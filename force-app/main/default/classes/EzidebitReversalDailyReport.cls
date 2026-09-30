/**
 * Daily email to Finance and Operations listing the payments reversed in the last 24 hours
 * (late returns and duplicate copies, EzidebitLateReturnReversal), and any late return Ezidebit
 * reported that could not be matched to a Salesforce payment.
 *
 * Schedule (9am Sydney/Melbourne): System.schedule('Ezidebit-ReversalDailyReport', '0 0 9 * * ?', new EzidebitReversalDailyReport());
 */
public without sharing class EzidebitReversalDailyReport implements Schedulable {

    public static final List<String> DEFAULT_RECIPIENTS = new List<String>{
        'naveenkama@r4k.com.au', 'ravigujjula@r4k.com.au', 'christannous@r4k.com.au'
    };
    private static final String SENDER = 'noreply@r4k.com.au';

    public void execute(SchedulableContext ctx) {
        send(System.now().addHours(-24));
    }

    public static void send(Datetime since) {
        Messaging.SingleEmailMessage mail = buildEmail(since);
        mail.setToAddresses(recipients());
        List<OrgWideEmailAddress> owea = [SELECT Id FROM OrgWideEmailAddress WHERE Address = :SENDER LIMIT 1];
        if (!owea.isEmpty()) {
            mail.setOrgWideEmailAddressId(owea[0].Id);
        }
        mail.setSaveAsActivity(false);
        try {
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
        } catch (Exception e) {
            ErrorLog.addErrorLog('EzidebitReversalDailyReport', 'send', String.valueOf(since), String.valueOf(e), String.valueOf(e.getLineNumber()));
        }
    }

    public static List<String> recipients() {
        String configured = EzidebitDishonourService.settings().Reversal_Report_Recipients__c;
        if (String.isBlank(configured)) {
            return DEFAULT_RECIPIENTS;
        }
        List<String> out = new List<String>();
        for (String a : configured.split('[,;\\s]+')) {
            if (String.isNotBlank(a)) {
                out.add(a.trim());
            }
        }
        return out.isEmpty() ? DEFAULT_RECIPIENTS : out;
    }

    public static Messaging.SingleEmailMessage buildEmail(Datetime since) {
        String base = URL.getOrgDomainUrl().toExternalForm() + '/';
        List<Payment__c> reversed = [
            SELECT Id, Name, Payment_Date__c, Agreement__c, Agreement__r.Contract_No__c, Agreement__r.Actual_Arrears__c,
                   ApplicantLookup__r.Name, Reversed_By__c, Reversed_By__r.Name, Reversed_By__r.Payment_Date__c,
                   Reversed_By__r.Actual_Amount__c, Reversed_By__r.Notes__c
            FROM Payment__c
            WHERE Reversed_By__c != null AND Reversed_By__r.CreatedDate >= :since
            ORDER BY Agreement__r.Contract_No__c, Payment_Date__c
        ];
        List<Ezidebit_Dishonour__c> unmatched = [
            SELECT Id, Contract_Reference__c, Debit_Date__c, Payment_Amount__c, Bank_Failed_Reason__c, Opportunity__c
            FROM Ezidebit_Dishonour__c
            WHERE Type__c = :EzidebitDishonourService.TYPE_LATE_RETURN AND Reversed_Payment__c = null AND CreatedDate >= :since
            ORDER BY Contract_Reference__c
        ];

        Decimal total = 0;
        Integer lateReturns = 0;
        Integer duplicates = 0;
        List<String> rows = new List<String>();
        for (Payment__c p : reversed) {
            Decimal amount = p.Reversed_By__r.Actual_Amount__c == null ? 0 : -p.Reversed_By__r.Actual_Amount__c;
            total += amount;
            String notes = p.Reversed_By__r.Notes__c == null ? '' : p.Reversed_By__r.Notes__c;
            String reason = notes.startsWith(EzidebitLateReturnReversal.REASON_DUPLICATE) ? EzidebitLateReturnReversal.REASON_DUPLICATE : EzidebitLateReturnReversal.REASON_LATE_RETURN;
            if (reason == EzidebitLateReturnReversal.REASON_DUPLICATE) {
                duplicates++;
            } else {
                lateReturns++;
            }
            rows.add('<tr>'
                + td(p.Agreement__c == null ? esc(p.Agreement__r.Contract_No__c) : link(base + p.Agreement__c, p.Agreement__r.Contract_No__c))
                + td(esc(p.ApplicantLookup__r == null ? '' : p.ApplicantLookup__r.Name))
                + td(link(base + p.Id, p.Name) + ' (' + fmt(p.Payment_Date__c) + ')')
                + tdRight(money(amount))
                + td(esc(reason))
                + td(fmt(p.Reversed_By__r.Payment_Date__c))
                + tdRight(money(p.Agreement__r == null ? null : p.Agreement__r.Actual_Arrears__c))
                + '</tr>');
        }

        String day = System.now().format('EEEE d MMMM yyyy', 'Australia/Sydney');
        String html = '<div style="font-family:Arial,sans-serif;font-size:14px;color:#1f2937">'
            + '<p><b>Ezidebit reversals for ' + day + '</b> (the 24 hours to ' + System.now().format('h:mm a', 'Australia/Sydney') + ')</p>';
        if (reversed.isEmpty()) {
            html += '<p>No payments were reversed.</p>';
        } else {
            html += '<p>' + reversed.size() + ' payment' + (reversed.size() == 1 ? '' : 's') + ' reversed, ' + money(total) + ' in total: '
                + lateReturns + ' taken back by the bank (late return), ' + duplicates + ' duplicate cop' + (duplicates == 1 ? 'y' : 'ies') + '. '
                + 'Each no longer counts as paid, so the balance, arrears and payout figure have gone back up by the amount.</p>'
                + '<table cellpadding="6" cellspacing="0" border="1" style="border-collapse:collapse;font-size:13px">'
                + '<tr style="background:#f3f4f6"><th align="left">Agreement</th><th align="left">Customer</th><th align="left">Payment reversed</th>'
                + '<th align="right">Amount</th><th align="left">Reason</th><th align="left">Returned on</th><th align="right">Arrears now</th></tr>'
                + String.join(rows, '') + '</table>';
        }
        if (!unmatched.isEmpty()) {
            html += '<p><b>Late returns not matched to a Salesforce payment (' + unmatched.size() + ')</b>: please check these by hand.</p><ul>';
            for (Ezidebit_Dishonour__c d : unmatched) {
                html += '<li>' + link(base + d.Id, d.Contract_Reference__c) + ': ' + money(d.Payment_Amount__c) + ' debited ' + fmt(d.Debit_Date__c)
                    + (String.isBlank(d.Bank_Failed_Reason__c) ? '' : ' (' + esc(d.Bank_Failed_Reason__c) + ')') + '</li>';
            }
            html += '</ul>';
        }
        html += '<p style="color:#6b7280;font-size:12px">Sent automatically by Salesforce each morning after the Ezidebit runs. '
            + 'Dishonour fees and default notices follow the usual collections process: a reversed agreement shows arrears again and appears on the dishonours page.</p></div>';

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setSubject('Ezidebit reversals ' + System.now().format('d MMM yyyy', 'Australia/Sydney') + ': '
            + (reversed.isEmpty() ? 'none' : reversed.size() + ' payment' + (reversed.size() == 1 ? '' : 's') + ', ' + money(total))
            + (unmatched.isEmpty() ? '' : ' (' + unmatched.size() + ' to check)'));
        mail.setHtmlBody(html);
        return mail;
    }

    private static String td(String v) { return '<td>' + (v == null ? '' : v) + '</td>'; }
    private static String tdRight(String v) { return '<td align="right">' + (v == null ? '' : v) + '</td>'; }
    private static String link(String url, String label) { return '<a href="' + url + '">' + esc(label) + '</a>'; }
    private static String esc(String v) { return v == null ? '' : v.escapeHtml4(); }
    private static String fmt(Date d) { return d == null ? '' : Datetime.newInstance(d, Time.newInstance(12, 0, 0, 0)).format('d MMM yyyy'); }
    private static String money(Decimal v) {
        if (v == null) return '';
        Decimal r = v.setScale(2, RoundingMode.HALF_UP);
        List<String> parts = String.valueOf(r.abs()).split('\\.');
        String whole = parts[0];
        String grouped = '';
        while (whole.length() > 3) {
            grouped = ',' + whole.right(3) + grouped;
            whole = whole.left(whole.length() - 3);
        }
        return (r < 0 ? '-$' : '$') + whole + grouped + '.' + (parts.size() > 1 ? parts[1] : '00');
    }
}
