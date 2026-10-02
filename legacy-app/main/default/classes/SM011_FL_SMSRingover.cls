global class SM011_FL_SMSRingover {

    /*An invocable variable used as input in the screen flow*/
    global class ActionRequest {
        @InvocableVariable(required = true label = 'Template ID')
        public ID templateId;
        // @InvocableVariable(required = true)
        @InvocableVariable(required = true label = 'Record ID')
        public ID recordId;
        @InvocableVariable(required = true label = 'Numéro de téléphone')
        public String phoneNumber;
        @InvocableVariable(required = true label = 'Créer une tâche en cas d\'échec')
        public Boolean createTaskOnFailure;
    }
    //This invocable method is used for processing the business by taking the input from screen flow
    @InvocableMethod(label = 'Sens SMS To email template and record')
    global static void SensSMS(List<ActionRequest> requests) {
        for (ActionRequest request : requests) {
            SM010_SmsTemplateService.SmsDataWrapper smsData = SM010_SmsTemplateService.getSMSData(request.templateId, request.recordId);
            SMSMessage smsMessage = new SMSMessage(request.phoneNumber, smsData.messageBody);
            smsMessage.recordId = request.recordId;
            smsMessage.templateId = request.templateId;
            smsMessage.createTaskOnFailure = request.createTaskOnFailure;
            // SMSResponse result = RingoverSMSSender.sendSMS(smsMessage);
            SMSResponse result = AircallSMSSender.sendSMS(smsMessage);
        }
    }
}