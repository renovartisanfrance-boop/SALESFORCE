/**
 * dicoCommun — libellés partagés par toutes les pages du site Campagnes.
 *
 * Fusionné EN PREMIER par etiquettes() : une page qui définit la même clé
 * l'emporte. Ne mettre ici que des mots réellement génériques.
 *
 * `fr` est la référence et doit rester exhaustive ; `es` peut être partiel
 * (toute clé absente retombe automatiquement sur le français).
 */
export const DICO_COMMUN = {
    fr: {
        // Titres de toasts
        validation: 'Validation',
        erreur: 'Erreur',
        succes: 'Succès',
        information: 'Information',

        // Mots génériques
        oui: 'Oui',
        non: 'Non',
        annuler: 'Annuler',
        fermer: 'Fermer',
        enregistrer: 'Enregistrer',
        selectionner: 'Sélectionner',
        chargement: 'Chargement...',
        aucunChoix: '--'
    },
    es: {
        validation: 'Validación',
        erreur: 'Error',
        succes: 'Éxito',
        information: 'Información',

        oui: 'Sí',
        non: 'No',
        annuler: 'Cancelar',
        fermer: 'Cerrar',
        enregistrer: 'Guardar',
        selectionner: 'Seleccionar',
        chargement: 'Cargando...',
        aucunChoix: '--'
    }
};