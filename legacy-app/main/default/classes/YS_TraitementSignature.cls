/**
 * YS_TraitementSignature — ce qui se passe QUAND une demande de signature aboutit.
 *
 * Point d'entrée unique, appelé par deux chemins qui doivent produire exactement
 * le même effet :
 *   • YS_TraiterWebhook   — le webhook Yousign, en temps réel ;
 *   • YS_ReconciliationBatch — le filet de sécurité, toutes les 15 minutes.
 *
 * D'où la factorisation ici : un webhook perdu ne doit pas donner un dossier
 * traité différemment d'un webhook reçu.
 *
 * IDEMPOTENCE — les méthodes peuvent être rejouées sans dommage : si le devis
 * est déjà au statut signé, elles sortent sans rien refaire. Yousign rejoue ses
 * événements, et le batch peut croiser un webhook en vol.
 */
public without sharing class YS_TraitementSignature {

    /** Le PDF signé est un fichier À PART du devis vierge « Devis CAE - Contrat ». */
    public static final String TITRE_SIGNE       = 'Presupuesto CAE - Firmado';
    public static final String NOM_FICHIER_SIGNE = 'Presupuesto_CAE_Firmado.pdf';

    /** Enregistrement porteur de la demande de signature. */
    public class Cible {
        public Id     recordId;
        public String sobjectType;
        public Cible(Id recordId, String sobjectType) {
            this.recordId = recordId;
            this.sobjectType = sobjectType;
        }
    }

    /**
     * Retrouve la Piste, le Dossier ou la Campagne qui porte cette demande Yousign.
     * Trois requêtes au pire : YS_Demande_Id__c est un External Id sur les trois
     * objets, donc indexé — le webhook doit répondre en moins d'une seconde.
     */
    public static Cible localiser(String demandeId) {
        if (String.isBlank(demandeId)) return null;

        List<Lead> pistes = [SELECT Id FROM Lead WHERE YS_Demande_Id__c = :demandeId LIMIT 1];
        if (!pistes.isEmpty()) return new Cible(pistes[0].Id, 'Lead');

        List<Pro__c> dossiers = [SELECT Id FROM Pro__c WHERE YS_Demande_Id__c = :demandeId LIMIT 1];
        if (!dossiers.isEmpty()) return new Cible(dossiers[0].Id, 'Pro__c');

        // Contrat de collaboration d'un pré-visiteur (portail Gestion Prévisites).
        // Troisième objet porteur de YS_Demande_Id__c, même nom d'API, donc même
        // recherche indexée. Le TRAITEMENT, lui, n'est pas le même : voir les
        // délégations vers LC027_TraitementContrat dans les méthodes ci-dessous.
        List<Campaign> campagnes = [SELECT Id FROM Campaign WHERE YS_Demande_Id__c = :demandeId LIMIT 1];
        if (!campagnes.isEmpty()) return new Cible(campagnes[0].Id, 'Campaign');

        return null;
    }

    /**
     * Signature aboutie : récupère le PDF signé, le joint au record, bascule le
     * devis en « Signé ».
     *
     * ⚠️ ORDRE — le callout est fait AVANT tout DML. L'inverse lèverait
     * « You have uncommitted work pending ».
     *
     * @return true si quelque chose a été fait, false si sans objet (demande
     *         inconnue, ou devis déjà signé).
     */
    public static Boolean appliquerSignature(String demandeId) {
        Cible c = localiser(demandeId);
        if (c == null) {
            System.debug(LoggingLevel.WARN,
                'YS_TraitementSignature : aucune Piste, Dossier ni Campagne pour la demande ' + demandeId);
            return false;
        }
        // Campagne = contrat de pré-visiteur : tout ce qui suit est propre au devis
        // (YS_Statut__c, LC021_DevisSignature.champStatut, titre « Presupuesto CAE »),
        // et n'a pas d'équivalent ici. On délègue avant d'y toucher.
        if (c.sobjectType == 'Campaign') {
            return LC027_TraitementContrat.appliquerSignature(c.recordId, demandeId);
        }
        if (dejaSigne(c)) {
            System.debug(LoggingLevel.INFO,
                'YS_TraitementSignature : ' + c.recordId + ' déjà signé, rien à faire.');
            return false;
        }

        Blob pdf = YS_YousignService.telechargerSigne(demandeId);   // ← callout
        Id docSigne = joindreSigne(c.recordId, pdf);                // ← puis DML

        SObject maj = enregistrement(c);
        // ⚠️ SANS CE POINTEUR, le portail servait le contrat VIERGE a la place
        // du document signe. La recherche du fichier signe passe par
        // ContentDocumentLink, que l'utilisateur invite du site ne peut pas
        // lire : elle ne renvoyait rien, et la lecture retombait sur le
        // pointeur du contrat. Ce traitement-ci tourne en Automated Process,
        // qui voit les liens — c'est donc a lui de noter l'information pour
        // celui qui ne les voit pas.
        maj.put('YS_Signe_Doc_Id__c', docSigne == null ? null : String.valueOf(docSigne));
        maj.put(LC021_DevisSignature.champStatut(c.sobjectType),
                LC021_DevisSignature.valeurStatut(c.sobjectType, LC021_DevisSignature.CODE_SIGNE));
        maj.put('YS_Statut__c', 'Signe');
        maj.put('YS_Date_Signature__c', Datetime.now());
        maj.put('YS_Message_Erreur__c', null);

        // Le Dossier porte en plus un champ Date historique, alimenté par le
        // reporting métier existant : on le tient à jour pour ne rien casser.
        if (c.sobjectType == 'Pro__c') {
            maj.put('DEVIS_Date_Signature__c', Date.today());
        }

        update maj;
        return true;
    }

    /**
     * Refus ou expiration : rien à télécharger, le statut métier du devis ne
     * bouge PAS — c'est au commercial de décider de relancer. On ne trace que
     * l'état technique, pour que l'écran puisse le dire.
     *
     * @param statutYs 'Refuse' ou 'Expire'.
     */
    public static Boolean appliquerEchec(String demandeId, String statutYs, String motif) {
        Cible c = localiser(demandeId);
        if (c == null) return false;
        if (c.sobjectType == 'Campaign') {
            return LC027_TraitementContrat.appliquerEchec(c.recordId, statutYs, motif);
        }
        if (dejaSigne(c)) return false;   // un refus arrivé après coup ne défait pas une signature

        SObject maj = enregistrement(c);
        maj.put('YS_Statut__c', statutYs);
        maj.put('YS_Message_Erreur__c', tronquer(motif, 255));
        update maj;
        return true;
    }

    /**
     * Consigne un échec de traitement SUR l'enregistrement concerné.
     *
     * POURQUOI — un Queueable qui attrape son exception se termine « Completed,
     * 0 erreur ». Sans cette trace, un échec de récupération du document signé
     * était totalement invisible : le webhook arrivait, était journalisé, le job
     * passait au vert, et le devis restait « en attente » sans que rien nulle
     * part ne dise pourquoi. C'est exactement ce qui s'est produit en sandbox.
     *
     * `YS_Statut__c` n'est PAS mis à « Erreur » : cette valeur sort la demande
     * du périmètre de YS_ReconciliationBatch, qui ne reprend que « Envoye » et
     * « Ouvert ». On veut au contraire que le filet continue de réessayer.
     */
    public static void enregistrerErreur(String demandeId, String message) {
        try {
            Cible c = localiser(demandeId);
            if (c == null) return;
            if (c.sobjectType == 'Campaign') {
                LC027_TraitementContrat.enregistrerErreur(c.recordId, message);
                return;
            }

            SObject maj = enregistrement(c);
            maj.put('YS_Message_Erreur__c', tronquer(message, 255));
            update maj;
        } catch (Exception e) {
            // Ne jamais masquer l'erreur d'origine derrière un échec de trace.
            System.debug(LoggingLevel.ERROR,
                'YS_TraitementSignature.enregistrerErreur : ' + e.getMessage());
        }
    }

    /* ════════════════════════════════════════════════════════════════════════
       FICHIER SIGNÉ
       ════════════════════════════════════════════════════════════════════════ */

    /**
     * Joint le PDF signé au record, en versionnant s'il en existe déjà un.
     *
     * ⚠️ GUEST USER — liaison par FirstPublishLocationId, jamais par
     * ContentDocumentLink : Salesforce interdit à l'utilisateur invité d'insérer
     * un partage de fichier, même en `without sharing`. Ce traitement tourne le
     * plus souvent en asynchrone (donc en Automated Process), mais le batch de
     * réconciliation peut être lancé depuis n'importe quel contexte : on garde
     * le procédé sûr dans tous les cas. Voir LC021_DevisSignature.enregistrerContrat.
     */
    private static Id joindreSigne(Id recordId, Blob pdf) {
        ContentVersion derniere = derniereVersionSignee(recordId);

        if (derniere != null) {
            String md5 = EncodingUtil.convertToHex(Crypto.generateDigest('MD5', pdf));
            if (derniere.Checksum == md5) {
                // Même fichier : un rejeu du même événement, on ne crée pas de version.
                return derniere.ContentDocumentId;
            }
        }

        ContentVersion version = nouvelleVersion(pdf,
            derniere == null ? null : derniere.ContentDocumentId, recordId);
        try {
            insert version;
        } catch (DmlException e) {
            if (derniere == null) throw e;
            // Ajouter une version à un document créé par un autre utilisateur
            // peut être refusé : on repart sur un nouveau document, la lecture
            // servant toujours la version la plus récente.
            version = nouvelleVersion(pdf, null, recordId);
            insert version;
        }

        return [SELECT ContentDocumentId FROM ContentVersion
                WHERE Id = :version.Id].ContentDocumentId;
    }

    private static ContentVersion nouvelleVersion(Blob octets, Id docId, Id recordId) {
        ContentVersion version = new ContentVersion(
            Title        = TITRE_SIGNE,
            PathOnClient = NOM_FICHIER_SIGNE,
            VersionData  = octets
        );
        if (docId != null) {
            version.ContentDocumentId = docId;
        } else {
            version.FirstPublishLocationId = recordId;
        }
        return version;
    }

    /** Dernière version du devis SIGNÉ lié au record, ou null. */
    public static ContentVersion derniereVersionSignee(Id recordId) {
        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink lien : [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
            AND ContentDocument.Title = :TITRE_SIGNE
        ]) {
            docIds.add(lien.ContentDocumentId);
        }
        if (docIds.isEmpty()) return null;

        List<ContentVersion> versions = [
            SELECT Id, ContentDocumentId, Checksum, VersionData
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds AND IsLatest = true
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        return versions.isEmpty() ? null : versions[0];
    }

    /* ════════════════════════════════════════════════════════════════════════
       OUTILS
       ════════════════════════════════════════════════════════════════════════ */

    private static Boolean dejaSigne(Cible c) {
        String champ = LC021_DevisSignature.champStatut(c.sobjectType);
        Id recordId = c.recordId;
        String soql = 'SELECT ' + champ + ' FROM ' + c.sobjectType + ' WHERE Id = :recordId LIMIT 1';
        List<SObject> lignes = Database.query(soql);
        if (lignes.isEmpty()) return false;
        return LC021_DevisSignature.codeStatutPublic((String) lignes[0].get(champ))
            == LC021_DevisSignature.CODE_SIGNE;
    }

    private static SObject enregistrement(Cible c) {
        SObject o = Schema.getGlobalDescribe().get(c.sobjectType).newSObject();
        o.put('Id', c.recordId);
        return o;
    }

    private static String tronquer(String valeur, Integer max) {
        if (String.isBlank(valeur)) return valeur;
        return valeur.length() <= max ? valeur : valeur.substring(0, max);
    }
}