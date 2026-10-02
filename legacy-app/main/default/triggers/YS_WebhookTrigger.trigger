/**
 * Relais des webhooks Yousign vers un contexte capable de faire des callouts.
 *
 * Un trigger de Platform Event ne peut pas appeler l'extérieur, or récupérer le
 * PDF signé en exige un : d'où le Queueable. Le trigger ne fait donc que
 * transférer, sans jamais lever d'exception — une erreur ici replacerait
 * l'événement dans le bus et le ferait rejouer indéfiniment.
 */
trigger YS_WebhookTrigger on YS_Webhook__e (after insert) {

    // Marge de sécurité : au-delà, les événements restants seront rattrapés par
    // YS_ReconciliationBatch plutôt que de faire échouer tout le lot.
    Integer restants = Limits.getLimitQueueableJobs() - Limits.getQueueableJobs();

    for (YS_Webhook__e evenement : Trigger.new) {
        if (restants <= 0) {
            System.debug(LoggingLevel.WARN,
                'YS_WebhookTrigger : quota de jobs atteint, événement ' + evenement.EventId__c
                + ' laissé au batch de réconciliation.');
            continue;
        }
        System.enqueueJob(new YS_TraiterWebhook(
            evenement.EventId__c,
            evenement.EventName__c,
            evenement.Payload__c
        ));
        restants--;
    }
}