import { LightningElement,api,track,wire} from 'lwc';
import getMapDeveloperNameIdsByDevNames from '@salesforce/apex/lWC003_DisplayReportChartController.getMapDeveloperNameIdsByDevNames';
import ACOUNTNAME_FIELD from '@salesforce/schema/Account.Name';
// import BROKERCEDANTCODE_FIELD from '@salesforce/schema/Account.brokerCedentCode__c';
// import BROKERCEDANTCODE_FIELD from '@salesforce/schema/Account.brokerCedentCode__c';
import { getRecord,getRecords } from 'lightning/uiRecordApi';
import { NavigationMixin } from 'lightning/navigation';
import { CurrentPageReference } from 'lightning/navigation';
import { getPicklistValues } from 'lightning/uiObjectInfoApi';       


export default class LWC003_DisplayReportChart extends LightningElement {

    @track showSpinner = true;
    @track showCharts = true ;

    @track height = 0 ;

    @api recordId;
    @api title;
    @api developerNameReport1 = 'null' ;
    @api developerNameReport2 = 'null' ;
    @api developerNameReport3 = 'null' ;
    @api developerNameReport4 = 'null' ;
    @api developerNameReport5 = 'null' ;
    @api developerNameReport6 = 'null' ;
    @api column ;
    @track accountName;
    @track idReportGlobale = 'null';

    @track urlVf = '/apex/VF_DisplayReportsChart?';

    connectedCallback() {
        console.log(' >>> LWC003_DisplayReportChart.connectedCallback() <<<');
    }

    @wire(getRecord, { recordId: '$recordId', fields: [ACOUNTNAME_FIELD/*,BROKERCEDANTCODE_FIELD*/] })
    wiredAccount({ error, data }) {
        this.showSpinner = true;
        if (data) {
            console.log('data'+JSON.stringify(data));
            // this.accountName = data.fields.brokerCedentCode__c.value;
            // console.log(' >>> LWC003_DisplayReportChart.wiredAccount.data <<<'+ this.accountName);
            this.createUrlsReports();
            this.calculHeight();
        } else if (error) {
            console.log(' >>> LWC003_DisplayReportChart.wiredAccount.error <<<');
            console.log(error);
        }
    }
    redirectToReport(evt) {
            evt.preventDefault();
            evt.stopPropagation();
            const accountName = 'RMA ASSURANCE'; // Remplacez par la logique pour obtenir le nom du compte

        // Construisez l'URL de redirection avec le filtre sur le nom du compte
        const reportUrl = `/lightning/r/00OMU000000O6Yj2AK/view?fv0=${accountName}`;

            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    recordId: '001MU000006vurUYAQ',
                    //objectApiName: 'Report',
                    //actionName: 'view'
                    url: reportUrl
                },
                state: {
                fv0: 'No'
            }
            });
    }
            

    createUrlsReports(){
        var listeDeveloperNamesJs = [];
        listeDeveloperNamesJs.push(this.developerNameReport1);
        listeDeveloperNamesJs.push(this.developerNameReport2);
        listeDeveloperNamesJs.push(this.developerNameReport3);
        listeDeveloperNamesJs.push(this.developerNameReport4);
        listeDeveloperNamesJs.push(this.developerNameReport5);
        listeDeveloperNamesJs.push(this.developerNameReport6);
        
        getMapDeveloperNameIdsByDevNames({listeDeveloperNames : listeDeveloperNamesJs}).then(result => {
            console.log(' >>> LWC003_DisplayReportChart.getMapDeveloperNameIdsByDevNames() <<<');

            this.idReportGlobale = result[this.developerNameReport1] ;

            this.urlVf += 'accountName=' + this.accountName;
            this.urlVf += '&column=' + this.column;
            this.urlVf += '&developerNameReport1=' + this.developerNameReport1;
            this.urlVf += '&idReport1=' + result[this.developerNameReport1] ;
            this.urlVf += '&developerNameReport2=' + this.developerNameReport2;
            this.urlVf += '&idReport2=' + result[this.developerNameReport2] ;
            this.urlVf += '&developerNameReport3=' + this.developerNameReport3;
            this.urlVf += '&idReport3=' + result[this.developerNameReport3] ;
            this.urlVf += '&developerNameReport4=' + this.developerNameReport4;
            this.urlVf += '&idReport4=' + result[this.developerNameReport4] 
            this.urlVf += '&developerNameReport5=' + this.developerNameReport5;
            this.urlVf += '&idReport5=' + result[this.developerNameReport5] ;
            this.urlVf += '&developerNameReport6=' + this.developerNameReport6;
            this.urlVf += '&idReport6=' + result[this.developerNameReport6] ;
            
            console.log('urlVf '+ this.urlVf);
            this.showSpinner = false;

        });

    }

    displayCharts(event){
        console.log(' >>> LWC003_DisplayReportChart.displayCharts() <<<');
        this.showCharts = !this.showCharts;
    }

    calculHeight(){
        console.log(' >>> LWC003_DisplayReportChart.calculHeight() <<<');
        var temp = 0;
        if(this.developerNameReport1 != 'null'){
            temp = temp + 1;
        }
        if(this.developerNameReport2 != 'null'){
            temp = temp + 1;
        }
        if(this.developerNameReport3 != 'null'){
            temp = temp + 1;
        }
        if(this.developerNameReport4 != 'null'){
            temp = temp + 1;
        }
        if(this.developerNameReport5 != 'null'){
            temp = temp + 1;
        }
        if(this.developerNameReport6 != 'null'){
            temp = temp + 1;
        }
        if(temp >= 6){
            this.height = 620;
        }
        else{
            this.height = 320;
        }
        console.log('height '+ this.height);
    }

}