/**
 * CustomerTrackerTriggerHandler
 *
 * Handler class for CustomerTracker__c trigger logic.
 * Follows the One-Trigger-Per-Object pattern with bulkified operations.
 *
 * Business logic implemented:
 *   - Before Insert : Auto-populate Name if blank (format: CT-<YYYYMMDD>-<index>)
 *   - Before Update : Prevent the record Name from being cleared once set
 *   - After Insert  : Create a follow-up Task for the record owner on new trackers
 *   - After Update  : Log an owner-change follow-up Task when OwnerId changes
 *
 * @author  SYNTH (Salesforce Apex Specialist)
 * @version 1.0
 */
public with sharing class CustomerTrackerTriggerHandler {

    // ─── Constants ───────────────────────────────────────────────────────────
    private static final String TASK_SUBJECT_NEW    = 'Follow up on new Customer Tracker';
    private static final String TASK_SUBJECT_OWNER  = 'Customer Tracker ownership changed – please review';
    private static final String TASK_STATUS         = 'Not Started';
    private static final String TASK_PRIORITY       = 'Normal';
    private static final Integer TASK_DUE_DAYS      = 7;
    private static final String NAME_PREFIX         = 'CT';

    // ─── Recursion guard ─────────────────────────────────────────────────────
    @TestVisible
    private static Boolean hasRun = false;

    // =========================================================================
    // BEFORE INSERT
    // =========================================================================

    /**
     * Ensure every CustomerTracker__c has a meaningful Name on insert.
     * If the caller did not supply a Name, generate one in the format
     * CT-YYYYMMDD-NNN (e.g., CT-20260604-001).
     *
     * @param newRecords List<CustomerTracker__c> from Trigger.new
     */
    public static void beforeInsert(List<CustomerTracker__c> newRecords) {
        String datePart = Datetime.now().format('yyyyMMdd');
        Integer counter = 1;

        for (CustomerTracker__c ct : newRecords) {
            if (String.isBlank(ct.Name)) {
                ct.Name = NAME_PREFIX + '-' + datePart + '-' + String.valueOf(counter).leftPad(3, '0');
                counter++;
            }
        }
    }

    // =========================================================================
    // BEFORE UPDATE
    // =========================================================================

    /**
     * Prevent the Name from being blanked out on an existing record.
     * If the old name was set and the new name is blank, revert to old value.
     *
     * @param newRecords List<CustomerTracker__c> from Trigger.new
     * @param oldMap     Map<Id, CustomerTracker__c> from Trigger.oldMap
     */
    public static void beforeUpdate(
        List<CustomerTracker__c> newRecords,
        Map<Id, CustomerTracker__c> oldMap
    ) {
        for (CustomerTracker__c ct : newRecords) {
            CustomerTracker__c oldRecord = oldMap.get(ct.Id);
            // Revert a blank-out attempt — name must remain meaningful
            if (String.isBlank(ct.Name) && !String.isBlank(oldRecord.Name)) {
                ct.Name = oldRecord.Name;
            }
        }
    }

    // =========================================================================
    // AFTER INSERT
    // =========================================================================

    /**
     * Create a follow-up Task for the owner of every newly inserted
     * CustomerTracker__c record.  All Tasks are inserted in a single DML
     * statement to stay within governor limits.
     *
     * @param newRecords List<CustomerTracker__c> from Trigger.new
     */
    public static void afterInsert(List<CustomerTracker__c> newRecords) {
        if (hasRun) { return; }
        hasRun = true;

        List<Task> tasksToInsert = new List<Task>();
        Date dueDate = Date.today().addDays(TASK_DUE_DAYS);

        for (CustomerTracker__c ct : newRecords) {
            tasksToInsert.add(buildTask(
                ct.Id,
                ct.OwnerId,
                TASK_SUBJECT_NEW,
                dueDate
            ));
        }

        if (!tasksToInsert.isEmpty()) {
            // Use allOrNone=false so one bad Task does not roll back all inserts
            Database.insert(tasksToInsert, false);
        }
    }

    // =========================================================================
    // AFTER UPDATE
    // =========================================================================

    /**
     * When a CustomerTracker__c record is reassigned to a new owner,
     * create a follow-up Task for the new owner so they are aware of the
     * handoff.  All tasks are inserted in a single DML statement.
     *
     * @param newRecords List<CustomerTracker__c> from Trigger.new
     * @param oldMap     Map<Id, CustomerTracker__c> from Trigger.oldMap
     */
    public static void afterUpdate(
        List<CustomerTracker__c> newRecords,
        Map<Id, CustomerTracker__c> oldMap
    ) {
        List<Task> tasksToInsert = new List<Task>();
        Date dueDate = Date.today().addDays(TASK_DUE_DAYS);

        for (CustomerTracker__c ct : newRecords) {
            CustomerTracker__c oldRecord = oldMap.get(ct.Id);
            // Only act when the owner actually changed
            if (ct.OwnerId != oldRecord.OwnerId) {
                tasksToInsert.add(buildTask(
                    ct.Id,
                    ct.OwnerId,
                    TASK_SUBJECT_OWNER,
                    dueDate
                ));
            }
        }

        if (!tasksToInsert.isEmpty()) {
            Database.insert(tasksToInsert, false);
        }
    }

    // =========================================================================
    // PRIVATE HELPERS
    // =========================================================================

    /**
     * Build a Task SObject linked to a CustomerTracker__c record.
     *
     * @param whatId   Id of the CustomerTracker__c
     * @param ownerId  Id of the Task owner (User or Group)
     * @param subject  Task subject line
     * @param dueDate  Activity date for the task
     * @return         Populated (unsaved) Task
     */
    private static Task buildTask(
        Id whatId,
        Id ownerId,
        String subject,
        Date dueDate
    ) {
        return new Task(
            WhatId       = whatId,
            OwnerId      = ownerId,
            Subject      = subject,
            Status       = TASK_STATUS,
            Priority     = TASK_PRIORITY,
            ActivityDate = dueDate
        );
    }
}
