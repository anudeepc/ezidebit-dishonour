/**
 * One-off repair: relinks retries that were recorded as missed instalments because they reached
 * Salesforce before their original failure (go-live on 29 Sep 2026). Oldest first, so each original
 * claims its own retry. See EzidebitDishonourService.relinkLaterRetries.
 *
 *   Database.executeBatch(new EzidebitDishonourRelinkBatch(), 200);
 */
public without sharing class EzidebitDishonourRelinkBatch implements Database.Batchable<SObject>, Database.Stateful {

    @TestVisible Integer relinked = 0;

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id FROM Ezidebit_Dishonour__c
            WHERE Type__c = :EzidebitDishonourService.TYPE_INSTALMENT AND Contract_Reference__c != null
            ORDER BY Debit_Date__c ASC, Name ASC
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Ezidebit_Dishonour__c> scope) {
        relinked += EzidebitDishonourService.relinkLaterRetries(scope);
    }

    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.INFO, 'EzidebitDishonourRelinkBatch relinked ' + relinked + ' retries');
    }
}
