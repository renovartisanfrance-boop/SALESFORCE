/**
 * Gardien de la remontée des leads : une fois par heure, vérifie que la chaîne
 * RemonteeLeadQueueable tourne et la relance si elle s'est arrêtée.
 *
 * La chaîne se relance elle-même après chaque passage ; elle ne peut s'interrompre que sur un
 * incident (limite Salesforce dépassée, maintenance, opération annulée). Sans gardien, plus aucun
 * lead ne remonterait jusqu'à ce que quelqu'un s'en aperçoive.
 *
 * Mise en route, une seule fois, depuis « Exécuter du code anonyme » :
 *   RemonteeLeadGardien.planifier();
 * Le gardien ne relance rien tant que l'interrupteur général du réglage est sur « inactif ».
 */
public with sharing class RemonteeLeadGardien implements Schedulable {
  public static final String NOM_TACHE = 'Remontée des leads - gardien';
  /** Toutes les heures, à la minute 7 (en dehors des heures rondes, les plus chargées). */
  @TestVisible
  private static final String FREQUENCE = '0 7 * * * ?';

  public void execute(SchedulableContext contexte) {
    RemonteeLeadQueueable.demarrerSiArretee();
  }

  /**
   * Planifie le gardien s'il ne l'est pas déjà, et lance la chaîne tout de suite.
   * @return l'identifiant de la tâche planifiée, ou null si elle existait déjà.
   */
  public static Id planifier() {
    Id idTache;
    if (!new RemonteeLeadSelector().tachePlanifieeExiste(NOM_TACHE)) {
      idTache = System.schedule(
        NOM_TACHE,
        FREQUENCE,
        new RemonteeLeadGardien()
      );
    }
    RemonteeLeadQueueable.demarrerSiArretee();
    return idTache;
  }
}
