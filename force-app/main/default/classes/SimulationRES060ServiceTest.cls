/**
 * Tests du calcul RES060_FM. Les valeurs attendues ont été recalculées avec la formule du calculateur
 * télépro « Éligibilité PAC RES060FM indice » (version 2) et son tableau D_CAL × 1,3.
 * Les réglages sont fournis par le test : les résultats ne dépendent pas des Custom Metadata de l'org.
 */
@IsTest
private class SimulationRES060ServiceTest {
  private static SimulationRES060Service service() {
    return service(210);
  }

  private static SimulationRES060Service service(Decimal surfaceMax) {
    SimulationRES060Service.Parametres p = new SimulationRES060Service.Parametres();
    p.scop = 4;
    p.facteurFc = 2;
    p.prixDefaut = 160;
    p.coutPack1Pac = 6600;
    p.coutPackCascade = 13000;
    p.seuilCascadeM2 = 210;
    p.seuilZoneVerte = 3500;
    p.multiplicateurBono = 1.5;
    p.surfaceMaxM2 = surfaceMax;
    p.facteurFcSansBonification = 2;
    p.majorationDcal = 1.3;
    p.dacs = 11;
    p.rendementFixe = 0.70;
    p.coefMitoyenneteAucune = 1;
    p.coefMitoyennete1Cote = 0.95;
    p.coefMitoyennete2Cotes = 0.85;
    p.coefMitoyenneteDefaut = 0.95;
    p.anneeMaisonCibleMax = 1997;

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
      Bono_Social__c = false,
      Mitoyennete__c = SimulationRES060Service.MITOYENNETE_AUCUNE
    );
  }

  @IsTest
  static void calculMaisonIsolee() {
    Simulation_RES060__c s = simulation('Madrid', 120, 1970, 'Gaz');

    service().calculer(s);

    Assert.areEqual(212.8, s.DCAL__c, 'D_CAL Madrid 1961-1980 × 1,3');
    Assert.areEqual(0.70, s.Rendement__c, 'rendement fixe');
    Assert.areEqual(31.65, s.AES_MWh__c, 'AES avec eau chaude 11 kWh/m²');
    Assert.areEqual(10128.55, s.Prime__c, 'prime');
    Assert.areEqual(6600, s.Cout_Pack__c, 'pack 1 PAC');
    Assert.areEqual(3528.55, s.Benefice__c, 'bénéfice');
    Assert.areEqual(3.5, s.Indice__c, 'indice');
    Assert.areEqual(SimulationRES060Service.ZONE_VERTE, s.Zone__c, 'zone');
    Assert.areEqual(
      SimulationRES060Service.STATUT_ELIGIBLE,
      s.Statut__c,
      'statut'
    );
    Assert.areEqual(160, s.Prix_Valorisation__c, 'prix par défaut appliqué');
  }

  @IsTest
  static void calculBonoCascadeDeuxMitoyens() {
    Simulation_RES060__c s = simulation('Madrid', 250, 1930, 'Fioul');
    s.Bono_Social__c = true;
    s.Mitoyennete__c = SimulationRES060Service.MITOYENNETE_2_COTES;

    // Sans limite de surface : le calcul cascade 2 PAC reste celui du calculateur FM.
    service(null).calculer(s);

    Assert.areEqual(29825.16, s.Prime__c, 'prime bono ×1,5 et −15 %');
    Assert.areEqual(13000, s.Cout_Pack__c, 'cascade 2 PAC');
    Assert.areEqual(16.8, s.Indice__c, 'indice');
    Assert.isTrue(s.Statut__c.contains('cascade'), 'statut cascade');
  }

  @IsTest
  static void prixModifiableEtMitoyenneteParDefaut() {
    Simulation_RES060__c s = simulation('Madrid', 120, 1970, 'Gaz');
    s.Mitoyennete__c = null;
    s.Prix_Valorisation__c = 200;

    service().calculer(s);

    Assert.areEqual(200, s.Prix_Valorisation__c, 'le prix saisi est conservé');
    Assert.areEqual(12027.65, s.Prime__c, 'prime à 200 €/MWh, −5 % par défaut');
    Assert.areEqual(5.4, s.Indice__c, 'indice');
  }

  @IsTest
  static void anneeMaisonVideEtUnMitoyen() {
    Simulation_RES060__c s = simulation('Madrid', 150, null, 'Gaz');
    s.Mitoyennete__c = SimulationRES060Service.MITOYENNETE_1_COTE;

    service().calculer(s);

    Assert.areEqual(237.1, s.DCAL__c, 'année vide = ≤1940');
    Assert.areEqual(13333.6, s.Prime__c, 'prime');
    Assert.areEqual(6.7, s.Indice__c, 'indice');
  }

  @IsTest
  static void maisonApres1997IndiceAZero() {
    SimulationRES060Service svc = service();
    Simulation_RES060__c s2005 = simulation('Madrid', 120, 2005, 'Gaz');
    Simulation_RES060__c s1998 = simulation('Madrid', 120, 1998, 'Gaz');
    s1998.Bono_Social__c = true;
    Simulation_RES060__c s1997 = simulation('Madrid', 120, 1997, 'Gaz');

    Decimal sansBonif = svc.indiceSansBonification(s1998);
    svc.calculer(new List<Simulation_RES060__c>{ s2005, s1998, s1997 });

    Assert.areEqual(0, s2005.Indice__c, 'maison 2005 : indice à 0');
    Assert.areEqual(0, s2005.Prime__c, 'prime à 0');
    Assert.areEqual(SimulationRES060Service.ZONE_ROUGE, s2005.Zone__c, 'zone');
    Assert.areEqual(
      SimulationRES060Service.STATUT_INDICE_ZERO + ' · maison après 1997',
      s2005.Statut__c,
      'statut'
    );
    Assert.isNull(s2005.DCAL__c, 'pas de détail de calcul');
    Assert.areEqual(0, s1998.Indice__c, '1998 : hors cible, même avec bono');
    Assert.areEqual(0, sansBonif, 'aussi sans bonification');
    Assert.areEqual(
      -0.3,
      s1997.Indice__c,
      '1997 : dans la cible, calcul normal'
    );
    Assert.isFalse(
      s1997.Statut__c.contains('maison après'),
      '1997 : pas de signal'
    );
  }

  @IsTest
  static void electriqueEtCharbonNonEligibles() {
    Simulation_RES060__c elec = simulation('Madrid', 100, 1970, 'Electrique');
    Simulation_RES060__c charbon = simulation('Madrid', 100, 1970, 'Charbon');

    service().calculer(new List<Simulation_RES060__c>{ elec, charbon });

    Assert.areEqual(
      SimulationRES060Service.STATUT_NON_ELIGIBLE_ELECTRIQUE,
      elec.Statut__c,
      'électrique'
    );
    Assert.isNull(elec.Indice__c, 'pas d\'indice');
    Assert.areEqual(
      SimulationRES060Service.STATUT_NON_ELIGIBLE_ELECTRIQUE,
      charbon.Statut__c,
      'charbon'
    );
  }

  @IsTest
  static void provinceDeduiteDuCodePostal() {
    Simulation_RES060__c s = simulation(null, 120, 1970, 'Gaz');
    s.Code_Postal__c = ' 28001 ';

    service().calculer(s);

    Assert.areEqual('Madrid', s.Province__c, 'province déduite');
    Assert.areEqual(3.5, s.Indice__c, 'calcul fait');
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
  static void rendementEtMitoyennete() {
    SimulationRES060Service svc = service();
    Assert.areEqual(0.70, svc.rendement('Gaz'), 'gaz');
    Assert.areEqual(0.70, svc.rendement('Fioul'), 'fioul');
    Assert.isNull(svc.rendement('Electrique'), 'électrique non éligible');
    Assert.isNull(svc.rendement('Bois'), 'bois non éligible');

    Assert.areEqual(
      1,
      svc.coefMitoyennete(SimulationRES060Service.MITOYENNETE_AUCUNE),
      'isolée'
    );
    Assert.areEqual(
      0.95,
      svc.coefMitoyennete(SimulationRES060Service.MITOYENNETE_1_COTE),
      '1 côté'
    );
    Assert.areEqual(
      0.85,
      svc.coefMitoyennete(SimulationRES060Service.MITOYENNETE_2_COTES),
      '2 côtés'
    );
    Assert.areEqual(0.95, svc.coefMitoyennete(null), 'vide = défaut −5 %');
    Assert.areEqual(0.95, svc.coefMitoyennete('autre'), 'inconnue = défaut');
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
  static void seuilsDeSurface() {
    SimulationRES060Service svc = service();
    Simulation_RES060__c s210 = simulation('Madrid', 210, 1970, 'Gaz');
    s210.Mitoyennete__c = null;
    Simulation_RES060__c s211 = simulation('Madrid', 211, 1970, 'Gaz');
    Simulation_RES060__c s250 = simulation('Madrid', 250, 2005, 'Gaz');

    svc.calculer(new List<Simulation_RES060__c>{ s210, s211, s250 });

    Assert.areEqual(6600, s210.Cout_Pack__c, '210 m² : 1 PAC');
    Assert.areEqual(10.2, s210.Indice__c, '210 m² pile : calcul normal');
    Assert.areEqual(0, s211.Indice__c, 'au-delà de 210 m² : indice à 0');
    Assert.areEqual(0, s211.Prime__c, 'prime à 0');
    Assert.areEqual(SimulationRES060Service.ZONE_ROUGE, s211.Zone__c, 'zone');
    Assert.areEqual(
      'Surface supérieure à 210 m² : indice mis à 0',
      s211.Statut__c,
      'statut'
    );
    Assert.isNull(s211.DCAL__c, 'pas de détail de calcul');
    Assert.isTrue(
      s250.Statut__c.startsWith('Surface supérieure à 210') &&
      s250.Statut__c.contains('maison après 1997'),
      s250.Statut__c
    );
  }

  @IsTest
  static void sansLimiteDeSurface() {
    Simulation_RES060__c s = simulation('Madrid', 400, 1970, 'Gaz');

    service(null).calculer(s);

    Assert.areEqual(13000, s.Cout_Pack__c, 'cascade');
    Assert.isTrue(s.Indice__c > 0, 'calcul fait sans limite');
  }

  @IsTest
  static void indiceSansBonification() {
    SimulationRES060Service svc = service();
    Simulation_RES060__c s = simulation('Madrid', 120, 1970, 'Gaz');
    s.Bono_Social__c = true;
    s.Mitoyennete__c = null;
    Simulation_RES060__c grande = simulation('Madrid', 400, 1970, 'Gaz');

    Decimal sansBonif = svc.indiceSansBonification(s);
    Decimal sansBonifGrande = svc.indiceSansBonification(grande);
    svc.calculer(s);

    Assert.areEqual(7.8, s.Indice__c, 'indice normal avec bono ×1,5');
    Assert.areEqual(
      3.0,
      sansBonif,
      'indice sans bonification (fM 2, sans ×1,5)'
    );
    Assert.areEqual(
      0,
      sansBonifGrande,
      'limite de 210 m² aussi sans bonification'
    );
    Assert.isNull(grande.Indice__c, 'la simulation reçue n\'est pas modifiée');
  }
}
