import { LightningElement, api, track } from 'lwc';
import { etiquettes } from 'c/lwc027_i18n';
import getContratStockeBase64 from '@salesforce/apex/LC027_GestionContrat.getContratStockeBase64';
import { base64VersOctets } from 'c/lwc027_gestion_contrat';

/**
 * lwc027_facturation_installateur — facturation de l'INSTALLATEUR.
 *
 * Pendant de lwc027_facturation_previsiteur pour le rôle « Installateur » :
 * même encart d'information (nom, société, NIF, activité, date de signature,
 * lien vers le contrat), même tableau encore non branché.
 *
 * Copie VOLONTAIRE : les prestations facturées (installations) ne sont pas
 * celles des prévisites. Le tableau se branchera ici sans risque de modifier
 * la facturation du prévisiteur.
 *
 * Libellés : écran « facturationInstallateur » de c/lwc027_i18n.
 */
export default class Lwc027FacturationInstallateur extends LightningElement {
    /** Token de campagne — sert à récupérer le contrat signé. */
    @api token;
    /** Nom et prénom de l'installateur (Campaign.Name). */
    @api nom;
    /** Dénomination sociale (Campaign.NomSociete__c) — absente pour un autónomo. */
    @api societe;
    /** NIF / DNI / NIE (Campaign.Contrat_NIF__c). */
    @api nif;
    /** Profession ou activité (Campaign.Contrat_Profession__c). */
    @api activite;
    /** Date de signature du contrat (Campaign.YS_Date_Signature__c). */
    @api dateSignature;
    /** Langue d'affichage, poussée par le conteneur. */
    @api langue;

    @track messageEcran;
    @track typeMessage = 'info';
    @track enCours = false;
    /** URL blob: du contrat signe, posee sur un vrai lien — voir chargerContrat(). */
    @track urlPdf = null;

    get txt() {
        return etiquettes('facturationInstallateur', this.langue);
    }

    /**
     * Lignes de l'encart, construites ici et non dans le template : une ligne
     * VIDE est retirée, pas affichée avec un tiret.
     *
     * Un autónomo n'a pas de dénomination sociale, et le NIF comme l'activité ne
     * sont renseignés qu'une fois le formulaire de contrat rempli. Aligner des
     * tirets sur trois lignes donnerait l'impression d'un dossier incomplet
     * alors que rien ne manque.
     */
    get lignes() {
        return [
            { cle: 'nom',      label: this.txt.labelNom,      valeur: this.nom },
            { cle: 'societe',  label: this.txt.labelSociete,  valeur: this.societe },
            { cle: 'nif',      label: this.txt.labelNif,      valeur: this.nif },
            { cle: 'activite', label: this.txt.labelActivite, valeur: this.activite },
            { cle: 'date',     label: this.txt.labelDate,     valeur: this.dateSignatureAffichee }
        ].filter((l) => l.valeur);
    }

    /**
     * Date de signature en toutes lettres, dans la langue d'affichage.
     *
     * `dateSignature` arrive en chaîne ISO depuis Apex (un Datetime sérialisé).
     * Une date invalide ou absente ne doit PAS afficher « Invalid Date » : on
     * rend un tiret, comme pour un nom manquant.
     */
    get dateSignatureAffichee() {
        if (!this.dateSignature) return '—';
        const d = new Date(this.dateSignature);
        if (isNaN(d.getTime())) return '—';
        return d.toLocaleDateString(this.langue === 'fr' ? 'fr-FR' : 'es-ES', {
            day: '2-digit', month: 'long', year: 'numeric'
        });
    }

    /** Le lien n'a de sens qu'une fois le contrat signé. */
    get contratConsultable() {
        return !!this.dateSignature;
    }

    get classeMessage() {
        return 'message message-' + this.typeMessage;
    }

    /**
     * Charge le contrat signé et prépare son lien.
     *
     * ⚠️ EN AMONT, pas au clic : une fenêtre ouverte par script hérite de la CSP
     * du site, qui refuse blob:. Le portail Campagnes charge le document puis
     * rend un <a target="_blank"> — le clic devient une navigation native.
     */
    connectedCallback() {
        if (this.contratConsultable) {
            this.chargerContrat();
        }
    }

    async chargerContrat() {
        try {
            const base64 = await getContratStockeBase64({ campaignToken: this.token });
            this.libererBlob();
            this.urlPdf = URL.createObjectURL(
                new Blob([base64VersOctets(base64)], { type: 'application/pdf' })
            );
        } catch (e) {
            console.error('Contrat signé illisible :', e);
            this.libererBlob();
        }
    }

    /** Un blob: non révoqué retient tout le PDF en mémoire jusqu'à la fermeture. */
    libererBlob() {
        if (this.urlPdf && this.urlPdf.indexOf('blob:') === 0) {
            URL.revokeObjectURL(this.urlPdf);
        }
        this.urlPdf = null;
    }

    disconnectedCallback() {
        this.libererBlob();
    }

    afficher(message, type) {
        this.messageEcran = message;
        this.typeMessage = type || 'info';
    }

    messageDe(erreur) {
        return erreur?.body?.message || erreur?.message || this.txt.erreurGenerique;
    }
}