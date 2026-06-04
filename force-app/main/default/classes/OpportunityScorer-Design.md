# OpportunityScorer Scoring Rules & Apex Contract

## Overview
Defines opportunity scoring for consistent, testable implementation—using `Amount`, `StageName`, and `CloseDate`.

---

## 1. Scoring Criteria

### Amount (Opportunity.Amount)
| Range            | Points |
|------------------|--------|
| ≥ 100,000        | 40     |
| 50,000–99,999    | 30     |
| 10,000–49,999    | 20     |
| 1–9,999          | 10     |
| 0 or null        | 0      |

### StageName (Opportunity.StageName)
| Value                    | Points |
|--------------------------|--------|
| Closed Won               | 40     |
| Negotiation/Review       | 30     |
| Proposal/Price Quote     | 20     |
| Qualification            | 10     |
| (any other value/null)   | 0      |

### CloseDate (Opportunity.CloseDate)
| Value                                  | Points |
|----------------------------------------|--------|
| In next 30 days       (0–30 days out)  | 20     |
| In next 31–90 days    (31–90 days out) | 10     |
| Past, >90 days, or null                | 0      |

---

## 2. Scoring Algorithm
- Add points from Amount, StageName, CloseDate buckets
- Maximum raw score: **100**
- No field is negative; missing/blank fields score **zero**
- If all fields blank: score is 0

## 3. Score Bands
| Score  | Band  |
|--------|-------|
| 80–100 | Hot   |
| 50–79  | Warm  |
| 20–49  | Cold  |
| 0–19   | Stale |

## 4. Null Handling
- Null or omitted Amount, StageName, CloseDate each score zero for that criterion
- Null Opportunity as input: throw IllegalArgumentException

---

## 5. Apex Class API Contract

### Contract: `OpportunityScorer`

```apex
public with sharing class OpportunityScorer {
    /**
     * Scores a single Opportunity.
     * @param opp Opportunity (must not be null)
     * @return ScoreResult { score, band }
     */
    public static ScoreResult scoreOpportunity(Opportunity opp);

    /**
     * Scores a list of Opportunities in bulk.
     * @param opps List<Opportunity>
     * @return Map<Id, ScoreResult> for each Opportunity with a valid Id
     */
    public static Map<Id, ScoreResult> scoreOpportunities(List<Opportunity> opps);

    /**
     * POJO representing the scoring outcome
     */
    public class ScoreResult {
        public Integer score { get; set; }
        public String band { get; set; }
        public ScoreResult(Integer score, String band) {
            this.score = score;
            this.band = band;
        }
    }
}
```

---

## 6. Design Notes
- Deterministic and testable: NO randomness, NO external dependencies
- Suitable for trigger, service, or controller usage
- Easily testable for all edge cases and bands
- Weightings & bands may be future-configurable via Custom Metadata, but are hardcoded for MVP
- Bulk method accepts 0–200 records; skips null input

---

## 7. Coverage Expectations
- Code and tests MUST verify all bands (Hot, Warm, Cold, Stale)
- Null, min, max, and edge case input must be covered explicitly in unit tests

---