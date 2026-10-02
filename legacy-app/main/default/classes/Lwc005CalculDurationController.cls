public with sharing class Lwc005CalculDurationController {

    @AuraEnabled(cacheable=true)
    public static List<Opportunity> getOpportunities() {
        List<String> statutRdv = new List<String>{NULL, '','A Replacer','Confirmer','Commercial - A Replacer ABS', 'R+2', 'Controle Qualite 1 - Demande de R2', 'Installation - Demande de R+2'};
        return [SELECT Id, Name, Adresse__c, CoordonneesGPS__c, Date_de_Previsite__c, Interesser_par_Isolation_Exterieur__c,Interesser_par_Panneau_solaire__c, Int_resser_par_Pompe_a_chaleur__c, Statut_Dossiers__c, 
        STATUT_RDV__c, Disponibilit_General_Clieent__c, Commentaire_Teleproo__c, Commentaire_Confirmateur__c, Commercial_Commentaire__c FROM Opportunity WHERE STATUT_RDV__c IN :statutRdv];
    }
}