trigger SimulationRES060Trigger on Simulation_RES060__c(
  before insert,
  before update
) {
  new SimulationRES060TriggerHandler().run(Trigger.operationType, Trigger.new);
}
