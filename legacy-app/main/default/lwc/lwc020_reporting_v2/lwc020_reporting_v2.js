import {
    LightningElement,
    track,
    api,
    wire
} from 'lwc'
import getReportingData from '@salesforce/apex/LC020_GestionReporting.getReportingData'
import compterDocuments from '@salesforce/apex/LC026_Documents.compterDocuments'
import { FR, etiquettes, traduireLabels, traduireValeurFr } from 'c/lwc000_i18n'
import {
    getRecord,
    getFieldValue
} from 'lightning/uiRecordApi';
import { signatureActivee, codeReporting } from 'c/lwc000_utils'
import userId from '@salesforce/user/Id';

const USER_PROFILE_FIELD = 'User.Profile.Name';
const USER_PAYS_FIELD = 'User.Pays__c';

/** Valeur de Pays__c déclenchant les colonnes propres à l'Espagne. */
const PAYS_ESPAGNE = 'Espagne';

/**
 * Taille des lots d'Ids envoyés à LC026_Documents.compterDocuments.
 *
 * Le comptage porte sur TOUTES les lignes du reporting et non sur la seule page
 * affichée : la pastille doit rester juste après un tri ou un changement de
 * page, sans nouvel aller-retour. Découper évite d'envoyer plusieurs milliers
 * d'Ids dans une seule requête, côté réseau comme côté SOQL.
 */
const LOT_COMPTAGE_DOCUMENTS = 500;

// ─── Caches de mémoïsation (perf) ────────────────────────────────────────────
// Stockés hors du système réactif LWC (WeakMap par instance) afin de ne PAS
// déclencher de rendu supplémentaire. Aucune incidence sur la logique :
// mêmes entrées => même résultat, simplement calculé une seule fois.
const FILTERED_DATA_CACHE = new WeakMap();
const PICKLIST_VALS_CACHE = new WeakMap();

// ─── Helpers pour le marqueur <track> ────────────────────────────────────────

// Supprime les marqueurs <track> d'un spec de champs
function stripTrack(spec) {
    return spec ? spec.replace(/<track>/gi, '') : spec
}

// Extrait les noms de champs marqués <track> pour un fieldKey donné
function parseTrackedFields(fieldKey) {
    const tracked = new Set()
    COLUMNS_CONFIG.forEach(col => {
        const spec = col[fieldKey]
        if (!spec || spec === '-') return
        spec.split(',').forEach(f => {
            const ft = f.trim()
            if (ft.includes('<track>')) {
                tracked.add(ft.replace(/<track>/gi, '').trim())
            }
        })
    })
    return tracked
}

// Profils (Profile.Name) — déclarés avant COLUMNS_CONFIG, qui les cite.
const PROFIL_SECRETAIRE = 'PORTAIL INTERNE- Secretaire';
const PROFIL_CONFIRMATEUR = 'PORTAIL INTERNE - Confirmateur';
const PROFIL_RESPO_TELEPRO = 'PORTAIL INTERNE- Responsable Telepro';
const PROFIL_CLOSER = 'PORTAIL INTERNE- Closer';
const PROFIL_ADMIN = 'Administrateur système';
const PROFIL_TP_LEADS = 'PORTAIL INTERNE- Télépro Leads';
const PROFIL_TP_DATA = 'PORTAIL INTERNE- Télépro Data';
const PROFIL_APPORTEUR = "PORTAIL INTERNE- APPORTEUR D'AFFAIRES";

const PROFILS_TELEPRO = [PROFIL_TP_LEADS, PROFIL_TP_DATA];
const PROFILS_Autres = [PROFIL_SECRETAIRE, PROFIL_CLOSER];

// Configuration des colonnes du tableau de reporting
const COLUMNS_CONFIG = [{
        i: 1,
        label: 'Date de création',
        field: 'CreatedDate',
        leadField: 'CreatedDate',
        opportunityField: 'CreatedDate',
        proField: 'Piste_Date_de_Cr_ation__c,CreatedDate',
        mobileHidden: true
    },
    {
        i: 2,
        notFilter: true,
        label: 'Date dernière modification',
        field: 'LastModifiedDate',
        leadField: 'LastModifiedDate,REP_DerniereModif__c',
        opportunityField: 'LastModifiedDate',
        proField: 'LastModifiedDate,REP_DerniereModif__c'
    },
    {
        i: 3,
        label: "Apporteur d'Affaire",
        field: 'ApporteurAffaire',
        leadField: 'NonREGIE_miniAppAff__c,NonREGIE_miniAppAff2__c,Campagne_REGIE__r.CampaignToken__c',
        opportunityField: '-',
        proField: 'Nom_REGIE__c,Nom_REGIE_2__c,Campagne_REGIE__r.CampaignToken__c'
    },
    {
        i: 4,
        label: 'Nom client- Societe',
        field: 'NomClient',
        leadField: 'Name,FirstName,LastName',
        opportunityField: 'Name',
        proField: 'PRO_Nom_Client__c,PRO_Nom_du_Signataire__c'
    },
    {
        i: 5,
        label: 'Téléphone',
        field: 'Phone',
        leadField: 'Phone',
        opportunityField: '-',
        proField: 'Phone__c'
    },
    // Colonnes réservées à certains profils : `profils` liste ceux qui les
    // voient (colonne ET filtre) ; masquées pour tous les autres. Voir
    // colonnesProfil. Ouvrir une colonne à un profil = l'ajouter ici, rien d'autre.
    // Sur la Piste, le télépro est porté par ConfirmateurLookup__c (libellé
    // « LOOKUP- Telepro ») ; LOOKUP_Telepro__c n'existe que sur Pro__c. Le
    // Responsable Télépro ne voit que des Pistes : pas de champ côté Dossier.
    {
        i: 5.1,
        isPicklist: true,
        profils: [PROFIL_RESPO_TELEPRO, PROFIL_CONFIRMATEUR],
        label: 'Nom Télépro',
        field: 'NomTelepro',
        leadField: 'ConfirmateurLookup__r.Name',
        opportunityField: '-',
        proField: '-'
    },
    {
        i: 5.2,
        isPicklist: true,
        profils: [PROFIL_RESPO_TELEPRO],
        label: 'Confirmateur',
        field: 'Confirmateur',
        leadField: 'Confirmateurs__r.Name',
        opportunityField: '-',
        proField: '-'
    },
    // « DR- Cotation 060 » : formule texte, n'existe que sur Lead.
    {
        i: 5.3,
        isPicklist: true,
        profils: [PROFIL_RESPO_TELEPRO],
        label: 'Note',
        field: 'Note',
        leadField: 'DR_Cotation_06__c',
        opportunityField: '-',
        proField: '-'
    },
    {
        i: 7,
        notFilter: true,
        label: 'Infos Confirmation',
        field: 'InfosConfirmation',
        leadField: 'REGIE_Commentaire_Regie__c<track>,CONFIRM_Traitement__c<track>,CONFIRM_Commentaire__c<track>',
        opportunityField: '-',
        proField: '-'
    },
    {
        i: 9,
        label: 'Type Fiche CEE',
        field: 'TypeFicheCEE',
        leadField: '-',
        opportunityField: '-',
        proField: 'Fiche_CEE__c'
    },
    // Statut du devis — colonne d'ACTION, réservée à l'Espagne (voir
    // afficheStatutDevis), et filtrable : c'est elle qui, en Espagne, prend la
    // place de « Type Fiche CEE » dans les filtres (voir hiddenFiltersPays).
    // Écart d'API assumé : RES_Statut_Devis__c n'existe QUE sur Lead ; sur Pro__c
    // le champ qui porte les mêmes valeurs est devisfinal__c.
    {
        i: 9.5,
        isPicklist: true,
        label: 'Statut Devis',
        field: 'StatutDevis',
        leadField: 'RES_Statut_Devis__c',
        opportunityField: '-',
        proField: 'devisfinal__c',
        // Champs LUS par la cellule mais jamais affiches tels quels. Ils ne
        // peuvent pas rejoindre leadField/proField : _celluleStatutDevis y
        // attend une valeur unique, et un spec multi-champs les concatenerait.
        // TypeDeDossier__c / Fiche_CEE__c portent la FICHE PRODUIT, qui decide
        // si la signature est active et quels reglages s'appliquent. Ils etaient
        // requetes par la colonne « Type Client », retiree depuis : sans ce
        // rattrapage la colonne Statut Devis se viderait pour toutes les Pistes.
        leadFieldExtra: 'YS_Date_Signature__c,YS_Nb_Relances__c,TypeDeDossier__c',
        proFieldExtra: 'YS_Date_Signature__c,YS_Nb_Relances__c'
    },
    // { i: 10, label: "Type de Travaux", field:"TypeTravaux", leadField: "-", opportunityField: "-", proField: "type__c" },
    {
        i: 10,
        isPicklist: true,
        label: 'Statut Confirmation',
        field: 'Etape1StatutConfirmateur',
        leadField: 'CONFIRM_Traitement__c',
        opportunityField: '-',
        proField: '-',
        skipLead: true
    },
    {
        i: 11,
        isPicklist: true,
        label: 'Statut Admin',
        field: 'Etape11StatutAdmin',
        leadField: 'CONFIRM_Traitement__c',
        opportunityField: '-',
        proField: 'Pr_visite_Date_Passage__c,PAC_Statut_MPR__c,PREVISITE_Statut__c ,Pr_visite_Statut__c,DR_Infos_Doss__c,AUDIT_N_c_ssit__c,RENO_Statut_Audit__c,Devis_Statut__c,Montant_RAC_c__c'
    },
    {
        i: 12,
        isPicklist: true,
        label: 'Statut Installation',
        field: 'Etape2StatutSecretariat',
        leadField: '-',
        opportunityField: '-',
        proField: 'INSTALLATIONN_PAC__c,PAC_STATUT_DOSSIER__c'
    },
    // { i: 12, label: "Informations Dossier", field:"Etape3StatutInstallation", leadField: "-", opportunityField: "-", proField: "PAC_Date_d_Installation__c,MPR_PRECARITE__c,MPR_SHAB__c,PRO_LED_Date_d_installation__c,MPR_Docs__c" },
    {
        i: 13,
        notFilter: true,
        label: 'Informations Dossier--- old',
        field: 'Etape3StatutInstallation',
        leadField: '-',
        opportunityField: '-',
        proField: 'Bareme_Ma_prim_renovv__c,PAC_Date_d_Installation__c,MPR_PRECARITE__c,MPR_SHAB__c,Surface_habitablee__c,MPR_Pose_Fictif__c,PAC_179_Nb_Logements__c,PAC_Date_d_Installation__c,DESTRAT_142_Qt_Pr_vue__c,PAC_Date_d_Installation__c,DESTRAT_142_Qt_Final__c,PAC_Date_d_Installation__c'
    },
    {
        i: 133,
        label: 'Informations Dossier',
        field: 'Etape3InfosInstallation',
        leadField: '-',
        opportunityField: '-',
        proField: 'PAC_Date_d_Installation__c,MPR_PRECARITE__c,MPR_SHAB__c,MPR_Pose_Fictif__c,PAC_179_Nb_Logements__c,DESTRAT_142_Qt_Pr_vue__c,DESTRAT_142_Qt_Final__c,PREVISITE_Date__c,DR_Zone__c'
    },
    {
        i: 14,
        isPicklist: true,
        label: 'Statut Paiement',
        field: 'Etape4StatutPaiement',
        leadField: '-',
        opportunityField: '-',
        proField: '-'
    },
    {
        i: 14,
        notFilter: true,
        label: 'Com2 Com1',
        field: 'InformationsInstallation',
        leadField: '-',
        opportunityField: '-',
        proField: 'REGIE_Commentaire_REGIE__c<track>,Confirmateur_Commentaire__c<track>,RDV_Motif_Annulation__c<track>,CEE_Commentaire_Secr_taire__c<track>,MPR_Docs__c<track>,RDV_Commentaire_Annulation__c<track>,PAC_171_Commentaire_Interne__c<track>,DR_Infos_Doss__c<track>,RENO_Statut_Audit__c<track>,Devis_Statut__c<track>,Montant_RAC_c__c<track>'
    }
    // { i: 13, notFilter: true, label: "Informations Installation", field:"InformationsInstallation", leadField: "-", opportunityField: "-", proField: "-" },
]

/**
 * Les trois états d'un devis, dans l'ordre du CYCLE DE VIE et non par ordre
 * alphabétique : c'est ainsi qu'on les lit dans une liste à cocher.
 *
 * `cle` est ce que la cellule stocke et ce sur quoi le filtre compare ;
 * `libelle` n'est qu'une clé de dictionnaire, résolue au rendu. Y figer le
 * texte traduit rendrait la liste sourde à un changement de langue.
 */
const ETATS_DEVIS = [
    { cle: 'generer', libelle: 'devisFiltreGenerer' },
    { cle: 'attente', libelle: 'devisFiltreAttente' },
    { cle: 'signe', libelle: 'devisFiltreSigne' }
];

export default class Lwc020_reporting_v2 extends LightningElement {
    // Langue d'affichage, poussee par lwc020_CampagneContainer.
    _langue = FR;
    @api
    get langue() {
        return this._langue;
    }
    set langue(valeur) {
        this._langue = valeur || FR;
    }

    get txt() {
        return etiquettes('reporting', this._langue);
    }

    @api isCommunityUser = false

    // Accès réduit (partenaire) : masque certains filtres + la colonne « App. Affaire »,
    // et ajoute un message dans le bandeau. Renseigné par le conteneur (isAccesReduit).
    @api accesReduit = false

    // Mini-régie (« niveau 2 ») : campagne fille sans accès réduit. Renseigné par
    // le conteneur, seul à disposer du ParentId de la campagne.
    @api miniRegie = false

    // @api campaignToken;
    _campaignCode
    @api
    get campaignCode() {
        if (this._campaignCode) return this._campaignCode
        try {
            return localStorage.getItem('renov_campaign_token')
        } catch (e) {
            return null
        }
    }
    set campaignCode(value) {
        this._campaignCode = value
    }

    /**
     * Pays de la campagne, poussé par lwc020_CampagneContainer.
     * Absent en mode utilisateur Salesforce (apporteur d'affaires) : on retombe
     * alors sur User.Pays__c — même règle que lwc020_CahierCharges.paysCourant.
     */
    @api pays;

    currentUser = {};

    // Résolue dès que le profil est connu (ou en erreur). Les lignes en
    // dépendent (App. Affaire du Responsable Télépro) : chargerDonnees
    // l'attend, faute de quoi une réponse Apex plus rapide que le wire
    // construirait les lignes avec le mauvais profil.
    _resoudreProfil;
    _profilPret = new Promise(resolve => {
        this._resoudreProfil = resolve
    });

    @wire(getRecord, {
        recordId: userId,
        // Pays__c en optionalFields et NON en fields : sans droit de lecture
        // dessus, tout le wire échouerait (Profile.Name compris) et les colonnes
        // masquées par profil réapparaîtraient à tort.
        optionalFields: [USER_PROFILE_FIELD, USER_PAYS_FIELD]
    })
    wiredCurrentUser(value) {
        this.currentUser = value || {}
        if (value && (value.data || value.error)) this._resoudreProfil()
    }

    /**
     * Attente du profil avant de construire les lignes — portail INTERNE
     * uniquement (isCommunityUser), seul cas où le profil change les lignes.
     *
     * ⚠️ JAMAIS pour l'accès par token de campagne : l'utilisateur est alors
     * l'invité du site, et getRecord sur lui ne répond jamais — le tableau
     * restait bloqué sur « Chargement » (bug du 2026-09-25).
     * Plafond de 3 s dans tous les cas : un wire muet ne doit pas figer l'écran.
     */
    _attendreProfil() {
        if (!this.isCommunityUser) return Promise.resolve()
        return Promise.race([
            this._profilPret,
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            new Promise(resolve => setTimeout(resolve, 3000))
        ])
    }

    get paysCourant() {
        return this.pays || getFieldValue(this.currentUser.data, USER_PAYS_FIELD) || null
    }

    /**
     * Colonne « Statut Devis » : visible dès qu'une ligne porte une fiche qui
     * gère la signature (`signature.statut` dans c/lwc000_utils).
     *
     * ⚠️ CE N'EST PLUS LE PAYS QUI DÉCIDE. La signature n'existe aujourd'hui
     * qu'en Espagne parce que seule une fiche espagnole la déclare — pas parce
     * que le code regarde le pays. Activer une fiche française suffira
     * désormais à faire apparaître la colonne, sans toucher à ce composant.
     *
     * JAMAIS en accès réduit : les partenaires recommandent des clients, ils
     * ne pilotent pas le devis ni sa signature — France comme Espagne.
     */
    get afficheStatutDevis() {
        if (this.accesReduit === true) return false
        return (this.reportingData || []).some(l => l.StatutDevis && l.StatutDevis.actif)
    }

    get profilCourant() {
        return getFieldValue(this.currentUser.data, USER_PROFILE_FIELD)
    }

    // Responsable Télépro : voit « Nom Télépro » + « Confirmateur » à la place
    // de « Téléphone » + « Type Fiche CEE » (colonnes ET filtres).
    get isRespoTelepro() {
        return this.profilCourant === PROFIL_RESPO_TELEPRO
    }

    /**
     * Visibilité des colonnes réservées (champ `profils` de COLUMNS_CONFIG),
     * indexée par `field` : { NomTelepro: true, Confirmateur: false, … }.
     * Le template lit `colonnesProfil.<field>`, le filtre suit la même règle
     * (hiddenFiltersProfil).
     */
    get colonnesProfil() {
        const visibles = {}
        COLUMNS_CONFIG
            .filter(col => col.profils)
            .forEach(col => {
                visibles[col.field] = col.profils.includes(this.profilCourant)
            })
        return visibles
    }

    get hidePhone() {
        return [PROFIL_APPORTEUR, PROFIL_RESPO_TELEPRO, PROFIL_CONFIRMATEUR].includes(this.profilCourant)
    }

    /**
     * Colonne « App. Affaire » — masquée (desktop + mobile) :
     *   • en accès réduit : le partenaire EST l'apporteur, la colonne ne lui
     *     apprendrait rien ;
     *   • pour le Télépro Leads : il travaille sur les Pistes qui lui sont
     *     nominativement rattachées, l'apporteur ne fait pas partie de son
     *     périmètre de lecture.
     * Le Responsable Télépro la VOIT, mais au niveau 1 seulement (voir
     * creerLigneLead).
     */
    get hideApporteur() {
        return this.accesReduit === true
            || this.profilCourant === PROFIL_TP_LEADS
    }

    // Accès réduit ou Responsable Télépro : masque la colonne « Type Fiche CEE »
    // (desktop + mobile).
    get hideTypeFicheCEE() {
        return this.accesReduit === true || this.isRespoTelepro
    }

    /**
     * Colonne « Docs » — masquee en acces reduit, France comme Espagne.
     *
     * Le partenaire recommande des clients ; le suivi des pieces jointes se
     * traite entre la regie et le siege. La pastille ouvre en outre
     * c/lwc026_documents, qui exige un token de campagne : la masquer evite
     * aussi de proposer une action qui ne le concerne pas.
     */
    get hideDocs() {
        return this.accesReduit === true
    }

    /**
     * « Statut Paiement » n'appartient qu'au NIVEAU 1.
     *
     * Le règlement se traite entre la régie mère et le siège : ni la mini-régie
     * (niveau 2) ni le partenaire (accès réduit) n'ont à le lire. Formulé en
     * positif : la colonne ne subsiste que pour une campagne mère sans accès
     * réduit — c'est-à-dire pour la régie elle-même.
     *
     * Le FILTRE disparaît avec la colonne (voir hiddenFiltersNiveau) : garder de
     * quoi filtrer sur une donnée qu'on ne montre plus laisserait un moyen
     * détourné de la lire, ligne par ligne, en observant ce qui reste affiché.
     */
    get hideStatutPaiement() {
        return this.miniRegie === true || this.accesReduit === true
    }

    // Partenaire (accès réduit) : message d'invitation visible TANT QU'aucun RDV n'existe
    // dans la table (compte brut, hors filtres) ; masqué dès qu'il y a au moins un dossier.
    get showPartnerEmptyMsg() {
        return this.accesReduit
            && !this.isLoading
            && (!this.reportingData || this.reportingData.length === 0)
    }

    showMobileBanner = true
    reportingData = []
    isLoading = false
    error = null
    // Libelles traduits au rendu ; COLUMNS_CONFIG reste de la pure config.
    get columns() {
        return traduireLabels(COLUMNS_CONFIG, this._langue, 'reporting')
    }

    // Filtres
    isFilterOpen = true
    filterType = ''
    filters = {}
    picklistState = {}
    // Tooltip InfosConfirmation
    tooltip = {
        visible: false,
        fields: [],
        style: ''
    }
    // Tri
    sortField = 'lastModifiedDate'
    sortDir = 'desc'
    // Pagination
    currentPage = 1
    pageSizeValue = '26'

    get pageSize() {
        return this.pageSizeValue === 'tous' ?
            this.filteredData.length || 1 :
            parseInt(this.pageSizeValue, 10)
    }

    get pageSizeOptions() {
        return [{
                label: '26',
                value: '26',
                selected: this.pageSizeValue === '26'
            },
            {
                label: '50',
                value: '50',
                selected: this.pageSizeValue === '50'
            },
            {
                label: '100',
                value: '100',
                selected: this.pageSizeValue === '100'
            },
            {
                label: this.txt.tous,
                value: 'tous',
                selected: this.pageSizeValue === 'tous'
            }
        ]
    }

    handlePageSizeChange(event) {
        event.stopPropagation()
        this.pageSizeValue = event.target.value
        this.currentPage = 1
    }

    // Filtres masqués pour les partenaires (accès réduit).
    get hiddenFiltersAccesReduit() {
        return ['ApporteurAffaire', 'TypeFicheCEE', 'Etape3InfosInstallation']
    }

    /**
     * Filtres écartés selon le pays.
     *
     * En Espagne, « Statut Devis » prend la place de « Type Fiche CEE » : la
     * typologie de fiche CEE est un dispositif français, et c'est l'avancement
     * du devis qui structure le suivi espagnol. Ailleurs l'inverse — la colonne
     * Statut Devis n'y est de toute façon pas affichée.
     */
    get hiddenFiltersPays() {
        const masques = []
        if (this.paysCourant === PAYS_ESPAGNE) masques.push('TypeFicheCEE')
        // Le filtre suit la COLONNE, pas le pays : proposer de filtrer sur un
        // état qu'aucune ligne n'affiche n'aurait pas de sens.
        if (!this.afficheStatutDevis) masques.push('StatutDevis')
        return masques
    }

    // Filtres écartés selon le niveau de campagne — voir hideStatutPaiement.
    get hiddenFiltersNiveau() {
        return this.hideStatutPaiement ? ['Etape4StatutPaiement'] : []
    }

    /**
     * Filtres écartés selon le PROFIL.
     *
     * Le filtre suit la colonne : proposer de filtrer sur une donnée qu'on
     * n'affiche pas laisserait un moyen détourné de la lire, ligne par ligne,
     * en observant ce qui subsiste.
     */
    get hiddenFiltersProfil() {
        const masques = this.hideApporteur ? ['ApporteurAffaire'] : []
        if (this.isRespoTelepro) masques.push('Phone', 'TypeFicheCEE')
        // Confirmateur : le filtre Téléphone suit la colonne masquée.
        if (this.profilCourant === PROFIL_CONFIRMATEUR) masques.push('Phone')
        const visibles = this.colonnesProfil
        Object.keys(visibles)
            .filter(field => !visibles[field])
            .forEach(field => masques.push(field))
        return masques
    }

    // Liste des filtres pour le template
    get filterFields() {
        return traduireLabels(COLUMNS_CONFIG, this._langue, 'reporting')
            .filter(col => !col.notFilter)
            .filter(col => !this.hiddenFiltersPays.includes(col.field))
            .filter(col => !this.hiddenFiltersNiveau.includes(col.field))
            .filter(col => !this.hiddenFiltersProfil.includes(col.field))
            .filter(col => !(this.accesReduit && this.hiddenFiltersAccesReduit.includes(col.field)))
            .map(col => {
            const state = this.picklistState[col.field] || {}
            const selectedVals = this.filters[col.field] || []
            const options = col.isPicklist ?
                this._getPicklistOptions(col.field, state.search || '') :
                []
            return {
                key: col.field,
                label: col.label,
                value: this.filters[col.field] || '',
                isPicklist: col.isPicklist || false,
                options,
                hasOptions: options.length > 0,
                isOpen: !!state.isOpen,
                searchText: state.search || '',
                displayLabel: col.isPicklist && selectedVals.length > 0 ?
                    `${selectedVals.length} sélectionné(s)` :
                    col.label,
                wrapperClass: 'picklist-wrapper' + (state.isOpen ? ' picklist-wrapper--open' : ''),
                itemClass: 'filter-item' + (col.mobileHidden ? ' filter-item--desktop-only' : '')
            }
        })
    }

    // Liste triée des valeurs distinctes d'une colonne, calculée une seule fois
    // par jeu de données puis réutilisée à chaque rendu (cache invalidé dès que
    // reportingData change de référence).
    _getPicklistDistinct(fieldName) {
        let cache = PICKLIST_VALS_CACHE.get(this)
        if (!cache || cache.data !== this.reportingData) {
            cache = {
                data: this.reportingData,
                byField: {}
            }
            PICKLIST_VALS_CACHE.set(this, cache)
        }
        if (cache.byField[fieldName]) return cache.byField[fieldName]
        const vals = new Set()
        this.reportingData.forEach(ligne => {
            const cell = ligne[fieldName]
            if (cell && cell.badges) {
                cell.badges.forEach(b => {
                    if (b.value && b.value !== '-') vals.add(b.value)
                })
            } else {
                const v = cell && (cell.filterValue || cell.value)
                if (v && v !== '-') vals.add(v)
            }
        })
        const sorted = [...vals].sort()
        cache.byField[fieldName] = sorted
        return sorted
    }

    _getPicklistOptions(fieldName, search = '') {
        const selected = this.filters[fieldName] || []
        const presents = this._getPicklistDistinct(fieldName)
        // « Statut Devis » ne se filtre pas sur un libellé mais sur un ÉTAT : la
        // cellule stocke une clé stable, le texte n'est résolu qu'ici. Les lignes
        // ne sont pas reconstruites quand l'utilisateur change de langue ; ce
        // détour est ce qui évite une liste restée en français.
        let options = fieldName === 'StatutDevis' ?
            ETATS_DEVIS
                .filter(e => presents.includes(e.cle))
                .map(e => ({
                    label: this.txt[e.libelle],
                    value: e.cle,
                    selected: selected.includes(e.cle)
                })) :
            presents.map(v => ({
                label: v,
                value: v,
                selected: selected.includes(v)
            }))
        if (search) {
            const s = search.toLowerCase()
            options = options.filter(o => o.label.toLowerCase().includes(s))
        }
        return options
    }

    // Icône de l'accordion
    get accordionIcon() {
        return this.isFilterOpen ? 'utility:chevrondown' : 'utility:chevronright'
    }

    // Nombre de filtres actifs
    get activeFilterCount() {
        let count = 0
        if (this.filterType) count++
        Object.values(this.filters).forEach(v => {
            if (Array.isArray(v) ? v.length > 0 : v) count++
        })
        return count
    }

    get hasActiveFilters() {
        return this.activeFilterCount > 0
    }

    get filterCountLabel() {
        return (
            this.activeFilterCount +
            ' filtre' +
            (this.activeFilterCount > 1 ? 's' : '') +
            ' actif' +
            (this.activeFilterCount > 1 ? 's' : '')
        )
    }

    // Toggle accordion
    handleToggleFilter() {
        this.isFilterOpen = !this.isFilterOpen
    }

    // Changement d'un filtre colonne (texte)
    handleFilterChange(event) {
        const key = event.target.dataset.key
        const val = event.target.value
        this.filters = {
            ...this.filters,
            [key]: val
        }
        this.currentPage = 1
    }

    // Stoppe la propagation pour les clics à l'intérieur du wrapper picklist
    handlePicklistWrapperClick(event) {
        event.stopPropagation()
    }

    // Ouvre/ferme le dropdown picklist
    handlePicklistToggle(event) {
        event.stopPropagation()
        const key = event.currentTarget.dataset.key
        const current = this.picklistState[key] || {}
        const newState = {}
        Object.keys(this.picklistState).forEach(k => {
            newState[k] = {
                ...this.picklistState[k],
                isOpen: false
            }
        })
        newState[key] = {
            ...current,
            isOpen: !current.isOpen
        }
        this.picklistState = newState
    }

    // Recherche dans le dropdown picklist
    handlePicklistSearch(event) {
        event.stopPropagation()
        const key = event.target.dataset.key
        const current = this.picklistState[key] || {}
        this.picklistState = {
            ...this.picklistState,
            [key]: {
                ...current,
                search: event.target.value,
                isOpen: true
            }
        }
    }

    // Coche/décoche une option picklist
    handlePicklistOptionChange(event) {
        event.stopPropagation()
        const key = event.target.dataset.key
        const val = event.target.value
        const checked = event.target.checked
        const current = Array.isArray(this.filters[key]) ?
            [...this.filters[key]] :
            []
        const updated = checked ? [...current, val] : current.filter(v => v !== val)
        this.filters = {
            ...this.filters,
            [key]: updated
        }
        this.currentPage = 1
    }

    // Changement du filtre Type
    handleTypeFilterChange(event) {
        this.filterType = event.target.value
        this.currentPage = 1
    }

    // Réinitialiser tous les filtres
    handleClearFilters(event) {
        event.stopPropagation()
        this.filters = {}
        this.filterType = ''
        this.picklistState = {}
        this.currentPage = 1
        const selectEl = this.template.querySelector('[data-id="typeFilter"]')
        if (selectEl) selectEl.value = ''
        this.template.querySelectorAll('.filter-input').forEach(input => {
            input.value = ''
        })
    }

    // Données filtrées + triées
    // Mémoïsé : les entrées (reportingData, filterType, filters, sortField,
    // sortDir) sont toujours réassignées en bloc par les handlers, donc
    // l'égalité de référence suffit pour savoir si le résultat tient encore.
    get filteredData() {
        if (!this.reportingData) return []
        const cache = FILTERED_DATA_CACHE.get(this)
        if (
            cache &&
            cache.data === this.reportingData &&
            cache.filterType === this.filterType &&
            cache.filters === this.filters &&
            cache.sortField === this.sortField &&
            cache.sortDir === this.sortDir
        ) {
            return cache.result
        }
        const filtered = this.reportingData.filter(ligne => {
            if (this.filterType && ligne.type !== this.filterType) return false
            for (const key of Object.keys(this.filters)) {
                const searchVal = this.filters[key]
                if (!searchVal || (Array.isArray(searchVal) && searchVal.length === 0))
                    continue
                const col = COLUMNS_CONFIG.find(c => c.field === key)
                if (!col) continue
                const cell = ligne[col.field]
                if (cell && cell.badges) {
                    if (Array.isArray(searchVal)) {
                        const badgeVals = cell.badges.map(b =>
                            (b.value || '').toLowerCase()
                        )
                        if (!searchVal.some(s => badgeVals.includes(s.toLowerCase())))
                            return false
                    }
                } else {
                    const cellVal = String(
                        (cell && (cell.filterValue || cell.value)) || ''
                    ).toLowerCase()
                    if (Array.isArray(searchVal)) {
                        if (!searchVal.map(s => s.toLowerCase()).includes(cellVal))
                            return false
                    } else {
                        if (!cellVal.includes(searchVal.toLowerCase())) return false
                    }
                }
            }
            return true
        })

        let result
        if (!this.sortField) {
            result = filtered
        } else {
            const dir = this.sortDir === 'asc' ? 1 : -1
            result = [...filtered].sort((a, b) => {
                const va = this._sortValue(a, this.sortField)
                const vb = this._sortValue(b, this.sortField)
                const aEmpty = va === '' || va === 0 || va === null || va === undefined || va === '-'
                const bEmpty = vb === '' || vb === 0 || vb === null || vb === undefined || vb === '-'
                if (aEmpty && !bEmpty) return 1 // a vide => toujours en dernier
                if (!aEmpty && bEmpty) return -1 // b vide => toujours en dernier
                if (va < vb) return -1 * dir
                if (va > vb) return 1 * dir
                return 0
            })
        }

        // Mémorise le résultat : tant que les entrées gardent la même référence,
        // les ~20 lectures de filteredData par rendu réutilisent ce calcul.
        FILTERED_DATA_CACHE.set(this, {
            data: this.reportingData,
            filterType: this.filterType,
            filters: this.filters,
            sortField: this.sortField,
            sortDir: this.sortDir,
            result
        })
        return result
    }

    // Tranche affichée (pagination)
    get paginatedData() {
        const start = (this.currentPage - 1) * this.pageSize
        return this.filteredData.slice(start, start + this.pageSize)
    }

    get totalPages() {
        return Math.max(1, Math.ceil(this.filteredData.length / this.pageSize))
    }
    get totalRecords() {
        return this.filteredData.length
    }
    get startRecord() {
        return this.filteredData.length === 0 ?
            0 :
            (this.currentPage - 1) * this.pageSize + 1
    }
    get endRecord() {
        return Math.min(this.currentPage * this.pageSize, this.filteredData.length)
    }
    get pageInfo() {
        return `${this.currentPage} / ${this.totalPages}`
    }
    get isPrevDisabled() {
        return this.currentPage <= 1
    }
    get isNextDisabled() {
        return this.currentPage >= this.totalPages
    }

    // Icônes de tri par colonne
    get sortIcons() {
        const mk = k => ({
            icon: this.sortField === k ?
                this.sortDir === 'asc' ?
                'utility:arrowup' :
                'utility:arrowdown' :
                'utility:sort',
            cls: this.sortField === k ? 'sort-icon sort-icon--active' : 'sort-icon'
        })
        return {
            type: mk('type'),
            createdDate: mk('createdDate'),
            lastModifiedDate: mk('lastModifiedDate'),
            apporteur: mk('apporteur'),
            typeFicheCEE: mk('typeFicheCEE'),
            nomClient: mk('nomClient'),
            phone: mk('phone'),
            nomTelepro: mk('nomTelepro'),
            confirmateur: mk('confirmateur'),
            note: mk('note'),
            etape1: mk('etape1'),
            etape11: mk('etape11'),
            typeTravaux: mk('typeTravaux'),
            etape2: mk('etape2'),
            etape3: mk('etape3'),
            etape4: mk('etape4')
        }
    }

    // Clic sur un th : tri
    handleSort(event) {
        const key = event.currentTarget.dataset.sortkey
        if (!key) return
        // Ignore si l'utilisateur clique sur la zone de resize (bord droit ±7px)
        const th = event.currentTarget
        if (event.clientX >= th.getBoundingClientRect().right - 7) return
        if (this.sortField === key) {
            this.sortDir = this.sortDir === 'asc' ? 'desc' : 'asc'
        } else {
            this.sortField = key
            this.sortDir = 'asc'
        }
        this.currentPage = 1
    }

    handlePagePrev() {
        if (this.currentPage > 1) this.currentPage--
    }
    handlePageNext() {
        if (this.currentPage < this.totalPages) this.currentPage++
    }

    // Valeur comparable pour le tri
    _parseSortDate(str) {
        if (!str) return 0
        const p = str.split('/')
        return p.length === 3 ?
            new Date(
                parseInt(p[2], 10),
                parseInt(p[1], 10) - 1,
                parseInt(p[0], 10)
            ).getTime() :
            0
    }

    _sortValue(ligne, key) {
        switch (key) {
            case 'type':
                return (ligne.type || '').toLowerCase()
            case 'createdDate':
                return this._parseSortDate(ligne.CreatedDate?.value)
            case 'lastModifiedDate':
                return this._parseSortDate(ligne.LastModifiedDate?.value)
            case 'apporteur':
                return (ligne.ApporteurAffaire?.valueApporteur || '').toLowerCase()
            case 'typeFicheCEE':
                return (ligne.TypeFicheCEE?.value || '').toLowerCase()
            case 'nomClient':
                return (ligne.NomClient?.value || '').toLowerCase()
            case 'phone':
                return (ligne.Phone?.value || '').toLowerCase()
            case 'nomTelepro':
                return (ligne.NomTelepro?.value || '').toLowerCase()
            case 'confirmateur':
                return (ligne.Confirmateur?.value || '').toLowerCase()
            case 'note':
                return (ligne.Note?.value || '').toLowerCase()
            case 'etape1':
                return (ligne.Etape1StatutConfirmateur?.value || '').toLowerCase()
            case 'etape11': {
                const cell11 = ligne.Etape11StatutAdmin
                if (!cell11) return ''
                if (cell11.badges)
                    return cell11.badges
                        .map(b => b.value || '')
                        .join(' ')
                        .toLowerCase()
                        .trim()
                return (cell11.value || '').toLowerCase()
            }
            case 'typeTravaux':
                return (ligne.TypeTravaux?.value || '').toLowerCase()
            case 'etape2':
                return (ligne.Etape2StatutSecretariat?.value || '').toLowerCase()
            case 'etape3':
                // retirer les symboles comme ✔️❌ pour le tri
                const cleanVal = (ligne.Etape3InfosInstallation?.value || '').replace(/[^\w\s]/gi, '') || "";
                return cleanVal.toLowerCase()
            case 'etape4':
                return (ligne.Etape4StatutPaiement?.value || '').toLowerCase()
            default:
                return ''
        }
    }

    // Génère automatiquement les métadonnées à partir de COLUMNS_CONFIG
    buildMetadata() {
        const leadFields = new Set(['Id'])
        const opportunityFields = new Set(['Id'])
        const proFields = new Set(['Id'])

        // Helper : éclate un spec multi-champs, retire <track>, alimente le Set
        const addFields = (spec, set) => {
            if (!spec || spec === '-') return
            spec.split(',').forEach(f => {
                const clean = stripTrack(f.trim())
                if (clean) set.add(clean)
            })
        }

        COLUMNS_CONFIG.forEach(col => {
            if (!col.skipLead) {
                addFields(col.leadField, leadFields)
                addFields(col.leadFieldExtra, leadFields)
            }
            if (!col.skipOpportunity)
                addFields(col.opportunityField, opportunityFields)
            if (!col.skipPro) {
                addFields(col.proField, proFields)
                addFields(col.proFieldExtra, proFields)
            }
        })

        const leadTracked = parseTrackedFields('leadField')
        const proTracked = parseTrackedFields('proField')

        return {
            champsLead: [...leadFields].join(','),
            champsOpportunite: [...opportunityFields].join(','),
            champsPro: [...proFields].join(','),
            champsLeadTracked: leadTracked.size ? [...leadTracked].join(',') : '',
            champsProTracked: proTracked.size ? [...proTracked].join(',') : '',
            campaignCode: this.campaignCode || '',
            isCommunityUser: this.isCommunityUser
        }
    }

    // Chargement des données au montage du composant
    connectedCallback() {
        try {
            if (localStorage.getItem('mobileWarningDismissed') === 'true') {
                this.showMobileBanner = false
            }
        } catch (e) {
            /* localStorage indisponible */
        }
        this.chargerDonnees()
        this._scrollHandler = () => this._repositionTooltip()
        window.addEventListener('scroll', this._scrollHandler, true)
        this._outsideClickHandler = e => this._handleOutsideClick(e)
        document.addEventListener('click', this._outsideClickHandler, false)
    }

    handleDismissMobileBanner() {
        this.showMobileBanner = false
        try {
            localStorage.setItem('mobileWarningDismissed', 'true')
        } catch (e) {
            /* */
        }
    }

    disconnectedCallback() {
        if (this._scrollHandler) {
            window.removeEventListener('scroll', this._scrollHandler, true)
        }
        if (this._outsideClickHandler) {
            document.removeEventListener('click', this._outsideClickHandler, false)
        }
        if (this._resizerMoveHandler) {
            document.removeEventListener('mousemove', this._resizerMoveHandler)
            document.removeEventListener('mouseup', this._resizerUpHandler)
            document.body.style.cursor = ''
            document.body.style.userSelect = ''
        }
    }

    _handleOutsideClick() {
        // Ferme tous les dropdowns picklist ouverts (les clics internes sont bloqués par stopPropagation)
        const hasOpenPicklist = Object.values(this.picklistState).some(
            s => s.isOpen
        )
        if (hasOpenPicklist) {
            const newState = {}
            Object.keys(this.picklistState).forEach(k => {
                newState[k] = {
                    ...this.picklistState[k],
                    isOpen: false
                }
            })
            this.picklistState = newState
        }

        // Ferme le tooltip si clic en dehors (les clics internes sont bloqués par stopPropagation)
        if (this.tooltip.visible) {
            this.tooltip = {
                visible: false,
                fields: [],
                style: ''
            }
        }
    }

    // Appel Apex et transformation des données
    chargerDonnees() {
        this.isLoading = true
        this.error = null
        const metadata = this.buildMetadata()
        // console.log("Metadata générée :", JSON.stringify(metadata));
        Promise.all([getReportingData({
                metadata
            }), this._attendreProfil()])
            .then(([result]) => {
                // console.log("Données chargées :", JSON.stringify(result));
                this.reportingData = this.transformerDonnees(result)
                this.isLoading = false
                // Les pastilles « Documents » arrivent APRÈS le tableau : leur
                // comptage ne doit jamais retarder l'affichage des données.
                this.chargerCompteursDocuments()
            })
            .catch(error => {
                console.error('Erreur lors de l"appel Apex :', error)
                console.error(
                    'Erreur lors du chargement des données :',
                    JSON.stringify(error)
                )
                this.error = error.body ?
                    error.body.message :
                    'Erreur lors du chargement des données'
                this.isLoading = false
            })
    }

    // Fusionne les 3 listes en une seule liste unifiée
    transformerDonnees(result) {
        const lignes = []

        // ── Construire les maps d'historique ────────────────────────────────
        // { [recordId]: { [fieldName]: isoDateString } }
        const leadHistoryMap = {}
        if (result.leadHistory) {
            result.leadHistory.forEach(h => {
                if (!leadHistoryMap[h.recordId]) leadHistoryMap[h.recordId] = {}
                leadHistoryMap[h.recordId][h.fieldName] = h.lastModified
            })
        }

        const proHistoryMap = {}
        if (result.proHistory) {
            result.proHistory.forEach(h => {
                if (!proHistoryMap[h.recordId]) proHistoryMap[h.recordId] = {}
                proHistoryMap[h.recordId][h.fieldName] = h.lastModified
            })
        }

        // Transformer les Leads
        if (result.leads) {
            result.leads.forEach(record => {
                lignes.push(this.creerLigneLead(record, leadHistoryMap))
            })
        }

        // Transformer les Dossiers Pro__c
        if (result.dossiers) {
            result.dossiers.forEach(record => {
                lignes.push(this.creerLignePro(record, proHistoryMap))
            })
        }

        return lignes
    }

    // ─── Helpers partagés ────────────────────────────────────────────────────

    // Traverse un chemin pointé ("ApporteurAffaires__r.Name") sur un objet
    _resolvePath(obj, path) {
        return path.split('.').reduce((o, k) => (o != null ? o[k] : undefined), obj)
    }

    /**
     * Cellule « Statut Devis ».
     *
     * Les valeurs de picklist diffèrent entre Lead (« 🟦En Att Signature ») et
     * Pro__c (« 🟦En Attente Signature ») : on compare donc sur la valeur
     * débarrassée de ses espaces, jamais sur le libellé exact. Même normalisation
     * que LC021_DevisSignature.codeStatut, à laquelle cette cellule doit rester
     * cohérente.
     */
    _celluleStatutDevis(valeurBrute, dateSignature, nbRelances, fiche) {
        const cle = String(valeurBrute || '').replace(/\s/g, '').toLowerCase()

        // ⚠️ AUCUN libellé n'est stocké ici, uniquement l'ÉTAT.
        //
        // Les lignes sont construites une fois au chargement et ne sont pas
        // reconstruites quand l'utilisateur change de langue : y figer un texte
        // traduit laissait des cellules en espagnol dans une interface repassée
        // en français. Le template résout le libellé au rendu, via `txt` — qui
        // est un getter, donc réévalué à chaque bascule.
        const estSigne = cle.includes('signé') || cle.includes('signe');

        const estAttente = cle.includes('attsignature') || cle.includes('attentesignature');

        return {
            // La FICHE decide. Une ligne dont le produit ne gere pas la
            // signature n'affiche rien dans cette colonne, meme si ses
            // voisines l'affichent : le reporting melange les produits.
            actif: signatureActivee(fiche),
            estSigne: estSigne,
            estAttente: estAttente,
            // Ce que LIT le filtre. Une clé d'état, jamais un libellé : la Piste
            // dit « En Att Signature » là où le Dossier dit « En Attente
            // Signature », et filtrer sur le texte brut proposerait deux entrées
            // pour un seul et même état.
            filterValue: estSigne ? 'signe' : (estAttente ? 'attente' : 'generer'),
            // Valeur vide comprise : un devis pas encore renseigné est à générer.
            estGenerer: !estSigne && !estAttente,
            // Date formatee ICI et non dans le gabarit : un getter ne peut pas
            // recevoir la ligne courante d'une boucle for:each.
            dateSignature: this._dateLisible(dateSignature),
            // Le premier envoi n'est pas une relance : rien a afficher tant que
            // le compteur est a zero, d'ou le null plutot que le 0.
            //
            // Rien non plus une fois le devis SIGNE : le nombre de relances
            // racontait l'attente, et cette attente est terminee. L'afficher
            // encore ne ferait que charger la ligne d'une information sans
            // suite.
            nbRelances: (!estSigne && Number(nbRelances) > 0) ? Number(nbRelances) : null
        }
    }

    /** Horodatage Salesforce -> « 26/08/2026 19:17 ». Chaine vide si absent. */
    _dateLisible(valeur) {
        if (!valeur) return ''
        const d = new Date(valeur)
        if (isNaN(d.getTime())) return ''
        return d.toLocaleString(this.langue === 'es' ? 'es-ES' : 'fr-FR', {
            day: '2-digit', month: '2-digit', year: 'numeric',
            hour: '2-digit', minute: '2-digit'
        })
    }

    // Lit un fieldSpec depuis le record (gère "-", chemins pointés, multi-champs, <track>)
    _getVal(record, fieldSpec) {
        if (!fieldSpec || fieldSpec === '-') return ''
        const spec = stripTrack(fieldSpec)
        if (spec.includes(',')) {
            return spec
                .split(',')
                .map(f => String(this._resolvePath(record, f.trim()) ?? ''))
                .filter(v => v)
                .join(' | ')
        }
        const val = this._resolvePath(record, spec)
        return val != null ? String(val) : ''
    }

    _formatDate(val) {
        if (!val) return ''
        const d = new Date(val)
        const dd = String(d.getDate()).padStart(2, '0')
        const mm = String(d.getMonth() + 1).padStart(2, '0')
        return `${dd}/${mm}/${d.getFullYear()}`
    }

    _formatDateTime(val, format = 'dd/mm/yyyy hh:mm') {
        if (!val) return ''
        const d = new Date(val)
        const dd = String(d.getDate()).padStart(2, '0')
        const mm = String(d.getMonth() + 1).padStart(2, '0')
        const hh = String(d.getHours()).padStart(2, '0')
        const min = String(d.getMinutes()).padStart(2, '0')
        if (!format || format === 'dd/mm/yyyy hh:mm') {
            return `${dd}/${mm}/${d.getFullYear()} ${hh}:${min}`
        } else if (format === 'dd/mm/yyyy') {
            return `${dd}/${mm}/${d.getFullYear()}`
        } else if (format === 'hh:mm') {
            return `${hh}:${min}`
        }
        // return `${dd}/${mm}/${d.getFullYear()} ${hh}:${min}`
    }

    /**
     * Construit une valeur concaténée à partir d'une liste de configs de champs.
     *
     * Chaque entrée de `infoFields` accepte :
     *   field       {string}  - API name du champ Salesforce
     *   label       {string}  - (optionnel) préfixe affiché avant la valeur, ex: "Zone"
     *   hideIfEmpty {boolean} - si true, ignore ce champ quand la valeur est vide
     *   format      {string}  - 'date' pour formater en JJ/MM/AAAA
     *   replaceVal  {Array}   - [{ from, to }] substitue la valeur :
     *                           match exact (espaces ignorés) ou partiel
     *   showIf      {object}  - condition d'affichage :
     *                           { field, isEmpty: true }   → affiche seulement si ce champ est vide
     *                           { field, notEmpty: true }  → affiche seulement si ce champ est rempli
     *                           { field, equals: 'val' }   → affiche seulement si ce champ = 'val'
     *
     * @param {object} record      - l'enregistrement Salesforce
     * @param {Array}  infoFields  - tableau de configs (voir ci-dessus)
     * @param {string} separator   - séparateur entre les parties (défaut ' / ')
     * @returns {string}
     */
    _buildInfoFields(record, infoFields, separator = ' / ') {
        const parts = []
        for (const cfg of infoFields) {
            // Condition showIf
            if (cfg.showIf) {
                const condVal = this._getVal(record, cfg.showIf.field)
                if ('isEmpty' in cfg.showIf && cfg.showIf.isEmpty && condVal) continue
                if ('notEmpty' in cfg.showIf && cfg.showIf.notEmpty && !condVal)
                    continue
                if ('equals' in cfg.showIf && condVal !== cfg.showIf.equals) continue
                if ('notEquals' in cfg.showIf && condVal === cfg.showIf.notEquals)
                    continue
            }
            let val = this._getVal(record, cfg.field)
            // replaceVal: [{ from, to }] → substitue la valeur si elle correspond
            if (cfg.replaceVal && Array.isArray(cfg.replaceVal) && val) {
                for (const r of cfg.replaceVal) {
                    if (r.from == null) continue
                    if (String(val).trim() === String(r.from).trim()) {
                        // correspondance exacte (insensible aux espaces)
                        val = r.to
                        break
                    }
                    if (String(val).includes(r.from)) {
                        // correspondance partielle → remplace l'occurrence
                        val = String(val).split(r.from).join(r.to)
                    }
                }
            }
            // hideIfEmpty: true → masque si vide
            if (cfg.hideIfEmpty && !val) continue
            // Formatage date
            if (cfg.format === 'date' && val) {
                const d = new Date(val)
                const dd = String(d.getDate()).padStart(2, '0')
                const mm = String(d.getMonth() + 1).padStart(2, '0')
                val =
                    cfg.formatDate === 'jj/mm' ?
                    `${dd}/${mm}` :
                    `${dd}/${mm}/${d.getFullYear()}`
            }
            // prefix / label / suffix
            if (val || !cfg.hideIfEmpty) {
                const display = val || '-'
                const withPrefix = cfg.prefix ?
                    `${cfg.prefix}${display}` :
                    cfg.label ?
                    `${cfg.label}: ${display}` :
                    display
                parts.push(cfg.suffix ? `${withPrefix}${cfg.suffix}` : withPrefix)
            }
        }
        return parts.join(separator)
    }

    _statusClass(val) {
        if (!val) return ''
        return (
            'badge status-' +
            val
            .toLowerCase()
            .normalize('NFD')
            .replace(/[\u0300-\u036f]/g, '')
            .replace(/\s+/g, '-')
        )
    }

    // ─── Ligne Piste ─────────────────────────────────────────────────────────
    // Boucle sur COLUMNS_CONFIG.leadField avec conditions d'affichage explicites
    mapStatus = [
        {
            contain: 'EN ATT DE TRAITEMENT',
            val: 'Nouveau Dossier',
            regex: /EN ATT DE TRAITEMENT/i,
            badgeBG: '#D9D9D9'
        },
        {
            contain: '1x|2x|3x|4x|5x',
            val: 'Traitement en Cours',
            regex: /[1-5]x/i,
            badgeBG: '#FFF2CC'
        },
        {
            contain: '6x|7x',
            val: 'Injoignable- Nrp x7',
            regex: /[6-7]x/i,
            badgeBG: '#FFD966'
        },
        {
            contain: 'Rappel Nécessaire',
            val: 'Rappel Nécessaire',
            regex: /A Rappeler/i,
            badgeBG: '#A4C2F4'
        },
        {
            contain: 'HORS CIBLE',
            val: 'Hors Cible',
            regex: /HORS CIBLE/i,
            badgeBG: '#EA9999'
        },
        {
            contain: 'Confirmation Ok',
            val: 'Confirmation Ok',
            regex: /Confirmation Ok/i,
            badgeBG: '#B6D7A8'
        },
        {
            contain: '🟩Conf Ok- Att prévisite',
            val: 'Confirmation Ok - Att prévisite',
            regex: /🟩Conf Ok- Att prévisite/i,
            badgeBG: '#B6D7A8'
        }
    ]
    creerLigneLead(record, historyMap = {}) {
        const ligne = {
            isLead: true,
            id: record.Id,
            type: 'Piste',
            typeCssClass: 'badge badge-piste',
            // Pastille documents à 0 dès la construction : le comptage arrive
            // dans un second temps, et le template ne doit jamais lire une
            // cellule absente.
            Documents: this._celluleDocuments(0)
        }

        COLUMNS_CONFIG.forEach(col => {
            // Champ non applicable aux Pistes → vide
            const fieldsToSkip = [
                'Etape3StatutInstallation',
                'Etape11StatutAdmin',
                'Etape2StatutSecretariat'
            ]
            if (fieldsToSkip.includes(col.field)) {
                ligne[col.field] = {
                    value: '-',
                    customCSS: '',
                    customClass: ''
                }
                return
            } else if (col.field === 'StatutDevis') {
                // Les champs annexes sont lus NOMMEMENT : leadFieldExtra est une
                // liste, et _getVal la concatenerait en une seule chaine.
                ligne.StatutDevis = this._celluleStatutDevis(
                    this._getVal(record, ligne.isLead ? col.leadField : col.proField),
                    this._getVal(record, 'YS_Date_Signature__c'),
                    this._getVal(record, 'YS_Nb_Relances__c'),
                    // Le champ portant la fiche differe selon l'objet : code
                    // exact sur la Piste, libelle sur le Dossier.
                    this._getVal(record, ligne.isLead ? 'TypeDeDossier__c' : 'Fiche_CEE__c')
                )
                return
            } else if (col.field == 'NomClient') {
                const nomClient = this._getVal(record, 'Name')
                const lastNameClient = this._getVal(record, 'LastName')
                const nomTruncated =
                    nomClient.length > 30 ? nomClient.substring(0, 30) + '...' : nomClient
                const nomTruncatedMobile =
                    lastNameClient.length > 12 ?
                    lastNameClient.substring(0, 12) + '...' :
                    lastNameClient
                ligne.NomClient = {
                    value: nomClient,
                    desktopValue: nomTruncated,
                    valueMobile: nomTruncatedMobile
                }
                return
            } else if (col.field == 'TypeFicheCEE') {
                try {
                    const typeFicheCEE = this._getVal(record, 'TypeDeDossier__c')
                    // console.log("typeFicheCEE : ", JSON.stringify(typeFicheCEE));
                    const fiches = [
                        'TH171- PAC Indiv',
                        'TH174- Réno Glob',
                        'TH175- Réno Globale Appart',
                        'TH179- PAC Collec',
                        'EQ127- LEDS',
                        'TH142- Déstrat'
                    ]

                    // // Ex : RESIDENTIEL_REGIES_-_BAR TH171;RESIDENTIEL_REGIES_-_BAR TH174 => [BAR TH171,BAR TH174]
                    const typeFicheCEEList = typeFicheCEE?.split(';') || []
                    // console.log("typeFicheCEEList : ", JSON.stringify(typeFicheCEEList));

                    // `codeProduitReporting` de la fiche PRIME sur l'extraction
                    // du code technique : certaines fiches doivent s'afficher
                    // autrement que ce que leur codeProduit laisse lire — la
                    // EQ112 joue le role du 110 depuis un changement
                    // d'etiquette. A defaut, la logique d'origine s'applique.
                    const typeFicheCEEValues = typeFicheCEEList.map(t =>
                        codeReporting(t)
                        || (t.includes('_-_') ? t.split('_-_')[1].trim() : '')
                    )
                    // console.log("typeFicheCEEValues : ", JSON.stringify(typeFicheCEEValues));
                    let selFiche = ''
                    if (typeFicheCEEValues.length === 1) {
                        selFiche =
                            fiches.find(f => f.startsWith(typeFicheCEEValues[0])) ||
                            typeFicheCEEValues[0]
                    } else if (typeFicheCEEValues.length > 1) {
                        selFiche = typeFicheCEEValues.join('+')
                    }
                    // Show each one in badge:
                    ligne.TypeFicheCEE = {
                        value: selFiche || '-'
                    }
                } catch (e) {
                    console.error('Erreur lors du traitement de TypeFicheCEE', e)
                    ligne.TypeFicheCEE = {
                        value: '-',
                        isBadge: false
                    }
                }
                return
            } else if (col.field == 'TypeClient') {
                const typeClient = this._getVal(record, 'TypeDeDossier__c')
                const types = [{
                        starts: 'RESIDENTIEL',
                        type: 'Résidentiel'
                    },
                    {
                        starts: 'BAT',
                        type: 'Tertiaire'
                    },
                    {
                        starts: 'AGRI',
                        type: 'Agriculture'
                    }
                ]
                const type =
                    types.find(t => typeClient?.startsWith(t.starts))?.type || '-'
                ligne.TypeClient = {
                    value: type
                }
                return
            } else if (col.field == 'ApporteurAffaire') {
                const apporteur = this._getVal(record, 'NonREGIE_miniAppAff__c')
                const miniAppAff = this._getVal(record, 'NonREGIE_miniAppAff2__c')
                const campaignToken = this._getVal(
                    record,
                    'Campagne_REGIE__r.CampaignToken__c'
                )
                // console.log("campaignToken from lead : ", JSON.stringify(campaignToken));
                // console.log("campaignCode from component : ", JSON.stringify(this.campaignCode));
                //
                // let colVal = {
                //     valueApporteur: apporteur || '-',
                //     styleApporteur: "font-weight: 600; color: #4A86F0;",
                //     valueMiniAppAff: miniAppAff,
                //     styleMiniAppAff: miniAppAff ? "font-style: italic; color: #EA6666;" : "display: none;"
                // }
                //
                // Responsable Télépro : régie de NIVEAU 1 uniquement (campagne
                // mère). `apporteur` = niveau 1, `miniAppAff` = niveau 2 —
                // vérifié sur les données : Nom REGIE = Campagne_REGIE__r.Parent.Name.
                if (this.isRespoTelepro) {
                    ligne.ApporteurAffaire = {
                        value: apporteur || '-',
                        style: 'font-weight: 600; text-transform: uppercase; color: #4A86F0;'
                    }
                    return
                }
                let colVal = {
                    // value: campaignToken == this.campaignCode ? apporteur : miniAppAff,
                    value: miniAppAff || apporteur,
                    // style: campaignToken == this.campaignCode ? "font-weight: 600; text-transform: uppercase; color: #4A86F0;" : "font-weight: 600; text-transform: uppercase; font-style: italic; color: #EA6666;"
                    style: campaignToken == this.campaignCode ?
                        'font-weight: 600; text-transform: uppercase; color: #4A86F0;' :
                        'font-weight: 600; text-transform: uppercase; font-style: italic; color: #EA6666;'
                }
                ligne.ApporteurAffaire = colVal
                return
            } else if (col.field == 'Etape1StatutConfirmateur') {
                const val = this._getVal(record, col.leadField)
                if (val) {
                    // check the val if part of the contain of the mapStatus and return the val of the mapStatus
                    const mapped = this.mapStatus.find(m => m.regex.test(val))
                    ligne.Etape1StatutConfirmateur = {
                        value: mapped ? mapped.val : val,
                        customCSS: mapped ? `background-color: ${mapped.badgeBG};` : '',
                        customClass: mapped ? 'badge' : ''
                    }
                    return
                }
                // ligne.Etape1StatutConfirmateur = { value: val, customCSS: this._statusClass(val) };
                return
            } else if (col.field === 'InfosConfirmation') {
                // → Champs individuels avec labels lisibles pour le tooltip
                const valConf = this._getVal(record, 'CONFIRM_Traitement__c')
                const mapConfSt = this.mapStatus.find(m => m.regex.test(valConf)) || {
                    val: '',
                    badgeBG: '',
                    regex: null
                }
                const recHistory = historyMap[record.Id] || {}
                let fields = [{
                        label: '💬Commentaire Régie:',
                        value: this._getVal(record, 'REGIE_Commentaire_Regie__c'),
                        lastModified: this._formatDateTime(this._getVal(record, "CreatedDate"))
                        // recHistory['REGIE_Commentaire_Regie__c']
                        //     ? this._formatDateTime(recHistory['REGIE_Commentaire_Regie__c'])
                        //     : null
                    },
                    {
                        label: '⬛Motif Annulation:',
                        value: mapConfSt.val,
                        lastModified: recHistory['CONFIRM_Traitement__c'] ?
                            this._formatDateTime(recHistory['CONFIRM_Traitement__c']) :
                            null,
                        condition: r => this._getVal(r, 'CONFIRM_Traitement__c')?.includes('HORS CIBLE'),
                        customCSS: 'margin-top: 1rem;',
                    },
                    {
                        label: '💬Commentaire Confirmateur:',
                        value: this._getVal(record, 'CONFIRM_Commentaire__c'),
                        lastModified: recHistory['CONFIRM_Commentaire__c'] ?
                            this._formatDateTime(recHistory['CONFIRM_Commentaire__c']) :
                            null
                    }
                ].filter(f => f.value);
                const fieldToShow = fields.filter(r => !r.condition || r.condition(record)) || [];
                // const fieldToShow = fields;
                ligne.InfosConfirmation = {
                    title: 'Informations Confirmation',
                    value: fieldToShow.map(f => f.value).join(' | '),
                    hasData: fieldToShow.length > 0,
                    nombreCommentaires: fieldToShow.length,
                    fields: fieldToShow
                }
                return
            } else if (col.field === 'LastModifiedDate') {
                // REP_DerniereModif__c if empty then CreatedDate
                const valLastModifiedDateP = this._getVal(record, 'REP_DerniereModif__c') || this._getVal(record, 'LastModifiedDate');
                ligne.LastModifiedDate = {
                    value: this._formatDate(valLastModifiedDateP) || '-'
                }
                // ligne.LastModifiedDate = { value: "test" }
                return
            } else if (col.skipLead || col.leadField === '-') {
                ligne[col.field] = {
                    value: '-'
                }
                return
            }

            const raw = this._getVal(record, col.leadField)

            if (col.field === 'CreatedDate') {
                // → Date formatée
                ligne[col.field] = {
                    value: this._formatDate(raw) || '-'
                }
            } else if (
                col.field === 'Etape1StatutConfirmateur' ||
                col.field === 'Etape2StatutSecretariat' ||
                col.field === 'Etape3StatutInstallation'
            ) {
                // → Badge statut coloré
                ligne[col.field] = {
                    value: raw || '-',
                    customCSS: raw ? this._statusClass(raw) : ''
                }
            } else {
                // → Texte brut (inclut multi-champs via _getVal)
                ligne[col.field] = {
                    value: raw || '-'
                }
            }
        })

        return ligne
    }

    mapStatusII = [
        {
            contains: 'BAR_TH174',
            // voir statut dossier => si annulé renvoi directement Annule => Com2 Ajout  : RDV Mofitif anullaton
            fieldCheckIfNotClosed: 'PAC_STATUT_DOSSIER__c',
            valueClosedToCheck: '⚫DOSSIER- Annulé',
            badgeBGAnnule: '#ff6464',
            field: 'INSTALLATIONN_PAC__c',
            defaultVal: {
                value: '-',
                badgeBG: '',
                customClass: ''
            },
            statusMap: {
                '🟨Date Planifiée': {
                    value: 'Date Planifiée',
                    badgeBG: '#FFD966',
                    customClass: 'badge'
                },
                '🟧Installation Non Finalisée': {
                    value: 'Installation Non Finalisée',
                    badgeBG: '#FE9B4A',
                    customClass: 'badge'
                },
                '🟩Installation Cloturée': {
                    value: 'Installation OK',
                    badgeBG: '#B6D7A8',
                    customClass: 'badge'
                }
            },
            infoFields: [
                // Starts : Pareil pour toutes les fiches
                {
                    field: 'DR_Zone__c',
                    hideIfEmpty: true,
                    // showIf: {
                    //     field: 'MPR_PRECARITE__c',
                    //     notEquals: '▣ En attente'
                    // }
                },
                {
                    field: 'MPR_PRECARITE__c',
                    hideIfEmpty: true,
                    // prefix: '(Dossier)',
                    showIf: {
                        field: 'MPR_PRECARITE__c',
                        notEquals: '▣ En attente'
                    }
                },
                {
                    field: 'Bareme_Ma_prim_renovv__c',
                    hideIfEmpty: true,
                    // prefix: '(Piste)',
                    showIf: {
                        field: 'MPR_PRECARITE__c',
                        equals: '▣ En attente'
                    },
                    replaceVal: [
                        { from: 'Bleu', to: '🟦BLEU' },
                        { from: 'Jaune ', to: '🟨JAUNE' },
                        { from: 'Violet', to: '🟪VIOLET' },
                        { from: 'Rose', to: '🟥ROSE' }
                    ]
                },
                 // Spécifique BAR_TH171
                {
                    field: 'MPR_SHAB__c',
                    hideIfEmpty: true,
                    prefix: '🏠',
                    suffix: 'm²'
                },
                {
                    field: 'Surface_habitablee__c',
                    hideIfEmpty: true,
                    prefix: '🏠',
                    suffix: 'm²',
                    showIf: {
                        field: 'MPR_SHAB__c',
                        isEmpty: true
                    }
                },
                {
                    field: 'PREVISITE_Date__c',
                    hideIfEmpty: true,
                    prefix: '🚗Prév: ',
                    format: 'date',
                    formatDate: 'jj/mm'
                },
                {
                    field: 'PAC_Date_d_Installation__c',
                    hideIfEmpty: true,
                    prefix: '🛠️Install : ',
                    format: 'date',
                    formatDate: 'jj/mm',
                    // showIf: {
                    //     field: 'MPR_Pose_Fictif__c',
                    //     isEmpty: true
                    // }
                },
                // {
                //     field: 'MPR_Pose_Fictif__c',
                //     hideIfEmpty: true,
                //     prefix: '🛠️Install Réelle: ',
                //     format: 'date',
                //     formatDate: 'jj/mm' /*,showIf: { field: 'MPR_Pose_Fictif__c', notEmpty: true }*/
                // },
                // End : Pareil pour toutes les fiches

            ],
            infoSeparator: ' -' // séparateur personnalisable par fiche
        },
        {
            contains: 'BAR_TH171',
            field: 'INSTALLATIONN_PAC__c',
            fieldCheckIfNotClosed: 'PAC_STATUT_DOSSIER__c',
            valueClosedToCheck: '⚫DOSSIER- Annulé',
            badgeBGAnnule: '#ff6464',
            defaultVal: {
                value: '-',
                displayValue: ' ',
                badgeBG: '',
                customClass: ''
            },
            statusMap: {
                // '🟪Chantier PréValidé':         { value: '-', badgeBG: ''},
                '🟨Date Planifiée': {
                    value: 'Date Planifiée',
                    badgeBG: '#FFD966',
                    customClass: 'badge'
                },
                '🟧Installation Non Finalisée': {
                    value: 'Installation Non Finalisée',
                    badgeBG: '#FE9B4A',
                    customClass: 'badge'
                },
                '🟩Installation Cloturée': {
                    value: 'Installation OK',
                    badgeBG: '#B6D7A8',
                    customClass: 'badge'
                }
            },
            // ─── Etape3InfosInstallation ──────────────────────────────────────────
            // Chaque entrée : { field, label?, hideIfEmpty?, format?, showIf? }
            // showIf : { field, isEmpty | notEmpty | equals }
            infoFields: [
                // Starts : Pareil pour toutes les fiches
                {
                    field: 'DR_Zone__c',
                    hideIfEmpty: true,
                    // showIf: {
                    //     field: 'MPR_PRECARITE__c',
                    //     notEquals: '▣ En attente'
                    // }
                },
                {
                    field: 'MPR_PRECARITE__c',
                    hideIfEmpty: true,
                    // prefix: '(Dossier)',
                    showIf: {
                        field: 'MPR_PRECARITE__c',
                        notEquals: '▣ En attente'
                    }
                },
                {
                    field: 'Bareme_Ma_prim_renovv__c',
                    hideIfEmpty: true,
                    // prefix: '(Piste)',
                    showIf: {
                        field: 'MPR_PRECARITE__c',
                        equals: '▣ En attente'
                    },
                    replaceVal: [
                        { from: 'Bleu', to: '🟦BLEU' },
                        { from: 'Jaune ', to: '🟨JAUNE' },
                        { from: 'Violet', to: '🟪VIOLET' },
                        { from: 'Rose', to: '🟥ROSE' }
                    ]
                },
                 // Spécifique BAR_TH171
                {
                    field: 'MPR_SHAB__c',
                    hideIfEmpty: true,
                    prefix: '🏠',
                    suffix: 'm²'
                },
                {
                    field: 'Surface_habitablee__c',
                    hideIfEmpty: true,
                    prefix: '🏠',
                    suffix: 'm²',
                    showIf: {
                        field: 'MPR_SHAB__c',
                        isEmpty: true
                    }
                },
                {
                    field: 'PREVISITE_Date__c',
                    hideIfEmpty: true,
                    prefix: '🚗Prév: ',
                    format: 'date',
                    formatDate: 'jj/mm'
                },
                {
                    field: 'PAC_Date_d_Installation__c',
                    hideIfEmpty: true,
                    prefix: '🛠️Install : ',
                    format: 'date',
                    formatDate: 'jj/mm',
                    // showIf: {
                    //     field: 'MPR_Pose_Fictif__c',
                    //     isEmpty: true
                    // }
                },
                // {
                //     field: 'MPR_Pose_Fictif__c',
                //     hideIfEmpty: true,
                //     prefix: '??️Install Réelle: ',
                //     format: 'date',
                //     formatDate: 'jj/mm' /*,showIf: { field: 'MPR_Pose_Fictif__c', notEmpty: true }*/
                // },
                // End : Pareil pour toutes les fiches

               
            ],
            infoSeparator: ' -' // séparateur personnalisable par fiche
        },
        {
            contains: 'BAT_EQ127',
            field: 'INSTALLATIONN_PAC__c',
            fieldCheckIfNotClosed: 'PAC_STATUT_DOSSIER__c',
            valueClosedToCheck: '⚫DOSSIER Annulé',
            badgeBGAnnule: '#ff6464',
            defaultVal: {
                value: '-',
                badgeBG: '',
                customClass: ''
            },
            statusMap: {
                '🟨Date Planifiée': {
                    value: 'Date Planifiée',
                    badgeBG: '#FFD966',
                    customClass: 'badge'
                },
                '🟧Installation Non Finalisée': {
                    value: 'Installation Non Finalisée',
                    badgeBG: '#FE9B4A',
                    customClass: 'badge'
                },
                '🟩Installation Cloturée': {
                    value: 'Installation OK',
                    badgeBG: '#B6D7A8',
                    customClass: 'badge'
                }
            },
            infoFields: [
                // Starts : Pareil pour toutes les fiches
                {
                    field: 'PREVISITE_Date__c',
                    hideIfEmpty: true,
                    prefix: '🚗Prév: ',
                    format: 'date',
                    formatDate: 'jj/mm'
                },
                {
                    field: 'PAC_Date_d_Installation__c',
                    hideIfEmpty: true,
                    prefix: '🛠️Install Provisoire: ',
                    format: 'date',
                    formatDate: 'jj/mm',
                    showIf: {
                        field: 'MPR_Pose_Fictif__c',
                        isEmpty: true
                    }
                },
                {
                    field: 'MPR_Pose_Fictif__c',
                    hideIfEmpty: true,
                    prefix: '🛠️Install Réelle: ',
                    format: 'date',
                    formatDate: 'jj/mm' /*,showIf: { field: 'MPR_Pose_Fictif__c', notEmpty: true }*/
                },
                // End : Pareil pour toutes les fiches
            ],
            infoSeparator: ' -' // séparateur personnalisable par fiche
        },
        {
            contains: 'BAR_TH179',
            field: 'INSTALLATIONN_PAC__c',
            fieldCheckIfNotClosed: 'PAC_STATUT_DOSSIER__c',
            valueClosedToCheck: '⚫DOSSIER- Annulé',
            badgeBGAnnule: '#ff6464',
            defaultVal: {
                value: '-',
                badgeBG: '',
                customClass: ''
            },
            statusMap: {
                '🟨Date Planifiée': {
                    value: 'Date Planifiée',
                    badgeBG: '#FFD966',
                    customClass: 'badge'
                },
                '🟧Installation Non Finalisée': {
                    value: 'Installation Non Finalisée',
                    badgeBG: '#FE9B4A',
                    customClass: 'badge'
                },
                '🟩Installation Cloturée': {
                    value: 'Installation OK',
                    badgeBG: '#B6D7A8',
                    customClass: 'badge'
                }
            },
            infoFields: [
                // Starts : Pareil pour toutes les fiches
                {
                    field: 'PREVISITE_Date__c',
                    hideIfEmpty: true,
                    prefix: '🚗Prév: ',
                    format: 'date',
                    formatDate: 'jj/mm'
                },
                {
                    field: 'PAC_Date_d_Installation__c',
                    hideIfEmpty: true,
                    prefix: '🛠️Install Provisoire: ',
                    format: 'date',
                    formatDate: 'jj/mm',
                    showIf: {
                        field: 'MPR_Pose_Fictif__c',
                        isEmpty: true
                    }
                },
                {
                    field: 'MPR_Pose_Fictif__c',
                    hideIfEmpty: true,
                    prefix: '🛠️Install Réelle: ',
                    format: 'date',
                    formatDate: 'jj/mm' /*,showIf: { field: 'MPR_Pose_Fictif__c', notEmpty: true }*/
                },
                // End : Pareil pour toutes les fiches
            ],
            infoSeparator: ' -' // séparateur personnalisable par fiche
        },
        {
            contains: 'BAT_TH142',
            field: 'INSTALLATIONN_PAC__c',
            fieldCheckIfNotClosed: 'PAC_STATUT_DOSSIER__c',
            valueClosedToCheck: '⚫DOSSIER- Annulé',
            badgeBGAnnule: '#ff6464',
            defaultVal: {
                value: '-',
                badgeBG: '',
                customClass: ''
            },
            statusMap: {
                '🟨Date Planifiée': {
                    value: 'Date Planifiée',
                    badgeBG: '#FFD966',
                    customClass: 'badge'
                },
                '🟧Installation Non Finalisée': {
                    value: 'Installation Non Finalisée',
                    badgeBG: '#FE9B4A',
                    customClass: 'badge'
                },
                '🟩Installation Cloturée': {
                    value: 'Installation OK',
                    badgeBG: '#B6D7A8',
                    customClass: 'badge'
                }
            },
            infoFields: [
                // Starts : Pareil pour toutes les fiches
                {
                    field: 'PREVISITE_Date__c',
                    hideIfEmpty: true,
                    prefix: '🚗Prév: ',
                    format: 'date',
                    formatDate: 'jj/mm'
                },
                {
                    field: 'PAC_Date_d_Installation__c',
                    hideIfEmpty: true,
                    prefix: '🛠️Install Provisoire: ',
                    format: 'date',
                    formatDate: 'jj/mm',
                    showIf: {
                        field: 'MPR_Pose_Fictif__c',
                        isEmpty: true
                    }
                },
                {
                    field: 'MPR_Pose_Fictif__c',
                    hideIfEmpty: true,
                    prefix: '🛠️Install Réelle: ',
                    format: 'date',
                    formatDate: 'jj/mm' /*,showIf: { field: 'MPR_Pose_Fictif__c', notEmpty: true }*/
                },
                // End : Pareil pour toutes les fiches
            ],
            infoSeparator: ' -' // séparateur personnalisable par fiche
        },
        // ─── BAR_TH175 - Réno Globale Appart ────────────────────────────────────
        {
            contains: 'BAR_TH175',
            field: 'INSTALLATIONN_PAC__c',
            fieldCheckIfNotClosed: 'PAC_STATUT_DOSSIER__c',
            valueClosedToCheck: '⚫DOSSIER- Annulé',
            badgeBGAnnule: '#ff6464',
            defaultVal: {
                value: '-',
                badgeBG: '',
                customClass: ''
            },
            statusMap: {
                '🟨Date Planifiée': {
                    value: 'Date Planifiée',
                    badgeBG: '#FFD966',
                    customClass: 'badge'
                },
                '🟧Installation Non Finalisée': {
                    value: 'Installation Non Finalisée',
                    badgeBG: '#FE9B4A',
                    customClass: 'badge'
                },
                '🟩Installation Cloturée': {
                    value: 'Installation OK',
                    badgeBG: '#B6D7A8',
                    customClass: 'badge'
                }
            },
            infoFields: [{
                    field: 'PREVISITE_Date__c',
                    hideIfEmpty: true,
                    prefix: '🚗Prév: ',
                    format: 'date',
                    formatDate: 'jj/mm'
                },
                {
                    field: 'PAC_Date_d_Installation__c',
                    hideIfEmpty: true,
                    prefix: '🛠️Install Provisoire: ',
                    format: 'date',
                    formatDate: 'jj/mm',
                    showIf: {
                        field: 'MPR_Pose_Fictif__c',
                        isEmpty: true
                    }
                },
                {
                    field: 'MPR_Pose_Fictif__c',
                    hideIfEmpty: true,
                    prefix: '🛠️Install Réelle: ',
                    format: 'date',
                    formatDate: 'jj/mm'
                },
            ],
            infoSeparator: ' -'
        },
        // ─── BAT_TH163 - PAC Tertiaire ──────────────────────────────────────────
        {
            contains: 'BAT_TH163',
            field: 'INSTALLATIONN_PAC__c',
            fieldCheckIfNotClosed: 'PAC_STATUT_DOSSIER__c',
            valueClosedToCheck: '⚫DOSSIER- Annulé',
            badgeBGAnnule: '#ff6464',
            defaultVal: {
                value: '-',
                badgeBG: '',
                customClass: ''
            },
            statusMap: {
                '🟨Date Planifiée': {
                    value: 'Date Planifiée',
                    badgeBG: '#FFD966',
                    customClass: 'badge'
                },
                '🟧Installation Non Finalisée': {
                    value: 'Installation Non Finalisée',
                    badgeBG: '#FE9B4A',
                    customClass: 'badge'
                },
                '🟩Installation Cloturée': {
                    value: 'Installation OK',
                    badgeBG: '#B6D7A8',
                    customClass: 'badge'
                }
            },
            infoFields: [
                // Starts : Pareil pour toutes les fiches
                {
                    field: 'PREVISITE_Date__c',
                    hideIfEmpty: true,
                    prefix: '🚗Prév: ',
                    format: 'date',
                    formatDate: 'jj/mm'
                },
                {
                    field: 'PAC_Date_d_Installation__c',
                    hideIfEmpty: true,
                    prefix: '🛠️Install Provisoire: ',
                    format: 'date',
                    formatDate: 'jj/mm',
                    showIf: {
                        field: 'MPR_Pose_Fictif__c',
                        isEmpty: true
                    }
                },
                {
                    field: 'MPR_Pose_Fictif__c',
                    hideIfEmpty: true,
                    prefix: '🛠️Install Réelle: ',
                    format: 'date',
                    formatDate: 'jj/mm' /*,showIf: { field: 'MPR_Pose_Fictif__c', notEmpty: true }*/
                },
                // End : Pareil pour toutes les fiches
            ],
            infoSeparator: ' -' // séparateur personnalisable par fiche
        },
        // ─── AGRI_EQ108 - TUBES ─────────────────────────────────────────────────
        {
            contains: 'AGRI_EQ108',
            field: 'INSTALLATIONN_PAC__c',
            fieldCheckIfNotClosed: 'PAC_STATUT_DOSSIER__c',
            valueClosedToCheck: '⚫DOSSIER- Annulé',
            badgeBGAnnule: '#ff6464',
            defaultVal: {
                value: '-',
                badgeBG: '',
                customClass: ''
            },
            statusMap: {
                '🟨Date Planifiée': {
                    value: 'Date Planifiée',
                    badgeBG: '#FFD966',
                    customClass: 'badge'
                },
                '🟧Installation Non Finalisée': {
                    value: 'Installation Non Finalisée',
                    badgeBG: '#FE9B4A',
                    customClass: 'badge'
                },
                '🟩Installation Cloturée': {
                    value: 'Installation OK',
                    badgeBG: '#B6D7A8',
                    customClass: 'badge'
                }
            },
            infoFields: [
                // Starts : Pareil pour toutes les fiches
                {
                    field: 'PREVISITE_Date__c',
                    hideIfEmpty: true,
                    prefix: '🚗Prév: ',
                    format: 'date',
                    formatDate: 'jj/mm'
                },
                {
                    field: 'PAC_Date_d_Installation__c',
                    hideIfEmpty: true,
                    prefix: '🛠️Install Provisoire: ',
                    format: 'date',
                    formatDate: 'jj/mm',
                    showIf: {
                        field: 'MPR_Pose_Fictif__c',
                        isEmpty: true
                    }
                },
                {
                    field: 'MPR_Pose_Fictif__c',
                    hideIfEmpty: true,
                    prefix: '🛠️Install Réelle: ',
                    format: 'date',
                    formatDate: 'jj/mm' /*,showIf: { field: 'MPR_Pose_Fictif__c', notEmpty: true }*/
                },
                // End : Pareil pour toutes les fiches
            ],
            infoSeparator: ' -' // séparateur personnalisable par fiche
        },
        // ─── AGRI_EQ112 - DPAROIS ───────────────────────────────────────────────
        {
            contains: 'AGRI_EQ112',
            field: 'INSTALLATIONN_PAC__c',
            fieldCheckIfNotClosed: 'PAC_STATUT_DOSSIER__c',
            valueClosedToCheck: '⚫DOSSIER- Annulé',
            badgeBGAnnule: '#ff6464',
            defaultVal: {
                value: '-',
                badgeBG: '',
                customClass: ''
            },
            statusMap: {
                '🟨Date Planifiée': {
                    value: 'Date Planifiée',
                    badgeBG: '#FFD966',
                    customClass: 'badge'
                },
                '🟧Installation Non Finalisée': {
                    value: 'Installation Non Finalisée',
                    badgeBG: '#FE9B4A',
                    customClass: 'badge'
                },
                '🟩Installation Cloturée': {
                    value: 'Installation OK',
                    badgeBG: '#B6D7A8',
                    customClass: 'badge'
                }
            },
            infoFields: [
                // Starts : Pareil pour toutes les fiches
                {
                    field: 'PREVISITE_Date__c',
                    hideIfEmpty: true,
                    prefix: '🚗Prév: ',
                    format: 'date',
                    formatDate: 'jj/mm'
                },
                {
                    field: 'PAC_Date_d_Installation__c',
                    hideIfEmpty: true,
                    prefix: '🛠️Install Provisoire: ',
                    format: 'date',
                    formatDate: 'jj/mm',
                    showIf: {
                        field: 'MPR_Pose_Fictif__c',
                        isEmpty: true
                    }
                },
                {
                    field: 'MPR_Pose_Fictif__c',
                    hideIfEmpty: true,
                    prefix: '🛠️Install Réelle: ',
                    format: 'date',
                    formatDate: 'jj/mm' /*,showIf: { field: 'MPR_Pose_Fictif__c', notEmpty: true }*/
                },
                // End : Pareil pour toutes les fiches
            ],
            infoSeparator: ' -' // séparateur personnalisable par fiche
        },
        // ─── AGRI_TH117 - DESHU ─────────────────────────────────────────────────
        {
            contains: 'AGRI_TH117',
            field: 'INSTALLATIONN_PAC__c',
            fieldCheckIfNotClosed: 'PAC_STATUT_DOSSIER__c',
            valueClosedToCheck: '⚫DOSSIER- Annulé',
            badgeBGAnnule: '#ff6464',
            defaultVal: {
                value: '-',
                badgeBG: '',
                customClass: ''
            },
            statusMap: {
                '🟨Date Planifiée': {
                    value: 'Date Planifiée',
                    badgeBG: '#FFD966',
                    customClass: 'badge'
                },
                '🟧Installation Non Finalisée': {
                    value: 'Installation Non Finalisée',
                    badgeBG: '#FE9B4A',
                    customClass: 'badge'
                },
                '🟩Installation Cloturée': {
                    value: 'Installation OK',
                    badgeBG: '#B6D7A8',
                    customClass: 'badge'
                }
            },
            infoFields: [
                // Starts : Pareil pour toutes les fiches
                {
                    field: 'PREVISITE_Date__c',
                    hideIfEmpty: true,
                    prefix: '🚗Prév: ',
                    format: 'date',
                    formatDate: 'jj/mm'
                },
                {
                    field: 'PAC_Date_d_Installation__c',
                    hideIfEmpty: true,
                    prefix: '🛠️Install Provisoire: ',
                    format: 'date',
                    formatDate: 'jj/mm',
                    showIf: {
                        field: 'MPR_Pose_Fictif__c',
                        isEmpty: true
                    }
                },
                {
                    field: 'MPR_Pose_Fictif__c',
                    hideIfEmpty: true,
                    prefix: '🛠️Install Réelle: ',
                    format: 'date',
                    formatDate: 'jj/mm' /*,showIf: { field: 'MPR_Pose_Fictif__c', notEmpty: true }*/
                },
                // End : Pareil pour toutes les fiches
            ],
            infoSeparator: ' -' // séparateur personnalisable par fiche
        },
        // ─── AGRI_TH119 - VMC ───────────────────────────────────────────────────
        {
            contains: 'AGRI_TH119',
            field: 'INSTALLATIONN_PAC__c',
            fieldCheckIfNotClosed: 'PAC_STATUT_DOSSIER__c',
            valueClosedToCheck: '⚫DOSSIER- Annulé',
            badgeBGAnnule: '#ff6464',
            defaultVal: {
                value: '-',
                badgeBG: '',
                customClass: ''
            },
            statusMap: {
                '🟨Date Planifiée': {
                    value: 'Date Planifiée',
                    badgeBG: '#FFD966',
                    customClass: 'badge'
                },
                '🟧Installation Non Finalisée': {
                    value: 'Installation Non Finalisée',
                    badgeBG: '#FE9B4A',
                    customClass: 'badge'
                },
                '🟩Installation Cloturée': {
                    value: 'Installation OK',
                    badgeBG: '#B6D7A8',
                    customClass: 'badge'
                }
            },
            infoFields: [
                // Starts : Pareil pour toutes les fiches
                {
                    field: 'PREVISITE_Date__c',
                    hideIfEmpty: true,
                    prefix: '🚗Prév: ',
                    format: 'date',
                    formatDate: 'jj/mm'
                },
                {
                    field: 'PAC_Date_d_Installation__c',
                    hideIfEmpty: true,
                    prefix: '🛠️Install Provisoire: ',
                    format: 'date',
                    formatDate: 'jj/mm',
                    showIf: {
                        field: 'MPR_Pose_Fictif__c',
                        isEmpty: true
                    }
                },
                {
                    field: 'MPR_Pose_Fictif__c',
                    hideIfEmpty: true,
                    prefix: '🛠️Install Réelle: ',
                    format: 'date',
                    formatDate: 'jj/mm' /*,showIf: { field: 'MPR_Pose_Fictif__c', notEmpty: true }*/
                },
                // End : Pareil pour toutes les fiches
            ],
            infoSeparator: ' -' // séparateur personnalisable par fiche
        }
    ]

    // ─── Ligne Dossier Pro ───────────────────────────────────────────────────
    creerLignePro(record, historyMap = {}) {
        const ligne = {
            isDossier: true,
            id: record.Id,
            type: 'Dossier',
            typeCssClass: 'badge badge-dossier',
            // Voir creerLigneLead : la cellule existe avant le comptage.
            Documents: this._celluleDocuments(0)
        }

        COLUMNS_CONFIG.forEach(col => {
            // Champ non applicable aux Pistes → vide
            const fieldsToSkip = [
                'Etape3StatutInstallation__IgnoreForNow',
                'Etape11StatutAdmin',
                'Etape4StatutPaiement'
            ]
            if (col.field === 'StatutDevis') {
                ligne.StatutDevis = this._celluleStatutDevis(
                    this._getVal(record, col.proField),
                    this._getVal(record, 'YS_Date_Signature__c'),
                    this._getVal(record, 'YS_Nb_Relances__c'),
                    this._getVal(record, 'Fiche_CEE__c')
                )
                return
            }
            if (fieldsToSkip.includes(col.field)) {
                ligne[col.field] =
                    ligne[col.field] != undefined ?
                    ligne[col.field] :
                    {
                        value: '-',
                        customCSS: '',
                        customClass: ''
                    }
                return
            } else if (col.field == 'TypeFicheCEE') {
                const typeClient = this._getVal(record, 'Fiche_CEE__c')
                // Voir le commentaire cote Piste : l'attribut de la fiche prime.
                let cleanedTypeClient = codeReporting(typeClient) || typeClient
                // BAR_xxxxx ou BAT_yyyy_jhg => supprime n'impore quoi avant la 1ere '_':
                if (typeClient.includes('_')) {
                    if(typeClient == "BAR_RES060- PAC"){
                        cleanedTypeClient = "RES060"
                    } else {
                        const partToDelete = typeClient.split('_')[0]
                        cleanedTypeClient = typeClient.replace(partToDelete + '_', '')
                    }
                    // console.log("cleanedTypeClient : ", cleanedTypeClient);
                }

                ligne.TypeFicheCEE = {
                    value: cleanedTypeClient
                }
                return
            } else if (col.field == 'Etape2StatutSecretariat') {
                let dossierAnnule = false
                const ficheCEE = this._getVal(record, 'Fiche_CEE__c')
                const matchedRule = this.mapStatusII.find(
                    rule => ficheCEE && ficheCEE.includes(rule.contains)
                )
                if (matchedRule) {
                    // console.log("matchedRule : ", JSON.stringify(matchedRule));
                    const closedVal = this._getVal(
                        record,
                        matchedRule.fieldCheckIfNotClosed
                    )

                    const rawVal = this._getVal(record, matchedRule.field)
                    // console.log("rawVal : ", JSON.stringify(rawVal));
                    const displayVal = rawVal ?
                        matchedRule.statusMap[rawVal] !== undefined ?
                        matchedRule.statusMap[rawVal] :
                        matchedRule.defaultVal :
                        matchedRule.defaultVal

                    if (closedVal === matchedRule.valueClosedToCheck) {
                        dossierAnnule = true

                        ligne.Etape2StatutSecretariat = {
                            value: 'Annulé- Voir Commentaire',
                            valueSwitch: displayVal?.value,
                            customCSS: `background-color: ${matchedRule.badgeBGAnnule};`,
                            customClass: 'badge'
                        }
                        ligne.Etape11StatutAdmin = {
                            badges: [{
                                value: '',
                                customCSS: '',
                                customClass: ''
                            }]
                        }
                        ligne.Etape3StatutInstallation = {
                            value: '-',
                            customCSS: '',
                            customClass: ''
                        }
                    } else {
                        ligne.Etape2StatutSecretariat = {
                            value: displayVal?.value || displayVal,
                            customCSS: displayVal && displayVal.badgeBG ?
                                `background-color: ${displayVal.badgeBG};` :
                                '',
                            customClass: displayVal?.customClass || ''
                        }
                    }

                    // Traité aussi Statut Admin + Infos installation :>  ["Etape3StatutInstallation", "Etape11StatutAdmin"];
                    let pacStatutMPR = ''
                    let dateInstallation = '',
                        precarite = '',
                        shab = '',
                        installation = ''
                    let nbLogements = '',
                        qtePrevu = '',
                        qteFinal = ''
                    const previsiteNecessite = this._getVal(record, 'PREVISITE_Statut__c')
                    const prvisiteStatut = this._getVal(record, 'Pr_visite_Statut__c')
                    const auditNecessite = this._getVal(record, 'AUDIT_N_c_ssit__c')
                    const auditStatut = this._getVal(record, 'RENO_Statut_Audit__c')

                    // Traitement 3 cas ICI
                    // Cas 1: Prévisite OUI + Passage Effectué + Audit NON
                    // Cas 2: Prévisite OUI + Passage Effectué + Audit OUI + Audit Validé
                    // Cas 3: Prévisite NON + Audit NON
                    const cas1 =
                        previsiteNecessite === 'OUI' &&
                        prvisiteStatut === '🟩Passage Effectué' &&
                        auditNecessite === 'NON'
                    const cas2 =
                        previsiteNecessite === 'OUI' &&
                        prvisiteStatut === '🟩Passage Effectué' &&
                        auditNecessite === 'OUI' &&
                        auditStatut === '🟩Audit- Validé'
                    const cas3 = previsiteNecessite !== 'OUI' && auditNecessite !== 'OUI'
                    const mtRAC = this._getVal(record, 'Montant_RAC_c__c');

                    const precaritePiste = this._getVal(record, 'Bareme_Ma_prim_renovv__c');
                    const precariteDossier = this._getVal(record, 'MPR_PRECARITE__c');
                    const val_shab = this._getVal(record, 'MPR_SHAB__c');
                    const val_shabPiste = this._getVal(record, 'Surface_habitablee__c');
                    const valShabPref = val_shab || val_shabPiste || 0;
                    // const valPrefere = precariteDossier && (precariteDossier !== '▣ En attente') ? precariteDossier : precaritePiste ? precaritePiste : val_shab ? `${val_shab}m²` : '';

                    const estBlueSup90 = (precariteDossier === '🟦BLEU' || (precariteDossier === '▣ En attente' && precaritePiste === 'Bleu')) && valShabPref >= 90;
                    const estBlueInf90 = (precariteDossier === '🟦BLEU' || (precariteDossier === '▣ En attente' && precaritePiste === 'Bleu')) && valShabPref < 90;
                    
                    const mprDocs = this._getVal(record, 'MPR_Docs__c')
                    const hasDossierComplet =
                                        mprDocs &&
                                        mprDocs
                                        .split(';')
                                        .map(s => s.trim())
                                        .includes('🟩Dossier Complet');
                                        
                    switch (matchedRule.contains) {
                        case 'BAR_TH174':
                            switch (ligne.Etape2StatutSecretariat.value) {
                                case '-':
                                    ligne.Etape11StatutAdmin = {
                                        badges: [
                                            // { value: 'En Attente', customCSS: 'background-color: #D9D9D9;', customClass: 'badge' }
                                        ]
                                    }
                                    ligne.Etape3StatutInstallation = {
                                        value: '-',
                                        customCSS: '',
                                        customClass: ''
                                    }
                                    ligne.Etape4StatutPaiement = {
                                        value: '-',
                                        customCSS: '',
                                        customClass: ''
                                    }
                                    break
                                case 'Date Planifiée':
                                    ligne.Etape11StatutAdmin = {
                                        badges: [{
                                            value: 'Admin Ok',
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }]
                                    }
                                    // "Installation:" PAC_Date_d_Installation__c
                                    dateInstallation = this._getVal(
                                        record,
                                        'PAC_Date_d_Installation__c'
                                    )
                                    // console.log("dateInstallation >> : ", JSON.stringify(dateInstallation));
                                    if (dateInstallation) {
                                        // console.log("dateInstallation is truthy");
                                        ligne.Etape3StatutInstallation = {
                                            value: `Installation: ${this._formatDate(
                                                dateInstallation
                                            )}`,
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }
                                    }
                                    // console.log("ligne.Etape3StatutInstallation >> : ", JSON.stringify(ligne.Etape3StatutInstallation));
                                    ligne.Etape4StatutPaiement = {
                                        value: '-',
                                        customCSS: '',
                                        customClass: ''
                                    }
                                    break
                                case 'Installation Non Finalisée':
                                    ligne.Etape11StatutAdmin = {
                                        badges: [{
                                            value: 'Admin Ok',
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }]
                                    }
                                    // "Installation:" PAC_Date_d_Installation__c
                                    dateInstallation = this._getVal(
                                        record,
                                        'PAC_Date_d_Installation__c'
                                    )
                                    if (dateInstallation) {
                                        ligne.Etape3StatutInstallation = {
                                            value: `Installation: ${this._formatDate(
                                                dateInstallation
                                            )}`,
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }
                                    }
                                    ligne.Etape4StatutPaiement = {
                                        value: '-',
                                        customCSS: '',
                                        customClass: ''
                                    }
                                    break
                                case 'Installation OK':
                                    ligne.Etape11StatutAdmin = {
                                        badges: [{
                                            value: 'Admin Ok',
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }]
                                    }
                                    // "Installation:" PAC_Date_d_Installation__c
                                    dateInstallation = this._getVal(
                                        record,
                                        'PAC_Date_d_Installation__c'
                                    )
                                    if (dateInstallation) {
                                        ligne.Etape3StatutInstallation = {
                                            value: `Installation: ${this._formatDate(
                                                dateInstallation
                                            )}`,
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }
                                    }

                                    ligne.Etape4StatutPaiement = {
                                        value: 'Vérif Comptable',
                                        customCSS: 'background-color: #D9D9D9;',
                                        customClass: 'badge'
                                    }
                                    break
                            }
                            // Previsite badge (BAR_TH171) - ajouté le badge au debut
                            if (auditNecessite === 'OUI') {
                                let auditBadge = null
                                if (
                                    auditStatut === '🟧Audit- Modifs Demandées' ||
                                    auditStatut === '▣ Nouveau Dossier' || auditStatut === '🟨Demandé'
                                ) {
                                    auditBadge = {
                                        value: 'Audit: Demandé',
                                        customCSS: 'background-color: #9FC5E8;',
                                        customClass: 'badge'
                                    }
                                } else if (auditStatut === '🟩Audit- Validé') {
                                    //! Le conditionnement est en relation avec la partie suivante
                                    auditBadge = {
                                        value: previsiteNecessite === 'OUI' &&
                                            prvisiteStatut === '🟩Passage Effectué' ?
                                            'Prévisite+Audit OK' :
                                            'Audit Ok',
                                        customCSS: 'background-color: #B6D7A8;',
                                        customClass: 'badge'
                                    }
                                }
                                if (auditBadge) {
                                    if (!ligne.Etape11StatutAdmin)
                                        ligne.Etape11StatutAdmin = {
                                            badges: []
                                        }
                                    ligne.Etape11StatutAdmin.badges.unshift(auditBadge)
                                }
                            }

                            // Previsite badge (BAR_TH171) - ajouté le badge au debut
                            if (previsiteNecessite === 'OUI' && auditNecessite !== 'OUI') {
                                let previBadge = null
                                if (
                                    prvisiteStatut === '🟨Passage Demandé' ||
                                    prvisiteStatut === '▣ Att Planification'
                                ) {
                                    previBadge = {
                                        value: 'Prévisite: Demandé',
                                        customCSS: 'background-color: #9FC5E8;',
                                        customClass: 'badge'
                                    }
                                } else if (prvisiteStatut === '🟫Passage à Replanifier') {
                                    previBadge = {
                                        value: 'Prévisite: A Replanifier',
                                        customCSS: 'background-color: #FE9B4A;',
                                        customClass: 'badge'
                                    }
                                } else if (prvisiteStatut === '🟧Passage Planifié') {
                                    const prvisiteDate = this._getVal(
                                        record,
                                        'Pr_visite_Date_Passage__c'
                                    )
                                    const dateStr = prvisiteDate ?
                                        this._formatDate(prvisiteDate) :
                                        ''
                                    previBadge = {
                                        value: `Prévisite: Planifié${dateStr ? ' ' + dateStr : ''}`,
                                        customCSS: 'background-color: #FFD966;',
                                        customClass: 'badge'
                                    }
                                } else if (prvisiteStatut === '🟩Passage Effectué') {
                                    previBadge = {
                                        value: 'Prévisite Ok',
                                        customCSS: 'background-color: #B6D7A8;',
                                        customClass: 'badge'
                                    }
                                }
                                if (previBadge) {
                                    if (!ligne.Etape11StatutAdmin)
                                        ligne.Etape11StatutAdmin = {
                                            badges: []
                                        }
                                    ligne.Etape11StatutAdmin.badges.unshift(previBadge)
                                }
                            }

                            if (cas1 || cas2 || cas3) {
                                const devisStatut = this._getVal(record, 'Devis_Statut__c')
                                let dvisBadge = null
                                if (devisStatut === '▣ Nouveau Dossier') {
                                    dvisBadge = {
                                        value: 'DEVIS: Demandé',
                                        customCSS: 'background-color: #9FC5E8;',
                                        customClass: 'badge'
                                    }
                                } else if (devisStatut === '🟦En Attente Signature') {
                                    dvisBadge = {
                                        value: 'DEVIS: Envoyé',
                                        customCSS: 'background-color: #FFD966;',
                                        customClass: 'badge'
                                    }
                                } else if (devisStatut === '🟩Signé') {
                                    dvisBadge = {
                                        value: 'DEVIS: Signature Ok',
                                        customCSS: 'background-color: #B6D7A8;',
                                        customClass: 'badge'
                                    }
                                }
                                if (dvisBadge) {
                                    if (!ligne.Etape11StatutAdmin)
                                        ligne.Etape11StatutAdmin = {
                                            badges: []
                                        }
                                    ligne.Etape11StatutAdmin.badges.push(dvisBadge)
                                }
                            }

                            // DR-Infos : si fiche non clôturée TH171, badge unique
                            if (this._getVal(record, 'DR_Infos_Doss__c') !== '✅1') {
                                ligne.Etape11StatutAdmin = {
                                    badges: [{
                                        value: dossierAnnule ?
                                            'Voir Motif Annulation TH171' :
                                            'Attente Cloture TH171⏳',
                                        customCSS: 'background-color: #D9D9D9;',
                                        customClass: 'badge'
                                    }]
                                }
                            }
                            break
                        case 'BAR_TH171':
                            switch (ligne.Etape2StatutSecretariat.value) {
                                case '-':
                                    // traitement PAC 171 here :
                                    pacStatutMPR = this._getVal(record, 'PAC_Statut_MPR__c')
                                    console.log(
                                        'pacStatutMPR >> : ',
                                        JSON.stringify(pacStatutMPR)
                                    )
                                    
                                    
                                    ligne.Etape11StatutAdmin = {
                                        badges: []
                                    };

                                    
                                    ligne.Etape2StatutSecretariatBiss = {
                                        badges: []
                                    }

                                    if (!this._getVal(record, 'MPR_Docs__c')) {
                                        if(previsiteNecessite !== 'OUI'){
                                            ligne.Etape11StatutAdmin.badges.push({
                                            id: 'docsAttente',
                                            value: 'Docs: En cours',
                                            customCSS: 'background-color: #9FC5E8;',
                                            customClass: 'badge'
                                        });
                                        }
                                        
                                    } else if (hasDossierComplet) {
                                        ligne.Etape11StatutAdmin.badges.push({
                                            id: 'docsComplet',
                                            value: 'Docs: Complet',
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        });

                                        if (estBlueSup90){
                                            ligne.Etape2StatutSecretariatBiss.badges.push({
                                                id: 'blueSup90',
                                                value: 'Planification en cours',
                                                customCSS: 'background-color: #D4AA61;',
                                                customClass: 'badge'
                                            });
                                        } else {
                                            if (pacStatutMPR === '🟩 Accordé'){
                                                ligne.Etape2StatutSecretariatBiss.badges.push({
                                                    id: 'blueSup90',
                                                    value: 'Planification en cours',
                                                    customCSS: 'background-color: #D4AA61;',
                                                    customClass: 'badge'
                                                });
                                            } else {
                                                ligne.Etape2StatutSecretariatBiss.badges.push({
                                                    id: 'blueSup90',
                                                    value: 'Att Octroi MPR',
                                                    customCSS: 'background-color: #E3BFFD;',
                                                    customClass: 'badge'
                                                });
                                            }
                                        }

                                    } else {
                                        ligne.Etape11StatutAdmin.badges.push({
                                            id: 'docsManquants',
                                            value: 'Docs: Incomplet',
                                            customCSS: 'background-color: #EA9999;',
                                            customClass: 'badge'
                                        });
                                    }
                                    // if(estBlueSup90){

                                    // } else 
                                    if (!estBlueSup90) {
                                        if (
                                            pacStatutMPR === '▣ En Attente Envoi' ||
                                            pacStatutMPR === '🟦Envoyé'
                                        ) {
                                            ligne.Etape11StatutAdmin.badges.push({
                                                id: 'mprAttEnvoi',
                                                value: 'MPR: Att Création ID',
                                                customCSS: 'background-color: #9FC5E8;',
                                                customClass: 'badge'
                                            });
                                        // }
                                        } else if (pacStatutMPR === '🟫En Att Code- Voie Postal') {
                                            ligne.Etape11StatutAdmin.badges.push({
                                                id: 'mprAttCode',
                                                value: 'MPR: Att Création ID VP',
                                                customCSS: 'background-color: #9FC5E8;',
                                                customClass: 'badge'
                                            });
                                        } else if (pacStatutMPR === '🟪Déposé') {
                                            // if (!hasDossierComplet) {
                                            //     ligne.Etape11StatutAdmin.badges.push({
                                            //         value: 'MPR: Déposé',
                                            //         customCSS: 'background-color: #E3BFFD;',
                                            //         customClass: 'badge'
                                            //     });
                                            //     ligne.Etape11StatutAdmin.badges.push({
                                            //         value: 'Docs Client Manquants',
                                            //         customCSS: 'background-color: #EA9999;',
                                            //         customClass: 'badge'
                                            //     });
                                            //         ]
                                            //     }
                                            // } else {
                                                ligne.Etape11StatutAdmin.badges.push({
                                                    id: 'mprDepose',
                                                        value: 'MPR: Déposé',
                                                        customCSS: 'background-color: #E3BFFD;',
                                                        customClass: 'badge'
                                                    });
                                            // }
                                        } else if (pacStatutMPR === '🟩 Accordé') {
                                            // if (!hasDossierComplet) {
                                            //     ligne.Etape11StatutAdmin = {
                                            //         badges: [{
                                            //                 value: 'MPR: Accordé',
                                            //                 customCSS: 'background-color: #FFD966;',
                                            //                 customClass: 'badge'
                                            //             },
                                            //             {
                                            //                 value: 'Docs Client Manquants',
                                            //                 customCSS: 'background-color: #EA9999;',
                                            //                 customClass: 'badge'
                                            //             }
                                            //         ]
                                            //     }
                                            // } else {
                                                ligne.Etape11StatutAdmin.badges.push({
                                                    id: 'mprAccorde',
                                                    value: 'MPR: Accordé',
                                                    customCSS: 'background-color: #FFD966;',
                                                    customClass: 'badge'
                                                });
                                            // }
                                        } else if (pacStatutMPR.includes('Anomalie')) {
                                            ligne.Etape11StatutAdmin.badges.push({
                                                id: 'mprAnomalie',
                                                    value: 'MPR: Anomalie',
                                                    customCSS: 'background-color: #FE9B4A;',
                                                    customClass: 'badge'
                                                });
                                        } else if (pacStatutMPR.includes('❌Full CEE')) {
                                            ligne.Etape11StatutAdmin.badges.push({
                                                id: 'mprFullCEE',
                                                value: 'Full CEE: RAC-' + (mtRAC || 0) + '€',
                                                customCSS: 'background-color: #E3BFFD;',
                                                customClass: 'badge'
                                            })
                                        }
                                    } else {

                                    }

                                    // else {
                                    //     ligne.Etape11StatutAdmin = { value: 'En Attente', customCSS: 'background-color: #D9D9D9;', customClass: 'badge' };
                                    // }

                                    // ligne.Etape3StatutInstallation = { value: '-', customCSS: '', customClass: '' };

                                    precarite = this._getVal(record, 'MPR_PRECARITE__c')
                                    shab = this._getVal(record, 'MPR_SHAB__c')
                                    installation = this._getVal(record, 'MPR_Pose_Fictif__c')
                                    if (precarite || shab || installation) {
                                        ligne.Etape3StatutInstallation = {
                                            value: `Précarité: ${precarite || ''} // Shab: ${shab || ''
                                                } m² ${installation ? '// Installation : ' + installation : ''
                                                }` /*, customCSS: 'background-color: #B6D7A8;', customClass: 'badge'*/
                                        }
                                    }

                                    ligne.Etape4StatutPaiement = {
                                        value: '-',
                                        customCSS: '',
                                        customClass: ''
                                    }

                                    break
                                case 'Date Planifiée':
                                    pacStatutMPR = this._getVal(record, 'PAC_Statut_MPR__c')

                                    ligne.Etape11StatutAdmin = {
                                        badges: []
                                    };
                                    if (!this._getVal(record, 'MPR_Docs__c')) {
                                        if(previsiteNecessite !== 'OUI'){
                                            ligne.Etape11StatutAdmin.badges.push({
                                            id: 'docsAttente',
                                            value: 'Docs: En cours',
                                            customCSS: 'background-color: #9FC5E8;',
                                            customClass: 'badge'
                                        });
                                        }
                                    } else if (hasDossierComplet) {
                                        ligne.Etape11StatutAdmin.badges.push({
                                            id: 'docsComplet',
                                            value: 'Docs: Complet',
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        });
                                    } else {
                                        ligne.Etape11StatutAdmin.badges.push({
                                            id: 'docsManquants',
                                            value: 'Docs: Incomplet',
                                            customCSS: 'background-color: #EA9999;',
                                            customClass: 'badge'
                                        });
                                    }

                                    if (!estBlueSup90) {
                                        if (pacStatutMPR === '🟪Déposé') {
                                            ligne.Etape11StatutAdmin.badges.push({
                                                    value: 'MPR: Déposé',
                                                    customCSS: 'background-color: #E3BFFD;',
                                                    customClass: 'badge'
                                                })
                                        } else if (pacStatutMPR === '🟩 Accordé') {
                                            ligne.Etape11StatutAdmin.badges.push({
                                                    value: 'MPR: Accordé',
                                                    customCSS: 'background-color: #FFD966;',
                                                    customClass: 'badge'
                                                })
                                        } else if (pacStatutMPR.includes('Anomalie')) {
                                            ligne.Etape11StatutAdmin.badges.push({
                                                value: 'MPR: Anomalie',
                                                customCSS: 'background-color: #FE9B4A;',
                                                customClass: 'badge'
                                            })
                                        }
                                    }
                                    
                                    

                                    dateInstallation = this._getVal(
                                        record,
                                        'PAC_Date_d_Installation__c'
                                    )
                                    if (dateInstallation) {
                                        ligne.Etape3StatutInstallation = {
                                            value: `Installation: ${this._formatDate(
                                                dateInstallation
                                            )}`,
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }
                                    }

                                    precarite = this._getVal(record, 'MPR_PRECARITE__c')
                                    shab = this._getVal(record, 'MPR_SHAB__c')
                                    installation = this._getVal(
                                        record,
                                        'PAC_Date_d_Installation__c'
                                    )
                                    if (precarite || shab || installation) {
                                        ligne.Etape3StatutInstallation = {
                                            value: `Précarité: ${precarite || ''} // Shab: ${shab || ''
                                                } m² // Installation :  ${installation || ''
                                                }` /*, customCSS: 'background-color: #B6D7A8;', customClass: 'badge'*/
                                        }
                                    }

                                    ligne.Etape4StatutPaiement = {
                                        value: '-',
                                        customCSS: '',
                                        customClass: ''
                                    }
                                    break
                                case 'Installation Non Finalisée':
                                    pacStatutMPR = this._getVal(record, 'PAC_Statut_MPR__c')

                                    ligne.Etape11StatutAdmin = {
                                        badges: []
                                    };
                                    if (!this._getVal(record, 'MPR_Docs__c')) {
                                        if(previsiteNecessite !== 'OUI'){
                                            ligne.Etape11StatutAdmin.badges.push({
                                            id: 'docsAttente',
                                            value: 'Docs: En cours',
                                            customCSS: 'background-color: #9FC5E8;',
                                            customClass: 'badge'
                                        });
                                        }
                                    } else if (hasDossierComplet) {
                                        ligne.Etape11StatutAdmin.badges.push({
                                            id: 'docsComplet',
                                            value: 'Docs: Complet',
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        });
                                    } else {
                                        ligne.Etape11StatutAdmin.badges.push({
                                            id: 'docsManquants',
                                            value: 'Docs: Incomplet',
                                            customCSS: 'background-color: #EA9999;',
                                            customClass: 'badge'
                                        });
                                    }

                                    if (!estBlueSup90) {
                                        if (pacStatutMPR === '🟪Déposé') {
                                            ligne.Etape11StatutAdmin.badges.push({
                                                id: 'mprDéposé',
                                                value: 'MPR: Déposé',
                                                customCSS: 'background-color: #E3BFFD;',
                                                customClass: 'badge'
                                            });
                                        } else if (pacStatutMPR === '🟩 Accordé') {
                                            ligne.Etape11StatutAdmin.badges.push({
                                                id: 'mprAccorde',
                                                value: 'MPR: Accordé',
                                                customCSS: 'background-color: #FFD966;',
                                                customClass: 'badge'
                                            });
                                        } else if (pacStatutMPR.includes('Anomalie')) {
                                            ligne.Etape11StatutAdmin.badges.push({
                                                id: 'mprAnomalie',
                                                value: 'MPR: Anomalie',
                                                customCSS: 'background-color: #FE9B4A;',
                                                customClass: 'badge'
                                            });
                                        }
                                    }

                                    precarite = this._getVal(record, 'MPR_PRECARITE__c')
                                    shab = this._getVal(record, 'MPR_SHAB__c')
                                    installation = this._getVal(
                                        record,
                                        'PAC_Date_d_Installation__c'
                                    )
                                    if (precarite || shab || installation) {
                                        ligne.Etape3StatutInstallation = {
                                            value: `Précarité: ${precarite || ''} // Shab: ${shab || ''
                                                } m² // Installation :  ${installation || ''
                                                }` /*, customCSS: 'background-color: #B6D7A8;', customClass: 'badge'*/
                                        }
                                    }
                                    ligne.Etape4StatutPaiement = {
                                        value: '-',
                                        customCSS: '',
                                        customClass: ''
                                    }
                                    break
                                case 'Installation OK':
                                    pacStatutMPR = this._getVal(record, 'PAC_Statut_MPR__c')

                                    
                                    ligne.Etape11StatutAdmin = {
                                        badges: []
                                    };
                                    if (!this._getVal(record, 'MPR_Docs__c')) {
                                        if(previsiteNecessite !== 'OUI'){
                                            ligne.Etape11StatutAdmin.badges.push({
                                            id: 'docsAttente',
                                            value: 'Docs: En cours',
                                            customCSS: 'background-color: #9FC5E8;',
                                            customClass: 'badge'
                                        });
                                        }
                                    } else if (hasDossierComplet) {
                                        ligne.Etape11StatutAdmin.badges.push({
                                            id: 'docsComplet',
                                            value: 'Docs: Complet',
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        });
                                    } else {
                                        ligne.Etape11StatutAdmin.badges.push({
                                            id: 'docsManquants',
                                            value: 'Docs: Incomplet',
                                            customCSS: 'background-color: #EA9999;',
                                            customClass: 'badge'
                                        });
                                    }

                                    // if (!estBlueSup90) {
                                        if (pacStatutMPR === '🟪Déposé') {
                                            ligne.Etape11StatutAdmin.badges.push({
                                                id: 'mprDéposé',
                                                value: 'MPR: Déposé',
                                                customCSS: 'background-color: #E3BFFD;',
                                                customClass: 'badge'
                                            });
                                        } else if (pacStatutMPR === '🟩 Accordé') {
                                            ligne.Etape11StatutAdmin.badges.push({
                                                id: 'mprAccorde',
                                                    value: 'MPR: Accordé',
                                                    customCSS: 'background-color: #FFD966;',
                                                    customClass: 'badge'
                                                });
                                        } else if (
                                            pacStatutMPR === '🟩Solde Demandé' ||
                                            pacStatutMPR === '🟩Payé'
                                        ) {
                                            ligne.Etape11StatutAdmin.badges.push({
                                                id: 'mprSoldeDemande',
                                                    value: 'MPR: Solde Demandé',
                                                    customCSS: 'background-color: #E3BFFD;',
                                                    customClass: 'badge'
                                                })
                                        } else if (pacStatutMPR === '🟩Payé- Virement Reçu') {
                                            ligne.Etape11StatutAdmin.badges.push({
                                                id: 'mprSoldeOk',
                                                value: 'MPR: Solde Ok',
                                                customCSS: 'background-color: #B6D7A8;',
                                                customClass: 'badge'
                                            });
                                        } else if (pacStatutMPR.includes('Anomalie')) {
                                            ligne.Etape11StatutAdmin.badges.push({
                                                id: 'mprAnomalie',
                                                value: 'MPR: Anomalie',
                                                customCSS: 'background-color: #FE9B4A;',
                                                customClass: 'badge'
                                            });
                                        }
                                    // }
                                    

                                    precarite = this._getVal(record, 'MPR_PRECARITE__c')
                                    shab = this._getVal(record, 'MPR_SHAB__c')
                                    installation = this._getVal(
                                        record,
                                        'PAC_Date_d_Installation__c'
                                    )
                                    if (precarite || shab || installation) {
                                        ligne.Etape3StatutInstallation = {
                                            value: `Précarité: ${precarite || ''} // Shab: ${shab || ''
                                                } m² // Installation :  ${installation || ''
                                                }` /*, customCSS: 'background-color: #B6D7A8;', customClass: 'badge'*/
                                        }
                                    }

                                    ligne.Etape4StatutPaiement = {
                                        value: 'Vérif Comptable🕒',
                                        customCSS: 'background-color: #D9D9D9;',
                                        customClass: 'badge'
                                    }
                                    break
                            }
                            // Previsite badge (BAR_TH171) - ajouté après le badge principal
                            if (previsiteNecessite === 'OUI') {
                                let previBadge = null
                                if (
                                    prvisiteStatut === '🟨Passage Demandé' ||
                                    prvisiteStatut === '▣ Att Planification'
                                ) {
                                    previBadge = {
                                        value: 'Prévisite: Demandé',
                                        customCSS: 'background-color: #9FC5E8;',
                                        customClass: 'badge'
                                    }
                                } else if (prvisiteStatut === '🟫Passage à Replanifier') {
                                    previBadge = {
                                        value: 'Prévisite: A Replanifier',
                                        customCSS: 'background-color: #FE9B4A;',
                                        customClass: 'badge'
                                    }
                                } else if (prvisiteStatut === '🟧Passage Planifié') {
                                    const prvisiteDate = this._getVal(
                                        record,
                                        'Pr_visite_Date_Passage__c'
                                    )
                                    const dateStr = prvisiteDate
                                        ? this._formatDate(prvisiteDate)
                                        : ''
                                    previBadge = {
                                        value: `Prévisite: Planifié${dateStr ? ' ' + dateStr : ''}`,
                                        customCSS: 'background-color: #FFD966;',
                                        customClass: 'badge'
                                    }
                                } else if (prvisiteStatut === '🟩Passage Effectué') {
                                    previBadge = {
                                        value: 'Prévisite Ok',
                                        customCSS: 'background-color: #B6D7A8;',
                                        customClass: 'badge'
                                    }
                                }
                                if (previBadge) {
                                    previBadge.id = 'previsiteBadge'
                                    ligne.Etape11StatutAdmin.badges.unshift(previBadge);
                            //         if (!ligne.Etape11StatutAdmin)
                            //             ligne.Etape11StatutAdmin = {
                            //                 badges: []
                            //             }
                            //         ligne.Etape11StatutAdmin.badges.unshift(previBadge)
                            //     }

                            //     if (prvisiteStatut !== '🟩Passage Effectué') {
                            //         // masquer les infos MPR:
                            //         ligne.Etape11StatutAdmin.badges =
                            //             ligne.Etape11StatutAdmin.badges.filter(
                            //                 badge => !badge.value.startsWith('MPR:')
                            //             )
                                }
                            }
                            break
                        case 'BAR_TH179':
                            switch (ligne.Etape2StatutSecretariat.value) {
                                case '-':
                                    ligne.Etape11StatutAdmin = {
                                        badges: [
                                            // { value: 'En Attente', customCSS: 'background-color: #D9D9D9;', customClass: 'badge' }
                                        ]
                                    }
                                    ligne.Etape3StatutInstallation = {
                                        value: '-',
                                        customCSS: '',
                                        customClass: ''
                                    }
                                    ligne.Etape4StatutPaiement = {
                                        value: '-',
                                        customCSS: '',
                                        customClass: ''
                                    }
                                    break
                                case 'Date Planifiée':
                                    ligne.Etape11StatutAdmin = {
                                        badges: [{
                                            value: 'Admin Ok',
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }]
                                    }
                                    // "Installation:" PAC_Date_d_Installation__c
                                    dateInstallation = this._getVal(
                                        record,
                                        'PAC_Date_d_Installation__c'
                                    )
                                    // console.log("dateInstallation >> : ", JSON.stringify(dateInstallation));
                                    if (dateInstallation) {
                                        // console.log("dateInstallation is truthy");
                                        ligne.Etape3StatutInstallation = {
                                            value: `Installation: ${this._formatDate(
                                                dateInstallation
                                            )}`,
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }
                                    }
                                    // console.log("ligne.Etape3StatutInstallation >> : ", JSON.stringify(ligne.Etape3StatutInstallation));
                                    ligne.Etape4StatutPaiement = {
                                        value: '-',
                                        customCSS: '',
                                        customClass: ''
                                    }
                                    break
                                case 'Installation Non Finalisée':
                                    ligne.Etape11StatutAdmin = {
                                        badges: [{
                                            value: 'Admin Ok',
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }]
                                    }
                                    // "Installation:" PAC_Date_d_Installation__c
                                    dateInstallation = this._getVal(
                                        record,
                                        'PAC_Date_d_Installation__c'
                                    )
                                    if (dateInstallation) {
                                        ligne.Etape3StatutInstallation = {
                                            value: `Installation: ${this._formatDate(
                                                dateInstallation
                                            )}`,
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }
                                    }
                                    ligne.Etape4StatutPaiement = {
                                        value: '-',
                                        customCSS: '',
                                        customClass: ''
                                    }
                                    break
                                case 'Installation OK':
                                    ligne.Etape11StatutAdmin = {
                                        badges: [{
                                            value: 'Admin Ok',
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }]
                                    }
                                    // "Installation:" PAC_Date_d_Installation__c
                                    dateInstallation = this._getVal(
                                        record,
                                        'PAC_Date_d_Installation__c'
                                    )
                                    if (dateInstallation) {
                                        ligne.Etape3StatutInstallation = {
                                            value: `Installation: ${this._formatDate(
                                                dateInstallation
                                            )}`,
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }
                                    }

                                    ligne.Etape4StatutPaiement = {
                                        value: 'Vérif Comptable',
                                        customCSS: 'background-color: #D9D9D9;',
                                        customClass: 'badge'
                                    }
                                    break
                            }
                            // Previsite badge (BAR_TH171) - ajouté le badge au debut
                            if (auditNecessite === 'OUI') {
                                let auditBadge = null
                                if (
                                    auditStatut === '🟧Audit- Modifs Demandées' ||
                                    auditStatut === '▣ Nouveau Dossier'
                                ) {
                                    auditBadge = {
                                        value: 'Audit: Demandé',
                                        customCSS: 'background-color: #9FC5E8;',
                                        customClass: 'badge'
                                    }
                                } else if (auditStatut === '🟩Audit- Validé') {
                                    //! Le conditionnement est en relation avec la partie suivante
                                    auditBadge = {
                                        value: previsiteNecessite === 'OUI' &&
                                            prvisiteStatut === '🟩Passage Effectué' ?
                                            'Prévisite+Audit OK' :
                                            'Audit Ok',
                                        customCSS: 'background-color: #B6D7A8;',
                                        customClass: 'badge'
                                    }
                                }
                                if (auditBadge) {
                                    if (!ligne.Etape11StatutAdmin)
                                        ligne.Etape11StatutAdmin = {
                                            badges: []
                                        }
                                    ligne.Etape11StatutAdmin.badges.unshift(auditBadge)
                                }
                            }

                            // Previsite badge (BAR_TH171) - ajouté le badge au debut
                            if (previsiteNecessite === 'OUI' && auditNecessite !== 'OUI') {
                                let previBadge = null
                                if (
                                    prvisiteStatut === '🟨Passage Demandé' ||
                                    prvisiteStatut === '▣ Att Planification'
                                ) {
                                    previBadge = {
                                        value: 'Prévisite: Demandé',
                                        customCSS: 'background-color: #9FC5E8;',
                                        customClass: 'badge'
                                    }
                                } else if (prvisiteStatut === '🟫Passage à Replanifier') {
                                    previBadge = {
                                        value: 'Prévisite: A Replanifier',
                                        customCSS: 'background-color: #FE9B4A;',
                                        customClass: 'badge'
                                    }
                                } else if (prvisiteStatut === '🟧Passage Planifié') {
                                    const prvisiteDate = this._getVal(
                                        record,
                                        'Pr_visite_Date_Passage__c'
                                    )
                                    const dateStr = prvisiteDate ?
                                        this._formatDate(prvisiteDate) :
                                        ''
                                    previBadge = {
                                        value: `Prévisite: Planifié${dateStr ? ' ' + dateStr : ''}`,
                                        customCSS: 'background-color: #FFD966;',
                                        customClass: 'badge'
                                    }
                                } else if (prvisiteStatut === '🟩Passage Effectué') {
                                    previBadge = {
                                        value: 'Prévisite Ok',
                                        customCSS: 'background-color: #B6D7A8;',
                                        customClass: 'badge'
                                    }
                                }
                                if (previBadge) {
                                    if (!ligne.Etape11StatutAdmin)
                                        ligne.Etape11StatutAdmin = {
                                            badges: []
                                        }
                                    ligne.Etape11StatutAdmin.badges.unshift(previBadge)
                                }
                            }

                            // Traitement 3 cas ICI
                            // Cas 1: Prévisite OUI + Passage Effectué + Audit NON
                            // Cas 2: Prévisite OUI + Passage Effectué + Audit OUI + Audit Validé
                            // Cas 3: Prévisite NON + Audit NON

                            if (cas1 || cas2 || cas3) {
                                const devisStatut = this._getVal(record, 'Devis_Statut__c')
                                let dvisBadge = null
                                if (devisStatut === '▣ Nouveau Dossier') {
                                    dvisBadge = {
                                        value: 'DEVIS: Demandé',
                                        customCSS: 'background-color: #9FC5E8;',
                                        customClass: 'badge'
                                    }
                                } else if (devisStatut === '🟦En Attente Signature') {
                                    dvisBadge = {
                                        value: 'DEVIS: Envoyé',
                                        customCSS: 'background-color: #FFD966;',
                                        customClass: 'badge'
                                    }
                                } else if (devisStatut === '🟩Signé') {
                                    dvisBadge = {
                                        value: 'DEVIS: Signature Ok',
                                        customCSS: 'background-color: #B6D7A8;',
                                        customClass: 'badge'
                                    }
                                }
                                if (dvisBadge) {
                                    if (!ligne.Etape11StatutAdmin)
                                        ligne.Etape11StatutAdmin = {
                                            badges: []
                                        }
                                    ligne.Etape11StatutAdmin.badges.push(dvisBadge)
                                }
                            }

                            // // DR-Infos : si fiche non clôturée TH171, badge unique
                            // if (this._getVal(record, 'DR_Infos_Doss__c') !== '✅1') {
                            //     ligne.Etape11StatutAdmin = {
                            //         badges: [
                            //             {
                            //                 value: dossierAnnule
                            //                     ? 'Voir Motif Annulation TH171'
                            //                     : 'Attente Cloture TH171⏳',
                            //                 customCSS: 'background-color: #D9D9D9;',
                            //                 customClass: 'badge'
                            //             }
                            //         ]
                            //     }
                            // }
                            break
                        case 'BAT_TH142':
                            switch (ligne.Etape2StatutSecretariat.value) {
                                case '-':
                                    ligne.Etape11StatutAdmin = {
                                        badges: [
                                            // { value: 'En Attente', customCSS: 'background-color: #D9D9D9;', customClass: 'badge' }
                                        ]
                                    }
                                    ligne.Etape3StatutInstallation = {
                                        value: '-',
                                        customCSS: '',
                                        customClass: ''
                                    }
                                    ligne.Etape4StatutPaiement = {
                                        value: '-',
                                        customCSS: '',
                                        customClass: ''
                                    }
                                    break
                                case 'Date Planifiée':
                                    ligne.Etape11StatutAdmin = {
                                        badges: [{
                                            value: 'Admin Ok',
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }]
                                    }
                                    // "Installation:" PAC_Date_d_Installation__c
                                    dateInstallation = this._getVal(
                                        record,
                                        'PAC_Date_d_Installation__c'
                                    )
                                    // console.log("dateInstallation >> : ", JSON.stringify(dateInstallation));
                                    if (dateInstallation) {
                                        // console.log("dateInstallation is truthy");
                                        ligne.Etape3StatutInstallation = {
                                            value: `Installation: ${this._formatDate(
                                                dateInstallation
                                            )}`,
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }
                                    }
                                    // console.log("ligne.Etape3StatutInstallation >> : ", JSON.stringify(ligne.Etape3StatutInstallation));
                                    ligne.Etape4StatutPaiement = {
                                        value: '-',
                                        customCSS: '',
                                        customClass: ''
                                    }
                                    break
                                case 'Installation Non Finalisée':
                                    ligne.Etape11StatutAdmin = {
                                        badges: [{
                                            value: 'Admin Ok',
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }]
                                    }
                                    // "Installation:" PAC_Date_d_Installation__c
                                    dateInstallation = this._getVal(
                                        record,
                                        'PAC_Date_d_Installation__c'
                                    )
                                    if (dateInstallation) {
                                        ligne.Etape3StatutInstallation = {
                                            value: `Installation: ${this._formatDate(
                                                dateInstallation
                                            )}`,
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }
                                    }
                                    ligne.Etape4StatutPaiement = {
                                        value: '-',
                                        customCSS: '',
                                        customClass: ''
                                    }
                                    break
                                case 'Installation OK':
                                    ligne.Etape11StatutAdmin = {
                                        badges: [{
                                            value: 'Admin Ok',
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }]
                                    }
                                    // "Installation:" PAC_Date_d_Installation__c
                                    dateInstallation = this._getVal(
                                        record,
                                        'PAC_Date_d_Installation__c'
                                    )
                                    if (dateInstallation) {
                                        ligne.Etape3StatutInstallation = {
                                            value: `Installation: ${this._formatDate(
                                                dateInstallation
                                            )}`,
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }
                                    }

                                    ligne.Etape4StatutPaiement = {
                                        value: 'Vérif Comptable',
                                        customCSS: 'background-color: #D9D9D9;',
                                        customClass: 'badge'
                                    }
                                    break
                            }
                            // Previsite badge (BAR_TH171) - ajouté le badge au debut
                            if (auditNecessite === 'OUI') {
                                let auditBadge = null
                                if (
                                    auditStatut === '🟧Audit- Modifs Demandées' ||
                                    auditStatut === '▣ Nouveau Dossier'
                                ) {
                                    auditBadge = {
                                        value: 'Audit: Demandé',
                                        customCSS: 'background-color: #9FC5E8;',
                                        customClass: 'badge'
                                    }
                                } else if (auditStatut === '🟩Audit- Validé') {
                                    //! Le conditionnement est en relation avec la partie suivante
                                    auditBadge = {
                                        value: previsiteNecessite === 'OUI' &&
                                            prvisiteStatut === '🟩Passage Effectué' ?
                                            'Prévisite+Audit OK' :
                                            'Audit Ok',
                                        customCSS: 'background-color: #B6D7A8;',
                                        customClass: 'badge'
                                    }
                                }
                                if (auditBadge) {
                                    if (!ligne.Etape11StatutAdmin)
                                        ligne.Etape11StatutAdmin = {
                                            badges: []
                                        }
                                    ligne.Etape11StatutAdmin.badges.unshift(auditBadge)
                                }
                            }

                            // Previsite badge (BAR_TH171) - ajouté le badge au debut
                            if (previsiteNecessite === 'OUI' && auditNecessite !== 'OUI') {
                                let previBadge = null
                                if (
                                    prvisiteStatut === '🟨Passage Demandé' ||
                                    prvisiteStatut === '▣ Att Planification'
                                ) {
                                    previBadge = {
                                        value: 'Prévisite: Demandé',
                                        customCSS: 'background-color: #9FC5E8;',
                                        customClass: 'badge'
                                    }
                                } else if (prvisiteStatut === '🟫Passage à Replanifier') {
                                    previBadge = {
                                        value: 'Prévisite: A Replanifier',
                                        customCSS: 'background-color: #FE9B4A;',
                                        customClass: 'badge'
                                    }
                                } else if (prvisiteStatut === '🟧Passage Planifié') {
                                    const prvisiteDate = this._getVal(
                                        record,
                                        'Pr_visite_Date_Passage__c'
                                    )
                                    const dateStr = prvisiteDate ?
                                        this._formatDate(prvisiteDate) :
                                        ''
                                    previBadge = {
                                        value: `Prévisite: Planifié${dateStr ? ' ' + dateStr : ''}`,
                                        customCSS: 'background-color: #FFD966;',
                                        customClass: 'badge'
                                    }
                                } else if (prvisiteStatut === '🟩Passage Effectué') {
                                    previBadge = {
                                        value: 'Prévisite Ok',
                                        customCSS: 'background-color: #B6D7A8;',
                                        customClass: 'badge'
                                    }
                                }
                                if (previBadge) {
                                    if (!ligne.Etape11StatutAdmin)
                                        ligne.Etape11StatutAdmin = {
                                            badges: []
                                        }
                                    ligne.Etape11StatutAdmin.badges.unshift(previBadge)
                                }
                            }

                            // Traitement 3 cas ICI
                            // Cas 1: Prévisite OUI + Passage Effectué + Audit NON
                            // Cas 2: Prévisite OUI + Passage Effectué + Audit OUI + Audit Validé
                            // Cas 3: Prévisite NON + Audit NON

                            if (cas1 || cas2 || cas3) {
                                const devisStatut = this._getVal(record, 'Devis_Statut__c')
                                let dvisBadge = null
                                if (devisStatut === '▣ Nouveau Dossier') {
                                    dvisBadge = {
                                        value: 'DEVIS: Demandé',
                                        customCSS: 'background-color: #9FC5E8;',
                                        customClass: 'badge'
                                    }
                                } else if (devisStatut === '🟦En Attente Signature') {
                                    dvisBadge = {
                                        value: 'DEVIS: Envoyé',
                                        customCSS: 'background-color: #FFD966;',
                                        customClass: 'badge'
                                    }
                                } else if (devisStatut === '🟩Signé') {
                                    dvisBadge = {
                                        value: 'DEVIS: Signature Ok',
                                        customCSS: 'background-color: #B6D7A8;',
                                        customClass: 'badge'
                                    }
                                }
                                if (dvisBadge) {
                                    if (!ligne.Etape11StatutAdmin)
                                        ligne.Etape11StatutAdmin = {
                                            badges: []
                                        }
                                    ligne.Etape11StatutAdmin.badges.push(dvisBadge)
                                }
                            }

                            // // DR-Infos : si fiche non clôturée TH171, badge unique
                            // if (this._getVal(record, 'DR_Infos_Doss__c') !== '✅1') {
                            //     ligne.Etape11StatutAdmin = {
                            //         badges: [
                            //             {
                            //                 value: dossierAnnule
                            //                     ? 'Voir Motif Annulation TH171'
                            //                     : 'Attente Cloture TH171⏳',
                            //                 customCSS: 'background-color: #D9D9D9;',
                            //                 customClass: 'badge'
                            //             }
                            //         ]
                            //     }
                            // }
                            break
                        case 'BAT_EQ127':
                            switch (ligne.Etape2StatutSecretariat.value) {
                                case '-':
                                    ligne.Etape11StatutAdmin = {
                                        badges: [
                                            // { value: 'En Attente', customCSS: 'background-color: #D9D9D9;', customClass: 'badge' }
                                        ]
                                    }
                                    ligne.Etape3StatutInstallation = {
                                        value: '-',
                                        customCSS: '',
                                        customClass: ''
                                    }
                                    ligne.Etape4StatutPaiement = {
                                        value: '-',
                                        customCSS: '',
                                        customClass: ''
                                    }
                                    break
                                case 'Date Planifiée':
                                    ligne.Etape11StatutAdmin = {
                                        badges: [{
                                            value: 'Admin Ok',
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }]
                                    }
                                    // "Installation:" PAC_Date_d_Installation__c
                                    dateInstallation = this._getVal(
                                        record,
                                        'PAC_Date_d_Installation__c'
                                    )
                                    // console.log("dateInstallation >> : ", JSON.stringify(dateInstallation));
                                    if (dateInstallation) {
                                        // console.log("dateInstallation is truthy");
                                        ligne.Etape3StatutInstallation = {
                                            value: `Installation: ${this._formatDate(
                                                dateInstallation
                                            )}`,
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }
                                    }
                                    // console.log("ligne.Etape3StatutInstallation >> : ", JSON.stringify(ligne.Etape3StatutInstallation));
                                    ligne.Etape4StatutPaiement = {
                                        value: '-',
                                        customCSS: '',
                                        customClass: ''
                                    }
                                    break
                                case 'Installation Non Finalisée':
                                    ligne.Etape11StatutAdmin = {
                                        badges: [{
                                            value: 'Admin Ok',
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }]
                                    }
                                    // "Installation:" PAC_Date_d_Installation__c
                                    dateInstallation = this._getVal(
                                        record,
                                        'PAC_Date_d_Installation__c'
                                    )
                                    if (dateInstallation) {
                                        ligne.Etape3StatutInstallation = {
                                            value: `Installation: ${this._formatDate(
                                                dateInstallation
                                            )}`,
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }
                                    }
                                    ligne.Etape4StatutPaiement = {
                                        value: '-',
                                        customCSS: '',
                                        customClass: ''
                                    }
                                    break
                                case 'Installation OK':
                                    ligne.Etape11StatutAdmin = {
                                        badges: [{
                                            value: 'Admin Ok',
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }]
                                    }
                                    // "Installation:" PAC_Date_d_Installation__c
                                    dateInstallation = this._getVal(
                                        record,
                                        'PAC_Date_d_Installation__c'
                                    )
                                    if (dateInstallation) {
                                        ligne.Etape3StatutInstallation = {
                                            value: `Installation: ${this._formatDate(
                                                dateInstallation
                                            )}`,
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }
                                    }

                                    ligne.Etape4StatutPaiement = {
                                        value: 'Vérif Comptable',
                                        customCSS: 'background-color: #D9D9D9;',
                                        customClass: 'badge'
                                    }
                                    break
                            }
                            // Previsite badge (BAR_TH171) - ajouté le badge au debut
                            if (auditNecessite === 'OUI') {
                                let auditBadge = null
                                if (
                                    auditStatut === '🟧Audit- Modifs Demandées' ||
                                    auditStatut === '▣ Nouveau Dossier'
                                ) {
                                    auditBadge = {
                                        value: 'Audit: Demandé',
                                        customCSS: 'background-color: #9FC5E8;',
                                        customClass: 'badge'
                                    }
                                } else if (auditStatut === '🟩Audit- Validé') {
                                    //! Le conditionnement est en relation avec la partie suivante
                                    auditBadge = {
                                        value: previsiteNecessite === 'OUI' &&
                                            prvisiteStatut === '🟩Passage Effectué' ?
                                            'Prévisite+Audit OK' :
                                            'Audit Ok',
                                        customCSS: 'background-color: #B6D7A8;',
                                        customClass: 'badge'
                                    }
                                }
                                if (auditBadge) {
                                    if (!ligne.Etape11StatutAdmin)
                                        ligne.Etape11StatutAdmin = {
                                            badges: []
                                        }
                                    ligne.Etape11StatutAdmin.badges.unshift(auditBadge)
                                }
                            }

                            // Previsite badge (BAR_TH171) - ajouté le badge au debut
                            if (previsiteNecessite === 'OUI' && auditNecessite !== 'OUI') {
                                let previBadge = null
                                if (
                                    prvisiteStatut === '🟨Passage Demandé' ||
                                    prvisiteStatut === '▣ Att Planification'
                                ) {
                                    previBadge = {
                                        value: 'Prévisite: Demandé',
                                        customCSS: 'background-color: #9FC5E8;',
                                        customClass: 'badge'
                                    }
                                } else if (prvisiteStatut === '🟫Passage à Replanifier') {
                                    previBadge = {
                                        value: 'Prévisite: A Replanifier',
                                        customCSS: 'background-color: #FE9B4A;',
                                        customClass: 'badge'
                                    }
                                } else if (prvisiteStatut === '🟧Passage Planifié') {
                                    const prvisiteDate = this._getVal(
                                        record,
                                        'Pr_visite_Date_Passage__c'
                                    )
                                    const dateStr = prvisiteDate ?
                                        this._formatDate(prvisiteDate) :
                                        ''
                                    previBadge = {
                                        value: `Prévisite: Planifié${dateStr ? ' ' + dateStr : ''}`,
                                        customCSS: 'background-color: #FFD966;',
                                        customClass: 'badge'
                                    }
                                } else if (prvisiteStatut === '🟩Passage Effectué') {
                                    previBadge = {
                                        value: 'Prévisite Ok',
                                        customCSS: 'background-color: #B6D7A8;',
                                        customClass: 'badge'
                                    }
                                }
                                if (previBadge) {
                                    if (!ligne.Etape11StatutAdmin)
                                        ligne.Etape11StatutAdmin = {
                                            badges: []
                                        }
                                    ligne.Etape11StatutAdmin.badges.unshift(previBadge)
                                }
                            }

                            // Traitement 3 cas ICI
                            // Cas 1: Prévisite OUI + Passage Effectué + Audit NON
                            // Cas 2: Prévisite OUI + Passage Effectué + Audit OUI + Audit Validé
                            // Cas 3: Prévisite NON + Audit NON

                            if (cas1 || cas2 || cas3) {
                                const devisStatut = this._getVal(record, 'Devis_Statut__c')
                                let dvisBadge = null
                                if (devisStatut === '▣ Nouveau Dossier') {
                                    dvisBadge = {
                                        value: 'DEVIS: Demandé',
                                        customCSS: 'background-color: #9FC5E8;',
                                        customClass: 'badge'
                                    }
                                } else if (devisStatut === '🟦En Attente Signature') {
                                    dvisBadge = {
                                        value: 'DEVIS: Envoyé',
                                        customCSS: 'background-color: #FFD966;',
                                        customClass: 'badge'
                                    }
                                } else if (devisStatut === '🟩Signé') {
                                    dvisBadge = {
                                        value: 'DEVIS: Signature Ok',
                                        customCSS: 'background-color: #B6D7A8;',
                                        customClass: 'badge'
                                    }
                                }
                                if (dvisBadge) {
                                    if (!ligne.Etape11StatutAdmin)
                                        ligne.Etape11StatutAdmin = {
                                            badges: []
                                        }
                                    ligne.Etape11StatutAdmin.badges.push(dvisBadge)
                                }
                            }

                            // // DR-Infos : si fiche non clôturée TH171, badge unique
                            // if (this._getVal(record, 'DR_Infos_Doss__c') !== '✅1') {
                            //     ligne.Etape11StatutAdmin = {
                            //         badges: [
                            //             {
                            //                 value: dossierAnnule
                            //                     ? 'Voir Motif Annulation TH171'
                            //                     : 'Attente Cloture TH171⏳',
                            //                 customCSS: 'background-color: #D9D9D9;',
                            //                 customClass: 'badge'
                            //             }
                            //         ]
                            //     }
                            // }
                            break
                            // ─── BAR_TH175 - Réno Globale Appart ─────────────────────────────────
                        case 'BAR_TH175':
                            switch (ligne.Etape2StatutSecretariat.value) {
                                case '-':
                                    ligne.Etape11StatutAdmin = {
                                        badges: [
                                            // { value: 'En Attente', customCSS: 'background-color: #D9D9D9;', customClass: 'badge' }
                                        ]
                                    }
                                    ligne.Etape3StatutInstallation = {
                                        value: '-',
                                        customCSS: '',
                                        customClass: ''
                                    }
                                    ligne.Etape4StatutPaiement = {
                                        value: '-',
                                        customCSS: '',
                                        customClass: ''
                                    }
                                    break
                                case 'Date Planifiée':
                                    ligne.Etape11StatutAdmin = {
                                        badges: [{
                                            value: 'Admin Ok',
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }]
                                    }
                                    // "Installation:" PAC_Date_d_Installation__c
                                    dateInstallation = this._getVal(
                                        record,
                                        'PAC_Date_d_Installation__c'
                                    )
                                    // console.log("dateInstallation >> : ", JSON.stringify(dateInstallation));
                                    if (dateInstallation) {
                                        // console.log("dateInstallation is truthy");
                                        ligne.Etape3StatutInstallation = {
                                            value: `Installation: ${this._formatDate(
                                                dateInstallation
                                            )}`,
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }
                                    }
                                    // console.log("ligne.Etape3StatutInstallation >> : ", JSON.stringify(ligne.Etape3StatutInstallation));
                                    ligne.Etape4StatutPaiement = {
                                        value: '-',
                                        customCSS: '',
                                        customClass: ''
                                    }
                                    break
                                case 'Installation Non Finalisée':
                                    ligne.Etape11StatutAdmin = {
                                        badges: [{
                                            value: 'Admin Ok',
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }]
                                    }
                                    // "Installation:" PAC_Date_d_Installation__c
                                    dateInstallation = this._getVal(
                                        record,
                                        'PAC_Date_d_Installation__c'
                                    )
                                    if (dateInstallation) {
                                        ligne.Etape3StatutInstallation = {
                                            value: `Installation: ${this._formatDate(
                                                dateInstallation
                                            )}`,
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }
                                    }
                                    ligne.Etape4StatutPaiement = {
                                        value: '-',
                                        customCSS: '',
                                        customClass: ''
                                    }
                                    break
                                case 'Installation OK':
                                    ligne.Etape11StatutAdmin = {
                                        badges: [{
                                            value: 'Admin Ok',
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }]
                                    }
                                    // "Installation:" PAC_Date_d_Installation__c
                                    dateInstallation = this._getVal(
                                        record,
                                        'PAC_Date_d_Installation__c'
                                    )
                                    if (dateInstallation) {
                                        ligne.Etape3StatutInstallation = {
                                            value: `Installation: ${this._formatDate(
                                                dateInstallation
                                            )}`,
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }
                                    }

                                    ligne.Etape4StatutPaiement = {
                                        value: 'Vérif Comptable',
                                        customCSS: 'background-color: #D9D9D9;',
                                        customClass: 'badge'
                                    }
                                    break
                            }
                            // Previsite badge (BAR_TH171) - ajouté le badge au debut
                            if (auditNecessite === 'OUI') {
                                let auditBadge = null
                                if (
                                    auditStatut === '🟧Audit- Modifs Demandées' ||
                                    auditStatut === '▣ Nouveau Dossier'
                                ) {
                                    auditBadge = {
                                        value: 'Audit: Demandé',
                                        customCSS: 'background-color: #9FC5E8;',
                                        customClass: 'badge'
                                    }
                                } else if (auditStatut === '🟩Audit- Validé') {
                                    //! Le conditionnement est en relation avec la partie suivante
                                    auditBadge = {
                                        value: previsiteNecessite === 'OUI' &&
                                            prvisiteStatut === '🟩Passage Effectué' ?
                                            'Prévisite+Audit OK' :
                                            'Audit Ok',
                                        customCSS: 'background-color: #B6D7A8;',
                                        customClass: 'badge'
                                    }
                                }
                                if (auditBadge) {
                                    if (!ligne.Etape11StatutAdmin)
                                        ligne.Etape11StatutAdmin = {
                                            badges: []
                                        }
                                    ligne.Etape11StatutAdmin.badges.unshift(auditBadge)
                                }
                            }

                            // Previsite badge (BAR_TH171) - ajouté le badge au debut
                            if (previsiteNecessite === 'OUI' && auditNecessite !== 'OUI') {
                                let previBadge = null
                                if (
                                    prvisiteStatut === '🟨Passage Demandé' ||
                                    prvisiteStatut === '▣ Att Planification'
                                ) {
                                    previBadge = {
                                        value: 'Prévisite: Demandé',
                                        customCSS: 'background-color: #9FC5E8;',
                                        customClass: 'badge'
                                    }
                                } else if (prvisiteStatut === '🟫Passage à Replanifier') {
                                    previBadge = {
                                        value: 'Prévisite: A Replanifier',
                                        customCSS: 'background-color: #FE9B4A;',
                                        customClass: 'badge'
                                    }
                                } else if (prvisiteStatut === '🟧Passage Planifié') {
                                    const prvisiteDate = this._getVal(
                                        record,
                                        'Pr_visite_Date_Passage__c'
                                    )
                                    const dateStr = prvisiteDate ?
                                        this._formatDate(prvisiteDate) :
                                        ''
                                    previBadge = {
                                        value: `Prévisite: Planifié${dateStr ? ' ' + dateStr : ''}`,
                                        customCSS: 'background-color: #FFD966;',
                                        customClass: 'badge'
                                    }
                                } else if (prvisiteStatut === '🟩Passage Effectué') {
                                    previBadge = {
                                        value: 'Prévisite Ok',
                                        customCSS: 'background-color: #B6D7A8;',
                                        customClass: 'badge'
                                    }
                                }
                                if (previBadge) {
                                    if (!ligne.Etape11StatutAdmin)
                                        ligne.Etape11StatutAdmin = {
                                            badges: []
                                        }
                                    ligne.Etape11StatutAdmin.badges.unshift(previBadge)
                                }
                            }

                            // Traitement 3 cas ICI
                            // Cas 1: Prévisite OUI + Passage Effectué + Audit NON
                            // Cas 2: Prévisite OUI + Passage Effectué + Audit OUI + Audit Validé
                            // Cas 3: Prévisite NON + Audit NON

                            if (cas1 || cas2 || cas3) {
                                const devisStatut = this._getVal(record, 'Devis_Statut__c')
                                let dvisBadge = null
                                if (devisStatut === '▣ Nouveau Dossier') {
                                    dvisBadge = {
                                        value: 'DEVIS: Demandé',
                                        customCSS: 'background-color: #9FC5E8;',
                                        customClass: 'badge'
                                    }
                                } else if (devisStatut === '🟦En Attente Signature') {
                                    dvisBadge = {
                                        value: 'DEVIS: Envoyé',
                                        customCSS: 'background-color: #FFD966;',
                                        customClass: 'badge'
                                    }
                                } else if (devisStatut === '🟩Signé') {
                                    dvisBadge = {
                                        value: 'DEVIS: Signature Ok',
                                        customCSS: 'background-color: #B6D7A8;',
                                        customClass: 'badge'
                                    }
                                }
                                if (dvisBadge) {
                                    if (!ligne.Etape11StatutAdmin)
                                        ligne.Etape11StatutAdmin = {
                                            badges: []
                                        }
                                    ligne.Etape11StatutAdmin.badges.push(dvisBadge)
                                }
                            }

                            // // DR-Infos : si fiche non clôturée TH171, badge unique
                            // if (this._getVal(record, 'DR_Infos_Doss__c') !== '✅1') {
                            //     ligne.Etape11StatutAdmin = {
                            //         badges: [
                            //             {
                            //                 value: dossierAnnule
                            //                     ? 'Voir Motif Annulation TH171'
                            //                     : 'Attente Cloture TH171⏳',
                            //                 customCSS: 'background-color: #D9D9D9;',
                            //                 customClass: 'badge'
                            //             }
                            //         ]
                            //     }
                            // }
                            break
                            // ─── BAT_TH163 - PAC Tertiaire ───────────────────────────────────────
                        case 'BAT_TH163':
                            switch (ligne.Etape2StatutSecretariat.value) {
                                case '-':
                                    ligne.Etape11StatutAdmin = {
                                        badges: [
                                            // { value: 'En Attente', customCSS: 'background-color: #D9D9D9;', customClass: 'badge' }
                                        ]
                                    }
                                    ligne.Etape3StatutInstallation = {
                                        value: '-',
                                        customCSS: '',
                                        customClass: ''
                                    }
                                    ligne.Etape4StatutPaiement = {
                                        value: '-',
                                        customCSS: '',
                                        customClass: ''
                                    }
                                    break
                                case 'Date Planifiée':
                                    ligne.Etape11StatutAdmin = {
                                        badges: [{
                                            value: 'Admin Ok',
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }]
                                    }
                                    // "Installation:" PAC_Date_d_Installation__c
                                    dateInstallation = this._getVal(
                                        record,
                                        'PAC_Date_d_Installation__c'
                                    )
                                    // console.log("dateInstallation >> : ", JSON.stringify(dateInstallation));
                                    if (dateInstallation) {
                                        // console.log("dateInstallation is truthy");
                                        ligne.Etape3StatutInstallation = {
                                            value: `Installation: ${this._formatDate(
                                                dateInstallation
                                            )}`,
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }
                                    }
                                    // console.log("ligne.Etape3StatutInstallation >> : ", JSON.stringify(ligne.Etape3StatutInstallation));
                                    ligne.Etape4StatutPaiement = {
                                        value: '-',
                                        customCSS: '',
                                        customClass: ''
                                    }
                                    break
                                case 'Installation Non Finalisée':
                                    ligne.Etape11StatutAdmin = {
                                        badges: [{
                                            value: 'Admin Ok',
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }]
                                    }
                                    // "Installation:" PAC_Date_d_Installation__c
                                    dateInstallation = this._getVal(
                                        record,
                                        'PAC_Date_d_Installation__c'
                                    )
                                    if (dateInstallation) {
                                        ligne.Etape3StatutInstallation = {
                                            value: `Installation: ${this._formatDate(
                                                dateInstallation
                                            )}`,
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }
                                    }
                                    ligne.Etape4StatutPaiement = {
                                        value: '-',
                                        customCSS: '',
                                        customClass: ''
                                    }
                                    break
                                case 'Installation OK':
                                    ligne.Etape11StatutAdmin = {
                                        badges: [{
                                            value: 'Admin Ok',
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }]
                                    }
                                    // "Installation:" PAC_Date_d_Installation__c
                                    dateInstallation = this._getVal(
                                        record,
                                        'PAC_Date_d_Installation__c'
                                    )
                                    if (dateInstallation) {
                                        ligne.Etape3StatutInstallation = {
                                            value: `Installation: ${this._formatDate(
                                                dateInstallation
                                            )}`,
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }
                                    }

                                    ligne.Etape4StatutPaiement = {
                                        value: 'Vérif Comptable',
                                        customCSS: 'background-color: #D9D9D9;',
                                        customClass: 'badge'
                                    }
                                    break
                            }
                            // Previsite badge (BAR_TH171) - ajouté le badge au debut
                            if (auditNecessite === 'OUI') {
                                let auditBadge = null
                                if (
                                    auditStatut === '🟧Audit- Modifs Demandées' ||
                                    auditStatut === '▣ Nouveau Dossier'
                                ) {
                                    auditBadge = {
                                        value: 'Audit: Demandé',
                                        customCSS: 'background-color: #9FC5E8;',
                                        customClass: 'badge'
                                    }
                                } else if (auditStatut === '🟩Audit- Validé') {
                                    //! Le conditionnement est en relation avec la partie suivante
                                    auditBadge = {
                                        value: previsiteNecessite === 'OUI' &&
                                            prvisiteStatut === '🟩Passage Effectué' ?
                                            'Prévisite+Audit OK' :
                                            'Audit Ok',
                                        customCSS: 'background-color: #B6D7A8;',
                                        customClass: 'badge'
                                    }
                                }
                                if (auditBadge) {
                                    if (!ligne.Etape11StatutAdmin)
                                        ligne.Etape11StatutAdmin = {
                                            badges: []
                                        }
                                    ligne.Etape11StatutAdmin.badges.unshift(auditBadge)
                                }
                            }

                            // Previsite badge (BAR_TH171) - ajouté le badge au debut
                            if (previsiteNecessite === 'OUI' && auditNecessite !== 'OUI') {
                                let previBadge = null
                                if (
                                    prvisiteStatut === '🟨Passage Demandé' ||
                                    prvisiteStatut === '▣ Att Planification'
                                ) {
                                    previBadge = {
                                        value: 'Prévisite: Demandé',
                                        customCSS: 'background-color: #9FC5E8;',
                                        customClass: 'badge'
                                    }
                                } else if (prvisiteStatut === '🟫Passage à Replanifier') {
                                    previBadge = {
                                        value: 'Prévisite: A Replanifier',
                                        customCSS: 'background-color: #FE9B4A;',
                                        customClass: 'badge'
                                    }
                                } else if (prvisiteStatut === '🟧Passage Planifié') {
                                    const prvisiteDate = this._getVal(
                                        record,
                                        'Pr_visite_Date_Passage__c'
                                    )
                                    const dateStr = prvisiteDate ?
                                        this._formatDate(prvisiteDate) :
                                        ''
                                    previBadge = {
                                        value: `Prévisite: Planifié${dateStr ? ' ' + dateStr : ''}`,
                                        customCSS: 'background-color: #FFD966;',
                                        customClass: 'badge'
                                    }
                                } else if (prvisiteStatut === '🟩Passage Effectué') {
                                    previBadge = {
                                        value: 'Prévisite Ok',
                                        customCSS: 'background-color: #B6D7A8;',
                                        customClass: 'badge'
                                    }
                                }
                                if (previBadge) {
                                    if (!ligne.Etape11StatutAdmin)
                                        ligne.Etape11StatutAdmin = {
                                            badges: []
                                        }
                                    ligne.Etape11StatutAdmin.badges.unshift(previBadge)
                                }
                            }

                            // Traitement 3 cas ICI
                            // Cas 1: Prévisite OUI + Passage Effectué + Audit NON
                            // Cas 2: Prévisite OUI + Passage Effectué + Audit OUI + Audit Validé
                            // Cas 3: Prévisite NON + Audit NON

                            if (cas1 || cas2 || cas3) {
                                const devisStatut = this._getVal(record, 'Devis_Statut__c')
                                let dvisBadge = null
                                if (devisStatut === '▣ Nouveau Dossier') {
                                    dvisBadge = {
                                        value: 'DEVIS: Demandé',
                                        customCSS: 'background-color: #9FC5E8;',
                                        customClass: 'badge'
                                    }
                                } else if (devisStatut === '🟦En Attente Signature') {
                                    dvisBadge = {
                                        value: 'DEVIS: Envoyé',
                                        customCSS: 'background-color: #FFD966;',
                                        customClass: 'badge'
                                    }
                                } else if (devisStatut === '🟩Signé') {
                                    dvisBadge = {
                                        value: 'DEVIS: Signature Ok',
                                        customCSS: 'background-color: #B6D7A8;',
                                        customClass: 'badge'
                                    }
                                }
                                if (dvisBadge) {
                                    if (!ligne.Etape11StatutAdmin)
                                        ligne.Etape11StatutAdmin = {
                                            badges: []
                                        }
                                    ligne.Etape11StatutAdmin.badges.push(dvisBadge)
                                }
                            }

                            // // DR-Infos : si fiche non clôturée TH171, badge unique
                            // if (this._getVal(record, 'DR_Infos_Doss__c') !== '✅1') {
                            //     ligne.Etape11StatutAdmin = {
                            //         badges: [
                            //             {
                            //                 value: dossierAnnule
                            //                     ? 'Voir Motif Annulation TH171'
                            //                     : 'Attente Cloture TH171⏳',
                            //                 customCSS: 'background-color: #D9D9D9;',
                            //                 customClass: 'badge'
                            //             }
                            //         ]
                            //     }
                            // }
                            break
                        case 'AGRI_EQ108':
                            switch (ligne.Etape2StatutSecretariat.value) {
                                case '-':
                                    ligne.Etape11StatutAdmin = {
                                        badges: [
                                            // { value: 'En Attente', customCSS: 'background-color: #D9D9D9;', customClass: 'badge' }
                                        ]
                                    }
                                    ligne.Etape3StatutInstallation = {
                                        value: '-',
                                        customCSS: '',
                                        customClass: ''
                                    }
                                    ligne.Etape4StatutPaiement = {
                                        value: '-',
                                        customCSS: '',
                                        customClass: ''
                                    }
                                    break
                                case 'Date Planifiée':
                                    ligne.Etape11StatutAdmin = {
                                        badges: [{
                                            value: 'Admin Ok',
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }]
                                    }
                                    // "Installation:" PAC_Date_d_Installation__c
                                    dateInstallation = this._getVal(
                                        record,
                                        'PAC_Date_d_Installation__c'
                                    )
                                    // console.log("dateInstallation >> : ", JSON.stringify(dateInstallation));
                                    if (dateInstallation) {
                                        // console.log("dateInstallation is truthy");
                                        ligne.Etape3StatutInstallation = {
                                            value: `Installation: ${this._formatDate(
                                                dateInstallation
                                            )}`,
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }
                                    }
                                    // console.log("ligne.Etape3StatutInstallation >> : ", JSON.stringify(ligne.Etape3StatutInstallation));
                                    ligne.Etape4StatutPaiement = {
                                        value: '-',
                                        customCSS: '',
                                        customClass: ''
                                    }
                                    break
                                case 'Installation Non Finalisée':
                                    ligne.Etape11StatutAdmin = {
                                        badges: [{
                                            value: 'Admin Ok',
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }]
                                    }
                                    // "Installation:" PAC_Date_d_Installation__c
                                    dateInstallation = this._getVal(
                                        record,
                                        'PAC_Date_d_Installation__c'
                                    )
                                    if (dateInstallation) {
                                        ligne.Etape3StatutInstallation = {
                                            value: `Installation: ${this._formatDate(
                                                dateInstallation
                                            )}`,
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }
                                    }
                                    ligne.Etape4StatutPaiement = {
                                        value: '-',
                                        customCSS: '',
                                        customClass: ''
                                    }
                                    break
                                case 'Installation OK':
                                    ligne.Etape11StatutAdmin = {
                                        badges: [{
                                            value: 'Admin Ok',
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }]
                                    }
                                    // "Installation:" PAC_Date_d_Installation__c
                                    dateInstallation = this._getVal(
                                        record,
                                        'PAC_Date_d_Installation__c'
                                    )
                                    if (dateInstallation) {
                                        ligne.Etape3StatutInstallation = {
                                            value: `Installation: ${this._formatDate(
                                                dateInstallation
                                            )}`,
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }
                                    }

                                    ligne.Etape4StatutPaiement = {
                                        value: 'Vérif Comptable',
                                        customCSS: 'background-color: #D9D9D9;',
                                        customClass: 'badge'
                                    }
                                    break
                            }
                            // Previsite badge (BAR_TH171) - ajouté le badge au debut
                            if (auditNecessite === 'OUI') {
                                let auditBadge = null
                                if (
                                    auditStatut === '🟧Audit- Modifs Demandées' ||
                                    auditStatut === '▣ Nouveau Dossier'
                                ) {
                                    auditBadge = {
                                        value: 'Audit: Demandé',
                                        customCSS: 'background-color: #9FC5E8;',
                                        customClass: 'badge'
                                    }
                                } else if (auditStatut === '🟩Audit- Validé') {
                                    //! Le conditionnement est en relation avec la partie suivante
                                    auditBadge = {
                                        value: previsiteNecessite === 'OUI' &&
                                            prvisiteStatut === '🟩Passage Effectué' ?
                                            'Prévisite+Audit OK' :
                                            'Audit Ok',
                                        customCSS: 'background-color: #B6D7A8;',
                                        customClass: 'badge'
                                    }
                                }
                                if (auditBadge) {
                                    if (!ligne.Etape11StatutAdmin)
                                        ligne.Etape11StatutAdmin = {
                                            badges: []
                                        }
                                    ligne.Etape11StatutAdmin.badges.unshift(auditBadge)
                                }
                            }

                            // Previsite badge (BAR_TH171) - ajouté le badge au debut
                            if (previsiteNecessite === 'OUI' && auditNecessite !== 'OUI') {
                                let previBadge = null
                                if (
                                    prvisiteStatut === '🟨Passage Demandé' ||
                                    prvisiteStatut === '▣ Att Planification'
                                ) {
                                    previBadge = {
                                        value: 'Prévisite: Demandé',
                                        customCSS: 'background-color: #9FC5E8;',
                                        customClass: 'badge'
                                    }
                                } else if (prvisiteStatut === '🟫Passage à Replanifier') {
                                    previBadge = {
                                        value: 'Prévisite: A Replanifier',
                                        customCSS: 'background-color: #FE9B4A;',
                                        customClass: 'badge'
                                    }
                                } else if (prvisiteStatut === '🟧Passage Planifié') {
                                    const prvisiteDate = this._getVal(
                                        record,
                                        'Pr_visite_Date_Passage__c'
                                    )
                                    const dateStr = prvisiteDate ?
                                        this._formatDate(prvisiteDate) :
                                        ''
                                    previBadge = {
                                        value: `Prévisite: Planifié${dateStr ? ' ' + dateStr : ''}`,
                                        customCSS: 'background-color: #FFD966;',
                                        customClass: 'badge'
                                    }
                                } else if (prvisiteStatut === '🟩Passage Effectué') {
                                    previBadge = {
                                        value: 'Prévisite Ok',
                                        customCSS: 'background-color: #B6D7A8;',
                                        customClass: 'badge'
                                    }
                                }
                                if (previBadge) {
                                    if (!ligne.Etape11StatutAdmin)
                                        ligne.Etape11StatutAdmin = {
                                            badges: []
                                        }
                                    ligne.Etape11StatutAdmin.badges.unshift(previBadge)
                                }
                            }

                            // Traitement 3 cas ICI
                            // Cas 1: Prévisite OUI + Passage Effectué + Audit NON
                            // Cas 2: Prévisite OUI + Passage Effectué + Audit OUI + Audit Validé
                            // Cas 3: Prévisite NON + Audit NON

                            if (cas1 || cas2 || cas3) {
                                const devisStatut = this._getVal(record, 'Devis_Statut__c')
                                let dvisBadge = null
                                if (devisStatut === '▣ Nouveau Dossier') {
                                    dvisBadge = {
                                        value: 'DEVIS: Demandé',
                                        customCSS: 'background-color: #9FC5E8;',
                                        customClass: 'badge'
                                    }
                                } else if (devisStatut === '🟦En Attente Signature') {
                                    dvisBadge = {
                                        value: 'DEVIS: Envoyé',
                                        customCSS: 'background-color: #FFD966;',
                                        customClass: 'badge'
                                    }
                                } else if (devisStatut === '🟩Signé') {
                                    dvisBadge = {
                                        value: 'DEVIS: Signature Ok',
                                        customCSS: 'background-color: #B6D7A8;',
                                        customClass: 'badge'
                                    }
                                }
                                if (dvisBadge) {
                                    if (!ligne.Etape11StatutAdmin)
                                        ligne.Etape11StatutAdmin = {
                                            badges: []
                                        }
                                    ligne.Etape11StatutAdmin.badges.push(dvisBadge)
                                }
                            }

                            // // DR-Infos : si fiche non clôturée TH171, badge unique
                            // if (this._getVal(record, 'DR_Infos_Doss__c') !== '✅1') {
                            //     ligne.Etape11StatutAdmin = {
                            //         badges: [
                            //             {
                            //                 value: dossierAnnule
                            //                     ? 'Voir Motif Annulation TH171'
                            //                     : 'Attente Cloture TH171⏳',
                            //                 customCSS: 'background-color: #D9D9D9;',
                            //                 customClass: 'badge'
                            //             }
                            //         ]
                            //     }
                            // }
                            break
                            // ─── AGRI_EQ112 - DPAROIS ────────────────────────────────────────────
                        case 'AGRI_EQ112':
                            switch (ligne.Etape2StatutSecretariat.value) {
                                case '-':
                                    ligne.Etape11StatutAdmin = {
                                        badges: [
                                            // { value: 'En Attente', customCSS: 'background-color: #D9D9D9;', customClass: 'badge' }
                                        ]
                                    }
                                    ligne.Etape3StatutInstallation = {
                                        value: '-',
                                        customCSS: '',
                                        customClass: ''
                                    }
                                    ligne.Etape4StatutPaiement = {
                                        value: '-',
                                        customCSS: '',
                                        customClass: ''
                                    }
                                    break
                                case 'Date Planifiée':
                                    ligne.Etape11StatutAdmin = {
                                        badges: [{
                                            value: 'Admin Ok',
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }]
                                    }
                                    // "Installation:" PAC_Date_d_Installation__c
                                    dateInstallation = this._getVal(
                                        record,
                                        'PAC_Date_d_Installation__c'
                                    )
                                    // console.log("dateInstallation >> : ", JSON.stringify(dateInstallation));
                                    if (dateInstallation) {
                                        // console.log("dateInstallation is truthy");
                                        ligne.Etape3StatutInstallation = {
                                            value: `Installation: ${this._formatDate(
                                                dateInstallation
                                            )}`,
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }
                                    }
                                    // console.log("ligne.Etape3StatutInstallation >> : ", JSON.stringify(ligne.Etape3StatutInstallation));
                                    ligne.Etape4StatutPaiement = {
                                        value: '-',
                                        customCSS: '',
                                        customClass: ''
                                    }
                                    break
                                case 'Installation Non Finalisée':
                                    ligne.Etape11StatutAdmin = {
                                        badges: [{
                                            value: 'Admin Ok',
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }]
                                    }
                                    // "Installation:" PAC_Date_d_Installation__c
                                    dateInstallation = this._getVal(
                                        record,
                                        'PAC_Date_d_Installation__c'
                                    )
                                    if (dateInstallation) {
                                        ligne.Etape3StatutInstallation = {
                                            value: `Installation: ${this._formatDate(
                                                dateInstallation
                                            )}`,
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }
                                    }
                                    ligne.Etape4StatutPaiement = {
                                        value: '-',
                                        customCSS: '',
                                        customClass: ''
                                    }
                                    break
                                case 'Installation OK':
                                    ligne.Etape11StatutAdmin = {
                                        badges: [{
                                            value: 'Admin Ok',
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }]
                                    }
                                    // "Installation:" PAC_Date_d_Installation__c
                                    dateInstallation = this._getVal(
                                        record,
                                        'PAC_Date_d_Installation__c'
                                    )
                                    if (dateInstallation) {
                                        ligne.Etape3StatutInstallation = {
                                            value: `Installation: ${this._formatDate(
                                                dateInstallation
                                            )}`,
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }
                                    }

                                    ligne.Etape4StatutPaiement = {
                                        value: 'Vérif Comptable',
                                        customCSS: 'background-color: #D9D9D9;',
                                        customClass: 'badge'
                                    }
                                    break
                            }
                            // Previsite badge (BAR_TH171) - ajouté le badge au debut
                            if (auditNecessite === 'OUI') {
                                let auditBadge = null
                                if (
                                    auditStatut === '🟧Audit- Modifs Demandées' ||
                                    auditStatut === '▣ Nouveau Dossier'
                                ) {
                                    auditBadge = {
                                        value: 'Audit: Demandé',
                                        customCSS: 'background-color: #9FC5E8;',
                                        customClass: 'badge'
                                    }
                                } else if (auditStatut === '🟩Audit- Validé') {
                                    //! Le conditionnement est en relation avec la partie suivante
                                    auditBadge = {
                                        value: previsiteNecessite === 'OUI' &&
                                            prvisiteStatut === '🟩Passage Effectué' ?
                                            'Prévisite+Audit OK' :
                                            'Audit Ok',
                                        customCSS: 'background-color: #B6D7A8;',
                                        customClass: 'badge'
                                    }
                                }
                                if (auditBadge) {
                                    if (!ligne.Etape11StatutAdmin)
                                        ligne.Etape11StatutAdmin = {
                                            badges: []
                                        }
                                    ligne.Etape11StatutAdmin.badges.unshift(auditBadge)
                                }
                            }

                            // Previsite badge (BAR_TH171) - ajouté le badge au debut
                            if (previsiteNecessite === 'OUI' && auditNecessite !== 'OUI') {
                                let previBadge = null
                                if (
                                    prvisiteStatut === '🟨Passage Demandé' ||
                                    prvisiteStatut === '▣ Att Planification'
                                ) {
                                    previBadge = {
                                        value: 'Prévisite: Demandé',
                                        customCSS: 'background-color: #9FC5E8;',
                                        customClass: 'badge'
                                    }
                                } else if (prvisiteStatut === '🟫Passage à Replanifier') {
                                    previBadge = {
                                        value: 'Prévisite: A Replanifier',
                                        customCSS: 'background-color: #FE9B4A;',
                                        customClass: 'badge'
                                    }
                                } else if (prvisiteStatut === '🟧Passage Planifié') {
                                    const prvisiteDate = this._getVal(
                                        record,
                                        'Pr_visite_Date_Passage__c'
                                    )
                                    const dateStr = prvisiteDate ?
                                        this._formatDate(prvisiteDate) :
                                        ''
                                    previBadge = {
                                        value: `Prévisite: Planifié${dateStr ? ' ' + dateStr : ''}`,
                                        customCSS: 'background-color: #FFD966;',
                                        customClass: 'badge'
                                    }
                                } else if (prvisiteStatut === '🟩Passage Effectué') {
                                    previBadge = {
                                        value: 'Prévisite Ok',
                                        customCSS: 'background-color: #B6D7A8;',
                                        customClass: 'badge'
                                    }
                                }
                                if (previBadge) {
                                    if (!ligne.Etape11StatutAdmin)
                                        ligne.Etape11StatutAdmin = {
                                            badges: []
                                        }
                                    ligne.Etape11StatutAdmin.badges.unshift(previBadge)
                                }
                            }

                            // Traitement 3 cas ICI
                            // Cas 1: Prévisite OUI + Passage Effectué + Audit NON
                            // Cas 2: Prévisite OUI + Passage Effectué + Audit OUI + Audit Validé
                            // Cas 3: Prévisite NON + Audit NON

                            if (cas1 || cas2 || cas3) {
                                const devisStatut = this._getVal(record, 'Devis_Statut__c')
                                let dvisBadge = null
                                if (devisStatut === '▣ Nouveau Dossier') {
                                    dvisBadge = {
                                        value: 'DEVIS: Demandé',
                                        customCSS: 'background-color: #9FC5E8;',
                                        customClass: 'badge'
                                    }
                                } else if (devisStatut === '🟦En Attente Signature') {
                                    dvisBadge = {
                                        value: 'DEVIS: Envoyé',
                                        customCSS: 'background-color: #FFD966;',
                                        customClass: 'badge'
                                    }
                                } else if (devisStatut === '🟩Signé') {
                                    dvisBadge = {
                                        value: 'DEVIS: Signature Ok',
                                        customCSS: 'background-color: #B6D7A8;',
                                        customClass: 'badge'
                                    }
                                }
                                if (dvisBadge) {
                                    if (!ligne.Etape11StatutAdmin)
                                        ligne.Etape11StatutAdmin = {
                                            badges: []
                                        }
                                    ligne.Etape11StatutAdmin.badges.push(dvisBadge)
                                }
                            }

                            // // DR-Infos : si fiche non clôturée TH171, badge unique
                            // if (this._getVal(record, 'DR_Infos_Doss__c') !== '✅1') {
                            //     ligne.Etape11StatutAdmin = {
                            //         badges: [
                            //             {
                            //                 value: dossierAnnule
                            //                     ? 'Voir Motif Annulation TH171'
                            //                     : 'Attente Cloture TH171⏳',
                            //                 customCSS: 'background-color: #D9D9D9;',
                            //                 customClass: 'badge'
                            //             }
                            //         ]
                            //     }
                            // }
                            break
                            // ─── AGRI_TH117 - DESHU ──────────────────────────────────────────────
                        case 'AGRI_TH117':
                            switch (ligne.Etape2StatutSecretariat.value) {
                                case '-':
                                    ligne.Etape11StatutAdmin = {
                                        badges: [
                                            // { value: 'En Attente', customCSS: 'background-color: #D9D9D9;', customClass: 'badge' }
                                        ]
                                    }
                                    ligne.Etape3StatutInstallation = {
                                        value: '-',
                                        customCSS: '',
                                        customClass: ''
                                    }
                                    ligne.Etape4StatutPaiement = {
                                        value: '-',
                                        customCSS: '',
                                        customClass: ''
                                    }
                                    break
                                case 'Date Planifiée':
                                    ligne.Etape11StatutAdmin = {
                                        badges: [{
                                            value: 'Admin Ok',
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }]
                                    }
                                    // "Installation:" PAC_Date_d_Installation__c
                                    dateInstallation = this._getVal(
                                        record,
                                        'PAC_Date_d_Installation__c'
                                    )
                                    // console.log("dateInstallation >> : ", JSON.stringify(dateInstallation));
                                    if (dateInstallation) {
                                        // console.log("dateInstallation is truthy");
                                        ligne.Etape3StatutInstallation = {
                                            value: `Installation: ${this._formatDate(
                                                dateInstallation
                                            )}`,
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }
                                    }
                                    // console.log("ligne.Etape3StatutInstallation >> : ", JSON.stringify(ligne.Etape3StatutInstallation));
                                    ligne.Etape4StatutPaiement = {
                                        value: '-',
                                        customCSS: '',
                                        customClass: ''
                                    }
                                    break
                                case 'Installation Non Finalisée':
                                    ligne.Etape11StatutAdmin = {
                                        badges: [{
                                            value: 'Admin Ok',
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }]
                                    }
                                    // "Installation:" PAC_Date_d_Installation__c
                                    dateInstallation = this._getVal(
                                        record,
                                        'PAC_Date_d_Installation__c'
                                    )
                                    if (dateInstallation) {
                                        ligne.Etape3StatutInstallation = {
                                            value: `Installation: ${this._formatDate(
                                                dateInstallation
                                            )}`,
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }
                                    }
                                    ligne.Etape4StatutPaiement = {
                                        value: '-',
                                        customCSS: '',
                                        customClass: ''
                                    }
                                    break
                                case 'Installation OK':
                                    ligne.Etape11StatutAdmin = {
                                        badges: [{
                                            value: 'Admin Ok',
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }]
                                    }
                                    // "Installation:" PAC_Date_d_Installation__c
                                    dateInstallation = this._getVal(
                                        record,
                                        'PAC_Date_d_Installation__c'
                                    )
                                    if (dateInstallation) {
                                        ligne.Etape3StatutInstallation = {
                                            value: `Installation: ${this._formatDate(
                                                dateInstallation
                                            )}`,
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }
                                    }

                                    ligne.Etape4StatutPaiement = {
                                        value: 'Vérif Comptable',
                                        customCSS: 'background-color: #D9D9D9;',
                                        customClass: 'badge'
                                    }
                                    break
                            }
                            // Previsite badge (BAR_TH171) - ajouté le badge au debut
                            if (auditNecessite === 'OUI') {
                                let auditBadge = null
                                if (
                                    auditStatut === '🟧Audit- Modifs Demandées' ||
                                    auditStatut === '▣ Nouveau Dossier'
                                ) {
                                    auditBadge = {
                                        value: 'Audit: Demandé',
                                        customCSS: 'background-color: #9FC5E8;',
                                        customClass: 'badge'
                                    }
                                } else if (auditStatut === '🟩Audit- Validé') {
                                    //! Le conditionnement est en relation avec la partie suivante
                                    auditBadge = {
                                        value: previsiteNecessite === 'OUI' &&
                                            prvisiteStatut === '🟩Passage Effectué' ?
                                            'Prévisite+Audit OK' :
                                            'Audit Ok',
                                        customCSS: 'background-color: #B6D7A8;',
                                        customClass: 'badge'
                                    }
                                }
                                if (auditBadge) {
                                    if (!ligne.Etape11StatutAdmin)
                                        ligne.Etape11StatutAdmin = {
                                            badges: []
                                        }
                                    ligne.Etape11StatutAdmin.badges.unshift(auditBadge)
                                }
                            }

                            // Previsite badge (BAR_TH171) - ajouté le badge au debut
                            if (previsiteNecessite === 'OUI' && auditNecessite !== 'OUI') {
                                let previBadge = null
                                if (
                                    prvisiteStatut === '🟨Passage Demandé' ||
                                    prvisiteStatut === '▣ Att Planification'
                                ) {
                                    previBadge = {
                                        value: 'Prévisite: Demandé',
                                        customCSS: 'background-color: #9FC5E8;',
                                        customClass: 'badge'
                                    }
                                } else if (prvisiteStatut === '🟫Passage à Replanifier') {
                                    previBadge = {
                                        value: 'Prévisite: A Replanifier',
                                        customCSS: 'background-color: #FE9B4A;',
                                        customClass: 'badge'
                                    }
                                } else if (prvisiteStatut === '🟧Passage Planifié') {
                                    const prvisiteDate = this._getVal(
                                        record,
                                        'Pr_visite_Date_Passage__c'
                                    )
                                    const dateStr = prvisiteDate ?
                                        this._formatDate(prvisiteDate) :
                                        ''
                                    previBadge = {
                                        value: `Prévisite: Planifié${dateStr ? ' ' + dateStr : ''}`,
                                        customCSS: 'background-color: #FFD966;',
                                        customClass: 'badge'
                                    }
                                } else if (prvisiteStatut === '🟩Passage Effectué') {
                                    previBadge = {
                                        value: 'Prévisite Ok',
                                        customCSS: 'background-color: #B6D7A8;',
                                        customClass: 'badge'
                                    }
                                }
                                if (previBadge) {
                                    if (!ligne.Etape11StatutAdmin)
                                        ligne.Etape11StatutAdmin = {
                                            badges: []
                                        }
                                    ligne.Etape11StatutAdmin.badges.unshift(previBadge)
                                }
                            }

                            // Traitement 3 cas ICI
                            // Cas 1: Prévisite OUI + Passage Effectué + Audit NON
                            // Cas 2: Prévisite OUI + Passage Effectué + Audit OUI + Audit Validé
                            // Cas 3: Prévisite NON + Audit NON

                            if (cas1 || cas2 || cas3) {
                                const devisStatut = this._getVal(record, 'Devis_Statut__c')
                                let dvisBadge = null
                                if (devisStatut === '▣ Nouveau Dossier') {
                                    dvisBadge = {
                                        value: 'DEVIS: Demandé',
                                        customCSS: 'background-color: #9FC5E8;',
                                        customClass: 'badge'
                                    }
                                } else if (devisStatut === '🟦En Attente Signature') {
                                    dvisBadge = {
                                        value: 'DEVIS: Envoyé',
                                        customCSS: 'background-color: #FFD966;',
                                        customClass: 'badge'
                                    }
                                } else if (devisStatut === '🟩Signé') {
                                    dvisBadge = {
                                        value: 'DEVIS: Signature Ok',
                                        customCSS: 'background-color: #B6D7A8;',
                                        customClass: 'badge'
                                    }
                                }
                                if (dvisBadge) {
                                    if (!ligne.Etape11StatutAdmin)
                                        ligne.Etape11StatutAdmin = {
                                            badges: []
                                        }
                                    ligne.Etape11StatutAdmin.badges.push(dvisBadge)
                                }
                            }

                            // // DR-Infos : si fiche non clôturée TH171, badge unique
                            // if (this._getVal(record, 'DR_Infos_Doss__c') !== '✅1') {
                            //     ligne.Etape11StatutAdmin = {
                            //         badges: [
                            //             {
                            //                 value: dossierAnnule
                            //                     ? 'Voir Motif Annulation TH171'
                            //                     : 'Attente Cloture TH171⏳',
                            //                 customCSS: 'background-color: #D9D9D9;',
                            //                 customClass: 'badge'
                            //             }
                            //         ]
                            //     }
                            // }
                            break
                            // ─── AGRI_TH119 - VMC ────────────────────────────────────────────────
                        case 'AGRI_TH119':
                            switch (ligne.Etape2StatutSecretariat.value) {
                                case '-':
                                    ligne.Etape11StatutAdmin = {
                                        badges: [
                                            // { value: 'En Attente', customCSS: 'background-color: #D9D9D9;', customClass: 'badge' }
                                        ]
                                    }
                                    ligne.Etape3StatutInstallation = {
                                        value: '-',
                                        customCSS: '',
                                        customClass: ''
                                    }
                                    ligne.Etape4StatutPaiement = {
                                        value: '-',
                                        customCSS: '',
                                        customClass: ''
                                    }
                                    break
                                case 'Date Planifiée':
                                    ligne.Etape11StatutAdmin = {
                                        badges: [{
                                            value: 'Admin Ok',
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }]
                                    }
                                    // "Installation:" PAC_Date_d_Installation__c
                                    dateInstallation = this._getVal(
                                        record,
                                        'PAC_Date_d_Installation__c'
                                    )
                                    // console.log("dateInstallation >> : ", JSON.stringify(dateInstallation));
                                    if (dateInstallation) {
                                        // console.log("dateInstallation is truthy");
                                        ligne.Etape3StatutInstallation = {
                                            value: `Installation: ${this._formatDate(
                                                dateInstallation
                                            )}`,
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }
                                    }
                                    // console.log("ligne.Etape3StatutInstallation >> : ", JSON.stringify(ligne.Etape3StatutInstallation));
                                    ligne.Etape4StatutPaiement = {
                                        value: '-',
                                        customCSS: '',
                                        customClass: ''
                                    }
                                    break
                                case 'Installation Non Finalisée':
                                    ligne.Etape11StatutAdmin = {
                                        badges: [{
                                            value: 'Admin Ok',
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }]
                                    }
                                    // "Installation:" PAC_Date_d_Installation__c
                                    dateInstallation = this._getVal(
                                        record,
                                        'PAC_Date_d_Installation__c'
                                    )
                                    if (dateInstallation) {
                                        ligne.Etape3StatutInstallation = {
                                            value: `Installation: ${this._formatDate(
                                                dateInstallation
                                            )}`,
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }
                                    }
                                    ligne.Etape4StatutPaiement = {
                                        value: '-',
                                        customCSS: '',
                                        customClass: ''
                                    }
                                    break
                                case 'Installation OK':
                                    ligne.Etape11StatutAdmin = {
                                        badges: [{
                                            value: 'Admin Ok',
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }]
                                    }
                                    // "Installation:" PAC_Date_d_Installation__c
                                    dateInstallation = this._getVal(
                                        record,
                                        'PAC_Date_d_Installation__c'
                                    )
                                    if (dateInstallation) {
                                        ligne.Etape3StatutInstallation = {
                                            value: `Installation: ${this._formatDate(
                                                dateInstallation
                                            )}`,
                                            customCSS: 'background-color: #B6D7A8;',
                                            customClass: 'badge'
                                        }
                                    }

                                    ligne.Etape4StatutPaiement = {
                                        value: 'Vérif Comptable',
                                        customCSS: 'background-color: #D9D9D9;',
                                        customClass: 'badge'
                                    }
                                    break
                            }
                            // Previsite badge (BAR_TH171) - ajouté le badge au debut
                            if (auditNecessite === 'OUI') {
                                let auditBadge = null
                                if (
                                    auditStatut === '🟧Audit- Modifs Demandées' ||
                                    auditStatut === '▣ Nouveau Dossier'
                                ) {
                                    auditBadge = {
                                        value: 'Audit: Demandé',
                                        customCSS: 'background-color: #9FC5E8;',
                                        customClass: 'badge'
                                    }
                                } else if (auditStatut === '🟩Audit- Validé') {
                                    //! Le conditionnement est en relation avec la partie suivante
                                    auditBadge = {
                                        value: previsiteNecessite === 'OUI' &&
                                            prvisiteStatut === '🟩Passage Effectué' ?
                                            'Prévisite+Audit OK' :
                                            'Audit Ok',
                                        customCSS: 'background-color: #B6D7A8;',
                                        customClass: 'badge'
                                    }
                                }
                                if (auditBadge) {
                                    if (!ligne.Etape11StatutAdmin)
                                        ligne.Etape11StatutAdmin = {
                                            badges: []
                                        }
                                    ligne.Etape11StatutAdmin.badges.unshift(auditBadge)
                                }
                            }

                            // Previsite badge (BAR_TH171) - ajouté le badge au debut
                            if (previsiteNecessite === 'OUI' && auditNecessite !== 'OUI') {
                                let previBadge = null
                                if (
                                    prvisiteStatut === '🟨Passage Demandé' ||
                                    prvisiteStatut === '▣ Att Planification'
                                ) {
                                    previBadge = {
                                        value: 'Prévisite: Demandé',
                                        customCSS: 'background-color: #9FC5E8;',
                                        customClass: 'badge'
                                    }
                                } else if (prvisiteStatut === '🟫Passage à Replanifier') {
                                    previBadge = {
                                        value: 'Prévisite: A Replanifier',
                                        customCSS: 'background-color: #FE9B4A;',
                                        customClass: 'badge'
                                    }
                                } else if (prvisiteStatut === '🟧Passage Planifié') {
                                    const prvisiteDate = this._getVal(
                                        record,
                                        'Pr_visite_Date_Passage__c'
                                    )
                                    const dateStr = prvisiteDate ?
                                        this._formatDate(prvisiteDate) :
                                        ''
                                    previBadge = {
                                        value: `Prévisite: Planifié${dateStr ? ' ' + dateStr : ''}`,
                                        customCSS: 'background-color: #FFD966;',
                                        customClass: 'badge'
                                    }
                                } else if (prvisiteStatut === '🟩Passage Effectué') {
                                    previBadge = {
                                        value: 'Prévisite Ok',
                                        customCSS: 'background-color: #B6D7A8;',
                                        customClass: 'badge'
                                    }
                                }
                                if (previBadge) {
                                    if (!ligne.Etape11StatutAdmin)
                                        ligne.Etape11StatutAdmin = {
                                            badges: []
                                        }
                                    ligne.Etape11StatutAdmin.badges.unshift(previBadge)
                                }
                            }

                            // Traitement 3 cas ICI
                            // Cas 1: Prévisite OUI + Passage Effectué + Audit NON
                            // Cas 2: Prévisite OUI + Passage Effectué + Audit OUI + Audit Validé
                            // Cas 3: Prévisite NON + Audit NON

                            if (cas1 || cas2 || cas3) {
                                const devisStatut = this._getVal(record, 'Devis_Statut__c')
                                let dvisBadge = null
                                if (devisStatut === '▣ Nouveau Dossier') {
                                    dvisBadge = {
                                        value: 'DEVIS: Demandé',
                                        customCSS: 'background-color: #9FC5E8;',
                                        customClass: 'badge'
                                    }
                                } else if (devisStatut === '🟦En Attente Signature') {
                                    dvisBadge = {
                                        value: 'DEVIS: Envoyé',
                                        customCSS: 'background-color: #FFD966;',
                                        customClass: 'badge'
                                    }
                                } else if (devisStatut === '🟩Signé') {
                                    dvisBadge = {
                                        value: 'DEVIS: Signature Ok',
                                        customCSS: 'background-color: #B6D7A8;',
                                        customClass: 'badge'
                                    }
                                }
                                if (dvisBadge) {
                                    if (!ligne.Etape11StatutAdmin)
                                        ligne.Etape11StatutAdmin = {
                                            badges: []
                                        }
                                    ligne.Etape11StatutAdmin.badges.push(dvisBadge)
                                }
                            }

                            // // DR-Infos : si fiche non clôturée TH171, badge unique
                            // if (this._getVal(record, 'DR_Infos_Doss__c') !== '✅1') {
                            //     ligne.Etape11StatutAdmin = {
                            //         badges: [
                            //             {
                            //                 value: dossierAnnule
                            //                     ? 'Voir Motif Annulation TH171'
                            //                     : 'Attente Cloture TH171⏳',
                            //                 customCSS: 'background-color: #D9D9D9;',
                            //                 customClass: 'badge'
                            //             }
                            //         ]
                            //     }
                            // }
                            break
                    }
                } else {
                    ligne.Etape2StatutSecretariat = {
                        value: '-',
                        customCSS: ''
                    }
                }
                return
            } else if (col.field == 'Etape3InfosInstallation') {
                const ficheCEE = this._getVal(record, 'Fiche_CEE__c')
                const matchedRule = this.mapStatusII.find(
                    rule => ficheCEE && ficheCEE.includes(rule.contains)
                )
                if (matchedRule && matchedRule.infoFields) {
                    const sep = matchedRule.infoSeparator || ' / '
                    const value = this._buildInfoFields(
                        record,
                        matchedRule.infoFields,
                        sep
                    )
                    ligne.Etape3InfosInstallation = {
                        value: value || '-',
                        customCSS: matchedRule.infoCSS || '',
                        customClass: matchedRule.infoClass || ''
                    }
                } else {
                    ligne.Etape3InfosInstallation = {
                        value: '-',
                        customCSS: '',
                        customClass: ''
                    }
                }
                return
            } else if (col.field === 'NomClient') {
                const htmlNomClient = this._getVal(record, 'PRO_Nom_Client__c')
                const nomSignataire = this._getVal(record, 'PRO_Nom_du_Signataire__c')
                // <a xxxx >Extraire this from htmlNomClient </a>
                const nomClient = htmlNomClient.replace(/<[^>]+>/g, '').trim()
                const nomSearch = nomClient + ' ' + nomSignataire
                const clientMax = 26;
                const nomClientTruncated =
                    nomClient.length > clientMax ?
                    nomClient.substring(0, clientMax) + '...' :
                    nomClient;
                // const nomSignataireTruncated = nomSignataire
                //     ? nomSignataire.length > MAX_SIGNATAIRE
                //         ? nomSignataire.substring(0, MAX_SIGNATAIRE) + '...'
                //         : nomSignataire
                //     : ''

                const clientMaxMobile = 20;
                const nomClientTruncatedMobile =
                    nomClient.length > clientMaxMobile ?
                    nomClient.substring(0, clientMaxMobile) + '...' :
                    nomClient;

                let colVal = {
                    value: nomSearch,
                    desktopValue: nomClientTruncated,
                    valueMobile: nomClientTruncatedMobile
                }
                ligne.NomClient = colVal
                return
            }
            if (col.field == 'ApporteurAffaire') {
                // ligne.ApporteurAffaire = { valueApporteur: '-', styleApporteur: 'color: var(--slate-400);', valueMiniAppAff: '', styleMiniAppAff: 'display: none;' };
                const apporteur = this._getVal(record, 'Nom_REGIE__c')
                const miniAppAff = this._getVal(record, 'Nom_REGIE_2__c')
                const campaignToken = this._getVal(
                    record,
                    'Campagne_REGIE__r.CampaignToken__c'
                )
                // console.log("campaignToken from lead : ", JSON.stringify(campaignToken));
                // console.log("campaignCode from component : ", JSON.stringify(this.campaignCode));
                //
                // let colVal = {
                //     valueApporteur: apporteur || '-',
                //     styleApporteur: "font-weight: 600; color: #4A86F0;",
                //     valueMiniAppAff: miniAppAff,
                //     styleMiniAppAff: miniAppAff ? "font-style: italic; color: #EA6666;" : "display: none;"
                // }
                //
                // Responsable Télépro : régie de NIVEAU 1 uniquement (campagne
                // mère). `apporteur` = niveau 1, `miniAppAff` = niveau 2 —
                // vérifié sur les données : Nom REGIE = Campagne_REGIE__r.Parent.Name.
                if (this.isRespoTelepro) {
                    ligne.ApporteurAffaire = {
                        value: apporteur || '-',
                        style: 'font-weight: 600; text-transform: uppercase; color: #4A86F0;'
                    }
                    return
                }
                let colVal = {
                    // value: campaignToken == this.campaignCode ? apporteur : miniAppAff,
                    value: miniAppAff || apporteur,
                    // style: campaignToken == this.campaignCode ? "font-weight: 600; text-transform: uppercase; color: #4A86F0;" : "font-weight: 600; text-transform: uppercase; font-style: italic; color: #EA6666;"
                    style: campaignToken == this.campaignCode ?
                        'font-weight: 600; text-transform: uppercase; color: #4A86F0;' :
                        'font-weight: 600; text-transform: uppercase; font-style: italic; color: #EA6666;'
                }
                ligne.ApporteurAffaire = colVal
                return
            } else if (col.field == 'Etape1StatutConfirmateur') {
                const val = 'Confirmation Ok'
                if (val) {
                    // check the val if part of the contain of the mapStatus and return the val of the mapStatus
                    const mapped = this.mapStatus.find(m => m.regex.test(val))
                    ligne.Etape1StatutConfirmateur = {
                        value: mapped ? mapped.val : val,
                        customCSS: mapped ? `background-color: ${mapped.badgeBG};` : '',
                        customClass: mapped ? 'badge' : ''
                    }
                    return
                }
                // ligne.Etape1StatutConfirmateur = { value: val, customCSS: this._statusClass(val) };
                return
            } else if (col.field === 'InformationsInstallation') {
                // → Champs individuels avec labels lisibles pour le tooltip
                const recHistory = historyMap[record.Id] || {}

                const precaritePiste = this._getVal(record, 'Bareme_Ma_prim_renovv__c');
                const precariteDossier = this._getVal(record, 'MPR_PRECARITE__c');
                const val_shab = this._getVal(record, 'MPR_SHAB__c');
                const val_shabPiste = this._getVal(record, 'Surface_habitablee__c');
                const valShabPref = val_shab || val_shabPiste || 0;
                // const valPrefere = precariteDossier && (precariteDossier !== '▣ En attente') ? precariteDossier : precaritePiste ? precaritePiste : val_shab ? `${val_shab}m²` : '';

                const estBlueSup90 = (precariteDossier === '🟦BLEU' || (precariteDossier === '▣ En attente' && precaritePiste === 'Bleu')) && valShabPref >= 90;

                const mprDocs = this._getVal(record, 'MPR_Docs__c')
                const hasDossierComplet =
                                        mprDocs &&
                                        mprDocs
                                        .split(';')
                                        .map(s => s.trim())
                                        .includes('🟩Dossier Complet');

                const fields = [{
                        label: '💬Commentaire Régie:',
                        value: this._getVal(record, 'REGIE_Commentaire_REGIE__c'),
                        lastModified: this._getVal(record, 'Piste_Date_de_Cr_ation__c') ?
                            this._formatDateTime(this._getVal(record, 'Piste_Date_de_Cr_ation__c'), 'dd/mm/yyyy') :
                            null
                        // recHistory['REGIE_Commentaire_REGIE__c']
                        //     ? this._formatDateTime(recHistory['REGIE_Commentaire_REGIE__c'])
                        //     : null
                    },
                    {
                        label: '💬Commentaire Confirmateur:',
                        value: this._getVal(record, 'Confirmateur_Commentaire__c'),
                        lastModified: recHistory['Confirmateur_Commentaire__c'] ?
                            this._formatDateTime(recHistory['Confirmateur_Commentaire__c']) :
                            this._formatDateTime(this._getVal(record, "CreatedDate"))
                    },
                    {
                        label: '💬Commentaire Installation:',
                        value: this._getVal(record, 'PAC_171_Commentaire_Interne__c'),
                        lastModified: recHistory['PAC_171_Commentaire_Interne__c'] ?
                            this._formatDateTime(recHistory['PAC_171_Commentaire_Interne__c']) :
                            this._formatDateTime(this._getVal(record, "CreatedDate"))
                    },
                    {
                        label: '📝DOCS- Statut:',
                        value: this._getVal(record, 'MPR_Docs__c')
                            ?.replace('⬛', ''),
                        lastModified: recHistory['MPR_Docs__c'] ?
                            this._formatDateTime(recHistory['MPR_Docs__c']) :
                            null,
                        condition: r => this._getVal(r, 'MPR_Docs__c') && this._getVal(r, 'MPR_Docs__c') !== '🟩Dossier Complet'
                    },
                    {
                        label: '💬Commentaire Secrétaire:',
                        value: this._getVal(record, 'CEE_Commentaire_Secr_taire__c')
                            ?.replace('⬛', ''),
                        lastModified: recHistory['CEE_Commentaire_Secr_taire__c'] ?
                            this._formatDateTime(recHistory['CEE_Commentaire_Secr_taire__c']) :
                            null,
                        // condition: r => ['🟨Anomalie', '🟫En Att Code- Voie Postal', '🟦Envoyé'].includes(this._getVal(r, 'PAC_Statut_MPR__c')) || (mprDocs && !hasDossierComplet) || ( ['▣ En Attente Envoi'].includes(this._getVal(r, 'PAC_Statut_MPR__c')) && !estBlueSup90)
                        condition: r => this._getVal(r, 'CEE_Commentaire_Secr_taire__c')
                    }, 
                    // {
                    //     label: '⬛Motif Annulation:',
                    //     value: this._getVal(record, 'RDV_Motif_Annulation__c')
                    //         // ?.replace('- Voir Commentaire', '')
                    //         ?.replace('⬛', ''),
                    //     lastModified: recHistory['RDV_Motif_Annulation__c'] ?
                    //         this._formatDateTime(recHistory['RDV_Motif_Annulation__c']) :
                    //         null,
                    //     customCSS: 'margin-top: 1rem;',
                    //     condition: r => this._getVal(r, 'PAC_STATUT_DOSSIER__c') == '⚫DOSSIER- Annulé'
                    // },
                    {
                        label: '🟥Commentaire Annulation:',
                        value: this._getVal(record, 'RDV_Commentaire_Annulation__c')
                            ?.replace('⬛', ''),
                        lastModified: recHistory['RDV_Commentaire_Annulation__c'] ?
                            this._formatDateTime(recHistory['RDV_Commentaire_Annulation__c']) :
                            null,
                        condition: r => this._getVal(r, 'PAC_STATUT_DOSSIER__c') == '⚫DOSSIER- Annulé'
                    },
                ].filter(f => f.value);
                const fieldToShow = fields.filter(r => !r.condition || r.condition(record)) || [];
                ligne.InfosInstallation = {
                    title: 'Informations Installation',
                    value: fieldToShow.map(f => f.value).join(' | '),
                    hasData: fieldToShow.length > 0,
                    nombreCommentaires: fieldToShow.length || 0,
                    fields: fieldToShow
                }
                return
            } else if (col.field === 'CreatedDate') {
                // → Date formatée
                ligne.CreatedDate = {
                    value: this._formatDate(this._getVal(record, 'Piste_Date_de_Cr_ation__c')) || '-',
                    displayedValue: this._formatDate(this._getVal(record, 'Piste_Date_de_Cr_ation__c')) || '-'
                }
                return;
            } else if (col.field === 'LastModifiedDate') {
                // REP_DerniereModif__c if empty then CreatedDate
                const valLastModifiedDateD = this._getVal(record, 'REP_DerniereModif__c') || this._getVal(record, 'LastModifiedDate');
                ligne.LastModifiedDate = {
                    value: this._formatDate(valLastModifiedDateD) || '-',
                    displayedValue: this._formatDate(valLastModifiedDateD) || '-'
                }
                // ligne.LastModifiedDate = { value: "test" }
                return
            } else if (col.skipPro || col.proField === '-') {
                ligne[col.field] = {
                    value: '-'
                }
                return
            }

            const raw = this._getVal(record, col.proField)

            if (col.field === 'LastModifiedDate_Old') {
                // → Date formatée
                ligne[col.field] = {
                    value: this._formatDate(raw) || '-'
                }
            }
            // else if (col.field === 'Etape1StatutConfirmateur' || col.field === 'Etape2StatutSecretariat' || col.field === 'Etape3StatutInstallation') {
            //     // → Badge statut coloré
            //     ligne[col.field] = { value: raw || '-', customCSS: raw ? this._statusClass(raw) : '' };

            // }
            else {
                // → Texte brut (inclut multi-champs via _getVal)
                ligne[col.field] = {
                    value: raw || '-'
                }
            }
        })

        return ligne
    }

    // ─── Tooltip Infos Confirmation ─────────────────────────────────────────

    _tooltipAnchorRect = null
    _tooltipAnchorEl = null
    _needsReposition = false
    _scrollHandler = null

    // ─── Resize colonnes ─────────────────────────────────────────────────────

    _resizeState = null // { th, startX, startWidth }
    _resizerMoveHandler = null
    _resizerUpHandler = null

    // Initialise le resize par glissement du bord droit du th
    _initResizers() {
        const EDGE = 7 // zone en px depuis le bord droit qui active le resize
        const ths = this.template.querySelectorAll('th[data-sizable="true"]')
        ths.forEach(th => {
            if (th.dataset.resizerAttached) return // déjà initialisé
            th.dataset.resizerAttached = '1'

            th.addEventListener('mousemove', e => {
                if (this._resizeState) return // en cours de drag
                const nearEdge = e.clientX >= th.getBoundingClientRect().right - EDGE
                th.style.cursor = nearEdge ? 'col-resize' : ''
            })

            th.addEventListener('mouseleave', () => {
                if (!this._resizeState) th.style.cursor = ''
            })

            th.addEventListener('mousedown', e => {
                const nearEdge = e.clientX >= th.getBoundingClientRect().right - EDGE
                if (!nearEdge) return
                this._onResizerDown(e, th)
            })
        })
    }

    _onResizerDown(e, th) {
        e.preventDefault()
        e.stopPropagation()
        this._resizeState = {
            th,
            startX: e.clientX,
            startWidth: th.offsetWidth
        }
        document.body.style.cursor = 'col-resize'
        document.body.style.userSelect = 'none'
        this._resizerMoveHandler = ev => this._onResizerMove(ev)
        this._resizerUpHandler = () => this._onResizerUp()
        document.addEventListener('mousemove', this._resizerMoveHandler)
        document.addEventListener('mouseup', this._resizerUpHandler)
    }

    _onResizerMove(e) {
        if (!this._resizeState) return
        const {
            th,
            startX,
            startWidth
        } = this._resizeState
        const newWidth = Math.max(40, startWidth + (e.clientX - startX))
        th.style.width = `${newWidth}px`
        th.style.minWidth = `${newWidth}px`
    }

    _onResizerUp() {
        this._resizeState = null
        document.body.style.cursor = ''
        document.body.style.userSelect = ''
        document.removeEventListener('mousemove', this._resizerMoveHandler)
        document.removeEventListener('mouseup', this._resizerUpHandler)
    }

    // Après chaque rendu : repositionne le tooltip + initialise les resizers
    renderedCallback() {
        this._initResizers()
        if (!this._needsReposition) return
        this._needsReposition = false
        this._applyTooltipPosition()
    }

    // Recalcule la position depuis l'élément anchor (utilisé au scroll)
    _repositionTooltip() {
        if (!this.tooltip.visible || !this._tooltipAnchorEl) return
        this._tooltipAnchorRect = this._tooltipAnchorEl.getBoundingClientRect()
        this._applyTooltipPosition()
    }

    // Applique le positionnement : à GAUCHE de la bulle, centré verticalement
    _applyTooltipPosition() {
        const el = this.template.querySelector('.floating-tooltip')
        if (!el) return

        const tw = el.offsetWidth
        const th = el.offsetHeight
        const r = this._tooltipAnchorRect
        const MARGIN = 8
        const vh = window.innerHeight

        // À gauche de la bulle, clamped dans le viewport
        const left = Math.max(MARGIN, r.left - tw - MARGIN)

        // Centré verticalement sur la bulle, clamped dans le viewport
        const top = Math.max(
            MARGIN,
            Math.min(r.top + r.height / 2 - th / 2, vh - th - MARGIN)
        )

        el.style.top = `${top}px`
        el.style.left = `${left}px`
        el.style.visibility = 'visible'
    }

    // Clic sur la bulle : ouvre le tooltip (ou ferme si même bulle)
    handleInfosClick(event) {
        event.stopPropagation()
        const id = event.currentTarget.dataset.id
        const type = event.currentTarget.dataset.type
        // Toggle : re-clic sur la même bulle → fermer
        if (this.tooltip.visible && this.tooltip.recordId === id) {
            this.tooltip = {
                visible: false,
                fields: [],
                style: ''
            }
            return
        }
        const ligne = this.reportingData.find(l => l.id === id)
        if (type === 'Piste') {
            if (
                !ligne ||
                !ligne.InfosConfirmation ||
                !ligne.InfosConfirmation.hasData
            )
                return
        } else if (type === 'Dossier') {
            if (
                !ligne ||
                !ligne.InfosInstallation ||
                !ligne.InfosInstallation.hasData
            )
                return
        }

        // Sauvegarder l'élément et son rect pour renderedCallback et scroll
        this._tooltipAnchorEl = event.currentTarget
        this._tooltipAnchorRect = event.currentTarget.getBoundingClientRect()
        this._needsReposition = true

        // Rendre le tooltip invisible hors-écran le temps que renderedCallback calcule la vraie position
        this.tooltip = {
            title: type === 'Piste' ?
                ligne.InfosConfirmation.title :
                ligne.InfosInstallation.title,
            visible: true,
            fields: type === 'Piste' ?
                ligne.InfosConfirmation.fields :
                ligne.InfosInstallation.fields,
            recordId: id,
            recordType: type,
            style: 'top: -9999px; left: -9999px; visibility: hidden;'
        }
    }

    // Bouton X : ferme le tooltip
    handleTooltipClick(event) {
        event.stopPropagation()
    }

    handleTooltipClose(event) {
        event.stopPropagation()
        this.tooltip = {
            visible: false,
            fields: [],
            style: ''
        }
    }

    get hasData() {
        return this.filteredData && this.filteredData.length > 0
    }

    // Rafraîchir les données
    handleRefresh(e) {
        e.stopPropagation()
        this.chargerDonnees()
    }

    /* ════════════════════════════════════
       PASTILLE « DOCUMENTS » (colonne Com)

       Le reporting ne connaît RIEN des pièces jointes : il demande un simple
       comptage, et délègue tout le reste à c/lwc026_documents, qui ne reçoit
       que l'Id de la ligne. C'est ce composant qui décide de ce qui est permis
       (ajout et suppression sur une Piste, consultation seule sur un Dossier).
       ════════════════════════════════════ */

    /**
     * Renseigne `ligne.Documents` pour toutes les lignes chargées.
     *
     * Un échec est SILENCIEUX : la pastille affiche alors 0 document et reste
     * cliquable — la modale, elle, saura dire pourquoi. Faire échouer tout le
     * reporting pour un compteur serait disproportionné.
     */
    chargerCompteursDocuments() {
        const ids = (this.reportingData || []).map(l => l.id).filter(Boolean)
        if (!ids.length) return

        const lots = []
        for (let i = 0; i < ids.length; i += LOT_COMPTAGE_DOCUMENTS) {
            lots.push(ids.slice(i, i + LOT_COMPTAGE_DOCUMENTS))
        }

        // Les lignes de référence sont mémorisées : si l'utilisateur relance un
        // chargement pendant le comptage, le résultat périmé est ignoré.
        const donneesAttendues = this.reportingData

        Promise.all(
            lots.map(lot =>
                compterDocuments({
                    recordIds: lot,
                    campaignCode: this.campaignCode || ''
                }).catch(() => ({}))
            )
        ).then(resultats => {
            if (this.reportingData !== donneesAttendues) return
            const compteurs = Object.assign({}, ...resultats.map(r => r || {}))
            this.reportingData = this.reportingData.map(ligne => ({
                ...ligne,
                Documents: this._celluleDocuments(compteurs[ligne.id] || 0)
            }))
        })
    }

    /** Modèle de la pastille : le template ne calcule rien. */
    _celluleDocuments(nombre) {
        return {
            nombre,
            aDocuments: nombre > 0,
            // Deux couleurs, pas deux icônes : la forme dit « documents », la
            // teinte dit « il y en a » — un gris pâle pour une pastille vide.
            couleur: nombre > 0 ? '#7C3AED' : '#CBD5E1',
            couleurTexte: nombre > 0 ? '#ffffff' : '#64748B'
        }
    }

    // Id du record dont la modale de documents est ouverte ; null = fermée.
    documentsRecordId = null

    handleOuvrirDocuments(event) {
        event.stopPropagation()
        // Le tooltip de commentaires resterait ancré sous la modale.
        this.tooltip = { visible: false, fields: [], style: '' }
        this.documentsRecordId = event.currentTarget.dataset.id
    }

    handleCloseDocuments(event) {
        if (event) event.stopPropagation()
        this.documentsRecordId = null
    }

    /**
     * La modale a ajouté ou supprimé un document : on remet la pastille à jour
     * sur place, sans recharger tout le reporting.
     */
    handleDocumentsChange(event) {
        const detail = (event && event.detail) || {}
        if (!detail.recordId) return
        this.reportingData = (this.reportingData || []).map(ligne =>
            ligne.id === detail.recordId
                ? { ...ligne, Documents: this._celluleDocuments(detail.nombre || 0) }
                : ligne
        )
    }

    /* ════════════════════════════════════
       ACTION « SIGNER DEVIS » (colonne Com)

       Le reporting ne connaît RIEN du devis : il ouvre c/lwc021_devis_signature
       avec le seul Id de la ligne. Toute la logique métier (identification
       Piste/Dossier, statut, récapitulatif, puissance, document, signature)
       vit dans ce composant, qui recharge lui-même ses données côté serveur.
       ════════════════════════════════════ */

    // Id du record dont la modale de devis est ouverte ; null = modale fermée.
    devisRecordId = null

    // Onglet sur lequel ouvrir la modale. null = elle decide seule. Seul le
    // stylo de « Att. signature » le renseigne, pour mener droit a l'envoi.
    devisEtapeInitiale = null

    handleSignerDevis(event) {
        event.stopPropagation()
        // Le tooltip de commentaires resterait ancré sous la modale.
        this.tooltip = { visible: false, fields: [], style: '' }
        // `data-onglet` n'est pose que par le stylo de « Att. signature » :
        // ailleurs il vaut undefined, et la modale choisit elle-meme.
        this.devisEtapeInitiale = event.currentTarget.dataset.onglet || null
        this.devisRecordId = event.currentTarget.dataset.id
    }

    handleCloseDevis(event) {
        if (event) event.stopPropagation()
        this.devisRecordId = null
        // Sans cette remise a zero, une ouverture suivante par le libelle
        // atterrirait encore sur l'onglet Signature.
        this.devisEtapeInitiale = null
    }
}