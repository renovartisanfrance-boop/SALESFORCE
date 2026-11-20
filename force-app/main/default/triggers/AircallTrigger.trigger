trigger AircallTrigger on Aircall__c(after insert, after update) {
  new AircallTriggerHandler()
    .run(Trigger.operationType, Trigger.new, Trigger.oldMap);
}
