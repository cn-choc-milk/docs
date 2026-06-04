/**
 * CustomerTrackerTriggerHandlerTest
 *
 * Comprehensive test class for CustomerTrackerTrigger and
 * CustomerTrackerTriggerHandler.
 *
 * Coverage targets (positive, negative, bulk, edge-case):
 *   ✓ beforeInsert – auto-name generation for blank Name
 *   ✓ beforeInsert – user-supplied Name is preserved
 *   ✓ beforeInsert – bulk (200 records)
 *   ✓ beforeUpdate – prevent blank-out of existing Name
 *   ✓ beforeUpdate – Name update allowed when non-blank
 *   ✓ afterInsert  – follow-up Task created for single record
 *   ✓ afterInsert  – follow-up Tasks created for bulk records (200)
 *   ✓ afterInsert  – recursion guard prevents duplicate Task inserts
 *   ✓ afterUpdate  – Task created on owner change (System Admin test user)
 *   ✓ afterUpdate  – No Task when owner unchanged
 *   ✓ afterUpdate  – bulk owner-change (200 records)
 *
 * @author  SYNTH (Salesforce Apex Specialist)
 * @version 1.1
 */
@isTest
private class CustomerTrackerTriggerHandlerTest {

    // ------------------------------------------------------------------
    // Test data helpers
    // ------------------------------------------------------------------

    /**
     * Create n CustomerTracker__c records with the given Name.
     * Pass null / blank to leave Name unpopulated (triggers auto-name).
     */
    private static List<CustomerTracker__c> makeTrackers(
        Integer count,
        String name
    ) {
        List<CustomerTracker__c> records = new List<CustomerTracker__c>();
        for (Integer i = 0; i < count; i++) {
            CustomerTracker__c ct = new CustomerTracker__c();
            if (String.isNotBlank(name)) {
                ct.Name = name + (count > 1 ? ' ' + i : '');
            }
            records.add(ct);
        }
        return records;
    }

    /**
     * Create a System Administrator test user who will always have
     * the permissions needed to own CustomerTracker__c records.
     * Using a Sys Admin avoids TRANSFER_REQUIRES_READ sharing errors.
     */
    private static User createAdminTestUser(String username) {
        List<User> existing = [
            SELECT Id
            FROM User
            WHERE Username = :username
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            return existing[0];
        }
        Profile adminProfile = [
            SELECT Id
            FROM Profile
            WHERE Name = 'System Administrator'
            LIMIT 1
        ];
        User u = new User(
            FirstName        = 'Test',
            LastName         = 'AdminCTT',
            Email            = username,
            Username         = username,
            Alias            = 'ctadm',
            TimeZoneSidKey   = 'America/Los_Angeles',
            LocaleSidKey     = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId        = adminProfile.Id
        );
        insert u;
        return u;
    }

    // ==================================================================
    // BEFORE INSERT tests
    // ==================================================================

    @isTest
    static void beforeInsert_autoName_whenNameIsBlank() {
        List<CustomerTracker__c> trackers = makeTrackers(1, null);

        Test.startTest();
        insert trackers;
        Test.stopTest();

        CustomerTracker__c result = [
            SELECT Id, Name
            FROM CustomerTracker__c
            WHERE Id = :trackers[0].Id
        ];
        System.assert(
            result.Name.startsWith('CT-'),
            'Expected auto-generated name starting with CT-, got: ' + result.Name
        );
    }

    @isTest
    static void beforeInsert_preservesSuppliedName() {
        String suppliedName = 'MyCustomTracker';
        List<CustomerTracker__c> trackers = makeTrackers(1, suppliedName);

        Test.startTest();
        insert trackers;
        Test.stopTest();

        CustomerTracker__c result = [
            SELECT Id, Name
            FROM CustomerTracker__c
            WHERE Id = :trackers[0].Id
        ];
        System.assertEquals(suppliedName, result.Name, 'User-supplied Name should not be overwritten');
    }

    @isTest
    static void beforeInsert_bulk200_allNamesPopulated() {
        List<CustomerTracker__c> trackers = makeTrackers(200, null);

        Test.startTest();
        insert trackers;
        Test.stopTest();

        List<CustomerTracker__c> results = [
            SELECT Id, Name
            FROM CustomerTracker__c
            WHERE Id IN :trackers
        ];
        System.assertEquals(200, results.size(), '200 records should be inserted');
        for (CustomerTracker__c ct : results) {
            System.assert(
                String.isNotBlank(ct.Name),
                'Name must be populated for all records; found blank for: ' + ct.Id
            );
        }
    }

    // ==================================================================
    // BEFORE UPDATE tests
    // ==================================================================

    @isTest
    static void beforeUpdate_preventsNameBlankOut() {
        CustomerTracker__c ct = new CustomerTracker__c(Name = 'OriginalName');
        insert ct;

        ct.Name = '';
        Test.startTest();
        update ct;
        Test.stopTest();

        CustomerTracker__c result = [
            SELECT Id, Name
            FROM CustomerTracker__c
            WHERE Id = :ct.Id
        ];
        System.assertEquals('OriginalName', result.Name, 'Name blank-out should have been reverted');
    }

    @isTest
    static void beforeUpdate_allowsLegitimateNameChange() {
        CustomerTracker__c ct = new CustomerTracker__c(Name = 'OldName');
        insert ct;

        ct.Name = 'NewName';
        Test.startTest();
        update ct;
        Test.stopTest();

        CustomerTracker__c result = [
            SELECT Id, Name
            FROM CustomerTracker__c
            WHERE Id = :ct.Id
        ];
        System.assertEquals('NewName', result.Name, 'Legitimate name change should be saved');
    }

    // ==================================================================
    // AFTER INSERT tests
    // ==================================================================

    @isTest
    static void afterInsert_createsFollowUpTask() {
        CustomerTracker__c ct = new CustomerTracker__c(Name = 'TrackerForTask');

        Test.startTest();
        insert ct;
        Test.stopTest();

        List<Task> tasks = [
            SELECT Id, Subject, WhatId, OwnerId, Status, Priority, ActivityDate
            FROM Task
            WHERE WhatId = :ct.Id
        ];
        System.assertEquals(1, tasks.size(), 'One follow-up Task should be created on insert');
        System.assertEquals('Follow up on new Customer Tracker', tasks[0].Subject, 'Task subject mismatch');
        System.assertEquals('Not Started', tasks[0].Status,   'Task status should be Not Started');
        System.assertEquals('Normal',      tasks[0].Priority, 'Task priority should be Normal');
        System.assertNotEquals(null, tasks[0].ActivityDate,   'Task due date should be set');
    }

    @isTest
    static void afterInsert_bulk200_createsOneTaskPerRecord() {
        List<CustomerTracker__c> trackers = makeTrackers(200, 'BulkTracker');

        Test.startTest();
        insert trackers;
        Test.stopTest();

        Set<Id> trackerIds = new Map<Id, CustomerTracker__c>(trackers).keySet();
        List<Task> tasks = [
            SELECT Id
            FROM Task
            WHERE WhatId IN :trackerIds
        ];
        System.assertEquals(200, tasks.size(), '200 Tasks should be created for 200 inserted Customer Trackers');
    }

    @isTest
    static void afterInsert_recursionGuardPreventsDoubleInsert() {
        CustomerTracker__c ct = new CustomerTracker__c(Name = 'RecursionTest');
        insert ct;

        // Reset guard so explicit calls can exercise it
        CustomerTrackerTriggerHandler.hasRun = false;

        Test.startTest();
        CustomerTrackerTriggerHandler.afterInsert(new List<CustomerTracker__c>{ ct });
        CustomerTrackerTriggerHandler.afterInsert(new List<CustomerTracker__c>{ ct }); // should be blocked
        Test.stopTest();

        List<Task> tasks = [
            SELECT Id
            FROM Task
            WHERE WhatId = :ct.Id
        ];
        // initial insert (1) + first explicit call (1) = 2 max; second explicit call should be blocked
        System.assert(
            tasks.size() <= 2,
            'Recursion guard should prevent more than 2 Task inserts; found: ' + tasks.size()
        );
    }

    // ==================================================================
    // AFTER UPDATE tests
    // ==================================================================

    @isTest
    static void afterUpdate_createsTaskOnOwnerChange() {
        // Use a System Admin test user to avoid TRANSFER_REQUIRES_READ
        User newOwner = createAdminTestUser('ctt_admin_other@test.example.com');

        // Insert tracker owned by the running user (also admin in tests)
        CustomerTracker__c ct = new CustomerTracker__c(Name = 'OwnerChangeTracker');
        insert ct;

        CustomerTrackerTriggerHandler.hasRun = false;

        // Act: change owner inside System.runAs to ensure sharing is correct
        Test.startTest();
        System.runAs(newOwner) {
            // The new owner does the update, implicitly inheriting the record
            ct.OwnerId = newOwner.Id;
            update ct;
        }
        Test.stopTest();

        List<Task> tasks = [
            SELECT Id, Subject, OwnerId
            FROM Task
            WHERE WhatId = :ct.Id
                AND Subject = 'Customer Tracker ownership changed \u2013 please review'
        ];
        System.assertEquals(1, tasks.size(), 'One owner-change Task should be created');
        System.assertEquals(newOwner.Id, tasks[0].OwnerId, 'Task owner should be the new owner');
    }

    @isTest
    static void afterUpdate_noTaskWhenOwnerUnchanged() {
        CustomerTracker__c ct = new CustomerTracker__c(Name = 'NoOwnerChangeTracker');
        insert ct;

        Integer tasksBefore = [
            SELECT COUNT()
            FROM Task
            WHERE WhatId = :ct.Id
        ];

        ct.Name = 'NoOwnerChangeTrackerUpdated';
        Test.startTest();
        update ct;
        Test.stopTest();

        Integer tasksAfter = [
            SELECT COUNT()
            FROM Task
            WHERE WhatId = :ct.Id
        ];
        System.assertEquals(tasksBefore, tasksAfter, 'No new Task should be created when owner does not change');
    }

    @isTest
    static void afterUpdate_bulk200_ownerChangeTasks() {
        // Use a System Admin test user to avoid TRANSFER_REQUIRES_READ
        User newOwner = createAdminTestUser('ctt_admin_bulk@test.example.com');

        List<CustomerTracker__c> trackers = makeTrackers(200, 'BulkOwnerChg');
        insert trackers;

        CustomerTrackerTriggerHandler.hasRun = false;

        // Change owners on all 200 records
        for (CustomerTracker__c ct : trackers) {
            ct.OwnerId = newOwner.Id;
        }

        Test.startTest();
        System.runAs(newOwner) {
            update trackers;
        }
        Test.stopTest();

        Set<Id> ids = new Map<Id, CustomerTracker__c>(trackers).keySet();
        List<Task> tasks = [
            SELECT Id
            FROM Task
            WHERE WhatId IN :ids
                AND Subject = 'Customer Tracker ownership changed \u2013 please review'
        ];
        System.assertEquals(200, tasks.size(), '200 owner-change Tasks should be created for 200 updated records');
    }
}
