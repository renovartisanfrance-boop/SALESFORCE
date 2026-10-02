import { LightningElement, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import reinitialiserFacture from '@salesforce/apex/FacturesController.reinitialiserFacture';
import getStatutFactureFrais from '@salesforce/apex/FacturesController.getStatutFactureFrais';

const STATUT_BROUILLON = 'Brouillon';

const BLOCKED_BROUILLON = 'brouillon';

export default class ReinitialiserFacture extends LightningElement {
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

    loading = false;
    done = false;
    error;

    initializing = true;
    blockedReason;

    async checkStatutFacture() {
        this.initializing = true;
        this.error = undefined;
        try {
            const statut = await getStatutFactureFrais({ factureId: this._recordId });
            if (statut === STATUT_BROUILLON) {
                this.blockedReason = BLOCKED_BROUILLON;
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

    get confirmDisabled() {
        return this.loading;
    }

    get containerClass() {
        return this.loading
            ? 'rf-container slds-p-around_medium is-loading'
            : 'rf-container slds-p-around_medium';
    }

    get isBlocked() {
        return !!this.blockedReason;
    }

    get blockedTitle() {
        if (this.blockedReason === BLOCKED_BROUILLON) return 'Facture déjà en brouillon';
        return '';
    }

    get blockedMessage() {
        if (this.blockedReason === BLOCKED_BROUILLON) {
            return 'Cette facture est déjà au statut « Brouillon ». Aucune réinitialisation n\'est nécessaire.';
        }
        return '';
    }

    get blockedIcon() {
        return 'utility:info';
    }

    // Sections mutuellement exclusives.
    get showInitMessage()    { return this.initializing; }
    get showBlockedSection() { return !this.initializing && this.isBlocked; }
    get showDoneSection()    { return !this.initializing && !this.isBlocked && this.done; }
    get showFormSection()    { return !this.initializing && !this.isBlocked && !this.done; }

    async handleConfirm() {
        if (this.confirmDisabled) return;
        this.loading = true;
        this.error = undefined;
        try {
            await reinitialiserFacture({ factureId: this._recordId });
            this.done = true;
            notifyRecordUpdateAvailable([{ recordId: this._recordId }]);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Facture remise en brouillon',
                message: 'Le statut est repassé à « Brouillon ».',
                variant: 'success'
            }));
        } catch (e) {
            const msg = (e.body && e.body.message) || e.message || 'Erreur inconnue';
            this.error = msg;
            // Bascule sur l'écran bloquant si le statut est passé à Brouillon
            // entre-temps (par une autre action).
            if (msg.includes('Brouillon')) {
                this.blockedReason = BLOCKED_BROUILLON;
            }
        } finally {
            this.loading = false;
        }
    }

    handleClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}