trigger HardshipRequestTrigger on Hardship_Request__c (before insert, before update, after insert, after update) {
    if (Trigger.isBefore) {
        HardshipRequestService.fillCustomer(Trigger.new);
    } else {
        HardshipRequestService.syncAccountsSafely(Trigger.new);
    }
}
