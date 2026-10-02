/**
 * Fournit les données du composant LWC previsiteurParCp (onglet « Prévisiteurs par CP »).
 *
 * PRÉVISITEURS — Campagnes (Campaign) de Role (Role__c) = « Pre-visiteur »
 * (LC027_Roles.PREVISITEUR) dont le contrat est signé (StatutContrat__c) : les autres ne
 * sont pas proposés. Leur téléphone n'est pas transmis au composant. Leurs provinces viennent de « Contrat - Provinces »
 * (Contrat_Provinces__c), saisi dans le formulaire de contrat du portail Gestion Prévisites.
 *
 * ACTION RAPIDE sur Piste (Lead) et Dossiers (Pro__c) — getContexte() préremplit le code
 * postal de la fiche (Lead.PostalCode, Pro__c.CodePostal__c) ; il n'est jamais réécrit.
 * attribuer() renseigne le prévisiteur de la fiche : LOOKUP- Previsiteur (Lead.LOOKUP_Previsiteur__c)
 * ou LOOKUP- Pré-visiteur (Pro__c.LOOKUP_Pre_visiteur__c). Ces lookups visent le COMPTE
 * du prévisiteur (Account.Acces_REGIE__c = sa Campagne, nom « PREVISITEUR- … » imposé par
 * leur filtre de recherche), pas la Campagne.
 *
 * PROVINCES — objet « Province » (Province__c) : code (2 premiers chiffres du code postal),
 * coordonnées du chef-lieu, provinces adjacentes, orthographes reconnues. Modifiables
 * depuis la modale du composant, par les seuls utilisateurs « Modifier toutes les données ».
 *
 * Contrat attendu par le composant pour un prévisiteur (ne pas changer les noms) :
 *   id     : Id de la Campagne
 *   nom    : nom de la Campagne (affiché et copié par le bouton « Copier »)
 *   mail   : Email (Email__c)
 *   zones  : codes province à 2 chiffres, déduits de Contrat_Provinces__c via Province__c
 *   actif  : Campagne active (le contrat est toujours signé) — mêmes conditions que
 *            l'accès au portail Gestion Prévisites (LC027_DossiersPrevisite)
 *   dispo  : volume de prévisites accepté (NombrePrevisites__c)
 *
 * PARTAGE — without sharing : les utilisateurs du portail business saas (licence partenaire,
 * profil Confirmateur) ne voient ni les Campagnes ni les Comptes des prévisiteurs, ni
 * Province__c. En contrepartie, getContexte() et attribuer() vérifient explicitement
 * (UserRecordAccess) que l'utilisateur peut lire / modifier la fiche visée, et
 * enregistrerProvinces() reste réservé aux administrateurs.
 */
public without sharing class PrevisiteurCpController {

    public class PrevisiteurDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String nom;
        @AuraEnabled public String mail;
        @AuraEnabled public List<String> zones;
        @AuraEnabled public Boolean actif;
        @AuraEnabled public String dispo;
        /** Compte « PREVISITEUR- … » rattaché à la Campagne ; null = attribution impossible. */
        @AuraEnabled public String compteId;
    }

    public class ContexteDTO {
        @AuraEnabled public String codePostal;
        @AuraEnabled public String compteActuelId;
        @AuraEnabled public String compteActuelNom;
    }

    public class ProvinceDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String code;
        @AuraEnabled public String nom;
        @AuraEnabled public Decimal lat;
        @AuraEnabled public Decimal lon;
        @AuraEnabled public List<String> adjacentes;
        @AuraEnabled public String alias;
    }

    public class DonneesDTO {
        @AuraEnabled public List<PrevisiteurDTO> previsiteurs;
        @AuraEnabled public List<ProvinceDTO> provinces;
        @AuraEnabled public Boolean estAdmin;
    }

    /**
     * Tout ce dont l'onglet a besoin, en un appel. NON cacheable : après un
     * enregistrement de la modale, le composant recharge et doit voir les
     * nouvelles provinces (et les zones des prévisiteurs qui en dépendent).
     */
    @AuraEnabled
    public static DonneesDTO getDonnees() {
        DonneesDTO d = new DonneesDTO();
        d.provinces = provinces();
        d.previsiteurs = previsiteurs();
        d.estAdmin = estAdmin();
        return d;
    }

    /** Code postal et prévisiteur actuel de la Piste ou du Dossier ouvert. */
    @AuraEnabled
    public static ContexteDTO getContexte(Id recordId) {
        ContexteDTO c = new ContexteDTO();
        Schema.SObjectType t = typeDe(recordId);
        exigerAcces(recordId, false);
        if (t == Lead.SObjectType) {
            for (Lead l : [SELECT PostalCode, LOOKUP_Previsiteur__c, LOOKUP_Previsiteur__r.Name
                           FROM Lead WHERE Id = :recordId LIMIT 1]) {
                c.codePostal = l.PostalCode;
                c.compteActuelId = l.LOOKUP_Previsiteur__c;
                c.compteActuelNom = l.LOOKUP_Previsiteur__r?.Name;
            }
        } else {
            for (Pro__c p : [SELECT CodePostal__c, LOOKUP_Pre_visiteur__c, LOOKUP_Pre_visiteur__r.Name
                             FROM Pro__c WHERE Id = :recordId LIMIT 1]) {
                c.codePostal = p.CodePostal__c;
                c.compteActuelId = p.LOOKUP_Pre_visiteur__c;
                c.compteActuelNom = p.LOOKUP_Pre_visiteur__r?.Name;
            }
        }
        return c;
    }

    /**
     * Attribue le prévisiteur (son Compte) à la Piste ou au Dossier. Seul le lookup est
     * écrit : les règles de validation de prévisite (statut, date…) s'appliquent telles
     * quelles et leur message est rendu à l'écran.
     */
    @AuraEnabled
    public static ContexteDTO attribuer(Id recordId, Id compteId) {
        Schema.SObjectType t = typeDe(recordId);
        if (compteId == null || [
            SELECT COUNT() FROM Account
            WHERE Id = :compteId AND Name LIKE :PREFIXE_COMPTE
              AND Acces_REGIE__r.Role__c = :LC027_Roles.PREVISITEUR
        ] == 0) {
            throw new AuraHandledException('Ce compte n\'est pas celui d\'un prévisiteur.');
        }
        exigerAcces(recordId, true);
        SObject rec = t.newSObject(recordId);
        rec.put(t == Lead.SObjectType ? 'LOOKUP_Previsiteur__c' : 'LOOKUP_Pre_visiteur__c', compteId);
        try {
            update rec;
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        }
        return getContexte(recordId);
    }

    /** Préfixe imposé par le filtre de recherche des deux lookups. */
    private static final String PREFIXE_COMPTE = 'PREVISITEUR-%';

    /** La classe est without sharing : c'est ICI que les droits de l'utilisateur sur la fiche sont vérifiés. */
    private static void exigerAcces(Id recordId, Boolean modification) {
        List<UserRecordAccess> acces = [
            SELECT RecordId, HasReadAccess, HasEditAccess FROM UserRecordAccess
            WHERE UserId = :UserInfo.getUserId() AND RecordId = :recordId
        ];
        Boolean ok = !acces.isEmpty() && (modification ? acces[0].HasEditAccess : acces[0].HasReadAccess);
        if (!ok) {
            throw new AuraHandledException(modification
                ? 'Vous n\'avez pas le droit de modifier cette fiche.'
                : 'Vous n\'avez pas accès à cette fiche.');
        }
    }

    private static Schema.SObjectType typeDe(Id recordId) {
        Schema.SObjectType t = recordId == null ? null : recordId.getSObjectType();
        if (t != Lead.SObjectType && t != Pro__c.SObjectType) {
            throw new AuraHandledException('Action disponible uniquement sur une Piste ou un Dossier.');
        }
        return t;
    }

    /**
     * Remplace la table des provinces par la liste reçue (JSON de ProvinceDTO) :
     * lignes avec id = mises à jour, sans id = créées, absentes = supprimées.
     * Réservé aux administrateurs ; tout ou rien.
     */
    @AuraEnabled
    public static DonneesDTO enregistrerProvinces(String provincesJson) {
        if (!estAdmin()) {
            throw new AuraHandledException('Réservé aux administrateurs.');
        }
        List<ProvinceDTO> recues;
        try {
            recues = (List<ProvinceDTO>) JSON.deserialize(provincesJson, List<ProvinceDTO>.class);
        } catch (Exception e) {
            throw new AuraHandledException('Données illisibles.');
        }
        if (recues == null) recues = new List<ProvinceDTO>();

        List<String> erreurs = valider(recues);
        if (!erreurs.isEmpty()) {
            throw new AuraHandledException(String.join(erreurs, '\n'));
        }

        Set<Id> gardes = new Set<Id>();
        List<Province__c> aEcrire = new List<Province__c>();
        for (ProvinceDTO p : recues) {
            Province__c r = new Province__c(
                Code__c       = p.code.trim(),
                Name          = p.nom.trim(),
                Coordonnees__Latitude__s   = p.lat,
                Coordonnees__Longitude__s  = p.lon,
                Adjacentes__c = p.adjacentes == null ? null : String.join(p.adjacentes, ';'),
                Alias__c      = String.isBlank(p.alias) ? null : p.alias.trim()
            );
            if (String.isNotBlank(p.id)) {
                r.Id = Id.valueOf(p.id);
                gardes.add(r.Id);
            }
            aEcrire.add(r);
        }

        Savepoint sp = Database.setSavepoint();
        try {
            // Suppressions d'abord : un code libéré peut être repris par une autre ligne.
            delete [SELECT Id FROM Province__c WHERE Id NOT IN :gardes];
            upsert aEcrire;
        } catch (DmlException e) {
            Database.rollback(sp);
            throw new AuraHandledException('Enregistrement impossible : ' + e.getDmlMessage(0));
        }
        codeParNom = null;
        return getDonnees();
    }

    /** Utilisateur « Modifier toutes les données » (par profil ou par ensemble d'autorisations). */
    @TestVisible
    private static Boolean estAdmin() {
        return [
            SELECT COUNT() FROM PermissionSetAssignment
            WHERE AssigneeId = :UserInfo.getUserId()
              AND PermissionSet.PermissionsModifyAllData = true
        ] > 0;
    }

    @TestVisible
    private static List<String> valider(List<ProvinceDTO> recues) {
        List<String> erreurs = new List<String>();
        Set<String> codes = new Set<String>();
        for (ProvinceDTO p : recues) {
            if (p.code != null && p.code.trim().length() > 0) codes.add(p.code.trim());
        }
        Set<String> vus = new Set<String>();
        for (ProvinceDTO p : recues) {
            String code = p.code == null ? '' : p.code.trim();
            String lib = 'Province ' + (String.isBlank(code) ? '(sans code)' : code) + ' : ';
            if (!Pattern.matches('\\d\\d', code)) {
                erreurs.add(lib + 'le code doit faire 2 chiffres.');
            } else if (!vus.add(code)) {
                erreurs.add(lib + 'code en double.');
            }
            if (String.isBlank(p.nom)) {
                erreurs.add(lib + 'nom obligatoire.');
            }
            if (p.lat != null && (p.lat < -90 || p.lat > 90)) {
                erreurs.add(lib + 'latitude hors de [-90 ; 90].');
            }
            if (p.lon != null && (p.lon < -180 || p.lon > 180)) {
                erreurs.add(lib + 'longitude hors de [-180 ; 180].');
            }
            for (String a : (p.adjacentes == null ? new List<String>() : p.adjacentes)) {
                if (!codes.contains(a)) {
                    erreurs.add(lib + 'province adjacente inconnue « ' + a + ' ».');
                } else if (a == code) {
                    erreurs.add(lib + 'une province ne peut pas être adjacente à elle-même.');
                }
            }
        }
        return erreurs;
    }

    private static List<ProvinceDTO> provinces() {
        List<ProvinceDTO> out = new List<ProvinceDTO>();
        for (Province__c r : [
            SELECT Id, Code__c, Name, Coordonnees__Latitude__s, Coordonnees__Longitude__s, Adjacentes__c, Alias__c
            FROM Province__c
            ORDER BY Code__c
            LIMIT 500
        ]) {
            ProvinceDTO p = new ProvinceDTO();
            p.id = r.Id;
            p.code = r.Code__c;
            p.nom = r.Name;
            p.lat = r.Coordonnees__Latitude__s;
            p.lon = r.Coordonnees__Longitude__s;
            p.adjacentes = decouper(r.Adjacentes__c);
            p.alias = r.Alias__c;
            out.add(p);
        }
        return out;
    }

    private static List<PrevisiteurDTO> previsiteurs() {
        List<PrevisiteurDTO> out = new List<PrevisiteurDTO>();
        // Valeurs d'API de Contrat_Provinces__c (« Araba/Álava;Rioja (La) ») :
        // splitZones les traduit en codes. toLabel() : NombrePrevisites__c rend son libellé (« 6 à 10 »).
        for (Campaign c : [
            SELECT Id, Name, Email__c, Contrat_Provinces__c, IsActive, toLabel(NombrePrevisites__c)
            FROM Campaign
            WHERE Role__c = :LC027_Roles.PREVISITEUR
              AND StatutContrat__c = :LC027_GestionContrat.STATUT_SIGNE
            ORDER BY Name
            LIMIT 2000
        ]) {
            PrevisiteurDTO d = new PrevisiteurDTO();
            d.id    = c.Id;
            d.nom   = c.Name;
            d.mail  = c.Email__c;
            d.zones = splitZones(c.Contrat_Provinces__c);
            d.actif = c.IsActive;
            d.dispo = String.isBlank(c.NombrePrevisites__c) ? '—' : c.NombrePrevisites__c;
            out.add(d);
        }
        // Compte du prévisiteur : le plus ancien, si une Campagne en a plusieurs.
        Map<Id, Id> compteParCampagne = new Map<Id, Id>();
        for (Account a : [
            SELECT Id, Acces_REGIE__c FROM Account
            WHERE Acces_REGIE__r.Role__c = :LC027_Roles.PREVISITEUR AND Name LIKE :PREFIXE_COMPTE
            ORDER BY CreatedDate ASC
        ]) {
            if (!compteParCampagne.containsKey(a.Acces_REGIE__c)) compteParCampagne.put(a.Acces_REGIE__c, a.Id);
        }
        for (PrevisiteurDTO d : out) d.compteId = compteParCampagne.get(d.id);
        return out;
    }

    /**
     * Transforme une liste de provinces (« Asturias;Madrid;Toledo ») en codes à 2 chiffres.
     * Reconnaît le nom et les alias de chaque Province__c (accents et majuscules ignorés),
     * ou directement des codes (« 28;34;47 »). Les valeurs non reconnues sont ignorées.
     */
    public static List<String> splitZones(String raw) {
        List<String> zones = new List<String>();
        if (String.isBlank(raw)) return zones;
        Map<String, String> parNom = codeParNom();
        for (String z : raw.split('[;,]+')) {
            String v = z.trim();
            if (String.isBlank(v)) continue;
            String code = null;
            if (v.isNumeric()) { code = v.length() == 1 ? '0' + v : v.substring(0, 2); }
            else { code = parNom.get(norm(v)); }
            if (code != null && !zones.contains(code)) zones.add(code);
        }
        return zones;
    }

    /** Nom ou alias (normalisé) → code, lu une fois par transaction dans Province__c. */
    private static Map<String, String> codeParNom;
    private static Map<String, String> codeParNom() {
        if (codeParNom == null) {
            codeParNom = new Map<String, String>();
            for (Province__c r : [SELECT Code__c, Name, Alias__c FROM Province__c LIMIT 500]) {
                codeParNom.put(norm(r.Name), r.Code__c);
                for (String a : decouper(r.Alias__c)) {
                    codeParNom.put(norm(a), r.Code__c);
                }
            }
        }
        return codeParNom;
    }

    private static List<String> decouper(String v) {
        List<String> out = new List<String>();
        if (String.isBlank(v)) return out;
        for (String s : v.split(';')) {
            if (String.isNotBlank(s)) out.add(s.trim());
        }
        return out;
    }

    /** minuscules + accents retirés + espaces normalisés, pour comparer les noms. */
    @TestVisible
    private static String norm(String v) {
        String s = v.toLowerCase().trim();
        String fromLett = 'áàäâãéèëêíìïîóòöôõúùüûñç';
        String to = 'aaaaaeeeeiiiiooooouuuunc';
        for (Integer i = 0; i < fromLett.length(); i++) s = s.replace(fromLett.substring(i, i + 1), to.substring(i, i + 1));
        s = s.replaceAll('\\s+', ' ');
        return s;
    }
}