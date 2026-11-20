/**
 * Données communes aux tests de la remontée des leads : réglage, fournisseur, régie (campagne
 * « Est REGIE »), tarif, source configurée comme une vraie feuille (mêmes colonnes que la feuille
 * « Leads PAC »), lignes de feuille, pistes et dossiers déjà présents.
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
    r.delaiDoublonJours = 14;
    r.statutDossierAnnule = statutDossierAnnule();
    RemonteeLeadReglage.forcage = r;
    return r;
  }

  public static Fournisseur_Lead__c fournisseur(String code) {
    Fournisseur_Lead__c f = new Fournisseur_Lead__c(
      Name = 'Fournisseur ' + code,
      Code__c = code,
      Actif__c = true
    );
    insert f;
    return f;
  }

  /**
   * Valeur « annulé » de « RDV- Statut Dossier », lue dans l'org : la liste est restreinte et sa
   * valeur exacte n'a pas à être recopiée dans les tests.
   */
  public static String statutDossierAnnule() {
    for (
      Schema.PicklistEntry valeur : Pro__c.PAC_STATUT_DOSSIER__c.getDescribe()
        .getPicklistValues()
    ) {
      if (valeur.isActive() && valeur.getValue().containsIgnoreCase('annul')) {
        return valeur.getValue();
      }
    }
    return null;
  }

  /** Autre valeur de « RDV- Statut Dossier » : un dossier vivant. */
  public static String statutDossierVivant() {
    for (
      Schema.PicklistEntry valeur : Pro__c.PAC_STATUT_DOSSIER__c.getDescribe()
        .getPicklistValues()
    ) {
      if (valeur.isActive() && !valeur.getValue().containsIgnoreCase('annul')) {
        return valeur.getValue();
      }
    }
    return null;
  }

  /** Régie : une campagne « Est REGIE », créée comme le font les tests existants de l'org. */
  public static Campaign regie(String nom) {
    Campaign c = new Campaign(
      Name = nom,
      Status = 'In Progress',
      StartDate = Date.today(),
      IsActive = true,
      EstREGIE__c = true
    );
    insert c;
    return c;
  }

  /** Compte de facturation d'une régie : relié par « Accès REGIE ». */
  public static Account compteDeLaRegie(Campaign regie) {
    Account a = new Account(
      Name = 'Compte ' + regie.Name,
      Acces_REGIE__c = regie.Id
    );
    insert a;
    return a;
  }

  /** Tarif à prix fixe, sans date de fin, pour un couple fournisseur + régie. */
  public static Tarif_Lead__c tarifFixe(
    Fournisseur_Lead__c fournisseur,
    Campaign regie,
    Decimal achat,
    Decimal revente
  ) {
    Tarif_Lead__c t = new Tarif_Lead__c(
      Fournisseur__c = fournisseur.Id,
      Regie__c = regie.Id,
      Date_debut__c = Date.today().addYears(-1),
      Actif__c = true,
      Mode_achat__c = LeadPrixService.MODE_FIXE,
      Prix_Achat__c = achat,
      Regle_revente__c = LeadPrixService.REVENTE_FIXE,
      Prix_Revente__c = revente
    );
    insert t;
    return t;
  }

  /** Tarif au pourcentage de campagne : prix provisoire, revente = achat + marge en %. */
  public static Tarif_Lead__c tarifPourcentage(
    Fournisseur_Lead__c fournisseur,
    Campaign regie,
    Decimal provisoire,
    Decimal margePourcent
  ) {
    Tarif_Lead__c t = new Tarif_Lead__c(
      Fournisseur__c = fournisseur.Id,
      Regie__c = regie.Id,
      Date_debut__c = Date.today().addYears(-1),
      Actif__c = true,
      Mode_achat__c = LeadPrixService.MODE_POURCENTAGE,
      Taux__c = 12,
      Prix_Achat_Provisoire__c = provisoire,
      Regle_revente__c = LeadPrixService.REVENTE_MARGE_POURCENT,
      Marge__c = margePourcent
    );
    insert t;
    return t;
  }

  /** Source active sans régie, relue avec tous les champs dont le traitement a besoin. */
  public static Source_Lead__c source(
    Fournisseur_Lead__c fournisseur,
    String idClasseur
  ) {
    return source(fournisseur, idClasseur, null);
  }

  /** Source active d'une régie (une feuille = une régie fixe). */
  public static Source_Lead__c source(
    Fournisseur_Lead__c fournisseur,
    String idClasseur,
    Campaign regie
  ) {
    Source_Lead__c s = new Source_Lead__c(
      Name = 'Feuille ' + idClasseur,
      Fournisseur__c = fournisseur.Id,
      Regie__c = regie?.Id,
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

  /** Une ligne de feuille dont la colonne « Prix » est remplie par le fournisseur. */
  public static List<String> ligneAvecPrix(
    String nom,
    String numero,
    String mail,
    String prix
  ) {
    List<String> cellules = ligne(nom, numero, mail, 'Leon');
    cellules.add(prix);
    return cellules;
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

  /** Fait remonter des lignes (à partir de la ligne 2) comme la chaîne, sans passer par Google. */
  public static RemonteeLeadService.Resultat remonter(
    Source_Lead__c source,
    List<List<String>> lignes
  ) {
    List<RemonteeLeadService.Travail> travaux = new List<RemonteeLeadService.Travail>();
    Integer numero = 2;
    for (List<String> cellules : lignes) {
      travaux.add(travail(source, numero, cellules));
      numero++;
    }
    return new RemonteeLeadService().traiter(travaux, reglage());
  }

  /** Un mois de leads d'un fournisseur pour une régie, prêt à être clôturé. */
  public class Mois {
    public Fournisseur_Lead__c fournisseur;
    public Campaign regie;
    public Account compte;
    public Tarif_Lead__c tarif;
    public Source_Lead__c source;
  }

  /**
   * Quatre lignes remontées ce mois-ci : deux leads normaux (Ana, Luis), un doublon interne (payé
   * au fournisseur, non facturé) et un faux numéro avec e-mail (piste créée, ni payée ni facturée).
   * @param auPourcentage vrai : tarif au pourcentage de campagne (prix provisoire 4 €, revente à
   *                      + 50 %) ; faux : tarif fixe, achat 5 €, revente 10 €.
   */
  public static Mois moisDeLeads(Boolean auPourcentage) {
    Mois m = new Mois();
    m.fournisseur = fournisseur('F001');
    m.regie = regie('Régie de test');
    m.compte = compteDeLaRegie(m.regie);
    m.tarif = auPourcentage
      ? tarifPourcentage(m.fournisseur, m.regie, 4, 50)
      : tarifFixe(m.fournisseur, m.regie, 5, 10);
    m.source = source(m.fournisseur, 'classeur-F001', m.regie);
    // Le compte de la régie est posé sur la Source par la chaîne ; ici, à la main.
    update new Source_Lead__c(Id = m.source.Id, Compte_Regie__c = m.compte.Id);
    pisteExistante('Déjà connue', '34688111222', null);
    remonter(
      m.source,
      new List<List<String>>{
        ligne('Ana', '34666111222', 'ana@exemple.com', 'Leon'),
        ligne('Luis', '34677111222', 'luis@exemple.com', 'Lugo'),
        ligne('Déjà connue', '688111222', 'connue@exemple.com', 'Soria'),
        ligne('Juan', '0', 'juan@exemple.com', 'Ourense')
      }
    );
    return m;
  }

  /** Dossier déjà présent pour ce numéro, dans le statut donné. */
  public static Pro__c dossierExistant(
    String nom,
    String telephone,
    String statut
  ) {
    Pro__c d = new Pro__c(
      Name = nom,
      Phone__c = telephone,
      PAC_STATUT_DOSSIER__c = statut
    );
    insert d;
    return d;
  }
}
