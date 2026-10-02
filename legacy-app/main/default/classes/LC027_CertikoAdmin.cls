/**
 * LC027_CertikoAdmin — contrôleur du tableau de bord Certiko (lwc027_certiko_comptes).
 *
 * Écran INTERNE, pour les administrateurs Salesforce. Il ne vit pas dans le
 * portail : ici l'utilisateur est réel, `with sharing` s'applique, et rien
 * n'est ouvert à l'invité d'un site.
 *
 * CE QU'IL APPORTE en plus de la console Certiko — le RAPPROCHEMENT. La console
 * montre les comptes ; elle ne sait pas quel pré-visiteur Salesforce n'en a
 * pas. C'est précisément ce qui se voit ici : un contrat signé sans compte
 * ouvert, ou un compte ouvert sous un email qui ne correspond plus.
 *
 * Les appels sortants passent par LC027_CertikoComptes, qui porte la clé des
 * comptes — distincte de celle des dossiers.
 */
public with sharing class LC027_CertikoAdmin {

    /** Tout ce dont l'écran a besoin, en un seul aller-retour. */
    public class Tableau {
        @AuraEnabled public LC027_CertikoComptes.Poseur poseur;
        @AuraEnabled public List<LC027_CertikoComptes.Equipe> equipes;
        @AuraEnabled public List<LC027_CertikoComptes.Membre> membres;
        @AuraEnabled public List<Previsiteur> previsiteurs;
    }

    /** Un pré-visiteur Salesforce, vu depuis Certiko. */
    public class Previsiteur {
        @AuraEnabled public Id campagneId;
        @AuraEnabled public String nom;
        @AuraEnabled public String email;
        @AuraEnabled public String statutContrat;
        @AuraEnabled public String certikoUserId;
        @AuraEnabled public String certikoLogin;
        @AuraEnabled public String certikoEquipe;
        /** Identifiant de l'équipe : c'est LUI qui part avec les dossiers. */
        @AuraEnabled public String certikoEquipeId;
        @AuraEnabled public Datetime compteCreeLe;
        @AuraEnabled public String erreur;
        /** Le compte existe VRAIMENT chez Certiko, pas seulement chez nous. */
        @AuraEnabled public Boolean compteVerifie;
        /**
         * L'équipe enregistrée chez nous n'est PLUS celle du compte chez
         * Certiko — ses dossiers partent donc à la mauvaise équipe. Arrive
         * quand quelqu'un déplace le compte depuis la console Certiko.
         */
        @AuraEnabled public Boolean equipeDesynchronisee;
    }

    /* ════════════════════════════════════════════════════════════════════════
       LECTURE
       ════════════════════════════════════════════════════════════════════════ */

    /**
     * État complet : le titulaire de la clé, ses équipes, ses comptes, et les
     * pré-visiteurs Salesforce en regard.
     *
     * @param inclureInactifs équipes et comptes désactivés compris — il n'y a
     *        pas de suppression chez Certiko, un départ se voit là.
     */
    @AuraEnabled
    public static Tableau getTableau(Boolean inclureInactifs) {
        Boolean tous = inclureInactifs == true;
        Tableau t = new Tableau();
        try {
            t.poseur = LC027_CertikoComptes.poseur();
            t.equipes = LC027_CertikoComptes.equipes(tous);
            t.membres = LC027_CertikoComptes.membres(null, tous);
        } catch (Exception e) {
            throw erreur(e.getMessage());
        }
        t.previsiteurs = previsiteurs(t.membres);
        return t;
    }

    /**
     * Pré-visiteurs dont le contrat est SIGNÉ : ce sont eux qui doivent avoir
     * un compte. Un contrat en attente n'en a pas encore, ce n'est pas une
     * anomalie et cela n'a rien à faire dans la liste des écarts.
     */
    private static List<Previsiteur> previsiteurs(List<LC027_CertikoComptes.Membre> membres) {
        // Équipe RÉELLE de chaque compte, par email : c'est elle qui fait foi.
        Map<String, String> equipeParEmail = new Map<String, String>();
        for (LC027_CertikoComptes.Membre m : membres) {
            if (String.isNotBlank(m.email)) {
                equipeParEmail.put(m.email.toLowerCase(), m.equipeId);
            }
        }
        List<Previsiteur> sortie = new List<Previsiteur>();
        for (Campaign c : [
            SELECT Id, Name, Email__c, StatutContrat__c, CERTIKO_User_Id__c,
                   CERTIKO_Login__c, CERTIKO_Equipe__c, CERTIKO_Equipe_Id__c,
                   CERTIKO_Compte_Cree_Le__c, CERTIKO_Compte_Erreur__c
            FROM Campaign
            WHERE Role__c = :LC027_Roles.PREVISITEUR
              AND StatutContrat__c = :LC027_GestionContrat.STATUT_SIGNE
            ORDER BY Name
            LIMIT 500
        ]) {
            Previsiteur p = new Previsiteur();
            p.campagneId = c.Id;
            p.nom = c.Name;
            p.email = c.Email__c;
            p.statutContrat = c.StatutContrat__c;
            p.certikoUserId = c.CERTIKO_User_Id__c;
            p.certikoLogin = c.CERTIKO_Login__c;
            p.certikoEquipe = c.CERTIKO_Equipe__c;
            p.certikoEquipeId = c.CERTIKO_Equipe_Id__c;
            p.compteCreeLe = c.CERTIKO_Compte_Cree_Le__c;
            p.erreur = c.CERTIKO_Compte_Erreur__c;
            // Confronté à la liste RÉELLE : un identifiant stocké chez nous ne
            // prouve pas que le compte existe encore chez eux.
            String login = String.isNotBlank(c.CERTIKO_Login__c) ? c.CERTIKO_Login__c : c.Email__c;
            String cle = String.isBlank(login) ? null : login.toLowerCase();
            p.compteVerifie = cle != null && equipeParEmail.containsKey(cle);

            // L'ÉCART QUI COÛTE CHER : le compte existe, mais dans une autre
            // équipe que celle enregistrée chez nous. Ses dossiers partiraient
            // à la mauvaise équipe, sans aucun message d'erreur — Certiko
            // accepte l'identifiant, il est simplement le mauvais.
            String equipeReelle = cle == null ? null : equipeParEmail.get(cle);
            p.equipeDesynchronisee = p.compteVerifie == true
                && String.isNotBlank(equipeReelle)
                && equipeReelle != c.CERTIKO_Equipe_Id__c;
            sortie.add(p);
        }
        return sortie;
    }

    /* ════════════════════════════════════════════════════════════════════════
       ÉQUIPES
       ════════════════════════════════════════════════════════════════════════ */

    @AuraEnabled
    public static LC027_CertikoComptes.Equipe creerEquipe(String nom) {
        try {
            return LC027_CertikoComptes.creerEquipe(nom);
        } catch (Exception e) {
            throw erreur(e.getMessage());
        }
    }

    @AuraEnabled
    public static LC027_CertikoComptes.Equipe majEquipe(String cle, String nouveauNom, Boolean active) {
        try {
            return LC027_CertikoComptes.majEquipe(cle, nouveauNom, active);
        } catch (Exception e) {
            throw erreur(e.getMessage());
        }
    }

    /* ════════════════════════════════════════════════════════════════════════
       COMPTES
       ════════════════════════════════════════════════════════════════════════ */

    @AuraEnabled
    public static LC027_CertikoComptes.Membre creerCompte(String email, String motDePasse,
            String prenom, String nom, String equipe, String telephone) {
        try {
            return LC027_CertikoComptes.creerCompte(email, motDePasse, prenom, nom, equipe, telephone);
        } catch (Exception e) {
            throw erreur(e.getMessage());
        }
    }

    /**
     * Change ce qui est fourni. Sert aux trois gestes du quotidien :
     * réinitialiser un mot de passe, déplacer d'équipe, désactiver un départ.
     */
    @AuraEnabled
    public static LC027_CertikoComptes.Membre majCompte(String cle, String motDePasse,
            String equipe, Boolean actif) {
        LC027_CertikoComptes.Membre membre;
        try {
            membre = LC027_CertikoComptes.majCompte(cle, motDePasse, equipe, actif);
        } catch (Exception e) {
            throw erreur(e.getMessage());
        }
        if (String.isNotBlank(equipe)) {
            suivreLeDeplacement(membre, equipe);
        }
        return membre;
    }

    /**
     * Un déplacement d'équipe se répercute sur la campagne — sinon les dossiers
     * du pré-visiteur continueraient de partir à son ancienne équipe.
     *
     * Silencieux si aucune campagne ne porte cet email : l'administrateur peut
     * très bien déplacer un compte Certiko qui n'a pas d'équivalent chez nous,
     * et ce n'est pas une raison pour faire échouer son geste. L'écran affiche
     * de toute façon l'écart au prochain chargement.
     */
    private static void suivreLeDeplacement(LC027_CertikoComptes.Membre membre, String equipe) {
        if (membre == null || String.isBlank(membre.email)) {
            return;
        }
        List<Campaign> camps = [
            SELECT Id FROM Campaign
            WHERE Role__c = :LC027_Roles.PREVISITEUR
              AND (CERTIKO_Login__c = :membre.email OR Email__c = :membre.email)
            LIMIT 1
        ];
        if (camps.isEmpty()) {
            return;
        }
        update new Campaign(
            Id = camps[0].Id,
            CERTIKO_Equipe__c = equipe.trim(),
            CERTIKO_Equipe_Id__c = membre.equipeId
        );
    }

    /**
     * Ouvre le compte d'un pré-visiteur resté sans accès — reprise manuelle de
     * ce que la signature aurait dû faire.
     *
     * Appel DIRECT et non par la file d'attente : l'administrateur attend une
     * réponse à l'écran, et rien n'a été écrit avant dans cette transaction.
     */
    @AuraEnabled
    public static Previsiteur ouvrirCompte(Id campagneId) {
        List<Campaign> camps = [
            SELECT Id, Name, Email__c, Telephone__c, Role__c, StatutContrat__c,
                   CERTIKO_User_Id__c, CERTIKO_Login__c, CERTIKO_Mot_De_Passe__c,
                   CERTIKO_Equipe__c, CERTIKO_Compte_Cree_Le__c, CERTIKO_Compte_Erreur__c
            FROM Campaign WHERE Id = :campagneId LIMIT 1
        ];
        if (camps.isEmpty()) {
            throw erreur('CAMPAGNE_INTROUVABLE');
        }
        Campaign camp = camps[0];
        if (camp.Role__c != LC027_Roles.PREVISITEUR) {
            throw erreur('PAS_UN_PREVISITEUR');
        }
        if (String.isBlank(camp.Email__c)) {
            throw erreur('EMAIL_MANQUANT');
        }

        // Une seule écriture de la vérité : le service porte le préfixe
        // d'équipe, le mot de passe initial et la liste des champs à remplir.
        // Cet écran en avait sa propre copie ; elle a fini par diverger.
        Campaign maj;
        try {
            maj = LC027_CertikoCompteService.ouvrirChezCertiko(camp);
        } catch (Exception e) {
            update new Campaign(Id = camp.Id,
                CERTIKO_Compte_Erreur__c = e.getMessage().abbreviate(255));
            throw erreur(e.getMessage());
        }
        update maj;

        Previsiteur p = new Previsiteur();
        p.campagneId = camp.Id;
        p.nom = camp.Name;
        p.email = camp.Email__c;
        p.statutContrat = camp.StatutContrat__c;
        p.certikoUserId = maj.CERTIKO_User_Id__c;
        p.certikoLogin = maj.CERTIKO_Login__c;
        p.certikoEquipe = maj.CERTIKO_Equipe__c;
        p.certikoEquipeId = maj.CERTIKO_Equipe_Id__c;
        p.compteCreeLe = maj.CERTIKO_Compte_Cree_Le__c;
        p.compteVerifie = true;
        return p;
    }

    /* ════════════════════════════════════════════════════════════════════════
       OUTILS
       ════════════════════════════════════════════════════════════════════════ */

    /**
     * AuraHandledException portant le CODE tel quel : le composant le traduit.
     * setMessage est indispensable, sans lui le client reçoit
     * « Script-thrown exception ».
     */
    private static AuraHandledException erreur(String message) {
        AuraHandledException e = new AuraHandledException(message);
        e.setMessage(message);
        return e;
    }
}