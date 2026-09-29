@isTest(SeeAllData = true)
private class EzidebitPaymentHistoryControllerTest {

    @isTest
    static void history_mergesPaymentsAndDishonoursNewestFirst() {
        List<Payment__c> pays = [
            SELECT Agreement__c, Agreement__r.Contract_No__c FROM Payment__c
            WHERE Agreement__c != null AND Agreement__r.Contract_No__c != null AND Payment_Date__c != null LIMIT 1
        ];
        if (pays.isEmpty()) {
            return;
        }
        Id oppId = pays[0].Agreement__c;
        EzidebitAPI.Payment p = new EzidebitAPI.Payment();
        p.PaymentID = 'T-HIST';
        p.PaymentStatus = 'D';
        p.YourSystemReference = pays[0].Agreement__r.Contract_No__c;
        p.DebitDate = Datetime.now().addDays(-1);
        p.SettlementDate = Datetime.now();
        p.PaymentAmount = 48.21;
        p.ScheduledAmount = 48.21;
        p.TransactionFeeClient = 2.75;
        p.PaymentSource = 'SCHEDULED';
        p.BankFailedReason = 'Refer to customer';
        EzidebitDishonourService.capture(new List<EzidebitAPI.Payment>{ p }, null);

        User viewer = staffUser();
        EzidebitPaymentHistoryController.History h;
        Test.startTest();
        System.runAs(viewer) {
            h = EzidebitPaymentHistoryController.getHistory(oppId);
        }
        Test.stopTest();

        System.assert(h.failedCount >= 1, 'the failed debit is counted');
        System.assert(h.paidCount >= 1, 'the existing payment is counted');
        Boolean hasFailure = false;
        for (Integer i = 0; i < h.rows.size(); i++) {
            hasFailure |= h.rows[i].result == 'Failed';
            if (i > 0 && h.rows[i].eventDate != null && h.rows[i - 1].eventDate != null) {
                System.assert(h.rows[i - 1].eventDate >= h.rows[i].eventDate, 'newest first');
            }
        }
        System.assert(hasFailure, 'the failed debit is in the history');
        System.assert(h.ezidebitFees >= 2.75, 'fees include the dishonour fee');
        System.assertEquals(0, EzidebitPaymentHistoryController.getHistory(null).rows.size());
    }

    // The component shows only what the viewer can read: an administrator with the permission set staff get.
    private static User staffUser() {
        Profile admin = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User u = new User(Alias = 'ezstaff', Email = 'ezstaff@example.invalid', EmailEncodingKey = 'UTF-8', LastName = 'Staff',
            LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_AU', ProfileId = admin.Id, TimeZoneSidKey = 'Australia/Sydney',
            UserName = 'ezstaff' + System.currentTimeMillis() + '@example.invalid');
        // Setup-object DML in its own runAs context, so it doesn't mix with the test's record DML.
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert u;
            insert new PermissionSetAssignment(AssigneeId = u.Id,
                PermissionSetId = [SELECT Id FROM PermissionSet WHERE Name = 'Ezidebit_Dishonour_Access' LIMIT 1].Id);
        }
        return u;
    }

    @isTest
    static void history_withoutDishonourAccessStillShowsPayments() {
        Profile readOnly = [SELECT Id FROM Profile WHERE Name IN ('Read Only', 'Standard User') ORDER BY Name LIMIT 1];
        User u = new User(Alias = 'ezhist', Email = 'ezhist@example.invalid', EmailEncodingKey = 'UTF-8', LastName = 'History',
            LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_AU', ProfileId = readOnly.Id, TimeZoneSidKey = 'Australia/Sydney',
            UserName = 'ezhist' + System.currentTimeMillis() + '@example.invalid');
        insert u;
        List<Payment__c> pays = [SELECT Agreement__c FROM Payment__c WHERE Agreement__c != null LIMIT 1];
        System.runAs(u) {
            EzidebitPaymentHistoryController.History h = EzidebitPaymentHistoryController.getHistory(pays.isEmpty() ? null : pays[0].Agreement__c);
            System.assertEquals(0, h.failedCount, 'no Dishonour access: failures are left out, not an error');
            System.assertEquals(false, h.showEzidebitFees, 'the Ezidebit fee is R4K\'s cost: hidden without Dishonour access');
            System.assertEquals(0, h.ezidebitFees);
            for (EzidebitPaymentHistoryController.Row r : h.rows) {
                System.assertEquals(null, r.ezidebitFee);
            }
        }
    }
}