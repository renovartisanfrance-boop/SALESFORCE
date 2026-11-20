/**
 * Rattache en arrière-plan des fiches Aircall à leur client, juste après leur création.
 */
public with sharing class AircallRattachementQueueable implements Queueable {
  private final Set<Id> ficheIds;

  public AircallRattachementQueueable(Set<Id> ficheIds) {
    this.ficheIds = ficheIds;
  }

  public void execute(QueueableContext contexte) {
    new AircallRattachementService().rattacher(ficheIds);
  }
}
