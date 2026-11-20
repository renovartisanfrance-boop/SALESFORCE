/**
 * Tests du gardien horaire de la remontée des leads.
 */
@IsTest
private class RemonteeLeadGardienTest {
  @IsTest
  static void planifieUneSeuleFoisEtLanceLaChaine() {
    RemonteeLeadTestData.reglage();
    Test.setMock(HttpCalloutMock.class, new RemonteeLeadGoogleMock());

    Test.startTest();
    Id premiere = RemonteeLeadGardien.planifier();
    Id seconde = RemonteeLeadGardien.planifier();
    Test.stopTest();

    Assert.isNotNull(premiere, 'tâche planifiée créée');
    Assert.isNull(seconde, 'déjà planifiée : pas de doublon');
    CronTrigger tache = [
      SELECT CronExpression, CronJobDetail.Name
      FROM CronTrigger
      WHERE Id = :premiere
    ];
    Assert.areEqual(RemonteeLeadGardien.FREQUENCE, tache.CronExpression);
    Assert.areEqual(RemonteeLeadGardien.NOM_TACHE, tache.CronJobDetail.Name);
    Assert.isNotNull(
      RemonteeLeadQueueable.suivante,
      'la chaîne a été lancée et se poursuit'
    );
  }

  @IsTest
  static void neRelanceRienQuandLInterrupteurEstCoupe() {
    RemonteeLeadTestData.reglage().actif = false;

    Test.startTest();
    new RemonteeLeadGardien().execute(null);
    Test.stopTest();

    Assert.isNull(RemonteeLeadQueueable.suivante, 'aucune chaîne lancée');
    Assert.areEqual(
      0,
      new RemonteeLeadSelector()
        .travauxEnCours(RemonteeLeadQueueable.NOM_CLASSE)
    );
  }
}
