@IsTest
private class AircallTriggerHandlerTest {
  private static Aircall__c creerFiche(String telephone) {
    return new Aircall__c(
      Objet__c = 'Missed Call from test on TEST',
      Telephone_Client__c = telephone,
      Telephone_Standard__c = '+33100000000',
      Nom_Standard__c = 'TEST'
    );
  }

  @IsTest
  static void relieLaFicheDesSaCreation() {
    AircallTestSupport.simulerAppelsExternes();
    Pro__c dossier = new Pro__c(Phone__c = '0612345678');
    insert dossier;
    Test.setFixedSearchResults(new List<Id>{ dossier.Id });
    Aircall__c fiche = creerFiche('+33612345678');

    Test.startTest();
    insert fiche;
    Test.stopTest();

    Assert.areEqual(
      dossier.Id,
      [SELECT Dossier__c FROM Aircall__c WHERE Id = :fiche.Id].Dossier__c,
      'Une nouvelle fiche doit être reliée automatiquement au dossier'
    );
  }

  @IsTest
  static void neLanceRienSansNumero() {
    Test.startTest();
    insert creerFiche(null);
    Integer lances = Limits.getQueueableJobs();
    Test.stopTest();

    Assert.areEqual(0, lances, 'Sans numéro, aucun traitement lancé');
  }

  @IsTest
  static void relanceQuandLaPisteEstVidee() {
    Lead piste = new Lead(
      LastName = 'Test Aircall',
      Company = 'Test',
      Phone = '0612345678'
    );
    insert piste;
    Aircall__c fiche = creerFiche('+33612345678');
    fiche.Piste__c = piste.Id;
    AircallTriggerHandler.enPause = true;
    insert fiche;
    AircallTriggerHandler.enPause = false;
    Test.setFixedSearchResults(new List<Id>{ piste.Id });

    Test.startTest();
    fiche.Nom_Standard__c = 'TEST 2';
    update fiche;
    Integer apresModifSimple = Limits.getQueueableJobs();
    fiche.Piste__c = null;
    update fiche;
    Integer apresPisteVidee = Limits.getQueueableJobs();
    Test.stopTest();

    Assert.areEqual(
      0,
      apresModifSimple,
      'Une modification simple ne lance rien'
    );
    Assert.areEqual(
      1,
      apresPisteVidee,
      'Une piste vidée relance le rattachement'
    );
    Assert.areEqual(
      piste.Id,
      [SELECT Piste__c FROM Aircall__c WHERE Id = :fiche.Id].Piste__c,
      'La piste doit être remise'
    );
  }

  @IsTest
  static void neFaitRienEnPause() {
    AircallTriggerHandler.enPause = true;

    Test.startTest();
    insert creerFiche('+33612345678');
    Integer lances = Limits.getQueueableJobs();
    Test.stopTest();

    Assert.areEqual(0, lances, 'En pause, aucun traitement lancé');
  }
}
