import { LightningElement, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import validerFacture from '@salesforce/apex/FacturesController.validerFacture';

export default class ValiderFacture extends LightningElement {
    _recordId;

    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        this._recordId = value;
    }

    loading = false;
    confirme = false;
    valide = false;
    dejaValide = false;
    erreurs = [];
    erreurInattendue;

    async lancerValidation() {
        this.confirme = true;
        this.loading = true;
        try {
            const res = await validerFacture({ factureId: this._recordId });
            this.valide = res.valide;
            this.dejaValide = res.dejaValide;
            this.erreurs = res.erreurs || [];
            this.erreurInattendue = undefined;

            if (this.valide && !this.dejaValide) {
                notifyRecordUpdateAvailable([{ recordId: this._recordId }]);
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Facture validée',
                    message: 'La facture est passée au statut « Validé ».',
                    variant: 'success'
                }));
            }
        } catch (e) {
            this.valide = false;
            this.erreurInattendue =
                (e.body && e.body.message) || e.message || 'Erreur inconnue';
        } finally {
            this.loading = false;
        }
    }

    get hasErreurs() {
        return this.erreurs && this.erreurs.length > 0;
    }

    get showContent() {
        return this.valide || this.hasErreurs || !!this.erreurInattendue;
    }

    get containerClass() {
        return this.loading
            ? 'vf-container slds-p-around_medium is-loading'
            : 'vf-container slds-p-around_medium';
    }

    get nbErreurs() {
        return this.erreurs ? this.erreurs.length : 0;
    }

    get erreursAffichees() {
        return (this.erreurs || []).map((msg, i) => ({ key: i, msg }));
    }

    get showRetry() {
        return !this.loading && (this.hasErreurs || !!this.erreurInattendue);
    }

    // Sections mutuellement exclusives.
    get showConfirmation() { return !this.confirme; }
    get showResultats()    { return this.confirme; }

    handleConfirm() {
        this.lancerValidation();
    }

    handleRetry() {
        this.lancerValidation();
    }

    handleClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}