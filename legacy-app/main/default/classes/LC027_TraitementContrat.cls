/**
 * LC027_TraitementContrat — ce qui se passe quand le contrat d'un PRE-VISITEUR
 * revient de Yousign.
 *
 * Pendant de YS_TraitementSignature pour la Campagne. Classe séparée parce que
 * l'originale est entièrement écrite pour le devis : elle pose YS_Statut__c,
 * appelle LC021_DevisSignature.champStatut(sobjectType) — qui ne connaît que
 * Lead et Pro__c — et joint un fichier intitulé « Presupuesto CAE - Firmado ».
 * Rien de tout cela ne s'applique à un contrat de collaboration.
 *
 * BRANCHEMENT — le webhook Yousign a un point d'entrée unique
 * (Site Force.com « yousign » -> YS_Webhook__e -> YS_TraiterWebhook ->
 * YS_TraitementSignature). YS_TraitementSignature.localiser() reconnaît
 * désormais aussi la Campagne, et ses trois points d'entrée délèguent ici quand
 * la cible en est une. Le chemin du devis est inchangé.
 *
 * IDEMPOTENCE — Yousign rejoue ses événements et YS_ReconciliationBatch peut
 * croiser un webhook en vol : toutes les méthodes se rejouent sans dommage.
 */
public without sharing class LC027_TraitementContrat {

    /** Le contrat signé est un fichier À PART du contrat vierge envoyé à la signature. */
    public static final String TITRE_SIGNE       = 'Contrato Previsitador - Firmado';
    public static final String NOM_FICHIER_SIGNE = 'Contrato_Previsitador_Firmado.pdf';

    /** Valeurs d'API de Campaign.StatutContrat__c (picklist restreinte). */
    public static final String STATUT_SIGNE = 'Signe';

    /**
     * Applique la signature : télécharge le PDF signé, le joint à la CAMPAGNE
     * (et non à une Piste ou un Dossier), puis passe le contrat à « Signé ».
     *
     * @return true si quelque chose a été fait, false si déjà signé ou introuvable.
     */
    public static Boolean appliquerSignature(Id campagneId, String demandeId) {
        List<Campaign> camps = [
            SELECT Id, StatutContrat__c, YS_Signe_Doc_Id__c
            FROM Campaign WHERE Id = :campagneId LIMIT 1
        ];
        if (camps.isEmpty()) return false;
        Campaign camp = camps[0];

        if (camp.StatutContrat__c == STATUT_SIGNE) {
            System.debug(LoggingLevel.INFO,
                'LC027_TraitementContrat : campagne ' + campagneId + ' déjà signée, rien à faire.');
            return false;
        }

        Blob pdf = YS_YousignService.telechargerSigne(demandeId);   // callout
        Id docSigne = joindreSigne(campagneId, pdf);                // puis DML

        update new Campaign(
            Id                   = campagneId,
            StatutContrat__c     = STATUT_SIGNE,
            // Voir le commentaire du champ : sans ce pointeur, le portail servirait
            // le contrat VIERGE, l'invité ne pouvant pas lire les ContentDocumentLink.
            YS_Signe_Doc_Id__c   = docSigne == null ? null : String.valueOf(docSigne),
            YS_Date_Signature__c = Datetime.now(),
            YS_Message_Erreur__c = null
        );
        return true;
    }

    /**
     * Refus ou expiration : rien à télécharger. Le contrat NE redescend PAS en
     * « En cours de génération » — le prévisiteur a bien saisi ses informations,
     * les lui redemander serait absurde. Il reste en attente, avec le motif visible.
     */
    public static Boolean appliquerEchec(Id campagneId, String statutYs, String motif) {
        List<Campaign> camps = [
            SELECT Id, StatutContrat__c FROM Campaign WHERE Id = :campagneId LIMIT 1
        ];
        if (camps.isEmpty()) return false;
        // Un refus arrivé après coup ne défait pas une signature déjà appliquée.
        if (camps[0].StatutContrat__c == STATUT_SIGNE) return false;

        update new Campaign(
            Id = campagneId,
            YS_Message_Erreur__c = tronquer(statutYs + ' : ' + motif, 255)
        );
        return true;
    }

    /** Consigne un échec de traitement sur la campagne, sans jamais masquer l'erreur d'origine. */
    public static void enregistrerErreur(Id campagneId, String message) {
        try {
            update new Campaign(Id = campagneId, YS_Message_Erreur__c = tronquer(message, 255));
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                'LC027_TraitementContrat.enregistrerErreur : ' + e.getMessage());
        }
    }

    /**
     * Joint le PDF signé à la campagne.
     *
     * ⚠️ GUEST USER — liaison par ContentVersion.FirstPublishLocationId, JAMAIS
     * par ContentDocumentLink : Salesforce refuse à l'utilisateur invité d'insérer
     * un partage de fichier (INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY), même
     * en `without sharing`. Ce traitement tourne le plus souvent en Automated
     * Process, mais le batch de réconciliation peut partir de n'importe quel
     * contexte : on garde le procédé sûr dans tous les cas.
     */
    private static Id joindreSigne(Id campagneId, Blob pdf) {
        if (pdf == null) return null;

        ContentVersion cv = new ContentVersion();
        cv.Title                  = TITRE_SIGNE;
        cv.PathOnClient           = NOM_FICHIER_SIGNE;
        cv.VersionData            = pdf;
        cv.FirstPublishLocationId = campagneId;
        insert cv;

        return [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1]
                   .ContentDocumentId;
    }

    private static String tronquer(String valeur, Integer max) {
        if (String.isBlank(valeur)) return valeur;
        return valeur.length() > max ? valeur.substring(0, max) : valeur;
    }
}