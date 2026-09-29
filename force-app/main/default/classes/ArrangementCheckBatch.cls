/**
 * Daily: stamps STA_Status__c, STA_Shortfall__c and STA_Checked_Date__c on every agreement with an
 * arrangement, so collections can report on broken ones ("Arrangements behind" report).
 * Only these three fields are written. Switch off with Collections_Settings__c.Disable_Arrangement_Check__c.
 *
 *   System.schedule('Collections-ArrangementCheck', '0 15 7 * * ?', new ArrangementCheckBatch());
 */
public without sharing class ArrangementCheckBatch implements Database.Batchable<SObject>, Schedulable {

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new ArrangementCheckBatch(), 100);
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        Integer rowLimit = Test.isRunningTest() ? 200 : 50000000;
        return Database.getQueryLocator([
            SELECT Id, Is_this_a_STA__c, STA_Start_Date__c, STA_Next_Due_Date__c, STA_End_Date__c, STA_Scheduled_Amount__c,
                   Payment_Frequency__c, STA_Status__c, STA_Shortfall__c
            FROM Opportunity
            WHERE Is_this_a_STA__c = true AND Is_Credit_Contract__c = true
            LIMIT :rowLimit
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Opportunity> scope) {
        Collections_Settings__c cs = Collections_Settings__c.getInstance();
        if (cs != null && cs.Disable_Arrangement_Check__c) {
            return;
        }
        Date earliest = null;
        for (Opportunity o : scope) {
            Date s = o.STA_Start_Date__c != null ? o.STA_Start_Date__c : o.STA_Next_Due_Date__c;
            if (s != null && (earliest == null || s < earliest)) {
                earliest = s;
            }
        }
        Map<Id, List<Payment__c>> paysByOpp = new Map<Id, List<Payment__c>>();
        if (earliest != null) {
            for (Payment__c p : [SELECT Agreement__c, Payment_Date__c, Actual_Amount__c FROM Payment__c
                                 WHERE Agreement__c IN :scope AND Payment_Date__c >= :earliest AND Is_TR4K__c = false]) {
                if (!paysByOpp.containsKey(p.Agreement__c)) {
                    paysByOpp.put(p.Agreement__c, new List<Payment__c>());
                }
                paysByOpp.get(p.Agreement__c).add(p);
            }
        }
        List<Opportunity> updates = new List<Opportunity>();
        for (Opportunity o : scope) {
            List<Payment__c> pays = paysByOpp.containsKey(o.Id) ? paysByOpp.get(o.Id) : new List<Payment__c>();
            ArrangementTracker.Status s = ArrangementTracker.evaluate(o, pays, Date.today());
            if (s == null) {
                continue;
            }
            updates.add(new Opportunity(Id = o.Id, STA_Status__c = s.status, STA_Shortfall__c = s.shortfall, STA_Checked_Date__c = Date.today()));
        }
        for (Database.SaveResult sr : Database.update(updates, false)) {
            if (!sr.isSuccess()) {
                ErrorLog.addErrorLog('ArrangementCheckBatch', 'execute', String.valueOf(sr.getId()), String.valueOf(sr.getErrors()), '');
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
    }
}
