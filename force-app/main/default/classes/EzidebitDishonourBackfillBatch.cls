/**
 * Loads Ezidebit failure history into Ezidebit_Dishonour__c for ACTIVE CREDIT CONTRACTS only (leases are left out), oldest first:
 * one territory and one WINDOW_DAYS window per execute, so each GetPayments response stays well
 * under the 6 MB limit and retries find the originals loaded before them.
 *
 * Records are marked Is_Backfill__c: the Form 11A panel, fee automation and alerts ignore them.
 * Dry run (the default) writes nothing and emails the monthly counts and fees to the person who ran it.
 *
 *   Database.executeBatch(new EzidebitDishonourBackfillBatch(Date.newInstance(2026,8,1), Date.newInstance(2026,8,31), true), 1);
 *
 * After a real run: EzidebitDishonourRecoveryBatch (recoveries from existing payments) and
 * EzidebitFeeLinkBackfillBatch (link the $16.50 fees already charged).
 */
public without sharing class EzidebitDishonourBackfillBatch implements Database.Batchable<String>, Database.AllowsCallouts, Database.Stateful {

    @TestVisible static final Integer WINDOW_DAYS = 14;
    private static final String ENDPOINT = 'https://api.ezidebit.com.au/v3-5/nonpci';

    private final Date fromDate;
    private final Date toDate;
    private final Boolean dryRun;
    @TestVisible Map<String, Integer> countByMonth = new Map<String, Integer>();
    @TestVisible Map<String, Decimal> feesByMonth = new Map<String, Decimal>();
    @TestVisible Integer inserted = 0;
    @TestVisible Integer skippedInactive = 0;
    @TestVisible List<String> errors = new List<String>();

    public EzidebitDishonourBackfillBatch(Date fromDate, Date toDate, Boolean dryRun) {
        this.fromDate = fromDate;
        this.toDate = toDate;
        this.dryRun = dryRun != false;
    }

    /** Aim for about this many failures per Ezidebit call: a 14-day call for the busiest account ran out of heap. */
    @TestVisible static final Integer ROWS_PER_CALL = 1000;

    /**
     * Work items "windowStart|territoryId|windowEnd", oldest window first. Each territory's window is
     * sized from its failures in the last 28 days, so a busy account is asked a few days at a time.
     */
    public Iterable<String> start(Database.BatchableContext bc) {
        List<Territory__c> ters = [SELECT Id, Short_Name__c FROM Territory__c WHERE Ezidebit_DigitalKey__c != null AND Status__c = 'Active' ORDER BY Name];
        Map<String, Integer> recent = new Map<String, Integer>();
        for (AggregateResult ar : [SELECT Territory_Name__c t, COUNT(Id) c FROM Ezidebit_Dishonour__c
                                   WHERE Debit_Date__c = LAST_N_DAYS:28 GROUP BY Territory_Name__c]) {
            recent.put((String) ar.get('t'), (Integer) ar.get('c'));
        }
        List<String> items = new List<String>();
        for (Territory__c t : ters) {
            Integer days = windowDays(recent.get(t.Short_Name__c));
            for (Date w = fromDate; w <= toDate; w = w.addDays(days)) {
                Date wEnd = w.addDays(days - 1) < toDate ? w.addDays(days - 1) : toDate;
                items.add(String.valueOf(w) + '|' + t.Id + '|' + String.valueOf(wEnd));
            }
        }
        items.sort(); // oldest window first, so each original is recorded before its retry
        return items;
    }

    @TestVisible
    static Integer windowDays(Integer failuresLast28Days) {
        if (failuresLast28Days == null || failuresLast28Days <= 0) {
            return WINDOW_DAYS;
        }
        Decimal perDay = failuresLast28Days / 28.0;
        Integer days = (Integer) Math.floor(ROWS_PER_CALL / perDay);
        return Math.max(2, Math.min(WINDOW_DAYS, days));
    }

    public void execute(Database.BatchableContext bc, List<String> scope) {
        for (String item : scope) {
            List<String> parts = item.split('\\|');
            try {
                Territory__c ter = [SELECT Id, Name, Short_Name__c, Ezidebit_DigitalKey__c FROM Territory__c WHERE Id = :parts[1]];
                EzidebitAPI.BasicHttpBinding_INonPCIService stub = new EzidebitAPI.BasicHttpBinding_INonPCIService();
                stub.inputHttpHeaders_x = new Map<String, String>();
                stub.endpoint_x = ENDPOINT;
                stub.timeout_x = 110000;
                EzidebitAPI.EziResponseOfArrayOfPaymentTHgMB7oL response = stub.GetPayments(
                    ter.Ezidebit_DigitalKey__c, 'FAILED', 'ALL', 'ALL', '', parts[0], parts[2], 'SETTLEMENT', '', '');
                if (response != null && response.Error != null && response.Error != 0) {
                    errors.add(ter.Short_Name__c + ' ' + parts[0] + '..' + parts[2] + ': Ezidebit error ' + response.Error + ' ' + response.ErrorMessage);
                    continue;
                }
                if (response == null || response.Data == null || response.Data.Payment == null) {
                    continue;
                }
                Map<String, String> territoryByPaymentId = new Map<String, String>();
                for (EzidebitAPI.Payment p : response.Data.Payment) {
                    if (p.PaymentID != null) {
                        territoryByPaymentId.put(p.PaymentID, ter.Short_Name__c);
                    }
                }
                EzidebitDishonourService.CaptureOptions opts = new EzidebitDishonourService.CaptureOptions();
                opts.backfill = true;
                opts.activeOnly = true;
                opts.dryRun = dryRun;
                EzidebitDishonourService.Result r = EzidebitDishonourService.capture(response.Data.Payment, territoryByPaymentId, opts);
                String month = parts[0].left(7);
                Integer n = dryRun ? r.wouldInsert : r.inserted;
                countByMonth.put(month, (countByMonth.containsKey(month) ? countByMonth.get(month) : 0) + n);
                feesByMonth.put(month, (feesByMonth.containsKey(month) ? feesByMonth.get(month) : 0) + r.ezidebitFees);
                inserted += n;
                skippedInactive += r.skippedInactive;
            } catch (Exception ex) {
                errors.add(item + ': ' + ex.getMessage());
                ErrorLog.addErrorLog('EzidebitDishonourBackfillBatch', 'execute', item, String.valueOf(ex), String.valueOf(ex.getLineNumber()));
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        List<String> months = new List<String>(countByMonth.keySet());
        months.sort();
        String body = (dryRun ? 'DRY RUN - nothing was written.\n' : 'Records written.\n')
            + 'Window: ' + String.valueOf(fromDate) + ' to ' + String.valueOf(toDate) + '\n'
            + (dryRun ? 'Dishonours that would be recorded: ' : 'Dishonours recorded: ') + inserted + '\n'
            + 'Failures skipped (not an active credit contract, e.g. a lease): ' + skippedInactive + '\n\nBy month (count, Ezidebit fees):\n';
        for (String m : months) {
            body += m + '  ' + countByMonth.get(m) + (dryRun ? '  $' + feesByMonth.get(m).setScale(2) : '') + '\n';
        }
        Integer failedWindows = 0;
        if (bc != null && bc.getJobId() != null) {
            List<AsyncApexJob> job = [SELECT NumberOfErrors FROM AsyncApexJob WHERE Id = :bc.getJobId()];
            failedWindows = job.isEmpty() || job[0].NumberOfErrors == null ? 0 : job[0].NumberOfErrors;
        }
        body += '\nWindows that failed on a Salesforce limit (not counted above): ' + failedWindows + '\n';
        if (!errors.isEmpty()) {
            body += '\nErrors (' + errors.size() + '):\n' + String.join(errors, '\n').left(8000);
        }
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setTargetObjectId(UserInfo.getUserId());
        mail.setSaveAsActivity(false);
        mail.setSubject('Ezidebit dishonour backfill ' + (dryRun ? '(dry run) ' : '') + String.valueOf(fromDate) + ' to ' + String.valueOf(toDate));
        mail.setPlainTextBody(body);
        if (!Test.isRunningTest()) {
            Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ mail });
        }
    }
}