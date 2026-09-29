/** SeeAllData: an existing credit contract whose customer has no other involvement (AFCA, bankruptcy...). */
@isTest(SeeAllData = true)
private class HardshipRequestServiceTest {

    private static Opportunity agreement() {
        List<Opportunity> opps = [
            SELECT Id, AccountId FROM Opportunity
            WHERE Is_Credit_Contract__c = true AND AccountId != null
              AND (Account.Involvement_Type__c = null OR Account.Involvement_Type__c = 'Hardship Request')
            LIMIT 1
        ];
        return opps.isEmpty() ? null : opps[0];
    }

    @isTest
    static void lifecycle_keepsTheCustomersIdrFieldsInStep() {
        Opportunity opp = agreement();
        if (opp == null) {
            return;
        }
        Hardship_Request__c r = new Hardship_Request__c(Opportunity__c = opp.Id, Received_Date__c = Date.today(),
            Channel__c = 'Phone', Reason__c = 'Illness or injury', Change_Requested__c = 'Pause payments');
        Test.startTest();
        insert r;
        Account a = [SELECT Involvement_Type__c, Involvement_Stage__c, Is_IDR__c, IDR_Start_Date__c FROM Account WHERE Id = :opp.AccountId];
        System.assertEquals('Hardship Request', a.Involvement_Type__c);
        System.assertEquals('Received', a.Involvement_Stage__c);
        System.assert(a.Is_IDR__c, 'collections contact pauses while the request is open');
        System.assertEquals(opp.AccountId, [SELECT Account__c FROM Hardship_Request__c WHERE Id = :r.Id].Account__c, 'customer filled from the agreement');

        r.Status__c = 'Agreed';
        r.Agreed_Change__c = 'Payments paused';
        r.Change_Start_Date__c = Date.today();
        r.Change_End_Date__c = Date.today().addDays(60);
        r.Decision_Date__c = Date.today();
        update r;
        a = [SELECT Involvement_Stage__c, IDR_End_Date__c, Is_IDR__c FROM Account WHERE Id = :opp.AccountId];
        System.assertEquals('Assessed', a.Involvement_Stage__c, 'assessed hardship: Is_in_Hardship__c stops interest on payments');
        System.assertEquals(Date.today().addDays(60), a.IDR_End_Date__c);

        Hardship_Request__c r2 = [SELECT Decision_Due_Date__c, Particulars_Notice_Due_Date__c, Is_Open__c FROM Hardship_Request__c WHERE Id = :r.Id];
        System.assertEquals(Date.today().addDays(21), r2.Decision_Due_Date__c);
        System.assertEquals(null, r2.Particulars_Notice_Due_Date__c, '90 days or less: no particulars notice (s73(1A))');
        System.assertEquals(false, r2.Is_Open__c);
        Test.stopTest();
    }

    @isTest
    static void declining_needsReasons_andEndsTheHold() {
        Opportunity opp = agreement();
        if (opp == null) {
            return;
        }
        Hardship_Request__c r = new Hardship_Request__c(Opportunity__c = opp.Id, Received_Date__c = Date.today().addDays(-5));
        insert r;
        r.Status__c = 'Declined';
        r.Decision_Date__c = Date.today();
        try {
            update r;
            System.assert(false, 'a decline without reasons must be refused');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('reasons'));
        }
        r.Decline_Reasons__c = 'Income does not support a change.';
        Test.startTest();
        update r;
        Test.stopTest();
        Account a = [SELECT Involvement_Stage__c, Is_IDR__c FROM Account WHERE Id = :opp.AccountId];
        System.assertEquals('Closed', a.Involvement_Stage__c);
        System.assertEquals(false, a.Is_IDR__c);
    }

    @isTest
    static void deadlines_followSection72() {
        Opportunity opp = agreement();
        if (opp == null) {
            return;
        }
        Date received = Date.today().addDays(-10);
        Hardship_Request__c r = new Hardship_Request__c(Opportunity__c = opp.Id, Received_Date__c = received,
            Status__c = 'Information requested', Information_Requested_Date__c = received.addDays(3));
        insert r;
        Hardship_Request__c q = [SELECT Information_Due_Date__c, Decision_Due_Date__c FROM Hardship_Request__c WHERE Id = :r.Id];
        System.assertEquals(received.addDays(24), q.Information_Due_Date__c);
        System.assertEquals(received.addDays(31), q.Decision_Due_Date__c, 'no information yet: 28 days after asking');
        r.Information_Received_Date__c = received.addDays(8);
        update r;
        System.assertEquals(received.addDays(29), [SELECT Decision_Due_Date__c FROM Hardship_Request__c WHERE Id = :r.Id].Decision_Due_Date__c,
            'information received: 21 days after it arrived');
        r.Information_Requested_Date__c = received.addDays(25);
        try {
            update r;
            System.assert(false, 'asking for information after 21 days is refused');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('21 days'));
        }
    }

    @isTest
    static void accountFor_mapsEachStatus() {
        Id acctId = [SELECT Id FROM Account LIMIT 1].Id;
        Hardship_Request__c r = new Hardship_Request__c(Status__c = 'Withdrawn', Received_Date__c = Date.today());
        System.assertEquals(false, HardshipRequestService.accountFor(r, acctId).Is_IDR__c);
        r.Status__c = 'Assessing';
        System.assertEquals('Received', HardshipRequestService.accountFor(r, acctId).Involvement_Stage__c);
        insert new Collections_Settings__c(SetupOwnerId = UserInfo.getUserId(), Disable_Hardship_Account_Sync__c = true);
        HardshipRequestService.syncAccountsSafely(new List<Hardship_Request__c>{ r }); // switched off: nothing happens
    }
}
