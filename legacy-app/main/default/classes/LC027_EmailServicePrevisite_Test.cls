/**
 * Tests de LC027_EmailServicePrevisite.
 *
 * L'ENVOI RÉEL n'est pas testé : il exige un EmailTemplate et une
 * OrgWideEmailAddress présents dans l'org, deux dépendances que le contexte de
 * test ne fournit pas et qu'un @isTest(SeeAllData=true) rendrait dépendant des
 * données de l'org — donc instable. Ce qui EST testé, ce sont les garde-fous :
 * ils portent la logique métier de la classe.
 */
@isTest
private class LC027_EmailServicePrevisite_Test {

    @isTest
    static void campagneInexistanteLeve() {
        Test.startTest();
        try {
            LC027_EmailServicePrevisite.sendPrevisiteEmail('701000000000000AAA');
            System.assert(false, 'Une campagne inexistante doit lever.');
        } catch (LC027_EmailServicePrevisite.PrevisiteEmailException e) {
            System.assert(e.getMessage().contains('introuvable'), e.getMessage());
        }
        Test.stopTest();
    }

    /**
     * Garde-fou central : ce template et cette adresse d'expédition ne
     * s'adressent qu'aux pré-visiteurs. Une erreur d'aiguillage enverrait à une
     * régie un mail la renvoyant vers le mauvais portail.
     */
    @isTest
    static void roleRegieRefuseLEnvoi() {
        Campaign regie = LC027_TestFactory.regie('token-mail-regie');

        Test.startTest();
        try {
            LC027_EmailServicePrevisite.sendPrevisiteEmail(regie.Id);
            System.assert(false, 'Une campagne de rôle Régie doit être refusée.');
        } catch (LC027_EmailServicePrevisite.PrevisiteEmailException e) {
            System.assert(e.getMessage().contains('Envoi refusé'), e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void emailAbsentLeve() {
        Campaign c = LC027_TestFactory.previsiteur('token-mail-vide');
        c.Email__c = null;
        update c;

        Test.startTest();
        try {
            LC027_EmailServicePrevisite.sendPrevisiteEmail(c.Id);
            System.assert(false, 'Une campagne sans email doit lever.');
        } catch (LC027_EmailServicePrevisite.PrevisiteEmailException e) {
            System.assert(e.getMessage().contains('Aucun email'), e.getMessage());
        }
        Test.stopTest();
    }

    /**
     * Rôle et email corrects : la classe va jusqu'à la recherche du template.
     * Qu'il soit trouvé ou non, l'exception reste du type attendu — c'est ce qui
     * permet à PrevisiteController de l'isoler sans faire échouer l'inscription.
     */
    @isTest
    static void erreurRemonteEnTypeDedie() {
        Campaign c = LC027_TestFactory.previsiteur('token-mail-ok');

        Test.startTest();
        try {
            LC027_EmailServicePrevisite.sendPrevisiteEmail(c.Id);
        } catch (LC027_EmailServicePrevisite.PrevisiteEmailException e) {
            System.assert(true, 'Type attendu : jamais AuraHandledException en contexte REST.');
        } catch (Exception e) {
            System.assert(false, 'Type inattendu : ' + e.getTypeName() + ' - ' + e.getMessage());
        }
        Test.stopTest();
    }
}