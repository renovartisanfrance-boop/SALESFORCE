trigger OpportunityTrigger on Opportunity(before insert,before update,after insert,after update) {
    if(Trigger.isInsert && Trigger.isBefore){
      OpportunityTriggerHandler.verifier_date_planification(trigger.new,null); 
    }
    if(Trigger.isUpdate && Trigger.isBefore){
      OpportunityTriggerHandler.verifier_date_planification(trigger.new,trigger.oldMap);
   }

    // Map adresse from lead after insert
    if(Trigger.isInsert && Trigger.isBefore){
      System.debug('OpportunityTriggerHandler.map_adresse_from_lead');
        OpportunityTriggerHandler.map_adresse_from_lead(trigger.new);
    }


    // 
    if((Trigger.isInsert || Trigger.isUpdate) && Trigger.isBefore){
         // Check if zip code has changed
         List<Opportunity> oppsToUpdate = new List<Opportunity>();
         if(Trigger.isInsert){
          for (Opportunity opp : Trigger.new) {
            oppsToUpdate.add(opp);
          }
         }
         else {
          for (Opportunity opp : Trigger.new) {
            Opportunity oldOpp = Trigger.oldMap.get(opp.Id);
            if (opp.Adresse__PostalCode__s != oldOpp.Adresse__PostalCode__s) {
                oppsToUpdate.add(opp);
            }
          }
         }
         
         
         if (!oppsToUpdate.isEmpty()) {
             OpportunityTriggerHandler.updateLatLong(oppsToUpdate);
         }
    }
}