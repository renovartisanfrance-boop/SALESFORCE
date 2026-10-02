import { LightningElement, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';
import { refreshApex } from '@salesforce/apex';
import getImportNames from '@salesforce/apex/LettreImportController.getImportNames';
import getImportDetails from '@salesforce/apex/LettreImportController.getImportDetails';
import startDeleteByImportName from '@salesforce/apex/LettreImportController.startDeleteByImportName';

export default class LettreSuppression extends LightningElement {
    importSummaries = [];
    wiredImportSummariesResult;
    selectedImportToDelete = '';
    selectedScope = 'all';
    importDetails = { totalCount: 0, withAircallCount: 0, withoutAircallCount: 0 };
    deleting = false;
    errorMessage = '';

    @wire(getImportNames)
    wiredImportNames(result) {
        this.wiredImportSummariesResult = result;
        if (result.data) {
            this.importSummaries = result.data;
            this.errorMessage = '';
        } else if (result.error) {
            this.importSummaries = [];
            this.errorMessage =
                "Impossible de charger la liste des imports : " +
                (result.error.body?.message || result.error.message || JSON.stringify(result.error));
        }
    }

    loadingDetails = false;

    loadImportDetails(importName) {
        if (!importName) {
            this.importDetails = { totalCount: 0, withAircallCount: 0, withoutAircallCount: 0 };
            return;
        }
        this.loadingDetails = true;
        getImportDetails({ importName })
            .then((data) => {
                this.importDetails = data || { totalCount: 0, withAircallCount: 0, withoutAircallCount: 0 };
            })
            .catch((error) => {
                this.importDetails = { totalCount: 0, withAircallCount: 0, withoutAircallCount: 0 };
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Erreur',
                    message:
                        'Impossible de charger les détails : ' +
                        (error?.body?.message || error?.message || JSON.stringify(error)),
                    variant: 'error'
                }));
            })
            .finally(() => {
                this.loadingDetails = false;
            });
    }

    get importNameOptions() {
        return (this.importSummaries || []).map((s) => ({
            label: `${s.importName} (${s.count} lettre${s.count > 1 ? 's' : ''})`,
            value: s.importName
        }));
    }

    get hasImportNames() {
        return this.importNameOptions.length > 0;
    }

    get hasSelectedImport() {
        return !!this.selectedImportToDelete;
    }

    get scopeOptions() {
        const d = this.importDetails || {};
        return [
            {
                label: `Toutes les lettres (${d.totalCount || 0})`,
                value: 'all'
            },
            {
                label: `Sans Aircall (${d.withoutAircallCount || 0})`,
                value: 'without-aircall'
            },
            {
                label: `Avec Aircall (${d.withAircallCount || 0})`,
                value: 'with-aircall'
            }
        ];
    }

    get currentDeleteCount() {
        const d = this.importDetails || {};
        if (this.selectedScope === 'with-aircall') return d.withAircallCount || 0;
        if (this.selectedScope === 'without-aircall') return d.withoutAircallCount || 0;
        return d.totalCount || 0;
    }

    get currentScopeLabel() {
        if (this.selectedScope === 'with-aircall') return 'avec Aircall';
        if (this.selectedScope === 'without-aircall') return 'sans Aircall';
        return 'au total';
    }

    get deleteDisabled() {
        return !this.selectedImportToDelete || this.deleting || this.currentDeleteCount === 0;
    }

    handleImportToDeleteChange(event) {
        this.selectedImportToDelete = event.detail.value;
        this.selectedScope = 'all';
        this.loadImportDetails(this.selectedImportToDelete);
    }

    handleScopeChange(event) {
        this.selectedScope = event.detail.value;
    }

    async handleStartDelete() {
        if (this.deleteDisabled) return;
        const count = this.currentDeleteCount;
        const importName = this.selectedImportToDelete;
        const scope = this.selectedScope;
        const scopeLabel = this.currentScopeLabel;
        const confirmed = await LightningConfirm.open({
            message: `Confirmer la suppression de ${count} lettre(s) ${scopeLabel} liée(s) à l'import « ${importName} » ?\n\nCette action est irréversible.`,
            variant: 'header',
            label: 'Suppression en masse',
            theme: 'warning'
        });
        if (!confirmed) return;

        this.deleting = true;
        try {
            await startDeleteByImportName({ importName, scope });
            this.dispatchEvent(new ShowToastEvent({
                title: 'Suppression lancée',
                message: `Suppression de ${count} lettre(s) en cours. Vous recevrez une notification à la fin.`,
                variant: 'success',
                mode: 'sticky'
            }));
            // Optimiste : si on supprime tout l'import, on le retire du combobox tout de suite
            if (scope === 'all') {
                this.importSummaries = (this.importSummaries || []).filter(
                    (s) => s.importName !== importName
                );
            }
            this.selectedImportToDelete = '';
            this.selectedScope = 'all';
            // Rafraîchit la liste depuis le serveur après quelques secondes pour aligner sur l'état réel
            // (le Queueable peut encore être en train de supprimer en arrière-plan)
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            window.setTimeout(() => {
                if (this.wiredImportSummariesResult) {
                    refreshApex(this.wiredImportSummariesResult);
                }
            }, 5000);
        } catch (e) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Erreur',
                message: e?.body?.message || e?.message || JSON.stringify(e),
                variant: 'error',
                mode: 'sticky'
            }));
        } finally {
            this.deleting = false;
        }
    }

    handleManualRefresh() {
        if (this.wiredImportSummariesResult) {
            refreshApex(this.wiredImportSummariesResult);
        }
        if (this.selectedImportToDelete) {
            this.loadImportDetails(this.selectedImportToDelete);
        }
    }
}