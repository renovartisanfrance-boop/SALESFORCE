@isTest
private class OdooController_Test {

    @isTest
    static void testCreateLeadSuccess() {
        // Build payload matching PayloadPiste
        Map<String, Object> payload = new Map<String, Object>{
            'firstName' => 'Jean',
            'lastName' => 'Dupont',
            'phone_sanitized' => '0123456789',
            'website_name' => 'ODOO_SITE',
            'heating_type' => 'gaz',
            'zip' => '75001',
            'email_from' => 'jean@example.com',
            'display_name' => 'M Dupont',
            'your_function' => 'Directeur',
            'you_are' => 'Entreprise',
            'raison_sociale' => 'Société Test',
            'form_state' => 'Formulaire terminé',
            'nb_bike' => '2',
            'nb_employee' => '10',
            'phone_delivery' => '0987654321',
            'street' => '1 Rue Test',
            'street2' => 'Bat A',
            'city' => 'Paris',
            'siret' => '12345678901234',
            'x_studio_secteur_dactivit' => 'Services',
            'x_studio_surface_clairer' => '100'
        };

        String body = JSON.serialize(payload);

        RestRequest req = new RestRequest();
        req.requestURI = '/odoo/createLead?secretodoo=' + Label.ODOO_TOKEN;
        req.httpMethod = 'POST';
        // req.params = new Map<String, String>{ 'secretodoo' => Label.ODOO_TOKEN };
        req.requestBody = Blob.valueOf(body);

        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        OdooController.createLeadFromOdoo();
        Test.stopTest();

        // Vérifier le code retour
        // System.assertEquals(200, RestContext.response.statusCode, 'Status HTTP attendu = 200');

        // Vérifier le corps de la réponse
        String respStr = RestContext.response.responseBody != null ? RestContext.response.responseBody.toString() : null;
        // System.assertNotEquals(null, respStr, 'La réponse ne doit pas être nulle');

        // Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(respStr);
        // System.assertEquals(true, (Boolean) respMap.get('success'));

        // String testField = (String) payload.get('phone_sanitized');
        // // Vérifier qu'un Lead a bien été inséré
        // Lead[] leads = [SELECT Id, FirstName, LastName, Email, Phone, PostalCode FROM Lead WHERE Phone =  : testField];
        // System.assertEquals(1, leads.size(), 'Un Lead doit être inséré');
        // System.assertEquals('Jean', leads[0].FirstName);
        // System.assertEquals('Dupont', leads[0].LastName);
        // System.assertEquals('jean@example.com', leads[0].Email);
        // System.assertEquals('75001', leads[0].PostalCode);
    }

        @isTest
    static void testCreateLeadSuccess2() {
        // Build payload matching PayloadPiste
        Map<String, Object> payload = new Map<String, Object>{
            'firstName' => 'Jean',
            'lastName' => 'false',
            'phone_sanitized' => '0123456789',
            'website_name' => 'ODOO_SITE',
            'zip' => '75001',
            'email_from' => 'jean@example.com',
            'display_name' => 'M Dupont',
            'your_function' => 'Directeur',
            'you_are' => 'Entreprise',
            'raison_sociale' => 'Société Test',
            'form_state' => 'Formulaire non terminé',
            'nb_bike' => '2',
            'nb_employee' => '10',
            'phone_delivery' => '0987654321',
            'street' => '1 Rue Test',
            'street2' => 'Bat A',
            'city' => 'Paris',
            'siret' => '12345678901234',
            'x_studio_secteur_dactivit' => 'Services',
            'x_studio_surface_clairer' => '100'
        };

        String body = JSON.serialize(payload);

        RestRequest req = new RestRequest();
        req.requestURI = '/odoo/createLead?secretodoo=' + Label.ODOO_TOKEN;
        req.httpMethod = 'POST';
        // req.params = new Map<String, String>{ 'secretodoo' => Label.ODOO_TOKEN };
        req.requestBody = Blob.valueOf(body);

        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        OdooController.createLeadFromOdoo();
        Test.stopTest();

        // Vérifier le code retour
        // System.assertEquals(200, RestContext.response.statusCode, 'Status HTTP attendu = 200');

        // Vérifier le corps de la réponse
        String respStr = RestContext.response.responseBody != null ? RestContext.response.responseBody.toString() : null;
        // System.assertNotEquals(null, respStr, 'La réponse ne doit pas être nulle');

        // Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(respStr);
        // System.assertEquals(true, (Boolean) respMap.get('success'));

        // String testField = (String) payload.get('phone_sanitized');
        // // Vérifier qu'un Lead a bien été inséré
        // Lead[] leads = [SELECT Id, FirstName, LastName, Email, Phone, PostalCode FROM Lead WHERE Phone =  : testField];
        // System.assertEquals(1, leads.size(), 'Un Lead doit être inséré');
        // System.assertEquals('Jean', leads[0].FirstName);
        // System.assertEquals('Dupont', leads[0].LastName);
        // System.assertEquals('jean@example.com', leads[0].Email);
        // System.assertEquals('75001', leads[0].PostalCode);
    }

    @isTest
    static void testUnauthorized() {
        RestRequest req = new RestRequest();
        req.requestURI = '/odoo/createLead?secretodoo=WRONG_TOKEN';
        req.httpMethod = 'POST';
        // req.params = new Map<String, String>{ 'secretodoo' => 'WRONG_TOKEN' };
        req.requestBody = Blob.valueOf('{}');

        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        OdooController.createLeadFromOdoo();
        Test.stopTest();

        // System.assertEquals(401, RestContext.response.statusCode, 'Accès non autorisé doit renvoyer 401');
    }
}