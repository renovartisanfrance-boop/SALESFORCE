/**
 * Calcul du simulateur de marge RES060FC (pompe à chaleur, maison individuelle).
 * Reproduit la version 3 du simulateur HTML :
 *   AES (kWh/an) = D_CAL × S × (1/η − 1/SCOP)
 *   Prime        = AES ÷ 1000 × fC × (multiplicateur si bono) × prix (€/MWh)
 *   Bénéfice     = Prime − coût du pack ; zone verte si bénéfice ≥ seuil.
 * Les valeurs modifiables sont dans RES060_Parametre__mdt et RES060_DCAL_Province__mdt.
 */
public with sharing class SimulationRES060Service {
  public static final String ZONE_VERTE = 'Zone verte · prioritaire';
  public static final String ZONE_ROUGE = 'Zone rouge · à traiter en janvier';
  public static final String STATUT_ELIGIBLE = 'Éligible';
  public static final String STATUT_NON_ELIGIBLE = 'Non éligible : bois / pellets (combustible non fossile)';
  public static final String STATUT_ATTENTE_CHAUDIERE = 'En attente : choisir le type de chaudière';
  public static final String STATUT_ATTENTE = 'En attente : renseigner la province et la surface';
  public static final String STATUT_PROVINCE_INCONNUE = 'Donnée manquante : province inconnue';
  public static final String STATUT_SANS_DCAL = 'Donnée manquante : pas de D_CAL publié pour cette province (Canarias)';
  public static final String STATUT_SANS_REGLAGES = 'Donnée manquante : réglages RES060 introuvables';

  /** Réglages fixes du calcul. */
  public class Parametres {
    public Decimal scop;
    public Decimal facteurFc;
    public Decimal prixDefaut;
    public Decimal coutPack1Pac;
    public Decimal coutPackCascade;
    public Decimal seuilCascadeM2;
    public Decimal seuilZoneVerte;
    public Decimal multiplicateurBono;
  }

  /** Une ligne du tableau D_CAL : 7 tranches d'année de la maison. */
  public class Province {
    public String nom;
    public String prefixeCodePostal;
    public List<Decimal> dcal;
  }

  private final Parametres params;
  private final Map<String, Province> provincesParNom = new Map<String, Province>();
  private final Map<String, Province> provincesParPrefixe = new Map<String, Province>();

  public SimulationRES060Service() {
    this(new SimulationRES060Selector());
  }

  public SimulationRES060Service(SimulationRES060Selector selector) {
    this(
      versParametres(selector.getParametres()),
      versProvinces(selector.getDcalProvinces())
    );
  }

  @TestVisible
  private SimulationRES060Service(Parametres params, List<Province> provinces) {
    this.params = params;
    for (Province p : provinces) {
      provincesParNom.put(p.nom, p);
      if (String.isNotBlank(p.prefixeCodePostal)) {
        provincesParPrefixe.put(p.prefixeCodePostal, p);
      }
    }
  }

  /** Calcule toutes les simulations (avant enregistrement : aucune DML ici). */
  public void calculer(List<Simulation_RES060__c> simulations) {
    for (Simulation_RES060__c s : simulations) {
      calculer(s);
    }
  }

  /** Calcule une simulation et remplit les champs de résultat. */
  public void calculer(Simulation_RES060__c s) {
    viderResultats(s);
    if (params == null) {
      s.Statut__c = STATUT_SANS_REGLAGES;
      return;
    }
    if (s.Prix_Valorisation__c == null) {
      s.Prix_Valorisation__c = params.prixDefaut;
    }
    if (String.isBlank(s.Province__c)) {
      s.Province__c = provinceDepuisCodePostal(s.Code_Postal__c);
    }
    if (String.isBlank(s.Type_Chaudiere__c)) {
      s.Statut__c = STATUT_ATTENTE_CHAUDIERE;
      return;
    }
    Decimal eta = rendement(
      s.Type_Chaudiere__c,
      s.Annee_Chaudiere__c,
      s.Condensation__c == true
    );
    if (eta == null) {
      s.Statut__c = STATUT_NON_ELIGIBLE;
      return;
    }
    if (
      String.isBlank(s.Province__c) ||
      s.Surface__c == null ||
      s.Surface__c <= 0
    ) {
      s.Statut__c = STATUT_ATTENTE;
      return;
    }
    Province province = provincesParNom.get(s.Province__c);
    if (province == null) {
      s.Statut__c = STATUT_PROVINCE_INCONNUE;
      return;
    }
    Decimal dcal = province.dcal[indexTranche(s.Annee_Maison__c)];
    if (dcal == null || dcal == 0) {
      s.Statut__c = STATUT_SANS_DCAL;
      return;
    }

    Double surface = s.Surface__c.doubleValue();
    Double aesKwh =
      dcal.doubleValue() *
      (1 / eta.doubleValue() -
      1 / params.scop.doubleValue()) *
      surface;
    Double multiplicateur = s.Bono_Social__c == true
      ? params.multiplicateurBono.doubleValue()
      : Double.valueOf(1);
    Double prime =
      s.Prix_Valorisation__c.doubleValue() /
      1000 *
      aesKwh *
      params.facteurFc.doubleValue() *
      multiplicateur;
    Boolean cascade = s.Surface__c > params.seuilCascadeM2;
    Decimal cout = cascade ? params.coutPackCascade : params.coutPack1Pac;
    Double benefice = prime - cout.doubleValue();

    s.DCAL__c = dcal;
    s.Rendement__c = eta;
    s.AES_MWh__c = arrondi(aesKwh / 1000, 2);
    s.Prime__c = arrondi(prime, 2);
    s.Cout_Pack__c = cout;
    s.Benefice__c = arrondi(benefice, 2);
    s.Indice__c = arrondi(benefice / 1000, 1);
    s.Zone__c = benefice >= params.seuilZoneVerte.doubleValue()
      ? ZONE_VERTE
      : ZONE_ROUGE;
    s.Statut__c = STATUT_ELIGIBLE + (cascade ? ' · cascade 2 PAC' : '');
  }

  /**
   * Rendement de la chaudière existante (η), comme le simulateur.
   * Année vide = 2000. Retourne null si non éligible (bois) ou type inconnu.
   */
  public static Decimal rendement(
    String typeChaudiere,
    Decimal anneeChaudiere,
    Boolean condensation
  ) {
    Integer annee = anneeChaudiere == null ? 2000 : anneeChaudiere.intValue();
    switch on typeChaudiere {
      when 'Electrique' {
        return 1.00;
      }
      when 'Charbon' {
        return 0.55;
      }
      when 'Gaz' {
        if (condensation) {
          return annee < 1998 ? 0.83 : 0.85;
        }
        return annee < 1979 ? 0.55 : (annee <= 1997 ? 0.65 : 0.73);
      }
      when 'Fioul' {
        if (condensation) {
          return 0.83;
        }
        return annee < 1985 ? 0.65 : (annee <= 1997 ? 0.70 : 0.79);
      }
      when else {
        return null;
      }
    }
  }

  /** Tranche d'année de la maison : 0 = ≤1940 (aussi si vide) … 6 = après 2019. */
  public static Integer indexTranche(Decimal anneeMaison) {
    if (anneeMaison == null) {
      return 0;
    }
    Integer a = anneeMaison.intValue();
    if (a <= 1940) {
      return 0;
    }
    if (a <= 1960) {
      return 1;
    }
    if (a <= 1980) {
      return 2;
    }
    if (a <= 2007) {
      return 3;
    }
    if (a <= 2012) {
      return 4;
    }
    if (a <= 2019) {
      return 5;
    }
    return 6;
  }

  private String provinceDepuisCodePostal(String codePostal) {
    String cp = codePostal == null ? '' : codePostal.deleteWhitespace();
    if (!Pattern.matches('\\d{5}', cp)) {
      return null;
    }
    Province p = provincesParPrefixe.get(cp.left(2));
    return p == null ? null : p.nom;
  }

  private static void viderResultats(Simulation_RES060__c s) {
    s.DCAL__c = null;
    s.Rendement__c = null;
    s.AES_MWh__c = null;
    s.Prime__c = null;
    s.Cout_Pack__c = null;
    s.Benefice__c = null;
    s.Indice__c = null;
    s.Zone__c = null;
    s.Statut__c = null;
  }

  private static Decimal arrondi(Double valeur, Integer decimales) {
    return Decimal.valueOf(valeur).setScale(decimales, RoundingMode.HALF_UP);
  }

  private static Parametres versParametres(RES060_Parametre__mdt m) {
    if (m == null) {
      return null;
    }
    Parametres p = new Parametres();
    p.scop = m.SCOP__c;
    p.facteurFc = m.Facteur_fC__c;
    p.prixDefaut = m.Prix_Valorisation_Defaut__c;
    p.coutPack1Pac = m.Cout_Pack_1_PAC__c;
    p.coutPackCascade = m.Cout_Pack_Cascade__c;
    p.seuilCascadeM2 = m.Seuil_Cascade_m2__c;
    p.seuilZoneVerte = m.Seuil_Zone_Verte__c;
    p.multiplicateurBono = m.Multiplicateur_Bono__c;
    return p;
  }

  private static List<Province> versProvinces(
    List<RES060_DCAL_Province__mdt> lignes
  ) {
    List<Province> result = new List<Province>();
    for (RES060_DCAL_Province__mdt m : lignes) {
      Province p = new Province();
      p.nom = m.Province__c;
      p.prefixeCodePostal = m.Prefixe_Code_Postal__c;
      p.dcal = new List<Decimal>{
        m.T1_1940__c,
        m.T2_1941_1960__c,
        m.T3_1961_1980__c,
        m.T4_1981_2007__c,
        m.T5_2008_2012__c,
        m.T6_2013_2019__c,
        m.T7_2020__c
      };
      result.add(p);
    }
    return result;
  }
}
