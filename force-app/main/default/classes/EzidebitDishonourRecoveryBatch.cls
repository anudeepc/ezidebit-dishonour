/**
 * After a history load: closes open missed instalments that a later payment already in Salesforce
 * recovered (matched by agreement, amount and 1-11 days after the debit). See
 * EzidebitDishonourService.recoverFromPayments.
 */
public without sharing class EzidebitDishonourRecoveryBatch implements Database.Batchable<SObject> {

    private final Boolean includeLive;

    /** History records only. */
    public EzidebitDishonourRecoveryBatch() {
        this(false);
    }

    /** includeLive: also live records (after go-live, when the recoveries arrived before the failures did). */
    public EzidebitDishonourRecoveryBatch(Boolean includeLive) {
        this.includeLive = includeLive == true;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        Set<Boolean> backfillValues = includeLive ? new Set<Boolean>{ true, false } : new Set<Boolean>{ true };
        return Database.getQueryLocator([
            SELECT Id, Opportunity__c, Debit_Date__c, Payment_Amount__c
            FROM Ezidebit_Dishonour__c
            WHERE Is_Backfill__c IN :backfillValues
              AND Type__c = :EzidebitDishonourService.TYPE_INSTALMENT
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