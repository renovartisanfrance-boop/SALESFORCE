/**
 * Requêtes de la remontée des leads : sources à lire, recherche des personnes déjà connues
 * (pistes, dossiers, lignes déjà rejetées) et compte de facturation des régies.
 *
 * without sharing : un doublon doit être trouvé quel que soit le propriétaire de la piste ou du
 * dossier (même principe que DoublonService). Toutes les requêtes filtrent sur un champ indexé,
 * sauf pistesParTelephoneExact et dossiersParTelephoneExact (voir leur remarque), que le réglage
 * permet de couper.
 */
public without sharing class RemonteeLeadSelector {
  private static final String REGLE_DOUBLON_EXISTANTE = 'TELEPHONE_RES060';
  private static final Integer LIMITE = 2000;

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
          Regie__r.EstREGIE__c,
          Compte_Regie__c,
          Campagne__c,
          Type_de_dossier__c,
          Record_Type_Developer_Name__c,
          Origine_piste__c,
          Statut_piste__c,
          Mapping_JSON__c,
          Colonne_Remonte__c,
          Colonne_Prix__c,
          Ligne_entete__c,
          Premiere_ligne_a_traiter__c
        FROM Source_Lead__c
        WHERE Id IN :ids
      ]
    );
  }

  /**
   * Comptes de facturation des régies : ceux dont « Accès REGIE » pointe vers la campagne.
   * Le champ sert aussi aux prévisiteurs ; on ne lit ici que les campagnes demandées.
   */
  public List<Account> comptesParRegie(Set<Id> regies) {
    if (regies.isEmpty()) {
      return new List<Account>();
    }
    return [
      SELECT Id, Name, Acces_REGIE__c
      FROM Account
      WHERE Acces_REGIE__c IN :regies
      ORDER BY CreatedDate
      LIMIT :LIMITE
    ];
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
        LastModifiedDate,
        LastActivityDate,
        IsConverted,
        ConvertedOpportunityId,
        Source_Lead__c,
        Campagne_REGIE__c,
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
        LastModifiedDate,
        LastActivityDate,
        IsConverted,
        ConvertedOpportunityId,
        Source_Lead__c,
        Campagne_REGIE__c,
        Code_Fournisseur__c,
        Telephone_Cle__c,
        Ligne_Feuille__c
      FROM Lead
      WHERE Telephone_Cle__c IN :cles
      ORDER BY CreatedDate
      LIMIT :LIMITE
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
        LastModifiedDate,
        LastActivityDate,
        IsConverted,
        ConvertedOpportunityId,
        Source_Lead__c,
        Campagne_REGIE__c,
        Code_Fournisseur__c,
        Telephone_Cle__c,
        Ligne_Feuille__c
      FROM Lead
      WHERE Email IN :emails
      ORDER BY CreatedDate
      LIMIT :LIMITE
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
        LastModifiedDate,
        LastActivityDate,
        IsConverted,
        ConvertedOpportunityId,
        Source_Lead__c,
        Campagne_REGIE__c,
        Code_Fournisseur__c,
        Telephone_Cle__c,
        Ligne_Feuille__c
      FROM Lead
      WHERE Phone IN :numeros OR MobilePhone IN :numeros
      ORDER BY CreatedDate
      LIMIT :LIMITE
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
    Set<Id> idsGroupes = groupesDoublon(cles);
    if (idsGroupes.isEmpty()) {
      return pistes;
    }
    try {
      pistes = (List<Lead>) Database.queryWithBinds(
        'SELECT Id, Phone, MobilePhone, Email, CreatedDate, LastModifiedDate, LastActivityDate,' +
          ' IsConverted, ConvertedOpportunityId, Source_Lead__c, Campagne_REGIE__c,' +
          ' Code_Fournisseur__c, Telephone_Cle__c, Ligne_Feuille__c FROM Lead' +
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

  // ------------------------------------------------------------ Dossiers déjà présents

  /**
   * Dossiers RES060 rattachés au même numéro par le système de doublons existant
   * (même groupe que les pistes : Pro__c.Doublon_Telephone__c, lookup indexé).
   */
  public List<Pro__c> dossiersParGroupeDoublon(Set<String> cles) {
    List<Pro__c> dossiers = new List<Pro__c>();
    Set<Id> idsGroupes = groupesDoublon(cles);
    if (idsGroupes.isEmpty()) {
      return dossiers;
    }
    try {
      dossiers = (List<Pro__c>) Database.queryWithBinds(
        'SELECT Id, Phone__c, Email__c, CreatedDate, PAC_STATUT_DOSSIER__c, Campagne_REGIE__c,' +
          ' Opportunite__c FROM Pro__c' +
          ' WHERE Doublon_Telephone__c IN :idsGroupes ORDER BY CreatedDate LIMIT 2000',
        new Map<String, Object>{ 'idsGroupes' => idsGroupes },
        AccessLevel.SYSTEM_MODE
      );
    } catch (Exception e) {
      System.debug(
        LoggingLevel.WARN,
        'RemonteeLeadSelector.dossiersParGroupeDoublon : ' + e.getMessage()
      );
    }
    return dossiers;
  }

  /** Dossiers des opportunités issues de pistes converties (lookup indexé). */
  public List<Pro__c> dossiersParOpportunite(Set<Id> opportunites) {
    if (opportunites.isEmpty()) {
      return new List<Pro__c>();
    }
    return [
      SELECT
        Id,
        Phone__c,
        Email__c,
        CreatedDate,
        PAC_STATUT_DOSSIER__c,
        Campagne_REGIE__c,
        Opportunite__c
      FROM Pro__c
      WHERE Opportunite__c IN :opportunites
      ORDER BY CreatedDate
      LIMIT :LIMITE
    ];
  }

  /**
   * Dossiers retrouvés sur le numéro tel qu'il est enregistré. Comme pour les pistes, le champ
   * n'est pas indexé : la requête parcourt les dossiers et le même réglage permet de la couper.
   */
  public List<Pro__c> dossiersParTelephoneExact(Set<String> numeros) {
    if (numeros.isEmpty()) {
      return new List<Pro__c>();
    }
    return [
      SELECT
        Id,
        Phone__c,
        Email__c,
        CreatedDate,
        PAC_STATUT_DOSSIER__c,
        Campagne_REGIE__c,
        Opportunite__c
      FROM Pro__c
      WHERE Phone__c IN :numeros
      ORDER BY CreatedDate
      LIMIT :LIMITE
    ];
  }

  /** Dossiers ayant le même e-mail client (pour les lignes sans téléphone valable). */
  public List<Pro__c> dossiersParEmail(Set<String> emails) {
    if (emails.isEmpty()) {
      return new List<Pro__c>();
    }
    return [
      SELECT
        Id,
        Phone__c,
        Email__c,
        CreatedDate,
        PAC_STATUT_DOSSIER__c,
        Campagne_REGIE__c,
        Opportunite__c
      FROM Pro__c
      WHERE Email__c IN :emails
      ORDER BY CreatedDate
      LIMIT :LIMITE
    ];
  }

  // ------------------------------------------------------------ Lignes déjà rejetées

  /**
   * Lignes de ces Sources déjà notées « doublon » ou « faux numéro » pour ces personnes.
   * Sert à reconnaître une personne envoyée deux fois dans la même feuille, même quand la première
   * ligne n'a pas créé de piste. Les erreurs ne comptent pas : leur ligne sera retentée.
   */
  public List<Rejet_Lead__c> rejetsDejaNotes(
    Set<Id> sources,
    Set<String> clesTelephone,
    Set<String> emails,
    Set<String> motifs
  ) {
    if (sources.isEmpty() || (clesTelephone.isEmpty() && emails.isEmpty())) {
      return new List<Rejet_Lead__c>();
    }
    return [
      SELECT
        Id,
        Source__c,
        Ligne__c,
        Motif__c,
        Telephone_Cle__c,
        Email__c,
        Date_rejet__c
      FROM Rejet_Lead__c
      WHERE
        Source__c IN :sources
        AND Motif__c IN :motifs
        AND (Telephone_Cle__c IN :clesTelephone
        OR Email__c IN :emails)
      ORDER BY Ligne__c
      LIMIT :LIMITE
    ];
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

  // ------------------------------------------------------------ Outils

  /** Groupes du système de doublons existant pour ces clés de téléphone (clé unique indexée). */
  private Set<Id> groupesDoublon(Set<String> cles) {
    Set<Id> ids = new Set<Id>();
    if (cles.isEmpty()) {
      return ids;
    }
    Set<String> clesUniques = new Set<String>();
    for (String cle : cles) {
      clesUniques.add(REGLE_DOUBLON_EXISTANTE + '|' + cle);
    }
    try {
      ids = new Map<Id, SObject>(
          Database.queryWithBinds(
            'SELECT Id FROM Doublon_Groupe__c WHERE Cle_Unique__c IN :clesUniques',
            new Map<String, Object>{ 'clesUniques' => clesUniques },
            AccessLevel.SYSTEM_MODE
          )
        )
        .keySet();
    } catch (Exception e) {
      System.debug(
        LoggingLevel.WARN,
        'RemonteeLeadSelector.groupesDoublon : ' + e.getMessage()
      );
    }
    return ids;
  }
}
