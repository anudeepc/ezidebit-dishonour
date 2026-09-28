/**
 * After a history load: links the $16.50 dishonour fees already charged (Fee__c, Late Payment) on
 * active agreements to the missed instalment each one followed. Oldest fees first. See
 * EzidebitDishonourService.linkFees.
 */
public without sharing class EzidebitFeeLinkBackfillBatch implements Database.Batchable<SObject> {

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Agreement__c, Fee_Type__c, Fee_Amount__c, Fee_Charged_Date__c, Ezidebit_Dishonour__c
            FROM Fee__c
            WHERE Fee_Type__c = :EzidebitDishonourService.FEE_TYPE_DISHONOUR AND Ezidebit_Dishonour__c = null
              AND Agreement__r.Is_Active__c = true
            ORDER BY Fee_Charged_Date__c ASC
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Fee__c> scope) {
        EzidebitDishonourService.linkFees(scope);
    }

    public void finish(Database.BatchableContext bc) {
    }
}