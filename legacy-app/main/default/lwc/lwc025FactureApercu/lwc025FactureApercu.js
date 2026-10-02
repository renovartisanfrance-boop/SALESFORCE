import { LightningElement, api, wire } from 'lwc';
import getApercu from '@salesforce/apex/LC025FactureApercuController.getApercu';

/**
 * Aperçu d'une facture (page d'enregistrement Facture__c, LEX + Experience Cloud).
 * Distingue les factures ÉMISES (thème vert) des REÇUES (thème bleu) et affiche :
 * type d'enregistrement, type de facture, la contrepartie (Client si reçue /
 * Fournisseur si émise) et les montants HT / TTC. Pensé pour une colonne étroite
 * (~1/4–1/3 de l'écran, à droite).
 */
export default class Lwc025FactureApercu extends LightningElement {
    @api recordId;

    apercu;
    error;
    loaded = false;

    @wire(getApercu, { factureId: '$recordId' })
    wiredApercu({ data, error }) {
        this.loaded = true;
        if (data) {
            this.apercu = data;
            this.error = undefined;
        } else if (error) {
            this.error = this.reduceError(error);
            this.apercu = undefined;
        }
    }

    get hasData() {
        return !!this.apercu;
    }

    get isEmise() {
        return !!(this.apercu && this.apercu.isEmise);
    }

    // Thème de la carte (variables CSS de couleur) : vert si émise, bleu si reçue.
    get wrapperClass() {
        return this.isEmise ? 'pf-apercu pf-emise' : 'pf-apercu pf-recue';
    }

    // Initiales de la contrepartie pour l'avatar.
    get contrepartieInitials() {
        const nom = ((this.apercu && this.apercu.contrepartieNom) || '').trim();
        if (!nom) return '—';
        const parts = nom.split(/\s+/).filter(Boolean);
        const first = parts[0].charAt(0);
        const last = parts.length > 1 ? parts[parts.length - 1].charAt(0) : '';
        return (first + last).toUpperCase();
    }

    // Sens du flux d'argent, en légende du TTC.
    get flowLabel() {
        return this.isEmise ? 'À encaisser · TTC' : 'À régler · TTC';
    }

    // Titre de l'en-tête : « Facture classique / d'acompte / d'avoir »
    // selon le type d'enregistrement (Classique / Acompte / Avoir).
    get headTitle() {
        const rt = ((this.apercu && this.apercu.recordTypeName) || '').toLowerCase();
        if (rt.includes('acompte')) return "Facture d'acompte";
        if (rt.includes('avoir')) return "Facture d'avoir";
        if (rt.includes('classique')) return 'Facture classique';
        return 'Facture';
    }

    get contrepartieDisplay() {
        return (this.apercu && this.apercu.contrepartieNom) || '—';
    }

    get showEmpty() {
        return this.loaded && !this.apercu && !this.error;
    }

    reduceError(error) {
        if (!error) return 'Erreur inconnue';
        if (Array.isArray(error.body)) return error.body.map((e) => e.message).join(', ');
        if (error.body && error.body.message) return error.body.message;
        return error.message || 'Erreur inconnue';
    }
}