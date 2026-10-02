import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { NavigationMixin } from 'lightning/navigation';
import getDossierFacturationV2 from '@salesforce/apex/LC022FacturationCatalogueController.getDossierFacturationV2';
import creerLigneFactureCatalogue from '@salesforce/apex/LC022FacturationCatalogueController.creerLigneFactureCatalogue';
import getLigneFacture from '@salesforce/apex/LC022FacturationCatalogueController.getLigneFacture';
import updateLigneFacture from '@salesforce/apex/LC022FacturationCatalogueController.updateLigneFacture';
import verifierIntervenantCompte from '@salesforce/apex/LC022FacturationCatalogueController.verifierIntervenantCompte';
import isCommunityUser from '@salesforce/apex/LC022FacturationCatalogueController.isCommunityUser';

// Champs éditables sur la ligne de facture (appliqués après création via update).
// ctx = { intervenant, numEcheance, statut }
const configChampsLigne = [
    { apiName: 'Date_Reception__c', label: 'Date de Réception', type: 'date',     showIf: () => false },
    { apiName: 'Commentaire__c',    label: 'Commentaire',       type: 'textarea', showIf: () => true },
    { apiName: 'Motif_Rejet__c',    label: 'Motif de Rejet',    type: 'textarea', showIf: (ctx) => ctx.statut === 'Rejetée' }
];

export default class PaiementFacturationDossierV2 extends NavigationMixin(LightningElement) {
    _recordId;
    @api
    get recordId() { return this._recordId; }
    set recordId(v) {
        this._recordId = v;
        if (v) this.loadData();
    }

    @track rows = [];
    @track selectedId;
    @track currentStep = 'recap';
    @track dossierName;
    @track ficheCee;
    @track loading = false;
    @track isCommunity = false;
    error;

    // État de la ligne sélectionnée (par commission)
    @track com1Form = {};
    @track com2Form = {};
    @track com1Statut = null;
    @track com2Statut = null;
    @track com1Processed = false;
    @track com1LigneId;
    @track com2Processed = false;
    @track com2LigneId;
    // Montant (éditable) saisi pour chaque commission, initialisé au montant calculé.
    @track com1Montant;
    @track com2Montant;

    connectedCallback() {
        isCommunityUser()
            .then((res) => { this.isCommunity = res === true; })
            .catch(() => { this.isCommunity = false; });
    }

    // ----------------------------------------------------------- Chargement

    async loadData() {
        if (!this._recordId) return;
        this.loading = true;
        try {
            const res = await getDossierFacturationV2({ dossierId: this._recordId });
            this.dossierName = res ? res.dossierName : null;
            this.ficheCee = res ? res.ficheCee : null;
            this.rows = ((res && res.rows) || []).map((r) => this.decorate(r));
            this.error = undefined;
            this.syncSelectedLigneState();
        } catch (e) {
            this.error = e;
            this.rows = [];
        } finally {
            this.loading = false;
        }
    }

    // Décore une ligne serveur avec les propriétés d'affichage.
    decorate(r) {
        const has1 = r.catalogueFound && r.ruleMatched && r.com1 > 0;
        const has2 = r.catalogueFound && r.ruleMatched && r.com2 > 0;
        const s1 = this.computeStatut(r, 1, has1);
        const s2 = this.computeStatut(r, 2, has2);
        return {
            id: r.intervenant,
            intervenant: r.role,
            role: r.role,
            champLookup: r.champLookup,
            catalogueFound: r.catalogueFound,
            ruleMatched: r.ruleMatched,
            com1: r.com1,
            com2: r.com2,
            montantEditable: r.montantEditable,
            echeance1: r.echeance1,
            echeance2: r.echeance2,
            ech1Reached: r.ech1Reached,
            ech2Reached: r.ech2Reached,
            ligne1Id: r.ligne1Id,
            ligne2Id: r.ligne2Id,
            ligne1Statut: r.ligne1Statut,
            ligne2Statut: r.ligne2Statut,
            message: r.message,
            note: r.commentaire,
            hasNote: !!(r.commentaire && r.commentaire.trim()),
            has1,
            has2,
            selectable: r.catalogueFound && r.ruleMatched && (has1 || has2),
            disabledRadio: !(r.catalogueFound && r.ruleMatched && (has1 || has2)),
            com1Display: has1 ? r.com1 : null,
            com2Display: has2 ? r.com2 : null,
            echeance1Display: has1 ? r.echeance1 || '—' : '—',
            echeance2Display: has2 ? r.echeance2 || '—' : '—',
            statut1Label: s1.label,
            statut1Class: s1.cls,
            statut1Tip: s1.tip,
            statut2Label: s2.label,
            statut2Class: s2.cls,
            statut2Tip: s2.tip
        };
    }

    computeStatut(r, num, has) {
        if (!r.catalogueFound) {
            return {
                label: 'Catalogue non trouvé',
                cls: 'pf-badge pf-badge-info',
                tip: 'Aucune ligne catalogue active (fiche + rôle + période de validité + statut « Active »).'
            };
        }
        if (!r.ruleMatched) {
            return {
                label: 'Non couvert',
                cls: 'pf-badge pf-badge-info',
                tip: 'Une ligne catalogue existe mais aucune règle ne correspond aux variables du dossier.'
            };
        }
        if (!has) {
            return {
                label: 'N/A',
                cls: 'pf-badge pf-badge-muted',
                tip:
                    r.message ||
                    'Ligne et règle trouvées, mais le montant calculé est vide ou égal à 0 (montant non renseigné dans le catalogue, ou formule à 0).'
            };
        }
        const ligneId = num === 1 ? r.ligne1Id : r.ligne2Id;
        const ligneStatut = num === 1 ? r.ligne1Statut : r.ligne2Statut;
        const reached = num === 1 ? r.ech1Reached : r.ech2Reached;
        if (ligneId) {
            const s = ligneStatut || 'Créée';
            return { label: s, cls: this.statutLigneBadge(s), tip: 'Statut de la facture liée (ou de la ligne si non rattachée).' };
        }
        // La commission 2 attend que la commission 1 (si elle existe) soit créée.
        if (num === 2 && r.com1 > 0 && !r.ligne1Id) {
            return { label: 'En attente', cls: 'pf-badge pf-badge-muted', tip: 'La commission 1 doit être créée avant la commission 2.' };
        }
        if (reached) return { label: 'À payer', cls: 'pf-badge pf-badge-danger', tip: 'Échéance atteinte — facturation possible.' };
        return { label: 'En attente', cls: 'pf-badge pf-badge-muted', tip: 'Échéance non encore atteinte.' };
    }

    // Badge coloré selon le statut affiché (statut de la facture liée le cas échéant).
    statutLigneBadge(s) {
        if (s === 'Validé' || s === 'Payé' || s === 'Payée') return 'pf-badge pf-badge-success';
        if (s === 'Annulé' || s === 'Rejetée') return 'pf-badge pf-badge-danger';
        if (s === 'Brouillon') return 'pf-badge pf-badge-info';
        return 'pf-badge pf-badge-success';
    }

    // Met à jour l'état des lignes de la sélection courante (après reload).
    syncSelectedLigneState() {
        const row = this.selectedRow;
        if (!row) return;
        this.com1Processed = !!row.ligne1Id;
        this.com1LigneId = row.ligne1Id || null;
        this.com1Statut = row.ligne1Statut || null;
        this.com2Processed = !!row.ligne2Id;
        this.com2LigneId = row.ligne2Id || null;
        this.com2Statut = row.ligne2Statut || null;
        // Pré-remplit les montants éditables avec les montants calculés.
        this.com1Montant = row.com1;
        this.com2Montant = row.com2;
    }

    // -------------------------------------------------------------- Getters

    get steps() {
        const label = this.selectedIntervenant ? `Paiement ${this.selectedIntervenant}` : 'Paiement Intervenant';
        return [
            { label: 'Récapitulatif', value: 'recap' },
            { label, value: 'paiement' }
        ];
    }

    get selectedRow() {
        return this.rows.find((r) => r.id === this.selectedId);
    }
    get selectedIntervenant() {
        const row = this.selectedRow;
        return row ? row.intervenant : null;
    }

    get isRecapStep() { return this.currentStep === 'recap'; }
    get isPaiementStep() { return this.currentStep === 'paiement'; }

    get hasRows() { return this.rows.length > 0; }
    get hasSelectionDisabled() {
        const row = this.selectedRow;
        return !row || !row.selectable;
    }

    get hasCom1() { return !!(this.selectedRow && this.selectedRow.has1); }
    get hasCom2() { return !!(this.selectedRow && this.selectedRow.has2); }
    get showCom2Column() { return this.hasCom2; }

    // Note de la règle correspondante (affichée en (i) dans l'écran de paiement).
    get selectedNote() { const r = this.selectedRow; return r ? r.note : null; }
    get selectedHasNote() { const r = this.selectedRow; return !!(r && r.hasNote); }

    get selectedEch1Ok() { return !!(this.selectedRow && this.selectedRow.ech1Reached); }
    get selectedEch2Ok() { return !!(this.selectedRow && this.selectedRow.ech2Reached); }

    // La commission 2 exige que la commission 1 (si elle existe) soit déjà créée.
    get com2RequiresCom1() {
        const r = this.selectedRow;
        return !!(r && r.has1 && !this.com1Processed);
    }
    get com2BlockedByCom1() { return this.hasCom2 && !this.com2Processed && this.com2RequiresCom1; }

    get com1Disabled() { return this.loading || !this.hasCom1 || !this.selectedEch1Ok; }
    get com2Disabled() {
        return this.loading || !this.hasCom2 || !this.selectedEch2Ok || this.com2RequiresCom1;
    }
    get com1Blocked() { return this.hasCom1 && !this.selectedEch1Ok && !this.com1Processed; }
    get com2Blocked() {
        return this.hasCom2 && !this.selectedEch2Ok && !this.com2Processed && !this.com2RequiresCom1;
    }

    get com1Label() { return this.com1Processed ? 'Enregistrer Facturation 1' : 'Créer Facturation 1'; }
    get com2Label() { return this.com2Processed ? 'Enregistrer Facturation 2' : 'Créer Facturation 2'; }
    get com1Variant() { return this.com1Processed ? 'success' : 'brand'; }
    get com2Variant() { return this.com2Processed ? 'success' : 'brand'; }

    get com1LigneUrl() { return this.com1LigneId ? `/${this.com1LigneId}` : null; }
    get com2LigneUrl() { return this.com2LigneId ? `/${this.com2LigneId}` : null; }

    get showLigneFactureRow() { return !this.isCommunity; }
    get com1ShowButton() { return !(this.com1Processed && this.isCommunity); }
    get com2ShowButton() { return !(this.com2Processed && this.isCommunity); }

    get displayRows() {
        return this.rows.map((r) => {
            let cls = 'slds-hint-parent';
            if (r.selectable) cls += ' row-clickable';
            if (r.id === this.selectedId) cls += ' row-selected';
            return { ...r, selected: r.id === this.selectedId, rowClass: cls };
        });
    }

    get infoRows() {
        const r = this.selectedRow;
        if (!r) return [];
        const disabled1 = this.loading || (this.com1Processed && this.isCommunity);
        const disabled2 = this.loading || (this.com2Processed && this.isCommunity) || this.com2RequiresCom1;
        return [
            {
                key: 'compte',
                info: 'Intervenant (Compte Bénéficiaire)',
                isComptePicker: true,
                show1: r.has1,
                show2: r.has2,
                compteVal1: this.com1Form.Intervenant_Compte__c || null,
                compteVal2: this.com2Form.Intervenant_Compte__c || null,
                disabled1,
                disabled2
            },
            {
                key: 'montant',
                info: 'Montant Total HT',
                isCurrency: !r.montantEditable,
                isEditableMontant: r.montantEditable,
                show1: r.has1,
                show2: r.has2,
                val1: r.has1 ? (r.montantEditable ? this.com1Montant : r.com1) : null,
                val2: r.has2 ? (r.montantEditable ? this.com2Montant : r.com2) : null,
                disabled1: this.loading || this.com1Processed,
                disabled2: this.loading || this.com2Processed || this.com2RequiresCom1
            },
            { key: 'num', info: 'Numéro Échéance', val1: r.has1 ? '1' : '-', val2: r.has2 ? '2' : '-' },
            { key: 'ech', info: 'Échéance Déclenchante', val1: r.echeance1 || '-', val2: r.echeance2 || '-' }
        ];
    }

    get editableFieldRows() {
        return configChampsLigne
            .map((c) => {
                const ctx1 = { intervenant: this.selectedIntervenant, numEcheance: '1', statut: this.com1Statut };
                const ctx2 = { intervenant: this.selectedIntervenant, numEcheance: '2', statut: this.com2Statut };
                const show1 = this.hasCom1 && this.safeShow(c, ctx1);
                const show2 = this.hasCom2 && this.safeShow(c, ctx2);
                const v1 = this.com1Form[c.apiName];
                const v2 = this.com2Form[c.apiName];
                return {
                    key: c.apiName,
                    apiName: c.apiName,
                    label: c.label,
                    required: c.required === true,
                    step: c.step || null,
                    isText: c.type === 'text',
                    isNumber: c.type === 'number',
                    isDate: c.type === 'date',
                    isCheckbox: c.type === 'checkbox',
                    isTextarea: c.type === 'textarea',
                    show1,
                    show2,
                    val1Str: v1 == null ? '' : String(v1),
                    val2Str: v2 == null ? '' : String(v2),
                    val1Bool: v1 === true,
                    val2Bool: v2 === true,
                    disabled1: this.loading || (this.com1Processed && this.isCommunity),
                    disabled2: this.loading || (this.com2Processed && this.isCommunity) || this.com2RequiresCom1
                };
            })
            .filter((f) => f.show1 || f.show2);
    }

    safeShow(c, ctx) {
        try { return c.showIf(ctx); } catch (e) { return false; }
    }

    // ------------------------------------------------------------- Handlers

    handleSelect(event) {
        event.stopPropagation();
        const id = event.target.dataset.id;
        const row = this.rows.find((r) => r.id === id);
        if (row && row.selectable) this.selectedId = id;
    }

    handleRowClick(event) {
        const id = event.currentTarget.dataset.id;
        const row = this.rows.find((r) => r.id === id);
        if (row && row.selectable) this.selectedId = id;
    }

    async handleNext() {
        const row = this.selectedRow;
        if (!row || !row.selectable) return;

        this.syncSelectedLigneState();
        this.com1Form = {};
        this.com2Form = {};
        if (row.ligne1Id) await this.loadLigneIntoForm(1, row.ligne1Id);
        if (row.ligne2Id) await this.loadLigneIntoForm(2, row.ligne2Id);

        this.currentStep = 'paiement';
    }

    async loadLigneIntoForm(num, ligneId) {
        try {
            const data = await getLigneFacture({ ligneId });
            const form = {};
            configChampsLigne.forEach((c) => { form[c.apiName] = data ? data[c.apiName] : null; });
            form.Intervenant_Compte__c = data ? data.Intervenant_Compte__c : null;
            if (num === 1) this.com1Form = form;
            else this.com2Form = form;
        } catch (e) {
            // silencieux
        }
    }

    handleBack() {
        this.currentStep = 'recap';
    }

    handleFieldChange(event) {
        const num = event.target.dataset.num;
        const api = event.target.dataset.field;
        const t = event.target.type;
        const val = t === 'checkbox' ? event.target.checked : event.target.value;
        if (num === '1') this.com1Form = { ...this.com1Form, [api]: val };
        else this.com2Form = { ...this.com2Form, [api]: val };
    }

    handleIntervenantCompteChange(event) {
        const num = event.target.dataset.num;
        const val = (event.detail && event.detail.recordId) || null;
        if (num === '1') this.com1Form = { ...this.com1Form, Intervenant_Compte__c: val };
        else this.com2Form = { ...this.com2Form, Intervenant_Compte__c: val };
    }

    // Montant éditable (admin ou ligne « montants modifiables »).
    handleMontantChange(event) {
        const num = event.target.dataset.num;
        const raw = event.target.value;
        const val = raw === '' || raw === null || raw === undefined ? null : Number(raw);
        if (num === '1') this.com1Montant = val;
        else this.com2Montant = val;
    }

    handlePayCom1() { this.saveCommission(1); }
    handlePayCom2() { this.saveCommission(2); }

    async saveCommission(num) {
        const row = this.selectedRow;
        if (!row) return;

        const processed = num === 1 ? this.com1Processed : this.com2Processed;
        const ligneId = num === 1 ? this.com1LigneId : this.com2LigneId;
        const form = num === 1 ? this.com1Form : this.com2Form;
        const echeance = num === 1 ? row.echeance1 : row.echeance2;
        // Montant saisi : envoyé uniquement si la ligne est éditable (le serveur
        // revérifie ce droit ; sinon le montant recalculé fait foi).
        const montantSaisi = row.montantEditable ? (num === 1 ? this.com1Montant : this.com2Montant) : null;

        this.loading = true;
        try {
            if (!processed) {
                // Montant recalculé serveur, sauf valeur saisie autorisée (modifiable).
                const newId = await creerLigneFactureCatalogue({
                    dossierId: this._recordId,
                    typeIntervenant: row.role,
                    numEcheance: num,
                    echeanceDeclenchante: echeance,
                    intervenantCompteId: form.Intervenant_Compte__c || null,
                    champLookupApi: row.champLookup || null,
                    montantSaisi: montantSaisi
                });
                if (num === 1) { this.com1Processed = true; this.com1LigneId = newId; }
                else { this.com2Processed = true; this.com2LigneId = newId; }

                const extra = this.pickExtraFields(form);
                if (Object.keys(extra).length) {
                    await updateLigneFacture({ ligneId: newId, fields: extra });
                }
                this.toast('Ligne créée', `Commission ${num} — ligne enregistrée`, 'success');
            } else {
                await verifierIntervenantCompte({
                    dossierId: this._recordId,
                    champLookupApi: row.champLookup || null,
                    intervenantCompteId: form.Intervenant_Compte__c || null,
                    typeIntervenant: row.role
                });

                const toSave = {};
                const ctx = {
                    intervenant: this.selectedIntervenant,
                    numEcheance: String(num),
                    statut: num === 1 ? this.com1Statut : this.com2Statut
                };
                configChampsLigne.forEach((c) => {
                    if (!this.safeShow(c, ctx)) return;
                    toSave[c.apiName] = form[c.apiName] ?? null;
                });
                toSave.Intervenant_Compte__c = form.Intervenant_Compte__c ?? null;
                await updateLigneFacture({ ligneId, fields: toSave });
                this.toast('Ligne mise à jour', `Commission ${num} — modifications enregistrées`, 'success');
            }

            await this.loadData();
        } catch (e) {
            this.toast('Erreur', (e.body && e.body.message) || e.message || 'Erreur inconnue', 'error');
        } finally {
            this.loading = false;
        }
    }

    pickExtraFields(form) {
        const out = {};
        configChampsLigne.forEach((c) => {
            const v = form[c.apiName];
            if (v === undefined || v === null || v === '') return;
            out[c.apiName] = v;
        });
        return out;
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    handleClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    // Élargissement de la modale (quick action)
    renderedCallback() {
        if (this._modalWidened) return;
        const host = this.template.host;
        const modal = host && host.closest ? host.closest('.slds-modal__container') : null;
        if (modal) {
            modal.style.width = '95vw';
            modal.style.maxWidth = '1400px';
            this._modalWidened = true;
        }
    }
}