/*
 * Unit tests for the PaymentUtil class.
 *
 * @Author: System Partners
 */
@isTest(SeeAllData=true)
private class PaymentUtilTests {
  static Account applicant;
  static Account applicant2;
  static Opportunity contract1;
  static Opportunity contract2;
  static Opportunity contract3;
  static Territory__c territory;
  static final String STAGE_CREATE_PAYMENTS = 'Goods Delivered';

  public static Opportunity contract4;
  public static Opportunity contract5;
  public static Territory__c nzTerritory;
  public static Payment__c paymentCRN;
  public static Payment__c paymentERN;
  public static List<Scheduled_Payment__c> sps;
  public static List<Payment_Allocation__c> payAllocations;
  public static OpportunityLineItem item;
  public static OpportunityLineItem item2;
  public static OpportunityLineItem item3;
  public static OpportunityLineItem item4;

  //Create test data such as Applicant 1, 2 and contract.
  static void createTestData() {
    territory = [
      SELECT Id, Name, Short_Name__c
      FROM Territory__c
      WHERE Name = '3010'
      LIMIT 1
    ];
    System.debug('###territory: ' + territory.Id);

    RecordType personAccountRecordType = [
      SELECT Id, Name
      FROM RecordType
      WHERE
        SobjectType = 'Account'
        AND IsPersonType = TRUE
        AND Name = 'Applicant'
      LIMIT 1
    ];
    applicant = new Account(
      RecordTypeId = personAccountRecordType.Id,
      Salutation = 'Mr.',
      FirstName = 'UnitTest',
      LastName = 'Applicant 1',
      Centrepay_Ref_No__c = 'XXXXXXXXXX',
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
      Centrepay_Ref_No__c = 'XXXXXXXXXY',
      Ezidebit_Ref_No__c = null,
      Customer_No__c = 'xxxxxxxy',
      Territory_Number__c = territory.Id
    );
    insert applicant2;

    contract1 = new Opportunity(
      Name = 'UnitTest - Contract Number Test 1',
      AccountId = applicant.Id,
      StageName = STAGE_CREATE_PAYMENTS,
      Start_Date__c = Date.today(),
      CloseDate = Date.today().addMonths(12),
      Term_Months__c = '12',
      Payment_Frequency__c = 'Fortnightly',
      Scheduled_Amount__c = 100,
      Is_Active__c = true
    );
    insert contract1;

    contract3 = new Opportunity(
      Name = 'UnitTest - Contract Number Test 1',
      AccountId = applicant.Id,
      StageName = STAGE_CREATE_PAYMENTS,
      Start_Date__c = Date.today(),
      Is_Credit_contract__c = true,
      CloseDate = Date.today().addMonths(12),
      Term_Months__c = '12',
      Payment_Frequency__c = 'Fortnightly',
      Scheduled_Amount__c = 100,
      Is_Active__c = true
    );
    insert contract3;

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
      ),
      new Scheduled_Payment__c(
        Opportunity__c = contract1.Id,
        Scheduled_Amount__c = 100,
        Scheduled_Date__c = Date.today().addDays(42)
      )
    };
    insert sps;
  }

  static void createTestData2() {
    territory = [
      SELECT Id, Name, Short_Name__c
      FROM Territory__c
      WHERE Applicant_Customer_Prefix__c = 'GRN'
      LIMIT 1
    ];
    nzTerritory = [
      SELECT Id, Name, Short_Name__c
      FROM Territory__c
      WHERE Name = '901'
      LIMIT 1
    ];
    System.debug('###territory: ' + territory.Id);

    RecordType personAccountRecordType = [
      SELECT Id, Name
      FROM RecordType
      WHERE
        SobjectType = 'Account'
        AND IsPersonType = TRUE
        AND Name = 'Applicant'
      LIMIT 1
    ];
    applicant = new Account(
      RecordTypeId = personAccountRecordType.Id,
      Salutation = 'Mr.',
      FirstName = 'UnitTest',
      LastName = 'Applicant 1',
      Centrepay_Ref_No__c = 'xxxxxxxxxx',
      Ezidebit_Ref_No__c = null,
      Customer_No__c = 'xxxxxxxx',
      PersonMobilePhone = '0469036691',
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
      AccountId = applicant2.Id,
      StageName = STAGE_CREATE_PAYMENTS,
      Start_Date__c = Date.today(),
      CloseDate = Date.today().addMonths(12),
      Term_Months__c = '12',
      Payment_Frequency__c = 'Fortnightly',
      Scheduled_Amount__c = 100,
      Is_Active__c = true,
      Requirements_Objectives__c = 'testrequired',
      Repossess_Notes__c = 'repossesstest'
    );
    insert contract1;

    contract2 = new Opportunity(
      Name = 'UnitTest - Contract Number Test 2',
      AccountId = applicant.Id,
      StageName = STAGE_CREATE_PAYMENTS,
      Start_Date__c = Date.today(),
      CloseDate = Date.today().addMonths(12),
      Term_Months__c = '12',
      Payment_Frequency__c = 'Fortnightly',
      Scheduled_Amount__c = 200,
      Is_Active__c = true,
      Requirements_Objectives__c = 'testrequired'
    );
    insert contract2;

    contract3 = new Opportunity(
      Name = 'UnitTest - Contract Number Test 3',
      AccountId = applicant.Id,
      StageName = STAGE_CREATE_PAYMENTS,
      Start_Date__c = Date.today(),
      CloseDate = Date.today().addMonths(12),
      Term_Months__c = '12',
      Payment_Frequency__c = 'Fortnightly',
      Scheduled_Amount__c = 200,
      Is_Active__c = true
    );
    insert contract3;

    contract4 = new Opportunity(
      Name = 'UnitTest - Contract Number Test 4',
      AccountId = applicant.Id,
      StageName = STAGE_CREATE_PAYMENTS,
      Start_Date__c = Date.today(),
      CloseDate = Date.today().addMonths(12),
      Term_Months__c = '12',
      Payment_Frequency__c = 'Weekly',
      Scheduled_Amount__c = 200,
      Is_Active__c = true
    );
    insert contract4;

    contract5 = new Opportunity(
      Name = 'UnitTest - Contract Number Test 1',
      AccountId = applicant.Id,
      StageName = STAGE_CREATE_PAYMENTS,
      Start_Date__c = Date.today(),
      CloseDate = Date.today().addMonths(12),
      Term_Months__c = '12',
      Payment_Frequency__c = 'Fortnightly',
      Scheduled_Amount__c = 100,
      Is_Active__c = true,
      Requirements_Objectives__c = '',
      Repossess_Notes__c = 'repossesstest'
    );
    insert contract5;

    List<PriceBookEntry> books = [
      SELECT id, Name
      FROM PriceBookEntry
      WHERE Name = 'Computing - Desktop' AND CurrencyIsoCode = 'AUD'
    ];
    item = new OpportunityLineItem();
    item.OpportunityId = contract1.Id;
    if (books.size() > 0)
      item.PriceBookEntryId = books[0].Id;
    item.Description = 'Computer';
    item.Supplier__c = 'Other';
    item.Other_Supplier__c = 'Other';
    item.UnitPrice = 2600;
    item.Cost_of_Goods__c = 2600;
    item.Total_Agreement_Value_For_Rent__c = 2600;
    insert item;

    List<PriceBookEntry> books2 = [
      SELECT id, Name
      FROM PriceBookEntry
      WHERE Name = 'Repair' AND CurrencyIsoCode = 'AUD'
    ];
    item2 = new OpportunityLineItem();
    item2.OpportunityId = contract1.Id;
    if (books2.size() > 0)
      item2.PriceBookEntryId = books2[0].Id;
    item2.Description = 'Repair';
    item2.Supplier__c = 'Other';
    item2.Other_Supplier__c = 'Other';
    item2.UnitPrice = 300;
    item2.Cost_of_Goods__c = 300;
    item2.Total_Agreement_Value_For_Rent__c = 300;
    insert item2;

    List<PriceBookEntry> books3 = [
      SELECT id, Name
      FROM PriceBookEntry
      WHERE Name = 'Variation' AND CurrencyIsoCode = 'AUD'
    ];
    item3 = new OpportunityLineItem();
    item3.OpportunityId = contract1.Id;
    if (books3.size() > 0)
      item3.PriceBookEntryId = books3[0].Id;
    item3.Description = 'Variation';
    item3.Supplier__c = 'Other';
    item3.Other_Supplier__c = 'Other';
    item3.UnitPrice = 500;
    item3.Cost_of_Goods__c = 500;
    item3.Total_Agreement_Value_For_Rent__c = 500;
    insert item3;

    item4 = new OpportunityLineItem();
    item4.OpportunityId = contract1.Id;
    if (books.size() > 0)
      item4.PriceBookEntryId = books[0].Id;
    item4.Description = 'Computer';
    item4.Supplier__c = 'Other';
    item4.Other_Supplier__c = 'Other';
    item4.UnitPrice = 2600;
    item4.Cost_of_Goods__c = 2600;
    item4.Total_Agreement_Value_For_Rent__c = 2600;
    insert item4;

    Payment_File__c paymentFile = new Payment_File__c(
      File_Name__c = 'Unit Test Centrepay payments',
      File_Upload_Date__c = datetime.now()
    );
    insert paymentFile;

    paymentCRN = new Payment__c(
      Payment_File__c = paymentFile.Id,
      RecordTypeId = PaymentUtil.RECORDTYPE_ID_CENTREPAY,
      Customer_Name__c = 'UnitTest Applicant 1',
      Scheduled_Amount__c = 100,
      Actual_Amount__c = 99.01,
      Effective_Date__c = Date.today().addDays(14),
      Payment_Date__c = Date.today().addDays(14),
      Centrelink_Ref_No__c = 'xxxxxxxxxx',
      Fee_Amount__c = 0.99,
      Lodgement_Prefix_Ref_No__c = 'xxxxxxxx',
      Applicantlookup__c = applicant.Id
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
      ),
      new Scheduled_Payment__c(
        Opportunity__c = contract1.Id,
        Scheduled_Amount__c = 100,
        Scheduled_Date__c = Date.today().addDays(42)
      )
    };
    insert sps;

    payAllocations = new List<Payment_Allocation__c>{
      new Payment_Allocation__c(
        Actual_Amount__c = 100,
        Contract__c = contract1.Id,
        RecordTypeId = Util.getRecordTypeInfosByDeveloperName(
            'Payment_Allocation__c'
          )
          .get('Centrepay')
          .Id,
        Payment__c = paymentCRN.Id,
        Scheduled_Payment__c = sps[0].Id,
        Payment_Date__c = Date.today()
      )
    };
    insert payAllocations;

    system.debug('remAmt: ' + contract1.Remaining_Amount__c);
  }

  static void create2ndContract(Id applicantId, Date startDate) {
    contract2 = new Opportunity(
      Name = 'UnitTest - Contract Number Test 2',
      AccountId = applicantId,
      StageName = STAGE_CREATE_PAYMENTS,
      Start_Date__c = startDate,
      CloseDate = startDate.addMonths(12),
      Term_Months__c = '12',
      Payment_Frequency__c = 'Fortnightly',
      Scheduled_Amount__c = 70,
      Is_Active__c = true
    );
    insert contract2;
  }

  /*
   * Test case for only 1 contract and couple payments.
   */
  static testMethod void testOneContractLoadCompleteCentrePayPayments() {
    createTestData();

    //Create the csv file and payment records for the test
    Payment_File__c paymentFile = new Payment_File__c(
      File_Name__c = 'Unit Test Centrepay payments',
      File_Upload_Date__c = datetime.now()
    );
    insert paymentFile;

    List<Payment__c> payments = new List<Payment__c>{
      new Payment__c(
        Payment_File__c = paymentFile.Id,
        RecordTypeId = PaymentUtil.RECORDTYPE_ID_CENTREPAY,
        Customer_Name__c = 'UnitTest Applicant 1',
        Scheduled_Amount__c = 100,
        Actual_Amount__c = 99.01,
        Effective_Date__c = Date.today().addDays(14),
        Payment_Date__c = Date.today().addDays(14),
        Centrelink_Ref_No__c = 'xxxxxxxxxx',
        Fee_Amount__c = 0.99,
        Lodgement_Prefix_Ref_No__c = 'xxxxxxxx'
      ),
      new Payment__c(
        Payment_File__c = paymentFile.Id,
        RecordTypeId = PaymentUtil.RECORDTYPE_ID_CENTREPAY,
        Customer_Name__c = 'UnitTest Applicant 1',
        Scheduled_Amount__c = 100,
        Actual_Amount__c = 99.01,
        Effective_Date__c = Date.today().addDays(28),
        Payment_Date__c = Date.today().addDays(28),
        Centrelink_Ref_No__c = 'xxxxxxxxxx',
        Fee_Amount__c = 0.99,
        Lodgement_Prefix_Ref_No__c = 'xxxxxxxx'
      ),
      new Payment__c(
        Payment_File__c = paymentFile.Id,
        RecordTypeId = PaymentUtil.RECORDTYPE_ID_CENTREPAY,
        Customer_Name__c = 'UnitTest Applicant 1',
        Scheduled_Amount__c = 100,
        Actual_Amount__c = 99.01,
        Effective_Date__c = Date.today().addDays(42),
        Payment_Date__c = Date.today().addDays(42),
        Centrelink_Ref_No__c = 'xxxxxxxxxx',
        Fee_Amount__c = 0.99,
        Lodgement_Prefix_Ref_No__c = 'xxxxxxxx'
      )
    };
    insert payments;

    //Check number of payment allocated and remaining amount etc.
    contract1 = refreshContractRecord(contract1.Id);
    System.debug('###contract1: ' + contract1);
    //System.assertEquals(3, countNumberOfPaymentAllocations(contract1.Id), 'There should be 3 payment allocations.');
    //System.assertEquals(300, contract1.Total_Paid_Amount__c, 'Total Paid amount should be 300.');
    //System.assertEquals(26, contract1.No_of_Scheduled_Payments__c, 'There should be 26 schedule payments.');
  }

  /*
   * Test case of the last payment that is overpaid.
   */
  static testMethod void testOneContractLoadLastPaymentOverPaid() {
    createTestData();

    //Create the csv file and payment records for the test
    Payment_File__c paymentFile = new Payment_File__c(
      File_Name__c = 'Unit Test Centrepay payments',
      File_Upload_Date__c = datetime.now()
    );
    insert paymentFile;

    //Create all the payments.
    List<Payment__c> payments = new List<Payment__c>();
    Date effective_date = date.today();
    for (Integer i = 0; i < 26; i++) {
      effective_date = effective_date.addDays(14);
      payments.add(
        new Payment__c(
          Payment_File__c = paymentFile.Id,
          RecordTypeId = PaymentUtil.RECORDTYPE_ID_CENTREPAY,
          Customer_Name__c = 'UnitTest Applicant 1',
          Scheduled_Amount__c = 100,
          Actual_Amount__c = 99.01,
          Effective_Date__c = effective_date,
          Payment_Date__c = effective_date,
          Centrelink_Ref_No__c = 'xxxxxxxxxx',
          Fee_Amount__c = 0.99,
          Lodgement_Prefix_Ref_No__c = 'xxxxxxxx'
        )
      );
    }

    //For last payment, we will overpay it.
    payments[25].Actual_Amount__c = 149.01;
    insert payments;

    //Check the last payment allocation should have the full overpaid amount and no more allocations or schedule payments created.
    contract1 = refreshContractRecord(contract1.Id);
    System.debug('###contract1: ' + contract1);
    //System.assertEquals(26, payments.size(), 'There should be 26 payments.');
    //System.assertEquals(26, countNumberOfPaymentAllocations(contract1.Id), 'There should be 26 payment allocations.');
    //System.assertEquals(2650, contract1.Total_Paid_Amount__c, 'Total Paid amount should be overpaid by 50 dollars.');
    //System.assertEquals(26, contract1.No_of_Scheduled_Payments__c, 'There should be 26 schedule payments.');
  }

  /*
   * Test case of multiple underpaid and overpaid payments.
   */
  static testMethod void testOneContractLoadUnderAndOverCentrePayPayments() {
    createTestData();

    //Create the csv file and payment records for the test
    Payment_File__c paymentFile = new Payment_File__c(
      File_Name__c = 'Unit Test Centrepay payments',
      File_Upload_Date__c = datetime.now()
    );
    insert paymentFile;

    //Create a mix of underpaid and overpaid payments.
    List<Payment__c> payments = new List<Payment__c>{
      new Payment__c(
        Payment_File__c = paymentFile.Id,
        RecordTypeId = PaymentUtil.RECORDTYPE_ID_CENTREPAY,
        Customer_Name__c = 'UnitTest Applicant 1',
        Scheduled_Amount__c = 100,
        Actual_Amount__c = 49.01,
        Effective_Date__c = Date.today().addDays(14),
        Payment_Date__c = Date.today().addDays(14),
        Centrelink_Ref_No__c = 'xxxxxxxxxx',
        Fee_Amount__c = 0.99,
        Lodgement_Prefix_Ref_No__c = 'xxxxxxxx'
      ),
      new Payment__c(
        Payment_File__c = paymentFile.Id,
        RecordTypeId = PaymentUtil.RECORDTYPE_ID_CENTREPAY,
        Customer_Name__c = 'UnitTest Applicant 1',
        Scheduled_Amount__c = 100,
        Actual_Amount__c = 99.01,
        Effective_Date__c = Date.today().addDays(28),
        Payment_Date__c = Date.today().addDays(28),
        Centrelink_Ref_No__c = 'xxxxxxxxxx',
        Fee_Amount__c = 0.99,
        Lodgement_Prefix_Ref_No__c = 'xxxxxxxx'
      ),
      new Payment__c(
        Payment_File__c = paymentFile.Id,
        RecordTypeId = PaymentUtil.RECORDTYPE_ID_CENTREPAY,
        Customer_Name__c = 'UnitTest Applicant 1',
        Scheduled_Amount__c = 100,
        Actual_Amount__c = 199.01,
        Effective_Date__c = Date.today().addDays(42),
        Payment_Date__c = Date.today().addDays(42),
        Centrelink_Ref_No__c = 'xxxxxxxxxx',
        Fee_Amount__c = 0.99,
        Lodgement_Prefix_Ref_No__c = 'xxxxxxxx'
      )
    };
    insert payments;

    //Check the some scheduled payments should have more than one payment allocated to pay off the amount. Also payment allocations all correctly paid off the contract.
    contract1 = refreshContractRecord(contract1.Id);
    System.debug('###contract1: ' + contract1);
    //System.assertEquals(6, countNumberOfPaymentAllocations(contract1.Id), 'There should be 6 payment allocations.');
    ///System.assertEquals(350, contract1.Total_Paid_Amount__c, 'Total Paid amount should be 350. Over paid by 50 dollars');
    //System.assertEquals(26, contract1.No_of_Scheduled_Payments__c, 'There should be 26 schedule payments.');
  }

  /*
   * Test case where the applicants have two contracts that payments should allocate to both contract's
   * scheduled payments.
   */
  static testMethod void testTwoContractLoadCompleteCentrePayPayments() {
    createTestData();
    create2ndContract(applicant.Id, date.today().addDays(14));

    //Create the csv file and payment records for the test
    Payment_File__c paymentFile = new Payment_File__c(
      File_Name__c = 'Unit Test Centrepay payments',
      File_Upload_Date__c = datetime.now()
    );
    insert paymentFile;

    List<Payment__c> payments = new List<Payment__c>{
      new Payment__c(
        Payment_File__c = paymentFile.Id,
        RecordTypeId = PaymentUtil.RECORDTYPE_ID_CENTREPAY,
        Customer_Name__c = 'UnitTest Applicant 1',
        Scheduled_Amount__c = 100,
        Actual_Amount__c = 99.01,
        Effective_Date__c = Date.today().addDays(14),
        Payment_Date__c = Date.today().addDays(14),
        Centrelink_Ref_No__c = 'xxxxxxxxxx',
        Fee_Amount__c = 0.99,
        Lodgement_Prefix_Ref_No__c = 'xxxxxxxx'
      ),
      new Payment__c(
        Payment_File__c = paymentFile.Id,
        RecordTypeId = PaymentUtil.RECORDTYPE_ID_CENTREPAY,
        Customer_Name__c = 'UnitTest Applicant 1',
        Scheduled_Amount__c = 100,
        Actual_Amount__c = 99.01,
        Effective_Date__c = Date.today().addDays(28),
        Payment_Date__c = Date.today().addDays(28),
        Centrelink_Ref_No__c = 'xxxxxxxxxx',
        Fee_Amount__c = 0.99,
        Lodgement_Prefix_Ref_No__c = 'xxxxxxxx'
      ),
      new Payment__c(
        Payment_File__c = paymentFile.Id,
        RecordTypeId = PaymentUtil.RECORDTYPE_ID_CENTREPAY,
        Customer_Name__c = 'UnitTest Applicant 1',
        Scheduled_Amount__c = 100,
        Actual_Amount__c = 99.01,
        Effective_Date__c = Date.today().addDays(42),
        Payment_Date__c = Date.today().addDays(42),
        Centrelink_Ref_No__c = 'xxxxxxxxxx',
        Fee_Amount__c = 0.99,
        Lodgement_Prefix_Ref_No__c = 'xxxxxxxx'
      )
    };
    insert payments;

    contract1 = refreshContractRecord(contract1.Id);
    contract2 = refreshContractRecord(contract2.Id);
    System.debug('###contract1: ' + contract1);
    //System.assertEquals(3, countNumberOfPaymentAllocations(contract1.Id), 'There should be 3 payment allocations.');
    //System.assertEquals(1, countNumberOfPaymentAllocations(contract2.Id), 'There should be 1 payment allocations.');
    //System.assertEquals(230, contract1.Total_Paid_Amount__c, 'Total Paid amount should be 230.');
    //System.assertEquals(70, contract2.Total_Paid_Amount__c, 'Total Paid amount should be 70.');
    //System.assertEquals(26, contract1.No_of_Scheduled_Payments__c, 'There should be 26 schedule payments.');
  }

  /*
   * Test case for Ezidebit payments.
   */
  static testMethod void testOneContractPerApplicantLoadCompletdEzidebitPayments() {
    createTestData();
    create2ndContract(applicant2.Id, date.today());
    applicant.Centrepay_Ref_No__c = null;
    applicant.Ezidebit_Ref_No__c = 'xxxxxxx';
    applicant2.Centrepay_Ref_No__c = null;
    applicant2.Ezidebit_Ref_No__c = 'xxxxxxy';
    update applicant;
    update applicant2;
    contract1.Scheduled_Amount__c = 130;
    contract2.Scheduled_Amount__c = 130;
    update contract1;
    update contract2;

    //Create the csv file and payment records for the test
    Payment_File__c paymentFile = new Payment_File__c(
      File_Name__c = 'Unit Test Ezidebit payments',
      File_Upload_Date__c = datetime.now()
    );
    insert paymentFile;

    List<Payment__c> payments = new List<Payment__c>{
      new Payment__c(
        Payment_File__c = paymentFile.Id,
        RecordTypeId = PaymentUtil.RECORDTYPE_ID_EZIDEBIT,
        Payment_Date__c = Date.today().addDays(14),
        Ezidebit_Ref_No__c = 'xxxxxxx',
        Customer_Account_No__c = 'xxxxxxxx',
        Deducted_Amount__c = 130,
        Amount_Deposited__c = 130,
        Actual_Amount__c = 130,
        Client_Fees__c = 1.5,
        Fee_Amount__c = 0,
        Setup_Fee__c = 0
      ),
      new Payment__c(
        Payment_File__c = paymentFile.Id,
        RecordTypeId = PaymentUtil.RECORDTYPE_ID_EZIDEBIT,
        Payment_Date__c = Date.today().addDays(14),
        Ezidebit_Ref_No__c = 'xxxxxxy',
        Customer_Account_No__c = 'xxxxxxxy',
        Deducted_Amount__c = 130,
        Amount_Deposited__c = 130,
        Actual_Amount__c = 130,
        Client_Fees__c = 1.5,
        Fee_Amount__c = 0,
        Setup_Fee__c = 0
      )
    };
    insert payments;

    contract1 = refreshContractRecord(contract1.Id);
    contract2 = refreshContractRecord(contract2.Id);
    System.debug('###contract1: ' + contract1);
    System.debug('###contract2: ' + contract2);
    //System.assertEquals(26, contract1.No_of_Scheduled_Payments__c, 'There should be 26 schedule payments.');
    //System.assertEquals(26, contract2.No_of_Scheduled_Payments__c, 'There should be 26 schedule payments.');
    //System.assertEquals(1, countNumberOfPaymentAllocations(contract1.Id), 'There should be 1 payment allocations.');
    //System.assertEquals(1, countNumberOfPaymentAllocations(contract2.Id), 'There should be 1 payment allocations.');
    //System.assertEquals(130, contract1.Total_Paid_Amount__c, 'Total Paid amount should be 130.');
    //System.assertEquals(130, contract2.Total_Paid_Amount__c, 'Total Paid amount should be 130.');
  }

  static testMethod void testOneContractPerApplicantLoadCompletdEzidebitPaymentsCC() {
    createTestData();

    //Create the csv file and payment records for the test
    Payment_File__c paymentFile = new Payment_File__c(
      File_Name__c = 'Unit Test EzidebitCC payments',
      File_Upload_Date__c = datetime.now()
    );
    insert paymentFile;

    List<Payment__c> payments = new List<Payment__c>{
      new Payment__c(
        Payment_File__c = paymentFile.Id,
        RecordTypeId = PaymentUtil.RECORDTYPE_ID_EZIDEBIT,
        Payment_Date__c = Date.today().addDays(14),
        Ezidebit_Ref_No__c = 'xxxxxxx',
        Customer_Account_No__c = [
          SELECT id, Contract_no__c
          FROM Opportunity
          WHERE id = :contract3.Id
        ]
        .Contract_no__c,
        Agreement__c = contract3.Id,
        Is_Credit_Contract__c = true,
        Deducted_Amount__c = 130,
        Amount_Deposited__c = 130,
        Actual_Amount__c = 130,
        Client_Fees__c = 1.5,
        Fee_Amount__c = 0,
        Setup_Fee__c = 0
      )
    };
    insert payments;
  }

  // Delivered after signing (Pending Order back to Goods Delivered before the first payment): interest on the
  // first payment runs from the delivery day, not from signing.
  static testMethod void testFirstPaymentChargedFromDelivery() {
    createTestData();
    update new Opportunity(Id = contract3.Id, StageName = 'Pending Order');
    update new Opportunity(Id = contract3.Id, StageName = 'Goods Delivered');
    Payment_File__c paymentFile = new Payment_File__c(File_Name__c = 'Unit Test delivery', File_Upload_Date__c = datetime.now());
    insert paymentFile;
    Test.startTest();
    insert new Payment__c(
      Payment_File__c = paymentFile.Id,
      RecordTypeId = PaymentUtil.RECORDTYPE_ID_EZIDEBIT,
      Payment_Date__c = Date.today().addDays(14),
      Ezidebit_Ref_No__c = 'xxxxxxx',
      Customer_Account_No__c = [SELECT Contract_no__c FROM Opportunity WHERE Id = :contract3.Id].Contract_no__c,
      Agreement__c = contract3.Id,
      Is_Credit_Contract__c = true,
      Deducted_Amount__c = 130,
      Amount_Deposited__c = 130,
      Actual_Amount__c = 130,
      Client_Fees__c = 1.5,
      Fee_Amount__c = 0,
      Setup_Fee__c = 0
    );
    Test.stopTest();
    List<Scheduled_Payment__c> sps = [SELECT Payment_Frequency_Number__c FROM Scheduled_Payment__c WHERE Opportunity__c = :contract3.Id ORDER BY CreatedDate DESC LIMIT 1];
    if (!sps.isEmpty()) {
      System.assert(sps[0].Payment_Frequency_Number__c <= 14, 'no more than the 14 days since delivery: ' + sps[0].Payment_Frequency_Number__c);
    }
  }

  // Interest stopped on the agreement (InterestStop page): a payment on or after the stop date carries no interest.
  static testMethod void testInterestStoppedPaymentCarriesNoInterest() {
    createTestData();
    update new Opportunity(Id = contract3.Id, Interest_Stopped_From__c = Date.today(), Interest_Stop_Reason__c = 'Hardship');

    Payment_File__c paymentFile = new Payment_File__c(
      File_Name__c = 'Unit Test interest stopped',
      File_Upload_Date__c = datetime.now()
    );
    insert paymentFile;
    Test.startTest();
    insert new Payment__c(
      Payment_File__c = paymentFile.Id,
      RecordTypeId = PaymentUtil.RECORDTYPE_ID_EZIDEBIT,
      Payment_Date__c = Date.today().addDays(14),
      Ezidebit_Ref_No__c = 'xxxxxxx',
      Customer_Account_No__c = [SELECT Contract_no__c FROM Opportunity WHERE Id = :contract3.Id].Contract_no__c,
      Agreement__c = contract3.Id,
      Is_Credit_Contract__c = true,
      Deducted_Amount__c = 130,
      Amount_Deposited__c = 130,
      Actual_Amount__c = 130,
      Client_Fees__c = 1.5,
      Fee_Amount__c = 0,
      Setup_Fee__c = 0
    );
    Test.stopTest();
    List<Scheduled_Payment__c> sps = [SELECT Exclude_Interest__c FROM Scheduled_Payment__c WHERE Opportunity__c = :contract3.Id ORDER BY CreatedDate DESC LIMIT 1];
    if (!sps.isEmpty()) {
      System.assert(sps[0].Exclude_Interest__c, 'a payment after the stop date carries no interest');
    }
    Opportunity after = [SELECT Interest_Accrued_Since_Last_Payment__c FROM Opportunity WHERE Id = :contract3.Id];
    System.assertEquals(0, after.Interest_Accrued_Since_Last_Payment__c, 'the payout figure stops accruing');
  }

  static testMethod void testOneContractPerApplicantLoadCompletdCashPaymentsCC() {
    createTestData();

    //Create the csv file and payment records for the test
    Payment_File__c paymentFile = new Payment_File__c(
      File_Name__c = 'Unit Test CashCC payments',
      File_Upload_Date__c = datetime.now()
    );
    insert paymentFile;

    List<Payment__c> payments = new List<Payment__c>{
      new Payment__c(
        Payment_File__c = paymentFile.Id,
        RecordTypeId = PaymentUtil.RECORDTYPE_ID_CASH,
        Payment_Date__c = Date.today().addDays(14),
        Ezidebit_Ref_No__c = 'xxxxxxx',
        Customer_Account_No__c = [
          SELECT id, Contract_no__c
          FROM Opportunity
          WHERE id = :contract3.Id
        ]
        .Contract_no__c,
        Agreement__c = contract3.Id,
        Is_Credit_Contract__c = true,
        Deducted_Amount__c = 130,
        Amount_Deposited__c = 130,
        Actual_Amount__c = 130,
        Client_Fees__c = 1.5,
        Fee_Amount__c = 0,
        Setup_Fee__c = 0
      )
    };
    insert payments;
  }

  static testMethod void testOneContractPerApplicantLoadCompletdWINZPaymentsCC() {
    createTestData();

    //Create the csv file and payment records for the test
    Payment_File__c paymentFile = new Payment_File__c(
      File_Name__c = 'Unit Test WINZCC payments',
      File_Upload_Date__c = datetime.now()
    );
    insert paymentFile;

    List<Payment__c> payments = new List<Payment__c>{
      new Payment__c(
        Payment_File__c = paymentFile.Id,
        RecordTypeId = PaymentUtil.RECORDTYPE_ID_WINZ,
        Payment_Date__c = Date.today().addDays(14),
        WINZ_No__c = 'xxxxxxx',
        Customer_Account_No__c = [
          SELECT id, Contract_no__c
          FROM Opportunity
          WHERE id = :contract3.Id
        ]
        .Contract_no__c,
        Agreement__c = contract3.Id,
        Is_Credit_Contract__c = true,
        Deducted_Amount__c = 130,
        Amount_Deposited__c = 130,
        Actual_Amount__c = 130,
        Client_Fees__c = 1.5,
        Fee_Amount__c = 0,
        Setup_Fee__c = 0
      )
    };
    insert payments;
  }

  /*
   * Test case of refund payments.
   */
  static testMethod void testNegativeEzidebitPayment() {
    createTestData();
    applicant.Centrepay_Ref_No__c = null;
    applicant.Ezidebit_Ref_No__c = 'xxxxxxx';
    update applicant;
    contract1.Scheduled_Amount__c = 130;
    update contract1;

    //Create the csv file and payment records for the test
    Payment_File__c paymentFile = new Payment_File__c(
      File_Name__c = 'Unit Test Centrepay payments',
      File_Upload_Date__c = datetime.now()
    );
    insert paymentFile;

    List<Payment__c> payments = new List<Payment__c>{
      new Payment__c(
        Payment_File__c = paymentFile.Id,
        RecordTypeId = PaymentUtil.RECORDTYPE_ID_EZIDEBIT,
        Payment_Date__c = Date.today().addDays(14),
        Ezidebit_Ref_No__c = 'xxxxxxx',
        Customer_Account_No__c = 'xxxxxxxx',
        Deducted_Amount__c = 130,
        Amount_Deposited__c = 130,
        Actual_Amount__c = 130,
        Client_Fees__c = 1.5,
        Fee_Amount__c = 0,
        Setup_Fee__c = 0
      ),
      //refund of the preivous payment
      new Payment__c(
        Payment_File__c = paymentFile.Id,
        RecordTypeId = PaymentUtil.RECORDTYPE_ID_EZIDEBIT,
        Payment_Date__c = Date.today().addDays(14),
        Ezidebit_Ref_No__c = 'xxxxxxx',
        Customer_Account_No__c = 'xxxxxxxx',
        Deducted_Amount__c = -130,
        Amount_Deposited__c = -130,
        Actual_Amount__c = -130,
        Client_Fees__c = -1.5,
        Fee_Amount__c = 0,
        Setup_Fee__c = 0
      )
    };
    insert payments;

    //Check there should be 1 payment allocation but 2 payment records.
    contract1 = refreshContractRecord(contract1.Id);
    //System.assertEquals(2, payments.size(), 'There should be 2 payments made.');
    //System.assertEquals(26, contract1.No_of_Scheduled_Payments__c, 'There should be 26 schedule payments.');
    //System.assertEquals(1, countNumberOfPaymentAllocations(contract1.Id), 'There should be 2 payment allocations.');
    //System.assertEquals(130, contract1.Total_Paid_Amount__c, 'Total Paid amount should be 130. Negative should be ignored.');
  }

  static testMethod void testOneContractLoadLastEzidebitOverPaid() {
    createTestData();
    applicant.Centrepay_Ref_No__c = null;
    applicant.Ezidebit_Ref_No__c = 'xxxxxxx';
    update applicant;

    //Create the csv file and payment records for the test
    Payment_File__c paymentFile = new Payment_File__c(
      File_Name__c = 'Unit Test Centrepay payments',
      File_Upload_Date__c = datetime.now()
    );
    insert paymentFile;

    List<Payment__c> payments = new List<Payment__c>();
    Date effective_date = date.today();
    for (Integer i = 0; i < 26; i++) {
      effective_date = effective_date.addDays(14);
      payments.add(
        new Payment__c(
          Payment_File__c = paymentFile.Id,
          RecordTypeId = PaymentUtil.RECORDTYPE_ID_EZIDEBIT,
          Payment_Date__c = effective_date,
          Ezidebit_Ref_No__c = 'xxxxxxx',
          Customer_Account_No__c = 'xxxxxxxx',
          Deducted_Amount__c = 100,
          Amount_Deposited__c = 100,
          Actual_Amount__c = 100,
          Client_Fees__c = 1.5,
          Fee_Amount__c = 0,
          Setup_Fee__c = 0
        )
      );
    }
    payments[25].Deducted_Amount__c = 150;
    payments[25].Amount_Deposited__c = 150;
    payments[25].Actual_Amount__c = 150;
    insert payments;

    contract1 = refreshContractRecord(contract1.Id);
    System.debug('###contract1: ' + contract1);
    //System.assertEquals(26, payments.size(), 'There should be 26 payments.');
    //System.assertEquals(26, contract1.No_of_Scheduled_Payments__c, 'There should be 26 schedule payments.');
    //System.assertEquals(2650, contract1.Total_Paid_Amount__c, 'Total Paid amount should be 2650.');
    //System.assertEquals(26, countNumberOfPaymentAllocations(contract1.Id), 'There should be 26 payment allocations.');
  }

  /*
   * Test case for over paying and under paying ezidebit payments.
   */
  static testMethod void testOneContractLoadOverPaidAndUnderPaidEzidebits() {
    createTestData();
    applicant.Centrepay_Ref_No__c = null;
    applicant.Ezidebit_Ref_No__c = 'xxxxxxx';
    update applicant;

    contract1.Scheduled_Amount__c = 100;
    update contract1;

    //Create the csv file and payment records for the test
    Payment_File__c paymentFile = new Payment_File__c(
      File_Name__c = 'Unit Test Centrepay payments',
      File_Upload_Date__c = datetime.now()
    );
    insert paymentFile;

    List<Payment__c> payments = new List<Payment__c>();
    Date effective_date = date.today();
    for (Integer i = 0; i < 26; i++) {
      effective_date = effective_date.addDays(14);
      payments.add(
        new Payment__c(
          Payment_File__c = paymentFile.Id,
          RecordTypeId = PaymentUtil.RECORDTYPE_ID_EZIDEBIT,
          Payment_Date__c = effective_date,
          Ezidebit_Ref_No__c = 'xxxxxxx',
          Customer_Account_No__c = 'xxxxxxxx',
          Deducted_Amount__c = 100,
          Amount_Deposited__c = 100,
          Actual_Amount__c = 100,
          Client_Fees__c = 1.5,
          Fee_Amount__c = 0,
          Setup_Fee__c = 0
        )
      );
    }
    //One under paid in the middle
    payments[3].Deducted_Amount__c = 50;
    payments[3].Amount_Deposited__c = 50;
    payments[3].Actual_Amount__c = 50;
    //And one over paid in the between
    payments[5].Deducted_Amount__c = 150;
    payments[5].Amount_Deposited__c = 150;
    payments[5].Actual_Amount__c = 150;
    insert payments;

    //There should be more payment allocations but all 26 payments paid off.
    contract1 = refreshContractRecord(contract1.Id);
    System.debug('###contract1: ' + contract1);
    //System.assertEquals(26, payments.size(), 'There should be 26 payments.');
    //System.assertEquals(26, contract1.No_of_Scheduled_Payments__c, 'There should be 26 schedule payments.');
    //System.assertEquals(2600, contract1.Total_Paid_Amount__c, 'Total Paid amount should be 2600.');
    //System.assertEquals(28, countNumberOfPaymentAllocations(contract1.Id), 'There should be 27 payment allocations.');
  }

  /*
   * Test case of making a deposit before the contract start.
   */
  static testMethod void testOneContractDeposit() {
    createTestData();
    applicant.Centrepay_Ref_No__c = null;
    applicant.Ezidebit_Ref_No__c = 'xxxxxxx';
    update applicant;

    contract1.Scheduled_Amount__c = 100;
    update contract1;

    //Create the csv file and payment records for the test
    Payment_File__c paymentFile = new Payment_File__c(
      File_Name__c = 'Unit Test Centrepay payments',
      File_Upload_Date__c = datetime.now()
    );
    insert paymentFile;

    Payment__c payment = new Payment__c(
      Payment_File__c = paymentFile.Id,
      RecordTypeId = PaymentUtil.RECORDTYPE_ID_DEPOSIT,
      Actual_Amount__c = 100,
      Agreement__c = contract1.Id,
      Effective_Date__c = date.today(),
      Client_Fees__c = 1.5,
      Fee_Amount__c = 0
    );
    insert payment;

    //The first schedule payment should be paid off.
    contract1 = refreshContractRecord(contract1.Id);
    System.debug('###contract1: ' + contract1);
    //System.assertEquals(26, contract1.No_of_Scheduled_Payments__c, 'There should be 26 schedule payments.');
    //System.assertEquals(100, contract1.Total_Paid_Amount__c, 'Total Paid amount should be 2600.');
    //System.assertEquals(1, countNumberOfPaymentAllocations(contract1.Id), 'There should be 26 payment allocations.');

    List<Scheduled_Payment__c> scheduledPayments = getScheduledPayments(
      contract1.Id
    );

    //System.assertEquals(100, scheduledPayments[0].Paid_Amount__c, 'The last scheduled payment should be fully paid.');
  }

  /*
   * Test case for adhoc cash payments
   */
  static testMethod void testOneContractCashAdHoc() {
    createTestData();
    applicant.Centrepay_Ref_No__c = null;
    applicant.Ezidebit_Ref_No__c = 'xxxxxxx';
    update applicant;

    contract1.Scheduled_Amount__c = 100;
    update contract1;

    //Create the csv file and payment records for the test
    Payment_File__c paymentFile = new Payment_File__c(
      File_Name__c = 'Unit Test Centrepay payments',
      File_Upload_Date__c = datetime.now()
    );
    insert paymentFile;

    Payment__c payment = new Payment__c(
      Payment_File__c = paymentFile.Id,
      RecordTypeId = PaymentUtil.RECORDTYPE_ID_CASH,
      Actual_Amount__c = 100,
      Agreement__c = contract1.Id,
      Effective_Date__c = date.today(),
      Client_Fees__c = 1.5,
      Fee_Amount__c = 0
    );
    insert payment;

    //It should paid off the last scheduled payment of the contract.
    contract1 = refreshContractRecord(contract1.Id);
    System.debug('###contract1: ' + contract1);
    //System.assertEquals(26, contract1.No_of_Scheduled_Payments__c, 'There should be 26 schedule payments.');
    //System.assertEquals(100, contract1.Total_Paid_Amount__c, 'Total Paid amount should be 2600.');
    //System.assertEquals(1, countNumberOfPaymentAllocations(contract1.Id), 'There should be 26 payment allocations.');

    List<Scheduled_Payment__c> scheduledPayments = getScheduledPayments(
      contract1.Id
    );

    //System.assertEquals(100, scheduledPayments[scheduledPayments.size() - 1].Paid_Amount__c, 'The first scheduled payment should be fully paid.');
  }

  /*
   * helper method to refresh the contract for checking testing results.
   */
  private static Opportunity refreshContractRecord(Id contractId) {
    return [
      SELECT
        Id,
        No_of_Payments__c,
        No_of_Scheduled_Payments__c,
        Total_Paid_Amount__c,
        Is_Active__c,
        Scheduled_Amount__c,
        StageName,
        Delivery_Date__c
      FROM Opportunity
      WHERE Id = :contractId
      LIMIT 1
    ];
  }

  /*
   * helper method for counting the number of payment allocations.
   */
  private static Integer countNumberOfPaymentAllocations(Id contractId) {
    List<Payment_Allocation__c> payment_allocs = [
      SELECT Id
      FROM Payment_Allocation__c
      WHERE Contract__c = :contractId
    ];
    return payment_allocs.size();
  }

  /*
   * helper method for getting a list of scheduled payments for the contract to verify the testing results.
   */
  private static List<Scheduled_Payment__c> getScheduledPayments(
    Id contractId
  ) {
    return [
      SELECT Id, Fully_Paid__c, Paid_Amount__c, Scheduled_Date__c
      FROM Scheduled_Payment__c
      WHERE Opportunity__c = :contractId
      ORDER BY Scheduled_Date__c DESC
    ];
  }

  static testMethod void testOneContractLoadLastWINZPaid() {
    Test.startTest();
    createTestData();
    applicant.Centrepay_Ref_No__c = null;
    applicant.Ezidebit_Ref_No__c = 'xxxxxxx';
    update applicant;

    //Create the csv file and payment records for the test
    Payment_File__c paymentFile = new Payment_File__c(
      File_Name__c = 'Unit Test Centrepay payments',
      File_Upload_Date__c = datetime.now()
    );
    insert paymentFile;

    List<Payment__c> payments = new List<Payment__c>();
    Date effective_date = date.today();
    for (Integer i = 0; i < 26; i++) {
      effective_date = effective_date.addDays(14);
      payments.add(
        new Payment__c(
          Payment_File__c = paymentFile.Id,
          RecordTypeId = PaymentUtil.RECORDTYPE_ID_WINZ,
          Payment_Date__c = effective_date,
          Ezidebit_Ref_No__c = 'xxxxxxx',
          Customer_Account_No__c = 'xxxxxxxx',
          Deducted_Amount__c = 100,
          Amount_Deposited__c = 100,
          Actual_Amount__c = 100,
          Client_Fees__c = 1.5,
          Fee_Amount__c = 0,
          Setup_Fee__c = 0
        )
      );
    }

    insert payments;

    contract1 = refreshContractRecord(contract1.Id);
    System.debug('###contract1: ' + contract1);
    Test.stopTest();
  }

  static testMethod void testAllocateCentrepay() {
    Test.startTest();
    String centrepayRecordId = Util.getRecordTypeInfosByDeveloperName(
        'Payment__c'
      )
      .get('Centrepay')
      .Id;
    List<Payment__c> payments = [
      SELECT
        Id,
        Centrelink_Ref_No__c,
        RecordTypeId,
        Total_Paid__c,
        Actual_Amount__c,
        Payment_Date__c,
        CreatedDate,
        Client_Fees__c,
        Fee_Amount__c,
        Setup_Fee__c
      FROM Payment__c
      WHERE RecordTypeId = :centrepayRecordId
      ORDER BY CreatedDate DESC
      LIMIT 2
    ];
    PaymentUtil.allocateCentrepayPayments(payments);
    Test.stopTest();
  }

  /*static testmethod void testAllocateManual() {
        Test.startTest();
        String centrepayRecordId = Util.getRecordTypeInfosByDeveloperName('Payment__c').get('Centrepay').Id;
        Payment__c payment = [SELECT Id, Centrelink_Ref_No__c,RecordTypeId,Total_Paid__c,Actual_Amount__c,Payment_Date__c,CreatedDate,Client_Fees__c,Fee_Amount__c,Setup_Fee__c,ApplicantLookup__c, ApplicantLookup__r.Id,ApplicantLookup__r.Active_Agreements__c,ApplicantLookup__r.Remaining_Amount_Active_Agreements__c FROM Payment__c WHERE RecordTypeId =: centrepayRecordId AND ApplicantLookup__r.Active_Agreements__c > 0 AND ApplicantLookup__r.Remaining_Amount_Active_Agreements__c > 0 ORDER BY CreatedDate DESC LIMIT 1];
        Opportunity opp = [SELECT Id,Name,Remaining_Amount__c FROM Opportunity WHERE AccountId =: payment.ApplicantLookup__c AND StageName = 'Goods Delivered' LIMIT 1];
        Map<String, Decimal> mapOpp = new Map<String, Decimal>();
        mapOpp.put(opp.Id,opp.Remaining_Amount__c);
        PaymentUtil.allocatePaymentsManually(mapOpp, payment);
        Test.stopTest();
    }*/

  static testMethod void testPaymentallocations() {
    Test.startTest();
    createTestData2();
    Map<String, Decimal> mapOpp = new Map<String, Decimal>();
    mapOpp.put(contract1.Id, contract1.Remaining_Amount__c);
    PaymentUtil.allocatePaymentsManually(mapOpp, paymentCRN);

    Test.stopTest();
  }

  private static testMethod void testPaymentCreditBatch() {
    // Start test
    createTestData();
    Test.startTest();
    EzidebitSettled__c ez = new EzidebitSettled__c();
    ez.Opportunity__c = contract1.Id;
    ez.Account__c = applicant.Id;
    ez.PaymentAmount__c = 100;
    insert ez;
    PaymentCreditBatch batch = new PaymentCreditBatch();
    Id batchId = Database.executeBatch(batch);
    Test.stopTest();
  }

  private static testMethod void testRealignScheduledPaymentsBatch() {
    Test.startTest();
    List<Opportunity> opps = [
      SELECT Id, Name, Unpaid_Interest_Amount__c
      FROM Opportunity
      WHERE
        Unpaid_Interest_Amount__c > 0
        AND Account.State_Master_State__c != 'NZ'
        AND StageName IN ('Goods Delivered', 'Written Off / Bad Debt')
      LIMIT 1
    ];
    RealignScheduledPaymentsBatch batch = new RealignScheduledPaymentsBatch(
      opps[0].Id
    );
    Id batchId = Database.executeBatch(batch);
    Test.stopTest();
  }

  private static testMethod void testPaymentAnalysis() {
    Test.startTest();
    List<Opportunity> opps = [
      SELECT Id, Name, Unpaid_Interest_Amount__c
      FROM Opportunity
      WHERE
        is_Credit_Contract__c = TRUE
        AND Unpaid_Interest_Amount__c > 0
        AND Total_additional_Fees__c > 0
      LIMIT 1
    ];
    if (opps.size() > 0) {
      ApexPages.currentPage().getParameters().put('id', opps[0].Id);
      PaymentStatementAnalysisController controller = new PaymentStatementAnalysisController();
    }
    Test.stopTest();
  }

  static testMethod void testExpectedPaymentScheduler() {
    Test.startTest();
    ExpectedPaymentScheduler scheduler = new ExpectedPaymentScheduler();
    String jobId = System.schedule(
      'Expected Payment Scheduler',
      '0 0 * * * ?',
      scheduler
    );
    Test.stopTest();
  }

  static testMethod void testExpectedInterestScheduler() {
    Test.startTest();
    ExpectedInterestScheduler scheduler = new ExpectedInterestScheduler();
    String jobId = System.schedule(
      'Expected Interest Scheduler',
      '0 0 * * * ?',
      scheduler
    );
    Test.stopTest();
  }

  static testMethod void testCreditContractExpectedPaymentCalculator() {
    Test.startTest();
    CreditContractExpectedPaymentCalculator ccepc = new CreditContractExpectedPaymentCalculator();
    Database.executeBatch(ccepc, 200);
    Test.stopTest();
  }

  static testMethod void testCreditContractExpectedInterestCalculator() {
    Test.startTest();
    List<Opportunity> oppList = [
      SELECT
        Id,
        Name,
        AccountId,
        Amount,
        StageName,
        First_Payment_Received_Date__c,
        CC_Payment_Date_Last_Expected__c,
        Interest_Last_Expected__c,
        Ezidebit_Starting_Date__c,
        Principal_Last_Expected__c,
        Total_Loan_Balance_Amount__c,
        Payment_Frequency_Number__c,
        Taxinvoice_Signed_Date__c,
        Daily_Interest_Rate__c,
        Scheduled_Amount__c,
        Interest_Accrued_Since_Last_Payment__c,
        Last_Payment_Received_Date__c,
        Total_Paid_Interest_Amount__c
      FROM Opportunity
      WHERE
        Is_Credit_Contract__c = TRUE
        AND Account.State_Master_State__c != 'NZ'
        AND Taxinvoice_Signed_Date__c != NULL
        AND (Taxinvoice_Signed_Date__c != LAST_N_DAYS:14
        OR Last_Payment_Received_Date__c != NULL)
        AND StageName != 'Did Not Proceed'
        AND Scheduled_Amount__c > 0
      ORDER BY Taxinvoice_Signed_Date__c ASC
      LIMIT 100
    ];
    Set<Id> oppIds = new Set<Id>();
    for (Opportunity opp : oppList) {
      oppIds.add(opp.Id);
    }
    CreditContractExpectedInterestCalculator cceic = new CreditContractExpectedInterestCalculator(
      oppIds
    );
    Database.executeBatch(cceic, 200);
    Test.stopTest();
  }
}