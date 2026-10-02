import { LightningElement, api, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { NavigationMixin } from 'lightning/navigation';
import getLettrageInfo from '@salesforce/apex/LettrageFacturesController.getLettrageInfo';
import getFacturesLiees from '@salesforce/apex/LettrageFacturesController.getFacturesLiees';
import getFacturesDisponibles from '@salesforce/apex/LettrageFacturesController.getFacturesDisponibles';
import linkFactures from '@salesforce/apex/LettrageFacturesController.linkFactures';
import unlinkFacture from '@salesforce/apex/LettrageFacturesController.unlinkFacture';

export default class LettrageFactures extends NavigationMixin(LightningElement) {
    @api recordId;
    @api mode = 'edition'; // 'edition' (lettrage existant) | 'creation' (avant insert)

    get isCreation() { return this.mode === 'creation'; }
    get isEdition() { return !this.isCreation; }
    get showLiees() { return this.isEdition && this.facturesLiees.length > 0; }

    @track lettrage;
    @track facturesLiees = [];
    @track facturesDisponibles = [];
    @track selectedIds = new Set();
    @track loading = false;
    error;

    // -- Filtres "Factures disponibles" ---------------------------------------
    @track filterNumFacture = '';
    @track filterNumExterne = '';

    wiredLettrageResult;
    wiredLieesResult;
    wiredDisposResult;

    @wire(getLettrageInfo, { lettrageId: '$recordId' })
    wiredLettrage(result) {
        if (this.isCreation) return;
        this.wiredLettrageResult = result;
        if (result.data) {
            this.lettrage = result.data;
        } else if (result.error) {
            this.error = result.error;
        }
    }

    @wire(getFacturesLiees, { lettrageId: '$recordId' })
    wiredLiees(result) {
        if (this.isCreation) return;
        this.wiredLieesResult = result;
        if (result.data) {
            this.facturesLiees = result.data;
        }
    }

    @wire(getFacturesDisponibles)
    wiredDispos(result) {
        this.wiredDisposResult = result;
        if (result.data) {
            this.facturesDisponibles = result.data;
        }
    }

    // -- Élargissement de la modale (quick action) ----------------------------

    renderedCallback() {
        if (this._modalWidened) return;
        const host = this.template.host;
        const modal = host && host.closest
            ? host.closest('.slds-modal__container')
            : null;
        if (modal) {
            modal.style.width = '95vw';
            modal.style.maxWidth = '1400px';
            this._modalWidened = true;
        }
    }

    // -- Getters d'affichage ---------------------------------------------------

    get hasLettrage() { return !!this.lettrage; }

    get lettrageStatut() { return this.lettrage ? this.lettrage.Statut__c : ''; }

    get statutBadgeClass() {
        const s = this.lettrageStatut;
        if (s === 'Validé') return 'pf-badge pf-badge-success';
        if (s === 'Annulé') return 'pf-badge pf-badge-danger';
        return 'pf-badge pf-badge-muted';
    }

    get destinataireAffichage() {
        if (!this.lettrage) return '';
        if (this.lettrage.Destinataire_User__r && this.lettrage.Destinataire_User__r.Name) {
            return this.lettrage.Destinataire_User__r.Name;
        }
        return this.lettrage.Destinataire_Nom__c || '—';
    }

    get facturesLieesDisplay() {
        return this.facturesLiees.map(f => this.mapFacture(f, false));
    }

    get filteredFactures() {
        const num = (this.filterNumFacture || '').toLowerCase().trim();
        const ext = (this.filterNumExterne || '').toLowerCase().trim();
        return this.facturesDisponibles.filter(f => {
            const matchNum = !num || (f.Name || '').toLowerCase().includes(num);
            const matchExt = !ext
                || (f.N_Facture_Externe__c || '').toLowerCase().includes(ext);
            return matchNum && matchExt;
        });
    }

    get facturesDisponiblesDisplay() {
        return this.filteredFactures.map(f => this.mapFacture(f, true));
    }

    get hasFilteredDispos() {
        return this.filteredFactures.length > 0;
    }

    handleFilterNumFacture(event) {
        this.filterNumFacture = event.target.value;
    }

    handleFilterNumExterne(event) {
        this.filterNumExterne = event.target.value;
    }

    mapFacture(f, selectable) {
        const destUser = f.Destinataire_User__r ? f.Destinataire_User__r.Name : null;
        const dest = destUser || f.Destinataire_Nom__c || '—';
        const statut = f.Statut__c || '-';
        let badge = 'pf-badge pf-badge-muted';
        if (statut === 'Payée' || statut === 'Validé') badge = 'pf-badge pf-badge-success';
        else if (statut === 'À payer' || statut === 'Rejetée' || statut === 'Annulé') badge = 'pf-badge pf-badge-danger';
        const selected = this.selectedIds.has(f.Id);
        return {
            id: f.Id,
            name: f.Name,
            numExterne: f.N_Facture_Externe__c || '-',
            destinataire: dest,
            montant: f.Montant_Total__c,
            datePaiement: f.Date_Paiement__c || '-',
            referenceBancaire: f.Reference_Bancaire__c || '-',
            moyenPaiement: f.Moyen_Paiement__c || '-',
            statut,
            statutBadgeClass: badge,
            selectable,
            selected,
            rowClass: selectable && selected
                ? 'slds-hint-parent row-clickable row-selected'
                : 'slds-hint-parent row-clickable'
        };
    }

    get hasLiees() { return this.facturesLiees.length > 0; }
    get hasDispos() { return this.facturesDisponibles.length > 0; }

    get nbSelected() { return this.selectedIds.size; }

    get totalSelected() {
        let total = 0;
        this.facturesDisponibles.forEach(f => {
            if (this.selectedIds.has(f.Id) && f.Montant_Total__c) {
                total += Number(f.Montant_Total__c);
            }
        });
        return total;
    }

    get linkDisabled() {
        return this.loading || this.selectedIds.size === 0;
    }

    get linkLabel() {
        const n = this.selectedIds.size;
        return n > 0 ? `Lier ${n} facture(s) au lettrage` : 'Lier les factures sélectionnées';
    }

    get selectionSummary() {
        return `${this.selectedIds.size} sélectionnée(s) sur ${this.facturesDisponibles.length}`;
    }

    // -- Handlers --------------------------------------------------------------

    notifySelection() {
        if (this.isCreation) {
            this.dispatchEvent(new CustomEvent('selectionchange', {
                detail: {
                    selectedIds: Array.from(this.selectedIds),
                    total: this.totalSelected
                }
            }));
        }
    }

    handleToggleRow(event) {
        const id = event.currentTarget.dataset.id;
        if (!id) return;
        const set = new Set(this.selectedIds);
        if (set.has(id)) set.delete(id);
        else set.add(id);
        this.selectedIds = set;
        this.notifySelection();
    }

    handleCheckboxChange(event) {
        event.stopPropagation();
        const id = event.target.dataset.id;
        const set = new Set(this.selectedIds);
        if (event.target.checked) set.add(id);
        else set.delete(id);
        this.selectedIds = set;
        this.notifySelection();
    }

    handleSelectAll(event) {
        event.stopPropagation();
        const set = new Set(this.selectedIds);
        if (event.target.checked) {
            this.filteredFactures.forEach(f => set.add(f.Id));
        } else {
            this.filteredFactures.forEach(f => set.delete(f.Id));
        }
        this.selectedIds = set;
        this.notifySelection();
    }

    get allSelected() {
        return this.filteredFactures.length > 0
            && this.filteredFactures.every(f => this.selectedIds.has(f.Id));
    }

    async handleLink() {
        if (this.selectedIds.size === 0) return;
        this.loading = true;
        try {
            const ids = Array.from(this.selectedIds);
            const count = await linkFactures({
                lettrageId: this.recordId,
                factureIds: ids
            });
            this.selectedIds = new Set();
            await Promise.all([
                refreshApex(this.wiredLieesResult),
                refreshApex(this.wiredDisposResult)
            ]);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Factures liées',
                message: `${count} facture(s) liée(s) au lettrage`,
                variant: 'success'
            }));
        } catch (e) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Erreur',
                message: (e.body && e.body.message) || e.message || 'Erreur inconnue',
                variant: 'error'
            }));
        } finally {
            this.loading = false;
        }
    }

    async handleUnlink(event) {
        const id = event.currentTarget.dataset.id;
        if (!id) return;
        this.loading = true;
        try {
            await unlinkFacture({ factureId: id });
            await Promise.all([
                refreshApex(this.wiredLieesResult),
                refreshApex(this.wiredDisposResult)
            ]);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Facture déliée',
                message: 'La facture a été retirée du lettrage',
                variant: 'success'
            }));
        } catch (e) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Erreur',
                message: (e.body && e.body.message) || e.message || 'Erreur inconnue',
                variant: 'error'
            }));
        } finally {
            this.loading = false;
        }
    }

    handleClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}