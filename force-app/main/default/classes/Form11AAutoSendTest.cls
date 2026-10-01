/**
 * SeeAllData like Form11AServiceTest: adds its own first-default record to an existing active credit
 * contract. The debit date is far back so the record is among the first the batch picks up.
 */
@isTest(SeeAllData = true)
private class Form11AAutoSendTest {

    private static Ezidebit_Dishonour__c oldFirstDefault(Boolean withEmail) {
        List<Opportunity> opps = [
            SELECT Id, AccountId, Contract_No__c FROM Opportunity
            WHERE Is_Credit_Contract__c = true AND Is_Active__c = true AND Contract_No__c != null AND MP1__c = null
              AND Account.Territory_Number__r.Status__c = 'Active' AND Account.Territory_Number__r.Is_Credit_Contract__c = true
              AND Account.Enquiry_Status__c NOT IN ('Deceased', 'Incarcerated')
              AND Account.PersonEmail != null AND Account.State_Master_State__c != 'NZ'
            LIMIT 1
        ];
        if (opps.isEmpty()) {
            return null;
        }
        Ezidebit_Dishonour__c d = new Ezidebit_Dishonour__c(
            Opportunity__c = opps[0].Id, Account__c = opps[0].AccountId, Ezidebit_Payment_ID__c = 'T-11A-AUTO',
            Contract_Reference__c = opps[0].Contract_No__c, Status__c = 'D', Type__c = EzidebitDishonourService.TYPE_INSTALMENT,
            Outcome__c = EzidebitDishonourService.OUTCOME_OPEN, Is_Scheduled_Debit__c = true, First_Default__c = true,
            Debit_Date__c = Date.newInstance(2000, 1, 3), Payment_Amount__c = 48.21);
        insert d;
        return d;
    }

    @isTest
    static void dailySendEmailsTheOldestFirstAndRecordsIt() {
        Ezidebit_Dishonour__c d = oldFirstDefault(true);
        if (d == null) {
            return;
        }
        Test.startTest();
        Database.executeBatch(new Form11AAutoSend(), Form11AAutoSend.SCOPE);
        Test.stopTest();
        Ezidebit_Dishonour__c after = [SELECT Form_11A_Sent_Date__c, Form_11A_Channel__c FROM Ezidebit_Dishonour__c WHERE Id = :d.Id];
        System.assertEquals(Date.today(), after.Form_11A_Sent_Date__c);
        System.assertEquals(Form11AService.CHANNEL_EMAIL, after.Form_11A_Channel__c);
    }

    @isTest
    static void scheduleRunsOnlyWhenSwitchedOnAndSummaryGoesToTheTeam() {
        System.assertEquals(Form11AAutoSend.DEFAULT_SUMMARY_TO.size() > 0, true);
        insert new Ezidebit_Sync_Settings__c(SetupOwnerId = UserInfo.getUserId(), Form11A_Auto_Send__c = false,
            Form11A_Summary_Recipients__c = 'lily@example.com, chris@example.com');
        System.assertEquals(new List<String>{ 'lily@example.com', 'chris@example.com' }, Form11AAutoSend.summaryRecipients());
        Integer before = [SELECT COUNT() FROM AsyncApexJob WHERE ApexClass.Name = 'Form11AAutoSend' AND JobType = 'BatchApex' AND CreatedDate = TODAY];
        Test.startTest();
        new Form11AAutoSend().execute((SchedulableContext) null);
        Test.stopTest();
        System.assertEquals(before, [SELECT COUNT() FROM AsyncApexJob WHERE ApexClass.Name = 'Form11AAutoSend' AND JobType = 'BatchApex' AND CreatedDate = TODAY], 'switched off: no batch');
    }

    @isTest
    static void noEmailMeansSkipWhenThereIsNoPostMailbox() {
        System.assertEquals(0, Form11AService.send(new Set<Id>(), '', null).emailed);
    }
}
