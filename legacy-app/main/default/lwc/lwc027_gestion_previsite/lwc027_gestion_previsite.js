import { LightningElement, api, track } from 'lwc';
import { etiquettes } from 'c/lwc027_i18n';
import getContratStockeBase64 from '@salesforce/apex/LC027_GestionContrat.getContratStockeBase64';
import getContrat from '@salesforce/apex/LC027_GestionContrat.getContrat';
import getDossiers from '@salesforce/apex/LC027_DossiersPrevisite.getDossiers';
import getHistorique from '@salesforce/apex/LC027_DossiersPrevisite.getHistorique';
import getDossier from '@salesforce/apex/LC027_DossiersPrevisite.getDossier';
import getAccesCertiko from '@salesforce/apex/LC027_DossiersPrevisite.getAccesCertiko';
import enregistrerNrp from '@salesforce/apex/LC027_DossiersPrevisite.enregistrerNrp';
import planifier from '@salesforce/apex/LC027_DossiersPrevisite.planifier';
import replanifierApresEnvoi from '@salesforce/apex/LC027_DossiersPrevisite.replanifierApresEnvoi';
import rendreVisite from '@salesforce/apex/LC027_DossiersPrevisite.rendreVisite';
import demarrerPrevisite from '@salesforce/apex/LC027_DossiersPrevisite.demarrerPrevisite';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import { base64VersOctets, lignesRecap } from 'c/lwc027_gestion_contrat';

/**
 * lwc027_gestion_previsite — accueil du pré-visiteur et gestion de ses visites.
 *
 * DEUX MODES
 *   • contrat EN ATTENTE de signature : accueil verrouillé (encadré jaune,
 *     récap des informations, recours) — aucune visite n'est chargée ;
 *   • contrat SIGNÉ : les visites du pré-visiteur (Pro__c), servies par
 *     LC027_DossiersPrevisite.
 *
 * ÉCRANS (navigation interne, `vue`)
 *   accueil -> aPlanifier -> fixer -> confirme (SMS)
 *           -> planifiees -> fixer (replanifier) -> confirme
 *                         -> previsite (envoi Certiko, relevé terrain, statut)
 *
 * LES DEUX LISTES SONT DES VUES DE TYPE « LISTE SALESFORCE » : tableau trié et
 * filtré, paginé, avec les actions en bout de ligne.
 *   • « à planifier » : les tentatives d'appel sont une COLONNE (badge + « +1 »),
 *     plus un bloc de la fiche ;
 *   • « rendre la visite à ECONATURA » se fait dans une FENÊTRE (deux temps :
 *     motif puis confirmation), ouverte depuis la liste ou depuis la fiche ;
 *   • « fixer le rendez-vous » reste sur la fiche du dossier, avec
 *     l'historique du dossier en tête.
 *
 * « Itinéraire » ouvre Google Maps en mode navigation, SANS point de départ :
 * Google part alors de la position du téléphone.
 */

const VUE_ACCUEIL     = 'accueil';
const VUE_A_PLANIFIER = 'aPlanifier';
const VUE_PLANIFIEES  = 'planifiees';
const VUE_FIXER       = 'fixer';
const VUE_CONFIRME    = 'confirme';
/** Fiche de la visite du jour : envoi à Certiko puis relevé terrain. */
const VUE_PREVISITE   = 'previsite';

/**
 * CARTE DÉSACTIVÉE — le composant lwc027_carte et la ressource Leaflet sont
 * déployés mais pas encore utilisés. À faux :
 *   • le bouton « Voir sur la carte » n'est pas rendu ;
 *   • la carte n'est jamais montée, donc Leaflet (≈ 145 Ko) n'est JAMAIS
 *     téléchargé — loadScript n'a lieu qu'au montage de la carte.
 * Remettre à vrai pour la rouvrir : rien d'autre à changer.
 */
const CARTE_ACTIVE = false;

/** Appels sans réponse requis avant le motif « injoignable ». */
const NRP_MAX = 3;

/** Nombre de lignes par page proposé dans les deux listes. */
const TAILLES_PAGE = [26, 50, 100];

/**
 * Créneaux proposés pour l'heure du rendez-vous : de 8 h à 19 h, par demi-heure.
 * Une liste déroulante se manipule d'un geste, là où le champ « time » du
 * navigateur demande de viser des flèches ou de taper chiffre par chiffre.
 */
const HEURE_PREMIERE = 8;
/** Dernier créneau : 19 h 00 pile, pas 19 h 30. */
const HEURE_DERNIERE = 19;
const PAS_MINUTES = 30;

/**
 * SUIVI DU STATUT — le portail n'appelle plus Certiko. C'est le webhook
 * (LC027_CertikoRetour) qui écrit le statut dès qu'il change là-bas, puis
 * publie Certiko_Maj__e. La fiche ouverte écoute cet événement et se réaffiche
 * toute seule : rien à rafraîchir, aucun appel sortant.
 */
const CANAL_MAJ = '/event/Certiko_Maj__e';

/**
 * Délai au-delà duquel l'abonnement est considéré perdu.
 *
 * ⚠️ subscribe() NE REJETTE PAS quand la liaison CometD n'aboutit pas : sa
 * promesse reste en attente pour toujours. Sans ce garde-fou, l'écran restait
 * muet — ni écoute, ni repli — et rien n'indiquait pourquoi.
 */
const ABONNEMENT_DELAI_MS = 8000;

/**
 * RELECTURE — c'est elle qui fait le travail aujourd'hui.
 *
 * L'écoute des événements suppose une session d'API, que l'invité d'un site
 * n'a pas : essai fait sur CopieProd le 2026-09-23 en lui accordant
 * « API activée », la liaison n'aboutit toujours pas. Cette permission a été
 * retirée — l'ouvrir à un visiteur anonyme coûterait bien plus cher que ce
 * qu'elle rapporte.
 *
 * La fiche relit donc LE SEUL DOSSIER OUVERT à ce rythme : une requête, pas
 * les deux listes. Toujours aucun appel vers Certiko, seul le webhook leur
 * parle.
 */
const REPLI_SECONDES = 5;

/**
 * Valeur d'API du statut Certiko qui clot la visite technique. Elle decide de
 * l'etat « terminee » et de la sortie de la liste — d'ou la constante plutot
 * que la chaine repetee.
 */
const VT_TERMINEE = 'terminee';

/** Durée d'affichage du « Copié » sur un bouton d'identifiant, en ms. */
const DUREE_COPIE_MS = 2000;

/** Types d'événements montrés sur un dossier DÉJÀ PLANIFIÉ. */
const HISTORIQUE_PLANIFIE = ['ajout', 'rdv', 'replanif'];

/** Donneur d'ordre : même nom dans les deux langues. */
const MARQUE = 'ECONATURA';

/**
 * Le pré-visiteur peut replier son bloc d'accès Certiko. Le choix est retenu
 * d'un écran à l'autre : le rouvrir à chaque visite reviendrait à afficher un
 * mot de passe que la personne vient justement de masquer.
 *
 * Clé PROPRE au portail Prévisites — les deux portails partagent le même
 * domaine, une clé commune les ferait se marcher dessus.
 */


/**
 * Motifs proposés. Le texte ENREGISTRÉ dans Pro__c.PREVISITE_Motif_Rendu__c est
 * le libellé dans la LANGUE D'AFFICHAGE (ou le texte libre pour « Autre »).
 * La clé est transmise à part : c'est elle que LC027_DossiersPrevisite contrôle
 * (« injoignable » = CLE_MOTIF_INJOIGNABLE).
 */
const MOTIFS = [
    { cle: 'desinteret',  libelle: 'motifDesinteret' },
    { cle: 'injoignable', libelle: 'motifInjoignable', nrp: true },
    { cle: 'autre',       libelle: 'motifAutre', libre: true }
];

/**
 * Historique : type d'événement -> étiquette et couleur. Le libellé « nrp » est
 * bâti à part, il porte le numéro de la tentative.
 */
const TAGS_HISTORIQUE = {
    creation: { cle: 'histTagAjout',    classe: 'hist-tag hist-tag-add' },
    ajout:    { cle: 'histTagAjout',    classe: 'hist-tag hist-tag-add' },
    nrp:      { cle: null,              classe: 'hist-tag hist-tag-nrp' },
    rdv:      { cle: 'histTagRdv',      classe: 'hist-tag hist-tag-rdv' },
    replanif: { cle: 'histTagReplanif', classe: 'hist-tag hist-tag-rep' },
    rendu:    { cle: 'histTagRendu',    classe: 'hist-tag hist-tag-pv' },
    retire:   { cle: 'histTagRetire',   classe: 'hist-tag hist-tag-pv' }
};

/** Modèle du SMS, TOUJOURS en espagnol : il part vers le client espagnol. */
const MODELE_SMS =
    'Hola {client}, soy {previsiteur}, técnico de ECONATURA.\n' +
    'Confirmo nuestra cita para la visita técnica de su vivienda:\n' +
    '📅 {date} a las {heure}\n' +
    '📍 {adresse}\n' +
    '⏱️ Duración aproximada: 1 hora\n\n' +
    'Para el día de la visita, tenga a mano:\n' +
    '· su última factura de electricidad y las de noviembre a marzo\n' +
    '· su DNI\n\n' +
    'Cualquier cambio, avíseme a este mismo número. Un saludo.';

export default class Lwc027GestionPrevisite extends LightningElement {
    /** Token de campagne : sert à chaque appel serveur. */
    @api token;
    /** Nom du pré-visiteur (Campaign.Name). */
    @api nom;
    /** Langue d'affichage, pilotée par le conteneur. */
    @api langue;
    /**
     * Contrat parti en signature mais pas encore signé : le portail s'affiche
     * en entier mais VERROUILLÉ, avec l'explication.
     */
    @api contratEnAttente = false;
    /** Email destinataire du contrat, cité dans le message d'attente. */
    @api email;
    /**
     * Mode test du portail (?c__test=true, mémorisé par le conteneur). Il
     * n'ouvre ici qu'un bandeau de contrôle du sondage Certiko.
     */
    @api modeTest = false;

    @track vue = VUE_ACCUEIL;
    @track messageEcran;
    @track typeMessage = 'info';
    @track enCours = false;
    /** URL blob: du contrat (mode verrouillé), posée sur un vrai lien. */
    @track urlPdf = null;
    /** Informations envoyées dans le contrat (mode verrouillé). */
    @track etatContrat = null;

    /* Visites */
    @track dossiers = { aPlanifier: [], planifies: [] };
    @track chargementDossiers = false;
    @track dossierId = null;
    /** Identifiant qui vient d'être copié : 'login', 'motDePasse' ou null. */
    @track copieFaite = null;
    _minuteurCopie;

    /** Dossier en attente de confirmation avant replanification, ou null. */
    @track replanifIdEnAttente = null;
    /**
     * Vrai entre la confirmation de l'avertissement et l'enregistrement de la
     * nouvelle date : c'est ce drapeau qui declenche la purge Certiko.
     */
    replanifApresEnvoi = false;

    @track saisieDate = '';
    @track saisieHeure = '';
    /** Dossier tout juste planifié : alimente l'écran SMS. */
    @track rdvConfirme = null;
    @track smsCopie = false;
    /** Liste affichée en carte (lwc027_carte) plutôt qu'en lignes. */
    @track carteOuverte = false;

    /* Vue liste « à planifier » : filtres, tri, pagination */
    @track filtres = { q: '', appels: '', province: '', age: '' };
    @track tri = { col: 'cree', sens: 'desc' };
    @track page = 1;
    @track parPage = TAILLES_PAGE[0];

    /* Vue liste « planifiées » */
    @track qPlanifiees = '';
    @track pagePlanifiees = 1;
    @track parPagePlanifiees = TAILLES_PAGE[0];

    /* Fenêtre « rendre la visite » : motif puis confirmation */
    @track rendreOuvert = false;
    @track rendreConfirmation = false;
    @track rendreId = null;
    @track motifCle = '';
    @track motifLibre = '';

    /* Historique du dossier ouvert */
    @track historique = [];

    /* Accès Certiko du pré-visiteur */
    @track acces = null;

    /* Suivi du statut Certiko */
    /**
     * Statut renvoyé par Certiko et refusé par notre liste de sélection. Ne
     * s'affiche qu'en mode test : c'est un signal pour nous, pas pour le
     * pré-visiteur, dont le dossier garde simplement son statut précédent.
     */
    @track statutRefuse = null;
    /** 'local' (relecture régulière), 'ecoute' (événement de plateforme), ou null. */
    @track modeSuivi = null;
    /** Raison d'un abonnement refusé — affichée en mode test seulement. */
    @track detailSuivi = null;
    /*
     * Compte a rebours du bandeau de test. PAS de @track et JAMAIS lu par le
     * template : il change chaque seconde, et chaque rendu effacait la
     * selection de texte en cours — on ne pouvait plus copier un identifiant
     * avec ?c__test=true. C'est majBandeauSondage() qui l'ecrit dans le DOM.
     */
    _suiviRestant = 0;
    @track suiviMajs = 0;
    /** Abonnement empApi en cours, à rendre en quittant la fiche. */
    abonnement = null;
    /** Minuteur d'une seconde du repli : compte à rebours ET déclencheur. */
    minuteurSuivi = null;

    connectedCallback() {
        if (this.contratEnAttente) {
            this.chargerContrat();
            this.chargerRecap();
        } else {
            this.chargerDossiers();
            this.chargerAcces();
        }
    }

    disconnectedCallback() {
        clearTimeout(this._minuteurCopie);
        this.libererBlob();
        // Quitter la page ne doit laisser ni abonnement ni minuteur derrière.
        this.arreterSuivi();
    }

    /* ══════════════════════ Libellés ══════════════════════ */

    get txt() {
        return etiquettes('previsite', this.langue);
    }

    get locale() {
        return this.langue === 'fr' ? 'fr-FR' : 'es-ES';
    }

    t(cle, n) {
        return (this.txt[cle] || '').replace('{n}', n);
    }

    get salutation() {
        return this.nom ? `${this.txt.salutation} ${this.nom}` : this.txt.salutation;
    }

    /* ══════════════════════ Écrans ══════════════════════ */

    /**
     * Les vues liste sont plus larges que le reste du portail : à 900 px, huit
     * colonnes débordent et les boutons d'action passent sous le défilement
     * horizontal. Les autres écrans gardent la largeur de lecture.
     */
    get classeRacine() {
        return (this.estAPlanifier || this.estPlanifiees)
            ? 'previsite previsite-liste'
            : 'previsite';
    }

    get estAccueil()    { return this.vue === VUE_ACCUEIL; }
    get estAPlanifier() { return this.vue === VUE_A_PLANIFIER; }
    get estPlanifiees() { return this.vue === VUE_PLANIFIEES; }
    get estFixer()      { return this.vue === VUE_FIXER && !!this.dossierCourant; }
    get estConfirme()   { return this.vue === VUE_CONFIRME && !!this.rdvConfirme; }
    get estPrevisite()  { return this.vue === VUE_PREVISITE && !!this.dossierCourant; }

    aller(vue) {
        // Arrêt SYSTÉMATIQUE : quel que soit le chemin de sortie (retour, tuile,
        // rendu de la visite), le suivi ne survit pas au changement d'écran.
        // Seule l'ouverture de la fiche de prévisite le relance.
        this.arreterSuivi();
        this.statutRefuse = null;
        this.vue = vue;
        this.messageEcran = null;
        this.smsCopie = false;
        try {
            window.scrollTo({ top: 0 });
        } catch (e) {
            // Défilement indisponible : sans conséquence.
        }
    }

    handleAccueil() {
        this.aller(VUE_ACCUEIL);
    }

    handleAPlanifier() {
        if (this.contratEnAttente) return;
        this.carteOuverte = false;
        this.aller(VUE_A_PLANIFIER);
    }

    handlePlanifiees() {
        if (this.contratEnAttente) return;
        this.carteOuverte = false;
        this.aller(VUE_PLANIFIEES);
    }

    /* ══════════════════════ Carte ══════════════════════ */

    /** La carte reste fermée tant que CARTE_ACTIVE est faux. */
    get carteDisponible() {
        return CARTE_ACTIVE;
    }

    handleBasculerCarte() {
        if (!CARTE_ACTIVE) return;
        this.carteOuverte = !this.carteOuverte;
    }

    get libelleBasculeCarte() {
        return this.carteOuverte ? this.txt.voirListe : this.txt.voirCarte;
    }

    /**
     * Points de la carte. Seule l'ADRESSE est transmise : la carte la localise
     * elle-même (lwc027_carte est autonome).
     */
    get pointsAPlanifier() {
        return this.dossiers.aPlanifier.map((d) => ({
            id: d.id,
            titre: d.nom,
            adresse: d.adresse,
            sousTitre: d.nrp > 0 ? this.t('pillNrp', d.nrp) : this.txt.pillNouveau,
            couleur: d.nrp > 0 ? 'alerte' : 'defaut'
        }));
    }

    get pointsPlanifies() {
        const debut = this.debutDuJour();
        return this.dossiers.planifies.map((d) => {
            let couleur = 'info';
            if (this.estAujourdhui(d.datePassage)) couleur = 'defaut';
            else if (new Date(d.datePassage) < debut) couleur = 'attente';
            return {
                id: d.id,
                titre: d.nom,
                adresse: d.adresse,
                sousTitre: this.quandPlanifie(d),
                couleur
            };
        });
    }

    /* ══════════════════════ Prévisite (Certiko) ══════════════════════ */

    /** Ouvre la fiche de prévisite d'une visite planifiée. */
    handleDemarrer(event) {
        this.dossierId = event.currentTarget.dataset.id;
        this.aller(VUE_PREVISITE);
        this.chargerHistorique();
        this.suivreLeDossier();
    }

    get certikoEnvoye() {
        return !!(this.dossierCourant && this.dossierCourant.certikoEnvoye);
    }

    get rdvCourant() {
        const d = this.dossierCourant;
        return d && d.datePassage ? this.formatDateLongue(new Date(d.datePassage)) : null;
    }

    get envoiCertikoLe() {
        const d = this.dossierCourant;
        return d && d.certikoDateEnvoi ? this.formatDateLongue(new Date(d.certikoDateEnvoi)) : null;
    }

    /**
     * Statut de la visite, LISIBLE — jamais la valeur d'API.
     * Trois sources, dans cet ordre : la traduction du portail (le
     * pré-visiteur est espagnol), à défaut le libellé de la liste de sélection
     * Salesforce, à défaut la valeur brute — qui ne doit rester à l'écran que
     * le temps d'ajouter le statut quelque part.
     */
    get statutVt() {
        const d = this.dossierCourant;
        const valeur = d && d.certikoStatutVt;
        if (!valeur) return this.txt.statutInconnu;
        const traductions = this.txt.statutsVt || {};
        return traductions[valeur] || d.certikoStatutVtLibelle || valeur;
    }

    /** Envoi à Certiko. Le serveur refuse un second envoi : rien à verrouiller ici. */
    async handleEnvoyerCertiko() {
        let dossier;
        const ok = await this.executer(async () => {
            dossier = await demarrerPrevisite({
                campaignToken: this.token, dossierId: this.dossierId
            });
            await this.chargerDossiers();
        });
        if (ok) {
            this.statutRefuse = (dossier && dossier.certikoStatutRefuse) || null;
            // Le dossier vient d'arriver chez Certiko : le suivi commence.
            this.suivreLeDossier();
        }
    }

    /* ══════════════════════ Suivi du statut Certiko ══════════════════════ */

    /**
     * Suit les changements du dossier ouvert, SANS jamais appeler Certiko.
     *
     * LA RELECTURE DÉMARRE TOUT DE SUITE, et l'écoute est tentée EN PARALLÈLE.
     * L'ordre compte : attendre l'abonnement d'abord laissait la fiche figée
     * plusieurs secondes — et indéfiniment là où l'écoute n'aboutit jamais,
     * ce qui est le cas de l'invité d'un site.
     *
     * Si l'écoute finit par prendre, elle remplace la relecture : rien à
     * changer le jour où ce portail aura des utilisateurs authentifiés.
     */
    suivreLeDossier() {
        this.arreterSuivi();
        if (!this.certikoEnvoye) return;
        this.detailSuivi = null;
        this.demarrerRepli();
        this.tenterEcoute();
    }

    /** Essai d'abonnement. Un échec ne change rien : la relecture tourne déjà. */
    async tenterEcoute() {
        const dossierId = this.dossierId;
        try {
            onError((erreur) => {
                // Le refus arrive PAR ICI, pas en rejet de la promesse : c'est
                // la seule façon de savoir que la liaison n'aboutira pas.
                this.detailSuivi = this.resumerErreur(erreur);
                console.warn('Flux des evenements refuse :', JSON.stringify(erreur));
            });
            const abonnement = await this.avecDelai(
                subscribe(CANAL_MAJ, -1, (message) => this.surMaj(message))
            );
            // La fiche a pu se fermer pendant l'essai : ne rien laisser derrière.
            if (this.dossierId !== dossierId || !this.estPrevisite) {
                unsubscribe(abonnement, () => {});
                return;
            }
            this.abonnement = abonnement;
            this.arreterMinuteur();
            this.modeSuivi = 'ecoute';
        } catch (e) {
            this.detailSuivi = this.detailSuivi || this.resumerErreur(e);
            console.warn('Ecoute indisponible, la relecture continue :', e);
        }
    }

    /** Promesse bornée dans le temps : subscribe() peut ne jamais se résoudre. */
    avecDelai(promesse) {
        return Promise.race([
            promesse,
            new Promise((resoudre, rejeter) => {
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                setTimeout(() => rejeter(new Error('sans reponse')), ABONNEMENT_DELAI_MS);
            })
        ]);
    }

    /** Message court et lisible, quelle que soit la forme de l'erreur. */
    resumerErreur(erreur) {
        if (!erreur) return null;
        if (typeof erreur === 'string') return erreur;
        return erreur.message || erreur.error || erreur.failureReason
            || JSON.stringify(erreur).slice(0, 160);
    }

    arreterSuivi() {
        if (this.abonnement) {
            // Sans désabonnement, le flux continue d'arriver sur une fiche
            // fermée et rafraîchit un écran que personne ne regarde.
            try {
                unsubscribe(this.abonnement, () => {});
            } catch (e) {
                console.warn('Desabonnement impossible :', e);
            }
            this.abonnement = null;
        }
        this.arreterMinuteur();
        this.modeSuivi = null;
        this.detailSuivi = null;
    }

    arreterMinuteur() {
        if (this.minuteurSuivi) {
            clearInterval(this.minuteurSuivi);
            this.minuteurSuivi = null;
        }
        this._suiviRestant = 0;
    }

    /** Sonnette reçue : est-ce MON dossier ? Sinon, rien à faire. */
    surMaj(message) {
        const donnees = message && message.data && message.data.payload;
        if (!donnees || !this.estPrevisite) return;
        const vise = String(donnees.Dossier_Id__c || '').substring(0, 15);
        if (!this.dossierId || vise !== String(this.dossierId).substring(0, 15)) return;
        this.relireLeDossier();
    }

    /**
     * Relit LE SEUL dossier ouvert, et ne remplace que celui-là dans les
     * listes. Recharger les deux listes entières à chaque battement, pour une
     * ligne qui change, coûterait cher pour rien.
     *
     * Le compteur ne bouge que si le statut a VRAIMENT changé : c'est ce qui
     * rend le bandeau de contrôle lisible.
     */
    async relireLeDossier() {
        const dossierId = this.dossierId;
        const avant = this.dossierCourant && this.dossierCourant.certikoStatutVt;
        try {
            const dossier = await getDossier({ campaignToken: this.token, dossierId });
            if (this.dossierId !== dossierId || !this.estPrevisite || !dossier) return;
            this.remplacerDossier(dossier);
            if (dossier.certikoStatutVt !== avant) {
                this.suiviMajs += 1;
            }
        } catch (e) {
            console.warn('Relecture du dossier impossible :', e);
        }
    }

    /**
     * Remplace un dossier dans les listes, sans toucher au reste.
     *
     * RIEN N'EST REMPLACE SI RIEN N'A CHANGE. La relecture rend le plus souvent
     * exactement ce qui est deja a l'ecran : reconstruire les listes ferait
     * alors un rendu pour rien, et ce rendu efface la selection de texte en
     * cours. On ne pouvait plus copier un identifiant sans que la relecture
     * suivante ne vienne tout deselectionner.
     */
    remplacerDossier(dossier) {
        const actuel = this.dossierPar(dossier.id);
        if (actuel && JSON.stringify(actuel) === JSON.stringify(dossier)) {
            return;
        }
        const remplacer = (liste) => liste.map((d) => (d.id === dossier.id ? dossier : d));
        this.dossiers = {
            aPlanifier: remplacer(this.dossiers.aPlanifier),
            planifies: remplacer(this.dossiers.planifies)
        };
    }

    demarrerRepli() {
        this.modeSuivi = 'local';
        this._suiviRestant = REPLI_SECONDES;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.minuteurSuivi = setInterval(() => this.battementRepli(), 1000);
    }

    battementRepli() {
        this._suiviRestant -= 1;
        this.majBandeauSondage();
        if (this._suiviRestant > 0) return;
        this._suiviRestant = REPLI_SECONDES;
        if (!this.estPrevisite) return;
        this.relireLeDossier();
    }

    /* --- Bandeau de contrôle, visible en mode test seulement --- */

    get afficherControleSondage() {
        return this.modeTest;
    }

    /**
     * Ecrit le bandeau de test DIRECTEMENT dans le DOM.
     *
     * Le compte a rebours change chaque seconde. Passe par une liaison de
     * template, il declenchait un rendu par seconde, et chaque rendu effacait
     * la selection de texte : impossible de copier un identifiant avec
     * ?c__test=true. Ecrire le texte a la main sort ce compteur du cycle de
     * rendu — le bandeau reste juste, et la page ne bouge plus.
     */
    majBandeauSondage() {
        const el = this.template.querySelector('.sondage-etat');
        if (el) {
            el.textContent = this.texteSondage;
        }
    }

    /**
     * LWC ne remplit JAMAIS un nœud lwc:dom="manual" : sans ceci le bandeau
     * reste une barre vide. Appelé après chaque rendu — donc au premier
     * affichage, et à chaque fois que l'état du suivi change. Entre deux
     * rendus, c'est battementRepli() qui fait avancer le compte à rebours.
     */
    renderedCallback() {
        this.majBandeauSondage();
    }

    get texteSondage() {
        let etat = this.txt.sondageArrete;
        if (this.modeSuivi === 'ecoute') {
            etat = this.txt.suiviEcoute;
        } else if (this.modeSuivi === 'local') {
            etat = (this.txt.suiviLocal || '').replace('{n}', this._suiviRestant);
        }
        const majs = (this.txt.sondageReleves || '').replace('{n}', this.suiviMajs);
        return `${this.txt.sondageTitre} : ${etat} · ${majs}`;
    }

    /** Pourquoi l'écoute a échoué. Mode test seulement : c'est un diagnostic. */
    get afficherDetailSuivi() {
        return this.modeTest && !!this.detailSuivi && this.modeSuivi !== 'ecoute';
    }

    get texteDetailSuivi() {
        return (this.txt.suiviRefus || '')
            .replace('{raison}', this.detailSuivi)
            .replace('{n}', REPLI_SECONDES);
    }

    /**
     * « sondage-etat » n'habille rien : c'est la PRISE de majBandeauSondage().
     * Viser « .sondage » tout court attraperait aussi les bandeaux de refus
     * juste en dessous, qui partagent cette classe.
     */
    get classeControleSondage() {
        return this.modeSuivi
            ? 'sondage sondage-etat sondage-actif'
            : 'sondage sondage-etat';
    }

    /** Statut ouvert chez Certiko mais absent de notre liste de sélection. */
    get texteStatutRefuse() {
        return (this.txt.sondageStatutRefuse || '').replace('{v}', this.statutRefuse);
    }

    /** Bouton de la bulle : fixer / replanifier le dossier du repère. */
    handleActionCarte(event) {
        this.ouvrirFixer(event.detail.id);
    }

    /** Retour depuis l'écran « fixer » vers la liste d'origine. */
    handleRetourListe() {
        this.aller(this.dossierCourant?.planifie ? VUE_PLANIFIEES : VUE_A_PLANIFIER);
    }

    /* ══════════════════════ Mode verrouillé ══════════════════════ */

    get classeTuile() {
        return this.contratEnAttente ? 'tuile tuile-bloquee' : 'tuile';
    }

    get messageAttente() {
        return (this.txt.attenteMessage || '').replace('{email}', this.email || '');
    }

    /**
     * Contrat chargé EN AMONT : un <a target="_blank"> vers un blob: est une
     * navigation native, qu'une fenêtre ouverte par script ne serait pas (CSP).
     */
    async chargerContrat() {
        try {
            const base64 = await getContratStockeBase64({ campaignToken: this.token });
            this.libererBlob();
            this.urlPdf = URL.createObjectURL(
                new Blob([base64VersOctets(base64)], { type: 'application/pdf' })
            );
        } catch (e) {
            console.error('Contrat illisible :', e);
            this.libererBlob();
        }
    }

    /** Un blob: non révoqué retient tout le PDF en mémoire jusqu'à la fermeture. */
    libererBlob() {
        if (this.urlPdf && this.urlPdf.indexOf('blob:') === 0) {
            URL.revokeObjectURL(this.urlPdf);
        }
        this.urlPdf = null;
    }

    /** Informations envoyées. Un échec masque le recap, sans bloquer. */
    async chargerRecap() {
        try {
            this.etatContrat = await getContrat({ campaignToken: this.token });
        } catch (e) {
            console.error('Recap du contrat illisible :', e);
            this.etatContrat = null;
        }
    }

    /** Mêmes libellés et valeurs que la relecture avant envoi. */
    get recap() {
        if (!this.etatContrat) return [];
        return lignesRecap(this.etatContrat.role, this.etatContrat.donnees,
            etiquettes('contrat', this.langue), this.etatContrat.pays);
    }

    get aUnRecap() {
        return this.recap.length > 0;
    }

    /** Renvoie au formulaire de contrat pour corriger une saisie. */
    handleModifierInfos() {
        this.dispatchEvent(new CustomEvent('modifierinfos'));
    }

    /* ══════════════════════ Chargement des visites ══════════════════════ */

    async chargerDossiers() {
        this.chargementDossiers = true;
        try {
            const res = await getDossiers({ campaignToken: this.token });
            this.dossiers = {
                aPlanifier: (res && res.aPlanifier) || [],
                planifies: (res && res.planifies) || []
            };
        } catch (e) {
            this.afficher(this.messageDe(e), 'error');
        } finally {
            this.chargementDossiers = false;
        }
    }

    /** Dossier de l'écran « fixer », relu dans les listes à jour. */
    get dossierCourant() {
        return this.dossierPar(this.dossierId);
    }

    dossierPar(id) {
        if (!id) return null;
        return [...this.dossiers.aPlanifier, ...this.dossiers.planifies]
            .find((d) => d.id === id) || null;
    }

    /* ══════════════════════ Accueil : compteurs ══════════════════════ */

    get afficherCompteurs() {
        return !this.contratEnAttente && !this.chargementDossiers;
    }

    get chargementAccueil() {
        return !this.contratEnAttente && this.chargementDossiers;
    }

    get compteurAPlanifier() {
        const n = this.dossiers.aPlanifier.length;
        if (!n) return this.txt.cptAucuneAPlanifier;
        const nrp = this.dossiers.aPlanifier.filter((d) => d.nrp > 0).length;
        return nrp
            ? `${this.t('cptAPlanifier', n)} · ${this.t('cptNrp', nrp)}`
            : this.t('cptAPlanifier', n);
    }

    get compteurPlanifiees() {
        const n = this.dossiers.planifies.length;
        if (!n) return this.txt.cptAucunePlanifiee;
        const jour = this.dossiers.planifies.filter((d) => this.estAujourdhui(d.datePassage)).length;
        return jour
            ? `${this.t('cptPlanifiees', n)} · ${this.t('cptAujourdhui', jour)}`
            : this.t('cptPlanifiees', n);
    }

    get classeCompteurAPlanifier() {
        return this.dossiers.aPlanifier.length ? 'compteur compteur-warn' : 'compteur';
    }

    get classeCompteurPlanifiees() {
        return this.dossiers.planifies.length ? 'compteur compteur-info' : 'compteur';
    }

    /* ══════════════════════════════════════════════════════════════════════
       LISTE « À PLANIFIER » — filtres, tri, pagination
       ══════════════════════════════════════════════════════════════════════ */

    /** Filtre « Tentatives d'appels » : chaque nombre, plus « à rendre ». */
    get optionsAppels() {
        const options = [{ cle: '', libelle: this.txt.filtreAppelsTous }];
        for (let n = 0; n <= NRP_MAX; n++) {
            let libelle = this.t('filtreAppelsN', n);
            if (n === 0) libelle = this.txt.filtreAppelsAucune;
            if (n === 1) libelle = this.txt.filtreAppelsUne;
            // Au dernier palier, la visite peut etre rendue : on le dit ici.
            if (n === NRP_MAX) libelle = this.t('filtreAppelsARendre', n);
            options.push({ cle: String(n), libelle });
        }
        return options.map((o) => ({ ...o, choisi: o.cle === this.filtres.appels ? true : null }));
    }

    /** Provinces réellement présentes dans la liste, par ordre alphabétique. */
    get optionsProvince() {
        const vues = new Set();
        this.dossiers.aPlanifier.forEach((d) => {
            if (d.province) vues.add(d.province);
        });
        const options = [{ cle: '', libelle: this.txt.filtreProvinceToutes }];
        [...vues].sort((a, b) => a.localeCompare(b, this.locale))
            .forEach((p) => options.push({ cle: p, libelle: p }));
        return options.map((o) => ({ ...o, choisi: o.cle === this.filtres.province ? true : null }));
    }

    get optionsAnciennete() {
        return [
            { cle: '',       libelle: this.txt.filtreAgeToutes },
            { cle: '7',      libelle: this.txt.filtreAge7 },
            { cle: '14',     libelle: this.txt.filtreAge14 },
            { cle: 'ancien', libelle: this.txt.filtreAgeAncien }
        ].map((o) => ({ ...o, choisi: o.cle === this.filtres.age ? true : null }));
    }

    get optionsTaille() {
        return TAILLES_PAGE.map((n) => ({
            cle: String(n),
            libelle: String(n),
            choisi: n === this.parPage ? true : null
        }));
    }

    get optionsTaillePlanifiees() {
        return TAILLES_PAGE.map((n) => ({
            cle: String(n),
            libelle: String(n),
            choisi: n === this.parPagePlanifiees ? true : null
        }));
    }

    /** Colonnes du tableau ; celles qui portent une clé sont triables. */
    get colonnesAPlanifier() {
        return [
            { cle: 'cree',      libelle: this.txt.colCree },
            { cle: 'nrp',       libelle: this.txt.colAppels },
            { cle: 'tentative', libelle: this.txt.colTentative },
            { cle: 'nom',       libelle: this.txt.colClient },
            { cle: '',          libelle: this.txt.colTelephone },
            { cle: 'province',  libelle: this.txt.colProvince }
        ].map((c) => {
            const actif = c.cle && c.cle === this.tri.col;
            return {
                ...c,
                classe: c.cle ? 'lv-triable' : '',
                fleche: actif ? (this.tri.sens === 'asc' ? '▲' : '▼') : ''
            };
        });
    }

    /** Dossiers retenus par la barre de filtres. */
    get aPlanifierFiltres() {
        const f = this.filtres;
        const q = (f.q || '').toLowerCase().trim();
        const aujourdhui = this.debutDuJour().getTime();
        return this.dossiers.aPlanifier.filter((d) => {
            const n = d.nrp || 0;
            if (f.appels !== '' && n !== Number(f.appels)) return false;
            if (f.province && d.province !== f.province) return false;
            if (f.age && d.dateCreation) {
                const jours = Math.floor((aujourdhui - new Date(d.dateCreation).getTime()) / 864e5);
                if (f.age === '7' && jours >= 7) return false;
                if (f.age === '14' && jours >= 14) return false;
                if (f.age === 'ancien' && jours <= 14) return false;
            }
            if (q) {
                const texte = `${d.nom || ''} ${d.adresse || ''} ${d.province || ''} ${d.telephone || ''}`;
                if (texte.toLowerCase().indexOf(q) < 0) return false;
            }
            return true;
        });
    }

    get aPlanifierTriees() {
        const col = this.tri.col;
        const sens = this.tri.sens === 'desc' ? -1 : 1;
        return [...this.aPlanifierFiltres].sort((a, b) => {
            const x = this.cleTri(a, col);
            const y = this.cleTri(b, col);
            if (x < y) return -1 * sens;
            if (x > y) return 1 * sens;
            return 0;
        });
    }

    cleTri(d, col) {
        switch (col) {
            case 'nrp':       return d.nrp || 0;
            // Sans date, la ligne part en bas quel que soit le sens choisi.
            case 'tentative': return d.derniereTentative || 0;
            case 'province':  return (d.province || '').toLowerCase();
            case 'nom':       return (d.nom || '').toLowerCase();
            default:          return d.dateCreation || 0;
        }
    }

    get pagesAPlanifier() {
        return Math.max(1, Math.ceil(this.aPlanifierTriees.length / this.parPage));
    }

    /** Page demandée, ramenée dans les bornes après un changement de filtre. */
    get pageAPlanifier() {
        return Math.min(Math.max(1, this.page), this.pagesAPlanifier);
    }

    get lignesAPlanifier() {
        const debut = (this.pageAPlanifier - 1) * this.parPage;
        return this.aPlanifierTriees
            .slice(debut, debut + this.parPage)
            .map((d) => this.ligneListe(d));
    }

    ligneListe(d) {
        const n = d.nrp || 0;
        let classeNrp = 'nrp-badge nrp-badge-zero';
        if (n >= NRP_MAX) classeNrp = 'nrp-badge nrp-badge-plein';
        else if (n > 0) classeNrp = 'nrp-badge';
        return {
            id: d.id,
            nom: d.nom,
            telephone: d.telephone,
            lienTel: d.telephone ? 'tel:' + d.telephone : null,
            province: d.province || '—',
            creeLe: d.dateCreation ? this.formatJourCourt(d.dateCreation) : '—',
            nrpTexte: n ? this.t('pillNrp', n) : '—',
            classeNrp,
            peutAppeler: n < NRP_MAX,
            prochainNrp: n + 1,
            tentativeTexte: this.formatTentative(d.derniereTentative)
        };
    }

    get aPlanifierAucunResultat() {
        return !this.chargementDossiers && this.aPlanifierFiltres.length === 0;
    }

    /** « Aucune visite » ou « aucune visite ne correspond aux filtres ». */
    get aPlanifierMessageVide() {
        return this.dossiers.aPlanifier.length ? this.txt.lvAucunFiltre : this.txt.listeVide;
    }

    get plageAPlanifier() {
        return this.plage(this.aPlanifierTriees.length, this.pageAPlanifier,
            this.parPage, this.lignesAPlanifier.length);
    }

    get pagination() {
        return (this.txt.lvPage || '')
            .replace('{n}', this.pageAPlanifier)
            .replace('{total}', this.pagesAPlanifier);
    }

    get premierePage()  { return this.pageAPlanifier <= 1; }
    get dernierePage()  { return this.pageAPlanifier >= this.pagesAPlanifier; }

    handleRecherche(event) {
        this.filtres = { ...this.filtres, q: event.target.value };
        this.page = 1;
    }

    handleFiltreAppels(event) {
        this.filtres = { ...this.filtres, appels: event.target.value };
        this.page = 1;
    }

    handleFiltreProvince(event) {
        this.filtres = { ...this.filtres, province: event.target.value };
        this.page = 1;
    }

    handleFiltreAge(event) {
        this.filtres = { ...this.filtres, age: event.target.value };
        this.page = 1;
    }

    handleReinitialiser() {
        this.filtres = { q: '', appels: '', province: '', age: '' };
        this.page = 1;
        // Les champs sont non contrôlés (pas de value= lié) : il faut les vider.
        this.template.querySelectorAll('.lv-barre input, .lv-barre select')
            .forEach((champ) => { champ.value = ''; });
    }

    handleTri(event) {
        const col = event.currentTarget.dataset.col;
        if (!col) return;
        // Même colonne : on inverse le sens. Nouvelle colonne : croissant.
        const memeColonne = this.tri.col === col;
        this.tri = { col, sens: memeColonne && this.tri.sens === 'asc' ? 'desc' : 'asc' };
        this.page = 1;
    }

    handleTaille(event) {
        this.parPage = Number(event.target.value);
        this.page = 1;
    }

    handlePagePrecedente() {
        this.page = Math.max(1, this.pageAPlanifier - 1);
    }

    handlePageSuivante() {
        this.page = Math.min(this.pagesAPlanifier, this.pageAPlanifier + 1);
    }

    /** Colonne « Tentatives d'appels » : enregistre l'appel sans réponse suivant. */
    async handleNrpRapide(event) {
        const dossierId = event.currentTarget.dataset.id;
        const niveau = Number(event.currentTarget.dataset.n);
        await this.executer(async () => {
            await enregistrerNrp({ campaignToken: this.token, dossierId, niveau });
            await this.chargerDossiers();
        });
    }

    handleFixer(event) {
        this.ouvrirFixer(event.currentTarget.dataset.id);
    }

    /* ══════════════════════════════════════════════════════════════════════
       LISTE « PLANIFIÉES »
       ══════════════════════════════════════════════════════════════════════ */

    /**
     * Les visites planifiees encore a suivre.
     *
     * UNE VISITE TERMINEE DONT LA DATE EST PASSEE N'Y EST PLUS : elle a quitte
     * le terrain et part en facturation. La laisser aurait encombre la liste
     * de dossiers sur lesquels le pre-visiteur n'a plus aucun geste a faire.
     * Le filtre est ici et non cote serveur : la fiche reste atteignable par
     * son lien, et rendre ces dossiers de nouveau visibles ne demandera pas de
     * deploiement Apex.
     */
    get planifiesSuivis() {
        return this.dossiers.planifies.filter(
            (d) => this.etatVisite(d) !== 'terminee-passee'
        );
    }

    get planifiesFiltres() {
        const q = (this.qPlanifiees || '').toLowerCase().trim();
        if (!q) return this.planifiesSuivis;
        return this.planifiesSuivis.filter(
            (d) => `${d.nom || ''} ${d.adresse || ''}`.toLowerCase().indexOf(q) >= 0
        );
    }

    get lignesDuJour() {
        return this.planifiesFiltres
            .filter((d) => this.estAujourdhui(d.datePassage))
            .map((d) => this.lignePlanifiee(d));
    }

    /**
     * Tout le reste : rendez-vous passés non clôturés ET visites à venir, de la
     * plus ancienne à la plus récente (le serveur trie déjà par date).
     */
    get resteTrie() {
        return this.planifiesFiltres.filter((d) => !this.estAujourdhui(d.datePassage));
    }

    get lignesReste() {
        const debut = (this.pagePlanifieesCourante - 1) * this.parPagePlanifiees;
        return this.resteTrie
            .slice(debut, debut + this.parPagePlanifiees)
            .map((d) => this.lignePlanifiee(d));
    }

    /**
     * OU EN EST CETTE VISITE — un seul mot qui commande tout le reste de la
     * ligne : le libelle du bouton, s'il s'affiche, et si « Replanifier »
     * demande confirmation.
     *
     * L'ordre des tests n'est pas negociable : une visite terminee dont la
     * date est passee sort de la liste AVANT qu'on se demande si elle est a
     * finaliser.
     *
     * Valeurs : terminee-passee | passe-non-demarre | a-finaliser |
     *           terminee | en-cours | a-demarrer | a-venir
     */
    etatVisite(d) {
        const finie = d.certikoStatutVt === VT_TERMINEE;
        const aujourdhui = this.estAujourdhui(d.datePassage);
        const passee = !aujourdhui && new Date(d.datePassage) < this.debutDuJour();

        if (finie && passee) return 'terminee-passee';
        if (passee) return d.certikoEnvoye ? 'a-finaliser' : 'passe-non-demarre';
        if (aujourdhui) {
            if (finie) return 'terminee';
            return d.certikoEnvoye ? 'en-cours' : 'a-demarrer';
        }
        return 'a-venir';
    }

    /**
     * Tout ce que l'etat decide, en un endroit.
     *
     * `confirmerReplanif` : replanifier une visite deja envoyee detruit le
     * releve commence chez Certiko. On previent AVANT d'ouvrir l'ecran, et la
     * destruction n'a lieu qu'a la confirmation de la nouvelle date.
     */
    reglesEtat(etat) {
        switch (etat) {
            case 'a-demarrer':
                return { bouton: this.txt.boutonDemarrer, replanif: true };
            case 'en-cours':
                return { bouton: this.txt.boutonEnCours, replanif: true,
                         confirmerReplanif: true };
            case 'a-finaliser':
                return { bouton: this.txt.boutonAFinaliser, replanif: true,
                         confirmerReplanif: true };
            case 'terminee':
                // Cliquable comme les autres : la fiche garde l'historique et
                // le lien vers le releve. Mais plus rien a replanifier.
                return { bouton: this.txt.boutonTerminee, replanif: false };
            // Rien a demarrer tant que le jour n'est pas venu, et rien a
            // demarrer non plus sur une date deja passee : dans les deux cas
            // le seul geste utile est de reposer une date.
            case 'a-venir':
            case 'passe-non-demarre':
            default:
                return { bouton: null, replanif: true };
        }
    }

    lignePlanifiee(d) {
        const date = new Date(d.datePassage);
        let pill = this.txt.pillAVenir;
        let classePill = 'pill pill-gris';
        if (this.estAujourdhui(d.datePassage)) {
            pill = this.txt.aujourdhui;
            classePill = 'pill pill-ok';
        } else if (date < this.debutDuJour()) {
            pill = this.txt.pillAttenteRapport;
            classePill = 'pill pill-new';
        }
        const etat = this.etatVisite(d);
        const regles = this.reglesEtat(etat);
        return {
            id: d.id,
            nom: d.nom,
            adresse: d.adresse,
            pill,
            classePill,
            quand: this.quandPlanifie(d),
            etat,
            libelleBouton: regles.bouton,
            afficherBouton: !!regles.bouton,
            afficherReplanif: regles.replanif,
            classeBouton: 'btn btn-sm btn-etat btn-etat-' + etat
        };
    }

    /** « 18/09 · 10:30 », ou « Aujourd'hui · 10:30 ». */
    quandPlanifie(d) {
        const date = new Date(d.datePassage);
        const jour = this.estAujourdhui(d.datePassage)
            ? this.txt.aujourdhui
            : this.formatJourCourt(d.datePassage);
        return `${jour} · ${this.formatHeure(date)}`;
    }

    get nbDuJour()  { return this.lignesDuJour.length; }
    get nbReste()   { return this.resteTrie.length; }
    get aDuJour()   { return this.lignesDuJour.length > 0; }
    get aDuReste()  { return this.resteTrie.length > 0; }

    get planifieesVide() {
        return !this.chargementDossiers && this.dossiers.planifies.length === 0;
    }

    get libelleAujourdhui() {
        return new Date().toLocaleDateString(this.locale, { weekday: 'long', day: 'numeric', month: 'long' });
    }

    get pagesPlanifiees() {
        return Math.max(1, Math.ceil(this.resteTrie.length / this.parPagePlanifiees));
    }

    get pagePlanifieesCourante() {
        return Math.min(Math.max(1, this.pagePlanifiees), this.pagesPlanifiees);
    }

    get plagePlanifiees() {
        return this.plage(this.resteTrie.length, this.pagePlanifieesCourante,
            this.parPagePlanifiees, this.lignesReste.length);
    }

    get paginationPlanifiees() {
        return (this.txt.lvPage || '')
            .replace('{n}', this.pagePlanifieesCourante)
            .replace('{total}', this.pagesPlanifiees);
    }

    get premierePagePlanifiees() { return this.pagePlanifieesCourante <= 1; }
    get dernierePagePlanifiees() { return this.pagePlanifieesCourante >= this.pagesPlanifiees; }

    handleRecherchePlanifiees(event) {
        this.qPlanifiees = event.target.value;
        this.pagePlanifiees = 1;
    }

    handleTaillePlanifiees(event) {
        this.parPagePlanifiees = Number(event.target.value);
        this.pagePlanifiees = 1;
    }

    handlePagePrecedentePlanifiees() {
        this.pagePlanifiees = Math.max(1, this.pagePlanifieesCourante - 1);
    }

    handlePageSuivantePlanifiees() {
        this.pagePlanifiees = Math.min(this.pagesPlanifiees, this.pagePlanifieesCourante + 1);
    }

    /**
     * Replanifier, mais pas a l'aveugle.
     *
     * Sur une visite DEJA ENVOYEE chez Certiko, reposer une date detruit le
     * releve commence la-bas. On le dit AVANT d'ouvrir l'ecran — apres, le
     * pre-visiteur a une date sous les yeux et croit ne faire que la changer.
     * La destruction, elle, n'a lieu qu'a la confirmation de la nouvelle date.
     */
    handleReplanifier(event) {
        const id = event.currentTarget.dataset.id;
        const d = this.dossierPar(id);
        if (d && this.reglesEtat(this.etatVisite(d)).confirmerReplanif) {
            this.replanifIdEnAttente = id;
            return;
        }
        this.ouvrirFixer(id);
    }

    get replanifConfirmationOuverte() {
        return !!this.replanifIdEnAttente;
    }

    /** L'etat annonce dans l'avertissement : « En cours » ou « A finaliser ». */
    get libelleEtatAReplanifier() {
        const d = this.dossierPar(this.replanifIdEnAttente);
        return d ? this.reglesEtat(this.etatVisite(d)).bouton : '';
    }

    handleAnnulerReplanif() {
        this.replanifIdEnAttente = null;
    }

    handleConfirmerReplanif() {
        const id = this.replanifIdEnAttente;
        this.replanifIdEnAttente = null;
        // Le drapeau suit jusqu'a la confirmation de la date : c'est LUI qui
        // decide d'appeler la purge plutot que la simple replanification.
        this.replanifApresEnvoi = true;
        this.ouvrirFixer(id);
    }

    /* ══════════════════════ Écran « fixer / replanifier » ══════════════════════ */

    ouvrirFixer(id) {
        this.dossierId = id;
        const d = this.dossierCourant;
        if (d && d.planifie && d.datePassage) {
            const dt = new Date(d.datePassage);
            this.saisieDate = this.isoDateLocale(dt);
            this.saisieHeure = `${String(dt.getHours()).padStart(2, '0')}:${String(dt.getMinutes()).padStart(2, '0')}`;
        } else {
            this.saisieDate = '';
            this.saisieHeure = '';
        }
        this.aller(VUE_FIXER);
        this.chargerHistorique();
    }

    get estReplanification() {
        return !!(this.dossierCourant && this.dossierCourant.planifie);
    }

    get titreFixer() {
        return this.estReplanification ? this.txt.titreReplanifier : this.txt.titreFixer;
    }

    get libelleRetourFixer() {
        return this.estReplanification ? this.txt.retourPlanifiees : this.txt.retourAPlanifier;
    }

    /** Consignes d'appel, découpées en morceaux normaux / gras. */
    get consignes() {
        return (this.txt.prepConsignes || []).map((morceaux, i) => ({
            cle: 'c' + i,
            morceaux: morceaux.map(([texte, gras], j) => ({
                cle: `c${i}m${j}`,
                texte,
                classe: gras ? 'gras' : ''
            }))
        }));
    }

    get lienTelCourant() {
        return this.dossierCourant && this.dossierCourant.telephone
            ? 'tel:' + this.dossierCourant.telephone
            : null;
    }

    get rdvActuel() {
        const d = this.dossierCourant;
        return d && d.planifie && d.datePassage ? this.formatDateLongue(new Date(d.datePassage)) : null;
    }

    /**
     * Itinéraire Google Maps vers l'adresse du chantier. Aucune origine n'est
     * passée : Google part de la position de l'appareil, ce qui évite de
     * demander la géolocalisation au portail.
     */
    get lienItineraire() {
        const d = this.dossierCourant;
        if (!d || !d.adresse) return null;
        return 'https://www.google.com/maps/dir/?api=1&destination='
            + encodeURIComponent(d.adresse);
    }

    /* ══════════════════════ Accès Certiko ══════════════════════ */

    /**
     * Identifiants de connexion à Certiko. Un échec ne bloque rien : le bloc
     * disparaît, le reste du portail fonctionne.
     */
    async chargerAcces() {
        try {
            this.acces = await getAccesCertiko({ campaignToken: this.token });
        } catch (e) {
            console.error('Acces Certiko illisible :', e);
            this.acces = null;
        }
    }

    /** Le bloc n'apparaît que sur la fiche de prévisite, et une fois le compte ouvert. */
    get afficherAcces() {
        return this.estPrevisite && !!this.acces && this.acces.pret === true;
    }

    /** Compte pas encore ouvert : le dire, plutôt que des champs vides. */
    get afficherAccesEnAttente() {
        return this.estPrevisite && !!this.acces && this.acces.pret !== true;
    }

    /*
     * PLUS D'OEIL NI DE PLIAGE — le mot de passe s'affiche en clair, dans le
     * carré de la visite technique. Il était masqué derrière un bouton et un
     * bloc replié dont l'état vivait dans localStorage : trois gestes avant de
     * pouvoir lire ce qu'on doit retaper sur Certiko, l'instant d'après. Le
     * secret ouvre le seul relevé de visite, aucune donnée Salesforce.
     */

    /* ══════════════════════ Historique du dossier ══════════════════════ */

    /**
     * Historique du dossier ouvert. Un échec ne doit pas empêcher de prendre le
     * rendez-vous : la section disparaît, rien de plus.
     */
    async chargerHistorique() {
        this.historique = [];
        const id = this.dossierId;
        try {
            const res = await getHistorique({ campaignToken: this.token, dossierId: id });
            // L'utilisateur a pu changer de dossier pendant l'appel.
            if (this.dossierId === id) {
                this.historique = res || [];
            }
        } catch (e) {
            console.error('Historique du dossier illisible :', e);
        }
    }

    get aUnHistorique() {
        return this.evenementsVisibles.length > 0;
    }

    get nbEvenements() {
        return this.t('histCompte', this.evenementsVisibles.length);
    }

    /**
     * Événements affichés. Sur un dossier DÉJÀ PLANIFIÉ, le rendez-vous est
     * pris : les appels sans réponse qui ont précédé n'apprennent plus rien, on
     * ne garde que l'attribution et la vie du rendez-vous.
     */
    get evenementsVisibles() {
        const planifie = !!(this.dossierCourant && this.dossierCourant.planifie);
        return planifie
            ? this.historique.filter((e) => HISTORIQUE_PLANIFIE.indexOf(e.type) >= 0)
            : this.historique;
    }

    get evenements() {
        return this.evenementsVisibles.map((e, i) => {
            const tag = TAGS_HISTORIQUE[e.type] || TAGS_HISTORIQUE.ajout;
            const auteur = e.auteur || (e.parLePrevisiteur ? this.nom : MARQUE);
            return {
                cle: 'e' + i,
                quand: this.formatJourHeure(e.quand),
                tag: tag.cle ? this.txt[tag.cle] : this.t('pillNrp', e.niveau),
                classeTag: tag.classe,
                morceaux: this.morceauxEvenement(e),
                auteur: (this.txt.histPar || '').replace('{auteur}', auteur)
            };
        });
    }

    /**
     * Phrase de l'événement découpée en morceaux : ce qui remplace un {repère}
     * du libellé (date, motif) ressort EN GRAS, le reste en texte courant.
     */
    morceauxEvenement(e) {
        switch (e.type) {
            case 'creation':
                return this.morceaux(this.txt.histCreation, {});
            case 'nrp':
                return this.morceaux(this.txt.histNrp, {});
            case 'rdv':
                return this.morceaux(this.txt.histRdv,
                    { date: this.formatJourHeure(e.dateNouvelle) });
            case 'replanif':
                return this.morceaux(this.txt.histReplanif, {
                    ancien: this.formatJourHeure(e.dateAncienne),
                    nouveau: this.formatJourHeure(e.dateNouvelle)
                });
            case 'rendu':
                return this.morceaux(this.txt.histRendu, { motif: e.valeur || '' });
            case 'retire':
                return this.morceaux(this.txt.histRetire, {});
            default:
                return this.morceaux(this.txt.histAjout, {});
        }
    }

    morceaux(modele, valeurs) {
        const sortie = [];
        const reperes = /\{(\w+)\}/g;
        let debut = 0;
        let trouve;
        let i = 0;
        while ((trouve = reperes.exec(modele || '')) !== null) {
            if (trouve.index > debut) {
                sortie.push({ cle: 'm' + i++, texte: modele.slice(debut, trouve.index), classe: '' });
            }
            sortie.push({ cle: 'm' + i++, texte: valeurs[trouve[1]] || '', classe: 'gras' });
            debut = trouve.index + trouve[0].length;
        }
        if (debut < (modele || '').length) {
            sortie.push({ cle: 'm' + i++, texte: modele.slice(debut), classe: '' });
        }
        return sortie;
    }

    /* ══════════════════════ Rendre la visite (fenêtre) ══════════════════════ */

    /** Dossier visé par la fenêtre : la liste comme la fiche y mènent. */
    get dossierRendu() {
        return this.dossierPar(this.rendreId);
    }

    handleOuvrirRendre(event) {
        this.rendreId = event.currentTarget.dataset.id;
        this.motifCle = '';
        this.motifLibre = '';
        this.rendreConfirmation = false;
        this.rendreOuvert = true;
    }

    handleFermerRendre() {
        this.rendreOuvert = false;
        this.rendreConfirmation = false;
        this.rendreId = null;
        this.motifCle = '';
        this.motifLibre = '';
    }

    get optionsMotif() {
        const nrpAtteint = ((this.dossierRendu && this.dossierRendu.nrp) || 0) >= NRP_MAX;
        // ⚠️ null et non false : sur un <option>, LWC écrit l'attribut tel quel
        // (disabled="false"), et un attribut booléen PRÉSENT vaut vrai pour le
        // navigateur — toutes les options étaient désactivées.
        return MOTIFS.map((m) => ({
            cle: m.cle,
            libelle: this.txt[m.libelle],
            desactive: m.nrp && !nrpAtteint ? true : null,
            selectionne: m.cle === this.motifCle ? true : null
        }));
    }

    get motifAutre() {
        return this.motifCle === 'autre';
    }

    /** Texte qui sera enregistré, ou '' tant que le choix est incomplet. */
    get motifAEnregistrer() {
        const m = MOTIFS.find((x) => x.cle === this.motifCle);
        if (!m) return '';
        if (m.libre) {
            const libre = (this.motifLibre || '').trim();
            return libre.length >= 3 ? libre : '';
        }
        return this.txt[m.libelle] || '';
    }

    get rendreDesactive() {
        return !this.motifAEnregistrer || this.enCours;
    }

    get nomDossierRendu() {
        return this.dossierRendu ? this.dossierRendu.nom : '';
    }

    /** Nom de la fenêtre pour les lecteurs d'écran, selon l'étape affichée. */
    get titreFenetreRendre() {
        return this.rendreConfirmation ? this.txt.confirmRendreTitre : this.txt.rendreTitre;
    }

    handleMotif(event) {
        this.motifCle = event.target.value;
    }

    handleMotifLibre(event) {
        this.motifLibre = event.target.value;
    }

    /** Pas d'enregistrement direct : la fenêtre demande confirmation d'abord. */
    handleDemanderRendu() {
        if (!this.rendreDesactive) this.rendreConfirmation = true;
    }

    handleAnnulerRendu() {
        this.rendreConfirmation = false;
    }

    async handleConfirmerRendu() {
        const id = this.rendreId;
        const planifie = !!(this.dossierRendu && this.dossierRendu.planifie);
        // Rendu depuis la FICHE du dossier : elle n'a plus de raison d'être.
        const depuisLaFiche = this.dossierId === id && (this.estFixer || this.estPrevisite);
        this.rendreConfirmation = false;
        const ok = await this.executer(async () => {
            await rendreVisite({
                campaignToken: this.token,
                dossierId: id,
                motif: this.motifAEnregistrer,
                motifCle: this.motifCle
            });
            await this.chargerDossiers();
        });
        if (ok) {
            this.handleFermerRendre();
            if (depuisLaFiche) {
                this.dossierId = null;
                this.aller(planifie ? VUE_PLANIFIEES : VUE_A_PLANIFIER);
            }
            this.afficher(this.txt.rendueOk, 'success');
        }
    }

    /* --- Date du rendez-vous --- */

    get dateMin() {
        return this.isoDateLocale(new Date());
    }

    handleDate(event) {
        this.saisieDate = event.target.value;
    }

    handleHeure(event) {
        this.saisieHeure = event.target.value;
    }

    /**
     * Créneaux de la liste déroulante. Un rendez-vous déjà enregistré peut
     * tomber hors de la grille (16 h 33) : il est ajouté pour qu'une
     * replanification ne perde jamais l'heure en cours.
     */
    get optionsHeure() {
        const creneaux = [];
        for (let m = HEURE_PREMIERE * 60; m <= HEURE_DERNIERE * 60; m += PAS_MINUTES) {
            const h = Math.floor(m / 60);
            creneaux.push(`${String(h).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`);
        }
        if (this.saisieHeure && creneaux.indexOf(this.saisieHeure) < 0) {
            creneaux.push(this.saisieHeure);
            creneaux.sort();
        }
        return creneaux.map((v) => ({
            cle: v,
            libelle: v,
            choisi: v === this.saisieHeure ? true : null
        }));
    }

    get confirmerDesactive() {
        return !this.saisieDate || !this.saisieHeure || this.enCours;
    }

    async handleConfirmerRdv() {
        if (!this.saisieDate || !this.saisieHeure) {
            this.afficher(this.txt.dateManquante, 'error');
            return;
        }
        // Saisie en heure LOCALE du navigateur, envoyée en ISO (UTC) :
        // Salesforce stocke un Datetime absolu.
        const [a, m, j] = this.saisieDate.split('-').map(Number);
        const [h, mi] = this.saisieHeure.split(':').map(Number);
        const dt = new Date(a, m - 1, j, h, mi, 0, 0);
        let dossier;
        const purger = this.replanifApresEnvoi;
        const ok = await this.executer(async () => {
            // C'EST ICI que le dossier Certiko est detruit, et nulle part
            // avant : un pre-visiteur qui fait demi-tour sur l'ecran de
            // replanification retrouve sa visite intacte.
            const appel = purger ? replanifierApresEnvoi : planifier;
            dossier = await appel({
                campaignToken: this.token,
                dossierId: this.dossierId,
                dateHeureIso: dt.toISOString()
            });
            await this.chargerDossiers();
        });
        if (ok) {
            this.replanifApresEnvoi = false;
            this.rdvConfirme = dossier;
            this.aller(VUE_CONFIRME);
        }
    }

    /* ══════════════════════ Écran SMS ══════════════════════ */

    get texteSms() {
        const d = this.rdvConfirme;
        if (!d) return '';
        const dt = new Date(d.datePassage);
        let jour = dt.toLocaleDateString('es-ES', { weekday: 'long', day: 'numeric', month: 'long' })
            .replace(',', '');
        jour = jour.charAt(0).toUpperCase() + jour.slice(1);
        const heure = dt.toLocaleTimeString('es-ES', { hour: '2-digit', minute: '2-digit' });
        return MODELE_SMS
            .replace('{client}', d.nom || '')
            .replace('{previsiteur}', this.nom || '')
            .replace('{date}', jour)
            .replace('{heure}', heure)
            .replace('{adresse}', d.adresse || '');
    }

    get libelleCopier() {
        return this.smsCopie ? this.txt.copie : this.txt.boutonCopier;
    }

    handleRetourConfirme() {
        this.aller(VUE_FIXER);
    }

    /**
     * Copie un texte, et dit si elle a abouti.
     *
     * DEUX CHEMINS, et le second n'est pas du luxe : le presse-papiers moderne
     * exige un contexte sécurisé et une permission que certains navigateurs
     * mobiles refusent. Le repli passe par un textarea temporaire, posé dans la
     * zone lwc:dom="manual" — un nœud que LWC ne touche jamais, donc sûr à
     * manipuler à la main.
     */
    async copier(texte) {
        if (!texte) return false;
        try {
            if (navigator.clipboard && navigator.clipboard.writeText) {
                await navigator.clipboard.writeText(texte);
                return true;
            }
        } catch (e) {
            // Refusé : on tente le repli plutôt que d'abandonner.
        }
        const zone = this.template.querySelector('.zone-copie');
        if (!zone) return false;
        const ta = document.createElement('textarea');
        ta.value = texte;
        ta.setAttribute('readonly', '');
        zone.appendChild(ta);
        ta.select();
        let copie = false;
        try {
            copie = document.execCommand('copy');
        } catch (e) {
            copie = false;
        }
        zone.removeChild(ta);
        return copie;
    }

    /* --- Identifiants : un bouton par valeur --- */

    /**
     * Un bouton PAR identifiant, et pas un seul pour les deux : le
     * pré-visiteur colle l'un, puis l'autre, dans deux champs différents de
     * l'écran de connexion.
     */
    async handleCopierAcces(event) {
        const quoi = event.currentTarget.dataset.quoi;
        const texte = quoi === 'login' ? this.acces.login : this.acces.motDePasse;
        const copie = await this.copier(texte);
        if (!copie) return;
        this.copieFaite = quoi;
        clearTimeout(this._minuteurCopie);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._minuteurCopie = setTimeout(() => {
            this.copieFaite = null;
        }, DUREE_COPIE_MS);
    }

    get libelleCopieLogin() {
        return this.copieFaite === 'login' ? this.txt.accesCopie : this.txt.accesCopier;
    }

    get libelleCopieMotDePasse() {
        return this.copieFaite === 'motDePasse' ? this.txt.accesCopie : this.txt.accesCopier;
    }

    get classeCopieLogin() {
        return 'acces-copier' + (this.copieFaite === 'login' ? ' acces-copier-ok' : '');
    }

    get classeCopieMotDePasse() {
        return 'acces-copier' + (this.copieFaite === 'motDePasse' ? ' acces-copier-ok' : '');
    }

    async handleCopierSms() {
        const copie = await this.copier(this.texteSms);
        this.smsCopie = copie;
        // Laisse voir « Copié » un instant avant de revenir à l'accueil.
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            this.rdvConfirme = null;
            this.dossierId = null;
            this.aller(VUE_ACCUEIL);
        }, copie ? 900 : 0);
    }

    /* ══════════════════════ Outils ══════════════════════ */

    /** Exécute une action serveur ; renvoie vrai si elle a abouti. */
    async executer(action) {
        this.enCours = true;
        this.messageEcran = null;
        try {
            await action();
            return true;
        } catch (e) {
            this.afficher(this.messageDe(e), 'error');
            return false;
        } finally {
            this.enCours = false;
        }
    }

    afficher(message, type) {
        this.messageEcran = message;
        this.typeMessage = type || 'info';
    }

    get classeMessage() {
        return 'message message-' + this.typeMessage;
    }

    /** Code d'erreur Apex -> texte traduit ; « DML:… » -> message Salesforce. */
    messageDe(erreur) {
        const brut = (erreur && erreur.body && erreur.body.message) || (erreur && erreur.message) || '';
        if (brut.indexOf('DML:') === 0) return brut.slice(4);
        // Refus de Certiko : le détail (champ manquant...) aide à corriger.
        if (brut.indexOf('CERTIKO_REFUS:') === 0) {
            return `${this.txt.err_CERTIKO_REFUS} ${brut.slice('CERTIKO_REFUS:'.length)}`;
        }
        return this.txt['err_' + brut] || brut || this.txt.erreurGenerique;
    }

    /** « 1–26 sur 30 éléments ». */
    plage(total, page, taille, affichees) {
        if (!total) return this.txt.lvAucunElement;
        const debut = (page - 1) * taille + 1;
        return (this.txt.lvPlage || '')
            .replace('{de}', debut)
            .replace('{a}', debut + affichees - 1)
            .replace('{total}', total);
    }

    estAujourdhui(valeur) {
        if (!valeur) return false;
        const d = new Date(valeur);
        return d >= this.debutDuJour() && d <= this.finDuJour();
    }

    debutDuJour() {
        const d = new Date();
        d.setHours(0, 0, 0, 0);
        return d;
    }

    finDuJour() {
        const d = new Date();
        d.setHours(23, 59, 59, 999);
        return d;
    }

    isoDateLocale(d) {
        return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
    }

    formatHeure(d) {
        return d.toLocaleTimeString(this.locale, { hour: '2-digit', minute: '2-digit' });
    }

    /** « 18/09 ». */
    formatJourCourt(valeur) {
        return new Date(valeur).toLocaleDateString(this.locale, { day: '2-digit', month: '2-digit' });
    }

    /** « 18/09 · 09:40 ». */
    formatJourHeure(valeur) {
        if (!valeur) return '';
        const d = new Date(valeur);
        return `${this.formatJourCourt(d)} · ${this.formatHeure(d)}`;
    }

    formatDateLongue(d) {
        const jour = d.toLocaleDateString(this.locale, { weekday: 'long', day: 'numeric', month: 'long' });
        return `${jour} · ${this.formatHeure(d)}`;
    }

    /** Colonne « Dernière tentative » : « aujourd'hui 18:40 », « 17/09 · 18:40 ». */
    formatTentative(valeur) {
        if (!valeur) return '—';
        const d = new Date(valeur);
        const heure = this.formatHeure(d);
        if (this.estAujourdhui(valeur)) return `${this.txt.aujourdhui} ${heure}`;
        const hier = new Date(this.debutDuJour().getTime() - 864e5);
        if (d >= hier && d < this.debutDuJour()) return `${this.txt.hier} ${heure}`;
        return `${this.formatJourCourt(d)} · ${heure}`;
    }
}