/**
 * Alerte « Aircall ne remonte plus d'appels » : si aucune fiche Aircall n'est arrivée depuis le délai
 * réglé, pendant les heures d'ouverture (lundi à vendredi, heure de Paris), un e-mail est envoyé.
 * Réglages et mémoire des envois : paramètre personnalisé « Aircall - Surveillance ».
 */
public with sharing class AircallSurveillanceService {
  private static final String FUSEAU = 'Europe/Paris';
  private final AircallSurveillanceSelector selector;

  public AircallSurveillanceService() {
    this.selector = new AircallSurveillanceSelector();
  }

  /** Renvoie vrai si une alerte a été envoyée. */
  public Boolean verifier(Datetime maintenant) {
    Aircall_Surveillance__c reglages = Aircall_Surveillance__c.getOrgDefaults();
    if (
      reglages == null ||
      reglages.Actif__c != true ||
      String.isBlank(reglages.Destinataires__c)
    ) {
      return false;
    }
    Integer delai = entier(reglages.Delai_Heures__c, 3);
    if (!heuresOuvrees(maintenant, reglages, delai)) {
      return false;
    }
    Datetime derniere = selector.derniereArrivee();
    if (derniere != null && derniere > maintenant.addHours(-delai)) {
      return false;
    }
    if (!alerteAutorisee(maintenant, reglages, delai)) {
      return false;
    }
    envoyer(reglages.Destinataires__c, derniere);
    reglages.Alertes_Du_Jour__c = alertesDuJour(maintenant, reglages) + 1;
    reglages.Derniere_Alerte__c = maintenant;
    // Mode système voulu : mémoire interne de l'automatisme.
    upsert reglages;
    return true;
  }

  /** Lundi à vendredi, et assez tard dans la journée pour que le silence soit significatif. */
  private static Boolean heuresOuvrees(
    Datetime maintenant,
    Aircall_Surveillance__c reglages,
    Integer delai
  ) {
    Date jour = Date.valueOf(maintenant.format('yyyy-MM-dd', FUSEAU));
    // Le 1er janvier 1900 était un lundi : 0 = lundi … 6 = dimanche.
    Integer jourSemaine = Math.mod(
      Date.newInstance(1900, 1, 1).daysBetween(jour),
      7
    );
    Integer heure = Integer.valueOf(maintenant.format('H', FUSEAU));
    return jourSemaine < 5 &&
      heure >= entier(reglages.Heure_Debut__c, 9) + delai &&
      heure <= entier(reglages.Heure_Fin__c, 19);
  }

  private static Boolean alerteAutorisee(
    Datetime maintenant,
    Aircall_Surveillance__c reglages,
    Integer delai
  ) {
    if (
      alertesDuJour(maintenant, reglages) >=
      entier(reglages.Alertes_Max_Par_Jour__c, 2)
    ) {
      return false;
    }
    return reglages.Derniere_Alerte__c == null ||
      reglages.Derniere_Alerte__c <= maintenant.addHours(-delai);
  }

  private static Integer alertesDuJour(
    Datetime maintenant,
    Aircall_Surveillance__c reglages
  ) {
    Boolean memeJour =
      reglages.Derniere_Alerte__c != null &&
      reglages.Derniere_Alerte__c.format('yyyy-MM-dd', FUSEAU) ==
      maintenant.format('yyyy-MM-dd', FUSEAU);
    return memeJour ? entier(reglages.Alertes_Du_Jour__c, 0) : 0;
  }

  private static Integer entier(Decimal valeur, Integer parDefaut) {
    return valeur == null ? parDefaut : valeur.intValue();
  }

  private static void envoyer(String destinataires, Datetime derniere) {
    List<String> adresses = new List<String>();
    for (String adresse : destinataires.split('[,;]')) {
      if (String.isNotBlank(adresse)) {
        adresses.add(adresse.trim());
      }
    }
    String depuis = derniere == null
      ? 'toujours'
      : 'le ' + derniere.format('dd/MM/yyyy à HH\'h\'mm', FUSEAU);
    Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
    message.setToAddresses(adresses);
    message.setSubject(
      'ALERTE - Aircall ne remonte plus d\'appels dans Salesforce'
    );
    message.setPlainTextBody(
      'Aucun appel Aircall n\'est arrivé dans Salesforce depuis ' +
        depuis +
        ' (heure de Paris).\n\n' +
        'À vérifier : Aircall > Intégrations > Salesforce (connexion active ?), ' +
        'puis l\'onglet Standard Aircall dans Salesforce.\n\n' +
        'Cette alerte est envoyée automatiquement. Réglages : Configuration > ' +
        'Paramètres personnalisés > Aircall - Surveillance.'
    );
    Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ message });
  }
}
