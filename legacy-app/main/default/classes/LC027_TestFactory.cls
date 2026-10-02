/**
 * LC027_TestFactory — jeux de données des tests du portail Gestion Prévisites.
 *
 * @isTest sans testMethod : la classe est exclue du décompte de couverture mais
 * reste appelable par les tests. Un utilitaire compté dans la couverture
 * gonflerait artificiellement le pourcentage de l'org.
 *
 * POURQUOI UNE FABRIQUE — les campagnes du portail doivent satisfaire plusieurs
 * conditions simultanées (rôle, token, actif, statut de contrat) pour être
 * seulement lisibles. Les recopier dans chaque test aurait garanti qu'un jour
 * l'une manque quelque part, et le test aurait échoué pour une raison sans
 * rapport avec ce qu'il vérifie.
 */
@isTest
public class LC027_TestFactory {

    /**
     * Bouchon d'appels sortants — À POSER AVANT TOUT DML.
     *
     * AccountTrigger (et les triggers Lead / Pro__c) émettent des appels
     * sortants : géocodage, SMS, synchronisation. Sans ce bouchon, la simple
     * insertion du Compte associé à une campagne fait échouer le test sur
     * « les méthodes de test ne prennent pas en charge les callouts » — l'erreur
     * ne désigne alors PAS le code testé, ce qui la rend très déroutante.
     *
     * Le corps dépend de l'endpoint : le géocodage nominatim désérialise en
     * LISTE, les autres appels attendent un objet. Un corps unique ferait
     * échouer l'un ou l'autre. Même procédé que LC021_DevisSignature_Test.
     */
    public class BouchonCallout implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest requete) {
            HttpResponse reponse = new HttpResponse();
            reponse.setStatusCode(200);
            reponse.setHeader('Content-Type', 'application/json');
            String endpoint = requete.getEndpoint();
            Boolean estGeocodage = endpoint != null && endpoint.contains('nominatim');
            reponse.setBody(estGeocodage ? '[]' : '{"success":true}');
            return reponse;
        }
    }

    /** À appeler en tête de chaque test qui déclenche du DML. */
    public static void bouchonnerCallouts() {
        Test.setMock(HttpCalloutMock.class, new BouchonCallout());
    }

    public static final String ROLE_PREVISITEUR  = 'Pre-visiteur';
    public static final String ROLE_INSTALLATEUR = 'Installateur';
    public static final String ROLE_REGIE        = 'Régie';

    /**
     * Campagne INSTALLATEUR active, contrat à remplir. Mêmes valeurs que
     * previsiteur() hormis le rôle et l'email : un test qui compare les deux
     * rôles ne doit mesurer QUE l'effet du rôle.
     */
    public static Campaign installateur(String token) {
        Campaign c = new Campaign(
            Name             = 'Test Installateur',
            IsActive         = true,
            Role__c          = ROLE_INSTALLATEUR,
            CampaignToken__c = token,
            StatutContrat__c = 'En cours de generation',
            Email__c         = 'test.installateur@example.es',
            Telephone__c     = '612345678',
            Pays__c          = 'Espagne'
        );
        insert c;
        return c;
    }

    /** Campagne pré-visiteur active, contrat à remplir. */
    public static Campaign previsiteur(String token) {
        return previsiteur(token, 'En cours de generation', true);
    }

    public static Campaign previsiteur(String token, String statutContrat, Boolean actif) {
        Campaign c = new Campaign(
            Name             = 'Test Previsiteur',
            IsActive         = actif,
            Role__c          = ROLE_PREVISITEUR,
            CampaignToken__c = token,
            StatutContrat__c = statutContrat,
            Email__c         = 'test.previsiteur@example.es',
            Telephone__c     = '612345678',
            Pays__c          = 'Espagne'
        );
        insert c;
        return c;
    }

    /** Campagne de RÔLE RÉGIE — sert à vérifier qu'elle est refusée par le portail. */
    public static Campaign regie(String token) {
        Campaign c = new Campaign(
            Name             = 'Test Regie',
            IsActive         = true,
            Role__c          = ROLE_REGIE,
            CampaignToken__c = token,
            Email__c         = 'test.regie@example.fr'
        );
        insert c;
        return c;
    }

    /** Corps JSON d'inscription d'un PRÉ-VISITEUR, tel que l'envoie le proxy PHP. */
    public static String payloadInscription(String email) {
        return payloadInscription(email, ROLE_PREVISITEUR);
    }

    /**
     * Corps JSON d'inscription pour un rôle donné.
     * @param role valeur de « role » ; null pour l'omettre du corps.
     */
    public static String payloadInscription(String email, String role) {
        Map<String, Object> corps = new Map<String, Object>{
            'nomComplet' => 'Maria Garcia',
            'societe'    => 'Garcia Instalaciones S.L.',
            'email'      => email,
            'telephone'  => '612345678',
            'source'     => 'cae-colaboradores',
            'ads_source' => 'facebook',
            'pays'       => 'Espagne'
        };
        if (role != null) {
            corps.put('role', role);
        }
        return JSON.serialize(corps);
    }

    /**
     * Prépare RestContext pour un appel à PrevisiteController.
     * @param secret valeur passée en paramètre d'URL ; null pour l'omettre.
     */
    public static void preparerRest(String corps, String secret) {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/previsite/';
        req.httpMethod = 'POST';
        if (corps != null) {
            req.requestBody = Blob.valueOf(corps);
        }
        if (secret != null) {
            req.params.put('secret', secret);
        }
        RestContext.request  = req;
        RestContext.response = new RestResponse();
    }

    /** Corps de la réponse REST, désérialisé. */
    public static Map<String, Object> reponse() {
        return (Map<String, Object>) JSON.deserializeUntyped(
            RestContext.response.responseBody.toString());
    }

    /** Réglages de signature, tels que les produit contratConfig.reglagesContrat(). */
    public static String reglagesSignature() {
        return JSON.serialize(new Map<String, Object>{
            'langue'         => 'es',
            'expediteur'     => 'ECONATURA',
            'champSignature' => '6|320|415|249|40',
            'champMention'   => null
        });
    }

    /** PDF minimal en base64 — le contenu n'est jamais lu par les tests. */
    public static String pdfFactice() {
        return EncodingUtil.base64Encode(Blob.valueOf('%PDF-1.4 test'));
    }
}