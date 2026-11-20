/**
 * Lance chaque heure la vérification des remontées Aircall.
 * Programmation : System.schedule('Aircall - surveillance des remontées', '0 0 * ? * MON-FRI', new AircallSurveillanceSchedulable());
 */
public with sharing class AircallSurveillanceSchedulable implements Schedulable {
  public void execute(SchedulableContext contexte) {
    new AircallSurveillanceService().verifier(Datetime.now());
  }
}
