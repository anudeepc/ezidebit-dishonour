// READ-ONLY: Ezidebit FAILED payments per window for the biggest territory, to see errors or caps.
Territory__c ter = [SELECT Ezidebit_DigitalKey__c, Short_Name__c FROM Territory__c WHERE Short_Name__c = 'R4K Services' AND Ezidebit_DigitalKey__c != null LIMIT 1];
EzidebitAPI.BasicHttpBinding_INonPCIService stub = new EzidebitAPI.BasicHttpBinding_INonPCIService();
stub.inputHttpHeaders_x = new Map<String, String>();
stub.endpoint_x = 'https://api.ezidebit.com.au/v3-5/nonpci';
stub.timeout_x = 60000;
List<List<String>> wins = new List<List<String>>{
    new List<String>{ '2025-12-24', '2026-01-06' }, new List<String>{ '2026-01-07', '2026-01-20' }, new List<String>{ '2026-01-21', '2026-02-03' },
    new List<String>{ '2026-05-13', '2026-05-26' }, new List<String>{ '2026-06-10', '2026-06-23' }, new List<String>{ '2026-07-08', '2026-07-21' },
    new List<String>{ '2026-01-07', '2026-01-13' } };
for (List<String> w : wins) {
    try {
        EzidebitAPI.EziResponseOfArrayOfPaymentTHgMB7oL r = stub.GetPayments(ter.Ezidebit_DigitalKey__c, 'FAILED', 'ALL', 'ALL', '', w[0], w[1], 'SETTLEMENT', '', '');
        Integer n = r == null || r.Data == null || r.Data.Payment == null ? -1 : r.Data.Payment.size();
        System.debug('RESULT ' + w[0] + '..' + w[1] + ' rows=' + n + ' error=' + (r == null ? null : r.Error) + ' msg=' + (r == null ? null : r.ErrorMessage) + ' heap=' + Limits.getHeapSize());
    } catch (Exception ex) {
        System.debug('RESULT ' + w[0] + '..' + w[1] + ' EXCEPTION ' + ex.getMessage());
    }
}
