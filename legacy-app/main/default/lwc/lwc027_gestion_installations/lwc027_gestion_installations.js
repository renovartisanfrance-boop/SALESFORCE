import { LightningElement, api, track } from 'lwc';
import { etiquettes } from 'c/lwc027_i18n';
import getContratStockeBase64 from '@salesforce/apex/LC027_GestionContrat.getContratStockeBase64';
import getContrat from '@salesforce/apex/LC027_GestionContrat.getContrat';
import { base64VersOctets, lignesRecap } from 'c/lwc027_gestion_contrat';

/**
 * lwc027_gestion_installations — accueil de l'INSTALLATEUR, pendant de
 * lwc027_gestion_previsite pour le rôle « Installateur » (même site, même
 * conteneur, même token).
 *
 * Copie VOLONTAIRE et non paramétrage du composant prévisiteur : les deux
 * métiers vont diverger. Les séparer dès maintenant évite qu'un changement
 * prévu pour l'un casse l'autre. Le verrouillage « contrat en attente » suit
 * le même principe que côté prévisiteur.
 *
 * Libellés : écran « installations » de c/lwc027_i18n.
 *
 * Le conteneur ne l'affiche que dans ce cas : tant que StatutContrat__c n'est
 * pas « Signe », c'est lwc027_gestion_contrat qui occupe l'écran.
 *
 * État actuel : les deux entrées du portail, sans contenu derrière. La logique
 * de planification n'est pas encore définie — chaque bouton émet un événement
 * `selectionvue` que le conteneur relaiera vers la vue correspondante quand
 * elle existera. Aucun appel serveur ici : ce composant n'est qu'un aiguillage.
 */

export const VUE_A_PLANIFIER = 'installations-a-planifier';
export const VUE_PLANIFIES   = 'installations-planifiees';

export default class Lwc027GestionInstallations extends LightningElement {
    /** Token de campagne, relayé par le conteneur aux futures vues. */
    @api token;
    /** Nom de l'installateur, pour l'accueil. */
    @api nom;
    /** Langue d'affichage, pilotée par la bascule du conteneur. */
    @api langue;
    /**
     * Contrat parti en signature mais pas encore signé.
     *
     * Le portail s'affiche alors en ENTIER mais VERROUILLÉ : l'installateur voit
     * ce qui l'attend, comprend qu'il n'y accède pas encore et pourquoi. Le
     * masquer aurait laissé un écran vide sans explication.
     */
    @api contratEnAttente = false;
    /** Email destinataire du contrat, cité dans le message d'attente. */
    @api email;

    @track vue = null;
    @track messageEcran;
    @track enCours = false;
    /** URL blob: du contrat, posee sur un vrai lien — voir chargerContrat(). */
    @track urlPdf = null;
    /**
     * Informations envoyées dans le contrat (EtatContrat de LC027_GestionContrat).
     * Lues au serveur et non relayées par le conteneur : c'est la valeur
     * ENREGISTRÉE qui a été imprimée sur le contrat, pas une saisie locale.
     */
    @track etatContrat = null;

    get accueil() {
        return this.vue === null;
    }

    /** Étiquettes de l'écran, dans la langue courante. */
    get txt() {
        return etiquettes('installations', this.langue);
    }

    get salutation() {
        return this.nom ? `${this.txt.salutation} ${this.nom}` : this.txt.salutation;
    }

    /**
     * Charge le contrat dès que l'écran verrouillé s'affiche.
     *
     * ⚠️ EN AMONT, pas au clic. Une fenêtre ouverte par script hérite de la CSP
     * du site, qui refuse blob:, et les navigateurs la traitent en popup. Le
     * portail Campagnes charge le document puis rend un <a target="_blank"> :
     * le clic devient une navigation native. Même procédé ici.
     */
    connectedCallback() {
        if (this.contratEnAttente) {
            this.chargerContrat();
            this.chargerRecap();
        }
    }

    /** Charge les informations envoyées. Un échec masque le recap, sans bloquer. */
    async chargerRecap() {
        try {
            this.etatContrat = await getContrat({ campaignToken: this.token });
        } catch (e) {
            console.error('Recap du contrat illisible :', e);
            this.etatContrat = null;
        }
    }

    /** Lignes du recap : mêmes libellés et valeurs que la relecture avant envoi. */
    get recap() {
        if (!this.etatContrat) return [];
        return lignesRecap(this.etatContrat.role, this.etatContrat.donnees,
            etiquettes('contrat', this.langue), this.etatContrat.pays);
    }

    get aUnRecap() {
        return this.recap.length > 0;
    }

    async chargerContrat() {
        try {
            const base64 = await getContratStockeBase64({ campaignToken: this.token });
            this.libererBlob();
            this.urlPdf = URL.createObjectURL(
                new Blob([base64VersOctets(base64)], { type: 'application/pdf' })
            );
        } catch (e) {
            console.error('Contrat illisible :', e);
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

    /** Message d'attente, avec l'email réellement destinataire. */
    get messageAttente() {
        return (this.txt.attenteMessage || '').replace('{email}', this.email || '');
    }

    get classeTuile() {
        return this.contratEnAttente ? 'tuile tuile-bloquee' : 'tuile';
    }

    handleAPlanifier() {
        if (this.contratEnAttente) return;
        this.choisir(VUE_A_PLANIFIER);
    }

    handlePlanifies() {
        if (this.contratEnAttente) return;
        this.choisir(VUE_PLANIFIES);
    }

    /** Renvoie au formulaire de contrat pour corriger une saisie. */
    handleModifierInfos() {
        this.dispatchEvent(new CustomEvent('modifierinfos'));
    }


    choisir(vue) {
        this.vue = vue;
        this.dispatchEvent(new CustomEvent('selectionvue', { detail: { vue } }));
    }

    /** Retour à l'accueil depuis une vue — utile tant qu'aucune n'est branchée. */
    handleRetour() {
        this.vue = null;
        this.dispatchEvent(new CustomEvent('selectionvue', { detail: { vue: null } }));
    }

    get titreVue() {
        return this.vue === VUE_A_PLANIFIER ? this.txt.aPlanifierTitre : this.txt.planifiesTitre;
    }
}