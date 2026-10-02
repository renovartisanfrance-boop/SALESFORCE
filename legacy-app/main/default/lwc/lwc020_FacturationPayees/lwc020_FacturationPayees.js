import { LightningElement, api } from 'lwc';
import { FR, etiquettes, traduireColonnes } from 'c/lwc000_i18n';
import getFacturesPayees from '@salesforce/apex/LC022PaiementPortailController.getFacturesPayees';
import {
    COLONNES_PAYEES,
    EURO,
    lireToken,
    construireMetadata,
    normaliserFacture,
    messageErreur
} from 'c/lwc020_FacturationUtils';

/**
 * Onglet « Payées » — historique des factures réglées.
 *
 * Le périmètre (Statut__c = 'Payé') est fixé CÔTÉ SERVEUR dans
 * LC022PaiementPortailController.getFacturesPayees : ce composant ne peut pas
 * l'élargir, même en modifiant l'appel depuis la console du navigateur.
 */
export default class Lwc020_FacturationPayees extends LightningElement {
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


    _recordId;
    /**
     * Renseigné sur une page d'enregistrement Compte en Lightning Experience.
     * En communauté le framework peut le fournir APRÈS connectedCallback : on passe
     * donc par un setter (même piège que lierLignesAvecFacture).
     */
    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        this._recordId = value;
        if (this._connected) this._charger();
    }

    _campaignCode;
    @api
    get campaignCode() {
        return this._campaignCode || lireToken();
    }
    set campaignCode(value) {
        this._campaignCode = value;
        if (this._connected) this._charger();
    }

    isLoading = false;
    error = null;
    compteNom = null;
    rows = [];

    /** La LISTE de factures a été plafonnée : des factures manquent. */
    facturesTronquees = false;
    /** Les LIGNES ont été plafonnées : toutes les factures sont là, mais les
     *  dernières ont perdu leurs dossiers. Cause et conséquence distinctes. */
    lignesTronquees = false;

    get colonnes() {
        return traduireColonnes(COLONNES_PAYEES, this._langue);
    }

    // Agrégat SERVEUR sur l'intégralité du compte.
    totalPayeCompte = 0;
    nbPayeCompte = 0;

    // Totaux du jeu FILTRÉ, remontés par la table.
    totalPayeFiltre = 0;
    nbPayeFiltre = 0;

    /** Un filtre restreint l'affichage : la tuile rappelle alors le total du compte. */
    filtreActif = false;

    /**
     * Sans filtre ET sans troncature, le grand chiffre EST le total du compte : le
     * répéter en dessous n'apprend rien. La troncature compte autant que le filtre —
     * elle réduit le total sans que l'utilisateur ait rien demandé.
     */
    get afficherRappelCompte() {
        return this.filtreActif || this.tronque;
    }

    _connected = false;
    _derniereCle = null;
    _premierChargementFait = false;

    connectedCallback() {
        this._connected = true;
        this._charger();
    }

    @api
    rafraichir() {
        this._charger(true);
    }

    _charger(force = false) {
        const cle = `${this._recordId || ''}|${this.campaignCode || ''}`;
        if (!force && cle === this._derniereCle) return;
        this._derniereCle = cle;

        this.isLoading = true;
        this.error = null;

        const metadata = construireMetadata(this.colonnes, this.campaignCode, this._recordId);

        getFacturesPayees({ metadata })
            .then((result) => {
                this.compteNom = result.compteNom;
                this.totalPayeCompte = result.totalPaye || 0;
                this.nbPayeCompte = result.nbPaye || 0;
                this.facturesTronquees = result.tronque === true;
                this.lignesTronquees = result.lignesTronquees === true;
                this.rows = (result.factures || []).map((f) =>
                    normaliserFacture(
                        { ...f, montantTotal: (f.champs || {}).Montant_Total__c },
                        this.colonnes
                    )
                );
                this.isLoading = false;
                this._premierChargementFait = true;
            })
            .catch((err) => {
                this.error = messageErreur(err);
                this.rows = [];
                this.isLoading = false;
                this._premierChargementFait = true;
            });
    }

    handleRefresh(event) {
        if (event) event.stopPropagation();
        this._charger(true);
    }

    /**
     * Le tableau reste masqué en cas d'erreur — afficher un état vide par-dessus un
     * message d'erreur serait doublement trompeur — mais reste MONTÉ pendant les
     * rechargements : le démonter viderait les filtres, le tri, la page et la taille
     * de page saisis par l'utilisateur, qui vivent dans les champs d'instance de la
     * table. Le rechargement se signale par une surimpression.
     */
    get showTable() {
        return this._premierChargementFait && !this.error;
    }

    get showSpinnerInitial() {
        return this.isLoading && !this._premierChargementFait;
    }

    get showOverlay() {
        return this.isLoading && this._premierChargementFait;
    }

    get tronque() {
        return this.facturesTronquees || this.lignesTronquees;
    }

    /** Deux causes, deux phrases : « liste plafonnée » serait faux quand ce sont les
     *  lignes qui manquent et que toutes les factures sont bien présentes. */
    get messageTroncature() {
        const parts = [];
        if (this.facturesTronquees) {
            parts.push(`Affichage limité aux ${this.rows.length} factures les plus récentes.`);
        }
        if (this.lignesTronquees) {
            parts.push(
                'Volume de lignes très important : les dernières factures de la liste ' +
                'peuvent apparaître sans leurs dossiers, et un filtre sur le dossier les ' +
                'écarterait alors du tableau et du total affiché.'
            );
        }
        parts.push(this.txt.totalCompte);
        return parts.join(' ');
    }

    handleTotaux(event) {
        this.totalPayeFiltre = event.detail.sommeFactures;
        this.nbPayeFiltre = event.detail.nbFactures;
        this.filtreActif = event.detail.filtreActif === true;
    }

    get totalPaye() {
        return EURO.format(this.totalPayeFiltre || 0);
    }

    get sousTitrePaye() {
        return `${this.nbPayeFiltre} facture(s) affichée(s)`;
    }

    /** Rappel du total réel du compte, sous le montant filtré. */
    get comptePaye() {
        return `sur ${EURO.format(this.totalPayeCompte || 0)} au total (${this.nbPayeCompte})`;
    }
}