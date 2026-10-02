/**
 * Contrôleur du LWC lwc022PaiementFacturesMasse : paiement en masse des
 * factures « Validé » d'un compte bénéficiaire (bouton de la vue liste
 * Facture__c, wrapper Aura PaiementFacturesMasse).
 *
 * Les colonnes du tableau sont pilotées par deux fieldsets :
 *  - FS_FacturesMasse_Champs_LectureSeule : colonnes d'affichage uniquement ;
 *  - FS_FacturesMasse_Champs_Modifiable  : colonnes saisissables, écrites sur
 *    les factures à la confirmation (caractère obligatoire respecté).
 * Ajouter/retirer un champ d'un fieldset suffit à faire évoluer l'écran.
 *
 * Aucune méthode n'est cacheable : la liste doit toujours refléter l'état
 * réel de la base, notamment après confirmation du paiement.
 */
public with sharing class LC022PaiementFacturesMasseController {

    /** Fieldset des colonnes éditables (écrites à la confirmation du paiement). */
    @TestVisible
    private static final String FIELDSET_MODIFIABLE = 'FS_FacturesMasse_Champs_Modifiable';

    /** Fieldset des colonnes affichées en lecture seule. */
    @TestVisible
    private static final String FIELDSET_LECTURE_SEULE = 'FS_FacturesMasse_Champs_LectureSeule';

    /** Statut cible après confirmation du paiement. */
    @TestVisible
    private static final String STATUT_PAYE = 'Payé';

    /** Colonne dynamique issue du fieldset. */
    public class ColonneFieldSet {
        @AuraEnabled public String apiName;
        @AuraEnabled public String label;
        @AuraEnabled public String type;        // Schema.DisplayType (DATE, PICKLIST…)
        @AuraEnabled public Boolean isRequired; // requis dans le fieldset OU en base
    }

    /** Colonnes des deux fieldsets, retournées en un seul aller-retour. */
    public class ColonnesDTO {
        @AuraEnabled public List<ColonneFieldSet> lectureSeule = new List<ColonneFieldSet>();
        @AuraEnabled public List<ColonneFieldSet> modifiables = new List<ColonneFieldSet>();
    }

    @AuraEnabled
    public static ColonnesDTO getColonnes() {
        ColonnesDTO dto = new ColonnesDTO();
        dto.lectureSeule = decrireFieldSet(FIELDSET_LECTURE_SEULE);
        dto.modifiables = decrireFieldSet(FIELDSET_MODIFIABLE);
        return dto;
    }

    @TestVisible
    private static List<ColonneFieldSet> decrireFieldSet(String apiFieldSet) {
        Schema.FieldSet fs = Schema.SObjectType.Facture__c.fieldSets.getMap().get(apiFieldSet);
        if (fs == null) {
            throw new AuraHandledException(
                'Fieldset « ' + apiFieldSet + ' » introuvable sur Facture__c.'
            );
        }
        List<ColonneFieldSet> colonnes = new List<ColonneFieldSet>();
        for (Schema.FieldSetMember m : fs.getFields()) {
            ColonneFieldSet c = new ColonneFieldSet();
            c.apiName = m.getFieldPath();
            c.label = m.getLabel();
            c.type = String.valueOf(m.getType());
            c.isRequired = m.getRequired() || m.getDbRequired();
            colonnes.add(c);
        }
        return colonnes;
    }

    /**
     * Factures payables du compte : statut « Validé » uniquement. Les factures
     * liées à un lettrage sont exclues : leur statut suit celui du lettrage
     * (FactureTriggerHandler bloque tout changement de statut direct).
     *
     * Les champs des deux fieldsets sont inclus dans la requête : affichage des
     * colonnes lecture seule et pré-remplissage des colonnes éditables.
     */
    @AuraEnabled
    public static List<Facture__c> getFacturesValidees(Id compteId) {
        if (compteId == null) return new List<Facture__c>();

        // Champs techniques toujours requis : identité (messages d'erreur,
        // recherche) et total TTC du récapitulatif.
        Set<String> champs = new Set<String>{
            'id', 'name', 'n_facture_externe__c',
            'montant_total__c', 'statut__c', 'destinataire_compte__r.name'
        };
        for (ColonneFieldSet c : decrireFieldSet(FIELDSET_LECTURE_SEULE)) {
            champs.add(c.apiName.toLowerCase());
        }
        for (ColonneFieldSet c : decrireFieldSet(FIELDSET_MODIFIABLE)) {
            champs.add(c.apiName.toLowerCase());
        }

        String statutValide = Constants.Facture_STATUT_VALIDE;
        String soql = 'SELECT ' + String.join(new List<String>(champs), ', ')
            + ' FROM Facture__c'
            + ' WHERE Destinataire_Compte__c = :compteId'
            + ' AND Statut__c = :statutValide'
            + ' AND Lettrage__c = null'
            + ' ORDER BY DateFacture__c NULLS LAST, Name'
            + ' LIMIT 500';
        return Database.query(soql);
    }

    /**
     * Confirme le paiement : passe les factures au statut « Payé » en
     * enregistrant les valeurs saisies pour les champs du fieldset.
     *
     * @param facturesJson JSON [{ "factureId": Id, "champs": { api: valeur } }]
     * @return nombre de factures mises à jour (tout ou rien : la moindre
     *         erreur annule l'ensemble du traitement).
     */
    @AuraEnabled
    public static Integer payerFactures(String facturesJson) {
        if (String.isBlank(facturesJson)) {
            throw new AuraHandledException('Aucune facture transmise.');
        }
        List<Object> lignes;
        try {
            lignes = (List<Object>) JSON.deserializeUntyped(facturesJson);
        } catch (Exception ex) {
            throw new AuraHandledException('Format de données invalide : ' + ex.getMessage());
        }
        if (lignes == null || lignes.isEmpty()) {
            throw new AuraHandledException('Aucune facture transmise.');
        }

        // Seuls les champs du fieldset modifiable sont autorisés en écriture :
        // le client ne peut pas pousser d'autres champs (le statut est posé ici).
        Map<String, ColonneFieldSet> colonnesParApi = new Map<String, ColonneFieldSet>();
        for (ColonneFieldSet c : decrireFieldSet(FIELDSET_MODIFIABLE)) {
            colonnesParApi.put(c.apiName.toLowerCase(), c);
        }

        Map<Id, Map<String, Object>> champsParFacture = new Map<Id, Map<String, Object>>();
        for (Object o : lignes) {
            Map<String, Object> ligne = (Map<String, Object>) o;
            Object idRaw = ligne.get('factureId');
            if (idRaw == null) {
                throw new AuraHandledException('Identifiant de facture manquant dans les données transmises.');
            }
            Map<String, Object> valeurs = new Map<String, Object>();
            if (ligne.get('champs') != null) {
                for (String key : ((Map<String, Object>) ligne.get('champs')).keySet()) {
                    valeurs.put(key.toLowerCase(), ((Map<String, Object>) ligne.get('champs')).get(key));
                }
            }
            champsParFacture.put(Id.valueOf(String.valueOf(idRaw)), valeurs);
        }

        // Relecture fraîche : la liste affichée peut être obsolète. Seules les
        // factures encore « Validé » et non lettrées sont payables.
        Map<Id, Facture__c> existantes = new Map<Id, Facture__c>([
            SELECT Id, Name, Statut__c, Lettrage__c
            FROM Facture__c
            WHERE Id IN :champsParFacture.keySet()
        ]);

        List<String> erreurs = new List<String>();
        for (Id fid : champsParFacture.keySet()) {
            Facture__c f = existantes.get(fid);
            if (f == null) {
                erreurs.add('Facture introuvable (' + fid + ').');
            } else if (f.Statut__c != Constants.Facture_STATUT_VALIDE) {
                erreurs.add('La facture ' + f.Name + ' n\'est plus au statut « Validé » (statut actuel : ' + f.Statut__c + ').');
            } else if (f.Lettrage__c != null) {
                erreurs.add('La facture ' + f.Name + ' est liée à un lettrage : son statut suit celui du lettrage.');
            }
        }
        if (!erreurs.isEmpty()) {
            throw new AuraHandledException(String.join(erreurs, ' '));
        }

        Map<String, Schema.SObjectField> fMap = Facture__c.SObjectType.getDescribe().fields.getMap();
        List<Facture__c> aMettreAJour = new List<Facture__c>();
        List<Id> ordre = new List<Id>(); // relie les erreurs DML aux factures
        for (Id fid : champsParFacture.keySet()) {
            Facture__c f = new Facture__c(Id = fid);
            Map<String, Object> valeurs = champsParFacture.get(fid);

            for (String api : colonnesParApi.keySet()) {
                ColonneFieldSet col = colonnesParApi.get(api);
                if (!fMap.containsKey(api)) continue;
                Object v = valeurs.get(api);
                Boolean estVide = v == null || (v instanceof String && String.isBlank((String) v));

                if (estVide) {
                    if (col.isRequired) {
                        erreurs.add('Le champ « ' + col.label + ' » est obligatoire pour la facture '
                            + existantes.get(fid).Name + '.');
                    } else if (valeurs.containsKey(api)) {
                        f.put(col.apiName, null); // blanc envoyé explicitement -> effacement
                    }
                    continue;
                }
                appliquerValeur(f, col.apiName, v, fMap.get(api).getDescribe().getType());
            }

            f.Statut__c = STATUT_PAYE;
            aMettreAJour.add(f);
            ordre.add(fid);
        }
        if (!erreurs.isEmpty()) {
            throw new AuraHandledException(String.join(erreurs, ' '));
        }

        try {
            update aMettreAJour;
        } catch (DmlException ex) {
            List<String> msgs = new List<String>();
            for (Integer i = 0; i < ex.getNumDml(); i++) {
                Facture__c enErreur = existantes.get(ordre[ex.getDmlIndex(i)]);
                String nom = enErreur == null ? String.valueOf(ordre[ex.getDmlIndex(i)]) : enErreur.Name;
                msgs.add('Facture ' + nom + ' : ' + ex.getDmlMessage(i));
            }
            throw new AuraHandledException(String.join(msgs, ' '));
        }
        return aMettreAJour.size();
    }

    /**
     * Pose une valeur JSON sur le champ en la convertissant selon le type du
     * champ (même logique que FacturesController.createFactureAvecLignes ;
     * JSON.deserializeUntyped produit des String / Decimal / Boolean).
     */
    @TestVisible
    private static void appliquerValeur(Facture__c f, String api, Object v, Schema.DisplayType dt) {
        try {
            if (dt == Schema.DisplayType.DATE && v instanceof String) {
                f.put(api, Date.valueOf((String) v));
            } else if (dt == Schema.DisplayType.DATETIME && v instanceof String) {
                f.put(api, DateTime.valueOfGmt(((String) v).replace('T', ' ').replace('Z', '')));
            } else if ((dt == Schema.DisplayType.DOUBLE || dt == Schema.DisplayType.CURRENCY ||
                        dt == Schema.DisplayType.PERCENT) && v instanceof String) {
                f.put(api, Decimal.valueOf((String) v));
            } else if (dt == Schema.DisplayType.INTEGER && v instanceof String) {
                f.put(api, Integer.valueOf((String) v));
            } else if (dt == Schema.DisplayType.INTEGER && v instanceof Decimal) {
                f.put(api, ((Decimal) v).intValue());
            } else if (dt == Schema.DisplayType.BOOLEAN && v instanceof String) {
                f.put(api, Boolean.valueOf((String) v));
            } else {
                f.put(api, v);
            }
        } catch (Exception ex) {
            throw new AuraHandledException('Valeur invalide pour ' + api + ' : ' + ex.getMessage());
        }
    }
}