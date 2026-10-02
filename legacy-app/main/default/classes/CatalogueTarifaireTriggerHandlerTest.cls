/**
 * Tests du garde-fou de non-chevauchement des lignes de catalogue
 * (CatalogueTarifaireTrigger / CatalogueTarifaireTriggerHandler) et de la
 * vérification front exposée par LC022CatalogueTarifaireController.
 *
 * Les valeurs de picklist (Fiche CEE, Rôle Intervenant) sont résolues à
 * l'exécution : si l'org n'en expose aucune, le scénario est ignoré.
 */
@IsTest
private class CatalogueTarifaireTriggerHandlerTest {

    private static String fiche;
    private static String role;

    // Mock générique : neutralise un éventuel callout d'automatisation org sur l'insert.
    private class CalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setStatus('OK');
            res.setBody('{}');
            return res;
        }
    }

    private static Boolean resolve() {
        Test.setMock(HttpCalloutMock.class, new CalloutMock());
        List<Schema.PicklistEntry> fes = CatalogueTarifaire__c.FicheCEE__c.getDescribe().getPicklistValues();
        List<Schema.PicklistEntry> res = CatalogueTarifaire__c.RoleIntervenant__c.getDescribe().getPicklistValues();
        if (fes.isEmpty() || res.isEmpty()) return false;
        fiche = fes[0].getValue();
        role = res[0].getValue();
        return true;
    }

    private static CatalogueTarifaire__c ligne(Date debut, Date fin, String statut, Id intervenant) {
        CatalogueTarifaire__c c = new CatalogueTarifaire__c(
            FicheCEE__c = fiche,
            RoleIntervenant__c = role,
            Statut__c = statut,
            DateDebutValidite__c = debut,
            DateFinValidite__c = fin
        );
        if (intervenant != null) {
            c.Intervenants__c = String.valueOf(intervenant);
        }
        return c;
    }

    private static Integer countLignes() {
        return [
            SELECT COUNT()
            FROM CatalogueTarifaire__c
            WHERE FicheCEE__c = :fiche AND RoleIntervenant__c = :role
        ];
    }

    // Id du Record Type Acompte (null s'il n'est pas déployé -> test ignoré).
    private static Id acompteRt() {
        Schema.RecordTypeInfo rti = CatalogueTarifaire__c.SObjectType.getDescribe()
            .getRecordTypeInfosByDeveloperName().get('Acompte');
        return rti == null ? null : rti.getRecordTypeId();
    }

    @IsTest
    static void testChevauchementMemesDatesBloque() {
        if (!resolve()) return;
        insert ligne(Date.today().addDays(-5), Date.today().addDays(5), 'Active', null);

        Boolean bloque = false;
        Test.startTest();
        try {
            insert ligne(Date.today().addDays(-5), Date.today().addDays(5), 'Active', null);
        } catch (DmlException e) {
            bloque = true;
            System.Assert.isTrue(e.getDmlMessage(0).contains('Chevauchement'),
                'Message de chevauchement attendu : ' + e.getDmlMessage(0));
        }
        Test.stopTest();
        System.Assert.isTrue(bloque, 'Deux lignes ACTIVE aux mêmes dates doivent être bloquées');
    }

    @IsTest
    static void testChevauchementBornesCommunesBloque() {
        if (!resolve()) return;
        insert ligne(Date.today().addDays(-10), Date.today(), 'Active', null);

        Boolean bloque = false;
        Test.startTest();
        try {
            // Se touchent sur "today" (borne commune) -> chevauchement.
            insert ligne(Date.today(), Date.today().addDays(10), 'Active', null);
        } catch (DmlException e) {
            bloque = true;
        }
        Test.stopTest();
        System.Assert.isTrue(bloque, 'Des périodes partageant une borne se recoupent -> blocage');
    }

    @IsTest
    static void testPeriodesDisjointesOk() {
        if (!resolve()) return;
        insert ligne(Date.today().addDays(-10), Date.today().addDays(-1), 'Active', null);

        Test.startTest();
        insert ligne(Date.today(), Date.today().addDays(10), 'Active', null);
        Test.stopTest();

        System.Assert.areEqual(2, countLignes(), 'Deux lignes disjointes doivent coexister');
    }

    @IsTest
    static void testInactiveNonContrainte() {
        if (!resolve()) return;
        insert ligne(Date.today().addDays(-5), Date.today().addDays(5), 'Active', null);

        Test.startTest();
        insert ligne(Date.today().addDays(-5), Date.today().addDays(5), 'Inactive', null);
        Test.stopTest();

        System.Assert.areEqual(2, countLignes(),
            'Une ligne Inactive ne déclenche pas le chevauchement');
    }

    // @IsTest
    // static void testIntervenantDifferentOk() {
    //     if (!resolve()) return;
    //     Account a = new Account(Name = 'Compte Spécifique');
    //     insert a;

    //     insert ligne(Date.today().addDays(-5), Date.today().addDays(5), 'Active', null); // générique

    //     Test.startTest();
    //     insert ligne(Date.today().addDays(-5), Date.today().addDays(5), 'Active', a.Id); // spécifique
    //     Test.stopTest();

    //     System.Assert.areEqual(2, countLignes(),
    //         'Générique (null) et spécifique (compte) ont des clés différentes -> pas de chevauchement');
    // }

    @IsTest
    static void testUpdateVersChevauchementBloque() {
        if (!resolve()) return;
        insert ligne(Date.today().addDays(-20), Date.today().addDays(-11), 'Active', null);
        CatalogueTarifaire__c b = ligne(Date.today(), Date.today().addDays(10), 'Active', null);
        insert b; // disjoint au départ -> OK

        Boolean bloque = false;
        Test.startTest();
        try {
            b.DateDebutValidite__c = Date.today().addDays(-15); // recoupe désormais la 1re
            update b;
        } catch (DmlException e) {
            bloque = true;
        }
        Test.stopTest();
        System.Assert.isTrue(bloque, 'Une MAJ créant un chevauchement doit être bloquée');
    }

    @IsTest
    static void testBatchChevauchementBloque() {
        if (!resolve()) return;
        List<CatalogueTarifaire__c> lot = new List<CatalogueTarifaire__c>{
            ligne(Date.today().addDays(-5), Date.today().addDays(5), 'Active', null),
            ligne(Date.today().addDays(-3), Date.today().addDays(8), 'Active', null)
        };
        Boolean bloque = false;
        Test.startTest();
        try {
            insert lot;
        } catch (DmlException e) {
            bloque = true;
        }
        Test.stopTest();
        System.Assert.isTrue(bloque, 'Chevauchement à l\'intérieur d\'un même insert doit être bloqué');
    }

    @IsTest
    static void testVerifierChevauchementFront() {
        if (!resolve()) return;
        CatalogueTarifaire__c existante = ligne(Date.today().addDays(-5), Date.today().addDays(5), 'Active', null);
        insert existante;
        String nom = [SELECT Name FROM CatalogueTarifaire__c WHERE Id = :existante.Id].Name;

        Map<String, Object> fields = new Map<String, Object>{
            'FicheCEE__c' => fiche,
            'RoleIntervenant__c' => role,
            'Statut__c' => 'Active',
            'DateDebutValidite__c' => String.valueOf(Date.today()),
            'DateFinValidite__c' => String.valueOf(Date.today().addDays(2))
        };

        Test.startTest();
        String conflit = LC022CatalogueTarifaireController.verifierChevauchement(null, fields);
        // Statut non Active -> aucune contrainte.
        Map<String, Object> inactiveFields = new Map<String, Object>(fields);
        inactiveFields.put('Statut__c', 'Inactive');
        String aucun = LC022CatalogueTarifaireController.verifierChevauchement(null, inactiveFields);
        Test.stopTest();

        // Le contrat front : renvoyer le N° (Name) de la ligne en conflit.
        System.Assert.areEqual(nom, conflit, 'La vérification front doit renvoyer le N° de la ligne en conflit');
        System.Assert.isNull(aucun, 'Une ligne Inactive ne déclenche aucun chevauchement');
    }

    // ----------------------------- Acompte : AUCUN chevauchement (best-effort) -----------------------------

    @IsTest
    static void testAcompteSansChevauchement() {
        if (!resolve()) return;
        Id rt = acompteRt();
        if (rt == null) return; // RT Acompte absent -> best-effort

        CatalogueTarifaire__c a1 = ligne(Date.today().addDays(-5), Date.today().addDays(5), 'Active', null);
        a1.RecordTypeId = rt;
        insert a1;

        Boolean ok = true;
        Test.startTest();
        try {
            // Deux lignes Acompte qui se recoupent : la règle de chevauchement Acompte
            // a été retirée -> elles doivent COEXISTER (aucun blocage).
            CatalogueTarifaire__c a2 = ligne(Date.today().addDays(-5), Date.today().addDays(5), 'Active', null);
            a2.RecordTypeId = rt;
            insert a2;
        } catch (DmlException e) {
            ok = false;
        }
        Test.stopTest();
        System.Assert.isTrue(ok,
            'Aucun contrôle de chevauchement pour l\'Acompte : deux lignes qui se recoupent coexistent');
    }

    @IsTest
    static void testAcompteNeBloquePasStandard() {
        if (!resolve()) return;
        Id rt = acompteRt();
        if (rt == null) return;

        // Ligne Standard (fiche + rôle + période).
        insert ligne(Date.today().addDays(-5), Date.today().addDays(5), 'Active', null);

        Boolean ok = true;
        Test.startTest();
        try {
            // Acompte même fiche/rôle/période : RT distinct -> AUCUN chevauchement avec le Standard.
            CatalogueTarifaire__c ac = ligne(Date.today().addDays(-5), Date.today().addDays(5), 'Active', null);
            ac.RecordTypeId = rt;
            insert ac;
        } catch (DmlException e) {
            ok = false;
        }
        Test.stopTest();
        System.Assert.isTrue(ok,
            'Une ligne Acompte ne doit pas être bloquée par une ligne Standard (Record Types distincts)');
    }

    @IsTest
    static void testDatesInverseesBloquees() {
        if (!resolve()) return;
        Boolean bloque = false;
        Test.startTest();
        try {
            // Date début > date fin -> rejet par la validation rule VR_Date_DebutFin.
            insert ligne(Date.today().addDays(5), Date.today().addDays(-5), 'Active', null);
        } catch (DmlException e) {
            bloque = true;
        }
        Test.stopTest();
        System.Assert.isTrue(bloque, 'Des dates incohérentes (début > fin) doivent être bloquées');
    }

    // -------- Logique pure (sans DML, sans GVS, sans compte) : toujours exécutée --------

    private static CatalogueTarifaire__c enMemoire(String fiche, String role, Id interv, Date debut, Date fin) {
        CatalogueTarifaire__c c = new CatalogueTarifaire__c(
            FicheCEE__c = fiche, RoleIntervenant__c = role,
            DateDebutValidite__c = debut, DateFinValidite__c = fin
        );
        if (interv != null) {
            c.Intervenants__c = String.valueOf(interv);
        }
        return c;
    }

    @IsTest
    static void testLogiqueChevauchementPure() {
        String pfx = Account.SObjectType.getDescribe().getKeyPrefix();
        Id compteA = pfx + '000000000001';
        Id compteB = pfx + '000000000002';

        Date d1 = Date.newInstance(2026, 1, 1);
        Date d5 = Date.newInstance(2026, 1, 5);
        Date d10 = Date.newInstance(2026, 1, 10);
        Date d20 = Date.newInstance(2026, 1, 20);

        CatalogueTarifaire__c base = enMemoire('F1', 'R1', null, d1, d10);

        // Génériques (null == null), périodes qui se recoupent -> chevauchement.
        System.Assert.isTrue(
            CatalogueTarifaireTriggerHandler.memeCleEtChevauche(base, enMemoire('F1', 'R1', null, d5, d20)),
            'Deux génériques même clé + recoupement -> chevauchement');
        // Borne commune (touchent sur d10) -> chevauchement.
        System.Assert.isTrue(
            CatalogueTarifaireTriggerHandler.memeCleEtChevauche(base, enMemoire('F1', 'R1', null, d10, d20)),
            'Borne commune -> chevauchement');
        // Périodes disjointes -> pas de chevauchement.
        System.Assert.isFalse(
            CatalogueTarifaireTriggerHandler.memeCleEtChevauche(base, enMemoire('F1', 'R1', null, d20, d20.addDays(5))),
            'Périodes disjointes -> pas de chevauchement');
        // MÊME intervenant (compte) + recoupement -> chevauchement (moitié de la clé d'unicité).
        System.Assert.isTrue(
            CatalogueTarifaireTriggerHandler.memeCleEtChevauche(
                enMemoire('F1', 'R1', compteA, d1, d10), enMemoire('F1', 'R1', compteA, d5, d20)),
            'Même intervenant (compte) + recoupement -> chevauchement');
        // Intervenants différents -> clés différentes.
        System.Assert.isFalse(
            CatalogueTarifaireTriggerHandler.memeCleEtChevauche(
                enMemoire('F1', 'R1', compteA, d1, d10), enMemoire('F1', 'R1', compteB, d1, d10)),
            'Comptes différents -> pas de chevauchement');
        // Générique vs spécifique -> clés différentes.
        System.Assert.isFalse(
            CatalogueTarifaireTriggerHandler.memeCleEtChevauche(
                enMemoire('F1', 'R1', null, d1, d10), enMemoire('F1', 'R1', compteA, d1, d10)),
            'Générique vs spécifique -> pas de chevauchement');
        // Fiche / rôle différents -> pas de chevauchement.
        System.Assert.isFalse(
            CatalogueTarifaireTriggerHandler.memeCleEtChevauche(base, enMemoire('F2', 'R1', null, d1, d10)),
            'Fiche différente -> pas de chevauchement');
        System.Assert.isFalse(
            CatalogueTarifaireTriggerHandler.memeCleEtChevauche(base, enMemoire('F1', 'R2', null, d1, d10)),
            'Rôle différent -> pas de chevauchement');
        // Bornes ouvertes (null) -> chevauchement avec toute période.
        System.Assert.isTrue(
            CatalogueTarifaireTriggerHandler.memeCleEtChevauche(
                enMemoire('F1', 'R1', null, null, null), enMemoire('F1', 'R1', null, d1, d10)),
            'Période ouverte -> chevauchement');

        // ---- Multi-comptes (champ Intervenants__c, IDs concaténés) ----
        Id compteC = pfx + '000000000003';

        CatalogueTarifaire__c m1 = enMemoire('F1', 'R1', null, d1, d10);
        m1.Intervenants__c = String.valueOf(compteA) + ';' + String.valueOf(compteB);
        CatalogueTarifaire__c m2 = enMemoire('F1', 'R1', null, d5, d20);
        m2.Intervenants__c = String.valueOf(compteB) + ';' + String.valueOf(compteC);
        // Partagent le compte B -> chevauchement.
        System.Assert.isTrue(
            CatalogueTarifaireTriggerHandler.memeCleEtChevauche(m1, m2),
            'Deux lignes partageant un compte -> chevauchement');

        CatalogueTarifaire__c m3 = enMemoire('F1', 'R1', null, d1, d10);
        m3.Intervenants__c = String.valueOf(compteA);
        CatalogueTarifaire__c m4 = enMemoire('F1', 'R1', null, d1, d10);
        m4.Intervenants__c = String.valueOf(compteB);
        // Ensembles de comptes disjoints -> pas de chevauchement.
        System.Assert.isFalse(
            CatalogueTarifaireTriggerHandler.memeCleEtChevauche(m3, m4),
            'Ensembles de comptes disjoints -> pas de chevauchement');

        // Mono-compte (un seul ID) vs multi partageant ce compte -> chevauchement.
        CatalogueTarifaire__c mono = enMemoire('F1', 'R1', compteA, d1, d10);
        CatalogueTarifaire__c multi = enMemoire('F1', 'R1', null, d1, d10);
        multi.Intervenants__c = String.valueOf(compteA) + ';' + String.valueOf(compteC);
        System.Assert.isTrue(
            CatalogueTarifaireTriggerHandler.memeCleEtChevauche(mono, multi),
            'Mono-compte vs multi partageant le compte -> chevauchement');
    }
}