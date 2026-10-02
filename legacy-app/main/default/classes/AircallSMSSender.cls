public without sharing class AircallSMSSender {
    public AircallSMSSender() {

    }

     // Configuration de l'API Ringover
     private static final String API_ENDPOINT = Label.SMS_AIRCALL_API_ENDPOINT; // À remplacer par label
     private static final String API_KEY = Label.SMS_AIRCALL_TOKEN; // À remplacer par label
     private static final String NUM_RINGOVER_SOURCE = Label.SMS_NUM_RINGOVER_SOURCE; // À remplacer par label
     private static final String BLOQ_SENDING = Label.SMS_AIRCALL_STATE; // À remplacer par label
     
    
     
     public static SMSResponse sendSMS(SMSMessage smsMessage) {
         SendSyncSMS(smsMessage.phoneNumber, smsMessage.message, smsMessage.createTaskOnFailure, smsMessage.recordId, smsMessage.templateId);
         return null;
     }
     
     // Méthode principale pour envoyer un SMS via Ringover
     @future(callout=true)
     public static void SendSyncSMS(String phoneNumber, String message, Boolean createTaskOnFailure, ID recordId, ID templateId) {
         SMSMessage smsMessage = new SMSMessage(phoneNumber, message, recordId, templateId);
         if(BLOQ_SENDING != 'ACTIVE'){
             // return new SMSResponse(
             //     true,
             // '0',
             // 'SMS SENDING ARE BLOCKED',
             // null,
             // 200
             //     );
             String errorMessage = 'L\'envoi de SMS est bloqué. Veuillez contacter l\'administrateur.';
             SMSResponse result =  new SMSResponse(false, null, 'ERROR', 'Exception: ' + errorMessage, null);
            //  SmsResponse result = new SMSResponse(true, '0', 'SMS SENDING ARE BLOCKED', null, 200);
            createTaskOnFailure(smsMessage, result);
            return;
         }
         try {
             String formattedPhoneNumber = formatNumber(smsMessage.phoneNumber);
             // Vérifier le numéro de téléphone
             if (!isValidPhoneNumber(phoneNumber)) {
                 SMSResponse result = new SMSResponse(false, null, 'INVALID_NUMBER', 'Format de numéro invalide > ' + formattedPhoneNumber + '('+ smsMessage.phoneNumber +')', null);
                 createTaskOnFailure(smsMessage, result);
             }
             
             // Préparer la requête HTTP pour Ringover
             HttpRequest req = new HttpRequest();
             req.setEndpoint(API_ENDPOINT);
             req.setMethod('POST');
             req.setHeader('Content-Type', 'application/json');
             req.setHeader('Authorization', API_KEY);
             
             // Construire le corps de la requête selon le format Ringover
             Map<String, Object> requestBody = new Map<String, Object>{
                 'to' => formattedPhoneNumber,
                 'body' => smsMessage.message
             };
             
             req.setBody(JSON.serialize(requestBody));
             
             // Envoyer la requête
             Http http = new Http();
             
             HttpResponse res = http.send(req);
             
             // Traiter la réponse de Ringover
             if (res.getStatusCode() == 200 || res.getStatusCode() == 202) {
                 Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
                 // return new SMSResponse(
                 //     true,
                 // String.valueOf(responseMap.get('id')),
                 // 'SENT',
                 // null,
                 // res.getStatusCode()
                 //     );
             } else {
                 Map<String, Object> errorMap = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
                 SMSResponse result = new SMSResponse( false, null, 'ERROR', 'Erreur Ringover: ' + errorMap.get('message'), res.getStatusCode());
                 createTaskOnFailure(smsMessage, result);
             }
             
         } catch (Exception e) {
             SMSResponse result =  new SMSResponse(false, null, 'ERROR', 'Exception: ' + e.getMessage(), null);
             createTaskOnFailure(smsMessage, result);
         }
     }
     
     // Valider le format du numéro
     public static Boolean isValidPhoneNumber(String phoneNumber) {
         //  String formattedNumber = formatPhoneNumber(phoneNumber);
         // Vérifie le format france +33 suivi de 9 chiffres
         // return Pattern.matches('^\\+?33\\d{9}$', phoneNumber);
         return true;
         // return Pattern.matches('^\\33\\d{9}$', formattedNumber);
         //  return Pattern.matches('^\\[1-9]\\d{1,14}$', formattedNumber);
     }
 
     public static String formatNumber(String phoneNumber) {
         // eliminer les expaces, /, -, ., (, )
         phoneNumber = phoneNumber.replaceAll('[^0-9]', '');
         return phoneNumber;
     }
     
     // Méthode pour vérifier le solde SMS (crédits restants)
     public static Integer checkSMSBalance() {
        return 1;
        //  try {
        //      HttpRequest req = new HttpRequest();
        //      req.setEndpoint('https://api.ringover.com/v2/account/credits');
        //      req.setMethod('GET');
        //      req.setHeader('Authorization', 'Bearer ' + API_KEY);
             
        //      Http http = new Http();
        //      HttpResponse res = http.send(req);
             
        //      if (res.getStatusCode() == 200) {
        //          Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
        //          return Integer.valueOf(responseMap.get('sms_credits'));
        //      }
        //      return -1; // En cas d'erreur
        //  } catch (Exception e) {
        //      return -1;
        //  }
     }
     
     // // Méthode pour envoyer des SMS en masse
     // public static List<SMSResponse> sendBulkSMS(List<SMSMessage> messages) {
     //     List<SMSResponse> responses = new List<SMSResponse>();
     //     Integer smsBalance = checkSMSBalance();
         
     //     if (smsBalance >= messages.size()) {
     //         for(SMSMessage message : messages) {
     //             responses.add(sendSMS(message));
     //         }
     //     } else {
     //         // Ajouter une réponse d'erreur si pas assez de crédits
     //         SMSResponse errorResponse = new SMSResponse(
     //             false,
     //         null,
     //         'INSUFFICIENT_CREDITS',
     //         'Crédits SMS insuffisants',
     //         null
     //             );
     //         responses.add(errorResponse);
     //     }
     //     return responses;
     // }
     
     
     public static void createTaskOnFailure(SMSMessage smsMessage, SMSResponse result) {
         Task task = new Task();
         task.Subject = 'SMS Sending echoué';
         task.Description = 'SMS Sending echoué pour le template ' + smsMessage.templateId + ' et le record ' + smsMessage.recordId + ' - ERROR : ' + result.errorMessage;
         task.WhoId = smsMessage.recordId;
         task.Priority = 'High';
         task.Status = 'Not Started';
         insert task;
     }
}