/**
 * The Form 11A (Direct Debit Default Notice) deadline banner shown on the CAP pages (Form11ADueAlert component).
 * NCC s87(2): the notice must be given within 14 days of the first direct debit default. Due date = debit date + 14.
 * Counts the same agreements as the Form 11A page: active Australian credit contracts with no notice yet
 * (a notice sent from the Dishonours page stamps MP1__c, which counts as sent).
 */
public without sharing class Form11ADueAlertController {

    public class Item {
        public String contractNo { get; set; }
        public String customer { get; set; }
        public Date dueDate { get; set; }
        public Integer daysLeft { get; set; }
        public String label { get; set; }
    }

    public Integer overdue { get; private set; }
    public Integer dueToday { get; private set; }
    public Integer dueSoon { get; private set; }   // within the next 3 days, after today
    public Integer totalUnsent { get; private set; }
    public List<Item> nextDue { get; private set; }
    public Boolean autoSendOn { get; private set; }

    public Form11ADueAlertController() {
        Date today = Date.today();
        overdue = 0;
        dueToday = 0;
        dueSoon = 0;
        totalUnsent = 0;
        nextDue = new List<Item>();
        autoSendOn = EzidebitDishonourService.settings().Form11A_Auto_Send__c;
        for (Ezidebit_Dishonour__c d : [
            SELECT Form_11A_Due_Date__c, Opportunity__r.Contract_No__c, Opportunity__r.Account.Name
            FROM Ezidebit_Dishonour__c
            WHERE First_Default__c = true AND Form_11A_Sent_Date__c = null AND Is_Backfill__c = false
              AND Opportunity__r.Is_Active__c = true AND Opportunity__r.Is_Credit_Contract__c = true
              AND Opportunity__r.MP1__c = null AND Opportunity__r.Account.State_Master_State__c != 'NZ'
            ORDER BY Debit_Date__c ASC
            LIMIT 2000
        ]) {
            totalUnsent++;
            Date due = d.Form_11A_Due_Date__c;
            if (due == null) {
                continue;
            }
            Integer left = today.daysBetween(due);
            if (left < 0) {
                overdue++;
            } else if (left == 0) {
                dueToday++;
            } else if (left <= 3) {
                dueSoon++;
            }
            if (nextDue.size() < 5) {
                Item i = new Item();
                i.contractNo = d.Opportunity__r.Contract_No__c;
                i.customer = d.Opportunity__r.Account.Name;
                i.dueDate = due;
                i.daysLeft = left;
                i.label = left < 0 ? (-left) + (left == -1 ? ' day' : ' days') + ' past the limit'
                    : left == 0 ? 'due today' : 'due in ' + left + (left == 1 ? ' day' : ' days');
                nextDue.add(i);
            }
        }
    }

    /** red: past the limit or due today; amber: due in the next 3 days; green: nothing urgent. */
    public String level {
        get {
            return overdue + dueToday > 0 ? 'red' : (dueSoon > 0 ? 'amber' : 'green');
        }
    }
}
