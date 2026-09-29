@isTest(SeeAllData = true)
private class ArrangementTrackerTest {

    static final Date TODAY = Date.newInstance(2026, 9, 30);

    private static Opportunity sta(Date firstDue, Date endDate, Decimal amount) {
        return new Opportunity(Is_this_a_STA__c = true, STA_Start_Date__c = firstDue.addDays(-3), STA_Next_Due_Date__c = firstDue,
            STA_End_Date__c = endDate, STA_Scheduled_Amount__c = amount, Payment_Frequency__c = 'Fortnightly');
    }

    private static Payment__c paid(Date d, Decimal amount) {
        return new Payment__c(Payment_Date__c = d, Actual_Amount__c = amount);
    }

    @isTest
    static void onTrack_partPaid_broken() {
        Opportunity o = sta(Date.newInstance(2026, 9, 1), Date.newInstance(2026, 12, 1), 50);
        // dues counted: 1 Sep, 15 Sep (29 Sep is inside the 4-day grace)
        ArrangementTracker.Status s = ArrangementTracker.evaluate(o, new List<Payment__c>{ paid(Date.newInstance(2026, 9, 1), 50), paid(Date.newInstance(2026, 9, 15), 50) }, TODAY);
        System.assertEquals(ArrangementTracker.ON_TRACK, s.status);
        System.assertEquals(2, s.duesPassed);
        System.assertEquals(Date.newInstance(2026, 9, 29), s.nextDue);

        s = ArrangementTracker.evaluate(o, new List<Payment__c>{ paid(Date.newInstance(2026, 9, 1), 50), paid(Date.newInstance(2026, 9, 15), 20) }, TODAY);
        System.assertEquals(ArrangementTracker.PART_PAID, s.status);
        System.assertEquals(30, s.shortfall);

        s = ArrangementTracker.evaluate(o, new List<Payment__c>{ paid(Date.newInstance(2026, 9, 1), 50) }, TODAY);
        System.assertEquals(ArrangementTracker.BROKEN, s.status);
        System.assert(s.summary.startsWith('Broken'));
    }

    @isTest
    static void notStarted_completed_endedShort_andNoArrangement() {
        System.assertEquals(ArrangementTracker.NOT_STARTED,
            ArrangementTracker.evaluate(sta(Date.newInstance(2026, 10, 5), Date.newInstance(2026, 12, 1), 50), new List<Payment__c>(), TODAY).status);
        Opportunity ended = sta(Date.newInstance(2026, 8, 3), Date.newInstance(2026, 8, 20), 40); // dues 3 Aug, 17 Aug
        System.assertEquals(ArrangementTracker.COMPLETED, ArrangementTracker.evaluate(ended,
            new List<Payment__c>{ paid(Date.newInstance(2026, 8, 3), 40), paid(Date.newInstance(2026, 8, 17), 40) }, TODAY).status);
        System.assertEquals(ArrangementTracker.ENDED_SHORT, ArrangementTracker.evaluate(ended,
            new List<Payment__c>{ paid(Date.newInstance(2026, 8, 3), 40) }, TODAY).status);
        System.assertEquals(null, ArrangementTracker.evaluate(new Opportunity(Is_this_a_STA__c = false), new List<Payment__c>(), TODAY));
        System.assertEquals(Date.newInstance(2026, 10, 30), ArrangementTracker.nextDate(TODAY, 'Monthly'));
        System.assertEquals(Date.newInstance(2026, 10, 7), ArrangementTracker.nextDate(TODAY, 'Weekly'));
    }

    @isTest
    static void batch_stampsTheStatus() {
        List<Opportunity> opps = [SELECT Id FROM Opportunity WHERE Is_Credit_Contract__c = true AND Is_Active__c = true LIMIT 1];
        if (opps.isEmpty()) {
            return;
        }
        Opportunity o = new Opportunity(Id = opps[0].Id, Is_this_a_STA__c = true, STA_Start_Date__c = Date.today().addDays(-20),
            STA_Next_Due_Date__c = Date.today().addDays(-18), STA_End_Date__c = Date.today().addDays(60), STA_Scheduled_Amount__c = 25);
        update o;
        ArrangementCheckBatch b = new ArrangementCheckBatch();
        Test.startTest();
        b.execute(null, [SELECT Id, Is_this_a_STA__c, STA_Start_Date__c, STA_Next_Due_Date__c, STA_End_Date__c, STA_Scheduled_Amount__c,
                         Payment_Frequency__c, STA_Status__c, STA_Shortfall__c FROM Opportunity WHERE Id = :o.Id]);
        b.finish(null);
        System.assertNotEquals(null, b.start(null));
        String jobId = System.schedule('Arrangement check test', '0 15 7 * * ?', new ArrangementCheckBatch());
        System.abortJob(jobId);
        Test.stopTest();
        Opportunity after = [SELECT STA_Status__c, STA_Checked_Date__c FROM Opportunity WHERE Id = :o.Id];
        System.assertNotEquals(null, after.STA_Status__c);
        System.assertEquals(Date.today(), after.STA_Checked_Date__c);
    }
}
