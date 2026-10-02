/**
 * AdresseGouvController — proxy Apex vers la Base Adresse Nationale (BAN).
 *
 * Endpoint : https://api-adresse.data.gouv.fr/search/ — service public gratuit,
 * aucune clé d'API requise. Remote Site Setting nécessaire : Api_Adresse_Data_Gouv.
 *
 * On passe par Apex plutôt que par un fetch() navigateur pour que l'autocomplétion
 * fonctionne à l'identique dans l'org interne ET dans la community (rdvFicheParent
 * cible lightningCommunity__Page, où la CSP d'Experience Cloud bloquerait l'appel).
 *
 * cacheable=true est compatible avec un callout (la seule restriction porte sur le
 * DML) : cf. Planification_Controller.getDurations. Bonus pour un type-ahead, une
 * requête déjà saisie est resservie depuis le cache client sans re-frapper l'API.
 *
 * Aucun accès SObject : le mot-clé de partage est sans effet fonctionnel ici.
 */
public with sharing class AdresseGouvController {

    private static final String  BASE_URL   = 'https://api-adresse.data.gouv.fr/search/';
    private static final Integer MIN_CHARS  = 3;
    private static final Integer LIMITE     = 8;
    private static final Integer TIMEOUT_MS = 10000;

    /** Une suggestion d'adresse, déjà découpée en sous-champs prêts à écrire sur le Lead. */
    public class Suggestion {
        @AuraEnabled public String  id;
        @AuraEnabled public String  label;       // « 8 Boulevard du Port 80000 Amiens »
        @AuraEnabled public String  street;      // properties.name  → Lead.Street
        @AuraEnabled public String  postalCode;  // properties.postcode
        @AuraEnabled public String  city;        // properties.city
        @AuraEnabled public String  country;     // toujours « France »
        @AuraEnabled public String  citycode;    // code INSEE
        @AuraEnabled public String  typeAdresse; // housenumber | street | locality | municipality
        @AuraEnabled public Decimal latitude;
        @AuraEnabled public Decimal longitude;
    }

    /**
     * Recherche d'adresses françaises pour l'autocomplétion.
     *
     * @param query saisie de l'utilisateur (moins de 3 caractères → aucun callout)
     * @return jusqu'à 8 suggestions ; liste vide si le service est indisponible
     *         ou ne renvoie rien (dégradation silencieuse : la fiche reste utilisable)
     */
    @AuraEnabled(cacheable=true)
    public static List<Suggestion> rechercherAdresse(String query) {
        List<Suggestion> resultats = new List<Suggestion>();

        // Court-circuit : l'API BAN ignore les requêtes trop courtes, inutile d'y aller.
        if (String.isBlank(query) || query.trim().length() < MIN_CHARS) {
            return resultats;
        }

        String url = BASE_URL
            + '?q='     + EncodingUtil.urlEncode(query.trim(), 'UTF-8')
            + '&limit=' + LIMITE
            + '&autocomplete=1';

        HttpRequest request = new HttpRequest();
        request.setEndpoint(url);
        request.setMethod('GET');
        request.setHeader('Accept', 'application/json');
        request.setTimeout(TIMEOUT_MS);

        HttpResponse response;
        try {
            response = new Http().send(request);
        } catch (Exception e) {
            throw new AuraHandledException('Service d\'adresses indisponible : ' + e.getMessage());
        }

        if (response.getStatusCode() != 200) {
            System.debug(LoggingLevel.WARN,
                'AdresseGouvController : HTTP ' + response.getStatusCode() + ' — ' + response.getBody());
            return resultats;
        }

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
        List<Object> features = (List<Object>) body.get('features');
        if (features == null) {
            return resultats;
        }

        for (Object rawFeature : features) {
            Map<String, Object> feature    = (Map<String, Object>) rawFeature;
            Map<String, Object> properties = (Map<String, Object>) feature.get('properties');
            if (properties == null) {
                continue;
            }

            Suggestion suggestion = new Suggestion();
            suggestion.id          = (String) properties.get('id');
            suggestion.label       = (String) properties.get('label');
            suggestion.postalCode  = (String) properties.get('postcode');
            suggestion.city        = (String) properties.get('city');
            suggestion.citycode    = (String) properties.get('citycode');
            suggestion.typeAdresse = (String) properties.get('type');
            suggestion.country     = 'France';

            // « name » vaut « n° + voie », sauf sur le type « municipality » où il
            // reprend le nom de la commune : ce n'est alors pas une rue.
            suggestion.street = (suggestion.typeAdresse == 'municipality')
                ? null
                : (String) properties.get('name');

            Map<String, Object> geometry = (Map<String, Object>) feature.get('geometry');
            if (geometry != null) {
                List<Object> coordinates = (List<Object>) geometry.get('coordinates'); // [lon, lat]
                if (coordinates != null && coordinates.size() >= 2) {
                    suggestion.longitude = toDecimal(coordinates[0]);
                    suggestion.latitude  = toDecimal(coordinates[1]);
                }
            }

            resultats.add(suggestion);
        }

        return resultats;
    }

    /** JSON.deserializeUntyped rend Double, Decimal ou Integer selon la valeur rencontrée. */
    private static Decimal toDecimal(Object value) {
        if (value == null)              { return null; }
        if (value instanceof Decimal)   { return (Decimal) value; }
        if (value instanceof Double)    { return Decimal.valueOf((Double) value); }
        if (value instanceof Integer)   { return Decimal.valueOf((Integer) value); }
        return null;
    }
}