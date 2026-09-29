/**
 * Keeps the customer's IDR fields (Account.Involvement_*, IDR dates, Is_IDR__c) in step with their
 * latest hardship request, so everything that already relies on them keeps working:
 * - the CAP console and collections pages leave IDR customers out of SMS, fees and arrears letters;
 * - Opportunity.Is_in_Hardship__c (stage "Assessed", end date not passed) stops interest on each
 *   payment (PaymentUtil) and the "Hardship Assessed - Reset Arrears" flow resets the letters.
 *
 *   Open request (Received / Information requested / Assessing) -> Hardship Request, Received, IDR on
 *   Agreed   -> Hardship Request, Assessed, IDR dates = the agreed change's dates, IDR on
 *   Declined / Withdrawn -> Hardship Request, Closed, IDR end = decision date, IDR off
 *
 * A customer already in another involvement (AFCA, bankruptcy, Part IX, complaint...) is left alone.
 * Switch off with Collections_Settings__c.Disable_Hardship_Account_Sync__c.
 */
public without sharing class HardshipRequestService {

    public static final String INVOLVEMENT_TYPE = 'Hardship Request';
    public static final Set<String> OPEN_STATUSES = new Set<String>{ 'Received', 'Information requested', 'Assessing' };

    /** For the trigger: a failed customer update is logged, never blocks saving the request. */
    public static void syncAccountsSafely(List<Hardship_Request__c> requests) {
        try {
            syncAccounts(requests);
        } catch (Exception ex) {
            ErrorLog.addErrorLog('HardshipRequestService', 'syncAccounts', '', String.valueOf(ex), String.valueOf(ex.getLineNumber()));
        }
    }

    public static void syncAccounts(List<Hardship_Request__c> requests) {
        Collections_Settings__c cs = Collections_Settings__c.getInstance();
        if (cs != null && cs.Disable_Hardship_Account_Sync__c) {
            return;
        }
        Set<Id> accountIds = new Set<Id>();
        Set<Id> oppIds = new Set<Id>();
        for (Hardship_Request__c r : requests) {
            if (r.Account__c != null) {
                accountIds.add(r.Account__c);
            } else if (r.Opportunity__c != null) {
                oppIds.add(r.Opportunity__c);
            }
        }
        if (!oppIds.isEmpty()) {
            for (Opportunity o : [SELECT AccountId FROM Opportunity WHERE Id IN :oppIds]) {
                accountIds.add(o.AccountId);
            }
        }
        accountIds.remove(null);
        if (accountIds.isEmpty()) {
            return;
        }
        // The latest request per customer decides.
        Map<Id, Hardship_Request__c> latest = new Map<Id, Hardship_Request__c>();
        for (Hardship_Request__c r : [
            SELECT Id, Account__c, Opportunity__r.AccountId, Status__c, Received_Date__c, Decision_Date__c, Change_Start_Date__c, Change_End_Date__c
            FROM Hardship_Request__c
            WHERE Account__c IN :accountIds OR Opportunity__r.AccountId IN :accountIds
            ORDER BY Received_Date__c DESC, CreatedDate DESC
        ]) {
            Id acct = r.Account__c != null ? r.Account__c : r.Opportunity__r.AccountId;
            if (acct != null && !latest.containsKey(acct)) {
                latest.put(acct, r);
            }
        }
        List<Account> updates = new List<Account>();
        for (Account a : [SELECT Id, Involvement_Type__c, Involvement_Stage__c, IDR_Start_Date__c, IDR_End_Date__c, Is_IDR__c
                          FROM Account WHERE Id IN :latest.keySet()]) {
            if (String.isNotBlank(a.Involvement_Type__c) && a.Involvement_Type__c != INVOLVEMENT_TYPE) {
                continue; // another involvement (AFCA, bankruptcy...) owns these fields
            }
            Account u = accountFor(latest.get(a.Id), a.Id);
            if (u != null && changed(a, u)) {
                updates.add(u);
            }
        }
        if (updates.isEmpty()) {
            return;
        }
        for (Database.SaveResult sr : Database.update(updates, false)) {
            if (!sr.isSuccess()) {
                ErrorLog.addErrorLog('HardshipRequestService', 'syncAccounts', String.valueOf(sr.getId()), String.valueOf(sr.getErrors()), '');
            }
        }
    }

    @TestVisible
    static Account accountFor(Hardship_Request__c r, Id accountId) {
        Account u = new Account(Id = accountId, Involvement_Type__c = INVOLVEMENT_TYPE);
        if (OPEN_STATUSES.contains(r.Status__c)) {
            u.Involvement_Stage__c = 'Received';
            u.IDR_Start_Date__c = r.Received_Date__c;
            u.IDR_End_Date__c = null;
            u.Is_IDR__c = true;
        } else if (r.Status__c == 'Agreed') {
            u.Involvement_Stage__c = 'Assessed';
            u.IDR_Start_Date__c = r.Change_Start_Date__c != null ? r.Change_Start_Date__c : r.Received_Date__c;
            u.IDR_End_Date__c = r.Change_End_Date__c;
            u.Is_IDR__c = true;
        } else if (r.Status__c == 'Declined' || r.Status__c == 'Withdrawn') {
            u.Involvement_Stage__c = 'Closed';
            u.IDR_End_Date__c = r.Decision_Date__c != null ? r.Decision_Date__c : Date.today();
            u.Is_IDR__c = false;
        } else {
            return null;
        }
        return u;
    }

    private static Boolean changed(Account a, Account u) {
        return a.Involvement_Type__c != u.Involvement_Type__c || a.Involvement_Stage__c != u.Involvement_Stage__c
            || (u.isSet('IDR_Start_Date__c') && a.IDR_Start_Date__c != u.IDR_Start_Date__c)
            || a.IDR_End_Date__c != u.IDR_End_Date__c || a.Is_IDR__c != u.Is_IDR__c;
    }

    /** Fills the customer from the agreement when only the agreement was given. */
    public static void fillCustomer(List<Hardship_Request__c> requests) {
        Set<Id> oppIds = new Set<Id>();
        for (Hardship_Request__c r : requests) {
            if (r.Account__c == null && r.Opportunity__c != null) {
                oppIds.add(r.Opportunity__c);
            }
        }
        if (oppIds.isEmpty()) {
            return;
        }
        Map<Id, Opportunity> opps = new Map<Id, Opportunity>([SELECT Id, AccountId FROM Opportunity WHERE Id IN :oppIds]);
        for (Hardship_Request__c r : requests) {
            if (r.Account__c == null && opps.containsKey(r.Opportunity__c)) {
                r.Account__c = opps.get(r.Opportunity__c).AccountId;
            }
        }
    }
}
