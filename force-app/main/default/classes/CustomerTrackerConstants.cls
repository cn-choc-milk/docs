/**
 * CustomerTrackerConstants
 *
 * Central repository of compile-time constants for the CustomerTracker__c
 * domain. Using a dedicated constants class ensures a single source of truth
 * for status values shared across triggers, handlers, services, and tests —
 * preventing magic-string bugs and simplifying future refactors.
 *
 * @author  SYNTH
 * @since   2026-06-04
 */
public with sharing class CustomerTrackerConstants {

    // ─── Status Values ────────────────────────────────────────────────────────
    /** Record is fully active and being tracked. */
    public static final String STATUS_ACTIVE   = 'Active';

    /** Record has been deactivated or retired. */
    public static final String STATUS_INACTIVE = 'Inactive';

    /** Record has been created but not yet confirmed / provisioned. */
    public static final String STATUS_PENDING  = 'Pending';

    // ─── Field API Names ─────────────────────────────────────────────────────
    /** API name of the Status field on CustomerTracker__c. */
    public static final String FIELD_STATUS = 'Status__c';

    /** API name of the Name field on CustomerTracker__c. */
    public static final String FIELD_NAME = 'Name';

    // ─── Auto-Name Prefix ────────────────────────────────────────────────────
    /** Prefix used by CustomerTrackerTriggerHandler when auto-generating names. */
    public static final String AUTO_NAME_PREFIX = 'CT-';

    // ─── Task Defaults ───────────────────────────────────────────────────────
    /** Subject prefix for follow-up tasks created on insert / owner change. */
    public static final String TASK_SUBJECT_PREFIX = 'Follow-up: CustomerTracker ';

    /** Days from today until generated follow-up tasks are due. */
    public static final Integer TASK_DUE_DAYS = 7;

    // ─── Private constructor — prevent instantiation ──────────────────────────
    @SuppressWarnings('PMD.EmptyStatementBlock')
    private CustomerTrackerConstants() {
        // Constants-only class — no instances allowed
    }
}
