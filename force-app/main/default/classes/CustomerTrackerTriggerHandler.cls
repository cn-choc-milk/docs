/**
 * CustomerTrackerTriggerHandler
 *
 * Handler class for all CustomerTracker__c trigger events.
 * Follows the One Trigger Per Object pattern, routing context-specific
 * work to dedicated static methods. All operations are bulkified to
 * handle 200+ records per transaction without hitting governor limits.
 *
 * Business Logic:
 *  - Before Insert: Set default Status; validate allowed values; stamp LastActivityDate
 *  - Before Update: Enforce Status transition rules; refresh LastActivityDate on change
 *  - Before Delete: Block deletion of Active records
 *  - After Insert:  Create a follow-up Task for each new record
 *  - After Update:  When Status flips to Inactive, close all open related Tasks
 */
public with sharing class CustomerTrackerTriggerHandler {

    // ---------------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------------
    @TestVisible private static final String STATUS_ACTIVE   = 'Active';
    @TestVisible private static final String STATUS_INACTIVE = 'Inactive';
    @TestVisible private static final String STATUS_PENDING  = 'Pending';

    private static final Set<String> VALID_STATUSES = new Set<String>{
        STATUS_ACTIVE, STATUS_INACTIVE, STATUS_PENDING
    };

    // ---------------------------------------------------------------------------
    // Before Insert
    // ---------------------------------------------------------------------------
    public static void beforeInsert(List<CustomerTracker__c> newRecords) {
        for (CustomerTracker__c ct : newRecords) {
            // Apply default status when omitted
            if (String.isBlank(ct.Status__c)) {
                ct.Status__c = STATUS_PENDING;
            }
            // Validate against allowed status values
            if (!VALID_STATUSES.contains(ct.Status__c)) {
                ct.addError('Status must be Active, Inactive, or Pending. Received: ' + ct.Status__c);
            }
            // Stamp initial activity date
            if (ct.LastActivityDate__c == null) {
                ct.LastActivityDate__c = Date.today();
            }
        }
    }

    // ---------------------------------------------------------------------------
    // Before Update
    // ---------------------------------------------------------------------------
    public static void beforeUpdate(List<CustomerTracker__c> newRecords,
                                    Map<Id, CustomerTracker__c> oldMap) {
        for (CustomerTracker__c ct : newRecords) {
            CustomerTracker__c oldCt = oldMap.get(ct.Id);

            // Validate new status value
            if (!VALID_STATUSES.contains(ct.Status__c)) {
                ct.addError('Status must be Active, Inactive, or Pending. Received: ' + ct.Status__c);
                continue;
            }

            // Disallow reverting Active -> Pending (must go via Inactive)
            if (oldCt.Status__c == STATUS_ACTIVE && ct.Status__c == STATUS_PENDING) {
                ct.addError('Cannot revert an Active Customer Tracker to Pending. Set Status to Inactive first.');
            }

            // Refresh activity date on any status change
            if (ct.Status__c != oldCt.Status__c) {
                ct.LastActivityDate__c = Date.today();
            }
        }
    }

    // ---------------------------------------------------------------------------
    // Before Delete
    // ---------------------------------------------------------------------------
    public static void beforeDelete(List<CustomerTracker__c> oldRecords) {
        for (CustomerTracker__c ct : oldRecords) {
            if (ct.Status__c == STATUS_ACTIVE) {
                ct.addError(
                    'Active Customer Tracker records cannot be deleted. ' +
                    'Set Status to Inactive before deleting.'
                );
            }
        }
    }

    // ---------------------------------------------------------------------------
    // After Insert
    // ---------------------------------------------------------------------------
    public static void afterInsert(List<CustomerTracker__c> newRecords) {
        List<Task> tasksToInsert = new List<Task>();
        for (CustomerTracker__c ct : newRecords) {
            Task t         = new Task();
            t.Subject      = 'Follow up: Customer Tracker created – ' + ct.Name;
            t.WhatId       = ct.Id;
            t.OwnerId      = ct.OwnerId;
            t.Status       = 'Not Started';
            t.Priority     = 'Normal';
            t.ActivityDate = Date.today().addDays(3);
            t.Description  = 'Auto-generated follow-up task. Review and update tracker status as needed.';
            tasksToInsert.add(t);
        }
        if (!tasksToInsert.isEmpty()) {
            insert tasksToInsert; // single DML — bulkified
        }
    }

    // ---------------------------------------------------------------------------
    // After Update
    // ---------------------------------------------------------------------------
    public static void afterUpdate(List<CustomerTracker__c> newRecords,
                                   Map<Id, CustomerTracker__c> oldMap) {
        // Collect IDs of records newly transitioned to Inactive
        Set<Id> deactivatedIds = new Set<Id>();
        for (CustomerTracker__c ct : newRecords) {
            if (ct.Status__c == STATUS_INACTIVE
                    && oldMap.get(ct.Id).Status__c != STATUS_INACTIVE) {
                deactivatedIds.add(ct.Id);
            }
        }

        if (deactivatedIds.isEmpty()) {
            return;
        }

        // Close all open Tasks linked to newly-deactivated trackers
        List<Task> openTasks = [
            SELECT Id, Status
            FROM   Task
            WHERE  WhatId    IN :deactivatedIds
            AND    IsClosed   = false
            AND    IsArchived = false
        ];

        if (!openTasks.isEmpty()) {
            for (Task t : openTasks) {
                t.Status = 'Completed';
            }
            update openTasks; // single DML — bulkified
        }
    }
}
