/**
 * Moteur générique de détection de doublons.
 *
 * Principe : chaque enregistrement concerné pointe (lookup) vers un Groupe de doublons
 * (Doublon_Groupe__c) — un par règle et par valeur — qui porte le Nombre d'enregistrements
 * rattachés. L'indicateur affiché en vue de liste est une formule qui lit ce Nombre.
 *
 * Aucun autre enregistrement Piste / Dossier n'est jamais modifié : seul le lien de
 * l'enregistrement en cours d'enregistrement (avant sauvegarde, sans DML) et les groupes
 * touchés (après sauvegarde) sont écrits. Doublon_Groupe__c n'a ni trigger ni Flow :
 * aucune cascade ni boucle n'est possible.
 *
 * Appels depuis les triggers :
 *  - before insert / before update : avantEnregistrement(Trigger.new, Trigger.oldMap)
 *  - after insert / after update   : apresEnregistrement()
 *  - after delete                  : apresSuppressionOuRestauration(Trigger.old)
 *  - after undelete                : apresSuppressionOuRestauration(Trigger.new)
 *
 * Coût par lot de 200 : avant = 1 requête + 1 upsert seulement s'il y a des clés à
 * rattacher ; après = 1 requête de verrou + 1 agrégat par objet de la règle + 1 update.
 * Les comptes sont recalculés (COUNT), jamais incrémentés : ils se corrigent d'eux-mêmes.
 *
 * Les règles actives sont lues dans Doublon_Regle__mdt (sans requête SOQL).
 * without sharing : les doublons doivent être comptés quel que soit le propriétaire.
 */
public without sharing class DoublonService {

    private static final String SEPARATEUR = '|';

    /** Groupes touchés pendant la transaction, recomptés après sauvegarde. */
    private static Set<Id> aRecompter = new Set<Id>();

    /** Règles injectées par les tests (null = règles actives de Doublon_Regle__mdt). */
    @TestVisible
    private static Map<String, DoublonRegle> reglesForcees;

    private static Map<String, DoublonRegle> reglesActives;

    // ------------------------------------------------------------ Points d'entrée

    public static void avantEnregistrement(List<SObject> nouveaux, Map<Id, SObject> anciens) {
        if (nouveaux == null || nouveaux.isEmpty()) return;
        SObjectType typeObjet = nouveaux[0].getSObjectType();

        for (String nomRegle : regles().keySet()) {
            DoublonRegle regle = regles().get(nomRegle);
            SObjectField champ = regle.champsLien().get(typeObjet);
            if (champ == null) continue;
            rattacher(nomRegle, regle, champ, nouveaux, anciens);
        }
    }

    public static void apresEnregistrement() {
        recompter();
    }

    public static void apresSuppressionOuRestauration(List<SObject> enregistrements) {
        if (enregistrements == null || enregistrements.isEmpty()) return;
        SObjectType typeObjet = enregistrements[0].getSObjectType();

        for (DoublonRegle regle : regles().values()) {
            SObjectField champ = regle.champsLien().get(typeObjet);
            if (champ == null) continue;
            for (SObject enr : enregistrements) {
                Id groupe = (Id) enr.get(champ);
                if (groupe != null) aRecompter.add(groupe);
            }
        }
        recompter();
    }

    // ------------------------------------------------------------ Avant sauvegarde

    /**
     * Pose le lien vers le bon groupe sur chaque enregistrement à traiter.
     * Un enregistrement n'est traité que si sa clé ou son lien a changé, ou s'il entre
     * dans la règle sans lien (reprise des données) : une modification sans rapport
     * ne coûte aucune requête.
     */
    private static void rattacher(String nomRegle, DoublonRegle regle, SObjectField champ,
                                  List<SObject> nouveaux, Map<Id, SObject> anciens) {
        Map<String, List<SObject>> parCleUnique = new Map<String, List<SObject>>();

        for (SObject enr : nouveaux) {
            String cle = regle.cle(enr);
            Id lienActuel = (Id) enr.get(champ);
            SObject ancien = (anciens == null || enr.Id == null) ? null : anciens.get(enr.Id);

            if (ancien != null) {
                Id lienAncien = (Id) ancien.get(champ);
                Boolean inchange = cle == regle.cle(ancien) && lienActuel == lienAncien;
                if (inchange && (cle == null) == (lienActuel == null)) continue;
                if (lienAncien != null) aRecompter.add(lienAncien);
            }

            if (cle == null) {
                if (lienActuel != null) {
                    aRecompter.add(lienActuel);
                    enr.put(champ, null);
                }
                continue;
            }
            String cleUnique = nomRegle + SEPARATEUR + cle;
            if (!parCleUnique.containsKey(cleUnique)) parCleUnique.put(cleUnique, new List<SObject>());
            parCleUnique.get(cleUnique).add(enr);
        }
        if (parCleUnique.isEmpty()) return;

        Map<String, Id> groupes = groupesParCle(nomRegle, parCleUnique.keySet());
        for (String cleUnique : parCleUnique.keySet()) {
            Id groupe = groupes.get(cleUnique);
            for (SObject enr : parCleUnique.get(cleUnique)) {
                Id lienActuel = (Id) enr.get(champ);
                if (lienActuel != null && lienActuel != groupe) aRecompter.add(lienActuel);
                // groupe null (création refusée) : pas de lien, rattrapé au prochain enregistrement.
                enr.put(champ, groupe);
                if (groupe != null) aRecompter.add(groupe);
            }
        }
    }

    /** Groupes existants pour ces clés, et création de ceux qui manquent. */
    private static Map<String, Id> groupesParCle(String nomRegle, Set<String> clesUniques) {
        Map<String, Id> resultat = new Map<String, Id>();
        for (Doublon_Groupe__c g : [
            SELECT Id, Cle_Unique__c FROM Doublon_Groupe__c WHERE Cle_Unique__c IN :clesUniques
        ]) {
            resultat.put(g.Cle_Unique__c, g.Id);
        }

        List<Doublon_Groupe__c> aCreer = new List<Doublon_Groupe__c>();
        for (String cleUnique : clesUniques) {
            if (resultat.containsKey(cleUnique)) continue;
            String cle = cleUnique.substringAfter(SEPARATEUR);
            aCreer.add(new Doublon_Groupe__c(
                Name = cle.left(80),
                Regle__c = nomRegle,
                Cle_Unique__c = cleUnique,
                Nombre__c = 0
            ));
        }
        if (aCreer.isEmpty()) return resultat;

        // upsert sur la clé unique, sans tout annuler : si un autre utilisateur crée le même
        // groupe au même instant, sa ligne est relue juste après au lieu de bloquer la sauvegarde.
        Database.UpsertResult[] resultats = Database.upsert(aCreer, Doublon_Groupe__c.Cle_Unique__c, false);
        Set<String> aRelire = new Set<String>();
        for (Integer i = 0; i < resultats.size(); i++) {
            if (resultats[i].isSuccess()) {
                resultat.put(aCreer[i].Cle_Unique__c, resultats[i].getId());
            } else {
                aRelire.add(aCreer[i].Cle_Unique__c);
            }
        }
        if (!aRelire.isEmpty()) {
            for (Doublon_Groupe__c g : [
                SELECT Id, Cle_Unique__c FROM Doublon_Groupe__c WHERE Cle_Unique__c IN :aRelire
            ]) {
                resultat.put(g.Cle_Unique__c, g.Id);
            }
        }
        return resultat;
    }

    // ------------------------------------------------------------ Après sauvegarde

    /**
     * Recompte les groupes touchés. Le verrou (FOR UPDATE) est pris avant le comptage :
     * deux enregistrements simultanés sur le même numéro sont comptés l'un après l'autre.
     * Un échec (verrou indisponible) ne bloque pas la sauvegarde : le groupe sera
     * recompté au prochain enregistrement qui le touche.
     */
    private static void recompter() {
        if (aRecompter.isEmpty()) return;
        Set<Id> ids = new Set<Id>(aRecompter);
        aRecompter.clear();

        try {
            List<Doublon_Groupe__c> groupes = [
                SELECT Id, Regle__c, Nombre__c FROM Doublon_Groupe__c WHERE Id IN :ids FOR UPDATE
            ];
            Map<String, Set<Id>> idsParRegle = new Map<String, Set<Id>>();
            for (Doublon_Groupe__c g : groupes) {
                if (!idsParRegle.containsKey(g.Regle__c)) idsParRegle.put(g.Regle__c, new Set<Id>());
                idsParRegle.get(g.Regle__c).add(g.Id);
            }

            Map<Id, Integer> comptes = new Map<Id, Integer>();
            for (String nomRegle : idsParRegle.keySet()) {
                DoublonRegle regle = regles().get(nomRegle);
                // Règle désactivée : on ne touche pas aux groupes.
                if (regle == null) continue;
                Set<Id> idsRegle = idsParRegle.get(nomRegle);
                for (Id g : idsRegle) comptes.put(g, 0);
                for (SObjectType typeObjet : regle.champsLien().keySet()) {
                    compter(typeObjet, regle.champsLien().get(typeObjet), idsRegle, comptes);
                }
            }

            List<Doublon_Groupe__c> aMettreAJour = new List<Doublon_Groupe__c>();
            for (Doublon_Groupe__c g : groupes) {
                Integer nombre = comptes.get(g.Id);
                if (nombre != null && nombre != g.Nombre__c) {
                    aMettreAJour.add(new Doublon_Groupe__c(Id = g.Id, Nombre__c = nombre));
                }
            }
            if (!aMettreAJour.isEmpty()) update aMettreAJour;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'DoublonService.recompter : ' + e.getMessage());
        }
    }

    /** Un agrégat indexé (lookup) par objet : COUNT des enregistrements rattachés. */
    private static void compter(SObjectType typeObjet, SObjectField champ, Set<Id> idsGroupes,
                                Map<Id, Integer> comptes) {
        String nomChamp = champ.getDescribe().getName();
        String requete = 'SELECT ' + nomChamp + ' groupe, COUNT(Id) nombre FROM '
            + typeObjet.getDescribe().getName()
            + ' WHERE ' + nomChamp + ' IN :idsGroupes GROUP BY ' + nomChamp;
        List<AggregateResult> lignes = (List<AggregateResult>) Database.queryWithBinds(
            requete, new Map<String, Object>{ 'idsGroupes' => idsGroupes }, AccessLevel.SYSTEM_MODE);
        for (AggregateResult ligne : lignes) {
            Id groupe = (Id) ligne.get('groupe');
            comptes.put(groupe, comptes.get(groupe) + (Integer) ligne.get('nombre'));
        }
    }

    // ------------------------------------------------------------ Règles

    private static Map<String, DoublonRegle> regles() {
        if (reglesForcees != null) return reglesForcees;
        if (reglesActives != null) return reglesActives;

        reglesActives = new Map<String, DoublonRegle>();
        for (Doublon_Regle__mdt config : Doublon_Regle__mdt.getAll().values()) {
            if (!config.Actif__c || String.isBlank(config.Classe__c)) continue;
            Type classe = Type.forName(config.Classe__c);
            Object instance = classe == null ? null : classe.newInstance();
            if (instance instanceof DoublonRegle) {
                reglesActives.put(config.DeveloperName, (DoublonRegle) instance);
            } else {
                System.debug(LoggingLevel.ERROR, 'DoublonService : classe invalide ' + config.Classe__c);
            }
        }
        return reglesActives;
    }
}