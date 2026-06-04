public with sharing class CustomerTrackerService {
    /**
     * Create new CustomerTracker__c records. Bulk-safe.
     */
    public static List<CustomerTracker__c> createTrackers(List<CustomerTracker__c> trackers) {
        if (trackers == null || trackers.isEmpty()) return new List<CustomerTracker__c>();
        insert trackers;
        return trackers;
    }
    /**
     * Get one CustomerTracker__c by Id (returns null if not found).
     */
    public static CustomerTracker__c getById(Id recordId) {
        if (recordId == null) return null;
        List<CustomerTracker__c> records = [SELECT Id, Name FROM CustomerTracker__c WHERE Id = :recordId LIMIT 1];
        return records.isEmpty() ? null : records[0];
    }
    /**
     * Get N most recent CustomerTracker__c, ordered by CreatedDate.
     */
    public static List<CustomerTracker__c> getAll(Integer limitVal) {
        Integer maxLimit = (limitVal == null || limitVal < 1) ? 50 : Math.min(limitVal, 200);
        return [SELECT Id, Name FROM CustomerTracker__c ORDER BY CreatedDate DESC LIMIT :maxLimit];
    }
    /**
     * Update CustomerTracker records (bulk-safe).
     */
    public static List<CustomerTracker__c> updateTrackers(List<CustomerTracker__c> trackers) {
        if (trackers == null || trackers.isEmpty()) return new List<CustomerTracker__c>();
        update trackers;
        return trackers;
    }
    /**
     * Delete records by set of Ids. Bulk-safe.
     */
    public static void deleteById(Set<Id> idSet) {
        if (idSet == null || idSet.isEmpty()) return;
        List<CustomerTracker__c> toDelete = [SELECT Id FROM CustomerTracker__c WHERE Id IN :idSet];
        if (!toDelete.isEmpty()) delete toDelete;
    }
    /**
     * Return count of CustomerTracker__c records using aggregate SOQL.
     */
    public static Integer countAll() {
        return [SELECT COUNT() FROM CustomerTracker__c];
    }
}
