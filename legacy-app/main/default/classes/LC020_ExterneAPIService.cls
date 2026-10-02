/**
 * LC020_ExterneAPIService - Service d'intégration avec le système externe
 * Envoie les accès utilisateurs (campagnes) vers l'API externe via POST
 *
 * Format JSON envoyé :
 * {
 *     "users": [
 *         {
 *             "login": "nom-utilisateur",
 *             "email": "email@example.com",
 *             "password": "motdepasse",
 *             "redirect_url": "https://..."
 *         }
 *     ]
 * }
 *
 * Custom Labels requis :
 *   - EXTERNE_API_ENDPOINT : URL de l'API POST (ex: https://api.monservice.com/users)
 *   - EXTERNE_API_TOKEN    : Token d'autorisation (laisser vide si non requis)
 */
public without sharing class LC020_ExterneAPIService {

    private static final String PASSWORD = 'SECRET_RETIRE_DU_DEPOT_VOIR_ORG';

    public class Result {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String  message;

        public Result(Boolean success, String message) {
            this.success = success;
            this.message = message;
        }
    }

    /**
     * Déclenche la réinitialisation du mot de passe d'un utilisateur via l'API externe.
     * Appelle POST /forgot_password.php avec le champ email en form-data.
     *
     * @param email  Adresse email de l'utilisateur dont le mot de passe doit être réinitialisé
     */
    @AuraEnabled
    public static Result reinitialiserMotDePasse(String email) {
        try {
            String endpoint = Label.GESTION_RDV_EXTERNE_API_ENDPOINT + '/forgot_password.php';

            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            req.setTimeout(30000);
            req.setBody('email=' + EncodingUtil.urlEncode(email, 'UTF-8'));

            Http http = new Http();
            HttpResponse res = http.send(req);

            Integer statusCode = res.getStatusCode();
            System.debug('LC020_ExterneAPIService.reinitialiserMotDePasse: Code=' + statusCode + ' | Corps=' + res.getBody());

            if (statusCode != 200 && statusCode != 201) {
                return new Result(false, 'Erreur lors de la réinitialisation du mot de passe (code ' + statusCode + ').');
            }

            return new Result(true, null);

        } catch (Exception e) {
            System.debug('LC020_ExterneAPIService.reinitialiserMotDePasse: Exception: ' + e.getMessage());
            return new Result(false, 'Erreur lors de la réinitialisation du mot de passe : ' + e.getMessage());
        }
    }

    /**
     * Envoie les données d'accès d'un utilisateur (campagne) vers le système externe.
     * Méthode asynchrone @future pour permettre le callout après un DML.
     *
     * @param login       Identifiant de connexion (nom de la campagne)
     * @param email       Email de l'utilisateur
     * @param password    Mot de passe choisi
     * @param redirectUrl URL de redirection après connexion (lien de la campagne)
     */
    /**
     * Change l'adresse email d'un utilisateur via l'API externe.
     * Appelle POST /api/change_email.php avec oldEmail et newEmail en JSON.
     *
     * @param oldEmail  Ancienne adresse email
     * @param newEmail  Nouvelle adresse email
     */
    @AuraEnabled
    public static Result changerEmail(String oldEmail, String newEmail) {
        try {
            String endpoint = Label.GESTION_RDV_EXTERNE_API_ENDPOINT + '/api/change_email.php';

            Map<String, Object> bodyMap = new Map<String, Object>{
                'oldEmail' => oldEmail,
                'newEmail' => newEmail
            };

            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(30000);
            req.setBody(JSON.serialize(bodyMap));

            Http http = new Http();
            HttpResponse res = http.send(req);

            Integer statusCode = res.getStatusCode();
            System.debug('LC020_ExterneAPIService.changerEmail: Code=' + statusCode + ' | Corps=' + res.getBody());

            if (statusCode == 200) {
                return new Result(true, null);
            }

            // Extraire le message d'erreur du corps de la réponse
            String errorMessage;
            if (statusCode == 404) {
                errorMessage = 'Aucun compte trouvé pour l\'adresse email ' + oldEmail + '.';
            } else if (statusCode == 409) {
                errorMessage = 'L\'adresse email ' + newEmail + ' est déjà utilisée.';
            } else {
                errorMessage = 'Erreur lors du changement d\'email (code ' + statusCode + ').';
            }

            try {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                if (responseMap.containsKey('message') && responseMap.get('message') != null) {
                    errorMessage = (String) responseMap.get('message');
                }
            } catch (Exception parseEx) {
                System.debug('LC020_ExterneAPIService.changerEmail: Erreur parsing réponse: ' + parseEx.getMessage());
            }

            return new Result(false, errorMessage);

        } catch (Exception e) {
            System.debug('LC020_ExterneAPIService.changerEmail: Exception: ' + e.getMessage() + ' | ' + e.getStackTraceString());
            return new Result(false, 'Erreur lors du changement d\'email : ' + e.getMessage());
        }
    }

    /**
     * Change la redirect_url d'un utilisateur via l'API externe.
     * Appelle POST /api/change_redirect_url.php avec email et redirect_url en JSON.
     *
     * @param email        Adresse email de l'utilisateur
     * @param redirectUrl  Nouvelle URL de redirection
     */
    @AuraEnabled
    public static Result changerRedirectURL(String email, String redirectUrl, String login) {
        try {
            String endpoint = Label.GESTION_RDV_EXTERNE_API_ENDPOINT + '/api/change_redirect_url.php';

            Map<String, Object> bodyMap = new Map<String, Object>{
                'login'        => login,
                'password'     => PASSWORD,
                'email'        => email,
                'redirect_url' => redirectUrl,
                'createIfNotExists' => true
            };

            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(30000);
            req.setBody(JSON.serialize(bodyMap));

            Http http = new Http();
            HttpResponse res = http.send(req);

            Integer statusCode = res.getStatusCode();
            System.debug('LC020_ExterneAPIService.changerRedirectURL: Code=' + statusCode + ' | Corps=' + res.getBody());

            if (statusCode == 200 || statusCode == 201) {
                return new Result(true, null);
            }

            // Extraire le message d'erreur du corps de la réponse
            String errorMessage;
            if (statusCode == 404) {
                errorMessage = 'Aucun utilisateur trouvé pour l\'adresse email ' + email + '.';
            } else if (statusCode == 405) {
                errorMessage = 'Méthode non autorisée.';
            } else {
                errorMessage = 'Erreur lors du changement de redirect URL (code ' + statusCode + ').';
            }

            try {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                if (responseMap.containsKey('error') && responseMap.get('error') != null) {
                    errorMessage = (String) responseMap.get('error');
                }
            } catch (Exception parseEx) {
                System.debug('LC020_ExterneAPIService.changerRedirectURL: Erreur parsing réponse: ' + parseEx.getMessage());
            }

            return new Result(false, errorMessage);

        } catch (Exception e) {
            System.debug('LC020_ExterneAPIService.changerRedirectURL: Exception: ' + e.getMessage() + ' | ' + e.getStackTraceString());
            return new Result(false, 'Erreur lors du changement de redirect URL : ' + e.getMessage());
        }
    }

    public static Result envoyerAccesUtilisateur(String login, String email, String password, String redirectUrl) {
        try {
            String endpoint = Label.GESTION_RDV_EXTERNE_API_ENDPOINT + '/api/add_users.php';

            // Construire l'objet user
            Map<String, Object> userMap = new Map<String, Object>{
                'login'        => login,
                'email'        => email,
                'password'     => password,
                'redirect_url' => redirectUrl
            };

            // Construire le body complet
            Map<String, Object> bodyMap = new Map<String, Object>{
                'users' => new List<Object>{ userMap }
            };

            String requestBody = JSON.serialize(bodyMap);

            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(30000);

            // Ajouter le token d'autorisation si configuré
            // String token = Label.GESTION_RDV_EXTERNE_API_TOKEN;
            // if (String.isNotBlank(token)) {
            //     req.setHeader('Authorization', 'Bearer ' + token);
            // }

            req.setBody(requestBody);

            Http http = new Http();
            HttpResponse res = http.send(req);

            Integer statusCode = res.getStatusCode();
            if (statusCode == 200 || statusCode == 201) {
                System.debug('LC020_ExterneAPIService: Accès utilisateur envoyé avec succès. Réponse: ' + res.getBody());
                return new Result(true, null);
            } else if (statusCode == 400) {
                String errorMessage = 'Erreur lors de la création de l\'accès utilisateur.';
                try {
                    System.debug('Result > ' + res.getBody());
                    Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    List<Object> errors = (List<Object>) responseMap.get('errors');
                    System.debug('Errors > ' + errors);
                    if (errors != null && !errors.isEmpty()) {
                        Map<String, Object> firstError = (Map<String, Object>) errors.get(0);
                        System.debug('First Error > ' + firstError);
                        if (firstError.containsKey('message')) {
                            errorMessage = (String) firstError.get('message');
                        }
                    }
                } catch (Exception parseEx) {
                    System.debug('LC020_ExterneAPIService: Erreur parsing réponse 400: ' + parseEx.getMessage());
                }
                return new Result(false, errorMessage);
            } else {
                System.debug('LC020_ExterneAPIService: Erreur API externe. Code: ' + statusCode + ' | Corps: ' + res.getBody());
                return new Result(false, res.getBody());
            }

        } catch (Exception e) {
            System.debug('LC020_ExterneAPIService: Exception lors de l\'appel API externe: ' + e.getMessage() + ' | ' + e.getStackTraceString());
            return new Result(false, e.getMessage());
        }
    }
}