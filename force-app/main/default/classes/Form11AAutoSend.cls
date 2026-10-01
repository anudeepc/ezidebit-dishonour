/**
 * Daily automatic Direct Debit Default Notice (Form 11A, NCC s87(2): within 14 days of the first default,
 * strict liability). Each morning it sends every first default not yet sent, oldest first, through
 * Form11AService (same PDF, email, attachment and MP1__c stamp as the Form 11A page), then emails a summary.
 *
 * Off unless Ezidebit_Sync_Settings__c.Form11A_Auto_Send__c is on.
 * Schedule (8am Sydney/Melbourne): System.schedule('Form11A-AutoSend', '0 0 8 * * ?', new Form11AAutoSend());
 */
public without sharing class Form11AAutoSend implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful, Schedulable {

    public static final List<String> DEFAULT_SUMMARY_TO = new List<String>{ 'lilywilliams@r4k.com.au', 'christannous@r4k.com.au' };
    private static final String SENDER = 'pay@r4k.com.au'; // R4K Collections: replies go to the team
    /** Form11AService renders one PDF per notice; keep each transaction well inside its limits. */
    public static final Integer SCOPE = 10;

    private Integer emailed = 0;
    private Integer toPost = 0;
    private Integer alreadySent = 0;
    private Integer overdueAtStart = 0;
    private List<String> skipped = new List<String>();

    public void execute(SchedulableContext ctx) {
        if (EzidebitDishonourService.settings().Form11A_Auto_Send__c) {
            Database.executeBatch(new Form11AAutoSend(), SCOPE);
        }
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        Integer rowLimit = Test.isRunningTest() ? 5 : 50000;
        overdueAtStart = [
            SELECT COUNT() FROM Ezidebit_Dishonour__c
            WHERE First_Default__c = true AND Form_11A_Sent_Date__c = null AND Is_Backfill__c = false
              AND Opportunity__r.Is_Active__c = true AND Opportunity__r.Is_Credit_Contract__c = true
              AND Opportunity__r.MP1__c = null AND Opportunity__r.Account.State_Master_State__c != 'NZ' AND Form_11A_Due_Date__c < TODAY
        ];
        return Database.getQueryLocator([
            SELECT Id FROM Ezidebit_Dishonour__c
            WHERE First_Default__c = true AND Form_11A_Sent_Date__c = null AND Is_Backfill__c = false
              AND Opportunity__r.Is_Active__c = true AND Opportunity__r.Is_Credit_Contract__c = true
              AND Opportunity__r.Account.State_Master_State__c != 'NZ'
            ORDER BY Debit_Date__c ASC
            LIMIT :rowLimit
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Ezidebit_Dishonour__c> scope) {
        Set<Id> ids = new Map<Id, Ezidebit_Dishonour__c>(scope).keySet();
        String postCopy = EzidebitDishonourService.settings().Form11A_Post_Copy_Email__c;
        Savepoint sp = Database.setSavepoint();
        try {
            Form11AService.Outcome o = Form11AService.send(ids, String.isBlank(postCopy) ? '' : postCopy, senderId());
            emailed += o.emailed;
            toPost += o.toPost;
            alreadySent += o.alreadySent;
            skipped.addAll(o.skipped);
        } catch (Exception e) {
            Database.rollback(sp);
            skipped.add(ids.size() + ' notices not sent (' + e.getMessage() + '): they will be tried again tomorrow');
            ErrorLog.addErrorLog('Form11AAutoSend', 'execute', String.valueOf(ids), String.valueOf(e), String.valueOf(e.getLineNumber()));
        }
    }

    public void finish(Database.BatchableContext bc) {
        Integer stillOverdue = [
            SELECT COUNT() FROM Ezidebit_Dishonour__c
            WHERE First_Default__c = true AND Form_11A_Sent_Date__c = null AND Is_Backfill__c = false
              AND Opportunity__r.Is_Active__c = true AND Opportunity__r.Is_Credit_Contract__c = true
              AND Opportunity__r.MP1__c = null AND Opportunity__r.Account.State_Master_State__c != 'NZ' AND Form_11A_Due_Date__c < TODAY
        ];
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(summaryRecipients());
        Id sender = senderId();
        if (sender != null) {
            mail.setOrgWideEmailAddressId(sender);
        }
        mail.setSaveAsActivity(false);
        mail.setSubject('Direct debit default notices ' + System.now().format('d MMM yyyy', 'Australia/Sydney') + ': '
            + emailed + ' emailed' + (toPost > 0 ? ', ' + toPost + ' to post' : '') + (skipped.isEmpty() ? '' : ', ' + skipped.size() + ' to check'));
        String html = '<div style="font-family:Arial,sans-serif;font-size:14px;color:#1f2937">'
            + '<p><b>Direct Debit Default Notices (Form 11A) sent this morning</b></p><ul>'
            + '<li>Emailed to customers: <b>' + emailed + '</b></li>'
            + '<li>Sent to ' + EzidebitDishonourService.settings().Form11A_Post_Copy_Email__c + ' to print and post: <b>' + toPost + '</b></li>'
            + '<li>Already sent earlier from the Dishonours page (recorded, not sent again): ' + alreadySent + '</li>'
            + '<li>Past the 14-day deadline at the start of the run: ' + overdueAtStart + '; still unsent now: <b>' + stillOverdue + '</b></li></ul>';
        if (!skipped.isEmpty()) {
            html += '<p><b>Not sent, please check (' + skipped.size() + ')</b></p><ul>';
            for (String s : skipped) {
                html += '<li>' + s.escapeHtml4() + '</li>';
            }
            html += '</ul><p>Send these from the Form 11A page (AdminProcessForm11A) once sorted.</p>';
        }
        html += '<p style="color:#6b7280;font-size:12px">Sent automatically by Salesforce each morning. The notice must reach the customer within 14 days of their first direct debit default (NCC s87(2)).</p></div>';
        mail.setHtmlBody(html);
        try {
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
        } catch (Exception e) {
            ErrorLog.addErrorLog('Form11AAutoSend', 'finish', '', String.valueOf(e), String.valueOf(e.getLineNumber()));
        }
    }

    public static List<String> summaryRecipients() {
        String configured = EzidebitDishonourService.settings().Form11A_Summary_Recipients__c;
        List<String> out = new List<String>();
        if (String.isNotBlank(configured)) {
            for (String a : configured.split('[,;\\s]+')) {
                if (String.isNotBlank(a)) {
                    out.add(a.trim());
                }
            }
        }
        return out.isEmpty() ? DEFAULT_SUMMARY_TO : out;
    }

    private static Id senderId() {
        List<OrgWideEmailAddress> owea = [SELECT Id FROM OrgWideEmailAddress WHERE Address = :SENDER LIMIT 1];
        return owea.isEmpty() ? null : owea[0].Id;
    }
}
