/**
 * Nav's four agreements (Interest Calc Review, 29 Sep 2026) worked through the rules, to the cent:
 * interest = daily rate x days x balance + fee adjustment, as the Interest_Amount__c formula does.
 */
@isTest
private class InterestPeriodRulesTest {

    static final Decimal RATE_44 = 0.12054795; // 44% a year, the Daily_Interest_Rate__c value
    static final Decimal RATE_47 = 0.12876712; // 47% a year

    private static Decimal interest(Decimal ratePercent, Integer days, Decimal balance, Decimal adjustment) {
        return (ratePercent / 100 * days * balance + adjustment).setScale(2, RoundingMode.HALF_UP);
    }

    private static List<InterestPeriodRules.StageEvent> events(List<Object> pairs) {
        List<InterestPeriodRules.StageEvent> out = new List<InterestPeriodRules.StageEvent>();
        for (Integer i = 0; i < pairs.size(); i += 2) {
            out.add(new InterestPeriodRules.StageEvent((String) pairs[i], (Date) pairs[i + 1]));
        }
        return out;
    }

    @isTest
    static void rebekah_deliveredAfterSigning_feeFromItsDate() {
        // 30000012974: signed 28 Aug, Pending Order 31 Aug, delivered 4 Sep, fee 15 Sep, paid 24 Sep.
        Date paid = Date.newInstance(2026, 9, 24);
        Date start = InterestPeriodRules.firstPeriodStart(Date.newInstance(2026, 8, 28), events(new List<Object>{
            'Goods Delivered', Date.newInstance(2026, 8, 28), 'Pending Order', Date.newInstance(2026, 8, 31),
            'Goods Delivered', Date.newInstance(2026, 9, 4) }), paid);
        System.assertEquals(Date.newInstance(2026, 9, 4), start, 'interest starts at delivery');
        List<InterestPeriodRules.FeeCharge> fees = new List<InterestPeriodRules.FeeCharge>{ new InterestPeriodRules.FeeCharge(16.50, Date.newInstance(2026, 9, 15)) };
        Decimal balance = InterestPeriodRules.balanceAtPaymentDate(1710.88, fees, paid);
        Integer days = start.daysBetween(paid);
        System.assertEquals(20, days);
        System.assertEquals(41.03, interest(RATE_44, days, balance, InterestPeriodRules.feeInterestAdjustment(fees, start, paid, RATE_44)));
    }

    @isTest
    static void manasseh_deliveredAtSigning_twoFees() {
        // Nav's three parts, $57.43 + $43.39 + $17.48, add up to $118.30.
        // 30000012822: signed 14 Aug (never Pending Order), fees 3 Sep and 18 Sep, paid 24 Sep.
        Date paid = Date.newInstance(2026, 9, 24);
        Date start = InterestPeriodRules.firstPeriodStart(Date.newInstance(2026, 8, 14),
            events(new List<Object>{ 'Goods Delivered', Date.newInstance(2026, 8, 14) }), paid);
        System.assertEquals(Date.newInstance(2026, 8, 14), start);
        List<InterestPeriodRules.FeeCharge> fees = new List<InterestPeriodRules.FeeCharge>{
            new InterestPeriodRules.FeeCharge(16.50, Date.newInstance(2026, 9, 3)), new InterestPeriodRules.FeeCharge(16.50, Date.newInstance(2026, 9, 18)) };
        Decimal balance = InterestPeriodRules.balanceAtPaymentDate(2263, fees, paid);
        System.assertEquals(118.30, interest(RATE_47, start.daysBetween(paid), balance, InterestPeriodRules.feeInterestAdjustment(fees, start, paid, RATE_47)));
    }

    @isTest
    static void nicole_feeChargedAfterThePaymentDate_isNextPeriod() {
        // 30000013170: signed 14 Sep, paid 28 Sep, fee charged 29 Sep before the payment was processed.
        Date paid = Date.newInstance(2026, 9, 28);
        Date start = Date.newInstance(2026, 9, 14);
        List<InterestPeriodRules.FeeCharge> fees = new List<InterestPeriodRules.FeeCharge>{ new InterestPeriodRules.FeeCharge(16.50, Date.newInstance(2026, 9, 29)) };
        Decimal balance = InterestPeriodRules.balanceAtPaymentDate(2270.83, fees, paid);
        System.assertEquals(2254.33, balance);
        System.assertEquals(0, InterestPeriodRules.feeInterestAdjustment(fees, start, paid, RATE_47));
        System.assertEquals(40.64, interest(RATE_47, 14, balance, 0));
    }

    @isTest
    static void phillip_paidTwoDaysAfterSigning() {
        // 30000013122: signed 9 Sep, first paid 11 Sep.
        Date start = InterestPeriodRules.firstPeriodStart(Date.newInstance(2026, 9, 9), new List<InterestPeriodRules.StageEvent>(), Date.newInstance(2026, 9, 11));
        System.assertEquals(3.13, interest(RATE_44, start.daysBetween(Date.newInstance(2026, 9, 11)), 1297.67, 0));
    }

    @isTest
    static void firstPeriodStart_edgeCases() {
        Date signed = Date.newInstance(2026, 8, 1);
        Date paid = Date.newInstance(2026, 9, 1);
        // moved back to Goods Delivered only after the first payment: not a delivery
        System.assertEquals(signed, InterestPeriodRules.firstPeriodStart(signed, events(new List<Object>{
            'Goods Delivered', signed, 'Pending Order', Date.newInstance(2026, 9, 5), 'Goods Delivered', Date.newInstance(2026, 9, 10) }), paid));
        // back and forth twice: the last delivery before the payment
        System.assertEquals(Date.newInstance(2026, 8, 20), InterestPeriodRules.firstPeriodStart(signed, events(new List<Object>{
            'Goods Delivered', signed, 'Pending Order', Date.newInstance(2026, 8, 3), 'Goods Delivered', Date.newInstance(2026, 8, 10),
            'Pending Order', Date.newInstance(2026, 8, 12), 'Goods Delivered', Date.newInstance(2026, 8, 20) }), paid));
        // a delivery recorded before signing: never before signing
        System.assertEquals(signed, InterestPeriodRules.firstPeriodStart(signed, events(new List<Object>{
            'Pending Order', Date.newInstance(2026, 7, 20), 'Goods Delivered', Date.newInstance(2026, 7, 25) }), paid));
        // still in Pending Order when paid: from signing
        System.assertEquals(signed, InterestPeriodRules.firstPeriodStart(signed, events(new List<Object>{
            'Goods Delivered', signed, 'Pending Order', Date.newInstance(2026, 8, 3) }), paid));
        // fee on the first day of the period counts for the whole period; on the payment date, for none
        List<InterestPeriodRules.FeeCharge> fees = new List<InterestPeriodRules.FeeCharge>{
            new InterestPeriodRules.FeeCharge(10, signed), new InterestPeriodRules.FeeCharge(10, paid) };
        System.assertEquals((-10 * 31 * RATE_44 / 100).setScale(2, RoundingMode.HALF_UP), InterestPeriodRules.feeInterestAdjustment(fees, signed, paid, RATE_44));
        System.assertEquals(0, InterestPeriodRules.feeInterestAdjustment(fees, null, paid, RATE_44));
        System.assertEquals(0, InterestPeriodRules.balanceAtPaymentDate(5, new List<InterestPeriodRules.FeeCharge>{ new InterestPeriodRules.FeeCharge(10, paid.addDays(1)) }, paid));
        System.assertEquals(Date.newInstance(2026, 9, 29), InterestPeriodRules.localDate(Datetime.newInstanceGmt(2026, 9, 28, 20, 0, 0)), '6am Melbourne');
    }

    @isTest
    static void loaders_returnMaps() {
        List<Opportunity> opps = [SELECT Id FROM Opportunity LIMIT 1];
        Set<Id> ids = new Set<Id>();
        for (Opportunity o : opps) {
            ids.add(o.Id);
        }
        System.assertNotEquals(null, InterestPeriodRules.stageHistory(ids));
        System.assertNotEquals(null, InterestPeriodRules.fees(ids, Date.today().addYears(-1)));
        System.assertEquals(0, InterestPeriodRules.stageHistory(new Set<Id>()).size());
        System.assertEquals(0, InterestPeriodRules.fees(null, Date.today()).size());
    }
}
