/**
 * Requêtes de la surveillance des remontées Aircall.
 * « without sharing » voulu : on cherche la dernière fiche arrivée, quel que soit son propriétaire.
 */
public without sharing class AircallSurveillanceSelector {
  /** Date de la dernière fiche Aircall arrivée dans Salesforce (null s'il n'y en a aucune). */
  public Datetime derniereArrivee() {
    List<Aircall__c> fiches = [
      SELECT CreatedDate
      FROM Aircall__c
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];
    return fiches.isEmpty() ? null : fiches[0].CreatedDate;
  }
}
