/**
 * LC027_CertikoCompteService — ouvre le compte Certiko du pré-visiteur quand
 * son contrat est signé.
 *
 * QUAND — au passage de Campaign.StatutContrat__c à « Signe », et pour le seul
 * rôle PRÉ-VISITEUR : c'est lui qui remplit le relevé de visite technique chez
 * Certiko. Un installateur signé n'a rien à y faire.
 *
 * DANS QUEL ORDRE — l'équipe D'ABORD, le compte ensuite. Certiko affecte les
 * dossiers à une ÉQUIPE, pas à une personne : sans équipe propre, tous les
 * pré-visiteurs verraient les mêmes dossiers. D'où « Equipo <nom> », une par
 * pré-visiteur, et le compte créé dedans.
 *
 * CE QU'ON GARDE — l'IDENTIFIANT de l'équipe autant que son nom. Le nom sert à
 * l'affichage ; c'est l'identifiant qui part dans la colonne `_equipe_poseur`
 * des dossiers, parce qu'une équipe peut être renommée chez Certiko sans que
 * nous le sachions, et que les dossiers partiraient alors à côté.
 *
 * EN ASYNCHRONE, et pas par goût : la signature vient d'écrire la campagne, et
 * Salesforce refuse un appel sortant après une écriture dans la même
 * transaction. La file d'attente reprend la main après validation.
 *
 * CE QUI NE DOIT JAMAIS ARRIVER — qu'un échec Certiko annule la signature. Le
 * contrat est signé, c'est un fait juridique ; le compte est un confort qui se
 * rattrape. Toute exception est donc attrapée et écrite dans
 * CERTIKO_Compte_Erreur__c, où elle reste visible.
 */
public without sharing class LC027_CertikoCompteService {

    /**
     * Mot de passe posé à la création, LE MÊME POUR TOUS.
     *
     * Il n'ouvre que le relevé de visite technique chez Certiko — aucune donnée
     * Salesforce. Le pré-visiteur le lit dans son portail ; Certiko lui
     * demandera de le changer à la première connexion.
     */
    public static final String MOT_DE_PASSE_INITIAL = '0123456789';

    /** Préfixe du nom d'équipe. Espagnol : c'est la langue de la console. */
    private static final String PREFIXE_EQUIPE = 'Equipo ';

    /* ════════════════════════════════════════════════════════════════════════
       ENTRÉE
       ════════════════════════════════════════════════════════════════════════ */

    /**
     * Met l'ouverture des comptes en file d'attente.
     *
     * UN SEUL travail pour TOUTES les campagnes, et non un par campagne : un
     * Queueable ne peut en enfiler qu'un seul, et la signature peut déjà
     * s'exécuter depuis un Queueable (webhook Yousign).
     */
    public static void ouvrirComptes(Set<Id> campagnes) {
        if (campagnes == null || campagnes.isEmpty() || Test.isRunningTest()) {
            // En test, la file ne part pas après un DML : l'ouverture se
            // vérifie directement sur ouvrirPour.
            return;
        }
        System.enqueueJob(new Ouverture(campagnes));
    }

    public class Ouverture implements Queueable, Database.AllowsCallouts {
        private Set<Id> campagnes;
        public Ouverture(Set<Id> campagnes) {
            this.campagnes = campagnes;
        }
        public void execute(QueueableContext contexte) {
            ouvrirPour(campagnes);
        }
    }

    /* ════════════════════════════════════════════════════════════════════════
       TRAITEMENT
       ════════════════════════════════════════════════════════════════════════ */

    /**
     * Ouvre le compte de chaque campagne, puis enregistre le résultat.
     *
     * Les campagnes sont traitées UNE PAR UNE et les erreurs isolées : un
     * pré-visiteur dont l'email est refusé ne doit pas priver les autres de
     * leur compte. Une seule écriture à la fin, pour ne pas multiplier les DML.
     */
    @TestVisible
    private static void ouvrirPour(Set<Id> campagnes) {
        List<Campaign> aMettreAJour = new List<Campaign>();
        for (Campaign camp : [
            SELECT Id, Name, Email__c, Telephone__c, Role__c, StatutContrat__c,
                   CERTIKO_User_Id__c, CERTIKO_Login__c, CERTIKO_Mot_De_Passe__c,
                   CERTIKO_Equipe__c, CERTIKO_Equipe_Id__c
            FROM Campaign WHERE Id IN :campagnes
        ]) {
            Campaign maj = ouvrirUnCompte(camp);
            if (maj != null) {
                aMettreAJour.add(maj);
            }
        }
        if (!aMettreAJour.isEmpty()) {
            // allOrNone = false : l'échec d'une campagne ne doit pas annuler
            // les comptes ouverts pour les autres.
            Database.update(aMettreAJour, false);
        }
    }

    /** @return la campagne à enregistrer, ou null s'il n'y a rien à changer. */
    private static Campaign ouvrirUnCompte(Campaign camp) {
        // Déjà ouvert : ne pas repasser par l'API. Une re-signature du même
        // contrat ne doit ni recréer, ni réinitialiser le mot de passe affiché.
        if (String.isNotBlank(camp.CERTIKO_User_Id__c)) {
            return null;
        }
        if (String.isBlank(camp.Email__c)) {
            return erreur(camp.Id, 'Email de la campagne absent.');
        }
        try {
            return ouvrirChezCertiko(camp);
        } catch (Exception e) {
            return erreur(camp.Id, e.getMessage());
        }
    }

    /**
     * Crée l'équipe puis le compte chez Certiko, et rend la campagne PRÊTE À
     * ENREGISTRER — champs de traçabilité compris.
     *
     * PARTAGÉE PAR LES DEUX CHEMINS d'ouverture : la signature (file d'attente)
     * et la reprise manuelle depuis l'écran d'administration. Ils écrivaient
     * les mêmes champs chacun de leur côté, avec chacun sa copie du préfixe
     * « Equipo » — le jour où l'un gagnait un champ, l'autre l'oubliait.
     *
     * ELLE LÈVE : c'est à l'appelant de décider quoi faire de l'échec, parce
     * que les deux n'en font pas la même chose — l'un le note et continue,
     * l'autre le remonte à l'écran.
     */
    public static Campaign ouvrirChezCertiko(Campaign camp) {
        LC027_CertikoComptes.Equipe eq =
            LC027_CertikoComptes.creerEquipe(nomEquipe(camp.Name));
        // LE NOM OBTENU, PAS CELUI DEMANDÉ : un homonyme fait glisser l'équipe
        // vers « Equipo Jose Martinez (2) ». Donner le nom voulu à creerCompte
        // déposerait le pré-visiteur dans l'équipe de son homonyme, avec ses
        // dossiers.
        String equipe = String.isNotBlank(eq.nom) ? eq.nom : nomEquipe(camp.Name);
        LC027_CertikoComptes.Membre membre = LC027_CertikoComptes.creerCompte(
            camp.Email__c, MOT_DE_PASSE_INITIAL,
            prenomDe(camp.Name), nomDe(camp.Name), equipe, camp.Telephone__c);

        return new Campaign(
            Id = camp.Id,
            CERTIKO_User_Id__c = membre.id,
            CERTIKO_Login__c = membre.email,
            CERTIKO_Mot_De_Passe__c = MOT_DE_PASSE_INITIAL,
            CERTIKO_Equipe__c = equipe,
            CERTIKO_Equipe_Id__c = identifiantEquipe(membre, eq),
            CERTIKO_Compte_Cree_Le__c = System.now(),
            CERTIKO_Compte_Erreur__c = null
        );
    }

    /**
     * Identifiant de l'équipe — c'est LUI qui part dans `_equipe_poseur`, pas
     * le nom : une équipe se renomme chez Certiko, son identifiant non.
     *
     * L'équipe où le compte a RÉELLEMENT atterri prime sur celle qu'on a
     * demandée. Un email déjà pris (409) rend le compte existant, qui peut très
     * bien vivre dans une autre équipe : écrire l'équipe demandée enverrait
     * alors les dossiers à côté.
     */
    private static String identifiantEquipe(LC027_CertikoComptes.Membre membre,
            LC027_CertikoComptes.Equipe equipe) {
        if (membre != null && String.isNotBlank(membre.equipeId)) {
            return membre.equipeId;
        }
        return equipe == null ? null : equipe.id;
    }

    private static Campaign erreur(Id campagneId, String message) {
        return new Campaign(
            Id = campagneId,
            CERTIKO_Compte_Erreur__c = message == null ? null : message.abbreviate(255)
        );
    }

    /* ════════════════════════════════════════════════════════════════════════
       NOMS
       ════════════════════════════════════════════════════════════════════════ */

    /** « Equipo Jose Manuel » — une équipe par pré-visiteur. */
    @TestVisible
    private static String nomEquipe(String nomCampagne) {
        String nom = String.isBlank(nomCampagne) ? '' : nomCampagne.trim();
        return (PREFIXE_EQUIPE + nom).trim().abbreviate(120);
    }

    /**
     * Certiko exige un prénom ET un nom. Une campagne s'appelle « Jose Manuel
     * Fernández » : le premier mot fait le prénom, le reste le nom. Un nom en
     * un seul mot part des deux côtés plutôt que de faire échouer la création.
     */
    @TestVisible
    private static String prenomDe(String nomComplet) {
        String nom = String.isBlank(nomComplet) ? '' : nomComplet.trim();
        Integer espace = nom.indexOf(' ');
        return espace > 0 ? nom.substring(0, espace) : nom;
    }

    @TestVisible
    private static String nomDe(String nomComplet) {
        String nom = String.isBlank(nomComplet) ? '' : nomComplet.trim();
        Integer espace = nom.indexOf(' ');
        return espace > 0 ? nom.substring(espace + 1).trim() : nom;
    }
}