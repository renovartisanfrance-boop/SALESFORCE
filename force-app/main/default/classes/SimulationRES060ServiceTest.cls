/**
 * Tests du calcul RES060. Les valeurs attendues ont été obtenues avec le simulateur HTML (version 3).
 * Les réglages sont fournis par le test : les résultats ne dépendent pas des Custom Metadata de l'org.
 */
@IsTest
private class SimulationRES060ServiceTest {
  private static SimulationRES060Service service() {
    return service(220);
  }

  private static SimulationRES060Service service(Decimal surfaceMax) {
    SimulationRES060Service.Parametres p = new SimulationRES060Service.Parametres();
    p.scop = 4;
    p.facteurFc = 2;
    p.prixDefaut = 155;
    p.coutPack1Pac = 6600;
    p.coutPackCascade = 12500;
    p.seuilCascadeM2 = 220;
    p.seuilZoneVerte = 3500;
    p.multiplicateurBono = 1.5;
    p.surfaceMaxM2 = surfaceMax;

    SimulationRES060Service.Province madrid = new SimulationRES060Service.Province();
    madrid.nom = 'Madrid';
    madrid.prefixeCodePostal = '28';
    madrid.dcal = new List<Decimal>{
      182.4,
      169.1,
      163.7,
      98.3,
      64,
      51.2,
      46.1
    };

    SimulationRES060Service.Province palmas = new SimulationRES060Service.Province();
    palmas.nom = 'Palmas, Las';
    palmas.prefixeCodePostal = '35';
    palmas.dcal = new List<Decimal>{ 0, 0, 0, 0, 0, 0, 0 };

    return new SimulationRES060Service(
      p,
      new List<SimulationRES060Service.Province>{ madrid, palmas }
    );
  }

  private static Simulation_RES060__c simulation(
    String province,
    Decimal surface,
    Decimal anneeMaison,
    String type
  ) {
    return new Simulation_RES060__c(
      Province__c = province,
      Surface__c = surface,
      Annee_Maison__c = anneeMaison,
      Type_Chaudiere__c = type,
      Condensation__c = false,
      Bono_Social__c = false
    );
  }

  @IsTest
  static void calculZoneRouge() {
    Simulation_RES060__c s = simulation('Madrid', 120, 1970, 'Gaz');
    s.Annee_Chaudiere__c = 1990;

    service().calculer(s);

    Assert.areEqual(163.7, s.DCAL__c, 'D_CAL Madrid 1961-1980');
    Assert.areEqual(0.65, s.Rendement__c, 'gaz 1979-1997');
    Assert.areEqual(25.31, s.AES_MWh__c, 'AES');
    Assert.areEqual(7846.27, s.Prime__c, 'prime');
    Assert.areEqual(6600, s.Cout_Pack__c, 'pack 1 PAC');
    Assert.areEqual(1246.27, s.Benefice__c, 'bénéfice');
    Assert.areEqual(1.2, s.Indice__c, 'indice');
    Assert.areEqual(SimulationRES060Service.ZONE_ROUGE, s.Zone__c, 'zone');
    Assert.areEqual(
      SimulationRES060Service.STATUT_ELIGIBLE,
      s.Statut__c,
      'statut'
    );
    Assert.areEqual(155, s.Prix_Valorisation__c, 'prix par défaut appliqué');
  }

  @IsTest
  static void calculBonoCascadeZoneVerte() {
    // Sans limite de surface, le calcul cascade 2 PAC reste celui du simulateur.
    Simulation_RES060__c s = simulation('Madrid', 250, 1930, 'Fioul');
    s.Annee_Chaudiere__c = 1980;
    s.Bono_Social__c = true;

    service(null).calculer(s);

    Assert.areEqual(27320.54, s.Prime__c, 'prime avec bono');
    Assert.areEqual(12500, s.Cout_Pack__c, 'cascade 2 PAC');
    Assert.areEqual(14820.54, s.Benefice__c, 'bénéfice');
    Assert.areEqual(14.8, s.Indice__c, 'indice');
    Assert.areEqual(SimulationRES060Service.ZONE_VERTE, s.Zone__c, 'zone');
    Assert.isTrue(s.Statut__c.contains('cascade'), 'statut cascade');
  }

  @IsTest
  static void prixDeValorisationModifiable() {
    Simulation_RES060__c s = simulation('Madrid', 120, 1970, 'Gaz');
    s.Annee_Chaudiere__c = 1990;
    s.Prix_Valorisation__c = 200;

    service().calculer(s);

    Assert.areEqual(200, s.Prix_Valorisation__c, 'le prix saisi est conservé');
    Assert.areEqual(10124.22, s.Prime__c, 'prime à 200 €/MWh');
    Assert.areEqual(3.5, s.Indice__c, 'indice');
    Assert.areEqual(
      SimulationRES060Service.ZONE_VERTE,
      s.Zone__c,
      'passe en zone verte'
    );
  }

  @IsTest
  static void condensationEtAnneeMaisonVide() {
    Simulation_RES060__c s = simulation('Madrid', 150, null, 'Gaz');
    s.Annee_Chaudiere__c = 2005;
    s.Condensation__c = true;

    service().calculer(s);

    Assert.areEqual(182.4, s.DCAL__c, 'année vide = ≤1940');
    Assert.areEqual(0.85, s.Rendement__c, 'gaz condensation récente');
    Assert.areEqual(7857.95, s.Prime__c, 'prime');
    Assert.areEqual(1.3, s.Indice__c, 'indice');
  }

  @IsTest
  static void electriqueIndiceNegatif() {
    Simulation_RES060__c s = simulation('Madrid', 100, 2010, 'Electrique');

    service().calculer(s);

    Assert.areEqual(1488.00, s.Prime__c, 'prime');
    Assert.areEqual(-5.1, s.Indice__c, 'indice négatif');
    Assert.areEqual(SimulationRES060Service.ZONE_ROUGE, s.Zone__c, 'zone');
  }

  @IsTest
  static void provinceDeduiteDuCodePostal() {
    Simulation_RES060__c s = simulation(null, 120, 1970, 'Gaz');
    s.Code_Postal__c = ' 28001 ';
    s.Annee_Chaudiere__c = 1990;

    service().calculer(s);

    Assert.areEqual('Madrid', s.Province__c, 'province déduite');
    Assert.areEqual(1.2, s.Indice__c, 'calcul fait');
  }

  @IsTest
  static void boisNonEligible() {
    Simulation_RES060__c s = simulation('Madrid', 120, 1970, 'Bois');
    s.Indice__c = 9.9;

    service().calculer(s);

    Assert.areEqual(
      SimulationRES060Service.STATUT_NON_ELIGIBLE,
      s.Statut__c,
      'statut'
    );
    Assert.isNull(s.Indice__c, 'ancien résultat effacé');
    Assert.isNull(s.Zone__c, 'pas de zone');
  }

  @IsTest
  static void infosManquantes() {
    SimulationRES060Service svc = service();
    Simulation_RES060__c sansSurface = simulation('Madrid', null, 1970, 'Gaz');
    Simulation_RES060__c sansProvince = simulation(null, 120, 1970, 'Gaz');
    sansProvince.Code_Postal__c = '99999';
    Simulation_RES060__c sansType = simulation('Madrid', 120, 1970, null);
    Simulation_RES060__c inconnue = simulation('Atlantide', 120, 1970, 'Gaz');
    Simulation_RES060__c canarias = simulation('Palmas, Las', 120, 1970, 'Gaz');

    svc.calculer(
      new List<Simulation_RES060__c>{
        sansSurface,
        sansProvince,
        sansType,
        inconnue,
        canarias
      }
    );

    Assert.areEqual(
      SimulationRES060Service.STATUT_ATTENTE,
      sansSurface.Statut__c,
      'surface manquante'
    );
    Assert.areEqual(
      SimulationRES060Service.STATUT_ATTENTE,
      sansProvince.Statut__c,
      'province introuvable'
    );
    Assert.areEqual(
      SimulationRES060Service.STATUT_ATTENTE_CHAUDIERE,
      sansType.Statut__c,
      'type manquant'
    );
    Assert.areEqual(
      SimulationRES060Service.STATUT_PROVINCE_INCONNUE,
      inconnue.Statut__c,
      'province inconnue'
    );
    Assert.areEqual(
      SimulationRES060Service.STATUT_SANS_DCAL,
      canarias.Statut__c,
      'Canarias'
    );
    Assert.isNull(canarias.Indice__c, 'pas d\'indice');
  }

  @IsTest
  static void sansReglages() {
    SimulationRES060Service svc = new SimulationRES060Service(
      null,
      new List<SimulationRES060Service.Province>()
    );
    Simulation_RES060__c s = simulation('Madrid', 120, 1970, 'Gaz');

    svc.calculer(s);

    Assert.areEqual(
      SimulationRES060Service.STATUT_SANS_REGLAGES,
      s.Statut__c,
      'statut'
    );
    Assert.isNull(s.Indice__c, 'pas de calcul');
  }

  @IsTest
  static void tableDesRendements() {
    Assert.areEqual(
      0.55,
      SimulationRES060Service.rendement('Gaz', 1978, false),
      'gaz < 1979'
    );
    Assert.areEqual(
      0.65,
      SimulationRES060Service.rendement('Gaz', 1997, false),
      'gaz ≤ 1997'
    );
    Assert.areEqual(
      0.73,
      SimulationRES060Service.rendement('Gaz', null, false),
      'gaz année vide = 2000'
    );
    Assert.areEqual(
      0.83,
      SimulationRES060Service.rendement('Gaz', 1990, true),
      'gaz condensation ancienne'
    );
    Assert.areEqual(
      0.65,
      SimulationRES060Service.rendement('Fioul', 1984, false),
      'fioul < 1985'
    );
    Assert.areEqual(
      0.70,
      SimulationRES060Service.rendement('Fioul', 1997, false),
      'fioul ≤ 1997'
    );
    Assert.areEqual(
      0.79,
      SimulationRES060Service.rendement('Fioul', 1998, false),
      'fioul récent'
    );
    Assert.areEqual(
      0.83,
      SimulationRES060Service.rendement('Fioul', 2010, true),
      'fioul condensation'
    );
    Assert.areEqual(
      0.55,
      SimulationRES060Service.rendement('Charbon', 2010, false),
      'charbon'
    );
    Assert.isNull(
      SimulationRES060Service.rendement('Bois', 2010, false),
      'bois non éligible'
    );
  }

  @IsTest
  static void tranchesAnneeMaison() {
    List<Integer> annees = new List<Integer>{
      1940,
      1941,
      1960,
      1961,
      1980,
      1981,
      2007,
      2008,
      2012,
      2013,
      2019,
      2020
    };
    List<Integer> attendus = new List<Integer>{
      0,
      1,
      1,
      2,
      2,
      3,
      3,
      4,
      4,
      5,
      5,
      6
    };
    for (Integer i = 0; i < annees.size(); i++) {
      Assert.areEqual(
        attendus[i],
        SimulationRES060Service.indexTranche(annees[i]),
        'année ' + annees[i]
      );
    }
    Assert.areEqual(
      0,
      SimulationRES060Service.indexTranche(null),
      'vide = ≤1940'
    );
  }

  @IsTest
  static void surfaceAuDelaDe220IndiceAZero() {
    Simulation_RES060__c s = simulation('Madrid', 250, 1930, 'Fioul');
    s.Annee_Chaudiere__c = 1980;
    s.Bono_Social__c = true;
    Simulation_RES060__c limite = simulation('Madrid', 220, 1970, 'Gaz');
    limite.Annee_Chaudiere__c = 1990;

    service().calculer(new List<Simulation_RES060__c>{ s, limite });

    Assert.areEqual(0, s.Indice__c, 'indice à 0 au-delà de 220 m²');
    Assert.areEqual(0, s.Prime__c, 'prime à 0');
    Assert.areEqual(
      SimulationRES060Service.ZONE_ROUGE,
      s.Zone__c,
      'zone rouge'
    );
    Assert.isTrue(
      s.Statut__c.startsWith('Surface supérieure à 220'),
      s.Statut__c
    );
    Assert.isNull(s.DCAL__c, 'pas de détail de calcul');
    Assert.areNotEqual(0, limite.Indice__c, '220 m² pile : calcul normal');
  }

  @IsTest
  static void indiceSansBonification() {
    SimulationRES060Service svc = service();
    Simulation_RES060__c s = simulation('Madrid', 120, 1970, 'Gaz');
    s.Annee_Chaudiere__c = 1990;
    s.Bono_Social__c = true;
    Simulation_RES060__c grande = simulation('Madrid', 250, 1970, 'Gaz');
    grande.Annee_Chaudiere__c = 1990;

    Decimal sansBonif = svc.indiceSansBonification(s);
    Decimal sansBonifGrande = svc.indiceSansBonification(grande);
    svc.calculer(s);

    // Avec fC 2 et bono x1,5 : 7 846,27 x 1,5 - 6 600 = 5 169 € ; sans : 7 846,27 / 2 - 6 600 = -2 677 €.
    Assert.areEqual(5.2, s.Indice__c, 'indice normal avec bono');
    Assert.areEqual(-2.7, sansBonif, 'indice sans bonification');
    Assert.areEqual(
      0,
      sansBonifGrande,
      'règle des 220 m² aussi sans bonification'
    );
    Assert.isNull(grande.Indice__c, 'la simulation reçue n\'est pas modifiée');
  }
}
