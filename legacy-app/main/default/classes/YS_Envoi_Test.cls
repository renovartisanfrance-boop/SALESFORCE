/**
 * Tests de LC021_DevisSignature.envoyerPourSignature.
 *
 * Deux préoccupations distinctes :
 *   • les GARDES — un devis signé, une demande déjà en cours, un email absent ou
 *     invalide, un contrat non généré : autant de cas où rien ne doit partir ;
 *   • le CONTRAT AVEC YOUSIGN — c'est bien le fichier déjà joint au dossier qui
 *     est transmis, et l'enregistrement n'est mis à jour qu'après coup.
 */
@isTest
private class YS_Envoi_Test {

    private static final String TOKEN = 'TEST-TOKEN-YS-001';

    @testSetup
    static void jeuDeDonnees() {
        Test.setMock(HttpCalloutMock.class, new YS_TestMock());

        Campaign campagne = new Campaign(
            Name = 'Campagne Yousign', IsActive = true, CampaignToken__c = TOKEN);
        insert campagne;

        Lead piste = new Lead(
            FirstName = 'Jean',
            LastName  = 'Dupont',
            Company   = 'Foyer Dupont',
            Email     = 'jean.dupont@example.com',
            Surface_habitable__c = 95
        );
        insert piste;
        insert new CampaignMember(CampaignId = campagne.Id, LeadId = piste.Id);

        // Un Dossier ne part pas en signature dans n'importe quel etat. Quatre
        // regles de validation de l'org s'enchainent, et il faut les satisfaire
        // toutes pour que devisfinal__c puisse quitter « ▣ Generation Devis » :
        //   • LEDS_FIN_DE_CHANTIER3  → la quantite de LEDS finale doit etre posee ;
        //   • LEDS_FIN_DE_CHANTIER   → quantite et mode d'installation vont par paire ;
        //   • « statut en cloture »  → quantite posee implique installation cloturee ;
        //   • LEDS_INSTALLATION      → une installation cloturee exige en plus le type
        //     final, le sous-traitant, le camion, la hauteur et la date de pose.
        //
        // Ce n'est pas un artifice de test : devisfinal__c est le devis FINAL,
        // emis apres travaux. L'org exige simplement que le chantier soit
        // reellement solde avant de l'envoyer signer. Les valeurs ci-dessous
        // sont relevees sur un Dossier reel, pas inventees.
        Camion__c camion = new Camion__c(Name = 'Camion Yousign');
        insert camion;

        Pro__c dossier = new Pro__c(
            Name              = 'Dossier Yousign',
            CodePostal__c     = '28001',
            MPR_SHAB__c       = 125,
            Campagne_REGIE__c = campagne.Id,
            PRO_Pr_nom_du_Signataire__c = 'Marie Martin',
            Email__c          = 'marie.martin@example.com',
            // chantier solde — cf. le commentaire ci-dessus
            PRO_Nombre_de_Cloche_Final__c   = 10,
            LED_Mode_d_installation__c      = 'Standard',
            INSTALLATION_Leds__c            = '🟩Installation Cloturée',
            PRO_LED_Installation_LED__c     = '✅HORS AGRICULTURE',
            // le type final doit egaler celui de la piste — 5e regle
            LEDS_Type_d_Installation_Final__c = '✅HORS AGRICULTURE',
            LOOKUP_SOUS_TRAITANT_LED__c     = UserInfo.getUserId(),
            CamionPro__c                    = camion.Id,
            PRO_LED_Hauteur_Sous_Plafond__c = '7',
            // Heure FIXE, et non Datetime.now() : une regle de l'org impose
            // les creneaux 9h-11h30, 11h30-14h et 14h-17h30. Avec l'heure
            // courante, le test passait ou echouait selon le moment de la
            // journee ou on le lancait.
            PRO_LED_Date_d_installation__c  = Datetime.newInstance(
                Date.today().addDays(-30), Time.newInstance(10, 0, 0, 0)),
            // et l'audit doit etre valide pour que le statut de signature bouge
            LEDS_Statut_Audit__c            = '🟩Validé',
            LED_Auditeur__c                 = '🟩OTMAN'
        );
        insert dossier;

        // Le devis vierge, tel que l'onglet Document l'aurait joint.
        joindreContrat(piste.Id);
        joindreContrat(dossier.Id);
    }

    private static void joindreContrat(Id recordId) {
        insert new ContentVersion(
            Title        = LC021_DevisSignature.TITRE_CONTRAT,
            PathOnClient = LC021_DevisSignature.NOM_FICHIER_CONTRAT,
            VersionData  = Blob.valueOf('%PDF-1.4 devis vierge'),
            FirstPublishLocationId = recordId
        );
    }

    private static Lead laPiste() {
        return [
            SELECT Id, RES_Statut_Devis__c, YS_Demande_Id__c, YS_Statut__c,
                   YS_Date_Envoi__c, YS_Message_Erreur__c
            FROM Lead LIMIT 1
        ];
    }

    private static Pro__c leDossier() {
        return [SELECT Id, devisfinal__c, YS_Demande_Id__c, YS_Statut__c FROM Pro__c LIMIT 1];
    }

    /* ── Cas nominaux ───────────────────────────────────────────────────── */

    @isTest
    static void envoiDepuisUnePiste() {
        YS_TestMock bouchon = new YS_TestMock();
        Test.setMock(HttpCalloutMock.class, bouchon);
        Id pisteId = laPiste().Id;

        Test.startTest();
        LC021_DevisSignature.EnvoiSignature retour =
            LC021_DevisSignature.envoyerPourSignature(pisteId, TOKEN, null, null, null, 'FR', false, null);
        Test.stopTest();

        System.assert(retour.envoye, 'L\'envoi aurait dû réussir : ' + retour.message);
        System.assertEquals('jean.dupont@example.com', retour.email,
            'À défaut de saisie, l\'email du record fait foi.');

        Lead piste = laPiste();
        System.assertEquals(bouchon.demandeId, piste.YS_Demande_Id__c);
        System.assertEquals('Envoye', piste.YS_Statut__c);
        System.assertNotEquals(null, piste.YS_Date_Envoi__c);
        System.assertEquals(
            LC021_DevisSignature.CODE_ATTENTE_SIGNATURE,
            LC021_DevisSignature.codeStatutPublic(piste.RES_Statut_Devis__c),
            'Le devis doit passer en attente de signature.');

        // C'est bien le fichier DÉJÀ JOINT qui est parti, pas un PDF reconstruit.
        String corpsDocument = bouchon.requetePour('/documents').getBodyAsBlob().toString();
        System.assert(corpsDocument.contains('%PDF-1.4 devis vierge'),
            'Le contrat stocké sur le dossier devait être transmis tel quel.');
    }

    /**
     * Le Dossier fusionne nom et prénom dans un seul champ, que Yousign veut
     * séparés : la coupure au premier espace doit être effective.
     */
    @isTest
    static void envoiDepuisUnDossierDecoupeLeNom() {
        YS_TestMock bouchon = new YS_TestMock();
        Test.setMock(HttpCalloutMock.class, bouchon);
        Id dossierId = leDossier().Id;

        Test.startTest();
        LC021_DevisSignature.EnvoiSignature retour =
            LC021_DevisSignature.envoyerPourSignature(dossierId, TOKEN, null, null, null, 'FR', false, null);
        Test.stopTest();

        System.assert(retour.envoye, 'L\'envoi aurait dû réussir : ' + retour.message);

        String corpsSignataire = bouchon.requetePour('/signers').getBody();
        System.assert(corpsSignataire.contains('"first_name":"Marie"'),
            'Le prénom devait être isolé : ' + corpsSignataire);
        System.assert(corpsSignataire.contains('"last_name":"Martin"'),
            'Le nom devait être isolé : ' + corpsSignataire);

        System.assertEquals(
            LC021_DevisSignature.CODE_ATTENTE_SIGNATURE,
            LC021_DevisSignature.codeStatutPublic(leDossier().devisfinal__c),
            'Le Dossier porte d\'autres libellés de picklist que la Piste : la '
            + 'conversion doit rester juste.');
    }

    /** L'email saisi dans l'onglet Signature l'emporte sur celui du record. */
    @isTest
    static void emailSaisiPrimeSurCeluiDuRecord() {
        YS_TestMock bouchon = new YS_TestMock();
        Test.setMock(HttpCalloutMock.class, bouchon);
        Id pisteId = laPiste().Id;

        Test.startTest();
        LC021_DevisSignature.EnvoiSignature retour = LC021_DevisSignature.envoyerPourSignature(
            pisteId, TOKEN, 'corrige@example.com', null, null, 'FR', false, null);
        Test.stopTest();

        System.assertEquals('corrige@example.com', retour.email);
        System.assert(bouchon.requetePour('/signers').getBody().contains('corrige@example.com'));
    }

    /** La langue du portail doit suivre jusque dans le mail reçu par le client. */
    @isTest
    static void langueEspagnolePropageLaLocale() {
        YS_TestMock bouchon = new YS_TestMock();
        Test.setMock(HttpCalloutMock.class, bouchon);
        Id pisteId = laPiste().Id;

        Test.startTest();
        LC021_DevisSignature.envoyerPourSignature(pisteId, TOKEN, null, null, null, 'ES', false, null);
        Test.stopTest();

        System.assert(bouchon.requetePour('/signers').getBody().contains('"locale":"es"'),
            'La locale espagnole devait être transmise.');
    }

    /**
     * Les reglages de la FICHE l'emportent sur les etiquettes.
     *
     * C'est tout l'objet du deplacement vers c/lwc000_utils : une etiquette est
     * unique pour l'org, une fiche non. Ce test le verifie la ou ca se voit —
     * dans ce qui part chez Yousign.
     */
    @isTest
    static void reglagesDeLaFichePrimentSurLesEtiquettes() {
        YS_TestMock bouchon = new YS_TestMock();
        Test.setMock(HttpCalloutMock.class, bouchon);
        Id pisteId = laPiste().Id;

        String reglages = JSON.serialize(new Map<String, Object>{
            'langue'         => 'es',
            'expediteur'     => 'FICHE-TEST',
            'champSignature' => '2|11|22|33|44',
            'champMention'   => 'DESACTIVE'
        });

        Test.startTest();
        LC021_DevisSignature.envoyerPourSignature(
            pisteId, TOKEN, null, null, null, 'FR', false, reglages);
        Test.stopTest();

        String demande = bouchon.requetePour('/signature_requests').getBody();
        System.assert(demande.contains('"custom_name":"FICHE-TEST"'),
            'Expediteur de la fiche non applique : ' + demande);

        String signataire = bouchon.requetePour('/signers').getBody();
        System.assert(signataire.contains('"locale":"es"'),
            'La langue de la fiche doit primer sur la langue du portail (FR) : ' + signataire);
        System.assert(signataire.contains('"page":2'),
            'Emplacement de signature non issu de la fiche : ' + signataire);
        System.assert(!signataire.contains('"type":"mention"'),
            'La mention desactivee par la fiche ne doit pas partir : ' + signataire);
    }

    /** Reglages absents : les etiquettes reprennent la main, rien ne casse. */
    @isTest
    static void sansReglagesDeFicheLesEtiquettesServent() {
        YS_TestMock bouchon = new YS_TestMock();
        Test.setMock(HttpCalloutMock.class, bouchon);
        Id pisteId = laPiste().Id;

        Test.startTest();
        LC021_DevisSignature.EnvoiSignature retour = LC021_DevisSignature.envoyerPourSignature(
            pisteId, TOKEN, null, null, null, 'FR', false, '{ ceci n est pas du JSON');
        Test.stopTest();

        System.assert(retour.envoye,
            'Un reglage illisible ne doit pas faire echouer un envoi : ' + retour.message);
        System.assert(bouchon.requetePour('/signers').getBody().contains('"locale":"es"'),
            'A defaut de fiche, YOUSIGN_LOCALE doit trancher.');
    }

    /* ── Numero de devis ────────────────────────────────────────────────── */

    /**
     * Reserver deux fois ne consomme QU'UN numero.
     *
     * C'est le test qui compte : rouvrir la modale, ou regenerer le document
     * apres correction d'une adresse, ne doit pas faire sauter la serie. La
     * contrepartie assumee du choix « numero attribue a la generation », ce
     * sont des trous quand un devis n'est jamais envoye — pas des doublons.
     */
    @isTest
    static void reserverDeuxFoisRendLeMemeNumero() {
        insert new YS_Compteur__c(
            Name = 'Devis CAE', Cle__c = YS_Numerotation.CLE_DEVIS,
            Prochain__c = 1001, Pas__c = 1);
        Id pisteId = laPiste().Id;

        Test.startTest();
        String premier = LC021_DevisSignature.reserverNumeroDevis(pisteId, TOKEN, null);
        String second  = LC021_DevisSignature.reserverNumeroDevis(pisteId, TOKEN, null);
        Test.stopTest();

        System.assertEquals('1001', premier, 'Le premier numero doit venir du compteur.');
        System.assertEquals(premier, second, 'Un second appel ne doit pas renumeroter.');
        System.assertEquals(1002,
            [SELECT Prochain__c FROM YS_Compteur__c LIMIT 1].Prochain__c,
            'Un seul numero devait etre consomme.');
    }

    /**
     * La cle portee par la FICHE choisit la sequence.
     *
     * Deux series coexistent ici ; seule celle designee doit avancer. C'est
     * tout l'objet du reglage : deux fiches peuvent numeroter separement.
     */
    @isTest
    static void laCleDeLaFicheChoisitLaSequence() {
        insert new List<YS_Compteur__c>{
            new YS_Compteur__c(Name = 'Devis CAE', Cle__c = YS_Numerotation.CLE_DEVIS,
                               Prochain__c = 1001, Pas__c = 1),
            new YS_Compteur__c(Name = 'Autre serie', Cle__c = 'AUTRE',
                               Prochain__c = 500, Pas__c = 1)
        };
        Id pisteId = laPiste().Id;

        Test.startTest();
        String numero = LC021_DevisSignature.reserverNumeroDevis(pisteId, TOKEN, 'AUTRE');
        Test.stopTest();

        System.assertEquals('500', numero, 'La cle de la fiche devait designer la serie AUTRE.');
        System.assertEquals(1001,
            [SELECT Prochain__c FROM YS_Compteur__c WHERE Cle__c = :YS_Numerotation.CLE_DEVIS].Prochain__c,
            'La serie du devis ne devait pas bouger.');
    }

    /* ── Gardes ─────────────────────────────────────────────────────────── */

    @isTest
    static void emailInvalideEstRefuse() {
        Test.setMock(HttpCalloutMock.class, new YS_TestMock());
        Id pisteId = laPiste().Id;

        String message = null;
        Test.startTest();
        try {
            LC021_DevisSignature.envoyerPourSignature(pisteId, TOKEN, 'pas-un-email', null, null, 'FR', false, null);
        } catch (Exception e) {
            message = e.getMessage();
        }
        Test.stopTest();

        System.assertNotEquals(null, message, 'Une adresse malformée devait être refusée.');
        System.assertEquals(null, laPiste().YS_Demande_Id__c,
            'Aucune demande ne doit avoir été créée.');
    }

    @isTest
    static void devisSansContratJointEstRefuse() {
        Test.setMock(HttpCalloutMock.class, new YS_TestMock());

        // On retire le fichier : le devis n'a jamais été généré.
        delete [SELECT Id FROM ContentDocument];
        Id pisteId = laPiste().Id;

        String message = null;
        Test.startTest();
        try {
            LC021_DevisSignature.envoyerPourSignature(pisteId, TOKEN, null, null, null, 'FR', false, null);
        } catch (Exception e) {
            message = e.getMessage();
        }
        Test.stopTest();

        System.assertNotEquals(null, message,
            'Sans document, l\'envoi doit être refusé avec un message explicite.');
    }

    @isTest
    static void demandeDejaEnCoursEstRefusee() {
        Test.setMock(HttpCalloutMock.class, new YS_TestMock());

        Lead piste = laPiste();
        piste.YS_Demande_Id__c = 'sr_deja_en_cours';
        piste.YS_Statut__c     = 'Envoye';
        piste.YS_Date_Envoi__c = Datetime.now();
        update piste;

        String message = null;
        Test.startTest();
        try {
            LC021_DevisSignature.envoyerPourSignature(piste.Id, TOKEN, null, null, null, 'FR', false, null);
        } catch (Exception e) {
            message = e.getMessage();
        }
        Test.stopTest();

        System.assertNotEquals(null, message, 'Un second envoi devait être bloqué.');
        System.assertEquals('sr_deja_en_cours', laPiste().YS_Demande_Id__c,
            'La demande en cours ne doit pas avoir été remplacée.');
    }

    @isTest
    static void tokenInvalideEstRefuse() {
        Test.setMock(HttpCalloutMock.class, new YS_TestMock());
        Id pisteId = laPiste().Id;

        Boolean refuse = false;
        Test.startTest();
        try {
            LC021_DevisSignature.envoyerPourSignature(pisteId, 'TOKEN-BIDON', null, null, null, 'FR', false, null);
        } catch (Exception e) {
            refuse = true;
        }
        Test.stopTest();

        System.assert(refuse, 'Le verrou du token de campagne doit s\'appliquer ici aussi.');
    }

    /* ── Échec Yousign ──────────────────────────────────────────────────── */

    /**
     * Un refus de Yousign ne doit PAS lever d'exception : elle annulerait la
     * transaction, et le motif de l'échec serait perdu pour le dossier.
     */
    @isTest
    static void echecYousignEstEnregistreSansException() {
        YS_TestMock bouchon = new YS_TestMock();
        bouchon.codeErreur = 422;
        Test.setMock(HttpCalloutMock.class, bouchon);
        Id pisteId = laPiste().Id;

        Test.startTest();
        LC021_DevisSignature.EnvoiSignature retour =
            LC021_DevisSignature.envoyerPourSignature(pisteId, TOKEN, null, null, null, 'FR', false, null);
        Test.stopTest();

        System.assert(!retour.envoye, 'L\'envoi a échoué, le retour doit le dire.');
        System.assertNotEquals(null, retour.message);

        Lead piste = laPiste();
        System.assertEquals('Erreur', piste.YS_Statut__c,
            'Le motif de l\'échec doit rester consultable sur la Piste.');
        System.assertNotEquals(null, piste.YS_Message_Erreur__c);
        System.assertEquals(
            LC021_DevisSignature.CODE_GENERATION,
            LC021_DevisSignature.codeStatutPublic(piste.RES_Statut_Devis__c),
            'Le statut métier ne doit pas avancer sur un échec.');
    }

    /* ── Réinitialisation ───────────────────────────────────────────────── */

    @isTest
    static void reinitialisationLibereUnNouvelEnvoi() {
        Test.setMock(HttpCalloutMock.class, new YS_TestMock());

        Lead piste = laPiste();
        piste.YS_Demande_Id__c = 'sr_perimee';
        piste.YS_Statut__c     = 'Envoye';
        update piste;

        Test.startTest();
        LC021_DevisSignature.reinitialiserSignature(piste.Id, TOKEN);
        Test.stopTest();

        Lead apres = laPiste();
        System.assertEquals(null, apres.YS_Demande_Id__c);
        System.assertEquals(null, apres.YS_Statut__c);
    }

    /* ── Relances ─────────────────────────────────────────── */

    /**
     * Le PREMIER envoi n'est pas une relance : le compteur doit rester a zero.
     * C'est la regle metier explicite, et celle qui se perd le plus facilement
     * en refactorisant.
     */
    @isTest
    static void premierEnvoiNeComptePasCommeRelance() {
        Test.setMock(HttpCalloutMock.class, new YS_TestMock());
        Id pisteId = laPiste().Id;

        Test.startTest();
        LC021_DevisSignature.envoyerPourSignature(pisteId, TOKEN, null, null, null, 'FR', false, null);
        Test.stopTest();

        Decimal relances = [SELECT YS_Nb_Relances__c FROM Lead WHERE Id = :pisteId].YS_Nb_Relances__c;
        System.assert(relances == null || relances == 0,
            'Le premier envoi ne doit pas compter comme une relance : ' + relances);
    }

    /**
     * Une relance incremente le compteur, et n'est PAS bloquee par la demande
     * en cours.
     *
     * ⚠️ UN SEUL ENVOI PAR TRANSACTION. Enchainer trois appels dans le meme
     * Test.startTest() semblait plus parlant, mais le premier fait un DML — et
     * Salesforce refuse alors tout appel sortant pour le reste de la
     * transaction. Les deux relances echouaient donc en silence, et le compteur
     * restait a zero. En production chaque envoi est une requete distincte,
     * donc une transaction distincte : l'etat de depart se pose ici en base,
     * pas en rejouant l'envoi precedent.
     */
    @isTest
    static void relanceIncrementeLeCompteur() {
        Test.setMock(HttpCalloutMock.class, new YS_TestMock());

        Lead piste = laPiste();
        piste.YS_Demande_Id__c = 'sr_precedente';
        piste.YS_Statut__c     = 'Envoye';
        piste.YS_Date_Envoi__c = Datetime.now();
        piste.YS_Nb_Relances__c = 1;
        update piste;

        Test.startTest();
        LC021_DevisSignature.envoyerPourSignature(piste.Id, TOKEN, null, null, null, 'FR', true, null);
        Test.stopTest();

        System.assertEquals(2,
            [SELECT YS_Nb_Relances__c FROM Lead WHERE Id = :piste.Id].YS_Nb_Relances__c,
            'Une relance de plus apres la premiere.');
    }

    /**
     * Une relance sur un dossier qui n'a JAMAIS ete envoye ne compte pas : il
     * n'y a rien a relancer, c'est un premier envoi deguise.
     */
    @isTest
    static void relanceSansEnvoiPrealableNeCompteRien() {
        Test.setMock(HttpCalloutMock.class, new YS_TestMock());
        Id pisteId = laPiste().Id;

        Test.startTest();
        LC021_DevisSignature.envoyerPourSignature(pisteId, TOKEN, null, null, null, 'FR', true, null);
        Test.stopTest();

        Decimal relances = [SELECT YS_Nb_Relances__c FROM Lead WHERE Id = :pisteId].YS_Nb_Relances__c;
        System.assert(relances == null || relances == 0,
            'Sans demande prealable, rien a relancer : ' + relances);
    }

    /* ── Conversion de statut ───────────────────────────────────────────── */

    /**
     * Les deux objets ne portent pas les mêmes libellés (« 🟦En Att Signature »
     * sur la Piste, « 🟦En Attente Signature » sur le Dossier). La valeur est
     * déduite de la liste de sélection, jamais écrite en dur : ce test échoue si
     * quelqu'un renomme une valeur sans mettre à jour la normalisation.
     */
    @isTest
    static void valeurStatutDeduiteDeLaPicklist() {
        Test.startTest();
        String surLead = LC021_DevisSignature.valeurStatut('Lead',
            LC021_DevisSignature.CODE_ATTENTE_SIGNATURE);
        String surPro  = LC021_DevisSignature.valeurStatut('Pro__c',
            LC021_DevisSignature.CODE_ATTENTE_SIGNATURE);
        Test.stopTest();

        System.assertEquals(LC021_DevisSignature.CODE_ATTENTE_SIGNATURE,
            LC021_DevisSignature.codeStatutPublic(surLead));
        System.assertEquals(LC021_DevisSignature.CODE_ATTENTE_SIGNATURE,
            LC021_DevisSignature.codeStatutPublic(surPro));
        System.assertEquals('RES_Statut_Devis__c', LC021_DevisSignature.champStatut('Lead'));
        System.assertEquals('devisfinal__c', LC021_DevisSignature.champStatut('Pro__c'));
    }
}