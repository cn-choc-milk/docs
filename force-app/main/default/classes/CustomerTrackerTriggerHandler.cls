/**
 * CustomerTrackerTriggerHandler
 * Handler class for CustomerTracker__c trigger.
 * Follows the One-Trigger-Per-Object pattern.
 *
 * Business Logic:
 *  - before insert: Auto-generate Name when blank (CT-YYYYMMDD-NNN)
 *  - before update: Prevent Name from being cleared
 *  - after insert:  Create a follow-up Task for the record owner (+7 days)
 *  - after update:  Create a follow-up Task when OwnerId changes
 */
public with sharing class CustomerTrackerTriggerHandler {

    // Recursion guard to prevent re-entrant trigger execution
    @TestVisible
    private static Boolean hasRun = false;

    // ─── Dispatch ─────────────────────────────────────────────────────────

    public static void dispatch(
        Boolean isInsert,
        Boolean isUpdate,
        Boolean isBefore,
        Boolean isAfter,
        List<CustomerTracker__c> newList,
        List<CustomerTracker__c> oldList,
        Map<Id, CustomerTracker__c> newMap,
        Map<Id, CustomerTracker__c> oldMap
    ) {
        if (isBefore) {
            if (isInsert) beforeInsert(newList);
            if (isUpdate) beforeUpdate(newList, oldMap);
        }
        if (isAfter) {
            if (isInsert && !hasRun) {
                hasRun = true;
                afterInsert(newList);
            }
            if (isUpdate) afterUpdate(newList, oldMap);
        }
    }

    // ─── Before Insert ─────────────────────────────────────────────────────

    /**
     * Auto-populate Name with CT-YYYYMMDD-NNN when a blank value is supplied.
     * Uses a zero-padded counter per transaction to ensure uniqueness.
     */
    @TestVisible
    private static void beforeInsert(List<CustomerTracker__c> newList) {
        String datePart = String.valueOf(Date.today().year())
            + String.valueOf(Date.today().month()).leftPad(2).replace(' ', '0')
            + String.valueOf(Date.today().day()).leftPad(2).replace(' ', '0');

        Integer counter = 1;
        for (CustomerTracker__c ct : newList) {
            if (String.isBlank(ct.Name)) {
                ct.Name = 'CT-' + datePart + '-' + String.valueOf(counter).leftPad(3).replace(' ', '0');
                counter++;
            }
        }
    }

    // ─── Before Update ─────────────────────────────────────────────────────

    /**
     * Prevent the Name field from being blanked out on update.
     */
    @TestVisible
    private static void beforeUpdate(
        List<CustomerTracker__c> newList,
        Map<Id, CustomerTracker__c> oldMap
    ) {
        for (CustomerTracker__c ct : newList) {
            if (String.isBlank(ct.Name)) {
                ct.Name.addError('Customer Tracker Name cannot be blank.');
            }
        }
    }

    // ─── After Insert ──────────────────────────────────────────────────────

    /**
     * Create a follow-up Task for each newly inserted record.
     * All Tasks are inserted in a single bulk DML statement.
     */
    @TestVisible
    private static void afterInsert(List<CustomerTracker__c> newList) {
        List<Task> tasks = new List<Task>();
        Date dueDate = Date.today().addDays(7);
        for (CustomerTracker__c ct : newList) {
            tasks.add(new Task(
                Subject         = 'Follow-up: ' + ct.Name,
                WhatId          = ct.Id,
                OwnerId         = ct.OwnerId,
                ActivityDate    = dueDate,
                Status          = 'Not Started',
                Priority        = 'Normal',
                Description     = 'Auto-generated follow-up task for Customer Tracker: ' + ct.Name
            ));
        }
        if (!tasks.isEmpty()) {
            insert tasks; // single bulk DML — no SOQL/DML in loop
        }
    }

    // ─── After Update ──────────────────────────────────────────────────────

    /**
     * Create a follow-up Task when OwnerId changes on a Customer Tracker record.
     * Only records where ownership actually changed get a new Task.
     */
    @TestVisible
    private static void afterUpdate(
        List<CustomerTracker__c> newList,
        Map<Id, CustomerTracker__c> oldMap
    ) {
        List<Task> tasks = new List<Task>();
        Date dueDate = Date.today().addDays(7);
        for (CustomerTracker__c ct : newList) {
            CustomerTracker__c oldCt = oldMap.get(ct.Id);
            if (ct.OwnerId != oldCt.OwnerId) {
                tasks.add(new Task(
                    Subject         = 'Ownership Transfer Follow-up: ' + ct.Name,
                    WhatId          = ct.Id,
                    OwnerId         = ct.OwnerId,
                    ActivityDate    = dueDate,
                    Status          = 'Not Started',
                    Priority        = 'Normal',
                    Description     = 'Ownership of Customer Tracker "' + ct.Name + '" was transferred. Please follow up.'
                ));
            }
        }
        if (!tasks.isEmpty()) {
            insert tasks; // single bulk DML — no SOQL/DML in loop
        }
    }
}
