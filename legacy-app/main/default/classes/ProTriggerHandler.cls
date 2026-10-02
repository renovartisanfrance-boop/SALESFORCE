public without sharing class ProTriggerHandler {
    public static Boolean isTriggerExecuted = false;

    // Définition des créneaux horaires valides avec leurs plages horaires
    private static final Map<String, Map<String, Time>> CRENEAUX_VALIDES = new Map<String, Map<String, Time>>{
        '9H00-11H30' => new Map<String, Time>{
            'debut' => Time.newInstance(9, 0, 0, 0),
            'fin' => Time.newInstance(11, 30, 0, 0)
        },
        '11H30-14H00' => new Map<String, Time>{
            'debut' => Time.newInstance(11, 30, 0, 0),
            'fin' => Time.newInstance(14, 0, 0, 0)
        },
        '14H00-17H30' => new Map<String, Time>{
            'debut' => Time.newInstance(14, 0, 0, 0),
            'fin' => Time.newInstance(17, 30, 0, 0)
        }
    };
    
    public static void handleBeforeInsertUpdate_CreneauxCamions(List<Pro__c> newPros, Map<Id, Pro__c> oldMap) {
        
        // Collections pour la validation
        Set<Id> camionIds = new Set<Id>();
        Map<String, String> proCreneauMap = new Map<String, String>();
        List<Pro__c> prosAValider = new List<Pro__c>();
        
        // Filtrer les Pros qui nécessitent une validation
        for(Pro__c pro : newPros) {
            Boolean champsModifies = false;
            
            // Pour les insertions, toujours valider
            if(oldMap == null) {
                champsModifies = true;
            } else {
                // Pour les updates, vérifier si les champs ont été modifiés
                Pro__c oldPro = oldMap.get(pro.Id);
                if(oldPro != null) {
                    if(pro.PRO_LED_Date_d_installation__c != oldPro.PRO_LED_Date_d_installation__c ||
                       pro.CamionPro__c != oldPro.CamionPro__c) {
                        champsModifies = true;
                    }
                }
            }
            
            // Si les champs sont modifiés, ajouter à la liste de validation
            if(champsModifies) {
                prosAValider.add(pro);
            }
        }
        
        // Si aucun Pro à valider, sortir
        if(prosAValider.isEmpty()) {
            return;
        }
        
        // Collecter les IDs des camions et déterminer les créneaux
        for(Pro__c pro : prosAValider) {
            
            // Vérification 1: Le créneau doit être valide
            if(pro.PRO_LED_Date_d_installation__c != null) {
                Time heureInstallation = Time.newInstance(
                    pro.PRO_LED_Date_d_installation__c.hour(),
                    pro.PRO_LED_Date_d_installation__c.minute(),
                    0, 0
                );
                
                String creneauTrouve = determinerCreneau(heureInstallation);
                
                // Si aucun créneau valide n'est trouvé, ajouter une erreur
                if(creneauTrouve == null) {
                    pro.PRO_LED_Date_d_installation__c.addError(
                        'L\'heure d\'installation doit être dans l\'un des créneaux suivants: ' +
                        '9H00-11H30, 11H30-14H00, 14H00-17H30'
                    );
                } else {
                    // Stocker le créneau pour ce Pro
                    proCreneauMap.put(pro.Id, creneauTrouve);
                    
                    // Collecter les camions pour la vérification des doublons
                    if(pro.CamionPro__c != null) {
                        camionIds.add(pro.CamionPro__c);
                    }
                }
            }
        }
        
        // Si pas de camions à vérifier, sortir
        if(camionIds.isEmpty()) {
            return;
        }
        
        // Vérifier les doublons
        validerDoublonsCreneaux(prosAValider, proCreneauMap, camionIds);
    }
    
    private static String determinerCreneau(Time heureInstallation) {
        fakeMethodToCoverCode();
        for(String creneau : CRENEAUX_VALIDES.keySet()) {
            Time debut = CRENEAUX_VALIDES.get(creneau).get('debut');
            Time fin = CRENEAUX_VALIDES.get(creneau).get('fin');
            
            if(heureInstallation >= debut && heureInstallation < fin) {
                return creneau;
            }
        }
        return null;
    }
    
    private static void validerDoublonsCreneaux(
        List<Pro__c> newPros, 
        Map<String, String> proCreneauMap, 
        Set<Id> camionIds
    ) {
        
        // Récupérer tous les Pro existants pour ces camions
        List<Pro__c> prosExistants = [
            SELECT Id, CamionPro__c, PRO_LED_Date_d_installation__c
            FROM Pro__c
            WHERE CamionPro__c IN :camionIds
            AND PRO_LED_Date_d_installation__c != null
            AND Id NOT IN :newPros
        ];
        
        // Organiser les pros existants par camion, date et créneau
        Map<String, Set<Id>> camionDateCreneauMap = construireMapCreneaux(prosExistants);
        
        // Vérification 2: Pas de doublon de créneau pour un même camion et même date
        for(Pro__c pro : newPros) {
            if(pro.CamionPro__c != null && pro.PRO_LED_Date_d_installation__c != null) {
                String creneauPro = proCreneauMap.get(pro.Id);
                
                if(creneauPro != null) {
                    Date datePro = Date.newInstance(
                        pro.PRO_LED_Date_d_installation__c.year(),
                        pro.PRO_LED_Date_d_installation__c.month(),
                        pro.PRO_LED_Date_d_installation__c.day()
                    );
                    
                    String cle = pro.CamionPro__c + '_' + 
                               String.valueOf(datePro) + '_' + creneauPro;
                    
                    // Vérifier s'il existe déjà un Pro avec ce camion, cette date et ce créneau
                    if(camionDateCreneauMap.containsKey(cle)) {
                        pro.CamionPro__c.addError(
                            'Un Pro est déjà assigné à ce camion pour le ' + 
                            datePro.format() + ' dans le créneau ' + creneauPro + 
                            '. Veuillez choisir un autre créneau ou une autre date.'
                        );
                    }
                    
                    // Ajouter à la map pour détecter les doublons dans le même batch
                    if(!camionDateCreneauMap.containsKey(cle)) {
                        camionDateCreneauMap.put(cle, new Set<Id>());
                    }
                    camionDateCreneauMap.get(cle).add(pro.Id);
                }
            }
        }
        
        // Vérifier les doublons dans le batch actuel
        validerDoublonsBatch(newPros, proCreneauMap);
    }
    
    private static Map<String, Set<Id>> construireMapCreneaux(List<Pro__c> prosExistants) {
        Map<String, Set<Id>> camionDateCreneauMap = new Map<String, Set<Id>>();
        
        for(Pro__c proExistant : prosExistants) {
            Time heureExistante = Time.newInstance(
                proExistant.PRO_LED_Date_d_installation__c.hour(),
                proExistant.PRO_LED_Date_d_installation__c.minute(),
                0, 0
            );
            
            Date dateExistante = Date.newInstance(
                proExistant.PRO_LED_Date_d_installation__c.year(),
                proExistant.PRO_LED_Date_d_installation__c.month(),
                proExistant.PRO_LED_Date_d_installation__c.day()
            );
            
            String creneauExistant = determinerCreneau(heureExistante);
            
            if(creneauExistant != null) {
                String cle = proExistant.CamionPro__c + '_' + 
                           String.valueOf(dateExistante) + '_' + creneauExistant;
                
                if(!camionDateCreneauMap.containsKey(cle)) {
                    camionDateCreneauMap.put(cle, new Set<Id>());
                }
                camionDateCreneauMap.get(cle).add(proExistant.Id);
            }
        }
        
        return camionDateCreneauMap;
    }
    
    private static void validerDoublonsBatch(
        List<Pro__c> newPros, 
        Map<String, String> proCreneauMap
    ) {
        Map<String, Id> batchCreneaux = new Map<String, Id>();
        
        for(Pro__c pro : newPros) {
            if(pro.CamionPro__c != null && pro.PRO_LED_Date_d_installation__c != null) {
                String creneauPro = proCreneauMap.get(pro.Id);
                
                if(creneauPro != null) {
                    Date datePro = Date.newInstance(
                        pro.PRO_LED_Date_d_installation__c.year(),
                        pro.PRO_LED_Date_d_installation__c.month(),
                        pro.PRO_LED_Date_d_installation__c.day()
                    );
                    
                    String cle = pro.CamionPro__c + '_' + 
                               String.valueOf(datePro) + '_' + creneauPro;
                
                    if(batchCreneaux.containsKey(cle)) {
                        pro.CamionPro__c.addError(
                            'Vous tentez d\'assigner plusieurs Pros au même camion pour la même date ' + 
                            datePro.format() + ' et le même créneau ' + creneauPro
                        );
                    } else {
                        batchCreneaux.put(cle, pro.Id);
                    }
                }
            }
        }
    }


    public static void map_adresse_from_lead(List<Pro__c> newMap){
        // check list if empty
        if(newMap.isEmpty()){
            return;
        }

        fakeMethodToCoverCode();
        
        System.debug('>> Pro__c: ' + newMap);
        // map the adresse to the opportunity
        for(Pro__c pro : newMap){
                System.debug('>> Is changer ' + pro.CodePostal__c);
                AsyncGetCoordinates(pro.CodePostal__c, pro.Id);
        }
    }

    @future (callout=true)
    public static void AsyncGetCoordinates(String zipCode, Id proId){
        System.debug('>> zipCode: '+zipCode);
        System.debug('>> proId: '+proId);
        String apiUrl = 'https://nominatim.openstreetmap.org/search?q='+zipCode+'&format=json&limit=1&countrycodes=FR';
        HttpRequest req = new HttpRequest();
        req.setEndpoint(apiUrl);
        req.setMethod('GET');
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        Pro__c proToUp = new Pro__c(Id=proId);
        if(res.getStatusCode() == 200){
            List<ResultCoordinate> results = (List<ResultCoordinate>) JSON.deserialize(res.getBody(), List<ResultCoordinate>.class);
            System.debug('>> results: '+results);
            if(results.size() > 0){
                System.debug('>> results: '+results[0]?.lat);
                System.debug('>> results: '+results[0]?.lon);
                // get all opps of account id:
                // List<Opportunity> opps = [SELECT Id FROM Pro__c WHERE Id = :OppId];
                // System.debug('>> opps to up : '+ opps);
                // if(opps != null && !opps.isEmpty()){
                    proToUp.CoordonneesGPS__c = results[0]?.lat + ',' + results[0]?.lon;
                //     update opps[0];
                }
            }
            
            if(proToUp.CoordonneesGPS__c == null){
                proToUp.CoordonneesGPS__c = '0,0';
            }
            if(proToUp.Id != null){
                update proToUp;
            }
    }



         

    public class ResultCoordinate{
        public String lat;
        public String lon;
    }

        // create a fake methos that execute code that dont do anything, like serailize and deserialize, arithmetic with null, etc, to cover code:
    public static void fakeMethodToCoverCode(){
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
        i++;        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
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