@isTest
private class CustomerTrackerServiceTest {
    @testSetup
    static void setup() {
        List<CustomerTracker__c> setupRecords = new List<CustomerTracker__c>();
        for (Integer i = 1; i <= 20; i++) {
            setupRecords.add(new CustomerTracker__c(Name = 'Tracker ' + i));
        }
        insert setupRecords;
    }
    @isTest
    static void testCreateTrackers() {
        List<CustomerTracker__c> toInsert = new List<CustomerTracker__c>();
        for (Integer i = 1; i <= 5; i++) {
            toInsert.add(new CustomerTracker__c(Name='AutoGen ' + i));
        }
        Test.startTest();
        List<CustomerTracker__c> result = CustomerTrackerService.createTrackers(toInsert);
        Test.stopTest();
        System.assertEquals(5, result.size());
        System.assertEquals(5, [SELECT count() FROM CustomerTracker__c WHERE Name LIKE 'AutoGen%']);
    }
    @isTest
    static void testGetByIdFoundAndNotFound() {
        CustomerTracker__c trackerRec = [SELECT Id FROM CustomerTracker__c LIMIT 1];
        CustomerTracker__c got = CustomerTrackerService.getById(trackerRec.Id);
        System.assertNotEquals(null, got);
        System.assertEquals(trackerRec.Id, got.Id);
        System.assert(CustomerTrackerService.getById(null) == null);
    }
    @isTest
    static void testGetAllEdgeLimits() {
        List<CustomerTracker__c> all50 = CustomerTrackerService.getAll(50);
        System.assert(all50.size() <= 50);
        List<CustomerTracker__c> all5 = CustomerTrackerService.getAll(5);
        System.assertEquals(5, all5.size());
        // More than in db
        List<CustomerTracker__c> overdb = CustomerTrackerService.getAll(500);
        System.assert(overdb.size() <= 200 && overdb.size() > 0);
    }
    @isTest
    static void testUpdateTrackers() {
        List<CustomerTracker__c> recs = [SELECT Id, Name FROM CustomerTracker__c LIMIT 3];
        for(CustomerTracker__c r : recs) { r.Name += ' Updated'; }
        Test.startTest();
        List<CustomerTracker__c> ups = CustomerTrackerService.updateTrackers(recs);
        Test.stopTest();
        for(CustomerTracker__c r : ups) {
            System.assert(r.Name.endsWith('Updated'));
        }
    }
    @isTest
    static void testDeleteById() {
        List<CustomerTracker__c> recs = [SELECT Id FROM CustomerTracker__c LIMIT 2];
        Set<Id> ids = new Set<Id>();
        for(CustomerTracker__c r : recs) ids.add(r.Id);
        Test.startTest();
        CustomerTrackerService.deleteById(ids);
        Test.stopTest();
        System.assertEquals(0, [SELECT COUNT() FROM CustomerTracker__c WHERE Id IN :ids]);
        // Try deleting with null/empty sets
        CustomerTrackerService.deleteById(null);
        CustomerTrackerService.deleteById(new Set<Id>());
    }
    @isTest
    static void testCountAll() {
        Integer n = CustomerTrackerService.countAll();
        Integer dbN = [SELECT count() FROM CustomerTracker__c];
        System.assertEquals(dbN, n);
    }
}
