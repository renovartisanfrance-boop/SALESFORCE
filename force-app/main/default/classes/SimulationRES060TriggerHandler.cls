/**
 * Aiguillage du trigger de Simulation RES060 : recalcul avant chaque insertion ou modification.
 */
public with sharing class SimulationRES060TriggerHandler {
  private final SimulationRES060Service service;

  public SimulationRES060TriggerHandler() {
    this(new SimulationRES060Service());
  }

  @TestVisible
  private SimulationRES060TriggerHandler(SimulationRES060Service service) {
    this.service = service;
  }

  public void run(
    System.TriggerOperation operation,
    List<Simulation_RES060__c> nouveaux
  ) {
    switch on operation {
      when BEFORE_INSERT, BEFORE_UPDATE {
        service.calculer(nouveaux);
      }
      when else {
        return;
      }
    }
  }
}
