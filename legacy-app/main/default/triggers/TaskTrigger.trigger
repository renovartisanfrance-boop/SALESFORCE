trigger TaskTrigger on Task (
    before insert, after insert, 
    before update, after update, 
    before delete, after delete) {
        
        if (Trigger.isBefore) {
            if (Trigger.isInsert) {
                // Call class logic here!
                // TaskTriggerHandler.onBeforeInsert(null, Trigger.new);
                
            } 
            if (Trigger.isUpdate) {
                // Call class logic here!
            }
            if (Trigger.isDelete) {
                // Call class logic here!
            }
        }
        
        if (Trigger.isAfter) {
            if (Trigger.isInsert) {
                // Call class logic here!
                TaskTriggerHandler.onAfterInsert(null, Trigger.newMap);
                
            } 
            if (Trigger.isUpdate) {
                // Call class logic here!
                TaskTriggerHandler.onAfterUpdate(Trigger.oldMap, Trigger.newMap);
            }
            if (Trigger.isDelete) {
                // Call class logic here!
                TaskTriggerHandler.onAfterDelete(null, Trigger.oldMap);
            }
        }
    }