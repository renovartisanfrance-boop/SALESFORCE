import { LightningElement } from 'lwc';

/**
 * Composant parent du paramétrage Catalogue Tarifaire.
 * Barre d'onglets maison (2 onglets), entièrement pilotée par l'état `activeTab` :
 *  - « Lignes du catalogue » : liste des lignes existantes (lwc022CatalogueListe)
 *  - « Nouvelle ligne » / « Modifier » / « Dupliquer » : assistant (lwc022CatalogueForm)
 *
 * editRecordId  -> édition d'une ligne existante.
 * cloneRecordId -> duplication : le formulaire pré-remplit depuis cette ligne
 *                  mais crée une NOUVELLE ligne (recordId reste null).
 */
export default class Lwc022CatalogueTarifaire extends LightningElement {
    activeTab = 'liste';
    editRecordId = null;
    cloneRecordId = null;

    get isListe() {
        return this.activeTab === 'liste';
    }

    get isForm() {
        return this.activeTab === 'form';
    }

    get formTabLabel() {
        if (this.editRecordId) return 'Modifier la ligne';
        if (this.cloneRecordId) return 'Dupliquer la ligne';
        return 'Nouvelle ligne';
    }

    get listeTabClass() {
        return this.isListe ? 'pf-tab pf-tab-active' : 'pf-tab';
    }

    get formTabClass() {
        return this.isForm ? 'pf-tab pf-tab-active' : 'pf-tab';
    }

    resetMode() {
        this.editRecordId = null;
        this.cloneRecordId = null;
    }

    handleTabClick(event) {
        const tab = event.currentTarget.dataset.tab;
        if (tab === 'liste') {
            this.resetMode();
        }
        this.activeTab = tab;
    }

    handleNew() {
        this.resetMode();
        this.activeTab = 'form';
    }

    handleEdit(event) {
        this.resetMode();
        this.editRecordId = event.detail.recordId;
        this.activeTab = 'form';
    }

    handleClone(event) {
        this.resetMode();
        this.cloneRecordId = event.detail.recordId;
        this.activeTab = 'form';
    }

    handleSaved() {
        this.resetMode();
        this.activeTab = 'liste';
    }

    handleCancel() {
        this.resetMode();
        this.activeTab = 'liste';
    }
}