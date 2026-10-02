/**
 * LC027_CertikoRetour — WEBHOOK que Certiko appelle à chaque changement de
 * colonne sur un dossier du tableau gestion-install-res060.
 *
 * Sens INVERSE de LC027_Certiko : ici c'est Certiko qui pousse, sans qu'on
 * demande rien. Aujourd'hui une seule colonne nous intéresse (`status_vt`),
 * d'autres viendront — c'est la carte COLONNES qui décide.
 *
 * ┌── ENDPOINT ───────────────────────────────────────────────────────────────
 * │ POST https://<domaine>/services/apexrest/WHCertikoChangeColumn
 * │ En-tête : aucun (voir AUTHENTIFICATION plus bas)
 * │ Corps   : le tableau d'événements de Certiko (voir plus bas)
 * │ ⚠️ A LA RACINE DU DOMAINE, pas sous le chemin du site : le routeur LWR ne
 * │    sert pas /services/apexrest/ (même constat que LC027_GestionContrat).
 * └───────────────────────────────────────────────────────────────────────────
 *
 * CORPS REÇU — un TABLEAU, même pour un seul changement :
 * [{ "event": "dossier.field_changed",
 *    "change":  { "column": { "slug": "status_vt" },
 *                 "new_value": "terminee", "old_value": "en_cours" },
 *    "dossier": { "id": "1c2506e0-…", "reference": "1985697503",
 *                 "values": { "status_vt": "terminee" } } }]
 * `dossier.values` fait foi : il porte l'état COMPLET du dossier après le
 * changement, là où `change` ne dit que ce qui a bougé. Prendre l'état complet
 * rattrape au passage un événement perdu plus tôt. `change` sert de repli.
 *
 * TOUJOURS 200 quand le corps est compris, même si un dossier est inconnu :
 * un webhook non-2xx est REJOUÉ par Certiko, et rejouer ne fera pas apparaître
 * un dossier qui n'existe pas chez nous. Le détail par événement part dans la
 * réponse, que Certiko garde dans son journal de livraison.
 *
 * DEUX EFFETS APRÈS L'ENREGISTREMENT :
 *   • un événement Certiko_Maj__e, auquel le portail est abonné. Il ne PORTE
 *     rien de décisif : c'est ce webhook qui a déjà écrit le statut. L'événement
 *     sert de sonnette — la fiche ouverte relit la base et se réaffiche, sans
 *     que le pré-visiteur rafraîchisse sa page ;
 *   • quand la visite se TERMINE, la colonne CERTIKO_COLONNE_FIN_VT est vidée
 *     chez Certiko. L'appel part en asynchrone : Salesforce refuse un appel
 *     sortant après une écriture dans la même transaction.
 *
 * ⚠️ AUCUNE AUTHENTIFICATION AUJOURD'HUI — décision du 2026-09-23 : Certiko
 * appelle ce webhook sans en-tête. Qui connaît l'URL et une référence de
 * dossier peut donc en changer le statut de visite.
 *
 * Ce que la classe borne malgré tout : elle ne crée ni ne supprime rien, elle
 * n'écrit que les colonnes listées dans COLONNES, et seulement des valeurs de
 * la liste de sélection. Le pire cas reste un statut de visite faux sur un
 * dossier dont l'appelant connaissait déjà la référence Certiko.
 *
 * POUR REFERMER LA PORTE, sans déploiement : remplacer la valeur du Custom
 * Label CERTIKO_TOKEN_ENTRANT — aujourd'hui « OUVERT » — par un vrai jeton,
 * et le faire envoyer par Certiko dans `X-API-Key`. Un label ne peut pas être
 * vide (Salesforce en exige une valeur), d'où ce mot convenu plutôt qu'un
 * blanc que personne ne saurait lire.
 *
 * ⚠️ PAS `Authorization` le jour où le jeton reviendra — Salesforce se le
 * réserve pour sa propre authentification et REFUSE qu'on le lise
 * (InvalidHeaderException) : l'appel serait rejeté avant d'arriver ici.
 *
 * UNE VALEUR HORS LISTE N'EST PAS ÉCRITE — `status_vt` est une liste de
 * sélection des deux côtés. Si Certiko ouvre un statut que nous n'avons pas, le
 * dossier garde le sien et la réponse dit lequel a été refusé. Ajouter le
 * statut dans la liste Salesforce suffit ensuite à l'accepter.
 *
 * AJOUTER UNE COLONNE — une ligne dans COLONNES ci-dessous, et c'est tout.
 * Volontairement dans le code, et non dans Certiko_Champ__mdt : cette table-là
 * décrit ce que NOUS envoyons ; mélanger les deux sens dans un même réglage
 * ferait qu'un champ retiré de l'envoi disparaîtrait aussi de la réception.
 *
 * without sharing : l'appel arrive sans utilisateur (invité du site), et le
 * webhook n'en demande pas. Ce qui protège les dossiers est la portée
 * volontairement étroite de ce que cette classe sait écrire.
 */
@RestResource(urlMapping='/WHCertikoChangeColumn/*')
global without sharing class LC027_CertikoRetour {

    /**
     * Colonnes Certiko suivies -> champ du Dossier.
     * Une colonne absente d'ici est ignorée : Certiko nous pousse TOUS les
     * changements du tableau, la plupart ne nous concernent pas.
     */
    private static final Map<String, Schema.SObjectField> COLONNES =
        new Map<String, Schema.SObjectField>{
            'status_vt' => Pro__c.CERTIKO_Statut_VT__c
        };

    /**
     * En-têtes acceptés pour le jeton, en minuscules — seulement si le label
     * CERTIKO_TOKEN_ENTRANT est rempli (voir jetonValide).
     */
    private static final Set<String> ENTETES_JETON = new Set<String>{ 'x-api-key' };

    @HttpPost
    global static void recevoirPost() {
        traiter();
    }

    /** Même traitement : certains clients préfèrent PATCH pour une mise à jour. */
    @HttpPatch
    global static void recevoirPatch() {
        traiter();
    }

    /* ════════════════════════════════════════════════════════════════════════
       TRAITEMENT
       ════════════════════════════════════════════════════════════════════════ */

    private static void traiter() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        if (res == null) {
            res = new RestResponse();
            RestContext.response = res;
        }
        res.addHeader('Content-Type', 'application/json; charset=UTF-8');

        if (!jetonValide(req)) {
            repondre(res, 401, new Map<String, Object>{ 'error' => 'Jeton absent ou invalide.' });
            return;
        }

        List<Object> evenements;
        try {
            String brut = (req != null && req.requestBody != null) ? req.requestBody.toString() : '';
            if (String.isBlank(brut)) {
                repondre(res, 400, new Map<String, Object>{ 'error' => 'Corps de requete vide.' });
                return;
            }
            evenements = enListe(JSON.deserializeUntyped(brut));
        } catch (Exception e) {
            repondre(res, 400, new Map<String, Object>{ 'error' => 'JSON invalide.' });
            return;
        }
        if (evenements.isEmpty()) {
            repondre(res, 400, new Map<String, Object>{ 'error' => 'Aucun evenement dans le corps.' });
            return;
        }

        List<Object> resultats = new List<Object>();
        for (Object element : evenements) {
            if (element instanceof Map<String, Object>) {
                resultats.add(traiterUnEvenement((Map<String, Object>) element));
            }
        }
        repondre(res, 200, new Map<String, Object>{
            'ok' => true,
            'traites' => resultats.size(),
            'resultats' => resultats
        });
    }

    /** Un événement du tableau -> un compte rendu, jamais une exception. */
    private static Map<String, Object> traiterUnEvenement(Map<String, Object> evt) {
        Map<String, Object> dossierCertiko = sousObjet(evt, 'dossier');
        String cle = identifiant(dossierCertiko);
        Map<String, Object> compteRendu = new Map<String, Object>{
            'reference' => texte(dossierCertiko, 'reference'),
            'cle' => cle
        };
        if (String.isBlank(cle)) {
            compteRendu.put('etat', 'sans_identifiant');
            return compteRendu;
        }

        List<Pro__c> dossiers = [
            SELECT Id, CERTIKO_Dossier_Id__c, CERTIKO_Reference__c, CERTIKO_Statut_VT__c
            FROM Pro__c
            WHERE CERTIKO_Dossier_Id__c = :cle OR CERTIKO_Reference__c = :cle
            LIMIT 2
        ];
        if (dossiers.isEmpty()) {
            // Répondre en erreur ferait rejouer Certiko en boucle pour un
            // dossier qui n'existera pas davantage au prochain essai.
            compteRendu.put('etat', 'dossier_inconnu');
            return compteRendu;
        }
        if (dossiers.size() > 1) {
            compteRendu.put('etat', 'cle_en_double');
            return compteRendu;
        }
        Pro__c dossier = dossiers[0];
        compteRendu.put('dossier', dossier.Id);

        Map<String, Object> valeurs = valeursDe(evt);
        if (valeurs.isEmpty()) {
            compteRendu.put('etat', 'aucune_valeur');
            return compteRendu;
        }

        Pro__c maj = new Pro__c(Id = dossier.Id);
        List<String> appliquees = new List<String>();
        List<Object> refusees = new List<Object>();
        String nouveauStatut = null;
        for (String colonne : valeurs.keySet()) {
            Schema.SObjectField champ = COLONNES.get(colonne.toLowerCase());
            if (champ == null) {
                continue;   // colonne du tableau qui ne nous concerne pas
            }
            Object valeur = valeurs.get(colonne);
            String v = valeur == null ? null : String.valueOf(valeur).trim();
            // Une valeur vide n'efface rien : Certiko pousse l'état complet du
            // dossier, une colonne qu'il n'a jamais remplie y figure à vide.
            if (String.isBlank(v)) {
                continue;
            }
            if (!LC027_Certiko.valeurAdmise(champ, v)) {
                refusees.add(new Map<String, Object>{
                    'colonne' => colonne,
                    'valeur' => v,
                    'valeurs_attendues' => LC027_Certiko.valeursAdmises(champ)
                });
                continue;
            }
            Object actuel = dossier.get(champ);
            if (v != (actuel == null ? null : String.valueOf(actuel))) {
                maj.put(champ, v);
                appliquees.add(colonne);
                if (champ == Pro__c.CERTIKO_Statut_VT__c) {
                    nouveauStatut = v;
                }
            }
        }
        if (!refusees.isEmpty()) {
            compteRendu.put('colonnes_refusees', refusees);
        }
        if (appliquees.isEmpty()) {
            compteRendu.put('etat', refusees.isEmpty() ? 'inchange' : 'valeur_refusee');
            return compteRendu;
        }

        maj.CERTIKO_Statut_Maj__c = System.now();
        try {
            update maj;
        } catch (DmlException e) {
            compteRendu.put('etat', 'refus_salesforce');
            compteRendu.put('message', e.getDmlMessage(0));
            return compteRendu;
        }
        compteRendu.put('etat', 'applique');
        compteRendu.put('colonnes_appliquees', appliquees);

        prevenirLePortail(dossier, appliquees, valeurs);
        if (finDeVisite(nouveauStatut)) {
            viderChezCertiko(dossier);
            compteRendu.put('nettoyage_certiko', System.Label.CERTIKO_COLONNE_FIN_VT);
        }
        return compteRendu;
    }

    /* ════════════════════════════════════════════════════════════════════════
       APRÈS L'ENREGISTREMENT
       ════════════════════════════════════════════════════════════════════════ */

    /**
     * Prévient le portail qu'un dossier a bougé.
     *
     * L'événement ne TRANSPORTE pas l'information utile : le statut est déjà
     * écrit sur le Dossier par ce webhook. Il sert de sonnette — la fiche
     * ouverte relit la base et se réaffiche, sans que le pré-visiteur
     * rafraîchisse sa page.
     *
     * PublishAfterCommit : rien ne part si l'enregistrement n'a pas été validé,
     * sinon le portail irait relire un statut que la base ne porte pas.
     */
    private static void prevenirLePortail(Pro__c dossier, List<String> colonnes,
            Map<String, Object> valeurs) {
        List<Certiko_Maj__e> messages = new List<Certiko_Maj__e>();
        for (String colonne : colonnes) {
            Object valeur = valeurs.get(colonne);
            messages.add(new Certiko_Maj__e(
                Dossier_Id__c = String.valueOf(dossier.Id),
                Reference__c = dossier.CERTIKO_Reference__c,
                Colonne__c = colonne,
                Valeur__c = valeur == null ? null : String.valueOf(valeur).abbreviate(255)
            ));
        }
        if (!messages.isEmpty()) {
            EventBus.publish(messages);
        }
    }

    /** La visite vient-elle de se terminer ? La valeur est un réglage. */
    @TestVisible
    private static Boolean finDeVisite(String statut) {
        String fin = System.Label.CERTIKO_STATUT_FIN_VT;
        return String.isNotBlank(statut) && String.isNotBlank(fin) && statut == fin.trim();
    }

    /**
     * Vide la colonne de fin de visite chez Certiko.
     *
     * EN ASYNCHRONE, et pas par choix de style : Salesforce refuse un appel
     * sortant après une écriture dans la même transaction (« uncommitted work
     * pending »). La file d'attente reprend donc la main après validation.
     */
    private static void viderChezCertiko(Pro__c dossier) {
        String cle = String.isNotBlank(dossier.CERTIKO_Dossier_Id__c)
            ? dossier.CERTIKO_Dossier_Id__c
            : dossier.CERTIKO_Reference__c;
        if (String.isBlank(cle) || Test.isRunningTest()) {
            // En test, la file d'attente ne part pas après un DML : l'appel est
            // vérifié directement sur LC027_Certiko.viderColonne.
            return;
        }
        System.enqueueJob(new NettoyageCertiko(cle, System.Label.CERTIKO_COLONNE_FIN_VT));
    }

    /** Appel sortant différé : vider une colonne chez Certiko. */
    public class NettoyageCertiko implements Queueable, Database.AllowsCallouts {
        private String cle;
        private String colonne;
        public NettoyageCertiko(String cle, String colonne) {
            this.cle = cle;
            this.colonne = colonne;
        }
        public void execute(QueueableContext contexte) {
            try {
                LC027_Certiko.viderColonne(cle, colonne);
            } catch (Exception e) {
                // Le dossier est à jour chez nous : ce nettoyage est un confort
                // côté Certiko, il ne doit pas faire échouer la réception.
                System.debug(LoggingLevel.WARN,
                    'Nettoyage Certiko impossible (' + cle + ') : ' + e.getMessage());
            }
        }
    }

    /* ════════════════════════════════════════════════════════════════════════
       LECTURE DU CORPS
       ════════════════════════════════════════════════════════════════════════ */

    /** Certiko envoie un tableau ; un objet seul est accepté par tolérance. */
    private static List<Object> enListe(Object corps) {
        if (corps instanceof List<Object>) {
            return (List<Object>) corps;
        }
        return new List<Object>{ corps };
    }

    /**
     * Valeurs à appliquer. `dossier.values` porte l'état COMPLET après
     * changement : le prendre rattrape un événement perdu plus tôt. À défaut,
     * on se rabat sur la seule colonne qui a bougé.
     */
    private static Map<String, Object> valeursDe(Map<String, Object> evt) {
        Map<String, Object> valeurs = sousObjet(sousObjet(evt, 'dossier'), 'values');
        if (!valeurs.isEmpty()) {
            return valeurs;
        }
        Map<String, Object> changement = sousObjet(evt, 'change');
        String colonne = texte(sousObjet(changement, 'column'), 'slug');
        if (String.isBlank(colonne)) {
            return new Map<String, Object>();
        }
        return new Map<String, Object>{ colonne => changement.get('new_value') };
    }

    /** Identifiant Certiko du dossier, ou sa référence à défaut. */
    private static String identifiant(Map<String, Object> dossier) {
        String id = texte(dossier, 'id');
        return String.isNotBlank(id) ? id : texte(dossier, 'reference');
    }

    private static Map<String, Object> sousObjet(Map<String, Object> parent, String cle) {
        Object valeur = parent == null ? null : parent.get(cle);
        return (valeur instanceof Map<String, Object>)
            ? (Map<String, Object>) valeur
            : new Map<String, Object>();
    }

    private static String texte(Map<String, Object> source, String cle) {
        Object valeur = source == null ? null : source.get(cle);
        return valeur == null ? null : String.valueOf(valeur).trim();
    }

    /* ════════════════════════════════════════════════════════════════════════
       JETON
       ════════════════════════════════════════════════════════════════════════ */

    /** Valeur du label qui OUVRE le webhook : aucun jeton n'est alors exigé. */
    private static final String JETON_OUVERT = 'OUVERT';

    /**
     * Jeton attendu — INTERRUPTEUR, pas une simple vérification.
     *
     * Label à « OUVERT » : le webhook est ouvert, c'est la situation demandée
     * aujourd'hui. Toute autre valeur devient un jeton obligatoire, que Certiko
     * envoie dans X-API-Key. Refermer la porte ne demande donc pas de
     * déploiement, seulement de changer le label des deux côtés.
     */
    private static Boolean jetonValide(RestRequest req) {
        String attendu = System.Label.CERTIKO_TOKEN_ENTRANT;
        if (String.isBlank(attendu) || attendu.trim() == JETON_OUVERT) {
            return true;
        }
        return attendu.trim() == jetonRecu(req);
    }

    /** Jeton de la requête, quel que soit l'en-tête utilisé. */
    private static String jetonRecu(RestRequest req) {
        if (req == null || req.headers == null) {
            return null;
        }
        for (String nom : req.headers.keySet()) {
            if (!ENTETES_JETON.contains(nom.toLowerCase())) {
                continue;
            }
            String valeur = req.headers.get(nom);
            if (String.isBlank(valeur)) {
                continue;
            }
            valeur = valeur.trim();
            // Tolère « Bearer <jeton> » : la forme vient naturellement sous la
            // plume, même sur un en-tête qui n'est pas Authorization.
            if (valeur.toLowerCase().startsWith('bearer ')) {
                valeur = valeur.substring(7).trim();
            }
            if (String.isNotBlank(valeur)) {
                return valeur;
            }
        }
        return null;
    }

    private static void repondre(RestResponse res, Integer code, Map<String, Object> corps) {
        res.statusCode = code;
        res.responseBody = Blob.valueOf(JSON.serialize(corps));
    }
}