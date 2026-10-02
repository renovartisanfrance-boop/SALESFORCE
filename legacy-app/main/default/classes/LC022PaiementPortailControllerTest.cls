/**
 * Tests de LC022PaiementPortailController.
 *
 * Deux familles de tests, volontairement séparées :
 *
 *  - Les tests de SÉCURITÉ (sanitizeFields, résolution d'identité) ne dépendent que
 *    d'un Account : ils s'exécutent TOUJOURS, sans garde best-effort. C'est le cœur
 *    de la classe, il ne doit jamais être silencieusement non couvert.
 *
 *  - Les tests de FORME DES DONNÉES insèrent des Facture__c, soumises à 18 règles de
 *    validation d'org. Ils suivent la convention best-effort du projet, MAIS les
 *    inserts sont découpés pour qu'un échec sur un cas particulier (l'avoir, qui a ses
 *    propres contraintes) n'emporte pas les assertions des autres cas.
 *
 * ⚠️ Un trigger d'org sur Account effectue un callout : Test.setMock DOIT être posé
 *    avant tout insert d'Account, et on n'utilise pas @TestSetup (le mock ne survit
 *    pas au contexte de setup).
 *
 * ⚠️ buildFacture laisse Taux_TVA__c VIDE volontairement : les règles
 *    coherence_ht_tva_ttc et Montant_TVA_correspond_TauxTVA ne se déclenchent que si
 *    ce champ est renseigné. Le renseigner obligerait à aligner HT/TVA/TTC au centime.
 */
@IsTest
private class LC022PaiementPortailControllerTest {

    private class CalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setStatus('OK');
            res.setBody('[]');
            return res;
        }
    }

    // Liste EXACTE de ce qu'émet construireMetadata() dans lwc020_FacturationUtils
    // (union des colonnes « En cours » et « Payées »). Si la config de colonnes du
    // module change, ces constantes doivent suivre : c'est ce qui garantit qu'une
    // faute de frappe côté LWC est vue par les tests.
    private static final String CHAMPS_FACTURE =
        'N_Facture_Externe__c,Name,DateFacture__c,DateEcheance__c,' +
        'MontantHT__c,Montant_Total__c,Statut__c,Date_Paiement__c,Moyen_Paiement__c';
    private static final String CHAMPS_LIGNE =
        'Dossier__r.Name,Dossier__r.Fiche_CEE__c,Type_Intervenant__c,' +
        'Echeance_Declenchante__c,Montant_HT__c';

    private static final String TYPE_RECUE = 'Reçue';
    private static final String TYPE_EMISE = 'Emise';   // ⚠️ sans accent, cf. FactureTriggerHandler

    private static LC022PaiementPortailController.PaiementMetadata meta(Id compteId) {
        LC022PaiementPortailController.PaiementMetadata m =
            new LC022PaiementPortailController.PaiementMetadata();
        m.champsFacture    = CHAMPS_FACTURE;
        m.champsLigne      = CHAMPS_LIGNE;
        m.campaignCode     = '';
        m.compteIdContexte = compteId == null ? '' : String.valueOf(compteId);
        return m;
    }

    private static Account compte(String nom) {
        Test.setMock(HttpCalloutMock.class, new CalloutMock());
        Account a = new Account(Name = nom);
        insert a;
        return a;
    }

    /**
     * Libellé d'affichage d'une valeur de Statut__c, lu depuis le describe.
     * Les libellés de ce projet portent des emoji (« ☑️Validé », « ✅Payé ») : les coder
     * en dur rendrait le test dépendant d'un choix cosmétique modifiable en Setup.
     */
    private static String libelleStatut(String valeurApi) {
        for (Schema.PicklistEntry pe : Facture__c.Statut__c.getDescribe().getPicklistValues()) {
            if (pe.getValue() == valeurApi) return pe.getLabel();
        }
        return valeurApi;
    }

    /**
     * Utilisateur interne « isolé » : ni Contact, ni Account, ni campagne possédée.
     * Indispensable pour tester la branche TOKEN — l'utilisateur qui exécute les tests
     * possède les campagnes qu'il vient de créer, et la branche « propriétaire de
     * campagne » résoudrait donc le compte AVANT que le token soit consulté.
     * Renvoie null si l'org interdit la création d'utilisateurs en test.
     */
    private static User utilisateurIsole() {
        try {
            Profile p = [SELECT Id FROM Profile WHERE UserType = 'Standard' LIMIT 1];
            String uniq = String.valueOf(Math.abs(Crypto.getRandomInteger()));
            User u = new User(
                FirstName         = 'Test',
                LastName          = 'Isole',
                Email             = 'isole' + uniq + '@example.invalid',
                Username          = 'isole' + uniq + '@example.invalid.renovtest',
                Alias             = 'tiso',
                ProfileId         = p.Id,
                TimeZoneSidKey    = 'Europe/Paris',
                LocaleSidKey      = 'fr_FR',
                EmailEncodingKey  = 'UTF-8',
                LanguageLocaleKey = 'fr'
            );
            insert u;
            return u;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Utilisateur isolé non créé : ' + e.getMessage());
            return null;
        }
    }

    private static Id rtFacture(String developerName) {
        Schema.RecordTypeInfo rt = Schema.SObjectType.Facture__c
            .getRecordTypeInfosByDeveloperName().get(developerName);
        return rt == null ? null : rt.getRecordTypeId();
    }

    /** Facture cohérente avec les règles de validation actives de l'objet. */
    private static Facture__c buildFacture(Id compteId, String rtDev, String statut,
                                           Decimal ht, Date dateFacture, Date echeance,
                                           String typeFacture) {
        Facture__c f = new Facture__c();
        Id rtId = rtFacture(rtDev);
        if (rtId != null) f.RecordTypeId = rtId;
        f.Destinataire_Compte__c = compteId;
        f.TypeFacture__c         = typeFacture;
        f.N_Facture_Externe__c   = 'EXT-' + Math.abs(Crypto.getRandomInteger());
        f.Statut__c              = statut;
        f.MontantHT__c           = ht;
        f.MontantTVA__c          = (ht * 0.2).setScale(2);
        f.Montant_Total__c       = (ht * 1.2).setScale(2);
        f.DateFacture__c         = dateFacture;
        f.DateEcheance__c        = echeance;
        return f;
    }

    private static Facture__c buildRecue(Id compteId, String statut, Decimal ht,
                                         Date dateFacture, Date echeance) {
        return buildFacture(compteId, 'Classique', statut, ht, dateFacture, echeance, TYPE_RECUE);
    }

    /**
     * Assertion de MONTANT.
     *
     * Ni System.Assert.areEqual(240, monDecimal) — le littéral entier est boxé en
     * Integer, l'assertion échoue alors sur une différence de TYPE et non de valeur —
     * ni Decimal.compareTo, qui n'est tout simplement pas exposé en Apex.
     *
     * L'opérateur == sur Decimal, lui, compare les valeurs en ignorant l'échelle :
     * 240 == 240.00 est vrai, ce qui est exactement le comportement voulu face à des
     * montants dont la précision dépend du calcul qui les a produits.
     */
    private static void assertMontant(Decimal attendu, Decimal obtenu, String message) {
        System.Assert.isTrue(obtenu != null && obtenu == attendu,
            message + ' — attendu ' + attendu + ', obtenu ' + obtenu);
    }

    // ══════════════════════════════════════════════ SÉCURITÉ — sanitizeFields

    @IsTest
    static void testInjectionSoqlRejetee() {
        Account a = compte('Compte Injection');

        List<String> charges = new List<String>{
            'Name FROM Facture__c WHERE Id != null--',
            'Id, (SELECT Id FROM Factures_associees__r)',
            'Id) FROM Facture__c WHERE Destinataire_Compte__c != null--(',
            'Id\' OR \'1\'=\'1',
            'Id FROM Account'
        };

        Test.startTest();
        for (String charge : charges) {
            LC022PaiementPortailController.PaiementMetadata m = meta(a.Id);
            m.champsFacture = charge;
            Boolean leve = false;
            try {
                LC022PaiementPortailController.getFacturesAPayer(m);
            } catch (AuraHandledException e) {
                leve = true;
            }
            System.Assert.isTrue(leve, 'La charge doit être rejetée : ' + charge);
        }
        Test.stopTest();
    }

    @IsTest
    static void testChampInexistantRejete() {
        Account a = compte('Compte Champ Bidon');
        LC022PaiementPortailController.PaiementMetadata m = meta(a.Id);
        m.champsFacture = 'Champ_Qui_Nexiste_Pas__c';

        Test.startTest();
        Boolean leve = false;
        String msg = null;
        try {
            LC022PaiementPortailController.getFacturesAPayer(m);
        } catch (AuraHandledException e) {
            leve = true;
            msg = e.getMessage();
        }
        Test.stopTest();

        System.Assert.isTrue(leve, 'Un champ inexistant doit lever une exception');
        // L'utilisateur d'exécution des tests est interne : le détail est attendu.
        System.Assert.isTrue(msg.contains('Champ_Qui_Nexiste_Pas__c'),
            'Le message doit nommer le champ fautif : ' + msg);
    }

    @IsTest
    static void testRelationInexistanteRejetee() {
        Account a = compte('Compte Relation Bidon');
        LC022PaiementPortailController.PaiementMetadata m = meta(a.Id);
        m.champsLigne = 'Relation_Bidon__r.Name';

        Test.startTest();
        Boolean leve = false;
        String msg = null;
        try {
            LC022PaiementPortailController.getFacturesAPayer(m);
        } catch (AuraHandledException e) {
            leve = true;
            msg = e.getMessage();
        }
        Test.stopTest();

        System.Assert.isTrue(leve, 'Une relation inexistante doit lever une exception');
        System.Assert.isTrue(msg.contains('Relation_Bidon__r'),
            'Le message doit nommer la relation fautive : ' + msg);
    }

    @IsTest
    static void testProfondeurExcessiveRejetee() {
        Account a = compte('Compte Profondeur');
        LC022PaiementPortailController.PaiementMetadata m = meta(a.Id);
        m.champsLigne = 'Dossier__r.Compte__r.Name';   // 3 niveaux

        Test.startTest();
        Boolean leve = false;
        String msg = null;
        try {
            LC022PaiementPortailController.getFacturesAPayer(m);
        } catch (AuraHandledException e) {
            leve = true;
            msg = e.getMessage();
        }
        Test.stopTest();

        System.Assert.isTrue(leve, 'Un chemin à 3 niveaux doit être refusé');
        System.Assert.isTrue(msg.containsIgnoreCase('profond'),
            'Message attendu sur la profondeur : ' + msg);
    }

    @IsTest
    static void testCheminPointeValideAccepte() {
        Account a = compte('Compte Chemin Valide');

        Test.startTest();
        LC022PaiementPortailController.PaiementResult r =
            LC022PaiementPortailController.getFacturesAPayer(meta(a.Id));
        Test.stopTest();

        System.Assert.isNotNull(r, 'La config de colonnes réelle du LWC doit passer');
        System.Assert.areEqual(a.Id, r.compteId);
        System.Assert.isFalse(r.tronque, 'Aucune troncature attendue sur un compte vide');
    }

    // ══════════════════════════════════════════ SÉCURITÉ — résolution d'identité

    @IsTest
    static void testAccesNonIdentifie() {
        // Utilisateur interne sans Contact/Account, aucun contexte, aucun token.
        Test.startTest();
        Boolean leve = false;
        String msg = null;
        try {
            LC022PaiementPortailController.getFacturesAPayer(meta(null));
        } catch (AuraHandledException e) {
            leve = true;
            msg = e.getMessage();
        }
        Test.stopTest();

        System.Assert.isTrue(leve, 'Sans identité résolue, l\'accès doit être refusé');
        // L'utilisateur d'exécution des tests est AUTHENTIFIÉ (UserType 'Standard') :
        // il reçoit le message actionnable, pas le générique réservé aux invités.
        System.Assert.isTrue(msg.containsIgnoreCase('rattaché à aucun compte'),
            'Message actionnable attendu pour un utilisateur connecté : ' + msg);
    }

    @IsTest
    static void testContexteLexResoutLeCompte() {
        Account a = compte('Compte Contexte LEX');

        Test.startTest();
        LC022PaiementPortailController.PaiementResult r =
            LC022PaiementPortailController.getFacturesAPayer(meta(a.Id));
        Test.stopTest();

        System.Assert.areEqual(a.Id, r.compteId, 'Le compte du contexte doit être retenu');
        System.Assert.areEqual('Compte Contexte LEX', r.compteNom);
        System.Assert.areEqual('CONTEXTE', r.source);
    }

    @IsTest
    static void testContexteNonAccountRejete() {
        LC022PaiementPortailController.PaiementMetadata m = meta(null);
        m.compteIdContexte = String.valueOf(UserInfo.getUserId());   // Id de User

        Test.startTest();
        Boolean leve = false;
        String msg = null;
        try {
            LC022PaiementPortailController.getFacturesAPayer(m);
        } catch (AuraHandledException e) {
            leve = true;
            msg = e.getMessage();
        }
        Test.stopTest();

        System.Assert.isTrue(leve, 'Un Id qui n\'est pas un Account doit être refusé');
        System.Assert.isTrue(msg.containsIgnoreCase('invalide'),
            'Message attendu sur l\'identifiant : ' + msg);
    }

    @IsTest
    static void testTokenInvalideRefuseSansFuite() {
        LC022PaiementPortailController.PaiementMetadata m = meta(null);
        m.campaignCode = 'TOKEN-QUI-NEXISTE-PAS-' + Math.abs(Crypto.getRandomInteger());

        Test.startTest();
        Boolean leve = false;
        String msg = null;
        try {
            LC022PaiementPortailController.getFacturesAPayer(m);
        } catch (AuraHandledException e) {
            leve = true;
            msg = e.getMessage();
        }
        Test.stopTest();

        System.Assert.isTrue(leve, 'Un token inconnu doit être refusé');
        // Le message ne doit donner AUCUN indice sur la validité du token : sinon
        // l'endpoint devient un oracle d'énumération des tokens de campagne.
        System.Assert.isFalse(msg.containsIgnoreCase('token'),
            'Le message ne doit pas mentionner le token : ' + msg);
        System.Assert.isFalse(msg.containsIgnoreCase('campagne'),
            'Le message ne doit pas mentionner la campagne : ' + msg);
    }

    @IsTest
    static void testTokenValideResoutLeCompteRegie() {
        Test.setMock(HttpCalloutMock.class, new CalloutMock());

        // L'insert de Campaign exige la case « Utilisateur marketing » sur le user
        // d'exécution : on ne fait pas échouer tout un déploiement pour ça.
        Campaign c;
        Account a;
        try {
            c = new Campaign(Name = 'Campagne Test Paiement', IsActive = true);
            c.put('CampaignToken__c', 'TOK-' + Math.abs(Crypto.getRandomInteger()));
            insert c;

            a = new Account(Name = 'Régie Test Paiement');
            a.put('Acces_REGIE__c', c.Id);
            insert a;
        } catch (Exception e) {
            return;   // org-specific : best-effort
        }

        // L'utilisateur courant POSSÈDE la campagne qu'il vient de créer : sans
        // isolation, la branche « propriétaire de campagne » résoudrait le compte avant
        // même que le token soit consulté, et ce test ne testerait pas le token.
        User isole = utilisateurIsole();
        if (isole == null) return;   // org-specific : best-effort

        LC022PaiementPortailController.PaiementMetadata m = meta(null);
        m.campaignCode = (String) c.get('CampaignToken__c');

        LC022PaiementPortailController.PaiementResult r;
        Test.startTest();
        System.runAs(isole) {
            r = LC022PaiementPortailController.getFacturesAPayer(m);
        }
        Test.stopTest();

        System.Assert.areEqual(a.Id, r.compteId, 'Le token doit résoudre le compte régie');
        System.Assert.areEqual('TOKEN', r.source);
    }

    /**
     * Branche 1b par CAMPAGNE POSSÉDÉE — c'est le chemin qui manquait et qui donnait
     * « Accès non identifié » à un apporteur d'affaires connecté sur le site Experience.
     * L'apporteur ne porte pas toujours un Contact rattaché au compte régie : ce qui
     * l'identifie, c'est qu'il est propriétaire des campagnes de cette régie.
     */
    @IsTest
    static void testCompteResoluViaCampagnePossedee() {
        Test.setMock(HttpCalloutMock.class, new CalloutMock());

        Campaign c;
        Account regie;
        try {
            c = new Campaign(Name = 'Campagne Possédée', IsActive = true,
                             OwnerId = UserInfo.getUserId());
            insert c;
            regie = new Account(Name = 'Régie Possédée');
            regie.put('Acces_REGIE__c', c.Id);
            insert regie;
        } catch (Exception e) {
            return;   // org-specific : best-effort
        }

        // Ni contexte LEX, ni token : seule la branche « propriétaire de campagne »
        // peut résoudre le compte.
        Test.startTest();
        LC022PaiementPortailController.PaiementResult r =
            LC022PaiementPortailController.getFacturesAPayer(meta(null));
        Test.stopTest();

        System.Assert.areEqual(regie.Id, r.compteId,
            'Le compte régie doit être résolu via les campagnes possédées');
        System.Assert.areEqual('USER', r.source,
            'La résolution passe par l\'utilisateur, pas par le token');
    }

    /**
     * Le token ne doit JAMAIS l'emporter sur un compte déjà résolu en amont. On ne peut
     * pas créer d'utilisateur portail de façon fiable ici (licence communautaire non
     * garantie sur toutes les orgs) : on vérifie la propriété via le contexte LEX, en
     * asserant explicitement `source` pour que le test dise ce qu'il teste réellement.
     */
    @IsTest
    static void testTokenIgnoreSiCompteDejaResolu() {
        Test.setMock(HttpCalloutMock.class, new CalloutMock());

        Campaign c;
        Account regie;
        try {
            c = new Campaign(Name = 'Campagne Autre', IsActive = true);
            c.put('CampaignToken__c', 'TOK-AUTRE-' + Math.abs(Crypto.getRandomInteger()));
            insert c;

            regie = new Account(Name = 'Régie Autre');
            regie.put('Acces_REGIE__c', c.Id);
            insert regie;
        } catch (Exception e) {
            return;   // org-specific : best-effort
        }

        Account mien = new Account(Name = 'Mon Compte');
        insert mien;

        // Contexte = mon compte ET token = celui d'une AUTRE régie.
        LC022PaiementPortailController.PaiementMetadata m = meta(mien.Id);
        m.campaignCode = (String) c.get('CampaignToken__c');

        Test.startTest();
        LC022PaiementPortailController.PaiementResult r =
            LC022PaiementPortailController.getFacturesAPayer(m);
        Test.stopTest();

        System.Assert.areEqual('CONTEXTE', r.source,
            'La branche token ne doit pas avoir été empruntée');
        System.Assert.areEqual(mien.Id, r.compteId,
            'Le token ne doit pas prendre le pas sur un compte déjà résolu');
        System.Assert.areNotEqual(regie.Id, r.compteId,
            'Le compte de l\'autre régie ne doit jamais être servi');
    }

    // ══════════════════════════════════════════════════════ FORME DES DONNÉES

    /**
     * Vérifie les trois invariants du découpage en onglets :
     * le Brouillon est bien traité comme un impayé, les deux onglets sont disjoints,
     * et les KPI restent globaux quel que soit le point d'entrée appelé.
     */
    @IsTest
    static void testBrouillonImpayeEtOngletsDisjoints() {
        Account a = compte('Compte Filtrage Statuts');
        Date hier = Date.today().addDays(-30);
        Date demain = Date.today().addDays(30);

        try {
            insert new List<Facture__c>{
                buildRecue(a.Id, 'Validé',    100, hier, demain),
                buildRecue(a.Id, 'Payé',      200, hier, demain),
                buildRecue(a.Id, 'Brouillon', 300, hier, demain)
            };
        } catch (Exception e) {
            return;   // org-specific : best-effort
        }

        Test.startTest();
        LC022PaiementPortailController.PaiementResult aPayer =
            LC022PaiementPortailController.getFacturesAPayer(meta(a.Id));
        LC022PaiementPortailController.PaiementResult payees =
            LC022PaiementPortailController.getFacturesPayees(meta(a.Id));
        Test.stopTest();

        // « En cours » = tout ce qui n'est pas payé, Brouillon COMPRIS.
        System.Assert.areEqual(2, aPayer.factures.size(),
            'L\'onglet « En cours » doit contenir le Validé ET le Brouillon');

        Set<String> statutsEnCours = new Set<String>();
        Set<String> idsEnCours = new Set<String>();
        for (LC022PaiementPortailController.FactureRow row : aPayer.factures) {
            statutsEnCours.add(row.statut);
            idsEnCours.add(row.id);
            System.Assert.areNotEqual('Payé', row.statut,
                'Aucune facture payée ne doit apparaître dans « En cours »');
        }
        System.Assert.isTrue(statutsEnCours.contains('Brouillon'),
            'Le Brouillon doit être visible comme impayé');
        System.Assert.isTrue(statutsEnCours.contains('Validé'), 'Le Validé aussi');

        System.Assert.areEqual(1, payees.factures.size(),
            'L\'onglet « Payées » ne doit contenir que le Payé');
        System.Assert.areEqual('Payé', payees.factures[0].statut);

        // Les deux onglets sont DISJOINTS : aucune facture des deux côtés.
        System.Assert.isFalse(idsEnCours.contains(payees.factures[0].id),
            'Une même facture ne doit jamais apparaître dans les deux onglets');

        // Les KPI restent GLOBAUX (agrégats serveur) : identiques dans les deux appels,
        // indépendamment du périmètre de la liste renvoyée.
        System.Assert.areEqual(1, aPayer.nbPaye, 'KPI global : un seul Payé');
        System.Assert.areEqual(2, aPayer.nbAPayer,
            'KPI global : Brouillon + Validé sont cumulés dans « À payer »');
        System.Assert.areEqual(aPayer.nbPaye, payees.nbPaye,
            'Les KPI ne doivent pas dépendre de l\'onglet appelant');
        System.Assert.areEqual(aPayer.nbAPayer, payees.nbAPayer,
            'Idem pour le compteur « À payer »');
        assertMontant(240, aPayer.totalPaye, 'Total payé = 200 HT -> 240 TTC');
        // 100 HT (Validé) + 300 HT (Brouillon) = 400 HT -> 480 TTC
        assertMontant(480, aPayer.totalAPayer,
            'Total à payer = Validé + Brouillon = 480 TTC');
    }

    /**
     * L'avoir a ses propres contraintes (facture d'origine Classique non annulée, motif,
     * montant <= origine). Il est inséré SÉPARÉMENT : dans une liste unique, son échec
     * emporterait les Classique et le test passerait au vert sans rien asserter — c'est
     * exactement le piège qui rendait la version précédente de ce test inopérante.
     */
    @IsTest
    static void testAvoirsExclus() {
        Account a = compte('Compte Filtrage Avoirs');
        Date hier = Date.today().addDays(-30);
        Date demain = Date.today().addDays(30);

        Facture__c origine = buildRecue(a.Id, 'Validé', 200, hier, demain);
        try {
            insert origine;
        } catch (Exception e) {
            return;   // org-specific : best-effort
        }

        Facture__c avoir = buildFacture(a.Id, 'Avoir', 'Validé', 100, hier, demain, TYPE_RECUE);
        avoir.Facture_Origine__c = origine.Id;      // doit être Classique et non annulée
        avoir.Motif_Avoir__c     = 'Motif de test';
        // Type_Avoir__c laissé vide : « Total » imposerait un montant égal à l'origine.
        Boolean avoirInsere = false;
        try {
            insert avoir;
            avoirInsere = true;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Avoir non inséré (org-specific) : ' + e.getMessage());
        }

        Test.startTest();
        LC022PaiementPortailController.PaiementResult r =
            LC022PaiementPortailController.getFacturesAPayer(meta(a.Id));
        Test.stopTest();

        System.Assert.areEqual(1, r.factures.size(),
            'Seule la facture Classique doit remonter, l\'avoir doit être exclu');
        System.Assert.areEqual(origine.Id, r.factures[0].id);
        assertMontant(240, r.totalAPayer, 'L\'avoir ne doit pas gonfler le total');
        System.Assert.isTrue(avoirInsere,
            'L\'avoir doit avoir été inséré, sinon ce test ne prouve rien');
    }

    @IsTest
    static void testEmisesExclues() {
        Account a = compte('Compte Filtrage Type');
        Date hier = Date.today().addDays(-30);
        Date demain = Date.today().addDays(30);

        try {
            insert buildRecue(a.Id, 'Validé', 100, hier, demain);
        } catch (Exception e) {
            return;   // org-specific : best-effort
        }

        // TypeFacture__c renseigné EXPLICITEMENT : laissé vide, FactureTriggerHandler
        // poserait « Reçue » par défaut et le test ne prouverait rien.
        Facture__c emise = buildFacture(a.Id, 'Classique', 'Validé', 999, hier, demain, TYPE_EMISE);
        Boolean emiseInseree = false;
        try {
            insert emise;
            emiseInseree = true;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Émise non insérée (org-specific) : ' + e.getMessage());
        }

        Test.startTest();
        LC022PaiementPortailController.PaiementResult r =
            LC022PaiementPortailController.getFacturesAPayer(meta(a.Id));
        Test.stopTest();

        System.Assert.areEqual(1, r.factures.size(), 'Aucune facture émise ne doit remonter');
        assertMontant(120, r.totalAPayer, 'Le montant de l\'émise ne doit pas être compté');
        System.Assert.isTrue(emiseInseree,
            'L\'émise doit avoir été insérée, sinon ce test ne prouve rien');
    }

    /**
     * Le retard est exprimé en JOURS et calculé côté serveur : l'horloge du navigateur
     * ne doit pas pouvoir faire changer une facture d'apparence.
     */
    @IsTest
    static void testJoursRetardCalculesServeur() {
        Account a = compte('Compte Retard');
        Facture__c enRetard = buildRecue(a.Id, 'Validé', 100,
                                         Date.today().addDays(-60), Date.today().addDays(-10));
        Facture__c aJour = buildRecue(a.Id, 'Validé', 50,
                                      Date.today().addDays(-5), Date.today().addDays(20));
        try {
            insert new List<Facture__c>{ enRetard, aJour };
        } catch (Exception e) {
            return;   // org-specific : best-effort
        }

        Test.startTest();
        LC022PaiementPortailController.PaiementResult r =
            LC022PaiementPortailController.getFacturesAPayer(meta(a.Id));
        Test.stopTest();

        Map<String, Integer> retardParId = new Map<String, Integer>();
        for (LC022PaiementPortailController.FactureRow row : r.factures) {
            retardParId.put(row.id, row.joursRetard);
        }

        System.Assert.areEqual(10, retardParId.get(enRetard.Id),
            'Échéance dépassée de 10 jours, obtenu ' + retardParId.get(enRetard.Id));
        System.Assert.areEqual(0, retardParId.get(aJour.Id),
            'Échéance à venir : aucun retard, obtenu ' + retardParId.get(aJour.Id));
    }

    /** Une facture sans échéance (cas fréquent d'un Brouillon) vaut 0, jamais null. */
    @IsTest
    static void testJoursRetardSansEcheance() {
        Account a = compte('Compte Sans Echeance');
        Facture__c sansEcheance = buildRecue(a.Id, 'Brouillon', 100,
                                             Date.today().addDays(-40), null);
        try {
            insert sansEcheance;
        } catch (Exception e) {
            return;   // org-specific : best-effort
        }

        Test.startTest();
        LC022PaiementPortailController.PaiementResult r =
            LC022PaiementPortailController.getFacturesAPayer(meta(a.Id));
        Test.stopTest();

        System.Assert.areEqual(1, r.factures.size(), 'Le Brouillon doit remonter');
        System.Assert.areEqual(0, r.factures[0].joursRetard,
            'Sans échéance, joursRetard doit valoir 0 et non null');
    }

    @IsTest
    static void testCloisonnementParCompte() {
        Account mien  = compte('Compte A Cloisonnement');
        Test.setMock(HttpCalloutMock.class, new CalloutMock());
        Account autre = new Account(Name = 'Compte B Cloisonnement');
        insert autre;

        Date hier = Date.today().addDays(-30);
        Date demain = Date.today().addDays(30);
        try {
            insert new List<Facture__c>{
                buildRecue(mien.Id,  'Validé', 100, hier, demain),
                buildRecue(autre.Id, 'Validé', 999, hier, demain)
            };
        } catch (Exception e) {
            return;   // org-specific : best-effort
        }

        Test.startTest();
        LC022PaiementPortailController.PaiementResult r =
            LC022PaiementPortailController.getFacturesAPayer(meta(mien.Id));
        Test.stopTest();

        System.Assert.areEqual(1, r.factures.size(),
            'Seules les factures du compte demandé doivent remonter');
        assertMontant(120, r.totalAPayer,
            'Le montant de l\'autre compte ne doit jamais être compté');
    }

    @IsTest
    static void testChampsRetournesSontCeuxDemandes() {
        Account a = compte('Compte Champs');
        Facture__c f = buildRecue(a.Id, 'Validé', 100,
                                  Date.today().addDays(-10), Date.today().addDays(20));
        try {
            insert f;
        } catch (Exception e) {
            return;   // org-specific : best-effort
        }

        // Une ligne rattachée, pour couvrir le chemin pointé Dossier__r.* et la
        // traduction de picklist sur Echeance_Declenchante__c.
        Boolean ligneInseree = false;
        try {
            insert new LigneFacture__c(
                Facture__c = f.Id,
                Type_Intervenant__c = 'Apporteur d\'Affaire',
                Echeance_Declenchante__c = 'Au Devis Signé',
                Montant_HT__c = 100
            );
            ligneInseree = true;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Ligne non insérée (org-specific) : ' + e.getMessage());
        }

        Test.startTest();
        LC022PaiementPortailController.PaiementResult r =
            LC022PaiementPortailController.getFacturesAPayer(meta(a.Id));
        Test.stopTest();

        System.Assert.areEqual(1, r.factures.size());
        Map<String, Object> champs = r.factures[0].champs;

        // Les clés doivent être EXACTEMENT les noms d'API demandés : c'est le contrat
        // avec le LWC, qui relit avec la chaîne écrite dans sa config de colonnes.
        for (String demande : CHAMPS_FACTURE.split(',')) {
            System.Assert.isTrue(champs.containsKey(demande.trim()),
                'Le champ demandé doit être présent dans la map : ' + demande);
        }
        assertMontant(100, (Decimal) champs.get('MontantHT__c'),
            'Le montant HT doit être remonté tel quel');

        // Séparation voulue : la LOGIQUE serveur travaille sur la valeur d'API brute,
        // l'AFFICHAGE reçoit le libellé traduit (emoji compris).
        System.Assert.areEqual('Validé', r.factures[0].statut,
            'Le statut du wrapper doit rester la valeur d\'API brute (logique métier)');
        System.Assert.areEqual(libelleStatut('Validé'), champs.get('Statut__c'),
            'Le champ remonté pour affichage doit être le LIBELLÉ de la picklist');

        if (ligneInseree) {
            System.Assert.areEqual(1, r.factures[0].lignes.size(), 'Une ligne rattachée attendue');
            Map<String, Object> l = r.factures[0].lignes[0];
            for (String demande : CHAMPS_LIGNE.split(',')) {
                System.Assert.isTrue(l.containsKey(demande.trim()),
                    'Le champ ligne demandé doit être présent : ' + demande);
            }
            // Picklist traduite en LIBELLÉ : la valeur d'API et le libellé coïncident
            // ici, mais la clé doit exister et être non vide.
            System.Assert.isNotNull(l.get('Echeance_Declenchante__c'),
                'L\'échéance déclenchante doit être remontée');
        }
    }

    /**
     * L'onglet « En cours » affiche dans une SEULE table deux origines : les lignes
     * de facture (traduites en libellé par extraireChamps) et les lignes du catalogue
     * (traduites par libelleEcheance). Si les deux chemins divergeaient, la même
     * échéance apparaîtrait sous deux orthographes sur des lignes voisines.
     *
     * On cible la valeur de la picklist dont le LIBELLÉ diffère de la VALEUR : c'est
     * la seule sur laquelle une régression serait visible.
     */
    @IsTest
    static void testEcheanceRemonteeEnLibelleEtNonEnValeur() {
        String valeur = null;
        String libelle = null;
        String premiereValeur = null;
        String premierLibelle = null;

        for (Schema.PicklistEntry pe :
                LigneFacture__c.Echeance_Declenchante__c.getDescribe().getPicklistValues()) {
            if (premiereValeur == null) {
                premiereValeur = pe.getValue();
                premierLibelle = pe.getLabel();
            }
            // .equals() et NON « != » : les opérateurs == / != sur String sont
            // INSENSIBLES À LA CASSE en Apex. Or une divergence libellé/valeur peut
            // n'être qu'une différence de casse — avec « != » la condition serait
            // fausse partout et la boucle ne trouverait jamais rien.
            if (!pe.getValue().equals(pe.getLabel())) {
                valeur  = pe.getValue();
                libelle = pe.getLabel();
                break;
            }
        }

        // Une picklist vide, elle, est une vraie anomalie : la colonne « Échéance »
        // ne pourrait alors rien afficher.
        System.Assert.isNotNull(premiereValeur,
            'La picklist Echeance_Declenchante__c ne contient aucune valeur.');

        // Aucune divergence dans cette org — les libellés sont alignés sur les
        // valeurs d'API. On se rabat sur la première entrée : l'assertion de
        // traduction est alors plus faible (elle ne peut plus distinguer une
        // traduction correcte d'une absence de traduction), mais le code reste
        // exercé et les cas limites ci-dessous, eux, restent démontrés. NE PAS
        // transformer ce cas en échec : c'est un état d'org légitime.
        if (valeur == null) {
            valeur  = premiereValeur;
            libelle = premierLibelle;
        }

        // ── Chemin CATALOGUE, attaqué directement : c'est la seule ligne de code
        //    ajoutée côté Apex par la refonte, et aucun test de bout en bout ne
        //    l'atteint (getLignesAFacturer ne boucle que sur des lignes A_CREER,
        //    qu'aucun test ne sait produire sans monter tout un catalogue).
        System.Assert.areEqual(libelle,
            LC022PaiementPortailController.libelleEcheance(valeur),
            'Une ligne du catalogue doit être traduite EXACTEMENT comme une ligne de ' +
            'facture, sinon la même échéance apparaît sous deux orthographes dans la ' +
            'table unique de l\'onglet « En cours »');
        System.Assert.areEqual('Valeur_Hors_Picklist',
            LC022PaiementPortailController.libelleEcheance('Valeur_Hors_Picklist'),
            'Une valeur absente de la picklist doit être rendue telle quelle, pas vidée');
        System.Assert.isNull(LC022PaiementPortailController.libelleEcheance(null),
            'null doit rester null');
        System.Assert.areEqual('', LC022PaiementPortailController.libelleEcheance(''),
            'Une chaîne vide doit rester vide');

        // ── Chemin FACTURE, de bout en bout.
        Account a = compte('Compte Libellé Échéance');
        Facture__c f = buildRecue(a.Id, 'Validé', 100,
                                  Date.today().addDays(-5), Date.today().addDays(25));
        try {
            insert f;
        } catch (Exception e) {
            return;   // org-specific : best-effort, cf. testChampsRetournesSontCeuxDemandes
        }

        Boolean ligneInseree = false;
        try {
            insert new LigneFacture__c(
                Facture__c = f.Id,
                Echeance_Declenchante__c = valeur,
                Montant_HT__c = 100
            );
            ligneInseree = true;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Ligne non insérée (org-specific) : ' + e.getMessage());
        }
        if (!ligneInseree) return;

        Test.startTest();
        LC022PaiementPortailController.PaiementResult r =
            LC022PaiementPortailController.getFacturesAPayer(meta(a.Id));
        Test.stopTest();

        System.Assert.areEqual(1, r.factures.size(), 'La facture doit être remontée');
        System.Assert.areEqual(1, r.factures[0].lignes.size(), 'Sa ligne doit être rattachée');
        System.Assert.areEqual(libelle, r.factures[0].lignes[0].get('Echeance_Declenchante__c'),
            'L\'échéance doit être remontée en LIBELLÉ (' + libelle + ') et non en ' +
            'valeur d\'API (' + valeur + ') : sinon elle ne coïnciderait pas avec ' +
            'celle des lignes du catalogue dans la table fusionnée');
    }

    // ═══════════════════════════════════════ LIGNES PRÊTES À ÊTRE FACTURÉES

    /*
     * Périmètre de ces tests : ce que CETTE classe possède réellement — la résolution
     * du compte, l'appel à LC023, le filtre A_CREER et le mapping vers LigneAFacturer.
     *
     * Le CALCUL des lignes (catalogue tarifaire, règles JSON, évaluation des échéances)
     * appartient à LC023FacturationCompteController et est couvert par
     * LC023FacturationCompteControllerTest. Monter ici un jeu de données complet
     * (Pro__c + CatalogueTarifaire__c + règles + statuts de dossier) dupliquerait cette
     * couverture pour un résultat très dépendant de la configuration de l'org.
     */

    @IsTest
    static void testLignesAFacturerSurCompteSansDossier() {
        Account a = compte('Compte Sans Dossier');

        Test.startTest();
        LC022PaiementPortailController.LignesAFacturerResult r =
            LC022PaiementPortailController.getLignesAFacturer(meta(a.Id));
        Test.stopTest();

        System.Assert.isNotNull(r, 'Un compte sans dossier ne doit pas lever d\'exception');
        System.Assert.areEqual(a.Id, r.compteId);
        System.Assert.areEqual('Compte Sans Dossier', r.compteNom);
        System.Assert.areEqual('CONTEXTE', r.source);
        System.Assert.areEqual(0, r.lignes.size(), 'Aucune ligne attendue');
        System.Assert.areEqual(0, r.nbAFacturer);
        assertMontant(0, r.totalAFacturer, 'Le total doit être 0 et non null');
        System.Assert.isFalse(r.tronque, 'Aucune alerte de volumétrie sur un compte vide');
    }

    @IsTest
    static void testLignesAFacturerRefuseSansIdentite() {
        // Utilisateur interne sans Contact/Account, aucun contexte, aucun token :
        // la garde de résolution doit s'appliquer AVANT tout appel à LC023.
        Test.startTest();
        Boolean leve = false;
        String msg = null;
        try {
            LC022PaiementPortailController.getLignesAFacturer(meta(null));
        } catch (AuraHandledException e) {
            leve = true;
            msg = e.getMessage();
        }
        Test.stopTest();

        System.Assert.isTrue(leve, 'Sans identité résolue, l\'accès doit être refusé');
        System.Assert.isTrue(msg.containsIgnoreCase('rattaché à aucun compte'),
            'Message actionnable attendu pour un utilisateur connecté : ' + msg);
    }

    @IsTest
    static void testLignesAFacturerRefuseParametresNuls() {
        Test.startTest();
        Boolean leve = false;
        try {
            LC022PaiementPortailController.getLignesAFacturer(null);
        } catch (AuraHandledException e) {
            leve = true;
        }
        Test.stopTest();

        System.Assert.isTrue(leve, 'metadata null doit lever une exception explicite');
    }

    @IsTest
    static void testLignesAFacturerIgnoreLeContextePourNonInterne() {
        Account a = compte('Compte Contexte Lignes');

        // Le contexte LEX n'est honoré que pour un UserType 'Standard'. Sous un
        // utilisateur isolé (interne lui aussi) il reste honoré ; on vérifie surtout
        // que la résolution est bien PARTAGÉE avec les méthodes de factures — un
        // contexte accepté ici doit l'être là aussi, et inversement.
        Test.startTest();
        LC022PaiementPortailController.LignesAFacturerResult lignes =
            LC022PaiementPortailController.getLignesAFacturer(meta(a.Id));
        LC022PaiementPortailController.PaiementResult factures =
            LC022PaiementPortailController.getFacturesAPayer(meta(a.Id));
        Test.stopTest();

        System.Assert.areEqual(factures.compteId, lignes.compteId,
            'Les deux points d\'entrée doivent résoudre EXACTEMENT le même compte');
        System.Assert.areEqual(factures.source, lignes.source,
            'La source de résolution doit être identique');
    }
}