import { LightningElement, api } from 'lwc';
import { FR, etiquettes, remplir, traduireColonnes } from 'c/lwc000_i18n';
import CONTRAT_PARRAINAGE from '@salesforce/resourceUrl/Contrat_Parrainage_RENOV_ARTISAN';
import getFacturesPayees from '@salesforce/apex/LC022PaiementPortailController.getFacturesPayees';
import getFacturesAPayer from '@salesforce/apex/LC022PaiementPortailController.getFacturesAPayer';
import getLignesAFacturer from '@salesforce/apex/LC022PaiementPortailController.getLignesAFacturer';
import {
    COLONNES_PARTENAIRE,
    STATUT_PAYEE,
    STATUT_IMPAYEE,
    lireToken,
    construireMetadata,
    normaliserFacture,
    ligneAFacturerEnFacture,
    messageErreur
} from 'c/lwc020_FacturationUtils';

/** Adresse à laquelle le partenaire envoie ses pièces. */
const EMAIL_FACTURATION = 'facturation@renov-artisan.fr';

/**
 * Contrat de parrainage, servi par la ressource statique
 * Contrat_Parrainage_RENOV_ARTISAN (PDF).
 *
 * Sa métadonnée porte cacheControl = Public : le site Experience est consulté par
 * des visiteurs non authentifiés, et un cache Private rendrait le fichier
 * inaccessible à ceux-là mêmes à qui on le demande.
 *
 * Le lien reste conditionné à une URL non vide : si la ressource venait à être
 * retirée de l'org, la mention « à télécharger ici » s'afficherait en texte simple
 * plutôt qu'en lien mort.
 */
const URL_CONTRAT_PARRAINAGE = CONTRAT_PARRAINAGE || '';

/**
 * Vue PARTENAIRE — campagnes en accès réduit.
 *
 * Les partenaires n'ont pas le même besoin que les régies : ils ne pilotent pas
 * une facturation, ils veulent savoir où en est chaque dossier. D'où un écran
 * volontairement plus pauvre — un seul tableau, aucun onglet, aucun filtre — dont
 * la colonne « Paiement » porte à elle seule la distinction que les deux onglets
 * matérialisaient ailleurs.
 *
 * TROIS sources, exactement les mêmes méthodes Apex que les onglets régie :
 *   • getLignesAFacturer  -> dossiers prêts à facturer, pas encore de facture
 *   • getFacturesAPayer   -> factures créées, pas encore réglées
 *        les deux ci-dessus deviennent « Pas payée »
 *   • getFacturesPayees   -> factures réglées, « Payée »
 *
 * Aucun périmètre n'est décidé ici : chaque méthode fixe le sien côté serveur, et
 * la résolution du compte reste celle du token de campagne.
 */
export default class Lwc020_FacturationPartenaire extends LightningElement {
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
    /** Voir lwc020_FacturationPayees : setter obligatoire, le framework peut
     *  renseigner recordId APRÈS connectedCallback en communauté. */
    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        this._recordId = value;
        if (this._connected) this._chargerTout();
    }

    _campaignCode;
    @api
    get campaignCode() {
        return this._campaignCode || lireToken();
    }
    set campaignCode(value) {
        this._campaignCode = value;
        if (this._connected) this._chargerTout();
    }

    get colonnes() {
        return traduireColonnes(COLONNES_PARTENAIRE, this._langue);
    }

    loadingLignes = false;
    loadingImpayees = false;
    loadingPayees = false;

    errorLignes = null;
    errorImpayees = null;
    errorPayees = null;

    lignesTronquees = false;
    impayeesTronquees = false;
    payeesTronquees = false;
    lignesFactureTronquees = false;

    rowsAFacturer = [];
    rowsImpayees = [];
    rowsPayees = [];
    rows = [];

    _connected = false;
    _derniereCle = null;
    _premierChargementFait = false;
    /** L'historique des paiements a répondu — condition d'affichage du message. */
    _payeesChargees = false;

    connectedCallback() {
        this._connected = true;
        this._chargerTout();
    }

    @api
    rafraichir() {
        this._chargerTout(true);
    }

    _chargerTout(force = false) {
        const cle = `${this._recordId || ''}|${this.campaignCode || ''}`;
        if (!force && cle === this._derniereCle) return;
        this._derniereCle = cle;
        this._chargerLignes();
        this._chargerImpayees();
        this._chargerPayees();
    }

    handleRefresh(event) {
        if (event) event.stopPropagation();
        this._chargerTout(true);
    }

    get _metadata() {
        return construireMetadata(this.colonnes, this.campaignCode, this._recordId);
    }

    /**
     * Normalise une facture Apex en lui accolant son statut de paiement.
     * `statutPaiement` est lu par la colonne `computed` de COLONNES_PARTENAIRE :
     * il ne vient d'aucun champ SOQL, donc aucun nom d'API ne transite pour lui.
     */
    _normaliser(f, statut) {
        return normaliserFacture(
            {
                ...f,
                statutPaiement: statut,
                montantTotal: (f.champs || {}).Montant_Total__c
            },
            this.colonnes
        );
    }

    // ───────────────────────────────── Dossiers prêts à être facturés

    _chargerLignes() {
        this.loadingLignes = true;
        this.errorLignes = null;

        getLignesAFacturer({ metadata: this._metadata })
            .then((result) => {
                this.lignesTronquees = result.tronque === true;
                this.rowsAFacturer = (result.lignes || []).map((l, i) =>
                    normaliserFacture(
                        { ...ligneAFacturerEnFacture(l, i), statutPaiement: STATUT_IMPAYEE },
                        this.colonnes
                    )
                );
                this.loadingLignes = false;
                this._recombiner();
            })
            .catch((err) => {
                this.errorLignes = messageErreur(err);
                this.rowsAFacturer = [];
                this.loadingLignes = false;
                this._recombiner();
            });
    }

    // ───────────────────────────────── Factures non réglées

    _chargerImpayees() {
        this.loadingImpayees = true;
        this.errorImpayees = null;

        getFacturesAPayer({ metadata: this._metadata })
            .then((result) => {
                this.impayeesTronquees = result.tronque === true;
                this.lignesFactureTronquees = result.lignesTronquees === true;
                this.rowsImpayees = (result.factures || []).map((f) =>
                    this._normaliser(f, STATUT_IMPAYEE)
                );
                this.loadingImpayees = false;
                this._recombiner();
            })
            .catch((err) => {
                this.errorImpayees = messageErreur(err);
                this.rowsImpayees = [];
                this.loadingImpayees = false;
                this._recombiner();
            });
    }

    // ───────────────────────────────── Factures réglées

    _chargerPayees() {
        this.loadingPayees = true;
        this.errorPayees = null;

        getFacturesPayees({ metadata: this._metadata })
            .then((result) => {
                this.payeesTronquees = result.tronque === true;
                this.lignesFactureTronquees =
                    this.lignesFactureTronquees || result.lignesTronquees === true;
                this.rowsPayees = (result.factures || []).map((f) =>
                    this._normaliser(f, STATUT_PAYEE)
                );
                this.loadingPayees = false;
                this._payeesChargees = true;
                this._recombiner();
            })
            .catch((err) => {
                this.errorPayees = messageErreur(err);
                this.rowsPayees = [];
                this.loadingPayees = false;
                this._payeesChargees = true;
                this._recombiner();
            });
    }

    // ───────────────────────────────── Assemblage

    /**
     * Ce qui reste dû en premier, l'historique ensuite : c'est l'ordre de lecture
     * naturel pour quelqu'un qui vient vérifier où en sont ses dossiers. Toutes les
     * colonnes restent triables si l'ordre voulu est un autre.
     *
     * Recalculé UNE fois par chargement, jamais dans un getter : un nouveau tableau
     * à chaque rendu forcerait un rendu complet de la table à chaque cycle.
     */
    _recombiner() {
        this.rows = [...this.rowsImpayees, ...this.rowsAFacturer, ...this.rowsPayees];
        this._premierChargementFait = true;
    }

    get isLoading() {
        return this.loadingLignes || this.loadingImpayees || this.loadingPayees;
    }

    /** Les trois sources en échec : il n'y a plus rien à montrer. Une ou deux
     *  seulement : la table reste affichée, amputée, et le bandeau le dit. */
    get erreurBloquante() {
        return this.errorLignes && this.errorImpayees && this.errorPayees
            ? this.errorImpayees
            : null;
    }

    get erreurPartielle() {
        if (this.erreurBloquante) return null;
        const manquants = [];
        if (this.errorLignes) manquants.push(this.txt.srcLignes);
        if (this.errorImpayees) manquants.push(this.txt.srcImpayees);
        if (this.errorPayees) manquants.push(this.txt.srcPayees);
        if (manquants.length === 0) return null;
        return remplir(this.txt.errPartielle, { sources: manquants.join(this.txt.joignantEt) });
    }

    /** La table reste MONTÉE pendant les rechargements : la démonter viderait son
     *  tri, sa page et sa taille de page. Le chargement passe par une surimpression. */
    get showTable() {
        return this._premierChargementFait && !this.erreurBloquante;
    }

    get showSpinnerInitial() {
        return this.isLoading && !this._premierChargementFait;
    }

    get showOverlay() {
        return this.isLoading && this._premierChargementFait;
    }

    get tronque() {
        return this.lignesTronquees || this.impayeesTronquees ||
               this.payeesTronquees || this.lignesFactureTronquees;
    }

    // ───────────────────────────────── Marche à suivre pour être payé

    /**
     * Le message n'est affiché qu'une fois l'historique des paiements RÉELLEMENT
     * connu. Pendant le chargement, ou si cette source a échoué, on ne sait pas
     * distinguer « aucun paiement » de « on n'a pas pu vérifier » — et se tromper
     * enverrait un partenaire déjà réglé rechercher son contrat de parrainage, ou
     * priverait un nouveau de la seule consigne qui le concerne.
     */
    get afficheInfo() {
        return this._payeesChargees && !this.errorPayees;
    }

    get premierPaiement() {
        return this.rowsPayees.length === 0;
    }

    get titreInfo() {
        return this.premierPaiement
            ? this.txt.titreInfoPremier
            : this.txt.titreInfoSuivants;
    }

    get emailFacturation() {
        return EMAIL_FACTURATION;
    }

    get lienEmail() {
        return `mailto:${EMAIL_FACTURATION}`;
    }

    /**
     * Pièces à transmettre. Le contrat de parrainage n'est demandé qu'au premier
     * paiement ; ensuite, seule une alerte en cas de changement de RIB reste utile.
     */
    get piecesInfo() {
        const demande = {
            key: 'demande',
            avant: this.txt.pieceDemande,
            aLien: false,
            lienTexte: '',
            lienUrl: '',
            apres: ''
        };

        if (!this.premierPaiement) {
            return [
                demande,
                {
                    key: 'rib',
                    avant: this.txt.pieceRibChangement,
                    aLien: false,
                    lienTexte: '',
                    lienUrl: '',
                    apres: ''
                }
            ];
        }

        return [
            demande,
            {
                key: 'contrat',
                avant: this.txt.pieceContrat,
                // Sans URL configurée, la mention reste du texte : voir
                // URL_CONTRAT_PARRAINAGE en tête de fichier.
                aLien: URL_CONTRAT_PARRAINAGE !== '',
                lienTexte: this.txt.pieceContratLien,
                lienUrl: URL_CONTRAT_PARRAINAGE,
                apres: this.txt.pieceContratApres
            },
            {
                key: 'rib',
                avant: this.txt.pieceRib,
                aLien: false,
                lienTexte: '',
                lienUrl: '',
                apres: ''
            }
        ];
    }

    get messageTroncature() {
        const parts = [];
        if (this.impayeesTronquees || this.payeesTronquees) {
            parts.push(this.txt.troncRecentes);
        }
        if (this.lignesFactureTronquees) {
            parts.push(this.txt.troncLignesFacture);
        }
        if (this.lignesTronquees) {
            parts.push(this.txt.troncLignesCompte);
        }
        return parts.join(' ');
    }
}