global class BatchUpdateEnMasse implements Database.Batchable<sObject> {

    // Constructor
    global BatchUpdateEnMasse() {
    }

    // Start method - defines the scope of records to process
    global Database.QueryLocator start(Database.BatchableContext BC) {
        String query = 'SELECT Id, RecordTypeId FROM Lead where TYPE_DE_DOSSIER__c  = \'🟨DATA\' AND RecordTypeId != \'012bR00000EKxlRQAT\'';
        return Database.getQueryLocator(query);
    }

    // Execute method - processes each batch of records
    global void execute(Database.BatchableContext BC, List<Lead> scope) {
        List<Lead> leadsToUpdate = new List<Lead>();
        
        try {
            for (Lead lead : scope) {
                // Create a new Lead record with just Id and the field to update
                Lead leadToUpdate = new Lead(Id = lead.Id);
                
                // Dynamically set the field value
                leadToUpdate.put('RecordTypeId', '012bR00000EKxlRQAT');
                
                leadsToUpdate.add(leadToUpdate);
            }
            
            // Perform DML with partial success allowed
            if (!leadsToUpdate.isEmpty()) {
                Database.SaveResult[] results = Database.update(leadsToUpdate, false);
                
                // Log any failures
                for (Integer i = 0; i < results.size(); i++) {
                    if (!results[i].isSuccess()) {
                        // System.debug('Failed to update Lead Id: ' + leadsToUpdate[i].Id + 
                        //            ' Error: ' + results[i].getErrors()[0].getMessage());
                    }
                }
            }
            
        } catch (Exception e) {
            System.debug('Error in LeadMassUpdateBatch execute: ' + e.getMessage());
            // You might want to send an email or log to a custom object here
        }
    }

    // Finish method - called after all batches are processed
    global void finish(Database.BatchableContext BC) {
        // Get job info
        // AsyncApexJob job = [SELECT Id, Status, NumberOfErrors, JobItemsProcessed, 
        //                    TotalJobItems, CreatedBy.Email, CreatedDate, CompletedDate
        //                    FROM AsyncApexJob WHERE Id = :BC.getJobId()];
        
        // System.debug('Lead Mass Update Batch completed. Status: ' + job.Status + 
        //             ', Records Processed: ' + job.JobItemsProcessed + 
        //             ', Errors: ' + job.NumberOfErrors);
        
        // Optional: Send completion email
        // if (job.CreatedBy.Email != null) {
        //     sendCompletionEmail(job);
        // }
    }
}