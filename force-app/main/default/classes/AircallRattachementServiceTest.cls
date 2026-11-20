@IsTest
private class AircallRattachementServiceTest {
  private static final String NUMERO = '+33612345678';

  private static Aircall__c creerFiche(String telephone) {
    return new Aircall__c(
      Objet__c = 'Missed Call from ' + telephone + ' on TEST',
      Telephone_Client__c = telephone,
      Telephone_Standard__c = '+33100000000',
      Nom_Standard__c = 'TEST'
    );
  }

  private static void insererSansTrigger(List<SObject> enregistrements) {
    AircallTriggerHandler.enPause = true;
    insert enregistrements;
    AircallTriggerHandler.enPause = false;
  }

  private static Aircall__c relire(Id ficheId) {
    return [
      SELECT Piste__c, Opportunite__c, Dossier__c
      FROM Aircall__c
      WHERE Id = :ficheId
    ];
  }

  @IsTest
  static void normaliseTousLesFormats() {
    Assert.areEqual('612345678', AircallRattachementService.normaliser(NUMERO));
    Assert.areEqual(
      '612345678',
      AircallRattachementService.normaliser('06 12 34 56 78')
    );
    Assert.areEqual(
      '612345678',
      AircallRattachementService.normaliser('33612345678')
    );
    Assert.areEqual(
      '612345678',
      AircallRattachementService.normaliser('06-12-34-56-78')
    );
    Assert.isNull(AircallRattachementService.normaliser('1234'));
    Assert.isNull(AircallRattachementService.normaliser(null));
  }

  @IsTest
  static void rattachePisteEtDossierParNumero() {
    Lead piste = new Lead(
      LastName = 'Test Aircall',
      Company = 'Test',
      Phone = '06 12 34 56 78'
    );
    AircallTestSupport.simulerAppelsExternes();
    Pro__c dossier = new Pro__c(Phone__c = '0612345678');
    insert new List<SObject>{ piste, dossier };
    Aircall__c fiche = creerFiche(NUMERO);
    Aircall__c sansClient = creerFiche('+33699999999');
    insererSansTrigger(new List<SObject>{ fiche, sansClient });
    Test.setFixedSearchResults(new List<Id>{ piste.Id, dossier.Id });

    Test.startTest();
    new AircallRattachementService()
      .rattacher(new Set<Id>{ fiche.Id, sansClient.Id });
    Test.stopTest();

    Aircall__c resultat = relire(fiche.Id);
    Assert.areEqual(piste.Id, resultat.Piste__c, 'La piste doit être reliée');
    Assert.areEqual(
      dossier.Id,
      resultat.Dossier__c,
      'Le dossier doit être relié'
    );
    Aircall__c inchangee = relire(sansClient.Id);
    Assert.isNull(inchangee.Piste__c, 'Autre numéro : aucune piste');
    Assert.isNull(inchangee.Dossier__c, 'Autre numéro : aucun dossier');
  }

  @IsTest
  static void necrasePasUnePisteDejaReliee() {
    Lead dejaReliee = new Lead(
      LastName = 'Deja reliee',
      Company = 'Test',
      Phone = '0611111111'
    );
    Lead autre = new Lead(
      LastName = 'Autre',
      Company = 'Test',
      Phone = '0612345678'
    );
    insert new List<Lead>{ dejaReliee, autre };
    Aircall__c fiche = creerFiche(NUMERO);
    fiche.Piste__c = dejaReliee.Id;
    insererSansTrigger(new List<SObject>{ fiche });
    Test.setFixedSearchResults(new List<Id>{ autre.Id });

    Test.startTest();
    new AircallRattachementService().rattacher(new Set<Id>{ fiche.Id });
    Test.stopTest();

    Assert.areEqual(
      dejaReliee.Id,
      relire(fiche.Id).Piste__c,
      'La piste déjà reliée ne doit pas être remplacée'
    );
  }

  @IsTest
  static void prendLaPisteLaPlusRecente() {
    Lead ancienne = new Lead(
      LastName = 'Ancienne',
      Company = 'Test',
      Phone = '0612345678'
    );
    Lead recente = new Lead(
      LastName = 'Recente',
      Company = 'Test',
      MobilePhone = '33612345678'
    );
    insert new List<Lead>{ ancienne, recente };
    Test.setCreatedDate(ancienne.Id, Datetime.now().addDays(-30));
    Aircall__c fiche = creerFiche(NUMERO);
    insererSansTrigger(new List<SObject>{ fiche });
    Test.setFixedSearchResults(new List<Id>{ ancienne.Id, recente.Id });

    Test.startTest();
    new AircallRattachementService().rattacher(new Set<Id>{ fiche.Id });
    Test.stopTest();

    Assert.areEqual(
      recente.Id,
      relire(fiche.Id).Piste__c,
      'La piste la plus récente doit être choisie'
    );
    Assert.isTrue(
      AircallRattachementService.meilleurePiste(recente, null),
      'Sans piste déjà retenue, la candidate est prise'
    );
  }

  @IsTest
  static void ignoreLesFichesSansNumero() {
    Aircall__c fiche = creerFiche(null);
    fiche.Objet__c = 'Missed Call from inconnu on TEST';
    insererSansTrigger(new List<SObject>{ fiche });

    Test.startTest();
    new AircallRattachementService().rattacher(new Set<Id>{ fiche.Id });
    Test.stopTest();

    Assert.isNull(relire(fiche.Id).Piste__c, 'Sans numéro, rien à relier');
  }

  @IsTest
  static void traiteDeuxCentsFiches() {
    AircallTestSupport.simulerAppelsExternes();
    Pro__c dossier = new Pro__c(Phone__c = '0612345678');
    insert dossier;
    List<Aircall__c> fiches = new List<Aircall__c>();
    for (Integer i = 0; i < 200; i++) {
      fiches.add(creerFiche(Math.mod(i, 2) == 0 ? NUMERO : '+33687654321'));
    }
    insererSansTrigger(fiches);
    Test.setFixedSearchResults(new List<Id>{ dossier.Id });

    Test.startTest();
    new AircallRattachementService()
      .rattacher(new Map<Id, Aircall__c>(fiches).keySet());
    Test.stopTest();

    Assert.areEqual(
      100,
      [SELECT COUNT() FROM Aircall__c WHERE Dossier__c = :dossier.Id],
      'Les 100 fiches du bon numéro doivent être reliées au dossier'
    );
  }
}
