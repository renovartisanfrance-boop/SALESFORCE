import { LightningElement, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import annulerFacture from '@salesforce/apex/FacturesController.annulerFacture';
import getStatutFactureFrais from '@salesforce/apex/FacturesController.getStatutFactureFrais';

const OPT_DISSOCIER = 'dissocier';
const OPT_SUPPRIMER = 'supprimer';

const STATUT_ANNULE = 'Annulé';
const STATUT_VALIDE = 'Validé';

const BLOCKED_ANNULE = 'annule';
const BLOCKED_VALIDE = 'valide';

export default class AnnulerFacture extends LightningElement {
    _recordId;
    _statutChecked = false;

    @api
    get recordId() { return this._recordId; }
    set recordId(value) {
        this._recordId = value;
        if (value && !this._statutChecked) {
            this._statutChecked = true;
            this.checkStatutFacture();
        }
    }

    option = OPT_DISSOCIER;
    motif = '';
    loading = false;
    done = false;
    nbLignes = 0;
    error;

    initializing = true;
    blockedReason;

    async checkStatutFacture() {
        this.initializing = true;
        this.error = undefined;
        try {
            const statut = await getStatutFactureFrais({ factureId: this._recordId });
            if (statut === STATUT_ANNULE) {
                this.blockedReason = BLOCKED_ANNULE;
            } else if (statut === STATUT_VALIDE) {
                this.blockedReason = BLOCKED_VALIDE;
            } else {
                this.blockedReason = undefined;
            }
        } catch (e) {
            this.error = (e.body && e.body.message) || e.message
                || 'Impossible de récupérer le statut de la facture.';
        } finally {
            this.initializing = false;
        }
    }

    get options() {
        return [
            { label: 'Annuler sans supprimer les lignes (dissociation)', value: OPT_DISSOCIER },
            { label: 'Annuler et supprimer définitivement les lignes', value: OPT_SUPPRIMER }
        ];
    }

    get optionHint() {
        return this.supprimerLignes
            ? 'Les lignes de paiement seront définitivement supprimées de la base de données.'
            : 'Les lignes de paiement seront conservées et simplement dissociées de la facture (elles redeviennent disponibles).';
    }

    get supprimerLignes() {
        return this.option === OPT_SUPPRIMER;
    }

    get dateAnnulation() {
        return new Date().toLocaleDateString('fr-FR');
    }

    get confirmDisabled() {
        return this.loading || !this.motif || this.motif.trim().length === 0;
    }

    get containerClass() {
        return this.loading
            ? 'af-container slds-p-around_medium is-loading'
            : 'af-container slds-p-around_medium';
    }

    get resultMessage() {
        const base = 'La facture est annulée. ';
        if (this.nbLignes === 0) {
            return base + 'Aucune ligne de paiement à traiter.';
        }
        return this.supprimerLignes
            ? `${base}${this.nbLignes} ligne(s) de paiement supprimée(s).`
            : `${base}${this.nbLignes} ligne(s) de paiement dissociée(s).`;
    }

    get isBlocked() {
        return !!this.blockedReason;
    }

    get blockedTitle() {
        if (this.blockedReason === BLOCKED_ANNULE) return 'Facture déjà annulée';
        if (this.blockedReason === BLOCKED_VALIDE) return 'Facture validée';
        return '';
    }

    get blockedMessage() {
        if (this.blockedReason === BLOCKED_ANNULE) {
            return 'Cette facture est déjà au statut « Annulé ». Aucune action supplémentaire n\'est nécessaire.';
        }
        if (this.blockedReason === BLOCKED_VALIDE) {
            return 'Cette facture est au statut « Validé ». Réinitialisez-la au statut « Brouillon » avant de pouvoir l\'annuler.';
        }
        return '';
    }

    get blockedIcon() {
        return this.blockedReason === BLOCKED_ANNULE ? 'utility:ban' : 'utility:warning';
    }

    // Sections mutuellement exclusives — pilote tout le rendu HTML.
    get showInitMessage()    { return this.initializing; }
    get showBlockedSection() { return !this.initializing && this.isBlocked; }
    get showDoneSection()    { return !this.initializing && !this.isBlocked && this.done; }
    get showFormSection()    { return !this.initializing && !this.isBlocked && !this.done; }

    handleOptionChange(event) {
        this.option = event.detail.value;
    }

    handleMotifChange(event) {
        this.motif = event.target.value;
    }

    async handleConfirm() {
        if (this.confirmDisabled) return;
        this.loading = true;
        this.error = undefined;
        try {
            this.nbLignes = await annulerFacture({
                factureId: this.recordId,
                motif: this.motif,
                supprimerLignes: this.supprimerLignes
            });
            this.done = true;
            notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Facture annulée',
                message: this.resultMessage,
                variant: 'success'
            }));
        } catch (e) {
            const msg = (e.body && e.body.message) || e.message || 'Erreur inconnue';
            this.error = msg;
            // Si l'erreur Apex indique un statut bloquant entre-temps, on bascule
            // l'écran sur l'état bloquant correspondant pour rester cohérent.
            if (msg.includes('déjà annulée')) {
                this.blockedReason = BLOCKED_ANNULE;
            } else if (msg.includes('Validé')) {
                this.blockedReason = BLOCKED_VALIDE;
            }
        } finally {
            this.loading = false;
        }
    }

    handleClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}