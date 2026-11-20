/**
 * Clôture mensuelle des leads : pour chaque couple fournisseur + régie et chaque mois, combien de
 * leads sont dus au fournisseur, combien sont facturables à la régie, et pour quels montants
 * (Cloture_Lead__c). C'est un relevé : aucune facture n'est produite.
 *
 * Trois actions, appelables depuis un flux ou un bouton (executer) :
 *  - « Ouvrir le mois » : crée ou recalcule les clôtures de tous les couples actifs sur le mois ;
 *  - « Calculer »       : recalcule une clôture ;
 *  - « Clôturer »       : fige une clôture. Si des leads sont au prix provisoire (fournisseur payé au
 *    pourcentage de la campagne), le coût réel est réparti sur TOUS les leads payés au prix
 *    provisoire de la période — le fournisseur est payé sur tous ses leads, doublons internes
 *    compris — puis leur prix devient définitif et la revente qui en dépend est recalculée.
 *
 * Sont comptés comme payés au fournisseur : les pistes cochées « Payé au fournisseur » et les lignes
 * rejetées cochées de même (doublons internes, faux numéros payés) qui n'ont pas créé de piste.
 *
 * Écritures en mode système : la clôture écrit des champs de prix que l'utilisateur ne modifie pas
 * à la main ; le droit de lancer l'action vient du jeu d'autorisations « Remontee_Leads ».
 */
public with sharing class LeadClotureService {
  public static final String STATUT_OUVERTE = 'Ouverte';
  public static final String STATUT_EN_COURS = 'En cours';
  public static final String STATUT_CLOTUREE = 'Clôturée';
  public static final String ACTION_OUVRIR = 'Ouvrir le mois';
  public static final String ACTION_CALCULER = 'Calculer';
  public static final String ACTION_CLOTURER = 'Clôturer';

  public class ClotureException extends Exception {
  }

  public class Demande {
    @InvocableVariable(
      label='Action'
      description='« Ouvrir le mois », « Calculer » ou « Clôturer »'
      required=true
    )
    public String action;
    @InvocableVariable(
      label='Mois'
      description='Un jour du mois concerné (action « Ouvrir le mois »)'
    )
    public Date mois;
    @InvocableVariable(
      label='Clôture'
      description='Clôture à calculer ou à clôturer'
    )
    public Id clotureId;
  }

  public class Reponse {
    @InvocableVariable(label='Réussi')
    public Boolean reussi = false;
    @InvocableVariable(label='Message')
    public String message;
  }

  @TestVisible
  private LeadPrixSelector selector = new LeadPrixSelector();
  /** En test, le traitement différé n'est pas lancé deux fois : il est gardé ici pour vérification. */
  @TestVisible
  private static LeadClotureBatch dernierLot;

  // ------------------------------------------------------------ Action appelable

  /**
   * Une seule demande par appel : chaque action interroge les pistes d'un mois et « Clôturer »
   * peut lancer un traitement différé. Les demandes suivantes sont refusées avec un message clair
   * plutôt que traitées en boucle.
   */
  @InvocableMethod(
    label='Clôture des leads'
    description='Ouvre un mois, recalcule une clôture ou la fige (relevé des leads par fournisseur et par régie).'
    category='Leads'
  )
  public static List<Reponse> executer(List<Demande> demandes) {
    List<Reponse> reponses = new List<Reponse>();
    Boolean premiere = true;
    for (Demande demande : demandes) {
      Reponse reponse = new Reponse();
      if (premiere) {
        premiere = false;
        try {
          reponse.message = new LeadClotureService().traiter(demande);
          reponse.reussi = true;
        } catch (Exception e) {
          reponse.message = e.getMessage();
        }
      } else {
        reponse.message = 'Une seule demande de clôture par appel : relancez pour celle-ci.';
      }
      reponses.add(reponse);
    }
    return reponses;
  }

  private String traiter(Demande demande) {
    if (demande.action == ACTION_OUVRIR) {
      if (demande.mois == null) {
        throw new ClotureException('Indiquez un jour du mois à ouvrir.');
      }
      Integer nombre = ouvrirMois(demande.mois).size();
      return nombre + ' clôture(s) créée(s) ou recalculée(s).';
    }
    if (demande.clotureId == null) {
      throw new ClotureException('Indiquez la clôture concernée.');
    }
    if (demande.action == ACTION_CALCULER) {
      calculer(new Set<Id>{ demande.clotureId });
      return 'Clôture recalculée.';
    }
    if (demande.action == ACTION_CLOTURER) {
      return cloturer(demande.clotureId);
    }
    throw new ClotureException(
      'Action inconnue : ' +
        demande.action +
        '. Actions possibles : ' +
        ACTION_OUVRIR +
        ', ' +
        ACTION_CALCULER +
        ', ' +
        ACTION_CLOTURER +
        '.'
    );
  }

  // ------------------------------------------------------------ Ouvrir un mois

  /**
   * Crée ou recalcule la clôture de chaque couple fournisseur + régie qui a eu des leads payés ou
   * facturés pendant le mois. Les clôtures déjà figées ne sont pas touchées.
   */
  public List<Cloture_Lead__c> ouvrirMois(Date jour) {
    Date periode = jour.toStartOfMonth();
    Map<String, Cloture_Lead__c> parCle = new Map<String, Cloture_Lead__c>();
    for (Source_Lead__c source : selector.sourcesAvecRegie()) {
      String cleCloture = cle(source.Fournisseur__c, source.Regie__c, periode);
      if (!parCle.containsKey(cleCloture)) {
        parCle.put(
          cleCloture,
          new Cloture_Lead__c(
            Cle__c = cleCloture,
            Fournisseur__c = source.Fournisseur__c,
            Regie__c = source.Regie__c,
            Periode__c = periode,
            Statut__c = STATUT_OUVERTE
          )
        );
      }
    }
    Set<String> figees = new Set<String>();
    Set<String> existantes = new Set<String>();
    for (Cloture_Lead__c deja : selector.cloturesParCle(parCle.keySet())) {
      existantes.add(deja.Cle__c);
      if (deja.Statut__c != STATUT_OUVERTE) {
        figees.add(deja.Cle__c);
      }
    }
    List<Cloture_Lead__c> aCalculer = new List<Cloture_Lead__c>();
    for (String cleCloture : parCle.keySet()) {
      if (!figees.contains(cleCloture)) {
        aCalculer.add(parCle.get(cleCloture));
      }
    }
    totaliser(aCalculer);
    List<Cloture_Lead__c> aEnregistrer = new List<Cloture_Lead__c>();
    for (Cloture_Lead__c cloture : aCalculer) {
      Boolean vide =
        (cloture.Nombre_payes__c == null || cloture.Nombre_payes__c == 0) &&
        (cloture.Nombre_factures__c == null ||
        cloture.Nombre_factures__c == 0);
      if (!vide || existantes.contains(cloture.Cle__c)) {
        aEnregistrer.add(cloture);
      }
    }
    if (!aEnregistrer.isEmpty()) {
      Database.upsert(
        aEnregistrer,
        Cloture_Lead__c.Cle__c,
        true,
        AccessLevel.SYSTEM_MODE
      );
    }
    return aEnregistrer;
  }

  // ------------------------------------------------------------ Calculer

  /** Recalcule les totaux de clôtures non figées d'un même mois. */
  public void calculer(Set<Id> ids) {
    List<Cloture_Lead__c> clotures = selector.cloturesParId(ids);
    for (Cloture_Lead__c cloture : clotures) {
      if (cloture.Statut__c == STATUT_CLOTUREE) {
        throw new ClotureException(
          'La clôture ' + cloture.Name + ' est déjà clôturée.'
        );
      }
    }
    totaliser(clotures);
    if (!clotures.isEmpty()) {
      Database.update(clotures, true, AccessLevel.SYSTEM_MODE);
    }
  }

  // ------------------------------------------------------------ Clôturer

  /** Fige une clôture ; répartit d'abord le coût réel si des leads sont au prix provisoire. */
  public String cloturer(Id idCloture) {
    Cloture_Lead__c cloture = une(idCloture);
    if (cloture.Statut__c == STATUT_CLOTUREE) {
      throw new ClotureException(
        'La clôture ' + cloture.Name + ' est déjà clôturée.'
      );
    }
    totaliser(new List<Cloture_Lead__c>{ cloture });
    Integer aRepartir = cloture.Nombre_a_repartir__c == null
      ? 0
      : cloture.Nombre_a_repartir__c.intValue();
    if (aRepartir == 0) {
      Database.update(cloture, true, AccessLevel.SYSTEM_MODE);
      terminer(idCloture);
      return 'Clôture figée.';
    }

    // Reprise d'une clôture interrompue : le coût déjà calculé est gardé tel quel.
    Decimal cout = cloture.Statut__c == STATUT_EN_COURS
      ? cloture.Cout_unitaire__c
      : null;
    if (cout == null) {
      Decimal total = cloture.Montant_facture_fournisseur__c;
      if (
        total == null &&
        cloture.Budget__c != null &&
        cloture.Taux__c != null
      ) {
        total = cloture.Budget__c * (1 + cloture.Taux__c / 100);
      }
      if (total == null) {
        throw new ClotureException(
          aRepartir +
          ' lead(s) sont au prix provisoire : saisissez le montant de la facture du fournisseur, ou le budget et le taux, avant de clôturer.'
        );
      }
      cout = (total / aRepartir).setScale(4, RoundingMode.HALF_UP);
    }
    cloture.Cout_unitaire__c = cout;
    cloture.Statut__c = STATUT_EN_COURS;
    cloture.Alerte__c = null;
    Database.update(cloture, true, AccessLevel.SYSTEM_MODE);

    Periode p = new Periode(cloture.Periode__c);
    Set<Id> sources = sourcesDe(cloture);
    Decimal prix = cout.setScale(2, RoundingMode.HALF_UP);
    List<Rejet_Lead__c> rejets = selector.rejetsARepartir(
      sources,
      p.debut,
      p.fin,
      LeadPrixService.STATUT_PROVISOIRE
    );
    for (Rejet_Lead__c rejet : rejets) {
      rejet.Prix_Achat__c = prix;
      rejet.Statut_Prix__c = LeadPrixService.STATUT_DEFINITIF;
    }
    if (!rejets.isEmpty()) {
      Database.update(rejets, false, AccessLevel.SYSTEM_MODE);
    }

    // Les pistes sont corrigées par petits paquets : chaque paquet traverse les automatismes
    // existants de la piste, comme à la remontée.
    LeadClotureBatch lot = new LeadClotureBatch(
      idCloture,
      sources,
      p.debut,
      p.fin,
      prix
    );
    dernierLot = lot;
    Database.executeBatch(lot, RemonteeLeadReglage.lire().taillePaquet);
    return 'Répartition du coût lancée sur ' +
      aRepartir +
      ' lead(s) : la clôture passera à « Clôturée » à la fin du traitement.';
  }

  /**
   * Dernière étape : totaux définitifs, statut « Clôturée » et montant des leads de la régie.
   * Si des pistes sont restées au prix provisoire (mise à jour refusée par une règle de validation,
   * par exemple), la clôture reste « En cours » avec une alerte et peut être relancée.
   */
  public void terminer(Id idCloture) {
    Cloture_Lead__c cloture = une(idCloture);
    totaliser(new List<Cloture_Lead__c>{ cloture });
    Boolean reste =
      cloture.Nombre_a_repartir__c != null &&
      cloture.Nombre_a_repartir__c > 0;
    if (reste) {
      cloture.Statut__c = STATUT_EN_COURS;
      cloture.Alerte__c =
        cloture.Nombre_a_repartir__c.intValue() +
        ' lead(s) sont restés au prix provisoire : leur mise à jour a été refusée. Corrigez-les puis relancez « Clôturer ».';
    } else {
      cloture.Statut__c = STATUT_CLOTUREE;
      cloture.Date_cloture__c = DateTime.now();
      cloture.Alerte__c = null;
    }
    Database.update(cloture, true, AccessLevel.SYSTEM_MODE);

    Decimal montant = selector.montantsReventeParRegie(
        new Set<Id>{ cloture.Regie__c }
      )
      .get(cloture.Regie__c);
    Database.SaveResult resultat = Database.update(
      new Campaign(
        Id = cloture.Regie__c,
        Montant_leads__c = montant == null ? 0 : montant
      ),
      false,
      AccessLevel.SYSTEM_MODE
    );
    if (!resultat.isSuccess()) {
      // La fiche de la régie n'a pas pu être mise à jour : la clôture n'est pas annulée pour autant.
      cloture.Alerte__c = ((cloture.Alerte__c == null
          ? ''
          : cloture.Alerte__c + ' ') +
        'Montant des leads non reporté sur la régie : ' +
        resultat.getErrors()[0].getMessage())
        .left(2000);
      Database.update(cloture, false, AccessLevel.SYSTEM_MODE);
    }
  }

  // ------------------------------------------------------------ Totaux

  /**
   * Remplit les nombres et montants de clôtures d'un même mois (enregistrées ou non), sans rien
   * écrire. Cinq requêtes quel que soit le nombre de clôtures.
   */
  @TestVisible
  private void totaliser(List<Cloture_Lead__c> clotures) {
    if (clotures.isEmpty()) {
      return;
    }
    Date periode = clotures[0].Periode__c;
    Set<Id> fournisseurs = new Set<Id>();
    Set<Id> regies = new Set<Id>();
    for (Cloture_Lead__c cloture : clotures) {
      if (cloture.Periode__c != periode) {
        throw new ClotureException('Calculez un seul mois à la fois.');
      }
      fournisseurs.add(cloture.Fournisseur__c);
      regies.add(cloture.Regie__c);
    }
    Map<String, Set<Id>> sourcesParCouple = new Map<String, Set<Id>>();
    Map<String, Id> compteParCouple = new Map<String, Id>();
    Set<Id> toutes = new Set<Id>();
    for (
      Source_Lead__c source : selector.sourcesDesCouples(fournisseurs, regies)
    ) {
      String couple = source.Fournisseur__c + '|' + source.Regie__c;
      if (!sourcesParCouple.containsKey(couple)) {
        sourcesParCouple.put(couple, new Set<Id>());
      }
      sourcesParCouple.get(couple).add(source.Id);
      toutes.add(source.Id);
      if (
        source.Compte_Regie__c != null && !compteParCouple.containsKey(couple)
      ) {
        compteParCouple.put(couple, source.Compte_Regie__c);
      }
    }

    Periode p = new Periode(periode);
    Map<Id, Decimal> nombrePayes = new Map<Id, Decimal>();
    Map<Id, Decimal> montantAchat = new Map<Id, Decimal>();
    Map<Id, Decimal> nombreARepartir = new Map<Id, Decimal>();
    Map<Id, Decimal> nombreFactures = new Map<Id, Decimal>();
    Map<Id, Decimal> montantRevente = new Map<Id, Decimal>();
    if (!toutes.isEmpty()) {
      for (AggregateResult a : selector.pistesPayees(toutes, p.debut, p.fin)) {
        ajouter(nombrePayes, a, 'nombre');
        ajouter(montantAchat, a, 'montant');
      }
      for (
        AggregateResult a : selector.pistesARepartir(
          toutes,
          p.debut,
          p.fin,
          LeadPrixService.STATUT_PROVISOIRE
        )
      ) {
        ajouter(nombreARepartir, a, 'nombre');
      }
      for (
        AggregateResult a : selector.pistesFacturees(toutes, p.debut, p.fin)
      ) {
        ajouter(nombreFactures, a, 'nombre');
        ajouter(montantRevente, a, 'montant');
      }
      for (AggregateResult a : selector.rejetsPayes(toutes, p.debut, p.fin)) {
        ajouter(nombrePayes, a, 'nombre');
        ajouter(montantAchat, a, 'montant');
      }
      for (
        Rejet_Lead__c rejet : selector.rejetsARepartir(
          toutes,
          p.debut,
          p.fin,
          LeadPrixService.STATUT_PROVISOIRE
        )
      ) {
        cumuler(nombreARepartir, rejet.Source__c, 1);
      }
    }

    for (Cloture_Lead__c cloture : clotures) {
      String couple = cloture.Fournisseur__c + '|' + cloture.Regie__c;
      Set<Id> sources = sourcesParCouple.containsKey(couple)
        ? sourcesParCouple.get(couple)
        : new Set<Id>();
      cloture.Nombre_payes__c = somme(nombrePayes, sources);
      cloture.Montant_achat__c = somme(montantAchat, sources);
      cloture.Nombre_a_repartir__c = somme(nombreARepartir, sources);
      cloture.Nombre_factures__c = somme(nombreFactures, sources);
      cloture.Montant_revente__c = somme(montantRevente, sources);
      if (compteParCouple.containsKey(couple)) {
        cloture.Compte_Regie__c = compteParCouple.get(couple);
      }
    }
  }

  // ------------------------------------------------------------ Outils

  /** Bornes d'un mois, dans le fuseau horaire de l'utilisateur qui lance le calcul. */
  public class Periode {
    public DateTime debut;
    public DateTime fin;
    public Periode(Date premierJour) {
      Date premier = premierJour.toStartOfMonth();
      debut = DateTime.newInstance(premier, Time.newInstance(0, 0, 0, 0));
      fin = DateTime.newInstance(
        premier.addMonths(1),
        Time.newInstance(0, 0, 0, 0)
      );
    }
  }

  private Cloture_Lead__c une(Id idCloture) {
    List<Cloture_Lead__c> trouvees = selector.cloturesParId(
      new Set<Id>{ idCloture }
    );
    if (trouvees.isEmpty()) {
      throw new ClotureException('Clôture introuvable.');
    }
    return trouvees[0];
  }

  private Set<Id> sourcesDe(Cloture_Lead__c cloture) {
    Set<Id> ids = new Set<Id>();
    for (
      Source_Lead__c source : selector.sourcesDesCouples(
        new Set<Id>{ cloture.Fournisseur__c },
        new Set<Id>{ cloture.Regie__c }
      )
    ) {
      ids.add(source.Id);
    }
    return ids;
  }

  @TestVisible
  private static String cle(Id fournisseur, Id regie, Date periode) {
    return fournisseur +
      '|' +
      regie +
      '|' +
      DateTime.newInstance(periode, Time.newInstance(12, 0, 0, 0))
        .format('yyyy-MM');
  }

  private static void ajouter(
    Map<Id, Decimal> totaux,
    AggregateResult ligne,
    String colonne
  ) {
    Object valeur = ligne.get(colonne);
    cumuler(
      totaux,
      (Id) ligne.get('feuille'),
      // COUNT rend un entier, SUM un décimal : on passe par le texte pour les deux.
      valeur == null ? 0 : Decimal.valueOf(String.valueOf(valeur))
    );
  }

  private static void cumuler(
    Map<Id, Decimal> totaux,
    Id idSource,
    Decimal valeur
  ) {
    Decimal actuel = totaux.get(idSource);
    totaux.put(idSource, (actuel == null ? 0 : actuel) + valeur);
  }

  private static Decimal somme(Map<Id, Decimal> totaux, Set<Id> sources) {
    Decimal total = 0;
    for (Id idSource : sources) {
      Decimal valeur = totaux.get(idSource);
      if (valeur != null) {
        total += valeur;
      }
    }
    return total;
  }
}
