public without sharing class SendSMSController {
    public SendSMSController() {

    }

    @AuraEnabled(cacheable=true)
    public static List<EmailTemplate> getEmailsTemplates(){
        List<EmailTemplate> result = [SELECT Id, Name FROM EmailTemplate WHERE Name like 'SMS%'];
        return result;
    }


    // @AuraEnabled
    // public static RingoverSMSSender.SMSResponse sendSMS(SMSWrapper form){
    //     System.debug('form: ' + form);
    //     RingoverSMSSender.SMSMessage smsMessage = new RingoverSMSSender.SMSMessage(form.a, form.message, form.de);
    //     // RingoverSMSSender.SMSResponse result = RingoverSMSSender.sendSMS(smsMessage);
    //     System.debug('result: ' + result);
    //     return result;
    // }


    @AuraEnabled
    public static object getMergedSMS(SMSWrapper form){
        System.debug('form: ' + form);
        SM010_SmsTemplateService.SmsDataWrapper test = SM010_SmsTemplateService.getSMSData(form.emailTemplate, form.recordId);
        return test;
    }

    public class SMSWrapper{
        @AuraEnabled
        public Id recordId {get; set;}
        @AuraEnabled
        public Id emailTemplate {get; set;}
        @AuraEnabled
        public String de {get; set;}
        @AuraEnabled
        public String a  {get; set;}
        @AuraEnabled
        public String message {get; set;}
    }
}