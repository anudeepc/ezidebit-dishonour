/**
 * Collection activity page (credit contracts): what Ezidebit has told us about this agreement's
 * failed debits, for the collector to read before calling. A second extension beside
 * CollectionsConsoleCreditContract so the console's own controller is untouched.
 *
 * - Summary strip: last failure and the bank's reason, automatic retry status, unrecovered failures
 *   in the last 60 days, debits stopped, Direct Debit Default Notice (Form 11A) status, fees.
 * - Timeline chart: the last payments and failures by the date they happened (dshTimelineJson).
 * - Dishonours list: every failure with reason, outcome and fees (dshRows).
 *
 * Arrears stay the agreement's own figures; "unrecovered" only covers failures Ezidebit reported
 * in the last 60 days, because an older failure may have been caught up by a larger payment.
 */
public with sharing class CollectionDishonourPanel {

    @TestVisible static final Integer UNRECOVERED_WINDOW_DAYS = 60;
    @TestVisible static final Integer RETRY_BUSINESS_DAYS = 4;
    @TestVisible static final Integer TIMELINE_EVENTS = 16;
    @TestVisible static final Integer TIMELINE_MONTHS = 6;

    @TestVisible public Boolean dshHasAccess { get; private set; }
    public Boolean dshHasAgreement { get; private set; }
    @TestVisible public List<Ezidebit_Dishonour__c> dshRows { get; private set; }
    public Ezidebit_Dishonour__c dshLast { get; private set; }
    public String dshLastReason { get; private set; }
    public String dshRetryStatus { get; private set; }
    public String dshRetryTone { get; private set; }      // danger | warning | success | secondary
    public Integer dshUnrecoveredCount { get; private set; }
    public Decimal dshUnrecoveredAmount { get; private set; }
    public Boolean dshDebitsStopped { get; private set; }
    public Date dshDebitsStoppedDate { get; private set; }
    public Integer dshFailures12m { get; private set; }
    public Decimal dshEzidebitFees12m { get; private set; }
    public Decimal dshR4kFees12m { get; private set; }
    public String dshNoticeStatus { get; private set; }
    public String dshTone { get; private set; }            // overall strip colour: danger | warning | success
    public String dshTimelineJson { get; private set; }
    public Integer dshCount { get { return dshRows == null ? 0 : dshRows.size(); } }

    // Agreement tools on the same strip: hardship requests, arrangement tracking, interest stop, statements.
    public Opportunity dshOpp { get; private set; }
    public Boolean dshHardshipAccess { get; private set; }
    public List<Hardship_Request__c> dshHardshipRows { get; private set; }
    public Hardship_Request__c dshHardshipOpen { get; private set; }
    public String dshHardshipStatus { get; private set; }
    public String dshHardshipTone { get; private set; }
    public Integer dshHardshipCount { get { return dshHardshipRows == null ? 0 : dshHardshipRows.size(); } }
    public String dshNewHardshipUrl { get; private set; }
    public ArrangementTracker.Status dshArrangement { get; private set; }
    public String dshArrangementTone { get; private set; }
    public Boolean dshCanStopInterest { get; private set; }
    public String dshPayoutStatementUrl { get; private set; }
    public String dshAgreementStatementUrl { get; private set; }
    // Plain values for the page, so it never depends on field-level access to the agreement's new fields.
    public Id dshOppId { get; private set; }
    public Date dshInterestStoppedFrom { get; private set; }
    public String dshInterestStopReason { get; private set; }
    public String dshCustomerEmail { get; private set; }
    public Boolean dshReady { get { return dshHasAgreement == true && dshOppId != null; } }

    public CollectionDishonourPanel(ApexPages.StandardController controller) {
        dshRows = new List<Ezidebit_Dishonour__c>();
        dshUnrecoveredCount = 0;
        dshUnrecoveredAmount = 0;
        dshFailures12m = 0;
        dshEzidebitFees12m = 0;
        dshR4kFees12m = 0;
        dshDebitsStopped = false;
        dshTone = 'success';
        dshTimelineJson = '[]';
        dshHasAccess = Schema.sObjectType.Ezidebit_Dishonour__c.isAccessible();
        dshHasAgreement = false;
        dshHardshipAccess = Schema.sObjectType.Hardship_Request__c.isAccessible();
        dshHardshipRows = new List<Hardship_Request__c>();
        dshCanStopInterest = FeatureManagement.checkPermission('Stop_Interest');
        try {
            List<Collection_Activity__c> cas = [SELECT Agreement__c FROM Collection_Activity__c WHERE Id = :controller.getId() LIMIT 1];
            if (cas.isEmpty() || cas[0].Agreement__c == null) {
                return;
            }
            dshHasAgreement = true;
            load(cas[0].Agreement__c, Date.today());
        } catch (Exception ex) {
            ErrorLog.addErrorLog('CollectionDishonourPanel', 'constructor', String.valueOf(controller.getId()), String.valueOf(ex), String.valueOf(ex.getLineNumber()));
        }
    }

    @TestVisible
    void load(Id agreementId, Date today) {
        Opportunity opp = [
            SELECT Id, Name, Contract_No__c, AccountId, MP1__c, Scheduled_Amount__c, Payment_Frequency__c, Is_Credit_Contract__c,
                   Is_this_a_STA__c, STA_Start_Date__c, STA_Next_Due_Date__c, STA_End_Date__c, STA_Scheduled_Amount__c,
                   Interest_Stopped_From__c, Interest_Stop_Reason__c, Customer_Statement_Sent_Date__c,
                   Account.FirstName, Account.PersonEmail, Account.Territory_Number__r.Short_Name__c,
                   Account.Territory_Number__r.Collection_Number__c
            FROM Opportunity WHERE Id = :agreementId];
        dshOpp = opp;
        Date since = today.addMonths(-TIMELINE_MONTHS);
        if (opp.Is_this_a_STA__c && opp.STA_Start_Date__c != null && opp.STA_Start_Date__c < since) {
            since = opp.STA_Start_Date__c;
        }
        List<Payment__c> payments = [
            SELECT Id, Payment_Date__c, Actual_Amount__c, Debit_Type__c, RecordType.Name
            FROM Payment__c
            WHERE Agreement__c = :agreementId AND Is_TR4K__c = false AND Payment_Date__c >= :since
            ORDER BY Payment_Date__c DESC
            LIMIT 200
        ];
        loadTools(opp, payments, today);
        if (dshHasAccess) {
            dshRows = [
                SELECT Id, Name, Debit_Date__c, Type__c, Outcome__c, Status__c, Payment_Amount__c, Ezidebit_Fee__c,
                       Dishonour_Fee_Charged__c, Bank_Failed_Reason__c, Bank_Return_Code__c, Recovered_Date__c,
                       First_Default__c, Form_11A_Due_Date__c, Form_11A_Sent_Date__c, Original_Dishonour__c,
                       Original_Dishonour__r.Name, Is_Backfill__c,
                       (SELECT Id, Debit_Date__c FROM Retries__r ORDER BY Debit_Date__c DESC LIMIT 1)
                FROM Ezidebit_Dishonour__c
                WHERE Opportunity__c = :agreementId
                ORDER BY Debit_Date__c DESC, Name DESC
                LIMIT 200
            ];
        }
        summarise(opp, payments, today);
        dshTimelineJson = JSON.serialize(timeline(payments, dshRows, today));
    }

    @TestVisible
    void summarise(Opportunity opp, List<Payment__c> payments, Date today) {
        Date lastPaid = null;
        for (Payment__c p : payments) {
            if (p.Actual_Amount__c != null && p.Actual_Amount__c > 0 && (lastPaid == null || p.Payment_Date__c > lastPaid)) {
                lastPaid = p.Payment_Date__c;
            }
        }
        Ezidebit_Dishonour__c latestInstalment = null;
        for (Ezidebit_Dishonour__c d : dshRows) {
            if (d.Debit_Date__c == null) {
                continue;
            }
            if (dshLast == null) {
                dshLast = d;
            }
            if (d.Debit_Date__c > today.addMonths(-12)) {
                dshFailures12m++;
                dshEzidebitFees12m += d.Ezidebit_Fee__c == null ? 0 : d.Ezidebit_Fee__c;
                dshR4kFees12m += d.Dishonour_Fee_Charged__c == null ? 0 : d.Dishonour_Fee_Charged__c;
            }
            Boolean isMissedInstalment = d.Type__c == EzidebitDishonourService.TYPE_INSTALMENT || d.Type__c == EzidebitDishonourService.TYPE_LATE_RETURN;
            if (isMissedInstalment && latestInstalment == null) {
                latestInstalment = d;
            }
            if (isMissedInstalment && d.Outcome__c == EzidebitDishonourService.OUTCOME_OPEN
                    && d.Debit_Date__c >= today.addDays(-UNRECOVERED_WINDOW_DAYS)) {
                dshUnrecoveredCount++;
                dshUnrecoveredAmount += d.Payment_Amount__c == null ? 0 : d.Payment_Amount__c;
            }
            if (d.Type__c == EzidebitDishonourService.TYPE_FATAL && !dshDebitsStopped && (lastPaid == null || d.Debit_Date__c >= lastPaid)) {
                dshDebitsStopped = true;
                dshDebitsStoppedDate = d.Debit_Date__c;
            }
        }
        dshLastReason = dshLast == null ? null : describeReason(dshLast.Bank_Failed_Reason__c, dshLast.Bank_Return_Code__c);
        retryStatus(latestInstalment, today);
        dshNoticeStatus = noticeStatus(opp, dshRows, today);
        if (dshDebitsStopped || (dshUnrecoveredCount > 0 && dshRetryTone == 'danger') || dshHardshipTone == 'danger' || dshArrangementTone == 'danger') {
            dshTone = 'danger';
        } else if (dshUnrecoveredCount > 0) {
            dshTone = 'warning';
        } else {
            dshTone = 'success';
        }
    }

    @TestVisible
    void loadTools(Opportunity opp, List<Payment__c> payments, Date today) {
        dshOppId = opp.Id;
        dshInterestStoppedFrom = opp.Interest_Stopped_From__c;
        dshInterestStopReason = opp.Interest_Stop_Reason__c;
        dshCustomerEmail = opp.Account == null ? null : opp.Account.PersonEmail;
        dshPayoutStatementUrl = '/apex/EarlyPayoutFigureStatement?oppId=' + opp.Id;
        dshAgreementStatementUrl = '/apex/CreditContractStatement?fullStmt=yes&oppId=' + opp.Id;
        dshNewHardshipUrl = URL.getOrgDomainUrl().toExternalForm() + '/lightning/o/Hardship_Request__c/new?defaultFieldValues='
            + EncodingUtil.urlEncode('Opportunity__c=' + opp.Id + ',Account__c=' + opp.AccountId + ',Received_Date__c=' + String.valueOf(today), 'UTF-8');
        if (dshHardshipAccess) {
            dshHardshipRows = [
                SELECT Id, Name, Status__c, Received_Date__c, Decision_Due_Date__c, Decision_Date__c, Decision_Overdue__c, Is_Open__c,
                       Agreed_Change__c, Change_Start_Date__c, Change_End_Date__c, Reason__c, Opportunity__r.Contract_No__c
                FROM Hardship_Request__c
                WHERE Opportunity__c = :opp.Id OR Account__c = :opp.AccountId
                ORDER BY Received_Date__c DESC, CreatedDate DESC
                LIMIT 50
            ];
        }
        hardshipStatus(dshHardshipRows, today);
        dshArrangement = ArrangementTracker.evaluate(opp, payments, today);
        if (dshArrangement != null) {
            dshArrangementTone = dshArrangement.status == ArrangementTracker.BROKEN || dshArrangement.status == ArrangementTracker.ENDED_SHORT ? 'danger'
                : (dshArrangement.status == ArrangementTracker.PART_PAID ? 'warning' : 'success');
        }
    }

    @TestVisible
    void hardshipStatus(List<Hardship_Request__c> rows, Date today) {
        dshHardshipOpen = null;
        dshHardshipStatus = null;
        dshHardshipTone = null;
        for (Hardship_Request__c r : rows) {
            if (r.Is_Open__c) {
                dshHardshipOpen = r;
                break;
            }
        }
        if (dshHardshipOpen != null) {
            Integer left = dshHardshipOpen.Decision_Due_Date__c == null ? null : today.daysBetween(dshHardshipOpen.Decision_Due_Date__c);
            dshHardshipStatus = dshHardshipOpen.Status__c + (left == null ? '' : (left < 0
                ? ': decision overdue since ' + dshHardshipOpen.Decision_Due_Date__c.format()
                : ': decision due by ' + dshHardshipOpen.Decision_Due_Date__c.format() + ' (' + left + ' days)'));
            dshHardshipTone = left != null && left <= 3 ? 'danger' : 'warning';
            return;
        }
        for (Hardship_Request__c r : rows) {
            if (r.Status__c == 'Agreed' && r.Change_End_Date__c != null && r.Change_End_Date__c >= today) {
                dshHardshipStatus = 'Agreed ' + (r.Agreed_Change__c == null ? 'change' : r.Agreed_Change__c.toLowerCase())
                    + ' until ' + r.Change_End_Date__c.format();
                dshHardshipTone = 'success';
                return;
            }
        }
    }

    /** Emails the customer their agreement statement (PDF), saves it on the agreement and stamps the sent date. */
    public PageReference dshSendStatement() {
        if (dshOpp == null) {
            return null;
        }
        try {
            Blob pdf;
            try {
                pdf = new PageReference(dshAgreementStatementUrl).getContentAsPDF();
            } catch (VisualforceException e) {
                pdf = Blob.valueOf('Statement'); // getContent is not available in tests
            }
            String fileName = 'Agreement Statement_' + dshOpp.Name + '_' + Datetime.now().format('ddMMMyyyy') + '.pdf';
            insert new Attachment(ParentId = dshOpp.Id, Body = pdf, Name = fileName);
            update new Opportunity(Id = dshOpp.Id, Customer_Statement_Sent_Date__c = Date.today());
            if (String.isBlank(dshOpp.Account.PersonEmail)) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.WARNING,
                    'No email address on file: the statement is saved on the agreement for posting.'));
                return null;
            }
            Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
            efa.setFileName(fileName);
            efa.setBody(pdf);
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ dshOpp.Account.PersonEmail });
            mail.setBccAddresses(new List<String>{ 'noreply@r4k.com.au' });
            mail.setSubject('Your agreement statement: ' + dshOpp.Contract_No__c);
            mail.setHtmlBody(statementEmailBody(dshOpp));
            mail.setFileAttachments(new List<Messaging.EmailFileAttachment>{ efa });
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.CONFIRM, 'Statement emailed to ' + dshOpp.Account.PersonEmail + ' and saved on the agreement.'));
        } catch (Exception ex) {
            ErrorLog.addErrorLog('CollectionDishonourPanel', 'dshSendStatement', String.valueOf(dshOpp.Id), String.valueOf(ex), String.valueOf(ex.getLineNumber()));
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'The statement was not sent: ' + ex.getMessage()));
        }
        return null;
    }

    @TestVisible
    static String statementEmailBody(Opportunity opp) {
        String name = opp.Account == null || opp.Account.FirstName == null ? '' : ' ' + opp.Account.FirstName.escapeHtml4();
        String product = opp.Name == null ? '' : (opp.Name.contains(' - ') ? opp.Name.substringAfter(' - ') : opp.Name).escapeHtml4();
        String phone = opp.Account == null || opp.Account.Territory_Number__r == null || opp.Account.Territory_Number__r.Collection_Number__c == null
            ? '' : opp.Account.Territory_Number__r.Collection_Number__c;
        String team = opp.Account == null || opp.Account.Territory_Number__r == null || opp.Account.Territory_Number__r.Short_Name__c == null
            ? 'R4K' : opp.Account.Territory_Number__r.Short_Name__c;
        return '<html><body><p>Dear' + name + ',</p>'
            + '<p>Please find attached the statement for your agreement ' + opp.Contract_No__c + (product == '' ? '' : ' (' + product + ')') + '.</p>'
            + '<p>If you have any questions about it' + (phone == '' ? ', please reply to this email' : ', please call us on ' + phone) + '.</p>'
            + '<p>Kind regards,<br/>' + team + '</p></body></html>';
    }

    /** What happened to the automatic retry of the latest missed instalment. */
    @TestVisible
    void retryStatus(Ezidebit_Dishonour__c d, Date today) {
        if (d == null) {
            dshRetryStatus = 'No missed instalments recorded';
            dshRetryTone = 'success';
            return;
        }
        if (d.Outcome__c == EzidebitDishonourService.OUTCOME_RETRY || d.Outcome__c == EzidebitDishonourService.OUTCOME_LATER) {
            dshRetryStatus = d.Outcome__c + (d.Recovered_Date__c == null ? '' : ' on ' + d.Recovered_Date__c.format());
            dshRetryTone = 'success';
        } else if (d.Debit_Date__c < today.addDays(-UNRECOVERED_WINDOW_DAYS)) {
            dshRetryStatus = 'Missed ' + d.Debit_Date__c.format() + '; no matching recovery. Check arrears, it may have been caught up';
            dshRetryTone = 'secondary';
        } else if (d.Retries__r != null && !d.Retries__r.isEmpty()) {
            dshRetryStatus = 'Automatic retry failed on ' + d.Retries__r[0].Debit_Date__c.format();
            dshRetryTone = 'danger';
        } else {
            Date due = addBusinessDays(d.Debit_Date__c, RETRY_BUSINESS_DAYS);
            if (due >= today.addDays(-2)) {
                // Ezidebit reports a retry's result a day or two after it runs.
                dshRetryStatus = 'Automatic retry due around ' + due.format();
                dshRetryTone = 'warning';
            } else {
                dshRetryStatus = 'Not recovered; no retry recorded';
                dshRetryTone = 'danger';
            }
        }
    }

    @TestVisible
    static String noticeStatus(Opportunity opp, List<Ezidebit_Dishonour__c> rows, Date today) {
        for (Ezidebit_Dishonour__c d : rows) {
            if (d.First_Default__c) {
                if (d.Form_11A_Sent_Date__c != null) {
                    return 'Sent ' + d.Form_11A_Sent_Date__c.format();
                }
                if (d.Form_11A_Due_Date__c != null) {
                    Integer left = today.daysBetween(d.Form_11A_Due_Date__c);
                    return left < 0 ? 'Overdue since ' + d.Form_11A_Due_Date__c.format() : 'Due by ' + d.Form_11A_Due_Date__c.format() + ' (' + left + ' days)';
                }
            }
        }
        return opp.MP1__c != null ? 'Sent ' + opp.MP1__c.format() : 'Not sent';
    }

    /** Plain words for the bank's reason; Ezidebit's text is kept where it's already clear. */
    @TestVisible
    static String describeReason(String reason, String code) {
        if (String.isBlank(reason)) {
            return code == null ? null : 'Bank code ' + code;
        }
        if (reason.startsWithIgnoreCase('Late Return')) {
            return 'Paid, then taken back by the bank (' + reason.substringAfter('-').trim() + ')';
        }
        if (reason.equalsIgnoreCase('Refer to customer')) {
            return 'Refer to customer (usually not enough money)';
        }
        return reason;
    }

    public class TimelineEvent implements Comparable {
        public String day;        // yyyy-MM-dd
        public Decimal amount;
        public String kind;       // paid | failed | retryFailed | recovered | stopped | lateReturn | card
        public String label;
        public String detail;

        public Integer compareTo(Object other) {
            TimelineEvent o = (TimelineEvent) other;
            if (day == o.day) {
                return kind == o.kind ? 0 : (kind == 'paid' ? 1 : -1);
            }
            return day < o.day ? -1 : 1;
        }
    }

    /** Payments and failures in date order, oldest first, the last TIMELINE_EVENTS of them. */
    @TestVisible
    static List<TimelineEvent> timeline(List<Payment__c> payments, List<Ezidebit_Dishonour__c> rows, Date today) {
        List<TimelineEvent> events = new List<TimelineEvent>();
        Date since = today.addMonths(-TIMELINE_MONTHS);
        for (Payment__c p : payments) {
            if (p.Payment_Date__c == null || p.Actual_Amount__c == null || p.Actual_Amount__c <= 0 || p.Payment_Date__c < since) {
                continue;
            }
            TimelineEvent e = new TimelineEvent();
            e.day = String.valueOf(p.Payment_Date__c);
            e.amount = p.Actual_Amount__c;
            e.kind = 'paid';
            e.label = 'Paid';
            e.detail = (p.Debit_Type__c != null ? p.Debit_Type__c : (p.RecordType == null ? 'Payment' : p.RecordType.Name));
            events.add(e);
        }
        for (Ezidebit_Dishonour__c d : rows) {
            if (d.Debit_Date__c == null || d.Debit_Date__c < since) {
                continue;
            }
            TimelineEvent e = new TimelineEvent();
            e.day = String.valueOf(d.Debit_Date__c);
            e.amount = d.Payment_Amount__c == null ? 0 : d.Payment_Amount__c.abs();
            if (d.Type__c == EzidebitDishonourService.TYPE_RETRY) {
                e.kind = 'retryFailed';
                e.label = 'Retry failed';
            } else if (d.Type__c == EzidebitDishonourService.TYPE_FATAL) {
                e.kind = 'stopped';
                e.label = 'Debits stopped';
            } else if (d.Type__c == EzidebitDishonourService.TYPE_LATE_RETURN) {
                e.kind = 'lateReturn';
                e.label = 'Taken back';
            } else if (d.Type__c == EzidebitDishonourService.TYPE_CARD_DECLINED) {
                e.kind = 'card';
                e.label = 'Card declined';
            } else if (d.Outcome__c == EzidebitDishonourService.OUTCOME_RETRY || d.Outcome__c == EzidebitDishonourService.OUTCOME_LATER) {
                e.kind = 'recovered';
                e.label = 'Failed, recovered';
            } else {
                e.kind = 'failed';
                e.label = 'Failed';
            }
            List<String> parts = new List<String>{ d.Name };
            String reason = describeReason(d.Bank_Failed_Reason__c, d.Bank_Return_Code__c);
            if (reason != null) {
                parts.add(reason);
            }
            if (d.Outcome__c != null) {
                parts.add(d.Outcome__c + (d.Recovered_Date__c == null ? '' : ' ' + d.Recovered_Date__c.format()));
            }
            e.detail = String.join(parts, ' · ');
            events.add(e);
        }
        events.sort();
        List<TimelineEvent> lastOnes = new List<TimelineEvent>();
        for (Integer i = Math.max(0, events.size() - TIMELINE_EVENTS); i < events.size(); i++) {
            lastOnes.add(events[i]);
        }
        return lastOnes;
    }

    @TestVisible
    static Date addBusinessDays(Date d, Integer days) {
        Date result = d;
        Integer added = 0;
        while (added < days) {
            result = result.addDays(1);
            Integer dow = Math.mod(Date.newInstance(1900, 1, 7).daysBetween(result), 7); // 0 = Sunday
            if (dow != 0 && dow != 6) {
                added++;
            }
        }
        return result;
    }
}
