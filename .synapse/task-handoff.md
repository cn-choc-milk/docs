# Task Handoff: Define Opportunity scoring rules and Apex class contract
<!-- agent: SYNTH -->
<!-- completed: $(date -u +%Y-%m-%dT%H:%M:%SZ) -->
<!-- status: complete -->

## Files Created/Modified
- `/workspace/force-app/main/default/classes/OpportunityScorer-Design.md` — Authoritative design doc specifying scoring rules, bands, weighting, and contract for OpportunityScorer Apex class

## Key Decisions
- Codified explicit, deterministic score table and weighting logic for Amount, StageName, and CloseDate, delivering zero ambiguity for downstream build/test
- Public API contract defined: scoreOpportunity(Opportunity) and scoreOpportunities(List<Opportunity>)
- Banding and edge/null handling rules exhaustively documented; API returns ScoreResult structure for uniform usage

## Integration Points
- Builders and testers must use the OpportunityScorer-Design.md spec as the source of truth for Apex implementation and test method coverage plan
- Invocable from triggers, controllers, Flows, etc. when downstream class is implemented

## Known Limitations
- All weights and bands are hardcoded for MVP; no admin UI or metadata config yet
- Algorithm assumes access to Amount, StageName, and CloseDate; no fallback for missing fields
- Does not address records with no Id in bulk method (can be extended if needed)

## Notes for Next Agent
- Use only the scoring rules in this spec—do not invent weights or scoring logic
- Test edge/null/empty scenarios and all four bands
- Ensure implementation is stateless and testable (no randomness, no DML)
