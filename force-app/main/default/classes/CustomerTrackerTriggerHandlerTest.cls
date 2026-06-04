/**
 * CustomerTrackerTriggerHandlerTest
 * Comprehensive test class for CustomerTrackerTrigger and CustomerTrackerTriggerHandler.
 * Covers: positive, negative, bulk (200 records), edge-case, and recursion-guard scenarios.
 */
@isTest
private class CustomerTrackerTriggerHandlerTest {

    // -------------------------------------------------------------------------
    // TEST DATA SETUP
    // -------------------------------------------------------------------------
    @testSetup
    static void setup() {
        // No shared data required — each test method creates its own records
        // to ensure full isolation and avoid inter-test dependencies.
    }

    // Helper: get or create a Sys Admin profile user for owner-transfer tests
    private static User createAdminUser(String alias) {
        Profile adminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        return new User(
            FirstName          = 'Test',
            LastName           = 'Admin ' + alias,
            Alias              = alias,
            Email              = alias + '@example.invalid',
            Username           = alias + '@example.invalid.' + UserInfo.getOrganizationId(),
            EmailEncodingKey   = 'UTF-8',
            LanguageLocaleKey  = 'en_US',
            LocaleSidKey       = 'en_US',
            TimeZoneSidKey     = 'America/Los_Angeles',
            ProfileId          = adminProfile.Id
        );
    }

    // -------------------------------------------------------------------------
    // BEFORE INSERT — auto-name
    // -------------------------------------------------------------------------
    @isTest
    static void beforeInsert_autoName_whenNameIsBlank() {
        CustomerTracker__c ct = new CustomerTracker__c(Name = null);

        Test.startTest();
        insert ct;
        Test.stopTest();

        CustomerTracker__c result = [SELECT Name FROM CustomerTracker__c WHERE Id = :ct.Id];
        System.assert(result.Name.startsWith('CT-'), 'Name should start with CT-');
        System.assert(result.Name.length() > 5, 'Name should contain date/sequence segment');
    }

    @isTest
    static void beforeInsert_preservesSuppliedName() {
        CustomerTracker__c ct = new CustomerTracker__c(Name = 'My Custom Name');

        Test.startTest();
        insert ct;
        Test.stopTest();

        CustomerTracker__c result = [SELECT Name FROM CustomerTracker__c WHERE Id = :ct.Id];
        System.assertEquals('My Custom Name', result.Name, 'User-supplied name should be preserved');
    }

    @isTest
    static void beforeInsert_bulk200_allNamesPopulated() {
        List<CustomerTracker__c> records = new List<CustomerTracker__c>();
        for (Integer i = 0; i < 200; i++) {
            records.add(new CustomerTracker__c(Name = null));
        }

        Test.startTest();
        insert records;
        Test.stopTest();

        List<CustomerTracker__c> results = [SELECT Name FROM CustomerTracker__c WHERE Id IN :records];
        System.assertEquals(200, results.size(), 'All 200 records should be inserted');
        for (CustomerTracker__c ct : results) {
            System.assert(String.isNotBlank(ct.Name), 'No record should have a blank name after insert');
            System.assert(ct.Name.startsWith('CT-'), 'Auto-generated name should start with CT-');
        }
    }

    // -------------------------------------------------------------------------
    // BEFORE UPDATE — name protection
    // -------------------------------------------------------------------------
    @isTest
    static void beforeUpdate_preventsNameBlankOut() {
        CustomerTracker__c ct = new CustomerTracker__c(Name = 'Important Name');
        insert ct;

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            ct.Name = null;
            update ct;
        } catch (DmlException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'DmlException should be thrown when Name is cleared');
        CustomerTracker__c result = [SELECT Name FROM CustomerTracker__c WHERE Id = :ct.Id];
        System.assertEquals('Important Name', result.Name, 'Name should remain unchanged');
    }

    @isTest
    static void beforeUpdate_allowsLegitimateNameChange() {
        CustomerTracker__c ct = new CustomerTracker__c(Name = 'Old Name');
        insert ct;

        Test.startTest();
        ct.Name = 'New Name';
        update ct;
        Test.stopTest();

        CustomerTracker__c result = [SELECT Name FROM CustomerTracker__c WHERE Id = :ct.Id];
        System.assertEquals('New Name', result.Name, 'Legitimate name change should be allowed');
    }

    // -------------------------------------------------------------------------
    // AFTER INSERT — follow-up Task creation
    // -------------------------------------------------------------------------
    @isTest
    static void afterInsert_createsFollowUpTask() {
        CustomerTracker__c ct = new CustomerTracker__c(Name = 'Task Test');

        Test.startTest();
        insert ct;
        Test.stopTest();

        List<Task> tasks = [SELECT Subject, OwnerId, WhatId FROM Task WHERE WhatId = :ct.Id];
        System.assertEquals(1, tasks.size(), 'Exactly one Task should be created on insert');
        System.assert(tasks[0].Subject.contains('Task Test'), 'Task subject should reference the CT name');
        System.assertEquals(ct.Id, tasks[0].WhatId, 'Task WhatId should point to the CustomerTracker');
    }

    @isTest
    static void afterInsert_bulk200_createsOneTaskPerRecord() {
        List<CustomerTracker__c> records = new List<CustomerTracker__c>();
        for (Integer i = 0; i < 200; i++) {
            records.add(new CustomerTracker__c(Name = 'Bulk CT ' + i));
        }

        Test.startTest();
        insert records;
        Test.stopTest();

        Set<Id> ctIds = new Map<Id, CustomerTracker__c>(records).keySet();
        List<Task> tasks = [SELECT Id FROM Task WHERE WhatId IN :ctIds];
        System.assertEquals(200, tasks.size(), '200 Tasks should be created for 200 inserted records');
    }

    @isTest
    static void afterInsert_recursionGuardPreventsDoubleInsert() {
        // Reset guard to ensure clean state for this test
        CustomerTrackerTriggerHandler.hasRun = false;

        CustomerTracker__c ct = new CustomerTracker__c(Name = 'Guard Test');

        Test.startTest();
        insert ct;
        Test.stopTest();

        // Guard should be set after first run
        System.assert(CustomerTrackerTriggerHandler.hasRun, 'hasRun should be true after first execution');

        // Verify only one Task was created (not two)
        List<Task> tasks = [SELECT Id FROM Task WHERE WhatId = :ct.Id];
        System.assertEquals(1, tasks.size(), 'Recursion guard should prevent duplicate Task creation');
    }

    // -------------------------------------------------------------------------
    // AFTER UPDATE — owner-change Task creation
    // -------------------------------------------------------------------------
    @isTest
    static void afterUpdate_createsTaskOnOwnerChange() {
        User otherUser = createAdminUser('cttu1');
        insert otherUser;

        CustomerTracker__c ct = new CustomerTracker__c(Name = 'Owner Change Test');
        insert ct;
        // Drain any insert Tasks
        List<Task> insertTasks = [SELECT Id FROM Task WHERE WhatId = :ct.Id];
        delete insertTasks;

        Test.startTest();
        System.runAs(otherUser) {
            ct.OwnerId = otherUser.Id;
            update ct;
        }
        Test.stopTest();

        List<Task> tasks = [SELECT Subject, OwnerId FROM Task WHERE WhatId = :ct.Id];
        System.assertEquals(1, tasks.size(), 'One Task should be created on owner change');
        System.assert(tasks[0].Subject.contains('Ownership transfer'), 'Task subject should mention ownership transfer');
        System.assertEquals(otherUser.Id, tasks[0].OwnerId, 'Task should be assigned to the new owner');
    }

    @isTest
    static void afterUpdate_noTaskWhenOwnerUnchanged() {
        CustomerTracker__c ct = new CustomerTracker__c(Name = 'No Task Test');
        insert ct;
        // Drain insert Tasks
        delete [SELECT Id FROM Task WHERE WhatId = :ct.Id];

        Test.startTest();
        ct.Name = 'Updated Name';
        update ct;
        Test.stopTest();

        List<Task> tasks = [SELECT Id FROM Task WHERE WhatId = :ct.Id];
        System.assertEquals(0, tasks.size(), 'No Task should be created when owner is unchanged');
    }

    @isTest
    static void afterUpdate_bulk200_ownerChangeTasks() {
        User otherUser = createAdminUser('cttu2');
        insert otherUser;

        List<CustomerTracker__c> records = new List<CustomerTracker__c>();
        for (Integer i = 0; i < 200; i++) {
            records.add(new CustomerTracker__c(Name = 'Bulk Update CT ' + i));
        }
        insert records;
        // Drain insert Tasks
        Set<Id> ctIds = new Map<Id, CustomerTracker__c>(records).keySet();
        delete [SELECT Id FROM Task WHERE WhatId IN :ctIds];

        Test.startTest();
        System.runAs(otherUser) {
            for (CustomerTracker__c ct : records) {
                ct.OwnerId = otherUser.Id;
            }
            update records;
        }
        Test.stopTest();

        List<Task> tasks = [SELECT Id FROM Task WHERE WhatId IN :ctIds];
        System.assertEquals(200, tasks.size(), '200 Tasks should be created for 200 owner-change updates');
    }
}