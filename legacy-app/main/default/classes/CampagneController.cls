/**
 * CampagneController — API REST publique de création de campagne REGIE.
 *
 * Appelée par un site externe (PHP, tunnel « cee-apporteurs ») pour créer une
 * campagne REGIE et son Compte associé. S'inspire de OdooController (patron REST)
 * et de la logique de LC020_GestionCampagnes.createCampaign, mais volontairement
 * simplifiée :
 *   - les champs « standards » sont codés en dur (EstREGIE, Status, IsActive…) ;
 *   - pas de gestion de campagne parente ;
 *   - pas d'email, pas d'appel externe (le payload n'a ni mot de passe ni creerAcces).
 *
 * Endpoint : POST /services/apexrest/campagne/?secret=<CAMPAGNE_API_TOKEN>
 *
 * Body JSON attendu :
 * {
 *   "nom": "Dupont",
 *   "prenom": "Jean",
 *   "email": "jean@example.com",
 *   "telephone": "0612345678",
 *   "fiche": "RESIDENTIEL_REGIES_-_TH171",
 *   "acces_reduit": true,
 *   "source": "cee-apporteurs"
 * }
 *
 * Réponses :
 *   - Succès (200) : { "success": true, "redirect_url": "..." }
 *   - Erreur (400 / 401 / 409 / 500) : { "error": "message à afficher à l'utilisateur" }
 */
@RestResource(urlMapping='/campagne/*')
global without sharing class CampagneController {

    public static final String API_SECRET = Label.CAMPAGNE_API_TOKEN;

    @HttpPost
    global static void createCampaignFromSite() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        if (res == null) {
            res = new RestResponse();
            RestContext.response = res;
        }
        res.addHeader('Content-Type', 'application/json; charset=UTF-8');

        // 1. Authentification : secret partagé passé en paramètre d'URL (2e couche applicative).
        String secret = (req != null && req.params != null) ? req.params.get('secret') : null;
        if (String.isBlank(secret) || secret != API_SECRET) {
            res.statusCode = 401;
            res.responseBody = errorBody('Accès non autorisé.');
            return;
        }

        try {
            // 2. Désérialisation du corps de la requête.
            String body = (req != null && req.requestBody != null) ? req.requestBody.toString() : '';
            if (String.isBlank(body)) {
                res.statusCode = 400;
                res.responseBody = errorBody('Corps de requête vide.');
                return;
            }

            PayloadCampagne data;
            try {
                data = (PayloadCampagne) JSON.deserialize(body, PayloadCampagne.class);
            } catch (Exception parseEx) {
                res.statusCode = 400;
                res.responseBody = errorBody('JSON invalide.');
                return;
            }

            // 3. Validations minimales.
            if (data == null || String.isBlank(data.email)) {
                res.statusCode = 400;
                res.responseBody = errorBody('Le champ email est obligatoire.');
                return;
            }
            if (String.isBlank(data.nom) && String.isBlank(data.prenom)) {
                res.statusCode = 400;
                res.responseBody = errorBody('Le nom ou le prénom est obligatoire.');
                return;
            }

            // 4. Email déjà présent ? -> 2 branches (aucun 409) :
            //    - PARTENAIRE (AccesReduit__c=true ET Source__c contient 'cee-apporteurs') :
            //        on lui renvoie son accès par email et on affiche un message "déjà membre".
            //    - REGIE (EstREGIE__c=true, non partenaire) : on renvoie un statut de redirection
            //        vers la page de connexion (gérée côté front), SANS envoyer d'email.
            List<Campaign> existing = [
                SELECT Id, Email__c, EstREGIE__c, AccesReduit__c, Source__c
                FROM Campaign
                WHERE Email__c = :data.email AND EstREGIE__c = true
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            if (!existing.isEmpty()) {
                Campaign existante = existing[0];
                Boolean isPartenaire = existante.AccesReduit__c == true
                    && existante.Source__c != null
                    && existante.Source__c.contains('cee-apporteurs');

                if (isPartenaire) {
                    // Renvoi de l'accès (best-effort : ne doit jamais faire échouer la réponse).
                    try {
                        LC020_EmailService.sendCampaignEmail(existante.Id, existante.Email__c, '');
                    } catch (Exception emailEx) {
                        System.debug('⚠️ Renvoi accès partenaire échoué (non bloquant) : ' + emailEx.getMessage());
                    }
                    res.statusCode = 200;
                    res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                        'success' => true,
                        'status'  => 'already_partner',
                        'message' => 'Vous êtes déjà membre. Nous venons de vous renvoyer votre accès par email.'
                    }));
                    return;
                } else {
                    // REGIE existante : le front redirige vers la page de connexion. Pas d'email.
                    res.statusCode = 200;
                    res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                        'success' => true,
                        'status'  => 'existing_regie'
                    }));
                    return;
                }
            }

            // 5. Construction de la campagne.
            Campaign newCampaign = new Campaign();

            // get owner :
            List<User> defaultOwner = [
                SELECT Id FROM User
                WHERE GestionnairePartenairesCEEApporteurs__c = true
                LIMIT 1
            ];

            if (!defaultOwner.isEmpty()) {
                newCampaign.OwnerId = defaultOwner[0].Id;
            }

            // -- Champs « standards » (codés en dur, non reçus de l'API) --
            newCampaign.EstREGIE__c = true;
            newCampaign.Status = 'In Progress';
            newCampaign.StartDate = System.today();
            newCampaign.IsActive = true;
            newCampaign.AvoirAccesCEE__c = false;
            newCampaign.ParentId = null;
            newCampaign.PeutCreerREGIE__c = false;

            // -- Champs issus de l'API --
            String nom = String.isNotBlank(data.nom) ? data.nom.trim() : '';
            String prenom = String.isNotBlank(data.prenom) ? data.prenom.trim() : '';
            newCampaign.Name = (nom + ' ' + prenom).trim();
            newCampaign.Email__c = data.email;
            if (String.isNotBlank(data.telephone)) {
                newCampaign.Telephone__c = data.telephone;
            }
            if (String.isNotBlank(data.fiche)) {
                newCampaign.ProduitsDisponibles__c = data.fiche;
            }
            newCampaign.AccesReduit__c = (data.acces_reduit == true);
            if (String.isNotBlank(data.source)) {
                newCampaign.Source__c = data.source;
            }

            // -- Champs additionnels (ads_source) --
            if (String.isNotBlank(data.ads_source)) {
                newCampaign.CanalPublicitaire__c = data.ads_source;
            }

            // -- Champs additionnels (canal) --
            if (String.isNotBlank(data.canal)) {
                newCampaign.CanalPublicitaire__c = data.canal;
            }

            // -- Jeton d'accès unique --
            newCampaign.CampaignToken__c = generateUniqueToken();

            // -- Pays (optionnel) --
            if (String.isNotBlank(data.pays)) {
                newCampaign.Pays__c = data.pays;
            }

            // 6. Insertion.
            insert newCampaign;

            // 7. Création automatique d'un Compte (RT « Client ») lié à la campagne.
            createAccountForCampaign(newCampaign, data.email, data.telephone);

            // 7.2 Notification email — best-effort OBLIGATOIRE : l'envoi ne doit JAMAIS faire
            //     échouer la création (la campagne est déjà insérée). sendCampaignEmail lève une
            //     AuraHandledException en cas d'erreur interne (template/OWA introuvable, etc.),
            //     or ce type est interdit hors contexte Aura/VF => System.LimitException => 500.
            //     On l'isole donc ici.
            try {
                LC020_EmailService.sendCampaignEmail(newCampaign.Id, newCampaign.Email__c, '');
            } catch (Exception emailEx) {
                System.debug('⚠️ Envoi email campagne échoué (non bloquant) : ' + emailEx.getMessage());
            }

            // 8. Réponse de succès : le front redirige vers redirect_url.
            String redirectUrl = Label.RENOV_Campagne_Base_URL + '?c__code=' + newCampaign.CampaignToken__c;
            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                'success'      => true,
                'status'       => 'created',
                'redirect_url' => redirectUrl
            }));

        } catch (DmlException e) {
            // Valeurs invalides (picklist « fiche » / « source »), règles de validation, etc.
            String msg = e.getNumDml() > 0 ? e.getDmlMessage(0) : e.getMessage();
            res.statusCode = 400;
            res.responseBody = errorBody('Erreur lors de la création : ' + msg);
        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = errorBody('Erreur serveur : ' + e.getMessage());
        }
    }

    // ------------------------------------------------------------------ Helpers

    private static Blob errorBody(String message) {
        return Blob.valueOf(JSON.serialize(new Map<String, Object>{ 'error' => message }));
    }

    private static String generateUniqueToken() {
        String token = '';
        Boolean isUnique = false;
        while (!isUnique) {
            token = generateRandomString(32);
            List<Campaign> existing = [SELECT Id FROM Campaign WHERE CampaignToken__c = :token LIMIT 1];
            if (existing.isEmpty()) {
                isUnique = true;
            }
        }
        return token;
    }

    private static String generateRandomString(Integer length) {
        String characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
        String randomString = '';
        for (Integer i = 0; i < length; i++) {
            Integer randomIndex = Math.mod(Math.abs(Crypto.getRandomInteger()), characters.length());
            randomString += characters.substring(randomIndex, randomIndex + 1);
        }
        return randomString;
    }

    /**
     * Crée un Compte (RecordType « Client ») lié à la campagne via Acces_REGIE__c.
     * Repris de LC020_GestionCampagnes. Les erreurs sont loggées mais ne bloquent
     * pas la réponse (le compte peut être recréé manuellement si besoin).
     */
    private static void createAccountForCampaign(Campaign camp, String email, String telephone) {
        try {
            Id clientRtId = null;
            List<RecordType> rts = [
                SELECT Id FROM RecordType
                WHERE SObjectType = 'Account' AND DeveloperName = 'Client'
                LIMIT 1
            ];
            if (!rts.isEmpty()) {
                clientRtId = rts[0].Id;
            }

            Account compte = new Account();
            compte.Name = 'REGIE- ' + camp.Name;
            compte.Type_Intervenant__c = 'Régie';
            if (clientRtId != null) {
                compte.RecordTypeId = clientRtId;
            }
            compte.Acces_REGIE__c = camp.Id;
            if (String.isNotBlank(telephone)) {
                compte.Phone = telephone;
            }

            insert compte;
        } catch (Exception e) {
            System.debug('⚠️ Erreur création Compte pour campagne ' + camp.Id + ' : ' + e.getMessage());
        }
    }

    // --------------------------------------------------------------------- DTO

    global class PayloadCampagne {
        public String nom;
        public String prenom;
        public String email;
        public String telephone;
        public String fiche;
        public Boolean acces_reduit;
        public String source;
        public String ads_source;
        public String pays;
        public String canal;
    }
}