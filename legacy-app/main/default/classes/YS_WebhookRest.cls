/**
 * YS_WebhookRest — point d'entrée public des notifications Yousign.
 *
 * ⚠️ CETTE CLASSE EST EXPOSÉE SUR INTERNET, sans authentification Salesforce.
 * Elle est servie par le Site Force.com « yousign », dont l'utilisateur invité
 * n'a QUE deux droits : exécuter cette classe et publier YS_Webhook__e. Aucun
 * accès à Lead, Pro__c ou ContentVersion — le travail réel se fait plus loin,
 * en contexte système.
 *
 * POURQUOI UN SITE DÉDIÉ — le site Experience Cloud « Campagnes » est en LWR,
 * et son routeur ne transmet PAS /services/apexrest/ (404 « Invalid Page »,
 * constaté ; c'est ce qui avait déjà condamné LC021_DevisContratRest). Il faut
 * donc un Site Force.com classique.
 *
 * POURQUOI SI PEU DE CODE ICI — Yousign attend une réponse 2xx en MOINS D'UNE
 * SECONDE, faute de quoi il considère l'appel échoué et rejoue. Télécharger un
 * PDF et écrire en base ne tient pas dans ce budget. On se contente donc de :
 *   1. vérifier que l'appel vient bien de Yousign (HMAC) ;
 *   2. republier le message en Platform Event ;
 *   3. répondre 200.
 * Le traitement réel a lieu dans YS_TraiterWebhook, déclenché par l'événement.
 */
@RestResource(urlMapping='/yousign/webhook')
global without sharing class YS_WebhookRest {

    /** En-tête portant la signature HMAC. Yousign le documente insensible à la casse. */
    private static final String ENTETE_SIGNATURE = 'x-yousign-signature-256';

    /** Valeur par défaut du Custom Label tant que la vraie clé n'a pas été collée. */
    private static final String SENTINELLE_NON_RENSEIGNE = 'A_RENSEIGNER';

    /**
     * Secret de vérification. Normalement lu dans le Custom Label ; les tests le
     * surchargent, faute de quoi ils ne pourraient jamais produire une signature
     * valide — un Custom Label n'est pas modifiable à l'exécution.
     */
    @TestVisible
    private static String secretSurcharge = null;

    private static String secretEffectif() {
        return secretSurcharge != null
            ? secretSurcharge
            : String.valueOf(Label.YOUSIGN_WEBHOOK_SECRET);
    }

    /**
     * Seuls ces événements déclenchent un traitement ; les autres sont acquittés
     * et ignorés.
     *
     * `signer.done` EST dans la liste, et ce n'est pas du zèle : selon les
     * événements souscrits chez Yousign, une signature terminée peut n'arriver
     * QUE sous cette forme — constaté en sandbox, où seul `signer.done` était
     * abonné et où le devis restait donc « en attente » alors que le client
     * avait signé. C'est ensuite le STATUT porté par la charge utile, et non le
     * nom de l'événement, qui décide de l'action (voir YS_TraiterWebhook).
     */
    private static final Set<String> EVENEMENTS_UTILES = new Set<String>{
        'signature_request.done',
        'signature_request.declined',
        'signature_request.expired',
        'signature_request.canceled',
        'signer.done'
    };

    @HttpPost
    global static void recevoir() {
        RestRequest  req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');

        try {
            Blob corps = (req == null) ? null : req.requestBody;
            if (corps == null || corps.size() == 0) {
                repondre(res, 400, 'corps vide');
                return;
            }

            if (!signatureValide(corps, entete(req, ENTETE_SIGNATURE))) {
                // On ne dit pas POURQUOI : un attaquant n'apprend rien d'un 401 nu.
                System.debug(LoggingLevel.WARN, 'YS_WebhookRest : signature HMAC refusée.');
                repondre(res, 401, 'signature invalide');
                return;
            }

            // ⚠️ Ne PAS nommer cette variable « json » : Apex est insensible à
            // la casse, elle masquerait la classe système JSON et l'appel
            // ci-dessous ne compilerait plus.
            Map<String, Object> donnees;
            try {
                donnees = (Map<String, Object>) JSON.deserializeUntyped(corps.toString());
            } catch (Exception e) {
                repondre(res, 400, 'corps illisible');
                return;
            }

            String nom = String.valueOf(donnees.get('event_name'));

            // Acquitté sans traitement : Yousign ne doit pas rejouer un événement
            // dont nous n'avons simplement rien à faire.
            if (!EVENEMENTS_UTILES.contains(nom)) {
                repondre(res, 200, 'ignoré');
                return;
            }

            // ⚠️ Le résultat de la publication DOIT être vérifié. Sans cela, un
            // échec (droit manquant sur l'événement, limite atteinte) passait
            // inaperçu : on répondait 200, Yousign considérait la notification
            // délivrée, et le devis restait « en attente » sans la moindre trace
            // nulle part. Un 500 fait rejouer Yousign, ce qui est exactement ce
            // qu'on veut quand la faute est de notre côté.
            Database.SaveResult publication = EventBus.publish(new YS_Webhook__e(
                EventId__c   = tronquer(String.valueOf(donnees.get('event_id')), 80),
                EventName__c = tronquer(nom, 80),
                Payload__c   = corps.toString()
            ));

            if (!publication.isSuccess()) {
                String motif = publication.getErrors().isEmpty()
                    ? 'cause inconnue'
                    : publication.getErrors()[0].getMessage();
                System.debug(LoggingLevel.ERROR,
                    'YS_WebhookRest : publication de YS_Webhook__e refusée — ' + motif);
                repondre(res, 500, 'publication impossible');
                return;
            }

            repondre(res, 200, 'reçu');

        } catch (Exception e) {
            // Un 5xx ferait rejouer Yousign en boucle sur un bug de notre côté.
            // On acquitte, on trace, et le batch de réconciliation rattrapera.
            System.debug(LoggingLevel.ERROR,
                'YS_WebhookRest : ' + e.getMessage() + '\n' + e.getStackTraceString());
            repondre(res, 200, 'erreur interne tracée');
        }
    }

    /* ════════════════════════════════════════════════════════════════════════
       VÉRIFICATION HMAC
       ════════════════════════════════════════════════════════════════════════ */

    /**
     * HMAC-SHA256 du CORPS BRUT avec le secret du webhook, préfixé « sha256= ».
     *
     * Le calcul porte sur les octets reçus tels quels : refaire un JSON.serialize
     * du corps désérialisé changerait l'ordre des clés et invaliderait la
     * signature. D'où le Blob passé directement à Crypto.generateMac.
     */
    @TestVisible
    private static Boolean signatureValide(Blob corps, String signatureRecue) {
        if (String.isBlank(signatureRecue)) return false;

        String secret = secretEffectif();
        if (String.isBlank(secret) || secret == SENTINELLE_NON_RENSEIGNE) {
            System.debug(LoggingLevel.ERROR,
                'YS_WebhookRest : Custom Label YOUSIGN_WEBHOOK_SECRET non renseigné, tout appel est refusé.');
            return false;
        }

        Blob mac = Crypto.generateMac('hmacSHA256', corps, Blob.valueOf(secret));
        String attendu = 'sha256=' + EncodingUtil.convertToHex(mac).toLowerCase();

        return egalitaireEnTempsConstant(attendu, signatureRecue.trim().toLowerCase());
    }

    /**
     * Comparaison sans court-circuit : une comparaison classique s'arrête au
     * premier caractère différent, et la durée de la réponse renseigne alors sur
     * le nombre de caractères devinés.
     */
    private static Boolean egalitaireEnTempsConstant(String a, String b) {
        if (a == null || b == null || a.length() != b.length()) return false;
        Integer ecart = 0;
        for (Integer i = 0; i < a.length(); i++) {
            ecart |= (a.charAt(i) ^ b.charAt(i));
        }
        return ecart == 0;
    }

    /* ════════════════════════════════════════════════════════════════════════
       OUTILS
       ════════════════════════════════════════════════════════════════════════ */

    /** Lecture d'en-tête insensible à la casse — la map de RestRequest ne l'est pas. */
    private static String entete(RestRequest req, String nomRecherche) {
        if (req == null || req.headers == null) return null;
        for (String cle : req.headers.keySet()) {
            if (cle != null && cle.equalsIgnoreCase(nomRecherche)) {
                return req.headers.get(cle);
            }
        }
        return null;
    }

    private static void repondre(RestResponse res, Integer code, String message) {
        res.statusCode = code;
        res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
            'status' => code < 300 ? 'ok' : 'error',
            'detail' => message
        }));
    }

    private static String tronquer(String valeur, Integer max) {
        if (String.isBlank(valeur) || valeur == 'null') return null;
        return valeur.length() <= max ? valeur : valeur.substring(0, max);
    }
}