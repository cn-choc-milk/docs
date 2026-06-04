@isTest
private class CustomerTrackerTriggerHandlerTest {

    // -----------------------------------------------------------------------
    // TEST SETUP
    // -----------------------------------------------------------------------
    @testSetup
    static void setup() {
        // Admin user for owner-change tests (avoids TRANSFER_REQUIRES_READ)
        Profile adminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User adminUser = new User(
            FirstName       = 'Tracker',
            LastName        = 'TestUser',
            Alias           = 'trkusr',
            Email           = 'tracker.testuser@example.synapse.test',
            Username        = 'tracker.testuser.' + DateTime.now().getTime() + '@example.synapse.test',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey    = 'en_US',
            TimeZoneSidKey  = 'America/Los_Angeles',
            ProfileId       = adminProfile.Id
        );
        insert adminUser;
    }

    // -----------------------------------------------------------------------
    // BEFORE INSERT: auto-naming
    // -----------------------------------------------------------------------
    @isTest
    static void beforeInsert_autoName_whenNameIsBlank() {
        CustomerTracker__c ct = new CustomerTracker__c(Name = null);
        Test.startTest();
        insert ct;
        Test.stopTest();
        ct = [SELECT Name FROM CustomerTracker__c WHERE Id = :ct.Id];
        System.assert(ct.Name.startsWith('CT-'), 'Name should start with CT-');
        System.assertEquals(12, ct.Name.length(), 'Name format should be CT-YYYYMMDD-NNN (12 chars)');
    }

    @isTest
    static void beforeInsert_preservesSuppliedName() {
        CustomerTracker__c ct = new CustomerTracker__c(Name = 'My Tracker');
        Test.startTest();
        insert ct;
        Test.stopTest();
        ct = [SELECT Name FROM CustomerTracker__c WHERE Id = :ct.Id];
        System.assertEquals('My Tracker', ct.Name, 'User-supplied name should be preserved');
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
        List<CustomerTracker__c> results = [SELECT Name FROM CustomerTracker__c];
        System.assertEquals(200, results.size(), '200 records should be inserted');
        for (CustomerTracker__c r : results) {
            System.assert(String.isNotBlank(r.Name), 'Every record should have a non-blank Name');
        }
    }

    // -----------------------------------------------------------------------
    // BEFORE UPDATE: prevent name clearing
    // -----------------------------------------------------------------------
    @isTest
    static void beforeUpdate_preventsNameBlankOut() {
        CustomerTracker__c ct = new CustomerTracker__c(Name = 'OriginalName');
        insert ct;
        ct.Name = null;
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            update ct;
        } catch (DmlException e) {
            exceptionThrown = true;
            System.assert(
                e.getMessage().contains('Customer Tracker Name cannot be cleared'),
                'Expected name-clearing error message'
            );
        }
        Test.stopTest();
        System.assert(exceptionThrown, 'DmlException expected when Name is blanked');
    }

    @isTest
    static void beforeUpdate_allowsLegitimateNameChange() {
        CustomerTracker__c ct = new CustomerTracker__c(Name = 'OldName');
        insert ct;
        ct.Name = 'NewName';
        Test.startTest();
        update ct;
        Test.stopTest();
        ct = [SELECT Name FROM CustomerTracker__c WHERE Id = :ct.Id];
        System.assertEquals('NewName', ct.Name, 'Legitimate name change should be allowed');
    }

    // -----------------------------------------------------------------------
    // AFTER INSERT: follow-up Task creation
    // -----------------------------------------------------------------------
    @isTest
    static void afterInsert_createsFollowUpTask() {
        CustomerTracker__c ct = new CustomerTracker__c(Name = 'TaskTest');
        Test.startTest();
        insert ct;
        Test.stopTest();
        List<Task> tasks = [SELECT Subject, WhatId, OwnerId, ActivityDate FROM Task WHERE WhatId = :ct.Id];
        System.assertEquals(1, tasks.size(), 'Exactly one follow-up Task should be created');
        System.assert(tasks[0].Subject.contains('TaskTest'), 'Task Subject should reference the tracker name');
        System.assertEquals(ct.Id, tasks[0].WhatId, 'Task WhatId should point to the tracker');
        System.assertEquals(Date.today().addDays(7), tasks[0].ActivityDate, 'Task due date should be 7 days from today');
    }

    @isTest
    static void afterInsert_bulk200_createsOneTaskPerRecord() {
        List<CustomerTracker__c> records = new List<CustomerTracker__c>();
        for (Integer i = 0; i < 200; i++) {
            records.add(new CustomerTracker__c(Name = 'BulkTracker-' + i));
        }
        Test.startTest();
        insert records;
        Test.stopTest();
        List<Id> ids = new List<Id>();
        for (CustomerTracker__c r : records) { ids.add(r.Id); }
        Integer taskCount = [SELECT COUNT() FROM Task WHERE WhatId IN :ids];
        System.assertEquals(200, taskCount, 'One Task per record should be created in bulk');
    }

    @isTest
    static void afterInsert_recursionGuardPreventsDoubleInsert() {
        // Reset static guard before test
        CustomerTrackerTriggerHandler.hasRun = false;
        CustomerTracker__c ct = new CustomerTracker__c(Name = 'RecursionTest');
        Test.startTest();
        insert ct;
        Test.stopTest();
        // Trigger fires once; guard prevents re-entry, so exactly 1 Task expected
        List<Task> tasks = [SELECT Id FROM Task WHERE WhatId = :ct.Id];
        System.assertEquals(1, tasks.size(), 'Recursion guard should allow only one Task per insert');
    }

    // -----------------------------------------------------------------------
    // AFTER UPDATE: owner-change Task creation
    // -----------------------------------------------------------------------
    @isTest
    static void afterUpdate_createsTaskOnOwnerChange() {
        User otherUser = [SELECT Id FROM User WHERE Email = 'tracker.testuser@example.synapse.test' LIMIT 1];
        CustomerTracker__c ct = new CustomerTracker__c(Name = 'OwnerChangeTest');
        insert ct;
        // Delete the after-insert Task so we can isolate the after-update Task
        delete [SELECT Id FROM Task WHERE WhatId = :ct.Id];
        ct.OwnerId = otherUser.Id;
        Test.startTest();
        System.runAs(otherUser) {
            update ct;
        }
        Test.stopTest();
        List<Task> tasks = [SELECT OwnerId FROM Task WHERE WhatId = :ct.Id];
        System.assertEquals(1, tasks.size(), 'One Task should be created on owner change');
        System.assertEquals(otherUser.Id, tasks[0].OwnerId, 'Task should be assigned to the new owner');
    }

    @isTest
    static void afterUpdate_noTaskWhenOwnerUnchanged() {
        CustomerTracker__c ct = new CustomerTracker__c(Name = 'NoOwnerChange');
        insert ct;
        delete [SELECT Id FROM Task WHERE WhatId = :ct.Id];
        ct.Name = 'NoOwnerChange-Updated';
        Test.startTest();
        update ct;
        Test.stopTest();
        Integer taskCount = [SELECT COUNT() FROM Task WHERE WhatId = :ct.Id];
        System.assertEquals(0, taskCount, 'No Task should be created when owner does not change');
    }

    @isTest
    static void afterUpdate_bulk200_ownerChangeTasks() {
        User otherUser = [SELECT Id FROM User WHERE Email = 'tracker.testuser@example.synapse.test' LIMIT 1];
        List<CustomerTracker__c> records = new List<CustomerTracker__c>();
        for (Integer i = 0; i < 200; i++) {
            records.add(new CustomerTracker__c(Name = 'BulkOwner-' + i));
        }
        insert records;
        List<Id> ids = new List<Id>();
        for (CustomerTracker__c r : records) { ids.add(r.Id); }
        delete [SELECT Id FROM Task WHERE WhatId IN :ids];
        for (CustomerTracker__c r : records) {
            r.OwnerId = otherUser.Id;
        }
        Test.startTest();
        System.runAs(otherUser) {
            update records;
        }
        Test.stopTest();
        Integer taskCount = [SELECT COUNT() FROM Task WHERE WhatId IN :ids];
        System.assertEquals(200, taskCount, '200 Tasks should be created for 200 owner changes');
    }
}