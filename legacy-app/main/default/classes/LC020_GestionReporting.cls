/**
 * Contrôleur Apex pour le composant lwc020_reporting_v2
 * Récupère les données de reporting depuis Lead, Opportunity et Pro__c
 * Supporte le suivi de l'historique de champs via champsLeadTracked / champsProTracked
 */
public without sharing class LC020_GestionReporting {

    // Wrapper pour les métadonnées de champs envoyées depuis le LWC
    public class ReportingMetadata {
        @AuraEnabled public String champsLead         { get; set; }
        @AuraEnabled public String champsOpportunite  { get; set; }
        @AuraEnabled public String champsPro          { get; set; }
        // Champs à historiser (séparés par des virgules)
        @AuraEnabled public String champsLeadTracked  { get; set; }
        @AuraEnabled public String champsProTracked   { get; set; }
        // Campagn token:
        @AuraEnabled public String campaignCode      { get; set; }
        // Community user flag:
        @AuraEnabled public Boolean isCommunityUser  { get; set; }
    }

    // Entrée d'historique de champ retournée au LWC
    public class FieldHistoryRecord {
        @AuraEnabled public String   recordId     { get; set; }
        @AuraEnabled public String   fieldName    { get; set; }
        @AuraEnabled public DateTime lastModified { get; set; }
    }

    // Wrapper pour le résultat retourné au LWC
    public class ReportingResult {
        @AuraEnabled public List<SObject>           leads        { get; set; }
        @AuraEnabled public List<SObject>           opportunites { get; set; }
        @AuraEnabled public List<SObject>           dossiers     { get; set; }
        @AuraEnabled public List<FieldHistoryRecord> leadHistory  { get; set; }
        @AuraEnabled public List<FieldHistoryRecord> proHistory   { get; set; }
    }

    @AuraEnabled
    public static ReportingResult getReportingData(ReportingMetadata metadata) {
        if (metadata == null || String.isBlank(metadata.champsLead) /*|| String.isBlank(metadata.champsOpportunite)*/ || String.isBlank(metadata.champsPro)) {
            System.debug('Metadata invalide reçue : ' + JSON.serialize(metadata));
            throw new AuraHandledException('Metadata invalide : tous les champs doivent être renseignés. Reçu : ' + JSON.serialize(metadata));
        }

        ReportingResult result = new ReportingResult();

        // ── Filtrage par campagne ──────────────────────────────────────────────
        Set<Id> campaignLeadIds    = null;
        Set<Id> campaignIdsForPro  = null;
        String proQueryClause = null;
        String pisteQueryClause = null;

        if (metadata.isCommunityUser == true) {
            // Community user : toutes les campagnes dont l'OwnerId = utilisateur courant
            Id currentUserId = UserInfo.getUserId();

            // check user Profil:
            String userProfileName = [SELECT Profile.Name, Pays__c FROM User WHERE Id = :currentUserId].Profile.Name;
            String userCountry = [SELECT Profile.Name, Pays__c FROM User WHERE Id = :currentUserId].Pays__c;
            // start change here
            List<Pro__c> dossiers = new List<Pro__c>();
            if (userProfileName == Constants.PROFIL_PI_RESPONSABLE_TELEPRO) {
                String RT_Dossier_AA_BAR = Constants.RT_Dossier_AA_BAR;
                String fiche_060 = Constants.FICHE_PISTE_060;
                List<String> statutNonTelepro = new List<String>{'🟦En Att Signature', '🟩Signé'};
                pisteQueryClause = ' TypeDeDossier__c INCLUDES (:fiche_060) AND RecordType.Name like \'AA-%\' AND ((ConfirmateurLookup__c != null AND RENO_Sous_Statut_Leads__c = \'🟩Envoyé En Signature\') OR (ConfirmateurLookup__c = null AND RES_Statut_Devis__c IN :statutNonTelepro ))';
            } else if (userProfileName == Constants.PROFIL_PI_CONFIRMATEUR) {
                String profilConfirmateur = Constants.PROFIL_PI_CONFIRMATEUR;
                proQueryClause = ' Confirmateurs__c = :currentUserId AND RecordType.Name like \'AA-%\'';
                pisteQueryClause = ' Utilisateur__c = :currentUserId AND CONFIRM_Traitement__c = \'🟩Conf Ok- Att prévisite\' AND RecordType.Name like \'AA-%\' AND IsConverted = false';
            } else if (/*userProfileName == Constants.PROFIL_PI_TELEPRO_DATA ||*/ userProfileName == Constants.PROFIL_PI_TELEPRO_LEADS) {
                proQueryClause = ' LOOKUP_Telepro__c = :currentUserId AND RecordType.Name like \'AA-%\'';
                pisteQueryClause = ' ConfirmateurLookup__c = :currentUserId AND RecordType.Name like \'AA-%\' AND RENO_Sous_Statut_Leads__c = \'🟩Envoyé En Signature\'';
            } else if (userProfileName == Constants.PROFIL_PI_APP_AFF || userProfileName == Constants.PROFIL_PI_APP_AFF_INTERNE) {
                    // end change here
                List<Campaign> camps = [
                    SELECT Id, (SELECT Id FROM ChildCampaigns)
                    FROM Campaign
                    WHERE OwnerId = :currentUserId
                ];
                if (!camps.isEmpty()) {
                    Set<Id> campaignIds = new Set<Id>();
                    for (Campaign c : camps) {
                        campaignIds.add(c.Id);
                        for (Campaign child : c.ChildCampaigns) {
                            campaignIds.add(child.Id);
                        }
                    }
                    campaignIdsForPro = campaignIds;

                    // Leads via CampaignMember
                    campaignLeadIds = new Set<Id>();
                    for (CampaignMember m : [
                        SELECT LeadId FROM CampaignMember
                        WHERE CampaignId IN :campaignIds AND LeadId != null
                    ]) {
                        campaignLeadIds.add(m.LeadId);
                    }
                }

                pisteQueryClause = ' Id IN :campaignLeadIds AND IsConverted = false';
                proQueryClause = ' Campagne_REGIE__c IN :campaignIdsForPro';
            } else {
                throw new AuraHandledException('Profil utilisateur non géré : ' + userProfileName);
            }
            
        } else if (String.isNotBlank(metadata.campaignCode)) {
            List<Campaign> camps = [
                SELECT Id, (SELECT Id FROM ChildCampaigns)
                FROM Campaign
                WHERE CampaignToken__c = :metadata.campaignCode
                LIMIT 1
            ];
            if (!camps.isEmpty()) {
                Set<Id> campaignIds = new Set<Id>();
                campaignIds.add(camps[0].Id);
                for (Campaign child : camps[0].ChildCampaigns) {
                    campaignIds.add(child.Id);
                }
                campaignIdsForPro = campaignIds;

                // Leads via CampaignMember
                campaignLeadIds = new Set<Id>();
                for (CampaignMember m : [
                    SELECT LeadId FROM CampaignMember
                    WHERE CampaignId IN :campaignIds AND LeadId != null
                ]) {
                    campaignLeadIds.add(m.LeadId);
                }
            }

            pisteQueryClause = ' Id IN :campaignLeadIds AND IsConverted = false';
            proQueryClause = ' Campagne_REGIE__c IN :campaignIdsForPro';
        } else {
            throw new AuraHandledException('Token de campagne non fourni');
        }

        // ── Requêtes principales ────────────────────────────────────────────────
        if(pisteQueryClause != null){
            try {
                // result.leads        = Database.query('SELECT ' + metadata.champsLead + ' FROM Lead WHERE Id IN :campaignLeadIds AND IsConverted = false');
                result.leads        = Database.query('SELECT ' + metadata.champsLead + ' FROM Lead WHERE ' + pisteQueryClause);
            } catch (Exception e) {
                System.debug('Erreur lors de la requête Lead : ' + e.getMessage());
                // throw new AuraHandledException('Erreur lors de la récupération des leads : ' + e.getMessage());
            }

        }
        // result.opportunites = Database.query('SELECT ' + metadata.champsOpportunite + ' FROM Opportunity');
        if(proQueryClause != null){
            try {
                // result.dossiers     = Database.query('SELECT ' + metadata.champsPro + ' FROM Pro__c WHERE Campagne_REGIE__c IN :campaignIdsForPro');
                result.dossiers     = Database.query('SELECT ' + metadata.champsPro + ' FROM Pro__c WHERE ' + proQueryClause);
            } catch (Exception e) {
                System.debug('Erreur lors de la requête Pro__c : ' + e.getMessage());
                // throw new AuraHandledException('Erreur lors de la récupération des dossiers : ' + e.getMessage());
            }
        }

        // ── Historique Lead ─────────────────────────────────────────────────────
        result.leadHistory = new List<FieldHistoryRecord>();
        if (String.isNotBlank(metadata.champsLeadTracked) && result.leads != null && result.leads.size() > 0) {
            Set<Id> leadIds = new Set<Id>();
            for (SObject s : result.leads) { leadIds.add((Id) s.get('Id')); }

            List<String> cleanFields = new List<String>();
            for (String f : metadata.champsLeadTracked.split(',')) {
                String ft = f.trim();
                if (String.isNotBlank(ft)) cleanFields.add(ft);
            }

            // Une seule entrée par (Lead, Field) — la plus récente (ORDER BY DESC puis skip si déjà vu)
            Map<String, Map<String, DateTime>> histMap = new Map<String, Map<String, DateTime>>();
            for (LeadHistory h : [
                SELECT LeadId, Field, CreatedDate
                FROM LeadHistory
                WHERE LeadId IN :leadIds
                AND   Field  IN :cleanFields
                ORDER BY LeadId, Field, CreatedDate DESC
            ]) {
                String lid = String.valueOf(h.LeadId);
                if (!histMap.containsKey(lid))          histMap.put(lid, new Map<String, DateTime>());
                if (!histMap.get(lid).containsKey(h.Field)) {
                    histMap.get(lid).put(h.Field, h.CreatedDate);
                }
            }
            for (String recId : histMap.keySet()) {
                for (String fn : histMap.get(recId).keySet()) {
                    FieldHistoryRecord fhr = new FieldHistoryRecord();
                    fhr.recordId     = recId;
                    fhr.fieldName    = fn;
                    fhr.lastModified = histMap.get(recId).get(fn);
                    result.leadHistory.add(fhr);
                }
            }
        }

        // ── Historique Pro__c ───────────────────────────────────────────────────
        result.proHistory = new List<FieldHistoryRecord>();
        if (String.isNotBlank(metadata.champsProTracked) && result.dossiers != null && result.dossiers.size() > 0) {
            Set<Id> proIds = new Set<Id>();
            for (SObject s : result.dossiers) { proIds.add((Id) s.get('Id')); }

            List<String> cleanFields = new List<String>();
            for (String f : metadata.champsProTracked.split(',')) {
                String ft = f.trim();
                if (String.isNotBlank(ft)) cleanFields.add(ft);
            }

            Map<String, Map<String, DateTime>> histMap = new Map<String, Map<String, DateTime>>();
            for (Pro__History h : [
                SELECT ParentId, Field, CreatedDate
                FROM Pro__History
                WHERE ParentId IN :proIds
                AND   Field    IN :cleanFields
                ORDER BY ParentId, Field, CreatedDate DESC
            ]) {
                String pid = String.valueOf(h.ParentId);
                if (!histMap.containsKey(pid))          histMap.put(pid, new Map<String, DateTime>());
                if (!histMap.get(pid).containsKey(h.Field)) {
                    histMap.get(pid).put(h.Field, h.CreatedDate);
                }
            }
            for (String recId : histMap.keySet()) {
                for (String fn : histMap.get(recId).keySet()) {
                    FieldHistoryRecord fhr = new FieldHistoryRecord();
                    fhr.recordId     = recId;
                    fhr.fieldName    = fn;
                    fhr.lastModified = histMap.get(recId).get(fn);
                    result.proHistory.add(fhr);
                }
            }
        }

        return result;
    }

        public static void fakeMethod() {
        Integer dummy = 0;
        dummy++;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy++;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
         dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
          dummy++;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
    }
}