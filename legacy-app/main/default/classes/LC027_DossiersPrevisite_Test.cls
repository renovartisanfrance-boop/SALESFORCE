/**
 * LC027_DossiersPrevisite_Test — visites du pré-visiteur (portail Gestion Prévisites).
 *
 * CE QUI EST VÉRIFIÉ — d'abord QUI voit quoi : le portail n'a pas
 * d'utilisateur, un token de campagne tient lieu d'identité, et c'est la SEULE
 * barrière entre un pré-visiteur et les dossiers des autres. Puis les écritures,
 * qui doivent toutes rester compatibles des règles de validation de Pro__c
 * (PREVISITE3_OUI, PREVISITE4_OUI) : un rendu de visite PLANIFIÉE ne peut pas
 * se contenter de vider le pré-visiteur.
 *
 * BOUCHON D'APPELS SORTANTS AVANT TOUT DML — les triggers de Compte et de
 * Dossier émettent des appels sortants (géocodage, synchronisation). Sans
 * bouchon, la simple création du jeu de données fait échouer le test sur une
 * erreur qui ne désigne pas le code testé.
 *
 * HISTORIQUE — Salesforce ne crée AUCUN enregistrement d'historique pendant un
 * test : getHistorique ne peut donc rendre qu'une liste vide. La mise en forme
 * est vérifiée à part, en passant les lignes directement à versEvenements.
 */
@isTest
private class LC027_DossiersPrevisite_Test {

    private static final String TOKEN = 'token-visites';
    /** Pro__c.PREVISITE_Statut__c — « la prévisite est nécessaire ». */
    private static final String PREVISITE_NECESSAIRE = 'OUI';
    /**
     * Nom du compte tel que le portail le construit : le filtre de recherche du
     * lookup Pré-visiteur impose le préfixe, et le motif d'un rendu le reprend.
     */
    private static final String NOM_COMPTE =
        LC027_Roles.prefixeCompte(LC027_Roles.PREVISITEUR) + 'Test Previsiteur';

    /* ════════════════════════════ Jeu de données ════════════════════════════ */

    /** Campagne pré-visiteur SIGNÉE : le portail reste verrouillé sans cela. */
    private static Campaign campagne(String token, String pays) {
        Campaign c = LC027_TestFactory.previsiteur(
            token, LC027_GestionContrat.STATUT_SIGNE, true);
        if (pays != null) {
            c.Pays__c = pays;
            update c;
        }
        return c;
    }

    /**
     * Compte du pré-visiteur, construit comme PrevisiteController le fait :
     * RecordType « Client » (l'org a les comptes personnels activés, un compte
     * sans type d'enregistrement d'entreprise refuserait le champ Name).
     */
    private static Account comptePrevisiteur(Campaign c) {
        return compte(c, NOM_COMPTE);
    }

    private static Account compte(Campaign c, String nom) {
        Account a = new Account(
            Name = nom,
            Type_Intervenant__c = LC027_Roles.PREVISITEUR,
            Acces_REGIE__c = c.Id
        );
        List<RecordType> rts = [
            SELECT Id FROM RecordType
            WHERE SObjectType = 'Account' AND DeveloperName = 'Client'
            LIMIT 1
        ];
        if (!rts.isEmpty()) {
            a.RecordTypeId = rts[0].Id;
        }
        insert a;
        return a;
    }

    /**
     * Dossier à planifier : « Passage Demandé » SANS date, sans quoi
     * PREVISITE3_OUI refuse l'enregistrement.
     */
    private static Pro__c aPlanifier(Account compte, String nom, String codePostal) {
        Pro__c p = new Pro__c(
            Name = nom,
            // Sans « OUI », l'automatisation pose « NON » et PREVISITE1_NON
            // exige alors un dossier sans pré-visiteur ni date.
            PREVISITE_Statut__c = PREVISITE_NECESSAIRE,
            LOOKUP_Pre_visiteur__c = compte.Id,
            Pr_visite_Statut__c = LC027_DossiersPrevisite.STATUT_DEMANDE,
            Client_Adresse_Chantier__c = 'Calle Mayor 14,,' + codePostal + ',PALENCIA',
            CodePostal__c = codePostal,
            Phone__c = '612345678'
        );
        insert p;
        return p;
    }

    /** Dossier planifié : « Passage Planifié » EXIGE pré-visiteur ET date. */
    private static Pro__c planifie(Account compte, String nom) {
        Pro__c p = new Pro__c(
            Name = nom,
            PREVISITE_Statut__c = PREVISITE_NECESSAIRE,
            LOOKUP_Pre_visiteur__c = compte.Id,
            Pr_visite_Statut__c = LC027_DossiersPrevisite.STATUT_PLANIFIE,
            PREVISITE_Date__c = System.now().addDays(2),
            Client_Adresse_Chantier__c = 'Calle Real 7,,49001,ZAMORA',
            CodePostal__c = '49001',
            Phone__c = '612345679'
        );
        insert p;
        return p;
    }

    private static String iso(Datetime quand) {
        return quand.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
    }

    /* ════════════════════════════ Lecture ════════════════════════════ */

    @isTest
    static void listeSepareAPlanifierEtPlanifiees() {
        LC027_TestFactory.bouchonnerCallouts();
        Campaign c = campagne(TOKEN, 'Espagne');
        Account compte = comptePrevisiteur(c);
        aPlanifier(compte, 'Maria Robles', '34004');
        planifie(compte, 'Pilar Nunez');

        Test.startTest();
        LC027_DossiersPrevisite.Dossiers res = LC027_DossiersPrevisite.getDossiers(TOKEN);
        Test.stopTest();

        Assert.areEqual(1, res.aPlanifier.size(), 'Une visite reste a planifier.');
        Assert.areEqual(1, res.planifies.size(), 'Une visite est planifiee.');
        LC027_DossiersPrevisite.Dossier d = res.aPlanifier[0];
        Assert.areEqual('Maria Robles', d.nom);
        Assert.isFalse(d.planifie, 'Cette visite n est pas planifiee.');
        Assert.areEqual(0, d.nrp, 'Aucun appel sans reponse enregistre.');
        Assert.isNotNull(d.dateCreation, 'La colonne « Creee le » a besoin de la date.');
        Assert.isFalse(res.planifies[0].certikoEnvoye, 'Rien n est encore parti chez Certiko.');
    }

    /** Espagne : les deux premiers chiffres du code postal donnent la province. */
    @isTest
    static void provinceVientDuCodePostalEspagnol() {
        LC027_TestFactory.bouchonnerCallouts();
        Campaign c = campagne(TOKEN, 'Espagne');
        aPlanifier(comptePrevisiteur(c), 'Maria Robles', '34004');

        Test.startTest();
        LC027_DossiersPrevisite.Dossiers res = LC027_DossiersPrevisite.getDossiers(TOKEN);
        Test.stopTest();

        Assert.areEqual('Palencia', res.aPlanifier[0].province,
            'Le code postal 34xxx designe la province de Palencia.');
    }

    /**
     * France : les codes postaux ont la même forme qu'en Espagne. Les lire comme
     * des provinces espagnoles donnerait une valeur fausse mais crédible — la
     * colonne affiche donc la ville.
     */
    @isTest
    static void provinceRetombeSurLaVilleHorsEspagne() {
        LC027_TestFactory.bouchonnerCallouts();
        Campaign c = campagne(TOKEN, 'France');
        aPlanifier(comptePrevisiteur(c), 'Agnes Chiab', '63290');

        Test.startTest();
        LC027_DossiersPrevisite.Dossiers res = LC027_DossiersPrevisite.getDossiers(TOKEN);
        Test.stopTest();

        Assert.areEqual('PALENCIA', res.aPlanifier[0].province,
            'Hors Espagne, la colonne montre la ville de l adresse.');
    }

    /** L'adresse importée arrive avec des virgules vides : elles sont nettoyées. */
    @isTest
    static void adresseEstNettoyee() {
        LC027_TestFactory.bouchonnerCallouts();
        Campaign c = campagne(TOKEN, 'Espagne');
        aPlanifier(comptePrevisiteur(c), 'Maria Robles', '34004');

        Test.startTest();
        LC027_DossiersPrevisite.Dossiers res = LC027_DossiersPrevisite.getDossiers(TOKEN);
        Test.stopTest();

        Assert.areEqual('Calle Mayor 14, 34004, PALENCIA', res.aPlanifier[0].adresse);
    }

    /* ════════════════════════════ Contrôle d'accès ════════════════════════════ */

    @isTest
    static void tokenAbsentRefuse() {
        Test.startTest();
        try {
            LC027_DossiersPrevisite.getDossiers('');
            Assert.fail('Un token vide doit etre refuse.');
        } catch (AuraHandledException e) {
            Assert.areEqual('ACCES_MANQUANT', e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void tokenInconnuRefuse() {
        Test.startTest();
        try {
            LC027_DossiersPrevisite.getDossiers('token-qui-n-existe-pas');
            Assert.fail('Un token inconnu doit etre refuse.');
        } catch (AuraHandledException e) {
            Assert.areEqual('ACCES_REFUSE', e.getMessage());
        }
        Test.stopTest();
    }

    /** Le portail des visites est réservé au rôle pré-visiteur. */
    @isTest
    static void autreRoleRefuse() {
        LC027_TestFactory.bouchonnerCallouts();
        LC027_TestFactory.installateur('token-installateur');

        Test.startTest();
        try {
            LC027_DossiersPrevisite.getDossiers('token-installateur');
            Assert.fail('Un installateur n a pas de visites.');
        } catch (AuraHandledException e) {
            Assert.areEqual('ACCES_REFUSE', e.getMessage());
        }
        Test.stopTest();
    }

    /** Tant que le contrat n'est pas signé, le portail reste verrouillé. */
    @isTest
    static void contratNonSigneRefuse() {
        LC027_TestFactory.bouchonnerCallouts();
        LC027_TestFactory.previsiteur('token-attente',
            LC027_GestionContrat.STATUT_ATTENTE_SIGNATURE, true);

        Test.startTest();
        try {
            LC027_DossiersPrevisite.getDossiers('token-attente');
            Assert.fail('Un contrat non signe ferme le portail.');
        } catch (AuraHandledException e) {
            Assert.areEqual('ACCES_REFUSE', e.getMessage());
        }
        Test.stopTest();
    }

    /** Sans compte rattaché à la campagne, la liste est vide — et non en erreur. */
    @isTest
    static void previsiteurSansCompteVoitUneListeVide() {
        LC027_TestFactory.bouchonnerCallouts();
        campagne(TOKEN, 'Espagne');

        Test.startTest();
        LC027_DossiersPrevisite.Dossiers res = LC027_DossiersPrevisite.getDossiers(TOKEN);
        Test.stopTest();

        Assert.areEqual(0, res.aPlanifier.size());
        Assert.areEqual(0, res.planifies.size());
    }

    /** Le dossier d'un autre pré-visiteur est INTROUVABLE, pas « refusé ». */
    @isTest
    static void dossierDUnAutrePrevisiteurEstIntrouvable() {
        LC027_TestFactory.bouchonnerCallouts();
        campagne(TOKEN, 'Espagne');
        Campaign autre = LC027_TestFactory.previsiteur(
            'token-autre', LC027_GestionContrat.STATUT_SIGNE, true);
        Account compteAutre = compte(autre,
            LC027_Roles.prefixeCompte(LC027_Roles.PREVISITEUR) + 'Autre');
        Pro__c dossier = aPlanifier(compteAutre, 'Client Voisin', '34004');

        Test.startTest();
        try {
            LC027_DossiersPrevisite.enregistrerNrp(TOKEN, dossier.Id, 1);
            Assert.fail('Ce dossier appartient a quelqu un d autre.');
        } catch (AuraHandledException e) {
            Assert.areEqual('INTROUVABLE', e.getMessage());
        }
        Test.stopTest();
    }

    /* ════════════════════════════ Appels sans réponse ════════════════════════════ */

    /**
     * Les tentatives s'enchaînent UNE PAR UNE : un double clic ou un onglet
     * resté ouvert ne doit ni sauter une étape ni revenir en arrière.
     */
    @isTest
    static void appelsSansReponseSEnchainentUnParUn() {
        LC027_TestFactory.bouchonnerCallouts();
        Campaign c = campagne(TOKEN, 'Espagne');
        Pro__c dossier = aPlanifier(comptePrevisiteur(c), 'Maria Robles', '34004');

        Test.startTest();
        LC027_DossiersPrevisite.Dossier apres1 =
            LC027_DossiersPrevisite.enregistrerNrp(TOKEN, dossier.Id, 1);
        Assert.areEqual(1, apres1.nrp);

        try {
            LC027_DossiersPrevisite.enregistrerNrp(TOKEN, dossier.Id, 1);
            Assert.fail('La meme tentative ne s enregistre pas deux fois.');
        } catch (AuraHandledException e) {
            Assert.areEqual('NRP_DEJA', e.getMessage());
        }
        try {
            LC027_DossiersPrevisite.enregistrerNrp(TOKEN, dossier.Id, 3);
            Assert.fail('On ne saute pas la deuxieme tentative.');
        } catch (AuraHandledException e) {
            Assert.areEqual('NRP_DEJA', e.getMessage());
        }

        LC027_DossiersPrevisite.enregistrerNrp(TOKEN, dossier.Id, 2);
        LC027_DossiersPrevisite.Dossier apres3 =
            LC027_DossiersPrevisite.enregistrerNrp(TOKEN, dossier.Id, 3);
        Test.stopTest();

        Assert.areEqual(3, apres3.nrp, 'Trois tentatives enregistrees.');
        Assert.areEqual(LC027_DossiersPrevisite.VALEURS_NRP[2],
            [SELECT Audit_Statut_CQ__c FROM Pro__c WHERE Id = :dossier.Id].Audit_Statut_CQ__c);
    }

    @isTest
    static void appelSansReponseRefuseSurVisitePlanifiee() {
        LC027_TestFactory.bouchonnerCallouts();
        Campaign c = campagne(TOKEN, 'Espagne');
        Pro__c dossier = planifie(comptePrevisiteur(c), 'Pilar Nunez');

        Test.startTest();
        try {
            LC027_DossiersPrevisite.enregistrerNrp(TOKEN, dossier.Id, 1);
            Assert.fail('La visite est deja planifiee.');
        } catch (AuraHandledException e) {
            Assert.areEqual('PLUS_A_PLANIFIER', e.getMessage());
        }
        Test.stopTest();
    }

    /* ════════════════════════════ Prise de rendez-vous ════════════════════════════ */

    @isTest
    static void planifierPoseLaDateEtLeStatut() {
        LC027_TestFactory.bouchonnerCallouts();
        Campaign c = campagne(TOKEN, 'Espagne');
        Pro__c dossier = aPlanifier(comptePrevisiteur(c), 'Maria Robles', '34004');
        Datetime rdv = System.now().addDays(3);

        Test.startTest();
        LC027_DossiersPrevisite.Dossier apres =
            LC027_DossiersPrevisite.planifier(TOKEN, dossier.Id, iso(rdv));
        Test.stopTest();

        Assert.isTrue(apres.planifie, 'La visite passe en planifiee.');
        Pro__c relu = [SELECT Pr_visite_Statut__c, PREVISITE_Date__c FROM Pro__c WHERE Id = :dossier.Id];
        Assert.areEqual(LC027_DossiersPrevisite.STATUT_PLANIFIE, relu.Pr_visite_Statut__c);
        Assert.areEqual(rdv.date(), relu.PREVISITE_Date__c.date());
    }

    /** Replanifier, c'est la même opération sur un dossier déjà planifié. */
    @isTest
    static void replanifierDeplaceLeRendezVous() {
        LC027_TestFactory.bouchonnerCallouts();
        Campaign c = campagne(TOKEN, 'Espagne');
        Pro__c dossier = planifie(comptePrevisiteur(c), 'Pilar Nunez');
        Datetime nouveau = System.now().addDays(9);

        Test.startTest();
        LC027_DossiersPrevisite.planifier(TOKEN, dossier.Id, iso(nouveau));
        Test.stopTest();

        Assert.areEqual(nouveau.date(),
            [SELECT PREVISITE_Date__c FROM Pro__c WHERE Id = :dossier.Id].PREVISITE_Date__c.date());
    }

    @isTest
    static void planifierRefuseUneDatePassee() {
        LC027_TestFactory.bouchonnerCallouts();
        Campaign c = campagne(TOKEN, 'Espagne');
        Pro__c dossier = aPlanifier(comptePrevisiteur(c), 'Maria Robles', '34004');

        Test.startTest();
        try {
            LC027_DossiersPrevisite.planifier(TOKEN, dossier.Id, iso(System.now().addDays(-1)));
            Assert.fail('Un rendez-vous ne se prend pas dans le passe.');
        } catch (AuraHandledException e) {
            Assert.areEqual('DATE_PASSEE', e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void planifierRefuseUneDateAbsenteOuIllisible() {
        LC027_TestFactory.bouchonnerCallouts();
        Campaign c = campagne(TOKEN, 'Espagne');
        Pro__c dossier = aPlanifier(comptePrevisiteur(c), 'Maria Robles', '34004');

        Test.startTest();
        try {
            LC027_DossiersPrevisite.planifier(TOKEN, dossier.Id, null);
            Assert.fail('Sans date, rien a enregistrer.');
        } catch (AuraHandledException e) {
            Assert.areEqual('DATE_MANQUANTE', e.getMessage());
        }
        try {
            LC027_DossiersPrevisite.planifier(TOKEN, dossier.Id, 'pas une date');
            Assert.fail('Une date illisible doit etre refusee.');
        } catch (AuraHandledException e) {
            Assert.areEqual('DATE_INVALIDE', e.getMessage());
        }
        Test.stopTest();
    }

    /* ════════════════════════════ Rendre la visite ════════════════════════════ */

    /**
     * Le motif part dans la LANGUE D'AFFICHAGE, précédé du nom du compte : le
     * dossier peut être réattribué puis rendu par quelqu'un d'autre, et
     * l'historique doit dire QUI a rendu, pas seulement pourquoi.
     */
    @isTest
    static void rendreVisiteEnregistreLeMotifEtLibereLeDossier() {
        LC027_TestFactory.bouchonnerCallouts();
        Campaign c = campagne(TOKEN, 'Espagne');
        Pro__c dossier = aPlanifier(comptePrevisiteur(c), 'Maria Robles', '34004');

        Test.startTest();
        LC027_DossiersPrevisite.rendreVisite(
            TOKEN, dossier.Id, 'El cliente ya no esta interesado', 'desinteret');
        Test.stopTest();

        Pro__c relu = [
            SELECT LOOKUP_Pre_visiteur__c, PREVISITE_Motif_Rendu__c, PREVISITE_Nb_Rendus__c,
                   Pr_visite_Statut__c
            FROM Pro__c WHERE Id = :dossier.Id
        ];
        Assert.isNull(relu.LOOKUP_Pre_visiteur__c, 'La visite n est plus attribuee.');
        Assert.areEqual(NOM_COMPTE + ' - El cliente ya no esta interesado',
            relu.PREVISITE_Motif_Rendu__c, 'Format « Nom du compte - motif ».');
        Assert.areEqual(1, relu.PREVISITE_Nb_Rendus__c, 'Premier rendu compte pour un.');
    }

    /**
     * Rendre une visite PLANIFIÉE ne peut pas se limiter à vider le
     * pré-visiteur : PREVISITE4_OUI l'exige tant que le statut reste
     * « Passage Planifié ». Le dossier repart donc en « Passage Demandé »,
     * date effacée.
     */
    @isTest
    static void rendreVisitePlanifieeLaRemetAPlanifier() {
        LC027_TestFactory.bouchonnerCallouts();
        Campaign c = campagne(TOKEN, 'Espagne');
        Pro__c dossier = planifie(comptePrevisiteur(c), 'Pilar Nunez');

        Test.startTest();
        LC027_DossiersPrevisite.rendreVisite(TOKEN, dossier.Id, 'Otro motivo', 'autre');
        Test.stopTest();

        Pro__c relu = [
            SELECT LOOKUP_Pre_visiteur__c, PREVISITE_Date__c, Pr_visite_Statut__c
            FROM Pro__c WHERE Id = :dossier.Id
        ];
        Assert.isNull(relu.LOOKUP_Pre_visiteur__c);
        Assert.isNull(relu.PREVISITE_Date__c, 'La date du rendez-vous est effacee.');
        Assert.areEqual(LC027_DossiersPrevisite.STATUT_DEMANDE, relu.Pr_visite_Statut__c);
    }

    /** Un dossier peut revenir puis repartir : le compteur suit. */
    @isTest
    static void compteurDeRendusSIncremente() {
        LC027_TestFactory.bouchonnerCallouts();
        Campaign c = campagne(TOKEN, 'Espagne');
        Account compte = comptePrevisiteur(c);
        Pro__c dossier = aPlanifier(compte, 'Maria Robles', '34004');

        Test.startTest();
        LC027_DossiersPrevisite.rendreVisite(TOKEN, dossier.Id, 'Primer motivo', 'autre');
        // Réattribution par ECONATURA, puis second rendu.
        update new Pro__c(Id = dossier.Id, LOOKUP_Pre_visiteur__c = compte.Id);
        LC027_DossiersPrevisite.rendreVisite(TOKEN, dossier.Id, 'Segundo motivo', 'autre');
        Test.stopTest();

        Assert.areEqual(2,
            [SELECT PREVISITE_Nb_Rendus__c FROM Pro__c WHERE Id = :dossier.Id].PREVISITE_Nb_Rendus__c);
    }

    @isTest
    static void rendreVisiteRefuseUnMotifVide() {
        LC027_TestFactory.bouchonnerCallouts();
        Campaign c = campagne(TOKEN, 'Espagne');
        Pro__c dossier = aPlanifier(comptePrevisiteur(c), 'Maria Robles', '34004');

        Test.startTest();
        try {
            LC027_DossiersPrevisite.rendreVisite(TOKEN, dossier.Id, '  ', 'autre');
            Assert.fail('Un motif vide ne dit rien a ECONATURA.');
        } catch (AuraHandledException e) {
            Assert.areEqual('MOTIF_MANQUANT', e.getMessage());
        }
        Test.stopTest();
    }

    /**
     * « Client injoignable » se mérite : c'est la CLÉ du motif qui est
     * contrôlée, jamais son texte — celui-ci change avec la langue.
     */
    @isTest
    static void motifInjoignableExigeTroisTentatives() {
        LC027_TestFactory.bouchonnerCallouts();
        Campaign c = campagne(TOKEN, 'Espagne');
        Pro__c dossier = aPlanifier(comptePrevisiteur(c), 'Maria Robles', '34004');

        Test.startTest();
        try {
            LC027_DossiersPrevisite.rendreVisite(
                TOKEN, dossier.Id, 'Cliente ilocalizable', 'injoignable');
            Assert.fail('Aucune tentative enregistree.');
        } catch (AuraHandledException e) {
            Assert.areEqual('MOTIF_NRP', e.getMessage());
        }

        for (Integer n = 1; n <= 3; n++) {
            LC027_DossiersPrevisite.enregistrerNrp(TOKEN, dossier.Id, n);
        }
        LC027_DossiersPrevisite.rendreVisite(
            TOKEN, dossier.Id, 'Cliente ilocalizable', 'injoignable');
        Test.stopTest();

        Assert.isNull([SELECT LOOKUP_Pre_visiteur__c FROM Pro__c WHERE Id = :dossier.Id]
            .LOOKUP_Pre_visiteur__c, 'Apres trois tentatives, le rendu passe.');
    }

    /* ════════════════════════════ Bouchons Certiko ════════════════════════════ */

    /**
     * Réponse de Certiko, avec le repli des triggers : le géocodage attend une
     * LISTE, un objet le ferait échouer et l'erreur ne désignerait alors pas le
     * code testé.
     */
    private class BouchonCertiko implements HttpCalloutMock {
        private Integer code;
        private String corps;
        private BouchonCertiko(Integer code, String corps) {
            this.code = code;
            this.corps = corps;
        }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse rep = new HttpResponse();
            String url = req.getEndpoint();
            Boolean versCertiko = url.contains('certiko');
            rep.setStatusCode(versCertiko ? code : 200);
            rep.setHeader('Content-Type', 'application/json');
            rep.setBody(versCertiko ? corps
                : (url.contains('nominatim') ? '[]' : '{"success":true}'));
            return rep;
        }
    }

    /**
     * Réponse de Certiko. `status` est le statut de l'espace, `values.status_vt`
     * celui de la visite : deux choses distinctes, et c'est la seconde qui
     * alimente notre liste de sélection.
     */
    private static String reponseCertiko(String statutVt) {
        Map<String, Object> corps = new Map<String, Object>{
            'id' => 'c1000000-0000-4000-8000-000000000009',
            'reference' => 'RES060-000777',
            'status' => new Map<String, Object>{ 'name' => 'Nouveaux Clients' }
        };
        if (statutVt != null) {
            corps.put('values', new Map<String, Object>{ 'status_vt' => statutVt });
        }
        return JSON.serialize(corps);
    }

    /* ════════════════════════ Démarrage de la prévisite ════════════════════════ */

    /** Une visite qui n'est pas planifiée ne se démarre pas. */
    @isTest
    static void demarrerRefuseUneVisiteNonPlanifiee() {
        LC027_TestFactory.bouchonnerCallouts();
        Campaign c = campagne(TOKEN, 'Espagne');
        Pro__c dossier = aPlanifier(comptePrevisiteur(c), 'Maria Robles', '34004');

        Test.startTest();
        try {
            LC027_DossiersPrevisite.demarrerPrevisite(TOKEN, dossier.Id);
            Assert.fail('Sans rendez-vous, il n y a rien a demarrer.');
        } catch (AuraHandledException e) {
            Assert.areEqual('PAS_PLANIFIEE', e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void demarrerEnvoieLeDossierEtGardeLaReference() {
        LC027_TestFactory.bouchonnerCallouts();
        Campaign c = campagne(TOKEN, 'Espagne');
        Pro__c dossier = planifie(comptePrevisiteur(c), 'Pilar Nunez');
        Test.setMock(HttpCalloutMock.class, new BouchonCertiko(201, reponseCertiko('planifie')));

        Test.startTest();
        LC027_DossiersPrevisite.Dossier apres =
            LC027_DossiersPrevisite.demarrerPrevisite(TOKEN, dossier.Id);
        Test.stopTest();

        Assert.isTrue(apres.certikoEnvoye, 'Le dossier est parti chez Certiko.');
        Assert.areEqual('RES060-000777', apres.certikoReference);
        Assert.isNotNull(apres.certikoLien, 'Le releve terrain doit etre ouvrable.');
        Pro__c relu = [
            SELECT CERTIKO_Dossier_Id__c, CERTIKO_Reference__c, CERTIKO_Date_Envoi__c,
                   CERTIKO_Message_Erreur__c
            FROM Pro__c WHERE Id = :dossier.Id
        ];
        Assert.areEqual('c1000000-0000-4000-8000-000000000009', relu.CERTIKO_Dossier_Id__c);
        Assert.isNotNull(relu.CERTIKO_Date_Envoi__c);
        Assert.isNull(relu.CERTIKO_Message_Erreur__c);
    }

    /**
     * LE GARDE-FOU CONTRE LES DOUBLONS : id ET référence déjà présents, aucun
     * appel n'est émis. C'est le serveur qui décide, pas le composant — le
     * bouchon refuserait tout, et le test échouerait s'il était sollicité.
     */
    @isTest
    static void dossierDejaEnvoyeNePartPasUneSecondeFois() {
        LC027_TestFactory.bouchonnerCallouts();
        Campaign c = campagne(TOKEN, 'Espagne');
        Pro__c dossier = planifie(comptePrevisiteur(c), 'Pilar Nunez');
        update new Pro__c(
            Id = dossier.Id,
            CERTIKO_Dossier_Id__c = 'deja-envoye',
            CERTIKO_Reference__c = 'RES060-000001'
        );
        Test.setMock(HttpCalloutMock.class,
            new BouchonCertiko(500, '{"error":{"message":"jamais appele"}}'));

        Test.startTest();
        LC027_DossiersPrevisite.Dossier apres =
            LC027_DossiersPrevisite.demarrerPrevisite(TOKEN, dossier.Id);
        Test.stopTest();

        Assert.isTrue(apres.certikoEnvoye);
        Assert.areEqual('RES060-000001', apres.certikoReference,
            'La reference d origine est conservee : aucun second envoi.');
    }

    /** Un refus de Certiko laisse une trace sur le Dossier, pour ECONATURA. */
    @isTest
    static void refusDeCertikoEstConserveSurLeDossier() {
        LC027_TestFactory.bouchonnerCallouts();
        Campaign c = campagne(TOKEN, 'Espagne');
        Pro__c dossier = planifie(comptePrevisiteur(c), 'Pilar Nunez');
        Test.setMock(HttpCalloutMock.class,
            new BouchonCertiko(422, '{"error":{"message":"telephone is required"}}'));

        Test.startTest();
        try {
            LC027_DossiersPrevisite.demarrerPrevisite(TOKEN, dossier.Id);
            Assert.fail('Certiko a refuse le dossier.');
        } catch (AuraHandledException e) {
            Assert.areEqual('CERTIKO_REFUS:telephone is required', e.getMessage());
        }
        Test.stopTest();

        Pro__c relu = [
            SELECT CERTIKO_Dossier_Id__c, CERTIKO_Message_Erreur__c
            FROM Pro__c WHERE Id = :dossier.Id
        ];
        Assert.isNull(relu.CERTIKO_Dossier_Id__c, 'Rien n a ete cree chez Certiko.');
        Assert.isTrue(relu.CERTIKO_Message_Erreur__c.contains('telephone'),
            relu.CERTIKO_Message_Erreur__c);
    }

    /* ════════════════════════════ Suivi du statut ════════════════════════════ */

    @isTest
    static void verifierStatutExigeUnDossierCertiko() {
        LC027_TestFactory.bouchonnerCallouts();
        Campaign c = campagne(TOKEN, 'Espagne');
        Pro__c dossier = planifie(comptePrevisiteur(c), 'Pilar Nunez');

        Test.startTest();
        try {
            LC027_DossiersPrevisite.verifierStatutCertiko(TOKEN, dossier.Id);
            Assert.fail('Sans dossier Certiko, il n y a pas de statut a relire.');
        } catch (AuraHandledException e) {
            Assert.areEqual('CERTIKO_SANS_DOSSIER', e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void verifierStatutRecopieLeStatutCourant() {
        LC027_TestFactory.bouchonnerCallouts();
        Campaign c = campagne(TOKEN, 'Espagne');
        Pro__c dossier = planifie(comptePrevisiteur(c), 'Pilar Nunez');
        update new Pro__c(
            Id = dossier.Id,
            CERTIKO_Dossier_Id__c = 'c1000000-0000-4000-8000-000000000009',
            CERTIKO_Reference__c = 'RES060-000777'
        );
        Test.setMock(HttpCalloutMock.class, new BouchonCertiko(200, reponseCertiko('terminee')));

        Test.startTest();
        LC027_DossiersPrevisite.Dossier apres =
            LC027_DossiersPrevisite.verifierStatutCertiko(TOKEN, dossier.Id);
        Test.stopTest();

        Assert.areEqual('terminee', apres.certikoStatutVt);
        Assert.isNull(apres.certikoStatutRefuse);
        Assert.isNotNull(apres.certikoStatutMaj, 'La date de verification est enregistree.');
    }

    /**
     * STATUT OUVERT CHEZ CERTIKO ET PAS CHEZ NOUS — le dossier garde le sien,
     * et la réponse porte la valeur refusée. Le portail ne la montre qu'en mode
     * test : c'est un signal pour nous, pas pour le pré-visiteur.
     */
    @isTest
    static void statutHorsListeNEstPasEnregistre() {
        LC027_TestFactory.bouchonnerCallouts();
        Campaign c = campagne(TOKEN, 'Espagne');
        Pro__c dossier = planifie(comptePrevisiteur(c), 'Pilar Nunez');
        update new Pro__c(
            Id = dossier.Id,
            CERTIKO_Dossier_Id__c = 'c1000000-0000-4000-8000-000000000009',
            CERTIKO_Reference__c = 'RES060-000777',
            CERTIKO_Statut_VT__c = 'en_cours'
        );
        Test.setMock(HttpCalloutMock.class,
            new BouchonCertiko(200, reponseCertiko('statut_de_demain')));

        Test.startTest();
        LC027_DossiersPrevisite.Dossier apres =
            LC027_DossiersPrevisite.verifierStatutCertiko(TOKEN, dossier.Id);
        Test.stopTest();

        Assert.areEqual('statut_de_demain', apres.certikoStatutRefuse,
            'La valeur refusee remonte au portail.');
        Assert.areEqual('en_cours',
            [SELECT CERTIKO_Statut_VT__c FROM Pro__c WHERE Id = :dossier.Id].CERTIKO_Statut_VT__c,
            'Le dossier garde le dernier statut que nous savons interpreter.');
    }

    /**
     * Le portail relit le statut toutes les dix secondes : tant que Certiko
     * renvoie la même chose, RIEN ne doit être écrit, sinon les automatismes du
     * Dossier se déclencheraient six fois par minute pour rien.
     */
    @isTest
    static void statutInchangeNEcritRien() {
        LC027_TestFactory.bouchonnerCallouts();
        Campaign c = campagne(TOKEN, 'Espagne');
        Pro__c dossier = planifie(comptePrevisiteur(c), 'Pilar Nunez');
        update new Pro__c(
            Id = dossier.Id,
            CERTIKO_Dossier_Id__c = 'c1000000-0000-4000-8000-000000000009',
            CERTIKO_Reference__c = 'RES060-000777',
            // Déjà à jour : c'est exactement ce que le bouchon va renvoyer.
            CERTIKO_Statut_VT__c = 'terminee',
            CERTIKO_Statut_Dossier__c = 'Nouveaux Clients'
        );
        Datetime avant = [SELECT LastModifiedDate FROM Pro__c WHERE Id = :dossier.Id].LastModifiedDate;
        Test.setMock(HttpCalloutMock.class, new BouchonCertiko(200, reponseCertiko('terminee')));

        Test.startTest();
        LC027_DossiersPrevisite.verifierStatutCertiko(TOKEN, dossier.Id);
        Test.stopTest();

        Pro__c relu = [
            SELECT LastModifiedDate, CERTIKO_Statut_Maj__c FROM Pro__c WHERE Id = :dossier.Id
        ];
        Assert.areEqual(avant, relu.LastModifiedDate, 'Statut inchange : aucune ecriture.');
        Assert.isNull(relu.CERTIKO_Statut_Maj__c,
            'La date suit les CHANGEMENTS de statut, pas les relectures.');
    }

    /* ════════════════════════════ Historique ════════════════════════════ */

    /**
     * Aucun enregistrement d'historique n'est créé pendant un test : la lecture
     * doit rendre une liste vide SANS erreur, pour que la fiche s'affiche même
     * quand le suivi vient d'être activé.
     */
    @isTest
    static void historiqueVideNeCassePasLaFiche() {
        LC027_TestFactory.bouchonnerCallouts();
        Campaign c = campagne(TOKEN, 'Espagne');
        Pro__c dossier = aPlanifier(comptePrevisiteur(c), 'Maria Robles', '34004');

        Test.startTest();
        List<LC027_DossiersPrevisite.Evenement> hist =
            LC027_DossiersPrevisite.getHistorique(TOKEN, dossier.Id);
        Test.stopTest();

        Assert.areEqual(0, hist.size(), 'Sans historique enregistre, la section reste vide.');
    }

    /**
     * Mise en forme de l'historique, lignes fournies directement : les
     * enregistrements Pro__History ne sont pas créables, ils sont donc
     * reconstitués depuis leur forme JSON.
     */
    @isTest
    static void historiqueTraduitChaqueTypeDeChangement() {
        Datetime t0 = Datetime.newInstance(2026, 9, 12, 9, 40, 0);
        Datetime rdv = Datetime.newInstance(2026, 9, 18, 16, 0, 0);
        Datetime tRendu = Datetime.newInstance(2026, 9, 18, 8, 10, 0);
        List<LC027_DossiersPrevisite.Ligne> lignes = new List<LC027_DossiersPrevisite.Ligne>{
            ligne('created', null, null, t0),
            ligne('LOOKUP_Pre_visiteur__c', null, '001000000000001', t0.addHours(1)),
            ligne('Audit_Statut_CQ__c', null, LC027_DossiersPrevisite.VALEURS_NRP[0], t0.addDays(1)),
            ligne('Audit_Statut_CQ__c', LC027_DossiersPrevisite.VALEURS_NRP[0],
                  LC027_DossiersPrevisite.VALEURS_NRP[1], t0.addDays(2)),
            // Champ Datetime : l'historique rend une vraie date...
            ligne('PREVISITE_Date__c', null, rdv, t0.addDays(3)),
            // ...et le repli sait aussi lire la forme texte.
            ligne('PREVISITE_Date__c', '2026-09-18T16:00:00.000Z',
                  '2026-09-22T16:00:00.000Z', t0.addDays(4)),
            // Le rendu vide le pré-visiteur DANS LE MÊME enregistrement.
            ligne('PREVISITE_Motif_Rendu__c', null,
                  'PREVISITEUR- Jose - El cliente ya no esta interesado', tRendu),
            ligne('LOOKUP_Pre_visiteur__c', '001000000000001', null, tRendu)
        };

        Test.startTest();
        List<LC027_DossiersPrevisite.Evenement> evts =
            LC027_DossiersPrevisite.versEvenements(lignes);
        Test.stopTest();

        // La creation precede l attribution : elle est coupee avec le reste.
        Assert.areEqual(6, evts.size(),
            'Le retrait du pre-visiteur ne doit pas doubler le rendu.');
        Assert.areEqual('ajout', evts[0].type, 'L historique commence a l attribution.');
        Assert.areEqual('nrp', evts[1].type);
        Assert.areEqual(1, evts[1].niveau);
        Assert.areEqual(2, evts[2].niveau);
        Assert.areEqual('rdv', evts[3].type, 'Premiere date posee : prise de rendez-vous.');
        Assert.isNotNull(evts[3].dateNouvelle);
        Assert.areEqual('replanif', evts[4].type, 'Date remplacee : report.');
        Assert.isNotNull(evts[4].dateAncienne);
        Assert.areEqual('rendu', evts[5].type);
        Assert.areEqual('El cliente ya no esta interesado', evts[5].valeur,
            'Le nom du compte est presente a part, pas dans le motif.');
        Assert.areEqual('Jose', evts[5].auteur);
    }

    /**
     * RÉATTRIBUTION — un dossier rendu puis confié à quelqu'un d'autre ne doit
     * pas montrer au suivant les appels et le motif de rendu du précédent.
     * L'historique repart de la DERNIÈRE attribution.
     */
    @isTest
    static void historiqueRepartDeLaDerniereAttribution() {
        Datetime t = Datetime.newInstance(2026, 9, 10, 9, 0, 0);
        Test.startTest();
        List<LC027_DossiersPrevisite.Evenement> evts =
            LC027_DossiersPrevisite.versEvenements(new List<LC027_DossiersPrevisite.Ligne>{
                // --- premier pre-visiteur ---
                ligne('created', null, null, t),
                ligne('LOOKUP_Pre_visiteur__c', null, '001000000000001', t.addDays(1)),
                ligne('Audit_Statut_CQ__c', null, LC027_DossiersPrevisite.VALEURS_NRP[0], t.addDays(2)),
                ligne('PREVISITE_Motif_Rendu__c', null,
                      'PREVISITEUR- Pedro - El cliente ya no esta interesado', t.addDays(3)),
                ligne('LOOKUP_Pre_visiteur__c', '001000000000001', null, t.addDays(3)),
                // --- reattribution au second ---
                ligne('LOOKUP_Pre_visiteur__c', null, '001000000000002', t.addDays(4)),
                ligne('Audit_Statut_CQ__c', LC027_DossiersPrevisite.VALEURS_NRP[0],
                      LC027_DossiersPrevisite.VALEURS_NRP[1], t.addDays(5))
            });
        Test.stopTest();

        Assert.areEqual(2, evts.size(), 'Rien d avant la reattribution.');
        Assert.areEqual('ajout', evts[0].type);
        Assert.areEqual('nrp', evts[1].type);
        for (LC027_DossiersPrevisite.Evenement e : evts) {
            Assert.areNotEqual('rendu', e.type,
                'Le motif de rendu du precedent pre-visiteur reste chez lui.');
        }
    }

    /** Un retrait sans motif reste visible : le dossier a bien quitté le portail. */
    @isTest
    static void retraitSansMotifResteUnEvenement() {
        Datetime t = Datetime.newInstance(2026, 9, 20, 11, 0, 0);
        Test.startTest();
        List<LC027_DossiersPrevisite.Evenement> evts =
            LC027_DossiersPrevisite.versEvenements(new List<LC027_DossiersPrevisite.Ligne>{
                ligne('LOOKUP_Pre_visiteur__c', '001000000000001', null, t),
                // Changements sans intérêt pour le pré-visiteur : ignorés.
                ligne('Audit_Statut_CQ__c', null, 'Confirme', t),
                ligne('Pr_visite_Statut__c', 'a', 'b', t)
            });
        Test.stopTest();

        Assert.areEqual(1, evts.size());
        Assert.areEqual('retire', evts[0].type);
    }

    /** Ligne d'historique telle que la lecture la produit, écrite par le portail. */
    private static LC027_DossiersPrevisite.Ligne ligne(
            String champ, Object avant, Object apres, Datetime quand) {
        return new LC027_DossiersPrevisite.Ligne(champ, avant, apres, quand, true);
    }
}