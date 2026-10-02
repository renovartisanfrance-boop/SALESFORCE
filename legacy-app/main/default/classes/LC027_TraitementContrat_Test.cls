/**
 * Tests de LC027_TraitementContrat — retour de signature sur la CAMPAGNE.
 *
 * Vérifie aussi le branchement dans YS_TraitementSignature : c'est la seule
 * classe existante que le portail modifie, et une régression y casserait le
 * flux devis en production.
 */
@isTest
private class LC027_TraitementContrat_Test {

    /** Renvoie un PDF quel que soit l'appel — c'est le téléchargement du signé. */
    private class MockPdfSigne implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/pdf');
            res.setBodyAsBlob(Blob.valueOf('%PDF-1.4 signe'));
            return res;
        }
    }

    private static Campaign avecDemande(String token, String statutContrat) {
        Campaign c = LC027_TestFactory.previsiteur(token, statutContrat, true);
        c.YS_Demande_Id__c = 'ys-demande-abc';
        update c;
        return c;
    }

    @isTest
    static void signatureAppliqueeJointLeDocumentEtBasculeLeStatut() {
        Campaign c = avecDemande('token-signature', 'Attente signature');
        Test.setMock(HttpCalloutMock.class, new MockPdfSigne());

        Test.startTest();
        Boolean fait = LC027_TraitementContrat.appliquerSignature(c.Id, 'ys-demande-abc');
        Test.stopTest();

        System.assertEquals(true, fait);
        Campaign apres = [SELECT StatutContrat__c, YS_Signe_Doc_Id__c, YS_Date_Signature__c,
                                 YS_Message_Erreur__c
                          FROM Campaign WHERE Id = :c.Id];
        System.assertEquals('Signe', apres.StatutContrat__c);
        System.assertNotEquals(null, apres.YS_Signe_Doc_Id__c,
            'Sans ce pointeur, le portail servirait le contrat vierge à la place du signé.');
        System.assertNotEquals(null, apres.YS_Date_Signature__c);
        System.assertEquals(null, apres.YS_Message_Erreur__c);

        System.assertEquals(1, [SELECT COUNT() FROM ContentVersion],
            'Le PDF signé doit être joint à la CAMPAGNE.');
    }

    /** Idempotence : Yousign rejoue ses événements, le batch peut croiser un webhook. */
    @isTest
    static void signatureDejaAppliqueeNeRefaitRien() {
        Campaign c = avecDemande('token-deja-signe', 'Signe');
        Test.setMock(HttpCalloutMock.class, new MockPdfSigne());

        Test.startTest();
        Boolean fait = LC027_TraitementContrat.appliquerSignature(c.Id, 'ys-demande-abc');
        Test.stopTest();

        System.assertEquals(false, fait, 'Un contrat déjà signé ne doit rien refaire.');
        System.assertEquals(0, [SELECT COUNT() FROM ContentVersion]);
    }

    @isTest
    static void campagneInexistanteNeLevePas() {
        Test.startTest();
        Boolean fait = LC027_TraitementContrat.appliquerSignature(
            '701000000000000AAA', 'ys-inconnu');
        Test.stopTest();
        System.assertEquals(false, fait);
    }

    /**
     * Refus ou expiration : le statut NE redescend PAS. Le pré-visiteur a saisi
     * ses informations, les lui redemander serait absurde.
     */
    @isTest
    static void echecTraceLeMotifSansToucherAuStatut() {
        Campaign c = avecDemande('token-refus', 'Attente signature');

        Test.startTest();
        Boolean fait = LC027_TraitementContrat.appliquerEchec(c.Id, 'Refuse', 'motif de test');
        Test.stopTest();

        System.assertEquals(true, fait);
        Campaign apres = [SELECT StatutContrat__c, YS_Message_Erreur__c
                          FROM Campaign WHERE Id = :c.Id];
        System.assertEquals('Attente signature', apres.StatutContrat__c,
            'Le contrat reste en attente : on ne redemande pas la saisie.');
        System.assert(apres.YS_Message_Erreur__c.contains('Refuse'), apres.YS_Message_Erreur__c);
    }

    /** Un refus arrivé après coup ne défait pas une signature déjà appliquée. */
    @isTest
    static void echecApresSignatureIgnore() {
        Campaign c = avecDemande('token-refus-tardif', 'Signe');

        Test.startTest();
        Boolean fait = LC027_TraitementContrat.appliquerEchec(c.Id, 'Expire', 'trop tard');
        Test.stopTest();

        System.assertEquals(false, fait);
        System.assertEquals('Signe',
            [SELECT StatutContrat__c FROM Campaign WHERE Id = :c.Id].StatutContrat__c);
    }

    @isTest
    static void erreurEnregistree() {
        Campaign c = avecDemande('token-erreur', 'Attente signature');

        Test.startTest();
        LC027_TraitementContrat.enregistrerErreur(c.Id, 'panne technique');
        Test.stopTest();

        System.assertEquals('panne technique',
            [SELECT YS_Message_Erreur__c FROM Campaign WHERE Id = :c.Id].YS_Message_Erreur__c);
    }

    /* ── Branchement dans YS_TraitementSignature ──────────────────────────── */

    /**
     * localiser() doit reconnaître la CAMPAGNE comme troisième objet porteur de
     * YS_Demande_Id__c, sans quoi le retour de signature n'atteindrait jamais
     * le portail Prévisites.
     */
    @isTest
    static void localiserReconnaitLaCampagne() {
        Campaign c = avecDemande('token-localiser', 'Attente signature');

        Test.startTest();
        YS_TraitementSignature.Cible cible =
            YS_TraitementSignature.localiser('ys-demande-abc');
        Test.stopTest();

        System.assertNotEquals(null, cible, 'La campagne doit être localisée.');
        System.assertEquals('Campaign', cible.sobjectType);
        System.assertEquals(c.Id, cible.recordId);
    }

    @isTest
    static void localiserRendNullSurDemandeInconnue() {
        System.assertEquals(null, YS_TraitementSignature.localiser('rien-du-tout'));
        System.assertEquals(null, YS_TraitementSignature.localiser(null));
    }

    /**
     * La délégation doit intervenir AVANT le code propre au devis : sans elle,
     * appliquerSignature appellerait LC021_DevisSignature.champStatut('Campaign'),
     * qui ne connaît que Lead et Pro__c.
     */
    @isTest
    static void ysTraitementDelegueALaCampagne() {
        Campaign c = avecDemande('token-delegation', 'Attente signature');
        Test.setMock(HttpCalloutMock.class, new MockPdfSigne());

        Test.startTest();
        Boolean fait = YS_TraitementSignature.appliquerSignature('ys-demande-abc');
        Test.stopTest();

        System.assertEquals(true, fait);
        System.assertEquals('Signe',
            [SELECT StatutContrat__c FROM Campaign WHERE Id = :c.Id].StatutContrat__c);
    }

    @isTest
    static void ysTraitementDelegueLEchecEtLErreur() {
        Campaign c = avecDemande('token-delegation-echec', 'Attente signature');

        Test.startTest();
        YS_TraitementSignature.appliquerEchec('ys-demande-abc', 'Refuse', 'motif');
        YS_TraitementSignature.enregistrerErreur('ys-demande-abc', 'trace');
        Test.stopTest();

        System.assertEquals('trace',
            [SELECT YS_Message_Erreur__c FROM Campaign WHERE Id = :c.Id].YS_Message_Erreur__c);
    }
}