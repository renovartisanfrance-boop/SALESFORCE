import { LightningElement, api } from 'lwc';

/**
 * Bouton « Chercher un prévisiteur » pour les fiches Piste et Dossiers du portail
 * business saas (site Experience Aura).
 *
 * Pourquoi un bouton et pas l'action rapide Lead/Pro__c.Chercher_Previsiteur : les
 * actions rapides LWC ne sont pas prises en charge sur les sites Experience Aura.
 * Ce composant ouvre previsiteurParCp (mode fiche) dans sa propre fenêtre.
 */
export default class PrevisiteurParCpBouton extends LightningElement {
    @api recordId;
    @api libelle = 'Chercher un prévisiteur';
    ouvert = false;

    ouvrir() { this.ouvert = true; }
    fermer() { this.ouvert = false; }
    handleKeydown(e) { if (e.key === 'Escape') this.fermer(); }
}