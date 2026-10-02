public class RollupActivities {
    
    // These variables store Trigger.oldMap and Trigger.newMap
    Map<Id, Task> oldTasks;
    Map<Id, Task> newTasks;
    
    // This is the constructor
    // A map of the old and new records is expected as inputs
    public RollupActivities(
        Map<Id, Task> oldTriggerTasks, 
        Map<Id, Task> newTriggerTasks) {
            oldTasks = oldTriggerTasks;
            newTasks = newTriggerTasks;
        }
    
    // The one method your master trigger will call
    public void RollupActivitiesOnLead() {
        List<Id> leadIds = new List<Id>();
        //List<Lead> leadsToUpdate = new List<Lead>();
        Map<Id, Integer> leadsToUpdate = new Map<Id, Integer>();
        
        for(Id taskId: newTasks.keySet()){
            String leadId = newTasks !=null && newTasks.containsKey(taskId) ? (String)newTasks.get(taskId).get('WhoId') : '' ;
            String oldLeadId = oldTasks !=null && oldTasks.containsKey(taskId) ? (String)oldTasks.get(taskId).get('WhoId') : '' ;
            
            if(String.isNotBlank(leadId) && leadId.contains('00Q')){
                leadIds.add(leadId);
            }
            if(String.isNotBlank(oldLeadId) && oldLeadId.contains('00Q')){
                leadIds.add(oldLeadId);
            }
            
        }
        system.debug('leadIds : ' + leadIds);
        if(leadIds.size()>0){
            updateLead(leadIds);
        }
    }
    
    
    private static void updateLead (List<Id> leadIds){
        List<Lead> leads = new List<Lead>();
        
        //obtenir tous les pistes & taches associées
        for(Lead ld: [Select id, Nombre_Activite__c, (Select Id, subject from Tasks) from Lead where Id IN:leadIds
                      and isconverted != true]){
            Integer nbTaskUnanswered = 0;
            Integer nbTaskAnswered = 0;
            Integer nbSmsSended = 0;
            Integer nbSmsRecieved = 0;
            
            for(Task tk: ld.tasks){
                if(tk.subject.contains(Label.ROLLUP_TASK_UNANSW)) nbTaskUnanswered++;
                if(tk.subject.contains(Label.ROLLUP_TASK_ANSWERED)) nbTaskAnswered++;
               // if(tk.subject.contains(Label.ROLLUP_SMS_RECEIVE)) nbSmsRecieved++;
               // if(tk.subject.contains(Label.ROLLUP_SMS_SEND)) nbSmsSended++;
            }
            
            ld.Nombre_Activite__c = ld.tasks !=null ? ld.tasks.size(): 0;
            ld.NombreTacheSortantsNRP__c = nbTaskUnanswered;
            ld.NombreTacheSortantsSucces__c = nbTaskAnswered;
			//ld.NombresmsEntrants__c = nbSmsRecieved;
			//ld.NombresmsSortants__c = nbSmsSended;                          
            leads.add(ld);
        }
        if(leads.size() > 0) update leads; 
    }
    
}