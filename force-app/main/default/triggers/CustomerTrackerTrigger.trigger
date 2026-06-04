/**
 * CustomerTrackerTrigger
 * ----------------------
 * Single trigger for CustomerTracker__c following the One-Trigger-Per-Object pattern.
 * All business logic is delegated to CustomerTrackerTriggerHandler.
 *
 * Contexts handled:
 *   before insert  - Auto-populate blank Name with a generated tracking number
 *   before update  - Prevent clearing a Name that was already set
 *   after insert   - Create a follow-up Task for the record owner
 *   after update   - Create a follow-up Task when ownership changes
 */
trigger CustomerTrackerTrigger on CustomerTracker__c (
    before insert, before update, after insert, after update
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