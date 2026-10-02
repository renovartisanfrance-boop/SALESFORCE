public class LigneFactureTriggerHandler extends TriggerHandler {

    /**
     * Le recalcul automatique du statut de la facture après association /
     * dissociation de lignes a été retiré.
     *
     * La cohérence « somme des lignes == montant total » reste vérifiée à la
     * création de la facture (FacturesController.createFactureAvecLignes).
     *
     * La validation d'une facture se fait désormais manuellement via le bouton
     * « Valider la facture » (LWC validerFacture -> FacturesController.validerFacture).
     */
}