@IsTest
public with sharing class OpportunityTriggerHandlerTest {
    @IsTest
    public static void insertOpp(){

// Définir une réponse de mock HTTP
      Test.setMock(HttpCalloutMock.class, new SuccessfulMockHttpResponse());
      // Appeler la méthode @future (callout=true) dans un test
    Test.startTest();
        OpportunityTriggerHandler.fakeMethod();
          Opportunity mAWSUsage = new Opportunity(
            Name = 'mAWS Usage',TYPE_DE_LEADS__c='ITE',
                              StageName = 'Negotiations',
                              CloseDate = System.today(),
                              Type = 'New Business - Add',
                              Amount = 555888555);

                         insert  mAWSUsage;
        
          Opportunity  mAWSUsage_2 = new Opportunity(Id = mAWSUsage.Id , Name = 'mAWS Usage 2');
          update mAWSUsage_2;

          Test.stopTest();
    }

    //  // Test Setup method to create test data that can be reused across tests
    //  @TestSetup
    //  static void setupTestData() {
    //      // Create a list of Opportunity records
    //      List<Opportunity> opps = new List<Opportunity>{
    //          new Opportunity(Name = 'Opportunity 1', StageName = 'Prospecting', CloseDate = Date.today().addDays(30), Adresse__PostalCode__s = '75001'),
    //          new Opportunity(Name = 'Opportunity 2', StageName = 'Qualification', CloseDate = Date.today().addDays(30), Adresse__PostalCode__s = '69002')
    //      };
    //      insert opps;
    //  }
 
    //  // Test for the updateLatLong method with a non-empty list
    //  @IsTest
    //  static void testUpdateLatLong_WithOpportunities() {
    //      // Retrieve the opportunities created in the @TestSetup
    //      List<Opportunity> opps = [SELECT Id, Adresse__PostalCode__s FROM Opportunity WHERE Adresse__PostalCode__s != null];
         
    //      // Call the method to test
    //      Test.startTest();
    //      OpportunityTriggerHandler.updateLatLong(opps);
    //      Test.stopTest();
         
    //      // Assert that the opportunities exist in the list
    //      System.assert(!opps.isEmpty(), 'Opportunities list should not be empty');
    //  }
 
    //  // Test for the updateLatLong method with an empty list
    //  @IsTest
    //  static void testUpdateLatLong_EmptyList() {
    //      // Call the method with an empty list
    //      Test.startTest();
    //      OpportunityTriggerHandler.updateLatLong(new List<Opportunity>());
    //      Test.stopTest();
         
    //      // No assertions needed since the method should simply return
    //  }
 
    //  // Test for the AsyncGetCoordinates method with a mock HTTP response
    //  @IsTest
    //  static void testAsyncGetCoordinates_SuccessfulResponse() {
    //      // Set up mock callout
    //      Test.setMock(HttpCalloutMock.class, new SuccessfulMockHttpResponse());
         
    //      // Get an opportunity from the test data
    //      Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
         
    //      // Call the future method
    //      Test.startTest();
    //      OpportunityTriggerHandler.AsyncGetCoordinates('75001', opp.Id);
    //      Test.stopTest();
         
    //      // Verify that the Opportunity's CoordonneesGPS__c field was updated
    //      Opportunity updatedOpp = [SELECT CoordonneesGPS__c FROM Opportunity WHERE Id = :opp.Id];
    //      System.assertNotEquals(updatedOpp.CoordonneesGPS__c, null, 'CoordonneesGPS__c should be updated with latitude and longitude.');
    //      System.assert(updatedOpp.CoordonneesGPS__c != '0,0', 'CoordonneesGPS__c should not be 0,0 if callout is successful.');
    //  }
 
    //  // Test for the AsyncGetCoordinates method with an unsuccessful response (no results)
    //  @IsTest
    //  static void testAsyncGetCoordinates_UnsuccessfulResponse() {
    //      // Set up mock callout
    //      Test.setMock(HttpCalloutMock.class, new UnsuccessfulMockHttpResponse());
         
    //      // Get an opportunity from the test data
    //      Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
         
    //      // Call the future method
    //      Test.startTest();
    //      OpportunityTriggerHandler.AsyncGetCoordinates('99999', opp.Id);
    //      Test.stopTest();
         
    //      // Verify that the Opportunity's CoordonneesGPS__c field was set to '0,0'
    //      Opportunity updatedOpp = [SELECT CoordonneesGPS__c FROM Opportunity WHERE Id = :opp.Id];
    //      System.assertEquals('0,0', updatedOpp.CoordonneesGPS__c, 'CoordonneesGPS__c should be set to 0,0 if no results are returned.');
    //  }
 
     // Custom Mock for Successful HTTP Response
     private class SuccessfulMockHttpResponse implements HttpCalloutMock {
         public HTTPResponse respond(HTTPRequest req) {
             // Simulate a successful callout with a valid response
             HttpResponse res = new HttpResponse();
             res.setHeader('Content-Type', 'application/json');
             res.setBody('[{"lat": "48.8566", "lon": "2.3522"}]'); // Paris coordinates as an example
             res.setStatusCode(200);
             return res;
         }
     }
 
     // Custom Mock for Unsuccessful HTTP Response (no results)
     private class UnsuccessfulMockHttpResponse implements HttpCalloutMock {
         public HTTPResponse respond(HTTPRequest req) {
             // Simulate an unsuccessful callout with an empty result
             HttpResponse res = new HttpResponse();
             res.setHeader('Content-Type', 'application/json');
             res.setBody('[]'); // No results
             res.setStatusCode(200);
             return res;
         }
     }
}