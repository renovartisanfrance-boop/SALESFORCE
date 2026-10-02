public without sharing class SMSMessage {
        public String phoneNumber;
        public String message;
        public String ringoverNumber; // Numéro Ringover source
        public ID recordId; // Numéro Ringover source
        public ID templateId; // Numéro Ringover source
        public Boolean createTaskOnFailure;
        
        public SMSMessage(String phoneNumber, String message) {
            this.phoneNumber = phoneNumber;
            this.message = message;
        }
        
        public SMSMessage(String phoneNumber, String message, String ringoverNumber) {
            this.phoneNumber = phoneNumber;
            this.message = message;
            this.ringoverNumber = ringoverNumber;
        }
        
        public SMSMessage(String phoneNumber, String message, ID recordId, ID templateId) {
            this(phoneNumber, message);
            this.recordId = recordId;
            this.templateId = templateId;
        }
}