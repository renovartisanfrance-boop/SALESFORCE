/**
 * PrevisiteController — API REST publique de création de campagne PRE-VISITEUR.
 *
 * Pendant de CampagneController pour le portail Gestion Prévisites. Classe
 * DEDIEE : rien n'est partagé avec CampagneController, dont la logique porte les
 * régies (EstREGIE__c, campagnes filles, produits, accès réduit). Les deux
 * endpoints doivent pouvoir évoluer sans se casser mutuellement.
 *
 * Appelée par le site PHP espagnol /version-es/previsitadore via son proxy
 * serveur api/previsitador_es.php (le secret ne transite jamais par le navigateur).
 *
 * Endpoint : POST /services/apexrest/previsite/?secret=<PREVISITE_API_TOKEN>
 *
 * Body JSON attendu :
 * {
 *   "nomComplet": "Maria Garcia",
 *   "societe": "Garcia Instalaciones S.L.",
 *   "email": "maria@example.es",
 *   "telephone": "612345678",
 *   "source": "cae-colaboradores",   // picklist RESTREINTE : seule valeur acceptee ici
 *   "ads_source": "facebook",     // optionnel
 *   "pays": "Espagne",
 *   "role": "Pre-visiteur"          // OBLIGATOIRE : Pre-visiteur | Installateur
 * }
 * La même API sert les deux pages d'inscription : seul « role » les distingue.
 * Les clés « fiche » et « acces_reduit » envoyées par le front sont ACCEPTEES mais
 * IGNOREES (voir PayloadPrevisite) : les produits restent vides pour l'instant et
 * l'accès réduit ne concerne pas ce portail.
 *
 * Réponses :
 *   - Création (200)        : { "success": true, "status": "created", "redirect_url": "..." }
 *   - Déjà inscrit (200)    : { "success": true, "status": "already_partner", "message": "..." }
 *   - Erreur (400/401/500)  : { "error": "message à afficher à l'utilisateur" }
 */
@RestResource(urlMapping='/previsite/*')
global without sharing class PrevisiteController {

    public static final String API_SECRET = Label.PREVISITE_API_TOKEN;

    // Le rôle vient désormais de la REQUÊTE : la même API sert la page des
    // pré-visiteurs et celle des installateurs. Les rôles admis sont définis dans
    // LC027_Roles, et nulle part ailleurs.

    @HttpPost
    global static void createPrevisiteurFromSite() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        if (res == null) {
            res = new RestResponse();
            RestContext.response = res;
        }
        res.addHeader('Content-Type', 'application/json; charset=UTF-8');

        // 1. Authentification : secret partagé passé en paramètre d'URL.
        String secret = (req != null && req.params != null) ? req.params.get('secret') : null;
        if (String.isBlank(secret) || secret != API_SECRET) {
            res.statusCode = 401;
            res.responseBody = errorBody('Accès non autorisé.');
            return;
        }

        try {
            // 2. Désérialisation.
            String body = (req != null && req.requestBody != null) ? req.requestBody.toString() : '';
            if (String.isBlank(body)) {
                res.statusCode = 400;
                res.responseBody = errorBody('Corps de requête vide.');
                return;
            }

            PayloadPrevisite data;
            try {
                data = (PayloadPrevisite) JSON.deserialize(body, PayloadPrevisite.class);
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
            if (String.isBlank(data.nomComplet)) {
                res.statusCode = 400;
                res.responseBody = errorBody('Le nom complet est obligatoire.');
                return;
            }
            // Rôle OBLIGATOIRE et limité aux rôles du portail. Pas de valeur par
            // défaut : une page qui oublierait de l'envoyer créerait des comptes
            // du mauvais rôle, erreur qui ne se verrait qu'à la première connexion.
            // Refuser tout de suite la rend visible dès le premier essai.
            String role = String.isBlank(data.role) ? null : data.role.trim();
            if (role == null) {
                res.statusCode = 400;
                res.responseBody = errorBody('Le champ role est obligatoire.');
                return;
            }
            if (!LC027_Roles.estRolePortail(role)) {
                res.statusCode = 400;
                res.responseBody = errorBody('Rôle non pris en charge : ' + role + '.');
                return;
            }

            // 4. Déjà inscrit ?
            //    Le doublon se cherche sur l'EMAIL SEUL, tous rôles confondus
            //    (choix métier) : un email déjà présent sur une campagne —
            //    pré-visiteur, installateur ou régie — bloque toute nouvelle
            //    inscription et renvoie « already_partner ». Pour une régie, le
            //    renvoi d'accès échoue (rôle hors portail) sans bloquer la réponse.
            List<Campaign> existing = [
                SELECT Id, Email__c, Role__c
                FROM Campaign
                WHERE Email__c = :data.email //AND Role__c = :role
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            if (!existing.isEmpty()) {
                // Renvoi de l'accès (best-effort : ne doit jamais faire échouer la réponse).
                try {
                    LC027_EmailServicePrevisite.sendPrevisiteEmail(existing[0].Id);
                } catch (Exception emailEx) {
                    System.debug(LoggingLevel.WARN, 'Renvoi accès pré-visiteur échoué (non bloquant) : ' + emailEx.getMessage());
                }
                // Statut « already_partner » et non « already_previsiteur » : le front
                // espagnol existant ne connaît que created / already_partner /
                // existing_regie. Introduire un statut inédit le ferait tomber dans
                // sa branche d'erreur alors que le renvoi a réussi.
                res.statusCode = 200;
                res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                    'success' => true,
                    'status'  => 'already_partner',
                    'message' => 'Vous êtes déjà inscrit. Nous venons de vous renvoyer votre accès par email.'
                }));
                return;
            }

            // 5. Construction de la campagne.
            Campaign nouvelle = new Campaign();

            List<User> defaultOwner = [
                SELECT Id FROM User
                WHERE GestionnairePartenairesCEEApporteurs__c = true
                LIMIT 1
            ];
            if (!defaultOwner.isEmpty()) {
                nouvelle.OwnerId = defaultOwner[0].Id;
            }

            // -- Champs codés en dur --
            nouvelle.Role__c = role;
            // Le contrat démarre son cycle dès l'inscription : à sa première
            // connexion, le pré-visiteur tombe sur le formulaire d'identification.
            // Le champ reste VIDE pour toute campagne créée autrement (une Régie
            // n'a pas de contrat) — c'est ce qui permet au portail de distinguer
            // « pas de contrat » de « contrat à remplir ».
            nouvelle.StatutContrat__c = LC027_GestionContrat.STATUT_GENERATION;
            nouvelle.Status = 'In Progress';
            nouvelle.StartDate = System.today();
            nouvelle.IsActive = true;
            nouvelle.AvoirAccesCEE__c = false;
            nouvelle.ParentId = null;
            nouvelle.PeutCreerREGIE__c = false;
            // EstREGIE__c reste FAUX volontairement. C'est ce qui tient les deux
            // populations séparées : toutes les requêtes du portail Campagnes
            // filtrent sur EstREGIE__c = true, un pré-visiteur n'y apparaîtra donc
            // jamais. Le passer à true ferait remonter les pré-visiteurs dans les
            // écrans régie et dans le contrôle de doublon de CampagneController.

            // ProduitsDisponibles__c : volontairement NON renseigné. Le front envoie
            // bien une valeur « fiche », mais le catalogue produits du portail
            // Prévisites n'est pas defini — on ne recopie pas celui des régies.

            // AccesReduit__c : non renseigné. La notion est propre au portail
            // Campagnes (onglets restreints des partenaires) et n'a pas de sens ici.

            // -- Champs issus de l'API --
            // Le site envoie le nom en UN SEUL champ : on ne le recoupe pas en
            // prénom / nom. Un « María del Carmen García López » découpé sur les
            // espaces produirait un état civil faux sur un contrat qui engage.
            nouvelle.Name = data.nomComplet.trim();
            if (String.isNotBlank(data.societe)) {
                nouvelle.NomSociete__c = data.societe.trim();
            }
            nouvelle.Email__c = data.email;
            if (String.isNotBlank(data.telephone)) {
                nouvelle.Telephone__c = data.telephone;
            }
            if (String.isNotBlank(data.source)) {
                nouvelle.Source__c = data.source;
            }
            if (String.isNotBlank(data.ads_source)) {
                nouvelle.CanalPublicitaire__c = data.ads_source;
            }
            if (String.isNotBlank(data.pays)) {
                nouvelle.Pays__c = data.pays;
            }

            // -- Jeton d'accès unique (consommé par ?c__code= sur le portail) --
            nouvelle.CampaignToken__c = generateUniqueToken();

            // 6. Insertion.
            insert nouvelle;

            // 7. Compte associé, comme sur le portail Campagnes.
            createAccountForPrevisiteur(nouvelle, data.telephone, role);

            // 8. Notification email — best-effort OBLIGATOIRE : la campagne est déjà
            //    insérée, un échec d'envoi ne doit pas transformer une création
            //    réussie en 500 côté site.
            try {
                LC027_EmailServicePrevisite.sendPrevisiteEmail(nouvelle.Id);
            } catch (Exception emailEx) {
                System.debug(LoggingLevel.WARN, 'Envoi email pré-visiteur échoué (non bloquant) : ' + emailEx.getMessage());
            }

            // 9. Succès.
            String redirectUrl = Label.RENOV_Previsite_Base_URL + '?c__code=' + nouvelle.CampaignToken__c;
            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                'success'      => true,
                'status'       => 'created',
                'redirect_url' => redirectUrl
            }));

        } catch (DmlException e) {
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
     * Crée le Compte (RecordType « Client ») rattaché à la campagne via
     * Acces_REGIE__c — même mécanique que côté Campagnes, mais typé selon le
     * RÔLE reçu : Type_Intervenant__c = rôle (valeur du jeu global
     * Types_Intervenant), et préfixe de nom propre au rôle pour que les
     * populations restent lisibles dans la liste des comptes.
     *
     * Les erreurs sont loggées sans bloquer : la campagne est déjà créée et le
     * compte peut être recréé à la main.
     */
    private static void createAccountForPrevisiteur(Campaign camp, String telephone, String role) {
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
            String name = '';
            if(camp.Role__c == LC027_Roles.PREVISITEUR) {
                name = LC027_Roles.prefixeCompte(role) + camp.NomSociete__c;
            } else {
                name = LC027_Roles.prefixeCompte(role) + camp.Name;
            }
            compte.Name = name;
            compte.Type_Intervenant__c = role;
            if (clientRtId != null) {
                compte.RecordTypeId = clientRtId;
            }
            compte.Acces_REGIE__c = camp.Id;
            if (String.isNotBlank(telephone)) {
                compte.Phone = telephone;
            }

            insert compte;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Erreur création Compte pré-visiteur pour ' + camp.Id + ' : ' + e.getMessage());
        }
    }

    // --------------------------------------------------------------------- DTO

    /**
     * JSON.deserialize IGNORE les clés inconnues (vérifié sur l'org : seul
     * JSON.deserializeStrict les rejette). Les champs ci-dessous inutilisés
     * pourraient donc être supprimés sans casser l'appel ; ils sont conservés
     * pour documenter ce que le front envoie réellement.
     *
     * Le vrai piège du contrat est ailleurs : un booléen transmis en CHAINE
     * ("acces_reduit":"true" au lieu de true) fait échouer la désérialisation
     * entière — « Illegal value for boolean » — donc un 400 sur l'inscription.
     */
    global class PayloadPrevisite {
        /** Nom et prénoms en un seul champ, ou dénomination pour une société. */
        public String nomComplet;
        /** Raison sociale, facultative : un autónomo n'en a pas. */
        public String societe;
        public String email;
        public String telephone;
        public String source;
        public String ads_source;
        public String pays;
        public String fiche;          // ignoré
        public Boolean acces_reduit;  // ignoré
        /** OBLIGATOIRE : 'Pre-visiteur' ou 'Installateur' (voir LC027_Roles). */
        public String role;
        // Champs de traçage Meta relayés par le front : consommés par le proxy PHP,
        // jamais par Salesforce, mais présents dans le JSON reçu.
        public String event_id;
        public String event_source_url;
        public String fbp;
        public String fbc;
    }
}