/**
 * Sends the Direct Debit Default Notice (Form 11A, NCC s87, reg 85) for first-default Dishonour
 * records. Same PDF, subject, body, bcc and MP1__c stamp as AdminProcessController.sendArrearsLetters,
 * plus the send date and channel on the Dishonour so the s87(2) 14-day deadline can be reported.
 *
 * No email address: the notice goes to the staff member sending it, to print and post (as the
 * console did before), and the channel says so.
 */
public without sharing class Form11AService {

    public static final String CHANNEL_EMAIL = 'Email';
    public static final String CHANNEL_POST = 'Staff copy to post';
    public static final String CHANNEL_ALREADY = 'Already sent (MP1)';
    public static final String LETTER_TYPE = 'Direct Debit Dishonoured - Default Notice';
    public static final String SUBJECT = 'Urgent: Action Required for Direct Debit Default';

    /** Each notice renders a PDF in this transaction: keeps heap and request time inside limits. */
    public static final Integer MAX_PER_SEND = 25;

    public class Outcome {
        public Integer emailed = 0;
        public Integer toPost = 0;
        public Integer alreadySent = 0;
        public List<String> skipped = new List<String>();
    }

    public static Outcome send(Set<Id> dishonourIds) {
        Outcome res = new Outcome();
        if (dishonourIds == null || dishonourIds.isEmpty()) {
            return res;
        }
        List<Ezidebit_Dishonour__c> rows = [
            SELECT Id, Name, Opportunity__c, Form_11A_Sent_Date__c, First_Default__c, Is_Backfill__c,
                   Opportunity__r.Name, Opportunity__r.Contract_No__c, Opportunity__r.MP1__c, Opportunity__r.Is_Credit_Contract__c,
                   Opportunity__r.Account.FirstName, Opportunity__r.Account.PersonEmail, Opportunity__r.Account.Enquiry_Status__c,
                   Opportunity__r.Account.Territory_Number__r.Collection_Number__c, Opportunity__r.Account.Territory_Number__r.Short_Name__c
            FROM Ezidebit_Dishonour__c
            WHERE Id IN :dishonourIds
            ORDER BY Debit_Date__c ASC
            LIMIT :MAX_PER_SEND
        ];
        User staff = [SELECT Email FROM User WHERE Id = :UserInfo.getUserId()];

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        List<Attachment> attachments = new List<Attachment>();
        Map<Id, Opportunity> oppUpdates = new Map<Id, Opportunity>();
        List<Ezidebit_Dishonour__c> dishonourUpdates = new List<Ezidebit_Dishonour__c>();

        for (Ezidebit_Dishonour__c d : rows) {
            Opportunity opp = d.Opportunity__r;
            String reason = blockReason(d);
            if (reason != null) {
                res.skipped.add(d.Name + ': ' + reason);
                continue;
            }
            if (oppUpdates.containsKey(opp.Id)) {
                res.skipped.add(d.Name + ': another failure on this agreement is in the same send');
                continue;
            }
            if (opp.MP1__c != null) {
                // Sent from the Dishonours page already: record it, don't send twice.
                dishonourUpdates.add(new Ezidebit_Dishonour__c(Id = d.Id, Form_11A_Sent_Date__c = opp.MP1__c, Form_11A_Channel__c = CHANNEL_ALREADY));
                res.alreadySent++;
                continue;
            }

            Blob pdfBlob;
            try {
                pdfBlob = new PageReference('/apex/DirectDebitDefaultNotice?Id=' + opp.Id).getContentAsPDF();
            } catch (VisualforceException e) {
                pdfBlob = Blob.valueOf('Some Text'); // getContent is not supported in tests
            }
            String pdfName = LETTER_TYPE + '_' + opp.Name + '_' + Datetime.now().format('ddMMMyyyy') + '.pdf';

            Boolean hasEmail = String.isNotBlank(opp.Account.PersonEmail);
            String to = hasEmail ? opp.Account.PersonEmail : staff.Email;
            if (String.isBlank(to)) {
                res.skipped.add(d.Name + ': no customer email and no email on your user');
                continue;
            }

            Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
            efa.setFileName(pdfName);
            efa.setBody(pdfBlob);
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setSubject(SUBJECT);
            email.setToAddresses(new List<String>{ to });
            email.setBccAddresses(new List<String>{ 'noreply@r4k.com.au' });
            email.setHtmlBody(emailBody(opp));
            email.setFileAttachments(new List<Messaging.EmailFileAttachment>{ efa });
            emails.add(email);

            attachments.add(new Attachment(ParentId = opp.Id, Body = pdfBlob, Name = pdfName));
            oppUpdates.put(opp.Id, new Opportunity(Id = opp.Id, MP1__c = Date.today()));
            dishonourUpdates.add(new Ezidebit_Dishonour__c(
                Id = d.Id,
                Form_11A_Sent_Date__c = Date.today(),
                Form_11A_Channel__c = hasEmail ? CHANNEL_EMAIL : CHANNEL_POST
            ));
            if (hasEmail) {
                res.emailed++;
            } else {
                res.toPost++;
            }
        }

        // Records first, email last: if anything fails the caller rolls back and nothing goes out.
        insert attachments;
        update oppUpdates.values();
        update dishonourUpdates;
        if (!emails.isEmpty()) {
            Messaging.reserveSingleEmailCapacity(emails.size());
            Messaging.sendEmail(emails);
        }
        return res;
    }

    /** Why a notice can't be sent from the panel, or null. The panel shows the same reason. */
    public static String blockReason(Ezidebit_Dishonour__c d) {
        Opportunity opp = d.Opportunity__r;
        if (opp == null) {
            return 'no agreement linked';
        }
        if (!opp.Is_Credit_Contract__c) {
            return 'not a credit contract';
        }
        if (!d.First_Default__c) {
            return 'not the first default';
        }
        if (d.Is_Backfill__c) {
            return 'loaded from history';
        }
        if (d.Form_11A_Sent_Date__c != null) {
            return 'already sent on ' + d.Form_11A_Sent_Date__c.format();
        }
        String status = opp.Account == null ? null : opp.Account.Enquiry_Status__c;
        if (status == 'Deceased' || status == 'Incarcerated') {
            return 'customer is ' + status.toLowerCase() + ': handle manually';
        }
        return null;
    }

    @TestVisible
    static String emailBody(Opportunity opp) {
        String fname = opp.Account.FirstName == null ? '' : opp.Account.FirstName;
        String prodName = opp.Name == null ? '' : (opp.Name.containsIgnoreCase(' - ') ? opp.Name.substringAfter(' - ') : opp.Name);
        String collectionNo = opp.Account.Territory_Number__r == null || opp.Account.Territory_Number__r.Collection_Number__c == null
            ? '' : opp.Account.Territory_Number__r.Collection_Number__c;
        String terName = opp.Account.Territory_Number__r == null || opp.Account.Territory_Number__r.Short_Name__c == null
            ? '' : opp.Account.Territory_Number__r.Short_Name__c;
        String body = '<html><body><p>Dear ' + fname + ',</p>';
        body += '<p>We regret to inform you of a recent direct debit default for your ' + prodName + ' account.</p>';
        body += '<p>Please find the attached Direct Debit Default Notice outlining the details.</p>';
        body += '<p>To rectify this, kindly contact our team at ' + collectionNo + ' at your earliest convenience.</p>';
        body += '<p>Mention the reference number in the notice for quicker assistance.</p>';
        body += '<p>Thank you for your prompt attention to this matter.</p>';
        body += '<p>Best Regards,<br/>' + terName + '</p>';
        body += '</body></html>';
        return body;
    }
}