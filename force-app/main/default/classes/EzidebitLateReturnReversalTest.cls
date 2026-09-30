/**
 * Uses existing Ezidebit payments and their allocations (SeeAllData), like EzidebitDishonourServiceTest:
 * building an agreement with instalments in a test runs the org's trigger gates and allocation engine.
 */
@isTest(SeeAllData = true)
private class EzidebitLateReturnReversalTest {

    private static Payment__c allocatedEzidebitPayment() {
        for (Payment__c p : [
            SELECT Id, Agreement__c, Agreement__r.Contract_No__c, Payment_Date__c, Actual_Amount__c,
                   (SELECT Scheduled_Payment__c, Actual_Amount__c FROM Payment_Allocation__r WHERE Actual_Amount__c > 0)
            FROM Payment__c
            WHERE RecordTypeId = :PaymentUtil.RECORDTYPE_ID_EZIDEBIT AND Agreement__c != null AND Reversed_By__c = null
              AND Actual_Amount__c > 0 AND Payment_Date__c != null AND Late_Returned__c = false AND Ezidebit_Payment_ID__c = null
            ORDER BY Payment_Date__c DESC LIMIT 20
        ]) {
            if (!p.Payment_Allocation__r.isEmpty()) {
                return p;
            }
        }
        return null;
    }

    private static Map<Id, Decimal> paidBySp(Payment__c p) {
        Set<Id> spIds = new Set<Id>();
        for (Payment_Allocation__c a : p.Payment_Allocation__r) {
            spIds.add(a.Scheduled_Payment__c);
        }
        Map<Id, Decimal> out = new Map<Id, Decimal>();
        for (Scheduled_Payment__c sp : [SELECT Id, Paid_Amount__c FROM Scheduled_Payment__c WHERE Id IN :spIds]) {
            out.put(sp.Id, sp.Paid_Amount__c == null ? 0 : sp.Paid_Amount__c);
        }
        return out;
    }

    @isTest
    static void dryRunChangesNothingThenReversalMirrorsTheAllocations() {
        Payment__c p = allocatedEzidebitPayment();
        if (p == null) {
            return; // no allocated Ezidebit payment in this org
        }
        Decimal allocated = 0;
        Map<Id, Decimal> spAllocated = new Map<Id, Decimal>();
        for (Payment_Allocation__c a : p.Payment_Allocation__r) {
            allocated += a.Actual_Amount__c;
            spAllocated.put(a.Scheduled_Payment__c, (spAllocated.containsKey(a.Scheduled_Payment__c) ? spAllocated.get(a.Scheduled_Payment__c) : 0) + a.Actual_Amount__c);
        }
        Map<Id, Decimal> paidBefore = paidBySp(p);
        Date returnedOn = p.Payment_Date__c.addDays(5);
        List<EzidebitLateReturnReversal.Request> req = new List<EzidebitLateReturnReversal.Request>{
            new EzidebitLateReturnReversal.Request(p.Id, returnedOn, EzidebitLateReturnReversal.REASON_LATE_RETURN, 'Late Return - Refer to customer')
        };

        List<EzidebitLateReturnReversal.Row> dry = EzidebitLateReturnReversal.reverse(req, false);
        System.assertEquals('Would reverse', dry[0].outcome);
        System.assertEquals(allocated, dry[0].allocatedAmount);
        System.assertEquals(null, [SELECT Reversed_By__c FROM Payment__c WHERE Id = :p.Id].Reversed_By__c, 'a dry run changes nothing');
        System.assert(EzidebitLateReturnReversal.toCsv(dry).contains('Would reverse'));

        Test.startTest();
        List<EzidebitLateReturnReversal.Row> done = EzidebitLateReturnReversal.reverse(req, true);
        Test.stopTest();

        System.assertEquals('Reversed', done[0].outcome, done[0].outcome);
        Payment__c original = [SELECT Reversed_By__c, Late_Returned__c, Late_Returned_Date__c FROM Payment__c WHERE Id = :p.Id];
        System.assertEquals(done[0].reversalPaymentId, original.Reversed_By__c);
        System.assert(original.Late_Returned__c);
        System.assertEquals(returnedOn, original.Late_Returned_Date__c);

        Payment__c rev = [
            SELECT Actual_Amount__c, RecordTypeId, Agreement__c, Payment_Date__c, Notes__c,
                   (SELECT Scheduled_Payment__c, Actual_Amount__c FROM Payment_Allocation__r)
            FROM Payment__c WHERE Id = :original.Reversed_By__c
        ];
        System.assertEquals(-allocated, rev.Actual_Amount__c);
        System.assertEquals(PaymentUtil.RECORDTYPE_ID_CASH, rev.RecordTypeId);
        System.assertEquals(null, rev.Agreement__c, 'like a manual reversal, so the trigger allocates nothing itself');
        System.assertEquals(returnedOn, rev.Payment_Date__c);
        System.assert(rev.Notes__c.startsWith('Late return: reverses '));
        Decimal reversedTotal = 0;
        for (Payment_Allocation__c a : rev.Payment_Allocation__r) {
            reversedTotal += a.Actual_Amount__c;
        }
        System.assertEquals(-allocated, reversedTotal, 'one negative allocation for each original one');

        Map<Id, Decimal> paidAfter = paidBySp(p);
        for (Id spId : spAllocated.keySet()) {
            System.assertEquals(paidBefore.get(spId) - spAllocated.get(spId), paidAfter.get(spId), 'the instalment no longer counts the payment');
        }

        System.assertEquals('Already reversed', EzidebitLateReturnReversal.reverse(req, true)[0].outcome, 'never reversed twice');
    }

    @isTest
    static void unknownAndEmptyRequests() {
        System.assertEquals(0, EzidebitLateReturnReversal.reverse(null, true).size());
        Payment__c p = allocatedEzidebitPayment();
        if (p == null) {
            return;
        }
        Id missing = p.Id;
        delete [SELECT Id FROM Payment_Allocation__c WHERE Payment__c = :p.Id];
        List<EzidebitLateReturnReversal.Row> rows = EzidebitLateReturnReversal.reverse(new List<EzidebitLateReturnReversal.Request>{
            new EzidebitLateReturnReversal.Request(missing, null, EzidebitLateReturnReversal.REASON_DUPLICATE, null)
        }, true);
        System.assertEquals('Nothing allocated', rows[0].outcome);
        System.assertEquals(Date.today(), rows[0].reversalDate);
    }

    @isTest
    static void nightlyLateReturnIsReversedWhenSwitchedOn() {
        Payment__c p = allocatedEzidebitPayment();
        if (p == null) {
            return;
        }
        insert new Ezidebit_Sync_Settings__c(SetupOwnerId = UserInfo.getUserId(), Disable_Late_Return_Flag__c = false, Reverse_Late_Returns__c = true);
        EzidebitAPI.Payment lr = new EzidebitAPI.Payment();
        lr.PaymentID = 'T-REV-LR';
        lr.PaymentStatus = 'D';
        lr.YourSystemReference = p.Agreement__r.Contract_No__c;
        lr.EzidebitCustomerID = 'ET-REV-LR';
        lr.DebitDate = Datetime.newInstance(p.Payment_Date__c.year(), p.Payment_Date__c.month(), p.Payment_Date__c.day());
        lr.SettlementDate = lr.DebitDate.addDays(4);
        lr.ScheduledAmount = p.Actual_Amount__c.doubleValue();
        lr.PaymentAmount = -p.Actual_Amount__c.doubleValue();
        lr.TransactionFeeClient = 0;
        lr.TransactionFeeCustomer = 0;
        lr.PaymentMethod = 'DR';
        lr.PaymentSource = 'SCHEDULED';
        lr.BankReturnCode = '6';
        lr.BankFailedReason = 'Late Return - Refer to customer';

        Test.startTest();
        EzidebitDishonourService.capture(new List<EzidebitAPI.Payment>{ lr }, null);
        Test.stopTest();

        Payment__c after = [SELECT Reversed_By__c, Late_Returned__c FROM Payment__c WHERE Id = :p.Id];
        System.assertNotEquals(null, after.Reversed_By__c, 'the late return reversed the payment');
        System.assert(after.Late_Returned__c);
    }

    @isTest
    static void dailyReportListsTheDaysReversals() {
        Datetime since = System.now().addMinutes(-5);
        Payment__c p = allocatedEzidebitPayment();
        if (p != null) {
            EzidebitLateReturnReversal.reverse(new List<EzidebitLateReturnReversal.Request>{
                new EzidebitLateReturnReversal.Request(p.Id, Date.today(), EzidebitLateReturnReversal.REASON_LATE_RETURN, null)
            }, true);
        }
        Messaging.SingleEmailMessage mail = EzidebitReversalDailyReport.buildEmail(since);
        if (p != null) {
            System.assert(mail.getSubject().contains('1 payment'), mail.getSubject());
            System.assert(mail.getHtmlBody().contains('taken back by the bank'), 'explains the reason');
        } else {
            System.assert(mail.getSubject().contains('none'), mail.getSubject());
        }

        insert new Ezidebit_Sync_Settings__c(SetupOwnerId = UserInfo.getUserId(), Reversal_Report_Recipients__c = 'finance@example.com; ops@example.com');
        System.assertEquals(new List<String>{ 'finance@example.com', 'ops@example.com' }, EzidebitReversalDailyReport.recipients());

        Test.startTest();
        new EzidebitReversalDailyReport().execute(null);
        Test.stopTest();
        System.assertEquals(0, [SELECT COUNT() FROM ErrorLog__c WHERE MethodName__c = 'send' AND CreatedDate >= :since AND CreatedById = :UserInfo.getUserId()], 'the email was sent without an error');
    }
}
