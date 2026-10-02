/**
 * YS_ReconciliationBatch — le filet de sécurité du retour de signature.
 *
 * POURQUOI IL EXISTE — Yousign attend une réponse en moins d'une seconde et
 * abandonne après quelques rejeux. Un endpoint momentanément lent, un
 * déploiement en cours, une maintenance : et un devis signé par le client
 * resterait indéfiniment affiché « En attente de signature » côté portail.
 * Ce batch interroge périodiquement Yousign sur les demandes encore ouvertes et
 * applique EXACTEMENT le même traitement que le webhook — même méthode,
 * YS_TraitementSignature, pour qu'aucun écart ne puisse s'installer.
 *
 * DEUX OBJETS, DEUX PASSES — un QueryLocator ne porte que sur un SObject. Le
 * batch tourne donc d'abord sur Lead, puis s'enchaîne lui-même sur Pro__c
 * depuis finish().
 *
 * CE QU'IL FAIT, CONCRÈTEMENT — pour chaque Piste et chaque Dossier dont la
 * demande est encore ouverte (`YS_Statut__c` à « Envoye » ou « Ouvert »), il
 * demande à Yousign où en est la signature (GET /signature_requests/{id}) et,
 * si elle est terminée, applique exactement le même traitement que le webhook :
 * téléchargement du PDF signé, pièce jointe au dossier, bascule du statut.
 *
 * Ce n'est PAS le chemin principal. Le webhook reste la voie normale, quasi
 * instantanée ; ce batch est le filet qui rattrape ce que le webhook a manqué.
 *
 * PLANIFICATION — un seul job suffit, la liste de minutes est acceptée par le
 * planificateur Apex. Toutes les 15 minutes :
 *
 *   System.schedule('Yousign reconciliation', '0 0,15,30,45 * * * ?',
 *                   new YS_ReconciliationBatch());
 *
 * (Quatre jobs horaires décalés donneraient le même résultat, mais encombrent
 * la liste des tâches planifiées pour rien.)
 */
public without sharing class YS_ReconciliationBatch
        implements Database.Batchable<SObject>, Database.AllowsCallouts, Schedulable {

    /**
     * Taille de lot. Chaque enregistrement coûte 1 appel de statut, plus 1
     * téléchargement s'il vient d'être signé : 20 tient largement sous les
     * 100 callouts autorisés par transaction.
     */
    public static final Integer TAILLE_LOT = 20;

    /** Au-delà, on considère la demande abandonnée et on cesse de l'interroger. */
    private static final Integer FENETRE_JOURS = 30;

    private final String sobjectType;

    public YS_ReconciliationBatch() {
        this('Lead');
    }

    public YS_ReconciliationBatch(String sobjectType) {
        this.sobjectType = sobjectType;
    }

    /** Point d'entrée du planificateur : démarre la passe Lead. */
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new YS_ReconciliationBatch('Lead'), TAILLE_LOT);
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        Datetime depuis = Datetime.now().addDays(-FENETRE_JOURS);
        String soql =
              'SELECT Id, YS_Demande_Id__c, YS_Statut__c '
            + 'FROM ' + sobjectType + ' '
            + 'WHERE YS_Demande_Id__c != null '
            + 'AND YS_Statut__c IN (\'Envoye\', \'Ouvert\') '
            + 'AND YS_Date_Envoi__c >= :depuis';
        return Database.getQueryLocator(soql);
    }

    public void execute(Database.BatchableContext bc, List<SObject> lot) {
        for (SObject record : lot) {
            String demandeId = (String) record.get('YS_Demande_Id__c');
            try {
                traiter(demandeId);
            } catch (Exception e) {
                // Un dossier en échec ne doit pas emporter les 19 autres — mais
                // il ne doit pas non plus disparaître en silence. Un batch qui
                // se contente de tracer en debug finit « Completed », et
                // l'échec ne se voit nulle part : le motif est donc écrit sur
                // l'enregistrement lui-même, comme pour le webhook.
                System.debug(LoggingLevel.ERROR,
                    'YS_ReconciliationBatch : demande ' + demandeId + ' — ' + e.getMessage());
                YS_TraitementSignature.enregistrerErreur(demandeId,
                    e.getTypeName() + ' : ' + e.getMessage());
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        if (sobjectType == 'Lead') {
            Database.executeBatch(new YS_ReconciliationBatch('Pro__c'), TAILLE_LOT);
        }
    }

    /**
     * Un statut Yousign -> l'action correspondante.
     * `ongoing` et `draft` : la demande vit encore, on repassera.
     */
    private void traiter(String demandeId) {
        String statut = YS_YousignService.statutDemande(demandeId);

        if (statut == 'done') {
            YS_TraitementSignature.appliquerSignature(demandeId);

        } else if (statut == 'declined') {
            YS_TraitementSignature.appliquerEchec(demandeId, 'Refuse',
                'Le client a refusé de signer le devis.');

        } else if (statut == 'expired') {
            YS_TraitementSignature.appliquerEchec(demandeId, 'Expire',
                'La demande de signature a expiré.');

        } else if (statut == 'canceled') {
            YS_TraitementSignature.appliquerEchec(demandeId, 'Expire',
                'La demande de signature a été annulée.');
        }
    }
}