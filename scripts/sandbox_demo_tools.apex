// SANDBOX ONLY: demo data for the collections tools.
Opportunity o7258 = [SELECT Id, AccountId FROM Opportunity WHERE Contract_No__c = '30000007258' LIMIT 1];
Opportunity o8979 = [SELECT Id, AccountId FROM Opportunity WHERE Contract_No__c = '30000008979' LIMIT 1];
insert new Hardship_Request__c(Opportunity__c = o7258.Id, Received_Date__c = Date.newInstance(2026, 9, 22), Channel__c = 'Phone',
    Reason__c = 'Loss of job or reduced income', Change_Requested__c = 'Pause payments', Status__c = 'Assessing',
    Customer_Explanation__c = 'Lost casual shifts; asked to pause for 8 weeks.');
update new Opportunity(Id = o7258.Id, Interest_Stopped_From__c = Date.newInstance(2026, 9, 29), Interest_Stop_Reason__c = 'Hardship',
    Interest_Stop_Notes__c = 'Sandbox demo', Interest_Stop_Approved_By__c = UserInfo.getUserId());
update new Opportunity(Id = o8979.Id, Is_this_a_STA__c = true, STA_Start_Date__c = Date.newInstance(2026, 8, 1),
    STA_Next_Due_Date__c = Date.newInstance(2026, 8, 6), STA_End_Date__c = Date.newInstance(2026, 11, 30), STA_Scheduled_Amount__c = 60,
    STA_Notes__c = 'Sandbox demo arrangement');
Database.executeBatch(new ArrangementCheckBatch(), 100);
Account a = [SELECT Involvement_Type__c, Involvement_Stage__c, Is_IDR__c FROM Account WHERE Id = :o7258.AccountId];
System.debug('RESULT account ' + a.Involvement_Type__c + ' / ' + a.Involvement_Stage__c + ' / IDR ' + a.Is_IDR__c);
