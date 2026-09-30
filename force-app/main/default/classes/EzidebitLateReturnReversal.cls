/**
 * Reverses Ezidebit payments that Salesforce recorded as paid but the customer never paid:
 *   - a late return: Ezidebit settled the debit, then the bank took it back days later;
 *   - a duplicate copy: the same settled payment imported twice.
 *
 * It does what staff do by hand today: a negative Cash payment (in its own Cash payment file, no agreement,
 * so the payment trigger allocates nothing) with negative allocations mirroring the original payment's
 * allocations. The instalments' Paid_Amount__c roll-ups drop by the same amounts, so the balance, arrears,
 * interest and payout figures all follow. The original is linked through Reversed_By__c, so a payment is
 * never reversed twice.
 *
 * reverse(..., false) is a dry run: it returns what it would do and changes nothing.
 */
public without sharing class EzidebitLateReturnReversal {

    public static final String REASON_LATE_RETURN = 'Late return';
    public static final String REASON_DUPLICATE = 'Duplicate copy';

    public class Row {
        public Id paymentId;
        public String paymentName;
        public Id agreementId;
        public Date paymentDate;
        public Decimal paymentAmount;
        public Decimal allocatedAmount;   // what is reversed: the sum of the payment's allocations
        public Date reversalDate;
        public String reason;
        public String outcome;            // Reversed | Would reverse | Already reversed | Nothing allocated | Error: ...
        public Id reversalPaymentId;
    }

    public class Request {
        public Id paymentId;
        public Date reversalDate;
        public String reason;
        public String note;
        public Request(Id paymentId, Date reversalDate, String reason, String note) {
            this.paymentId = paymentId;
            this.reversalDate = reversalDate;
            this.reason = reason;
            this.note = note;
        }
    }

    public static List<Row> reverse(List<Request> requests, Boolean commitChanges) {
        List<Row> rows = new List<Row>();
        if (requests == null || requests.isEmpty()) {
            return rows;
        }
        Map<Id, Request> byPayment = new Map<Id, Request>();
        for (Request r : requests) {
            if (r != null && r.paymentId != null && !byPayment.containsKey(r.paymentId)) {
                byPayment.put(r.paymentId, r);
            }
        }
        Map<Id, Payment__c> payments = new Map<Id, Payment__c>([
            SELECT Id, Name, Agreement__c, ApplicantLookup__c, Payment_Date__c, Total_Paid__c, Actual_Amount__c,
                   Ezidebit_Payment_ID__c, Reversed_By__c, CurrencyIsoCode,
                   (SELECT Id, Scheduled_Payment__c, Contract__c, Actual_Amount__c FROM Payment_Allocation__r WHERE Actual_Amount__c > 0)
            FROM Payment__c WHERE Id IN :byPayment.keySet()
        ]);

        List<Payment__c> toReverse = new List<Payment__c>();
        Map<Id, Row> rowByPayment = new Map<Id, Row>();
        for (Id pid : byPayment.keySet()) {
            Request req = byPayment.get(pid);
            Payment__c p = payments.get(pid);
            Row row = new Row();
            row.paymentId = pid;
            row.reason = req.reason;
            row.reversalDate = req.reversalDate != null ? req.reversalDate : Date.today();
            rows.add(row);
            if (p == null) {
                row.outcome = 'Error: payment not found';
                continue;
            }
            row.paymentName = p.Name;
            row.agreementId = p.Agreement__c;
            row.paymentDate = p.Payment_Date__c;
            row.paymentAmount = p.Total_Paid__c;
            row.allocatedAmount = 0;
            for (Payment_Allocation__c a : p.Payment_Allocation__r) {
                row.allocatedAmount += a.Actual_Amount__c;
            }
            if (p.Reversed_By__c != null) {
                row.outcome = 'Already reversed';
                row.reversalPaymentId = p.Reversed_By__c;
            } else if (row.allocatedAmount <= 0) {
                row.outcome = 'Nothing allocated';
            } else {
                row.outcome = commitChanges ? 'Reversed' : 'Would reverse';
                toReverse.add(p);
                rowByPayment.put(pid, row);
            }
        }
        if (!commitChanges || toReverse.isEmpty()) {
            return rows;
        }

        Savepoint sp = Database.setSavepoint();
        try {
            Payment_File__c file = new Payment_File__c(
                RecordTypeId = Schema.SObjectType.Payment_File__c.getRecordTypeInfosByDeveloperName().get('Cash').getRecordTypeId(),
                File_Name__c = 'Ezidebit reversals (late returns and duplicates) ' + System.now().format('yyyy-MM-dd HH:mm'),
                File_Upload_Date__c = System.now()
            );
            insert file;

            Map<Id, Payment__c> reversalByOriginal = new Map<Id, Payment__c>();
            for (Payment__c p : toReverse) {
                Row row = rowByPayment.get(p.Id);
                Request req = byPayment.get(p.Id);
                Payment__c rev = new Payment__c(
                    RecordTypeId = PaymentUtil.RECORDTYPE_ID_CASH,
                    Payment_File__c = file.Id,
                    ApplicantLookup__c = p.ApplicantLookup__c,
                    Payment_Date__c = row.reversalDate,
                    Actual_Amount__c = -row.allocatedAmount,
                    Fee_Amount__c = 0,
                    Is_Credit_Contract__c = false, // keeps the payment trigger from allocating it
                    Notes__c = (req.reason + ': reverses ' + p.Name
                        + (String.isBlank(p.Ezidebit_Payment_ID__c) ? '' : ' (Ezidebit ' + p.Ezidebit_Payment_ID__c + ')')
                        + (String.isBlank(req.note) ? '' : '. ' + req.note)).left(255)
                );
                if (p.CurrencyIsoCode != null) {
                    rev.put('CurrencyIsoCode', p.CurrencyIsoCode);
                }
                reversalByOriginal.put(p.Id, rev);
            }
            insert reversalByOriginal.values();

            List<Payment_Allocation__c> allocations = new List<Payment_Allocation__c>();
            List<Payment__c> originals = new List<Payment__c>();
            for (Payment__c p : toReverse) {
                Payment__c rev = reversalByOriginal.get(p.Id);
                Row row = rowByPayment.get(p.Id);
                for (Payment_Allocation__c a : p.Payment_Allocation__r) {
                    allocations.add(new Payment_Allocation__c(
                        Payment__c = rev.Id,
                        Scheduled_Payment__c = a.Scheduled_Payment__c,
                        Contract__c = a.Contract__c,
                        Payment_Date__c = row.reversalDate,
                        Actual_Amount__c = -a.Actual_Amount__c
                    ));
                }
                Payment__c original = new Payment__c(Id = p.Id, Reversed_By__c = rev.Id);
                if (byPayment.get(p.Id).reason == REASON_LATE_RETURN) {
                    original.Late_Returned__c = true;
                    original.Late_Returned_Date__c = row.reversalDate;
                }
                originals.add(original);
                row.reversalPaymentId = rev.Id;
            }
            insert allocations;
            update originals;
        } catch (Exception e) {
            Database.rollback(sp);
            for (Row row : rowByPayment.values()) {
                row.outcome = 'Error: ' + e.getMessage();
                row.reversalPaymentId = null;
            }
            ErrorLog.addErrorLog('EzidebitLateReturnReversal', 'reverse', String.valueOf(toReverse.size()) + ' payments',
                String.valueOf(e), String.valueOf(e.getLineNumber()));
        }
        return rows;
    }

    /** One CSV line per row, for the dry-run list Finance signs off. */
    public static String toCsv(List<Row> rows) {
        List<String> lines = new List<String>{ 'Payment,Agreement,Payment date,Payment amount,Allocated (reversed),Reversal date,Reason,Outcome,Reversal payment' };
        for (Row r : rows) {
            lines.add(String.join(new List<String>{
                r.paymentName == null ? String.valueOf(r.paymentId) : r.paymentName, String.valueOf(r.agreementId),
                String.valueOf(r.paymentDate), String.valueOf(r.paymentAmount), String.valueOf(r.allocatedAmount),
                String.valueOf(r.reversalDate), r.reason, '"' + (r.outcome == null ? '' : r.outcome.replace('"', '\'')) + '"',
                r.reversalPaymentId == null ? '' : String.valueOf(r.reversalPaymentId)
            }, ','));
        }
        return String.join(lines, '\n');
    }
}
