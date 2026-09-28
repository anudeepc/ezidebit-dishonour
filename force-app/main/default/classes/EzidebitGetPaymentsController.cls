global class EzidebitGetPaymentsController implements Database.Batchable<sObject>, Database.AllowsCallouts{

global final List<Territory__c> lstTerritoriesBatch;
global String DateFromBatch;
global String DateToBatch;

global EzidebitGetPaymentsController(List<Territory__c> lstTerritories, String DateFrom, String DateTo){
    // Batch Constructor
    lstTerritoriesBatch=lstTerritories;
    DateFromBatch=DateFrom;
    DateToBatch=DateTo;
}

// Start Method
global Iterable<SObject> start(Database.BatchableContext BC){
system.debug('lstTerritoriesBatch.size(): '+lstTerritoriesBatch.size());
    //return Database.getQueryLocator(query);
    return lstTerritoriesBatch;
}

// Execute Logic
global void execute(Database.BatchableContext BC, List<Territory__c>scope){
Datetime myDate = Datetime.now().addDays(-1);

String DigitalKey = '';//'61BF8276-2B1C-4383-D3DC-6231E102442C';//'A96FA1B6-1875-47BA-8E2E-41BFE9DCE61E';
String PaymentType = 'ALL';//'SUCCESSFUL';//'FAILED';(S/D)
String PaymentMethod = 'ALL';
String PaymentSource = 'ALL';
String PaymentReference = '';
String DateFrom = DateFromBatch; //'2023-07-01';//myDate.format('yyyy-MM-dd');//'2018-08-10';('yyyy-MM-dd')
String DateTo = DateToBatch;//'2023-08-08';//myDate.format('yyyy-MM-dd');//'2018-08-10';('yyyy-MM-dd')
String DateField = 'SETTLEMENT';
String EziDebitCustomerID = '';//'228813'; //'202-627-833';
String YourSystemReference = '';//'VIC00040';

List<EzidebitSettled__c> ezidebits=new List<EzidebitSettled__c>();
List<Account> accountsToUpdate = new List<Account>();
Map<String,Opportunity> mapoppsToUpdate = new Map<String,Opportunity>();
Set<String> paidAccountIds = new Set<String>();
// Every payment Ezidebit returned, for the dishonour records (EzidebitDishonourService) once all callouts are done.
List<EzidebitAPI.Payment> allPayments = new List<EzidebitAPI.Payment>();
Map<String,String> territoryByPaymentId = new Map<String,String>();
for(Territory__c ter:scope)
{
DigitalKey=ter.Ezidebit_DigitalKey__c;
String territoryName=ter.Short_Name__c;

EzidebitAPI.BasicHttpBinding_INonPCIService stub = new EzidebitAPI.BasicHttpBinding_INonPCIService();
stub.inputHttpHeaders_x = new Map<String, String>();
stub.endpoint_x='https://api.ezidebit.com.au/v3-5/nonpci';
stub.timeout_x=120000;

//List<EzidebitSettled__c> ezidebits=new List<EzidebitSettled__c>();
EzidebitAPI.EziResponseOfArrayOfPaymentTHgMB7oL response=stub.GetPayments(DigitalKey,PaymentType,PaymentMethod,PaymentSource,PaymentReference,DateFrom,DateTo,DateField,EziDebitCustomerID,YourSystemReference);
List<String> payEzidebitRefNos=new List<String>();
List<Account> accounts = new List<Account>();
List<Opportunity> opportunities = new List<Opportunity>();
//List<Account> accountsToUpdate = new List<Account>();
Map<String,Account> accountMap = new Map<String,Account>();
Map<String,Opportunity> oppMap = new Map<String,Opportunity>();
String currentOwnerId=ter.OwnerId;

system.debug('response1: '+response);

if(response.Data!=null)
{
    List<EzidebitAPI.Payment> payments= new List<EzidebitAPI.Payment>();
    payments=response.Data.Payment;
    if(payments!=null)
    {
        allPayments.addAll(payments);
        for(EzidebitAPI.Payment p : payments)
        {
            if(p.PaymentID!=null)
                territoryByPaymentId.put(p.PaymentID,ter.Short_Name__c);
        }
    }
    
    system.debug('payments: '+payments);

    if(payments!=null && payments.size()>0)
    {
        system.debug('payments.size(): '+payments.size());
        
        //Add Ezidebit Ref Nos in the String List
        for(EzidebitAPI.Payment payForAccount : payments)
        {
            payEzidebitRefNos.add(payForAccount.YourSystemReference);
        }
        
        system.debug('payEzidebitRefNos: ' + payEzidebitRefNos);
        
        accounts=[select id,Name,Customer_No__c,OwnerId,Ezidebit_Ref_No__c,Territory_Number__r.Short_Name__c,No_of_Days_Since_Last_Payment__c,Days_Since_Last_Uploaded__c,Schedule_Amount__c,Ignore_payment_indicator_manually_fixed__c,Next_Due_Date_Payment_Type_1__c,Next_Due_Date_Payment_Type_2__c,Scheduled_Amount_Payment_Type_1__c,Scheduled_Amount_Payment_Type_2__c,Payment_Frequency_Payment_Type_1__c,Payment_Frequency_Payment_Type_2__c,Payment_Type_1__c,Payment_Type_2__c,Last_Collection_Activity__c,Last_Collection_Activity__r.Collection_Outcome1__c from Account where Customer_No__c in : payEzidebitRefNos];
        opportunities = [select id,name,Contract_No__c,AccountId,Account.Name,Account.OwnerId,Ezidebit_Ref_No__c,Account.Territory_Number__r.Short_Name__c,Scheduled_Amount__c,Ezidebit_Payment_Status_Date__c from Opportunity where Contract_No__c in: payEzidebitRefNos];
        
        //Add Acocunts to a Map of Ref Nos
        if(accounts.size()>0)
        {
            for(Account acct : accounts)
            {
                accountMap.put(acct.Customer_No__c,acct);
            }
        }
        if(opportunities.size()>0)
        {
            for(Opportunity opp : opportunities)
            {
                oppMap.put(opp.Contract_No__c,opp);
            }
        }
        
        Integer counter = 1;
        String batchPart ='P0';
        for(EzidebitAPI.Payment pay : payments)
        {
            system.debug('pay.YourSystemReference: '+pay.YourSystemReference + ' pay.PaymentSource: '+pay.PaymentSource+' paymentReference: '+pay.PaymentReference+' PaymentMethod: '+pay.PaymentMethod+' ScheduledAmount: '+pay.ScheduledAmount+' BankFailedReason: '+pay.BankFailedReason+' BankReturnCode: '+pay.BankReturnCode);
            
            if(pay.PaymentStatus=='S' && pay.PaymentSource!='WEB' && (pay.BankFailedReason==null || pay.BankFailedReason==''))
            //if(pay.PaymentStatus=='S' && pay.PaymentSource=='WEB')
            {
            batchPart = counter>=1 && counter<=350 ? 'P0' : counter>=351 && counter<=700 ? 'P1' : counter>=701 && counter<=1050 ? 'P2' : counter>=1051 && counter<=1400 ? 'P3' : 'P4';
            system.debug('batchPart: '+batchPart);
            
            //For all successful settlements
            EzidebitSettled__c ezidebit = new EzidebitSettled__c();
            ezidebit.CustomerNo__c=pay.YourSystemReference;
            ezidebit.CustomerName__c=pay.CustomerName;
            ezidebit.PaymentAmount__c=pay.ScheduledAmount;
            ezidebit.ClientFee__c=pay.TransactionFeeClient;
            ezidebit.CustomerFee__c=pay.TransactionFeeCustomer;
            ezidebit.PaymentMethod__c=pay.PaymentMethod;
            ezidebit.PaymentSource__c=pay.PaymentSource;
            ezidebit.PaymentId__c=pay.PaymentId;
            ezidebit.InvoiceId__c=pay.InvoiceId;
            ezidebit.BatchPart__c=batchPart; 
            ezidebit.Ezidebit_DigitalKey__c=DigitalKey;
            ezidebit.Is_Credit_Contract__c=ter.State_Master_State__c!='NZ' ? ter.Is_Credit_Contract__c : false;
            
            Date debitDate = date.newinstance(pay.DebitDate.year(), pay.DebitDate.month(), pay.DebitDate.day());
            Date settledDate;
            if(pay.SettlementDate!=null)
                settledDate=date.newinstance(pay.SettlementDate.year(), pay.SettlementDate.month(), pay.SettlementDate.day());
            
            ezidebit.PaymentDate__c=debitDate;
            ezidebit.Date_Settled__c=settledDate;
            
            if(ter.Name=='101')
                ezidebit.Is_TR4K__c=true;
            
            //Add Account and Owner Information
            currentOwnerId=ter.OwnerId;
            territoryName=ter.Short_Name__c;
            if(!accountMap.isEmpty())
            {
                
                if(accountMap.get(pay.YourSystemReference)!=null)
                {
                    system.debug('pay.YourSystemReference: '+pay.YourSystemReference+' accountMap.get(pay.YourSystemReference).Id: '+accountMap.get(pay.YourSystemReference).Id+' accountMapAccounts: '+accountMap.get(pay.YourSystemReference));
                    ezidebit.Account__c=accountMap.get(pay.YourSystemReference).Id;
                    currentOwnerId=accountMap.get(pay.YourSystemReference).OwnerId;
                    territoryName=accountMap.get(pay.YourSystemReference).Territory_Number__r.Short_Name__c;
                    /*if(accountMap.get(pay.YourSystemReference).Ezidebit_Ref_No__c!=null)
                        ezidebit.Ezidebit_Ref_No__c=accountMap.get(pay.YourSystemReference).Ezidebit_Ref_No__c;
                    else
                        ezidebit.Ezidebit_Ref_No__c=pay.EziDebitCustomerID;*/
                        
                    //Update Ezidebit details in Account after settlement
                    Account acct = new Account();
                    acct.Id=accountMap.get(pay.YourSystemReference).Id;                  
                    acct.Reason_for_Dishonour__c='';                 
                    
                    //Add ERN Ref No if Ezidebit REf No is blank
                    //if(accountMap.get(pay.YourSystemReference).Ezidebit_Ref_No__c==null)
                    if(ezidebit.Is_TR4K__c)
                    {
                        acct.TR4K_ERN__c=pay.EziDebitCustomerID;
                    }
                    else
                    {
                        acct.LastPaymentRecieved__c=pay.ScheduledAmount;
                        acct.LastPaymentStatus__c = 'Paid';
                        acct.Ezidebit_Ref_No__c=pay.EziDebitCustomerID;
                        acct.LastPaymentRecievedDate__c = debitDate;
                        acct.Last_Payment_StatusDate__c=debitDate;
                        acct.Actual_Last_Payment_Status_Date__c=Date.today();
                        acct.Last_Payment_Upload_Date__c=Date.today();
                        acct.Payment_Received_Type__c='Ezidebit';
                    
                        
                        if(accountMap.get(pay.YourSystemReference).No_of_Days_Since_Last_Payment__c>0)
                        {
                            acct.Days_Applicant_Missed_Paying_Again__c=accountMap.get(pay.YourSystemReference).No_of_Days_Since_Last_Payment__c;
                            acct.Repayment_Date__c=debitDate;
                        }
                        if(accountMap.get(pay.YourSystemReference).Days_Since_Last_Uploaded__c>0)
                        {
                            acct.Days_Since_Previous_Upload_Date__c =accountMap.get(pay.YourSystemReference).Days_Since_Last_Uploaded__c;
                        }
                        
                        //Payment Indicator update
                        Decimal totalPaid=acct.LastPaymentRecieved__c;
                        Date todayDate=Date.today();
                        Integer payFreq1=14;
                        Integer payFreq2=14;
                        
                        System.debug('****totalPaid ' + totalPaid);
                        System.debug('accountMap.get(pay.YourSystemReference).Scheduled_Amount_Payment_Type_2__c ' + accountMap.get(pay.YourSystemReference).Scheduled_Amount_Payment_Type_2__c);
                        System.debug('accountMap.get(pay.YourSystemReference).Next_Due_Date_Payment_Type_2__c ' + accountMap.get(pay.YourSystemReference).Next_Due_Date_Payment_Type_2__c);
                        
                        acct.Attention_Required__c=true;
                        acct.AutoCorrected__c=false;
                        acct.Ignore_payment_indicator_manually_fixed__c=false;
                        acct.Warning_Required__c=false;
                        acct.Quick_Fix__c=false;
                        acct.Last_Expected_Amount__c=accountMap.get(pay.YourSystemReference).Schedule_Amount__c;
                        acct.Last_Payment_Received_Amount__c=totalPaid;
                        acct.Last_Expected_Date__c=todayDate;
                        acct.CAP_Payment_Upload_Logs__c = 'Benefit Type - Ezidebit' + '\n' + 'Amount Paid - ' + totalPaid;
                        
                        if(totalPaid > 0 && accountMap.get(pay.YourSystemReference).Payment_Type_1__c == null)
                        {
                            System.debug('****P1 is blank');
                            acct.CAP_Payment_Upload_Logs__c += ('\n' + 'P1 is blank');
                            if(accountMap.get(pay.YourSystemReference).Last_Collection_Activity__c != null && accountMap.get(pay.YourSystemReference).Last_Collection_Activity__r.Collection_Outcome1__c == 'In Progress')
                            {
                                System.debug('****Open CA');
                                acct.CAP_Payment_Upload_Logs__c += ('\n' + 'Open CA');
                                acct.Attention_Required__c=false;
                                acct.AutoCorrected__c=true;
                                acct.Next_Due_Date_Payment_Type_1__c=todayDate.addDays(14);
                                acct.Payment_Frequency_Payment_Type_1__c='14';
                                acct.Scheduled_Amount_Payment_Type_1__c=totalPaid;
                                acct.Payment_Type_1__c = 'Ezidebit';
                            }
                            else
                            {
                                System.debug('****No CA');
                                acct.CAP_Payment_Upload_Logs__c += ('\n' + 'No CA');
                                acct.Attention_Required__c=true;
                                acct.AutoCorrected__c=false;
                                acct.Payment_Type_1__c = 'Ezidebit';
                            }
                        }
                        else if(totalPaid > 0 && accountMap.get(pay.YourSystemReference).Payment_Type_1__c != null && accountMap.get(pay.YourSystemReference).Payment_Type_1__c == 'Ezidebit')
                        {
                            System.debug('****P1 matches');
                            acct.CAP_Payment_Upload_Logs__c += ('\n' + 'P1 matches');
                            if(accountMap.get(pay.YourSystemReference).Scheduled_Amount_Payment_Type_1__c == null || accountMap.get(pay.YourSystemReference).Scheduled_Amount_Payment_Type_1__c == totalPaid)
                            {
                                System.debug('****P1 amount matches');
                                acct.CAP_Payment_Upload_Logs__c += ('\n' + 'P1 amount matches');
                                if(accountMap.get(pay.YourSystemReference).Next_Due_Date_Payment_Type_1__c == null || Math.abs(todayDate.daysBetween(accountMap.get(pay.YourSystemReference).Next_Due_Date_Payment_Type_1__c)) <= 7)
                                {
                                    System.debug('****P1 date matches');
                                    acct.CAP_Payment_Upload_Logs__c += ('\n' + 'P1 date matches');
                                    acct.Attention_Required__c=false;
                                    acct.AutoCorrected__c=true;
                                    acct.Next_Due_Date_Payment_Type_1__c=todayDate.addDays(accountMap.get(pay.YourSystemReference).Payment_Frequency_Payment_Type_1__c == null ? 14 : Integer.valueOf(accountMap.get(pay.YourSystemReference).Payment_Frequency_Payment_Type_1__c));
                                    acct.Payment_Frequency_Payment_Type_1__c=accountMap.get(pay.YourSystemReference).Payment_Frequency_Payment_Type_1__c == null ? '14' : accountMap.get(pay.YourSystemReference).Payment_Frequency_Payment_Type_1__c;
                                    acct.Scheduled_Amount_Payment_Type_1__c=totalPaid;
                                }
                                else
                                {
                                    System.debug('****P1 date does not match');
                                    acct.CAP_Payment_Upload_Logs__c += ('\n' + 'P1 date does not match');
                                    acct.Attention_Required__c=true;
                                    acct.AutoCorrected__c=false;
                                    acct.Payment_Frequency_Payment_Type_1__c=accountMap.get(pay.YourSystemReference).Payment_Frequency_Payment_Type_1__c == null ? '14' : accountMap.get(pay.YourSystemReference).Payment_Frequency_Payment_Type_1__c;
                                    acct.Scheduled_Amount_Payment_Type_1__c=totalPaid;
                                }
                            }
                            else
                            {
                                System.debug('****P1 amount Does not match');
                                acct.CAP_Payment_Upload_Logs__c += ('\n' + 'P1 amount does not match');
                                acct.Attention_Required__c=true;
                                acct.AutoCorrected__c=false;
                                acct.Next_Due_Date_Payment_Type_1__c=todayDate.addDays(accountMap.get(pay.YourSystemReference).Payment_Frequency_Payment_Type_1__c == null ? 14 : Integer.valueOf(accountMap.get(pay.YourSystemReference).Payment_Frequency_Payment_Type_1__c));
                                acct.Payment_Frequency_Payment_Type_1__c=accountMap.get(pay.YourSystemReference).Payment_Frequency_Payment_Type_1__c == null ? '14' : accountMap.get(pay.YourSystemReference).Payment_Frequency_Payment_Type_1__c;    
                            }
                        }
                        else if(totalPaid > 0 && accountMap.get(pay.YourSystemReference).Payment_Type_2__c == null)
                        {
                            System.debug('****P2 is blank');
                            acct.CAP_Payment_Upload_Logs__c += ('\n' + 'P2 is blank');
                            if(accountMap.get(pay.YourSystemReference).Last_Collection_Activity__c != null && accountMap.get(pay.YourSystemReference).Last_Collection_Activity__r.Collection_Outcome1__c == 'In Progress')
                            {
                                System.debug('****Open CA');
                                acct.CAP_Payment_Upload_Logs__c += ('\n' + 'Open CA');
                                acct.Attention_Required__c=false;
                                acct.AutoCorrected__c=true;
                                acct.Next_Due_Date_Payment_Type_2__c=todayDate.addDays(14);
                                acct.Payment_Frequency_Payment_Type_2__c='14';
                                acct.Scheduled_Amount_Payment_Type_2__c=totalPaid;
                                acct.Payment_Type_2__c = 'Ezidebit';
                            }
                            else
                            {
                                System.debug('****No CA');
                                acct.CAP_Payment_Upload_Logs__c += ('\n' + 'No CA');
                                acct.Attention_Required__c=true;
                                acct.AutoCorrected__c=false;
                                acct.Payment_Type_2__c = 'Ezidebit';
                            }
                        }
                        else if(totalPaid > 0 && accountMap.get(pay.YourSystemReference).Payment_Type_2__c != null && accountMap.get(pay.YourSystemReference).Payment_Type_2__c == 'Ezidebit')
                        {
                            System.debug('****P2 matches');
                            acct.CAP_Payment_Upload_Logs__c += ('\n' + 'P2 matches');
                            if(accountMap.get(pay.YourSystemReference).Scheduled_Amount_Payment_Type_2__c == null || accountMap.get(pay.YourSystemReference).Scheduled_Amount_Payment_Type_2__c == totalPaid)
                            {
                                System.debug('****P2 amount matches');
                                acct.CAP_Payment_Upload_Logs__c += ('\n' + 'P2 amount matches');
                                if(accountMap.get(pay.YourSystemReference).Next_Due_Date_Payment_Type_2__c == null || Math.abs(todayDate.daysBetween(accountMap.get(pay.YourSystemReference).Next_Due_Date_Payment_Type_2__c)) <= 7)
                                {
                                    System.debug('****P2 date matches');
                                    acct.CAP_Payment_Upload_Logs__c += ('\n' + 'P2 date matches');
                                    acct.Attention_Required__c=false;
                                    acct.AutoCorrected__c=true;
                                    acct.Next_Due_Date_Payment_Type_2__c=todayDate.addDays(accountMap.get(pay.YourSystemReference).Payment_Frequency_Payment_Type_2__c == null ? 14 : Integer.valueOf(accountMap.get(pay.YourSystemReference).Payment_Frequency_Payment_Type_2__c));
                                    acct.Payment_Frequency_Payment_Type_2__c=accountMap.get(pay.YourSystemReference).Payment_Frequency_Payment_Type_2__c == null ? '14' : accountMap.get(pay.YourSystemReference).Payment_Frequency_Payment_Type_2__c;
                                    acct.Scheduled_Amount_Payment_Type_2__c=totalPaid;
                                }
                                else
                                {
                                    System.debug('****P2 date does not match');
                                    acct.CAP_Payment_Upload_Logs__c += ('\n' + 'P2 date does not match');
                                    acct.Attention_Required__c=true;
                                    acct.AutoCorrected__c=false;
                                    acct.Payment_Frequency_Payment_Type_2__c=accountMap.get(pay.YourSystemReference).Payment_Frequency_Payment_Type_2__c == null ? '14' : accountMap.get(pay.YourSystemReference).Payment_Frequency_Payment_Type_2__c;
                                    acct.Scheduled_Amount_Payment_Type_2__c=totalPaid;
                                }
                            }
                            else
                            {
                                System.debug('****P2 amount does not match');
                                acct.CAP_Payment_Upload_Logs__c += ('\n' + 'P2 amount does not match');
                                acct.Attention_Required__c=true;
                                acct.AutoCorrected__c=false;
                                acct.Next_Due_Date_Payment_Type_2__c=todayDate.addDays(accountMap.get(pay.YourSystemReference).Payment_Frequency_Payment_Type_2__c == null ? 14 : Integer.valueOf(accountMap.get(pay.YourSystemReference).Payment_Frequency_Payment_Type_2__c));
                                acct.Payment_Frequency_Payment_Type_2__c=accountMap.get(pay.YourSystemReference).Payment_Frequency_Payment_Type_2__c == null ? '14' : accountMap.get(pay.YourSystemReference).Payment_Frequency_Payment_Type_2__c;
                            }
                        }
                        
                        if(!acct.Attention_Required__c){
                            acct.Collection_Firm_Sent_DateTime__c = null;
                            acct.Collection_Medium_Sent_DateTime__c = null;
                            acct.Collection_Soft_Sent_DateTime__c = null;
                        }
                    }
                    //////////////////////////
                    
                    accountsToUpdate.add(acct);
                    paidAccountIds.add(acct.Id);
                }
            }
            
            if(!oppMap.isEmpty())
            {
                
                if(oppMap.get(pay.YourSystemReference)!=null && mapoppsToUpdate.get(pay.YourSystemReference)==null)
                {
                    system.debug('##opp'+counter+'pay.YourSystemReference: '+pay.YourSystemReference+' oppMap.get(pay.YourSystemReference).Id: '+oppMap.get(pay.YourSystemReference).Id+' oppMaps: '+oppMap.get(pay.YourSystemReference));
                    ezidebit.Account__c=oppMap.get(pay.YourSystemReference).AccountId;
                    ezidebit.Opportunity__c=oppMap.get(pay.YourSystemReference).Id;
                    currentOwnerId=oppMap.get(pay.YourSystemReference).Account.OwnerId;
                    territoryName=oppMap.get(pay.YourSystemReference).Account.Territory_Number__r.Short_Name__c;
                    
                    //Update Ezidebit details in Opportunity
                    Opportunity opp = new Opportunity();
                    opp.Id = oppMap.get(pay.YourSystemReference).Id;
                    opp.Reason_for_Dishonour__c=''; 
                    //opp.Ezidebit_Payment_Status_Date__c=Date.today(); 
                    if(oppMap.get(pay.YourSystemReference).Ezidebit_Payment_Status_Date__c!=null)
                    {
                        opp.Previous_Dishonour_Date__c = oppMap.get(pay.YourSystemReference).Ezidebit_Payment_Status_Date__c;
                        opp.Ezidebit_Payment_Status_Date__c=null; 
                    }
                    opp.Ezidebit_Ref_No__c=pay.EziDebitCustomerID;
                    //oppsToUpdate.add(opp); 
                    mapoppsToUpdate.put(pay.YourSystemReference,opp);               
                        
                    //Update Ezidebit details in Account after settlement
                    Account acct = new Account();
                    acct.Id=oppMap.get(pay.YourSystemReference).AccountId;                  
                    acct.Reason_for_Dishonour__c='';  
                    acct.LastPaymentRecieved__c=pay.ScheduledAmount;
                    acct.LastPaymentStatus__c = 'Paid';
                    acct.LastPaymentRecievedDate__c = debitDate;
                    acct.Last_Payment_StatusDate__c=debitDate;
                    acct.Actual_Last_Payment_Status_Date__c=Date.today();
                    acct.Last_Payment_Upload_Date__c=Date.today();
                    acct.Payment_Received_Type__c='Ezidebit';
                    accountsToUpdate.add(acct);
                }
            }
            
            //Add Owner Information
            //////////////if(currentOwnerId!='')
            ezidebit.OwnerId=currentOwnerId; //'00590000001qjoP';
            //Add TerritoryName
            ezidebit.Territory_Name__c=territoryName;
            
            //Add Ezidebit Ref No if not present
            //if(ezidebit.Ezidebit_Ref_No__c==null)
            ezidebit.Ezidebit_Ref_No__c=pay.EziDebitCustomerID;
                
            ezidebits.add(ezidebit);
            counter++;
          }
          // F = fatal dishonour (e.g. account closed, payment stopped): a failed scheduled debit too.
          else if(pay.PaymentStatus=='D' || (pay.PaymentStatus=='F' && pay.PaymentSource!='WEB'))
          {
              //For all dishonoured customers
              if(!accountMap.isEmpty())
              {
                if(accountMap.get(pay.YourSystemReference)!=null)
                {
                    //Update Ezidebit Dishonour details in Account after settlement
                    Account acct = new Account();
                    acct.Id=accountMap.get(pay.YourSystemReference).Id;
                    acct.LastPaymentStatus__c = 'Dishonour';
                    if(ter.Name!=null && ter.Name=='101')
                    {
                        acct.TR4K_Dishonoured_Date__c=Date.today();
                        acct.TR4K_Reason_For_Dishonour__c=pay.BankFailedReason;
                    }
                    else
                    {
                       acct.Actual_Last_Payment_Status_Date__c=Date.today();
                       acct.Reason_for_Dishonour__c=pay.BankFailedReason;
                    }
                    accountsToUpdate.add(acct); 
                }
              }
              
              if(!oppMap.isEmpty())
              {
                if(oppMap.get(pay.YourSystemReference)!=null && mapoppsToUpdate.get(pay.YourSystemReference)==null)
                {
                    Opportunity opp = new Opportunity();
                    opp.Id = oppMap.get(pay.YourSystemReference).Id;
                    opp.Reason_for_Dishonour__c=pay.BankFailedReason;
                    opp.Ezidebit_Payment_Status_Date__c=Date.today();
                    if(oppMap.get(pay.YourSystemReference).Ezidebit_Payment_Status_Date__c!=null)
                    {
                        opp.Previous_Dishonour_Date__c = oppMap.get(pay.YourSystemReference).Ezidebit_Payment_Status_Date__c;
                    } 
                    //oppsToUpdate.add(opp); 
                    mapoppsToUpdate.put(pay.YourSystemReference,opp);               
                    
                    //Update Ezidebit Dishonour details in Account after settlement
                    Account acct = new Account();
                    acct.Id=oppMap.get(pay.YourSystemReference).AccountId;                  
                    acct.LastPaymentStatus__c = 'Dishonour';
                    acct.Actual_Last_Payment_Status_Date__c=Date.today();
                    acct.Reason_for_Dishonour__c=pay.BankFailedReason;
                    accountsToUpdate.add(acct); 
                }
              }
             
          }
        }   
        
        
    }
}
system.debug('response: '+response);
}

if(ezidebits.size()>0)
{
    insert ezidebits; 
}   

Set<Account> accset = new Set<Account>();
List<Account> finalAcctList = new List<Account>();
Map<String,Account> mapAccount = new Map<String,Account>();
//To eliminate duplicate Id issue
if(accountsToUpdate.size()>0)
{
    //Eliminates duplicate Account object
    accset.addAll(accountsToUpdate);
    finalAcctList.addAll(accset);
    
    //Eliminates duplicate AccountId
    if(finalAcctList.size()>0)
    {
        for(Account acct: finalAcctList)
        {
             mapAccount.put(acct.Id,acct);
        }
    }
    
    if(!mapAccount.isEmpty())
    {
        system.debug('mapAccount.size(): '+mapAccount.size()+'mapAccount.values(): '+mapAccount.values());
        if(!test.isRunningTest()) 
        {
            //update finalAcctList;
            update mapAccount.values();
        }
    }
}

if(mapoppsToUpdate.values().size()>0)
    update mapoppsToUpdate.values();

// One Ezidebit_Dishonour__c per failed debit, and the next successful payment against it.
try
{
    EzidebitDishonourService.capture(allPayments,territoryByPaymentId);
    EzidebitDishonourService.recordRecoveries(allPayments);
}
catch(Exception ex)
{
    ErrorLog.addErrorLog('EzidebitGetPaymentsController','dishonours','',String.valueOf(ex),String.valueOf(ex.getLineNumber()));
}

//Update and blank all Active Agreements Arrears date
/*Map<String,Opportunity> mapOppObj=new Map<String,Opportunity>();
if(!paidAccountIds.isEmpty())
{
    Opportunity[] opportunities = [select id,Account.Id,Applicant2__c,Payment_Frequency_Number__c,Account.New_Payment_Frequency__c,Account.STA_Short_Term_Arrangement__c,Remaining_Amount__c,SCI_sent_date__c,Default_Letter_Sent_Date__c,MP1__c,X6Q__c,X21_D_Sent_Date__c,X21_D_Rem_Amt_Sent_Date__c,Actual_Arrears__c from Opportunity where (Account.Id IN: paidAccountIds OR Applicant2__c IN: paidAccountIds) and StageName in ('Goods Delivered')];
    
    //Populate SMS delay date and make all the arrears date blank in Opportunity
    if(opportunities.size()>0)
    {
        for(Opportunity opp: opportunities)
        {
            Opportunity o = new Opportunity();
            o.Id=opp.Id;

            if(opp.Default_Letter_Sent_Date__c == null)
            {
                o.MP1__c=null;
                o.X6Q__c=null;
                o.X21_D_Sent_Date__c=null;
                o.X21_D_Rem_Amt_Sent_Date__c=null;
                //o.Default_Letter_Sent_Date__c=null;
                //o.SCI_sent_date__c=null;
                o.MP1_Sent_Date_Prev__c=opp.MP1__c;
                o.X6_Q_Sent_Date_Prev__c=opp.X6Q__c;
                o.X21_D_Sent_Date_Prev__c=opp.X21_D_Sent_Date__c;
                o.X21_D_Rem_Amt_Sent_Date_Prev__c=opp.X21_D_Rem_Amt_Sent_Date__c;
            }
            
            Integer days=0;
            days=opp.Payment_Frequency_Number__c.intValue()+1;
            //o.SMS_Date__c=Date.today().addDays(days);
            o.Last_Remaining_Amount__c=opp.Remaining_Amount__c;
            
            mapOppObj.put(o.Id,o);
        }
    }
    /////////////////////////////////////////////
    
    if(!mapOppObj.isEmpty()) 
    update mapOppObj.values();
    
}*/

}

global void finish(Database.BatchableContext BC){
    // Logic to be Executed at finish
       List<String> emailList = new List<String>(); 
       emailList.add('shri@rent4keeps.com.au');
       //emailList.add('anudeep@rent4keeps.com.au');
       Messaging.reserveSingleEmailCapacity(10);
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        for (String mailId : emailList) { // walk through all records which is processed
                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                email.setToAddresses(new String[] {mailId});
                email.setSubject('Ezidebit Settlements have been uploaded');
                email.setHtmlBody('<html><body><p>Dear Admin</p><p>Testing of Ezidebit in Sandbox!!</p><p>Regards</p><p>R4K CRM System</p></body></html>');
                
                //Set email file attachments
                //email.setFileAttachments(attachments);
                
                emails.add(email);
           
        }
        Messaging.sendEmail(emails);
}
}