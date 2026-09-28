/**
 * After a history load: closes open missed instalments that a later payment already in Salesforce
 * recovered (matched by agreement, amount and 1-11 days after the debit). See
 * EzidebitDishonourService.recoverFromPayments.
 */
public without sharing class EzidebitDishonourRecoveryBatch implements Database.Batchable<SObject> {

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Opportunity__c, Debit_Date__c, Payment_Amount__c
            FROM Ezidebit_Dishonour__c
            WHERE Is_Backfill__c = true AND Type__c = :EzidebitDishonourService.TYPE_INSTALMENT
              AND Outcome__c = :EzidebitDishonourService.OUTCOME_OPEN AND Opportunity__c != null
            ORDER BY Opportunity__c, Debit_Date__c
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Ezidebit_Dishonour__c> scope) {
        EzidebitDishonourService.recoverFromPayments(scope);
    }

    public void finish(Database.BatchableContext bc) {
    }
}