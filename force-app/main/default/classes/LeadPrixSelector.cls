/**
 * Requêtes des prix des leads : tarifs par couple fournisseur + régie, et clôtures mensuelles.
 *
 * without sharing : le prix d'un lead vient de la grille de l'entreprise, quel que soit
 * l'utilisateur qui crée la piste (la remontée automatique aujourd'hui, une régie qui saisira
 * ses propres leads plus tard). Celui qui crée la piste n'a pas à voir les tarifs pour qu'ils
 * s'appliquent, et un tarif invisible ne doit pas donner une piste « sans tarif ».
 * Toutes les requêtes filtrent sur des lookups ou une clé unique (champs indexés).
 */
public without sharing class LeadPrixSelector {
  private static final Integer LIMITE = 10000;

  // ------------------------------------------------------------ Tarifs

  /** Tarifs actifs de ces fournisseurs et de ces régies qui s'appliquent ce jour-là. */
  public List<Tarif_Lead__c> tarifsApplicables(
    Set<Id> fournisseurs,
    Set<Id> regies,
    Date jour
  ) {
    if (fournisseurs.isEmpty() || regies.isEmpty()) {
      return new List<Tarif_Lead__c>();
    }
    return [
      SELECT
        Id,
        Fournisseur__c,
        Regie__c,
        Date_debut__c,
        Date_fin__c,
        Mode_achat__c,
        Prix_Achat__c,
        Taux__c,
        Prix_Achat_Provisoire__c,
        Regle_revente__c,
        Prix_Revente__c,
        Marge__c,
        Faux_numeros_payes__c
      FROM Tarif_Lead__c
      WHERE
        Actif__c = TRUE
        AND Fournisseur__c IN :fournisseurs
        AND Regie__c IN :regies
        AND Date_debut__c <= :jour
        AND (Date_fin__c = NULL
        OR Date_fin__c >= :jour)
      ORDER BY Date_debut__c DESC, CreatedDate DESC
      LIMIT :LIMITE
    ];
  }

  /** Tous les tarifs actifs de ces fournisseurs et régies, sauf ceux en cours d'enregistrement. */
  public List<Tarif_Lead__c> tarifsActifs(
    Set<Id> fournisseurs,
    Set<Id> regies,
    Set<Id> saufCeuxLa
  ) {
    if (fournisseurs.isEmpty() || regies.isEmpty()) {
      return new List<Tarif_Lead__c>();
    }
    return [
      SELECT Id, Name, Fournisseur__c, Regie__c, Date_debut__c, Date_fin__c
      FROM Tarif_Lead__c
      WHERE
        Actif__c = TRUE
        AND Fournisseur__c IN :fournisseurs
        AND Regie__c IN :regies
        AND Id NOT IN :saufCeuxLa
      LIMIT :LIMITE
    ];
  }

  // ------------------------------------------------------------ Sources

  /** Fournisseur et régie des Sources (pour tarifer une piste à partir de sa Source). */
  public Map<Id, Source_Lead__c> sourcesParId(Set<Id> ids) {
    if (ids.isEmpty()) {
      return new Map<Id, Source_Lead__c>();
    }
    return new Map<Id, Source_Lead__c>(
      [
        SELECT Id, Fournisseur__c, Regie__c, Compte_Regie__c
        FROM Source_Lead__c
        WHERE Id IN :ids
      ]
    );
  }

  /** Sources qui ont une régie, pour ouvrir les clôtures d'un mois. */
  public List<Source_Lead__c> sourcesAvecRegie() {
    return [
      SELECT Id, Fournisseur__c, Regie__c, Compte_Regie__c
      FROM Source_Lead__c
      WHERE Regie__c != NULL
      LIMIT :LIMITE
    ];
  }

  /** Sources des couples fournisseur + régie demandés. */
  public List<Source_Lead__c> sourcesDesCouples(
    Set<Id> fournisseurs,
    Set<Id> regies
  ) {
    if (fournisseurs.isEmpty() || regies.isEmpty()) {
      return new List<Source_Lead__c>();
    }
    return [
      SELECT Id, Fournisseur__c, Regie__c, Compte_Regie__c
      FROM Source_Lead__c
      WHERE Fournisseur__c IN :fournisseurs AND Regie__c IN :regies
      LIMIT :LIMITE
    ];
  }

  // ------------------------------------------------------------ Clôtures

  public List<Cloture_Lead__c> cloturesParId(Set<Id> ids) {
    if (ids.isEmpty()) {
      return new List<Cloture_Lead__c>();
    }
    return [
      SELECT
        Id,
        Name,
        Fournisseur__c,
        Regie__c,
        Compte_Regie__c,
        Periode__c,
        Cle__c,
        Statut__c,
        Nombre_payes__c,
        Nombre_a_repartir__c,
        Nombre_factures__c,
        Montant_achat__c,
        Montant_revente__c,
        Budget__c,
        Taux__c,
        Montant_facture_fournisseur__c,
        Cout_unitaire__c,
        Alerte__c
      FROM Cloture_Lead__c
      WHERE Id IN :ids
    ];
  }

  public List<Cloture_Lead__c> cloturesParCle(Set<String> cles) {
    if (cles.isEmpty()) {
      return new List<Cloture_Lead__c>();
    }
    return [
      SELECT Id, Cle__c, Statut__c
      FROM Cloture_Lead__c
      WHERE Cle__c IN :cles
    ];
  }

  /** Total facturable à chaque régie, toutes clôtures confondues. */
  public Map<Id, Decimal> montantsReventeParRegie(Set<Id> regies) {
    Map<Id, Decimal> montants = new Map<Id, Decimal>();
    if (regies.isEmpty()) {
      return montants;
    }
    for (AggregateResult a : [
      SELECT Regie__c regie, SUM(Montant_revente__c) montant
      FROM Cloture_Lead__c
      WHERE Regie__c IN :regies
      GROUP BY Regie__c
    ]) {
      Decimal montant = (Decimal) a.get('montant');
      montants.put((Id) a.get('regie'), montant == null ? 0 : montant);
    }
    return montants;
  }

  // ------------------------------------------------------------ Pistes et rejets d'une période

  /** Par Source : nombre et montant d'achat des pistes payées au fournisseur sur la période. */
  public List<AggregateResult> pistesPayees(
    Set<Id> sources,
    DateTime debut,
    DateTime fin
  ) {
    return [
      SELECT
        Source_Lead__c feuille,
        COUNT(Id) nombre,
        SUM(Prix_Achat__c) montant
      FROM Lead
      WHERE
        Source_Lead__c IN :sources
        AND CreatedDate >= :debut
        AND CreatedDate < :fin
        AND Paye_fournisseur__c = TRUE
      GROUP BY Source_Lead__c
    ];
  }

  /** Par Source : nombre de pistes payées dont le prix attend la clôture. */
  public List<AggregateResult> pistesARepartir(
    Set<Id> sources,
    DateTime debut,
    DateTime fin,
    String statutProvisoire
  ) {
    return [
      SELECT Source_Lead__c feuille, COUNT(Id) nombre
      FROM Lead
      WHERE
        Source_Lead__c IN :sources
        AND CreatedDate >= :debut
        AND CreatedDate < :fin
        AND Paye_fournisseur__c = TRUE
        AND Statut_Prix__c = :statutProvisoire
      GROUP BY Source_Lead__c
    ];
  }

  /** Par Source : nombre et montant de revente des pistes facturées à la régie sur la période. */
  public List<AggregateResult> pistesFacturees(
    Set<Id> sources,
    DateTime debut,
    DateTime fin
  ) {
    return [
      SELECT
        Source_Lead__c feuille,
        COUNT(Id) nombre,
        SUM(Prix_Revente__c) montant
      FROM Lead
      WHERE
        Source_Lead__c IN :sources
        AND CreatedDate >= :debut
        AND CreatedDate < :fin
        AND Facture_regie__c = TRUE
      GROUP BY Source_Lead__c
    ];
  }

  /**
   * Par Source : lignes rejetées mais payées au fournisseur (doublons internes, faux numéros
   * payés). Celles qui ont quand même créé une piste sont comptées avec les pistes.
   */
  public List<AggregateResult> rejetsPayes(
    Set<Id> sources,
    DateTime debut,
    DateTime fin
  ) {
    return [
      SELECT Source__c feuille, COUNT(Id) nombre, SUM(Prix_Achat__c) montant
      FROM Rejet_Lead__c
      WHERE
        Source__c IN :sources
        AND Date_rejet__c >= :debut
        AND Date_rejet__c < :fin
        AND Paye_fournisseur__c = TRUE
        AND Piste_creee__c = NULL
      GROUP BY Source__c
    ];
  }

  /** Lignes rejetées et payées dont le prix attend la clôture (tarif au pourcentage). */
  public List<Rejet_Lead__c> rejetsARepartir(
    Set<Id> sources,
    DateTime debut,
    DateTime fin,
    String statutProvisoire
  ) {
    return [
      SELECT Id, Source__c, Prix_Achat__c, Statut_Prix__c
      FROM Rejet_Lead__c
      WHERE
        Source__c IN :sources
        AND Date_rejet__c >= :debut
        AND Date_rejet__c < :fin
        AND Paye_fournisseur__c = TRUE
        AND Piste_creee__c = NULL
        AND Statut_Prix__c = :statutProvisoire
      LIMIT :LIMITE
    ];
  }

  /** Pistes payées au prix provisoire sur la période : celles que la clôture doit corriger. */
  public Database.QueryLocator pistesARepartirUneParUne(
    Set<Id> sources,
    DateTime debut,
    DateTime fin,
    String statutProvisoire
  ) {
    return Database.getQueryLocator(
      [
        SELECT
          Id,
          Prix_Achat__c,
          Prix_Revente__c,
          Facture_regie__c,
          Statut_Prix__c,
          Tarif_Lead__c,
          Tarif_Lead__r.Regle_revente__c,
          Tarif_Lead__r.Prix_Revente__c,
          Tarif_Lead__r.Marge__c
        FROM Lead
        WHERE
          Source_Lead__c IN :sources
          AND CreatedDate >= :debut
          AND CreatedDate < :fin
          AND Paye_fournisseur__c = TRUE
          AND Statut_Prix__c = :statutProvisoire
      ]
    );
  }
}
