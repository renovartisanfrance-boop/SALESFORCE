import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';
import getCompteFacturation from '@salesforce/apex/LC024FacturationCompteController.getCompteFacturation';
import creerFactureDepuisCompte from '@salesforce/apex/LC024FacturationCompteController.creerFactureDepuisCompte';
import getFieldSetFields from '@salesforce/apex/FieldSetController.getFieldSetFields';
import getAcomptesDisponibles from '@salesforce/apex/FacturesController.getAcomptesDisponibles';

const FACTURE_OBJECT = 'Facture__c';
const FIELDSET_EMISE = 'FS_nouvelleFacture_Emise';

// Champ du FieldSet rempli ailleurs (Destinataire = par le trigger) : retiré du formulaire.
const SERVER_FIELDS = ['Destinataire_Compte__c'];

// Fournisseur = compte courant (compte d'où la facture émise est créée) : affiché
// dans le formulaire mais en LECTURE SEULE, forcé côté serveur.
const FOURNISSEUR_FIELD = 'Fournisseur_Compte__c';

// Type de facture : forcé « Émise » côté serveur (factures que nous émettons),
// affiché en lecture seule dans le formulaire.
const TYPE_FACTURE_FIELD = 'TypeFacture__c';
// Valeur API de la picklist restreinte (le label affiché est « Émise »).
const TYPE_FACTURE_DEFAULT = 'Emise';

const STATUS = {
    A_CREER: 'A_CREER',
    EXISTANTE: 'EXISTANTE',
    NON_ATTEINTE: 'NON_ATTEINTE',
    INDISPONIBLE: 'INDISPONIBLE'
};

/**
 * Wizard de facturation ÉMISE DEPUIS LE COMPTE (Account) — pendant de lwc023, mais
 * pour les factures que NOUS ÉMETTONS (catalogue Paiement « Reçu », rôle Délégataire,
 * RT Standard uniquement).
 *  Écran 1 : lignes facturables (à créer) + déjà créées réutilisables.
 *  Écran 2 : informations de facture (FieldSet Émise).
 *  Écran 3 : acomptes (avances) du compte à rattacher (pas d'acompte catalogue ici).
 *  Création : Facture Émise + lignes + rattachement en une transaction atomique.
 */
export default class Lwc024FacturationCompteEmise extends NavigationMixin(LightningElement) {
    _recordId;
    _lignesLoaded = false;
    _modalWidened = false;

    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        this._recordId = value;
        this.maybeLoadLignes();
    }

    @track currentStep = 'lignes';
    @track loading = false;
    @track error;

    compteName;
    rawRows = [];
    selectedKeys = new Set();
    editedMontants = new Map();
    @track filterText = '';
    sortField = '';
    sortDir = 'asc';

    // Étape Informations (FieldSet réutilisé)
    @track fields = [];
    @track values = {};

    // Étape Acomptes (avances existantes à rattacher)
    @track acomptes = [];
    @track selectedAcompteIds = new Set();

    // ------------------------------------------------------------ Cycle de vie

    connectedCallback() {
        this.loadFieldSet();
        this.maybeLoadLignes();
    }

    maybeLoadLignes() {
        if (this._lignesLoaded || !this._recordId) return;
        this._lignesLoaded = true;
        this.loadLignes();
    }

    renderedCallback() {
        this.widenModal();
    }

    widenModal() {
        if (this._modalWidened) return;
        const host = this.template.host;
        const modal = host && host.closest ? host.closest('.slds-modal__container') : null;
        if (modal) {
            modal.style.width = '95vw';
            modal.style.maxWidth = '1500px';
            this._modalWidened = true;
        }
    }

    async loadLignes() {
        if (!this.recordId) return;
        this.loading = true;
        try {
            const res = await getCompteFacturation({ compteId: this.recordId });
            this.compteName = res.compteName;
            this.rawRows = res.rows || [];
            const keys = new Set(this.rawRows.map((r) => r.key));
            this.selectedKeys = new Set([...this.selectedKeys].filter((k) => keys.has(k)));
            const edited = new Map();
            this.editedMontants.forEach((v, k) => { if (keys.has(k)) edited.set(k, v); });
            this.editedMontants = edited;
            this.error = undefined;
            // Fournisseur = compte courant (au cas où recordId arrive après loadFieldSet).
            if (this.values[FOURNISSEUR_FIELD] !== this.recordId) {
                this.values = { ...this.values, [FOURNISSEUR_FIELD]: this.recordId };
                this.fields = this.fields.map((f) => ({ ...f, savedValue: this.values[f.apiName] }));
            }
        } catch (e) {
            this.error = this.reduceError(e);
        } finally {
            this.loading = false;
        }
    }

    async loadFieldSet() {
        try {
            const data = await getFieldSetFields({ objectName: FACTURE_OBJECT, fieldSetName: FIELDSET_EMISE });
            // Type de facture : pré-rempli « Émise » (lecture seule) tant que non saisi,
            // pour que la valeur survive aux re-mappages (capture / prefill montant).
            if (!this.values[TYPE_FACTURE_FIELD]) {
                this.values = { ...this.values, [TYPE_FACTURE_FIELD]: TYPE_FACTURE_DEFAULT };
            }
            // Fournisseur = compte courant (lecture seule), si déjà connu.
            if (this.recordId && !this.values[FOURNISSEUR_FIELD]) {
                this.values = { ...this.values, [FOURNISSEUR_FIELD]: this.recordId };
            }
            this.fields = (data.champs || [])
                .filter((f) => !SERVER_FIELDS.includes(f.apiName))
                .map((f) => ({
                    apiName: f.apiName,
                    isRequired: f.isRequired,
                    isReadOnly: f.apiName === TYPE_FACTURE_FIELD || f.apiName === FOURNISSEUR_FIELD,
                    savedValue: this.values[f.apiName]
                }));
        } catch (e) {
            this.error = this.reduceError(e);
        }
    }

    // ------------------------------------------------------------ Étapes / nav

    get steps() {
        return [
            { value: 'lignes', label: 'Lignes à facturer' },
            { value: 'infos', label: 'Informations' },
            { value: 'acomptes', label: 'Acomptes (Avances)' }
        ];
    }

    get isLignesStep() { return this.currentStep === 'lignes'; }
    get isInfosStep() { return this.currentStep === 'infos'; }
    get isAcomptesStep() { return this.currentStep === 'acomptes'; }
    get infosStepClass() { return this.isInfosStep ? '' : 'slds-hide'; }
    get objectApiName() { return FACTURE_OBJECT; }

    get subtitle() {
        return this.compteName
            ? `Compte : ${this.compteName} — factures émises`
            : 'Sélectionnez les lignes à facturer (émises) pour ce compte';
    }

    // ------------------------------------------------------------ Écran 1 : lignes

    decorate(r) {
        const selected = this.selectedKeys.has(r.key);
        const isEditable = r.montantEditable && r.status === STATUS.A_CREER;
        const montantValue = this.editedMontants.has(r.key) ? this.editedMontants.get(r.key) : r.montant;

        let statutLabel = '';
        let statutBadge = 'pf-badge pf-badge-muted';
        if (r.factureStatut) {
            statutLabel = r.factureStatut;
            statutBadge = this.factureBadgeClass(r.factureStatut);
        } else if (r.status === STATUS.A_CREER) { statutLabel = 'À créer'; statutBadge = 'pf-badge pf-badge-success'; }
        else if (r.status === STATUS.EXISTANTE) { statutLabel = 'Déjà créée'; statutBadge = 'pf-badge pf-badge-info'; }
        else if (r.status === STATUS.INDISPONIBLE) { statutLabel = 'Déjà facturée'; statutBadge = 'pf-badge pf-badge-muted'; }
        else { statutLabel = 'Échéance non atteinte'; statutBadge = 'pf-badge pf-badge-muted'; }

        const factureBadge = this.factureBadgeClass(r.factureStatut);

        let rowClass = 'slds-hint-parent';
        if (r.selectable) rowClass += ' row-clickable';
        else rowClass += ' row-disabled';
        if (selected) rowClass += ' row-selected';

        return {
            key: r.key,
            dossierName: r.dossierName || '—',
            ficheCee: r.ficheCee || '—',
            role: r.role || '—',
            numEcheance: r.numEcheance,
            numEcheanceDisplay: r.numEcheance == null ? '—' : r.numEcheance,
            echeance: r.echeance || '—',
            montant: r.montant,
            montantValue,
            isEditable,
            isCurrency: !isEditable,
            montantEditable: r.montantEditable,
            selectable: r.selectable,
            disabledCheckbox: !r.selectable,
            selected,
            disabledInput: this.loading,
            commentaire: r.commentaire,
            hasNote: !!r.commentaire,
            statutLabel,
            statutBadge,
            factureStatut: r.factureStatut,
            factureBadge,
            factureNumExterne: r.factureNumExterne,
            rowClass
        };
    }

    get filteredRaw() {
        const q = (this.filterText || '').toLowerCase().trim();
        if (!q) return this.rawRows;
        return this.rawRows.filter((r) => {
            const hay = `${r.dossierName || ''} ${r.role || ''} ${r.echeance || ''} ${r.ficheCee || ''}`.toLowerCase();
            return hay.includes(q);
        });
    }

    get sortedFiltered() {
        const rows = [...this.filteredRaw];
        if (!this.sortField) return rows;
        const dir = this.sortDir === 'desc' ? -1 : 1;
        const f = this.sortField;
        return rows.sort((a, b) => {
            let va = a[f];
            let vb = b[f];
            if (va === null || va === undefined) va = '';
            if (vb === null || vb === undefined) vb = '';
            if (typeof va === 'number' && typeof vb === 'number') return (va - vb) * dir;
            return String(va).localeCompare(String(vb), 'fr', { numeric: true }) * dir;
        });
    }

    get displayRows() { return this.sortedFiltered.map((r) => this.decorate(r)); }

    get arrows() {
        const fields = ['ficheCee', 'role', 'numEcheance', 'echeance', 'status', 'montant'];
        const active = this.sortDir === 'desc' ? ' ▼' : ' ▲';
        const a = {};
        fields.forEach((f) => {
            a[f] = this.sortField === f ? active : ' ⇅';
        });
        return a;
    }

    handleSort(event) {
        const field = event.currentTarget.dataset.field;
        if (!field) return;
        if (this.sortField === field) {
            this.sortDir = this.sortDir === 'asc' ? 'desc' : 'asc';
        } else {
            this.sortField = field;
            this.sortDir = 'asc';
        }
    }

    get hasRows() { return this.rawRows.length > 0; }
    get hasFilteredRows() { return this.filteredRaw.length > 0; }

    get selectableFiltered() { return this.filteredRaw.filter((r) => r.selectable); }

    get allSelected() {
        const sel = this.selectableFiltered;
        return sel.length > 0 && sel.every((r) => this.selectedKeys.has(r.key));
    }

    get selectionSummary() {
        return `${this.selectedKeys.size} sélectionnée(s) sur ${this.rawRows.length}`;
    }

    get totalSelected() {
        let total = 0;
        this.rawRows.forEach((r) => {
            if (!this.selectedKeys.has(r.key)) return;
            const m = (r.montantEditable && r.status === STATUS.A_CREER && this.editedMontants.has(r.key))
                ? Number(this.editedMontants.get(r.key))
                : Number(r.montant);
            if (!isNaN(m)) total += m;
        });
        return total;
    }

    get hasSelection() { return this.selectedKeys.size > 0; }
    get lignesNextDisabled() { return this.loading || this.selectedKeys.size === 0; }

    handleSearch(event) { this.filterText = event.target.value; }

    toggleKey(key) {
        const row = this.rawRows.find((r) => r.key === key);
        if (!row || !row.selectable) return;
        const set = new Set(this.selectedKeys);
        if (set.has(key)) set.delete(key);
        else set.add(key);
        this.selectedKeys = set;
    }

    handleToggleRow(event) { this.toggleKey(event.currentTarget.dataset.key); }

    stopProp(event) { event.stopPropagation(); }

    handleCheckboxChange(event) {
        event.stopPropagation();
        this.toggleKey(event.target.dataset.key);
    }

    handleSelectAll(event) {
        event.stopPropagation();
        const set = new Set(this.selectedKeys);
        if (event.target.checked) this.selectableFiltered.forEach((r) => set.add(r.key));
        else this.selectableFiltered.forEach((r) => set.delete(r.key));
        this.selectedKeys = set;
    }

    handleMontantChange(event) {
        const key = event.target.dataset.key;
        const raw = event.target.value;
        const map = new Map(this.editedMontants);
        if (raw === '' || raw === null || raw === undefined) map.delete(key);
        else map.set(key, Number(raw));
        this.editedMontants = map;
    }

    // ------------------------------------------------------------ Écran 2 : infos

    captureCurrentValues() {
        const inputs = this.template.querySelectorAll('lightning-input-field');
        const collected = { ...this.values };
        inputs.forEach((i) => { collected[i.fieldName] = i.value; });
        this.values = collected;
        this.fields = this.fields.map((f) => ({ ...f, savedValue: this.values[f.apiName] }));
    }

    handleLignesNext() {
        if (this.selectedKeys.size === 0) {
            this.toast('Aucune ligne', 'Sélectionnez au moins une ligne à facturer.', 'warning');
            return;
        }
        this.values = { ...this.values, MontantHT__c: this.totalSelected };
        this.fields = this.fields.map((f) => ({ ...f, savedValue: this.values[f.apiName] }));
        this.currentStep = 'infos';
    }

    handleInfosBack() { this.currentStep = 'lignes'; }

    handleInfosNext() {
        const inputs = this.template.querySelectorAll('lightning-input-field');
        let valid = true;
        const collected = { ...this.values };
        inputs.forEach((i) => {
            if (!i.reportValidity()) valid = false;
            collected[i.fieldName] = i.value;
        });
        if (!valid) {
            this.toast('Champs invalides', 'Veuillez compléter les champs requis.', 'error');
            return;
        }
        this.values = collected;
        this.fields = this.fields.map((f) => ({ ...f, savedValue: this.values[f.apiName] }));
        this.currentStep = 'acomptes';
        this.loadAcomptes();
    }

    // ------------------------------------------------------------ Écran 3 : acomptes

    async loadAcomptes() {
        if (!this.recordId) return;
        this.loading = true;
        try {
            const data = await getAcomptesDisponibles({ destinataireCompteId: this.recordId });
            this.acomptes = data || [];
            const ids = new Set(this.acomptes.map((a) => a.Id));
            const kept = new Set();
            this.selectedAcompteIds.forEach((id) => { if (ids.has(id)) kept.add(id); });
            this.selectedAcompteIds = kept;
        } catch (e) {
            this.toast('Erreur', this.reduceError(e), 'error');
        } finally {
            this.loading = false;
        }
    }

    get hasAcomptes() { return this.acomptes.length > 0; }

    get acomptesDisplay() {
        return this.acomptes.map((a) => {
            const selected = this.selectedAcompteIds.has(a.Id);
            const statut = a.Statut__c || '-';
            let badge = 'pf-badge pf-badge-muted';
            if (statut === 'Validé' || statut === 'Payé') badge = 'pf-badge pf-badge-success';
            return {
                id: a.Id,
                name: a.Name,
                numExterne: a.N_Facture_Externe__c || '—',
                dateFacture: a.DateFacture__c,
                montantHT: a.MontantHT__c,
                montantTTC: a.Montant_Total__c,
                statut,
                statutBadgeClass: badge,
                selected,
                rowClass: selected
                    ? 'slds-hint-parent row-clickable row-selected'
                    : 'slds-hint-parent row-clickable'
            };
        });
    }

    get totalAcomptesHT() {
        let total = 0;
        this.acomptes.forEach((a) => {
            if (this.selectedAcompteIds.has(a.Id) && a.MontantHT__c) total += Number(a.MontantHT__c);
        });
        return total;
    }

    get acompteSelectionSummary() {
        return `${this.selectedAcompteIds.size} sélectionné(s) sur ${this.acomptes.length}`;
    }
    get htAttendu() { return this.totalSelected - this.totalAcomptesHT; }
    get htSaisi() {
        const n = Number(this.values.MontantHT__c);
        return isNaN(n) ? 0 : n;
    }
    get acomptesDepassent() { return this.htAttendu < 0; }
    get htMatches() { return Math.abs(this.htSaisi - this.htAttendu) < 0.01; }
    get matchRowClass() { return this.htMatches ? 'pf-match-row pf-match-ok' : 'pf-match-row pf-match-warn'; }
    get matchLabel() {
        return this.htMatches
            ? '✓ Montant HT conforme (= total des lignes − acomptes)'
            : '⚠ Le montant HT saisi doit être égal au total des lignes − acomptes (ajustez-le à l\'étape Informations)';
    }
    get creationBlocked() {
        return this.loading || this.selectedKeys.size === 0 || this.htAttendu < 0 || !this.htMatches;
    }

    toggleAcompte(id) {
        if (!id) return;
        const set = new Set(this.selectedAcompteIds);
        if (set.has(id)) set.delete(id);
        else set.add(id);
        this.selectedAcompteIds = set;
    }
    handleAcompteToggleRow(event) { this.toggleAcompte(event.currentTarget.dataset.id); }
    handleAcompteCheckboxChange(event) {
        event.stopPropagation();
        this.toggleAcompte(event.target.dataset.id);
    }
    handleAcomptesBack() { this.currentStep = 'infos'; }

    // ------------------------------------------------------------ Création

    async handleCreate() {
        this.captureCurrentValues();

        const selections = this.rawRows
            .filter((r) => this.selectedKeys.has(r.key))
            .map((r) => ({
                rowKey: r.key,
                selType: r.status === STATUS.EXISTANTE ? STATUS.EXISTANTE : STATUS.A_CREER,
                montantSaisi:
                    r.montantEditable && r.status === STATUS.A_CREER && this.editedMontants.has(r.key)
                        ? Number(this.editedMontants.get(r.key))
                        : null
            }));

        if (selections.length === 0) {
            this.toast('Aucune ligne', 'Sélectionnez au moins une ligne à facturer.', 'warning');
            return;
        }

        const factureFields = { ...this.values };

        this.loading = true;
        try {
            const factureId = await creerFactureDepuisCompte({
                compteId: this.recordId,
                factureFields,
                selections,
                acompteIds: Array.from(this.selectedAcompteIds)
            });
            this.toast('Facture émise créée', `${selections.length} ligne(s) rattachée(s).`, 'success');
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId: factureId, objectApiName: FACTURE_OBJECT, actionName: 'view' }
            });
            this.closeAction();
        } catch (e) {
            this.toast('Erreur', this.reduceError(e), 'error');
        } finally {
            this.loading = false;
        }
    }

    handleCancel() {
        this.closeAction();
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: this.recordId, objectApiName: 'Account', actionName: 'view' }
        });
    }

    closeAction() {
        try { this.dispatchEvent(new CloseActionScreenEvent()); } catch (e) { /* noop */ }
    }

    // ------------------------------------------------------------ Utilitaires

    factureBadgeClass(s) {
        if (s === 'Validé' || s === 'Payé' || s === 'Payée') return 'pf-badge pf-badge-success';
        if (s === 'Annulé' || s === 'Rejetée') return 'pf-badge pf-badge-danger';
        if (s === 'Brouillon') return 'pf-badge pf-badge-info';
        return 'pf-badge pf-badge-muted';
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    reduceError(error) {
        if (!error) return 'Erreur inconnue';
        if (Array.isArray(error.body)) return error.body.map((e) => e.message).join(', ');
        if (error.body && error.body.message) return error.body.message;
        return error.message || 'Erreur inconnue';
    }
}