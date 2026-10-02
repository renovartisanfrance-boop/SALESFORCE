/**
 * @ Author: Abdessamad AZZOUZI (©S@M+)
 * @ Create Time: 2024-12-17 01:28:09
 * @ Modified by: Abdessamad AZZOUZI (©S@M+)
 * @ Modified time: 2025-01-07 00:46:51
 * @ Description:
 */


import { LightningElement, wire, track } from 'lwc';
import getOpportunities from '@salesforce/apex/Lwc005CalculDurationController.getOpportunities';

const NOMINATIM_API_BASE_URL = 'https://nominatim.openstreetmap.org/search';
const OSRM_API_BASE_URL = 'http://router.project-osrm.org/route/v1/driving';
const FETCH_DELAY = 100; // 1 second delay between API calls
const DEFAULT_COORDINATES = '0,0';

export default class Lwc005CalculDuration extends LightningElement {
    @track oppList = [];
    @track startLocation = {};
    codePostal = '';
    canSearch = false;

    get hoursZoneOffset() {
        return new Date().getTimezoneOffset() / 60;
    }

    @wire(getOpportunities)
    handleOpportunities({ error, data }) {
        if (data) {
            this.processOpportunityData(data);
        } else if (error) {
            console.error('Error fetching opportunities:', error);
        }
    }

    processOpportunityData(data) {
        this.oppList = data?.map(opp => ({
            Id: opp.Id,
            Url: `/${opp.Id}`,
            Name: opp.Name,
            DatePreVisite: opp.Date_de_Previsite__c,
            // DatePreVisiteDisplay: this.formatPreVisiteDate(opp.Date_de_Previsite__c),
            LookupTelePro: opp.LOOKUP_T_l_pro__c,
            Duration: -1,
            bdgClass: 'slds-badge',
            Coordonnees: opp.CoordonneesGPS__c || DEFAULT_COORDINATES,
            DurationInHeuresMinutes: "Non calculé",
            InteresserParIsolationExterieur: opp.Interesser_par_Isolation_Exterieur__c,
            InteresserParPanneauSolaire: opp.Interesser_par_Panneau_solaire__c,
            InteresserParPompeAChaleur: opp.Int_resser_par_Pompe_a_chaleur__c,
            StatutDossiers: opp.Statut_Dossiers__c,
            StatutRDV: opp.STATUT_RDV__c,
            DisponibiliteGeneralClient: opp.Disponibilit_General_Clieent__c,
            TeleproCommentaire: opp.Commentaire_Teleproo__c,
            ConfirmateurCommentaire: opp.Commentaire_Confirmateur__c,
            CommercialCommentaire: opp.Commercial_Commentaire__c
        }));
    }

    formatPreVisiteDate(dateString) {
        if (!dateString) return '';
        const date = new Date(dateString);
        date.setHours(date.getHours() + this.hoursZoneOffset);
        return date.toLocaleString();
    }

    handleChange(event) {
        this.codePostal = event.target.value;
    }

    sortOpportunities(ascending = true) {
        const sortedList = [...this.oppList].sort((a, b) => {
            return ascending ? a.Duration - b.Duration : b.Duration - a.Duration;
        });
        this.oppList = sortedList;
    }

    sortAscHandle() {
        this.sortOpportunities(true);
    }

    sortDescHandle() {
        this.sortOpportunities(false);
    }

    async CalculerDurationHandle() {
        try {
            await this.getLatLngCodePostal();
            if (this.canSearch) {
                await this.calculDurations();
            }
        } catch (error) {
            console.error('Error in calculation:', error);
        }
    }

    async getLatLngCodePostal() {
        try {
            const params = new URLSearchParams({
                q: this.codePostal,
                format: 'json',
                limit: '1',
                countrycodes: 'FR'
            });

            const response = await fetch(`${NOMINATIM_API_BASE_URL}?${params}`);
            const [data] = await response.json();

            if (data?.lat && data?.lon) {
                this.startLocation = { lat: data.lat, lon: data.lon };
                this.canSearch = true;
            } else {
                this.canSearch = false;
            }
        } catch (error) {
            this.canSearch = false;
            console.error('Error fetching location:', error);
        }
    }

    async calculDurations() {
        const validOpportunities = this.oppList.filter(opp => opp.Coordonnees !== DEFAULT_COORDINATES);
        
        for (const opp of validOpportunities) {
            await this.processOpportunityDuration(opp);
            await this.delay(FETCH_DELAY);
        }
    }

    async processOpportunityDuration(opportunity) {
        try {
            const [lat, lon] = opportunity.Coordonnees.split(',');
            const locTo = { lat, lon };
            
            opportunity.Duration = await this.calculOneDuration(this.startLocation, locTo);
            this.updateDurationDisplay(opportunity);
            this.oppList = [...this.oppList];
        } catch (error) {
            console.error('Error processing duration:', error);
            opportunity.Duration = -2;
            this.updateDurationDisplay(opportunity);
        }
    }

    async calculOneDuration(locFrom, locTo) {
        if (!this.isValidLocation(locFrom) || !this.isValidLocation(locTo)) {
            return -2;
        }

        try {
            const url = `${OSRM_API_BASE_URL}/${locFrom.lon},${locFrom.lat};${locTo.lon},${locTo.lat}?overview=false`;
            const response = await fetch(url);
            const data = await response.json();
            
            return data.routes[0]?.duration ?? -2;
        } catch (error) {
            console.error('Error calculating duration:', error);
            return -2;
        }
    }

    isValidLocation(loc) {
        return loc?.lat && loc?.lon;
    }

    updateDurationDisplay(opportunity) {
        if (opportunity.Duration >= 0) {
            opportunity.DurationInHeuresMinutes = this.convertSecToHeureMinutes(opportunity.Duration);
            opportunity.bdgClass = 'slds-badge slds-theme_success';
        } else if (opportunity.Duration === -1) {
            opportunity.bdgClass = 'slds-badge slds-badge_inverse';
            opportunity.DurationInHeuresMinutes = "Non calculé";
        } else {
            opportunity.bdgClass = 'slds-badge slds-theme_error';
            opportunity.DurationInHeuresMinutes = "Erreur";
        }
    }

    convertSecToHeureMinutes(seconds) {
        if (seconds < 0) return "Erreur";
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        return `${hours}h${minutes}min`;
    }

    delay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }
}

// import { LightningElement, wire } from 'lwc';

// import getOpportunities from '@salesforce/apex/Lwc005CalculDurationController.getOpportunities';
// export default class Lwc005CalculDuration extends LightningElement {


//     get hoursZoneOfSet(){
//         // check if gmt or gmt+1
//         let  hoursZoneOfSet = new Date().getTimezoneOffset() / 60;
//         console.log('gmt : ', hoursZoneOfSet);
//         return hoursZoneOfSet;
//     }

//     oppList = [];
//     @wire(getOpportunities)
//     getOpportunities({ error, data }) {
//         console.log('hoursZoneOfSet : ',this.hoursZoneOfSet);
//         if (data) {
//             // this.opportunities = data;
//             // this.error = undefined;
//             // console.log('data : ', JSON.stringify(data));
//             this.oppList = data?.map(e => ({
//                 Id: e.Id,
//                 Url: `/${e.Id}`,
//                 Name: e.Name,
//                 DatePreVisite: e.Date_de_Previsite__c,
//                 DatePreVisiteDisplay : e.Date_de_Previsite__c != null ? new Date(new Date(e.Date_de_Previsite__c).setHours(new Date(e.Date_de_Previsite__c).getHours() + this.hoursZoneOfSet)).toLocaleString()/*.setHours(new Date(e.Date_de_Previsite__c).getHours() + this.hoursZoneOfSet))*/ : '',
//                 LookupTelePro: e.LOOKUP_T_l_pro__c,
//                 Duration : -1,
//                 bdgClass : 'slds-badge',
//                 Coordonnees : e.CoordonneesGPS__c || '0,0',
//                 DurationInHeuresMinutes: "Non calculé",
//                 InteresserParIsolationExterieur: e.Interesser_par_Isolation_Exterieur__c,
//                 InteresserParPanneauSolaire: e.Interesser_par_Panneau_solaire__c,
//                 InteresserParPompeAChaleur: e.Int_resser_par_Pompe_a_chaleur__c,
//                 StatutDossiers: e.Statut_Dossiers__c,
//                 StatutRDV: e.STATUT_RDV__c,
//                 DisponibiliteGeneralClient: e.Disponibilit_General_Clieent__c,
//                 TeleproCommentaire: e.Commentaire_Teleproo__c,
//                 ConfirmateurCommentaire: e.Commentaire_Confirmateur__c,
//                 CommercialCommentaire: e.Commercial_Commentaire__c
//             }));
//         } else if (error) {
//             console.log('error : ', JSON.stringify(error));

//             // this.error = error;
//             // this.opportunities = undefined;
//         }
//     }

//     codePostal = '';
//     handleChange(event) {
//         this.codePostal = event.target.value;
//         console.log('codePostal : ', this.codePostal);
//     }

//     sortAscHandle(){
//         this.oppList.sort((a, b) => a.Duration - b.Duration);
//         this.oppList = [...this.oppList];
//     }

//     sortDescHandle(){
//         this.oppList.sort((a, b) => b.Duration - a.Duration);
//         this.oppList = [...this.oppList];
//     }

//     startLocation = {};
//     canSearch = false;
//     async CalculerDurationHandle(){
//         console.log('Start CalculerDurationHandle : ', this.codePostal);
//         await this.getLatLngCodePostal();
//         await this.calculDurations();
//         console.log('End CalculerDurationHandle : ', this.codePostal);

//     }



//     async calculDurations(){
//         // await this.getLatLngCodePostal();
//         if(this.canSearch){
//             this.oppList.filter(e => e.Coordonnees != '0,0')?.forEach(async e => {
//                 setTimeout(async () => {
//                     try{
//                         console.log('Starts <<', e.Coordonnees);
                        
//                         // console.error('Starts <<');
//                         let coordonnees = e.Coordonnees.split(',');
//                         let locTo = {
//                             lat : coordonnees[0],
//                             lon : coordonnees[1]
//                         }
//                         // this.calculOneDuration(e, this.startLocation, locTo);// || 'Erreur';
//                         e.Duration = await this.calculOneDuration(this.startLocation, locTo);// || 'Erreur';
//                         if(e.Duration >= 0){
//                             e.DurationInHeuresMinutes = this.convertSecToHeureMinutes(e.Duration);
//                             e.bdgClass = 'slds-badge slds-theme_success';
//                         } else if (e.Duration == -1){
//                             e.bdgClass = 'slds-badge slds-badge_inverse';
//                             e.DurationInHeuresMinutes = "Non calculé";
//                         } else {
//                             e.bdgClass = 'slds-badge slds-theme_error';
//                             e.DurationInHeuresMinutes = "Erreur";
//                         }
//                         // console.log('duration res : ', e.Duration);
//                         this.oppList = [...this.oppList];
//                     }
//                     catch(error){
//                         console.error('error : ', error);
//                     }
//                 }, 1000);
//             });

//             // // this.oppList = [...this.oppList];
//             // console.log('OUTPUT : ', JSON.stringify(this.oppList));
//         }
//     }

//     async getLatLngCodePostal(){
//         try{
//             let apiUrl = 'https://nominatim.openstreetmap.org/search?q='+this.codePostal+'&format=json&limit=1&countrycodes=FR';
//             let response = await fetch(apiUrl);
//             let data = await response.json();
//             console.log('data : ', data);    
//             if(data[0]?.lat && data[0]?.lon){
//                 this.startLocation = {
//                     lat : data[0].lat,
//                     lon : data[0].lon
//                 }
//                 this.canSearch = true;
//                 console.log('canSearch : ', JSON.stringify(this.startLocation));    

//             } else {
//                 console.log('data : ', data);
//                 this.canSearch = false;
//                 // console.error('cant Search');    
//             }
            
//         } catch (error){
//             this.canSearch = false;
//             console.log('error : ', error);
//         }
//     }

//     async calculOneDuration(locFrom, locTo){
//         if(locFrom.lat && locFrom.lon && locTo.lat && locTo.lon){
//             try{
//                 // console.log('starts');
//                 let duration = -2;
//                 let apiUrl = `http://router.project-osrm.org/route/v1/driving/${locFrom.lon},${locFrom.lat};${locTo.lon},${locTo.lat}?overview=false`;
//                 let response = await fetch(apiUrl);
//                 let data = await response.json();
//                 console.log('data : ', data);    
//                 if(data.routes[0]?.duration){
//                     duration = data.routes[0]?.duration
//                 } else {
//                     console.log('data : ', data);
//                 }
//                 return duration;
//             } catch (error){
//                 // this.canSearch = false;
//                 console.log('error : ', error);
//                 return null;
//             }
//         }
//     }

//     convertSecToHeureMinutes(sec){
//         if(sec < 0){
//             return "Erreur";
//         }
//         let hours = Math.floor(sec / 3600);
//         let minutes = Math.floor((sec - (hours * 3600)) / 60);
//         return `${hours}h${minutes}min`;
//     }
// }