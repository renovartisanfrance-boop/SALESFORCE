/**
 * Tests de LC026_Documents.
 *
 * L'essentiel porte sur la SÉCURITÉ APPLICATIVE, puisque c'est elle qui remplace
 * le partage Salesforce dans ce contexte Experience Cloud : token absent, token
 * inconnu, Id invalide, objet non supporté, record hors périmètre — et surtout
 * la règle « écriture sur une Piste uniquement », qui interdit à un partenaire de
 * toucher aux pièces d'un Dossier.
 */
@isTest
private class LC026_Documents_Test {

    private static final String TOKEN       = 'TEST-TOKEN-DOCS-001';
    private static final String TOKEN_AUTRE = 'TEST-TOKEN-DOCS-002';

    /**
     * Les triggers Lead / Pro__c de l'org émettent des appels sortants (SMS,
     * géocodage). Un test ne peut pas en faire : toute insertion ou mise à jour
     * doit donc être précédée de ce bouchon, sans quoi le DML échoue sur « les
     * méthodes de test ne prennent pas en charge les callouts ».
     */
    private class BouchonCallout implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest requete) {
            HttpResponse reponse = new HttpResponse();
            reponse.setStatusCode(200);
            reponse.setHeader('Content-Type', 'application/json');
            // Le géocodage des Dossiers désérialise en LISTE ; les autres appels
            // attendent un objet. Le corps dépend donc de l'endpoint appelé.
            String endpoint = requete.getEndpoint();
            Boolean estGeocodage = endpoint != null && endpoint.contains('nominatim');
            reponse.setBody(estGeocodage ? '[]' : '{"success":true}');
            return reponse;
        }
    }

    /** À appeler en tête de chaque test qui déclenche du DML. */
    private static void bouchonnerCallouts() {
        Test.setMock(HttpCalloutMock.class, new LC026_Documents_Test.BouchonCallout());
    }

    @testSetup
    static void jeuDeDonnees() {
        bouchonnerCallouts();

        List<Campaign> campagnes = new List<Campaign>{
            new Campaign(Name = 'Campagne documents',  IsActive = true, CampaignToken__c = TOKEN),
            new Campaign(Name = 'Campagne hors champ', IsActive = true, CampaignToken__c = TOKEN_AUTRE)
        };
        insert campagnes;

        Lead piste = new Lead(
            FirstName = 'Jean',
            LastName  = 'Dupont',
            Company   = 'Foyer Dupont',
            Email     = 'jean.dupont@example.com'
        );
        insert piste;

        // Le rattachement d'une Piste à une campagne passe par CampaignMember :
        // c'est exactement la règle appliquée par le reporting.
        insert new CampaignMember(CampaignId = campagnes[0].Id, LeadId = piste.Id);

        insert new Pro__c(
            Name              = 'Dossier documents',
            CodePostal__c     = '28001',
            Campagne_REGIE__c = campagnes[0].Id
        );
    }

    private static Lead laPiste() {
        return [SELECT Id FROM Lead LIMIT 1];
    }

    private static Pro__c leDossier() {
        return [SELECT Id FROM Pro__c LIMIT 1];
    }

    /** Contenu minimal, encodé comme le fait le composant. */
    private static String contenuBase64() {
        return EncodingUtil.base64Encode(Blob.valueOf('contenu de test'));
    }

    /* ── Lecture ────────────────────────────────────────────────────────── */

    @isTest
    static void getDocuments_piste_estModifiableEtVide() {
        Lead piste = laPiste();

        Test.startTest();
        LC026_Documents.DocumentsData data = LC026_Documents.getDocuments(piste.Id, TOKEN);
        Test.stopTest();

        Assert.areEqual('Lead', data.objectType, 'Le type d\'objet doit être identifié.');
        Assert.areEqual('Piste', data.typeLibelle, 'Le libellé attendu est « Piste ».');
        Assert.isTrue(data.modifiable, 'Une Piste accepte l\'ajout et la suppression.');
        Assert.areEqual(0, data.documents.size(), 'Aucun document n\'a encore été joint.');
    }

    @isTest
    static void getDocuments_dossier_estEnLectureSeule() {
        Pro__c dossier = leDossier();

        Test.startTest();
        LC026_Documents.DocumentsData data = LC026_Documents.getDocuments(dossier.Id, TOKEN);
        Test.stopTest();

        Assert.areEqual('Pro__c', data.objectType, 'Le type d\'objet doit être identifié.');
        Assert.areEqual('Dossier', data.typeLibelle, 'Le libellé attendu est « Dossier ».');
        Assert.isFalse(data.modifiable, 'Un Dossier est en consultation seule.');
    }

    /* ── Sécurité ───────────────────────────────────────────────────────── */

    @isTest
    static void getDocuments_sansToken_estRefuse() {
        Lead piste = laPiste();
        Boolean refuse = false;
        try {
            LC026_Documents.getDocuments(piste.Id, null);
        } catch (Exception e) {
            refuse = true;
        }
        Assert.isTrue(refuse, 'Un appel sans token doit être refusé.');
    }

    @isTest
    static void getDocuments_tokenInconnu_estRefuse() {
        Lead piste = laPiste();
        Boolean refuse = false;
        try {
            LC026_Documents.getDocuments(piste.Id, 'TOKEN-QUI-N-EXISTE-PAS');
        } catch (Exception e) {
            refuse = true;
        }
        Assert.isTrue(refuse, 'Un token inconnu doit être refusé.');
    }

    @isTest
    static void getDocuments_horsPerimetre_estRefuse() {
        Lead piste = laPiste();
        Boolean refuse = false;
        try {
            // La Piste existe, mais elle n'appartient PAS à cette campagne.
            LC026_Documents.getDocuments(piste.Id, TOKEN_AUTRE);
        } catch (Exception e) {
            refuse = true;
        }
        Assert.isTrue(refuse, 'Un record hors périmètre du token doit être refusé.');
    }

    @isTest
    static void getDocuments_objetNonSupporte_estRefuse() {
        Campaign campagne = [SELECT Id FROM Campaign WHERE CampaignToken__c = :TOKEN LIMIT 1];
        Boolean refuse = false;
        try {
            LC026_Documents.getDocuments(campagne.Id, TOKEN);
        } catch (Exception e) {
            refuse = true;
        }
        Assert.isTrue(refuse, 'Seuls Lead et Pro__c gèrent des documents.');
    }

    @isTest
    static void getDocuments_idInvalide_estRefuse() {
        Boolean refuse = false;
        try {
            LC026_Documents.getDocuments('pas-un-id', TOKEN);
        } catch (Exception e) {
            refuse = true;
        }
        Assert.isTrue(refuse, 'Un identifiant illisible doit être refusé.');
    }

    /* ── Ajout ──────────────────────────────────────────────────────────── */

    @isTest
    static void ajouterDocument_piste_jointLeFichier() {
        bouchonnerCallouts();
        Lead piste = laPiste();

        Test.startTest();
        LC026_Documents.DocumentsData data = LC026_Documents.ajouterDocument(
            piste.Id, TOKEN, 'Photo cadastrale 1.jpg', contenuBase64(), 'image/jpeg'
        );
        Test.stopTest();

        Assert.areEqual(1, data.documents.size(), 'Le document doit apparaître dans la liste.');
        Assert.areEqual('Photo cadastrale 1.jpg', data.documents[0].titre,
            'Le nom transmis par le composant est celui qui est stocké.');
        Assert.areEqual(1, [
            SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :piste.Id
        ], 'Le fichier doit être rattaché à la Piste.');
    }

    @isTest
    static void ajouterDocument_dossier_estRefuse() {
        bouchonnerCallouts();
        Pro__c dossier = leDossier();

        Boolean refuse = false;
        try {
            LC026_Documents.ajouterDocument(
                dossier.Id, TOKEN, 'piece.pdf', contenuBase64(), 'application/pdf'
            );
        } catch (Exception e) {
            refuse = true;
        }
        Assert.isTrue(refuse, 'Les documents d\'un Dossier sont en consultation seule.');
    }

    @isTest
    static void ajouterDocument_sansContenu_estRefuse() {
        Lead piste = laPiste();
        Boolean refuse = false;
        try {
            LC026_Documents.ajouterDocument(piste.Id, TOKEN, 'vide.pdf', null, 'application/pdf');
        } catch (Exception e) {
            refuse = true;
        }
        Assert.isTrue(refuse, 'Un fichier sans contenu doit être refusé.');
    }

    /* ── Consultation d'un fichier ──────────────────────────────────────── */

    @isTest
    static void getContenu_renvoieLesOctetsEtLeTypeMime() {
        bouchonnerCallouts();
        Lead piste = laPiste();
        LC026_Documents.DocumentsData data = LC026_Documents.ajouterDocument(
            piste.Id, TOKEN, 'Photo cadastrale 1.jpg', contenuBase64(), 'image/jpeg'
        );

        Test.startTest();
        LC026_Documents.ContenuDocument contenu = LC026_Documents.getContenu(
            piste.Id, TOKEN, data.documents[0].contentDocumentId
        );
        Test.stopTest();

        Assert.areEqual('image/jpeg', contenu.contentType,
            'Le type MIME doit être déduit de l\'extension, sinon le navigateur télécharge au lieu d\'afficher.');
        Assert.areEqual('contenu de test',
            EncodingUtil.base64Decode(contenu.base64).toString(),
            'Les octets renvoyés doivent être ceux du fichier.');
        Assert.isTrue(data.documents[0].consultable,
            'Un fichier de quelques octets est consultable.');
    }

    @isTest
    static void getContenu_documentNonLie_estRefuse() {
        bouchonnerCallouts();
        Lead piste = laPiste();

        // Document créé SANS lien vers la Piste : deviner son Id ne doit pas
        // suffire à en lire le contenu.
        ContentVersion version = new ContentVersion(
            Title           = 'Ailleurs.pdf',
            PathOnClient    = 'Ailleurs.pdf',
            VersionData     = Blob.valueOf('ailleurs'),
            ContentLocation = 'S',
            IsMajorVersion  = true
        );
        insert version;
        Id idDoc = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :version.Id].ContentDocumentId;

        Boolean refuse = false;
        try {
            LC026_Documents.getContenu(piste.Id, TOKEN, idDoc);
        } catch (Exception e) {
            refuse = true;
        }
        Assert.isTrue(refuse, 'Un document non lié à l\'enregistrement ne doit pas être lisible.');
    }

    @isTest
    static void getContenu_dossier_estAutorise() {
        bouchonnerCallouts();
        Pro__c dossier = leDossier();

        // Le Dossier est en consultation seule : la LECTURE, elle, doit marcher.
        ContentVersion version = new ContentVersion(
            Title                  = 'Piece dossier.pdf',
            PathOnClient           = 'Piece dossier.pdf',
            VersionData            = Blob.valueOf('dossier'),
            ContentLocation        = 'S',
            IsMajorVersion         = true,
            FirstPublishLocationId = dossier.Id
        );
        insert version;
        Id idDoc = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :version.Id].ContentDocumentId;

        Test.startTest();
        LC026_Documents.ContenuDocument contenu = LC026_Documents.getContenu(
            dossier.Id, TOKEN, idDoc
        );
        Test.stopTest();

        Assert.areEqual('application/pdf', contenu.contentType, 'Un PDF doit s\'ouvrir dans l\'onglet.');
    }

    /* ── Suppression ────────────────────────────────────────────────────── */

    @isTest
    static void supprimerDocument_piste_retireLeFichier() {
        bouchonnerCallouts();
        Lead piste = laPiste();

        LC026_Documents.DocumentsData avant = LC026_Documents.ajouterDocument(
            piste.Id, TOKEN, 'piece.pdf', contenuBase64(), 'application/pdf'
        );
        Assert.areEqual(1, avant.documents.size(), 'Le document doit d\'abord exister.');

        Test.startTest();
        LC026_Documents.DocumentsData apres = LC026_Documents.supprimerDocument(
            piste.Id, TOKEN, avant.documents[0].contentDocumentId
        );
        Test.stopTest();

        Assert.areEqual(0, apres.documents.size(), 'La liste doit être vide après suppression.');
    }

    @isTest
    static void supprimerDocument_nonLie_estRefuse() {
        bouchonnerCallouts();
        Lead piste = laPiste();

        // Document créé SANS lien vers la Piste : deviner son Id ne doit pas
        // suffire à le supprimer.
        ContentVersion version = new ContentVersion(
            Title           = 'Ailleurs.pdf',
            PathOnClient    = 'Ailleurs.pdf',
            VersionData     = Blob.valueOf('ailleurs'),
            ContentLocation = 'S',
            IsMajorVersion  = true
        );
        insert version;
        Id idDoc = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :version.Id].ContentDocumentId;

        Boolean refuse = false;
        try {
            LC026_Documents.supprimerDocument(piste.Id, TOKEN, idDoc);
        } catch (Exception e) {
            refuse = true;
        }
        Assert.isTrue(refuse, 'Un document non lié à l\'enregistrement ne doit pas être supprimable.');
    }

    @isTest
    static void supprimerDocument_dossier_estRefuse() {
        Pro__c dossier = leDossier();
        Boolean refuse = false;
        try {
            LC026_Documents.supprimerDocument(dossier.Id, TOKEN, dossier.Id);
        } catch (Exception e) {
            refuse = true;
        }
        Assert.isTrue(refuse, 'Un Dossier n\'autorise aucune suppression.');
    }

    /* ── Comptage ───────────────────────────────────────────────────────── */

    @isTest
    static void compterDocuments_renvoieLesLignesDuPerimetre() {
        bouchonnerCallouts();
        Lead piste = laPiste();
        Pro__c dossier = leDossier();
        LC026_Documents.ajouterDocument(piste.Id, TOKEN, 'a.pdf', contenuBase64(), 'application/pdf');
        LC026_Documents.ajouterDocument(piste.Id, TOKEN, 'b.pdf', contenuBase64(), 'application/pdf');

        Test.startTest();
        Map<String, Integer> compteurs = LC026_Documents.compterDocuments(
            new List<String>{ piste.Id, dossier.Id, 'pas-un-id' }, TOKEN
        );
        Test.stopTest();

        Assert.areEqual(2, compteurs.get(String.valueOf(piste.Id)),
            'La Piste porte deux documents.');
        Assert.isFalse(compteurs.containsKey(String.valueOf(dossier.Id)),
            'Un enregistrement sans document ne figure pas dans la map.');
    }

    @isTest
    static void compterDocuments_horsPerimetre_estIgnore() {
        bouchonnerCallouts();
        Lead piste = laPiste();
        LC026_Documents.ajouterDocument(piste.Id, TOKEN, 'a.pdf', contenuBase64(), 'application/pdf');

        Test.startTest();
        // Token valide mais d'une autre campagne : la ligne est simplement
        // absente du résultat, sans erreur — le reporting ne doit pas casser.
        Map<String, Integer> compteurs = LC026_Documents.compterDocuments(
            new List<String>{ piste.Id }, TOKEN_AUTRE
        );
        Test.stopTest();

        Assert.isTrue(compteurs.isEmpty(), 'Rien ne doit remonter hors du périmètre du token.');
    }

    /* ── Utilisateur Salesforce connecté : pas de token ─────────────────── */

    @isTest
    static void sansToken_confirmateurRattache_accedeEtCompte() {
        bouchonnerCallouts();
        // Sur le Dossier : le lookup Confirmateur de la Piste filtre sur le
        // profil, que l'utilisateur de test n'a pas.
        Pro__c dossier = leDossier();
        update new Pro__c(Id = dossier.Id, Confirmateurs__c = UserInfo.getUserId());
        insert new ContentVersion(
            Title                  = 'Piece dossier.pdf',
            PathOnClient           = 'Piece dossier.pdf',
            VersionData            = Blob.valueOf('dossier'),
            ContentLocation        = 'S',
            IsMajorVersion         = true,
            FirstPublishLocationId = dossier.Id
        );

        Test.startTest();
        LC021_DevisSignature.profilForce = Constants.PROFIL_PI_CONFIRMATEUR;
        LC026_Documents.DocumentsData data = LC026_Documents.getDocuments(dossier.Id, null);
        Map<String, Integer> compteurs = LC026_Documents.compterDocuments(
            new List<String>{ dossier.Id, laPiste().Id }, null
        );
        Test.stopTest();

        Assert.areEqual(1, data.documents.size(), 'Le confirmateur voit les documents de son Dossier.');
        Assert.areEqual(1, compteurs.get(String.valueOf(dossier.Id)), 'La pastille compte son Dossier.');
        Assert.areEqual(1, compteurs.size(), 'La Piste non rattachée reste hors pastille.');
    }

    @isTest
    static void sansToken_nonRattache_refuseSansParlerDeToken() {
        LC021_DevisSignature.profilForce = Constants.PROFIL_PI_CONFIRMATEUR;
        String message;
        try {
            LC026_Documents.getDocuments(laPiste().Id, null);
        } catch (AuraHandledException e) {
            message = e.getMessage();
        }
        Assert.isNotNull(message, 'Une Piste non rattachée doit être refusée.');
        Assert.isFalse(message.containsIgnoreCase('token'), 'Pas de token à évoquer : ' + message);
    }

    @isTest
    static void sansToken_profilNonHabilite_pastilleVide() {
        LC021_DevisSignature.profilForce = 'Profil sans habilitation';
        Map<String, Integer> compteurs = LC026_Documents.compterDocuments(
            new List<String>{ laPiste().Id }, null
        );
        Assert.isTrue(compteurs.isEmpty(), 'Aucun périmètre : aucune pastille, sans erreur.');
    }

    @isTest
    static void compterDocuments_listeVide_renvoieMapVide() {
        Test.startTest();
        Map<String, Integer> compteurs = LC026_Documents.compterDocuments(
            new List<String>(), TOKEN
        );
        Test.stopTest();

        Assert.isTrue(compteurs.isEmpty(), 'Une liste vide ne déclenche aucune requête.');
    }
    /**
     * Le titre de la modale ne doit JAMAIS porter de balisage.
     *
     * PRO_Nom_Client__c est une formule HYPERLINK : sa valeur vaut
     * « <a href="/a09..." target="_blank">Nom</a> ». Elle s'affichait telle
     * quelle en tete de la modale Documents.
     */
    @isTest
    static void titreDebarrasseDuBalisage() {
        String brut = LC026_Documents.texteBrut(
            '<a href="/a09Jv00000QWvgv" target="_blank">Test 104 Test 104-</a>');
        System.assertEquals('Test 104 Test 104-', brut,
            'Les balises doivent disparaitre, le nom rester intact.');
    }

    /** Les entites sont decodees, et &amp; en dernier pour ne rien recreer. */
    @isTest
    static void entitesDecodeesDansLeBonOrdre() {
        System.assertEquals('Dupont & Fils',
            LC026_Documents.texteBrut('<b>Dupont &amp; Fils</b>'),
            'Une esperluette encodee doit redevenir lisible.');
        System.assertEquals('&lt;test&gt;',
            LC026_Documents.texteBrut('&amp;lt;test&amp;gt;'),
            'Decoder &amp; en premier aurait recree des entites.');
    }

    /** Une valeur sans balisage traverse inchangee. */
    @isTest
    static void texteSimpleInchange() {
        System.assertEquals('Cecile Botzung-',
            LC026_Documents.texteBrut('Cecile Botzung-'));
        System.assertEquals(null, LC026_Documents.texteBrut(null));
    }

}