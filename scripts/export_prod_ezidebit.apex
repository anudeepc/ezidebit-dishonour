// READ-ONLY (production): Ezidebit payment rows for the sandbox's active credit contracts, 1 Oct 2025 to today.
// Prints one compact JSON line per contract. No DML. Digital keys are used in the callout only, never printed.
Set<String> refs = new Set<String>{ '30000010216','30000007729','30000013176','32600000888','30000005090','31900000309','30000009759','30000012305','30000012967','30000012130','30400000145','30000012405','71700000974','30000008298','30000012595','30000011682','30000007346','30000000185','30000008199','30000004374','30000010813','30000013185','30000010760','30000009289','32700000241','30000008774','30000010892','30000012615','30000012729','30000007883','30000012836','30000008217','30000008979','30000011329','30000008072','30000012536','30000012924','30000011958','30000007258','60100000037' };
Map<String, String> keyByRef = new Map<String, String>();
for (Opportunity o : [SELECT Contract_No__c, Account.Territory_Number__r.Ezidebit_DigitalKey__c FROM Opportunity WHERE Contract_No__c IN :refs]) {
    keyByRef.put(o.Contract_No__c, o.Account.Territory_Number__r.Ezidebit_DigitalKey__c);
}
String fallbackKey = [SELECT Ezidebit_DigitalKey__c FROM Territory__c WHERE Name = '3000' LIMIT 1].Ezidebit_DigitalKey__c;
EzidebitAPI.BasicHttpBinding_INonPCIService stub = new EzidebitAPI.BasicHttpBinding_INonPCIService();
stub.inputHttpHeaders_x = new Map<String, String>();
stub.endpoint_x = 'https://api.ezidebit.com.au/v3-5/nonpci';
stub.timeout_x = 60000;
String today = Datetime.now().format('yyyy-MM-dd');
for (String ref : refs) {
    String key = keyByRef.get(ref) != null ? keyByRef.get(ref) : fallbackKey;
    List<Map<String, Object>> rows = new List<Map<String, Object>>();
    try {
        EzidebitAPI.EziResponseOfArrayOfPaymentTHgMB7oL r = stub.GetPayments(key, 'ALL', 'ALL', 'ALL', '', '2025-10-01', today, 'SETTLEMENT', '', ref);
        if (r != null && r.Data != null && r.Data.Payment != null) {
            for (EzidebitAPI.Payment p : r.Data.Payment) {
                rows.add(new Map<String, Object>{
                    'id' => p.PaymentID, 'st' => p.PaymentStatus, 'ref' => p.YourSystemReference, 'cid' => p.EzidebitCustomerID,
                    'dd' => p.DebitDate == null ? null : p.DebitDate.format('yyyy-MM-dd'), 'sd' => p.SettlementDate == null ? null : p.SettlementDate.format('yyyy-MM-dd'),
                    'sa' => p.ScheduledAmount, 'pa' => p.PaymentAmount, 'fc' => p.TransactionFeeClient, 'fu' => p.TransactionFeeCustomer,
                    'pm' => p.PaymentMethod, 'ps' => p.PaymentSource, 'rc' => p.BankReturnCode, 'rs' => p.BankFailedReason });
            }
        }
        System.debug('EXPORT ' + JSON.serialize(new Map<String, Object>{ 'ref' => ref, 'rows' => rows }));
    } catch (Exception ex) {
        System.debug('EXPORTERR ' + ref + ' ' + ex.getMessage());
    }
}
