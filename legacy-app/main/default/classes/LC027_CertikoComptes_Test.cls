/**
 * LC027_CertikoComptes_Test — équipes et comptes des pré-visiteurs chez Certiko.
 *
 * CE QUI COMPTE ICI, ce sont les REFUS. Les appels qui réussissent ne tiennent
 * qu'à la lecture du JSON ; c'est quand l'API dit non que le comportement se
 * décide, et deux « non » ne se valent pas :
 *   • un 409 « existe déjà » n'est PAS un échec — une re-signature doit
 *     retrouver l'existant, pas afficher une erreur au pré-visiteur ;
 *   • tout le reste devient un CODE, que l'écran d'administration traduit.
 *
 * Les corps de réponse reprennent la forme relevée sur l'API réelle : les
 * listes arrivent dans `items`, les dates en ISO sans fuseau.
 */
@isTest
private class LC027_CertikoComptes_Test {

    /* ════════════════════════════ Bouchons ════════════════════════════ */

    /** Corps de la DERNIÈRE requête partie vers Certiko. */
    private static String corpsEnvoye;
    /** Chemin appelé, pour vérifier la méthode et l'URL. */
    private static String cheminAppele;
    /** Clé d'API réellement présentée. */
    private static String cleEnvoyee;

    private class Bouchon implements HttpCalloutMock {
        private Integer code;
        private String corps;
        private Bouchon(Integer code, String corps) {
            this.code = code;
            this.corps = corps;
        }
        public HttpResponse respond(HttpRequest req) {
            corpsEnvoye = req.getBody();
            cheminAppele = req.getMethod() + ' ' + req.getEndpoint();
            cleEnvoyee = req.getHeader('X-API-Key');
            HttpResponse rep = new HttpResponse();
            rep.setStatusCode(code);
            rep.setHeader('Content-Type', 'application/json');
            rep.setBody(corps);
            return rep;
        }
    }

    /**
     * Deux réponses à la suite : le refus, puis la liste où l'on retrouve
     * l'existant. C'est le scénario du 409, qui demande DEUX appels.
     */
    private class BouchonSuite implements HttpCalloutMock {
        private List<Integer> codes;
        private List<String> corps;
        private Integer tour = 0;
        private BouchonSuite(List<Integer> codes, List<String> corps) {
            this.codes = codes;
            this.corps = corps;
        }
        public HttpResponse respond(HttpRequest req) {
            Integer i = Math.min(tour, codes.size() - 1);
            tour++;
            HttpResponse rep = new HttpResponse();
            rep.setStatusCode(codes[i]);
            rep.setHeader('Content-Type', 'application/json');
            rep.setBody(corps[i]);
            return rep;
        }
    }

    private class BouchonInjoignable implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new CalloutException('Read timed out');
        }
    }

    private static void bouchonner(Integer code, String corps) {
        Test.setMock(HttpCalloutMock.class, new Bouchon(code, corps));
    }

    /* ════════════════════════════ Corps type ════════════════════════════ */

    private static final String EQUIPE_ID = 'f03c9643-e6e0-4bbc-9dc2-69baf86c234c';
    private static final String USER_ID   = '7b1e0d42-0000-4000-8000-000000000042';

    private static String equipe(String nom) {
        return JSON.serialize(new Map<String, Object>{
            'id' => EQUIPE_ID, 'name' => nom, 'color' => '#3B82F6',
            'is_active' => true, 'members_count' => 1
        });
    }

    private static String membre(String email, Boolean actif) {
        return JSON.serialize(new Map<String, Object>{
            'id' => USER_ID, 'email' => email,
            'first_name' => 'Jose', 'last_name' => 'Fernandez',
            'phone' => '612345678', 'role' => 'poseur', 'language' => 'es',
            'equipe_id' => EQUIPE_ID, 'is_active' => actif,
            'last_login' => '2026-09-25T11:36:33.249076',
            'created_at' => '2026-09-20T08:00:00.000000'
        });
    }

    private static String liste(String element) {
        return '{"items":[' + element + ']}';
    }

    private static String refus(String code, String message) {
        return JSON.serialize(new Map<String, Object>{
            'error' => new Map<String, Object>{ 'code' => code, 'message' => message }
        });
    }

    /* ════════════════════════════ La clé ════════════════════════════ */

    /**
     * LA CLÉ DES COMPTES, PAS CELLE DES DOSSIERS. Deux périmètres, deux clés :
     * les confondre ferait qu'une fuite de l'une donnerait les deux pouvoirs.
     * Ce test garde la trace de ce choix, invisible autrement.
     */
    @isTest
    static void laCleDesComptesEstDistincteDeCelleDesDossiers() {
        bouchonner(200, '{"id":"p1","name":"ECONATURA","equipes_count":3}');

        Test.startTest();
        LC027_CertikoComptes.poseur();
        Test.stopTest();

        Assert.areEqual(System.Label.CERTIKO_API_KEY_COMPTES, cleEnvoyee,
            'Les equipes et les comptes passent par CERTIKO_API_KEY_COMPTES.');
        Assert.areNotEqual(System.Label.CERTIKO_API_KEY, cleEnvoyee,
            'La cle des dossiers ne doit pas servir ici.');
    }

    @isTest
    static void poseurRendLeTitulaireDeLaCle() {
        bouchonner(200, '{"id":"p1","name":"ECONATURA","equipes_count":3}');

        Test.startTest();
        LC027_CertikoComptes.Poseur p = LC027_CertikoComptes.poseur();
        Test.stopTest();

        Assert.areEqual('ECONATURA', p.nom);
        Assert.areEqual(3, p.equipes);
    }

    /* ════════════════════════════ Équipes ════════════════════════════ */

    @isTest
    static void creerEquipeRendLEquipeCreee() {
        bouchonner(201, equipe('Equipo Jose'));

        Test.startTest();
        LC027_CertikoComptes.Equipe e = LC027_CertikoComptes.creerEquipe('Equipo Jose');
        Test.stopTest();

        Assert.areEqual(EQUIPE_ID, e.id);
        Assert.areEqual('Equipo Jose', e.nom);
        Assert.areEqual(true, e.active);
        Map<String, Object> envoye = (Map<String, Object>) JSON.deserializeUntyped(corpsEnvoye);
        Assert.areEqual('Equipo Jose', envoye.get('name'), corpsEnvoye);
    }

    /** Équipe complète, avec son nombre de membres — le levier des homonymes. */
    private static String equipe(String nom, Integer membres, Boolean active) {
        return JSON.serialize(new Map<String, Object>{
            'id' => EQUIPE_ID, 'name' => nom, 'color' => '#3B82F6',
            'is_active' => active, 'members_count' => membres
        });
    }

    /**
     * UNE ÉQUIPE VIDE QUI PORTE LE NOM EST LA NÔTRE, selon toute
     * vraisemblance : une ouverture de compte qui échoue après la création de
     * l'équipe en laisse une sans personne dedans. La réutiliser évite d'en
     * semer une nouvelle à chaque tentative.
     */
    @isTest
    static void equipeVideDuMemeNomEstReutilisee() {
        Test.setMock(HttpCalloutMock.class, new BouchonSuite(
            new List<Integer>{ 409, 200 },
            new List<String>{ refus('equipe_exists', 'deja prise'),
                              liste(equipe('Equipo Jose', 0, true)) }
        ));

        Test.startTest();
        LC027_CertikoComptes.Equipe e = LC027_CertikoComptes.creerEquipe('Equipo Jose');
        Test.stopTest();

        Assert.areEqual(EQUIPE_ID, e.id, 'Une equipe vide se reutilise.');
    }

    /**
     * DEUX PRÉ-VISITEURS HOMONYMES — l'équipe qui bloque a des membres, elle
     * sert donc à quelqu'un. Y glisser le nouveau venu lui donnerait les
     * visites de son homonyme : on crée sous un nom suffixé.
     */
    @isTest
    static void homonymeObtientUneEquipeSuffixee() {
        Test.setMock(HttpCalloutMock.class, new BouchonHomonyme());

        Test.startTest();
        LC027_CertikoComptes.Equipe e = LC027_CertikoComptes.creerEquipe('Equipo Jose');
        Test.stopTest();

        Assert.areEqual('Equipo Jose (2)', e.nom,
            'Le second homonyme doit avoir SA propre equipe.');
    }

    /**
     * Refuse le premier nom (equipe occupee par un homonyme), accepte le
     * second. La liste rendue entre les deux porte une équipe AVEC un membre.
     */
    private class BouchonHomonyme implements HttpCalloutMock {
        private Integer creations = 0;
        public HttpResponse respond(HttpRequest req) {
            HttpResponse rep = new HttpResponse();
            rep.setHeader('Content-Type', 'application/json');
            if (req.getMethod() == 'GET') {
                rep.setStatusCode(200);
                rep.setBody(liste(equipe('Equipo Jose', 1, true)));
                return rep;
            }
            creations++;
            if (creations == 1) {
                rep.setStatusCode(409);
                rep.setBody(refus('equipe_exists', 'Une equipe active porte deja ce nom.'));
                return rep;
            }
            Map<String, Object> envoye =
                (Map<String, Object>) JSON.deserializeUntyped(req.getBody());
            rep.setStatusCode(201);
            rep.setBody(equipe(String.valueOf(envoye.get('name')), 0, true));
            return rep;
        }
    }

    /**
     * Une équipe INACTIVE et vide est réactivée plutôt que doublée : l'API
     * refuserait de toute façon d'en créer une seconde du même nom.
     */
    @isTest
    static void equipeInactiveEtVideEstReactivee() {
        Test.setMock(HttpCalloutMock.class, new BouchonSuite(
            new List<Integer>{ 409, 200, 200 },
            new List<String>{ refus('equipe_exists', 'deja prise'),
                              liste(equipe('Equipo Jose', 0, false)),
                              equipe('Equipo Jose', 0, true) }
        ));

        Test.startTest();
        LC027_CertikoComptes.Equipe e = LC027_CertikoComptes.creerEquipe('Equipo Jose');
        Test.stopTest();

        Assert.areEqual(true, e.active, 'Elle doit ressortir active.');
    }

    /**
     * Tous les noms pris par des équipes occupées : mieux vaut une erreur
     * lisible qu'une rafale d'appels sur une API limitée à une par seconde.
     */
    @isTest
    static void tropDHomonymesFinitParLever() {
        Test.setMock(HttpCalloutMock.class, new BouchonToujoursPris());

        Test.startTest();
        try {
            LC027_CertikoComptes.creerEquipe('Equipo Jose');
            Assert.fail('Au bout des essais, il faut lever.');
        } catch (LC027_CertikoComptes.CertikoComptesException e) {
            Assert.areEqual('CERTIKO_EQUIPE_EXISTE', e.getMessage());
        }
        Test.stopTest();
    }

    /** Tout nom demandé est pris, et par une équipe qui a des membres. */
    private class BouchonToujoursPris implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse rep = new HttpResponse();
            rep.setHeader('Content-Type', 'application/json');
            if (req.getMethod() == 'GET') {
                rep.setStatusCode(200);
                // Une équipe occupée, quel que soit le nom cherché : la
                // recherche se fait sur le nom, donc on les rend toutes.
                rep.setBody('{"items":['
                    + equipe('Equipo Jose', 1, true) + ','
                    + equipe('Equipo Jose (2)', 1, true) + ','
                    + equipe('Equipo Jose (3)', 1, true) + ','
                    + equipe('Equipo Jose (4)', 1, true) + ','
                    + equipe('Equipo Jose (5)', 1, true) + ']}');
                return rep;
            }
            rep.setStatusCode(409);
            rep.setBody(refus('equipe_exists', 'deja prise'));
            return rep;
        }
    }

    /**
     * La couleur est tirée d'une PALETTE, pas des seize millions possibles :
     * un jaune pâle serait illisible sur le fond clair de leur console.
     */
    @isTest
    static void laCouleurVientDeLaPalette() {
        Set<String> vues = new Set<String>();
        Test.startTest();
        for (Integer i = 0; i < 40; i++) {
            vues.add(LC027_CertikoComptes.couleurAuHasard());
        }
        Test.stopTest();

        for (String c : vues) {
            Assert.isTrue(Pattern.matches('#[0-9A-F]{6}', c), c);
        }
        Assert.isTrue(vues.size() > 1, 'Le tirage doit vraiment varier.');
    }

    @isTest
    static void equipeSansNomEstRefusee() {
        Test.startTest();
        try {
            LC027_CertikoComptes.creerEquipe('  ');
            Assert.fail('Un nom vide doit lever.');
        } catch (LC027_CertikoComptes.CertikoComptesException e) {
            Assert.areEqual('CERTIKO_EQUIPE_SANS_NOM', e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void equipesListeCeQueRendLApi() {
        bouchonner(200, liste(equipe('Equipo Jose')));

        Test.startTest();
        List<LC027_CertikoComptes.Equipe> es = LC027_CertikoComptes.equipes(true);
        Test.stopTest();

        Assert.areEqual(1, es.size());
        Assert.areEqual('Equipo Jose', es[0].nom);
    }

    @isTest
    static void majEquipeSansRienAChangerEstRefusee() {
        Test.startTest();
        try {
            LC027_CertikoComptes.majEquipe(EQUIPE_ID, null, null);
            Assert.fail('Une mise a jour vide doit lever.');
        } catch (LC027_CertikoComptes.CertikoComptesException e) {
            Assert.areEqual('CERTIKO_RIEN_A_CHANGER', e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void majEquipeEnvoieCeQuiEstFourni() {
        bouchonner(200, equipe('Equipo Jose Manuel'));

        Test.startTest();
        LC027_CertikoComptes.majEquipe(EQUIPE_ID, 'Equipo Jose Manuel', false);
        Test.stopTest();

        Map<String, Object> envoye = (Map<String, Object>) JSON.deserializeUntyped(corpsEnvoye);
        Assert.areEqual('Equipo Jose Manuel', envoye.get('name'));
        Assert.areEqual(false, envoye.get('is_active'));
    }

    /* ════════════════════════════ Comptes ════════════════════════════ */

    @isTest
    static void creerCompteEnvoieLesChampsAttendus() {
        bouchonner(201, membre('jose@example.es', true));

        Test.startTest();
        LC027_CertikoComptes.Membre m = LC027_CertikoComptes.creerCompte(
            'jose@example.es', '0123456789', 'Jose', 'Fernandez', 'Equipo Jose', '612345678');
        Test.stopTest();

        Assert.areEqual(USER_ID, m.id);
        Assert.areEqual(EQUIPE_ID, m.equipeId,
            'L equipe reelle du compte : c est elle qui part dans _equipe_poseur.');
        Map<String, Object> envoye = (Map<String, Object>) JSON.deserializeUntyped(corpsEnvoye);
        Assert.areEqual('jose@example.es', envoye.get('email'));
        Assert.areEqual('Equipo Jose', envoye.get('equipe'));
        Assert.areEqual('es', envoye.get('language'), 'Les pre-visiteurs sont espagnols.');
    }

    /**
     * L'API exige un prénom ET un nom. Un pré-visiteur inscrit sous un seul
     * mot ne doit pas faire échouer la création : le mot part des deux côtés.
     */
    @isTest
    static void nomEnUnSeulMotRemplitLesDeuxChamps() {
        bouchonner(201, membre('jose@example.es', true));

        Test.startTest();
        LC027_CertikoComptes.creerCompte(
            'jose@example.es', '0123456789', null, 'Fernandez', 'Equipo Jose', null);
        Test.stopTest();

        Map<String, Object> envoye = (Map<String, Object>) JSON.deserializeUntyped(corpsEnvoye);
        Assert.areEqual('Fernandez', envoye.get('first_name'));
        Assert.areEqual('Fernandez', envoye.get('last_name'));
        Assert.isFalse(envoye.containsKey('phone'),
            'Un telephone absent ne part pas vide.');
    }

    /**
     * EMAIL DÉJÀ PRIS : le portail doit afficher un accès, pas une erreur. Le
     * compte existant est retrouvé — y compris s'il a été désactivé, d'où la
     * recherche qui inclut les inactifs.
     */
    @isTest
    static void emailDejaPrisRendLeCompteExistant() {
        Test.setMock(HttpCalloutMock.class, new BouchonSuite(
            new List<Integer>{ 409, 200 },
            new List<String>{ refus('email_taken', 'deja pris'),
                              liste(membre('jose@example.es', false)) }
        ));

        Test.startTest();
        LC027_CertikoComptes.Membre m = LC027_CertikoComptes.creerCompte(
            'jose@example.es', '0123456789', 'Jose', 'Fernandez', 'Equipo Jose', null);
        Test.stopTest();

        Assert.areEqual(USER_ID, m.id);
        Assert.areEqual(false, m.actif, 'Un compte desactive doit quand meme etre retrouve.');
    }

    @isTest
    static void compteIncompletEstRefuseAvantTouteRequete() {
        Test.startTest();
        try {
            LC027_CertikoComptes.creerCompte('jose@example.es', '0123456789',
                'Jose', 'Fernandez', '', null);
            Assert.fail('Une equipe vide doit lever.');
        } catch (LC027_CertikoComptes.CertikoComptesException e) {
            Assert.areEqual('CERTIKO_COMPTE_INCOMPLET', e.getMessage());
        }
        Test.stopTest();
        Assert.areEqual(0, Limits.getCallouts(), 'Rien ne doit partir sur une saisie incomplete.');
    }

    @isTest
    static void membresFiltreParEquipeEtInactifs() {
        bouchonner(200, liste(membre('jose@example.es', true)));

        Test.startTest();
        List<LC027_CertikoComptes.Membre> ms =
            LC027_CertikoComptes.membres('Equipo Jose', true);
        Test.stopTest();

        Assert.areEqual(1, ms.size());
        Assert.isTrue(cheminAppele.contains('equipe=Equipo+Jose'), cheminAppele);
        Assert.isTrue(cheminAppele.contains('include_inactive=true'), cheminAppele);
    }

    @isTest
    static void majCompteEnvoieCeQuiEstFourni() {
        bouchonner(200, membre('jose@example.es', false));

        Test.startTest();
        LC027_CertikoComptes.majCompte('jose@example.es', '0123456789', 'Equipo Autre', false);
        Test.stopTest();

        Map<String, Object> envoye = (Map<String, Object>) JSON.deserializeUntyped(corpsEnvoye);
        Assert.areEqual('0123456789', envoye.get('password'));
        Assert.areEqual('Equipo Autre', envoye.get('equipe'));
        Assert.areEqual(false, envoye.get('is_active'));
    }

    @isTest
    static void majCompteSansRienAChangerEstRefusee() {
        Test.startTest();
        try {
            LC027_CertikoComptes.majCompte('jose@example.es', null, null, null);
            Assert.fail('Une mise a jour vide doit lever.');
        } catch (LC027_CertikoComptes.CertikoComptesException e) {
            Assert.areEqual('CERTIKO_RIEN_A_CHANGER', e.getMessage());
        }
        Test.stopTest();
    }

    /* ════════════════════════════ Les refus ════════════════════════════ */

    /**
     * CHAQUE REFUS A SON CODE — l'écran d'administration les traduit un par
     * un. Un code qui changerait sans que le dictionnaire suive laisserait un
     * message vide à l'écran, d'où cette vérification cas par cas.
     */
    @isTest
    static void chaqueRefusDonneSonCode() {
        Map<Integer, String> attendus = new Map<Integer, String>{
            401 => 'CERTIKO_CLE_REFUSEE',
            403 => 'CERTIKO_CLE_REFUSEE',
            404 => 'CERTIKO_INTROUVABLE',
            429 => 'CERTIKO_LIMITE_DEBIT'
        };
        Test.startTest();
        for (Integer code : attendus.keySet()) {
            bouchonner(code, refus('x', 'refus'));
            try {
                LC027_CertikoComptes.poseur();
                Assert.fail('Le code HTTP ' + code + ' doit lever.');
            } catch (LC027_CertikoComptes.CertikoComptesException e) {
                Assert.areEqual(attendus.get(code), e.getMessage(), 'HTTP ' + code);
            }
        }
        Test.stopTest();
    }

    /** Un refus inconnu remonte le message de Certiko : il aide à corriger. */
    @isTest
    static void refusInconnuRemonteLeDetail() {
        bouchonner(422, refus('champ_manquant', 'Le champ email est obligatoire'));

        Test.startTest();
        try {
            LC027_CertikoComptes.poseur();
            Assert.fail('Un 422 doit lever.');
        } catch (LC027_CertikoComptes.CertikoComptesException e) {
            Assert.isTrue(e.getMessage().startsWith('CERTIKO_REFUS:'), e.getMessage());
            Assert.isTrue(e.getMessage().contains('email est obligatoire'), e.getMessage());
        }
        Test.stopTest();
    }

    /** Un 409 dont le code d'erreur n'est pas connu reste un refus. */
    @isTest
    static void conflitInconnuResteUnRefus() {
        bouchonner(409, refus('autre_chose', 'conflit'));

        Test.startTest();
        try {
            LC027_CertikoComptes.creerEquipe('Equipo Jose');
            Assert.fail('Un 409 inconnu doit lever.');
        } catch (LC027_CertikoComptes.CertikoComptesException e) {
            Assert.isTrue(e.getMessage().startsWith('CERTIKO_REFUS:'), e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void reponseIllisibleDonneUnCodeDedie() {
        bouchonner(200, 'pas du json');

        Test.startTest();
        try {
            LC027_CertikoComptes.poseur();
            Assert.fail('Une reponse illisible doit lever.');
        } catch (LC027_CertikoComptes.CertikoComptesException e) {
            Assert.areEqual('CERTIKO_REPONSE_ILLISIBLE', e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void certikoInjoignableDonneUnCodeDedie() {
        Test.setMock(HttpCalloutMock.class, new BouchonInjoignable());

        Test.startTest();
        try {
            LC027_CertikoComptes.poseur();
            Assert.fail('Une coupure reseau doit lever.');
        } catch (LC027_CertikoComptes.CertikoComptesException e) {
            Assert.areEqual('CERTIKO_INJOIGNABLE', e.getMessage());
        }
        Test.stopTest();
    }

    /* ════════════════════════════ Lecture des réponses ════════════════════════════ */

    /**
     * Les dates de Certiko arrivent SANS FUSEAU (« 2026-09-25T11:36:33.249076 »)
     * et sont lues comme de l'UTC. Une date illisible ne doit pas faire échouer
     * la lecture de tout le compte.
     */
    @isTest
    static void datesSansFuseauEtDatesIllisibles() {
        bouchonner(200, liste(JSON.serialize(new Map<String, Object>{
            'id' => USER_ID, 'email' => 'jose@example.es',
            'equipe_id' => EQUIPE_ID, 'is_active' => true,
            'last_login' => '2026-09-25T11:36:33.249076',
            'created_at' => 'pas une date'
        })));

        Test.startTest();
        List<LC027_CertikoComptes.Membre> ms = LC027_CertikoComptes.membres(null, false);
        Test.stopTest();

        Assert.areEqual(1, ms.size());
        Assert.areEqual(Datetime.newInstanceGmt(2026, 9, 25, 11, 36, 33), ms[0].derniereConnexion);
        Assert.isNull(ms[0].creeLe, 'Une date illisible vaut null, sans faire echouer le reste.');
    }

    /** Une réponse sans `items` ne casse rien : elle rend une liste vide. */
    @isTest
    static void reponseSansItemsRendUneListeVide() {
        bouchonner(200, '{"total":0}');

        Test.startTest();
        List<LC027_CertikoComptes.Equipe> es = LC027_CertikoComptes.equipes(false);
        Test.stopTest();

        Assert.isTrue(es.isEmpty());
    }

    @isTest
    static void membreParEmailIgnoreLaCasse() {
        bouchonner(200, liste(membre('Jose@Example.ES', true)));

        Test.startTest();
        LC027_CertikoComptes.Membre m =
            LC027_CertikoComptes.membreParEmail('jose@example.es', false);
        Test.stopTest();

        Assert.isNotNull(m, 'La casse de l email ne doit pas empecher de le retrouver.');
        Assert.areEqual(USER_ID, m.id);
    }

    @isTest
    static void equipeParNomIgnoreLaCasse() {
        bouchonner(200, liste(equipe('Equipo Jose')));

        Test.startTest();
        LC027_CertikoComptes.Equipe e = LC027_CertikoComptes.equipeParNom('EQUIPO JOSE');
        Test.stopTest();

        Assert.isNotNull(e);
        Assert.areEqual(EQUIPE_ID, e.id);
    }
}