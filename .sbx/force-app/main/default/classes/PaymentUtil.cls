/*
 * Being part of Payment Reconciliation piece, PaymentUtil class is used by the Payment trigger 
 * to create payment allocation against the scheduled payments of given list of contracts whether 
 * payment is made by applicant 1 or applicant 2 or multi-contracts scenairos. 
 *
 * Payments used to have a rule of allowing 3 day of payment date variance for matching scheduled payment of the month/forthweek/week
 * in practice it is much more accurate when payment amount just allocate to the earlest unpaid scheduled payments. 
 * 
 * In addition, there are chances that a payment amount in the payment record allocated by Centre Link would be more or less than the 
 * scheduled payment amount. In both cases, payment amount needs to be split or merged into pay off multiple or a single scheduled payment(s).
 * 
 * Furthermore, on the last payment paid, the contract is paid off and no more schedule payment will be generated. If the last 
 * payment is overpaid, the remaining amount will be allocated against the last scheduled payment record as there is no
 * more additonal scheduled payment record to allocate to. 
 *
 * @Author: System Partners
 */
public with sharing class PaymentUtil {
    //List of known payment codes.
    public  static final String  RECORDTYPE_PYI510     = 'PYI510'; //Code for creating/updating Applicant Status
    public  static final String  RECORDTYPE_PYI520     = 'PYI520'; //Code for Centrepay payments
    public  static final String  RECORDTYPE_PYI540     = 'PYI540'; //Code for Bank Records
    public  static final String  RECORDTYPE_EZIDEBIT   = 'Ezidebit';
    private static final String  OPPORTUNITY_STAGE_CREATE_PAYMENTS = 'Goods Delivered';
    private static final String  OPPORTUNITY_STAGE_CREATE_PAYMENTS_WRITTENOFF = 'Written Off / Bad Debt';

    //Query dynamically
    public static final String  RECORDTYPE_ID_CENTREPAY = Util.getRecordTypeInfosByDeveloperName('Payment__c').get('Centrepay').Id;
    public static final String  RECORDTYPE_ID_EZIDEBIT  = Util.getRecordTypeInfosByDeveloperName('Payment__c').get('Ezidebit').Id;
    public static final String  RECORDTYPE_ID_DEPOSIT   = Util.getRecordTypeInfosByDeveloperName('Payment__c').get('Deposit').Id;
    public static final String  RECORDTYPE_ID_CASH      = Util.getRecordTypeInfosByDeveloperName('Payment__c').get('Cash').Id;
    public static final String  RECORDTYPE_ID_WINZ      = Util.getRecordTypeInfosByDeveloperName('Payment__c').get('WINZ').Id;
    public static final String  RECORDTYPE_ID_BUYOUT    = Util.getRecordTypeInfosByDeveloperName('Payment__c').get('Buyout').Id;
    public static final String  RECORDTYPE_ID_CREDIT      = Util.getRecordTypeInfosByDeveloperName('Payment__c').get('Credit').Id;

    //public static final String  PAYMENT_ALLOCATION_RECORDTYPE_ID_CENTREPAY = Util.getRecordTypeInfosByDeveloperName('Payment_Allocation__c').get('Centrepay').Id;
    //public static final String  PAYMENT_ALLOCATION_RECORDTYPE_ID_EZIDEBIT  = Util.getRecordTypeInfosByDeveloperName('Payment_Allocation__c').get('Ezidebit').Id;

    private static final Integer PAYMENT_DAY_VARIANCE  = 3;
    private static final Integer BULK_INSERT_NUMBER_PER_BATCH = 200;

    /*
     ****************************************************************
     * Centrepay allocations
     ****************************************************************     
     */
    //Allocate Centrepay Payments
    public static void allocateCentrepayPayments(List<Payment__c> payments) {
              System.debug('>>>>payments>>'+payments);
        Map<String, List<Payment__c>> centrePaymentMap = new Map<String, List<Payment__c>>(); 
        Set<String> CRNs = new Set<String>();
        //Only process payments of Centrepay type and grab the CRN numbers.
        for (Payment__c payment : payments) {
        System.debug('>>>>payment.id>>'+payment.id);
        //System.debug('>>>>payment.RecordTypeId>>'+payment.RecordTypeId);
           if (payment.RecordTypeId == RECORDTYPE_ID_CENTREPAY) {
                String crn = payment.Centrelink_Ref_No__c.replace(' ', '');
                CRNs.add(crn);
                if (!centrePaymentMap.containsKey(crn))
                    centrePaymentMap.put(crn, new List<Payment__c>());
                centrePaymentMap.get(crn).add(payment); 
           }
        }   
        
        System.debug('>>>centrePaymentMap>>'+centrePaymentMap);

        //Retrieve list of active unpaid Scheduled payment order by Opportunity Start Date and then earliest payment due date
        Map<String, List<Scheduled_Payment__c>> unpaidScheduledPayments = getUnpaidScheduledPaymentsByCRN(CRNs);   
        
        //Create Payment Allocation against Scheduled Payments
        List<Payment_Allocation__c> paymentAllocations = new List<Payment_Allocation__c>();
        String paymentCRN = null;
        String lastPaymentCRN = '';
        List<Scheduled_Payment__c> scheduledPayments;
         
        for (List<Payment__c> paymentsByCRN : centrePaymentMap.values()) {
            //Trim off any empty spaces of the CRN number.
            paymentCRN = paymentsByCRN[0].Centrelink_Ref_No__c.replace(' ', '').toUpperCase();
            System.debug('###paymentCRN=' + paymentCRN);
            scheduledPayments = unpaidScheduledPayments.get(paymentCRN);
            System.debug('###scheduledPayments is NULL? ' + (scheduledPayments == null));
            if (scheduledPayments != null) System.debug('###scheduledPayments size: ' + scheduledPayments.size());
            
            for (Payment__c payment : paymentsByCRN) {
                System.debug('###payment.Total_Paid__c=' + payment.Total_Paid__c);
                
                paymentAllocations.addAll(allocatePayments(payment, scheduledPayments,0));    //Create payment allocations against the scheduled payments.
            }
        }
        
        //insert Payment Allocation Records
        if (!paymentAllocations.isEmpty()) {
            insert paymentAllocations;
            /*for (Payment_Allocation__c newPaymentAllocation : paymentAllocations) {
                System.debug('###newPaymentAllocation inserted - recordID: ' + newPaymentAllocation.Id +
                    ' Scheduled Payment ID: ' + newPaymentAllocation.Scheduled_Payment__c + 
                    ' - Payment ID: ' + newPaymentAllocation.Payment__c + ' - Payment Date: ' + newPaymentAllocation.Payment_Date__c +
                    ' - Contract: ' + newPaymentAllocation.Contract__c + ' - Amount: ' + newPaymentAllocation.Actual_Amount__c);
            }*/
        }
    }
    
    //CRN__c = Centrepay_Ref_No__c without white spaces
    private static Map<String, List<Scheduled_Payment__c>> getUnpaidScheduledPaymentsByCRN(Set<String> centrepayPayments) {
        System.debug('>>>centrepayPayments >>'+centrepayPayments);
        Date startPaymentDate = getStartPaymentDate();
        System.debug('>>>startPaymentDate >>'+startPaymentDate);
        Date endPaymentDate   = getEndPaymentDate();
        System.debug('>>>endPaymentDate>>'+endPaymentDate);
        System.debug('###centrepayPayments is null? ' + (centrepayPayments == null));
        if (centrepayPayments != null) System.debug('###centrepayPayments in getUnpaidScheduledPaymentsByCRN: ' + centrepayPayments);
        
        Map<String, List<Scheduled_Payment__c>> result = new Map<String, List<Scheduled_Payment__c>>();
        List<Opportunity> tr4kHistoricActiveOppList = getAllHistoricActiveTR4K(centrepayPayments);
        List<Scheduled_Payment__c> unpaidScheduledPayments = new List<Scheduled_Payment__c>();
        
        if(tr4kHistoricActiveOppList.size()>0)
        {
        List<Scheduled_Payment__c> unPaidSpsMainAgmts = [SELECT Id, 
                                Name,
                                Opportunity__c,
                                Opportunity__r.Account.Centrepay_Ref_No__c,
                                Opportunity__r.Account.CRN__c,
                                Opportunity__r.Account.Territory_Number__r.State_Master_State__c,
                                Opportunity__r.Applicant2__r.Centrepay_Ref_No__c,
                                Opportunity__r.Applicant2__r.CRN__c,
                                Opportunity__r.StageName, 
                                Paid_Amount__c,
                                Scheduled_Amount__c,
                                Remaining_Amount__c,
                                Scheduled_Date__c,
                                Opportunity__r.Start_Date__c 
                      FROM      Scheduled_Payment__c
                      WHERE     Fully_Paid__c <> 'Yes'
                      AND        Opportunity__r.Is_Active__c   = true
                      AND        Opportunity__r.Is_Credit_Contract__c   = false
                      AND       Opportunity__r.StageName = :OPPORTUNITY_STAGE_CREATE_PAYMENTS
                      AND      (Opportunity__r.Account.CRN__c IN :centrepayPayments OR Opportunity__r.Applicant2__r.CRN__c IN :centrepayPayments) and Opportunity__r.RecordType.Name<>'Trak SIM'
                      ORDER BY  Scheduled_Date__c, 
                                Opportunity__r.Start_Date__c];
                                
        List<Scheduled_Payment__c> unPaidSpsTR4KAgmts = [SELECT Id, 
                                Name,
                                Opportunity__c,
                                Opportunity__r.Account.Centrepay_Ref_No__c,
                                Opportunity__r.Account.CRN__c,
                                Opportunity__r.Account.Territory_Number__r.State_Master_State__c,
                                Opportunity__r.Applicant2__r.Centrepay_Ref_No__c,
                                Opportunity__r.Applicant2__r.CRN__c,
                                Opportunity__r.StageName, 
                                Paid_Amount__c,
                                Scheduled_Amount__c,
                                Remaining_Amount__c,
                                Scheduled_Date__c,
                                Opportunity__r.Start_Date__c 
                      FROM      Scheduled_Payment__c
                      WHERE     Fully_Paid__c <> 'Yes'
                      AND        Opportunity__r.Is_Credit_Contract__c   = false
                      AND      Opportunity__c=:tr4kHistoricActiveOppList
                      ORDER BY  Scheduled_Date__c, 
                                Opportunity__r.Start_Date__c];
        
        unPaidSpsMainAgmts.addAll(unPaidSpsTR4KAgmts);
        
        unpaidScheduledPayments = [SELECT Id, 
                                Name,
                                Opportunity__c,
                                Opportunity__r.Account.Centrepay_Ref_No__c,
                                Opportunity__r.Account.CRN__c,
                                Opportunity__r.Account.Territory_Number__r.State_Master_State__c,
                                Opportunity__r.Applicant2__r.Centrepay_Ref_No__c,
                                Opportunity__r.Applicant2__r.CRN__c,
                                Opportunity__r.StageName, 
                                Paid_Amount__c,
                                Scheduled_Amount__c,
                                Remaining_Amount__c,
                                Scheduled_Date__c,
                                Opportunity__r.Start_Date__c 
                      FROM      Scheduled_Payment__c where id IN: unPaidSpsMainAgmts
                      ORDER BY  Scheduled_Date__c, 
                                Opportunity__r.Start_Date__c];
        }
        else
        {
            unpaidScheduledPayments = [SELECT Id, 
                                Name,
                                Opportunity__c,
                                Opportunity__r.Account.Centrepay_Ref_No__c,
                                Opportunity__r.Account.CRN__c,
                                Opportunity__r.Account.Territory_Number__r.State_Master_State__c,
                                Opportunity__r.Applicant2__r.Centrepay_Ref_No__c,
                                Opportunity__r.Applicant2__r.CRN__c,
                                Opportunity__r.StageName, 
                                Paid_Amount__c,
                                Scheduled_Amount__c,
                                Remaining_Amount__c,
                                Scheduled_Date__c,
                                Opportunity__r.Start_Date__c 
                      FROM      Scheduled_Payment__c
                      WHERE     Opportunity__r.Is_Active__c   = true
                      AND        Opportunity__r.Is_Credit_Contract__c   = false
                      AND       Opportunity__r.RecordType.Name <> 'Trak SIM' 
                      AND       Fully_Paid__c <> 'Yes'
                      AND       Opportunity__r.StageName = :OPPORTUNITY_STAGE_CREATE_PAYMENTS
                      AND      (Opportunity__r.Account.CRN__c IN :centrepayPayments OR Opportunity__r.Applicant2__r.CRN__c IN :centrepayPayments)
                      ORDER BY  Scheduled_Date__c,  //Ensure records are sorted by Opportunity Start Date first!?
                                Opportunity__r.Start_Date__c];
        }
        
        //use index to ensure list order is maintained
            
            for (Scheduled_Payment__c payment: unpaidScheduledPayments) {
                System.debug('###payment in getUnpaidScheduledPaymentsByCRN loop: ' + payment);
                //initialise Remaining_Amount__c
                payment.Remaining_Amount__c = payment.Scheduled_Amount__c - payment.Paid_Amount__c; 
                
                //add applicant 1
                if (!result.containsKey(payment.Opportunity__r.Account.CRN__c))
                    result.put(payment.Opportunity__r.Account.CRN__c, new List<Scheduled_Payment__c>());
              
                result.get(payment.Opportunity__r.Account.CRN__c).add(payment);    
                
                //add applicant 2 
                if (payment.Opportunity__r.Applicant2__c != null && payment.Opportunity__r.Applicant2__r.CRN__c != null) {
                    if (!result.containsKey(payment.Opportunity__r.Applicant2__r.CRN__c))
                        result.put(payment.Opportunity__r.Applicant2__r.CRN__c, new List<Scheduled_Payment__c>());
                    
                    result.get(payment.Opportunity__r.Applicant2__r.CRN__c).add(payment);  
                }
            }
        System.debug('###result size: ' + result.size());   
        if (result.size() > 0) for (String key : result.keySet()) { System.debug('###key - ' + key + ' : list size - ' + result.get(key).size()); }
        return result;        
    }
    /*
     ****************************************************************
     * Manual allocations
     ****************************************************************
     */
     public static void allocatePaymentsManually(Map<String,Decimal> mapOpp,Payment__c payment) {

        //Create Payment Allocation against Scheduled Payments
        List<Payment_Allocation__c> paymentAllocations = new List<Payment_Allocation__c>();
        List<Scheduled_Payment__c> scheduledPayments = new List<Scheduled_Payment__c>();
        
        for(String oppId : mapOpp.keySet())
        {
            scheduledPayments=getUnpaidScheduledPaymentsManually(oppId);
            if (scheduledPayments != null) 
            {
                System.debug('###scheduledPayments size: ' + scheduledPayments.size());    
                paymentAllocations.addAll(allocatePayments(payment, scheduledPayments,mapOpp.get(oppId)));    //Create payment allocations against the scheduled payments.
            }
        }

        //insert Payment Allocation Records
        if (!paymentAllocations.isEmpty()) {
            insert paymentAllocations;
            for (Payment_Allocation__c newPaymentAllocation : paymentAllocations) {
                System.debug('###newPaymentAllocation inserted - recordID: ' + newPaymentAllocation.Id +
                    ' Scheduled Payment ID: ' + newPaymentAllocation.Scheduled_Payment__c + 
                    ' - Payment ID: ' + newPaymentAllocation.Payment__c + ' - Payment Date: ' + newPaymentAllocation.Payment_Date__c +
                    ' - Contract: ' + newPaymentAllocation.Contract__c + ' - Amount: ' + newPaymentAllocation.Actual_Amount__c);
            }
        }
    }
    
    private static List<Scheduled_Payment__c> getUnpaidScheduledPaymentsManually(String oppId) {
        Date startPaymentDate = getStartPaymentDate();
        System.debug('>>>startPaymentDate >>'+startPaymentDate);
        Date endPaymentDate   = getEndPaymentDate();
        System.debug('>>>endPaymentDate>>'+endPaymentDate);
        
        List<Scheduled_Payment__c> result = new List<Scheduled_Payment__c>();
        
        //use index to ensure list order is maintained
        for(List<Scheduled_Payment__c> unpaidScheduledPayments : 
                        [SELECT Id, 
                                Name,
                                Opportunity__c,
                                Opportunity__r.Account.Centrepay_Ref_No__c,
                                Opportunity__r.Account.CRN__c,
                                Opportunity__r.Account.Territory_Number__r.State_Master_State__c,
                                Opportunity__r.Applicant2__r.Centrepay_Ref_No__c,
                                Opportunity__r.Applicant2__r.CRN__c,
                                Opportunity__r.StageName, 
                                Paid_Amount__c,
                                Scheduled_Amount__c,
                                Remaining_Amount__c,
                                Scheduled_Date__c,
                                Opportunity__r.Start_Date__c 
                      FROM      Scheduled_Payment__c
                      WHERE     Opportunity__r.Id=:oppId
                      AND       Opportunity__r.Is_Credit_Contract__c   = false
                      ORDER BY  Scheduled_Date__c]) {
            
            for (Scheduled_Payment__c payment: unpaidScheduledPayments) {
                System.debug('###payment in getUnpaidScheduledPaymentsByCRN loop: ' + payment);
                //initialise Remaining_Amount__c
                payment.Remaining_Amount__c = payment.Scheduled_Amount__c - payment.Paid_Amount__c; 
                
               /* if (!result.containsKey(payment.Opportunity__r.Id))
                    result.put(payment.Opportunity__r.Id, new List<Scheduled_Payment__c>());
              
                result.get(payment.Opportunity__r.Id).add(payment);*/
                result.add(payment);
            }
        }          
        System.debug('###result size: ' + result.size());   
        if (result.size() > 0) 
            return result;   
        else
            return null;     
    }
    
    /*
     ****************************************************************
     * EziDebit allocations
     ****************************************************************
     */
    //Allocate Ezidebit Payments
    public static void allocateEzidebitPayments(List<Payment__c> payments) {
        system.debug('pymntSize: '+payments.size());
        Map<String, List<Payment__c>> ezidebitPayments = new Map<String, List<Payment__c>>();
        for (Payment__c payment :payments) {
            if (payment.RecordTypeId == RECORDTYPE_ID_EZIDEBIT) {
                if (!ezidebitPayments.containsKey(payment.Ezidebit_Ref_No__c))
                    ezidebitPayments.put(payment.Ezidebit_Ref_No__c, new List<Payment__c>());
                ezidebitPayments.get(payment.Ezidebit_Ref_No__c).add(payment);
            }
        }

        //Retrieve list of active unpaid Scheduled payment order by Opportunity Start Date and then earliest payment due date
        Map<String, List<Scheduled_Payment__c>> unpaidScheduledPayments = getUnpaidScheduledPaymentsByERN(ezidebitPayments.keySet());   
        
        //Create Payment Allocation against Scheduled Payments
        List<Payment_Allocation__c> paymentAllocations = new List<Payment_Allocation__c>();
        List<Scheduled_Payment__c> scheduledPayments; 
        
        for (List<Payment__c> paymentsByERN : ezidebitPayments.values()) {
            System.debug('###paymentsByERN size: ' + paymentsByERN.size());
            
            scheduledPayments = unpaidScheduledPayments.get(paymentsByERN[0].Ezidebit_Ref_No__c);
            
            system.debug('sps: '+scheduledPayments);
            //system.debug('ern: '+paymentsByERN[0].Ezidebit_Ref_No__c+ ' size: '+scheduledPayments.size());
            if (scheduledPayments == null) continue;
            
            for (Payment__c payment :paymentsByERN) {
                System.debug('###scheduledPayments.size(): ' + scheduledPayments.size());

                paymentAllocations.addAll(allocatePayments(payment, scheduledPayments,0));
            }
        }
        
        //Insert Payment Allocation Records
        if (paymentAllocations.size() > 0)
            insert paymentAllocations;
    }
    
    /*
     ****************************************************************
     * EziDebit allocations for CreditContracts
     ****************************************************************
     */
    //Allocate Ezidebit Payments
    public static void allocateEzidebitPaymentsForCreditContract(List<Payment__c> payments) {
        //Create a map for agreementId with payments
        system.debug('pymntSize: '+payments.size());
        Map<String, List<Payment__c>> ezidebitPayments = new Map<String, List<Payment__c>>();
        for (Payment__c payment :payments) {
            if (payment.RecordTypeId == RECORDTYPE_ID_EZIDEBIT) {
                if (!ezidebitPayments.containsKey(payment.Customer_Account_No__c))
                    ezidebitPayments.put(payment.Customer_Account_No__c, new List<Payment__c>());
                ezidebitPayments.get(payment.Customer_Account_No__c).add(payment);
            }
        }
        
        //Get map of agreement with all values
        Map<String, Opportunity> mapCreditContract = getCreditContractList(ezidebitPayments.keySet()); 
        
        //Create And Retrived SPs
        Map<String, Scheduled_Payment__c> mapSPCreditContract = createAndGetSchedulePaymentsForCreditContracts(payments,mapCreditContract); 
        
        
        //Create a PA and allocate it to the SP
        createPaymentAllocationsForCreditContracts(payments,mapCreditContract,mapSPCreditContract);
    }
    
    /*
     ****************************************************************
     * Cash Payment allocations for CreditContracts
     ****************************************************************
     */
    //Allocate Cash Payments
    public static void allocateCashPaymentsForCreditContract(Payment__c payment) {
        //Create a map for agreementId with payments
        system.debug('##contractNo: '+payment.ContractNo__c);
        List<Payment__c> payments = new List<Payment__c>();
        Set<String> agreementIds = new Set<String>();
        payments.add(payment);
        agreementIds.add(payment.Agreement__c);
        
        //Get map of agreement with all values
        Map<String, Opportunity> mapCreditContract = getCreditContractList(agreementIds); 
        
        //Create And Retrived SPs
        Map<String, Scheduled_Payment__c> mapSPCreditContract = createAndGetSchedulePaymentsForCreditContracts(payments,mapCreditContract); 
        
        
        //Create a PA and allocate it to the SP
        createPaymentAllocationsForCreditContracts(payments,mapCreditContract,mapSPCreditContract);
    }
    
    /*
     ****************************************************************
     * WINZ allocations for CreditContracts
     ****************************************************************
     */
    //Allocate WINZ Payments
    public static void allocateWINZPaymentsForCreditContract(List<Payment__c> payments) {
        //Create a map for agreementId with payments
        system.debug('pymntSize: '+payments.size());
        Map<String, List<Payment__c>> winzPayments = new Map<String, List<Payment__c>>();
        for (Payment__c payment :payments) {
            if (payment.RecordTypeId == RECORDTYPE_ID_WINZ) {
                if (!winzPayments.containsKey(payment.Customer_Account_No__c))
                    winzPayments.put(payment.Customer_Account_No__c, new List<Payment__c>());
                winzPayments.get(payment.Customer_Account_No__c).add(payment);
            }
        }
        
        //Get map of agreement with all values
        Map<String, Opportunity> mapCreditContract = getCreditContractList(winzPayments.keySet()); 
        
        //Create And Retrived SPs
        Map<String, Scheduled_Payment__c> mapSPCreditContract = createAndGetSchedulePaymentsForCreditContracts(payments,mapCreditContract); 
        
        
        //Create a PA and allocate it to the SP
        createPaymentAllocationsForCreditContracts(payments,mapCreditContract,mapSPCreditContract);
    }
    
    private static Map<String,Opportunity> getCreditContractList(Set<String> identifiers)
    {
        system.debug('identifiers: '+identifiers);
        Map<String, Opportunity> result = new Map<String, Opportunity>();
        List<Opportunity> allCreditContracts = [select id,name,Contract_No__c,Start_Date__c,Last_Payment_Received_Date__c,Last_Payment_Upload_Date_Rollup__c,Total_Loan_Balance_Amount__c,Scheduled_Amount__c,
                                                Payment_Frequency_Number__c,NextAvailableScheduledDate__c,Account.Territory_Number__r.State_Master_State__c,Daily_Interest_Rate__c,Ezidebit_Starting_Date__c,Is_in_Hardship__c,Payment_On_Hold_End_Date__c,Unpaid_Interest_Amount__c
                                                from Opportunity where (Contract_No__c in: identifiers or id in:identifiers)  and Is_Credit_Contract__c=true];
        
        for(Opportunity opp: allCreditContracts)
        {
        if (!result.containsKey(opp.Contract_No__c))
            result.put(opp.Contract_No__c, opp);
        }
        
        return result;
    }
    
    private static Map<String,Scheduled_Payment__c> createAndGetSchedulePaymentsForCreditContracts(List<Payment__c> payments,Map<String, Opportunity> mapCreditContract)
    {
        Map<String, Scheduled_Payment__c> result = new Map<String, Scheduled_Payment__c>();
        List<Scheduled_Payment__c> spsToInsert = new List<Scheduled_Payment__c>();
        List<Scheduled_Payment__c> alreadyInsertedSps = new List<Scheduled_Payment__c>();
        List<Payment__c> morePaymentsDoneToday = new List<Payment__c>();
        for (Payment__c payment :payments) {
            if(!mapCreditContract.IsEmpty() && mapCreditContract.get(payment.ContractNo__c)!=null)
            {
                Scheduled_Payment__c scheduledPayment = new Scheduled_Payment__c();
                scheduledPayment.Opportunity__c      = mapCreditContract.get(payment.ContractNo__c).Id;
                scheduledPayment.Scheduled_Amount__c = mapCreditContract.get(payment.ContractNo__c).Scheduled_Amount__c;
                if(mapCreditContract.get(payment.ContractNo__c).Account.Territory_Number__r.State_Master_State__c=='NZ')
                    scheduledPayment.CurrencyISOCode='NZD';
                
                //firstExpectedPaymentDate (startDate + Payment Frequency, or Ezidebit Starting Date + 5 days) is now only a fallback for an agreement with no Start_Date__c; see paymentFrequencyNumber below
                Date firstExpectedPaymentDate;
                //Date lastpaymentUploadDate =  mapCreditContract.get(payment.ContractNo__c).Last_Payment_Upload_Date_Rollup__c!=null ? date.newinstance(mapCreditContract.get(payment.ContractNo__c).Last_Payment_Upload_Date_Rollup__c.year(), mapCreditContract.get(payment.ContractNo__c).Last_Payment_Upload_Date_Rollup__c.month(), mapCreditContract.get(payment.ContractNo__c).Last_Payment_Upload_Date_Rollup__c.day()) : null;
                Date lastpaymentUploadDate =  mapCreditContract.get(payment.ContractNo__c).Last_Payment_Received_Date__c!=null ? date.newinstance(mapCreditContract.get(payment.ContractNo__c).Last_Payment_Received_Date__c.year(), mapCreditContract.get(payment.ContractNo__c).Last_Payment_Received_Date__c.month(), mapCreditContract.get(payment.ContractNo__c).Last_Payment_Received_Date__c.day()) : null;
                /*Date paymentOnHoldEndDate = mapCreditContract.get(payment.ContractNo__c).Payment_On_Hold_End_Date__c!=null ? date.newinstance(mapCreditContract.get(payment.ContractNo__c).Payment_On_Hold_End_Date__c.year(), mapCreditContract.get(payment.ContractNo__c).Payment_On_Hold_End_Date__c.month(), mapCreditContract.get(payment.ContractNo__c).Payment_On_Hold_End_Date__c.day()) : null;
                if(paymentOnHoldEndDate!=null && paymentOnHoldEndDate>lastpaymentUploadDate)
                {
                    lastpaymentUploadDate = paymentOnHoldEndDate;
                }*/
                
                if(lastpaymentUploadDate==null)
                {
                if(mapCreditContract.get(payment.ContractNo__c).Start_Date__c!=null)
                    firstExpectedPaymentDate =  mapCreditContract.get(payment.ContractNo__c).Payment_Frequency_Number__c==7 ?  mapCreditContract.get(payment.ContractNo__c).Start_Date__c.addDays(7) : mapCreditContract.get(payment.ContractNo__c).Start_Date__c.addDays(14);
                if(payment.RecordTypeId == RECORDTYPE_ID_EZIDEBIT && mapCreditContract.get(payment.ContractNo__c).Ezidebit_Starting_Date__c!=null)
                    firstExpectedPaymentDate = mapCreditContract.get(payment.ContractNo__c).Ezidebit_Starting_Date__c.addDays(5);
                }
                ////////////////////////////////////////////////////////////////////////
                
                scheduledPayment.Scheduled_Date__c   = mapCreditContract.get(payment.ContractNo__c).NextAvailableScheduledDate__c==null ? mapCreditContract.get(payment.ContractNo__c).Start_Date__c : mapCreditContract.get(payment.ContractNo__c).NextAvailableScheduledDate__c!=null && mapCreditContract.get(payment.ContractNo__c).Payment_Frequency_Number__c==7 ? mapCreditContract.get(payment.ContractNo__c).NextAvailableScheduledDate__c.addDays(7) : mapCreditContract.get(payment.ContractNo__c).NextAvailableScheduledDate__c.addDays(14);
                scheduledPayment.Loan_Balance_Amount__c = mapCreditContract.get(payment.ContractNo__c).Total_Loan_Balance_Amount__c<=0 ? 0 : mapCreditContract.get(payment.ContractNo__c).Total_Loan_Balance_Amount__c;
                scheduledPayment.Daily_Interest_Rate__c = mapCreditContract.get(payment.ContractNo__c).Daily_Interest_Rate__c;
                scheduledPayment.Is_in_Hardship__c = mapCreditContract.get(payment.ContractNo__c).Is_in_Hardship__c;
                scheduledPayment.Is_Early_Payout__c = payment.Is_Early_Payout__c!=null ? payment.Is_Early_Payout__c : false;
                scheduledPayment.Exclude_Interest__c = payment.Exclude_Interest__c!=null ? payment.Exclude_Interest__c : false;
                scheduledPayment.Accrued_Unpaid_Interest_Amount__c = mapCreditContract.get(payment.ContractNo__c).Unpaid_Interest_Amount__c > 0.01 ? mapCreditContract.get(payment.ContractNo__c).Unpaid_Interest_Amount__c : 0;
                
                //Make sure if the payment frequency number should be between createdDates or PaymentDates
                Date paymentDate = ((payment.Payment_Date__c!=null && payment.Payment_Date__c>=lastpaymentUploadDate) || (payment.Payment_Date__c!=null && lastpaymentUploadDate==null)) ? payment.Payment_Date__c : Date.today();
                // Days of interest this payment closes. The first payment's period runs from the
                // agreement start date (the opening balance) to the payment date, however short:
                // the contract calculates interest daily on the unpaid daily balance (cl 7.6, NCC s 28).
                // It used to run from the Ezidebit start date + 5 days with a minimum of one payment
                // period, which overcharged every first payment made within the first period.
                // Until Compliance decides on delayed deliveries, a first payment is never charged
                // more days than that old rule gave (a late first payment was charged from the
                // Ezidebit start, not the start date), so the lower of the two is used.
                Date agreementStartDate = mapCreditContract.get(payment.ContractNo__c).Start_Date__c;
                Integer paymentFrequencyNumber;
                if(lastpaymentUploadDate!=null)
                    paymentFrequencyNumber = Integer.valueOf(lastpaymentUploadDate.daysBetween(paymentDate));
                else
                {
                    Integer oldRuleFirstPaymentDays = (firstExpectedPaymentDate!=null && firstExpectedPaymentDate.daysBetween(paymentDate) >  mapCreditContract.get(payment.ContractNo__c).Payment_Frequency_Number__c) ? Integer.valueOf(firstExpectedPaymentDate.daysBetween(paymentDate)) :  Integer.valueOf(mapCreditContract.get(payment.ContractNo__c).Payment_Frequency_Number__c);
                    if(agreementStartDate==null)
                        paymentFrequencyNumber = oldRuleFirstPaymentDays;
                    else if(oldRuleFirstPaymentDays==null)
                        paymentFrequencyNumber = Math.max(0, agreementStartDate.daysBetween(paymentDate));
                    else
                        paymentFrequencyNumber = Math.min(Math.max(0, agreementStartDate.daysBetween(paymentDate)), oldRuleFirstPaymentDays);
                }
                system.debug('##lastpaymentUploadDate: '+lastpaymentUploadDate+' paymentDate: '+paymentDate+' paymentFrequencyNumber: '+paymentFrequencyNumber+' startDate: '+mapCreditContract.get(payment.ContractNo__c).Start_Date__c);
                scheduledPayment.Payment_Frequency_Number__c =  paymentFrequencyNumber;
                // A first payment made on the start date closes a 0-day period but still needs
                // its own scheduled payment: there is no earlier one to allocate it to.
                if(paymentFrequencyNumber>0 || lastpaymentUploadDate==null)
                    spsToInsert.add(scheduledPayment);
                else
                    morePaymentsDoneToday.add(payment);
             }
          }
          
          if(spsToInsert.size()>0)
              insert spsToInsert;
          if(morePaymentsDoneToday.size()>0)
              alreadyInsertedSps.addAll(getRecentSchedulePayments(morePaymentsDoneToday));
              
          system.debug('##spsToInsert: '+spsToInsert.size()+' ##alreadyInsertedSps: '+alreadyInsertedSps.size());
          List<Scheduled_Payment__c> insertedSPs = [select id,name,Opportunity__c,Opportunity__r.Contract_No__c from Scheduled_Payment__c where id in: spsToInsert or id in: alreadyInsertedSps];
          for(Scheduled_Payment__c sp: insertedSPs)
          {
              if (!result.containsKey(sp.Opportunity__r.Contract_No__c))
                  result.put(sp.Opportunity__r.Contract_No__c, sp);
          }
          
          return result;
    }
    
    private static List<Scheduled_Payment__c> getRecentSchedulePayments(List<Payment__c> payments)
    {
        Set<String> oppsIdsInPayments = new Set<String>();
        Map<Id,Scheduled_Payment__c> mapspsToUpdate = new Map<Id,Scheduled_Payment__c>();
        List<Scheduled_Payment__c> spsToUpdate = new List<Scheduled_Payment__c>();
        if(payments.size()>0)
        {
            for(Payment__c payment : payments)
            {
                //List<Scheduled_Payment__c> insertedSPs = [select id,name,Opportunity__c,Opportunity__r.Contract_No__c from Scheduled_Payment__c where Payment_received_date__c=:payment.Payment_Date__c and Opportunity__c=:payment.Agreement__c order by CreatedDate desc LIMIT 1];
                oppsIdsInPayments.add(payment.Agreement__c);
            }
            List<Scheduled_Payment__c> insertedSPs = [select id,name,Opportunity__c,Opportunity__r.Contract_No__c,Payment_received_date__c from Scheduled_Payment__c where Opportunity__c in: oppsIdsInPayments and Payment_received_date__c= LAST_n_days:90 order by CreatedDate desc];
            
            if(insertedSPs.size()>0)
            {
                for(Payment__c payment : payments)
                {
                    for(Scheduled_Payment__c sp: insertedSPs)
                    {
                        if(sp.Payment_received_date__c==payment.Payment_Date__c && sp.Opportunity__c==payment.Agreement__c && mapspsToUpdate.get(payment.Id)==null)
                            mapspsToUpdate.put(payment.Id,sp);
                    }
                }
                spsToUpdate =  mapspsToUpdate.values();
                system.debug('##getRecentSchedulePayments: '+spsToUpdate);
            }
        }
        return spsToUpdate;
    }
    
    private static void createPaymentAllocationsForCreditContracts(List<Payment__c> payments,Map<String, Opportunity> mapCreditContract,Map<String, Scheduled_Payment__c> mapSPCreditContract)
    {
        List<Payment_Allocation__c> insertPAForCreditContract = new List<Payment_Allocation__c>();
        for(Payment__c payment : payments)
        {
            if(!mapCreditContract.IsEmpty() && mapCreditContract.get(payment.ContractNo__c)!=null && !mapSPCreditContract.IsEmpty() && mapSPCreditContract.get(payment.ContractNo__c)!=null)
            {
                Payment_Allocation__c paymentAllocation = new Payment_Allocation__c();
                paymentAllocation.Scheduled_Payment__c = mapSPCreditContract.get(payment.ContractNo__c).Id;
                paymentAllocation.Payment__c           = payment.Id;
                paymentAllocation.Contract__c          =  mapCreditContract.get(payment.ContractNo__c).Id;
                paymentAllocation.Payment_Date__c      = payment.Payment_Date__c; 
                paymentAllocation.Actual_Amount__c     = payment.Actual_Amount__c;
                
                paymentAllocation.Client_Fees__c       = payment.Client_Fees__c;
                paymentAllocation.Fee_Amount__c        = payment.Fee_Amount__c;
                paymentAllocation.Setup_Fee__c         = payment.Setup_Fee__c;
               
                if(mapCreditContract.get(payment.ContractNo__c).Account.Territory_Number__r.State_Master_State__c=='NZ')
                    paymentAllocation.CurrencyISOCode='NZD';
                insertPAForCreditContract.add(paymentAllocation);
            }
        }
        if(insertPAForCreditContract.size()>0)
            insert insertPAForCreditContract;
           
    }

    /*
     * helper method to get all unpaid Ezidebit type scheduled payments using ERN numbers.
     */
    private static Map<String, List<Scheduled_Payment__c>> getUnpaidScheduledPaymentsByERN(Set<String> ernSet) {
        Date startPaymentDate = getStartPaymentDate();
        Date endPaymentDate   = getEndPaymentDate();
        
        Date tr4kCutOffDate;
        
        try{
            tr4kCutOffDate=Date.parse('16/09/2020');
        }catch(Exception ex){
            system.debug('ExceptionType: '+ex);
            tr4kCutOffDate=Date.newInstance(2020,09,16);
        }
        
        System.debug('>> OPPORTUNITY_STAGE_CREATE_PAYMENTS >>'+OPPORTUNITY_STAGE_CREATE_PAYMENTS);
        System.debug('>>ernSet >>'+ernSet );
        
        if(ernSet.size()>0)
            ernSet.remove(null);
        System.debug('>>ernSet >>'+ernSet );
        //List<Scheduled_Payment__c> sps=[SELECT Id, Name, Opportunity__c, Opportunity__r.Account.Ezidebit_Ref_No__c, Opportunity__r.Account.Territory_Number__r.State_Master_State__c, Opportunity__r.Applicant2__r.Ezidebit_Ref_No__c, Opportunity__r.StageName, Opportunity__r.Start_Date__c, Paid_Amount__c, Scheduled_Amount__c, Remaining_Amount__c, Scheduled_Date__c FROM Scheduled_Payment__c WHERE Opportunity__r.Is_Active__c = true AND Fully_Paid__c <> 'Yes' AND Fully_Paid__c <> 'Yes' AND Opportunity__r.StageName = 'Goods Delivered' AND (Opportunity__r.Account.Ezidebit_Ref_No__c ='210-380-480')];
        //system.debug('##sps: '+sps.size());
        //Scheduled_Payment__c payment = null;
        Map<String, List<Scheduled_Payment__c>> result = new Map<String, List<Scheduled_Payment__c>>();
        //use index to ensure list order is maintained
        
        List<Scheduled_Payment__c> unPaidSpsAll = new List<Scheduled_Payment__c>();
        List<Scheduled_Payment__c> unPaidSpsTR4K = new List<Scheduled_Payment__c>();
        List<Scheduled_Payment__c> unpaidScheduledPayments = new List<Scheduled_Payment__c>();
        List<Opportunity> tr4kHistoricActiveOppList = getAllHistoricActiveTR4K(ernSet);
        
        if(tr4kHistoricActiveOppList.size()>0)
        {
        List<Scheduled_Payment__c> unPaidSpsMainAgmts = [SELECT   Id, 
                              Name,
                              Opportunity__c,
                              Opportunity__r.Account.Ezidebit_Ref_No__c,
                              Opportunity__r.Account.Territory_Number__r.State_Master_State__c,
                              Opportunity__r.Applicant2__r.Ezidebit_Ref_No__c,
                              Opportunity__r.StageName,
                              Paid_Amount__c,
                              Scheduled_Amount__c,
                              Remaining_Amount__c,
                              Scheduled_Date__c ,
                              Opportunity__r.Start_Date__c,
                              Opportunity__r.Account.TR4K_ERN__c,Opportunity__r.RecordType.Name,Opportunity__r.Name,Opportunity__r.TaxInvoice_Signed_DateTime__c,Opportunity__r.TR4K_Deduction_Form_Signed_DateTime__c
                    FROM      Scheduled_Payment__c
                    WHERE     Opportunity__r.Is_Active__c   = true
                    AND       Opportunity__r.Is_Credit_Contract__c   = false
                    AND       Fully_Paid__c <> 'Yes'
                    AND       Opportunity__r.StageName = :OPPORTUNITY_STAGE_CREATE_PAYMENTS
                    AND      (Opportunity__r.Account.Ezidebit_Ref_No__c IN :ernSet OR
                              Opportunity__r.Applicant2__r.Ezidebit_Ref_No__c IN :ernSet) and Opportunity__r.RecordType.Name<>'Trak SIM'  
                              ORDER BY  Scheduled_Date__c];
                              
        List<Scheduled_Payment__c> unPaidSpsTR4KAgmts = [SELECT   Id, 
                              Name,
                              Opportunity__c,
                              Opportunity__r.Account.Ezidebit_Ref_No__c,
                              Opportunity__r.Account.Territory_Number__r.State_Master_State__c,
                              Opportunity__r.Applicant2__r.Ezidebit_Ref_No__c,
                              Opportunity__r.StageName,
                              Paid_Amount__c,
                              Scheduled_Amount__c,
                              Remaining_Amount__c,
                              Scheduled_Date__c ,
                              Opportunity__r.Start_Date__c,
                              Opportunity__r.Account.TR4K_ERN__c,Opportunity__r.RecordType.Name,Opportunity__r.Name,Opportunity__r.TaxInvoice_Signed_DateTime__c,Opportunity__r.TR4K_Deduction_Form_Signed_DateTime__c
                    FROM      Scheduled_Payment__c
                    WHERE     Opportunity__r.Is_Active__c   = true
                    AND       Opportunity__r.Is_Credit_Contract__c   = false
                    AND       Fully_Paid__c <> 'Yes'
                    AND       Opportunity__c IN:tr4kHistoricActiveOppList 
                              ORDER BY  Scheduled_Date__c];
         
         unPaidSpsMainAgmts.addAll(unPaidSpsTR4KAgmts);
         
         unPaidSpsAll = [SELECT   Id, 
                              Name,
                              Opportunity__c,
                              Opportunity__r.Account.Ezidebit_Ref_No__c,
                              Opportunity__r.Account.Territory_Number__r.State_Master_State__c,
                              Opportunity__r.Applicant2__r.Ezidebit_Ref_No__c,
                              Opportunity__r.StageName,
                              Paid_Amount__c,
                              Scheduled_Amount__c,
                              Remaining_Amount__c,
                              Scheduled_Date__c ,
                              Opportunity__r.Start_Date__c,
                              Opportunity__r.Account.TR4K_ERN__c,Opportunity__r.RecordType.Name,Opportunity__r.Name,Opportunity__r.TaxInvoice_Signed_DateTime__c,Opportunity__r.TR4K_Deduction_Form_Signed_DateTime__c
                    FROM      Scheduled_Payment__c where id in: unPaidSpsMainAgmts order by Scheduled_Date__c];
        }
        else
        {
            unPaidSpsAll = [SELECT    Id, 
                              Name,
                              Opportunity__c,
                              Opportunity__r.Account.Ezidebit_Ref_No__c,
                              Opportunity__r.Account.Territory_Number__r.State_Master_State__c,
                              Opportunity__r.Applicant2__r.Ezidebit_Ref_No__c,
                              Opportunity__r.StageName,
                              Paid_Amount__c,
                              Scheduled_Amount__c,
                              Remaining_Amount__c,
                              Scheduled_Date__c ,
                              Opportunity__r.Start_Date__c,Opportunity__r.Account.TR4K_ERN__c,Opportunity__r.RecordType.Name,Opportunity__r.Name,Opportunity__r.TaxInvoice_Signed_DateTime__c,Opportunity__r.TR4K_Deduction_Form_Signed_DateTime__c
                    FROM      Scheduled_Payment__c
                    WHERE     Opportunity__r.Is_Active__c   = true
                    AND       Opportunity__r.Is_Credit_Contract__c   = false
                    AND       Fully_Paid__c <> 'Yes'
                    AND       Opportunity__r.StageName = :OPPORTUNITY_STAGE_CREATE_PAYMENTS
                    AND      (Opportunity__r.Account.Ezidebit_Ref_No__c IN :ernSet OR
                              Opportunity__r.Applicant2__r.Ezidebit_Ref_No__c IN :ernSet)
                    ORDER BY  Scheduled_Date__c];
        }
     
        system.debug('unPaidSpsAllsize: '+unPaidSpsAll.size());                      
        unPaidSpsTR4K = [SELECT   Id, 
                              Name,
                              Opportunity__c,
                              Opportunity__r.Account.Ezidebit_Ref_No__c,
                              Opportunity__r.Account.Territory_Number__r.State_Master_State__c,
                              Opportunity__r.Applicant2__r.Ezidebit_Ref_No__c,
                              Opportunity__r.StageName,
                              Paid_Amount__c,
                              Scheduled_Amount__c,
                              Remaining_Amount__c,
                              Scheduled_Date__c ,
                              Opportunity__r.Start_Date__c,
                              Opportunity__r.Account.TR4K_ERN__c,Opportunity__r.RecordType.Name,Opportunity__r.Name,Opportunity__r.TaxInvoice_Signed_DateTime__c,Opportunity__r.TR4K_Deduction_Form_Signed_DateTime__c
                    FROM      Scheduled_Payment__c
                    WHERE     Opportunity__r.Is_Active__c   = true
                    AND       Opportunity__r.Is_Credit_Contract__c   = false
                    AND       Fully_Paid__c <> 'Yes'
                    AND       Opportunity__r.StageName = :OPPORTUNITY_STAGE_CREATE_PAYMENTS
                    AND       (Opportunity__r.Account.TR4K_ERN__c IN :ernSet  and Opportunity__r.RecordType.Name='Trak SIM' )
                              ORDER BY  Scheduled_Date__c];
        
        unpaidScheduledPayments.addAll(unPaidSpsAll);
        unpaidScheduledPayments.addAll(unPaidSpsTR4K);
           
            for (Scheduled_Payment__c payment : unpaidScheduledPayments) {
                //initialise Remaining_Amount__c
                payment.Remaining_Amount__c = payment.Scheduled_Amount__c - payment.Paid_Amount__c; 
                
                //add applicant 1
                if (!result.containsKey(payment.Opportunity__r.Account.Ezidebit_Ref_No__c))
                    result.put(payment.Opportunity__r.Account.Ezidebit_Ref_No__c, new List<Scheduled_Payment__c>());
                if(payment.Opportunity__r.RecordType.Name!='Trak SIM' || (payment.Opportunity__r.RecordType.Name=='Trak SIM' && payment.Opportunity__r.TR4K_Deduction_Form_Signed_DateTime__c!=null && payment.Opportunity__r.TR4K_Deduction_Form_Signed_DateTime__c < tr4kCutOffDate))
                    result.get(payment.Opportunity__r.Account.Ezidebit_Ref_No__c).add(payment);    
    
                //add applicant 2 
                if (payment.Opportunity__r.Applicant2__c != null && payment.Opportunity__r.Applicant2__r.Ezidebit_Ref_No__c != null) {
                    if (!result.containsKey(payment.Opportunity__r.Applicant2__r.Ezidebit_Ref_No__c))
                        result.put(payment.Opportunity__r.Applicant2__r.Ezidebit_Ref_No__c, new List<Scheduled_Payment__c>());
                    if(payment.Opportunity__r.RecordType.Name!='Trak SIM' || (payment.Opportunity__r.RecordType.Name=='Trak SIM' && payment.Opportunity__r.TR4K_Deduction_Form_Signed_DateTime__c!=null && payment.Opportunity__r.TR4K_Deduction_Form_Signed_DateTime__c < tr4kCutOffDate))
                        result.get(payment.Opportunity__r.Applicant2__r.Ezidebit_Ref_No__c).add(payment);  
                }  
                
                //add TR4K ERN
                if (payment.Opportunity__r.Account != null && payment.Opportunity__r.Account.TR4K_ERN__c != null && payment.Opportunity__r.RecordType.Name=='Trak SIM') {
                    if (!result.containsKey(payment.Opportunity__r.Account.TR4K_ERN__c))
                        result.put(payment.Opportunity__r.Account.TR4K_ERN__c, new List<Scheduled_Payment__c>());
                    if(payment.Opportunity__r.TR4K_Deduction_Form_Signed_DateTime__c!=null && payment.Opportunity__r.TR4K_Deduction_Form_Signed_DateTime__c >= tr4kCutOffDate)
                        result.get(payment.Opportunity__r.Account.TR4K_ERN__c).add(payment); 
                } 
            } 
        return result;        
    }
    
    public static List<Opportunity> getAllHistoricActiveTR4K(Set<String> CrnErnSet)
    {
        Date tr4kCutOffDate;
        
        try{
            tr4kCutOffDate=Date.parse('16/09/2020');
        }catch(Exception ex){
            system.debug('ExceptionType: '+ex);
            tr4kCutOffDate=Date.newInstance(2020,09,16);
        }
        List<Opportunity> tr4kOppList = new List<Opportunity>();
        tr4kOppList = [select id,name from Opportunity where StageName = :OPPORTUNITY_STAGE_CREATE_PAYMENTS and (TR4K_Deduction_Form_Signed_DateTime__c = null OR TR4K_Deduction_Form_Signed_DateTime__c<: tr4kCutOffDate) and RecordType.Name='Trak SIM' and (Account.Ezidebit_Ref_No__c IN :CrnErnSet or Account.CRN__c IN :CrnErnSet)];
        
        system.debug('tr4kOppListsize: '+tr4kOppList.size()+' tr4kOppList: '+tr4kOppList);
        return tr4kOppList;
    }
    
    /*
     ****************************************************************
     * WINZ allocations
     ****************************************************************
     */
    //Allocate WINZ Payments
    public static void allocateWINZPayments(List<Payment__c> payments) {
        Map<String, List<Payment__c>> winzPayments = new Map<String, List<Payment__c>>();
        for (Payment__c payment :payments) {
            if (payment.RecordTypeId == RECORDTYPE_ID_WINZ) {
                if (!winzPayments.containsKey(payment.WINZ_No__c))
                    winzPayments.put(payment.WINZ_No__c, new List<Payment__c>());
                winzPayments.get(payment.WINZ_No__c).add(payment);
            }
        }

        //Retrieve list of active unpaid Scheduled payment order by Opportunity Start Date and then earliest payment due date
        Map<String, List<Scheduled_Payment__c>> unpaidScheduledPayments = getUnpaidScheduledPaymentsByWINZ(winzPayments.keySet());   
        
        //Create Payment Allocation against Scheduled Payments
        List<Payment_Allocation__c> paymentAllocations = new List<Payment_Allocation__c>();
        List<Scheduled_Payment__c> scheduledPayments; 
        
        for (List<Payment__c> paymentsByWINZ : winzPayments.values()) {
            System.debug('###paymentsByWINZ size: ' + paymentsByWINZ.size());
            
            scheduledPayments = unpaidScheduledPayments.get(paymentsByWINZ[0].WINZ_No__c);
            if (scheduledPayments == null) continue;
            
            for (Payment__c payment :paymentsByWINZ) {
                System.debug('###scheduledPayments.size(): ' + scheduledPayments.size());

                paymentAllocations.addAll(allocatePayments(payment, scheduledPayments,0));
            }
        }
        
        //Insert Payment Allocation Records
        if (paymentAllocations.size() > 0)
            insert paymentAllocations;
    }

    /*
     * helper method to get all unpaid Ezidebit type scheduled payments using ERN numbers.
     */
    private static Map<String, List<Scheduled_Payment__c>> getUnpaidScheduledPaymentsByWINZ(Set<String> winzSet) {
        Date startPaymentDate = getStartPaymentDate();
        Date endPaymentDate   = getEndPaymentDate();
        
        System.debug('>> OPPORTUNITY_STAGE_CREATE_PAYMENTS >>'+OPPORTUNITY_STAGE_CREATE_PAYMENTS);
        System.debug('>>winzSet >>'+winzSet );
        
        if(winzSet.size()>0)
            winzSet.remove(null);
        System.debug('winzSize: '+ winzSet.size()+' >>winzSet >>'+winzSet );
       
        //Scheduled_Payment__c payment = null;
        Map<String, List<Scheduled_Payment__c>> result = new Map<String, List<Scheduled_Payment__c>>();
        //use index to ensure list order is maintained
        for(List<Scheduled_Payment__c> unpaidScheduledPayments :
                   [SELECT    Id, 
                              Name,
                              Opportunity__c,
                              Opportunity__r.Account.WINZ_No__c,
                              Opportunity__r.Account.Territory_Number__r.State_Master_State__c,
                              Opportunity__r.Applicant2__r.WINZ_No__c,
                              Opportunity__r.StageName,
                              Paid_Amount__c,
                              Scheduled_Amount__c,
                              Remaining_Amount__c,
                              Scheduled_Date__c ,
                              Opportunity__r.Start_Date__c
                    FROM      Scheduled_Payment__c
                    WHERE     Opportunity__r.Is_Active__c   = true
                    AND       Opportunity__r.Is_Credit_Contract__c   = false
                    AND       Fully_Paid__c <> 'Yes'
                    AND       Opportunity__r.StageName = :OPPORTUNITY_STAGE_CREATE_PAYMENTS
                    AND      (Opportunity__r.Account.WINZ_No__c IN :winzSet OR
                              Opportunity__r.Applicant2__r.WINZ_No__c IN :winzSet)
                    ORDER BY  Scheduled_Date__c]){    
            for (Scheduled_Payment__c payment : unpaidScheduledPayments) {
                //initialise Remaining_Amount__c
                payment.Remaining_Amount__c = payment.Scheduled_Amount__c - payment.Paid_Amount__c; 
                
                //add applicant 1
                if (!result.containsKey(payment.Opportunity__r.Account.WINZ_No__c))
                    result.put(payment.Opportunity__r.Account.WINZ_No__c, new List<Scheduled_Payment__c>());
                result.get(payment.Opportunity__r.Account.WINZ_No__c).add(payment);    
    
                //add applicant 2 
                if (payment.Opportunity__r.Applicant2__c != null && payment.Opportunity__r.Applicant2__r.WINZ_No__c != null) {
                    if (!result.containsKey(payment.Opportunity__r.Applicant2__r.WINZ_No__c))
                        result.put(payment.Opportunity__r.Applicant2__r.WINZ_No__c, new List<Scheduled_Payment__c>());
                    result.get(payment.Opportunity__r.Applicant2__r.WINZ_No__c).add(payment);  
                }  
            } 
        }                          
        return result;        
    }
    
    /*
     * helper method to find the first index in the list that has an unpaid scheduled payment.
     */
    private static Integer getFirstUnpaidScheduledPaymentIndex(List<Scheduled_Payment__c> scheduledPayments, Payment__c payment) {
        if (scheduledPayments == null)
            return -1;
        
        for (Integer i = 0; i < scheduledPayments.size(); i++) {
            Scheduled_Payment__c scheduledPayment = scheduledPayments.get(i);
            //Ian - disable Opp Start Date checking for initial data uploading, to to enabled after initial data uploading 
            //if (scheduledPayment.Remaining_Amount__c > 0 && scheduledPayment.Opportunity__r.Start_Date__c <= payment.Payment_Date__c)  {
            if (scheduledPayment.Remaining_Amount__c > 0)  {
               return i;
            }
        }
        return -1;
    }
        
    /*
     ****************************************************************
     * Deposit allocations
     **************************************************************** 
     * Manual deposit from the applicant always pays the at the begin before scheduled payments start.
     */
    public static void allocateDepositPayments(Payment__c payment) {
        System.debug('### allocateDepositPayments');
        List<Scheduled_Payment__c> scheduledPayments = [SELECT   Id, Opportunity__c, Remaining_Amount__c, Scheduled_Amount__c, Paid_Amount__c,
                                                        Opportunity__r.Account.Territory_Number__r.State_Master_State__c
                                                        FROM     Scheduled_Payment__c
                                                        WHERE    Opportunity__c = :payment.Agreement__c
                                                        AND      Opportunity__r.Is_Active__c = true 
                                                        AND      Opportunity__r.Is_Credit_Contract__c   = false
                                                        AND      Opportunity__r.StageName = :OPPORTUNITY_STAGE_CREATE_PAYMENTS
                                                        AND      Fully_Paid__c <> 'Yes'
                                                        ORDER BY Scheduled_Date__c DESC];
        
        initializeRemainingAmountsForAdHocSchedulePayments(scheduledPayments);
        List<Payment_Allocation__c> paymentAllocations = allocatePayments(payment, scheduledPayments,0);
        if (!paymentAllocations.isEmpty())
            insert paymentAllocations;
    }


    /*
     ****************************************************************
     * Cash allocations
     **************************************************************** 
     * Adhoc Cash payment always pays from the last schedule payments going backwards.    
     */
    public static void allocateCashPayments(Payment__c payment) {
        List<Scheduled_Payment__c> scheduledPayments = new List<Scheduled_Payment__c>();
        system.debug('payment.Third_Party_Collections__c: '+payment.Third_Party_Collections__c);
        if(payment.Third_Party_Collections__c){
            scheduledPayments = [SELECT   Id, Opportunity__c, Remaining_Amount__c, Scheduled_Amount__c, Paid_Amount__c,Opportunity__r.Account.Territory_Number__r.State_Master_State__c 
                                                        FROM     Scheduled_Payment__c
                                                        WHERE    Opportunity__c =: payment.Agreement__c
                                                        AND      Opportunity__r.Is_Credit_Contract__c   = false
                                                        AND      (Opportunity__r.StageName = :OPPORTUNITY_STAGE_CREATE_PAYMENTS OR Opportunity__r.StageName = :OPPORTUNITY_STAGE_CREATE_PAYMENTS_WRITTENOFF)
                                                        AND      Fully_Paid__c <> 'Yes'
                                                        ORDER BY Scheduled_Date__c];
        }else{
            scheduledPayments = [SELECT   Id, Opportunity__c, Remaining_Amount__c, Scheduled_Amount__c, Paid_Amount__c,Opportunity__r.Account.Territory_Number__r.State_Master_State__c 
                                                        FROM     Scheduled_Payment__c
                                                        WHERE    Opportunity__c =: payment.Agreement__c
                                                        AND      Opportunity__r.Is_Active__c = true 
                                                        AND      Opportunity__r.Is_Credit_Contract__c   = false
                                                        AND      Opportunity__r.StageName = :OPPORTUNITY_STAGE_CREATE_PAYMENTS
                                                        AND      Fully_Paid__c <> 'Yes'
                                                        ORDER BY Scheduled_Date__c];
        }
        
        initializeRemainingAmountsForAdHocSchedulePayments(scheduledPayments);
        List<Payment_Allocation__c> paymentAllocations = allocatePayments(payment, scheduledPayments,0);
        if (!paymentAllocations.isEmpty())
            insert paymentAllocations;
    }
    
    private static void initializeRemainingAmountsForAdHocSchedulePayments(List<Scheduled_Payment__c> scheduledPayments) {
        //init Remaining_Amount__c
        for (Scheduled_Payment__c scheduledPayment : scheduledPayments)
            scheduledPayment.Remaining_Amount__c = scheduledPayment.Scheduled_Amount__c - scheduledPayment.Paid_Amount__c;
    }

    /*
     * Reusable help method to generate payment allocations for all payment types. Payment Allocation is the link between payments 
     * and scheduled payments so that we known how much a contract has been paid off.
     *
     * @param payment               Payment record
     * @param scheduledPayments     List of scheduled payments
     * @return paymentAllocations   List of payment allocations created against this payment record.
     */
    private static List<Payment_Allocation__c> allocatePayments(Payment__c payment, List<Scheduled_Payment__c> scheduledPayments,Decimal manuallyAllocatedAmount) {
        Decimal remainingPaymentAmount = 0;
        List<Payment_Allocation__c> result = new List<Payment_Allocation__c>();
        System.debug('###IN allocatePayments method - payment is NULL?' + (payment == null));
        System.debug('###IN allocatePayments method - scheduledPayments is NULL?' + (scheduledPayments == null));
        if (payment != null) System.debug('###scheduledPayments: ' + payment);
        if (scheduledPayments != null) System.debug('###scheduledPayments: ' + scheduledPayments);
        if (scheduledPayments == null || payment == null || scheduledPayments.isEmpty() || payment.Actual_Amount__c == 0) return result;
        if (manuallyAllocatedAmount!=0)
            remainingPaymentAmount = manuallyAllocatedAmount;
        else
            remainingPaymentAmount = payment.Total_Paid__c;
            
        Payment_Allocation__c lastPaymentAllocation = null;
                
        while (remainingPaymentAmount > 0) {
            Integer firstUnpaidScheduledPaymentIndex = getFirstUnpaidScheduledPaymentIndex(scheduledPayments, payment);
            Scheduled_Payment__c unpaidScheduledPayment = (firstUnpaidScheduledPaymentIndex > -1)?  scheduledPayments.get(firstUnpaidScheduledPaymentIndex) : null;
            if (unpaidScheduledPayment == null) break;
            System.debug('###remainingPaymentAmount: ' + remainingPaymentAmount + ' vs ###unpaidScheduledPayment.Remaining_Amount__c: ' + unpaidScheduledPayment.Remaining_Amount__c);
            //add new Payment Allocation
            //Under paid
            if (remainingPaymentAmount < unpaidScheduledPayment.Remaining_Amount__c) {
                lastPaymentAllocation = createPaymentAllocation(unpaidScheduledPayment, payment, remainingPaymentAmount);
                System.debug('###lastPaymentAllocation(under payment) - Scheduled Payment ID: ' + lastPaymentAllocation.Scheduled_Payment__c + 
                    ' - Payment ID: ' + lastPaymentAllocation.Payment__c + ' - Payment Date: ' + lastPaymentAllocation.Payment_Date__c +
                    ' - Contract: ' + lastPaymentAllocation.Contract__c + ' - Amount: ' + lastPaymentAllocation.Actual_Amount__c);

                unpaidScheduledPayment.Remaining_Amount__c = Math.abs(unpaidScheduledPayment.Remaining_Amount__c - remainingPaymentAmount);
                System.debug('###unpaidScheduledPayment.Remaining_Amount__c = ' + unpaidScheduledPayment.Remaining_Amount__c);
                remainingPaymentAmount = 0;
            }    
            else { //Over paid  
                lastPaymentAllocation = createPaymentAllocation(unpaidScheduledPayment, payment, unpaidScheduledPayment.Remaining_Amount__c);
                
                System.debug('###lastPaymentAllocation(over payment) - Scheduled Payment ID: ' + lastPaymentAllocation.Scheduled_Payment__c + 
                    ' - Payment ID: ' + lastPaymentAllocation.Payment__c + ' - Payment Date: ' + lastPaymentAllocation.Payment_Date__c +
                    ' - Contract: ' + lastPaymentAllocation.Contract__c + ' - Amount: ' + lastPaymentAllocation.Actual_Amount__c);

                remainingPaymentAmount -= unpaidScheduledPayment.Remaining_Amount__c;
                System.debug('###remainingPaymentAmount: ' + remainingPaymentAmount);
                unpaidScheduledPayment.Remaining_Amount__c = 0;
                //remove paid ScheduledPayment from unpaid scheduledPayment list
                scheduledPayments.remove(firstUnpaidScheduledPaymentIndex);
            }

            result.add(lastPaymentAllocation);
            
            System.debug('###lastPaymentAllocation added to result list - Scheduled Payment ID: ' + lastPaymentAllocation.Scheduled_Payment__c + 
                    ' - Payment ID: ' + lastPaymentAllocation.Payment__c + ' - Payment Date: ' + lastPaymentAllocation.Payment_Date__c +
                    ' - Contract: ' + lastPaymentAllocation.Contract__c + ' - Amount: ' + lastPaymentAllocation.Actual_Amount__c);
            
        }
        
        //add remaining amount to the last payment allocation of the agreement
        if (remainingPaymentAmount > 0 && lastPaymentAllocation != null)
           lastPaymentAllocation.Actual_Amount__c += remainingPaymentAmount;
        
        return result;
    }
    
    /*
     ****************************************************************
     * Create payment allocation 
     ****************************************************************
     */
    private static Payment_Allocation__c createPaymentAllocation(Scheduled_Payment__c scheduledPayment, Payment__c payment, Decimal remainingAmount) {
       Payment_Allocation__c paymentAllocation = new Payment_Allocation__c();
      
       paymentAllocation.Scheduled_Payment__c = scheduledPayment.Id;
       paymentAllocation.Payment__c           = payment.Id;
       paymentAllocation.Contract__c          = scheduledPayment.Opportunity__c;
       paymentAllocation.Payment_Date__c      = payment.Payment_Date__c;  //Date.today();
       paymentAllocation.Actual_Amount__c     = remainingAmount;
        
       //Do we need to set the fields below if Working_Table__c is linked?
       paymentAllocation.Client_Fees__c       = payment.Client_Fees__c;
       paymentAllocation.Fee_Amount__c        = payment.Fee_Amount__c;
       paymentAllocation.Setup_Fee__c         = payment.Setup_Fee__c;
       //paymentAllocation.RecordTypeId         = (payment.RecordTypeId == RECORDTYPE_ID_CENTREPAY) ? PAYMENT_ALLOCATION_RECORDTYPE_ID_CENTREPAY : 
       //                                                                                             PAYMENT_ALLOCATION_RECORDTYPE_ID_EZIDEBIT;
       
       if(scheduledPayment.Opportunity__r.Account.Territory_Number__r.State_Master_State__c!=null && scheduledPayment.Opportunity__r.Account.Territory_Number__r.State_Master_State__c=='NZ')
           paymentAllocation.CurrencyISOCode='NZD';
           
       return paymentAllocation;
    }
    
    //Create payment date 3 days earlier than scheduled date.
    private static Date getStartPaymentDate() {
       return Date.today().addDays(PAYMENT_DAY_VARIANCE * -1);
    }

    //Create payment date 3 days after scheduled date.
    private static Date getEndPaymentDate() {
       return Date.today().addDays(PAYMENT_DAY_VARIANCE);
    }
            
}