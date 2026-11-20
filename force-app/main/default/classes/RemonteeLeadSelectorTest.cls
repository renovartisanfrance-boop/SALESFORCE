/**
 * Tests des requêtes de la remontée des leads.
 */
@IsTest
private class RemonteeLeadSelectorTest {
  private static final RemonteeLeadSelector SELECTOR = new RemonteeLeadSelector();

  @IsTest
  static void sourcesActivesDUnFournisseurActifSeulement() {
    Fournisseur_Lead__c actif = RemonteeLeadTestData.fournisseur('F001');
    Fournisseur_Lead__c coupe = RemonteeLeadTestData.fournisseur('F002');
    Source_Lead__c lue = RemonteeLeadTestData.source(actif, 'classeur-a');
    Source_Lead__c eteinte = RemonteeLeadTestData.source(actif, 'classeur-b');
    Source_Lead__c fournisseurCoupe = RemonteeLeadTestData.source(
      coupe,
      'classeur-c'
    );
    update new Source_Lead__c(Id = eteinte.Id, Actif__c = false);
    update new Fournisseur_Lead__c(Id = coupe.Id, Actif__c = false);

    Test.startTest();
    List<Source_Lead__c> actives = SELECTOR.sourcesActives();
    Map<Id, Source_Lead__c> parId = SELECTOR.sourcesParId(
      new Set<Id>{ lue.Id, eteinte.Id, fournisseurCoupe.Id }
    );
    Test.stopTest();

    Assert.areEqual(
      1,
      actives.size(),
      'ni la source éteinte ni celle du fournisseur coupé'
    );
    Assert.areEqual(lue.Id, actives[0].Id);
    Assert.areEqual(3, parId.size());
    Assert.areEqual('F001', parId.get(lue.Id).Fournisseur__r.Code__c);
    Assert.areEqual('classeur-a', parId.get(lue.Id).Spreadsheet_Id__c);
    Assert.areEqual(RemonteeLeadTestData.ONGLET, parId.get(lue.Id).Onglet__c);
    Assert.isNotNull(parId.get(lue.Id).Mapping_JSON__c);
  }

  @IsTest
  static void retrouveLesPistesDejaPresentes() {
    Test.setMock(HttpCalloutMock.class, new RemonteeLeadGoogleMock());
    Lead ancienne = RemonteeLeadTestData.pisteExistante(
      'Ancienne',
      '34666111222',
      'ancienne@exemple.com'
    );
    Lead remontee = RemonteeLeadTestData.pisteExistante(
      'Remontee',
      '34677111222',
      'remontee@exemple.com'
    );
    update new Lead(
      Id = remontee.Id,
      Telephone_Cle__c = '677111222',
      Ligne_Feuille__c = 'source|2|677111222',
      Code_Fournisseur__c = 'F001'
    );

    Test.startTest();
    List<Lead> parLigne = SELECTOR.pistesParLigneFeuille(
      new Set<String>{ 'source|2|677111222', 'source|3|x' }
    );
    List<Lead> parCle = SELECTOR.pistesParCleTelephone(
      new Set<String>{ '677111222', '666111222' }
    );
    List<Lead> parNumero = SELECTOR.pistesParTelephoneExact(
      new Set<String>{ '34666111222', '666111222' }
    );
    List<Lead> parEmail = SELECTOR.pistesParEmail(
      new Set<String>{ 'ancienne@exemple.com' }
    );
    List<Lead> parGroupe = SELECTOR.pistesParGroupeDoublon(
      new Set<String>{ '000000000' }
    );
    Test.stopTest();

    Assert.areEqual(1, parLigne.size());
    Assert.areEqual(remontee.Id, parLigne[0].Id);
    Assert.areEqual('F001', parLigne[0].Code_Fournisseur__c);
    Assert.areEqual(1, parCle.size(), 'seule la piste qui porte la clé');
    Assert.areEqual(remontee.Id, parCle[0].Id);
    Assert.areEqual(
      1,
      parNumero.size(),
      'ancienne piste retrouvée sur son numéro brut'
    );
    Assert.areEqual(ancienne.Id, parNumero[0].Id);
    Assert.areEqual(1, parEmail.size());
    Assert.areEqual(ancienne.Id, parEmail[0].Id);
    Assert.isTrue(
      parGroupe.isEmpty(),
      'aucun groupe pour ce numéro, et aucune erreur'
    );
  }

  @IsTest
  static void ensemblesVidesSansRequete() {
    Set<String> rien = new Set<String>();

    Test.startTest();
    Integer avant = Limits.getQueries();
    Assert.isTrue(SELECTOR.pistesParLigneFeuille(rien).isEmpty());
    Assert.isTrue(SELECTOR.pistesParCleTelephone(rien).isEmpty());
    Assert.isTrue(SELECTOR.pistesParTelephoneExact(rien).isEmpty());
    Assert.isTrue(SELECTOR.pistesParEmail(rien).isEmpty());
    Assert.isTrue(SELECTOR.pistesParGroupeDoublon(rien).isEmpty());
    Integer apres = Limits.getQueries();
    Test.stopTest();

    Assert.areEqual(avant, apres, 'rien à chercher : aucune requête consommée');
  }

  @IsTest
  static void etatDeLaChaine() {
    Test.startTest();
    Integer enCours = SELECTOR.travauxEnCours(RemonteeLeadQueueable.NOM_CLASSE);
    Boolean planifiee = SELECTOR.tachePlanifieeExiste(
      'Tâche qui n’existe pas ' + Crypto.getRandomInteger()
    );
    Test.stopTest();

    Assert.areEqual(0, enCours, 'aucun traitement lancé dans ce test');
    Assert.isFalse(planifiee);
  }
}
