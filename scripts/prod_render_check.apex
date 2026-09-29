// READ-ONLY production check: render the collections page and the Form 11A page and look for the new panel / errors.
List<Collection_Activity__c> cas = [SELECT Id, Agreement__c FROM Collection_Activity__c
    WHERE Agreement__r.Is_Credit_Contract__c = true AND Agreement__c IN (SELECT Opportunity__c FROM Ezidebit_Dishonour__c WHERE Debit_Date__c = LAST_N_DAYS:10)
    ORDER BY CreatedDate DESC LIMIT 1];
PageReference pr = Page.CollectionActivityCreditContractPage;
pr.getParameters().put('id', cas[0].Id);
String html = pr.getContent().toString();
System.debug('RESULT ca=' + cas[0].Id + ' len=' + html.length() + ' strip=' + html.contains('dsh-strip dsh-') + ' lastFailed=' + html.contains('Last failed debit')
    + ' tools=' + html.contains('Agreement statement') + ' timeline=' + html.contains('dshTimeline = JSON.parse') + ' error=' + (html.contains('An error occurred') || html.contains('Visualforce Error') || html.contains('System.')));
PageReference f = Page.AdminProcessForm11A;
f.getParameters().put('ccCAP', 'true');
String h2 = f.getContent().toString();
Integer i = h2.indexOf('Direct Debit Default Notices due');
System.debug('RESULT form11a len=' + h2.length() + ' ' + (i < 0 ? 'NOT FOUND' : h2.substring(i, Math.min(h2.length(), i + 900)).replaceAll('<[^>]+>', ' ').replaceAll('\\s+', ' ')));
