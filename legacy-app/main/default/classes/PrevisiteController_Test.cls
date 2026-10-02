/**
 * Tests de PrevisiteController — API REST d'inscription des pré-visiteurs.
 *
 * Couvre les quatre issues de l'endpoint : refus d'authentification, refus de
 * validation, inscription déjà existante, création complète.
 *
 * L'ENVOI D'EMAIL est volontairement laissé s'exécuter : le contrôleur l'isole
 * dans un try/catch et le test vérifie justement que son échec (aucun template
 * en contexte de test) ne fait PAS échouer la création. C'est le comportement le
 * plus important de la méthode — une campagne créée puis perdue parce que le
 * mail n'est pas parti serait le pire des défauts.
 */
@isTest
private class PrevisiteController_Test {

    private static String secret() {
        return Label.PREVISITE_API_TOKEN;
    }

    @isTest
    static void secretInvalideRefuse() {
        LC027_TestFactory.bouchonnerCallouts();
        LC027_TestFactory.preparerRest(
            LC027_TestFactory.payloadInscription('a@b.es'), 'mauvais-secret');

        Test.startTest();
        PrevisiteController.createPrevisiteurFromSite();
        Test.stopTest();

        System.assertEquals(401, RestContext.response.statusCode,
            'Un secret erroné doit être refusé avant toute lecture du corps.');
        System.assertEquals(0, [SELECT COUNT() FROM Campaign],
            'Aucune campagne ne doit être créée sur un refus d\'authentification.');
    }

    @isTest
    static void secretAbsentRefuse() {
        LC027_TestFactory.bouchonnerCallouts();
        LC027_TestFactory.preparerRest(
            LC027_TestFactory.payloadInscription('a@b.es'), null);

        Test.startTest();
        PrevisiteController.createPrevisiteurFromSite();
        Test.stopTest();

        System.assertEquals(401, RestContext.response.statusCode);
    }

    @isTest
    static void corpsVideRefuse() {
        LC027_TestFactory.bouchonnerCallouts();
        LC027_TestFactory.preparerRest(null, secret());

        Test.startTest();
        PrevisiteController.createPrevisiteurFromSite();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }

    @isTest
    static void jsonInvalideRefuse() {
        LC027_TestFactory.bouchonnerCallouts();
        LC027_TestFactory.preparerRest('{ceci n est pas du json', secret());

        Test.startTest();
        PrevisiteController.createPrevisiteurFromSite();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }

    /**
     * Un booléen transmis en CHAÎNE casse la désérialisation entière. C'est le
     * piège du contrat côté PHP : le test le fige pour qu'une évolution du DTO
     * ne le transforme pas silencieusement en 500.
     */
    @isTest
    static void booleenEnChaineRefuse() {
        LC027_TestFactory.bouchonnerCallouts();
        LC027_TestFactory.preparerRest(
            '{"email":"a@b.es","nomComplet":"X","acces_reduit":"true"}', secret());

        Test.startTest();
        PrevisiteController.createPrevisiteurFromSite();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode,
            'Un booléen en chaîne doit produire un 400 explicite, pas un 500.');
    }

    @isTest
    static void emailManquantRefuse() {
        LC027_TestFactory.bouchonnerCallouts();
        LC027_TestFactory.preparerRest('{"nomComplet":"Maria Garcia"}', secret());

        Test.startTest();
        PrevisiteController.createPrevisiteurFromSite();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }

    @isTest
    static void nomCompletManquantRefuse() {
        LC027_TestFactory.bouchonnerCallouts();
        LC027_TestFactory.preparerRest('{"email":"a@b.es"}', secret());

        Test.startTest();
        PrevisiteController.createPrevisiteurFromSite();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }

    /**
     * La société est FACULTATIVE : un autónomo n'en a pas. Son absence ne doit
     * pas empêcher l'inscription.
     */
    @isTest
    static void societeFacultative() {
        LC027_TestFactory.bouchonnerCallouts();
        LC027_TestFactory.preparerRest(
            '{"nomComplet":"Maria Garcia","email":"autonomo@example.es","source":"cae-colaboradores","role":"Pre-visiteur"}',
            secret());

        Test.startTest();
        PrevisiteController.createPrevisiteurFromSite();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Campaign c = [SELECT Name, NomSociete__c FROM Campaign LIMIT 1];
        System.assertEquals('Maria Garcia', c.Name);
        System.assertEquals(null, c.NomSociete__c);
    }

    /** Le cas nominal : campagne créée, compte associé, statut de contrat amorcé. */
    @isTest
    static void inscriptionCreeCampagneEtCompte() {
        LC027_TestFactory.bouchonnerCallouts();
        LC027_TestFactory.preparerRest(
            LC027_TestFactory.payloadInscription('maria@example.es'), secret());

        Test.startTest();
        PrevisiteController.createPrevisiteurFromSite();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> rep = LC027_TestFactory.reponse();
        System.assertEquals(true, rep.get('success'));
        System.assertEquals('created', rep.get('status'));
        System.assert(String.valueOf(rep.get('redirect_url')).contains('?c__code='),
            'La réponse doit porter le lien d\'accès au portail.');

        Campaign c = [
            SELECT Name, NomSociete__c, Role__c, StatutContrat__c, EstREGIE__c, AccesReduit__c,
                   ProduitsDisponibles__c, Source__c, CanalPublicitaire__c,
                   Pays__c, CampaignToken__c, IsActive
            FROM Campaign LIMIT 1
        ];
        System.assertEquals('Maria Garcia', c.Name,
            'Le nom arrive en UN champ : aucune recomposition prénom + nom.');
        System.assertEquals('Garcia Instalaciones S.L.', c.NomSociete__c);
        System.assertEquals('Pre-visiteur', c.Role__c);
        System.assertEquals('En cours de generation', c.StatutContrat__c,
            'Le contrat doit démarrer son cycle dès l\'inscription.');
        System.assertEquals(false, c.EstREGIE__c,
            'EstREGIE__c faux : c\'est ce qui tient les pré-visiteurs hors des écrans régie.');
        System.assertEquals(null, c.ProduitsDisponibles__c,
            'Les produits restent vides — le catalogue prévisiteur n\'est pas défini.');
        System.assertEquals('cae-colaboradores', c.Source__c);
        System.assertEquals('facebook', c.CanalPublicitaire__c);
        System.assertEquals('Espagne', c.Pays__c);
        System.assertEquals(32, c.CampaignToken__c.length(), 'Le token fait 32 caractères.');

        List<Account> comptes = [
            SELECT Name, Type_Intervenant__c, Acces_REGIE__c FROM Account
        ];
        System.assertEquals(1, comptes.size(), 'Un compte doit être créé avec la campagne.');
        System.assertEquals('Pre-visiteur', comptes[0].Type_Intervenant__c);
        System.assertEquals(c.Id, comptes[0].Acces_REGIE__c);
    }

    /**
     * Une seconde inscription du même email ne crée PAS de doublon : elle renvoie
     * l'accès. Le statut « already_partner » est celui que le front espagnol sait
     * déjà traiter — un statut inédit tomberait dans sa branche d'erreur.
     */
    @isTest
    static void inscriptionExistanteRenvoieAcces() {
        LC027_TestFactory.bouchonnerCallouts();
        LC027_TestFactory.previsiteur('token-existant');

        LC027_TestFactory.preparerRest(
            LC027_TestFactory.payloadInscription('test.previsiteur@example.es'), secret());

        Test.startTest();
        PrevisiteController.createPrevisiteurFromSite();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> rep = LC027_TestFactory.reponse();
        System.assertEquals('already_partner', rep.get('status'));
        System.assertEquals(1, [SELECT COUNT() FROM Campaign],
            'Aucun doublon ne doit être créé.');
    }

    /**
     * Le doublon se cherche sur l'EMAIL SEUL (choix métier) : un email déjà
     * porté par une régie bloque l'inscription comme pré-visiteur.
     */
    @isTest
    static void emailDejaRegieBloqueInscription() {
        LC027_TestFactory.bouchonnerCallouts();
        Campaign regie = LC027_TestFactory.regie('token-regie');
        regie.Email__c = 'partage@example.es';
        update regie;

        LC027_TestFactory.preparerRest(
            LC027_TestFactory.payloadInscription('partage@example.es'), secret());

        Test.startTest();
        PrevisiteController.createPrevisiteurFromSite();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        System.assertEquals('already_partner', LC027_TestFactory.reponse().get('status'));
        System.assertEquals(1, [SELECT COUNT() FROM Campaign],
            'Aucune campagne ne doit etre creee pour un email deja connu.');
    }

    /* ── Rôle : obligatoire, choisi par la page d'inscription ────────────── */

    /**
     * Sans « role », l'inscription est REFUSÉE : la même API sert deux pages,
     * et deviner le rôle créerait un installateur sur le contrat de prévisites
     * (ou l'inverse).
     */
    @isTest
    static void roleManquantRefuse() {
        LC027_TestFactory.bouchonnerCallouts();
        LC027_TestFactory.preparerRest(
            LC027_TestFactory.payloadInscription('sansrole@example.es', null), secret());

        Test.startTest();
        PrevisiteController.createPrevisiteurFromSite();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        System.assert(RestContext.response.responseBody.toString().contains('role'),
            'Le refus doit nommer le champ manquant.');
        System.assertEquals(0, [SELECT COUNT() FROM Campaign]);
    }

    /** Un rôle hors portail (une Régie) ne peut pas être créé par cette API. */
    @isTest
    static void roleHorsPortailRefuse() {
        LC027_TestFactory.bouchonnerCallouts();
        LC027_TestFactory.preparerRest(
            LC027_TestFactory.payloadInscription('regie@example.es', LC027_TestFactory.ROLE_REGIE),
            secret());

        Test.startTest();
        PrevisiteController.createPrevisiteurFromSite();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        System.assertEquals(0, [SELECT COUNT() FROM Campaign]);
    }

    /** Installateur : même création, rôle et compte portés par le payload. */
    @isTest
    static void inscriptionInstallateur() {
        LC027_TestFactory.bouchonnerCallouts();
        LC027_TestFactory.preparerRest(
            LC027_TestFactory.payloadInscription('pedro@example.es', LC027_TestFactory.ROLE_INSTALLATEUR),
            secret());

        Test.startTest();
        PrevisiteController.createPrevisiteurFromSite();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        System.assertEquals('created', LC027_TestFactory.reponse().get('status'));

        Campaign c = [SELECT Role__c, StatutContrat__c, EstREGIE__c FROM Campaign LIMIT 1];
        System.assertEquals('Installateur', c.Role__c);
        System.assertEquals('En cours de generation', c.StatutContrat__c);
        System.assertEquals(false, c.EstREGIE__c);

        Account compte = [SELECT Name, Type_Intervenant__c FROM Account LIMIT 1];
        System.assertEquals('Installateur', compte.Type_Intervenant__c);
        System.assert(compte.Name.startsWith('INSTALLATEUR- '), compte.Name);
    }

    /**
     * Le doublon se cherche sur l'EMAIL SEUL : un prévisiteur déjà inscrit ne
     * peut PAS s'inscrire comme installateur avec le même email.
     */
    @isTest
    static void previsiteurNePeutPasSInscrireInstallateur() {
        LC027_TestFactory.bouchonnerCallouts();
        LC027_TestFactory.previsiteur('token-double-role');

        LC027_TestFactory.preparerRest(
            LC027_TestFactory.payloadInscription('test.previsiteur@example.es',
                LC027_TestFactory.ROLE_INSTALLATEUR), secret());

        Test.startTest();
        PrevisiteController.createPrevisiteurFromSite();
        Test.stopTest();

        System.assertEquals('already_partner', LC027_TestFactory.reponse().get('status'));
        System.assertEquals(0, [SELECT COUNT() FROM Campaign WHERE Role__c = 'Installateur']);
    }
}