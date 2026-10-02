public without sharing class SM010_SmsTemplateService {


    public String AccountBrandId = Label.AccountBrandId;
    
    public SM010_SmsTemplateService() {
        // Constructor
        // string AccountBrandId = Label.AccountBrandId;
    }
    
    /**
     * Gets SMS data from an email template and merges field values from the related record
     * @param emailTemplateId The ID of the email template to use
     * @param recordId The ID of the record to get field values from
     * @return SmsDataWrapper containing the template data and merged field values
     */
    public static SmsDataWrapper getSMSData(Id emailTemplateId, Id recordId) {
        // Query the email template
        EmailTemplate template = [
            SELECT Id, Subject, Body, HtmlValue, RelatedEntityType
            FROM EmailTemplate
            WHERE Id = :emailTemplateId
        ];
        
        // Get the object API name from the template's related entity type
        String objectApiName = template.RelatedEntityType;
        
        // Use HtmlValue if Body is null
        String templateContent = (template.Body != null && template.Body.trim() != '') 
                                ? template.Body 
                                : extractTextFromHtml(template.HtmlValue);
        
        // Extract merge fields from the template content
        Set<String> mergeFieldsSetRecepient = extractRecipientMergeFields('Recipient',templateContent);
        List<String> fieldsRecepient = new List<String>(mergeFieldsSetRecepient);

        Set<String> mergeFieldsSetAccounBrand = extractRecipientMergeFields('AccountBrand',templateContent);
        List<String> fieldsAccounBrand = new List<String>(mergeFieldsSetAccounBrand);
        
        // Query the record with dynamic fields
        Map<String, String> fieldValuesRecepient = getFieldValues(objectApiName, fieldsRecepient, recordId);
        Map<String, String> fieldValuesAccounBrand = getFieldValues('AccountBrand', fieldsAccounBrand, Label.AccountBrandId);
        
        // Create and return the wrapper
        SmsDataWrapper smsData = new SmsDataWrapper();
        smsData.recordId = recordId;
        smsData.objectApiName = objectApiName;
        smsData.fieldsRecepient = fieldsRecepient;
        smsData.fieldValues = fieldValuesRecepient;
        
        // Merge the template with field values
        string body =  mergeFieldsIntoTemplate(templateContent, fieldValuesRecepient);
        body = mergeFieldsIntoTemplate(body, fieldValuesAccounBrand);
        
        smsData.messageBody = body;

        System.debug('>> SMS data: ' + smsData);
        return smsData;
    }
    
    /**
     * Extracts plain text content from HTML
     * @param htmlContent The HTML content
     * @return The extracted text content
     */
    private static String extractTextFromHtml(String htmlContent) {
        if (htmlContent == null) {
            return '';
        }
        
        // Remove HTML tags but preserve the content between them
        String plainText = htmlContent.replaceAll('<[^>]+>', ' ');
        
        // Remove extra whitespace
        plainText = plainText.replaceAll('\\s+', ' ').trim();
        
        return plainText;
    }
    
    /**
     * Extracts merge fields from template text with triple curly braces format {{{Recipient.Field}}}
     * @param templateText The template text containing merge fields
     * @return Set of field API names
     */
    private static Set<String> extractRecipientMergeFields(String prefixMerge, String templateText) {
        Set<String> fields = new Set<String>();
        
        if (templateText == null) {
            return fields;
        }
        
        // Pattern to match merge fields like {{{Recipient.Field}}}
        Pattern pattern = Pattern.compile('\\{\\{\\{('+ prefixMerge +'\\.\\w+)\\}\\}\\}');
        Matcher matcher = pattern.matcher(templateText);
        System.debug('Template text: ' + templateText);
        while (matcher.find()) {
            System.debug('Template text: ' + matcher);

            String fullMatch = matcher.group(1); // Recipient.Field
            String[] parts = fullMatch.split('\\.');
            System.debug('parts: ' + parts);

            if (parts.size() == 2) {
                // We only want the field name, not the object prefix
                fields.add(parts[1]);
            }
        }
        System.debug('fields: ' + fields);

        return fields;
    }
    
    /**
     * Gets field values from a record dynamically
     * @param objectApiName The API name of the object
     * @param fields The list of fields to query
     * @param recordId The ID of the record
     * @return Map of field names to their values
     */
    private static Map<String, String> getFieldValues(String objectApiName, List<String> fields, Id recordId) {
        Map<String, String> fieldValues = new Map<String, String>();
        
        if (fields.isEmpty() || String.isBlank(objectApiName)) {
            return fieldValues;
        }
        
        // Build dynamic SOQL query
        String query = 'SELECT Id, ' + String.join(fields, ', ') + 
                      ' FROM ' + objectApiName + 
                      ' WHERE Id = :recordId';
        
        try {
            SObject record = Database.query(query);
            
            // Extract field values
            for (String field : fields) {
                Object value = record.get(field);
                fieldValues.put(field, value != null ? String.valueOf(value) : 'N/A');
            }
        } catch (Exception e) {
            System.debug('Error querying record: ' + e.getMessage());
        }
        
        return fieldValues;
    }
    
    /**
     * Merges field values into the template with triple curly braces format
     * @param templateText The template text with merge fields
     * @param fieldValues Map of field names to values
     * @return Merged text with values substituted for merge fields
     */
    private static String mergeFieldsIntoTemplate(String templateText, Map<String, String> fieldValues) {
        if (templateText == null) {
            return '';
        }
        
        String mergedText = templateText;
        
        for (String field : fieldValues.keySet()) {
            String mergeFieldPattern = '\\{\\{\\{\\w+\\.' + field + '\\}\\}\\}';
            String value = fieldValues.get(field);
            
            mergedText = mergedText.replaceAll(mergeFieldPattern, value);
        }
        
        return mergedText;
    }
    
    /**
     * Sends an SMS using the prepared template and data
     * @param smsData The wrapper containing template data and field values
     * @param phoneNumber The phone number to send the SMS to
     * @return Boolean indicating success or failure
     */
    public static Boolean sendSMS(SmsDataWrapper smsData, String phoneNumber) {
        try {
            if (String.isBlank(smsData.messageBody)) {
                System.debug('SMS body is empty, nothing to send');
                return false;
            }
            
            // This is a placeholder for the actual SMS sending logic
            // You would integrate with your SMS service provider here
            
            // Example:
            // SMS_Provider__c.send(phoneNumber, smsData.messageBody);
            
            System.debug('SMS would be sent to: ' + phoneNumber);
            System.debug('SMS content: ' + smsData.messageBody);
            
            return true;
        } catch (Exception e) {
            System.debug('Error sending SMS: ' + e.getMessage());
            return false;
        }
    }
    
    public class SmsDataWrapper {
        @AuraEnabled
        public Id recordId {get;set;}
        @AuraEnabled
        public String objectApiName {get;set;}
        @AuraEnabled
        public List<String> fieldsRecepient {get;set;}
        @AuraEnabled
        public Map<String, String> fieldValues {get;set;}
        @AuraEnabled
        public String messageBody {get;set;} // Merged template text ready to send
    }
}