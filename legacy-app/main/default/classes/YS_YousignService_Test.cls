/**
 * Tests de YS_YousignService.
 *
 * L'essentiel porte sur le corps MULTIPART : c'est la seule partie du client qui
 * ne se contente pas de sérialiser du JSON, et une erreur d'un octet y produit un
 * PDF corrompu que Yousign accepterait sans broncher avant d'afficher une page
 * blanche au client. On vérifie donc que le corps se relit correctement, et pour
 * les trois restes possibles de la division du fichier par 3.
 */
@isTest
private class YS_YousignService_Test {

    /* ── Multipart ──────────────────────────────────────────────────────── */

    /**
     * Le corps doit contenir les deux parties attendues ET restituer le PDF
     * OCTET POUR OCTET. On teste les trois longueurs possibles modulo 3, parce
     * que c'est précisément ce reste qui décide du bourrage base64 recyclé.
     */
    @isTest
    static void multipartRestitueLeFichierQuelQueSoitSaLongueur() {
        // ⚠️ PAS de Test.startTest() dans la boucle : il ne se declare qu'une
        // fois par methode, et le deuxieme tour levait « Testing already
        // started ». Il n'est de toute facon pas necessaire ici — un appel
        // bouchonne n'a pas besoin d'une fenetre de limites dediee.
        for (Integer complement = 0; complement < 3; complement++) {

            YS_TestMock bouchon = new YS_TestMock();
            Test.setMock(HttpCalloutMock.class, bouchon);

            // Un contenu binaire varié : des octets nuls ou hauts casseraient
            // une implémentation qui passerait par String quelque part.
            String source = '%PDF-1.4 contenu binaire éàü';
            for (Integer i = 0; i < complement; i++) source += '#';
            Blob pdf = Blob.valueOf(source);

            YS_YousignService.ajouterDocument('sr_1', pdf, 'Devis.pdf');

            HttpRequest envoyee = bouchon.requetePour('/documents');
            System.assertNotEquals(null, envoyee, 'La requête document n\'a pas été émise.');

            String corps = envoyee.getBodyAsBlob().toString();

            System.assert(corps.contains('name="nature"'),
                'La partie « nature » manque (reste ' + complement + ').');
            System.assert(corps.contains('signable_document'),
                'La valeur signable_document manque (reste ' + complement + ').');
            System.assert(corps.contains('filename="Devis.pdf"'),
                'Le nom de fichier manque (reste ' + complement + ').');
            System.assert(corps.contains(source),
                'Le PDF n\'est pas restitué intact (reste ' + complement + ').');
            System.assert(corps.endsWith('--\r\n'),
                'Le corps ne se termine pas par la frontière de clôture (reste ' + complement + ').');
        }
    }

    /** Un nom de fichier accentué ne doit pas partir tel quel dans un en-tête MIME. */
    @isTest
    static void nomDeFichierRameneEnAscii() {
        YS_TestMock bouchon = new YS_TestMock();
        Test.setMock(HttpCalloutMock.class, bouchon);

        Test.startTest();
        YS_YousignService.ajouterDocument('sr_1', Blob.valueOf('%PDF-1.4'), 'Devis signé (é).pdf');
        Test.stopTest();

        String corps = bouchon.requetePour('/documents').getBodyAsBlob().toString();
        String declare = corps.substringBetween('filename="', '"');

        System.assertNotEquals(null, declare,
            'Aucun nom de fichier dans l\'en-tête MIME.');
        System.assert(declare.startsWith('Devis_sign'),
            'Le nom devait rester reconnaissable : ' + declare);
        System.assert(Pattern.matches('^[A-Za-z0-9._-]+$', declare),
            'Un en-tête MIME est ASCII : ' + declare);
    }

    /**
     * Le client doit voir « Econatura », pas le nom de l'organisation Yousign.
     *
     * Le compte est partage avec plusieurs integrations : le nom affiche se
     * pose donc requete par requete, jamais dans les reglages du compte. Ce test
     * garde cette decision — le jour ou quelqu'un retire email_notification en
     * pensant que l'etiquette suffit, il tombera ici.
     */
    @isTest
    static void nomExpediteurEstTransmis() {
        YS_TestMock bouchon = new YS_TestMock();
        Test.setMock(HttpCalloutMock.class, bouchon);

        Test.startTest();
        YS_YousignService.creerDemande('Devis CAE - Test', 'fr');
        Test.stopTest();

        String corps = bouchon.requetePour('/signature_requests').getBody();
        System.assert(corps.contains('"type":"custom"'),
            'Type expediteur inattendu : ' + corps);
        System.assert(
            corps.contains('"custom_name":"' + Label.YOUSIGN_EXPEDITEUR + '"'),
            'Le nom porte par etiquette doit partir tel quel : ' + corps);
    }

    /**
     * Un refus de parametres doit NOMMER le parametre et la raison.
     *
     * Le `detail` de Yousign ne dit que « invalid params » ; le motif est dans
     * `invalid_params`. Sans lui a l'ecran, une hauteur de signature de 34 au
     * lieu de 37 n'a pu etre comprise qu'en rejouant l'appel a la main.
     */
    @isTest
    static void refusDeParametresNommeLeParametre() {
        YS_TestMock bouchon = new YS_TestMock();
        bouchon.codeErreur = 400;
        bouchon.corpsErreur = '{"type":"parameters_not_valid","detail":"You have some invalid params in your payload.",'
            + '"invalid_params":[{"name":"fields[0].height","reason":"This value should be greater than or equal to 37."}]}';
        Test.setMock(HttpCalloutMock.class, bouchon);

        String message = null;
        Test.startTest();
        try {
            YS_YousignService.creerDemande('Devis', 'fr');
        } catch (Exception e) {
            message = e.getMessage();
        }
        Test.stopTest();

        System.assertNotEquals(null, message, 'Le refus doit lever.');
        System.assert(message.contains('fields[0].height'),
            'Le parametre fautif doit etre nomme : ' + message);
        System.assert(message.contains('37'),
            'La raison doit etre reprise telle quelle : ' + message);
    }

    /* ── Séquence nominale ──────────────────────────────────────────────── */

    @isTest
    static void sequenceComplete() {
        YS_TestMock bouchon = new YS_TestMock();
        Test.setMock(HttpCalloutMock.class, bouchon);

        Test.startTest();
        String demande = YS_YousignService.creerDemande('Devis CAE - Test', 'fr');
        String document = YS_YousignService.ajouterDocument(demande, Blob.valueOf('%PDF-1.4'), 'D.pdf');
        YS_YousignService.ajouterSignataire(demande, document,
            new YS_YousignService.Signataire('Jean', 'Dupont', 'jean@example.com', 'fr'),
            new YS_YousignService.Position(1, 45, 590, 242, 79));
        YS_YousignService.activer(demande);
        Test.stopTest();

        System.assertEquals('sr_test_0001', demande);
        System.assertEquals('doc_test_0001', document);
        System.assertEquals(4, bouchon.requetes.size(),
            'Les quatre appels de la séquence doivent être émis.');

        // Le signataire doit partir avec le niveau et le mode d'authentification
        // convenus : c'est ce qui décide de la valeur juridique de la signature.
        String corpsSignataire = bouchon.requetePour('/signers').getBody();
        System.assert(corpsSignataire.contains('"signature_level":"electronic_signature"'),
            'Niveau de signature inattendu : ' + corpsSignataire);
        System.assert(corpsSignataire.contains('"signature_authentication_mode":"no_otp"'),
            'Mode d\'authentification inattendu : ' + corpsSignataire);
        System.assert(corpsSignataire.contains('"email":"jean@example.com"'));
        System.assert(corpsSignataire.contains('"page":1'));
        System.assert(corpsSignataire.contains('"width":242')
                   && corpsSignataire.contains('"height":79'),
            'Les dimensions relevées avec PlaceIt doivent être transmises : ' + corpsSignataire);

        // Le mode de remise conditionne l'envoi du mail au client.
        System.assert(bouchon.requetePour('/signature_requests').getBody()
            .contains('"delivery_mode":"email"'));
    }

    /* ── Langue du signataire ───────────────────────────────────────────── */

    /**
     * Le réglage livré impose l'espagnol : les signataires sont espagnols, et
     * la langue de l'écran de l'opérateur ne doit pas décider de celle d'un
     * email adressé au client. Ce test échouera si quelqu'un remet
     * YOUSIGN_LOCALE sur « auto » sans le vouloir.
     */
    @isTest
    static void localeImposeeParLeReglage() {
        Test.startTest();
        String depuisFr = YS_YousignService.localeSignataire('fr');
        String depuisEs = YS_YousignService.localeSignataire('es');
        String sansRien = YS_YousignService.localeSignataire(null);
        Test.stopTest();

        System.assertEquals(depuisEs, depuisFr,
            'La langue du portail ne doit pas influer sur celle du signataire.');
        System.assertEquals(depuisEs, sansRien);
        System.assert(depuisEs == 'es' || depuisEs == 'fr',
            'Locale inattendue : ' + depuisEs);
    }

    /** Le portail espagnol ne doit pas se retrouver en français par accident. */
    @isTest
    static void localePropageeAuSignataire() {
        YS_TestMock bouchon = new YS_TestMock();
        Test.setMock(HttpCalloutMock.class, bouchon);

        Test.startTest();
        YS_YousignService.ajouterSignataire('sr_1', 'doc_1',
            new YS_YousignService.Signataire('Jean', 'Dupont', 'jean@example.com',
                YS_YousignService.localeSignataire('fr')),
            new YS_YousignService.Position(1, 140, 669));
        Test.stopTest();

        String attendu = '"locale":"' + YS_YousignService.localeSignataire('fr') + '"';
        System.assert(bouchon.requetePour('/signers').getBody().contains(attendu),
            'La locale résolue doit partir telle quelle : ' + attendu);
    }

    /* ── Mention accompagnant la signature ──────────────────────────────── */

    /**
     * En API v3 la mention est un CHAMP À PART, pas une propriété du cadre de
     * signature. Le corps doit donc porter deux entrées dans `fields`.
     */
    @isTest
    static void mentionEnvoyeeCommeChampDistinct() {
        YS_TestMock bouchon = new YS_TestMock();
        Test.setMock(HttpCalloutMock.class, bouchon);
        YS_YousignService.positionMentionSurcharge = '1|45|680|242|30';
        YS_YousignService.texteMentionSurcharge    = 'Lu et approuve - signe le %date%';

        Test.startTest();
        YS_YousignService.ajouterSignataire('sr_1', 'doc_1',
            new YS_YousignService.Signataire('Jean', 'Dupont', 'jean@example.com', 'fr'),
            new YS_YousignService.Position(1, 45, 590, 242, 79));
        Test.stopTest();

        String corps = bouchon.requetePour('/signers').getBody();
        System.assert(corps.contains('"type":"signature"'), corps);
        System.assert(corps.contains('"type":"mention"'),
            'La mention doit partir comme champ distinct : ' + corps);
        System.assert(corps.contains('%date%'),
            'La variable de date doit être transmise telle quelle, Yousign la résout : ' + corps);
    }

    /** Label vide = pas de mention. C'est le réglage livré par défaut. */
    @isTest
    static void sansPositionAucuneMentionNEstEnvoyee() {
        YS_TestMock bouchon = new YS_TestMock();
        Test.setMock(HttpCalloutMock.class, bouchon);
        YS_YousignService.positionMentionSurcharge = 'DESACTIVE';

        Test.startTest();
        YS_YousignService.ajouterSignataire('sr_1', 'doc_1',
            new YS_YousignService.Signataire('Jean', 'Dupont', 'jean@example.com', 'fr'),
            new YS_YousignService.Position(1, 45, 590));
        Test.stopTest();

        System.assert(!bouchon.requetePour('/signers').getBody().contains('"type":"mention"'),
            'Aucune mention ne devait partir.');
    }

    /* ── Espace de travail et identite visuelle ─────────────────── */

    /**
     * Les deux reglages sont FACULTATIFS : livres a « AUTO », ils ne doivent pas
     * partir. Transmettre un null ferait refuser la demande par Yousign.
     */
    @isTest
    static void reglageAutoNEnvoieRien() {
        YS_TestMock bouchon = new YS_TestMock();
        Test.setMock(HttpCalloutMock.class, bouchon);

        Test.startTest();
        YS_YousignService.creerDemande('Devis CAE - Test', 'fr');
        Test.stopTest();

        String corps = bouchon.requetePour('/signature_requests').getBody();
        System.assert(!corps.contains('workspace_id'),
            'Aucun espace de travail ne devait partir : ' + corps);
        System.assert(!corps.contains('branding_id'),
            'Aucune identite visuelle ne devait partir : ' + corps);
    }

    /** « AUTO », vide ou nul se valent : rien n'est transmis. */
    @isTest
    static void reglageNormalise() {
        Test.startTest();
        System.assertEquals(null, YS_YousignService.reglage('AUTO'));
        System.assertEquals(null, YS_YousignService.reglage('auto'));
        System.assertEquals(null, YS_YousignService.reglage('  '));
        System.assertEquals(null, YS_YousignService.reglage(null));
        System.assertEquals('efe74993-90e2-485e-9bdc-682ddbd68326',
            YS_YousignService.reglage('  efe74993-90e2-485e-9bdc-682ddbd68326  '),
            'Un identifiant reel doit etre conserve, espaces retires.');
        Test.stopTest();
    }

    /* ── Erreurs ────────────────────────────────────────────────────────── */

    @isTest
    static void erreurApiRemonteLeMessageDeYousign() {
        YS_TestMock bouchon = new YS_TestMock();
        bouchon.codeErreur = 422;
        Test.setMock(HttpCalloutMock.class, bouchon);

        String message = null;
        Test.startTest();
        try {
            YS_YousignService.creerDemande('Devis', 'fr');
            System.assert(false, 'Une exception était attendue.');
        } catch (YS_YousignService.YousignException e) {
            message = e.getMessage();
        }
        Test.stopTest();

        System.assertEquals('Refus simulé par le test.', message,
            'Le détail renvoyé par Yousign doit être remonté tel quel.');
    }

    /** Une clé refusée mérite un message qui désigne le Custom Label fautif. */
    @isTest
    static void erreur401DesigneLeLabel() {
        YS_TestMock bouchon = new YS_TestMock();
        bouchon.codeErreur = 401;
        Test.setMock(HttpCalloutMock.class, bouchon);

        String message = null;
        Test.startTest();
        try {
            YS_YousignService.creerDemande('Devis', 'fr');
        } catch (YS_YousignService.YousignException e) {
            message = e.getMessage();
        }
        Test.stopTest();

        System.assert(message != null && message.contains('YOUSIGN_API_TOKEN'),
            'Le message devrait désigner le label à corriger : ' + message);
    }

    @isTest
    static void telechargementVideEstUneErreur() {
        YS_TestMock bouchon = new YS_TestMock();
        bouchon.pdfSigne = Blob.valueOf('');
        Test.setMock(HttpCalloutMock.class, bouchon);

        Boolean leve = false;
        Test.startTest();
        try {
            YS_YousignService.telechargerSigne('sr_1');
        } catch (YS_YousignService.YousignException e) {
            leve = true;
        }
        Test.stopTest();

        System.assert(leve, 'Un document vide doit être refusé, pas stocké.');
    }

    /* ── Position du champ de signature ─────────────────────────────────── */

    @isTest
    static void positionLueDepuisLeLabel() {
        Test.startTest();
        YS_YousignService.Position p = YS_YousignService.positionSignature();
        Test.stopTest();

        System.assertNotEquals(null, p.page, 'La page doit être renseignée.');
        System.assert(p.page > 0, 'La page Yousign est numérotée à partir de 1.');
        System.assertNotEquals(null, p.x);
        System.assertNotEquals(null, p.y);
    }

    /**
     * Sans dimensions, aucune clé width/height ne doit partir : Yousign refuse
     * un `null` là où il attend un entier ou rien du tout.
     */
    @isTest
    static void positionSansDimensionsNEnvoieRien() {
        YS_TestMock bouchon = new YS_TestMock();
        Test.setMock(HttpCalloutMock.class, bouchon);
        // La mention est DESACTIVEE le temps de ce test : elle porte ses propres
        // width/height, qui faisaient echouer une assertion portant en realite
        // sur le champ de signature. Le test doit isoler ce qu'il mesure.
        YS_YousignService.positionMentionSurcharge = 'DESACTIVE';

        Test.startTest();
        YS_YousignService.ajouterSignataire('sr_1', 'doc_1',
            new YS_YousignService.Signataire('Jean', 'Dupont', 'jean@example.com', 'fr'),
            new YS_YousignService.Position(1, 45, 590));
        Test.stopTest();

        String corps = bouchon.requetePour('/signers').getBody();
        System.assert(!corps.contains('width'), 'Aucune largeur ne devait partir : ' + corps);
        System.assert(!corps.contains('height'), 'Aucune hauteur ne devait partir : ' + corps);
    }

    @isTest
    static void statutDemandeLuDansLaReponse() {
        YS_TestMock bouchon = new YS_TestMock();
        bouchon.statut = 'done';
        Test.setMock(HttpCalloutMock.class, bouchon);

        Test.startTest();
        String statut = YS_YousignService.statutDemande('sr_test_0001');
        Test.stopTest();

        System.assertEquals('done', statut);
    }
}