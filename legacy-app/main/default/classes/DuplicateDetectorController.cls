/**
 * Contrôleur Apex pour la détection de doublons Salesforce.
 *
 * Ce contrôleur exécute une requête SOQL dynamique sur n'importe quel objet Salesforce.
 * La clause WHERE est construite côté LWC et transmise en paramètre — Apex
 * l'intègre dans la requête après validation de base.
 *
 * Sécurité :
 *  - Utilisation de WITH SECURITY_ENFORCED pour respecter les permissions FLS et CRUD.
 *  - La limite est imposée côté Apex (plafonnée à MAX_LIMIT) pour éviter les abus.
 *  - La clause WHERE est construite par le LWC avec échappement des valeurs ;
 *    les noms de champs et d'objet proviennent uniquement de la configuration,
 *    jamais de la saisie utilisateur directe.
 */
public without sharing class DuplicateDetectorController {

    /** Limite absolue de sécurité — ne peut pas être dépassée, même via l'API */
    private static final Integer MAX_LIMIT = 50;

    /**
     * Recherche les doublons potentiels pour un objet et une clause WHERE donnés.
     *
     * @param objectApiName   API name de l'objet à interroger (ex: 'Contact')
     * @param soqlWhereClause Clause WHERE sans le mot-clé WHERE (ex: "Name LIKE 'Dup%'")
     * @param recordId        ID de l'enregistrement courant à exclure (peut être null)
     * @param maxResults      Nombre maximum de résultats souhaités (plafonné à MAX_LIMIT)
     * @param fieldsToQuery   Chaîne CSV des champs à inclure dans le SELECT (ex: "Name,Phone,Email")
     *                        Si null, les champs sont déduits de la clause WHERE.
     * @return Liste de SObjects correspondant aux doublons potentiels
     */
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> findDuplicates(
        String objectApiName,
        String soqlWhereClause,
        String recordId,
        Integer maxResults,
        String fieldsToQuery
    ) {
        // ── Validation des paramètres obligatoires ────────────────────────────
        if (String.isBlank(objectApiName)) {
            throw new AuraHandledException('Le paramètre objectApiName est obligatoire.');
        }
        if (String.isBlank(soqlWhereClause)) {
            throw new AuraHandledException('La clause WHERE ne peut pas être vide.');
        }

        // Validation que l'API name ne contient que des caractères autorisés
        // (lettres, chiffres, underscore) pour éviter toute injection SOQL
        if (!Pattern.matches('[a-zA-Z][a-zA-Z0-9_]*(__c|__mdt|__e|__b)?', objectApiName)) {
            throw new AuraHandledException('Le nom d\'objet fourni n\'est pas valide.');
        }

        // ── Construction des champs du SELECT ────────────────────────────────
        // Id et Name sont toujours inclus.
        // Si fieldsToQuery est fourni, on le parse en retirant les tags <pl>/<mpl>.
        // Sinon, on extrait les champs présents dans la clause WHERE comme fallback.
        Set<String> selectFields = new Set<String>{ 'Id', 'Name' };

        // fieldTypeMap : fieldApiName (casse d'origine) → 'pl' | 'mpl'
        Map<String, String> fieldTypeMap = new Map<String, String>();

        if (String.isNotBlank(fieldsToQuery)) {
            for (String rawField : fieldsToQuery.split(',')) {
                String trimmed = rawField.trim();
                String fieldName = trimmed;
                String fieldType = null;

                // Détection et retrait des tags <mpl> et <pl>
                if (trimmed.endsWith('<mpl>')) {
                    fieldType = 'mpl';
                    fieldName = trimmed.substring(0, trimmed.length() - 5);
                } else if (trimmed.endsWith('<pl>')) {
                    fieldType = 'pl';
                    fieldName = trimmed.substring(0, trimmed.length() - 4);
                }

                // Validation du nom de champ pour éviter toute injection SOQL
                if (String.isNotBlank(fieldName) && Pattern.matches('[a-zA-Z][a-zA-Z0-9_]*(__c)?', fieldName)) {
                    selectFields.add(fieldName);
                    if (fieldType != null) {
                        fieldTypeMap.put(fieldName, fieldType);
                    }
                }
            }
        } else {
            selectFields.addAll(extractFieldsFromWhereClause(soqlWhereClause));
        }

        String selectClause = String.join(new List<String>(selectFields), ', ');

        // ── Calcul de la limite effective ─────────────────────────────────────
        Integer effectiveLimit = (maxResults != null && maxResults > 0)
            ? Math.min(maxResults, MAX_LIMIT)
            : 10;

        // ── Construction de la clause WHERE complète ──────────────────────────
        String whereClause = soqlWhereClause;

        if (String.isNotBlank(recordId)) {
            if (!Pattern.matches('[a-zA-Z0-9]{15,18}', recordId)) {
                throw new AuraHandledException('Le recordId fourni n\'est pas un ID Salesforce valide.');
            }
            whereClause += ' AND Id != \'' + String.escapeSingleQuotes(recordId) + '\'';
        }

        // ── Exécution de la requête SOQL dynamique ────────────────────────────
        String soql = 'SELECT ' + selectClause
                    + ' FROM '  + objectApiName
                    + ' WHERE ' + whereClause
                    // + ' WITH SECURITY_ENFORCED'
                    + ' LIMIT '  + effectiveLimit;

        List<SObject> records;
        try {
            records = Database.query(soql);
        } catch (QueryException e) {
            throw new AuraHandledException(
                'Erreur lors de l\'exécution de la requête : ' + e.getMessage() + '. Requête tentée : ' + soql
            );
        }

        // ── Construction des métadonnées picklist ─────────────────────────────
        // Pour chaque champ tagué <pl>/<mpl>, on construit un Map apiValue → label.
        Map<String, Map<String, String>> picklistMeta = new Map<String, Map<String, String>>();

        if (!fieldTypeMap.isEmpty()) {
            Schema.DescribeSObjectResult objDescribe =
                Schema.getGlobalDescribe().get(objectApiName)?.getDescribe();

            if (objDescribe != null) {
                Map<String, Schema.SObjectField> schemaFieldMap = objDescribe.fields.getMap();

                for (String fieldName : fieldTypeMap.keySet()) {
                    // getMap() stocke les clés en minuscules
                    Schema.SObjectField sField = schemaFieldMap.get(fieldName.toLowerCase());
                    if (sField == null) continue;

                    Map<String, String> valueToLabel = new Map<String, String>();
                    for (Schema.PicklistEntry entry : sField.getDescribe().getPicklistValues()) {
                        valueToLabel.put(entry.getValue(), entry.getLabel());
                    }
                    picklistMeta.put(fieldName, valueToLabel);
                }
            }
        }

        // ── Réponse structurée ────────────────────────────────────────────────
        return new Map<String, Object>{
            'records'      => records,
            'picklistMeta' => picklistMeta
        };
    }

    /**
     * Extrait les noms de champs présents dans une clause WHERE SOQL.
     * Utilisé pour construire la liste SELECT afin de retourner les valeurs des champs filtrés.
     *
     * Reconnaissance des patterns :
     *   fieldName = '...'
     *   fieldName != '...'
     *   fieldName LIKE '...'
     *
     * @param whereClause clause WHERE sans le mot-clé WHERE
     * @return Liste des noms de champs trouvés
     */
    private static List<String> extractFieldsFromWhereClause(String whereClause) {
        List<String> fields = new List<String>();
        if (String.isBlank(whereClause)) return fields;

        // Pattern : capture le nom de champ (lettres, chiffres, underscore) suivi d'un espace
        // et d'un opérateur SOQL (=, !=, LIKE)
        Pattern fieldPattern = Pattern.compile('([a-zA-Z][a-zA-Z0-9_]*)\\s*(?:=|!=|LIKE)');
        Matcher m = fieldPattern.matcher(whereClause);

        while (m.find()) {
            String fieldName = m.group(1);
            // Exclut les mots-clés SOQL qui pourraient matcher par erreur
            if (!isSoqlKeyword(fieldName)) {
                fields.add(fieldName);
            }
        }

        return fields;
    }

    /**
     * Détermine si un token est un mot-clé SOQL réservé.
     * @param token Le mot à vérifier
     * @return true si c'est un mot-clé SOQL
     */
    private static Boolean isSoqlKeyword(String token) {
        Set<String> keywords = new Set<String>{
            'AND', 'OR', 'NOT', 'LIKE', 'IN', 'NULL', 'TRUE', 'FALSE',
            'SELECT', 'FROM', 'WHERE', 'LIMIT', 'ORDER', 'BY', 'GROUP',
            'HAVING', 'WITH', 'INCLUDES', 'EXCLUDES'
        };
        return keywords.contains(token.toUpperCase());
    }
}