/**
 * Tests de LC027_GestionPrevisites — contrôle d'accès du portail.
 *
 * L'ORDRE des contrôles est vérifié explicitement : c'est une décision de
 * conception (rôle avant activation) qui déterminerait le message affiché à un
 * partenaire, et rien d'autre ne l'empêcherait de s'inverser à la première
 * refactorisation.
 */
@isTest
private class LC027_GestionPrevisites_Test {

    @isTest
    static void tokenVideRefuse() {
        Test.startTest();
        LC027_GestionPrevisites.ResultatAcces r =
            LC027_GestionPrevisites.getPrevisiteurByToken('');
        Test.stopTest();

        System.assertEquals('TOKEN_MANQUANT', r.statut);
        System.assertEquals(null, r.previsiteur, 'Aucune donnée ne doit fuir sur un refus.');
    }

    @isTest
    static void tokenNullRefuse() {
        LC027_GestionPrevisites.ResultatAcces r =
            LC027_GestionPrevisites.getPrevisiteurByToken(null);
        System.assertEquals('TOKEN_MANQUANT', r.statut);
    }

    @isTest
    static void tokenInconnuRefuse() {
        Test.startTest();
        LC027_GestionPrevisites.ResultatAcces r =
            LC027_GestionPrevisites.getPrevisiteurByToken('token-qui-n-existe-pas');
        Test.stopTest();

        System.assertEquals('INTROUVABLE', r.statut);
        System.assertEquals(null, r.previsiteur);
    }

    @isTest
    static void roleRegieRefuse() {
        LC027_TestFactory.regie('token-regie');

        Test.startTest();
        LC027_GestionPrevisites.ResultatAcces r =
            LC027_GestionPrevisites.getPrevisiteurByToken('token-regie');
        Test.stopTest();

        System.assertEquals('ROLE_INVALIDE', r.statut);
        System.assertEquals(null, r.previsiteur);
    }

    /** L'installateur entre sur le MÊME portail, avec son rôle. */
    @isTest
    static void installateurAccepte() {
        LC027_TestFactory.installateur('token-installateur');

        Test.startTest();
        LC027_GestionPrevisites.ResultatAcces r =
            LC027_GestionPrevisites.getPrevisiteurByToken('token-installateur');
        Test.stopTest();

        System.assertEquals('OK', r.statut);
        System.assertEquals('Installateur', r.previsiteur.Role__c,
            'Le rôle doit remonter : il choisit les écrans du portail.');
    }

    @isTest
    static void campagneDesactiveeRefuse() {
        LC027_TestFactory.previsiteur('token-inactif', 'En cours de generation', false);

        Test.startTest();
        LC027_GestionPrevisites.ResultatAcces r =
            LC027_GestionPrevisites.getPrevisiteurByToken('token-inactif');
        Test.stopTest();

        System.assertEquals('DESACTIVE', r.statut);
    }

    /**
     * Rôle ET activation en défaut : c'est le RÔLE qui l'emporte. Dire
     * « votre compte est désactivé » à une régie lui laisserait croire qu'elle a
     * sa place sur ce portail.
     */
    @isTest
    static void roleInvalidePrimeSurDesactivation() {
        Campaign regie = LC027_TestFactory.regie('token-cumul');
        regie.IsActive = false;
        update regie;

        Test.startTest();
        LC027_GestionPrevisites.ResultatAcces r =
            LC027_GestionPrevisites.getPrevisiteurByToken('token-cumul');
        Test.stopTest();

        System.assertEquals('ROLE_INVALIDE', r.statut,
            'Le rôle doit être contrôlé avant l\'activation.');
    }

    @isTest
    static void accesAccordeRemonteLaCampagne() {
        Campaign c = LC027_TestFactory.previsiteur('token-ok');

        Test.startTest();
        LC027_GestionPrevisites.ResultatAcces r =
            LC027_GestionPrevisites.getPrevisiteurByToken('token-ok');
        Test.stopTest();

        System.assertEquals('OK', r.statut);
        System.assertNotEquals(null, r.previsiteur);
        System.assertEquals(c.Id, r.previsiteur.Id);
        System.assertEquals('En cours de generation', r.previsiteur.StatutContrat__c,
            'Le statut de contrat pilote l\'aiguillage du conteneur : il doit remonter.');

        // La trace de connexion n'est posée que sur un accès réellement accordé.
        System.assertNotEquals(null,
            [SELECT DateDerniereConnexion__c FROM Campaign WHERE Id = :c.Id].DateDerniereConnexion__c);
    }

    /** Un accès refusé ne doit PAS alimenter la date de dernière connexion. */
    @isTest
    static void accesRefuseNAlimentePasLaTrace() {
        Campaign c = LC027_TestFactory.regie('token-refus');

        Test.startTest();
        LC027_GestionPrevisites.getPrevisiteurByToken('token-refus');
        Test.stopTest();

        System.assertEquals(null,
            [SELECT DateDerniereConnexion__c FROM Campaign WHERE Id = :c.Id].DateDerniereConnexion__c,
            'Un token révoqué ne doit pas continuer d\'alimenter la trace de connexion.');
    }
}