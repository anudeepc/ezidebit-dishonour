/**
 * Pulls failed Ezidebit debits into Ezidebit_Dishonour__c. Two uses:
 *  - nightly catch-up, new EzidebitDishonourCatchUpBatch() or (7): the last 7 days;
 *  - daytime check, new EzidebitDishonourCatchUpBatch(0): today's reports only, so a failure is
 *    recorded soon after Ezidebit publishes it. Records only: no payments are created, so the
 *    allocation engine is never run during the day.
 *
 * Nightly catch-up detail: The main settlement batch
 * (EzidebitGetPaymentsController) only asks Ezidebit for yesterday, so a night it fails, or a
 * bank return reported late, would otherwise never be recorded. This asks each territory for
 * the FAILED payments of the last LOOKBACK_DAYS and records any Ezidebit_Dishonour__c not
 * already held (records are keyed on the Ezidebit PaymentID, so re-reading is harmless).
 *
 * One territory per execute: each GetPayments call can take most of the 120-second callout
 * budget a transaction has.
 */
public without sharing class EzidebitDishonourCatchUpBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Schedulable {

    @TestVisible static final Integer DEFAULT_LOOKBACK_DAYS = 7;
    private final Integer lookbackDays;

    public EzidebitDishonourCatchUpBatch() {
        this(DEFAULT_LOOKBACK_DAYS);
    }

    public EzidebitDishonourCatchUpBatch(Integer lookbackDays) {
        this.lookbackDays = lookbackDays == null ? DEFAULT_LOOKBACK_DAYS : Math.max(0, lookbackDays);
    }
    private static final String ENDPOINT = 'https://api.ezidebit.com.au/v3-5/nonpci';

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new EzidebitDishonourCatchUpBatch(lookbackDays), 1);
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Name, Short_Name__c, Ezidebit_DigitalKey__c
            FROM Territory__c
            WHERE Ezidebit_DigitalKey__c != null AND Status__c = 'Active'
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Territory__c> scope) {
        for (Territory__c ter : scope) {
            try {
                EzidebitAPI.BasicHttpBinding_INonPCIService stub = new EzidebitAPI.BasicHttpBinding_INonPCIService();
                stub.inputHttpHeaders_x = new Map<String, String>();
                stub.endpoint_x = ENDPOINT;
                stub.timeout_x = 110000;
                String dateFrom = Datetime.now().addDays(-lookbackDays).format('yyyy-MM-dd');
                String dateTo = Datetime.now().addDays(lookbackDays == 0 ? 0 : -1).format('yyyy-MM-dd');
                EzidebitAPI.EziResponseOfArrayOfPaymentTHgMB7oL response = stub.GetPayments(
                    ter.Ezidebit_DigitalKey__c, 'FAILED', 'ALL', 'ALL', '', dateFrom, dateTo, 'SETTLEMENT', '', '');
                if (response == null || response.Data == null || response.Data.Payment == null) {
                    continue;
                }
                Map<String, String> territoryByPaymentId = new Map<String, String>();
                for (EzidebitAPI.Payment p : response.Data.Payment) {
                    if (p.PaymentID != null) {
                        territoryByPaymentId.put(p.PaymentID, ter.Short_Name__c);
                    }
                }
                EzidebitDishonourService.capture(response.Data.Payment, territoryByPaymentId);
            } catch (Exception ex) {
                ErrorLog.addErrorLog('EzidebitDishonourCatchUpBatch', 'execute', ter.Name, String.valueOf(ex), String.valueOf(ex.getLineNumber()));
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
    }
}