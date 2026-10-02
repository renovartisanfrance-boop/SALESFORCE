/**
 * LC026_Documents — contrôleur du composant c/lwc026_documents.
 *
 * CONTEXTE D'EXÉCUTION
 * ────────────────────
 * Même contexte que LC021_DevisSignature : le composant tourne dans le site
 * Experience Cloud « Campagnes », l'appelant n'est pas forcément un utilisateur
 * Salesforce nominatif, et le droit d'accès ne vient PAS du partage mais du
 * TOKEN DE CAMPAGNE (Campaign.CampaignToken__c, propagé en `campaign-code`
 * depuis le localStorage `renov_campaign_token`).
 *
 * D'où le `without sharing`, et la même sécurité APPLICATIVE en trois verrous :
 *
 *   1. le token doit correspondre à une campagne existante ;
 *   2. le recordId doit être un Id valide de Lead ou de Pro__c ;
 *   3. le record doit APPARTENIR au périmètre de cette campagne (et de ses
 *      campagnes filles) — même règle de rattachement que le reporting :
 *        • Lead    → membre d'une CampaignMember de ces campagnes,
 *        • Pro__c  → Campagne_REGIE__c dans ces campagnes.
 *
 * Un utilisateur Salesforce CONNECTÉ (confirmateur, télépro…) n'a pas de token :
 * son profil fixe son périmètre, selon les règles de LC021_DevisSignature
 * (section « ACCES SANS TOKEN »), partagées pour rester identiques.
 *
 * ÉCRITURE : PISTE UNIQUEMENT
 * ───────────────────────────
 * Ajouter ou supprimer un document n'est permis que sur une Piste (Lead). Sur un
 * Dossier (Pro__c) la consultation est seule autorisée : les pièces d'un dossier
 * en cours de traitement sont sous la responsabilité de RENOV, pas du partenaire.
 * Le verrou est ICI, pas dans le composant — `modifiable` renvoyé au LWC ne sert
 * qu'à masquer les boutons.
 *
 * @see c/lwc026_documents           composant appelant (modale autonome)
 * @see LC021_DevisSignature         même modèle de sécurité, mêmes verrous
 */
public without sharing class LC026_Documents {

    /** Types d'enregistrement acceptés. */
    private static final String OBJET_LEAD = 'Lead';
    private static final String OBJET_PRO  = 'Pro__c';

    /**
     * Marqueur de la fiche RES060 dans les champs produit. Sur Lead il est porté
     * par TypeDeDossier__c (« RESIDENTIEL_REGIES_-_RES060 »), sur Pro__c par
     * Fiche_CEE__c. On teste la PRÉSENCE du code et non l'égalité : une Piste peut
     * porter plusieurs produits séparés par des « ; ».
     */
    private static final String CODE_RES060 = 'RES060';

    /**
     * Plafond par fichier, en octets. Le contenu part en base64 dans un appel
     * Apex synchrone (heap 6 Mo) et le décodage garde une seconde copie : 3 Mo de
     * brut sont déjà proches de la limite. Le composant envoie les fichiers UN PAR
     * UN et les compresse avant (1600 px / JPEG q=0,72), donc ce plafond n'est
     * atteint en pratique que par un PDF volumineux.
     */
    private static final Integer TAILLE_MAX_FICHIER = 3000000;

    /**
     * Plafond de LECTURE, en octets. getContenu renvoie le fichier en base64 :
     * la chaîne pèse 1,33 fois le fichier et coexiste un instant avec le Blob
     * décodé, dans une heap de 6 Mo. 3,5 Mo de brut est la limite raisonnable.
     *
     * Au-delà, `consultable` vaut faux et le composant grise l'ouverture plutôt
     * que de déclencher un appel voué à l'erreur « heap size too large ».
     */
    private static final Integer TAILLE_MAX_LECTURE = 3500000;

    /* ════════════════════════════════════════════════════════════════════════
       STRUCTURES RENVOYÉES AU COMPOSANT
       ════════════════════════════════════════════════════════════════════════ */

    /** Une pièce jointe de l'enregistrement. */
    public class DocumentJoint {
        @AuraEnabled public String  contentDocumentId { get; set; }
        @AuraEnabled public String  titre             { get; set; }
        @AuraEnabled public String  extension         { get; set; }
        @AuraEnabled public Integer taille            { get; set; }
        /** Date de dernière modification, déjà formatée (jj/mm/aaaa). */
        @AuraEnabled public String  dateModif         { get; set; }
        /**
         * Faux si le fichier dépasse ce qu'un appel Apex synchrone peut renvoyer
         * en base64 : le composant grise alors l'ouverture au lieu de lancer un
         * appel qui échouerait sur la heap.
         */
        @AuraEnabled public Boolean consultable       { get; set; }
    }

    /** Tout ce dont la modale a besoin, en un seul appel. */
    public class DocumentsData {
        @AuraEnabled public String  recordId    { get; set; }
        @AuraEnabled public String  objectType  { get; set; }
        /** « Piste » ou « Dossier » — le LWC traduit, il ne devine pas. */
        @AuraEnabled public String  typeLibelle { get; set; }
        /** Nom du client, affiché en sous-titre de la modale. */
        @AuraEnabled public String  titre       { get; set; }
        /** Vrai sur Piste uniquement : autorise l'ajout et la suppression. */
        @AuraEnabled public Boolean modifiable  { get; set; }
        /** Vrai si la fiche produit est RES060 : sections de photos typées. */
        @AuraEnabled public Boolean estRes060   { get; set; }
        @AuraEnabled public List<DocumentJoint> documents { get; set; }
    }

    /* ════════════════════════════════════════════════════════════════════════
       LECTURE
       ════════════════════════════════════════════════════════════════════════ */

    /**
     * Documents joints à une Piste ou à un Dossier.
     *
     * @param recordId     Id du Lead ou du Pro__c.
     * @param campaignCode Token de campagne (Campaign.CampaignToken__c).
     */
    @AuraEnabled
    public static DocumentsData getDocuments(String recordId, String campaignCode) {
        Id idRecord = verifierAcces(recordId, campaignCode);
        return construire(idRecord);
    }

    /**
     * Nombre de documents par enregistrement, pour la pastille du reporting.
     *
     * Contrairement aux autres méthodes, un Id hors périmètre n'est pas une erreur
     * : il est simplement ABSENT du résultat. Le reporting envoie la page entière
     * en un appel, et une ligne inattendue ne doit pas faire disparaître la colonne.
     *
     * @return Map Id d'enregistrement -> nombre de documents (les enregistrements
     *         sans document ne figurent pas dans la map).
     */
    @AuraEnabled
    public static Map<String, Integer> compterDocuments(List<String> recordIds, String campaignCode) {
        Map<String, Integer> compteurs = new Map<String, Integer>();
        if (recordIds == null || recordIds.isEmpty()) return compteurs;

        // Utilisateur connecte : perimetre de son profil (LC021_DevisSignature).
        Set<Id> campaignIds = LC021_DevisSignature.perimetreCampagnes(campaignCode);
        Boolean sansToken = (campaignIds == null);
        if (sansToken && (String.isNotBlank(campaignCode) || UserInfo.getUserType() == 'Guest')) {
            LC021_DevisSignature.refuserSansAcces(campaignCode);
        }

        // ── Tri des Ids par type, en ignorant tout ce qui n'est ni Lead ni Pro__c
        Set<Id> idsLead = new Set<Id>();
        Set<Id> idsPro  = new Set<Id>();
        for (String brut : recordIds) {
            if (String.isBlank(brut)) continue;
            Id idRecord;
            try {
                idRecord = (Id) brut;
            } catch (Exception e) {
                continue;
            }
            String type = String.valueOf(idRecord.getSObjectType());
            if (type == OBJET_LEAD)     idsLead.add(idRecord);
            else if (type == OBJET_PRO) idsPro.add(idRecord);
        }
        if (idsLead.isEmpty() && idsPro.isEmpty()) return compteurs;

        // ── Verrou 3 en masse : on ne garde que ce qui est dans le périmètre
        Set<Id> autorises = new Set<Id>();
        if (sansToken) {
            // Profil sans perimetre par enregistrement : ensemble vide, la
            // pastille reste simplement absente.
            Set<Id> tous = new Set<Id>(idsLead);
            tous.addAll(idsPro);
            autorises = LC021_DevisSignature.rattachesSansToken(tous);
        }
        if (!sansToken && !idsLead.isEmpty()) {
            for (CampaignMember membre : [
                SELECT LeadId FROM CampaignMember
                WHERE CampaignId IN :campaignIds AND LeadId IN :idsLead
            ]) {
                autorises.add(membre.LeadId);
            }
        }
        if (!sansToken && !idsPro.isEmpty()) {
            for (Pro__c dossier : [
                SELECT Id FROM Pro__c
                WHERE Id IN :idsPro AND Campagne_REGIE__c IN :campaignIds
            ]) {
                autorises.add(dossier.Id);
            }
        }
        if (autorises.isEmpty()) return compteurs;

        // ── Comptage. ContentDocumentLink n'accepte pas de GROUP BY : on ramène
        //    les liens et on agrège en Apex.
        for (ContentDocumentLink lien : [
            SELECT LinkedEntityId FROM ContentDocumentLink
            WHERE LinkedEntityId IN :autorises
        ]) {
            String cle = String.valueOf(lien.LinkedEntityId);
            Integer n = compteurs.get(cle);
            compteurs.put(cle, n == null ? 1 : n + 1);
        }
        return compteurs;
    }

    /* ════════════════════════════════════════════════════════════════════════
       CONSULTATION D'UN FICHIER

       POURQUOI PASSER PAR L'APEX plutôt que par un lien de téléchargement.
       Le servlet de fichiers (/sfc/servlet.shepherd/...) s'appuie sur le PARTAGE
       Salesforce du document. Or la sécurité de ce portail est APPLICATIVE : le
       droit vient du token de campagne, pas d'un partage. Pour un utilisateur du
       portail, le servlet ne renvoie donc pas le fichier mais un script de
       redirection vers `errorduringprocessing.jsp` — constaté aussi bien sur ce
       composant que sur lwc021_devis_signature, qui a fini par adopter la même
       solution : les octets remontent par l'Apex et le navigateur les affiche
       depuis un `blob:` local.
       ════════════════════════════════════════════════════════════════════════ */

    /** Contenu d'un fichier, prêt à devenir un blob: côté navigateur. */
    public class ContenuDocument {
        @AuraEnabled public String titre       { get; set; }
        /** Type MIME, déduit de l'extension — pilote l'affichage du navigateur. */
        @AuraEnabled public String contentType { get; set; }
        @AuraEnabled public String base64      { get; set; }
    }

    /**
     * Renvoie la dernière version d'un document joint à l'enregistrement.
     *
     * Le document doit être RÉELLEMENT lié : sans cette vérification, un Id de
     * ContentDocument deviné suffirait à lire le fichier d'un autre dossier.
     */
    @AuraEnabled
    public static ContenuDocument getContenu(String recordId, String campaignCode,
                                             String contentDocumentId) {
        Id idRecord = verifierAcces(recordId, campaignCode);

        if (String.isBlank(contentDocumentId)) {
            throw erreur('Identifiant de document non fourni.');
        }
        Id idDoc;
        try {
            idDoc = (Id) contentDocumentId;
        } catch (Exception e) {
            throw erreur('Identifiant de document invalide.');
        }

        List<ContentDocumentLink> liens = [
            SELECT Id FROM ContentDocumentLink
            WHERE ContentDocumentId = :idDoc AND LinkedEntityId = :idRecord
            LIMIT 1
        ];
        if (liens.isEmpty()) {
            throw erreur('Ce document n\'appartient pas à cet enregistrement.');
        }

        List<ContentVersion> versions = [
            SELECT Title, FileExtension, ContentSize, VersionData
            FROM ContentVersion
            WHERE ContentDocumentId = :idDoc AND IsLatest = true
            LIMIT 1
        ];
        if (versions.isEmpty()) {
            throw erreur('Ce document est introuvable.');
        }
        ContentVersion version = versions[0];
        if (version.ContentSize != null && version.ContentSize > TAILLE_MAX_LECTURE) {
            throw erreur('Ce fichier est trop volumineux pour être ouvert depuis le portail.');
        }

        ContenuDocument contenu = new ContenuDocument();
        contenu.titre       = version.Title;
        contenu.contentType = typeMime(version.FileExtension);
        contenu.base64      = EncodingUtil.base64Encode(version.VersionData);
        return contenu;
    }

    /**
     * Extension -> type MIME.
     *
     * Ce que le navigateur AFFICHE dépend entièrement de ce type : sans lui, un
     * PDF est téléchargé au lieu de s'ouvrir dans l'onglet. Les formats absents
     * de cette table retombent sur octet-stream, c'est-à-dire un téléchargement
     * — comportement correct pour un .docx ou un .zip.
     */
    private static String typeMime(String extension) {
        String ext = String.isBlank(extension) ? '' : extension.toLowerCase();
        Map<String, String> types = new Map<String, String>{
            'pdf'  => 'application/pdf',
            'jpg'  => 'image/jpeg',
            'jpeg' => 'image/jpeg',
            'png'  => 'image/png',
            'gif'  => 'image/gif',
            'webp' => 'image/webp',
            'heic' => 'image/heic',
            'bmp'  => 'image/bmp',
            'svg'  => 'image/svg+xml',
            'txt'  => 'text/plain',
            'csv'  => 'text/csv'
        };
        String mime = types.get(ext);
        return mime == null ? 'application/octet-stream' : mime;
    }

    /* ════════════════════════════════════════════════════════════════════════
       ÉCRITURE — PISTE UNIQUEMENT
       ════════════════════════════════════════════════════════════════════════ */

    /**
     * Ajoute UN document à une Piste et renvoie l'état complet rafraîchi.
     *
     * Un fichier par appel, volontairement : le base64 de plusieurs photos dans
     * un même appel synchrone sature la heap de 6 Mo. Le composant enchaîne les
     * appels et affiche la progression.
     *
     * @param nomFichier  Nom FINAL du fichier (déjà préfixé/numéroté par le LWC
     *                    pour la fiche RES060 ; nom d'origine sinon).
     */
    @AuraEnabled
    public static DocumentsData ajouterDocument(String recordId, String campaignCode,
                                                String nomFichier, String base64, String contentType) {
        Id idRecord = verifierAcces(recordId, campaignCode);
        exigerModifiable(idRecord);

        if (String.isBlank(nomFichier) || String.isBlank(base64)) {
            throw erreur('Le nom du fichier et son contenu sont requis.');
        }

        Blob contenu;
        try {
            contenu = EncodingUtil.base64Decode(base64);
        } catch (Exception e) {
            throw erreur('Le contenu du fichier est illisible.');
        }
        if (contenu.size() > TAILLE_MAX_FICHIER) {
            throw erreur('Le fichier est trop volumineux (maximum '
                + (TAILLE_MAX_FICHIER / 1024 / 1024) + ' Mo).');
        }

        ContentVersion version = new ContentVersion(
            Title                  = nomFichier,
            PathOnClient           = nomFichier,
            VersionData            = contenu,
            ContentLocation        = 'S',
            IsMajorVersion         = true,
            FirstPublishLocationId = idRecord
        );
        insert version;

        // FirstPublishLocationId est ignoré dans certains contextes portail : on
        // vérifie que le lien existe, et on le pose sinon. Sans lui le fichier
        // serait créé mais invisible depuis l'enregistrement.
        ContentVersion creee = [
            SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :version.Id LIMIT 1
        ];
        List<ContentDocumentLink> liens = [
            SELECT Id FROM ContentDocumentLink
            WHERE ContentDocumentId = :creee.ContentDocumentId AND LinkedEntityId = :idRecord
            LIMIT 1
        ];
        if (liens.isEmpty()) {
            insert new ContentDocumentLink(
                ContentDocumentId = creee.ContentDocumentId,
                LinkedEntityId    = idRecord,
                ShareType         = 'V',
                Visibility        = 'AllUsers'
            );
        }

        return construire(idRecord);
    }

    /**
     * Supprime un document d'une Piste et renvoie l'état complet rafraîchi.
     *
     * Le document doit être RÉELLEMENT lié à cette Piste : sans cette
     * vérification, un Id de ContentDocument deviné suffirait à supprimer le
     * fichier d'un autre enregistrement.
     */
    @AuraEnabled
    public static DocumentsData supprimerDocument(String recordId, String campaignCode,
                                                  String contentDocumentId) {
        Id idRecord = verifierAcces(recordId, campaignCode);
        exigerModifiable(idRecord);

        if (String.isBlank(contentDocumentId)) {
            throw erreur('Identifiant de document non fourni.');
        }
        Id idDoc;
        try {
            idDoc = (Id) contentDocumentId;
        } catch (Exception e) {
            throw erreur('Identifiant de document invalide.');
        }

        List<ContentDocumentLink> liens = [
            SELECT Id FROM ContentDocumentLink
            WHERE ContentDocumentId = :idDoc AND LinkedEntityId = :idRecord
            LIMIT 1
        ];
        if (liens.isEmpty()) {
            throw erreur('Ce document n\'appartient pas à cet enregistrement.');
        }

        // Suppression du document lui-même, pas du seul lien : un fichier
        // détaché resterait dans l'org sans qu'aucun écran ne le montre.
        delete [SELECT Id FROM ContentDocument WHERE Id = :idDoc];

        return construire(idRecord);
    }

    /* ════════════════════════════════════════════════════════════════════════
       CONSTRUCTION DE LA RÉPONSE
       ════════════════════════════════════════════════════════════════════════ */

    /** Lit l'enregistrement et ses pièces jointes après vérification d'accès. */
    private static DocumentsData construire(Id idRecord) {
        String type = String.valueOf(idRecord.getSObjectType());

        DocumentsData data = new DocumentsData();
        data.recordId   = String.valueOf(idRecord);
        data.objectType = type;
        data.modifiable = (type == OBJET_LEAD);

        if (type == OBJET_LEAD) {
            Lead piste = [
                SELECT Id, Name, TypeDeDossier__c FROM Lead WHERE Id = :idRecord LIMIT 1
            ];
            data.typeLibelle = 'Piste';
            data.titre       = piste.Name;
            data.estRes060   = estRes060(piste.TypeDeDossier__c);
        } else {
            Pro__c dossier = [
                SELECT Id, Name, PRO_Nom_Client__c, Fiche_CEE__c
                FROM Pro__c WHERE Id = :idRecord LIMIT 1
            ];
            data.typeLibelle = 'Dossier';
            // ⚠️ PRO_Nom_Client__c est une FORMULE HYPERLINK : sa valeur est du
            // balisage, pas un nom. Elle vaut litteralement
            // « <a href="/a09..." target="_blank">Cecile Botzung-</a> », et le
            // titre de la modale l'affichait tel quel.
            data.titre       = String.isNotBlank(dossier.PRO_Nom_Client__c)
                             ? texteBrut(dossier.PRO_Nom_Client__c) : dossier.Name;
            data.estRes060   = estRes060(dossier.Fiche_CEE__c);
        }

        data.documents = documentsDe(idRecord);
        return data;
    }

    /**
     * Retire le balisage d'une valeur destinee a etre LUE.
     *
     * Plusieurs champs de l'org sont des formules HYPERLINK : pratiques dans une
     * vue de liste Salesforce, ou le balisage est interprete, mais inutilisables
     * ailleurs. Plutot que de preferer `Name` — ce qui marcherait aujourd'hui et
     * casserait le jour ou les deux divergent —, on garde le champ voulu et on
     * le rend lisible.
     *
     * Les entites sont decodees APRES le retrait des balises : un nom contenant
     * « &lt; » ne doit pas se transformer en balise a demi ouverte.
     */
    @TestVisible
    private static String texteBrut(String valeur) {
        if (String.isBlank(valeur)) return valeur;
        String t = valeur.replaceAll('<[^>]*>', '');
        t = t.replace('&nbsp;', ' ')
             .replace('&quot;', '"')
             .replace('&#39;', '\'')
             .replace('&lt;', '<')
             .replace('&gt;', '>')
             // En DERNIER : decoder &amp; avant les autres recreerait des
             // entites la ou le texte contenait « &amp;lt; ».
             .replace('&amp;', '&');
        return t.trim();
    }

    /** Pièces jointes de l'enregistrement, les plus récentes d'abord. */
    private static List<DocumentJoint> documentsDe(Id idRecord) {
        Set<Id> idsDocs = new Set<Id>();
        for (ContentDocumentLink lien : [
            SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :idRecord
        ]) {
            idsDocs.add(lien.ContentDocumentId);
        }

        List<DocumentJoint> resultat = new List<DocumentJoint>();
        if (idsDocs.isEmpty()) return resultat;

        for (ContentDocument doc : [
            SELECT Id, Title, FileExtension, ContentSize, LastModifiedDate
            FROM ContentDocument
            WHERE Id IN :idsDocs
            ORDER BY LastModifiedDate DESC
        ]) {
            DocumentJoint dj = new DocumentJoint();
            dj.contentDocumentId = String.valueOf(doc.Id);
            dj.titre             = doc.Title;
            dj.extension         = doc.FileExtension;
            dj.taille            = doc.ContentSize;
            dj.dateModif         = doc.LastModifiedDate == null
                                 ? null : doc.LastModifiedDate.format('dd/MM/yyyy');
            dj.consultable       = doc.ContentSize != null && doc.ContentSize <= TAILLE_MAX_LECTURE;
            resultat.add(dj);
        }
        return resultat;
    }

    /** Un champ produit porte-t-il la fiche RES060 ? */
    private static Boolean estRes060(String valeurProduit) {
        return String.isNotBlank(valeurProduit) && valeurProduit.contains(CODE_RES060);
    }

    /* ════════════════════════════════════════════════════════════════════════
       SÉCURITÉ
       ════════════════════════════════════════════════════════════════════════ */

    /**
     * Applique les verrous 1 à 3 et renvoie l'Id validé.
     * Toute anomalie lève la MÊME exception : le composant n'apprend jamais si un
     * enregistrement existe hors de son périmètre.
     */
    private static Id verifierAcces(String recordId, String campaignCode) {

        // ── Verrou 1 : token connu, OU utilisateur connecté habilité ─────────
        //    (règles par profil : LC021_DevisSignature, « ACCES SANS TOKEN »)
        Set<Id> campaignIds = LC021_DevisSignature.perimetreCampagnes(campaignCode);
        Boolean sansToken = (campaignIds == null);
        if (sansToken && !LC021_DevisSignature.aUnPerimetreSansToken()) {
            LC021_DevisSignature.refuserSansAcces(campaignCode);
        }

        // ── Verrou 2 : Id valide, d'un type supporté ─────────────────────────
        Id idRecord;
        try {
            idRecord = (Id) recordId;
        } catch (Exception e) {
            throw erreur('Identifiant d\'enregistrement invalide.');
        }
        String type = String.valueOf(idRecord.getSObjectType());
        if (type != OBJET_LEAD && type != OBJET_PRO) {
            throw erreur('Ce type d\'enregistrement ne gère pas de documents.');
        }

        // ── Verrou 3 : le record appartient bien au périmètre du token ───────
        Boolean dansPerimetre;
        if (sansToken) {
            dansPerimetre = !LC021_DevisSignature.rattachesSansToken(new Set<Id>{ idRecord }).isEmpty();
        } else if (type == OBJET_LEAD) {
            dansPerimetre = ![
                SELECT Id FROM CampaignMember
                WHERE CampaignId IN :campaignIds AND LeadId = :idRecord
                LIMIT 1
            ].isEmpty();
        } else {
            dansPerimetre = ![
                SELECT Id FROM Pro__c
                WHERE Id = :idRecord AND Campagne_REGIE__c IN :campaignIds
                LIMIT 1
            ].isEmpty();
        }
        if (!dansPerimetre) {
            throw erreur(String.isBlank(campaignCode)
                ? 'Cet enregistrement ne fait pas partie de votre périmètre.'
                : 'Cet enregistrement n\'est pas accessible avec ce token de campagne.');
        }

        return idRecord;
    }

    /** Verrou d'écriture : seule une Piste accepte l'ajout et la suppression. */
    private static void exigerModifiable(Id idRecord) {
        if (String.valueOf(idRecord.getSObjectType()) != OBJET_LEAD) {
            throw erreur('Les documents d\'un dossier sont en consultation seule.');
        }
    }

    /** AuraHandledException dont le message REMONTE au composant. */
    private static AuraHandledException erreur(String message) {
        AuraHandledException e = new AuraHandledException(message);
        e.setMessage(message);
        return e;
    }
}