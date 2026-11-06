@IsTest
private class SimulationRES060SelectorTest {
  @IsTest
  static void litLesReglagesDeployes() {
    SimulationRES060Selector selector = new SimulationRES060Selector();

    RES060_Parametre__mdt p = selector.getParametres();
    List<RES060_DCAL_Province__mdt> provinces = selector.getDcalProvinces();

    Assert.isNotNull(
      p,
      'enregistrement ' + SimulationRES060Selector.NOM_PARAMETRES + ' présent'
    );
    Assert.isNotNull(p.SCOP__c, 'SCOP renseigné');
    Assert.isNotNull(
      p.Prix_Valorisation_Defaut__c,
      'prix par défaut renseigné'
    );
    Assert.areEqual(50, provinces.size(), 'une ligne par province');
    Set<String> prefixes = new Set<String>();
    for (RES060_DCAL_Province__mdt m : provinces) {
      Assert.isTrue(
        String.isNotBlank(m.Province__c),
        'nom de province renseigné'
      );
      prefixes.add(m.Prefixe_Code_Postal__c);
    }
    Assert.areEqual(50, prefixes.size(), 'préfixes de code postal uniques');
  }
}
