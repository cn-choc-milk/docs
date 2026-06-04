/**
 * CustomerTrackerTriggerHandler
 * ------------------------------
 * Handler class for CustomerTracker__c trigger logic.
 * All methods are bulkified to safely process 200+ records.
 *
 * Business Logic:
 *   beforeInsert  - Auto-assign a tracking number (CT-YYYYMMDD-NNN) when Name is blank
 *   beforeUpdate  - Prevent clearing an already-set Name field
 *   afterInsert   - Create a follow-up Task for the record owner (due in 7 days)
 *   afterUpdate   - Create a follow-up Task when OwnerId changes
 *
 * Assumptions (no spec provided):
 *   - Tracking number format: CT-YYYYMMDD-NNN (date + sequence within the batch)
 *   - Follow-up Task subject: 'Review Customer Tracker: <Name>'
 *   - Tasks use Database.insert with allOrNone=false so a bad Task never rolls back the parent
 *   - Static recursion guard (hasRun) prevents double-firing on after-insert re-entry
 */
public with sharing class CustomerTrackerTriggerHandler {

    // Recursion guard: prevents after-insert from re-firing if a Task insert somehow re-triggers
    @TestVisible
    private static Boolean hasRun = false;

    // -----------------------------------------------------------------------
    // BEFORE INSERT
    // -----------------------------------------------------------------------
    public static void beforeInsert(List<CustomerTracker__c> newRecords) {
        String today = String.valueOf(Date.today()).replace('-', '');
        Integer seq = 1;
        for (CustomerTracker__c ct : newRecords) {
            if (String.isBlank(ct.Name)) {
                ct.Name = 'CT-' + today + '-' + String.valueOf(seq).leftPad(3, '0');
                seq++;
            }
        }
    }

    // -----------------------------------------------------------------------
    // BEFORE UPDATE
    // -----------------------------------------------------------------------
    public static void beforeUpdate(
        List<CustomerTracker__c> newRecords,
        Map<Id, CustomerTracker__c> oldMap
    ) {
        for (CustomerTracker__c ct : newRecords) {
            CustomerTracker__c oldCt = oldMap.get(ct.Id);
            // Prevent blanking out a Name that was already set
            if (String.isNotBlank(oldCt.Name) && String.isBlank(ct.Name)) {
                ct.Name.addError(
                    'Customer Tracker Name cannot be cleared once it has been assigned.'
                );
            }
        }
    }

    // -----------------------------------------------------------------------
    // AFTER INSERT
    // -----------------------------------------------------------------------
    public static void afterInsert(List<CustomerTracker__c> newRecords) {
        if (hasRun) {
            return;
        }
        hasRun = true;
        List<Task> tasks = new List<Task>();
        Date dueDate = Date.today().addDays(7);
        for (CustomerTracker__c ct : newRecords) {
            tasks.add(buildFollowUpTask(ct.Id, ct.OwnerId, ct.Name, dueDate));
        }
        if (!tasks.isEmpty()) {
            Database.insert(tasks, false); // partial-success: bad Task never rolls back parent
        }
    }

    // -----------------------------------------------------------------------
    // AFTER UPDATE
    // -----------------------------------------------------------------------
    public static void afterUpdate(
        List<CustomerTracker__c> newRecords,
        Map<Id, CustomerTracker__c> oldMap
    ) {
        List<Task> tasks = new List<Task>();
        Date dueDate = Date.today().addDays(7);
        for (CustomerTracker__c ct : newRecords) {
            CustomerTracker__c oldCt = oldMap.get(ct.Id);
            // Only create a follow-up Task when ownership has changed
            if (ct.OwnerId != oldCt.OwnerId) {
                tasks.add(buildFollowUpTask(ct.Id, ct.OwnerId, ct.Name, dueDate));
            }
        }
        if (!tasks.isEmpty()) {
            Database.insert(tasks, false);
        }
    }

    // -----------------------------------------------------------------------
    // PRIVATE HELPERS
    // -----------------------------------------------------------------------
    private static Task buildFollowUpTask(
        Id whatId,
        Id ownerId,
        String trackerName,
        Date dueDate
    ) {
        return new Task(
            WhatId      = whatId,
            OwnerId     = ownerId,
            Subject     = 'Review Customer Tracker: ' + trackerName,
            ActivityDate = dueDate,
            Status      = 'Not Started',
            Priority    = 'Normal',
            Description = 'Auto-generated follow-up task for Customer Tracker record.'
        );
    }
}