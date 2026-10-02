/**
 * LC027_Certiko_Test — échanges avec l'API publique Certiko.
 *
 * CE QUI COMPTE ICI, ce sont les CODES D'ERREUR : le portail les traduit dans
 * la langue du pré-visiteur, aucun texte brut de l'API ne lui est montré. Un
 * code qui change sans que le dictionnaire suive laisserait un message vide à
 * l'écran, d'où une vérification par cas de refus.
 *
 * Les corps de réponse sont ceux de l'API réelle : `id`, `reference`,
 * `status` (objet), `values` (objet). Depuis le 2026-09-23, `status_vt` est
 * une colonne exposée, liste de sélection des deux côtés : c'est notre liste
 * qui fait foi, et une valeur qu'elle ignore n'est pas enregistrée.
 */
@isTest
private class LC027_Certiko_Test {

    /* ════════════════════════════ Bouchons ════════════════════════════ */

    /**
     * Réponse unique, quel que soit l'appel. Les triggers de Compte et de
     * Dossier émettent eux aussi des appels sortants pendant la préparation du
     * jeu de données : un bouchon partiel les ferait échouer.
     */
    /**
     * Corps du DERNIER appel vers Certiko. Porte par la classe de test : une
     * classe interne Apex ne peut pas avoir de membre statique.
     */
    private static String corpsEnvoye;

    /** Clé d'idempotence du DERNIER appel. Même raison : pas de statique interne. */
    private static String cleEnvoyee;

    private class Bouchon implements HttpCalloutMock {
        private Integer code;
        private String corps;
        private Bouchon(Integer code, String corps) {
            this.code = code;
            this.corps = corps;
        }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse rep = new HttpResponse();
            String endpoint = req.getEndpoint();
            Boolean versCertiko = endpoint.contains('certiko');
            if (versCertiko) {
                corpsEnvoye = req.getBody();
                cleEnvoyee = req.getHeader('Idempotency-Key');
            }
            rep.setStatusCode(versCertiko ? code : 200);
            rep.setHeader('Content-Type', 'application/json');
            // Le géocodage des triggers désérialise une LISTE : un objet le
            // ferait échouer, et l'erreur ne désignerait pas Certiko.
            rep.setBody(versCertiko ? corps
                : (endpoint.contains('nominatim') ? '[]' : '{"success":true}'));
            return rep;
        }
    }

    /** Certiko hors d'atteinte : coupure réseau, DNS, délai dépassé. */
    private class BouchonInjoignable implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            if (req.getEndpoint().contains('certiko')) {
                throw new CalloutException('Read timed out');
            }
            HttpResponse rep = new HttpResponse();
            rep.setStatusCode(200);
            rep.setBody(req.getEndpoint().contains('nominatim') ? '[]' : '{"success":true}');
            return rep;
        }
    }

    private static void bouchonner(Integer code, String corps) {
        Test.setMock(HttpCalloutMock.class, new Bouchon(code, corps));
    }

    /** Réponse de création telle que l'API la renvoie aujourd'hui. */
    private static String dossierCree(String statutVt) {
        Map<String, Object> corps = new Map<String, Object>{
            'id' => '4bce8e1e-0000-4000-8000-000000000001',
            'reference' => 'RES060-000123',
            'status' => new Map<String, Object>{ 'slug' => 'a-planifier', 'name' => 'A planifier' }
        };
        if (statutVt != null) {
            corps.put('values', new Map<String, Object>{ 'status_vt' => statutVt });
        }
        return JSON.serialize(corps);
    }

    /* ════════════════════════════ Jeu de données ════════════════════════════ */

    private static Pro__c dossier() {
        Pro__c p = new Pro__c(
            Name = 'Maria Robles-',
            Client_Adresse_Chantier__c = 'Calle Mayor 14,,34004,PALENCIA',
            CodePostal__c = '34004',
            Phone__c = '612345678',
            Email__c = 'maria.robles@example.es'
        );
        insert p;
        return p;
    }

    /* ════════════════════════════ Création ════════════════════════════ */

    /**
     * Le corps envoyé n'est pas écrit en dur : il vient de Certiko_Champ__mdt.
     * Si la table est vide, l'envoi partirait sans aucune donnée — ce test
     * garde la trace de ce lien.
     */
    @isTest
    static void tableDeCorrespondanceAlimenteLEnvoi() {
        Test.startTest();
        List<Certiko_Champ__mdt> lignes = LC027_Certiko.correspondances();
        Test.stopTest();

        Assert.isFalse(lignes.isEmpty(),
            'Sans correspondance active, aucun champ ne part chez Certiko.');
        for (Certiko_Champ__mdt l : lignes) {
            Assert.isNotNull(l.Colonne_Certiko__c, 'Une correspondance vise une colonne Certiko.');
            // Deux sources possibles, jamais aucune : soit un champ du Dossier,
            // soit une valeur fixe identique pour tous les dossiers.
            Boolean aUneSource = String.isNotBlank(l.Champ_Dossier__c)
                || String.isNotBlank(l.Valeur_Fixe__c);
            Assert.isTrue(aUneSource,
                'La correspondance « ' + l.Colonne_Certiko__c + ' » n a aucune source.');
        }
    }

    /**
     * LE CORPS RÉELLEMENT ENVOYÉ — c'est ici que se joue la colonne « Statut
     * RES060 » du tableau. Relevé sur l'API le 2026-09-23 : `status` vise le
     * statut de l'espace, `statut_res060` est une COLONNE et doit donc partir
     * dans `values`. Les envoyer au même endroit laissait la colonne vide.
     */
    @isTest
    static void corpsEnvoyePorteLeStatutDuTableauEtLesValeursFixes() {
        LC027_TestFactory.bouchonnerCallouts();
        Pro__c p = dossierPlanifie();
        bouchonner(201, dossierCree(null));

        Test.startTest();
        LC027_Certiko.creerDossier(p.Id);
        Test.stopTest();

        Map<String, Object> corps = (Map<String, Object>)
            JSON.deserializeUntyped(corpsEnvoye);
        Map<String, Object> valeurs = (Map<String, Object>) corps.get('values');

        Assert.areEqual('gestion-install-res060', corps.get('board'));
        Assert.areEqual('nouveaux_clients', corps.get('status'),
            'Statut de l espace Certiko.');
        Assert.areEqual('nouveaux_clients', valeurs.get('statut_res060'),
            'COLONNE « Statut RES060 » du tableau : c est celle qui restait vide.');
        Assert.areEqual('planifie', valeurs.get('status_vt'));
        Assert.areEqual('ECONATURA', valeurs.get('_poseur'),
            'Certiko resout le nom du poseur en identifiant de son cote.');
        Assert.areEqual(EQUIPE_ID, valeurs.get('_equipe_poseur'),
            'C est l IDENTIFIANT de l equipe qui part, jamais son nom : un nom '
            + 'se renomme chez Certiko, l identifiant non.');

        // « 2026-09-22T13:28:00 » : date et heure locales, sans fuseau.
        String quand = String.valueOf(valeurs.get('_date_previsite'));
        Assert.isNotNull(quand, 'La date d installation part avec le dossier.');
        Assert.areEqual(19, quand.length(), quand);
        Assert.areEqual('T', quand.substring(10, 11), quand);
        Assert.isTrue(Pattern.matches('\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}', quand), quand);

        // Le nom du client perd le tiret final des imports.
        Assert.areEqual('Maria Robles', corps.get('client_name'));
    }

    /* ══════════════════ Clé d'idempotence ══════════════════ */

    /**
     * LE PREMIER ENVOI PORTE « -1 », sans que personne ait rien saisi.
     *
     * C'est cette clé qui évite un second dossier chez Certiko quand la
     * réponse se perd en route.
     */
    @isTest
    static void premierEnvoiPorteLeNumeroUn() {
        LC027_TestFactory.bouchonnerCallouts();
        Pro__c p = dossierPlanifie();
        // Le champ vaut 1 par défaut ; on le vide pour figer le comportement
        // des Dossiers créés AVANT ce champ, qui n'en portent aucun.
        update new Pro__c(Id = p.Id, CERTIKO_Numero_Envoi__c = null);
        bouchonner(201, dossierCree(null));

        Test.startTest();
        LC027_Certiko.creerDossier(p.Id);
        Test.stopTest();

        Assert.areEqual(p.Id + '-1', cleEnvoyee,
            'Un numero d envoi vide vaut 1.');
    }

    /**
     * LA SORTIE DE SECOURS — incrémenter le numéro donne une clé neuve, donc
     * un dossier neuf chez Certiko. Sans elle, une faute de saisie ou une
     * replanification resterait sans recours : l'Id Salesforce ne changeant
     * jamais, Certiko refuserait la recréation à vie.
     */
    @isTest
    static void numeroDEnvoiDonneUneCleNeuve() {
        LC027_TestFactory.bouchonnerCallouts();
        Pro__c p = dossierPlanifie();
        update new Pro__c(Id = p.Id, CERTIKO_Numero_Envoi__c = 3);
        bouchonner(201, dossierCree(null));

        Test.startTest();
        LC027_Certiko.creerDossier(p.Id);
        Test.stopTest();

        Assert.areEqual(p.Id + '-3', cleEnvoyee);
    }

    /**
     * Un zéro saisi à la main ne doit pas produire une clé que personne
     * n'attend : on retombe sur le premier envoi.
     */
    @isTest
    static void numeroAberrantRetombeSurLePremierEnvoi() {
        LC027_TestFactory.bouchonnerCallouts();
        Pro__c p = dossierPlanifie();
        update new Pro__c(Id = p.Id, CERTIKO_Numero_Envoi__c = 0);
        bouchonner(201, dossierCree(null));

        Test.startTest();
        LC027_Certiko.creerDossier(p.Id);
        Test.stopTest();

        Assert.areEqual(p.Id + '-1', cleEnvoyee);
    }

    /**
     * Pré-visiteur sans compte Certiko : la colonne est OMISE, pas envoyée
     * vide. Une chaîne vide effacerait l'équipe posée par ailleurs — c'est
     * exactement ce que fait viderColonne() en fin de visite technique.
     *
     * Le NOM de l'équipe est renseigné dans ce cas, et pas l'identifiant :
     * c'est bien l'identifiant, et lui seul, qui commande l'envoi.
     */
    @isTest
    static void equipeInconnueNEnvoiePasLaColonne() {
        LC027_TestFactory.bouchonnerCallouts();
        Pro__c p = dossierPlanifie(null);
        bouchonner(201, dossierCree(null));

        Test.startTest();
        LC027_Certiko.creerDossier(p.Id);
        Test.stopTest();

        Map<String, Object> corps = (Map<String, Object>)
            JSON.deserializeUntyped(corpsEnvoye);
        Map<String, Object> valeurs = (Map<String, Object>) corps.get('values');

        Assert.isFalse(valeurs.containsKey('_equipe_poseur'), corpsEnvoye);
        // Le reste du dossier part quand même : l equipe n est pas bloquante.
        Assert.areEqual('ECONATURA', valeurs.get('_poseur'));
    }

    /**
     * LE STATUT DU PREMIER ENVOI — la création ne renvoie PAS le détail des
     * colonnes, seulement id / reference / status. Le portail affichait donc
     * « Sans statut » juste après l'envoi, alors que la visite était bien
     * planifiée chez Certiko. Ce que nous avons envoyé fait foi.
     */
    @isTest
    static void statutEnvoyeFaitFoiQuandLaReponseNeLeRendPas() {
        LC027_TestFactory.bouchonnerCallouts();
        Pro__c p = dossierPlanifie();
        // dossierCree(null) : la réponse de création, SANS bloc « values ».
        bouchonner(201, dossierCree(null));

        Test.startTest();
        LC027_Certiko.Resultat r = LC027_Certiko.creerDossier(p.Id);
        Test.stopTest();

        Assert.areEqual('planifie', r.statutVt,
            'La valeur fixe de la table de correspondance doit prendre le relais.');
    }

    /** Une réponse qui PORTE le statut reste prioritaire sur ce qu'on a envoyé. */
    @isTest
    static void statutRenduParCertikoLEmporteSurLEnvoye() {
        LC027_TestFactory.bouchonnerCallouts();
        Pro__c p = dossierPlanifie();
        bouchonner(201, dossierCree('en_cours'));

        Test.startTest();
        LC027_Certiko.Resultat r = LC027_Certiko.creerDossier(p.Id);
        Test.stopTest();

        Assert.areEqual('en_cours', r.statutVt);
    }

    /**
     * MAIS PAS AVEUGLÉMENT : si Certiko a refusé la colonne, la valeur envoyée
     * n'est pas celle du dossier. Mieux vaut aucun statut qu'un faux.
     */
    @isTest
    static void colonneDeStatutRefuseeNeLaisseAucunStatut() {
        LC027_TestFactory.bouchonnerCallouts();
        Pro__c p = dossierPlanifie();
        Map<String, Object> corps = (Map<String, Object>)
            JSON.deserializeUntyped(dossierCree(null));
        corps.put('errors', new List<Object>{
            new Map<String, Object>{ 'slug' => 'status_vt', 'code' => 'invalid_value' }
        });
        bouchonner(201, JSON.serialize(corps));

        Test.startTest();
        LC027_Certiko.Resultat r = LC027_Certiko.creerDossier(p.Id);
        Test.stopTest();

        Assert.isNull(r.statutVt, 'Un statut refuse ne doit pas etre repris comme acquis.');
    }

    /**
     * Certiko peut refuser UNE colonne et rendre quand même 200, avec le détail
     * dans « errors » — relevé le 2026-09-25 sur un nom d'équipe inconnu. La
     * création ne doit pas échouer pour autant : la visite doit pouvoir
     * démarrer même si l'équipe ne suit pas.
     */
    @isTest
    static void colonneRefuseeNEmpechePasLaCreation() {
        LC027_TestFactory.bouchonnerCallouts();
        Pro__c p = dossierPlanifie();
        Map<String, Object> corps = (Map<String, Object>)
            JSON.deserializeUntyped(dossierCree(null));
        corps.put('errors', new List<Object>{
            new Map<String, Object>{
                'slug' => '_equipe_poseur',
                'code' => 'invalid_value',
                'message' => 'Equipe inconnue'
            }
        });
        bouchonner(201, JSON.serialize(corps));

        Test.startTest();
        LC027_Certiko.Resultat r = LC027_Certiko.creerDossier(p.Id);
        Test.stopTest();

        Assert.areEqual('RES060-000123', r.reference,
            'Le dossier est cree : seule la colonne a ete refusee.');
    }

    /**
     * LE GARDE-FOU DE LA TABLE — vérifié à part, parce qu'une ligne fautive ne
     * peut pas être insérée en test : le DML sur du Custom Metadata est
     * asynchrone et ne change rien à la requête en cours.
     *
     * Ce qu'il protège : la requête est construite à la volée à partir de la
     * table. Un chemin fautif qui y entrerait la ferait échouer, et PLUS AUCUN
     * dossier ne partirait chez Certiko — pas seulement celui de la ligne.
     */
    @isTest
    static void cheminFautifEstEcarteDeLaRequete() {
        Test.startTest();
        // Ce qui doit passer : un champ du Dossier, et un champ de parent.
        Assert.isTrue(LC027_Certiko.cheminValide('PREVISITE_Date__c'));
        Assert.isTrue(LC027_Certiko.cheminValide(
            'LOOKUP_Pre_visiteur__r.Acces_REGIE__r.CERTIKO_Equipe_Id__c'),
            'Le chemin de l equipe du pre-visiteur doit rester valide.');

        // Ce qui doit être écarté.
        Assert.isFalse(LC027_Certiko.cheminValide(''));
        Assert.isFalse(LC027_Certiko.cheminValide('Champ_Qui_Nexiste_Pas__c'));
        Assert.isFalse(LC027_Certiko.cheminValide('Relation_Absente__r.Name'),
            'Un maillon inconnu arrete le chemin.');
        Assert.isFalse(LC027_Certiko.cheminValide('PREVISITE_Date__c.Name'),
            'Un champ simple n est pas une relation.');
        Assert.isFalse(LC027_Certiko.cheminValide(
            'LOOKUP_Pre_visiteur__r.Champ_Absent_Sur_Compte__c'));
        Test.stopTest();
    }

    /** Identifiant d'équipe Certiko, de la forme que rend leur API. */
    private static final String EQUIPE_ID = 'f03c9643-e6e0-4bbc-9dc2-69baf86c234c';

    private static Pro__c dossierPlanifie() {
        return dossierPlanifie(EQUIPE_ID);
    }

    /**
     * Dossier PLANIFIÉ : seul état où PREVISITE_Date__c peut être renseignée
     * (PREVISITE4_OUI exige alors pré-visiteur ET date).
     *
     * `equipeId` se pose sur la CAMPAGNE du pré-visiteur, à deux relations du
     * Dossier : c'est ce chemin que suit `_equipe_poseur`. Le NOM de l'équipe
     * vit à côté, pour l'affichage — il ne part jamais chez Certiko.
     */
    private static Pro__c dossierPlanifie(String equipeId) {
        Campaign c = LC027_TestFactory.previsiteur(
            'token-certiko', LC027_GestionContrat.STATUT_SIGNE, true);
        c.CERTIKO_Equipe__c = 'Equipo Test Previsiteur';
        c.CERTIKO_Equipe_Id__c = equipeId;
        update c;
        Account a = new Account(
            Name = LC027_Roles.prefixeCompte(LC027_Roles.PREVISITEUR) + 'Test Previsiteur',
            Type_Intervenant__c = LC027_Roles.PREVISITEUR,
            Acces_REGIE__c = c.Id
        );
        List<RecordType> rts = [
            SELECT Id FROM RecordType
            WHERE SObjectType = 'Account' AND DeveloperName = 'Client' LIMIT 1
        ];
        if (!rts.isEmpty()) {
            a.RecordTypeId = rts[0].Id;
        }
        insert a;
        Pro__c p = new Pro__c(
            Name = 'Maria Robles-',
            PREVISITE_Statut__c = 'OUI',
            LOOKUP_Pre_visiteur__c = a.Id,
            Pr_visite_Statut__c = LC027_DossiersPrevisite.STATUT_PLANIFIE,
            PREVISITE_Date__c = Datetime.newInstance(2026, 9, 22, 13, 28, 0),
            Client_Adresse_Chantier__c = 'Calle Mayor 14,,34004,PALENCIA',
            CodePostal__c = '34004',
            Phone__c = '612345678',
            Email__c = 'maria.robles@example.es'
        );
        insert p;
        return p;
    }

    @isTest
    static void creationRendIdReferenceEtStatut() {
        LC027_TestFactory.bouchonnerCallouts();
        Pro__c p = dossier();
        bouchonner(201, dossierCree(null));

        Test.startTest();
        LC027_Certiko.Resultat res = LC027_Certiko.creerDossier(p.Id);
        Test.stopTest();

        Assert.areEqual('4bce8e1e-0000-4000-8000-000000000001', res.id);
        Assert.areEqual('RES060-000123', res.reference);
        Assert.areEqual('A planifier', res.statutDossier);
        // JAMAIS DE REPLI SUR LE STATUT DE WORKFLOW : « A planifier » n'est pas
        // une valeur de status_vt, l'y recopier remplirait la liste de
        // sélection avec ce qui n'en fait pas partie. Le repli se fait sur ce
        // que NOUS avons envoyé, et sur rien d'autre.
        Assert.areNotEqual('A planifier', res.statutVt,
            'Le statut de l espace ne doit jamais devenir un statut de visite.');
        Assert.areEqual('planifie', res.statutVt,
            'Faute de reponse detaillee, la valeur envoyee fait foi.');
    }

    @isTest
    static void statutVtEstLuDansValues() {
        LC027_TestFactory.bouchonnerCallouts();
        Pro__c p = dossier();
        bouchonner(201, dossierCree('en_cours'));

        Test.startTest();
        LC027_Certiko.Resultat res = LC027_Certiko.creerDossier(p.Id);
        Test.stopTest();

        Assert.areEqual('en_cours', res.statutVt);
        Assert.areEqual('A planifier', res.statutDossier);
    }

    /**
     * Le champ est une LISTE DE SÉLECTION : c'est elle qui décide, et elle se
     * lit dans le schéma. Ajouter un statut se fait donc en configuration.
     */
    @isTest
    static void listeDeSelectionDecideDeCeQuiEstAdmis() {
        Test.startTest();
        Schema.SObjectField champ = Pro__c.CERTIKO_Statut_VT__c;
        Boolean connu = LC027_Certiko.valeurAdmise(champ, 'terminee');
        Boolean inconnu = LC027_Certiko.valeurAdmise(champ, 'statut_de_demain');
        Boolean vide = LC027_Certiko.valeurAdmise(champ, '');
        // Un champ TEXTE accepte tout : le controle ne vaut que pour les listes.
        Boolean texte = LC027_Certiko.valeurAdmise(Pro__c.CERTIKO_Reference__c, 'n importe quoi');
        List<String> admises = LC027_Certiko.valeursAdmises(champ);
        Test.stopTest();

        Assert.isTrue(connu, 'terminee fait partie de la liste.');
        Assert.isFalse(inconnu, 'Un statut absent de la liste est refuse.');
        Assert.isFalse(vide, 'Une valeur vide n est pas un statut.');
        Assert.isTrue(texte, 'Un champ texte n a rien a controler.');
        Assert.isTrue(admises.contains('planifie'), String.join(admises, ', '));
        Assert.isTrue(admises.contains('en_cours'), String.join(admises, ', '));
        Assert.isTrue(admises.contains('terminee'), String.join(admises, ', '));
    }

    /**
     * Le portail ne doit JAMAIS afficher une valeur d API. Il traduit d abord
     * lui-meme ; ce libelle est son filet pour un statut ajoute en
     * configuration sans passer par le dictionnaire.
     */
    @isTest
    static void libelleRemplaceLaValeurDApi() {
        Test.startTest();
        Schema.SObjectField champ = Pro__c.CERTIKO_Statut_VT__c;
        String connu = LC027_Certiko.libelleDe(champ, 'en_cours');
        String inconnu = LC027_Certiko.libelleDe(champ, 'statut_de_demain');
        String vide = LC027_Certiko.libelleDe(champ, null);
        // Deuxieme appel : le libelle est retenu, le champ n est pas redecrit.
        String rappel = LC027_Certiko.libelleDe(champ, 'terminee');
        Test.stopTest();

        Assert.areEqual('En cours', connu);
        Assert.areEqual('Terminée', rappel);
        Assert.isNull(inconnu, 'Une valeur hors liste n a pas de libelle.');
        Assert.isNull(vide);
    }

    /* ════════════════════════════ Relecture ════════════════════════════ */

    @isTest
    static void relectureRendLeStatutCourant() {
        LC027_TestFactory.bouchonnerCallouts();
        bouchonner(200, dossierCree('terminee'));

        Test.startTest();
        LC027_Certiko.Resultat res = LC027_Certiko.lireDossier('RES060-000123');
        Test.stopTest();

        Assert.areEqual('terminee', res.statutVt);
    }

    @isTest
    static void relectureSansIdentifiantEstRefusee() {
        Test.startTest();
        try {
            LC027_Certiko.lireDossier('   ');
            Assert.fail('Sans identifiant, il n y a rien a relire.');
        } catch (LC027_Certiko.CertikoException e) {
            Assert.areEqual('CERTIKO_SANS_DOSSIER', e.getMessage());
        }
        Test.stopTest();
    }

    /* ════════════════════════════ Refus de l'API ════════════════════════════ */

    /** Débit limité à un appel : deux clics rapprochés donnent un 429. */
    @isTest
    static void debitDepasseDonneUnCodeDedie() {
        LC027_TestFactory.bouchonnerCallouts();
        Pro__c p = dossier();
        bouchonner(429, '{"error":{"message":"Too many requests"}}');

        Test.startTest();
        try {
            LC027_Certiko.creerDossier(p.Id);
            Assert.fail('Un 429 doit etre traduit.');
        } catch (LC027_Certiko.CertikoException e) {
            Assert.areEqual('CERTIKO_LIMITE_DEBIT', e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void cleRefuseeDonneUnCodeDedie() {
        LC027_TestFactory.bouchonnerCallouts();
        Pro__c p = dossier();
        bouchonner(401, '{"error":{"message":"Invalid API key"}}');

        Test.startTest();
        try {
            LC027_Certiko.creerDossier(p.Id);
            Assert.fail('Une cle refusee doit etre traduite.');
        } catch (LC027_Certiko.CertikoException e) {
            Assert.areEqual('CERTIKO_CLE_REFUSEE', e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void dossierInconnuDonneUnCodeDedie() {
        LC027_TestFactory.bouchonnerCallouts();
        bouchonner(404, '{"error":{"message":"Not found"}}');

        Test.startTest();
        try {
            LC027_Certiko.lireDossier('inconnu');
            Assert.fail('Un 404 doit etre traduit.');
        } catch (LC027_Certiko.CertikoException e) {
            Assert.areEqual('CERTIKO_DOSSIER_INTROUVABLE', e.getMessage());
        }
        Test.stopTest();
    }

    /**
     * 422 : un champ obligatoire manque. Le détail vient de Certiko et VOYAGE
     * avec le code — c'est lui qui dit au pré-visiteur quoi corriger.
     */
    @isTest
    static void refusDeContenuRemonteLeDetail() {
        LC027_TestFactory.bouchonnerCallouts();
        Pro__c p = dossier();
        bouchonner(422, '{"error":{"message":"telephone is required"}}');

        Test.startTest();
        try {
            LC027_Certiko.creerDossier(p.Id);
            Assert.fail('Un 422 doit etre traduit.');
        } catch (LC027_Certiko.CertikoException e) {
            Assert.areEqual('CERTIKO_REFUS:telephone is required', e.getMessage());
        }
        Test.stopTest();
    }

    /** Erreur sans champ « error » : le corps brut sert de détail. */
    @isTest
    static void refusSansMessageRemonteLeCorps() {
        LC027_TestFactory.bouchonnerCallouts();
        Pro__c p = dossier();
        bouchonner(500, '{"detail":["boom"]}');

        Test.startTest();
        try {
            LC027_Certiko.creerDossier(p.Id);
            Assert.fail('Une erreur serveur doit etre traduite.');
        } catch (LC027_Certiko.CertikoException e) {
            Assert.isTrue(e.getMessage().startsWith('CERTIKO_REFUS:'), e.getMessage());
            Assert.isTrue(e.getMessage().contains('boom'), e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void reponseIllisibleDonneUnCodeDedie() {
        LC027_TestFactory.bouchonnerCallouts();
        Pro__c p = dossier();
        bouchonner(200, '<html>maintenance</html>');

        Test.startTest();
        try {
            LC027_Certiko.creerDossier(p.Id);
            Assert.fail('Un corps illisible doit etre signale.');
        } catch (LC027_Certiko.CertikoException e) {
            Assert.areEqual('CERTIKO_REPONSE_ILLISIBLE', e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void certikoInjoignableDonneUnCodeDedie() {
        LC027_TestFactory.bouchonnerCallouts();
        Pro__c p = dossier();
        Test.setMock(HttpCalloutMock.class, new BouchonInjoignable());

        Test.startTest();
        try {
            LC027_Certiko.creerDossier(p.Id);
            Assert.fail('Une coupure reseau doit etre traduite.');
        } catch (LC027_Certiko.CertikoException e) {
            Assert.areEqual('CERTIKO_INJOIGNABLE', e.getMessage());
        }
        Test.stopTest();
    }

    /* ════════════════════════════ Vider une colonne ════════════════════════════ */

    /**
     * Fin de visite : l equipe de pose est liberee chez Certiko, sans quoi le
     * creneau resterait reserve a une intervention deja faite. Certiko accepte
     * la chaine vide comme « efface ».
     */
    @isTest
    static void viderColonneEnvoieUneChaineVide() {
        bouchonner(200, JSON.serialize(new Map<String, Object>{
            'dossier_id' => 'abc', 'updated' => new List<Object>(), 'errors' => new List<Object>()
        }));

        Test.startTest();
        LC027_Certiko.viderColonne('7118001276', '_equipe_poseur');
        Test.stopTest();

        Map<String, Object> corps = (Map<String, Object>) JSON.deserializeUntyped(corpsEnvoye);
        Map<String, Object> valeurs = (Map<String, Object>) corps.get('values');
        Assert.isTrue(valeurs.containsKey('_equipe_poseur'), corpsEnvoye);
        Assert.areEqual('', valeurs.get('_equipe_poseur'),
            'La chaine vide est ce que Certiko comprend comme un effacement.');
    }

    @isTest
    static void viderColonneExigeUnDossierEtUneColonne() {
        Test.startTest();
        try {
            LC027_Certiko.viderColonne('', '_equipe_poseur');
            Assert.fail('Sans dossier, rien a vider.');
        } catch (LC027_Certiko.CertikoException e) {
            Assert.areEqual('CERTIKO_SANS_DOSSIER', e.getMessage());
        }
        try {
            LC027_Certiko.viderColonne('7118001276', '');
            Assert.fail('Sans colonne, rien a vider.');
        } catch (LC027_Certiko.CertikoException e) {
            Assert.areEqual('CERTIKO_SANS_DOSSIER', e.getMessage());
        }
        Test.stopTest();
    }

    /* ════════════════════════════ Lien du relevé ════════════════════════════ */

    @isTest
    static void lienTerrainEstConstruitDepuisLeReglage() {
        Test.startTest();
        String lien = LC027_Certiko.lienTerrain('4bce8e1e');
        String vide = LC027_Certiko.lienTerrain(null);
        Test.stopTest();

        Assert.isNull(vide, 'Sans dossier Certiko, il n y a pas de releve a ouvrir.');
        Assert.isTrue(lien.endsWith('4bce8e1e'), lien);
        Assert.isTrue(lien.startsWith(System.Label.CERTIKO_URL_TERRAIN.trim()), lien);
    }
}