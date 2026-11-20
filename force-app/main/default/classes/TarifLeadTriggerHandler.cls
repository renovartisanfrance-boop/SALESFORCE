/**
 * Logique déclenchée par TarifLeadTrigger (même modèle que CampaignTriggerHandler).
 *
 * Seul traitement : refuser un tarif actif dont la période recouvre celle d'un autre tarif actif
 * du même couple fournisseur + régie. Le contrôle lui-même est dans LeadPrixService.
 */
public with sharing class TarifLeadTriggerHandler extends TriggerHandler {
  protected override void beforeInsert() {
    new LeadPrixService()
      .refuserLesChevauchements((List<Tarif_Lead__c>) Trigger.new);
  }

  protected override void beforeUpdate() {
    new LeadPrixService()
      .refuserLesChevauchements((List<Tarif_Lead__c>) Trigger.new);
  }
}
