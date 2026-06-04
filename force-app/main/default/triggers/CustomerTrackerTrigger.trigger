/**
 * CustomerTrackerTrigger
 * One trigger per object — delegates all logic to CustomerTrackerTriggerHandler.
 * Handles: before insert, before update, after insert, after update
 */
trigger CustomerTrackerTrigger on CustomerTracker__c (
    before insert, before update,
    after insert, after update
) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            CustomerTrackerTriggerHandler.beforeInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            CustomerTrackerTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
        }
    } else if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            CustomerTrackerTriggerHandler.afterInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            CustomerTrackerTriggerHandler.afterUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}