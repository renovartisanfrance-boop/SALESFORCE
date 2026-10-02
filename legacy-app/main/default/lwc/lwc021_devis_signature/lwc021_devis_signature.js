import { LightningElement, api } from 'lwc';
import { FR, etiquettes } from 'c/lwc000_i18n';
import { loadScript } from 'lightning/platformResourceLoader';
// Gabarit de REPLI. Celui de la fiche prime — voir gabaritUrl. L'import reste
// statique parce que `@salesforce/resourceUrl/<nom>` est resolu a la
// compilation : les gabarits par fiche sont importes dans c/lwc000_utils.
import CAE_COLAB_CONTRAT from '@salesforce/resourceUrl/cae_colab_contrat';
import PDF_LIB from '@salesforce/resourceUrl/pdfLib';
import PDF_JS from '@salesforce/resourceUrl/pdfJs';
import PDF_JS_WORKER from '@salesforce/resourceUrl/pdfJsWorker';

import getDevis from '@salesforce/apex/LC021_DevisSignature.getDevis';
import enregistrerDevis from '@salesforce/apex/LC021_DevisSignature.enregistrerDevis';
import getContratBase64 from '@salesforce/apex/LC021_DevisSignature.getContratBase64';
import getContratStockeBase64 from '@salesforce/apex/LC021_DevisSignature.getContratStockeBase64';
import enregistrerContrat from '@salesforce/apex/LC021_DevisSignature.enregistrerContrat';
import reserverNumeroDevis from '@salesforce/apex/LC021_DevisSignature.reserverNumeroDevis';
import envoyerPourSignature from '@salesforce/apex/LC021_DevisSignature.envoyerPourSignature';

import {
    reglagesSignature,
    cleDevisSelonConditions,
    champsRecapFiche,
    devisSousConditions
} from 'c/lwc000_utils';

import {
    STATUT_GENERATION,
    STATUT_ATTENTE_SIGNATURE,
    STATUT_SIGNE,
    champsRecap,
    champsDemandes,
    CHAMPS_CLIENT_PDF,
    CHAMPS_SIGNATAIRE,
    CHAMP_FICHE,
    CHAMP_SURFACE,
    puissancePourSurface,
    appliquerPuissanceSurPdf,
    evaluerCalculs,
    valeurDuTexte,
    base64VersOctets,
    PUISSANCES
} from './devisConfig';

/**
 * Clé localStorage du token de campagne — IDENTIQUE à lwc020_reporting_v2 et à
 * lwc020_FacturationUtils. Ne pas la changer sans changer les autres : c'est le
 * même token qui circule dans tout le portail « Campagnes ».
 */
const TOKEN_STORAGE_KEY = 'renov_campaign_token';

/**
 * Aperçu du document rendu sur canvas par pdf.js, dans l'onglet 2.
 *
 * DÉSACTIVÉ. Dans ce site, Lightning Web Security interdit à pdf.js son worker :
 * la bibliothèque détecte `window.pdfjsWorker` et peint TOUT sur le thread
 * principal. Tant que le contrat faisait 2 ou 3 pages c'était supportable ; à 5,
 * Edge propose de fermer l'onglet et la modale reste bloquée sur « Affichage du
 * document ». Le découpage en rendu paresseux n'a pas suffi.
 *
 * En attendant une vraie correction, le document s'ouvre dans un onglet : c'est
 * le lecteur PDF natif du navigateur qui l'affiche, sans rien coûter à la page.
 * Le fichier est le MÊME — coché, rempli et joint au dossier : seule la manière
 * de le regarder change.
 *
 * Repasser à `true` réactive l'aperçu ; rendrePdf() et ses méthodes sont
 * conservées intactes pour cela.
 */
const APERCU_CANVAS_ACTIF = false;

/*
 * DEUX etapes, plus trois. L'onglet « Document » n'affichait plus qu'un lien
 * « Ouvrir le devis » depuis que l'apercu canvas a ete coupe : une etape entiere
 * pour un bouton. Sa raison d'etre — fabriquer le document — a rejoint l'etape
 * Signature, qui montre la generation en cours puis le reste une fois pret.
 */
const ONGLET_RECAP     = 'recap';
const ONGLET_SIGNATURE = 'signature';

/** DisplayType Salesforce -> attribut `type` du <input> natif du récapitulatif. */
const TYPES_INPUT = {
    EMAIL: 'email',
    PHONE: 'tel',
    URL: 'url',
    DATE: 'date',
    DATETIME: 'datetime',
    DOUBLE: 'number',
    CURRENCY: 'number',
    PERCENT: 'number',
    INTEGER: 'number',
    LONG: 'number'
};

/**
 * lwc021_devis_signature — modale de devis d'une Piste ou d'un Dossier.
 *
 * INDÉPENDANT du reporting : il ne reçoit qu'un `record-id`. Tout le reste —
 * identification Lead/Pro__c, statut, données, puissance, document — est de son
 * ressort et transite par un unique contrôleur, LC021_DevisSignature.
 *
 * AUTHENTIFICATION — le composant tourne dans le site Experience Cloud
 * « Campagnes » où l'utilisateur n'est pas forcément un utilisateur Salesforce
 * nominatif. Il réutilise TEL QUEL le token de campagne déjà en place : la
 * propriété `campaign-code` si le parent la passe (le reporting l'a déjà), sinon
 * le localStorage `renov_campaign_token`. Aucun second mécanisme d'authentification
 * n'est introduit ; c'est l'Apex qui valide le token et le périmètre du record.
 *
 * Le composant ne fait que DEUX appels serveur au maximum : un au chargement, un
 * par enregistrement (qui renvoie déjà le devis rechargé — pas de refresh en plus).
 */
export default class Lwc021_devis_signature extends LightningElement {

    /* ── API publique ──────────────────────────────────────────────────────── */

    /** SEULE donnée métier attendue du parent : l'Id du Lead ou du Pro__c. */
    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(valeur) {
        const change = valeur !== this._recordId;
        this._recordId = valeur;
        if (change && valeur && this._monte) {
            this.charger();
        }
    }
    _recordId;

    /**
     * Token de campagne. Optionnel : le composant sait le relire lui-même dans
     * le localStorage. Le parent le passe quand il l'a déjà sous la main, ce qui
     * évite une lecture de plus et couvre le cas où le stockage est indisponible
     * (navigation privée).
     */
    @api
    get campaignCode() {
        if (this._campaignCode) return this._campaignCode;
        try {
            return localStorage.getItem(TOKEN_STORAGE_KEY);
        } catch (e) {
            return null;
        }
    }
    set campaignCode(valeur) {
        this._campaignCode = valeur;
    }
    _campaignCode;

    /**
     * Vrai utilisateur Salesforce, ouvrant l'ecran depuis Lightning.
     *
     * ⚠️ IL N'A PAS DE TOKEN, et n'en aura jamais : le token vit dans le
     * localStorage du portail Campagnes, ou ces utilisateurs ne passent pas.
     * Leur droit vient de leur PROFIL et du rattachement nominatif de
     * l'enregistrement — c'est LC021_DevisSignature qui le verifie, comme
     * LC020_GestionReporting le fait deja pour le reporting.
     *
     * Le nom vient du reporting, qui porte la meme propriete : mieux vaut un
     * nom imparfait mais identique des deux cotes qu'un synonyme de plus.
     */
    @api isCommunityUser = false;

    /**
     * Faut-il un token pour travailler ?
     *
     * Oui pour le portail : sans token il n'y a pas de session, et le dire tot
     * evite un aller-retour serveur pour un message qu'on connait deja.
     * Non pour un utilisateur Salesforce : exiger un token lui refusait l'acces
     * a un ecran auquel il a droit.
     *
     * Dans les deux cas l'Apex re-verifie : cette garde est un confort
     * d'affichage, jamais une securite.
     */
    get tokenRequis() {
        return this.isCommunityUser !== true;
    }

    /**
     * Onglet a ouvrir en arrivant : 'recap', 'document' ou 'signature'.
     *
     * Sert au pictogramme stylo du reporting, qui amene directement a l'ecran
     * d'envoi pour relancer une signature. Ignore quand la barre d'onglets est
     * masquee (devis signe) : il n'y a alors qu'un seul ecran possible.
     *
     * ⚠️ NE PAS renommer en « ongletInitial » : LWC reserve tout nom commencant
     * par « on » aux gestionnaires d'evenements et refuse la compilation.
     */
    @api etapeInitiale;

    /** Langue d'affichage, poussée par le conteneur du portail. */
    @api
    get langue() {
        return this._langue;
    }
    set langue(valeur) {
        this._langue = valeur || FR;
    }
    _langue = FR;

    get txt() {
        return etiquettes('devis', this._langue);
    }

    /* ── État interne ──────────────────────────────────────────────────────── */

    devis = null;
    isLoading = false;
    isSaving = false;
    error = null;
    message = null;
    ongletActif = ONGLET_RECAP;

    /** Un envoi à la signature est en vol : le bouton reste inerte jusqu'au retour. */
    envoiEnCours = false;

    /**
     * Email saisi dans l'onglet Signature. `null` — et non chaîne vide — signifie
     * « rien de saisi », donc « prendre celui du dossier » : sans cette
     * distinction, effacer volontairement le champ ferait aussitôt réapparaître
     * l'adresse d'origine.
     */
    _emailSaisi = null;

    /**
     * Sur une demande deja envoyee, l'ecran propose d'abord un CHOIX. Ce drapeau
     * dit qu'on est passe de ce choix a la correction de l'adresse.
     */
    editionEmail = false;

    /**
     * URL du document affiché. Vaut d'abord le Static Resource brut, puis le
     * blob: du PDF COCHÉ dès que pdf-lib a tourné. Le lien « ouvrir dans un
     * nouvel onglet » pointe sur la même URL : ce que l'utilisateur consulte,
     * télécharge et signera est un seul et même fichier.
     */
    urlPdf = CAE_COLAB_CONTRAT;
    /** true quand le PDF affiché porte réellement la coche. */
    pdfCoche = false;
    /** true quand le PDF coché est joint au record (fichier Salesforce). */
    fichierJoint = false;
    /** Le rendu du PDF coché est en cours. */
    pdfEnCours = false;
    /** Renseigné si la génération a échoué : le document brut reste affiché. */
    pdfErreur = null;
    /** Étape en cours, affichée sous le spinner du document. */
    pdfEtape = null;

    /**
     * Valeurs saisies non encore enregistrées, par nom d'API.
     * Séparées des données serveur : tant qu'on n'a pas enregistré, `devis` reste
     * la vérité du serveur et `_brouillon` la vérité de l'écran. C'est ce qui
     * permet « Annuler les modifications » sans aucun appel réseau.
     */
    _brouillon = {};
    /**
     * Champs que l'utilisateur a TOUCHES lui-meme, par nom d'API.
     *
     * Distingue une valeur choisie d'une valeur proposee : la recommandation
     * (voir appliquerRecommandations) ne s'applique qu'aux champs vides que
     * l'utilisateur n'a pas encore pris en main. Sans cette distinction, corriger
     * la surface apres avoir choisi 16 capteurs remettrait la proposition a la
     * place du choix.
     */
    _choisis = new Set();
    _monte = false;

    connectedCallback() {
        this._monte = true;
        if (this._recordId) this.charger();
    }

    /* ── Chargement ────────────────────────────────────────────────────────── */

    /**
     * @param {Object} [options] options d'appel.
     * @param {boolean} [options.conserverOnglet] true pour rester sur l'onglet courant.
     *        Après un envoi à la signature, le statut passe à
     *        « en attente » et ongletParDefaut ramènerait au récapitulatif :
     *        l'utilisateur perdrait de vue le message qu'il vient de déclencher.
     * @returns une promesse, pour que l'appelant puisse enchaîner.
     */
    charger(options) {
        const conserverOnglet = !!(options && options.conserverOnglet);
        const token = this.campaignCode;
        if (!token && this.tokenRequis) {
            this.error = this.txt.tokenManquant;
            return Promise.resolve();
        }
        this.isLoading = true;
        this.error = null;
        this.message = null;

        // Les champs demandés dépendent de l'objet, qu'on ne connaît pas encore :
        // on envoie l'union des deux configurations. L'Apex n'en retient que ceux
        // de sa liste blanche pour l'objet réellement identifié — les autres sont
        // simplement ignorés, jamais requêtés.
        const demandes = [
            ...new Set([...champsDemandes('Lead'), ...champsDemandes('Pro__c')])
        ];

        return getDevis({
            recordId: this._recordId,
            campaignCode: token,
            champs: demandes
        })
            .then((data) => {
                this.devis = data;
                this._brouillon = {};
                this._choisis = new Set();
                this.appliquerRecommandations();
                // Le verrou de l'adresse retombe : nouvelles donnees, nouvelle lecture.
                this.editionEmail = false;
                if (!conserverOnglet) {
                    // L'onglet demande ne vaut que si la barre est affichee.
                    const demande = this.afficheOnglets ? this.etapeInitiale : null;
                    this.ongletActif = demande || this.ongletParDefaut;
                }
            })
            .catch((e) => {
                this.error = this.messageErreur(e) || this.txt.erreurChargement;
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    /* ── Statut du devis — aiguillage principal ────────────────────────────── */

    get statutCode() {
        return this.devis ? this.devis.statutCode : null;
    }

    /**
     * Un seul point de décision pour tout l'écran. Les statuts « En Att
     * Signature » et « Signé » ne sont volontairement PAS implémentés : ils
     * affichent un message d'attente. Toute la mécanique (onglets, chargement,
     * enregistrement, puissance) leur est déjà disponible le jour où leur
     * workflow sera défini — il n'y aura qu'à ajouter leur branche ici et le
     * gabarit correspondant.
     */
    get vueStatut() {
        switch (this.statutCode) {
            case STATUT_GENERATION:
                return 'GENERATION';
            case STATUT_ATTENTE_SIGNATURE:
                return 'ATTENTE_SIGNATURE';
            case STATUT_SIGNE:
                return 'SIGNE';
            default:
                return 'INCONNU';
        }
    }

    get estGenerationDevis() {
        return this.vueStatut === 'GENERATION';
    }

    /**
     * Parcours complet en 3 onglets : tant que le devis n'est pas signé, il
     * reste modifiable — que le document soit à produire (« Génération Devis »)
     * ou déjà parti en signature (« En Att Signature »).
     */
    get afficheOnglets() {
        return this.estGenerationDevis || this.estAttenteSignature;
    }

    /**
     * Corps de la modale. Signé compris : on n'y montre alors QUE le document
     * (voir ongletParDefaut), sans barre d'onglets ni récapitulatif.
     */
    get afficheDevis() {
        return this.afficheOnglets || this.estSigne;
    }

    /** Un devis signé se consulte, il ne se modifie plus. */
    get modificationAutorisee() {
        return !this.estSigne;
    }

    /** Signé : le document est le seul écran utile, il s'ouvre directement. */
    get ongletParDefaut() {
        return this.estSigne ? ONGLET_SIGNATURE : ONGLET_RECAP;
    }
    get estAttenteSignature() {
        return this.vueStatut === 'ATTENTE_SIGNATURE';
    }
    get estSigne() {
        return this.vueStatut === 'SIGNE';
    }
    get estStatutInconnu() {
        return this.vueStatut === 'INCONNU';
    }

    /** Message des statuts non encore implémentés. */
    get messageStatut() {
        if (this.estAttenteSignature) return this.txt.enAttenteSignature;
        if (this.estSigne) return this.txt.dejaSigne;
        return this.txt.statutInconnu;
    }

    /* ── Onglets ───────────────────────────────────────────────────────────── */

    get onglets() {
        const t = this.txt;
        return [
            { id: ONGLET_RECAP, num: '1', label: t.ongletRecap },
            { id: ONGLET_SIGNATURE, num: '2', label: t.ongletSignature }
        ].map((o) => ({
            ...o,
            cssClass: o.id === this.ongletActif ? 'devis-tab devis-tab--actif' : 'devis-tab'
        }));
    }

    get estOngletRecap() {
        return this.ongletActif === ONGLET_RECAP && this.modificationAutorisee;
    }
    /**
     * L'ancien onglet Document a disparu, mais la GENERATION reste declenchee
     * par l'etape Signature : ce getter la designe desormais, pour que la
     * chaine de fabrication n'ait pas eu a etre reecrite.
     */
    get estOngletDocument() {
        return this.ongletActif === ONGLET_SIGNATURE;
    }
    get estOngletSignature() {
        return this.ongletActif === ONGLET_SIGNATURE;
    }

    /* ── Navigation pas a pas ────────────────────────────────────────────────
       Les onglets ne sont plus cliquables : ils indiquent l'avancement, ils ne
       le commandent pas. On ne saute donc plus a l'onglet Signature sans etre
       passe par le recapitulatif, dont les champs alimentent le document. */

    /** Vrai tant qu'on n'a pas tente d'avancer : evite de souligner en rouge
     *  des champs vides que l'utilisateur n'a pas encore eu l'occasion de voir. */
    _validationTentee = false;

    /** Champs obligatoires encore vides, par leur libelle affiche. */
    get champsManquants() {
        return this.champsAffiches
            .filter((c) => c.editable && !String(c.valeur === null || c.valeur === undefined ? '' : c.valeur).trim())
            .map((c) => c.label);
    }

    get messageChampsManquants() {
        const modele = this.txt.champsObligatoires
            || 'Renseignez tous les champs avant de continuer : {0}.';
        return modele.replace('{0}', this.champsManquants.join(', '));
    }

    get libelleSuivant() {
        return this.txt.suivant || 'Suivant';
    }

    get libellePrecedent() {
        return this.txt.precedent || 'Precedent';
    }

    get suivantDesactive() {
        return this.isSaving;
    }

    /**
     * Le contenu de l'etape Signature n'apparait qu'une fois le document pret.
     * Tant qu'il se fabrique, seul le spinner s'affiche : proposer d'envoyer un
     * devis qui n'existe pas encore n'aurait pas de sens.
     */
    get signaturePrete() {
        return !this.pdfEnCours && !this.isLoading && !this.versionDevisIndeterminee;
    }

    /* ── Actions du pied ─────────────────────────────────────────────────────
       Conditionnees par `afficheOnglets` et pas seulement par l'onglet courant :
       sur un devis SIGNE la barre d'onglets disparait, ongletParDefaut vaut
       « document », et sans cette garde le pied proposerait un « Precedent »
       vers un ecran qui n'existe plus. */

    get afficheActionsRecap() {
        return this.afficheOnglets && this.estOngletRecap;
    }

    get afficheActionsSignature() {
        return this.afficheOnglets && this.estOngletSignature;
    }

    /**
     * Le bouton d'envoi du pied ne sert qu'au PREMIER envoi. Sur une demande
     * deja partie, les actions vivent au centre de l'ecran : le laisser aurait
     * offert deux chemins pour relancer, dont un sans le choix qui precede.
     */
    get afficheEnvoiDansLePied() {
        return this.afficheActionsSignature && !this.demandeEnCours;
    }

    /** Premier envoi ou relance : l'etat de la demande tranche, pas l'utilisateur. */
    get libelleActionSignature() {
        return this.demandeEnCours ? this.libelleRelancer : this.libelleBoutonSigner;
    }

    get actionSignatureDesactivee() {
        if (this.envoiEnCours) return true;
        return this.demandeEnCours ? false : this.signatureDesactivee;
    }

    handleActionSignature() {
        return this.demandeEnCours ? this.handleRelancer() : this.handleSigner();
    }

    async handleSuivant() {
        if (this.estOngletRecap) {
            this._validationTentee = true;
            if (this.champsManquants.length) {
                this.message = {
                    texte: this.messageChampsManquants,
                    cssClass: 'devis-msg devis-msg--erreur'
                };
                return;
            }
            // Les saisies partent AVANT de changer d'onglet : le document est
            // fabrique a partir des donnees enregistrees, pas du brouillon.
            if (this.aDesModifications) {
                await this.handleEnregistrer();
                if (this.message && this.message.cssClass.indexOf('erreur') !== -1) return;
            }
            this.allerA(ONGLET_SIGNATURE);
        }
    }

    /**
     * « Precedent » remonte d'UN cran, et la correction d'adresse en est un.
     *
     * Sur une demande deja partie, le champ email remplace les trois chemins
     * d'action : c'est un sous-ecran, pas un champ de plus. Le seul bouton de
     * retour ramenait pourtant au recapitulatif — on ouvrait le champ, on
     * renoncait, et on se retrouvait deux ecrans en arriere, a devoir refaire
     * « Suivant » pour retrouver le choix. La saisie non envoyee est jetee :
     * renoncer, c'est renoncer.
     */
    handlePrecedent() {
        if (this.demandeEnCours && this.editionEmail) {
            this.editionEmail = false;
            this._emailSaisi = null;
            this.message = null;
            return;
        }
        if (this.estOngletSignature) this.allerA(ONGLET_RECAP);
    }

    allerA(onglet) {
        this.ongletActif = onglet;
        this.message = null;
    }

    /* ── Onglet 1 : récapitulatif ──────────────────────────────────────────── */

    /**
     * Fusion de la CONFIG d'affichage (devisConfig) et des données AUTORISÉES
     * par l'Apex. Un champ configuré mais absent de la réponse serveur n'est pas
     * affiché : c'est le comportement voulu, la liste blanche Apex fait foi.
     */
    get champsAffiches() {
        if (!this.devis) return [];
        return this.construireChamps(champsRecap(this.devis.objectType, this.optionsRecap));
    }

    /**
     * Fabrique les champs d'ecran a partir d'une liste de descripteurs.
     *
     * Extrait de `champsAffiches` pour servir aussi l'onglet Signature : les
     * deux ecrans doivent traiter le brouillon, la validation et le marquage
     * « modifie » de la meme facon, sinon l'un des deux finira par diverger.
     */
    construireChamps(descripteurs) {
        if (!this.devis) return [];
        const parApi = {};
        (this.devis.champs || []).forEach((c) => {
            parApi[c.apiName] = c;
        });

        return (descripteurs || [])
            .map((conf) => {
                const src = parApi[conf.field];
                if (!src) return null;

                const editable = conf.editable !== false
                    && src.modifiable === true
                    && this.modificationAutorisee;
                const brouillon = this._brouillon[conf.field];
                const valeur = brouillon !== undefined ? brouillon : src.valeur;

                const valeurAffichee = valeur === null || valeur === undefined ? '' : valeur;

                // Champ RECOMMANDE : dire d'ou vient la valeur, et qu'elle se
                // change. Une liste pre-remplie sans un mot passe pour une
                // donnee du dossier, pas pour une proposition.
                let aide = null;
                if (conf.recommande) {
                    const reco = (this.calculsCourants.recommandations || {})[conf.recommande];
                    if (reco !== null && reco !== undefined) {
                        aide = String(valeurAffichee) === String(reco)
                            ? (this.txt.valeurRecommandeeAide
                                || 'Valeur recommandée d\'après la surface saisie — vous pouvez en choisir une autre.')
                            : (this.txt.valeurRecommandeeAutre || 'Valeur recommandée : {0}.')
                                .replace('{0}', String(reco));
                    }
                }
                // Une liste de choix ne se saisit pas au clavier : « Non, je
                // prefere que votre conseiller lui explique. » ne se tape pas
                // sans faute, et une valeur approchee ne correspondrait a aucune
                // regle de selection de version.
                const estListe = conf.type === 'picklist' && Array.isArray(conf.options);

                return {
                    key: conf.field,
                    apiName: conf.field,
                    label: conf.label || src.label,
                    type: conf.type || TYPES_INPUT[src.type] || 'text',
                    valeur: valeurAffichee,
                    aide,
                    estListe,
                    estSaisie: !estListe,
                    options: estListe
                        ? [{ cle: '', libelle: '', choisie: !valeurAffichee }].concat(
                            conf.options.map((o) => ({
                                cle: o,
                                libelle: o,
                                choisie: o === valeurAffichee
                            })))
                        : [],
                    editable,
                    modifie: brouillon !== undefined && brouillon !== src.valeur,
                    cssClass:
                        'devis-champ' +
                        (conf.pleineLargeur ? ' devis-champ--large' : '') +
                        (brouillon !== undefined && brouillon !== src.valeur
                            ? ' devis-champ--modifie'
                            : '') +
                        // Signale seulement APRES une tentative d'avancer : rougir
                        // d'emblee un formulaire qu'on vient d'ouvrir est hostile.
                        (this._validationTentee && editable
                            && !String(valeur === null || valeur === undefined ? '' : valeur).trim()
                            ? ' devis-champ--manquant'
                            : '')
                };
            })
            .filter(Boolean);
    }

    /** Champ natif : la valeur est sur l'élément, pas dans event.detail. */
    handleChampChange(event) {
        const api = event.currentTarget.dataset.api;
        this._brouillon = { ...this._brouillon, [api]: event.currentTarget.value };
        this._choisis.add(api);
        // Un champ de DECISION vient de changer : ce qui en decoule est
        // recalcule, MEME si l'utilisateur l'avait choisi a la main. Sa surface
        // a change, sa recommandation aussi — il retranchera s'il le souhaite,
        // et le message sous la liste lui dira que c'est une proposition.
        const dependants = this.champsDependantDe(api);
        dependants.forEach((f) => this._choisis.delete(f));
        this.appliquerRecommandations(dependants);
        this.message = null;
    }

    /** Champs recommandes dont la regle lit le champ `api`. */
    champsDependantDe(api) {
        const calculs = (this.reglagesSignatureFiche || {}).calculs || {};
        return champsRecapFiche(this.ficheCourante)
            .filter((c) => c && c.recommande && calculs[c.recommande]
                && calculs[c.recommande].champ === api)
            .map((c) => c.field);
    }

    /**
     * Pose dans le brouillon la valeur RECOMMANDEE des champs qui en declarent
     * une (`recommande` sur un champ de fiche), quand ils sont vides et que
     * l'utilisateur n'y a pas touche.
     *
     * Elle passe par le brouillon, et non par un simple affichage : c'est ce
     * qui la fait ENREGISTRER avec le reste au moment de « Suivant ». Une
     * valeur seulement affichee aurait donne un document juste a l'ecran et
     * une Piste sans nombre de capteurs.
     */
    /**
     * @param {Array<string>} [forces] champs a recalculer QUOI QU'IL ARRIVE —
     *        ceux dont le champ de decision vient de changer. Pour les autres,
     *        une valeur deja stockee ou deja choisie est laissee en place :
     *        a l'ouverture, ce que porte la Piste fait foi.
     */
    appliquerRecommandations(forces) {
        const declares = champsRecapFiche(this.ficheCourante).filter((c) => c && c.recommande);
        if (declares.length === 0) return;
        const forcer = new Set(forces || []);
        const propositions = this.calculsCourants.recommandations || {};
        const enregistre = (api) => {
            const champ = ((this.devis && this.devis.champs) || []).find((c) => c.apiName === api);
            return champ ? champ.valeur : null;
        };
        let brouillon = { ...this._brouillon };
        let change = false;
        declares.forEach((c) => {
            const force = forcer.has(c.field);
            if (!force && this._choisis.has(c.field)) return;
            const stocke = enregistre(c.field);
            if (!force && stocke !== null && stocke !== undefined && String(stocke).trim() !== '') return;
            const proposee = propositions[c.recommande];
            const courante = brouillon[c.field];
            if (proposee === null || proposee === undefined) {
                // Plus rien a proposer (surface hors tranches, ou vide).
                // Force : on VIDE plutot que de laisser l'ancienne valeur, qui
                // ne correspond plus a la surface — et le champ redevient a
                // renseigner. Sinon, on efface seulement la proposition.
                if (force) { brouillon[c.field] = ''; change = true; }
                else if (courante !== undefined) { delete brouillon[c.field]; change = true; }
                return;
            }
            if (String(courante) !== String(proposee)) {
                brouillon[c.field] = String(proposee);
                change = true;
            }
        });
        if (change) this._brouillon = brouillon;
    }

    get aDesModifications() {
        if (!this.devis) return false;
        const parApi = {};
        (this.devis.champs || []).forEach((c) => {
            parApi[c.apiName] = c.valeur;
        });
        return Object.keys(this._brouillon).some(
            (api) => String(this._brouillon[api] ?? '') !== String(parApi[api] ?? '')
        );
    }

    get enregistrementDesactive() {
        return this.isSaving || !this.aDesModifications || !this.modificationAutorisee;
    }

    handleAnnulerModifs() {
        this._brouillon = {};
        this._choisis = new Set();
        this.appliquerRecommandations();
        this.message = null;
    }

    /**
     * Enregistrement : n'envoie QUE les champs réellement modifiés, et se
     * rafraîchit avec la réponse du même appel — aucun rechargement de page,
     * aucun second aller-retour.
     */
    /** @returns une promesse, pour que « Suivant » puisse enregistrer avant d'avancer. */
    handleEnregistrer() {
        if (this.enregistrementDesactive) {
            this.message = { texte: this.txt.aucuneModification, cssClass: 'devis-msg devis-msg--info' };
            return Promise.resolve();
        }
        const token = this.campaignCode;
        if (!token && this.tokenRequis) {
            this.error = this.txt.tokenManquant;
            return Promise.resolve();
        }

        const parApi = {};
        (this.devis.champs || []).forEach((c) => {
            parApi[c.apiName] = c.valeur;
        });
        const valeurs = {};
        Object.keys(this._brouillon).forEach((api) => {
            if (String(this._brouillon[api] ?? '') !== String(parApi[api] ?? '')) {
                valeurs[api] = this._brouillon[api] === null ? '' : String(this._brouillon[api]);
            }
        });

        this.isSaving = true;
        this.message = null;
        this.error = null;

        return enregistrerDevis({
            recordId: this._recordId,
            campaignCode: token,
            valeurs,
            champs: champsDemandes(this.devis.objectType)
        })
            .then((data) => {
                this.devis = data;
                this._brouillon = {};
                this._choisis = new Set();
                this.appliquerRecommandations();
                // Le verrou de l'adresse retombe : nouvelles donnees, nouvelle lecture.
                this.editionEmail = false;
                this.message = { texte: this.txt.enregistre, cssClass: 'devis-msg devis-msg--ok' };
            })
            .catch((e) => {
                this.message = {
                    texte: this.messageErreur(e) || this.txt.erreurEnregistrement,
                    cssClass: 'devis-msg devis-msg--erreur'
                };
            })
            .finally(() => {
                this.isSaving = false;
            });
    }

    get libelleEnregistrer() {
        return this.isSaving ? this.txt.enregistrementEnCours : this.txt.enregistrer;
    }

    /* ── Surface -> puissance ──────────────────────────────────────────────── */

    /**
     * Surface COURANTE : la valeur en cours de saisie prime sur celle du serveur.
     * C'est ce qui fait que passer 95 -> 125 dans l'onglet 1 bascule la puissance
     * de 12 KW à 14 KW immédiatement, avant même d'avoir enregistré.
     */
    get surfaceCourante() {
        if (!this.devis) return null;
        const api = this.devis.champSurface;
        if (this._brouillon[api] !== undefined) return this._brouillon[api];
        const champ = (this.devis.champs || []).find((c) => c.apiName === api);
        return champ ? champ.valeur : this.devis.surface;
    }

    get puissance() {
        return puissancePourSurface(this.surfaceCourante);
    }

    /**
     * Fiche produit de l'enregistrement — « RESIDENTIEL_REGIES_-_RES060 » sur
     * la Piste, « BAR_TH171- PAC Indiv » sur le Dossier.
     */
    get ficheCourante() {
        if (!this.devis) return null;
        const api = CHAMP_FICHE[this.devis.objectType];
        if (!api) return null;
        const champ = (this.devis.champs || []).find((c) => c.apiName === api);
        return champ ? champ.valeur : null;
    }

    /**
     * Reglages Yousign de la fiche : langue de signature, expediteur,
     * emplacements de la signature et de la mention.
     *
     * Ils vivent dans le catalogue produits (c/lwc000_utils) et non dans des
     * Custom Labels : ils VARIENT d'une fiche a l'autre, alors qu'un label est
     * unique pour toute l'org — une deuxieme fiche signable y aurait ecrase la
     * premiere.
     *
     * `null` quand la fiche n'en declare pas : l'Apex retombe alors sur les
     * labels, et l'envoi fonctionne comme avant.
     */
    get reglagesSignatureFiche() {
        return reglagesSignature(this.ficheCourante, this.cleDevisCourante);
    }

    /**
     * Valeurs de l'enregistrement, par nom d'API, brouillon compris.
     *
     * Le BROUILLON prime : choisir « Oui » dans la liste doit changer la
     * version de devis immediatement, sans attendre un enregistrement.
     */
    get valeursCourantes() {
        const valeurs = {};
        ((this.devis && this.devis.champs) || []).forEach((c) => {
            valeurs[c.apiName] = c.valeur;
        });
        Object.keys(this._brouillon).forEach((api) => {
            valeurs[api] = this._brouillon[api];
        });
        return valeurs;
    }

    /**
     * Version de devis retenue, quand la fiche en propose plusieurs.
     *
     * `null` sur une fiche a un seul devis — reglagesSignature prend alors le
     * premier declare. `null` AUSSI quand aucune regle ne s'applique, et c'est
     * la le cas qui compte : tant que le champ decisif n'est pas renseigne, il
     * n'y a pas de devis, donc pas de document. L'ecran le dira plutot que de
     * servir une version au hasard.
     */
    get cleDevisCourante() {
        return cleDevisSelonConditions(this.ficheCourante, this.valeursCourantes);
    }

    /**
     * La fiche attend un choix qui n'a pas encore ete fait.
     *
     * Se distingue d'une fiche sans lanceur : ici des regles existent, mais
     * aucune ne s'applique.
     */
    get versionDevisIndeterminee() {
        // Sur le NOMBRE de versions, pas sur les champs du Recapitulatif : la
        // premiere ecriture confondait les deux, et bloquait le TH168 — un seul
        // devis, mais un champ de fiche — sur « choisissez le type de devis ».
        return devisSousConditions(this.ficheCourante) && !this.cleDevisCourante;
    }

    /**
     * Message affiche tant qu'aucune version n'est choisie.
     *
     * Il remplace le document : sans choix il n'y a PAS de devis, et generer
     * quoi que ce soit reviendrait a en inventer un. Le repli sur le premier
     * gabarit declare serait pire encore — l'utilisateur verrait un document
     * plausible, sans savoir qu'il n'a rien choisi.
     */
    get messageVersionAChoisir() {
        if (!this.versionDevisIndeterminee) return null;
        return this.txt.devisVersionAChoisir
            || 'Choisissez le type de devis pour produire le document.';
    }

    /**
     * Ce que l'Apex a besoin de savoir : uniquement les reglages Yousign.
     *
     * `contratUrl` en est ECARTE — c'est une URL de navigateur, sans usage
     * cote serveur, et l'envoyer encombrerait la requete sans rien apporter.
     */
    get reglagesPourApex() {
        const r = this.reglagesSignatureFiche;
        if (!r) return null;
        return {
            langue: r.langue,
            expediteur: r.expediteur,
            champSignature: r.champSignature,
            champMention: r.champMention
        };
    }

    /**
     * Gabarit contractuel a AFFICHER : celui de la fiche, sinon le repli.
     *
     * Un getter et non un champ : la fiche n'est connue qu'une fois `devis`
     * charge, alors que le composant s'affiche avant.
     */
    get gabaritUrl() {
        return this.reglagesSignatureFiche?.contratUrl || CAE_COLAB_CONTRAT;
    }

    /**
     * Ce qui distingue le recapitulatif d'une fiche a l'autre.
     *
     * La surface habitable ne sert qu'a deduire la puissance : la demander sur
     * une fiche qui n'en a pas ferait saisir une donnee que rien ne lit — et
     * obligatoirement, puisque tous les champs du recapitulatif le sont.
     */
    get optionsRecap() {
        const surface = this.devis ? CHAMP_SURFACE[this.devis.objectType] : null;
        const decision = (this.reglagesSignatureFiche || {}).champsDecision || [];
        return {
            // Cases de puissance (060) OU champ de decision declare (168) : dans
            // les deux cas la surface sert au document, il faut pouvoir la saisir.
            avecSurface: this.ficheUtilisePuissance || (!!surface && decision.includes(surface)),
            supplementaires: champsRecapFiche(this.ficheCourante)
        };
    }

    /* ── Calculs de la fiche ─────────────────────────────────────────────────
       Nombre de capteurs, surface installee, puissance et modele de PAC : des
       valeurs imprimees qui ne sont dans aucun champ. Les regles sont sur la
       fiche (c/lwc000_utils), l'evaluation dans devisConfig. */

    get calculsCourants() {
        const reglages = this.reglagesSignatureFiche;
        return evaluerCalculs(reglages ? reglages.calculs : null, this.valeursCourantes);
    }

    /** Un calcul declare par la fiche est reste sans resultat. */
    get calculsHorsCible() {
        return this.calculsCourants.horsCible.length > 0;
    }

    /** Date du jour, telle qu'imprimee — le format francais du devis. */
    get dateDuJour() {
        const d = new Date();
        const deux = (n) => String(n).padStart(2, '0');
        return deux(d.getDate()) + '/' + deux(d.getMonth() + 1) + '/' + d.getFullYear();
    }

    /**
     * Tout ce que le moteur PDF peut imprimer, resolu ici une fois pour
     * toutes : champs (brouillon compris), calculs, numero, identifiant, date.
     */
    get contextePdf() {
        if (!this.devis) return null;
        return {
            objectType: this.devis.objectType,
            champs: this.valeursCourantes,
            calculs: this.calculsCourants.valeurs,
            numeroDevis: this.numeroDevis,
            recordId: this._recordId,
            dateDuJour: this.dateDuJour
        };
    }

    /** Mise en page du gabarit : cadre client, numero, cases eventuelles. */
    get miseEnPagePdf() {
        return this.reglagesSignatureFiche?.pdf || null;
    }

    /**
     * Ce gabarit porte-t-il la bande « 12 / 14 / 16 kW » ?
     *
     * Tous ne l'ont pas : le solaire (TH168) n'a pas de puissance a cocher.
     * Sans cette distinction, une fiche sans cases ne produisait AUCUN document
     * — la generation s'arretait faute de case a cocher, et l'ecran restait sur
     * le gabarit vierge, sans nom de client ni numero.
     *
     * `true` a defaut : une fiche qui ne declare rien garde le comportement
     * historique de la 060.
     */
    get ficheUtilisePuissance() {
        const plan = this.miseEnPagePdf;
        return plan ? !!plan.casesPuissance : true;
    }

    /**
     * Hors cible : une surface qui ne tombe dans aucune tranche de puissance.
     *
     * ⚠️ NE VAUT QUE POUR UNE FICHE A CASES DE PUISSANCE. Ailleurs, la surface
     * n'est ni demandee ni lue, et la juger « hors cible » avait trois effets,
     * tous faux : le message « Surface habitable non renseignee » s'affichait,
     * le bouton d'envoi restait grise, et l'envoi etait refuse — sur des devis
     * ou la surface ne joue aucun role.
     */
    get estHorsCible() {
        if (this.ficheUtilisePuissance) return this.puissance.horsCible;
        return this.calculsHorsCible;
    }

    /**
     * Message explicite selon la raison du hors-cible.
     *
     * ⚠️ Passe par `estHorsCible`, jamais par `this.puissance` directement :
     * seul le premier tient compte de la fiche. Lire la puissance ici affichait
     * « Surface habitable non renseignee » sur des devis ou la surface ne joue
     * aucun role — le bouton d'envoi, lui, etait deja debloque, ce qui rendait
     * l'avertissement d'autant plus deroutant.
     */
    get messageHorsCible() {
        if (!this.estHorsCible) return null;
        if (this.ficheUtilisePuissance) {
            const p = this.puissance;
            if (p.raison === 'ABSENTE') return this.txt.surfaceAbsente;
            if (p.raison === 'INFERIEURE') return this.txt.surfaceTropPetite;
            return this.txt.surfaceTropGrande;
        }
        // Fiche a calculs : PLUSIEURS donnees peuvent etre en cause — la
        // toiture dimensionne le solaire, la surface habitable la pompe a
        // chaleur. Le message nomme celle du premier calcul reste sans
        // resultat, et distingue « pas saisie » de « hors tranches » : dire
        // « surface habitable » quand c'est la toiture qui manque enverrait
        // l'utilisateur corriger le mauvais champ.
        const calculs = (this.reglagesSignatureFiche || {}).calculs || {};
        const fautif = this.calculsCourants.horsCible.find((n) => calculs[n] && calculs[n].champ);
        const regle = fautif ? calculs[fautif] : null;
        const nom = (regle && regle.libelle) || 'Surface';
        const saisie = regle ? this.valeursCourantes[regle.champ] : null;
        const vide = saisie === null || saisie === undefined || String(saisie).trim() === '';
        const modele = vide
            ? (this.txt.calculChampAbsent || '{0} non renseignée : le dimensionnement est impossible.')
            : (this.txt.calculHorsCible || '{0} hors des tranches du devis : le dimensionnement est impossible.');
        return modele.replace('{0}', nom);
    }

    /**
     * Rappel des trois cases de la section « Description », au-dessus de l'aperçu.
     * C'est un RÉSUMÉ de lecture : la case est réellement cochée DANS le fichier
     * PDF par appliquerPuissanceSurPdf(), ce bandeau ne fait que rendre la
     * puissance retenue visible sans avoir à chercher la ligne dans le document.
     */
    get casesPuissance() {
        const retenue = this.puissance.puissance;
        return PUISSANCES.map((kw) => ({
            key: kw,
            libelle: `${kw} kW`,
            coche: kw === retenue ? '☑' : '☐',
            cssClass: kw === retenue ? 'devis-case devis-case--cochee' : 'devis-case'
        }));
    }

    /**
     * Coordonnées du client, telles qu'elles seront imprimées dans le cadre
     * « CLIENTE » de la page 1. Lues sur le BROUILLON en priorité : ce que
     * l'utilisateur vient de corriger dans l'onglet 1 part dans le document,
     * sans attendre l'enregistrement.
     */
    get donneesClient() {
        if (!this.devis) return null;
        const conf = CHAMPS_CLIENT_PDF[this.devis.objectType];
        if (!conf) return null;

        const valeur = (api) => {
            if (this._brouillon[api] !== undefined) return this._brouillon[api];
            const champ = (this.devis.champs || []).find((c) => c.apiName === api);
            return champ ? champ.valeur : null;
        };
        const joindre = (apis) => (apis || [])
            .map(valeur)
            .filter((v) => v !== null && v !== undefined && String(v).trim() !== '')
            .join(' ')
            .trim();

        // Quatre lignes distinctes dans le cadre CLIENTE — nom, adresse,
        // téléphone, email — et non plus une ligne « Tel. / Email » fusionnée.
        // Les clés doivent correspondre à PDF_ZONE_CLIENT.lignes.
        return {
            nom: joindre(conf.nom),
            adresse: joindre(conf.adresse),
            telephone: joindre(conf.telephone),
            email: joindre(conf.email)
        };
    }

    /**
     * Empreinte de ce que le document doit contenir. Le PDF n'est reconstruit
     * que lorsqu'elle change — sinon revenir sur l'onglet Document relancerait
     * toute la chaîne pour un résultat identique.
     */
    get signaturePdf() {
        const c = this.donneesClient || {};
        const reglages = this.reglagesSignatureFiche || {};
        // Toute donnée imprimée dans le document doit figurer ici, sinon une
        // correction du téléphone ou de l'email ne redéclencherait pas la
        // génération et le PDF resterait celui d'avant. Le numéro en fait
        // partie : un document produit avant son attribution doit être refait.
        //
        // LE GABARIT AUSSI, et c'est le cas le plus grave. Une fiche a
        // plusieurs versions de devis — le 110 en a deux, selon que le client
        // a ete informe du reste a charge. Changer ce choix apres generation
        // ne modifiait AUCUNE des donnees ci-dessus : l'empreinte restait
        // identique, rien n'etait regenere, et le document envoye a la
        // signature restait celui de l'autre version. Il fallait fermer la
        // modale et la rouvrir pour en sortir.
        // Les textes declares par la fiche, resolus a leur valeur — SAUF la
        // date du jour : elle changerait chaque matin et ferait regenerer un
        // document identique par ailleurs. Un devis deja produit garde donc
        // sa date ; une correction le refait a la date du jour.
        const contexte = this.contextePdf;
        const textes = ((reglages.pdf || {}).textes || [])
            .filter((t) => t.source !== 'dateDuJour')
            .map((t) => valeurDuTexte(t, contexte))
            .map((v) => (v === null || v === undefined ? '' : String(v)))
            .join('|');
        return [this.puissance.puissance, c.nom, c.adresse, c.telephone, c.email,
                this.numeroDevis, this.cleDevisCourante,
                reglages.contratRessource, textes].join('|');
    }

    /* ── Onglet 2 : document ───────────────────────────────────────────────── */

    renderedCallback() {
        // Le voile prend le focus au premier rendu : sans cela, la touche Échap
        // n'arriverait jamais jusqu'au gestionnaire tant que l'utilisateur n'a
        // pas cliqué dans la modale.
        if (!this._focusPose) {
            const voile = this.template.querySelector('.devis-voile');
            if (voile) {
                voile.focus();
                this._focusPose = true;
            }
        }

        // Devis SIGNÉ : on ne regénère RIEN. Regénérer réattacherait le contrat
        // au dossier et écraserait le document signé. On affiche le fichier
        // stocké, tel quel.
        if (this.estSigne) {
            if (!this._signeDemande) {
                this._signeDemande = true;
                this.chargerContratSigne();
            }
        } else if (this.estOngletDocument && this.versionDevisIndeterminee) {
            // Aucune version choisie : il n'y a PAS de devis. Fabriquer quoi que
            // ce soit reviendrait a en inventer un, et le repli sur le premier
            // gabarit declare serait pire — l'utilisateur verrait un document
            // plausible sans savoir qu'il n'a rien choisi.
            this._pdfSignature = null;
        } else if (this.estOngletDocument && this._pdfSignature !== this.signaturePdf) {
            // Génération PARESSEUSE : rien ne se produit tant que l'onglet
            // Document n'est pas ouvert. L'onglet 1 reste donc instantané —
            // auparavant il chargeait pdf-lib et pdf.js (~1,8 Mo de script) et
            // fabriquait le document alors que personne ne le regardait.
            this._pdfSignature = this.signaturePdf;
            this.genererPdf(this.puissance.puissance);
        }

        // Rendu canvas : uniquement quand l'onglet Document est affiché (le
        // conteneur n'existe pas avant) et que les octets cochés sont prêts.
        if (APERCU_CANVAS_ACTIF) this.rendrePdf();
    }
    /** Empreinte du document actuellement produit — voir signaturePdf. */
    _pdfSignature = null;
    _focusPose = false;
    _pdfLib = null;
    /** Le contrat signé a déjà été demandé — un seul appel par modale. */
    _signeDemande = false;
    /** Gabarit auquel correspondent `_octetsContrat` — voir genererPdf. */
    _ressourceContrat = null;
    /** Octets bruts du contrat VIERGE, livrés par l'Apex — un appel par modale. */
    _octetsContrat = null;
    /** Octets du contrat COCHÉ — la source de l'aperçu canvas. */
    _octetsCoche = null;
    /** Puissance dont le rendu canvas est à l'écran ; null = à (re)dessiner. */
    _pdfRendu = null;
    _renduEnCours = false;
    /** Observateur des pages non encore peintes — voir observerPages(). */
    _observateurPages = null;

    /**
     * Dessine le PDF coché sur des <canvas>, page par page, via pdf.js.
     *
     * POURQUOI PAS UN IFRAME — tout a été essayé et bloqué par la plateforme :
     * blob: refusé par frame-src (console CSP), /services/apexrest non routé
     * par le site LWR (404), servlet fichiers mut en script de redirection pour
     * le Guest User, lien de distribution servi en attachment (téléchargement).
     * Le canvas ne dépend d'AUCUNE de ces règles : les octets sont déjà en
     * mémoire, pdf.js les dessine, rien ne sort du composant.
     */
    /**
     * Affiche le document sur canvas, page par page.
     *
     * ⚠️ TOUT SE PASSE SUR LE THREAD PRINCIPAL. Dans ce site, Lightning Web
     * Security interdit à pdf.js de charger son worker : le worker est fourni
     * par loadScript, pdf.js détecte `window.pdfjsWorker` et n'instancie donc
     * aucun Worker. Chaque page peinte gèle l'interface d'autant.
     *
     * Tant que le contrat faisait 2 ou 3 pages, peindre l'ensemble d'un trait
     * passait. À 5 pages, Edge affichait « la page ne répond pas » et le
     * navigateur se figeait avant même la première page. D'où la stratégie
     * actuelle, en trois temps :
     *
     *   1. un emplacement VIDE mais déjà dimensionné par page — la modale
     *      devient défilante et utilisable tout de suite ;
     *   2. la PREMIÈRE page peinte aussitôt — l'utilisateur voit son document ;
     *   3. les suivantes seulement lorsqu'elles approchent de l'écran.
     *
     * Un devis qu'on ouvre pour vérifier une case en page 1 ne coûte donc plus
     * qu'une page peinte, quelle que soit l'épaisseur du contrat.
     */
    async rendrePdf() {
        if (!this.estOngletDocument || !this._octetsCoche || this._renduEnCours) return;
        if (this._pdfRendu === this.signaturePdf) return;
        const conteneur = this.template.querySelector('[data-pdf-pages]');
        const pdfjs = window.pdfjsLib;
        if (!conteneur || !pdfjs) return;

        this._renduEnCours = true;
        this.pdfEnCours = true;
        this.cesserObservation();

        try {
            await this.annoncer('pdfEtapeAffichage');

            // slice() : pdf.js peut détacher le buffer qu'on lui confie ; les
            // octets d'origine doivent survivre pour un futur re-rendu.
            const doc = await pdfjs.getDocument({
                data: this._octetsCoche.slice(),
                isEvalSupported: false
            }).promise;

            conteneur.innerHTML = '';
            const largeur = conteneur.clientWidth || 800;
            // Plafond à 1,25 : sur un écran Retina, chaque cran multiplie la
            // surface à peindre pour un gain quasi invisible à cette taille.
            const nettete = Math.min(window.devicePixelRatio || 1, 1.25);

            // ── 1. Les emplacements, vides mais à la bonne taille ────────────
            const emplacements = [];
            for (let n = 1; n <= doc.numPages; n++) {
                const page = await doc.getPage(n);
                const base = page.getViewport({ scale: 1 });
                const viewport = page.getViewport({ scale: (largeur / base.width) * nettete });

                const canvas = document.createElement('canvas');
                canvas.className = 'devis-pdf-page';
                // La mémoire du canvas n'est PAS allouée ici : un canvas plein
                // format pèse quelques mégaoctets, et cinq pages réservées
                // d'avance pour n'en peindre qu'une seule est un gâchis qui
                // grandit avec l'épaisseur du contrat. Seule la hauteur est
                // réservée en CSS, pour que le défilement soit juste ; la
                // largeur vient déjà de la feuille de style (width: 100%).
                canvas.style.height = Math.round(viewport.height / nettete) + 'px';
                conteneur.appendChild(canvas);

                emplacements.push({ canvas, page, viewport, peinte: false });
                await this.souffler();
            }

            // ── 2. La première page, tout de suite ───────────────────────────
            if (emplacements.length) {
                await this.peindrePage(emplacements[0]);
            }

            // ── 3. Les suivantes, à l'approche ───────────────────────────────
            this.observerPages(emplacements.slice(1), conteneur);

            this._pdfRendu = this.signaturePdf;
        } catch (e) {
            // eslint-disable-next-line no-console
            console.error('lwc021_devis_signature : rendu pdf.js impossible', e);
            this.pdfErreur = this.avertissementPdf(e);
        } finally {
            this._renduEnCours = false;
            this.pdfEnCours = false;
            this.pdfEtape = null;
        }
    }

    /** Peint une page, une seule fois. */
    async peindrePage(emplacement) {
        if (!emplacement || emplacement.peinte || emplacement.enCours) return;
        emplacement.enCours = true;
        try {
            // Allocation au dernier moment ; la hauteur réservée cède ensuite
            // la place au `height: auto` de la feuille de style.
            emplacement.canvas.width = emplacement.viewport.width;
            emplacement.canvas.height = emplacement.viewport.height;
            emplacement.canvas.style.height = '';

            await emplacement.page.render({
                canvasContext: emplacement.canvas.getContext('2d'),
                viewport: emplacement.viewport
            }).promise;
            emplacement.peinte = true;
        } catch (e) {
            // Une page illisible ne doit pas emporter les autres : elle reste
            // blanche, le reste du document s'affiche.
            // eslint-disable-next-line no-console
            console.error('lwc021_devis_signature : page non peinte', e);
        } finally {
            emplacement.enCours = false;
        }
    }

    /**
     * Peint chaque page lorsqu'elle approche de l'écran.
     *
     * La racine est le conteneur des pages, qui est le VRAI élément défilant
     * (`.devis-pdf-pages` porte `max-height: 62vh; overflow-y: auto`). La marge
     * de 300 px déclenche la peinture juste avant que la page ne devienne
     * visible, pour que le défilement ne montre pas de blanc.
     */
    observerPages(emplacements, conteneur) {
        if (!emplacements || !emplacements.length) return;

        if (typeof IntersectionObserver === 'undefined') {
            // Repli : on peint tout, mais en rendant la main entre chaque page.
            this.peindreLesRestantes(emplacements);
            return;
        }

        const parCanvas = new Map(emplacements.map((e) => [e.canvas, e]));
        this._observateurPages = new IntersectionObserver(
            (entrees, observateur) => {
                entrees.forEach((entree) => {
                    if (!entree.isIntersecting) return;
                    const emplacement = parCanvas.get(entree.target);
                    if (!emplacement) return;
                    observateur.unobserve(entree.target);
                    this.peindrePage(emplacement);
                });
            },
            { root: conteneur || null, rootMargin: '300px 0px' }
        );
        emplacements.forEach((e) => this._observateurPages.observe(e.canvas));
    }

    /** Repli séquentiel, sans IntersectionObserver. */
    async peindreLesRestantes(emplacements) {
        for (const emplacement of emplacements) {
            await this.peindrePage(emplacement);
            await this.souffler();
        }
    }

    cesserObservation() {
        if (this._observateurPages) {
            this._observateurPages.disconnect();
            this._observateurPages = null;
        }
    }

    /**
     * Rend la main au navigateur : sans cette respiration, la boucle monopolise
     * le thread et Edge propose de fermer la page.
     */
    souffler() {
        return new Promise((resoudre) => setTimeout(resoudre, 0));
    }

    /**
     * Charge pdf-lib (une seule fois) puis produit le document coché.
     *
     * Tout échec est absorbé : bibliothèque bloquée par la CSP du site,
     * ressource inaccessible, PDF illisible... l'aperçu retombe sur le document
     * d'origine plutôt que de rester vide, et le bandeau au-dessus signale que
     * la case n'a pas pu être cochée.
     */
    async genererPdf(puissance) {
        this.pdfErreur = null;

        // Hors cible : on montre le document nu, sans rien y poser. Pour la
        // 060 c'est la case de puissance qui manque ; pour une fiche a calculs
        // c'est un modele ou un nombre de capteurs sans resultat — un document
        // avec un blanc a cet endroit n'est pas un devis.
        if (this.estHorsCible) {
            this.libererBlob();
            this.urlPdf = this.gabaritUrl;
            this.pdfCoche = false;
            return;
        }

        this.pdfEnCours = true;
        try {
            if (!this._pdfLib) {
                // Étape la plus longue (~1,8 Mo de script) : annoncée avant
                // d'être lancée, sinon l'écran se fige sans explication.
                await this.annoncer('pdfEtapeLibs');
                // pdf-lib écrit le fichier ; pdf.js l'affiche. Le worker de
                // pdf.js est chargé sur le THREAD PRINCIPAL (loadScript) : la
                // lib détecte window.pdfjsWorker et n'instancie ni Worker ni
                // fetch — seuls canaux que la CSP/LWS du site laisse passer.
                // pdf.js n'est chargé QUE si l'aperçu canvas est actif : ce
                // sont les deux ressources les plus lourdes du lot, et elles ne
                // servent qu'à peindre. pdf-lib, lui, écrit le fichier et reste
                // indispensable.
                const aCharger = [loadScript(this, PDF_LIB)];
                if (APERCU_CANVAS_ACTIF) {
                    aCharger.push(loadScript(this, PDF_JS));
                    aCharger.push(loadScript(this, PDF_JS_WORKER));
                }
                await Promise.all(aCharger);
                this._pdfLib = this.recupererPdfLib();
            }
            // Les octets du contrat viennent de l'APEX, pas d'un fetch : LWS
            // bloque les requêtes du composant vers /resource/… (voir
            // devisConfig.base64VersOctets). Chargés une seule fois par modale.
            // Le cache d'octets vaut pour UN gabarit. Change-t-on de version,
            // il faut redemander le fichier : sans cela on redessinerait le
            // client et le numero sur le document precedent.
            const ressourceVoulue = this.reglagesSignatureFiche?.contratRessource || null;
            if (this._ressourceContrat !== ressourceVoulue) {
                this._octetsContrat = null;
                this._ressourceContrat = ressourceVoulue;
            }
            if (!this._octetsContrat) {
                await this.annoncer('pdfEtapeModele');
                const base64 = await getContratBase64({
                    campaignCode: this.campaignCode,
                    // Le serveur ne sert que les gabarits qu'il autorise : un
                    // nom inconnu retombe sur le gabarit par defaut.
                    ressource: this.reglagesSignatureFiche?.contratRessource || null
                });
                this._octetsContrat = base64VersOctets(base64);
            }
            // Le numero doit exister AVANT la fabrication : il est imprime
            // dans le document. L'appel est idempotent — un devis deja
            // numerote garde le sien et le compteur ne bouge pas.
            const numero = await this.assurerNumeroDevis();

            await this.annoncer('pdfEtapeGeneration');
            const resultat = await appliquerPuissanceSurPdf(
                this._octetsContrat,
                puissance,
                this._pdfLib,
                this.donneesClient,
                numero,
                // Cadres du gabarit de CETTE fiche. Absent, le moteur retombe
                // sur la mise en page du gabarit historique.
                this.miseEnPagePdf,
                this.contextePdf
            );
            this.libererBlob();
            // Le blob ne sert plus qu'au lien « ouvrir dans un nouvel onglet » :
            // la CSP du site refuse blob: en frame-src, l'aperçu passe par pdf.js.
            this.urlPdf = resultat.url;
            this.pdfCoche = resultat.coche === true;
            this._octetsCoche = resultat.octets;
            this._pdfRendu = null; // le rendu canvas doit repartir de zéro
            await this.annoncer('pdfEtapeEnregistrement');
            await this.joindreAuDossier(resultat.base64);
        } catch (e) {
            // eslint-disable-next-line no-console
            console.error('lwc021_devis_signature : cochage du PDF impossible', e);
            this.libererBlob();
            this.urlPdf = this.gabaritUrl;
            this.pdfCoche = false;
            this.pdfErreur = this.avertissementPdf(e);
        } finally {
            this.pdfEnCours = false;
            this.pdfEtape = null;
        }
    }

    /**
     * Affiche l'étape en cours ET rend la main au navigateur.
     *
     * Sans la pause, le message serait posé puis aussitôt suivi d'un calcul
     * bloquant : le navigateur n'aurait jamais l'occasion de le peindre et
     * l'utilisateur ne verrait qu'un figement. Le rAF attend la frame, le
     * setTimeout laisse le rendu se terminer.
     */
    async annoncer(cle) {
        this.pdfEtape = this.txt[cle] || null;
        await new Promise((resoudre) => {
            requestAnimationFrame(() => setTimeout(resoudre, 0));
        });
    }

    /**
     * Joint le PDF coché au record en fichier Salesforce versionné — c'est CE
     * fichier qui sera enrichi puis envoyé à uSign / DocuSign. L'Apex
     * déduplique par MD5 : rouvrir la modale sans changement ne crée aucune
     * version de plus.
     *
     * L'aperçu, lui, ne dépend PAS de cette jonction : il est rendu sur canvas
     * à partir des mêmes octets (voir rendrePdf) — contenu identique.
     */
    /**
     * Garantit qu'un numero est attribue, et le renvoie.
     *
     * Un echec n'interrompt PAS la generation : mieux vaut un devis consultable
     * sans numero qu'un ecran bloque. Le defaut se verra — le document sortira
     * avec « HP-2026- » suivi de rien — et le prochain passage reessaiera.
     */
    async assurerNumeroDevis() {
        if (this.numeroDevis) return this.numeroDevis;
        try {
            const numero = await reserverNumeroDevis({
                recordId: this._recordId,
                campaignCode: this.campaignCode,
                // Sequence designee par la fiche. A defaut, l'Apex retombe sur
                // la sequence historique du devis.
                cleCompteur: this.reglagesSignatureFiche?.compteur || null
            });
            // Inscrit localement : le devis n'est pas recharge apres la
            // generation, et sans cela l'empreinte resterait sans numero.
            if (numero && this.devis && this.devis.champs) {
                const champ = this.devis.champs.find(
                    (c) => c.apiName === 'YS_Numero_Devis__c'
                );
                if (champ) champ.valeur = numero;
            }
            return numero;
        } catch (e) {
            // eslint-disable-next-line no-console
            console.error('lwc021_devis_signature : numero de devis non attribue', e);
            return '';
        }
    }

    /** Numéro imprimé sur le devis, une fois attribué. */
    get numeroDevis() {
        return this.valeurCourante('YS_Numero_Devis__c') || '';
    }

    /** Empreinte du document DEJA joint au dossier, telle que le serveur la connait. */
    get empreinteStockee() {
        return this.valeurCourante('YS_Contrat_Empreinte__c');
    }

    /** Le dossier porte-t-il deja ce document exact ? */
    get contratDejaAJour() {
        return !!this.valeurCourante('YS_Contrat_Doc_Id__c')
            && this.empreinteStockee === this.signaturePdf;
    }

    async joindreAuDossier(base64) {
        // Rien n'a change depuis le dernier passage : ni televersement de
        // 874 Ko, ni nouvelle version. Ouvrir la modale pour consulter un devis
        // ne doit pas laisser de trace dans les fichiers du dossier.
        if (this.contratDejaAJour) {
            this.fichierJoint = true;
            return;
        }
        try {
            await enregistrerContrat({
                recordId: this._recordId,
                campaignCode: this.campaignCode,
                contenuBase64: base64,
                empreinte: this.signaturePdf
            });
            this.fichierJoint = true;
            // Le devis rechargé porterait la nouvelle empreinte ; on l'inscrit
            // localement pour que le prochain passage dans cette même modale
            // n'essaie pas de rejoindre le fichier.
            this._brouillon = { ...this._brouillon };
            if (this.devis && this.devis.champs) {
                const champ = this.devis.champs.find(
                    (c) => c.apiName === 'YS_Contrat_Empreinte__c'
                );
                if (champ) champ.valeur = this.signaturePdf;
            }
        } catch (e) {
            // Jonction impossible : l'anomalie est dite — le fichier N'EST PAS
            // sur le record (l'aperçu canvas, lui, reste affiché).
            // eslint-disable-next-line no-console
            console.error('lwc021_devis_signature : jonction du contrat impossible', e);
            this.fichierJoint = false;
            const cause = (e && e.body && e.body.message) || (e && e.message) || String(e);
            this.pdfErreur =
                (this.txt.fichierJointErreur ||
                    "Le devis n'a pas pu être joint au dossier.") +
                ' [' + cause + ']';
        }
    }

    /**
     * Devis signé : charge le contrat DÉJÀ JOINT au dossier et l'affiche.
     *
     * Aucune génération, aucune écriture — le document signé est la pièce de
     * référence, il ne doit être ni recalculé ni réattaché.
     */
    async chargerContratSigne() {
        this.pdfEnCours = true;
        this.pdfErreur = null;
        try {
            const base64 = await getContratStockeBase64({
                recordId: this._recordId,
                campaignCode: this.campaignCode
            });
            this._octetsCoche = base64VersOctets(base64);
            this._pdfRendu = null;
            this.pdfCoche = true;
            this.fichierJoint = true;
            // Sans cela, « ouvrir dans un nouvel onglet » servirait encore le
            // MODÈLE vierge : urlPdf n'est mis à jour que par genererPdf(), qui
            // ne tourne jamais sur un devis signé.
            this.libererBlob();
            this.urlPdf = URL.createObjectURL(
                new Blob([this._octetsCoche], { type: 'application/pdf' })
            );
        } catch (e) {
            // eslint-disable-next-line no-console
            console.error('lwc021_devis_signature : contrat signé illisible', e);
            const cause = (e && e.body && e.body.message) || (e && e.message) || String(e);
            this.pdfErreur = (this.txt.devisSigneIntrouvable
                || 'Le devis signé est introuvable.') + ' [' + cause + ']';

            // ⚠️ On COUPE le lien plutôt que de laisser urlPdf sur sa valeur
            // initiale — le MODÈLE vierge du Static Resource. Sur un devis
            // signé, offrir le modèle vierge sous le libellé « Ouvrir le
            // devis » ferait passer un document sans valeur pour le document
            // contractuel. Mieux vaut aucun lien qu'un mauvais.
            this.libererBlob();
            this.urlPdf = null;
        } finally {
            this.pdfEnCours = false;
        }
    }

    /**
     * pdf-lib est livré en UMD : il s'installe sur l'objet global. Selon le mode
     * de sécurité du site (Lightning Web Security ou Locker), le global vu depuis
     * le composant n'est pas forcément le même objet — d'où les trois tentatives
     * plutôt qu'un `window.PDFLib` sec.
     */
    recupererPdfLib() {
        const candidats = [
            typeof window !== 'undefined' ? window : null,
            typeof globalThis !== 'undefined' ? globalThis : null,
            typeof self !== 'undefined' ? self : null
        ];
        for (const g of candidats) {
            if (g && g.PDFLib && g.PDFLib.PDFDocument) return g.PDFLib;
        }
        return null;
    }

    /**
     * Avertissement affiché quand le document n'a PAS pu être coché.
     *
     * Le libellé de repli est codé en dur : si dicoDevis n'est pas à jour dans
     * l'org, `txt.pdfNonCoche` vaut `undefined` et l'anomalie deviendrait
     * invisible — exactement le piège à éviter ici. La cause technique est
     * jointe : c'est elle qui permet de trancher sans ouvrir la console.
     */
    avertissementPdf(erreur) {
        const base =
            this.txt.pdfNonCoche ||
            "La case n'a pas pu être cochée automatiquement : le document s'affiche non coché.";
        const cause = erreur && (erreur.message || String(erreur));
        return cause ? base + ' [' + cause + ']' : base;
    }

    /** Un blob: non révoqué retient tout le PDF en mémoire jusqu'à la fermeture
     *  de l'onglet ; la puissance pouvant changer plusieurs fois, on libère. */
    libererBlob() {
        if (this.urlPdf && this.urlPdf.indexOf('blob:') === 0) {
            URL.revokeObjectURL(this.urlPdf);
        }
    }

    disconnectedCallback() {
        this.libererBlob();
        // Sans cela, l'observateur survivrait à la modale et tenterait de
        // peindre des canvas détachés du document.
        this.cesserObservation();
    }

    /**
     * Libellé du bandeau : état RÉEL du document, pas seulement la puissance.
     * Replis codés en dur pour la même raison que dans avertissementPdf().
     */
    /** Étape en cours, avec repli : le spinner ne doit jamais rester muet. */
    get libellePdfEtape() {
        return this.pdfEtape || this.txt.pdfEnCours || 'Préparation du document...';
    }

    /** Le bandeau « case cochée » ne concerne que la production du devis. */
    get afficheCases() {
        return !this.estSigne;
    }

    get libelleCases() {
        if (this.pdfEnCours) return this.txt.pdfEnCours || 'Préparation du document...';
        if (this.pdfCoche && this.fichierJoint) {
            return (
                this.txt.caseCocheeJointe ||
                'Case cochée — devis joint au dossier :'
            );
        }
        if (this.pdfCoche) {
            return this.txt.caseCochee || 'Case cochée dans le document, section Description :';
        }
        return this.txt.casePuissance || 'À cocher dans la section Description :';
    }

    /** Le gabarit s'aligne sur le drapeau : un seul endroit à basculer. */
    get apercuCanvasActif() {
        return APERCU_CANVAS_ACTIF;
    }

    /* ── Libellés du bloc « ouvrir le document » ─────────────────────────────
       Replis codés en dur, comme partout ailleurs dans ce composant : le
       dictionnaire c/lwc000_i18n vit dans l'org et peut être en retard d'une clé. */

    get libelleDocumentPret() {
        if (this.estSigne) {
            return this.txt.documentSignePret || 'Votre devis signé est disponible.';
        }
        return this.txt.documentPret || 'Votre devis est prêt.';
    }

    get libelleOuvrirDocument() {
        // Sur un devis signé, le libellé doit dire lequel des deux fichiers on
        // ouvre : le dossier porte à la fois le devis vierge et le devis signé.
        if (this.estSigne) {
            return this.txt.ouvrirDocumentSigne || 'Ouvrir le devis signé';
        }
        return this.txt.ouvrirDocument || 'Ouvrir le devis';
    }

    get libelleOuvrirAide() {
        return this.txt.ouvrirDocumentAide
            || "Le document s'ouvre dans un nouvel onglet.";
    }

    get pdfIndisponible() {
        return !this.urlPdf;
    }

    /* ── Onglet 3 : signature ──────────────────────────────────────────────── */

    /**
     * Valeur courante d'un champ : le brouillon de l'onglet 1 l'emporte sur la
     * valeur en base. Une adresse email corrigée part donc à la signature sans
     * qu'il faille l'enregistrer d'abord.
     */
    valeurCourante(api) {
        if (!api) return null;
        if (this._brouillon[api] !== undefined) return this._brouillon[api];
        const champ = ((this.devis && this.devis.champs) || []).find((c) => c.apiName === api);
        return champ ? champ.valeur : null;
    }

    /**
     * Email du destinataire de la signature.
     *
     * `donneesClient` ne convient pas ici : il fusionne téléphone et email sur
     * une seule ligne pour l'impression du contrat. Yousign veut une adresse
     * seule — d'où cette lecture dédiée, qui suit CHAMPS_SIGNATAIRE.
     *
     * Trois niveaux de priorité : ce que l'utilisateur vient de taper dans
     * l'onglet 3, puis le brouillon de l'onglet 1, puis la base.
     */
    get emailSignataire() {
        if (this._emailSaisi !== null) return this._emailSaisi;
        return this.emailDuRecord;
    }

    get emailDuRecord() {
        if (!this.devis) return '';
        const conf = CHAMPS_SIGNATAIRE[this.devis.objectType];
        if (!conf) return '';
        for (const api of conf.email || []) {
            const v = this.valeurCourante(api);
            if (v && String(v).trim()) return String(v).trim();
        }
        return '';
    }

    /** Prénom et nom séparés — la Piste les porte déjà ainsi, le Dossier non. */
    get prenomSignataire() {
        if (!this.devis) return '';
        const conf = CHAMPS_SIGNATAIRE[this.devis.objectType] || {};
        return conf.prenom ? this.valeurCourante(conf.prenom) || '' : '';
    }

    get nomSignataire() {
        if (!this.devis) return '';
        const conf = CHAMPS_SIGNATAIRE[this.devis.objectType] || {};
        if (conf.nom) return this.valeurCourante(conf.nom) || '';
        // Dossier : un seul champ « Nom+Prénom ». On l'envoie tel quel, c'est
        // l'Apex qui le coupe — le composant n'a pas à deviner où est la césure.
        return conf.nomComplet ? this.valeurCourante(conf.nomComplet) || '' : '';
    }

    /** Nom affiché sous le champ email, pour que l'utilisateur voie qui signera. */
    get nomSignataireAffiche() {
        return [this.prenomSignataire, this.nomSignataire]
            .filter((v) => v && String(v).trim())
            .join(' ')
            .trim();
    }

    /* ── Suivi de la demande Yousign ───────────────────────────────────────── */

    get demandeIdYousign() {
        return this.valeurCourante('YS_Demande_Id__c');
    }

    get statutYousign() {
        return this.valeurCourante('YS_Statut__c');
    }

    /** Une demande est partie et n'a pas encore abouti. */
    get demandeEnCours() {
        const s = this.statutYousign;
        return !!this.demandeIdYousign && (s === 'Envoye' || s === 'Ouvert');
    }

    get envoiEnErreur() {
        return this.statutYousign === 'Erreur';
    }

    /** Date d'envoi en clair, ou chaîne vide. */
    get dateEnvoiAffichee() {
        return this.dateLisible(this.valeurCourante('YS_Date_Envoi__c'));
    }

    /** Date de signature, telle que remontee par Yousign. Vide si absente. */
    get dateSignatureAffichee() {
        return this.dateLisible(this.valeurCourante('YS_Date_Signature__c'));
    }

    get libelleSigneLe() {
        const modele = this.txt.devisSigneLe || 'Signe le {0}';
        return modele.replace('{0}', this.dateSignatureAffichee);
    }

    /** Horodatage Salesforce -> « 26/08/2026 19:17 ». Chaine vide si illisible. */
    dateLisible(brut) {
        if (!brut) return '';
        const d = new Date(brut);
        if (isNaN(d.getTime())) return '';
        return d.toLocaleString(this._langue === 'es' ? 'es-ES' : 'fr-FR', {
            day: '2-digit', month: '2-digit', year: 'numeric',
            hour: '2-digit', minute: '2-digit'
        });
    }

    /**
     * Le suivi de la demande — date d'envoi et rappel de ce que recoit le
     * client — s'affiche DANS la carte du document, et seulement tant qu'il y a
     * quelque chose a attendre. Une fois le devis signe, il n'y a plus de
     * demande en cours a raconter.
     */
    get afficheSuiviDemande() {
        return this.demandeEnCours && !this.estSigne;
    }

    get messageDejaEnvoyee() {
        const modele = this.txt.signatureDejaEnvoyee
            || 'Une demande de signature a été envoyée le {0}.';
        return modele.replace('{0}', this.dateEnvoiAffichee);
    }

    /* ── Saisie et envoi ───────────────────────────────────────────────────── */

    /* ── Libellés de l'onglet 3 ─────────────────────────────────────────────
       Chacun porte un repli codé en dur, comme le reste du composant : le
       dictionnaire c/lwc000_i18n vit dans l'org et non dans ce dépôt, il peut
       donc être en retard d'une clé. Un écran sans étiquette serait pire qu'un
       écran en français. */

    get libelleEmailSignataire() {
        return this.txt.signatureEmailLabel || 'Email du signataire';
    }

    get libelleDestinataire() {
        return this.txt.signatureDestinataire || 'Signataire';
    }

    get aideAttenteSignature() {
        return this.txt.signatureAttenteAide
            || "Le client reçoit un lien par email. Le devis passera automatiquement "
             + "à « signé » dès qu'il aura signé.";
    }

    handleEmailSignataire(event) {
        this._emailSaisi = event.target.value;
        this.message = null;
    }

    /**
     * Le bouton reste inerte tant qu'il manque de quoi envoyer : hors cible, pas
     * d'email, ou un envoi déjà en vol. L'Apex refait tous ces contrôles — griser
     * un bouton n'empêche pas d'appeler la méthode.
     */
    /**
     * `!signaturePrete` : tant que le contrat se fabrique, il n'y a rien a
     * envoyer. Le bouton restait pourtant cliquable pendant la generation, et
     * un clic anticipe partait chercher un fichier qui n'existait pas encore.
     */
    /**
     * Le document JOINT correspond-il a ce que l'ecran affiche ?
     *
     * ⚠️ CE QUI PART A LA SIGNATURE EST LE FICHIER JOINT AU DOSSIER, pas
     * l'apercu. Les deux peuvent diverger : il suffit de revenir en arriere,
     * de changer un choix, et de repasser a l'etape Signature avant que la
     * regeneration n'ait abouti. Sans ce controle, le client recevrait l'autre
     * version du contrat — et l'ecart ne se verrait qu'apres sa signature.
     */
    get contratEnvoyeConforme() {
        return this.contratDejaAJour;
    }

    get signatureDesactivee() {
        return this.estHorsCible
            || this.envoiEnCours
            || !this.signaturePrete
            || !this.contratEnvoyeConforme
            || !this.emailSignataire;
    }

    /** Averti l'utilisateur plutot que de laisser un bouton grise sans raison. */
    get messageDocumentObsolete() {
        if (this.contratEnvoyeConforme || !this.signaturePrete || this.estSigne) return null;
        return this.txt.signatureDocumentObsolete
            || 'Le document est en cours de mise a jour. Patientez avant de l\'envoyer.';
    }

    /**
     * Mode test : `?c__test=true` dans l'URL de la page.
     *
     * Lu au moment de l'affichage et non au chargement : le conteneur reecrit
     * l'URL pour en retirer le token, et le parametre doit etre lu sur l'URL
     * telle qu'elle est, pas telle qu'elle etait.
     */
    get modeTest() {
        try {
            return new URL(window.location.href).searchParams.get('c__test') === 'true';
        } catch (e) {
            return false;
        }
    }

    /**
     * Message d'un echec d'envoi cote Yousign.
     *
     * Generique pour l'utilisateur ; le motif technique s'y ajoute en mode test.
     * Les messages METIER (« email invalide », « demande deja en cours ») ne
     * passent pas ici : ils arrivent par exception et restent visibles pour
     * tout le monde — c'est a l'utilisateur d'agir dessus.
     */
    messageEchecYousign(motifTechnique) {
        const generique = this.txt.signatureErreurEnvoi || 'L\'envoi à la signature a échoué.';
        if (this.modeTest && motifTechnique) return generique + ' [' + motifTechnique + ']';
        return generique;
    }

    get libelleBoutonSigner() {
        if (this.envoiEnCours) return this.txt.signatureEnvoiEnCours || 'Envoi en cours…';
        return this.txt.signerDevis;
    }

    /**
     * Envoie le devis à la signature.
     *
     * Le PDF n'est PAS régénéré ici : c'est le fichier déjà joint au dossier —
     * celui que le client a vu dans l'onglet Document — que l'Apex transmet à
     * Yousign. Envoyer autre chose que ce qui a été montré n'aurait pas de sens
     * pour un document contractuel.
     */
    async envoyerDemande(estRelance) {
        // Deuxieme verrou, apres le bouton grise. L'un protege de l'erreur de
        // manipulation, l'autre d'un appel qui l'aurait contourne : sur un
        // document contractuel, se fier au seul etat visuel ne suffit pas.
        if (!this.contratEnvoyeConforme) {
            this.message = {
                texte: this.messageDocumentObsolete,
                cssClass: 'devis-msg devis-msg--erreur'
            };
            return;
        }
        if (this.estHorsCible) {
            this.message = {
                texte: this.txt.signatureBloqueeHorsCible,
                cssClass: 'devis-msg devis-msg--erreur'
            };
            return;
        }
        const email = (this.emailSignataire || '').trim();
        if (!email) {
            this.message = {
                texte: this.txt.signatureEmailManquant
                    || 'Renseignez l\'adresse email du signataire.',
                cssClass: 'devis-msg devis-msg--erreur'
            };
            return;
        }

        this.envoiEnCours = true;
        this.message = {
            texte: this.txt.signatureEnvoiEnCours || 'Envoi en cours…',
            cssClass: 'devis-msg devis-msg--info'
        };

        try {
            const resultat = await envoyerPourSignature({
                recordId: this._recordId,
                campaignCode: this.campaignCode,
                emailSignataire: email,
                prenomSignataire: this.prenomSignataire,
                nomSignataire: this.nomSignataire,
                langue: this._langue,
                relance: estRelance === true,
                // Serialise ici plutot que passe en parametres separes : une
                // fiche pourra en porter d'autres demain sans qu'il faille
                // toucher a la signature Apex ni la reautoriser sur les
                // 18 profils du portail.
                reglagesSignature: JSON.stringify(this.reglagesPourApex || {})
            });

            if (resultat && resultat.envoye) {
                this._emailSaisi = null;
                // Le rechargement remet message à null : on le repose après.
                await this.charger({ conserverOnglet: true });
                const modele = this.txt.signatureEnvoyee
                    || 'Devis envoyé à {0} pour signature.';
                this.message = {
                    texte: modele.replace('{0}', resultat.email || email),
                    cssClass: 'devis-msg devis-msg--ok'
                };
            } else {
                // Échec côté Yousign : l'Apex n'a PAS levé d'exception, pour que
                // le motif reste enregistré sur le dossier (YS_Message_Erreur__c).
                // A l'ecran, le motif technique n'apparait qu'en MODE TEST : un
                // utilisateur du portail ne peut rien faire de « fields[0].height
                // should be greater than or equal to 37 », et le lui montrer
                // ressemble a une panne. Celui qui diagnostique ajoute
                // ?c__test=true a l'URL et voit tout.
                await this.charger({ conserverOnglet: true });
                this.message = {
                    texte: this.messageEchecYousign(resultat && resultat.message),
                    cssClass: 'devis-msg devis-msg--erreur'
                };
            }
        } catch (e) {
            this.message = {
                texte: this.messageErreur(e)
                    || this.txt.signatureErreurEnvoi
                    || 'L\'envoi à la signature a échoué.',
                cssClass: 'devis-msg devis-msg--erreur'
            };
        } finally {
            this.envoiEnCours = false;
        }
    }

    /* ── Relance : trois chemins plutot qu'un bouton ────────────────────────
       Un devis reste sans reponse pour trois raisons, et une seule d'entre
       elles se corrige en renvoyant le meme mail. Proposer directement
       « relancer » revenait a supposer que l'adresse et les informations
       etaient bonnes ; l'ecran laisse maintenant le choix. */

    get libelleModifierInfos() {
        return this.txt.relanceModifierInfos || 'Modifier les informations du devis';
    }

    get libelleModifierEmail() {
        return this.txt.relanceModifierEmail || "Modifier l'email du signataire";
    }

    /**
     * L'adresse est verrouillee tant qu'on n'a pas demande a la changer.
     *
     * C'est le destinataire d'un document contractuel : on ne le modifie pas
     * d'un clic distrait dans un champ, on le decide. Un champ grise dit aussi
     * a l'operateur que l'adresse affichee est bien celle du dossier, et pas
     * une saisie a completer.
     */
    get emailVerrouille() {
        return !this.editionEmail;
    }

    get libelleModifierEmailCourt() {
        return this.txt.emailModifier || 'Modifier';
    }

    /** « Relance 1 → 2 » : d'ou l'on part, ou l'on va. */
    get libelleRelanceFleche() {
        const modele = this.txt.relanceFleche || 'Relance {0} → {1}';
        return modele.replace('{0}', String(this.nbRelances))
                     .replace('{1}', String(this.nbRelances + 1));
    }

    get libelleEnregistrerEtRelancer() {
        return this.txt.relanceEnregistrerEtEnvoyer || 'Enregistrer et envoyer la relance';
    }

    /** Retour au recapitulatif : les informations du devis s'y corrigent. */
    handleModifierInfos() {
        this.editionEmail = false;
        this.allerA(ONGLET_RECAP);
    }

    handleModifierEmail() {
        this.editionEmail = true;
        this.message = null;
    }

    /**
     * Enregistre l'adresse corrigee SUR l'enregistrement, puis relance.
     *
     * Le champ de l'onglet Signature ne vivait jusqu'ici qu'en memoire : il
     * servait de destinataire pour un envoi, sans jamais rejoindre la fiche. Sur
     * une relance c'est insuffisant — si l'adresse etait fausse, elle doit etre
     * corrigee POUR DE BON, sans quoi la relance suivante repartirait sur la
     * mauvaise.
     */
    async handleEnregistrerEtRelancer() {
        const email = (this.emailSignataire || '').trim();
        if (!email) {
            this.message = {
                texte: this.txt.signatureEmailManquant
                    || "Renseignez l'adresse email du signataire.",
                cssClass: 'devis-msg devis-msg--erreur'
            };
            return;
        }

        const conf = CHAMPS_SIGNATAIRE[this.devis.objectType] || {};
        const champ = (conf.email || [])[0];
        if (champ && email !== this.emailDuRecord) {
            this._brouillon = { ...this._brouillon, [champ]: email };
            await this.handleEnregistrer();
            if (this.message && this.message.cssClass.indexOf('erreur') !== -1) return;
        }

        this.editionEmail = false;
        await this.handleRelancer();
    }

    /** Premier envoi : le compteur de relances ne bouge pas. */
    handleSigner() {
        return this.envoyerDemande(false);
    }

    /**
     * Relance : une nouvelle demande Yousign part, et le compteur avance.
     *
     * On ne passe plus par reinitialiserSignature : effacer le suivi puis
     * renvoyer faisait deux gestes la ou il n'y a qu'une intention, et le
     * compteur n'aurait rien eu a compter entre les deux.
     */
    handleRelancer() {
        return this.envoyerDemande(true);
    }

    /* ── Relances ──────────────────────────────────────────────────────────── */

    /** Nombre de relances deja envoyees. Le premier envoi n'en est pas une. */
    get nbRelances() {
        const brut = this.valeurCourante('YS_Nb_Relances__c');
        const n = Number(brut);
        return isNaN(n) ? 0 : n;
    }

    /**
     * Rang de la relance a venir, en toutes lettres abregees : 1re, 2e, 3e…
     * (1.ª, 2.ª en espagnol). C'est le libelle du bouton qui l'annonce, pour
     * que l'utilisateur sache combien de fois il a deja sollicite le client.
     */
    get libelleRelancer() {
        const rang = this.nbRelances + 1;
        const espagnol = this._langue === 'es';
        const ordinal = espagnol
            ? rang + '.ª'
            : (rang === 1 ? '1re' : rang + 'e');
        const modele = this.txt.relanceEnvoyer || 'Envoyer la {0} relance';
        return modele.replace('{0}', ordinal);
    }

    /* ── Fermeture ─────────────────────────────────────────────────────────── */

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    /** Clic sur le voile : ferme, comme le bouton X. Le clic sur la carte non. */
    handleVoileClick(event) {
        if (event.target === event.currentTarget) this.handleClose();
    }

    handleKeyDown(event) {
        if (event.key === 'Escape') this.handleClose();
    }

    /* ── Divers ────────────────────────────────────────────────────────────── */

    get titre() {
        if (!this.devis) return this.txt.titreModale;
        return `${this.txt.titreModale} — ${this.devis.titre || ''}`.trim();
    }

    get sousTitre() {
        if (!this.devis) return '';
        return `${this.devis.typeLibelle} · ${this.devis.statutValeur || '—'}`;
    }

    get afficherContenu() {
        return !this.isLoading && !this.error && this.devis;
    }

    /** Message d'erreur lisible à partir d'une erreur Apex. */
    messageErreur(err) {
        if (!err) return null;
        if (err.body && err.body.message) return err.body.message;
        if (Array.isArray(err.body)) return err.body.map((e) => e.message).join(', ');
        return err.message || null;
    }
}