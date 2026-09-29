/**
 * "Stop interest" page, opened from the collections page. Sets the date from which no interest is
 * charged on a credit contract (PaymentUtil and the payout figure honour it), with the reason and
 * who approved it. Only people with the Stop_Interest custom permission can save.
 */
public with sharing class InterestStopController {

    public Opportunity opp { get; set; }
    public Boolean canStop { get; private set; }
    public Boolean saved { get; private set; }

    public InterestStopController() {
        Id oppId = ApexPages.currentPage().getParameters().get('oppId');
        canStop = FeatureManagement.checkPermission('Stop_Interest');
        saved = false;
        List<Opportunity> opps = [
            SELECT Id, Name, Contract_No__c, Is_Credit_Contract__c, Interest_Stopped_From__c, Interest_Stop_Reason__c,
                   Interest_Stop_Notes__c, Interest_Stop_Approved_By__c, Interest_Stop_Approved_By__r.Name, Final_Payout_Figure__c
            FROM Opportunity WHERE Id = :oppId LIMIT 1
        ];
        opp = opps.isEmpty() ? null : opps[0];
        if (opp != null && opp.Interest_Stopped_From__c == null) {
            opp.Interest_Stopped_From__c = Date.today();
        }
    }

    public PageReference save() {
        if (!canStop || opp == null) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'You need the Stop Interest permission.'));
            return null;
        }
        if (!opp.Is_Credit_Contract__c) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Interest can only be stopped on a credit contract.'));
            return null;
        }
        if (opp.Interest_Stopped_From__c == null || String.isBlank(opp.Interest_Stop_Reason__c)) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Give the date interest stops from and the reason.'));
            return null;
        }
        if (opp.Interest_Stopped_From__c > Date.today().addDays(60)) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'The stop date can be at most 60 days ahead.'));
            return null;
        }
        return write(opp.Interest_Stopped_From__c, opp.Interest_Stop_Reason__c, opp.Interest_Stop_Notes__c, UserInfo.getUserId(),
            'Interest stopped from ' + opp.Interest_Stopped_From__c.format() + '.');
    }

    /** Restart interest: clears the stop. Interest is charged again from the next payment. */
    public PageReference restart() {
        if (!canStop || opp == null) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'You need the Stop Interest permission.'));
            return null;
        }
        return write(null, null, opp.Interest_Stop_Notes__c, UserInfo.getUserId(), 'Interest restarted.');
    }

    private PageReference write(Date fromDate, String reason, String notes, Id approver, String message) {
        Database.SaveResult sr = Database.update(new Opportunity(Id = opp.Id, Interest_Stopped_From__c = fromDate,
            Interest_Stop_Reason__c = reason, Interest_Stop_Notes__c = notes, Interest_Stop_Approved_By__c = approver), false);
        if (!sr.isSuccess()) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Not saved: ' + String.valueOf(sr.getErrors())));
            return null;
        }
        saved = true;
        ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.CONFIRM, message));
        return null;
    }
}
