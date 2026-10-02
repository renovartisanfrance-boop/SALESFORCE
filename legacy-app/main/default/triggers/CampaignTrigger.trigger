/**
 * CampaignTrigger — point d'entree unique des declencheurs sur Campagne.
 *
 * Le trigger ne porte AUCUNE logique : il delegue au handler, comme
 * CatalogueTarifaireTrigger et FactureTrigger. C'est ce qui permet de tester la
 * logique sans DML et d'en desactiver l'execution par TriggerHandler.bypass().
 *
 * Premier trigger sur Campaign dans cette org : verifie avant creation, il n'y
 * en avait aucun. Tout ajout futur passe donc par CampaignTriggerHandler.
 */
trigger CampaignTrigger on Campaign (after update) {
    new CampaignTriggerHandler().run();
}