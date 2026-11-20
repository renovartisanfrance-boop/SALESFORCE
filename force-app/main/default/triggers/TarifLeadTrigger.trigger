/**
 * TarifLeadTrigger — point d'entrée unique des déclencheurs sur Tarif lead.
 * Aucune logique ici : tout est délégué à TarifLeadTriggerHandler.
 */
trigger TarifLeadTrigger on Tarif_Lead__c(before insert, before update) {
  new TarifLeadTriggerHandler().run();
}
