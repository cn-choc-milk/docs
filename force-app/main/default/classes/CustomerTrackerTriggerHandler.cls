/**
 * CustomerTrackerTriggerHandler
 * Handler class for all CustomerTracker__c trigger logic.
 * Follows the One-Trigger-Per-Object pattern with a dedicated handler.
 *
 * Responsibilities:
 *   - before insert : auto-populate blank Name field (CT-YYYYMMDD-NNN format)
 *   - before update : prevent Name from being cleared
 *   - after insert  : create a follow-up Task for the record owner (+7 days)
 *   - after update  : create a follow-up Task when OwnerId changes
 */
public with sharing class CustomerTrackerTriggerHandler {

    // Recursion guard — prevents re-entry during task creation
    @TestVisible
    private static Boolean hasRun = false;

    // ------------------------------------------------------------------ //
    // Dispatch entry point called from the trigger
    // ------------------------------------------------------------------ //
    public static void dispatch(
            List<CustomerTracker__c> newList,
            List<CustomerTracker__c> oldList,
            Map<Id, CustomerTracker__c> newMap,
            Map<Id, CustomerTracker__c> oldMap,
            TriggerOperation operation) {

        switch on operation {
            when BEFORE_INSERT {
                beforeInsert(newList);
            }
            when BEFORE_UPDATE {
                beforeUpdate(newList, oldMap);
            }
            when AFTER_INSERT {
                afterInsert(newList);
            }
            when AFTER_UPDATE {
                afterUpdate(newList, oldMap);
            }
        }
    }

    // ------------------------------------------------------------------ //
    // BEFORE INSERT
    // Auto-populate blank Name with CT-YYYYMMDD-NNN pattern
    // ------------------------------------------------------------------ //
    @TestVisible
    private static void beforeInsert(List<CustomerTracker__c> newList) {
        Integer counter = 1;
        String datePart = Datetime.now().format('yyyyMMdd');
        for (CustomerTracker__c ct : newList) {
            if (String.isBlank(ct.Name)) {
                ct.Name = 'CT-' + datePart + '-' + String.valueOf(counter).leftPad(3, '0');
                counter++;
            }
        }
    }

    // ------------------------------------------------------------------ //
    // BEFORE UPDATE
    // Prevent Name from being cleared or blanked out
    // ------------------------------------------------------------------ //
    @TestVisible
    private static void beforeUpdate(List<CustomerTracker__c> newList, Map<Id, CustomerTracker__c> oldMap) {
        for (CustomerTracker__c ct : newList) {
            if (String.isBlank(ct.Name)) {
                ct.Name.addError('CustomerTracker Name cannot be blank. Please provide a valid name.');
            }
        }
    }

    // ------------------------------------------------------------------ //
    // AFTER INSERT
    // Create a follow-up Task for the record owner due in 7 days
    // ------------------------------------------------------------------ //
    @TestVisible
    private static void afterInsert(List<CustomerTracker__c> newList) {
        if (hasRun) {
            return;
        }
        hasRun = true;
        List<Task> tasks = buildFollowUpTasks(newList);
        if (!tasks.isEmpty()) {
            insert tasks;
        }
    }

    // ------------------------------------------------------------------ //
    // AFTER UPDATE
    // Create a follow-up Task when OwnerId changes
    // ------------------------------------------------------------------ //
    @TestVisible
    private static void afterUpdate(List<CustomerTracker__c> newList, Map<Id, CustomerTracker__c> oldMap) {
        List<CustomerTracker__c> ownerChanged = new List<CustomerTracker__c>();
        for (CustomerTracker__c ct : newList) {
            CustomerTracker__c oldCt = oldMap.get(ct.Id);
            if (ct.OwnerId != oldCt.OwnerId) {
                ownerChanged.add(ct);
            }
        }
        if (!ownerChanged.isEmpty()) {
            List<Task> tasks = buildFollowUpTasks(ownerChanged);
            if (!tasks.isEmpty()) {
                insert tasks;
            }
        }
    }

    // ------------------------------------------------------------------ //
    // Helper: build follow-up Task records (bulk-safe, no SOQL/DML in loop)
    // ------------------------------------------------------------------ //
    private static List<Task> buildFollowUpTasks(List<CustomerTracker__c> records) {
        List<Task> tasks = new List<Task>();
        Date dueDate = Date.today().addDays(7);
        for (CustomerTracker__c ct : records) {
            tasks.add(new Task(
                Subject       = 'Follow up on Customer Tracker: ' + ct.Name,
                WhatId        = ct.Id,
                OwnerId       = ct.OwnerId,
                ActivityDate  = dueDate,
                Status        = 'Not Started',
                Priority      = 'Normal',
                Description   = 'Auto-generated follow-up task for CustomerTracker record ' + ct.Name
            ));
        }
        return tasks;
    }
}