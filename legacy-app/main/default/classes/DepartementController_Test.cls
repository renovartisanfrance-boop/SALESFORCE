@IsTest
public with sharing class DepartementController_Test {
    public DepartementController_Test() {

    }

    @isTest
    static void testGetDepartements() {
        // Create test metadata records
        List<Departement__mdt> departements = DepartementController.getDepartements();
        System.assertNotEquals(0, departements.size(), 'There should be at least one departement metadata record.');
    }
}