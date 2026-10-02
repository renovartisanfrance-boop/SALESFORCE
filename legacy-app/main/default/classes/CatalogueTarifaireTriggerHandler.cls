/**
 * Trigger handler du Catalogue Tarifaire (objet CatalogueTarifaire__c).
 *
 * Règle d'unicité / non-chevauchement : on ne peut pas avoir deux lignes ACTIVE
 * partageant la même clé (Fiche CEE + Rôle Intervenant + Intervenant) avec des
 * périodes de validité qui se recoupent (mêmes dates ou chevauchement).
 *  - Intervenant null == null : deux lignes génériques se chevauchent entre elles.
 *  - Une ligne générique (Intervenant vide) et une ligne spécifique (Intervenant
 *    renseigné) ont des clés différentes : pas de chevauchement.
 *  - Seules les lignes ACTIVE sont contraintes (les Inactive/Archivée cohabitent).
 *
 * La logique de détection est exposée en statique (premierChevauchement) pour être
 * réutilisée par le contrôleur LWC (vérification avant l'écran suivant du formulaire).
 */
public class CatalogueTarifaireTriggerHandler extends TriggerHandler {

    private List<CatalogueTarifaire__c> newList;

    private static final String STATUT_ACTIVE = 'Active';

    public CatalogueTarifaireTriggerHandler() {
        this.newList = (List<CatalogueTarifaire__c>) Trigger.new;
    }

    protected override void beforeInsert() {
        bloquerChevauchements();
    }

    protected override void beforeUpdate() {
        bloquerChevauchements();
    }

    // ------------------------------------------------------- Garde-fou (bulk)

    private void bloquerChevauchements() {
        // Ce contrôle est la règle STANDARD (Fiche + rôle + intervenant). Les types
        // Supplémentaire et Acompte en sont exemptés (ni bloqués, ni bloqueurs) : ils
        // ont leur propre logique (l'Acompte aura sa règle Fiche facultative +
        // intervenant + période, traitée à part).
        Set<Id> exemptIds = exemptStandardRtIds();

        // 1) Lignes ACTIVE à contrôler + clés (fiche, rôle) pour la requête.
        List<CatalogueTarifaire__c> actives = new List<CatalogueTarifaire__c>();
        Set<String> fiches = new Set<String>();
        Set<String> roles = new Set<String>();
        Set<Id> currentIds = new Set<Id>();
        for (CatalogueTarifaire__c c : newList) {
            if (c.Id != null) currentIds.add(c.Id);
            if (c.Statut__c != STATUT_ACTIVE) continue;
            // Types Supplémentaire / Acompte : non soumis à la règle Standard.
            if (exemptIds.contains(c.RecordTypeId)) continue;
            if (String.isBlank(c.FicheCEE__c) || String.isBlank(c.RoleIntervenant__c)) continue;
            actives.add(c);
            fiches.add(c.FicheCEE__c);
            roles.add(c.RoleIntervenant__c);
        }
        if (actives.isEmpty()) return;

        // 2) Lignes ACTIVE existantes candidates (même fiche + rôle), hors lignes du batch.
        List<CatalogueTarifaire__c> existantes = [
            SELECT Id, Name, RecordTypeId, FicheCEE__c, RoleIntervenant__c, Intervenants__c,
                   DateDebutValidite__c, DateFinValidite__c, Paiement__c
            FROM CatalogueTarifaire__c
            WHERE Statut__c = :STATUT_ACTIVE
              AND FicheCEE__c IN :fiches
              AND RoleIntervenant__c IN :roles
              AND Id NOT IN :currentIds
        ];

        // 3) Comparaison : chaque ligne vs existantes en base, puis vs les autres
        //    lignes ACTIVE du même batch (création/màj multiple).
        for (Integer i = 0; i < actives.size(); i++) {
            CatalogueTarifaire__c c = actives[i];
            CatalogueTarifaire__c conflit = null;

            for (CatalogueTarifaire__c e : existantes) {
                // Une ligne Supplémentaire / Acompte existante ne crée pas de chevauchement Standard.
                if (exemptIds.contains(e.RecordTypeId)) continue;
                if (memeCleEtChevauche(c, e)) { conflit = e; break; }
            }
            if (conflit == null) {
                for (Integer j = 0; j < actives.size(); j++) {
                    if (j == i) continue;
                    if (memeCleEtChevauche(c, actives[j])) { conflit = actives[j]; break; }
                }
            }
            if (conflit != null) {
                c.addError(messageConflit(conflit));
            }
        }
    }

    // ------------------------------------------- Détection (réutilisable front)

    /**
     * Renvoie la 1re ligne ACTIVE en chevauchement avec le candidat décrit, ou null.
     * Utilisé par le contrôleur pour la vérification côté formulaire (avant l'écran
     * suivant), avec la même règle que le garde-fou du trigger.
     *
     * @param comptes  Ensemble des comptes ciblés par la ligne candidate (vide = générique).
     * @param excludeId Id de la ligne en cours d'édition (exclue), ou null en création.
     */
    public static CatalogueTarifaire__c premierChevauchement(
        String fiche, String role, Set<String> comptes, Date debut, Date fin, Id excludeId
    ) {
        if (String.isBlank(fiche) || String.isBlank(role)) return null;
        Set<String> candidat = (comptes == null) ? new Set<String>() : comptes;
        Set<Id> exclude = new Set<Id>();
        if (excludeId != null) exclude.add(excludeId);
        Set<Id> exemptIds = exemptStandardRtIds();
        for (CatalogueTarifaire__c e : [
            SELECT Id, Name, RecordTypeId, Intervenants__c, DateDebutValidite__c, DateFinValidite__c, Paiement__c
            FROM CatalogueTarifaire__c
            WHERE Statut__c = :STATUT_ACTIVE
              AND FicheCEE__c = :fiche
              AND RoleIntervenant__c = :role
              AND Id NOT IN :exclude
        ]) {
            // Types Supplémentaire / Acompte exemptés du chevauchement Standard.
            if (exemptIds.contains(e.RecordTypeId)) continue;
            if (comptesSeRecoupent(candidat, comptesDe(e))
                && periodesSeChevauchent(debut, fin, e.DateDebutValidite__c, e.DateFinValidite__c)) {
                return e;
            }
        }
        return null;
    }

    // Id d'un Record Type par DeveloperName (null s'il n'est pas déployé).
    private static Id recordTypeId(String devName) {
        Schema.RecordTypeInfo rti = CatalogueTarifaire__c.SObjectType.getDescribe()
            .getRecordTypeInfosByDeveloperName().get(devName);
        return rti == null ? null : rti.getRecordTypeId();
    }

    // Ids des Record Types EXEMPTÉS du chevauchement Standard : Supplémentaire (sa
    // propre identité dossier+ligne catalogue) et Acompte (sa propre règle : Fiche
    // facultative + intervenant + période). Le Standard ne se compare qu'au Standard.
    private static Set<Id> exemptStandardRtIds() {
        Set<Id> ids = new Set<Id>();
        for (String dev : new List<String>{ 'Supplementaire', 'Acompte' }) {
            Id rtId = recordTypeId(dev);
            if (rtId != null) ids.add(rtId);
        }
        return ids;
    }

    @TestVisible
    private static Boolean memeCleEtChevauche(CatalogueTarifaire__c a, CatalogueTarifaire__c b) {
        return a.FicheCEE__c == b.FicheCEE__c
            && a.RoleIntervenant__c == b.RoleIntervenant__c
            && comptesSeRecoupent(comptesDe(a), comptesDe(b))
            && periodesSeChevauchent(
                   a.DateDebutValidite__c, a.DateFinValidite__c,
                   b.DateDebutValidite__c, b.DateFinValidite__c);
    }

    // Ensemble des comptes ciblés par une ligne : IDs concaténés (« ; ») du champ
    // multi Intervenants__c. Vide = ligne générique.
    @TestVisible
    private static Set<String> comptesDe(CatalogueTarifaire__c c) {
        Set<String> s = new Set<String>();
        Object multi = (c == null) ? null : c.get('Intervenants__c');
        if (multi != null) {
            for (String part : String.valueOf(multi).split(';')) {
                String t = part.trim();
                if (String.isNotBlank(t)) s.add(t);
            }
        }
        return s;
    }

    // Deux lignes visent le même intervenant si elles PARTAGENT au moins un compte,
    // OU si elles sont toutes deux génériques (aucun compte).
    private static Boolean comptesSeRecoupent(Set<String> a, Set<String> b) {
        if (a.isEmpty() && b.isEmpty()) return true;
        for (String x : a) {
            if (b.contains(x)) return true;
        }
        return false;
    }

    // [d1,f1] et [d2,f2] se chevauchent ssi d1 <= f2 ET d2 <= f1.
    // Une borne nulle est traitée comme ouverte (début = -infini, fin = +infini).
    private static Boolean periodesSeChevauchent(Date d1, Date f1, Date d2, Date f2) {
        Boolean cond1 = (d1 == null || f2 == null || d1 <= f2);
        Boolean cond2 = (d2 == null || f1 == null || d2 <= f1);
        return cond1 && cond2;
    }

    private static String messageConflit(CatalogueTarifaire__c e) {
        String ref = (e != null && e.Name != null) ? ' « ' + e.Name + ' »' : '';
        return 'Chevauchement détecté : une ligne de catalogue ACTIVE' + ref
            + ' existe déjà pour la même Fiche CEE, le même Rôle Intervenant et le même '
            + 'Intervenant, sur une période de validité qui se recoupe. Ajustez les dates, '
            + 'changez le statut, ou désactivez la ligne existante.';
    }
}