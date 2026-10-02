/**
 * LC027_CertikoCompteService_Test — ouverture du compte Certiko à la signature.
 *
 * CE QUI NE DOIT JAMAIS ARRIVER, et que ces tests gardent :
 *   • qu'un échec Certiko annule la signature — le contrat est un fait
 *     juridique, le compte un confort qui se rattrape ;
 *   • qu'une re-signature réinitialise le mot de passe affiché au
 *     pré-visiteur, ou crée un second compte ;
 *   • qu'un pré-visiteur refusé prive les autres de leur compte.
 *
 * LA FILE D'ATTENTE NE PART PAS EN TEST (ouvrirComptes rend la main tout de
 * suite quand Test.isRunningTest) : l'ouverture se vérifie donc directement
 * sur ouvrirPour, qui est @TestVisible pour cette raison.
 */
@isTest
private class LC027_CertikoCompteService_Test {

    private static final String EQUIPE_ID = 'f03c9643-e6e0-4bbc-9dc2-69baf86c234c';
    private static final String USER_ID   = '7b1e0d42-0000-4000-8000-000000000042';

    /** Corps de la DERNIÈRE création de compte partie chez Certiko. */
    private static String corpsCompte;

    /**
     * Répond à la séquence complète : création d'équipe, puis du compte. Le
     * chemin distingue les deux, l'ordre étant justement ce qu'on vérifie.
     */
    private class BouchonCertiko implements HttpCalloutMock {
        private Boolean equipeVue = false;
        public HttpResponse respond(HttpRequest req) {
            HttpResponse rep = new HttpResponse();
            rep.setHeader('Content-Type', 'application/json');
            if (req.getEndpoint().endsWith('/equipes')) {
                equipeVue = true;
                rep.setStatusCode(201);
                rep.setBody(JSON.serialize(new Map<String, Object>{
                    'id' => EQUIPE_ID, 'name' => 'Equipo Test Previsiteur', 'is_active' => true
                }));
                return rep;
            }
            corpsCompte = req.getBody();
            Assert.isTrue(equipeVue, 'L EQUIPE D ABORD : sans elle, le compte n a pas d attache.');
            rep.setStatusCode(201);
            rep.setBody(JSON.serialize(new Map<String, Object>{
                'id' => USER_ID, 'email' => 'test.previsiteur@example.es',
                'equipe_id' => EQUIPE_ID, 'is_active' => true
            }));
            return rep;
        }
    }

    /** Certiko refuse tout : l'échec doit rester local à la campagne. */
    private class BouchonRefus implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse rep = new HttpResponse();
            rep.setStatusCode(422);
            rep.setHeader('Content-Type', 'application/json');
            rep.setBody('{"error":{"code":"invalide","message":"Email rejete par Certiko"}}');
            return rep;
        }
    }

    private static Campaign campagneSignee(String token) {
        return LC027_TestFactory.previsiteur(token, LC027_GestionContrat.STATUT_SIGNE, true);
    }

    private static Campaign relire(Id campagneId) {
        return [
            SELECT CERTIKO_User_Id__c, CERTIKO_Login__c, CERTIKO_Mot_De_Passe__c,
                   CERTIKO_Equipe__c, CERTIKO_Equipe_Id__c, CERTIKO_Compte_Cree_Le__c,
                   CERTIKO_Compte_Erreur__c
            FROM Campaign WHERE Id = :campagneId
        ];
    }

    /* ════════════════════════ L'ouverture nominale ════════════════════════ */

    /**
     * LE CAS QUI COMPTE — l'équipe, puis le compte dedans, puis les six champs
     * enregistrés sur la campagne. Certiko affecte les dossiers à une ÉQUIPE et
     * non à une personne : sans équipe propre, tous les pré-visiteurs verraient
     * les mêmes dossiers.
     */
    @isTest
    static void signatureOuvreLEquipePuisLeCompte() {
        Campaign c = campagneSignee('token-ouverture');
        Test.setMock(HttpCalloutMock.class, new BouchonCertiko());

        Test.startTest();
        LC027_CertikoCompteService.ouvrirPour(new Set<Id>{ c.Id });
        Test.stopTest();

        Campaign apres = relire(c.Id);
        Assert.areEqual(USER_ID, apres.CERTIKO_User_Id__c);
        Assert.areEqual('test.previsiteur@example.es', apres.CERTIKO_Login__c);
        Assert.areEqual(LC027_CertikoCompteService.MOT_DE_PASSE_INITIAL,
            apres.CERTIKO_Mot_De_Passe__c);
        Assert.areEqual('Equipo Test Previsiteur', apres.CERTIKO_Equipe__c);
        Assert.areEqual(EQUIPE_ID, apres.CERTIKO_Equipe_Id__c,
            'L IDENTIFIANT de l equipe : c est lui qui part dans _equipe_poseur.');
        Assert.isNotNull(apres.CERTIKO_Compte_Cree_Le__c);
        Assert.isNull(apres.CERTIKO_Compte_Erreur__c);

        Map<String, Object> envoye = (Map<String, Object>) JSON.deserializeUntyped(corpsCompte);
        Assert.areEqual('Equipo Test Previsiteur', envoye.get('equipe'));
        Assert.areEqual(LC027_CertikoCompteService.MOT_DE_PASSE_INITIAL, envoye.get('password'));
    }

    /**
     * L'équipe où le compte a RÉELLEMENT atterri prime sur celle demandée : un
     * email déjà pris rend le compte existant, qui peut vivre ailleurs. Écrire
     * l'équipe demandée enverrait alors les dossiers à côté.
     */
    @isTest
    static void lEquipeEnregistreeEstCelleDuCompteObtenu() {
        Campaign c = campagneSignee('token-equipe-reelle');
        Test.setMock(HttpCalloutMock.class, new BouchonAutreEquipe());

        Test.startTest();
        LC027_CertikoCompteService.ouvrirPour(new Set<Id>{ c.Id });
        Test.stopTest();

        Assert.areEqual('autre-equipe-0000-4000-8000-000000000001',
            relire(c.Id).CERTIKO_Equipe_Id__c,
            'C est l equipe RENDUE par Certiko qui fait foi, pas celle demandee.');
    }

    /** Le compte rendu appartient à une autre équipe que celle créée. */
    private class BouchonAutreEquipe implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse rep = new HttpResponse();
            rep.setStatusCode(201);
            rep.setHeader('Content-Type', 'application/json');
            if (req.getEndpoint().endsWith('/equipes')) {
                rep.setBody('{"id":"' + EQUIPE_ID + '","name":"Equipo Test Previsiteur"}');
            } else {
                rep.setBody('{"id":"' + USER_ID + '","email":"test.previsiteur@example.es"'
                    + ',"equipe_id":"autre-equipe-0000-4000-8000-000000000001"}');
            }
            return rep;
        }
    }

    /* ════════════════════════ Ce qui ne doit pas bouger ════════════════════════ */

    /**
     * UNE RE-SIGNATURE NE RECRÉE RIEN. Le mot de passe affiché au pré-visiteur
     * ne doit pas changer sous ses pieds, et l'API ne doit pas être rappelée.
     */
    @isTest
    static void compteDejaOuvertNeRepasseParLApi() {
        Campaign c = campagneSignee('token-deja-ouvert');
        update new Campaign(Id = c.Id,
            CERTIKO_User_Id__c = 'deja-la',
            CERTIKO_Mot_De_Passe__c = 'un-autre-mot-de-passe');
        Test.setMock(HttpCalloutMock.class, new BouchonCertiko());

        Test.startTest();
        LC027_CertikoCompteService.ouvrirPour(new Set<Id>{ c.Id });
        Test.stopTest();

        Assert.areEqual(0, Limits.getCallouts(), 'Aucun appel pour un compte deja ouvert.');
        Assert.areEqual('un-autre-mot-de-passe', relire(c.Id).CERTIKO_Mot_De_Passe__c,
            'Le mot de passe affiche ne doit pas changer sous les pieds du pre-visiteur.');
    }

    /**
     * UN ÉCHEC CERTIKO N'ANNULE PAS LA SIGNATURE. L'erreur part dans
     * CERTIKO_Compte_Erreur__c, où l'écran d'administration la montre en rouge,
     * et le contrat reste signé.
     */
    @isTest
    static void echecCertikoEstNoteSansRienBloquer() {
        Campaign c = campagneSignee('token-echec');
        Test.setMock(HttpCalloutMock.class, new BouchonRefus());

        Test.startTest();
        LC027_CertikoCompteService.ouvrirPour(new Set<Id>{ c.Id });
        Test.stopTest();

        Campaign apres = relire(c.Id);
        Assert.isNull(apres.CERTIKO_User_Id__c, 'Aucun compte ouvert.');
        Assert.isNotNull(apres.CERTIKO_Compte_Erreur__c, 'L echec doit laisser une trace.');
        Assert.areEqual(LC027_GestionContrat.STATUT_SIGNE,
            [SELECT StatutContrat__c FROM Campaign WHERE Id = :c.Id].StatutContrat__c,
            'La signature reste acquise : c est un fait juridique.');
    }

    /** Sans email, rien à tenter : l'erreur est posée sans appeler l'API. */
    @isTest
    static void campagneSansEmailEstNoteeSansAppel() {
        Campaign c = campagneSignee('token-sans-email');
        update new Campaign(Id = c.Id, Email__c = null);
        Test.setMock(HttpCalloutMock.class, new BouchonCertiko());

        Test.startTest();
        LC027_CertikoCompteService.ouvrirPour(new Set<Id>{ c.Id });
        Test.stopTest();

        Assert.areEqual(0, Limits.getCallouts());
        Assert.isTrue(relire(c.Id).CERTIKO_Compte_Erreur__c.contains('Email'),
            'La raison doit etre lisible dans l ecran d administration.');
    }

    /**
     * UN PRÉ-VISITEUR REFUSÉ NE PRIVE PAS LES AUTRES. D'où le traitement un par
     * un et le Database.update(false) : une erreur isolée ne doit pas annuler
     * les comptes ouverts dans la même fournée.
     */
    @isTest
    static void unEchecNePriveePasLesAutres() {
        Campaign bon = campagneSignee('token-lot-bon');
        Campaign casse = campagneSignee('token-lot-casse');
        update new Campaign(Id = casse.Id, Email__c = null);
        Test.setMock(HttpCalloutMock.class, new BouchonCertiko());

        Test.startTest();
        LC027_CertikoCompteService.ouvrirPour(new Set<Id>{ bon.Id, casse.Id });
        Test.stopTest();

        Assert.areEqual(USER_ID, relire(bon.Id).CERTIKO_User_Id__c,
            'Le pre-visiteur valide doit avoir son compte.');
        Assert.isNotNull(relire(casse.Id).CERTIKO_Compte_Erreur__c);
    }

    /* ════════════════════════ La file d'attente ════════════════════════ */

    /** Rien à enfiler : aucune exception, et rien ne part. */
    @isTest
    static void fileVideNeLevePas() {
        Test.startTest();
        LC027_CertikoCompteService.ouvrirComptes(null);
        LC027_CertikoCompteService.ouvrirComptes(new Set<Id>());
        LC027_CertikoCompteService.ouvrirComptes(new Set<Id>{ campagneSignee('token-file').Id });
        Test.stopTest();

        Assert.areEqual(0, Limits.getAsyncCalls(),
            'En test, la file rend la main : ouvrirPour se verifie directement.');
    }

    /** Le Queueable existe et délègue : il se couvre par exécution directe. */
    @isTest
    static void leTravailDeFileDelegueAOuvrirPour() {
        Campaign c = campagneSignee('token-queueable');
        Test.setMock(HttpCalloutMock.class, new BouchonCertiko());

        Test.startTest();
        new LC027_CertikoCompteService.Ouverture(new Set<Id>{ c.Id }).execute(null);
        Test.stopTest();

        Assert.areEqual(USER_ID, relire(c.Id).CERTIKO_User_Id__c);
    }

    /* ════════════════════════ Les noms ════════════════════════ */

    /**
     * « Equipo » suivi du nom : une équipe par pré-visiteur, et le préfixe est
     * en espagnol parce que c'est la langue de la console Certiko.
     */
    @isTest
    static void nomEquipePorteLePrefixeEspagnol() {
        Test.startTest();
        Assert.areEqual('Equipo Jose Manuel',
            LC027_CertikoCompteService.nomEquipe('  Jose Manuel  '));
        Assert.areEqual('Equipo', LC027_CertikoCompteService.nomEquipe(null),
            'Sans nom, le prefixe seul — jamais une chaine avec un espace en trop.');
        Test.stopTest();
    }

    /**
     * Certiko exige un prénom ET un nom. Le premier mot fait le prénom, le
     * reste le nom ; un nom en un seul mot part des deux côtés.
     */
    @isTest
    static void prenomEtNomSeDeduisentDuNomComplet() {
        Test.startTest();
        Assert.areEqual('Jose', LC027_CertikoCompteService.prenomDe('Jose Manuel Fernandez'));
        Assert.areEqual('Manuel Fernandez', LC027_CertikoCompteService.nomDe('Jose Manuel Fernandez'));
        Assert.areEqual('Cher', LC027_CertikoCompteService.prenomDe('Cher'));
        Assert.areEqual('Cher', LC027_CertikoCompteService.nomDe('Cher'));
        Assert.areEqual('', LC027_CertikoCompteService.prenomDe(null));
        Assert.areEqual('', LC027_CertikoCompteService.nomDe('   '));
        Test.stopTest();
    }
}