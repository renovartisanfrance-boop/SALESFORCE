public with sharing class LettrageFacturesController {

    @AuraEnabled(cacheable=true)
    public static Lettrage__c getLettrageInfo(Id lettrageId) {
        if (lettrageId == null) throw new AuraHandledException('Lettrage requis');
        return [
            SELECT Id, Name, Statut__c, Montant_Total__c, Date_Paiement__c,
                   Reference_Bancaire__c, Moyen_Paiement__c, Commentaire__c
            FROM Lettrage__c
            WHERE Id = :lettrageId
            LIMIT 1
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Facture__c> getFacturesLiees(Id lettrageId) {
        if (lettrageId == null) return new List<Facture__c>();
        return [
            SELECT Id, Name, N_Facture_Externe__c, Statut__c, Montant_Total__c,
                   Date_Paiement__c, Reference_Bancaire__c, Moyen_Paiement__c
            FROM Facture__c
            WHERE Lettrage__c = :lettrageId
            ORDER BY CreatedDate DESC
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Facture__c> getFacturesDisponibles() {
        return [
            SELECT Id, Name, N_Facture_Externe__c, Statut__c, Montant_Total__c,
                   Date_Paiement__c, Reference_Bancaire__c, Moyen_Paiement__c
            FROM Facture__c
            WHERE Lettrage__c = null AND Statut__c = 'Validé'
            ORDER BY CreatedDate DESC
            LIMIT 500
        ];
    }

    @AuraEnabled
    public static Integer linkFactures(Id lettrageId, List<Id> factureIds) {
        if (lettrageId == null) throw new AuraHandledException('Lettrage requis');
        if (factureIds == null || factureIds.isEmpty()) {
            throw new AuraHandledException('Aucune facture sélectionnée');
        }

        List<Facture__c> toUpdate = [
            SELECT Id, Lettrage__c
            FROM Facture__c
            WHERE Id IN :factureIds
        ];

        for (Facture__c f : toUpdate) {
            if (f.Lettrage__c != null && f.Lettrage__c != lettrageId) {
                throw new AuraHandledException(
                    'La facture ' + f.Id + ' est déjà liée à un autre lettrage.'
                );
            }
            f.Lettrage__c = lettrageId;
        }
        update toUpdate;
        return toUpdate.size();
    }

    @AuraEnabled
    public static Id unlinkFacture(Id factureId) {
        if (factureId == null) throw new AuraHandledException('Facture requise');
        Facture__c f = new Facture__c(Id = factureId, Lettrage__c = null);
        update f;
        return factureId;
    }

    @AuraEnabled
    public static Id createLettrageAvecFactures(Map<String, Object> fields, List<Id> factureIds) {
        if (factureIds == null || factureIds.isEmpty()) {
            throw new AuraHandledException('Au moins une facture doit être sélectionnée pour créer un lettrage.');
        }

        Lettrage__c l = new Lettrage__c();
        Map<String, Schema.SObjectField> fMap = Lettrage__c.SObjectType.getDescribe().fields.getMap();

        if (fields != null) {
            for (String key : fields.keySet()) {
                String k = key.toLowerCase();
                if (!fMap.containsKey(k)) continue;
                Object v = fields.get(key);
                Schema.DisplayType dt = fMap.get(k).getDescribe().getType();

                if (v == null || (v instanceof String && String.isBlank((String) v))) {
                    l.put(key, null);
                    continue;
                }
                try {
                    if (dt == Schema.DisplayType.DATE && v instanceof String) {
                        l.put(key, Date.valueOf((String) v));
                    } else if (dt == Schema.DisplayType.DATETIME && v instanceof String) {
                        l.put(key, DateTime.valueOfGmt(((String) v).replace('T', ' ').replace('Z', '')));
                    } else if ((dt == Schema.DisplayType.DOUBLE || dt == Schema.DisplayType.CURRENCY ||
                                dt == Schema.DisplayType.PERCENT) && v instanceof String) {
                        l.put(key, Decimal.valueOf((String) v));
                    } else if (dt == Schema.DisplayType.INTEGER && v instanceof String) {
                        l.put(key, Integer.valueOf((String) v));
                    } else if (dt == Schema.DisplayType.BOOLEAN && v instanceof String) {
                        l.put(key, Boolean.valueOf((String) v));
                    } else {
                        l.put(key, v);
                    }
                } catch (Exception ex) {
                    throw new AuraHandledException('Valeur invalide pour ' + key + ' : ' + ex.getMessage());
                }
            }
        }

        List<Facture__c> factures = [
            SELECT Id, Lettrage__c, Montant_Total__c
            FROM Facture__c
            WHERE Id IN :factureIds
        ];
        Decimal totalFactures = 0;
        for (Facture__c f : factures) {
            if (f.Lettrage__c != null) {
                throw new AuraHandledException('La facture ' + f.Id + ' est déjà liée à un autre lettrage.');
            }
            if (f.Montant_Total__c != null) totalFactures += f.Montant_Total__c;
        }

        Decimal totalLettrage = l.Montant_Total__c == null ? 0 : l.Montant_Total__c;
        if (totalLettrage.setScale(2) != totalFactures.setScale(2)) {
            throw new AuraHandledException(
                'Le montant du lettrage (' + totalLettrage.setScale(2) +
                ' €) doit être égal au total des factures sélectionnées (' + totalFactures.setScale(2) + ' €).'
            );
        }

        try {
            insert l;
        } catch (DmlException ex) {
            if (ex.getMessage().contains('DUPLICATES_DETECTED')) {
                throw new AuraHandledException('Un lettrage avec les mêmes informations existe déjà.');
            }
            throw new AuraHandledException('Erreur lors de la création du lettrage : ' + ex.getMessage());
        }

        for (Facture__c f : factures) {
            f.Lettrage__c = l.Id;
        }
        try {
            update factures;
        } catch (DmlException ex) {
            throw new AuraHandledException('Erreur lors de la liaison des factures : ' + ex.getMessage());
        }
        return l.Id;
    }
}