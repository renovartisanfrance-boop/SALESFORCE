import { LightningElement, api, track } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import getContrat from '@salesforce/apex/LC027_GestionContrat.getContrat';
import getContratBase64 from '@salesforce/apex/LC027_GestionContrat.getContratBase64';
import enregistrerInfos from '@salesforce/apex/LC027_GestionContrat.enregistrerInfos';
import emailLibre from '@salesforce/apex/LC027_GestionContrat.emailLibre';
import envoyerEnSignature from '@salesforce/apex/LC027_GestionContrat.envoyerEnSignature';
import getContratStockeBase64 from '@salesforce/apex/LC027_GestionContrat.getContratStockeBase64';
import getSignatureEconaturaBase64 from '@salesforce/apex/LC027_GestionContrat.getSignatureEconaturaBase64';
import pdfLib from '@salesforce/resourceUrl/pdfLib';
import { etiquettes } from 'c/lwc027_i18n';
import {
    STATUT_ATTENTE_SIGNATURE,
    STATUT_SIGNE,
    champsFormulaire,
    lignesRecap,
    DEFINITIONS_CHAMPS,
    PDF_PAGE_IDENTITE,
    PDF_X_VALEUR,
    PDF_LIGNES,
    PDF_TAILLE_POLICE,
    PDF_COULEUR_TEXTE,
    SIGNATURE_ECONATURA,
    valeurLigne,
    SEPARATEUR_MULTI,
    reglagesContrat,
    base64VersOctets,
    octetsVersBase64
} from './contratConfig';

/**
 * Ré-exporté pour le conteneur : contratConfig.js vit DANS ce bundle et n'est
 * donc pas importable de l'extérieur (seul le fichier principal l'est). Sans
 * cette ligne, lwc027_previsite_container devrait recopier la valeur de picklist
 * « Signe », et les deux finiraient par diverger.
 */
export { STATUT_SIGNE, STATUT_ATTENTE_SIGNATURE } from './contratConfig';

/**
 * Ré-exporté pour lwc027_facturation_previsiteur, qui ouvre lui aussi le contrat
 * dans un onglet et a donc besoin de reconstruire un blob depuis du base64.
 * Dupliquer la fonction dans l'autre bundle aurait fait diverger deux
 * conversions d'octets — le genre d'écart qui ne se voit que sur un PDF corrompu.
 */
export { base64VersOctets } from './contratConfig';

/**
 * Ré-exportés pour le conteneur, qui choisit les écrans du portail selon le
 * rôle : une seule définition côté client, alignée sur LC027_Roles côté Apex.
 */
export { ROLE_PREVISITEUR, ROLE_INSTALLATEUR } from './contratConfig';

/**
 * Ré-exporté pour l'accueil verrouillé (lwc027_gestion_previsite /
 * lwc027_gestion_installations), qui récapitule les informations envoyées.
 */
export { lignesRecap } from './contratConfig';

/**
 * lwc027_gestion_contrat — contrat de collaboration du pré-visiteur.
 *
 * DEUX ÉCRANS, pilotés par Campaign.StatutContrat__c :
 *   • « En cours de generation » — saisie des informations, puis envoi en signature ;
 *   • « Attente signature »      — rappel du contrat parti, informations corrigeables.
 * Le troisième état (« Signe ») ne s'affiche PAS ici : le conteneur bascule
 * alors sur lwc027_gestion_previsite.
 *
 * Toute la configuration (champs, coordonnées de dessin, réglages Yousign) vit
 * dans contratConfig.js — voir son en-tête avant toute modification.
 */
export default class Lwc027GestionContrat extends LightningElement {
    /** Token de campagne, relayé par le conteneur. Sert à CHAQUE appel serveur. */
    @api token;
    /**
     * Langue d'AFFICHAGE, pilotée par la bascule du conteneur.
     * ⚠️ Sans effet sur la langue de SIGNATURE : reglagesContrat() impose
     * l'espagnol, seule langue qui fait foi pour le contrat.
     */
    @api langue;
    /**
     * Ouverture DIRECTE en modification, posée par le conteneur quand
     * l'intervenant vient de cliquer « Je modifie mes informations
     * personnelles ». Sans effet hors statut « Attente signature ».
     */
    @api editionDirecte = false;

    @track statut;
    @track donnees = {};
    @track messageErreur;
    @track isLoading = true;
    @track enCours = false;
    @track messageEcran;
    @track typeMessage = 'info';
    /** Un contrat est archivé : le lien de consultation a un sens. */
    @track documentDisponible = false;
    /**
     * Rôle de la campagne, fourni par l'Apex (source de vérité). Il compose le
     * formulaire via contratConfig.champsFormulaire(). Vide tant que l'état
     * n'est pas chargé : le formulaire est alors vide, jamais celui d'un autre rôle.
     */
    @track role = null;
    /**
     * Le rôle a-t-il un contrat à signer ? Faux pour l'installateur tant que son
     * PDF n'est pas livré : la saisie reste possible, l'envoi est retenu.
     */
    @track contratDisponible = true;
    /** Campaign.Pays__c — certains champs ne s'affichent que pour un pays. */
    @track pays = null;
    /**
     * URL blob: du contrat archivé, posée sur un vrai lien <a>.
     *
     * ⚠️ PAS DE window.open() — c'est ce qui empêchait l'ouverture. Une fenêtre
     * ouverte par script hérite de la CSP du site, qui refuse blob: ; et les
     * navigateurs la traitent en popup. Le portail Campagnes charge le document
     * EN AMONT et rend un <a href={urlPdf} target="_blank"> : le clic devient
     * une navigation native, que rien ne bloque. Même procédé ici.
     */
    @track urlPdf = null;
    /**
     * Déverrouillage EXPLICITE de l'écran d'attente.
     *
     * Le contrat est parti chez Yousign : ses champs sont verrouillés par défaut,
     * pour que personne ne les modifie en croyant corriger le document déjà
     * envoyé — il ne bougerait pas. Corriger impose de REGÉNÉRER puis de
     * renvoyer, d'où un geste volontaire avant toute saisie.
     */
    @track modeEdition = false;
    /**
     * Étape de RELECTURE, entre la saisie et l'envoi.
     *
     * Le contrat engage : le prévisiteur voit ses valeurs telles qu'elles seront
     * imprimées avant de déclencher quoi que ce soit. Une faute de NIF repérée
     * ici coûte un clic ; repérée après signature, elle coûte tout le cycle.
     */
    @track etapeRecap = false;

    pdfLibCharge = false;

    connectedCallback() {
        this.charger();
    }

    charger() {
        this.isLoading = true;
        getContrat({ campaignToken: this.token })
            .then((etat) => {
                this.statut = etat.statut;
                this.donnees = { ...(etat.donnees || {}) };
                this.messageErreur = etat.messageErreur;
                this.documentDisponible = etat.documentDisponible === true;
                this.role = etat.role || null;
                this.contratDisponible = etat.contratDisponible !== false;
                this.pays = etat.pays || null;
                // Arrivée par « Je modifie mes informations personnelles » :
                // l'intervenant a DÉJÀ exprimé sa demande sur l'accueil, on ne
                // la lui fait pas reconfirmer — champs directement modifiables.
                if (this.editionDirecte && etat.statut === STATUT_ATTENTE_SIGNATURE) {
                    this.handleDemanderModification();
                }
                this.isLoading = false;
                if (this.documentDisponible) {
                    this.chargerContrat();
                }
            })
            .catch((e) => {
                this.isLoading = false;
                this.afficher(this.messageDe(e), 'error');
            });
    }

    /* ── Écrans ─────────────────────────────────────────────────────────── */

    /**
     * Écran de saisie — défini par DÉFAUT et non sur la seule valeur
     * « En cours de generation ».
     *
     * StatutContrat__c est VIDE sur toute campagne pré-visiteur créée avant
     * l'arrivée du champ, ou par un autre chemin que PrevisiteController. Tester
     * l'égalité stricte laissait ces campagnes sur une carte entièrement vide :
     * ni saisie, ni attente, aucun message. Un statut inconnu doit mener au
     * formulaire, qui est l'état de départ du contrat.
     */
    get ecranSaisie() {
        return !this.isLoading
            && !this.etapeRecap
            && this.statut !== STATUT_ATTENTE_SIGNATURE
            && this.statut !== STATUT_SIGNE;
    }

    /** Relecture : mêmes valeurs, en lecture, avant confirmation. */
    get ecranRecap() {
        return !this.isLoading && this.etapeRecap;
    }

    /** Valeurs à relire, libellées et sans les champs vides. */
    get recapLignes() {
        // Construction partagée avec l'accueil verrouillé : voir lignesRecap().
        return lignesRecap(this.role, this.donnees, this.txt, this.pays);
    }

    get ecranAttente() {
        return !this.isLoading && this.statut === STATUT_ATTENTE_SIGNATURE;
    }

    /**
     * Contrat SIGNÉ : tout est verrouillé.
     *
     * Le conteneur ne rend normalement plus ce composant à ce stade — il bascule
     * sur le portail. C'est donc une défense en profondeur, pour le jour où
     * l'écran serait rendu autrement (lien direct, évolution de l'aiguillage).
     * L'Apex refuse déjà l'écriture d'un contrat signé ; l'interface dit
     * maintenant la même chose, au lieu d'offrir des champs qui échoueraient.
     */
    get ecranSigne() {
        return !this.isLoading && this.statut === STATUT_SIGNE;
    }

    /**
     * Aucune saisie possible : contrat signé (définitif), traitement en cours,
     * ou contrat en attente de signature pas encore déverrouillé.
     */
    get lectureSeule() {
        return this.ecranSigne
            || this.enCours
            || (this.ecranAttente && !this.modeEdition);
    }

    /** Le bouton de déverrouillage : sur l'écran d'attente, avant tout geste. */
    get afficherBoutonModifier() {
        return this.ecranAttente && !this.modeEdition;
    }

    /**
     * Bouton d'action principal : saisie initiale, ou renvoi après
     * déverrouillage. Jamais sur un contrat signé.
     */
    /**
     * Relecture sans contrat disponible : on n'offre PAS le bouton d'envoi, qui
     * échouerait côté serveur. Un message dit pourquoi, au lieu d'un bouton mort.
     */
    get envoiRetenu() {
        return this.ecranRecap && !this.contratDisponible;
    }

    get afficherAction() {
        return this.ecranSaisie
            || (this.ecranRecap && !this.envoiRetenu)
            || (this.ecranAttente && this.modeEdition);
    }

    /** L'action du bouton principal dépend de l'étape. */
    handleActionPrincipale() {
        if (this.ecranSaisie) {
            return this.handleContinuer();
        }
        return this.handleSignerAction();
    }

    /** Étiquettes de l'écran, dans la langue courante. */
    get txt() {
        return etiquettes('contrat', this.langue);
    }

    /**
     * Champs du formulaire, enrichis de leur valeur courante.
     * Construit ici et non dans le template : LWC ne sait pas indexer un objet
     * par une expression dans le HTML.
     */
    get champs() {
        return champsFormulaire(this.role, this.pays).map((c) => ({
            ...c,
            // Libellé pris dans le dictionnaire, indexé par nom d'API. Le `label`
            // espagnol de contratConfig sert de repli : un champ ajouté à la
            // config sans sa clé de traduction reste lisible au lieu d'être vide.
            label: this.txt['champ_' + c.champ] || c.label,
            valeur: this.donnees[c.champ] || '',
            // La pleine largeur est DECLAREE dans la configuration, plus deduite
            // d'un nom de champ en dur : le composant n'a pas a savoir lesquels
            // debordent, c'est une propriete de la mise en page du formulaire.
            classeCase: c.pleineLargeur ? 'pleine-largeur' : '',
            desactive: this.lectureSeule,
            estPicklist: c.type === 'picklist',
            estBadges: c.type === 'badges',
            estTexte: c.type !== 'picklist' && c.type !== 'badges',
            // Compteur sous les badges : sur 27 provinces, savoir combien sont
            // retenues évite de faire défiler la liste pour le vérifier.
            compteur: c.type === 'badges'
                ? (this.txt.badgesSelectionnes || '{n}')
                    .replace('{n}', this.valeursMulti(c.champ).length)
                : '',
            options: (c.options || []).map((o) => {
                // Une multipicklist stocke « Burgos;Madrid » : on teste
                // l'appartenance, pas l'égalité, sinon aucun badge ne serait
                // jamais sélectionné.
                const selectionne = c.type === 'badges'
                    ? this.valeursMulti(c.champ).includes(o.valeur)
                    : this.donnees[c.champ] === o.valeur;
                return {
                    ...o,
                    cle: c.champ + '_' + o.valeur,
                    selectionne,
                    // Classe calculée ici plutôt qu'en CSS par :has(input:checked) :
                    // un navigateur sans :has() n'afficherait AUCUN état, et le
                    // formulaire deviendrait illisible sans que rien ne le signale.
                    classe: selectionne ? 'badge badge-on' : 'badge'
                };
            })
        }));
    }

    /**
     * Fil d'étapes. Les trois étapes sont les trois valeurs de
     * StatutContrat__c — le prévisiteur suit donc son avancement RÉEL, pas une
     * progression décorative. La troisième (« Acceso ») n'est jamais « on » ici :
     * quand elle est atteinte, le conteneur a déjà basculé sur le portail.
     */
    get etapes() {
        // Signé : la 3e étape est atteinte. Sinon attente = 2e, saisie = 1re.
        const courante = this.ecranSigne ? 2 : (this.ecranAttente ? 1 : 0);
        return ['etape1', 'etape2', 'etape3'].map((cle, i) => ({
            cle,
            label: this.txt[cle],
            classe: i < courante ? 's done' : (i === courante ? 's on' : 's')
        }));
    }

    get libelleBouton() {
        if (this.ecranRecap) return this.txt.boutonSigner;
        return this.ecranAttente ? this.txt.boutonRelancer : this.txt.boutonContinuer;
    }

    /**
     * Saisie validée : on passe à la relecture, sans rien envoyer encore.
     *
     * L'EMAIL EST CONTRÔLÉ ICI, et pas seulement à l'envoi : il identifie la
     * personne dans tout le dispositif (destinataire Yousign, login Certiko),
     * et l'apprendre au clic sur « Signer » obligerait à revenir sur un
     * formulaire déjà relu. L'Apex refuse de toute façon le doublon — ce
     * contrôle-ci sert le confort, pas la sécurité.
     */
    async handleContinuer() {
        const manquants = this.champsManquants();
        if (manquants.length) {
            this.afficher(this.txt.manquants + manquants.join(', '), 'error');
            return;
        }

        this.enCours = true;
        try {
            const libre = await emailLibre({
                campaignToken: this.token,
                email: this.donnees.Email__c
            });
            if (!libre) {
                this.afficher(this.txt.emailPris, 'error');
                return;
            }
        } catch (e) {
            // Serveur injoignable : on arrête là. Laisser passer n'avancerait à
            // rien — l'enregistrement de l'étape suivante échouerait pareil, et
            // sur un écran où la saisie n'est plus sous les yeux.
            this.afficher(this.messageDe(e), 'error');
            return;
        } finally {
            this.enCours = false;
        }

        this.messageEcran = null;
        this.etapeRecap = true;
    }

    /** Retour à la saisie depuis la relecture. */
    handleRetourSaisie() {
        this.etapeRecap = false;
        this.messageEcran = null;
    }

    /** Déverrouille la saisie et prévient de ce que le renvoi implique. */
    handleDemanderModification() {
        this.modeEdition = true;
        this.afficher(this.txt.avertissementRelance, 'info');
    }

    /* ── Saisie ─────────────────────────────────────────────────────────── */

    handleChange(event) {
        const champ = event.target.dataset.champ;
        if (champ) {
            this.donnees = { ...this.donnees, [champ]: event.target.value };
        }
    }

    /** Valeurs d'une multipicklist, sous forme de tableau. */
    valeursMulti(champ) {
        const brut = this.donnees[champ];
        return brut ? String(brut).split(SEPARATEUR_MULTI).filter((v) => v) : [];
    }

    /**
     * Sélectionne ou retire un badge (une valeur de multipicklist).
     *
     * L'ORDRE DES VALEURS EST CELUI DE LA CONFIGURATION, pas celui des clics :
     * une chaîne « D1;A;C » et une chaîne « A;C;D1 » désignent la même chose pour
     * Salesforce, mais diffèrent à la relecture et dans les rapports. On
     * reconstruit donc la liste depuis les options déclarées.
     */
    handleBadge(event) {
        const champ = event.target.dataset.champ;
        const valeur = event.target.dataset.valeur;
        if (!champ || !valeur) return;

        const coche = new Set(this.valeursMulti(champ));
        if (event.target.checked) {
            coche.add(valeur);
        } else {
            coche.delete(valeur);
        }

        const def = DEFINITIONS_CHAMPS.find((c) => c.champ === champ);
        const ordonnees = (def?.options || [])
            .map((o) => o.valeur)
            .filter((v) => coche.has(v));

        this.donnees = { ...this.donnees, [champ]: ordonnees.join(SEPARATEUR_MULTI) };
    }

    /**
     * Libellés des champs obligatoires non renseignés, vide si tout est rempli.
     * Les libellés sont pris TRADUITS : citer le nom espagnol d'un champ affiché
     * en français rendrait le message inutilisable pour le retrouver à l'écran.
     */
    champsManquants() {
        return champsFormulaire(this.role, this.pays)
            .filter((c) => c.requis && !String(this.donnees[c.champ] || '').trim())
            .map((c) => this.txt['champ_' + c.champ] || c.label);
    }

    /* ── Actions ────────────────────────────────────────────────────────── */

    /**
     * Écran de saisie : enregistrer PUIS envoyer en signature.
     *
     * L'enregistrement précède volontairement l'envoi : si l'appel Yousign
     * échoue, la saisie n'est pas perdue et le prévisiteur retrouve son
     * formulaire rempli au rechargement.
     */
    async handleSignerAction() {
        const manquants = this.champsManquants();
        if (manquants.length) {
            this.afficher(this.txt.manquants + manquants.join(', '), 'error');
            return;
        }

        this.enCours = true;
        try {
            await enregistrerInfos({
                campaignToken: this.token,
                donneesJson: JSON.stringify(this.donnees)
            });

            const pdfRempli = await this.construirePdf();

            const etat = await envoyerEnSignature({
                campaignToken: this.token,
                pdfBase64: pdfRempli,
                // Réglages OBLIGATOIRES côté Apex : sans eux l'envoi est refusé,
                // plutôt que de retomber sur une position de signature périmée.
                reglagesJson: JSON.stringify(reglagesContrat())
            });
            this.appliquerEtat(etat);
            // Le déverrouillage ne survit pas au renvoi : le nouveau contrat est
            // parti, on repart d'un écran verrouillé.
            this.modeEdition = false;
            this.etapeRecap = false;
            this.afficher(this.txt.envoye, 'success');
        } catch (e) {
            this.afficher(this.messageDe(e), 'error');
        } finally {
            this.enCours = false;
        }
    }

    /**
     * Charge le contrat archivé et prépare son lien d'ouverture.
     *
     * Appelé au chargement de l'écran, PAS au clic : le lien doit déjà porter
     * son URL quand l'utilisateur clique, sinon on retombe sur une ouverture
     * par script — que la CSP du site refuse.
     *
     * Un échec COUPE le lien plutôt que de le laisser vide : mieux vaut aucun
     * lien qu'un lien mort.
     */
    async chargerContrat() {
        try {
            const base64 = await getContratStockeBase64({ campaignToken: this.token });
            this.libererBlob();
            this.urlPdf = URL.createObjectURL(
                new Blob([base64VersOctets(base64)], { type: 'application/pdf' })
            );
        } catch (e) {
            console.error('Contrat archivé illisible :', e);
            this.libererBlob();
            this.urlPdf = null;
            this.documentDisponible = false;
        }
    }

    /** Un blob: non révoqué retient tout le PDF en mémoire jusqu'à la fermeture. */
    libererBlob() {
        if (this.urlPdf && this.urlPdf.indexOf('blob:') === 0) {
            URL.revokeObjectURL(this.urlPdf);
        }
        this.urlPdf = null;
    }

    disconnectedCallback() {
        this.libererBlob();
    }

    /* ── PDF ────────────────────────────────────────────────────────────── */

    /**
     * Écrit les valeurs saisies sur le contrat vierge et rend le PDF en base64.
     *
     * Le contrat est un PDF PLAT, sans champ AcroForm : les valeurs sont
     * DESSINÉES aux coordonnées de contratConfig.PDF_LIGNES.
     *
     * ⚠️ Les octets viennent de l'Apex, JAMAIS d'un fetch() de la Static
     * Resource : dans un site LWR, Lightning Web Security bloque tout fetch vers
     * /webruntime/org-asset/... loadScript, lui, passe — d'où pdf-lib chargé
     * ainsi et le contrat livré en base64.
     */
    async construirePdf() {
        if (!this.pdfLibCharge) {
            await loadScript(this, pdfLib);
            this.pdfLibCharge = true;
        }
        const PDFLib = window.PDFLib;
        if (!PDFLib) {
            throw new Error(this.txt.pdfLibKo);
        }

        const base64 = await getContratBase64({ campaignToken: this.token });
        const doc = await PDFLib.PDFDocument.load(base64VersOctets(base64));
        const police = await doc.embedFont(PDFLib.StandardFonts.Helvetica);
        const page = doc.getPages()[PDF_PAGE_IDENTITE];

        const couleur = PDFLib.rgb(
            PDF_COULEUR_TEXTE.r, PDF_COULEUR_TEXTE.g, PDF_COULEUR_TEXTE.b
        );

        Object.keys(PDF_LIGNES).forEach((cle) => {
            const texte = valeurLigne(cle, this.donnees);
            if (!texte) return;
            page.drawText(String(texte), {
                x: PDF_X_VALEUR,
                y: PDF_LIGNES[cle],
                size: PDF_TAILLE_POLICE,
                font: police,
                color: couleur
            });
        });

        await this.apposerSignatureEconatura(doc, PDFLib);

        return octetsVersBase64(await doc.save());
    }

    /**
     * Appose la signature ECONATURA sur la DERNIÈRE page, colonne « POR ECONATURA ».
     *
     * Yousign ne sait pas pré-signer un document au nom de l'émetteur : une
     * demande de signature s'adresse à des signataires, qui doivent tous agir.
     * Le paraphe de la société est donc dessiné ici, avant l'envoi, pour que le
     * technicien reçoive un contrat déjà signé côté ECONATURA.
     *
     * ⚠️ C'est un FAC-SIMILÉ, pas une signature électronique : il n'a pas la
     * valeur probante de la signature Yousign du technicien.
     *
     * Ne lève JAMAIS : une signature absente ou illisible ne doit pas empêcher
     * l'envoi du contrat.
     */
    async apposerSignatureEconatura(doc, PDFLib) {
        try {
            const base64 = await getSignatureEconaturaBase64({ campaignToken: this.token });
            if (!base64) return;

            const octets = base64VersOctets(base64);
            const image = await doc.embedJpg(octets);
            const pages = doc.getPages();
            const page = pages[SIGNATURE_ECONATURA.page];
            if (!page) return;

            // scaleToFit préserve le rapport 656x382 : la bande disponible est
            // plus contraignante en hauteur qu'en largeur.
            const taille = image.scaleToFit(
                SIGNATURE_ECONATURA.largeurMax, SIGNATURE_ECONATURA.hauteurMax);

            page.drawImage(image, {
                x: SIGNATURE_ECONATURA.x,
                y: SIGNATURE_ECONATURA.y,
                width: taille.width,
                height: taille.height
            });
        } catch (e) {
            console.warn('Signature ECONATURA non apposee :', e);
        }
    }

    /* ── Utilitaires ────────────────────────────────────────────────────── */

    appliquerEtat(etat) {
        if (!etat) return;
        this.statut = etat.statut;
        this.donnees = { ...(etat.donnees || {}) };
        this.messageErreur = etat.messageErreur;
        this.documentDisponible = etat.documentDisponible === true;
        this.role = etat.role || this.role;
        this.pays = etat.pays || this.pays;
        this.contratDisponible = etat.contratDisponible !== false;
        // Le conteneur garde SA propre copie du statut, lue à l'entrée du
        // portail : sans ces événements, il continuerait d'afficher le
        // formulaire alors que le contrat vient de partir. C'est ce qui obligeait
        // à rafraîchir la page pour voir l'écran d'attente.
        if (etat.statut === STATUT_SIGNE) {
            this.dispatchEvent(new CustomEvent('contratsigne'));
        } else if (etat.statut === STATUT_ATTENTE_SIGNATURE) {
            this.dispatchEvent(new CustomEvent('contratenvoye'));
        }
    }

    afficher(message, type) {
        this.messageEcran = message;
        this.typeMessage = type || 'info';
    }

    get classeMessage() {
        return 'message message-' + this.typeMessage;
    }

    /** Déballe le message d'une AuraHandledException, sinon rend un texte lisible. */
    messageDe(erreur) {
        return erreur?.body?.message
            || erreur?.message
            || this.txt.erreurGenerique;
    }
}