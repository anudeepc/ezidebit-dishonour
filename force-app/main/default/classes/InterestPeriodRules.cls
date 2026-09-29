/**
 * The interest rules PaymentUtil applies when it closes a period with a payment (credit contracts):
 *
 * 1. First period starts at delivery or signing. If, before this first payment, the agreement moved
 *    from Pending Order back to Goods Delivered, interest starts on the day of the last such move
 *    (the goods were delivered then). Otherwise it starts on the Start Date (signing). Never before
 *    signing. Every later period runs from the previous payment, as before.
 * 2. The balance is the balance as at the payment date: a fee charged after the payment date belongs
 *    to the next period.
 * 3. A fee charged inside the period attracts interest only from the day it was charged. The days
 *    before it was charged come off through Scheduled_Payment__c.Fee_Interest_Adjustment__c, which
 *    the Interest_Amount__c and Unpaid_Interest_Amount__c formulas add in.
 *
 * Dates are Melbourne dates (stage history is stored in UTC).
 */
public without sharing class InterestPeriodRules {

    public static final String STAGE_ORDERED = 'Pending Order';
    public static final String STAGE_DELIVERED = 'Goods Delivered';
    private static final String TZ = 'Australia/Melbourne';

    public class StageEvent {
        public String stage;
        public Date onDate;
        public StageEvent(String stage, Date onDate) {
            this.stage = stage;
            this.onDate = onDate;
        }
    }

    public class FeeCharge {
        public Decimal amount;
        public Date charged;
        public FeeCharge(Decimal amount, Date charged) {
            this.amount = amount;
            this.charged = charged;
        }
    }

    /** Rule 1: the day the first period's interest starts. `history` must be oldest first. */
    public static Date firstPeriodStart(Date startDate, List<StageEvent> history, Date paymentDate) {
        Date delivered = null;
        String previous = null;
        for (StageEvent e : history) {
            if (e.onDate != null && paymentDate != null && e.onDate > paymentDate) {
                break; // a move after the customer started paying is not a delivery
            }
            if (e.stage == STAGE_DELIVERED && previous == STAGE_ORDERED) {
                delivered = e.onDate; // the last move before the first payment wins
            }
            previous = e.stage;
        }
        if (delivered == null) {
            return startDate;
        }
        return startDate != null && delivered < startDate ? startDate : delivered;
    }

    /** Rule 2: today's balance less the fees charged after the payment date. */
    public static Decimal balanceAtPaymentDate(Decimal balanceNow, List<FeeCharge> fees, Date paymentDate) {
        Decimal b = balanceNow == null ? 0 : balanceNow;
        for (FeeCharge f : fees) {
            if (f.charged != null && paymentDate != null && f.charged > paymentDate && f.amount != null) {
                b -= f.amount;
            }
        }
        return b <= 0 ? 0 : b;
    }

    /**
     * Rule 3: interest to take off for the days before each fee charged inside the period
     * (after periodStart, up to the payment date). dailyRatePercent is the field value, e.g. 0.12054795.
     */
    public static Decimal feeInterestAdjustment(List<FeeCharge> fees, Date periodStart, Date paymentDate, Decimal dailyRatePercent) {
        if (periodStart == null || paymentDate == null || dailyRatePercent == null) {
            return 0;
        }
        Decimal adjustment = 0;
        for (FeeCharge f : fees) {
            if (f.charged == null || f.amount == null || f.charged <= periodStart || f.charged > paymentDate) {
                continue;
            }
            adjustment -= f.amount * periodStart.daysBetween(f.charged) * dailyRatePercent / 100;
        }
        return adjustment.setScale(2, RoundingMode.HALF_UP);
    }

    // ---- loading, for PaymentUtil (one query each for the whole batch) -------------------

    public static Map<Id, List<StageEvent>> stageHistory(Set<Id> opportunityIds) {
        Map<Id, List<StageEvent>> byOpp = new Map<Id, List<StageEvent>>();
        if (opportunityIds == null || opportunityIds.isEmpty()) {
            return byOpp;
        }
        for (OpportunityHistory h : [
            SELECT OpportunityId, StageName, CreatedDate FROM OpportunityHistory
            WHERE OpportunityId IN :opportunityIds ORDER BY OpportunityId, CreatedDate ASC
        ]) {
            if (!byOpp.containsKey(h.OpportunityId)) {
                byOpp.put(h.OpportunityId, new List<StageEvent>());
            }
            byOpp.get(h.OpportunityId).add(new StageEvent(h.StageName, localDate(h.CreatedDate)));
        }
        return byOpp;
    }

    public static Map<Id, List<FeeCharge>> fees(Set<Id> opportunityIds, Date since) {
        Map<Id, List<FeeCharge>> byOpp = new Map<Id, List<FeeCharge>>();
        if (opportunityIds == null || opportunityIds.isEmpty()) {
            return byOpp;
        }
        for (Fee__c f : [
            SELECT Agreement__c, Fee_Amount__c, Fee_Charged_Date__c FROM Fee__c
            WHERE Agreement__c IN :opportunityIds AND Fee_Charged_Date__c > :since
        ]) {
            if (!byOpp.containsKey(f.Agreement__c)) {
                byOpp.put(f.Agreement__c, new List<FeeCharge>());
            }
            byOpp.get(f.Agreement__c).add(new FeeCharge(f.Fee_Amount__c, f.Fee_Charged_Date__c));
        }
        return byOpp;
    }

    public static Date localDate(Datetime dt) {
        return dt == null ? null : Date.valueOf(dt.format('yyyy-MM-dd', TZ));
    }
}
