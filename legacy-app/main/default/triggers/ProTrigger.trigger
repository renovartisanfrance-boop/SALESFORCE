trigger ProTrigger on Pro__c (before insert, before update, after insert, after update, after delete, after undelete) {
//     if(Trigger.isInsert && Trigger.isBefore){
//       OpportunityTriggerHandler.verifier_date_planification(trigger.new,null); 
//     }
//     if(Trigger.isUpdate && Trigger.isBefore){
//       OpportunityTriggerHandler.verifier_date_planification(trigger.new,trigger.oldMap);
//    }

  if(Trigger.isInsert) {
    ProTriggerHandler.handleBeforeInsertUpdate_CreneauxCamions(Trigger.new, null);
  } else if(Trigger.isUpdate) {
    ProTriggerHandler.handleBeforeInsertUpdate_CreneauxCamions(Trigger.new, Trigger.oldMap);
  }

  List<Pro__c> prosToCheck = new List<Pro__c>();
  // Map adresse from lead after insert
  if(Trigger.isInsert && Trigger.isBefore){
    System.debug('ProTriggerHandler.map_adresse_from_lead');
    // Check if CodePostal__c has changed
    for(Pro__c pro : trigger.new){
        Pro__c oldPro = Trigger.oldMap != null ? Trigger.oldMap.get(pro.Id) : null;
        if(oldPro == null || pro.CodePostal__c != oldPro.CodePostal__c){
          prosToCheck.add(pro);
        }
    }
  }

    // Map adresse from lead after insert
    if(Trigger.IsUpdate && Trigger.isBefore){
      // check if CodePostal__c has changed
        for(Pro__c pro : trigger.new){
            Pro__c oldPro = Trigger.oldMap.get(pro.Id);
            if(pro.CodePostal__c != oldPro.CodePostal__c){
              prosToCheck.add(pro);
            }
        }
    }

    ProTriggerHandler.map_adresse_from_lead(prosToCheck);



    // // 
    // if((Trigger.isInsert || Trigger.isUpdate) && Trigger.isBefore){
    //      // Check if zip code has changed
    //      List<Opportunity> oppsToUpdate = new List<Opportunity>();
    //      if(Trigger.isInsert){
    //       for (Opportunity opp : Trigger.new) {
    //         oppsToUpdate.add(opp);
    //       }
    //      }
    //      else {
    //       for (Opportunity opp : Trigger.new) {
    //         Opportunity oldOpp = Trigger.oldMap.get(opp.Id);
    //         if (opp.Adresse__PostalCode__s != oldOpp.Adresse__PostalCode__s) {
    //             oppsToUpdate.add(opp);
    //         }
    //       }
    //      }
         
         
    //      if (!oppsToUpdate.isEmpty()) {
    //          OpportunityTriggerHandler.updateLatLong(oppsToUpdate);
    //      }
    // }
}