@IsTest (SeeAllData=true)

public class CollectionsConsoleCreditContractTest
{

    static Opportunity contract1;
    static Account applicant;
    static Territory__c territory;
    static Collection_Activity__c ca;
    static Payment__c paymentCASH;

    
static void createTestData()
{
    territory = [
            SELECT
                Id,
                Name,
                Short_Name__c
            FROM
                Territory__c
            WHERE
                Name = '100' limit 1
        ];
    RecordType personAccountRecordType = [SELECT Id, Name FROM RecordType WHERE SobjectType = 'Account' AND IsPersonType = true AND Name = 'Applicant' limit 1];
    List<Account> refacctList = [SELECT Id,Referring_Applicant__c FROM Account WHERE Referring_Applicant__c != null AND Referring_Applicant__r.Applicant__r.Active_Agreements__c > 0 LIMIT 1];
    
    applicant = new Account(
        RecordTypeId = personAccountRecordType.Id,
      Salutation = 'Mr.',
      FirstName = 'UnitTest',
      LastName = 'Applicant 1',
      Centrepay_Ref_No__c = 'xxxxxxxxxx',
      Ezidebit_Ref_No__c = null, 
      Customer_No__c = 'xxxxxxxx',
      PersonMobilePhone='0469036691',
      Territory_Number__c = territory.Id,
      Veda_File_Number__c='987779090999',
      Centrelink_Benefit__c='Parenting Payment',
      Centrelink_Benefit_Amount__c=1000,
      Rent_Mortgage_Board__c=500,
      Product_Category_Selected__c='Phones',
      Product_COGS_for_Agreement__c=1000,
      Product_Term_for_Agreement__c='36',
      PersonEmail='test@test.com.au',
      Bank_Institution__c='Demo Bank',
      Equifax_Mobile__c='0469036691',
      AccessId_BankStatement__c='123456432',
      Equifax_Enquiry_Id__c = '171205-P04CJ-040AS',
        Referring_Applicant__c = refacctList.size() > 0 ? refacctList[0].Referring_Applicant__c : null
    );
    insert applicant;
    
     contract1 = new Opportunity(
      Name = 'UnitTest - Contract Number Test 1',
      AccountId = applicant.Id,
      StageName = 'Goods Delivered',
      Start_Date__c = Date.today(),
      CloseDate = Date.today().addMonths(12),
      Term_Months__c = '12',
      Payment_Frequency__c = 'Fortnightly',
      Scheduled_Amount__c = 200,
      Is_Active__c = true,
      Requirements_Objectives__c='testrequired',
      Repossess_Notes__c='repossesstest',
         Is_Credit_Contract__c = true
    );
    insert contract1;
    
    ca = new Collection_Activity__c(
        Applicant__c = applicant.Id,
        Agreement__c = contract1.Id,
        Email__c = 'test@test.com',
        First_Name__c = 'Shrijit',
        Last_Name__c = 'XXXX',
        MobilePhoneNumber__c = '0585868XXX',
        Scheduled_Amount__c = 60,
        Short_Link__c='testlink.com',
        Collection_Outcome1__c='In Progress',
        Collection_Notes__c='Missed payment',
        Communication_Type__c='SMS',
        Activity_By__c='Infield Collections',
        Activity_Type__c='Missed'
    );
    insert ca;
    
     Payment_File__c paymentFile = new Payment_File__c(
        File_Name__c = 'Unit Test Cash payments',
        File_Upload_Date__c = datetime.now()
      );
      insert paymentFile;
      
       paymentCASH = new Payment__c(
          Payment_File__c = paymentFile.Id,
          RecordTypeId    = PaymentUtil.RECORDTYPE_ID_CASH,
          Customer_Name__c = 'UnitTest Applicant 1',
          Scheduled_Amount__c = 100,
          Actual_Amount__c = 99.01,
          Effective_Date__c = Date.today().addDays(14),
          Payment_Date__c = Date.today().addDays(14),
          Centrelink_Ref_No__c = 'xxxxxxxxxx',
          Fee_Amount__c = 0.99,
          Lodgement_Prefix_Ref_No__c = 'xxxxxxxx',
          Applicantlookup__c=applicant.Id,
           Agreement__c = contract1.Id,
           Is_Credit_Contract__c = true
        );
        insert paymentCASH;
}    

@IsTest static void test0()
{
    Test.startTest();
    Test.setMock(HttpCalloutMock.class, new FirebaseCalloutMock());
    
    List<Collection_Activity__c> caList = [SELECT Id FROM Collection_Activity__c WHERE Short_Link__c = null AND Agreement__c <> null ORDER BY CreatedDate DESC LIMIT 1]; 
    if(caList.size() > 0){
        Collection_Activity__c ca1 = caList[0];
        ApexPages.StandardController sc = new ApexPages.StandardController(ca1);
        CollectionsConsoleCreditContract cac = new CollectionsConsoleCreditContract(sc);
        cac.initializeConsole();
        
        cac.actionCollectionActivitySMS(); 
        cac.actionCollectionActivityEmail(); 
    }
    Test.stopTest();    
}

@IsTest static void test1()
{
    Test.startTest();
    Test.setMock(HttpCalloutMock.class, new FirebaseCalloutMock());
    
    List<Collection_Activity__c> caList = [SELECT Id FROM Collection_Activity__c WHERE Agreement__c <> null ORDER BY CreatedDate DESC LIMIT 1]; 
    if(caList.size() > 0){
        Collection_Activity__c ca1 = caList[0];
        ApexPages.StandardController sc = new ApexPages.StandardController(ca1);
        CollectionsConsoleCreditContract cac = new CollectionsConsoleCreditContract(sc);
        cac.initializeConsole();
        
        cac.p1PaymentFrequency = '14';
        cac.p2PaymentFrequency = '14';
        cac.p1ScheduledAmount = 100;
        cac.p2ScheduledAmount = 20;
        cac.expectedAmount = 20;
        cac.p1NextDueDate = '14/12/2018';
        cac.p2NextDueDate = '14/12/2018';
        cac.fieldVisitNotes = 'Whaaaaaaaaaat!!!!!!!';
        cac.fieldRepSurname = 'Puli';
        cac.fieldVisitAddress = 'Disneyland';
        cac.droppedArrearsFlyer = true;
        cac.isThisAnArrangement = true;
        cac.arrangementEndDate = '14/12/2018';
        cac.arrangementNotes = 'Whaaaaaaaaaat!!!!!!!';
        cac.actionCollectionActivitySMS(); 
        cac.addFieldVisit();  
    }
    Test.stopTest();    
}

@IsTest static void test2()
{
    Test.startTest();
    Test.setMock(HttpCalloutMock.class, new FirebaseCalloutMock());
    
    List<Collection_Activity__c> caList = [SELECT Id FROM Collection_Activity__c WHERE State_Master_State__c <> 'NZ' AND Agreement__c <> null ORDER BY CreatedDate DESC LIMIT 1]; 
    if(caList.size() > 0){
        Collection_Activity__c ca1 = caList[0];
        ApexPages.StandardController sc = new ApexPages.StandardController(ca1);
        CollectionsConsoleCreditContract cac = new CollectionsConsoleCreditContract(sc);
        cac.initializeConsole();
     
        cac.mobileNumber = '0DD449066375';
        //cac.smsTemplateType = 'DAY 7-29';
        cac.collectionNotes = 'Test';
        cac.remindMeOn = '14/12/2018';
        cac.expectedCollectionDate = '14/12/2018';
        cac.refereesContacted = true;
        cac.refereeName = 'Mohit';
        cac.makeSuccessManually = true;
        cac.reasonSuccessManually = 'Test';
        cac.paymentAmount = 22;
        cac.paymentType = 'Cash';
        
        cac.actionCollectionActivitySMS(); 
        cac.updateCollectionActivity();
    }    
    Test.stopTest();    
}
    
    @IsTest static void test9()
{
        createTestData();
    Test.startTest();
    Test.setMock(HttpCalloutMock.class, new FirebaseCalloutMock());
    ApexPages.StandardController sc = new ApexPages.StandardController(ca);
    CollectionsConsoleCreditContract cac = new CollectionsConsoleCreditContract(sc);
    cac.initializeConsole();
    
    cac.mobileNumber = '0DD449066375';
    //cac.smsTemplateType = 'DAY 7-29';
    cac.collectionNotes = 'Test';
    cac.remindMeOn = '14/12/2018';
    cac.expectedCollectionDate = '14/12/2018';
    cac.refereesContacted = true;
    cac.refereeName = 'Mohit';
    cac.makeSuccessManually = true;
    cac.reasonSuccessManually = 'Test';
    cac.paymentAmount = 22;
    cac.paymentType = 'Cash';
    
    cac.actionCollectionActivitySMS(); 
    cac.actionCollectionActivityEmail(); 
    cac.updateCollectionActivity();
    Test.stopTest();    
}

@IsTest static void test3()
{
    Test.startTest();
    Test.setMock(HttpCalloutMock.class, new FirebaseCalloutMock());
    
    List<Collection_Activity__c> caList = [SELECT Id FROM Collection_Activity__c WHERE State_Master_State__c = 'NZ' AND Agreement__c <> null ORDER BY CreatedDate DESC LIMIT 1]; 
    if(caList.size() > 0){
        Collection_Activity__c ca1 = caList[0];
        ApexPages.StandardController sc = new ApexPages.StandardController(ca1);
        CollectionsConsoleCreditContract cac = new CollectionsConsoleCreditContract(sc);
        cac.initializeConsole();
        
        cac.email = 'mohitTTT@rent4keeps.com.au';
        cac.emailTemplateType = 'DAY 15';
        cac.collectionNotes = 'Test';
        cac.remindMeOn = '14/12/2018';
        cac.refereesContacted = true;
        cac.refereeName = 'Mohit';
        
        cac.actionCollectionActivityEmail(); 
    }
    Test.stopTest();    
}

@IsTest static void test4()
{
    Test.startTest();
    Test.setMock(HttpCalloutMock.class, new FirebaseCalloutMock());
    
    List<Collection_Activity__c> caList = [SELECT Id FROM Collection_Activity__c WHERE State_Master_State__c = 'NZ' AND Agreement__c <> null ORDER BY CreatedDate DESC LIMIT 1]; 
    if(caList.size() > 0){
        Collection_Activity__c ca1 = caList[0];
        ApexPages.StandardController sc = new ApexPages.StandardController(ca1);
        CollectionsConsoleCreditContract cac = new CollectionsConsoleCreditContract(sc);
        cac.initializeConsole();
        
        cac.email = 'mohitff@rent4keeps.com.au';
        cac.emailTemplateType = 'DAY 29';
        cac.collectionNotes = 'Test';
        cac.remindMeOn = '14/12/2018';
        cac.refereesContacted = true;
        cac.refereeName = 'Mohit';
        
        cac.actionCollectionActivityEmail(); 
    }
    Test.stopTest();    
}

@IsTest static void test5()
{
    Test.startTest();
    Test.setMock(HttpCalloutMock.class, new FirebaseCalloutMock());
    
    List<Collection_Activity__c> caList = [SELECT Id FROM Collection_Activity__c WHERE State_Master_State__c <> 'NZ' AND Agreement__c <> null ORDER BY CreatedDate DESC LIMIT 1]; 
    if(caList.size() > 0){
        Collection_Activity__c ca1 = caList[0];
        ApexPages.StandardController sc = new ApexPages.StandardController(ca1);
        CollectionsConsoleCreditContract cac = new CollectionsConsoleCreditContract(sc);
        cac.initializeConsole();
        
        cac.email = 'mohitgg@rent4keeps.com.au';
        cac.emailTemplateType = 'DAY 29';
        cac.collectionNotes = 'Test';
        cac.remindMeOn = '14/12/2018';
        cac.refereesContacted = true;
        cac.refereeName = 'Mohit';
        
        cac.actionCollectionActivityEmail(); 
    }
    Test.stopTest();    
}

@IsTest static void test6()
{
    Test.startTest();
    Test.setMock(HttpCalloutMock.class, new FirebaseCalloutMock());
    
    List<Collection_Activity__c> caList = [SELECT Id FROM Collection_Activity__c WHERE State_Master_State__c = 'NZ' AND Agreement__c <> null ORDER BY CreatedDate DESC LIMIT 1]; 
    if(caList.size() > 0){
        Collection_Activity__c ca1 = caList[0];
        ApexPages.StandardController sc = new ApexPages.StandardController(ca1);
        CollectionsConsoleCreditContract cac = new CollectionsConsoleCreditContract(sc);
        cac.initializeConsole();
        
        cac.email = 'mohitgg@rent4keeps.com.au';
        cac.emailTemplateType = 'DAY 30';
        cac.collectionNotes = 'Test';
        cac.remindMeOn = '14/12/2018';
        cac.refereesContacted = true;
        cac.refereeName = 'Mohit';
        
        cac.actionCollectionActivityEmail(); 
    }
    Test.stopTest();    
}

@IsTest static void test7()
{
    Test.startTest();
    
    List<Collection_Activity__c> caList = [SELECT Id FROM Collection_Activity__c WHERE Agreement__c <> null ORDER BY CreatedDate DESC LIMIT 1]; 
    if(caList.size() > 0){
        Collection_Activity__c ca1 = caList[0];
        ApexPages.StandardController sc = new ApexPages.StandardController(ca1);
        CollectionsConsoleCreditContract cac = new CollectionsConsoleCreditContract(sc);
        cac.initializeConsole();
        if(cac.refereesRelatedList != null && cac.refereesRelatedList.size() > 0)
        {
            cac.editRefereeEmail = 'test@gmail.com';
            cac.editRefereePhone = '0449066375';
            cac.editRefereeContacted = 'Yes';
            cac.editRefereeContactedDate = Date.today().format();
            cac.editRefereeId = cac.refereesRelatedList[0].Id;
            cac.editRefereeContactId = cac.refereesRelatedList[0].Referee_Name__c;
            cac.updateReferee();
        }
        cac.makeSuccessManually = true;
        cac.updateCollectionActivity();
        cac.returnToCollectionActivity();
    }
    Test.stopTest();    
}

}