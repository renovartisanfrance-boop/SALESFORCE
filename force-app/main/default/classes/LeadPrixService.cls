/**
 * Prix d'un lead : prix d'achat au fournisseur et prix de revente à la régie, d'après le tarif du
 * couple fournisseur + régie valable le jour de l'arrivée du lead (Tarif_Lead__c).
 *
 * Brique indépendante de la remontée des feuilles : toute création de lead peut l'utiliser
 * (voir tarifer), par exemple une régie qui saisira ses leads à la main.
 *
 * Deux modes d'achat :
 *  - « Prix fixe »               : le prix est connu et définitif dès l'arrivée ;
 *  - « Pourcentage de campagne » : le fournisseur refacture son budget plus sa commission ; le lead
 *    porte un prix provisoire, remplacé à la clôture du mois (LeadClotureService).
 * La revente est fixe, égale à l'achat, ou l'achat plus une marge (en % ou en €).
 *
 * Aucun rapport avec le Catalogue tarifaire ni la Grille tarifaire, qui ne sont pas lus ici.
 */
public with sharing class LeadPrixService {
  public static final String MODE_FIXE = 'Prix fixe';
  public static final String MODE_POURCENTAGE = 'Pourcentage de campagne';
  public static final String REVENTE_FIXE = 'Prix fixe';
  public static final String REVENTE_ACHAT = 'Meme prix que achat';
  public static final String REVENTE_MARGE_POURCENT = 'Achat plus marge pourcent';
  public static final String REVENTE_MARGE_EUROS = 'Achat plus marge euros';
  public static final String STATUT_DEFINITIF = 'Définitif';
  public static final String STATUT_PROVISOIRE = 'Provisoire';
  public static final String STATUT_SANS_TARIF = 'Sans tarif';
  private static final Date SANS_FIN = Date.newInstance(4000, 12, 31);
  private static final String FORMAT_DATE = 'dd/MM/yyyy';

  /** Prix d'un lead d'après un tarif (ou « Sans tarif » s'il n'y en a pas). */
  public class Prix {
    public Id tarifId;
    public String modeAchat;
    public Decimal achat;
    public Decimal revente;
    public String statut = STATUT_SANS_TARIF;
    /** Un faux numéro est-il quand même payé à ce fournisseur ? */
    public Boolean fauxNumerosPayes = false;
  }

  @TestVisible
  private LeadPrixSelector selector = new LeadPrixSelector();
  /** Tarif retenu par couple « fournisseur|régie » (le plus récent en cas de recouvrement). */
  private Map<String, Tarif_Lead__c> tarifsParCouple = new Map<String, Tarif_Lead__c>();

  // ------------------------------------------------------------ Chargement des tarifs

  /** Charge en une requête les tarifs de ces fournisseurs et régies valables ce jour-là. */
  public void charger(Set<Id> fournisseurs, Set<Id> regies, Date jour) {
    Set<Id> f = sansVide(fournisseurs);
    Set<Id> r = sansVide(regies);
    for (Tarif_Lead__c tarif : selector.tarifsApplicables(f, r, jour)) {
      String cle = couple(tarif.Fournisseur__c, tarif.Regie__c);
      // La requête est triée du début le plus récent au plus ancien : le premier trouvé gagne.
      if (!tarifsParCouple.containsKey(cle)) {
        tarifsParCouple.put(cle, tarif);
      }
    }
  }

  /** Tarif chargé pour ce couple, ou null. */
  public Tarif_Lead__c tarifDuCouple(Id fournisseur, Id regie) {
    return tarifsParCouple.get(couple(fournisseur, regie));
  }

  /** Prix d'un lead de ce fournisseur pour cette régie (appeler charger avant). */
  public Prix prixDuCouple(Id fournisseur, Id regie) {
    return prixDuTarif(tarifDuCouple(fournisseur, regie));
  }

  // ------------------------------------------------------------ Calcul

  public static Prix prixDuTarif(Tarif_Lead__c tarif) {
    Prix p = new Prix();
    if (tarif == null) {
      return p;
    }
    p.tarifId = tarif.Id;
    p.modeAchat = tarif.Mode_achat__c;
    p.fauxNumerosPayes = tarif.Faux_numeros_payes__c == true;
    if (tarif.Mode_achat__c == MODE_POURCENTAGE) {
      p.achat = tarif.Prix_Achat_Provisoire__c;
      p.statut = STATUT_PROVISOIRE;
    } else {
      p.achat = tarif.Prix_Achat__c;
      p.statut = STATUT_DEFINITIF;
    }
    p.revente = revente(tarif, p.achat);
    return p;
  }

  /** Prix de revente à la régie pour un prix d'achat donné, selon la règle du tarif. */
  public static Decimal revente(Tarif_Lead__c tarif, Decimal achat) {
    if (tarif == null) {
      return null;
    }
    String regle = tarif.Regle_revente__c;
    if (regle == REVENTE_FIXE) {
      return tarif.Prix_Revente__c;
    }
    if (achat == null) {
      return null;
    }
    Decimal marge = tarif.Marge__c == null ? 0 : tarif.Marge__c;
    if (regle == REVENTE_ACHAT) {
      return achat;
    }
    if (regle == REVENTE_MARGE_POURCENT) {
      return (achat * (1 + marge / 100)).setScale(2, RoundingMode.HALF_UP);
    }
    if (regle == REVENTE_MARGE_EUROS) {
      return achat + marge;
    }
    return null;
  }

  /** Vrai si le prix de revente change quand le prix d'achat change. */
  public static Boolean reventeDependDeLAchat(String regle) {
    return regle == REVENTE_ACHAT ||
      regle == REVENTE_MARGE_POURCENT ||
      regle == REVENTE_MARGE_EUROS;
  }

  /**
   * Pose les prix sur une piste pas encore enregistrée.
   * @param payeFournisseur ce lead est-il dû au fournisseur ?
   * @param factureRegie    ce lead est-il facturé à la régie ?
   */
  public static void poser(
    Lead piste,
    Prix prix,
    Boolean payeFournisseur,
    Boolean factureRegie
  ) {
    piste.Tarif_Lead__c = prix.tarifId;
    // Un lead qui n'est pas dû au fournisseur n'attend aucune clôture : son prix est définitif.
    piste.Statut_Prix__c = !payeFournisseur && prix.statut == STATUT_PROVISOIRE
      ? STATUT_DEFINITIF
      : prix.statut;
    piste.Paye_fournisseur__c = payeFournisseur;
    piste.Facture_regie__c = factureRegie;
    piste.Prix_Achat__c = payeFournisseur ? prix.achat : null;
    piste.Prix_Revente__c = factureRegie ? prix.revente : null;
  }

  /**
   * Tarife des pistes pas encore enregistrées à partir de leur Source (Source_Lead__c) et de leur
   * régie (« Campagne (REGIE) », sinon celle de la Source). Pour toute création de lead hors
   * remontée automatique. Un faux numéro n'est jamais facturé à la régie ; il est payé au
   * fournisseur seulement si le tarif le prévoit.
   */
  public void tarifer(List<Lead> pistes, Date jour) {
    Set<Id> idsSources = new Set<Id>();
    for (Lead piste : pistes) {
      if (piste.Source_Lead__c != null) {
        idsSources.add(piste.Source_Lead__c);
      }
    }
    Map<Id, Source_Lead__c> sources = selector.sourcesParId(idsSources);
    Set<Id> fournisseurs = new Set<Id>();
    Set<Id> regies = new Set<Id>();
    for (Lead piste : pistes) {
      Source_Lead__c source = sources.get(piste.Source_Lead__c);
      if (source != null) {
        fournisseurs.add(source.Fournisseur__c);
        regies.add(regieDe(piste, source));
      }
    }
    charger(fournisseurs, regies, jour);
    for (Lead piste : pistes) {
      Source_Lead__c source = sources.get(piste.Source_Lead__c);
      Prix p = source == null
        ? new Prix()
        : prixDuCouple(source.Fournisseur__c, regieDe(piste, source));
      Boolean fauxNumero = piste.Faux_Numero__c == true;
      poser(piste, p, fauxNumero ? p.fauxNumerosPayes : true, !fauxNumero);
    }
  }

  // ------------------------------------------------------------ Contrôle des tarifs

  /**
   * Refuse un tarif actif dont la période recouvre celle d'un autre tarif actif du même couple
   * fournisseur + régie : un lead ne doit jamais avoir deux prix possibles.
   * Appelé avant l'enregistrement des tarifs (TarifLeadTriggerHandler) : une seule requête.
   */
  public void refuserLesChevauchements(List<Tarif_Lead__c> aControler) {
    List<Tarif_Lead__c> actifs = new List<Tarif_Lead__c>();
    Set<Id> fournisseurs = new Set<Id>();
    Set<Id> regies = new Set<Id>();
    Set<Id> enCours = new Set<Id>();
    for (Tarif_Lead__c tarif : aControler) {
      if (tarif.Id != null) {
        enCours.add(tarif.Id);
      }
      if (
        tarif.Actif__c == true &&
        tarif.Fournisseur__c != null &&
        tarif.Regie__c != null &&
        tarif.Date_debut__c != null
      ) {
        actifs.add(tarif);
        fournisseurs.add(tarif.Fournisseur__c);
        regies.add(tarif.Regie__c);
      }
    }
    if (actifs.isEmpty()) {
      return;
    }
    Map<String, List<Tarif_Lead__c>> parCouple = new Map<String, List<Tarif_Lead__c>>();
    for (
      Tarif_Lead__c existant : selector.tarifsActifs(
        fournisseurs,
        regies,
        enCours
      )
    ) {
      ranger(parCouple, existant);
    }
    for (Tarif_Lead__c tarif : actifs) {
      String cle = couple(tarif.Fournisseur__c, tarif.Regie__c);
      Tarif_Lead__c enConflit;
      if (parCouple.containsKey(cle)) {
        for (Tarif_Lead__c autre : parCouple.get(cle)) {
          if (seChevauchent(tarif, autre)) {
            enConflit = autre;
            break;
          }
        }
      }
      if (enConflit != null) {
        tarif.addError(
          'Ce tarif recouvre un autre tarif actif du même fournisseur et de la même régie' +
            (String.isBlank(enConflit.Name)
              ? ''
              : ' (' + enConflit.Name + ')') +
            ' : du ' +
            texte(enConflit.Date_debut__c) +
            (enConflit.Date_fin__c == null
              ? ', sans date de fin'
              : ' au ' + texte(enConflit.Date_fin__c)) +
            '. Fermez d’abord l’ancien tarif (date de fin) ou désactivez-le.'
        );
      } else {
        // Les tarifs acceptés de ce lot comptent pour les suivants du même lot.
        ranger(parCouple, tarif);
      }
    }
  }

  @TestVisible
  private static Boolean seChevauchent(Tarif_Lead__c a, Tarif_Lead__c b) {
    Date finA = a.Date_fin__c == null ? SANS_FIN : a.Date_fin__c;
    Date finB = b.Date_fin__c == null ? SANS_FIN : b.Date_fin__c;
    return a.Date_debut__c <= finB && b.Date_debut__c <= finA;
  }

  // ------------------------------------------------------------ Outils

  private static void ranger(
    Map<String, List<Tarif_Lead__c>> parCouple,
    Tarif_Lead__c tarif
  ) {
    String cle = couple(tarif.Fournisseur__c, tarif.Regie__c);
    if (!parCouple.containsKey(cle)) {
      parCouple.put(cle, new List<Tarif_Lead__c>());
    }
    parCouple.get(cle).add(tarif);
  }

  private static Id regieDe(Lead piste, Source_Lead__c source) {
    return piste.Campagne_REGIE__c != null
      ? piste.Campagne_REGIE__c
      : source.Regie__c;
  }

  private static String couple(Id fournisseur, Id regie) {
    return String.valueOf(fournisseur) + '|' + String.valueOf(regie);
  }

  private static Set<Id> sansVide(Set<Id> ids) {
    Set<Id> resultat = new Set<Id>();
    if (ids != null) {
      resultat.addAll(ids);
      resultat.remove(null);
    }
    return resultat;
  }

  private static String texte(Date jour) {
    return DateTime.newInstance(jour, Time.newInstance(12, 0, 0, 0))
      .format(FORMAT_DATE);
  }
}
