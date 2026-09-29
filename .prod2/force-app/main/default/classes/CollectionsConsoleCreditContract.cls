public class CollectionsConsoleCreditContract{

public Collection_Activity__c currentCollectionActivity{get;set;}
public Collection_Activity__c collectionActivity{get;set;}
public Opportunity opportunity{get;set;}

//COI
public List<Referee__c> refereesRelatedList{get;set;}
public List<AccountWrapper> referringApplicantWrapper{get;set;}
public List<AccountWrapper> referredApplicantWrappers{get;set;}
public List<AccountHistoryWrapper> accountHistoryWrappers{get;set;}
public List<Opportunity> activeOpportunities{get;set;}
public List<Collection_Activity__c> pastCollectionActivities{get;set;}
public List<Collection_Activity__c> otherOpenCAs{get;set;}
public List<ContentNote> pastContentNotes{get;set;}
public List<Task> pastTasks{get;set;}

//Field Visit
public String fieldVisitNotes{get;set;}
public String fieldVisitDateTime{get;set;}
public String landLordMobileNumber{get;set;}
public String fieldRepSurname{get;set;}
public String fieldVisitAddress{get;set;}
public Boolean droppedArrearsFlyer{get;set;}

//Alerts 
public List<Equifax_Alert__c> equifaxAlertsBankruptcy{get;set;}
public List<Equifax_Alert__c> equifaxAlertsAddress{get;set;}
public List<Equifax_Alert__c> equifaxAlertsEnquiry{get;set;}
public List<Equifax_Alert__c> equifaxAlertsEmployment{get;set;}
public List<Equifax_Alert__c> equifaxAlertsDefault{get;set;}

public List<Payment__c> applicantPastPayments{get;set;}
public List<Attachment> selectedApplicantAttachments{get;set;}
public List<smagicinteract__smsMagic__c> selectedApplicantSMSHistory{get;set;}
public List<String> activeOppIds{get;set;}

public Date nextPaymentDueDate{get;set;}
public String stateMasterState{get;set;}
public String mobileNumber{get;set;}
public String refereeName{get;set;}
public String remindMeOn{get;set;}
public Boolean refereesContacted{get;set;}
public String smsTemplateType{get;set;}
public String collectionNotes{get;set;}
public String expectedCollectionDate{get;set;}
public String email{get;set;}
public String emailTemplateType{get;set;}
public String assignedTo{get;set;}
public String nextStep{get;set;}
public String callStatus{get;set;}
public String collectionOfficer{get;set;}
public Id collectionEmployee{get;set;}
public String reasonForSuccess{get;set;}
public List<SelectOption> userOptions{get;set;}
public List<SelectOption> smsOptions{get;set;}
public List<SelectOption> emailOptions{get;set;}

public Account account{get;set;}
public Decimal actualArrears{get;set;}
public Decimal actualArrearsOriginal{get;set;}

//Arrangement Section
public Boolean isThisAnArrangement{get;set;}
public String p1PaymentFrequency{get;set;}
public String p2PaymentFrequency{get;set;}
public Decimal p1ScheduledAmount{get;set;}
public Decimal p2ScheduledAmount{get;set;}
public Decimal expectedAmount{get;set;}
public String p1NextDueDate{get;set;}
public String p2NextDueDate{get;set;}
public String arrangementEndDate{get;set;}
public String arrangementNotes{get;set;}
public Boolean excludeSendingArrearsLetters{get;set;}
public Boolean excludeSendingSMS{get;set;}
public Boolean excludeChargingFees{get;set;}

public Boolean makeSuccessManually{get;set;}
public String reasonSuccessManually{get;set;}
public Decimal paymentAmount{get;set;}
public String paymentType{get;set;}

//Address Section
public String mailingStreet{get;set;}
public String mailingCity{get;set;}
public String mailingState{get;set;}
public String mailingPostalCode{get;set;}
public String mailingCountry{get;set;} 

public String paymentJson{get;set;}
public Decimal fortnightlyAmount{get;set;}
public Integer minimumPaymentFrequency{get;set;}

public String collectedDeviceName{get;set;}
public String collectedDeviceLocation{get;set;}
public String homeLocation{get;set;}
public String shortLinkOpenedDatetime {get;set;}

public List<NoteWrapper> allNotes{get;set;}

public Decimal actualArrearsWrittenOff{get;set;}
public Decimal actualArrearsOriginalWrittenOff{get;set;}
public Decimal remainingAmountWrittenOff{get;set;}
public Decimal tavWrittenOff{get;set;}
public Decimal totalPaidWrittenOff{get;set;}
public String refereesJSON{get;set;}

public String editRefereeEmail{get;set;}
public String editRefereePhone{get;set;}
public String editRefereeContacted{get;set;}
public String editRefereeContactedDate{get;set;}
public String editRefereeContactedDateTime{get;set;}
public String editRefereeId{get;set;}
public String editRefereeContactId{get;set;}
public String customerContactedDateTime{get;set;}
public List<RefereeWrapper> refereeWrapperList{get;set;}

public Integer timesContactedThisWeek{get;set;}
public Integer timesContactedLastWeek{get;set;}

public Integer totalAgreements{get;set;} 
public Integer activeAgreements{get;set;} 
public Decimal totalTAV{get;set;}
public Decimal totalPaid{get;set;}
public Decimal totalRemaining{get;set;}
public Decimal scheduledAmount{get;set;}
public Decimal lastPaidAmount{get;set;}

public String softTemplateForCust{get;set;}
public String mediumTemplateForCust{get;set;}
public String firmTemplateForCust{get;set;}
public String smsProfileTemplateForCust{get;set;}
public String smsProfile{get;set;}
public Boolean isCreditContract{get;set;}

public Decimal lateFees{get;set;}
public Decimal siteVisitFees{get;set;}
public Decimal terminationFees{get;set;}

public List<SelectOption> collectionReasonOptions{get;set;}
public List<SelectOption> collectionReasonCategoryOptions{get;set;}
public List<SelectOption> collectionEmployeeOptions{get;set;}
public String collectionReason{get;set;}
public String collectionReasonCategory{get;set;}

public CollectionsConsoleCreditContract(ApexPages.StandardController controller) 
{
    currentCollectionActivity = (Collection_Activity__c)controller.getRecord();
    collectionActivity = [SELECT Id, Applicant__c, Name,Activity_Type__c,Call_Status__c,Collection_Notes__c,Remind_Me_On__c,Referees_Contacted__c,Person__c,Next_Step__c,SMS_Status__c,Arrears_Amount__c,CreatedDate,
                            Collection_Outcome1__c,Dropped_Arrears_Flyer__c,Email__c,Expected_Collection_Date__c,Short_Link__c,Payment_Status__c,AUS_SMS_Type__c,AUS_Email_Type__c,NZ_SMS_Type__c,NZ_Email_Type__c,
                            Collection_Officer__c,Collection_Employee__c,Collection_Employee__r.Name,Reason_For_Success__c,Collection_Activity_Intitiator__c,Short_Link_Opened_Latitude__c,Short_Link_Opened_Longitude__c,Short_Link_Opened_DateTime__c,Contacted_Date_Time__c,
                            Short_Link_Opened_Device_Brand__c,Short_Link_Opened_Device_Name__c,Short_Link_Opened_Device_Type__c,Short_Link_Opened_Address__c,No_of_Field_Visits__c,Agreement__r.Is_this_a_STA__c,Company_Territory__c,Is_Credit_Contract__c,
                            Applicant__r.Collection_Firm_Sent_DateTime__c,Applicant__r.Collection_Medium_Sent_DateTime__c,Applicant__r.Collection_Soft_Sent_DateTime__c,Agreement__c,Collection_Reason_Category__c,Collection_Reason__c,
                            (SELECT OldValue FROM Histories WHERE Field = 'Contacted_Date_Time__c' ORDER BY CreatedDate ASC) FROM Collection_Activity__c WHERE Id =: currentCollectionActivity.Id LIMIT 1]; 
}

public void getDependentCollectionReasons(){
    Map<String,List<String>> picklistMap = PACollectionsConsoleController.getCollectionCategoryMap();
    collectionReasonOptions = new List<SelectOption>{new SelectOption('', '--None--')};
    if(picklistMap.containsKey(collectionReasonCategory)){
        for(String val : picklistMap.get(collectionReasonCategory)){
            collectionReasonOptions.add(new SelectOption(val, val));
        }
    }
}

public void initializeConsole()
{
    try
    {
        if(collectionActivity.Agreement__c != null)
        {
            opportunity = [SELECT Id, Name, StageName, Amount, Remaining_Amount__c, Total_Paid_Amount__c, Actual_Arrears__c,Account.Territory_Number__r.TM__c,
                           Actual_Arrears_Original__c, No_of_Missed_Payment_Fees_applied__c, Fee_Amount__c,Scheduled_Amount__c,Applicant2__c,Applicant2__r.Name,
                           Missed_Payment_Charged_Date__c,Payment_Frequency__c, CreatedDate, No_of_Remaining_Payments_to_be_Made__c,Fortnightly_Schedule_Payment__c,
                           AccountId,Account.Customer_No__c,Account.Centrepay_Ref_No__c,Account.SMS_Mobile__c,Account.Is_IDR__c,Account.WrittenOff_s_Count__c,
                           Account.Birthdate__c,Account.UnformattedAddress_VedaAlert_Report__c,Account.Territory_Number__r.Collection_Number__c,Days_Since_Expected_Payment__c,
                           Account.Scheduled_Amount_Exc_TR4K__c,Account.Name,Account.Next_Payment_Due_Date__c,Account.Territory_Number__r.State_Master_State__c,
                           Account.PersonMobilePhone,Account.PersonEmail,Account.Payment_Frequency_Payment_Type_1__c,Account.Payment_Frequency_Payment_Type_2__c,
                           Account.Scheduled_Amount_Payment_Type_1__c,Account.Scheduled_Amount_Payment_Type_2__c,Account.Territory_Number__r.Collection_User__c,OwnerId,
                           Account.Next_Due_Date_Payment_Type_1__c,Account.Next_Due_Date_Payment_Type_2__c,Account.Territory_Number__r.Accounting_User__c,Next_Payment_Due_Date__c,
                           Account.Last_Expected_Amount__c,Account.CAP_Exclude_Sending_Arrears_Letter__c,Account.CAP_Exclude_Charging_Fees__c,Account.CAP_Exclude_Sending_SMS__c,
                           Account.PersonMailingStreet,Account.PersonMailingCity,Account.PersonMailingState,Account.PersonMailingPostalCode,Account.PersonMailingCountry,
                           Account.Arrangement_End_Date__c,Account.Is_This_An_Arrangement__c,Account.Arrangement_Notes__c,Account.Territory_Number__r.Latitude__c,
                           Account.Territory_Number__r.Longitude__c,Account.Sensis_Latitude__c,Account.Sensis_Longitude__c,Account.Territory_Number__r.Collection_User__r.Name,
                           Account.Territory_Number__r.Accounting_User__r.Name,Account.Territory_Number__r.TM__r.Name,Account.Collection_Firm_Sent_DateTime__c,
                           Account.Collection_Medium_Sent_DateTime__c,Account.Collection_Soft_Sent_DateTime__c,Account.FirstName,Account.LastName,Contract_No__c,Is_Credit_Contract__c,
                           Total_Loan_Amount__c,Total_Paid_Principal_Amount__c,Total_Loan_Balance_Amount__c,Total_Loan_Amount_Incl_Unpaid_Interest__c,Account.OwnerId,Account.PersonContactId,
                           Is_this_a_STA__c,STA_End_Date__c,STA_Notes__c,STA_Next_Due_Date__c,STA_Scheduled_Amount__c,Account.Company_Territory__c,Account.Territory_Company_Name__c
                           FROM Opportunity WHERE Id = :collectionActivity.Agreement__c AND Is_Credit_Contract__c = true LIMIT 1];
        
            nextPaymentDueDate = opportunity.Next_Payment_Due_Date__c;
            stateMasterState = opportunity.Account.Territory_Number__r.State_Master_State__c;
            mobileNumber = opportunity.Account.PersonMobilePhone;
            email = opportunity.Account.PersonEmail;
            p1PaymentFrequency = opportunity.Account.Payment_Frequency_Payment_Type_1__c;
            p2PaymentFrequency = opportunity.Account.Payment_Frequency_Payment_Type_2__c;
            p1ScheduledAmount = opportunity.Account.Scheduled_Amount_Payment_Type_1__c;
            p2ScheduledAmount = opportunity.Account.Scheduled_Amount_Payment_Type_2__c;
            p1NextDueDate = (opportunity.Account.Next_Due_Date_Payment_Type_1__c == null ? null : opportunity.Account.Next_Due_Date_Payment_Type_1__c.format());
            p2NextDueDate = (opportunity.Account.Next_Due_Date_Payment_Type_2__c == null ? null : opportunity.Account.Next_Due_Date_Payment_Type_2__c.format());
            expectedAmount = opportunity.Account.Last_Expected_Amount__c;
            excludeSendingArrearsLetters = opportunity.Account.CAP_Exclude_Sending_Arrears_Letter__c;
            excludeChargingFees = opportunity.Account.CAP_Exclude_Charging_Fees__c;
            excludeSendingSMS = opportunity.Account.CAP_Exclude_Sending_SMS__c;
            mailingStreet = opportunity.Account.PersonMailingStreet;
            mailingCity = opportunity.Account.PersonMailingCity;
            mailingState = opportunity.Account.PersonMailingState;
            mailingPostalCode = opportunity.Account.PersonMailingPostalCode;
            mailingCountry = opportunity.Account.PersonMailingCountry;
            arrangementEndDate = (opportunity.Account.Arrangement_End_Date__c == null ? null : opportunity.Account.Arrangement_End_Date__c.format());
            isThisAnArrangement = opportunity.Account.Is_This_An_Arrangement__c;
            arrangementNotes = opportunity.Account.Arrangement_Notes__c;
            account = opportunity.Account;
            isCreditContract = opportunity.Is_Credit_Contract__c;
            
            //Home location
            Decimal initialLat = account.Territory_Number__r.Latitude__c;
            Decimal initialLng = account.Territory_Number__r.Longitude__c;
            homeLocation = '{'+'\"lat\":'+ initialLat+','+'\"lng\":'+ initialLng+'}';
            if(account.Sensis_Latitude__c!=null && account.Sensis_Latitude__c !=0 && account.Sensis_Longitude__c!=null && account.Sensis_Longitude__c!=0)
                homeLocation = '{'+'\"lat\":'+ account.Sensis_Latitude__c+','+'\"lng\":'+ account.Sensis_Longitude__c+'}';
            //////////////
            
            userOptions = new List<SelectOption>();
            Set<SelectOption> tempUserSet = new Set<SelectOption>();
            tempUserSet.add(new SelectOption('None','None'));
            tempUserSet.add(new SelectOption(userInfo.getUserId(),userInfo.getName()));
            
            if(opportunity.Account.Territory_Number__r.Collection_User__c != null)
            {
                tempUserSet.add(new SelectOption(opportunity.Account.Territory_Number__r.Collection_User__c,opportunity.Account.Territory_Number__r.Collection_User__r.Name));
            }
            
            if(opportunity.Account.Territory_Number__r.Accounting_User__c != null)
            {
                tempUserSet.add(new SelectOption(opportunity.Account.Territory_Number__r.Accounting_User__c,opportunity.Account.Territory_Number__r.Accounting_User__r.Name));
            }
            
            if(opportunity.Account.Territory_Number__r.TM__c != null)
            {
                tempUserSet.add(new SelectOption(opportunity.Account.Territory_Number__r.TM__c,opportunity.Account.Territory_Number__r.TM__r.Name));
            }
            
            if(collectionActivity.Person__c != null)
            {
                List<User> userList = [SELECT Id,Name FROM User WHERE Id =: collectionActivity.Person__c LIMIT 1];
                
                if(userList.size() > 0)
                {
                    assignedTo = userList[0].Id;
                    tempUserSet.add(new SelectOption(userList[0].Id,userList[0].Name));
                }
            }
            
            userOptions.addAll(tempUserSet);
        
            remindMeOn = (collectionActivity.Remind_Me_On__c == null ? null : collectionActivity.Remind_Me_On__c.format());
            customerContactedDateTime = (collectionActivity.Contacted_Date_Time__c == null ? null : collectionActivity.Contacted_Date_Time__c.date().format());
            refereesContacted = collectionActivity.Referees_Contacted__c;
            collectionNotes =  collectionActivity.Collection_Notes__c;
            expectedCollectionDate = (collectionActivity.Expected_Collection_Date__c == null ? null : collectionActivity.Expected_Collection_Date__c.format());
            nextStep = collectionActivity.Next_Step__c;
            callStatus = collectionActivity.Call_Status__c;
            collectionOfficer = collectionActivity.Collection_Officer__c ?? collectionActivity.Collection_Activity_Intitiator__c;
            collectionEmployee = collectionActivity.Collection_Employee__c;
            reasonForSuccess = collectionActivity.Reason_For_Success__c;
            makeSuccessManually = false;
            paymentAmount = 0;
            paymentType = 'None';

            isThisSTA = opportunity.Is_this_a_STA__c;
            staEndDate = opportunity.STA_End_Date__c == null ? null : opportunity.STA_End_Date__c.format();
            staNotes = opportunity.STA_Notes__c;
            staDueDate = opportunity.STA_Next_Due_Date__c == null ? null : opportunity.STA_Next_Due_Date__c.format();
            staAmount = opportunity.STA_Scheduled_Amount__c;

            collectionReasonCategory = (collectionActivity.Collection_Reason_Category__c == null ? '' : collectionActivity.Collection_Reason_Category__c);
            collectionReason = (collectionActivity.Collection_Reason__c == null ? '' : collectionActivity.Collection_Reason__c);
            collectionReasonCategoryOptions = new List<SelectOption>{new SelectOption('', '--None--')};
            Schema.DescribeFieldResult collectionReasonCategoryResult = Collection_Activity__c.Collection_Reason_Category__c.getDescribe();
            List<Schema.PicklistEntry> collectionReasonCategoryValues = collectionReasonCategoryResult.getPicklistValues();
            for(Schema.PicklistEntry picklistValue : collectionReasonCategoryValues) {
                System.debug('Label: ' + picklistValue.getLabel() + ', Value: ' + picklistValue.getValue());
                collectionReasonCategoryOptions.add(new SelectOption(picklistValue.getValue(), picklistValue.getLabel()));
            }
            getDependentCollectionReasons();

            collectionEmployeeOptions = new List<SelectOption>();
            if(CollectionsConsoleController.canReassignCollectionActivity(collectionActivity.Id)){
                collectionEmployeeOptions.addAll(CollectionsConsoleController.getCollectionEmployees(collectionActivity.Is_Credit_Contract__c, collectionActivity.Company_Territory__c));
            }else{
                collectionEmployeeOptions.add(new SelectOption(collectionActivity.Collection_Employee__c, collectionActivity.Collection_Employee__r.Name));
            }
            
            allNotes = new List<NoteWrapper>();
            getCollectionActivities();
            System.debug('****smsProfile ' + smsProfile);
            
            firmTemplateForCust = 'FINAL REMINDER - Hi ' + opportunity.Account.FirstName + ', Your R4K account is seriously overdue!\n' + 'Please make payment now at <<LINK>>\n' + 
                                            'If you continue to ignore our attempts to contact you, the goods must be returned immediately!\n' + 
                                            'We reserve our rights to commence enforcement action against you so please do not ignore this message and call us now on ' + 
                                            opportunity.Account.Territory_Number__r.Collection_Number__c + ' to discuss your options.';
                                            
            mediumTemplateForCust = 'OVERDUE - Hi ' + opportunity.Account.FirstName + ', you have an overdue amount that requires immediate payment!\n' + 'Please pay now at <<LINK>>\n' +
                                            'To prevent enforcement action against you, please call us now on ' + opportunity.Account.Territory_Number__r.Collection_Number__c + ' to discuss your options!';
            
            softTemplateForCust = 'REMINDER - Hi ' + opportunity.Account.FirstName + ', It looks like we missed your payment.\n' + 'Please pay now at <<LINK>>\n' +
                                            'OR call us on ' + opportunity.Account.Territory_Number__r.Collection_Number__c + ' to talk about your R4K account.\n' +
                                            'We\'d like to hear from you!';
                                            
            if(smsProfile == 'Firm'){
                smsTemplateType = 'Firm Touch';
                emailTemplateType = 'Firm Touch';
                smsProfileTemplateForCust = firmTemplateForCust;
            }else if(smsProfile == 'Medium'){
                smsTemplateType = 'Medium Touch';
                emailTemplateType = 'Medium Touch';
                smsProfileTemplateForCust = mediumTemplateForCust;
            }else{
                smsTemplateType = 'Soft Touch';
                emailTemplateType = 'Soft Touch';
                smsProfileTemplateForCust = softTemplateForCust;
            }
            
            smsOptions = new List<SelectOption>();
            emailOptions = new List<SelectOption>();
            
            if(stateMasterState != null && stateMasterState == 'NZ')
            {
                smsOptions.add(new SelectOption('DAY 1','DAY 1'));
                smsOptions.add(new SelectOption('DAY 3','DAY 3'));
                smsOptions.add(new SelectOption('DAY 7-29','DAY 7-29'));
                
                emailOptions.add(new SelectOption('DAY 1','DAY 1'));
                emailOptions.add(new SelectOption('DAY 3','DAY 3'));
                emailOptions.add(new SelectOption('DAY 7','DAY 7'));
                emailOptions.add(new SelectOption('DAY 15','DAY 15'));
                emailOptions.add(new SelectOption('DAY 29','DAY 29'));
                emailOptions.add(new SelectOption('DAY 30','DAY 30'));
                
                smsTemplateType = (collectionActivity.NZ_SMS_Type__c != null ? collectionActivity.NZ_SMS_Type__c : null);
                emailTemplateType = (collectionActivity.NZ_Email_Type__c != null ? collectionActivity.NZ_Email_Type__c : null);
            }else{
                smsOptions.add(new SelectOption('Soft Touch','Soft Touch'));
                smsOptions.add(new SelectOption('Medium Touch','Medium Touch'));
                smsOptions.add(new SelectOption('Firm Touch','Firm Touch'));
                
                emailOptions.add(new SelectOption('Soft Touch','Soft Touch'));
                emailOptions.add(new SelectOption('Medium Touch','Medium Touch'));
                emailOptions.add(new SelectOption('Firm Touch','Firm Touch'));
            }
            
            //Add collection Location
            collectedDeviceLocation = 'unavailable';
            if(collectionActivity.Short_Link_Opened_Datetime__c!=null)
            {
                shortLinkOpenedDatetime = collectionActivity.Short_Link_Opened_Datetime__c.format('dd/MM/yyyy hh:mm');
                collectedDeviceName = collectionActivity.Short_Link_Opened_Device_Brand__c+' '+collectionActivity.Short_Link_Opened_Device_Name__c+' - '+collectionActivity.Short_Link_Opened_Device_Type__c;
            }
            if(collectionActivity.Short_Link_Opened_Latitude__c!=null && collectionActivity.Short_Link_Opened_Latitude__c!='' && collectionActivity.Short_Link_Opened_Latitude__c!='No Location Access' && collectionActivity.Short_Link_Opened_Longitude__c!=null && collectionActivity.Short_Link_Opened_Longitude__c!='' && collectionActivity.Short_Link_Opened_Longitude__c!='No Location Access')
            {
                collectedDeviceLocation = '{'+'\"lat\":'+ collectionActivity.Short_Link_Opened_Latitude__c+','+'\"lng\":'+ collectionActivity.Short_Link_Opened_Longitude__c+'}';
            }
            system.debug('collectedDeviceLocation: '+collectedDeviceLocation);
            ////////////////////////////
            
            timesContactedThisWeek = 0;
            timesContactedLastWeek = 0;
            
            getRefereeDetails();
            getOpportunities();
            getTasks();
            getContentNotes();
            getPastPayments();
            getEquifaxAlerts();
            getSMSHistory();
            allNotes.sort();
            getFees();
            
            timesContactedThisWeek += (collectionActivity.Contacted_Date_Time__c != null && collectionActivity.Contacted_Date_Time__c.date() >= Date.today().toStartofWeek() && collectionActivity.Contacted_Date_Time__c.date() < Date.today().addDays(7).toStartofWeek()) ? 1 : 0;
            
            timesContactedLastWeek += (collectionActivity.Contacted_Date_Time__c != null && collectionActivity.Contacted_Date_Time__c.date() >= Date.today().addDays(-7).toStartofWeek() && collectionActivity.Contacted_Date_Time__c.date() < Date.today().toStartofWeek()) ? 1 : 0;
            
            if(collectionActivity.Histories.size() > 0)
            {
                for(Integer i=0; i < collectionActivity.Histories.size(); i++)
                {
                    timesContactedThisWeek += (collectionActivity.Histories[i].OldValue != null && (DateTime)collectionActivity.Histories[i].OldValue >= Date.today().toStartofWeek() && (DateTime)collectionActivity.Histories[i].OldValue < Date.today().addDays(7).toStartofWeek()) ? 1 : 0;
                    timesContactedLastWeek += (collectionActivity.Histories[i].OldValue != null && (DateTime)collectionActivity.Histories[i].OldValue >= Date.today().addDays(-7).toStartofWeek() && (DateTime)collectionActivity.Histories[i].OldValue < Date.today().toStartofWeek()) ? 1 : 0;
                }
            }
            
            Collection_Activity__c ca = new Collection_Activity__c();
            ca.Id = collectionActivity.Id;
            ca.Times_Conatcted_This_Week__c = timesContactedThisWeek;
            ca.Times_Contacted_Last_Week__c = timesContactedLastWeek;
            
            if(!Test.isRunningTest())
            {
                update ca;
            } 
        }
    }catch(Exception ex){
        ErrorLog.addErrorLog('CollectionsConsoleCreditContract','initializeConsole',collectionActivity.Id,String.valueOf(ex),String.valueOf(ex.getLineNumber()));
    }
} 

public void getFees()
{
    try{
        lateFees = 0;
        siteVisitFees = 0;
        terminationFees = 0;
        List<Fee__c> pastFeeList = [SELECT Id,Fee_Type__c,Fee_Amount__c,Fee_Charged_Date__c,Agreement__c,Account__c 
                                    FROM Fee__c WHERE Agreement__c = :opportunity.Id LIMIT 1000];
        for(Fee__c pf : pastFeeList){
            if(pf.Fee_Type__c == 'Late Payment'){
                lateFees += (pf.Fee_Amount__c == null ? 0 : pf.Fee_Amount__c);
            }else if(pf.Fee_Type__c == 'Site Visit'){
                siteVisitFees += (pf.Fee_Amount__c == null ? 0 : pf.Fee_Amount__c);
            }if(pf.Fee_Type__c == 'Termination'){
                terminationFees += (pf.Fee_Amount__c == null ? 0 : pf.Fee_Amount__c);
            }
        }
    }catch(Exception ex){
        ErrorLog.addErrorLog('CollectionsConsoleCreditContract','getFees',collectionActivity.Id,String.valueOf(ex),String.valueOf(ex.getLineNumber()));
    }
}

public PageReference actionCollectionActivitySMS()
{
    try
    {
        String smsMobileNumber;
        String shortLink;
        String smsText;
        
        if(mobileNumber != null)
        {
            Collection_Activity__c ca = new Collection_Activity__c();
            ca.Id = collectionActivity.Id;
            
            if(stateMasterState == 'NZ')
           {
                smsMobileNumber = (mobileNumber.startsWith('0')) ? ('64' + mobileNumber.substring(1)) : ('64' + mobileNumber);
                ca.NZ_SMS_Type__c = smsTemplateType;
            }else
            {
                smsMobileNumber = (mobileNumber.startsWith('0')) ? ('61' + mobileNumber.substring(1)) : ('61' + mobileNumber);
                ca.AUS_SMS_Type__c = smsTemplateType;
            }
            
            //if(collectionActivity.Short_Link__c == null || collectionActivity.Short_Link__c.trim() == '')
            //{
                String eid = '';
                String finalURL = '';
                String shortURL = '';
                String firstOppId = collectionActivity.Agreement__c;               
                
                eid = collectionActivity.Applicant__c + '/' + firstOppId;
                EzidebitSiteController es = new EzidebitSiteController();
                finalURL = es.createEncryptedURL('',eid);      
                if(!Test.isRunningTest()){
                    ShortLinkGeneratorUtil sl = new ShortLinkGeneratorUtil();
                    shortURL = sl.shortLinkGenerator(finalURL);
                }
                ca.Short_Link__c = shortURL;
                shortLink = shortURL;
            //}else{
              //  shortLink = collectionActivity.Short_Link__c;
            //}
            
            if(stateMasterState == 'NZ')
            {
                if(smsTemplateType == null || smsTemplateType == 'DAY 1')
                {
                    smsText = 'Hi ' + account.FirstName + ', unfortunately your R4K payment of $' + (opportunity.Scheduled_Amount__c == null ? 0 : opportunity.Scheduled_Amount__c).setScale(2) + ' has been missed! Easily catch up on your payment at ' + shortLink + ' or call one of our friendly staff on ' + account.Territory_Number__r.Collection_Number__c;
                }else if(smsTemplateType == 'DAY 3')
                {
                    smsText = 'Hi ' + account.FirstName + ', Urgent payment needed for $' + (opportunity.Scheduled_Amount__c == null ? 0 : opportunity.Scheduled_Amount__c).setScale(2) + ' that was due on ' + opportunity.Next_Payment_Due_Date__c.format() + ', to avoid further action against you pay now at ' + shortLink + ' or call ' + account.Territory_Number__r.Collection_Number__c + ' to resolve immediately!';
                }else if(smsTemplateType == 'DAY 7-29')
                {
                    smsText = 'Hi ' + account.FirstName + ', your R4K payment of $' + (opportunity.Scheduled_Amount__c == null ? 0 : opportunity.Scheduled_Amount__c).setScale(2) + ' is seriously overdue and needs to be paid ASAP. Avoid a Repossession Warning Notice by calling today on ' + account.Territory_Number__r.Collection_Number__c + ' to talk with us about your payment options or pay now at ' + shortLink;
                }
            }else{

                if(smsTemplateType != null)
                {
                    Account acctToUp = new Account();
                    acctToUp.Id = account.Id;
                    if(smsTemplateType == 'Firm Touch')
                    {
                        smsProfileTemplateForCust = 'FINAL REMINDER - Hi ' + account.FirstName + ', Your R4K account is seriously overdue!\n' + 'Please make payment now at ' + shortLink + '\n' + 
                                                    'If you continue to ignore our attempts to contact you, the goods must be returned immediately!\n' + 
                                                    'We reserve our rights to commence enforcement action against you so please do not ignore this message and call us now on ' + 
                                                    account.Territory_Number__r.Collection_Number__c + ' to discuss your options.';
                        acctToUp.Collection_Firm_Sent_DateTime__c = DateTime.now();
                    }else if(smsTemplateType == 'Medium Touch')
                    {
                        smsProfileTemplateForCust = 'OVERDUE - Hi ' + account.FirstName + ', you have an overdue amount that requires immediate payment!\n' + 'Please pay now at ' + shortLink + '\n' +
                                                    'To prevent enforcement action against you, please call us now on ' + account.Territory_Number__r.Collection_Number__c + ' to discuss your options!';
                        acctToUp.Collection_Medium_Sent_DateTime__c = DateTime.now();
                    }else if(smsTemplateType == 'Soft Touch')
                    {
                        smsProfileTemplateForCust = 'REMINDER - Hi ' + account.FirstName + ', It looks like we missed your payment.\n' + 'Please pay now at ' + shortLink + '\n' +
                                                    'OR call us on ' + account.Territory_Number__r.Collection_Number__c + ' to talk about your R4K account.\n' +
                                                    'We\'d like to hear from you!';
                        acctToUp.Collection_Soft_Sent_DateTime__c = DateTime.now();
                    }
                    smsText = smsProfileTemplateForCust;
                    update acctToUp;
                }else{
                    if(collectionActivity.Activity_Type__c == 'Status')
                    {
                        smsText = ( 'Hi ' + account.FirstName + ', we noticed a variation to your payment. To avoid late fees, make payment via ' );
                        smsText += shortLink;
                        smsText += '. Thanks R4K ' + account.Territory_Number__r.Short_Name__c + ', ' + account.Territory_Number__r.Collection_Number__c; 
                    }else{
                        smsText = ( 'Hi ' + account.FirstName + ', your rental agreement is now overdue. Late fees may apply.' );       
                        smsText += ' To avoid, make payment via ';
                        smsText += shortLink;
                        smsText += '. Thanks R4K ' + account.Territory_Number__r.Short_Name__c + ', ' + account.Territory_Number__r.Collection_Number__c;
                    }
                }
            }
            
            /*List<smagicinteract__smsMagic__c> smsObjectList = new List<smagicinteract__smsMagic__c>();
            smagicinteract__smsMagic__c smsObject = new smagicinteract__smsMagic__c();
            smsObject.smagicinteract__SenderId__c = 'r4k';
            smsObject.smagicinteract__Name__c = 'CollectionsConsole-'+smsTemplateType.replace('Touch','').trim(); // records name
            smsObject.smagicinteract__Account__c = account.Id;
            smsObject.smagicinteract__Opportunity__c = opportunity.Id;
            smsObject.OwnerId = opportunity.OwnerId;
            smsObject.smagicinteract__ObjectType__c = 'Opportunity'; // record type
            smsObject.smagicinteract__disableSMSOnTrigger__c = 0; // this field either be 0 or 1, if you specify the value as 1 then sms will not get send but entry of sms will get create under SMS History object
            smsObject.smagicinteract__external_field__c = smagicinteract.ApexAPI.generateUniqueKey();
            smsObject.smagicinteract__PhoneNumber__c = smsMobileNumber;
            smsObject.smagicinteract__SMSText__c = smsText; 
            smsObjectList.add(smsObject);
            
            //String response = smagicinteract.ApexAPI.pushSMSCallout(smsObjectList);
            Database.insert(smsObjectList,false);*/

            CommunicationUtil.insertSMSRecord('r4k', smsMobileNumber, smsText, 'CollectionsConsole-'+smsTemplateType.replace('Touch','').trim(), 'Opportunity', opportunity.Id, opportunity.OwnerId);
            
            ca.Last_SMS_Sent__c = smsText;
            update ca;
        }
        
        
        if(refereeName != null && refereeName != '' && mobileNumber != null && mobileNumber != account.PersonMobilePhone)
        {
            Contact ct = new Contact();
            ct.LastName = refereeName;
            ct.MobilePhone = mobileNumber;
            insert ct;
            
            Referee__c ref = new Referee__c();
            ref.Referee_Name__c = ct.Id;
            ref.Applicant__c = account.Id;
            insert ref;
        }
        
        return new PageReference('/apex/CollectionActivityCreditContractPage?id='+collectionActivity.Id).setRedirect(true);
    }catch(Exception ex){
        ErrorLog.addErrorLog('CollectionsConsoleCreditContract','actionCollectionActivitySMS',collectionActivity.Id,String.valueOf(ex),String.valueOf(ex.getLineNumber()));
        return null;
    }
}

public PageReference actionCollectionActivityEmail()
{
    try
    {
        String shortLink;
        
        if(email != null)
        {              
            Collection_Activity__c ca = new Collection_Activity__c();
            ca.Id = collectionActivity.Id;
            
            //if(collectionActivity.Short_Link__c == null || collectionActivity.Short_Link__c.trim() == '')
            //{
                String eid = '';
                String finalURL = '';
                String shortURL = '';
                String firstOppId = collectionActivity.Agreement__c;

                eid = collectionActivity.Applicant__c + '/' + firstOppId;
                EzidebitSiteController es = new EzidebitSiteController();
                finalURL = es.createEncryptedURL('',eid);  
                if(!Test.isRunningTest()){
                    ShortLinkGeneratorUtil sl = new ShortLinkGeneratorUtil();
                    shortURL = sl.shortLinkGenerator(finalURL);
                }
                ca.Short_Link__c = shortURL;
                shortLink = shortURL;
            //}else{
              //  shortLink = collectionActivity.Short_Link__c;
            //}
            
            if(stateMasterState == 'NZ')
            {
                ca.NZ_Email_Type__c = emailTemplateType;
                
                List<String> toAddresses = new List<string>();                    
                toAddresses.add(email);
                
                String emailTemplate = '';
                
                if(emailTemplateType != null && emailTemplateType == 'DAY 3')
                {
                    emailTemplate = 'NZ_Collection_Day_3';
                }else if(emailTemplateType != null && emailTemplateType == 'DAY 7')
                {
                    emailTemplate = 'NZ_Collection_Day_7';
                }else if(emailTemplateType != null && emailTemplateType == 'DAY 15')
                {
                    emailTemplate = 'NZ_Collection_Day_15';
                }else if(emailTemplateType != null && emailTemplateType == 'DAY 29')
                {
                    emailTemplate = 'NZ_Collection_Day_29';
                }else
                {
                    emailTemplate = 'NZ_Collection_Day_1';
                }
                
                System.debug('*****email ' + toAddresses + ' ****' + emailTemplate + ' *****' + emailTemplateType);
                
                //Email Template Code
                if(emailTemplateType != null && emailTemplateType == 'DAY 29')
                {
                    String nextpaymentDateStr = nextPaymentDueDate!=null ? ((Datetime)nextPaymentDueDate).format('dd/MM/YYYY') : DateTime.now().format('dd/MM/YYYY');
                    String agmtNameDom = '<li style="line-height: normal;">'+opportunity.Name+'</li>';
                    String emailSubject = 'FINAL NOTICE';
                    String emailBody ='<p style="margin-bottom: .0001pt; line-height: normal;"><strong>Customer Name:&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; '+account.Name+'<br /></strong></p>'+
                    '<p style="margin-bottom: .0001pt; line-height: normal;"><strong>Customer Address:&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; '+account.UnformattedAddress_VedaAlert_Report__c+'<br /></strong></p>'+
                    '<p style="margin-bottom: .0001pt; line-height: normal;"><strong>Account Reference:&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;'+opportunity.Contract_No__c+'<br /></strong></p>'+
                    '<p style="margin-bottom: .0001pt; line-height: normal;"><strong>Default Payment:&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; $'+opportunity.Actual_Arrears__c+'<br /></strong></p>'+
                    '<p style="margin-bottom: .0001pt; line-height: normal;"><strong>Payment Date:&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; '+nextpaymentDateStr+'<br /></strong></p>'+
                    '<p style="margin-bottom: .0001pt; line-height: normal;"><strong>&nbsp;</strong></p>'+
                    '<p style="margin-bottom: .0001pt; line-height: normal;">TAKE NOTICE that documents are being prepared for the issue of a <strong>Repossession Warning Notice</strong> to repossess the following agreements:</p><ol>'+
                    agmtNameDom+
                    '</ol><p style="margin-bottom: .0001pt; line-height: normal;">&nbsp;</p>'+
                    '<p style="margin-bottom: .0001pt; line-height: normal;">Enforced action to collect this obligation will result in additional costs to you. Please also note, we will pursue our legal rights with the additional Personal Guarantee signed by you.</p>'+
                    '<p style="margin-bottom: .0001pt; line-height: normal;">&nbsp;</p>'+
                    '<p style="margin-bottom: .0001pt; line-height: normal;">CREDIT DEFAULT in this matter will lead to an entry being registered with NZ&rsquo;s Credit Reporting Agency and making it difficult for you to obtain future credit.</p>'+
                    '<p style="margin-bottom: .0001pt; line-height: normal;">&nbsp;</p>'+
                    '<p style="margin-bottom: .0001pt; line-height: normal;">It is essential that you immediately settle your outstanding arrears as a matter of urgency. The consequence of ignoring this notice could be very serious!</p>'+
                    '<p style="margin-bottom: .0001pt; line-height: normal;">&nbsp;</p>'+
                    '<p style="margin-bottom: .0001pt; line-height: normal;">&nbsp;</p>'+
                    '<p style="margin-bottom: .0001pt; line-height: normal;">Yours faithfully,</p>'+
                    '<p style="margin-bottom: .0001pt; line-height: normal;"><strong>RENT4KEEPS COLLECTIONS NEW ZEALAND<br /></strong></p>';
                    
                    CommunicationUtil.sendEmail(toAddresses,null, null,emailSubject,emailBody, null);
                }else if(emailTemplateType != null && emailTemplateType == 'DAY 30'){
                    Messaging.reserveSingleEmailCapacity(3);
                    List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
                    List<Attachment> attachList = new List<Attachment>();
                    List<Opportunity> opppList = new List<Opportunity>();
                    
                    String emailSubject = '';
                    String emailBody = '';
                    PageReference  pdf;
                    
                    pdf = new PageReference('/apex/NZDefaultLetterDay30?Id=' + collectionActivity.Agreement__c); 
                    emailSubject = 'Rent4Keeps Payment Arrears - DEFAULT LISTING NOTICE';
                    emailBody = '<p>Dear ' + opportunity.Account.FirstName + '</p><br/>';
                    emailBody += '<p>Please read the attached letter regarding your Rent4Keeps rental agreement.</p>';
                    emailBody += '<p>Rental Agreement No. <strong>' + opportunity.Contract_No__c + '</strong> for <strong>' + opportunity.Name + '</strong></p>';
                    emailBody += '<p>Urgent action is required so please call us now on <strong>' + opportunity.account.Territory_Number__r.Collection_Number__c + '</strong>.</p><br/>';
                    emailBody += '<p>Kind Regards<br/><br/><strong>RENT4KEEPS COLLECTIONS NEW ZEALAND</strong></p>';
                    
                    Blob pdfBlob;
                    try 
                    {
                        pdfBlob = pdf.getContentAsPDF();  
                    }catch(VisualforceException e){
                        pdfBlob = Blob.valueOf('Some Text');
                    }
                    string pdfname = opportunity.Name + '_DEFAULT LISTING NOTICE_' + Datetime.now().format('ddMMMyyyy') + '.pdf';
                    String fileType = 'pdf';
                    
                    Attachment attach = new Attachment();
                    attach.ParentId = collectionActivity.Agreement__c;
                    attach.name = pdfname;
                    attach.body = pdfBlob; 
                    attachList.add(attach);
                    
                    List<Messaging.Emailfileattachment> attachmentList = new List<Messaging.Emailfileattachment>();
                    Messaging.Emailfileattachment efa = new Messaging.Emailfileattachment();
                    efa.setFileName(pdfname);
                    efa.setBody(pdfBlob);
                    attachmentList.add(efa);
                    
                    Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                    email.setSubject(emailSubject);
                    email.setToAddresses(toAddresses);
                    email.setHtmlBody(emailBody);
                    email.setFileAttachments(attachmentList);
                    emails.add(email);
                    
                    Opportunity oppp = new Opportunity();
                    oppp.Id = collectionActivity.Agreement__c;
                    oppp.Default_Letter_Sent_Date__c = Date.today();
                    opppList.add(oppp);
                    
                    if(emails.size() > 0)
                    {
                        Messaging.sendEmail(emails);
                    }
                    
                    insert attachList;
                    update opppList;
                }else{
                    Messaging.reserveSingleEmailCapacity(1);
                    List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
                    
                    Contact cont = [SELECT Id,Email FROM Contact WHERE Email <> null LIMIT 1];
                    EmailTemplate et = [SELECT Id,Subject, Body FROM EmailTemplate WHERE DeveloperName =: emailTemplate];
                    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                    mail.setTemplateId(et.Id);
                    mail.setToAddresses(toAddresses);
                    mail.setTargetObjectId(cont.Id);
                    mail.setWhatId(collectionActivity.Id);
                    mail.setSaveAsActivity(false);
                    mail.setUseSignature(false);
                    mail.setTreatTargetObjectAsRecipient(false);
                    
                    if(emailTemplateType != null && emailTemplateType == 'DAY 15')
                    {
                        String dateOutput = Datetime.now().format('ddMMMyyyy');
                        PageReference pdfPend = new PageReference('/apex/PendingDefaultNZ?id=' + collectionActivity.Id);
                        Attachment attachPend = new Attachment();
                        Blob bodyPend;
                        try {
                         bodyPend = pdfPend.getContentAsPDF();   
                        } catch (VisualforceException e) {
                            bodyPend = Blob.valueOf('Some Text');
                        }
                        attachPend.ParentId = collectionActivity.Applicant__c;
                
                        attachPend.name = 'PendingDefaultNZ_'+dateOutput+'.pdf';
                        attachPend.body = bodyPend;
                        insert attachPend;
                        
                        system.debug('attachPend: '+attachPend.Id);
                        
                        List<Messaging.Emailfileattachment> fileAttachments = new List<Messaging.Emailfileattachment>();
                        Attachment[] watts=[select Name, Body, BodyLength from Attachment where parentid=:collectionActivity.Applicant__c and Name like 'PendingDefaultNZ_%' order by CreatedDate desc limit 1];
                        if(watts.size()>0)
                        {
                            Attachment at = watts[0];
                            Messaging.Emailfileattachment efa = new Messaging.Emailfileattachment();
                            efa.setFileName(at.Name);
                            efa.setBody(at.Body);
                            fileAttachments.add(efa);
                            
                            system.debug('fileAttachments.size(): '+fileAttachments.size());
                            mail.setFileAttachments(fileAttachments);
                        }
                    }
                    emails.add(mail);
                    Messaging.sendEmail(emails);
                }
            }else{
                ca.AUS_Email_Type__c = emailTemplateType;
                String emailSubject = 'R4K Collection - Payment Overdue';
                String emailBody = '';

                if(emailTemplateType != null)
                {
                    if(emailTemplateType == 'Firm Touch')
                    {
                        emailBody = 'FINAL REMINDER - Hi ' + account.FirstName + ', Your R4K account is seriously overdue!<br><br>' + 'Please make payment now at ' + shortLink + '<br><br>' + 
                                                    'If you continue to ignore our attempts to contact you, the goods must be returned immediately!<br><br>' + 
                                                    'We reserve our rights to commence enforcement action against you so please do not ignore this message and call us now on ' + 
                                                    account.Territory_Number__r.Collection_Number__c + ' to discuss your options.';
                    }else if(emailTemplateType == 'Medium Touch')
                    {
                        emailBody = 'OVERDUE - Hi ' + account.FirstName + ', you have an overdue amount that requires immediate payment!<br><br>' + 'Please pay now at ' + shortLink + '<br><br>' +
                                                    'To prevent enforcement action against you, please call us now on ' + account.Territory_Number__r.Collection_Number__c + ' to discuss your options!';
                    }else if(emailTemplateType == 'Soft Touch')
                    {
                        emailBody = 'REMINDER - Hi ' + account.FirstName + ', It looks like we missed your payment.<br><br>' + 'Please pay now at ' + shortLink + '<br><br>' +
                                                    'OR call us on ' + account.Territory_Number__r.Collection_Number__c + ' to talk about your R4K account.<br><br>' +
                                                    'We\'d like to hear from you!';
                    }
                }else{
                    if(collectionActivity.Activity_Type__c == 'Status')
                    {
                        emailBody += ( 'Hi, ' + account.FirstName + ' we noticed a variation to your payment. To avoid late fees, make payment via ' );       
                        emailBody += shortLink;
                        emailBody += '.<br><br>Thanks R4K ' + account.Territory_Number__r.Short_Name__c + ', ' + account.Territory_Number__r.Collection_Number__c;
                    }else{
                        emailBody += ( 'Hi, ' + account.FirstName + ' your rental agreement is now overdue. Late fees may apply.' );       
                        emailBody += ' To avoid, make payment via ';
                        emailBody += shortLink;
                        emailBody += '.<br><br>Thanks R4K ' + account.Territory_Number__r.Short_Name__c + ', ' + account.Territory_Number__r.Collection_Number__c;
                    }
                }

                OrgWideEmailAddress owa = [select id, Address, DisplayName from OrgWideEmailAddress where DisplayName = 'R4K Collections' LIMIT 1];
                
                Messaging.reserveSingleEmailCapacity(1);
                List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setSubject(emailSubject);
                mail.setHtmlBody(emailBody);
                mail.setToAddresses(new List<String>{email});
                mail.setTargetObjectId(opportunity.Account.PersonContactId);
                mail.setWhatId(opportunity.Id);
                mail.setSaveAsActivity(true);
                mail.setUseSignature(false);
                mail.setTreatTargetObjectAsRecipient(false);
                mail.setOrgWideEmailAddressId(owa.Id);
                emails.add(mail);
                Messaging.sendEmail(emails);
            }
            update ca;
        }
        
        
        if(refereeName != null && refereeName != '' && email != null && email != account.PersonEmail)
        {
            Contact ct = new Contact();
            ct.LastName = refereeName;
            ct.Email = email;
            insert ct;
            
            Referee__c ref = new Referee__c();
            ref.Referee_Name__c = ct.Id;
            ref.Applicant__c = account.Id;
            insert ref;
        }

        return new PageReference('/apex/CollectionActivityCreditContractPage?id='+collectionActivity.Id).setRedirect(true);
    }catch(Exception ex){
        ErrorLog.addErrorLog('CollectionsConsoleCreditContract','actionCollectionActivityEmail',collectionActivity.Id,String.valueOf(ex),String.valueOf(ex.getLineNumber()));
        return null;
    }
}

public void getRefereeDetails()
{
    try
    {
        if(collectionActivity.Applicant__c != null)
        {    
            List<Account> acctList = [SELECT Id, Referring_Applicant__c, Referring_Applicant__r.Id,Referring_Applicant__r.Applicant__c, Territory_Number__c,
             Territory_Number__r.State_Master_State__c, Customer_Photo_Id__c, Landlord_Telephone__c FROM Account WHERE Id =: collectionActivity.Applicant__c LIMIT 1];
        
            if(acctList.size() > 0)
            {
                List<Opportunity> tempOpportunities = new List<Opportunity>();
                Decimal total = 0;
                landLordMobileNumber = '';
                
                if(acctList[0].Landlord_Telephone__c != null)
                {
                    if(acctList[0].Territory_Number__r.State_Master_State__c == 'NZ')
                    {
                        if(acctList[0].Landlord_Telephone__c.startsWith('0'))
                        {
                            landLordMobileNumber = ('64' + acctList[0].Landlord_Telephone__c.substring(1));
                        }else{
                            landLordMobileNumber = ('64' + acctList[0].Landlord_Telephone__c);
                        }
                    }else{
                        if(acctList[0].Landlord_Telephone__c.startsWith('0'))
                        {
                            landLordMobileNumber = ('61' + acctList[0].Landlord_Telephone__c.substring(1));
                        }else{
                            landLordMobileNumber = ('61' + acctList[0].Landlord_Telephone__c);
                        }
                    } 
                }
                  
                if(acctList[0].Referring_Applicant__c != null && acctList[0].Referring_Applicant__r.Applicant__c != null)
                {
                    referringApplicantWrapper = new List<AccountWrapper>();
                    List<Account> referringApplicant = [SELECT Id, Name, Active_Agreements__c,Actual_Arrears__c, PersonMobilePhone,PersonMailingStreet,PersonMailingCity,PersonMailingState,PersonMailingPostalCode,PersonMailingCountry, Territory_Number__c, Territory_Number__r.State_Master_State__c FROM Account WHERE Id =: acctList[0].Referring_Applicant__r.Applicant__c LIMIT 1];
                    
                    tempOpportunities = [SELECT Id, Actual_Arrears__c FROM Opportunity WHERE Account.Id =: acctList[0].Referring_Applicant__r.Applicant__c];
                
                    for(Opportunity opp: tempOpportunities)
                    {
                        total += (opp.Actual_Arrears__c == null ? 0 : opp.Actual_Arrears__c);    
                    }
                    
                    AccountWrapper wrap = new AccountWrapper();
                    wrap.acct = referringApplicant[0];
                    wrap.arrears = total;
                    wrap.mobileNumber = '';
                    
                    if(referringApplicant[0].PersonMobilePhone != null)
                    {
                        if(referringApplicant[0].Territory_Number__r.State_Master_State__c == 'NZ')
                        {
                            if(referringApplicant[0].PersonMobilePhone.startsWith('0'))
                            {
                                wrap.mobileNumber = ('64' + referringApplicant[0].PersonMobilePhone.substring(1));
                            }else{
                                wrap.mobileNumber = ('64' + referringApplicant[0].PersonMobilePhone);
                            }
                        }else{
                            if(referringApplicant[0].PersonMobilePhone.startsWith('0'))
                            {
                                wrap.mobileNumber = ('61' + referringApplicant[0].PersonMobilePhone.substring(1));
                            }else{
                                wrap.mobileNumber = ('61' + referringApplicant[0].PersonMobilePhone);
                            }
                        }
                    }
                    
                    referringApplicantWrapper.add(wrap);
                }
                
                List<Account> referredApplicants = [SELECT Id, Name, Active_Agreements__c,Actual_Arrears__c, PersonMobilePhone,PersonMailingStreet,PersonMailingCity,PersonMailingState,PersonMailingPostalCode,PersonMailingCountry, Territory_Number__c, Territory_Number__r.State_Master_State__c FROM Account WHERE Referring_Applicant__r.Applicant__c =: acctList[0].Id];                           
                referredApplicantWrappers = new List<AccountWrapper>();
                
                for(Account acct : referredApplicants)
                {
                    AccountWrapper wrap = new AccountWrapper();
                    wrap.acct = acct;
                    wrap.mobileNumber = '';
                    total = 0;
                    tempOpportunities = [SELECT Id, Actual_Arrears__c FROM Opportunity WHERE Account.Id =: acct.Id];
                    
                    for(Opportunity opp: tempOpportunities)
                    {
                        total += (opp.Actual_Arrears__c == null ? 0 : opp.Actual_Arrears__c);    
                    }
                    
                    wrap.arrears = total;
                    
                    if(acct.PersonMobilePhone != null)
                    {
                        if(acct.Territory_Number__r.State_Master_State__c == 'NZ')
                        {
                            if(acct.PersonMobilePhone.startsWith('0')){
                                wrap.mobileNumber = ('64' + acct.PersonMobilePhone.substring(1));
                            }else{
                                wrap.mobileNumber = ('64' + acct.PersonMobilePhone);
                            }
                        }else{
                            if(acct.PersonMobilePhone.startsWith('0'))
                            {
                                wrap.mobileNumber = ('61' + acct.PersonMobilePhone.substring(1));
                            }else{
                                wrap.mobileNumber = ('61' + acct.PersonMobilePhone);
                            }
                        }
                    }
                    
                    referredApplicantWrappers.add(wrap);
                }
                
                refereesRelatedList = [SELECT Id, Name, Email__c, Contacted__c,Contacted_Date_Time__c, Contacted_On_Date__c, Referee_Name__c,Referee_Name__r.Name,Referee_Name__r.MobilePhone, Relationship__c, Street__c, State__c, Postcode__c, Phone__c,SMS_Referee_Mobile__c, City__c, 
                                        (SELECT OldValue FROM Histories WHERE Field ='Contacted_Date_Time__c' ORDER BY CreatedDate ASC) FROM Referee__c WHERE Applicant__c =: acctList[0].Id];
                
                refereeWrapperList = new List<RefereeWrapper>();
                for(Referee__c ref : refereesRelatedList)
                {                    
                    RefereeWrapper wrap = new RefereeWrapper();
                    wrap.referee = ref;
                    wrap.timesContactedThisWeek = 0;
                    wrap.timesContactedLastWeek = 0;
                    
                    if(ref.Contacted_Date_Time__c != null && ref.Contacted_Date_Time__c.date() >= Date.today().toStartofWeek() && ref.Contacted_Date_Time__c.date() < Date.today().addDays(7).toStartofWeek())
                    {
                        wrap.timesContactedThisWeek++;
                        timesContactedThisWeek++;
                    }
                    
                    if(ref.Contacted_Date_Time__c != null && ref.Contacted_Date_Time__c.date() >= Date.today().addDays(-7).toStartofWeek() && ref.Contacted_Date_Time__c.date() < Date.today().toStartofWeek())
                    {
                        wrap.timesContactedLastWeek++;
                        timesContactedLastWeek++;
                    }
                    
                    if(ref.Histories.size() > 0)
                    {
                        for(Integer i=0; i < ref.Histories.size(); i++)
                        {
                            if(ref.Histories[i].OldValue != null && (DateTime)ref.Histories[i].OldValue >= Date.today().toStartofWeek() && (DateTime)ref.Histories[i].OldValue < Date.today().addDays(7).toStartofWeek())
                            {
                                wrap.timesContactedThisWeek++;
                                timesContactedThisWeek++;
                            }
                            
                            if(ref.Histories[i].OldValue != null && (DateTime)ref.Histories[i].OldValue >= Date.today().addDays(-7).toStartofWeek() && (DateTime)ref.Histories[i].OldValue < Date.today().toStartofWeek())
                            {
                                wrap.timesContactedLastWeek++;
                                timesContactedLastWeek++;
                            }
                        }
                    }
                    refereeWrapperList.add(wrap);
                    
                    System.debug('****' + wrap.timesContactedThisWeek);
                }
                
                refereesJson = JSON.serialize(refereeWrapperList).replaceAll('\'','');
                
                
                List<AccountHistory> contactInfoHistory = [SELECT AccountId, Account.Name, CreatedBy.Name, CreatedDate, Field, OldValue,NewValue FROM AccountHistory WHERE AccountId =: acctList[0].Id AND (Field = 'PersonEmail' OR Field = 'PersonMobilePhone' OR Field = 'PersonMailingStreet' OR Field = 'PersonMailingCity' OR Field = 'PersonMailingPostalCode' OR Field = 'PersonMailingState') ORDER BY CreatedDate DESC];
                
                accountHistoryWrappers = new List<AccountHistoryWrapper>();
                
                for(AccountHistory ah : contactInfoHistory)
                {
                    AccountHistoryWrapper wrap = new AccountHistoryWrapper();
                    wrap.acctHistory = ah;
                    
                    Datetime localTime = ah.CreatedDate.Date();
                    localTime = localTime.addHours(ah.CreatedDate.hour());
                    
                    wrap.modifiedDate = localTime;
                    accountHistoryWrappers.add(wrap);
                }                
            }
        }
    }catch(Exception ex){
        ErrorLog.addErrorLog('CollectionsConsoleCreditContract','getRefereeDetails',collectionActivity.Id,String.valueOf(ex),String.valueOf(ex.getLineNumber()));
    }
}

public void getOpportunities()
{
    try
    {
        activeOpportunities = new List<Opportunity>();
        activeOppIds = new List<String>();
        actualArrears = 0;
        actualArrearsOriginal = 0;
        actualArrearsWrittenOff = 0;
        actualArrearsOriginalWrittenOff = 0;
        remainingAmountWrittenOff = 0;
        tavWrittenOff = 0;
        totalPaidWrittenOff = 0;
        
        if(collectionActivity.Applicant__c != null)
        {    
            activeOpportunities = [SELECT Id, Name, StageName, Amount, Remaining_Amount__c, Total_Paid_Amount__c, Actual_Arrears__c,Actual_Arrears_Original__c, 
                                    No_of_Missed_Payment_Fees_applied__c, Fee_Amount__c,Scheduled_Amount__c,Applicant2__c,Applicant2__r.Name,
                                     Missed_Payment_Charged_Date__c,Payment_Frequency__c, CreatedDate, No_of_Remaining_Payments_to_be_Made__c,
                                     Fortnightly_Schedule_Payment__c,Last_Collection_Activity__c,Last_Collection_Activity__r.Collection_Outcome1__c,Last_Collection_Activity__r.Name  
                                     FROM Opportunity WHERE AccountId =: collectionActivity.Applicant__c AND RecordType.Name <> 'Trak SIM' ORDER BY CreatedDate DESC];            
            
            totalAgreements = activeOpportunities.size();
            activeAgreements = 0;
            totalTAV = 0;
            totalPaid = 0;
            totalRemaining = 0;
            scheduledAmount = 0;
            
            for(Opportunity opp : activeOpportunities)
            {
                if(opp.StageName == 'Goods Delivered')
                {
                    activeOppIds.add(opp.Id);
                    actualArrears += (opp.Actual_Arrears__c == null ? 0 : opp.Actual_Arrears__c);
                    actualArrearsOriginal += (opp.Actual_Arrears_Original__c == null ? 0 : opp.Actual_Arrears_Original__c);
                    activeAgreements++;
                    totalTAV += (opp.Amount == null ? 0 : opp.Amount);
                    totalPaid += (opp.Total_Paid_Amount__c == null ? 0 : opp.Total_Paid_Amount__c);
                    totalRemaining += (opp.Remaining_Amount__c == null ? 0 : opp.Remaining_Amount__c);
                    scheduledAmount += (opp.Scheduled_Amount__c == null ? 0 : opp.Scheduled_Amount__c);
                }
                
                if(opp.StageName == 'Written Off / Bad Debt')
                {
                    actualArrearsWrittenOff += (opp.Actual_Arrears__c == null ? 0 : opp.Actual_Arrears__c);
                    actualArrearsOriginalWrittenOff += (opp.Actual_Arrears_Original__c == null ? 0 : opp.Actual_Arrears_Original__c);
                    remainingAmountWrittenOff += (opp.Remaining_Amount__c == null ? 0 : opp.Remaining_Amount__c);
                    tavWrittenOff += (opp.Amount == null ? 0 : opp.Amount);
                    totalPaidWrittenOff += (opp.Total_Paid_Amount__c == null ? 0 : opp.Total_Paid_Amount__c);
                }
            }
            
            selectedApplicantAttachments = [select id,Name,CreatedDate from Attachment where ParentId =: collectionActivity.Applicant__c OR ParentId =: collectionActivity.Agreement__c ORDER BY CreatedDate DESC LIMIT 10];
        }
    }catch(Exception ex){
        ErrorLog.addErrorLog('CollectionsConsoleCreditContract','getOpportunities',collectionActivity.Id,String.valueOf(ex),String.valueOf(ex.getLineNumber()));
    }
}

public void getContentNotes()
{
    try
    {
        pastContentNotes = new List<ContentNote>();
        List<String> contentIds = new List<String>();
        List<Note> oldNotes = new List<Note>();
               
        if(collectionActivity.Applicant__c != null)
        {           
            List<ContentDocumentLink> contentDocLinks = [SELECT LinkedEntityId, ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityID =: collectionActivity.Applicant__c];
            
            for(ContentDocumentLink link : contentDocLinks)
            {
                contentIds.add(link.ContentDocumentId);
            }
            
            pastContentNotes = [SELECT Id, Title, Content, CreatedById, CreatedDate, FileExtension, FileType, LastModifiedById, LastModifiedDate, OwnerId, TextPreview FROM ContentNote WHERE Id in: contentIds ORDER BY CreatedDate DESC LIMIT 5];
            oldNotes = [SELECT Id,Body,Title,LastModifiedDate,CreatedDate FROM Note WHERE ParentId =: collectionActivity.Applicant__c ORDER BY CreatedDate DESC LIMIT 5];
        }
        
        for(ContentNote cn : pastContentNotes)
        {
            NoteWrapper wrap = new NoteWrapper();
            wrap.obj = cn;
            wrap.dateToCompare = cn.CreatedDate.Date();
            wrap.title = cn.Title;
            wrap.description = cn.TextPreview;
            wrap.type = 'Note';
            allNotes.add(wrap);
        }
        
        for(Note cn : oldNotes)
        {
            NoteWrapper wrap = new NoteWrapper();
            wrap.obj = cn;
            wrap.dateToCompare = cn.CreatedDate.Date();
            wrap.title = cn.Title;
            wrap.description = cn.Body;
            wrap.type = 'Note';
            allNotes.add(wrap);
        }
    }catch(Exception ex){
        ErrorLog.addErrorLog('CollectionsConsoleCreditContract','getNotes',collectionActivity.Id,String.valueOf(ex),String.valueOf(ex.getLineNumber()));
    }
}

public void getTasks()
{
    try
    {
        pastTasks = new List<Task>();

        if(collectionActivity.Applicant__c != null)
        {
            pastTasks = [SELECT Id, Subject, Status, Description, CreatedDate,LastModifiedDate, Priority FROM Task WHERE (WhatId =: collectionActivity.Applicant__c OR WhoId =: collectionActivity.Applicant__c) ORDER BY CreatedDate DESC LIMIT 5];
        }
        
        for(Task task : pastTasks)
        {
            NoteWrapper wrap = new NoteWrapper();
            wrap.obj = task;
            wrap.dateToCompare = task.CreatedDate.Date();
            wrap.title = task.Subject;
            wrap.description = task.Description;
            wrap.type = 'Task';
            allNotes.add(wrap);
        }
    }catch(Exception ex){
        ErrorLog.addErrorLog('CollectionsConsoleCreditContract','getTasks',collectionActivity.Id,String.valueOf(ex),String.valueOf(ex.getLineNumber()));
    }
}

public void getCollectionActivities()
{
    try
    {
        pastCollectionActivities = new List<Collection_Activity__c>();
        otherOpenCAs = new List<Collection_Activity__c>();
        Decimal ca6WeeksCount = 0;
        if(collectionActivity.Agreement__c != null)
        {    
            pastCollectionActivities = [SELECT Id,Name,Activity_By__c,Activity_Type__c,Collection_Notes__c,Collection_Outcome1__c,
                                        CreatedDate,LastModifiedDate,Collection_Last_6_Weeks_Count__c,Applicant__c 
                                        FROM Collection_Activity__c 
                                        WHERE Agreement__c =: collectionActivity.Agreement__c 
                                        ORDER BY CreatedDate DESC LIMIT 5];
        }
        otherOpenCAs = [SELECT Id,Name,Activity_By__c,Activity_Type__c,Collection_Notes__c,Collection_Outcome1__c,
                                        CreatedDate,LastModifiedDate,Collection_Last_6_Weeks_Count__c,Applicant__c,
                                        Agreement__c,Agreement__r.Name,Applicant__r.Name
                                        FROM Collection_Activity__c 
                                        WHERE Applicant__c = :collectionActivity.Applicant__c 
                                        AND Agreement__c != :collectionActivity.Agreement__c
                                        AND Collection_Outcome1__c = 'In Progress' 
                                        ORDER BY CreatedDate DESC LIMIT 5];
        for(Collection_Activity__c ca : pastCollectionActivities)
        {
            NoteWrapper wrap = new NoteWrapper();
            wrap.obj = ca;
            wrap.dateToCompare = ca.LastModifiedDate.Date();
            wrap.title = ca.Name;
            wrap.description = ca.Collection_Notes__c;
            wrap.type = 'CA';
            allNotes.add(wrap);
            ca6WeeksCount += ca.Collection_Last_6_Weeks_Count__c;
        }
        
        if(account.Collection_Firm_Sent_DateTime__c != null){
            smsProfile = 'Firm';
        }else if(account.Collection_Medium_Sent_DateTime__c != null){
            smsProfile = 'Firm';
        }else if(account.Collection_Soft_Sent_DateTime__c != null){
            smsProfile = 'Medium';
        }else if(ca6WeeksCount >= 3){
            smsProfile = 'Firm';
        }else if(ca6WeeksCount >= 1){
            smsProfile = 'Medium';
        }else{
            smsProfile = 'Soft';
        }       
    }catch(Exception ex){
        ErrorLog.addErrorLog('CollectionsConsoleCreditContract','getCollectionActivities',collectionActivity.Id,String.valueOf(ex),String.valueOf(ex.getLineNumber()));
    }

}

public void getEquifaxAlerts()
{
    try
    {                   
        equifaxAlertsBankruptcy = [SELECT Id,Name,Alert_Type__c,Applicant__c,Address_Change__c,Bankruptcy_Reference__c,Bankruptcy_Type__c,Credit_Enquiry_Account_Type__c,Credit_Enquiry_Enquirer__c,Default_Latest_Amount__c,Default_Latest_Credit_Provider__c,Default_Status__c,Default_Type__c,
                            Employment_Updated_Employer__c,Applicant__r.PersonMobilePhone,Applicant__r.Territory_Number__c,Applicant__r.Territory_Number__r.State_Master_State__c,Applicant__r.Name,Applicant__r.Customer_No__c,Applicant__r.Veda_File_Number__c,
                            Applicant__r.No_of_Agreements__c,Applicant__r.Active_Agreements__c,Applicant__r.Employer_Name__c,Applicant__r.UnformattedAddress_VedaAlert_Report__c,Applicant__r.WrittenOff_s_Count__c,CreatedDate 
                            FROM Equifax_Alert__c WHERE Applicant__c =: collectionActivity.Applicant__c AND Alert_Type__c = 'Bankruptcy' ORDER BY CreatedDate DESC LIMIT 5];
                            
        equifaxAlertsEmployment = [SELECT Id,Name,Alert_Type__c,Applicant__c,Address_Change__c,Bankruptcy_Reference__c,Bankruptcy_Type__c,Credit_Enquiry_Account_Type__c,Credit_Enquiry_Enquirer__c,Default_Latest_Amount__c,Default_Latest_Credit_Provider__c,Default_Status__c,Default_Type__c,
                            Employment_Updated_Employer__c,Applicant__r.PersonMobilePhone,Applicant__r.Territory_Number__c,Applicant__r.Territory_Number__r.State_Master_State__c,Applicant__r.Name,Applicant__r.Customer_No__c,Applicant__r.Veda_File_Number__c,
                            Applicant__r.No_of_Agreements__c,Applicant__r.Active_Agreements__c,Applicant__r.Employer_Name__c,Applicant__r.UnformattedAddress_VedaAlert_Report__c,Applicant__r.WrittenOff_s_Count__c,CreatedDate 
                            FROM Equifax_Alert__c WHERE Applicant__c =: collectionActivity.Applicant__c AND Alert_Type__c = 'Employment' ORDER BY CreatedDate DESC LIMIT 5];
                            
        equifaxAlertsEnquiry = [SELECT Id,Name,Alert_Type__c,Applicant__c,Address_Change__c,Bankruptcy_Reference__c,Bankruptcy_Type__c,Credit_Enquiry_Account_Type__c,Credit_Enquiry_Enquirer__c,Default_Latest_Amount__c,Default_Latest_Credit_Provider__c,Default_Status__c,Default_Type__c,
                            Employment_Updated_Employer__c,Applicant__r.PersonMobilePhone,Applicant__r.Territory_Number__c,Applicant__r.Territory_Number__r.State_Master_State__c,Applicant__r.Name,Applicant__r.Customer_No__c,Applicant__r.Veda_File_Number__c,
                            Applicant__r.No_of_Agreements__c,Applicant__r.Active_Agreements__c,Applicant__r.Employer_Name__c,Applicant__r.UnformattedAddress_VedaAlert_Report__c,Applicant__r.WrittenOff_s_Count__c,CreatedDate 
                            FROM Equifax_Alert__c WHERE Applicant__c =: collectionActivity.Applicant__c AND Alert_Type__c = 'Enquiry' ORDER BY CreatedDate DESC LIMIT 5];
                            
        equifaxAlertsAddress = [SELECT Id,Name,Alert_Type__c,Applicant__c,Address_Change__c,Bankruptcy_Reference__c,Bankruptcy_Type__c,Credit_Enquiry_Account_Type__c,Credit_Enquiry_Enquirer__c,Default_Latest_Amount__c,Default_Latest_Credit_Provider__c,Default_Status__c,Default_Type__c,
                            Employment_Updated_Employer__c,Applicant__r.PersonMobilePhone,Applicant__r.Territory_Number__c,Applicant__r.Territory_Number__r.State_Master_State__c,Applicant__r.Name,Applicant__r.Customer_No__c,Applicant__r.Veda_File_Number__c,
                            Applicant__r.No_of_Agreements__c,Applicant__r.Active_Agreements__c,Applicant__r.Employer_Name__c,Applicant__r.UnformattedAddress_VedaAlert_Report__c,Applicant__r.WrittenOff_s_Count__c,CreatedDate 
                            FROM Equifax_Alert__c WHERE Applicant__c =: collectionActivity.Applicant__c AND Alert_Type__c = 'Address' ORDER BY CreatedDate DESC LIMIT 5];
                            
        equifaxAlertsDefault = [SELECT Id,Name,Alert_Type__c,Applicant__c,Address_Change__c,Bankruptcy_Reference__c,Bankruptcy_Type__c,Credit_Enquiry_Account_Type__c,Credit_Enquiry_Enquirer__c,Default_Latest_Amount__c,Default_Latest_Credit_Provider__c,Default_Status__c,Default_Type__c,
                            Employment_Updated_Employer__c,Applicant__r.PersonMobilePhone,Applicant__r.Territory_Number__c,Applicant__r.Territory_Number__r.State_Master_State__c,Applicant__r.Name,Applicant__r.Customer_No__c,Applicant__r.Veda_File_Number__c,
                            Applicant__r.No_of_Agreements__c,Applicant__r.Active_Agreements__c,Applicant__r.Employer_Name__c,Applicant__r.UnformattedAddress_VedaAlert_Report__c,Applicant__r.WrittenOff_s_Count__c,CreatedDate 
                            FROM Equifax_Alert__c WHERE Applicant__c =: collectionActivity.Applicant__c AND Alert_Type__c = 'Default' ORDER BY CreatedDate DESC LIMIT 5];
    }catch(Exception ex){
        ErrorLog.addErrorLog('CollectionsConsoleCreditContract','getEquifaxAlerts',collectionActivity.Id,String.valueOf(ex),String.valueOf(ex.getLineNumber()));
    }
}

public void getSMSHistory()
{
    try
    {
        selectedApplicantSMSHistory = [SELECT Id,smagicinteract__SMSText__c,smagicinteract__PhoneNumber__c,smagicinteract__Account__c,smagicinteract__Account__r.Name,smagicinteract__Opportunity__c,smagicinteract__Opportunity__r.Name,CreatedDate,smagicinteract__deliveryStatus__c FROM smagicinteract__smsMagic__c WHERE smagicinteract__Account__c =: collectionActivity.Applicant__c OR smagicinteract__Opportunity__c =: collectionActivity.Agreement__c ORDER BY CreatedDate DESC LIMIT 6];    
    }catch(Exception ex){
        ErrorLog.addErrorLog('CollectionsConsoleCreditContract','getSMSHistory',collectionActivity.Id,String.valueOf(ex),String.valueOf(ex.getLineNumber()));
    }
}

public void getPastPayments()
{
    try
    {
        if(collectionActivity.Agreement__c != null)
        {
            applicantPastPayments = [SELECT Id,Name,RecordType.Name,Amount_Allocated__c,Total_Paid__c,Payment_Allocation_Balance__c,CreatedDate,ApplicantLookup__c,Centrepay_Benefits__c 
                                    FROM Payment__c WHERE Agreement__c =: collectionActivity.Agreement__c AND Is_TR4K__c = false 
                                    ORDER BY CreatedDate Desc LIMIT 7];
            if(applicantPastPayments.size()>0)
            {    
                paymentJson=JSON.serialize(applicantPastPayments);
                lastPaidAmount = applicantPastPayments[0].Total_Paid__c;
                system.debug('paymentJson: '+paymentJson);
            }
            /*
            applicantStatuses = [SELECT Id,Name,Scheduled_Amount__c,Actual_Amount__c,Effective_Date__c,Activation_Code__c,CreatedDate FROM Applicant_Status__c WHERE Account__c =: collectionActivity.Applicant__c ORDER BY CreatedDate DESC LIMIT 6];
            if(applicantStatuses.size()>0)
            {
                appStatusJson=JSON.serialize(applicantStatuses);
                system.debug('appStatusJson: '+appStatusJson);
            }
            */
        }
    }catch(Exception ex){
        ErrorLog.addErrorLog('CollectionsConsoleCreditContract','getPastPayments','',String.valueOf(ex),String.valueOf(ex.getLineNumber()));
    }
}

public PageReference updateCollectionActivity()
{
    try
    {
        Collection_Activity__c ca = new Collection_Activity__c();
        ca.Id = collectionActivity.Id;
        ca.Collection_Notes__c = collectionNotes;
        ca.Referees_Contacted__c = refereesContacted;
        ca.Next_Step__c = nextStep;
        ca.Collection_Employee__c = collectionEmployee;
        ca.Collection_Officer__c = collectionOfficer;
        ca.Collection_Reason__c = collectionReason;
        ca.Collection_Reason_Category__c = collectionReasonCategory;
        
        if(assignedTo == null || assignedTo == '' || assignedTo == 'None')
        {
            ca.Person__c = null;
        }else{
            ca.Person__c = assignedTo;
        }
        
        if(callStatus != null && callStatus.trim() != '')
        {
            ca.Call_Status__c = (callStatus == 'None' ? null : callStatus);
        }

        if(reasonForSuccess != null && reasonForSuccess.trim() != '')
        {
            ca.Reason_For_Success__c = (reasonForSuccess == 'None' ? null : reasonForSuccess);
        }
        
        if(remindMeOn != null && remindMeOn.trim() != '')
        {
            ca.Remind_Me_On__c = Date.parse(remindMeOn);
        }else{
            ca.Remind_Me_On__c = null;
        }
        
        if(customerContactedDateTime != null && customerContactedDateTime.trim() != '')
        {
            ca.Contacted_Date_Time__c = Date.parse(customerContactedDateTime);
        }else{
            ca.Contacted_Date_Time__c = null;
        }
        
        if(expectedCollectionDate != null && expectedCollectionDate.trim() != '')
        {
            ca.Expected_Collection_Date__c = Date.parse(expectedCollectionDate);
        }else{
            ca.Expected_Collection_Date__c = null;
        }
        
        if(makeSuccessManually)
        {
            if(ca.Collection_Notes__c == null)
            {
                ca.Collection_Notes__c = reasonSuccessManually;
            }else{
                ca.Collection_Notes__c = (Date.today().format() + ' - Manual Success' + '\n' + reasonSuccessManually + '\n' + ca.Collection_Notes__c);
            }
            
            if(paymentAmount != null && paymentAmount > 0)
            {
                ca.Payment_Amount__c = paymentAmount;
                ca.Payment_Type__c = paymentType;
                ca.Collection_Date_Time__c = DateTime.now();
            }
            
            ca.Manual_Success__c = true;
            ca.Manual_Success_Date_Time__c = DateTime.now();
            ca.Collection_Outcome1__c = 'Success';
            
            LP1NotClearedAfterPayment lp = new LP1NotClearedAfterPayment();
            lp.closeCollectionCases(new List<String>{collectionActivity.Applicant__c},'Manual Success');
        }
        update ca;
        return new PageReference('/apex/CollectionActivityCreditContractPage?id=' + collectionActivity.Id).setRedirect(true);
    }catch(Exception ex){
        ErrorLog.addErrorLog('CollectionsConsoleCreditContract','updateCollectionActivity',collectionActivity.Id,String.valueOf(ex),String.valueOf(ex.getLineNumber()));
        return null;
    }
}

public PageReference addFieldVisit()
{    
    try
    {
        Collection_Activity__c ca = new Collection_Activity__c();
        ca.Id = collectionActivity.Id;      
        
        if(fieldVisitNotes != null && fieldVisitNotes != '' && fieldVisitNotes.trim() != '')
        {
            ca.Collection_Notes__c =
             Date.today().format() + ' - Field Visit - ' + fieldVisitNotes
             + '. \n' + (collectionNotes == null ? '' : collectionNotes);            
        }
        
        ca.Field_Visit_Date_Time__c = DateTime.now();
        ca.Field_Visit_Representative_Surname__c = fieldRepSurname;
        ca.Field_Visit_Address__c = fieldVisitAddress;
        ca.Dropped_Arrears_Flyer__c = droppedArrearsFlyer;
        ca.No_of_Field_Visits__c = (collectionActivity.No_of_Field_Visits__c == null ? 1 : collectionActivity.No_of_Field_Visits__c + 1);
        
        update ca;
        
        return new PageReference('/apex/CollectionActivityCreditContractPage?id=' + collectionActivity.Id+'&showfees=true').setRedirect(true);
    }catch(Exception ex){
        ErrorLog.addErrorLog('CollectionsConsoleCreditContract','addFieldVisit',collectionActivity.Id,String.valueOf(ex),String.valueOf(ex.getLineNumber()));
        return null;
    }   
}

public PageReference returnToCollectionActivity()
{
    try
    {
        return new PageReference('/apex/CollectionActivityCreditContractPage?id=' + collectionActivity.Id).setRedirect(true);
    }catch(Exception ex){
        ErrorLog.addErrorLog('CollectionsConsoleCreditContract','returnToCollectionActivity',collectionActivity.Id,String.valueOf(ex),String.valueOf(ex.getLineNumber()));
        return null;
    }
}

public PageReference updateReferee()
{
    try
    {
        Referee__c ref = new Referee__c();
        ref.Id = editRefereeId;
        ref.Contacted__c = editRefereeContacted;

        if(editRefereeContactedDate != null)
        {
            ref.Contacted_On_Date__c = Date.parse(editRefereeContactedDate);
            ref.Contacted_Date_Time__c = Date.parse(editRefereeContactedDate);
        }
        
        update ref;
        
        Contact ct = new Contact();
        ct.Id = editRefereeContactId;
        ct.MobilePhone = editRefereePhone;
        ct.Email = editRefereeEmail;
        update ct;
        
        return new PageReference('/apex/CollectionActivityCreditContractPage?id=' + collectionActivity.Id).setRedirect(true);
    }catch(Exception ex){
        ErrorLog.addErrorLog('CollectionsConsoleCreditContract','updateReferee',collectionActivity.Id,String.valueOf(ex),String.valueOf(ex.getLineNumber()));
        return null;
    }
}

public PageReference updateArrangement()
{
    try
    {
        Opportunity opp = new Opportunity();
        opp.Id = collectionActivity.Agreement__c;
        opp.STA_End_Date__c = Date.parse(staEndDate);
        opp.STA_Next_Due_Date__c = Date.parse(staDueDate);
        opp.STA_Notes__c = staNotes;
        opp.STA_Scheduled_Amount__c = staAmount;
        opp.Is_this_a_STA__c = isThisSTA;

        if(isThisSTA && !opportunity.Is_this_a_STA__c){
            opp.MP1__c = null;
            opp.X6Q__c = null;
            opp.X6_Q_Rem_Amt_Sent_Date__c = null;
            opp.X21_D_Sent_Date__c = null;
            opp.STA_Start_Date__c = Date.today();

            if(opportunity.Account.Company_Territory__c){
                String smsTemplateForCust = 'Hi ' + opportunity.Account.FirstName + ', your new payment arrangement with ' + opportunity.Account.Territory_Company_Name__c + ' is now in place.\n\n' +
                                            'Next Payment Due Date: ' + opp.STA_Next_Due_Date__c.format() + '\n' + 
                                            'Payment Amount: $' + opp.STA_Scheduled_Amount__c + '\n' + 
                                            'Payment Frequency: ' + opportunity.Payment_Frequency__c + '\n' + 
                                            'Arrangement End Date: ' + opp.STA_End_Date__c.format() + '\n\n' + 
                                            'Please note that interest will continue to accrue on the unpaid balance. If you miss a payment, the arrangement may be cancelled without notice and collections activity will resume.\n\n' + 
                                            'If you have any issues, contact us on ' + opportunity.Account.Territory_Number__r.Collection_Number__c + ' ASAP to rectify. Notify us immediately of any changes to avoid this arrangement being cancelled. Thank you, R4K Collections.';
                
                //CommunicationUtil.sendSMS(opportunity.Account.SMS_Mobile__c,smsTemplateForCust,'STA','Opportunity',opportunity.Id,opportunity.Account.OwnerId,false,null);
                CommunicationUtil.insertSMSRecord('r4k', opportunity.Account.SMS_Mobile__c, smsTemplateForCust, 'STA', 'Opportunity', opportunity.Id, opportunity.Account.OwnerId);
            }
        }
        update opp;
        return new PageReference('/apex/CollectionActivityCreditContractPage?id=' + collectionActivity.Id).setRedirect(true);
    }catch(Exception ex){
        ErrorLog.addErrorLog('CollectionsConsoleController','updateArrangement',collectionActivity.Id,String.valueOf(ex),String.valueOf(ex.getLineNumber()));
        return null;
    }
}

public String staEndDate{get;set;}
public String staDueDate{get;set;}
public String staNotes{get;set;}
public Decimal staAmount{get;set;}
public Boolean isThisSTA{get;set;}


public class AccountWrapper
{
    public Account acct{get;set;}
    public Decimal arrears{get;set;}
    public String mobileNumber{get;set;}
}

public class AccountHistoryWrapper
{
    public AccountHistory acctHistory{get;set;}
    public DateTime modifiedDate{get;set;}
}

public class RefereeWrapper
{
    public Referee__c referee{get;set;}
    public Integer timesContactedThisWeek{get;set;}
    public Integer timesContactedLastWeek{get;set;}
}

public class NoteWrapper implements Comparable 
{
    public SObject obj{get;set;}
    public Date dateToCompare{get;set;}
    public String title{get;set;}
    public String description{get;set;}
    public String type{get;set;}
    
    // Compare opportunities based on the opportunity amount.
    public Integer compareTo(Object compareTo) {
        // Cast argument to OpportunityWrapper
        NoteWrapper compareToOppy = (NoteWrapper)compareTo;
        
        // The return value of 0 indicates that both elements are equal.
        Integer returnValue = 0;
        if (dateToCompare > compareToOppy.dateToCompare) {
            // Set return value to a positive value.
            returnValue = -1;
        } else if (dateToCompare < compareToOppy.dateToCompare) {
            // Set return value to a negative value.
            returnValue = 1;
        }
        
        return returnValue;       
    }
}

}