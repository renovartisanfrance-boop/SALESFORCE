import { LightningElement, api, track, wire } from 'lwc';
import getLeadsByCampaignToken from '@salesforce/apex/LC020_GestionCampagnes.getLeadsByCampaignToken';
import getCampaignByToken from '@salesforce/apex/LC020_GestionCampagnes.getCampaignByToken';
import apiEndpoint from '@salesforce/label/c.GESTION_RDV_EXTERNE_API_ENDPOINT';
import { estModeGenerateur } from 'c/lwc000_utils';

export default class Lwc020_MyReporting extends LightningElement {
    apiEndpoint = apiEndpoint;

    _campaignCode;
    @api
    get campaignCode() {
        if (this._campaignCode) return this._campaignCode;
        try { return localStorage.getItem('renov_campaign_token'); } catch (e) { return null; }
    }
    set campaignCode(value) {
        this._campaignCode = value;
        if (value) {
            this.loadLeads();
            this.loadCampaign();
        }
    }
    
    @track leads = [];
    @track campaign = null;
    @track isLoading = true;
    @track selectedLead = null;
    @track showDetails = false;
    @track hasError = false;
    @track errorMessage = '';
    @track searchTerm = '';
    @track currentPage = 1;
    @track pageSize = 50;

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
        // Si le token vient du localStorage (pas de @api), déclencher le chargement
        if (!this._campaignCode && this.campaignCode) {
            this.loadLeads();
            this.loadCampaign();
        } else if (!this.campaignCode) {
            this._redirectInvalidToken();
        }
    }

    loadLeads() {
        this.isLoading = true;
        this.currentPage = 1;
        getLeadsByCampaignToken({ campaignToken: this.campaignCode })
            .then(data => {
                this.leads = data.map(lead => ({
                    ...lead,
                    formattedDate: this.formatDate(lead.CreatedDate)
                }));
                this.isLoading = false;
                this.hasError = false;
            })
            .catch(error => {
                console.error('Invalid or not found campaign token, redirecting:', error);
                this._redirectInvalidToken();
            });
    }

    loadCampaign() {
        getCampaignByToken({ campaignToken: this.campaignCode })
            .then(data => {
                this.campaign = data;
            })
            .catch(error => {
                console.error('Invalid or not found campaign token, redirecting:', error);
                this._redirectInvalidToken();
            });
    }

    formatDate(date) {
        if (!date) return '-';
        const d = new Date(date);
        return d.toLocaleDateString('fr-FR', { year: 'numeric', month: 'long', day: 'numeric' });
    }

    handleViewDetails(event) {
        const leadId = event.currentTarget.dataset.id;
        this.selectedLead = this.filteredLeads.find(l => l.Id === leadId);
        this.showDetails = true;
    }

    handleCloseDetails() {
        this.showDetails = false;
        this.selectedLead = null;
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value.toLowerCase();
        this.currentPage = 1;
    }

    handlePageSizeChange(event) {
        this.pageSize = parseInt(event.target.value);
        this.currentPage = 1;
    }

    handlePreviousPage() {
        if (this.currentPage > 1) {
            this.currentPage--;
        }
    }

    handleNextPage() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
        }
    }

    handlePageChange(event) {
        this.currentPage = parseInt(event.target.value);
    }

    get filteredLeads() {
        if (!this.searchTerm) {
            return this.leads;
        }
        return this.leads.filter(lead => {
            const fullName = `${lead.FirstName} ${lead.LastName}`.toLowerCase();
            const email = (lead.Email || '').toLowerCase();
            const phone = (lead.Phone || '').toLowerCase();
            const company = (lead.Company || '').toLowerCase();
            
            return fullName.includes(this.searchTerm) || 
                   email.includes(this.searchTerm) || 
                   phone.includes(this.searchTerm) || 
                   company.includes(this.searchTerm);
        });
    }

    get paginatedLeads() {
        const start = (this.currentPage - 1) * this.pageSize;
        const end = start + this.pageSize;
        return this.filteredLeads.slice(start, end);
    }

    get totalPages() {
        return Math.ceil(this.filteredLeads.length / this.pageSize) || 1;
    }

    get hasLeads() {
        return this.paginatedLeads && this.paginatedLeads.length > 0;
    }

    get totalLeads() {
        return this.leads.length;
    }

    get filteredLeadsCount() {
        return this.filteredLeads.length;
    }

    get leadsWithEmail() {
        return this.leads.filter(l => l.Email).length;
    }

    get leadsWithPhone() {
        return this.leads.filter(l => l.Phone).length;
    }

    get paginationInfo() {
        const start = (this.currentPage - 1) * this.pageSize + 1;
        const end = Math.min(this.currentPage * this.pageSize, this.filteredLeadsCount);
        return `${start}-${end} sur ${this.filteredLeadsCount}`;
    }

    get canPreviousPage() {
        return this.currentPage > 1;
    }

    get canNextPage() {
        return this.currentPage < this.totalPages;
    }

    get pageNumbers() {
        const pages = [];
        for (let i = 1; i <= this.totalPages; i++) {
            pages.push(i);
        }
        return pages;
    }

    get isValidCampaign() {
        return !this.hasError && this.campaign && this.campaign.IsActive;
    }

    get isCampaignInactive() {
        return !this.hasError && this.campaign && !this.campaign.IsActive;
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    handleRefresh() {
        this.loadLeads();
    }
}