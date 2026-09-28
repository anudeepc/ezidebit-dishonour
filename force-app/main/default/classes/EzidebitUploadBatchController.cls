global class EzidebitUploadBatchController implements Database.Batchable<sObject> {
    global Database.QueryLocator start(Database.BatchableContext BC) {
      
        String query = 'select id, name,CustomerNo__c,CustomerName__c,PaymentAmount__c,ClientFee__c,CustomerFee__c,PaymentMethod__c,PaymentSource__c,PaymentID__c,Ezidebit_Ref_No__c,PaymentDate__c,Date_Settled__c,OwnerId,Owner.Name,Account__c,Opportunity__c,Opportunity__r.Is_Credit_Contract__c,Territory_Name__c,Account__r.Territory_Number__r.State_Master_State__c,Is_TR4K__c,BatchPart__c,Ezidebit_DigitalKey__c,Is_Credit_Contract__c,Payment_File__c from EzidebitSettled__c where Payment_File__c<>null order by Payment_File__c asc'+(Test.isRunningTest()?' LIMIT 1':'');
        return Database.getQueryLocator(query);
     }

     global void execute(Database.BatchableContext BC, List<EzidebitSettled__c> scope) {
        // Duplicate prevention, debit type and dishonour links for the whole scope (EzidebitDishonourService).
        EzidebitDishonourService.UploadContext ctx = EzidebitDishonourService.uploadContext(scope);
        for(EzidebitSettled__c ezi : scope) {
           system.debug('##'+ezi.Id+' - '+ezi.Name +' - '+ezi.CustomerNo__c);
           
           try{
            // Already recorded under the same Ezidebit payment ID: refresh its fee, don't add a copy.
            if(ctx.isDuplicate(ezi))
            {
                delete ezi;
                continue;
            }
            Payment__c payment = new Payment__c(Payment_File__c = ezi.Payment_File__c);
            payment.RecordTypeId           = PaymentUtil.RECORDTYPE_ID_EZIDEBIT;
            payment.Payment_Date__c        = ezi.PaymentDate__c;
            payment.Date_Settled__c        = ezi.Date_Settled__c;
            payment.Ezidebit_Ref_No__c     = ezi.Ezidebit_Ref_No__c;
            payment.Customer_Account_No__c = ezi.CustomerNo__c;
            payment.Schedule_Amount__c     = ezi.PaymentAmount__c;
            payment.Deducted_Amount__c     = ezi.PaymentAmount__c;
            payment.Amount_Deposited__c    = ezi.PaymentAmount__c;
            payment.Actual_Amount__c       = ezi.PaymentAmount__c;
            payment.Client_Fees__c         = ezi.ClientFee__c;
            payment.Ezidebit_Customer_Fee__c = ezi.CustomerFee__c;
            payment.Ezidebit_Payment_Method__c = ezi.PaymentMethod__c;
            payment.Ezidebit_Payment_Source__c = ezi.PaymentSource__c;
            payment.Ezidebit_Payment_ID__c = ezi.PaymentID__c;
            payment.Debit_Type__c = ctx.debitType(ezi);
            ctx.linkBeforeInsert(payment, ezi);
            payment.Fee_Amount__c          = 0;
            payment.Setup_Fee__c           = 0;
            payment.ApplicantLookup__c  = ezi.Account__c;
            payment.Agreement__c  = ezi.Opportunity__c;
            payment.Is_Credit_Contract__c = ezi.Opportunity__r.Is_Credit_Contract__c? true : (ezi.Is_Credit_Contract__c ? true : false);
            payment.Customer_Name__c=ezi.CustomerName__c;
            payment.Payment_Type__c = 'Ezidebit';
            payment.Is_TR4K__c=ezi.Is_TR4K__c;
            payment.Ezidebit_DigitalKey__c=ezi.Ezidebit_DigitalKey__c;
            if(ezi.Account__r.Territory_Number__r.State_Master_State__c=='NZ' || ezi.Territory_Name__c=='North Island')
                payment.CurrencyISOCode='NZD';
            insert payment;
            ctx.linkAfterInsert(payment);

            //If payment is inserted delete the ezidebit settled
            delete ezi;
           }
           catch(Exception ex)
           {
            ErrorLog.addErrorLog('EzidebitUploadBatchController','execute',ezi.Id+' - '+ezi.CustomerNo__c+' - '+ezi.PaymentAmount__c,String.valueOf(ex),String.valueOf(ex.getLineNumber()));
           }
        }
        ctx.flush();
     }
     
     global void finish(Database.BatchableContext BC) {
        sendCompletionEmail();
     }
     
     private void sendCompletionEmail() {
          Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
          mail.setBccAddresses(new String[] {'shrijitservegar@r4k.com.au'});
          mail.setSubject('Ezidebit has been uploaded');
          mail.setPlainTextBody('The job for Ezidebit Upload has been completed');
          Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
      }
}