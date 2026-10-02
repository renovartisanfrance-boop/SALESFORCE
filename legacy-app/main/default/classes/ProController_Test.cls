@isTest
public class ProController_Test {
    
    @isTest
    static void testMapAdresseFromLeadWithValidZipCode() {
        // Créer des données de test
        Pro__c testPro = new Pro__c(
            Name = 'Test Pro',
            CodePostal__c = '75001'
        );
        insert testPro;
        
        // Configurer le mock pour la réponse HTTP
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseSuccess());
        
        // Démarrer le test
        Test.startTest();
        
        List<Pro__c> proList = new List<Pro__c>{testPro};
        ProTriggerHandler.map_adresse_from_lead(proList);
        
        Test.stopTest();
        
        // Vérifier les résultats
        Pro__c updatedPro = [SELECT Id, CoordonneesGPS__c FROM Pro__c WHERE Id = :testPro.Id];
        System.assertNotEquals(null, updatedPro.CoordonneesGPS__c, 'Les coordonnées GPS doivent être renseignées');
        System.assert(updatedPro.CoordonneesGPS__c.contains(','), 'Les coordonnées doivent contenir une virgule');
    }
    
    @isTest
    static void testMapAdresseFromLeadWithInvalidZipCode() {
        // Créer des données de test
        Pro__c testPro = new Pro__c(
            Name = 'Test Pro Invalid',
            CodePostal__c = '00000'
        );
        insert testPro;
        
        // Configurer le mock pour une réponse vide
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseEmpty());
        
        // Démarrer le test
        Test.startTest();
        
        List<Pro__c> proList = new List<Pro__c>{testPro};
        ProTriggerHandler.map_adresse_from_lead(proList);
        
        Test.stopTest();
        
        // Vérifier les résultats
        Pro__c updatedPro = [SELECT Id, CoordonneesGPS__c FROM Pro__c WHERE Id = :testPro.Id];
        System.assertEquals('0,0', updatedPro.CoordonneesGPS__c, 'Les coordonnées doivent être 0,0 pour un code postal invalide');
    }
    
    @isTest
    static void testMapAdresseFromLeadWithEmptyList() {
        // Tester avec une liste vide
        Test.startTest();
        
        ProTriggerHandler.map_adresse_from_lead(new List<Pro__c>());
        
        Test.stopTest();
        
        // Pas d'exception levée = test réussi
        System.assert(true, 'La méthode doit gérer les listes vides sans erreur');
    }
    
    @isTest
    static void testMapAdresseFromLeadWithMultipleRecords() {
        // Créer plusieurs enregistrements
        List<Pro__c> proList = new List<Pro__c>{
            new Pro__c(Name = 'Test Pro 1', CodePostal__c = '75001'),
            new Pro__c(Name = 'Test Pro 2', CodePostal__c = '69001')
        };
        insert proList;
        
        // Configurer le mock
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseSuccess());
        
        // Démarrer le test
        Test.startTest();
        
        ProTriggerHandler.map_adresse_from_lead(proList);
        
        Test.stopTest();
        
        // Vérifier que les deux enregistrements ont été mis à jour
        List<Pro__c> updatedPros = [SELECT Id, CoordonneesGPS__c FROM Pro__c WHERE Id IN :proList];
        System.assertEquals(2, updatedPros.size(), 'Deux enregistrements doivent être mis à jour');
        
        for(Pro__c pro : updatedPros) {
            System.assertNotEquals(null, pro.CoordonneesGPS__c, 'Chaque Pro doit avoir des coordonnées');
        }
    }
    
    
    // Mock pour réponse HTTP réussie
    private class MockHttpResponseSuccess implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('[{"lat":"48.8566","lon":"2.3522","display_name":"Paris, France"}]');
            res.setStatusCode(200);
            return res;
        }
    }
    
    // Mock pour réponse HTTP vide
    private class MockHttpResponseEmpty implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('[]');
            res.setStatusCode(200);
            return res;
        }
    }
    
    // Mock pour erreur HTTP
    private class MockHttpResponseError implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"error": "Service unavailable"}');
            res.setStatusCode(500);
            return res;
        }
    }
}