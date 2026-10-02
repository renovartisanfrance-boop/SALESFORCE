import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getColonnes from '@salesforce/apex/LC022PaiementFacturesMasseController.getColonnes';
import getFacturesValidees from '@salesforce/apex/LC022PaiementFacturesMasseController.getFacturesValidees';
import payerFactures from '@salesforce/apex/LC022PaiementFacturesMasseController.payerFactures';

const OBJECT_API = 'Facture__c';

export default class Lwc022PaiementFacturesMasse extends NavigationMixin(LightningElement) {
    @track columnsRO = [];
    @track columns = [];
    @track rows = [];
    @track loading = false;
    @track error;
    @track nbPayees = 0;
    @track filtreRecherche = '';
    @track compteSectionOuverte = true;
    @track showConfirmModal = false;

    compteId;
    compteNom;
    facturesChargees = false;

    connectedCallback() {
        this.loadColonnes();
    }

    async loadColonnes() {
        try {
            const dto = await getColonnes();
            // Colonnes d'affichage (lecture seule).
            this.columnsRO = (dto.lectureSeule || []).map((c, idx) => ({
                ...c,
                isFirst: idx === 0
            }));
            // Colonnes saisissables ; masterValue = saisie sous l'en-tête de
            // colonne, reportée sur toutes les lignes.
            this.columns = (dto.modifiables || []).map(c => ({ ...c, masterValue: null }));
        } catch (e) {
            this.error = this.messageErreur(e);
        }
    }

    // -- Sélection du compte -----------------------------------------------------

    handleCompteChange(event) {
        this.compteId = this.extraireValeur(event);
        this.nbPayees = 0;
        this.error = undefined;
        this.facturesChargees = false;
        this.filtreRecherche = '';
        this.compteNom = undefined;
        if (this.compteId) {
            this.loadFactures();
        } else {
            this.rows = [];
            this.compteSectionOuverte = true;
        }
    }

    // Requête fraîche à chaque appel (Apex non cacheable) : la liste reflète
    // toujours l'état réel, notamment après confirmation du paiement.
    async loadFactures() {
        this.loading = true;
        try {
            const data = await getFacturesValidees({ compteId: this.compteId });
            this.rows = (data || []).map(f => this.buildRow(f));
            const premiere = (data || [])[0];
            this.compteNom = premiere && premiere.Destinataire_Compte__r
                ? premiere.Destinataire_Compte__r.Name
                : this.compteNom;
            this.facturesChargees = true;
            // La section compte se replie une fois le compte choisi.
            this.compteSectionOuverte = false;
        } catch (e) {
            this.error = this.messageErreur(e);
            this.rows = [];
        } finally {
            this.loading = false;
        }
    }

    buildRow(f) {
        // Colonnes lecture seule : valeur résolue (chemins relationnels inclus)
        // et formatage selon le type du champ.
        const roCells = this.columnsRO.map(c => {
            const brut = this.resoudreValeur(f, c.apiName);
            const value = brut === undefined ? null : brut;
            return {
                key: f.Id + '-ro-' + c.apiName,
                value,
                hasValue: value !== null && value !== '',
                isCurrency: c.type === 'CURRENCY',
                isDate: c.type === 'DATE' || c.type === 'DATETIME',
                cellClass: c.isFirst ? 'cell-strong' : ''
            };
        });
        // Colonnes éditables : pré-remplies avec les valeurs de la facture ;
        // la saisie sous l'en-tête de colonne ou dans la cellule met à jour
        // cet état (source des données envoyées à la confirmation).
        const cells = this.columns.map(c => ({
            key: f.Id + '-' + c.apiName,
            factureId: f.Id,
            apiName: c.apiName,
            required: c.isRequired,
            value: f[c.apiName] !== undefined ? f[c.apiName] : null
        }));
        const recherche = [f.Name, f.N_Facture_Externe__c]
            .concat(roCells.map(c => c.value))
            .filter(v => v !== null && v !== undefined)
            .join(' ')
            .toLowerCase();
        return {
            id: f.Id,
            name: f.Name,
            montant: f.Montant_Total__c,
            searchKey: recherche,
            selected: true,
            rowClass: 'row-selected',
            roCells,
            cells
        };
    }

    // Résout un chemin de champ éventuellement relationnel (ex. Compte__r.Name).
    resoudreValeur(record, chemin) {
        return chemin.split('.').reduce(
            (acc, partie) => (acc === null || acc === undefined ? acc : acc[partie]),
            record
        );
    }

    // -- Section compte repliable --------------------------------------------------

    toggleCompteSection() {
        this.compteSectionOuverte = !this.compteSectionOuverte;
    }

    get compteBodyClass() {
        return this.compteSectionOuverte ? '' : 'slds-hide';
    }

    get compteChevronIcon() {
        return this.compteSectionOuverte ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get compteResume() {
        if (!this.compteId || this.compteSectionOuverte) return '';
        const nom = this.compteNom || 'Compte sélectionné';
        return `${nom} — ${this.rows.length} facture(s) « Validé »`;
    }

    // -- Saisie sous l'en-tête de colonne : reportée sur toutes les lignes ----------

    handleMasterChange(event) {
        const api = event.target.dataset.field;
        const valeur = this.extraireValeur(event);
        this.columns = this.columns.map(c =>
            c.apiName === api ? { ...c, masterValue: valeur } : c
        );
        // Propagation à toutes les lignes (y compris masquées par la recherche) ;
        // chaque ligne reste ensuite modifiable individuellement.
        this.rows = this.rows.map(r => ({
            ...r,
            cells: r.cells.map(c => (c.apiName === api ? { ...c, value: valeur } : c))
        }));
    }

    handleCellChange(event) {
        const api = event.target.dataset.field;
        const fid = event.target.dataset.factureId;
        const valeur = this.extraireValeur(event);
        this.rows = this.rows.map(r => (r.id !== fid ? r : {
            ...r,
            cells: r.cells.map(c => (c.apiName === api ? { ...c, value: valeur } : c))
        }));
    }

    // -- Recherche -------------------------------------------------------------------

    handleRechercheChange(event) {
        this.filtreRecherche = event.target.value || '';
    }

    get rowsDisplay() {
        const terme = this.filtreRecherche.trim().toLowerCase();
        if (!terme) return this.rows;
        return this.rows.filter(r => r.searchKey.includes(terme));
    }

    get hasRowsDisplay() { return this.rowsDisplay.length > 0; }
    get showFilterEmpty() { return this.hasRows && !this.hasRowsDisplay; }

    // -- Sélection des lignes ----------------------------------------------------------

    get allSelected() {
        const affichees = this.rowsDisplay;
        return affichees.length > 0 && affichees.every(r => r.selected);
    }

    handleSelectAll(event) {
        const selected = event.target.checked;
        const visibles = new Set(this.rowsDisplay.map(r => r.id));
        this.rows = this.rows.map(r => (visibles.has(r.id)
            ? { ...r, selected, rowClass: selected ? 'row-selected' : '' }
            : r));
    }

    handleToggleRow(event) {
        const id = event.target.dataset.id;
        this.rows = this.rows.map(r => {
            if (r.id !== id) return r;
            const selected = !r.selected;
            return { ...r, selected, rowClass: selected ? 'row-selected' : '' };
        });
    }

    // -- Getters d'affichage -------------------------------------------------------------

    get objectApiName() { return OBJECT_API; }
    get hasRows() { return this.rows.length > 0; }
    get showTable() { return Boolean(this.compteId) && this.hasRows; }
    get showEmpty() {
        return Boolean(this.compteId) && this.facturesChargees && !this.loading && !this.hasRows;
    }
    get selectedRows() { return this.rows.filter(r => r.selected); }
    get selectedCount() { return this.selectedRows.length; }
    get totalSelected() {
        return this.selectedRows.reduce((somme, r) => somme + (Number(r.montant) || 0), 0);
    }
    get selectionSummary() {
        const base = `${this.selectedCount} / ${this.rows.length} facture(s) sélectionnée(s)`;
        const affichees = this.rowsDisplay.length;
        return affichees === this.rows.length ? base : `${base} — ${affichees} affichée(s)`;
    }
    get confirmLabel() {
        return this.selectedCount > 0
            ? `Confirmer le paiement (${this.selectedCount})`
            : 'Confirmer le paiement';
    }
    get confirmDisabled() {
        return this.loading || this.selectedCount === 0;
    }

    // -- Confirmation -----------------------------------------------------------------------

    handleConfirm() {
        const selectionnees = this.selectedRows;
        if (selectionnees.length === 0) {
            this.toast('Aucune facture', 'Sélectionnez au moins une facture à payer.', 'error');
            return;
        }
        if (!this.validerSaisie(selectionnees)) return;
        this.showConfirmModal = true;
    }

    handleModalCancel() {
        this.showConfirmModal = false;
    }

    handleModalConfirm() {
        this.showConfirmModal = false;
        this.confirmerPaiement(this.construirePayload(this.selectedRows));
    }

    /**
     * Contrôle des champs obligatoires : reportValidity sur les lignes affichées
     * (retour visuel) + contrôle d'état couvrant aussi les lignes sélectionnées
     * masquées par la recherche.
     */
    validerSaisie(selectionnees) {
        const idsSelectionnes = new Set(selectionnees.map(r => r.id));
        let domValide = true;
        [...this.template.querySelectorAll('lightning-input-field[data-row]')]
            .filter(i => idsSelectionnes.has(i.dataset.factureId))
            .forEach(i => {
                if (!i.reportValidity()) domValide = false;
            });

        const enErreur = [];
        selectionnees.forEach(r => {
            r.cells.forEach(c => {
                const vide = c.value === null || c.value === undefined || c.value === '';
                if (c.required && vide) enErreur.push(r.name);
            });
        });

        if (!domValide || enErreur.length) {
            const detail = enErreur.length
                ? ` Factures incomplètes : ${[...new Set(enErreur)].join(', ')}.`
                : '';
            this.toast('Champs invalides', 'Veuillez compléter les champs requis.' + detail, 'error');
            return false;
        }
        return true;
    }

    /**
     * Valeurs depuis l'état (couvre les lignes masquées par la recherche),
     * complétées par une relecture du DOM pour les lignes affichées.
     */
    construirePayload(selectionnees) {
        const valeursDom = {};
        [...this.template.querySelectorAll('lightning-input-field[data-row]')].forEach(i => {
            const fid = i.dataset.factureId;
            if (!valeursDom[fid]) valeursDom[fid] = {};
            let v = i.value;
            if (Array.isArray(v)) v = v.length ? v[0] : null;
            valeursDom[fid][i.fieldName] = v;
        });
        return selectionnees.map(r => {
            const champs = {};
            r.cells.forEach(c => { champs[c.apiName] = c.value; });
            Object.assign(champs, valeursDom[r.id] || {});
            return { factureId: r.id, champs };
        });
    }

    async confirmerPaiement(payload) {
        this.loading = true;
        try {
            const nb = await payerFactures({ facturesJson: JSON.stringify(payload) });
            this.nbPayees = nb;
            this.toast(
                'Paiement confirmé',
                `${nb} facture(s) passée(s) au statut « Payé ».`,
                'success'
            );
            await this.loadFactures();
        } catch (e) {
            this.toast('Erreur', this.messageErreur(e), 'error');
        } finally {
            this.loading = false;
        }
    }

    handleClose() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: OBJECT_API, actionName: 'list' }
        });
    }

    // -- Utilitaires ----------------------------------------------------------------------------

    extraireValeur(event) {
        let v = event.detail && Object.prototype.hasOwnProperty.call(event.detail, 'value')
            ? event.detail.value
            : event.target.value;
        if (Array.isArray(v)) v = v.length ? v[0] : null;
        return v === '' ? null : v;
    }

    messageErreur(e) {
        return (e && e.body && e.body.message) || (e && e.message) || 'Erreur inattendue';
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}