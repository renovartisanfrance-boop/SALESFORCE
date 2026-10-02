import { LightningElement, api } from 'lwc';
import { lireToken } from 'c/lwc020_FacturationUtils';
import { FR, etiquettes } from 'c/lwc000_i18n';

const TAB_EN_COURS = 'en-cours';
const TAB_PAYEES = 'payees';

/**
 * Composant PARENT de l'écran de facturation du portail.
 *
 * Il ne porte que la bascule entre les deux onglets et la transmission du contexte
 * d'accès (token de campagne / recordId) ; toute la logique métier vit dans les
 * enfants :
 *   - lwc020_FacturationEnCours : dossiers prêts à facturer + factures à payer
 *   - lwc020_FacturationPayees  : historique des factures réglées
 *   - lwc020_FacturationTable   : table de factures partagée par les deux
 *   - lwc020_FacturationUtils   : colonnes, normalisation, formatage
 */
export default class Lwc020_Facturation extends LightningElement {
    // Langue d'affichage, poussee par le parent (voir c/lwc000_i18n).
    _langue = FR;
    @api
    get langue() {
        return this._langue;
    }
    set langue(valeur) {
        this._langue = valeur || FR;
    }

    get txt() {
        return etiquettes('facturation', this._langue);
    }


    /** Piloté depuis App Builder / Experience Builder (voir .js-meta.xml). */
    @api afficherContenu = false;

    /**
     * Campagne en accès réduit (partenaire).
     *
     * Déjà transmis par lwc020_CampagneContainer, l'attribut n'était simplement pas
     * déclaré ici. Il bascule l'écran vers une vue SANS onglet : un seul tableau,
     * réunissant ce que les deux onglets séparent, avec un statut de paiement par
     * ligne. Le partenaire n'arbitre pas une facturation, il consulte l'état de ses
     * dossiers — deux onglets pour ça seraient un détour.
     */
    @api accesReduit = false;

    /**
     * Renseigné sur une page d'enregistrement Compte en Lightning Experience.
     * En communauté le framework peut le fournir APRÈS connectedCallback : le setter
     * est donc conservé même si le parent ne fait que le relayer (même piège que
     * lierLignesAvecFacture). Côté serveur il n'est honoré que pour un utilisateur
     * interne.
     */
    _recordId;
    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        this._recordId = value;
    }

    /** Token de campagne : surchargeable par la page, sinon lu dans localStorage. */
    _campaignCode;
    @api
    get campaignCode() {
        return this._campaignCode || lireToken();
    }
    set campaignCode(value) {
        this._campaignCode = value;
    }

    /**
     * La vue partenaire est soumise au même interrupteur d'App Builder que le reste :
     * décocher « Afficher le contenu » doit masquer l'écran pour TOUT le monde,
     * partenaires compris, sinon le placeholder « Bientôt disponible » ne protégerait
     * plus rien.
     */
    get estPartenaire() {
        return this.afficherContenu && this.accesReduit === true;
    }

    ongletActif = TAB_EN_COURS;

    handleTab(event) {
        const tab = event.currentTarget.dataset.tab;
        if (tab) this.ongletActif = tab;
    }

    get isEnCours() {
        return this.ongletActif === TAB_EN_COURS;
    }

    /** Pilote la position de l'indicateur glissant (voir .tab-slider dans le CSS). */
    get classeTabBar() {
        return this.isEnCours ? 'tab-bar' : 'tab-bar tab-bar--payees';
    }

    get classeOngletEnCours() {
        return this.isEnCours ? 'tab-btn tab-btn--active' : 'tab-btn';
    }

    get classeOngletPayees() {
        return this.isEnCours ? 'tab-btn' : 'tab-btn tab-btn--active';
    }

    get ariaEnCours() {
        return this.isEnCours ? 'true' : 'false';
    }

    get ariaPayees() {
        return this.isEnCours ? 'false' : 'true';
    }
}