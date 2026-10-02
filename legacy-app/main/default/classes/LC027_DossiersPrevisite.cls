/**
 * LC027_DossiersPrevisite — visites du pré-visiteur connecté (portail Gestion Prévisites).
 *
 * QUI VOIT QUOI — le portail n'a pas d'utilisateur : le pré-visiteur est
 * identifié par le token de SA campagne. La chaîne est :
 *     Campaign (token)  <-  Account.Acces_REGIE__c
 *     Account           <-  Pro__c.LOOKUP_Pre_visiteur__c
 * Un dossier n'est lisible ou modifiable que s'il pointe sur un compte
 * rattaché à la campagne du token. Toute écriture revérifie ce lien.
 *
 * DEUX LISTES
 *   • à planifier : Pr_visite_Statut__c = « 🟨Passage Demandé » ET pas de date ;
 *   • planifiées  : Pr_visite_Statut__c = « 🟧Passage Planifié ».
 *
 * RÈGLES DE VALIDATION DE Pro__c RESPECTÉES (ne pas les contourner ici) :
 *   • PREVISITE3_OUI — « Passage Demandé » interdit toute date ;
 *   • PREVISITE4_OUI — « Passage Planifié » exige pré-visiteur ET date ;
 *   • CHAMPS_NUL2    — Audit_Statut_CQ__c ne peut plus être vidé.
 * D'où le rendu d'une visite PLANIFIÉE : retour à « Passage Demandé », date
 * vidée — vider le seul lookup serait refusé par PREVISITE4_OUI.
 *
 * COLONNES DES LISTES (vue « liste Salesforce » du portail)
 *   • « Créé le »            : Pro__c.CreatedDate ;
 *   • « Province »           : déduite du code postal quand le pré-visiteur est
 *     espagnol, sinon la ville (voir provinceOuVille) ;
 *   • « Dernière tentative » : date du dernier appel sans réponse, LUE DANS LE
 *     SUIVI D'HISTORIQUE de Audit_Statut_CQ__c — aucun champ ne la stocke.
 *
 * HISTORIQUE DU DOSSIER (getHistorique) — reconstruit depuis Pro__History, d'où
 * le suivi d'historique activé sur quatre champs :
 *   LOOKUP_Pre_visiteur__c, Audit_Statut_CQ__c, PREVISITE_Date__c,
 *   PREVISITE_Motif_Rendu__c.
 * L'historique ne remonte QUE jusqu'à l'activation du suivi : les dossiers
 * antérieurs affichent peu ou pas d'événements, c'est normal.
 *
 * without sharing : l'invité du site ne voit aucun dossier par le partage ; le
 * contrôle d'accès est celui décrit plus haut, fait ici explicitement.
 */
public without sharing class LC027_DossiersPrevisite {

    public static final String STATUT_DEMANDE  = '🟨Passage Demandé';
    public static final String STATUT_PLANIFIE = '🟧Passage Planifié';

    /** Valeurs d'API de Audit_Statut_CQ__c, dans l'ordre des tentatives. */
    public static final List<String> VALEURS_NRP = new List<String>{
        '🟨NRP x1', '🟨NRP x2', '🟨NRP x3'
    };

    /**
     * Clé du motif réservé aux dossiers ayant atteint 3 appels sans réponse.
     * Le TEXTE du motif est enregistré dans la langue d'affichage du portail :
     * c'est donc la clé, et non le texte, qui déclenche le contrôle.
     */
    public static final String CLE_MOTIF_INJOIGNABLE = 'injoignable';

    /**
     * Deux premiers chiffres du code postal ESPAGNOL -> province (codes INE,
     * fixés une fois pour toutes). Les orthographes sont celles du champ
     * Campaign.Contrat_Provinces__c, pour que les deux écrans parlent pareil.
     */
    private static final Map<String, String> PROVINCES_ES = new Map<String, String>{
        '01' => 'Araba/Álava',      '02' => 'Albacete',   '03' => 'Alicante/Alacant',
        '04' => 'Almería',          '05' => 'Ávila',      '06' => 'Badajoz',
        '07' => 'Balears (Illes)',  '08' => 'Barcelona',  '09' => 'Burgos',
        '10' => 'Cáceres',          '11' => 'Cádiz',      '12' => 'Castellón/Castelló',
        '13' => 'Ciudad Real',      '14' => 'Córdoba',    '15' => 'Coruña (A)',
        '16' => 'Cuenca',           '17' => 'Girona',     '18' => 'Granada',
        '19' => 'Guadalajara',      '20' => 'Gipuzkoa',   '21' => 'Huelva',
        '22' => 'Huesca',           '23' => 'Jaén',       '24' => 'León',
        '25' => 'Lleida',           '26' => 'Rioja (La)', '27' => 'Lugo',
        '28' => 'Madrid',           '29' => 'Málaga',     '30' => 'Murcia',
        '31' => 'Navarra',          '32' => 'Ourense',    '33' => 'Asturias',
        '34' => 'Palencia',         '35' => 'Palmas (Las)', '36' => 'Pontevedra',
        '37' => 'Salamanca',        '38' => 'Santa Cruz de Tenerife',
        '39' => 'Cantabria',        '40' => 'Segovia',    '41' => 'Sevilla',
        '42' => 'Soria',            '43' => 'Tarragona',  '44' => 'Teruel',
        '45' => 'Toledo',           '46' => 'Valencia/València', '47' => 'Valladolid',
        '48' => 'Bizkaia',          '49' => 'Zamora',     '50' => 'Zaragoza',
        '51' => 'Ceuta',            '52' => 'Melilla'
    };

    /** Valeur de Campaign.Pays__c qui ouvre la table des provinces espagnoles. */
    private static final String PAYS_ESPAGNE = 'Espagne';

    /**
     * Pays du pré-visiteur de la transaction en cours, posé par
     * comptesDuPrevisiteur : c'est lui qui décide de la lecture du code postal.
     * Une transaction ne sert qu'un token, donc un seul pays.
     */
    private static String paysCourant;

    public class Dossier {
        @AuraEnabled public Id id;
        @AuraEnabled public String nom;
        @AuraEnabled public String adresse;
        @AuraEnabled public String telephone;
        @AuraEnabled public String statut;
        @AuraEnabled public Datetime datePassage;
        /** Colonne « Créé le » de la liste. */
        @AuraEnabled public Datetime dateCreation;
        /** Colonne « Province » : province espagnole, ou ville à défaut. */
        @AuraEnabled public String province;
        /** Colonne « Dernière tentative » : dernier NRP, lu dans l'historique. */
        @AuraEnabled public Datetime derniereTentative;
        /** Nombre d'appels sans réponse enregistrés : 0 à 3. */
        @AuraEnabled public Integer nrp;
        @AuraEnabled public Boolean planifie;

        /* Certiko — état de la visite technique (voir LC027_Certiko). */
        @AuraEnabled public String certikoId;
        @AuraEnabled public String certikoReference;
        @AuraEnabled public String certikoStatutVt;
        /**
         * Libellé de la liste de sélection pour ce statut (« En cours »). Le
         * portail préfère sa propre traduction ; ceci lui évite d'afficher une
         * valeur d'API pour un statut ajouté en configuration.
         */
        @AuraEnabled public String certikoStatutVtLibelle;
        @AuraEnabled public String certikoStatutDossier;
        @AuraEnabled public Datetime certikoDateEnvoi;
        @AuraEnabled public Datetime certikoStatutMaj;
        @AuraEnabled public String certikoErreur;
        /** Lien du relevé terrain, prêt à ouvrir. Vide tant que rien n'est envoyé. */
        @AuraEnabled public String certikoLien;
        /** Dossier DÉJÀ chez Certiko : id ET référence présents. */
        @AuraEnabled public Boolean certikoEnvoye;
        /**
         * Statut renvoyé par Certiko mais REFUSÉ par notre liste de sélection.
         * Renseigné le temps d'une réponse, jamais stocké : le portail ne
         * l'affiche qu'en mode test, pour qu'un statut ouvert chez Certiko et
         * pas chez nous se voie tout de suite.
         */
        @AuraEnabled public String certikoStatutRefuse;
    }

    /**
     * Un événement de l'historique du dossier. Le composant TRADUIT et met en
     * forme : ici, aucun texte d'interface.
     */
    public class Evenement {
        @AuraEnabled public Datetime quand;
        /** creation | ajout | nrp | rdv | replanif | rendu | retire */
        @AuraEnabled public String type;
        /** Appel sans réponse : 1, 2 ou 3. */
        @AuraEnabled public Integer niveau;
        /** Motif, pour un rendu. */
        @AuraEnabled public String valeur;
        @AuraEnabled public Datetime dateNouvelle;
        @AuraEnabled public Datetime dateAncienne;
        /** Nom lisible quand l'historique le porte (compte du rendu). */
        @AuraEnabled public String auteur;
        /** Vrai si l'action vient du portail, donc du pré-visiteur lui-même. */
        @AuraEnabled public Boolean parLePrevisiteur;
    }

    /**
     * Une ligne d'historique, DÉTACHÉE de Pro__History.
     *
     * Les enregistrements d'historique ne sont ni créables ni reconstituables
     * dans un test : les recopier ici est la seule façon de vérifier la mise en
     * forme, qui est la partie où une erreur se verrait à l'écran.
     */
    public class Ligne {
        public String champ;
        public Object avant;
        public Object apres;
        public Datetime quand;
        /** Vrai si l'écriture vient du portail, donc du pré-visiteur. */
        public Boolean parLePortail;

        public Ligne(String champ, Object avant, Object apres, Datetime quand, Boolean parLePortail) {
            this.champ = champ;
            this.avant = avant;
            this.apres = apres;
            this.quand = quand;
            this.parLePortail = parLePortail;
        }
    }

    public class Dossiers {
        @AuraEnabled public List<Dossier> aPlanifier = new List<Dossier>();
        @AuraEnabled public List<Dossier> planifies  = new List<Dossier>();
    }

    /* ════════════════════════════════════════════════════════════════════════
       LECTURE
       ════════════════════════════════════════════════════════════════════════ */

    @AuraEnabled
    public static Dossiers getDossiers(String campaignToken) {
        Set<Id> comptes = comptesDuPrevisiteur(campaignToken);
        Dossiers res = new Dossiers();
        if (comptes.isEmpty()) {
            return res;
        }
        Map<Id, Dossier> parId = new Map<Id, Dossier>();
        for (Pro__c p : [
            SELECT Id, Name, Client_Adresse_Chantier__c, Phone__c, CodePostal__c, CreatedDate,
                   Pr_visite_Statut__c, PREVISITE_Date__c, Audit_Statut_CQ__c,
                   CERTIKO_Dossier_Id__c, CERTIKO_Reference__c, CERTIKO_Statut_VT__c,
                   CERTIKO_Statut_Dossier__c, CERTIKO_Date_Envoi__c, CERTIKO_Statut_Maj__c,
                   CERTIKO_Message_Erreur__c, CERTIKO_Numero_Envoi__c
            FROM Pro__c
            WHERE LOOKUP_Pre_visiteur__c IN :comptes
              AND ( (Pr_visite_Statut__c = :STATUT_DEMANDE AND PREVISITE_Date__c = null)
                 OR  Pr_visite_Statut__c = :STATUT_PLANIFIE )
            ORDER BY PREVISITE_Date__c ASC NULLS LAST, CreatedDate ASC
            LIMIT 1000
        ]) {
            Dossier d = versDossier(p);
            parId.put(d.id, d);
            if (d.planifie) {
                res.planifies.add(d);
            } else {
                res.aPlanifier.add(d);
            }
        }
        Map<Id, Datetime> appels = derniersAppels(parId.keySet());
        for (Id cle : appels.keySet()) {
            parId.get(cle).derniereTentative = appels.get(cle);
        }
        return res;
    }

    /**
     * Date du DERNIER appel sans réponse de chaque dossier — colonne
     * « Dernière tentative ». Elle est LUE dans le suivi d'historique de
     * Audit_Statut_CQ__c : aucun champ ne la stocke.
     *
     * Deux conséquences assumées : les tentatives enregistrées AVANT
     * l'activation du suivi n'ont pas de date (la colonne affiche « — »), et
     * une lecture impossible laisse la colonne vide — la liste, elle, doit
     * s'afficher dans tous les cas.
     */
    private static Map<Id, Datetime> derniersAppels(Set<Id> dossiers) {
        Map<Id, Datetime> res = new Map<Id, Datetime>();
        if (dossiers.isEmpty()) {
            return res;
        }
        try {
            // Tri croissant : la tentative la plus récente écrase les précédentes.
            for (Pro__History h : [
                SELECT ParentId, NewValue, CreatedDate
                FROM Pro__History
                WHERE ParentId IN :dossiers AND Field = 'Audit_Statut_CQ__c'
                ORDER BY CreatedDate ASC
                LIMIT 5000
            ]) {
                if (niveauNrp(String.valueOf(h.NewValue)) > 0) {
                    res.put(h.ParentId, h.CreatedDate);
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Historique des appels illisible : ' + e.getMessage());
        }
        return res;
    }

    /**
     * Historique d'un dossier, reconstruit depuis Pro__History : attribution,
     * appels sans réponse, prise puis report du rendez-vous, rendu à ECONATURA.
     * Le composant traduit et met en forme.
     */
    @AuraEnabled
    public static List<Evenement> getHistorique(String campaignToken, Id dossierId) {
        Pro__c p = dossierAutorise(campaignToken, dossierId);
        List<Ligne> lignes = new List<Ligne>();
        try {
            // Le portail n'a pas d'utilisateur : ce qui est écrit par l'invité
            // du site vient du pré-visiteur ; le reste vient d'ECONATURA.
            for (Pro__History h : [
                SELECT Field, OldValue, NewValue, CreatedDate, CreatedById
                FROM Pro__History
                WHERE ParentId = :p.Id
                ORDER BY CreatedDate ASC
                LIMIT 200
            ]) {
                lignes.add(new Ligne(h.Field, h.OldValue, h.NewValue, h.CreatedDate,
                    h.CreatedById == UserInfo.getUserId()));
            }
        } catch (Exception e) {
            // Suivi désactivé ou illisible : section vide, jamais d'erreur à l'écran.
            System.debug(LoggingLevel.WARN, 'Historique illisible : ' + e.getMessage());
            return new List<Evenement>();
        }
        return versEvenements(lignes);
    }

    /**
     * Lignes d'historique -> événements affichables.
     *
     * Séparé de la lecture pour être vérifiable : les enregistrements
     * d'historique ne sont JAMAIS créés pendant un test Apex, la seule façon de
     * contrôler cette mise en forme est de lui passer les lignes directement.
     */
    @TestVisible
    private static List<Evenement> versEvenements(List<Ligne> lignes) {
        List<Evenement> res = new List<Evenement>();
        // Un rendu écrit le motif ET vide le pré-visiteur dans le MÊME
        // enregistrement : sans ce repérage, l'événement sortirait en double.
        Set<Datetime> rendus = new Set<Datetime>();
        for (Ligne l : lignes) {
            if (l.champ == 'PREVISITE_Motif_Rendu__c' && l.apres != null) {
                rendus.add(l.quand);
            }
        }
        for (Ligne l : lignes) {
            Evenement e = versEvenement(l, rendus);
            if (e != null) {
                res.add(e);
            }
        }
        return depuisLAttribution(res);
    }

    /**
     * Ne garde que ce qui s'est passé DEPUIS LA DERNIÈRE ATTRIBUTION.
     *
     * Un dossier rendu puis réattribué repart chez un autre pré-visiteur : ses
     * appels, ses rendez-vous et son motif de rendu ne regardent pas le
     * suivant. Le dernier « ajout » marque donc le début de ce que le
     * pré-visiteur courant a le droit de voir.
     *
     * Sans aucun « ajout » — dossier attribué avant l'activation du suivi —
     * l'historique est rendu tel quel : il ne commence de toute façon qu'à
     * cette activation.
     */
    private static List<Evenement> depuisLAttribution(List<Evenement> evts) {
        Integer debut = 0;
        for (Integer i = 0; i < evts.size(); i++) {
            if (evts[i].type == 'ajout') {
                debut = i;
            }
        }
        if (debut == 0) {
            return evts;
        }
        List<Evenement> res = new List<Evenement>();
        for (Integer i = debut; i < evts.size(); i++) {
            res.add(evts[i]);
        }
        return res;
    }

    /** Une ligne d'historique -> un événement lisible, ou null si sans intérêt. */
    private static Evenement versEvenement(Ligne l, Set<Datetime> rendus) {
        Evenement e = new Evenement();
        e.quand = l.quand;
        e.parLePrevisiteur = l.parLePortail;
        if (l.champ == 'created') {
            e.type = 'creation';
            return e;
        }
        if (l.champ == 'Audit_Statut_CQ__c') {
            Integer n = niveauNrp(String.valueOf(l.apres));
            if (n == 0) {
                return null;
            }
            e.type = 'nrp';
            e.niveau = n;
            return e;
        }
        if (l.champ == 'PREVISITE_Date__c') {
            Datetime nouvelle = versDatetime(l.apres);
            if (nouvelle == null) {
                return null;   // date vidée : c'est le rendu qui le raconte
            }
            e.dateNouvelle = nouvelle;
            e.dateAncienne = versDatetime(l.avant);
            e.type = e.dateAncienne == null ? 'rdv' : 'replanif';
            return e;
        }
        if (l.champ == 'PREVISITE_Motif_Rendu__c') {
            if (l.apres == null) {
                return null;
            }
            String texte = String.valueOf(l.apres);
            e.type = 'rendu';
            e.valeur = motifSeul(texte);
            e.auteur = compteDuMotif(texte);
            return e;
        }
        if (l.champ == 'LOOKUP_Pre_visiteur__c') {
            if (l.apres != null) {
                e.type = 'ajout';
                return e;
            }
            if (rendus.contains(l.quand)) {
                return null;
            }
            e.type = 'retire';
            return e;
        }
        return null;
    }

    /**
     * Accès du pré-visiteur à Certiko, tel qu'il s'affiche dans son portail.
     *
     * Le mot de passe voyage jusqu'au navigateur, et c'est voulu : le
     * pré-visiteur doit pouvoir le lire pour se connecter la première fois. Il
     * n'ouvre que le relevé de visite technique chez Certiko, aucune donnée
     * Salesforce.
     */
    public class AccesCertiko {
        @AuraEnabled public String login;
        @AuraEnabled public String motDePasse;
        @AuraEnabled public String equipe;
        /** Vrai quand le compte existe vraiment chez Certiko. */
        @AuraEnabled public Boolean pret;
    }

    /**
     * Identifiants Certiko du pré-visiteur connecté.
     *
     * Le compte s'ouvre à la signature du contrat (LC027_CertikoCompteService).
     * Tant qu'il n'existe pas — création en attente ou en échec — `pret` est
     * faux et le portail le dit, plutôt que d'afficher des champs vides.
     */
    @AuraEnabled
    public static AccesCertiko getAccesCertiko(String campaignToken) {
        // Même porte d'entrée que le reste du portail : rôle, campagne active,
        // contrat signé. Le résultat est ignoré, seul le contrôle compte.
        comptesDuPrevisiteur(campaignToken);
        List<Campaign> camps = [
            SELECT CERTIKO_Login__c, CERTIKO_Mot_De_Passe__c, CERTIKO_Equipe__c,
                   CERTIKO_User_Id__c
            FROM Campaign WHERE CampaignToken__c = :campaignToken LIMIT 1
        ];
        AccesCertiko acces = new AccesCertiko();
        if (camps.isEmpty()) {
            acces.pret = false;
            return acces;
        }
        acces.login = camps[0].CERTIKO_Login__c;
        acces.motDePasse = camps[0].CERTIKO_Mot_De_Passe__c;
        acces.equipe = camps[0].CERTIKO_Equipe__c;
        acces.pret = String.isNotBlank(camps[0].CERTIKO_User_Id__c)
            && String.isNotBlank(camps[0].CERTIKO_Login__c);
        return acces;
    }

    /**
     * État d'un SEUL dossier — version légère de getDossiers.
     *
     * Le portail s'en sert pour rafraîchir la fiche ouverte : à la réception
     * d'un événement Certiko_Maj__e, ou à intervalle régulier quand l'écoute
     * n'est pas possible. Recharger les deux listes entières pour une seule
     * ligne qui change serait disproportionné.
     *
     * Le contrôle d'accès reste le même : le dossier doit appartenir au
     * pré-visiteur du token.
     */
    @AuraEnabled
    public static Dossier getDossier(String campaignToken, Id dossierId) {
        return versDossier(dossierAutorise(campaignToken, dossierId));
    }

    /* ════════════════════════════════════════════════════════════════════════
       ÉCRITURES
       ════════════════════════════════════════════════════════════════════════ */

    /**
     * Enregistre un appel sans réponse. `niveau` doit être EXACTEMENT la
     * tentative suivante : un double clic ou un onglet resté ouvert ne doit pas
     * sauter une étape ni revenir en arrière.
     */
    @AuraEnabled
    public static Dossier enregistrerNrp(String campaignToken, Id dossierId, Integer niveau) {
        Pro__c p = dossierAutorise(campaignToken, dossierId);
        if (p.Pr_visite_Statut__c != STATUT_DEMANDE) {
            throw erreur('PLUS_A_PLANIFIER');
        }
        Integer actuel = niveauNrp(p.Audit_Statut_CQ__c);
        if (niveau == null || niveau != actuel + 1 || niveau > VALEURS_NRP.size()) {
            throw erreur('NRP_DEJA');
        }
        p.Audit_Statut_CQ__c = VALEURS_NRP[niveau - 1];
        enregistrer(p);
        return versDossier(relire(p.Id));
    }

    /**
     * Fixe (ou change) la date du rendez-vous et passe le dossier en
     * « Passage Planifié ».
     * @param dateHeureIso date et heure au format ISO 8601 (Date.toISOString()).
     */
    @AuraEnabled
    public static Dossier planifier(String campaignToken, Id dossierId, String dateHeureIso) {
        Pro__c p = dossierAutorise(campaignToken, dossierId);
        Datetime dh = lireDateHeure(dateHeureIso);
        if (dh.date() < Date.today()) {
            throw erreur('DATE_PASSEE');
        }
        p.PREVISITE_Date__c = dh;
        p.Pr_visite_Statut__c = STATUT_PLANIFIE;
        enregistrer(p);
        return versDossier(relire(p.Id));
    }

    /**
     * Replanifie une visite DÉJÀ ENVOYÉE chez Certiko — et repart de zéro.
     *
     * Une visite en cours ou à finaliser qu'on replanifie n'a plus rien à faire
     * chez Certiko : le relevé commencé porte l'ancien rendez-vous, et le
     * créneau de l'équipe reste réservé à une intervention qui n'aura pas lieu.
     * Trois gestes, dans cet ordre :
     *   1. chez eux, EN UN SEUL appel : passer status_vt à « annulé par le
     *      visiteur » et vider `_equipe_poseur`. Le dossier sort de l'écran de
     *      leurs équipes, et son sort reste lisible — un dossier simplement
     *      dépouillé de son équipe aurait paru abandonné sans raison ;
     *   2. effacer nos champs Certiko : le dossier redevient « à envoyer » ;
     *   3. incrémenter le numéro d'envoi, SANS QUOI RIEN NE REPARTIRAIT. Leur
     *      API refuse une seconde création sous la même clé d'idempotence, et
     *      cette clé porte ce numéro (voir LC027_Certiko.cleIdempotence).
     *
     * L'APPEL SORTANT PASSE EN PREMIER : Salesforce refuse un callout après un
     * DML. Et il n'est PAS bloquant — Certiko injoignable ne doit pas empêcher
     * de reposer une date. L'échec est écrit dans CERTIKO_Message_Erreur__c,
     * APRÈS l'effacement, pour qu'il y survive : l'équipe reste alors à libérer
     * à la main chez eux, et la trace le dit.
     */
    @AuraEnabled
    public static Dossier replanifierApresEnvoi(String campaignToken, Id dossierId, String dateHeureIso) {
        Pro__c p = dossierAutorise(campaignToken, dossierId);
        Datetime dh = lireDateHeure(dateHeureIso);
        if (dh.date() < Date.today()) {
            throw erreur('DATE_PASSEE');
        }

        String souci = null;
        if (String.isNotBlank(p.CERTIKO_Dossier_Id__c)) {
            try {
                LC027_Certiko.majColonnes(p.CERTIKO_Dossier_Id__c, new Map<String, Object>{
                    System.Label.CERTIKO_COLONNE_STATUT_VT => System.Label.CERTIKO_STATUT_ANNULE,
                    System.Label.CERTIKO_COLONNE_FIN_VT    => ''
                });
            } catch (Exception e) {
                souci = e.getMessage();
            }
        }

        Pro__c maj = new Pro__c(Id = p.Id);
        maj.PREVISITE_Date__c = dh;
        maj.Pr_visite_Statut__c = STATUT_PLANIFIE;
        maj.CERTIKO_Dossier_Id__c = null;
        maj.CERTIKO_Reference__c = null;
        maj.CERTIKO_Statut_VT__c = null;
        maj.CERTIKO_Statut_Dossier__c = null;
        maj.CERTIKO_Date_Envoi__c = null;
        maj.CERTIKO_Statut_Maj__c = null;
        maj.CERTIKO_Message_Erreur__c = souci;
        maj.CERTIKO_Numero_Envoi__c = numeroEnvoiSuivant(p);
        enregistrer(maj);
        return versDossier(relire(p.Id));
    }

    /** Vide vaut 1 : les Dossiers créés avant ce champ n'en portent pas. */
    private static Decimal numeroEnvoiSuivant(Pro__c p) {
        Decimal n = p.CERTIKO_Numero_Envoi__c;
        return (n == null || n < 1 ? 1 : n) + 1;
    }

    /**
     * Rend la visite à ECONATURA : motif enregistré (tel que saisi, dans la
     * langue d'affichage), pré-visiteur retiré.
     * @param motifCle clé du motif choisi (desinteret / injoignable / autre).
     * Visite planifiée : retour à « Passage Demandé » et date vidée, sans quoi
     * PREVISITE4_OUI refuserait l'enregistrement.
     */
    @AuraEnabled
    public static void rendreVisite(String campaignToken, Id dossierId, String motif, String motifCle) {
        Pro__c p = dossierAutorise(campaignToken, dossierId);
        String m = motif == null ? '' : motif.trim();
        if (m.length() < 3) {
            throw erreur('MOTIF_MANQUANT');
        }
        if (motifCle == CLE_MOTIF_INJOIGNABLE && niveauNrp(p.Audit_Statut_CQ__c) < VALEURS_NRP.size()) {
            throw erreur('MOTIF_NRP');
        }
        // Format « Nom du compte - motif » : le dossier peut etre reattribue puis
        // rendu par un autre pre-visiteur ; l historique du champ doit dire QUI
        // a rendu la visite, pas seulement pourquoi.
        String compte = p.LOOKUP_Pre_visiteur__r == null ? null : p.LOOKUP_Pre_visiteur__r.Name;
        String texte = String.isBlank(compte) ? m : compte.trim() + ' - ' + m;
        p.PREVISITE_Motif_Rendu__c = texte.abbreviate(255);
        // Compteur de rendus : null sur les dossiers anterieurs au champ.
        p.PREVISITE_Nb_Rendus__c = (p.PREVISITE_Nb_Rendus__c == null ? 0 : p.PREVISITE_Nb_Rendus__c) + 1;
        p.LOOKUP_Pre_visiteur__c = null;
        if (p.Pr_visite_Statut__c == STATUT_PLANIFIE) {
            p.Pr_visite_Statut__c = STATUT_DEMANDE;
            p.PREVISITE_Date__c = null;
        }
        enregistrer(p);
    }

    /* ════════════════════════════════════════════════════════════════════════
       CERTIKO — démarrage de la visite technique
       ════════════════════════════════════════════════════════════════════════ */

    /**
     * Envoie le dossier à Certiko, une seule fois.
     *
     * DÉJÀ ENVOYÉ = Id ET référence Certiko présents sur le Dossier : on rend
     * l'état tel quel, SANS appel. C'est le garde-fou contre les doublons ; le
     * composant ne décide de rien, il ne fait qu'afficher.
     *
     * Ordre imposé par Salesforce : lecture, puis appel sortant, puis
     * enregistrement — aucun DML avant le callout.
     */
    @AuraEnabled
    public static Dossier demarrerPrevisite(String campaignToken, Id dossierId) {
        Pro__c p = dossierAutorise(campaignToken, dossierId);
        if (p.Pr_visite_Statut__c != STATUT_PLANIFIE) {
            throw erreur('PAS_PLANIFIEE');
        }
        if (String.isNotBlank(p.CERTIKO_Dossier_Id__c) && String.isNotBlank(p.CERTIKO_Reference__c)) {
            return versDossier(p);
        }
        LC027_Certiko.Resultat res;
        try {
            res = LC027_Certiko.creerDossier(p.Id);
        } catch (Exception e) {
            noterErreurCertiko(p.Id, e.getMessage());
            throw erreur(e.getMessage());
        }
        if (String.isBlank(res.id)) {
            noterErreurCertiko(p.Id, 'CERTIKO_REPONSE_ILLISIBLE');
            throw erreur('CERTIKO_REPONSE_ILLISIBLE');
        }
        Boolean statutAdmis = LC027_Certiko.valeurAdmise(
            Pro__c.CERTIKO_Statut_VT__c, res.statutVt);
        Pro__c maj = new Pro__c(Id = p.Id);
        maj.CERTIKO_Dossier_Id__c = res.id;
        maj.CERTIKO_Reference__c = res.reference;
        if (statutAdmis) {
            maj.CERTIKO_Statut_VT__c = res.statutVt;
        }
        maj.CERTIKO_Statut_Dossier__c = res.statutDossier;
        maj.CERTIKO_Date_Envoi__c = System.now();
        maj.CERTIKO_Statut_Maj__c = System.now();
        maj.CERTIKO_Message_Erreur__c = null;
        enregistrer(maj);
        Dossier d = versDossier(relire(p.Id));
        if (!statutAdmis && String.isNotBlank(res.statutVt)) {
            d.certikoStatutRefuse = res.statutVt;
        }
        return d;
    }

    /**
     * Relit le statut chez Certiko et le recopie sur le Dossier.
     *
     * ÉCRITURE SEULEMENT SI LE STATUT A CHANGÉ — le portail appelle cette
     * méthode toutes les dix secondes tant que la fiche est ouverte. Écrire à
     * chaque passage déclencherait les automatismes du Dossier six fois par
     * minute pour ne rien changer. CERTIKO_Statut_Maj__c date donc le dernier
     * CHANGEMENT, pas la dernière lecture.
     */
    @AuraEnabled
    public static Dossier verifierStatutCertiko(String campaignToken, Id dossierId) {
        Pro__c p = dossierAutorise(campaignToken, dossierId);
        if (String.isBlank(p.CERTIKO_Dossier_Id__c)) {
            throw erreur('CERTIKO_SANS_DOSSIER');
        }
        LC027_Certiko.Resultat res;
        try {
            res = LC027_Certiko.lireDossier(p.CERTIKO_Dossier_Id__c);
        } catch (Exception e) {
            noterErreurCertiko(p.Id, e.getMessage());
            throw erreur(e.getMessage());
        }
        // Un statut hors liste n'est PAS enregistré : le dossier garde le
        // dernier état que nous savons interpréter.
        Boolean statutAdmis = LC027_Certiko.valeurAdmise(
            Pro__c.CERTIKO_Statut_VT__c, res.statutVt);
        Boolean change = (statutAdmis && p.CERTIKO_Statut_VT__c != res.statutVt)
            || p.CERTIKO_Statut_Dossier__c != res.statutDossier
            || String.isNotBlank(p.CERTIKO_Message_Erreur__c);
        Dossier d;
        if (!change) {
            d = versDossier(p);
        } else {
            Pro__c maj = new Pro__c(Id = p.Id);
            if (statutAdmis) {
                maj.CERTIKO_Statut_VT__c = res.statutVt;
            }
            maj.CERTIKO_Statut_Dossier__c = res.statutDossier;
            maj.CERTIKO_Statut_Maj__c = System.now();
            maj.CERTIKO_Message_Erreur__c = null;
            enregistrer(maj);
            d = versDossier(relire(p.Id));
        }
        if (!statutAdmis && String.isNotBlank(res.statutVt)) {
            d.certikoStatutRefuse = res.statutVt;
        }
        return d;
    }

    /**
     * Garde la trace du refus sur le Dossier. Isolé dans un try : un échec
     * d'écriture ne doit pas remplacer l'erreur d'origine, seule utile au
     * pré-visiteur.
     */
    private static void noterErreurCertiko(Id dossierId, String message) {
        try {
            update new Pro__c(Id = dossierId,
                CERTIKO_Message_Erreur__c = message == null ? null : message.abbreviate(255));
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Trace Certiko non enregistree : ' + e.getMessage());
        }
    }

    /* ════════════════════════════════════════════════════════════════════════
       CONTRÔLE D'ACCÈS
       ════════════════════════════════════════════════════════════════════════ */

    /**
     * Comptes du pré-visiteur. Refuse tout token qui ne donne pas accès au
     * portail ouvert : rôle Pré-visiteur, campagne active, contrat SIGNÉ (le
     * portail reste verrouillé tant que le contrat ne l'est pas).
     */
    private static Set<Id> comptesDuPrevisiteur(String campaignToken) {
        if (String.isBlank(campaignToken)) {
            throw erreur('ACCES_MANQUANT');
        }
        List<Campaign> camps = [
            SELECT Id, Role__c, IsActive, StatutContrat__c, Pays__c
            FROM Campaign
            WHERE CampaignToken__c = :campaignToken
            LIMIT 1
        ];
        if (camps.isEmpty()
                || camps[0].Role__c != LC027_Roles.PREVISITEUR
                || camps[0].IsActive != true
                || camps[0].StatutContrat__c != LC027_GestionContrat.STATUT_SIGNE) {
            throw erreur('ACCES_REFUSE');
        }
        paysCourant = camps[0].Pays__c;
        return new Map<Id, Account>([
            SELECT Id FROM Account WHERE Acces_REGIE__c = :camps[0].Id
        ]).keySet();
    }

    /** Le dossier, s'il appartient au pré-visiteur et est encore à traiter. */
    private static Pro__c dossierAutorise(String campaignToken, Id dossierId) {
        Set<Id> comptes = comptesDuPrevisiteur(campaignToken);
        List<Pro__c> ps = dossierId == null ? new List<Pro__c>() : [
            SELECT Id, Name, Client_Adresse_Chantier__c, Phone__c, CodePostal__c, CreatedDate,
                   Pr_visite_Statut__c, PREVISITE_Date__c, Audit_Statut_CQ__c,
                   LOOKUP_Pre_visiteur__c, LOOKUP_Pre_visiteur__r.Name, PREVISITE_Nb_Rendus__c,
                   CERTIKO_Dossier_Id__c, CERTIKO_Reference__c, CERTIKO_Statut_VT__c,
                   CERTIKO_Statut_Dossier__c, CERTIKO_Date_Envoi__c, CERTIKO_Statut_Maj__c,
                   CERTIKO_Message_Erreur__c, CERTIKO_Numero_Envoi__c
            FROM Pro__c
            WHERE Id = :dossierId AND LOOKUP_Pre_visiteur__c IN :comptes
            LIMIT 1
        ];
        if (ps.isEmpty()) {
            throw erreur('INTROUVABLE');
        }
        Pro__c p = ps[0];
        Boolean aPlanifier = p.Pr_visite_Statut__c == STATUT_DEMANDE && p.PREVISITE_Date__c == null;
        if (!aPlanifier && p.Pr_visite_Statut__c != STATUT_PLANIFIE) {
            throw erreur('NON_MODIFIABLE');
        }
        return p;
    }

    /* ════════════════════════════════════════════════════════════════════════
       OUTILS
       ════════════════════════════════════════════════════════════════════════ */

    private static Pro__c relire(Id dossierId) {
        return [
            SELECT Id, Name, Client_Adresse_Chantier__c, Phone__c, CodePostal__c, CreatedDate,
                   Pr_visite_Statut__c, PREVISITE_Date__c, Audit_Statut_CQ__c,
                   CERTIKO_Dossier_Id__c, CERTIKO_Reference__c, CERTIKO_Statut_VT__c,
                   CERTIKO_Statut_Dossier__c, CERTIKO_Date_Envoi__c, CERTIKO_Statut_Maj__c,
                   CERTIKO_Message_Erreur__c, CERTIKO_Numero_Envoi__c
            FROM Pro__c WHERE Id = :dossierId LIMIT 1
        ];
    }

    private static Dossier versDossier(Pro__c p) {
        Dossier d = new Dossier();
        d.id = p.Id;
        // Les noms importés finissent souvent par « - » (« CLAUDE ROCHER- »).
        d.nom = p.Name == null ? '' : p.Name.trim().removeEnd('-').trim();
        d.adresse = nettoyerAdresse(p.Client_Adresse_Chantier__c);
        d.telephone = p.Phone__c;
        d.statut = p.Pr_visite_Statut__c;
        d.datePassage = p.PREVISITE_Date__c;
        d.dateCreation = p.CreatedDate;
        d.province = provinceOuVille(p);
        d.nrp = niveauNrp(p.Audit_Statut_CQ__c);
        d.planifie = p.Pr_visite_Statut__c == STATUT_PLANIFIE;
        d.certikoId = p.CERTIKO_Dossier_Id__c;
        d.certikoReference = p.CERTIKO_Reference__c;
        d.certikoStatutVt = p.CERTIKO_Statut_VT__c;
        d.certikoStatutVtLibelle = LC027_Certiko.libelleDe(
            Pro__c.CERTIKO_Statut_VT__c, p.CERTIKO_Statut_VT__c);
        d.certikoStatutDossier = p.CERTIKO_Statut_Dossier__c;
        d.certikoDateEnvoi = p.CERTIKO_Date_Envoi__c;
        d.certikoStatutMaj = p.CERTIKO_Statut_Maj__c;
        d.certikoErreur = p.CERTIKO_Message_Erreur__c;
        d.certikoEnvoye = String.isNotBlank(p.CERTIKO_Dossier_Id__c)
            && String.isNotBlank(p.CERTIKO_Reference__c);
        d.certikoLien = d.certikoEnvoye ? LC027_Certiko.lienTerrain(p.CERTIKO_Dossier_Id__c) : null;
        return d;
    }

    /** « 39 RUE X,,48000,MENDE » -> « 39 RUE X, 48000, MENDE ». */
    private static String nettoyerAdresse(String brut) {
        if (String.isBlank(brut)) return '';
        List<String> parties = new List<String>();
        for (String s : brut.split(',')) {
            if (String.isNotBlank(s)) parties.add(s.trim());
        }
        return String.join(parties, ', ');
    }

    /**
     * Colonne « Province ».
     * Espagne : les deux premiers chiffres du code postal donnent la province
     * (table INE). Ailleurs, la France ayant des codes postaux de même forme,
     * cette table dirait n'importe quoi : on affiche alors la VILLE, dernière
     * partie de l'adresse chantier.
     */
    private static String provinceOuVille(Pro__c p) {
        if (paysCourant == PAYS_ESPAGNE) {
            String cp = String.isNotBlank(p.CodePostal__c)
                ? p.CodePostal__c.trim()
                : codePostalDe(p.Client_Adresse_Chantier__c);
            if (String.isNotBlank(cp) && cp.length() >= 2) {
                String prov = PROVINCES_ES.get(cp.substring(0, 2));
                if (prov != null) {
                    return prov;
                }
            }
        }
        return villeDe(p.Client_Adresse_Chantier__c);
    }

    /** Premier groupe de 5 chiffres de l'adresse, à défaut de CodePostal__c. */
    private static String codePostalDe(String adresse) {
        if (String.isBlank(adresse)) return null;
        for (String part : adresse.split(',')) {
            String s = part.trim();
            if (s.length() == 5 && s.isNumeric()) return s;
        }
        return null;
    }

    /** « 39 RUE X, 48000, MENDE » -> « MENDE ». */
    private static String villeDe(String adresse) {
        if (String.isBlank(adresse)) return '';
        List<String> parties = new List<String>();
        for (String s : adresse.split(',')) {
            if (String.isNotBlank(s)) parties.add(s.trim());
        }
        return parties.isEmpty() ? '' : parties[parties.size() - 1];
    }

    /**
     * Valeur d'historique -> Datetime. Salesforce rend déjà un Datetime pour un
     * champ de ce type ; le repli ne sert qu'aux valeurs rendues en texte.
     */
    private static Datetime versDatetime(Object valeur) {
        if (valeur == null) return null;
        if (valeur instanceof Datetime) return (Datetime) valeur;
        try {
            return (Datetime) JSON.deserialize('"' + String.valueOf(valeur) + '"', Datetime.class);
        } catch (Exception e) {
            return null;
        }
    }

    /** « PREVISITEUR-Jose - Client absent » -> « Client absent ». */
    private static String motifSeul(String texte) {
        Integer i = texte == null ? -1 : texte.indexOf(' - ');
        return (i > 0 && texte.startsWith('PREVISITEUR')) ? texte.substring(i + 3) : texte;
    }

    /** « PREVISITEUR-Jose - Client absent » -> « Jose ». */
    private static String compteDuMotif(String texte) {
        Integer i = texte == null ? -1 : texte.indexOf(' - ');
        if (i <= 0 || !texte.startsWith('PREVISITEUR')) return null;
        return texte.substring(0, i).removeStart('PREVISITEUR-').trim();
    }

    private static Integer niveauNrp(String valeur) {
        Integer i = VALEURS_NRP.indexOf(valeur);
        return i < 0 ? 0 : i + 1;
    }

    private static Datetime lireDateHeure(String iso) {
        if (String.isBlank(iso)) {
            throw erreur('DATE_MANQUANTE');
        }
        try {
            return (Datetime) JSON.deserialize('"' + iso.trim() + '"', Datetime.class);
        } catch (Exception e) {
            throw erreur('DATE_INVALIDE');
        }
    }

    /**
     * Enregistre en remontant le message de la règle de validation (préfixe
     * « DML: ») : le pré-visiteur doit lire la raison du refus, pas
     * « Script-thrown exception ».
     */
    private static void enregistrer(Pro__c p) {
        try {
            update p;
        } catch (DmlException e) {
            throw erreur('DML:' + e.getDmlMessage(0));
        }
    }

    /**
     * AuraHandledException portant un CODE (traduit par le composant, écran
     * « previsite », clés err_<CODE>) ou « DML:<message Salesforce> ».
     */
    private static AuraHandledException erreur(String message) {
        AuraHandledException e = new AuraHandledException(message);
        e.setMessage(message);
        return e;
    }
}