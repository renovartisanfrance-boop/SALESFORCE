import { LightningElement, api, wire, track } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { NavigationMixin } from 'lightning/navigation';
import createLigneFacture from '@salesforce/apex/PaiementFacturationController.createLigneFacture';
import getDossierInfo from '@salesforce/apex/PaiementFacturationController.getDossierInfo';
import getLignesByDossier from '@salesforce/apex/PaiementFacturationController.getLignesByDossier';
import getLigneFacture from '@salesforce/apex/PaiementFacturationController.getLigneFacture';
import updateLigneFacture from '@salesforce/apex/PaiementFacturationController.updateLigneFacture';
import verifierIntervenantCompte from '@salesforce/apex/PaiementFacturationController.verifierIntervenantCompte';
import isCommunityUser from '@salesforce/apex/PaiementFacturationController.isCommunityUser';

// champLookup = champ lookup sur le dossier (Pro__c) identifiant le compte/utilisateur
// rattaché à l'intervenant. Sert à valider le compte bénéficiaire saisi avant
// la création de la ligne (cf. validateIntervenantCompte côté Apex).
const configIntervenant = [
    { intervenant: 'Apporteur',       apiIntervenant: "Apporteur d'Affaire", apiNameCom1: 'Com1_App__c',        apiNameCom2: 'Com2_App__c',          champLookup: 'LOOKUP_Apporteur_d_affaires__c' },
    { intervenant: 'Client',          apiIntervenant: 'Client',              apiNameCom1: 'Com1_Cli__c',        apiNameCom2: 'Com2_Cli__c',          champLookup: 'Compte__c' },
    { intervenant: 'Closer',          apiIntervenant: 'Closer',              apiNameCom1: 'Com1_Clo__c',        apiNameCom2: 'Com2_Clo__c',          champLookup: 'LOOKUP_Closer__c' },
    { intervenant: 'Cofrac',          apiIntervenant: 'Cofrac',              apiNameCom1: 'Com1_Cofr__c',       apiNameCom2: 'Com2_Cofr__c',         champLookup: 'LOOKUP_Cofrac__c' },
    { intervenant: 'Commerciaux',     apiIntervenant: 'Commerciaux',         apiNameCom1: 'Com1_Comm__c',       apiNameCom2: 'Com2_Comm__c',         champLookup: 'Commercial__c' },
    { intervenant: 'Confirmateur',    apiIntervenant: 'Confirmateur',        apiNameCom1: 'Com1_Conf__c',       apiNameCom2: 'Com2_Conf__c',         champLookup: 'Confirmateurs__c' },
    { intervenant: 'Previsiteur',     apiIntervenant: 'Pre-visiteur',        apiNameCom1: 'Com1_Prev__c',       apiNameCom2: 'Com2_Prev__c',         champLookup: 'LOOKUP_Pre_visiteur__c' },
    { intervenant: 'Regie',           apiIntervenant: 'Régie',               apiNameCom1: 'Montant_Calcule__c', apiNameCom2: 'Montant_Calcule_2__c', champLookup: 'Campagne_REGIE__c' },
    { intervenant: 'RespAdmin',       apiIntervenant: 'Responsable Admin',   apiNameCom1: 'Com1_RAdm__c',       apiNameCom2: 'Com2_RAdm__c',         champLookup: 'LOOKUP_Responsable_Admin__c' },
    { intervenant: 'RespPrevisite',   apiIntervenant: 'Responsable Previsite', apiNameCom1: 'Com1_RPrev__c',    apiNameCom2: 'Com2_RPrev__c',        champLookup: 'LOOKUP_Responsable_Previsite__c' },
    { intervenant: 'RespProd',        apiIntervenant: 'Responsable Prod',    apiNameCom1: 'Com1_RProd__c',      apiNameCom2: 'Com2_RProd__c',        champLookup: 'LOOKUP_Responsable_Prod__c' },
    { intervenant: 'Secretaire',      apiIntervenant: 'Secrétaire',          apiNameCom1: 'Com1_Sec__c',        apiNameCom2: 'Com2_Sec__c',          champLookup: 'LOOKUP_Secretaire__c' },
    { intervenant: 'Secretaire2',     apiIntervenant: 'Secretaire 2',        apiNameCom1: 'Com1_Sec2__c',       apiNameCom2: 'Com2_Sec2__c',         champLookup: 'LOOKUP_Secretaire_2__c' },
    { intervenant: 'SousTraitant',    apiIntervenant: 'Sous-traitant',       apiNameCom1: 'Com1_ST__c',         apiNameCom2: 'Com2_ST__c',           champLookup: 'LOOKUP_Sous_Traitant_PAC__c' },
    { intervenant: 'Telepro',         apiIntervenant: 'Telepro',             apiNameCom1: 'Com1_Tele__c',       apiNameCom2: 'Com2_Tele__c',         champLookup: 'LOOKUP_Telepro__c' },
    { intervenant: 'Auditeur',        apiIntervenant: 'Auditeur',            apiNameCom1: 'Com1_Aud__c',        apiNameCom2: 'Com2_Aud__c',          champLookup: 'LOOKUP_Auditeur__c' }
];

const API_Echeance1 = "EcheancesPaiement__c";
const API_Echeance2 = "EcheancesPaiement_2__c";

// TODO: A reverifier apres passage en prod
const echeancesOptions = [
    {
        label: "A la Visite/Previsite",
        condition: (r) => r.Pr_visite_Statut__c == "🟩Passage Effectué"
    },
    {
        label: "Au Devis Signé",
        condition: (r) => ["🟩Signé"].includes(r.Devis_Statut__c) 
    },
    {
        label: "A L'installation",
        condition: (r) => ["🟩Installation Cloturée"].includes(r.INSTALLATIONN_PAC__c)
    },
    {
        label: "Au Dossier Déposé",
        condition: (r) => ["Déposé", "🟪Déposé- Controle COFRAC", "🟪Déposé- Anomalie", "🟩Validation Délégataire", "Payé"].includes(r.PAC_Statut_CEE__c)
    },
    {
        label: "Au Solde CEE",
        condition: (r) => ["Payé", "🟩Validation Délégataire"].includes(r.PAC_Statut_CEE__c)
    },
    {
        label: "Au Solde MPR",
        condition: (r) => ["🟩Payé", "🟩Payé- Virement Reçu", "🟩Solde Demandé"].includes(r.PAC_Statut_MPR__c )
    },
];

// Champs gérables sur la ligne de facture. showIf(ctx) => booléen.
// ctx = { intervenant, ficheCeeId, numEcheance, assujettiTva, statut }
const configChampsLigne = [
    { apiName: 'Numero_Facture_Fournisseur__c', label: 'N° Facture Fournisseur', type: 'text',     showIf: () => false, required: false },
    { apiName: 'Date_Facture_Fournisseur__c',   label: 'Date Facture',           type: 'date',     showIf: () => false, required: false },
    { apiName: 'Date_Reception__c',             label: 'Date de Réception',      type: 'date',     showIf: () => false },
    // { apiName: 'Assujetti_TVA__c',              label: 'Assujetti TVA',          type: 'checkbox', showIf: (ctx) => ['SousTraitant', 'Cofrac', 'Apporteur'].includes(ctx.intervenant) },
    // { apiName: 'Taux_TVA__c',                   label: 'Taux TVA (%)',           type: 'number',   step: '0.01', showIf: (ctx) => ctx.assujettiTva === true },
    { apiName: 'Commentaire__c',                label: 'Commentaire',            type: 'textarea', showIf: () => true },
    { apiName: 'Motif_Rejet__c',                label: 'Motif de Rejet',         type: 'textarea', showIf: (ctx) => ctx.statut === 'Rejetée' }
];

const PRO_EXTRA_FIELDS = [
    'Pr_visite_Statut__c',
    'Devis_Statut__c',
    'Statut_Devis__c',
    'INSTALLATIONN_PAC__c',
    'PAC_Statut_CEE__c',
    'PAC_Statut_MPR__c'
];

const FIELDS = [
    ...configIntervenant.flatMap(c => [c.apiNameCom1, c.apiNameCom2]).filter(Boolean),
    API_Echeance1,
    API_Echeance2,
    ...PRO_EXTRA_FIELDS
].map(f => `Pro__c.${f}`);

function isEcheanceOk(label, dossier) {
    console.log('Vérification échéance - ', label, '- ', JSON.stringify(dossier));
    if (!label || !dossier) return false;
    const opt = echeancesOptions.find(o => o.label === label);
    if (!opt) return false;
    try { return !!opt.condition(dossier); } catch (e) { return false; }
}

function parseEcheance(raw) {
    const map = {};
    if (!raw || typeof raw !== 'string') return map;
    raw.split(';').forEach(pair => {
        const [key, ...rest] = pair.split(':');
        if (!key) return;
        const k = key.trim();
        const v = rest.join(':').trim();
        if (k) map[k] = v;
    });
    return map;
}

export default class PaiementFacturationDossier extends NavigationMixin(LightningElement) {
    _recordId;
    @api
    get recordId() { return this._recordId; }
    set recordId(v) {
        this._recordId = v;
        if (v) this.refreshLignes();
    }
    @track rows = [];
    @track selectedId;
    @track currentStep = 'recap';
    @track lignesMap = {};
    wiredRecordData;
    @track dossierName;
    @track ficheCeeId;
    @track com1Processed = false;
    @track com1LigneId;
    @track com2Processed = false;
    @track com2LigneId;
    @track loading = false;
    @track isCommunity = false;
    error;

    connectedCallback() {
        isCommunityUser()
            .then(res => { this.isCommunity = res === true; })
            .catch(() => { this.isCommunity = false; });
    }

    @track com1Form = {};
    @track com2Form = {};
    @track com1Statut = null;
    @track com2Statut = null;

    get steps() {
        const intervenantLabel = this.selectedIntervenant
            ? `Paiement ${this.selectedIntervenant}`
            : 'Paiement Intervenant';
        return [
            { label: 'Récapitulatif', value: 'recap' },
            { label: intervenantLabel, value: 'paiement' }
        ];
    }

    get selectedIntervenant() {
        const row = this.rows.find(r => r.id === this.selectedId);
        return row ? row.intervenant : null;
    }

    get selectedRow() {
        return this.rows.find(r => r.id === this.selectedId);
    }

    get isRecapStep() { return this.currentStep === 'recap'; }
    get isPaiementStep() { return this.currentStep === 'paiement'; }

    get hasCom1() { return this.selectedRow && this.selectedRow.com1 > 0; }
    get hasCom2() { return this.selectedRow && this.selectedRow.com2 > 0; }
    get com1Disabled() { return this.loading || !this.hasCom1 || !this.selectedEch1Ok; }
    get com2Disabled() { return this.loading || !this.hasCom2 || !this.selectedEch2Ok; }

    get selectedEch1Ok() { return this.selectedRow ? this.selectedRow.ech1Ok : false; }
    get selectedEch2Ok() { return this.selectedRow ? this.selectedRow.ech2Ok : false; }

    get com1Blocked() { return this.hasCom1 && !this.selectedEch1Ok; }
    get com2Blocked() { return this.hasCom2 && !this.selectedEch2Ok; }
    get com1Label() { return this.com1Processed ? 'Enregistrer Facturation 1' : 'Créer Facturation 1'; }
    get com2Label() { return this.com2Processed ? 'Enregistrer Facturation 2' : 'Créer Facturation 2'; }
    get com1Variant() { return this.com1Processed ? 'success' : 'brand'; }
    get com2Variant() { return this.com2Processed ? 'success' : 'brand'; }

    get com1LigneUrl() { return this.com1LigneId ? `/${this.com1LigneId}` : null; }
    get com2LigneUrl() { return this.com2LigneId ? `/${this.com2LigneId}` : null; }

    // Portail community : pas d'accès direct à la ligne de facturation.
    get showLigneFactureRow() { return !this.isCommunity; }

    // Portail community : pas de modification de la ligne une fois créée.
    get com1ShowButton() { return !(this.com1Processed && this.isCommunity); }
    get com2ShowButton() { return !(this.com2Processed && this.isCommunity); }

    // Lignes statiques d'informations
    get infoRows() {
        const r = this.selectedRow;
        if (!r) return [];
        const compteDisabled1 = this.loading || (this.com1Processed && this.isCommunity);
        const compteDisabled2 = this.loading || (this.com2Processed && this.isCommunity);
        return [
            {
                key: 'compte',
                info: 'Intervenant (Compte Bénéficiaire)',
                isComptePicker: true,
                show1: r.com1 > 0,
                show2: r.com2 > 0,
                compteVal1: this.com1Form.Intervenant_Compte__c || null,
                compteVal2: this.com2Form.Intervenant_Compte__c || null,
                disabled1: compteDisabled1,
                disabled2: compteDisabled2
            },
            { key: 'montant', info: 'Montant Total HT',          val1: r.com1 > 0 ? r.com1 : null, val2: r.com2 > 0 ? r.com2 : null, isCurrency: true },
            { key: 'num',     info: 'Numéro Échéance',        val1: r.com1 > 0 ? '1' : '-',     val2: r.com2 > 0 ? '2' : '-' },
            { key: 'ech',     info: 'Échéance Déclenchante',  val1: r.echeance1 || '-',         val2: r.echeance2 || '-' }
        ];
    }

    get showCom2Column() { return this.hasCom2; }

    // Champs éditables par commission selon configChampsLigne
    get editableFieldRows() {
        return configChampsLigne.map(c => {
            const ctx1 = {
                intervenant: this.selectedIntervenant,
                ficheCeeId: this.ficheCeeId,
                numEcheance: '1',
                // assujettiTva: this.com1Form.Assujetti_TVA__c,
                statut: this.com1Statut
            };
            const ctx2 = {
                intervenant: this.selectedIntervenant,
                ficheCeeId: this.ficheCeeId,
                numEcheance: '2',
                // assujettiTva: this.com2Form.Assujetti_TVA__c,
                statut: this.com2Statut
            };
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
                disabled2: this.loading || (this.com2Processed && this.isCommunity)
            };
        }).filter(f => f.show1 || f.show2);
    }

    safeShow(c, ctx) {
        try { return c.showIf(ctx); } catch (e) { return false; }
    }

    @wire(getRecord, { recordId: '$recordId', optionalFields: FIELDS })
    wiredRecord(result) {
        this.wiredRecordData = result;
        const { data, error } = result;
        if (data) {
            this.buildRows(data);
        } else if (error) {
            this.error = error;
        }
    }

    async refreshLignes() {
        if (!this._recordId) return;
        try {
            const data = await getLignesByDossier({ dossierId: this._recordId });
            const map = {};
            (data || []).forEach(l => {
                const key = `${l.Type_Intervenant__c}||${l.Numero_Echeance__c}`;
                map[key] = {
                    statut: l.Statut__c || 'Créée',
                    id: l.Id,
                    numeroFacture: l.Numero_Facture_Fournisseur__c,
                    dateFacture: l.Date_Facture_Fournisseur__c,
                    factureId: l.Facture__c
                };
            });
            this.lignesMap = map;
            if (this.wiredRecordData && this.wiredRecordData.data) {
                this.buildRows(this.wiredRecordData.data);
            }
        } catch (e) {
            // silencieux
        }
    }

    buildRows(data) {
        const ech1Map = parseEcheance(this.readString(data, API_Echeance1));
        const ech2Map = parseEcheance(this.readString(data, API_Echeance2));

        const dossierRec = {};
        PRO_EXTRA_FIELDS.forEach(f => { dossierRec[f] = this.readString(data, f); });
        this._dossierRec = dossierRec;

        this.rows = configIntervenant
            .map(cfg => {
                const com1 = this.readNumber(data, cfg.apiNameCom1);
                const com2 = this.readNumber(data, cfg.apiNameCom2);
                return { cfg, com1, com2 };
            })
            .filter(r => r.com1 > 0 || r.com2 > 0)
            .map(r => {
                const ech1Label = ech1Map[r.cfg.apiIntervenant] || '';
                const ech2Label = ech2Map[r.cfg.apiIntervenant] || '';
                const ech1Ok = r.com1 > 0 && isEcheanceOk(ech1Label, dossierRec);
                const ech2Ok = r.com2 > 0 && isEcheanceOk(ech2Label, dossierRec);
                const ech1Applicable = r.com1 > 0;
                const ech2Applicable = r.com2 > 0;
                const warningOrder = ech2Ok && ech1Applicable && !ech1Ok;
                const s1 = this.resolveStatut(r.cfg.apiIntervenant, '1', r.com1, ech1Applicable && !ech1Ok);
                const s2 = this.resolveStatut(r.cfg.apiIntervenant, '2', r.com2, ech2Applicable && !ech2Ok);
                return {
                    id: r.cfg.intervenant,
                    intervenant: r.cfg.intervenant,
                    com1: r.com1,
                    com2: r.com2,
                    echeance1: ech1Label,
                    echeance2: ech2Label,
                    ech1Ok,
                    ech2Ok,
                    ech1Applicable,
                    ech2Applicable,
                    warningOrder,
                    statutPaiement1: s1.label,
                    statutBadgeClass1: s1.badgeClass,
                    statutPaiement2: s2.label,
                    statutBadgeClass2: s2.badgeClass,
                    _cfg: r.cfg
                };
            })
            .filter(row => row.ech1Ok || row.ech2Ok);

        if (this.selectedRow) {
            const api = this.selectedRow._cfg.apiIntervenant;
            const l1 = this.lignesMap[`${api}||1`];
            const l2 = this.lignesMap[`${api}||2`];
            this.com1Processed = !!l1;
            this.com1LigneId = l1 ? l1.id : null;
            this.com1Statut = l1 ? l1.statut : null;
            this.com2Processed = !!l2;
            this.com2LigneId = l2 ? l2.id : null;
            this.com2Statut = l2 ? l2.statut : null;
        }
    }

    resolveStatut(apiIntervenant, numEch, montant, isStandby) {
        if (montant <= 0) {
            return { label: 'N/A', badgeClass: 'pf-badge-notUsed pf-badge-muted-notUsed' };
        }
        const key = `${apiIntervenant}||${numEch}`;
        const entry = this.lignesMap[key];
        if (entry) {
            return { label: entry.statut, badgeClass: 'pf-badge pf-badge-success' };
        }
        if (isStandby) {
            return { label: 'Standby', badgeClass: 'pf-badge pf-badge-muted' };
        }
        return { label: 'À payer', badgeClass: 'pf-badge pf-badge-danger' };
    }

    readNumber(record, apiName) {
        if (!apiName) return 0;
        const f = record.fields?.[apiName];
        const v = f ? f.value : null;
        return v == null ? 0 : Number(v);
    }

    readString(record, apiName) {
        if (!apiName) return null;
        const f = record.fields?.[apiName];
        return f ? f.value : null;
    }

    get hasRows() { return this.rows.length > 0; }
    get hasSelectionDisabled() { return !this.selectedId; }

    get displayRows() {
        return this.rows.map(r => {
            const baseClass = r.id === this.selectedId
                ? 'slds-hint-parent row-clickable row-selected'
                : 'slds-hint-parent row-clickable';
            return {
                ...r,
                selected: r.id === this.selectedId,
                rowClass: r.warningOrder ? `${baseClass} row-warning` : baseClass
            };
        });
    }

    handleSelect(event) {
        event.stopPropagation();
        this.selectedId = event.target.dataset.id;
    }

    handleRowClick(event) {
        this.selectedId = event.currentTarget.dataset.id;
    }

    async handleNext() {
        const row = this.selectedRow;
        if (!row) return;

        const api = row._cfg.apiIntervenant;
        const l1 = this.lignesMap[`${api}||1`];
        const l2 = this.lignesMap[`${api}||2`];
        this.com1Processed = !!l1;
        this.com1LigneId = l1 ? l1.id : null;
        this.com1Statut = l1 ? l1.statut : null;
        this.com2Processed = !!l2;
        this.com2LigneId = l2 ? l2.id : null;
        this.com2Statut = l2 ? l2.statut : null;

        try {
            const info = await getDossierInfo({ dossierId: this.recordId });
            this.dossierName = info ? info.Name : null;
            this.ficheCeeId = info ? info.Fiche_CEE__c : null;
        } catch (e) {
            this.ficheCeeId = null;
        }

        // Initialise les formulaires depuis la BD si ligne existante, sinon vide
        this.com1Form = {};
        this.com2Form = {};
        if (l1) await this.loadLigneIntoForm(1, l1.id);
        if (l2) await this.loadLigneIntoForm(2, l2.id);

        this.currentStep = 'paiement';
    }

    async loadLigneIntoForm(num, ligneId) {
        try {
            const data = await getLigneFacture({ ligneId });
            const form = {};
            configChampsLigne.forEach(c => {
                form[c.apiName] = data ? data[c.apiName] : null;
            });
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
        if (num === '1') {
            this.com1Form = { ...this.com1Form, [api]: val };
        } else {
            this.com2Form = { ...this.com2Form, [api]: val };
        }
    }

    handleIntervenantCompteChange(event) {
        const num = event.target.dataset.num;
        const val = (event.detail && event.detail.recordId) || null;
        if (num === '1') {
            this.com1Form = { ...this.com1Form, Intervenant_Compte__c: val };
        } else {
            this.com2Form = { ...this.com2Form, Intervenant_Compte__c: val };
        }
    }

    handlePayCom1() { this.saveCommission(1); }
    handlePayCom2() { this.saveCommission(2); }

    async saveCommission(num) {
        const row = this.selectedRow;
        if (!row) return;

        const processed = num === 1 ? this.com1Processed : this.com2Processed;
        const ligneId = num === 1 ? this.com1LigneId : this.com2LigneId;
        const form = num === 1 ? this.com1Form : this.com2Form;
        const montant = num === 1 ? row.com1 : row.com2;
        const echeance = num === 1 ? row.echeance1 : row.echeance2;

        this.loading = true;
        try {
            if (!processed) {
                const newId = await createLigneFacture({
                    dossierId: this.recordId,
                    typeIntervenant: row._cfg.apiIntervenant,
                    montant,
                    numEcheance: num,
                    echeanceDeclenchante: echeance,
                    numeroFactureFournisseur: form.Numero_Facture_Fournisseur__c || '',
                    dateFactureFournisseur: form.Date_Facture_Fournisseur__c || '',
                    intervenantCompteId: form.Intervenant_Compte__c || null,
                    champLookupApi: row._cfg.champLookup || null
                });
                if (num === 1) { this.com1Processed = true; this.com1LigneId = newId; }
                else { this.com2Processed = true; this.com2LigneId = newId; }

                // Applique les autres champs via update (le compte bénéficiaire est déjà
                // posé et validé à la création côté Apex).
                const extra = this.pickExtraFields(form);
                if (Object.keys(extra).length) {
                    await updateLigneFacture({ ligneId: newId, fields: extra });
                }
                this.toast('Ligne créée', `Commission ${num} - ligne enregistrée`, 'success');
            } else {
                // Vérification compte bénéficiaire vs intervenant du dossier
                // (rejouée aussi à la modification, pas uniquement à la création).
                await verifierIntervenantCompte({
                    dossierId: this.recordId,
                    champLookupApi: row._cfg.champLookup || null,
                    intervenantCompteId: form.Intervenant_Compte__c || null,
                    typeIntervenant: row._cfg.apiIntervenant
                });

                const toSave = {};
                const ctx = {
                    intervenant: this.selectedIntervenant,
                    ficheCeeId: this.ficheCeeId,
                    numEcheance: String(num),
                    // assujettiTva: form.Assujetti_TVA__c,
                    statut: num === 1 ? this.com1Statut : this.com2Statut
                };
                configChampsLigne.forEach(c => {
                    if (!this.safeShow(c, ctx)) return;
                    toSave[c.apiName] = form[c.apiName] ?? null;
                });
                toSave.Intervenant_Compte__c = form.Intervenant_Compte__c ?? null;
                await updateLigneFacture({ ligneId, fields: toSave });
                this.toast('Ligne mise à jour', `Commission ${num} - modifications enregistrées`, 'success');
            }

            await this.refreshLignes();
        } catch (e) {
            this.toast('Erreur', (e.body && e.body.message) || e.message || 'Erreur inconnue', 'error');
        } finally {
            this.loading = false;
        }
    }

    pickExtraFields(form) {
        const out = {};
        configChampsLigne.forEach(c => {
            if (c.apiName === 'Numero_Facture_Fournisseur__c') return;
            if (c.apiName === 'Date_Facture_Fournisseur__c') return;
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

    // -- Élargissement de la modale (quick action) ----------------------------

    renderedCallback() {
        if (this._modalWidened) return;
        const host = this.template.host;
        const modal = host && host.closest
            ? host.closest('.slds-modal__container')
            : null;
        if (modal) {
            modal.style.width = '95vw';
            modal.style.maxWidth = '1400px';
            this._modalWidened = true;
        }
    }
}