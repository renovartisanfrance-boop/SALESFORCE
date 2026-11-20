/**
 * Lecture du contenu d'une feuille de leads : où est la colonne de résultat, quelles lignes
 * restent à traiter, et à partir de quelle ligne relire la prochaine fois.
 *
 * Le résultat écrit par Salesforce dans la colonne (« Remonté » par défaut) fait foi :
 *  - vide ou « ERREUR – … »      → ligne à traiter (ou à retenter) ;
 *  - « OK », « DOUBLON », « FAUX NUMÉRO », « ERREUR DÉFINITIVE » → ligne terminée.
 *
 * Aucune requête, aucun DML, aucun appel sortant : classe de calcul pur.
 */
public with sharing class RemonteeLeadFeuille {
  public static final String STATUT_OK = 'OK';
  public static final String STATUT_DOUBLON = 'DOUBLON';
  public static final String STATUT_FAUX_NUMERO = 'FAUX NUMÉRO';
  public static final String STATUT_ERREUR = 'ERREUR';
  public static final String STATUT_ERREUR_DEFINITIVE = 'ERREUR DÉFINITIVE';
  public static final String SEPARATEUR = ' – ';
  private static final Pattern MOTIF_TENTATIVE = Pattern.compile(
    'tentative (\\d+)'
  );

  /** Une ligne de la feuille à traiter. */
  public class Ligne {
    /** Numéro de la ligne dans la feuille (1 = première ligne). */
    public Integer numero;
    /** Valeurs par titre de colonne normalisé (voir normaliser). */
    public Map<String, String> valeurs = new Map<String, String>();
    /** Nombre d'essais déjà faits (0 pour une ligne jamais traitée). */
    public Integer tentatives = 0;
  }

  /** Résultat de l'analyse d'une lecture. */
  public class Lecture {
    /** Rang (0 = colonne A) de la colonne de résultat. */
    public Integer rangColonneStatut;
    /** Vrai si le titre de la colonne de résultat n'existe pas encore dans la feuille. */
    public Boolean colonneStatutACreer = false;
    /** Lignes à traiter maintenant, dans l'ordre de la feuille, limitées à la capacité. */
    public List<Ligne> aTraiter = new List<Ligne>();
    /** Vrai si d'autres lignes attendent au-delà de la capacité. */
    public Boolean resteDesLignes = false;
    /** Première ligne non terminée : point de départ de la prochaine lecture. */
    public Integer premiereLigneNonTerminee;
  }

  /** Titre de colonne comparable : sans espaces autour, en minuscules. */
  public static String normaliser(String titre) {
    return titre == null ? '' : titre.trim().toLowerCase();
  }

  /**
   * @param titres             cellules de la ligne des titres
   * @param lignes             lignes lues à partir de numeroPremiereLigne
   * @param numeroPremiereLigne numéro de feuille de lignes[0]
   * @param ligneTitres        numéro de la ligne des titres (les lignes au-dessus sont ignorées)
   * @param titreColonneStatut titre de la colonne de résultat
   * @param capacite           nombre maximum de lignes à retenir
   */
  public static Lecture analyser(
    List<String> titres,
    List<List<String>> lignes,
    Integer numeroPremiereLigne,
    Integer ligneTitres,
    String titreColonneStatut,
    Integer capacite
  ) {
    Lecture lecture = new Lecture();
    List<String> titresNormalises = new List<String>();
    for (String titre : titres) {
      titresNormalises.add(normaliser(titre));
    }
    lecture.rangColonneStatut = titresNormalises.indexOf(
      normaliser(titreColonneStatut)
    );
    if (lecture.rangColonneStatut < 0) {
      // Colonne absente : elle sera créée juste après le dernier titre.
      lecture.rangColonneStatut = titresNormalises.size();
      lecture.colonneStatutACreer = true;
    }

    for (Integer i = 0; i < lignes.size(); i++) {
      Integer numero = numeroPremiereLigne + i;
      if (numero <= ligneTitres) {
        continue;
      }
      List<String> cellules = lignes[i];
      String statut = lecture.rangColonneStatut < cellules.size()
        ? cellules[lecture.rangColonneStatut].trim()
        : '';
      if (estTerminee(statut)) {
        continue;
      }
      Ligne ligne = new Ligne();
      ligne.numero = numero;
      ligne.tentatives = tentatives(statut);
      Boolean vide = true;
      for (
        Integer c = 0; c < cellules.size() && c < titresNormalises.size(); c++
      ) {
        if (c == lecture.rangColonneStatut) {
          continue;
        }
        String valeur = cellules[c] == null ? '' : cellules[c].trim();
        if (String.isNotBlank(valeur)) {
          vide = false;
        }
        if (String.isNotBlank(titresNormalises[c])) {
          ligne.valeurs.put(titresNormalises[c], valeur);
        }
      }
      // Une ligne sans aucune donnée n'est ni un lead ni un travail en attente.
      if (vide) {
        continue;
      }
      if (lecture.premiereLigneNonTerminee == null) {
        lecture.premiereLigneNonTerminee = numero;
      }
      if (lecture.aTraiter.size() < capacite) {
        lecture.aTraiter.add(ligne);
      } else {
        lecture.resteDesLignes = true;
      }
    }

    if (lecture.premiereLigneNonTerminee == null) {
      // Tout est terminé : la prochaine lecture repartira après la dernière ligne lue.
      lecture.premiereLigneNonTerminee = Math.max(
        ligneTitres + 1,
        numeroPremiereLigne + lignes.size()
      );
    }
    return lecture;
  }

  /** Une ligne est terminée si elle a un résultat autre qu'une erreur à retenter. */
  public static Boolean estTerminee(String statut) {
    if (String.isBlank(statut)) {
      return false;
    }
    String s = statut.trim().toUpperCase();
    return s.startsWith(STATUT_ERREUR_DEFINITIVE) ||
      !s.startsWith(STATUT_ERREUR);
  }

  /** Nombre d'essais inscrit dans un résultat « ERREUR – tentative N – … » (0 si aucun). */
  public static Integer tentatives(String statut) {
    if (String.isBlank(statut)) {
      return 0;
    }
    Matcher m = MOTIF_TENTATIVE.matcher(statut);
    return m.find() ? Integer.valueOf(m.group(1)) : 1;
  }
}
