/**
 * Réglages généraux de la remontée des leads depuis les feuilles Google
 * (Custom Metadata Remontee_Lead_Reglage__mdt, enregistrement « Defaut »).
 *
 * Lu en mémoire : aucune requête SOQL consommée. Les valeurs absentes ou hors bornes
 * sont ramenées à des valeurs sûres, pour qu'un réglage mal saisi ne casse pas la chaîne.
 */
public with sharing class RemonteeLeadReglage {
  @TestVisible
  private static final String NOM_ENREGISTREMENT = 'Defaut';
  public static final Integer TAILLE_PAQUET_DEFAUT = 20;
  public static final Integer TAILLE_PAQUET_MAX = 200;
  public static final Integer INTERVALLE_DEFAUT = 3;
  public static final Integer INTERVALLE_MAX = 10;
  public static final Integer TENTATIVES_DEFAUT = 5;

  /** Réglage injecté par les tests (les Custom Metadata ne se créent pas en test). */
  @TestVisible
  private static RemonteeLeadReglage forcage;

  /** Interrupteur général : faux = aucune feuille n'est lue et la chaîne s'arrête. */
  public Boolean actif = false;
  /** Nombre maximum de lignes traitées (donc de pistes créées) par opération. */
  public Integer taillePaquet = TAILLE_PAQUET_DEFAUT;
  /** Pause en minutes entre deux passages complets sur les feuilles. */
  public Integer intervalleMinutes = INTERVALLE_DEFAUT;
  /** Nom unique du certificat Salesforce qui signe la demande de jeton Google. */
  public String nomCertificat;
  /** Adresse du compte de service Google (le « robot »). */
  public String emailCompteService;
  /** Cherche aussi les doublons sur le téléphone tel qu'il est enregistré (anciennes pistes). */
  public Boolean rechercheTelephoneExacte = true;
  /** Nombre d'échecs après lequel une ligne passe en erreur définitive. */
  public Integer tentativesMax = TENTATIVES_DEFAUT;

  public static RemonteeLeadReglage lire() {
    if (forcage != null) {
      return forcage;
    }
    return depuis(Remontee_Lead_Reglage__mdt.getInstance(NOM_ENREGISTREMENT));
  }

  @TestVisible
  private static RemonteeLeadReglage depuis(Remontee_Lead_Reglage__mdt source) {
    RemonteeLeadReglage reglage = new RemonteeLeadReglage();
    if (source == null) {
      return reglage;
    }
    reglage.actif = source.Actif__c == true;
    reglage.taillePaquet = borner(
      source.Taille_paquet__c,
      TAILLE_PAQUET_DEFAUT,
      TAILLE_PAQUET_MAX
    );
    reglage.intervalleMinutes = borner(
      source.Intervalle_minutes__c,
      INTERVALLE_DEFAUT,
      INTERVALLE_MAX
    );
    reglage.tentativesMax = borner(
      source.Tentatives_max__c,
      TENTATIVES_DEFAUT,
      99
    );
    reglage.nomCertificat = source.Nom_certificat__c;
    reglage.emailCompteService = source.Email_compte_service__c;
    reglage.rechercheTelephoneExacte =
      source.Recherche_telephone_exacte__c == true;
    return reglage;
  }

  /** Valeur entière entre 1 et le maximum ; la valeur par défaut si elle est vide ou négative. */
  @TestVisible
  private static Integer borner(
    Decimal valeur,
    Integer defaut,
    Integer maximum
  ) {
    if (valeur == null || valeur < 1) {
      return defaut;
    }
    return Math.min(valeur.intValue(), maximum);
  }
}
