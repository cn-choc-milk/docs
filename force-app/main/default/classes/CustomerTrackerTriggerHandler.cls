/**
 * CustomerTrackerTriggerHandler
 * Handler class for CustomerTrackerTrigger.
 * Implements bulkified, governor-limit-safe business logic for CustomerTracker__c.
 *
 * Business Rules:
 *   before insert  — Auto-populate blank Name with CT-YYYYMMDD-NNN sequence
 *   before update  — Prevent clearing a Name once it has been set
 *   after insert   — Create a follow-up Task for the owner of each new record
 *   after update   — Create a follow-up Task for the new owner when OwnerId changes
 */
public with sharing class CustomerTrackerTriggerHandler {

    // Recursion guard — prevents re-entrant after-insert execution when Tasks are created
    @TestVisible
    private static Boolean hasRun = false;

    // -------------------------------------------------------------------------
    // BEFORE INSERT
    // -------------------------------------------------------------------------
    public static void beforeInsert(List<CustomerTracker__c> newRecords) {
        // Build a date-based prefix once for the entire batch
        String datePart = Datetime.now().format('yyyyMMdd');
        Integer seq = 1;

        for (CustomerTracker__c ct : newRecords) {
            if (String.isBlank(ct.Name)) {
                // Pad sequence number to 3 digits
                ct.Name = 'CT-' + datePart + '-' + String.valueOf(seq).leftPad(3, '0');
            }
            seq++;
        }
    }

    // -------------------------------------------------------------------------
    // BEFORE UPDATE
    // -------------------------------------------------------------------------
    public static void beforeUpdate(
        List<CustomerTracker__c> newRecords,
        Map<Id, CustomerTracker__c> oldMap
    ) {
        for (CustomerTracker__c ct : newRecords) {
            CustomerTracker__c oldCt = oldMap.get(ct.Id);
            // Prevent blanking out a name that was previously set
            if (String.isBlank(ct.Name) && String.isNotBlank(oldCt.Name)) {
                ct.addError('Customer Tracker Name cannot be removed once it has been set.');
            }
        }
    }

    // -------------------------------------------------------------------------
    // AFTER INSERT
    // -------------------------------------------------------------------------
    public static void afterInsert(List<CustomerTracker__c> newRecords) {
        if (hasRun) {
            return;
        }
        hasRun = true;

        List<Task> tasks = new List<Task>();
        Date dueDate = Date.today().addDays(7);

        for (CustomerTracker__c ct : newRecords) {
            tasks.add(new Task(
                Subject      = 'Follow up on Customer Tracker: ' + ct.Name,
                OwnerId      = ct.OwnerId,
                WhatId       = ct.Id,
                ActivityDate = dueDate,
                Status       = 'Not Started',
                Priority     = 'Normal',
                Description  = 'Automatically created follow-up task for new Customer Tracker record.'
            ));
        }

        if (!tasks.isEmpty()) {
            // Partial-success insert: a bad Task should not roll back the parent record
            Database.insert(tasks, false);
        }
    }

    // -------------------------------------------------------------------------
    // AFTER UPDATE
    // -------------------------------------------------------------------------
    public static void afterUpdate(
        List<CustomerTracker__c> newRecords,
        Map<Id, CustomerTracker__c> oldMap
    ) {
        List<Task> tasks = new List<Task>();
        Date dueDate = Date.today().addDays(7);

        for (CustomerTracker__c ct : newRecords) {
            CustomerTracker__c oldCt = oldMap.get(ct.Id);
            // Only create a Task when the owner changes
            if (ct.OwnerId != oldCt.OwnerId) {
                tasks.add(new Task(
                    Subject      = 'Ownership transfer — review Customer Tracker: ' + ct.Name,
                    OwnerId      = ct.OwnerId,
                    WhatId       = ct.Id,
                    ActivityDate = dueDate,
                    Status       = 'Not Started',
                    Priority     = 'Normal',
                    Description  = 'Customer Tracker ownership was transferred. New owner should review the record.'
                ));
            }
        }

        if (!tasks.isEmpty()) {
            Database.insert(tasks, false);
        }
    }
}