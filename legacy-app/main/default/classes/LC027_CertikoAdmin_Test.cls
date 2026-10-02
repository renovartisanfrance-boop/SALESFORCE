/**
 * LC027_CertikoAdmin_Test — tableau de bord Certiko des administrateurs.
 *
 * CE QUE CET ÉCRAN APPORTE en plus de la console Certiko, c'est le
 * RAPPROCHEMENT : la console montre les comptes, elle ne sait pas quel
 * pré-visiteur Salesforce n'en a pas, ni lequel a glissé dans une autre
 * équipe. C'est donc ce rapprochement que ces tests gardent — les appels
 * pass-through vers LC027_CertikoComptes sont vérifiés ailleurs.
 *
 * DEUX ÉCARTS, et le second est le plus coûteux : un compte qui existe mais
 * dans une autre équipe que celle enregistrée chez nous envoie ses dossiers à
 * la mauvaise équipe, sans aucun message d'erreur.
 */
@isTest
private class LC027_CertikoAdmin_Test {

    private static final String EQUIPE_ID  = 'f03c9643-e6e0-4bbc-9dc2-69baf86c234c';
    private static final String AUTRE_ID   = 'aaaaaaaa-e6e0-4bbc-9dc2-69baf86c234c';
    private static final String USER_ID    = '7b1e0d42-0000-4000-8000-000000000042';
    private static final String EMAIL_PREV = 'test.previsiteur@example.es';

    /** Corps de la DERNIÈRE requête partie vers Certiko. */
    private static String corpsEnvoye;

    /**
     * Répond à tout : titulaire de la clé, équipes, comptes, écritures.
     * `equipeDuCompte` décide de l'équipe rendue pour le compte — c'est le
     * levier des tests de désynchronisation.
     */
    private class Bouchon implements HttpCalloutMock {
        private String equipeDuCompte;
        private String emailDuCompte;
        private Bouchon(String equipeDuCompte, String emailDuCompte) {
            this.equipeDuCompte = equipeDuCompte;
            this.emailDuCompte = emailDuCompte;
        }
        public HttpResponse respond(HttpRequest req) {
            corpsEnvoye = req.getBody();
            String url = req.getEndpoint();
            HttpResponse rep = new HttpResponse();
            rep.setStatusCode(200);
            rep.setHeader('Content-Type', 'application/json');

            if (url.endsWith('/poseur')) {
                rep.setBody('{"id":"p1","name":"ECONATURA","equipes_count":1}');
            } else if (url.contains('/equipes')) {
                rep.setBody(req.getMethod() == 'GET'
                    ? '{"items":[' + equipeJson() + ']}'
                    : equipeJson());
            } else {
                rep.setBody(req.getMethod() == 'GET'
                    ? '{"items":[' + compteJson() + ']}'
                    : compteJson());
            }
            return rep;
        }
        private String equipeJson() {
            return '{"id":"' + EQUIPE_ID + '","name":"Equipo Test Previsiteur"'
                + ',"is_active":true,"members_count":1}';
        }
        private String compteJson() {
            return '{"id":"' + USER_ID + '","email":"' + emailDuCompte + '"'
                + ',"equipe_id":"' + equipeDuCompte + '","is_active":true}';
        }
    }

    private class BouchonMuet implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse rep = new HttpResponse();
            rep.setStatusCode(401);
            rep.setBody('{"error":{"code":"cle","message":"refusee"}}');
            return rep;
        }
    }

    private static void bouchonner(String equipeDuCompte, String emailDuCompte) {
        Test.setMock(HttpCalloutMock.class, new Bouchon(equipeDuCompte, emailDuCompte));
    }

    private static Campaign campagneSignee(String token) {
        return LC027_TestFactory.previsiteur(token, LC027_GestionContrat.STATUT_SIGNE, true);
    }

    private static LC027_CertikoAdmin.Previsiteur previsiteurDe(
            LC027_CertikoAdmin.Tableau t, Id campagneId) {
        for (LC027_CertikoAdmin.Previsiteur p : t.previsiteurs) {
            if (p.campagneId == campagneId) return p;
        }
        return null;
    }

    /* ════════════════════════ Le rapprochement ════════════════════════ */

    /**
     * LE PREMIER ÉCART — contrat signé, aucun compte chez Certiko. C'est la
     * seule chose que la console Certiko ne peut pas montrer.
     */
    @isTest
    static void contratSigneSansCompteRemonteCommeEcart() {
        Campaign c = campagneSignee('token-sans-compte');
        // Le compte rendu par Certiko porte un AUTRE email : aucun
        // rapprochement possible avec cette campagne.
        bouchonner(EQUIPE_ID, 'quelquun.dautre@example.es');

        Test.startTest();
        LC027_CertikoAdmin.Tableau t = LC027_CertikoAdmin.getTableau(false);
        Test.stopTest();

        LC027_CertikoAdmin.Previsiteur p = previsiteurDe(t, c.Id);
        Assert.isNotNull(p, 'Un contrat signe doit figurer dans le rapprochement.');
        Assert.areEqual(false, p.compteVerifie,
            'Un identifiant stocke chez nous ne prouve pas que le compte existe chez eux.');
        Assert.areEqual(false, p.equipeDesynchronisee,
            'Sans compte, il n y a pas d equipe a desynchroniser.');
        Assert.areEqual('ECONATURA', t.poseur.nom);
    }

    /** Compte présent des deux côtés, même équipe : aucun écart. */
    @isTest
    static void compteAJourNeRemontePasCommeEcart() {
        Campaign c = campagneSignee('token-a-jour');
        update new Campaign(Id = c.Id,
            CERTIKO_Login__c = EMAIL_PREV, CERTIKO_Equipe_Id__c = EQUIPE_ID);
        bouchonner(EQUIPE_ID, EMAIL_PREV);

        Test.startTest();
        LC027_CertikoAdmin.Tableau t = LC027_CertikoAdmin.getTableau(false);
        Test.stopTest();

        LC027_CertikoAdmin.Previsiteur p = previsiteurDe(t, c.Id);
        Assert.areEqual(true, p.compteVerifie);
        Assert.areEqual(false, p.equipeDesynchronisee);
        Assert.areEqual(EQUIPE_ID, p.certikoEquipeId);
    }

    /**
     * L'ÉCART QUI COÛTE CHER — le compte existe, mais dans une autre équipe
     * que celle enregistrée chez nous. Ses dossiers partiraient à la mauvaise
     * équipe et Certiko ne dirait rien : l'identifiant est valide, il est
     * simplement le mauvais. Arrive dès qu'on déplace un compte depuis leur
     * console.
     */
    @isTest
    static void equipeChangeeChezCertikoRemonteCommeEcart() {
        Campaign c = campagneSignee('token-desync');
        update new Campaign(Id = c.Id,
            CERTIKO_Login__c = EMAIL_PREV, CERTIKO_Equipe_Id__c = EQUIPE_ID);
        bouchonner(AUTRE_ID, EMAIL_PREV);

        Test.startTest();
        LC027_CertikoAdmin.Tableau t = LC027_CertikoAdmin.getTableau(false);
        Test.stopTest();

        LC027_CertikoAdmin.Previsiteur p = previsiteurDe(t, c.Id);
        Assert.areEqual(true, p.compteVerifie, 'Le compte existe bien.');
        Assert.areEqual(true, p.equipeDesynchronisee,
            'Mais plus dans l equipe que nous avons enregistree.');
    }

    /**
     * Un compte ouvert AVANT l'arrivée du champ n'a pas d'identifiant
     * d'équipe : il remonte comme écart, et c'est voulu — c'est ainsi que le
     * rattrapage se voit sur l'écran.
     */
    @isTest
    static void compteSansIdentifiantDEquipeRemonteCommeEcart() {
        Campaign c = campagneSignee('token-sans-id-equipe');
        update new Campaign(Id = c.Id, CERTIKO_Login__c = EMAIL_PREV);
        bouchonner(EQUIPE_ID, EMAIL_PREV);

        Test.startTest();
        LC027_CertikoAdmin.Tableau t = LC027_CertikoAdmin.getTableau(false);
        Test.stopTest();

        Assert.areEqual(true, previsiteurDe(t, c.Id).equipeDesynchronisee);
    }

    /** À défaut de login enregistré, l'email de la campagne sert de clé. */
    @isTest
    static void lEmailDeLaCampagneSertDeCleQuandLeLoginManque() {
        Campaign c = campagneSignee('token-sans-login');
        bouchonner(EQUIPE_ID, EMAIL_PREV);

        Test.startTest();
        LC027_CertikoAdmin.Tableau t = LC027_CertikoAdmin.getTableau(false);
        Test.stopTest();

        Assert.areEqual(true, previsiteurDe(t, c.Id).compteVerifie);
    }

    /**
     * Un contrat EN ATTENTE n'a pas encore de compte, ce n'est pas une
     * anomalie : il n'a rien à faire dans la liste des écarts.
     */
    @isTest
    static void contratNonSigneNestPasUnEcart() {
        Campaign c = LC027_TestFactory.previsiteur('token-en-attente');
        bouchonner(EQUIPE_ID, EMAIL_PREV);

        Test.startTest();
        LC027_CertikoAdmin.Tableau t = LC027_CertikoAdmin.getTableau(false);
        Test.stopTest();

        Assert.isNull(previsiteurDe(t, c.Id),
            'Un contrat en attente n a pas a figurer dans le rapprochement.');
    }

    /** Clé refusée : l'écran doit le dire, pas afficher un tableau vide. */
    @isTest
    static void cleRefuseeRemonteAuComposant() {
        Test.setMock(HttpCalloutMock.class, new BouchonMuet());

        Test.startTest();
        try {
            LC027_CertikoAdmin.getTableau(false);
            Assert.fail('Une cle refusee doit lever.');
        } catch (AuraHandledException e) {
            Assert.areEqual('CERTIKO_CLE_REFUSEE', e.getMessage());
        }
        Test.stopTest();
    }

    /* ════════════════════════ Le déplacement d'équipe ════════════════════════ */

    /**
     * DÉPLACER UN COMPTE DEPUIS CET ÉCRAN met la campagne à jour — sinon les
     * dossiers du pré-visiteur continueraient de partir à son ancienne équipe,
     * et la ligne remonterait en écart au chargement suivant.
     */
    @isTest
    static void deplacementDEquipeSuitSurLaCampagne() {
        Campaign c = campagneSignee('token-deplacement');
        update new Campaign(Id = c.Id,
            CERTIKO_Login__c = EMAIL_PREV, CERTIKO_Equipe_Id__c = EQUIPE_ID);
        bouchonner(AUTRE_ID, EMAIL_PREV);

        Test.startTest();
        LC027_CertikoAdmin.majCompte(EMAIL_PREV, null, 'Equipo Autre', null);
        Test.stopTest();

        Campaign apres = [SELECT CERTIKO_Equipe__c, CERTIKO_Equipe_Id__c
                          FROM Campaign WHERE Id = :c.Id];
        Assert.areEqual('Equipo Autre', apres.CERTIKO_Equipe__c);
        Assert.areEqual(AUTRE_ID, apres.CERTIKO_Equipe_Id__c,
            'L identifiant suit : c est lui qui part dans _equipe_poseur.');
    }

    /**
     * Réinitialiser un mot de passe ne touche à AUCUNE équipe : la campagne
     * ne doit pas bouger.
     */
    @isTest
    static void reinitialisationDeMotDePasseNeTouchePasALEquipe() {
        Campaign c = campagneSignee('token-mdp');
        update new Campaign(Id = c.Id,
            CERTIKO_Login__c = EMAIL_PREV, CERTIKO_Equipe_Id__c = EQUIPE_ID);
        bouchonner(AUTRE_ID, EMAIL_PREV);

        Test.startTest();
        LC027_CertikoAdmin.majCompte(EMAIL_PREV, '0123456789', null, null);
        Test.stopTest();

        Assert.areEqual(EQUIPE_ID,
            [SELECT CERTIKO_Equipe_Id__c FROM Campaign WHERE Id = :c.Id].CERTIKO_Equipe_Id__c);
    }

    /**
     * Un compte Certiko sans équivalent chez nous se déplace quand même :
     * l'administrateur ne doit pas voir son geste échouer parce que le
     * rapprochement ne trouve rien.
     */
    @isTest
    static void compteSansCampagneSeDeplaceSansLever() {
        bouchonner(AUTRE_ID, 'inconnu@example.es');

        Test.startTest();
        LC027_CertikoComptes.Membre m =
            LC027_CertikoAdmin.majCompte('inconnu@example.es', null, 'Equipo Autre', null);
        Test.stopTest();

        Assert.areEqual(AUTRE_ID, m.equipeId);
    }

    /* ════════════════════════ La reprise manuelle ════════════════════════ */

    /**
     * OUVRIR UN COMPTE À LA MAIN — ce que la signature aurait dû faire pour
     * les contrats déjà signés au moment du déploiement. Appel DIRECT et non
     * par la file : l'administrateur attend une réponse à l'écran.
     */
    @isTest
    static void reprendreLOuvertureRemplitLaCampagne() {
        Campaign c = campagneSignee('token-reprise');
        bouchonner(EQUIPE_ID, EMAIL_PREV);

        Test.startTest();
        LC027_CertikoAdmin.Previsiteur p = LC027_CertikoAdmin.ouvrirCompte(c.Id);
        Test.stopTest();

        Assert.areEqual(USER_ID, p.certikoUserId);
        Assert.areEqual(EQUIPE_ID, p.certikoEquipeId);
        Assert.areEqual(true, p.compteVerifie);
        Campaign apres = [SELECT CERTIKO_User_Id__c, CERTIKO_Equipe_Id__c, CERTIKO_Compte_Erreur__c
                          FROM Campaign WHERE Id = :c.Id];
        Assert.areEqual(USER_ID, apres.CERTIKO_User_Id__c);
        Assert.areEqual(EQUIPE_ID, apres.CERTIKO_Equipe_Id__c);
        Assert.isNull(apres.CERTIKO_Compte_Erreur__c);
    }

    @isTest
    static void repriseSurUneCampagneInconnueEstRefusee() {
        Test.startTest();
        try {
            LC027_CertikoAdmin.ouvrirCompte(
                [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()].Id);
            Assert.fail('Un Id qui n est pas une campagne doit lever.');
        } catch (Exception e) {
            Assert.isTrue(e.getMessage().contains('CAMPAGNE_INTROUVABLE')
                || e.getMessage().contains('Invalid id'), e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void repriseSurUnRoleAutreQuePrevisiteurEstRefusee() {
        Campaign c = LC027_TestFactory.installateur('token-inst-reprise');

        Test.startTest();
        try {
            LC027_CertikoAdmin.ouvrirCompte(c.Id);
            Assert.fail('Seul un pre-visiteur a un compte Certiko.');
        } catch (AuraHandledException e) {
            Assert.areEqual('PAS_UN_PREVISITEUR', e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void repriseSansEmailEstRefusee() {
        Campaign c = campagneSignee('token-reprise-sans-email');
        update new Campaign(Id = c.Id, Email__c = null);

        Test.startTest();
        try {
            LC027_CertikoAdmin.ouvrirCompte(c.Id);
            Assert.fail('Sans email, aucun compte n est possible.');
        } catch (AuraHandledException e) {
            Assert.areEqual('EMAIL_MANQUANT', e.getMessage());
        }
        Test.stopTest();
    }

    /**
     * Une reprise qui échoue chez Certiko laisse sa trace sur la campagne ET
     * remonte à l'écran : sans les deux, l'administrateur réessaierait sans
     * savoir pourquoi ça ne passe pas.
     */
    @isTest
    static void repriseEnEchecLaisseUneTraceEtRemonte() {
        Campaign c = campagneSignee('token-reprise-echec');
        Test.setMock(HttpCalloutMock.class, new BouchonMuet());

        Test.startTest();
        try {
            LC027_CertikoAdmin.ouvrirCompte(c.Id);
            Assert.fail('Un refus de Certiko doit remonter.');
        } catch (AuraHandledException e) {
            Assert.areEqual('CERTIKO_CLE_REFUSEE', e.getMessage());
        }
        Test.stopTest();

        Assert.isNotNull(
            [SELECT CERTIKO_Compte_Erreur__c FROM Campaign WHERE Id = :c.Id].CERTIKO_Compte_Erreur__c,
            'L echec doit rester lisible dans l ecran d administration.');
    }

    /* ════════════════════════ Les relais vers l'API ════════════════════════ */

    /** Les quatre relais rendent ce que l'API rend, et traduisent ses refus. */
    @isTest
    static void lesRelaisRendentEtTraduisent() {
        bouchonner(EQUIPE_ID, EMAIL_PREV);

        Test.startTest();
        Assert.areEqual(EQUIPE_ID, LC027_CertikoAdmin.creerEquipe('Equipo Test').id);
        Assert.areEqual(EQUIPE_ID, LC027_CertikoAdmin.majEquipe(EQUIPE_ID, 'Equipo Neuf', true).id);
        Assert.areEqual(USER_ID, LC027_CertikoAdmin.creerCompte(
            EMAIL_PREV, '0123456789', 'Jose', 'Fernandez', 'Equipo Test', null).id);
        Test.stopTest();
    }

    @isTest
    static void unRefusDeLApiDevientUneErreurLisible() {
        Test.setMock(HttpCalloutMock.class, new BouchonMuet());

        Test.startTest();
        for (Integer i = 0; i < 3; i++) {
            try {
                if (i == 0) LC027_CertikoAdmin.creerEquipe('Equipo Test');
                if (i == 1) LC027_CertikoAdmin.majEquipe(EQUIPE_ID, 'Neuf', null);
                if (i == 2) LC027_CertikoAdmin.creerCompte(
                    EMAIL_PREV, '0123456789', 'Jose', 'Fernandez', 'Equipo Test', null);
                Assert.fail('Le relais ' + i + ' doit lever.');
            } catch (AuraHandledException e) {
                Assert.areEqual('CERTIKO_CLE_REFUSEE', e.getMessage());
            }
        }
        Test.stopTest();
    }
}