/**
 * CustomerTrackerTrigger
 *
 * Single trigger for CustomerTracker__c following the One-Trigger-Per-Object pattern.
 * All business logic is delegated to CustomerTrackerTriggerHandler to keep
 * triggers lean and testable.
 */
trigger CustomerTrackerTrigger on CustomerTracker__c (
    before insert,
    before update,
    before delete,
    after insert,
    after update
) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            CustomerTrackerTriggerHandler.beforeInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            CustomerTrackerTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
        } else if (Trigger.isDelete) {
            CustomerTrackerTriggerHandler.beforeDelete(Trigger.old);
        }
    } else if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            CustomerTrackerTriggerHandler.afterInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            CustomerTrackerTriggerHandler.afterUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}
