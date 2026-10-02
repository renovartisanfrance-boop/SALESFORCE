import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import {
    getRecord,
    getFieldValue,
    updateRecord
} from 'lightning/uiRecordApi';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';

export default class ChangerStatut extends LightningElement {
    // Id de l'enregistrement (auto sur page de détail interne ; {!recordId} en Experience Cloud).
    @api recordId;
    // API Name de l'objet (ex. Facture__c).
    @api objectApiName = 'Facture__c';
    // API Name du champ picklist à modifier (ex. Statut__c).
    @api fieldApiName = 'Statut__c';
    // Personnalisation de l'UI.
    @api cardTitle = 'Statut';
    // Conservée pour compatibilité Experience Builder : non utilisée (libellé calculé).
    @api buttonLabel = 'Enregistrer';
    // Lecture seule : affiche le chemin sans permettre la modification.
    _readOnly = false;

    @api
    get readOnly() {
        return this._readOnly;
    }
    set readOnly(value) {
        console.warn(value, 'La propriété readOnly est obsolète. Utilisez showAction=false pour un affichage en lecture seule.');
        this._readOnly = value === true || value === 'true';
    }

    @track _picklistValues = [];
    currentValue;
    selectedValue;
    saving = false;
    recordTypeId;
    errorMessage;

    // ---- Références dérivées des propriétés (réactives) ----
    get fieldRef() {
        return { objectApiName: this.objectApiName, fieldApiName: this.fieldApiName };
    }

    get fields() {
        return [`${this.objectApiName}.${this.fieldApiName}`];
    }

    // ---- Wires ----
    @wire(getObjectInfo, { objectApiName: '$objectApiName' })
    objectInfo({ data }) {
        if (data) {
            this.recordTypeId = data.defaultRecordTypeId;
        }
    }

    @wire(getPicklistValues, { recordTypeId: '$recordTypeId', fieldApiName: '$fieldRef' })
    picklist({ data, error }) {
        if (data) {
            this._picklistValues = data.values;
            this.errorMessage = undefined;
        } else if (error) {
            this.errorMessage = this.extractError(error);
        }
    }

    @wire(getRecord, { recordId: '$recordId', fields: '$fields' })
    record({ data, error }) {
        if (data) {
            this.currentValue = getFieldValue(data, this.fields[0]);
            if (this.selectedValue === undefined) {
                this.selectedValue = this.currentValue;
            }
        } else if (error) {
            this.errorMessage = this.extractError(error);
        }
    }

    // ---- État d'affichage ----
    get isReady() {
        return !!this.recordId && this._picklistValues.length > 0;
    }

    get currentIndex() {
        return this._picklistValues.findIndex((v) => v.value === this.currentValue);
    }

    // Construit les étapes du chemin avec leurs classes SLDS.
    get stages() {
        const currentIdx = this.currentIndex;
        return this._picklistValues.map((v, idx) => {
            let state;
            if (idx < currentIdx) {
                state = 'slds-is-complete';
            } else if (idx === currentIdx) {
                state = 'slds-is-current';
            } else {
                state = 'slds-is-incomplete';
            }
            const isSelected = v.value === this.selectedValue;
            const itemClass =
                'slds-path__item ' + state + (isSelected ? ' slds-is-active' : '');
            return {
                value: v.value,
                label: v.label,
                itemClass,
                ariaSelected: isSelected ? 'true' : 'false',
                tabindex: this.readOnly ? '-1' : isSelected ? '0' : '-1'
            };
        });
    }

    get selectedLabel() {
        const found = this._picklistValues.find((v) => v.value === this.selectedValue);
        return found ? found.label : '';
    }

    get computedButtonLabel() {
        return `Marquer comme « ${this.selectedLabel} »`;
    }

    get buttonDisabled() {
        return this.saving || this.selectedValue === this.currentValue;
    }

    get showAction() {
        return !this.readOnly;
    }

    // ---- Interactions ----
    handleSelect(event) {
        event.preventDefault();
        if (this.readOnly) {
            return;
        }
        this.selectedValue = event.currentTarget.dataset.value;
    }

    async handleSave() {
        this.saving = true;
        this.errorMessage = undefined;
        const fields = { Id: this.recordId };
        fields[this.fieldApiName] = this.selectedValue;
        try {
            await updateRecord({ fields });
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Statut mis à jour',
                    message: `Statut passé à « ${this.selectedLabel} ».`,
                    variant: 'success'
                })
            );
        } catch (e) {
            this.errorMessage = this.extractError(e);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Erreur',
                    message: this.errorMessage,
                    variant: 'error'
                })
            );
        } finally {
            this.saving = false;
        }
    }

    extractError(e) {
        if (Array.isArray(e?.body)) {
            return e.body.map((err) => err.message).join(', ');
        }
        return e?.body?.message || e?.message || 'Erreur inconnue';
    }
}