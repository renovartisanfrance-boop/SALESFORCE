public with sharing class PaiementFacturationController {

    /**
     * Indique si l'utilisateur courant est un utilisateur de portail/communauté
     * (par opposition à un utilisateur interne / administrateur système).
     * Les utilisateurs internes ont un UserType 'Standard'.
     */
    @AuraEnabled(cacheable=true)
    public static Boolean isCommunityUser() {
        return UserInfo.getUserType() != 'Standard';
    }

    @AuraEnabled
    public static List<LigneFacture__c> getLignesByDossier(Id dossierId) {
        if (dossierId == null) return new List<LigneFacture__c>();
        return [
            SELECT Id, Type_Intervenant__c, Numero_Echeance__c, Statut__c,
                   Numero_Facture_Fournisseur__c, Date_Facture_Fournisseur__c,
                   Facture__c
            FROM LigneFacture__c
            WHERE Dossier__c = :dossierId
        ];
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getDossierInfo(Id dossierId) {
        if (dossierId == null) {
            throw new AuraHandledException('Dossier requis');
        }
        SObjectType sot = dossierId.getSObjectType();
        Map<String, SObjectField> fMap = sot.getDescribe().fields.getMap();

        List<String> wanted = new List<String>{ 'Id', 'Name', 'Fiche_CEE__c' };
        List<String> present = new List<String>();
        for (String f : wanted) {
            if (fMap.containsKey(f.toLowerCase())) present.add(f);
        }
        String soql = 'SELECT ' + String.join(present, ', ') +
                      ' FROM ' + String.valueOf(sot) +
                      ' WHERE Id = :dossierId LIMIT 1';
        SObject rec = Database.query(soql);

        Map<String, Object> out = new Map<String, Object>();
        out.put('Id', rec.Id);
        out.put('Name', rec.get('Name'));
        out.put('Fiche_CEE__c', fMap.containsKey('fiche_cee__c') ? rec.get('Fiche_CEE__c') : null);
        return out;
    }

    @AuraEnabled
    public static Id createLigneFacture(
        Id dossierId,
        String typeIntervenant,
        Decimal montant,
        Integer numEcheance,
        String echeanceDeclenchante,
        String numeroFactureFournisseur,
        String dateFactureFournisseur,
        Id intervenantCompteId,
        String champLookupApi
    ) {
        if (dossierId == null) throw new AuraHandledException('Dossier requis');
        if (String.isBlank(typeIntervenant)) throw new AuraHandledException('Intervenant requis');
        if (montant == null || montant <= 0) throw new AuraHandledException('Montant invalide');
        if (numEcheance == null) throw new AuraHandledException('Numéro d échéance requis');

        // Vérification : le compte bénéficiaire saisi doit correspondre à
        // l'intervenant rattaché au dossier (lève une exception sinon).
        validateIntervenantCompte(dossierId, champLookupApi, intervenantCompteId, typeIntervenant);

        // Contexte du dossier figé sur la ligne : critères ayant servi à la
        // sélection de la grille tarifaire au moment de la création.
        Pro__c dossier = [
            SELECT Id, Name, Fiche_CEE__c, DR_Zone__c, MPR_SHAB__c,
                   MPR_PRECARITE__c, CodePostal__c, Piste_Date_de_Cr_ation__c,
                   GrillesUtilises__c
            FROM Pro__c
            WHERE Id = :dossierId
            LIMIT 1
        ];

        String numEchStr = String.valueOf(numEcheance);
        List<LigneFacture__c> existing = [
            SELECT Id
            FROM LigneFacture__c
            WHERE Dossier__c = :dossierId
              AND Type_Intervenant__c = :typeIntervenant
              AND Numero_Echeance__c = :numEchStr
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            throw new AuraHandledException(
                'Une ligne de facture existe déjà pour ce dossier, intervenant « ' + typeIntervenant +
                ' » et commission ' + numEchStr + '.'
            );
        }

        LigneFacture__c lf = new LigneFacture__c();
        lf.Dossier__c = dossierId;
        lf.Montant_HT__c = montant;
        lf.Numero_Echeance__c = numEchStr;
        lf.Type_Intervenant__c = typeIntervenant;
        if (String.isNotBlank(numeroFactureFournisseur)) {
            lf.Numero_Facture_Fournisseur__c = numeroFactureFournisseur;
        }
        if (String.isNotBlank(dateFactureFournisseur)) {
            try {
                lf.Date_Facture_Fournisseur__c = Date.valueOf(dateFactureFournisseur);
            } catch (Exception ex) {
                throw new AuraHandledException('Date de facture invalide : ' + dateFactureFournisseur);
            }
        }
        if (String.isNotBlank(echeanceDeclenchante)) {
            lf.Echeance_Declenchante__c = echeanceDeclenchante;
        }
        if (intervenantCompteId != null) {
            lf.Intervenant_Compte__c = intervenantCompteId;
        }

        // Snapshot du contexte de sélection du prix (figé, non recalculé ensuite).
        lf.Fiche_CEE__c = dossier.Fiche_CEE__c;
        lf.Zone_Climatique__c = dossier.DR_Zone__c;
        lf.Surface_SHAB__c = dossier.MPR_SHAB__c;
        lf.Niveau_Precarite__c = dossier.MPR_PRECARITE__c;
        lf.Code_Postal__c = dossier.CodePostal__c;
        lf.Date_Reference_Tarif__c = dossier.Piste_Date_de_Cr_ation__c;

        // Grille tarifaire source : dernière grille listée pour cet intervenant
        // dans GrillesUtilises__c (format "Intervenant:GT-00044;..."). Résolue par
        // son Name ; laissée vide si introuvable.
        String grilleName = resolveLastGrilleName(dossier.GrillesUtilises__c, typeIntervenant);
        if (String.isNotBlank(grilleName)) {
            List<GrilleTarifaire__c> grilles = [
                SELECT Id FROM GrilleTarifaire__c WHERE Name = :grilleName LIMIT 1
            ];
            if (!grilles.isEmpty()) {
                lf.Grille_Source__c = grilles[0].Id;
            }
        }

        insert lf;
        return lf.Id;
    }

    /**
     * Point d'entrée appelable depuis le LWC pour rejouer la vérification du
     * compte bénéficiaire en dehors de la création (ex. lors d'une modification
     * de ligne). Lève une AuraHandledException avec un message si non conforme.
     */
    @AuraEnabled
    public static void verifierIntervenantCompte(
        Id dossierId, String champLookupApi, Id intervenantCompteId, String typeIntervenant
    ) {
        validateIntervenantCompte(dossierId, champLookupApi, intervenantCompteId, typeIntervenant);
    }

    /**
     * Vérifie, avant création de la ligne, que le compte bénéficiaire saisi
     * correspond à l'intervenant rattaché au dossier via son champ lookup.
     *
     * Règles :
     *  - champLookup de type Compte (Account) : comparaison directe.
     *  - champLookup de type Utilisateur (User) : résolution User -> Contact -> Compte
     *    puis comparaison.
     *  - champLookup de type Campagne (Campaign, Régie) : résolution Campagne ->
     *    premier Compte rattaché (Account.Acces_REGIE__c, relation Compte_Regie__r)
     *    puis comparaison.
     *  - champLookup vide sur le dossier : message invitant à renseigner l'intervenant.
     */
    @TestVisible
    private static void validateIntervenantCompte(
        Id dossierId, String champLookupApi, Id intervenantCompteId, String typeIntervenant
    ) {
        if (String.isBlank(champLookupApi)) return; // aucun champ configuré -> pas de contrôle

        Map<String, SObjectField> fMap = Pro__c.SObjectType.getDescribe().fields.getMap();
        SObjectField fld = fMap.get(champLookupApi.toLowerCase());
        if (fld == null) return; // champ inconnu sur le dossier -> on ne bloque pas

        List<Schema.SObjectType> refs = fld.getDescribe().getReferenceTo();
        String refObj = refs.isEmpty() ? null : String.valueOf(refs[0]);

        Id dossierCompteId = null;
        Boolean lookupRenseigne = false;

        if (refObj == 'Account') {
            SObject rec = Database.query(
                'SELECT ' + champLookupApi + ' FROM Pro__c WHERE Id = :dossierId LIMIT 1'
            );
            dossierCompteId = (Id) rec.get(champLookupApi);
            lookupRenseigne = dossierCompteId != null;
        } else if (refObj == 'User') {
            // User -> Contact -> Compte
            String rel = champLookupApi.replace('__c', '__r');
            SObject rec = Database.query(
                'SELECT ' + champLookupApi + ', ' + rel + '.Contact.AccountId ' +
                'FROM Pro__c WHERE Id = :dossierId LIMIT 1'
            );
            lookupRenseigne = rec.get(champLookupApi) != null;
            SObject userRec = rec.getSObject(rel);
            if (userRec != null) {
                SObject contactRec = userRec.getSObject('Contact');
                if (contactRec != null) {
                    dossierCompteId = (Id) contactRec.get('AccountId');
                }
            }
        } else if (refObj == 'Campaign') {
            // Régie : le dossier pointe une Campagne. Le compte régie est le
            // premier Account rattaché à cette campagne via la relation
            // Compte_Regie__r (champ Account.Acces_REGIE__c).
            SObject rec = Database.query(
                'SELECT ' + champLookupApi + ' FROM Pro__c WHERE Id = :dossierId LIMIT 1'
            );
            Id campagneId = (Id) rec.get(champLookupApi);
            lookupRenseigne = campagneId != null;
            if (campagneId != null) {
                List<Campaign> camps = [
                    SELECT Id, (SELECT Id FROM Compte_Regie__r LIMIT 1)
                    FROM Campaign WHERE Id = :campagneId LIMIT 1
                ];
                if (!camps.isEmpty()) {
                    List<SObject> comptes = camps[0].getSObjects('Compte_Regie__r');
                    if (comptes != null && !comptes.isEmpty()) {
                        dossierCompteId = (Id) comptes[0].get('Id');
                    }
                }
            }
        } else {
            return; // autre type de référence -> pas de contrôle
        }

        // Intervenant non renseigné sur le dossier.
        if (!lookupRenseigne) {
            throw new AuraHandledException(
                'L\'intervenant « ' + typeIntervenant + ' » n\'est pas renseigné au niveau du dossier. ' +
                'Veuillez faire attention au moment du choix du compte bénéficiaire.'
            );
        }

        // Comparaison compte saisi vs compte du dossier.
        if (intervenantCompteId == null || dossierCompteId == null || intervenantCompteId != dossierCompteId) {
            throw new AuraHandledException(
                'Le compte bénéficiaire sélectionné ne correspond pas à l\'intervenant « ' +
                typeIntervenant + ' » renseigné sur le dossier.'
            );
        }
    }

    /**
     * Extrait le nom de la dernière grille associée à un intervenant dans la
     * chaîne sérialisée GrillesUtilises__c (ex. "Apporteur d'Affaire:GT-00019;
     * Telepro:GT-00027;Telepro:GT-00044;"). Renvoie GT-00044 pour Telepro.
     */
    @TestVisible
    private static String resolveLastGrilleName(String grillesUtilises, String typeIntervenant) {
        if (String.isBlank(grillesUtilises) || String.isBlank(typeIntervenant)) {
            return null;
        }
        String found = null;
        for (String entry : grillesUtilises.split(';')) {
            if (String.isBlank(entry)) continue;
            Integer sep = entry.indexOf(':');
            if (sep < 0) continue;
            String key = entry.substring(0, sep).trim();
            String val = entry.substring(sep + 1).trim();
            if (key == typeIntervenant.trim() && String.isNotBlank(val)) {
                found = val; // on garde la dernière occurrence
            }
        }
        return found;
    }

    @AuraEnabled
    public static LigneFacture__c getLigneFacture(Id ligneId) {
        if (ligneId == null) throw new AuraHandledException('Ligne de facture requise');
        return [
            SELECT Id, Name, Dossier__c, Fiche_CEE__c, Type_Intervenant__c,
                   Numero_Echeance__c, Echeance_Declenchante__c,
                   Montant_HT__c, Montant_Total__c, Numero_Facture_Fournisseur__c,
                   Date_Facture_Fournisseur__c, Date_Reception__c,
                   Commentaire__c, Assujetti_TVA__c, Taux_TVA__c,
                   Statut__c, Motif_Rejet__c, Facture__c, Intervenant_Compte__c
            FROM LigneFacture__c
            WHERE Id = :ligneId
            LIMIT 1
        ];
    }

    @AuraEnabled
    public static Id updateLigneFacture(Id ligneId, Map<String, Object> fields) {
        if (ligneId == null) throw new AuraHandledException('Ligne de facture requise');
        if (fields == null || fields.isEmpty()) return ligneId;

        Map<String, SObjectField> fMap = LigneFacture__c.SObjectType.getDescribe().fields.getMap();
        LigneFacture__c lf = new LigneFacture__c(Id = ligneId);
        for (String key : fields.keySet()) {
            String k = key.toLowerCase();
            if (!fMap.containsKey(k)) continue;
            Object v = fields.get(key);
            Schema.DisplayType dt = fMap.get(k).getDescribe().getType();

            if (v == null || (v instanceof String && String.isBlank((String) v))) {
                lf.put(key, null);
                continue;
            }

            try {
                if (dt == Schema.DisplayType.DATE && v instanceof String) {
                    lf.put(key, Date.valueOf((String) v));
                } else if (dt == Schema.DisplayType.DATETIME && v instanceof String) {
                    lf.put(key, DateTime.valueOfGmt(((String) v).replace('T', ' ').replace('Z', '')));
                } else if ((dt == Schema.DisplayType.DOUBLE || dt == Schema.DisplayType.CURRENCY ||
                            dt == Schema.DisplayType.PERCENT) && v instanceof String) {
                    lf.put(key, Decimal.valueOf((String) v));
                } else if (dt == Schema.DisplayType.INTEGER && v instanceof String) {
                    lf.put(key, Integer.valueOf((String) v));
                } else if (dt == Schema.DisplayType.BOOLEAN && v instanceof String) {
                    lf.put(key, Boolean.valueOf((String) v));
                } else {
                    lf.put(key, v);
                }
            } catch (Exception ex) {
                throw new AuraHandledException('Valeur invalide pour ' + key + ' : ' + ex.getMessage());
            }
        }
        update lf;
        return lf.Id;
    }
}