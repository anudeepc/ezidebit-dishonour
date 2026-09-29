/**
 * The summary rules are tested on records built in memory (a fixed "today", retries as child rows),
 * and the page wiring on an existing collection activity (SeeAllData: inserting agreements runs the
 * org's trigger gates).
 */
@isTest(SeeAllData = true)
private class CollectionDishonourPanelTest {

    // A Wednesday, so 4 business days later is the next Tuesday.
    static final Date TODAY = Date.newInstance(2026, 9, 30);

    private static Ezidebit_Dishonour__c failure(String name, Date debit, String type, String outcome, Date recovered, Date retryDate) {
        Map<String, Object> m = new Map<String, Object>{
            'attributes' => new Map<String, Object>{ 'type' => 'Ezidebit_Dishonour__c' },
            'Name' => name, 'Debit_Date__c' => String.valueOf(debit), 'Type__c' => type, 'Outcome__c' => outcome,
            'Payment_Amount__c' => 31.19, 'Ezidebit_Fee__c' => 2.75, 'Bank_Failed_Reason__c' => 'Refer to customer',
            'Bank_Return_Code__c' => '6', 'First_Default__c' => false
        };
        if (recovered != null) {
            m.put('Recovered_Date__c', String.valueOf(recovered));
        }
        if (retryDate != null) {
            m.put('Retries__r', new Map<String, Object>{ 'totalSize' => 1, 'done' => true, 'records' => new List<Object>{
                new Map<String, Object>{ 'attributes' => new Map<String, Object>{ 'type' => 'Ezidebit_Dishonour__c' }, 'Debit_Date__c' => String.valueOf(retryDate) } } });
        }
        return (Ezidebit_Dishonour__c) JSON.deserialize(JSON.serialize(m), Ezidebit_Dishonour__c.class);
    }

    private static CollectionDishonourPanel panelWith(List<Ezidebit_Dishonour__c> rows, List<Payment__c> payments, Opportunity opp) {
        CollectionDishonourPanel p = new CollectionDishonourPanel(new ApexPages.StandardController(new Collection_Activity__c()));
        p.dshRows = rows;
        p.dshHasAccess = true;
        p.summarise(opp == null ? new Opportunity() : opp, payments == null ? new List<Payment__c>() : payments, TODAY);
        return p;
    }

    @isTest
    static void retryFailed_isRedWithTheRetryDate() {
        CollectionDishonourPanel p = panelWith(new List<Ezidebit_Dishonour__c>{
            failure('DSH-2', Date.newInstance(2026, 9, 17), EzidebitDishonourService.TYPE_RETRY, null, null, null),
            failure('DSH-1', Date.newInstance(2026, 9, 11), EzidebitDishonourService.TYPE_INSTALMENT, EzidebitDishonourService.OUTCOME_OPEN, null, Date.newInstance(2026, 9, 17))
        }, null, null);
        System.assertEquals('danger', p.dshRetryTone);
        System.assert(p.dshRetryStatus.startsWith('Automatic retry failed on'), p.dshRetryStatus);
        System.assertEquals(1, p.dshUnrecoveredCount, 'the retry is not a second missed instalment');
        System.assertEquals(31.19, p.dshUnrecoveredAmount);
        System.assertEquals('danger', p.dshTone);
        System.assertEquals('DSH-2', p.dshLast.Name, 'newest failure first');
        System.assertEquals(2, p.dshFailures12m);
        System.assertEquals(5.50, p.dshEzidebitFees12m);
        System.assert(p.dshLastReason.contains('not enough money'));
    }

    @isTest
    static void retryPending_isAmberWithTheExpectedDate() {
        CollectionDishonourPanel p = panelWith(new List<Ezidebit_Dishonour__c>{
            failure('DSH-3', Date.newInstance(2026, 9, 28), EzidebitDishonourService.TYPE_INSTALMENT, EzidebitDishonourService.OUTCOME_OPEN, null, null)
        }, null, null);
        System.assertEquals('warning', p.dshRetryTone);
        System.assertEquals('Automatic retry due around ' + Date.newInstance(2026, 10, 2).format(), p.dshRetryStatus, 'Monday + 4 business days = Friday');
        System.assertEquals('warning', p.dshTone);
    }

    @isTest
    static void recovered_isGreen_andOldOpenFailuresDoNotCount() {
        CollectionDishonourPanel p = panelWith(new List<Ezidebit_Dishonour__c>{
            failure('DSH-5', Date.newInstance(2026, 9, 16), EzidebitDishonourService.TYPE_INSTALMENT, EzidebitDishonourService.OUTCOME_RETRY, Date.newInstance(2026, 9, 22), null),
            failure('DSH-4', Date.newInstance(2026, 5, 7), EzidebitDishonourService.TYPE_INSTALMENT, EzidebitDishonourService.OUTCOME_OPEN, null, null)
        }, null, null);
        System.assertEquals('success', p.dshRetryTone);
        System.assert(p.dshRetryStatus.startsWith('Recovered by retry'));
        System.assertEquals(0, p.dshUnrecoveredCount, 'May is outside the 60 days: it may have been caught up');
        System.assertEquals('success', p.dshTone);
    }

    @isTest
    static void oldUnmatchedInstalment_pointsToArrears() {
        CollectionDishonourPanel p = panelWith(new List<Ezidebit_Dishonour__c>{
            failure('DSH-6', Date.newInstance(2026, 5, 7), EzidebitDishonourService.TYPE_INSTALMENT, EzidebitDishonourService.OUTCOME_OPEN, null, null)
        }, null, null);
        System.assertEquals('secondary', p.dshRetryTone);
        System.assert(p.dshRetryStatus.contains('Check arrears'));
    }

    @isTest
    static void fatalAfterTheLastPayment_meansDebitsStopped() {
        Payment__c paid = new Payment__c(Payment_Date__c = Date.newInstance(2026, 9, 1), Actual_Amount__c = 31.19);
        CollectionDishonourPanel p = panelWith(new List<Ezidebit_Dishonour__c>{
            failure('DSH-7', Date.newInstance(2026, 9, 15), EzidebitDishonourService.TYPE_FATAL, EzidebitDishonourService.OUTCOME_STOPPED, null, null)
        }, new List<Payment__c>{ paid }, null);
        System.assert(p.dshDebitsStopped);
        System.assertEquals(Date.newInstance(2026, 9, 15), p.dshDebitsStoppedDate);
        System.assertEquals('danger', p.dshTone);

        CollectionDishonourPanel resumed = panelWith(new List<Ezidebit_Dishonour__c>{
            failure('DSH-8', Date.newInstance(2026, 8, 15), EzidebitDishonourService.TYPE_FATAL, EzidebitDishonourService.OUTCOME_STOPPED, null, null)
        }, new List<Payment__c>{ paid }, null);
        System.assertEquals(false, resumed.dshDebitsStopped, 'paid since, so debits were restarted');
    }

    @isTest
    static void noticeStatus_showsDueSentOrMp1() {
        Ezidebit_Dishonour__c first = failure('DSH-9', Date.newInstance(2026, 9, 25), EzidebitDishonourService.TYPE_INSTALMENT, EzidebitDishonourService.OUTCOME_OPEN, null, null);
        first.First_Default__c = true;
        Map<String, Object> m = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(first));
        m.put('Form_11A_Due_Date__c', '2026-10-09');
        first = (Ezidebit_Dishonour__c) JSON.deserialize(JSON.serialize(m), Ezidebit_Dishonour__c.class);
        System.assertEquals('Due by ' + Date.newInstance(2026, 10, 9).format() + ' (9 days)',
            CollectionDishonourPanel.noticeStatus(new Opportunity(), new List<Ezidebit_Dishonour__c>{ first }, TODAY));
        first.Form_11A_Sent_Date__c = Date.newInstance(2026, 9, 29);
        System.assertEquals('Sent ' + Date.newInstance(2026, 9, 29).format(),
            CollectionDishonourPanel.noticeStatus(new Opportunity(), new List<Ezidebit_Dishonour__c>{ first }, TODAY));
        System.assertEquals('Sent ' + Date.newInstance(2026, 3, 2).format(),
            CollectionDishonourPanel.noticeStatus(new Opportunity(MP1__c = Date.newInstance(2026, 3, 2)), new List<Ezidebit_Dishonour__c>(), TODAY));
        System.assertEquals('Not sent', CollectionDishonourPanel.noticeStatus(new Opportunity(), new List<Ezidebit_Dishonour__c>(), TODAY));
    }

    @isTest
    static void timeline_mergesPaymentsAndFailuresOldestFirst() {
        List<Payment__c> payments = new List<Payment__c>{
            new Payment__c(Payment_Date__c = Date.newInstance(2026, 9, 3), Actual_Amount__c = 31.19),
            new Payment__c(Payment_Date__c = Date.newInstance(2025, 1, 1), Actual_Amount__c = 31.19) // outside 6 months
        };
        List<Ezidebit_Dishonour__c> rows = new List<Ezidebit_Dishonour__c>{
            failure('DSH-11', Date.newInstance(2026, 9, 17), EzidebitDishonourService.TYPE_RETRY, null, null, null),
            failure('DSH-10', Date.newInstance(2026, 9, 11), EzidebitDishonourService.TYPE_INSTALMENT, EzidebitDishonourService.OUTCOME_OPEN, null, null),
            failure('DSH-12', Date.newInstance(2026, 8, 28), EzidebitDishonourService.TYPE_INSTALMENT, EzidebitDishonourService.OUTCOME_RETRY, Date.newInstance(2026, 9, 3), null)
        };
        List<CollectionDishonourPanel.TimelineEvent> events = CollectionDishonourPanel.timeline(payments, rows, TODAY);
        System.assertEquals(4, events.size());
        System.assertEquals('recovered', events[0].kind);
        System.assertEquals('paid', events[1].kind);
        System.assertEquals('failed', events[2].kind);
        System.assertEquals('retryFailed', events[3].kind);
        System.assert(events[2].detail.contains('DSH-10'));
    }

    @isTest
    static void describeReason_andBusinessDays() {
        System.assert(CollectionDishonourPanel.describeReason('Late Return - Refer to customer', '6').startsWith('Paid, then taken back'));
        System.assertEquals('Account closed', CollectionDishonourPanel.describeReason('Account closed', '3'));
        System.assertEquals('Bank code 9', CollectionDishonourPanel.describeReason(null, '9'));
        System.assertEquals(null, CollectionDishonourPanel.describeReason(null, null));
        System.assertEquals(Date.newInstance(2026, 10, 6), CollectionDishonourPanel.addBusinessDays(TODAY, 4), 'Wednesday + 4 = Tuesday');
    }

    @isTest
    static void page_loadsForARealCollectionActivity() {
        List<Collection_Activity__c> cas = [SELECT Id, Agreement__c FROM Collection_Activity__c
                                            WHERE Agreement__r.Is_Credit_Contract__c = true ORDER BY CreatedDate DESC LIMIT 1];
        if (cas.isEmpty()) {
            return;
        }
        Test.startTest();
        CollectionDishonourPanel p = new CollectionDishonourPanel(new ApexPages.StandardController(cas[0]));
        Test.stopTest();
        System.assert(p.dshHasAgreement);
        System.assertNotEquals(null, p.dshTimelineJson);
        System.assertNotEquals(null, p.dshRetryStatus);
        System.assert(p.dshCount >= 0);
    }

    @isTest
    static void hardshipStatus_openOverdueAndAgreed() {
        CollectionDishonourPanel p = new CollectionDishonourPanel(new ApexPages.StandardController(new Collection_Activity__c()));
        Hardship_Request__c open = (Hardship_Request__c) JSON.deserialize(JSON.serialize(new Map<String, Object>{
            'attributes' => new Map<String, Object>{ 'type' => 'Hardship_Request__c' },
            'Status__c' => 'Assessing', 'Is_Open__c' => true, 'Decision_Due_Date__c' => '2026-10-02' }), Hardship_Request__c.class);
        p.hardshipStatus(new List<Hardship_Request__c>{ open }, TODAY);
        System.assertEquals('danger', p.dshHardshipTone, '2 days to the decision deadline');
        System.assert(p.dshHardshipStatus.startsWith('Assessing: decision due by'));
        Hardship_Request__c agreed = new Hardship_Request__c(Status__c = 'Agreed', Agreed_Change__c = 'Payments paused', Change_End_Date__c = TODAY.addDays(30));
        p.hardshipStatus(new List<Hardship_Request__c>{ agreed }, TODAY);
        System.assertEquals('success', p.dshHardshipTone);
        System.assert(p.dshHardshipStatus.startsWith('Agreed payments paused'));
        p.hardshipStatus(new List<Hardship_Request__c>(), TODAY);
        System.assertEquals(null, p.dshHardshipStatus);
    }

    @isTest
    static void tools_andStatementEmail() {
        List<Collection_Activity__c> cas = [SELECT Id, Agreement__c FROM Collection_Activity__c
                                            WHERE Agreement__r.Is_Credit_Contract__c = true ORDER BY CreatedDate DESC LIMIT 1];
        if (cas.isEmpty()) {
            return;
        }
        CollectionDishonourPanel p = new CollectionDishonourPanel(new ApexPages.StandardController(cas[0]));
        System.assertNotEquals(null, p.dshOpp);
        System.assert(p.dshPayoutStatementUrl.contains('EarlyPayoutFigureStatement'));
        System.assert(p.dshNewHardshipUrl.contains('Hardship_Request__c/new'));
        Test.setCurrentPage(Page.CollectionActivityCreditContractPage);
        Test.startTest();
        p.dshSendStatement();
        Test.stopTest();
        System.assertEquals(Date.today(), [SELECT Customer_Statement_Sent_Date__c FROM Opportunity WHERE Id = :cas[0].Agreement__c].Customer_Statement_Sent_Date__c);
        System.assertEquals(1, [SELECT COUNT() FROM Attachment WHERE ParentId = :cas[0].Agreement__c AND Name LIKE 'Agreement Statement_%' AND CreatedDate = TODAY]);
        Opportunity o = new Opportunity(Name = '3000 - Fridge', Contract_No__c = '30000000001');
        o.Account = new Account(FirstName = 'Jo');
        String body = CollectionDishonourPanel.statementEmailBody(o);
        System.assert(body.contains('Dear Jo,'));
        System.assert(body.contains('30000000001 (Fridge)'));
    }
}
