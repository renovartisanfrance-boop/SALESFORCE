/**
 * LC021_DevisSignature — contrôleur du composant c/lwc021_devis_signature.
 *
 * CONTEXTE D'EXÉCUTION
 * ────────────────────
 * Le composant tourne dans le site Experience Cloud « Campagnes ». L'utilisateur
 * qui l'appelle n'est PAS forcément un utilisateur Salesforce nominatif : c'est
 * soit un Guest User, soit un utilisateur de portail interne. Le droit d'accès
 * ne vient donc PAS du partage Salesforce mais du TOKEN DE CAMPAGNE déjà en place
 * dans le portail (Campaign.CampaignToken__c, stocké côté navigateur sous la clé
 * localStorage `renov_campaign_token` et propagé en `campaign-code`), exactement
 * comme LC020_GestionReporting.getReportingData.
 *
 * D'où le `without sharing` : le partage de l'org filtrerait tout et le portail
 * n'afficherait rien. La sécurité est APPLICATIVE et repose sur quatre verrous,
 * tous obligatoires et appliqués dans cet ordre :
 *
 *   1. le token doit correspondre à une campagne existante ;
 *   2. le recordId doit être un Id valide de Lead ou de Pro__c ;
 *   3. le record doit APPARTENIR au périmètre de cette campagne (et de ses
 *      campagnes filles) — même règle de rattachement que le reporting :
 *        • Lead    → membre d'une CampaignMember de ces campagnes,
 *        • Pro__c  → Campagne_REGIE__c dans ces campagnes ;
 *      (un utilisateur Salesforce CONNECTÉ n'a pas de token : son profil fixe
 *      son périmètre, voir la section « ACCES SANS TOKEN ») ;
 *   4. seuls les champs de la liste blanche ci-dessous sont lus ou écrits. La
 *      liste envoyée par le LWC est INTERSECTÉE avec elle : un nom de champ
 *      arbitraire venu du navigateur est ignoré, jamais requêté.
 *
 * ⚠️ Ajouter un champ au récapitulatif = le déclarer ICI (autorisation) ET dans
 *    devisConfig.js du LWC (affichage). Le LWC seul ne peut rien ouvrir.
 *
 * CHAMPS MÉTIER — écarts constatés entre Lead et Pro__c
 * ────────────────────────────────────────────────────
 * Le statut de devis demandé (`RES_Statut_Devis__c`) n'existe QUE sur Lead. Sur
 * Pro__c, le champ qui porte exactement les trois mêmes valeurs est
 * `devisfinal__c` (« LEDS- Devis Final ») : c'est lui qui est utilisé ici. De
 * même la surface habitable « RES- Shab » s'appelle `Surface_habitable__c` sur
 * Lead et `MPR_SHAB__c` sur Pro__c. Voir CONFIG_LEAD / CONFIG_PRO.
 *
 * Les libellés de picklist diffèrent eux aussi d'un objet à l'autre
 * (« 🟦En Att Signature » sur Lead, « 🟦En Attente Signature » sur Pro__c). Ils
 * sont donc normalisés en CODES stables (GENERATION / ATTENTE_SIGNATURE / SIGNE)
 * pour que le LWC n'ait qu'un seul `switch` à tenir.
 */
public without sharing class LC021_DevisSignature {

    /* ════════════════════════════════════════════════════════════════════════
       CONFIGURATION PAR OBJET — source de vérité des AUTORISATIONS
       ════════════════════════════════════════════════════════════════════════ */

    /** Description d'un objet supporté par le workflow de devis. */
    private class ConfigObjet {
        String sobjectType;
        /** Champ picklist portant le statut du devis. */
        String champStatut;
        /** Champ numérique « surface habitable », qui détermine la puissance. */
        String champSurface;
        /** Champ affiché comme titre de la modale. */
        String champTitre;
        /** Liste blanche : champs LISIBLES par le composant. */
        Set<String> champsLisibles;
        /** Liste blanche : champs MODIFIABLES par le composant (sous-ensemble). */
        Set<String> champsModifiables;

        ConfigObjet(String t, String statut, String surface, String titre,
                    Set<String> lisibles, Set<String> modifiables) {
            this.sobjectType       = t;
            this.champStatut       = statut;
            this.champSurface      = surface;
            this.champTitre        = titre;
            this.champsLisibles    = lisibles;
            this.champsModifiables = modifiables;
        }
    }

    private static final ConfigObjet CONFIG_LEAD = new ConfigObjet(
        'Lead',
        'RES_Statut_Devis__c',
        'Surface_habitable__c',
        'Name',
        new Set<String>{
            'Id', 'Name', 'FirstName', 'LastName', 'Company',
            'Email', 'Phone', 'MobilePhone',
            'Street', 'PostalCode', 'City', 'Country', 'REGIE_Adresse_Client__c',
            'Surface_habitable__c', 'RES_Statut_Devis__c',
            // Suivi Yousign — LECTURE SEULE : ces champs sont écrits par
            // envoyerPourSignature et par le retour de signature, jamais par
            // l'utilisateur. Ils ne figurent donc pas dans champsModifiables.
            'YS_Demande_Id__c', 'YS_Statut__c', 'YS_Date_Envoi__c', 'YS_Date_Signature__c',
            'YS_Nb_Relances__c',
            'YS_Contrat_Doc_Id__c', 'YS_Contrat_Empreinte__c',
            'YS_Numero_Devis__c',
            // Fiche produit — LECTURE SEULE. Elle designe les reglages de
            // signature dans c/lwc000_utils : langue, expediteur, emplacements.
            // Sur la Piste, ce champ porte le codeProduit exact
            // (« RESIDENTIEL_REGIES_-_RES060 »).
            'TypeDeDossier__c',
            // Choisit la VERSION du devis quand la fiche en propose plusieurs :
            // deux contrats distincts, deux restes a charge differents.
            // Modifiable — c'est une saisie du recapitulatif.
            'Type_Devis__c',
            // Nombre de capteurs retenu pour le devis TH168 : propose par une
            // regle de la fiche, tranche par l'utilisateur. Modifiable.
            'Nombre_Capteurs__c',
            // Surface de toiture : dimensionne le solaire du TH168 (la surface
            // habitable, elle, dimensionne la pompe a chaleur). Modifiable.
            'Surface_Toiture__c',
            // Numero client « CL-01001 » — numerotation automatique, donc en
            // LECTURE SEULE par nature : il s'imprime, il ne se saisit pas.
            'Numero_Client__c'
        },
        new Set<String>{
            'FirstName', 'LastName', 'Company',
            'Email', 'Phone', 'MobilePhone',
            'Street', 'PostalCode', 'City', 'REGIE_Adresse_Client__c',
            'Surface_habitable__c', 'Type_Devis__c', 'Nombre_Capteurs__c',
            'Surface_Toiture__c'
        }
    );

    private static final ConfigObjet CONFIG_PRO = new ConfigObjet(
        'Pro__c',
        'devisfinal__c',
        'MPR_SHAB__c',
        'Name',
        new Set<String>{
            'Id', 'Name', 'PRO_Pr_nom_du_Signataire__c',
            'Email__c', 'PRO_Email_Signataire__c', 'Phone__c',
            'Client_Adresse_Chantier__c', 'CodePostal__c',
            'MPR_SHAB__c', 'devisfinal__c',
            // Suivi Yousign — LECTURE SEULE, voir CONFIG_LEAD.
            'YS_Demande_Id__c', 'YS_Statut__c', 'YS_Date_Envoi__c', 'YS_Date_Signature__c',
            'YS_Nb_Relances__c',
            'YS_Contrat_Doc_Id__c', 'YS_Contrat_Empreinte__c',
            'YS_Numero_Devis__c',
            // Fiche produit — LECTURE SEULE, voir CONFIG_LEAD. ⚠️ Le Dossier
            // porte ici un LIBELLE (« BAR_TH171- PAC Indiv ») la ou la Piste
            // porte un code : reglagesSignature() reconnait les deux formes.
            'Fiche_CEE__c'
        },
        new Set<String>{
            'PRO_Pr_nom_du_Signataire__c',
            'Email__c', 'PRO_Email_Signataire__c', 'Phone__c',
            'Client_Adresse_Chantier__c', 'CodePostal__c',
            'MPR_SHAB__c'
        }
    );

    /* ════════════════════════════════════════════════════════════════════════
       STATUTS — normalisation en codes stables
       ════════════════════════════════════════════════════════════════════════ */

    public static final String CODE_GENERATION        = 'GENERATION';
    public static final String CODE_ATTENTE_SIGNATURE = 'ATTENTE_SIGNATURE';
    public static final String CODE_SIGNE             = 'SIGNE';
    public static final String CODE_INCONNU           = 'INCONNU';

    /**
     * Valeur de picklist -> code.
     *
     * Les clés couvrent les DEUX jeux de valeurs (Lead et Pro__c). La comparaison
     * se fait sur la valeur débarrassée de ses espaces, pour absorber la variante
     * « 🟦En Att Signature » / « 🟦 En Att Signature » sans dépendre d'un espace.
     */
    private static final Map<String, String> CODES_STATUT = new Map<String, String>{
        '▣générationdevis'      => CODE_GENERATION,
        '▣generationdevis'      => CODE_GENERATION,
        '🟦enattsignature'      => CODE_ATTENTE_SIGNATURE,
        '🟦enattentesignature'  => CODE_ATTENTE_SIGNATURE,
        '🟩signé'               => CODE_SIGNE,
        '🟩signe'               => CODE_SIGNE
    };

    private static String codeStatut(String valeur) {
        if (String.isBlank(valeur)) return CODE_GENERATION; // pas encore renseigné => début de cycle
        String cle = valeur.deleteWhitespace().toLowerCase();
        String code = CODES_STATUT.get(cle);
        return code == null ? CODE_INCONNU : code;
    }

    /**
     * codeStatut() ouvert aux traitements de retour de signature
     * (YS_TraitementSignature), qui doivent savoir si un devis est déjà signé
     * avant de rejouer un événement Yousign.
     */
    public static String codeStatutPublic(String valeur) {
        return codeStatut(valeur);
    }

    /** Nom d'API du champ portant le statut du devis, selon l'objet. */
    public static String champStatut(String sobjectType) {
        return config(sobjectType).champStatut;
    }

    /**
     * Valeur de picklist à écrire pour un code donné.
     *
     * Elle est DÉDUITE de la définition du champ, pas écrite en dur : les deux
     * objets ne portent pas les mêmes libellés (« 🟦En Att Signature » sur Lead,
     * « 🟦En Attente Signature » sur Pro__c) et rien n'interdit au métier de les
     * retoucher. On parcourt donc les valeurs actives et on retient celle qui se
     * normalise vers le code demandé — ce qui reste juste même après un
     * renommage, tant que codeStatut sait la reconnaître.
     */
    public static String valeurStatut(String sobjectType, String code) {
        ConfigObjet cfg = config(sobjectType);
        Schema.DescribeFieldResult d = Schema.getGlobalDescribe()
            .get(cfg.sobjectType).getDescribe()
            .fields.getMap().get(cfg.champStatut.toLowerCase()).getDescribe();

        for (Schema.PicklistEntry entree : d.getPicklistValues()) {
            if (entree.isActive() && codeStatut(entree.getValue()) == code) {
                return entree.getValue();
            }
        }
        throw erreur('Aucune valeur de « ' + d.getLabel() + ' » ne correspond à l\'état « '
            + code + ' ». La liste de sélection a-t-elle été modifiée ?');
    }

    private static ConfigObjet config(String sobjectType) {
        if (sobjectType == 'Lead')   return CONFIG_LEAD;
        if (sobjectType == 'Pro__c') return CONFIG_PRO;
        throw erreur('Ce type d\'enregistrement ne gère pas de devis.');
    }

    /* ════════════════════════════════════════════════════════════════════════
       WRAPPERS RENVOYÉS AU LWC
       ════════════════════════════════════════════════════════════════════════ */

    /** Un champ du récapitulatif, prêt à afficher. */
    public class ChampDevis {
        @AuraEnabled public String  apiName    { get; set; }
        /** Libellé Salesforce ; le LWC peut le remplacer par le sien. */
        @AuraEnabled public String  label      { get; set; }
        /** DisplayType Salesforce : STRING, EMAIL, PHONE, DOUBLE, DATE… */
        @AuraEnabled public String  type       { get; set; }
        /** Valeur sérialisée en texte (dates en ISO, nombres en notation simple). */
        @AuraEnabled public String  valeur     { get; set; }
        /** false si le champ n'est pas dans la liste blanche d'écriture. */
        @AuraEnabled public Boolean modifiable { get; set; }
    }

    /** Charge utile complète d'un devis. */
    public class DevisData {
        @AuraEnabled public String  recordId     { get; set; }
        @AuraEnabled public String  objectType   { get; set; }
        /** 'Piste' ou 'Dossier' — le vocabulaire du portail. */
        @AuraEnabled public String  typeLibelle  { get; set; }
        @AuraEnabled public String  titre        { get; set; }
        /** Valeur brute de la picklist de statut. */
        @AuraEnabled public String  statutValeur { get; set; }
        /** Code normalisé : GENERATION / ATTENTE_SIGNATURE / SIGNE / INCONNU. */
        @AuraEnabled public String  statutCode   { get; set; }
        /** Nom d'API du champ « surface habitable » de cet objet. */
        @AuraEnabled public String  champSurface { get; set; }
        @AuraEnabled public Decimal surface      { get; set; }
        @AuraEnabled public List<ChampDevis> champs { get; set; }
    }

    /* ════════════════════════════════════════════════════════════════════════
       API @AuraEnabled
       ════════════════════════════════════════════════════════════════════════ */

    /**
     * Charge le devis d'un Lead ou d'un Pro__c.
     *
     * @param recordId     Id du Lead ou du Pro__c.
     * @param campaignCode Token de campagne (Campaign.CampaignToken__c).
     * @param champs       Champs souhaités par le LWC ; intersectés avec la liste
     *                     blanche. Vide ou null => toute la liste blanche.
     */
    @AuraEnabled
    public static DevisData getDevis(String recordId, String campaignCode, List<String> champs) {
        try {
            ConfigObjet cfg = verifierAcces(recordId, campaignCode);
            return lire(recordId, cfg, champsAutorises(cfg, champs, false));
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'LC021_DevisSignature.getDevis : ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw erreur('Impossible de charger le devis.');
        }
    }

    /**
     * Enregistre les champs modifiés du récapitulatif, puis renvoie le devis
     * rechargé — le LWC n'a donc qu'UN aller-retour à faire, pas deux.
     *
     * @param valeurs Map nom d'API -> valeur saisie (toujours du texte côté LWC).
     *                Les clés hors liste blanche d'écriture sont ignorées.
     */
    @AuraEnabled
    public static DevisData enregistrerDevis(String recordId, String campaignCode,
                                             Map<String, String> valeurs,
                                             List<String> champs) {
        try {
            ConfigObjet cfg = verifierAcces(recordId, campaignCode);

            // Un devis SIGNÉ ne se modifie plus. Le composant masque déjà le
            // récapitulatif dans ce cas ; le contrôle est REFAIT ici parce que
            // masquer un écran n'empêche pas d'appeler la méthode, et qu'il
            // s'agit des données d'un document contractuel déjà signé.
            if (statutCourant(recordId, cfg) == CODE_SIGNE) {
                throw erreur('Ce devis est signé : ses informations ne peuvent plus être modifiées.');
            }

            Set<String> autorisesEcriture = champsAutorises(cfg, null, true);
            SObject enregistrement = Schema.getGlobalDescribe()
                .get(cfg.sobjectType).newSObject();
            enregistrement.put('Id', recordId);

            Map<String, Schema.SObjectField> champsSf = Schema.getGlobalDescribe()
                .get(cfg.sobjectType).getDescribe().fields.getMap();

            Integer modifies = 0;
            if (valeurs != null) {
                for (String api : valeurs.keySet()) {
                    if (!autorisesEcriture.contains(api)) {
                        // Champ non ouvert à l'écriture : ignoré en silence côté
                        // utilisateur, tracé côté debug.
                        System.debug(LoggingLevel.WARN,
                            'LC021_DevisSignature : écriture refusée sur ' + cfg.sobjectType + '.' + api);
                        continue;
                    }
                    Schema.DescribeFieldResult d = champsSf.get(api.toLowerCase()).getDescribe();
                    enregistrement.put(api, convertir(valeurs.get(api), d.getType()));
                    modifies++;
                }
            }

            if (modifies > 0) {
                update enregistrement;
            }

            return lire(recordId, cfg, champsAutorises(cfg, champs, false));

        } catch (AuraHandledException e) {
            throw e;
        } catch (DmlException e) {
            System.debug(LoggingLevel.ERROR, 'LC021_DevisSignature.enregistrerDevis (DML) : ' + e.getMessage());
            throw erreur(e.getNumDml() > 0 ? e.getDmlMessage(0) : e.getMessage());
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'LC021_DevisSignature.enregistrerDevis : ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw erreur('Impossible d\'enregistrer les modifications.');
        }
    }

    /** Nom du Static Resource du contrat — aligné sur devisConfig.PDF_RESOURCE_NAME. */
    /** Gabarit servi quand la fiche n'en designe aucun. */
    private static final String RESSOURCE_CONTRAT = 'cae_colab_contrat';

    /**
     * Gabarits qu'un composant du portail a le droit de demander.
     *
     * ⚠️ CETTE LISTE EST UNE MESURE DE SECURITE, pas une commodite. Le nom de la
     * ressource vient du navigateur : sans filtre, un utilisateur du portail —
     * ou l'invite d'un site public — pourrait demander N'IMPORTE QUELLE
     * ressource statique de l'org, dont certaines contiennent des cles ou des
     * gabarits internes. On ne sert donc que ce qui est nomme ici.
     *
     * DOUBLON ASSUME avec le catalogue produits de c/lwc000_utils : ajouter un
     * gabarit demande de le declarer aux DEUX endroits. C'est le prix a payer
     * pour que le serveur ne fasse pas confiance au client sur ce point.
     */
    private static final Set<String> RESSOURCES_CONTRAT_AUTORISEES = new Set<String>{
        'cae_colab_contrat', // RES060 — Pompe a chaleur (Espagne)
        'DEVIS_TH168',       // TH168  — Solaire (France)
        'DEVIS_TH110_v1',    // 110    — 100% pris en charge, grand precaire
        'DEVIS_TH110_v2',    // 110    — 3500 EUR de reste a charge, classique
        'DEVIS_SE104'        // SE104  — Gonfleurs (Transport, France)
    };

    /**
     * Nom de ressource utilisable, ou le gabarit par defaut.
     *
     * ⚠️ UN NOM HORS LISTE EST REFUSE, il ne retombe PAS sur le gabarit par
     * defaut. La premiere version repliait en silence, et le defaut s'est
     * manifeste des la deuxieme fiche : le TH168 partait a la signature avec le
     * contrat de la 060, sans le moindre signal. Servir un AUTRE contrat que
     * celui demande est pire que ne rien servir — c'est un document
     * contractuel, et l'erreur ne se voit qu'apres signature du client.
     *
     * Le message reste volontairement vague : il dit qu'on ne peut pas servir
     * le document, jamais ce que le serveur accepte. Le detail part dans les
     * logs, ou l'administrateur le trouvera.
     *
     * Un nom VIDE, lui, reste legitime : c'est le cas d'une fiche qui ne
     * declare pas de gabarit, et le defaut s'applique.
     */
    private static String ressourceContrat(String demandee) {
        if (String.isBlank(demandee)) return RESSOURCE_CONTRAT;
        String nom = demandee.trim();
        if (RESSOURCES_CONTRAT_AUTORISEES.contains(nom)) return nom;

        System.debug(LoggingLevel.ERROR,
            'Gabarit non autorise : ' + nom + '. A declarer dans '
            + 'RESSOURCES_CONTRAT_AUTORISEES si la fiche est legitime.');
        throw erreur('Document contractuel indisponible.');
    }

    /**
     * Livre le PDF du contrat en base64.
     *
     * POURQUOI PASSER PAR L'APEX — dans le site Campagnes, Lightning Web
     * Security interdit au composant tout fetch() vers l'URL du Static Resource
     * (« Cannot request disallowed endpoint …/resource/… »). Un appel Apex, lui,
     * passe par le canal Aura autorisé. Le composant reçoit donc les octets ici,
     * coche la case avec pdf-lib côté client, et affiche le résultat en blob:.
     *
     * `cacheable=true` : le contrat est un gabarit fixe, identique pour tous les
     * dossiers — le client Aura peut le garder en cache sans risque.
     */
    @AuraEnabled(cacheable=true)
    public static String getContratBase64(String campaignCode, String ressource) {
        try {
            verifierAccesPortail(campaignCode);
            String nom = ressourceContrat(ressource);
            List<StaticResource> ressources = [
                SELECT Body FROM StaticResource WHERE Name = :nom LIMIT 1
            ];
            if (ressources.isEmpty()) {
                throw erreur('Document contractuel introuvable.');
            }
            return EncodingUtil.base64Encode(ressources[0].Body);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'LC021_DevisSignature.getContratBase64 : ' + e.getMessage());
            throw erreur('Impossible de charger le document contractuel.');
        }
    }

    /* ════════════════════════════════════════════════════════════════════════
       CONTRAT JOINT AU RECORD

       Le PDF coché (généré côté client par pdf-lib) est stocké comme FICHIER
       Salesforce sur la Piste ou le Dossier : c'est lui qui sera visualisé,
       enrichi puis envoyé à uSign / DocuSign. Un seul ContentDocument par
       record (titre fixe) ; chaque nouvelle puissance produit une VERSION de
       plus, jamais un doublon de document.
       ════════════════════════════════════════════════════════════════════════ */

    /** Titre du ContentDocument portant le contrat — la clé de déduplication. */
    public static final String TITRE_CONTRAT = 'Presupuesto - Contrato';
    public static final String NOM_FICHIER_CONTRAT = 'Presupuesto_CAE_Contrato.pdf';

    /** Résultat du stockage, renvoyé au composant. */
    public class ContratJoint {
        @AuraEnabled public String  contentDocumentId { get; set; }
        @AuraEnabled public String  contentVersionId  { get; set; }
        /** true si le fichier stocké était déjà identique (aucune version créée). */
        @AuraEnabled public Boolean dejaAJour         { get; set; }
    }

    /**
     * Joint le contrat coché au record, en versionnant.
     *
     * DÉDUPLICATION — la modale peut être ouverte plusieurs fois sur le même
     * record sans que rien ne change : re-stocker créerait une version par
     * ouverture. Le MD5 du contenu reçu est donc comparé au `Checksum` de la
     * dernière version : identique => aucune écriture, on renvoie l'existant.
     */
    @AuraEnabled
    public static ContratJoint enregistrerContrat(String recordId, String campaignCode,
                                                  String contenuBase64, String empreinte) {
        try {
            ConfigObjet cfg = verifierAcces(recordId, campaignCode);

            if (String.isBlank(contenuBase64)) {
                throw erreur('Contenu du contrat manquant.');
            }
            Blob octets = EncodingUtil.base64Decode(contenuBase64);
            // 'JVBERi' = '%PDF-' : refuse tout contenu qui n'est pas un PDF.
            if (!contenuBase64.startsWith('JVBERi')) {
                throw erreur('Le contenu reçu n\'est pas un PDF.');
            }

            ContratJoint resultat = new ContratJoint();
            resultat.dejaAJour = false;

            // ── Ce qui est DÉJÀ joint, lu sur l'enregistrement ───────────────
            //
            // ⚠️ NE PAS repasser par ContentDocumentLink : l'utilisateur invité
            // du portail ne peut pas lire cette table. La requête renvoyait
            // toujours zéro, donc aucun ContentDocumentId n'était transmis à
            // l'insertion, et chaque ouverture de la modale créait un DOCUMENT
            // de plus au lieu d'une version — sept fichiers de 874 Ko sur une
            // même Piste, constaté en sandbox. Le pointeur et l'empreinte
            // vivent desormais sur le record, que le portail sait lire.
            SObject etat = etatContrat(idRecordContrat(recordId), cfg);
            String docIdConnu   = (String) etat.get('YS_Contrat_Doc_Id__c');
            String empreinteAnc = (String) etat.get('YS_Contrat_Empreinte__c');

            // Même contenu qu'auparavant : rien à écrire, ni fichier ni champ.
            if (String.isNotBlank(docIdConnu) && String.isNotBlank(empreinte)
                && empreinte == empreinteAnc) {
                resultat.contentDocumentId = docIdConnu;
                resultat.dejaAJour = true;
                return resultat;
            }

            // Repli pour les utilisateurs INTERNES, qui voient les liens : si le
            // record ne porte pas encore de pointeur mais qu'un fichier existe,
            // on le versionne plutôt que d'en créer un second.
            ContentVersion derniere = String.isBlank(docIdConnu)
                ? derniereVersionContrat(recordId)
                : null;
            if (derniere != null) {
                docIdConnu = derniere.ContentDocumentId;
                String md5 = EncodingUtil.convertToHex(Crypto.generateDigest('MD5', octets));
                if (derniere.Checksum == md5) {
                    resultat.contentDocumentId = derniere.ContentDocumentId;
                    resultat.contentVersionId  = derniere.Id;
                    resultat.dejaAJour = true;
                    memoriserContrat(idRecordContrat(recordId), cfg,
                                     derniere.ContentDocumentId, empreinte);
                    return resultat;
                }
            }

            // ── Nouvelle version (ou premier fichier) ────────────────────────
            // ⚠️ GUEST USER — le portail tourne souvent sous l'utilisateur invité
            // du site, et Salesforce lui INTERDIT d'insérer un ContentDocumentLink
            // (INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY « Vous n'êtes pas
            // autorisé à partager ce fichier »), même en without sharing — constaté
            // en sandbox. La liaison passe donc par FirstPublishLocationId : c'est
            // la PLATEFORME qui crée le lien à l'insertion, aucune opération de
            // partage explicite. Même procédé que CustomFileUploadController.
            ContentVersion version = nouvelleVersion(octets,
                String.isBlank(docIdConnu) ? null : (Id) docIdConnu, recordId);
            try {
                insert version;
            } catch (DmlException dmlEx) {
                // Rien n'avait été tenté sur un document existant : l'échec est
                // réel, il n'y a pas de repli possible.
                if (String.isBlank(docIdConnu)) throw dmlEx;

                // Le pointeur mémorisé peut être PÉRIMÉ, et de deux façons :
                //   • le fichier a été supprimé depuis (ENTITY_IS_DELETED) —
                //     c'est ce qui s'est produit après le ménage des doublons ;
                //   • il appartient à un autre utilisateur, qui refuse qu'on y
                //     ajoute une version (invité vs interne).
                // Dans les deux cas on repart sur un NOUVEAU document, et le
                // pointeur est corrigé quelques lignes plus bas. Le mécanisme
                // se répare donc de lui-même : sans cela, un fichier supprimé
                // à la main bloquait définitivement la génération du devis.
                System.debug(LoggingLevel.WARN,
                    'LC021_DevisSignature : pointeur de contrat périmé (' + docIdConnu
                    + '), nouveau document — ' + dmlEx.getMessage());
                docIdConnu = null;
                version = nouvelleVersion(octets, null, recordId);
                insert version;
            }

            version = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :version.Id];
            resultat.contentDocumentId = version.ContentDocumentId;
            resultat.contentVersionId  = version.Id;

            // Le record garde le pointeur ET l'empreinte : c'est ce couple qui
            // evitera de rejoindre le meme fichier au prochain passage.
            memoriserContrat(idRecordContrat(recordId), cfg, version.ContentDocumentId, empreinte);
            return resultat;

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'LC021_DevisSignature.enregistrerContrat : ' + e.getMessage() + '\n' + e.getStackTraceString());
            // Le motif REEL accompagne le message. Un « Impossible de joindre le
            // devis » muet obligeait a activer un journal de debogage sur
            // l'utilisateur invite pour apprendre quoi que ce soit : un aller-
            // retour a chaque incident, alors que l'ecran pouvait le dire.
            throw erreur('Impossible de joindre le devis au dossier. ['
                + e.getTypeName() + ' : ' + e.getMessage() + ']');
        }
    }

    /* ════════════════════════════════════════════════════════════════════════
       NUMÉRO DE DEVIS

       Le gabarit PDF imprime « HP-2026- » sur ses deux premières pages ; c'est
       le numéro qui suit que nous produisons ici.
       ════════════════════════════════════════════════════════════════════════ */

    /**
     * Réserve — ou rappelle — le numéro du devis de cet enregistrement.
     *
     * IDEMPOTENTE, et c'est ce qui rend le mécanisme tenable : rouvrir la
     * modale, ou regénérer le document après correction d'une adresse, ne doit
     * pas consommer un numéro de plus. Un enregistrement déjà numéroté garde le
     * sien, et le compteur ne bouge pas.
     *
     * Appelée par le composant AVANT de fabriquer le PDF, puisque le numéro y
     * est imprimé. La séquence est partagée entre Piste et Dossier : c'est ce
     * qui garantit qu'un numéro ne sert jamais deux fois.
     */
    @AuraEnabled
    public static String reserverNumeroDevis(String recordId, String campaignCode,
                                            String cleCompteur) {
        try {
            ConfigObjet cfg = verifierAcces(recordId, campaignCode);
            Id idRecord = (Id) recordId;

            String soql = 'SELECT YS_Numero_Devis__c FROM ' + cfg.sobjectType
                        + ' WHERE Id = :idRecord LIMIT 1';
            List<SObject> lignes = Database.query(soql);
            if (lignes.isEmpty()) throw erreur('Enregistrement introuvable.');

            String existant = (String) lignes[0].get('YS_Numero_Devis__c');
            if (String.isNotBlank(existant)) return existant;

            // La sequence est designee par la FICHE (c/lwc000_utils). A defaut,
            // la sequence historique du devis : une fiche qui ne dit rien garde
            // le comportement d'avant.
            //
            // ⚠️ La cle vient du navigateur. Elle n'expose aucune donnee — un
            // compteur ne contient qu'un entier — mais une cle forgee ferait
            // CONSOMMER des numeros a une autre serie. Le risque est une serie
            // trouee, jamais une fuite. Si cela devient genant, la parade est un
            // drapeau « utilisable par le portail » sur YS_Compteur__c, plutot
            // qu'une liste en dur ici qu'il faudrait tenir a jour.
            String cle = String.isBlank(cleCompteur)
                ? YS_Numerotation.CLE_DEVIS
                : cleCompteur.trim();
            String numero = YS_Numerotation.suivant(cle);

            SObject maj = Schema.getGlobalDescribe().get(cfg.sobjectType).newSObject();
            maj.put('Id', idRecord);
            maj.put('YS_Numero_Devis__c', numero);
            update maj;

            return numero;

        } catch (AuraHandledException e) {
            throw e;
        } catch (YS_Numerotation.NumerotationException e) {
            // Message deja explicite (cle manquante, pas invalide) : on le passe
            // tel quel plutot que de le remplacer par une formule vague.
            System.debug(LoggingLevel.ERROR, 'LC021_DevisSignature.reserverNumeroDevis : ' + e.getMessage());
            throw erreur(e.getMessage());
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'LC021_DevisSignature.reserverNumeroDevis : '
                + e.getMessage() + '\n' + e.getStackTraceString());
            throw erreur('Impossible d\'attribuer un numéro à ce devis.');
        }
    }

    /**
     * Dernière version d'un document désigné par son Id.
     *
     * Ne passe PAS par ContentDocumentLink, et c'est tout l'intérêt : c'est le
     * seul chemin qu'un utilisateur invité puisse emprunter.
     */
    private static ContentVersion versionDeDocument(String documentId) {
        if (String.isBlank(documentId)) return null;
        List<ContentVersion> versions = [
            SELECT Id, ContentDocumentId, Checksum, VersionData
            FROM ContentVersion
            WHERE ContentDocumentId = :documentId AND IsLatest = true
            LIMIT 1
        ];
        return versions.isEmpty() ? null : versions[0];
    }

    /** Conversion sans surprise : recordId arrive en String depuis le composant. */
    private static Id idRecordContrat(String recordId) {
        return (Id) recordId;
    }

    /** Pointeur et empreinte du contrat deja joint, lus sur l'enregistrement. */
    private static SObject etatContrat(Id recordId, ConfigObjet cfg) {
        String soql = 'SELECT YS_Contrat_Doc_Id__c, YS_Contrat_Empreinte__c, YS_Signe_Doc_Id__c FROM '
                    + cfg.sobjectType + ' WHERE Id = :recordId LIMIT 1';
        List<SObject> lignes = Database.query(soql);
        if (lignes.isEmpty()) throw erreur('Enregistrement introuvable.');
        return lignes[0];
    }

    /**
     * Retient QUEL document porte le devis et POUR QUEL contenu.
     *
     * Sans ce couple, la deduplication reposait sur une requete ContentDocumentLink
     * que l'utilisateur invite ne peut pas executer — voir enregistrerContrat.
     */
    private static void memoriserContrat(Id recordId, ConfigObjet cfg,
                                         Id documentId, String empreinte) {
        SObject maj = Schema.getGlobalDescribe().get(cfg.sobjectType).newSObject();
        maj.put('Id', recordId);
        maj.put('YS_Contrat_Doc_Id__c', documentId == null ? null : String.valueOf(documentId));
        // Tronquee a la longueur du champ : l'empreinte porte l'adresse
        // complete, et une adresse longue ferait echouer tout
        // l'enregistrement du devis pour une raison sans rapport avec lui.
        maj.put('YS_Contrat_Empreinte__c',
                empreinte == null || empreinte.length() <= 255
                    ? empreinte
                    : empreinte.substring(0, 255));
        update maj;
    }

    /** Code de statut du devis, lu directement en base — jamais depuis le client. */
    private static String statutCourant(Id recordId, ConfigObjet cfg) {
        String soql = 'SELECT ' + cfg.champStatut + ' FROM ' + cfg.sobjectType
                    + ' WHERE Id = :recordId LIMIT 1';
        List<SObject> lignes = Database.query(soql);
        return lignes.isEmpty()
            ? CODE_INCONNU
            : codeStatut((String) lignes[0].get(cfg.champStatut));
    }

    /**
     * Contrat DÉJÀ JOINT au record, en base64 — pour un devis signé.
     *
     * Le composant ne doit surtout pas regénérer le PDF dans ce cas : il le
     * réattacherait et écraserait le document signé. Il lit donc le fichier
     * stocké par cette méthode et se contente de l'afficher.
     */
    @AuraEnabled
    public static String getContratStockeBase64(String recordId, String campaignCode) {
        try {
            return EncodingUtil.base64Encode(lireContratStocke(recordId, campaignCode));
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'LC021_DevisSignature.getContratStockeBase64 : ' + e.getMessage());
            throw erreur('Impossible de charger le devis signé.');
        }
    }

    /** Squelette d'une version de contrat. `docId` null => nouveau document,
     *  lié au record PAR LA PLATEFORME via FirstPublishLocationId. */
    private static ContentVersion nouvelleVersion(Blob octets, Id docId, Id recordId) {
        ContentVersion version = new ContentVersion(
            Title        = TITRE_CONTRAT,
            PathOnClient = NOM_FICHIER_CONTRAT,
            VersionData  = octets
        );
        if (docId != null) {
            version.ContentDocumentId = docId;
        } else {
            version.FirstPublishLocationId = recordId;
        }
        return version;
    }

    /**
     * Dernière version du contrat lié au record — TOUS documents de contrat
     * confondus : le repli guest (voir enregistrerContrat) peut en avoir créé
     * plusieurs, la plus récente fait foi.
     */
    private static ContentVersion derniereVersionContrat(Id recordId) {
        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink lien : [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
            AND ContentDocument.Title = :TITRE_CONTRAT
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

    /**
     * Octets de la DERNIÈRE version du contrat joint au record.
     * Utilisé par LC021_DevisContratRest pour servir l'aperçu inline — mêmes
     * verrous que le reste du workflow, et UNIQUEMENT le document de contrat de
     * ce record : jamais un fichier arbitraire.
     */
    public static Blob lireContratStocke(String recordId, String campaignCode) {
        verifierAcces(recordId, campaignCode);

        // ══ ORDRE DE PRÉFÉRENCE ═════════════════════════════════════════
        //
        // Le devis SIGNÉ prime toujours : une fois le client passé par Yousign,
        // c'est cette version-là qui fait foi. Le devis vierge reste joint au
        // record mais n'est plus le document de référence.
        //
        // ⚠️ Les POINTEURS d'abord, les recherches par ContentDocumentLink
        // ensuite. Dans l'autre sens, l'utilisateur invité du portail — qui ne
        // peut pas lire cette table — voyait les deux recherches échouer et
        // retombait sur le pointeur du CONTRAT : la modale affichait le devis
        // vierge alors que le dossier portait bien le devis signé. Constaté en
        // sandbox le 31/08/2026.
        Id idRecord = (Id) recordId;
        ConfigObjet cfg = config(String.valueOf(idRecord.getSObjectType()));
        SObject etat = etatContrat(idRecord, cfg);

        ContentVersion derniere = versionDeDocument((String) etat.get('YS_Signe_Doc_Id__c'));
        if (derniere == null) derniere = YS_TraitementSignature.derniereVersionSignee(idRecord);
        if (derniere == null) derniere = versionDeDocument((String) etat.get('YS_Contrat_Doc_Id__c'));
        if (derniere == null) derniere = derniereVersionContrat(idRecord);

        if (derniere == null) {
            throw erreur('Aucun contrat joint à cet enregistrement.');
        }
        return derniere.VersionData;
    }

    /* ════════════════════════════════════════════════════════════════════════
       ENVOI POUR SIGNATURE — Yousign

       Le contrat déjà joint au record (onglet 2) part chez Yousign, qui adresse
       au client un mail de signature. Le RETOUR, lui, ne passe pas par ici : il
       arrive par le webhook (YS_WebhookRest) ou par le batch de réconciliation,
       tous deux aboutissant à YS_TraitementSignature.
       ════════════════════════════════════════════════════════════════════════ */

    /** Ce que le composant apprend de l'envoi. */
    public class EnvoiSignature {
        /** true si la demande est bien partie chez Yousign. */
        @AuraEnabled public Boolean envoye    { get; set; }
        /** Identifiant Yousign de la demande, quand elle a pu être créée. */
        @AuraEnabled public String  demandeId { get; set; }
        /** Adresse effectivement destinataire — le composant l'affiche. */
        @AuraEnabled public String  email     { get; set; }
        /** Motif d'échec, renseigné uniquement si envoye vaut false. */
        @AuraEnabled public String  message   { get; set; }
    }

    /**
     * Transmet au service les reglages portes par la fiche produit.
     *
     * Le JSON est volontairement TOLERANT : mal forme, il est ignore et les
     * Custom Labels reprennent la main. Lever ici aurait fait echouer l'envoi
     * pour une raison sans rapport avec la demande de l'utilisateur, et sur un
     * message qu'il ne pourrait pas comprendre.
     */
    private static void appliquerReglagesFiche(String reglagesJson) {
        if (String.isBlank(reglagesJson)) return;
        try {
            Object decode = JSON.deserializeUntyped(reglagesJson);
            if (decode instanceof Map<String, Object>) {
                YS_YousignService.appliquerReglages((Map<String, Object>) decode);
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                'Reglages de signature illisibles, repli sur les etiquettes : ' + e.getMessage());
        }
    }

    /**
     * Envoie le devis à la signature du client.
     *
     * ⚠️ ORDRE DES OPÉRATIONS — tous les appels à Yousign ont lieu AVANT le
     * moindre DML : Salesforce interdit un callout après une écriture dans la
     * même transaction (« You have uncommitted work pending »). C'est aussi
     * pourquoi le PDF n'est pas régénéré ici : il a été joint au record dans une
     * transaction antérieure, par enregistrerContrat, et c'est exactement le
     * fichier que le client a vu dans l'onglet Document qui part à la signature.
     *
     * @param emailSignataire Adresse saisie ou corrigée dans l'onglet Signature.
     *                        Vide => on retombe sur celle du record.
     * @param langue          'FR' ou 'ES' : pilote la langue du mail Yousign.
     */
    @AuraEnabled
    public static EnvoiSignature envoyerPourSignature(String recordId, String campaignCode,
                                                      String emailSignataire,
                                                      String prenomSignataire,
                                                      String nomSignataire,
                                                      String langue,
                                                      Boolean relance,
                                                      String reglagesSignature) {
        ConfigObjet cfg = verifierAcces(recordId, campaignCode);
        Id idRecord = (Id) recordId;

        // Langue, expediteur et emplacements viennent de la FICHE PRODUIT
        // (c/lwc000_utils), pas des Custom Labels : ils varient d'une fiche a
        // l'autre, et un label est unique pour toute l'org.
        //
        // Le composant les transmet en JSON plutot qu'en parametres separes :
        // une fiche pourra en porter d'autres demain sans qu'il faille toucher
        // a cette signature ni aux 18 profils qui l'autorisent.
        //
        // Absents ou illisibles, l'Apex retombe sur les labels : un envoi ne
        // doit pas echouer parce qu'une fiche a ete mal decrite.
        appliquerReglagesFiche(reglagesSignature);

        // ── État courant, en une seule lecture ───────────────────────────────
        SObject record = etatSignature(idRecord, cfg);

        if (codeStatut((String) record.get(cfg.champStatut)) == CODE_SIGNE) {
            throw erreur('Ce devis est déjà signé.');
        }

        String statutYs  = (String) record.get('YS_Statut__c');
        String demandeYs = (String) record.get('YS_Demande_Id__c');
        Boolean estRelance = (relance == true);

        // Une demande en cours bloque un envoi ordinaire — c'est la protection
        // contre le double clic — mais PAS une relance, qui est justement le
        // geste de renvoyer alors qu'une demande traîne sans réponse.
        if (!estRelance && String.isNotBlank(demandeYs)
            && (statutYs == 'Envoye' || statutYs == 'Ouvert')) {
            Datetime envoiLe = (Datetime) record.get('YS_Date_Envoi__c');
            throw erreur('Une demande de signature est déjà en cours'
                + (envoiLe == null ? '' : ' depuis le ' + envoiLe.format('dd/MM/yyyy HH:mm'))
                + '.');
        }

        // Le PREMIER envoi n'est pas une relance : le compteur ne bouge que si
        // une demande existait deja pour cet enregistrement.
        Decimal relancesAvant = (Decimal) record.get('YS_Nb_Relances__c');
        if (relancesAvant == null) relancesAvant = 0;
        Boolean compteUneRelance = estRelance && String.isNotBlank(demandeYs);

        // ── Destinataire ─────────────────────────────────────────────────────
        YS_YousignService.Signataire dest = signataire(
            record, cfg, emailSignataire, prenomSignataire, nomSignataire, langue);

        if (String.isBlank(dest.email)) {
            throw erreur('Aucune adresse email pour le signataire : renseignez-la avant d\'envoyer le devis.');
        }
        if (!Pattern.matches('^[^@\\s]+@[^@\\s]+\\.[^@\\s]{2,}$', dest.email)) {
            throw erreur('L\'adresse email du signataire est invalide : ' + dest.email);
        }

        // ── Document ─────────────────────────────────────────────────────────
        ContentVersion contrat = derniereVersionContrat(idRecord);
        if (contrat == null) {
            throw erreur('Aucun devis n\'est joint à cet enregistrement : ouvrez l\'onglet Document pour le générer.');
        }

        EnvoiSignature retour = new EnvoiSignature();
        retour.email = dest.email;

        // ── Appels Yousign — AVANT tout DML ──────────────────────────────────
        String demandeId;
        try {
            String titre = String.valueOf(record.get(cfg.champTitre));
            demandeId = YS_YousignService.creerDemande('Presupuesto - ' + titre, dest.locale);

            String documentId = YS_YousignService.ajouterDocument(
                demandeId, contrat.VersionData, NOM_FICHIER_CONTRAT);

            YS_YousignService.ajouterSignataire(
                demandeId, documentId, dest, YS_YousignService.positionSignature());

            YS_YousignService.activer(demandeId);

        } catch (Exception e) {
            // L'exception n'est PAS relancée : elle annulerait la transaction, et
            // avec elle la trace de l'échec. Le composant reçoit un retour en
            // échec, l'enregistrement conserve le motif.
            System.debug(LoggingLevel.ERROR,
                'LC021_DevisSignature.envoyerPourSignature : ' + e.getMessage());

            SObject echec = Schema.getGlobalDescribe().get(cfg.sobjectType).newSObject();
            echec.put('Id', idRecord);
            echec.put('YS_Statut__c', 'Erreur');
            echec.put('YS_Message_Erreur__c', abreger(e.getMessage(), 255));
            if (String.isNotBlank(demandeId)) echec.put('YS_Demande_Id__c', demandeId);
            update echec;

            retour.envoye    = false;
            retour.demandeId = demandeId;
            retour.message   = e.getMessage();
            return retour;
        }

        // ── Puis, seulement, l'écriture ──────────────────────────────────────
        SObject maj = Schema.getGlobalDescribe().get(cfg.sobjectType).newSObject();
        maj.put('Id', idRecord);
        maj.put('YS_Demande_Id__c', demandeId);
        maj.put('YS_Statut__c', 'Envoye');
        maj.put('YS_Date_Envoi__c', Datetime.now());
        maj.put('YS_Message_Erreur__c', null);
        maj.put(cfg.champStatut, valeurStatut(cfg.sobjectType, CODE_ATTENTE_SIGNATURE));
        if (compteUneRelance) {
            maj.put('YS_Nb_Relances__c', relancesAvant + 1);
        }
        update maj;

        retour.envoye    = true;
        retour.demandeId = demandeId;
        return retour;
    }

    /**
     * Annule le suivi Yousign en cours pour permettre un nouvel envoi.
     * Le statut métier du devis n'est pas touché : il reste « en attente de
     * signature », ce qu'il est effectivement jusqu'au prochain envoi.
     */
    @AuraEnabled
    public static void reinitialiserSignature(String recordId, String campaignCode) {
        ConfigObjet cfg = verifierAcces(recordId, campaignCode);
        Id idRecord = (Id) recordId;

        if (statutCourant(idRecord, cfg) == CODE_SIGNE) {
            throw erreur('Ce devis est déjà signé.');
        }
        SObject maj = Schema.getGlobalDescribe().get(cfg.sobjectType).newSObject();
        maj.put('Id', idRecord);
        maj.put('YS_Demande_Id__c', null);
        maj.put('YS_Statut__c', null);
        maj.put('YS_Message_Erreur__c', null);
        update maj;
    }

    /** Champs nécessaires à l'envoi — tous déjà présents dans la liste blanche de lecture. */
    private static SObject etatSignature(Id recordId, ConfigObjet cfg) {
        List<String> champs = new List<String>{
            cfg.champTitre, cfg.champStatut,
            'YS_Demande_Id__c', 'YS_Statut__c', 'YS_Date_Envoi__c', 'YS_Nb_Relances__c'
        };
        champs.addAll(cfg === CONFIG_LEAD
            ? new List<String>{ 'FirstName', 'LastName', 'Email' }
            : new List<String>{ 'PRO_Pr_nom_du_Signataire__c', 'Email__c', 'PRO_Email_Signataire__c' });

        String soql = 'SELECT ' + String.join(champs, ', ')
                    + ' FROM ' + cfg.sobjectType + ' WHERE Id = :recordId LIMIT 1';
        List<SObject> lignes = Database.query(soql);
        if (lignes.isEmpty()) throw erreur('Enregistrement introuvable.');
        return lignes[0];
    }

    /**
     * Destinataire de la signature : ce que le composant a saisi l'emporte, le
     * record ne sert que de repli — l'utilisateur peut corriger une adresse
     * fausse sans avoir à enregistrer le récapitulatif d'abord.
     *
     * Sur Pro__c, nom et prénom sont fusionnés dans un seul champ
     * (« CLIENT- Nom+Prénom du Signataire ») alors que Yousign les veut
     * séparés : on coupe au premier espace, faute de mieux.
     */
    private static YS_YousignService.Signataire signataire(
            SObject record, ConfigObjet cfg,
            String email, String prenom, String nom, String langue) {

        String mail = String.isNotBlank(email)  ? email.trim()  : null;
        String p    = String.isNotBlank(prenom) ? prenom.trim() : null;
        String n    = String.isNotBlank(nom)    ? nom.trim()    : null;

        if (cfg === CONFIG_LEAD) {
            if (mail == null) mail = (String) record.get('Email');
            if (p == null)    p    = (String) record.get('FirstName');
            if (n == null)    n    = (String) record.get('LastName');
        } else {
            if (mail == null) mail = (String) record.get('Email__c');
            if (String.isBlank(mail)) mail = (String) record.get('PRO_Email_Signataire__c');

            if (p == null || n == null) {
                String complet = (String) record.get('PRO_Pr_nom_du_Signataire__c');
                if (String.isNotBlank(complet)) {
                    complet = complet.trim();
                    Integer espace = complet.indexOf(' ');
                    if (espace > 0) {
                        if (p == null) p = complet.substring(0, espace);
                        if (n == null) n = complet.substring(espace + 1).trim();
                    } else if (n == null) {
                        n = complet;
                    }
                }
            }
        }

        // Yousign refuse un nom vide. Le prénom peut manquer en pratique, mais
        // autant que le mail reçu par le client reste lisible.
        if (String.isBlank(n)) n = 'Client';
        if (String.isBlank(p)) p = '-';

        // La langue Yousign n'est PAS forcément celle du portail : le réglage
        // vit dans le Custom Label YOUSIGN_LOCALE. Voir localeSignataire().
        return new YS_YousignService.Signataire(
            p, n, mail, YS_YousignService.localeSignataire(langue));
    }

    private static String abreger(String valeur, Integer max) {
        if (String.isBlank(valeur)) return valeur;
        return valeur.length() <= max ? valeur : valeur.substring(0, max);
    }

    /* ════════════════════════════════════════════════════════════════════════
       SÉCURITÉ APPLICATIVE
       ════════════════════════════════════════════════════════════════════════ */

    /**
     * Applique les verrous 1 à 3 et renvoie la config de l'objet concerné.
     * Toute anomalie lève une AuraHandledException : le LWC n'apprend jamais
     * l'existence d'un record hors périmètre, il reçoit le même message.
     */
    private static ConfigObjet verifierAcces(String recordId, String campaignCode) {

        // ── Verrou 1 : token connu, OU profil habilite sans token ────────────
        //
        // DEUX POPULATIONS, DEUX PREUVES D'ACCES. Le portail Campagnes presente
        // un token : c'est lui qui delimite le perimetre. Certains profils
        // INTERNES ouvrent le meme ecran depuis Lightning, sans token — leur
        // droit vient d'un rattachement nominatif sur l'enregistrement
        // (« LOOKUP- Telepro »), exactement comme dans le reporting.
        //
        // L'ordre compte : le token d'abord. Un utilisateur qui en presente un
        // valide reste juge sur ce perimetre, meme si son profil figure aussi
        // ci-dessous.
        Set<Id> campaignIds = perimetreCampagnes(campaignCode);
        String profilInterne = (campaignIds == null) ? profilSansToken() : null;
        if (campaignIds == null && profilInterne == null) {
            refuserSansAcces(campaignCode);
        }

        // ── Verrou 2 : Id valide, d'un type supporté ─────────────────────────
        Id idRecord;
        try {
            idRecord = (Id) recordId;
        } catch (Exception e) {
            throw erreur('Identifiant d\'enregistrement invalide.');
        }
        String typeRecord = String.valueOf(idRecord.getSObjectType());

        ConfigObjet cfg;
        if (typeRecord == 'Lead')        cfg = CONFIG_LEAD;
        else if (typeRecord == 'Pro__c') cfg = CONFIG_PRO;
        else throw erreur('Ce type d\'enregistrement ne gère pas de devis.');

        // ── Verrou 3 : le record est bien dans le perimetre autorise ────────
        Boolean dansPerimetre;
        if (profilInterne != null) {
            dansPerimetre = !rattachesSansToken(new Set<Id>{ idRecord }).isEmpty();
        } else if (cfg === CONFIG_LEAD) {
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

        return cfg;
    }

    /* ════════════════════════════════════════════════════════════════════════
       ACCES SANS TOKEN — utilisateurs Salesforce connectes

       Le token de campagne (localStorage) n'authentifie que les visiteurs
       INVITES du portail Campagnes. Un utilisateur connecte — confirmateur,
       telepro, responsable telepro, apporteur d'affaires — ouvre le meme ecran
       depuis son reporting SANS token : c'est son PROFIL qui fixe son perimetre,
       exactement comme dans LC020_GestionReporting.getReportingData. Les regles
       ci-dessous doivent rester alignees sur celles du reporting.

         • Rattachement NOMINATIF (tables RATTACHEMENT_*) : l'enregistrement
           porte l'utilisateur courant dans un champ lookup.
         • Responsable Telepro : Pistes AA- de la fiche RES060 (aucun lookup
           ne le designe ; meme critere que son reporting, sans les statuts,
           qui changent pendant la signature).
         • Apporteurs d'affaires : les campagnes dont ils sont PROPRIETAIRES,
           puis la meme regle que le token (voir perimetreCampagnes).

       Un profil absent d'ici n'a aucun acces sans token. Ajouter un profil
       demande de nommer ce qui le rattache a l'enregistrement — jamais de se
       contenter du nom du profil, qui ne prouve rien sur l'enregistrement vise.

       Les methodes publiques de cette section sont reutilisees par
       LC026_Documents (modale Documents, ouverte depuis le meme reporting).
       ════════════════════════════════════════════════════════════════════════ */

    /** Profil -> champ de rattachement sur la Piste. */
    private static final Map<String, String> RATTACHEMENT_LEAD = new Map<String, String>{
        Constants.PROFIL_PI_TELEPRO_LEADS => 'ConfirmateurLookup__c',
        Constants.PROFIL_PI_CONFIRMATEUR  => 'Utilisateur__c'
    };

    /** Profil -> champ de rattachement sur le Dossier. */
    private static final Map<String, String> RATTACHEMENT_PRO = new Map<String, String>{
        Constants.PROFIL_PI_TELEPRO_LEADS => 'LOOKUP_Telepro__c',
        Constants.PROFIL_PI_CONFIRMATEUR  => 'Confirmateurs__c'
    };

    /** Profils dont le perimetre est celui des campagnes qu'ils possedent. */
    private static final Set<String> PROFILS_APPORTEUR = new Set<String>{
        Constants.PROFIL_PI_APP_AFF,
        Constants.PROFIL_PI_APP_AFF_INTERNE
    };

    /**
     * Nom du profil de l'utilisateur courant, null pour un invite.
     *
     * Un seul appel par transaction : le resultat est memorise. La modale
     * enchaine plusieurs methodes qui verifient toutes l'acces, et une requete
     * User par verrou serait du gaspillage pur.
     */
    private static String profilCache;
    private static Boolean profilLu = false;
    /** Les tests ne peuvent pas creer d'utilisateur de portail : ils forcent le profil. */
    @TestVisible private static String profilForce;

    private static String profilCourant() {
        if (Test.isRunningTest() && profilForce != null) return profilForce;
        if (profilLu) return profilCache;
        profilLu = true;
        profilCache = null;
        if (estInvite()) return null;
        try {
            profilCache = [
                SELECT Profile.Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1
            ].Profile.Name;
        } catch (Exception e) {
            // Profil illisible : aucune voie sans token.
            System.debug(LoggingLevel.WARN, 'Profil illisible : ' + e.getMessage());
        }
        return profilCache;
    }

    private static Boolean estInvite() {
        return UserInfo.getUserType() == 'Guest';
    }

    /** Nom du profil courant s'il a un perimetre PAR ENREGISTREMENT, null sinon. */
    private static String profilSansToken() {
        String nom = profilCourant();
        if (nom == null) return null;
        if (RATTACHEMENT_LEAD.containsKey(nom) || RATTACHEMENT_PRO.containsKey(nom)
                || nom == Constants.PROFIL_PI_RESPONSABLE_TELEPRO) {
            return nom;
        }
        return null;
    }

    /** Vrai si le profil courant a un perimetre par enregistrement (rattachesSansToken). */
    public static Boolean aUnPerimetreSansToken() {
        return profilSansToken() != null;
    }

    /**
     * Parmi ces Pistes et Dossiers, ceux qui entrent dans le perimetre du profil
     * courant (voir l'en-tete de section). Ensemble vide si le profil n'a pas de
     * perimetre par enregistrement. Les Ids d'un autre type sont ignores.
     *
     * Le nom du champ vient des tables ci-dessus, jamais du navigateur : la
     * requete dynamique ne peut donc porter que sur un champ choisi ici.
     */
    public static Set<Id> rattachesSansToken(Set<Id> ids) {
        Set<Id> retenus = new Set<Id>();
        String profil = profilSansToken();
        if (profil == null || ids == null || ids.isEmpty()) return retenus;

        Set<Id> idsLead = new Set<Id>();
        Set<Id> idsPro  = new Set<Id>();
        for (Id i : ids) {
            if (i == null) continue;
            String type = String.valueOf(i.getSObjectType());
            if (type == 'Lead')        idsLead.add(i);
            else if (type == 'Pro__c') idsPro.add(i);
        }
        Id moi = UserInfo.getUserId();

        if (!idsLead.isEmpty()) {
            if (profil == Constants.PROFIL_PI_RESPONSABLE_TELEPRO) {
                String fiche060 = Constants.FICHE_PISTE_060;
                for (Lead l : [
                    SELECT Id FROM Lead
                    WHERE Id IN :idsLead
                      AND TypeDeDossier__c INCLUDES (:fiche060)
                      AND RecordType.Name LIKE 'AA-%'
                ]) {
                    retenus.add(l.Id);
                }
            } else if (RATTACHEMENT_LEAD.containsKey(profil)) {
                String soql = 'SELECT Id FROM Lead WHERE Id IN :idsLead AND '
                            + RATTACHEMENT_LEAD.get(profil) + ' = :moi';
                for (SObject s : Database.query(soql)) retenus.add(s.Id);
            }
        }
        // Le profil peut etre habilite sur un objet et pas sur l'autre.
        if (!idsPro.isEmpty() && RATTACHEMENT_PRO.containsKey(profil)) {
            String soql = 'SELECT Id FROM Pro__c WHERE Id IN :idsPro AND '
                        + RATTACHEMENT_PRO.get(profil) + ' = :moi';
            for (SObject s : Database.query(soql)) retenus.add(s.Id);
        }
        return retenus;
    }

    /**
     * Campagnes du perimetre : celles du token s'il est connu ; a defaut de
     * token, celles que possede un apporteur d'affaires connecte (ensemble
     * eventuellement vide). Null si aucune de ces deux voies ne s'applique.
     *
     * Ne leve PAS : l'appelant decide s'il existe une autre voie d'acces avant
     * de refuser (refuserSansAcces).
     */
    public static Set<Id> perimetreCampagnes(String campaignCode) {
        Set<Id> duToken = perimetreDuToken(campaignCode);
        if (duToken != null) return duToken;
        if (String.isNotBlank(campaignCode)) return null;
        if (!PROFILS_APPORTEUR.contains(profilCourant())) return null;

        Set<Id> campaignIds = new Set<Id>();
        for (Campaign c : [
            SELECT Id, (SELECT Id FROM ChildCampaigns)
            FROM Campaign
            WHERE OwnerId = :UserInfo.getUserId()
        ]) {
            campaignIds.add(c.Id);
            for (Campaign enfant : c.ChildCampaigns) {
                campaignIds.add(enfant.Id);
            }
        }
        return campaignIds;
    }

    /**
     * Leve l'exception adaptee quand aucune voie d'acces n'a abouti. Un
     * utilisateur connecte n'a pas de token a fournir : lui parler de token
     * serait faux, on lui dit que son profil n'est pas habilite.
     */
    public static void refuserSansAcces(String campaignCode) {
        if (String.isBlank(campaignCode) && !estInvite()) {
            throw erreur('Votre profil n\'a pas accès à cet écran.');
        }
        verifierToken(campaignCode);
        // Token connu mais aucune voie retenue : ne devrait pas arriver.
        throw erreur('Accès refusé.');
    }

    /** Perimetre du token, ou null si le token est absent ou inconnu. */
    private static Set<Id> perimetreDuToken(String campaignCode) {
        if (String.isBlank(campaignCode)) return null;
        List<Campaign> campagnes = [
            SELECT Id, (SELECT Id FROM ChildCampaigns)
            FROM Campaign
            WHERE CampaignToken__c = :campaignCode
            LIMIT 1
        ];
        if (campagnes.isEmpty()) return null;

        Set<Id> campaignIds = new Set<Id>{ campagnes[0].Id };
        for (Campaign enfant : campagnes[0].ChildCampaigns) {
            campaignIds.add(enfant.Id);
        }
        return campaignIds;
    }

    /**
     * Verrou 1 seul, pour les methodes SANS enregistrement (le gabarit vierge) :
     * un token valide, ou un profil habilite.
     */
    private static void verifierAccesPortail(String campaignCode) {
        if (perimetreCampagnes(campaignCode) != null) return;
        if (profilSansToken() != null) return;
        refuserSansAcces(campaignCode);
    }

    /**
     * Verrou 1 seul : le token doit désigner une campagne existante.
     * Renvoie la campagne et ses filles — le périmètre du token.
     */
    private static Set<Id> verifierToken(String campaignCode) {
        if (String.isBlank(campaignCode)) {
            throw erreur('Token de campagne non fourni.');
        }
        List<Campaign> campagnes = [
            SELECT Id, (SELECT Id FROM ChildCampaigns)
            FROM Campaign
            WHERE CampaignToken__c = :campaignCode
            LIMIT 1
        ];
        if (campagnes.isEmpty()) {
            throw erreur('Token de campagne invalide.');
        }
        Set<Id> campaignIds = new Set<Id>{ campagnes[0].Id };
        for (Campaign enfant : campagnes[0].ChildCampaigns) {
            campaignIds.add(enfant.Id);
        }
        return campaignIds;
    }

    /**
     * Verrou 4 : intersection de la demande du LWC avec la liste blanche.
     * Les champs techniques indispensables (Id, statut, surface) sont toujours
     * réintégrés en lecture — le récapitulatif peut les omettre, pas le workflow.
     */
    private static Set<String> champsAutorises(ConfigObjet cfg, List<String> demandes, Boolean pourEcriture) {
        Set<String> blanche = pourEcriture ? cfg.champsModifiables : cfg.champsLisibles;

        if (pourEcriture) {
            return blanche.clone();
        }

        Set<String> retenus = new Set<String>{ 'Id', cfg.champStatut, cfg.champSurface, cfg.champTitre };
        if (demandes == null || demandes.isEmpty()) {
            retenus.addAll(blanche);
            return retenus;
        }
        for (String d : demandes) {
            if (String.isBlank(d)) continue;
            String api = d.trim();
            for (String autorise : blanche) {
                if (autorise.equalsIgnoreCase(api)) {
                    retenus.add(autorise);
                    break;
                }
            }
        }
        return retenus;
    }

    /* ════════════════════════════════════════════════════════════════════════
       LECTURE
       ════════════════════════════════════════════════════════════════════════ */

    /**
     * Une seule SOQL, construite exclusivement à partir de noms de champs issus
     * de la liste blanche : aucune chaîne venue du navigateur n'entre dans la
     * requête, l'injection SOQL est structurellement impossible.
     */
    private static DevisData lire(Id recordId, ConfigObjet cfg, Set<String> champs) {

        Map<String, Schema.SObjectField> champsSf = Schema.getGlobalDescribe()
            .get(cfg.sobjectType).getDescribe().fields.getMap();

        List<String> selection = new List<String>();
        for (String api : champs) {
            if (champsSf.containsKey(api.toLowerCase())) selection.add(api);
        }

        String soql = 'SELECT ' + String.join(selection, ', ')
                    + ' FROM ' + cfg.sobjectType
                    + ' WHERE Id = :recordId LIMIT 1';
        List<SObject> lignes = Database.query(soql);
        if (lignes.isEmpty()) {
            throw erreur('Enregistrement introuvable.');
        }
        SObject record = lignes[0];

        DevisData data = new DevisData();
        data.recordId     = recordId;
        data.objectType   = cfg.sobjectType;
        data.typeLibelle  = (cfg === CONFIG_LEAD) ? 'Piste' : 'Dossier';
        data.titre        = String.valueOf(record.get(cfg.champTitre));
        data.statutValeur = (String) record.get(cfg.champStatut);
        data.statutCode   = codeStatut(data.statutValeur);
        data.champSurface = cfg.champSurface;
        data.surface      = (Decimal) record.get(cfg.champSurface);
        data.champs       = new List<ChampDevis>();

        for (String api : selection) {
            if (api == 'Id') continue;
            Schema.DescribeFieldResult d = champsSf.get(api.toLowerCase()).getDescribe();
            ChampDevis c = new ChampDevis();
            c.apiName    = d.getName();
            c.label      = d.getLabel();
            c.type       = String.valueOf(d.getType());
            c.valeur     = enTexte(record.get(api));
            // isUpdateable() n'est VOLONTAIREMENT pas utilisé : il dépend des
            // droits de l'utilisateur COURANT, or le portail tourne sous le Guest
            // User du site, à qui Salesforce interdit l'autorisation « Modifier »
            // sur Lead (constaté : ObjectPermissions edit = false, et cette
            // autorisation n'est pas accordable à un invité depuis Winter '21).
            // Tous les champs seraient alors rendus en lecture seule et l'écran
            // de modification n'existerait plus.
            //
            // Ce n'est pas un relâchement : le droit d'écrire ne vient pas du
            // profil mais du TOKEN de campagne (voir l'en-tête de la classe), et
            // c'est la liste blanche champsModifiables qui décide seule de ce qui
            // est écrivable. Restent écartés ici les champs non écrivables PAR
            // NATURE — formule, auto-numéro — un contrôle qui, lui, ne dépend
            // d'aucun utilisateur et protège d'un ajout hâtif à la liste blanche.
            c.modifiable = cfg.champsModifiables.contains(d.getName())
                && !d.isCalculated()
                && !d.isAutoNumber();
            data.champs.add(c);
        }
        return data;
    }

    /* ════════════════════════════════════════════════════════════════════════
       CONVERSIONS
       ════════════════════════════════════════════════════════════════════════ */

    /** Valeur SObject -> texte, sans dépendre du fuseau de l'utilisateur. */
    private static String enTexte(Object valeur) {
        if (valeur == null) return null;
        if (valeur instanceof Date)     return String.valueOf((Date) valeur);      // yyyy-MM-dd
        if (valeur instanceof Datetime) return ((Datetime) valeur).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
        return String.valueOf(valeur);
    }

    /** Texte saisi -> valeur typée attendue par le champ. Vide => null. */
    private static Object convertir(String saisie, Schema.DisplayType type) {
        if (String.isBlank(saisie)) return null;
        String s = saisie.trim();
        if (type == Schema.DisplayType.DOUBLE
         || type == Schema.DisplayType.CURRENCY
         || type == Schema.DisplayType.PERCENT) {
            return Decimal.valueOf(s.replace(',', '.'));
        }
        if (type == Schema.DisplayType.INTEGER) {
            return Integer.valueOf(s);
        }
        if (type == Schema.DisplayType.BOOLEAN) {
            return Boolean.valueOf(s);
        }
        if (type == Schema.DisplayType.DATE) {
            return Date.valueOf(s);
        }
        if (type == Schema.DisplayType.DATETIME) {
            return Datetime.valueOfGmt(s.replace('T', ' ').replace('Z', ''));
        }
        return s;
    }

    /** Message d'erreur lisible côté portail (getMessage() renseigné). */
    private static AuraHandledException erreur(String message) {
        AuraHandledException e = new AuraHandledException(message);
        e.setMessage(message);
        return e;
    }
}