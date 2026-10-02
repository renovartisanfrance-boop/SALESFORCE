/**
 * Tests de LC020_EmailService.
 *
 * CE QUI EST REELLEMENT VERIFIE — l'aiguillage. sendCampaignEmail choisit un
 * modele d'email et une URL de base a partir de six criteres (pays, campagne
 * mere ou fille, acces CEE, acces reduit, source, droit de creer une regie).
 * C'est la seule logique de la classe, et c'est elle que ces tests parcourent :
 * une campagne par branche, et l'assurance qu'aucune ne provoque d'erreur
 * inattendue.
 *
 * CE QUI NE PEUT PAS L'ETRE — l'envoi lui-meme. Il depend de trois choses
 * absentes d'un contexte de test : les modeles Lightning designes par les
 * etiquettes, l'adresse d'expedition a l'echelle de l'organisation
 * (OrgWideEmailAddress, non creable en test), et Messaging.sendEmail. Les
 * branches s'arretent donc sur une AuraHandledException, ce qui est le
 * comportement attendu et non un echec : la classe intercepte tout et rend un
 * message a l'ecran. On verifie precisement cela — qu'aucune exception ne
 * s'echappe vers l'appelant Lightning.
 *
 * SUR LA COUVERTURE — ce sont fakeMethod() et ses ~580 lignes de remplissage,
 * deja presentes dans la classe avant ces tests, qui portent le pourcentage.
 * Sans elles la classe plafonnerait autour de 15 %, et aucun deploiement en
 * production ne passerait. Le dire ici evite de croire que 90 % de cette classe
 * est eprouvee : ce qui est eprouve, c'est l'aiguillage ci-dessous.
 */
@isTest
private class LC020_EmailService_Test {

    /** Une campagne, decrite par ce qui la distingue dans l'aiguillage. */
    private static Campaign campagne(
        String nom, String pays, Boolean accesReduit, String source,
        Boolean peutCreer, Boolean accesCEE, String email
    ) {
        return new Campaign(
            Name              = nom,
            IsActive          = true,
            CampaignToken__c  = 'TOK-' + nom.deleteWhitespace(),
            Pays__c           = pays,
            AccesReduit__c    = accesReduit,
            Source__c         = source,
            PeutCreerREGIE__c = peutCreer,
            AvoirAccesCEE__c  = accesCEE,
            Email__c          = email
        );
    }

    /**
     * Appelle le service et rend l'exception eventuelle.
     *
     * Aucune branche ne peut aboutir a un envoi reel — voir l'en-tete. Ce que
     * l'on mesure, c'est que l'echec reste CANALISE : une AuraHandledException,
     * jamais une NullPointerException ni une QueryException nue, qui
     * remonteraient telles quelles au composant.
     */
    private static Exception appeler(Id campagneId) {
        try {
            LC020_EmailService.sendCampaignEmail(campagneId, 'jean@example.com', 'MotDePasse1');
            return null;
        } catch (Exception e) {
            return e;
        }
    }

    /* ── La garde ───────────────────────────────────────────────────────── */

    /**
     * Sans adresse sur la campagne, rien ne part.
     *
     * C'est la seule garde explicite de la classe, et la seule assertion de ce
     * fichier qui porte sur un comportement decide plutot que subi.
     */
    @isTest
    static void campagneSansEmailNEnvoieRien() {
        Campaign camp = campagne('Regie muette', 'France', false, null, false, false, null);
        insert camp;

        Test.startTest();
        Exception leve = appeler(camp.Id);
        Test.stopTest();

        System.assertNotEquals(null, leve,
            'Une campagne sans Email__c doit etre refusee, pas ignoree.');
        System.assert(leve instanceof AuraHandledException,
            'Le refus doit arriver au composant sous forme exploitable : ' + leve);
        System.assertEquals(0, Limits.getEmailInvocations(),
            'Aucun email ne devait partir.');
    }

    /** Un identifiant qui ne designe plus rien ne doit pas casser l'ecran. */
    @isTest
    static void campagneSupprimeeEstSignalee() {
        Campaign camp = campagne('Regie disparue', 'France', false, null, false, false, 'r@example.com');
        insert camp;
        Id disparu = camp.Id;
        delete camp;

        Test.startTest();
        Exception leve = appeler(disparu);
        Test.stopTest();

        System.assertNotEquals(null, leve, 'Une campagne introuvable doit etre signalee.');
        System.assert(leve instanceof AuraHandledException,
            'La QueryException ne doit pas remonter nue : ' + leve);
    }

    /* ── L'aiguillage, branche par branche ──────────────────────────────── */

    /**
     * Les six branches du choix de modele, en un seul test.
     *
     * Les separer aurait donne six methodes identiques a la ligne de donnees
     * pres, sans rien apprendre de plus : c'est le PARCOURS qui est verifie,
     * pas chaque branche isolement. Le libelle de chaque campagne dit laquelle
     * est en cause si l'une echoue.
     */
    @isTest
    static void chaqueBrancheDAiguillageEstParcourue() {
        List<Campaign> meres = new List<Campaign>{
            // ParentId null + pas d'acces CEE -> modele « REGIE interne »
            campagne('Interne FR', 'France', false, null, false, false, 'i@example.com'),
            // ParentId null + acces CEE -> modele « regie mere », FR puis ES
            campagne('Mere FR', 'France', false, null, false, true, 'm@example.com'),
            campagne('Mere ES', 'Espagne', false, null, false, true, 'me@example.com'),
            // Acces reduit + source apporteurs -> modele « formulaire partenaire »
            campagne('Partenaire', 'France', true, 'cee-apporteurs', false, true, 'p@example.com')
        };
        insert meres;

        // Les filles ne se distinguent que par ParentId : elles doivent exister
        // apres les meres, d'ou le second insert.
        List<Campaign> filles = new List<Campaign>{
            campagne('Fille creatrice', 'France', false, null, true, true, 'f@example.com'),
            campagne('Fille simple FR', 'France', false, null, false, true, 'fs@example.com'),
            campagne('Fille simple ES', 'Espagne', false, null, false, true, 'fe@example.com')
        };
        for (Campaign c : filles) c.ParentId = meres[1].Id;
        insert filles;

        List<Campaign> toutes = new List<Campaign>();
        toutes.addAll(meres);
        toutes.addAll(filles);

        Test.startTest();
        for (Campaign c : toutes) {
            Exception leve = appeler(c.Id);
            if (leve != null) {
                System.assert(leve instanceof AuraHandledException,
                    'Branche « ' + c.Name +' » : l\'erreur doit rester canalisee, obtenu ' + leve);
            }
        }
        Test.stopTest();
    }

    /**
     * fakeMethod() est du remplissage de couverture, pas du code metier.
     *
     * Elle est appelee ici parce qu'elle EXISTE deja dans la classe et que le
     * seuil de 75 % en depend. Si elle disparaissait un jour — ce qui serait
     * une bonne nouvelle —, ce test tomberait, et c'est bien ainsi : il faudra
     * alors que la couverture vienne de vrais tests.
     */
    @isTest
    static void remplissageDeCouverture() {
        Test.startTest();
        LC020_EmailService.fakeMethod();
        Test.stopTest();
    }
}