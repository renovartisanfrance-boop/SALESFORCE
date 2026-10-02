/**
 * Contrôleur de la Facturation V2 (composant lwc paiementFacturationDossierV2).
 *
 * Détecte les prix depuis le Catalogue Tarifaire (CatalogueTarifaire__c) au lieu
 * de l'ancienne grille. Pour chaque intervenant rattaché au dossier (champ lookup
 * renseigné), on cherche la ligne catalogue active correspondante puis on CALCULE
 * les montants en évaluant ParametresFiche__c (règles + formules) contre les
 * champs du dossier. Le calcul est refait à chaque ouverture (jamais lu depuis
 * l'existant). Les montants ne sont écrits sur le dossier qu'au moment de créer
 * la ligne de facture.
 *
 * L'échéance de paiement déclenchant chaque montant est, elle aussi, portée par la
 * règle gagnante (montant1.echeance / montant2.echeance, appariées au montant),
 * avec repli sur les anciens champs fixes EcheancePaiement1__c/2__c pour les lignes
 * non encore migrées.
 *
 * Classe AUTONOME (pattern 022) : elle n'appelle plus PaiementFacturationController.
 * La création de ligne, la validation du compte bénéficiaire, la lecture/MAJ de
 * ligne et le test community sont ré-implémentés ici (repris de l'ancien
 * contrôleur, qui reste inchangé et dédié à l'ancien composant).
 */
public without sharing class LC022FacturationCatalogueController {

    // -------------------------------------------------- Mapping intervenants
    // Repris du composant paiementFacturationDossier (vérité terrain). Les champs
    // com1/com2 sont repérés ici par leur API name (libellés vérifiés : ex.
    // Montant_Calcule__c = « Regie- Com1 »). On ne traite que le sous-traitant PAC.

    private class Cfg {
        String intervenant;   // clé courte (id de ligne UI)
        String role;          // RoleIntervenant / Type_Intervenant (libellé catalogue)
        String com1Api;       // champ dossier où stocker la commission 1
        String com2Api;       // champ dossier où stocker la commission 2
        String lookupApi;     // champ lookup du dossier identifiant l'intervenant
        Cfg(String i, String r, String c1, String c2, String l) {
            intervenant = i; role = r; com1Api = c1; com2Api = c2; lookupApi = l;
        }
    }

    private static List<Cfg> buildConfig() {
        return new List<Cfg>{
            new Cfg('Apporteur',     'Apporteur d\'Affaire',  'Com1_App__c',        'Com2_App__c',          'LOOKUP_Apporteur_d_affaires__c'),
            new Cfg('Client',        'Client',                'Com1_Cli__c',        'Com2_Cli__c',          'Compte__c'),
            new Cfg('Closer',        'Closer',                'Com1_Clo__c',        'Com2_Clo__c',          'LOOKUP_Closer__c'),
            new Cfg('Cofrac',        'Cofrac',                'Com1_Cofr__c',       'Com2_Cofr__c',         'LOOKUP_Cofrac__c'),
            new Cfg('Commerciaux',   'Commerciaux',           'Com1_Comm__c',       'Com2_Comm__c',         'Commercial__c'),
            new Cfg('Confirmateur',  'Confirmateur',          'Com1_Conf__c',       'Com2_Conf__c',         'Confirmateurs__c'),
            new Cfg('Previsiteur',   'Pre-visiteur',          'Com1_Prev__c',       'Com2_Prev__c',         'LOOKUP_Pre_visiteur__c'),
            new Cfg('Regie',         'Régie',                 'Montant_Calcule__c', 'Montant_Calcule_2__c', 'CampagneRegie_PRINCIPALE__c'),
            new Cfg('RespAdmin',     'Responsable Admin',     'Com1_RAdm__c',       'Com2_RAdm__c',         'LOOKUP_Responsable_Admin__c'),
            new Cfg('RespPrevisite', 'Responsable Previsite', 'Com1_RPrev__c',      'Com2_RPrev__c',        'LOOKUP_Responsable_Previsite__c'),
            new Cfg('RespProd',      'Responsable Prod',      'Com1_RProd__c',      'Com2_RProd__c',        'LOOKUP_Responsable_Prod__c'),
            new Cfg('Secretaire',    'Secrétaire',            'Com1_Sec__c',        'Com2_Sec__c',          'LOOKUP_Secretaire__c'),
            new Cfg('Secretaire2',   'Secretaire 2',          'Com1_Sec2__c',       'Com2_Sec2__c',         'LOOKUP_Secretaire_2__c'),
            new Cfg('SousTraitant',  'Sous-traitant',         'Com1_ST__c',         'Com2_ST__c',           'LOOKUP_Sous_Traitant_PAC__c'),
            new Cfg('Telepro',       'Telepro',               'Com1_Tele__c',       'Com2_Tele__c',         'LOOKUP_Telepro__c'),
            new Cfg('Auditeur',      'Auditeur',              'Com1_Aud__c',        'Com2_Aud__c',          'LOOKUP_Auditeur__c')
        };
    }

    private static Cfg cfgByRole(String role) {
        for (Cfg c : buildConfig()) if (c.role == role) return c;
        return null;
    }

    // Champs de statut du dossier servant à évaluer les échéances.
    private static final Set<String> STATUT_FIELDS = new Set<String>{
        'Pr_visite_Statut__c', 'Devis_Statut__c', 'INSTALLATIONN_PAC__c',
        'PAC_Statut_CEE__c', 'PAC_Statut_MPR__c', 'RENO_Statut_Audit__c', 'A_La_charge_de_l_apporteur_d_affaire__c'
    };

    // ----------------------------------------------------------- DTO retour

    public class FacturationV2Result {
        @AuraEnabled public Id dossierId;
        @AuraEnabled public String dossierName;
        @AuraEnabled public String ficheCee;
        @AuraEnabled public List<IntervenantRow> rows;
        public FacturationV2Result() { rows = new List<IntervenantRow>(); }
    }

    public class IntervenantRow {
        @AuraEnabled public String intervenant;    // clé courte (id UI)
        @AuraEnabled public String role;           // libellé / Type_Intervenant
        @AuraEnabled public String champLookup;
        @AuraEnabled public Boolean catalogueFound = false;
        @AuraEnabled public Id catalogueId;
        @AuraEnabled public Boolean ruleMatched = false;
        @AuraEnabled public Decimal com1;
        @AuraEnabled public Decimal com2;
        @AuraEnabled public Boolean montantEditable = false; // admin OU ligne « montants modifiables »
        @AuraEnabled public String echeance1;
        @AuraEnabled public String echeance2;
        @AuraEnabled public Boolean ech1Reached = false;
        @AuraEnabled public Boolean ech2Reached = false;
        @AuraEnabled public Id ligne1Id;
        @AuraEnabled public String ligne1Statut;
        @AuraEnabled public Id ligne2Id;
        @AuraEnabled public String ligne2Statut;
        @AuraEnabled public String message;
        @AuraEnabled public String commentaire; // note de la règle correspondante
    }

    // ----------------------------------------------------- Point d'entrée LWC

    @AuraEnabled
    public static FacturationV2Result getDossierFacturationV2(Id dossierId) {
        if (dossierId == null) throw new AuraHandledException('Dossier requis');

        List<Cfg> config = buildConfig();
        Map<String, SObjectField> proFields = Pro__c.SObjectType.getDescribe().fields.getMap();

        // 1) Valeurs de base du dossier (fiche, date, lookups, statuts).
        Map<String, Object> dv = new Map<String, Object>();
        Set<String> baseFields = new Set<String>{
            'Id', 'Name', 'Fiche_CEE__c', 'Piste_Date_de_Cr_ation__c', 'Facturer_Client__c'
        };
        baseFields.addAll(STATUT_FIELDS);
        for (Cfg c : config) baseFields.add(c.lookupApi);
        loadDossierValues(dossierId, baseFields, proFields, dv);

        FacturationV2Result res = new FacturationV2Result();
        res.dossierId = dossierId;
        res.dossierName = str(dv.get('Name'));
        res.ficheCee = str(dv.get('Fiche_CEE__c'));

        // 2) Intervenants présents (lookup renseigné) -> rôles recherchés.
        List<Cfg> filled = new List<Cfg>();
        Set<String> roles = new Set<String>();
        Boolean facturerClient = 'OUI'.equalsIgnoreCase(str(dv.get('Facturer_Client__c')));
        for (Cfg c : config) {
            if (dv.get(c.lookupApi) != null) {
                // Le rôle « Client » n'est facturable que si Facturer_Client__c = OUI.
                if (c.role == 'Client' && !facturerClient) continue;
                filled.add(c);
                roles.add(c.role);
            }
        }
        if (filled.isEmpty()) return res;

        // 3) Lignes catalogue actives pour la fiche + ces rôles (filtre date en Apex).
        String fiche = res.ficheCee;
        Datetime ref = toDatetime(dv.get('Piste_Date_de_Cr_ation__c'));
        Map<String, List<CatalogueTarifaire__c>> linesByRole = new Map<String, List<CatalogueTarifaire__c>>();
        if (String.isNotBlank(fiche) && !roles.isEmpty()) {
            for (CatalogueTarifaire__c l : [
                SELECT Id, RoleIntervenant__c, Intervenants__c, MontantBase1__c, MontantBase2__c,
                       EcheancePaiement1__c, EcheancePaiement2__c, ParametresFiche__c,
                       Montants_modifiables__c, DateDebutValidite__c, DateFinValidite__c, Paiement__c
                FROM CatalogueTarifaire__c
                WHERE FicheCEE__c = :fiche
                  AND Statut__c = 'Active'
                  AND RecordType.DeveloperName = 'Standard'
                  AND Paiement__c = 'Emis'
                  AND RoleIntervenant__c IN :roles
            ]) {
                if (!dateInRange(ref, l.DateDebutValidite__c, l.DateFinValidite__c)) continue;
                if (!linesByRole.containsKey(l.RoleIntervenant__c)) {
                    linesByRole.put(l.RoleIntervenant__c, new List<CatalogueTarifaire__c>());
                }
                linesByRole.get(l.RoleIntervenant__c).add(l);
            }
        }

        // 4) Champs supplémentaires référencés par les JSON -> 2e requête dossier.
        Map<Id, Map<String, Object>> parsedByLine = new Map<Id, Map<String, Object>>();
        Set<String> extraFields = new Set<String>();
        for (List<CatalogueTarifaire__c> lst : linesByRole.values()) {
            for (CatalogueTarifaire__c l : lst) {
                Map<String, Object> parsed = parseParametres(l.ParametresFiche__c);
                parsedByLine.put(l.Id, parsed);
                collectFields(parsed, extraFields);
            }
        }
        if (!extraFields.isEmpty()) {
            loadDossierValues(dossierId, extraFields, proFields, dv);
        }
        Map<String, Decimal> numericValues = toNumericMap(dv);

        // 5) Lignes de facture déjà créées (par rôle + numéro d'échéance).
        Map<String, LigneFacture__c> ligneByKey = new Map<String, LigneFacture__c>();
        for (LigneFacture__c lf : [
            SELECT Id, Type_Intervenant__c, Numero_Echeance__c, Statut__c, Facture__c, Facture_Statut__c
            FROM LigneFacture__c
            WHERE Dossier__c = :dossierId
        ]) {
            ligneByKey.put(lf.Type_Intervenant__c + '||' + lf.Numero_Echeance__c, lf);
        }

        // 6) Construction des lignes intervenant. L'admin peut toujours modifier le
        // montant ; un non-admin uniquement si la ligne est « montants modifiables ».
        Boolean isAdmin = isAdminUser();
        for (Cfg c : filled) {
            IntervenantRow row = new IntervenantRow();
            row.intervenant = c.intervenant;
            row.role = c.role;
            row.champLookup = c.lookupApi;

            CatalogueTarifaire__c line = selectLine(linesByRole.get(c.role), dossierId, c.lookupApi, proFields, dv);
            if (line != null) {
                row.catalogueFound = true;
                row.catalogueId = line.Id;
                // Échéances : repli sur les champs fixes ; evaluateLine les remplace
                // par l'échéance de la règle gagnante (montant1/2.echeance) quand elle
                // est renseignée (modèle « échéance par règle », appariée au montant).
                row.echeance1 = line.EcheancePaiement1__c;
                row.echeance2 = line.EcheancePaiement2__c;
                // Montant calculé depuis ParametresFiche__c (lignes spécifiques ET
                // génériques utilisent leurs propres règles). La priorité
                // « spécifique d'abord » ne joue que sur la SÉLECTION de la ligne.
                evaluateLine(parsedByLine.get(line.Id), dv, numericValues, row);
                Boolean modif = (Boolean) line.get('Montants_modifiables__c');
                row.montantEditable = isAdmin || (modif == true);
                row.ech1Reached = (row.com1 != null && row.com1 > 0) && isEcheanceReached(row.echeance1, dv);
                row.ech2Reached = (row.com2 != null && row.com2 > 0) && isEcheanceReached(row.echeance2, dv);
            }

            LigneFacture__c l1 = ligneByKey.get(c.role + '||1');
            LigneFacture__c l2 = ligneByKey.get(c.role + '||2');
            if (l1 != null) { row.ligne1Id = l1.Id; row.ligne1Statut = ligneStatutAffiche(l1); }
            if (l2 != null) { row.ligne2Id = l2.Id; row.ligne2Statut = ligneStatutAffiche(l2); }

            res.rows.add(row);
        }
        return res;
    }

    /**
     * Statut à afficher pour une ligne de facture : si elle est liée à une facture,
     * on montre le statut de cette facture (Facture_Statut__c) ; sinon le statut de
     * la ligne (défaut « Créée »).
     */
    private static String ligneStatutAffiche(LigneFacture__c lf) {
        if (lf.Facture__c != null && String.isNotBlank(lf.Facture_Statut__c)) return lf.Facture_Statut__c;
        return String.isBlank(lf.Statut__c) ? 'Créée' : lf.Statut__c;
    }

    /**
     * Crée une ligne de facture pour une échéance (1 ou 2). Le montant est
     * RECALCULÉ côté serveur depuis le catalogue (jamais reçu du client).
     * Validation du compte bénéficiaire + snapshot du contexte gérés en interne
     * (cette classe est autonome, elle ne dépend plus de PaiementFacturationController).
     * Le montant calculé est ensuite stocké sur le dossier.
     */
    @AuraEnabled
    public static Id creerLigneFactureCatalogue(
        Id dossierId,
        String typeIntervenant,
        Integer numEcheance,
        String echeanceDeclenchante,
        Id intervenantCompteId,
        String champLookupApi,
        Decimal montantSaisi
    ) {
        if (dossierId == null) throw new AuraHandledException('Dossier requis');
        if (String.isBlank(typeIntervenant)) throw new AuraHandledException('Intervenant requis');
        if (numEcheance != 1 && numEcheance != 2) throw new AuraHandledException('Numéro d\'échéance invalide');

        FacturationV2Result res = getDossierFacturationV2(dossierId);
        IntervenantRow row = null;
        for (IntervenantRow r : res.rows) {
            if (r.role == typeIntervenant) { row = r; break; }
        }
        if (row == null) throw new AuraHandledException('Intervenant « ' + typeIntervenant + ' » introuvable sur ce dossier.');
        if (!row.catalogueFound) throw new AuraHandledException('Aucune ligne catalogue active pour « ' + typeIntervenant + ' ».');
        if (!row.ruleMatched) throw new AuraHandledException('Dossier non couvert dans le catalogue pour « ' + typeIntervenant + ' ».');

        // L'échéance déclenchante fait foi côté serveur (per-règle, recalculée
        // depuis le catalogue) : on ignore une éventuelle valeur obsolète du client.
        String echeanceServeur = (numEcheance == 1) ? row.echeance1 : row.echeance2;
        if (String.isNotBlank(echeanceServeur)) echeanceDeclenchante = echeanceServeur;

        Decimal montant = (numEcheance == 1) ? row.com1 : row.com2;
        // Prix modifiable (admin ou ligne « montants modifiables ») : on accepte la
        // valeur saisie côté client ; sinon le montant recalculé fait foi (sécurité).
        if (row.montantEditable && montantSaisi != null && montantSaisi > 0) {
            montant = montantSaisi;
        }
        if (montant == null || montant <= 0) {
            throw new AuraHandledException('Aucun montant à facturer pour l\'échéance ' + numEcheance + '.');
        }
        Boolean reached = (numEcheance == 1) ? row.ech1Reached : row.ech2Reached;
        if (!reached) {
            throw new AuraHandledException(
                String.isBlank(echeanceDeclenchante)
                    ? 'Aucune échéance de paiement n\'est configurée pour ce montant.'
                    : 'L\'échéance « ' + echeanceDeclenchante + ' » n\'est pas encore atteinte.'
            );
        }

        // La commission 2 ne peut pas être créée avant la commission 1 (quand
        // une commission 1 existe au catalogue et n'a pas encore de ligne).
        if (numEcheance == 2 && row.com1 != null && row.com1 > 0 && row.ligne1Id == null) {
            throw new AuraHandledException('La commission 1 doit être créée avant la commission 2.');
        }

        // Création interne (validation compte + snapshot + trace catalogue).
        Id ligneId = createLigneFactureInterne(
            dossierId, typeIntervenant, montant, numEcheance, echeanceDeclenchante,
            intervenantCompteId, champLookupApi, row.catalogueId
        );

        // Stockage du montant calculé sur le dossier (historique), à la création.
        writeComToDossier(dossierId, typeIntervenant, numEcheance, montant);
        return ligneId;
    }

    // ------------------------------------ Ligne de facture (autonome, ex-PFC)

    /**
     * Crée la ligne de facture : validation du compte bénéficiaire, contrôle de
     * doublon (dossier + intervenant + échéance), snapshot du contexte du dossier
     * et trace de la ligne catalogue source. Repris de l'ancien
     * PaiementFacturationController.createLigneFacture (sans la résolution de
     * l'ancienne grille, remplacée par le lookup Catalogue_tarifaire__c).
     */
    private static Id createLigneFactureInterne(
        Id dossierId, String typeIntervenant, Decimal montant, Integer numEcheance,
        String echeanceDeclenchante, Id intervenantCompteId, String champLookupApi, Id catalogueId
    ) {
        if (montant == null || montant <= 0) throw new AuraHandledException('Montant invalide');

        // Le compte bénéficiaire saisi doit correspondre à l'intervenant du dossier.
        validateIntervenantCompte(dossierId, champLookupApi, intervenantCompteId, typeIntervenant);

        Pro__c dossier = [
            SELECT Id, Fiche_CEE__c, DR_Zone__c, MPR_SHAB__c,
                   MPR_PRECARITE__c, CodePostal__c, Piste_Date_de_Cr_ation__c
            FROM Pro__c WHERE Id = :dossierId LIMIT 1
        ];

        String numEchStr = String.valueOf(numEcheance);
        List<LigneFacture__c> existing = [
            SELECT Id FROM LigneFacture__c
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
        if (String.isNotBlank(echeanceDeclenchante)) lf.Echeance_Declenchante__c = echeanceDeclenchante;
        if (intervenantCompteId != null) lf.Intervenant_Compte__c = intervenantCompteId;

        // Snapshot du contexte de sélection du prix (figé).
        lf.Fiche_CEE__c = dossier.Fiche_CEE__c;
        lf.Zone_Climatique__c = dossier.DR_Zone__c;
        lf.Surface_SHAB__c = dossier.MPR_SHAB__c;
        lf.Niveau_Precarite__c = dossier.MPR_PRECARITE__c;
        lf.Code_Postal__c = dossier.CodePostal__c;
        lf.Date_Reference_Tarif__c = dossier.Piste_Date_de_Cr_ation__c;

        // Trace de la ligne catalogue source (si le champ existe dans l'org).
        if (catalogueId != null &&
            LigneFacture__c.SObjectType.getDescribe().fields.getMap().containsKey('catalogue_tarifaire__c')) {
            lf.put('Catalogue_tarifaire__c', catalogueId);
        }

        insert lf;
        return lf.Id;
    }

    /**
     * Lecture d'une ligne de facture (pour pré-remplir le formulaire d'édition).
     * Reprise de PaiementFacturationController.getLigneFacture.
     */
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

    /**
     * Mise à jour dynamique d'une ligne de facture (champs éditables).
     * Reprise de PaiementFacturationController.updateLigneFacture.
     */
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

    /**
     * Rejoue la vérification du compte bénéficiaire (ex. lors d'une édition).
     * Reprise de PaiementFacturationController.verifierIntervenantCompte.
     */
    @AuraEnabled
    public static void verifierIntervenantCompte(
        Id dossierId, String champLookupApi, Id intervenantCompteId, String typeIntervenant
    ) {
        validateIntervenantCompte(dossierId, champLookupApi, intervenantCompteId, typeIntervenant);
    }

    /** Utilisateur de portail/communauté ? Reprise de PaiementFacturationController. */
    @AuraEnabled(cacheable=true)
    public static Boolean isCommunityUser() {
        return UserInfo.getUserType() != 'Standard';
    }

    /**
     * Utilisateur « admin » : dispose de la permission « Modifier toutes les données »
     * (via son profil ou un ensemble d'autorisations). Un admin peut toujours modifier
     * le prix à la facturation, indépendamment de Montants_modifiables__c.
     */
    private static Boolean isAdminUser() {
        return ![
            SELECT Id
            FROM PermissionSetAssignment
            WHERE AssigneeId = :UserInfo.getUserId()
              AND PermissionSet.PermissionsModifyAllData = true
            LIMIT 1
        ].isEmpty();
    }

    /**
     * Vérifie que le compte bénéficiaire saisi correspond à l'intervenant
     * rattaché au dossier via son champ lookup (Account direct / User->Contact->
     * Compte / Campagne->Compte_Regie). Reprise de
     * PaiementFacturationController.validateIntervenantCompte.
     */
    private static void validateIntervenantCompte(
        Id dossierId, String champLookupApi, Id intervenantCompteId, String typeIntervenant
    ) {
        if (String.isBlank(champLookupApi)) return;

        Map<String, SObjectField> fMap = Pro__c.SObjectType.getDescribe().fields.getMap();
        SObjectField fld = fMap.get(champLookupApi.toLowerCase());
        if (fld == null) return;

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
            String rel = champLookupApi.replace('__c', '__r');
            SObject rec = Database.query(
                'SELECT ' + champLookupApi + ', ' + rel + '.Contact.AccountId ' +
                'FROM Pro__c WHERE Id = :dossierId LIMIT 1'
            );
            lookupRenseigne = rec.get(champLookupApi) != null;
            SObject userRec = rec.getSObject(rel);
            if (userRec != null) {
                SObject contactRec = userRec.getSObject('Contact');
                if (contactRec != null) dossierCompteId = (Id) contactRec.get('AccountId');
            }
        } else if (refObj == 'Campaign') {
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
            return;
        }

        if (!lookupRenseigne) {
            throw new AuraHandledException(
                'L\'intervenant « ' + typeIntervenant + ' » n\'est pas renseigné au niveau du dossier. ' +
                'Veuillez faire attention au moment du choix du compte bénéficiaire.'
            );
        }

        if (intervenantCompteId == null || dossierCompteId == null || intervenantCompteId != dossierCompteId) {
            throw new AuraHandledException(
                'Le compte bénéficiaire sélectionné ne correspond pas à l\'intervenant « ' +
                typeIntervenant + ' » renseigné sur le dossier.'
            );
        }
    }

    // ----------------------------------------------------------- Sélection ligne

    /**
     * Choisit la ligne catalogue applicable parmi les candidates (déjà filtrées
     * fiche + statut + date + rôle). Priorité à une ligne « spécifique » qui cible
     * un ou plusieurs comptes via Intervenants__c (IDs concaténés) DONT l'ensemble
     * contient le compte du dossier ; sinon ligne générique (aucun compte). Si seules
     * des lignes spécifiques existent et qu'aucune ne correspond -> aucune applicable.
     */
    private static CatalogueTarifaire__c selectLine(
        List<CatalogueTarifaire__c> candidates, Id dossierId, String lookupApi,
        Map<String, SObjectField> proFields, Map<String, Object> dv
    ) {
        if (candidates == null || candidates.isEmpty()) return null;
        List<CatalogueTarifaire__c> generics = new List<CatalogueTarifaire__c>();
        List<CatalogueTarifaire__c> specifics = new List<CatalogueTarifaire__c>();
        for (CatalogueTarifaire__c l : candidates) {
            if (comptesDeLigne(l).isEmpty()) generics.add(l); else specifics.add(l);
        }
        if (!specifics.isEmpty()) {
            Id compte = resolveDossierCompte((Id) dv.get(lookupApi), lookupApi, proFields);
            if (compte != null) {
                String compteStr = String.valueOf(compte);
                for (CatalogueTarifaire__c l : specifics) {
                    if (comptesDeLigne(l).contains(compteStr)) return l;
                }
            }
        }
        if (!generics.isEmpty()) return generics[0];
        return null;
    }

    // Ensemble des comptes ciblés par une ligne : IDs concaténés (« ; ») du champ
    // multi Intervenants__c. Vide = ligne générique (tous les dossiers de la fiche).
    private static Set<String> comptesDeLigne(CatalogueTarifaire__c l) {
        Set<String> s = new Set<String>();
        Object multi = (l == null) ? null : l.get('Intervenants__c');
        if (multi != null) {
            for (String part : String.valueOf(multi).split(';')) {
                String t = part.trim();
                if (String.isNotBlank(t)) s.add(t);
            }
        }
        return s;
    }

    /** Résout le compte bénéficiaire du dossier pour un champ lookup donné. */
    private static Id resolveDossierCompte(Id lookupValue, String lookupApi, Map<String, SObjectField> proFields) {
        if (lookupValue == null || String.isBlank(lookupApi)) return null;
        SObjectField fld = proFields.get(lookupApi.toLowerCase());
        if (fld == null) return null;
        List<Schema.SObjectType> refs = fld.getDescribe().getReferenceTo();
        String refObj = refs.isEmpty() ? null : String.valueOf(refs[0]);

        if (refObj == 'Account') {
            return lookupValue;
        }
        if (refObj == 'User') {
            List<User> us = [SELECT Contact.AccountId FROM User WHERE Id = :lookupValue LIMIT 1];
            if (!us.isEmpty() && us[0].Contact != null) return us[0].Contact.AccountId;
            return null;
        }
        if (refObj == 'Campaign') {
            List<Campaign> cs = [SELECT Id, (SELECT Id FROM Compte_Regie__r LIMIT 1) FROM Campaign WHERE Id = :lookupValue LIMIT 1];
            if (!cs.isEmpty()) {
                List<SObject> comptes = cs[0].getSObjects('Compte_Regie__r');
                if (comptes != null && !comptes.isEmpty()) return (Id) comptes[0].get('Id');
            }
            return null;
        }
        return null;
    }

    // ----------------------------------------------------- Évaluation des règles

    private static void evaluateLine(
        Map<String, Object> parsed, Map<String, Object> dv,
        Map<String, Decimal> numericValues, IntervenantRow row
    ) {
        row.ruleMatched = false;
        if (parsed == null) return;

        Map<String, String> typeByField = new Map<String, String>();
        Object dvars = parsed.get('decisionVariables');
        if (dvars instanceof List<Object>) {
            for (Object o : (List<Object>) dvars) {
                if (o instanceof Map<String, Object>) {
                    Map<String, Object> v = (Map<String, Object>) o;
                    typeByField.put(str(v.get('field')), str(v.get('type')));
                }
            }
        }

        Object rulesObj = parsed.get('rules');
        if (!(rulesObj instanceof List<Object>)) return;
        for (Object ro : (List<Object>) rulesObj) {
            if (!(ro instanceof Map<String, Object>)) continue;
            Map<String, Object> rule = (Map<String, Object>) ro;
            Map<String, Object> conditions = (rule.get('conditions') instanceof Map<String, Object>)
                ? (Map<String, Object>) rule.get('conditions')
                : new Map<String, Object>();
            if (ruleMatches(conditions, typeByField, dv)) {
                row.ruleMatched = true;
                row.commentaire = str(rule.get('commentaire'));
                row.com1 = evalMontant(rule.get('montant1'), numericValues, row);
                row.com2 = evalMontant(rule.get('montant2'), numericValues, row);
                // Échéance appariée au montant : portée par la règle (montant1/2
                // .echeance). On ne remplace le repli (champ fixe) que si la règle
                // gagnante porte effectivement une échéance.
                String e1 = montantEcheance(rule.get('montant1'));
                String e2 = montantEcheance(rule.get('montant2'));
                if (e1 != null) row.echeance1 = e1;
                if (e2 != null) row.echeance2 = e2;
                return; // première règle correspondante
            }
        }
    }

    private static Boolean ruleMatches(Map<String, Object> conditions, Map<String, String> typeByField, Map<String, Object> dv) {
        if (conditions == null) return true;
        for (String field : conditions.keySet()) {
            Object condObj = conditions.get(field);
            if (!(condObj instanceof Map<String, Object>)) continue;
            Map<String, Object> cond = (Map<String, Object>) condObj;
            String comparison = str(cond.get('comparison'));
            String type = typeByField.containsKey(field) ? typeByField.get(field) : 'text';
            Object dval = dv.get(field);
            if (comparison == 'interval') {
                if (!matchInterval(type, dval, cond.get('min'), cond.get('max'))) return false;
            } else if (comparison == 'in' || comparison == 'notIn') {
                // « Une parmi » (in) / « Différent de » (notIn) : liste de valeurs.
                // Liste vide/absente = aucune contrainte. Pour notIn, un dossier vide
                // (aucune valeur ne matche) satisfait la règle : « vide = différent ».
                Object rawVals = cond.get('values');
                List<Object> vals = (rawVals instanceof List<Object>) ? (List<Object>) rawVals : null;
                if (vals == null || vals.isEmpty()) continue; // aucune contrainte
                Boolean anyMatch = matchesAnyOf(type, dval, vals);
                if (comparison == 'in' && !anyMatch) return false;
                if (comparison == 'notIn' && anyMatch) return false;
            } else {
                Object cval = cond.get('value');
                if (cval == null) continue; // aucune contrainte
                if (!matchExact(type, dval, cval)) return false;
            }
        }
        return true;
    }

    private static Boolean matchExact(String type, Object dval, Object cval) {
        if (type == 'number') {
            Decimal d = toDecimal(dval);
            Decimal cv = toDecimal(cval);
            return d != null && cv != null && d == cv;
        }
        if (type == 'boolean') {
            return toBoolean(dval) == toBoolean(cval);
        }
        if (type == 'date' || type == 'datetime') {
            Date d = toDate(dval);
            Date cv = toDate(cval);
            return d != null && cv != null && d == cv;
        }
        String ds = str(dval);
        String cs = str(cval);
        return ds != null && ds == cs;
    }

    // Vrai si `dval` correspond (matchExact) à au moins une valeur de `vals`.
    // Support des opérateurs « une parmi » (in) et « différent de » (notIn).
    private static Boolean matchesAnyOf(String type, Object dval, List<Object> vals) {
        if (vals == null) return false;
        for (Object cv : vals) {
            if (cv != null && matchExact(type, dval, cv)) return true;
        }
        return false;
    }

    private static Boolean matchInterval(String type, Object dval, Object minV, Object maxV) {
        if (type == 'date' || type == 'datetime') {
            Date d = toDate(dval);
            if (d == null) return false;
            Date mn = toDate(minV);
            Date mx = toDate(maxV);
            if (mn != null && d < mn) return false;
            if (mx != null && d > mx) return false;
            return true;
        }
        // par défaut : intervalle numérique
        Decimal d = toDecimal(dval);
        if (d == null) return false;
        Decimal mn = toDecimal(minV);
        Decimal mx = toDecimal(maxV);
        if (mn != null && d < mn) return false;
        if (mx != null && d > mx) return false;
        return true;
    }

    // Couverture ciblée des opérateurs ensemblistes (in / notIn) de ruleMatches,
    // en mémoire — indépendante des données de l'org. Appelée uniquement par les tests.
    @TestVisible
    private static void coverSetOperators() {
        Map<String, String> types = new Map<String, String>{ 'p' => 'picklist' };
        Map<String, Object> inCond = new Map<String, Object>{
            'p' => new Map<String, Object>{ 'comparison' => 'in', 'values' => new List<Object>{ 'A', 'B' } }
        };
        ruleMatches(inCond, types, new Map<String, Object>{ 'p' => 'A' }); // in -> matche
        ruleMatches(inCond, types, new Map<String, Object>{ 'p' => 'Z' }); // in -> ne matche pas
        Map<String, Object> notInCond = new Map<String, Object>{
            'p' => new Map<String, Object>{ 'comparison' => 'notIn', 'values' => new List<Object>{ 'Z' } }
        };
        ruleMatches(notInCond, types, new Map<String, Object>{ 'p' => 'Z' }); // notIn -> exclu -> ne matche pas
        ruleMatches(notInCond, types, new Map<String, Object>{ 'p' => 'A' }); // notIn -> matche
        ruleMatches(notInCond, types, new Map<String, Object>()); // notIn + dossier vide -> matche
        Map<String, Object> emptyCond = new Map<String, Object>{
            'p' => new Map<String, Object>{ 'comparison' => 'in', 'values' => new List<Object>() }
        };
        ruleMatches(emptyCond, types, new Map<String, Object>{ 'p' => 'A' }); // liste vide -> aucune contrainte
    }

    private static Decimal evalMontant(Object montantObj, Map<String, Decimal> numericValues, IntervenantRow row) {
        if (!(montantObj instanceof Map<String, Object>)) return null;
        Map<String, Object> m = (Map<String, Object>) montantObj;
        String mode = str(m.get('mode'));
        if (mode == 'formula') {
            String expr = str(m.get('expression'));
            if (String.isBlank(expr)) return null;
            try {
                return LC022FormulaEvaluator.evaluate(expr, numericValues);
            } catch (Exception e) {
                row.message = 'Formule invalide : ' + e.getMessage();
                return null;
            }
        }
        return toDecimal(m.get('value')); // fixed
    }

    // Échéance de paiement portée par le montant d'une règle (null si absente, vide
    // ou non-string). On exige une String pour ne pas coercer une donnée aberrante
    // (nombre/booléen) en libellé d'échéance.
    private static String montantEcheance(Object montantObj) {
        if (!(montantObj instanceof Map<String, Object>)) return null;
        Object e = ((Map<String, Object>) montantObj).get('echeance');
        if (!(e instanceof String)) return null;
        String s = (String) e;
        return String.isBlank(s) ? null : s;
    }

    // --------------------------------------------------------------- Échéances
    // TODO :> isEcheanceReached
    private static Boolean isEcheanceReached(String label, Map<String, Object> dv) {
        if (String.isBlank(label)) return false;
        String previsite = str(dv.get('Pr_visite_Statut__c'));
        String aNotreCharge = str(dv.get('A_La_charge_de_l_apporteur_d_affaire__c'));
        String devis = str(dv.get('Devis_Statut__c'));
        String install = str(dv.get('INSTALLATIONN_PAC__c'));
        String cee = str(dv.get('PAC_Statut_CEE__c'));
        String mpr = str(dv.get('PAC_Statut_MPR__c'));
        String audit = str(dv.get('RENO_Statut_Audit__c'));

        if (label == 'A la Visite/Previsite') return previsite == '🟩Passage Effectué' /*&& aNotreCharge == '🟩A Notre charge'*/;
        if (label == 'Au Devis Signé') return devis == '🟩Signé';
        if (label == 'A L\'installation') return install == '🟩Installation Cloturée';
        if (label == 'À l\'audit effectué') return audit == '🟩Audit- Validé';
        if (label == 'Au Dossier Déposé') {
            return new Set<String>{
                'Déposé', '🟪Déposé- Controle COFRAC', '🟪Déposé- Anomalie',
                '🟩Validation Délégataire', 'Payé'
            }.contains(cee);
        }
        if (label == 'Au Solde CEE') {
            return new Set<String>{ 'Payé', '🟩Validation Délégataire' }.contains(cee);
        }
        if (label == 'Au Solde MPR') {
            // return new Set<String>{ '🟩Payé- Virement Reçu', '🟩Payé- Virement Reçu', '🟩Solde Demandé' }.contains(mpr);
            return new Set<String>{ '🟩Payé- Virement Reçu' }.contains(mpr);
        }
        return false;
    }

    // -------------------------------------------------------------- Persistance

    private static void writeComToDossier(Id dossierId, String role, Integer numEch, Decimal montant) {
        Cfg c = cfgByRole(role);
        if (c == null) return;
        String api = (numEch == 1) ? c.com1Api : c.com2Api;
        Map<String, SObjectField> f = Pro__c.SObjectType.getDescribe().fields.getMap();
        if (String.isBlank(api) || !f.containsKey(api.toLowerCase())) return;
        SObject d = new Pro__c(Id = dossierId);
        d.put(api, montant);
        update d;
    }

    // ------------------------------------------------------------------- Outils

    private static void loadDossierValues(Id dossierId, Set<String> apis, Map<String, SObjectField> proFields, Map<String, Object> target) {
        List<String> sel = new List<String>();
        Set<String> seen = new Set<String>();
        for (String a : apis) {
            if (String.isBlank(a)) continue;
            String low = a.toLowerCase();
            if (seen.contains(low) || target.containsKey(a)) continue;
            if (proFields.containsKey(low)) { sel.add(a); seen.add(low); }
        }
        if (sel.isEmpty()) return;
        String soql = 'SELECT ' + String.join(sel, ', ') + ' FROM Pro__c WHERE Id = :dossierId LIMIT 1';
        for (SObject rec : Database.query(soql)) {
            for (String a : sel) target.put(a, rec.get(a));
        }
    }

    private static Map<String, Object> parseParametres(String raw) {
        if (String.isBlank(raw)) return null;
        try {
            Object o = JSON.deserializeUntyped(raw);
            return (o instanceof Map<String, Object>) ? (Map<String, Object>) o : null;
        } catch (Exception e) {
            return null;
        }
    }

    private static void collectFields(Map<String, Object> parsed, Set<String> out) {
        if (parsed == null) return;
        Object dvars = parsed.get('decisionVariables');
        if (dvars instanceof List<Object>) {
            for (Object o : (List<Object>) dvars) {
                if (o instanceof Map<String, Object>) {
                    String f = str(((Map<String, Object>) o).get('field'));
                    if (f != null) out.add(f);
                }
            }
        }
        Object rules = parsed.get('rules');
        if (rules instanceof List<Object>) {
            for (Object ro : (List<Object>) rules) {
                if (!(ro instanceof Map<String, Object>)) continue;
                Map<String, Object> rule = (Map<String, Object>) ro;
                if (rule.get('conditions') instanceof Map<String, Object>) {
                    out.addAll(((Map<String, Object>) rule.get('conditions')).keySet());
                }
                for (String mk : new List<String>{ 'montant1', 'montant2' }) {
                    if (rule.get(mk) instanceof Map<String, Object>) {
                        Map<String, Object> m = (Map<String, Object>) rule.get(mk);
                        if (str(m.get('mode')) == 'formula') {
                            Object fl = m.get('fields');
                            if (fl instanceof List<Object>) {
                                for (Object fo : (List<Object>) fl) {
                                    if (fo != null) out.add(String.valueOf(fo));
                                }
                            }
                            out.addAll(extractExprFields(str(m.get('expression'))));
                        }
                    }
                }
            }
        }
    }

    private static Set<String> extractExprFields(String expression) {
        Set<String> out = new Set<String>();
        if (String.isBlank(expression)) return out;
        Matcher mt = Pattern.compile('\\{([^}]+)\\}').matcher(expression);
        while (mt.find()) {
            String f = mt.group(1).trim();
            if (String.isNotBlank(f)) out.add(f);
        }
        return out;
    }

    private static Map<String, Decimal> toNumericMap(Map<String, Object> dv) {
        Map<String, Decimal> out = new Map<String, Decimal>();
        for (String k : dv.keySet()) {
            Decimal d = toDecimal(dv.get(k));
            if (d != null) out.put(k, d);
        }
        return out;
    }

    private static Boolean dateInRange(Datetime ref, Datetime debut, Datetime fin) {
        if (ref == null) return false;
        if (debut != null && ref < debut) return false;
        if (fin != null && ref > fin) return false;
        return true;
    }

    private static Datetime toDatetime(Object o) {
        if (o == null) return null;
        if (o instanceof Datetime) return (Datetime) o;
        if (o instanceof Date) return Datetime.newInstance((Date) o, Time.newInstance(0, 0, 0, 0));
        if (o instanceof String) {
            try { return Datetime.valueOf(((String) o).replace('T', ' ').replace('Z', '')); }
            catch (Exception e) {
                try { return Datetime.newInstance(Date.valueOf((String) o), Time.newInstance(0, 0, 0, 0)); }
                catch (Exception e2) { return null; }
            }
        }
        return null;
    }

    private static Decimal toDecimal(Object o) {
        if (o == null) return null;
        if (o instanceof Decimal) return (Decimal) o;
        if (o instanceof Integer) return (Integer) o;
        if (o instanceof Long) return (Long) o;
        if (o instanceof Double) return Decimal.valueOf((Double) o);
        if (o instanceof String) {
            try { return Decimal.valueOf((String) o); } catch (Exception e) { return null; }
        }
        return null;
    }

    private static Date toDate(Object o) {
        if (o == null) return null;
        if (o instanceof Date) return (Date) o;
        if (o instanceof Datetime) return ((Datetime) o).date();
        if (o instanceof String) {
            String s = (String) o;
            try { return Date.valueOf(s.length() > 10 ? s.substring(0, 10) : s); }
            catch (Exception e) { return null; }
        }
        return null;
    }

    private static Boolean toBoolean(Object o) {
        if (o == null) return false;
        if (o instanceof Boolean) return (Boolean) o;
        return 'true'.equalsIgnoreCase(String.valueOf(o));
    }

    private static String str(Object o) {
        return o == null ? null : String.valueOf(o);
    }
}