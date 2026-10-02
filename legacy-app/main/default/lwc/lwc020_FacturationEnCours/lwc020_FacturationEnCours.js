import { LightningElement, api } from 'lwc';
import { FR, etiquettes, remplir, traduireColonnes } from 'c/lwc000_i18n';
import getLignesAFacturer from '@salesforce/apex/LC022PaiementPortailController.getLignesAFacturer';
import getFacturesAPayer from '@salesforce/apex/LC022PaiementPortailController.getFacturesAPayer';
import {
    COLONNES_EN_COURS,
    EURO,
    lireToken,
    construireMetadata,
    normaliserFacture,
    ligneAFacturerEnFacture,
    messageErreur
} from 'c/lwc020_FacturationUtils';

/**
 * Onglet « En cours » — tout ce qui n'est pas encore réglé, dans UNE table.
 *
 * Deux origines y cohabitent, parce que l'utilisateur ne raisonne pas en objets
 * Salesforce mais en dossiers : « combien on me doit, et où ça en est ».
 *
 *   • Dossiers dont l'échéance du catalogue est atteinte et dont la facture n'est
 *     pas encore créée (getLignesAFacturer, statut A_CREER de LC023). Les colonnes
 *     de facture y tombent sur leurs replis : « Att. réception facture », « 🕛En Att ».
 *   • Factures créées et pas encore réglées, Brouillon comme Validé
 *     (getFacturesAPayer). Elles portent leur numéro et leur date de paiement prévue.
 *
 * Les deux appels restent INDÉPENDANTS : le calcul du catalogue est lourd, un échec
 * de son côté ne doit pas priver l'utilisateur de ses factures en attente, et
 * réciproquement. La table affiche ce qui a répondu, un bandeau signale le reste.
 */
export default class Lwc020_FacturationEnCours extends LightningElement {
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

    // Libelles traduits au rendu ; COLONNES_EN_COURS reste de la pure config.
    get colonnes() {
        return traduireColonnes(COLONNES_EN_COURS, this._langue);
    }

    loadingLignes = false;
    loadingFactures = false;
    errorLignes = null;
    errorFactures = null;

    /** Le calcul du catalogue a frôlé le plafond de LC023. */
    lignesTronquees = false;
    /** La LISTE de factures a été plafonnée : des factures manquent. */
    facturesTronquees = false;
    /** Les LIGNES de facture ont été plafonnées : toutes les factures sont là,
     *  mais les dernières ont perdu leurs dossiers. Cause et conséquence
     *  distinctes de facturesTronquees, donc message distinct. */
    lignesFactureTronquees = false;

    rowsAFacturer = [];
    rowsFactures = [];

    /**
     * Concaténation des deux origines, recalculée UNE fois par chargement.
     *
     * Surtout pas un getter : il renverrait un nouveau tableau à chaque évaluation
     * du template, l'@api rows de la table changerait d'identité à chaque rendu du
     * parent, et le moindre aller-retour de l'événement `totaux` provoquerait un
     * rendu complet du tableau.
     *
     * Factures d'abord — ce sont des montants déjà engagés — puis les dossiers dont
     * la facture reste à recevoir. N'importe quelle colonne reste triable.
     */
    rows = [];

    // Agrégats SERVEUR, sur l'INTÉGRALITÉ du compte : ils ne suivent ni la
    // pagination ni les filtres, et restent exacts au-delà du plafond de chargement.
    totalAFacturerCompte = 0;
    nbAFacturerCompte = 0;
    totalAPayerCompte = 0;
    nbAPayerCompte = 0;

    // Totaux du jeu FILTRÉ, remontés par la table à chaque changement de filtre.
    totalAFacturerFiltre = 0;
    nbAFacturerFiltre = 0;
    totalAPayerFiltre = 0;
    nbAPayerFiltre = 0;

    /** Un filtre restreint l'affichage : les tuiles rappellent alors le total du compte. */
    filtreActif = false;

    /**
     * Sans filtre ET sans troncature, le grand chiffre de la tuile EST le total du
     * compte : le répéter juste en dessous n'apprend rien. Dès que l'un des deux
     * entre en jeu, il cesse de l'être et le rappel redevient nécessaire — la
     * troncature compte autant que le filtre, car elle réduit le total SANS que
     * l'utilisateur ait rien demandé.
     */
    get afficherRappelCompte() {
        return this.filtreActif || this.tronque;
    }

    _connected = false;
    _derniereCle = null;
    _premierChargementFait = false;

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
        this._chargerFactures();
    }

    handleRefresh(event) {
        if (event) event.stopPropagation();
        this._chargerTout(true);
    }

    get _metadata() {
        return construireMetadata(this.colonnes, this.campaignCode, this._recordId);
    }

    // ───────────────────────────────── Dossiers prêts à être facturés

    _chargerLignes() {
        this.loadingLignes = true;
        this.errorLignes = null;

        getLignesAFacturer({ metadata: this._metadata })
            .then((result) => {
                this.totalAFacturerCompte = result.totalAFacturer || 0;
                this.nbAFacturerCompte = result.nbAFacturer || 0;
                this.lignesTronquees = result.tronque === true;
                this.rowsAFacturer = (result.lignes || []).map((l, i) =>
                    normaliserFacture(ligneAFacturerEnFacture(l, i), this.colonnes)
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

    // ───────────────────────────────── Factures impayées

    _chargerFactures() {
        this.loadingFactures = true;
        this.errorFactures = null;

        getFacturesAPayer({ metadata: this._metadata })
            .then((result) => {
                this.totalAPayerCompte = result.totalAPayer || 0;
                this.nbAPayerCompte = result.nbAPayer || 0;
                this.facturesTronquees = result.tronque === true;
                this.lignesFactureTronquees = result.lignesTronquees === true;
                this.rowsFactures = (result.factures || []).map((f) =>
                    normaliserFacture(
                        { ...f, montantTotal: (f.champs || {}).Montant_Total__c },
                        this.colonnes
                    )
                );
                this.loadingFactures = false;
                this._recombiner();
            })
            .catch((err) => {
                this.errorFactures = messageErreur(err);
                this.rowsFactures = [];
                this.loadingFactures = false;
                this._recombiner();
            });
    }

    // ───────────────────────────────── Assemblage

    _recombiner() {
        this.rows = [...this.rowsFactures, ...this.rowsAFacturer];
        this._premierChargementFait = true;
    }

    get isLoading() {
        return this.loadingLignes || this.loadingFactures;
    }

    /**
     * La table reste MONTÉE une fois le premier chargement fait, y compris pendant
     * un rafraîchissement.
     *
     * La démonter à chaque rechargement viderait tout son état d'affichage — filtres
     * saisis, tri, page courante, taille de page, panneau de filtres déplié — qui vit
     * dans ses champs d'instance. Cliquer « Actualiser » après avoir filtré et trié
     * aurait tout remis à zéro, alors que l'utilisateur n'a rien demandé d'autre que
     * de rafraîchir. Le chargement se signale désormais par une surimpression.
     *
     * Elle s'affiche dès qu'une des deux sources a répondu : un échec du calcul
     * catalogue ne doit pas masquer les factures, et inversement.
     */
    get showTable() {
        return this._premierChargementFait && !this.erreurBloquante;
    }

    /** Premier chargement : rien à montrer encore, le spinner occupe la place. */
    get showSpinnerInitial() {
        return this.isLoading && !this._premierChargementFait;
    }

    /** Rechargements suivants : le contenu reste en place sous la surimpression. */
    get showOverlay() {
        return this.isLoading && this._premierChargementFait;
    }

    get erreurBloquante() {
        return this.errorLignes && this.errorFactures ? this.errorLignes : null;
    }

    /** Une seule source en échec : la table reste affichée, amputée — il faut le
     *  dire, sinon l'écran présente un total partiel comme s'il était complet. */
    get erreurPartielle() {
        if (this.erreurBloquante) return null;
        if (this.errorLignes) {
            return this.txt.errCalculPrets;
        }
        if (this.errorFactures) {
            return this.txt.errChargementFactures;
        }
        return null;
    }

    get tronque() {
        return this.lignesTronquees || this.facturesTronquees || this.lignesFactureTronquees;
    }

    /**
     * Trois causes de troncature, trois phrases distinctes : elles n'ont ni la même
     * conséquence ni le même remède, et les confondre ferait affirmer « liste de
     * factures plafonnée » alors que toutes les factures sont bien présentes.
     */
    get messageTroncature() {
        const parts = [];
        if (this.facturesTronquees) {
            parts.push(`Affichage limité aux ${this.rowsFactures.length} factures les plus récentes.`);
        }
        if (this.lignesFactureTronquees) {
            parts.push(
                'Volume de lignes très important : les dernières factures de la liste ' +
                'peuvent apparaître sans leurs dossiers, et un filtre sur le dossier les ' +
                'écarterait alors du tableau et du total affiché.'
            );
        }
        if (this.lignesTronquees) {
            parts.push(
                'Volume important de lignes sur ce compte : certaines lignes déjà ' +
                'créées peuvent apparaître ici à tort. Rapprochez-vous du service facturation.'
            );
        }
        parts.push(this.txt.totauxCompte);
        return parts.join(' ');
    }

    // ───────────────────────────────── Tuiles

    handleTotaux(event) {
        const t = event.detail;
        this.totalAFacturerFiltre = t.sommeAFacturer;
        this.nbAFacturerFiltre = t.nbAFacturer;
        this.totalAPayerFiltre = t.sommeFactures;
        this.nbAPayerFiltre = t.nbFactures;
        this.filtreActif = t.filtreActif === true;
    }

    get totalAFacturer() {
        return EURO.format(this.totalAFacturerFiltre || 0);
    }
    get totalAPayer() {
        return EURO.format(this.totalAPayerFiltre || 0);
    }

    get sousTitreAFacturer() {
        return `${this.nbAFacturerFiltre} ligne(s) affichée(s)`;
    }
    get sousTitreAPayer() {
        return `${this.nbAPayerFiltre} facture(s) affichée(s)`;
    }

    /** Rappel du total réel du compte, sous le montant filtré : sans lui, un filtre
     *  actif ferait passer un sous-total pour la totalité de ce qui est dû. */
    get compteAFacturer() {
        return `sur ${EURO.format(this.totalAFacturerCompte || 0)} au total (${this.nbAFacturerCompte})`;
    }
    get compteAPayer() {
        return `sur ${EURO.format(this.totalAPayerCompte || 0)} au total (${this.nbAPayerCompte})`;
    }
}