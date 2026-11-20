/**
 * Requêtes de la remontée des leads : sources à lire et recherche des pistes déjà présentes.
 *
 * without sharing : un doublon doit être trouvé quel que soit le propriétaire de la piste
 * (même principe que DoublonService). Toutes les requêtes filtrent sur un champ indexé, sauf
 * pistesParTelephoneExact (voir sa remarque), que le réglage permet de couper.
 */
public without sharing class RemonteeLeadSelector {
  private static final String REGLE_DOUBLON_EXISTANTE = 'TELEPHONE_RES060';
  private static final Integer LIMITE_PISTES = 2000;

  // ------------------------------------------------------------ Sources

  /** Sources à lire : actives, d'un fournisseur actif, dans un ordre stable. */
  public List<Source_Lead__c> sourcesActives() {
    return [
      SELECT Id
      FROM Source_Lead__c
      WHERE Actif__c = TRUE AND Fournisseur__r.Actif__c = TRUE
      ORDER BY Name, Id
      LIMIT 2000
    ];
  }

  public Map<Id, Source_Lead__c> sourcesParId(Set<Id> ids) {
    return new Map<Id, Source_Lead__c>(
      [
        SELECT
          Id,
          Name,
          Actif__c,
          Fournisseur__c,
          Fournisseur__r.Code__c,
          Fournisseur__r.Actif__c,
          Spreadsheet_Id__c,
          Onglet__c,
          Regie__c,
          Campagne__c,
          Type_de_dossier__c,
          Record_Type_Developer_Name__c,
          Origine_piste__c,
          Statut_piste__c,
          Mapping_JSON__c,
          Colonne_Remonte__c,
          Ligne_entete__c,
          Premiere_ligne_a_traiter__c
        FROM Source_Lead__c
        WHERE Id IN :ids
      ]
    );
  }

  // ------------------------------------------------------------ Pistes déjà présentes

  /** Pistes déjà créées pour ces lignes de feuille (champ unique indexé). */
  public List<Lead> pistesParLigneFeuille(Set<String> cles) {
    if (cles.isEmpty()) {
      return new List<Lead>();
    }
    return [
      SELECT
        Id,
        Phone,
        MobilePhone,
        Email,
        CreatedDate,
        Code_Fournisseur__c,
        Telephone_Cle__c,
        Ligne_Feuille__c
      FROM Lead
      WHERE Ligne_Feuille__c IN :cles
    ];
  }

  /** Pistes portant la même clé de téléphone (champ indexé, rempli par la remontée). */
  public List<Lead> pistesParCleTelephone(Set<String> cles) {
    if (cles.isEmpty()) {
      return new List<Lead>();
    }
    return [
      SELECT
        Id,
        Phone,
        MobilePhone,
        Email,
        CreatedDate,
        Code_Fournisseur__c,
        Telephone_Cle__c,
        Ligne_Feuille__c
      FROM Lead
      WHERE Telephone_Cle__c IN :cles
      ORDER BY CreatedDate
      LIMIT :LIMITE_PISTES
    ];
  }

  /** Pistes ayant le même e-mail (champ standard indexé). */
  public List<Lead> pistesParEmail(Set<String> emails) {
    if (emails.isEmpty()) {
      return new List<Lead>();
    }
    return [
      SELECT
        Id,
        Phone,
        MobilePhone,
        Email,
        CreatedDate,
        Code_Fournisseur__c,
        Telephone_Cle__c,
        Ligne_Feuille__c
      FROM Lead
      WHERE Email IN :emails
      ORDER BY CreatedDate
      LIMIT :LIMITE_PISTES
    ];
  }

  /**
   * Anciennes pistes retrouvées sur le numéro tel qu'il est enregistré (34XXXXXXXXX, 0XXXXXXXXX…).
   * Le téléphone standard n'est pas indexé : cette requête parcourt les pistes. Elle est tolérée
   * hors déclencheur, mais ralentit avec le volume ; le réglage « Recherche de doublons sur le
   * téléphone brut » permet de la couper une fois la clé de comparaison remplie sur l'existant.
   */
  public List<Lead> pistesParTelephoneExact(Set<String> numeros) {
    if (numeros.isEmpty()) {
      return new List<Lead>();
    }
    return [
      SELECT
        Id,
        Phone,
        MobilePhone,
        Email,
        CreatedDate,
        Code_Fournisseur__c,
        Telephone_Cle__c,
        Ligne_Feuille__c
      FROM Lead
      WHERE Phone IN :numeros OR MobilePhone IN :numeros
      ORDER BY CreatedDate
      LIMIT :LIMITE_PISTES
    ];
  }

  /**
   * Pistes déjà rattachées au même numéro par le système de doublons existant
   * (Doublon_Groupe__c, règle TELEPHONE_RES060 : pistes RES060 non converties).
   * Deux requêtes indexées : la clé unique du groupe, puis le lookup de la piste.
   * Requêtes dynamiques et protégées : si ce système évolue ou n'est pas visible, la remontée
   * continue avec les autres recherches au lieu de s'arrêter.
   */
  public List<Lead> pistesParGroupeDoublon(Set<String> cles) {
    List<Lead> pistes = new List<Lead>();
    if (cles.isEmpty()) {
      return pistes;
    }
    Set<String> clesUniques = new Set<String>();
    for (String cle : cles) {
      clesUniques.add(REGLE_DOUBLON_EXISTANTE + '|' + cle);
    }
    try {
      Map<Id, SObject> groupes = new Map<Id, SObject>(
        Database.queryWithBinds(
          'SELECT Id FROM Doublon_Groupe__c WHERE Cle_Unique__c IN :clesUniques',
          new Map<String, Object>{ 'clesUniques' => clesUniques },
          AccessLevel.SYSTEM_MODE
        )
      );
      if (groupes.isEmpty()) {
        return pistes;
      }
      Set<Id> idsGroupes = groupes.keySet();
      pistes = (List<Lead>) Database.queryWithBinds(
        'SELECT Id, Phone, MobilePhone, Email, CreatedDate, Code_Fournisseur__c,' +
          ' Telephone_Cle__c, Ligne_Feuille__c FROM Lead' +
          ' WHERE Doublon_Telephone__c IN :idsGroupes ORDER BY CreatedDate LIMIT 2000',
        new Map<String, Object>{ 'idsGroupes' => idsGroupes },
        AccessLevel.SYSTEM_MODE
      );
    } catch (Exception e) {
      System.debug(
        LoggingLevel.WARN,
        'RemonteeLeadSelector.pistesParGroupeDoublon : ' + e.getMessage()
      );
    }
    return pistes;
  }

  // ------------------------------------------------------------ Chaîne de traitement

  /** Nombre de traitements de cette classe en attente ou en cours. */
  public Integer travauxEnCours(String nomClasse) {
    return [
      SELECT COUNT()
      FROM AsyncApexJob
      WHERE
        JobType = 'Queueable'
        AND ApexClass.Name = :nomClasse
        AND Status IN ('Holding', 'Queued', 'Preparing', 'Processing')
    ];
  }

  /** Vrai si une tâche planifiée porte déjà ce nom. */
  public Boolean tachePlanifieeExiste(String nom) {
    return [SELECT COUNT() FROM CronTrigger WHERE CronJobDetail.Name = :nom] >
      0;
  }
}
