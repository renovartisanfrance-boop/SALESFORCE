public with sharing class AccountTriggerHandler {
    public static void ManageCoordinates(map<Id,Account> accs)
    {
        for(Id key : accs.keySet())
        {
            Account acc = accs.get(key);
            AsyncGetCoordinates(acc.BillingPostalCode, acc.Id);
        }
    }

    @future (callout=true)
    private static void AsyncGetCoordinates(String zipCode, Id accId){
        System.debug('>> zipCode: '+zipCode);
        System.debug('>> oppId: '+accId);
        String apiUrl = 'https://nominatim.openstreetmap.org/search?q='+zipCode+'&format=json&limit=1&countrycodes=FR';
        HttpRequest req = new HttpRequest();
        req.setEndpoint(apiUrl);
        req.setMethod('GET');
        Http http = new Http();
        HttpResponse res = http.send(req);
        if(res.getStatusCode() == 200){
            List<ResultCoordinate> results = (List<ResultCoordinate>) JSON.deserialize(res.getBody(), List<ResultCoordinate>.class);
            System.debug('>> results: '+results);
            if(results.size() > 0){
                System.debug('>> results: '+results[0]?.lat);
                System.debug('>> results: '+results[0]?.lon);
                // get all opps of account id:
                List<Opportunity> opps = [SELECT Id FROM Opportunity WHERE AccountId = :accId];
                for(Opportunity opp : opps){
                    // set field value
                    opp.CoordonneesGPS__c = results[0]?.lat + ',' + results[0]?.lon;
                }
                // update all opps
                System.debug('>> opps to up : '+opps);
                update opps;
            }
        }
    }
         

    public class ResultCoordinate{
        public String lat;
        public String lon;
    }
}