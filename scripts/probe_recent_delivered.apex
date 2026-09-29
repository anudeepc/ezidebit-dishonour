// READ-ONLY: Ezidebit status of agreements moved Pending Order -> Goods Delivered since 10 Sep.
List<Opportunity> opps = [SELECT Contract_No__c, Account.Territory_Number__r.Ezidebit_DigitalKey__c FROM Opportunity WHERE Contract_No__c IN ('30000013020','30000013026','30000013054','30000013056','30000013058','30000013070','30000013071','30000013072','30000013074','30000013079','30000013083','30000013089','30000013093','30000013097','30000013108','30000013109','30000013116','30000013117','30000013119','30000013126','30000013132','30000013135','30000013143','30000013144','30000013153','30000013157','30000013159','30000013192','30000013202','30000013205','30000013225','30000013226','30000013227','30000013232','30000013245','30000013246','30000013265','30000013273','30000013279','30000013283','30000013294','30000013300','30000013310','30000013314','30000013329')];
EzidebitAPI.BasicHttpBinding_INonPCIService s = new EzidebitAPI.BasicHttpBinding_INonPCIService();
s.inputHttpHeaders_x = new Map<String, String>(); s.endpoint_x = 'https://api.ezidebit.com.au/v3-5/nonpci'; s.timeout_x = 20000;
Map<String, Integer> counts = new Map<String, Integer>();
for (Opportunity o : opps) {
    String st = 'no key';
    String k = o.Account.Territory_Number__r.Ezidebit_DigitalKey__c;
    if (k != null) { try { EzidebitAPI.EziResponseOfCustomerDetailsTHgMB7oL r = s.GetCustomerDetails(k, '', o.Contract_No__c); st = r.Data != null ? r.Data.StatusCode + ' ' + r.Data.StatusDescription : 'err ' + r.ErrorMessage; } catch (Exception e) { st = 'exception'; } }
    if (st.startsWith('H')) System.debug('HOLDREF ' + o.Contract_No__c);
    st = st.left(40); counts.put(st, (counts.containsKey(st) ? counts.get(st) : 0) + 1);
}
System.debug('RESULT n=' + opps.size() + ' ' + counts);
