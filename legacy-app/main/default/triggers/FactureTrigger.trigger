trigger FactureTrigger on Facture__c (
    before insert, before update
) {
    new FactureTriggerHandler().run();
}