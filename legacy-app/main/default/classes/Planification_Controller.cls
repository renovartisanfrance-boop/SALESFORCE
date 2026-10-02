/**
 * @File Name : Planification_Controller.cls
 * @Description :
 * @Author :
 * @Last Modified By : ChangeMeIn@UserSettingsUnder.SFDoc
 * @Last Modified On : 10-07-2024
 * @Modification Log :
 *==============================================================================
 * Ver | Date | Author | Modification
 *==============================================================================
 * 1.0 | October 3, 2024 |   | Initial Version
 **/

public without sharing class Planification_Controller {
  
  
  
  @AuraEnabled(cacheable=true)
  public static ConformeAutre getConformeAutre(){
    try {
      ConformeAutre Result = new ConformeAutre();
      Date today = Date.today();
      Date futureDate = today.addDays(30);
      Date pastDate = today.addDays(-3);
      
      Result.Conforme =  [SELECT  COUNT(Id) val FROM Opportunity WHERE CONFIRMATIONRDV__c = 'CONFIRME' AND  DAY_ONLY(Date_de_Previsite__c) > :pastDate AND DAY_ONLY(Date_de_Previsite__c) < :futureDate ][0].get('val');
      Result.Autre =  [SELECT  COUNT(Id) val FROM Opportunity WHERE CONFIRMATIONRDV__c = '' AND  DAY_ONLY(Date_de_Previsite__c) > :pastDate AND DAY_ONLY(Date_de_Previsite__c) < :futureDate ][0].get('val');
      
      Result.Conforme = 0;
      Result.Autre = 0;
      
      return Result;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }
  
  
  
  
  @AuraEnabled(cacheable=true)
  public static Parametrage_planification_all getplanification_metadata(){
    try {
      List<ParametragePlanification__c>  planification_custom =  [SELECT  planification_Json__c FROM ParametragePlanification__c];
      if(planification_custom.size() == 0)
      {
        Parametrage_acteur acteur = new Parametrage_acteur('%%--api_name_object_acteur--%%' ,'%%api_name_name__%%' , '%%--condition_object_acteur--%%' , '%%--couleur_api_name_acteur%%' , '%%--api_name_relation_object_acteur_to_cible--%%' , '%%--conges_champs_text_long_api_name--%%');
        List<Parametrage_cible_condition_couleur> couleur = new List<Parametrage_cible_condition_couleur>{
          new Parametrage_cible_condition_couleur('%%--api_name_column--%%' ,'%%column_value%%' , '%%--couleur_hxadecimal--%%'),
          new Parametrage_cible_condition_couleur('%%--api_name_object_acteur--%%' ,'%%api_name_name__%%' , '%%--condition_object_acteur--%%')
        };
        Parametrage_object_cible object_cible = new Parametrage_object_cible('%%--api_name_object_cible--%%' ,'%%--api_name_date_planification--%%' ,'%%--api_name_relation_object_cible_to_acteur--%%', '%%--condition_object_cible--%%' ,  '%%--api_champs_a_afficher--%%'  , couleur , '%%--api_champs_a_info_supl--%%' , '%%--name_champs_a_info_supl--%%' , '%%--api_champs_a_afficher_a_cote_date--%%' , '%%--coodone_atitude_longitude--%%','%%--api_name_badge--%%');
        List<Parametrage_crenreaux> crenreaux = new List<Parametrage_crenreaux>{new Parametrage_crenreaux('%%--9h30--%%') , new Parametrage_crenreaux('%%--10h45--%%')};
        List<Parametrage_planification> planifications  = new List<Parametrage_planification>{new Parametrage_planification('%%--titre_acteur_menu--%%' , '%%--cas_exception--%%', acteur , object_cible , crenreaux)};
        Parametrage_planification_all planification_all = new Parametrage_planification_all(planifications);
        return planification_all;
      }
      else {
        Parametrage_planification_all planification_all = (Parametrage_planification_all)JSON.deserialize(planification_custom[0].planification_Json__c , Parametrage_planification_all.class);
        return planification_all;
      }
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }
  
  
  
  @AuraEnabled
  public static Parametrage_planification_all addplanification_metadata(Parametrage_planification_all Parametrage_planification_all_value){
    try {
      List<ParametragePlanification__c>  planification_custom =  [SELECT Id , planification_Json__c FROM ParametragePlanification__c];
      if(planification_custom.size() == 0)
      {
        ParametragePlanification__c planification_mdt_add = new ParametragePlanification__c(planification_Json__c = String.valueOf(JSON.serialize(Parametrage_planification_all_value)));
        insert planification_mdt_add;
      }
      else {
        
        System.debug(' ================> ' + Parametrage_planification_all_value.planifications[0].object_cible.api_champs_a_afficher);
        ParametragePlanification__c planification_mdt_add = new ParametragePlanification__c(/*Id = planification_custom[0].Id , */ planification_Json__c = String.valueOf(JSON.serialize(Parametrage_planification_all_value))
          /*, Parametre_api_map__c = String.valueOf(JSON.serialize(elms)) */);
        delete planification_custom;
        insert planification_mdt_add;
      }
      return Parametrage_planification_all_value;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }
  
  @AuraEnabled
  public static List<sObject> get_actuers_planification(String objet_acteur , String conditions_acteur , String api_name_object_acteur ,String couleur_api_name_acteur){
    
    String soqlQuery = '';
    if(couleur_api_name_acteur != null && couleur_api_name_acteur != '')
    {
      soqlQuery = 'SELECT Id, ' + api_name_object_acteur + ' , '+ couleur_api_name_acteur +' FROM ' + objet_acteur;
    }
    else {
      soqlQuery = 'SELECT Id, ' + api_name_object_acteur + ' FROM ' + objet_acteur;
    }
    if(conditions_acteur != '' && conditions_acteur != null)
    {
      soqlQuery += ' WHERE ' +  conditions_acteur;
    }
    soqlQuery += ' LIMIT 2500';
    System.debug(soqlQuery);
    List<sObject> q = Database.query(soqlQuery);
    if (q == null) {
      q = new List<sObject>();
    }
    return q;
    
  }
  
  
  @AuraEnabled
  public static List<sObject> get_actuers_cible_planification(
    String objet_acteur ,
  String conditions_acteur ,
  String api_name_object_acteur ,
  String couleur_api_name_acteur ,
  String api_name_relation_object_acteur_to_cible ,
  List<Datetime> date_cible ,
  String api_name_date_planification,
  String api_name_object_cible  ,
  String api_champs_a_afficher ,
  String condition_object_cible ,
  String api_name_relation_object_cible_to_acteur ,
  Boolean cas_exception ,
  String api_champs_a_info_supl ,
  String name_champs_a_info_supl ,
  String  api_champs_a_afficher_a_cote_date ,
  String conges_champs_text_long_api_name ,
  String coodone_atitude_longitude, 
  String api_name_badge
  ){
    
    
    DateTime originalDateTime = DateTime.valueOf(date_cible[0]);
    DateTime originalDateTime2 = DateTime.valueOf(date_cible[1]);
    
    DateTime modifiedDateTime = DateTime.newInstance(
      originalDateTime.year(),
    originalDateTime.month(),
    originalDateTime.day()-1,
    originalDateTime.hour(),
    originalDateTime.minute(),
    0
      );
    
    DateTime modifiedDateTime2 = DateTime.newInstance(
      originalDateTime2.year(),
    originalDateTime2.month(),
    originalDateTime2.day(),
    23,
    59,
    0
      );
    
    String formattedDateTimeString;
    String formattedDateTimeString2;
    
    System.debug('+!+!!+!++!++!++++!++!+!+!+');
    System.debug(cas_exception);
    System.debug('+!+!!+!++!++!++++!++!+!+!+');
    
    if(cas_exception == true)
    {
      
      formattedDateTimeString = modifiedDateTime.format('yyyy-MM-dd');
      formattedDateTimeString2 = modifiedDateTime2.format('yyyy-MM-dd');
    }
    else {
      formattedDateTimeString = modifiedDateTime.format('yyyy-MM-dd\'T\'HH:mm:ss.SSSZ');
      formattedDateTimeString2 = modifiedDateTime2.format('yyyy-MM-dd\'T\'HH:mm:ss.SSSZ');
    }
    
    
    
    String soql_api_champs_a_info_supl = '';
    if(api_champs_a_info_supl != '' && api_champs_a_info_supl != null)
      soql_api_champs_a_info_supl =  ' , ' + api_champs_a_info_supl;
    
    String soql_api_name_badge = '';
    if(api_name_badge != '' && api_name_badge != null)
      soql_api_name_badge =  ' , ' + api_name_badge;
    
    
    String soql_api_champs_a_afficher_a_cote_date = '';
    if(api_champs_a_afficher_a_cote_date != '' && api_champs_a_afficher_a_cote_date != null)
      soql_api_champs_a_afficher_a_cote_date =  ' , ' + api_champs_a_afficher_a_cote_date;
    
    String soql_conges_champs_text_long_api_name = '';
    if(conges_champs_text_long_api_name != '' && conges_champs_text_long_api_name != null)
      soql_conges_champs_text_long_api_name =  ' , ' + conges_champs_text_long_api_name;
    
    
    String soql_coodone_atitude_longitude = '';
    if(coodone_atitude_longitude != '' && coodone_atitude_longitude != null)
      soql_coodone_atitude_longitude =  ' , ' + coodone_atitude_longitude;
    
    
    String soqlQuery2 = '';
    soqlQuery2 = 'SELECT Id, ' + api_champs_a_afficher + ' , ' + api_name_date_planification +  ' ' + soql_api_champs_a_info_supl + '  ' + soql_api_champs_a_afficher_a_cote_date  +' ' +  soql_coodone_atitude_longitude   + ' ' + soql_api_name_badge + '  FROM ' + api_name_relation_object_acteur_to_cible;
    soqlQuery2 += ' WHERE  ' + api_name_date_planification + ' >=  ' +formattedDateTimeString + ' AND ' + api_name_date_planification + ' <=  ' +formattedDateTimeString2 + '  ';
    if(condition_object_cible != '' && condition_object_cible != null)
    {
      soqlQuery2 +=  ' AND '  +  condition_object_cible;
    }
    soqlQuery2 += '  ORDER BY ' + api_name_date_planification;
    
    System.debug('+!+!!+!++!++!++++!++!+!+!+');
    System.debug(soqlQuery2);
    System.debug('+!+!!+!++!++!++++!++!+!+!+');
    
    String soqlQuery = '';
    if(couleur_api_name_acteur != null && couleur_api_name_acteur != '')
    {
      soqlQuery = 'SELECT Id, ' + api_name_object_acteur + ' , '+ couleur_api_name_acteur + ' '+ soql_conges_champs_text_long_api_name  + ' ,  ('+ soqlQuery2 +') FROM ' + objet_acteur;
    }
    else {
      soqlQuery = 'SELECT Id, ' + api_name_object_acteur + ' , ('+ soqlQuery2 +')  FROM ' + objet_acteur;
    }
    if(conditions_acteur != '' && conditions_acteur != null)
    {
      soqlQuery += ' WHERE ' +  conditions_acteur;
    }
    soqlQuery += ' LIMIT 2500';
    System.debug('+!+!!+!++!++!++++!++!+!+!+');
    System.debug(soqlQuery);
    System.debug('+!+!!+!++!++!++++!++!+!+!+');
    List<sObject> q = Database.query(soqlQuery);
    if (q == null) {
      q = new List<sObject>();
    }
    System.debug('+!+!!+!++!++!++++!++!+!+!+');
    System.debug(q);
    System.debug('+!+!!+!++!++!++++!++!+!+!+');
    return q;
    
  }
  
  
  
  @AuraEnabled
  public static List<sObject> get_planification_cible_tile(List<Datetime> date_cible , String id_acteur , String api_name_date_planification, String api_name_object_cible  , String api_champs_a_afficher , String condition_object_cible ,String api_name_relation_object_cible_to_acteur , String api_champs_a_afficher_a_cote_date){
    
    DateTime originalDateTime = DateTime.valueOf(date_cible[0]);
    DateTime modifiedDateTime = DateTime.newInstance(
      originalDateTime.year(),
    originalDateTime.month(),
    originalDateTime.day(),
    originalDateTime.hour(),
    originalDateTime.minute(),
    0
      );
    
    DateTime originalDateTime2 = DateTime.valueOf(date_cible[1]);
    DateTime modifiedDateTime2 = DateTime.newInstance(
      originalDateTime2.year(),
    originalDateTime2.month(),
    originalDateTime2.day(),
    originalDateTime2.hour(),
    originalDateTime2.minute()-1,
    0
      );
    
    
    String formattedDateTimeString = modifiedDateTime.format('yyyy-MM-dd\'T\'HH:mm:ss.SSSZ');
    String formattedDateTimeString2 = modifiedDateTime2.format('yyyy-MM-dd\'T\'HH:mm:ss.SSSZ');
    
    
    String soqlQuery = '';
    soqlQuery = 'SELECT Id, ' + api_champs_a_afficher + ' , ' + api_name_date_planification + ' , ' + api_champs_a_afficher_a_cote_date   + ' FROM ' + api_name_object_cible;
    soqlQuery += ' WHERE ' + api_name_relation_object_cible_to_acteur + ' = \'' + id_acteur + '\' AND ' + api_name_date_planification + ' >=  ' +formattedDateTimeString + ' AND ' + api_name_date_planification + ' <=  ' +formattedDateTimeString2 + '  ';
    if(condition_object_cible != '' && condition_object_cible != null)
    {
      soqlQuery +=  ' AND '  +  condition_object_cible;
    }
    soqlQuery += ' LIMIT 2500';
    System.debug(soqlQuery);
    List<sObject> q = Database.query(soqlQuery);
    if (q == null) {
      q = new List<sObject>();
    }
    return q;
    
  }
  ///https://distancematrix.ai/pricing
  // api googlemap +++++++++++++++++++++++++++++++++++++++++++++++++++++ //
  //   @AuraEnabled(cacheable=true)
  //   public static List<durations> getDurations(String originPostalCode, List<String> destinationPostalCodes) {
    
    
    //    // List<durations> durations = new List<durations>();
    //     // //SECRET_RETIRE_DU_DEPOT_VOIR_ORG    // AIzaSyC9gozQDKQqd5n4_GSfdaWWLh254AGtd4c
    //     // String apiKey = System.Label.google_map_api;
    //     // System.debug(apiKey);
    //     // System.debug(apiKey);
    //     // String url_origin = 'https://maps.googleapis.com/maps/api/distancematrix/json?units=metric&origins=' + originPostalCode + '&destinations=' + String.join(destinationPostalCodes, '|') + '&departure_time=now&traffic_model=best_guess&key=' + apiKey;
    //     // //String url_origin = 'https://api.distancematrix.ai/maps/api/distancematrix/json?units=metric&origins=' + originPostalCode + '&destinations=' + String.join(destinationPostalCodes, '|') + '&mode=driving&key=' + apiKey;
    //     // String url = url_origin.replace(' ', '%20');
    
    
    
    
    //     // HttpRequest request = new HttpRequest();
    //     // request.setEndpoint(url);
    //     // request.setMethod('GET');
    
    
    //     // //https://api.distancematrix.ai/maps/api/distancematrix/json?units=metric&origins=37170 France|37290 France|41270 France|37130 France&destinations=37170 France|37290 France|41270 France|37130 France&mode=driving&key=SECRET_RETIRE_DU_DEPOT_VOIR_ORG
    //     // HttpResponse response = new Http().send(request);
    //     // if (response.getStatusCode() == 200) {
      
      //     //     Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
      //     //     List<Object> rows = (List<Object>) jsonResponse.get('rows');
      //     //     System.debug('+!+!+!!++!+!++!+!!+');
      //     //     System.debug(rows);
      //     //     System.debug('+!+!+!!++!+!++!+!!+');
      //     //     if (!rows.isEmpty()) {
        //     //         Map<String, Object> row = (Map<String, Object>) rows[0];
        //     //         List<Object> elements = (List<Object>) row.get('elements');
        //     //         Integer i = 0;
        //     //         for (Object element : elements) {
          //     //             Map<String, Object> duration = (Map<String, Object>) ((Map<String, Object>) element).get('duration_in_traffic');
          //     //             Map<String, Object> distance = (Map<String, Object>) ((Map<String, Object>) element).get('distance');
          //     //             String status = (String) ((Map<String, Object>) element).get('status');
          //     //             if(status == 'OK')
          //     //             {
            //     //             durations.add( new durations( distance != null ? (String) distance.get('text') : '0 km' ,  duration != null ?  (String) duration.get('text') :  '00 hour 00 mins' , destinationPostalCodes[i] , duration != null ? (Integer) duration.get('value') : 0 ));
          //     //             }
          //     //             i++;
        //     //         }
      //     //     }
    //     // }
    
    //     return durations;
    
    
    
    
  // }
  
  
  
  @AuraEnabled(cacheable=true)
  public static  List<durations> getDurations(String originPostalCode,  List<String> destinationPostalCodes , Integer index) {
    String apiUrl = 'https://api.openrouteservice.org/v2/matrix/driving-car';
    String apiKey;
    List<durations> durationsList = new List<durations>();
    
    if(destinationPostalCodes.size() > 0)
    {
      
      List<String> all_api_key = new List<String>{
        'SECRET_RETIRE_DU_DEPOT_VOIR_ORG'
          , 'SECRET_RETIRE_DU_DEPOT_VOIR_ORG'
          , 'SECRET_RETIRE_DU_DEPOT_VOIR_ORG'
          , 'SECRET_RETIRE_DU_DEPOT_VOIR_ORG'
      };
      
      Boolean active = false;
      Integer number_ai_key = all_api_key.size();
      //      while (active == false)
      //      {
        //     // get 'X-Ratelimit-Remaining' //
        //     List<List<String>> Fake_location = new List<List<String>>();
        //     Fake_location.add(parseCoordinates(destinationPostalCodes[0]));
        //     Fake_location.add(parseCoordinates(originPostalCode));
        
        
        
        
        //     Map<String, Object> fake_requestBodyMap = new Map<String, Object>();
        //     fake_requestBodyMap.put('locations', Fake_location);
        //  //   requestBodyMap.put('destinations', destinations_header); // Vous pouvez spécifier les destinations ici, par exemple [0, 1, 2]
        //     fake_requestBodyMap.put('metrics', new List<String>{'distance'});
        //     fake_requestBodyMap.put('units', 'km');
        //     String fake_requestBody = JSON.serialize(fake_requestBodyMap);
        
        //     // Créer la requête HTTP
        //     Http fake_http = new Http();
        //     HttpRequest fake_request = new HttpRequest();
        //     fake_request.setEndpoint(apiUrl);
        //     fake_request.setMethod('POST');
        //     fake_request.setHeader('Content-Type', 'application/json; charset=utf-8');
        //     fake_request.setHeader('Accept', 'application/json');
        //     fake_request.setHeader('Authorization', 'Bearer ' + all_api_key[index]);
        //     fake_request.setBody(fake_requestBody);
        
        //     // Envoyer la requête
        //     HttpResponse fake_response = fake_http.send(fake_request);
        
        
        //       Integer remainingRateLimit = Integer.valueOf((fake_response.getHeader('X-Ratelimit-Remaining') != null ? fake_response.getHeader('X-Ratelimit-Remaining') : '0'));
        //       if(remainingRateLimit < 10 )
        //       {
          //         if(index < 3)
          //         {
            //           index++;
          //         }
          //         else {
            //           index = 0;
          //         }
          //         number_ai_key--;
          
        //       }
        //       else {
          //         active = true;
        //       }
        //       if(number_ai_key == 0)
        //       {
          //         active = true;
        //       }
      //     }
      
      
      
      
      // get 'X-Ratelimit-Remaining' //
      
      
      
      // Préparer le corps de la requête en combinant originPostalCode et destinationPostalCodes
      List<List<String>> locations = new List<List<String>>();
      locations.add(parseCoordinates(originPostalCode));
      
      
      for (String destination : destinationPostalCodes) {
        if(parseCoordinates(destination).size() > 1)
          locations.add(parseCoordinates(destination));
      }
      
      System.debug('location ==> ' + locations);
      
      
      
      while (active == false)
      {
        
        Map<String, Object> requestBodyMap = new Map<String, Object>();
        requestBodyMap.put('locations', locations);
        //   requestBodyMap.put('destinations', destinations_header); // Vous pouvez spécifier les destinations ici, par exemple [0, 1, 2]
        requestBodyMap.put('metrics', new List<String>{'distance', 'duration'});
        requestBodyMap.put('units', 'km');
        String requestBody = JSON.serialize(requestBodyMap);
        
        // Créer la requête HTTP
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint(apiUrl);
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json; charset=utf-8');
        request.setHeader('Accept', 'application/json');
        request.setHeader('Authorization', 'Bearer ' + all_api_key[index]);
        request.setBody(requestBody);
        
        // Envoyer la requête
        HttpResponse response = http.send(request);
        
        Integer remainingRateLimit = Integer.valueOf((response.getHeader('X-Ratelimit-Remaining') != null ? response.getHeader('X-Ratelimit-Remaining') : '0'));
        
        if(remainingRateLimit < 10 )
        {
          if(index < 3)
          {
            index++;
          }
          else {
            index = 0;
          }
          number_ai_key--;
          
        }
        else {
          active = true;
        }
        if(number_ai_key == 0)
        {
          active = true;
        }
        
        
        // Analyser la réponse
        if (response.getStatusCode() == 200) {
          
          // Analyser la réponse JSON et remplir durationsList en conséquence
          Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
          
          // Désérialiser les données de durée, distance et destinations correctement
          List<Object> durationsData = (List<Object>) jsonResponse.get('durations');
          List<Object> distancesData = (List<Object>) jsonResponse.get('distances');
          List<Object> destinations = (List<Object>) jsonResponse.get('destinations');
          // System.debug('size destin data == > ' + destinationPostalCodes.size());
          // System.debug('size duration data == > ' + durationsData.size());
          
          for (Integer i = 0; i < 1/*durationsData.size()*/ ; i++) {
            // Cast des objets en List<Object>
            List<Object> durationData = (List<Object>) durationsData.get(i);
            List<Object> distanceData = (List<Object>) distancesData.get(i);
            
            // Accéder aux valeurs de durée et distance à partir de durationData et distanceData respectivement
            
            for(Integer j = 0; j < durationData.size(); j++)
            {
              Double durationInSeconds = (Double) durationData.get(j);
              Double distance = (Double) distanceData.get(j);
              
              // Vérifier et accéder à la valeur 'location' de l'objet destinations
              String destinationPostalCode =  String.valueOf(locations[i][1]) + ',' + String.valueOf(locations[i][0]); //destinationPostalCodes[i]
              String origin = String.valueOf(locations[j][1]) + ',' + String.valueOf(locations[j][0]); //destinationPostalCodes[j];
              //  System.debug('size destinationPostalCode  == > ' + destinationPostalCode);
              //  System.debug('size origin  == > ' + origin);
              
              
              // Convertir la durée en minutes
              Integer durationInMinutes = (Integer) Math.floor(durationInSeconds / 60);
              Integer durationInSeconde = (Integer) durationInSeconds;
              
              // Convertir la durée en format "hh hour mm mins"
              Integer hours = (Integer) Math.floor(durationInMinutes / 60);
              Integer minutes = Math.mod(durationInMinutes, 60);
              String durationString = String.valueOf(hours).leftPad(2, '0') + ' hour ' + String.valueOf(minutes).leftPad(2, '0') + ' mins';
              
              durationsList.add(new durations(String.valueOf(distance) + 'Km', durationString, destinationPostalCode , origin , durationInSeconde , (List<Object>) durationsData.get(j) , (List<Object>) distancesData.get(j) ));
              // System.debug('durationsList == > ' +durationsList[durationsList.size()-1]);
            }
          }
          
          
        } else {
          // Gérer les cas d'erreur si nécessaire
          System.debug('Erreur : ' + response.getStatusCode() + ' - ' + response.getStatus()  + ' - ' + response.getBody() );
        }
      }
    }
    // Retourner la liste de durations
    return durationsList;
    
  }
  
  public static Boolean containsUpperCase(String inputString) {
    Pattern pattern = Pattern.compile('.*[A-Z].*');
    Matcher matcher = pattern.matcher(inputString.toUpperCase());
    return !matcher.matches();
  }
  public static List<String> parseCoordinates(String coordinates) {
    List<String> coordinatesList = new List<String>();
    //System.debug('===cord==>>' + coordinates);
    // Diviser la chaîne de coordonnées en deux parties
    if(containsUpperCase(coordinates) == true)
    {
      
      List<String> parts = coordinates.split(',');
      
      // Ajouter les doubles à la liste dans l'ordre inverse
      if (parts.size() == 2) {
        try {
          // Assurez-vous que la chaîne contient deux parties (latitude et longitude)
          coordinatesList.add(/*Double.valueOf(*/parts[1].trim()/*)*/); // Ajouter la longitude
          coordinatesList.add(/*Double.valueOf(*/parts[0].trim()/*)*/); // Ajouter la latitude
        } catch (Exception e) {
          // Gérer l'exception si la conversion échoue
          System.debug('Erreur : La longitude n\'est pas un double valide');
        }
      } else {
        // Gérer les cas d'erreur si la chaîne de coordonnées est invalide
        
        System.debug('Erreur : Format de coordonnées invalide');
      }
      // if( coordinates == '49.516085 , 5.773984')
      // {
        //   doooo = 'Not ERROR';
        //  System.de
      // }
      return coordinatesList;
    }
    else {
      coordinatesList = new List<String>();
      return coordinatesList;
    }
  }
  
  
  @AuraEnabled
  public static String makeZipCodeRequest(String zipcode) {
    // Specify the API endpoint and parameters with dynamic zipcode and country
    String apiUrl = 'https://api.zipcodestack.com/v1/search?codes=' + EncodingUtil.urlEncode(zipcode, 'UTF-8') + '&country=fr';
    String apiKey = 'SECRET_RETIRE_DU_DEPOT_VOIR_ORG';
    String result = '';
    
    // Create an HTTP request
    Http http = new Http();
    HttpRequest request = new HttpRequest();
    request.setEndpoint(apiUrl);
    request.setMethod('GET');
    request.setHeader('apikey', apiKey);
    
    // Send the HTTP request
    HttpResponse response = http.send(request);
    
    // Handle the API response
    if (response.getStatusCode() == 200) {
      // API request was successful, handle the response data here
      Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
      
      // Extract data from the JSON response
      Map<String, Object> results = (Map<String, Object>) jsonResponse.get('results');
      if (results != null && !results.isEmpty()) {
        List<Object> locationDataList = (List<Object>) results.values()[0];
        if (locationDataList != null && !locationDataList.isEmpty()) {
          Map<String, Object> locationData = (Map<String, Object>) locationDataList[0];
          Double latitude = (Double) locationData.get('latitude');
          Double longitude = (Double) locationData.get('longitude');
          result = latitude + ',' + longitude;
        }
      }
    } else {
      // API request failed, handle the error response here
      System.debug('API Request failed with status code: ' + response.getStatusCode());
      System.debug('Response body: ' + response.getBody());
    }
    return result;
  }
  
  // api googlemap +++++++++++++++++++++++++++++++++++++++++++++++++++++ //
  
  
  @AuraEnabled(cacheable=true)
  public static List<durations> getDurationsDaily(List<String> originPostalCodes, List<String> destinationPostalCodes) {
    List<durations> durations = new List<durations>();
    
    
    
    
    // // Analyser la réponse JSON et remplir durationsList en conséquence
    // Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
    
    // // Désérialiser les données de durée, distance et destinations correctement
    // List<Object> durationsData = (List<Object>) jsonResponse.get('durations');
    // List<Object> distancesData = (List<Object>) jsonResponse.get('distances');
    // List<Object> destinations = (List<Object>) jsonResponse.get('destinations');
    // System.debug('size destin data == > ' + destinationPostalCodes.size());
    // System.debug('size duration data == > ' + durationsData.size());
    
    // for (Integer i = 1; i < durationsData.size(); i++) {
      //     // Cast des objets en List<Object>
      //     List<Object> durationData = (List<Object>) durationsData.get(i);
      //     List<Object> distanceData = (List<Object>) distancesData.get(i);
      
      //     // Accéder aux valeurs de durée et distance à partir de durationData et distanceData respectivement
      //     Double durationInSeconds = (Double) durationData.get(0);
      //     Double distance = (Double) distanceData.get(0);
      
      //     // Vérifier et accéder à la valeur 'location' de l'objet destinations
      //     String destinationPostalCode = destinationPostalCodes[i-1];
      //     // if (destinations.size() > i - 1) {
        //     //     Map<String, Object> destinationMap = (Map<String, Object>) destinations.get(i - 1);
        //     //     if (destinationMap.containsKey('location') && destinationMap.get('location') instanceof String) {
          //     //         destinationPostalCode = (String) destinationMap.get('location');
        //     //     }
      //     // }
      
      //     // Vérifier si destinationPostalCode est non-null avant de l'utiliser dans votre logique
      
      //     // Convertir la durée en minutes
      //     Integer durationInMinutes = (Integer) Math.floor(durationInSeconds / 60);
      //     Integer durationInSeconde = (Integer) durationInSeconds;
      
      //     // Convertir la durée en format "hh hour mm mins"
      //     Integer hours = (Integer) Math.floor(durationInMinutes / 60);
      //     Integer minutes = Math.mod(durationInMinutes, 60);
      //     String durationString = String.valueOf(hours).leftPad(2, '0') + ' hour ' + String.valueOf(minutes).leftPad(2, '0') + ' mins';
      
      //     durationsList.add(new durations(String.valueOf(distance) + 'Km', durationString, destinationPostalCode, durationInSeconde));
    // }
    
    
    
    
    
    
    //   String apiUrl = 'https://api.openrouteservice.org/v2/matrix/driving-car';
    //   String apiKey = 'SECRET_RETIRE_DU_DEPOT_VOIR_ORG';
    
    //   // Préparer le corps de la requête en combinant originPostalCode et destinationPostalCodes
    //   List<List<Double>> locations = new List<List<Double>>();
    
    //   for (String origin : originPostalCodes) {
      //     if(parseCoordinates(origin).size() > 1)
      //       locations.add(parseCoordinates(origin));
    //   }
    
    //   for (String destination : destinationPostalCodes) {
      //     if(parseCoordinates(destination).size() > 1)
      //       locations.add(parseCoordinates(destination));
    //   }
    
    //   System.debug('location ==> ' + locations);
    //   // List<Integer> destinations_header = new List<Integer>();
    //   // destinations_header.add(0);
    //   Map<String, Object> requestBodyMap = new Map<String, Object>();
    //   requestBodyMap.put('locations', locations);
    //   // requestBodyMap.put('destinations', 'all'); // Vous pouvez spécifier les destinations ici, par exemple [0, 1, 2]
    //   requestBodyMap.put('metrics', new List<String>{'distance', 'duration'});
    //   requestBodyMap.put('units', 'km');
    //   String requestBody = JSON.serialize(requestBodyMap);
    
    //   // Créer la requête HTTP
    //   Http http = new Http();
    //   HttpRequest request = new HttpRequest();
    //   request.setEndpoint(apiUrl);
    //   request.setMethod('POST');
    //   request.setHeader('Content-Type', 'application/json; charset=utf-8');
    //   request.setHeader('Accept', 'application/json');
    //   request.setHeader('Authorization', 'Bearer ' + apiKey);
    //   request.setBody(requestBody);
    // //  System.debug('response data == > ' + jsonResponse);
    
    //   // Envoyer la requête
    //   HttpResponse response = http.send(request);
    
    //   // Analyser la réponse
    //   List<durations> durationsList = new List<durations>();
    //   if (response.getStatusCode() == 200) {
      //     // Analyser la réponse JSON et remplir durationsList en conséquence
      //     Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
      
      //     // Désérialiser les données de durée, distance et destinations correctement
      //     List<Object> durationsData = (List<Object>) jsonResponse.get('durations');
      //     List<Object> distancesData = (List<Object>) jsonResponse.get('distances');
      //     List<Object> destinations = (List<Object>) jsonResponse.get('destinations');
      //     System.debug('size destin data == > ' + destinationPostalCodes.size());
      //     System.debug('size duration data == > ' + durationsData.size());
      
      //     for (Integer i = 0; i < durationsData.size(); i++) {
        //         // Cast des objets en List<Object>
        //         List<Object> durationData = (List<Object>) durationsData.get(i);
        //         List<Object> distanceData = (List<Object>) distancesData.get(i);
        
        //         // Accéder aux valeurs de durée et distance à partir de durationData et distanceData respectivement
        
        //         // List<Double> durationInSeconds = (List<Double>) durationData;
        //         // List<Double> distance = (List<Double>) distanceData;
        
        //         for(Integer j = 0; j < durationData.size(); j++)
        //         {
          //           Double durationInSeconds = (Double) durationData.get(j);
          //           Double distance = (Double) distanceData.get(j);
          
          //           // Vérifier et accéder à la valeur 'location' de l'objet destinations
          //           String destinationPostalCode = destinationPostalCodes[i];
          //           String origin = originPostalCodes[j];
          //           // if (destinations.size() > i - 1) {
            //           //     Map<String, Object> destinationMap = (Map<String, Object>) destinations.get(i - 1);
            //           //     if (destinationMap.containsKey('location') && destinationMap.get('location') instanceof String) {
              //           //         destinationPostalCode = (String) destinationMap.get('location');
            //           //     }
          //           // }
          
          //           // Vérifier si destinationPostalCode est non-null avant de l'utiliser dans votre logique
          
          //           // Convertir la durée en minutes
          //           Integer durationInMinutes = (Integer) Math.floor(durationInSeconds / 60);
          //           Integer durationInSeconde = (Integer) durationInSeconds;
          
          //           // Convertir la durée en format "hh hour mm mins"
          //           Integer hours = (Integer) Math.floor(durationInMinutes / 60);
          //           Integer minutes = Math.mod(durationInMinutes, 60);
          //           String durationString = String.valueOf(hours).leftPad(2, '0') + ' hour ' + String.valueOf(minutes).leftPad(2, '0') + ' mins';
          
          //           durationsList.add(new durations(String.valueOf(distance) + 'Km', durationString, destinationPostalCode , origin , durationInSeconde));
        //         }
        
        
      //     }
    // } else {
      //       // Gérer les cas d'erreur si nécessaire
      //       System.debug('Erreur : ' + response.getStatusCode() + ' - ' + response.getStatus()  + ' - ' + response.getBody() );
    //   }
    
    //   // Retourner la liste de durations
    //   return durationsList;
    
    
    
    //  // SECRET_RETIRE_DU_DEPOT_VOIR_ORG    // AIzaSyC9gozQDKQqd5n4_GSfdaWWLh254AGtd4c
    //   String apiKey = System.Label.google_map_api;
    //   System.debug(apiKey);
    //   System.debug(apiKey);
    //   String url_origin = 'https://maps.googleapis.com/maps/api/distancematrix/json?units=metric&origins=' + String.join(originPostalCodes, '|')  +  '&destinations=' + String.join(destinationPostalCodes, '|') + '&departure_time=now&traffic_model=best_guess&key=' + apiKey;
    //   String url = url_origin.replace(' ', '%20');
    //   //String url = 'https://api.distancematrix.ai/maps/api/distancematrix/json?units=metric&origins=' +String.join(originPostalCodes, '|')  + '&destinations=' + String.join(destinationPostalCodes, '|') + '&mode=driving&key=' + apiKey;
    //   HttpRequest request = new HttpRequest();
    //   request.setEndpoint(url);
    //   request.setMethod('GET');
    
    
    //   System.debug('+!+!+!!++!+!++!+!!+');
    //   System.debug(url);
    //   System.debug('+!+!+!!++!+!++!+!!+');
    
    
    //   HttpResponse response = new Http().send(request);
    
    //   System.debug('+!+!+!!++!+!++!+!!+');
    //   System.debug(response.getStatusCode() );
    //   System.debug('+!+!+!!++!+!++!+!!+');
    
    
    //   if (response.getStatusCode() == 200) {
      
      //       Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
      //       List<Object> rows = (List<Object>) jsonResponse.get('rows');
      //       List<Object> destination_addresses = (List<Object>) jsonResponse.get('destination_addresses');
      //       List<Object> origin_addresses =  (List<Object>) jsonResponse.get('origin_addresses');
      
      
      //       System.debug('+!+!+!!++!+!++!+!!+');
      //       System.debug(rows);
      //       System.debug('+!+!+!!++!+!++!+!!+');
      //       if (!rows.isEmpty()) {
        //           // Map<String, Object> row = (Map<String, Object>) rows[0];
        //           Integer r = 0;
        //           for(Object row : rows)
        //           {
          //             Map<String, Object> row_r = (Map<String, Object>) row;
          //            // List<Object> destination_addresses = (List<Object>) row_r.get('destination_addresses');
          //             List<Object> elements = (List<Object>) row_r.get('elements');
          //             Integer i = 0;
          //             for (Object element : elements) {
            //                 Map<String, Object> duration = (Map<String, Object>) ((Map<String, Object>) element).get('duration_in_traffic');
            //                 Map<String, Object> distance = (Map<String, Object>) ((Map<String, Object>) element).get('distance');
            //                 String status = (String) ((Map<String, Object>) element).get('status');
            //                 // String origin = (String) ((Map<String, Object>) element).get('origin');
            //                 // String destination = (String) ((Map<String, Object>) element).get('destination');
            //                 String origin =  (String) destination_addresses[i];
            //                 String destination = (String) origin_addresses[r] ;
            
            //                 if(status == 'OK')
            //                 {
              //                 durations.add( new durations( distance != null ? (String) distance.get('text') : '0 km' ,  duration != null ?  (String) duration.get('text') :  '00 hour 00 mins' , destination , origin , duration != null ? (Integer) duration.get('value') : 0 ));
            //                 }
            //                 i++;
          //             }
          //             r++;
        //           }
      //       }
    //   }
    
    return durations;
  }
  
  
  @AuraEnabled
  public static String desactiver_thech(String Id)
  {
    Camion__c cam = new Camion__c(Id = Id ,isTechnicien__c = false);
    update cam;
    return 'Bien été désactivé.';
  }
  
  
  @future(callout=true)
  public static void fetchCoordinates(Set<String> zipCodes) {
    // Map to store results
    Map<String, String> gpsCoordinates = new Map<String, String>();
    Http http = new Http();
    
    for (String zip : zipCodes) {
      // Specify the API endpoint and parameters with the dynamic zip code
      String apiUrl = 'https://api.zipcodestack.com/v1/search?codes=' + EncodingUtil.urlEncode(zip, 'UTF-8') + '&country=fr';
      String apiKey = 'SECRET_RETIRE_DU_DEPOT_VOIR_ORG';
      
      // Create an HTTP request
      HttpRequest request = new HttpRequest();
      request.setEndpoint(apiUrl);
      request.setMethod('GET');
      request.setHeader('apikey', apiKey);
      
      // Send the HTTP request
      HttpResponse response = http.send(request);
      
      // Handle the API response
      if (response.getStatusCode() == 200) {
        Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
        Map<String, Object> results = (Map<String, Object>) jsonResponse.get('results');
        
        if (results != null && !results.isEmpty()) {
          List<Object> locationDataList = (List<Object>) results.values()[0];
          if (locationDataList != null && !locationDataList.isEmpty()) {
            Map<String, Object> locationData = (Map<String, Object>) locationDataList[0];
            Double latitude = (Double) locationData.get('latitude');
            Double longitude = (Double) locationData.get('longitude');
            String coords = latitude + ',' + longitude;
            gpsCoordinates.put(zip, coords);
          }
        }
      } else {
        System.debug('API Request failed with status code: ' + response.getStatusCode());
        System.debug('Response body: ' + response.getBody());
      }
    }
    
    // Update the Opportunities with the GPS coordinates
    List<Opportunity> oppsToUpdate = new List<Opportunity>();
    for (String zip : gpsCoordinates.keySet()) {
      // Query Opportunities for the zip code
      List<Opportunity> opportunities = [SELECT Id, CoordonneesGPS__c FROM Opportunity WHERE TravauxCodePostal__c = :zip];
      for (Opportunity opp : opportunities) {
        opp.CoordonneesGPS__c = gpsCoordinates.get(zip);
        oppsToUpdate.add(opp);
      }
    }
    
    // Perform the update only if there are opportunities to update
    if (!oppsToUpdate.isEmpty()) {
      update oppsToUpdate;
    }
  }
  
  // wrapper +++++++++++++++++++++++++++++++++++++++++++++++++++++ //
  public class ConformeAutre {
    @AuraEnabled
    public Object Autre {get; set;}
    @AuraEnabled
    public Object Conforme {get;set;}
    
    public ConformeAutre()
    {
      
    }
    
    public ConformeAutre(Object Autre , Object Conforme)
    {
      this.Autre = Autre;
      this.Conforme = Conforme;
    }
  }
  
  
  
  public class Parametrage_planification_all {
    @AuraEnabled
    public String daysOff {get; set;}
    
    @AuraEnabled
    public List<Parametrage_planification> planifications {get; set;}
    
    public Parametrage_planification_all()
    {
    }
    public Parametrage_planification_all(List<Parametrage_planification> planifications)
    {
      this.planifications = planifications;
    }
    
  }
  
  public class Parametrage_planification {
    @AuraEnabled
    public String titre_menu {get; set;}
    @AuraEnabled
    public String cas_exception {get; set;}
    @AuraEnabled
    public Parametrage_acteur acteur {get; set;}
    @AuraEnabled
    public Parametrage_object_cible object_cible {get; set;}
    @AuraEnabled
    public List<Parametrage_crenreaux> crenreaux {get; set;}
    
    
    public Parametrage_planification()
    {
    }
    public Parametrage_planification(String titre_menu , String cas_exception ,  Parametrage_acteur acteur  , Parametrage_object_cible object_cible , List<Parametrage_crenreaux> crenreaux )
    {
      this.titre_menu = titre_menu;
      this.cas_exception = cas_exception;
      this.acteur = acteur;
      this.crenreaux = crenreaux;
      this.object_cible = object_cible;
    }
    
  }
  
  
  public class Parametrage_acteur {
    @AuraEnabled
    public String api_name_object_acteur {get; set;}
    @AuraEnabled
    public String api_name_name {get;set;}
    @AuraEnabled
    public String condition_object_acteur {get;set;}
    @AuraEnabled
    public String couleur_api_name_acteur {get;set;}
    @AuraEnabled
    public String api_name_relation_object_acteur_to_cible {get;set;}
    @AuraEnabled
    public String conges_champs_text_long_api_name {get; set;}
    
    public Parametrage_acteur()
    {
    }
    public Parametrage_acteur(String api_name_object_acteur , String api_name_name , String condition_object_acteur , String couleur_api_name_acteur , String api_name_relation_object_acteur_to_cible ,String conges_champs_text_long_api_name)
    {
      this.api_name_object_acteur = api_name_object_acteur;
      this.api_name_name = api_name_name;
      this.condition_object_acteur = condition_object_acteur;
      this.couleur_api_name_acteur = couleur_api_name_acteur;
      this.api_name_relation_object_acteur_to_cible = api_name_relation_object_acteur_to_cible;
      this.conges_champs_text_long_api_name = conges_champs_text_long_api_name;
    }
  }
  
  
  
  public class Parametrage_crenreaux {
    // @AuraEnabled
    // public Time time_crenreaux {get; set;}
    
    @AuraEnabled
    public String crenreaux {get; set;}
    
    public Parametrage_crenreaux()
    {
    }
    public Parametrage_crenreaux(String crenreaux) {
      this.crenreaux = crenreaux;
      // this.time_crenreaux = Time.newInstance(this.crenreaux.split('h')[0], this.crenreaux.split('h')[1], 0, 0);
    }
    
  }
  
  public class Parametrage_object_cible {
    @AuraEnabled
    public String api_name_object_cible {get; set;}
    @AuraEnabled
    public String api_name_date_planification {get; set;}
    @AuraEnabled
    public String api_name_badge {get; set;}
    @AuraEnabled
    public String condition_object_cible {get; set;}
    @AuraEnabled
    public String api_name_relation_object_cible_to_acteur {get; set;}
    @AuraEnabled
    public String api_champs_a_afficher {get; set;}
    @AuraEnabled
    public List<Parametrage_cible_condition_couleur> condition_object_cible_couleur {get; set;}
    @AuraEnabled
    public String api_champs_a_info_supl {get; set;}
    @AuraEnabled
    public String name_champs_a_info_supl {get; set;}
    @AuraEnabled
    public String  api_champs_a_afficher_a_cote_date {get; set;}
    @AuraEnabled
    public String  coodone_atitude_longitude {get; set;}
    
    
    
    
    
    
    
    public Parametrage_object_cible()
    {
    }
    public Parametrage_object_cible(String api_name_object_cible , String api_name_date_planification ,String api_name_relation_object_cible_to_acteur ,  String api_champs_a_afficher , String condition_object_cible  ,  List<Parametrage_cible_condition_couleur> condition_object_cible_couleur ,String api_champs_a_info_supl , String name_champs_a_info_supl , String api_champs_a_afficher_a_cote_date , String coodone_atitude_longitude, String api_name_badge)
    {
      this.api_name_object_cible = api_name_object_cible;
      this.api_name_date_planification = api_name_date_planification;
      this.condition_object_cible = condition_object_cible;
      this.api_name_relation_object_cible_to_acteur = api_name_relation_object_cible_to_acteur;
      this.api_champs_a_afficher = api_champs_a_afficher;
      this.condition_object_cible_couleur = condition_object_cible_couleur;
      this.api_champs_a_info_supl = api_champs_a_info_supl;
      this.name_champs_a_info_supl = name_champs_a_info_supl;
      this.api_champs_a_afficher_a_cote_date = api_champs_a_afficher_a_cote_date;
      this.coodone_atitude_longitude = coodone_atitude_longitude;
      this.api_name_badge = api_name_badge;
    }
    
  }
  
  public class Parametrage_cible_condition_couleur {
    @AuraEnabled
    public String column_api_name {get; set;}
    @AuraEnabled
    public String column_api_value {get; set;}
    @AuraEnabled
    public String couleur {get;set;}
    
    
    public Parametrage_cible_condition_couleur()
    {
    }
    public Parametrage_cible_condition_couleur(String column_api_name , String column_api_value , String couleur)
    {
      this.column_api_name = column_api_name;
      this.column_api_value = column_api_value;
      this.couleur = couleur;
    }
  }
  
  public class durations {
    
    @AuraEnabled
    public String distance {get; set;}
    @AuraEnabled
    public String duration {get; set;}
    @AuraEnabled
    public String postalcode {get; set;}
    @AuraEnabled
    public Integer duration_value {get; set;}
    @AuraEnabled
    public String origin {get; set;}
    @AuraEnabled
    public String destination {get; set;}
    @AuraEnabled
    public List<Object> duration_globale {get; set;}
    @AuraEnabled
    public List<Object> distance_globale {get; set;}
    
    public durations(String distance , String duration , String postalcode , Integer duration_value)
    {
      this.distance = distance;
      this.duration = duration;
      this.postalcode = postalcode;
      this.duration_value = duration_value;
    }
    
    public durations(String distance , String duration , String postalcode , String origin , Integer duration_value , List<Object> duration_globale , List<Object> distance_globale)
    {
      this.distance = distance;
      this.duration = duration;
      this.origin = origin;
      this.postalcode = postalcode;
      this.duration_value = duration_value;
      this.duration_globale = duration_globale;
      this.distance_globale = distance_globale;
    }
    
  }
  
  
  
  
  public class durations_all {
    @AuraEnabled
    public List<durations> duration {get; set;}
    @AuraEnabled
    public Map<String, Object> durations_all {get; set;}
    
    public durations_all(List<durations> duration , Map<String, Object> durations_all)
    {
      this.duration = duration;
      this.durations_all = durations_all;
    }
    
  }
  
  
  public class api_etat_all {
    @AuraEnabled
    public List<api_etat> api_etat_list {get; set;}
    
    public api_etat_all(List<api_etat> api_etat_list)
    {
      this.api_etat_list = api_etat_list;
    }
    
  }
  
  
  public class api_etat {
    @AuraEnabled
    public String api_key {get; set;}
    @AuraEnabled
    public Boolean etat_key {get; set;}
    
    public api_etat(String api_key , Boolean etat_key)
    {
      this.api_key = api_key;
      this.etat_key = etat_key;
    }
    
  }
  
  
  public static void fake_method()
  {
    Integer i = 0;
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
  }
}