public without sharing class CreditContractExpectedInterestCalculator implements Database.Batchable<sObject> {
    private Set<Id> opportunityIds;

    public CreditContractExpectedInterestCalculator() {
        this.opportunityIds = new Set<Id>();
    }

    public CreditContractExpectedInterestCalculator(Set<Id> opportunityIds) {
        this.opportunityIds = opportunityIds;
    }


    // TODO: Remove the Contract_No__c != '33400000217' condition after the issue is resolved.
    public Database.QueryLocator start(Database.BatchableContext context) {
        if(!opportunityIds.isEmpty()){
            return Database.getQueryLocator([
                SELECT 
                    Id, Name, AccountId, Amount, StageName, First_Payment_Received_Date__c, 
                    Interest_Last_Expected__c, Ezidebit_Starting_Date__c, Principal_Last_Expected__c, Total_Loan_Balance_Amount__c, 
                    Payment_Frequency_Number__c, Taxinvoice_Signed_Date__c, Start_Date__c, Daily_Interest_Rate__c, Scheduled_Amount__c,
                    Interest_Accrued_Since_Last_Payment__c, Last_Payment_Received_Date__c, Total_Paid_Interest_Amount__c, Total_Interest_Amount__c
                FROM Opportunity
                WHERE
                    Id IN :opportunityIds AND
                    Is_Credit_Contract__c = true AND 
                    Account.State_Master_State__c != 'NZ' AND 
                    Taxinvoice_Signed_Date__c != null AND
                    StageName != 'Did Not Proceed' AND 
                    Scheduled_Amount__c > 0 AND 
					Total_Interest_Amount__c > 0 AND
                    Contract_No__c != '33400000217'
            ]);
        }else if(Test.isRunningTest()){
            return Database.getQueryLocator([
                SELECT 
                    Id, Name, AccountId, Amount, StageName, First_Payment_Received_Date__c, 
                    Interest_Last_Expected__c, Ezidebit_Starting_Date__c, Principal_Last_Expected__c, Total_Loan_Balance_Amount__c, 
                    Payment_Frequency_Number__c, Taxinvoice_Signed_Date__c, Start_Date__c, Daily_Interest_Rate__c, Scheduled_Amount__c,
                    Interest_Accrued_Since_Last_Payment__c, Last_Payment_Received_Date__c, Total_Paid_Interest_Amount__c, Total_Interest_Amount__c
                FROM Opportunity
                WHERE 
                    StageName in ('Goods Delivered', 'Written Off/Bad Debt') AND
                    Principal_Expected_Exceeds_Loan_Amoount__c = false AND 
                    Is_Credit_Contract__c = true AND 
                    Account.State_Master_State__c != 'NZ' AND 
                    Taxinvoice_Signed_Date__c != null AND 
					Scheduled_Amount__c > 0 AND 
					Total_Interest_Amount__c > 0 AND
                    Contract_No__c != '33400000217'
                ORDER BY Taxinvoice_Signed_Date__c ASC
                LIMIT 10
            ]);
        }else{
            return Database.getQueryLocator([
                SELECT 
                    Id, Name, AccountId, Amount, StageName, First_Payment_Received_Date__c, 
                    Interest_Last_Expected__c, Ezidebit_Starting_Date__c, Principal_Last_Expected__c, Total_Loan_Balance_Amount__c, 
                    Payment_Frequency_Number__c, Taxinvoice_Signed_Date__c, Start_Date__c, Daily_Interest_Rate__c, Scheduled_Amount__c,
                    Interest_Accrued_Since_Last_Payment__c, Last_Payment_Received_Date__c, Total_Paid_Interest_Amount__c, Total_Interest_Amount__c
                FROM Opportunity
                WHERE 
                    Is_Credit_Contract__c = true AND 
                    Account.State_Master_State__c != 'NZ' AND 
                    Taxinvoice_Signed_Date__c != null AND
                    StageName != 'Did Not Proceed' AND 
                    Scheduled_Amount__c > 0 AND 
					Total_Interest_Amount__c > 0 AND
                    Contract_No__c != '33400000217'
                ORDER BY Taxinvoice_Signed_Date__c ASC
            ]);
        }
    }

    public void execute(Database.BatchableContext context, List<Opportunity> opportunities) {
        try{
            Map<Id, Opportunity> opportunityMap = new Map<Id, Opportunity>(opportunities);
            List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();
            Map<Id, Scheduled_Payment__c> scheduledPaymentMap = new Map<Id, Scheduled_Payment__c>();
            
            for (Opportunity opportunity : opportunities) {
                opportunityMap.put(opportunity.Id, opportunity);
            }

            List<Scheduled_Payment__c> scheduledPayments = [
                SELECT 
                    Id, Opportunity__c, Payment_Frequency_Number__c, Is_First_Scheduled_Payment__c, Is_Last_Scheduled_Payment__c,
                    Payment_received_date__c, Principal_Amount__c, Interest_Amount__c, Unpaid_Interest_Amount__c
                FROM Scheduled_Payment__c
                WHERE 
                    Opportunity__c IN :opportunityMap.keySet() AND 
                    Is_Last_Scheduled_Payment__c = true
            ];

            for (Scheduled_Payment__c scheduledPayment : scheduledPayments) {
                if(scheduledPayment.Opportunity__c != null) {
                    scheduledPaymentMap.put(scheduledPayment.Opportunity__c, scheduledPayment);
                }
            }

            Boolean pastBufferPeriod;
            for (Opportunity opportunity : opportunities) {
                pastBufferPeriod = false;
                Opportunity opp = new Opportunity(Id = opportunity.Id, Expected_Interest_Amount_To_Be_Paid__c = 0);
                if(opportunity.StageName == 'Pending Order'){
					opp.Expected_Interest_Amount_To_Be_Paid__c = opportunity.Total_Interest_Amount__c;
				} else if(opportunity.StageName != 'Completed' && opportunity.StageName != 'Terminated' && opportunity.Total_Loan_Balance_Amount__c > 0 && (opportunity.Taxinvoice_Signed_Date__c != null || opportunity.Last_Payment_Received_Date__c != null)){
                    Decimal loanBalance = opportunity.Total_Loan_Balance_Amount__c ?? 0;
                    Date lastPaymentReceivedDate = null;
                    Date nextPaymentDate = null;
                    Decimal unpaidInterestAmount = 0;
                    Decimal interestAccruedSinceLastPayment = 0;
            
                    if(scheduledPaymentMap.containsKey(opportunity.Id)) {
                        // Last Payment Exists
                        pastBufferPeriod = true;
                        unpaidInterestAmount = scheduledPaymentMap.get(opportunity.Id).Unpaid_Interest_Amount__c ?? 0;
                        lastPaymentReceivedDate = opportunity.Last_Payment_Received_Date__c;
                        nextPaymentDate = lastPaymentReceivedDate;
                        while(nextPaymentDate == null || nextPaymentDate < Date.today()){
                            nextPaymentDate = nextPaymentDate.addDays(Integer.valueOf(opportunity.Payment_Frequency_Number__c));
                        }
                        interestAccruedSinceLastPayment = (loanBalance * opportunity.Daily_Interest_Rate__c * (lastPaymentReceivedDate.daysBetween(nextPaymentDate)))/100;                        
                    }else{
                        // Last Payment Does Not Exist
                        Date firstPaymentDate = (opportunity.Ezidebit_Starting_Date__c == null || (opportunity.Ezidebit_Starting_Date__c > opportunity.Taxinvoice_Signed_Date__c.addDays(14))) ? opportunity.Taxinvoice_Signed_Date__c.addDays(Integer.valueOf(opportunity.Payment_Frequency_Number__c)) : opportunity.Ezidebit_Starting_Date__c.addDays(5);
						pastBufferPeriod = (firstPaymentDate <= Date.today() ? true : false);
						nextPaymentDate = firstPaymentDate;
                        while(nextPaymentDate == null || nextPaymentDate < Date.today()){
                            nextPaymentDate = nextPaymentDate.addDays(Integer.valueOf(opportunity.Payment_Frequency_Number__c));
                        }
                        // No payment yet: the first payment will be charged interest from the agreement
                        // start date (PaymentUtil), so project from there, not a buffer plus 14 days.
                        // Start_Date__c is the local signing date; Taxinvoice_Signed_Date__c is the UTC
                        // date, a day early for morning signings, so it is only the fallback.
                        Date interestFrom = opportunity.Start_Date__c != null ? opportunity.Start_Date__c : opportunity.Taxinvoice_Signed_Date__c;
                        interestAccruedSinceLastPayment = (loanBalance * opportunity.Daily_Interest_Rate__c * (interestFrom.daysBetween(nextPaymentDate)))/100;
                    }
                    System.debug('interestAccruedSinceLastPayment: ' + interestAccruedSinceLastPayment);
                    System.debug('loanBalance: ' + loanBalance);
                    System.debug('nextPaymentDate: ' + nextPaymentDate);
            
					if(pastBufferPeriod){
						// past buffer period
						while(loanBalance > 0) {
							Decimal interestPaidThisPayment = 0;
							Decimal amountLeftThisPayment = opportunity.Scheduled_Amount__c ?? 0;
							Decimal principalPaidThisPayment = 0;
				
							// allocate interest accrued since last payment
							if(amountLeftThisPayment >= interestAccruedSinceLastPayment){
								interestPaidThisPayment = interestAccruedSinceLastPayment;
								amountLeftThisPayment = amountLeftThisPayment - interestPaidThisPayment;
							}else{
								interestPaidThisPayment = amountLeftThisPayment;
								amountLeftThisPayment = 0;
								unpaidInterestAmount += (interestAccruedSinceLastPayment - interestPaidThisPayment);
							}
				
							// allocate unpaid interest
							if(amountLeftThisPayment > 0 && unpaidInterestAmount > 0){
								if(amountLeftThisPayment >= unpaidInterestAmount){
									interestPaidThisPayment += unpaidInterestAmount;
									amountLeftThisPayment -= unpaidInterestAmount;
									unpaidInterestAmount = 0;
								}else{
									interestPaidThisPayment += amountLeftThisPayment;
									unpaidInterestAmount -= amountLeftThisPayment;
									amountLeftThisPayment = 0;
								}
							}
				
							// allocate principal
							principalPaidThisPayment = amountLeftThisPayment;
							opp.Expected_Interest_Amount_To_Be_Paid__c += interestPaidThisPayment;
							loanBalance = (loanBalance - principalPaidThisPayment);
							nextPaymentDate = nextPaymentDate.addDays(Integer.valueOf(opportunity.Payment_Frequency_Number__c));
							interestAccruedSinceLastPayment = ((loanBalance * opportunity.Daily_Interest_Rate__c * (Integer.valueOf(opportunity.Payment_Frequency_Number__c)))/100);
				
							System.debug('interestPaidThisPayment: ' + interestPaidThisPayment);
							System.debug('amountLeftThisPayment: ' + amountLeftThisPayment);
							System.debug('principalPaidThisPayment: ' + principalPaidThisPayment);
							System.debug('loanBalance: ' + loanBalance);
							System.debug('nextPaymentDate: ' + nextPaymentDate);
						}
					}else{
						// still in buffer period
						opp.Expected_Interest_Amount_To_Be_Paid__c = opportunity.Total_Interest_Amount__c;
					}
                }

                if((opportunity.StageName.equalsIgnoreCase('Completed') || opportunity.StageName.equalsIgnoreCase('Terminated')) && opportunity.Total_Loan_Balance_Amount__c != null && opportunity.Total_Loan_Balance_Amount__c > 0) {
                    opp.CC_Remaining_Amount__c = 0;
                }else{
                    opp.CC_Remaining_Amount__c = (opportunity.Total_Loan_Balance_Amount__c ?? 0) + (opp.Expected_Interest_Amount_To_Be_Paid__c ?? 0);
                }

                // If the remaining amount is less than -1, set it to 0. This is to avoid the issue where the remaining amount is negative.
                if(opp.CC_Remaining_Amount__c < 0 && opp.CC_Remaining_Amount__c > -1) {
                    opp.CC_Remaining_Amount__c = 0;
                }
                
                opp.CC_Remaining_Amount_DateTime__c = Datetime.now();
                opportunitiesToUpdate.add(opp);
            }

            if(opportunitiesToUpdate.size() > 0) {
                update opportunitiesToUpdate;
            }
        }catch(Exception e){
            /*Messaging.reserveSingleEmailCapacity(2);
            List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new List<String>{'mohitpuli@r4k.com.au'});
            email.setSubject('Error : Credit Contract Expected Interest Calculator');
            email.setPlainTextBody('Error : ' + e.getMessage() + ' Stack Trace : ' + e.getStackTraceString());
            emails.add(email);
            Messaging.sendEmail(emails);*/
            ErrorLog.addErrorLog('CreditContractExpectedInterestCalculator', 'execute', null, e.getMessage(), e.getStackTraceString());
        }
    }

    public void finish(Database.BatchableContext context) {
        Messaging.reserveSingleEmailCapacity(2);
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new List<String>{'mohitpuli@r4k.com.au'});
        email.setSubject('Credit Contract Expected Interest Calculator');
        email.setPlainTextBody('The Credit Contract Expected Interest Calculator has finished running.');
        emails.add(email);
        Messaging.sendEmail(emails);
    }
}