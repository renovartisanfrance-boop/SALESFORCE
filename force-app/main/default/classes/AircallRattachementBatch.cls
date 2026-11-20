/**
 * Rattrapage : rattache à leur client les fiches Aircall déjà créées depuis une date donnée.
 * Lancement : Database.executeBatch(new AircallRattachementBatch(Date.newInstance(2026, 9, 1)), 100);
 */
public with sharing class AircallRattachementBatch implements Database.Batchable<SObject> {
  private final Datetime depuis;

  public AircallRattachementBatch(Date depuis) {
    this.depuis = Datetime.newInstance(depuis, Time.newInstance(0, 0, 0, 0));
  }

  public Database.QueryLocator start(Database.BatchableContext contexte) {
    return new AircallRattachementSelector().fichesIncompletesDepuis(depuis);
  }

  public void execute(
    Database.BatchableContext contexte,
    List<Aircall__c> fiches
  ) {
    new AircallRattachementService()
      .rattacher(new Map<Id, Aircall__c>(fiches).keySet());
  }

  public void finish(Database.BatchableContext contexte) {
    return;
  }
}
