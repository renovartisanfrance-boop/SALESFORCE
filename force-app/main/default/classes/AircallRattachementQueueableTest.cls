@IsTest
private class AircallRattachementQueueableTest {
  @IsTest
  static void rattacheEnArrierePlan() {
    AircallTestSupport.simulerAppelsExternes();
    Pro__c dossier = new Pro__c(Phone__c = '0612345678');
    insert dossier;
    Aircall__c fiche = new Aircall__c(
      Objet__c = 'Missed Call from +33612345678 on TEST',
      Telephone_Client__c = '+33612345678',
      Telephone_Standard__c = '+33100000000',
      Nom_Standard__c = 'TEST'
    );
    AircallTriggerHandler.enPause = true;
    insert fiche;
    AircallTriggerHandler.enPause = false;
    Test.setFixedSearchResults(new List<Id>{ dossier.Id });

    Test.startTest();
    System.enqueueJob(
      new AircallRattachementQueueable(new Set<Id>{ fiche.Id })
    );
    Test.stopTest();

    Assert.areEqual(
      dossier.Id,
      [SELECT Dossier__c FROM Aircall__c WHERE Id = :fiche.Id].Dossier__c,
      'Le dossier doit être relié par le traitement en arrière-plan'
    );
  }
}
