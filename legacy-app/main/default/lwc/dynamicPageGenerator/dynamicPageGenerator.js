import { LightningElement,api, wire} from 'lwc';
import getForm from '@salesforce/apex/FieldSetController.getForm';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';


export default class DynamicPageGenerator extends NavigationMixin(LightningElement) {

    recordTypeId
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            this.recordTypeId = currentPageReference.state?.recordTypeId || 
                            currentPageReference.state?.c__recordTypeId;
            console.log("Record type ID => ", this.recordTypeId )
        }
    }
    


    _objectName;
    set objectName(value) {
        // console.log('Setting objectName:', value);
        this._objectName = value;
    }
    @api get objectName() {
        console.log('Getting objectName:', this._objectName);
        return this._objectName;
    }
    _recordId;
    set recordId(value) {
        this._recordId = value;
    }
    @api
    get recordId() {
        return this._recordId;
    }
    _fieldSet;
    set fieldSet(value) {
        console.log('Setting fieldSet:', value);
        this._fieldSet = value;
    }
    @api
    get fieldSet() {
        return this._fieldSet;
    }
    _title;
    set title(value) {
        this._title = value;
    }
    @api
    get title() {
        return this._title;
    }


    fields;

    onSubmit = false;

    get getOnSubmit(){
        return this.onSubmit;
    }

    // @wire(getForm, { recordId: "$recordId", objectName: "$objectName", fieldSetName: "$fieldSet"})
    // wiredForm({ error, data }) {
    //     console.log('Wired Form wiredForm');
    //     console.log('RecordId:', this.recordId);
    //     console.log('ObjectName:', this._objectName);
    //     console.log('FieldSet:', this.fieldSet);
    //     if (data) {
    //         console.log('Data:', JSON.stringify(data));
    //         this.fields = data.Fields;
    //         this.error = undefined;
    //     } else if (error) {
    //         console.log(error);
    //         this.error = error;
    //     }
    // }
    
    connectedCallback()
    {
        console.log('Connected Callback');
        setTimeout(() => {
            getForm({ recordId: this.recordId, objectName: this.objectName, fieldSetName: this.fieldSet, recordTypeId: this.recordTypeId})
            .then(result => {
                console.log('Data:', JSON.stringify(result));
                if (result) {
                    this.fields = result.Fields;
                    // set class based on isVisible:
                    this.fields = this.fields.map(f => ({
                        ...f, Id: this.getRandomNumber(), className : f.isVisible ? 'slds-show' : 'slds-hide',
                    }));
                    this.error = undefined;
                }
            }) .catch(error => {
                console.log(error);
                this.error = error;
            }); 
        }, 500);
    }

    getRandomNumber(){
        // date + Math.random() * 1000000;
        return new Date().getTime() + Math.floor(Math.random() * 1000000);
    }

    // saveClick(event)
    // {
    //     event.preventDefault();
    //     if(!this.validateFields()) {
    //         this.showMessage('Please fill all the required fields.','error');
    //         return;
    //     }
    //     this.onSubmit = true;
    //     const inputFields = event.detail.fields;
    //     this.template.querySelector('lightning-record-edit-form').submit(inputFields);
    // }
    saveClick(event) {
        event.preventDefault();

        if (!this.validateFields()) {
            this.showMessage("Veuillez vérifier les champs requis.", "error");
            return;
        }
        this.onSubmit = true;
        let inputFields = event.detail.fields;
         // Set the record type before saving
        if (this.recordTypeId) {
            inputFields.RecordTypeId = this.recordTypeId;
        }
        this.template.querySelector('lightning-record-edit-form').submit(inputFields);
    }
    validateFields() {
        // return [...this.template.querySelectorAll("lightning-input-field")].reduce((validSoFar, field) => {
        //     return (validSoFar && field.reportValidity());
        // }, true);
        return [...this.template.querySelectorAll('lightning-input')]
        .reduce((validSoFar, inputCmp) => {
            inputCmp.reportValidity();
            return validSoFar && inputCmp.checkValidity();
        }, true);
    }


    handleSuccess(e)
    {
        // console.log("Result : ", JSON.stringify(e.detail?.id));
        // console.log("Result : ", JSON.stringify(e.detail));
        this.onSubmit = false;
        // this.showMessage('Record Saved Successfully','success');
        this.showMessage('Enregistrement créé avec succès', 'success');
        console.log('trye close modale:');
        this.closeModal();

        // Navigate to the recordId:
        const recordId = e.detail?.id
        this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: recordId,
                        //objectApiName: 'Case', // objectApiName is optional
                        actionName: 'view'
                    }
                });

        // clear the form
        // this.template.querySelector('lightning-record-edit-form').reset();
        const inputFields = this.template.querySelectorAll(
            'lightning-input-field'
        );
        if (inputFields) {
            inputFields.forEach(field => {
                // if(field.name === "email") {
                    field.reset();
                // }
            });
        }
    }
    handleError(e)
    {
        this.onSubmit = false;
        this.template.querySelector('[data-id="message"]').setError(e.detail.detail);
        e.preventDefault();
    }

    showMessage(message,variant)
    {
        const event = new ShowToastEvent({
            title: 'Record Save',
            variant: variant,
            mode: 'dismissable',
            message: message
        });
        this.dispatchEvent(event);
    }

    closeModal() {
        // this.dispatchEvent(new CloseActionScreenEvent());
        // this.dispatchEvent(new CustomEvent("closeauraquickaction"));
        // conso
        // get button with this selector class: slds-button slds-button_icon slds-modal__close closeIcon slds-button_icon-bare
        
        // const closeButton = this.template.querySelector('.slds-button_icon.slds-modal__close');
        // if (closeButton) {
        //     closeButton.click();
        //     console.log('Close button clicked');
        // } else {
        //     console.log('Close button not found');
        // }

        const valueChangeEvent = new CustomEvent("saverecord", {
            detail: { type : "close" }
          });
        // Fire the custom event
        this.dispatchEvent(valueChangeEvent);
        console.log('Close action fired in DynamicPageGenerator');
    }
}