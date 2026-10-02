import { LightningElement, wire, track, api } from 'lwc';
import RENOV_Campagne_Base_URL from '@salesforce/label/c.RENOV_Campagne_Base_URL';
import LWC020_MasqueLienConnexion from '@salesforce/label/c.LWC020_MasqueLienConnexion';
import getCampaignsByParentToken from '@salesforce/apex/LC020_GestionCampagnes.getCampaignsByParentToken';
import getMyCampagnesWithChildren from '@salesforce/apex/LC020_GestionCampagnes.getMyCampagnesWithChildren';
import getProduitsDisponiblesPicklistValues from '@salesforce/apex/LC020_GestionCampagnes.getProduitsDisponiblesPicklistValues';
import createCampaign from '@salesforce/apex/LC020_GestionCampagnes.createCampaign';
import updateCampaign from '@salesforce/apex/LC020_GestionCampagnes.updateCampaign';
import activerCEE from '@salesforce/apex/LC020_GestionCampagnes.activerCEE';
import sendCampaignEmail from '@salesforce/apex/LC020_EmailService.sendCampaignEmail';
import reinitialiserMotDePasse from '@salesforce/apex/LC020_ExterneAPIService.reinitialiserMotDePasse';
import changerEmail from '@salesforce/apex/LC020_ExterneAPIService.changerEmail';
import apiEndpoint from '@salesforce/label/c.GESTION_RDV_EXTERNE_API_ENDPOINT';
// import sendCampaignSMS from '@salesforce/apex/LC020_SMSService.sendCampaignSMS';
import { FR, PAYS_ESPAGNE, etiquettes, remplir } from 'c/lwc000_i18n';
import { NavigationMixin } from 'lightning/navigation';
import Toast from 'lightning/toast';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import userId from '@salesforce/user/Id';
import { estModeGenerateur } from 'c/lwc000_utils';

const USER_PROFILE_FIELD = 'User.Profile.Name';
const PROFIL_PI_APP_AFF_INTERNE = "PORTAIL INTERNE- APPORTEUR D'AFFAIRES- INTERNE";
const PROFIL_PI_APP_AFF = "PORTAIL INTERNE- APPORTEUR D'AFFAIRES";
const PROFILS_APPORTEUR_AFFAIRES = [PROFIL_PI_APP_AFF_INTERNE, PROFIL_PI_APP_AFF];
const PRODUIT_BAT_TH179 = 'BAT_REGIES_-_TH179';
const PRODUIT_BAT_TH163 = 'BAT_REGIES_-_TH163';

export default class Lwc020_GestionCampagnes extends NavigationMixin(LightningElement) {
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
        return etiquettes('gestionCampagnes', this._langue);
    }

    // Classe racine : les libelles Actif/Inactif du basculeur sont dessines en
    // CSS (content: '...'), donc hors de portee du dictionnaire. La classe
    // permet de les surcharger en espagnol.
    get classeRacine() {
        return this._langue === 'es' ? 'campaigns-container gc-es' : 'campaigns-container';
    }

    // Custom Labels
    baseUrl = RENOV_Campagne_Base_URL;
    apiEndpoint = apiEndpoint;

    get masqueLienConnexion() {
        // console.log('LWC020_MasqueLienConnexion:', LWC020_MasqueLienConnexion);
        // console.log("LWC020_MasqueLienConnexion?.trim().toUpperCase() === 'OUI':4", LWC020_MasqueLienConnexion?.trim().toUpperCase() === 'OUI');
        return LWC020_MasqueLienConnexion?.trim().toUpperCase() === 'OUI' && !this.isApporteurInterne;
    }

    _cantCreateRegie;
    get cantCreateRegie() {
        return this._cantCreateRegie;
    }
    @api set cantCreateRegie(value) {
        this._cantCreateRegie = value;
    }


    @wire(getRecord, { recordId: userId, optionalFields: [USER_PROFILE_FIELD] })
    currentUser;

    get isApporteurInterne() {
        console.log('Current User Profile:', getFieldValue(this.currentUser?.data, USER_PROFILE_FIELD));
        return getFieldValue(this.currentUser?.data, USER_PROFILE_FIELD) === PROFIL_PI_APP_AFF_INTERNE;
    }

    // Profils Apporteur d'Affaires (interne + standard) :
    // produits + simulateurs présélectionnés et masqués dans le formulaire.
    get isApporteurAffaires() {
        const profile = getFieldValue(this.currentUser?.data, USER_PROFILE_FIELD);
        return PROFILS_APPORTEUR_AFFAIRES.includes(profile);
    }

    // Liste des produits du compte actif (utilisée en mode guest)
    get currentUserProduitsList() {
        return (this.currentUserProduits || '').split(';').map(s => s.trim()).filter(Boolean);
    }

    get currentUserHasTH179() {
        return this.currentUserProduitsList.includes(PRODUIT_BAT_TH179);
    }

    get currentUserHasTH163() {
        return this.currentUserProduitsList.includes(PRODUIT_BAT_TH163);
    }

    // Section Produits : visible uniquement pour les profils "autres"
    // (les Apporteur d'Affaires ont tout par défaut, les guests héritent du parent).
    get showProduitsSection() {
        return !this.isApporteurAffaires && !this.isGuestUser;
    }

    @api parentId = null;
    @api isGuestUser = false;
    // Produits du compte actif (chaîne ';'-séparée), utilisé en mode guest pour
    // déterminer quelles questions de simulateur afficher au Regie 1.
    @api currentUserProduits = '';

    // Pays de la campagne active, transmis par lwc020_CampagneContainer : les
    // requêtes qui alimentent ce composant ne sélectionnent pas Pays__c.
    @api pays = null;

    get estEspagne() {
        return this.pays === PAYS_ESPAGNE;
    }

    _parentToken = null;
    @api
    get parentToken() {
        if (this._parentToken) return this._parentToken;
        try { return localStorage.getItem('renov_campaign_token'); } catch (e) { return null; }
    }
    set parentToken(value) {
        this._parentToken = value;
    }

    @track campaigns = [];
    @track isLoading = false;
    @track sortField = 'displayName';
    @track sortDirection = 'asc';
    @track showCreateModal = false;
    @track showEditModal = false;
    @track showDetailsModal = false;
    @track showInfoModal = false;
    @track isSendingEmail = false;
    @track isSendingSMS = false;
    @track isResettingPassword = false;
    @track isActivatingCEE = false;
    @track selectedCampaign = null;
    @track produitsPicklistValues = [];
    @track formData = {
        name: '',
        commentaire: '',
        email: '',
        telephone: '',
        isActive: true,
        peutCreerRegie: false,
        produitsDisponibles: []
    };
    @track fieldErrors = {
        name: '',
        email: '',
        telephone: '',
        motDePasse: ''
    };

    wiredCampaignsResult;
    _isInitialized = false;

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

    connectedCallback() {
        this.loadProduitsDisponibles();
        // Charger les campagnes selon le mode
        if (this.isGuestUser && this.parentToken) {
            this.loadGuestCampaigns();
        } else if (this.isGuestUser && !this.parentToken) {
            this._redirectInvalidToken();
            return;
        } else if (this.parentId || 1) {
            // Mode utilisateur authentifié avec parentId (depuis le container)
            this.loadAuthenticatedCampaignsWithChildren();
        }
        // Sinon le @wire se chargera du chargement pour le mode standard
    }

    loadProduitsDisponibles() {
        getProduitsDisponiblesPicklistValues()
            .then(result => {
                this.produitsPicklistValues = result;
            })
            .catch(error => {
                console.error('Error loading products:', error);
                this.showToast(this.txt.erreur, this.txt.errChargementProduits, 'error');
            });
    }

    /**
     * Charge les campagnes pour les guest users (enfants de la campagne parente)
     */
    loadGuestCampaigns() {
        if (!this.parentToken) return;

        this.isLoading = true;
        getCampaignsByParentToken({ parentToken: this.parentToken })
            .then(data => {
                console.log('Loaded Guest Campaigns:', JSON.stringify(data));
                this.campaigns = data.map(campaign => this.mapCampaignData(campaign, false));
                this.isLoading = false;
                this._isInitialized = true;
            })
            .catch(error => {
                console.error('Invalid or not found token, redirecting:', error);
                this._redirectInvalidToken();
            });
    }

    /**
     * Charge les campagnes pour les utilisateurs authentifiés avec leurs enfants
     */
    loadAuthenticatedCampaignsWithChildren() {
        this.isLoading = true;
        getMyCampagnesWithChildren()
            .then(data => {
                // console.log('Loaded Campaigns with Children:', JSON.stringify(data));
                this.campaigns = data.map(item => {
                    const campaign = item.campaign;
                    const isReadOnly = item.isReadOnly;
                    const parentName = item.parentName || null;
                    return this.mapCampaignData(campaign, isReadOnly, parentName);
                });
                // Re-synchroniser selectedCampaign si un modal est ouvert
                if (this.selectedCampaign) {
                    const refreshed = this.campaigns.find(c => c.Id === this.selectedCampaign.Id);
                    if (refreshed) this.selectedCampaign = refreshed;
                }
                this.isLoading = false;
                this._isInitialized = true;
            })
            .catch(error => {
                console.error('Error loading campaigns with children:', error);
                this.showToast(this.txt.erreur, this.txt.errChargementUtilisateurs, 'error');
                this.isLoading = false;
            });
    }

    /**
     * Mappe les donnés d'une campagne pour l'affichage
     */
    mapCampaignData(campaign, isReadOnly = false, parentName = null) {
        // Construire le displayName selon le contexte utilisateur
        let displayName = campaign.Name || '';
        let childDisplayName = null;

        // Si l'utilisateur n'est pas guest, séparer parent et enfant
        if (!this.isGuestUser) {
            if (parentName) {
                displayName = parentName;
                childDisplayName = campaign.Name || '';
            } else if (campaign.ChildCampaigns && Array.isArray(campaign.ChildCampaigns) && campaign.ChildCampaigns.length > 0) {
                const firstChild = campaign.ChildCampaigns[0];
                const childName = firstChild && firstChild.Name ? firstChild.Name : '';
                if (childName) {
                    childDisplayName = childName;
                }
            }
        }

        return {
            ...campaign,
            displayName: displayName,
            childDisplayName: childDisplayName,
            hasChildName: !!childDisplayName,
            displayDate: this.formatDate(campaign.DateDerniereConnexion__c, "short"),
            displayCreatedDate: this.formatDate(campaign.CreatedDate, "short"),
            isActiveStatus: campaign.IsActive ? this.txt.actif : this.txt.inactif,
            statusClass: campaign.IsActive ? 'status-active' : 'status-inactive',
            isInactive: !campaign.IsActive,
            commentaire: campaign.commentaireRegie__c || '',
            email: campaign.Email__c || '',
            telephone: campaign.Telephone__c || '',
            isReadOnly: isReadOnly,
            parentName: parentName
        };
    }

    /**
     * Rafraîchit les donnés selon le mode
     */
    refreshCampaigns() {
        if (this.isGuestUser && this.parentToken) {
            this.loadGuestCampaigns();
        } else if (this.parentId || this._isInitialized || true) {
            this.loadAuthenticatedCampaignsWithChildren();
        } else {
            // return refreshApex(this.wiredCampaignsResult);
        }
        return Promise.resolve();
    }

    handleSort(event) {
        const field = event.currentTarget.dataset.field;
        if (!field) return;

        // toggle direction if same field
        if (this.sortField === field) {
            this.sortDirection = this.sortDirection === 'asc' ? 'desc' : 'asc';
        } else {
            this.sortField = field;
            this.sortDirection = 'asc';
        }

        this.sortCampaigns();
    }

    sortCampaigns() {
        if (!this.campaigns || this.campaigns.length <= 1) return;

        const field = this.sortField;
        const dir = this.sortDirection === 'asc' ? 1 : -1;

        const compare = (a, b) => {
            let va = a[field];
            let vb = b[field];

            // Fallbacks for commonly used fields
            if (field === 'displayName' || field === 'Name') {
                va = (a.displayName || a.Name || '') + '';
                vb = (b.displayName || b.Name || '') + '';
                return va.localeCompare(vb) * dir;
            }

            if (field === 'CreatedDate' || field === 'DateDerniereConnexion__c') {
                // Try to use raw date fields if present, otherwise formatted strings
                const da = a[field] ? new Date(a[field]) : (a.CreatedDate ? new Date(a.CreatedDate) : null);
                const db = b[field] ? new Date(b[field]) : (b.CreatedDate ? new Date(b.CreatedDate) : null);
                const ta = da ? da.getTime() : 0;
                const tb = db ? db.getTime() : 0;
                return (ta - tb) * dir;
            }

            // Generic string/number compare
            va = va === undefined || va === null ? '' : va;
            vb = vb === undefined || vb === null ? '' : vb;

            if (!isNaN(Number(va)) && !isNaN(Number(vb))) {
                return (Number(va) - Number(vb)) * dir;
            }

            return (('' + va).localeCompare('' + vb)) * dir;
        };

        this.campaigns.sort(compare);
        this.campaigns = [...this.campaigns];
    }

    // Getters pour template LWC (conditions boolénnes autorisés)
    get isSortDisplayName() {
        return this.sortField === 'displayName';
    }

    get isSortCreatedDate() {
        return this.sortField === 'CreatedDate';
    }

    get isSortDateDerniere() {
        return this.sortField === 'DateDerniereConnexion__c';
    }

    get isSortEmail(){
        return this.sortField === 'Email__c';
    }

    get isSortCommentaire() {
        return this.sortField === 'commentaire';
    }

    get isSortIsActiveStatus() {
        return this.sortField === 'isActiveStatus';
    }

    get isSortPeutCreerRegie() {
        return this.sortField === 'PeutCreerREGIE__c';
    }

    get sortIndicator() {
        return this.sortDirection === 'asc' ? '▲' : '▼';
    }

    // @wire(getMyCampagnes)
    // wiredCampaigns(result) {
    //     // Ne pas utiliser le @wire si on est en mode guest ou avec parentId
    //     if (this.isGuestUser || this.parentId || this._isInitialized) {
    //         return;
    //     }

    //     this.wiredCampaignsResult = result;
    //     const { error, data } = result;
    //     if (data) {
    //         console.log('Loaded Campaigns:', JSON.stringify(data));
    //         this.campaigns = data.map(campaign => this.mapCampaignData(campaign, false));
    //         this.isLoading = false;
    //     } else if (error) {
    //         console.error('Error loading campaigns:', error);
    //         this.showToast(this.txt.erreur, 'Erreur lors du chargement des REGIES', 'error');
    //         this.isLoading = false;
    //     }
    // }

    handleNewCampaign() {
        const allProducts = (this.produitsPicklistValues || []).map(p => p.value);
        const isAppAff = this.isApporteurAffaires;
        const isGuest = this.isGuestUser;

        // Produits :
        //  - Apporteur d'Affaires : tous présélectionnés (UI cachée).
        //  - Guest (Regie 1) : laissés vides → Apex hérite du parent.
        //  - Autres : tous présélectionnés, l'utilisateur peut désélectionner.
        const produitsInitiaux = isGuest ? [] : allProducts;

        // Simulateurs :
        //  - Apporteur d'Affaires : 'OUI' par défaut (UI cachée).
        //  - Sinon : null (le Regie 1 choisira en mode guest).
        const simInitial = isAppAff ? 'OUI' : null;

        this.formData = {
            name: '',
            nomSociete: '',
            commentaire: '',
            email: '',
            telephone: '',
            isActive: true,
            peutCreerRegie: !this.isGuestUser,
            envoyerEmail: false,
            envoyerSMS: false,
            produitsDisponibles: produitsInitiaux,
            creerAcces: true,
            motDePasse: this.generateRandomPassword(),
            avoirAccesCEE: !this.isApporteurInterne,
            simulateurBatTh179: simInitial,
            simulateurBatTh163: simInitial
        };
        this.fieldErrors = { name: '', nomSociete: '', email: '', telephone: '', motDePasse: '', simulateurBatTh179: '', simulateurBatTh163: '' };
        this.showCreateModal = true;
    }

    handleCreateSave() {
        if (!this.validateForm()) {
            return;
        }

        this.isLoading = true;
        const campaignData = {
            name: this.formData.name,
            nomSociete: this.formData.nomSociete,
            commentaire: this.formData.commentaire,
            email: this.formData.email,
            telephone: this.formData.telephone,
            isActive: this.formData.isActive,
            peutCreerRegie: this.formData.peutCreerRegie,
            produitsDisponibles: this.formData.produitsDisponibles,
            parentId: this.parentId,
            creerAcces: this.formData.creerAcces,
            motDePasse: this.generateRandomPassword(),
            avoirAccesCEE: this.formData.avoirAccesCEE,
            // Simulateurs : la valeur est portée par formData (forcée à 'OUI' pour les
            // Apporteur d'Affaires, choisie en mode guest, null sinon).
            simulateurBatTh179: this.formData.simulateurBatTh179 || null,
            simulateurBatTh163: this.formData.simulateurBatTh163 || null
        };

        const shouldSendEmail = this.formData.envoyerEmail;
        const shouldSendSMS = this.formData.envoyerSMS;

        createCampaign({ campaignJson: JSON.stringify(campaignData) })
            .then((campaignId) => {
                this.showToast(this.txt.succes, this.txt.succesCreation, 'success');
                this.showCreateModal = false;

                const promises = [];

                // if (shouldSendEmail && campaignId) {
                //     promises.push(
                //         sendCampaignEmail({ campaignId: campaignId })
                //             .catch((error) => {
                //                 const message = error.body?.message || this.txt.errEnvoiEmail;
                //                 this.showToast(this.txt.erreur, message, 'error');
                //             })
                //     );
                // }

                // if (shouldSendSMS && campaignId) {
                //     promises.push(
                //         sendCampaignSMS({ campaignId: campaignId })
                //             .then((result) => {
                //                 this.showToast(this.txt.succes, result, 'success');
                //             })
                //             .catch((error) => {
                //                 const message = error.body?.message || 'Erreur lors de l\'envoi du SMS';
                //                 this.showToast(this.txt.erreur, message, 'error');
                //             })
                //     );
                // }

                if (promises.length > 0) {
                    return Promise.all(promises).then(() => this.refreshCampaigns());
                }
                return this.refreshCampaigns();
            })
            .then(() => {
                this.isLoading = false;
            })
            .catch(error => {
                if(error.body?.message) {
                    this.showToast(this.txt.erreur, error.body.message, 'error');
                } else {
                    console.error('Error creating campaign:', error);
                    this.showToast(this.txt.erreur, this.txt.errCreation, 'error');
                }
                this.isLoading = false;
            });
    }

    handleEditCampaign(event) {
        const campaignId = event.currentTarget.dataset.id;
        this.selectedCampaign = this.campaigns.find(c => c.Id === campaignId);

        // Vérifier si la campagne est en lecture seule
        if (this.selectedCampaign.isReadOnly) {
            this.showToast(this.txt.information, this.txt.lectureSeuleMsg, 'info');
            return;
        }

        // Parse description to extract contact info
        const description = this.selectedCampaign.Description || '';
        const lines = description.split('\n');
        
        // Récupérer les produits depuis ProduitsDisponibles__c
        let produitsDisponibles = [];
        if (this.selectedCampaign.ProduitsDisponibles__c) {
            produitsDisponibles = this.selectedCampaign.ProduitsDisponibles__c.split(';').map(p => p.trim());
        }
        
        const existingPhone = this.selectedCampaign.telephone || this.extractValue(lines, 'Téléphone:');

        const isAppAff = this.isApporteurAffaires;
        const allProducts = (this.produitsPicklistValues || []).map(p => p.value);

        this.formData = {
            name: this.selectedCampaign.Name,
            commentaire: this.selectedCampaign.commentaire || this.extractValue(lines, 'Commentaire:'),
            email: this.selectedCampaign.email || this.extractValue(lines, 'Email:'),
            telephone: existingPhone,
            isActive: !this.selectedCampaign.isInactive,
            peutCreerRegie: this.isGuestUser ? false : true,
            // Apporteur d'Affaires : on force tous les produits + simulateurs OUI/OUI
            // (cohérent avec la création : section non affichée → toujours par défaut).
            produitsDisponibles: isAppAff ? allProducts : produitsDisponibles,
            simulateurBatTh179: isAppAff ? 'OUI' : (this.selectedCampaign.Simulateur_BAT_TH179__c || null),
            simulateurBatTh163: isAppAff ? 'OUI' : (this.selectedCampaign.Simulateur_BAT_TH163__c || null)
        };
        this.fieldErrors = { name: '', email: '', telephone: '', simulateurBatTh179: '', simulateurBatTh163: '' };

        this.showEditModal = true;
    }

    handleEditSave() {
        if (!this.validateForm()) {
            return;
        }

        this.isLoading = true;
        const campaignData = {
            campaignId: this.selectedCampaign.Id,
            name: this.formData.name,
            commentaire: this.formData.commentaire,
            email: this.formData.email,
            telephone: this.formData.telephone,
            isActive: this.formData.isActive,
            peutCreerRegie: this.formData.peutCreerRegie,
            produitsDisponibles: this.formData.produitsDisponibles,
            // Simulateurs : la valeur est portée par formData (forcée à 'OUI' pour les
            // Apporteur d'Affaires, choisie en mode guest, sinon valeur d'origine).
            simulateurBatTh179: this.formData.simulateurBatTh179 || null,
            simulateurBatTh163: this.formData.simulateurBatTh163 || null
        };

        console.log('Updating Campaign with Data:', JSON.stringify(campaignData));

        updateCampaign({ campaignJson: JSON.stringify(campaignData) })
            .then(() => {
                this.showToast(this.txt.succes, this.txt.succesMaj, 'success');
                this.showEditModal = false;
                return this.refreshCampaigns();
            })
            .then(() => {
                this.isLoading = false;
            })
            .catch(error => {
                if(error.body?.message) {
                    this.showToast(this.txt.erreur, error.body.message, 'error');
                } else {
                console.error('Error updating campaign:', error);
                this.showToast(this.txt.erreur, this.txt.errMaj, 'error');
                }
                this.isLoading = false;
            });
    }

    handleToggleCampaignStatus(event) {
        const campaignId = event.currentTarget.dataset.id;
        const campaign = this.campaigns.find(c => c.Id === campaignId);

        if (!campaign) {
            return;
        }

        // Vérifier si la campagne est en lecture seule
        if (campaign.isReadOnly) {
            this.showToast(this.txt.information, this.txt.lectureSeuleMsg, 'info');
            return;
        }
        console.log('Toggling status for Campaign:', JSON.stringify(campaign));
        // Inverser le statut
        const newStatus = !campaign.IsActive;
        
        this.isLoading = true;
        const campaignData = {
            campaignId: campaignId,
            isActive: newStatus
        };
        
        updateCampaign({ campaignJson: JSON.stringify(campaignData) })
            .then(() => {
                const statusText = newStatus ? this.txt.statutActive : this.txt.statutDesactive;
                this.showToast(this.txt.succes, remplir(this.txt.succesStatut, { statut: statusText }), 'success');
                
                // Mise à jour optimiste de l'affichage
                campaign.IsActive = newStatus;
                campaign.isActiveStatus = newStatus ? this.txt.actif : this.txt.inactif;
                campaign.statusClass = newStatus ? 'status-active' : 'status-inactive';
                campaign.isInactive = !newStatus;
                
                // Force reactivity
                this.campaigns = [...this.campaigns];

                return this.refreshCampaigns();
            })
            .then(() => {
                this.isLoading = false;
            })
            .catch(error => {
                console.error('Error updating campaign status:', error);
                this.showToast(this.txt.erreur, this.txt.errStatut, 'error');
                this.isLoading = false;
            });
    }

    handleShowDetails(event) {
        const campaignId = event.currentTarget.dataset.id;
        this.selectedCampaign = this.campaigns.find(c => c.Id === campaignId);
        this.showDetailsModal = true;
    }

    handleCopyLink(event) {
        const campaignId = event.currentTarget.dataset.id;
        this.selectedCampaign = this.campaigns.find(c => c.Id === campaignId);
        console.log('Selected Campaign for Copy Link:', JSON.stringify(this.selectedCampaign));
        const campaignCode = this.selectedCampaign.CampaignToken__c;
        
        // Construire l'URL complète avec le base URL du custom label
        const fullUrl = `${this.baseUrl}?c__code=${campaignCode}`;
        
        navigator.clipboard.writeText(fullUrl).then(() => {
            this.showToast(this.txt.succes, this.txt.succesCopie, 'success');
        }).catch(() => {
            this.showToast(this.txt.erreur, this.txt.errCopie, 'error');
        });
    }

    /**
     * Copie Campaign.LienConnexion__c — champ FORMULE de l'org :
     *   IF(Pays__c = 'Espagne', $Label.RENOV_Campagne_Base_URL_ES,
     *      $Label.RENOV_Campagne_Base_URL) & '?c__code=' & CampaignToken__c
     *
     * A ne pas confondre avec handleCopyLink, qui RECONSTRUIT l'URL en JS et
     * emploie toujours la base FR : pour une campagne espagnole les deux liens
     * different. C'est le champ qui fait foi, on ne recalcule rien ici.
     *
     * Reserve aux Apporteurs d'Affaires internes (isApporteurInterne) : eux
     * seuls transmettent ce lien, les autres passent par « Se Connecter ».
     */
    handleCopyLienConnexion(event) {
        const campaignId = event.currentTarget.dataset.id;
        const campaign = this.campaigns.find(c => c.Id === campaignId);
        const lien = campaign && campaign.LienConnexion__c;
        // Formule vide = campagne sans token : rien a copier, et un
        // presse-papiers vide serait pire qu'un message d'erreur.
        if (!lien) {
            this.showToast(this.txt.erreur, this.txt.errCopie, 'error');
            return;
        }
        navigator.clipboard.writeText(lien).then(() => {
            this.showToast(this.txt.succes, this.txt.succesCopieLienConnexion, 'success');
        }).catch(() => {
            this.showToast(this.txt.erreur, this.txt.errCopie, 'error');
        });
    }

    handleSendEmail() {
        if (!this.selectedCampaign) return;
        this.isSendingEmail = true;
        sendCampaignEmail({ campaignId: this.selectedCampaign.Id })
            .then((result) => {
                this.showToast(this.txt.succes, result, 'success');
            })
            .catch((error) => {
                const message = error.body?.message || this.txt.errEnvoiEmail;
                this.showToast(this.txt.erreur, message, 'error');
            })
            .finally(() => {
                this.isSendingEmail = false;
            });
    }

    handleSendSMS() {
        if (!this.selectedCampaign) return;
        this.isSendingSMS = true;
        // sendCampaignSMS({ campaignId: this.selectedCampaign.Id })
        //     .then((result) => {
        //         this.showToast(this.txt.succes, result, 'success');
        //     })
        //     .catch((error) => {
        //         const message = error.body?.message || 'Erreur lors de l\'envoi du SMS';
        //         this.showToast(this.txt.erreur, message, 'error');
        //     })
        //     .finally(() => {
        //         this.isSendingSMS = false;
        //     });
    }

    handleResetPassword() {
        const email = this.formData.email;
        if (!email || !this.isValidEmail(email)) {
            this.showToast(this.txt.erreur, this.txt.errEmailAvantReinit, 'error');
            return;
        }
        this.isResettingPassword = true;
        reinitialiserMotDePasse({ email: email })
            .then(result => {
                if (result.success) {
                    this.showToast(this.txt.succes, remplir(this.txt.succesReinit, { email }), 'success');
                } else {
                    this.showToast(this.txt.erreur, result.message || this.txt.errReinit, 'error');
                }
            })
            .catch(error => {
                const message = error.body?.message || this.txt.errReinit;
                this.showToast(this.txt.erreur, message, 'error');
            })
            .finally(() => {
                this.isResettingPassword = false;
            });
    }

    handleChangerEmail(oldEmail, newEmail) {
        changerEmail({ oldEmail: oldEmail, newEmail: newEmail })
            .then(result => {
                if (result.success) {
                    this.showToast(this.txt.succes, this.txt.succesChangementEmail, 'success');
                } else {
                    this.showToast(this.txt.erreur, result.message || this.txt.errChangementEmail, 'error');
                }
            })
            .catch(error => {
                const message = error.body?.message || this.txt.errChangementEmail;
                this.showToast(this.txt.erreur, message, 'error');
            });
    }

    handleViewRecord(event) {
        const campaignId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: campaignId,
                actionName: 'view'
            }
        });
    }

    handleCloseModal() {
        this.showCreateModal = false;
        this.showEditModal = false;
        this.showDetailsModal = false;
        this.selectedCampaign = null;
        this.fieldErrors = { name: '', nomSociete: '', email: '', telephone: '', motDePasse: '' };
    }

    handleOpenInfoModal() {
        this.showInfoModal = true;
    }

    handleCloseInfoModal() {
        this.showInfoModal = false;
    }

    handleInputChange(event) {
        const field = event.currentTarget.dataset.field;

        // Handle dual-listbox component (returns array via detail.value)
        if (event.detail && Array.isArray(event.detail.value)) {
            this.formData[field] = event.detail.value;
        } else if (field === 'telephone') {
            // Phone mask: only allow digits, max 10
            let raw = event.target.value.replace(/[^\d]/g, '');
            if (raw.length > 10) {
                raw = raw.substring(0, 10);
            }
            this.formData.telephone = raw;
            event.target.value = raw;
            // Clear error on valid input
            if (/^0\d{9}$/.test(raw)) {
                this.fieldErrors = { ...this.fieldErrors, telephone: '' };
            }
        } else {
            const isCheckbox = event.currentTarget.type === 'checkbox';
            this.formData[field] = isCheckbox ? event.currentTarget.checked : event.target.value;
        }

        // Clear field error on change
        if (field === 'name' && this.formData.name.trim()) {
            this.fieldErrors = { ...this.fieldErrors, name: '' };
        }
        if (field === 'nomSociete' && this.formData.nomSociete.trim()) {
            this.fieldErrors = { ...this.fieldErrors, nomSociete: '' };
        }
        if (field === 'email') {
            if (this.formData.email.trim() && this.isValidEmail(this.formData.email)) {
                this.fieldErrors = { ...this.fieldErrors, email: '' };
            }
        }
    }

    validateForm() {
        let isValid = true;
        const errors = { name: '', nomSociete: '', email: '', telephone: '', motDePasse: '' };

        // Validate name
        if (!this.formData.name.trim()) {
            errors.name = this.txt.errNomRequis;
            isValid = false;
        }

        // Validate nomSociete (obligatoire pour les Apporteur d'Affaires à la création)
        if (this.showNomSociete && !this.formData.nomSociete?.trim()) {
            errors.nomSociete = this.txt.errSocieteRequise;
            isValid = false;
        }

        // Validate email
        if (!this.formData.email.trim()) {
            errors.email = this.txt.errEmailRequis;
            isValid = false;
        } else if (!this.isValidEmail(this.formData.email)) {
            errors.email = this.txt.errEmailFormat;
            isValid = false;
        }

        // Validate telephone (must be exactly 10 digits starting with 0)
        if (!this.formData.telephone || !this.formData.telephone.trim()) {
            // Téléphone obligatoire pour les Apporteur d'Affaires (création + modification)
            if (this.isApporteurAffaires) {
                errors.telephone = this.txt.errTelephoneRequis;
                isValid = false;
            }
        } else if (!/^0\d{9}$/.test(this.formData.telephone)) {
            errors.telephone = this.txt.errTelephoneFormat;
            isValid = false;
        }

        this.fieldErrors = errors;

        if (!isValid) {
            // this.showToast(this.txt.erreur, 'Veuillez corriger les erreurs dans le formulaire', 'error');
            return false;
        }

        // // Valider le mot de passe si "Créer accès avec mot de passe" est coché
        // if (this.formData.creerAcces) {
        //     if (!this.formData.motDePasse || this.formData.motDePasse.length < 8) {
        //         errors.motDePasse = 'Le mot de passe doit contenir au moins 8 caractères';
        //         isValid = false;
        //     }
        // }

        this.fieldErrors = errors;

        if (!isValid) {
            return false;
        }

        // Validate produits
        if (!this.isGuestUser && !this.formData.produitsDisponibles?.length) {
            this.showToast(this.txt.erreur, this.txt.errProduitRequis, 'error');
            return false;
        }

        // Validate simulateurs : toggles obligatoires uniquement si affichés (mode guest avec produit).
        if (this.showSimulateurTH179 || this.showSimulateurTH163) {
            const simErrors = { ...this.fieldErrors };
            let simValid = true;
            if (this.showSimulateurTH179 && !this.formData.simulateurBatTh179) {
                simErrors.simulateurBatTh179 = this.txt.errChoixOuiNon;
                simValid = false;
            }
            if (this.showSimulateurTH163 && !this.formData.simulateurBatTh163) {
                simErrors.simulateurBatTh163 = this.txt.errChoixOuiNon;
                simValid = false;
            }
            this.fieldErrors = simErrors;
            if (!simValid) return false;
        }

        return true;
    }

    get hasNameError() {
        return !!this.fieldErrors.name;
    }

    // Nom Société : affiché et obligatoire uniquement pour les Apporteur d'Affaires
    // au moment de la création de la régie.
    get showNomSociete() {
        return this.isApporteurAffaires && this.showCreateModal;
    }

    get hasNomSocieteError() {
        return !!this.fieldErrors.nomSociete;
    }

    get nomSocieteInputClass() {
        return this.fieldErrors.nomSociete ? 'form-input has-icon input-error' : 'form-input has-icon';
    }

    get hasEmailError() {
        return !!this.fieldErrors.email;
    }

    get hasTelephoneError() {
        return !!this.fieldErrors.telephone;
    }

    get hasMotDePasseError() {
        return !!this.fieldErrors.motDePasse;
    }

    /**
     * Génère un mot de passe aléatoire de 8 caractères (lettres + chiffres)
     */
    generateRandomPassword() {
        // const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
        // let pwd = '';
        // for (let i = 0; i < 8; i++) {
        //     pwd += chars.charAt(Math.floor(Math.random() * chars.length));
        // }
        // return pwd;
        return '123456';
    }

    /**
     * Gère la case à cocher "Créer accès avec mot de passe"
     * Si cochée, génère automatiquement un mot de passe de 8 caractères
     */
    handleCreerAccesChange(event) {
        const isChecked = event.currentTarget.checked;
        this.formData = { ...this.formData, creerAcces: isChecked };
        if (isChecked && !this.formData.motDePasse) {
            this.formData = { ...this.formData, motDePasse: this.generateRandomPassword() };
        }
        this.fieldErrors = { ...this.fieldErrors, motDePasse: '' };
    }

    /**
     * Régénère un nouveau mot de passe aléatoire
     */
    handleRegeneratePassword() {
        this.formData = { ...this.formData, motDePasse: this.generateRandomPassword() };
        this.fieldErrors = { ...this.fieldErrors, motDePasse: '' };
    }

    get nameInputClass() {
        return this.fieldErrors.name ? 'form-input has-icon input-error' : 'form-input has-icon';
    }

    get emailInputClass() {
        return this.fieldErrors.email ? 'form-input has-icon input-error' : 'form-input has-icon';
    }

    get telephoneInputClass() {
        return this.fieldErrors.telephone ? 'form-input has-icon phone-input input-error' : 'form-input has-icon phone-input';
    }

    isValidEmail(email) {
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        return emailRegex.test(email);
    }

    extractValue(lines, prefix) {
        // const line = lines.find(l => l.includes(prefix));
        // if (line) {
        //     return line.replace(prefix, '').trim();
        // }
        return '';
    }

    formatDate(date, type) {
        if (!date) return '-';
        const d = new Date(date);
        // return d.toLocaleDateString('fr-FR', { year: 'numeric', month: 'long', day: 'numeric' });
        if(type == "short"){
            // dd/mm/yyyy
            return d.toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit', year: 'numeric' });
        } else {
            return d.toLocaleString('fr-FR');
        }
    }

    showToast(title, message, variant) {
        // Sur mobile, lightning/toast n'affiche que le label (le message est masqué).
        // On fusionne titre + message dans le label pour garantir la visibilité sur tous les supports.
        const label = message ? `${title} — ${message}` : title;
        Toast.show({
            label: label,
            mode: 'dismissible',
            variant: variant
        }, this);
    }

    get selectedCampaignFullLink() {
        if (!this.selectedCampaign || !this.selectedCampaign.CampaignToken__c) return '';
        return `${this.baseUrl}?c__code=${this.selectedCampaign.CampaignToken__c}`;
    }

    get hasNoCampaigns() {
        return !this.isLoading && this.campaigns.length === 0;
    }

    get isCeeLoginChecked() {
        return this.formData.avoirAccesCEE === true;
    }

    get isCeeLienChecked() {
        return this.formData.avoirAccesCEE === false;
    }

    handleCeeAccesChange(event) {
        this.formData = { ...this.formData, avoirAccesCEE: event.target.value === 'true' };
    }

    get showActiverCEE() {
        return this.isApporteurInterne && this.selectedCampaign && !this.selectedCampaign.AvoirAccesCEE__c;
    }

    get showResetPassword() {
        return this.selectedCampaign.AvoirAccesCEE__c;
    }

    handleActiverCEE() {
        if (!this.selectedCampaign) return;
        this.isActivatingCEE = true;
        activerCEE({ campaignId: this.selectedCampaign.Id })
            .then((result) => {
                this.showToast(this.txt.succes, result, 'success');
                // Mettre à jour localement pour masquer le bouton immédiatement
                this.selectedCampaign = { ...this.selectedCampaign, AvoirAccesCEE__c: true };
                return this.refreshCampaigns();
            })
            .catch((error) => {
                const message = error.body?.message || this.txt.errActivationCee;
                this.showToast(this.txt.erreur, message, 'error');
            })
            .finally(() => {
                this.isActivatingCEE = false;
            });
    }

    // ===== Produits disponibles : liste à cases à cocher =====
    get produitsAffichage() {
        const selected = this.formData?.produitsDisponibles || [];
        return (this.produitsPicklistValues || []).map(p => ({
            value: p.value,
            label: p.label,
            checked: selected.includes(p.value),
            itemClass: selected.includes(p.value) ? 'produit-item is-checked' : 'produit-item'
        }));
    }

    handleProduitCheckboxChange(event) {
        const value = event.target.value;
        const checked = event.target.checked;
        let current = [...((this.formData && this.formData.produitsDisponibles) || [])];

        if (checked && !current.includes(value)) {
            current.push(value);
        } else if (!checked) {
            current = current.filter(v => v !== value);
        }

        const updated = { ...this.formData, produitsDisponibles: current };
        const updatedErrors = { ...this.fieldErrors };

        // Si le produit lié au simulateur est décoché, on réinitialise la valeur
        if (!checked && value === PRODUIT_BAT_TH179) {
            updated.simulateurBatTh179 = null;
            updatedErrors.simulateurBatTh179 = '';
        }
        if (!checked && value === PRODUIT_BAT_TH163) {
            updated.simulateurBatTh163 = null;
            updatedErrors.simulateurBatTh163 = '';
        }

        this.formData = updated;
        this.fieldErrors = updatedErrors;
    }

    // ===== Simulateurs BAT =====
    // En mode guest (Regie 1 → Regie 2) : on demande au Regie 1 s'il veut donner accès au simulateur.
    // La question apparaît seulement si le compte actif possède le produit lié.
    // Jamais en Espagne : TH179 et TH163 sont des produits France (pays: ["France"]
    // dans PRODUCT_CATALOG), leurs simulateurs de commission n'ont aucun sens pour
    // une régie espagnole. Le filtre porte sur le PAYS et non sur
    // ProduitsDisponibles__c, car une campagne espagnole peut malgré tout avoir ces
    // codes produits dans sa picklist — c'est le cas aujourd'hui de « Regie Esp1 ».
    // Masquer ici suffit aussi à lever la validation : validateForm() conditionne
    // les toggles obligatoires à ces mêmes getters, et la valeur envoyée reste null.
    get showSimulateurTH179() {
        return this.isGuestUser && this.currentUserHasTH179 && !this.estEspagne;
    }

    get showSimulateurTH163() {
        return this.isGuestUser && this.currentUserHasTH163 && !this.estEspagne;
    }

    get showSimulateursSection() {
        return this.showSimulateurTH179 || this.showSimulateurTH163;
    }

    // Plus de gestion d'état "désactivé" — on affiche ou on cache.
    get isSimTH179Disabled() { return false; }
    get isSimTH163Disabled() { return false; }

    get simTH179CardClass() {
        return this.hasSimTH179Error ? 'simulateur-card is-error' : 'simulateur-card';
    }
    get simTH163CardClass() {
        return this.hasSimTH163Error ? 'simulateur-card is-error' : 'simulateur-card';
    }

    // Message d'erreur consolidé pour la colonne simulateurs
    get simulateursErrorMessage() {
        const labels = [];
        if (this.hasSimTH179Error) labels.push('TH179');
        if (this.hasSimTH163Error) labels.push('TH163');
        if (labels.length === 0) return '';
        return remplir(this.txt.errSimulateurs, { labels: labels.join(this.txt.joignantEt) });
    }

    get hasSimulateursError() {
        return this.hasSimTH179Error || this.hasSimTH163Error;
    }

    get isSimTH179Oui() { return this.formData.simulateurBatTh179 === 'OUI'; }
    get isSimTH179Non() { return this.formData.simulateurBatTh179 === 'NON'; }
    get isSimTH163Oui() { return this.formData.simulateurBatTh163 === 'OUI'; }
    get isSimTH163Non() { return this.formData.simulateurBatTh163 === 'NON'; }

    get hasSimTH179Error() { return !!this.fieldErrors.simulateurBatTh179; }
    get hasSimTH163Error() { return !!this.fieldErrors.simulateurBatTh163; }

    handleSimTH179Change(event) {
        if (this.isSimTH179Disabled) return;
        this.formData = { ...this.formData, simulateurBatTh179: event.target.value };
        this.fieldErrors = { ...this.fieldErrors, simulateurBatTh179: '' };
    }

    handleSimTH163Change(event) {
        if (this.isSimTH163Disabled) return;
        this.formData = { ...this.formData, simulateurBatTh163: event.target.value };
        this.fieldErrors = { ...this.fieldErrors, simulateurBatTh163: '' };
    }

    stopPropagation(event) {
        event.stopPropagation();
    }
}