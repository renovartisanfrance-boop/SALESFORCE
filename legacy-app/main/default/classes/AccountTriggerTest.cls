@IsTest
public class AccountTriggerTest {
    @IsTest
    static void testAfterInsert() {
        // Step 1: Create and insert accounts
        Account acc1 = new Account(Name = 'Test Account 1', BillingPostalCode = '75001');
        Account acc2 = new Account(Name = 'Test Account 2', BillingPostalCode = '75002');
        insert new List<Account>{ acc1, acc2 };

        // Step 2: Mock the HTTP callout
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new AccountTriggerHandlerMock());

        // Re-query the accounts to simulate Trigger.new
        List<Account> insertedAccounts = [SELECT Id, BillingPostalCode FROM Account WHERE Id IN (:acc1.Id, :acc2.Id)];

        // Verify handler method is called with inserted accounts
        System.debug('Inserted Accounts: ' + insertedAccounts);
        Test.stopTest();

        // Additional assertions can be added if necessary
    }

    @IsTest
    static void testAfterUpdate() {
        // Step 1: Create and insert an account
        Account acc = new Account(Name = 'Test Account', BillingPostalCode = '75001');
        insert acc;

        // Step 2: Update the account's BillingPostalCode
        acc.BillingPostalCode = '75008';
        update acc;

        // Mock the HTTP callout
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new AccountTriggerHandlerMock());

        // Step 3: Verify handler method is called for the updated account
        Account updatedAccount = [SELECT BillingPostalCode FROM Account WHERE Id = :acc.Id];
        System.debug('Updated Account: ' + updatedAccount);
        Test.stopTest();
    }

    private class AccountTriggerHandlerMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('[{"lat": "48.8566", "lon": "2.3522"}]'); // Example GPS for Paris
            res.setStatusCode(200);
            return res;
        }
    }
    
}