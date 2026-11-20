@IsTest
private class AircallRattachementSelectorTest {
  private static Aircall__c insererFiche() {
    Aircall__c fiche = new Aircall__c(
      Objet__c = 'Missed Call from +33612345678 on TEST',
      Telephone_Client__c = '+33612345678',
      Telephone_Standard__c = '+33100000000',
      Nom_Standard__c = 'TEST'
    );
    AircallTriggerHandler.enPause = true;
    insert fiche;
    AircallTriggerHandler.enPause = false;
    return fiche;
  }

  @IsTest
  static void litLesFichesParId() {
    Aircall__c fiche = insererFiche();

    List<Aircall__c> fiches = new AircallRattachementSelector()
      .fichesParIds(new Set<Id>{ fiche.Id });

    Assert.areEqual(1, fiches.size(), 'La fiche doit être retrouvée');
    Assert.areEqual('+33612345678', fiches[0].Telephone_Client__c);
  }

  @IsTest
  static void listeLesFichesIncompletes() {
    Aircall__c fiche = insererFiche();

    Database.QueryLocatorIterator fiches = new AircallRattachementSelector()
      .fichesIncompletesDepuis(Datetime.now().addDays(-1))
      .iterator();

    Assert.isTrue(fiches.hasNext(), 'La fiche sans lien doit être listée');
    Assert.areEqual(fiche.Id, fiches.next().Id);
  }

  @IsTest
  static void chercheLesClientsParNumero() {
    AircallTestSupport.simulerAppelsExternes();
    Pro__c dossier = new Pro__c(Phone__c = '0612345678');
    insert dossier;
    Test.setFixedSearchResults(new List<Id>{ dossier.Id });
    AircallRattachementSelector selector = new AircallRattachementSelector();

    List<List<SObject>> trouves = selector.clientsParNumeros(
      new List<String>{ '612345678' }
    );
    List<List<SObject>> sansChiffres = selector.clientsParNumeros(
      new List<String>{ 'abc', null }
    );

    Assert.areEqual(0, trouves[0].size(), 'Aucune piste attendue');
    Assert.areEqual(1, trouves[1].size(), 'Le dossier doit être trouvé');
    Assert.areEqual(0, sansChiffres[1].size(), 'Rien à chercher');
  }

  @IsTest
  static void neChercheAucunDossierSansOpportunite() {
    List<Pro__c> dossiers = new AircallRattachementSelector()
      .dossiersParOpportunites(new Set<Id>());

    Assert.areEqual(0, dossiers.size(), 'Sans opportunité, aucun dossier');
  }
}
