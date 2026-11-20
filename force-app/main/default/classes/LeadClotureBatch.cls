/**
 * Seconde partie d'une clôture au pourcentage : remplace, piste par piste, le prix d'achat
 * provisoire par le coût réel réparti, passe le prix en « Définitif » et recalcule la revente
 * quand elle dépend de l'achat. Lancé par LeadClotureService.cloturer, qui fixe aussi la taille
 * des paquets (celle du réglage général) : chaque paquet traverse les automatismes existants de
 * la piste, jamais plus de pistes à la fois que pendant la remontée.
 *
 * Une piste dont la mise à jour est refusée (règle de validation…) n'arrête pas les autres : elle
 * reste au prix provisoire et la clôture le signale à la fin (LeadClotureService.terminer).
 *
 * Écriture en mode système : traitement de l'entreprise, sans utilisateur à l'écran.
 */
public with sharing class LeadClotureBatch implements Database.Batchable<SObject> {
  private final Id idCloture;
  private final Set<Id> sources;
  private final DateTime debut;
  private final DateTime fin;
  private final Decimal prixAchat;

  public LeadClotureBatch(
    Id idCloture,
    Set<Id> sources,
    DateTime debut,
    DateTime fin,
    Decimal prixAchat
  ) {
    this.idCloture = idCloture;
    this.sources = sources;
    this.debut = debut;
    this.fin = fin;
    this.prixAchat = prixAchat;
  }

  public Database.QueryLocator start(Database.BatchableContext contexte) {
    return new LeadPrixSelector()
      .pistesARepartirUneParUne(
        sources,
        debut,
        fin,
        LeadPrixService.STATUT_PROVISOIRE
      );
  }

  public void execute(Database.BatchableContext contexte, List<Lead> pistes) {
    List<Lead> aModifier = new List<Lead>();
    for (Lead piste : pistes) {
      Lead modifiee = new Lead(
        Id = piste.Id,
        Prix_Achat__c = prixAchat,
        Statut_Prix__c = LeadPrixService.STATUT_DEFINITIF
      );
      if (
        piste.Facture_regie__c == true &&
        piste.Tarif_Lead__r != null &&
        LeadPrixService.reventeDependDeLAchat(
          piste.Tarif_Lead__r.Regle_revente__c
        )
      ) {
        modifiee.Prix_Revente__c = LeadPrixService.revente(
          piste.Tarif_Lead__r,
          prixAchat
        );
      }
      aModifier.add(modifiee);
    }
    Database.update(aModifier, false, AccessLevel.SYSTEM_MODE);
  }

  public void finish(Database.BatchableContext contexte) {
    new LeadClotureService().terminer(idCloture);
  }
}
