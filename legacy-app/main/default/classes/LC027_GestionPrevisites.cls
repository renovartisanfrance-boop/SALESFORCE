/**
 * LC027_GestionPrevisites — Contrôleur du portail « Gestion Prévisites ».
 *
 * Classe DÉDIÉE à ce site : elle ne réutilise rien de LC020_GestionCampagnes,
 * dont les méthodes portent la logique propre au portail Campagnes (régies,
 * campagnes filles, accès réduit, produits). Seul l'objet Campagne est commun.
 *
 * Différence de contrat volontaire avec LC020_GestionCampagnes.getCampaignByToken :
 * celle-ci lève une AuraHandledException indifférenciée, si bien que le portail
 * Campagnes ne peut pas distinguer un token inconnu d'un compte désactivé — il
 * redirige dans les deux cas. Ici on renvoie un STATUT explicite, parce que le
 * cahier des charges demande un écran différent par cas.
 */
public without sharing class LC027_GestionPrevisites {

    // Rôles admis : voir LC027_Roles, seule définition côté serveur.

    public class ResultatAcces {
        /** OK | TOKEN_MANQUANT | INTROUVABLE | ROLE_INVALIDE | DESACTIVE */
        @AuraEnabled public String statut;
        /** Renseignée UNIQUEMENT si statut = OK : aucune donnée ne fuit sur erreur. */
        @AuraEnabled public Campaign previsiteur;
    }

    /**
     * Contrôle d'accès unique du portail : token + rôle du portail
     * (Pré-visiteur ou Installateur, voir LC027_Roles).
     *
     * Ordre des contrôles — il détermine le message affiché quand plusieurs cas
     * se cumulent (ex. campagne Régie ET désactivée) :
     *   1. token vide      -> TOKEN_MANQUANT
     *   2. token inconnu   -> INTROUVABLE
     *   3. rôle hors portail    -> ROLE_INVALIDE  (le compte n'appartient pas à ce site)
     *   4. IsActive = false     -> DESACTIVE     (il y appartient, mais est suspendu)
     * Le rôle passe avant l'activation à dessein : dire « votre compte est
     * désactivé » à une régie lui laisserait croire qu'elle a sa place ici.
     */
    @AuraEnabled
    public static ResultatAcces getPrevisiteurByToken(String campaignToken) {
        ResultatAcces res = new ResultatAcces();

        if (String.isBlank(campaignToken)) {
            res.statut = 'TOKEN_MANQUANT';
            return res;
        }

        List<Campaign> campagnes = [
            // StatutContrat__c pilote ce que le conteneur affiche : tant que le
            // contrat n'est pas « Signe », le portail ne montre QUE l'écran de
            // contrat. Il est donc lu ici, à l'entrée, et non par un second appel.
            SELECT Id, Name, IsActive, Role__c, Pays__c, StatutContrat__c,
                   // Date de signature du contrat : affichee en permanence dans
                   // l'encart d'information de la facturation previsiteur.
                   YS_Date_Signature__c,
                   // Identite contractuelle, affichee en permanence dans l'encart
                   // de la facturation : elle vient de la meme requete d'entree,
                   // aucun appel serveur supplementaire.
                   NomSociete__c, Contrat_NIF__c, Contrat_Profession__c,
                   Email__c, Telephone__c, ParentId, Parent.Name
            FROM Campaign
            WHERE CampaignToken__c = :campaignToken
            LIMIT 1
        ];

        if (campagnes.isEmpty()) {
            res.statut = 'INTROUVABLE';
            return res;
        }

        Campaign c = campagnes[0];

        if (!LC027_Roles.estRolePortail(c.Role__c)) {
            res.statut = 'ROLE_INVALIDE';
            return res;
        }

        if (c.IsActive != true) {
            res.statut = 'DESACTIVE';
            return res;
        }

        // Trace de connexion : uniquement sur un accès réellement accordé, sinon
        // un token révoqué continuerait d'alimenter la date de dernière connexion.
        try {
            update new Campaign(Id = c.Id, DateDerniereConnexion__c = System.now());
        } catch (DmlException e) {
            // L'horodatage est accessoire : son échec ne doit pas bloquer l'accès.
            System.debug(LoggingLevel.WARN, 'MAJ DateDerniereConnexion__c échouée : ' + e.getMessage());
        }

        res.statut = 'OK';
        res.previsiteur = c;
        return res;
    }
}