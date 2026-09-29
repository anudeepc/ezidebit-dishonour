/**
 * Uses existing agreements and payments (SeeAllData) because inserting Accounts, Opportunities
 * and Payments in this org runs several trigger gates and the allocation engine, which are not
 * what these tests are about.
 */
@isTest(SeeAllData = true)
private class EzidebitDishonourServiceTest {

    // A Wednesday about three weeks ago, so a retry 4 business days later is the next Tuesday.
    private static Date wednesday() {
        Date d = Date.today().addDays(-21);
        while (Math.mod(Date.newInstance(1900, 1, 7).daysBetween(d), 7) != 3) {
            d = d.addDays(1);
        }
        return d;
    }

    private static Opportunity anyCreditContract() {
        List<Opportunity> opps = [
            SELECT Id, AccountId, Contract_No__c, MP1__c FROM Opportunity
            WHERE Is_Credit_Contract__c = true AND Contract_No__c != null AND MP1__c = null LIMIT 1
        ];
        return opps.isEmpty() ? null : opps[0];
    }

    private static EzidebitAPI.Payment pay(String id, String status, String ref, Date debit, Decimal amount, Decimal fee, String source) {
        EzidebitAPI.Payment p = new EzidebitAPI.Payment();
        p.PaymentID = id;
        p.PaymentStatus = status;
        p.YourSystemReference = ref;
        p.EzidebitCustomerID = 'E' + id;
        p.DebitDate = Datetime.newInstance(debit.year(), debit.month(), debit.day());
        p.SettlementDate = p.DebitDate.addDays(2);
        p.ScheduledAmount = amount.abs().doubleValue();
        p.PaymentAmount = amount.doubleValue();
        p.TransactionFeeClient = fee.doubleValue();
        p.TransactionFeeCustomer = 0;
        p.PaymentMethod = source == 'WEB' ? 'CR' : 'DR';
        p.PaymentSource = source;
        p.BankReturnCode = status == 'S' ? '0' : '6';
        p.BankFailedReason = status == 'S' ? null : (amount < 0 ? 'Late Return - Refer to customer' : 'Refer to customer');
        return p;
    }

    private static Map<String, Ezidebit_Dishonour__c> byPaymentId(Set<String> ids) {
        Map<String, Ezidebit_Dishonour__c> out = new Map<String, Ezidebit_Dishonour__c>();
        for (Ezidebit_Dishonour__c d : [
            SELECT Ezidebit_Payment_ID__c, Type__c, Outcome__c, Status__c, Debit_Date__c, Payment_Amount__c, Ezidebit_Fee__c,
                   Is_Scheduled_Debit__c, First_Default__c, Form_11A_Due_Date__c, Opportunity__c, Territory_Name__c,
                   Original_Dishonour__c, Recovered_By_Payment_ID__c, Recovered_By_Payment__c, Recovered_Date__c, Recovery_Ezidebit_Fee__c,
                   Reversed_Payment__c
            FROM Ezidebit_Dishonour__c WHERE Ezidebit_Payment_ID__c IN :ids
        ]) {
            out.put(d.Ezidebit_Payment_ID__c, d);
        }
        return out;
    }

    @isTest
    static void capture_classifiesEachCaseOnceAndLinksRetries() {
        Opportunity opp = anyCreditContract();
        String ref = opp == null ? 'NO-SUCH-CONTRACT' : opp.Contract_No__c;
        Date d1 = wednesday();
        List<EzidebitAPI.Payment> payments = new List<EzidebitAPI.Payment>{
            pay('T-RETRY', 'D', ref, d1.addDays(6), 48.21, 2.75, 'SCHEDULED'),   // 4 business days later
            pay('T-INST', 'D', ref, d1, 48.21, 2.75, 'SCHEDULED'),
            pay('T-NEXT', 'D', ref, d1.addDays(14), 48.21, 2.75, 'SCHEDULED'),   // next fortnight: a new instalment
            pay('T-FATAL', 'F', ref, d1.addDays(15), 30.00, 0, 'SCHEDULED'),
            pay('T-CARD', 'F', ref, d1.addDays(8), 40.00, 0.44, 'WEB'),
            pay('T-OK', 'S', ref, d1.addDays(3), 50.00, 0.80, 'SCHEDULED')
        };
        Test.startTest();
        EzidebitDishonourService.Result first = EzidebitDishonourService.capture(payments, new Map<String, String>{ 'T-INST' => 'R4K Services' });
        EzidebitDishonourService.Result again = EzidebitDishonourService.capture(payments, null);
        Test.stopTest();

        System.assertEquals(5, first.inserted, 'five failures; the success is not a dishonour');
        System.assertEquals(0, again.inserted, 'the same payment IDs are never recorded twice');
        System.assertEquals(5, again.updated);

        Map<String, Ezidebit_Dishonour__c> d = byPaymentId(new Set<String>{ 'T-INST', 'T-RETRY', 'T-NEXT', 'T-FATAL', 'T-CARD' });
        System.assertEquals('Instalment', d.get('T-INST').Type__c);
        System.assertEquals('Open', d.get('T-INST').Outcome__c);
        System.assertEquals(d1, d.get('T-INST').Debit_Date__c);
        System.assertEquals(2.75, d.get('T-INST').Ezidebit_Fee__c);
        System.assertEquals('R4K Services', d.get('T-INST').Territory_Name__c);
        System.assertEquals('Automatic retry', d.get('T-RETRY').Type__c);
        System.assertEquals(d.get('T-INST').Id, d.get('T-RETRY').Original_Dishonour__c, 'a retry points at the instalment it retried');
        System.assertEquals('Instalment', d.get('T-NEXT').Type__c, 'outside the retry window it is a new missed instalment');
        System.assertEquals('Fatal', d.get('T-FATAL').Type__c);
        System.assertEquals('Debits stopped', d.get('T-FATAL').Outcome__c);
        System.assertEquals('Card declined', d.get('T-CARD').Type__c);
        System.assertEquals(false, d.get('T-CARD').Is_Scheduled_Debit__c);
        System.assertEquals(false, d.get('T-RETRY').First_Default__c, 'a failed retry never starts a Form 11A');
        System.assertEquals(false, d.get('T-CARD').First_Default__c);
        if (opp != null) {
            System.assertEquals(opp.Id, d.get('T-INST').Opportunity__c);
            System.assert(d.get('T-INST').First_Default__c, 'the earliest missed instalment is the first default');
            System.assertEquals(d1.addDays(14), d.get('T-INST').Form_11A_Due_Date__c);
            System.assertEquals(false, d.get('T-NEXT').First_Default__c);
        }
    }

    @isTest
    static void capture_linksARetryToAnInstalmentRecordedInAnEarlierRun() {
        Date d1 = wednesday();
        EzidebitDishonourService.capture(new List<EzidebitAPI.Payment>{ pay('T-A1', 'D', 'REF-A', d1, 35.86, 2.75, 'SCHEDULED') }, null);
        Test.startTest();
        EzidebitDishonourService.capture(new List<EzidebitAPI.Payment>{ pay('T-A2', 'D', 'REF-A', d1.addDays(6), 35.86, 2.75, 'SCHEDULED') }, null);
        Test.stopTest();
        Map<String, Ezidebit_Dishonour__c> d = byPaymentId(new Set<String>{ 'T-A1', 'T-A2' });
        System.assertEquals('Automatic retry', d.get('T-A2').Type__c);
        System.assertEquals(d.get('T-A1').Id, d.get('T-A2').Original_Dishonour__c);
    }

    @isTest
    static void recordRecoveries_marksRetryAndLaterPayments() {
        Date d1 = wednesday();
        EzidebitDishonourService.capture(new List<EzidebitAPI.Payment>{
            pay('T-R1', 'D', 'REF-R', d1, 48.21, 2.75, 'SCHEDULED'),
            pay('T-L1', 'D', 'REF-L', d1, 30.00, 2.75, 'SCHEDULED')
        }, null);
        Test.startTest();
        Integer n = EzidebitDishonourService.recordRecoveries(new List<EzidebitAPI.Payment>{
            pay('T-S-SAME', 'S', 'REF-R', d1, 48.21, 0.80, 'SCHEDULED'),          // same day: not a recovery
            pay('T-S-RETRY', 'S', 'REF-R', d1.addDays(6), 48.21, 0.80, 'SCHEDULED'),
            pay('T-S-LATER', 'S', 'REF-L', d1.addDays(1), 30.00, 0.80, 'SCHEDULED')
        });
        Test.stopTest();
        System.assertEquals(2, n);
        Map<String, Ezidebit_Dishonour__c> d = byPaymentId(new Set<String>{ 'T-R1', 'T-L1' });
        System.assertEquals('Recovered by retry', d.get('T-R1').Outcome__c);
        System.assertEquals('T-S-RETRY', d.get('T-R1').Recovered_By_Payment_ID__c);
        System.assertEquals(d1.addDays(6), d.get('T-R1').Recovered_Date__c);
        System.assertEquals(0.80, d.get('T-R1').Recovery_Ezidebit_Fee__c);
        System.assertEquals('Recovered by later payment', d.get('T-L1').Outcome__c, 'one business day later is not the automatic retry');
    }

    @isTest
    static void lateReturn_flagsThePaymentAndReopensWhatItRecovered() {
        List<Payment__c> pays = [
            SELECT Id, Agreement__r.Contract_No__c, Payment_Date__c, Actual_Amount__c FROM Payment__c
            WHERE RecordTypeId = :PaymentUtil.RECORDTYPE_ID_EZIDEBIT AND Agreement__r.Contract_No__c != null
              AND Payment_Date__c != null AND Actual_Amount__c > 0 AND Ezidebit_Payment_ID__c = null AND Late_Returned__c = false
            LIMIT 1
        ];
        if (pays.isEmpty()) {
            return; // no Ezidebit payment in this org to take back
        }
        Payment__c taken = pays[0];
        String ref = taken.Agreement__r.Contract_No__c;
        // Production keeps the late-return flag switched off at org level until Finance decides; this test turns it on for itself.
        insert new Ezidebit_Sync_Settings__c(SetupOwnerId = UserInfo.getUserId(), Disable_Late_Return_Flag__c = false);
        // An open instalment that this payment appeared to recover, 4 business days earlier.
        Date original = taken.Payment_Date__c.addDays(-6);
        EzidebitDishonourService.capture(new List<EzidebitAPI.Payment>{ pay('T-LR-ORIG', 'D', ref, original, taken.Actual_Amount__c, 2.75, 'SCHEDULED') }, null);
        update new Ezidebit_Dishonour__c(Id = byPaymentId(new Set<String>{ 'T-LR-ORIG' }).get('T-LR-ORIG').Id,
            Outcome__c = 'Recovered by retry', Recovered_By_Payment_ID__c = 'T-LR');

        Test.startTest();
        EzidebitDishonourService.Result res = EzidebitDishonourService.capture(new List<EzidebitAPI.Payment>{
            pay('T-LR', 'D', ref, taken.Payment_Date__c, -taken.Actual_Amount__c, 0, 'SCHEDULED')
        }, null);
        Test.stopTest();

        Map<String, Ezidebit_Dishonour__c> d = byPaymentId(new Set<String>{ 'T-LR', 'T-LR-ORIG' });
        System.assertEquals('Late return', d.get('T-LR').Type__c);
        System.assertEquals(taken.Actual_Amount__c.setScale(2), d.get('T-LR').Payment_Amount__c, 'stored as a positive amount');
        System.assertEquals(taken.Id, d.get('T-LR').Reversed_Payment__c, 'matched by contract, debit date and amount');
        System.assert(res.paymentsFlagged >= 1);
        System.assert([SELECT Late_Returned__c FROM Payment__c WHERE Id = :taken.Id].Late_Returned__c);
        System.assertEquals('Open', d.get('T-LR-ORIG').Outcome__c, 'the instalment is open again once its recovery was taken back');
        System.assertEquals(null, d.get('T-LR-ORIG').Recovered_By_Payment_ID__c);
    }

    @isTest
    static void upload_skipsDuplicatesRefreshesFeesAndClassifiesDebits() {
        List<Payment__c> pays = [
            SELECT Id, Agreement__c, Client_Fees__c FROM Payment__c
            WHERE RecordTypeId = :PaymentUtil.RECORDTYPE_ID_EZIDEBIT AND Agreement__c != null AND Ezidebit_Payment_ID__c = null
            LIMIT 1
        ];
        Date d1 = wednesday();
        EzidebitDishonourService.capture(new List<EzidebitAPI.Payment>{ pay('T-U1', 'D', 'REF-U', d1, 20.00, 2.75, 'SCHEDULED') }, null);
        EzidebitDishonourService.recordRecoveries(new List<EzidebitAPI.Payment>{ pay('T-U-RETRY', 'S', 'REF-U', d1.addDays(6), 20.00, 0.80, 'SCHEDULED') });

        List<EzidebitSettled__c> rows = new List<EzidebitSettled__c>{
            new EzidebitSettled__c(PaymentID__c = 'T-U-RETRY', PaymentSource__c = 'SCHEDULED'),
            new EzidebitSettled__c(PaymentID__c = 'T-U-WEB', PaymentSource__c = 'WEB')
        };
        if (!pays.isEmpty()) {
            update new Payment__c(Id = pays[0].Id, Ezidebit_Payment_ID__c = 'T-U-EXISTING', Client_Fees__c = 0.80);
            rows.add(new EzidebitSettled__c(PaymentID__c = 'T-U-EXISTING', PaymentSource__c = 'SCHEDULED', ClientFee__c = 2.75));
            rows.add(new EzidebitSettled__c(PaymentID__c = 'T-U-NEXT', PaymentSource__c = 'SCHEDULED', Opportunity__c = pays[0].Agreement__c));
        }

        Test.startTest();
        EzidebitDishonourService.UploadContext ctx = EzidebitDishonourService.uploadContext(rows);
        System.assertEquals(false, ctx.isDuplicate(rows[0]));
        System.assertEquals('Automatic retry', ctx.debitType(rows[0]));
        System.assertEquals('Online card', ctx.debitType(rows[1]));
        Payment__c p = new Payment__c();
        ctx.linkBeforeInsert(p, rows[0]);
        System.assertNotEquals(null, p.Recovered_Dishonour__c, 'the payment points at the instalment it recovered');
        if (!pays.isEmpty()) {
            System.assert(ctx.isDuplicate(rows[2]), 'an Ezidebit payment already recorded is not inserted again');
            System.assertEquals('Instalment', ctx.debitType(rows[3]), 'the agreement already has an Ezidebit payment');
            ctx.linkAfterInsert(new Payment__c(Id = pays[0].Id, Ezidebit_Payment_ID__c = 'T-U-EXISTING',
                Recovered_Dishonour__c = byPaymentId(new Set<String>{ 'T-U1' }).get('T-U1').Id));
        }
        ctx.flush();
        Test.stopTest();

        if (!pays.isEmpty()) {
            System.assertEquals(2.75, [SELECT Client_Fees__c FROM Payment__c WHERE Id = :pays[0].Id].Client_Fees__c, 'the fee follows Ezidebit');
            System.assertEquals(pays[0].Id, byPaymentId(new Set<String>{ 'T-U1' }).get('T-U1').Recovered_By_Payment__c);
        }
        EzidebitSettled__c firstDebit = new EzidebitSettled__c(PaymentID__c = 'T-U-FIRST', PaymentSource__c = 'SCHEDULED', Opportunity__c = anyOppWithoutEzidebitPayment());
        if (firstDebit.Opportunity__c != null) {
            System.assertEquals('First debit', EzidebitDishonourService.uploadContext(new List<EzidebitSettled__c>{ firstDebit }).debitType(firstDebit));
        }
    }

    private static Id anyOppWithoutEzidebitPayment() {
        for (Opportunity o : [SELECT Id, (SELECT Id FROM Payments__r LIMIT 1) FROM Opportunity WHERE Is_Credit_Contract__c = true LIMIT 50]) {
            if (o.Payments__r.isEmpty()) {
                return o.Id;
            }
        }
        return null;
    }

    @isTest
    static void dishonourFee_linksToTheLatestMissedInstalmentNotARetry() {
        Opportunity opp = anyCreditContract();
        if (opp == null) {
            return;
        }
        Date d1 = wednesday();
        EzidebitDishonourService.capture(new List<EzidebitAPI.Payment>{
            pay('T-F1', 'D', opp.Contract_No__c, d1, 48.21, 2.75, 'SCHEDULED'),
            pay('T-F2', 'D', opp.Contract_No__c, d1.addDays(6), 48.21, 2.75, 'SCHEDULED')
        }, null);
        Test.startTest();
        Fee__c fee = new Fee__c(Agreement__c = opp.Id, Account__c = opp.AccountId, Fee_Type__c = EzidebitDishonourService.FEE_TYPE_DISHONOUR,
            Fee_Amount__c = 16.50, Fee_Charged_Date__c = Date.today());
        insert fee;
        Test.stopTest();
        Ezidebit_Dishonour__c instalment = [SELECT Fee__c, Dishonour_Fee_Charged__c FROM Ezidebit_Dishonour__c WHERE Ezidebit_Payment_ID__c = 'T-F1'];
        System.assertEquals(fee.Id, instalment.Fee__c, 'the fee belongs to the missed instalment');
        System.assertEquals(16.50, instalment.Dishonour_Fee_Charged__c);
        System.assertEquals(null, [SELECT Fee__c FROM Ezidebit_Dishonour__c WHERE Ezidebit_Payment_ID__c = 'T-F2'].Fee__c);
    }

    @isTest
    static void switches_turnRecordingOff() {
        insert new Ezidebit_Sync_Settings__c(SetupOwnerId = UserInfo.getUserId(), Disable_Dishonour_Recording__c = true);
        Test.startTest();
        EzidebitDishonourService.Result r = EzidebitDishonourService.capture(new List<EzidebitAPI.Payment>{
            pay('T-OFF', 'D', 'REF-OFF', wednesday(), 10.00, 2.75, 'SCHEDULED') }, null);
        Test.stopTest();
        System.assertEquals(0, r.inserted);
        System.assertEquals(0, [SELECT COUNT() FROM Ezidebit_Dishonour__c WHERE Ezidebit_Payment_ID__c = 'T-OFF']);
    }

    @isTest
    static void businessDays_skipWeekends() {
        Date wed = wednesday();
        System.assertEquals(4, EzidebitDishonourService.businessDaysBetween(wed, wed.addDays(6)), 'Wednesday to Tuesday');
        System.assertEquals(2, EzidebitDishonourService.businessDaysBetween(wed, wed.addDays(2)));
        System.assert(EzidebitDishonourService.withinRetryWindow(wed, wed.addDays(11)));
        System.assert(!EzidebitDishonourService.withinRetryWindow(wed, wed.addDays(12)));
    }

    private class FailedPaymentsMock implements WebServiceMock {
        public void doInvoke(Object stub, Object request, Map<String, Object> response, String endpoint, String soapAction,
                             String requestName, String responseNS, String responseName, String responseType) {
            EzidebitAPI.EziResponseOfArrayOfPaymentTHgMB7oL ezi = new EzidebitAPI.EziResponseOfArrayOfPaymentTHgMB7oL();
            EzidebitAPI.ArrayOfPayment data = new EzidebitAPI.ArrayOfPayment();
            data.Payment = new List<EzidebitAPI.Payment>{ EzidebitDishonourServiceTest.pay('T-C1', 'F', 'REF-C', Date.today().addDays(-3), 37.93, 0, 'SCHEDULED') };
            ezi.Data = data;
            EzidebitAPI.GetPaymentsResponse_element el = new EzidebitAPI.GetPaymentsResponse_element();
            el.GetPaymentsResult = ezi;
            response.put('response_x', el);
        }
    }

    @isTest
    static void catchUpBatch_recordsFailuresForOneTerritory() {
        // Held in memory only: execute() takes the territory as given, and inserting one would hit the duplicate rule.
        Territory__c ter = new Territory__c(Name = '9999', Short_Name__c = 'Test Catch Up', Ezidebit_DigitalKey__c = 'TEST-KEY');
        Test.setMock(WebServiceMock.class, new FailedPaymentsMock());
        EzidebitDishonourCatchUpBatch batch = new EzidebitDishonourCatchUpBatch();
        Test.startTest();
        batch.execute(null, new List<Territory__c>{ ter });
        batch.finish(null);
        Test.stopTest();
        Ezidebit_Dishonour__c d = [SELECT Type__c, Territory_Name__c FROM Ezidebit_Dishonour__c WHERE Ezidebit_Payment_ID__c = 'T-C1'];
        System.assertEquals('Fatal', d.Type__c);
        System.assertEquals('Test Catch Up', d.Territory_Name__c);
        System.assertNotEquals(null, batch.start(null));
    }

    @isTest
    static void daytimeCheck_recordsTodaysFailures() {
        Territory__c ter = new Territory__c(Name = '9998', Short_Name__c = 'Test Daytime', Ezidebit_DigitalKey__c = 'TEST-KEY');
        Test.setMock(WebServiceMock.class, new FailedPaymentsMock());
        Test.startTest();
        new EzidebitDishonourCatchUpBatch(0).execute(null, new List<Territory__c>{ ter });
        Test.stopTest();
        System.assertEquals(1, [SELECT COUNT() FROM Ezidebit_Dishonour__c WHERE Ezidebit_Payment_ID__c = 'T-C1']);
    }

    @isTest
    static void catchUpBatch_schedulesItself() {
        Test.startTest();
        String jobId = System.schedule('Dishonour catch-up test', '0 30 3 * * ?', new EzidebitDishonourCatchUpBatch());
        System.assertNotEquals(null, jobId);
        System.abortJob(jobId); // don't let stopTest run it: one executeBatch per test, many territories
        Test.stopTest();
    }

    @isTest
    static void retryRecordedBeforeItsOriginal_isRelinkedAndFirstDefaultMoves() {
        Opportunity opp = anyCreditContract();
        String ref = opp == null ? 'REF-LATE-ORIG' : opp.Contract_No__c;
        Date d1 = wednesday();
        // The retry arrives first (e.g. go-live): recorded as a missed instalment.
        EzidebitDishonourService.capture(new List<EzidebitAPI.Payment>{ pay('T-RL2', 'D', ref, d1.addDays(6), 48.21, 2.75, 'SCHEDULED') }, null);
        Test.startTest();
        EzidebitDishonourService.Result r = EzidebitDishonourService.capture(new List<EzidebitAPI.Payment>{ pay('T-RL1', 'D', ref, d1, 48.21, 2.75, 'SCHEDULED') }, null);
        Test.stopTest();
        System.assertEquals(1, r.relinked);
        Map<String, Ezidebit_Dishonour__c> d = byPaymentId(new Set<String>{ 'T-RL1', 'T-RL2' });
        System.assertEquals('Automatic retry', d.get('T-RL2').Type__c);
        System.assertEquals(d.get('T-RL1').Id, d.get('T-RL2').Original_Dishonour__c);
        System.assertEquals(null, d.get('T-RL2').Outcome__c);
        if (opp != null) {
            System.assertEquals(false, d.get('T-RL2').First_Default__c, 'the retry is not the first default');
            System.assert(d.get('T-RL1').First_Default__c, 'the real first failure is');
        }
    }

    @isTest
    static void relinkBatch_repairsExistingRecords() {
        Date d1 = wednesday();
        List<Ezidebit_Dishonour__c> rows = new List<Ezidebit_Dishonour__c>{
            new Ezidebit_Dishonour__c(Ezidebit_Payment_ID__c = 'T-RB1', Contract_Reference__c = 'REF-RB', Debit_Date__c = d1,
                Payment_Amount__c = 20, Type__c = 'Instalment', Outcome__c = 'Open', Status__c = 'D'),
            new Ezidebit_Dishonour__c(Ezidebit_Payment_ID__c = 'T-RB2', Contract_Reference__c = 'REF-RB', Debit_Date__c = d1.addDays(6),
                Payment_Amount__c = 20, Type__c = 'Instalment', Outcome__c = 'Open', Status__c = 'D'),
            new Ezidebit_Dishonour__c(Ezidebit_Payment_ID__c = 'T-RB3', Contract_Reference__c = 'REF-RB', Debit_Date__c = d1.addDays(14),
                Payment_Amount__c = 20, Type__c = 'Instalment', Outcome__c = 'Open', Status__c = 'D')
        };
        insert rows;
        EzidebitDishonourRelinkBatch b = new EzidebitDishonourRelinkBatch();
        Test.startTest();
        b.execute(null, rows);
        b.finish(null);
        Test.stopTest();
        System.assertNotEquals(null, b.start(null));
        Map<String, Ezidebit_Dishonour__c> d = byPaymentId(new Set<String>{ 'T-RB1', 'T-RB2', 'T-RB3' });
        System.assertEquals('Automatic retry', d.get('T-RB2').Type__c);
        System.assertEquals('Instalment', d.get('T-RB3').Type__c, 'the next fortnight is a new instalment, not a retry of the retry');
        System.assertEquals(1, b.relinked);
    }

    @isTest
    static void recoveryBatch_canIncludeLiveRecords() {
        EzidebitDishonourRecoveryBatch b = new EzidebitDishonourRecoveryBatch(true);
        System.assertNotEquals(null, b.start(null));
        Test.startTest();
        b.execute(null, new List<Ezidebit_Dishonour__c>());
        b.finish(null);
        Test.stopTest();
    }
}
