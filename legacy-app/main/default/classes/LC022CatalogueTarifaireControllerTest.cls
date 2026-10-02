/**
 * Tests de LC022CatalogueTarifaireController : describe dynamique, CRUD des
 * lignes de catalogue et validation du JSON ParametresFiche__c.
 *
 * On ne renseigne pas FicheCEE__c / RoleIntervenant__c (value sets globaux dont
 * les valeurs ne sont pas garanties dans l'org de test) : les champs n'étant pas
 * obligatoires, on s'appuie sur les picklists locales connues.
 */
@IsTest
private class LC022CatalogueTarifaireControllerTest {

    private static final String SAMPLE_JSON =
        '{"version":1,"decisionVariables":[{"field":"MPR_SHAB__c","label":"Surface","type":"number","comparison":"interval"}],' +
        '"rules":[{"id":"r1","conditions":{"MPR_SHAB__c":{"comparison":"interval","min":0,"max":90}},' +
        '"montant1":{"mode":"fixed","value":400},"montant2":{"mode":"formula","factor":40,"field":"MPR_SHAB__c"}}]}';

    private static Map<String, Object> sampleFields() {
        return new Map<String, Object>{
            'TypeIntervenant__c' => 'Externe',
            'EcheancePaiement1__c' => 'Au Solde MPR',
            'EcheancePaiement2__c' => '', // exerce la garde « blanc -> null » de coerceValue
            'DateDebutValidite__c' => '2026-01-01',
            'DateFinValidite__c' => '2030-12-31'
        };
    }

    @IsTest
    static void testGetDossierFieldsReturnsAll() {
        Test.startTest();
        List<LC022CatalogueTarifaireController.FieldDescriptorDTO> fields =
            LC022CatalogueTarifaireController.getObjectFields('Pro__c', null);
        Test.stopTest();

        System.Assert.isFalse(fields.isEmpty(), 'Le dossier doit exposer des champs');
        // Tri par libellé : ordre croissant attendu.
        if (fields.size() > 1) {
            System.Assert.isTrue(
                fields[0].label.toLowerCase().compareTo(fields[1].label.toLowerCase()) <= 0,
                'Les champs doivent être triés par libellé'
            );
        }
    }

    @IsTest
    static void testGetCatalogueFieldsSubsetWithPicklist() {
        Test.startTest();
        List<LC022CatalogueTarifaireController.FieldDescriptorDTO> fields =
            LC022CatalogueTarifaireController.getObjectFields(
                'CatalogueTarifaire__c',
                new List<String>{ 'EcheancePaiement1__c', 'DateDebutValidite__c' }
            );
        Test.stopTest();

        System.Assert.areEqual(2, fields.size(), 'Seuls les 2 champs demandés sont décrits');
        Map<String, LC022CatalogueTarifaireController.FieldDescriptorDTO> byApi =
            new Map<String, LC022CatalogueTarifaireController.FieldDescriptorDTO>();
        for (LC022CatalogueTarifaireController.FieldDescriptorDTO d : fields) {
            byApi.put(d.apiName, d);
        }
        System.Assert.areEqual('picklist', byApi.get('EcheancePaiement1__c').dataType);
        System.Assert.isFalse(
            byApi.get('EcheancePaiement1__c').picklistValues.isEmpty(),
            'La picklist doit exposer ses valeurs'
        );
        System.Assert.areEqual('date', byApi.get('DateDebutValidite__c').dataType);
    }

    @IsTest
    static void testGetObjectFieldsUnknownObject() {
        Test.startTest();
        try {
            LC022CatalogueTarifaireController.getObjectFields('Objet_Inexistant__x', null);
            System.Assert.fail('Une exception était attendue pour un objet inconnu');
        } catch (AuraHandledException e) {
            System.Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testInsertUpdateAndRead() {
        Test.startTest();
        Id newId = LC022CatalogueTarifaireController.saveCatalogueLigne(null, sampleFields(), SAMPLE_JSON, 'Standard');
        System.Assert.isNotNull(newId, 'La création doit renvoyer un Id');

        // Lecture liste + détail. La liste renvoie le COMPTE de règles (serveur)
        // mais pas le JSON lui-même (chargé à la demande au dépliage d'une ligne).
        List<LC022CatalogueTarifaireController.LigneListeDTO> all =
            LC022CatalogueTarifaireController.getCatalogueLignes();
        System.Assert.areEqual(1, all.size());
        System.Assert.areEqual(1, all[0].nbRegles, 'SAMPLE_JSON contient 1 règle');
        System.Assert.isNull(all[0].ligne.ParametresFiche__c,
            'Le JSON des règles ne doit pas être expédié à la liste');
        CatalogueTarifaire__c one = LC022CatalogueTarifaireController.getCatalogueLigne(newId);
        System.Assert.areEqual('Externe', one.TypeIntervenant__c);
        System.Assert.areEqual(SAMPLE_JSON, one.ParametresFiche__c);

        // Mise à jour
        Map<String, Object> updated = sampleFields();
        updated.put('EcheancePaiement1__c', 'A la Visite/Previsite');
        Id sameId = LC022CatalogueTarifaireController.saveCatalogueLigne(newId, updated, SAMPLE_JSON, null);
        Test.stopTest();

        System.Assert.areEqual(newId, sameId, 'La mise à jour conserve le même Id');
        CatalogueTarifaire__c reread = LC022CatalogueTarifaireController.getCatalogueLigne(newId);
        System.Assert.areEqual('A la Visite/Previsite', reread.EcheancePaiement1__c);
    }

    @IsTest
    static void testSaveRejectsInvalidDatetime() {
        // DateDebutValidite__c est de type Date : une valeur non parseable
        // doit lever une AuraHandledException (couvre la branche DATE + le catch).
        Test.startTest();
        try {
            LC022CatalogueTarifaireController.saveCatalogueLigne(
                null,
                new Map<String, Object>{ 'DateDebutValidite__c' => 'pas-une-date' },
                null,
                null
            );
            System.Assert.fail('Une date/heure invalide doit lever une exception');
        } catch (AuraHandledException e) {
            System.Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testSaveRejectsInvalidJson() {
        Test.startTest();
        try {
            LC022CatalogueTarifaireController.saveCatalogueLigne(null, sampleFields(), '{not valid json', null);
            System.Assert.fail('Un JSON invalide doit lever une exception');
        } catch (AuraHandledException e) {
            System.Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testDelete() {
        Id newId = LC022CatalogueTarifaireController.saveCatalogueLigne(null, sampleFields(), SAMPLE_JSON, 'Standard');
        Test.startTest();
        LC022CatalogueTarifaireController.deleteCatalogueLigne(newId);
        Test.stopTest();
        System.Assert.areEqual(0, LC022CatalogueTarifaireController.getCatalogueLignes().size());
    }

    @IsTest
    static void testGuardClauses() {
        Test.startTest();
        try {
            LC022CatalogueTarifaireController.getCatalogueLigne(null);
            System.Assert.fail('Id null doit lever une exception');
        } catch (AuraHandledException e) {
            System.Assert.isNotNull(e.getMessage());
        }
        try {
            LC022CatalogueTarifaireController.deleteCatalogueLigne(null);
            System.Assert.fail('Suppression avec Id null doit lever une exception');
        } catch (AuraHandledException e) {
            System.Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    // ----------------------- Méthodes utilitaires du contrôleur -----------------------

    @IsTest
    static void testGetAccountsByIds() {
        // Entrées vides -> liste vide (gardes), sans requête.
        System.Assert.isTrue(
            LC022CatalogueTarifaireController.getAccountsByIds(null).isEmpty(),
            'Liste null -> aucun compte'
        );
        System.Assert.isTrue(
            LC022CatalogueTarifaireController.getAccountsByIds(new List<Id>()).isEmpty(),
            'Liste vide -> aucun compte'
        );

        // Id synthétique (aucun Account inséré -> on n'active pas l'automatisation org de
        // géocodage AccountTriggerHandler.AsyncGetCoordinates) : la requête s'exécute et la
        // ligne est couverte, résultat vide attendu.
        String pfx = Account.SObjectType.getDescribe().getKeyPrefix();
        Test.startTest();
        List<Account> rows = LC022CatalogueTarifaireController.getAccountsByIds(
            new List<Id>{ pfx + '000000000001' });
        Test.stopTest();

        System.Assert.isNotNull(rows, 'La requête doit s\'exécuter même sans correspondance en base');
    }

    @IsTest
    static void testGetRecordTypeIds() {
        Test.startTest();
        Map<String, String> ids = LC022CatalogueTarifaireController.getRecordTypeIds('CatalogueTarifaire__c');
        // Objet inconnu -> map vide (branche sot == null).
        Map<String, String> none = LC022CatalogueTarifaireController.getRecordTypeIds('Objet_Inexistant__x');
        Test.stopTest();

        System.Assert.isNotNull(ids, 'La map des Record Types ne doit pas être nulle');
        System.Assert.isTrue(none.isEmpty(), 'Objet inconnu -> map de Record Types vide');
    }

    @IsTest
    static void testVerifierChevauchementFront() {
        // fields null -> null (garde d'entrée).
        System.Assert.isNull(
            LC022CatalogueTarifaireController.verifierChevauchement(null, null),
            'fields null -> aucun conflit'
        );
        // Statut non Active -> null (la contrainte ne vise que les lignes ACTIVE).
        System.Assert.isNull(
            LC022CatalogueTarifaireController.verifierChevauchement(
                null, new Map<String, Object>{ 'Statut__c' => 'Inactive' }),
            'Statut Inactive -> aucun conflit'
        );

        // Statut Active : exerce le parsing du multi Intervenants__c (dont une part vide)
        // et l'appel à premierChevauchement. Aucune ligne ACTIVE en base -> null attendu.
        String pfx = Account.SObjectType.getDescribe().getKeyPrefix();
        Map<String, Object> fields = new Map<String, Object>{
            'Statut__c' => 'Active',
            'FicheCEE__c' => 'Fiche_Inexistante_X',
            'RoleIntervenant__c' => 'Role_Inexistant_X',
            'Intervenants__c' => pfx + '000000000001; ' + pfx + '000000000002 ; ',
            'DateDebutValidite__c' => '2026-01-01',
            'DateFinValidite__c' => '2026-12-31'
        };
        Test.startTest();
        String conflit = LC022CatalogueTarifaireController.verifierChevauchement(null, fields);
        Test.stopTest();
        System.Assert.isNull(conflit, 'Aucune ligne ACTIVE correspondante -> pas de conflit');
    }

    @IsTest
    static void testCoerceValueNumeriqueEtBooleen() {
        // MontantBase1__c (Currency) et Montants_modifiables__c (Checkbox), reçus en String,
        // exercent les branches numérique et booléenne de coerceValue.
        Map<String, Object> fields = new Map<String, Object>{
            'MontantBase1__c' => '400.50',
            'Montants_modifiables__c' => 'true',
            'DateDebutValidite__c' => '2026-01-01',
            'DateFinValidite__c' => '2030-12-31'
        };
        Test.startTest();
        Id id = LC022CatalogueTarifaireController.saveCatalogueLigne(null, fields, null, 'Standard');
        Test.stopTest();

        System.Assert.isNotNull(id, 'La ligne doit être créée');
        CatalogueTarifaire__c row = [
            SELECT MontantBase1__c, Montants_modifiables__c
            FROM CatalogueTarifaire__c WHERE Id = :id
        ];
        System.Assert.areEqual(400.50, row.MontantBase1__c, 'Le montant Currency doit être coercé depuis la String');
        System.Assert.areEqual(true, row.Montants_modifiables__c, 'Le booléen doit être coercé depuis la String');
    }
}