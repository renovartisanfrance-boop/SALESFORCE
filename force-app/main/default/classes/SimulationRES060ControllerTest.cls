@IsTest
private class SimulationRES060ControllerTest {
  @IsTest
  static void calculeSansEnregistrer() {
    Simulation_RES060__c s = new Simulation_RES060__c(
      Province__c = 'Madrid',
      Surface__c = 120,
      Annee_Maison__c = 1970,
      Type_Chaudiere__c = 'Gaz',
      Annee_Chaudiere__c = 1990,
      Prix_Valorisation__c = 155
    );

    Test.startTest();
    Simulation_RES060__c r = SimulationRES060Controller.simuler(s);
    Test.stopTest();

    Assert.areEqual(1.2, r.Indice__c, 'indice calculé');
    Assert.areEqual(SimulationRES060Service.ZONE_ROUGE, r.Zone__c, 'zone');
    Assert.isNull(r.Id, 'rien n\'est enregistré');
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM Simulation_RES060__c],
      'aucune simulation en base'
    );
  }

  @IsTest
  static void simulationVide() {
    Simulation_RES060__c r = SimulationRES060Controller.simuler(null);

    Assert.areEqual(
      SimulationRES060Service.STATUT_ATTENTE_CHAUDIERE,
      r.Statut__c,
      'en attente des infos'
    );
    Assert.isNotNull(r.Prix_Valorisation__c, 'prix par défaut proposé');
  }
}
