/**
 * Service d'administration des utilisateurs du portail CEE Apporteurs (base MySQL IONOS).
 * Fait des callouts REST vers l'API PHP hébergée chez IONOS (api/salesforce/*) via le
 * Named Credential IONOS_Users_API, qui injecte l'en-tête X-API-Key automatiquement.
 *
 * Consommé par le LWC ionosUsersAdmin. Aucune donnée n'est persistée dans Salesforce.
 */
public with sharing class IonosUsersService {

    private static final String BASE_URL = 'https://www.cee-apporteurs.fr/api/salesforce';
    private static final String API_KEY = 'SECRET_RETIRE_DU_DEPOT_VOIR_ORG';
    private static final Integer TIMEOUT_MS = 30000;
    private static final Integer MAX_PAGE_SIZE = 100;

    /** Exception interne du domaine IONOS API (encapsulée en AuraHandledException en sortie). */
    public class IonosApiException extends Exception {}

    /** Représente un utilisateur du portail tel que renvoyé par l'API PHP. */
    public class UserDTO {
        @AuraEnabled public Integer id;
        @AuraEnabled public String login;
        @AuraEnabled public String email;
        @AuraEnabled public String redirectUrl;
        @AuraEnabled public Boolean firstLogin;
        @AuraEnabled public String createdAt;
        @AuraEnabled public String updatedAt;
    }

    /** Résultat paginé de la liste des utilisateurs. */
    public class UserListResult {
        @AuraEnabled public List<UserDTO> users;
        @AuraEnabled public Integer page;
        @AuraEnabled public Integer pageSize;
        @AuraEnabled public Integer total;
        @AuraEnabled public Integer totalPages;
    }

    /**
     * Liste paginée des utilisateurs, avec recherche facultative sur login/email.
     *
     * @param searchTerm Terme de recherche (login ou email), peut être vide
     * @param page Numéro de page (base 1)
     * @param pageSize Taille de page (1 à 100)
     * @return Le résultat paginé (utilisateurs + métadonnées de pagination)
     * @throws AuraHandledException si l'API est injoignable ou renvoie une erreur
     */
    @AuraEnabled
    public static UserListResult getUsers(String searchTerm, Integer page, Integer pageSize) {
        Integer safePage = (page == null || page < 1) ? 1 : page;
        Integer safePageSize = (pageSize == null || pageSize < 1) ? 25 : Math.min(pageSize, MAX_PAGE_SIZE);

        String query = '?page=' + safePage + '&page_size=' + safePageSize;
        if (String.isNotBlank(searchTerm)) {
            query += '&search=' + EncodingUtil.urlEncode(searchTerm.trim(), 'UTF-8');
        }

        Map<String, Object> body = callApi('GET', '/users_list.php' + query, null);

        UserListResult result = new UserListResult();
        result.page = toInteger(body.get('page'));
        result.pageSize = toInteger(body.get('page_size'));
        result.total = toInteger(body.get('total'));
        result.totalPages = toInteger(body.get('total_pages'));
        result.users = new List<UserDTO>();
        for (Object item : (List<Object>) body.get('users')) {
            result.users.add(toUserDTO((Map<String, Object>) item));
        }
        return result;
    }

    /**
     * Crée un utilisateur dans la base IONOS.
     *
     * @param login Identifiant (obligatoire)
     * @param email Email unique (obligatoire)
     * @param password Mot de passe initial (obligatoire)
     * @param redirectUrl URL de redirection après connexion (défaut "/")
     * @return L'utilisateur créé
     * @throws AuraHandledException si un champ est invalide ou l'email existe déjà
     */
    @AuraEnabled
    public static UserDTO createUser(String login, String email, String password, String redirectUrl) {
        if (String.isBlank(login) || String.isBlank(email) || String.isBlank(password)) {
            throw buildAuraException('Les champs login, email et mot de passe sont obligatoires.');
        }

        Map<String, Object> payload = new Map<String, Object>{
            'login'        => login.trim(),
            'email'        => email.trim(),
            'password'     => password,
            'redirect_url' => String.isBlank(redirectUrl) ? '/' : redirectUrl.trim()
        };

        Map<String, Object> body = callApi('POST', '/users_create.php', payload);
        return toUserDTO((Map<String, Object>) body.get('user'));
    }

    /**
     * Met à jour un utilisateur. Seuls les paramètres non nuls sont modifiés.
     *
     * @param userId Id de l'utilisateur (obligatoire)
     * @param login Nouveau login, ou null pour ne pas changer
     * @param email Nouvel email, ou null pour ne pas changer
     * @param password Nouveau mot de passe, ou null pour ne pas changer
     * @param redirectUrl Nouvelle URL de redirection, ou null pour ne pas changer
     * @param firstLogin Force le changement de mot de passe à la prochaine connexion, ou null
     * @return L'utilisateur mis à jour
     * @throws AuraHandledException si l'utilisateur n'existe pas ou l'email est déjà pris
     */
    @AuraEnabled
    public static UserDTO updateUser(Integer userId, String login, String email, String password,
                                     String redirectUrl, Boolean firstLogin) {
        if (userId == null || userId <= 0) {
            throw buildAuraException('Identifiant utilisateur invalide.');
        }

        Map<String, Object> payload = new Map<String, Object>{ 'id' => userId };
        if (login != null)       { payload.put('login', login.trim()); }
        if (email != null)       { payload.put('email', email.trim()); }
        if (String.isNotBlank(password)) { payload.put('password', password); }
        if (redirectUrl != null) { payload.put('redirect_url', redirectUrl.trim()); }
        if (firstLogin != null)  { payload.put('first_login', firstLogin ? 1 : 0); }

        if (payload.size() == 1) {
            throw buildAuraException('Aucun champ à mettre à jour.');
        }

        Map<String, Object> body = callApi('POST', '/users_update.php', payload);
        return toUserDTO((Map<String, Object>) body.get('user'));
    }

    /**
     * Supprime un utilisateur de la base IONOS.
     *
     * @param userId Id de l'utilisateur à supprimer
     * @throws AuraHandledException si l'utilisateur n'existe pas
     */
    @AuraEnabled
    public static void deleteUser(Integer userId) {
        if (userId == null || userId <= 0) {
            throw buildAuraException('Identifiant utilisateur invalide.');
        }
        callApi('POST', '/users_delete.php', new Map<String, Object>{ 'id' => userId });
    }

    /**
     * Teste la connectivité avec l'API IONOS.
     *
     * @return Le nombre total d'utilisateurs dans la base
     * @throws AuraHandledException si l'API ou la base est injoignable
     */
    @AuraEnabled
    public static Integer ping() {
        Map<String, Object> body = callApi('GET', '/ping.php', null);
        return toInteger(body.get('total_users'));
    }

    // ------------------------------------------------------------------
    // Plomberie HTTP
    // ------------------------------------------------------------------

    /**
     * Exécute un callout vers l'API IONOS et retourne le corps JSON désérialisé.
     * Les erreurs applicatives (4xx/5xx) remontent le message "error" renvoyé par le PHP.
     */
    private static Map<String, Object> callApi(String method, String path, Map<String, Object> payload) {
        HttpRequest request = new HttpRequest();
        request.setEndpoint(BASE_URL + path);
        request.setMethod(method);
        request.setTimeout(TIMEOUT_MS);
        request.setHeader('X-API-Key', API_KEY);
        if (payload != null) {
            request.setHeader('Content-Type', 'application/json; charset=utf-8');
            request.setBody(JSON.serialize(payload));
        }

        HttpResponse response;
        try {
            response = new Http().send(request);
        } catch (CalloutException e) {
            throw buildAuraException('API IONOS injoignable : ' + e.getMessage());
        }

        Map<String, Object> body = parseJsonBody(response.getBody());

        if (response.getStatusCode() >= 200 && response.getStatusCode() < 300) {
            return body;
        }

        String apiError = (body != null && body.get('error') instanceof String)
            ? (String) body.get('error')
            : 'Erreur API IONOS (HTTP ' + response.getStatusCode() + ').';
        throw buildAuraException(apiError);
    }

    /** Désérialise le corps JSON, ou null si le corps n'est pas un objet JSON valide. */
    private static Map<String, Object> parseJsonBody(String rawBody) {
        if (String.isBlank(rawBody)) {
            return null;
        }
        try {
            Object parsed = JSON.deserializeUntyped(rawBody);
            return (parsed instanceof Map<String, Object>) ? (Map<String, Object>) parsed : null;
        } catch (JSONException e) {
            return null;
        }
    }

    /** Convertit un objet JSON utilisateur (clés snake_case PHP) en UserDTO camelCase. */
    private static UserDTO toUserDTO(Map<String, Object> raw) {
        if (raw == null) {
            throw buildAuraException('Réponse inattendue de l\'API IONOS : utilisateur manquant.');
        }
        UserDTO dto = new UserDTO();
        dto.id = toInteger(raw.get('id'));
        dto.login = (String) raw.get('login');
        dto.email = (String) raw.get('email');
        dto.redirectUrl = (String) raw.get('redirect_url');
        dto.firstLogin = toInteger(raw.get('first_login')) == 1;
        dto.createdAt = (String) raw.get('created_at');
        dto.updatedAt = (String) raw.get('updated_at');
        return dto;
    }

    /** Convertit une valeur JSON numérique (Integer/Long/Decimal/String) en Integer. */
    private static Integer toInteger(Object value) {
        if (value == null) {
            return 0;
        }
        if (value instanceof Integer) {
            return (Integer) value;
        }
        if (value instanceof Long) {
            return ((Long) value).intValue();
        }
        if (value instanceof Decimal) {
            return ((Decimal) value).intValue();
        }
        return Integer.valueOf(String.valueOf(value));
    }

    /** Construit une AuraHandledException dont le message est lisible côté LWC et en test. */
    private static AuraHandledException buildAuraException(String message) {
        AuraHandledException auraException = new AuraHandledException(message);
        auraException.setMessage(message);
        return auraException;
    }
}