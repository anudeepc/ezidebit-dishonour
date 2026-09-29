/**
 * One payment history per agreement: every payment (Payment__c) and every failed Ezidebit debit
 * (Ezidebit_Dishonour__c) in date order, with Ezidebit's fee and the R4K dishonour fee on each.
 * Runs with sharing, and strips any field the viewer can't read.
 */
public with sharing class EzidebitPaymentHistoryController {

    @TestVisible static final Integer MAX_ROWS = 500;

    public class Row implements Comparable {
        @AuraEnabled public Id recordId;
        @AuraEnabled public String name;
        @AuraEnabled public Date eventDate;
        @AuraEnabled public String result;      // Paid | Failed | Taken back
        @AuraEnabled public String type;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public Decimal ezidebitFee;
        @AuraEnabled public Decimal r4kFee;
        @AuraEnabled public String detail;

        public Integer compareTo(Object other) {
            Row o = (Row) other;
            if (eventDate == o.eventDate) {
                return result == o.result ? 0 : (result == 'Paid' ? 1 : -1); // a failure sorts above a payment on the same day
            }
            if (eventDate == null) {
                return 1;
            }
            if (o.eventDate == null) {
                return -1;
            }
            return eventDate > o.eventDate ? -1 : 1; // newest first
        }
    }

    public class History {
        @AuraEnabled public List<Row> rows = new List<Row>();
        @AuraEnabled public Integer paidCount = 0;
        @AuraEnabled public Decimal paidAmount = 0;
        @AuraEnabled public Integer failedCount = 0;
        @AuraEnabled public Integer openInstalments = 0;
        @AuraEnabled public Decimal ezidebitFees = 0;
        @AuraEnabled public Decimal r4kFees = 0;
        @AuraEnabled public Boolean truncated = false;
    }

    @AuraEnabled(cacheable=true)
    public static History getHistory(Id opportunityId) {
        History h = new History();
        if (opportunityId == null) {
            return h;
        }
        List<Payment__c> payments = (List<Payment__c>) Security.stripInaccessible(AccessType.READABLE, [
            SELECT Id, Name, Payment_Date__c, Actual_Amount__c, Client_Fees__c, Debit_Type__c, Payment_Type__c,
                   Late_Returned__c, Late_Returned_Date__c, RecordType.Name
            FROM Payment__c
            WHERE Agreement__c = :opportunityId
            ORDER BY Payment_Date__c DESC
            LIMIT 500
        ]).getRecords();
        for (Payment__c p : payments) {
            Row r = new Row();
            r.recordId = p.Id;
            r.name = p.Name;
            r.eventDate = p.Payment_Date__c;
            Boolean takenBack = p.isSet('Late_Returned__c') && p.Late_Returned__c;
            r.result = takenBack ? 'Taken back' : 'Paid';
            r.type = p.isSet('Debit_Type__c') && p.Debit_Type__c != null ? p.Debit_Type__c : (p.RecordType != null ? p.RecordType.Name : null);
            r.amount = p.Actual_Amount__c;
            r.ezidebitFee = p.Client_Fees__c;
            r.detail = takenBack
                ? 'Bank took it back' + (p.isSet('Late_Returned_Date__c') && p.Late_Returned_Date__c != null ? ' on ' + p.Late_Returned_Date__c.format() : '')
                : null;
            h.rows.add(r);
            if (!takenBack) {
                h.paidCount++;
                h.paidAmount += p.Actual_Amount__c == null ? 0 : p.Actual_Amount__c;
            }
            h.ezidebitFees += p.Client_Fees__c == null ? 0 : p.Client_Fees__c;
        }
        if (!Schema.sObjectType.Ezidebit_Dishonour__c.isAccessible()) {
            h.rows.sort();
            return h; // viewer has no Dishonour access (Ezidebit Dishonour Access permission set)
        }
        List<Ezidebit_Dishonour__c> dishonours = (List<Ezidebit_Dishonour__c>) Security.stripInaccessible(AccessType.READABLE, [
            SELECT Id, Name, Debit_Date__c, Payment_Amount__c, Ezidebit_Fee__c, Dishonour_Fee_Charged__c, Type__c,
                   Outcome__c, Bank_Failed_Reason__c, Original_Dishonour__r.Name
            FROM Ezidebit_Dishonour__c
            WHERE Opportunity__c = :opportunityId
            ORDER BY Debit_Date__c DESC
            LIMIT 500
        ]).getRecords();
        for (Ezidebit_Dishonour__c d : dishonours) {
            Row r = new Row();
            r.recordId = d.Id;
            r.name = d.Name;
            r.eventDate = (Date) value(d, 'Debit_Date__c');
            r.result = 'Failed';
            r.type = (String) value(d, 'Type__c');
            r.amount = (Decimal) value(d, 'Payment_Amount__c');
            r.ezidebitFee = (Decimal) value(d, 'Ezidebit_Fee__c');
            r.r4kFee = (Decimal) value(d, 'Dishonour_Fee_Charged__c');
            String reason = (String) value(d, 'Bank_Failed_Reason__c');
            String outcome = (String) value(d, 'Outcome__c');
            List<String> parts = new List<String>();
            if (reason != null) {
                parts.add(reason);
            }
            if (outcome != null) {
                parts.add(outcome);
            }
            String original = originalName(d);
            if (original != null) {
                parts.add('Retry of ' + original);
            }
            r.detail = String.join(parts, ' · ');
            h.rows.add(r);
            h.failedCount++;
            if (outcome == EzidebitDishonourService.OUTCOME_OPEN) {
                h.openInstalments++;
            }
            h.ezidebitFees += r.ezidebitFee == null ? 0 : r.ezidebitFee;
            h.r4kFees += r.r4kFee == null ? 0 : r.r4kFee;
        }
        h.truncated = h.rows.size() >= MAX_ROWS;
        h.rows.sort();
        return h;
    }

    // A field the viewer can't read was stripped: treat it as blank instead of failing.
    private static Object value(SObject record, String field) {
        return record.isSet(field) ? record.get(field) : null;
    }

    private static String originalName(Ezidebit_Dishonour__c d) {
        try {
            return d.Original_Dishonour__r == null ? null : d.Original_Dishonour__r.Name;
        } catch (SObjectException stripped) {
            return null;
        }
    }
}