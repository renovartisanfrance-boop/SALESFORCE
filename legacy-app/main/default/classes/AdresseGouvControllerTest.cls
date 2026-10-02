/**
 * Tests unitaires de AdresseGouvController. Tous les callouts sont mockés via
 * HttpCalloutMock ; aucune donnée SObject n'est nécessaire (le contrôleur ne fait
 * ni SOQL ni DML), donc pas de TestDataFactory ni de @TestSetup.
 */
@isTest
private class AdresseGouvControllerTest {

    /** Réponse type de l'API BAN : une adresse précise + une commune. */
    private static final String BAN_JSON =
        '{"type":"FeatureCollection","features":[' +
            '{"type":"Feature",' +
             '"geometry":{"type":"Point","coordinates":[2.290084,49.897442]},' +
             '"properties":{"label":"8 Boulevard du Port 80000 Amiens","id":"80021_6590_00008",' +
                           '"type":"housenumber","name":"8 Boulevard du Port","postcode":"80000",' +
                           '"citycode":"80021","city":"Amiens"}},' +
            '{"type":"Feature",' +
             '"geometry":{"type":"Point","coordinates":[2.3522,48.8566]},' +
             '"properties":{"label":"Paris","id":"75056","type":"municipality","name":"Paris",' +
                           '"postcode":"75001","citycode":"75056","city":"Paris"}}' +
        '],"limit":8}';

    /** Mock configurable : rejoue un statut/corps donnés et capture la dernière requête. */
    private class BanApiMock implements HttpCalloutMock {
        Integer statusCode;
        String body;
        Boolean throwCalloutException = false;
        HttpRequest lastRequest;

        BanApiMock(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }

        public HttpResponse respond(HttpRequest request) {
            this.lastRequest = request;
            if (throwCalloutException) {
                CalloutException calloutError = new CalloutException();
                calloutError.setMessage('Read timed out');
                throw calloutError;
            }
            HttpResponse response = new HttpResponse();
            response.setStatusCode(statusCode);
            response.setBody(body);
            return response;
        }
    }

    // ------------------------------------------------------------------
    // Cas nominal
    // ------------------------------------------------------------------

    @isTest
    static void shouldMapSuggestions_WhenApiReturns200() {
        // Given
        Test.setMock(HttpCalloutMock.class, new BanApiMock(200, BAN_JSON));

        // When
        Test.startTest();
        List<AdresseGouvController.Suggestion> resultats =
            AdresseGouvController.rechercherAdresse('8 boulevard du port amiens');
        Test.stopTest();

        // Then
        Assert.areEqual(2, resultats.size(), 'Les deux features doivent être mappées');
        AdresseGouvController.Suggestion premiere = resultats[0];
        Assert.areEqual('80021_6590_00008', premiere.id, 'L\'id doit être mappé');
        Assert.areEqual('8 Boulevard du Port 80000 Amiens', premiere.label, 'Le label doit être mappé');
        Assert.areEqual('8 Boulevard du Port', premiere.street, 'properties.name doit alimenter street');
        Assert.areEqual('80000', premiere.postalCode, 'properties.postcode doit alimenter postalCode');
        Assert.areEqual('Amiens', premiere.city, 'properties.city doit alimenter city');
        Assert.areEqual('80021', premiere.citycode, 'Le code INSEE doit être mappé');
        Assert.areEqual('housenumber', premiere.typeAdresse, 'Le type d\'adresse doit être mappé');
        Assert.areEqual('France', premiere.country, 'Le pays doit toujours valoir France');
        Assert.areEqual(49.897442, premiere.latitude, 'La latitude est la 2e coordonnée');
        Assert.areEqual(2.290084, premiere.longitude, 'La longitude est la 1re coordonnée');
    }

    @isTest
    static void shouldNotSetStreet_WhenTypeIsMunicipality() {
        // Given
        Test.setMock(HttpCalloutMock.class, new BanApiMock(200, BAN_JSON));

        // When
        Test.startTest();
        List<AdresseGouvController.Suggestion> resultats =
            AdresseGouvController.rechercherAdresse('paris');
        Test.stopTest();

        // Then
        AdresseGouvController.Suggestion commune = resultats[1];
        Assert.areEqual('municipality', commune.typeAdresse, 'La 2e feature est une commune');
        Assert.isNull(commune.street, 'Sur une commune, « name » est la ville : street doit rester vide');
        Assert.areEqual('Paris', commune.city, 'La ville doit rester renseignée');
    }

    @isTest
    static void shouldBuildEncodedEndpoint_WhenQueryHasSpecialChars() {
        // Given
        BanApiMock mock = new BanApiMock(200, BAN_JSON);
        Test.setMock(HttpCalloutMock.class, mock);

        // When
        Test.startTest();
        AdresseGouvController.rechercherAdresse('  8 boulevard du port  ');
        Test.stopTest();

        // Then
        String endpoint = mock.lastRequest.getEndpoint();
        Assert.isTrue(endpoint.startsWith('https://api-adresse.data.gouv.fr/search/?q='),
            'L\'endpoint doit pointer vers la BAN : ' + endpoint);
        Assert.isTrue(endpoint.contains('8+boulevard+du+port'),
            'La requête doit être URL-encodée et trimée : ' + endpoint);
        Assert.isTrue(endpoint.contains('limit=8'), 'La limite doit être passée : ' + endpoint);
        Assert.isTrue(endpoint.contains('autocomplete=1'), 'Le mode autocomplete doit être activé : ' + endpoint);
        Assert.areEqual('GET', mock.lastRequest.getMethod(), 'La méthode doit être GET');
    }

    // ------------------------------------------------------------------
    // Court-circuit : aucun callout ne doit partir
    // ------------------------------------------------------------------
    // Volontairement SANS Test.setMock : si un callout partait, le test échouerait
    // sur « You have uncommitted work pending » / « Methods defined as TestMethod
    // do not support Web service callouts ». C'est la preuve du court-circuit.

    @isTest
    static void shouldReturnEmpty_WhenQueryTooShort() {
        Test.startTest();
        List<AdresseGouvController.Suggestion> resultats = AdresseGouvController.rechercherAdresse('ab');
        Test.stopTest();

        Assert.isTrue(resultats.isEmpty(), 'Moins de 3 caractères : aucun callout, liste vide');
    }

    @isTest
    static void shouldReturnEmpty_WhenQueryIsBlank() {
        Test.startTest();
        List<AdresseGouvController.Suggestion> resultats = AdresseGouvController.rechercherAdresse('   ');
        Test.stopTest();

        Assert.isTrue(resultats.isEmpty(), 'Requête vide : aucun callout, liste vide');
    }

    @isTest
    static void shouldReturnEmpty_WhenQueryIsNull() {
        Test.startTest();
        List<AdresseGouvController.Suggestion> resultats = AdresseGouvController.rechercherAdresse(null);
        Test.stopTest();

        Assert.isTrue(resultats.isEmpty(), 'Requête null : aucun callout, liste vide');
    }

    // ------------------------------------------------------------------
    // Dégradation
    // ------------------------------------------------------------------

    @isTest
    static void shouldReturnEmpty_WhenApiReturns500() {
        // Given
        Test.setMock(HttpCalloutMock.class, new BanApiMock(500, '{"error":"boom"}'));

        // When
        Test.startTest();
        List<AdresseGouvController.Suggestion> resultats =
            AdresseGouvController.rechercherAdresse('amiens');
        Test.stopTest();

        // Then
        Assert.isTrue(resultats.isEmpty(), 'Une erreur serveur ne doit pas casser la fiche');
    }

    @isTest
    static void shouldReturnEmpty_WhenBodyHasNoFeatures() {
        // Given
        Test.setMock(HttpCalloutMock.class, new BanApiMock(200, '{}'));

        // When
        Test.startTest();
        List<AdresseGouvController.Suggestion> resultats =
            AdresseGouvController.rechercherAdresse('amiens');
        Test.stopTest();

        // Then
        Assert.isTrue(resultats.isEmpty(), 'Un corps sans « features » doit rendre une liste vide');
    }

    @isTest
    static void shouldThrowAuraHandledException_WhenCalloutFails() {
        // Given
        BanApiMock mock = new BanApiMock(200, BAN_JSON);
        mock.throwCalloutException = true;
        Test.setMock(HttpCalloutMock.class, mock);

        // When
        Boolean exceptionLevee = false;
        Test.startTest();
        try {
            AdresseGouvController.rechercherAdresse('amiens');
        } catch (AuraHandledException e) {
            exceptionLevee = true;
        }
        Test.stopTest();

        // Then
        Assert.isTrue(exceptionLevee, 'Un échec de callout doit remonter une AuraHandledException au LWC');
    }
}