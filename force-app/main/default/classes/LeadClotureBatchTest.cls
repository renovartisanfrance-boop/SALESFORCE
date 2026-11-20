/**
 * Tests de la répartition du coût réel sur les pistes d'une clôture au pourcentage de campagne.
 */
@IsTest
private class LeadClotureBatchTest {
  @IsTest
  static void prixDefinitifPoseSurLesPistesPayeesSeulement() {
    Test.setMock(HttpCalloutMock.class, new RemonteeLeadGoogleMock());
    RemonteeLeadTestData.Mois mois = RemonteeLeadTestData.moisDeLeads(true);
    Id idCloture = new LeadClotureService().ouvrirMois(Date.today())[0].Id;
    LeadClotureService.Periode periode = new LeadClotureService.Periode(
      Date.today()
    );
    LeadClotureBatch lot = new LeadClotureBatch(
      idCloture,
      new Set<Id>{ mois.source.Id },
      periode.debut,
      periode.fin,
      10
    );

    Test.startTest();
    List<Lead> aTraiter = new List<Lead>();
    Database.QueryLocatorIterator curseur = lot.start(null).iterator();
    while (curseur.hasNext()) {
      aTraiter.add((Lead) curseur.next());
    }
    lot.execute(null, aTraiter);
    lot.finish(null);
    Test.stopTest();

    Assert.areEqual(
      2,
      aTraiter.size(),
      'les deux pistes payées au prix provisoire, pas le faux numéro'
    );
    for (Lead piste : [
      SELECT LastName, Prix_Achat__c, Prix_Revente__c, Statut_Prix__c
      FROM Lead
      WHERE Id IN :aTraiter
    ]) {
      Assert.areEqual(10, piste.Prix_Achat__c, piste.LastName);
      Assert.areEqual(15, piste.Prix_Revente__c, piste.LastName);
      Assert.areEqual(LeadPrixService.STATUT_DEFINITIF, piste.Statut_Prix__c);
    }
    Lead fauxNumero = [
      SELECT Prix_Achat__c, Prix_Revente__c, Paye_fournisseur__c
      FROM Lead
      WHERE Source_Lead__c = :mois.source.Id AND Faux_Numero__c = TRUE
    ];
    Assert.isFalse(fauxNumero.Paye_fournisseur__c);
    Assert.isNull(fauxNumero.Prix_Achat__c, 'le faux numéro n’est pas touché');
    Assert.isNull(fauxNumero.Prix_Revente__c);
    Cloture_Lead__c apres = [
      SELECT Statut__c, Nombre_a_repartir__c, Alerte__c
      FROM Cloture_Lead__c
      WHERE Id = :idCloture
    ];
    Assert.areEqual(
      LeadClotureService.STATUT_EN_COURS,
      apres.Statut__c,
      'le doublon interne payé attend encore son coût réel : la clôture le signale'
    );
    Assert.areEqual(1, apres.Nombre_a_repartir__c);
    Assert.isNotNull(apres.Alerte__c);
  }
}
