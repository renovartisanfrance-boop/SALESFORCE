public without sharing class SMSResponse {
      // Structure de réponse Ringover
        @AuraEnabled
        public Boolean success;
        @AuraEnabled
        public String messageId;
        @AuraEnabled
        public String status;
        @AuraEnabled
        public String errorMessage;
        @AuraEnabled
        public Integer codeStatus;
        
        public SMSResponse(Boolean success, String messageId, String status, String errorMessage, Integer codeStatus) {
            this.success = success;
            this.messageId = messageId;
            this.status = status;
            this.errorMessage = errorMessage;
            this.codeStatus = codeStatus;
        }
    
}