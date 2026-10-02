public without sharing class LettreImportController {

    @AuraEnabled(cacheable=true)
    public static List<FieldOption> getImportableFields(String objectApiName) {
        if (String.isBlank(objectApiName)) {
            objectApiName = 'Lettre__c';
        }

        Schema.SObjectType sobjType = Schema.getGlobalDescribe().get(objectApiName);
        if (sobjType == null) {
            throw new AuraHandledException('Objet introuvable : ' + objectApiName);
        }

        List<FieldOption> options = new List<FieldOption>();
        Map<String, Schema.SObjectField> fieldMap = sobjType.getDescribe().fields.getMap();

        for (String apiName : fieldMap.keySet()) {
            Schema.DescribeFieldResult dfr = fieldMap.get(apiName).getDescribe();
            if (!dfr.isCreateable()) {
                continue;
            }
            List<PicklistEntryOption> picklistVals = null;
            Schema.DisplayType t = dfr.getType();
            if (t == Schema.DisplayType.PICKLIST || t == Schema.DisplayType.MULTIPICKLIST) {
                picklistVals = new List<PicklistEntryOption>();
                for (Schema.PicklistEntry pe : dfr.getPicklistValues()) {
                    if (pe.isActive()) {
                        picklistVals.add(new PicklistEntryOption(pe.getLabel(), pe.getValue()));
                    }
                }
            }
            options.add(new FieldOption(
                dfr.getName(),
                dfr.getLabel(),
                String.valueOf(t),
                dfr.isCustom(),
                picklistVals
            ));
        }

        options.sort();
        return options;
    }

    @AuraEnabled
    public static Id startImport(List<Map<String, Object>> records, String objectApiName, String importName) {
        if (records == null || records.isEmpty()) {
            throw new AuraHandledException('Aucune ligne à importer.');
        }
        if (String.isBlank(objectApiName)) {
            objectApiName = 'Lettre__c';
        }
        User runningUser = [SELECT Id, Email FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        LettreImportQueueable job = new LettreImportQueueable(
            records,
            objectApiName,
            importName,
            runningUser.Id,
            runningUser.Email
        );
        return System.enqueueJob(job);
    }

    @AuraEnabled(cacheable=true)
    public static List<ImportSummary> getImportNames() {
        List<ImportSummary> result = new List<ImportSummary>();
        for (AggregateResult ar : [
            SELECT Nom_d_import__c importName, COUNT(Id) cnt
            FROM Lettre__c
            WHERE Nom_d_import__c != null
            GROUP BY Nom_d_import__c
            ORDER BY Nom_d_import__c
        ]) {
            result.add(new ImportSummary(
                (String) ar.get('importName'),
                (Integer) ar.get('cnt')
            ));
        }
        return result;
    }

    @AuraEnabled
    public static ImportDetails getImportDetails(String importName) {
        ImportDetails d = new ImportDetails();
        if (String.isBlank(importName)) {
            return d;
        }
        d.totalCount = [
            SELECT COUNT()
            FROM Lettre__c
            WHERE Nom_d_import__c = :importName
        ];
        List<AggregateResult> aircallAgg = [
            SELECT COUNT_DISTINCT(Lettre__c) cnt
            FROM Aircall__c
            WHERE Lettre__c IN (
                SELECT Id FROM Lettre__c WHERE Nom_d_import__c = :importName
            )
        ];
        d.withAircallCount = aircallAgg.isEmpty() ? 0 : (Integer) aircallAgg[0].get('cnt');
        d.withoutAircallCount = d.totalCount - d.withAircallCount;
        return d;
    }

    @AuraEnabled
    public static Id startDeleteByImportName(String importName, String scope) {
        if (String.isBlank(importName)) {
            throw new AuraHandledException('Nom d\'import requis.');
        }
        String s = String.isBlank(scope) ? 'all' : scope;
        if (s != 'all' && s != 'with-aircall' && s != 'without-aircall') {
            throw new AuraHandledException('Scope invalide : ' + s);
        }
        User u = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        LettreDeleteQueueable job = new LettreDeleteQueueable(importName, s, u.Id);
        return System.enqueueJob(job);
    }

    @AuraEnabled
    public static List<SObject> getLettresByImportName(String importName, List<String> fieldApiNames) {
        if (String.isBlank(importName)) {
            return new List<SObject>();
        }
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Lettre__c.fields.getMap();
        Set<String> safeFields = new Set<String>{ 'Id', 'Name' };
        if (fieldApiNames != null) {
            for (String f : fieldApiNames) {
                if (String.isBlank(f)) continue;
                if (fieldMap.containsKey(f.toLowerCase())) {
                    safeFields.add(f);
                }
            }
        }
        String fieldList = String.join(new List<String>(safeFields), ', ');
        String soql =
            'SELECT ' + fieldList +
            ' FROM Lettre__c WHERE Nom_d_import__c = :importName' +
            ' ORDER BY Name LIMIT 5000';
        return Database.query(soql);
    }

    @AuraEnabled
    public static Id startMassUpdate(List<Map<String, Object>> records) {
        if (records == null || records.isEmpty()) {
            throw new AuraHandledException('Aucune ligne à modifier.');
        }
        User u = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        LettreUpdateQueueable job = new LettreUpdateQueueable(records, u.Id);
        return System.enqueueJob(job);
    }

    @AuraEnabled(cacheable=true)
    public static Boolean isSystemAdmin() {
        Profile p = [
            SELECT PermissionsModifyAllData
            FROM Profile
            WHERE Id = :UserInfo.getProfileId()
            LIMIT 1
        ];
        return p.PermissionsModifyAllData;
    }

    public class FieldOption implements Comparable {
        @AuraEnabled public String apiName;
        @AuraEnabled public String label;
        @AuraEnabled public String type;
        @AuraEnabled public Boolean custom;
        @AuraEnabled public List<PicklistEntryOption> picklistValues;

        public FieldOption(String apiName, String label, String type, Boolean custom, List<PicklistEntryOption> picklistValues) {
            this.apiName = apiName;
            this.label = label;
            this.type = type;
            this.custom = custom;
            this.picklistValues = picklistValues;
        }

        public Integer compareTo(Object other) {
            FieldOption o = (FieldOption) other;
            return this.label.compareTo(o.label);
        }
    }

    public class PicklistEntryOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;

        public PicklistEntryOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    public class ImportSummary {
        @AuraEnabled public String importName;
        @AuraEnabled public Integer count;

        public ImportSummary(String importName, Integer count) {
            this.importName = importName;
            this.count = count;
        }
    }

    public class ImportDetails {
        @AuraEnabled public Integer totalCount = 0;
        @AuraEnabled public Integer withAircallCount = 0;
        @AuraEnabled public Integer withoutAircallCount = 0;
    }
}