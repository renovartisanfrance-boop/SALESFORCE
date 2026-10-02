trigger AccountTrigger on Account ( after insert, after update) {
    map<Id,Account> accountsToManage = new map<Id,Account>();
    if (Trigger.isAfter) {

        // check the opportunity
        if( Trigger.isInsert) {
            for (Account newAcc : Trigger.new) {
                accountsToManage.put(newAcc.Id, newAcc);
            }
         }
         else {
            for (Account newAcc : Trigger.new) {
                for(Account oldAcc : Trigger.Old) {
                    if(newAcc.Id == oldAcc.Id) {
                        if (newAcc.BillingPostalCode != oldAcc.BillingPostalCode) {
                            accountsToManage.put(newAcc.Id, newAcc);
                        }
                    }
                    
                }
            }
         }
        
        System.debug('>> accountsToManage: ' + accountsToManage);
        if(accountsToManage.size() > 0) {
            AccountTriggerHandler.ManageCoordinates(accountsToManage);
         }
    }

}