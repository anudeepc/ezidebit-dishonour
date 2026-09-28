/**
 * When staff charge a dishonour fee (Fee__c, type Late Payment) from the CAP console, link it to
 * the missed instalment it was charged for. See EzidebitDishonourService.linkFees, which never
 * throws, so charging the fee is never blocked.
 */
trigger FeeDishonourLink on Fee__c (after insert) {
    EzidebitDishonourService.linkFeesSafely(Trigger.new);
}