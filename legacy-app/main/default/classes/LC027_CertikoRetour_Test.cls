/**
 * LC027_CertikoRetour_Test — webhook que Certiko appelle à chaque changement
 * de colonne.
 *
 * CE QUI COMPTE ICI — un webhook n'a personne en face pour corriger le tir :
 *   • il reçoit un TABLEAU d'événements, dans le format exact de Certiko ;
 *   • il répond 200 dès que le corps est compris, MÊME si le dossier est
 *     inconnu — un non-2xx déclencherait des rejeux sans fin pour un dossier
 *     qui n'apparaîtra jamais ;
 *   • il n'écrit que ce qu'il sait écrire : colonnes suivies, valeurs de la
 *     liste de sélection, et seulement si quelque chose change vraiment.
 *
 * Le corps d'exemple est celui relevé le 2026-09-23 sur un vrai envoi.
 */
@isTest
private class LC027_CertikoRetour_Test {

    private static final String ID_CERTIKO = '1c2506e0-301e-4f30-976c-881b7d3e315d';
    private static final String REFERENCE  = '1985697503';

    /* ════════════════════════════ Jeu de données ════════════════════════════ */

    private static Pro__c dossier() {
        Pro__c p = new Pro__c(
            Name = 'TEST 2 SAMAD',
            Client_Adresse_Chantier__c = '55 RTE DE NOALHAT,,63290,PASLIERES',
            CodePostal__c = '63290',
            Phone__c = '612345678',
            CERTIKO_Dossier_Id__c = ID_CERTIKO,
            CERTIKO_Reference__c = REFERENCE,
            CERTIKO_Statut_VT__c = 'en_cours'
        );
        insert p;
        return p;
    }

    /** Le corps exact d'un webhook Certiko, un seul changement. */
    private static String corpsWebhook(String nouvelleValeur) {
        return '[{'
            + '"event":"dossier.field_changed",'
            + '"delivery_id":"d_b01c07ac744a4ed0aff5ad5ccf3f3fa6",'
            + '"occurred_at":"2026-09-23T13:03:10.501807+00:00",'
            + '"attempt":1,"source":"user",'
            + '"installateur_id":"bd304e35-ed4a-4154-bb13-2cc1ad293fb1",'
            + '"automation":{"id":"641b9029-707b-4788-a314-43394009b23d",'
            + '"name":"Status VT = Terminee"},'
            + '"change":{"column":{"id":"1ee44c00-13f5-44fd-9e2f-a9da3f60b4d4",'
            + '"name":"Status VT","slug":"status_vt"},'
            + '"new_value":"' + nouvelleValeur + '","old_value":"en_cours"},'
            + '"dossier":{"id":"' + ID_CERTIKO + '",'
            + '"board":{"slug":"gestion-install-res060"},'
            + '"status":{"slug":"nouveaux_clients","name":"Nouveaux Clients"},'
            + '"values":{"status_vt":"' + nouvelleValeur + '"},'
            + '"reference":"' + REFERENCE + '","client_name":"TEST 2 SAMAD"}'
            + '}]';
    }

    private static void appeler(String corps) {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/WHCertikoChangeColumn';
        req.httpMethod = 'POST';
        if (corps != null) {
            req.requestBody = Blob.valueOf(corps);
        }
        RestContext.request = req;
        RestContext.response = new RestResponse();
    }

    private static Map<String, Object> reponse() {
        return (Map<String, Object>) JSON.deserializeUntyped(
            RestContext.response.responseBody.toString());
    }

    /** Compte rendu du premier événement du tableau. */
    private static Map<String, Object> premier() {
        List<Object> resultats = (List<Object>) reponse().get('resultats');
        return (Map<String, Object>) resultats[0];
    }

    private static String statutDe(Id dossierId) {
        return [SELECT CERTIKO_Statut_VT__c FROM Pro__c WHERE Id = :dossierId].CERTIKO_Statut_VT__c;
    }

    /* ════════════════════════════ Le cas nominal ════════════════════════════ */

    @isTest
    static void leWebhookEcritLeNouveauStatut() {
        LC027_TestFactory.bouchonnerCallouts();
        Pro__c p = dossier();
        appeler(corpsWebhook('terminee'));

        Test.startTest();
        LC027_CertikoRetour.recevoirPost();
        Test.stopTest();

        Assert.areEqual(200, RestContext.response.statusCode);
        Assert.areEqual(true, reponse().get('ok'));
        Assert.areEqual(1, reponse().get('traites'));
        Assert.areEqual('applique', premier().get('etat'));
        Assert.areEqual(REFERENCE, premier().get('reference'));
        Assert.areEqual('terminee', statutDe(p.Id));
        Assert.isNotNull([SELECT CERTIKO_Statut_Maj__c FROM Pro__c WHERE Id = :p.Id]
            .CERTIKO_Statut_Maj__c);
    }

    /** PATCH mène au même traitement que POST. */
    @isTest
    static void patchEstAcceptee() {
        LC027_TestFactory.bouchonnerCallouts();
        Pro__c p = dossier();
        appeler(corpsWebhook('planifie'));

        Test.startTest();
        LC027_CertikoRetour.recevoirPatch();
        Test.stopTest();

        Assert.areEqual(200, RestContext.response.statusCode);
        Assert.areEqual('planifie', statutDe(p.Id));
    }

    /**
     * Plusieurs événements dans un même envoi : chacun a son compte rendu.
     * Certiko groupe ses livraisons, un tableau d'un seul élément n'est pas
     * une garantie.
     */
    @isTest
    static void plusieursEvenementsDansUnMemeEnvoi() {
        LC027_TestFactory.bouchonnerCallouts();
        Pro__c p = dossier();
        String un = corpsWebhook('terminee').removeStart('[').removeEnd(']');
        appeler('[' + un + ',' + un + ']');

        Test.startTest();
        LC027_CertikoRetour.recevoirPost();
        Test.stopTest();

        Assert.areEqual(2, reponse().get('traites'));
        List<Object> resultats = (List<Object>) reponse().get('resultats');
        Assert.areEqual('applique', ((Map<String, Object>) resultats[0]).get('etat'));
        // Le second ne change plus rien : le premier a déjà posé la valeur.
        Assert.areEqual('inchange', ((Map<String, Object>) resultats[1]).get('etat'));
        Assert.areEqual('terminee', statutDe(p.Id));
    }

    /**
     * `dossier.values` fait foi : il porte l'état complet après changement.
     * Ici `change.new_value` dit autre chose — c'est `values` qui doit gagner,
     * sinon un événement perdu plus tôt ne serait jamais rattrapé.
     */
    @isTest
    static void etatCompletDuDossierLEmporteSurLeSeulChangement() {
        LC027_TestFactory.bouchonnerCallouts();
        Pro__c p = dossier();
        appeler('[{"change":{"column":{"slug":"status_vt"},"new_value":"planifie"},'
            + '"dossier":{"id":"' + ID_CERTIKO + '","reference":"' + REFERENCE + '",'
            + '"values":{"status_vt":"terminee"}}}]');

        Test.startTest();
        LC027_CertikoRetour.recevoirPost();
        Test.stopTest();

        Assert.areEqual('terminee', statutDe(p.Id));
    }

    /** Sans `values`, on se rabat sur la colonne qui a bougé. */
    @isTest
    static void repliSurLaColonneQuiABouge() {
        LC027_TestFactory.bouchonnerCallouts();
        Pro__c p = dossier();
        appeler('[{"change":{"column":{"slug":"status_vt"},"new_value":"terminee"},'
            + '"dossier":{"id":"' + ID_CERTIKO + '","reference":"' + REFERENCE + '"}}]');

        Test.startTest();
        LC027_CertikoRetour.recevoirPost();
        Test.stopTest();

        Assert.areEqual('terminee', statutDe(p.Id));
    }

    /** La référence suffit quand l'identifiant Certiko manque. */
    @isTest
    static void referenceSeuleDesigneLeDossier() {
        LC027_TestFactory.bouchonnerCallouts();
        Pro__c p = dossier();
        appeler('[{"dossier":{"reference":"' + REFERENCE + '",'
            + '"values":{"status_vt":"terminee"}}}]');

        Test.startTest();
        LC027_CertikoRetour.recevoirPost();
        Test.stopTest();

        Assert.areEqual('terminee', statutDe(p.Id));
    }

    /* ════════════════════════ Ce qui ne passe pas ════════════════════════ */

    /**
     * DOSSIER INCONNU — 200 quand même. Un non-2xx ferait rejouer Certiko en
     * boucle pour un dossier qui n'existera pas davantage au prochain essai.
     */
    @isTest
    static void dossierInconnuRepond200SansRienCreer() {
        LC027_TestFactory.bouchonnerCallouts();
        dossier();
        Integer avant = [SELECT COUNT() FROM Pro__c];
        appeler('[{"dossier":{"id":"inconnu-chez-nous","reference":"0000000000",'
            + '"values":{"status_vt":"terminee"}}}]');

        Test.startTest();
        LC027_CertikoRetour.recevoirPost();
        Test.stopTest();

        Assert.areEqual(200, RestContext.response.statusCode,
            'Un rejeu ne ferait pas apparaitre le dossier.');
        Assert.areEqual('dossier_inconnu', premier().get('etat'));
        Assert.areEqual(avant, [SELECT COUNT() FROM Pro__c]);
    }

    @isTest
    static void cleEnDoubleEstSignalee() {
        LC027_TestFactory.bouchonnerCallouts();
        dossier();
        dossier();
        appeler(corpsWebhook('terminee'));

        Test.startTest();
        LC027_CertikoRetour.recevoirPost();
        Test.stopTest();

        Assert.areEqual(200, RestContext.response.statusCode);
        Assert.areEqual('cle_en_double', premier().get('etat'));
    }

    /**
     * VALEUR HORS LISTE — le dossier garde son statut, et la réponse dit
     * lequel a été refusé avec les valeurs attendues.
     */
    @isTest
    static void valeurHorsListeNEcritRienEtLeDit() {
        LC027_TestFactory.bouchonnerCallouts();
        Pro__c p = dossier();
        appeler(corpsWebhook('statut_de_demain'));

        Test.startTest();
        LC027_CertikoRetour.recevoirPost();
        Test.stopTest();

        Assert.areEqual(200, RestContext.response.statusCode);
        Assert.areEqual('valeur_refusee', premier().get('etat'));
        Assert.areEqual('en_cours', statutDe(p.Id), 'Le statut precedent tient.');
        List<Object> refusees = (List<Object>) premier().get('colonnes_refusees');
        Map<String, Object> refus = (Map<String, Object>) refusees[0];
        Assert.areEqual('status_vt', refus.get('colonne'));
        Assert.areEqual('statut_de_demain', refus.get('valeur'));
        Assert.isNotNull(refus.get('valeurs_attendues'));
    }

    /** Statut identique : rien n'est écrit, les automatismes ne partent pas. */
    @isTest
    static void statutIdentiqueNEcritRien() {
        LC027_TestFactory.bouchonnerCallouts();
        Pro__c p = dossier();
        Datetime avant = [SELECT LastModifiedDate FROM Pro__c WHERE Id = :p.Id].LastModifiedDate;
        appeler(corpsWebhook('en_cours'));

        Test.startTest();
        LC027_CertikoRetour.recevoirPost();
        Test.stopTest();

        Assert.areEqual('inchange', premier().get('etat'));
        Assert.areEqual(avant,
            [SELECT LastModifiedDate FROM Pro__c WHERE Id = :p.Id].LastModifiedDate);
    }

    /**
     * Certiko nous pousse TOUS les changements du tableau. Une colonne qui ne
     * nous concerne pas est ignorée sans bruit — ce n'est pas une anomalie.
     */
    @isTest
    static void colonneQuiNeNousConcernePasEstIgnoree() {
        LC027_TestFactory.bouchonnerCallouts();
        Pro__c p = dossier();
        appeler('[{"change":{"column":{"slug":"motif_refus"},"new_value":"doublon"},'
            + '"dossier":{"id":"' + ID_CERTIKO + '","reference":"' + REFERENCE + '",'
            + '"values":{"motif_refus":"doublon"}}}]');

        Test.startTest();
        LC027_CertikoRetour.recevoirPost();
        Test.stopTest();

        Assert.areEqual(200, RestContext.response.statusCode);
        Assert.areEqual('inchange', premier().get('etat'));
        Assert.areEqual('en_cours', statutDe(p.Id));
    }

    /** Une valeur vide n'efface rien : le tableau pousse aussi ses colonnes vides. */
    @isTest
    static void valeurVideNEffaceRien() {
        LC027_TestFactory.bouchonnerCallouts();
        Pro__c p = dossier();
        appeler('[{"dossier":{"id":"' + ID_CERTIKO + '","values":{"status_vt":""}}}]');

        Test.startTest();
        LC027_CertikoRetour.recevoirPost();
        Test.stopTest();

        Assert.areEqual('en_cours', statutDe(p.Id));
    }

    @isTest
    static void sansIdentifiantLEvenementEstSignale() {
        LC027_TestFactory.bouchonnerCallouts();
        dossier();
        appeler('[{"dossier":{"values":{"status_vt":"terminee"}}}]');

        Test.startTest();
        LC027_CertikoRetour.recevoirPost();
        Test.stopTest();

        Assert.areEqual('sans_identifiant', premier().get('etat'));
    }

    @isTest
    static void corpsVideEstRefuse() {
        LC027_TestFactory.bouchonnerCallouts();
        appeler(null);

        Test.startTest();
        LC027_CertikoRetour.recevoirPost();
        Test.stopTest();

        Assert.areEqual(400, RestContext.response.statusCode);
    }

    @isTest
    static void jsonIllisibleEstRefuse() {
        LC027_TestFactory.bouchonnerCallouts();
        appeler('pas du json');

        Test.startTest();
        LC027_CertikoRetour.recevoirPost();
        Test.stopTest();

        Assert.areEqual(400, RestContext.response.statusCode);
        Assert.areEqual('JSON invalide.', reponse().get('error'));
    }

    @isTest
    static void tableauVideEstRefuse() {
        LC027_TestFactory.bouchonnerCallouts();
        appeler('[]');

        Test.startTest();
        LC027_CertikoRetour.recevoirPost();
        Test.stopTest();

        Assert.areEqual(400, RestContext.response.statusCode);
    }

    /* ════════════════════════════ Fin de visite ════════════════════════════ */

    /**
     * La valeur qui marque la fin est un RÉGLAGE (label CERTIKO_STATUT_FIN_VT),
     * pas une constante : Certiko peut renommer son statut terminal.
     */
    @isTest
    static void finDeVisiteSuitLeReglage() {
        Test.startTest();
        Boolean fin = LC027_CertikoRetour.finDeVisite(System.Label.CERTIKO_STATUT_FIN_VT);
        Boolean pasFin = LC027_CertikoRetour.finDeVisite('en_cours');
        Boolean vide = LC027_CertikoRetour.finDeVisite(null);
        Test.stopTest();

        Assert.isTrue(fin, 'Le statut du label termine la visite.');
        Assert.isFalse(pasFin);
        Assert.isFalse(vide);
    }

    /**
     * Fin de visite : le compte rendu annonce le nettoyage de la colonne chez
     * Certiko. L'appel lui-même part en file d'attente — Salesforce refuse un
     * appel sortant après une écriture — et se vérifie sur LC027_Certiko.
     */
    @isTest
    static void finDeVisiteAnnonceLeNettoyage() {
        LC027_TestFactory.bouchonnerCallouts();
        dossier();
        appeler(corpsWebhook(System.Label.CERTIKO_STATUT_FIN_VT));

        Test.startTest();
        LC027_CertikoRetour.recevoirPost();
        Test.stopTest();

        Assert.areEqual('applique', premier().get('etat'));
        Assert.areEqual(System.Label.CERTIKO_COLONNE_FIN_VT, premier().get('nettoyage_certiko'));
    }

    /**
     * La file d'attente ne doit JAMAIS faire échouer la réception : le dossier
     * est déjà à jour chez nous, ce nettoyage n'est qu'un confort côté Certiko.
     */
    @isTest
    static void fileDAttenteDeNettoyageNeLevePas() {
        Test.startTest();
        LC027_CertikoRetour.NettoyageCertiko tache =
            new LC027_CertikoRetour.NettoyageCertiko('', '_equipe_poseur');
        tache.execute(null);
        Test.stopTest();

        Assert.isTrue(true, 'Un nettoyage impossible reste sans consequence.');
    }
}