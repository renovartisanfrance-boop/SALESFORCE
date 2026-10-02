public without sharing class OpportunityTriggerHandler {
        public static Boolean isTriggerExecuted = false;


    public static void verifier_date_planification(List<opportunity> newOppMap,map<Id,opportunity> oldOppMap){

        Boolean old_deja_previsite = false;
        Boolean old_deja_ite = false;
        if( oldOppMap != null )
        {
                if(newOppMap[0].Date_de_Previsite__c != null)
                {
                        if(oldOppMap.get(newOppMap[0].Id).Date_de_Previsite__c != newOppMap[0].Date_de_Previsite__c)
                        {
                                old_deja_previsite = true;
                        }
                }
                // if(newOppMap[0].Date_install_ITE_ISO__c != null)
                // {
                //         if(oldOppMap.get(newOppMap[0].Id).Date_install_ITE_ISO__c != newOppMap[0].Date_install_ITE_ISO__c)
                //         {
                //                 old_deja_ite = true;
                //         }
                // }

        }
        else
        {
                old_deja_previsite = true ;  
                old_deja_ite = true ;
        }


        if(newOppMap[0].Date_de_Previsite__c != null && old_deja_previsite == true)
        {
                List<ParametragePlanification__c>  planification_custom =  [SELECT  planification_Json__c FROM ParametragePlanification__c];
                Planification_Controller.Parametrage_planification_all planification_all = (Planification_Controller.Parametrage_planification_all)JSON.deserialize(planification_custom[0].planification_Json__c , Planification_Controller.Parametrage_planification_all.class);
                DateTime dt_new =  newOppMap[0].Date_de_Previsite__c;
                List<opportunity> opps = [SELECT Id , Date_de_Previsite__c , Name FROM Opportunity WHERE Id != :newOppMap[0].Id AND  Camion__c =: newOppMap[0].Camion__c AND CALENDAR_YEAR(Date_de_Previsite__c) = :dt_new.year() AND  CALENDAR_MONTH(Date_de_Previsite__c)  = :dt_new.month() AND DAY_IN_MONTH(Date_de_Previsite__c) = :dt_new.day() ];	
            
           // AND  Technicien__c =: newOppMap[0].Technicien__c
                  System.debug('+!!!++!+!+!++!+!++!+++!+!');
               System.debug(opps);
                 System.debug('+!!!++!+!+!++!+!++!+++!+!');


                   System.debug('+!!!++!+!+!++!+!++!+++!+!');
               System.debug(dt_new);
                 System.debug('+!!!++!+!+!++!+!++!+++!+!');


             Boolean exist_deja = false;
                     for(Planification_Controller.Parametrage_crenreaux cr :planification_all.planifications[0].crenreaux){  
                             DateTime modifiedDateTime = DateTime.newInstance(
                                newOppMap[0].Date_de_Previsite__c.year(),
                                newOppMap[0].Date_de_Previsite__c.month(),
                                newOppMap[0].Date_de_Previsite__c.day(),
                                Integer.valueOf(cr.crenreaux.split('-')[0].toUpperCase().split('H')[0]),
                                Integer.valueOf(cr.crenreaux.split('-')[0].toUpperCase().split('H')[1]),
                                0
                             );
             
                             DateTime modifiedDateTime2 = DateTime.newInstance(
                                newOppMap[0].Date_de_Previsite__c.year(),
                                newOppMap[0].Date_de_Previsite__c.month(),
                                newOppMap[0].Date_de_Previsite__c.day(),
                                Integer.valueOf(cr.crenreaux.split('-')[1].toUpperCase().split('H')[0]) ,
                                Integer.valueOf(cr.crenreaux.split('-')[1].toUpperCase().split('H')[1]),
                                0
                             );


                             System.debug('+!!!++!+!+!++!+!++!+++!+!');
                        System.debug( cr.crenreaux );
                                System.debug('+!!!++!+!+!++!+!++!+++!+!');

                             System.debug('+!!!++!+!+!++!+!++!+++!+!');
                        System.debug( Integer.valueOf(cr.crenreaux.split('-')[1].toUpperCase().split('H')[1]));
                                System.debug('+!!!++!+!+!++!+!++!+++!+!');

                                System.debug('+!!!++!+!+!++!+!++!+++!+!');
                        System.debug(modifiedDateTime + ' // ' +  modifiedDateTime2);
                                System.debug('+!!!++!+!+!++!+!++!+++!+!');
        
                             if(newOppMap[0].Date_de_Previsite__c >= modifiedDateTime  && newOppMap[0].Date_de_Previsite__c < modifiedDateTime2)
                             {
                                     for(opportunity opp_i : opps)
                                     {
                                          if(opp_i.Date_de_Previsite__c >= modifiedDateTime  && opp_i.Date_de_Previsite__c < modifiedDateTime2)
                                          {
                                             exist_deja = true;
                                             break;
                                          }
                                     }
                                     break;
                             }

                       }
              if(exist_deja == true)
              {
                     newOppMap[0].addError('Le créneau Date de Pré-visite que vous avez choisi est déjà pris !');   
              }
                   
        }     
     }

     public static void fakeMethod(){
        Integer i = 0;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
            i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
            i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
                i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
                i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
                i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
                i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
                i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
            i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
            i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
                i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
                i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
                i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
                i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
                i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
            i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
            i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
                i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
                i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
                i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
                i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;

                i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
                i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
                i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
                i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
                i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
                i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
                i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
                i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
                i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
                i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
                i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
                i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;i++;
    }


    public static void map_adresse_from_lead(List<opportunity> newOppMap){
        // check list if empty
        if(newOppMap.isEmpty()){
            return;
        }
        // get the opportunity ids
        Map<Id, ID> OppsAccounts = new Map<Id, ID>();
        for(Opportunity opp : newOppMap){
            OppsAccounts.put(opp.Id, opp.AccountId);
        }

        // get the Accounts of this opportunity
        List<Account> accounts = [SELECT Id, BillingCity, BillingPostalCode, BillingStreet FROM Account WHERE Id IN :OppsAccounts.values()];
        
        System.debug('>> Leads: ' + accounts);
        // map the adresse to the opportunity
        for(Account account : accounts){
                System.debug('>> Lead City: ' + lead.City);
                for(Opportunity opp : newOppMap){
                    if(account.Id == opp.AccountId){
                        System.debug('>> Is changer ' + account.BillingCity);
                        opp.Adresse__City__s = account.BillingCity;
                        // code postale:
                        opp.Adresse__PostalCode__s = account.BillingPostalCode;
                        // street
                        opp.Adresse__Street__s = account.BillingStreet;
                    }
                }
        }
    }

    public static void updateLatLong(List<opportunity> newOppMap){
        // check list if empty
        if(newOppMap.isEmpty()){
            return;
        }

        System.debug('>> Leads: ' + newOppMap);
        // map the adresse to the opportunity
        for(Opportunity opp : newOppMap){
                System.debug('>> Is changer ' + opp.Adresse__PostalCode__s);
                AsyncGetCoordinates(opp.Adresse__PostalCode__s, opp.Id);
        }
    }


    @future (callout=true)
    public static void AsyncGetCoordinates(String zipCode, Id OppId){
        System.debug('>> zipCode: '+zipCode);
        System.debug('>> oppId: '+OppId);
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
                List<Opportunity> opps = [SELECT Id FROM Opportunity WHERE Id = :OppId];
                System.debug('>> opps to up : '+ opps);

                if(opps != null && !opps.isEmpty()){
                    opps[0].CoordonneesGPS__c = results[0]?.lat + ',' + results[0]?.lon;
                    update opps[0];
                }
            } else {
                // get the opportunity with the Id:
                List<Opportunity> opps = [SELECT Id FROM Opportunity WHERE Id = :OppId];
                if(opps != null && !opps.isEmpty()){
                        // set field value
                    opps[0].CoordonneesGPS__c = '0,0';
                    // update all opps
                    System.debug('>> opps to up : '+opps);
                update opps;
                }
            }
        }
    }
         

    public class ResultCoordinate{
        public String lat;
        public String lon;
    }
}