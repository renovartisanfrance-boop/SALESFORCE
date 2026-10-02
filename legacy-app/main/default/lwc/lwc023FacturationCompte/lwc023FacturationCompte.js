import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';
import getCompteFacturation from '@salesforce/apex/LC023FacturationCompteController.getCompteFacturation';
import creerFactureDepuisCompte from '@salesforce/apex/LC023FacturationCompteController.creerFactureDepuisCompte';
import getPropositionsAcompte from '@salesforce/apex/LC023FacturationCompteController.getPropositionsAcompte';
import getFieldSetFields from '@salesforce/apex/FieldSetController.getFieldSetFields';
import getAcomptesDisponibles from '@salesforce/apex/FacturesController.getAcomptesDisponibles';

const FACTURE_OBJECT = 'Facture__c';
const FIELDSET_CLASSIQUE = 'FS_nouvelleFacture_Classique';

// Champ du FieldSet forcé côté serveur (= compte courant) : retiré du formulaire.
// Les montants (HT/TVA/TTC) restent saisis par l'utilisateur.
const SERVER_FIELDS = ['Destinataire_Compte__c'];

// Type de facture : forcé « Reçue » par défaut côté serveur (trigger), affiché en
// lecture seule dans le formulaire (les factures émises seront traitées plus tard).
const TYPE_FACTURE_FIELD = 'TypeFacture__c';
const TYPE_FACTURE_DEFAULT = 'Reçue';

const STATUS = {
    A_CREER: 'A_CREER',
    EXISTANTE: 'EXISTANTE',
    NON_ATTEINTE: 'NON_ATTEINTE',
    INDISPONIBLE: 'INDISPONIBLE',
    // Ligne Supplémentaire déjà créée, non liée à une facture (non recréable).
    CREEE: 'CREEE'
};

/**
 * Wizard de facturation DEPUIS LE COMPTE (Account).
 *  Écran 1 : lignes facturables (à créer) + déjà créées réutilisables — sélection multiple.
 *  Écran 2 : informations de facture (FieldSet Classique réutilisé).
 *  Écran 3 : acomptes (avances) du compte à rattacher.
 *  Création : Facture Classique + lignes + rattachement en une transaction atomique.
 */
export default class Lwc023FacturationCompte extends NavigationMixin(LightningElement) {
    // Id du Compte (Account). En quick action, le framework peut renseigner recordId
    // APRÈS connectedCallback : on déclenche donc le chargement via le setter aussi.
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

    // Étape Acomptes
    @track acomptes = [];
    @track selectedAcompteIds = new Set();
    // Factures d'acompte à CRÉER depuis le catalogue (RT Acompte) — propositions par
    // (ligne facturée × ligne catalogue Acompte), avec N° externe saisi par ligne.
    @track acompteCatalogue = [];
    @track selectedAcompteCatalogueKeys = new Set();
    acompteCatalogueNumero = new Map(); // key -> N° de facture externe

    // ------------------------------------------------------------ Cycle de vie

    connectedCallback() {
        this.loadFieldSet();
        this.maybeLoadLignes();
    }

    // Charge les lignes dès que recordId est disponible (une seule fois), que
    // recordId arrive avant ou après connectedCallback.
    maybeLoadLignes() {
        if (this._lignesLoaded || !this._recordId) return;
        this._lignesLoaded = true;
        this.loadLignes();
    }

    renderedCallback() {
        this.widenModal();
    }

    // En quick action, la modale est étroite par défaut et les colonnes se
    // chevauchent : on élargit la modale (une seule fois) une fois rendue.
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
            // Purge sélection / montants des clés qui n'existent plus.
            const keys = new Set(this.rawRows.map((r) => r.key));
            this.selectedKeys = new Set([...this.selectedKeys].filter((k) => keys.has(k)));
            const edited = new Map();
            this.editedMontants.forEach((v, k) => { if (keys.has(k)) edited.set(k, v); });
            this.editedMontants = edited;
            this.error = undefined;
        } catch (e) {
            this.error = this.reduceError(e);
        } finally {
            this.loading = false;
        }
    }

    async loadFieldSet() {
        try {
            const data = await getFieldSetFields({ objectName: FACTURE_OBJECT, fieldSetName: FIELDSET_CLASSIQUE });
            // Type de facture : pré-rempli « Reçue » (lecture seule) tant que non saisi,
            // pour que la valeur survive aux re-mappages (capture / prefill montant).
            if (!this.values[TYPE_FACTURE_FIELD]) {
                this.values = { ...this.values, [TYPE_FACTURE_FIELD]: TYPE_FACTURE_DEFAULT };
            }
            this.fields = (data.champs || [])
                .filter((f) => !SERVER_FIELDS.includes(f.apiName))
                .map((f) => ({
                    apiName: f.apiName,
                    isRequired: f.isRequired,
                    // TypeFacture__c : affiché en lecture seule.
                    isReadOnly: f.apiName === TYPE_FACTURE_FIELD,
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
            ? `Compte : ${this.compteName}`
            : 'Sélectionnez les lignes à facturer pour ce compte';
    }

    // ------------------------------------------------------------ Écran 1 : lignes

    decorate(r) {
        const selected = this.selectedKeys.has(r.key);
        const isEditable = r.montantEditable && r.status === STATUS.A_CREER;
        const montantValue = this.editedMontants.has(r.key) ? this.editedMontants.get(r.key) : r.montant;

        let statutLabel = '';
        let statutBadge = 'pf-badge pf-badge-muted';
        if (r.factureStatut) {
            // Ligne liée à une facture : on affiche le statut de la facture.
            statutLabel = r.factureStatut;
            statutBadge = this.factureBadgeClass(r.factureStatut);
        } else if (r.status === STATUS.A_CREER) { statutLabel = 'À créer'; statutBadge = 'pf-badge pf-badge-success'; }
        else if (r.status === STATUS.CREEE) { statutLabel = 'Créée'; statutBadge = 'pf-badge pf-badge-info'; }
        else if (r.status === STATUS.EXISTANTE) { statutLabel = 'Déjà créée'; statutBadge = 'pf-badge pf-badge-info'; }
        else if (r.status === STATUS.INDISPONIBLE) { statutLabel = 'Déjà facturée'; statutBadge = 'pf-badge pf-badge-muted'; }
        else { statutLabel = 'Échéance non atteinte'; statutBadge = 'pf-badge pf-badge-muted'; }

        const factureBadge = this.factureBadgeClass(r.factureStatut);

        let rowClass = 'slds-hint-parent';
        if (r.selectable) rowClass += ' row-clickable';
        else rowClass += ' row-disabled';
        if (selected) rowClass += ' row-selected';
        // Lignes du RT Supplémentaire : fond distinct pour les repérer.
        if (r.isSupplementaire) rowClass += ' pf-row-supp';

        return {
            key: r.key,
            dossierName: r.dossierName || '—',
            ficheCee: r.ficheCee || '—',
            role: r.role || '—',
            numEcheance: r.numEcheance,
            // Colonne « Éch. » : N° (1/2) pour le Standard, « Supp. » pour le Supplémentaire.
            numEcheanceDisplay: r.isSupplementaire ? 'Supp.' : (r.numEcheance == null ? '—' : r.numEcheance),
            isSupplementaire: r.isSupplementaire === true,
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

    // Tri (toutes colonnes sauf Dossier). Le champ correspond à une propriété de
    // la ligne brute (ficheCee, role, numEcheance, echeance, status, montant).
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

    // Indicateur de tri par colonne (objet lu en template : {arrows.role}…).
    // Neutre « ⇅ » avant tri, « ▲ »/« ▼ » sur la colonne active.
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

    // Empêche le clic dans la cellule Montant (saisie) de cocher/décocher la ligne.
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
        // Montant HT pré-rempli avec le total des lignes sélectionnées (éditable) ;
        // TVA et TTC restent vides, à saisir par l'utilisateur.
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
        this.loadPropositionsAcompte();
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

    // Taux de TVA saisi à l'écran 2 (picklist « 20 » …), en nombre (0 si vide).
    get tauxTVANumber() {
        const n = Number(this.values.Taux_TVA__c);
        return isNaN(n) ? 0 : n;
    }

    // Propositions de factures d'acompte (catalogue RT Acompte) pour les lignes
    // sélectionnées à l'écran 1 ; recalculées à chaque entrée de l'écran 3.
    async loadPropositionsAcompte() {
        if (!this.recordId) return;
        const selectedRowKeys = Array.from(this.selectedKeys);
        if (selectedRowKeys.length === 0) { this.acompteCatalogue = []; return; }
        this.loading = true;
        try {
            const data = await getPropositionsAcompte({
                compteId: this.recordId,
                selectedRowKeys,
                tauxTVA: this.tauxTVANumber
            });
            this.acompteCatalogue = data || [];
            // Purge sélection / N° des propositions qui n'existent plus.
            const keys = new Set(this.acompteCatalogue.map((p) => p.key));
            this.selectedAcompteCatalogueKeys = new Set(
                [...this.selectedAcompteCatalogueKeys].filter((k) => keys.has(k))
            );
            const num = new Map();
            this.acompteCatalogueNumero.forEach((v, k) => { if (keys.has(k)) num.set(k, v); });
            this.acompteCatalogueNumero = num;
        } catch (e) {
            this.toast('Erreur', this.reduceError(e), 'error');
        } finally {
            this.loading = false;
        }
    }

    get hasAcompteCatalogue() { return this.acompteCatalogue.length > 0; }

    get acompteCatalogueDisplay() {
        return this.acompteCatalogue.map((p) => {
            const selected = this.selectedAcompteCatalogueKeys.has(p.key);
            return {
                key: p.key,
                dossierName: p.dossierName || '—',
                ficheCee: p.ficheCee || '—',
                role: p.role || '—',
                designation: p.designation || '—',
                montantHT: p.montantHT,
                montantTVA: p.montantTVA,
                montantTTC: p.montantTTC,
                numero: this.acompteCatalogueNumero.get(p.key) || '',
                selected,
                // N° requis dès que la proposition est cochée (acompte créé en Validé).
                numeroMissing: selected && !String(this.acompteCatalogueNumero.get(p.key) || '').trim(),
                rowClass: selected
                    ? 'slds-hint-parent row-clickable row-selected pf-row-supp'
                    : 'slds-hint-parent row-clickable pf-row-supp'
            };
        });
    }

    get acompteCatalogueSummary() {
        return `${this.selectedAcompteCatalogueKeys.size} sélectionnée(s) sur ${this.acompteCatalogue.length}`;
    }

    toggleAcompteCatalogue(key) {
        if (!key) return;
        const set = new Set(this.selectedAcompteCatalogueKeys);
        if (set.has(key)) set.delete(key);
        else set.add(key);
        this.selectedAcompteCatalogueKeys = set;
    }
    handleAcompteCatalogueToggleRow(event) { this.toggleAcompteCatalogue(event.currentTarget.dataset.key); }
    handleAcompteCatalogueCheckbox(event) {
        event.stopPropagation();
        this.toggleAcompteCatalogue(event.target.dataset.key);
    }
    handleAcompteCatalogueNumero(event) {
        event.stopPropagation();
        const key = event.target.dataset.key;
        const map = new Map(this.acompteCatalogueNumero);
        map.set(key, event.target.value);
        this.acompteCatalogueNumero = map;
    }

    // Au moins une proposition cochée sans N° externe -> création bloquée.
    get missingAcompteNumero() {
        for (const k of this.selectedAcompteCatalogueKeys) {
            const num = this.acompteCatalogueNumero.get(k);
            if (!num || !String(num).trim()) return true;
        }
        return false;
    }

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
        // Acomptes catalogue cochés (à créer) : leur HT se déduit aussi de la Classique.
        this.acompteCatalogue.forEach((p) => {
            if (this.selectedAcompteCatalogueKeys.has(p.key) && p.montantHT) total += Number(p.montantHT);
        });
        return total;
    }

    get acompteSelectionSummary() {
        return `${this.selectedAcompteIds.size} sélectionné(s) sur ${this.acomptes.length}`;
    }
    // HT attendu pour la facture = total des lignes − acomptes (avances déjà facturées).
    get htAttendu() { return this.totalSelected - this.totalAcomptesHT; }
    // HT réellement saisi par l'utilisateur (étape Informations).
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
        return this.loading || this.selectedKeys.size === 0 || this.htAttendu < 0
            || !this.htMatches || this.missingAcompteNumero;
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
        // Recapture des valeurs (les inputs Informations restent dans le DOM, masqués).
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

        // Le serveur force RecordType, bénéficiaire et montants (HT/TVA/TTC) ; on ne
        // transmet que les champs saisis (N° externe, dates, taux, commentaire).
        const factureFields = { ...this.values };

        // Factures d'acompte (catalogue) cochées à créer : clé + N° externe saisi.
        const acomptesCatalogue = Array.from(this.selectedAcompteCatalogueKeys).map((k) => ({
            key: k,
            numero: this.acompteCatalogueNumero.get(k) || null
        }));

        this.loading = true;
        try {
            const factureId = await creerFactureDepuisCompte({
                compteId: this.recordId,
                factureFields,
                selections,
                acompteIds: Array.from(this.selectedAcompteIds),
                acomptesCatalogue
            });
            this.toast('Facture créée', `${selections.length} ligne(s) rattachée(s).`, 'success');
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
        // Sans effet hors contexte quick action.
        try { this.dispatchEvent(new CloseActionScreenEvent()); } catch (e) { /* noop */ }
    }

    // ------------------------------------------------------------ Utilitaires

    // Classe de badge selon le statut de la facture liée.
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