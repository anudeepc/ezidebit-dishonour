/**
 * Loads Ezidebit failure history into Ezidebit_Dishonour__c for ACTIVE agreements, oldest first:
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

    /** Work items "territoryId|windowStart|windowEnd", oldest window first. */
    public Iterable<String> start(Database.BatchableContext bc) {
        List<Territory__c> ters = [SELECT Id FROM Territory__c WHERE Ezidebit_DigitalKey__c != null AND Status__c = 'Active' ORDER BY Name];
        List<String> items = new List<String>();
        for (Date w = fromDate; w <= toDate; w = w.addDays(WINDOW_DAYS)) {
            Date wEnd = w.addDays(WINDOW_DAYS - 1) < toDate ? w.addDays(WINDOW_DAYS - 1) : toDate;
            for (Territory__c t : ters) {
                items.add(t.Id + '|' + String.valueOf(w) + '|' + String.valueOf(wEnd));
            }
        }
        return items;
    }

    public void execute(Database.BatchableContext bc, List<String> scope) {
        for (String item : scope) {
            List<String> parts = item.split('\\|');
            try {
                Territory__c ter = [SELECT Id, Name, Short_Name__c, Ezidebit_DigitalKey__c FROM Territory__c WHERE Id = :parts[0]];
                EzidebitAPI.BasicHttpBinding_INonPCIService stub = new EzidebitAPI.BasicHttpBinding_INonPCIService();
                stub.inputHttpHeaders_x = new Map<String, String>();
                stub.endpoint_x = ENDPOINT;
                stub.timeout_x = 110000;
                EzidebitAPI.EziResponseOfArrayOfPaymentTHgMB7oL response = stub.GetPayments(
                    ter.Ezidebit_DigitalKey__c, 'FAILED', 'ALL', 'ALL', '', parts[1], parts[2], 'SETTLEMENT', '', '');
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
                String month = parts[1].left(7);
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
            + 'Failures skipped (agreement not active or not found): ' + skippedInactive + '\n\nBy month (count, Ezidebit fees):\n';
        for (String m : months) {
            body += m + '  ' + countByMonth.get(m) + (dryRun ? '  $' + feesByMonth.get(m).setScale(2) : '') + '\n';
        }
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