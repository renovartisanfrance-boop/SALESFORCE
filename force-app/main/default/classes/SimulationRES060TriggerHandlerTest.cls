/**
 * Tests de bout en bout : le trigger calcule à l'insertion et recalcule à la modification,
 * avec les réglages déployés dans l'org.
 */
@IsTest
private class SimulationRES060TriggerHandlerTest {
  private static Simulation_RES060__c nouvelle() {
    return new Simulation_RES060__c(
      Province__c = 'Madrid',
      Surface__c = 120,
      Annee_Maison__c = 1970,
      Type_Chaudiere__c = 'Gaz',
      Annee_Chaudiere__c = 1990,
      Prix_Valorisation__c = 155
    );
  }

  @IsTest
  static void calculAInsertionEtModification() {
    Simulation_RES060__c s = nouvelle();

    Test.startTest();
    insert s;
    Simulation_RES060__c apresInsertion = [
      SELECT Indice__c, Zone__c, Statut__c
      FROM Simulation_RES060__c
      WHERE Id = :s.Id
    ];
    s.Prix_Valorisation__c = 200;
    update s;
    Test.stopTest();

    Simulation_RES060__c apresModif = [
      SELECT Indice__c, Zone__c, Prime__c
      FROM Simulation_RES060__c
      WHERE Id = :s.Id
    ];
    Assert.areEqual(
      2.7,
      apresInsertion.Indice__c,
      'indice calculé à l\'insertion'
    );
    Assert.areEqual(
      SimulationRES060Service.ZONE_ROUGE,
      apresInsertion.Zone__c,
      'zone à l\'insertion'
    );
    Assert.areEqual(
      SimulationRES060Service.STATUT_ELIGIBLE,
      apresInsertion.Statut__c,
      'statut'
    );
    Assert.areEqual(
      5.4,
      apresModif.Indice__c,
      'indice recalculé avec le nouveau prix'
    );
    Assert.areEqual(
      SimulationRES060Service.ZONE_VERTE,
      apresModif.Zone__c,
      'zone recalculée'
    );
  }

  @IsTest
  static void prixVidePrendLaValeurParDefaut() {
    Simulation_RES060__c s = nouvelle();
    s.Prix_Valorisation__c = null;

    insert s;

    Simulation_RES060__c lu = [
      SELECT Prix_Valorisation__c
      FROM Simulation_RES060__c
      WHERE Id = :s.Id
    ];
    Assert.areEqual(
      new SimulationRES060Selector()
        .getParametres()
        .Prix_Valorisation_Defaut__c,
      lu.Prix_Valorisation__c,
      'prix par défaut des réglages'
    );
  }

  @IsTest
  static void calculEnMasse() {
    List<Simulation_RES060__c> lot = new List<Simulation_RES060__c>();
    for (Integer i = 0; i < 200; i++) {
      lot.add(nouvelle());
    }

    Test.startTest();
    insert lot;
    Test.stopTest();

    List<Simulation_RES060__c> lus = [
      SELECT Indice__c
      FROM Simulation_RES060__c
    ];
    Assert.areEqual(200, lus.size(), '200 simulations');
    for (Simulation_RES060__c s : lus) {
      Assert.areEqual(2.7, s.Indice__c, 'chaque simulation est calculée');
    }
  }

  @IsTest
  static void autreOperationSansEffet() {
    Simulation_RES060__c s = nouvelle();
    List<Simulation_RES060__c> liste = new List<Simulation_RES060__c>{ s };

    new SimulationRES060TriggerHandler()
      .run(System.TriggerOperation.AFTER_INSERT, liste);

    Assert.isNull(s.Indice__c, 'aucun calcul hors before insert/update');
  }
}
