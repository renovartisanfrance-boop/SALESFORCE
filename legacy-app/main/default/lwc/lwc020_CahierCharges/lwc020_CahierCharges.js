import { LightningElement, api, track, wire } from 'lwc';
import getCampaignByToken from '@salesforce/apex/LC020_GestionCampagnes.getCampaignByToken';
import apiEndpoint from '@salesforce/label/c.GESTION_RDV_EXTERNE_API_ENDPOINT';
import USER_ID from '@salesforce/user/Id';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import PROFILE_NAME_FIELD from '@salesforce/schema/User.Profile.Name';
import PAYS_FIELD from '@salesforce/schema/User.Pays__c';

// Catalogue produits partagé (source unique) — voir c/lwc000_utils
import { PRODUCT_CATALOG, filtrerProduitsParPays, estModeGenerateur } from 'c/lwc000_utils';
// Traduction FR/ES partagée — voir c/lwc000_i18n
import { FR, etiquettes, traduireProduit } from 'c/lwc000_i18n';

// Profils Apporteur d'Affaires (interne + standard) — voient tous les simulateurs disponibles
const PROFIL_PI_APP_AFF = "PORTAIL INTERNE- APPORTEUR D'AFFAIRES";
const PROFIL_PI_APP_AFF_INTERNE = "PORTAIL INTERNE- APPORTEUR D'AFFAIRES- INTERNE";
const PROFILS_APPORTEUR_AFFAIRES = [PROFIL_PI_APP_AFF, PROFIL_PI_APP_AFF_INTERNE];

export default class Lwc020_CahierCharges extends LightningElement {

    apiEndpoint = apiEndpoint;

    @api isCommunityUser = false;

    // Accès réduit : affiche la section "Créer un RDV" (l'onglet Nouveau RDV est masqué).
    // Renseigné par lwc020_CampagneContainer ; false par défaut => aucun changement ailleurs.
    @api accesReduit = false;

    // Langue d'affichage, poussée par lwc020_CampagneContainer.
    _langue = FR;
    @api
    get langue() {
        return this._langue;
    }
    set langue(valeur) {
        const nouvelle = valeur || FR;
        const change = nouvelle !== this._langue;
        this._langue = nouvelle;

        // `this.produits` est un CHAMP, pas un getter : il fige le nom du produit,
        // le titre de groupe ET le lien du cahier des charges au moment du calcul.
        // Sans ce recalcul, basculer FR <-> ES laissait la fiche dans l'ancienne
        // langue et servait le mauvais CDC jusqu'au rechargement de la page.
        //
        // On ne recalcule QUE si le catalogue est déjà chargé : populateProducts()
        // viderait la liste sinon, et le premier rendu passe déjà par
        // loadInfosProduits().
        if (change && this.infoProduits) {
            this.populateProducts();
        }
    }

    get txt() {
        return etiquettes('cahierCharges', this._langue);
    }

    // Offre PAC Air/Air masquée temporairement (11/08/2026) : remettre à true pour la
    // restaurer à tout moment (le bloc HTML est conservé tel quel dans le template).
    showAirAir = false;

    // Bandeau reconnexion (accès réduit) — fermable ; l'état fermé est mémorisé dans
    // localStorage (comme le bandeau du reporting) pour ne pas réapparaître au rechargement.
    showReconnexionBanner = true;

    handleDismissReconnexion() {
        this.showReconnexionBanner = false;
        try {
            localStorage.setItem('reconnexionBannerDismissed', 'true');
        } catch (e) {
            /* localStorage indisponible */
        }
    }

    // Notifie le conteneur parent pour basculer sur la vue "Créer RDV" (Nouveau RDV).
    // Le bouton cliqué transmet son type de PAC (data-pac) : le Lead créé recevra
    // TypePompeChaleur__c avec la valeur correspondante, sans champ visible sur le formulaire.
    handleCreateRdv(event) {
        const pac = event?.currentTarget?.dataset?.pac;
        const typePompeChaleur = pac === 'air-eau'
            ? 'Air/Eau- Chauffage sur Radiateurs'
            : pac === 'air-air'
                ? 'Air/Air- Climatiseur(s) pour Chauffage et Refroidissement'
                : null;
        this.dispatchEvent(new CustomEvent('createrdv', { detail: { typePompeChaleur } }));
    }

    // --- Popup barème (fiche partenaire PAC Air/Eau) ---
    // Desktop : affiché au survol (CSS :hover). Mobile : ouvert/fermé au clic (état ci-dessous).
    @track isBaremeOpen = false;

    // Plafonds de revenus "ménages aux revenus très modestes" (source : cahier des charges TH171).
    baremeIdf = [
        { personnes: '1', revenu: '24 031 €' },
        { personnes: '2', revenu: '35 270 €' },
        { personnes: '3', revenu: '42 357 €' },
        { personnes: '4', revenu: '49 455 €' },
        { personnes: '5', revenu: '56 580 €' },
        { personnes: 'Par personne supplémentaire', revenu: '+ 7 116 €' }
    ];

    baremeHorsIdf = [
        { personnes: '1', revenu: '17 363 €' },
        { personnes: '2', revenu: '25 393 €' },
        { personnes: '3', revenu: '30 540 €' },
        { personnes: '4', revenu: '35 676 €' },
        { personnes: '5', revenu: '40 835 €' },
        { personnes: 'Par personne supplémentaire', revenu: '+ 5 151 €' }
    ];

    handleToggleBareme(event) {
        // Empêche le clic d'atteindre le listener document (qui fermerait le popup aussitôt).
        event.stopPropagation();
        this.isBaremeOpen = !this.isBaremeOpen;
    }

    // Un clic/tap À L'INTÉRIEUR du popup ne doit pas le fermer.
    handleBaremePopupClick(event) {
        event.stopPropagation();
    }

    get baremePopupClass() {
        return this.isBaremeOpen ? 'bareme-popup bareme-popup--open' : 'bareme-popup';
    }

    // Accès réduit : élargit la carte produit sur desktop (un seul produit -> pas 1/4 de largeur).
    get containerClass() {
        return this.accesReduit ? 'container container--acces-reduit' : 'container';
    }

    // Fiche TH171 disponible (avec son lien CDC) — support de la fiche partenaire dédiée.
    get th171Product() {
        return (this.produits || []).find(
            p => p.codeProduit === 'RESIDENTIEL_REGIES_-_TH171' && p.isAvailable
        ) || null;
    }

    /**
     * Fiche RES060 disponible — pendant espagnol de th171Product.
     *
     * Même condition que la TH171 : le produit doit être dans le
     * ProduitsDisponibles__c de la campagne (c'est `isAvailable` qui le porte).
     *
     * Aucun garde-fou « pays » n'est nécessaire ici : `this.produits` est déjà
     * filtré par filtrerProduitsParPays() sur Campaign.Pays__c, et la fiche
     * RES060 est déclarée pays: ["Espagne"] — elle ne peut donc pas remonter sur
     * une campagne France, où la carte TH171 reste la seule affichée.
     */
    get th060Product() {
        return (this.produits || []).find(
            p => p.codeProduit === 'RESIDENTIEL_REGIES_-_RES060' && p.isAvailable
        ) || null;
    }

    // Profil courant
    userProfileName = null;
    profileLoaded = false;

    // Pays de l'utilisateur courant (User.Pays__c) — utilisé en mode user Salesforce.
    userPays = null;

    // Récupère le nom du profil de l'utilisateur courant (Experience site).
    // Pays__c passe par optionalFields et NON par fields : sans droit de lecture
    // sur le champ, tout le wire échouerait (Profile.Name compris) et la logique
    // CDC Master/Mini repasserait à tort en Mini. En optionalFields, le champ est
    // simplement absent de la réponse et le reste continue de fonctionner.
    @wire(getRecord, { recordId: USER_ID, fields: [PROFILE_NAME_FIELD], optionalFields: [PAYS_FIELD] })
    wiredUser({ error, data }) {
        if (data) {
            this.userProfileName = getFieldValue(data, PROFILE_NAME_FIELD);
            this.userPays = getFieldValue(data, PAYS_FIELD);
            this.profileLoaded = true;
        } else if (error) {
            this.userProfileName = null;
            this.userPays = null;
            this.profileLoaded = true;
        }
        if (!this.profileLoaded) return;

        if (this.infoProduits) {
            // Produits déjà calculés sans le profil (mode Token) : on recalcule.
            this.populateProducts();
        } else if (this.isCommunityUser) {
            // Mode user Salesforce : le premier affichage est différé jusqu'ici
            // (cf. connectedCallback), le pays User.Pays__c est maintenant connu.
            this.loadInfosProduits();
        }
    }

    // Pays retenu pour filtrer le catalogue (France / Espagne) :
    //  - accès par Token : la campagne fait foi (Campaign.Pays__c) ;
    //  - user Salesforce (isCommunityUser, campaign null) : User.Pays__c.
    // null => aucun filtre pays (cf. filtrerProduitsParPays).
    get paysCourant() {
        return this.campaign ? (this.campaign.Pays__c || null) : (this.userPays || null);
    }


    _campaignCode;
    @api
    get campaignCode() {
        if (this._campaignCode) return this._campaignCode;
        try { return localStorage.getItem('renov_campaign_token'); } catch (e) { return null; }
    }
    set campaignCode(value) {
        this._campaignCode = value;
    }

    @track campaign = null;
    @track infoProduits = null;
    @track produits = [];
    @track isLoading = true;
    @track productsCollapsed = false;
    @track activeSimulator = null;

    connectedCallback() {
        // Ferme le popup barème au clic/tap en dehors (mobile surtout ; sans backdrop, pas un modal).
        // NB : ne pas inspecter composedPath ici — avec le shadow DOM (synthetic), l'événement est
        // retargeté et le chemin ne contient plus .bareme-trigger, ce qui refermait le popup
        // immédiatement après ouverture sur mobile. Les clics sur le déclencheur et DANS le popup
        // font stopPropagation() et n'atteignent donc jamais ce listener.
        this._onDocumentClick = () => {
            if (this.isBaremeOpen) {
                this.isBaremeOpen = false;
            }
        };
        document.addEventListener('click', this._onDocumentClick);

        // Restaure l'état fermé du bandeau reconnexion (persisté, comme le reporting).
        try {
            if (localStorage.getItem('reconnexionBannerDismissed') === 'true') {
                this.showReconnexionBanner = false;
            }
        } catch (e) {
            /* localStorage indisponible */
        }

        if (this.isCommunityUser) {
            // Dans un site Experience, on ne redirige pas et on affiche tous les produits.
            // L'affichage est différé tant que le wire User n'a pas répondu : sinon la
            // grille s'affiche sans filtre pays, puis les fiches des autres pays
            // disparaissent une fois User.Pays__c connu (effet de "flash").
            // Si le wire a déjà répondu, on enchaîne ici ; sinon wiredUser() prend le relais.
            this.campaign = null;
            if (this.profileLoaded && !this.infoProduits) {
                this.loadInfosProduits();
            }
        } else if (this.campaignCode) {
            this.loadCampaign();
        } else {
            this._redirectInvalidToken();
        }
    }

    disconnectedCallback() {
        if (this._onDocumentClick) {
            document.removeEventListener('click', this._onDocumentClick);
        }
    }

    _redirectInvalidToken() {
        // Generateur d'experience (prod ou sandbox) : la redirection vers l'app
        // externe remplacerait l'iframe d'apercu par la page de connexion et
        // masquerait toute l'interface de travail. Voir c/lwc000_utils.
        if (estModeGenerateur()) {
            console.warn('Mode Generateur : redirection vers le portail de connexion desactivee.');
            this.isLoading = false;
            return;
        }
        try { localStorage.clear(); } catch (e) { /* ignore */ }
        window.location.href = this.apiEndpoint;
    }

    loadCampaign() {
        this.isLoading = true;
        getCampaignByToken({ campaignToken: this.campaignCode })
            .then(data => {
                this.campaign = data;
                this.isLoading = false;
                this.loadInfosProduits();
            })
            .catch(error => {
                console.error('Invalid or not found campaign token, redirecting:', error);
                this._redirectInvalidToken();
            });
    }

    loadInfosProduits() {
        this.infoProduits = {
            // Le titre de section n'est PLUS porté ici : c'est un libellé
            // d'interface, le template le lit sur `txt` au rendu. L'y figer le
            // laissait dans l'ancienne langue après une bascule FR/ES.
            subtitle: PRODUCT_CATALOG.subtitle,
            produits: PRODUCT_CATALOG.produits.map(p => ({ ...p })).sort((a, b) => a.ordreAffichage - b.ordreAffichage)
        };
        this.populateProducts();
        // Le spinner ne s'arrête qu'ici : la grille n'apparaît jamais avant que le
        // pays (campagne ou utilisateur) ait été pris en compte.
        this.isLoading = false;
    }

    populateProducts() {
        if (!this.infoProduits || !this.infoProduits.produits) {
            this.produits = [];
            return;
        }

        // Filtre Pays (France / Espagne) appliqué AVANT toutes les autres règles :
        // un produit d'un autre pays est masqué, pas grisé. Le filtre est ici et non
        // dans loadInfosProduits() car le wire User peut se résoudre après le premier
        // rendu et ne rappelle que populateProducts().
        const produitsPays = filtrerProduitsParPays(this.infoProduits.produits, this.paysCourant);

        // Pour les community users, rendre tous les produits disponibles
        const campaignProducts = this.isCommunityUser
            ? produitsPays.filter(f => f.disponible).map(p => p.codeProduit)
            : (this.campaign && this.campaign.ProduitsDisponibles__c
                ? this.campaign.ProduitsDisponibles__c.split(';').map(p => p.trim())
                : []);

        // Profil Apporteur d'Affaires (Lightning) — accès complet
        const isApporteurAffaires = this.profileLoaded
            && PROFILS_APPORTEUR_AFFAIRES.includes(this.userProfileName);

        // Niveau 2 (Regie 2) = campagne avec un parent. Sinon Niveau 1 (Regie 1, ParentId null).
        const isRegie2 = !this.isCommunityUser
            && !!this.campaign
            && !!this.campaign.ParentId;

        // Choix Master/Mini : si le wire User a résolu, utiliser les profils Apporteur d'Affaires;
        // sinon retomber sur la valeur PeutCreerREGIE__c dans la campagne.
        const isRang1 = this.profileLoaded
            ? isApporteurAffaires
            : (this.campaign?.PeutCreerREGIE__c === true);

        this.produits = produitsPays.filter(f => f.disponible).map((product) => {
            const simMatch = (product.nomProduit || '').match(/TH(\d+)/);
            const simCode = simMatch ? simMatch[1] : null;
            // ⚠️ La fiche est traduite AVANT de choisir le CDC, et le choix se fait
            // sur la version traduite : une fiche peut surcharger cdcMaster /
            // cdcMini dans son bloc i18n (RES060 a un cahier des charges espagnol).
            // Lire product.cdcMaster ici servirait toujours le document français,
            // quelle que soit la langue affichée.
            const fiche = traduireProduit(product, this._langue);

            // Accès réduit (partenaire) : CDC dédié "Partenaire" si défini pour le produit,
            // sinon on retombe sur la logique Master/Mini habituelle.
            const cdcResource = (this.accesReduit && fiche.cdcPartenaire)
                ? fiche.cdcPartenaire
                : (isRang1 ? fiche.cdcMaster : fiche.cdcMini);

            // Visibilité du bouton Simulateur :
            //  - Apporteur d'Affaires / Niveau 1 / mode community : visible si le produit est dispo (déjà géré par isAvailable).
            //  - Niveau 2 (Regie 2) : en plus, le champ Simulateur_BAT_THxxx__c de la campagne doit valoir 'OUI'.
            let showSimulateur = !!(product.simulateurExiste && simCode);
            if (showSimulateur && isRegie2) {
                const fieldName = simCode === '179' ? 'Simulateur_BAT_TH179__c'
                    : simCode === '163' ? 'Simulateur_BAT_TH163__c'
                    : null;
                showSimulateur = fieldName ? this.campaign[fieldName] === 'OUI' : false;
            }

            return {
                // Libellés d'affichage traduits (nomProduit, titre) via le bloc
                // i18n.es de la fiche. Les champs qui servent de VALEUR
                // (codeProduit, typeEnregistrement) restent intacts : simCode et
                // isTh171 ci-dessus s'appuient dessus.
                ...fiche,
                downloadLink: product.cdcExiste ? cdcResource : null,
                // Catalogue : jamais surchargé par langue — un seul document sert
                // le français et l'espagnol.
                catalogueLink: product.catalogueExiste ? product.catalogue : null,
                simulateurCode: showSimulateur ? simCode : null,
                fileName: product.nomProduit,
                isAvailable: this.isCommunityUser ? true : (product.disponible && campaignProducts.includes(product.codeProduit)),
                couleurStyle: product.couleurProduit ? `color: ${product.couleurProduit};` : '',
                // Variable CSS pour colorer l'encadré CDC (partenaire) avec la couleur du produit.
                cdcHintStyle: product.couleurProduit ? `--cdc-color: ${product.couleurProduit};` : '',
                // Infos partenaire (marques + rémunération) réservées à la fiche TH171.
                isTh171: product.codeProduit === 'RESIDENTIEL_REGIES_-_TH171'
            };
        });
    }

    get produitsWithClasses() {
        return this.produits.map(product => ({
            ...product,
            cardClass: product.isAvailable ? 'product-card product-available' : 'product-card product-unavailable'
        }));
    }

    get produitsGroupes() {
        // Accès réduit : n'afficher QUE les fiches disponibles pour l'utilisateur.
        // (les groupes devenus vides ne sont pas créés, donc masqués automatiquement).
        // Les autres types d'utilisateurs continuent de voir toutes les fiches.
        const source = this.accesReduit
            ? this.produitsWithClasses.filter(p => p.isAvailable)
            : this.produitsWithClasses;

        const groupes = {};
        source.forEach(product => {
            if (!groupes[product.typeEnregistrement]) {
                groupes[product.typeEnregistrement] = [];
            }
            groupes[product.typeEnregistrement].push(product);
        });
        return Object.entries(groupes).map(([type, products]) => ({
            typeEnregistrement: type,
            titre: products[0]?.titre || '',
            titreStyle: products[0]?.couleurProduit ? `color: ${products[0].couleurProduit};` : '',
            products: products
        }));
    }

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

    // eslint-disable-next-line no-unused-vars
    handleProductClick(event) {
        // No-op: product click has no action in this view
    }

    handleOpenSimulator(event) {
        const simCode = event.currentTarget.dataset.sim;
        if (simCode) this.activeSimulator = simCode;
    }

    handleCloseSimulator() {
        this.activeSimulator = null;
    }

    handleSimulatorBackdropClick(event) {
        if (event.target === event.currentTarget) {
            this.handleCloseSimulator();
        }
    }

    get isSimulatorOpen() {
        return this.activeSimulator !== null;
    }

    get isSim163Open() {
        return this.activeSimulator === '163';
    }

    get isSim179Open() {
        return this.activeSimulator === '179';
    }
}