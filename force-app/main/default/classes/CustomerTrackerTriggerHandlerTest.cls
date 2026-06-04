/**
 * CustomerTrackerTriggerHandlerTest
 * Comprehensive test class for CustomerTrackerTriggerHandler.
 * Covers: before insert auto-name, before update name protection,
 *         after insert task creation, after update owner-change task creation,
 *         bulk (200-record) paths, and recursion guard.
 */
@isTest
private class CustomerTrackerTriggerHandlerTest {

    @testSetup
    static void setup() {
        // No shared setup needed — each method creates its own isolated data
    }

    // ─── Before Insert: Auto-Name ─────────────────────────────────────────

    @isTest
    static void beforeInsert_autoName_whenNameIsBlank() {
        CustomerTracker__c ct = new CustomerTracker__c();

        Test.startTest();
        insert ct;
        Test.stopTest();

        CustomerTracker__c result = [SELECT Name FROM CustomerTracker__c WHERE Id = :ct.Id];
        // Format: CT-YYYYMMDD-NNN  e.g. CT-20260604-001 = 15 chars
        System.assert(
            result.Name.startsWith('CT-'),
            'Auto-generated name should start with CT-'
        );
        // Length: 'CT-' (3) + 8-digit date (8) + '-' (1) + 3-digit counter (3) = 15
        System.assertEquals(
            15,
            result.Name.length(),
            'Auto-generated name format CT-YYYYMMDD-NNN should be 15 chars'
        );
    }

    @isTest
    static void beforeInsert_preservesSuppliedName() {
        CustomerTracker__c ct = new CustomerTracker__c(Name = 'My Custom Tracker');

        Test.startTest();
        insert ct;
        Test.stopTest();

        CustomerTracker__c result = [SELECT Name FROM CustomerTracker__c WHERE Id = :ct.Id];
        System.assertEquals('My Custom Tracker', result.Name, 'Supplied name must be preserved');
    }

    @isTest
    static void beforeInsert_bulk200_allNamesPopulated() {
        List<CustomerTracker__c> cts = new List<CustomerTracker__c>();
        for (Integer i = 0; i < 200; i++) {
            cts.add(new CustomerTracker__c());
        }

        Test.startTest();
        insert cts;
        Test.stopTest();

        List<CustomerTracker__c> results = [
            SELECT Name FROM CustomerTracker__c WHERE Id IN :cts
        ];
        System.assertEquals(200, results.size(), 'All 200 records should be inserted');
        for (CustomerTracker__c r : results) {
            System.assert(String.isNotBlank(r.Name), 'Every auto-named record must have a non-blank Name');
            System.assert(r.Name.startsWith('CT-'), 'Auto-generated names must start with CT-');
        }
    }

    // ─── Before Update: Protect Name ────────────────────────────────────

    @isTest
    static void beforeUpdate_preventsNameBlankOut() {
        CustomerTracker__c ct = new CustomerTracker__c(Name = 'Valid Name');
        insert ct;

        ct.Name = '';

        Test.startTest();
        Boolean caughtException = false;
        try {
            update ct;
        } catch (DmlException e) {
            caughtException = true;
        }
        Test.stopTest();

        System.assert(caughtException, 'DmlException expected when Name is blanked out');
    }

    @isTest
    static void beforeUpdate_allowsLegitimateNameChange() {
        CustomerTracker__c ct = new CustomerTracker__c(Name = 'Old Name');
        insert ct;

        ct.Name = 'New Valid Name';

        Test.startTest();
        update ct;
        Test.stopTest();

        CustomerTracker__c result = [SELECT Name FROM CustomerTracker__c WHERE Id = :ct.Id];
        System.assertEquals('New Valid Name', result.Name, 'Legitimate name change should be allowed');
    }

    // ─── After Insert: Follow-Up Task Creation ──────────────────────────

    @isTest
    static void afterInsert_createsFollowUpTask() {
        CustomerTracker__c ct = new CustomerTracker__c(Name = 'Task Test');

        Test.startTest();
        insert ct;
        Test.stopTest();

        List<Task> tasks = [SELECT Subject, WhatId, OwnerId, ActivityDate, Status
                            FROM Task WHERE WhatId = :ct.Id];
        System.assertEquals(1, tasks.size(), 'One follow-up Task should be created on insert');
        System.assert(tasks[0].Subject.contains('Follow-up'), 'Task subject should contain Follow-up');
        System.assertEquals(ct.Id, tasks[0].WhatId, 'Task WhatId should point to the CustomerTracker');
        System.assertEquals(Date.today().addDays(7), tasks[0].ActivityDate, 'Due date should be +7 days');
        System.assertEquals('Not Started', tasks[0].Status, 'Task status should be Not Started');
    }

    @isTest
    static void afterInsert_bulk200_createsOneTaskPerRecord() {
        List<CustomerTracker__c> cts = new List<CustomerTracker__c>();
        for (Integer i = 0; i < 200; i++) {
            cts.add(new CustomerTracker__c(Name = 'Bulk CT ' + i));
        }

        Test.startTest();
        insert cts;
        Test.stopTest();

        List<Id> ctIds = new List<Id>();
        for (CustomerTracker__c ct : cts) ctIds.add(ct.Id);

        List<Task> tasks = [SELECT Id FROM Task WHERE WhatId IN :ctIds];
        System.assertEquals(200, tasks.size(), '200 Tasks should be created for 200 inserts');
    }

    @isTest
    static void afterInsert_recursionGuardPreventsDoubleInsert() {
        CustomerTrackerTriggerHandler.hasRun = false;

        CustomerTracker__c ct = new CustomerTracker__c(Name = 'Guard Test');

        Test.startTest();
        insert ct;
        Test.stopTest();

        System.assert(
            CustomerTrackerTriggerHandler.hasRun,
            'hasRun flag should be true after first insert'
        );
    }

    // ─── After Update: Owner-Change Task ───────────────────────────────

    @isTest
    static void afterUpdate_createsTaskOnOwnerChange() {
        // Create a second user with the same profile (System Admin) so they
        // have read access to CustomerTracker__c and ownership transfer succeeds.
        User otherUser = createAdminUser('other.cttestuser@testorg.com.invalid');

        CustomerTracker__c ct = new CustomerTracker__c(Name = 'Owner Change Test');
        insert ct;

        Test.startTest();
        ct.OwnerId = otherUser.Id;
        update ct;
        Test.stopTest();

        // Expect 2 Tasks: 1 from insert + 1 from owner change
        List<Task> tasks = [SELECT Subject, OwnerId FROM Task WHERE WhatId = :ct.Id
                            ORDER BY CreatedDate ASC];
        System.assertEquals(2, tasks.size(), 'One extra Task expected for owner change');
        Task ownerTask = tasks[1];
        System.assert(
            ownerTask.Subject.contains('Ownership Transfer'),
            'Owner-change task should mention Ownership Transfer'
        );
        System.assertEquals(otherUser.Id, ownerTask.OwnerId, 'Task owner should be the new owner');
    }

    @isTest
    static void afterUpdate_noTaskWhenOwnerUnchanged() {
        CustomerTracker__c ct = new CustomerTracker__c(Name = 'No Change Test');
        insert ct;

        Integer tasksAfterInsert = [SELECT COUNT() FROM Task WHERE WhatId = :ct.Id];

        ct.Name = 'Updated Name';
        Test.startTest();
        update ct;
        Test.stopTest();

        Integer tasksAfterUpdate = [SELECT COUNT() FROM Task WHERE WhatId = :ct.Id];
        System.assertEquals(
            tasksAfterInsert,
            tasksAfterUpdate,
            'No new Task should be created when only Name changes (no owner change)'
        );
    }

    @isTest
    static void afterUpdate_bulk200_ownerChangeTasks() {
        User otherUser = createAdminUser('bulk.cttestuser@testorg.com.invalid');

        List<CustomerTracker__c> cts = new List<CustomerTracker__c>();
        for (Integer i = 0; i < 200; i++) {
            cts.add(new CustomerTracker__c(Name = 'Bulk Update CT ' + i));
        }
        insert cts;

        for (CustomerTracker__c ct : cts) {
            ct.OwnerId = otherUser.Id;
        }

        Test.startTest();
        update cts;
        Test.stopTest();

        List<Id> ctIds = new List<Id>();
        for (CustomerTracker__c ct : cts) ctIds.add(ct.Id);

        List<Task> ownerChangeTasks = [
            SELECT Id FROM Task
            WHERE WhatId IN :ctIds
            AND Subject LIKE 'Ownership Transfer%'
        ];
        System.assertEquals(
            200,
            ownerChangeTasks.size(),
            '200 owner-change Tasks should be created for 200 record updates'
        );
    }

    // ─── Helpers ──────────────────────────────────────────────────────

    /**
     * Create a System Administrator user so ownership transfers succeed
     * (OWD for CustomerTracker__c may be Private; Admin bypasses sharing).
     */
    private static User createAdminUser(String username) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User u = new User(
            FirstName        = 'Test',
            LastName         = 'AdminCTUser',
            Email            = username,
            Username         = username,
            Alias            = 'ctadm',
            TimeZoneSidKey   = 'America/Los_Angeles',
            LocaleSidKey     = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId        = p.Id
        );
        insert u;
        return u;
    }
}
