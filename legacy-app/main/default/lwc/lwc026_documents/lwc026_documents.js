import { LightningElement, api, track } from 'lwc';
import { FR, etiquettes, remplir } from 'c/lwc000_i18n';
import { PRODUCT_CATALOG } from 'c/lwc000_utils';

import getDocuments from '@salesforce/apex/LC026_Documents.getDocuments';
import ajouterDocument from '@salesforce/apex/LC026_Documents.ajouterDocument';
import supprimerDocument from '@salesforce/apex/LC026_Documents.supprimerDocument';
import getContenu from '@salesforce/apex/LC026_Documents.getContenu';

/**
 * Clé localStorage du token de campagne — IDENTIQUE à lwc020_reporting_v2 et à
 * lwc021_devis_signature. Ne pas la changer sans changer les autres : c'est le
 * même token qui circule dans tout le portail « Campagnes ».
 */
const TOKEN_STORAGE_KEY = 'renov_campaign_token';

/**
 * Code de la fiche dont les documents sont TYPÉS (une zone de dépôt par type de
 * photo, fichiers renommés). Partout ailleurs il n'y a qu'une zone et les noms
 * d'origine sont conservés.
 */
const CODE_RES060 = 'RES060';

/**
 * Sections de photos, clé technique -> clé de libellé dans dicoNouveauRdv.
 * Recopié à l'identique de lwc020_NouveauRdv : ces deux composants alimentent
 * les MÊMES pièces jointes, avec les mêmes noms.
 */
const LIBELLE_SECTION_PHOTO = {
    cadastrale: 'photoCadastrale',
    facade: 'photoFacade',
    chaudiere: 'photoChaudiere',
    contratEnergie: 'photoContratEnergie',
    complementaires: 'photoComplementaires'
};

/** Clé de la zone unique, hors fiche RES060. */
const SECTION_GENERIQUE = 'autres';

/**
 * Réglages de compression, repris tels quels de lwc020_NouveauRdv : les photos
 * jointes depuis le reporting doivent peser comme celles jointes à la création
 * du RDV, sinon les pièces d'une même Piste n'auraient pas le même poids.
 */
const TAILLE_MAX_FICHIER = 3000000;

/**
 * lwc026_documents — modale « Documents » d'une Piste ou d'un Dossier.
 *
 * AUTONOME : elle ne reçoit que le recordId (et, facultativement, le token de
 * campagne et la langue). Elle identifie seule le type d'enregistrement, charge
 * ses données et décide de ce qui est permis. Aucune logique documentaire ne
 * vit dans le composant appelant.
 *
 *   • Piste (Lead)    → consultation, ajout ET suppression ;
 *   • Dossier (Pro__c)→ consultation seule.
 *
 * Le verrou n'est pas ici mais dans LC026_Documents : `modifiable` ne sert qu'à
 * masquer les boutons.
 *
 * FICHE RES060 : les pièces sont typées (Photo cadastrale, Photo de façade,
 * Photo chaudière, Contrat d'énergie, Photos complémentaires) et renommées
 * « <préfixe> <n> », comme dans lwc020_NouveauRdv. La numérotation REPREND
 * après les pièces déjà présentes du même type, pour ne pas créer deux
 * « Photo cadastrale 1 ».
 */
export default class Lwc026_Documents extends LightningElement {

    /* ════════════════════════════════════════════════════════════════════════
       ENTRÉES
       ════════════════════════════════════════════════════════════════════════ */

    _recordId;
    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(valeur) {
        this._recordId = valeur;
        // Le setter peut arriver AVANT connectedCallback quand le parent pose
        // l'attribut au moment du rendu : on ne charge que si l'on est monté.
        if (this._monte && valeur) this.charger();
    }

    _campaignCode;
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

    _langue = FR;
    @api
    get langue() {
        return this._langue;
    }
    set langue(valeur) {
        this._langue = valeur || FR;
    }

    /* ════════════════════════════════════════════════════════════════════════
       ÉTAT
       ════════════════════════════════════════════════════════════════════════ */

    @track data = null;
    isLoading = true;

    /**
     * Deux erreurs, et non une seule : `erreurChargement` REMPLACE le contenu de
     * la modale (il n'y a rien à montrer), tandis que `error` s'affiche EN PLUS
     * de la liste. Les confondre faisait disparaître les documents déjà chargés
     * dès qu'un envoi échouait.
     */
    erreurChargement = null;
    error = null;

    /** Document dont la suppression attend confirmation ; null = aucune. */
    @track aSupprimer = null;

    /** Id du document en cours d'ouverture, pour le spinner de la ligne. */
    ouvertureEnCours = null;

    /**
     * Filet de sécurité : n'apparaît que si l'ouverture de l'onglet a REELLEMENT
     * échoué (voir _ouvrirOnglet). Le document est alors déjà chargé, il ne
     * manque qu'un clic de l'utilisateur sur un vrai lien.
     */
    @track lienSecours = null;

    /** URLs blob: à révoquer à la fermeture — sinon les fichiers restent en RAM. */
    _urlsBlob = [];

    /** blob: déjà fabriqué, par Id de document : un document n'est chargé qu'une fois. */
    _urlsParDocument = {};

    /** Accordéon d'ajout : FERMÉ par défaut, la consultation prime. */
    accordeonOuvert = false;

    enEnvoi = false;
    messageEnvoi = '';
    messageSucces = '';

    /** Nombre de fichiers en attente par section, pour le bouton « Envoyer ». */
    @track fichiersEnAttente = {};

    _monte = false;
    _focusPose = false;

    connectedCallback() {
        this._monte = true;
        if (this._recordId) this.charger();
    }

    renderedCallback() {
        // Sans ce focus, la touche Échap ne parvient au gestionnaire qu'après un
        // premier clic dans la modale.
        if (!this._focusPose) {
            const voile = this.template.querySelector('.doc-voile');
            if (voile) {
                voile.focus();
                this._focusPose = true;
            }
        }
    }

    /* ════════════════════════════════════════════════════════════════════════
       LIBELLÉS
       ════════════════════════════════════════════════════════════════════════ */

    get txt() {
        return etiquettes('documents', this._langue);
    }

    /**
     * Libellés de la fiche RES060 (sections de photos et PRÉFIXES de nommage),
     * lus dans le dictionnaire de lwc020_NouveauRdv et non recopiés : le nom
     * enregistré dans Salesforce doit être le même des deux côtés.
     */
    get txtRdv() {
        return etiquettes('nouveauRdv', this._langue);
    }

    get titre() {
        const base = this.txt.titre;
        const nom = this.data && this.data.titre;
        return nom ? `${base} — ${nom}` : base;
    }

    get sousTitre() {
        if (!this.data) return '';
        const type = this.data.objectType === 'Lead' ? this.txt.typePiste : this.txt.typeDossier;
        const n = this.nombreDocuments;
        const compte = n === 1 ? this.txt.unDocument : remplir(this.txt.nDocuments, { n });
        return `${type} · ${compte}`;
    }

    /* ════════════════════════════════════════════════════════════════════════
       CHARGEMENT
       ════════════════════════════════════════════════════════════════════════ */

    charger() {
        this.isLoading = true;
        this.erreurChargement = null;
        this.error = null;
        return getDocuments({ recordId: this._recordId, campaignCode: this.campaignCode })
            .then(resultat => {
                this.data = resultat;
                this.isLoading = false;
            })
            .catch(e => {
                this.data = null;
                this.erreurChargement = this._messageErreur(e, this.txt.errChargement);
                this.isLoading = false;
            });
    }

    /* ════════════════════════════════════════════════════════════════════════
       AFFICHAGE
       ════════════════════════════════════════════════════════════════════════ */

    get afficherContenu() {
        return !this.isLoading && !this.erreurChargement && !!this.data;
    }

    get peutModifier() {
        return !!(this.data && this.data.modifiable);
    }

    get lectureSeule() {
        return !!(this.data && !this.data.modifiable);
    }

    get nombreDocuments() {
        return this.data && this.data.documents ? this.data.documents.length : 0;
    }

    get aDocuments() {
        return this.nombreDocuments > 0;
    }

    /** Une ligne par pièce jointe, prête pour le template. */
    get documents() {
        if (!this.data || !this.data.documents) return [];
        return this.data.documents.map(doc => ({
            ...doc,
            tailleLisible: this._formaterTaille(doc.taille),
            // Majuscule sans point : « PDF », « JPG » — la pastille est étroite.
            extensionCourte: (doc.extension || '').toUpperCase(),
            enCours: this.ouvertureEnCours === doc.contentDocumentId,
            // Un fichier trop lourd pour un appel Apex reste listé, mais son nom
            // n'est plus cliquable : mieux vaut le dire que d'échouer au clic.
            nomClass: doc.consultable ? 'doc-nom' : 'doc-nom doc-nom--inerte',
            titreInfobulle: doc.consultable ? this.txt.ouvrir : this.txt.tropVolumineux
        }));
    }

    /* ── Zones de dépôt ────────────────────────────────────────────────────── */

    /**
     * Une section par type de photo sur la fiche RES060, une seule zone sinon.
     * Les clés viennent du catalogue produits (c/lwc000_utils) : ajouter un type
     * de photo à la fiche l'ajoute ici sans toucher à ce composant.
     */
    get sections() {
        const t = this.txt;
        if (!this.data || !this.data.estRes060) {
            return [{ cle: SECTION_GENERIQUE, label: t.zoneGenerique, prefixe: null }];
        }
        const tRdv = this.txtRdv;
        return this._clesPhotosRes060().map(cle => ({
            cle,
            label: tRdv[LIBELLE_SECTION_PHOTO[cle]] || cle,
            prefixe: tRdv['prefixePhoto_' + cle] || cle
        }));
    }

    /** Clés de sections de photos de la fiche RES060, depuis le catalogue. */
    _clesPhotosRes060() {
        const produits = (PRODUCT_CATALOG && PRODUCT_CATALOG.produits) || [];
        const fiche = produits.find(
            p =>
                p.codeProduit &&
                p.codeProduit.indexOf(CODE_RES060) >= 0 &&
                Array.isArray(p.photosFiche)
        );
        // Repli : si la fiche disparaissait du catalogue, la modale doit encore
        // permettre de joindre un document plutôt que de n'afficher aucune zone.
        return fiche ? fiche.photosFiche : Object.keys(LIBELLE_SECTION_PHOTO);
    }

    /** Texte d'aide sous les zones : le renommage doit être annoncé. */
    get consigneNommage() {
        return this.data && this.data.estRes060
            ? this.txt.nommageAutomatique
            : this.txt.nommageOrigine;
    }

    get accordeonClass() {
        return this.accordeonOuvert ? 'doc-accordeon doc-accordeon--ouvert' : 'doc-accordeon';
    }

    get nbFichiersEnAttente() {
        return Object.keys(this.fichiersEnAttente).reduce(
            (total, cle) => total + (this.fichiersEnAttente[cle] || 0),
            0
        );
    }

    get envoiImpossible() {
        return this.enEnvoi || this.nbFichiersEnAttente === 0;
    }

    get libelleEnvoyer() {
        return this.enEnvoi ? this.txt.btnEnvoiEnCours : this.txt.btnEnvoyer;
    }

    /* ════════════════════════════════════════════════════════════════════════
       ACTIONS
       ════════════════════════════════════════════════════════════════════════ */

    handleToggleAccordeon() {
        this.accordeonOuvert = !this.accordeonOuvert;
    }

    /** Compte les fichiers sélectionnés dans une zone, pour activer « Envoyer ». */
    handleFichiersChange(event) {
        const cle = event.target.dataset.section;
        if (!cle) return;
        const n = (event.detail && event.detail.count) || 0;
        this.fichiersEnAttente = { ...this.fichiersEnAttente, [cle]: n };
        this.messageSucces = '';
    }

    /**
     * Envoie les fichiers UN PAR UN. Grouper les base64 dans un seul appel Apex
     * saturerait la heap de 6 Mo dès quelques photos ; séquencer permet en outre
     * d'afficher une progression honnête.
     */
    async handleEnvoyer() {
        if (this.enEnvoi) return;

        const aEnvoyer = this._collecterFichiers();
        if (aEnvoyer.length === 0) {
            this.error = this.txt.errAucunFichier;
            return;
        }

        this.enEnvoi = true;
        this.error = null;
        this.messageSucces = '';
        let envoyes = 0;

        try {
            for (let i = 0; i < aEnvoyer.length; i++) {
                this.messageEnvoi = remplir(this.txt.envoiProgression, {
                    n: i + 1,
                    total: aEnvoyer.length
                });
                const fichier = aEnvoyer[i];
                // eslint-disable-next-line no-await-in-loop
                const resultat = await ajouterDocument({
                    recordId: this._recordId,
                    campaignCode: this.campaignCode,
                    nomFichier: fichier.nomFinal,
                    base64: fichier.base64,
                    contentType: fichier.contentType
                });
                // Chaque appel renvoie l'état complet : la liste reste juste même
                // si l'envoi s'interrompt au milieu.
                this.data = resultat;
                envoyes++;
            }

            this._viderZones();
            this.messageSucces = remplir(this.txt.succesEnvoi, { n: envoyes });
            this._notifierParent();
        } catch (e) {
            this.error = this._messageErreur(e, this.txt.errEnvoi);
            // Les fichiers déjà partis sont bien enregistrés : on rafraîchit pour
            // que la liste montre exactement ce qui est arrivé.
            if (envoyes > 0) this._notifierParent();
        } finally {
            this.enEnvoi = false;
            this.messageEnvoi = '';
        }
    }

    /**
     * Rassemble les fichiers de toutes les zones et calcule leur nom DÉFINITIF.
     *
     * Fiche RES060 : « <préfixe> <n>.ext », la numérotation reprenant après les
     * photos déjà attachées du même type. Ailleurs : nom d'origine inchangé.
     */
    _collecterFichiers() {
        const fichiers = [];
        this.sections.forEach(section => {
            const zone = this.template.querySelector(
                `c-custom-file-upload[data-section="${section.cle}"]`
            );
            if (!zone || !zone.hasFile()) return;

            const donnees = zone.getFileData();
            const liste = Array.isArray(donnees) ? donnees : [donnees];
            let index = section.prefixe ? this._prochainIndex(section.prefixe) : 0;

            liste.filter(Boolean).forEach(f => {
                const nomFinal = section.prefixe
                    ? this._nommerPhoto(section.prefixe, index++, f.fileName)
                    : f.fileName;
                fichiers.push({
                    nomFinal,
                    base64: f.base64,
                    contentType: f.contentType
                });
            });
        });
        return fichiers;
    }

    /**
     * Numéro à donner à la prochaine photo d'un type : le plus grand déjà
     * utilisé, plus un. Sans cela, un second envoi recréerait « Photo cadastrale
     * 1 » à côté de la première.
     */
    _prochainIndex(prefixe) {
        const echappe = prefixe.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
        const motif = new RegExp('^' + echappe + '\\s+(\\d+)\\b', 'i');
        let max = 0;
        ((this.data && this.data.documents) || []).forEach(doc => {
            const trouve = motif.exec(doc.titre || '');
            if (trouve) max = Math.max(max, parseInt(trouve[1], 10) || 0);
        });
        return max + 1;
    }

    /**
     * « Photo cadastrale » + 2 + « photo.jpg » -> « Photo cadastrale 2.jpg ».
     * Identique à lwc020_NouveauRdv._nommerPhoto : l'extension d'origine est
     * conservée pour que Salesforce affiche la bonne icône.
     */
    _nommerPhoto(prefixe, index, nomOriginal) {
        const nom = nomOriginal || '';
        const pos = nom.lastIndexOf('.');
        const extension = pos > 0 ? nom.substring(pos) : '';
        return `${prefixe} ${index}${extension}`;
    }

    _viderZones() {
        this.template.querySelectorAll('c-custom-file-upload').forEach(zone => zone.reset());
        this.fichiersEnAttente = {};
    }

    /* ── Consultation ──────────────────────────────────────────────────────── */

    /**
     * Ouvre un document dans un nouvel onglet.
     *
     * POURQUOI PAS UN SIMPLE LIEN VERS LE FICHIER. Le servlet de fichiers de
     * Salesforce (/sfc/servlet.shepherd/...) s'appuie sur le PARTAGE du
     * document. Ici le droit vient du token de campagne, pas d'un partage : pour
     * un utilisateur du portail, ce lien ne renvoie pas le fichier mais un
     * script de redirection vers errorduringprocessing.jsp. Les octets remontent
     * donc par l'Apex et le navigateur les affiche depuis un blob: local — même
     * solution que lwc021_devis_signature pour le contrat.
     *
     * POURQUOI PAS window.open. Sous Lightning Web Security, window.open ouvre
     * bien l'onglet mais renvoie TOUJOURS null : impossible d'y poser une URL
     * ensuite, et impossible de distinguer un succès d'un blocage. Pré-ouvrir
     * l'onglet avant l'appel serveur laissait donc un about:blank orphelin ET
     * affichait à tort le lien de secours. Un <a target="_blank"> cliqué
     * programmatiquement, lui, ouvre le blob: sans détour.
     *
     * Le fichier n'est demandé au serveur QU'UNE FOIS : le blob: est mémorisé,
     * un second clic sur la même ligne est instantané.
     */
    async handleOuvrir(event) {
        const contentDocumentId = event.currentTarget.dataset.docid;
        const consultable = event.currentTarget.dataset.consultable === 'true';
        if (!contentDocumentId || this.ouvertureEnCours) return;
        if (!consultable) {
            this.error = this.txt.tropVolumineux;
            return;
        }

        this.error = null;
        this.messageSucces = '';
        this.lienSecours = null;

        const titre = this._titreDe(contentDocumentId);
        let url = this._urlsParDocument[contentDocumentId];

        if (!url) {
            this.ouvertureEnCours = contentDocumentId;
            try {
                const contenu = await getContenu({
                    recordId: this._recordId,
                    campaignCode: this.campaignCode,
                    contentDocumentId
                });
                url = this._urlBlob(contenu);
                this._urlsParDocument[contentDocumentId] = url;
            } catch (e) {
                this.error = this._messageErreur(e, this.txt.errOuverture);
                return;
            } finally {
                this.ouvertureEnCours = null;
            }
        }

        this._ouvrirOnglet(url, titre);
    }

    /**
     * Ouvre une URL dans un onglet via un <a> temporaire.
     *
     * Le lien est posé DANS le template du composant : un élément détaché du
     * document n'est pas cliquable de façon fiable. Le navigateur garde
     * l'autorisation d'ouvrir un onglet pendant quelques secondes après le clic
     * de l'utilisateur, ce qui couvre largement l'appel Apex qui précède.
     */
    _ouvrirOnglet(url, titre) {
        try {
            const hote = this.template.querySelector('.doc-corps');
            if (!hote) throw new Error('Conteneur de la modale introuvable.');
            const lien = document.createElement('a');
            lien.href = url;
            lien.target = '_blank';
            lien.rel = 'noopener noreferrer';
            lien.style.display = 'none';
            hote.appendChild(lien);
            lien.click();
            hote.removeChild(lien);
        } catch (e) {
            // Filet de sécurité : le document est prêt, il ne manque qu'un vrai
            // clic de l'utilisateur. N'apparaît que si l'ouverture a réellement
            // échoué, jamais « au cas où ».
            this.lienSecours = { url, titre };
        }
    }

    /** Titre d'une pièce jointe, pour le lien de secours. */
    _titreDe(contentDocumentId) {
        const doc = ((this.data && this.data.documents) || []).find(
            d => d.contentDocumentId === contentDocumentId
        );
        return doc ? doc.titre : '';
    }

    /** base64 -> blob: local, mémorisé pour être révoqué à la fermeture. */
    _urlBlob(contenu) {
        const binaire = atob(contenu.base64);
        const octets = new Uint8Array(binaire.length);
        for (let i = 0; i < binaire.length; i++) {
            octets[i] = binaire.charCodeAt(i);
        }
        const url = URL.createObjectURL(
            new Blob([octets], { type: contenu.contentType || 'application/octet-stream' })
        );
        this._urlsBlob.push(url);
        return url;
    }

    handleFermerSecours() {
        this.lienSecours = null;
    }

    /* ── Suppression ───────────────────────────────────────────────────────── */

    /**
     * Premier clic sur la corbeille : on DEMANDE, on ne supprime pas. La
     * confirmation est rendue dans la modale et non par window.confirm, dont le
     * comportement n'est pas garanti sous Lightning Web Security — et qui, sur
     * mobile, s'affiche hors du contexte de la ligne concernée.
     */
    handleDemanderSuppression(event) {
        const contentDocumentId = event.currentTarget.dataset.docid;
        const nom = event.currentTarget.dataset.nom;
        if (!contentDocumentId || this.enEnvoi) return;
        this.error = null;
        this.messageSucces = '';
        this.aSupprimer = { contentDocumentId, nom };
    }

    handleAnnulerSuppression() {
        this.aSupprimer = null;
    }

    /** Message de confirmation, avec le nom du fichier inséré au bon endroit. */
    get messageConfirmation() {
        if (!this.aSupprimer) return '';
        return remplir(this.txt.confirmerSuppression, { nom: this.aSupprimer.nom });
    }

    handleConfirmerSuppression() {
        if (!this.aSupprimer || this.enEnvoi) return;
        const contentDocumentId = this.aSupprimer.contentDocumentId;
        this.aSupprimer = null;

        this.enEnvoi = true;
        this.error = null;
        this.messageSucces = '';
        supprimerDocument({
            recordId: this._recordId,
            campaignCode: this.campaignCode,
            contentDocumentId
        })
            .then(resultat => {
                this.data = resultat;
                this.messageSucces = this.txt.succesSuppression;
                this._notifierParent();
            })
            .catch(e => {
                this.error = this._messageErreur(e, this.txt.errSuppression);
            })
            .finally(() => {
                this.enEnvoi = false;
            });
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

    /** Un blob: non révoqué retient tout le fichier en mémoire. */
    disconnectedCallback() {
        this._urlsBlob.forEach(url => {
            try {
                URL.revokeObjectURL(url);
            } catch (e) {
                // Rien à faire : l'URL était déjà libérée.
            }
        });
        this._urlsBlob = [];
        this._urlsParDocument = {};
    }

    /**
     * Prévient l'appelant que le NOMBRE de documents a changé, pour qu'il
     * rafraîchisse sa pastille sans recharger tout son tableau.
     */
    _notifierParent() {
        this.dispatchEvent(
            new CustomEvent('documentschange', {
                detail: { recordId: this._recordId, nombre: this.nombreDocuments }
            })
        );
    }

    /* ════════════════════════════════════════════════════════════════════════
       OUTILS
       ════════════════════════════════════════════════════════════════════════ */

    /** Taille max par fichier, exposée au template pour c/customFileUpload. */
    get tailleMaxFichier() {
        return TAILLE_MAX_FICHIER;
    }

    _formaterTaille(octets) {
        if (!octets && octets !== 0) return '';
        const t = this.txt;
        if (octets < 1024 * 1024) {
            return `${Math.max(1, Math.round(octets / 1024))} ${t.uniteKo}`;
        }
        return `${(octets / (1024 * 1024)).toFixed(1)} ${t.uniteMo}`;
    }

    /** Message d'AuraHandledException, avec repli sur un texte traduit. */
    _messageErreur(e, repli) {
        const corps = e && e.body;
        if (corps) {
            if (corps.message) return corps.message;
            if (Array.isArray(corps) && corps.length && corps[0].message) return corps[0].message;
        }
        return (e && e.message) || repli;
    }
}