@IsTest(SeeAllData=true)
private class GoogleChartsPaymentControllerTest{
 static Account applicant;
  static Account applicant2;
  static Opportunity contract1;
  static Opportunity contract2;
  static Territory__c territory;
  static Payment__c paymentCRN;
  static Payment__c paymentERN;
   static final String STAGE_CREATE_PAYMENTS = 'Goods Delivered';
   static List<Scheduled_Payment__c> sps;
   static List<Payment_Allocation__c> payAllocations;
     static void createTestData() {
    territory = [
            SELECT
                Id,
                Name,
                Short_Name__c
            FROM
                Territory__c
            WHERE
                Applicant_Customer_Prefix__c = 'GRN' limit 1
        ];
        System.debug('###territory: ' + territory.Id);
        
    RecordType personAccountRecordType = [SELECT Id, Name FROM RecordType WHERE SobjectType = 'Account' AND IsPersonType = true AND Name = 'Applicant' limit 1];
    applicant = new Account(
        RecordTypeId = personAccountRecordType.Id,
      Salutation = 'Mr.',
      FirstName = 'UnitTest',
      LastName = 'Applicant 1',
      Centrepay_Ref_No__c = 'xxxxxxxxxx',
      Ezidebit_Ref_No__c = null, 
      Customer_No__c = 'xxxxxxxx',
      Territory_Number__c = territory.Id
    );
    insert applicant;
    
    applicant2 = new Account(
        RecordTypeId = personAccountRecordType.Id,
      Salutation = 'Mr.',
      FirstName = 'UnitTest',
      LastName = 'Applicant 2',
      Ezidebit_Ref_No__c = '1234568',
      Customer_No__c = 'xxxxxxxz',
      Territory_Number__c = territory.Id
    );
    insert applicant2;
    
    contract1 = new Opportunity(
      Name = 'UnitTest - Contract Number Test 1',
      AccountId = applicant.Id,
      Applicant2__c=applicant2.Id,
      StageName = STAGE_CREATE_PAYMENTS,
      Start_Date__c = Date.today(),
      CloseDate = Date.today().addMonths(12),
      Term_Months__c = '12',
      Payment_Frequency__c = 'Fortnightly',
      Scheduled_Amount__c = 100,
      Amount=1000,
      Is_Active__c = true
    );
    insert contract1;
    
    Payment_File__c paymentFile = new Payment_File__c(
        File_Name__c = 'Unit Test Centrepay payments',
        File_Upload_Date__c = datetime.now()
      );
      insert paymentFile;
      
       paymentCRN = new Payment__c(
          Payment_File__c = paymentFile.Id,
          RecordTypeId    = PaymentUtil.RECORDTYPE_ID_CENTREPAY,
          Customer_Name__c = 'UnitTest Applicant 1',
          Scheduled_Amount__c = 100,
          Actual_Amount__c = 99.01,
          Effective_Date__c = Date.today().addDays(14),
          Payment_Date__c = Date.today().addDays(14),
          Centrelink_Ref_No__c = 'xxxxxxxxxx',
          Fee_Amount__c = 0.99,
          Lodgement_Prefix_Ref_No__c = 'xxxxxxxx',
          Applicantlookup__c=applicant.Id
        );
        insert paymentCRN;
        
        sps = new List<Scheduled_Payment__c>{
        new Scheduled_Payment__c(
          Opportunity__c = contract1.Id,
          Scheduled_Amount__c = 100,
          Scheduled_Date__c = Date.today()
        ),
        new Scheduled_Payment__c(
          Opportunity__c = contract1.Id,
          Scheduled_Amount__c = 100,
          Scheduled_Date__c = Date.today().addDays(14)
        ),
        new Scheduled_Payment__c(
          Opportunity__c = contract1.Id,
          Scheduled_Amount__c = 100,
          Scheduled_Date__c = Date.today().addDays(28)
        )
        };
        insert sps;
        
        payAllocations = new List<Payment_Allocation__c>{
        new Payment_Allocation__c(
          Actual_Amount__c = 100,
          Contract__c = contract1.Id,
          RecordTypeId = Util.getRecordTypeInfosByDeveloperName('Payment_Allocation__c').get('Centrepay').Id,
          Payment__c=paymentCRN.Id,
          Scheduled_Payment__c=sps[0].Id,
          Payment_Date__c = Date.today()
        )
        };
        insert payAllocations;
  }
  
    static testmethod void testGoogleChartsPayment() {
      
      Test.startTest();
      
      createTestData();
      PageReference pageRef = Page.GoogleChartsAgreementPaymentStatusPage;
      Test.setCurrentPage(pageRef);
      
      System.debug('applicantId: '+applicant.Id+' contractTestId: '+contract1.Id+' contractTestAccount: '+contract1.AccountId + ' contractTestActive: '+contract1.Is_Active__c);
      
      ApexPages.currentPage().getParameters().put('id',applicant.id);
      
      GoogleChartsPaymentController gc = new GoogleChartsPaymentController();
      //GoogleChartsPaymentController.MyWrapper wrap2 = new ManualPaymentAllocationController.MyWrapper(contract1.Id,contract1.Name,100,200,100,10,'Goods Delivered');
      //List<ManualPaymentAllocationController.MyWrapper>  list1 =new List<ManualPaymentAllocationController.MyWrapper>();
      //list1.add(wrap2);
      
      gc.GetDataToCreateChartsInAgreement();

      
      Test.stopTest();  
    }
    
    
    static testmethod void testGoogleChartsPaymentReport() {
      
      Test.startTest();
      
      createTestData();
      PageReference pageRef = Page.NewPaymentStatementPage;
      Test.setCurrentPage(pageRef);
      
      System.debug('applicantId: '+applicant.Id+' contractTestId: '+contract1.Id+' contractTestAccount: '+contract1.AccountId + ' contractTestActive: '+contract1.Is_Active__c);
      
      ApexPages.currentPage().getParameters().put('oppId',contract1.id);
      
      GoogleChartsPaymentController gc = new GoogleChartsPaymentController();
      //GoogleChartsPaymentController.MyWrapper wrap2 = new ManualPaymentAllocationController.MyWrapper(contract1.Id,contract1.Name,100,200,100,10,'Goods Delivered');
      //List<ManualPaymentAllocationController.MyWrapper>  list1 =new List<ManualPaymentAllocationController.MyWrapper>();
      //list1.add(wrap2);
      
      gc.GetPaymentAllocations();
      gc.GetPaymentAllocationsNZ();
      
      Test.stopTest();  
    }
    
    static testmethod void testGoogleChartsPaymentReportDateWise() {
      
      Test.startTest();
      
      createTestData();
      PageReference pageRef = Page.NewPaymentStatementPage;
      Test.setCurrentPage(pageRef);
      
      System.debug('applicantId: '+applicant.Id+' contractTestId: '+contract1.Id+' contractTestAccount: '+contract1.AccountId + ' contractTestActive: '+contract1.Is_Active__c);
      
      ApexPages.currentPage().getParameters().put('oppId',contract1.id);
      
      GoogleChartsPaymentController gc = new GoogleChartsPaymentController();
      
      gc.GetPaymentAllocationsDateWise();
      
      Test.stopTest();  
    }
    
    static testmethod void testCreditContract() 
    {
        Test.startTest();
        List<Opportunity> oppList = [SELECT Id FROM Opportunity WHERE Is_Credit_Contract__c = true AND Account.Territory_State__c = 'NZ' AND Total_Paid_Amount__c > 0 LIMIT 1];
        if(oppList.size() > 0){
            ApexPages.currentPage().getParameters().put('oppId',oppList[0].Id);
            GoogleChartsPaymentController gc = new GoogleChartsPaymentController();
            gc.initAgreementStatement();
        }
        Test.stopTest();  
    }
    
    static testmethod void testArchivedPaymentStatement() 
    {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new OwnArchiveCalloutMock('paymentsFromOpportunity', 200));
        List<Opportunity> oppList = [SELECT Id FROM Opportunity WHERE Is_Credit_Contract__c = false AND Account.Territory_State__c != 'NZ' AND Total_Paid_Amount_Archived__c > 0 ORDER BY CreatedDate DESC LIMIT 1];
        if(oppList.size() > 0){
            ApexPages.currentPage().getParameters().put('oppId',oppList[0].Id);
            GoogleChartsPaymentController gc = new GoogleChartsPaymentController();
            gc.getArchivedPaymentAllocationsCL();
        }
        Test.stopTest();  
    }
   
    static testmethod void testSendEarlyPayoutStatement() 
    {
        Test.startTest();
        List<Opportunity> oppList = [SELECT Id 
                                      FROM Opportunity WHERE 
                                      Is_Credit_Contract__c = true AND 
                                      Account.Territory_State__c != 'NZ' AND 
                                      Remaining_Amount__c > 0 AND
                                      Final_Payout_Figure__c > 0 AND
                                      Account.PersonEmail != null
                                      ORDER BY CreatedDate DESC LIMIT 1];
        if(oppList.size() > 0){
            ApexPages.currentPage().getParameters().put('oppId',oppList[0].Id);
            GoogleChartsPaymentController gc = new GoogleChartsPaymentController();
			gc.initEarlyPayoutStatement();
            // The statement's lines add up to the payout figure: balance + unpaid interest + accrued interest.
            System.assert(Math.abs(gc.adjustedAmountBorrowed + gc.unpaidInterest + gc.accruedInterest - gc.opportunity.Final_Payout_Figure__c) <= 0.02,
                'payout breakdown adds up');
            gc.sendEarlyPayoutStatement();
            gc.proceedToPayout();
        }
        Test.stopTest();  
    }

	@isTest
	static void testAddBankTransfer(){
		Test.startTest();
        List<Opportunity> oppList = [SELECT Id,Contract_No__c,Final_Payout_Figure__c 
                                      FROM Opportunity WHERE 
                                      Is_Credit_Contract__c = true AND 
                                      Account.Territory_State__c != 'NZ' AND 
                                      Remaining_Amount__c > 0 AND
                                      Final_Payout_Figure__c > 0 AND
                                      Account.PersonEmail != null
                                      ORDER BY CreatedDate DESC LIMIT 1];
        if(oppList.size() > 0){
            ApexPages.currentPage().getParameters().put('oppId',oppList[0].Id);
			ApexPages.currentPage().getParameters().put('pmtRef',oppList[0].Contract_No__c + 'EPF');
			ApexPages.currentPage().getParameters().put('transactionId',oppList[0].Contract_No__c);
			ApexPages.currentPage().getParameters().put('pmtDate','24/05/2024');
			ApexPages.currentPage().getParameters().put('pmtAmt','20000');
            GoogleChartsPaymentController gc = new GoogleChartsPaymentController();
			gc.initEarlyPayoutStatement();
            gc.addBankTransferPayment();
			gc.searchCreditContract();
        }
        Test.stopTest();
	}
}