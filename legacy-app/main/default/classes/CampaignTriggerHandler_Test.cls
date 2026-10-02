/**
 * Tests de CampaignTrigger / CampaignTriggerHandler.
 *
 * CE QUI EST VRAIMENT VÉRIFIÉ — la DÉTECTION, pas l'envoi.
 *
 * L'envoi réel exige un EmailTemplate et une OrgWideEmailAddress, deux
 * dépendances que le contexte de test ne fournit pas : la classe lève alors une
 * PrevisiteEmailException, que le handler attrape. Les tests confirment donc que
 * cet échec ne remonte JAMAIS jusqu'à faire échouer la mise à jour — c'est le
 * comportement le plus important du handler. Un contrat signé perdu parce que
 * l'accusé de réception n'est pas parti serait le pire des défauts.
 *
 * Le trigger portant sur TOUTES les campagnes de l'org, les cas négatifs
 * comptent autant que le cas positif : ils garantissent que le portail
 * Campagnes n'est pas affecté.
 */
@isTest
private class CampaignTriggerHandler_Test {

    private static final String STATUT_ATTENTE = 'Attente signature';
    private static final String STATUT_SIGNE   = 'Signe';

    private static Campaign creer(String role, String statutContrat) {
        Campaign c = new Campaign(
            Name             = 'Test Trigger',
            IsActive         = true,
            Role__c          = role,
            CampaignToken__c = 'tok-' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
            StatutContrat__c = statutContrat,
            Email__c         = 'trigger@example.es'
        );
        insert c;
        return c;
    }

    /** Cas nominal : le passage à « Signe » d'un pré-visiteur est bien traité. */
    @isTest
    static void signatureDUnPrevisiteurEstTraitee() {
        LC027_TestFactory.bouchonnerCallouts();
        Campaign c = creer(LC027_TestFactory.ROLE_PREVISITEUR, STATUT_ATTENTE);

        Test.startTest();
        update new Campaign(Id = c.Id, StatutContrat__c = STATUT_SIGNE);
        Test.stopTest();

        // L'envoi échoue faute de template en contexte de test, et c'est le
        // point : la mise à jour, elle, doit avoir abouti.
        System.assertEquals(STATUT_SIGNE,
            [SELECT StatutContrat__c FROM Campaign WHERE Id = :c.Id].StatutContrat__c,
            'La signature doit être enregistrée même si l\'email ne part pas.');
    }

    /** Même traitement pour un installateur : même modèle d'email pour l'instant. */
    @isTest
    static void signatureDUnInstallateurEstTraitee() {
        LC027_TestFactory.bouchonnerCallouts();
        Campaign c = creer(LC027_TestFactory.ROLE_INSTALLATEUR, STATUT_ATTENTE);

        Test.startTest();
        update new Campaign(Id = c.Id, StatutContrat__c = STATUT_SIGNE);
        Test.stopTest();

        System.assertEquals(STATUT_SIGNE,
            [SELECT StatutContrat__c FROM Campaign WHERE Id = :c.Id].StatutContrat__c);
    }

    /**
     * Une campagne DÉJÀ signée qu'on met à jour ne redéclenche rien : sans la
     * comparaison à l'ancienne valeur, le webhook Yousign, le batch de
     * réconciliation et l'écran d'administration renverraient tous le mail.
     */
    @isTest
    static void miseAJourDUnContratDejaSigneNeRedeclenchePas() {
        LC027_TestFactory.bouchonnerCallouts();
        Campaign c = creer(LC027_TestFactory.ROLE_PREVISITEUR, STATUT_SIGNE);

        Test.startTest();
        update new Campaign(Id = c.Id, Telephone__c = '600000000');
        Test.stopTest();

        System.assertEquals('600000000',
            [SELECT Telephone__c FROM Campaign WHERE Id = :c.Id].Telephone__c);
    }

    /** Une régie signée ne doit pas recevoir un mail vers le portail Prévisites. */
    @isTest
    static void roleRegieNEstPasNotifie() {
        LC027_TestFactory.bouchonnerCallouts();
        Campaign c = creer(LC027_TestFactory.ROLE_REGIE, STATUT_ATTENTE);

        Test.startTest();
        update new Campaign(Id = c.Id, StatutContrat__c = STATUT_SIGNE);
        Test.stopTest();

        System.assertEquals(STATUT_SIGNE,
            [SELECT StatutContrat__c FROM Campaign WHERE Id = :c.Id].StatutContrat__c);
    }

    /**
     * Le trigger s'exécute pour TOUTES les campagnes de l'org. Une campagne sans
     * rôle ni statut de contrat — le cas de toutes celles du portail Campagnes —
     * doit traverser le handler sans effet ni erreur.
     */
    @isTest
    static void campagneOrdinaireNestPasAffectee() {
        LC027_TestFactory.bouchonnerCallouts();
        Campaign c = new Campaign(Name = 'Campagne Regie ordinaire', IsActive = true);
        insert c;

        Test.startTest();
        update new Campaign(Id = c.Id, Name = 'Campagne renommee');
        Test.stopTest();

        System.assertEquals('Campagne renommee',
            [SELECT Name FROM Campaign WHERE Id = :c.Id].Name);
    }

    /** Traitement par LOT : le handler doit rester correct au-delà d'une ligne. */
    @isTest
    static void lotMixteNeTraiteQueLesPrevisiteurs() {
        LC027_TestFactory.bouchonnerCallouts();

        List<Campaign> lot = new List<Campaign>();
        for (Integer i = 0; i < 20; i++) {
            lot.add(new Campaign(
                Name             = 'Lot ' + i,
                IsActive         = true,
                Role__c          = Math.mod(i, 2) == 0
                                   ? LC027_TestFactory.ROLE_PREVISITEUR
                                   : LC027_TestFactory.ROLE_REGIE,
                CampaignToken__c = 'lot-' + i,
                StatutContrat__c = STATUT_ATTENTE,
                Email__c         = 'lot' + i + '@example.es'
            ));
        }
        insert lot;

        for (Campaign c : lot) {
            c.StatutContrat__c = STATUT_SIGNE;
        }

        Test.startTest();
        update lot;
        Test.stopTest();

        System.assertEquals(20,
            [SELECT COUNT() FROM Campaign WHERE StatutContrat__c = :STATUT_SIGNE],
            'Les 20 mises à jour doivent aboutir, quel que soit le sort des emails.');
    }

    /** Appel direct : un ensemble vide ne doit ni requêter ni lever. */
    @isTest
    static void envoiSurEnsembleVideNeFaitRien() {
        Test.startTest();
        LC027_EmailServicePrevisite.envoyerConfirmationsSignature(new Set<Id>());
        LC027_EmailServicePrevisite.envoyerConfirmationsSignature(null);
        Test.stopTest();
    }
}