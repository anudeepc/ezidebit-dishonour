/**
 * SeeAllData for the same reason as EzidebitDishonourServiceTest: inserting agreements runs the
 * org's trigger gates. Each test adds its own Dishonour record to an existing credit contract.
 */
@isTest(SeeAllData = true)
private class Form11AServiceTest {

    private static Opportunity dueAgreement() {
        List<Opportunity> opps = [
            SELECT Id, AccountId, Contract_No__c FROM Opportunity
            WHERE Is_Credit_Contract__c = true AND Is_Active__c = true AND Contract_No__c != null AND MP1__c = null
              AND Account.State_Master_State__c != 'NZ'
              AND Account.Territory_Number__r.Status__c = 'Active' AND Account.Territory_Number__r.Is_Credit_Contract__c = true
              AND Account.Enquiry_Status__c NOT IN ('Deceased', 'Incarcerated')
            LIMIT 1
        ];
        return opps.isEmpty() ? null : opps[0];
    }

    private static Ezidebit_Dishonour__c firstDefault(Opportunity opp, String paymentId) {
        Ezidebit_Dishonour__c d = new Ezidebit_Dishonour__c(
            Opportunity__c = opp.Id, Account__c = opp.AccountId, Ezidebit_Payment_ID__c = paymentId,
            Contract_Reference__c = opp.Contract_No__c, Status__c = 'D', Type__c = EzidebitDishonourService.TYPE_INSTALMENT,
            Outcome__c = EzidebitDishonourService.OUTCOME_OPEN, Is_Scheduled_Debit__c = true, First_Default__c = true,
            Debit_Date__c = Date.today().addDays(-10), Payment_Amount__c = 48.21);
        insert d;
        return d;
    }

    @isTest
    static void send_givesTheNoticeAndRecordsIt() {
        Opportunity opp = dueAgreement();
        if (opp == null) {
            return;
        }
        Ezidebit_Dishonour__c d = firstDefault(opp, 'T-11A-1');
        Test.startTest();
        Form11AService.Outcome res = Form11AService.send(new Set<Id>{ d.Id });
        Test.stopTest();
        System.assertEquals(1, res.emailed + res.toPost, String.valueOf(res.skipped));
        Ezidebit_Dishonour__c after = [SELECT Form_11A_Sent_Date__c, Form_11A_Channel__c FROM Ezidebit_Dishonour__c WHERE Id = :d.Id];
        System.assertEquals(Date.today(), after.Form_11A_Sent_Date__c);
        System.assert(after.Form_11A_Channel__c == Form11AService.CHANNEL_EMAIL || after.Form_11A_Channel__c == Form11AService.CHANNEL_POST);
        System.assertEquals(Date.today(), [SELECT MP1__c FROM Opportunity WHERE Id = :opp.Id].MP1__c, 'same stamp as the Dishonours page');
        System.assertEquals(1, [SELECT COUNT() FROM Attachment WHERE ParentId = :opp.Id AND Name LIKE :Form11AService.LETTER_TYPE + '%' AND CreatedDate = TODAY]);

        Form11AService.Outcome again = Form11AService.send(new Set<Id>{ d.Id });
        System.assertEquals(0, again.emailed + again.toPost, 'never sent twice');
        System.assertEquals(1, again.skipped.size());
    }

    @isTest
    static void blockReason_coversEachException() {
        Opportunity cc = new Opportunity(Is_Credit_Contract__c = true, Is_Active__c = true);
        Ezidebit_Dishonour__c ok = new Ezidebit_Dishonour__c(First_Default__c = true);
        ok.Opportunity__r = cc;
        System.assertEquals(null, Form11AService.blockReason(ok));

        Ezidebit_Dishonour__c noOpp = new Ezidebit_Dishonour__c(First_Default__c = true);
        System.assertNotEquals(null, Form11AService.blockReason(noOpp));

        Ezidebit_Dishonour__c lease = new Ezidebit_Dishonour__c(First_Default__c = true);
        lease.Opportunity__r = new Opportunity(Is_Credit_Contract__c = false);
        System.assertEquals('not a credit contract', Form11AService.blockReason(lease));

        Ezidebit_Dishonour__c notFirst = new Ezidebit_Dishonour__c(First_Default__c = false);
        notFirst.Opportunity__r = cc;
        System.assertEquals('not the first default', Form11AService.blockReason(notFirst));

        Ezidebit_Dishonour__c history = new Ezidebit_Dishonour__c(First_Default__c = true, Is_Backfill__c = true);
        history.Opportunity__r = cc;
        System.assertEquals('loaded from history', Form11AService.blockReason(history));

        Ezidebit_Dishonour__c sent = new Ezidebit_Dishonour__c(First_Default__c = true, Form_11A_Sent_Date__c = Date.today());
        sent.Opportunity__r = cc;
        System.assert(Form11AService.blockReason(sent).startsWith('already sent'));

        Ezidebit_Dishonour__c nz = new Ezidebit_Dishonour__c(First_Default__c = true);
        Opportunity nzOpp = new Opportunity(Is_Credit_Contract__c = true, Is_Active__c = true);
        nzOpp.Account = (Account) JSON.deserialize('{"State_Master_State__c":"NZ"}', Account.class);
        nz.Opportunity__r = nzOpp;
        System.assert(Form11AService.blockReason(nz).startsWith('New Zealand'), 'the NCC notice is for Australian agreements');

        Ezidebit_Dishonour__c closed = new Ezidebit_Dishonour__c(First_Default__c = true);
        closed.Opportunity__r = new Opportunity(Is_Credit_Contract__c = true, Is_Active__c = false);
        System.assertEquals('agreement is no longer active', Form11AService.blockReason(closed));

        Opportunity deceasedOpp = new Opportunity(Is_Credit_Contract__c = true, Is_Active__c = true);
        deceasedOpp.Account = new Account(Enquiry_Status__c = 'Deceased');
        Ezidebit_Dishonour__c deceased = new Ezidebit_Dishonour__c(First_Default__c = true);
        deceased.Opportunity__r = deceasedOpp;
        System.assert(Form11AService.blockReason(deceased).contains('deceased'));
    }

    @isTest
    static void emailBody_matchesTheDishonoursPageWording() {
        Opportunity opp = new Opportunity(Name = '3000 - Samsung 65in TV');
        opp.Account = new Account(FirstName = 'Jo');
        String body = Form11AService.emailBody(opp);
        System.assert(body.contains('Dear Jo,'));
        System.assert(body.contains('direct debit default for your Samsung 65in TV account'));
    }

    @isTest
    static void console_listsReviewsAndSends() {
        Opportunity opp = dueAgreement();
        if (opp == null) {
            return;
        }
        Ezidebit_Dishonour__c d = firstDefault(opp, 'T-11A-2');
        Test.setCurrentPage(Page.AdminProcessForm11A);
        ApexPages.currentPage().getParameters().put('ccCAP', 'true');
        Form11AConsoleController ctl = new Form11AConsoleController();
        ctl.load();
        Form11AConsoleController.Row mine;
        for (Form11AConsoleController.Row r : ctl.rows) {
            if (r.d.Id == d.Id) {
                mine = r;
            }
        }
        System.assertNotEquals(null, mine, 'the first default is listed');
        System.assertEquals(10, mine.daysSinceDebit);
        System.assertEquals(4, mine.daysLeft);
        System.assertEquals('red', mine.urgency, 'day 10 is red');
        System.assert(ctl.redCount >= 1);
        System.assertEquals(true, mine.canSend);

        ctl.review();
        System.assertEquals(false, ctl.reviewing, 'nothing ticked');

        mine.selected = true;
        ctl.review();
        System.assertEquals(true, ctl.reviewing);
        System.assertEquals(1, ctl.reviewRows.size());
        ctl.cancelReview();
        System.assertEquals(false, ctl.reviewing);

        ctl.review();
        Test.startTest();
        ctl.send();
        Test.stopTest();
        System.assertEquals(Date.today(), [SELECT Form_11A_Sent_Date__c FROM Ezidebit_Dishonour__c WHERE Id = :d.Id].Form_11A_Sent_Date__c);
        for (Form11AConsoleController.Row r : ctl.rows) {
            System.assertNotEquals(d.Id, r.d.Id, 'a sent notice leaves the list');
        }
        System.assertEquals(25, ctl.maxPerSend);
    }

    @isTest
    static void console_recordsNoticesAlreadySentFromTheDishonoursPage() {
        Opportunity opp = dueAgreement();
        if (opp == null) {
            return;
        }
        Ezidebit_Dishonour__c d = firstDefault(opp, 'T-11A-3');
        Date sentOn = Date.today().addDays(-2);
        update new Opportunity(Id = opp.Id, MP1__c = sentOn);
        Test.setCurrentPage(Page.AdminProcessForm11A);
        Test.startTest();
        Form11AConsoleController ctl = new Form11AConsoleController();
        ctl.load();
        Test.stopTest();
        Ezidebit_Dishonour__c after = [SELECT Form_11A_Sent_Date__c, Form_11A_Channel__c FROM Ezidebit_Dishonour__c WHERE Id = :d.Id];
        System.assertEquals(sentOn, after.Form_11A_Sent_Date__c);
        System.assertEquals(Form11AService.CHANNEL_ALREADY, after.Form_11A_Channel__c);
        System.assert(ctl.reconciledCount >= 1);
    }
}