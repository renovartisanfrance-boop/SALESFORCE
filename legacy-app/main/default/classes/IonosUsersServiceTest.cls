/**
 * Tests unitaires de IonosUsersService. Tous les callouts sont mockés via HttpCalloutMock ;
 * aucune donnée SObject n'est nécessaire (le service ne fait ni SOQL ni DML),
 * donc pas de TestDataFactory ni de @TestSetup.
 */
@isTest
private class IonosUsersServiceTest {

    private static final String USER_JSON =
        '{"id":7,"login":"jean.dupont","email":"jean@example.com",' +
        '"redirect_url":"https://exemple.com","first_login":1,' +
        '"created_at":"2026-07-06 10:00:00","updated_at":"2026-07-06 11:00:00"}';

    /** Mock configurable : rejoue un statut/corps donnés et capture la dernière requête. */
    private class IonosApiMock implements HttpCalloutMock {
        Integer statusCode;
        String body;
        Boolean throwCalloutException = false;
        HttpRequest lastRequest;

        IonosApiMock(Integer statusCode, String body) {
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
    // getUsers
    // ------------------------------------------------------------------

    @isTest
    static void shouldReturnMappedUsers_WhenListSucceeds() {
        // Given
        String listJson = '{"users":[' + USER_JSON + '],"page":1,"page_size":25,"total":1,"total_pages":1}';
        IonosApiMock mock = new IonosApiMock(200, listJson);
        Test.setMock(HttpCalloutMock.class, mock);

        // When
        Test.startTest();
        IonosUsersService.UserListResult result = IonosUsersService.getUsers('', 1, 25);
        Test.stopTest();

        // Then
        Assert.areEqual(1, result.users.size(), 'Un seul utilisateur doit être retourné');
        IonosUsersService.UserDTO user = result.users[0];
        Assert.areEqual(7, user.id, 'L\'id doit être mappé');
        Assert.areEqual('jean.dupont', user.login, 'Le login doit être mappé');
        Assert.areEqual('jean@example.com', user.email, 'L\'email doit être mappé');
        Assert.areEqual('https://exemple.com', user.redirectUrl, 'redirect_url doit être mappé en camelCase');
        Assert.isTrue(user.firstLogin, 'first_login=1 doit devenir true');
        Assert.areEqual(1, result.total, 'Le total doit être mappé');
        Assert.areEqual(1, result.totalPages, 'total_pages doit être mappé');
    }

    @isTest
    static void shouldEncodeSearchTerm_WhenSearchProvided() {
        // Given
        String listJson = '{"users":[],"page":1,"page_size":25,"total":0,"total_pages":0}';
        IonosApiMock mock = new IonosApiMock(200, listJson);
        Test.setMock(HttpCalloutMock.class, mock);

        // When
        Test.startTest();
        IonosUsersService.getUsers('jean dupont', 1, 25);
        Test.stopTest();

        // Then
        Assert.isTrue(mock.lastRequest.getEndpoint().contains('search=jean+dupont'),
            'Le terme de recherche doit être encodé dans l\'URL : ' + mock.lastRequest.getEndpoint());
    }

    @isTest
    static void shouldClampPageSize_WhenAboveMaximum() {
        // Given
        String listJson = '{"users":[],"page":1,"page_size":100,"total":0,"total_pages":0}';
        IonosApiMock mock = new IonosApiMock(200, listJson);
        Test.setMock(HttpCalloutMock.class, mock);

        // When
        Test.startTest();
        IonosUsersService.getUsers(null, null, 500);
        Test.stopTest();

        // Then
        Assert.isTrue(mock.lastRequest.getEndpoint().contains('page_size=100'),
            'La taille de page doit être plafonnée à 100 : ' + mock.lastRequest.getEndpoint());
        Assert.isTrue(mock.lastRequest.getEndpoint().contains('page=1'),
            'La page nulle doit retomber à 1 : ' + mock.lastRequest.getEndpoint());
    }

    // ------------------------------------------------------------------
    // createUser
    // ------------------------------------------------------------------

    @isTest
    static void shouldReturnCreatedUser_WhenCreateSucceeds() {
        // Given
        IonosApiMock mock = new IonosApiMock(201, '{"user":' + USER_JSON + '}');
        Test.setMock(HttpCalloutMock.class, mock);

        // When
        Test.startTest();
        IonosUsersService.UserDTO user = IonosUsersService.createUser(
            'jean.dupont', 'jean@example.com', 'Temp123!', 'https://exemple.com');
        Test.stopTest();

        // Then
        Assert.areEqual(7, user.id, 'L\'utilisateur créé doit être retourné');
        Assert.isTrue(mock.lastRequest.getEndpoint().endsWith('/users_create.php'),
            'L\'endpoint de création doit être appelé');
        Map<String, Object> sentPayload =
            (Map<String, Object>) JSON.deserializeUntyped(mock.lastRequest.getBody());
        Assert.areEqual('jean@example.com', sentPayload.get('email'), 'L\'email doit être envoyé');
        Assert.areEqual('Temp123!', sentPayload.get('password'), 'Le mot de passe doit être envoyé');
    }

    @isTest
    static void shouldThrowError_WhenCreateWithDuplicateEmail() {
        // Given
        IonosApiMock mock = new IonosApiMock(409, '{"error":"Cet email existe déjà."}');
        Test.setMock(HttpCalloutMock.class, mock);

        // When / Then
        Test.startTest();
        try {
            IonosUsersService.createUser('jean', 'jean@example.com', 'Temp123!', null);
            Assert.fail('Une AuraHandledException était attendue sur le 409');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('existe déjà'),
                'Le message d\'erreur de l\'API doit remonter : ' + e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void shouldThrowError_WhenCreateWithBlankFields() {
        // Given — aucun mock : la validation doit échouer avant le callout

        // When / Then
        Test.startTest();
        try {
            IonosUsersService.createUser('', 'jean@example.com', '', null);
            Assert.fail('Une AuraHandledException était attendue sur champs vides');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('obligatoires'),
                'Le message doit indiquer les champs obligatoires : ' + e.getMessage());
        }
        Test.stopTest();
    }

    // ------------------------------------------------------------------
    // updateUser
    // ------------------------------------------------------------------

    @isTest
    static void shouldSendOnlyProvidedFields_WhenUpdatePartial() {
        // Given
        IonosApiMock mock = new IonosApiMock(200, '{"user":' + USER_JSON + '}');
        Test.setMock(HttpCalloutMock.class, mock);

        // When
        Test.startTest();
        IonosUsersService.updateUser(7, null, null, null, 'https://nouveau.fr', true);
        Test.stopTest();

        // Then
        Map<String, Object> sentPayload =
            (Map<String, Object>) JSON.deserializeUntyped(mock.lastRequest.getBody());
        Assert.areEqual(7, (Integer) sentPayload.get('id'), 'L\'id doit être envoyé');
        Assert.areEqual('https://nouveau.fr', sentPayload.get('redirect_url'),
            'redirect_url doit être envoyé');
        Assert.areEqual(1, (Integer) sentPayload.get('first_login'), 'first_login doit valoir 1');
        Assert.isFalse(sentPayload.containsKey('login'), 'login null ne doit pas être envoyé');
        Assert.isFalse(sentPayload.containsKey('email'), 'email null ne doit pas être envoyé');
        Assert.isFalse(sentPayload.containsKey('password'), 'password vide ne doit pas être envoyé');
    }

    @isTest
    static void shouldThrowError_WhenUpdateWithoutAnyField() {
        // Given — aucun mock : la validation doit échouer avant le callout

        // When / Then
        Test.startTest();
        try {
            IonosUsersService.updateUser(7, null, null, null, null, null);
            Assert.fail('Une AuraHandledException était attendue sans champ à modifier');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('Aucun champ'),
                'Le message doit indiquer l\'absence de champs : ' + e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void shouldThrowError_WhenUpdateWithInvalidId() {
        // When / Then
        Test.startTest();
        try {
            IonosUsersService.updateUser(null, 'jean', null, null, null, null);
            Assert.fail('Une AuraHandledException était attendue sur id nul');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('invalide'),
                'Le message doit indiquer l\'id invalide : ' + e.getMessage());
        }
        Test.stopTest();
    }

    // ------------------------------------------------------------------
    // deleteUser
    // ------------------------------------------------------------------

    @isTest
    static void shouldCallDeleteEndpoint_WhenDeleteSucceeds() {
        // Given
        IonosApiMock mock = new IonosApiMock(200, '{"deleted":true,"user":' + USER_JSON + '}');
        Test.setMock(HttpCalloutMock.class, mock);

        // When
        Test.startTest();
        IonosUsersService.deleteUser(7);
        Test.stopTest();

        // Then
        Assert.isTrue(mock.lastRequest.getEndpoint().endsWith('/users_delete.php'),
            'L\'endpoint de suppression doit être appelé');
        Map<String, Object> sentPayload =
            (Map<String, Object>) JSON.deserializeUntyped(mock.lastRequest.getBody());
        Assert.areEqual(7, (Integer) sentPayload.get('id'), 'L\'id à supprimer doit être envoyé');
    }

    @isTest
    static void shouldThrowError_WhenDeleteUnknownUser() {
        // Given
        IonosApiMock mock = new IonosApiMock(404, '{"error":"Aucun utilisateur avec l\'id 999."}');
        Test.setMock(HttpCalloutMock.class, mock);

        // When / Then
        Test.startTest();
        try {
            IonosUsersService.deleteUser(999);
            Assert.fail('Une AuraHandledException était attendue sur le 404');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('Aucun utilisateur'),
                'Le message 404 de l\'API doit remonter : ' + e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void shouldThrowError_WhenDeleteWithInvalidId() {
        // When / Then
        Test.startTest();
        try {
            IonosUsersService.deleteUser(0);
            Assert.fail('Une AuraHandledException était attendue sur id 0');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('invalide'),
                'Le message doit indiquer l\'id invalide : ' + e.getMessage());
        }
        Test.stopTest();
    }

    // ------------------------------------------------------------------
    // ping et erreurs transverses
    // ------------------------------------------------------------------

    @isTest
    static void shouldReturnTotalUsers_WhenPingSucceeds() {
        // Given
        IonosApiMock mock = new IonosApiMock(200, '{"status":"ok","total_users":42}');
        Test.setMock(HttpCalloutMock.class, mock);

        // When
        Test.startTest();
        Integer total = IonosUsersService.ping();
        Test.stopTest();

        // Then
        Assert.areEqual(42, total, 'Le total d\'utilisateurs doit être retourné');
    }

    @isTest
    static void shouldThrowError_WhenApiUnreachable() {
        // Given
        IonosApiMock mock = new IonosApiMock(200, '');
        mock.throwCalloutException = true;
        Test.setMock(HttpCalloutMock.class, mock);

        // When / Then
        Test.startTest();
        try {
            IonosUsersService.ping();
            Assert.fail('Une AuraHandledException était attendue sur CalloutException');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('injoignable'),
                'Le message doit indiquer l\'API injoignable : ' + e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void shouldThrowGenericError_WhenResponseIsNotJson() {
        // Given — page d'erreur HTML au lieu d'un JSON
        IonosApiMock mock = new IonosApiMock(500, '<html>Fatal error</html>');
        Test.setMock(HttpCalloutMock.class, mock);

        // When / Then
        Test.startTest();
        try {
            IonosUsersService.ping();
            Assert.fail('Une AuraHandledException était attendue sur le 500 non-JSON');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('HTTP 500'),
                'Le message générique doit contenir le code HTTP : ' + e.getMessage());
        }
        Test.stopTest();
    }
}