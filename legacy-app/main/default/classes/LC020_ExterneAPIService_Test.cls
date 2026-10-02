@isTest
private class LC020_ExterneAPIService_Test {

    // ─────────────────────────────────────────────────────────────
    // Mocks HTTP
    // ─────────────────────────────────────────────────────────────

    /** Simule une réponse HTTP 200 OK */
    private class MockHTTP200 implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"status":"ok","message":"Utilisateur créé avec succès"}');
            res.setHeader('Content-Type', 'application/json');
            return res;
        }
    }

    /** Simule une réponse HTTP 201 Created */
    private class MockHTTP201 implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(201);
            res.setBody('{"status":"created","id":42}');
            res.setHeader('Content-Type', 'application/json');
            return res;
        }
    }

    /** Simule une réponse HTTP 400 sans message structuré */
    private class MockHTTP400 implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('{"error":"Données invalides"}');
            res.setHeader('Content-Type', 'application/json');
            return res;
        }
    }

    /** Simule une réponse HTTP 400 avec un tableau errors (format envoyerAccesUtilisateur) */
    private class MockHTTP400WithErrors implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('{"errors":[{"message":"Login déjà utilisé"}]}');
            res.setHeader('Content-Type', 'application/json');
            return res;
        }
    }

    /** Simule une réponse HTTP 400 avec un champ message (format changerEmail) */
    private class MockHTTP400WithMessage implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('{"message":"Champs obligatoires manquants"}');
            res.setHeader('Content-Type', 'application/json');
            return res;
        }
    }

    /** Simule une réponse HTTP 404 sans corps structuré */
    private class MockHTTP404Empty implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(404);
            res.setBody('{}');
            return res;
        }
    }

    /** Simule une réponse HTTP 409 sans corps structuré */
    private class MockHTTP409Empty implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(409);
            res.setBody('{}');
            return res;
        }
    }

    /** Simule une réponse HTTP 404 Not Found */
    private class MockHTTP404 implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(404);
            res.setBody('{"message":"Email introuvable"}');
            res.setHeader('Content-Type', 'application/json');
            return res;
        }
    }

    /** Simule une réponse HTTP 409 Conflict */
    private class MockHTTP409 implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(409);
            res.setBody('{"message":"Email déjà utilisé"}');
            res.setHeader('Content-Type', 'application/json');
            return res;
        }
    }

    /** Simule une réponse HTTP 500 Internal Server Error */
    private class MockHTTP500 implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"error":"Internal Server Error"}');
            res.setHeader('Content-Type', 'application/json');
            return res;
        }
    }

    /** Simule une erreur réseau (callout exception) */
    private class MockHTTPNetworkError implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            CalloutException e = (CalloutException) CalloutException.class.newInstance();
            e.setMessage('Connexion refusée - hôte introuvable');
            throw e;
        }
    }

    /** Mock qui capture la requête pour vérification du corps envoyé */
    private class MockHTTPCapture implements HttpCalloutMock {
        public HttpRequest capturedRequest;
        public HttpResponse respond(HttpRequest req) {
            this.capturedRequest = req;
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"status":"ok"}');
            return res;
        }
    }

    // ─────────────────────────────────────────────────────────────
    // Tests : envoyerAccesUtilisateur
    // ─────────────────────────────────────────────────────────────

    @isTest
    static void testEnvoyerAccesUtilisateur_Succes200() {
        Test.setMock(HttpCalloutMock.class, new MockHTTP200());

        Test.startTest();
        LC020_ExterneAPIService.Result result = LC020_ExterneAPIService.envoyerAccesUtilisateur(
            'jean.dupont', 'jean@example.com', 'Abc12345',
            'https://example.com/rdv?c__code=abc123'
        );
        Test.stopTest();

        System.assertEquals(true,  result.success, 'Un code 200 doit retourner success=true.');
        System.assertEquals(null,  result.message, 'Aucun message d\'erreur attendu pour un succès.');
    }

    @isTest
    static void testEnvoyerAccesUtilisateur_Succes201() {
        Test.setMock(HttpCalloutMock.class, new MockHTTP201());

        Test.startTest();
        LC020_ExterneAPIService.Result result = LC020_ExterneAPIService.envoyerAccesUtilisateur(
            'marie.martin', 'marie@example.com', 'Xyz98765',
            'https://example.com/rdv?c__code=xyz789'
        );
        Test.stopTest();

        System.assertEquals(true, result.success, 'Un code 201 doit retourner success=true.');
    }

    @isTest
    static void testEnvoyerAccesUtilisateur_ErreurServeur500() {
        Test.setMock(HttpCalloutMock.class, new MockHTTP500());

        Test.startTest();
        LC020_ExterneAPIService.Result result = LC020_ExterneAPIService.envoyerAccesUtilisateur(
            'erreur.serveur', 'erreur@example.com', 'Pass1234',
            'https://example.com/rdv?c__code=err001'
        );
        Test.stopTest();

        System.assertEquals(false, result.success, 'Un code 500 doit retourner success=false.');
        System.assertNotEquals(null, result.message, 'Un message d\'erreur doit être présent pour un code 500.');
    }

    @isTest
    static void testEnvoyerAccesUtilisateur_ErreurClient400_SansMessage() {
        Test.setMock(HttpCalloutMock.class, new MockHTTP400());

        Test.startTest();
        LC020_ExterneAPIService.Result result = LC020_ExterneAPIService.envoyerAccesUtilisateur(
            'bad.request', 'bad@example.com', 'Pass1234',
            'https://example.com/rdv?c__code=bad001'
        );
        Test.stopTest();

        System.assertEquals(false, result.success, 'Un code 400 doit retourner success=false.');
        System.assertNotEquals(null, result.message, 'Un message d\'erreur doit être présent.');
    }

    @isTest
    static void testEnvoyerAccesUtilisateur_ErreurClient400_AvecErrors() {
        Test.setMock(HttpCalloutMock.class, new MockHTTP400WithErrors());

        Test.startTest();
        LC020_ExterneAPIService.Result result = LC020_ExterneAPIService.envoyerAccesUtilisateur(
            'login.existant', 'existant@example.com', 'Pass1234',
            'https://example.com/rdv?c__code=dup001'
        );
        Test.stopTest();

        System.assertEquals(false,              result.success, 'Un code 400 doit retourner success=false.');
        System.assertEquals('Login déjà utilisé', result.message, 'Le message doit être extrait du tableau errors.');
    }

    @isTest
    static void testEnvoyerAccesUtilisateur_ErreurReseau() {
        Test.setMock(HttpCalloutMock.class, new MockHTTPNetworkError());

        Test.startTest();
        LC020_ExterneAPIService.Result result = LC020_ExterneAPIService.envoyerAccesUtilisateur(
            'reseau.fail', 'fail@example.com', 'Pass5678',
            'https://example.com/rdv?c__code=net001'
        );
        Test.stopTest();

        System.assertEquals(false, result.success, 'Une erreur réseau doit retourner success=false.');
        System.assertNotEquals(null, result.message, 'Un message d\'erreur doit être présent.');
    }

    @isTest
    static void testEnvoyerAccesUtilisateur_VerifieFormatJSON() {
        MockHTTPCapture captureMock = new MockHTTPCapture();
        Test.setMock(HttpCalloutMock.class, captureMock);

        String login       = 'jean.dupont';
        String email       = 'jean@example.com';
        String password    = 'MonPass1';
        String redirectUrl = 'https://example.com/rdv?c__code=tok123';

        Test.startTest();
        LC020_ExterneAPIService.Result result = LC020_ExterneAPIService.envoyerAccesUtilisateur(
            login, email, password, redirectUrl
        );
        Test.stopTest();

        System.assertEquals(true, result.success, 'Un code 200 doit retourner success=true.');
        System.assertNotEquals(null, captureMock.capturedRequest, 'La requête HTTP doit avoir été envoyée.');
        System.assertEquals('POST', captureMock.capturedRequest.getMethod(), 'La méthode HTTP doit être POST.');
        System.assertEquals(
            'application/json',
            captureMock.capturedRequest.getHeader('Content-Type'),
            'Le header Content-Type doit être application/json.'
        );

        String body = captureMock.capturedRequest.getBody();
        System.assert(body.contains('"users"'),        'Le JSON doit contenir la clé "users".');
        System.assert(body.contains(login),            'Le JSON doit contenir le login.');
        System.assert(body.contains(email),            'Le JSON doit contenir l\'email.');
        System.assert(body.contains(password),         'Le JSON doit contenir le mot de passe.');
        System.assert(body.contains('"login"'),        'Le JSON doit contenir la clé "login".');
        System.assert(body.contains('"email"'),        'Le JSON doit contenir la clé "email".');
        System.assert(body.contains('"password"'),     'Le JSON doit contenir la clé "password".');
        System.assert(body.contains('"redirect_url"'), 'Le JSON doit contenir la clé "redirect_url".');
    }

    // ─────────────────────────────────────────────────────────────
    // Tests : reinitialiserMotDePasse
    // ─────────────────────────────────────────────────────────────

    @isTest
    static void testReinitialiserMotDePasse_Succes200() {
        Test.setMock(HttpCalloutMock.class, new MockHTTP200());

        Test.startTest();
        LC020_ExterneAPIService.Result result = LC020_ExterneAPIService.reinitialiserMotDePasse('jean@example.com');
        Test.stopTest();

        System.assertEquals(true, result.success, 'Un code 200 doit retourner success=true.');
        System.assertEquals(null, result.message, 'Aucun message d\'erreur attendu pour un succès.');
    }

    @isTest
    static void testReinitialiserMotDePasse_Succes201() {
        Test.setMock(HttpCalloutMock.class, new MockHTTP201());

        Test.startTest();
        LC020_ExterneAPIService.Result result = LC020_ExterneAPIService.reinitialiserMotDePasse('marie@example.com');
        Test.stopTest();

        System.assertEquals(true, result.success, 'Un code 201 doit retourner success=true.');
    }

    @isTest
    static void testReinitialiserMotDePasse_ErreurServeur500() {
        Test.setMock(HttpCalloutMock.class, new MockHTTP500());

        Test.startTest();
        LC020_ExterneAPIService.Result result = LC020_ExterneAPIService.reinitialiserMotDePasse('erreur@example.com');
        Test.stopTest();

        System.assertEquals(false, result.success, 'Un code 500 doit retourner success=false.');
        System.assertNotEquals(null, result.message, 'Un message d\'erreur doit être présent.');
    }

    @isTest
    static void testReinitialiserMotDePasse_ErreurClient400() {
        Test.setMock(HttpCalloutMock.class, new MockHTTP400());

        Test.startTest();
        LC020_ExterneAPIService.Result result = LC020_ExterneAPIService.reinitialiserMotDePasse('bad@example.com');
        Test.stopTest();

        System.assertEquals(false, result.success, 'Un code 400 doit retourner success=false.');
        System.assertNotEquals(null, result.message, 'Un message d\'erreur doit être présent.');
    }

    @isTest
    static void testReinitialiserMotDePasse_ErreurReseau() {
        Test.setMock(HttpCalloutMock.class, new MockHTTPNetworkError());

        Test.startTest();
        LC020_ExterneAPIService.Result result = LC020_ExterneAPIService.reinitialiserMotDePasse('fail@example.com');
        Test.stopTest();

        System.assertEquals(false, result.success, 'Une erreur réseau doit retourner success=false.');
        System.assertNotEquals(null, result.message, 'Un message d\'erreur doit être présent.');
    }

    @isTest
    static void testReinitialiserMotDePasse_VerifieFormatRequete() {
        MockHTTPCapture captureMock = new MockHTTPCapture();
        Test.setMock(HttpCalloutMock.class, captureMock);

        String email = 'test.user@example.com';

        Test.startTest();
        LC020_ExterneAPIService.reinitialiserMotDePasse(email);
        Test.stopTest();

        System.assertNotEquals(null, captureMock.capturedRequest, 'La requête HTTP doit avoir été envoyée.');
        System.assertEquals('POST', captureMock.capturedRequest.getMethod(), 'La méthode HTTP doit être POST.');
        System.assertEquals(
            'application/x-www-form-urlencoded',
            captureMock.capturedRequest.getHeader('Content-Type'),
            'Le Content-Type doit être application/x-www-form-urlencoded.'
        );
        System.assert(
            captureMock.capturedRequest.getEndpoint().endsWith('/forgot_password.php'),
            'L\'endpoint doit se terminer par /forgot_password.php.'
        );
        System.assert(
            captureMock.capturedRequest.getBody().contains('email='),
            'Le corps doit contenir le champ email en form-data.'
        );
    }

    // ─────────────────────────────────────────────────────────────
    // Tests : changerEmail
    // ─────────────────────────────────────────────────────────────

    @isTest
    static void testChangerEmail_Succes200() {
        Test.setMock(HttpCalloutMock.class, new MockHTTP200());

        Test.startTest();
        LC020_ExterneAPIService.Result result = LC020_ExterneAPIService.changerEmail(
            'ancien@example.com', 'nouveau@example.com'
        );
        Test.stopTest();

        System.assertEquals(true, result.success, 'Un code 200 doit retourner success=true.');
        System.assertEquals(null, result.message, 'Aucun message d\'erreur attendu pour un succès.');
    }

    @isTest
    static void testChangerEmail_Erreur400_SansMessage() {
        Test.setMock(HttpCalloutMock.class, new MockHTTP400());

        Test.startTest();
        LC020_ExterneAPIService.Result result = LC020_ExterneAPIService.changerEmail(
            'ancien@example.com', 'mauvais'
        );
        Test.stopTest();

        System.assertEquals(false, result.success, 'Un code 400 doit retourner success=false.');
        System.assertNotEquals(null, result.message, 'Un message d\'erreur doit être présent.');
    }

    @isTest
    static void testChangerEmail_Erreur400_AvecMessage() {
        Test.setMock(HttpCalloutMock.class, new MockHTTP400WithMessage());

        Test.startTest();
        LC020_ExterneAPIService.Result result = LC020_ExterneAPIService.changerEmail(
            'ancien@example.com', ''
        );
        Test.stopTest();

        System.assertEquals(false,                          result.success, 'Un code 400 doit retourner success=false.');
        System.assertEquals('Champs obligatoires manquants', result.message, 'Le message doit être extrait du corps de la réponse.');
    }

    @isTest
    static void testChangerEmail_Erreur404_FallbackMessage() {
        Test.setMock(HttpCalloutMock.class, new MockHTTP404Empty());

        String oldEmail = 'introuvable@example.com';

        Test.startTest();
        LC020_ExterneAPIService.Result result = LC020_ExterneAPIService.changerEmail(
            oldEmail, 'nouveau@example.com'
        );
        Test.stopTest();

        System.assertEquals(false, result.success, 'Un code 404 doit retourner success=false.');
        System.assert(result.message.contains(oldEmail), 'Le message de fallback doit mentionner l\'ancien email.');
    }

    @isTest
    static void testChangerEmail_Erreur404_AvecMessage() {
        Test.setMock(HttpCalloutMock.class, new MockHTTP404());

        Test.startTest();
        LC020_ExterneAPIService.Result result = LC020_ExterneAPIService.changerEmail(
            'introuvable@example.com', 'nouveau@example.com'
        );
        Test.stopTest();

        System.assertEquals(false,             result.success, 'Un code 404 doit retourner success=false.');
        System.assertEquals('Email introuvable', result.message, 'Le message doit être extrait du corps de la réponse.');
    }

    @isTest
    static void testChangerEmail_Erreur409_FallbackMessage() {
        Test.setMock(HttpCalloutMock.class, new MockHTTP409Empty());

        String newEmail = 'deja.pris@example.com';

        Test.startTest();
        LC020_ExterneAPIService.Result result = LC020_ExterneAPIService.changerEmail(
            'ancien@example.com', newEmail
        );
        Test.stopTest();

        System.assertEquals(false, result.success, 'Un code 409 doit retourner success=false.');
        System.assert(result.message.contains(newEmail), 'Le message de fallback doit mentionner le nouvel email.');
    }

    @isTest
    static void testChangerEmail_Erreur409_AvecMessage() {
        Test.setMock(HttpCalloutMock.class, new MockHTTP409());

        Test.startTest();
        LC020_ExterneAPIService.Result result = LC020_ExterneAPIService.changerEmail(
            'ancien@example.com', 'deja.pris@example.com'
        );
        Test.stopTest();

        System.assertEquals(false,               result.success, 'Un code 409 doit retourner success=false.');
        System.assertEquals('Email déjà utilisé', result.message, 'Le message doit être extrait du corps de la réponse.');
    }

    @isTest
    static void testChangerEmail_ErreurReseau() {
        Test.setMock(HttpCalloutMock.class, new MockHTTPNetworkError());

        Test.startTest();
        LC020_ExterneAPIService.Result result = LC020_ExterneAPIService.changerEmail(
            'ancien@example.com', 'nouveau@example.com'
        );
        Test.stopTest();

        System.assertEquals(false, result.success, 'Une erreur réseau doit retourner success=false.');
        System.assertNotEquals(null, result.message, 'Un message d\'erreur doit être présent.');
    }

    @isTest
    static void testChangerEmail_VerifieFormatRequete() {
        MockHTTPCapture captureMock = new MockHTTPCapture();
        Test.setMock(HttpCalloutMock.class, captureMock);

        String oldEmail = 'ancien@example.com';
        String newEmail = 'nouveau@example.com';

        Test.startTest();
        LC020_ExterneAPIService.changerEmail(oldEmail, newEmail);
        Test.stopTest();

        System.assertNotEquals(null, captureMock.capturedRequest, 'La requête HTTP doit avoir été envoyée.');
        System.assertEquals('POST', captureMock.capturedRequest.getMethod(), 'La méthode HTTP doit être POST.');
        System.assertEquals(
            'application/json',
            captureMock.capturedRequest.getHeader('Content-Type'),
            'Le Content-Type doit être application/json.'
        );
        System.assert(
            captureMock.capturedRequest.getEndpoint().endsWith('/api/change_email.php'),
            'L\'endpoint doit se terminer par /api/change_email.php.'
        );

        String body = captureMock.capturedRequest.getBody();
        System.assert(body.contains('"oldEmail"'), 'Le JSON doit contenir la clé "oldEmail".');
        System.assert(body.contains('"newEmail"'), 'Le JSON doit contenir la clé "newEmail".');
        System.assert(body.contains(oldEmail),     'Le JSON doit contenir l\'ancien email.');
        System.assert(body.contains(newEmail),     'Le JSON doit contenir le nouvel email.');
    }
}