import { LightningElement, api, track, wire } from 'lwc';
import getCampaignByToken from '@salesforce/apex/LC020_GestionCampagnes.getCampaignByToken';
import apiEndpoint from '@salesforce/label/c.GESTION_RDV_EXTERNE_API_ENDPOINT';
// Catalogue produits partagé (source unique) — voir c/lwc000_utils
import { PRODUCT_CATALOG, RT_RES, filtrerProduitsParPays, estModeGenerateur } from 'c/lwc000_utils';
// Traduction FR/ES partagée — voir c/lwc000_i18n
import {
    FR, lireLangue, etiquettes, remplir, localeDe, nombreDecimal,
    traduireProduit, traduireTypeProduit, traduirePicklist
} from 'c/lwc000_i18n';
import createLead from '@salesforce/apex/LC020_GestionCampagnes.createLead';
import getFieldsMetadata from '@salesforce/apex/LC020_FieldMetadataService.getFieldsMetadata';
// import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import Toast from 'lightning/toast';

import cdc_CDC00 from '@salesforce/resourceUrl/CDC_0'; // Replace 'sample' with your static resource name
import cdc_CDC01 from '@salesforce/resourceUrl/CDC_0'; // Replace 'sample' with your static resource name


// INFO_PRODUITS will be built at runtime from the campaign field
const INFO_PRODUITS = {};

/**
 * Plafond de taille cumulée des pièces jointes, en octets.
 *
 * Pourquoi 3 Mo et non 4,2 : tout le contenu part en base64 dans UN SEUL appel
 * Apex synchrone, dont la heap est limitée à 6 Mo. Le base64 gonfle les données
 * de ×1,33, et LC020_GestionCampagnes.createLead fait un
 * JSON.deserializeUntyped(filesDataJson) qui garde une seconde copie de toutes
 * les chaînes en mémoire. Le pic réel est donc de l'ordre de 2,7 × la taille
 * brute : au-delà de ~3 Mo on frôle la limite, et l'erreur Apex qui en résulte
 * est brutale et illisible pour le partenaire.
 *
 * Ce plafond n'est plus contraignant en pratique : les photos sont
 * redimensionnées à 1600 px / JPEG q=0,72 par c/customFileUpload avant envoi,
 * soit ~150 à 350 Ko pièce — une dizaine de photos tiennent largement.
 */
const TAILLE_MAX_PIECES_JOINTES = 3000000;

// Sections de photos de la fiche : clé technique -> clé de libellé i18n.
/**
 * Champ « Suivi Signature » de la fiche RES060 (groupe 'signature' du catalogue).
 * Sa valeur conditionne le bloc date/créneau de rappel : on ne planifie un rappel
 * que si RENOV gère la signature. Sinon c'est le partenaire qui la gère, il n'y a
 * rien à rappeler et les deux champs disparaissent.
 *
 * La valeur ci-dessous est recopiée A L'IDENTIQUE de la picklist de l'org, faute
 * d'accent comprise (« gére ») : si quelqu'un corrige la valeur côté Salesforce,
 * il faut la corriger ici dans la foulée, sinon le bloc rappel ne s'afficherait
 * plus jamais.
 */
const API_SUIVI_SIGNATURE = 'Suivi_Signature__c';
const SUIVI_SIGNATURE_AVEC_RAPPEL = 'On gére la signature + Confirmation (Tx Conversion+)';

const LIBELLE_SECTION_PHOTO = {
    cadastrale: 'photoCadastrale',
    facade: 'photoFacade',
    chaudiere: 'photoChaudiere',
    complementaires: 'photoComplementaires'
};

export default class Lwc020_NouveauRdv extends LightningElement {

    apiEndpoint = apiEndpoint;

    CDC_0 = cdc_CDC00;
    CDC_1 = cdc_CDC01;
    CDC_2 = cdc_CDC01;
    CDC_3 = cdc_CDC01;
    CDC_4 = cdc_CDC01;
    CDC_5 = cdc_CDC01;
    
    _campaignCode;
    @api
    get campaignCode() {
        if (this._campaignCode) return this._campaignCode;
        try { return localStorage.getItem('renov_campaign_token'); } catch (e) { return null; }
    }
    set campaignCode(value) {
        this._campaignCode = value;
    }

    @api products = [];

    // Accès réduit : masque l'upload de documents et impose une case de certification
    // (validation front uniquement — NON stockée dans Salesforce).
    @api accesReduit = false;

    // Accès réduit : type de PAC pré-sélectionné par le bouton « Recommander un contact »
    // cliqué dans le Cahier des charges (Air/Eau ou Air/Air). Renseigne TypePompeChaleur__c
    // sur le Lead à la soumission — aucun champ n'est affiché sur le formulaire.
    @api typePompeChaleur = null;

    // Langue d'affichage, poussée par lwc020_CampagneContainer.
    // Repli défensif : si le parent ne la passe pas, on la redérive du pays de
    // la campagne (français tant que la campagne n'est pas chargée).
    _langue = FR;
    @api
    get langue() {
        return this._langue;
    }
    set langue(valeur) {
        this._langue = valeur || lireLangue(this.campaign?.Pays__c);
    }

    // Étiquettes résolues. Getter et non champ stocké : etiquettes() est mémoïsée,
    // donc chaque rendu ne coûte qu'une lecture de Map.
    get txt() {
        return etiquettes('nouveauRdv', this._langue);
    }

    @track certificationAccord = false;

    @track campaign = null;
    @track infoProduits = null;
    @track isLoading = true;
    @track isSavingLead = false;
    @track showSuccessAnimation = false;
    @track hasError = false;
    @track errorMessage = '';
    @track productsCollapsed = false;
    @track selectedProductType = null;
    @track selectedProducts = []; // stores codeProduit values for multi-picklist TypeDeDossier__c
    @track selectedTypeEnregistrement = null; // enforce single type across selections

    @track formData = {
        nomDirigeant: '',
        firstName: '',
        lastName: '',
        email: '',
        phone: '',
        company: '',
        adresseComplete: '',
        dateRappel: '',
        creneauRappel: '',
        commentaire: '',
        typeEnregistrement: null,
        // Accès réduit (partenaires) : section « Informations d'appel » (facultatifs)
        Apporteur_Presentation__c: '',
        Apporteur_ClientPrevenuAppel__c: '',
        Apporteur_ClientInformeRAC__c: ''
    };

    @track contactInfo = {
        name: '',
        email: '',
        phone: ''
    };

    // Dynamic fields retrieved from Apex based on selected products
    @track dynamicFields = [];

    // Picklist values for créneau de rappel
    @track creneauPicklistValues = [];

    // Accès réduit : valeurs de picklist des 2 champs « apporteur » (chargées depuis l'org)
    @track apporteurPrevenuOptions = [];
    @track apporteurRacOptions = [];

    // --- Champs propres à la fiche produit (ex. RES060 Espagne) --------------
    // On ne stocke ici QUE les métadonnées de l'org (type, valeurs de picklist).
    // Les libellés et placeholders sont résolus dans les getters à partir du
    // dictionnaire : ils suivent donc la langue sans rechargement.
    @track champsFicheMeta = [];

    // Produit sélectionné qui porte des champs de fiche (le premier trouvé).
    get _ficheAvecChamps() {
        const codes = this.selectedProducts || [];
        return (this.produits || []).find(
            p => codes.includes(p.codeProduit) && Array.isArray(p.champsFiche) && p.champsFiche.length > 0
        );
    }

    // Produit sélectionné qui porte des sections de photos.
    get _ficheAvecPhotos() {
        const codes = this.selectedProducts || [];
        return (this.produits || []).find(
            p => codes.includes(p.codeProduit) && Array.isArray(p.photosFiche) && p.photosFiche.length > 0
        );
    }

    /** Transforme une métadonnée brute en modèle prêt pour le template. */
    _modeleChampFiche(meta) {
        const t = this.txt;
        const cle = 'df_' + meta.apiName;
        const valeur = this.formData[meta.apiName] || '';
        return {
            apiName: meta.apiName,
            // Le libellé de l'org est technique (« RES- Shab ») : on ne l'affiche
            // jamais. Repli sur l'apiName seulement si la clé manque au dictionnaire.
            label: t[cle] || meta.apiName,
            placeholder: t[cle + 'Ph'] || '',
            isPicklist: meta.isPicklist,
            isInput: meta.isInput,
            renderType: meta.renderType,
            maxlength: meta.length || null,
            // Bornes de saisie — voir handleLimiteChiffres. `max` et `step` sont
            // posés en plus du contrôle JS : ils règlent le clavier mobile et la
            // validation native, mais n'empêchent pas de TAPER trop de chiffres.
            entiers: meta.entiers || null,
            decimales: meta.decimales || null,
            max: meta.entiers ? Number('9'.repeat(meta.entiers)) : null,
            step: meta.decimales ? Number('0.' + '0'.repeat(meta.decimales - 1) + '1') : null,
            currentValue: valeur,
            // LWC n'accepte pas value= sur <select> : l'état sélectionné se porte
            // sur les <option>, sinon le choix serait perdu à chaque re-rendu
            // (notamment au changement de langue).
            aucunSelectionne: valeur === '',
            picklistValues: (meta.picklistValues || []).map(o => ({
                value: o.value,
                label: traduirePicklist(o.value, o.label, this._langue),
                selected: o.value === valeur
            }))
        };
    }

    /**
     * Borne le nombre de chiffres saisis dans un champ de fiche numérique.
     *
     * `maxlength` est SANS EFFET sur un <input type="number"> — d'où cette
     * troncature à la frappe. Les bornes viennent du catalogue produit
     * (`entiers` / `decimales` de champsFiche) et transitent par data-*.
     *
     * Sur un champ number, `value` vaut '' tant que la saisie n'est pas un
     * nombre valide (« 123. » en cours de frappe) : on ne touche à rien dans ce
     * cas, l'utilisateur est en train de taper.
     */
    handleLimiteChiffres(event) {
        const el = event.currentTarget;
        const maxEntiers = Number(el.dataset.entiers) || 0;
        if (!maxEntiers) return;

        const maxDecimales = Number(el.dataset.decimales) || 0;
        const brut = String(el.value == null ? '' : el.value);
        if (brut === '') return;

        const negatif = brut.startsWith('-');
        const [entiers, decimales] = brut.replace('-', '').split('.');
        const entiersCoupes = entiers.slice(0, maxEntiers);
        const decimalesCoupees =
            decimales === undefined ? undefined : decimales.slice(0, maxDecimales);

        let corrige = entiersCoupes;
        if (maxDecimales > 0 && decimalesCoupees !== undefined && decimalesCoupees !== '') {
            corrige += '.' + decimalesCoupees;
        }
        if (negatif) corrige = '-' + corrige;

        // Réécrire à l'identique replacerait le curseur en fin de champ.
        if (corrige !== brut) {
            el.value = corrige;
            this.formData[el.dataset.field] = corrige;
        }
    }

    // Champs affichés juste sous l'adresse (zone climatique, référence cadastrale).
    get champsFicheAdresse() {
        return this.champsFicheMeta.filter(m => m.groupe === 'adresse').map(m => this._modeleChampFiche(m));
    }

    // Champs de la section « Le logement ».
    get champsFicheLogement() {
        return this.champsFicheMeta.filter(m => m.groupe === 'logement').map(m => this._modeleChampFiche(m));
    }

    get aChampsFicheAdresse() {
        return this.champsFicheAdresse.length > 0;
    }

    get aChampsFicheLogement() {
        return this.champsFicheLogement.length > 0;
    }

    // Champ « Suivi Signature », rendu juste avant le bloc date/créneau de rappel.
    get champsFicheSignature() {
        return this.champsFicheMeta.filter(m => m.groupe === 'signature').map(m => this._modeleChampFiche(m));
    }

    get aChampsFicheSignature() {
        return this.champsFicheSignature.length > 0;
    }

    /**
     * Le bloc date + créneau de rappel n'est demandé que si RENOV gère la signature.
     * Sans champ « signature » sur la fiche (tous les produits hors RES060), le bloc
     * reste affiché comme avant : la règle ne s'applique qu'aux fiches qui la portent.
     */
    get afficherRappel() {
        if (!this.aChampsFicheSignature) return true;
        return this.formData[API_SUIVI_SIGNATURE] === SUIVI_SIGNATURE_AVEC_RAPPEL;
    }

    // Sections de photos de la fiche (libellés traduits, préfixe de nommage figé).
    get sectionsPhotos() {
        const fiche = this._ficheAvecPhotos;
        if (!fiche) return [];
        const t = this.txt;
        return fiche.photosFiche.map(cle => ({
            cle,
            label: t[LIBELLE_SECTION_PHOTO[cle]] || cle,
            prefixe: t['prefixePhoto_' + cle] || cle
        }));
    }

    get aSectionsPhotos() {
        return this.sectionsPhotos.length > 0;
    }

    // --- Récapitulatif global des pièces jointes ----------------------------
    // Les 3 zones de dépôt sont compactes et alignées : sans ce récap, un
    // partenaire qui a scrollé ne voit plus ce qu'il a joint ni ce qui manque.
    // On ne stocke ici que {id, fileName, size} — surtout pas le base64, qui
    // resterait dupliqué en mémoire pour rien.
    @track photosParSection = {};

    handlePhotosChange(event) {
        const cle = event.target.dataset.section;
        if (!cle) return;
        const fichiers = (event.detail && event.detail.files) || [];
        this.photosParSection = {
            ...this.photosParSection,
            [cle]: fichiers.map(f => ({ id: f.id, fileName: f.fileName, size: f.size }))
        };
    }

    /** Une ligne par fichier, avec le nom DÉFINITIF tel qu'il sera enregistré. */
    get recapPieces() {
        const lignes = [];
        this.sectionsPhotos.forEach(sec => {
            (this.photosParSection[sec.cle] || []).forEach((f, i) => {
                lignes.push({
                    cleLigne: sec.cle + '|' + f.id,
                    section: sec.cle,
                    fichierId: f.id,
                    // Le partenaire voit exactement le nom qui arrivera dans
                    // Salesforce, pas le nom d'origine de son téléphone.
                    nomFinal: this._nommerPhoto(sec.prefixe, i + 1, f.fileName),
                    categorie: sec.label,
                    taille: this._formaterTaille(f.size)
                });
            });
        });
        return lignes;
    }

    get aRecapPieces() {
        return this.recapPieces.length > 0;
    }

    get nbRecapPieces() {
        return this.recapPieces.length;
    }

    get _octetsPieces() {
        return Object.keys(this.photosParSection).reduce(
            (total, cle) => total + (this.photosParSection[cle] || []).reduce((s, f) => s + (f.size || 0), 0), 0
        );
    }

    get tailleRecap() {
        return this._formaterTaille(this._octetsPieces);
    }

    get tailleMaxRecap() {
        return this._formaterTaille(TAILLE_MAX_PIECES_JOINTES);
    }

    get styleJaugeRecap() {
        const pct = Math.min(100, Math.round((this._octetsPieces / TAILLE_MAX_PIECES_JOINTES) * 100));
        return `width:${pct}%`;
    }

    get classeJaugeRecap() {
        const ratio = this._octetsPieces / TAILLE_MAX_PIECES_JOINTES;
        if (ratio > 1) return 'recap-jauge__barre recap-jauge__barre--depasse';
        if (ratio > 0.8) return 'recap-jauge__barre recap-jauge__barre--proche';
        return 'recap-jauge__barre';
    }

    /** Tailles en unités décimales (Ko/Mo, KB/MB en espagnol). */
    _formaterTaille(octets) {
        if (!octets) return '0 ' + this.txt.uniteKo;
        if (octets < 1000000) {
            return nombreDecimal(Math.round(octets / 1000), this._langue) + ' ' + this.txt.uniteKo;
        }
        return nombreDecimal((octets / 1000000).toFixed(2), this._langue) + ' ' + this.txt.uniteMo;
    }

    handleSupprimerPiece(event) {
        const section = event.currentTarget.dataset.section;
        const fichierId = event.currentTarget.dataset.fichier;
        const cmp = this.template.querySelector(`c-custom-file-upload[data-section="${section}"]`);
        // La suppression passe par l'enfant, qui réémet fileschange : le récap
        // et la numérotation des noms se recalculent tout seuls.
        if (cmp && cmp.supprimerFichier) cmp.supprimerFichier(fichierId);
    }

    // L'upload générique ne s'affiche que si la fiche n'impose pas ses propres
    // sections de photos (et jamais en accès réduit, comme aujourd'hui).
    get afficherUploadGenerique() {
        return !this.aSectionsPhotos;
    }

    // Accès réduit : les 2 questions Oui/Non présentées en toggle (segmented control).
    // Chaque option porte son état sélectionné pour la surbrillance dans le template.
    get apporteurPrevenuToggle() {
        return this._toggleOptions(this.apporteurPrevenuOptions, this.formData.Apporteur_ClientPrevenuAppel__c);
    }

    get apporteurRacToggle() {
        return this._toggleOptions(this.apporteurRacOptions, this.formData.Apporteur_ClientInformeRAC__c);
    }

    // Accès réduit : la question « reste à charge » (Apporteur_ClientInformeRAC__c) n'est
    // affichée que pour une recommandation Air/Air. Masquée pour Air/Eau.
    // typePompeChaleur provient du bouton « Recommander un contact » du Cahier des charges.
    get showApporteurRac() {
        return (this.typePompeChaleur || '').startsWith('Air/Air');
    }

    _toggleOptions(options, currentValue) {
        return (options || []).map(o => {
            const s = o.value === currentValue;
            return {
                value: o.value,
                // Les libellés viennent de l'org (toujours en français pour
                // l'utilisateur portail) : on les surcharge côté LWC.
                label: traduirePicklist(o.value, o.label, this._langue),
                selected: s,
                cardClass: s ? 'tgl-card-opt tgl-card-opt--on' : 'tgl-card-opt'
            };
        });
    }

    get hasDynamicFields() {
        return this.dynamicFields && this.dynamicFields.length > 0;
    }

    get creneauOptions() {
        return (this.creneauPicklistValues || []).map(opt => ({
            ...opt,
            label: traduirePicklist(opt.value, opt.label, this._langue)
        }));
    }

    get creneauSelectClass() {
        return this.isSavingLead
            ? 'form-input form-select form-select-readonly'
            : 'form-input form-select';
    }

    renderedCallback() {
        this._syncSelectValue('#creneauRappel', this.formData.creneauRappel);
        // Les 2 questions « apporteur » (accès réduit) sont désormais des toggles (boutons)
        // bindés via getters -> plus de <select> à resynchroniser ici.
    }

    _syncSelectValue(selector, value) {
        const el = this.template.querySelector(selector);
        const target = value || '';
        if (el && el.value !== target) {
            el.value = target;
        }
    }

    // File upload tracking
    @track uploadedFiles = [];
    @track pendingFiles = []; // Files ready to be uploaded with Lead creation

    _redirectInvalidToken() {
        // Generateur d'experience (prod ou sandbox) : la redirection vers l'app
        // externe remplacerait l'iframe d'apercu par la page de connexion et
        // masquerait toute l'interface de travail. Voir c/lwc000_utils.
        if (estModeGenerateur()) {
            console.warn('Mode Generateur : redirection vers le portail de connexion desactivee.');
            this.isLoading = false;
            this.hasError = true;
            this.errorMessage = "Apercu Generateur : aucun token de campagne, la redirection est desactivee ici. Le composant fonctionnera normalement sur le site publie.";
            return;
        }
        try { localStorage.clear(); } catch (e) { /* ignore */ }
        window.location.href = this.apiEndpoint;
    }

    connectedCallback() {
        if (this.campaignCode) {
            this.loadCampaign();
        } else {
            this._redirectInvalidToken();
            return;
        }
        this.loadInfosProduits();
        this.loadCreneauPicklistValues();
        if (this.accesReduit) {
            this.loadApporteurPicklistValues();
        }
    }

    loadCreneauPicklistValues() {
        getFieldsMetadata({ fieldApiNames: ['ENVOI_CONF_Cr_neau_de_Rappel__c'] })
            .then(result => {
                if (result && result.length > 0 && result[0].picklistValues) {
                    this.creneauPicklistValues = result[0].picklistValues;
                }
            })
            .catch(error => {
                console.error('Erreur chargement créneaux de rappel:', error);
            });
    }

    // Accès réduit : récupère les valeurs de picklist depuis l'org (évite tout codage en dur).
    loadApporteurPicklistValues() {
        getFieldsMetadata({ fieldApiNames: ['Apporteur_ClientPrevenuAppel__c', 'Apporteur_ClientInformeRAC__c'] })
            .then(result => {
                (result || []).forEach(r => {
                    if (r.apiName === 'Apporteur_ClientPrevenuAppel__c') {
                        this.apporteurPrevenuOptions = r.picklistValues || [];
                    } else if (r.apiName === 'Apporteur_ClientInformeRAC__c') {
                        this.apporteurRacOptions = r.picklistValues || [];
                    }
                });
            })
            .catch(error => {
                console.error('Erreur chargement picklists apporteur:', error);
            });
    }

    loadInfosProduits() {
        // Build infoProduits from PRODUCT_CATALOG (contains all products)
        // Actual availability is determined in populateProducts() based on campaign field
        this.infoProduits = {
            title: PRODUCT_CATALOG.title,
            subtitle: PRODUCT_CATALOG.subtitle,
            produits: PRODUCT_CATALOG.produits.map(p => ({ ...p })).sort((a, b) => a.ordreAffichage - b.ordreAffichage)
        };
        this.populateProducts();
    }

    get showFieldsPro(){
        // Afficher le champ nomDirigeant pour tous les produits autre que les produits résidentiels
        return this.selectedTypeEnregistrement != RT_RES;
    }

    populateProducts() {
        if (!this.infoProduits || !this.infoProduits.produits) {
            this.produits = [];
            return;
        }

        const campaignProducts = this.campaign && this.campaign.ProduitsDisponibles__c
            ? this.campaign.ProduitsDisponibles__c.split(';').map(p => p.trim())
            : [];

        // Filtre Pays (France / Espagne) : les produits d'un autre pays que celui de
        // la campagne sont masqués. Composant réservé à l'accès par Token (isExposed=false),
        // le pays vient donc uniquement de Campaign.Pays__c.
        const produitsPays = filtrerProduitsParPays(this.infoProduits.produits, this.campaign?.Pays__c);

            console.log('Campaign Products:', this['CDC_0']);

        this.produits = produitsPays.map((product, index) => ({
            ...product,
            downloadLink: product.cdcExiste ? this['CDC_' + index] : null,
            fileName: product.nomProduit,
            isAvailable: product.disponible && campaignProducts.includes(product.codeProduit),
            couleurStyle: product.couleurProduit ? `color: ${product.couleurProduit};` : ''
        }));

        // Si un seul produit existe, l'assigner automatiquement
        const available = this.produits?.filter(e => e.isAvailable) || [];
        if (available.length === 1) {
            const singleProduct = available[0];
            this.selectedProductType = singleProduct.typeEnregistrement;
            this.formData.typeEnregistrement = singleProduct.typeEnregistrement;
            // preselect the single available product for the multi-picklist
            this.selectedProducts = [singleProduct.codeProduit];
            this.selectedTypeEnregistrement = singleProduct.typeEnregistrement;
            // load dynamic fields for the preselected single product
            this.updateDynamicFieldsForSelectedProducts();
        }
    }

    /**
     * Fiches regroupées par typeProduit (Residentiel / Tertiaire / Agriculture).
     *
     * Remplace l'ancien filtre <select> « Type du RDV » : tous les groupes sont
     * affichés d'emblée, chacun sous son intitulé, ce qui évite au partenaire un
     * clic préalable pour découvrir les fiches disponibles.
     *
     * Les fiches d'un autre type d'enregistrement disparaissent dès qu'une
     * première fiche est cochée (règle de non-mélange portée par `disabled`) ;
     * un groupe qui se vide n'est plus rendu du tout, intitulé compris.
     */
    get groupesProduits() {
        const groupes = [];
        const parType = new Map();

        this.checkboxProducts.forEach(item => {
            if (item.disabled || !item.typeProduit) return;

            let groupe = parType.get(item.typeProduit);
            if (!groupe) {
                groupe = {
                    key: item.typeProduit,
                    // Seul le LIBELLÉ est traduit : la valeur reste française, car
                    // elle sert de clé de regroupement et transite vers Apex.
                    label: traduireTypeProduit(item.typeProduit, this._langue),
                    titreStyle: item.couleurStyle,
                    items: []
                };
                parType.set(item.typeProduit, groupe);
                groupes.push(groupe);
            }
            groupe.items.push(item);
        });

        return groupes;
    }

    get showCheckboxList() {
        return this.groupesProduits.length > 0;
    }

    // Show form only when at least one product is checked
    get showFormFields() {
        return this.selectedProducts && this.selectedProducts.length > 0;
    }

    // Getter for checkbox list (label + value + checked)
    get checkboxProducts() {
        return (this.produits || []).filter(p => p.isAvailable)?.sort((a, b) => a.ordreAffichage - b.ordreAffichage)?.map(p => {
            const disabledByType = this.selectedTypeEnregistrement ? (p.typeEnregistrement !== this.selectedTypeEnregistrement) : false;
            return {
                // traduireProduit renvoie la fiche telle quelle s'il n'y a rien à
                // traduire (produits France) — aucune copie inutile.
                label: traduireProduit(p, this._langue).nomProduit,
                value: p.codeProduit,
                typeEnregistrement: p.typeEnregistrement,
                typeProduit: p.typeProduit,
                checked: this.selectedProducts.includes(p.codeProduit),
                disabled: disabledByType,
                couleurStyle: p.couleurProduit ? `color: ${p.couleurProduit};` : '',
                checkboxStyle: p.couleurProduit ? `--checkbox-bg: ${p.couleurProduit};` : ''
            };
        });
    }

    loadCampaign() {
        this.isLoading = true;
        getCampaignByToken({ campaignToken: this.campaignCode })
            .then(data => {
                this.campaign = data;
                this.extractContactInfo();
                this.isLoading = false;
                this.hasError = false;
                this.loadInfosProduits();
            })
            .catch(error => {
                console.error('Invalid or not found campaign token, redirecting:', error);
                this._redirectInvalidToken();
            });
    }

    extractContactInfo() {
        if (this.campaign && this.campaign.Description) {
            const lines = this.campaign.Description.split('\n');
            this.contactInfo = {
                name: this.extractValue(lines, 'Contact:'),
                email: this.extractValue(lines, 'Email:'),
                phone: this.extractValue(lines, 'Téléphone:')
            };
        }
    }

    extractValue(lines, prefix) {
        const line = lines.find(l => l.includes(prefix));
        if (line) {
            return line.replace(prefix, '').trim();
        }
        return '';
    }

    handlePhoneInput(event) {
        // Phone mask: only allow digits, max 10
        let raw = event.target.value.replace(/[^\d]/g, '');
        if (raw.length > 10) {
            raw = raw.substring(0, 10);
        }
        this.formData.phone = raw;
        event.target.value = raw;
    }

    handleCertificationChange(event) {
        this.certificationAccord = event.target.checked;
    }

    // Bouton de soumission : style vert (identique à « Recommander un contact ») en accès réduit.
    get submitBtnClass() {
        return this.accesReduit ? 'btn-submit btn-submit--reco' : 'btn-submit';
    }

    handleInputChange(event) {
        const field = event.currentTarget.dataset.field;
        this.formData[field] = event.target.value;
        // keep dynamicFields in sync with current value for template rendering
        if (this.dynamicFields && this.dynamicFields.length > 0) {
            const idx = this.dynamicFields.findIndex(d => d.apiName === field);
            if (idx !== -1) {
                this.dynamicFields[idx].currentValue = event.target.value;
                this.dynamicFields = [...this.dynamicFields];
            }
        }
    }

    // Accès réduit : sélection d'une option du toggle Oui/Non (questions « apporteur »).
    // Écrit dans formData comme le faisaient les <select> -> repris tel quel à la soumission.
    handleToggleSelect(event) {
        const field = event.currentTarget.dataset.field;
        this.formData[field] = event.currentTarget.dataset.value;
    }

    /**
     * Charge les métadonnées des champs de fiche (type, valeurs de picklist).
     * Ces champs sont FACULTATIFS : ils sont volontairement tenus à l'écart de
     * this.dynamicFields, dont la validation impose que tout soit renseigné.
     */
    chargerChampsFiche() {
        const fiche = this._ficheAvecChamps;
        if (!fiche) {
            this.champsFicheMeta = [];
            return;
        }

        const groupeParApi = {};
        // Bornes de saisie déclarées au catalogue (entiers / décimales).
        const bornesParApi = {};
        fiche.champsFiche.forEach(c => {
            groupeParApi[c.apiName] = c.groupe;
            bornesParApi[c.apiName] = { entiers: c.entiers || 0, decimales: c.decimales || 0 };
        });
        const apiNames = fiche.champsFiche.map(c => c.apiName);

        getFieldsMetadata({ fieldApiNames: apiNames })
            .then(result => {
                const parApi = {};
                (result || []).forEach(r => {
                    const api = r.apiName || (r.get && r.get('apiName'));
                    if (api) parApi[api] = r;
                });

                // On boucle sur champsFiche (et non sur le résultat Apex) pour
                // garantir l'ordre d'affichage défini dans le catalogue.
                this.champsFicheMeta = apiNames
                    .filter(api => parApi[api])
                    .map(api => {
                        const r = parApi[api];
                        const dataType = r.dataType || 'string';
                        let renderType = 'text';
                        let isPicklist = false;
                        let isInput = true;

                        if (dataType === 'picklist') { isPicklist = true; isInput = false; }
                        else if (dataType === 'integer' || dataType === 'double' || dataType === 'long') { renderType = 'number'; }
                        else if (dataType === 'date') { renderType = 'date'; }

                        return {
                            apiName: api,
                            groupe: groupeParApi[api] || 'logement',
                            dataType,
                            renderType,
                            isPicklist,
                            isInput,
                            length: r.length || null,
                            entiers: (bornesParApi[api] || {}).entiers || 0,
                            decimales: (bornesParApi[api] || {}).decimales || 0,
                            picklistValues: r.picklistValues || []
                        };
                    });
            })
            .catch(error => {
                console.error('Erreur getFieldsMetadata (champs fiche):', error);
                this.champsFicheMeta = [];
            });
    }

    updateDynamicFieldsForSelectedProducts() {
        // Les champs de fiche suivent la même sélection de produits.
        this.chargerChampsFiche();

        // collect all champsDisponibles from selected products and remove duplicates
        const fieldsSet = new Set();
        (this.selectedProducts || []).forEach(code => {
            const p = (this.produits || []).find(x => x.codeProduit === code);
            if (p && Array.isArray(p.champsDisponibles)) {
                p.champsDisponibles.forEach(f => { if (f) fieldsSet.add(f.trim()); });
            }
        });

        const fieldsArray = Array.from(fieldsSet).filter(f => f && f.length > 0);
        if (fieldsArray.length === 0) {
            this.dynamicFields = [];
            return;
        }

        getFieldsMetadata({ fieldApiNames: fieldsArray })
            .then(result => {
                // augment with currentValue to support template binding
                this.dynamicFields = (result || []).map(r => {
                    const apiName = (r.apiName || (r.get ? r.get('apiName') : r.apiName));
                    const dataType = (r.dataType || (r.get && r.get('dataType')) || 'string');
                    let renderType = 'text';
                    let isPicklist = false;
                    let isTextarea = false;
                    let isInput = true;

                    if (dataType === 'picklist') { isPicklist = true; isInput = false; }
                    else if (dataType === 'textarea') { isTextarea = true; isInput = false; }
                    else if (dataType === 'email') { renderType = 'email'; }
                    else if (dataType === 'phone') { renderType = 'tel'; }
                    else if (dataType === 'integer' || dataType === 'double' || dataType === 'long') { renderType = 'number'; }
                    else if (dataType === 'date') { renderType = 'date'; }
                    else if (dataType === 'datetime') { renderType = 'datetime'; }

                    return {
                        apiName: apiName,
                        label: r.label || (r.get && r.get('label')) || apiName,
                        dataType: dataType,
                        picklistValues: r.picklistValues || [],
                        length: r.length || null,
                        currentValue: this.formData[apiName] || '',
                        renderType: renderType,
                        isPicklist: isPicklist,
                        isTextarea: isTextarea,
                        isInput: isInput
                    };
                });
            })
            .catch(error => {
                console.error('Erreur getFieldsMetadata:', error);
                this.dynamicFields = [];
            });
    }

    validateForm() {
        const t = this.txt;
        if ( this.showFieldsPro && !this.formData.nomDirigeant.trim()) {
            this.showToast(t.validation, t.errNomSociete, 'error');
            return false;
        }
        if (!this.formData.lastName.trim()) {
            this.showToast(t.validation, t.errNom, 'error');
            return false;
        }

        if (!this.formData.firstName.trim()) {
            this.showToast(t.validation, t.errPrenom, 'error');
            return false;
        }

        if (!this.formData.email.trim() || !this.isValidEmail(this.formData.email)) {
            this.showToast(t.validation, t.errEmail, 'error');
            return false;
        }
        // Format téléphone français conservé pour TOUS les pays (décision produit) :
        // seul le message est traduit, la règle ne change pas.
        if (!this.formData.phone || !/^0\d{9}$/.test(this.formData.phone)) {
            this.showToast(t.validation, t.errTelephone, 'error');
            return false;
        }
        if (!this.accesReduit && !this.formData.adresseComplete.trim()) {
            this.showToast(t.validation, t.errAdresse, 'error');
            return false;
        }
        // Date et créneau ne sont exigés que si le bloc est affiché : sur la fiche
        // RES060, « Suivi Signature » peut le masquer (voir afficherRappel).
        if (this.afficherRappel) {
            if (!this.formData.dateRappel || !this.formData.dateRappel.trim()) {
                this.showToast(t.validation, t.errDateRappel, 'error');
                return false;
            }
            if (!this.formData.creneauRappel || !this.formData.creneauRappel.trim()) {
                this.showToast(t.validation, t.errHeureRappel, 'error');
                return false;
            }
        }

        if ( this.checkboxProducts?.length > 0 && (!this.selectedProducts || this.selectedProducts.length === 0)) {
            this.showToast(t.validation, t.errProduit, 'error');
            return false;
        }

        // verifier la longueur du commentaire
        if (this.formData.commentaire && this.formData.commentaire.length > 255) {
            this.showToast(t.erreur, t.errCommentaireLong, 'error');
            return false;
        }

        // Taille cumulée de TOUTES les zones de dépôt (upload générique ou les
        // 3 sections de photos de la fiche) : le plafond porte sur le total, car
        // tout part dans un seul appel Apex. Voir TAILLE_MAX_PIECES_JOINTES.
        const zonesDepot = Array.from(this.template.querySelectorAll('c-custom-file-upload'));
        const totalOctets = zonesDepot.reduce(
            (somme, cmp) => somme + ((cmp && cmp.hasFile() && cmp.getTotalFileSize()) || 0), 0
        );
        if (totalOctets > TAILLE_MAX_PIECES_JOINTES) {
            // Mo décimaux (÷1 000 000) pour les deux valeurs : le message d'origine
            // mélangeait Mio pour la taille et Mo pour la limite.
            const sizeMB = nombreDecimal((totalOctets / 1000000).toFixed(2), this._langue);
            const maxMB = nombreDecimal((TAILLE_MAX_PIECES_JOINTES / 1000000).toFixed(0), this._langue);
            this.showToast(t.validation, remplir(t.errTailleFichiers, { taille: sizeMB, max: maxMB }), 'error');
            return false;
        }

        // Validate dynamic fields — all displayed dynamic fields are required
        if (this.dynamicFields && this.dynamicFields.length > 0) {
            for (const df of this.dynamicFields) {
                const val = this.formData[df.apiName] || df.currentValue || '';
                if (!String(val).trim()) {
                    this.showToast(t.validation, remplir(t.errChampRequis, { champ: df.label }), 'error');
                    return false;
                }
            }
        }

        // Champs propres à la fiche produit — tous obligatoires. On itère sur les
        // modèles des getters (et non sur champsFicheMeta) : eux seuls portent le
        // libellé traduit affiché à l'écran, celui qui doit apparaître dans le message.
        // Le groupe « adresse » n'est contrôlé qu'en accès complet : en accès réduit
        // toute la section adresse est masquée, on ne bloque pas sur des champs invisibles.
        // Ordre = ordre d'affichage, pour que le message pointe le premier champ
        // vide rencontré en descendant le formulaire.
        const champsFicheARemplir = [
            ...(this.accesReduit ? [] : this.champsFicheAdresse),
            ...this.champsFicheLogement,
            ...this.champsFicheSignature
        ];
        for (const cf of champsFicheARemplir) {
            const val = this.formData[cf.apiName] || cf.currentValue || '';
            if (!String(val).trim()) {
                this.showToast(t.validation, remplir(t.errChampRequis, { champ: cf.label }), 'error');
                return false;
            }
        }

        // Accès réduit : la case de certification est obligatoire (front only, non stockée).
        if (this.accesReduit && !this.certificationAccord) {
            this.showToast(t.validation, t.errCertification, 'error');
            return false;
        }

        return true;
    }

    isValidEmail(email) {
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        return emailRegex.test(email);
    }

    // Handle file selection (files are ready but not uploaded yet)
    handleFileUploadSuccess(event) {
        const detail = event.detail;

        if (detail.files && Array.isArray(detail.files)) {
            // Multiple files selected
            detail.files.forEach(file => {
                const fileId = this.generateFileId();
                if (!this.pendingFiles.some(f => f.fileName === file.fileName)) {
                    this.pendingFiles.push({
                        id: fileId,
                        contentDocumentId: file.contentDocumentId,
                        fileName: file.fileName
                    });
                }
            });
        } else if (detail.contentDocumentId) {
            // Single file selected
            const fileId = this.generateFileId();
            if (!this.pendingFiles.some(f => f.contentDocumentId === detail.contentDocumentId)) {
                this.pendingFiles.push({
                    id: fileId,
                    contentDocumentId: detail.contentDocumentId,
                    fileName: detail.fileName
                });
            }
        }

        console.log('Pending files:', this.pendingFiles);
    }

    // Remove pending file from list
    handleRemoveFile(event) {
        const fileId = event.currentTarget.dataset.fileid;
        this.pendingFiles = this.pendingFiles.filter(f => f.id !== fileId);
    }

    /**
     * « Photo cadastrale » + 2 + « .jpg » -> « Photo cadastrale 2.jpg ».
     * L'extension d'origine est conservée pour que Salesforce affiche la bonne
     * icône et que le fichier s'ouvre correctement.
     */
    _nommerPhoto(prefixe, index, nomOriginal) {
        const nom = nomOriginal || '';
        const pos = nom.lastIndexOf('.');
        const extension = pos > 0 ? nom.substring(pos) : '';
        return `${prefixe} ${index}${extension}`;
    }

    // Generate unique file ID
    generateFileId() {
        return 'file_' + Date.now() + '_' + Math.random().toString(36).substring(2, 11);
    }

    handleSubmit() {
        if (!this.validateForm()) {
            return;
        }

        this.isSavingLead = true;

        const leadData = {
            nomDirigeant: this.formData.nomDirigeant,
            firstName: this.formData.firstName,
            lastName: this.formData.lastName,
            email: this.formData.email,
            phone: this.formData.phone,
            company: this.formData.company,
            adresseComplete: this.formData.adresseComplete,
            // Bloc rappel masqué (« Suivi Signature » = le partenaire gère la signature) :
            // on n'envoie rien plutôt que la saisie laissée en mémoire. L'Apex teste
            // String.isEmpty() sur les deux avant de valoriser le Lead.
            dateRappel: this.afficherRappel ? this.formData.dateRappel : '',
            creneauRappel: this.afficherRappel ? this.formData.creneauRappel : '',
            commentaire: this.formData.commentaire,
            typeEnregistrement: this.formData.typeEnregistrement
        };

        // Add selected products to the lead multi-picklist field TypeDeDossier__c
        if (this.selectedProducts && this.selectedProducts.length > 0) {
            // Salesforce multi-select picklists use ';' as separator
            leadData.TypeDeDossier__c = this.selectedProducts.join(';');
        }

        // Build separate payload for dynamic fields (sent as separate param)
        const dynamicFieldsPayload = {};
        (this.dynamicFields || []).forEach(df => {
            try {
                const val = this.formData[df.apiName] || df.currentValue || null;
                if (val !== null && val !== undefined && String(val).length > 0) {
                    dynamicFieldsPayload[df.apiName] = val;
                }
            } catch (e) {
                // ignore
            }
        });

        // Accès réduit (partenaires) : TypePompeChaleur__c hérité du bouton
        // « Recommander un contact » cliqué (Air/Eau ou Air/Air) — transmis au Lead
        // via les champs dynamiques, sans champ visible sur le formulaire.
        if (this.accesReduit && this.typePompeChaleur) {
            dynamicFieldsPayload.TypePompeChaleur__c = this.typePompeChaleur;
        }

        // Accès réduit : champs « Informations d'appel » (facultatifs) saisis par le partenaire —
        // transmis au Lead via les champs dynamiques, uniquement si renseignés.
        if (this.accesReduit) {
            ['Apporteur_Presentation__c', 'Apporteur_ClientPrevenuAppel__c', 'Apporteur_ClientInformeRAC__c'].forEach(api => {
                const val = this.formData[api];
                if (val !== null && val !== undefined && String(val).trim().length > 0) {
                    dynamicFieldsPayload[api] = val;
                }
            });
        }

        // Champs propres à la fiche produit (facultatifs) — mêmes champs
        // dynamiques côté Apex, seuls les non vides sont transmis.
        (this.champsFicheMeta || []).forEach(m => {
            const val = this.formData[m.apiName];
            if (val !== null && val !== undefined && String(val).trim().length > 0) {
                dynamicFieldsPayload[m.apiName] = val;
            }
        });

        // Pièces jointes. Avec les sections de photos de la fiche, chaque fichier
        // est renommé « <préfixe> <n> » (la numérotation repart de 1 par section)
        // avant envoi : c'est ce nom que l'Apex pose sur ContentVersion.Title.
        let filesData = [];
        if (this.aSectionsPhotos) {
            this.sectionsPhotos.forEach(section => {
                const cmp = this.template.querySelector(`c-custom-file-upload[data-section="${section.cle}"]`);
                if (!cmp || !cmp.hasFile()) return;
                const data = cmp.getFileData();
                const liste = Array.isArray(data) ? data : [data];
                liste.filter(Boolean).forEach((f, i) => {
                    filesData.push({ ...f, fileName: this._nommerPhoto(section.prefixe, i + 1, f.fileName) });
                });
            });
        } else {
            const fileUploadComponent = this.template.querySelector('c-custom-file-upload');
            if (fileUploadComponent && fileUploadComponent.hasFile()) {
                const fileData = fileUploadComponent.getFileData();
                // getFileData returns array if multiple, single object if not
                filesData = Array.isArray(fileData) ? fileData : [fileData];
            }
        }

        console.log('Submitting lead with leadData:', JSON.stringify(leadData));
        console.log('Submitting lead with campaignCode:', JSON.stringify(this.campaignCode));
        console.log('Submitting lead with dynamicFieldsPayload:', JSON.stringify(dynamicFieldsPayload));
        console.log('Submitting lead with filesData.length:', filesData.length);
        // this.isSavingLead = false;
        // return;
        createLead({
            leadJson: JSON.stringify(leadData),
            campaignToken: this.campaignCode,
            filesDataJson: JSON.stringify(filesData),
            dynamicFieldsJson: JSON.stringify(dynamicFieldsPayload)
        })
            .then((result) => {
                console.log('Lead created successfully:', result);

                // Log uploaded files info
                if (result.uploadedFiles && result.uploadedFiles.length > 0) {
                    const successCount = result.uploadedFiles.filter(f => f.success).length;
                    const errorCount = result.uploadedFiles.filter(f => !f.success).length;
                    console.log(`Files uploaded: ${successCount} success, ${errorCount} failed`);

                    if (errorCount > 0) {
                        const failedFiles = result.uploadedFiles.filter(f => !f.success).map(f => f.fileName).join(', ');
                        console.warn('Failed files:', failedFiles);
                    }
                }

                this.showSuccessAnimation = true;
                this.showToast(this.txt.succes, this.txt.succesRdvToast, 'success');

                // Reset form
                this.formData = {
                    nomDirigeant: '',
                    firstName: '',
                    lastName: '',
                    email: '',
                    phone: '',
                    company: '',
                    adresseComplete: '',
                    dateRappel: '',
                    creneauRappel: '',
                    commentaire: '',
                    typeEnregistrement: null,
                    Apporteur_Presentation__c: '',
                    Apporteur_ClientPrevenuAppel__c: '',
                    Apporteur_ClientInformeRAC__c: ''
                };
                this.selectedProductType = null;

                // Reset checkbox selections
                this.selectedProducts = [];
                this.selectedTypeEnregistrement = null;

                // Reset certification (accès réduit)
                this.certificationAccord = false;

                // Reset files
                this.uploadedFiles = [];
                this.pendingFiles = [];

                // Reset file upload components — querySelectorAll : avec les
                // sections de photos de la fiche il y en a plusieurs, et n'en
                // vider qu'une laisserait les autres photos affichées après succès.
                this.template.querySelectorAll('c-custom-file-upload').forEach(cmp => {
                    if (cmp && cmp.reset) cmp.reset();
                });

                // Reset animation
                setTimeout(() => {
                    this.showSuccessAnimation = false;
                    // Re-auto-select single product if applicable
                    this.populateProducts();
                }, 5000);

                this.isSavingLead = false;
            })
            .catch(error => {
                if (error.body && error.body.message && error.body.message.includes('DUPLICATE_LEAD')) {
                    this.showToast(this.txt.erreur, this.txt.errDoublonApporteur, 'error');
                } else {
                    console.error('Error creating lead:', error);
                    this.showToast(this.txt.erreur, this.txt.errCreationPiste, 'error');
                }
                this.isSavingLead = false;
            });
    }

    showToast(title, message, variant) {
        // const event = new ShowToastEvent({
        //     title: title,
        //     message: message,
        //     variant: variant,
        //     mode: 'dismissable'
        // });
        // this.dispatchEvent(event);
        const label = message ? `${title} — ${message}` : title;
        Toast.show({
            label: label,
            mode: 'dismissible',
            variant: variant
        }, this);
    }

    handleProductClick(event) {
        const productType = event.currentTarget.dataset.type;
        this.selectProduct(productType);
    }

    handleCheckboxChange(event) {
        const value = event.currentTarget.dataset.value || event.target.value;
        if (!value) return;
        const product = (this.produits || []).find(p => p.codeProduit === value);
        if (!product) return;

        // If there is already a selected type, prevent mixing types
        if (this.selectedTypeEnregistrement && product.typeEnregistrement !== this.selectedTypeEnregistrement) {
            // ignore selection of different type
            return;
        }

        const idx = this.selectedProducts.indexOf(value);
        if (idx === -1) {
            // add
            this.selectedProducts = [...this.selectedProducts, value];
            // set selected type if first selection
            if (!this.selectedTypeEnregistrement) {
                this.selectedTypeEnregistrement = product.typeEnregistrement;
                // also set the small dropdown typeEnregistrement if empty
                if (!this.formData.typeEnregistrement) {
                    this.formData.typeEnregistrement = product.typeEnregistrement;
                    this.selectedProductType = product.typeEnregistrement;
                }
            }
        } else {
            // remove
            this.selectedProducts = this.selectedProducts.filter(v => v !== value);
            if (this.selectedProducts.length === 0) {
                this.selectedTypeEnregistrement = null;
            }
        }
        // Update dynamic fields whenever selection changes
        this.updateDynamicFieldsForSelectedProducts();
    }

    get formattedDate() {
        if (!this.campaign || !this.campaign.StartDate) return '-';
        const date = new Date(this.campaign.StartDate);
        return date.toLocaleDateString(localeDe(this._langue), { year: 'numeric', month: 'long', day: 'numeric' });
    }

    get isValidCampaign() {
        return this.campaign && !this.hasError && this.campaign.IsActive;
    }

    get isCampaignInactive() {
        return this.campaign && !this.hasError && !this.campaign.IsActive;
    }

    get showProductDropdown() {
        // console.log('Available products count:', JSON.stringify(this.produits));
        return this.produits && this.produits?.filter(e => e.isAvailable)?.length > 1;
    }

    get availableProducts() {
        return (this.produits || []).filter(p => p.isAvailable).map(p => ({
            label: p.nomProduit,
            value: p.typeEnregistrement,
            selected: p.typeEnregistrement === this.selectedProductType
        }));
    }

    get produitsWithClasses() {
        return this.produits.map(product => ({
            ...product,
            cardClass: product.isAvailable ? 'product-card product-available' : 'product-card product-unavailable'
        }));
    }

    get produitsGroupes() {
        const groupes = {};
        this.produitsWithClasses.forEach(product => {
                if (!groupes[product.typeEnregistrement]) {
                groupes[product.typeEnregistrement] = [];
            }
            groupes[product.typeEnregistrement].push(product);
        });
        // Return as array of objects with type and products
        return Object.entries(groupes).map(([type, products]) => ({
            typeEnregistrement: type,
            titre: products[0]?.titre || '',
            titreStyle: products[0]?.couleurProduit ? `color: ${products[0].couleurProduit};` : '',
            products: products
        }));
    }

    // Collapse control for products list
    toggleProductsCollapse() {
        this.productsCollapsed = !this.productsCollapsed;
    }

    get productsWrapClass() {
        return this.productsCollapsed ? 'products-wrap collapsed' : 'products-wrap expanded';
    }

    get collapseButtonAriaLabel() {
        return this.productsCollapsed ? this.txt.afficherProduits : this.txt.masquerProduits;
    }

    get collapseBtnClass() {
        return this.productsCollapsed ? 'collapse-btn collapsed' : 'collapse-btn';
    }

    get hasUploadedFiles() {
        return this.pendingFiles && this.pendingFiles.length > 0;
    }

    get uploadedFilesCount() {
        return this.pendingFiles.length;
    }

    get commentaireLength() {
        return this.formData.commentaire ? this.formData.commentaire.length : 0;
    }

    get commentaireCounterClass() {
        return this.commentaireLength > 230
            ? 'char-counter char-counter-warning'
            : 'char-counter';
    }

    get canSeeProductsInfo() {
        // return this.campaign?.PeutCreerREGIE__c;
        return false;
    }


    selectProduct(productType) {
        this.selectedProductType = productType;
        this.formData.typeEnregistrement = productType;
        
        // Find and scroll to product dropdown for visual feedback
        const dropdown = this.template.querySelector('[data-field="typeEnregistrement"]');
        if (dropdown) {
            dropdown.scrollIntoView({ behavior: 'smooth', block: 'center' });
            dropdown.classList.add('highlight-selection');
            setTimeout(() => {
                dropdown.classList.remove('highlight-selection');
            }, 1500);
        }
    }

    handleProductChange(event) {
        this.selectedProductType = event.target.value;
        this.formData.typeEnregistrement = event.target.value;
    }

    isInfosFillOpen = false;
    handleToggleInfosFill(event) {
        // Empêche le clic d'atteindre le listener document (qui fermerait le popup aussitôt).
        event.stopPropagation();
        this.isInfosFillOpen = !this.isInfosFillOpen;
    }

    get infosFillPopupClass() {
        return this.isInfosFillOpen ? 'bareme-popup bareme-popup--open' : 'bareme-popup';
    }
}