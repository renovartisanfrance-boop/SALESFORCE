@IsTest
public class TaskTriggerHandlerTest {
@IsTest
    public static void testMethod1(){
            // Create Lead 
        Lead ld = new Lead(firstname='firstname', lastname='lastname', company='company' );
        //Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        insert ld;
        
        // Create Task
        //Test.startTest();
        Task tk1 = new Task(whoId = ld.Id, subject = 'Outbound unanswered', status = 'Terminé');
        Task tk2 = new Task(whoId = ld.Id, subject = 'Outbound answered call', status = 'Terminé');
        insert new List<Sobject>{tk1,tk2};
        update tk2;
        delete tk1;
        // TaskTriggerHandler.fakeMethod();
    }
}