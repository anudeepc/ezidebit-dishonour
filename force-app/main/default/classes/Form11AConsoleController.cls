/**
 * CAP console "Form 11A" page: every first default recorded from Ezidebit that still needs its
 * Direct Debit Default Notice, oldest debit first, with the s87(2) deadline (debit date + 14).
 * Amber from day 7 after the debit, red from day 10. Staff tick rows, review, then send.
 */
public with sharing class Form11AConsoleController {

    public static final Integer AMBER_FROM_DAY = 7;
    public static final Integer RED_FROM_DAY = 10;

    public class Row {
        public Ezidebit_Dishonour__c d { get; set; }
        public Boolean selected { get; set; }
        public Integer daysSinceDebit { get; set; }
        public Integer daysLeft { get; set; }
        public String urgency { get; set; }      // '' | 'amber' | 'red'
        public String blockReason { get; set; }
        public String channel { get; set; }      // what Send will do
        public Boolean canSend { get { return blockReason == null; } }
    }

    public Boolean ccCAP { get; set; }
    public List<Row> rows { get; set; }
    public List<Row> reviewRows { get; set; }
    public Boolean reviewing { get; set; }
    public Integer overdueCount { get; set; }
    public Integer redCount { get; set; }
    public Integer amberCount { get; set; }
    public Integer reconciledCount { get; set; }
    public Integer maxPerSend { get { return Form11AService.MAX_PER_SEND; } }

    public Form11AConsoleController() {
        String cc = ApexPages.currentPage() == null ? null : ApexPages.currentPage().getParameters().get('ccCAP');
        ccCAP = cc == null || cc == 'true'; // Form 11A is credit contracts only
        rows = new List<Row>();
        reviewRows = new List<Row>();
        reviewing = false;
        overdueCount = 0;
        redCount = 0;
        amberCount = 0;
        reconciledCount = 0;
    }

    /** Page action: records notices already sent from the Dishonours page (MP1 stamped), then loads. */
    public PageReference load() {
        reconciledCount = reconcileAlreadySent();
        loadRows();
        return null;
    }

    private Integer reconcileAlreadySent() {
        List<Ezidebit_Dishonour__c> sent = new List<Ezidebit_Dishonour__c>();
        for (Ezidebit_Dishonour__c d : [
            SELECT Id, Opportunity__r.MP1__c FROM Ezidebit_Dishonour__c
            WHERE First_Default__c = true AND Form_11A_Sent_Date__c = null AND Is_Backfill__c = false
              AND Opportunity__r.MP1__c != null AND Opportunity__r.Account.Territory_Number__c IN :territoryIds()
            LIMIT 200
        ]) {
            sent.add(new Ezidebit_Dishonour__c(Id = d.Id, Form_11A_Sent_Date__c = d.Opportunity__r.MP1__c,
                Form_11A_Channel__c = Form11AService.CHANNEL_ALREADY));
        }
        update sent;
        return sent.size();
    }

    private void loadRows() {
        rows = new List<Row>();
        overdueCount = 0;
        redCount = 0;
        amberCount = 0;
        Date today = Date.today();
        for (Ezidebit_Dishonour__c d : [
            SELECT Id, Name, Opportunity__c, Debit_Date__c, Form_11A_Due_Date__c, Form_11A_Sent_Date__c, First_Default__c,
                   Is_Backfill__c, Type__c, Payment_Amount__c, Bank_Failed_Reason__c, Outcome__c, Territory_Name__c,
                   Opportunity__r.Name, Opportunity__r.Contract_No__c, Opportunity__r.MP1__c, Opportunity__r.Is_Credit_Contract__c,
                   Opportunity__r.Is_Active__c, Opportunity__r.Account.State_Master_State__c, Opportunity__r.Account.Name, Opportunity__r.Account.FirstName, Opportunity__r.Account.PersonEmail,
                   Opportunity__r.Account.Enquiry_Status__c, Opportunity__r.Account.Is_IDR__c
            FROM Ezidebit_Dishonour__c
            WHERE First_Default__c = true AND Form_11A_Sent_Date__c = null AND Is_Backfill__c = false
              AND Opportunity__r.MP1__c = null AND Opportunity__r.Account.Territory_Number__c IN :territoryIds()
              AND Opportunity__r.Is_Active__c = true AND Opportunity__r.Account.State_Master_State__c != 'NZ'
            ORDER BY Debit_Date__c ASC, Name ASC
            LIMIT 1000
        ]) {
            Row r = new Row();
            r.d = d;
            r.selected = false;
            r.daysSinceDebit = d.Debit_Date__c == null ? null : d.Debit_Date__c.daysBetween(today);
            r.daysLeft = d.Form_11A_Due_Date__c == null ? null : today.daysBetween(d.Form_11A_Due_Date__c);
            r.urgency = r.daysSinceDebit == null ? '' : (r.daysSinceDebit >= RED_FROM_DAY ? 'red' : (r.daysSinceDebit >= AMBER_FROM_DAY ? 'amber' : ''));
            r.blockReason = Form11AService.blockReason(d);
            r.channel = String.isNotBlank(d.Opportunity__r.Account.PersonEmail) ? 'Email' : 'No email: copy to you to post';
            if (r.daysLeft != null && r.daysLeft < 0) {
                overdueCount++;
            }
            if (r.urgency == 'red') {
                redCount++;
            } else if (r.urgency == 'amber') {
                amberCount++;
            }
            rows.add(r);
        }
    }

    /** Credit-contract territories the user can read, as the rest of the CAP console scopes them. */
    private List<Id> territoryIds() {
        Map<Id, Territory__c> ters = new Map<Id, Territory__c>([
            SELECT Id FROM Territory__c WHERE Status__c = 'Active' AND Is_Credit_Contract__c = true LIMIT 200
        ]);
        List<Id> ids = new List<Id>();
        if (ters.isEmpty()) {
            return ids;
        }
        for (UserRecordAccess a : [
            SELECT RecordId FROM UserRecordAccess
            WHERE UserId = :UserInfo.getUserId() AND HasReadAccess = true AND RecordId IN :ters.keySet() LIMIT 200
        ]) {
            ids.add(a.RecordId);
        }
        return ids;
    }

    public PageReference review() {
        reviewRows = new List<Row>();
        for (Row r : rows) {
            if (r.selected && r.canSend) {
                reviewRows.add(r);
            }
        }
        if (reviewRows.isEmpty()) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.WARNING, 'Tick at least one notice that can be sent.'));
            return null;
        }
        if (reviewRows.size() > Form11AService.MAX_PER_SEND) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO,
                'Up to ' + Form11AService.MAX_PER_SEND + ' notices go in one send. The ' + Form11AService.MAX_PER_SEND
                + ' oldest are below; send the rest next.'));
            List<Row> firstBatch = new List<Row>();
            for (Integer i = 0; i < Form11AService.MAX_PER_SEND; i++) {
                firstBatch.add(reviewRows[i]);
            }
            reviewRows = firstBatch;
        }
        reviewing = true;
        return null;
    }

    public PageReference cancelReview() {
        reviewing = false;
        reviewRows = new List<Row>();
        return null;
    }

    public PageReference send() {
        Set<Id> ids = new Set<Id>();
        for (Row r : reviewRows) {
            ids.add(r.d.Id);
        }
        Savepoint sp = Database.setSavepoint();
        try {
            Form11AService.Outcome res = Form11AService.send(ids);
            String msg = res.emailed + ' emailed to the customer';
            if (res.toPost > 0) {
                msg += ', ' + res.toPost + ' sent to you to print and post (no customer email)';
            }
            if (res.alreadySent > 0) {
                msg += ', ' + res.alreadySent + ' had already been sent';
            }
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.CONFIRM, msg + '.'));
            for (String s : res.skipped) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.WARNING, 'Not sent: ' + s));
            }
        } catch (Exception ex) {
            Database.rollback(sp);
            ErrorLog.addErrorLog('Form11AConsoleController', 'send', '', String.valueOf(ex), String.valueOf(ex.getLineNumber()));
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Nothing was sent: ' + ex.getMessage()));
        }
        reviewing = false;
        reviewRows = new List<Row>();
        loadRows();
        return null;
    }
}