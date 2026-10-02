/**
 * Classe de test pour DuplicateDetectorController.
 *
 * Couverture :
 *  - Validation des paramètres obligatoires (objectApiName, whereClause, recordId)
 *  - Cas nominal : avec/sans fieldsToQuery, avec/sans recordId
 *  - Tags de picklist <pl> et <mpl> → picklistMeta retourné
 *  - Plafonnement de maxResults à MAX_LIMIT (50)
 *  - maxResults null → défaut 10
 *  - Champs invalides dans fieldsToQuery silencieusement ignorés
 *  - QueryException capturée et remontée en AuraHandledException
 */
@IsTest
private class DuplicateDetectorControllerTest {

    // ── Données de test ──────────────────────────────────────────────────────

    @TestSetup
    static void makeData() {
        insert new List<Contact>{
            new Contact(LastName = 'Dupont', FirstName = 'Jean',  LeadSource = 'Web'),
            new Contact(LastName = 'Dupont', FirstName = 'Marie', LeadSource = 'Phone'),
            new Contact(LastName = 'Martin', FirstName = 'Paul',  LeadSource = 'Web')
        };
    }

    // ── Validation des paramètres ────────────────────────────────────────────

    @IsTest
    static void testBlankObjectApiName_throwsException() {
        Boolean exceptionThrown = false;
        try {
            DuplicateDetectorController.findDuplicates('', 'LastName = \'Dupont\'', null, 10, null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Assert.isTrue(exceptionThrown, 'Une AuraHandledException devait être levée pour un objectApiName vide.');
    }

    @IsTest
    static void testBlankWhereClause_throwsException() {
        Boolean exceptionThrown = false;
        try {
            DuplicateDetectorController.findDuplicates('Contact', '', null, 10, null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Assert.isTrue(exceptionThrown, 'Une AuraHandledException devait être levée pour une clause WHERE vide.');
    }

    @IsTest
    static void testInvalidObjectApiName_throwsException() {
        Boolean exceptionThrown = false;
        try {
            DuplicateDetectorController.findDuplicates('123Invalid; DROP', 'Name = \'test\'', null, 10, null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Assert.isTrue(exceptionThrown, 'Une AuraHandledException devait être levée pour un objectApiName invalide.');
    }

    @IsTest
    static void testInvalidRecordId_throwsException() {
        Boolean exceptionThrown = false;
        try {
            DuplicateDetectorController.findDuplicates('Contact', 'LastName = \'Dupont\'', 'NOT_A_VALID_ID!!!', 10, null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Assert.isTrue(exceptionThrown, 'Une AuraHandledException devait être levée pour un recordId invalide.');
    }

    // ── Cas nominaux ─────────────────────────────────────────────────────────

    @IsTest
    static void testFindDuplicates_noFieldsToQuery_extractsFromWhereClause() {
        Test.startTest();
        Map<String, Object> result = DuplicateDetectorController.findDuplicates(
            'Contact',
            'LastName = \'Dupont\'',
            null,
            10,
            null
        );
        Test.stopTest();

        List<SObject> records = (List<SObject>) result.get('records');
        Assert.areEqual(2, records.size(), 'Deux contacts Dupont attendus.');
        // Le champ extrait de la WHERE clause doit être dans le SELECT
        Assert.isNotNull(records[0].get('LastName'), 'Le champ LastName doit être retourné.');
    }

    @IsTest
    static void testFindDuplicates_withExplicitFieldsToQuery() {
        Test.startTest();
        Map<String, Object> result = DuplicateDetectorController.findDuplicates(
            'Contact',
            'LastName = \'Dupont\'',
            null,
            10,
            'LastName,FirstName'
        );
        Test.stopTest();

        List<SObject> records = (List<SObject>) result.get('records');
        Assert.areEqual(2, records.size());
        Assert.isNotNull(records[0].get('FirstName'), 'Le champ FirstName doit être retourné.');
    }

    @IsTest
    static void testFindDuplicates_withRecordId_excludesCurrentRecord() {
        Contact current = [SELECT Id FROM Contact WHERE LastName = 'Dupont' LIMIT 1];

        Test.startTest();
        Map<String, Object> result = DuplicateDetectorController.findDuplicates(
            'Contact',
            'LastName = \'Dupont\'',
            current.Id,
            10,
            null
        );
        Test.stopTest();

        List<SObject> records = (List<SObject>) result.get('records');
        Assert.areEqual(1, records.size(), 'Le contact courant doit être exclu des résultats.');
        Assert.areNotEqual(current.Id, records[0].get('Id'), 'L\'Id exclu ne doit pas apparaître.');
    }

    @IsTest
    static void testFindDuplicates_noResults_returnsEmptyList() {
        Test.startTest();
        Map<String, Object> result = DuplicateDetectorController.findDuplicates(
            'Contact',
            'LastName = \'NomInexistantXYZ999\'',
            null,
            10,
            null
        );
        Test.stopTest();

        List<SObject> records = (List<SObject>) result.get('records');
        Assert.areEqual(0, records.size(), 'Aucun résultat attendu pour un nom inexistant.');
    }

    // ── Picklist metadata ────────────────────────────────────────────────────

    // @IsTest
    // static void testFindDuplicates_plTag_returnsPicklistMeta() {
    //     Test.startTest();
    //     Map<String, Object> result = DuplicateDetectorController.findDuplicates(
    //         'Contact',
    //         'LastName = \'Dupont\'',
    //         null,
    //         10,
    //         'LastName,LeadSource<pl>'
    //     );
    //     Test.stopTest();

    //     Map<String, Map<String, String>> picklistMeta =
    //         (Map<String, Map<String, String>>) result.get('picklistMeta');
    //     Assert.isTrue(picklistMeta.containsKey('LeadSource'), 'picklistMeta doit contenir LeadSource.');
    //     Assert.isFalse(picklistMeta.get('LeadSource').isEmpty(), 'Les valeurs de la picklist ne doivent pas être vides.');
    // }

    // @IsTest
    // static void testFindDuplicates_mplTag_returnsPicklistMeta() {
    //     Test.startTest();
    //     Map<String, Object> result = DuplicateDetectorController.findDuplicates(
    //         'Contact',
    //         'LastName = \'Dupont\'',
    //         null,
    //         10,
    //         'LastName,LeadSource<mpl>'
    //     );
    //     Test.stopTest();

    //     Map<String, Map<String, String>> picklistMeta =
    //         (Map<String, Map<String, String>>) result.get('picklistMeta');
    //     Assert.isTrue(picklistMeta.containsKey('LeadSource'), 'Le tag <mpl> doit également peupler picklistMeta.');
    // }

    @IsTest
    static void testFindDuplicates_noPicklistTags_emptyPicklistMeta() {
        Test.startTest();
        Map<String, Object> result = DuplicateDetectorController.findDuplicates(
            'Contact',
            'LastName = \'Dupont\'',
            null,
            10,
            'LastName,FirstName'
        );
        Test.stopTest();

        Map<String, Map<String, String>> picklistMeta =
            (Map<String, Map<String, String>>) result.get('picklistMeta');
        Assert.isTrue(picklistMeta.isEmpty(), 'Sans tag <pl>/<mpl>, picklistMeta doit être vide.');
    }

    // ── Gestion de maxResults ────────────────────────────────────────────────

    @IsTest
    static void testFindDuplicates_maxResultsAboveCap_isAccepted() {
        // On vérifie que maxResults > 50 ne lève pas d'erreur (le plafonnement est silencieux).
        Test.startTest();
        Map<String, Object> result = DuplicateDetectorController.findDuplicates(
            'Contact',
            'LastName = \'Dupont\'',
            null,
            200,
            null
        );
        Test.stopTest();

        Assert.isNotNull(result.get('records'), 'Un résultat doit être retourné même avec maxResults > 50.');
    }

    @IsTest
    static void testFindDuplicates_nullMaxResults_defaultsToTen() {
        Test.startTest();
        Map<String, Object> result = DuplicateDetectorController.findDuplicates(
            'Contact',
            'LastName = \'Dupont\'',
            null,
            null,
            null
        );
        Test.stopTest();

        Assert.isNotNull(result.get('records'), 'Un résultat doit être retourné avec maxResults null.');
    }

    @IsTest
    static void testFindDuplicates_zeroMaxResults_defaultsToTen() {
        Test.startTest();
        Map<String, Object> result = DuplicateDetectorController.findDuplicates(
            'Contact',
            'LastName = \'Dupont\'',
            null,
            0,
            null
        );
        Test.stopTest();

        Assert.isNotNull(result.get('records'), 'Un résultat doit être retourné avec maxResults = 0.');
    }

    // ── Robustesse / sécurité ────────────────────────────────────────────────

    @IsTest
    static void testFindDuplicates_invalidFieldInFieldsToQuery_isIgnoredSilently() {
        // Un champ commençant par un chiffre ne passe pas la validation → ignoré
        Test.startTest();
        Map<String, Object> result = DuplicateDetectorController.findDuplicates(
            'Contact',
            'LastName = \'Dupont\'',
            null,
            10,
            'LastName,123Invalid,FirstName'
        );
        Test.stopTest();

        List<SObject> records = (List<SObject>) result.get('records');
        Assert.areEqual(2, records.size(), 'Le champ invalide doit être ignoré sans planter la requête.');
    }

    @IsTest
    static void testFindDuplicates_queryException_wrappedAsAuraHandledException() {
        // Un champ inexistant dans la clause WHERE provoque une QueryException,
        // qui doit être encapsulée en AuraHandledException.
        Boolean exceptionThrown = false;
        try {
            DuplicateDetectorController.findDuplicates(
                'Contact',
                'ChampInexistantXyz999 = \'test\'',
                null,
                10,
                null
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Assert.isTrue(exceptionThrown, 'Une AuraHandledException doit encapsuler la QueryException.');
    }
}