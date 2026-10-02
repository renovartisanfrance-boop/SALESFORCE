/**
 * Contrôleur du paramétrage du Catalogue Tarifaire (objet CatalogueTarifaire__c).
 *
 * Sert les composants lwc022Catalogue* :
 *  - describe dynamique des champs (catalogue + dossier Pro__c) avec valeurs de
 *    picklist, pour proposer les variables de décision sans rien coder en dur ;
 *  - lecture / sauvegarde / suppression des lignes de catalogue, le champ
 *    ParametresFiche__c portant les règles de tarification au format JSON.
 *
 * Le calcul effectif des montants (depuis le bouton facturation, côté dossier)
 * n'est PAS du ressort de ce contrôleur : il ne fait que stocker la logique.
 */
public without sharing class LC022CatalogueTarifaireController {

    private static final String CATALOGUE_OBJECT = 'CatalogueTarifaire__c';

    // Champs fixes éditables d'une ligne de catalogue (hors JSON ParametresFiche__c).
    private static final List<String> FIXED_FIELDS = new List<String>{
        'FicheCEE__c', 'TypeIntervenant__c', 'RoleIntervenant__c',
        'DateDebutValidite__c', 'DateFinValidite__c',
        'EcheancePaiement1__c', 'EcheancePaiement2__c'
    };

    // ============================ DTOs ============================

    public class PicklistEntryDTO {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        public PicklistEntryDTO(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    /**
     * Description normalisée d'un champ exploitable par le composant.
     * dataType ∈ { picklist, number, date, datetime, boolean, text, reference }.
     */
    public class FieldDescriptorDTO implements Comparable {
        @AuraEnabled public String apiName;
        @AuraEnabled public String label;
        @AuraEnabled public String dataType;
        @AuraEnabled public Boolean required;
        @AuraEnabled public String referenceTo; // objet cible pour les lookups
        @AuraEnabled public List<PicklistEntryDTO> picklistValues;

        public Integer compareTo(Object other) {
            FieldDescriptorDTO o = (FieldDescriptorDTO) other;
            String a = (this.label == null) ? '' : this.label.toLowerCase();
            String b = (o.label == null) ? '' : o.label.toLowerCase();
            return a.compareTo(b);
        }
    }

    // ====================== Describe dynamique ======================

    /**
     * Renvoie la description des champs d'un objet. Si fieldApiNames est vide/null,
     * tous les champs accessibles sont renvoyés (utilisé pour lister les champs du
     * dossier Pro__c). Sinon, seuls les champs demandés (champs fixes du catalogue).
     *
     * @param objectApiName API name de l'objet (ex. 'Pro__c', 'CatalogueTarifaire__c')
     * @param fieldApiNames Sous-ensemble de champs à décrire, ou null/empty pour tous
     * @return Liste de descripteurs triée par libellé
     */
    @AuraEnabled(cacheable=true)
    public static List<FieldDescriptorDTO> getObjectFields(String objectApiName, List<String> fieldApiNames) {
        if (String.isBlank(objectApiName)) {
            throw new AuraHandledException('Objet requis');
        }
        Schema.SObjectType sot = Schema.getGlobalDescribe().get(objectApiName);
        if (sot == null) {
            throw new AuraHandledException('Objet inconnu : ' + objectApiName);
        }

        Set<String> wanted = null;
        if (fieldApiNames != null && !fieldApiNames.isEmpty()) {
            wanted = new Set<String>();
            for (String f : fieldApiNames) {
                if (String.isNotBlank(f)) wanted.add(f.toLowerCase());
            }
        }

        Map<String, Schema.SObjectField> fieldMap = sot.getDescribe().fields.getMap();
        List<FieldDescriptorDTO> result = new List<FieldDescriptorDTO>();

        for (String key : fieldMap.keySet()) {
            Schema.DescribeFieldResult dfr = fieldMap.get(key).getDescribe();
            if (!dfr.isAccessible()) continue;
            if (wanted != null && !wanted.contains(key)) continue;

            String dataType = normalizeType(dfr.getType());
            if (dataType == null) continue; // type non exploitable (adresse, géoloc, blob…)

            FieldDescriptorDTO d = new FieldDescriptorDTO();
            d.apiName = dfr.getName();
            d.label = dfr.getLabel();
            d.dataType = dataType;
            d.required = !dfr.isNillable() && dfr.isCreateable() && !dfr.isDefaultedOnCreate();

            if (dataType == 'picklist') {
                d.picklistValues = new List<PicklistEntryDTO>();
                for (Schema.PicklistEntry pe : dfr.getPicklistValues()) {
                    if (pe.isActive()) {
                        d.picklistValues.add(new PicklistEntryDTO(pe.getLabel(), pe.getValue()));
                    }
                }
            } else if (dataType == 'reference') {
                List<Schema.SObjectType> refs = dfr.getReferenceTo();
                if (!refs.isEmpty()) {
                    d.referenceTo = String.valueOf(refs[0]);
                }
            }
            result.add(d);
        }
        result.sort();
        return result;
    }

    /**
     * Normalise un Schema.DisplayType vers une catégorie exploitable par l'UI.
     * Renvoie null pour les types non gérés comme variables de décision.
     */
    private static String normalizeType(Schema.DisplayType t) {
        switch on t {
            when PICKLIST, MULTIPICKLIST { return 'picklist'; }
            when INTEGER, DOUBLE, CURRENCY, PERCENT, LONG { return 'number'; }
            when DATE { return 'date'; }
            when DATETIME { return 'datetime'; }
            when BOOLEAN { return 'boolean'; }
            when REFERENCE { return 'reference'; }
            when STRING, TEXTAREA, EMAIL, PHONE, URL, ID { return 'text'; }
            when else { return null; }
        }
    }

    // ====================== Lecture des lignes ======================

    /**
     * Ligne pour la LISTE : champs fixes + nombre de règles compté côté serveur.
     * Le JSON ParametresFiche__c n'est PAS expédié au client (il peut être lourd,
     * multiplié par le nombre de lignes) : le détail des règles est chargé à la
     * demande via getCatalogueLigne au dépliage d'une ligne.
     */
    public class LigneListeDTO {
        @AuraEnabled public CatalogueTarifaire__c ligne;
        @AuraEnabled public Integer nbRegles;
    }

    @AuraEnabled
    public static List<LigneListeDTO> getCatalogueLignes() {
        List<LigneListeDTO> out = new List<LigneListeDTO>();
        for (CatalogueTarifaire__c c : [
            SELECT Id, Name, FicheCEE__c, TypeIntervenant__c, RoleIntervenant__c, Statut__c,
                   Intervenants__c, Montants_modifiables__c,
                   DateDebutValidite__c, DateFinValidite__c,
                   EcheancePaiement1__c, EcheancePaiement2__c, Paiement__c,
                   RecordTypeId, RecordType.DeveloperName,
                   ParametresFiche__c, LastModifiedDate
            FROM CatalogueTarifaire__c
            WITH USER_MODE
            ORDER BY Name
        ]) {
            LigneListeDTO dto = new LigneListeDTO();
            dto.nbRegles = countRules(c.ParametresFiche__c);
            c.ParametresFiche__c = null; // le JSON reste côté serveur (chargé au dépliage)
            dto.ligne = c;
            out.add(dto);
        }
        return out;
    }

    // Nombre de règles du JSON ParametresFiche__c (0 si vide ou illisible).
    private static Integer countRules(String parametresFiche) {
        if (String.isBlank(parametresFiche)) return 0;
        try {
            Object parsed = JSON.deserializeUntyped(parametresFiche);
            Object rules = ((Map<String, Object>) parsed).get('rules');
            return (rules instanceof List<Object>) ? ((List<Object>) rules).size() : 0;
        } catch (Exception e) {
            return 0;
        }
    }

    @AuraEnabled
    public static CatalogueTarifaire__c getCatalogueLigne(Id recordId) {
        if (recordId == null) {
            throw new AuraHandledException('Identifiant requis');
        }
        List<CatalogueTarifaire__c> rows = [
            SELECT Id, Name, FicheCEE__c, TypeIntervenant__c, RoleIntervenant__c, Statut__c,
                   Intervenants__c, Montants_modifiables__c,
                   DateDebutValidite__c, DateFinValidite__c,
                   EcheancePaiement1__c, EcheancePaiement2__c, echeanceSupp__c, Paiement__c,
                   RecordTypeId, RecordType.DeveloperName,
                   ParametresFiche__c
            FROM CatalogueTarifaire__c
            WHERE Id = :recordId
            WITH USER_MODE
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            throw new AuraHandledException('Ligne de catalogue introuvable');
        }
        return rows[0];
    }

    /**
     * Résout les libellés (Name) des comptes intervenants, pour l'affichage des
     * pills du sélecteur multi-comptes (champ Intervenants__c = IDs concaténés).
     */
    @AuraEnabled(cacheable=true)
    public static List<Account> getAccountsByIds(List<Id> accountIds) {
        if (accountIds == null || accountIds.isEmpty()) {
            return new List<Account>();
        }
        return [
            SELECT Id, Name
            FROM Account
            WHERE Id IN :accountIds
            WITH USER_MODE
        ];
    }

    // ================== Vérification chevauchement (front) ==================

    /**
     * Vérifie (pour le formulaire, avant le passage à l'écran suivant) si une ligne
     * ACTIVE en chevauchement existe déjà pour la même clé (Fiche CEE + Rôle +
     * Intervenant) et une période de validité qui se recoupe. Renvoie le N° de la
     * ligne en conflit, ou null. La règle est de toute façon imposée par le trigger
     * (CatalogueTarifaireTriggerHandler) ; ceci n'est qu'une aide front.
     */
    @AuraEnabled
    public static String verifierChevauchement(Id recordId, Map<String, Object> fields) {
        if (fields == null) return null;
        // La contrainte ne vise que les lignes ACTIVE.
        if (asString(fields.get('Statut__c')) != 'Active') return null;

        // Ensemble des comptes ciblés : IDs concaténés du champ multi Intervenants__c.
        Set<String> comptes = new Set<String>();
        String multi = asString(fields.get('Intervenants__c'));
        if (String.isNotBlank(multi)) {
            for (String part : multi.split(';')) {
                String t = part.trim();
                if (String.isNotBlank(t)) comptes.add(t);
            }
        }

        CatalogueTarifaire__c conflit = CatalogueTarifaireTriggerHandler.premierChevauchement(
            asString(fields.get('FicheCEE__c')),
            asString(fields.get('RoleIntervenant__c')),
            comptes,
            asDate(fields.get('DateDebutValidite__c')),
            asDate(fields.get('DateFinValidite__c')),
            recordId
        );
        return conflit == null ? null : conflit.Name;
    }


    private static String asString(Object o) {
        return o == null ? null : String.valueOf(o);
    }

    private static Date asDate(Object o) {
        if (o == null) return null;
        String s = String.valueOf(o);
        if (String.isBlank(s)) return null;
        try {
            return Date.valueOf(s.length() > 10 ? s.substring(0, 10) : s);
        } catch (Exception e) {
            return null;
        }
    }

    // ====================== Sauvegarde ======================

    /**
     * Crée ou met à jour une ligne de catalogue.
     *
     * @param recordId       Id de la ligne (null pour une création)
     * @param fields         Valeurs des champs fixes (clé = API name)
     * @param parametresFiche JSON des règles de tarification (champ ParametresFiche__c)
     * @return Id de la ligne enregistrée
     */
    /**
     * Record Types disponibles d'un objet (DeveloperName -> Id), pour le sélecteur
     * de type au formulaire et le filtrage de la picklist dépendante echeanceSupp__c.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getRecordTypeIds(String objectApiName) {
        Map<String, String> out = new Map<String, String>();
        Schema.SObjectType sot = Schema.getGlobalDescribe().get(objectApiName);
        if (sot == null) return out;
        for (Schema.RecordTypeInfo rti : sot.getDescribe().getRecordTypeInfos()) {
            if (rti.isAvailable() && !rti.isMaster()) {
                out.put(rti.getDeveloperName(), String.valueOf(rti.getRecordTypeId()));
            }
        }
        return out;
    }

    @AuraEnabled
    public static Id saveCatalogueLigne(Id recordId, Map<String, Object> fields, String parametresFiche, String recordTypeDevName) {
        if (String.isNotBlank(parametresFiche)) {
            try {
                JSON.deserializeUntyped(parametresFiche);
            } catch (Exception e) {
                throw new AuraHandledException('Les paramètres de la fiche ne sont pas un JSON valide.');
            }
        }

        SObject record = (recordId == null)
            ? (SObject) new CatalogueTarifaire__c()
            : (SObject) new CatalogueTarifaire__c(Id = recordId);

        Map<String, Schema.SObjectField> fieldMap =
            CatalogueTarifaire__c.SObjectType.getDescribe().fields.getMap();

        if (fields != null) {
            for (String key : fields.keySet()) {
                String k = key.toLowerCase();
                if (!fieldMap.containsKey(k)) continue;
                Schema.DescribeFieldResult dfr = fieldMap.get(k).getDescribe();
                if (!dfr.isCreateable() && !dfr.isUpdateable()) continue;
                record.put(dfr.getName(), coerceValue(dfr, fields.get(key)));
            }
        }
        record.put('ParametresFiche__c', String.isBlank(parametresFiche) ? null : parametresFiche);

        // Record Type choisi au formulaire (posé uniquement à la création). On ne
        // l'assigne que s'il est DISPONIBLE pour l'utilisateur courant : l'insert se
        // fait en USER_MODE, qui rejette un Record Type non assigné au profil.
        if (recordId == null && String.isNotBlank(recordTypeDevName)) {
            Schema.RecordTypeInfo rti = CatalogueTarifaire__c.SObjectType.getDescribe()
                .getRecordTypeInfosByDeveloperName().get(recordTypeDevName);
            if (rti != null && rti.isAvailable()) record.put('RecordTypeId', rti.getRecordTypeId());
        }

        try {
            if (recordId == null) {
                Database.insert(record, AccessLevel.USER_MODE);
            } else {
                Database.update(record, AccessLevel.USER_MODE);
            }
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        }
        return record.Id;
    }

    /**
     * Convertit une valeur reçue du LWC (souvent String) vers le type Apex du champ.
     */
    private static Object coerceValue(Schema.DescribeFieldResult dfr, Object value) {
        if (value == null || (value instanceof String && String.isBlank((String) value))) {
            return null;
        }
        String s = String.valueOf(value);
        try {
            switch on dfr.getType() {
                when DATE {
                    // Accepte 'yyyy-MM-dd' ou un ISO datetime, on garde la partie date.
                    return Date.valueOf(s.replace('T', ' ').substringBefore(' ').length() == 10
                        ? s.substringBefore('T')
                        : s);
                }
                when DATETIME {
                    return (Datetime) JSON.deserialize('"' + s + '"', Datetime.class);
                }
                when INTEGER, LONG {
                    return Integer.valueOf(Decimal.valueOf(s).intValue());
                }
                when DOUBLE, CURRENCY, PERCENT {
                    return Decimal.valueOf(s);
                }
                when BOOLEAN {
                    return Boolean.valueOf(value);
                }
                when else {
                    return s;
                }
            }
        } catch (Exception e) {
            throw new AuraHandledException('Valeur invalide pour ' + dfr.getLabel() + ' : ' + s);
        }
    }

    // ====================== Suppression ======================

    @AuraEnabled
    public static void deleteCatalogueLigne(Id recordId) {
        if (recordId == null) {
            throw new AuraHandledException('Identifiant requis');
        }
        try {
            Database.delete(new CatalogueTarifaire__c(Id = recordId), AccessLevel.USER_MODE);
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        }
    }
}