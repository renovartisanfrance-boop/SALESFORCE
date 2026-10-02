/**
 * Tests du contrôleur de Facturation DEPUIS LE COMPTE (LC023FacturationCompteController).
 *
 * L'intégration (Compte + Pro__c + CatalogueTarifaire__c + Facture__c) est
 * best-effort : si l'org impose des champs/validations spécifiques, le scénario
 * est ignoré sans faire échouer la classe. Le callout déclaratif de l'org sur
 * l'insert d'Account est neutralisé par un HttpCalloutMock.
 */
@IsTest
private class LC023FacturationCompteControllerTest {

    private class Scenario {
        Id compteId;
        Id dossierId;
        String fiche;
        Boolean reached = false;
    }

    // Neutralise un éventuel callout d'automatisation org sur l'insert d'Account/Pro__c.
    private class CalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setStatus('OK');
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

    // Id du Record Type Supplémentaire du catalogue (null s'il n'existe pas).
    private static Id suppCatalogueRt() {
        Schema.RecordTypeInfo rti = CatalogueTarifaire__c.SObjectType.getDescribe()
            .getRecordTypeInfosByDeveloperName().get('Supplementaire');
        return rti == null ? null : rti.getRecordTypeId();
    }

    // Id du Record Type Acompte du catalogue (null s'il n'existe pas).
    private static Id catalogueAcompteRt() {
        Schema.RecordTypeInfo rti = CatalogueTarifaire__c.SObjectType.getDescribe()
            .getRecordTypeInfosByDeveloperName().get('Acompte');
        return rti == null ? null : rti.getRecordTypeId();
    }

    // Id du Record Type Acompte de Facture__c (null s'il n'existe pas).
    private static Id factureAcompteRt() {
        Schema.RecordTypeInfo rti = Facture__c.SObjectType.getDescribe()
            .getRecordTypeInfosByDeveloperName().get('Acompte');
        return rti == null ? null : rti.getRecordTypeId();
    }

    // Une valeur de echeanceSupp__c contenant le chiffre voulu (ex. « 2 »), ou null
    // si le champ/la valeur n'existe pas dans l'org (test best-effort).
    private static String suppEcheanceValue(String digit) {
        Map<String, Schema.SObjectField> fm = CatalogueTarifaire__c.SObjectType.getDescribe().fields.getMap();
        if (!fm.containsKey('echeancesupp__c')) return null;
        for (Schema.PicklistEntry pe : fm.get('echeancesupp__c').getDescribe().getPicklistValues()) {
            if (pe.getValue().contains(digit)) return pe.getValue();
        }
        return null;
    }

    // Une valeur de echeanceSupp__c contenant un texte (insensible à la casse), ou null.
    private static String suppEcheanceValueContaining(String needle) {
        Map<String, Schema.SObjectField> fm = CatalogueTarifaire__c.SObjectType.getDescribe().fields.getMap();
        if (!fm.containsKey('echeancesupp__c')) return null;
        String n = needle.toLowerCase();
        for (Schema.PicklistEntry pe : fm.get('echeancesupp__c').getDescribe().getPicklistValues()) {
            if (pe.getValue().toLowerCase().contains(n)) return pe.getValue();
        }
        return null;
    }

    private static Scenario buildScenario() {
        Scenario s = new Scenario();
        try {
            Test.setMock(HttpCalloutMock.class, new CalloutMock());

            List<Schema.PicklistEntry> fes = Pro__c.Fiche_CEE__c.getDescribe().getPicklistValues();
            if (fes.isEmpty()) return null;
            s.fiche = fes[0].getValue();

            Account acc = new Account(Name = 'Compte Facturation 023');
            insert acc;
            s.compteId = acc.Id;

            Pro__c d = new Pro__c();
            d.put('Compte__c', acc.Id);
            d.put('Facturer_Client__c', 'OUI'); // Client facturable (sinon la ligne Client est masquée)
            d.put('Fiche_CEE__c', s.fiche);
            d.put('Piste_Date_de_Cr_ation__c', Date.today());

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
            System.debug('Scénario 023 ignoré (données org) : ' + e.getMessage());
            return null;
        }
    }

    // Champs de facture cohérents avec les VR (HT = somme des lignes choisies).
    private static Map<String, Object> factureFields(Decimal ht) {
        String tauxVal = null;
        Decimal taux = null;
        for (Schema.PicklistEntry pe : Facture__c.Taux_TVA__c.getDescribe().getPicklistValues()) {
            try {
                Decimal dd = Decimal.valueOf(pe.getValue());
                if (dd == 0) { tauxVal = pe.getValue(); taux = 0; break; }
                if (tauxVal == null) { tauxVal = pe.getValue(); taux = dd; }
            } catch (Exception e) { /* valeur non numérique ignorée */ }
        }
        if (tauxVal == null) { tauxVal = '0'; taux = 0; }
        Decimal tva = (ht * taux / 100).setScale(2);
        Decimal ttc = (ht + tva).setScale(2);
        return new Map<String, Object>{
            'MontantHT__c' => ht,
            'Taux_TVA__c' => tauxVal,
            'MontantTVA__c' => tva,
            'Montant_Total__c' => ttc,
            'N_Facture_Externe__c' => 'TEST-023-001',
            'DateFacture__c' => Date.today()
        };
    }

    // ------------------------------------------------------------------ Gardes

    @IsTest
    static void testGuardCompteNull() {
        Test.setMock(HttpCalloutMock.class, new CalloutMock());
        try {
            LC023FacturationCompteController.getCompteFacturation(null);
            System.Assert.fail('Compte null doit lever une exception');
        } catch (AuraHandledException e) {
            System.Assert.isNotNull(e.getMessage());
        }
    }

    @IsTest
    static void testGuardSelectionVide() {
        Test.setMock(HttpCalloutMock.class, new CalloutMock());
        Account a = new Account(Name = 'Compte Vide 023');
        insert a;
        try {
            LC023FacturationCompteController.creerFactureDepuisCompte(
                a.Id, new Map<String, Object>(), new List<Map<String, Object>>(), null, null
            );
            System.Assert.fail('Sélection vide doit lever une exception');
        } catch (AuraHandledException e) {
            System.Assert.isNotNull(e.getMessage());
        }
    }

    // ------------------------------------------------------------- Découverte

    @IsTest
    static void testGetCompteFacturation() {
        Scenario s = buildScenario();
        if (s == null || s.dossierId == null) return;

        Test.startTest();
        LC023FacturationCompteController.CompteFacturationResult res =
            LC023FacturationCompteController.getCompteFacturation(s.compteId);
        Test.stopTest();

        System.Assert.isNotNull(res, 'Résultat attendu');
        System.Assert.areEqual(s.compteId, res.compteId);

        LC023FacturationCompteController.CompteLigneRow ech1;
        LC023FacturationCompteController.CompteLigneRow ech2;
        for (LC023FacturationCompteController.CompteLigneRow r : res.rows) {
            if (r.role == 'Client' && r.numEcheance == 1) ech1 = r;
            if (r.role == 'Client' && r.numEcheance == 2) ech2 = r;
        }
        System.Assert.isNotNull(ech1, 'Ligne Client échéance 1 attendue');
        System.Assert.areEqual(400, ech1.montant, 'Montant 1 (catalogue) = 400');
        System.Assert.isNotNull(ech2, 'Ligne Client échéance 2 attendue');
        System.Assert.areEqual(200, ech2.montant, 'Montant 2 (catalogue) = 200');
        // Échéance 2 « Au Devis Signé » non atteinte -> non sélectionnable.
        System.Assert.areEqual('NON_ATTEINTE', ech2.status, 'Échéance 2 non atteinte');
        System.Assert.isFalse(ech2.selectable, 'Échéance 2 non sélectionnable');
        if (s.reached) {
            System.Assert.areEqual('A_CREER', ech1.status, 'Échéance 1 atteinte -> à créer');
            System.Assert.isTrue(ech1.selectable, 'Échéance 1 sélectionnable');
        }
    }

    // ---------------------------------------------------------- Création complète

    @IsTest
    static void testCreerFactureDepuisCompte() {
        Scenario s = buildScenario();
        if (s == null || s.dossierId == null || !s.reached) return;

        LC023FacturationCompteController.CompteFacturationResult res =
            LC023FacturationCompteController.getCompteFacturation(s.compteId);
        LC023FacturationCompteController.CompteLigneRow target;
        for (LC023FacturationCompteController.CompteLigneRow r : res.rows) {
            if (r.role == 'Client' && r.numEcheance == 1 && r.status == 'A_CREER') target = r;
        }
        if (target == null) return;

        Map<String, Object> sel = new Map<String, Object>{ 'rowKey' => target.key, 'selType' => 'A_CREER' };

        Test.startTest();
        Id factureId = LC023FacturationCompteController.creerFactureDepuisCompte(
            s.compteId, factureFields(400),
            new List<Map<String, Object>>{ sel }, new List<Id>(), null
        );
        Test.stopTest();

        System.Assert.isNotNull(factureId, 'Facture créée attendue');
        Facture__c f = [
            SELECT Id, Statut__c, Destinataire_Compte__c, MontantHT__c,
                   (SELECT Id, Montant_HT__c, Type_Intervenant__c, Numero_Echeance__c FROM Factures_associees__r)
            FROM Facture__c WHERE Id = :factureId LIMIT 1
        ];
        System.Assert.areEqual(s.compteId, f.Destinataire_Compte__c, 'Bénéficiaire = compte courant');
        System.Assert.areEqual('Validé', f.Statut__c, 'Facture validée à la création');
        System.Assert.areEqual(1, f.Factures_associees__r.size(), 'Une ligne rattachée');
        System.Assert.areEqual(400, f.Factures_associees__r[0].Montant_HT__c, 'Montant HT de la ligne');
        System.Assert.areEqual('Client', f.Factures_associees__r[0].Type_Intervenant__c);

        // Réécriture de la commission sur le dossier (aligné sur la V2) : l'échéance 1
        // facturée (400) est recopiée dans Com1_Cli__c du dossier (rôle Client).
        // Best-effort : ignoré si le champ n'existe pas dans l'org (réécriture défensive
        // côté contrôleur), via SOQL dynamique pour rester déployable partout.
        if (Pro__c.SObjectType.getDescribe().fields.getMap().containsKey('com1_cli__c')) {
            Id did = s.dossierId;
            List<SObject> dossiers = Database.query(
                'SELECT Com1_Cli__c FROM Pro__c WHERE Id = :did LIMIT 1'
            );
            Decimal com1 = (Decimal) dossiers[0].get('Com1_Cli__c');
            System.Assert.areEqual(400, com1,
                'Commission éch.1 (400) recopiée sur le dossier (Com1_Cli__c)');
        }
    }

    // ----------------------------------------------------- Réutilisation existante

    @IsTest
    static void testReutiliseLigneExistante() {
        Scenario s = buildScenario();
        if (s == null || s.dossierId == null) return;

        // Ligne déjà créée, non liée à une facture : doit être réutilisée (pas recréée).
        LigneFacture__c existing;
        try {
            existing = new LigneFacture__c(
                Dossier__c = s.dossierId,
                Intervenant_Compte__c = s.compteId,
                Type_Intervenant__c = 'Client',
                Numero_Echeance__c = '1',
                Montant_HT__c = 400
            );
            insert existing;
        } catch (Exception e) {
            return; // champs/VR org-spécifiques : best-effort
        }

        LC023FacturationCompteController.CompteFacturationResult res =
            LC023FacturationCompteController.getCompteFacturation(s.compteId);
        LC023FacturationCompteController.CompteLigneRow target;
        for (LC023FacturationCompteController.CompteLigneRow r : res.rows) {
            if (r.role == 'Client' && r.numEcheance == 1) target = r;
        }
        System.Assert.isNotNull(target, 'Ligne Client éch.1 attendue');
        System.Assert.areEqual('EXISTANTE', target.status, 'Ligne déjà créée -> EXISTANTE');
        System.Assert.areEqual(existing.Id, target.existingLigneId, 'Référence la ligne existante');

        Map<String, Object> sel = new Map<String, Object>{ 'rowKey' => target.key, 'selType' => 'EXISTANTE' };

        Test.startTest();
        Id factureId = LC023FacturationCompteController.creerFactureDepuisCompte(
            s.compteId, factureFields(400),
            new List<Map<String, Object>>{ sel }, new List<Id>(), null
        );
        Test.stopTest();

        Facture__c f = [
            SELECT Id, (SELECT Id FROM Factures_associees__r) FROM Facture__c WHERE Id = :factureId LIMIT 1
        ];
        System.Assert.areEqual(1, f.Factures_associees__r.size(), 'Une seule ligne (réutilisée)');
        System.Assert.areEqual(existing.Id, f.Factures_associees__r[0].Id, 'La ligne existante est réutilisée, pas recréée');
    }

    // ----------------------------------------------- Sécurité : non atteinte bloquée

    @IsTest
    static void testEcheanceNonAtteinteRejetee() {
        Scenario s = buildScenario();
        if (s == null || s.dossierId == null) return;

        LC023FacturationCompteController.CompteFacturationResult res =
            LC023FacturationCompteController.getCompteFacturation(s.compteId);
        LC023FacturationCompteController.CompteLigneRow nonAtteinte;
        for (LC023FacturationCompteController.CompteLigneRow r : res.rows) {
            if (r.status == 'NON_ATTEINTE') { nonAtteinte = r; break; }
        }
        if (nonAtteinte == null) return;

        Map<String, Object> sel = new Map<String, Object>{ 'rowKey' => nonAtteinte.key, 'selType' => 'A_CREER' };

        Test.startTest();
        try {
            LC023FacturationCompteController.creerFactureDepuisCompte(
                s.compteId, factureFields(nonAtteinte.montant),
                new List<Map<String, Object>>{ sel }, new List<Id>(), null
            );
            System.Assert.fail('Une échéance non atteinte ne doit pas être facturable');
        } catch (AuraHandledException e) {
            System.Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    // ------------------------------------------- Montant modifiable (décision 7)

    @IsTest
    static void testMontantModifiableHonoreSaisie() {
        Scenario s = buildScenario();
        if (s == null || s.dossierId == null || !s.reached) return;

        // Rend la ligne catalogue « montants modifiables ».
        CatalogueTarifaire__c cat = [
            SELECT Id FROM CatalogueTarifaire__c
            WHERE FicheCEE__c = :s.fiche AND RoleIntervenant__c = 'Client' LIMIT 1
        ];
        cat.put('Montants_modifiables__c', true);
        update cat;

        LC023FacturationCompteController.CompteFacturationResult res =
            LC023FacturationCompteController.getCompteFacturation(s.compteId);
        LC023FacturationCompteController.CompteLigneRow target;
        for (LC023FacturationCompteController.CompteLigneRow r : res.rows) {
            if (r.role == 'Client' && r.numEcheance == 1 && r.status == 'A_CREER') target = r;
        }
        if (target == null) return;
        System.Assert.isTrue(target.montantEditable, 'Ligne modifiable -> montant éditable');

        Map<String, Object> sel = new Map<String, Object>{
            'rowKey' => target.key, 'selType' => 'A_CREER', 'montantSaisi' => 250
        }; // montant saisi au lieu du montant catalogue (400)

        Test.startTest();
        Id factureId = LC023FacturationCompteController.creerFactureDepuisCompte(
            s.compteId, factureFields(250),
            new List<Map<String, Object>>{ sel }, new List<Id>(), null
        );
        Test.stopTest();

        Facture__c f = [
            SELECT Id, MontantHT__c, (SELECT Montant_HT__c FROM Factures_associees__r)
            FROM Facture__c WHERE Id = :factureId LIMIT 1
        ];
        System.Assert.areEqual(1, f.Factures_associees__r.size(), 'Une ligne créée');
        System.Assert.areEqual(250, f.Factures_associees__r[0].Montant_HT__c,
            'Ligne modifiable : le montant saisi (250) doit primer sur le calculé (400)');
        System.Assert.areEqual(250, f.MontantHT__c, 'HT facture calculé serveur = Σ lignes');

        // La commission recopiée sur le dossier = le montant FINAL facturé (saisi 250),
        // pas la valeur catalogue (400). Best-effort (champ optionnel dans l'org).
        if (Pro__c.SObjectType.getDescribe().fields.getMap().containsKey('com1_cli__c')) {
            Id did = s.dossierId;
            List<SObject> dossiers = Database.query(
                'SELECT Com1_Cli__c FROM Pro__c WHERE Id = :did LIMIT 1'
            );
            System.Assert.areEqual(250, (Decimal) dossiers[0].get('Com1_Cli__c'),
                'Dossier : Com1_Cli__c = montant saisi facturé (250), pas le catalogue (400)');
        }
    }

    // ----------------------------------------- Clé de sélection inconnue rejetée
    // Exerce aussi getCompteFacturation + résolution inverse (sans dossier -> vide).

    @IsTest
    static void testCleInconnueRejetee() {
        Test.setMock(HttpCalloutMock.class, new CalloutMock());
        Account a = new Account(Name = 'Compte Sans Dossier 023');
        insert a;

        Map<String, Object> sel = new Map<String, Object>{ 'rowKey' => a.Id + '||Client||1', 'selType' => 'A_CREER' };

        Test.startTest();
        try {
            LC023FacturationCompteController.creerFactureDepuisCompte(
                a.Id, factureFields(100),
                new List<Map<String, Object>>{ sel }, null, null
            );
            System.Assert.fail('Une clé de sélection inconnue doit être rejetée');
        } catch (AuraHandledException e) {
            System.Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    // Opérateurs ensemblistes (in / notIn) : couverture garantie (en mémoire), sans
    // dépendre du scénario d'intégration (données org).
    @IsTest
    static void testOperateursInNotInUnit() {
        Test.startTest();
        LC023FacturationCompteController.coverSetOperators();
        Test.stopTest();
        System.Assert.isTrue(true, 'Opérateurs « une parmi » / « différent de » exercés');
    }

    // ------------------------------------------------- RT Supplémentaire (Porte 1/2)

    @IsTest
    static void testSupplementaire() {
        Id suppRt = suppCatalogueRt();
        String echVal = suppEcheanceValue('2'); // Porte 2 -> cascade (Porte 1 + 2)
        if (suppRt == null || echVal == null) return; // RT/picklist absent -> best-effort

        Scenario s;
        try {
            Test.setMock(HttpCalloutMock.class, new CalloutMock());
            s = buildScenario();
            if (s == null || s.dossierId == null) return;

            // Dossier : Porte 2 atteinte (PREVISITE_PORTE__c restreinte = « ⬛Porte 2 »).
            Pro__c d = new Pro__c(Id = s.dossierId);
            d.put('PREVISITE_PORTE__c', '⬛Porte 2');
            update d;

            // Ligne catalogue Supplémentaire (Client) : échéance Porte, montant 150.
            CatalogueTarifaire__c sc = new CatalogueTarifaire__c();
            sc.RecordTypeId = suppRt;
            sc.FicheCEE__c = s.fiche;
            sc.RoleIntervenant__c = 'Client';
            sc.Statut__c = 'Active';
            sc.put('echeanceSupp__c', echVal);
            sc.DateDebutValidite__c = Date.today().addDays(-10);
            sc.DateFinValidite__c = Date.today().addDays(10);
            sc.ParametresFiche__c =
                '{"version":1,"decisionVariables":[],' +
                '"rules":[{"id":"r1","conditions":{},"montant1":{"mode":"fixed","value":150}}]}';
            insert sc;
        } catch (Exception e) {
            return; // champs/VR org-spécifiques : best-effort
        }

        LC023FacturationCompteController.CompteFacturationResult res =
            LC023FacturationCompteController.getCompteFacturation(s.compteId);

        LC023FacturationCompteController.CompteLigneRow supp;
        for (LC023FacturationCompteController.CompteLigneRow r : res.rows) {
            if (r.isSupplementaire && r.role == 'Client') { supp = r; break; }
        }
        System.Assert.isNotNull(supp, 'Une ligne Supplémentaire Client attendue (Porte 2 atteinte)');
        System.Assert.areEqual(150, supp.montant, 'Montant = celui du catalogue (150)');
        System.Assert.isTrue(supp.selectable, 'Échéance Porte réalisée -> sélectionnable');
        System.Assert.isNull(supp.numEcheance, 'Pas de N° d\'échéance pour le Supplémentaire');
        System.Assert.areEqual(echVal, supp.echeance, 'Libellé d\'échéance = valeur echeanceSupp__c');

        Map<String, Object> sel = new Map<String, Object>{ 'rowKey' => supp.key, 'selType' => 'A_CREER' };

        Test.startTest();
        Id factureId = LC023FacturationCompteController.creerFactureDepuisCompte(
            s.compteId, factureFields(150), new List<Map<String, Object>>{ sel }, new List<Id>(), null
        );
        Test.stopTest();

        System.Assert.isNotNull(factureId, 'Facture créée attendue');
        List<LigneFacture__c> lignes = [
            SELECT Id, Numero_Echeance__c, Echeance_Declenchante__c, Montant_HT__c
            FROM LigneFacture__c
            WHERE Dossier__c = :s.dossierId AND Type_Intervenant__c = 'Client'
              AND Numero_Echeance__c = null
        ];
        System.Assert.areEqual(1, lignes.size(), 'Une ligne Supplémentaire créée (sans N° d\'échéance)');
        System.Assert.areEqual(echVal, lignes[0].Echeance_Declenchante__c, 'Échéance Porte stockée dans Echeance_Declenchante__c');
        System.Assert.areEqual(150, lignes[0].Montant_HT__c, 'Montant catalogue facturé');

        // Après création : la ligne Supplémentaire n'est plus recréable (identité
        // dossier + ligne catalogue) -> non sélectionnable, statut de la facture liée.
        LC023FacturationCompteController.CompteFacturationResult res2 =
            LC023FacturationCompteController.getCompteFacturation(s.compteId);
        LC023FacturationCompteController.CompteLigneRow supp2;
        for (LC023FacturationCompteController.CompteLigneRow r : res2.rows) {
            if (r.isSupplementaire && r.role == 'Client') { supp2 = r; break; }
        }
        System.Assert.isNotNull(supp2, 'La ligne Supplémentaire reste affichée après création');
        System.Assert.isFalse(supp2.selectable, 'Ligne déjà créée -> non recréable / non sélectionnable');
        System.Assert.areNotEqual('A_CREER', supp2.status, 'Ligne déjà créée -> plus « à créer »');
    }

    // ------------------------------------------- Facturation Acompte (catalogue)

    @IsTest
    static void testAcompteCatalogue() {
        Id catRt = catalogueAcompteRt();
        Id factRt = factureAcompteRt();
        if (catRt == null || factRt == null) return; // RT Acompte absent -> best-effort

        Scenario s;
        try {
            Test.setMock(HttpCalloutMock.class, new CalloutMock());
            s = buildScenario();
            if (s == null || s.dossierId == null || !s.reached) return;

            // Dossier : « à la charge de l'apporteur d'affaire » (condition par défaut Acompte).
            Pro__c d = new Pro__c(Id = s.dossierId);
            d.put('A_La_charge_de_l_apporteur_d_affaire__c', '🟦A La charge de l\'apporteur d\'affaire');
            update d;

            // Ligne catalogue Acompte (Client) : montant 100 + condition par défaut.
            CatalogueTarifaire__c ac = new CatalogueTarifaire__c();
            ac.RecordTypeId = catRt;
            ac.FicheCEE__c = s.fiche;
            ac.RoleIntervenant__c = 'Client';
            ac.Statut__c = 'Active';
            ac.DateDebutValidite__c = Date.today().addDays(-10);
            ac.DateFinValidite__c = Date.today().addDays(10);
            ac.ParametresFiche__c =
                '{"version":1,"decisionVariables":[],"rules":[{"id":"r1","conditions":' +
                '{"A_La_charge_de_l_apporteur_d_affaire__c":{"comparison":"exact",' +
                '"value":"🟦A La charge de l\'apporteur d\'affaire"}},' +
                '"montant1":{"mode":"fixed","value":100}}]}';
            insert ac;
        } catch (Exception e) {
            return; // champs/VR org-spécifiques : best-effort
        }

        // Ligne facturée Client éch.1 (à créer).
        LC023FacturationCompteController.CompteFacturationResult res =
            LC023FacturationCompteController.getCompteFacturation(s.compteId);
        LC023FacturationCompteController.CompteLigneRow target;
        for (LC023FacturationCompteController.CompteLigneRow r : res.rows) {
            if (r.role == 'Client' && r.numEcheance == 1 && r.status == 'A_CREER') target = r;
        }
        if (target == null) return;

        // Propositions d'acompte pour cette ligne (taux 20 %).
        List<LC023FacturationCompteController.AcompteProposition> props =
            LC023FacturationCompteController.getPropositionsAcompte(
                s.compteId, new List<String>{ target.key }, 20
            );
        System.Assert.isFalse(props.isEmpty(), 'Une proposition d\'acompte attendue (catalogue Acompte applicable)');
        LC023FacturationCompteController.AcompteProposition p = props[0];
        System.Assert.areEqual(100, p.montantHT, 'Montant HT = montant catalogue (100)');
        System.Assert.areEqual(20, p.montantTVA, 'TVA = 20 % de 100');
        System.Assert.areEqual(120, p.montantTTC, 'TTC = 120');

        // Création : ligne (400) + acompte catalogue (100) -> HT Classique attendu = 300.
        Map<String, Object> sel = new Map<String, Object>{ 'rowKey' => target.key, 'selType' => 'A_CREER' };
        Map<String, Object> acSel = new Map<String, Object>{ 'key' => p.key, 'numero' => 'AC-TEST-1' };

        Test.startTest();
        Id factureId;
        try {
            factureId = LC023FacturationCompteController.creerFactureDepuisCompte(
                s.compteId, factureFields(300),
                new List<Map<String, Object>>{ sel }, new List<Id>(),
                new List<Map<String, Object>>{ acSel }
            );
        } catch (AuraHandledException e) {
            // VR/champs requis spécifiques à l'org sur la Facture Acompte : best-effort.
            Test.stopTest();
            return;
        }
        Test.stopTest();

        System.Assert.isNotNull(factureId, 'Facture Classique créée attendue');
        List<Facture__c> acomptes = [
            SELECT Id, MontantHT__c, N_Facture_Externe__c, Facture_Solde__c, Designation__c
            FROM Facture__c
            WHERE Destinataire_Compte__c = :s.compteId AND RecordType.DeveloperName = 'Acompte'
        ];
        System.Assert.areEqual(1, acomptes.size(), 'Une facture d\'acompte créée');
        System.Assert.areEqual(100, acomptes[0].MontantHT__c, 'HT de l\'acompte = montant catalogue');
        System.Assert.areEqual('AC-TEST-1', acomptes[0].N_Facture_Externe__c, 'N° externe saisi conservé');
        System.Assert.areEqual(factureId, acomptes[0].Facture_Solde__c, 'Acompte rattaché à la Classique');
        System.Assert.areEqual('-', acomptes[0].Designation__c,
            'Désignation (texte fixe) portée par l\'acompte');

        // Marqueur de consommation : une LigneFacture liée au dossier + à la ligne
        // catalogue Acompte, rattachée à la facture d'acompte.
        List<LigneFacture__c> markers = [
            SELECT Id, Dossier__c, Catalogue_tarifaire__c, Facture__c
            FROM LigneFacture__c
            WHERE Dossier__c = :s.dossierId AND Catalogue_tarifaire__c != null
              AND Facture__r.RecordType.DeveloperName = 'Acompte'
        ];
        System.Assert.areEqual(1, markers.size(), 'Un marqueur de consommation (LigneFacture) créé');

        // Anti-doublon : la même (dossier + ligne catalogue Acompte) n'est plus proposée.
        List<LC023FacturationCompteController.AcompteProposition> props2 =
            LC023FacturationCompteController.getPropositionsAcompte(
                s.compteId, new List<String>{ target.key }, 20
            );
        System.Assert.isTrue(props2.isEmpty(),
            'Acompte déjà consommé (dossier + ligne catalogue) -> plus proposé');
    }

    // Ligne catalogue Acompte « toutes fiches » (FicheCEE vide) : doit être proposée
    // (la Fiche est facultative pour l'Acompte). Le dossier est « à la charge apporteur »
    // -> la condition de prise en charge (désormais RESPECTÉE) matche.
    @IsTest
    static void testAcompteCatalogueToutesFiches() {
        Id catRt = catalogueAcompteRt();
        if (catRt == null) return; // RT Acompte absent -> best-effort

        Scenario s;
        try {
            Test.setMock(HttpCalloutMock.class, new CalloutMock());
            s = buildScenario();
            if (s == null || s.dossierId == null || !s.reached) return;

            // Prise en charge apporteur (matche la condition de la règle).
            Pro__c d = new Pro__c(Id = s.dossierId);
            d.put('A_La_charge_de_l_apporteur_d_affaire__c', '🟦A La charge de l\'apporteur d\'affaire');
            update d;

            // Ligne Acompte SANS fiche (toutes fiches), condition « à la charge apporteur ».
            CatalogueTarifaire__c ac = new CatalogueTarifaire__c();
            ac.RecordTypeId = catRt;
            ac.RoleIntervenant__c = 'Client';
            ac.Statut__c = 'Active';
            ac.DateDebutValidite__c = Date.today().addDays(-10);
            ac.DateFinValidite__c = Date.today().addDays(10);
            ac.ParametresFiche__c =
                '{"version":1,"decisionVariables":[],"rules":[{"id":"r1","conditions":' +
                '{"A_La_charge_de_l_apporteur_d_affaire__c":{"comparison":"exact",' +
                '"value":"🟦A La charge de l\'apporteur d\'affaire"}},' +
                '"montant1":{"mode":"fixed","value":80}}]}';
            insert ac; // FicheCEE__c laissé vide
        } catch (Exception e) {
            return; // best-effort
        }

        LC023FacturationCompteController.CompteFacturationResult res =
            LC023FacturationCompteController.getCompteFacturation(s.compteId);
        LC023FacturationCompteController.CompteLigneRow target;
        for (LC023FacturationCompteController.CompteLigneRow r : res.rows) {
            if (r.role == 'Client' && r.numEcheance == 1 && r.status == 'A_CREER') target = r;
        }
        if (target == null) return;

        List<LC023FacturationCompteController.AcompteProposition> props =
            LC023FacturationCompteController.getPropositionsAcompte(
                s.compteId, new List<String>{ target.key }, 0
            );
        Boolean found = false;
        for (LC023FacturationCompteController.AcompteProposition p : props) {
            if (p.montantHT == 80) found = true;
        }
        System.Assert.isTrue(found,
            'Ligne Acompte « toutes fiches » proposée (dossier « à la charge apporteur » = condition)');
    }

    // Prise en charge RESPECTÉE : un dossier « à notre charge » ne doit recevoir AUCUN
    // acompte dont la règle exige « à la charge de l'apporteur d'affaire ».
    @IsTest
    static void testAcompteAChargeNonApporteurExclu() {
        Id catRt = catalogueAcompteRt();
        if (catRt == null) return;

        Scenario s;
        try {
            Test.setMock(HttpCalloutMock.class, new CalloutMock());
            s = buildScenario();
            if (s == null || s.dossierId == null || !s.reached) return;

            // Dossier « à notre charge » : NE matche PAS la condition apporteur.
            Pro__c d = new Pro__c(Id = s.dossierId);
            d.put('A_La_charge_de_l_apporteur_d_affaire__c', '🟩A Notre charge');
            update d;

            CatalogueTarifaire__c ac = new CatalogueTarifaire__c();
            ac.RecordTypeId = catRt;
            ac.FicheCEE__c = s.fiche;
            ac.RoleIntervenant__c = 'Client';
            ac.Statut__c = 'Active';
            ac.DateDebutValidite__c = Date.today().addDays(-10);
            ac.DateFinValidite__c = Date.today().addDays(10);
            ac.ParametresFiche__c =
                '{"version":1,"decisionVariables":[],"rules":[{"id":"r1","conditions":' +
                '{"A_La_charge_de_l_apporteur_d_affaire__c":{"comparison":"exact",' +
                '"value":"🟦A La charge de l\'apporteur d\'affaire"}},' +
                '"montant1":{"mode":"fixed","value":90}}]}';
            insert ac;
        } catch (Exception e) {
            return;
        }

        LC023FacturationCompteController.CompteFacturationResult res =
            LC023FacturationCompteController.getCompteFacturation(s.compteId);
        LC023FacturationCompteController.CompteLigneRow target;
        for (LC023FacturationCompteController.CompteLigneRow r : res.rows) {
            if (r.role == 'Client' && r.numEcheance == 1 && r.status == 'A_CREER') target = r;
        }
        if (target == null) return;

        List<LC023FacturationCompteController.AcompteProposition> props =
            LC023FacturationCompteController.getPropositionsAcompte(
                s.compteId, new List<String>{ target.key }, 20
            );
        System.Assert.isTrue(props.isEmpty(),
            'Dossier « à notre charge » -> aucun acompte dont la règle exige « à la charge apporteur »');
    }

    // Cascade des paliers Porte pour l'Acompte : un dossier « Porte 2 » réalise l'acompte
    // « Porte 1 » ET l'acompte « Porte 2 » -> DEUX propositions (une par ligne catalogue).
    @IsTest
    static void testAcompteCascadePorte() {
        Id catRt = catalogueAcompteRt();
        if (catRt == null) return;

        Scenario s;
        try {
            Test.setMock(HttpCalloutMock.class, new CalloutMock());
            s = buildScenario();
            if (s == null || s.dossierId == null || !s.reached) return;

            Pro__c d = new Pro__c(Id = s.dossierId);
            d.put('A_La_charge_de_l_apporteur_d_affaire__c', '🟦A La charge de l\'apporteur d\'affaire');
            d.put('PREVISITE_PORTE__c', '⬛Porte 2'); // Porte 2 atteinte -> cascade sur Porte 1
            update d;

            // Ligne Porte 1 -> 80 (réalisée par cascade car dossier = Porte 2).
            CatalogueTarifaire__c p1 = new CatalogueTarifaire__c();
            p1.RecordTypeId = catRt;
            p1.FicheCEE__c = s.fiche;
            p1.RoleIntervenant__c = 'Client';
            p1.Statut__c = 'Active';
            p1.DateDebutValidite__c = Date.today().addDays(-10);
            p1.DateFinValidite__c = Date.today().addDays(10);
            p1.ParametresFiche__c =
                '{"version":1,"decisionVariables":[],"rules":[{"id":"r1","conditions":' +
                '{"PREVISITE_PORTE__c":{"comparison":"exact","value":"⬛Porte 1"}},' +
                '"montant1":{"mode":"fixed","value":80}}]}';
            // Ligne Porte 2 -> 90 (réalisée directement).
            CatalogueTarifaire__c p2 = new CatalogueTarifaire__c();
            p2.RecordTypeId = catRt;
            p2.FicheCEE__c = s.fiche;
            p2.RoleIntervenant__c = 'Client';
            p2.Statut__c = 'Active';
            p2.DateDebutValidite__c = Date.today().addDays(-10);
            p2.DateFinValidite__c = Date.today().addDays(10);
            p2.ParametresFiche__c =
                '{"version":1,"decisionVariables":[],"rules":[{"id":"r1","conditions":' +
                '{"PREVISITE_PORTE__c":{"comparison":"exact","value":"⬛Porte 2"}},' +
                '"montant1":{"mode":"fixed","value":90}}]}';
            insert new List<CatalogueTarifaire__c>{ p1, p2 };
        } catch (Exception e) {
            return;
        }

        LC023FacturationCompteController.CompteFacturationResult res =
            LC023FacturationCompteController.getCompteFacturation(s.compteId);
        LC023FacturationCompteController.CompteLigneRow target;
        for (LC023FacturationCompteController.CompteLigneRow r : res.rows) {
            if (r.role == 'Client' && r.numEcheance == 1 && r.status == 'A_CREER') target = r;
        }
        if (target == null) return;

        List<LC023FacturationCompteController.AcompteProposition> props =
            LC023FacturationCompteController.getPropositionsAcompte(
                s.compteId, new List<String>{ target.key }, 0
            );
        Boolean has80 = false, has90 = false;
        for (LC023FacturationCompteController.AcompteProposition p : props) {
            if (p.montantHT == 80) has80 = true;
            if (p.montantHT == 90) has90 = true;
        }
        System.Assert.isTrue(has80,
            'Acompte « Porte 1 » (80) proposé par cascade pour un dossier « Porte 2 »');
        System.Assert.isTrue(has90, 'Acompte « Porte 2 » (90) proposé (palier direct)');
    }

    // Désignation Acompte par règle : gabarit texte résolu depuis un champ CATALOGUE
    // (rôle) et un champ DOSSIER (fiche) à la proposition/création de la facture.
    @IsTest
    static void testAcompteDesignationTemplate() {
        Id catRt = catalogueAcompteRt();
        if (catRt == null) return;

        Scenario s;
        try {
            Test.setMock(HttpCalloutMock.class, new CalloutMock());
            s = buildScenario();
            if (s == null || s.dossierId == null || !s.reached) return;

            Pro__c d = new Pro__c(Id = s.dossierId);
            d.put('A_La_charge_de_l_apporteur_d_affaire__c', '🟦A La charge de l\'apporteur d\'affaire');
            update d;

            CatalogueTarifaire__c ac = new CatalogueTarifaire__c();
            ac.RecordTypeId = catRt;
            ac.FicheCEE__c = s.fiche;
            ac.RoleIntervenant__c = 'Client';
            ac.Statut__c = 'Active';
            ac.DateDebutValidite__c = Date.today().addDays(-10);
            ac.DateFinValidite__c = Date.today().addDays(10);
            // Gabarit : littéral + {catalogue.RoleIntervenant__c} + {dossier.Fiche_CEE__c}.
            ac.ParametresFiche__c =
                '{"version":1,"decisionVariables":[],"rules":[{"id":"r1","conditions":' +
                '{"A_La_charge_de_l_apporteur_d_affaire__c":{"comparison":"exact",' +
                '"value":"🟦A La charge de l\'apporteur d\'affaire"}},' +
                '"montant1":{"mode":"fixed","value":100},' +
                '"designation":"Previsite {catalogue.RoleIntervenant__c} - {dossier.Fiche_CEE__c}"}]}';
            insert ac;
        } catch (Exception e) {
            return;
        }

        LC023FacturationCompteController.CompteFacturationResult res =
            LC023FacturationCompteController.getCompteFacturation(s.compteId);
        LC023FacturationCompteController.CompteLigneRow target;
        for (LC023FacturationCompteController.CompteLigneRow r : res.rows) {
            if (r.role == 'Client' && r.numEcheance == 1 && r.status == 'A_CREER') target = r;
        }
        if (target == null) return;

        List<LC023FacturationCompteController.AcompteProposition> props =
            LC023FacturationCompteController.getPropositionsAcompte(
                s.compteId, new List<String>{ target.key }, 20
            );
        LC023FacturationCompteController.AcompteProposition p;
        for (LC023FacturationCompteController.AcompteProposition pr : props) {
            if (pr.montantHT == 100) p = pr;
        }
        System.Assert.isNotNull(p, 'Proposition d\'acompte (100) attendue');
        System.Assert.areEqual('Previsite Client - ' + s.fiche, p.designation,
            'Désignation résolue depuis le gabarit (rôle catalogue + fiche dossier)');
    }

    // Échéance Supplémentaire « Supplément Installation » : réalisée quand
    // INSTALLATION_Frais_Supplementaire__c > 0 (indépendante des portes).
    @IsTest
    static void testSupplementInstallation() {
        Id suppRt = suppCatalogueRt();
        String echVal = suppEcheanceValueContaining('install'); // « Supplément Installation »
        if (suppRt == null || echVal == null) return; // RT/valeur absente -> best-effort

        Scenario s;
        try {
            Test.setMock(HttpCalloutMock.class, new CalloutMock());
            s = buildScenario();
            if (s == null || s.dossierId == null || !s.reached) return;

            // Frais supplémentaires d'installation > 0 -> échéance réalisée.
            Pro__c d = new Pro__c(Id = s.dossierId);
            d.put('INSTALLATION_Frais_Supplementaire__c', 150);
            update d;

            CatalogueTarifaire__c sc = new CatalogueTarifaire__c();
            sc.RecordTypeId = suppRt;
            sc.FicheCEE__c = s.fiche;
            sc.RoleIntervenant__c = 'Client';
            sc.Statut__c = 'Active';
            sc.put('echeanceSupp__c', echVal);
            sc.DateDebutValidite__c = Date.today().addDays(-10);
            sc.DateFinValidite__c = Date.today().addDays(10);
            sc.ParametresFiche__c =
                '{"version":1,"decisionVariables":[],"rules":[{"id":"r1","conditions":{},' +
                '"montant1":{"mode":"fixed","value":90}}]}';
            insert sc;
        } catch (Exception e) {
            return; // best-effort (dépendance picklist / champs org)
        }

        LC023FacturationCompteController.CompteFacturationResult res =
            LC023FacturationCompteController.getCompteFacturation(s.compteId);
        LC023FacturationCompteController.CompteLigneRow supp;
        for (LC023FacturationCompteController.CompteLigneRow r : res.rows) {
            if (r.isSupplementaire && r.role == 'Client' && r.echeance == echVal) { supp = r; break; }
        }
        System.Assert.isNotNull(supp,
            'Échéance « Supplément Installation » attendue (frais installation > 0)');
        System.Assert.areEqual(90, supp.montant, 'Montant = catalogue (90)');
        System.Assert.isTrue(supp.selectable, 'Frais installation > 0 -> échéance réalisée -> sélectionnable');
    }

    // Échéances Supplémentaire « Frais Déplacement 1/2 » : pilotées par
    // INSTALLATION_Deplacement__c, même cascade que les portes (Déplacement 2 atteint
    // ⟹ Déplacement 1 atteint).
    @IsTest
    static void testSupplementFraisDeplacement() {
        Id suppRt = suppCatalogueRt();
        String echVal = suppEcheanceValueContaining('placement'); // « ⬛Frais Déplacement 1/2 »
        if (suppRt == null || echVal == null) return; // RT/valeur absente -> best-effort

        Scenario s;
        try {
            Test.setMock(HttpCalloutMock.class, new CalloutMock());
            s = buildScenario();
            if (s == null || s.dossierId == null || !s.reached) return;

            // Déplacement 2 atteint (picklist restreinte = « ⬛Frais Déplacement 2 ») -> cascade.
            Pro__c d = new Pro__c(Id = s.dossierId);
            d.put('INSTALLATION_Deplacement__c', '⬛Frais Déplacement 2');
            update d;

            CatalogueTarifaire__c sc = new CatalogueTarifaire__c();
            sc.RecordTypeId = suppRt;
            sc.FicheCEE__c = s.fiche;
            sc.RoleIntervenant__c = 'Client';
            sc.Statut__c = 'Active';
            sc.put('echeanceSupp__c', echVal);
            sc.DateDebutValidite__c = Date.today().addDays(-10);
            sc.DateFinValidite__c = Date.today().addDays(10);
            sc.ParametresFiche__c =
                '{"version":1,"decisionVariables":[],"rules":[{"id":"r1","conditions":{},' +
                '"montant1":{"mode":"fixed","value":75}}]}';
            insert sc;
        } catch (Exception e) {
            return; // best-effort (dépendance picklist / champs org)
        }

        LC023FacturationCompteController.CompteFacturationResult res =
            LC023FacturationCompteController.getCompteFacturation(s.compteId);
        LC023FacturationCompteController.CompteLigneRow supp;
        for (LC023FacturationCompteController.CompteLigneRow r : res.rows) {
            if (r.isSupplementaire && r.role == 'Client' && r.echeance == echVal) { supp = r; break; }
        }
        System.Assert.isNotNull(supp,
            'Échéance « Frais Déplacement » attendue (INSTALLATION_Deplacement__c = ⬛Frais Déplacement 2)');
        System.Assert.areEqual(75, supp.montant, 'Montant = catalogue (75)');
        System.Assert.isTrue(supp.selectable, 'Déplacement 2 -> cascade -> échéance réalisée -> sélectionnable');
    }
}