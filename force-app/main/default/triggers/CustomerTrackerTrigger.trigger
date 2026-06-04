/**
 * CustomerTrackerTrigger
 * One trigger per object pattern — all logic delegated to CustomerTrackerTriggerHandler.
 */
trigger CustomerTrackerTrigger on CustomerTracker__c (
    before insert,
    before update,
    after insert,
    after update
) {
    CustomerTrackerTriggerHandler.dispatch(
        Trigger.isInsert,
        Trigger.isUpdate,
        Trigger.isBefore,
        Trigger.isAfter,
        Trigger.new,
        Trigger.old,
        Trigger.newMap,
        Trigger.oldMap
    );
}
