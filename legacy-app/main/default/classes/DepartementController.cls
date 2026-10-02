public with sharing class DepartementController {
    

    @AuraEnabled(cacheable=true)
    public static List<Departement__mdt> getDepartements(){
        return [SELECT Id, MasterLabel, DepartementsVoisins__c FROM Departement__mdt];
    }
}