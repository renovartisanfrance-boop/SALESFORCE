import { api, LightningElement, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';

export default class Lwc008_dynamicObjectForm extends LightningElement {
    @wire(CurrentPageReference)
    getCurrentPageReference(currentPageReference) {
        if (currentPageReference && currentPageReference.attributes?.objectApiName) {
            this.expObjectApiName = currentPageReference.attributes?.objectApiName;
            // console.log('Current Page Reference:', currentPageReference);
            // console.log('Object API Name:', this.expObjectApiName);
        }
    }

    _expObjectApiName;
    @api set expObjectApiName(value) {
        console.log('Setting expObjectApiName:', value);
        this._expObjectApiName = value;
    }
    get expObjectApiName() {
        return this._expObjectApiName;
    }
}