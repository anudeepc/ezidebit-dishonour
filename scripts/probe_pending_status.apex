// READ-ONLY: Ezidebit status of credit contracts currently in Pending Order (goods ordered, not delivered).
List<Opportunity> opps = [SELECT Contract_No__c, Start_Date__c, Ezidebit_Starting_Date__c, Account.Territory_Number__r.Ezidebit_DigitalKey__c
    FROM Opportunity WHERE Is_Credit_Contract__c = true AND StageName = 'Pending Order' AND Contract_No__c != null ORDER BY Start_Date__c DESC LIMIT 60];
System.debug('RESULT pendingTotal=' + [SELECT COUNT() FROM Opportunity WHERE Is_Credit_Contract__c = true AND StageName = 'Pending Order']);
EzidebitAPI.BasicHttpBinding_INonPCIService s = new EzidebitAPI.BasicHttpBinding_INonPCIService();
s.inputHttpHeaders_x = new Map<String, String>(); s.endpoint_x = 'https://api.ezidebit.com.au/v3-5/nonpci'; s.timeout_x = 20000;
Map<String, Integer> counts = new Map<String, Integer>();
Integer futureStart = 0;
for (Opportunity o : opps) {
    String k = o.Account.Territory_Number__r.Ezidebit_DigitalKey__c;
    String st = 'no key';
    if (k != null) {
        try {
            EzidebitAPI.EziResponseOfCustomerDetailsTHgMB7oL r = s.GetCustomerDetails(k, '', o.Contract_No__c);
            st = r.Data != null ? r.Data.StatusCode + ' ' + r.Data.StatusDescription : 'err ' + r.Error + ' ' + r.ErrorMessage;
        } catch (Exception e) { st = 'exception'; }
    }
    if (o.Ezidebit_Starting_Date__c != null && o.Ezidebit_Starting_Date__c > Date.today()) futureStart++;
    counts.put(st.left(40), (counts.containsKey(st.left(40)) ? counts.get(st.left(40)) : 0) + 1);
}
System.debug('RESULT sampled=' + opps.size() + ' ezidebitStartInFuture=' + futureStart + ' statuses=' + counts);
