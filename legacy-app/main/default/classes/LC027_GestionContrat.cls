/**
 * LC027_GestionContrat — contrôleur du composant lwc027_gestion_contrat.
 *
 * Sert le contrat de collaboration des rôles du portail (Pré-visiteur,
 * Installateur — voir LC027_Roles) : lecture de son état, saisie
 * des informations d'identification, envoi en signature Yousign.
 *
 * MODÈLE DE SÉCURITÉ — APPLICATIF, pas déclaratif. Le portail tourne sous le
 * Guest User du site, qui n'a aucun droit sur Campaign. L'autorisation vient
 * du TOKEN de campagne et du rôle, contrôlés à CHAQUE méthode :
 *   • token inconnu               -> exception ;
 *   • rôle hors portail (voir LC027_Roles) -> exception.
 * Toutes les méthodes passent donc par campagneAutorisee().
 *
 * ⚠️ NE JAMAIS utiliser isUpdateable() / isAccessible() ici. Ces méthodes
 *    dépendent des droits de l'utilisateur COURANT, or l'invité n'a pas
 *    « Modifier » sur Campaign — et Salesforce interdit de le lui accorder
 *    depuis Winter '21. Le résultat serait un formulaire entièrement en lecture
 *    seule. C'est LC027_Roles.champsModifiables(rôle) qui fait le contrôle.
 *    Même constat que sur LC021_DevisSignature.
 */
public without sharing class LC027_GestionContrat {


    public static final String STATUT_GENERATION        = 'En cours de generation';
    public static final String STATUT_ATTENTE_SIGNATURE = 'Attente signature';
    public static final String STATUT_SIGNE             = 'Signe';


    /** Signature ECONATURA — même nom que contratConfig.SIGNATURE_ECONATURA.ressource. */
    private static final String RESSOURCE_SIGNATURE = 'signature_econatura';

    private static final String TITRE_CONTRAT       = 'Contrato Previsitador';
    private static final String NOM_FICHIER_CONTRAT = 'Contrato_Previsitador.pdf';

    /*
     * LISTE BLANCHE D'ÉCRITURE — elle dépend désormais du RÔLE et vit dans
     * LC027_Roles.champsModifiables(). Un champ absent de la liste du rôle n'est
     * pas enregistrable, quoi qu'envoie le composant : c'est le seul rempart, le
     * profil invité n'en fournissant aucun.
     */

    public class ContratException extends Exception {}

    /** Rôle sans contrat livré : l'envoi en signature est refusé, la saisie reste possible. */
    public static final String MESSAGE_CONTRAT_INDISPONIBLE =
        'Le contrat de ce rôle sera disponible prochainement : envoi en signature momentanément impossible.';

    /**
     * Email déjà porté par une autre campagne.
     *
     * Ce message-ci est un FILET : le composant contrôle l'email dès la saisie
     * et affiche alors sa propre phrase, traduite. On ne le voit donc qu'en
     * cas de course entre deux saisies, ou d'un appel direct à l'API.
     */
    public static final String MESSAGE_EMAIL_DEJA_PRIS =
        'Cet email est déjà utilisé par un autre intervenant : indiquez une adresse personnelle.';

    /** État du contrat servi au composant. */
    public class EtatContrat {
        @AuraEnabled public String statut;
        @AuraEnabled public Map<String, Object> donnees;
        @AuraEnabled public String messageErreur;
        @AuraEnabled public Boolean signe;
        /** Un contrat est archivé et consultable — pilote le bouton « voir le contrat ». */
        @AuraEnabled public Boolean documentDisponible;
        /** Rôle de la campagne : le composant en déduit les champs du formulaire. */
        @AuraEnabled public String role;
        /**
         * Le rôle a-t-il un contrat à signer ? Faux pour l'installateur tant que
         * son PDF n'est pas livré : le composant laisse saisir, mais n'envoie pas.
         */
        @AuraEnabled public Boolean contratDisponible;
        /** Campaign.Pays__c : certains champs ne s'affichent que pour un pays. */
        @AuraEnabled public String pays;
    }

    /* ════════════════════════════════════════════════════════════════════════
       LECTURE
       ════════════════════════════════════════════════════════════════════════ */

    @AuraEnabled(cacheable=true)
    public static EtatContrat getContrat(String campaignToken) {
        Campaign camp = campagneAutorisee(campaignToken);

        EtatContrat etat = new EtatContrat();
        etat.statut = camp.StatutContrat__c;
        etat.signe  = (camp.StatutContrat__c == STATUT_SIGNE);
        etat.messageErreur = camp.YS_Message_Erreur__c;
        etat.documentDisponible = documentAConsulter(camp) != null;
        etat.role = camp.Role__c;
        etat.contratDisponible = LC027_Roles.contratDisponible(camp.Role__c);
        etat.pays = camp.Pays__c;
        etat.donnees = new Map<String, Object>{
            'Name'                  => camp.Name,
            'Contrat_Profession__c' => camp.Contrat_Profession__c,
            'Contrat_Situation__c'  => camp.Contrat_Situation__c,
            'Contrat_NIF__c'        => camp.Contrat_NIF__c,
            'Contrat_Adresse__c'    => camp.Contrat_Adresse__c,
            'Contrat_CodePostal__c' => camp.Contrat_CodePostal__c,
            'Contrat_Ville__c'      => camp.Contrat_Ville__c,
            'NombrePrevisites__c'   => camp.NombrePrevisites__c,
            'Contrat_Provinces__c'  => camp.Contrat_Provinces__c,
            'Telephone__c'          => camp.Telephone__c,
            'Email__c'              => camp.Email__c
        };
        return etat;
    }

    /**
     * Octets du contrat vierge, en base64.
     *
     * ⚠️ POURQUOI PAR L'APEX ET NON PAR fetch() — dans un site LWR, Lightning
     * Web Security bloque tout fetch() du composant vers
     * /webruntime/org-asset/.../resource/... (« Cannot request disallowed
     * endpoint »). loadScript passe, fetch non. Constaté en sandbox sur le devis.
     * Ne jamais revenir à un fetch direct de Static Resource depuis ce site.
     */
    @AuraEnabled(cacheable=true)
    public static String getContratBase64(String campaignToken) {
        Campaign camp = campagneAutorisee(campaignToken);

        String ressource = LC027_Roles.ressourceContrat(camp.Role__c);
        if (String.isBlank(ressource)) {
            throw new ContratException(MESSAGE_CONTRAT_INDISPONIBLE);
        }
        List<StaticResource> res = [
            SELECT Body FROM StaticResource WHERE Name = :ressource LIMIT 1
        ];
        if (res.isEmpty()) {
            throw new ContratException('Static Resource « ' + ressource + ' » introuvable.');
        }
        return EncodingUtil.base64Encode(res[0].Body);
    }

    /**
     * Signature ECONATURA, en base64 — apposée sur la dernière page du contrat
     * avant l'envoi.
     *
     * Renvoie NULL si la Static Resource est absente, au lieu de lever : le
     * contrat part alors sans paraphe côté ECONATURA plutôt que de bloquer
     * l'inscription. Un envoi impossible serait un défaut plus grave qu'un
     * paraphe manquant, que l'on peut toujours ajouter ensuite.
     */
    @AuraEnabled(cacheable=true)
    public static String getSignatureEconaturaBase64(String campaignToken) {
        campagneAutorisee(campaignToken);

        List<StaticResource> res = [
            SELECT Body FROM StaticResource WHERE Name = :RESSOURCE_SIGNATURE LIMIT 1
        ];
        return res.isEmpty() ? null : EncodingUtil.base64Encode(res[0].Body);
    }

    /* ════════════════════════════════════════════════════════════════════════
       ÉCRITURE
       ════════════════════════════════════════════════════════════════════════ */

    /**
     * Enregistre les informations saisies. Accessible tant que le contrat n'est
     * PAS signé : l'écran « attente signature » autorise la correction, un NIF
     * ou une adresse erronés rendraient le contrat inexploitable.
     *
     * Une fois signé, plus rien ne bouge — le document signé ferait référence à
     * des valeurs que l'enregistrement ne porterait plus.
     */
    @AuraEnabled
    public static EtatContrat enregistrerInfos(String campaignToken, String donneesJson) {
        Campaign camp = campagneAutorisee(campaignToken);

        if (camp.StatutContrat__c == STATUT_SIGNE) {
            throw new ContratException('Le contrat est signé : les informations ne sont plus modifiables.');
        }

        Map<String, Object> recu;
        try {
            recu = (Map<String, Object>) JSON.deserializeUntyped(donneesJson);
        } catch (Exception e) {
            throw new ContratException('Données invalides.');
        }

        // Liste blanche DU RÔLE et DU PAYS : un installateur ne peut écrire que
        // ses champs, et un champ réservé à l'Espagne est ignoré ailleurs.
        Set<String> autorises = LC027_Roles.champsModifiables(camp.Role__c, camp.Pays__c);
        Campaign maj = new Campaign(Id = camp.Id);
        Boolean quelqueChose = false;
        for (String champ : recu.keySet()) {
            // Tout champ hors liste blanche est IGNORÉ en silence : refuser
            // bruyamment renseignerait un attaquant sur les champs existants.
            if (!autorises.contains(champ)) continue;
            Object v = recu.get(champ);
            maj.put(champ, v == null ? null : String.valueOf(v));
            quelqueChose = true;
        }

        // AVANT l'écriture : une campagne qui garderait un email en double
        // verrait l'envoi refusé plus tard, sans qu'aucun écran ne permette de
        // revenir en arrière une fois le contrat en attente de signature.
        verifierEmailLibre(camp.Id, maj.Email__c);

        if (quelqueChose) update maj;

        return getContratFrais(camp.Id);
    }

    /**
     * L'email est-il libre ? Contrôle appelable seul, pour le dire AU MOMENT
     * DE LA SAISIE plutôt qu'au clic sur « Signer » : à ce stade l'intervenant
     * a déjà tout rempli et relu son contrat.
     *
     * @return true si l'email peut être utilisé par cette campagne.
     */
    @AuraEnabled
    public static Boolean emailLibre(String campaignToken, String email) {
        Campaign camp = campagneAutorisee(campaignToken);
        return !emailDejaPris(camp.Id, email);
    }

    /**
     * UN EMAIL, UNE PERSONNE — refuse un email déjà porté par une autre
     * campagne, quel que soit son rôle ou son statut.
     *
     * Ce n'est pas une coquetterie de saisie : l'email est la clé de la
     * personne dans tout le dispositif. C'est le destinataire Yousign du
     * contrat, le login du compte Certiko du pré-visiteur, et ce sur quoi
     * l'écran d'administration rapproche Salesforce et Certiko. Deux campagnes
     * sur le même email, et la seconde retombe sur le compte Certiko de la
     * première (leur API répond 409 « email_taken » et nous rend l'existant) :
     * les dossiers de l'une partiraient à l'autre.
     */
    private static void verifierEmailLibre(Id campagneId, String email) {
        if (emailDejaPris(campagneId, email)) {
            throw new ContratException(MESSAGE_EMAIL_DEJA_PRIS);
        }
    }

    private static Boolean emailDejaPris(Id campagneId, String email) {
        String propre = email == null ? '' : email.trim();
        if (String.isBlank(propre)) {
            return false;
        }
        // SOQL compare sans tenir compte de la casse : « A@b.es » et « a@B.es »
        // sont bien reconnus comme le même email.
        return ![
            SELECT Id FROM Campaign
            WHERE Email__c = :propre AND Id != :campagneId
            LIMIT 1
        ].isEmpty();
    }

    /**
     * Envoie le contrat rempli à la signature.
     *
     * Le PDF arrive DÉJÀ RENSEIGNÉ depuis le composant : le contrat est un PDF
     * plat, sans champ AcroForm, et les valeurs y sont dessinées par pdf-lib côté
     * navigateur (mêmes coordonnées que contratConfig.PDF_LIGNES). L'Apex ne
     * refait pas ce travail, il reçoit les octets finaux.
     *
     * ORDRE — callouts d'abord, DML ensuite : Salesforce interdit un callout
     * après une opération DML dans la même transaction.
     *
     * @param reglagesJson langue / expéditeur / position, produits par
     *        contratConfig.reglagesContrat(). OBLIGATOIRES : voir
     *        appliquerReglages(), il n'y a PAS de repli sur les Custom Labels.
     */
    @AuraEnabled
    public static EtatContrat envoyerEnSignature(String campaignToken, String pdfBase64, String reglagesJson) {
        Campaign camp = campagneAutorisee(campaignToken);

        if (camp.StatutContrat__c == STATUT_SIGNE) {
            throw new ContratException('Le contrat est déjà signé.');
        }
        // Contrôlé AVANT tout callout : sans contrat propre au rôle, l'installateur
        // signerait le contrat de PRÉVISITES, juridiquement faux.
        if (!LC027_Roles.contratDisponible(camp.Role__c)) {
            throw new ContratException(MESSAGE_CONTRAT_INDISPONIBLE);
        }
        if (String.isBlank(pdfBase64)) {
            throw new ContratException('Contrat vide : rien à envoyer.');
        }
        if (String.isBlank(camp.Email__c)) {
            throw new ContratException('Aucun email : impossible d\'envoyer le contrat à la signature.');
        }
        // DERNIER REMPART, relu sur l'enregistrement et non sur la saisie : le
        // contrôle de la saisie peut dater de plusieurs minutes, et l'email a
        // pu être pris entre-temps par un autre intervenant en cours de
        // contrat. Une fois parti chez Yousign, le doublon ne se rattrape plus.
        verifierEmailLibre(camp.Id, camp.Email__c);

        // Avant tout callout : des réglages incomplets doivent arrêter l'envoi,
        // pas produire un contrat signé à la mauvaise place.
        String langue = appliquerReglages(reglagesJson);

        Blob pdf = EncodingUtil.base64Decode(pdfBase64);
        YS_YousignService.Signataire dest = signataire(camp, langue);

        String demandeId;
        try {
            demandeId = YS_YousignService.creerDemande('Contrato Previsitador - ' + camp.Name, dest.locale);
            String documentId = YS_YousignService.ajouterDocument(demandeId, pdf, NOM_FICHIER_CONTRAT);
            YS_YousignService.ajouterSignataire(
                demandeId, documentId, dest, YS_YousignService.positionSignature());
            YS_YousignService.activer(demandeId);
        } catch (Exception e) {
            // L'exception n'est PAS relancée telle quelle : elle annulerait la
            // transaction, et avec elle la trace de l'échec.
            System.debug(LoggingLevel.ERROR, 'LC027_GestionContrat.envoyerEnSignature : ' + e.getMessage());
            update new Campaign(
                Id = camp.Id,
                YS_Message_Erreur__c = abreger(e.getMessage(), 255),
                YS_Demande_Id__c = String.isBlank(demandeId) ? null : demandeId
            );
            throw new ContratException('Envoi à la signature impossible : ' + e.getMessage());
        }

        // Callouts terminés : on peut écrire.
        Id docContrat = joindreContrat(camp.Id, pdf);

        update new Campaign(
            Id                   = camp.Id,
            YS_Demande_Id__c     = demandeId,
            StatutContrat__c     = STATUT_ATTENTE_SIGNATURE,
            // Sans ce pointeur, le portail ne saurait pas retrouver le document :
            // l'invité ne peut pas lire les ContentDocumentLink.
            YS_Contrat_Doc_Id__c = docContrat == null ? null : String.valueOf(docContrat),
            YS_Message_Erreur__c = null
        );

        return getContratFrais(camp.Id);
    }


    /**
     * Contrat archivé, en base64 — alimente l'ouverture dans un nouvel onglet.
     *
     * ⚠️ POURQUOI UN NOUVEL ONGLET ET PAS UN APERÇU INTÉGRÉ — sur ce site LWR,
     * toutes les voies d'iframe sont fermées : `blob:` est refusé par frame-src,
     * le routeur ne transmet pas /services/apexrest/, et les URL de fichiers
     * Salesforce répondent en Content-Disposition: attachment. En revanche,
     * OUVRIR un blob: dans un onglet passe la CSP. C'est donc le composant qui
     * reconstruit le blob à partir de ces octets.
     */
    @AuraEnabled
    public static String getContratStockeBase64(String campaignToken) {
        Campaign camp = campagneAutorisee(campaignToken);

        Id docId = documentAConsulter(camp);
        if (docId == null) {
            throw new ContratException('Aucun contrat joint à cette campagne.');
        }
        ContentVersion cv = versionDeDocument(docId);
        if (cv == null) {
            throw new ContratException('Le contrat est introuvable.');
        }
        return EncodingUtil.base64Encode(cv.VersionData);
    }

    /**
     * Quel document servir, par ORDRE DE PRÉFÉRENCE :
     *   1. le contrat SIGNÉ — une fois passé par Yousign, c'est lui qui fait foi ;
     *   2. le contrat rempli envoyé à la signature.
     *
     * ⚠️ Les POINTEURS d'abord, la recherche par ContentDocumentLink ensuite.
     * Dans l'autre sens, l'utilisateur invité — qui ne peut pas lire cette table —
     * voyait la recherche échouer et retombait sur le contrat vierge, alors que
     * la campagne portait bien le document signé. Le piège a déjà été constaté
     * sur le flux devis (voir LC021_DevisSignature.lireContratStocke).
     */
    private static Id documentAConsulter(Campaign camp) {
        if (String.isNotBlank(camp.YS_Signe_Doc_Id__c))   return (Id) camp.YS_Signe_Doc_Id__c;
        if (String.isNotBlank(camp.YS_Contrat_Doc_Id__c)) return (Id) camp.YS_Contrat_Doc_Id__c;
        return documentParLien(camp.Id);
    }

    /**
     * REPLI quand aucun pointeur n'est renseigné : on cherche le document par son
     * lien à la campagne.
     *
     * Il couvre les contrats envoyés AVANT que la relecture du pointeur ne soit
     * corrigée, et ceux dont la relecture échoue encore. Placé en DERNIER
     * volontairement : les pointeurs restent le chemin sûr, cette recherche
     * dépend de la lecture de ContentDocumentLink, que l'utilisateur invité ne
     * peut pas toujours faire.
     *
     * Le SIGNÉ prime sur le vierge, comme pour les pointeurs.
     */
    private static Id documentParLien(Id campagneId) {
        try {
            List<ContentDocumentLink> liens = [
                SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.CreatedDate
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :campagneId
                  AND ContentDocument.Title IN (:LC027_TraitementContrat.TITRE_SIGNE, :TITRE_CONTRAT)
                ORDER BY ContentDocument.CreatedDate DESC
            ];
            Id vierge = null;
            for (ContentDocumentLink l : liens) {
                if (l.ContentDocument.Title == LC027_TraitementContrat.TITRE_SIGNE) {
                    return l.ContentDocumentId;
                }
                if (vierge == null) vierge = l.ContentDocumentId;
            }
            return vierge;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                'Recherche du contrat par lien impossible : ' + e.getMessage());
            return null;
        }
    }

    /**
     * Version pointée, ou null si le pointeur ne mène nulle part.
     *
     * Le pointeur peut désigner un ContentDocument (préfixe 069) ou directement
     * une ContentVersion (068) — voir joindreContrat : quand la relecture du
     * document échoue, c'est l'identifiant de version qui est mémorisé. On
     * accepte donc les deux plutôt que d'imposer un droit de lecture que
     * l'utilisateur invité n'a pas.
     */
    private static ContentVersion versionDeDocument(Id pointeur) {
        if (pointeur == null) return null;

        String prefixe = String.valueOf(pointeur).substring(0, 3);
        List<ContentVersion> versions = (prefixe == '068')
            ? [SELECT Id, VersionData FROM ContentVersion WHERE Id = :pointeur LIMIT 1]
            : [SELECT Id, VersionData FROM ContentVersion
               WHERE ContentDocumentId = :pointeur AND IsLatest = true LIMIT 1];

        return versions.isEmpty() ? null : versions[0];
    }

    /* ════════════════════════════════════════════════════════════════════════
       INTERNES
       ════════════════════════════════════════════════════════════════════════ */

    /**
     * Contrôle d'accès unique : token valide ET rôle Pré-visiteur.
     * Toute méthode publique commence par là — un token de Régie n'ouvre rien ici.
     */
    private static Campaign campagneAutorisee(String campaignToken) {
        if (String.isBlank(campaignToken)) {
            throw new ContratException('Lien d\'accès manquant.');
        }
        List<Campaign> camps = [
            SELECT Id, Name, Role__c, StatutContrat__c, Email__c, Telephone__c,
                   Contrat_Profession__c, Contrat_Situation__c, Contrat_NIF__c,
                   Contrat_Adresse__c, Contrat_CodePostal__c, Contrat_Ville__c,
                   Contrat_Provinces__c, NombrePrevisites__c, YS_Message_Erreur__c, Pays__c,
                   YS_Contrat_Doc_Id__c, YS_Signe_Doc_Id__c
            FROM Campaign
            WHERE CampaignToken__c = :campaignToken
            LIMIT 1
        ];
        if (camps.isEmpty()) {
            throw new ContratException('Campagne introuvable.');
        }
        if (!LC027_Roles.estRolePortail(camps[0].Role__c)) {
            throw new ContratException('Ce lien d\'accès ne donne pas accès au contrat de pré-visiteur.');
        }
        return camps[0];
    }

    /** Relit l'état après écriture — le composant reçoit toujours la vérité de la base. */
    private static EtatContrat getContratFrais(Id campagneId) {
        Campaign c = [
            SELECT Id, Name, Role__c, StatutContrat__c, Email__c, Telephone__c,
                   Contrat_Profession__c, Contrat_Situation__c, Contrat_NIF__c,
                   Contrat_Adresse__c, Contrat_CodePostal__c, Contrat_Ville__c,
                   Contrat_Provinces__c, NombrePrevisites__c, Pays__c,
                   YS_Message_Erreur__c, YS_Contrat_Doc_Id__c, YS_Signe_Doc_Id__c
            FROM Campaign WHERE Id = :campagneId LIMIT 1
        ];
        EtatContrat etat = new EtatContrat();
        etat.statut = c.StatutContrat__c;
        etat.signe  = (c.StatutContrat__c == STATUT_SIGNE);
        etat.messageErreur = c.YS_Message_Erreur__c;
        etat.documentDisponible = documentAConsulter(c) != null;
        etat.role = c.Role__c;
        etat.contratDisponible = LC027_Roles.contratDisponible(c.Role__c);
        etat.pays = c.Pays__c;
        etat.donnees = new Map<String, Object>{
            'Name'                  => c.Name,
            'Contrat_Profession__c' => c.Contrat_Profession__c,
            'Contrat_Situation__c'  => c.Contrat_Situation__c,
            'Contrat_NIF__c'        => c.Contrat_NIF__c,
            'Contrat_Adresse__c'    => c.Contrat_Adresse__c,
            'Contrat_CodePostal__c' => c.Contrat_CodePostal__c,
            'Contrat_Ville__c'      => c.Contrat_Ville__c,
            'NombrePrevisites__c'   => c.NombrePrevisites__c,
            'Contrat_Provinces__c'  => c.Contrat_Provinces__c,
            'Telephone__c'          => c.Telephone__c,
            'Email__c'              => c.Email__c
        };
        return etat;
    }

    /**
     * Applique les réglages de signature envoyés par contratConfig.reglagesContrat().
     *
     * ⚠️ OBLIGATOIRES, SANS REPLI SUR LES CUSTOM LABELS — et c'est délibéré.
     * `YOUSIGN_CHAMP_SIGNATURE` vaut « 1|140|700|249|40 » (page 1) et n'est PLUS
     * utilisé par aucun flux : le devis passe lui aussi la position par
     * appliquerReglages(), fiche par fiche. C'est donc une valeur morte que
     * personne ne tient à jour. Y retomber ferait signer le contrat au milieu de
     * sa première page au lieu de la zone prévue page 6, et un document signé au
     * mauvais endroit ne se rattrape pas. Mieux vaut un envoi refusé.
     *
     * Seuls YOUSIGN_API_ENDPOINT et YOUSIGN_API_TOKEN restent des labels : ce
     * sont des coordonnées de service, communes à toutes les intégrations, et
     * elles n'ont aucun sens dans une configuration par document.
     *
     * @return la langue retenue, qui pilote aussi l'email du signataire.
     */
    private static String appliquerReglages(String reglagesJson) {
        if (String.isBlank(reglagesJson)) {
            throw new ContratException('Réglages de signature absents : envoi refusé.');
        }
        Map<String, Object> reglages;
        try {
            reglages = (Map<String, Object>) JSON.deserializeUntyped(reglagesJson);
        } catch (Exception e) {
            throw new ContratException('Réglages de signature illisibles : envoi refusé.');
        }

        String position = texte(reglages.get('champSignature'));
        String langue   = texte(reglages.get('langue'));
        if (String.isBlank(position)) {
            throw new ContratException('Position de signature absente des réglages : envoi refusé.');
        }
        if (String.isBlank(langue)) {
            throw new ContratException('Langue de signature absente des réglages : envoi refusé.');
        }

        YS_YousignService.appliquerReglages(reglages);
        return langue;
    }

    private static String texte(Object valeur) {
        if (valeur == null) return null;
        String t = String.valueOf(valeur).trim();
        return String.isBlank(t) ? null : t;
    }

    /**
     * Le signataire est le pré-visiteur lui-même. Campaign.Name porte
     * « prénom nom » concaténés par PrevisiteController : on découpe au premier
     * espace, le reste allant au nom — un nom composé reste ainsi entier.
     */
    private static YS_YousignService.Signataire signataire(Campaign camp, String langue) {
        String complet = String.isBlank(camp.Name) ? '' : camp.Name.trim();
        String prenom = complet;
        String nom    = '';
        Integer sep = complet.indexOf(' ');
        if (sep > 0) {
            prenom = complet.substring(0, sep);
            nom    = complet.substring(sep + 1).trim();
        }
        // Yousign refuse un nom vide : on retombe sur le prénom plutôt que
        // d'échouer sur une dénomination sociale en un seul mot.
        if (String.isBlank(nom)) nom = prenom;

        // Langue issue des réglages du contrat, jamais du label YOUSIGN_LOCALE
        // ni de la langue d'affichage du portail : elle s'adresse au SIGNATAIRE.
        return new YS_YousignService.Signataire(prenom, nom, camp.Email__c, langue);
    }

    /**
     * Joint le contrat rempli (non signé) à la campagne.
     * ⚠️ FirstPublishLocationId et non ContentDocumentLink : l'invité n'a pas le
     * droit d'insérer un partage de fichier, même en `without sharing`.
     */
    private static Id joindreContrat(Id campagneId, Blob pdf) {
        ContentVersion cv = new ContentVersion(
            Title                  = TITRE_CONTRAT,
            PathOnClient           = NOM_FICHIER_CONTRAT,
            VersionData            = pdf,
            FirstPublishLocationId = campagneId
        );
        try {
            insert cv;
        } catch (Exception e) {
            // Le contrat est déjà parti chez Yousign : un échec d'archivage ne
            // doit pas faire croire à un échec d'envoi.
            System.debug(LoggingLevel.WARN, 'Archivage du contrat échoué : ' + e.getMessage());
            return null;
        }

        // ── Identifiant a memoriser ──────────────────────────────────────
        // ContentDocumentId n'est PAS renseigne sur l'objet insere (verifie :
        // null en memoire, alors qu'une requete immediate le retourne). Il faut
        // donc relire — mais l'utilisateur INVITE ne peut pas interroger
        // ContentVersion : la requete ne renvoie rien, et le pointeur restait
        // vide alors que le fichier existait. Constate en production sur toutes
        // les campagnes envoyees.
        //
        // A DEFAUT, on memorise l'identifiant de la VERSION (cv.Id), lui
        // toujours disponible apres insertion. versionDeDocument() accepte les
        // deux : le prefixe 069 designe un document, 068 une version. Le
        // pointeur cesse ainsi de dependre d'un droit de lecture.
        try {
            Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1]
                           .ContentDocumentId;
            if (docId != null) return docId;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                'Relecture du document impossible, repli sur la version : ' + e.getMessage());
        }
        return cv.Id;
    }

    private static String abreger(String valeur, Integer max) {
        if (String.isBlank(valeur)) return valeur;
        return valeur.length() > max ? valeur.substring(0, max) : valeur;
    }
}