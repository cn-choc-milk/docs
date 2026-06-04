public with sharing class OpportunityScorer {
    /**
     * Bulk-safe: Returns a ScoreResult for each Opportunity (by Id)
     */
    public static Map<Id, ScoreResult> scoreOpportunities(List<Opportunity> opps) {
        Map<Id, ScoreResult> results = new Map<Id, ScoreResult>();
        if (opps == null || opps.isEmpty()) return results;
        for (Opportunity opp : opps) {
            if (opp == null || opp.Id == null) continue; // Defensive: skip null
            results.put(opp.Id, scoreOpportunity(opp));
        }
        return results;
    }

    /**
     * Scores a single Opportunity using the exact logic in design spec
     */
    public static ScoreResult scoreOpportunity(Opportunity opp) {
        if (opp == null) {
            throw new IllegalArgumentException('Opportunity is required');
        }
        Integer score = 0;
        // Amount Points
        if (opp.Amount != null) {
            Decimal amt = opp.Amount;
            if (amt >= 100000) {
                score += 40;
            } else if (amt >= 50000) {
                score += 30;
            } else if (amt >= 10000) {
                score += 20;
            } else if (amt > 0) {
                score += 10;
            } // else zero
        }
        // StageName Points
        String stage = opp.StageName;
        if (stage != null) {
            switch on stage {
                when 'Closed Won'              { score += 40; }
                when 'Negotiation/Review'      { score += 30; }
                when 'Proposal/Price Quote'    { score += 20; }
                when 'Qualification'           { score += 10; }
                when else                      { /* zero */ }
            }
        }
        // CloseDate Points
        if (opp.CloseDate != null) {
            Integer daysOut = opp.CloseDate.daysBetween(Date.today());
            if (daysOut >= 0 && daysOut <= 30) {
                score += 20;
            } else if (daysOut > 30 && daysOut <= 90) {
                score += 10;
            } // else zero
        }
        return new ScoreResult(score, bandFor(score));
    }

    /**
     * Returns band for score per official table
     */
    private static String bandFor(Integer score) {
        if (score == null) return 'Stale';
        if (score >= 80) return 'Hot';
        if (score >= 50) return 'Warm';
        if (score >= 20) return 'Cold';
        return 'Stale';
    }

    /**
     * Data bag with score and band
     */
    public class ScoreResult {
        public Integer score {get;set;}
        public String band {get;set;}
        public ScoreResult(Integer score, String band) {
            this.score = score;
            this.band = band;
        }
    }
}
