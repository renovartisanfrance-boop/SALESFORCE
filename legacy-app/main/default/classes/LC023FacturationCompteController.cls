/**
 * Contrôleur de la Facturation DEPUIS LE COMPTE (composant lwc023FacturationCompte).
 *
 * Nouveau point d'entrée : à partir d'un Compte (Account), on balaie TOUS les
 * dossiers (Pro__c) où ce compte joue un rôle (intervenant), on calcule pour
 * chacun les échéances facturables via le Catalogue Tarifaire (même logique que
 * la Facturation V2), et on permet — dans un wizard unique — de :
 *   1) sélectionner les lignes à créer + les lignes déjà créées réutilisables ;
 *   2) saisir les informations de facture (FieldSet Classique) ;
 *   3) rattacher d'éventuels acomptes ;
 *   4) créer en UNE transaction atomique la Facture Classique + les lignes + le
 *      rattachement (réutilise FacturesController.createFactureAvecLignes).
 *
 * AUTONOME (préfixe 023) : cette classe NE MODIFIE PAS et ne dépend pas de
 * LC022FacturationCatalogueController (réservé à la V2 depuis le dossier). La
 * logique de détection de prix (config rôles, sélection de ligne catalogue,
 * évaluation des règles ParametresFiche__c, échéances) y est ré-implémentée,
 * mais BULKIFIÉE pour balayer N dossiers en un nombre de requêtes constant.
 * Le seul réutilisé (sans modification) est LC022FormulaEvaluator (évaluateur
 * de formules pur) et FacturesController (création/regroupement de facture).
 *
 * Sécurité : « without sharing » (choix métier — vue consolidée par compte) ;
 * le montant facturé est RECALCULÉ côté serveur depuis le catalogue (un montant
 * saisi n'est accepté que si la ligne est « montants modifiables » ou si
 * l'utilisateur est admin).
 */
public without sharing class LC023FacturationCompteController {

    // ============================================================ Mapping rôles
    // Repris à l'identique de la Facturation V2 (vérité terrain). Chaque rôle est
    // porté par un champ lookup du dossier dont la CIBLE peut être Account, User
    // (-> Contact.AccountId) ou Campaign (-> Compte_Regie__r).

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
            new Cfg('Auditeur',      'Auditeur',              'Com1_Aud__c',        'Com2_Aud__c',          'LOOKUP_Auditeur__c')
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
    // Ligne Supplémentaire déjà créée mais NON liée à une facture : « Créée »,
    // non recréable / non réutilisable (≠ EXISTANTE du Standard, réutilisable).
    private static final String STATUS_CREEE = 'CREEE';

    // Record Type des lignes catalogue « Supplémentaire » (logique de paiement
    // distincte du Standard : plusieurs lignes par intervenant, échéance au niveau
    // ligne via echeanceSupp__c, réalisation pilotée par PREVISITE_PORTE__c).
    private static final String RT_SUPPLEMENTAIRE = 'Supplementaire';
    // Champ du dossier pilotant la réalisation des échéances Supplémentaire (Porte
    // 1/2). Le montant n'entre PAS dans la décision (≠ Standard).
    private static final String SUPP_PORTE_FIELD = 'PREVISITE_PORTE__c';
    // Champ pilotant l'échéance Supplémentaire « Supplément Installation » :
    // réalisée lorsque les frais supplémentaires d'installation sont > 0.
    private static final String SUPP_INSTALL_FIELD = 'INSTALLATION_Frais_Supplementaire__c';
    // Champ pilotant les échéances Supplémentaire « Frais Déplacement 1/2 » : même
    // cascade que les portes (valeurs ⬛Frais Déplacement 1 / ⬛Frais Déplacement 2).
    private static final String SUPP_DEPLACEMENT_FIELD = 'INSTALLATION_Deplacement__c';
    // Record Type des lignes catalogue « Acompte » : sert à proposer des factures
    // d'acompte (RT Facture Acompte) à l'écran 3, dérivées des lignes facturées.
    private static final String RT_ACOMPTE = 'Acompte';
    // Sentinelle de clé (fiche||rôle) pour les lignes Acompte « toutes fiches »
    // (FicheCEE vide) : la Fiche est FACULTATIVE pour l'Acompte (≠ Standard).
    private static final String ACOMPTE_ALL_FICHES = '*';
    // Désignation (texte fixe) portée par chaque facture d'acompte.
    private static final String ACOMPTE_DESIGNATION = '-';
    // Champs « progression 1/2 » pour lesquels les conditions des règles ACOMPTE sont
    // évaluées EN CASCADE (niveau atteint >= niveau requis) et non en égalité stricte :
    // atteindre « ⬛Porte 2 » réalise aussi l'acompte conditionné sur « ⬛Porte 1 ». On
    // peut donc proposer PLUSIEURS acomptes (un par palier franchi) pour un dossier.
    private static final Set<String> ACOMPTE_CASCADE_FIELDS = new Set<String>{
        'PREVISITE_PORTE__c', 'INSTALLATION_Deplacement__c'
    };

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
        @AuraEnabled public String status;          // A_CREER | EXISTANTE | NON_ATTEINTE
        @AuraEnabled public Boolean selectable = false;
        @AuraEnabled public Boolean isSupplementaire = false; // ligne du RT Supplémentaire (BG différent)
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
        String designationTemplate; // gabarit de désignation de la règle gagnante (Acompte)
    }

    // Ligne à créer (accumulée pour insertion en masse).
    private class PendingLine {
        Id dossierId;
        String role;
        Integer num;
        String echeance;
        Decimal montant;
        Id catalogueId;
        Boolean isSupp = false; // ligne Supplémentaire : pas de N° d'échéance, clé = échéance
    }

    // Proposition de facture d'acompte (RT Facture Acompte) dérivée d'une ligne
    // facturée sélectionnée × une ligne catalogue RT Acompte applicable. Montant HT
    // = montant catalogue ; TVA/TTC calculés depuis le taux de la facture Classique.
    public class AcompteProposition {
        @AuraEnabled public String key;          // rowKey||ACPT:catalogueId (identité proposition)
        @AuraEnabled public String rowKey;       // ligne facturée source (écran 1)
        @AuraEnabled public Id dossierId;
        @AuraEnabled public String dossierName;
        @AuraEnabled public String ficheCee;
        @AuraEnabled public String role;
        @AuraEnabled public Id catalogueId;      // ligne catalogue Acompte source
        @AuraEnabled public String designation;  // désignation (texte fixe)
        @AuraEnabled public Decimal montantHT;
        @AuraEnabled public Decimal tauxTVA;
        @AuraEnabled public Decimal montantTVA;
        @AuraEnabled public Decimal montantTTC;
    }

    // ===================================================== Point d'entrée — lecture

    /**
     * Toutes les lignes facturables (à créer) + réutilisables (déjà créées, non
     * liées ou sur une facture Brouillon) pour un compte donné, tous dossiers
     * confondus. Non cacheable : recalculé à chaque ouverture.
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

        // Cible (Account/User/Campaign) de chaque lookup de rôle, calculée UNE fois
        // (le describe est constant par champ : on évite de le rappeler en boucle).
        Map<String, String> targetByLookup = new Map<String, String>();
        for (Cfg c : config) {
            if (proFields.containsKey(c.lookupApi.toLowerCase())) {
                targetByLookup.put(c.lookupApi, roleTarget(c.lookupApi, proFields));
            }
        }

        // Libellés de la Fiche CEE (valeur API -> libellé) pour l'affichage.
        Map<String, String> ficheLabels = new Map<String, String>();
        for (Schema.PicklistEntry pe : Pro__c.Fiche_CEE__c.getDescribe().getPicklistValues()) {
            ficheLabels.put(pe.getValue(), pe.getLabel());
        }

        dbg('========== getCompteFacturation ==========');
        dbg('Compte : ' + compteId + ' (' + res.compteName + ')');

        // 1) Résolution inverse : Users et Campagnes rattachés à ce compte.
        Set<Id> userIds = usersForCompte(compteId);
        Set<Id> campaignIds = campaignsForCompte(compteId);
        dbg('Campagnes (régie) rattachées : ' + campaignIds.size() + ' -> ' + campaignIds);

        // 2) Dossiers candidats : ceux où le compte joue au moins un rôle.
        List<String> ors = new List<String>();
        for (Cfg c : config) {
            if (!proFields.containsKey(c.lookupApi.toLowerCase())) continue;
            String t = targetByLookup.get(c.lookupApi);
            if (t == 'Account') ors.add(c.lookupApi + ' = :compteId');
            else if (t == 'User' && !userIds.isEmpty()) ors.add(c.lookupApi + ' IN :userIds');
            else if (t == 'Campaign' && !campaignIds.isEmpty()) ors.add(c.lookupApi + ' IN :campaignIds');
        }
        dbg('Clause WHERE (rôles testés) : ' + (ors.isEmpty() ? '(AUCUNE — aucun rôle ne cible ce compte)' : String.join(ors, ' OR ')));

        Map<Id, Map<String, Object>> dvByDossier = new Map<Id, Map<String, Object>>();
        Map<Id, List<Cfg>> matchedByDossier = new Map<Id, List<Cfg>>();
        Set<String> fiches = new Set<String>();
        Set<String> rolesSet = new Set<String>();

        if (!ors.isEmpty()) {
            Set<String> selFields = new Set<String>{
                'Id', 'Name', 'Fiche_CEE__c', 'Piste_Date_de_Cr_ation__c', 'Facturer_Client__c'
            };
            selFields.addAll(STATUT_FIELDS);
            selFields.add(SUPP_PORTE_FIELD);      // pilote les échéances Porte 1/2
            selFields.add(SUPP_INSTALL_FIELD);    // pilote l'échéance « Supplément Installation »
            selFields.add(SUPP_DEPLACEMENT_FIELD); // pilote les échéances « Frais Déplacement 1/2 »
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
                    List<String> rolesDuDossier = new List<String>();
                    for (Cfg c : matched) { rolesSet.add(c.role); rolesDuDossier.add(c.role); }
                    dbg('Dossier candidat ' + did + ' (' + str(dv.get('Name')) + ', fiche=' + fiche +
                        ') -> rôles ciblant le compte : ' + rolesDuDossier);
                }
            }
        }
        dbg('Dossiers candidats trouvés : ' + dvByDossier.size() + ' ; avec rôle ciblant le compte : ' +
            matchedByDossier.size() + ' ; fiches=' + fiches + ' ; rôles=' + rolesSet);

        // 3) Lignes catalogue actives (fiches + rôles concernés), indexées par
        //    fiche||rôle. Le filtre de date de validité est appliqué PAR dossier
        //    (chaque dossier a sa propre date de référence).
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
                  AND RecordType.DeveloperName = 'Standard'
                  AND Paiement__c = 'Emis'
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
        dbg('Lignes catalogue actives trouvées (fiche||rôle) : ' + linesByKey.keySet());

        // 3 bis) Lignes catalogue ACTIVE du Record Type « Supplémentaire » (fiche||rôle).
        //   Modèle distinct du Standard : plusieurs lignes par rôle, échéance portée
        //   par echeanceSupp__c (au niveau ligne). Filtre de date appliqué par dossier.
        Map<String, List<CatalogueTarifaire__c>> suppLinesByKey = new Map<String, List<CatalogueTarifaire__c>>();
        if (!fiches.isEmpty() && !rolesSet.isEmpty()) {
            for (CatalogueTarifaire__c l : [
                SELECT Id, FicheCEE__c, RoleIntervenant__c, Intervenants__c, echeanceSupp__c,
                       MontantBase1__c, ParametresFiche__c, Montants_modifiables__c,
                       DateDebutValidite__c, DateFinValidite__c, Paiement__c
                FROM CatalogueTarifaire__c
                WHERE FicheCEE__c IN :fiches
                  AND Statut__c = 'Active'
                  AND RecordType.DeveloperName = :RT_SUPPLEMENTAIRE
                  AND RoleIntervenant__c IN :rolesSet
            ]) {
                String k = l.FicheCEE__c + '||' + l.RoleIntervenant__c;
                if (!suppLinesByKey.containsKey(k)) suppLinesByKey.put(k, new List<CatalogueTarifaire__c>());
                suppLinesByKey.get(k).add(l);
                Map<String, Object> parsed = parseParametres(l.ParametresFiche__c);
                parsedByCat.put(l.Id, parsed);
                collectFields(parsed, extraFields);
            }
        }
        dbg('Lignes catalogue Supplémentaire trouvées (fiche||rôle) : ' + suppLinesByKey.keySet());

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
        // statut de facture) : sert à marquer « indisponible » une (dossier,rôle,éch)
        // déjà créée mais NON réutilisable pour ce compte (déjà facturée sur une
        // facture Validé/Annulé, ou rattachée à un autre bénéficiaire), afin que
        // l'écran reflète l'anti-doublon réellement appliqué à la création.
        Boolean hasCatField = LigneFacture__c.SObjectType.getDescribe()
            .fields.getMap().containsKey('catalogue_tarifaire__c');
        Map<String, LigneFacture__c> allLinesByKey = new Map<String, LigneFacture__c>();
        // Index des lignes Supplémentaire par identité (dossier + ligne catalogue) :
        // une ligne déjà créée pour ce couple n'est plus recréable, quel que soit le
        // libellé d'échéance stocké.
        Map<String, LigneFacture__c> suppByCatKey = new Map<String, LigneFacture__c>();
        Set<Id> candDossierIds = dvByDossier.keySet();
        if (!candDossierIds.isEmpty()) {
            String catSel = hasCatField ? ', Catalogue_tarifaire__c' : '';
            String soql = 'SELECT Id, Dossier__c, Type_Intervenant__c, Numero_Echeance__c, ' +
                          'Echeance_Declenchante__c, Statut__c, Facture__c, Facture_Statut__c' + catSel +
                          ' FROM LigneFacture__c WHERE Dossier__c IN :candDossierIds';
            for (LigneFacture__c lf : Database.query(soql)) {
                allLinesByKey.put(lineFactureKey(lf), lf);
                if (hasCatField) {
                    Object cat = lf.get('Catalogue_tarifaire__c');
                    if (cat != null) suppByCatKey.put(lf.Dossier__c + '||CAT:' + cat, lf);
                }
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
                if (line == null) {
                    dbg('  [' + c.role + '] AUCUNE ligne catalogue valide (candidats=' +
                        (candidates == null ? 0 : candidates.size()) + ', dateRéf=' + ref + ')');
                    continue;
                }

                LineEval ev = new LineEval();
                ev.echeance1 = line.EcheancePaiement1__c;
                ev.echeance2 = line.EcheancePaiement2__c;
                evaluateLine(parsedByCat.get(line.Id), dv, numericValues, ev);
                if (!ev.ruleMatched) {
                    dbg('  [' + c.role + '] ligne ' + line.Id + ' trouvée mais AUCUNE règle ne matche le dossier');
                    continue;
                }
                dbg('  [' + c.role + '] ligne ' + line.Id + ' OK : com1=' + ev.com1 + ' (éch.' + ev.echeance1 +
                    '), com2=' + ev.com2 + ' (éch.' + ev.echeance2 + ')');

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

            // 6 bis) Lignes Supplémentaire (RT distinct, indépendantes du Standard) :
            //   plusieurs échéances possibles par rôle ; une échéance NON réalisée
            //   n'est PAS affichée (≠ Standard, qui montre les non atteintes).
            for (Cfg c : matchedByDossier.get(did)) {
                List<CatalogueTarifaire__c> suppCands = candidatesForDate(suppLinesByKey.get(fiche + '||' + c.role), ref);
                Map<String, CatalogueTarifaire__c> byEch = pickSuppLinesByEcheance(suppCands, compteId);
                for (String echLabel : byEch.keySet()) {
                    CatalogueTarifaire__c sline = byEch.get(echLabel);
                    if (sline == null) continue;
                    // Réalisation : uniquement sur PREVISITE_PORTE__c (le montant n'entre pas en jeu).
                    if (!isEcheanceSuppReached(echLabel, dv)) {
                        dbg('  [' + c.role + ' / ' + echLabel + '] échéance Supplémentaire non réalisée -> masquée');
                        continue;
                    }
                    // Montant = celui configuré au catalogue (règle gagnante -> montant1).
                    LineEval ev = new LineEval();
                    evaluateLine(parsedByCat.get(sline.Id), dv, numericValues, ev);
                    Decimal montant = ev.com1;
                    if (montant == null || montant <= 0) {
                        dbg('  [' + c.role + ' / ' + echLabel + '] aucun montant catalogue -> ignorée');
                        continue;
                    }
                    Boolean modifS = (Boolean) sline.get('Montants_modifiables__c');
                    CompteLigneRow row = new CompteLigneRow();
                    row.key = did + '||' + c.role + '||S:' + echLabel;
                    row.dossierId = did;
                    row.dossierName = str(dv.get('Name'));
                    row.ficheCee = ficheLabels.containsKey(fiche) ? ficheLabels.get(fiche) : fiche;
                    row.role = c.role;
                    row.champLookupApi = c.lookupApi;
                    row.numEcheance = null;
                    row.echeance = echLabel;
                    row.montant = montant;
                    row.montantEditable = isAdmin || (modifS == true);
                    row.catalogueId = sline.Id;
                    row.commentaire = ev.commentaire;
                    row.isSupplementaire = true;
                    row.status = STATUS_A_CREER;
                    row.selectable = true;
                    virtualByKey.put(row.key, row);
                    dbg('  [' + c.role + ' / ' + echLabel + '] Supplémentaire OK : montant=' + montant);
                }
            }
        }

        // 7) Fusion avec les lignes existantes : une (dossier,rôle,éch) déjà créée
        //    devient « EXISTANTE » (réutilisée, pas recréée).
        Set<String> consumed = new Set<String>();
        for (CompteLigneRow row : virtualByKey.values()) {
            // Supplémentaire : identité = (dossier + ligne catalogue). Une fois créée,
            // la ligne n'est PLUS recréable ni réutilisable -> on affiche seulement son
            // statut : « Créée » si non liée à une facture, sinon le statut de la facture.
            if (row.isSupplementaire) {
                // Identité = (dossier + ligne catalogue) ; repli sur la clé échéance.
                String catKey = (hasCatField && row.catalogueId != null)
                    ? (row.dossierId + '||CAT:' + row.catalogueId) : null;
                LigneFacture__c sx = (catKey != null) ? suppByCatKey.get(catKey) : null;
                if (sx == null) {
                    sx = allLinesByKey.containsKey(row.key) ? allLinesByKey.get(row.key) : existingByKey.get(row.key);
                }
                if (sx != null) {
                    consumed.add(lineFactureKey(sx));
                    row.existingLigneId = sx.Id;
                    row.existingStatut = sx.Statut__c;
                    row.selectable = false; // non recréable / non réutilisable
                    if (sx.Facture__c != null) {
                        row.status = STATUS_INDISPONIBLE;          // liée -> statut facture
                        row.factureStatut = sx.Facture_Statut__c;
                    } else {
                        row.status = STATUS_CREEE;                 // créée, non liée
                    }
                }
                res.rows.add(row);
                continue;
            }
            LigneFacture__c ex = existingByKey.get(row.key);
            if (ex != null) {
                applyExisting(row, ex);
                consumed.add(row.key);
            } else if (allLinesByKey.containsKey(row.key)) {
                // Une ligne existe déjà pour cette (dossier,rôle,éch) mais n'est pas
                // réutilisable pour ce compte -> non sélectionnable. On affiche le
                // statut de la facture liée s'il y en a une.
                ex = allLinesByKey.get(row.key);
                row.status = STATUS_INDISPONIBLE;
                row.selectable = false;
                row.existingStatut = ex.Statut__c;
                if (ex.Facture__c != null) row.factureStatut = ex.Facture_Statut__c;
                row.message = 'Déjà facturée (non réutilisable pour ce compte)';
            }
            res.rows.add(row);
        }
        // Lignes existantes réutilisables non couvertes par une ligne virtuelle
        // (ex. rôle retiré du dossier après création) : présentées telles quelles.
        for (String k : existingByKey.keySet()) {
            if (consumed.contains(k)) continue;
            res.rows.add(orphanExistingRow(existingByKey.get(k)));
        }

        dbg('Lignes à facturer produites : ' + res.rows.size() +
            ' (existantes réutilisables=' + existingByKey.size() + ')');
        dbg('==========================================');
        res.rows.sort();
        return res;
    }

    // =============================== Propositions de factures d'acompte (catalogue)

    /**
     * Pour les lignes facturées SÉLECTIONNÉES à l'écran 1, propose des factures
     * d'acompte dérivées des lignes catalogue RT « Acompte ». Les lignes Acompte
     * applicables sont sélectionnées sur Fiche (facultative) + rôle + intervenant +
     * dates + évaluation des règles. TOUTES les conditions comptent (dont la prise en
     * charge apporteur A_La_charge_de_l_apporteur_d_affaire__c) : pas de proposition si
     * aucune règle ne matche. Les champs « progression 1/2 » (Porte, Déplacement) sont
     * évalués en CASCADE, donc plusieurs acomptes (un par palier) peuvent être proposés.
     * Une proposition par (dossier + ligne catalogue Acompte), les couples déjà
     * consommés (marqueur LigneFacture) exclus.
     * Montant HT = montant catalogue ; TVA/TTC dérivés du taux TVA de la Classique.
     */
    @AuraEnabled
    public static List<AcompteProposition> getPropositionsAcompte(
        Id compteId, List<String> selectedRowKeys, Decimal tauxTVA
    ) {
        List<AcompteProposition> out = new List<AcompteProposition>();
        if (compteId == null || selectedRowKeys == null || selectedRowKeys.isEmpty()) return out;

        // Lignes sélectionnées (recalcul autoritaire).
        CompteFacturationResult res = getCompteFacturation(compteId);
        Map<String, CompteLigneRow> byKey = new Map<String, CompteLigneRow>();
        for (CompteLigneRow r : res.rows) byKey.put(r.key, r);

        List<CompteLigneRow> selected = new List<CompteLigneRow>();
        Set<Id> dossierIds = new Set<Id>();
        Set<String> roles = new Set<String>();
        for (String k : selectedRowKeys) {
            CompteLigneRow r = byKey.get(k);
            if (r == null || r.dossierId == null || String.isBlank(r.role)) continue;
            selected.add(r);
            dossierIds.add(r.dossierId);
            roles.add(r.role);
        }
        if (selected.isEmpty()) return out;

        Map<String, SObjectField> proFields = Pro__c.SObjectType.getDescribe().fields.getMap();

        // Valeurs dossier (fiche, date, statuts). Les champs des conditions des règles
        // (dont la prise en charge apporteur) sont ajoutés plus bas via collectFields.
        Map<Id, Map<String, Object>> dvByDossier = new Map<Id, Map<String, Object>>();
        Set<String> selFields = new Set<String>{
            'Id', 'Name', 'Fiche_CEE__c', 'Piste_Date_de_Cr_ation__c'
        };
        selFields.addAll(STATUT_FIELDS);
        loadDossierValuesBulk(dossierIds, selFields, proFields, dvByDossier);

        Set<String> fiches = new Set<String>();
        for (Id did : dossierIds) {
            Map<String, Object> dv = dvByDossier.get(did);
            if (dv != null) {
                String f = str(dv.get('Fiche_CEE__c'));
                if (String.isNotBlank(f)) fiches.add(f);
            }
        }

        // Lignes catalogue Acompte (fiche||rôle).
        Map<String, List<CatalogueTarifaire__c>> acompteByKey = new Map<String, List<CatalogueTarifaire__c>>();
        Map<Id, Map<String, Object>> parsedByCat = new Map<Id, Map<String, Object>>();
        Set<String> extraFields = new Set<String>();
        Set<Id> acompteCatIds = new Set<Id>();
        if (!roles.isEmpty()) {
            // Inclut les lignes Acompte « toutes fiches » (FicheCEE vide) : la Fiche
            // est facultative pour l'Acompte (≠ Standard/Supplémentaire).
            for (CatalogueTarifaire__c l : [
                SELECT Id, FicheCEE__c, RoleIntervenant__c, Intervenants__c,
                       MontantBase1__c, ParametresFiche__c, Montants_modifiables__c,
                       DateDebutValidite__c, DateFinValidite__c, Paiement__c,
                       Statut__c, TypeIntervenant__c, EcheancePaiement1__c,
                       EcheancePaiement2__c, echeanceSupp__c
                FROM CatalogueTarifaire__c
                WHERE (FicheCEE__c IN :fiches OR FicheCEE__c = null)
                  AND Statut__c = 'Active'
                  AND RecordType.DeveloperName = :RT_ACOMPTE
                  AND RoleIntervenant__c IN :roles
            ]) {
                // Ligne sans fiche -> clé « toutes fiches » indépendante de la fiche
                // (ne PAS écrire l.FicheCEE__c + '||' quand null : donnerait « null||… »).
                String key = String.isBlank(l.FicheCEE__c)
                    ? (ACOMPTE_ALL_FICHES + '||' + l.RoleIntervenant__c)
                    : (l.FicheCEE__c + '||' + l.RoleIntervenant__c);
                if (!acompteByKey.containsKey(key)) acompteByKey.put(key, new List<CatalogueTarifaire__c>());
                acompteByKey.get(key).add(l);
                Map<String, Object> parsed = parseParametres(l.ParametresFiche__c);
                // Toutes les conditions sont évaluées telles quelles (y compris la prise
                // en charge apporteur) : l'acompte n'est proposé que si une règle matche.
                parsedByCat.put(l.Id, parsed);
                collectFields(parsed, extraFields);
                // Champs dossier référencés par les gabarits de désignation ({dossier.X})
                // : à charger aussi pour les résoudre.
                collectDesignationDossierFields(parsed, extraFields);
                acompteCatIds.add(l.Id);
            }
        }
        if (acompteByKey.isEmpty()) return out;
        if (!extraFields.isEmpty()) loadDossierValuesBulk(dossierIds, extraFields, proFields, dvByDossier);

        // Anti-doublon : une ligne Acompte déjà consommée pour un dossier (une
        // LigneFacture liée à cette ligne catalogue existe) n'est plus proposée.
        Set<String> consumed = new Set<String>();
        Boolean hasCatField = LigneFacture__c.SObjectType.getDescribe()
            .fields.getMap().containsKey('catalogue_tarifaire__c');
        if (hasCatField && !acompteCatIds.isEmpty()) {
            for (LigneFacture__c lf : Database.query(
                'SELECT Dossier__c, Catalogue_tarifaire__c FROM LigneFacture__c ' +
                'WHERE Dossier__c IN :dossierIds AND Catalogue_tarifaire__c IN :acompteCatIds'
            )) {
                Object cat = lf.get('Catalogue_tarifaire__c');
                if (cat != null) consumed.add(String.valueOf(lf.Dossier__c) + '||' + String.valueOf(cat));
            }
        }

        Map<String, String> ficheLabels = new Map<String, String>();
        for (Schema.PicklistEntry pe : Pro__c.Fiche_CEE__c.getDescribe().getPicklistValues()) {
            ficheLabels.put(pe.getValue(), pe.getLabel());
        }

        Decimal taux = (tauxTVA == null) ? 0 : tauxTVA;
        String compteStr = String.valueOf(compteId);
        // Identité d'une proposition = (dossier + ligne catalogue Acompte) : une seule
        // proposition par couple, même si plusieurs lignes facturées y correspondent.
        Set<String> seen = new Set<String>();

        for (CompteLigneRow row : selected) {
            Map<String, Object> dv = dvByDossier.get(row.dossierId);
            if (dv == null) continue;
            String fiche = str(dv.get('Fiche_CEE__c'));
            Date ref = toDate(dv.get('Piste_Date_de_Cr_ation__c'));
            Map<String, Decimal> numericValues = toNumericMap(dv);

            // Lignes Acompte applicables = celles de la fiche du dossier + celles
            // « toutes fiches » (FicheCEE vide).
            List<CatalogueTarifaire__c> applicables = new List<CatalogueTarifaire__c>();
            List<CatalogueTarifaire__c> parFiche = acompteByKey.get(fiche + '||' + row.role);
            if (parFiche != null) applicables.addAll(parFiche);
            List<CatalogueTarifaire__c> toutesFiches = acompteByKey.get(ACOMPTE_ALL_FICHES + '||' + row.role);
            if (toutesFiches != null) applicables.addAll(toutesFiches);
            List<CatalogueTarifaire__c> cands = candidatesForDate(applicables, ref);
            if (cands.isEmpty()) continue;
            for (CatalogueTarifaire__c line : cands) {
                // Éligibilité intervenant : générique OU ciblant le compte courant.
                Set<String> comptesLigne = comptesDeLigne(line);
                if (!comptesLigne.isEmpty() && !comptesLigne.contains(compteStr)) continue;
                String identite = String.valueOf(row.dossierId) + '||' + String.valueOf(line.Id);
                if (consumed.contains(identite) || seen.contains(identite)) continue; // déjà consommée/proposée
                seen.add(identite);
                // Évaluation des règles (montant catalogue). Cascade sur les champs de
                // progression 1/2 (Porte, Déplacement) : un dossier « Porte 2 » réalise
                // aussi l'acompte conditionné sur « Porte 1 ».
                LineEval ev = new LineEval();
                evaluateLine(parsedByCat.get(line.Id), dv, numericValues, ev, ACOMPTE_CASCADE_FIELDS);
                if (!ev.ruleMatched) continue;
                Decimal ht = ev.com1;
                if (ht == null || ht <= 0) continue;

                AcompteProposition p = new AcompteProposition();
                p.key = row.dossierId + '||ACPT:' + line.Id; // identité (dossier + ligne catalogue)
                p.rowKey = row.key;
                p.dossierId = row.dossierId;
                p.dossierName = row.dossierName;
                p.ficheCee = ficheLabels.containsKey(fiche) ? ficheLabels.get(fiche) : fiche;
                p.role = row.role;
                p.catalogueId = line.Id;
                // Désignation : gabarit de la règle résolu (champs dossier/catalogue),
                // sinon repli sur le texte statique historique.
                p.designation = resolveDesignation(ev.designationTemplate, dv, line);
                p.montantHT = ht.setScale(2);
                p.tauxTVA = taux;
                // TVA/TTC calculés depuis le HT ARRONDI -> cohérents avec les VR Facture.
                p.montantTVA = (p.montantHT * taux / 100).setScale(2);
                p.montantTTC = (p.montantHT + p.montantTVA).setScale(2);
                out.add(p);
            }
        }
        return out;
    }

    // Id du Record Type « Acompte » de Facture__c (null s'il n'existe pas).
    private static Id factureAcompteRtId() {
        Schema.RecordTypeInfo rti = Facture__c.SObjectType.getDescribe()
            .getRecordTypeInfosByDeveloperName().get(RT_ACOMPTE);
        return rti == null ? null : rti.getRecordTypeId();
    }

    /**
     * Crée les factures d'acompte (RT Facture « Acompte », statut Validé) à partir
     * des propositions catalogue cochées. Montants RECALCULÉS côté serveur (jamais
     * confiance au client). HT/TVA/TTC cohérents avec les VR Facture ; un N° de
     * facture externe est requis (obligatoire hors Brouillon). Renvoie les Ids créés.
     */
    private static List<Id> creerFacturesAcompte(
        Id compteId, Map<String, Object> factureFields,
        List<Map<String, Object>> selections, List<Map<String, Object>> acomptesCatalogue
    ) {
        List<Id> out = new List<Id>();
        if (acomptesCatalogue == null || acomptesCatalogue.isEmpty()) return out;

        // Clés des lignes sélectionnées -> recalcul autoritaire des propositions.
        List<String> selKeys = new List<String>();
        if (selections != null) {
            for (Map<String, Object> sel : selections) {
                if (sel == null) continue;
                String sk = str(sel.get('rowKey'));
                if (String.isBlank(sk)) sk = str(sel.get('key'));
                if (String.isNotBlank(sk)) selKeys.add(sk);
            }
        }
        Object tauxRaw = (factureFields == null) ? null : factureFields.get('Taux_TVA__c');
        Decimal taux = toDecimal(tauxRaw);

        Map<String, AcompteProposition> propByKey = new Map<String, AcompteProposition>();
        for (AcompteProposition p : getPropositionsAcompte(compteId, selKeys, taux)) {
            propByKey.put(p.key, p);
        }

        Id acompteRt = factureAcompteRtId();
        if (acompteRt == null) {
            throw new AuraHandledException('Le Record Type « Acompte » est introuvable sur la facture.');
        }

        List<Facture__c> toInsert = new List<Facture__c>();
        List<AcompteProposition> propsForInsert = new List<AcompteProposition>();
        Set<String> seenAcKeys = new Set<String>(); // anti-doublon intra-envoi (jamais confiance au client)
        for (Map<String, Object> ac : acomptesCatalogue) {
            if (ac == null) continue;
            String acKey = str(ac.get('key'));
            if (String.isBlank(acKey) || !seenAcKeys.add(acKey)) continue; // clé vide ou déjà traitée
            AcompteProposition p = propByKey.get(acKey);
            if (p == null) {
                throw new AuraHandledException(
                    'Une facture d\'acompte sélectionnée n\'est plus applicable (déjà consommée ?). ' +
                    'Veuillez recharger l\'écran.');
            }
            String numero = str(ac.get('numero'));
            if (String.isBlank(numero)) {
                throw new AuraHandledException(
                    'Le N° de facture externe est requis pour l\'acompte « ' + p.role +
                    ' » du dossier « ' + p.dossierName + ' ».');
            }
            Facture__c f = new Facture__c();
            f.RecordTypeId = acompteRt;
            f.Destinataire_Compte__c = compteId;
            f.MontantHT__c = p.montantHT;
            if (tauxRaw != null) f.put('Taux_TVA__c', tauxRaw);
            f.MontantTVA__c = p.montantTVA;
            f.Montant_Total__c = p.montantTTC;
            f.N_Facture_Externe__c = numero;
            f.DateFacture__c = Date.today();
            f.Statut__c = 'Validé';
            f.Designation__c = (p.designation != null) ? p.designation : ACOMPTE_DESIGNATION;
            toInsert.add(f);
            propsForInsert.add(p);
        }
        if (!toInsert.isEmpty()) {
            insert toInsert;
            // Marqueur de consommation : 1 LigneFacture par acompte, liée au dossier +
            // à la ligne catalogue Acompte (Catalogue_tarifaire__c) -> empêche de
            // re-facturer le même couple (dossier + ligne catalogue) une 2e fois.
            // Liée à la facture d'acompte (Validé) -> non réutilisable à l'écran 1.
            Boolean hasCatField = LigneFacture__c.SObjectType.getDescribe()
                .fields.getMap().containsKey('catalogue_tarifaire__c');
            List<LigneFacture__c> markers = new List<LigneFacture__c>();
            for (Integer i = 0; i < toInsert.size(); i++) {
                Facture__c f = toInsert[i];
                AcompteProposition p = propsForInsert[i];
                out.add(f.Id);
                LigneFacture__c lf = new LigneFacture__c();
                lf.Dossier__c = p.dossierId;
                lf.Type_Intervenant__c = p.role;
                lf.Montant_HT__c = p.montantHT;
                lf.Intervenant_Compte__c = compteId;
                lf.Facture__c = f.Id;
                lf.Commentaire__c = (p.designation != null) ? p.designation : ACOMPTE_DESIGNATION;
                if (hasCatField && p.catalogueId != null) lf.put('Catalogue_tarifaire__c', p.catalogueId);
                markers.add(lf);
            }
            if (!markers.isEmpty()) insert markers;
        }
        dbg('Factures d\'acompte créées : ' + out.size());
        return out;
    }

    // ===================================================== Point d'entrée — écriture

    /**
     * Crée en UNE transaction atomique la facture Classique + les lignes à créer,
     * et rattache les lignes (créées + existantes sélectionnées) à la facture.
     * Le tout est annulé (rollback) à la moindre erreur.
     *
     * @param compteId          bénéficiaire (compte courant), fait foi
     * @param factureFields     valeurs du FieldSet Classique saisies au wizard
     * @param selections        lignes choisies (clé + type + montant saisi éventuel)
     * @param acompteIds        acomptes (avances) EXISTANTS à rattacher
     * @param acomptesCatalogue propositions d'acompte (catalogue) cochées à CRÉER
     *                          puis rattacher : chaque map = { key, numero }
     * @return Id de la facture créée
     */
    @AuraEnabled
    public static Id creerFactureDepuisCompte(
        Id compteId,
        Map<String, Object> factureFields,
        List<Map<String, Object>> selections,
        List<Id> acompteIds,
        List<Map<String, Object>> acomptesCatalogue
    ) {
        if (compteId == null) throw new AuraHandledException('Compte requis');
        if (selections == null || selections.isEmpty()) {
            throw new AuraHandledException('Aucune ligne sélectionnée.');
        }

        System.Savepoint sp = Database.setSavepoint();
        try {
            // Recalcul AUTORITAIRE : on ne fait jamais confiance au client pour le
            // montant, le statut « atteinte » ou l'éligibilité d'une ligne.
            CompteFacturationResult auth = getCompteFacturation(compteId);
            Map<String, CompteLigneRow> byKey = new Map<String, CompteLigneRow>();
            for (CompteLigneRow r : auth.rows) byKey.put(r.key, r);
            dbg('creerFactureDepuisCompte — ' + selections.size() + ' sélection(s) ; ' +
                byKey.size() + ' ligne(s) autoritaire(s) recalculée(s)');

            List<Id> ligneIds = new List<Id>();
            List<PendingLine> pending = new List<PendingLine>();

            for (Map<String, Object> sel : selections) {
                if (sel == null) { dbg('  sélection ignorée (null)'); continue; }
                // Lecture par clé (Map) : insensible aux problèmes de désérialisation
                // d'une classe typée. Repli sur l'ancien nom « key ».
                String selKey = str(sel.get('rowKey'));
                if (String.isBlank(selKey)) selKey = str(sel.get('key'));
                if (String.isBlank(selKey)) {
                    dbg('  sélection ignorée (clé vide) : ' + sel);
                    continue;
                }
                CompteLigneRow r = byKey.get(selKey);
                dbg('  sélection "' + selKey + '" -> ' +
                    (r == null ? 'INTROUVABLE dans le recalcul' : ('status=' + r.status + ' selectable=' + r.selectable)));
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
                        String ref = r.isSupplementaire ? str(r.echeance) : ('échéance ' + r.numEcheance);
                        throw new AuraHandledException(
                            'Montant invalide pour « ' + r.role + ' » (' + ref + ').');
                    }
                    PendingLine p = new PendingLine();
                    p.dossierId = r.dossierId;
                    p.role = r.role;
                    p.num = r.numEcheance;
                    p.echeance = r.echeance;
                    p.montant = montant;
                    p.catalogueId = r.catalogueId;
                    p.isSupp = (r.isSupplementaire == true);
                    pending.add(p);
                } else if (r.status == STATUS_CREEE || r.status == STATUS_INDISPONIBLE) {
                    // Garde-fou (course) : ligne déjà créée pour ce dossier + ligne
                    // catalogue -> non recréable.
                    throw new AuraHandledException(
                        'La ligne « ' + r.role + (r.isSupplementaire ? ' / ' + str(r.echeance) : '') +
                        ' » est déjà créée : impossible de la recréer.');
                } else {
                    throw new AuraHandledException(
                        'L\'échéance n\'est pas atteinte pour « ' + r.role + ' » : impossible de facturer.');
                }
            }

            dbg('Bilan sélections : à créer=' + pending.size() + ', existantes réutilisées=' + ligneIds.size());

            // Création en masse des lignes à créer (1 insert).
            ligneIds.addAll(createLignesBulk(compteId, pending));

            if (ligneIds.isEmpty()) {
                throw new AuraHandledException('Aucune ligne valide à facturer.');
            }

            List<Id> acomptes = (acompteIds == null) ? new List<Id>() : new List<Id>(acompteIds);

            // --- Factures d'acompte (catalogue) : créées (RT Acompte, Validé) puis
            //     ajoutées aux acomptes -> FacturesController les rattache et déduit
            //     (la cohérence Σ lignes == HT Classique + Σ acomptes les inclut).
            acomptes.addAll(creerFacturesAcompte(compteId, factureFields, selections, acomptesCatalogue));

            // Montants (HT/TVA/TTC) SAISIS par l'utilisateur : transmis tels quels.
            // FacturesController.createFactureAvecLignes vérifie la cohérence
            // Σ lignes == HT + acomptes, et les règles de validation la cohérence
            // HT/TVA/TTC -> rollback sinon. On force uniquement le Record Type
            // (Classique) et le bénéficiaire (compte courant).
            Map<String, Object> fields = (factureFields == null)
                ? new Map<String, Object>()
                : new Map<String, Object>(factureFields);
            fields.put('RecordTypeId', classiqueRtId());
            fields.put('Destinataire_Compte__c', String.valueOf(compteId));
            dbg('Facture (montants saisis) : HT=' + fields.get('MontantHT__c') +
                ' TVA=' + fields.get('MontantTVA__c') + ' TTC=' + fields.get('Montant_Total__c'));

            Id factureId = FacturesController.createFactureAvecLignes(fields, ligneIds, acomptes);
            dbg('Facture créée : ' + factureId + ' avec ' + ligneIds.size() + ' ligne(s) rattachée(s)');
            return factureId;

        } catch (AuraHandledException ahe) {
            dbg('ERREUR (AuraHandledException) : ' + ahe.getMessage() + ' -> rollback');
            Database.rollback(sp);
            throw ahe;
        } catch (Exception e) {
            dbg('ERREUR (Exception) : ' + e.getMessage() + ' -> rollback');
            Database.rollback(sp);
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ===================================================== Résolution inverse

    /**
     * Utilisateurs rattachés au compte, par la CHAÎNE RÉELLE :
     *   Dossier.<rôle User>  ->  User.ContactId  ->  Contact.AccountId = compte.
     * On la parcourt en sens inverse, EN DEUX TEMPS (compte -> ses Contacts ->
     * leurs Users) : filtrer directement « User WHERE Contact.AccountId = :compte »
     * (relation à deux niveaux depuis User) n'est pas fiable en SOQL et renvoyait
     * vide. Repli : utilisateur portail relié directement au compte (User.AccountId).
     */
    private static Set<Id> usersForCompte(Id compteId) {
        Set<Id> out = new Set<Id>();

        Set<Id> contactIds = new Set<Id>();
        for (Contact c : [SELECT Id FROM Contact WHERE AccountId = :compteId]) contactIds.add(c.Id);
        dbg('usersForCompte — contacts du compte : ' + contactIds.size() + ' -> ' + contactIds);

        if (!contactIds.isEmpty()) {
            for (User u : [SELECT Id FROM User WHERE ContactId IN :contactIds]) out.add(u.Id);
        }
        dbg('usersForCompte — utilisateurs via contacts : ' + out.size());

        Integer avant = out.size();
        for (User u : [SELECT Id FROM User WHERE AccountId = :compteId]) out.add(u.Id);
        if (out.size() > avant) dbg('usersForCompte — +' + (out.size() - avant) + ' via User.AccountId');

        dbg('usersForCompte — TOTAL : ' + out.size() + ' utilisateur(s) -> ' + out);
        return out;
    }

    /**
     * Campagnes dont ce compte est une « régie » (Campaign.Compte_Regie__r).
     * Le champ lookup Account->Campaign est résolu par describe (relation enfant
     * « Compte_Regie » côté Campaign) pour ne rien coder en dur.
     */
    private static Set<Id> campaignsForCompte(Id compteId) {
        Set<Id> out = new Set<Id>();
        String accCampaignField = null;
        for (Schema.ChildRelationship cr : Campaign.SObjectType.getDescribe().getChildRelationships()) {
            if (cr.getChildSObject() != Account.SObjectType || cr.getField() == null) continue;
            // Pour une relation CUSTOM, getRelationshipName() renvoie le nom AVEC le
            // suffixe « __r » (Compte_Regie__r) ; on normalise pour matcher dans les
            // deux cas (sinon la résolution inverse Compte->Campagne échoue).
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

    /**
     * Choisit la ligne catalogue applicable : priorité à une ligne « spécifique »
     * dont l'ensemble Intervenants__c contient le compte ; sinon ligne générique.
     * Le compte est connu (point d'entrée), aucune requête nécessaire.
     */
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
        // Sans cascade (comportement Standard : égalité stricte sur toutes les conditions).
        evaluateLine(parsed, dv, numericValues, e, null);
    }

    // cascadeFields : champs dont la condition exacte est évaluée en CASCADE « 1/2 »
    // (niveau atteint >= niveau requis) au lieu de l'égalité stricte. null/vide = aucune
    // cascade. Utilisé par l'Acompte (paliers Porte/Déplacement) ; le Standard passe null.
    private static void evaluateLine(
        Map<String, Object> parsed, Map<String, Object> dv,
        Map<String, Decimal> numericValues, LineEval e, Set<String> cascadeFields
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
            if (ruleMatches(conditions, typeByField, dv, cascadeFields)) {
                e.ruleMatched = true;
                e.commentaire = str(rule.get('commentaire'));
                e.designationTemplate = str(rule.get('designation'));
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

    private static Boolean ruleMatches(
        Map<String, Object> conditions, Map<String, String> typeByField,
        Map<String, Object> dv, Set<String> cascadeFields
    ) {
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
                // Cascade « 1/2 » pour les champs de progression (Acompte) : le niveau du
                // dossier doit être >= au niveau requis (Porte 2 satisfait la condition Porte 1).
                if (cascadeFields != null && cascadeFields.contains(field)) {
                    if (!niveauCascadeAtteint(str(dval), str(cval))) return false;
                } else if (!matchExact(type, dval, cval)) {
                    return false;
                }
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

    // Couverture ciblée des opérateurs ensemblistes (in / notIn) de ruleMatches,
    // en mémoire — indépendante des données de l'org. Appelée uniquement par les tests.
    @TestVisible
    private static void coverSetOperators() {
        Map<String, String> types = new Map<String, String>{ 'p' => 'picklist' };
        Map<String, Object> inCond = new Map<String, Object>{
            'p' => new Map<String, Object>{ 'comparison' => 'in', 'values' => new List<Object>{ 'A', 'B' } }
        };
        ruleMatches(inCond, types, new Map<String, Object>{ 'p' => 'A' }, null); // in -> matche
        ruleMatches(inCond, types, new Map<String, Object>{ 'p' => 'Z' }, null); // in -> ne matche pas
        Map<String, Object> notInCond = new Map<String, Object>{
            'p' => new Map<String, Object>{ 'comparison' => 'notIn', 'values' => new List<Object>{ 'Z' } }
        };
        ruleMatches(notInCond, types, new Map<String, Object>{ 'p' => 'Z' }, null); // notIn -> exclu -> ne matche pas
        ruleMatches(notInCond, types, new Map<String, Object>{ 'p' => 'A' }, null); // notIn -> matche
        ruleMatches(notInCond, types, new Map<String, Object>(), null); // notIn + dossier vide -> matche
        Map<String, Object> emptyCond = new Map<String, Object>{
            'p' => new Map<String, Object>{ 'comparison' => 'in', 'values' => new List<Object>() }
        };
        ruleMatches(emptyCond, types, new Map<String, Object>{ 'p' => 'A' }, null); // liste vide -> aucune contrainte
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

    // -------------------------------------------------- Échéances Supplémentaire
    /**
     * Réalisation d'une échéance « Supplémentaire » (RT distinct ; le montant n'entre
     * PAS dans la décision). Échéances gérées :
     *  - Porte 1 : PREVISITE_PORTE__c ∈ {⬛Porte 1, ⬛Porte 2}
     *  - Porte 2 : PREVISITE_PORTE__c = ⬛Porte 2
     *    (cascade : Porte 2 atteinte ⟹ Porte 1 atteinte).
     *  - Frais Déplacement 1/2 : INSTALLATION_Deplacement__c, même cascade que les
     *    portes (Déplacement 2 atteint ⟹ Déplacement 1 atteint).
     *  - Supplément Installation : INSTALLATION_Frais_Supplementaire__c > 0
     *    (indépendante des portes / du déplacement).
     * Extensible : ajouter ici d'autres échéances/fiches au besoin.
     */
    private static Boolean isEcheanceSuppReached(String echeanceLabel, Map<String, Object> dv) {
        if (String.isBlank(echeanceLabel)) return false;
        String lower = echeanceLabel.toLowerCase();

        // Supplément Installation : frais supplémentaires d'installation > 0. Testé AVANT
        // les cascades (qui renvoient false si leur champ pilote est vide).
        if (lower.contains('install')) {
            Decimal frais = toDecimal(dv.get(SUPP_INSTALL_FIELD));
            return frais != null && frais > 0;
        }

        // Frais Déplacement 1 / 2 (INSTALLATION_Deplacement__c) — même cascade « 1/2 »
        // que les portes. « déplacement » contient « placement » (robuste à l'accent).
        if (lower.contains('placement')) {
            return niveauCascadeAtteint(str(dv.get(SUPP_DEPLACEMENT_FIELD)), echeanceLabel);
        }

        // Porte 1 / Porte 2 (PREVISITE_PORTE__c).
        return niveauCascadeAtteint(str(dv.get(SUPP_PORTE_FIELD)), echeanceLabel);
    }

    // Cascade « niveau 1/2 » : l'échéance cible est atteinte selon la valeur courante du
    // champ pilote. Niveau 1 atteint si le courant ∈ {1, 2} (cascade), niveau 2 atteint
    // seulement si le courant = 2. Renvoie false si la valeur courante est vide/inconnue.
    private static Boolean niveauCascadeAtteint(String valeurCourante, String echeanceLabel) {
        String courant = niveauNum(valeurCourante);
        if (courant == null) return false;
        String cible = niveauNum(echeanceLabel);
        if (cible == '1') return courant == '1' || courant == '2';
        if (cible == '2') return courant == '2';
        return false;
    }

    // Niveau « 1 / 2 » porté par un libellé, robuste au préfixe « ⬛ » et à la casse
    // (« Porte 1 », « ⬛Porte 2 », « ⬛Frais Déplacement 2 »…). null si non reconnu.
    private static String niveauNum(String s) {
        if (String.isBlank(s)) return null;
        if (s.contains('2')) return '2';
        if (s.contains('1')) return '1';
        return null;
    }

    // Choisit, par valeur d'échéance (echeanceSupp__c), la ligne catalogue
    // Supplémentaire applicable (priorité spécifique > générique, comme selectLine).
    private static Map<String, CatalogueTarifaire__c> pickSuppLinesByEcheance(
        List<CatalogueTarifaire__c> cands, Id compteId
    ) {
        Map<String, List<CatalogueTarifaire__c>> byEch = new Map<String, List<CatalogueTarifaire__c>>();
        if (cands != null) {
            for (CatalogueTarifaire__c l : cands) {
                String ech = str(l.get('echeanceSupp__c'));
                if (String.isBlank(ech)) continue; // ligne Supplémentaire sans échéance : ignorée
                if (!byEch.containsKey(ech)) byEch.put(ech, new List<CatalogueTarifaire__c>());
                byEch.get(ech).add(l);
            }
        }
        Map<String, CatalogueTarifaire__c> out = new Map<String, CatalogueTarifaire__c>();
        for (String ech : byEch.keySet()) {
            CatalogueTarifaire__c sel = selectLine(byEch.get(ech), compteId);
            if (sel != null) out.put(ech, sel);
        }
        return out;
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

    // Clé d'identité d'une LigneFacture, unifiée Standard / Supplémentaire :
    //  - Standard      : dossier||rôle||<N° échéance (1/2)>
    //  - Supplémentaire : dossier||rôle||S:<libellé échéance>  (Numero_Echeance__c vide)
    // Les deux espaces ne se chevauchent pas (« 1 »/« 2 » vs « S:Porte 1 »).
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
            // Ligne liée à une facture : on expose le statut de la facture.
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
        r.isSupplementaire = String.isBlank(ex.Numero_Echeance__c);
        applyExisting(r, ex);
        if (r.isSupplementaire) {
            // Supplémentaire : non réutilisable -> « Créée » (ou statut facture si liée).
            r.selectable = false;
            r.status = (ex.Facture__c != null) ? STATUS_INDISPONIBLE : STATUS_CREEE;
        }
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

        // Anti-doublon en 1 requête. Identité Supplémentaire = (dossier + ligne
        // catalogue) via Catalogue_tarifaire__c (indépendante du libellé d'échéance) ;
        // Standard = lineFactureKey (rôle + N° d'échéance).
        Set<String> existingKeys = new Set<String>();
        String catSel = hasCatField ? ', Catalogue_tarifaire__c' : '';
        for (LigneFacture__c lf : Database.query(
            'SELECT Dossier__c, Type_Intervenant__c, Numero_Echeance__c, Echeance_Declenchante__c' +
            catSel + ' FROM LigneFacture__c WHERE Dossier__c IN :dossierIds'
        )) {
            existingKeys.add(lineFactureKey(lf));
            if (hasCatField) {
                Object cat = lf.get('Catalogue_tarifaire__c');
                if (cat != null) existingKeys.add(lf.Dossier__c + '||CAT:' + cat);
            }
        }

        List<LigneFacture__c> toInsert = new List<LigneFacture__c>();
        for (PendingLine p : pending) {
            // Clé de doublon : Supplémentaire = (dossier + ligne catalogue), repli sur
            // l'échéance si le champ catalogue est absent ; Standard = N° d'échéance.
            String dupKey;
            if (p.isSupp) {
                dupKey = (hasCatField && p.catalogueId != null)
                    ? (p.dossierId + '||CAT:' + p.catalogueId)
                    : (p.dossierId + '||' + p.role + '||S:' + str(p.echeance));
            } else {
                dupKey = p.dossierId + '||' + p.role + '||' + String.valueOf(p.num);
            }
            if (existingKeys.contains(dupKey)) {
                String ref = p.isSupp ? str(p.echeance) : ('échéance ' + p.num);
                throw new AuraHandledException(
                    'Une ligne existe déjà pour « ' + p.role + ' » (' + ref +
                    ') sur ce dossier. Veuillez recharger l\'écran.');
            }
            // Évite aussi un doublon au sein du même envoi.
            existingKeys.add(dupKey);

            Pro__c d = dossiers.get(p.dossierId);
            LigneFacture__c lf = new LigneFacture__c();
            lf.Dossier__c = p.dossierId;
            lf.Montant_HT__c = p.montant;
            // Supplémentaire : pas de N° d'échéance (l'échéance « Porte » fait foi) ;
            // Standard : N° 1/2.
            if (!p.isSupp) lf.Numero_Echeance__c = String.valueOf(p.num);
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

        // Réécriture des commissions sur le dossier (aligné sur la Facturation V2,
        // writeComToDossier) : chaque montant facturé est recopié dans le champ
        // com1/com2 du rôle. Exécuté dans la transaction (savepoint) de
        // creerFactureDepuisCompte -> annulé si la facture échoue. Le Supplémentaire
        // est ignoré (montant unique, pas de com1/com2).
        ecrireCommissionsSurDossiers(pending);
        return out;
    }

    /**
     * Recopie les commissions facturées sur les dossiers (champ com1/com2 du rôle),
     * comme la Facturation V2 (writeComToDossier). Une seule MAJ par dossier (rôles
     * et échéances fusionnés). Le Supplémentaire est ignoré (montant unique, pas de
     * com1/com2). Les champs absents de l'org sont ignorés (défensif).
     */
    private static void ecrireCommissionsSurDossiers(List<PendingLine> pending) {
        if (pending == null || pending.isEmpty()) return;
        Map<String, Cfg> roleToCfg = new Map<String, Cfg>();
        for (Cfg c : buildConfig()) roleToCfg.put(c.role, c);
        Map<String, SObjectField> proFields = Pro__c.SObjectType.getDescribe().fields.getMap();

        Map<Id, Pro__c> majParDossier = new Map<Id, Pro__c>();
        for (PendingLine p : pending) {
            if (p.isSupp || p.dossierId == null) continue; // pas de com1/com2 pour le Supplémentaire
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

    // --------------------------------------------- Désignation Acompte (gabarit texte)

    // Champs DOSSIER référencés par les gabarits de désignation ({dossier.X}) de toutes
    // les règles : à charger dans dv pour être résolus. (Les {catalogue.X} viennent de
    // la ligne catalogue, pas du dossier.)
    private static void collectDesignationDossierFields(Map<String, Object> parsed, Set<String> out) {
        if (parsed == null) return;
        Object rules = parsed.get('rules');
        if (!(rules instanceof List<Object>)) return;
        for (Object ro : (List<Object>) rules) {
            if (!(ro instanceof Map<String, Object>)) continue;
            Object d = ((Map<String, Object>) ro).get('designation');
            if (!(d instanceof String)) continue;
            Matcher mt = Pattern.compile('\\{dossier\\.([A-Za-z0-9_]+)\\}').matcher((String) d);
            while (mt.find()) out.add(mt.group(1));
        }
    }

    // Résout un gabarit de désignation : remplace {dossier.X} par la valeur du dossier,
    // {catalogue.X} par la valeur de la ligne catalogue. Gabarit vide -> repli sur le
    // texte statique historique (comportement préservé). Un champ inconnu/non chargé ->
    // remplacé par une chaîne vide (jamais d'erreur).
    private static String resolveDesignation(String template, Map<String, Object> dv, CatalogueTarifaire__c line) {
        if (String.isBlank(template)) return ACOMPTE_DESIGNATION;
        Matcher mt = Pattern.compile('\\{(dossier|catalogue)\\.([A-Za-z0-9_]+)\\}').matcher(template);
        Map<String, String> repl = new Map<String, String>();
        while (mt.find()) {
            String whole = mt.group(0);
            if (repl.containsKey(whole)) continue;
            String src = mt.group(1);
            String field = mt.group(2);
            String val = '';
            if (src == 'dossier') {
                val = str(dv == null ? null : dv.get(field));
            } else {
                try {
                    Object o = (line == null) ? null : line.get(field);
                    val = (o == null) ? '' : String.valueOf(o);
                } catch (Exception e) {
                    val = ''; // champ catalogue non requêté : ignoré silencieusement
                }
            }
            repl.put(whole, val == null ? '' : val);
        }
        String out = template;
        for (String whole : repl.keySet()) {
            out = out.replace(whole, repl.get(whole));
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

    // Tracé décoré (visible dans les logs Apex en niveau DEBUG/INFO).
    private static void dbg(String msg) {
        System.debug('🟩 [LC023-Facturation] ' + msg);
    }
}