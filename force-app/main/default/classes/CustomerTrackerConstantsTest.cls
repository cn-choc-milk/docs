@isTest
private class CustomerTrackerConstantsTest {

    // ─── Status Constants ──────────────────────────────────────────────────
    @isTest
    static void statusActive_hasExpectedValue() {
        System.assertEquals(
            'Active',
            CustomerTrackerConstants.STATUS_ACTIVE,
            'STATUS_ACTIVE should equal \'Active\''
        );
    }

    @isTest
    static void statusInactive_hasExpectedValue() {
        System.assertEquals(
            'Inactive',
            CustomerTrackerConstants.STATUS_INACTIVE,
            'STATUS_INACTIVE should equal \'Inactive\''
        );
    }

    @isTest
    static void statusPending_hasExpectedValue() {
        System.assertEquals(
            'Pending',
            CustomerTrackerConstants.STATUS_PENDING,
            'STATUS_PENDING should equal \'Pending\''
        );
    }

    // ─── Mutual Exclusivity ─────────────────────────────────────────────
    @isTest
    static void statusConstants_areAllDistinct() {
        Set<String> statuses = new Set<String>{
            CustomerTrackerConstants.STATUS_ACTIVE,
            CustomerTrackerConstants.STATUS_INACTIVE,
            CustomerTrackerConstants.STATUS_PENDING
        };
        System.assertEquals(
            3,
            statuses.size(),
            'All three status constants must have distinct values'
        );
    }

    // ─── Non-Null / Non-Empty Assertions ────────────────────────────────
    @isTest
    static void statusActive_isNotBlank() {
        System.assert(
            String.isNotBlank(CustomerTrackerConstants.STATUS_ACTIVE),
            'STATUS_ACTIVE must not be blank'
        );
    }

    @isTest
    static void statusInactive_isNotBlank() {
        System.assert(
            String.isNotBlank(CustomerTrackerConstants.STATUS_INACTIVE),
            'STATUS_INACTIVE must not be blank'
        );
    }

    @isTest
    static void statusPending_isNotBlank() {
        System.assert(
            String.isNotBlank(CustomerTrackerConstants.STATUS_PENDING),
            'STATUS_PENDING must not be blank'
        );
    }

    // ─── Field API Name Constants ───────────────────────────────────────
    @isTest
    static void fieldStatus_hasExpectedValue() {
        System.assertEquals(
            'Status__c',
            CustomerTrackerConstants.FIELD_STATUS,
            'FIELD_STATUS should equal \'Status__c\''
        );
    }

    @isTest
    static void fieldName_hasExpectedValue() {
        System.assertEquals(
            'Name',
            CustomerTrackerConstants.FIELD_NAME,
            'FIELD_NAME should equal \'Name\''
        );
    }

    // ─── Auto-Name Prefix Constant ─────────────────────────────────────────
    @isTest
    static void autoNamePrefix_startsWithCT() {
        System.assert(
            CustomerTrackerConstants.AUTO_NAME_PREFIX.startsWith('CT'),
            'AUTO_NAME_PREFIX should start with \'CT\''
        );
    }

    @isTest
    static void autoNamePrefix_hasExpectedValue() {
        System.assertEquals(
            'CT-',
            CustomerTrackerConstants.AUTO_NAME_PREFIX,
            'AUTO_NAME_PREFIX should equal \'CT-\''
        );
    }

    // ─── Task Default Constants ────────────────────────────────────────────
    @isTest
    static void taskSubjectPrefix_isNotBlank() {
        System.assert(
            String.isNotBlank(CustomerTrackerConstants.TASK_SUBJECT_PREFIX),
            'TASK_SUBJECT_PREFIX must not be blank'
        );
    }

    @isTest
    static void taskDueDays_isPositive() {
        System.assert(
            CustomerTrackerConstants.TASK_DUE_DAYS > 0,
            'TASK_DUE_DAYS must be a positive integer'
        );
    }

    @isTest
    static void taskDueDays_hasExpectedValue() {
        System.assertEquals(
            7,
            CustomerTrackerConstants.TASK_DUE_DAYS,
            'TASK_DUE_DAYS should equal 7'
        );
    }

    // ─── Set Membership Helpers (regression guard) ─────────────────────
    @isTest
    static void allStatusConstants_areInKnownSet() {
        Set<String> known = new Set<String>{ 'Active', 'Inactive', 'Pending' };
        System.assert(
            known.contains(CustomerTrackerConstants.STATUS_ACTIVE),
            'STATUS_ACTIVE must be in the known-values set'
        );
        System.assert(
            known.contains(CustomerTrackerConstants.STATUS_INACTIVE),
            'STATUS_INACTIVE must be in the known-values set'
        );
        System.assert(
            known.contains(CustomerTrackerConstants.STATUS_PENDING),
            'STATUS_PENDING must be in the known-values set'
        );
    }
}
