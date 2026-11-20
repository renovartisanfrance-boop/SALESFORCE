/**
 * Tests du déclencheur des tarifs : un tarif actif ne peut pas recouvrir la période d'un autre
 * tarif actif du même couple fournisseur + régie, à la création comme à la modification.
 */
@IsTest
private class TarifLeadTriggerHandlerTest {
  private static Tarif_Lead__c tarif(
    Fournisseur_Lead__c fournisseur,
    Campaign regie,
    Date debut,
    Date fin
  ) {
    return new Tarif_Lead__c(
      Fournisseur__c = fournisseur.Id,
      Regie__c = regie.Id,
      Date_debut__c = debut,
      Date_fin__c = fin,
      Actif__c = true,
      Mode_achat__c = LeadPrixService.MODE_FIXE,
      Prix_Achat__c = 5,
      Regle_revente__c = LeadPrixService.REVENTE_FIXE,
      Prix_Revente__c = 10
    );
  }

  @IsTest
  static void creationRefuseeSiLaPeriodeRecouvreUnTarifExistant() {
    Fournisseur_Lead__c f = RemonteeLeadTestData.fournisseur('F001');
    Campaign regie = RemonteeLeadTestData.regie('Régie de test');
    Campaign autreRegie = RemonteeLeadTestData.regie('Autre régie');
    Date j = Date.today();
    insert tarif(f, regie, j.addDays(-30), j.addDays(30));

    Test.startTest();
    List<Database.SaveResult> resultats = Database.insert(
      new List<Tarif_Lead__c>{
        tarif(f, regie, j, null),
        tarif(f, regie, j.addDays(31), null),
        tarif(f, autreRegie, j, null)
      },
      false
    );
    Test.stopTest();

    Assert.isFalse(
      resultats[0].isSuccess(),
      'commence pendant la période du tarif existant'
    );
    Assert.isTrue(
      resultats[0].getErrors()[0]
        .getMessage()
        .contains('recouvre un autre tarif actif'),
      resultats[0].getErrors()[0].getMessage()
    );
    Assert.isTrue(
      resultats[1].isSuccess(),
      'commence le lendemain de la fin : accepté'
    );
    Assert.isTrue(
      resultats[2].isSuccess(),
      'même fournisseur, autre régie : un autre tarif'
    );
    Assert.areEqual(
      2,
      [
        SELECT COUNT()
        FROM Tarif_Lead__c
        WHERE Fournisseur__c = :f.Id AND Regie__c = :regie.Id
      ]
    );
  }

  @IsTest
  static void modificationRefuseeSiElleCreeUnRecouvrement() {
    Fournisseur_Lead__c f = RemonteeLeadTestData.fournisseur('F001');
    Campaign regie = RemonteeLeadTestData.regie('Régie de test');
    Date j = Date.today();
    Tarif_Lead__c ancien = tarif(f, regie, j.addDays(-60), j.addDays(-1));
    Tarif_Lead__c courant = tarif(f, regie, j, null);
    insert new List<Tarif_Lead__c>{ ancien, courant };

    Test.startTest();
    // Changer le prix sans toucher aux dates : aucun recouvrement, donc accepté.
    Database.SaveResult prix = Database.update(
      new Tarif_Lead__c(Id = courant.Id, Prix_Achat__c = 6),
      false
    );
    // Rouvrir l'ancien tarif sans date de fin : il recouvrirait le tarif courant.
    Database.SaveResult rouvert = Database.update(
      new Tarif_Lead__c(Id = ancien.Id, Date_fin__c = null),
      false
    );
    // Désactivé, il ne gêne plus.
    Database.SaveResult desactive = Database.update(
      new Tarif_Lead__c(Id = ancien.Id, Date_fin__c = null, Actif__c = false),
      false
    );
    Test.stopTest();

    Assert.isTrue(
      prix.isSuccess(),
      'un tarif ne se recouvre pas lui-même : ' + prix.getErrors()
    );
    Assert.isFalse(rouvert.isSuccess());
    Assert.isTrue(
      rouvert.getErrors()[0].getMessage().contains('sans date de fin'),
      rouvert.getErrors()[0].getMessage()
    );
    Assert.isTrue(
      desactive.isSuccess(),
      'désactivé : ' + desactive.getErrors()
    );
  }
}
