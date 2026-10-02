/**
 * Tests du RETOUR de signature : webhook, traitement, déduplication, batch de
 * réconciliation.
 *
 * Le fil conducteur est l'idempotence. Yousign rejoue ses événements, et le batch
 * peut croiser un webhook en vol : le même événement traité deux fois ne doit
 * jamais produire deux fichiers signés ni deux bascules de statut.
 */
@isTest
private class YS_Retour_Test {

    private static final String DEMANDE_ID = 'sr_test_0001';
    private static final String SECRET     = 'secret-de-test-yousign';

    /* ════════════════════════════════════════════════════════════════════════
       JEU DE DONNÉES
       ════════════════════════════════════════════════════════════════════════ */

    /**
     * Les triggers Lead / Pro__c de l'org émettent des appels sortants : tout
     * DML doit être précédé d'un bouchon, sans quoi l'insertion échoue sur
     * « les méthodes de test ne prennent pas en charge les callouts ».
     */
    @testSetup
    static void jeuDeDonnees() {
        Test.setMock(HttpCalloutMock.class, new YS_TestMock());

        insert new Lead(
            FirstName = 'Jean',
            LastName  = 'Dupont',
            Company   = 'Foyer Dupont',
            Email     = 'jean.dupont@example.com',
            Surface_habitable__c = 95,
            YS_Demande_Id__c = DEMANDE_ID,
            YS_Statut__c     = 'Envoye',
            YS_Date_Envoi__c = Datetime.now()
        );
    }

    private static Lead laPiste() {
        return [
            SELECT Id, RES_Statut_Devis__c, YS_Statut__c, YS_Date_Signature__c, YS_Message_Erreur__c
            FROM Lead LIMIT 1
        ];
    }

    private static String payload(String evenement) {
        return JSON.serialize(new Map<String, Object>{
            'event_id'   => 'evt_0001',
            'event_name' => evenement,
            'event_time' => 1735689600,
            'sandbox'    => true,
            'data' => new Map<String, Object>{
                'signature_request' => new Map<String, Object>{
                    'id'     => DEMANDE_ID,
                    'status' => 'done'
                }
            }
        });
    }

    /* ════════════════════════════════════════════════════════════════════════
       WEBHOOK — vérification HMAC
       ════════════════════════════════════════════════════════════════════════ */

    private static void appeler(String corps, String signature) {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/yousign/webhook';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(corps);
        if (signature != null) {
            // Casse volontairement mélangée : Yousign documente l'en-tête comme
            // insensible à la casse, la lecture doit l'être aussi.
            req.addHeader('X-YouSign-Signature-256', signature);
        }
        RestContext.request  = req;
        RestContext.response = new RestResponse();
    }

    private static String signer(String corps) {
        Blob mac = Crypto.generateMac('hmacSHA256', Blob.valueOf(corps), Blob.valueOf(SECRET));
        return 'sha256=' + EncodingUtil.convertToHex(mac);
    }

    @isTest
    static void signatureValideEstAcceptee() {
        YS_WebhookRest.secretSurcharge = SECRET;
        String corps = payload('signature_request.done');

        Test.startTest();
        appeler(corps, signer(corps));
        YS_WebhookRest.recevoir();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode,
            'Un webhook correctement signé doit être acquitté.');
    }

    @isTest
    static void signatureInvalideEstRefusee() {
        YS_WebhookRest.secretSurcharge = SECRET;
        String corps = payload('signature_request.done');

        Test.startTest();
        appeler(corps, 'sha256=' + EncodingUtil.convertToHex(
            Crypto.generateMac('hmacSHA256', Blob.valueOf(corps), Blob.valueOf('mauvais-secret'))));
        YS_WebhookRest.recevoir();
        Test.stopTest();

        System.assertEquals(401, RestContext.response.statusCode,
            'Un corps signé avec un autre secret doit être rejeté.');
    }

    @isTest
    static void signatureAbsenteEstRefusee() {
        YS_WebhookRest.secretSurcharge = SECRET;

        Test.startTest();
        appeler(payload('signature_request.done'), null);
        YS_WebhookRest.recevoir();
        Test.stopTest();

        System.assertEquals(401, RestContext.response.statusCode);
    }

    /**
     * Le HMAC porte sur le corps BRUT. Un corps modifié d'un seul caractère, même
     * sémantiquement équivalent, doit invalider la signature — c'est tout l'objet
     * du contrôle.
     */
    @isTest
    static void corpsAltereInvalideLaSignature() {
        YS_WebhookRest.secretSurcharge = SECRET;
        String corps = payload('signature_request.done');
        String signature = signer(corps);

        Test.startTest();
        appeler(corps.replace(DEMANDE_ID, 'sr_pirate_9999'), signature);
        YS_WebhookRest.recevoir();
        Test.stopTest();

        System.assertEquals(401, RestContext.response.statusCode,
            'Un corps altéré ne doit pas passer, même avec une signature par ailleurs valide.');
    }

    @isTest
    static void corpsVideEstRefuse() {
        YS_WebhookRest.secretSurcharge = SECRET;

        Test.startTest();
        appeler('', null);
        YS_WebhookRest.recevoir();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode,
            'Un corps vide est refusé avant même le contrôle de signature.');
    }

    /** Un événement hors périmètre est acquitté : Yousign ne doit pas le rejouer. */
    @isTest
    static void evenementNonSuiviEstAcquitteSansTraitement() {
        YS_WebhookRest.secretSurcharge = SECRET;
        String corps = payload('signature_request.reminder_executed');

        Test.startTest();
        appeler(corps, signer(corps));
        YS_WebhookRest.recevoir();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        System.assertEquals(0, [SELECT COUNT() FROM YS_Evenement__c],
            'Aucun traitement ne devait être journalisé.');
    }

    /* ════════════════════════════════════════════════════════════════════════
       TRAITEMENT
       ════════════════════════════════════════════════════════════════════════ */

    @isTest
    static void signatureAboutieJointLeDocumentEtBasculeLeStatut() {
        YS_TestMock bouchon = new YS_TestMock();
        Test.setMock(HttpCalloutMock.class, bouchon);

        Test.startTest();
        Boolean fait = YS_TraitementSignature.appliquerSignature(DEMANDE_ID);
        Test.stopTest();

        System.assert(fait, 'Le traitement aurait dû s\'appliquer.');

        Lead piste = laPiste();
        System.assertEquals('Signe', piste.YS_Statut__c);
        System.assertNotEquals(null, piste.YS_Date_Signature__c,
            'La date de signature doit être horodatée.');
        System.assertEquals(
            LC021_DevisSignature.CODE_SIGNE,
            LC021_DevisSignature.codeStatutPublic(piste.RES_Statut_Devis__c),
            'Le statut métier du devis doit passer à « signé ».');

        List<ContentVersion> fichiers = [
            SELECT Title FROM ContentVersion WHERE Title = :YS_TraitementSignature.TITRE_SIGNE
        ];
        System.assertEquals(1, fichiers.size(),
            'Le devis signé doit être joint comme fichier séparé.');
    }

    /** Rejouer le même événement ne doit pas créer un second fichier. */
    @isTest
    static void rejeuNeDupliquePas() {
        Test.setMock(HttpCalloutMock.class, new YS_TestMock());

        Test.startTest();
        YS_TraitementSignature.appliquerSignature(DEMANDE_ID);
        Boolean second = YS_TraitementSignature.appliquerSignature(DEMANDE_ID);
        Test.stopTest();

        System.assert(!second, 'Le second passage doit être sans effet.');
        System.assertEquals(1,
            [SELECT COUNT() FROM ContentVersion WHERE Title = :YS_TraitementSignature.TITRE_SIGNE],
            'Un rejeu ne doit pas produire un second devis signé.');
    }

    @isTest
    static void demandeInconnueNeCassePas() {
        Test.setMock(HttpCalloutMock.class, new YS_TestMock());

        Test.startTest();
        Boolean fait = YS_TraitementSignature.appliquerSignature('sr_inexistante');
        Test.stopTest();

        System.assert(!fait, 'Une demande sans enregistrement porteur doit être ignorée en silence.');
    }

    /**
     * Un refus ne touche PAS au statut métier du devis : c'est au commercial de
     * décider de la suite, pas au webhook.
     */
    @isTest
    static void refusTraceSansToucherAuStatutMetier() {
        Test.setMock(HttpCalloutMock.class, new YS_TestMock());
        String statutAvant = laPiste().RES_Statut_Devis__c;

        Test.startTest();
        YS_TraitementSignature.appliquerEchec(DEMANDE_ID, 'Refuse', 'Le client a refusé.');
        Test.stopTest();

        Lead piste = laPiste();
        System.assertEquals('Refuse', piste.YS_Statut__c);
        System.assertEquals('Le client a refusé.', piste.YS_Message_Erreur__c);
        System.assertEquals(statutAvant, piste.RES_Statut_Devis__c,
            'Le statut métier du devis ne doit pas bouger sur un refus.');
    }

    /* ════════════════════════════════════════════════════════════════════════
       DÉDUPLICATION
       ════════════════════════════════════════════════════════════════════════ */

    /**
     * ⚠️ CE QUE CES TESTS NE PEUVENT PAS ATTRAPER
     *
     * Un appel sortant bouchonné par Test.setMock ne déclenche PAS la règle
     * « callout interdit après un DML » : la plateforme ne l'applique qu'aux
     * appels réels. Une première version de YS_TraiterWebhook journalisait
     * l'événement (INSERT) avant d'appeler Yousign ; tous les tests passaient au
     * vert, et en sandbox chaque webhook échouait sur
     * « You have uncommitted work pending ».
     *
     * D'où l'ordre imposé dans la classe — LECTURE, CALLOUT, ÉCRITURE — qu'aucun
     * test ici ne peut défendre. Il tient par la revue, pas par l'assertion.
     */
    @isTest
    static void memeEventIdNestTraiteQuUneFois() {
        Test.setMock(HttpCalloutMock.class, new YS_TestMock());
        String corps = payload('signature_request.done');

        Test.startTest();
        new YS_TraiterWebhook('evt_0001', 'signature_request.done', corps).execute(null);
        new YS_TraiterWebhook('evt_0001', 'signature_request.done', corps).execute(null);
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM YS_Evenement__c],
            'Le journal ne doit contenir qu\'une seule entrée pour un event_id donné.');
        System.assertEquals(1,
            [SELECT COUNT() FROM ContentVersion WHERE Title = :YS_TraitementSignature.TITRE_SIGNE],
            'Le second passage ne doit pas rejoindre le document.');
    }

    /**
     * Charge utile réelle d'un `signer.done`, relevée en sandbox : la demande y
     * porte déjà `status: done`, et le signataire est imbriqué à côté d'elle.
     */
    private static String payloadSignerDone(String statutDemande) {
        return JSON.serialize(new Map<String, Object>{
            'event_id'   => 'evt_signer_0001',
            'event_name' => 'signer.done',
            'event_time' => '1787768268',
            'sandbox'    => true,
            'data' => new Map<String, Object>{
                'signature_request' => new Map<String, Object>{
                    'id'     => DEMANDE_ID,
                    'status' => statutDemande,
                    'name'   => 'Devis CAE - Test1 Test1'
                },
                'signer' => new Map<String, Object>{
                    'id'     => 'f067e050-6dfa-41e8-8b7a-78e0bca93d21',
                    'status' => 'signed'
                }
            }
        });
    }

    /**
     * Le cas qui avait échappé à la première version : selon les événements
     * souscrits, une signature terminée n'arrive QUE sous le nom `signer.done`.
     * Le devis doit basculer quand même — c'est le statut de la demande qui
     * fait foi, pas le nom de l'événement.
     */
    @isTest
    static void signerDoneDeclencheLaSignature() {
        Test.setMock(HttpCalloutMock.class, new YS_TestMock());

        Test.startTest();
        new YS_TraiterWebhook('evt_signer_0001', 'signer.done',
            payloadSignerDone('done')).execute(null);
        Test.stopTest();

        Lead piste = laPiste();
        System.assertEquals('Signe', piste.YS_Statut__c,
            'Un signer.done sur une demande terminée doit signer le devis.');
        System.assertEquals(1,
            [SELECT COUNT() FROM ContentVersion WHERE Title = :YS_TraitementSignature.TITRE_SIGNE]);
    }

    /**
     * Garde-fou multi-signataire : avec plusieurs signataires, `signer.done`
     * part à chaque signature, mais la demande reste `ongoing` tant que tout le
     * monde n'a pas signé. Rien ne doit bouger dans ce cas.
     */
    @isTest
    static void signerDoneSurDemandeEnCoursNeSignePas() {
        Test.setMock(HttpCalloutMock.class, new YS_TestMock());

        Test.startTest();
        new YS_TraiterWebhook('evt_signer_0002', 'signer.done',
            payloadSignerDone('ongoing')).execute(null);
        Test.stopTest();

        System.assertEquals('Envoye', laPiste().YS_Statut__c,
            'Une demande encore en cours ne doit pas être considérée comme signée.');
        System.assertEquals(0,
            [SELECT COUNT() FROM ContentVersion WHERE Title = :YS_TraitementSignature.TITRE_SIGNE]);
    }

    /** Le webhook doit ACCEPTER signer.done, pas l'ignorer comme un bruit. */
    @isTest
    static void signerDoneEstAccepteParLeWebhook() {
        YS_WebhookRest.secretSurcharge = SECRET;
        String corps = payloadSignerDone('done');

        Test.startTest();
        appeler(corps, signer(corps));
        YS_WebhookRest.recevoir();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        System.assert(!RestContext.response.responseBody.toString().contains('ignoré'),
            'signer.done doit être traité, pas acquitté puis jeté.');
    }

    @isTest
    static void statutLuDansLePayload() {
        Map<String, Object> json =
            (Map<String, Object>) JSON.deserializeUntyped(payloadSignerDone('done'));

        Test.startTest();
        String statut = YS_TraiterWebhook.extraireStatut(json);
        Test.stopTest();

        System.assertEquals('done', statut);
    }

    @isTest
    static void identifiantDeDemandeLuDansLePayload() {
        Map<String, Object> json =
            (Map<String, Object>) JSON.deserializeUntyped(payload('signature_request.done'));

        Test.startTest();
        String trouve = YS_TraiterWebhook.extraireDemandeId(json);
        Test.stopTest();

        System.assertEquals(DEMANDE_ID, trouve);
    }

    /* ════════════════════════════════════════════════════════════════════════
       RÉCONCILIATION
       ════════════════════════════════════════════════════════════════════════ */

    /**
     * Le filet de sécurité : aucun webhook n'est arrivé, mais Yousign répond
     * « done » — le batch doit produire exactement le même résultat.
     */
    @isTest
    static void batchRattrapeUnWebhookPerdu() {
        YS_TestMock bouchon = new YS_TestMock();
        bouchon.statut = 'done';
        Test.setMock(HttpCalloutMock.class, bouchon);

        Test.startTest();
        Database.executeBatch(new YS_ReconciliationBatch('Lead'), 20);
        Test.stopTest();

        Lead piste = laPiste();
        System.assertEquals('Signe', piste.YS_Statut__c,
            'Le batch doit rattraper une signature dont le webhook s\'est perdu.');
        System.assertEquals(1,
            [SELECT COUNT() FROM ContentVersion WHERE Title = :YS_TraitementSignature.TITRE_SIGNE]);
    }

    /** Une demande encore en cours ne doit rien déclencher. */
    @isTest
    static void batchLaisseLesDemandesEnCours() {
        YS_TestMock bouchon = new YS_TestMock();
        bouchon.statut = 'ongoing';
        Test.setMock(HttpCalloutMock.class, bouchon);

        Test.startTest();
        Database.executeBatch(new YS_ReconciliationBatch('Lead'), 20);
        Test.stopTest();

        System.assertEquals('Envoye', laPiste().YS_Statut__c,
            'Une demande « ongoing » doit rester en l\'état.');
    }

    @isTest
    static void planificationDemarreLaPasseLead() {
        Test.setMock(HttpCalloutMock.class, new YS_TestMock());

        Test.startTest();
        System.schedule('YS test reconciliation', '0 0 3 * * ?', new YS_ReconciliationBatch());
        Test.stopTest();

        System.assertEquals(1,
            [SELECT COUNT() FROM CronTrigger WHERE CronJobDetail.Name = 'YS test reconciliation'],
            'La planification doit être enregistrée.');
    }
}