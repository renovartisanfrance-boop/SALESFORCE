public with sharing class FacturesController {

    @AuraEnabled(cacheable=true)
    public static Facture__c getFactureInfo(Id factureId) {
        if (factureId == null) throw new AuraHandledException('Facture requise');
        return [
            SELECT Id, Name, Statut__c, Montant_Total__c, MontantHT__c, Date_Paiement__c,
                   Montant_TotalAcompte_Avance_HT__c,
                   Reference_Bancaire__c, Moyen_Paiement__c, Commentaire__c
            FROM Facture__c
            WHERE Id = :factureId
            LIMIT 1
        ];
    }

    /**
     * Factures d'acompte (avance) rattachables à une nouvelle facture Classique :
     * acomptes du bénéficiaire choisi non encore liés à une facture classique
     * (Facture_Solde__c vide) et non annulés. Méthode NON cacheable : un acompte
     * vient typiquement d'être créé juste avant la facture classique.
     */
    @AuraEnabled
    public static List<Facture__c> getAcomptesDisponibles(Id destinataireCompteId) {
        if (destinataireCompteId == null) return new List<Facture__c>();
        return [
            SELECT Id, Name, N_Facture_Externe__c, DateFacture__c, Statut__c,
                   MontantHT__c, Montant_Total__c
            FROM Facture__c
            WHERE RecordType.DeveloperName = 'Acompte'
              AND Destinataire_Compte__c = :destinataireCompteId
              AND Facture_Solde__c = null
              AND Statut__c != :Constants.Facture_STATUT_ANNULE
            ORDER BY DateFacture__c DESC NULLS LAST, CreatedDate DESC
            LIMIT 500
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<LigneFacture__c> getLignesLiees(Id factureId) {
        if (factureId == null) return new List<LigneFacture__c>();
        return [
            SELECT Id, Name, Type_Intervenant__c, Numero_Echeance__c, Statut__c,
                Montant_Total__c, Montant_HT__c, Numero_Facture_Fournisseur__c, Date_Facture_Fournisseur__c,
                   Dossier__c, Dossier__r.Name
            FROM LigneFacture__c
            WHERE Facture__c = :factureId
            ORDER BY CreatedDate DESC
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<LigneFacture__c> getLignesDisponibles(Id factureId, Id destinataireCompteId) {
        // Seules les lignes dont l'intervenant (compte bénéficiaire) correspond au
        // bénéficiaire de la facture sont proposées. En édition le bénéficiaire est
        // lu sur la facture ; en création il est transmis depuis le wizard.
        Id dest = destinataireCompteId;

        // Gestion des lignes sur une facture existante (quick action, factureId
        // renseigné) : « disponibles » = uniquement les lignes non liées à une
        // facture. Les lignes de la facture courante sont affichées dans la
        // section « déjà liées » et ne doivent donc pas réapparaître ici.
        if (factureId != null) {
            List<Facture__c> fs = [
                SELECT Destinataire_Compte__c FROM Facture__c WHERE Id = :factureId LIMIT 1
            ];
            dest = fs.isEmpty() ? null : fs[0].Destinataire_Compte__c;

            return [
                SELECT Id, Name, Type_Intervenant__c, Numero_Echeance__c, Statut__c,
                       Montant_Total__c, Montant_HT__c, Numero_Facture_Fournisseur__c, Date_Facture_Fournisseur__c,
                       Dossier__c, Dossier__r.Name, Intervenant_Compte__c,
                       Facture__c, Facture__r.N_Facture_Externe__c, Facture__r.Statut__c
                FROM LigneFacture__c
                WHERE Facture__c = null
                  AND Intervenant_Compte__c = :dest
                ORDER BY CreatedDate DESC
                LIMIT 500
            ];
        }

        // Mode création (aucune facture encore) : lignes non liées + lignes encore
        // rattachées à une facture Brouillon, restreintes au bénéficiaire saisi.
        return [
            SELECT Id, Name, Type_Intervenant__c, Numero_Echeance__c, Statut__c,
                   Montant_Total__c, Montant_HT__c, Numero_Facture_Fournisseur__c, Date_Facture_Fournisseur__c,
                   Dossier__c, Dossier__r.Name, Intervenant_Compte__c,
                   Facture__c, Facture__r.N_Facture_Externe__c, Facture__r.Statut__c
            FROM LigneFacture__c
            WHERE (Facture__c = null OR Facture__r.Statut__c = :Constants.Facture_STATUT_BROUILLON)
              AND Intervenant_Compte__c = :dest
            ORDER BY CreatedDate DESC
            LIMIT 500
        ];
    }

    @AuraEnabled
    public static Integer linkLignes(Id factureId, List<Id> ligneIds) {
        if (factureId == null) throw new AuraHandledException('Facture requise');
        if (ligneIds == null || ligneIds.isEmpty()) {
            throw new AuraHandledException('Aucune ligne sélectionnée');
        }

        // Bénéficiaire de la facture : l'intervenant de chaque ligne doit y correspondre.
        Id destFacture = [
            SELECT Destinataire_Compte__c FROM Facture__c WHERE Id = :factureId LIMIT 1
        ].Destinataire_Compte__c;

        List<LigneFacture__c> toUpdate = [
            SELECT Id, Name, Facture__c, Facture__r.Statut__c, Intervenant_Compte__c
            FROM LigneFacture__c
            WHERE Id IN :ligneIds
        ];

        for (LigneFacture__c f : toUpdate) {
            // On autorise le rattachement d'une ligne libre, déjà liée à la
            // facture courante, ou liée à une autre facture encore au statut
            // Brouillon (déplacement). On refuse seulement si elle est liée à
            // une facture finalisée (Validé / Annulé).
            if (f.Facture__c != null
                    && f.Facture__c != factureId
                    && f.Facture__r.Statut__c != Constants.Facture_STATUT_BROUILLON) {
                throw new AuraHandledException(
                    'La ligne ' + f.Name + ' est déjà liée à une facture qui n\'est pas au statut Brouillon.'
                );
            }
            // Le compte bénéficiaire de la ligne doit être identique à celui de la facture.
            if (f.Intervenant_Compte__c != destFacture) {
                throw new AuraHandledException(
                    'La ligne ' + f.Name + ' a un intervenant (compte bénéficiaire) différent ' +
                    'du bénéficiaire de la facture.'
                );
            }
            f.Facture__c = factureId;
            f.Tech_Bypass__c = ''; // Pour bypasser la validation du montant total lors de la création de la facture
        }
        update toUpdate;
        return toUpdate.size();
    }

    @AuraEnabled
    public static Id createFactureAvecLignes(Map<String, Object> fields, List<Id> ligneIds, List<Id> acompteIds) {
        Facture__c f = new Facture__c();
        Map<String, Schema.SObjectField> fMap = Facture__c.SObjectType.getDescribe().fields.getMap();

        if (fields != null) {
            for (String key : fields.keySet()) {
                String k = key.toLowerCase();
                if (!fMap.containsKey(k)) continue;
                Object v = fields.get(key);
                Schema.DisplayType dt = fMap.get(k).getDescribe().getType();

                if (v == null || (v instanceof String && String.isBlank((String) v))) {
                    f.put(key, null);
                    continue;
                }
                try {
                    if (dt == Schema.DisplayType.DATE && v instanceof String) {
                        f.put(key, Date.valueOf((String) v));
                    } else if (dt == Schema.DisplayType.DATETIME && v instanceof String) {
                        f.put(key, DateTime.valueOfGmt(((String) v).replace('T', ' ').replace('Z', '')));
                    } else if ((dt == Schema.DisplayType.DOUBLE || dt == Schema.DisplayType.CURRENCY ||
                                dt == Schema.DisplayType.PERCENT) && v instanceof String) {
                        f.put(key, Decimal.valueOf((String) v));
                    } else if (dt == Schema.DisplayType.INTEGER && v instanceof String) {
                        f.put(key, Integer.valueOf((String) v));
                    } else if (dt == Schema.DisplayType.BOOLEAN && v instanceof String) {
                        f.put(key, Boolean.valueOf((String) v));
                    } else {
                        f.put(key, v);
                    }
                } catch (Exception ex) {
                    throw new AuraHandledException('Valeur invalide pour ' + key + ' : ' + ex.getMessage());
                }
            }
        }

        String RT_Classique_Id = Schema.SObjectType.Facture__c.getRecordTypeInfosByName().get('Classique').getRecordTypeId();
        if (f.RecordTypeId == RT_Classique_Id) {
            if(ligneIds == null || ligneIds.isEmpty()) {
                throw new AuraHandledException('Au moins une ligne est requise pour une facture de type Classique.');
            }
        }

        // Bénéficiaire saisi sur la facture : chaque ligne doit avoir le même
        // intervenant (compte bénéficiaire). La valeur a pu être posée dynamiquement
        // sous forme de String -> on normalise en Id (gère aussi 15/18 caractères).
        // Facture reçue : le compte est le Destinataire ; facture émise : il est porté
        // par le Fournisseur (le Destinataire y est rempli par le trigger APRÈS cette
        // validation, il est donc encore vide ici).
        Object destRaw = f.get('Destinataire_Compte__c');
        if (destRaw == null &&
            Facture__c.SObjectType.getDescribe().fields.getMap().containsKey('fournisseur_compte__c')) {
            destRaw = f.get('Fournisseur_Compte__c');
        }
        Id destFacture = destRaw == null ? null : Id.valueOf(String.valueOf(destRaw));

        // --- Acomptes (avances) sélectionnés --------------------------------
        // Les acomptes sont toujours créés AVANT la facture Classique. À la
        // création de celle-ci, l'utilisateur peut rattacher les acomptes du
        // bénéficiaire non encore liés : leur total HT est stocké sur la
        // facture (Montant_TotalAcompte_Avance_HT__c) et s'ajoute au montant
        // HT de la facture dans la comparaison avec les lignes.
        List<Facture__c> acomptes = new List<Facture__c>();
        Decimal totalAcomptesHT = 0;
        if (acompteIds != null && !acompteIds.isEmpty()) {
            acomptes = [
                SELECT Id, Name, MontantHT__c, Destinataire_Compte__c,
                       Facture_Solde__c, RecordType.DeveloperName, Statut__c
                FROM Facture__c
                WHERE Id IN :acompteIds
            ];
            for (Facture__c a : acomptes) {
                if (a.RecordType.DeveloperName != 'Acompte') {
                    throw new AuraHandledException(
                        'La facture ' + a.Name + ' n\'est pas une facture d\'acompte.');
                }
                if (a.Facture_Solde__c != null) {
                    throw new AuraHandledException(
                        'L\'acompte ' + a.Name + ' est déjà rattaché à une facture classique.');
                }
                if (a.Statut__c == Constants.Facture_STATUT_ANNULE) {
                    throw new AuraHandledException(
                        'L\'acompte ' + a.Name + ' est annulé : il ne peut pas être rattaché.');
                }
                if (destFacture != null && a.Destinataire_Compte__c != destFacture) {
                    throw new AuraHandledException(
                        'L\'acompte ' + a.Name + ' a un bénéficiaire différent de celui de la facture.');
                }
                if (a.MontantHT__c != null) totalAcomptesHT += a.MontantHT__c;
            }
            f.Montant_TotalAcompte_Avance_HT__c = totalAcomptesHT;
        }

        if (ligneIds != null && !ligneIds.isEmpty()) {
            List<LigneFacture__c> toUpdate = [
                SELECT Id, Name, Facture__c, Montant_Total__c, Montant_HT__c, Facture__r.Statut__c,
                       Intervenant_Compte__c
                FROM LigneFacture__c WHERE Id IN :ligneIds
            ];
            Decimal totalLignes = 0;
            for (LigneFacture__c lf : toUpdate) {
                if (lf.Facture__c != null && lf.Facture__r.Statut__c != Constants.Facture_STATUT_BROUILLON) {
                    throw new AuraHandledException('La ligne ' + lf.Name + ' est déjà liée.');
                }
                if (lf.Intervenant_Compte__c != destFacture) {
                    throw new AuraHandledException(
                        'La ligne ' + lf.Name + ' a un intervenant (compte bénéficiaire) différent ' +
                        'du bénéficiaire de la facture.'
                    );
                }
                if (lf.Montant_HT__c != null) totalLignes += lf.Montant_HT__c;
            }
            // Le total attendu des lignes = montant HT de la facture + total HT
            // des acomptes rattachés (le montant de la Classique ne contient
            // pas les acomptes déjà facturés).
            Decimal totalFacture = (f.MontantHT__c == null ? 0 : f.MontantHT__c) + totalAcomptesHT;
            if (totalFacture.setScale(2) != totalLignes.setScale(2)) {
                throw new AuraHandledException(
                    'Le montant HT de la facture + total des acomptes (' + totalFacture.setScale(2) +
                    ' €) doit être égal au total des lignes sélectionnées (' + totalLignes.setScale(2) + ' €).'
                );
            }

            try {
                insert f;
            } catch (DmlException ex) {
                // Check DUPLICATES_DETECTED:
                    if (ex.getMessage().contains('DUPLICATES_DETECTED')) {
                        throw new AuraHandledException('Une facture avec les mêmes informations existe déjà.');
                    }
                throw new AuraHandledException('Erreur lors de la création de la facture : ' + ex.getMessage());
            }
            for (LigneFacture__c lf : toUpdate) {
                lf.Facture__c = f.Id;
                // lf.Tech_Bypass__c = Constants.BYPASS_CREATION_FACTURE; // Pour bypasser la validation du montant total lors de la création de la facture
            }
            try {
                update toUpdate;
                f.Statut__c = 'Validé'; // TODO
                update f;
            } catch (DmlException ex) {
                throw new AuraHandledException('Erreur lors de la création de la facture : ' + ex.getMessage());
            }
            rattacherAcomptes(acomptes, f.Id);
        } else {
             try {
                insert f;
            } catch (DmlException ex) {
                throw new AuraHandledException('Erreur lors de la création de la facture : ' + ex.getMessage());
            }
            rattacherAcomptes(acomptes, f.Id);
        }
        return f.Id;
    }

    /**
     * Rattache les acomptes sélectionnés à la facture classique nouvellement
     * créée (Facture_Solde__c). Le champ technique Tech_ControleModification__c
     * est horodaté pour bypasser la règle modif_interdite_hors_brouillon : le
     * rattachement doit rester possible sur un acompte déjà validé.
     */
    private static void rattacherAcomptes(List<Facture__c> acomptes, Id factureId) {
        if (acomptes == null || acomptes.isEmpty()) return;
        List<Facture__c> toLink = new List<Facture__c>();
        for (Facture__c a : acomptes) {
            toLink.add(new Facture__c(
                Id = a.Id,
                Facture_Solde__c = factureId,
                Tech_ControleModification__c = System.now()
            ));
        }
        try {
            update toLink;
        } catch (DmlException ex) {
            throw new AuraHandledException(
                'Erreur lors du rattachement des acomptes : ' + ex.getDmlMessage(0));
        }
    }

    @AuraEnabled
    public static Id unlinkLigne(Id ligneId) {
        if (ligneId == null) throw new AuraHandledException('Ligne requise');
        LigneFacture__c f = new LigneFacture__c(Id = ligneId, Facture__c = null, Tech_Bypass__c = '');
        update f;
        return ligneId;
    }

    /**
     * Résultat de la tentative de validation d'une facture.
     */
    public class ValidationFactureResult {
        @AuraEnabled public Boolean valide = false;       // true si la facture est (ou passe) au statut Validé
        @AuraEnabled public Boolean dejaValide = false;   // true si la facture était déjà validée
        @AuraEnabled public String statut;                // statut de la facture après traitement
        @AuraEnabled public List<String> erreurs = new List<String>();
    }

    /**
     * Tente de valider une facture.
     *  - Contrôle les règles de validation existantes (cf. validationRules Facture__c).
     *  - Si aucune erreur : passe la facture au statut Validé.
     *  - Sinon : retourne la liste des manques sous forme de texte, sans rien modifier.
     */
    @AuraEnabled
    public static ValidationFactureResult validerFacture(Id factureId) {
        if (factureId == null) throw new AuraHandledException('Facture requise');

        List<Facture__c> factures = [
            SELECT Id, Name, Statut__c, Destinataire_Compte__c,
                   MontantHT__c, MontantTVA__c, Taux_TVA__c, Montant_Total__c,
                   Montant_TotalAcompte_Avance_HT__c,
                   N_Facture_Externe__c, DateFacture__c, DateEcheance__c, Date_Paiement__c,
                   (SELECT Id, Name, Montant_Total__c, Montant_HT__c, Intervenant_Compte__c FROM Factures_associees__r)
            FROM Facture__c
            WHERE Id = :factureId
            LIMIT 1
        ];
        if (factures.isEmpty()) throw new AuraHandledException('Facture introuvable');

        Facture__c facture = factures[0];
        ValidationFactureResult result = new ValidationFactureResult();
        result.statut = facture.Statut__c;

        // États terminaux : rien à faire
        if (facture.Statut__c == Constants.Facture_STATUT_VALIDE) {
            result.valide = true;
            result.dejaValide = true;
            return result;
        }
        if (facture.Statut__c == Constants.Facture_STATUT_ANNULE) {
            result.valide = false;
            result.erreurs.add('La facture est annulée : elle ne peut pas être validée.');
            return result;
        }

        result.erreurs = collecterErreursValidation(facture);
        if (!result.erreurs.isEmpty()) {
            result.valide = false;
            return result;
        }

        // Aucune erreur -> on valide
        facture.Statut__c = Constants.Facture_STATUT_VALIDE;
        try {
            update facture;
        } catch (DmlException ex) {
            result.valide = false;
            for (Integer i = 0; i < ex.getNumDml(); i++) {
                result.erreurs.add(ex.getDmlMessage(i));
            }
            if (result.erreurs.isEmpty()) result.erreurs.add(ex.getMessage());
            return result;
        }

        result.valide = true;
        result.statut = Constants.Facture_STATUT_VALIDE;
        return result;
    }

    /**
     * Annule une facture.
     *  - Passe le statut à Annulé, renseigne la date d'annulation (date de
     *    l'opération) et le motif.
     *  - supprimerLignes = false : les lignes de paiement sont conservées et
     *    simplement dissociées de la facture (elles redeviennent disponibles).
     *  - supprimerLignes = true  : les lignes de paiement sont définitivement
     *    supprimées de la base de données.
     *
     * @return nombre de lignes de paiement traitées (dissociées ou supprimées).
     */
    /**
     * Récupère le statut courant d'une facture en SOQL fraîche (non cacheable),
     * pour permettre au LWC d'annulation de contourner le cache uiRecordApi /
     * @AuraEnabled(cacheable=true) et de s'assurer qu'il affiche la valeur
     * réellement à jour avant toute action.
     */
    @AuraEnabled
    public static String getStatutFactureFrais(Id factureId) {
        if (factureId == null) throw new AuraHandledException('Facture requise');
        List<Facture__c> factures = [
            SELECT Id, Statut__c FROM Facture__c WHERE Id = :factureId LIMIT 1
        ];
        if (factures.isEmpty()) throw new AuraHandledException('Facture introuvable');
        return factures[0].Statut__c;
    }

    @AuraEnabled
    public static Integer annulerFacture(Id factureId, String motif, Boolean supprimerLignes) {
        if (factureId == null) throw new AuraHandledException('Facture requise');
        if (String.isBlank(motif)) {
            throw new AuraHandledException('Le motif d\'annulation est obligatoire.');
        }

        List<Facture__c> factures = [
            SELECT Id, Statut__c FROM Facture__c WHERE Id = :factureId LIMIT 1
        ];
        if (factures.isEmpty()) throw new AuraHandledException('Facture introuvable');

        Facture__c facture = factures[0];
        if (facture.Statut__c == Constants.Facture_STATUT_ANNULE) {
            throw new AuraHandledException('La facture est déjà annulée.');
        }
        if (facture.Statut__c == Constants.Facture_STATUT_VALIDE) {
            throw new AuraHandledException(
                'La facture est au statut « Validé ». Réinitialisez-la au statut « Brouillon » avant de pouvoir l\'annuler.'
            );
        }

        List<LigneFacture__c> lignes = [
            SELECT Id, Facture__c FROM LigneFacture__c WHERE Facture__c = :factureId
        ];

        // Annulation de la facture
        facture.Statut__c        = Constants.Facture_STATUT_ANNULE;
        facture.Date_Annulation__c = Date.today();
        facture.Motif_Annulation__c = motif;
        try {
            update facture;
        } catch (DmlException ex) {
            throw new AuraHandledException(
                'Erreur lors de l\'annulation de la facture : ' + ex.getDmlMessage(0)
            );
        }

        // Traitement des lignes de paiement
        if (!lignes.isEmpty()) {
            if (supprimerLignes == true) {
                try {
                    delete lignes;
                } catch (DmlException ex) {
                    throw new AuraHandledException(
                        'Erreur lors de la suppression des lignes : ' + ex.getDmlMessage(0)
                    );
                }
            } else {
                for (LigneFacture__c l : lignes) {
                    l.Facture__c = null;
                }
                try {
                    update lignes;
                } catch (DmlException ex) {
                    throw new AuraHandledException(
                        'Erreur lors de la dissociation des lignes : ' + ex.getDmlMessage(0)
                    );
                }
            }
        }

        return lignes.size();
    }

    /**
     * Remet une facture au statut « Brouillon ». Seul le statut est modifié ;
     * aucun autre champ n'est vidé. Le champ technique Tech_ControleModification__c
     * est horodaté (DateTime now) pour déclencher le bypass des règles de
     * validation prévu à cet effet.
     */
    @AuraEnabled
    public static void reinitialiserFacture(Id factureId) {
        if (factureId == null) throw new AuraHandledException('Facture requise');

        // Vérification serveur via SOQL fraîche pour contourner le cache LWC :
        // la remise en brouillon n'a de sens que pour une facture déjà sortie
        // du statut « Brouillon ».
        List<Facture__c> facturesEtat = [
            SELECT Id, Statut__c FROM Facture__c WHERE Id = :factureId LIMIT 1
        ];
        if (facturesEtat.isEmpty()) throw new AuraHandledException('Facture introuvable');
        if (facturesEtat[0].Statut__c == Constants.Facture_STATUT_BROUILLON) {
            throw new AuraHandledException(
                'La facture est déjà au statut « Brouillon ». Aucune réinitialisation nécessaire.'
            );
        }

        Facture__c facture = new Facture__c(Id = factureId);

        // Le statut repasse à Brouillon.
        facture.Statut__c = Constants.Facture_STATUT_BROUILLON;
        // Horodatage technique : déclenche le bypass des règles de validation.
        facture.Tech_ControleModification__c = System.now();

        try {
            update facture;
        } catch (DmlException ex) {
            throw new AuraHandledException(
                'Erreur lors de la réinitialisation : ' + ex.getDmlMessage(0)
            );
        }
    }

    /**
     * Reproduit en Apex les règles de validation de Facture__c afin de pouvoir
     * lister les manques avant toute modification du statut.
     */
    private static List<String> collecterErreursValidation(Facture__c f) {
        List<String> erreurs = new List<String>();

        // validation_interdite_si_montant_nul
        if (f.Montant_Total__c == null || f.Montant_Total__c == 0) {
            erreurs.add('Le montant TTC de la facture est obligatoire et doit être supérieur à 0.');
        }

        // montants_ttc_ht_tva_non_negatifs
        if ((f.Montant_Total__c != null && f.Montant_Total__c < 0)
            || (f.MontantHT__c != null && f.MontantHT__c < 0)
            || (f.MontantTVA__c != null && f.MontantTVA__c < 0)) {
            erreurs.add('Les montants TTC / HT / TVA ne peuvent pas être négatifs.');
        }

        

        // coherence_ht_tva_ttc
        if (f.MontantHT__c != null && String.isNotBlank(f.Taux_TVA__c) && f.Montant_Total__c != null) {
            Decimal tolerance = 0.01;
            Decimal attendu = f.MontantHT__c * (1 + Decimal.valueOf(f.Taux_TVA__c) / 100);
            // if (Math.abs(f.Montant_Total__c - attendu) > 0.01) {
            if ((f.Montant_Total__c - attendu).abs() > tolerance) {
                erreurs.add('Incohérence des montants : le TTC (' + f.Montant_Total__c
                    + ' €) ne correspond pas à HT × (1 + Taux TVA). Montant attendu : '
                    + attendu.setScale(2) + ' €.');
            }
        }

        // coherence_montant_tva
        if (f.MontantHT__c != null &&
            String.isNotBlank(f.Taux_TVA__c) &&
            f.MontantTVA__c != null) {

            Decimal tvaAttendue =
                f.MontantHT__c * Decimal.valueOf(f.Taux_TVA__c) / 100;

            if ((f.MontantTVA__c - tvaAttendue).abs() > 0.01) {
                erreurs.add(
                    'Le montant TVA (' + f.MontantTVA__c +
                    ' €) ne correspond pas au taux de TVA sélectionné.'
                );
            }
        }

        // numero_facture_obligatoire_hrs_brouillon
        if (String.isBlank(f.Name) && String.isBlank(f.N_Facture_Externe__c)) {
            erreurs.add('Un N° de facture (interne ou externe) est obligatoire pour valider la facture.');
        }

        // echeance_apres_date_facture
        if (f.DateFacture__c != null && f.DateEcheance__c != null
            && f.DateEcheance__c < f.DateFacture__c) {
            erreurs.add('La date d\'échéance doit être postérieure ou égale à la date de facture.');
        }

        // date_paiement_apres_date_facture
        if (f.DateFacture__c != null && f.Date_Paiement__c != null
            && f.Date_Paiement__c < f.DateFacture__c) {
            erreurs.add('La date de paiement ne peut pas être antérieure à la date de facture.');
        }

        // Cohérence somme des lignes == montant HT facture + total des acomptes
        // (avances) rattachés. Le montant de la facture Classique ne contient
        // pas les acomptes déjà facturés : le total HT des acomptes
        // (Montant_TotalAcompte_Avance_HT__c) s'ajoute donc au HT de la
        // facture pour la comparaison avec les lignes.
        List<LigneFacture__c> lignes = f.Factures_associees__r;
        if (lignes != null && !lignes.isEmpty()) {
            Decimal sommeLignes = 0;
            for (LigneFacture__c l : lignes) {
                if (l.Montant_HT__c != null) sommeLignes += l.Montant_HT__c;
            }
            Decimal totalAcomptes = f.Montant_TotalAcompte_Avance_HT__c == null
                ? 0 : f.Montant_TotalAcompte_Avance_HT__c;
            Decimal totalFacture = (f.MontantHT__c == null ? 0 : f.MontantHT__c) + totalAcomptes;
            if (sommeLignes.setScale(2) != totalFacture.setScale(2)) {
                erreurs.add('Le total des lignes associées (' + sommeLignes.setScale(2)
                    + ' €) ne correspond pas au montant HT de la facture + total des acomptes ('
                    + totalFacture.setScale(2) + ' €).');
            }

            // Cohérence bénéficiaire : l'intervenant (compte) de chaque ligne doit
            // correspondre au bénéficiaire de la facture.
            List<String> lignesNonConformes = new List<String>();
            for (LigneFacture__c l : lignes) {
                if (l.Intervenant_Compte__c != f.Destinataire_Compte__c) {
                    lignesNonConformes.add(l.Name);
                }
            }
            if (!lignesNonConformes.isEmpty()) {
                erreurs.add('Le compte bénéficiaire des lignes suivantes ne correspond pas au '
                    + 'bénéficiaire de la facture : ' + String.join(lignesNonConformes, ', ') + '.');
            }
        }

        return erreurs;
    }
}