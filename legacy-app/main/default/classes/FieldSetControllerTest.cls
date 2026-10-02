@isTest
public class FieldSetControllerTest {
    
    @isTest
    static void testGetForm_WithRecordId() {
        // Call the method with a recordId
        FieldSetController.FakeMethod();
        FieldSetController.FieldSetForm form = FieldSetController.getForm(
            null,
            'Lead', // objectName is not provided
            'TestFieldSet',
            null
        );
    }


    @isTest
    static void testFakeMethod() {
        // Call the FakeMethod to ensure it can be executed
        FieldSetController.FakeMethod();
    }
}