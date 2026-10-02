import { LightningElement, api, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { NavigationMixin } from 'lightning/navigation';
import getFactureInfo from '@salesforce/apex/FacturesController.getFactureInfo';
import getStatutFactureFrais from '@salesforce/apex/FacturesController.getStatutFactureFrais';
import getLignesLiees from '@salesforce/apex/FacturesController.getLignesLiees';
import getLignesDisponibles from '@salesforce/apex/FacturesController.getLignesDisponibles';
import linkLignes from '@salesforce/apex/FacturesController.linkLignes';
import unlinkLigne from '@salesforce/apex/FacturesController.unlinkLigne';

export default class LierLignesAvecFacture extends NavigationMixin(LightningElement) {
    _recordId;
    @api
    get recordId() { return this._recordId; }
    set recordId(value) {
        this._recordId = value;
        // En communauté, le framework peut renseigner recordId APRÈS
        // connectedCallback. On synchronise donc ici le paramètre du wire
        // « lignes disponibles » pour qu'il reparte avec le bon factureId
        // (normalisé à null en création pour que le wire s'exécute quand même).
        this.factureIdParam = value || null;
    }
    @api mode = 'edition'; // 'edition' (facture existante) | 'creation' (avant insert)
    // Montant HT saisi dans le wizard parent (mode création). Permet d'afficher
    // le rapprochement (Montant HT / Écart) avant même la création de la facture.
    @api montantHt;
    // Total HT des acomptes (avances) sélectionnés dans le wizard parent (mode
    // création). S'ajoute au montant HT de la facture : le total attendu des
    // lignes = HT facture + acomptes.
    @api montantAcomptesHt;
    // Bénéficiaire (compte) saisi dans le wizard parent (mode création). Filtre les
    // lignes disponibles : seules celles dont Intervenant_Compte__c correspond sont
    // proposées. En édition, le bénéficiaire est résolu côté serveur depuis la facture.
    _destinataireCompteId;
    @api
    get destinataireCompteId() { return this._destinataireCompteId; }
    set destinataireCompteId(v) {
        this._destinataireCompteId = v;
        // Normalisé à null (jamais undefined) pour que le wire getLignesDisponibles
        // s'exécute même en édition, où ce paramètre n'est pas fourni : le serveur
        // résout alors le bénéficiaire directement depuis la facture.
        this.destinataireParam = v || null;
    }
    // Paramètre réactif du wire (toujours null par défaut, jamais undefined).
    @track destinataireParam = null;

    get isCreation() { return this.mode === 'creation'; }
    get isEdition() { return !this.isCreation; }
    get showLiees() { return this.isEdition && this.lignesLiees.length > 0; }

    // Modifications autorisées uniquement en création ou sur une facture Brouillon.
    // Sur une facture déjà validée/annulée, le composant est en lecture seule.
    get canModify() {
        return this.isCreation || this.factureStatut === 'Brouillon';
    }
    get isReadOnly() {
        return this.isEdition && !this.canModify;
    }
    get showReadOnlyEmpty() {
        return this.isReadOnly && !this.hasLiees;
    }

    @track facture;
    // Statut lu via méthode NON cacheable (getStatutFactureFrais) : fait
    // autorité sur le statut renvoyé par le wire getFactureInfo (cacheable),
    // qui peut être périmé après un changement de statut effectué ailleurs.
    _freshStatut;
    @track lignesLiees = [];
    @track lignesDisponibles = [];
    // Paramètre du wire getLignesDisponibles. Normalisé à null en mode création
    // (recordId undefined) pour que le wire se déclenche quand même.
    factureIdParam = null;
    @track selectedIds = new Set();
    @track loading = false;
    error;

    // -- Filtres "Lignes disponibles" -----------------------------------------
    @track filterDossier = '';

    wiredFactureResult;
    wiredLieesResult;
    wiredDisposResult;

    @wire(getFactureInfo, { factureId: '$recordId' })
    wiredFacture(result) {
        if (this.isCreation) return;
        this.wiredFactureResult = result;
        if (result.data) {
            this.facture = result.data;
        } else if (result.error) {
            this.error = result.error;
        }
    }

    @wire(getLignesLiees, { factureId: '$recordId' })
    wiredLiees(result) {
        if (this.isCreation) return;
        this.wiredLieesResult = result;
        if (result.data) {
            this.lignesLiees = result.data;
        }
    }

    @wire(getLignesDisponibles, { factureId: '$factureIdParam', destinataireCompteId: '$destinataireParam' })
    wiredDispos(result) {
        this.wiredDisposResult = result;
        if (result.data) {
            this.lignesDisponibles = result.data;
        }
    }

    // -- Cycle de vie ----------------------------------------------------------

    connectedCallback() {
        // Le quick action (ScreenAction) peut réutiliser la même instance entre
        // deux ouvertures : on réarme à chaque ouverture le rafraîchissement des
        // listes et l'élargissement de la modale.
        this._refreshedOnOpen = false;
        this._modalWidened = false;

        // recordId est renseigné à ce stade (édition) ou absent (création) :
        // on normalise le paramètre du wire (undefined -> null) pour qu'il
        // s'exécute dans les deux cas.
        this.factureIdParam = this.recordId || null;

        // Statut frais (méthode NON cacheable) à chaque ouverture, pour ne pas
        // dépendre du cache du wire getFactureInfo. Les @api (recordId, mode)
        // sont déjà renseignés à ce stade.
        if (this.isEdition && this.recordId) {
            this.loadFreshStatut();
        }
    }

    async loadFreshStatut() {
        try {
            this._freshStatut = await getStatutFactureFrais({ factureId: this.recordId });
        } catch (e) {
            // En cas d'échec on retombe sur la valeur (potentiellement cachée) du wire.
            this._freshStatut = undefined;
        }
    }

    renderedCallback() {
        this.refreshOnFirstLoad();
        this.widenModal();
    }

    /**
     * Les méthodes Apex sont cacheable=true : à la réouverture du composant
     * (nouvelle instance du quick action), le wire renvoie la valeur en cache,
     * qui peut être périmée si le statut de la facture a changé entre-temps
     * (ex. réinitialisation en Brouillon depuis un autre composant).
     *
     * On force donc un refreshApex une fois les wires provisionnés, pour
     * garantir des données fraîches à chaque ouverture sans recharger la page.
     */
    refreshOnFirstLoad() {
        if (this._refreshedOnOpen) return;
        if (!this.wiredDisposResult) return;
        if (!this.isCreation && (!this.wiredFactureResult || !this.wiredLieesResult)) return;
        this._refreshedOnOpen = true;
        this.forceRefresh();
    }

    forceRefresh() {
        const tasks = [refreshApex(this.wiredDisposResult)];
        if (!this.isCreation) {
            tasks.push(refreshApex(this.wiredFactureResult));
            tasks.push(refreshApex(this.wiredLieesResult));
        }
        this.loading = true;
        Promise.all(tasks)
            .catch(() => { /* erreurs déjà remontées par les wires */ })
            .finally(() => { this.loading = false; });
    }

    // Élargissement de la modale (quick action)
    widenModal() {
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

    get hasFacture() { return !!this.facture; }

    get factureStatut() {
        // Le statut frais (non caché) fait autorité dès qu'il est disponible.
        if (this._freshStatut) return this._freshStatut;
        return this.facture ? this.facture.Statut__c : '';
    }

    get statutBadgeClass() {
        const s = this.factureStatut;
        if (s === 'Validé' || s === 'Payée') return 'pf-badge pf-badge-success';
        if (s === 'Annulé' || s === 'Rejetée') return 'pf-badge pf-badge-danger';
        return 'pf-badge pf-badge-muted';
    }

    get destinataireAffichage() {
        if (!this.facture) return '';
        if (this.facture.Destinataire_User__r && this.facture.Destinataire_User__r.Name) {
            return this.facture.Destinataire_User__r.Name;
        }
        return this.facture.Destinataire_Nom__c || '—';
    }

    get lignesLieesDisplay() {
        return this.lignesLiees.map(f => this.mapLigne(f, false));
    }

    dossierName(f) {
        if (f.Dossier__r && f.Dossier__r.Name) return f.Dossier__r.Name;
        return f.Dossier__c || '';
    }

    get filteredLignes() {
        const dossier = (this.filterDossier || '').toLowerCase().trim();
        return this.lignesDisponibles.filter(f => {
            const matchDossier = !dossier
                || this.dossierName(f).toLowerCase().includes(dossier);
            return matchDossier;
        });
    }

    get lignesDisponiblesDisplay() {
        return this.filteredLignes.map(f => this.mapLigne(f, true));
    }

    get hasFilteredDispos() {
        return this.filteredLignes.length > 0;
    }

    handleFilterDossier(event) {
        this.filterDossier = event.target.value;
    }

    mapLigne(f, selectable) {
        const destUser = f.Destinataire_User__r ? f.Destinataire_User__r.Name : null;
        const dest = destUser || f.Destinataire_Nom__c || '—';
        const dossier = f.Dossier__r ? f.Dossier__r.Name : (f.Dossier__c || '-');
        const statut = f.Statut__c || '-';
        let badge = 'pf-badge pf-badge-muted';
        if (statut === 'Payée') badge = 'pf-badge pf-badge-success';
        else if (statut === 'À payer' || statut === 'Validée') badge = 'pf-badge pf-badge-danger';

        // Facture liée (présente pour les lignes rattachées à une facture Brouillon
        // dans la liste « disponibles ») : N° externe + statut affiché en badge.
        const factStatut = f.Facture__r ? f.Facture__r.Statut__c : null;
        let factBadge = 'pf-badge pf-badge-muted';
        if (factStatut === 'Validé' || factStatut === 'Payée') factBadge = 'pf-badge pf-badge-success';
        else if (factStatut === 'Annulé' || factStatut === 'Rejetée') factBadge = 'pf-badge pf-badge-danger';

        const selected = this.selectedIds.has(f.Id);
        return {
            id: f.Id,
            name: f.Name,
            numFournisseur: f.Numero_Facture_Fournisseur__c || '-',
            dateFournisseur: f.Date_Facture_Fournisseur__c || '-',
            intervenant: f.Type_Intervenant__c || '-',
            echeance: f.Numero_Echeance__c || '-',
            dossier,
            destinataire: dest,
            montant: f.Montant_HT__c,
            statut,
            statutBadgeClass: badge,
            factureNumExterne: (f.Facture__r && f.Facture__r.N_Facture_Externe__c) || null,
            factureStatut: factStatut,
            factureStatutBadgeClass: factBadge,
            selectable,
            selected,
            rowClass: selectable && selected
                ? 'slds-hint-parent row-clickable row-selected'
                : 'slds-hint-parent row-clickable'
        };
    }

    get hasLiees() { return this.lignesLiees.length > 0; }
    get hasDispos() { return this.lignesDisponibles.length > 0; }

    get nbSelected() { return this.selectedIds.size; }

    get totalSelected() {
        let total = 0;
        this.lignesDisponibles.forEach(f => {
            if (this.selectedIds.has(f.Id) && f.Montant_HT__c) {
                total += Number(f.Montant_HT__c);
            }
        });
        return total;
    }

    // -- Vérification : sélection vs montant HT de la facture ------------------

    get factureMontantHT() {
        // Montant HT attendu pour les lignes = HT de la facture + total HT des
        // acomptes (avances) rattachés.
        // En création, les montants proviennent du wizard parent (saisie en cours).
        if (this.isCreation) {
            if (this.montantHt === null || this.montantHt === undefined || this.montantHt === '') {
                return null;
            }
            const n = Number(this.montantHt);
            if (isNaN(n)) return null;
            const acomptes = Number(this.montantAcomptesHt || 0);
            return n + (isNaN(acomptes) ? 0 : acomptes);
        }
        // En édition, ils proviennent de la facture.
        if (!this.facture || this.facture.MontantHT__c == null) return null;
        return this.facture.MontantHT__c + (this.facture.Montant_TotalAcompte_Avance_HT__c || 0);
    }

    get hasFactureMontant() {
        return this.factureMontantHT != null;
    }

    // Écart entre les lignes sélectionnées et le montant HT de la facture.
    get ecartFacture() {
        if (!this.hasFactureMontant) return 0;
        return this.totalSelected - Number(this.factureMontantHT);
    }

    get selectionMatchesFacture() {
        return this.hasFactureMontant && Math.abs(this.ecartFacture) < 0.01;
    }

    get matchRowClass() {
        return this.selectionMatchesFacture
            ? 'pf-match-row pf-match-ok'
            : 'pf-match-row pf-match-warn';
    }

    get matchLabel() {
        return this.selectionMatchesFacture
            ? '✓ Sélection conforme au montant HT attendu (facture + acomptes)'
            : '⚠ Écart avec le montant HT attendu (facture + acomptes)';
    }

    get linkDisabled() {
        return this.loading || this.selectedIds.size === 0;
    }

    get linkLabel() {
        const n = this.selectedIds.size;
        return n > 0 ? `Lier ${n} ligne(s) à la facture` : 'Lier les lignes sélectionnées';
    }

    get selectionSummary() {
        return `${this.selectedIds.size} sélectionnée(s) sur ${this.lignesDisponibles.length}`;
    }

    // -- Handlers --------------------------------------------------------------

    notifySelection() {
        if (this.isCreation) {
            this.dispatchEvent(new CustomEvent('selectionchange', {
                detail: { selectedIds: Array.from(this.selectedIds) }
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
            this.filteredLignes.forEach(f => set.add(f.Id));
        } else {
            this.filteredLignes.forEach(f => set.delete(f.Id));
        }
        this.selectedIds = set;
        this.notifySelection();
    }

    get allSelected() {
        return this.filteredLignes.length > 0
            && this.filteredLignes.every(f => this.selectedIds.has(f.Id));
    }

    async handleLink() {
        if (this.selectedIds.size === 0) return;
        this.loading = true;
        try {
            const ids = Array.from(this.selectedIds);
            const count = await linkLignes({
                factureId: this.recordId,
                ligneIds: ids
            });
            this.selectedIds = new Set();
            await Promise.all([
                refreshApex(this.wiredLieesResult),
                refreshApex(this.wiredDisposResult)
            ]);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Lignes liées',
                message: `${count} ligne(s) liée(s) à la facture`,
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
            await unlinkLigne({ ligneId: id });
            await Promise.all([
                refreshApex(this.wiredLieesResult),
                refreshApex(this.wiredDisposResult)
            ]);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Ligne déliée',
                message: 'La ligne a été retirée de la facture',
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