@RestResource(urlMapping='/odoo/*')
global without sharing class OdooController {
    
    public static final String API_SECRET = Label.ODOO_TOKEN;
    
    @HttpPost
    @RestResource(urlMapping='/odoo/createLead')
    global static void createLeadFromOdoo(/*PayloadPiste piste, String token*/) {

//         BatchUpdateEnMasse batch4 = new BatchUpdateEnMasse();
// Id jobId4 = Database.executeBatch(batch4, 200);



        RestResponse res = RestContext.response;

        // Check API Key
        String apisecret_url = RestContext.request.params.get('secretodoo');
        RestRequest req = RestContext.request;
        // is not test environment
        if ((apisecret_url == null || apisecret_url != API_SECRET) && !Test.isRunningTest()) {
            res.statusCode = 401;
            return;
            // return JSON.serialize(new Map<String, Object>{ 'success' => false, 'error' => 'Unauthorized Access' });
        }
        
        try {
            
            String body = req.requestBody.toString();
            PayloadPiste piste = (PayloadPiste) JSON.deserialize(body, PayloadPiste.class);
            
            // // Création d'un Lead Salesforce
            Lead newLead = new Lead();

            // shared fields: traited first to can be overriden by the form
            newLead.Plateforme__c = 'ODOO';

            newLead.Phone = piste.phone_sanitized;
            try{
                newLead.Mode_de_chauffage_Formulaire__c = piste.heating_type != 'false' ? piste.heating_type : '';
            } catch(Exception e){
                System.debug('Error in Mode_de_chauffage_Formulaire__c / heating_type: \'' + piste.heating_type + '\' ==> ' + e.getMessage());
            }
            
            newLead.Origine_de_la_demande__c = 'N1 ' + piste.website_name;
            try{
                 newLead.Raison_sociale__c = piste.raison_social != 'false' && piste.raison_social != null && piste.raison_social != '' ? piste.raison_social : newLead.Raison_sociale__c;
            } catch(Exception e){
                System.debug('Error in Raison_sociale__c / raison_social: \'' + piste.raison_social + '\' ==> ' + e.getMessage());
            }

            
            try{
                newLead.Email = piste.email_from != 'false' ? piste.email_from : '';
            }
            catch(Exception e){
                System.debug('Error in Email / email_from: \'' + piste.email_from + '\' ==> ' + e.getMessage());
            }
           

            // add zip code to address
            try{
                newLead.PostalCode = piste.zip != 'false' ? piste.zip : '';
            }
            catch(Exception e){
                System.debug('Error in PostalCode / zip: \'' + piste.zip + '\' ==> ' + e.getMessage());
            }


            // check which model to use:
            // first model (Form):
            if(!String.isBlank(piste.lastName) && piste.lastName != 'false'){
                newLead.FirstName = piste.firstName;
                newLead.LastName = piste.lastName;
            } 
            // Second form
            else if (!String.isBlank(piste.display_name) && piste.display_name != 'false'){
                // newLead.FirstName = piste.firstName;
                newLead.LastName = piste.display_name;
                newLead.Title = piste.your_function;

                try{
                    newLead.Raison_sociale__c = piste.you_are != 'false' && piste.you_are != null && piste.you_are != '' ? piste.you_are : newLead.Raison_sociale__c;
                } catch(Exception e){
                    System.debug('Error in Raison_sociale__c / you_are: \'' + piste.you_are + '\' ==> ' + e.getMessage());
                }

                try{
                    newLead.TravauxSouhaites__c = piste.desired_works != 'false' ? piste.desired_works : '';
                } catch(Exception e){
                    System.debug('Error in TravauxSouhaites__c / desired_works: \'' + piste.desired_works + '\' ==> ' + e.getMessage());
                }
            }


            
            // check form_state to set Status:
            try{
                // newLead.StatutFormulaire__c = piste.form_state != 'false' ? (piste.form_state == 'Form not finished' ? 'FormulaireNonTermine' : piste.form_state == 'Form finished' ? 'FormulaireTermine' : null) : null;
                // change to If structure to avoid too long lines
                if(piste.form_state != 'false'){
                    if(piste.form_state == 'Formulaire non terminé'){
                        newLead.StatutFormulaire__c = 'FormulaireNonTermine';
                    } else if (piste.form_state == 'Formulaire terminé'){
                        newLead.StatutFormulaire__c = 'FormulaireTermine';
                    }   else {
                        newLead.StatutFormulaire__c = null;
                    }
                } else {
                    newLead.StatutFormulaire__c = null;
                }
            }
            catch(Exception e){
                System.debug('Error in StatutFormulaire__c / form_state: \'' + piste.form_state + '\' ==> ' + e.getMessage());
            }

            // Try parse nomber of bike if present
            try{
                newLead.VELO_Nb_de_v_los__c = Integer.valueOf(piste.nb_bike);
            }
            catch(Exception e){
                System.debug('Error in VELO_Nb_de_v_los__c / nb_bike: \'' + piste.nb_bike + '\' ==> ' + e.getMessage());
            }

            // Try parse nomber of employees if present
            try{
                newLead.VELO_Nb_de_salari_s__c = Integer.valueOf(piste.nb_employee);
            }
            catch(Exception e){
                System.debug('Error in VELO_Nb_de_salari_s__c / nb_employee: \'' + piste.nb_employee + '\' ==> ' + e.getMessage());
            }

            try{
                newLead.TelephoneContact__c = piste.phone_delivery != 'false' ? piste.phone_delivery : '';
            }
            catch(Exception e){
                System.debug('Error in TelephoneContact__c / phone_delivery: \'' + piste.phone_delivery + '\' ==> ' + e.getMessage());
            }

            // Address details
            try{
                newLead.Street = piste.street != 'false' ? piste.street : '';
            }
            catch(Exception e){
                System.debug('Error in Street / street: \'' + piste.street + '\' ==> ' + e.getMessage());
            }

            try{
                newLead.City = piste.city != 'false' ? piste.city : '';
            }
            catch(Exception e){
                System.debug('Error in City / city: \'' + piste.city + '\' ==> ' + e.getMessage());
            }

            try{
                newLead.ComplementAdresse__c = piste.street2 != 'false' ? piste.street2 : '';
            }
            catch(Exception e){
                System.debug('Error in ComplementAdresse__c / street2: \'' + piste.street2 + '\' ==> ' + e.getMessage());
            }

            try{
                newLead.Raison_sociale__c = piste.raison_sociale != 'false' && piste.raison_sociale != null && piste.raison_sociale != '' ? piste.raison_sociale : newLead.Raison_sociale__c;
            } catch(Exception e){
                System.debug('Error in Raison_sociale__c / raison_sociale: \'' + piste.raison_sociale + '\' ==> ' + e.getMessage());
            }

            try{
                newLead.SIRET__c = piste.siret != 'false' && piste.siret != null && piste.siret != '' ? piste.siret : newLead.SIRET__c;
            } catch(Exception e){
                System.debug('Error in SIRET__c / siret: \'' + piste.siret + '\' ==> ' + e.getMessage());
            }


            // add zip code to address
            try{
                // Parse to :
                newLead.Surface_d_tenu__c = Integer.valueOf(piste.x_studio_surface_clairer);
            }
            catch(Exception e){
                System.debug('Error in Surface_d_tenu__c / x_studio_surface_clairer: \'' + piste.x_studio_surface_clairer + '\' ==> ' + e.getMessage());
            }

            // add zip code to address
            try{
                newLead.DATA_PRO_Secteur_d_activit__c = piste.x_studio_secteur_dactivit != 'false' ? piste.x_studio_secteur_dactivit : '';
            }
            catch(Exception e){
                System.debug('Error in DATA_PRO_Secteur_d_activit__c / x_studio_secteur_dactivit: \'' + piste.x_studio_secteur_dactivit + '\' ==> ' + e.getMessage());
            }


            // Mode chauffage : 
             try{
                newLead.Mode_de_chauffage_Formulaire__c = piste.x_lgr_energy != 'false' ? piste.x_lgr_energy : '';
            }
            catch(Exception e){
                System.debug('Error in Mode_de_chauffage_Formulaire__c / x_lgr_energy: \'' + piste.x_lgr_energy + '\' ==> ' + e.getMessage());
            }

            // RecordType for type d'enregistrement:
            try{
                RecordType rt = [SELECT Id FROM RecordType WHERE DeveloperName = :piste.x_lgr_type_enregistrement AND SObjectType = 'Lead' LIMIT 1];
                newLead.RecordTypeId = rt.Id;
            }
            catch(Exception e){
                System.debug('Error in RecordTypeId / x_lgr_type_enregistrement: \'' + piste.x_lgr_type_enregistrement + '\' ==> ' + e.getMessage());
            }

            // Lead source for type d'origine de piste: 
             try{
                newLead.LeadSource = piste.x_lgr_origine_piste != 'false' ? piste.x_lgr_origine_piste : '';
            }
            catch(Exception e){
                System.debug('Error in LeadSource / x_lgr_origine_piste: \'' + piste.x_lgr_origine_piste + '\' ==> ' + e.getMessage());
            }

            // Type de dossier
             try{
                newLead.TypeDeDossier__c = piste.x_lgr_type_dossier != 'false' ? piste.x_lgr_type_dossier : '';
            }
            catch(Exception e){
                System.debug('Error in TypeDeDossier__c / x_lgr_type_dossier: \'' + piste.x_lgr_type_dossier + '\' ==> ' + e.getMessage());
            }
          
            


            // Add attribution:
            newLead.OwnerId = Label.LeadsAttribution;
            
            if(!Test.isRunningTest()) {
                insert newLead;
            }
            
            Response resBody = new Response();
            resBody.success = true;
            // res.token = token;
            resBody.newpiste = newLead;
            resBody.reqPiste = piste;
            
            // Set the response code to success (200)
            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(resBody));
            
            
            // return res;
        } catch (Exception e) {
            // // Retourner une erreur
            // Response res = new Response();
            // res.success = false;
            // res.error = e.getMessage();
            // // return res;
            
            // Set the response code to error (405)
            res.statusCode = 405;
            res.responseBody = Blob.valueOf(e.getMessage());
        }
    }
    
    global  class PayloadPiste {
        public String firstname;
        public String lastName;
        public String phone_sanitized;
        public String property_type;
        public String website_name;
        public String heating_type;
        public String zip;
        public String x_lgr_energy;
        public String x_lgr_origine_piste;
        public String x_lgr_type_dossier;
        public String x_lgr_type_enregistrement;

        public String desired_works;
        public String display_name;
        public String your_function;
        public String you_are;
        public String email_from;
        public String raison_social;
        public String raison_sociale;

        public String form_state; // nouveau champs
        public String nb_bike; // nouveau champs
        public String nb_employee;
        public String phone_delivery; // nouveau champs
        public String street;
        public String street2; // nouveau champs
        public String city;
        public String country;

        public String siret;

        public String x_studio_secteur_dactivit;
        public String x_studio_surface_clairer;

    }
    
    global  class Response {
        global Boolean success;
        global String error;
        global String leadId;
        public PayloadPiste reqPiste;
        public Lead newpiste;
        public String token;
    }
}