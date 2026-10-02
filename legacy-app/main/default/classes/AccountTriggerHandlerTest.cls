@IsTest
public class AccountTriggerHandlerTest {
    @IsTest
    static void testManageCoordinates() {
        // Step 1: Create mock data
        Account testAccount = new Account(
            Name = 'Test Account',
            BillingPostalCode = '75001' // Example postal code
        );
        insert testAccount;

        Opportunity testOpportunity = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = testAccount.Id,
            StageName = 'Prospecting',
            CloseDate = System.today().addMonths(1)
        );
        insert testOpportunity;

        // Step 2: Mock the HTTP Callout
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new AccountTriggerHandlerMock());
        
        // Simulate the ManageCoordinates call
        Map<Id, Account> accs = new Map<Id, Account>{
            testAccount.Id => [SELECT Id, BillingPostalCode FROM Account WHERE Id = :testAccount.Id]
        };
        AccountTriggerHandler.ManageCoordinates(accs);

        // Trigger the @future method
        Test.stopTest();

        // Step 3: Verify the results
        Opportunity updatedOpportunity = [SELECT CoordonneesGPS__c FROM Opportunity WHERE Id = :testOpportunity.Id];
        System.assertNotEquals(null, updatedOpportunity.CoordonneesGPS__c, 'The GPS coordinates should be updated.');
        System.assert(updatedOpportunity.CoordonneesGPS__c.contains(','), 'The GPS coordinates should be in lat,lon format.');
    }

    private class AccountTriggerHandlerMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
        // Mock response for the HTTP callout
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('[{"lat": "48.8566", "lon": "2.3522"}]'); // Example coordinates for Paris, France
        res.setStatusCode(200);
        return res;
    }
}
}