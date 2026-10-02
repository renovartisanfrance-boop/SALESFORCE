trigger CatalogueTarifaireTrigger on CatalogueTarifaire__c (
    before insert, before update
) {
    new CatalogueTarifaireTriggerHandler().run();
}