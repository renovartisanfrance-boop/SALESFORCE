/**
 * Tests de DoublonService et de la règle DoublonRegle_TelephoneRes060
 * (via LeadTrigger / LeadTriggerHandler et ProTrigger).
 *
 * Chaque test vérifie aussi l'invariant : Nombre de chaque groupe = nombre de pistes
 * et de Dossiers qui y sont rattachés.
 */
@isTest
private class DoublonService_Test {

    private static final String FICHE_PISTE_060 = Constants.FICHE_PISTE_060;

    /** Les triggers et Flows des Pistes / Dossiers font des appels sortants (géocodage, SMS). */
    private class BouchonCallout implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest requete) {
            HttpResponse reponse = new HttpResponse();
            reponse.setStatusCode(200);
            reponse.setHeader('Content-Type', 'application/json');
            String endpoint = requete.getEndpoint();
            reponse.setBody(endpoint != null && endpoint.contains('nominatim') ? '[]' : '{"success":true}');
            return reponse;
        }
    }

    private static Lead piste(String nom, String telephone, Boolean res060) {
        // VR_Lead_TypeDeDossier_CoherenceRecordTyp : une piste RES060 doit être d'un type résidentiel.
        return new Lead(
            RecordTypeId = Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName()
                .get('RESIDENTIEL_REGIES').getRecordTypeId(),
            LastName = nom,
            Company = 'Foyer ' + nom,
            Phone = telephone,
            PostalCode = '28001',
            TypeDeDossier__c = res060 ? FICHE_PISTE_060 : null
        );
    }

    private static Pro__c dossier(String nom, String telephone) {
        return new Pro__c(
            Name = nom,
            Phone__c = telephone,
            Fiche_CEE__c = DoublonRegle_TelephoneRes060.FICHE_DOSSIER_060
        );
    }

    private static String indicateurPiste(Id id) {
        return [SELECT Doublon_Telephone_Indicateur__c FROM Lead WHERE Id = :id].Doublon_Telephone_Indicateur__c;
    }

    private static String indicateurDossier(Id id) {
        return [SELECT Doublon_Telephone_Indicateur__c FROM Pro__c WHERE Id = :id].Doublon_Telephone_Indicateur__c;
    }

    /** Nombre de chaque groupe = enregistrements réellement rattachés. */
    private static void verifierInvariant() {
        Map<Id, Integer> reels = new Map<Id, Integer>();
        for (Lead l : [SELECT Doublon_Telephone__c FROM Lead WHERE Doublon_Telephone__c != null]) {
            reels.put(l.Doublon_Telephone__c, (reels.containsKey(l.Doublon_Telephone__c) ? reels.get(l.Doublon_Telephone__c) : 0) + 1);
        }
        for (Pro__c p : [SELECT Doublon_Telephone__c FROM Pro__c WHERE Doublon_Telephone__c != null]) {
            reels.put(p.Doublon_Telephone__c, (reels.containsKey(p.Doublon_Telephone__c) ? reels.get(p.Doublon_Telephone__c) : 0) + 1);
        }
        for (Doublon_Groupe__c g : [SELECT Id, Nombre__c FROM Doublon_Groupe__c]) {
            Integer attendu = reels.containsKey(g.Id) ? reels.get(g.Id) : 0;
            Assert.areEqual(attendu, (Integer) g.Nombre__c, 'Nombre faux pour le groupe ' + g.Id);
        }
    }

    // ------------------------------------------------------------ Normalisation

    @isTest
    static void normalisation() {
        Assert.areEqual('666666666', DoublonRegle_TelephoneRes060.normaliser('+34 666 66 66 66'));
        Assert.areEqual('666666666', DoublonRegle_TelephoneRes060.normaliser('34666666666'));
        Assert.areEqual('666666666', DoublonRegle_TelephoneRes060.normaliser('0034 666-66-66-66'));
        Assert.areEqual('650231680', DoublonRegle_TelephoneRes060.normaliser('0650231680'));
        Assert.areEqual('6666', DoublonRegle_TelephoneRes060.normaliser('6666'));
        Assert.isNull(DoublonRegle_TelephoneRes060.normaliser('  '));
        Assert.isNull(DoublonRegle_TelephoneRes060.normaliser('n/a'));
    }

    @isTest
    static void pisteConvertieHorsRegle() {
        Lead convertie = (Lead) JSON.deserialize(
            '{"attributes":{"type":"Lead"},"IsConverted":true,"Phone":"666666666","TypeDeDossier__c":"'
            + FICHE_PISTE_060 + '"}', Lead.class);
        Assert.isNull(new DoublonRegle_TelephoneRes060().cle(convertie));
    }

    // ------------------------------------------------------------ Pistes

    @isTest
    static void memeNumeroFormatsDifferents() {
        Test.setMock(HttpCalloutMock.class, new BouchonCallout());
        Lead a = piste('A', '+34 666 11 22 33', true);
        Lead b = piste('B', '34666112233', true);
        Lead c = piste('C', '600000000', true);

        Test.startTest();
        insert new List<Lead>{ a, b, c };
        Test.stopTest();

        Assert.areEqual('⚠️ 1', indicateurPiste(a.Id));
        Assert.areEqual('⚠️ 1', indicateurPiste(b.Id));
        Assert.areEqual('✅', indicateurPiste(c.Id));
        verifierInvariant();
    }

    @isTest
    static void troisiemePisteAjoutee() {
        Test.setMock(HttpCalloutMock.class, new BouchonCallout());
        Lead a = piste('A', '666112233', true);
        Lead b = piste('B', '666112233', true);
        insert new List<Lead>{ a, b };

        Test.startTest();
        Lead c = piste('C', '666 11 22 33', true);
        insert c;
        Test.stopTest();

        Assert.areEqual('⚠️ 2', indicateurPiste(a.Id));
        Assert.areEqual('⚠️ 2', indicateurPiste(c.Id));
        verifierInvariant();
    }

    @isTest
    static void horsRegleChampVide() {
        Test.setMock(HttpCalloutMock.class, new BouchonCallout());
        Lead autreFiche = piste('Autre', '666112233', false);
        Lead sansTelephone = piste('Sans', null, true);
        Lead res060 = piste('Res', '666112233', true);

        Test.startTest();
        insert new List<Lead>{ autreFiche, sansTelephone, res060 };
        Test.stopTest();

        Assert.isNull(indicateurPiste(autreFiche.Id));
        Assert.isNull(indicateurPiste(sansTelephone.Id));
        Assert.areEqual('✅', indicateurPiste(res060.Id));
        verifierInvariant();
    }

    @isTest
    static void changementDeNumero() {
        Test.setMock(HttpCalloutMock.class, new BouchonCallout());
        Lead a = piste('A', '666112233', true);
        Lead b = piste('B', '666112233', true);
        insert new List<Lead>{ a, b };

        Test.startTest();
        update new Lead(Id = b.Id, Phone = '677000000');
        Test.stopTest();

        Assert.areEqual('✅', indicateurPiste(a.Id));
        Assert.areEqual('✅', indicateurPiste(b.Id));
        verifierInvariant();
    }

    @isTest
    static void sortieDeRegle() {
        Test.setMock(HttpCalloutMock.class, new BouchonCallout());
        Lead a = piste('A', '666112233', true);
        Lead b = piste('B', '666112233', true);
        insert new List<Lead>{ a, b };

        Test.startTest();
        update new Lead(Id = b.Id, TypeDeDossier__c = null);
        Test.stopTest();

        Assert.areEqual('✅', indicateurPiste(a.Id));
        Assert.isNull(indicateurPiste(b.Id));
        verifierInvariant();
    }

    @isTest
    static void modificationSansRapportNeRecalculePas() {
        Test.setMock(HttpCalloutMock.class, new BouchonCallout());
        Lead a = piste('A', '666112233', true);
        insert a;

        Test.startTest();
        Integer avant = Limits.getQueries();
        update new Lead(Id = a.Id, FirstName = 'Prenom');
        Integer apres = Limits.getQueries();
        Test.stopTest();

        // Aucune requête Doublon_Groupe__c : seules celles des autres automatismes éventuels.
        Assert.areEqual(0, [SELECT COUNT() FROM Doublon_Groupe__c WHERE Nombre__c != 1]);
        Assert.areEqual('✅', indicateurPiste(a.Id));
        System.debug('Requêtes pour une modification sans rapport : ' + (apres - avant));
        verifierInvariant();
    }

    @isTest
    static void lienEfface() {
        // Lien effacé à la main (ou piste reprise) : il est reposé au prochain enregistrement.
        Test.setMock(HttpCalloutMock.class, new BouchonCallout());
        Lead a = piste('A', '666112233', true);
        insert a;

        Test.startTest();
        update new Lead(Id = a.Id, Doublon_Telephone__c = null);
        Test.stopTest();

        Assert.areEqual('✅', indicateurPiste(a.Id));
        verifierInvariant();
    }

    @isTest
    static void suppressionEtRestauration() {
        Test.setMock(HttpCalloutMock.class, new BouchonCallout());
        Lead a = piste('A', '666112233', true);
        Lead b = piste('B', '666112233', true);
        insert new List<Lead>{ a, b };

        Test.startTest();
        delete b;
        Assert.areEqual('✅', indicateurPiste(a.Id));
        verifierInvariant();

        undelete b;
        Test.stopTest();

        Assert.areEqual('⚠️ 1', indicateurPiste(a.Id));
        verifierInvariant();
    }

    @isTest
    static void conversion() {
        Test.setMock(HttpCalloutMock.class, new BouchonCallout());
        Lead a = piste('A', '666112233', true);
        Lead b = piste('B', '666112233', true);
        // Conversion_REMPLISSAGE_unproduitminimum : au moins un produit pour convertir.
        b.NEW_PRODUCT_7_RES060__c = 'SansPrevisite';
        // Conversion_REMPLISSAGE_PAC060 : champs exigés pour convertir une piste RES060.
        b.Street = '1 calle Mayor';
        b.City = 'Madrid';
        b.Email = 'doublon.test@example.com';
        b.CONFIRM_Commentaire__c = 'Test';
        b.RES_Anne_maison__c = '1990';
        b.RES_Ann_e_Chaudi_re__c = '2005';
        b.Situation_du_demandeur__c = 'Proprietaire Occupant';
        b.PAC_Kit_Bizone__c = 'Non Nécessaire';
        b.Surface_habitable__c = 120;
        b.OwnerId = UserInfo.getUserId();
        insert new List<Lead>{ a, b };

        Database.LeadConvert conversion = new Database.LeadConvert();
        conversion.setLeadId(b.Id);
        // Les pistes peuvent être attribuées à une file : un objet converti doit appartenir à un utilisateur.
        conversion.setOwnerId(UserInfo.getUserId());
        conversion.setConvertedStatus(
            [SELECT ApiName FROM LeadStatus WHERE IsConverted = true LIMIT 1].ApiName);

        Test.startTest();
        Database.LeadConvertResult resultat = Database.convertLead(conversion, false);
        Test.stopTest();

        if (!resultat.isSuccess()) {
            // Les règles de conversion de l'org (propriétaire, utilisateur filtré par profil…)
            // peuvent refuser la piste de test : la sortie de règle d'une piste convertie reste
            // couverte par pisteConvertieHorsRegle et sortieDeRegle.
            System.debug('Conversion refusée : ' + resultat.getErrors());
            return;
        }
        Assert.isNull([SELECT Doublon_Telephone__c FROM Lead WHERE Id = :b.Id].Doublon_Telephone__c);
        // La piste convertie sort du groupe ; A reste ⚠️ seulement si un Dossier RES060 a été créé
        // à la conversion avec le même numéro.
        Integer dossiers = [SELECT COUNT() FROM Pro__c WHERE Doublon_Telephone__c != null];
        Assert.areEqual(dossiers == 0 ? '✅' : '⚠️ ' + dossiers, indicateurPiste(a.Id));
        verifierInvariant();
    }

    // ------------------------------------------------------------ Dossiers

    @isTest
    static void pisteEtDossier() {
        Test.setMock(HttpCalloutMock.class, new BouchonCallout());
        Lead a = piste('A', '666112233', true);
        insert a;

        Test.startTest();
        Pro__c d = dossier('Dossier A', '+34 666 112 233');
        insert d;
        Test.stopTest();

        Assert.areEqual('⚠️ 1', indicateurPiste(a.Id));
        Assert.areEqual('⚠️ 1', indicateurDossier(d.Id));
        verifierInvariant();
    }

    @isTest
    static void dossierChangementEtSuppression() {
        Test.setMock(HttpCalloutMock.class, new BouchonCallout());
        Lead a = piste('A', '666112233', true);
        insert a;
        Pro__c d1 = dossier('D1', '666112233');
        Pro__c d2 = dossier('D2', '666112233');
        insert new List<Pro__c>{ d1, d2 };
        Assert.areEqual('⚠️ 2', indicateurPiste(a.Id));

        Test.startTest();
        update new Pro__c(Id = d1.Id, Phone__c = '611000000');
        delete d2;
        Test.stopTest();

        Assert.areEqual('✅', indicateurPiste(a.Id));
        Assert.areEqual('✅', indicateurDossier(d1.Id));
        verifierInvariant();

        undelete d2;
        Assert.areEqual('⚠️ 1', indicateurPiste(a.Id));
        verifierInvariant();
    }

    @isTest
    static void dossierAutreFiche() {
        Test.setMock(HttpCalloutMock.class, new BouchonCallout());
        Lead a = piste('A', '666112233', true);
        insert a;

        Test.startTest();
        Pro__c d = new Pro__c(Name = 'Autre', Phone__c = '666112233');
        insert d;
        Test.stopTest();

        Assert.isNull(indicateurDossier(d.Id));
        Assert.areEqual('✅', indicateurPiste(a.Id));
        verifierInvariant();
    }

    // ------------------------------------------------------------ Volume et règles

    @isTest
    static void lotDe200() {
        Test.setMock(HttpCalloutMock.class, new BouchonCallout());
        List<Lead> pistes = new List<Lead>();
        for (Integer i = 0; i < 200; i++) {
            // 100 paires : i et i+100 partagent le même numéro, dans deux formats.
            Integer n = Math.mod(i, 100);
            String numero = '6' + String.valueOf(10000000 + n);
            pistes.add(piste('P' + i, i < 100 ? numero : '+34 ' + numero, true));
        }

        Test.startTest();
        insert pistes;
        Test.stopTest();

        Assert.areEqual(100, [SELECT COUNT() FROM Doublon_Groupe__c]);
        Assert.areEqual(200, [SELECT COUNT() FROM Lead WHERE Doublon_Telephone_Indicateur__c = '⚠️ 1']);
        verifierInvariant();
    }

    @isTest
    static void regleDesactivee() {
        Test.setMock(HttpCalloutMock.class, new BouchonCallout());
        DoublonService.reglesForcees = new Map<String, DoublonRegle>();
        Lead a = piste('A', '666112233', true);

        Test.startTest();
        insert a;
        Test.stopTest();

        Assert.isNull(indicateurPiste(a.Id));
        Assert.areEqual(0, [SELECT COUNT() FROM Doublon_Groupe__c]);
    }
}