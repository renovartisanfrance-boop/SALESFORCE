/**
 * YS_TraiterWebhook — traitement réel d'un webhook Yousign, hors du chemin HTTP.
 *
 * Déclenché par le trigger sur YS_Webhook__e. Le passage par un Queueable n'est
 * pas un confort : un trigger de Platform Event ne peut PAS faire de callout, et
 * il faut en faire un pour récupérer le PDF signé.
 *
 * DÉDUPLICATION — Yousign rejoue ses événements (jusqu'à ce qu'il obtienne un
 * 2xx, et parfois au-delà) et fournit un `event_id` constant à travers les
 * rejeux. On le journalise dans YS_Evenement__c pour ne traiter qu'une fois.
 *
 * ⚠️ ORDRE IMPOSÉ : LECTURE — CALLOUT — ÉCRITURE
 * ──────────────────────────────────────────────
 * La journalisation a lieu À LA FIN, et la vérification du doublon se fait par
 * une simple REQUÊTE. C'est contre-intuitif — on aimerait poser le verrou
 * d'abord — mais un INSERT avant le callout rendait le traitement impossible :
 * Salesforce refuse tout appel sortant une fois qu'un DML est engagé dans la
 * transaction (« You have uncommitted work pending »). Le Queueable attrapait
 * l'exception, se terminait « Completed », et le devis restait en attente sans
 * la moindre trace. Constaté en sandbox le 26/08/2026.
 *
 * Ce que l'on perd : la fenêtre de concurrence entre la requête et l'insertion.
 * Ce que l'on garde : l'idempotence réelle, qui vit de toute façon dans
 * YS_TraitementSignature.appliquerSignature — statut déjà signé, et
 * déduplication du fichier par MD5. Un doublon simultané ne produit donc rien.
 *
 * Bénéfice de bord : si le traitement échoue, aucune ligne de journal n'est
 * écrite, et le rejeu de Yousign est donc réellement retenté.
 */
public without sharing class YS_TraiterWebhook implements Queueable, Database.AllowsCallouts {

    private final String eventId;
    private final String eventName;
    private final String payload;

    public YS_TraiterWebhook(String eventId, String eventName, String payload) {
        this.eventId   = eventId;
        this.eventName = eventName;
        this.payload   = payload;
    }

    public void execute(QueueableContext ctx) {
        try {
            Map<String, Object> json = (Map<String, Object>) JSON.deserializeUntyped(payload);
            String demandeId = extraireDemandeId(json);

            if (String.isBlank(demandeId)) {
                System.debug(LoggingLevel.WARN,
                    'YS_TraiterWebhook : aucun id de demande dans l\'événement ' + eventId);
                return;
            }

            // ── LECTURE : déjà vu ? (une requête, surtout pas un INSERT) ─────
            if (dejaTraite()) {
                System.debug(LoggingLevel.INFO,
                    'YS_TraiterWebhook : événement ' + eventId + ' déjà traité, ignoré.');
                return;
            }

            // Le STATUT de la demande fait foi, pas le nom de l'événement.
            //
            // Yousign peut annoncer une signature terminée sous plusieurs noms
            // selon les événements souscrits : `signature_request.done`, mais
            // aussi `signer.done` quand c'est le seul abonnement en place. Les
            // deux portent le même `data.signature_request.status = "done"`.
            // S'en remettre au seul nom laissait le devis « en attente » alors
            // que le client avait signé — constaté en sandbox.
            //
            // Le garde-fou du multi-signataire est inclus : avec plusieurs
            // signataires, `signer.done` part à CHAQUE signature, mais le statut
            // de la demande ne passe à `done` qu'une fois tout le monde passé.
            String statutDemande = extraireStatut(json);

            if (eventName == 'signature_request.declined' || statutDemande == 'declined') {
                YS_TraitementSignature.appliquerEchec(demandeId, 'Refuse',
                    'Le client a refusé de signer le devis.');

            } else if (eventName == 'signature_request.expired'
                    || eventName == 'signature_request.canceled'
                    || statutDemande == 'expired' || statutDemande == 'canceled') {
                YS_TraitementSignature.appliquerEchec(demandeId, 'Expire',
                    'La demande de signature a expiré ou a été annulée.');

            } else if (statutDemande == 'done' || eventName == 'signature_request.done') {
                // appliquerSignature est idempotent : si les deux événements
                // arrivent pour la même demande, le second ne fait rien.
                YS_TraitementSignature.appliquerSignature(demandeId);

            } else {
                System.debug(LoggingLevel.INFO, 'YS_TraiterWebhook : ' + eventName
                    + ' sur une demande au statut « ' + statutDemande + ' » — rien à faire.');
            }

            // ── ÉCRITURE : le traitement a abouti, on peut marquer l'événement.
            //    En cas d'échec, on n'arrive pas ici : le rejeu sera retenté.
            journaliser(demandeId);

        } catch (Exception e) {
            // ⚠️ Un Queueable qui attrape son exception se termine « Completed,
            // 0 erreur » : sans les deux gestes ci-dessous, l'échec ne laissait
            // AUCUNE trace exploitable. Le webhook arrivait, le job passait au
            // vert, et le devis restait en attente sans explication.
            System.debug(LoggingLevel.ERROR,
                'YS_TraiterWebhook (' + eventName + '/' + eventId + ') : '
                + e.getMessage() + '\n' + e.getStackTraceString());

            String demandeId = null;
            try {
                demandeId = extraireDemandeId(
                    (Map<String, Object>) JSON.deserializeUntyped(payload));
            } catch (Exception ignore) {
                // Payload illisible : il n'y a alors rien à rattacher.
            }

            if (String.isNotBlank(demandeId)) {
                // Rendre l'échec visible là où quelqu'un le verra. Aucune ligne
                // de journal n'ayant été écrite, un rejeu sera bien retenté.
                YS_TraitementSignature.enregistrerErreur(demandeId,
                    e.getTypeName() + ' : ' + e.getMessage());
            }
        }
    }

    /* ════════════════════════════════════════════════════════════════════════
       IDEMPOTENCE
       ════════════════════════════════════════════════════════════════════════ */

    /**
     * Cet événement a-t-il déjà été traité ?
     *
     * Une REQUÊTE, jamais un INSERT : à ce stade de la transaction, un DML
     * interdirait le callout qui suit. Voir l'en-tête de la classe.
     */
    private Boolean dejaTraite() {
        if (String.isBlank(eventId)) {
            // Pas d'identifiant d'événement : rien à dédoublonner. Le traitement
            // reste idempotent de lui-même (voir YS_TraitementSignature).
            return false;
        }
        return ![SELECT Id FROM YS_Evenement__c WHERE EventId__c = :eventId LIMIT 1].isEmpty();
    }

    /**
     * Marque l'événement comme traité, une fois le travail réellement fait.
     *
     * `Database.insert(..., false)` : deux événements simultanés porteraient le
     * même identifiant et le second heurterait la contrainte d'unicité. Ce n'est
     * pas une erreur — c'est le doublon qu'on voulait éviter — et le traitement
     * lui-même est idempotent, donc rien de fâcheux n'a pu se produire.
     */
    private void journaliser(String demandeId) {
        if (String.isBlank(eventId)) return;

        Database.SaveResult r = Database.insert(new YS_Evenement__c(
            EventId__c    = eventId,
            EventName__c  = eventName,
            Demande_Id__c = demandeId
        ), false);

        if (!r.isSuccess()) {
            System.debug(LoggingLevel.INFO,
                'YS_TraiterWebhook : journalisation de ' + eventId + ' refusée — '
                + r.getErrors()[0].getMessage());
        }
    }

    /* ════════════════════════════════════════════════════════════════════════
       LECTURE DU PAYLOAD
       ════════════════════════════════════════════════════════════════════════ */

    /**
     * Identifiant de la Signature Request, quel que soit l'emplacement où
     * Yousign le loge selon l'événement (`data.signature_request.id` pour les
     * événements de demande, `…signature_request_id` pour ceux de signataire).
     */
    @TestVisible
    private static String extraireDemandeId(Map<String, Object> json) {
        Object data = json.get('data');
        if (!(data instanceof Map<String, Object>)) return null;
        Map<String, Object> d = (Map<String, Object>) data;

        Object demande = d.get('signature_request');
        if (demande instanceof Map<String, Object>) {
            Object id = ((Map<String, Object>) demande).get('id');
            if (id != null) return String.valueOf(id);
        }
        Object idPlat = d.get('signature_request_id');
        if (idPlat != null) return String.valueOf(idPlat);

        // Certains événements imbriquent la demande sous le signataire.
        Object signataire = d.get('signer');
        if (signataire instanceof Map<String, Object>) {
            return extraireDemandeId(new Map<String, Object>{
                'data' => (Map<String, Object>) signataire
            });
        }
        return null;
    }

    /**
     * Statut de la demande porté par la charge utile
     * (`data.signature_request.status`) : draft, ongoing, done, declined,
     * expired, canceled.
     *
     * C'est lui qui décide de l'action, plutôt que le nom de l'événement —
     * Yousign annonce la même réalité sous plusieurs noms selon les abonnements
     * souscrits, mais le statut, lui, est univoque.
     */
    @TestVisible
    private static String extraireStatut(Map<String, Object> json) {
        Object data = json.get('data');
        if (!(data instanceof Map<String, Object>)) return null;

        Object demande = ((Map<String, Object>) data).get('signature_request');
        if (demande instanceof Map<String, Object>) {
            Object statut = ((Map<String, Object>) demande).get('status');
            if (statut != null) return String.valueOf(statut);
        }
        return null;
    }
}