/**
 * CustomerTrackerTrigger
 *
 * Single trigger for CustomerTracker__c following the One-Trigger-Per-Object
 * pattern.  All business logic is delegated to CustomerTrackerTriggerHandler.
 *
 * Contexts handled:
 *   before insert  – auto-name population
 *   before update  – prevent Name blank-out
 *   after insert   – follow-up Task creation for new records
 *   after update   – follow-up Task creation on owner change
 */
trigger CustomerTrackerTrigger on CustomerTracker__c (
    before insert,
    before update,
    after insert,
    after update
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
