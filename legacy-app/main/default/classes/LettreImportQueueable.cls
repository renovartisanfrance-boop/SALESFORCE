public without sharing class LettreImportQueueable implements Queueable {

    private static final Integer CHUNK_SIZE = 200;
    private static final String NOTIFICATION_DEV_NAME = 'Lettre_Import_Notification';

    private List<Map<String, Object>> rows;
    private String objectApiName;
    private String importName;
    private Id userId;
    private String userEmail;
    private Integer chunkIndex;
    private List<FailureRecord> failures;
    private Integer successCount;

    public LettreImportQueueable(
        List<Map<String, Object>> rows,
        String objectApiName,
        String importName,
        Id userId,
        String userEmail
    ) {
        this(rows, objectApiName, importName, userId, userEmail, 0, new List<FailureRecord>(), 0);
    }

    private LettreImportQueueable(
        List<Map<String, Object>> rows,
        String objectApiName,
        String importName,
        Id userId,
        String userEmail,
        Integer chunkIndex,
        List<FailureRecord> failures,
        Integer successCount
    ) {
        this.rows = rows;
        this.objectApiName = objectApiName;
        this.importName = importName;
        this.userId = userId;
        this.userEmail = userEmail;
        this.chunkIndex = chunkIndex;
        this.failures = failures;
        this.successCount = successCount;
    }

    public void execute(QueueableContext context) {
        Schema.SObjectType sobjType = Schema.getGlobalDescribe().get(objectApiName);
        if (sobjType == null) {
            return;
        }
        Map<String, Schema.SObjectField> fieldMap = sobjType.getDescribe().fields.getMap();

        Integer startIdx = chunkIndex * CHUNK_SIZE;
        Integer endIdx = Math.min(startIdx + CHUNK_SIZE, rows.size());

        List<SObject> chunkRecords = new List<SObject>();
        List<Integer> originalIndexes = new List<Integer>();
        for (Integer i = startIdx; i < endIdx; i++) {
            SObject rec = sobjType.newSObject();
            Map<String, Object> rowData = rows[i];
            for (String fieldApi : rowData.keySet()) {
                Object val = rowData.get(fieldApi);
                if (val == null) continue;
                try {
                    Object coerced = coerceValue(val, fieldMap.get(fieldApi.toLowerCase()));
                    if (coerced != null) {
                        rec.put(fieldApi, coerced);
                    }
                } catch (Exception e) {
                    System.debug(LoggingLevel.WARN,
                        'Conversion impossible pour ' + fieldApi + '=' + val + ' : ' + e.getMessage()
                    );
                }
            }
            chunkRecords.add(rec);
            originalIndexes.add(i);
        }

        Database.SaveResult[] results = Database.insert(chunkRecords, false);
        for (Integer i = 0; i < results.size(); i++) {
            if (results[i].isSuccess()) {
                successCount++;
            } else {
                FailureRecord fr = new FailureRecord();
                fr.rowIndex = originalIndexes[i];
                fr.data = rows[originalIndexes[i]];
                fr.errorMessage = results[i].getErrors()[0].getMessage();
                failures.add(fr);
            }
        }

        if (endIdx < rows.size()) {
            if (!Test.isRunningTest()) {
                System.enqueueJob(new LettreImportQueueable(
                    rows,
                    objectApiName,
                    importName,
                    userId,
                    userEmail,
                    chunkIndex + 1,
                    failures,
                    successCount
                ));
            }
        } else {
            sendCompletionEmail();
            sendNotification();
        }
    }

    private void sendCompletionEmail() {
        if (failures.isEmpty()) {
            return;
        }

        String csv = buildFailureCsv();
        Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
        attachment.setFileName('lettres_non_importees.csv');
        attachment.setBody(Blob.valueOf(csv));
        attachment.setContentType('text/csv');

        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setTargetObjectId(userId);
        email.setTreatTargetObjectAsRecipient(true);
        email.setSaveAsActivity(false);
        email.setSubject('Import « ' + importName + ' » terminé — lignes en échec');
        email.setPlainTextBody(
            'L\'import « ' + importName + ' » est terminé.\n\n' +
            successCount + ' ligne(s) importée(s) avec succès.\n' +
            failures.size() + ' ligne(s) en échec — voir le CSV joint.\n\n' +
            'Vous pouvez corriger les lignes en échec et relancer l\'import.'
        );
        email.setFileAttachments(new List<Messaging.EmailFileAttachment>{ attachment });

        Messaging.SendEmailResult[] results = Messaging.sendEmail(
            new List<Messaging.SingleEmailMessage>{ email },
            false
        );

        for (Messaging.SendEmailResult r : results) {
            if (!r.isSuccess()) {
                for (Messaging.SendEmailError err : r.getErrors()) {
                    System.debug(LoggingLevel.ERROR,
                        'Echec envoi email - statusCode=' + err.getStatusCode() +
                        ' message=' + err.getMessage() +
                        ' targetObjectId=' + err.getTargetObjectId()
                    );
                }
            } else {
                System.debug(LoggingLevel.INFO, 'Email d\'import envoyé à userId=' + userId);
            }
        }
    }

    private String buildFailureCsv() {
        Set<String> keySet = new Set<String>();
        for (FailureRecord fr : failures) {
            keySet.addAll(fr.data.keySet());
        }
        List<String> keys = new List<String>(keySet);
        keys.sort();

        List<String> headerCells = new List<String>();
        headerCells.add('Ligne');
        headerCells.addAll(keys);
        headerCells.add('Erreur');

        List<String> lines = new List<String>();
        lines.add(String.join(headerCells, ','));

        for (FailureRecord fr : failures) {
            List<String> cells = new List<String>();
            cells.add(String.valueOf(fr.rowIndex + 2));
            for (String k : keys) {
                Object v = fr.data.get(k);
                cells.add(escapeCsv(v == null ? '' : String.valueOf(v)));
            }
            cells.add(escapeCsv(fr.errorMessage));
            lines.add(String.join(cells, ','));
        }
        return String.join(lines, '\n');
    }

    private Object coerceValue(Object raw, Schema.SObjectField sobjField) {
        if (raw == null || sobjField == null) {
            return raw;
        }
        Schema.DescribeFieldResult dfr = sobjField.getDescribe();
        Schema.DisplayType t = dfr.getType();
        String s = String.valueOf(raw);

        if (t == Schema.DisplayType.Date) {
            // Format attendu depuis le LWC : YYYY-MM-DD
            String datePart = s.length() >= 10 ? s.substring(0, 10) : s;
            return Date.valueOf(datePart);
        }
        if (t == Schema.DisplayType.DateTime) {
            // ISO 8601 envoyé par le LWC : 2025-12-31T14:30:00.000Z
            // JSON.deserialize gère ce format nativement
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

    private String escapeCsv(String s) {
        if (s == null) {
            return '';
        }
        if (s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r')) {
            return '"' + s.replace('"', '""') + '"';
        }
        return s;
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
            notif.setTitle('Import « ' + importName + ' » terminé');
            String body = successCount + ' ligne(s) importée(s)';
            if (!failures.isEmpty()) {
                body += ' • ' + failures.size() + ' en échec (CSV envoyé par email)';
            }
            // System.debug('Notification body: ' + body);
            notif.setBody(body);
            notif.setNotificationTypeId(notifTypes[0].Id);
            notif.setTargetId(userId);
            notif.send(new Set<String>{ String.valueOf(userId) });
        } catch (Exception e) {
            System.debug('Erreur notification : ' + e.getMessage());
        }
    }

    public class FailureRecord {
        public Integer rowIndex;
        public Map<String, Object> data;
        public String errorMessage;
    }
}