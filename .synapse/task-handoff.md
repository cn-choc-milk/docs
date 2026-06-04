# Task Handoff: Implement OpportunityScorer Apex class with bulk-safe scoring logic
<!-- agent: SYNTH -->
<!-- completed: $(date -u +%Y-%m-%dT%H:%M:%SZ) -->
<!-- status: complete -->

## Files Created/Modified
- `/workspace/force-app/main/default/classes/OpportunityScorer.cls` — Apex implementation (contract, scoring logic, bulk-safe)
- `/workspace/force-app/main/default/classes/OpportunityScorer.cls-meta.xml` — Metadata

## Key Decisions
- Implemented **exact band, weighting, and null-handling rules** per `/classes/OpportunityScorer-Design.md` contract. No invented logic or extra fields.
- Bulk-safe: No DML, SOQL, or record-level operations in loops; single pass per input list.
- Stateless/Reusable: Pure static, reusable in triggers, flows, LWC, batch, or controller context.

## Integration Points
- Call `OpportunityScorer.scoreOpportunity(Opportunity)` for a single record (e.g., flow/Apex action)
- Call `OpportunityScorer.scoreOpportunities(List<Opportunity>)` for bulk logic (e.g., trigger, batch job, reporting)
- Designed for downstream test class to cover all edge/null/bulk/contract scenarios

## Known Limitations
- No configuration via Custom Metadata (future extension); all scoring is hardcoded
- Does not handle Opportunities with null Ids in Map return; those are skipped
- Future changes to StageName/amount bands may require coordinated test updates

## Notes for Next Agent
- See contract—test bands (Hot, Warm, Cold, Stale) and input edge cases
- Logic is fully deterministic for test case creation—no randomness
