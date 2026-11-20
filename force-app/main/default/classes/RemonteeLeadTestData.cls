/**
 * Données communes aux tests de la remontée des leads : réglage, fournisseur, source configurée
 * comme une vraie feuille (mêmes colonnes que la feuille « Leads PAC »), lignes de feuille.
 */
@IsTest
public class RemonteeLeadTestData {
  public static final String ID_CLASSEUR = 'classeur-de-test';
  public static final String ONGLET = 'Leads PAC';
  public static final String TYPE_ENREGISTREMENT = 'RESIDENTIEL_LEADS';
  /** Rang (0 = A) de la colonne « Remonté » dans TITRES. */
  public static final Integer RANG_REMONTE = 14;
  public static final List<String> TITRES = new List<String>{
    'Nom',
    'Num',
    'Mail',
    'CP',
    'Province',
    'Proprio',
    'Chauffage',
    'Année chauffage',
    'Bono ?',
    'Année',
    'm²',
    'Date',
    'Canal',
    'Prix',
    'Remonté'
  };
  public static final String CORRESPONDANCE =
    '{"Nom":"LastName","Num":"Phone","Mail":"Email","CP":"CP_Formulaire__c",' +
    '"Province":"City","Proprio":"Nature_de_l_occupation_Formulaire__c",' +
    '"Chauffage":"Mode_de_chauffage_Formulaire__c",' +
    '"Année chauffage":"RES060_Annee_chaudiere_formulaire__c","Bono ?":"RES060__c",' +
    '"Année":"RES060_Annee_Logement_formulaire__c","m²":"RES060_SHAB_Formulaire__c",' +
    '"Date":"Heure_de_cr_ation__c"}';

  /** Réglage actif imposé aux classes testées (les Custom Metadata ne se créent pas en test). */
  public static RemonteeLeadReglage reglage() {
    RemonteeLeadReglage r = new RemonteeLeadReglage();
    r.actif = true;
    r.taillePaquet = 20;
    r.intervalleMinutes = 3;
    r.tentativesMax = 5;
    r.nomCertificat = 'Certificat_De_Test';
    r.emailCompteService = 'robot@exemple.iam.gserviceaccount.com';
    r.rechercheTelephoneExacte = true;
    RemonteeLeadReglage.forcage = r;
    return r;
  }

  public static Fournisseur_Lead__c fournisseur(String code) {
    Fournisseur_Lead__c f = new Fournisseur_Lead__c(
      Name = 'Fournisseur ' + code,
      Code__c = code,
      Type__c = 'Externe',
      Actif__c = true
    );
    insert f;
    return f;
  }

  /** Source active, relue avec tous les champs dont le traitement a besoin. */
  public static Source_Lead__c source(
    Fournisseur_Lead__c fournisseur,
    String idClasseur
  ) {
    Source_Lead__c s = new Source_Lead__c(
      Name = 'Feuille ' + idClasseur,
      Fournisseur__c = fournisseur.Id,
      Spreadsheet_Id__c = idClasseur,
      Onglet__c = ONGLET,
      Record_Type_Developer_Name__c = TYPE_ENREGISTREMENT,
      Origine_piste__c = 'LEADS',
      Statut_piste__c = 'New',
      Campagne__c = 'TEST REMONTEE',
      Type_de_dossier__c = 'RESIDENTIEL_REGIES_-_RES060',
      Mapping_JSON__c = CORRESPONDANCE,
      Colonne_Remonte__c = 'Remonté',
      Ligne_entete__c = 1,
      Actif__c = true
    );
    insert s;
    return relire(s.Id);
  }

  public static Source_Lead__c relire(Id idSource) {
    return new RemonteeLeadSelector()
      .sourcesParId(new Set<Id>{ idSource })
      .get(idSource);
  }

  /** Une ligne de feuille, sans résultat. */
  public static List<String> ligne(
    String nom,
    String numero,
    String mail,
    String province
  ) {
    return new List<String>{
      nom,
      numero,
      mail,
      '24730',
      province,
      'si',
      'caldera_de_gas',
      'instalada_antes_del_año_2000',
      'no',
      'antes_de_1985',
      'menos_de_120_m²',
      '20/11/2026 10:00:00',
      'FB 1'
    };
  }

  /** Feuille : la ligne des titres suivie des lignes données. */
  public static List<List<String>> feuille(List<List<String>> lignes) {
    List<List<String>> contenu = new List<List<String>>{ TITRES.clone() };
    contenu.addAll(lignes);
    return contenu;
  }

  /** Ligne prête pour RemonteeLeadService, comme si elle venait d'être lue dans la feuille. */
  public static RemonteeLeadService.Travail travail(
    Source_Lead__c source,
    Integer numero,
    List<String> cellules
  ) {
    RemonteeLeadFeuille.Lecture lecture = RemonteeLeadFeuille.analyser(
      TITRES,
      new List<List<String>>{ cellules },
      numero,
      1,
      'Remonté',
      10
    );
    return new RemonteeLeadService.Travail(source, lecture.aTraiter[0]);
  }

  /** Piste déjà présente dans Salesforce, créée comme le ferait un Zap. */
  public static Lead pisteExistante(
    String nom,
    String telephone,
    String email
  ) {
    Lead p = new Lead(
      RecordTypeId = Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName()
        .get(TYPE_ENREGISTREMENT)
        .getRecordTypeId(),
      LastName = nom,
      Phone = telephone,
      Email = email,
      LeadSource = 'LEADS',
      Status = 'New'
    );
    insert p;
    return p;
  }
}
