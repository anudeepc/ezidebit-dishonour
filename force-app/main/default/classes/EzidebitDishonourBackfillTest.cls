@isTest(SeeAllData = true)
private class EzidebitDishonourBackfillTest {

    static String contractRef;
    static Date debitDate;

    private static Opportunity activeCreditContract() {
        List<Opportunity> opps = [
            SELECT Id, AccountId, Contract_No__c FROM Opportunity
            WHERE Is_Credit_Contract__c = true AND Is_Active__c = true AND Contract_No__c != null LIMIT 1
        ];
        return opps.isEmpty() ? null : opps[0];
    }

    private class HistoryMock implements WebServiceMock {
        public void doInvoke(Object stub, Object request, Map<String, Object> response, String endpoint, String soapAction,
                             String requestName, String responseNS, String responseName, String responseType) {
            EzidebitAPI.Payment p = new EzidebitAPI.Payment();
            p.PaymentID = 'T-HIST-1';
            p.PaymentStatus = 'D';
            p.YourSystemReference = contractRef;
            p.EzidebitCustomerID = 'E-HIST';
            p.DebitDate = Datetime.newInstance(debitDate.year(), debitDate.month(), debitDate.day());
            p.SettlementDate = p.DebitDate.addDays(2);
            p.ScheduledAmount = 48.21;
            p.PaymentAmount = 48.21;
            p.TransactionFeeClient = 2.75;
            p.TransactionFeeCustomer = 0;
            p.PaymentMethod = 'DR';
            p.PaymentSource = 'SCHEDULED';
            p.BankReturnCode = '6';
            p.BankFailedReason = 'Refer to customer';
            EzidebitAPI.EziResponseOfArrayOfPaymentTHgMB7oL ezi = new EzidebitAPI.EziResponseOfArrayOfPaymentTHgMB7oL();
            ezi.Data = new EzidebitAPI.ArrayOfPayment();
            ezi.Data.Payment = new List<EzidebitAPI.Payment>{ p };
            EzidebitAPI.GetPaymentsResponse_element el = new EzidebitAPI.GetPaymentsResponse_element();
            el.GetPaymentsResult = ezi;
            response.put('response_x', el);
        }
    }

    private static String item(Date fromDate) {
        Territory__c ter = [SELECT Id FROM Territory__c LIMIT 1];
        return ter.Id + '|' + String.valueOf(fromDate) + '|' + String.valueOf(fromDate.addDays(13));
    }

    @isTest
    static void dryRun_countsWithoutWriting_thenLoadMarksHistory() {
        Opportunity opp = activeCreditContract();
        if (opp == null) {
            return;
        }
        contractRef = opp.Contract_No__c;
        debitDate = Date.newInstance(2025, 3, 5);
        Test.setMock(WebServiceMock.class, new HistoryMock());
        Date fromDate = Date.newInstance(2025, 3, 1);

        EzidebitDishonourBackfillBatch dry = new EzidebitDishonourBackfillBatch(fromDate, fromDate.addDays(13), true);
        Test.startTest();
        dry.execute(null, new List<String>{ item(fromDate) });
        System.assertEquals(1, dry.inserted, String.valueOf(dry.errors));
        System.assertEquals(1, dry.countByMonth.get('2025-03'));
        System.assertEquals(2.75, dry.feesByMonth.get('2025-03'));
        System.assertEquals(0, [SELECT COUNT() FROM Ezidebit_Dishonour__c WHERE Ezidebit_Payment_ID__c = 'T-HIST-1'], 'a dry run writes nothing');
        dry.finish(null);

        EzidebitDishonourBackfillBatch load = new EzidebitDishonourBackfillBatch(fromDate, fromDate.addDays(13), false);
        load.execute(null, new List<String>{ item(fromDate) });
        Test.stopTest();
        Ezidebit_Dishonour__c d = [SELECT Is_Backfill__c, First_Default__c, Type__c, Opportunity__c FROM Ezidebit_Dishonour__c WHERE Ezidebit_Payment_ID__c = 'T-HIST-1'];
        System.assert(d.Is_Backfill__c);
        System.assertEquals(false, d.First_Default__c, 'history never raises a Form 11A');
        System.assertEquals(opp.Id, d.Opportunity__c);
        System.assertEquals(1, load.inserted);
    }

    @isTest
    static void start_buildsTerritoryWindowsOldestFirst() {
        EzidebitDishonourBackfillBatch b = new EzidebitDishonourBackfillBatch(Date.newInstance(2025, 1, 1), Date.newInstance(2025, 1, 31), true);
        List<String> items = (List<String>) b.start(null);
        Integer territories = [SELECT COUNT() FROM Territory__c WHERE Ezidebit_DigitalKey__c != null AND Status__c = 'Active'];
        System.assertEquals(territories * 3, items.size(), '31 days = three 14-day windows per territory');
        if (!items.isEmpty()) {
            System.assert(items[0].endsWith('2025-01-01|2025-01-14'));
            System.assert(items[items.size() - 1].endsWith('2025-01-29|2025-01-31'));
        }
    }

    @isTest
    static void recoveryBatch_closesInstalmentsPaidLater() {
        List<Payment__c> pays = [
            SELECT Id, Agreement__c, Payment_Date__c, Actual_Amount__c FROM Payment__c
            WHERE Agreement__c != null AND Payment_Date__c != null AND Actual_Amount__c > 0 AND Late_Returned__c = false
            ORDER BY Payment_Date__c DESC LIMIT 1
        ];
        if (pays.isEmpty()) {
            return;
        }
        Payment__c p = pays[0];
        Ezidebit_Dishonour__c d = new Ezidebit_Dishonour__c(
            Opportunity__c = p.Agreement__c, Ezidebit_Payment_ID__c = 'T-HIST-R', Status__c = 'D', Is_Backfill__c = true,
            Type__c = EzidebitDishonourService.TYPE_INSTALMENT, Outcome__c = EzidebitDishonourService.OUTCOME_OPEN,
            Debit_Date__c = p.Payment_Date__c.addDays(-6), Payment_Amount__c = p.Actual_Amount__c);
        insert d;
        EzidebitDishonourRecoveryBatch b = new EzidebitDishonourRecoveryBatch();
        System.assertNotEquals(null, b.start(null));
        Test.startTest();
        b.execute(null, [SELECT Id, Opportunity__c, Debit_Date__c, Payment_Amount__c FROM Ezidebit_Dishonour__c WHERE Id = :d.Id]);
        b.finish(null);
        Test.stopTest();
        Ezidebit_Dishonour__c after = [SELECT Outcome__c, Recovered_By_Payment__c FROM Ezidebit_Dishonour__c WHERE Id = :d.Id];
        System.assertNotEquals(EzidebitDishonourService.OUTCOME_OPEN, after.Outcome__c);
        System.assertNotEquals(null, after.Recovered_By_Payment__c);
    }

    @isTest
    static void feeLinkBatch_runs() {
        EzidebitFeeLinkBackfillBatch b = new EzidebitFeeLinkBackfillBatch();
        System.assertNotEquals(null, b.start(null));
        Test.startTest();
        b.execute(null, new List<Fee__c>());
        b.finish(null);
        Test.stopTest();
    }
}