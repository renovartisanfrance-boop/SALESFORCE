public without sharing class LettreUpdateQueueable implements Queueable {

    private static final Integer CHUNK_SIZE = 200;
    private static final String NOTIFICATION_DEV_NAME = 'Lettre_Import_Notification';

    private List<Map<String, Object>> rows;
    private Id userId;
    private Integer chunkIndex;
    private Integer successCount;
    private Integer failCount;

    public LettreUpdateQueueable(List<Map<String, Object>> rows, Id userId) {
        this(rows, userId, 0, 0, 0);
    }

    private LettreUpdateQueueable(List<Map<String, Object>> rows, Id userId, Integer chunkIndex, Integer successCount, Integer failCount) {
        this.rows = rows;
        this.userId = userId;
        this.chunkIndex = chunkIndex;
        this.successCount = successCount;
        this.failCount = failCount;
    }

    public void execute(QueueableContext context) {
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Lettre__c.fields.getMap();
        Integer startIdx = chunkIndex * CHUNK_SIZE;
        Integer endIdx = Math.min(startIdx + CHUNK_SIZE, rows.size());
        List<Lettre__c> toUpdate = new List<Lettre__c>();

        for (Integer i = startIdx; i < endIdx; i++) {
            Map<String, Object> rowData = rows[i];
            Object idVal = rowData.get('Id');
            if (idVal == null) continue;
            Lettre__c rec = new Lettre__c(Id = (Id) idVal);
            for (String f : rowData.keySet()) {
                if (f == 'Id') continue;
                Object v = rowData.get(f);
                try {
                    rec.put(f, coerce(v, fieldMap.get(f.toLowerCase())));
                } catch (Exception e) {
                    System.debug(LoggingLevel.WARN, 'Conversion impossible pour ' + f + '=' + v + ' : ' + e.getMessage());
                }
            }
            toUpdate.add(rec);
        }

        Database.SaveResult[] results = Database.update(toUpdate, false);
        for (Database.SaveResult r : results) {
            if (r.isSuccess()) successCount++;
            else failCount++;
        }

        if (endIdx < rows.size()) {
            if (!Test.isRunningTest()) {
                System.enqueueJob(new LettreUpdateQueueable(rows, userId, chunkIndex + 1, successCount, failCount));
            }
        } else {
            sendNotification();
        }
    }

    private Object coerce(Object raw, Schema.SObjectField sobjField) {
        if (raw == null || sobjField == null) return raw;
        Schema.DescribeFieldResult dfr = sobjField.getDescribe();
        Schema.DisplayType t = dfr.getType();
        String s = String.valueOf(raw);
        if (String.isBlank(s)) return null;
        if (t == Schema.DisplayType.Date) {
            String datePart = s.length() >= 10 ? s.substring(0, 10) : s;
            return Date.valueOf(datePart);
        }
        if (t == Schema.DisplayType.DateTime) {
            return (DateTime) JSON.deserialize('"' + s + '"', DateTime.class);
        }
        if (t == Schema.DisplayType.Boolean) {
            if (raw instanceof Boolean) return raw;
            String low = s.toLowerCase();
            return low == 'true' || low == '1' || low == 'oui' || low == 'yes';
        }
        if (t == Schema.DisplayType.Integer) {
            if (raw instanceof Integer) return raw;
            return Integer.valueOf(s);
        }
        if (t == Schema.DisplayType.Double || t == Schema.DisplayType.Currency || t == Schema.DisplayType.Percent) {
            if (raw instanceof Decimal || raw instanceof Double) return raw;
            return Decimal.valueOf(s);
        }
        return raw;
    }

    private void sendNotification() {
        try {
            List<CustomNotificationType> types = [
                SELECT Id FROM CustomNotificationType
                WHERE DeveloperName = :NOTIFICATION_DEV_NAME LIMIT 1
            ];
            if (types.isEmpty()) return;
            Messaging.CustomNotification notif = new Messaging.CustomNotification();
            notif.setTitle('Modification en masse terminée');
            String body = successCount + ' lettre(s) modifiée(s)';
            if (failCount > 0) body += ' • ' + failCount + ' échec(s)';
            notif.setBody(body);
            notif.setNotificationTypeId(types[0].Id);
            notif.setTargetId(userId);
            notif.send(new Set<String>{ String.valueOf(userId) });
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Erreur notification update : ' + e.getMessage());
        }
    }
}