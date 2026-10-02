/**
 * Contrôleur de la Facturation ÉMISE DEPUIS LE COMPTE (composant lwc024FacturationCompteEmise).
 *
 * Pendant « miroir » de LC023FacturationCompteController, mais pour les factures
 * que NOUS ÉMETTONS (pour recevoir un paiement), au lieu des factures reçues :
 *   - on lit le Catalogue Tarifaire avec Paiement__c = « Reçu » (≠ « Emis » pour LC023) ;
 *   - on ne traite QUE le Record Type « Standard » (pas de Supplémentaire ni d'Acompte) ;
 *   - la facture créée porte TypeFacture__c = « Émise » (≠ « Reçue » par défaut).
 *
 * Le rôle catalogue éligible en « Reçu » est le « Délégataire » (dépendance picklist
 * RoleIntervenant__c contrôlée par Paiement__c), porté sur le dossier par le lookup
 * LOOKUP_Delegataire__c (→ Account). La config liste néanmoins tous les rôles (comme
 * LC023) : le filtre Reçu du catalogue restreint naturellement aux lignes Délégataire.
 *
 * AUTONOME (préfixe 024) : NE MODIFIE PAS et ne dépend pas de LC023/LC022. Réutilise
 * uniquement LC022FormulaEvaluator (évaluateur de formules) et FacturesController
 * (création/regroupement de facture, acomptes disponibles).
 *
 * Sécurité : « without sharing » (vue consolidée par compte) ; le montant facturé est
 * RECALCULÉ côté serveur depuis le catalogue (un montant saisi n'est accepté que si la
 * ligne est « montants modifiables » ou si l'utilisateur est admin).
 */
public without sharing class LC024FacturationCompteController {

    // ============================================================ Mapping rôles
    // Repris de LC023 + ajout du rôle « Délégataire » (facturation émise / Reçu).

    private class Cfg {
        String intervenant;
        String role;          // RoleIntervenant / Type_Intervenant (libellé catalogue)
        String com1Api;
        String com2Api;
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
            new Cfg('Auditeur',      'Auditeur',              'Com1_Aud__c',        'Com2_Aud__c',          'LOOKUP_Auditeur__c'),
            // Nouveau rôle « Reçu » : Délégataire (facturation émise).
            new Cfg('Delegataire',   'Délégataire',           'Com1_Deleg__c',      'Com2_Deleg__c',        'LOOKUP_Delegataire__c')
        };
    }

    // Champs de statut du dossier servant à évaluer les échéances.
    private static final Set<String> STATUT_FIELDS = new Set<String>{
        'Pr_visite_Statut__c', 'Devis_Statut__c', 'INSTALLATIONN_PAC__c',
        'PAC_Statut_CEE__c', 'PAC_Statut_MPR__c', 'RENO_Statut_Audit__c'
    };

    private static final String STATUS_A_CREER = 'A_CREER';
    private static final String STATUS_EXISTANTE = 'EXISTANTE';
    private static final String STATUS_NON_ATTEINTE = 'NON_ATTEINTE';
    private static final String STATUS_INDISPONIBLE = 'INDISPONIBLE';

    // Catalogue : Record Type traité et sens de paiement (factures émises = « Reçu »).
    private static final String RT_STANDARD = 'Standard';
    private static final String PAIEMENT_RECU = 'Reçu';
    // Type de la facture créée par ce flux (≠ « Reçue » par défaut du trigger).
    // ⚠️ Valeur API de la picklist RESTREINTE = « Emise » (sans accent ; le label est « Émise »).
    private static final String TYPE_FACTURE_EMISE = 'Emise';

    // ============================================================== DTO de retour

    public class CompteFacturationResult {
        @AuraEnabled public Id compteId;
        @AuraEnabled public String compteName;
        @AuraEnabled public List<CompteLigneRow> rows;
        public CompteFacturationResult() { rows = new List<CompteLigneRow>(); }
    }

    public class CompteLigneRow implements Comparable {
        @AuraEnabled public String key;             // dossierId||role||num : identité de la ligne
        @AuraEnabled public Id dossierId;
        @AuraEnabled public String dossierName;
        @AuraEnabled public String ficheCee;
        @AuraEnabled public String role;            // Type_Intervenant
        @AuraEnabled public String champLookupApi;
        @AuraEnabled public Integer numEcheance;    // 1 ou 2
        @AuraEnabled public String echeance;        // libellé déclenchant
        @AuraEnabled public Decimal montant;
        @AuraEnabled public Boolean montantEditable = false;
        @AuraEnabled public String status;          // A_CREER | EXISTANTE | NON_ATTEINTE | INDISPONIBLE
        @AuraEnabled public Boolean selectable = false;
        @AuraEnabled public Id catalogueId;
        @AuraEnabled public Id existingLigneId;
        @AuraEnabled public String existingStatut;
        @AuraEnabled public String factureStatut;     // statut de la facture liée (si Brouillon)
        @AuraEnabled public String factureNumExterne;
        @AuraEnabled public String commentaire;        // note de la règle gagnante
        @AuraEnabled public String message;

        public Integer compareTo(Object o) {
            CompteLigneRow other = (CompteLigneRow) o;
            Integer c = safe(dossierName).compareTo(safe(other.dossierName));
            if (c != 0) return c;
            c = safe(role).compareTo(safe(other.role));
            if (c != 0) return c;
            Integer n1 = numEcheance == null ? 0 : numEcheance;
            Integer n2 = other.numEcheance == null ? 0 : other.numEcheance;
            return n1 - n2;
        }
        private String safe(String s) { return s == null ? '' : s; }
    }

    // Holder interne d'évaluation des deux échéances d'une ligne catalogue.
    private class LineEval {
        Decimal com1;
        Decimal com2;
        String echeance1;
        String echeance2;
        Boolean ruleMatched = false;
        String commentaire;
        String message;
    }

    // Ligne à créer (accumulée pour insertion en masse).
    private class PendingLine {
        Id dossierId;
        String role;
        Integer num;
        String echeance;
        Decimal montant;
        Id catalogueId;
    }

    // ===================================================== Point d'entrée — lecture

    /**
     * Toutes les lignes facturables (à créer) + réutilisables (déjà créées, non
     * liées ou sur une facture Brouillon) pour un compte donné, tous dossiers
     * confondus. Catalogue « Standard » + Paiement « Reçu » uniquement.
     */
    @AuraEnabled
    public static CompteFacturationResult getCompteFacturation(Id compteId) {
        if (compteId == null) throw new AuraHandledException('Compte requis');

        CompteFacturationResult res = new CompteFacturationResult();
        res.compteId = compteId;
        List<Account> comptes = [SELECT Id, Name FROM Account WHERE Id = :compteId LIMIT 1];
        res.compteName = comptes.isEmpty() ? null : comptes[0].Name;

        List<Cfg> config = buildConfig();
        Map<String, SObjectField> proFields = Pro__c.SObjectType.getDescribe().fields.getMap();

        Map<String, String> targetByLookup = new Map<String, String>();
        for (Cfg c : config) {
            if (proFields.containsKey(c.lookupApi.toLowerCase())) {
                targetByLookup.put(c.lookupApi, roleTarget(c.lookupApi, proFields));
            }
        }

        Map<String, String> ficheLabels = new Map<String, String>();
        for (Schema.PicklistEntry pe : Pro__c.Fiche_CEE__c.getDescribe().getPicklistValues()) {
            ficheLabels.put(pe.getValue(), pe.getLabel());
        }

        dbg('========== getCompteFacturation (émise) ==========');
        dbg('Compte : ' + compteId + ' (' + res.compteName + ')');

        // 1) Résolution inverse : Users et Campagnes rattachés à ce compte.
        Set<Id> userIds = usersForCompte(compteId);
        Set<Id> campaignIds = campaignsForCompte(compteId);

        // 2) Dossiers candidats : ceux où le compte joue au moins un rôle.
        List<String> ors = new List<String>();
        for (Cfg c : config) {
            if (!proFields.containsKey(c.lookupApi.toLowerCase())) continue;
            String t = targetByLookup.get(c.lookupApi);
            if (t == 'Account') ors.add(c.lookupApi + ' = :compteId');
            else if (t == 'User' && !userIds.isEmpty()) ors.add(c.lookupApi + ' IN :userIds');
            else if (t == 'Campaign' && !campaignIds.isEmpty()) ors.add(c.lookupApi + ' IN :campaignIds');
        }

        Map<Id, Map<String, Object>> dvByDossier = new Map<Id, Map<String, Object>>();
        Map<Id, List<Cfg>> matchedByDossier = new Map<Id, List<Cfg>>();
        Set<String> fiches = new Set<String>();
        Set<String> rolesSet = new Set<String>();

        if (!ors.isEmpty()) {
            Set<String> selFields = new Set<String>{
                'Id', 'Name', 'Fiche_CEE__c', 'Piste_Date_de_Cr_ation__c', 'Facturer_Client__c'
            };
            selFields.addAll(STATUT_FIELDS);
            for (Cfg c : config) {
                if (proFields.containsKey(c.lookupApi.toLowerCase())) selFields.add(c.lookupApi);
            }
            List<String> sel = validSelect(selFields, proFields);
            String soql = 'SELECT ' + String.join(sel, ', ') +
                          ' FROM Pro__c WHERE (' + String.join(ors, ' OR ') + ')';
            for (SObject rec : Database.query(soql)) {
                Id did = (Id) rec.get('Id');
                Map<String, Object> dv = new Map<String, Object>();
                for (String a : sel) dv.put(a, rec.get(a));
                dvByDossier.put(did, dv);

                List<Cfg> matched = new List<Cfg>();
                for (Cfg c : config) {
                    Object v = dv.get(c.lookupApi);
                    if (v == null) continue;
                    String t = targetByLookup.get(c.lookupApi);
                    Boolean ok = (t == 'Account' && (Id) v == compteId)
                              || (t == 'User' && userIds.contains((Id) v))
                              || (t == 'Campaign' && campaignIds.contains((Id) v));
                    if (!ok) continue;
                    // Le rôle « Client » n'est éligible que si Facturer_Client__c = OUI.
                    if (c.role == 'Client' && !'OUI'.equalsIgnoreCase(str(dv.get('Facturer_Client__c')))) continue;
                    matched.add(c);
                }
                if (!matched.isEmpty()) {
                    matchedByDossier.put(did, matched);
                    String fiche = str(dv.get('Fiche_CEE__c'));
                    if (String.isNotBlank(fiche)) fiches.add(fiche);
                    for (Cfg c : matched) rolesSet.add(c.role);
                }
            }
        }
        dbg('Dossiers candidats : ' + dvByDossier.size() + ' ; avec rôle ciblant le compte : ' +
            matchedByDossier.size() + ' ; fiches=' + fiches + ' ; rôles=' + rolesSet);

        // 3) Lignes catalogue ACTIVE « Standard » + Paiement « Reçu » (fiche||rôle).
        //    Le filtre de date de validité est appliqué PAR dossier.
        Map<String, List<CatalogueTarifaire__c>> linesByKey = new Map<String, List<CatalogueTarifaire__c>>();
        Map<Id, Map<String, Object>> parsedByCat = new Map<Id, Map<String, Object>>();
        Set<String> extraFields = new Set<String>();
        if (!fiches.isEmpty() && !rolesSet.isEmpty()) {
            for (CatalogueTarifaire__c l : [
                SELECT Id, FicheCEE__c, RoleIntervenant__c, Intervenants__c,
                       MontantBase1__c, MontantBase2__c, EcheancePaiement1__c, EcheancePaiement2__c,
                       ParametresFiche__c, Montants_modifiables__c, DateDebutValidite__c, DateFinValidite__c,
                       Paiement__c
                FROM CatalogueTarifaire__c
                WHERE FicheCEE__c IN :fiches
                  AND Statut__c = 'Active'
                  AND RecordType.DeveloperName = :RT_STANDARD
                  AND Paiement__c = :PAIEMENT_RECU
                  AND RoleIntervenant__c IN :rolesSet
            ]) {
                String k = l.FicheCEE__c + '||' + l.RoleIntervenant__c;
                if (!linesByKey.containsKey(k)) linesByKey.put(k, new List<CatalogueTarifaire__c>());
                linesByKey.get(k).add(l);
                Map<String, Object> parsed = parseParametres(l.ParametresFiche__c);
                parsedByCat.put(l.Id, parsed);
                collectFields(parsed, extraFields);
            }
        }
        dbg('Lignes catalogue Reçu/Standard trouvées (fiche||rôle) : ' + linesByKey.keySet());

        // 4) Champs supplémentaires référencés par les règles JSON -> 1 requête.
        if (!extraFields.isEmpty() && !dvByDossier.isEmpty()) {
            loadDossierValuesBulk(dvByDossier.keySet(), extraFields, proFields, dvByDossier);
        }

        // 5) Lignes déjà créées réutilisables (non liées OU sur facture Brouillon).
        Map<String, LigneFacture__c> existingByKey = new Map<String, LigneFacture__c>();
        for (LigneFacture__c lf : existingReusableLines(compteId)) {
            existingByKey.put(lineFactureKey(lf), lf);
        }
        // Lignes DÉJÀ existantes sur les dossiers candidats (tout bénéficiaire / tout
        // statut) : sert à marquer « indisponible » une (dossier,rôle,éch) déjà créée
        // mais NON réutilisable pour ce compte.
        Boolean hasCatField = LigneFacture__c.SObjectType.getDescribe()
            .fields.getMap().containsKey('catalogue_tarifaire__c');
        Map<String, LigneFacture__c> allLinesByKey = new Map<String, LigneFacture__c>();
        Set<Id> candDossierIds = dvByDossier.keySet();
        if (!candDossierIds.isEmpty()) {
            String catSel = hasCatField ? ', Catalogue_tarifaire__c' : '';
            String soql = 'SELECT Id, Dossier__c, Type_Intervenant__c, Numero_Echeance__c, ' +
                          'Echeance_Declenchante__c, Statut__c, Facture__c, Facture_Statut__c' + catSel +
                          ' FROM LigneFacture__c WHERE Dossier__c IN :candDossierIds';
            for (LigneFacture__c lf : Database.query(soql)) {
                allLinesByKey.put(lineFactureKey(lf), lf);
            }
        }

        // 6) Construction des lignes « virtuelles » (à créer / non atteintes).
        Boolean isAdmin = isAdminUser();
        Map<String, CompteLigneRow> virtualByKey = new Map<String, CompteLigneRow>();
        for (Id did : matchedByDossier.keySet()) {
            Map<String, Object> dv = dvByDossier.get(did);
            String fiche = str(dv.get('Fiche_CEE__c'));
            Date ref = toDate(dv.get('Piste_Date_de_Cr_ation__c'));
            Map<String, Decimal> numericValues = toNumericMap(dv);

            for (Cfg c : matchedByDossier.get(did)) {
                List<CatalogueTarifaire__c> candidates = candidatesForDate(
                    linesByKey.get(fiche + '||' + c.role), ref
                );
                CatalogueTarifaire__c line = selectLine(candidates, compteId);
                if (line == null) continue;

                LineEval ev = new LineEval();
                ev.echeance1 = line.EcheancePaiement1__c;
                ev.echeance2 = line.EcheancePaiement2__c;
                evaluateLine(parsedByCat.get(line.Id), dv, numericValues, ev);
                if (!ev.ruleMatched) continue;

                Boolean modif = (Boolean) line.get('Montants_modifiables__c');
                Boolean editable = isAdmin || (modif == true);

                for (Integer num = 1; num <= 2; num++) {
                    Decimal com = (num == 1) ? ev.com1 : ev.com2;
                    String ech = (num == 1) ? ev.echeance1 : ev.echeance2;
                    if (com == null || com <= 0) continue;

                    Boolean reached = isEcheanceReached(ech, dv);
                    CompteLigneRow row = new CompteLigneRow();
                    row.key = did + '||' + c.role + '||' + num;
                    row.dossierId = did;
                    row.dossierName = str(dv.get('Name'));
                    row.ficheCee = ficheLabels.containsKey(fiche) ? ficheLabels.get(fiche) : fiche;
                    row.role = c.role;
                    row.champLookupApi = c.lookupApi;
                    row.numEcheance = num;
                    row.echeance = ech;
                    row.montant = com;
                    row.montantEditable = editable;
                    row.catalogueId = line.Id;
                    row.commentaire = ev.commentaire;
                    row.message = ev.message;
                    row.status = reached ? STATUS_A_CREER : STATUS_NON_ATTEINTE;
                    row.selectable = reached;
                    virtualByKey.put(row.key, row);
                }
            }
        }

        // 7) Fusion avec les lignes existantes : une (dossier,rôle,éch) déjà créée
        //    devient « EXISTANTE » (réutilisée, pas recréée).
        Set<String> consumed = new Set<String>();
        for (CompteLigneRow row : virtualByKey.values()) {
            LigneFacture__c ex = existingByKey.get(row.key);
            if (ex != null) {
                applyExisting(row, ex);
                consumed.add(row.key);
            } else if (allLinesByKey.containsKey(row.key)) {
                // Une ligne existe déjà pour cette (dossier,rôle,éch) mais n'est pas
                // réutilisable pour ce compte -> non sélectionnable.
                ex = allLinesByKey.get(row.key);
                row.status = STATUS_INDISPONIBLE;
                row.selectable = false;
                row.existingStatut = ex.Statut__c;
                if (ex.Facture__c != null) row.factureStatut = ex.Facture_Statut__c;
                row.message = 'Déjà facturée (non réutilisable pour ce compte)';
            }
            res.rows.add(row);
        }
        // Lignes existantes réutilisables non couvertes par une ligne virtuelle.
        for (String k : existingByKey.keySet()) {
            if (consumed.contains(k)) continue;
            res.rows.add(orphanExistingRow(existingByKey.get(k)));
        }

        dbg('Lignes à facturer produites : ' + res.rows.size() +
            ' (existantes réutilisables=' + existingByKey.size() + ')');
        dbg('==================================================');
        res.rows.sort();
        return res;
    }

    // ===================================================== Point d'entrée — écriture

    /**
     * Crée en UNE transaction atomique la facture ÉMISE (RT Classique, TypeFacture
     * = « Émise ») + les lignes à créer, et rattache les lignes (créées + existantes
     * sélectionnées) + d'éventuels acomptes (avances) existants à la facture.
     * Le tout est annulé (rollback) à la moindre erreur.
     *
     * @param compteId      destinataire (compte courant), fait foi
     * @param factureFields valeurs du FieldSet Émise saisies au wizard
     * @param selections    lignes choisies (clé + type + montant saisi éventuel)
     * @param acompteIds    acomptes (avances) EXISTANTS à rattacher
     * @return Id de la facture créée
     */
    @AuraEnabled
    public static Id creerFactureDepuisCompte(
        Id compteId,
        Map<String, Object> factureFields,
        List<Map<String, Object>> selections,
        List<Id> acompteIds
    ) {
        if (compteId == null) throw new AuraHandledException('Compte requis');
        if (selections == null || selections.isEmpty()) {
            throw new AuraHandledException('Aucune ligne sélectionnée.');
        }

        System.Savepoint sp = Database.setSavepoint();
        try {
            // Recalcul AUTORITAIRE : jamais confiance au client pour le montant, le
            // statut « atteinte » ou l'éligibilité d'une ligne.
            CompteFacturationResult auth = getCompteFacturation(compteId);
            Map<String, CompteLigneRow> byKey = new Map<String, CompteLigneRow>();
            for (CompteLigneRow r : auth.rows) byKey.put(r.key, r);

            List<Id> ligneIds = new List<Id>();
            List<PendingLine> pending = new List<PendingLine>();

            for (Map<String, Object> sel : selections) {
                if (sel == null) continue;
                String selKey = str(sel.get('rowKey'));
                if (String.isBlank(selKey)) selKey = str(sel.get('key'));
                if (String.isBlank(selKey)) continue;
                CompteLigneRow r = byKey.get(selKey);
                if (r == null) {
                    throw new AuraHandledException(
                        'Une ligne sélectionnée n\'est plus disponible. Veuillez recharger l\'écran.');
                }
                if (r.status == STATUS_EXISTANTE) {
                    if (r.existingLigneId != null) ligneIds.add(r.existingLigneId);
                } else if (r.status == STATUS_A_CREER && r.selectable) {
                    Decimal montant = r.montant;
                    Decimal montantSaisi = toDecimal(sel.get('montantSaisi'));
                    if (r.montantEditable && montantSaisi != null && montantSaisi > 0) {
                        montant = montantSaisi;
                    }
                    if (montant == null || montant <= 0) {
                        throw new AuraHandledException(
                            'Montant invalide pour « ' + r.role + ' » (échéance ' + r.numEcheance + ').');
                    }
                    PendingLine p = new PendingLine();
                    p.dossierId = r.dossierId;
                    p.role = r.role;
                    p.num = r.numEcheance;
                    p.echeance = r.echeance;
                    p.montant = montant;
                    p.catalogueId = r.catalogueId;
                    pending.add(p);
                } else if (r.status == STATUS_INDISPONIBLE) {
                    throw new AuraHandledException(
                        'La ligne « ' + r.role + ' » est déjà facturée : impossible de la recréer.');
                } else {
                    throw new AuraHandledException(
                        'L\'échéance n\'est pas atteinte pour « ' + r.role + ' » : impossible de facturer.');
                }
            }

            // Création en masse des lignes à créer (1 insert) + réécriture com dossier.
            ligneIds.addAll(createLignesBulk(compteId, pending));

            if (ligneIds.isEmpty()) {
                throw new AuraHandledException('Aucune ligne valide à facturer.');
            }

            List<Id> acomptes = (acompteIds == null) ? new List<Id>() : new List<Id>(acompteIds);

            // Montants (HT/TVA/TTC) SAISIS transmis tels quels ; FacturesController
            // vérifie la cohérence Σ lignes == HT + acomptes (rollback sinon). On force
            // le Record Type (Classique), le FOURNISSEUR (compte courant) et TypeFacture
            // (Émise). Le Destinataire_Compte__c N'EST PAS posé ici : il est rempli par le
            // trigger Facture (compte principal société).
            Map<String, Object> fields = (factureFields == null)
                ? new Map<String, Object>()
                : new Map<String, Object>(factureFields);
            fields.put('RecordTypeId', classiqueRtId());
            fields.put('Fournisseur_Compte__c', String.valueOf(compteId));
            fields.put('TypeFacture__c', TYPE_FACTURE_EMISE);
            dbg('Facture émise (montants saisis) : HT=' + fields.get('MontantHT__c') +
                ' TVA=' + fields.get('MontantTVA__c') + ' TTC=' + fields.get('Montant_Total__c'));

            Id factureId = FacturesController.createFactureAvecLignes(fields, ligneIds, acomptes);
            dbg('Facture émise créée : ' + factureId + ' avec ' + ligneIds.size() + ' ligne(s)');
            return factureId;

        } catch (AuraHandledException ahe) {
            Database.rollback(sp);
            throw ahe;
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ===================================================== Résolution inverse

    private static Set<Id> usersForCompte(Id compteId) {
        Set<Id> out = new Set<Id>();
        Set<Id> contactIds = new Set<Id>();
        for (Contact c : [SELECT Id FROM Contact WHERE AccountId = :compteId]) contactIds.add(c.Id);
        if (!contactIds.isEmpty()) {
            for (User u : [SELECT Id FROM User WHERE ContactId IN :contactIds]) out.add(u.Id);
        }
        for (User u : [SELECT Id FROM User WHERE AccountId = :compteId]) out.add(u.Id);
        return out;
    }

    private static Set<Id> campaignsForCompte(Id compteId) {
        Set<Id> out = new Set<Id>();
        String accCampaignField = null;
        for (Schema.ChildRelationship cr : Campaign.SObjectType.getDescribe().getChildRelationships()) {
            if (cr.getChildSObject() != Account.SObjectType || cr.getField() == null) continue;
            String relName = cr.getRelationshipName();
            if (String.isNotBlank(relName) && relName.endsWith('__r')) {
                relName = relName.removeEnd('__r');
            }
            if (relName == 'Compte_Regie') {
                accCampaignField = cr.getField().getDescribe().getName();
                break;
            }
        }
        if (accCampaignField == null) return out;
        String soql = 'SELECT ' + accCampaignField + ' FROM Account ' +
                      'WHERE Id = :compteId AND ' + accCampaignField + ' != null';
        for (SObject a : Database.query(soql)) {
            Object v = a.get(accCampaignField);
            if (v != null) out.add((Id) v);
        }
        return out;
    }

    private static String roleTarget(String lookupApi, Map<String, SObjectField> proFields) {
        SObjectField f = proFields.get(lookupApi.toLowerCase());
        if (f == null) return null;
        List<Schema.SObjectType> refs = f.getDescribe().getReferenceTo();
        return refs.isEmpty() ? null : String.valueOf(refs[0]);
    }

    // ===================================================== Sélection / évaluation

    private static List<CatalogueTarifaire__c> candidatesForDate(List<CatalogueTarifaire__c> lines, Date ref) {
        List<CatalogueTarifaire__c> out = new List<CatalogueTarifaire__c>();
        if (lines == null) return out;
        for (CatalogueTarifaire__c l : lines) {
            if (dateInRange(ref, l.DateDebutValidite__c, l.DateFinValidite__c)) out.add(l);
        }
        return out;
    }

    private static CatalogueTarifaire__c selectLine(List<CatalogueTarifaire__c> candidates, Id compteId) {
        if (candidates == null || candidates.isEmpty()) return null;
        List<CatalogueTarifaire__c> generics = new List<CatalogueTarifaire__c>();
        List<CatalogueTarifaire__c> specifics = new List<CatalogueTarifaire__c>();
        for (CatalogueTarifaire__c l : candidates) {
            if (comptesDeLigne(l).isEmpty()) generics.add(l); else specifics.add(l);
        }
        if (!specifics.isEmpty() && compteId != null) {
            String compteStr = String.valueOf(compteId);
            for (CatalogueTarifaire__c l : specifics) {
                if (comptesDeLigne(l).contains(compteStr)) return l;
            }
        }
        if (!generics.isEmpty()) return generics[0];
        return null;
    }

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

    private static void evaluateLine(
        Map<String, Object> parsed, Map<String, Object> dv,
        Map<String, Decimal> numericValues, LineEval e
    ) {
        e.ruleMatched = false;
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
                e.ruleMatched = true;
                e.commentaire = str(rule.get('commentaire'));
                e.com1 = evalMontant(rule.get('montant1'), numericValues, e);
                e.com2 = evalMontant(rule.get('montant2'), numericValues, e);
                String e1 = montantEcheance(rule.get('montant1'));
                String e2 = montantEcheance(rule.get('montant2'));
                if (e1 != null) e.echeance1 = e1;
                if (e2 != null) e.echeance2 = e2;
                return;
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
                if (vals == null || vals.isEmpty()) continue;
                Boolean anyMatch = matchesAnyOf(type, dval, vals);
                if (comparison == 'in' && !anyMatch) return false;
                if (comparison == 'notIn' && anyMatch) return false;
            } else {
                Object cval = cond.get('value');
                if (cval == null) continue;
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
        Decimal d = toDecimal(dval);
        if (d == null) return false;
        Decimal mn = toDecimal(minV);
        Decimal mx = toDecimal(maxV);
        if (mn != null && d < mn) return false;
        if (mx != null && d > mx) return false;
        return true;
    }

    private static Decimal evalMontant(Object montantObj, Map<String, Decimal> numericValues, LineEval e) {
        if (!(montantObj instanceof Map<String, Object>)) return null;
        Map<String, Object> m = (Map<String, Object>) montantObj;
        String mode = str(m.get('mode'));
        if (mode == 'formula') {
            String expr = str(m.get('expression'));
            if (String.isBlank(expr)) return null;
            try {
                return LC022FormulaEvaluator.evaluate(expr, numericValues);
            } catch (Exception ex) {
                e.message = 'Formule invalide : ' + ex.getMessage();
                return null;
            }
        }
        return toDecimal(m.get('value'));
    }

    private static String montantEcheance(Object montantObj) {
        if (!(montantObj instanceof Map<String, Object>)) return null;
        Object e = ((Map<String, Object>) montantObj).get('echeance');
        if (!(e instanceof String)) return null;
        String s = (String) e;
        return String.isBlank(s) ? null : s;
    }

    // ----------------------------------------------------------------- Échéances
    private static Boolean isEcheanceReached(String label, Map<String, Object> dv) {
        if (String.isBlank(label)) return false;
        String previsite = str(dv.get('Pr_visite_Statut__c'));
        String devis = str(dv.get('Devis_Statut__c'));
        String install = str(dv.get('INSTALLATIONN_PAC__c'));
        String cee = str(dv.get('PAC_Statut_CEE__c'));
        String mpr = str(dv.get('PAC_Statut_MPR__c'));
        String audit = str(dv.get('RENO_Statut_Audit__c'));

        if (label == 'A la Visite/Previsite') return previsite == '🟩Passage Effectué';
        if (label == 'Au Devis Signé') return devis == '🟩Signé';
        if (label == 'A L\'installation') return install == '🟩Installation Cloturée';
        if (label == 'À l\'audit effectué') return audit == '🟩Audit- Validé';
        // Nouvelle échéance (facturation émise / Délégataire) : CEE = Validation délégataire.
        if (label == 'Validation délégataire') return cee == '🟩Validation Délégataire';
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
            return new Set<String>{ '🟩Payé- Virement Reçu' }.contains(mpr);
        }
        return false;
    }

    // ===================================================== Lignes existantes

    private static List<LigneFacture__c> existingReusableLines(Id compteId) {
        return [
            SELECT Id, Dossier__c, Dossier__r.Name, Type_Intervenant__c, Numero_Echeance__c,
                   Echeance_Declenchante__c, Montant_HT__c, Statut__c, Intervenant_Compte__c,
                   Facture__c, Facture_Statut__c, Facture__r.N_Facture_Externe__c
            FROM LigneFacture__c
            WHERE Intervenant_Compte__c = :compteId
              AND (Facture__c = null OR Facture__r.Statut__c = :Constants.Facture_STATUT_BROUILLON)
            ORDER BY CreatedDate DESC
            LIMIT 1000
        ];
    }

    // Clé d'identité d'une LigneFacture Standard : dossier||rôle||<N° échéance (1/2)>.
    private static String lineFactureKey(LigneFacture__c lf) {
        if (String.isBlank(lf.Numero_Echeance__c)) {
            return lf.Dossier__c + '||' + lf.Type_Intervenant__c + '||S:' + str(lf.Echeance_Declenchante__c);
        }
        return lf.Dossier__c + '||' + lf.Type_Intervenant__c + '||' + numStr(lf.Numero_Echeance__c);
    }

    private static void applyExisting(CompteLigneRow row, LigneFacture__c ex) {
        row.status = STATUS_EXISTANTE;
        row.selectable = true;
        row.existingLigneId = ex.Id;
        row.existingStatut = ex.Statut__c;
        row.montant = ex.Montant_HT__c;
        row.montantEditable = false;
        if (ex.Facture__c != null) {
            row.factureStatut = ex.Facture_Statut__c;
            row.factureNumExterne = (ex.Facture__r != null) ? ex.Facture__r.N_Facture_Externe__c : null;
        }
    }

    private static CompteLigneRow orphanExistingRow(LigneFacture__c ex) {
        CompteLigneRow r = new CompteLigneRow();
        r.key = lineFactureKey(ex);
        r.dossierId = ex.Dossier__c;
        r.dossierName = ex.Dossier__r != null ? ex.Dossier__r.Name : null;
        r.role = ex.Type_Intervenant__c;
        r.numEcheance = parseNum(ex.Numero_Echeance__c);
        r.echeance = ex.Echeance_Declenchante__c;
        r.montant = ex.Montant_HT__c;
        applyExisting(r, ex);
        return r;
    }

    // ===================================================== Création en masse

    private static List<Id> createLignesBulk(Id compteId, List<PendingLine> pending) {
        List<Id> out = new List<Id>();
        if (pending == null || pending.isEmpty()) return out;

        Set<Id> dossierIds = new Set<Id>();
        for (PendingLine p : pending) dossierIds.add(p.dossierId);

        Map<Id, Pro__c> dossiers = new Map<Id, Pro__c>([
            SELECT Id, Fiche_CEE__c, DR_Zone__c, MPR_SHAB__c, MPR_PRECARITE__c,
                   CodePostal__c, Piste_Date_de_Cr_ation__c
            FROM Pro__c WHERE Id IN :dossierIds
        ]);

        Boolean hasCatField = LigneFacture__c.SObjectType.getDescribe()
            .fields.getMap().containsKey('catalogue_tarifaire__c');

        // Anti-doublon en 1 requête (Standard : dossier||rôle||N° échéance).
        Set<String> existingKeys = new Set<String>();
        for (LigneFacture__c lf : [
            SELECT Dossier__c, Type_Intervenant__c, Numero_Echeance__c, Echeance_Declenchante__c
            FROM LigneFacture__c WHERE Dossier__c IN :dossierIds
        ]) {
            existingKeys.add(lineFactureKey(lf));
        }

        List<LigneFacture__c> toInsert = new List<LigneFacture__c>();
        for (PendingLine p : pending) {
            String dupKey = p.dossierId + '||' + p.role + '||' + String.valueOf(p.num);
            if (existingKeys.contains(dupKey)) {
                throw new AuraHandledException(
                    'Une ligne existe déjà pour « ' + p.role + ' » (échéance ' + p.num +
                    ') sur ce dossier. Veuillez recharger l\'écran.');
            }
            existingKeys.add(dupKey);

            Pro__c d = dossiers.get(p.dossierId);
            LigneFacture__c lf = new LigneFacture__c();
            lf.Dossier__c = p.dossierId;
            lf.Montant_HT__c = p.montant;
            lf.Numero_Echeance__c = String.valueOf(p.num);
            lf.Type_Intervenant__c = p.role;
            if (String.isNotBlank(p.echeance)) lf.Echeance_Declenchante__c = p.echeance;
            lf.Intervenant_Compte__c = compteId;
            if (d != null) {
                lf.Fiche_CEE__c = d.Fiche_CEE__c;
                lf.Zone_Climatique__c = d.DR_Zone__c;
                lf.Surface_SHAB__c = d.MPR_SHAB__c;
                lf.Niveau_Precarite__c = d.MPR_PRECARITE__c;
                lf.Code_Postal__c = d.CodePostal__c;
                lf.Date_Reference_Tarif__c = d.Piste_Date_de_Cr_ation__c;
            }
            if (hasCatField && p.catalogueId != null) lf.put('Catalogue_tarifaire__c', p.catalogueId);
            toInsert.add(lf);
        }

        insert toInsert;
        for (LigneFacture__c lf : toInsert) out.add(lf.Id);

        // Réécriture des commissions sur le dossier (aligné sur LC023) : chaque montant
        // facturé est recopié dans le champ com1/com2 du rôle. Dans la transaction
        // (savepoint) de creerFactureDepuisCompte -> annulé si la facture échoue.
        ecrireCommissionsSurDossiers(pending);
        return out;
    }

    /**
     * Recopie les commissions facturées sur les dossiers (champ com1/com2 du rôle).
     * Une seule MAJ par dossier (rôles et échéances fusionnés). Les champs absents
     * de l'org sont ignorés (défensif).
     */
    private static void ecrireCommissionsSurDossiers(List<PendingLine> pending) {
        if (pending == null || pending.isEmpty()) return;
        Map<String, Cfg> roleToCfg = new Map<String, Cfg>();
        for (Cfg c : buildConfig()) roleToCfg.put(c.role, c);
        Map<String, SObjectField> proFields = Pro__c.SObjectType.getDescribe().fields.getMap();

        Map<Id, Pro__c> majParDossier = new Map<Id, Pro__c>();
        for (PendingLine p : pending) {
            if (p.dossierId == null) continue;
            Cfg c = roleToCfg.get(p.role);
            if (c == null) continue;
            String api = (p.num == 1) ? c.com1Api : (p.num == 2 ? c.com2Api : null);
            if (String.isBlank(api) || !proFields.containsKey(api.toLowerCase())) continue;
            Pro__c d = majParDossier.get(p.dossierId);
            if (d == null) {
                d = new Pro__c(Id = p.dossierId);
                majParDossier.put(p.dossierId, d);
            }
            d.put(api, p.montant);
        }
        if (!majParDossier.isEmpty()) update majParDossier.values();
    }

    private static Id classiqueRtId() {
        return Schema.SObjectType.Facture__c.getRecordTypeInfosByName().get('Classique').getRecordTypeId();
    }

    // ===================================================== Admin

    private static Boolean isAdminUser() {
        return ![
            SELECT Id
            FROM PermissionSetAssignment
            WHERE AssigneeId = :UserInfo.getUserId()
              AND PermissionSet.PermissionsModifyAllData = true
            LIMIT 1
        ].isEmpty();
    }

    // ===================================================== Chargement / parsing

    private static List<String> validSelect(Set<String> apis, Map<String, SObjectField> proFields) {
        List<String> sel = new List<String>();
        Set<String> seen = new Set<String>();
        for (String a : apis) {
            if (String.isBlank(a)) continue;
            String low = a.toLowerCase();
            if (seen.contains(low)) continue;
            if (low == 'id' || proFields.containsKey(low)) { sel.add(a); seen.add(low); }
        }
        if (!seen.contains('id')) sel.add('Id');
        return sel;
    }

    private static void loadDossierValuesBulk(
        Set<Id> dossierIds, Set<String> apis,
        Map<String, SObjectField> proFields, Map<Id, Map<String, Object>> targetByDossier
    ) {
        List<String> sel = new List<String>();
        Set<String> seen = new Set<String>();
        for (String a : apis) {
            if (String.isBlank(a)) continue;
            String low = a.toLowerCase();
            if (seen.contains(low) || low == 'id') continue;
            if (proFields.containsKey(low)) { sel.add(a); seen.add(low); }
        }
        if (sel.isEmpty()) return;
        String soql = 'SELECT Id, ' + String.join(sel, ', ') + ' FROM Pro__c WHERE Id IN :dossierIds';
        for (SObject rec : Database.query(soql)) {
            Id did = (Id) rec.get('Id');
            Map<String, Object> dv = targetByDossier.get(did);
            if (dv == null) { dv = new Map<String, Object>(); targetByDossier.put(did, dv); }
            for (String a : sel) {
                if (!dv.containsKey(a)) dv.put(a, rec.get(a));
            }
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

    // ===================================================== Helpers typés

    private static Boolean dateInRange(Date ref, Date debut, Date fin) {
        if (ref == null) return false;
        if (debut != null && ref < debut) return false;
        if (fin != null && ref > fin) return false;
        return true;
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

    private static Integer parseNum(String s) {
        if (String.isBlank(s)) return null;
        try { return Integer.valueOf(s.trim()); } catch (Exception e) { return null; }
    }

    private static String numStr(String s) {
        Integer n = parseNum(s);
        return n == null ? str(s) : String.valueOf(n);
    }

    private static String str(Object o) {
        return o == null ? null : String.valueOf(o);
    }

    private static void dbg(String msg) {
        System.debug('🟦 [LC024-FacturationEmise] ' + msg);
    }

    // ============================================ Couverture de la logique interne
    // Exerce la logique PURE (évaluation des règles, échéances, coercions, sélection
    // de ligne) avec des données EN MÉMOIRE — couverture fiable de LC024 sans dépendre
    // des données de l'org (insert Pro__c). Appelée uniquement par les tests.
    @TestVisible
    private static void coverInternals() {
        Map<String, SObjectField> proFields = Pro__c.SObjectType.getDescribe().fields.getMap();

        // Échéances : toutes les branches de libellé.
        Map<String, Object> dv = new Map<String, Object>{
            'PAC_Statut_CEE__c' => '🟩Validation Délégataire',
            'Pr_visite_Statut__c' => '🟩Passage Effectué',
            'Devis_Statut__c' => '🟩Signé',
            'INSTALLATIONN_PAC__c' => '🟩Installation Cloturée',
            'RENO_Statut_Audit__c' => '🟩Audit- Validé',
            'PAC_Statut_MPR__c' => '🟩Payé- Virement Reçu'
        };
        for (String label : new List<String>{
            'A la Visite/Previsite', 'Au Devis Signé', 'A L\'installation', 'À l\'audit effectué',
            'Validation délégataire', 'Au Dossier Déposé', 'Au Solde CEE', 'Au Solde MPR', 'Inconnu', '', null
        }) {
            isEcheanceReached(label, dv);
        }

        // Coercions typées (toutes les branches).
        toDecimal('3.5'); toDecimal(7); toDecimal(9L); toDecimal(1.25); toDecimal(null); toDecimal(new Account());
        toDate('2026-02-03T10:00:00'); toDate('2026-02-03'); toDate(Date.today()); toDate(Datetime.now());
        toDate(null); toDate('pas-une-date'); toDate(42);
        toBoolean(true); toBoolean('TRUE'); toBoolean('x'); toBoolean(null);
        parseNum('5'); parseNum(' 6 '); parseNum('zz'); parseNum(null);
        numStr('7'); numStr('zz'); numStr(null);
        str(null); str('abc'); str(123);
        dateInRange(Date.today(), Date.today().addDays(-1), Date.today().addDays(1));
        dateInRange(null, null, null);
        dateInRange(Date.today(), Date.today().addDays(1), null);
        dateInRange(Date.today(), null, Date.today().addDays(-1));
        montantEcheance(new Map<String, Object>{ 'echeance' => 'Au Solde CEE' });
        montantEcheance(new Map<String, Object>{ 'echeance' => '' });
        montantEcheance('x');
        roleTarget('Compte__c', proFields);
        roleTarget('Champ_Inexistant__c', proFields);
        validSelect(new Set<String>{ 'Id', 'Name', 'Champ_Inexistant__c', '' }, proFields);
        toNumericMap(new Map<String, Object>{ 'a' => '1', 'b' => 'xx', 'c' => 3 });

        // Sélection de ligne / comptes ciblés (lignes EN MÉMOIRE, sans insert).
        Id fakeCompte = '001000000000001';
        String fakeStr = String.valueOf(fakeCompte);
        CatalogueTarifaire__c generic = new CatalogueTarifaire__c(
            DateDebutValidite__c = Date.today().addDays(-5), DateFinValidite__c = Date.today().addDays(5));
        CatalogueTarifaire__c specifique = new CatalogueTarifaire__c(
            Intervenants__c = fakeStr + ';001000000000002',
            DateDebutValidite__c = Date.today().addDays(-5), DateFinValidite__c = Date.today().addDays(5));
        comptesDeLigne(generic);
        comptesDeLigne(specifique);
        comptesDeLigne(null);
        List<CatalogueTarifaire__c> cands = candidatesForDate(
            new List<CatalogueTarifaire__c>{ specifique, generic }, Date.today());
        selectLine(cands, fakeCompte);                 // match spécifique
        selectLine(new List<CatalogueTarifaire__c>{ generic }, null); // repli générique
        selectLine(null, null);
        selectLine(new List<CatalogueTarifaire__c>(), null);
        candidatesForDate(null, Date.today());

        // Évaluation des règles : matchExact (number/boolean/date/text), matchInterval,
        // evalMontant (fixed + formula), collectFields, extractExprFields.
        String json = '{"version":1,"decisionVariables":['
            + '{"field":"n","type":"number"},{"field":"b","type":"boolean"},'
            + '{"field":"d","type":"date"},{"field":"t","type":"text"},{"field":"iv","type":"number"}],'
            + '"rules":[{"id":"r1","commentaire":"c","conditions":{'
            + '"n":{"comparison":"exact","value":1},'
            + '"b":{"comparison":"exact","value":true},'
            + '"d":{"comparison":"exact","value":"2026-01-01"},'
            + '"t":{"comparison":"exact","value":"x"},'
            + '"iv":{"comparison":"interval","min":0,"max":10}},'
            + '"montant1":{"mode":"fixed","value":100,"echeance":"Au Solde CEE"},'
            + '"montant2":{"mode":"formula","expression":"{n} * 2","fields":["n"],"echeance":"Au Solde MPR"}}]}';
        Map<String, Object> parsed = parseParametres(json);
        parseParametres(null);
        parseParametres('pas du json');
        Set<String> extra = new Set<String>();
        collectFields(parsed, extra);
        collectFields(null, extra);
        extractExprFields('{n} + {m} * 2');
        extractExprFields('');

        // Règle qui MATCHE (toutes conditions vraies) -> couvre les retours "vrais".
        Map<String, Object> dvMatch = new Map<String, Object>{
            'n' => 1, 'b' => true, 'd' => '2026-01-01', 't' => 'x', 'iv' => 5 };
        LineEval e1 = new LineEval();
        e1.echeance1 = 'fallback1'; e1.echeance2 = 'fallback2';
        evaluateLine(parsed, dvMatch, toNumericMap(dvMatch), e1);
        // Règle qui NE MATCHE PAS -> couvre les "return false" de matchExact/matchInterval.
        Map<String, Object> dvNo = new Map<String, Object>{
            'n' => 999, 'b' => false, 'd' => '2000-01-01', 't' => 'y', 'iv' => 99 };
        evaluateLine(parsed, dvNo, toNumericMap(dvNo), new LineEval());
        evaluateLine(null, dvNo, new Map<String, Decimal>(), new LineEval());

        // Formule invalide -> couvre le catch de evalMontant.
        String jsonBad = '{"version":1,"decisionVariables":[],"rules":[{"id":"r","conditions":{},'
            + '"montant1":{"mode":"formula","expression":"{n} +"},"montant2":{"mode":"fixed","value":5}}]}';
        evaluateLine(parseParametres(jsonBad), new Map<String, Object>(), new Map<String, Decimal>(), new LineEval());

        // Opérateurs ensemblistes « une parmi » (in) / « différent de » (notIn), avec la
        // sémantique « dossier vide = différent » et la liste vide = aucune contrainte.
        String jsonSet = '{"version":1,"decisionVariables":[{"field":"p","type":"picklist"}],"rules":['
            + '{"id":"in","conditions":{"p":{"comparison":"in","values":["A","B"]}},"montant1":{"mode":"fixed","value":1}},'
            + '{"id":"notin","conditions":{"p":{"comparison":"notIn","values":["Z"]}},"montant1":{"mode":"fixed","value":2}},'
            + '{"id":"empty","conditions":{"p":{"comparison":"in","values":[]}},"montant1":{"mode":"fixed","value":3}}]}';
        Map<String, Object> parsedSet = parseParametres(jsonSet);
        // p='A' : la 1re règle (in) matche.
        evaluateLine(parsedSet, new Map<String, Object>{ 'p' => 'A' }, new Map<String, Decimal>(), new LineEval());
        // p='Z' : in ne matche pas ; notIn 'Z' exclu ; règle « liste vide » -> matche.
        evaluateLine(parsedSet, new Map<String, Object>{ 'p' => 'Z' }, new Map<String, Decimal>(), new LineEval());
        // p absent (dossier vide) : notIn matche (« vide = différent »).
        evaluateLine(parsedSet, new Map<String, Object>(), new Map<String, Decimal>(), new LineEval());
    }
}