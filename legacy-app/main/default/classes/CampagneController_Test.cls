@isTest
private class CampagneController_Test {

    /**
     * Mock HTTP générique : répond 200 OK avec un tableau JSON de coordonnées.
     * Nécessaire car l'insertion du Compte déclenche le trigger Account
     * (AccountTriggerHandler.AsyncGetCoordinates) qui appelle l'API de géocodage.
     * Sans ce mock, les tests échouent avec « Methods defined as test methods
     * do not support Web service callouts ».
     */
    private class MockHTTP200 implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('[{"lat":"48.8566","lon":"2.3522"}]');
            res.setHeader('Content-Type', 'application/json');
            return res;
        }
    }

    /** Construit un RestContext (request + response) prêt pour un POST. */
    private static void setupRestContext(String secret, String body) {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/campagne/';
        req.httpMethod = 'POST';
        if (secret != null) {
            req.addParameter('secret', secret);
        }
        if (body != null) {
            req.requestBody = Blob.valueOf(body);
        }
        RestContext.request = req;
        RestContext.response = new RestResponse();
    }

    private static Map<String, Object> parseResponse() {
        Blob b = RestContext.response.responseBody;
        String s = (b != null) ? b.toString() : '{}';
        return (Map<String, Object>) JSON.deserializeUntyped(s);
    }

    private static String validPayload(String email) {
        return JSON.serialize(new Map<String, Object>{
            'nom' => 'Dupont',
            'prenom' => 'Jean',
            'email' => email,
            'telephone' => '0612345678',
            'fiche' => 'RESIDENTIEL_REGIES_-_TH171',
            'acces_reduit' => true,
            'source' => 'cee-apporteurs'
        });
    }

    @isTest
    static void testCreateCampaignSuccess() {
        setupRestContext(Label.CAMPAGNE_API_TOKEN, validPayload('jean.success@example.com'));

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHTTP200());
        CampagneController.createCampaignFromSite();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode,
            'Un payload valide doit répondre 200. Réponse: '
            + (RestContext.response.responseBody != null ? RestContext.response.responseBody.toString() : 'null'));
        Map<String, Object> resp = parseResponse();
        System.assertEquals(true, resp.get('success'), 'La réponse doit indiquer success=true.');
        System.assert(resp.get('redirect_url') != null, 'La réponse doit contenir une redirect_url.');
        System.assert(String.valueOf(resp.get('redirect_url')).contains('?c__code='),
            'La redirect_url doit contenir le token.');

        Campaign c = [
            SELECT Name, Status, IsActive, EstREGIE__c, AvoirAccesCEE__c, ParentId,
                   PeutCreerREGIE__c, Email__c, Telephone__c, ProduitsDisponibles__c,
                   AccesReduit__c, Source__c, CampaignToken__c, StartDate
            FROM Campaign
            WHERE Email__c = 'jean.success@example.com'
            LIMIT 1
        ];
        // Champs standards codés en dur
        System.assertEquals(true, c.EstREGIE__c, 'EstREGIE__c doit être true.');
        System.assertEquals('In Progress', c.Status, 'Status doit être In Progress.');
        System.assertEquals(true, c.IsActive, 'IsActive doit être true.');
        System.assertEquals(false, c.AvoirAccesCEE__c, 'AvoirAccesCEE__c doit être false.');
        System.assertEquals(null, c.ParentId, 'ParentId doit être null.');
        System.assertEquals(false, c.PeutCreerREGIE__c, 'PeutCreerREGIE__c doit être false.');
        System.assertEquals(System.today(), c.StartDate, 'StartDate doit être aujourd\'hui.');
        // Champs issus de l'API
        System.assertEquals('Dupont Jean', c.Name, 'Name doit être « nom prenom ».');
        System.assertEquals('RESIDENTIEL_REGIES_-_TH171', c.ProduitsDisponibles__c, 'fiche -> ProduitsDisponibles__c.');
        System.assertEquals(true, c.AccesReduit__c, 'acces_reduit -> AccesReduit__c.');
        System.assertEquals('cee-apporteurs', c.Source__c, 'source -> Source__c.');
        System.assertNotEquals(null, c.CampaignToken__c, 'Le token doit être généré.');

        // Le compte lié est créé en « best-effort » : createAccountForCampaign avale ses
        // erreurs, donc selon la config de l'org (Person Account activé, règles de validation)
        // l'insert peut échouer sans bloquer la campagne. On ne vérifie son nom que s'il existe.
        List<Account> comptes = [SELECT Id, Name FROM Account WHERE Acces_REGIE__c = :c.Id];
        if (!comptes.isEmpty()) {
            System.assertEquals('REGIE- Dupont Jean', comptes[0].Name,
                'Le nom du compte doit être « REGIE- {Name} ».');
        }
    }

    @isTest
    static void testUnauthorized() {
        setupRestContext('MAUVAIS_SECRET', validPayload('jean.unauth@example.com'));

        Test.startTest();
        CampagneController.createCampaignFromSite();
        Test.stopTest();

        System.assertEquals(401, RestContext.response.statusCode, 'Un secret invalide doit répondre 401.');
        System.assert(parseResponse().get('error') != null, 'La réponse 401 doit contenir un message d\'erreur.');
    }

    @isTest
    static void testMissingSecret() {
        setupRestContext(null, validPayload('jean.nosecret@example.com'));

        Test.startTest();
        CampagneController.createCampaignFromSite();
        Test.stopTest();

        System.assertEquals(401, RestContext.response.statusCode, 'Un secret absent doit répondre 401.');
    }

    @isTest
    static void testEmptyBody() {
        setupRestContext(Label.CAMPAGNE_API_TOKEN, '');

        Test.startTest();
        CampagneController.createCampaignFromSite();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode, 'Un corps vide doit répondre 400.');
    }

    @isTest
    static void testInvalidJson() {
        setupRestContext(Label.CAMPAGNE_API_TOKEN, '{ ceci n\'est pas du json ');

        Test.startTest();
        CampagneController.createCampaignFromSite();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode, 'Un JSON invalide doit répondre 400.');
    }

    @isTest
    static void testMissingEmail() {
        String payload = JSON.serialize(new Map<String, Object>{
            'nom' => 'Dupont',
            'prenom' => 'Jean',
            'fiche' => 'RESIDENTIEL_REGIES_-_TH171'
        });
        setupRestContext(Label.CAMPAGNE_API_TOKEN, payload);

        Test.startTest();
        CampagneController.createCampaignFromSite();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode, 'Un email manquant doit répondre 400.');
    }

    @isTest
    static void testMissingName() {
        String payload = JSON.serialize(new Map<String, Object>{
            'email' => 'noname@example.com',
            'fiche' => 'RESIDENTIEL_REGIES_-_TH171'
        });
        setupRestContext(Label.CAMPAGNE_API_TOKEN, payload);

        Test.startTest();
        CampagneController.createCampaignFromSite();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode, 'Nom et prénom manquants doivent répondre 400.');
    }

    @isTest
    static void testExistingRegieRedirect() {
        // REGIE existante (non partenaire) -> 200 + status 'existing_regie' (le front redirige vers la connexion).
        insert new Campaign(
            Name = 'Regie Existante',
            Status = 'In Progress',
            StartDate = Date.today(),
            IsActive = true,
            EstREGIE__c = true,
            Email__c = 'regie@example.com'
        );

        setupRestContext(Label.CAMPAGNE_API_TOKEN, validPayload('regie@example.com'));

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHTTP200());
        CampagneController.createCampaignFromSite();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode, 'Régie existante doit répondre 200.');
        System.assertEquals('existing_regie', parseResponse().get('status'), 'Le statut doit être existing_regie.');
    }

    @isTest
    static void testExistingPartenaireResendsAccess() {
        // Partenaire existant (AccesReduit + Source cee-apporteurs) -> 200 + status 'already_partner' + message.
        insert new Campaign(
            Name = 'Partenaire Existant',
            Status = 'In Progress',
            StartDate = Date.today(),
            IsActive = true,
            EstREGIE__c = true,
            AccesReduit__c = true,
            Source__c = 'cee-apporteurs',
            Email__c = 'partenaire@example.com'
        );

        setupRestContext(Label.CAMPAGNE_API_TOKEN, validPayload('partenaire@example.com'));

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHTTP200());
        CampagneController.createCampaignFromSite();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode, 'Partenaire existant doit répondre 200.');
        Map<String, Object> resp = parseResponse();
        System.assertEquals('already_partner', resp.get('status'), 'Le statut doit être already_partner.');
        System.assert(resp.get('message') != null, 'Un message doit être renvoyé.');
    }

    @isTest
    static void testDmlErrorReturns400() {
        // Couvre la branche DmlException -> 400 de manière DÉTERMINISTE (indépendante de la
        // config de l'org) : un Name > 80 caractères (limite standard de Campaign.Name)
        // provoque un STRING_TOO_LONG à l'insert.
        // NB : en production, une valeur invalide de « fiche »/« source » (picklists
        // restreintes) déclenche exactement la même branche.
        String longNom = 'A'.repeat(100);
        String payload = JSON.serialize(new Map<String, Object>{
            'nom' => longNom,
            'prenom' => 'Jean',
            'email' => 'dmlerror@example.com',
            'fiche' => 'RESIDENTIEL_REGIES_-_TH171'
        });
        setupRestContext(Label.CAMPAGNE_API_TOKEN, payload);

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHTTP200());
        CampagneController.createCampaignFromSite();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode,
            'Une erreur DML (Name trop long) doit répondre 400.');
        System.assert(parseResponse().get('error') != null,
            'La réponse 400 doit contenir un message d\'erreur.');
    }
}