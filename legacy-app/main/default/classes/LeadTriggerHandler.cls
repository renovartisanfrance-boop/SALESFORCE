/**
 * Trigger handler des Pistes (Lead).
 *  - before insert / before update : contrôle de la référence cadastrale RES060
 *    (format espagnol et doublons), voir LeadReferenceCadastrale.
 *  - toutes phases : indicateurs de doublons (même téléphone RES060…), voir DoublonService.
 */
public with sharing class LeadTriggerHandler extends TriggerHandler {

    private List<Lead> newList;
    private List<Lead> oldList;
    private Map<Id, Lead> oldMap;

    public LeadTriggerHandler() {
        this.newList = (List<Lead>) Trigger.new;
        this.oldList = (List<Lead>) Trigger.old;
        this.oldMap = (Map<Id, Lead>) Trigger.oldMap;
    }

    protected override void beforeInsert() {
        LeadReferenceCadastrale.controler(newList, null);
        DoublonService.avantEnregistrement(newList, null);
    }

    protected override void beforeUpdate() {
        LeadReferenceCadastrale.controler(newList, oldMap);
        DoublonService.avantEnregistrement(newList, oldMap);
    }

    protected override void afterInsert() {
        DoublonService.apresEnregistrement();
    }

    protected override void afterUpdate() {
        DoublonService.apresEnregistrement();
    }

    protected override void afterDelete() {
        DoublonService.apresSuppressionOuRestauration(oldList);
    }

    protected override void afterUndelete() {
        DoublonService.apresSuppressionOuRestauration(newList);
    }

    public static void  CalculCampagnesStats(){

    }
}