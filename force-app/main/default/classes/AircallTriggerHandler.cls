/**
 * Aiguillage du trigger des fiches Aircall : repère les fiches à rattacher à leur client
 * (piste, opportunité, dossier) et lance le rattachement en arrière-plan.
 */
public with sharing class AircallTriggerHandler {
  /** Mis à vrai par le service pendant sa propre mise à jour, pour ne pas boucler. */
  public static Boolean enPause = false;

  public void run(
    System.TriggerOperation operation,
    List<Aircall__c> nouveaux,
    Map<Id, Aircall__c> anciens
  ) {
    if (enPause) {
      return;
    }
    Set<Id> aRattacher = new Set<Id>();
    switch on operation {
      when AFTER_INSERT {
        for (Aircall__c fiche : nouveaux) {
          if (aUnNumero(fiche) && aUnLienVide(fiche)) {
            aRattacher.add(fiche.Id);
          }
        }
      }
      when AFTER_UPDATE {
        for (Aircall__c fiche : nouveaux) {
          if (
            aUnNumero(fiche) &&
            lienPerduOuNumeroChange(fiche, anciens.get(fiche.Id))
          ) {
            aRattacher.add(fiche.Id);
          }
        }
      }
      when else {
        return;
      }
    }
    lancer(aRattacher);
  }

  private static Boolean aUnNumero(Aircall__c fiche) {
    return String.isNotBlank(fiche.Telephone_Client__c);
  }

  private static Boolean aUnLienVide(Aircall__c fiche) {
    return fiche.Piste__c == null ||
      fiche.Opportunite__c == null ||
      fiche.Dossier__c == null;
  }

  /** Un autre automatisme a vidé la piste ou l'opportunité, ou le numéro a changé. */
  private static Boolean lienPerduOuNumeroChange(
    Aircall__c fiche,
    Aircall__c ancien
  ) {
    return fiche.Telephone_Client__c != ancien.Telephone_Client__c ||
      (fiche.Piste__c == null &&
      ancien.Piste__c != null) ||
      (fiche.Opportunite__c == null &&
      ancien.Opportunite__c != null);
  }

  private static void lancer(Set<Id> ficheIds) {
    if (
      ficheIds.isEmpty() ||
      System.isBatch() ||
      System.isFuture() ||
      System.isQueueable() ||
      Limits.getQueueableJobs() >= Limits.getLimitQueueableJobs()
    ) {
      return;
    }
    System.enqueueJob(new AircallRattachementQueueable(ficheIds));
  }
}
