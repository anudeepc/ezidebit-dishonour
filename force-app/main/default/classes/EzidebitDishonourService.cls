/**
 * Records Ezidebit outcomes correctly. Plan: "Ezidebit Payments and Dishonours: Build Plan".
 *
 *  - Money in stays on Payment__c (one per Ezidebit PaymentID, classified by Debit_Type__c).
 *  - Every failure is an Ezidebit_Dishonour__c, one per Ezidebit PaymentID:
 *      Instalment      D on a scheduled debit that is not a retry. Outcome starts Open.
 *      Automatic retry D of the same amount within RETRY_WINDOW_DAYS after an open instalment on
 *                      the same contract. Ezidebit's portal retries about 3 days after a failure,
 *                      which lands 4 business days after the debit. Linked to its original.
 *      Fatal           F on a scheduled debit (account closed, payment stopped...). Debits stopped.
 *      Late return     D or F with a negative amount ("Late Return - ..."): the bank took back a
 *                      payment Ezidebit first reported as successful, under the same PaymentID.
 *      Card declined   F on a customer's website card payment. Not a direct debit default.
 *  - A later success of the same amount closes the open instalment: "Recovered by retry" when it is
 *    3-4 business days after the debit, otherwise "Recovered by later payment".
 *
 * The debit date is kept because NCC s87(2) runs the Form 11A 14 days from the default, not from
 * when Ezidebit reports it. Every step can be switched off in Ezidebit_Sync_Settings__c.
 */
public without sharing class EzidebitDishonourService {

    public static final String FEE_TYPE_DISHONOUR = 'Late Payment';

    public static final String TYPE_INSTALMENT = 'Instalment';
    public static final String TYPE_RETRY = 'Automatic retry';
    public static final String TYPE_FATAL = 'Fatal';
    public static final String TYPE_LATE_RETURN = 'Late return';
    public static final String TYPE_CARD_DECLINED = 'Card declined';

    public static final String OUTCOME_OPEN = 'Open';
    public static final String OUTCOME_RETRY = 'Recovered by retry';
    public static final String OUTCOME_LATER = 'Recovered by later payment';
    public static final String OUTCOME_STOPPED = 'Debits stopped';

    public static final String DEBIT_INSTALMENT = 'Instalment';
    public static final String DEBIT_RETRY = 'Automatic retry';
    public static final String DEBIT_CARD = 'Online card';
    public static final String DEBIT_FIRST = 'First debit';

    @TestVisible static final Integer RETRY_WINDOW_DAYS = 11;
    @TestVisible static final Integer OPEN_LOOKBACK_DAYS = 45;
    @TestVisible static final Integer FEE_MATCH_DAYS = 60;
    private static final Set<Integer> RETRY_BUSINESS_DAYS = new Set<Integer>{ 3, 4 };
    private static final Set<String> DEFAULT_TYPES = new Set<String>{ TYPE_INSTALMENT, TYPE_FATAL, TYPE_LATE_RETURN };

    /** How a capture run records failures. Live runs use the defaults. */
    public class CaptureOptions {
        public Boolean backfill = false;      // history load: marked Is_Backfill__c, never a first default
        public Boolean activeOnly = false;    // only active credit contracts (history load: leases are left out)
        public Boolean dryRun = false;        // count only, write nothing
    }

    public class Result {
        public Integer inserted = 0;
        public Integer updated = 0;
        public Integer paymentsFlagged = 0;
        public Integer wouldInsert = 0;          // dry run: new records that would be created
        public Decimal ezidebitFees = 0;         // dry run: Ezidebit fees on those records
        public Integer skippedInactive = 0;
        public Integer relinked = 0;             // retries recorded before their original, now linked
        public Set<Id> newlyRecordedOpportunityIds = new Set<Id>();
    }

    public static Ezidebit_Sync_Settings__c settings() {
        Ezidebit_Sync_Settings__c s = Ezidebit_Sync_Settings__c.getInstance();
        return s == null ? new Ezidebit_Sync_Settings__c() : s;
    }

    public static Boolean isFailure(EzidebitAPI.Payment p) {
        return p != null && (p.PaymentStatus == 'D' || p.PaymentStatus == 'F');
    }

    public static Boolean isLateReturn(EzidebitAPI.Payment p) {
        return isFailure(p) && ((p.PaymentAmount != null && p.PaymentAmount < 0)
            || (p.BankFailedReason != null && p.BankFailedReason.startsWithIgnoreCase('Late Return')));
    }

    // ---- failures ------------------------------------------------------------------------

    /** Records the D and F payments in the list. Payments without a PaymentID are skipped. */
    public static Result capture(List<EzidebitAPI.Payment> payments, Map<String, String> territoryByPaymentId) {
        return capture(payments, territoryByPaymentId, new CaptureOptions());
    }

    public static Result capture(List<EzidebitAPI.Payment> payments, Map<String, String> territoryByPaymentId, CaptureOptions opts) {
        Result res = new Result();
        opts = opts == null ? new CaptureOptions() : opts;
        if (payments == null || settings().Disable_Dishonour_Recording__c) {
            return res;
        }
        Map<String, EzidebitAPI.Payment> failed = new Map<String, EzidebitAPI.Payment>();
        Set<String> refs = new Set<String>();
        for (EzidebitAPI.Payment p : payments) {
            if (isFailure(p) && String.isNotBlank(p.PaymentID)) {
                failed.put(p.PaymentID, p);
                if (String.isNotBlank(p.YourSystemReference)) {
                    refs.add(p.YourSystemReference);
                }
            }
        }
        if (failed.isEmpty()) {
            return res;
        }

        Map<String, Ezidebit_Dishonour__c> existing = new Map<String, Ezidebit_Dishonour__c>();
        for (Ezidebit_Dishonour__c d : [
            SELECT Id, Ezidebit_Payment_ID__c FROM Ezidebit_Dishonour__c WHERE Ezidebit_Payment_ID__c IN :failed.keySet()
        ]) {
            existing.put(d.Ezidebit_Payment_ID__c, d);
        }
        Map<String, Opportunity> oppByRef = new Map<String, Opportunity>();
        for (Opportunity o : [SELECT Id, AccountId, Contract_No__c, MP1__c, Is_Active__c, Is_Credit_Contract__c FROM Opportunity WHERE Contract_No__c IN :refs]) {
            oppByRef.put(o.Contract_No__c, o);
        }
        Map<String, Account> acctByRef = new Map<String, Account>();
        for (Account a : [SELECT Id, Customer_No__c FROM Account WHERE Customer_No__c IN :refs]) {
            acctByRef.put(a.Customer_No__c, a);
        }
        Set<Id> oppsWithFirstDefault = new Set<Id>();
        for (AggregateResult ar : [
            SELECT Opportunity__c oppId FROM Ezidebit_Dishonour__c
            WHERE Opportunity__c IN :idsOf(oppByRef.values()) AND First_Default__c = true
            GROUP BY Opportunity__c
        ]) {
            oppsWithFirstDefault.add((Id) ar.get('oppId'));
        }
        Date earliestDebit = null;
        for (EzidebitAPI.Payment p : failed.values()) {
            Date dd = toDate(p.DebitDate);
            if (dd != null && (earliestDebit == null || dd < earliestDebit)) {
                earliestDebit = dd;
            }
        }
        // Live: open instalments from the last OPEN_LOOKBACK_DAYS. History: those just before this window.
        Date openSince = opts.backfill && earliestDebit != null
            ? earliestDebit.addDays(-RETRY_WINDOW_DAYS - 1)
            : Date.today().addDays(-OPEN_LOOKBACK_DAYS);
        Map<String, List<Ezidebit_Dishonour__c>> openByRef = openInstalmentsByRef(refs, openSince);

        List<Ezidebit_Dishonour__c> firstPass = new List<Ezidebit_Dishonour__c>();
        // Retries whose original is new in this same run: inserted after the originals have Ids.
        List<Ezidebit_Dishonour__c> pendingRetries = new List<Ezidebit_Dishonour__c>();
        List<Ezidebit_Dishonour__c> pendingOriginals = new List<Ezidebit_Dishonour__c>();
        List<Ezidebit_Dishonour__c> toUpdate = new List<Ezidebit_Dishonour__c>();
        Map<String, Ezidebit_Dishonour__c> lateReturnsById = new Map<String, Ezidebit_Dishonour__c>();

        for (EzidebitAPI.Payment p : sortByDebitDate(failed.values())) {
            Ezidebit_Dishonour__c d = new Ezidebit_Dishonour__c(
                Status__c = p.PaymentStatus,
                Settlement_Date__c = toDate(p.SettlementDate),
                Bank_Return_Code__c = p.BankReturnCode,
                Bank_Failed_Reason__c = p.BankFailedReason == null ? null : p.BankFailedReason.left(255),
                Ezidebit_Fee__c = toDecimal(p.TransactionFeeClient),
                Ezidebit_Customer_Fee__c = toDecimal(p.TransactionFeeCustomer)
            );
            Ezidebit_Dishonour__c prior = existing.get(p.PaymentID);
            if (prior != null) {
                d.Id = prior.Id;
                toUpdate.add(d);
                continue;
            }
            Opportunity opp = oppByRef.get(p.YourSystemReference);
            if (opts.activeOnly && (opp == null || !opp.Is_Active__c || !opp.Is_Credit_Contract__c)) {
                res.skippedInactive++;
                continue;
            }
            Account acct = acctByRef.get(p.YourSystemReference);
            Decimal amount = toDecimal(p.PaymentAmount);
            d.Ezidebit_Payment_ID__c = p.PaymentID;
            d.Contract_Reference__c = p.YourSystemReference;
            d.Ezidebit_Customer_ID__c = p.EzidebitCustomerID;
            d.Territory_Name__c = territoryByPaymentId == null ? null : territoryByPaymentId.get(p.PaymentID);
            d.Payment_Method__c = p.PaymentMethod;
            d.Payment_Source__c = p.PaymentSource;
            d.Is_Scheduled_Debit__c = p.PaymentSource != 'WEB';
            d.Debit_Date__c = toDate(p.DebitDate);
            d.Received_Date__c = Date.today();
            d.Is_Backfill__c = opts.backfill;
            d.Scheduled_Amount__c = toDecimal(p.ScheduledAmount);
            d.Payment_Amount__c = amount == null ? null : amount.abs();
            d.Opportunity__c = opp == null ? null : opp.Id;
            d.Account__c = opp != null ? opp.AccountId : (acct == null ? null : acct.Id);

            if (isLateReturn(p)) {
                d.Type__c = TYPE_LATE_RETURN;
                lateReturnsById.put(p.PaymentID, d);
            } else if (p.PaymentSource == 'WEB') {
                d.Type__c = TYPE_CARD_DECLINED;
            } else if (p.PaymentStatus == 'F') {
                d.Type__c = TYPE_FATAL;
                d.Outcome__c = OUTCOME_STOPPED;
            } else {
                Ezidebit_Dishonour__c original = findOpenOriginal(openByRef.get(p.YourSystemReference), d.Debit_Date__c, d.Payment_Amount__c);
                if (original != null) {
                    d.Type__c = TYPE_RETRY;
                    if (original.Id != null) {
                        d.Original_Dishonour__c = original.Id;
                    } else {
                        pendingRetries.add(d);
                        pendingOriginals.add(original);
                    }
                } else {
                    d.Type__c = TYPE_INSTALMENT;
                    d.Outcome__c = OUTCOME_OPEN;
                    if (!openByRef.containsKey(p.YourSystemReference)) {
                        openByRef.put(p.YourSystemReference, new List<Ezidebit_Dishonour__c>());
                    }
                    openByRef.get(p.YourSystemReference).add(d);
                }
            }
            if (!opts.backfill && opp != null && opp.Is_Credit_Contract__c && d.Is_Scheduled_Debit__c && DEFAULT_TYPES.contains(d.Type__c)
                    && opp.MP1__c == null && !oppsWithFirstDefault.contains(opp.Id)) {
                d.First_Default__c = true;
                oppsWithFirstDefault.add(opp.Id);
            }
            if (opp != null) {
                res.newlyRecordedOpportunityIds.add(opp.Id);
            }
            if (d.Type__c != TYPE_RETRY || d.Original_Dishonour__c != null) {
                firstPass.add(d);
            }
        }

        if (opts.dryRun) {
            res.wouldInsert = firstPass.size() + pendingRetries.size();
            for (Ezidebit_Dishonour__c d : firstPass) {
                res.ezidebitFees += d.Ezidebit_Fee__c == null ? 0 : d.Ezidebit_Fee__c;
            }
            for (Ezidebit_Dishonour__c d : pendingRetries) {
                res.ezidebitFees += d.Ezidebit_Fee__c == null ? 0 : d.Ezidebit_Fee__c;
            }
            return res;
        }
        res.paymentsFlagged = linkLateReturns(lateReturnsById);
        res.inserted = save(firstPass, true);
        List<Ezidebit_Dishonour__c> secondPass = new List<Ezidebit_Dishonour__c>();
        for (Integer i = 0; i < pendingRetries.size(); i++) {
            pendingRetries[i].Original_Dishonour__c = pendingOriginals[i].Id;
            secondPass.add(pendingRetries[i]);
        }
        res.inserted += save(secondPass, true);
        res.updated = save(toUpdate, false);
        List<Ezidebit_Dishonour__c> newInstalments = new List<Ezidebit_Dishonour__c>();
        for (Ezidebit_Dishonour__c d : firstPass) {
            if (d.Id != null && d.Type__c == TYPE_INSTALMENT) {
                newInstalments.add(d);
            }
        }
        res.relinked = relinkLaterRetries(newInstalments);
        return res;
    }

    /**
     * A failure can reach Salesforce after its own retry did (at go-live, or when the catch-up finds a
     * missed day): the retry was then recorded as a missed instalment. For each instalment just
     * recorded, a later instalment of the same contract and amount within the retry window is really
     * its retry: relink it, and move the first-default flag back to the real first failure.
     */
    public static Integer relinkLaterRetries(List<Ezidebit_Dishonour__c> instalments) {
        if (instalments == null || instalments.isEmpty()) {
            return 0;
        }
        // Only records that are still missed instalments now (a repair run passes a stale snapshot).
        Set<Id> candidateIds = new Set<Id>();
        for (Ezidebit_Dishonour__c d : instalments) {
            if (d.Id != null) {
                candidateIds.add(d.Id);
            }
        }
        instalments = [
            SELECT Id, Contract_Reference__c, Debit_Date__c, Payment_Amount__c, Is_Backfill__c
            FROM Ezidebit_Dishonour__c WHERE Id IN :candidateIds AND Type__c = :TYPE_INSTALMENT
            ORDER BY Debit_Date__c ASC
        ];
        Set<String> refs = new Set<String>();
        Date minDebit = null;
        Date maxDebit = null;
        for (Ezidebit_Dishonour__c d : instalments) {
            if (d.Id == null || d.Debit_Date__c == null || String.isBlank(d.Contract_Reference__c)) {
                continue;
            }
            refs.add(d.Contract_Reference__c);
            minDebit = minDebit == null || d.Debit_Date__c < minDebit ? d.Debit_Date__c : minDebit;
            maxDebit = maxDebit == null || d.Debit_Date__c > maxDebit ? d.Debit_Date__c : maxDebit;
        }
        if (refs.isEmpty()) {
            return 0;
        }
        Date until = maxDebit.addDays(RETRY_WINDOW_DAYS);
        Map<String, List<Ezidebit_Dishonour__c>> laterByRef = new Map<String, List<Ezidebit_Dishonour__c>>();
        for (Ezidebit_Dishonour__c d : [
            SELECT Id, Contract_Reference__c, Debit_Date__c, Payment_Amount__c, First_Default__c, Form_11A_Sent_Date__c
            FROM Ezidebit_Dishonour__c
            WHERE Contract_Reference__c IN :refs AND Type__c = :TYPE_INSTALMENT AND Original_Dishonour__c = null
              AND Debit_Date__c > :minDebit AND Debit_Date__c <= :until
            ORDER BY Debit_Date__c ASC
        ]) {
            if (!laterByRef.containsKey(d.Contract_Reference__c)) {
                laterByRef.put(d.Contract_Reference__c, new List<Ezidebit_Dishonour__c>());
            }
            laterByRef.get(d.Contract_Reference__c).add(d);
        }
        Map<Id, Ezidebit_Dishonour__c> updates = new Map<Id, Ezidebit_Dishonour__c>();
        for (Ezidebit_Dishonour__c original : instalments) {
            List<Ezidebit_Dishonour__c> later = laterByRef.get(original.Contract_Reference__c);
            if (later == null) {
                continue;
            }
            if (updates.containsKey(original.Id) && updates.get(original.Id).Type__c == TYPE_RETRY) {
                continue; // became a retry earlier in this run
            }
            for (Ezidebit_Dishonour__c l : later) {
                if (updates.containsKey(l.Id) || !withinRetryWindow(original.Debit_Date__c, l.Debit_Date__c)
                        || !sameAmount(original.Payment_Amount__c, l.Payment_Amount__c)) {
                    continue;
                }
                Ezidebit_Dishonour__c retry = new Ezidebit_Dishonour__c(Id = l.Id, Type__c = TYPE_RETRY,
                    Original_Dishonour__c = original.Id, Outcome__c = null);
                if (l.First_Default__c && l.Form_11A_Sent_Date__c == null) {
                    retry.First_Default__c = false;
                    Ezidebit_Dishonour__c first = updates.containsKey(original.Id) ? updates.get(original.Id) : new Ezidebit_Dishonour__c(Id = original.Id);
                    first.First_Default__c = true;
                    first.Is_Backfill__c = false; // the notice for this default is still live
                    updates.put(original.Id, first);
                }
                updates.put(l.Id, retry);
                break; // one retry per instalment
            }
        }
        save(updates.values(), false);
        Integer relinked = 0;
        for (Ezidebit_Dishonour__c u : updates.values()) {
            if (u.Type__c == TYPE_RETRY) {
                relinked++;
            }
        }
        return relinked;
    }

    /**
     * For each open instalment, the first later successful payment of the same amount within the
     * retry window recovers it. Links the Payment__c when it already exists; otherwise the upload
     * links it when the payment is created (see UploadContext).
     */
    public static Integer recordRecoveries(List<EzidebitAPI.Payment> payments) {
        if (payments == null || settings().Disable_Dishonour_Recording__c) {
            return 0;
        }
        Map<String, List<EzidebitAPI.Payment>> okByRef = new Map<String, List<EzidebitAPI.Payment>>();
        Set<String> okIds = new Set<String>();
        for (EzidebitAPI.Payment p : payments) {
            if (p != null && p.PaymentStatus == 'S' && String.isNotBlank(p.YourSystemReference) && p.DebitDate != null
                    && p.PaymentAmount != null && p.PaymentAmount > 0) {
                if (!okByRef.containsKey(p.YourSystemReference)) {
                    okByRef.put(p.YourSystemReference, new List<EzidebitAPI.Payment>());
                }
                okByRef.get(p.YourSystemReference).add(p);
                if (p.PaymentID != null) {
                    okIds.add(p.PaymentID);
                }
            }
        }
        if (okByRef.isEmpty()) {
            return 0;
        }
        for (String ref : okByRef.keySet()) {
            okByRef.put(ref, sortByDebitDate(okByRef.get(ref)));
        }
        Map<String, Id> paymentIdToRecord = new Map<String, Id>();
        for (Payment__c pay : [SELECT Id, Ezidebit_Payment_ID__c FROM Payment__c WHERE Ezidebit_Payment_ID__c IN :okIds]) {
            paymentIdToRecord.put(pay.Ezidebit_Payment_ID__c, pay.Id);
        }
        List<Ezidebit_Dishonour__c> toUpdate = new List<Ezidebit_Dishonour__c>();
        Set<String> used = new Set<String>();
        Map<String, List<Ezidebit_Dishonour__c>> openByRef = openInstalmentsByRef(okByRef.keySet(), Date.today().addDays(-OPEN_LOOKBACK_DAYS));
        for (String ref : openByRef.keySet()) {
            for (Ezidebit_Dishonour__c d : openByRef.get(ref)) {
                for (EzidebitAPI.Payment p : okByRef.get(ref)) {
                    Date paid = toDate(p.DebitDate);
                    if ((p.PaymentID != null && used.contains(p.PaymentID)) || !withinRetryWindow(d.Debit_Date__c, paid)
                            || !sameAmount(d.Payment_Amount__c, toDecimal(p.PaymentAmount))) {
                        continue;
                    }
                    d.Outcome__c = RETRY_BUSINESS_DAYS.contains(businessDaysBetween(d.Debit_Date__c, paid)) ? OUTCOME_RETRY : OUTCOME_LATER;
                    d.Recovered_By_Payment_ID__c = p.PaymentID;
                    d.Recovered_Date__c = paid;
                    d.Recovery_Ezidebit_Fee__c = toDecimal(p.TransactionFeeClient);
                    d.Recovered_By_Payment__c = paymentIdToRecord.get(p.PaymentID);
                    used.add(p.PaymentID);
                    toUpdate.add(d);
                    break;
                }
            }
        }
        return save(toUpdate, false);
    }

    /**
     * History: closes open instalments using payments already in Salesforce (older payments have no
     * Ezidebit payment ID), matched by agreement, amount and 1-RETRY_WINDOW_DAYS after the debit.
     */
    public static Integer recoverFromPayments(List<Ezidebit_Dishonour__c> openInstalments) {
        Set<Id> oppIds = new Set<Id>();
        Date minDate = null;
        Date maxDate = null;
        for (Ezidebit_Dishonour__c d : openInstalments) {
            if (d.Opportunity__c == null || d.Debit_Date__c == null) {
                continue;
            }
            oppIds.add(d.Opportunity__c);
            minDate = minDate == null || d.Debit_Date__c < minDate ? d.Debit_Date__c : minDate;
            maxDate = maxDate == null || d.Debit_Date__c > maxDate ? d.Debit_Date__c : maxDate;
        }
        if (oppIds.isEmpty()) {
            return 0;
        }
        Date toDateLimit = maxDate.addDays(RETRY_WINDOW_DAYS);
        Map<Id, List<Payment__c>> paysByOpp = new Map<Id, List<Payment__c>>();
        for (Payment__c p : [
            SELECT Id, Agreement__c, Payment_Date__c, Actual_Amount__c, Client_Fees__c, Ezidebit_Payment_ID__c, Late_Returned__c
            FROM Payment__c
            WHERE Agreement__c IN :oppIds AND Payment_Date__c > :minDate AND Payment_Date__c <= :toDateLimit
              AND Actual_Amount__c > 0 AND Late_Returned__c = false
            ORDER BY Payment_Date__c ASC
        ]) {
            if (!paysByOpp.containsKey(p.Agreement__c)) {
                paysByOpp.put(p.Agreement__c, new List<Payment__c>());
            }
            paysByOpp.get(p.Agreement__c).add(p);
        }
        List<Ezidebit_Dishonour__c> updates = new List<Ezidebit_Dishonour__c>();
        Set<Id> used = new Set<Id>();
        for (Ezidebit_Dishonour__c d : openInstalments) {
            List<Payment__c> pays = paysByOpp.get(d.Opportunity__c);
            if (pays == null) {
                continue;
            }
            for (Payment__c p : pays) {
                if (used.contains(p.Id) || !withinRetryWindow(d.Debit_Date__c, p.Payment_Date__c)
                        || !sameAmount(d.Payment_Amount__c, p.Actual_Amount__c)) {
                    continue;
                }
                used.add(p.Id);
                updates.add(new Ezidebit_Dishonour__c(
                    Id = d.Id,
                    Outcome__c = RETRY_BUSINESS_DAYS.contains(businessDaysBetween(d.Debit_Date__c, p.Payment_Date__c)) ? OUTCOME_RETRY : OUTCOME_LATER,
                    Recovered_By_Payment__c = p.Id,
                    Recovered_By_Payment_ID__c = p.Ezidebit_Payment_ID__c,
                    Recovered_Date__c = p.Payment_Date__c,
                    Recovery_Ezidebit_Fee__c = p.Client_Fees__c
                ));
                break;
            }
        }
        return save(updates, false);
    }

    // ---- payment upload ------------------------------------------------------------------

    /**
     * Everything the payment upload needs for one batch of EzidebitSettled__c rows, fetched in
     * three queries: payments already recorded (duplicates, fee refresh), instalments recovered by
     * these payments, and agreements that already have an Ezidebit payment (first debit).
     */
    public class UploadContext {
        public Map<String, Payment__c> existingById = new Map<String, Payment__c>();
        public Map<String, Ezidebit_Dishonour__c> recoveredById = new Map<String, Ezidebit_Dishonour__c>();
        public Set<Id> agreementsWithPayments = new Set<Id>();
        public List<Ezidebit_Dishonour__c> dishonourLinks = new List<Ezidebit_Dishonour__c>();
        public List<Payment__c> feeRefreshes = new List<Payment__c>();

        /** True when this Ezidebit payment is already recorded: refresh its fee instead of inserting. */
        public Boolean isDuplicate(EzidebitSettled__c ezi) {
            if (settings().Disable_Duplicate_Prevention__c || ezi.PaymentID__c == null) {
                return false;
            }
            Payment__c prior = existingById.get(ezi.PaymentID__c);
            if (prior == null) {
                return false;
            }
            if (ezi.ClientFee__c != null && ezi.ClientFee__c != prior.Client_Fees__c) {
                feeRefreshes.add(new Payment__c(Id = prior.Id, Client_Fees__c = ezi.ClientFee__c));
            }
            return true;
        }

        public String debitType(EzidebitSettled__c ezi) {
            if (settings().Disable_Debit_Classification__c) {
                return null;
            }
            if (ezi.PaymentSource__c == 'WEB') {
                return DEBIT_CARD;
            }
            Ezidebit_Dishonour__c recovered = ezi.PaymentID__c == null ? null : recoveredById.get(ezi.PaymentID__c);
            if (recovered != null && recovered.Outcome__c == OUTCOME_RETRY) {
                return DEBIT_RETRY;
            }
            if (ezi.Opportunity__c != null && !agreementsWithPayments.contains(ezi.Opportunity__c)) {
                agreementsWithPayments.add(ezi.Opportunity__c);
                return DEBIT_FIRST;
            }
            return DEBIT_INSTALMENT;
        }

        /** Sets the payment's link before insert; the dishonour's link is saved by flush(). */
        public void linkBeforeInsert(Payment__c payment, EzidebitSettled__c ezi) {
            Ezidebit_Dishonour__c recovered = ezi.PaymentID__c == null ? null : recoveredById.get(ezi.PaymentID__c);
            if (recovered != null) {
                payment.Recovered_Dishonour__c = recovered.Id;
            }
        }

        public void linkAfterInsert(Payment__c payment) {
            if (payment.Id != null && payment.Ezidebit_Payment_ID__c != null) {
                existingById.put(payment.Ezidebit_Payment_ID__c, payment); // a second copy later in the same run is a duplicate
            }
            if (payment.Id != null && payment.Recovered_Dishonour__c != null) {
                dishonourLinks.add(new Ezidebit_Dishonour__c(Id = payment.Recovered_Dishonour__c, Recovered_By_Payment__c = payment.Id));
            }
        }

        public void flush() {
            save(dishonourLinks, false);
            if (!feeRefreshes.isEmpty()) {
                logErrors(Database.update(feeRefreshes, false), 'feeRefresh');
            }
            dishonourLinks.clear();
            feeRefreshes.clear();
        }
    }

    public static UploadContext uploadContext(List<EzidebitSettled__c> rows) {
        UploadContext ctx = new UploadContext();
        Set<String> ids = new Set<String>();
        Set<Id> oppIds = new Set<Id>();
        for (EzidebitSettled__c e : rows) {
            if (e.PaymentID__c != null) {
                ids.add(e.PaymentID__c);
            }
            if (e.Opportunity__c != null) {
                oppIds.add(e.Opportunity__c);
            }
        }
        if (!ids.isEmpty()) {
            for (Payment__c p : [SELECT Id, Ezidebit_Payment_ID__c, Client_Fees__c FROM Payment__c WHERE Ezidebit_Payment_ID__c IN :ids]) {
                ctx.existingById.put(p.Ezidebit_Payment_ID__c, p);
            }
            for (Ezidebit_Dishonour__c d : [
                SELECT Id, Recovered_By_Payment_ID__c, Outcome__c FROM Ezidebit_Dishonour__c WHERE Recovered_By_Payment_ID__c IN :ids
            ]) {
                ctx.recoveredById.put(d.Recovered_By_Payment_ID__c, d);
            }
        }
        if (!oppIds.isEmpty()) {
            for (AggregateResult ar : [
                SELECT Agreement__c agreementId FROM Payment__c
                WHERE Agreement__c IN :oppIds AND RecordTypeId = :PaymentUtil.RECORDTYPE_ID_EZIDEBIT
                GROUP BY Agreement__c
            ]) {
                ctx.agreementsWithPayments.add((Id) ar.get('agreementId'));
            }
        }
        return ctx;
    }

    // ---- R4K dishonour fee ---------------------------------------------------------------

    /**
     * Links each new R4K dishonour fee to the latest failed instalment (not a retry) on its
     * contract with no fee yet, within FEE_MATCH_DAYS before the fee was charged.
     */
    public static void linkFeesSafely(List<Fee__c> fees) {
        try {
            linkFees(fees);
        } catch (Exception ex) {
            ErrorLog.addErrorLog('EzidebitDishonourService', 'linkFees', '', String.valueOf(ex), String.valueOf(ex.getLineNumber()));
        }
    }

    public static void linkFees(List<Fee__c> fees) {
        Map<Id, List<Fee__c>> feesByOpp = new Map<Id, List<Fee__c>>();
        for (Fee__c f : fees) {
            if (f.Agreement__c != null && f.Fee_Type__c == FEE_TYPE_DISHONOUR && f.Ezidebit_Dishonour__c == null) {
                if (!feesByOpp.containsKey(f.Agreement__c)) {
                    feesByOpp.put(f.Agreement__c, new List<Fee__c>());
                }
                feesByOpp.get(f.Agreement__c).add(f);
            }
        }
        if (feesByOpp.isEmpty()) {
            return;
        }
        Date earliest = null;
        Date latest = null;
        for (List<Fee__c> byOpp : feesByOpp.values()) {
            for (Fee__c f : byOpp) {
                Date charged = f.Fee_Charged_Date__c != null ? f.Fee_Charged_Date__c : Date.today();
                earliest = earliest == null || charged < earliest ? charged : earliest;
                latest = latest == null || charged > latest ? charged : latest;
            }
        }
        earliest = earliest.addDays(-FEE_MATCH_DAYS - 1);
        Map<Id, List<Ezidebit_Dishonour__c>> openByOpp = new Map<Id, List<Ezidebit_Dishonour__c>>();
        for (Ezidebit_Dishonour__c d : [
            SELECT Id, Opportunity__c, Debit_Date__c FROM Ezidebit_Dishonour__c
            WHERE Opportunity__c IN :feesByOpp.keySet() AND Fee__c = null AND Debit_Date__c >= :earliest AND Debit_Date__c <= :latest
              AND Type__c IN :DEFAULT_TYPES
            ORDER BY Debit_Date__c DESC
        ]) {
            if (!openByOpp.containsKey(d.Opportunity__c)) {
                openByOpp.put(d.Opportunity__c, new List<Ezidebit_Dishonour__c>());
            }
            openByOpp.get(d.Opportunity__c).add(d);
        }
        List<Ezidebit_Dishonour__c> dishonours = new List<Ezidebit_Dishonour__c>();
        List<Fee__c> feeUpdates = new List<Fee__c>();
        for (Id oppId : feesByOpp.keySet()) {
            List<Ezidebit_Dishonour__c> open = openByOpp.get(oppId);
            for (Fee__c f : feesByOpp.get(oppId)) {
                Date charged = f.Fee_Charged_Date__c != null ? f.Fee_Charged_Date__c : Date.today();
                Ezidebit_Dishonour__c match = null;
                if (open != null) {
                    for (Integer i = 0; i < open.size(); i++) {
                        Ezidebit_Dishonour__c d = open[i];
                        if (d.Debit_Date__c != null && d.Debit_Date__c <= charged && d.Debit_Date__c >= charged.addDays(-FEE_MATCH_DAYS)) {
                            match = open.remove(i);
                            break;
                        }
                    }
                }
                if (match == null) {
                    continue;
                }
                dishonours.add(new Ezidebit_Dishonour__c(
                    Id = match.Id,
                    Fee__c = f.Id,
                    Dishonour_Fee_Charged__c = f.Fee_Amount__c,
                    Dishonour_Fee_Charged_Date__c = charged
                ));
                feeUpdates.add(new Fee__c(Id = f.Id, Ezidebit_Dishonour__c = match.Id));
            }
        }
        save(dishonours, false);
        if (!feeUpdates.isEmpty()) {
            logErrors(Database.update(feeUpdates, false), 'linkFees');
        }
    }

    // ---- helpers -------------------------------------------------------------------------

    /**
     * Finds the Salesforce payment(s) each late return took back: by Ezidebit PaymentID, or for
     * payments recorded before the ID was stored, by contract, debit date and amount. Sets the
     * dishonour's link, flags the payments and reopens any instalment they had recovered.
     */
    private static Integer linkLateReturns(Map<String, Ezidebit_Dishonour__c> lateReturnsById) {
        if (lateReturnsById.isEmpty()) {
            return 0;
        }
        Map<String, List<Payment__c>> paymentsById = new Map<String, List<Payment__c>>();
        for (Payment__c pay : [
            SELECT Id, Ezidebit_Payment_ID__c, Late_Returned__c FROM Payment__c WHERE Ezidebit_Payment_ID__c IN :lateReturnsById.keySet()
        ]) {
            paymentsById.put(pay.Ezidebit_Payment_ID__c, new List<Payment__c>{ pay });
        }
        Set<String> refs = new Set<String>();
        Set<Date> dates = new Set<Date>();
        for (String pid : lateReturnsById.keySet()) {
            if (!paymentsById.containsKey(pid)) {
                refs.add(lateReturnsById.get(pid).Contract_Reference__c);
                dates.add(lateReturnsById.get(pid).Debit_Date__c);
            }
        }
        if (!refs.isEmpty()) {
            List<Payment__c> candidates = [
                SELECT Id, Ezidebit_Payment_ID__c, Late_Returned__c, Agreement__r.Contract_No__c, Payment_Date__c, Actual_Amount__c
                FROM Payment__c
                WHERE Agreement__r.Contract_No__c IN :refs AND Payment_Date__c IN :dates
                  AND RecordTypeId = :PaymentUtil.RECORDTYPE_ID_EZIDEBIT AND Ezidebit_Payment_ID__c = null
            ];
            for (String pid : lateReturnsById.keySet()) {
                if (paymentsById.containsKey(pid)) {
                    continue;
                }
                Ezidebit_Dishonour__c d = lateReturnsById.get(pid);
                for (Payment__c c : candidates) {
                    if (c.Agreement__r.Contract_No__c == d.Contract_Reference__c && c.Payment_Date__c == d.Debit_Date__c
                            && sameAmount(c.Actual_Amount__c, d.Payment_Amount__c)) {
                        if (!paymentsById.containsKey(pid)) {
                            paymentsById.put(pid, new List<Payment__c>());
                        }
                        paymentsById.get(pid).add(c);
                    }
                }
            }
        }
        List<Payment__c> flags = new List<Payment__c>();
        Boolean flagOn = !settings().Disable_Late_Return_Flag__c;
        for (String pid : lateReturnsById.keySet()) {
            List<Payment__c> taken = paymentsById.get(pid);
            if (taken == null || taken.isEmpty()) {
                continue;
            }
            Ezidebit_Dishonour__c d = lateReturnsById.get(pid);
            d.Reversed_Payment__c = taken[0].Id;
            if (flagOn) {
                for (Payment__c pay : taken) {
                    if (!pay.Late_Returned__c) {
                        flags.add(new Payment__c(Id = pay.Id, Late_Returned__c = true,
                            Late_Returned_Date__c = d.Settlement_Date__c != null ? d.Settlement_Date__c : Date.today()));
                    }
                }
            }
        }
        List<Ezidebit_Dishonour__c> reopen = new List<Ezidebit_Dishonour__c>();
        for (Ezidebit_Dishonour__c d : [
            SELECT Id FROM Ezidebit_Dishonour__c WHERE Recovered_By_Payment_ID__c IN :lateReturnsById.keySet()
        ]) {
            reopen.add(new Ezidebit_Dishonour__c(Id = d.Id, Outcome__c = OUTCOME_OPEN, Recovered_By_Payment_ID__c = null,
                Recovered_By_Payment__c = null, Recovered_Date__c = null, Recovery_Ezidebit_Fee__c = null));
        }
        save(reopen, false);
        if (flags.isEmpty()) {
            return 0;
        }
        return logErrors(Database.update(flags, false), 'flagLateReturns');
    }

    private static Map<String, List<Ezidebit_Dishonour__c>> openInstalmentsByRef(Set<String> refs, Date since) {
        Map<String, List<Ezidebit_Dishonour__c>> byRef = new Map<String, List<Ezidebit_Dishonour__c>>();
        for (Ezidebit_Dishonour__c d : [
            SELECT Id, Contract_Reference__c, Debit_Date__c, Payment_Amount__c FROM Ezidebit_Dishonour__c
            WHERE Contract_Reference__c IN :refs AND Type__c = :TYPE_INSTALMENT AND Outcome__c = :OUTCOME_OPEN
              AND Debit_Date__c >= :since
            ORDER BY Debit_Date__c ASC
        ]) {
            if (!byRef.containsKey(d.Contract_Reference__c)) {
                byRef.put(d.Contract_Reference__c, new List<Ezidebit_Dishonour__c>());
            }
            byRef.get(d.Contract_Reference__c).add(d);
        }
        return byRef;
    }

    /** The latest open instalment this failed debit could be a retry of. */
    private static Ezidebit_Dishonour__c findOpenOriginal(List<Ezidebit_Dishonour__c> open, Date debit, Decimal amount) {
        if (open == null) {
            return null;
        }
        Ezidebit_Dishonour__c best = null;
        for (Ezidebit_Dishonour__c d : open) {
            if (withinRetryWindow(d.Debit_Date__c, debit) && sameAmount(d.Payment_Amount__c, amount)) {
                best = d;
            }
        }
        return best;
    }

    @TestVisible
    private static Boolean withinRetryWindow(Date original, Date later) {
        if (original == null || later == null) {
            return false;
        }
        Integer gap = original.daysBetween(later);
        return gap >= 1 && gap <= RETRY_WINDOW_DAYS;
    }

    private static Boolean sameAmount(Decimal a, Decimal b) {
        return a != null && b != null && (a.abs() - b.abs()).abs() < 0.01;
    }

    /** Weekdays after `fromDate` up to and including `toDate`. Public holidays are not excluded. */
    @TestVisible
    private static Integer businessDaysBetween(Date fromDate, Date toDate) {
        Integer n = 0;
        Date d = fromDate;
        while (d < toDate) {
            d = d.addDays(1);
            Integer dow = Math.mod(Date.newInstance(1900, 1, 7).daysBetween(d), 7); // 0 = Sunday
            if (dow != 0 && dow != 6) {
                n++;
            }
        }
        return n;
    }

    private static Integer save(List<Ezidebit_Dishonour__c> records, Boolean isInsert) {
        if (records.isEmpty()) {
            return 0;
        }
        Database.SaveResult[] results = isInsert ? Database.insert(records, false) : Database.update(records, false);
        return logErrors(results, isInsert ? 'insert' : 'update');
    }

    private static Integer logErrors(Database.SaveResult[] results, String step) {
        Integer ok = 0;
        for (Database.SaveResult r : results) {
            if (r.isSuccess()) {
                ok++;
            } else {
                ErrorLog.addErrorLog('EzidebitDishonourService', step, String.valueOf(r.getId()), String.valueOf(r.getErrors()), '');
            }
        }
        return ok;
    }

    private static Set<Id> idsOf(List<Opportunity> opps) {
        Set<Id> ids = new Set<Id>();
        for (Opportunity o : opps) {
            ids.add(o.Id);
        }
        return ids;
    }

    @TestVisible
    private static List<EzidebitAPI.Payment> sortByDebitDate(List<EzidebitAPI.Payment> payments) {
        List<PaymentByDate> wrapped = new List<PaymentByDate>();
        for (EzidebitAPI.Payment p : payments) {
            wrapped.add(new PaymentByDate(p));
        }
        wrapped.sort();
        List<EzidebitAPI.Payment> out = new List<EzidebitAPI.Payment>();
        for (PaymentByDate w : wrapped) {
            out.add(w.p);
        }
        return out;
    }

    private class PaymentByDate implements Comparable {
        EzidebitAPI.Payment p;
        PaymentByDate(EzidebitAPI.Payment p) {
            this.p = p;
        }
        public Integer compareTo(Object other) {
            Datetime a = p.DebitDate;
            Datetime b = ((PaymentByDate) other).p.DebitDate;
            if (a == b) {
                return 0;
            }
            if (a == null) {
                return 1;
            }
            if (b == null) {
                return -1;
            }
            return a < b ? -1 : 1;
        }
    }

    @TestVisible
    private static Date toDate(Datetime dt) {
        return dt == null ? null : Date.newInstance(dt.year(), dt.month(), dt.day());
    }

    private static Decimal toDecimal(Double d) {
        return d == null ? null : Decimal.valueOf(d).setScale(2);
    }
}