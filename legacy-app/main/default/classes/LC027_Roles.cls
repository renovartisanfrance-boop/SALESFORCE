/**
 * LC027_Roles — LA configuration des rôles du portail Gestion Prévisites.
 *
 * C'est le SEUL endroit, côté serveur, où un rôle est défini. Avant, la chaîne
 * 'Pre-visiteur' était recopiée en dur dans cinq classes : ajouter un rôle
 * obligeait à les retrouver toutes, et en oublier une ouvrait ou fermait
 * l'accès sans bruit. Toute règle qui dépend du rôle lit désormais ici.
 *
 * ⚠️ MIROIR CÔTÉ COMPOSANT — contratConfig.js (lwc027_gestion_contrat) porte
 * la même table pour l'AFFICHAGE du formulaire. Ce fichier-ci porte la
 * SÉCURITÉ : un champ déclaré côté composant mais absent de CHAMPS_PAR_ROLE
 * s'affichera, et son enregistrement sera ignoré en silence. Les deux listes se
 * tiennent ensemble — c'est volontaire, le navigateur ne décide jamais de ce
 * qui s'écrit.
 *
 * AJOUTER / RETIRER UN CHAMP POUR UN RÔLE
 *   1. ici, dans CHAMPS_PAR_ROLE (droit d'écriture) ;
 *   2. dans contratConfig.CHAMPS_PAR_ROLE (affichage) ;
 *   3. dans les requêtes de LC027_GestionContrat si le champ est nouveau.
 *
 * AJOUTER UN RÔLE
 *   1. la valeur dans la picklist Campaign.Role__c ET dans le jeu de valeurs
 *      global Types_Intervenant (le compte créé porte le rôle) ;
 *   2. une entrée dans chacune des tables ci-dessous ;
 *   3. l'écran d'accueil et la facturation du rôle dans le conteneur.
 */
public without sharing class LC027_Roles {

    /** Valeurs EXACTES de Campaign.Role__c (« Pre » sans accent). */
    public static final String PREVISITEUR  = 'Pre-visiteur';
    public static final String INSTALLATEUR = 'Installateur';

    /** Rôles admis sur le portail. Tout autre rôle — une Régie — est refusé. */
    public static final Set<String> ROLES_PORTAIL = new Set<String>{ PREVISITEUR, INSTALLATEUR };

    /**
     * Champs du formulaire de contrat ENREGISTRABLES, par rôle.
     *
     * L'installateur reprend pour l'instant exactement les champs du
     * prévisiteur : les deux listes divergeront quand ses champs propres
     * seront définis. Elles sont déjà séparées pour que ce jour-là, modifier
     * l'une ne touche pas l'autre.
     */
    private static final Map<String, Set<String>> CHAMPS_PAR_ROLE = new Map<String, Set<String>>{
        PREVISITEUR => new Set<String>{
            'Name',
            'Contrat_Profession__c',
            'Contrat_Situation__c',
            'Contrat_NIF__c',
            'Contrat_Adresse__c',
            'Contrat_CodePostal__c',
            'Contrat_Ville__c',
            'NombrePrevisites__c',
            'Contrat_Provinces__c',
            'Telephone__c',
            'Email__c'
        },
        INSTALLATEUR => new Set<String>{
            'Name',
            'Contrat_Profession__c',
            'Contrat_Situation__c',
            'Contrat_NIF__c',
            'Contrat_Adresse__c',
            'Contrat_CodePostal__c',
            'Contrat_Ville__c',
            'Contrat_Provinces__c',
            'Telephone__c',
            'Email__c'
        }
    };

    /**
     * Static Resource du contrat à signer, par rôle.
     *
     * Une entrée NULL ou vide REFUSE l'envoi en signature pour ce rôle, avec un
     * message explicite ; la saisie des informations reste possible. C'est le
     * moyen de suspendre la signature d'un rôle dont le contrat n'est pas prêt.
     *
     * ⚠️ L'installateur pointe aujourd'hui sur le contrat des PRÉVISITES : les
     * coordonnées de dessin de contratConfig.js sont celles de ce PDF. Le jour
     * où un PDF propre à l'installateur arrive, ses coordonnées sont à revoir.
     */
    private static final Map<String, String> CONTRAT_PAR_ROLE = new Map<String, String>{
        PREVISITEUR  => 'contrat_previsiteur',
        INSTALLATEUR => 'contrat_previsiteur'
    };

    /** Valeur EXACTE de Campaign.Pays__c pour l'Espagne. */
    public static final String PAYS_ESPAGNE = 'Espagne';

    /**
     * Champs RÉSERVÉS à certains pays (Campaign.Pays__c).
     *
     * Un champ absent de cette table vaut pour tous les pays. Un champ présent
     * n'est enregistrable QUE si la campagne est d'un pays listé — même si le
     * rôle l'autorise. Miroir côté composant : la clé `pays` des définitions de
     * contratConfig.js, qui masque le champ à l'écran.
     */
    private static final Map<String, Set<String>> PAYS_PAR_CHAMP = new Map<String, Set<String>>{
        'NombrePrevisites__c' => new Set<String>{ PAYS_ESPAGNE }
    };

    /** Préfixe du nom du Compte créé à l'inscription, par rôle. */
    private static final Map<String, String> PREFIXE_COMPTE = new Map<String, String>{
        PREVISITEUR  => 'PREVISITEUR- ',
        INSTALLATEUR => 'INSTALLATEUR- '
    };

    public static Boolean estRolePortail(String role) {
        return role != null && ROLES_PORTAIL.contains(role);
    }

    /** Champs enregistrables pour ce rôle ; ensemble VIDE si le rôle est inconnu. */
    public static Set<String> champsModifiables(String role) {
        Set<String> champs = CHAMPS_PAR_ROLE.get(role);
        // Copie : un appelant qui modifierait l'ensemble ne doit pas altérer la
        // configuration pour les appels suivants de la même transaction.
        return champs == null ? new Set<String>() : new Set<String>(champs);
    }

    /**
     * Champs enregistrables pour ce rôle ET ce pays : la liste du rôle, moins
     * les champs réservés à d'autres pays (voir PAYS_PAR_CHAMP).
     */
    public static Set<String> champsModifiables(String role, String pays) {
        Set<String> champs = champsModifiables(role);
        for (String champ : PAYS_PAR_CHAMP.keySet()) {
            if (!PAYS_PAR_CHAMP.get(champ).contains(pays)) {
                champs.remove(champ);
            }
        }
        return champs;
    }

    /** Nom de la Static Resource du contrat, ou null si le rôle n'en a pas encore. */
    public static String ressourceContrat(String role) {
        return CONTRAT_PAR_ROLE.get(role);
    }

    public static Boolean contratDisponible(String role) {
        return String.isNotBlank(ressourceContrat(role));
    }

    public static String prefixeCompte(String role) {
        String p = PREFIXE_COMPTE.get(role);
        return p == null ? '' : p;
    }
}