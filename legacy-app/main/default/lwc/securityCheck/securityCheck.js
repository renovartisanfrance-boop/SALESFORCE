import { LightningElement, api, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import Id from '@salesforce/user/Id';
import ACCES_FIELD from '@salesforce/schema/User.AccesAccueilPortail__c';

export default class SecurityCheck extends LightningElement {
    @api typePage;
    
    userId = Id;
    hasAccess = false;
    isLoading = true;

    @wire(getRecord, { 
        recordId: '$userId', 
        fields: [ACCES_FIELD] 
    })
    wiredUser({ error, data }) {
        this.isLoading = false;
        
        if (data) {
            const accesPortail = data.fields.AccesAccueilPortail__c?.value;
            
            if (accesPortail) {
                // Convertir la multipicklist en tableau
                const accessList = accesPortail.split(';');
                
                // Vérifier si le type de page existe dans la liste
                this.hasAccess = accessList.includes(this.typePage);
            } else {
                this.hasAccess = false;
            }
        }
        
        if (error) {
            console.error('Erreur lors de la récupération des accès:', error);
            this.hasAccess = false;
        }
    }

    get showAccessDenied() {
        return !this.isLoading && !this.hasAccess;
    }

    get showContent() {
        return !this.isLoading && this.hasAccess;
    }
}