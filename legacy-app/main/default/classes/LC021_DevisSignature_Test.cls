/**
 * Tests de LC021_DevisSignature.
 *
 * L'essentiel du test porte sur la SÉCURITÉ APPLICATIVE, puisque c'est elle qui
 * remplace le partage Salesforce dans ce contexte Experience Cloud : token absent,
 * token inconnu, Id invalide, objet non supporté, record hors périmètre, et
 * écriture sur un champ hors liste blanche.
 */
@isTest
private class LC021_DevisSignature_Test {

    private static final String TOKEN        = 'TEST-TOKEN-DEVIS-001';
    private static final String TOKEN_AUTRE  = 'TEST-TOKEN-DEVIS-002';

    /**
     * Les triggers Lead / Pro__c de l'org émettent des appels sortants (SMS,
     * synchronisation externe). Un test ne peut pas en faire : toute insertion
     * ou mise à jour doit donc être précédée de ce bouchon, sans quoi le DML
     * échoue sur « les méthodes de test ne prennent pas en charge les callouts ».
     */
    private class BouchonCallout implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest requete) {
            HttpResponse reponse = new HttpResponse();
            reponse.setStatusCode(200);
            reponse.setHeader('Content-Type', 'application/json');
            // Le géocodage des Dossiers (ProTriggerHandler.AsyncGetCoordinates)
            // désérialise en LISTE ; les autres appels sortants attendent un
            // objet. Le corps dépend donc de l'endpoint appelé.
            String endpoint = requete.getEndpoint();
            Boolean estGeocodage = endpoint != null && endpoint.contains('nominatim');
            reponse.setBody(estGeocodage ? '[]' : '{"success":true}');
            return reponse;
        }
    }

    /** À appeler en tête de chaque test qui déclenche du DML. */
    private static void bouchonnerCallouts() {
        Test.setMock(HttpCalloutMock.class, new LC021_DevisSignature_Test.BouchonCallout());
    }

    @testSetup
    static void jeuDeDonnees() {
        bouchonnerCallouts();

        List<Campaign> campagnes = new List<Campaign>{
            new Campaign(Name = 'Campagne devis',       IsActive = true, CampaignToken__c = TOKEN),
            new Campaign(Name = 'Campagne hors champ',  IsActive = true, CampaignToken__c = TOKEN_AUTRE)
        };
        insert campagnes;

        Lead piste = new Lead(
            FirstName = 'Jean',
            LastName  = 'Dupont',
            Company   = 'Foyer Dupont',
            Email     = 'jean.dupont@example.com',
            Surface_habitable__c = 95
        );
        insert piste;

        // Le rattachement d'une Piste à une campagne passe par CampaignMember :
        // c'est exactement la règle appliquée par le reporting.
        insert new CampaignMember(CampaignId = campagnes[0].Id, LeadId = piste.Id);

        insert new Pro__c(
            Name              = 'Dossier devis',
            CodePostal__c     = '28001',
            MPR_SHAB__c       = 125,
            Campagne_REGIE__c = campagnes[0].Id
        );
    }

    private static Lead laPiste() {
        return [SELECT Id, Surface_habitable__c FROM Lead LIMIT 1];
    }

    private static Pro__c leDossier() {
        return [SELECT Id, MPR_SHAB__c FROM Pro__c LIMIT 1];
    }

    /* ── Lecture ────────────────────────────────────────────────────────── */

    @isTest
    static void getDevis_piste_renvoieChampsEtStatut() {
        Lead piste = laPiste();

        Test.startTest();
        LC021_DevisSignature.DevisData data = LC021_DevisSignature.getDevis(
            piste.Id, TOKEN, new List<String>{ 'FirstName', 'LastName', 'Email' }
        );
        Test.stopTest();

        System.assertEquals('Lead', data.objectType, 'Objet mal identifié');
        System.assertEquals('Piste', data.typeLibelle, 'Libellé de type inattendu');
        System.assertEquals('Surface_habitable__c', data.champSurface, 'Champ surface de la Piste');
        System.assertEquals(95, data.surface, 'Surface remontée');
        // Statut non renseigné => début de cycle.
        System.assertEquals(LC021_DevisSignature.CODE_GENERATION, data.statutCode, 'Statut normalisé');

        Map<String, LC021_DevisSignature.ChampDevis> parApi =
            new Map<String, LC021_DevisSignature.ChampDevis>();
        for (LC021_DevisSignature.ChampDevis c : data.champs) parApi.put(c.apiName, c);

        System.assertEquals('Jean', parApi.get('FirstName').valeur, 'Valeur du prénom');
        System.assert(parApi.get('FirstName').modifiable, 'Le prénom doit être modifiable');
        // Les champs techniques sont réintégrés même s'ils ne sont pas demandés.
        System.assert(parApi.containsKey('Surface_habitable__c'), 'La surface doit toujours être remontée');
        System.assert(parApi.containsKey('RES_Statut_Devis__c'), 'Le statut doit toujours être remonté');
    }

    @isTest
    static void getDevis_dossier_utiliseLesChampsPro() {
        Pro__c dossier = leDossier();

        Test.startTest();
        LC021_DevisSignature.DevisData data = LC021_DevisSignature.getDevis(dossier.Id, TOKEN, null);
        Test.stopTest();

        System.assertEquals('Pro__c', data.objectType, 'Objet mal identifié');
        System.assertEquals('Dossier', data.typeLibelle, 'Libellé de type inattendu');
        // Écart d'API assumé : la surface « RES- Shab » s'appelle MPR_SHAB__c ici.
        System.assertEquals('MPR_SHAB__c', data.champSurface, 'Champ surface du Dossier');
        System.assertEquals(125, data.surface, 'Surface remontée');
    }

    /* ── Écriture ───────────────────────────────────────────────────────── */

    @isTest
    static void enregistrerDevis_metAJourEtRenvoieLeDevisRecharge() {
        bouchonnerCallouts();
        Lead piste = laPiste();

        Test.startTest();
        LC021_DevisSignature.DevisData data = LC021_DevisSignature.enregistrerDevis(
            piste.Id, TOKEN,
            new Map<String, String>{ 'Surface_habitable__c' => '125', 'Email' => 'nouveau@example.com' },
            new List<String>{ 'Email' }
        );
        Test.stopTest();

        System.assertEquals(125, data.surface, 'La surface doit être enregistrée puis rechargée');
        Lead relu = [SELECT Surface_habitable__c, Email FROM Lead WHERE Id = :piste.Id];
        System.assertEquals(125, relu.Surface_habitable__c, 'Surface en base');
        System.assertEquals('nouveau@example.com', relu.Email, 'Email en base');
    }

    @isTest
    static void enregistrerDevis_ignoreUnChampHorsListeBlanche() {
        bouchonnerCallouts();
        Lead piste = laPiste();

        Test.startTest();
        LC021_DevisSignature.enregistrerDevis(
            piste.Id, TOKEN,
            // Status n'est pas dans la liste blanche d'écriture : doit être ignoré
            // sans faire échouer l'enregistrement du champ légitime.
            new Map<String, String>{ 'Status' => 'Working', 'LastName' => 'Durand' },
            null
        );
        Test.stopTest();

        Lead relu = [SELECT LastName, Status FROM Lead WHERE Id = :piste.Id];
        System.assertEquals('Durand', relu.LastName, 'Le champ autorisé doit être écrit');
        System.assertNotEquals('Working', relu.Status, 'Le champ non autorisé ne doit pas être écrit');
    }

    @isTest
    static void enregistrerDevis_sansModification_neLeveRien() {
        bouchonnerCallouts();
        Lead piste = laPiste();
        Test.startTest();
        LC021_DevisSignature.DevisData data = LC021_DevisSignature.enregistrerDevis(
            piste.Id, TOKEN, new Map<String, String>(), null
        );
        Test.stopTest();
        System.assertNotEquals(null, data, 'Le devis doit être renvoyé même sans modification');
    }

    /* ── Document contractuel ───────────────────────────────────────────── */

    /**
     * Un gabarit hors liste blanche est REFUSE, pas remplace.
     *
     * Le nom vient du navigateur : sans filtre, l'invite d'un site public
     * pourrait lire n'importe quelle ressource statique de l'org.
     *
     * ⚠️ CE TEST GARDE UNE CORRECTION. La premiere version repliait en silence
     * sur le gabarit par defaut, et le defaut est apparu des la deuxieme fiche :
     * le TH168 partait a la signature avec le contrat de la 060, sans aucun
     * signal. Servir un AUTRE contrat que celui demande est pire que ne rien
     * servir — l'erreur ne se voit qu'apres signature du client.
     */
    @isTest
    static void gabaritHorsListeEstRefuse() {
        Exception leve = null;
        Test.startTest();
        try {
            LC021_DevisSignature.getContratBase64(TOKEN, 'une_ressource_interne');
        } catch (Exception e) {
            leve = e;
        }
        Test.stopTest();

        System.assertNotEquals(null, leve,
            'Un gabarit non autorise doit etre refuse, jamais remplace en silence.');
        System.assert(leve instanceof AuraHandledException,
            'Le refus doit arriver au composant sous forme exploitable : ' + leve);
    }

    /** Un nom vide reste legitime : la fiche ne declare pas de gabarit. */
    @isTest
    static void gabaritAbsentServeLeDefaut() {
        Test.startTest();
        String defaut = LC021_DevisSignature.getContratBase64(TOKEN, null);
        Test.stopTest();

        System.assert(String.isNotBlank(defaut),
            'Sans gabarit declare, le document par defaut doit etre servi.');
    }

    @isTest
    static void getContratBase64_renvoieLePdf() {
        Test.startTest();
        String base64 = LC021_DevisSignature.getContratBase64(TOKEN, null);
        Test.stopTest();

        System.assert(String.isNotBlank(base64), 'Le contrat doit être renvoyé');
        // 'JVBERi' est l'encodage base64 de '%PDF-', la signature d'un fichier
        // PDF — preuve que ce sont bien les octets du document, pas un message
        // d'erreur encodé. (Pas de Blob.toString() : le binaire n'est pas de
        // l'UTF-8 valide et la conversion lèverait.)
        System.assert(base64.startsWith('JVBERi'),
            'Le contenu doit être un PDF (préfixe %PDF-)');
    }

    @isTest
    static void getContratBase64_sansToken_refuse() {
        Boolean refuse = false;
        try {
            LC021_DevisSignature.getContratBase64(null, null);
        } catch (AuraHandledException e) {
            refuse = true;
        }
        System.assert(refuse, 'Le contrat ne doit pas être livré sans token');
    }

    /* ── Contrat joint au record ──────────────────────────────────────── */

    @isTest
    static void enregistrerContrat_joint_versionne_et_deduplique() {
        bouchonnerCallouts();
        Lead piste = laPiste();
        String pdf1 = EncodingUtil.base64Encode(Blob.valueOf('%PDF-1.4 contenu un'));
        String pdf2 = EncodingUtil.base64Encode(Blob.valueOf('%PDF-1.4 contenu deux'));

        Test.startTest();
        LC021_DevisSignature.ContratJoint premier = LC021_DevisSignature.enregistrerContrat(
            piste.Id, TOKEN, pdf1, 'empreinte-A');
        // Meme empreinte rejouee : rien a ecrire, ni fichier ni champ. C'est le
        // cas nominal — rouvrir la modale sans rien changer.
        LC021_DevisSignature.ContratJoint rejoue = LC021_DevisSignature.enregistrerContrat(
            piste.Id, TOKEN, pdf1, 'empreinte-A');
        // Empreinte differente : nouvelle VERSION du MEME document, jamais un
        // second document. C'est precisement ce qui echouait sous l'utilisateur
        // invite, faute de pouvoir lire ContentDocumentLink.
        LC021_DevisSignature.ContratJoint modifie = LC021_DevisSignature.enregistrerContrat(
            piste.Id, TOKEN, pdf2, 'empreinte-B');
        Test.stopTest();

        System.assertEquals(false, premier.dejaAJour, 'Premier stockage = écriture');
        System.assertEquals(true, rejoue.dejaAJour, 'Empreinte identique = aucune écriture');
        System.assertEquals(premier.contentDocumentId, modifie.contentDocumentId,
            'Un contenu modifié versionne le MÊME document');
        System.assertNotEquals(premier.contentVersionId, modifie.contentVersionId,
            'Un contenu modifié crée une nouvelle version');

        Integer nbLiens = [
            SELECT COUNT() FROM ContentDocumentLink
            WHERE LinkedEntityId = :piste.Id
            AND ContentDocument.Title = :LC021_DevisSignature.TITRE_CONTRAT
        ];
        System.assertEquals(1, nbLiens, 'Un seul document de contrat par record');

        Blob lu = LC021_DevisSignature.lireContratStocke(piste.Id, TOKEN);
        System.assert(lu.toString().contains('deux'), 'La lecture doit servir la DERNIÈRE version');

        // Le couple pointeur + empreinte doit vivre sur l'enregistrement : c'est
        // lui qui remplace la requete ContentDocumentLink, interdite a l'invite.
        Lead apres = [SELECT YS_Contrat_Doc_Id__c, YS_Contrat_Empreinte__c
                      FROM Lead WHERE Id = :piste.Id];
        System.assertEquals(modifie.contentDocumentId, apres.YS_Contrat_Doc_Id__c,
            'Le document joint doit etre memorise sur la Piste.');
        System.assertEquals('empreinte-B', apres.YS_Contrat_Empreinte__c,
            'La derniere empreinte doit etre memorisee.');
    }

    /**
     * Le pointeur memorise peut devenir PERIME : il suffit que quelqu'un
     * supprime le fichier depuis l'interface. Le devis doit alors repartir sur
     * un nouveau document, pas rester bloque.
     *
     * Regression : le repli testait `derniere == null` et ne se declenchait
     * donc jamais quand le pointeur venait du record. Resultat en sandbox,
     * apres un menage des doublons : ENTITY_IS_DELETED a chaque generation, et
     * plus aucun devis joignable.
     */
    @isTest
    static void enregistrerContrat_seRepareApresSuppressionDuFichier() {
        bouchonnerCallouts();
        Lead piste = laPiste();
        String pdf = EncodingUtil.base64Encode(Blob.valueOf('%PDF-1.4 contenu un'));

        LC021_DevisSignature.ContratJoint premier =
            LC021_DevisSignature.enregistrerContrat(piste.Id, TOKEN, pdf, 'empreinte-A');

        // Le fichier disparait, mais le record garde son pointeur.
        delete [SELECT Id FROM ContentDocument WHERE Id = :premier.contentDocumentId];

        Test.startTest();
        LC021_DevisSignature.ContratJoint apres =
            LC021_DevisSignature.enregistrerContrat(piste.Id, TOKEN, pdf, 'empreinte-B');
        Test.stopTest();

        System.assertNotEquals(null, apres.contentDocumentId,
            'Un pointeur perime doit conduire a un nouveau document, pas a une erreur.');
        System.assertNotEquals(premier.contentDocumentId, apres.contentDocumentId,
            'Le nouveau document doit etre distinct du document supprime.');

        Lead recharge = [SELECT YS_Contrat_Doc_Id__c FROM Lead WHERE Id = :piste.Id];
        System.assertEquals(apres.contentDocumentId, recharge.YS_Contrat_Doc_Id__c,
            'Le pointeur doit avoir ete corrige, sans quoi l echec se repeterait.');
    }

    @isTest
    static void enregistrerContrat_refuseUnContenuNonPdf() {
        bouchonnerCallouts();
        Boolean refuse = false;
        try {
            LC021_DevisSignature.enregistrerContrat(laPiste().Id, TOKEN,
                EncodingUtil.base64Encode(Blob.valueOf('<html>pas un pdf</html>')), 'empreinte-test');
        } catch (AuraHandledException e) {
            refuse = true;
        }
        System.assert(refuse, 'Un contenu non-PDF doit être refusé');
    }

    @isTest
    static void contratRest_sertLePdfEtRefuseSansToken() {
        bouchonnerCallouts();
        Lead piste = laPiste();
        LC021_DevisSignature.enregistrerContrat(piste.Id, TOKEN,
            EncodingUtil.base64Encode(Blob.valueOf('%PDF-1.4 servi par le REST')), 'empreinte-test');

        Test.startTest();
        // ── Appel légitime : 200, PDF inline ─────────────────────────────
        RestContext.request = new RestRequest();
        RestContext.request.params.put('recordId', piste.Id);
        RestContext.request.params.put('token', TOKEN);
        RestContext.response = new RestResponse();
        LC021_DevisContratRest.getContrat();
        System.assertEquals(200, RestContext.response.statusCode, 'Le contrat doit être servi');
        System.assert(RestContext.response.responseBody.toString().startsWith('%PDF'),
            'Le corps doit être le PDF stocké');

        // ── Sans token : 404, sans fuite d'information ───────────────────
        RestContext.request = new RestRequest();
        RestContext.request.params.put('recordId', piste.Id);
        RestContext.response = new RestResponse();
        LC021_DevisContratRest.getContrat();
        System.assertEquals(404, RestContext.response.statusCode, 'Sans token : refus');
        Test.stopTest();
    }

    @isTest
    static void lireContratStocke_sansFichier_refuse() {
        Boolean refuse = false;
        try {
            LC021_DevisSignature.lireContratStocke(leDossier().Id, TOKEN);
        } catch (AuraHandledException e) {
            refuse = true;
        }
        System.assert(refuse, 'Aucun fichier joint : la lecture doit refuser');
    }
    /* ── Sécurité applicative ───────────────────────────────────────────── */

    @isTest
    static void getDevis_sansToken_refuse() {
        System.assert(echoue(laPiste().Id, null), 'Un token vide doit être refusé');
    }

    @isTest
    static void getDevis_tokenInconnu_refuse() {
        System.assert(echoue(laPiste().Id, 'TOKEN-QUI-NEXISTE-PAS'), 'Un token inconnu doit être refusé');
    }

    @isTest
    static void getDevis_recordHorsPerimetre_refuse() {
        // Le record existe, le token aussi — mais ils ne se rencontrent pas.
        System.assert(echoue(laPiste().Id, TOKEN_AUTRE), 'Une Piste hors campagne doit être refusée');
        System.assert(echoue(leDossier().Id, TOKEN_AUTRE), 'Un Dossier hors campagne doit être refusé');
    }

    @isTest
    static void getDevis_idInvalide_refuse() {
        System.assert(echoue('pas-un-id', TOKEN), 'Un Id malformé doit être refusé');
    }

    @isTest
    static void getDevis_objetNonSupporte_refuse() {
        bouchonnerCallouts();
        Account compte = new Account(Name = 'Compte hors périmètre');
        insert compte;
        System.assert(echoue(compte.Id, TOKEN), 'Un objet sans workflow de devis doit être refusé');
    }

    /* ── Utilisateur Salesforce connecté : pas de token ─────────────────── */

    /** Message de refus, ou null si l'appel est passé. */
    private static String messageRefus(String recordId) {
        try {
            LC021_DevisSignature.getDevis(recordId, null, null);
            return null;
        } catch (AuraHandledException e) {
            return e.getMessage();
        }
    }

    @isTest
    static void sansToken_confirmateurRattache_accede() {
        bouchonnerCallouts();
        // Sur le Dossier : le lookup Confirmateur de la Piste filtre sur le
        // profil, que l'utilisateur de test n'a pas.
        Pro__c dossier = leDossier();
        update new Pro__c(Id = dossier.Id, Confirmateurs__c = UserInfo.getUserId());

        Test.startTest();
        LC021_DevisSignature.profilForce = Constants.PROFIL_PI_CONFIRMATEUR;
        String surDossier = messageRefus(dossier.Id);
        String surPiste   = messageRefus(laPiste().Id);
        String gabarit    = LC021_DevisSignature.getContratBase64(null, null);
        Test.stopTest();

        System.assertEquals(null, surDossier, 'Le confirmateur du Dossier doit y accéder sans token');
        System.assertNotEquals(null, surPiste, 'Une Piste non rattachée reste refusée');
        System.assertNotEquals(null, gabarit, 'Le gabarit doit être servi sans token');
    }

    @isTest
    static void sansToken_confirmateurNonRattache_refuseSansParlerDeToken() {
        LC021_DevisSignature.profilForce = Constants.PROFIL_PI_CONFIRMATEUR;
        String message = messageRefus(laPiste().Id);
        System.assertNotEquals(null, message, 'Une Piste non rattachée doit être refusée');
        System.assert(!message.containsIgnoreCase('token'), 'Pas de token à évoquer : ' + message);
    }

    @isTest
    static void sansToken_responsableTelepro_horsCritere_refuse() {
        LC021_DevisSignature.profilForce = Constants.PROFIL_PI_RESPONSABLE_TELEPRO;
        System.assertNotEquals(null, messageRefus(laPiste().Id),
            'Une Piste hors fiche RES060 AA- doit être refusée');
        System.assertNotEquals(null, messageRefus(leDossier().Id),
            'Le responsable telepro n\'a pas de périmètre Dossier');
    }

    @isTest
    static void sansToken_apporteurProprietaire_accede() {
        // Les campagnes du jeu de données appartiennent à l'utilisateur de test.
        LC021_DevisSignature.profilForce = Constants.PROFIL_PI_APP_AFF;
        System.assertEquals(null, messageRefus(laPiste().Id),
            'L\'apporteur accède aux Pistes de ses campagnes sans token');
    }

    @isTest
    static void sansToken_profilNonHabilite_refuseSansParlerDeToken() {
        LC021_DevisSignature.profilForce = 'Profil sans habilitation';
        String message = messageRefus(laPiste().Id);
        System.assertNotEquals(null, message, 'Un profil non habilité doit être refusé');
        System.assert(!message.containsIgnoreCase('token'), 'Pas de token à évoquer : ' + message);
    }

    /** Renvoie true si l'appel a bien été refusé par une AuraHandledException. */
    private static Boolean echoue(String recordId, String token) {
        try {
            LC021_DevisSignature.getDevis(recordId, token, null);
            return false;
        } catch (AuraHandledException e) {
            return true;
        }
    }
}