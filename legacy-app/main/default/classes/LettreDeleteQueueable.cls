public without sharing class LettreDeleteQueueable implements Queueable {

    private static final Integer CHUNK_SIZE = 200;
    private static final String NOTIFICATION_DEV_NAME = 'Lettre_Import_Notification';

    private String importName;
    private String scope;
    private Id userId;
    private Integer deletedCount;
    private Integer failedCount;

    public LettreDeleteQueueable(String importName, String scope, Id userId) {
        this(importName, scope, userId, 0, 0);
    }

    // Constructeur historique conservé pour compatibilité (scope = 'all')
    public LettreDeleteQueueable(String importName, Id userId) {
        this(importName, 'all', userId, 0, 0);
    }

    private LettreDeleteQueueable(String importName, String scope, Id userId, Integer deletedCount, Integer failedCount) {
        this.importName = importName;
        this.scope = String.isBlank(scope) ? 'all' : scope;
        this.userId = userId;
        this.deletedCount = deletedCount;
        this.failedCount = failedCount;
    }

    public void execute(QueueableContext context) {
        List<Lettre__c> toDelete = fetchNextChunk();

        if (toDelete.isEmpty()) {
            sendNotification();
            return;
        }

        Database.DeleteResult[] results = Database.delete(toDelete, false);
        for (Database.DeleteResult r : results) {
            if (r.isSuccess()) {
                deletedCount++;
            } else {
                failedCount++;
            }
        }

        if (!Test.isRunningTest()) {
            System.enqueueJob(new LettreDeleteQueueable(importName, scope, userId, deletedCount, failedCount));
        }
    }

    private List<Lettre__c> fetchNextChunk() {
        if (scope == 'with-aircall') {
            return [
                SELECT Id
                FROM Lettre__c
                WHERE Nom_d_import__c = :importName
                AND Id IN (SELECT Lettre__c FROM Aircall__c WHERE Lettre__c != null)
                LIMIT :CHUNK_SIZE
            ];
        }
        if (scope == 'without-aircall') {
            return [
                SELECT Id
                FROM Lettre__c
                WHERE Nom_d_import__c = :importName
                AND Id NOT IN (SELECT Lettre__c FROM Aircall__c WHERE Lettre__c != null)
                LIMIT :CHUNK_SIZE
            ];
        }
        // scope = 'all'
        return [
            SELECT Id
            FROM Lettre__c
            WHERE Nom_d_import__c = :importName
            LIMIT :CHUNK_SIZE
        ];
    }

    private String scopeLabel() {
        if (scope == 'with-aircall') return ' (avec Aircall)';
        if (scope == 'without-aircall') return ' (sans Aircall)';
        return '';
    }

    private void sendNotification() {
        try {
            List<CustomNotificationType> notifTypes = [
                SELECT Id
                FROM CustomNotificationType
                WHERE DeveloperName = :NOTIFICATION_DEV_NAME
                LIMIT 1
            ];
            if (notifTypes.isEmpty()) {
                return;
            }
            Messaging.CustomNotification notif = new Messaging.CustomNotification();
            notif.setTitle('Suppression « ' + importName + ' »' + scopeLabel() + ' terminée');
            String body = deletedCount + ' lettre(s) supprimée(s)';
            if (failedCount > 0) {
                body += ' • ' + failedCount + ' échec(s)';
            }
            notif.setBody(body);
            notif.setNotificationTypeId(notifTypes[0].Id);
            notif.setTargetId(userId);
            notif.send(new Set<String>{ String.valueOf(userId) });
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Erreur notification suppression : ' + e.getMessage());
        }
    }
}