trigger CustomerTrackerTrigger on CustomerTracker__c (before insert, before update, after insert, after update) {
    CustomerTrackerTriggerHandler.dispatch(Trigger.new, Trigger.old, Trigger.newMap, Trigger.oldMap, Trigger.operationType);
}