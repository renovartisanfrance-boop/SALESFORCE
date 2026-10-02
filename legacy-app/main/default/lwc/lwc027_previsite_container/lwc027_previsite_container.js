import { LightningElement, track, api, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getPrevisiteurByToken from '@salesforce/apex/LC027_GestionPrevisites.getPrevisiteurByToken';
import logoEconatura from '@salesforce/resourceUrl/logo_econatura';
// Utilitaire GENERIQUE partage (famille lwc000_) : detecte l'apercu du
// Generateur d'experience, ou aucun token ne circule dans l'URL.
import { estModeGenerateur } from 'c/lwc000_utils';
// Valeur d'API de Campaign.StatutContrat__c. Importée de la config du contrat
// plutôt que recopiée : une chaîne de picklist dupliquée finit par diverger.
import { STATUT_SIGNE, STATUT_ATTENTE_SIGNATURE, ROLE_INSTALLATEUR } from 'c/lwc027_gestion_contrat';
import { ES, FR, lireLangue, ecrireLangue, autreLangue, etiquettes } from 'c/lwc027_i18n';

/**
 * Cle de stockage du token. DISTINCTE de « renov_campaign_token » utilisee par
 * lwc020_CampagneContainer : les deux portails partagent le meme navigateur et
 * le meme domaine my.site.com. Une cle commune ferait qu'une connexion a
 * Campagnes ecraserait la session Previsites, et inversement.
 */
const CLE_TOKEN = 'renov_previsite_token';

/**
 * MODE TEST — pose par ?c__test=true dans l'URL, retire par ?c__test=false.
 *
 * La valeur est MEMORISEE : une fois posee, elle survit aux navigations sans
 * qu'on ait a repasser le parametre. Sans cela il faudrait le rajouter a chaque
 * ecran, et il finirait par etre partage par erreur dans un lien.
 *
 * Le parametre est RETIRE de l'URL des sa lecture, comme le token : une adresse
 * copiee-collee ne doit pas transmettre le mode test a un previsiteur.
 *
 * Ce qu'il ouvre aujourd'hui : la bascule de langue, reservee aux essais tant
 * que le portail ne s'adresse qu'a des techniciens espagnols.
 */
const CLE_TEST = 'renov_previsite_test';

/**
 * Clés des écrans d'erreur, indexées sur le statut renvoyé par
 * LC027_GestionPrevisites. Les TEXTES vivent dans c/lwc027_i18n : ils changent
 * avec la langue, l'écran affiché non. On ne stocke donc que la clé, et le
 * libellé se résout au rendu — sinon un changement de langue laisserait à
 * l'écran le message figé dans la langue précédente.
 */
const CLES_ERREUR = ['TOKEN_MANQUANT', 'INTROUVABLE', 'ROLE_INVALIDE', 'DESACTIVE'];

/**
 * Vues du portail, une fois le contrat signé. La valeur est reprise telle quelle
 * dans l'URL (?c__view=) pour survivre à un rafraîchissement — même procédé que
 * le portail Campagnes.
 */
const VUE_PREVISITES    = 'previsites';
/** Vue d'activité de l'installateur — pendant de VUE_PREVISITES. */
const VUE_INSTALLATIONS = 'installations';
const VUE_FACTURATION   = 'facturation';
const VUES_VALIDES = [VUE_PREVISITES, VUE_INSTALLATIONS, VUE_FACTURATION];
const CLE_TECHNIQUE = 'TECHNIQUE';
const CLE_GENERATEUR = 'GENERATEUR';

export default class Lwc027PrevisiteContainer extends LightningElement {
    logoEconatura = logoEconatura;
    @api isGuestUser = false;

    @track isLoading = true;
    @track hasError = false;
    /** Clé d'écran d'erreur (voir CLES_ERREUR) — le texte se résout au rendu. */
    @track cleErreur = null;
    @track previsiteur = null;
    /** Langue d'affichage. Espagnol par défaut, bascule offerte dans l'en-tête. */
    @track langue = lireLangue();
    /** Vue active du portail. Sans effet tant que le contrat n'est pas signé. */
    @track vue = VUE_PREVISITES;
    /** Mode test : lu de l'URL, puis mémorisé. Voir CLE_TEST. */
    @track modeTest = false;
    /**
     * Menu déroulant de l'en-tête, sur mobile uniquement.
     *
     * Les deux liens tenaient auparavant sur une seconde ligne pleine largeur.
     * Ça marchait, mais ça poussait tout le contenu vers le bas d'une hauteur de
     * ligne entière — coûteux sur un écran où le portail est consulté pour
     * moitié. Un menu replié rend cette hauteur au contenu.
     */
    @track menuOuvert = false;
    /**
     * Retour VOLONTAIRE au formulaire depuis l'accueil verrouillé.
     *
     * Sans cet indicateur, le contrat en attente afficherait toujours l'accueil
     * inerte et le bouton « je modifie mes informations » n'aurait nulle part où
     * mener. Il ne survit pas au rechargement : la vérité reste le statut en base.
     */
    @track retourFormulaire = false;

    token = null;
    // Le wire CurrentPageReference se redeclenche a chaque changement d'URL —
    // or on REECRIT l'URL juste apres avoir lu le token. Sans ce garde-fou, le
    // nettoyage relancerait le wire, donc un second appel Apex a chaque entree.
    accesVerifie = false;

    @wire(CurrentPageReference)
    wiredPageRef(pageRef) {
        // AVANT le garde-fou : le mode test doit pouvoir être posé ou retiré à
        // tout moment en ajoutant ?c__test= à l'adresse courante, pas seulement
        // au premier chargement. La méthode ne touche à l'URL que si le
        // paramètre est présent, elle ne peut donc pas boucler sur le wire.
        this.resoudreModeTest(pageRef?.state?.c__test);

        if (this.accesVerifie) {
            return;
        }

        const tokenUrl = pageRef?.state?.c__code;

        if (tokenUrl) {
            this.token = tokenUrl;
            this.stockerToken(tokenUrl);
            this.nettoyerUrl();
        } else {
            this.token = this.lireToken();
        }

        // Vue demandée dans l'URL : on ne retient qu'une valeur connue. Un
        // paramètre fantaisiste ne doit pas laisser le portail sur un écran vide.
        const vueUrl = pageRef?.state?.c__view;
        if (vueUrl && VUES_VALIDES.includes(vueUrl)) {
            this.vue = vueUrl;
        }

        this.accesVerifie = true;

        if (!this.token) {
            // Le Generateur d'experience ne transmet aucun parametre d'URL :
            // sans ce cas, l'apercu afficherait toujours « Session expirée » et
            // laisserait croire a une regression du portail publie.
            if (estModeGenerateur()) {
                this.afficherErreur(CLE_GENERATEUR);
                return;
            }
            this.afficherErreur('TOKEN_MANQUANT');
            return;
        }

        this.verifierAcces();
    }

    verifierAcces() {
        this.isLoading = true;
        getPrevisiteurByToken({ campaignToken: this.token })
            .then(res => {
                if (res?.statut === 'OK') {
                    this.previsiteur = res.previsiteur;
                    this.hasError = false;
                    this.isLoading = false;
                    return;
                }
                // Acces refuse : on purge le token pour qu'un rafraichissement
                // ne rejoue pas indefiniment un lien revoque ou perime.
                this.effacerToken();
                // Statut inconnu du serveur : on retombe sur l'écran technique
                // plutôt que d'afficher une carte vide.
                const cle = CLES_ERREUR.includes(res?.statut) ? res.statut : CLE_TECHNIQUE;
                this.afficherErreur(cle);
            })
            .catch(error => {
                // Erreur reseau ou Apex : le token n'est PAS efface — il est
                // probablement valide, c'est le service qui a echoue.
                console.error('Verification acces Previsites echouee :', error);
                this.afficherErreur(CLE_TECHNIQUE);
            });
    }

    afficherErreur(cle) {
        this.cleErreur = cle;
        this.hasError = true;
        this.previsiteur = null;
        this.isLoading = false;
    }

    // --- Stockage du token -------------------------------------------------
    // Chaque acces est protege : localStorage leve en navigation privee sur
    // certains navigateurs, et l'exception y ferait echouer tout le rendu.

    stockerToken(valeur) {
        try {
            localStorage.setItem(CLE_TOKEN, valeur);
        } catch (e) {
            // Stockage indisponible : la session ne survivra pas au rafraichissement,
            // mais la navigation en cours reste fonctionnelle (this.token est en memoire).
            console.warn('localStorage indisponible, token non persiste.');
        }
    }

    lireToken() {
        try {
            return localStorage.getItem(CLE_TOKEN);
        } catch (e) {
            return null;
        }
    }

    effacerToken() {
        try {
            // removeItem et non clear() : le portail ne doit pas detruire les
            // cles des autres composants ou de l'autre portail.
            localStorage.removeItem(CLE_TOKEN);
        } catch (e) {
            // ignore
        }
    }

    nettoyerUrl() {
        try {
            const url = new URL(window.location.href);
            url.searchParams.delete('c__code');
            window.history.replaceState(null, '', url.toString());
        } catch (e) {
            console.warn('Nettoyage de URL impossible.');
        }
    }

    /* --- Mode test ---------------------------------------------------------- */

    /**
     * Applique ?c__test= s'il est present, sinon reprend la valeur memorisee.
     *
     * Un parametre PRESENT fait autorite et ECRASE le stockage, y compris pour
     * l'eteindre : c'est ce qui permet de sortir du mode test par
     * ?c__test=false, sans avoir a vider le stockage du navigateur.
     */
    resoudreModeTest(valeurUrl) {
        if (valeurUrl === undefined || valeurUrl === null || valeurUrl === '') {
            this.modeTest = this.lireModeTest();
            return;
        }

        // Tout ce qui n'est pas explicitement vrai eteint le mode : une faute de
        // frappe ne doit pas activer un mode reserve aux essais.
        const actif = String(valeurUrl).trim().toLowerCase() === 'true';
        this.modeTest = actif;

        try {
            localStorage.setItem(CLE_TEST, actif ? 'true' : 'false');
        } catch (e) {
            // Stockage indisponible : le mode tient pour la session en cours.
        }
        this.retirerParametreTest();
    }

    lireModeTest() {
        try {
            return localStorage.getItem(CLE_TEST) === 'true';
        } catch (e) {
            return false;
        }
    }

    /** Retire c__test de l'URL, pour qu'une adresse copiee ne le propage pas. */
    retirerParametreTest() {
        try {
            const url = new URL(window.location.href);
            url.searchParams.delete('c__test');
            window.history.replaceState(null, '', url.toString());
        } catch (e) {
            // ignore
        }
    }

    // --- Getters d'affichage ----------------------------------------------

    get accesAccorde() {
        return !!this.previsiteur && !this.hasError && !this.isLoading;
    }

    /* --- Aiguillage sur le contrat ----------------------------------------
       Tant que le contrat n'est pas signé, le portail n'affiche QUE l'écran de
       contrat : le pré-visiteur ne peut rien faire d'autre avant d'être engagé.

       Le statut vient de LC027_GestionPrevisites, lu à l'entrée avec le reste de
       la campagne — pas d'appel serveur supplémentaire pour cette décision. */

    get contratSigne() {
        return this.previsiteur?.StatutContrat__c === STATUT_SIGNE;
    }

    /** Contrat parti chez Yousign, pas encore signé. */
    get contratEnAttente() {
        return this.previsiteur?.StatutContrat__c === STATUT_ATTENTE_SIGNATURE;
    }

    /**
     * Formulaire de contrat : avant tout envoi, ou sur retour volontaire depuis
     * l'accueil verrouillé. Jamais une fois le contrat signé.
     */
    get afficherContrat() {
        if (!this.accesAccorde || this.contratSigne) return false;
        return !this.contratEnAttente || this.retourFormulaire;
    }

    /**
     * Le portail s'affiche dès que le contrat est PARTI, pas seulement une fois
     * signé — verrouillé dans l'intervalle. Le prévisiteur voit ainsi ce qui
     * l'attend au lieu de rester devant un formulaire figé.
     */
    get afficherPortail() {
        return this.accesAccorde && !this.afficherContrat;
    }

    /**
     * Le contrat vient d'être signé dans l'écran fils. On relit l'accès plutôt
     * que de basculer sur une valeur locale : la signature est appliquée par le
     * webhook Yousign, côté serveur, et c'est la base qui fait foi.
     */
    handleContratSigne() {
        this.accesVerifie = true;
        this.retourFormulaire = false;
        this.verifierAcces();
    }

    /**
     * Le contrat vient de partir en signature. On relit l'accès plutôt que de
     * poser le statut localement : la source de vérité reste la base, et le
     * même chemin sert au retour du webhook.
     *
     * `retourFormulaire` est remis à faux, sinon un prévisiteur qui vient de
     * corriger ses informations resterait sur le formulaire après le renvoi.
     */
    handleContratEnvoye() {
        this.retourFormulaire = false;
        this.accesVerifie = true;
        this.verifierAcces();
    }

    /** L'accueil verrouillé demande à corriger la saisie : on rouvre le formulaire. */
    handleModifierInfos() {
        this.retourFormulaire = true;
    }

    get nomPrevisiteur() {
        return this.previsiteur?.Name || '';
    }

    /** Date de signature du contrat, relayée à la facturation. */
    get dateSignature() {
        return this.previsiteur?.YS_Date_Signature__c || null;
    }

    /* Identité contractuelle relayée à l'encart de la facturation. Chaque valeur
       peut être vide — un autónomo n'a pas de dénomination sociale — et l'encart
       masque alors la ligne plutôt que d'afficher un tiret. */

    get societe() {
        return this.previsiteur?.NomSociete__c || null;
    }

    get nif() {
        return this.previsiteur?.Contrat_NIF__c || null;
    }

    /** Email destinataire du contrat, cité dans le message d'attente. */
    get emailPrevisiteur() {
        return this.previsiteur?.Email__c || null;
    }

    get activite() {
        return this.previsiteur?.Contrat_Profession__c || null;
    }

    /* --- Navigation --------------------------------------------------------
       Le menu n'existe QUE le contrat signé : avant, le portail ne doit offrir
       aucune autre destination que l'écran de contrat (voir afficherContrat). */

    get afficherNav() {
        return this.afficherPortail;
    }

    /* --- Rôle ---------------------------------------------------------------
       Un seul site, deux métiers. Le rôle (Campaign.Role__c, contrôlé par
       LC027_GestionPrevisites) choisit le libellé du premier lien de menu et
       les composants rendus ; l'accès, le contrat et la navigation restent
       communs. Tout rôle autre qu'Installateur retombe sur le prévisiteur :
       le serveur a déjà refusé ceux qui n'appartiennent pas au portail. */

    get estInstallateur() {
        return this.previsiteur?.Role__c === ROLE_INSTALLATEUR;
    }

    /** Vue d'activité du rôle : « installations » ou « previsites ». */
    get vueActivite() {
        return this.estInstallateur ? VUE_INSTALLATIONS : VUE_PREVISITES;
    }

    get libelleNavActivite() {
        return this.estInstallateur ? this.txt.navInstallations : this.txt.navPrevisites;
    }

    /**
     * Vue d'activité affichée — quel que soit le rôle.
     *
     * Repli par défaut : tout ce qui n'est pas une facturation ouverte montre
     * l'activité. Un ?c__view=previsites conservé dans un favori d'installateur
     * (ou l'inverse) ne doit pas laisser un écran vide.
     */
    get vueActiviteAffichee() {
        return this.afficherPortail
            && (this.vue !== VUE_FACTURATION || this.facturationBloquee);
    }

    get vuePrevisites() {
        return this.vueActiviteAffichee && !this.estInstallateur;
    }

    get vueInstallations() {
        return this.vueActiviteAffichee && this.estInstallateur;
    }

    get vueFacturation() {
        return this.afficherPortail && this.vue === VUE_FACTURATION && !this.facturationBloquee;
    }

    get vueFacturationPrevisiteur() {
        return this.vueFacturation && !this.estInstallateur;
    }

    get vueFacturationInstallateur() {
        return this.vueFacturation && this.estInstallateur;
    }

    get classeNavActivite() {
        return this.vueActiviteAffichee ? 'nav-lien actif' : 'nav-lien';
    }

    /**
     * La facturation n'ouvre qu'une fois le contrat signé : avant, il n'y a
     * aucune prestation à facturer, et l'encart y affiche une date de signature
     * qui n'existe pas encore.
     */
    get facturationBloquee() {
        return !this.contratSigne;
    }

    get classeNavFacturation() {
        if (this.facturationBloquee) return 'nav-lien bloque';
        return this.vue === VUE_FACTURATION ? 'nav-lien actif' : 'nav-lien';
    }

    get titreNavFacturation() {
        return this.facturationBloquee ? this.txt.navBloquee : this.txt.navFacturation;
    }

    handleNav(event) {
        event.preventDefault();
        const vue = event.currentTarget.dataset.vue;
        if (!VUES_VALIDES.includes(vue)) return;
        // Le lien reste dans le DOM pour rester lisible, mais il n'agit pas.
        // Le menu ne se referme PAS non plus : le refermer sur un clic sans
        // effet laisserait croire que la navigation a eu lieu.
        if (vue === VUE_FACTURATION && this.facturationBloquee) return;
        this.vue = vue;
        this.menuOuvert = false;
        this.memoriserVue(vue);
    }

    /* --- Menu mobile -------------------------------------------------------- */

    handleBasculerMenu() {
        this.menuOuvert = !this.menuOuvert;
    }

    get classeNav() {
        return this.menuOuvert ? 'nav nav-ouvert' : 'nav';
    }

    get classeBoutonMenu() {
        return this.menuOuvert ? 'menu-bouton ouvert' : 'menu-bouton';
    }

    /**
     * Reporte la vue dans l'URL, sans recharger la page. Un rafraîchissement
     * ramène ainsi le prévisiteur là où il était, au lieu de le renvoyer
     * systématiquement sur les prévisites.
     */
    memoriserVue(vue) {
        try {
            const url = new URL(window.location.href);
            url.searchParams.set('c__view', vue);
            window.history.replaceState(null, '', url.toString());
        } catch (e) {
            // URL non manipulable : la navigation reste fonctionnelle en mémoire.
        }
    }

    /* --- Langue d'affichage -----------------------------------------------
       Espagnol par défaut, bascule toujours offerte : le portail s'adresse à des
       techniciens espagnols, le français n'est qu'un confort de lecture.

       ⚠️ NE PILOTE PAS la langue de la signature. Le contrat part en espagnol
       quelle que soit la langue à l'écran (contratConfig.CONTRAT_SIGNATURE) :
       l'affichage s'adresse au LECTEUR, le contrat ENGAGE. Un technicien qui
       bascule en français pour se relire ne doit pas recevoir — ni signer — un
       contrat dans une autre langue que celle qui fait foi. */

    /** Étiquettes de l'en-tête et des écrans d'état, dans la langue courante. */
    get txt() {
        return etiquettes('entete', this.langue);
    }

    get errorTitle() {
        return this.cleErreur ? this.txt[this.cleErreur + '_titre'] : '';
    }

    get errorMessage() {
        return this.cleErreur ? this.txt[this.cleErreur + '_message'] : '';
    }

    /**
     * La bascule de langue n'apparait QU'EN MODE TEST.
     *
     * Le portail ne s'adresse aujourd'hui qu'a des techniciens espagnols : leur
     * offrir un basculement vers le francais n'a pas d'usage, et un ecran passe
     * en francais par curiosite se lit mal ensuite. La traduction reste
     * entierement en place, seul son declencheur est masque.
     */
    get afficherBasculeLangue() {
        return this.modeTest;
    }

    /** Code de la langue vers laquelle le bouton bascule — c'est ce qu'il affiche. */
    get langueBascule() {
        return autreLangue(this.langue);
    }

    get libelleBascule() {
        return this.langueBascule === FR ? 'FR' : 'ES';
    }

    get estEspagnol() {
        return this.langue === ES;
    }

    handleBasculerLangue() {
        this.langue = ecrireLangue(autreLangue(this.langue));
    }

    /** Relaye aux futures vues : le token sert a chaque appel serveur. */
    get tokenCourant() {
        return this.token;
    }
}