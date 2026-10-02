/**
 * YS_YousignService — client HTTP de l'API Yousign v3.
 *
 * Cette classe ne connaît RIEN du devis, du Lead ni du Pro__c : elle traduit des
 * appels REST, rien de plus. Toute la logique métier vit dans
 * LC021_DevisSignature (envoi) et YS_TraitementSignature (retour).
 *
 * CONFIGURATION — trois Custom Labels, aucune valeur en dur :
 *   • YOUSIGN_API_ENDPOINT    racine de l'API (sandbox ou production)
 *   • YOUSIGN_API_TOKEN       clé API, envoyée en Bearer
 *   • YOUSIGN_CHAMP_SIGNATURE emplacement du champ de signature,
 *                               « page|x|y|largeur|hauteur »
 *
 * Passer de la sandbox à la production ne demande donc AUCUN déploiement de
 * code : on change la valeur de deux labels.
 *
 * `without sharing` : appelée depuis le portail Campagnes, qui tourne sous le
 * Guest User du site. Voir l'en-tête de LC021_DevisSignature pour le détail du
 * modèle de sécurité — il est APPLICATIF (token de campagne), pas déclaratif.
 */
public without sharing class YS_YousignService {

    /** Erreur remontée par l'API Yousign, ou impossibilité de la joindre. */
    public class YousignException extends Exception {}

    /** Destinataire de la demande de signature. */
    public class Signataire {
        public String prenom;
        public String nom;
        public String email;
        /** 'fr' ou 'es' — pilote la langue de l'email et de l'interface Yousign. */
        public String locale;

        public Signataire(String prenom, String nom, String email, String locale) {
            this.prenom = prenom;
            this.nom    = nom;
            this.email  = email;
            this.locale = String.isBlank(locale) ? 'fr' : locale.toLowerCase();
        }
    }

    /**
     * Emplacement du champ de signature sur le document.
     *
     * `largeur` et `hauteur` sont facultatives : omises, Yousign applique sa
     * taille par défaut. PlaceIt les fournit pourtant, et les reprendre évite
     * que le cadre déborde sur le texte imprimé autour.
     */
    public class Position {
        public Integer page;
        public Integer x;
        public Integer y;
        public Integer largeur;
        public Integer hauteur;

        public Position(Integer page, Integer x, Integer y) {
            this(page, x, y, null, null);
        }

        public Position(Integer page, Integer x, Integer y, Integer largeur, Integer hauteur) {
            this.page    = page;
            this.x       = x;
            this.y       = y;
            this.largeur = largeur;
            this.hauteur = hauteur;
        }
    }

    /* ════════════════════════════════════════════════════════════════════════
       APPELS
       ════════════════════════════════════════════════════════════════════════ */

    /**
     * 1/4 — crée la demande de signature (encore vide).
     *
     * `delivery_mode: email` : c'est Yousign qui enverra le mail au signataire à
     * l'activation. La signature embarquée dans le portail n'est pas une option
     * ici — la CSP du site LWR interdit tout iframe, comme l'a montré le travail
     * sur l'aperçu du document (blob:, apexrest et servlet fichiers ont tous été
     * refusés).
     *
     * @return l'identifiant de la Signature Request.
     */
    public static String creerDemande(String nom, String locale) {
        Map<String, Object> corps = new Map<String, Object>{
            'name'          => tronquer(nom, 255),
            'delivery_mode' => 'email',
            'timezone'      => 'Europe/Paris'
        };

        // Espace de travail et identite visuelle : envoyes SEULEMENT s'ils sont
        // configures. Transmettre un null ferait refuser la demande, et laisser
        // Yousign choisir est un comportement parfaitement valable.
        //
        // ⚠️ LES DEUX NE FONT PAS LA MEME CHOSE. `workspace_id` decide OU la
        // demande est rangee ; c'est `branding_id` qui decide de ce que le
        // client VOIT — nom d'expediteur, logo, couleurs de l'email et de la
        // page de signature. Un workspace applique son branding par defaut,
        // sans plus : pour imposer une identite precise, c'est le second qu'il
        // faut renseigner.
        String workspace = reglage(String.valueOf(Label.YOUSIGN_WORKSPACE_ID));
        if (workspace != null) corps.put('workspace_id', workspace);

        String branding = reglage(String.valueOf(Label.YOUSIGN_BRANDING_ID));
        if (branding != null) corps.put('branding_id', branding);

        // Nom d'expediteur affiche au client — dans l'objet du mail, dans le
        // corps, et dans la signature du message.
        //
        // POURQUOI ICI ET PAS DANS LE COMPTE YOUSIGN — le compte est partage
        // avec d'autres integrations, qui doivent continuer a s'annoncer sous
        // leur propre nom. Renommer l'organisation ou l'espace de travail les
        // renommerait toutes. `email_notification` se declare requete par
        // requete : seules les demandes emises par ce code sont concernees.
        String expediteur = reglage(expediteurSurcharge != null
            ? expediteurSurcharge
            : String.valueOf(Label.YOUSIGN_EXPEDITEUR));
        if (expediteur != null) {
            corps.put('email_notification', new Map<String, Object>{
                'sender' => new Map<String, Object>{
                    'type'        => 'custom',
                    'custom_name' => tronquer(expediteur, 255)
                }
            });
        }

        HttpRequest req = requete('POST', '/signature_requests');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(corps));
        return texte(envoyer(req, 'creerDemande'), 'id');
    }

    /**
     * Valeur d'une etiquette facultative, ou null si elle n'est pas renseignee.
     *
     * « AUTO » signifie « laisser Yousign decider » — une etiquette Salesforce
     * ne pouvant pas etre vide, il faut bien une sentinelle.
     */
    @TestVisible
    private static String reglage(String valeur) {
        if (String.isBlank(valeur)) return null;
        String v = valeur.trim();
        return v.equalsIgnoreCase('AUTO') ? null : v;
    }

    /**
     * 2/4 — attache le PDF à signer.
     *
     * L'API attend du multipart/form-data, que Apex ne sait pas produire
     * nativement : voir corpsMultipart() pour la construction.
     *
     * @return l'identifiant du document, nécessaire pour positionner la signature.
     */
    public static String ajouterDocument(String demandeId, Blob pdf, String nomFichier) {
        HttpRequest req = requete('POST', '/signature_requests/' + demandeId + '/documents');
        req.setHeader('Content-Type', 'multipart/form-data; boundary=' + FRONTIERE);
        req.setBodyAsBlob(corpsMultipart(pdf, nomFichier));
        return texte(envoyer(req, 'ajouterDocument'), 'id');
    }

    /**
     * 3/4 — déclare le signataire et l'endroit où il signera.
     *
     * `no_otp` : le client signe depuis le lien reçu par mail, sans code
     * supplémentaire. `electronic_signature` est le niveau simple, suffisant
     * pour un devis.
     */
    public static String ajouterSignataire(String demandeId, String documentId,
                                           Signataire s, Position pos) {
        HttpRequest req = requete('POST', '/signature_requests/' + demandeId + '/signers');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(new Map<String, Object>{
            'info' => new Map<String, Object>{
                'first_name'   => tronquer(s.prenom, 255),
                'last_name'    => tronquer(s.nom, 255),
                'email'        => s.email,
                'locale'       => s.locale,
                'phone_number' => null
            },
            'signature_level'               => 'electronic_signature',
            'signature_authentication_mode' => 'no_otp',
            'fields' => champs(documentId, pos, s.locale)
        }));
        return texte(envoyer(req, 'ajouterSignataire'), 'id');
    }

    /**
     * Les champs posés sur le document : le cadre de signature, et — si elle est
     * configurée — la mention qui l'accompagne.
     *
     * ⚠️ En API v3, la mention n'est PAS une propriété du champ signature (elle
     * l'était en v2) : c'est un champ à part entière, de type « mention ».
     *
     * Elle n'est envoyée que si YOUSIGN_CHAMP_MENTION porte une position.
     * « DESACTIVE » = pas de mention, sans qu'aucune ligne de code ne change.
     * (Une étiquette Salesforce ne peut pas être vide, d'où la sentinelle.)
     */
    private static List<Object> champs(String documentId, Position posSignature, String locale) {
        List<Object> liste = new List<Object>{ champSignature(documentId, posSignature) };

        Position posMention = positionMention();
        String texte = texteMention(locale);
        if (posMention != null && String.isNotBlank(texte)) {
            liste.add(champMention(documentId, posMention, texte));
        }
        return liste;
    }

    /**
     * Un champ de mention. `%date%` et `%datetime%` y sont remplacés par Yousign
     * au moment de la signature — c'est la seule façon d'y faire figurer une
     * date, puisque nous ignorons quand le client signera.
     */
    private static Map<String, Object> champMention(String documentId, Position pos, String texte) {
        Map<String, Object> champ = new Map<String, Object>{
            'type'        => 'mention',
            'document_id' => documentId,
            'page'        => pos.page,
            'x'           => pos.x,
            'y'           => pos.y,
            // 255 caractères maximum côté Yousign, et pas de HTML.
            'mention'     => tronquer(texte.trim(), 255)
        };
        if (pos.largeur != null) champ.put('width', pos.largeur);
        if (pos.hauteur != null) champ.put('height', pos.hauteur);
        return champ;
    }

    /**
     * Surcharges de test. Un Custom Label n'est pas modifiable à l'exécution :
     * sans ces deux crans, aucun test ne pourrait couvrir la mention, puisque le
     * label part vide par défaut. Même procédé que YS_WebhookRest.secretSurcharge.
     */
    /** Valeur du label signifiant « pas de mention » — une étiquette ne peut pas être vide. */
    private static final String MENTION_DESACTIVEE = 'DESACTIVE';

    @TestVisible private static String positionMentionSurcharge = null;
    @TestVisible private static String texteMentionSurcharge    = null;

    /* ════════════════════════════════════════════════════════════════════════
       REGLAGES PORTES PAR LA FICHE PRODUIT
       ════════════════════════════════════════════════════════════════════════
       Langue, expediteur et emplacements VARIENT d'une fiche a l'autre. Un
       Custom Label est unique pour toute l'org : une deuxieme fiche signable y
       aurait ecrase la premiere. Ces valeurs vivent donc desormais dans le
       catalogue produits (c/lwc000_utils), et arrivent ici par la demande.

       Les labels YOUSIGN_* restent le REPLI, pour une fiche qui ne declarerait
       rien : rien ne casse tant qu'ils sont renseignes.

       Portee : la transaction. Un envoi = une transaction = une fiche, donc
       aucun risque de fuite d'un envoi sur l'autre. appliquerReglages() est
       appele par LC021_DevisSignature avant la sequence d'appels. */
    @TestVisible private static String localeSurcharge           = null;
    @TestVisible private static String expediteurSurcharge       = null;
    @TestVisible private static String positionSignatureSurcharge = null;

    /**
     * Applique les reglages d'une fiche pour la transaction en cours.
     *
     * Chaque valeur absente laisse le label en place : une fiche peut donc
     * n'imposer que sa langue et hériter du reste.
     *
     * @param reglages { langue, expediteur, champSignature, champMention },
     *                 tel que produit par reglagesSignature() cote LWC.
     */
    public static void appliquerReglages(Map<String, Object> reglages) {
        if (reglages == null) return;
        localeSurcharge            = texteNonVide(reglages.get('langue'));
        expediteurSurcharge        = texteNonVide(reglages.get('expediteur'));
        positionSignatureSurcharge = texteNonVide(reglages.get('champSignature'));
        positionMentionSurcharge   = texteNonVide(reglages.get('champMention'));
    }

    /** Valeur textuelle utilisable, ou null — un blanc vaut « non renseigne ». */
    private static String texteNonVide(Object valeur) {
        if (valeur == null) return null;
        String t = String.valueOf(valeur).trim();
        return String.isBlank(t) ? null : t;
    }

    /**
     * Langue du signataire chez Yousign : celle de l'email reçu, de l'interface
     * de signature, et donc de la mention imprimée.
     *
     * ⚠️ ELLE NE SUIT PAS LA LANGUE DU PORTAIL, et c'est délibéré. Le portail
     * s'affiche dans la langue de l'OPÉRATEUR (dérivée du pays de la campagne,
     * et modifiable par un sélecteur sur les campagnes espagnoles) ; l'email,
     * lui, s'adresse au CLIENT. Faire dépendre le second du premier laissait un
     * opérateur basculer son écran en français et envoyer, ce faisant, un email
     * français à un client espagnol.
     *
     * Le Custom Label YOUSIGN_LOCALE tranche :
     *   • « es » ou « fr » — imposée, quel que soit le portail (réglage livré : es) ;
     *   • « auto »         — on retombe sur la langue du portail.
     *
     * @param languePortail langue d'affichage transmise par le composant.
     */
    public static String localeSignataire(String languePortail) {
        String reglage = localeSurcharge != null
            ? localeSurcharge
            : String.valueOf(Label.YOUSIGN_LOCALE);
        reglage = String.isBlank(reglage) ? '' : reglage.trim().toLowerCase();

        if (reglage == 'es' || reglage == 'fr') return reglage;

        // 'auto', ou valeur inattendue : la langue du portail, à défaut le français.
        return (String.isNotBlank(languePortail)
                && languePortail.toLowerCase().startsWith('es')) ? 'es' : 'fr';
    }

    /** Position de la mention, ou null si le label n'est pas renseigné. */
    private static Position positionMention() {
        String valeur = positionMentionSurcharge != null
            ? positionMentionSurcharge
            : String.valueOf(Label.YOUSIGN_CHAMP_MENTION);

        if (String.isBlank(valeur) || valeur.trim().equalsIgnoreCase(MENTION_DESACTIVEE)) {
            return null;
        }
        return lirePosition(valeur, 'YOUSIGN_CHAMP_MENTION');
    }

    /** Texte de la mention dans la langue du signataire. */
    private static String texteMention(String locale) {
        if (texteMentionSurcharge != null) return texteMentionSurcharge;
        return (locale == 'es')
            ? String.valueOf(Label.YOUSIGN_MENTION_ES)
            : String.valueOf(Label.YOUSIGN_MENTION_FR);
    }

    /**
     * Un champ de signature. Les dimensions ne sont transmises que si elles sont
     * connues : envoyer `null` ferait échouer la validation côté Yousign, qui
     * attend un entier ou rien.
     *
     * ⚠️ Yousign impose au cadre de signature un rapport de 2,3 pour 1 et le
     * redimensionne d'office s'il ne le respecte pas. Une mesure relevée dans
     * PlaceIt peut donc ne pas être appliquée telle quelle.
     */
    private static Map<String, Object> champSignature(String documentId, Position pos) {
        Map<String, Object> champ = new Map<String, Object>{
            'type'        => 'signature',
            'document_id' => documentId,
            'page'        => pos.page,
            'x'           => pos.x,
            'y'           => pos.y
        };
        if (pos.largeur != null) champ.put('width', pos.largeur);
        if (pos.hauteur != null) champ.put('height', pos.hauteur);
        return champ;
    }

    /** 4/4 — active la demande : c'est CET appel qui déclenche l'email au client. */
    public static void activer(String demandeId) {
        HttpRequest req = requete('POST', '/signature_requests/' + demandeId + '/activate');
        req.setHeader('Content-Type', 'application/json');
        req.setBody('{}');
        envoyer(req, 'activer');
    }

    /**
     * Statut courant d'une demande : draft, ongoing, done, canceled, expired,
     * declined, approval. Utilisé par le batch de réconciliation, qui rattrape
     * les webhooks perdus.
     */
    public static String statutDemande(String demandeId) {
        HttpRequest req = requete('GET', '/signature_requests/' + demandeId);
        return texte(envoyer(req, 'statutDemande'), 'status');
    }

    /**
     * PDF signé, tous documents de la demande réunis.
     *
     * Réponse binaire : on ne passe donc PAS par envoyer(), qui suppose du JSON.
     */
    public static Blob telechargerSigne(String demandeId) {
        HttpRequest req = requete('GET', '/signature_requests/' + demandeId + '/documents/download');
        req.setHeader('Accept', 'application/pdf');

        HttpResponse res = new Http().send(req);
        if (!estSucces(res.getStatusCode())) {
            System.debug(LoggingLevel.ERROR,
                'YS_YousignService.telechargerSigne HTTP ' + res.getStatusCode() + ' : ' + res.getBody());
            throw new YousignException('Téléchargement du devis signé impossible (code '
                + res.getStatusCode() + ').');
        }
        Blob pdf = res.getBodyAsBlob();
        if (pdf == null || pdf.size() == 0) {
            throw new YousignException('Yousign a renvoyé un document vide.');
        }
        return pdf;
    }

    /* ════════════════════════════════════════════════════════════════════════
       POSITION DU CHAMP DE SIGNATURE
       ════════════════════════════════════════════════════════════════════════ */

    /**
     * Lit « page|x|y|largeur|hauteur » depuis le Custom Label
     * YOUSIGN_CHAMP_SIGNATURE. La forme courte « page|x|y » reste acceptée :
     * Yousign applique alors sa taille par défaut.
     *
     * ⚠️ Ces coordonnées sont relevées avec l'outil PlaceIt de Yousign, dont
     * l'origine est en HAUT à gauche. Elles ne sont donc pas interchangeables
     * avec les constantes PDF_CASES_PUISSANCE de devisConfig.js, que pdf-lib
     * exprime depuis le BAS à gauche.
     */
    public static Position positionSignature() {
        return positionSignatureSurcharge != null
            ? lirePosition(positionSignatureSurcharge, 'signature.champSignature')
            : lirePosition(String.valueOf(Label.YOUSIGN_CHAMP_SIGNATURE), 'YOUSIGN_CHAMP_SIGNATURE');
    }

    /** Analyse « page|x|y » ou « page|x|y|largeur|hauteur ». */
    private static Position lirePosition(String valeur, String nomLabel) {
        List<String> morceaux = valeur.split('\\|');

        if (morceaux.size() != 3 && morceaux.size() != 5) {
            throw new YousignException('Custom Label ' + nomLabel + ' mal formé : '
                + 'attendu « page|x|y » ou « page|x|y|largeur|hauteur ».');
        }
        try {
            Integer page = Integer.valueOf(morceaux[0].trim());
            Integer x    = Integer.valueOf(morceaux[1].trim());
            Integer y    = Integer.valueOf(morceaux[2].trim());

            if (morceaux.size() == 3) return new Position(page, x, y);

            return new Position(page, x, y,
                Integer.valueOf(morceaux[3].trim()),
                Integer.valueOf(morceaux[4].trim()));

        } catch (YousignException e) {
            throw e;
        } catch (Exception e) {
            throw new YousignException(
                'Custom Label ' + nomLabel + ' : toutes les valeurs doivent être des entiers.');
        }
    }

    /* ════════════════════════════════════════════════════════════════════════
       PLOMBERIE HTTP
       ════════════════════════════════════════════════════════════════════════ */

    private static HttpRequest requete(String methode, String chemin) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(racine() + chemin);
        req.setMethod(methode);
        req.setHeader('Authorization', 'Bearer ' + Label.YOUSIGN_API_TOKEN);
        req.setHeader('Accept', 'application/json');
        req.setTimeout(60000);
        return req;
    }

    /** Racine de l'API, sans slash final — le label peut en porter un ou pas. */
    private static String racine() {
        String v = String.valueOf(Label.YOUSIGN_API_ENDPOINT).trim();
        if (String.isBlank(v)) {
            throw new YousignException('Custom Label YOUSIGN_API_ENDPOINT non renseigné.');
        }
        return v.endsWith('/') ? v.removeEnd('/') : v;
    }

    private static Boolean estSucces(Integer code) {
        return code >= 200 && code <= 299;
    }

    /**
     * Envoie et désérialise, ou lève une YousignException portant le message de
     * l'API. Le corps complet part toujours en debug : c'est la seule trace
     * exploitable quand Yousign refuse une requête pour une raison de détail.
     */
    private static Map<String, Object> envoyer(HttpRequest req, String operation) {
        HttpResponse res;
        try {
            res = new Http().send(req);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'YS_YousignService.' + operation + ' : ' + e.getMessage());
            throw new YousignException('Service de signature injoignable : ' + e.getMessage());
        }

        String corps = res.getBody();
        if (!estSucces(res.getStatusCode())) {
            System.debug(LoggingLevel.ERROR,
                'YS_YousignService.' + operation + ' HTTP ' + res.getStatusCode() + ' : ' + corps);
            throw new YousignException(messageErreur(res.getStatusCode(), corps));
        }
        if (String.isBlank(corps)) return new Map<String, Object>();
        try {
            return (Map<String, Object>) JSON.deserializeUntyped(corps);
        } catch (Exception e) {
            throw new YousignException('Réponse illisible du service de signature.');
        }
    }

    /**
     * Yousign renvoie ses erreurs en RFC 7807 : { "title": …, "detail": … }.
     *
     * Sur un refus de parametres, `detail` ne dit que « You have some invalid
     * params in your payload » ; le VRAI motif est dans `invalid_params`
     * (nom du champ + raison). Il est ajoute au message : sans lui, une
     * hauteur de signature de 34 au lieu de 37 a coute une seance de
     * diagnostic — avec lui, l'ecran l'aurait dit.
     */
    private static String messageErreur(Integer code, String corps) {
        String detail;
        try {
            Map<String, Object> json = (Map<String, Object>) JSON.deserializeUntyped(corps);
            detail = (String) json.get('detail');
            if (String.isBlank(detail)) detail = (String) json.get('title');

            Object invalides = json.get('invalid_params');
            if (invalides instanceof List<Object>) {
                List<String> motifs = new List<String>();
                for (Object o : (List<Object>) invalides) {
                    if (!(o instanceof Map<String, Object>)) continue;
                    Map<String, Object> p = (Map<String, Object>) o;
                    motifs.add(String.valueOf(p.get('name')) + ' : ' + String.valueOf(p.get('reason')));
                }
                if (!motifs.isEmpty()) {
                    detail = (String.isBlank(detail) ? '' : detail + ' ') + '[' + String.join(motifs, ' ; ') + ']';
                }
            }
        } catch (Exception e) {
            detail = null;
        }
        if (code == 401 || code == 403) {
            return 'Clé API Yousign refusée (code ' + code + ') — vérifier le Custom Label YOUSIGN_API_TOKEN.';
        }
        return String.isBlank(detail)
            ? 'Le service de signature a refusé la demande (code ' + code + ').'
            : detail;
    }

    private static String texte(Map<String, Object> json, String cle) {
        Object v = json.get(cle);
        return v == null ? null : String.valueOf(v);
    }

    private static String tronquer(String valeur, Integer max) {
        if (String.isBlank(valeur)) return valeur;
        return valeur.length() <= max ? valeur : valeur.substring(0, max);
    }

    /* ════════════════════════════════════════════════════════════════════════
       MULTIPART/FORM-DATA — la partie délicate

       Apex ne sait pas assembler deux Blob. On construit donc le corps
       ENTIÈREMENT EN BASE64, puis on le décode d'un seul coup : concaténer du
       base64 est légitime tant qu'aucun segment ne porte de caractère de
       bourrage « = », qui signalerait une fin de flux au milieu du corps.

       Deux précautions, donc :
         • l'en-tête est complété d'espaces jusqu'à une longueur multiple de 3
           octets, pour que son base64 ne se termine jamais par « = » ;
         • le bourrage du PDF, lui, ne peut pas être évité — on le RECYCLE en
           lui faisant encoder les premiers octets du pied (voir plus bas).
       ════════════════════════════════════════════════════════════════════════ */

    private static final String FRONTIERE = '----RENOVYSb0undary7d91e3';

    private static Blob corpsMultipart(Blob fichier, String nomFichier) {

        // Assemblé en deux temps : la partie fixe, puis le remplissage qui aligne
        // l'ensemble sur 3 octets. Les espaces sont insérés en fin de la ligne
        // « Content-Type », où un en-tête MIME tolère les blancs terminaux — ils
        // n'atteignent donc jamais le contenu du fichier.
        String debut =
              '--' + FRONTIERE + '\r\n'
            + 'Content-Disposition: form-data; name="nature"\r\n'
            + '\r\n'
            + 'signable_document\r\n'
            + '--' + FRONTIERE + '\r\n'
            + 'Content-Disposition: form-data; name="file"; filename="' + ascii(nomFichier) + '"\r\n'
            + 'Content-Type: application/pdf';
        String fin = '\r\n\r\n';

        Integer manquant = Math.mod(3 - Math.mod(debut.length() + fin.length(), 3), 3);
        String remplissage = '';
        for (Integer i = 0; i < manquant; i++) remplissage += ' ';
        String entete = debut + remplissage + fin;

        // Tout est ASCII : longueur en caractères = longueur en octets, et
        // l'alignement calculé ci-dessus garantit un base64 sans « = ».
        String enteteB64 = EncodingUtil.base64Encode(Blob.valueOf(entete));

        String fichierB64 = EncodingUtil.base64Encode(fichier);
        String pied;

        // Le dernier groupe base64 du PDF encode 1, 2 ou 3 octets utiles. Quand
        // il en encode moins de 3, on remplace le bourrage par l'encodage des
        // premiers octets du pied (\r puis \n) : le flux reste aligné et aucun
        // « = » ne subsiste au milieu du corps.
        if (fichierB64.endsWith('==')) {
            // 1 octet utile : « == » devient « 0K », qui encode \r\n.
            fichierB64 = fichierB64.substring(0, fichierB64.length() - 2) + '0K';
            pied = '--' + FRONTIERE + '--\r\n';
        } else if (fichierB64.endsWith('=')) {
            // 2 octets utiles : « = » devient « N », qui encode \r.
            fichierB64 = fichierB64.substring(0, fichierB64.length() - 1) + 'N';
            pied = '\n--' + FRONTIERE + '--\r\n';
        } else {
            pied = '\r\n--' + FRONTIERE + '--\r\n';
        }

        return EncodingUtil.base64Decode(enteteB64 + fichierB64 + EncodingUtil.base64Encode(Blob.valueOf(pied)));
    }

    /** Nom de fichier sans accent ni caractère exotique : l'en-tête MIME est ASCII. */
    private static String ascii(String nom) {
        if (String.isBlank(nom)) return 'document.pdf';
        return nom.replaceAll('[^A-Za-z0-9._-]', '_');
    }
}