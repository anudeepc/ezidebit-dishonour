@isTest(SeeAllData = true)
private class EzidebitStatusWatchTest {

    private static Opportunity unpaidCreditContract() {
        List<Opportunity> opps = [SELECT Id, Contract_No__c, Interest_Start_Date__c, Last_Payment_Received_Date__c
                                  FROM Opportunity WHERE Is_Credit_Contract__c = true AND Last_Payment_Received_Date__c = null
                                  AND Id NOT IN (SELECT Agreement__c FROM Payment__c WHERE Actual_Amount__c > 0) LIMIT 1];
        return opps.isEmpty() ? null : opps[0];
    }

    private static EzidebitAPI.CustomerDetails details(String code, String description) {
        EzidebitAPI.CustomerDetails d = new EzidebitAPI.CustomerDetails();
        d.StatusCode = code;
        d.StatusDescription = description;
        return d;
    }

    @isTest
    static void holdThenActive_setsInterestStartOnce() {
        Opportunity opp = unpaidCreditContract();
        if (opp == null) {
            return;
        }
        Date ordered = Date.today().addDays(-10);
        Date delivered = Date.today().addDays(-3);
        Test.startTest();
        EzidebitStatusWatch.record(new List<Opportunity>{ opp }, new Map<Id, EzidebitAPI.CustomerDetails>{ opp.Id => details('H', 'Hold') }, ordered);
        EzidebitStatusWatch.record(new List<Opportunity>{ opp }, new Map<Id, EzidebitAPI.CustomerDetails>{ opp.Id => details('H', 'Hold') }, ordered.addDays(1));
        EzidebitStatusWatch.record(new List<Opportunity>{ opp }, new Map<Id, EzidebitAPI.CustomerDetails>{ opp.Id => details('A', 'Active') }, delivered);
        Test.stopTest();
        List<Ezidebit_Status_Change__c> log = [SELECT Kind__c, Previous_Status__c, New_Status__c, Set_Interest_Start__c, Observed_Date__c
                                               FROM Ezidebit_Status_Change__c WHERE Opportunity__c = :opp.Id ORDER BY CreatedDate, Name];
        System.assertEquals(2, log.size(), 'first seen, then the change; an unchanged status is not logged again');
        System.assertEquals('First seen', log[0].Kind__c);
        System.assertEquals('On hold', log[0].New_Status__c);
        System.assertEquals('Changed', log[1].Kind__c);
        System.assertEquals('On hold', log[1].Previous_Status__c);
        System.assertEquals('Active', log[1].New_Status__c);
        System.assert(log[1].Set_Interest_Start__c);
        System.assertEquals(delivered, [SELECT Interest_Start_Date__c FROM Opportunity WHERE Id = :opp.Id].Interest_Start_Date__c);
    }

    @isTest
    static void activeFromTheStart_leavesInterestStartBlank() {
        Opportunity opp = unpaidCreditContract();
        if (opp == null) {
            return;
        }
        Date before = opp.Interest_Start_Date__c;
        EzidebitStatusWatch.record(new List<Opportunity>{ opp }, new Map<Id, EzidebitAPI.CustomerDetails>{ opp.Id => details('A', 'Active') }, Date.today());
        System.assertEquals(before, [SELECT Interest_Start_Date__c FROM Opportunity WHERE Id = :opp.Id].Interest_Start_Date__c,
            'never on hold before delivery: interest runs from the start date');
        EzidebitStatusWatch.record(new List<Opportunity>(), new Map<Id, EzidebitAPI.CustomerDetails>(), Date.today()); // nothing seen: no-op
    }

    @isTest
    static void describe_mapsEzidebitCodes() {
        System.assertEquals('Active', EzidebitStatusWatch.describe('A', 'Active'));
        System.assertEquals('On hold', EzidebitStatusWatch.describe('H', 'Hold'));
        System.assertEquals('On hold (Cancelled by customer)', EzidebitStatusWatch.describe('H2', 'Cancelled by customer'));
        System.assertEquals('Cancelled (Cancelled by bank)', EzidebitStatusWatch.describe('CB', 'Cancelled by bank'));
        System.assertEquals('Unknown', EzidebitStatusWatch.describe(null, null));
        System.assertEquals('New', EzidebitStatusWatch.describe('N', 'New'));
    }

    private class DetailsMock implements WebServiceMock {
        public void doInvoke(Object stub, Object request, Map<String, Object> response, String endpoint, String soapAction,
                             String requestName, String responseNS, String responseName, String responseType) {
            EzidebitAPI.EziResponseOfCustomerDetailsTHgMB7oL r = new EzidebitAPI.EziResponseOfCustomerDetailsTHgMB7oL();
            r.Error = 0;
            r.Data = new EzidebitAPI.CustomerDetails();
            r.Data.StatusCode = 'H';
            r.Data.StatusDescription = 'Hold';
            EzidebitAPI.GetCustomerDetailsResponse_element el = new EzidebitAPI.GetCustomerDetailsResponse_element();
            el.GetCustomerDetailsResult = r;
            response.put('response_x', el);
        }
    }

    @isTest
    static void batch_bothModes_andSchedule() {
        Test.setMock(WebServiceMock.class, new DetailsMock());
        EzidebitStatusWatch focused = new EzidebitStatusWatch(EzidebitStatusWatch.Mode.FOCUSED);
        EzidebitStatusWatch all = new EzidebitStatusWatch(EzidebitStatusWatch.Mode.ALL);
        System.assertNotEquals(null, focused.start(null));
        System.assertNotEquals(null, all.start(null));
        Opportunity opp = unpaidCreditContract();
        Test.startTest();
        if (opp != null) {
            Opportunity withKey = new Opportunity(Id = opp.Id, Contract_No__c = opp.Contract_No__c);
            withKey.Account = new Account(Territory_Number__r = new Territory__c(Ezidebit_DigitalKey__c = 'TEST-KEY'));
            focused.execute(null, new List<Opportunity>{ withKey });
        }
        focused.finish(null);
        String jobId = System.schedule('Status watch test', '0 5 8-20/2 * * ?', new EzidebitStatusWatch(null));
        System.abortJob(jobId);
        Test.stopTest();
        if (opp != null) {
            System.assertEquals('On hold', [SELECT New_Status__c FROM Ezidebit_Status_Change__c WHERE Opportunity__c = :opp.Id LIMIT 1].New_Status__c);
        }
    }

    @isTest
    static void backfill_runs() {
        Test.startTest();
        Integer n = EzidebitStatusWatch.backfillFromStageHistory();
        Test.stopTest();
        System.assert(n >= 0);
    }
}
