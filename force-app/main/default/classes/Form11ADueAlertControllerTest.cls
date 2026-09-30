/** SeeAllData like the other Form 11A tests: adds first defaults to an existing active credit contract. */
@isTest(SeeAllData = true)
private class Form11ADueAlertControllerTest {

    @isTest
    static void countsPastTheLimitDueTodayAndSoon() {
        Form11ADueAlertController before = new Form11ADueAlertController();
        List<Opportunity> opps = [
            SELECT Id, AccountId, Contract_No__c FROM Opportunity
            WHERE Is_Credit_Contract__c = true AND Is_Active__c = true AND Contract_No__c != null LIMIT 3
        ];
        if (opps.size() < 3) {
            return;
        }
        List<Integer> daysAgo = new List<Integer>{ 16, 14, 12 }; // past the limit, due today, due in 2 days
        List<Ezidebit_Dishonour__c> ds = new List<Ezidebit_Dishonour__c>();
        for (Integer i = 0; i < 3; i++) {
            ds.add(new Ezidebit_Dishonour__c(Opportunity__c = opps[i].Id, Account__c = opps[i].AccountId,
                Ezidebit_Payment_ID__c = 'T-11A-ALERT-' + i, Contract_Reference__c = opps[i].Contract_No__c, Status__c = 'D',
                Type__c = EzidebitDishonourService.TYPE_INSTALMENT, Outcome__c = EzidebitDishonourService.OUTCOME_OPEN,
                Is_Scheduled_Debit__c = true, First_Default__c = true, Debit_Date__c = Date.today().addDays(-daysAgo[i]), Payment_Amount__c = 45));
        }
        insert ds;

        Form11ADueAlertController c = new Form11ADueAlertController();
        System.assertEquals(before.overdue + 1, c.overdue);
        System.assertEquals(before.dueToday + 1, c.dueToday);
        System.assertEquals(before.dueSoon + 1, c.dueSoon);
        System.assertEquals(before.totalUnsent + 3, c.totalUnsent);
        System.assertEquals('red', c.level);
        System.assert(!c.nextDue.isEmpty());
        System.assert(c.nextDue[0].label.contains('past the limit') || c.nextDue[0].label.contains('due'));
    }

    @isTest
    static void greenWhenNothingIsDue() {
        delete [SELECT Id FROM Ezidebit_Dishonour__c WHERE First_Default__c = true AND Form_11A_Sent_Date__c = null];
        Form11ADueAlertController c = new Form11ADueAlertController();
        System.assertEquals(0, c.totalUnsent);
        System.assertEquals('green', c.level);
    }
}
