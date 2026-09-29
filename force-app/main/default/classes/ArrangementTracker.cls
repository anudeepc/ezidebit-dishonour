/**
 * Is a payment arrangement (STA on the agreement) being kept? Due dates run from the first due date
 * the collector set (STA_Next_Due_Date__c; nothing moves it forward) every payment period until the
 * arrangement's end date. Payments count from the day the arrangement started (STA_Start_Date__c).
 * A due date only counts once GRACE_DAYS have passed, because a debit reaches Salesforce a few
 * days after it's taken.
 */
public without sharing class ArrangementTracker {

    public static final Integer GRACE_DAYS = 4;
    public static final String ON_TRACK = 'On track';
    public static final String PART_PAID = 'Part paid';
    public static final String BROKEN = 'Broken';
    public static final String COMPLETED = 'Completed';
    public static final String ENDED_SHORT = 'Ended short';
    public static final String NOT_STARTED = 'Not started';

    public class Status {
        public String status { get; set; }
        public Decimal expected { get; set; }
        public Decimal paid { get; set; }
        public Decimal shortfall { get; set; }
        public Integer duesPassed { get; set; }
        public Date nextDue { get; set; }
        public String summary { get; set; }

        public Status() {
            expected = 0;
            paid = 0;
            shortfall = 0;
            duesPassed = 0;
        }
    }

    public static Status evaluate(Opportunity opp, List<Payment__c> payments, Date today) {
        if (opp == null || !opp.Is_this_a_STA__c || opp.STA_Next_Due_Date__c == null || opp.STA_Scheduled_Amount__c == null) {
            return null;
        }
        Status s = new Status();
        Date start = opp.STA_Start_Date__c != null ? opp.STA_Start_Date__c : opp.STA_Next_Due_Date__c;
        Date countUntil = today.addDays(-GRACE_DAYS);
        if (opp.STA_End_Date__c != null && opp.STA_End_Date__c < countUntil) {
            countUntil = opp.STA_End_Date__c;
        }
        Date due = opp.STA_Next_Due_Date__c;
        Integer guard = 0;
        while (due <= countUntil && guard < 400) {
            s.duesPassed++;
            due = nextDate(due, opp.Payment_Frequency__c);
            guard++;
        }
        if (opp.STA_End_Date__c == null || due <= opp.STA_End_Date__c) {
            s.nextDue = due;
        }
        s.expected = s.duesPassed * opp.STA_Scheduled_Amount__c;
        for (Payment__c p : payments) {
            if (p.Payment_Date__c != null && p.Payment_Date__c >= start && p.Actual_Amount__c != null && p.Actual_Amount__c > 0) {
                s.paid += p.Actual_Amount__c;
            }
        }
        s.shortfall = s.expected - s.paid > 0.009 ? s.expected - s.paid : 0;
        Boolean ended = opp.STA_End_Date__c != null && opp.STA_End_Date__c < today.addDays(-GRACE_DAYS);
        if (ended) {
            s.status = s.shortfall == 0 ? COMPLETED : ENDED_SHORT;
        } else if (s.duesPassed == 0) {
            s.status = NOT_STARTED;
        } else if (s.shortfall == 0) {
            s.status = ON_TRACK;
        } else if (s.shortfall + 0.009 >= opp.STA_Scheduled_Amount__c) {
            s.status = BROKEN;
        } else {
            s.status = PART_PAID;
        }
        s.summary = s.status + ': ' + s.duesPassed + ' of the arrangement\'s payments due so far, $'
            + s.paid.setScale(2) + ' paid of $' + s.expected.setScale(2)
            + (s.nextDue == null ? '' : '; next due ' + s.nextDue.format());
        return s;
    }

    @TestVisible
    static Date nextDate(Date d, String frequency) {
        String f = frequency == null ? '' : frequency.toLowerCase();
        if (f.contains('month')) {
            return d.addMonths(1);
        }
        if (f.contains('week') && !f.contains('fort')) {
            return d.addDays(7);
        }
        return d.addDays(14); // fortnightly, the usual case
    }
}
