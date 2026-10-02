/**
 * Contrôleur du composant lwc020_Facturation — écran « Mes paiements » du portail.
 *
 * PRINCIPE (calqué sur LC020_GestionReporting / lwc020_reporting_v2) : la liste des
 * champs à remonter est déclarée DANS LE LWC (config de colonnes) et envoyée ici, la
 * SOQL est construite côté serveur. Ajouter une colonne au tableau ne demande donc
 * aucune modification de cette classe.
 *
 * MAIS — contrairement au reporting — les noms de champs reçus du navigateur sont
 * VALIDÉS CONTRE LE DESCRIBE avant d'entrer dans la requête (voir sanitizeFields).
 * LC020_GestionReporting fait « 'SELECT ' + metadata.champsPro + ' FROM Pro__c » sans
 * contrôle : c'est une injection SOQL, délibérément non reproduite ici.
 *
 * PÉRIMÈTRE DES DONNÉES : l'utilisateur ne voit que les Facture__c dont
 * Destinataire_Compte__c est SON compte. Ce compte est TOUJOURS dérivé côté serveur :
 *   1. compte de l'utilisateur authentifié (User.ContactId -> Contact.AccountId,
 *      repli User.AccountId) ;
 *   2. à défaut seulement, compte régie de la campagne portant le token
 *      (Campaign.CampaignToken__c -> Compte_Regie).
 * L'ordre est important : un partenaire connecté ne doit pas pouvoir lire les paiements
 * d'un tiers en posant le token d'une autre campagne dans son localStorage.
 *
 * Le type d'accès n'est jamais lu depuis le LWC (le reporting expose un @api
 * isCommunityUser que l'Apex croit sur parole) : il est déduit ici du compte résolu.
 *
 * Sécurité : « without sharing » — l'écran doit fonctionner pour un utilisateur de site
 * Experience, dont le profil n'a par construction aucun accès à Facture__c. Le
 * cloisonnement repose donc entièrement sur le filtre Destinataire_Compte__c ci-dessus.
 */
public without sharing class LC022PaiementPortailController {

    /**
     * Statuts de facture visibles côté portail.
     *
     * Le Brouillon EST exposé : côté intervenant, une facture en cours de préparation
     * reste une somme qui lui est due et qu'il doit pouvoir suivre. L'écran ne
     * distingue d'ailleurs plus Brouillon de Validé — les deux sont « impayé ».
     *
     * ⚠️ Un Brouillon n'a pas passé les règles de validation de l'objet : son
     *    N_Facture_Externe__c peut être vide (d'où le repli sur Name dans la config de
     *    colonnes) et ses montants peuvent encore changer.
     */
    private static final String STATUT_BROUILLON = 'Brouillon';
    private static final String STATUT_VALIDE    = 'Validé';
    private static final String STATUT_PAYE      = 'Payé';

    /** Non payé = ce qui alimente l'onglet « En cours ». */
    private static final Set<String> STATUTS_IMPAYES =
        new Set<String>{ STATUT_BROUILLON, STATUT_VALIDE };

    private static final Set<String> STATUTS_VISIBLES =
        new Set<String>{ STATUT_BROUILLON, STATUT_VALIDE, STATUT_PAYE };

    // Les avoirs remonteraient avec un montant POSITIF et fausseraient les totaux.
    private static final String RT_EXCLU = 'Avoir';

    /**
     * Périmètre : factures REÇUES uniquement.
     *
     * ⚠️ Graphie de la picklist (cf. FactureTriggerHandler lignes 6-9) : « Reçue » porte
     *    la cédille ET l'accent, alors que l'autre valeur est « Emise » SANS accent. Une
     *    faute de frappe ici ne provoque aucune erreur : elle vide silencieusement l'écran.
     *
     * Ce filtre n'est pas cosmétique. Sur une facture ÉMISE, FactureTriggerHandler écrit le
     * COMPTE SOCIÉTÉ dans Destinataire_Compte__c (et non le bénéficiaire) : sans ce filtre,
     * le compte société verrait remonter les factures émises de tous les partenaires.
     */
    private static final String TYPE_RECUE = 'Reçue';

    /**
     * Statut de CompteLigneRow (LC023) retenu pour la table « prêt à facturer ».
     * C'est le SEUL qui garantisse « échéance atteinte ET rien en base » : pour
     * EXISTANTE / INDISPONIBLE, la fusion de l'étape 7 de LC023 écrase le statut sans
     * revérifier l'échéance.
     */
    private static final String STATUS_A_CREER = 'A_CREER';

    /**
     * LC023.existingReusableLines plafonne à 1000 lignes réutilisables (ORDER BY
     * CreatedDate DESC). Au-delà, des lignes DÉJÀ créées ressortent en A_CREER. On
     * alerte bien avant d'atteindre ce seuil.
     */
    private static final Integer SEUIL_ALERTE_LC023 = 900;

    private static final Integer MAX_FACTURES   = 500;
    private static final Integer MAX_LIGNES     = 5000;
    private static final Integer MAX_CHAMPS     = 60;
    private static final Integer MAX_PROFONDEUR = 2;

    // Visiteur non authentifié : message unique pour « pas de token » ET « token
    // invalide ». Un message différencié permettrait d'énumérer les tokens valides.
    private static final String MSG_ACCES = 'Accès non identifié.';

    // Utilisateur AUTHENTIFIÉ dont aucun compte ne se résout : là, un message précis ne
    // divulgue rien (il parle de son propre rattachement) et évite un ticket de support.
    private static final String MSG_SANS_COMPTE =
        'Votre utilisateur n\'est rattaché à aucun compte de facturation. ' +
        'Contactez votre administrateur.';

    // Forme autorisée d'un nom de champ : segments alphanumériques séparés par des points.
    // Élimine parenthèses, virgules internes, apostrophes, espaces, mots-clés SOQL.
    private static final Pattern FIELD_PATTERN =
        Pattern.compile('^[A-Za-z0-9_]+(\\.[A-Za-z0-9_]+)*$');

    // ==================================================================== Wrappers

    /** Entrée : la config de colonnes du LWC, aplatie en listes de noms d'API. */
    public class PaiementMetadata {
        @AuraEnabled public String champsFacture { get; set; }
        @AuraEnabled public String champsLigne   { get; set; }
        @AuraEnabled public String campaignCode  { get; set; }
        /**
         * Compte à consulter, renseigné par le recordId d'une page d'enregistrement
         * Account en Lightning Experience. N'est HONORÉ QUE pour un utilisateur interne
         * (UserType 'Standard') : pour un utilisateur portail ou invité il est ignoré,
         * sinon n'importe qui pourrait lire les paiements de n'importe quel compte en
         * modifiant l'appel depuis la console du navigateur.
         */
        @AuraEnabled public String compteIdContexte { get; set; }
    }

    public class PaiementResult {
        @AuraEnabled public String  compteId      { get; set; }
        @AuraEnabled public String  compteNom     { get; set; }
        /** 'USER' | 'TOKEN' — sert au bandeau d'en-tête, pas au cloisonnement. */
        @AuraEnabled public String  source        { get; set; }

        /**
         * Totaux calculés par requête AGRÉGÉE sur l'intégralité des factures du compte,
         * PAS en sommant la liste ci-dessous : celle-ci est plafonnée à MAX_FACTURES et
         * les totaux resteraient donc faux, sans avertissement, au-delà de ce seuil.
         */
        @AuraEnabled public Decimal totalPaye   { get; set; }
        /** Brouillon + Validé : tout ce qui est affiché dans l'onglet est compté. */
        @AuraEnabled public Decimal totalAPayer { get; set; }
        @AuraEnabled public Integer nbPaye      { get; set; }
        @AuraEnabled public Integer nbAPayer    { get; set; }

        /** Vrai si la LISTE de factures a été plafonnée (les totaux ci-dessus
         *  restent exacts). Des factures MANQUENT alors à l'écran. */
        @AuraEnabled public Boolean tronque       { get; set; }

        /**
         * Vrai si la requête des LIGNES a été plafonnée. Cause distincte et
         * conséquence distincte : toutes les factures sont bien là, mais les
         * dernières perdent tout ou partie de leurs lignes de dossier. Elles
         * s'affichent alors avec des colonnes de dossier vides, et un filtre sur
         * le dossier les ferait disparaître avec leur montant. Les confondre en un
         * seul drapeau ferait afficher un message faux dans ce cas.
         */
        @AuraEnabled public Boolean lignesTronquees { get; set; }

        @AuraEnabled public List<FactureRow> factures { get; set; }

        public PaiementResult() {
            totalPaye = 0; totalAPayer = 0;
            nbPaye = 0;    nbAPayer = 0;
            tronque = false;
            lignesTronquees = false;
            factures = new List<FactureRow>();
        }
    }

    /** Une ligne de commission prête à être facturée (issue du catalogue via LC023). */
    public class LigneAFacturer {
        @AuraEnabled public String  key              { get; set; }
        @AuraEnabled public String  dossierId        { get; set; }
        @AuraEnabled public String  dossierName      { get; set; }
        @AuraEnabled public String  ficheCee         { get; set; }
        @AuraEnabled public String  role             { get; set; }
        @AuraEnabled public Integer numEcheance      { get; set; }
        @AuraEnabled public String  echeance         { get; set; }
        @AuraEnabled public Decimal montant          { get; set; }
        @AuraEnabled public Boolean isSupplementaire { get; set; }
        /** Note de la règle catalogue gagnante, affichée en infobulle. */
        @AuraEnabled public String  commentaire      { get; set; }
        /**
         * Pro__c.PAC_Date_d_Installation__c du dossier.
         *
         * Absente de CompteLigneRow, donc renseignée ici par une requête dédiée :
         * l'écran partenaire affiche dans une MÊME table les dossiers déjà facturés
         * — qui lisent la date via Dossier__r.PAC_Date_d_Installation__c dans la SOQL
         * dynamique — et ceux qui ne le sont pas encore. Sans elle, la colonne serait
         * vide sur la moitié des lignes.
         */
        @AuraEnabled public Date    dateInstallation { get; set; }
    }

    public class LignesAFacturerResult {
        @AuraEnabled public String  compteId       { get; set; }
        @AuraEnabled public String  compteNom      { get; set; }
        @AuraEnabled public String  source         { get; set; }
        @AuraEnabled public Decimal totalAFacturer { get; set; }
        @AuraEnabled public Integer nbAFacturer    { get; set; }
        /** Volumétrie proche du plafond interne de LC023 : le résultat peut être faux. */
        @AuraEnabled public Boolean tronque        { get; set; }
        @AuraEnabled public List<LigneAFacturer> lignes { get; set; }

        public LignesAFacturerResult() {
            totalAFacturer = 0;
            nbAFacturer = 0;
            tronque = false;
            lignes = new List<LigneAFacturer>();
        }
    }

    public class FactureRow {
        @AuraEnabled public String  id     { get; set; }
        /** Valeur d'API brute (Brouillon | Validé | Payé) : sert la logique, pas
         *  l'affichage — l'écran ne montre plus de colonne de statut. */
        @AuraEnabled public String  statut { get; set; }
        /**
         * Nombre de jours d'ancienneté du retard : 0 si l'échéance n'est pas dépassée
         * ou n'est pas renseignée (cas fréquent sur un Brouillon).
         *
         * Calculé SERVEUR : l'horloge du navigateur n'est pas une source de vérité, et
         * un utilisateur qui la décale ne doit pas voir ses factures changer d'état.
         */
        @AuraEnabled public Integer joursRetard { get; set; }
        /** Clé = le nom d'API EXACT demandé par le LWC, chemins pointés compris
         *  (« Dossier__r.Name »), pour qu'il relise avec la chaîne qu'il a écrite. */
        @AuraEnabled public Map<String, Object> champs { get; set; }
        @AuraEnabled public List<Map<String, Object>> lignes { get; set; }

        public FactureRow() {
            champs = new Map<String, Object>();
            lignes = new List<Map<String, Object>>();
        }
    }

    // ============================================================ Points d'entrée

    /**
     * Onglet « Payées » : factures reçues déjà réglées.
     * Le périmètre de statut est FIXÉ ICI, jamais transmis par le client — sinon le
     * navigateur pourrait l'élargir et lire les Brouillons.
     *
     * Non « cacheable » — comme LC020_GestionReporting.getReportingData — pour que le
     * bouton « Actualiser » du composant recharge réellement depuis le serveur.
     */
    @AuraEnabled
    public static PaiementResult getFacturesPayees(PaiementMetadata metadata) {
        return chargerFactures(metadata, new Set<String>{ STATUT_PAYE });
    }

    /**
     * Onglet « En cours », table basse : toutes les factures créées et non réglées,
     * Brouillon compris. L'écran les présente uniformément comme « impayées » et
     * n'affiche plus de colonne de statut : il montre à la place l'ancienneté du
     * retard, qui est l'information réellement actionnable pour l'intervenant.
     */
    @AuraEnabled
    public static PaiementResult getFacturesAPayer(PaiementMetadata metadata) {
        return chargerFactures(metadata, STATUTS_IMPAYES);
    }

    private static PaiementResult chargerFactures(PaiementMetadata metadata, Set<String> statuts) {
        if (metadata == null) {
            throw erreur('Paramètres manquants.');
        }

        ContexteAcces ctx = resoudreContexte(metadata);
        Id compteId = ctx.compteId;

        // ── 2. Validation des champs demandés (garde-fou anti-injection) ────────────
        // Champs forcés : nécessaires au fonctionnement même si aucune colonne ne les
        // affiche (regroupement, KPI, calcul du retard).
        List<String> champsFacture = sanitizeFields(
            metadata.champsFacture,
            Facture__c.SObjectType,
            new Set<String>{ 'Id', 'Statut__c', 'Montant_Total__c', 'DateEcheance__c' }
        );
        List<String> champsLigne = sanitizeFields(
            metadata.champsLigne,
            LigneFacture__c.SObjectType,
            new Set<String>{ 'Id', 'Facture__c' }
        );

        // Libellés de picklist, résolus une fois pour toutes les lignes.
        Map<String, Map<String, String>> libellesFacture =
            mapsPicklist(champsFacture, Facture__c.SObjectType);
        Map<String, Map<String, String>> libellesLigne =
            mapsPicklist(champsLigne, LigneFacture__c.SObjectType);

        // ── 3. Requêtes ────────────────────────────────────────────────────────────
        PaiementResult res = new PaiementResult();
        res.compteId  = compteId;
        res.compteNom = nomDuCompte(compteId);
        res.source    = ctx.source;

        // Variables LOCALES : Database.query ne voit que la portée de la méthode
        // appelante pour résoudre ses liaisons « :variable ».
        // Intersection avec STATUTS_VISIBLES : même si un appelant interne se trompait
        // de périmètre, aucun Brouillon ne pourrait sortir d'ici.
        Set<String> statutsVisibles = new Set<String>(statuts);
        statutsVisibles.retainAll(STATUTS_VISIBLES);
        String rtExclu   = RT_EXCLU;
        String typeRecue = TYPE_RECUE;

        // compteId / typeRecue / statutsVisibles / rtExclu sont BINDÉS, jamais concaténés.
        String soqlFactures =
            'SELECT ' + String.join(champsFacture, ', ') +
            ' FROM Facture__c' +
            ' WHERE Destinataire_Compte__c = :compteId' +
            '   AND TypeFacture__c = :typeRecue' +
            '   AND Statut__c IN :statutsVisibles' +
            '   AND RecordType.DeveloperName != :rtExclu' +
            ' ORDER BY DateFacture__c DESC NULLS LAST' +
            ' LIMIT ' + MAX_FACTURES;

        List<SObject> factures = Database.query(soqlFactures);
        res.tronque = (factures.size() == MAX_FACTURES);

        Map<Id, FactureRow> parId = new Map<Id, FactureRow>();
        Date aujourdhui = Date.today();

        for (SObject f : factures) {
            FactureRow row = new FactureRow();
            row.id     = String.valueOf(f.get('Id'));
            row.statut = (String) f.get('Statut__c');
            row.champs = extraireChamps(f, champsFacture, libellesFacture);

            // Le retard se lit sur l'échéance seule, quel que soit le statut : un
            // Brouillon sans échéance vaut simplement 0.
            Date echeance = (Date) f.get('DateEcheance__c');
            row.joursRetard = (echeance != null && echeance < aujourdhui)
                ? echeance.daysBetween(aujourdhui)
                : 0;

            res.factures.add(row);
            parId.put((Id) f.get('Id'), row);
        }

        // ── 3bis. KPI par requêtes AGRÉGÉES, indépendantes du plafond d'affichage ───
        calculerTotaux(res, compteId);

        // ── 4. Lignes rattachées (alimentent le rowspan côté LWC) ───────────────────
        // Deux requêtes plutôt qu'une sous-requête : évite de dépendre du nom de
        // relation enfant « Factures_associees » et découple les deux listes de champs.
        if (!parId.isEmpty()) {
            Set<Id> factureIds = parId.keySet();
            String soqlLignes =
                'SELECT ' + String.join(champsLigne, ', ') +
                ' FROM LigneFacture__c' +
                ' WHERE Facture__c IN :factureIds' +
                ' ORDER BY Facture__c' +
                ' LIMIT ' + MAX_LIGNES;

            List<SObject> lignes = Database.query(soqlLignes);
            // Drapeau DISTINCT de `tronque` : ici aucune facture ne manque, mais les
            // dernières de l'ORDER BY Facture__c perdent leurs lignes de dossier.
            // Les confondre ferait afficher « liste de factures plafonnée » alors que
            // toutes les factures sont présentes.
            res.lignesTronquees = (lignes.size() == MAX_LIGNES);

            for (SObject l : lignes) {
                FactureRow row = parId.get((Id) l.get('Facture__c'));
                if (row != null) {
                    row.lignes.add(extraireChamps(l, champsLigne, libellesLigne));
                }
            }
        }

        return res;
    }

    // ============================================ Onglet « En cours » — table haute

    /**
     * Lignes du catalogue prêtes à être facturées : échéance ATTEINTE et rien encore
     * créé en base.
     *
     * Réutilise LC023FacturationCompteController.getCompteFacturation TEL QUEL, en lui
     * passant un compteId résolu ICI côté serveur. C'est légitime et déjà éprouvé :
     * la méthode est public static, ne fait aucun DML ni callout, et LC023 s'appelle
     * elle-même en Apex (lignes 578 et 872).
     *
     * ⚠️ Ne JAMAIS exposer getCompteFacturation directement au client : elle est
     *    « without sharing », sans contrôle FLS/CRUD, et ne vérifie pas qui l'appelle.
     */
    @AuraEnabled
    public static LignesAFacturerResult getLignesAFacturer(PaiementMetadata metadata) {
        if (metadata == null) {
            throw erreur('Paramètres manquants.');
        }

        ContexteAcces ctx = resoudreContexte(metadata);

        LignesAFacturerResult res = new LignesAFacturerResult();
        res.compteId  = ctx.compteId;
        res.compteNom = nomDuCompte(ctx.compteId);
        res.source    = ctx.source;

        LC023FacturationCompteController.CompteFacturationResult src;
        try {
            src = LC023FacturationCompteController.getCompteFacturation(ctx.compteId);
        } catch (Exception e) {
            // getCompteFacturation lève une AuraHandledException si le compte est null.
            // Le garde de resoudreContexte l'exclut, mais on ne laisse pas remonter une
            // exception dont le message serait perdu (« Script-thrown exception »).
            dbg('getCompteFacturation a échoué : ' + e.getMessage());
            throw erreur('Impossible de calculer les lignes à facturer.');
        }

        if (src == null || src.rows == null) return res;

        for (LC023FacturationCompteController.CompteLigneRow r : src.rows) {
            // A_CREER est le SEUL statut garantissant « échéance atteinte ET rien en
            // base ». Pour EXISTANTE / INDISPONIBLE, la fusion de l'étape 7 de LC023
            // écrase le statut sans revérifier l'échéance : l'information est perdue.
            if (r.status != STATUS_A_CREER) continue;

            LigneAFacturer l = new LigneAFacturer();
            l.key              = r.key;
            l.dossierId        = r.dossierId;
            l.dossierName      = r.dossierName;
            l.ficheCee         = r.ficheCee;
            l.role             = r.role;
            l.numEcheance      = r.numEcheance;
            l.echeance         = libelleEcheance(r.echeance);
            l.montant          = r.montant;
            l.isSupplementaire = (r.isSupplementaire == true);
            l.commentaire      = r.commentaire;
            res.lignes.add(l);

            if (r.montant != null) res.totalAFacturer += r.montant;
            res.nbAFacturer++;
        }

        // ── Date d'installation des dossiers concernés ──────────────────────────
        // CompteLigneRow ne la porte pas, et LC023 n'est pas modifiée : une requête
        // dédiée, APRÈS la boucle, sur les seuls dossiers retenus. Elle est
        // bulkifiée (un IN sur l'ensemble des Ids) et bornée de fait par le volume
        // de lignes A_CREER, lui-même plafonné en amont par LC023.
        Set<Id> dossierIds = new Set<Id>();
        for (LigneAFacturer l : res.lignes) {
            if (String.isNotBlank(l.dossierId)) dossierIds.add((Id) l.dossierId);
        }
        if (!dossierIds.isEmpty()) {
            Map<Id, Pro__c> parDossier = new Map<Id, Pro__c>([
                SELECT Id, PAC_Date_d_Installation__c
                FROM Pro__c
                WHERE Id IN :dossierIds
            ]);
            for (LigneAFacturer l : res.lignes) {
                Pro__c p = String.isBlank(l.dossierId) ? null : parDossier.get((Id) l.dossierId);
                if (p != null) l.dateInstallation = p.PAC_Date_d_Installation__c;
            }
        }

        // ⚠️ LC023.existingReusableLines est plafonnée à 1000 lignes avec un
        //    ORDER BY CreatedDate DESC : au-delà, les lignes déjà créées les plus
        //    anciennes sortent du jeu et RESSORTENT en A_CREER alors qu'elles existent.
        //    On le signale plutôt que de laisser l'écran mentir en silence.
        res.tronque = (src.rows.size() >= SEUIL_ALERTE_LC023);

        return res;
    }

    /**
     * Libellés de LigneFacture__c.Echeance_Declenchante__c, calculés UNE fois.
     *
     * L'onglet « En cours » affiche dans une SEULE table deux origines qui ne
     * traitent pas l'échéance de la même façon : les lignes de facture passent par
     * extraireChamps, qui substitue le LIBELLÉ de la picklist, tandis que les lignes
     * du catalogue arrivent de LC023 avec la VALEUR d'API brute. Sans normalisation,
     * la même échéance s'afficherait « À l'audit effectué » sur une ligne et
     * « À L'Audit Effectué » sur la suivante.
     *
     * On traduit avec la picklist de LigneFacture__c, et non celle de la grille
     * tarifaire : c'est elle qui fait foi une fois la facture créée, et sa
     * description dit qu'elle reprend les mêmes valeurs.
     */
    private static Map<String, String> libellesEcheance;

    @TestVisible
    private static String libelleEcheance(String valeur) {
        if (String.isBlank(valeur)) return valeur;

        if (libellesEcheance == null) {
            libellesEcheance = new Map<String, String>();
            for (Schema.PicklistEntry pe :
                    LigneFacture__c.Echeance_Declenchante__c.getDescribe().getPicklistValues()) {
                libellesEcheance.put(pe.getValue(), pe.getLabel());
            }
        }
        // Valeur inconnue de la picklist (règle catalogue au libellé libre) :
        // on l'affiche telle quelle plutôt que de la vider.
        return libellesEcheance.containsKey(valeur) ? libellesEcheance.get(valeur) : valeur;
    }

    // ================================================== Résolution du contexte d'accès

    private class ContexteAcces {
        Id compteId;
        String source;   // 'CONTEXTE' | 'USER' | 'TOKEN'
    }

    /**
     * Résout le compte à consulter. Le compteId n'est JAMAIS un paramètre libre du
     * client : il est dérivé du contexte LEX (utilisateur interne uniquement), de
     * l'utilisateur authentifié, puis — à défaut seulement — du token de campagne.
     */
    private static ContexteAcces resoudreContexte(PaiementMetadata metadata) {
        ContexteAcces ctx = new ContexteAcces();

        // 1a. Contexte LEX — accepté UNIQUEMENT pour un utilisateur interne.
        if (UserInfo.getUserType() == 'Standard' && String.isNotBlank(metadata.compteIdContexte)) {
            try {
                ctx.compteId = (Id) metadata.compteIdContexte.trim();
                ctx.source = 'CONTEXTE';
            } catch (Exception e) {
                throw erreur('Identifiant de compte invalide.');
            }
            if (ctx.compteId.getSObjectType() != Account.SObjectType) {
                throw erreur('Identifiant de compte invalide.');
            }
        }

        // 1b. Compte de l'utilisateur authentifié — PRIORITAIRE sur le token : un
        //     partenaire connecté ne doit pas pouvoir lire les paiements d'un tiers
        //     en posant le token d'une autre campagne dans son localStorage.
        if (ctx.compteId == null) {
            ctx.compteId = compteDeLUtilisateurCourant();
            if (ctx.compteId != null) ctx.source = 'USER';
        }

        // 1c. À défaut seulement : compte régie porté par le token de campagne.
        if (ctx.compteId == null && String.isNotBlank(metadata.campaignCode)) {
            ctx.compteId = compteDuToken(metadata.campaignCode.trim());
            if (ctx.compteId != null) ctx.source = 'TOKEN';
        }

        if (ctx.compteId == null) {
            // Un invité reste sur le message générique (anti-énumération de tokens) ;
            // un utilisateur connecté reçoit un message actionnable sur SON compte.
            throw erreur(UserInfo.getUserType() == 'Guest' ? MSG_ACCES : MSG_SANS_COMPTE);
        }
        return ctx;
    }

    // ======================================================================= KPI

    /**
     * Totaux du compte par requêtes AGRÉGÉES, sur l'INTÉGRALITÉ des factures reçues —
     * sans le plafond MAX_FACTURES appliqué à la liste affichée.
     *
     * Sommer la liste donnerait des KPI faux dès qu'un compte dépasse ce plafond, et faux
     * SILENCIEUSEMENT : une régie à 700 factures verrait son total amputé des 200 plus
     * anciennes.
     *
     * « À payer » agrège Brouillon ET Validé : tout ce qui est affiché dans l'onglet est
     * compté, sinon l'intervenant additionne les lignes à la main sans retomber sur la
     * tuile.
     *
     * Requête STATIQUE : aucun champ ne provient du client, elle est hors du périmètre
     * de sanitizeFields.
     */
    private static void calculerTotaux(PaiementResult res, Id compteId) {
        for (AggregateResult ar : [
                SELECT Statut__c st, COUNT(Id) nb, SUM(Montant_Total__c) tot
                FROM Facture__c
                WHERE Destinataire_Compte__c = :compteId
                  AND TypeFacture__c = :TYPE_RECUE
                  AND Statut__c IN :STATUTS_VISIBLES
                  AND RecordType.DeveloperName != :RT_EXCLU
                GROUP BY Statut__c]) {

            String statut = (String) ar.get('st');
            Integer nb    = (Integer) ar.get('nb');
            Decimal tot   = (Decimal) ar.get('tot');   // SUM() renvoie null, pas 0
            if (tot == null) tot = 0;
            if (nb == null)  nb = 0;

            if (statut == STATUT_PAYE) {
                res.totalPaye   = tot;
                res.nbPaye      = nb;
            } else if (STATUTS_IMPAYES.contains(statut)) {
                // Cumul : deux statuts alimentent le même compteur.
                res.totalAPayer += tot;
                res.nbAPayer    += nb;
            }
        }

        // Pas d'agrégat « en retard » : l'écran n'affiche plus que deux tuiles, et le
        // détail du retard se lit ligne par ligne via FactureRow.joursRetard — inutile
        // de payer une requête supplémentaire pour un total que personne n'affiche.
    }

    // ======================================================= Résolution du compte

    /**
     * Compte de l'utilisateur connecté. TROIS chaînes possibles, essayées dans l'ordre :
     *
     *   1. User.AccountId                      — utilisateur portail rattaché au compte
     *   2. User.ContactId -> Contact.AccountId — chaîne Partner/Customer Community
     *   3. Campaign.OwnerId = user -> Compte_Regie
     *      L'apporteur d'affaires / la régie ne porte PAS toujours un Contact rattaché au
     *      compte régie : ce qui l'identifie, c'est qu'il est PROPRIÉTAIRE des campagnes
     *      de cette régie. C'est déjà la règle appliquée par LC020_GestionReporting pour
     *      les profils « APPORTEUR D'AFFAIRES » (Campaign WHERE OwnerId = :currentUserId).
     *      Cette branche est le pendant authentifié du chemin par token : les deux
     *      aboutissent au compte régie via Account.Acces_REGIE__c.
     *
     * ⚠️ L'étape 2 fait une requête SÉPARÉE sur Contact au lieu de sélectionner
     *    « Contact.AccountId » depuis User : la traversée de relation à deux niveaux
     *    depuis User n'est pas fiable en SOQL — constat déjà documenté dans
     *    LC023FacturationCompteController.usersForCompte(), qui procède aussi en deux temps.
     *
     * Retourne null pour un utilisateur invité de site Experience : c'est ce null qui
     * déclenche la branche « token ».
     */
    private static Id compteDeLUtilisateurCourant() {
        Id userId = UserInfo.getUserId();

        List<User> us = [SELECT Id, ContactId, AccountId FROM User WHERE Id = :userId LIMIT 1];
        if (us.isEmpty()) return null;
        User u = us[0];

        // 1. Rattachement direct (utilisateur portail).
        if (u.AccountId != null) {
            dbg('compte résolu via User.AccountId : ' + u.AccountId);
            return u.AccountId;
        }

        // 2. Chaîne User -> Contact -> Account, en DEUX requêtes.
        if (u.ContactId != null) {
            List<Contact> cs = [SELECT AccountId FROM Contact WHERE Id = :u.ContactId LIMIT 1];
            if (!cs.isEmpty() && cs[0].AccountId != null) {
                dbg('compte résolu via Contact.AccountId : ' + cs[0].AccountId);
                return cs[0].AccountId;
            }
        }

        // 3. Propriétaire de campagnes -> compte régie.
        Set<Id> campagnes = new Set<Id>();
        for (Campaign c : [SELECT Id FROM Campaign WHERE OwnerId = :userId LIMIT 200]) {
            campagnes.add(c.Id);
        }
        if (!campagnes.isEmpty()) {
            Id viaCampagne = compteDeCampagnes(campagnes);
            if (viaCampagne != null) {
                dbg('compte résolu via Campaign.OwnerId -> Compte_Regie : ' + viaCampagne);
                return viaCampagne;
            }
            dbg('utilisateur propriétaire de ' + campagnes.size() +
                ' campagne(s), mais aucun compte ne les référence via Acces_REGIE__c');
        }

        dbg('AUCUN compte résolu — User ' + userId +
            ' | ContactId=' + u.ContactId + ' | AccountId=' + u.AccountId +
            ' | campagnes possédées=' + campagnes.size());
        return null;
    }

    /** Premier compte référençant l'une de ces campagnes via Account.Acces_REGIE__c. */
    private static Id compteDeCampagnes(Set<Id> campagneIds) {
        if (campagneIds == null || campagneIds.isEmpty()) return null;

        String accCampaignField = champAccountVersCampagne();
        if (accCampaignField == null) {
            dbg('relation enfant « Compte_Regie » introuvable sur Campaign');
            return null;
        }

        // Nom de champ issu du describe (jamais du client) : concaténation sûre.
        // LIMIT 2 pour détecter — et tracer — une configuration ambiguë.
        String soql = 'SELECT Id FROM Account WHERE ' + accCampaignField +
                      ' IN :campagneIds LIMIT 2';
        List<SObject> comptes = Database.query(soql);
        if (comptes.isEmpty()) return null;
        if (comptes.size() > 1) {
            dbg('ATTENTION : plusieurs comptes référencent ces campagnes, le premier est retenu');
        }
        return (Id) comptes[0].get('Id');
    }

    private static void dbg(String message) {
        System.debug(LoggingLevel.INFO, 'LC022PaiementPortail — ' + message);
    }

    /**
     * Compte régie porté par la campagne dont CampaignToken__c vaut le token fourni.
     * Motif token repris de LC020_GestionReporting (lignes ~102-131).
     *
     * Le champ lookup Account -> Campaign est résolu PAR DESCRIBE via la relation
     * enfant « Compte_Regie » (comme LC023FacturationCompteController.campaignsForCompte,
     * mais en sens inverse) pour ne pas coder « Acces_REGIE__c » en dur.
     */
    private static Id compteDuToken(String token) {
        List<Campaign> camps = [
            SELECT Id FROM Campaign WHERE CampaignToken__c = :token LIMIT 1
        ];
        if (camps.isEmpty()) return null;
        // Même pont campagne -> compte que pour l'utilisateur authentifié propriétaire
        // de campagnes : une seule implémentation, pas deux à garder synchronisées.
        return compteDeCampagnes(new Set<Id>{ camps[0].Id });
    }

    /**
     * Nom du champ lookup Account -> Campaign (aujourd'hui Acces_REGIE__c), retrouvé
     * par la relation enfant « Compte_Regie » côté Campaign.
     *
     * Pour une relation CUSTOM, getRelationshipName() renvoie le nom AVEC le suffixe
     * « __r » (Compte_Regie__r) : on normalise pour matcher dans les deux cas.
     */
    private static String champAccountVersCampagne() {
        for (Schema.ChildRelationship cr : Campaign.SObjectType.getDescribe().getChildRelationships()) {
            if (cr.getChildSObject() != Account.SObjectType || cr.getField() == null) continue;
            String relName = cr.getRelationshipName();
            if (String.isNotBlank(relName) && relName.endsWith('__r')) {
                relName = relName.removeEnd('__r');
            }
            if (relName == 'Compte_Regie') {
                return cr.getField().getDescribe().getName();
            }
        }
        return null;
    }

    private static String nomDuCompte(Id compteId) {
        List<Account> a = [SELECT Name FROM Account WHERE Id = :compteId LIMIT 1];
        return a.isEmpty() ? null : a[0].Name;
    }

    // ============================================== Validation des champs demandés

    /**
     * Valide chaque nom de champ reçu du LWC contre le describe de l'objet, et
     * retourne la liste sûre à injecter dans le SELECT.
     *
     * C'est LE garde-fou anti-injection : sans lui, la config de colonnes du LWC
     * serait un vecteur d'injection SOQL (cf. LC020_GestionReporting).
     *
     * ═══════════════════════════════════════════════════════════════════════════════
     * ⚠️  SÉCURITÉ — DETTE ASSUMÉE, À FERMER AVANT TOUTE EXPOSITION PUBLIQUE
     * ═══════════════════════════════════════════════════════════════════════════════
     * Cette méthode valide que le champ EXISTE. Elle ne valide PAS qu'il est AUTORISÉ.
     * Or la liste des champs vient du navigateur, la classe est « without sharing », et
     * aucun contrôle de FLS n'est appliqué (le profil invité n'a de toute façon aucun
     * accès à Facture__c). Le filtre Destinataire_Compte__c borne les LIGNES ; il ne
     * borne ni les COLONNES ni les objets PARENTS.
     *
     * Concrètement, un porteur de token — donc potentiellement un visiteur non
     * authentifié — peut rejouer l'appel Aura avec :
     *     champsLigne   : 'Dossier__r.PRO_Nom_Client__c,Dossier__r.CEE_Montant_Aide__c'
     *     champsFacture : 'Commentaire__c,Reference_Bancaire__c,CreatedBy.Email'
     * et lire des données personnelles de clients finaux, des commentaires internes, des
     * références bancaires et des identifiants de salariés. MAX_PROFONDEUR = 2 ouvre
     * Pro__c (361 champs), Account et User.
     *
     * DEUX FAÇONS DE FERMER (au choix, non implémentées ici sur décision du métier) :
     *   1. Field sets FS_PaiementPortail_Facture / _Ligne : n'accepter que leurs membres
     *      (Schema.FieldSetMember.getFieldPath() gère les chemins relationnels). Ajouter
     *      une colonne reste déclaratif, sans redéploiement Apex. C'est l'idiome du
     *      projet — cf. FieldSetController et les field sets FS_nouvelleFacture_*.
     *   2. Set<String> constant de chemins autorisés dans cette classe. Plus verrouillé,
     *      mais ajouter une colonne impose d'éditer le LWC ET l'Apex.
     *
     * CONDITION DE LEVÉE : tant que ce point n'est pas traité, NE PAS poser ce composant
     * sur une page communautaire accessible en invité et NE PAS activer le chemin token
     * en production. Le chemin utilisateur interne authentifié n'ajoute aucun risque
     * (il lit déjà ces objets par ailleurs).
     * ═══════════════════════════════════════════════════════════════════════════════
     *
     * Un champ invalide lève via erreurConfig() : détail nominatif pour un utilisateur
     * interne (une faute de frappe dans la config donne un message clair au lieu d'une
     * erreur SOQL opaque), message générique sinon.
     */
    private static List<String> sanitizeFields(String csv, Schema.SObjectType racine, Set<String> forces) {
        Set<String> retenus = new Set<String>();
        List<String> ordonnes = new List<String>();

        List<String> demandes = new List<String>();
        if (forces != null) demandes.addAll(forces);
        if (String.isNotBlank(csv)) demandes.addAll(csv.split(','));

        for (String brut : demandes) {
            String f = (brut == null) ? '' : brut.trim();
            if (String.isBlank(f)) continue;
            if (retenus.contains(f.toLowerCase())) continue;

            if (!FIELD_PATTERN.matcher(f).matches()) {
                throw erreurConfig('Champ invalide : « ' + f + ' ».');
            }

            List<String> segments = f.split('\\.');
            if (segments.size() > MAX_PROFONDEUR) {
                throw erreurConfig('Chemin trop profond : « ' + f + ' » (max ' +
                                   MAX_PROFONDEUR + ' niveaux).');
            }

            resoudreTerminal(f, segments, racine);   // lève si un segment n'existe pas

            retenus.add(f.toLowerCase());
            ordonnes.add(f);

            if (ordonnes.size() > MAX_CHAMPS) {
                throw erreurConfig('Trop de champs demandés (max ' + MAX_CHAMPS + ').');
            }
        }

        if (ordonnes.isEmpty()) {
            throw erreurConfig('Aucun champ demandé pour ' + racine.getDescribe().getName() + '.');
        }
        return ordonnes;
    }

    /**
     * Parcourt les segments d'un chemin en vérifiant l'existence de chacun, et renvoie
     * le describe du champ TERMINAL. Sert à la fois à la validation (§ sanitizeFields)
     * et à la détection des picklists à traduire (§ mapsPicklist) : une seule traversée
     * de référence, pas deux implémentations à garder synchronisées.
     */
    private static Schema.DescribeFieldResult resoudreTerminal(
            String complet, List<String> segments, Schema.SObjectType courant) {

        for (Integer i = 0; i < segments.size(); i++) {
            String seg = segments[i];
            Schema.DescribeSObjectResult dsr = courant.getDescribe();

            if (i == segments.size() - 1) {
                // Segment terminal : doit être un champ de l'objet courant.
                Schema.SObjectField champ = dsr.fields.getMap().get(seg.toLowerCase());
                if (champ == null) {
                    throw erreurConfig('Champ inconnu : « ' + complet + ' » — « ' + seg +
                                       ' » n\'existe pas sur ' + dsr.getName() + '.');
                }
                return champ.getDescribe();
            }

            // Segment relationnel : retrouver le champ dont le nom de relation
            // PARENT correspond (Dossier__r -> Dossier__c, RecordType -> RecordTypeId).
            Schema.SObjectType cible = null;
            for (Schema.SObjectField champ : dsr.fields.getMap().values()) {
                Schema.DescribeFieldResult dfr = champ.getDescribe();
                String rel = dfr.getRelationshipName();
                if (String.isBlank(rel) || !rel.equalsIgnoreCase(seg)) continue;
                List<Schema.SObjectType> refs = dfr.getReferenceTo();
                if (refs != null && !refs.isEmpty()) cible = refs[0];
                break;
            }
            if (cible == null) {
                throw erreurConfig('Relation inconnue : « ' + complet + ' » — « ' + seg +
                                   ' » n\'est pas une relation de ' + dsr.getName() + '.');
            }
            courant = cible;
        }
        // Inatteignable : la boucle sort forcément par le segment terminal.
        throw erreurConfig('Chemin de champ vide.');
    }

    /**
     * Map { chemin de champ -> { valeur d'API -> libellé } } pour les seules picklists.
     *
     * Sans cette traduction, l'écran afficherait « BAR_TH171- PAC Indiv » là où
     * l'utilisateur voit « 🟩BAR TH171- PAC Individuelle » partout ailleurs dans
     * Salesforce — et les listes à cocher des filtres proposeraient ces mêmes valeurs
     * brutes, méconnaissables. LC023/LC024 traduisent déjà de la même façon.
     *
     * Construite UNE fois par chemin, pas par enregistrement.
     */
    private static Map<String, Map<String, String>> mapsPicklist(
            List<String> champs, Schema.SObjectType racine) {

        Map<String, Map<String, String>> out = new Map<String, Map<String, String>>();
        for (String chemin : champs) {
            Schema.DescribeFieldResult dfr = resoudreTerminal(chemin, chemin.split('\\.'), racine);
            Schema.DisplayType t = dfr.getType();
            if (t != Schema.DisplayType.PICKLIST && t != Schema.DisplayType.MULTIPICKLIST) continue;

            Map<String, String> valeurVersLibelle = new Map<String, String>();
            for (Schema.PicklistEntry pe : dfr.getPicklistValues()) {
                valeurVersLibelle.put(pe.getValue(), pe.getLabel());
            }
            out.put(chemin, valeurVersLibelle);
        }
        return out;
    }

    // ============================================================== Aplatissement

    /**
     * Construit la map { nom d'API demandé -> valeur }, chemins pointés compris, en
     * substituant le LIBELLÉ pour les picklists.
     */
    private static Map<String, Object> extraireChamps(SObject rec, List<String> champs,
                                                      Map<String, Map<String, String>> libelles) {
        Map<String, Object> out = new Map<String, Object>();
        for (String f : champs) {
            Object v = valeurChemin(rec, f);
            Map<String, String> valeurVersLibelle = libelles.get(f);

            if (valeurVersLibelle != null && v != null) {
                String brut = String.valueOf(v);
                if (brut.contains(';')) {
                    // Multipicklist : valeurs séparées par des points-virgules.
                    List<String> libs = new List<String>();
                    for (String part : brut.split(';')) {
                        libs.add(valeurVersLibelle.containsKey(part) ? valeurVersLibelle.get(part) : part);
                    }
                    v = String.join(libs, '; ');
                } else if (valeurVersLibelle.containsKey(brut)) {
                    v = valeurVersLibelle.get(brut);
                }
                // Valeur absente de la map (option désactivée depuis) : on garde le brut
                // plutôt que d'afficher une cellule vide.
            }
            out.put(f, v);
        }
        return out;
    }

    private static Object valeurChemin(SObject rec, String chemin) {
        if (rec == null) return null;
        List<String> segments = chemin.split('\\.');
        SObject courant = rec;
        for (Integer i = 0; i < segments.size() - 1; i++) {
            courant = courant.getSObject(segments[i]);
            if (courant == null) return null;   // parent non renseigné
        }
        try {
            return courant.get(segments[segments.size() - 1]);
        } catch (Exception e) {
            return null;
        }
    }

    // ==================================================================== Erreurs

    /**
     * AuraHandledException perd son message si on ne le repose pas explicitement :
     * le LWC recevrait « Script-thrown exception ».
     */
    private static AuraHandledException erreur(String message) {
        AuraHandledException e = new AuraHandledException(message);
        e.setMessage(message);
        return e;
    }

    /**
     * Erreur de configuration de colonnes. Le détail (nom du champ fautif) n'est renvoyé
     * qu'à un utilisateur INTERNE : pour un utilisateur portail ou invité, un message qui
     * distingue « champ inconnu » de « champ valide » transforme l'endpoint en oracle
     * d'énumération du schéma. Le détail part quand même dans les logs serveur.
     */
    private static AuraHandledException erreurConfig(String detail) {
        System.debug(LoggingLevel.WARN, 'LC022PaiementPortail — config colonnes : ' + detail);
        return erreur(
            UserInfo.getUserType() == 'Standard'
                ? detail
                : 'Configuration de colonnes invalide.'
        );
    }
}