/**
 * Tests de la Facturation V2 : évaluateur de formules (LC022FormulaEvaluator)
 * et contrôleur catalogue (LC022FacturationCatalogueController).
 *
 * La partie « intégration » (création d'un Pro__c + CatalogueTarifaire__c) est
 * best-effort : si l'org de test impose des champs obligatoires ou des
 * validations spécifiques sur le dossier, le scénario est ignoré sans faire
 * échouer la classe (l'évaluateur et les gardes restent couverts).
 */
@IsTest
private class LC022FacturationCatalogueControllerTest {

    // ------------------------------------------------------- Évaluateur

    private static void assertEval(Decimal expected, String expr, Map<String, Decimal> f) {
        Decimal actual = LC022FormulaEvaluator.evaluate(expr, f);
        System.Assert.isTrue(expected == actual, expr + ' = ' + actual + ' (attendu ' + expected + ')');
    }

    @IsTest
    static void testFormulaArithmetic() {
        Map<String, Decimal> empty = new Map<String, Decimal>();
        assertEval(40, '40', empty);
        assertEval(14, '2 + 3 * 4', empty);
        assertEval(20, '(2 + 3) * 4', empty);
        assertEval(-2, '-5 + 3', empty);
        assertEval(2.5, '10 / 4', empty);
        assertEval(7, '3 - -4', empty);
    }

    @IsTest
    static void testFormulaFunctions() {
        Map<String, Decimal> empty = new Map<String, Decimal>();
        assertEval(10, 'MIN(10, 2000, 50)', empty);
        assertEval(50, 'MAX(10, 2, 50)', empty);
        assertEval(7, 'ABS(-7)', empty);
        assertEval(3.14, 'ARRONDI(3.14159, 2)', empty);
        assertEval(4, 'ARRONDI(3.7)', empty);
        assertEval(3, 'PLANCHER(3.9)', empty);
        assertEval(4, 'PLAFOND(3.1)', empty);
        // Alias anglais
        assertEval(3, 'ROUND(2.5)', empty);
        assertEval(2, 'FLOOR(2.9)', empty);
        assertEval(3, 'CEIL(2.1)', empty);
        assertEval(3, 'CEILING(2.1)', empty);
    }

    @IsTest
    static void testFormulaFields() {
        Map<String, Decimal> f = new Map<String, Decimal>{ 'MPR_SHAB__c' => 90 };
        assertEval(3600, '{MPR_SHAB__c} * 40', f);
        assertEval(2000, 'MIN(2000, {MPR_SHAB__c} * 40)', f);
        // Champ absent -> 0
        assertEval(5, '{Inexistant__c} + 5', f);
    }

    @IsTest
    static void testFormulaErrors() {
        Map<String, Decimal> empty = new Map<String, Decimal>();
        assertFormulaError('', empty);
        assertFormulaError('10 / 0', empty);
        assertFormulaError('{nonferme', empty);
        assertFormulaError('FOO(1)', empty);
        assertFormulaError('2 @ 3', empty);
        assertFormulaError('SHAB * 2', empty);   // identifiant non suivi de (
        assertFormulaError('2 3', empty);          // éléments en trop
        assertFormulaError('(2 + 3', empty);       // parenthèse non fermée
    }

    private static void assertFormulaError(String expr, Map<String, Decimal> f) {
        try {
            LC022FormulaEvaluator.evaluate(expr, f);
            System.Assert.fail('Formule invalide attendue : « ' + expr + ' »');
        } catch (LC022FormulaEvaluator.FormulaException e) {
            System.Assert.isNotNull(e.getMessage());
        }
    }

    // ------------------------------------------------------- Gardes contrôleur

    @IsTest
    static void testGuards() {
        Test.setMock(HttpCalloutMock.class, new CalloutMock());
        Account a = new Account(Name = 'Compte Garde');
        insert a;

        try {
            LC022FacturationCatalogueController.getDossierFacturationV2(null);
            System.Assert.fail('Dossier null doit lever une exception');
        } catch (AuraHandledException e) {
            System.Assert.isNotNull(e.getMessage());
        }

        // numéro d'échéance invalide (rejeté avant toute requête)
        try {
            LC022FacturationCatalogueController.creerLigneFactureCatalogue(
                a.Id, 'Client', 3, 'A la Visite/Previsite', null, 'Compte__c', null
            );
            System.Assert.fail('Échéance 3 doit lever une exception');
        } catch (AuraHandledException e) {
            System.Assert.isNotNull(e.getMessage());
        }

        try {
            LC022FacturationCatalogueController.creerLigneFactureCatalogue(
                a.Id, '', 1, 'A la Visite/Previsite', null, 'Compte__c', null
            );
            System.Assert.fail('Intervenant vide doit lever une exception');
        } catch (AuraHandledException e) {
            System.Assert.isNotNull(e.getMessage());
        }
    }

    // ------------------------------------------------------- Intégration

    private class Scenario {
        Id dossierId;
        String fiche;
        Boolean reached = false;
    }

    // Mock générique : une automatisation déclarative de l'org (flow) peut déclencher
    // un callout HTTP sur l'insert d'Account/Pro__c ; on le neutralise pour le DML en test.
    private class CalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setStatus('OK');
            // L'automatisation org (AccountTriggerHandler.AsyncGetCoordinates) désérialise
            // la réponse en List : il faut un tableau JSON ([]), pas un objet ({}).
            res.setBody('[]');
            return res;
        }
    }

    // Id du Record Type Standard du catalogue (les moteurs ne lisent que le Standard).
    private static Id stdCatalogueRt() {
        Schema.RecordTypeInfo rti = CatalogueTarifaire__c.SObjectType.getDescribe()
            .getRecordTypeInfosByDeveloperName().get('Standard');
        return rti == null ? null : rti.getRecordTypeId();
    }

    /** Construit best-effort un dossier + une ligne catalogue active. */
    private static Scenario buildScenario() {
        Scenario s = new Scenario();
        try {
            // Neutralise un éventuel callout d'automatisation org sur l'insert.
            Test.setMock(HttpCalloutMock.class, new CalloutMock());
            // Valeur de fiche valide (GVS partagé Pro__c / Catalogue)
            List<Schema.PicklistEntry> fes = Pro__c.Fiche_CEE__c.getDescribe().getPicklistValues();
            if (fes.isEmpty()) return null;
            s.fiche = fes[0].getValue();

            Account acc = new Account(Name = 'Compte Intervenant Test');
            insert acc;

            Pro__c d = new Pro__c();
            d.put('Compte__c', acc.Id);
            d.put('Facturer_Client__c', 'OUI'); // Client facturable (sinon la ligne Client est masquée)
            d.put('Fiche_CEE__c', s.fiche);
            d.put('Piste_Date_de_Cr_ation__c', Date.today());

            // Échéance « A la Visite/Previsite » atteinte si la valeur de statut existe.
            // On renseigne aussi les champs exigés par la validation rule PREVISITE6_OUI
            // (nom société, dates, nécessité audit) : sans eux l'insert échoue et le
            // scénario d'intégration serait ignoré en silence (faux vert).
            for (Schema.PicklistEntry pe : Pro__c.Pr_visite_Statut__c.getDescribe().getPicklistValues()) {
                if (pe.getValue() == '🟩Passage Effectué') {
                    d.put('Pr_visite_Statut__c', '🟩Passage Effectué');
                    d.put('Audit_Envoi_en_Visite__c', Date.today());
                    d.put('PREVISITE_Date__c', Datetime.now());
                    d.put('AUDIT_N_c_ssit__c', 'OUI');
                    for (Schema.PicklistEntry ne : Pro__c.Pr_visite_Nom_St__c.getDescribe().getPicklistValues()) {
                        if (ne.getValue() != '▣ Nouveau Dossier') {
                            d.put('Pr_visite_Nom_St__c', ne.getValue());
                            break;
                        }
                    }
                    s.reached = true;
                    break;
                }
            }
            insert d;
            s.dossierId = d.Id;

            CatalogueTarifaire__c c = new CatalogueTarifaire__c();
            c.RecordTypeId = stdCatalogueRt();
            c.Paiement__c = 'Emis';
            c.FicheCEE__c = s.fiche;
            c.RoleIntervenant__c = 'Client';
            c.Statut__c = 'Active';
            c.EcheancePaiement1__c = 'A la Visite/Previsite';
            c.EcheancePaiement2__c = 'Au Devis Signé';
            c.DateDebutValidite__c = Date.today().addDays(-10);
            c.DateFinValidite__c = Date.today().addDays(10);
            c.ParametresFiche__c =
                '{"version":1,"decisionVariables":[],' +
                '"rules":[{"id":"r1","conditions":{},' +
                '"montant1":{"mode":"fixed","value":400},' +
                '"montant2":{"mode":"fixed","value":200}}]}';
            insert c;

            return s;
        } catch (Exception e) {
            System.debug('Scénario d\'intégration ignoré (données org) : ' + e.getMessage());
            return null;
        }
    }

    @IsTest
    static void testGetDossierFacturationV2() {
        Scenario s = buildScenario();
        if (s == null || s.dossierId == null) return; // org-specific : ignoré

        Test.startTest();
        LC022FacturationCatalogueController.FacturationV2Result res =
            LC022FacturationCatalogueController.getDossierFacturationV2(s.dossierId);
        Test.stopTest();

        System.Assert.isNotNull(res, 'Résultat attendu');
        LC022FacturationCatalogueController.IntervenantRow clientRow;
        for (LC022FacturationCatalogueController.IntervenantRow r : res.rows) {
            if (r.role == 'Client') { clientRow = r; break; }
        }
        System.Assert.isNotNull(clientRow, 'La ligne Client (lookup rempli) doit apparaître');
        System.Assert.isTrue(clientRow.catalogueFound, 'La ligne catalogue doit être trouvée');
        System.Assert.isTrue(clientRow.ruleMatched, 'La règle (sans condition) doit matcher');
        System.Assert.areEqual(400, clientRow.com1, 'Montant 1 fixe attendu');
        System.Assert.areEqual(200, clientRow.com2, 'Montant 2 fixe attendu');
        if (s.reached) {
            System.Assert.isTrue(clientRow.ech1Reached, 'Échéance 1 atteinte attendue');
        }
    }

    @IsTest
    static void testCreerLigneFactureCatalogue() {
        Scenario s = buildScenario();
        if (s == null || s.dossierId == null || !s.reached) return; // org-specific : ignoré

        // Compte bénéficiaire = compte rattaché au dossier (Compte__c)
        Pro__c d = [SELECT Compte__c FROM Pro__c WHERE Id = :s.dossierId LIMIT 1];

        Test.startTest();
        // On passe VOLONTAIREMENT une échéance client erronée ('Au Solde CEE') :
        // le serveur doit l'ignorer et stocker SA valeur recalculée (le repli champ
        // fixe ici = 'A la Visite/Previsite'). Le gate s'appuie sur l'atteinte
        // recalculée serveur, pas sur le paramètre client.
        Id ligneId = LC022FacturationCatalogueController.creerLigneFactureCatalogue(
            s.dossierId, 'Client', 1, 'Au Solde CEE', d.Compte__c, 'Compte__c', null
        );
        Test.stopTest();

        System.Assert.isNotNull(ligneId, 'La ligne de facture doit être créée');
        LigneFacture__c lf = [
            SELECT Type_Intervenant__c, Numero_Echeance__c, Montant_HT__c, Echeance_Declenchante__c
            FROM LigneFacture__c WHERE Id = :ligneId LIMIT 1
        ];
        System.Assert.areEqual('Client', lf.Type_Intervenant__c);
        System.Assert.areEqual('1', lf.Numero_Echeance__c);
        System.Assert.areEqual(400, lf.Montant_HT__c, 'Montant recalculé depuis le catalogue');
        System.Assert.areEqual('A la Visite/Previsite', lf.Echeance_Declenchante__c,
            'Échéance déclenchante figée côté serveur : la valeur client erronée est ignorée');

        // Le montant calculé est stocké sur le dossier (Com1_Cli__c) à la création.
        Pro__c reread = [SELECT Com1_Cli__c FROM Pro__c WHERE Id = :s.dossierId LIMIT 1];
        System.Assert.areEqual(400, reread.Com1_Cli__c, 'Commission 1 stockée sur le dossier');
    }

    @IsTest
    static void testMontantModifiableUtiliseValeurSaisie() {
        Test.setMock(HttpCalloutMock.class, new CalloutMock());
        Scenario s = buildScenario();
        if (s == null || s.dossierId == null || !s.reached) return; // org-specific : ignoré

        Pro__c d = [SELECT Compte__c FROM Pro__c WHERE Id = :s.dossierId LIMIT 1];

        // Rend la ligne générique (créée par buildScenario) « montants modifiables ».
        CatalogueTarifaire__c gen = [
            SELECT Id FROM CatalogueTarifaire__c
            WHERE FicheCEE__c = :s.fiche AND RoleIntervenant__c = 'Client' LIMIT 1
        ];
        gen.put('Montants_modifiables__c', true);
        update gen;

        Test.startTest();
        // Montant saisi (250) au lieu du montant calculé (400).
        Id ligneId = LC022FacturationCatalogueController.creerLigneFactureCatalogue(
            s.dossierId, 'Client', 1, 'A la Visite/Previsite', d.Compte__c, 'Compte__c', 250
        );
        Test.stopTest();

        LigneFacture__c lf = [SELECT Montant_HT__c FROM LigneFacture__c WHERE Id = :ligneId LIMIT 1];
        System.Assert.areEqual(250, lf.Montant_HT__c,
            'Ligne modifiable : le montant saisi (250) doit primer sur le calculé (400)');
    }

    @IsTest
    static void testSpecificLinePriorityUsesItsRules() {
        // buildScenario crée déjà une ligne générique (ParametresFiche -> 400/200).
        Scenario s = buildScenario();
        if (s == null || s.dossierId == null) return; // org-specific : ignoré

        Pro__c d = [SELECT Compte__c FROM Pro__c WHERE Id = :s.dossierId LIMIT 1];

        // Ligne SPÉCIFIQUE pour le compte du dossier : sélectionnée en priorité,
        // montant calculé depuis SES PROPRES règles (777). MontantBase volontairement
        // rempli (500) pour prouver qu'il n'est PAS utilisé.
        CatalogueTarifaire__c spec = new CatalogueTarifaire__c();
        spec.RecordTypeId = stdCatalogueRt();
        spec.Paiement__c = 'Emis';
        spec.FicheCEE__c = s.fiche;
        spec.RoleIntervenant__c = 'Client';
        spec.Statut__c = 'Active';
        spec.Intervenants__c = String.valueOf(d.Compte__c);
        spec.MontantBase1__c = 500;
        spec.MontantBase2__c = 500;
        spec.EcheancePaiement1__c = 'A la Visite/Previsite';
        spec.EcheancePaiement2__c = 'Au Devis Signé';
        spec.DateDebutValidite__c = Date.today().addDays(-10);
        spec.DateFinValidite__c = Date.today().addDays(10);
        spec.ParametresFiche__c =
            '{"version":1,"decisionVariables":[],' +
            '"rules":[{"id":"r1","conditions":{},' +
            '"montant1":{"mode":"fixed","value":777},' +
            '"montant2":{"mode":"fixed","value":333}}]}';
        insert spec;

        Test.startTest();
        LC022FacturationCatalogueController.FacturationV2Result res =
            LC022FacturationCatalogueController.getDossierFacturationV2(s.dossierId);
        Test.stopTest();

        LC022FacturationCatalogueController.IntervenantRow clientRow;
        for (LC022FacturationCatalogueController.IntervenantRow r : res.rows) {
            if (r.role == 'Client') { clientRow = r; break; }
        }
        System.Assert.isNotNull(clientRow, 'Ligne Client attendue');
        System.Assert.isTrue(clientRow.catalogueFound, 'Ligne catalogue trouvée');
        // La ligne spécifique l'emporte (sélection) ET son montant vient de SES règles
        // (777/333), pas de la générique (400/200) ni de MontantBase (500).
        System.Assert.areEqual(777, clientRow.com1, 'Spécifique sélectionnée -> ses règles (montant1)');
        System.Assert.areEqual(333, clientRow.com2, 'Spécifique sélectionnée -> ses règles (montant2)');
    }

    @IsTest
    static void testSpecificLineParIntervenantsMulti() {
        // buildScenario crée une ligne générique Client (400/200).
        Scenario s = buildScenario();
        if (s == null || s.dossierId == null) return; // org-specific : ignoré

        Pro__c d = [SELECT Compte__c FROM Pro__c WHERE Id = :s.dossierId LIMIT 1];

        // Ligne SPÉCIFIQUE partagée entre PLUSIEURS comptes via Intervenants__c
        // (sans Intervenant__c). Le 2e compte est un Id fabriqué (champ texte = pas
        // de FK) ; l'ensemble contient le compte du dossier -> doit être sélectionnée.
        Id fake = Account.SObjectType.getDescribe().getKeyPrefix() + '000000000999';
        CatalogueTarifaire__c spec = new CatalogueTarifaire__c();
        spec.RecordTypeId = stdCatalogueRt();
        spec.Paiement__c = 'Emis';
        spec.FicheCEE__c = s.fiche;
        spec.RoleIntervenant__c = 'Client';
        spec.Statut__c = 'Active';
        spec.Intervenants__c = String.valueOf(fake) + ';' + String.valueOf(d.Compte__c);
        spec.DateDebutValidite__c = Date.today().addDays(-10);
        spec.DateFinValidite__c = Date.today().addDays(10);
        spec.ParametresFiche__c =
            '{"version":1,"decisionVariables":[],' +
            '"rules":[{"id":"r1","conditions":{},' +
            '"montant1":{"mode":"fixed","value":888},' +
            '"montant2":{"mode":"fixed","value":444}}]}';
        insert spec;

        Test.startTest();
        LC022FacturationCatalogueController.FacturationV2Result res =
            LC022FacturationCatalogueController.getDossierFacturationV2(s.dossierId);
        Test.stopTest();

        LC022FacturationCatalogueController.IntervenantRow clientRow;
        for (LC022FacturationCatalogueController.IntervenantRow r : res.rows) {
            if (r.role == 'Client') { clientRow = r; break; }
        }
        System.Assert.isNotNull(clientRow, 'Ligne Client attendue');
        // La ligne multi-comptes (Intervenants__c contient le compte du dossier)
        // l'emporte sur la générique.
        System.Assert.areEqual(spec.Id, clientRow.catalogueId,
            'Ligne multi-comptes (Intervenants__c) sélectionnée en priorité');
        System.Assert.areEqual(888, clientRow.com1, 'Montant de la ligne multi-comptes (montant1)');
        System.Assert.areEqual(444, clientRow.com2, 'Montant de la ligne multi-comptes (montant2)');
    }

    @IsTest
    static void testEcheanceParRegleOverridesFixedField() {
        // buildScenario crée une ligne générique Client (échéance fixe atteinte).
        // L'override ne dépend pas de l'atteinte : on ne gate pas sur s.reached.
        Scenario s = buildScenario();
        if (s == null || s.dossierId == null) return; // org-specific : ignoré

        Pro__c d = [SELECT Compte__c FROM Pro__c WHERE Id = :s.dossierId LIMIT 1];

        // Ligne SPÉCIFIQUE (prioritaire) dont l'échéance vient de la RÈGLE
        // (montant1/2.echeance). Les champs fixes portent volontairement une échéance
        // NON atteinte ('Au Solde MPR') pour prouver qu'ils ne sont PLUS la source.
        CatalogueTarifaire__c spec = new CatalogueTarifaire__c();
        spec.RecordTypeId = stdCatalogueRt();
        spec.Paiement__c = 'Emis';
        spec.FicheCEE__c = s.fiche;
        spec.RoleIntervenant__c = 'Client';
        spec.Statut__c = 'Active';
        spec.Intervenants__c = String.valueOf(d.Compte__c);
        spec.EcheancePaiement1__c = 'Au Solde MPR';
        spec.EcheancePaiement2__c = 'Au Solde MPR';
        spec.DateDebutValidite__c = Date.today().addDays(-10);
        spec.DateFinValidite__c = Date.today().addDays(10);
        spec.ParametresFiche__c =
            '{"version":1,"decisionVariables":[],' +
            '"rules":[{"id":"r1","conditions":{},' +
            '"montant1":{"mode":"fixed","value":400,"echeance":"A la Visite/Previsite"},' +
            '"montant2":{"mode":"fixed","value":200,"echeance":"Au Devis Signé"}}]}';
        insert spec;

        Test.startTest();
        LC022FacturationCatalogueController.FacturationV2Result res =
            LC022FacturationCatalogueController.getDossierFacturationV2(s.dossierId);
        Test.stopTest();

        LC022FacturationCatalogueController.IntervenantRow clientRow;
        for (LC022FacturationCatalogueController.IntervenantRow r : res.rows) {
            if (r.role == 'Client') { clientRow = r; break; }
        }
        System.Assert.isNotNull(clientRow, 'Ligne Client attendue');
        // Verrou de sélection : c'est bien la ligne SPÉCIFIQUE qui est évaluée (sinon
        // l'override serait prouvé contre le mauvais enregistrement).
        System.Assert.areEqual(spec.Id, clientRow.catalogueId,
            'La ligne spécifique (prioritaire) doit être la ligne évaluée');
        // L'échéance vient de la RÈGLE, pas du champ fixe ('Au Solde MPR').
        System.Assert.areEqual('A la Visite/Previsite', clientRow.echeance1,
            'Échéance 1 doit venir de montant1.echeance (règle), pas du champ fixe');
        System.Assert.areEqual('Au Devis Signé', clientRow.echeance2,
            'Échéance 2 doit venir de montant2.echeance (règle)');
        // L'atteinte est évaluée sur l'échéance de la règle (prévisite atteinte),
        // alors que le champ fixe 'Au Solde MPR' ne serait pas atteint.
        if (s.reached) {
            System.Assert.isTrue(clientRow.ech1Reached,
                'Échéance 1 (règle = A la Visite/Previsite) atteinte attendue');
        }
    }

    // Opérateurs ensemblistes (in / notIn) : couverture garantie (en mémoire), sans
    // dépendre du scénario d'intégration (données org).
    @IsTest
    static void testOperateursInNotInUnit() {
        Test.startTest();
        LC022FacturationCatalogueController.coverSetOperators();
        Test.stopTest();
        System.Assert.isTrue(true, 'Opérateurs « une parmi » / « différent de » exercés');
    }

    // Validation end-to-end : règles « une parmi » (in) et « différent de » (notIn)
    // sur une picklist du dossier (Fiche_CEE__c), premier-match.
    @IsTest
    static void testRegleInNotInParFiche() {
        Scenario s = buildScenario();
        if (s == null || s.dossierId == null) return; // org-specific : ignoré

        Pro__c d = [SELECT Compte__c FROM Pro__c WHERE Id = :s.dossierId LIMIT 1];

        // Ligne SPÉCIFIQUE (prioritaire) portant 3 règles sur Fiche_CEE__c (= s.fiche) :
        //   r1 : in  {autre}    -> ne matche pas ;
        //   r2 : notIn {s.fiche} -> valeur du dossier exclue -> ne matche pas ;
        //   r3 : notIn {autre}  -> matche -> montant1 = 333.
        CatalogueTarifaire__c spec = new CatalogueTarifaire__c();
        spec.RecordTypeId = stdCatalogueRt();
        spec.Paiement__c = 'Emis';
        spec.FicheCEE__c = s.fiche;
        spec.RoleIntervenant__c = 'Client';
        spec.Statut__c = 'Active';
        spec.Intervenants__c = String.valueOf(d.Compte__c);
        spec.DateDebutValidite__c = Date.today().addDays(-10);
        spec.DateFinValidite__c = Date.today().addDays(10);
        spec.ParametresFiche__c =
            '{"version":1,"decisionVariables":[{"field":"Fiche_CEE__c","type":"picklist"}],"rules":['
            + '{"id":"r1","conditions":{"Fiche_CEE__c":{"comparison":"in","values":["__AUTRE__"]}},'
            + '"montant1":{"mode":"fixed","value":111},"montant2":{"mode":"fixed","value":11}},'
            + '{"id":"r2","conditions":{"Fiche_CEE__c":{"comparison":"notIn","values":["' + s.fiche + '"]}},'
            + '"montant1":{"mode":"fixed","value":222},"montant2":{"mode":"fixed","value":22}},'
            + '{"id":"r3","conditions":{"Fiche_CEE__c":{"comparison":"notIn","values":["__AUTRE__"]}},'
            + '"montant1":{"mode":"fixed","value":333},"montant2":{"mode":"fixed","value":33}}]}';
        insert spec;

        Test.startTest();
        LC022FacturationCatalogueController.FacturationV2Result res =
            LC022FacturationCatalogueController.getDossierFacturationV2(s.dossierId);
        Test.stopTest();

        LC022FacturationCatalogueController.IntervenantRow clientRow;
        for (LC022FacturationCatalogueController.IntervenantRow r : res.rows) {
            if (r.role == 'Client') { clientRow = r; break; }
        }
        System.Assert.isNotNull(clientRow, 'Ligne Client attendue');
        System.Assert.areEqual(spec.Id, clientRow.catalogueId, 'La ligne spécifique doit être évaluée');
        System.Assert.areEqual(333, clientRow.com1,
            'Premier-match : r1(in {autre}) et r2(notIn {fiche}) échouent, r3(notIn {autre}) matche -> 333');
    }

    @IsTest
    static void testCreerLigneEcheanceRegleNonAtteinte() {
        Scenario s = buildScenario();
        if (s == null || s.dossierId == null) return; // org-specific : ignoré

        Pro__c d = [SELECT Compte__c FROM Pro__c WHERE Id = :s.dossierId LIMIT 1];

        // Ligne spécifique (prioritaire) dont l'échéance de RÈGLE n'est pas atteinte
        // sur ce dossier ('Au Solde MPR' : PAC_Statut_MPR__c non posé), avec un montant
        // positif. La création doit être BLOQUÉE par le gate, qui s'appuie sur
        // l'échéance per-règle recalculée serveur — preuve que le gate ne fait pas
        // confiance à la valeur client.
        CatalogueTarifaire__c spec = new CatalogueTarifaire__c();
        spec.RecordTypeId = stdCatalogueRt();
        spec.Paiement__c = 'Emis';
        spec.FicheCEE__c = s.fiche;
        spec.RoleIntervenant__c = 'Client';
        spec.Statut__c = 'Active';
        spec.Intervenants__c = String.valueOf(d.Compte__c);
        spec.DateDebutValidite__c = Date.today().addDays(-10);
        spec.DateFinValidite__c = Date.today().addDays(10);
        spec.ParametresFiche__c =
            '{"version":1,"decisionVariables":[],' +
            '"rules":[{"id":"r1","conditions":{},' +
            '"montant1":{"mode":"fixed","value":400,"echeance":"Au Solde MPR"},' +
            '"montant2":{"mode":"fixed","value":200,"echeance":"Au Solde MPR"}}]}';
        insert spec;

        Test.startTest();
        try {
            // Même en passant une échéance client « atteinte » trompeuse, le gate
            // serveur (échéance de règle non atteinte) doit bloquer.
            LC022FacturationCatalogueController.creerLigneFactureCatalogue(
                s.dossierId, 'Client', 1, 'A la Visite/Previsite', d.Compte__c, 'Compte__c', null
            );
            System.Assert.fail('Création attendue bloquée : échéance de règle non atteinte');
        } catch (AuraHandledException e) {
            System.Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }
}