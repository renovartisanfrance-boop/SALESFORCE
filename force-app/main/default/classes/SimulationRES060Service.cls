/**
 * Calcul du simulateur de marge RES060_FM (pompe à chaleur, maison individuelle).
 * Reproduit le calculateur télépro « Éligibilité PAC RES060FM indice » (version 2) :
 *   D_CAL majoré = D_CAL officiel × majoration (1,3), arrondi au dixième
 *   AES (kWh/an) = (D_CAL majoré + D_ACS 11) × S × (1/η fixe 0,70 − 1/SCOP)
 *   Prime        = AES ÷ 1000 × fM × (multiplicateur si bono) × prix (€/MWh) × coef. mitoyenneté
 *   Bénéfice     = Prime − coût du pack (1 PAC jusqu'au seuil cascade, sinon cascade 2 PAC).
 * Seuls le gaz et le fioul sont éligibles. Hors cible (surface au-delà du maximum, 210 m², ou maison
 * construite après l'année cible, 1997) : indice mis à 0, signalé dans le statut (« maison après … »).
 * Les valeurs modifiables sont dans RES060_Parametre__mdt et RES060_DCAL_Province__mdt.
 */
public with sharing class SimulationRES060Service {
  public static final String ZONE_VERTE = 'Zone verte · prioritaire';
  public static final String ZONE_ROUGE = 'Zone rouge · à traiter en janvier';
  public static final String STATUT_ELIGIBLE = 'Éligible';
  public static final String STATUT_NON_ELIGIBLE = 'Non éligible : bois / pellets (combustible non fossile)';
  public static final String STATUT_NON_ELIGIBLE_ELECTRIQUE = 'Non éligible : chauffage électrique ou charbon (seuls gaz et fioul)';
  /** Ajouté au statut quand la maison est construite après l'année cible (texte lu par « RES060- Retour calculateur »). */
  public static final String MAISON_APRES = ' · maison après {0}';
  public static final String STATUT_ATTENTE_CHAUDIERE = 'En attente : choisir le type de chaudière';
  public static final String STATUT_ATTENTE = 'En attente : renseigner la province et la surface';
  public static final String STATUT_PROVINCE_INCONNUE = 'Donnée manquante : province inconnue';
  public static final String STATUT_SANS_DCAL = 'Donnée manquante : pas de D_CAL publié pour cette province (Canarias)';
  public static final String STATUT_SANS_REGLAGES = 'Donnée manquante : réglages RES060 introuvables';
  public static final String STATUT_SURFACE_MAX = 'Surface supérieure à {0} m² : indice mis à 0';
  /** Statut d'une maison construite après l'année cible (suivi de « · maison après … »). */
  public static final String STATUT_INDICE_ZERO = 'Indice mis à 0';

  /** Valeurs du champ mitoyenneté (mêmes valeurs sur la Piste et la Simulation). */
  public static final String MITOYENNETE_AUCUNE = 'Aislada/Independiente';
  public static final String MITOYENNETE_1_COTE = 'Adosada por un lado/ Con una medianera';
  public static final String MITOYENNETE_2_COTES = 'Entre medianeras/ Con dos medianeras';

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
    /** Au-delà de cette surface, l'indice est mis à 0 (vide = pas de limite). */
    public Decimal surfaceMaxM2;
    /** fM utilisé pour l'indice « sans bonification » (vide = 1). */
    public Decimal facteurFcSansBonification;
    /** D_CAL officiel × majoration (vide = 1). */
    public Decimal majorationDcal;
    /** Besoin d'eau chaude ajouté au D_CAL majoré, kWh/m²·an (vide = 0). */
    public Decimal dacs;
    /** Rendement unique des chaudières gaz et fioul. */
    public Decimal rendementFixe;
    public Decimal coefMitoyenneteAucune;
    public Decimal coefMitoyennete1Cote;
    public Decimal coefMitoyennete2Cotes;
    public Decimal coefMitoyenneteDefaut;
    /** Après cette année de construction : indice mis à 0 et maison signalée (vide = pas de règle). */
    public Decimal anneeMaisonCibleMax;
  }

  /** Une ligne du tableau D_CAL : 7 tranches d'année de la maison. */
  public class Province {
    public String nom;
    public String prefixeCodePostal;
    public List<Decimal> dcal;
    /** Noms cherchés dans une adresse (minuscules, sans accents). */
    public List<String> noms = new List<String>();
  }

  private static final Pattern CODE_POSTAL_SEUL = Pattern.compile(
    '(?<!\\d)(\\d{4,5})(?!\\d)'
  );
  private static final Pattern CODE_POSTAL_TEXTE = Pattern.compile(
    '(?<!\\d)(\\d{5})(?!\\d)'
  );
  private static final Map<String, String> ACCENTS = new Map<String, String>{
    'á' => 'a',
    'à' => 'a',
    'â' => 'a',
    'ä' => 'a',
    'ã' => 'a',
    'é' => 'e',
    'è' => 'e',
    'ê' => 'e',
    'ë' => 'e',
    'í' => 'i',
    'ì' => 'i',
    'î' => 'i',
    'ï' => 'i',
    'ó' => 'o',
    'ò' => 'o',
    'ô' => 'o',
    'ö' => 'o',
    'õ' => 'o',
    'ú' => 'u',
    'ù' => 'u',
    'û' => 'u',
    'ü' => 'u',
    'ñ' => 'n',
    'ç' => 'c'
  };
  private Pattern nomsProvinces;
  private final Map<String, Province> provincesParNomRecherche = new Map<String, Province>();

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
      for (String nom : p.noms) {
        String n = normaliser(nom);
        if (String.isNotBlank(n)) {
          provincesParNomRecherche.put(n, p);
        }
      }
    }
    if (!provincesParNomRecherche.isEmpty()) {
      // Noms les plus longs d'abord : « santa cruz de tenerife » avant « tenerife ».
      List<String> noms = new List<String>(provincesParNomRecherche.keySet());
      noms.sort(new ParLongueurDecroissante());
      List<String> morceaux = new List<String>();
      for (String n : noms) {
        morceaux.add(Pattern.quote(n));
      }
      nomsProvinces = Pattern.compile(
        '(?<![a-z])(' + String.join(morceaux, '|') + ')(?![a-z])'
      );
    }
  }

  private class ParLongueurDecroissante implements System.Comparator<String> {
    public Integer compare(String a, String b) {
      return b.length() - a.length();
    }
  }

  /**
   * Trouve la province d'un logement.
   * 1) Les champs « code postal » (dans l'ordre) : 5 chiffres, ou 4 si le 0 de tête a été perdu.
   * 2) Sinon les adresses en texte libre : un code postal dont la province est aussi écrite
   *    dans l'adresse, sinon le premier code postal reconnu, sinon le dernier nom de province écrit.
   * Retourne null si rien n'est trouvé.
   */
  public String trouverProvince(
    List<String> codesPostaux,
    List<String> adresses
  ) {
    for (String cp : codesPostaux == null ? new List<String>() : codesPostaux) {
      if (String.isBlank(cp)) {
        continue;
      }
      Matcher m = CODE_POSTAL_SEUL.matcher(cp);
      while (m.find()) {
        Province p = provincesParPrefixe.get(
          m.group(1).leftPad(5, '0').left(2)
        );
        if (p != null) {
          return p.nom;
        }
      }
    }
    List<String> morceaux = new List<String>();
    for (String a : adresses == null ? new List<String>() : adresses) {
      if (String.isNotBlank(a)) {
        morceaux.add(a);
      }
    }
    if (morceaux.isEmpty()) {
      return null;
    }
    String texte = String.join(morceaux, ' | ');

    List<String> parCode = new List<String>();
    Matcher mc = CODE_POSTAL_TEXTE.matcher(texte);
    while (mc.find()) {
      Province p = provincesParPrefixe.get(mc.group(1).left(2));
      if (p != null) {
        parCode.add(p.nom);
      }
    }
    List<String> parNom = new List<String>();
    if (nomsProvinces != null) {
      Matcher mn = nomsProvinces.matcher(normaliser(texte));
      while (mn.find()) {
        parNom.add(provincesParNomRecherche.get(mn.group(1)).nom);
      }
    }
    for (String p : parCode) {
      if (parNom.contains(p)) {
        return p;
      }
    }
    if (!parCode.isEmpty()) {
      return parCode[0];
    }
    return parNom.isEmpty() ? null : parNom[parNom.size() - 1];
  }

  /** Minuscules, sans accents, et tout ce qui n'est ni lettre ni chiffre remplacé par un espace. */
  public static String normaliser(String texte) {
    if (texte == null) {
      return '';
    }
    String t = texte.toLowerCase();
    for (String a : ACCENTS.keySet()) {
      t = t.replace(a, ACCENTS.get(a));
    }
    return t.replaceAll('[^a-z0-9]+', ' ').trim();
  }

  /** Calcule toutes les simulations (avant enregistrement : aucune DML ici). */
  public void calculer(List<Simulation_RES060__c> simulations) {
    for (Simulation_RES060__c s : simulations) {
      calculer(s);
    }
  }

  /** Vrai pendant le calcul « sans bonification » : fC sans bonification et pas de ×1,5 bono. */
  private Boolean sansBonification = false;

  /**
   * Indice « sans bonification » : même calcul, mais fC sans bonification (1 par défaut)
   * et sans multiplicateur bono social. La simulation reçue n'est pas modifiée.
   */
  public Decimal indiceSansBonification(Simulation_RES060__c entree) {
    Simulation_RES060__c copie = entree.clone(false, true);
    sansBonification = true;
    try {
      calculer(copie);
    } finally {
      sansBonification = false;
    }
    return copie.Indice__c;
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
    if (s.Type_Chaudiere__c == 'Bois') {
      s.Statut__c = STATUT_NON_ELIGIBLE;
      return;
    }
    Decimal eta = rendement(s.Type_Chaudiere__c);
    if (eta == null) {
      s.Statut__c = STATUT_NON_ELIGIBLE_ELECTRIQUE;
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
    // Hors cible (surface au-delà du maximum ou maison après l'année cible) : indice mis à 0.
    String signalMaison = signalMaison(s.Annee_Maison__c);
    Boolean tropGrande =
      params.surfaceMaxM2 != null &&
      s.Surface__c > params.surfaceMaxM2;
    if (tropGrande || String.isNotBlank(signalMaison)) {
      s.Prime__c = 0;
      s.Benefice__c = 0;
      s.Indice__c = 0;
      s.Zone__c = ZONE_ROUGE;
      s.Statut__c =
        (tropGrande
          ? String.format(
              STATUT_SURFACE_MAX,
              new List<Object>{ params.surfaceMaxM2.format() }
            )
          : STATUT_INDICE_ZERO) + signalMaison;
      return;
    }
    Province province = provincesParNom.get(s.Province__c);
    if (province == null) {
      s.Statut__c = STATUT_PROVINCE_INCONNUE;
      return;
    }
    Decimal dcalOfficiel = province.dcal[indexTranche(s.Annee_Maison__c)];
    if (dcalOfficiel == null || dcalOfficiel == 0) {
      s.Statut__c = STATUT_SANS_DCAL;
      return;
    }
    Decimal dcal = (dcalOfficiel * valeur(params.majorationDcal, 1))
      .setScale(1, RoundingMode.HALF_UP);

    Double surface = s.Surface__c.doubleValue();
    Double aesKwh =
      (dcal + valeur(params.dacs, 0)).doubleValue() *
      (1 / eta.doubleValue() -
      1 / params.scop.doubleValue()) *
      surface;
    Double multiplicateur = s.Bono_Social__c == true && !sansBonification
      ? params.multiplicateurBono.doubleValue()
      : Double.valueOf(1);
    Double prime =
      s.Prix_Valorisation__c.doubleValue() /
      1000 *
      aesKwh *
      facteurFc() *
      multiplicateur *
      coefMitoyennete(s.Mitoyennete__c).doubleValue();
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
    s.Statut__c =
      STATUT_ELIGIBLE +
      (cascade ? ' · cascade 2 PAC' : '') +
      signalMaison;
  }

  /** Rendement de la chaudière existante : fixe pour gaz et fioul, null sinon (non éligible). */
  public Decimal rendement(String typeChaudiere) {
    return typeChaudiere == 'Gaz' ||
      typeChaudiere == 'Fioul'
      ? params.rendementFixe
      : null;
  }

  /** Coefficient appliqué à la prime selon la mitoyenneté (vide ou inconnue = valeur par défaut). */
  public Decimal coefMitoyennete(String mitoyennete) {
    if (mitoyennete == MITOYENNETE_AUCUNE) {
      return valeur(params.coefMitoyenneteAucune, 1);
    }
    if (mitoyennete == MITOYENNETE_1_COTE) {
      return valeur(params.coefMitoyennete1Cote, 1);
    }
    if (mitoyennete == MITOYENNETE_2_COTES) {
      return valeur(params.coefMitoyennete2Cotes, 1);
    }
    return valeur(params.coefMitoyenneteDefaut, 1);
  }

  /** « · maison après 1997 » si la maison est construite après l'année cible, sinon vide. */
  private String signalMaison(Decimal anneeMaison) {
    if (
      anneeMaison == null ||
      params.anneeMaisonCibleMax == null ||
      anneeMaison <= params.anneeMaisonCibleMax
    ) {
      return '';
    }
    return String.format(
      MAISON_APRES,
      new List<Object>{ String.valueOf(params.anneeMaisonCibleMax.intValue()) }
    );
  }

  private static Decimal valeur(Decimal v, Decimal parDefaut) {
    return v == null ? parDefaut : v;
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

  private Double facteurFc() {
    if (!sansBonification) {
      return params.facteurFc.doubleValue();
    }
    return params.facteurFcSansBonification == null
      ? Double.valueOf(1)
      : params.facteurFcSansBonification.doubleValue();
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
    p.surfaceMaxM2 = m.Surface_Max_m2__c;
    p.facteurFcSansBonification = m.Facteur_fC_Sans_Bonification__c;
    p.majorationDcal = m.Majoration_DCAL__c;
    p.dacs = m.DACS_kWh_m2__c;
    p.rendementFixe = m.Rendement_Fixe__c;
    p.coefMitoyenneteAucune = m.Coef_Mitoyennete_Aucune__c;
    p.coefMitoyennete1Cote = m.Coef_Mitoyennete_1_Cote__c;
    p.coefMitoyennete2Cotes = m.Coef_Mitoyennete_2_Cotes__c;
    p.coefMitoyenneteDefaut = m.Coef_Mitoyennete_Defaut__c;
    p.anneeMaisonCibleMax = m.Annee_Maison_Cible_Max__c;
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
      if (String.isNotBlank(m.Noms_Recherche__c)) {
        p.noms = m.Noms_Recherche__c.split(',');
      }
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
