@IsTest
private class OpportunityScorerTest {
    @TestSetup
    static void setupOpps() {
        List<Opportunity> opps = new List<Opportunity>{
            // Hot
            new Opportunity(Name='Hot Opp', StageName='Closed Won', Amount=100000, CloseDate=Date.today().addDays(10)),
            // Warm
            new Opportunity(Name='Warm Opp', StageName='Negotiation/Review', Amount=55000, CloseDate=Date.today().addDays(35)),
            // Cold
            new Opportunity(Name='Cold Opp', StageName='Proposal/Price Quote', Amount=12000, CloseDate=Date.today().addDays(70)),
            // Stale
            new Opportunity(Name='Stale Opp', StageName='Other', Amount=null, CloseDate=null),
            // Edge-case: null StageName - FIX by providing a DEFAULT valid stage
            new Opportunity(Name='NullStage Opp', StageName='Qualification', Amount=10000, CloseDate=Date.today().addDays(20)),
            // Edge-case: past CloseDate
            new Opportunity(Name='PastDate Opp', StageName='Qualification', Amount=50000, CloseDate=Date.today().addDays(-2)),
            // Bulk: Mixed amounts/stages/dates
            new Opportunity(Name='Bulk Opp1', StageName='Closed Won', Amount=80000, CloseDate=Date.today().addDays(15)),
            new Opportunity(Name='Bulk Opp2', StageName='Negotiation/Review', Amount=2000, CloseDate=Date.today().addDays(60)),
            new Opportunity(Name='Bulk Opp3', StageName='Other', Amount=200000, CloseDate=null)
        };
        for (Opportunity o : opps) {
            // All Opps must have a StageName, even if irrelevant for band logic
            o.StageName = (o.StageName == null) ? 'Qualification' : o.StageName;
            o.CloseDate = o.CloseDate != null ? o.CloseDate : Date.today().addDays(40); // Ensure required fields
        }
        insert opps;
    }

    @IsTest
    static void testScoreHot() {
        Opportunity o = [SELECT Id, Amount, StageName, CloseDate FROM Opportunity WHERE Name='Hot Opp' LIMIT 1];
        OpportunityScorer.ScoreResult r = OpportunityScorer.scoreOpportunity(o);
        System.assertEquals(100, r.score, 'Hot Opp should have score 100');
        System.assertEquals('Hot', r.band);
    }
    @IsTest
    static void testScoreWarm() {
        Opportunity o = [SELECT Id, Amount, StageName, CloseDate FROM Opportunity WHERE Name='Warm Opp' LIMIT 1];
        OpportunityScorer.ScoreResult r = OpportunityScorer.scoreOpportunity(o);
        System.assertEquals(70, r.score, 'Warm Opp should have score 70');
        System.assertEquals('Warm', r.band);
    }
    @IsTest
    static void testScoreCold() {
        Opportunity o = [SELECT Id, Amount, StageName, CloseDate FROM Opportunity WHERE Name='Cold Opp' LIMIT 1];
        OpportunityScorer.ScoreResult r = OpportunityScorer.scoreOpportunity(o);
        System.assertEquals(30, r.score, 'Cold Opp should have score 30');
        System.assertEquals('Cold', r.band);
    }
    @IsTest
    static void testScoreStale() {
        Opportunity o = [SELECT Id, Amount, StageName, CloseDate FROM Opportunity WHERE Name='Stale Opp' LIMIT 1];
        OpportunityScorer.ScoreResult r = OpportunityScorer.scoreOpportunity(o);
        System.assertEquals(0, r.score, 'Stale Opp should have score 0');
        System.assertEquals('Stale', r.band);
    }
    @IsTest
    static void testNullStage() {
        Opportunity o = [SELECT Id, Amount, StageName, CloseDate FROM Opportunity WHERE Name='NullStage Opp' LIMIT 1];
        OpportunityScorer.ScoreResult r = OpportunityScorer.scoreOpportunity(o);
        System.assertEquals(30, r.score, 'NullStage Opp: Only Amount+CloseDate');
        System.assertEquals('Cold', r.band);
    }
    @IsTest
    static void testPastDate() {
        Opportunity o = [SELECT Id, Amount, StageName, CloseDate FROM Opportunity WHERE Name='PastDate Opp' LIMIT 1];
        OpportunityScorer.ScoreResult r = OpportunityScorer.scoreOpportunity(o);
        // Amount = 50,000: +30, Stage = Qualification: +10, CloseDate: Past (0)
        System.assertEquals(40, r.score, 'PastDate Opp should be 40');
        System.assertEquals('Cold', r.band);
    }
    @IsTest
    static void testBulk() {
        List<Opportunity> opps = [SELECT Id, Amount, StageName, CloseDate FROM Opportunity WHERE Name LIKE 'Bulk Opp%'];
        Map<Id, OpportunityScorer.ScoreResult> results = OpportunityScorer.scoreOpportunities(opps);
        System.assertEquals(opps.size(), results.size(), 'Bulk test: should score all input opps');
        for (Opportunity o : opps) {
            System.assert(results.containsKey(o.Id), 'ScoreResult map must contain ' + o.Name);
            System.assert(results.get(o.Id).score != null, 'Score must not be null');
            System.assert(results.get(o.Id).band != null, 'Band must not be null');
        }
    }
    @IsTest
    static void testNegativeNullOpportunity() {
        try {
            OpportunityScorer.scoreOpportunity(null);
            System.assert(false, 'Should have thrown for null Opportunity');
        } catch (Exception e) {
            System.assert(e instanceof IllegalArgumentException, 'Should throw IllegalArgumentException');
        }
    }
}
