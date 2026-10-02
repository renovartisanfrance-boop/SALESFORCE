import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getFieldSetFields from '@salesforce/apex/FieldSetController.getFieldSetFields';
import createLettrageAvecFactures from '@salesforce/apex/LettrageFacturesController.createLettrageAvecFactures';

const OBJECT_API = 'Lettrage__c';
const FIELDSET_NAME = 'FS_nouveauLettrage';

export default class CreerLettrageWizard extends NavigationMixin(LightningElement) {
    @track currentStep = 'infos';
    @track fields = [];
    @track values = {};
    @track selectedFactureIds = [];
    @track totalFactures = 0;
    @track loading = false;
    error;

    connectedCallback() {
        this.loadFieldSet();
    }

    async loadFieldSet() {
        try {
            const data = await getFieldSetFields({ objectName: OBJECT_API, fieldSetName: FIELDSET_NAME });
            this.fields = (data.champs || []).map(f => ({
                apiName: f.apiName,
                isRequired: f.isRequired,
                savedValue: this.values[f.apiName]
            }));
        } catch (e) {
            this.error = e;
        }
    }

    get steps() {
        return [
            { value: 'infos', label: 'Informations' },
            { value: 'factures', label: 'Factures lettrées' }
        ];
    }

    get isInfosStep() { return this.currentStep === 'infos'; }
    get isFacturesStep() { return this.currentStep === 'factures'; }
    get infosStepClass() { return this.isInfosStep ? '' : 'slds-hide'; }
    get objectApiName() { return OBJECT_API; }

    // -- Montants --------------------------------------------------------------

    get montantLettrage() {
        const v = this.values.Montant_Total__c;
        return v == null || v === '' ? 0 : Number(v);
    }

    get ecart() {
        return Number((this.montantLettrage - this.totalFactures).toFixed(2));
    }

    get montantsCorrespondent() {
        return this.selectedFactureIds.length > 0 && this.ecart === 0;
    }

    get matchClass() {
        return this.montantsCorrespondent
            ? 'pf-match pf-match-ok'
            : 'pf-match pf-match-ko';
    }

    get matchLabel() {
        if (this.selectedFactureIds.length === 0) {
            return 'Sélectionnez au moins une facture';
        }
        if (this.montantsCorrespondent) {
            return 'Les montants correspondent';
        }
        const signe = this.ecart > 0 ? '+' : '';
        return `Écart de ${signe}${this.ecart.toFixed(2)} € entre le lettrage et les factures`;
    }

    get saveDisabled() {
        return this.loading || !this.montantsCorrespondent;
    }

    // -- Navigation ------------------------------------------------------------

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
                title: 'Champs invalides',
                message: 'Veuillez compléter les champs requis.',
                variant: 'error'
            }));
            return;
        }
        this.values = collected;
        this.fields = this.fields.map(f => ({ ...f, savedValue: this.values[f.apiName] }));
        this.currentStep = 'factures';
    }

    handleBack() { this.currentStep = 'infos'; }

    handleSelectionChange(event) {
        this.selectedFactureIds = event.detail.selectedIds || [];
        this.totalFactures = event.detail.total || 0;
    }

    async handleSave() {
        if (this.selectedFactureIds.length === 0) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Aucune facture',
                message: 'Sélectionnez au moins une facture à lettrer.',
                variant: 'error'
            }));
            return;
        }
        if (!this.montantsCorrespondent) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Montants incohérents',
                message: this.matchLabel,
                variant: 'error'
            }));
            return;
        }
        this.loading = true;
        try {
            const id = await createLettrageAvecFactures({
                fields: { ...this.values },
                factureIds: this.selectedFactureIds
            });
            this.dispatchEvent(new ShowToastEvent({
                title: 'Lettrage créé',
                message: `${this.selectedFactureIds.length} facture(s) lettrée(s)`,
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