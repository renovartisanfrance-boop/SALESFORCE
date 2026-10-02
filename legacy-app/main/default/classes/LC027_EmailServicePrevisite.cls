/**
 * LC027_EmailServicePrevisite — Envoi du lien d'accès aux PRE-VISITEURS.
 *
 * Service DEDIE : LC020_EmailService n'est pas touché. Son arbre de décision
 * (ParentId, PeutCreerREGIE__c, AvoirAccesCEE__c, AccesReduit__c + Source__c)
 * choisit un template parmi sept selon la place de la régie dans la hiérarchie
 * Campagnes. Aucune de ces notions n'existe ici : un seul envoi, un seul template.
 *
 * Le service refuse d'envoyer si la campagne n'a pas le rôle Pré-visiteur. C'est
 * un garde-fou volontaire : ce template et cette adresse d'expédition ne
 * s'adressent qu'aux pré-visiteurs, et une erreur d'aiguillage enverrait à une
 * régie un mail la renvoyant vers le mauvais portail.
 *
 * Les erreurs remontent en PrevisiteEmailException et NON en AuraHandledException :
 * l'appelant est PrevisiteController, un contexte REST où une AuraHandledException
 * devient une System.LimitException, donc un 500 opaque sur une campagne pourtant
 * créée. C'est le défaut que CampagneController doit neutraliser par un try/catch.
 */
public without sharing class LC027_EmailServicePrevisite {

    public class PrevisiteEmailException extends Exception {}

    /*
     * Rôles concernés : ceux du portail, définis dans LC027_Roles. Les deux rôles
     * reçoivent pour l'instant les MÊMES modèles d'email ; le jour où ils
     * divergent, c'est ici qu'un aiguillage sur le rôle viendra choisir le
     * modèle, sans toucher aux appelants.
     */

    /**
     * Envoie le lien d'accès au portail Prévisites.
     *
     * @param campaignId Campagne de rôle « Pre-visiteur ».
     * @return Message de confirmation.
     * @throws PrevisiteEmailException campagne introuvable, rôle incorrect, email
     *         absent, template ou adresse d'expédition manquants.
     */
    public static String sendPrevisiteEmail(String campaignId) {
        try {
            List<Campaign> campagnes = [
                SELECT Id, Name, Email__c, CampaignToken__c, Role__c
                FROM Campaign
                WHERE Id = :campaignId
                LIMIT 1
            ];
            if (campagnes.isEmpty()) {
                throw new PrevisiteEmailException('Campagne ' + campaignId + ' introuvable.');
            }
            Campaign camp = campagnes[0];

            if (!LC027_Roles.estRolePortail(camp.Role__c)) {
                throw new PrevisiteEmailException(
                    'Envoi refusé : la campagne ' + camp.Id + ' a le rôle « ' + camp.Role__c
                    + ' », hors portail Prévisites.'
                );
            }

            if (String.isBlank(camp.Email__c)) {
                throw new PrevisiteEmailException('Aucun email renseigné sur la campagne ' + camp.Id + '.');
            }

            String fullUrl = Label.RENOV_Previsite_Base_URL + '?c__code=' + camp.CampaignToken__c;

            String templateDevName = Label.Email_Template_Previsiteur;
            List<EmailTemplate> templates = [
                SELECT Id, Subject, Body, HtmlValue
                FROM EmailTemplate
                WHERE DeveloperName = :templateDevName
                LIMIT 1
            ];
            if (templates.isEmpty()) {
                throw new PrevisiteEmailException('Template email « ' + templateDevName + ' » introuvable.');
            }
            EmailTemplate template = templates[0];

            // Deux jetons seulement : le nom du pré-visiteur et le lien de connexion.
            // Pas de __LOGIN__ ni de __PASS__ — l'accès au portail se fait par le
            // token de l'URL, il n'y a pas de mot de passe.
            String htmlBody = remplacerJetons(template.HtmlValue, fullUrl, camp.Name);
            String textBody = remplacerJetons(template.Body, fullUrl, camp.Name);

            // Expéditeur espagnol : le portail pré-visiteurs n'existe qu'en Espagne
            // pour l'instant. Le jour où un marché français s'ouvre, c'est ici qu'un
            // aiguillage sur Pays__c viendra — pas dans LC020_EmailService.
            String adresseExpediteur = Label.Email_ExpCampagnesRDV_ES;
            List<OrgWideEmailAddress> owa = [
                SELECT Id FROM OrgWideEmailAddress WHERE Address = :adresseExpediteur LIMIT 1
            ];
            if (owa.isEmpty()) {
                throw new PrevisiteEmailException(
                    'Adresse expéditeur « ' + adresseExpediteur + ' » absente des adresses à l\'échelle de l\'organisation.'
                );
            }

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setOrgWideEmailAddressId(owa[0].Id);
            mail.setToAddresses(new List<String>{ camp.Email__c });
            mail.setSubject(template.Subject);
            mail.setHtmlBody(htmlBody);
            mail.setPlainTextBody(textBody);
            mail.setSaveAsActivity(true);

            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });

            return 'Email envoyé avec succès à ' + camp.Email__c;

        } catch (PrevisiteEmailException e) {
            throw e;
        } catch (Exception e) {
            throw new PrevisiteEmailException('Erreur lors de l\'envoi de l\'email : ' + e.getMessage());
        }
    }

    /**
     * Confirmation de signature — envoyée par CampaignTriggerHandler dès que
     * StatutContrat__c passe à « Signe ».
     *
     * EN MASSE, contrairement à sendPrevisiteEmail : appelée depuis un trigger,
     * elle peut recevoir plusieurs campagnes d'un même lot. Le template et
     * l'adresse d'expédition sont donc lus UNE fois, hors de la boucle, et tous
     * les messages partent en un seul Messaging.sendEmail — trois requêtes et un
     * envoi, quel que soit le volume.
     *
     * Modèle DISTINCT de celui de l'accès initial : le premier active un espace,
     * celui-ci accuse réception d'un engagement contractuel. Les confondre
     * enverrait « votre espace est activé » à quelqu'un qui vient de signer.
     *
     * Les campagnes sans email ou de rôle incorrect sont IGNORÉES en silence :
     * un lot ne doit pas échouer en entier à cause d'une ligne.
     */
    public static void envoyerConfirmationsSignature(Set<Id> campagneIds) {
        if (campagneIds == null || campagneIds.isEmpty()) {
            return;
        }

        List<Campaign> campagnes = [
            SELECT Id, Name, Email__c, CampaignToken__c, Role__c
            FROM Campaign
            WHERE Id IN :campagneIds
              AND Role__c IN :LC027_Roles.ROLES_PORTAIL
              AND Email__c != null
        ];
        if (campagnes.isEmpty()) {
            return;
        }

        String templateDevName = Label.Email_Template_Contrat_Signe;
        List<EmailTemplate> templates = [
            SELECT Id, Subject, Body, HtmlValue
            FROM EmailTemplate WHERE DeveloperName = :templateDevName LIMIT 1
        ];
        if (templates.isEmpty()) {
            throw new PrevisiteEmailException('Template email « ' + templateDevName + ' » introuvable.');
        }
        EmailTemplate template = templates[0];

        List<OrgWideEmailAddress> owa = [
            SELECT Id FROM OrgWideEmailAddress
            WHERE Address = :Label.Email_ExpCampagnesRDV_ES LIMIT 1
        ];
        if (owa.isEmpty()) {
            throw new PrevisiteEmailException(
                'Adresse expéditeur « ' + Label.Email_ExpCampagnesRDV_ES + ' » introuvable.');
        }

        List<Messaging.SingleEmailMessage> messages = new List<Messaging.SingleEmailMessage>();
        for (Campaign camp : campagnes) {
            String fullUrl = Label.RENOV_Previsite_Base_URL + '?c__code=' + camp.CampaignToken__c;

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setOrgWideEmailAddressId(owa[0].Id);
            mail.setToAddresses(new List<String>{ camp.Email__c });
            mail.setSubject(template.Subject);
            mail.setHtmlBody(remplacerJetons(template.HtmlValue, fullUrl, camp.Name));
            mail.setPlainTextBody(remplacerJetons(template.Body, fullUrl, camp.Name));
            mail.setSaveAsActivity(true);
            messages.add(mail);
        }

        Messaging.sendEmail(messages);
    }

    private static String remplacerJetons(String corps, String url, String nom) {
        if (String.isBlank(corps)) {
            return '';
        }
        return corps
            .replace('__URL__', url == null ? '' : url)
            .replace('__RegieName__', nom == null ? '' : nom);
    }
}