@isTest(SeeAllData = true)
private class InterestStopControllerTest {

    private static User approver(Boolean withPermission) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        String u = 'interest.stop.' + (withPermission ? 'yes' : 'no') + '.' + Crypto.getRandomInteger() + '@r4k.test';
        User usr = new User(Alias = 'istop', Email = u, EmailEncodingKey = 'UTF-8', LastName = 'Stop', LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_AU', ProfileId = p.Id, TimeZoneSidKey = 'Australia/Sydney', UserName = u);
        insert usr;
        if (withPermission) {
            insert new PermissionSetAssignment(AssigneeId = usr.Id,
                PermissionSetId = [SELECT Id FROM PermissionSet WHERE Name = 'Interest_Stop_Approver'].Id);
        }
        return usr;
    }

    private static Opportunity agreement() {
        List<Opportunity> opps = [SELECT Id FROM Opportunity WHERE Is_Credit_Contract__c = true AND Interest_Stopped_From__c = null LIMIT 1];
        return opps.isEmpty() ? null : opps[0];
    }

    @isTest
    static void approver_canStopAndRestart() {
        Opportunity opp = agreement();
        if (opp == null) {
            return;
        }
        User u = approver(true);
        System.runAs(u) {
            Test.setCurrentPage(Page.InterestStop);
            ApexPages.currentPage().getParameters().put('oppId', opp.Id);
            InterestStopController c = new InterestStopController();
            System.assert(c.canStop);
            System.assertEquals(Date.today(), c.opp.Interest_Stopped_From__c, 'defaults to today');
            c.save();
            System.assertEquals(false, c.saved, 'a reason is required');
            c.opp.Interest_Stop_Reason__c = 'Hardship';
            c.opp.Interest_Stopped_From__c = Date.today().addDays(90);
            c.save();
            System.assertEquals(false, c.saved, 'not more than 60 days ahead');
            c.opp.Interest_Stopped_From__c = Date.today();
            Test.startTest();
            c.save();
            System.assert(c.saved);
            Opportunity after = [SELECT Interest_Stopped_From__c, Interest_Stop_Approved_By__c FROM Opportunity WHERE Id = :opp.Id];
            System.assertEquals(Date.today(), after.Interest_Stopped_From__c);
            System.assertEquals(u.Id, after.Interest_Stop_Approved_By__c);
            c.restart();
            Test.stopTest();
            System.assertEquals(null, [SELECT Interest_Stopped_From__c FROM Opportunity WHERE Id = :opp.Id].Interest_Stopped_From__c);
        }
    }

    @isTest
    static void withoutPermission_nothingChanges() {
        Opportunity opp = agreement();
        if (opp == null) {
            return;
        }
        System.runAs(approver(false)) {
            Test.setCurrentPage(Page.InterestStop);
            ApexPages.currentPage().getParameters().put('oppId', opp.Id);
            InterestStopController c = new InterestStopController();
            System.assertEquals(false, c.canStop);
            c.opp.Interest_Stop_Reason__c = 'Other';
            c.save();
            c.restart();
            System.assertEquals(false, c.saved);
        }
        System.assertEquals(null, [SELECT Interest_Stopped_From__c FROM Opportunity WHERE Id = :opp.Id].Interest_Stopped_From__c);
    }
}
