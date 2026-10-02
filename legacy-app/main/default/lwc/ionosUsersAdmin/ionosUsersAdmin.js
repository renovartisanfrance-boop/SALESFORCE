import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';
import getUsers from '@salesforce/apex/IonosUsersService.getUsers';
import createUser from '@salesforce/apex/IonosUsersService.createUser';
import updateUser from '@salesforce/apex/IonosUsersService.updateUser';
import deleteUser from '@salesforce/apex/IonosUsersService.deleteUser';

const SEARCH_DEBOUNCE_MS = 350;
const PAGE_SIZE = 10;

const COLUMNS = [
    { label: 'ID', fieldName: 'id', type: 'number', initialWidth: 70, cellAttributes: { alignment: 'left' } },
    { label: 'Login', fieldName: 'login', type: 'text' },
    { label: 'Email', fieldName: 'email', type: 'email' },
    { label: 'URL de redirection', fieldName: 'redirectUrl', type: 'text' },
    { label: 'Doit changer son mot de passe', fieldName: 'firstLogin', type: 'boolean', initialWidth: 140 },
    { label: 'Créé le', fieldName: 'createdAt', type: 'text', initialWidth: 160 },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [
                { label: 'Modifier', name: 'edit' },
                { label: 'Supprimer', name: 'delete' }
            ]
        }
    }
];

export default class IonosUsersAdmin extends LightningElement {
    columns = COLUMNS;
    users = [];
    total = 0;
    totalPages = 0;
    page = 1;
    searchTerm = '';
    isLoading = false;

    showModal = false;
    isEditMode = false;
    isSaving = false;
    draft = {};

    searchTimeout;

    connectedCallback() {
        this.loadUsers();
    }

    disconnectedCallback() {
        window.clearTimeout(this.searchTimeout);
    }

    // ------------------------------------------------------------------
    // Chargement des données
    // ------------------------------------------------------------------

    async loadUsers() {
        this.isLoading = true;
        try {
            const result = await getUsers({
                searchTerm: this.searchTerm,
                page: this.page,
                pageSize: PAGE_SIZE
            });
            this.users = result.users;
            this.total = result.total;
            this.totalPages = result.totalPages;
            this.page = result.page;
        } catch (error) {
            this.showError(error);
        } finally {
            this.isLoading = false;
        }
    }

    handleSearchChange(event) {
        const value = event.target.value;
        window.clearTimeout(this.searchTimeout);
        this.searchTimeout = window.setTimeout(() => {
            this.searchTerm = value;
            this.page = 1;
            this.loadUsers();
        }, SEARCH_DEBOUNCE_MS);
    }

    handleRefresh() {
        this.loadUsers();
    }

    handlePrevious() {
        if (this.page > 1) {
            this.page -= 1;
            this.loadUsers();
        }
    }

    handleNext() {
        if (this.page < this.totalPages) {
            this.page += 1;
            this.loadUsers();
        }
    }

    // ------------------------------------------------------------------
    // Actions de ligne (modifier / supprimer)
    // ------------------------------------------------------------------

    handleRowAction(event) {
        const action = event.detail.action.name;
        const row = event.detail.row;
        if (action === 'edit') {
            this.openEditModal(row);
        } else if (action === 'delete') {
            this.confirmDelete(row);
        }
    }

    async confirmDelete(row) {
        const confirmed = await LightningConfirm.open({
            message: `Supprimer définitivement l'utilisateur « ${row.login} » (${row.email}) ?`,
            label: 'Confirmer la suppression',
            theme: 'warning'
        });
        if (!confirmed) {
            return;
        }
        this.isLoading = true;
        try {
            await deleteUser({ userId: row.id });
            this.showSuccess(`Utilisateur « ${row.login} » supprimé.`);
            // Si on vient de vider la dernière page, recule d'une page.
            if (this.users.length === 1 && this.page > 1) {
                this.page -= 1;
            }
            await this.loadUsers();
        } catch (error) {
            this.showError(error);
            this.isLoading = false;
        }
    }

    // ------------------------------------------------------------------
    // Modal création / édition
    // ------------------------------------------------------------------

    handleNewUser() {
        this.isEditMode = false;
        this.draft = { login: '', email: '', password: '', redirectUrl: '/', firstLogin: true };
        this.showModal = true;
    }

    openEditModal(row) {
        this.isEditMode = true;
        this.draft = {
            id: row.id,
            login: row.login,
            email: row.email,
            password: '',
            redirectUrl: row.redirectUrl,
            firstLogin: row.firstLogin
        };
        this.showModal = true;
    }

    handleModalKeydown(event) {
        if (event.key === 'Escape') {
            this.closeModal();
        }
    }

    closeModal() {
        this.showModal = false;
        this.draft = {};
    }

    handleDraftChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.type === 'toggle' ? event.target.checked : event.target.value;
        this.draft = { ...this.draft, [field]: value };
    }

    async handleSave() {
        if (!this.validateModalInputs()) {
            return;
        }
        this.isSaving = true;
        try {
            if (this.isEditMode) {
                await updateUser({
                    userId: this.draft.id,
                    login: this.draft.login,
                    email: this.draft.email,
                    password: this.draft.password || null,
                    redirectUrl: this.draft.redirectUrl,
                    firstLogin: this.draft.firstLogin
                });
                this.showSuccess(`Utilisateur « ${this.draft.login} » mis à jour.`);
            } else {
                await createUser({
                    login: this.draft.login,
                    email: this.draft.email,
                    password: this.draft.password,
                    redirectUrl: this.draft.redirectUrl
                });
                this.showSuccess(`Utilisateur « ${this.draft.login} » créé.`);
            }
            this.closeModal();
            await this.loadUsers();
        } catch (error) {
            this.showError(error);
        } finally {
            this.isSaving = false;
        }
    }

    validateModalInputs() {
        const inputs = [...this.template.querySelectorAll('.modal-field')];
        return inputs.reduce((allValid, input) => {
            input.reportValidity();
            return allValid && input.checkValidity();
        }, true);
    }

    // ------------------------------------------------------------------
    // Getters d'affichage
    // ------------------------------------------------------------------

    get cardSubtitle() {
        return `${this.total} utilisateur${this.total > 1 ? 's' : ''} dans la base IONOS`;
    }

    get modalTitle() {
        return this.isEditMode ? 'Modifier l\'utilisateur' : 'Nouvel utilisateur';
    }

    get saveLabel() {
        return this.isEditMode ? 'Enregistrer' : 'Créer';
    }

    get passwordLabel() {
        return this.isEditMode ? 'Nouveau mot de passe' : 'Mot de passe';
    }

    get passwordPlaceholder() {
        return this.isEditMode ? 'Laisser vide pour conserver l\'actuel' : '';
    }

    get isPasswordRequired() {
        return !this.isEditMode;
    }

    get hasUsers() {
        return this.users.length > 0;
    }

    get showEmptyState() {
        return !this.isLoading && !this.hasUsers;
    }

    get pageLabel() {
        return `Page ${this.page} sur ${Math.max(this.totalPages, 1)}`;
    }

    get disablePrevious() {
        return this.isLoading || this.page <= 1;
    }

    get disableNext() {
        return this.isLoading || this.page >= this.totalPages;
    }

    // ------------------------------------------------------------------
    // Toasts
    // ------------------------------------------------------------------

    showSuccess(message) {
        this.dispatchEvent(new ShowToastEvent({ title: 'Succès', message, variant: 'success' }));
    }

    showError(error) {
        const message =
            error?.body?.message || error?.message || 'Une erreur inattendue est survenue.';
        this.dispatchEvent(new ShowToastEvent({ title: 'Erreur', message, variant: 'error' }));
    }
}