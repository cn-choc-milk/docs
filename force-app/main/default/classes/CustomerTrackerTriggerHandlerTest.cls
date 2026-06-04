/**
 * CustomerTrackerTriggerHandlerTest
 *
 * Comprehensive test class for CustomerTrackerTrigger and CustomerTrackerTriggerHandler.
 * Covers:
 *  - Positive paths (valid inserts, updates, status transitions)
 *  - Negative paths (invalid status, blocked transitions, blocked delete)
 *  - Bulk scenarios (200 records)
 *  - After-insert Task creation
 *  - After-update Task closure on deactivation
 */
@isTest
private class CustomerTrackerTriggerHandlerTest {

    // ---------------------------------------------------------------------------
    // Test Setup
    // ---------------------------------------------------------------------------
    @testSetup
    static void setup() {
        // Nothing to pre-seed at org level; records are created per-test.
    }

    // ---------------------------------------------------------------------------
    // Helper
    // ---------------------------------------------------------------------------
    private static CustomerTracker__c makeTracker(String name, String status) {
        CustomerTracker__c ct = new CustomerTracker__c();
        ct.Name      = name;
        ct.Status__c = status;
        return ct;
    }

    // ---------------------------------------------------------------------------
    // Before Insert — default status applied when omitted
    // ---------------------------------------------------------------------------
    @isTest
    static void testBeforeInsert_DefaultStatus() {
        CustomerTracker__c ct = new CustomerTracker__c(Name = 'Test Default');
        // Status__c intentionally NOT set

        Test.startTest();
        insert ct;
        Test.stopTest();

        CustomerTracker__c inserted = [
            SELECT Status__c, LastActivityDate__c
            FROM CustomerTracker__c
            WHERE Id = :ct.Id
        ];
        System.assertEquals('Pending', inserted.Status__c,
            'Default status should be set to Pending on insert');
        System.assertNotEquals(null, inserted.LastActivityDate__c,
            'LastActivityDate__c should be stamped on insert');
    }

    // ---------------------------------------------------------------------------
    // Before Insert — explicit valid status preserved
    // ---------------------------------------------------------------------------
    @isTest
    static void testBeforeInsert_ExplicitStatus() {
        CustomerTracker__c ct = makeTracker('Explicit Active', 'Active');

        Test.startTest();
        insert ct;
        Test.stopTest();

        CustomerTracker__c inserted = [
            SELECT Status__c FROM CustomerTracker__c WHERE Id = :ct.Id
        ];
        System.assertEquals('Active', inserted.Status__c,
            'Explicit Active status should be preserved');
    }

    // ---------------------------------------------------------------------------
    // Before Insert — invalid status rejected
    // ---------------------------------------------------------------------------
    @isTest
    static void testBeforeInsert_InvalidStatus() {
        CustomerTracker__c ct = makeTracker('Bad Status', 'InvalidStatus');

        Test.startTest();
        try {
            insert ct;
            System.assert(false, 'Expected DmlException for invalid status');
        } catch (DmlException e) {
            System.assert(
                e.getMessage().contains('Status must be'),
                'Error message should mention allowed statuses'
            );
        }
        Test.stopTest();
    }

    // ---------------------------------------------------------------------------
    // Before Update — valid status transition allowed
    // ---------------------------------------------------------------------------
    @isTest
    static void testBeforeUpdate_ValidTransition() {
        CustomerTracker__c ct = makeTracker('Transition Test', 'Pending');
        insert ct;

        Test.startTest();
        ct.Status__c = 'Active';
        update ct;
        Test.stopTest();

        CustomerTracker__c updated = [
            SELECT Status__c, LastActivityDate__c
            FROM CustomerTracker__c
            WHERE Id = :ct.Id
        ];
        System.assertEquals('Active', updated.Status__c,
            'Pending -> Active transition should be allowed');
        System.assertEquals(Date.today(), updated.LastActivityDate__c,
            'LastActivityDate__c should be refreshed on status change');
    }

    // ---------------------------------------------------------------------------
    // Before Update — Active -> Pending blocked
    // ---------------------------------------------------------------------------
    @isTest
    static void testBeforeUpdate_BlockActiveToPending() {
        CustomerTracker__c ct = makeTracker('Block Revert', 'Active');
        insert ct;

        Test.startTest();
        try {
            ct.Status__c = 'Pending';
            update ct;
            System.assert(false, 'Expected DmlException for invalid transition');
        } catch (DmlException e) {
            System.assert(
                e.getMessage().contains('Cannot revert'),
                'Error should mention invalid Active->Pending revert'
            );
        }
        Test.stopTest();
    }

    // ---------------------------------------------------------------------------
    // Before Delete — Active record cannot be deleted
    // ---------------------------------------------------------------------------
    @isTest
    static void testBeforeDelete_BlockActiveDelete() {
        CustomerTracker__c ct = makeTracker('Block Delete', 'Active');
        insert ct;

        Test.startTest();
        try {
            delete ct;
            System.assert(false, 'Expected DmlException for active record deletion');
        } catch (DmlException e) {
            System.assert(
                e.getMessage().contains('Active Customer Tracker'),
                'Error should block deletion of Active records'
            );
        }
        Test.stopTest();
    }

    // ---------------------------------------------------------------------------
    // Before Delete — Inactive record can be deleted
    // ---------------------------------------------------------------------------
    @isTest
    static void testBeforeDelete_AllowInactiveDelete() {
        CustomerTracker__c ct = makeTracker('Allow Delete', 'Inactive');
        insert ct;

        Test.startTest();
        delete ct;
        Test.stopTest();

        List<CustomerTracker__c> remaining = [
            SELECT Id FROM CustomerTracker__c WHERE Id = :ct.Id
        ];
        System.assertEquals(0, remaining.size(), 'Inactive record should be deletable');
    }

    // ---------------------------------------------------------------------------
    // After Insert — follow-up Task created for each new record
    // ---------------------------------------------------------------------------
    @isTest
    static void testAfterInsert_TaskCreated() {
        CustomerTracker__c ct = makeTracker('Task Creation Test', 'Pending');

        Test.startTest();
        insert ct;
        Test.stopTest();

        List<Task> tasks = [
            SELECT Subject, Status, Priority, ActivityDate, WhatId
            FROM   Task
            WHERE  WhatId = :ct.Id
        ];
        System.assertEquals(1, tasks.size(), 'Exactly one follow-up Task should be created');
        System.assert(
            tasks[0].Subject.contains('Follow up'),
            'Task subject should contain "Follow up"'
        );
        System.assertEquals('Not Started', tasks[0].Status, 'Task status should be Not Started');
        System.assertEquals('Normal', tasks[0].Priority, 'Task priority should be Normal');
        System.assertEquals(
            Date.today().addDays(3), tasks[0].ActivityDate,
            'Task due date should be 3 days from today'
        );
    }

    // ---------------------------------------------------------------------------
    // After Update — deactivation closes open Tasks
    // ---------------------------------------------------------------------------
    @isTest
    static void testAfterUpdate_TasksClosedOnDeactivation() {
        CustomerTracker__c ct = makeTracker('Deactivation Test', 'Active');
        insert ct;

        // The afterInsert auto-created Task will have Status='Not Started'.
        // Verify it exists then deactivate.
        List<Task> preUpdateTasks = [
            SELECT Id, Status FROM Task WHERE WhatId = :ct.Id AND IsClosed = false
        ];
        System.assert(!preUpdateTasks.isEmpty(), 'Should have open task before deactivation');

        Test.startTest();
        ct.Status__c = 'Inactive';
        update ct;
        Test.stopTest();

        List<Task> postUpdateTasks = [
            SELECT Id, Status FROM Task WHERE WhatId = :ct.Id
        ];
        for (Task t : postUpdateTasks) {
            System.assertEquals('Completed', t.Status,
                'All open Tasks should be closed when tracker is deactivated');
        }
    }

    // ---------------------------------------------------------------------------
    // After Update — non-deactivation update does NOT close tasks
    // ---------------------------------------------------------------------------
    @isTest
    static void testAfterUpdate_NoTaskClosureOnNonDeactivation() {
        CustomerTracker__c ct = makeTracker('No Close Test', 'Pending');
        insert ct;

        // Move Pending -> Active (no deactivation, should not close tasks)
        Test.startTest();
        ct.Status__c = 'Active';
        update ct;
        Test.stopTest();

        List<Task> openTasks = [
            SELECT Id, Status FROM Task WHERE WhatId = :ct.Id AND IsClosed = false
        ];
        // Task should still be open (not closed) since we only activated, not deactivated
        System.assert(!openTasks.isEmpty(),
            'Tasks should remain open when transitioning to Active (not Inactive)');
    }

    // ---------------------------------------------------------------------------
    // Bulk Insert — 200 records with default status
    // ---------------------------------------------------------------------------
    @isTest
    static void testBulkInsert_200Records() {
        List<CustomerTracker__c> trackers = new List<CustomerTracker__c>();
        for (Integer i = 0; i < 200; i++) {
            trackers.add(new CustomerTracker__c(Name = 'Bulk Tracker ' + i));
        }

        Test.startTest();
        insert trackers;
        Test.stopTest();

        List<CustomerTracker__c> inserted = [
            SELECT Status__c FROM CustomerTracker__c
            WHERE Name LIKE 'Bulk Tracker%'
        ];
        System.assertEquals(200, inserted.size(), 'All 200 records should be inserted');
        for (CustomerTracker__c ct : inserted) {
            System.assertEquals('Pending', ct.Status__c,
                'Default status Pending should be applied to all bulk inserts');
        }

        // Each insert should have created a Task
        List<Task> tasks = [
            SELECT Id FROM Task
            WHERE WhatId IN :new Map<Id, CustomerTracker__c>(inserted).keySet()
        ];
        System.assertEquals(200, tasks.size(),
            'One follow-up Task should be created for each of the 200 records');
    }

    // ---------------------------------------------------------------------------
    // Bulk Update — 200 records deactivated in single DML
    // ---------------------------------------------------------------------------
    @isTest
    static void testBulkUpdate_DeactivateAll() {
        List<CustomerTracker__c> trackers = new List<CustomerTracker__c>();
        for (Integer i = 0; i < 200; i++) {
            trackers.add(new CustomerTracker__c(
                Name     = 'Bulk Deactivate ' + i,
                Status__c = 'Active'
            ));
        }
        insert trackers;

        // Deactivate all 200 in one DML
        for (CustomerTracker__c ct : trackers) {
            ct.Status__c = 'Inactive';
        }

        Test.startTest();
        update trackers;
        Test.stopTest();

        List<CustomerTracker__c> updated = [
            SELECT Status__c FROM CustomerTracker__c
            WHERE Id IN :new Map<Id, CustomerTracker__c>(trackers).keySet()
        ];
        for (CustomerTracker__c ct : updated) {
            System.assertEquals('Inactive', ct.Status__c,
                'All 200 trackers should be deactivated');
        }
    }
}
