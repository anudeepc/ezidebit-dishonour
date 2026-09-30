public class GoogleChartsPaymentController
{
public String accId {get;set;}
public String oppId {get;set;}
public List<Opportunity> oppList{get;set;}
public Opportunity opportunity{get;set;}
public String oppJson {get;set;}
public List<ApplicantWrapper> applicantList {get;set;}

public Date startDate{get;set;}
public List<OpportunityLineItem> products{get;set;}
public List<OpportunityLineItem> leasedProducts{get;set;}
public List<OpportunityLineItem> feeProducts{get;set;}
public Decimal totalFees{get;set;}
public Decimal totalDebits{get;set;}
public Decimal openingBalance{get;set;}
public Decimal closingBalance{get;set;}
public Decimal totalPaidAmount{get;set;}
public Decimal totalPrincipalPaid{get;set;}
public Decimal totalInterestPaid{get;set;}
public Decimal totalAccruedInterest{get;set;}
//public Decimal totalFeesNZ{get;set;}
public Date lastStatementSentDate{get;set;}
public Integer statementNo{get;set;}
public List<PaymentWrapper> paymentWrappers {get;set;}
public Boolean hasCreditPayment{get;set;}
public String fullStmt{get;set;}
public OpportunityLineItem earlyTerminationProd{get;set;}
public Date expectedPayoutDate{get;set;}
public Decimal earlyTerminationFee{get;set;}
public Decimal accruedInterest{get;set;}
public Decimal dailyInterest{get;set;}
public Decimal quotedAccruedInterest{get;set;}
public Decimal interestOwing{get;set;}
public Decimal totalInterest{get;set;}
public Decimal adjustedAmountBorrowed{get;set;}
public Decimal amountBorrowed{get;set;}
public Decimal amountOfCredit{get;set;}
public String payoutLink{get;set;}
public String renderAs{get;set;}
public Boolean pastPayoutDate{set;get;}

public GoogleChartsPaymentController()
{
    accId=ApexPages.currentPage().getParameters().get('id');
    oppId=ApexPages.currentPage().getParameters().get('oppId');
    fullStmt=ApexPages.currentPage().getParameters().get('fullStmt');
    hasCreditPayment = false;
    system.debug('accId: '+accId);
    renderAs='html';
}

public void GetDataToCreateChartsInAgreement()
{
    system.debug('accId1: '+accId);
    oppList=[select id,Name,Amount,Approximate_No_of_Payments_Made__c,No_of_Scheduled_Payments__c,Total_Paid_Amount__c,Remaining_Amount__c,Scheduled_Amount__c,Days_Since_Expected_Payment__c,Expected_payment_amount_so_far__c from Opportunity where (Account.Id=:accId or Applicant2__c=:accId) and Scheduled_Amount__c!=null and Is_Active__c=true];
    if(oppList.size()>0)
    {    
        oppJson=JSON.serialize(oppList);
        system.debug('oppJson: '+oppJson);
    }
}

public PageReference proceedToPayout(){
    payoutLink = (opportunity.Account.Territory_Number__r.Ezidebit_Instant_URL__c + '?Type=I&FirstName=' + opportunity.Account.FirstName + '&LastName=' + opportunity.Account.LastName + '&PaymentAmount=' + opportunity.Actual_Payout_Figure__c + '&PaymentReference=' + opportunity.Contract_No__c + 'EPF&RedirectURL=https://r4k.my.salesforce-sites.com/R4KPay');
    return new PageReference(payoutLink).setRedirect(true);
}

public void initEarlyPayoutStatement(){
    if(!String.isBlank(oppId)){
        opportunity = [
            SELECT 
                Id, Name,Amount,Account.FirstName,Account.LastName,Account.PersonMailingStreet,Account.PersonMailingCity,Account.PersonMailingState,Account.Name,
                Account.PersonMailingPostalCode,Total_Paid_Amount__c,Remaining_Amount__c,Contract_No__c,Start_Date__c,Term_Months__c,Payment_Frequency__c,Payment_Frequency_Number__c,
                Total_Loan_Amount__c,Total_Loan_Amount_Incl_Unpaid_Interest__c,Total_Loan_Balance_Amount__c,Statement_Closing_Balance__c,Total_Paid_Interest_Amount__c,
                Account.Customer_No__c,Account.PersonEmail,Final_Payout_Figure__c,Interest_Accrued_Since_Last_Payment__c,Daily_Interest_Rate__c,Total_Additional_Fees__c,Total_Paid__c,Total_Paid_Principal_Amount__c,Total_Interest_Amount__c,
                Account.Territory_Number__r.Company_Name__c,Account.Territory_Number__r.Trading_Name__c,Account.Territory_Number__r.A_B_N__c,Account.Territory_Number__r.A_C_L__c,
                Account.Territory_Number__r.Ezidebit_Instant_URL__c,Expected_Payout_Date__c,Account.PersonContactId,Actual_Payout_Figure__c,Customer_Support_Phone__c,StageName,
                Account.Territory_Number__r.PPB_Street__c,Account.Territory_Number__r.PPB_Suburb__c,Account.Territory_Number__r.PPB_State__c,Account.Territory_Number__r.PPB_Postcode__c,
                Account.Territory_Number__r.EMF_Account_Name__c,Account.Territory_Number__r.EMF_BSB__c,Account.Territory_Number__r.EMF_Account__c,Ezidebit_Starting_Date__c 
            FROM Opportunity
            WHERE 
                Id = :oppId AND
                Is_Credit_Contract__c = true AND
                Account.State_Master_State__c != 'NZ'
            LIMIT 1
        ];

        pastPayoutDate = false;
        amountOfCredit = opportunity.Amount ?? 0;
        amountBorrowed = opportunity.Total_Loan_Amount__c ?? 0;
        totalFees = opportunity.Total_Additional_Fees__c ?? 0;
        totalPaidAmount = opportunity.Total_Paid__c ?? 0;
        totalPrincipalPaid = opportunity.Total_Paid_Principal_Amount__c ?? 0;
        totalInterestPaid = opportunity.Total_Paid_Interest_Amount__c ?? 0;
        totalInterest = opportunity.Total_Interest_Amount__c ?? 0;
        interestOwing = (totalInterest - totalInterestPaid);
        // Compliance (Sep 2026): no early termination fee. The payout figure is
        // Final_Payout_Figure__c = account balance + interest accrued daily since
        // the last payment; the legacy Payout_Figure__c still adds 25% of interestOwing.
        earlyTerminationFee = 0;
        adjustedAmountBorrowed = (amountBorrowed + totalFees - totalPrincipalPaid);
        accruedInterest = opportunity.Interest_Accrued_Since_Last_Payment__c ?? 0;
        dailyInterest = ((opportunity.Total_Loan_Balance_Amount__c ?? 0) * (opportunity.Daily_Interest_Rate__c ?? 0) / 100).setScale(2);
        // EarlyPayoutRedirection charges the figure quoted on the statement
        // (Actual_Payout_Figure__c), so it shows the interest that figure included.
        quotedAccruedInterest = (opportunity.Actual_Payout_Figure__c ?? 0) - adjustedAmountBorrowed;

        List<Payment__c> payments = [
            SELECT 
                Id, Payment_Date__c, CreatedDate
            FROM Payment__c
            WHERE 
                Agreement__c = :oppId AND
                Total_Paid__c > 0 AND 
                (NOT File_Name__c LIKE 'Ezidebit_Realtime_%') AND
                Payment_Record_Type__c = 'Ezidebit'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        expectedPayoutDate = (payments.size() > 0 ? payments[0].Payment_Date__c.addDays((Integer)opportunity.Payment_Frequency_Number__c) : (opportunity.Ezidebit_Starting_Date__c != null ? opportunity.Ezidebit_Starting_Date__c : Date.today()));
        while(expectedPayoutDate <= Date.today()){
            expectedPayoutDate = expectedPayoutDate.addDays((Integer)opportunity.Payment_Frequency_Number__c);
        }
        
        payoutLink = (SiteEndpoint__c.getValues('R4KPay').URL__c + '/EarlyPayoutRedirection?oppId=' + opportunity.Id);
        /*if(!Test.isRunningTest()){
            ShortLinkGeneratorUtil sl = new ShortLinkGeneratorUtil();
            payoutLink = sl.shortLinkGenerator(payoutLink);
        }*/
        pastPayoutDate = (opportunity.StageName == 'Completed' || opportunity.Final_Payout_Figure__c == null || opportunity.Final_Payout_Figure__c <= 0 || opportunity.Expected_Payout_Date__c == null || Date.today() > opportunity.Expected_Payout_Date__c ? true : false);
    }
}

public PageReference sendEarlyPayoutStatement(){
    PageReference pdf = new PageReference(SiteEndpoint__c.getValues('R4KPay').URL__c + '/EarlyPayoutFigureStatement?oppId=' + opportunity.Id + '&renderAs=pdf');

    Messaging.EmailFileAttachment pdfAttachment = new Messaging.EmailFileAttachment();
    Blob pdfBlob; 
    try{
        pdfBlob = pdf.getContentAsPDF();
    }catch(Exception ex){
        System.debug(ex.getMessage());
        pdfBlob = Blob.valueOf(' ');
    }
    String pdfName = 'Early Payout Figure Statement_' + opportunity.Name + '_' + DateTime.now().format('ddMMMyyyy') + '.pdf';
    pdfAttachment.setFileName(pdfName);
    pdfAttachment.setBody(pdfBlob);

    Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
    String[] toAddresses = new String[]{opportunity.Account.PersonEmail};
    email.setSubject('Early Payout Figure Statement - Your R4K Instalment Agreement No: ' + opportunity.Contract_No__c);
    email.setToAddresses(toAddresses);
    String emailBody = '<p>Dear ' + opportunity.Account.Name + ',</p>';
    emailBody += '<p>As per your recent request, please find attached the Early Payout Figure Statement for your R4K Instalment Agreement related to the purchase of your ' + opportunity.Name.substringAfter(' - ') + '. This statement outlines the calculated payout figure and its components, as required by the National Credit Code.</p>';
    emailBody += '<p>If you have any questions or need further assistance, please don\'t hesitate to reach out to our customer care team.</p>';
    emailBody += '<p>Best regards,<br/><br/>';
    emailBody += opportunity.Account.Territory_Number__r.Company_Name__c;
    emailBody += '<br/>' + opportunity.Customer_Support_Phone__c + '</p>';
    
    email.setHtmlBody(emailBody);
    email.setWhatId(opportunity.Id);
    email.setSaveAsActivity(true);
    email.setTargetObjectId(opportunity.Account.PersonContactId);
    email.setTreatTargetObjectAsRecipient(false);
    email.setFileAttachments(new Messaging.EmailFileAttachment[]{pdfAttachment});
    Messaging.sendEmail(new Messaging.SingleEmailMessage[]{email});

    Opportunity opp = new Opportunity();
    opp.Id = opportunity.Id;
    opp.Expected_Payout_Date__c = expectedPayoutDate.addDays(-1);
    opp.Actual_Payout_Figure__c = opportunity.Final_Payout_Figure__c;
    update opp;

    Attachment att = new Attachment();
    att.ParentId = opportunity.Id;
    att.Name = pdfname;
    att.body = pdfBlob;
    insert att;

    return new PageReference('/' + opportunity.Id).setRedirect(true);
}

public PageReference searchCreditContract(){
    String pmtRef = ApexPages.currentPage().getParameters().get('pmtRef');
    if(!String.isBlank(pmtRef)){
        String contractNo = pmtRef.substringBeforeLast('EPF');
        List<Opportunity> creditContracts = [
                                                SELECT 
                                                    Id,Scheduled_Amount__c,StageName,Last_Collection_Activity__c,Last_Payment_Received_Amount__c,Contract_No__c,Actual_Arrears__c,
                                                    Account.Territory_Number__c,Account.Territory_Number__r.Short_Name__c,Account.Territory_Number__r.State_Master_State__c,Account.PersonContactId,
                                                    Account.OwnerId,AccountId,Account.Customer_No__c,Account.Ezidebit_Ref_No__c,Account.Name,CurrencyIsoCode,Payout_Figure__c,Account.PersonEmail
                                                FROM Opportunity WHERE 
                                                    Contract_No__c =: contractNo AND 
                                                    Is_Credit_Contract__c = true AND
                                                    Account.Territory_State__c != 'NZ' AND
                                                    RecordType.Name <> 'Trak SIM' 
                                                LIMIT 1
                                            ];
        if(!creditContracts.isEmpty()){
            return new PageReference('/apex/EarlyPayoutBankTransferPayment?oppId=' + creditContracts[0].Id).setRedirect(true);
        }
    }
    return null;
}

public PageReference addBankTransferPayment(){
    String pmtRef = ApexPages.currentPage().getParameters().get('pmtRef');
    String transactionId = ApexPages.currentPage().getParameters().get('transactionId');
    String pmtDate = ApexPages.currentPage().getParameters().get('pmtDate');
    String pmtAmt = ApexPages.currentPage().getParameters().get('pmtAmt');

    EzidebitSiteController.addEarlyPayoutPayment(pmtRef, transactionId, 0, Date.parse(pmtDate), Decimal.valueOf(pmtAmt), 'BankTransfer');

    return new PageReference('/' + opportunity.Id).setRedirect(true);
}

public void initAgreementStatement()
{
    List<Opportunity> oppList=[select id,Name,Amount,Account.FirstName,Account.LastName,Account.PersonMailingStreet,Account.PersonMailingCity,Account.PersonMailingState,
                                Account.PersonMailingPostalCode,Total_Paid_Amount__c,Remaining_Amount__c,Contract_No__c,Start_Date__c,Term_Months__c,Payment_Frequency__c,
                                Scheduled_Amount__c,Number_Of_SP_for_Cross_Check__c,Account.State_Master_State__c,StageName,CreatedDate ,Last_Paid_Date_Applicant_1_2__c, 
                                NZ_Interest_Rate__c,NZ_Cash_Price_of_goods__c,Fortnightly_Schedule_Payment__c,Customer_Statement_Sent_Date__c,Taxinvoice_Signed_DateTime__c,
                                Total_Loan_Amount__c,Total_Loan_Amount_Incl_Unpaid_Interest__c,Total_Loan_Balance_Amount__c,Statement_Closing_Balance__c,Total_Paid_Interest_Amount__c,
                                Customer_Support_Phone__c,Customer_Support_Email__c,Account.Territory_Number__r.PPB_Street__c,Account.Territory_Number__r.PPB_Suburb__c,
                                Account.Territory_Number__r.PPB_State__c,Account.Territory_Number__r.PPB_Postcode__c,Account.Territory_Number__r.Company_Name__c,
                                Account.Territory_Number__r.A_B_N__c,Account.Territory_Number__r.A_C_L__c,Early_Payout_Adjustment__c 
                                from Opportunity where id=: oppId];
    if(oppList.size()>0)
    {
        statementNo = 1;
        opportunity = oppList[0];
        startDate = opportunity.Taxinvoice_Signed_DateTime__c != null ? opportunity.Taxinvoice_Signed_DateTime__c.date() : opportunity.CreatedDate.date();
        products = [select id,Name,Description,Serial_Number__c,Term_Months__c,TotalPrice,Actual_Per_Fortnight__c,Product2.ProductCode,CreatedDate,Early_Payout_Adjustment__c 
                    from OpportunityLineItem where Opportunity.id=:opportunity.Id];
        closingBalance = opportunity.Total_Loan_Balance_Amount__c;
        totalAccruedInterest = 0;
        openingBalance = opportunity.Total_Loan_Amount__c;    
        feeProducts = new List<OpportunityLineItem>();
        leasedProducts = new List<OpportunityLineItem>();
        totalFees = 0;
        totalDebits = 0;
        
        for(OpportunityLineItem prd : products)
        {
            if(prd.Description <> null && prd.Description == 'Fee')
            {
                feeProducts.add(prd);
            }else if(prd.Description <> null && prd.Description <> 'Fee' && prd.Description <> 'Variation' && prd.Product2.ProductCode != 'Early Termination Adjustment')
            {
                leasedProducts.add(prd);
            }else if(prd.Product2.ProductCode == 'Early Termination Adjustment' && opportunity.Account.State_Master_State__c != 'NZ')
            {
                earlyTerminationProd = prd;
            }
        }

        List<Attachment> attachList = [SELECT Id FROM Attachment WHERE ParentId =: opportunity.Id AND Name LIKE '%Agreement Statement%'];
        statementNo = attachList.size() + 1;

        //get payment allocations
        List<Payment_Allocation__c> paymentAllocations = [SELECT Id,Actual_Amount__c,Payment__c,Scheduled_Payment__c,Payment__r.Payment_File__c,
                                                                Payment__r.Payment_File__r.CreatedDate,Scheduled_Payment__r.Loan_Balance_Amount__c,
                                                                Payment__r.Payment_Date__c,Payment__r.Name,Payment__r.Payment_Record_Type__c,
                                                                Scheduled_Payment__r.Principal_Amount__c,Scheduled_Payment__r.Interest_Amount__c,Scheduled_Payment__r.Paid_Amount__c,
                                                                Scheduled_Payment__r.Unpaid_Interest_Amount__c,Scheduled_Payment__r.No_of_Payment_Allocations__c,Scheduled_Payment__r.Name 
                                                                FROM Payment_Allocation__c WHERE 
                                                                Contract__c =:opportunity.Id 
                                                                ORDER BY CreatedDate ASC];

        totalPaidAmount = 0;
        totalPrincipalPaid = 0;
        totalInterestPaid = 0;
        totalAccruedInterest = 0;
        paymentWrappers = new List<PaymentWrapper>();
        List<PaymentWrapper> paymentWrappersASC = new List<PaymentWrapper>();
        Map<String,Decimal> scheduledPaymentBalanceMap = new Map<String,Decimal>();
        for(Integer p=0; p<paymentAllocations.size(); p++)
        {
            PaymentWrapper wrap = new PaymentWrapper();
            wrap.paymentNo = String.valueOf(p+1);
            wrap.paymentDate = paymentAllocations[p].Payment__r.Payment_Date__c;
            wrap.description = (paymentAllocations[p].Payment__r.Payment_Record_Type__c + ' Payment Received - ' + paymentAllocations[p].Payment__r.Name);
            wrap.recordType = paymentAllocations[p].Payment__r.Payment_Record_Type__c;
            wrap.paymentAmount = paymentAllocations[p].Actual_Amount__c;
            wrap.interestAmount = 0;
            //TODO: Update this code to also consider refunds in future
            if(paymentAllocations[p].Scheduled_Payment__r.No_of_Payment_Allocations__c > 1 && Math.abs(paymentAllocations[p].Scheduled_Payment__r.Paid_Amount__c) > 0){
                Decimal paymentRatio = (paymentAllocations[p].Actual_Amount__c / paymentAllocations[p].Scheduled_Payment__r.Paid_Amount__c);
                Decimal loanBalanceReducedBy = paymentRatio * ((paymentAllocations[p].Scheduled_Payment__r.Principal_Amount__c == null ? 0 : paymentAllocations[p].Scheduled_Payment__r.Principal_Amount__c) + (paymentAllocations[p].Scheduled_Payment__r.Unpaid_Interest_Amount__c == null ? 0 : paymentAllocations[p].Scheduled_Payment__r.Unpaid_Interest_Amount__c));
                wrap.loanBalance = (scheduledPaymentBalanceMap.containsKey(paymentAllocations[p].Scheduled_Payment__r.Name) ? scheduledPaymentBalanceMap.get(paymentAllocations[p].Scheduled_Payment__r.Name) : paymentAllocations[p].Scheduled_Payment__r.Loan_Balance_Amount__c) - loanBalanceReducedBy;
            }else{
                wrap.loanBalance = ((paymentAllocations[p].Scheduled_Payment__r.Loan_Balance_Amount__c - (paymentAllocations[p].Scheduled_Payment__r.Principal_Amount__c == null ? 0 : paymentAllocations[p].Scheduled_Payment__r.Principal_Amount__c)) + (paymentAllocations[p].Scheduled_Payment__r.Unpaid_Interest_Amount__c == null ? 0 : paymentAllocations[p].Scheduled_Payment__r.Unpaid_Interest_Amount__c));
            }
            totalPaidAmount += wrap.paymentAmount;
            if(!scheduledPaymentBalanceMap.containsKey(paymentAllocations[p].Scheduled_Payment__r.Name)){
                totalPrincipalPaid += (paymentAllocations[p].Scheduled_Payment__r.Principal_Amount__c == null ? 0 : paymentAllocations[p].Scheduled_Payment__r.Principal_Amount__c);
                totalInterestPaid += (paymentAllocations[p].Scheduled_Payment__r.Interest_Amount__c == null ? 0 : paymentAllocations[p].Scheduled_Payment__r.Interest_Amount__c);
                totalAccruedInterest += (paymentAllocations[p].Scheduled_Payment__r.Unpaid_Interest_Amount__c == null ? 0 : paymentAllocations[p].Scheduled_Payment__r.Unpaid_Interest_Amount__c);
                wrap.interestAmount = (paymentAllocations[p].Scheduled_Payment__r.Interest_Amount__c == null ? 0 : paymentAllocations[p].Scheduled_Payment__r.Interest_Amount__c);
                totalDebits += (paymentAllocations[p].Scheduled_Payment__r.Interest_Amount__c == null ? 0 : paymentAllocations[p].Scheduled_Payment__r.Interest_Amount__c);
            }
            scheduledPaymentBalanceMap.put(paymentAllocations[p].Scheduled_Payment__r.Name, wrap.loanBalance);
            if(paymentAllocations[p].Actual_Amount__c != null && Math.abs(paymentAllocations[p].Actual_Amount__c) > 0){
                paymentWrappersASC.add(wrap);

                if(paymentAllocations[p].Payment__r.Payment_Record_Type__c == 'Credit'){
                    hasCreditPayment = true;
                }
            }
        }
        PaymentWrapper wrap;
        //get total fees
        List<Fee__c> feeList =  [
                                    SELECT Id, Fee_Amount__c, Fee_Charged_Date__c, Fee_Type__c 
                                    FROM Fee__c 
                                    WHERE Agreement__c = :opportunity.Id
                                    ORDER BY CreatedDate DESC
                                ];
        
        for(Fee__c fee : feeList){
            totalFees += fee.Fee_Amount__c;

            wrap = new PaymentWrapper();
            wrap.paymentDate = fee.Fee_Charged_Date__c;
            wrap.description = fee.Fee_Type__c == 'Late Payment' ? 'Dishonour Fee' : fee.Fee_Type__c;
            wrap.allocatedAmount = fee.Fee_Amount__c;
            totalDebits += fee.Fee_Amount__c != null ? fee.Fee_Amount__c : 0;
            paymentWrappersASC.add(wrap);
        }
        paymentWrappersASC.sort();
        System.debug('****totalFees ' + totalFees);
        
        for(Integer i = (paymentWrappersASC.size() - 1); i>=0; i--){
            if(paymentWrappersASC[i].description != null && !(paymentWrappersASC[i].description.containsIgnoreCase('Fee') || paymentWrappersASC[i].description.containsIgnoreCase('Missed Payment') || paymentWrappersASC[i].description.containsIgnoreCase('Late Payment') || paymentWrappersASC[i].description.containsIgnoreCase('Dishonour') || paymentWrappersASC[i].description.containsIgnoreCase('Credit'))){
                wrap = new PaymentWrapper();
                wrap.paymentDate = paymentWrappersASC[i].paymentDate;
                wrap.description = (opportunity.Account.State_Master_State__c == 'NZ' ? 'R4K Rental Charge' : 'R4K Interest Charge');
                if(wrap.description.equalsIgnoreCase('R4K Interest Charge') && paymentWrappersASC[i].interestAmount != null && Math.abs(paymentWrappersASC[i].interestAmount) > 0){
                    wrap.allocatedAmount = paymentWrappersASC[i].interestAmount;
                    paymentWrappers.add(wrap);
                }else if(opportunity.Account.State_Master_State__c == 'NZ'){
                    wrap.allocatedAmount = paymentWrappersASC[i].paymentAmount;
                    paymentWrappers.add(wrap);
                }
            }
            paymentWrappers.add(paymentWrappersASC[i]);
        }

        if(earlyTerminationProd != null){
            List<Payment__c> earlyPayments = [
                SELECT 
                    Id, Payment_Allocation_Balance__c, Total_Paid__c, Payment_Date__c
                FROM Payment__c WHERE
                    Agreement__c = :opportunity.Id AND
                    Is_Early_Payout__c = true AND 
                    Total_Paid__c > 0
                ORDER BY Payment_Date__c DESC LIMIT 1
            ];

            wrap = new PaymentWrapper();
            wrap.paymentDate = (earlyPayments.size() > 0 && earlyPayments[0].Payment_Date__c != null ? earlyPayments[0].Payment_Date__c : earlyTerminationProd.CreatedDate.date());
            wrap.description = '+ Early Termination adjustment';
            wrap.paymentAmount = earlyTerminationProd.Early_Payout_Adjustment__c;
            wrap.loanBalance = opportunity.Total_Loan_Balance_Amount__c;
            wrap.paymentNo = String.valueOf(paymentWrappersASC.size() + 1);
            paymentWrappers.add(wrap);
        }
    }
}

public void GetPaymentAllocations()
{
    //Create List of Applicants for the agreement
    applicantList=new List<ApplicantWrapper>();
    List<PaymentWrapper> paymentWrapperList = new List<PaymentWrapper>();
    List<AggregateResult> paymentForApplicantList = new List<AggregateResult>();
    List<AggregateResult> paymentForApplicant2List = new List<AggregateResult>();
    Map<String,Decimal> mapPaymentAllocations= new Map<String,Decimal>();
    Map<String,Decimal> mapAllPaymentAllocations= new Map<String,Decimal>();
    List<AggregateResult> applicantAggregateList=[select Payment__r.ApplicantLookup__r.Name applicantName,Payment__r.ApplicantLookup__r.Id applicantId,sum(Actual_Amount__c) paymentTotal from Payment_Allocation__c where Contract__c=:oppId group by Payment__r.ApplicantLookup__r.Name,Payment__r.ApplicantLookup__r.Id];
    if(applicantAggregateList.size()>0)
    {
        for(AggregateResult ar:applicantAggregateList)
        {
            //Initilizing PaymentWrapper list and Map for each iteration
            paymentWrapperList = new List<PaymentWrapper>();
            mapPaymentAllocations = new Map<String,Decimal>();
            ////////////////////////////////////////////////////////////
            ApplicantWrapper appWrap = new ApplicantWrapper();
            appWrap.applicantName= (String)ar.get('applicantName');
            appWrap.applicantId= (String)ar.get('applicantId');
            appWrap.paymentTotal= (Decimal)ar.get('paymentTotal');
            
            //Payment Allocated for the respective applicants - Get sum of allocated amount by grouping the payment allocations by applicants
            paymentForApplicantList=[select sum(Actual_Amount__c) allocatedAmount,Payment__r.Id paymentId from Payment_Allocation__c where Contract__c=: oppId and Payment__r.ApplicantLookup__r.Id=: appWrap.applicantId group by Payment__r.Id];
            if(paymentForApplicantList.size()>0)
            {
                for(AggregateResult paymentForApplicantAr : paymentForApplicantList)
                {
                    mapPaymentAllocations.put((String)paymentForApplicantAr.get('paymentId'),(Decimal)paymentForApplicantAr.get('allocatedAmount'));
                    mapAllPaymentAllocations.put((String)paymentForApplicantAr.get('paymentId'),(Decimal)paymentForApplicantAr.get('allocatedAmount'));
                }
                
            //Get all the Payments and related items and add it in ApplicantWrapper
            List<Payment__c> paymentList = [select id,Name,Payment_Date__c,File_Name__c,RecordType.Name,Total_Paid__c,Payment_File__r.Id,Payment_File__r.Name from Payment__c where id in: mapPaymentAllocations.keySet() order by Payment_Date__c desc];
            if(paymentList.size()>0)
            {
                for(Payment__c pay : paymentList)
                {
                    PaymentWrapper payWrapper = new PaymentWrapper();
                    payWrapper.paymentId=pay.Id;
                    payWrapper.paymentNo=pay.Name;
                    payWrapper.fileName=pay.File_Name__c;
                    payWrapper.paymentFileName=pay.Payment_File__r.Name;
                    payWrapper.paymentFileId=pay.Payment_File__r.Id;
                    payWrapper.paymentAmount=pay.Total_Paid__c;
                    payWrapper.paymentDate=pay.Payment_Date__c;
                    payWrapper.recordType=pay.RecordType.Name;
                    payWrapper.allocatedAmount=mapPaymentAllocations.get(pay.Id);
                    if(payWrapper.allocatedAmount != null && payWrapper.allocatedAmount != 0){
                        paymentWrapperList.add(payWrapper);
                        if(pay.RecordType.Name == 'Credit'){
                            hasCreditPayment = true;
                        }
                    }
                }
                system.debug('paymentWrapperList.size(): '+paymentWrapperList.size());
            }
            }
            appWrap.payments=paymentWrapperList;
            applicantList.add(appWrap);
        }
    }
    
    List<Opportunity> oppList=[select id,Name,Amount,Account.FirstName,Account.LastName,Account.PersonMailingStreet,Account.PersonMailingCity,Account.PersonMailingState,
                                Account.PersonMailingPostalCode,Total_Paid_Amount__c,Remaining_Amount__c,Contract_No__c,Start_Date__c,Term_Months__c,Payment_Frequency__c,
                                Scheduled_Amount__c,Number_Of_SP_for_Cross_Check__c,Account.State_Master_State__c,StageName,CreatedDate ,Last_Paid_Date_Applicant_1_2__c, 
                                NZ_Interest_Rate__c,NZ_Cash_Price_of_goods__c,Fortnightly_Schedule_Payment__c,Statement_Closing_Balance__c,
                                Customer_Support_Phone__c,Customer_Support_Email__c from Opportunity where id=: oppId];
    if(oppList.size()>0)
    {
        opportunity=oppList[0];
        
        products=[select id,Name,Description,Serial_Number__c,Term_Months__c,TotalPrice,Actual_Per_Fortnight__c from OpportunityLineItem where Opportunity.id=:opportunity.Id];
        
        feeProducts = new List<OpportunityLineItem>();
        leasedProducts = new List<OpportunityLineItem>();
        totalFees = 0;
        for(OpportunityLineItem prd : products)
        {
            if(prd.Description <> null && prd.Description == 'Fee')
            {
                feeProducts.add(prd);
                totalFees += (prd.TotalPrice == null ? 0 : prd.TotalPrice);
            }else if(prd.Description <> null && prd.Description <> 'Fee' && prd.Description <> 'Variation')
            {
                leasedProducts.add(prd);
            }
        }
    } 
    
    //Get all Payment Allocations
    /*List<Payment__c> allPaymentList=[select id,Name,Payment_Date__c,File_Name__c,RecordType.Name,Total_Paid__c,Payment_File__r.Id,Payment_File__r.Name from Payment__c where id in: mapAllPaymentAllocations.keySet() order by Payment_Date__c desc];
    Integer i=1;
    if(allPaymentList.size()>0)
    {
        for(Payment__c pay : allPaymentList)
        {
            if(i==1)
                endDate=pay.Payment_Date__c;
            else if(i==allPaymentList.size())
                startDate=pay.Payment_Date__c;  
            i++;
        }
    }*/
    
    AggregateResult[] minPaymentDateList=[select min(Payment_Date__c) minDate from Payment__c where id in: mapAllPaymentAllocations.keySet()];
    if(minPaymentDateList.size()>0)
    {
        startDate=(Date)minPaymentDateList[0].get('minDate'); 
    } 
}

public void GetPaymentAllocationsNZ()
{
    //Create List of Applicants for the agreement
    applicantList=new List<ApplicantWrapper>();
    List<PaymentWrapper> paymentWrapperList = new List<PaymentWrapper>();
    List<AggregateResult> paymentForApplicantList = new List<AggregateResult>();
    List<AggregateResult> paymentForApplicant2List = new List<AggregateResult>();
    Map<String,Decimal> mapPaymentAllocations= new Map<String,Decimal>();
    Map<String,Decimal> mapAllPaymentAllocations= new Map<String,Decimal>();
    List<CurrencyType> currencyTable;
    statementNo = 1;
    List<Opportunity> oppList=[select id,Name,Amount,Account.FirstName,Account.LastName,Account.PersonMailingStreet,Account.PersonMailingCity,Account.PersonMailingState,
                                Account.PersonMailingPostalCode,Total_Paid_Amount__c,Remaining_Amount__c,Contract_No__c,Start_Date__c,Term_Months__c,Payment_Frequency__c,
                                Scheduled_Amount__c,Number_Of_SP_for_Cross_Check__c,Account.State_Master_State__c,StageName,CreatedDate ,Last_Paid_Date_Applicant_1_2__c,Account.CurrencyIsoCode,
                                NZ_Interest_Rate__c,NZ_Cash_Price_of_goods__c,Fortnightly_Schedule_Payment__c,Customer_Statement_Sent_Date__c,Statement_Closing_Balance__c,Taxinvoice_Signed_DateTime__c,
                                Customer_Support_Phone__c,Customer_Support_Email__c from Opportunity where id=: oppId];
    
    if(oppList.size()>0)
    {
        opportunity=oppList[0];
        lastStatementSentDate = (fullStmt != null && fullStmt == 'yes' ? null : opportunity.Customer_Statement_Sent_Date__c);
        startDate = (((fullStmt != null && fullStmt == 'yes') || opportunity.Customer_Statement_Sent_Date__c == null) ? (opportunity.Taxinvoice_Signed_DateTime__c != null ? opportunity.Taxinvoice_Signed_DateTime__c.date() : opportunity.CreatedDate.date()) : opportunity.Customer_Statement_Sent_Date__c.addDays(1));
        if(opportunity.Account.CurrencyIsoCode == 'NZD')
        {
            currencyTable = [SELECT Id, IsoCode, ConversionRate FROM CurrencyType WHERE IsoCode = 'NZD' LIMIT 1];
        }
        
        //get products
        products=[select id,Name,Description,Serial_Number__c,Term_Months__c,TotalPrice,Actual_Per_Fortnight__c from OpportunityLineItem where Opportunity.id=:opportunity.Id];
        feeProducts = new List<OpportunityLineItem>();
        leasedProducts = new List<OpportunityLineItem>();
        totalFees = 0;
        for(OpportunityLineItem prd : products)
        {
            if(prd.Description <> null && prd.Description == 'Fee')
            {
                feeProducts.add(prd);
            }else if(prd.Description <> null && prd.Description <> 'Fee' && prd.Description <> 'Variation')
            {
                leasedProducts.add(prd);
            }
        }

        //get total fees
        List<AggregateResult> feeAggregateList = [SELECT SUM(Fee_Amount__c) totalFees
                                                        FROM Fee__c WHERE 
                                                        Agreement__c = :opportunity.Id AND 
                                                        CreatedDate >= :startDate];
        if(feeAggregateList.size()>0){
            totalFees = (Decimal)feeAggregateList[0].get('totalFees');
            totalFees = (totalFees == null ? 0 : totalFees);
        }

        List<AggregateResult> applicantAggregateList;
        if(opportunity.Account.State_Master_State__c == 'NZ' && lastStatementSentDate != null)
        {
            applicantAggregateList=[select Payment__r.ApplicantLookup__r.Name applicantName,Payment__r.ApplicantLookup__r.Id applicantId,sum(Actual_Amount__c) paymentTotal from Payment_Allocation__c where Contract__c=:oppId AND Payment__r.CreatedDate >: lastStatementSentDate group by Payment__r.ApplicantLookup__r.Name,Payment__r.ApplicantLookup__r.Id];
            List<Attachment> attachList = [SELECT Id FROM Attachment WHERE ParentId =: opportunity.Id AND Name LIKE '%Agreement Statement%'];
            statementNo = attachList.size() + 1;
        }else
        {
            applicantAggregateList=[select Payment__r.ApplicantLookup__r.Name applicantName,Payment__r.ApplicantLookup__r.Id applicantId,sum(Actual_Amount__c) paymentTotal from Payment_Allocation__c where Contract__c=:oppId group by Payment__r.ApplicantLookup__r.Name,Payment__r.ApplicantLookup__r.Id];
        }
        
        if(applicantAggregateList.size()>0)
        {
            for(AggregateResult ar:applicantAggregateList)
            {
                //Initilizing PaymentWrapper list and Map for each iteration
                paymentWrapperList = new List<PaymentWrapper>();
                mapPaymentAllocations = new Map<String,Decimal>();
                ////////////////////////////////////////////////////////////
                ApplicantWrapper appWrap = new ApplicantWrapper();
                appWrap.applicantName= (String)ar.get('applicantName');
                appWrap.applicantId= (String)ar.get('applicantId');
                appWrap.paymentTotal= (Decimal)ar.get('paymentTotal');
                
                //Payment Allocated for the respective applicants - Get sum of allocated amount by grouping the payment allocations by applicants
                if(opportunity.Account.State_Master_State__c == 'NZ')
                {
                    paymentForApplicantList=[select sum(Actual_Amount__c) allocatedAmount,Payment__r.Id paymentId from Payment_Allocation__c where Contract__c=: oppId and Payment__r.ApplicantLookup__r.Id=: appWrap.applicantId AND Payment__r.CreatedDate >: lastStatementSentDate AND Payment__r.CreatedDate <= TODAY group by Payment__r.Id];
                }else
                {
                    paymentForApplicantList=[select sum(Actual_Amount__c) allocatedAmount,Payment__r.Id paymentId from Payment_Allocation__c where Contract__c=: oppId and Payment__r.ApplicantLookup__r.Id=: appWrap.applicantId group by Payment__r.Id];
                }
                
                
                if(paymentForApplicantList.size()>0)
                {
                    for(AggregateResult paymentForApplicantAr : paymentForApplicantList)
                    {
                        mapPaymentAllocations.put((String)paymentForApplicantAr.get('paymentId'),(Decimal)paymentForApplicantAr.get('allocatedAmount'));
                        mapAllPaymentAllocations.put((String)paymentForApplicantAr.get('paymentId'),(Decimal)paymentForApplicantAr.get('allocatedAmount'));
                    }
                
                    //Get all the Payments and related items and add it in ApplicantWrapper
                    List<Payment__c> paymentList;
                    if(opportunity.Account.State_Master_State__c == 'NZ' && lastStatementSentDate != null)
                    {
                        paymentList = [select id,Name,Payment_Date__c,File_Name__c,RecordType.Name,Total_Paid__c,Payment_File__r.Id,Payment_File__r.Name from Payment__c where id in: mapPaymentAllocations.keySet() AND CreatedDate >: lastStatementSentDate order by CreatedDate desc];
                    }else
                    {
                        paymentList = [select id,Name,Payment_Date__c,File_Name__c,RecordType.Name,Total_Paid__c,Payment_File__r.Id,Payment_File__r.Name from Payment__c where id in: mapPaymentAllocations.keySet() order by Payment_Date__c desc];
                    }
                
                    totalPaidAmount = 0;
                    if(paymentList.size()>0)
                    {
                        for(Payment__c pay : paymentList)
                        {
                            PaymentWrapper payWrapper = new PaymentWrapper();
                            payWrapper.paymentId=pay.Id;
                            payWrapper.paymentNo=pay.Name;
                            payWrapper.fileName=pay.File_Name__c;
                            payWrapper.paymentFileName=pay.Payment_File__r.Name;
                            payWrapper.paymentFileId=pay.Payment_File__r.Id;
                            payWrapper.paymentAmount=pay.Total_Paid__c;
                            payWrapper.paymentDate=pay.Payment_Date__c;
                            payWrapper.recordType=pay.RecordType.Name;
                            payWrapper.allocatedAmount = (opportunity.Account.CurrencyIsoCode == 'NZD' && currencyTable <> null && currencyTable.size() > 0 ? mapPaymentAllocations.get(pay.Id) * currencyTable[0].ConversionRate : mapPaymentAllocations.get(pay.Id));
                            if(payWrapper.allocatedAmount != null && payWrapper.allocatedAmount != 0){
                                paymentWrapperList.add(payWrapper);
                                totalPaidAmount += payWrapper.allocatedAmount == null ? 0 : payWrapper.allocatedAmount;
                                if(pay.RecordType.Name == 'Credit'){
                                    hasCreditPayment = true;
                                }
                            }
                        }
                        system.debug('paymentWrapperList.size(): '+paymentWrapperList.size());
                    }
                    if(lastStatementSentDate == null){
                        openingBalance = opportunity.Amount;    
                    }else{
                        openingBalance = (opportunity.Statement_Closing_Balance__c == null ? (opportunity.Remaining_Amount__c + totalPaidAmount) : opportunity.Statement_Closing_Balance__c);
                    }
                }
                appWrap.payments=paymentWrapperList;
                applicantList.add(appWrap);
            }
        }
        
        //Get all Payment Allocations
        /*List<Payment__c> allPaymentList=[select id,Name,Payment_Date__c,File_Name__c,RecordType.Name,Total_Paid__c,Payment_File__r.Id,Payment_File__r.Name from Payment__c where id in: mapAllPaymentAllocations.keySet() order by Payment_Date__c desc];
        Integer i=1;
        if(allPaymentList.size()>0)
        {
            for(Payment__c pay : allPaymentList)
            {
                if(i==1)
                    endDate=pay.Payment_Date__c;
                else if(i==allPaymentList.size())
                    startDate=pay.Payment_Date__c;  
                i++;
            }
        }
        
        AggregateResult[] minPaymentDateList=[select min(Payment_Date__c) minDate from Payment__c where id in: mapAllPaymentAllocations.keySet()];
        if(minPaymentDateList.size()>0)
        {
            startDate=(Date)minPaymentDateList[0].get('minDate'); 
        }*/
    } 
}

public void GetPaymentAllocationsDateWise()
{
    //Create List of Applicants for the agreement
    applicantList=new List<ApplicantWrapper>();
    List<PaymentWrapper> paymentWrapperList = new List<PaymentWrapper>();
    List<AggregateResult> paymentForApplicantList = new List<AggregateResult>();
    List<AggregateResult> paymentForApplicant2List = new List<AggregateResult>();
    Map<String,Decimal> mapPaymentAllocations= new Map<String,Decimal>();
    Map<String,Decimal> mapAllPaymentAllocations= new Map<String,Decimal>();
    List<CurrencyType> currencyTable;
    Date pmtStartDate;
    Date pmtEndDate;
    
    if(ApexPages.CurrentPage().getParameters().get('startDate') != null && ApexPages.CurrentPage().getParameters().get('startDate') != ''){
        pmtStartDate = Date.valueOf(ApexPages.CurrentPage().getParameters().get('startDate'));
    }
    if(ApexPages.CurrentPage().getParameters().get('endDate') != null && ApexPages.CurrentPage().getParameters().get('endDate') != ''){
        pmtEndDate = Date.valueOf(ApexPages.CurrentPage().getParameters().get('endDate'));
    }
    
    List<Opportunity> oppList=[select id,Name,Amount,Account.FirstName,Account.LastName,Account.PersonMailingStreet,Account.PersonMailingCity,Account.PersonMailingState,
                                Account.PersonMailingPostalCode,Total_Paid_Amount__c,Remaining_Amount__c,Contract_No__c,Start_Date__c,Term_Months__c,Payment_Frequency__c,
                                Scheduled_Amount__c,Number_Of_SP_for_Cross_Check__c,Account.State_Master_State__c,StageName,CreatedDate ,Last_Paid_Date_Applicant_1_2__c,Account.CurrencyIsoCode,
                                NZ_Interest_Rate__c,NZ_Cash_Price_of_goods__c,Fortnightly_Schedule_Payment__c,Customer_Statement_Sent_Date__c,Statement_Closing_Balance__c,
                                Customer_Support_Phone__c,Customer_Support_Email__c from Opportunity where id=: oppId];
    
    if(oppList.size()>0)
    {
        opportunity=oppList[0];
        lastStatementSentDate = opportunity.Customer_Statement_Sent_Date__c;
        if(opportunity.Account.CurrencyIsoCode == 'NZD')
        {
            currencyTable = [SELECT Id, IsoCode, ConversionRate FROM CurrencyType WHERE IsoCode = 'NZD' LIMIT 1];
        }
        
        products=[select id,Name,Description,Serial_Number__c,Term_Months__c,TotalPrice,Actual_Per_Fortnight__c from OpportunityLineItem where Opportunity.id=:opportunity.Id];
        
        feeProducts = new List<OpportunityLineItem>();
        leasedProducts = new List<OpportunityLineItem>();
        totalFees = 0;
        for(OpportunityLineItem prd : products)
        {
            if(prd.Description <> null && prd.Description == 'Fee')
            {
                feeProducts.add(prd);
                totalFees += (prd.TotalPrice == null ? 0 : prd.TotalPrice);
            }else if(prd.Description <> null && prd.Description <> 'Fee' && prd.Description <> 'Variation')
            {
                leasedProducts.add(prd);
            }
        }
    }
    
    List<AggregateResult> applicantAggregateList;
    statementNo = 1;
    
    if(pmtStartDate != null && pmtEndDate != null){
        applicantAggregateList = [select Payment__r.ApplicantLookup__r.Name applicantName,Payment__r.ApplicantLookup__r.Id applicantId,sum(Actual_Amount__c) paymentTotal 
                                    from Payment_Allocation__c where Contract__c=:oppId AND Payment__r.CreatedDate >=: pmtStartDate AND Payment__r.CreatedDate <=: pmtEndDate 
                                    group by Payment__r.ApplicantLookup__r.Name,Payment__r.ApplicantLookup__r.Id];
    }else if(pmtStartDate != null){
        applicantAggregateList = [select Payment__r.ApplicantLookup__r.Name applicantName,Payment__r.ApplicantLookup__r.Id applicantId,sum(Actual_Amount__c) paymentTotal 
                                    from Payment_Allocation__c where Contract__c=:oppId AND Payment__r.CreatedDate >=: pmtStartDate 
                                    group by Payment__r.ApplicantLookup__r.Name,Payment__r.ApplicantLookup__r.Id];
    }else if(pmtEndDate != null){
        applicantAggregateList = [select Payment__r.ApplicantLookup__r.Name applicantName,Payment__r.ApplicantLookup__r.Id applicantId,sum(Actual_Amount__c) paymentTotal 
                                    from Payment_Allocation__c where Contract__c=:oppId AND Payment__r.CreatedDate <=: pmtEndDate 
                                    group by Payment__r.ApplicantLookup__r.Name,Payment__r.ApplicantLookup__r.Id];
    }else{
        applicantAggregateList = [select Payment__r.ApplicantLookup__r.Name applicantName,Payment__r.ApplicantLookup__r.Id applicantId,sum(Actual_Amount__c) paymentTotal 
                                    from Payment_Allocation__c where Contract__c=:oppId 
                                    group by Payment__r.ApplicantLookup__r.Name,Payment__r.ApplicantLookup__r.Id];
    }
    
    if(applicantAggregateList.size()>0)
    {
        for(AggregateResult ar:applicantAggregateList)
        {
            //Initilizing PaymentWrapper list and Map for each iteration
            paymentWrapperList = new List<PaymentWrapper>();
            mapPaymentAllocations = new Map<String,Decimal>();
            ////////////////////////////////////////////////////////////
            ApplicantWrapper appWrap = new ApplicantWrapper();
            appWrap.applicantName= (String)ar.get('applicantName');
            appWrap.applicantId= (String)ar.get('applicantId');
            appWrap.paymentTotal= (Decimal)ar.get('paymentTotal');
            
            //Payment Allocated for the respective applicants - Get sum of allocated amount by grouping the payment allocations by applicants
            if(pmtStartDate != null && pmtEndDate != null){
                paymentForApplicantList=[select sum(Actual_Amount__c) allocatedAmount,Payment__r.Id paymentId from Payment_Allocation__c where Contract__c=: oppId and Payment__r.ApplicantLookup__r.Id=: appWrap.applicantId AND Payment__r.CreatedDate >=: pmtStartDate AND Payment__r.CreatedDate <=: pmtEndDate group by Payment__r.Id];
            }else if(pmtStartDate != null){
                paymentForApplicantList=[select sum(Actual_Amount__c) allocatedAmount,Payment__r.Id paymentId from Payment_Allocation__c where Contract__c=: oppId and Payment__r.ApplicantLookup__r.Id=: appWrap.applicantId AND Payment__r.CreatedDate >=: pmtStartDate group by Payment__r.Id];
            }else if(pmtEndDate != null){
                paymentForApplicantList=[select sum(Actual_Amount__c) allocatedAmount,Payment__r.Id paymentId from Payment_Allocation__c where Contract__c=: oppId and Payment__r.ApplicantLookup__r.Id=: appWrap.applicantId AND Payment__r.CreatedDate <=: pmtEndDate group by Payment__r.Id];
            }else{
                paymentForApplicantList=[select sum(Actual_Amount__c) allocatedAmount,Payment__r.Id paymentId from Payment_Allocation__c where Contract__c=: oppId and Payment__r.ApplicantLookup__r.Id=: appWrap.applicantId group by Payment__r.Id];
            }
            
            
            if(paymentForApplicantList.size()>0)
            {
                for(AggregateResult paymentForApplicantAr : paymentForApplicantList)
                {
                    mapPaymentAllocations.put((String)paymentForApplicantAr.get('paymentId'),(Decimal)paymentForApplicantAr.get('allocatedAmount'));
                    mapAllPaymentAllocations.put((String)paymentForApplicantAr.get('paymentId'),(Decimal)paymentForApplicantAr.get('allocatedAmount'));
                }
            
                //Get all the Payments and related items and add it in ApplicantWrapper
                List<Payment__c> paymentList = [select id,Name,Payment_Date__c,File_Name__c,RecordType.Name,Total_Paid__c,Payment_File__r.Id,Payment_File__r.Name from Payment__c where id in: mapPaymentAllocations.keySet() order by Payment_Date__c desc];
            
                totalPaidAmount = 0;
                if(paymentList.size()>0)
                {
                    for(Payment__c pay : paymentList)
                    {
                        PaymentWrapper payWrapper = new PaymentWrapper();
                        payWrapper.paymentId=pay.Id;
                        payWrapper.paymentNo=pay.Name;
                        payWrapper.fileName=pay.File_Name__c;
                        payWrapper.paymentFileName=pay.Payment_File__r.Name;
                        payWrapper.paymentFileId=pay.Payment_File__r.Id;
                        payWrapper.paymentAmount=pay.Total_Paid__c;
                        payWrapper.paymentDate=pay.Payment_Date__c;
                        payWrapper.recordType=pay.RecordType.Name;
                        payWrapper.allocatedAmount = (opportunity.Account.CurrencyIsoCode == 'NZD' && currencyTable <> null && currencyTable.size() > 0 ? mapPaymentAllocations.get(pay.Id) * currencyTable[0].ConversionRate : mapPaymentAllocations.get(pay.Id));
                        if(payWrapper.allocatedAmount != null && payWrapper.allocatedAmount != 0){
                            paymentWrapperList.add(payWrapper);
                            totalPaidAmount += payWrapper.allocatedAmount == null ? 0 : payWrapper.allocatedAmount;
                            if(pay.RecordType.Name == 'Credit'){
                                hasCreditPayment = true;
                            }
                        }
                    }
                    system.debug('paymentWrapperList.size(): '+paymentWrapperList.size());
                }
                
                //openingBalance = opportunity.Statement_Closing_Balance__c == null ? opportunity.Remaining_Amount__c + totalPaidAmount : opportunity.Statement_Closing_Balance__c;
                //totalFeesNZ = openingBalance - opportunity.Remaining_Amount__c - totalPaidAmount;
            }
            appWrap.payments=paymentWrapperList;
            applicantList.add(appWrap);
        }
    }
    
    AggregateResult[] minPaymentDateList=[select min(Payment_Date__c) minDate from Payment__c where id in: mapAllPaymentAllocations.keySet()];
    if(minPaymentDateList.size()>0)
    {
        startDate=(Date)minPaymentDateList[0].get('minDate'); 
    } 
}

public void getArchivedPaymentAllocationsCL()
{
    /*if(Test.isRunningTest()){
        oppId = '0066F00000k6NQZ';
    }*/
    opportunity = [select id,Name,Amount,Account.FirstName,Account.LastName,Account.PersonMailingStreet,Account.PersonMailingCity,Account.PersonMailingState,
                                    Account.PersonMailingPostalCode,Total_Paid_Amount__c,Remaining_Amount__c,Contract_No__c,Start_Date__c,Term_Months__c,Payment_Frequency__c,
                                    Scheduled_Amount__c,Number_Of_SP_for_Cross_Check__c,Account.State_Master_State__c,StageName,CreatedDate ,Last_Paid_Date_Applicant_1_2__c, 
                                    NZ_Interest_Rate__c,NZ_Cash_Price_of_goods__c,Fortnightly_Schedule_Payment__c,Statement_Closing_Balance__c,Total_Paid_Amount_Archived__c,
                                    Customer_Support_Phone__c,Customer_Support_Email__c,TaxInvoice_Signed_DateTime__c 
                                    from Opportunity where id=: oppId];
    paymentAllocations = new List<PaymentAllocationWrapper>();
    startDate = (opportunity.Taxinvoice_Signed_DateTime__c != null ? opportunity.Taxinvoice_Signed_DateTime__c.date() : opportunity.CreatedDate.date());
    openingBalance = opportunity.Amount;
    statementNo = 1;
    totalPaidAmount = 0;
    //List<CurrencyType> currencyTable = [SELECT Id, IsoCode, ConversionRate FROM CurrencyType WHERE IsoCode = 'NZD' LIMIT 1];
    
    OwnArchiveIntegration oai = new OwnArchiveIntegration();
    List<Map<String,Object>> paMapList = new List<Map<String,Object>>();
    if(!Test.isRunningTest()){
        paMapList = oai.getArchivedRecords('Payment_Allocation__c', 'Contract__c', opportunity.Id);
    }
    System.debug('paMapList: ' + paMapList);
    
    if(Test.isRunningTest() || paMapList.size() > 0){
        List<OwnArchiveIntegration.PaymentAllocation> pmtAllocations = new List<OwnArchiveIntegration.PaymentAllocation>();
        if(!Test.isRunningTest()){
            pmtAllocations = oai.parseArchivedPaymentAllocations(paMapList);
        }else{
            OwnArchiveIntegration.PaymentAllocation owpa = new OwnArchiveIntegration.PaymentAllocation();
            owpa.paymentId = 'a096F000029nsfA';
            owpa.actualAmount = 50;
            pmtAllocations.add(owpa);
        }
        System.debug('pmtAllocations: ' + pmtAllocations);
        System.debug('pmtAllocations: ' + pmtAllocations.size());
        
        if(pmtAllocations.size() > 0){
            Map<Id, PaymentAllocationWrapper> pmtAllocatedMap = new Map<Id, PaymentAllocationWrapper>();
            for(Integer i=0; i<pmtAllocations.size(); i++){
                totalPaidAmount += (pmtAllocations[i].actualAmount ?? 0);
                if(pmtAllocatedMap.containsKey(pmtAllocations[i].paymentId)){
                    Decimal totalAllocated = (pmtAllocatedMap.get(pmtAllocations[i].paymentId).allocatedAmount ?? 0) + (pmtAllocations[i].actualAmount ?? 0);
                    pmtAllocatedMap.get(pmtAllocations[i].paymentId).allocatedAmount = totalAllocated;
                }else{
                    System.debug('paymentId: ' + pmtAllocations[i].paymentId);
                    PaymentAllocationWrapper pmtWrap = new PaymentAllocationWrapper();
                    pmtWrap.paymentId = pmtAllocations[i].paymentId;
                    pmtWrap.allocatedAmount = pmtAllocations[i].actualAmount;
                    pmtWrap.paymentDate = pmtAllocations[i].paymentDate;
                    pmtWrap.recordType = pmtAllocations[i].paymentFileRecordType;
                    pmtWrap.paymentNo = pmtAllocations[i].name;
                    pmtWrap.fileName = pmtAllocations[i].fileName;
                    paymentAllocations.add(pmtWrap);
                    pmtAllocatedMap.put(pmtAllocations[i].paymentId, pmtWrap);
                }
            }
            
            paymentAllocations.sort();
        }
    }
    
    products=[select id,Name,Description,Serial_Number__c,Term_Months__c,TotalPrice,Actual_Per_Fortnight__c from OpportunityLineItem where Opportunity.id=:opportunity.Id];       
    feeProducts = new List<OpportunityLineItem>();
    leasedProducts = new List<OpportunityLineItem>();
    totalFees = 0;
    for(OpportunityLineItem prd : products)
    {
        if(prd.Description <> null && prd.Description == 'Fee')
        {
            feeProducts.add(prd);
            totalFees += (prd.TotalPrice == null ? 0 : prd.TotalPrice);
        }else if(prd.Description <> null && prd.Description <> 'Fee' && prd.Description <> 'Variation')
        {
            leasedProducts.add(prd);
        }
    }
}

public List<PaymentAllocationWrapper> paymentAllocations{get;set;}

public class PaymentAllocationWrapper implements Comparable
{
    public String fileName {get; set;}
    public String paymentFileId {get; set;}
    public String paymentId {get; set;}
    public Decimal allocatedAmount {get; set;}
    public String recordType{get; set;}
    
    public String paymentNo {get; set;}
    public Decimal paymentAmount {get; set;}
    public Date paymentDate{get;set;}

    public Integer compareTo(Object compareTo) {
        PaymentAllocationWrapper pmt = (PaymentAllocationWrapper)compareTo;
        if (paymentDate == pmt.paymentDate) {
            return 0;
        } else if (paymentDate > pmt.paymentDate) {
            return 1;
        } else {
            return -1;
        }
    }
}

public class PaymentWrapper implements Comparable
{
    public String fileName {get; set;}
    public String paymentFileName {get; set;}
    public String paymentFileId {get; set;}
    public String paymentId {get; set;}
    public Decimal allocatedAmount {get; set;}
    public Decimal interestAmount {get; set;}
    public String recordType{get; set;}
    
    public String paymentNo {get; set;}
    public Decimal paymentAmount {get; set;}
    public Date paymentDate{get;set;}
    public String description {get; set;}
    public Decimal loanBalance {get; set;}

    public Integer compareTo(Object compareTo) {
        PaymentWrapper pmt = (PaymentWrapper)compareTo;
        if (paymentDate == pmt.paymentDate) {
            if(paymentNo != null && pmt.paymentNo != null){
                if(Integer.valueOf(paymentNo) > Integer.valueOf(pmt.paymentNo)){
                    return -1;
                }else{
                    return 1;
                }
            }
            return 0;
        } else if (paymentDate > pmt.paymentDate) {
            return -1;
        } else {
            return 1;
        }
    }
}

Public class ApplicantWrapper
{
    public String applicantName{get;set;}
    public String applicantId{get;set;}
    public Decimal paymentTotal{get;set;}
    public List<PaymentWrapper> payments {get;set;}
}
}