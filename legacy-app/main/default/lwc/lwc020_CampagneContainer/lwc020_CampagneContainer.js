import { LightningElement, track, wire, api } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getCampaignByToken from '@salesforce/apex/LC020_GestionCampagnes.getCampaignByToken';
import getInfosProduits from '@salesforce/apex/LC020_GestionCampagnes.getInfosProduits';
import bannerPage from '@salesforce/resourceUrl/bannerPage';
import logoRenov from '@salesforce/resourceUrl/logoRenov';
import apiEndpoint from '@salesforce/label/c.GESTION_RDV_EXTERNE_API_ENDPOINT';
import contactPhone from '@salesforce/label/c.RENOV_Contact_Telephone';
import contactWhatsapp from '@salesforce/label/c.RENOV_Contact_WhatsApp';
import { FR, ES, bilingue, choixLangueOffert, lireLangue, ecrireLangue, etiquettes } from 'c/lwc000_i18n';
// Detection du Generateur d'experience (aperçu) — voir c/lwc000_utils
import { estModeGenerateur } from 'c/lwc000_utils';

// Vues restaurables depuis le paramètre d'URL c__view. Liste UNIQUE : elle était
// dupliquée à deux endroits, ce qui a fait oublier « facturation » lors de son ajout.
const VUES_VALIDES = ['nouveau-rdv', 'my-reporting', 'creer-regie', 'cahier-charges', 'facturation'];

// Titre du site — piloté par le PAYS de la campagne, jamais par la langue
// d'affichage : le sigle désigne le dispositif réglementaire dont relève la
// régie (CEE en France, CAE en Espagne), pas la langue de lecture. Un partenaire
// espagnol qui bascule en français doit continuer à lire « Espace CAE ».
// C'est pour cette raison que ces libellés ne sont PAS dans c/lwc000_i18n.
const TITRE_SITE_FR = 'Espace CEE';
// const TITRE_SITE_ES = 'Espace CAE';
const TITRE_SITE_ES = 'Espacio CAE';

export default class Lwc020_CampagneContainer extends LightningElement {
    bannerPage = bannerPage;
    logoRenov = logoRenov;
    apiEndpoint = apiEndpoint;
    contactPhone = contactPhone;
    contactWhatsapp = contactWhatsapp;
    @track isFooterCollapsed = false;
    @api isGuestUser = false;
    @track currentView = 'nouveau-rdv';
    @track campaignCode = null;
    @track isLoading = true;
    @track hasError = false;
    @track errorTitle = 'Lien invalide';
    @track errorMessage = '';
    @track campaign = null;
    @track infoProduits = null;
    @track produits = [];
    @track isMenuOpen = false;
    // Langue d'affichage du site. Renseignee une fois la campagne chargee, a
    // partir de Campaign.Pays__c : une campagne non espagnole reste en francais
    // quoi qu'il y ait dans le localStorage (cf. lireLangue).
    @track langue = FR;

    connectedCallback() {
        // Restaure l'état réduit/déplié du pied de page depuis localStorage.
        try {
            this.isFooterCollapsed = localStorage.getItem('renov_footer_collapsed') === 'true';
        } catch (e) {
            // ignore (localStorage indisponible)
        }
    }

    get afficherContenu() {
        return true;
    }

    @wire(CurrentPageReference)
    wiredPageRef(pageRef) {
        console.log('Page Reference:', JSON.stringify(pageRef));

        if (pageRef && pageRef.state?.c__code) {
            // Token trouvé dans l'URL — sauvegarder dans localStorage et nettoyer l'URL
            this.campaignCode = pageRef.state.c__code;
            console.log('Campaign Code from URL:', this.campaignCode);

            try {
                localStorage.setItem('renov_campaign_token', this.campaignCode);
            } catch (e) {
                console.error('Error saving token to localStorage:', e);
            }

            // Supprimer le token de l'URL
            try {
                const url = new URL(window.location.href);
                url.searchParams.delete('c__code');
                window.history.replaceState(null, '', url.toString());
            } catch (e) {
                console.error('Error cleaning URL:', e);
            }

            // Restaurer la vue depuis l'URL si présente
            const validViews = VUES_VALIDES;
            if (pageRef.state?.c__view && validViews.includes(pageRef.state.c__view)) {
                this.currentView = pageRef.state.c__view;
            }

            this.isLoading = true;
            this.loadCampaign();
        } else if (!this.campaignCode) {
            // Pas de token dans l'URL — essayer localStorage
            try {
                const storedToken = localStorage.getItem('renov_campaign_token');
                if (storedToken) {
                    this.campaignCode = storedToken;
                    console.log('Campaign Code from localStorage:', this.campaignCode);

                    // Restaurer la vue depuis l'URL si présente
                    const validViews = VUES_VALIDES;
                    if (pageRef && pageRef.state?.c__view && validViews.includes(pageRef.state.c__view)) {
                        this.currentView = pageRef.state.c__view;
                    }

                    this.isLoading = true;
                    this.loadCampaign();
                } else {
                    console.log('No token found in URL or localStorage, redirecting...');
                    this.handleDeconnexion();
                    return;
                }
            } catch (e) {
                console.error('Error reading token from localStorage:', e);
                this.handleDeconnexion();
                return;
            }
        }

        // Check if code is missing
        if (!this.campaignCode) {
            this.handleDeconnexion();
        }
    }

    loadCampaign() {
        getCampaignByToken({ campaignToken: this.campaignCode })
            .then(data => {
                console.log('Loaded Campaign:', JSON.stringify(data));
                this.campaign = data;
                // Avant validateViewAccess() : ses messages d'erreur sont traduits.
                // `this.campaign` vient d'être renseigné : this.isAccesReduit est fiable.
                this.langue = lireLangue(data?.Pays__c, this.isAccesReduit);
                this.hasError = false;
                this.isLoading = false;
                // Accès réduit (AccesReduit__c = true) : seuls les onglets Reporting,
                // Cahier des charges et Facturation sont visibles. Si la vue courante
                // n'est aucune des trois, on démarre sur le Cahier des charges (la vue
                // "Créer RDV" reste accessible via le bouton dédié du Cahier des charges).
                if (this.isAccesReduit
                    && this.currentView !== 'my-reporting'
                    && this.currentView !== 'cahier-charges'
                    // La facturation leur est ouverte depuis l'ajout de la vue
                    // partenaire : sans cette exception, un lien ?c__view=facturation
                    // les renverrait silencieusement sur le Cahier des charges.
                    && this.currentView !== 'facturation') {
                    this.currentView = 'cahier-charges';
                }
                this.validateViewAccess();
                this.loadInfosProduits();
            })
            .catch(error => {
                console.error('Invalid or not found campaign token, redirecting:', error);
                this.handleDeconnexion();
            });
    }

    validateViewAccess() {
        const restrictedViews = {
            'creer-regie': this.voirBtnCreerRegie,
            // Sans cette entrée, un lien direct ?c__view=facturation afficherait
            // l'onglet à une campagne fille ou à un accès réduit, alors que
            // showTabFacturation le masque dans le menu.
            'facturation': this.showTabFacturation
        };

        if (this.currentView in restrictedViews && !restrictedViews[this.currentView]) {
            this.hasError = true;
            this.errorTitle = this.txt.pageNonTrouvee;
            this.errorMessage = this.txt.pasAcces;
        }
    }

    loadInfosProduits() {
        getInfosProduits()
            .then(result => {
                const infos = JSON.parse(result);
                this.infoProduits = infos;
                this.filterProducts();
            })
            .catch(error => {
                console.error('Error loading product info:', error);
            });
    }

    filterProducts() {
        if (!this.infoProduits || !this.infoProduits.produits) {
            this.produits = [];
            return;
        }

        const campaignProducts = this.campaign && this.campaign.ProduitsDisponibles__c
            ? this.campaign.ProduitsDisponibles__c.split(';').map(p => p.trim())
            : [];

        this.produits = this.infoProduits.produits.map(product => ({
            ...product,
            isAvailable: product.disponible && campaignProducts.includes(product.typeEnregistrement)
        }));
    }

    handleMenuClick(event) {
        event.preventDefault();
        const viewName = event.currentTarget.dataset.view;
        if (viewName) {
            this.currentView = viewName;
            this.isMenuOpen = false;

            // Persister la vue dans l'URL pour survie au refresh
            try {
                const url = new URL(window.location.href);
                url.searchParams.set('c__view', viewName);
                window.history.replaceState(null, '', url.toString());
            } catch (e) {
                console.error('Erreur mise à jour URL:', e);
            }
        }
    }

    handleToggleMenu() {
        this.isMenuOpen = !this.isMenuOpen;
    }

    // --- Langue d'affichage (FR / ES) ---------------------------------------
    // Le selecteur n'apparait que pour les campagnes Espagne QUI NE SONT PAS en
    // acces reduit ; une campagne France, comme un partenaire, n'a aucun element
    // de DOM supplementaire et reste dans la langue de son pays.

    // Etiquettes de l'en-tete. Getter et non champ stocke : etiquettes() est
    // memoisee, donc c'est une simple lecture de Map a chaque rendu.
    get txt() {
        return etiquettes('entete', this.langue);
    }

    // Partenaire (accès réduit) : aucun sélecteur. Espagne => espagnol imposé,
    // France => français imposé. Voir choixLangueOffert dans c/lwc000_i18n.
    get afficherSelecteurLangue() {
        return choixLangueOffert(this.campaign?.Pays__c, this.isAccesReduit);
    }

    // Pays de la campagne, relayé aux vues qui en dépendent (lwc020_GestionCampagnes
    // masque les simulateurs BAT français pour l'Espagne). Les requêtes qui
    // alimentent ce composant ne remontent pas Pays__c : il vient donc d'ici.
    get paysCampagne() {
        return this.campaign?.Pays__c || null;
    }

    // Voir TITRE_SITE_* : dépend du pays, pas du sélecteur de langue.
    get titreSite() {
        return bilingue(this.campaign?.Pays__c) ? TITRE_SITE_ES : TITRE_SITE_FR;
    }

    get estEspagnol() {
        return this.langue === ES;
    }

    get estFrancais() {
        return this.langue === FR;
    }

    get classeLangueEs() {
        return this.estEspagnol ? 'lang-option active' : 'lang-option';
    }

    get classeLangueFr() {
        return this.estFrancais ? 'lang-option active' : 'lang-option';
    }

    handleChangerLangue(event) {
        // ecrireLangue renvoie la langue effectivement retenue (elle refuse
        // l'espagnol si la campagne n'est pas espagnole, et tout changement si
        // la campagne est en accès réduit — le sélecteur n'y est pas rendu, mais
        // le garde-fou reste côté module plutôt que côté template).
        this.langue = ecrireLangue(
            event.currentTarget.dataset.langue,
            this.campaign?.Pays__c,
            this.isAccesReduit
        );
        this.isMenuOpen = false;
    }

    // Type de PAC pré-sélectionné (accès réduit) par le bouton « Recommander un contact »
    // cliqué dans le Cahier des charges — relayé à lwc020_NouveauRdv pour renseigner
    // TypePompeChaleur__c sur le Lead sans afficher de champ sur le formulaire.
    @track typePompeChaleurRdv = null;

    // Navigue vers la vue "Créer RDV" (Nouveau RDV) sans exposer l'onglet.
    // Déclenché par le bouton "Créer un RDV" du Cahier des charges (accès réduit).
    handleNavigateToCreateRdv(event) {
        this.typePompeChaleurRdv = event?.detail?.typePompeChaleur || null;
        this.currentView = 'nouveau-rdv';
        this.isMenuOpen = false;
        try {
            const url = new URL(window.location.href);
            url.searchParams.set('c__view', 'nouveau-rdv');
            window.history.replaceState(null, '', url.toString());
        } catch (e) {
            console.error('Erreur mise à jour URL:', e);
        }
    }

    // Retour vers le Cahier des charges depuis le formulaire RDV (accès réduit).
    // Bascule simplement la vue du conteneur ; l'URL reflète la vue active (c__view).
    handleBackToCahierCharges() {
        this.currentView = 'cahier-charges';
        this.isMenuOpen = false;
        try {
            const url = new URL(window.location.href);
            url.searchParams.set('c__view', 'cahier-charges');
            window.history.replaceState(null, '', url.toString());
        } catch (e) {
            console.error('Erreur mise à jour URL:', e);
        }
    }

    handleDeconnexion() {
        // Générateur d'expérience (prod ou sandbox) : la redirection vers l'app
        // externe remplacerait l'iframe d'aperçu par la page de connexion et
        // masquerait toute l'interface de travail. On affiche un message à la
        // place. Voir estModeGenerateur() dans c/lwc000_utils.
        if (estModeGenerateur()) {
            console.warn('Mode Générateur : redirection vers le portail de connexion désactivée.');
            this.isLoading = false;
            this.hasError = true;
            this.errorTitle = 'Aperçu Générateur';
            this.errorMessage = "Aucun token de campagne dans cet aperçu : la redirection vers le portail de connexion est désactivée dans le Générateur. Le composant fonctionnera normalement sur le site publié (lien avec ?c__code=...).";
            return;
        }
        try {
            localStorage.clear();
        } catch (e) {
            console.error('Error clearing localStorage:', e);
        }
        window.location.href = this.apiEndpoint;
    }

    // --- Pied de page contact (visible sur toutes les pages) ---
    toggleFooter() {
        this.isFooterCollapsed = !this.isFooterCollapsed;
        try {
            localStorage.setItem('renov_footer_collapsed', this.isFooterCollapsed ? 'true' : 'false');
        } catch (e) {
            // ignore (localStorage indisponible)
        }
    }

    get contactPhoneHref() {
        return 'tel:' + (this.contactPhone || '').replace(/\s+/g, '');
    }

    get contactWhatsappHref() {
        // wa.me exige le format international en chiffres uniquement.
        return 'https://wa.me/' + (this.contactWhatsapp || '').replace(/[^\d]/g, '');
    }

    get showNouveauRdv() {
        return this.currentView === 'nouveau-rdv';
    }

    get showMyReporting() {
        return this.currentView === 'my-reporting';
    }

    get isNouveauRdvActive() {
        return this.currentView === 'nouveau-rdv' ? 'nav-link active' : 'nav-link';
    }

    get isMyReportingActive() {
        return this.currentView === 'my-reporting' ? 'nav-link active' : 'nav-link';
    }

    get isCreerRegieActive() {
        return this.currentView === 'creer-regie' ? 'nav-link active' : 'nav-link';
    }

    get navMenuClass() {
        return this.isMenuOpen ? 'nav-menu open' : 'nav-menu';
    }

    get menuIconClass() {
        return this.isMenuOpen ? 'hamburger-icon open' : 'hamburger-icon';
    }

    get showCreerRegie() {
        return this.currentView === 'creer-regie';
    }

    get showCahierCharges() {
        return this.currentView === 'cahier-charges';
    }

    get isCahierChargesActive() {
        return this.currentView === 'cahier-charges' ? 'nav-link active' : 'nav-link';
    }

    get showFacturation() {
        return this.currentView === 'facturation';
    }

    get isFacturationActive() {
        return this.currentView === 'facturation' ? 'nav-link active' : 'nav-link';
    }

    get campaignId() {
        return this.campaign?.Id;
    }

    // Nom de la régie (Campagne.Name) affiché dans l'en-tête (desktop + mobile).
    get regieName() {
        return this.campaign?.Name || '';
    }

    get isValidToken() {
        return this.campaign && !this.hasError;
    }

    get voirBtnCreerRegie() {
        return !this.campaign?.ParentId && (this.campaign?.PeutCreerREGIE__c === true || this.campaign?.ChildCampaigns?.length);
    }

    get voirBtnFacturation() {
        return !this.campaign?.ParentId;
    }

    /**
     * Mini-régie, dite « niveau 2 » : une campagne FILLE qui n'est pas en accès
     * réduit. Trois cas coexistent et il faut les distinguer :
     *   • niveau 1 — campagne mère (ParentId null), la régie ;
     *   • niveau 2 — campagne fille sans accès réduit, la mini-régie ;
     *   • accès réduit — le partenaire, traité à part par isAccesReduit.
     *
     * Le composant de reporting ne reçoit que le code de campagne : il ne peut
     * pas déduire ce niveau seul, d'où la propriété passée depuis ici, comme
     * `acces-reduit` et `pays` avant elle.
     */
    get isMiniRegie() {
        return !!this.campaign?.ParentId && !this.isAccesReduit;
    }

    // --- Accès réduit (AccesReduit__c = true) ---
    // Seuls les onglets Reporting, Cahier des charges et Facturation sont
    // visibles ; Créer Accès Utilisateurs et Nouveau RDV sont masqués.
    get isAccesReduit() {
        return this.campaign?.AccesReduit__c === true;
    }

    // Le pied de page contact (fixe) n'existe qu'en accès réduit : on réserve alors un
    // espace bas dans la zone scrollable pour que le bas du formulaire reste atteignable
    // (sinon la carte fixe recouvre la case de certification + le bouton sur mobile).
    get contentWrapperClass() {
        return this.isAccesReduit && !this.isFooterCollapsed
            ? 'content-wrapper contact-footer-present'
            : 'content-wrapper';
    }

    get showTabCreerRegie() {
        return this.voirBtnCreerRegie && !this.isAccesReduit;
    }

    get showTabNouveauRdv() {
        return !this.isAccesReduit;
    }

    /**
     * La facturation est ouverte AUSSI aux accès réduits : les partenaires y voient
     * une vue dédiée, sans onglet, portée par lwc020_FacturationPartenaire.
     * Seule la règle « pas de campagne fille » subsiste.
     *
     * Ce getter sert DEUX fois — l'onglet du menu et validateViewAccess() : y
     * remettre un `&& !this.isAccesReduit` ne masquerait pas seulement l'onglet,
     * il rendrait aussi la vue inatteignable par lien direct.
     */
    get showTabFacturation() {
        return this.voirBtnFacturation;
    }

    /** Le partenaire ne « facture » pas : il consulte l'état de ses dossiers au
     *  regard de son contrat — d'où un libellé de menu différent pour lui seul. */
    get libelleFacturation() {
        return this.isAccesReduit ? this.txt.facturationContrat : this.txt.facturation;
    }

    // Le lien "Se déconnecter" n'est visible que si la campagne a l'accès CEE.
    get voirDeconnexion() {
        return this.campaign?.AvoirAccesCEE__c === true;
    }

    get cantCreateRegie() {
        return !this.campaign?.PeutCreerREGIE__c
    }

    // Produits du compte actif (chaîne ';'-séparée) — utilisé par lwc020_GestionCampagnes
    // pour décider si afficher la question "donner accès au simulateur" en mode guest.
    get currentUserProduits() {
        return this.campaign?.ProduitsDisponibles__c || '';
    }

    get backgroundStyle() {
        return `background-image:url(${this.bannerPage})`;
    }
}