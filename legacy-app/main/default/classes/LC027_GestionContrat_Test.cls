/**
 * Tests de LC027_GestionContrat — lecture, saisie et envoi en signature.
 *
 * SIMULATEUR HTTP INTERNE plutôt que YS_TestMock : le test ne dépend ainsi
 * d'aucune classe du flux devis, qui pourrait évoluer pour ses propres besoins
 * et faire échouer ces tests-ci sans rapport avec le portail Prévisites.
 */
@isTest
private class LC027_GestionContrat_Test {

    /** Répond à toute la séquence Yousign : création, document, signataire, activation. */
    private class MockYousign implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(201);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"id":"ys-demande-123","status":"draft"}');
            return res;
        }
    }

    /** Simulateur d'échec, pour vérifier que l'erreur est tracée sans perdre la saisie. */
    private class MockYousignErreur implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"detail":"panne simulee"}');
            return res;
        }
    }

    private static String donnees() {
        return JSON.serialize(new Map<String, Object>{
            'Name'                  => 'Maria Garcia',
            'Contrat_Profession__c' => 'Tecnico',
            'Contrat_Situation__c'  => 'Autonomo',
            'Contrat_NIF__c'        => '12345678Z',
            'Contrat_Adresse__c'    => 'Calle Mayor 1',
            'Contrat_CodePostal__c' => '28001',
            'Contrat_Ville__c'      => 'Madrid',
            // Multipicklist : valeurs separees par ';'. Volontairement fournies
            // dans le DESORDRE, pour figer le comportement verifie ci-dessous.
            'NombrePrevisites__c'   => '6 à 10',
            'Contrat_Provinces__c'  => 'Madrid;Burgos;Ávila',
            'Telephone__c'          => '612345678',
            'Email__c'              => 'maria@example.es'
        });
    }

    /* ── Contrôle d'accès ────────────────────────────────────────────────── */

    @isTest
    static void tokenInconnuLeve() {
        Test.startTest();
        try {
            LC027_GestionContrat.getContrat('inconnu');
            System.assert(false, 'Un token inconnu doit lever.');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('introuvable'), e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void roleRegieLeve() {
        LC027_TestFactory.regie('token-regie');

        Test.startTest();
        try {
            LC027_GestionContrat.getContrat('token-regie');
            System.assert(false, 'Une régie ne doit pas accéder au contrat pré-visiteur.');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('pré-visiteur'), e.getMessage());
        }
        Test.stopTest();
    }

    /* ── Lecture ─────────────────────────────────────────────────────────── */

    @isTest
    static void getContratRemonteLesChampsDuFormulaire() {
        LC027_TestFactory.previsiteur('token-lecture');

        Test.startTest();
        LC027_GestionContrat.EtatContrat etat = LC027_GestionContrat.getContrat('token-lecture');
        Test.stopTest();

        System.assertEquals('En cours de generation', etat.statut);
        System.assertEquals(false, etat.signe);
        System.assertEquals(false, etat.documentDisponible,
            'Aucun contrat archivé tant que rien n\'a été envoyé.');
        // On vérifie la PRÉSENCE des champs, pas leur NOMBRE : un décompte figé
        // casse à chaque ajout au formulaire pour une raison sans rapport avec
        // ce que le test contrôle. C'est ce qui s'est produit à l'arrivée des
        // zones couvertes.
        for (String champ : new List<String>{
                'Name', 'Contrat_Profession__c', 'Contrat_Situation__c',
                'Contrat_NIF__c', 'Contrat_Adresse__c', 'Contrat_CodePostal__c',
                'Contrat_Ville__c', 'Contrat_Provinces__c', 'Telephone__c', 'Email__c' }) {
            System.assert(etat.donnees.containsKey(champ),
                'Le formulaire doit remonter ' + champ + '.');
        }
        System.assertEquals('Test Previsiteur', etat.donnees.get('Name'));
    }

    /* ── Rôle Installateur ───────────────────────────────────────────────── */

    /** Le prévisiteur a son contrat : l'état le dit au composant. */
    @isTest
    static void previsiteurAUnContratDisponible() {
        LC027_TestFactory.previsiteur('token-role-prev');

        LC027_GestionContrat.EtatContrat etat = LC027_GestionContrat.getContrat('token-role-prev');

        System.assertEquals('Pre-visiteur', etat.role);
        System.assertEquals(true, etat.contratDisponible);
    }

    /**
     * L'installateur accède au formulaire, avec les champs de son rôle.
     *
     * contratDisponible SUIT LC027_Roles.CONTRAT_PAR_ROLE, sans supposer sa
     * valeur : le contrat de l'installateur peut être branché, retiré ou
     * remplacé sans que ce test soit à réécrire.
     */
    @isTest
    static void installateurLitSonFormulaire() {
        LC027_TestFactory.installateur('token-inst-lecture');

        Test.startTest();
        LC027_GestionContrat.EtatContrat etat = LC027_GestionContrat.getContrat('token-inst-lecture');
        Test.stopTest();

        System.assertEquals('Installateur', etat.role);
        System.assertEquals(LC027_Roles.contratDisponible(LC027_Roles.INSTALLATEUR), etat.contratDisponible,
            'L etat doit refleter la configuration du role.');
        System.assertEquals('Test Installateur', etat.donnees.get('Name'));
    }

    /** Principe de saisie identique : ses champs autorisés s'enregistrent. */
    @isTest
    static void installateurEnregistreSesInfos() {
        LC027_TestFactory.installateur('token-inst-ecriture');

        Test.startTest();
        LC027_GestionContrat.EtatContrat etat =
            LC027_GestionContrat.enregistrerInfos('token-inst-ecriture', donnees());
        Test.stopTest();

        System.assertEquals('12345678Z', etat.donnees.get('Contrat_NIF__c'));
        System.assertEquals('Madrid', etat.donnees.get('Contrat_Ville__c'));
    }

    /**
     * Envoi en signature de l'installateur, selon la configuration du rôle :
     *   - sans contrat : REFUSÉ avant tout callout ni archivage ;
     *   - avec contrat : même cycle que le prévisiteur (Attente signature).
     */
    @isTest
    static void installateurEnvoiSelonConfiguration() {
        Campaign c = LC027_TestFactory.installateur('token-inst-envoi');
        Test.setMock(HttpCalloutMock.class, new MockYousign());
        Boolean disponible = LC027_Roles.contratDisponible(LC027_Roles.INSTALLATEUR);

        String erreur;
        Test.startTest();
        try {
            LC027_GestionContrat.envoyerEnSignature('token-inst-envoi',
                LC027_TestFactory.pdfFactice(), LC027_TestFactory.reglagesSignature());
        } catch (Exception e) {
            erreur = e.getMessage();
        }
        Test.stopTest();

        String statut = [SELECT StatutContrat__c FROM Campaign WHERE Id = :c.Id].StatutContrat__c;
        if (disponible) {
            System.assertEquals(null, erreur, 'Un role avec contrat doit pouvoir l envoyer.');
            System.assertEquals('Attente signature', statut);
        } else {
            System.assertEquals(LC027_GestionContrat.MESSAGE_CONTRAT_INDISPONIBLE, erreur);
            System.assertEquals(0, [SELECT COUNT() FROM ContentVersion],
                'Aucun document ne doit etre archive.');
            System.assertEquals('En cours de generation', statut);
        }
    }

    /** Modèle PDF de l'installateur : servi s'il est configuré, refusé sinon. */
    @isTest
    static void installateurModeleSelonConfiguration() {
        LC027_TestFactory.installateur('token-inst-modele');
        Boolean disponible = LC027_Roles.contratDisponible(LC027_Roles.INSTALLATEUR);

        String erreur;
        String modele;
        Test.startTest();
        try {
            modele = LC027_GestionContrat.getContratBase64('token-inst-modele');
        } catch (Exception e) {
            erreur = e.getMessage();
        }
        Test.stopTest();

        if (disponible) {
            System.assert(String.isNotBlank(modele), 'Le modele configure doit etre servi.');
        } else {
            System.assertEquals(LC027_GestionContrat.MESSAGE_CONTRAT_INDISPONIBLE, erreur);
        }
    }

    /* ── Nombre de prévisites : prévisiteur espagnol uniquement ────────────── */

    @isTest
    static void nombrePrevisitesEnregistrePourLEspagne() {
        LC027_TestFactory.previsiteur('token-nombre-es');

        Test.startTest();
        LC027_GestionContrat.EtatContrat etat =
            LC027_GestionContrat.enregistrerInfos('token-nombre-es', donnees());
        Test.stopTest();

        System.assertEquals('Espagne', etat.pays);
        System.assertEquals('6 à 10', etat.donnees.get('NombrePrevisites__c'));
    }

    @isTest
    static void nombrePrevisitesIgnoreHorsEspagne() {
        Campaign c = LC027_TestFactory.previsiteur('token-nombre-fr');
        c.Pays__c = 'France';
        update c;

        Test.startTest();
        LC027_GestionContrat.EtatContrat etat =
            LC027_GestionContrat.enregistrerInfos('token-nombre-fr', donnees());
        Test.stopTest();

        System.assertEquals('France', etat.pays);
        System.assertEquals(null, etat.donnees.get('NombrePrevisites__c'),
            'Champ reserve a l Espagne : ignore pour un autre pays.');
        System.assertEquals('12345678Z', etat.donnees.get('Contrat_NIF__c'),
            'Les autres champs sont enregistres normalement.');
    }

    /* ── Écriture ────────────────────────────────────────────────────────── */

    @isTest
    static void enregistrerInfosEcritLesChampsAutorises() {
        LC027_TestFactory.previsiteur('token-ecriture');

        Test.startTest();
        LC027_GestionContrat.EtatContrat etat =
            LC027_GestionContrat.enregistrerInfos('token-ecriture', donnees());
        Test.stopTest();

        System.assertEquals('Maria Garcia', etat.donnees.get('Name'));
        System.assertEquals('12345678Z', etat.donnees.get('Contrat_NIF__c'));
        System.assertEquals('Madrid', etat.donnees.get('Contrat_Ville__c'));
        // SALESFORCE REORDONNE une multipicklist selon l'ordre de DECLARATION
        // de la liste de selection (alphabetique espagnol pour les provinces),
        // pas selon l'ordre recu : « Madrid;Burgos;Ávila » ressort en
        // « Ávila;Burgos;Madrid ».
        //
        // C'est precisement pour cela que handleBadge() reconstruit la valeur
        // depuis l'ordre des options de contratConfig plutot que depuis l'ordre
        // des clics : les deux produisent alors la meme chaine.
        System.assertEquals('Ávila;Burgos;Madrid', etat.donnees.get('Contrat_Provinces__c'),
            'Les provinces sont reordonnees selon la liste de selection.');
    }

    /**
     * Un champ hors liste blanche est IGNORÉ EN SILENCE, jamais écrit. Refuser
     * bruyamment renseignerait un attaquant sur les champs existants.
     */
    @isTest
    static void champHorsListeBlancheIgnore() {
        Campaign c = LC027_TestFactory.previsiteur('token-injection');

        Test.startTest();
        LC027_GestionContrat.enregistrerInfos('token-injection', JSON.serialize(
            new Map<String, Object>{
                'Contrat_NIF__c'   => 'OK123',
                'StatutContrat__c' => 'Signe',        // interdit : ferait sauter le verrou
                'Role__c'          => 'Régie'          // interdit : changerait de population
            }));
        Test.stopTest();

        Campaign apres = [SELECT StatutContrat__c, Role__c, Contrat_NIF__c
                          FROM Campaign WHERE Id = :c.Id];
        System.assertEquals('OK123', apres.Contrat_NIF__c, 'Le champ autorisé passe.');
        System.assertEquals('En cours de generation', apres.StatutContrat__c,
            'StatutContrat__c n\'est PAS modifiable depuis le portail.');
        System.assertEquals('Pre-visiteur', apres.Role__c,
            'Role__c n\'est PAS modifiable depuis le portail.');
    }

    @isTest
    static void contratSigneNestPlusModifiable() {
        LC027_TestFactory.previsiteur('token-signe', 'Signe', true);

        Test.startTest();
        try {
            LC027_GestionContrat.enregistrerInfos('token-signe', donnees());
            System.assert(false, 'Un contrat signé doit refuser toute modification.');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('signé'), e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void donneesInvalidesLeve() {
        LC027_TestFactory.previsiteur('token-json');

        Test.startTest();
        try {
            LC027_GestionContrat.enregistrerInfos('token-json', '{pas du json');
            System.assert(false, 'Un JSON invalide doit lever.');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('invalides'), e.getMessage());
        }
        Test.stopTest();
    }

    /* ── Un email, une personne ──────────────────────────────────────────── */

    /**
     * UN EMAIL DÉJÀ PRIS BLOQUE L'ENREGISTREMENT, quel que soit le rôle de
     * celui qui le détient — ici un installateur face à un pré-visiteur.
     *
     * Ce qui est en jeu n'est pas la propreté des données : l'email est le
     * login du compte Certiko et le destinataire Yousign. Deux campagnes
     * dessus, et la seconde retombe sur le compte de la première.
     */
    @isTest
    static void emailDejaPrisRefuseLEnregistrement() {
        LC027_TestFactory.previsiteur('token-email-pris');
        // L'installateur du kit porte un autre email : on lui fait saisir
        // celui du pré-visiteur.
        Campaign inst = LC027_TestFactory.installateur('token-email-voleur');
        String occupe = [SELECT Email__c FROM Campaign
                         WHERE CampaignToken__c = 'token-email-pris'].Email__c;

        Test.startTest();
        try {
            LC027_GestionContrat.enregistrerInfos('token-email-voleur',
                JSON.serialize(new Map<String, Object>{ 'Email__c' => occupe }));
            System.assert(false, 'Un email déjà pris doit être refusé.');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('déjà utilisé'), e.getMessage());
        }
        Test.stopTest();

        System.assertEquals('test.installateur@example.es',
            [SELECT Email__c FROM Campaign WHERE Id = :inst.Id].Email__c,
            'Le refus ne doit RIEN écrire : l email d origine reste en place.');
    }

    /**
     * La casse et les espaces ne font pas un email différent — sinon le
     * contrôle se contournerait en tapant une majuscule.
     */
    @isTest
    static void emailPrisMemeAvecUneCasseDifferente() {
        LC027_TestFactory.previsiteur('token-casse');
        LC027_TestFactory.installateur('token-casse-inst');

        Test.startTest();
        Boolean libre = LC027_GestionContrat.emailLibre(
            'token-casse-inst', '  TEST.PREVISITEUR@Example.ES  ');
        Test.stopTest();

        System.assertEquals(false, libre, 'Même adresse, autre casse : pas libre.');
    }

    /** Son PROPRE email reste évidemment disponible : on se resaisit soi-même. */
    @isTest
    static void sonProprementEmailResteLibre() {
        LC027_TestFactory.previsiteur('token-lui-meme');

        Test.startTest();
        Boolean libre = LC027_GestionContrat.emailLibre(
            'token-lui-meme', 'test.previsiteur@example.es');
        Test.stopTest();

        System.assertEquals(true, libre,
            'Une campagne ne doit pas se bloquer elle-même.');
    }

    /**
     * L'ENVOI EN SIGNATURE est le dernier rempart : le contrôle de la saisie
     * peut dater, et l'email avoir été pris entre-temps. Une fois le contrat
     * parti chez Yousign, le doublon ne se rattrape plus.
     */
    @isTest
    static void emailDejaPrisRefuseLEnvoiEnSignature() {
        Campaign prev = LC027_TestFactory.previsiteur('token-envoi-double');
        LC027_TestFactory.installateur('token-envoi-autre');
        // Le doublon est posé DIRECTEMENT en base, comme s'il était apparu
        // après que le pré-visiteur a rempli son formulaire.
        update new Campaign(Id = prev.Id, Email__c = 'test.installateur@example.es');

        Test.startTest();
        try {
            LC027_GestionContrat.envoyerEnSignature('token-envoi-double',
                LC027_TestFactory.pdfFactice(), LC027_TestFactory.reglagesSignature());
            System.assert(false, 'Un email en double doit refuser l\'envoi.');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('déjà utilisé'), e.getMessage());
        }
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM ContentVersion],
            'Rien ne doit partir chez Yousign quand l email est en double.');
    }

    /* ── Réglages de signature : obligatoires, sans repli ─────────────────── */

    @isTest
    static void reglagesAbsentsRefusentLEnvoi() {
        LC027_TestFactory.previsiteur('token-sans-reglages');

        Test.startTest();
        try {
            LC027_GestionContrat.envoyerEnSignature(
                'token-sans-reglages', LC027_TestFactory.pdfFactice(), null);
            System.assert(false, 'Des réglages absents doivent refuser l\'envoi.');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Réglages'), e.getMessage());
        }
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM ContentVersion],
            'Aucun document ne doit être archivé si l\'envoi est refusé.');
    }

    /**
     * Position de signature manquante : l'envoi est refusé plutôt que de
     * retomber sur YOUSIGN_CHAMP_SIGNATURE, qui vaut « page 1 » et ferait signer
     * le contrat au mauvais endroit. Un envoi refusé se corrige, pas un contrat
     * mal signé.
     */
    @isTest
    static void positionSignatureManquanteRefuseLEnvoi() {
        LC027_TestFactory.previsiteur('token-sans-position');

        Test.startTest();
        try {
            LC027_GestionContrat.envoyerEnSignature('token-sans-position',
                LC027_TestFactory.pdfFactice(),
                JSON.serialize(new Map<String, Object>{ 'langue' => 'es' }));
            System.assert(false, 'Une position absente doit refuser l\'envoi.');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Position'), e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void pdfVideRefuseLEnvoi() {
        LC027_TestFactory.previsiteur('token-pdf-vide');

        Test.startTest();
        try {
            LC027_GestionContrat.envoyerEnSignature(
                'token-pdf-vide', '', LC027_TestFactory.reglagesSignature());
            System.assert(false, 'Un PDF vide doit refuser l\'envoi.');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('vide'), e.getMessage());
        }
        Test.stopTest();
    }

    /* ── Envoi en signature ──────────────────────────────────────────────── */

    @isTest
    static void envoiEnSignatureBasculeLeStatut() {
        Campaign c = LC027_TestFactory.previsiteur('token-envoi');
        Test.setMock(HttpCalloutMock.class, new MockYousign());

        Test.startTest();
        LC027_GestionContrat.EtatContrat etat = LC027_GestionContrat.envoyerEnSignature(
            'token-envoi', LC027_TestFactory.pdfFactice(), LC027_TestFactory.reglagesSignature());
        Test.stopTest();

        System.assertEquals('Attente signature', etat.statut);
        System.assertEquals(true, etat.documentDisponible,
            'Le contrat archivé doit être consultable dès l\'envoi.');

        Campaign apres = [SELECT YS_Demande_Id__c, YS_Contrat_Doc_Id__c, StatutContrat__c,
                                 YS_Message_Erreur__c
                          FROM Campaign WHERE Id = :c.Id];
        System.assertEquals('ys-demande-123', apres.YS_Demande_Id__c);
        System.assertNotEquals(null, apres.YS_Contrat_Doc_Id__c,
            'Sans ce pointeur, le portail ne saurait pas retrouver le document.');
        System.assertEquals(null, apres.YS_Message_Erreur__c);

        System.assertEquals(1, [SELECT COUNT() FROM ContentVersion],
            'Le contrat rempli doit être archivé sur la campagne.');
    }

    @isTest
    static void echecYousignTraceLErreurSansPerdreLaSaisie() {
        Campaign c = LC027_TestFactory.previsiteur('token-echec');
        Test.setMock(HttpCalloutMock.class, new MockYousignErreur());

        Test.startTest();
        try {
            LC027_GestionContrat.envoyerEnSignature('token-echec',
                LC027_TestFactory.pdfFactice(), LC027_TestFactory.reglagesSignature());
            System.assert(false, 'Un échec Yousign doit remonter au composant.');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('impossible'), e.getMessage());
        }
        Test.stopTest();

        Campaign apres = [SELECT StatutContrat__c, YS_Message_Erreur__c
                          FROM Campaign WHERE Id = :c.Id];
        System.assertEquals('En cours de generation', apres.StatutContrat__c,
            'Le statut ne bascule pas sur un échec : le pré-visiteur doit pouvoir réessayer.');
        System.assertNotEquals(null, apres.YS_Message_Erreur__c,
            'L\'échec doit laisser une trace, sinon il est invisible.');
    }

    /* ── Consultation du contrat archivé ─────────────────────────────────── */

    @isTest
    static void contratStockeIntrouvableLeve() {
        LC027_TestFactory.previsiteur('token-sans-doc');

        Test.startTest();
        try {
            LC027_GestionContrat.getContratStockeBase64('token-sans-doc');
            System.assert(false, 'Sans document joint, la lecture doit lever.');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Aucun contrat'), e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void contratStockeRelu() {
        LC027_TestFactory.previsiteur('token-relecture');
        Test.setMock(HttpCalloutMock.class, new MockYousign());

        Test.startTest();
        LC027_GestionContrat.envoyerEnSignature('token-relecture',
            LC027_TestFactory.pdfFactice(), LC027_TestFactory.reglagesSignature());
        String base64 = LC027_GestionContrat.getContratStockeBase64('token-relecture');
        Test.stopTest();

        System.assertNotEquals(null, base64);
        System.assert(base64.length() > 0, 'Le contrat archivé doit être relisible.');
    }
}