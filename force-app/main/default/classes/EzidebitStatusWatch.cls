/**
 * Watches Ezidebit customer status so staff don't have to do anything new: WeCare keeps putting a
 * customer on hold in the Ezidebit portal when the goods are ordered and making them active again on
 * delivery, and Salesforce records when that happened.
 *
 *   FOCUSED (every 2 hours in the day): credit contracts in Pending Order, or Goods Delivered with no
 *            payment yet - the ones whose interest start can still change.
 *   ALL     (nightly): every active credit contract, for the full hold history.
 *
 * Each status seen is compared with the last one recorded (Ezidebit_Status_Change__c). When an
 * agreement with no payment yet goes from on hold to active, that day becomes its Interest Start
 * Date (PaymentUtil charges the first period from it). Nothing is written to Ezidebit.
 *
 *   System.schedule('Ezidebit-StatusWatch-Day', '0 5 8-20/2 * * ?', new EzidebitStatusWatch(EzidebitStatusWatch.Mode.FOCUSED));
 *   System.schedule('Ezidebit-StatusWatch-Night', '0 15 21 * * ?', new EzidebitStatusWatch(EzidebitStatusWatch.Mode.ALL));
 */
public without sharing class EzidebitStatusWatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Schedulable {

    public enum Mode { FOCUSED, ALL }

    public static final String STATUS_ACTIVE = 'Active';
    public static final String STATUS_HOLD = 'On hold';
    /** Agreements per execute: one Ezidebit call each, well inside the callout limits. */
    public static final Integer SCOPE = 40;
    private static final String ENDPOINT = 'https://api.ezidebit.com.au/v3-5/nonpci';

    private final Mode mode;

    public EzidebitStatusWatch(Mode mode) {
        this.mode = mode == null ? EzidebitStatusWatch.Mode.FOCUSED : mode;
    }

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new EzidebitStatusWatch(mode), SCOPE);
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        Integer rowLimit = Test.isRunningTest() ? 200 : 50000000;
        if (mode == EzidebitStatusWatch.Mode.ALL) {
            return Database.getQueryLocator([
                SELECT Id, Contract_No__c, Interest_Start_Date__c, Last_Payment_Received_Date__c, Account.Territory_Number__r.Ezidebit_DigitalKey__c
                FROM Opportunity
                WHERE Is_Credit_Contract__c = true AND Is_Active__c = true AND Contract_No__c != null
                  AND Account.Territory_Number__r.Ezidebit_DigitalKey__c != null
                LIMIT :rowLimit
            ]);
        }
        return Database.getQueryLocator([
            SELECT Id, Contract_No__c, Interest_Start_Date__c, Last_Payment_Received_Date__c, Account.Territory_Number__r.Ezidebit_DigitalKey__c
            FROM Opportunity
            WHERE Is_Credit_Contract__c = true AND Contract_No__c != null
              AND Account.Territory_Number__r.Ezidebit_DigitalKey__c != null
              AND (StageName = 'Pending Order' OR (StageName = 'Goods Delivered' AND Last_Payment_Received_Date__c = null))
            LIMIT :rowLimit
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Opportunity> scope) {
        // Ask Ezidebit first (callouts before any DML).
        Map<Id, EzidebitAPI.CustomerDetails> seen = new Map<Id, EzidebitAPI.CustomerDetails>();
        EzidebitAPI.BasicHttpBinding_INonPCIService stub = new EzidebitAPI.BasicHttpBinding_INonPCIService();
        stub.inputHttpHeaders_x = new Map<String, String>();
        stub.endpoint_x = ENDPOINT;
        stub.timeout_x = 20000;
        for (Opportunity o : scope) {
            try {
                EzidebitAPI.EziResponseOfCustomerDetailsTHgMB7oL r =
                    stub.GetCustomerDetails(o.Account.Territory_Number__r.Ezidebit_DigitalKey__c, '', o.Contract_No__c);
                if (r != null && (r.Error == null || r.Error == 0) && r.Data != null) {
                    seen.put(o.Id, r.Data);
                }
                // Not set up in Ezidebit (e.g. Centrepay) or an Ezidebit error: nothing to record this time.
            } catch (Exception ex) {
                // Ezidebit unreachable: try again next run.
            }
        }
        record(scope, seen, Date.today());
    }

    public void finish(Database.BatchableContext bc) {
    }

    /** Compares what Ezidebit shows with the last status recorded; logs changes and sets the interest start. */
    @TestVisible
    static void record(List<Opportunity> scope, Map<Id, EzidebitAPI.CustomerDetails> seen, Date today) {
        if (seen.isEmpty()) {
            return;
        }
        Map<Id, Ezidebit_Status_Change__c> last = new Map<Id, Ezidebit_Status_Change__c>();
        for (Ezidebit_Status_Change__c c : [
            SELECT Opportunity__c, New_Status__c FROM Ezidebit_Status_Change__c
            WHERE Opportunity__c IN :seen.keySet() ORDER BY Opportunity__c, CreatedDate DESC, Name DESC
        ]) {
            if (!last.containsKey(c.Opportunity__c)) {
                last.put(c.Opportunity__c, c);
            }
        }
        Set<Id> paid = new Set<Id>();
        for (AggregateResult ar : [SELECT Agreement__c a FROM Payment__c WHERE Agreement__c IN :seen.keySet() AND Actual_Amount__c > 0 GROUP BY Agreement__c]) {
            paid.add((Id) ar.get('a'));
        }
        List<Ezidebit_Status_Change__c> logs = new List<Ezidebit_Status_Change__c>();
        List<Opportunity> starts = new List<Opportunity>();
        for (Opportunity o : scope) {
            EzidebitAPI.CustomerDetails d = seen.get(o.Id);
            if (d == null) {
                continue;
            }
            String status = describe(d.StatusCode, d.StatusDescription);
            Ezidebit_Status_Change__c prior = last.get(o.Id);
            if (prior != null && prior.New_Status__c == status) {
                continue; // no change
            }
            Ezidebit_Status_Change__c c = new Ezidebit_Status_Change__c(
                Opportunity__c = o.Id, Kind__c = prior == null ? 'First seen' : 'Changed',
                Previous_Status__c = prior == null ? null : prior.New_Status__c, New_Status__c = status,
                Status_Code__c = d.StatusCode, Observed_Date__c = today);
            Boolean activated = prior != null && prior.New_Status__c != null && prior.New_Status__c.startsWith(STATUS_HOLD)
                && status == STATUS_ACTIVE;
            if (activated && !paid.contains(o.Id) && o.Last_Payment_Received_Date__c == null) {
                c.Set_Interest_Start__c = true;
                starts.add(new Opportunity(Id = o.Id, Interest_Start_Date__c = today));
            }
            logs.add(c);
        }
        insert logs;
        for (Database.SaveResult sr : Database.update(starts, false)) {
            if (!sr.isSuccess()) {
                ErrorLog.addErrorLog('EzidebitStatusWatch', 'record', String.valueOf(sr.getId()), String.valueOf(sr.getErrors()), '');
            }
        }
    }

    /** Ezidebit's status code in words: A = Active, H* = On hold (with Ezidebit's reason), C* = Cancelled. */
    public static String describe(String code, String description) {
        if (String.isBlank(code)) {
            return String.isBlank(description) ? 'Unknown' : description;
        }
        if (code == 'A') {
            return STATUS_ACTIVE;
        }
        if (code.startsWith('H')) {
            return code == 'H' || String.isBlank(description) ? STATUS_HOLD : (STATUS_HOLD + ' (' + description + ')').left(60);
        }
        if (code.startsWith('C')) {
            return String.isBlank(description) ? 'Cancelled' : ('Cancelled (' + description + ')').left(60);
        }
        return (String.isBlank(description) ? code : description).left(60);
    }

    /**
     * One-off at go-live: agreements delivered before the watch existed and still unpaid get their
     * interest start from the day the stage last moved from Pending Order back to Goods Delivered.
     * Returns the number of agreements set.
     */
    public static Integer backfillFromStageHistory() {
        Map<Id, Date> deliveredOn = new Map<Id, Date>();
        for (OpportunityFieldHistory h : [
            SELECT OpportunityId, CreatedDate FROM OpportunityFieldHistory
            WHERE Field = 'StageName' AND Opportunity.Is_Credit_Contract__c = true AND Opportunity.StageName = 'Goods Delivered'
              AND Opportunity.Last_Payment_Received_Date__c = null AND Opportunity.Interest_Start_Date__c = null
            ORDER BY OpportunityId, CreatedDate ASC
        ]) {
            deliveredOn.put(h.OpportunityId, null); // placeholder: filled from the value check below
        }
        if (deliveredOn.isEmpty()) {
            return 0;
        }
        for (OpportunityFieldHistory h : [
            SELECT OpportunityId, OldValue, NewValue, CreatedDate FROM OpportunityFieldHistory
            WHERE Field = 'StageName' AND OpportunityId IN :deliveredOn.keySet() ORDER BY CreatedDate ASC
        ]) {
            if (String.valueOf(h.OldValue) == 'Pending Order' && String.valueOf(h.NewValue) == 'Goods Delivered') {
                deliveredOn.put(h.OpportunityId, h.CreatedDate.date()); // the last move wins
            }
        }
        Set<Id> paid = new Set<Id>();
        for (AggregateResult ar : [SELECT Agreement__c a FROM Payment__c WHERE Agreement__c IN :deliveredOn.keySet() AND Actual_Amount__c > 0 GROUP BY Agreement__c]) {
            paid.add((Id) ar.get('a'));
        }
        List<Opportunity> updates = new List<Opportunity>();
        for (Id oppId : deliveredOn.keySet()) {
            Date d = deliveredOn.get(oppId);
            if (d != null && !paid.contains(oppId)) {
                updates.add(new Opportunity(Id = oppId, Interest_Start_Date__c = d));
            }
        }
        Integer ok = 0;
        for (Database.SaveResult sr : Database.update(updates, false)) {
            if (sr.isSuccess()) {
                ok++;
            } else {
                ErrorLog.addErrorLog('EzidebitStatusWatch', 'backfillFromStageHistory', String.valueOf(sr.getId()), String.valueOf(sr.getErrors()), '');
            }
        }
        return ok;
    }
}
