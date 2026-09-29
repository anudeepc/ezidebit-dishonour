// One-off: re-close the first payment of 30000012822 and 30000012974 under the new interest rules
// (they were processed under the temporary 14-day first-period limit). Expected $118.30 and $41.03.
Map<Id, Scheduled_Payment__c> sps = new Map<Id, Scheduled_Payment__c>([SELECT Id, Opportunity__c, Opportunity__r.Contract_No__c, Opportunity__r.Start_Date__c,
    Payment_received_date__c, Loan_Balance_Amount__c, Payment_Frequency_Number__c, Daily_Interest_Rate__c, Fee_Interest_Adjustment__c, Interest_Amount__c
    FROM Scheduled_Payment__c WHERE Id IN ('a07OZ00001frM8zYAE', 'a07OZ00001frJXQYA2')]);
Set<Id> oppIds = new Set<Id>();
for (Scheduled_Payment__c sp : sps.values()) oppIds.add(sp.Opportunity__c);
Map<Id, List<InterestPeriodRules.StageEvent>> hist = InterestPeriodRules.stageHistory(oppIds);
Map<Id, List<InterestPeriodRules.FeeCharge>> fees = InterestPeriodRules.fees(oppIds, Date.newInstance(2026, 1, 1));
Map<String, Decimal> expected = new Map<String, Decimal>{ '30000012822' => 118.30, '30000012974' => 41.03 };
List<Scheduled_Payment__c> updates = new List<Scheduled_Payment__c>();
for (Scheduled_Payment__c sp : sps.values()) {
    Date paid = sp.Payment_received_date__c;
    List<InterestPeriodRules.FeeCharge> f = fees.containsKey(sp.Opportunity__c) ? fees.get(sp.Opportunity__c) : new List<InterestPeriodRules.FeeCharge>();
    Date start = InterestPeriodRules.firstPeriodStart(sp.Opportunity__r.Start_Date__c,
        hist.containsKey(sp.Opportunity__c) ? hist.get(sp.Opportunity__c) : new List<InterestPeriodRules.StageEvent>(), paid);
    Integer days = Math.max(0, start.daysBetween(paid));
    Decimal adj = InterestPeriodRules.feeInterestAdjustment(f, start, paid, sp.Daily_Interest_Rate__c);
    Decimal interest = (sp.Daily_Interest_Rate__c / 100 * days * sp.Loan_Balance_Amount__c + adj).setScale(2, RoundingMode.HALF_UP);
    System.debug('CALC ' + sp.Opportunity__r.Contract_No__c + ' start=' + start + ' days=' + days + ' bal=' + sp.Loan_Balance_Amount__c + ' adj=' + adj + ' interest=' + interest + ' expected=' + expected.get(sp.Opportunity__r.Contract_No__c));
    if (interest != expected.get(sp.Opportunity__r.Contract_No__c)) {
        throw new IllegalArgumentException('Mismatch on ' + sp.Opportunity__r.Contract_No__c + ': ' + interest);
    }
    updates.add(new Scheduled_Payment__c(Id = sp.Id, Payment_Frequency_Number__c = days, Fee_Interest_Adjustment__c = adj));
}
update updates;
for (Scheduled_Payment__c sp : [SELECT Opportunity__r.Contract_No__c, Payment_Frequency_Number__c, Fee_Interest_Adjustment__c, Paid_Amount__c, Interest_Amount__c, Unpaid_Interest_Amount__c FROM Scheduled_Payment__c WHERE Id IN :sps.keySet()]) {
    System.debug('AFTER ' + JSON.serialize(sp));
}
