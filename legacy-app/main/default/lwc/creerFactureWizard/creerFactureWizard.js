import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getFieldSetFields from '@salesforce/apex/FieldSetController.getFieldSetFields';
import createFactureAvecLignes from '@salesforce/apex/FacturesController.createFactureAvecLignes';
import getAcomptesDisponibles from '@salesforce/apex/FacturesController.getAcomptesDisponibles';
import getRecordTypeInfo from '@salesforce/apex/LC020_FieldMetadataService.getRecordTypeInfo';

const OBJECT_API = 'Facture__c';

// Type de facture : forcé « Reçue » par défaut côté serveur (trigger), affiché en
// lecture seule dans le formulaire (les factures émises seront traitées plus tard).
const TYPE_FACTURE_FIELD = 'TypeFacture__c';
const TYPE_FACTURE_DEFAULT = 'Reçue';

const RT_FIELDSET_MAP = {
    'Classique': 'FS_nouvelleFacture_Classique',
    'Acompte':   'FS_nouvelleFacture_Acompte',
    'Avoir':    'FS_nouvelleFacture_Avoir'
};

export default class CreerFactureWizard extends NavigationMixin(LightningElement) {
    _recordTypeId;

    @api
    get recordTypeId() { return this._recordTypeId; }
    set recordTypeId(v) {
        this._recordTypeId = v;
        this.resolveRt();
    }

    @track currentStep = 'infos';
    @track fields = [];
    @track values = {};
    @track selectedLigneIds = [];
    // Acomptes (avances) du bénéficiaire rattachables à la facture Classique.
    @track acomptes = [];
    @track selectedAcompteIds = new Set();
    @track loading = false;
    @track error;

    rtDevName;
    fieldSetName;

    async resolveRt() {
        if (!this._recordTypeId) return;
        try {
            const info = await getRecordTypeInfo({ recordTypeId: this._recordTypeId });
            if (info && info.DeveloperName) {
                this.rtDevName = info.DeveloperName;
                this.fieldSetName = RT_FIELDSET_MAP[this.rtDevName] || RT_FIELDSET_MAP['Classique'];
                this.loadFieldSet();
            }
        } catch (e) {
            this.error = e;
        }
    }

    async loadFieldSet() {
        if (!this.fieldSetName) return;
        try {
            const data = await getFieldSetFields({ objectName: OBJECT_API, fieldSetName: this.fieldSetName });
            // Type de facture : pré-rempli « Reçue » (lecture seule) tant que non saisi,
            // pour que la valeur survive aux re-mappages (capture des saisies).
            if (!this.values[TYPE_FACTURE_FIELD]) {
                this.values = { ...this.values, [TYPE_FACTURE_FIELD]: TYPE_FACTURE_DEFAULT };
            }
            this.fields = (data.champs || []).map(f => ({
                apiName: f.apiName,
                isRequired: f.isRequired,
                // TypeFacture__c : affiché en lecture seule.
                isReadOnly: f.apiName === TYPE_FACTURE_FIELD,
                savedValue: this.values[f.apiName]
            }));
        } catch (e) {
            this.error = e;
        }
    }

    captureCurrentValues() {
        const inputs = this.template.querySelectorAll('lightning-input-field');
        const collected = { ...this.values };
        inputs.forEach(i => { collected[i.fieldName] = i.value; });
        this.values = collected;
        this.fields = this.fields.map(f => ({ ...f, savedValue: this.values[f.apiName] }));
    }

    get isClassique() { return this.rtDevName === 'Classique'; }

    get steps() {
        const s = [{ value: 'infos', label: 'Informations' }];
        if (this.isClassique) {
            s.push({ value: 'acomptes', label: 'Acomptes (Avances)' });
            s.push({ value: 'lignes', label: 'Lignes Facture' });
        }
        return s;
    }

    get isInfosStep() { return this.currentStep === 'infos'; }
    get isAcomptesStep() { return this.currentStep === 'acomptes'; }
    get isLignesStep() { return this.currentStep === 'lignes'; }

    // Montant HT saisi à l'étape "Informations", transmis au composant de liaison
    // pour afficher le rapprochement (Montant HT / Écart) dès la sélection.
    get montantHtSaisi() { return this.values['MontantHT__c']; }
    // Bénéficiaire (compte) saisi à l'étape "Informations", transmis au composant
    // de liaison pour ne proposer que les lignes du même intervenant.
    get destinataireCompteIdSaisi() { return this.values['Destinataire_Compte__c']; }
    get infosStepClass() { return this.isInfosStep ? '' : 'slds-hide'; }
    get objectApiName() { return OBJECT_API; }
    get nextLabel() { return this.isClassique ? 'Suivant' : 'Créer la facture'; }

    // -- Acomptes (avances) ------------------------------------------------

    async loadAcomptes() {
        const dest = this.destinataireCompteIdSaisi;
        if (!dest) {
            this.acomptes = [];
            this.selectedAcompteIds = new Set();
            return;
        }
        this.loading = true;
        try {
            const data = await getAcomptesDisponibles({ destinataireCompteId: dest });
            this.acomptes = data || [];
            // Purge de la sélection : ne garder que les acomptes encore proposés
            // (le bénéficiaire a pu changer après un retour à l'étape Informations).
            const ids = new Set(this.acomptes.map(a => a.Id));
            const kept = new Set();
            this.selectedAcompteIds.forEach(id => { if (ids.has(id)) kept.add(id); });
            this.selectedAcompteIds = kept;
        } catch (e) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Erreur',
                message: (e.body && e.body.message) || e.message || 'Erreur lors du chargement des acomptes',
                variant: 'error'
            }));
        } finally {
            this.loading = false;
        }
    }

    get hasAcomptes() { return this.acomptes.length > 0; }

    get acomptesDisplay() {
        return this.acomptes.map(a => {
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
        this.acomptes.forEach(a => {
            if (this.selectedAcompteIds.has(a.Id) && a.MontantHT__c) {
                total += Number(a.MontantHT__c);
            }
        });
        return total;
    }

    // Total HT attendu des lignes à l'étape suivante : HT facture + acomptes.
    get montantHtAttendu() {
        const ht = Number(this.montantHtSaisi || 0);
        return (isNaN(ht) ? 0 : ht) + this.totalAcomptesHT;
    }

    get acompteSelectionSummary() {
        return `${this.selectedAcompteIds.size} sélectionné(s) sur ${this.acomptes.length}`;
    }

    toggleAcompte(id) {
        if (!id) return;
        const set = new Set(this.selectedAcompteIds);
        if (set.has(id)) set.delete(id);
        else set.add(id);
        this.selectedAcompteIds = set;
    }

    handleAcompteToggleRow(event) {
        this.toggleAcompte(event.currentTarget.dataset.id);
    }

    handleAcompteCheckboxChange(event) {
        event.stopPropagation();
        this.toggleAcompte(event.target.dataset.id);
    }

    handleNext() {
        const inputs = this.template.querySelectorAll('lightning-input-field');
        let allValid = true;
        const collected = {};
        inputs.forEach(i => {
            if (!i.reportValidity()) allValid = false;
            collected[i.fieldName] = i.value;
        });
        if (!allValid) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Champs invalides', message: 'Veuillez compléter les champs requis.', variant: 'error'
            }));
            return;
        }
        this.values = collected;
        this.fields = this.fields.map(f => ({ ...f, savedValue: this.values[f.apiName] }));
        if (this.isClassique) {
            this.currentStep = 'acomptes';
            this.loadAcomptes();
        } else {
            this.handleSave();
        }
    }

    handleAcomptesNext() { this.currentStep = 'lignes'; }

    handleBack() {
        // Lignes -> Acomptes -> Informations
        this.currentStep = this.isLignesStep ? 'acomptes' : 'infos';
    }

    handleSelectionChange(event) {
        this.selectedLigneIds = event.detail.selectedIds || [];
    }

    async handleSave() {
        this.loading = true;
        try {
            const payload = { ...this.values };
            if (this.recordTypeId) payload.RecordTypeId = this.recordTypeId;
            const id = await createFactureAvecLignes({
                fields: payload,
                ligneIds: this.isClassique ? this.selectedLigneIds : [],
                acompteIds: this.isClassique ? Array.from(this.selectedAcompteIds) : []
            });
            this.dispatchEvent(new ShowToastEvent({
                title: 'Facture créée',
                message: this.isClassique ? `${this.selectedLigneIds.length} ligne(s) liée(s)` : 'Facture créée',
                variant: 'success'
            }));
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId: id, objectApiName: OBJECT_API, actionName: 'view' }
            });
        } catch (e) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Erreur',
                message: (e.body && e.body.message) || e.message || 'Erreur',
                variant: 'error'
            }));
        } finally {
            this.loading = false;
        }
    }

    handleCancel() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: OBJECT_API, actionName: 'list' }
        });
    }
}