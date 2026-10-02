/**
 * LC027_Certiko — échanges avec l'API publique Certiko (dossiers RES060).
 *
 * DEUX APPELS, et deux seulement :
 *   • creerDossier  : POST /dossiers — le pré-visiteur démarre sa visite ;
 *   • lireDossier   : GET  /dossiers/{id} — relecture du statut.
 *
 * CE QUI EST ENVOYÉ SE RÈGLE SANS CODE — le corps est construit à partir du
 * type de métadonnée « Certiko - Champ envoyé » (Certiko_Champ__mdt) : une ligne
 * = une colonne Certiko alimentée par un champ du Dossier. Ajouter un champ,
 * c'est ajouter un enregistrement ; le retirer, c'est décocher « Actif ».
 *
 * Le champ peut être porté par un PARENT : « Champ Dossier (API) » accepte un
 * chemin de relation, comme en SOQL. C'est ainsi que l'équipe du pré-visiteur
 * part dans `_equipe_poseur` :
 *   LOOKUP_Pre_visiteur__r.Acces_REGIE__r.CERTIKO_Equipe_Id__c
 * Un maillon vide (dossier non attribué, pré-visiteur sans compte Certiko)
 * n'envoie rien plutôt qu'une colonne vide.
 *
 * RECRÉER UN DOSSIER CHEZ EUX — Certiko refuse deux créations sous la même
 * Idempotency-Key, et c'est voulu : c'est ce qui évite un doublon quand le
 * réseau coupe. Pour un dossier volontairement neuf (faute de saisie,
 * annulation, replanification), incrémenter Pro__c.CERTIKO_Numero_Envoi__c :
 * il entre dans la clé. Voir cleIdempotence().
 *
 * RÉGLAGES (Custom Labels) : CERTIKO_BASE_URL, CERTIKO_API_KEY, CERTIKO_BOARD,
 * CERTIKO_STATUT_CREATION, CERTIKO_URL_TERRAIN. La clé ne quitte JAMAIS le
 * serveur : le composant ne voit que le résultat.
 *
 * ⚠️ DÉBIT TRÈS LIMITÉ — l'API renvoie l'en-tête « x-ratelimit-limit: 1 » :
 * deux appels rapprochés donnent un 429. D'où le code d'erreur dédié
 * LIMITE_DEBIT, que le portail traduit en « réessayez dans un instant ».
 *
 * ⚠️ LE STATUT DU TABLEAU N'EST PAS LE STATUT DU DOSSIER — relevé le
 * 2026-09-23 sur GET /boards/gestion-install-res060/columns :
 *   • `status` du corps de création vise le statut de l'ESPACE (« Nouveaux
 *     Clients »), celui que rend `status.name` ;
 *   • `statut_res060` est une COLONNE du tableau (workflow_column), et se
 *     remplit donc par `values`, comme n'importe quelle autre colonne.
 * Envoyer l'un ne remplit pas l'autre : c'est ce qui laissait la colonne
 * « Statut RES060 » vide sur les dossiers créés par le portail.
 *
 * ⚠️ COLONNES SYSTÈME — `_poseur`, `_equipe_poseur` et `_date_previsite` ne
 * sont PAS listées par GET /columns, mais elles sont bien acceptées en
 * écriture : vérifié par création réelle, toutes ressortent du GET du dossier.
 * `_poseur` et `_equipe_poseur` acceptent le NOM (« ECONATURA », « Equipo
 * Untel ») et Certiko le résout lui-même en identifiant interne — vérifié le
 * 2026-09-25 : la réponse rend l'UUID de l'équipe pour un nom envoyé.
 *
 * `status_vt` est en revanche devenue une colonne EXPOSÉE (liste de sélection :
 * planifie / en_cours / terminee / annule_par_le_visiteur). Notre champ
 * Pro__c.CERTIKO_Statut_VT__c est donc lui aussi une liste de sélection, et
 * c'est LUI qui fait foi : une valeur que Certiko ouvrirait de son côté sans
 * qu'on l'ajoute ici n'est pas enregistrée, plutôt que de laisser un dossier
 * dans un état que nos règles ignorent.
 *
 * `annule_par_le_visiteur` est le seul statut que NOUS posons : il part quand
 * le pré-visiteur replanifie une visite déjà envoyée, en même temps que la
 * libération de `_equipe_poseur` (voir majColonnes).
 */
public without sharing class LC027_Certiko {

    public class CertikoException extends Exception {}

    /** Réponse utile d'un dossier Certiko. */
    public class Resultat {
        public String id;
        public String reference;
        /** Statut de la visite technique (values.status_vt), si Certiko l'expose. */
        public String statutVt;
        /** Statut de workflow (« Statut RES060 »), toujours présent. */
        public String statutDossier;
    }

    private static final Integer DELAI_MS = 60000;

    /* ════════════════════════════════════════════════════════════════════════
       APPELS
       ════════════════════════════════════════════════════════════════════════ */

    /**
     * Crée le dossier chez Certiko à partir du Dossier Salesforce.
     *
     * Idempotency-Key : voir cleIdempotence() — elle protège des doublons
     * accidentels, et le numéro d'envoi permet d'en sortir volontairement.
     */
    public static Resultat creerDossier(Id dossierId) {
        Pro__c d = lireDossierSalesforce(dossierId);
        Map<String, Object> envoyees = valeurs(d);
        Map<String, Object> corps = new Map<String, Object>{
            'board'  => reglage('CERTIKO_BOARD'),
            'status' => reglage('CERTIKO_STATUT_CREATION'),
            'client_name' => nomClient(d),
            'values' => envoyees
        };
        HttpRequest req = requete('POST', '/dossiers');
        req.setHeader('Idempotency-Key', cleIdempotence(d));
        req.setBody(JSON.serialize(corps, true));

        Map<String, Object> reponse = appeler(req);
        Resultat r = versResultat(reponse);

        // CE QUE NOUS AVONS ENVOYÉ FAIT FOI quand la réponse ne le renvoie
        // pas. La création rend « id », « reference » et « status », mais PAS
        // le détail des colonnes — seul le GET du dossier le fait. Sans ce
        // repli, le portail affichait « Sans statut » juste après l'envoi,
        // alors que la visite était bien « Planifiée » chez eux : le statut
        // n'apparaissait qu'au premier retour de leur webhook.
        //
        // On ne se fie pas aveuglément pour autant : si Certiko a REFUSÉ la
        // colonne, la valeur envoyée n'est pas celle du dossier.
        String colonneStatut = System.Label.CERTIKO_COLONNE_STATUT_VT;
        if (String.isBlank(r.statutVt) && !colonneRefusee(reponse, colonneStatut)) {
            r.statutVt = texteDe(envoyees.get(colonneStatut));
        }
        return r;
    }

    /** Cette colonne figure-t-elle parmi les refus de la réponse ? */
    private static Boolean colonneRefusee(Map<String, Object> corps, String colonne) {
        Object soucis = corps == null ? null : corps.get('errors');
        if (!(soucis instanceof List<Object>)) {
            return false;
        }
        for (Object o : (List<Object>) soucis) {
            if (o instanceof Map<String, Object>
                    && colonne == texteDe(((Map<String, Object>) o).get('slug'))) {
                return true;
            }
        }
        return false;
    }

    /**
     * « Id Salesforce - numéro d'envoi », par exemple « a09AW00000b0QlBYAU-1 ».
     *
     * CE QU'ELLE PROTÈGE — si la réponse se perd (réseau coupé après l'écriture
     * côté Certiko), un nouvel essai ne crée pas de second dossier : Certiko
     * reconnaît la clé et rend le dossier déjà créé.
     *
     * CE QU'ELLE BLOQUERAIT SANS LE NUMÉRO — la recréation VOLONTAIRE. Une
     * faute de saisie, un pré-visiteur qui annule, une replanification : il
     * faut parfois un dossier neuf chez eux. L'Id Salesforce seul ne changeant
     * jamais, Certiko refuserait à vie. Le numéro d'envoi est la sortie de
     * secours : l'incrémenter donne une clé neuve, sans toucher au code.
     *
     * Vide vaut 1 : les Dossiers créés avant ce champ n'en portent pas.
     */
    @TestVisible
    private static String cleIdempotence(Pro__c d) {
        Decimal numero = d.CERTIKO_Numero_Envoi__c;
        // Un zéro ou un négatif saisi à la main ne doit pas produire une clé
        // bizarre : on retombe sur le premier envoi.
        Integer n = (numero == null || numero < 1) ? 1 : numero.intValue();
        return String.valueOf(d.Id) + '-' + n;
    }

    /** Relit un dossier (id ou référence) pour connaître son statut. */
    public static Resultat lireDossier(String idOuReference) {
        if (String.isBlank(idOuReference)) {
            throw new CertikoException('CERTIKO_SANS_DOSSIER');
        }
        return versResultat(appeler(requete('GET', '/dossiers/' + EncodingUtil.urlEncode(idOuReference, 'UTF-8'))));
    }

    /** Lien du relevé terrain à ouvrir par le pré-visiteur. */
    public static String lienTerrain(String certikoId) {
        return String.isBlank(certikoId) ? null : reglage('CERTIKO_URL_TERRAIN') + certikoId;
    }

    /**
     * Vide une colonne d'un dossier chez Certiko.
     *
     * Sert à libérer l'équipe de pose quand la visite technique se termine :
     * le créneau reste sinon réservé à une intervention déjà faite. Certiko
     * accepte la chaîne vide comme « efface ».
     *
     * L'appel doit partir HORS d'une transaction ayant déjà écrit : Salesforce
     * refuse un appel sortant après un DML. C'est la file d'attente de
     * LC027_CertikoRetour qui s'en charge.
     */
    public static void viderColonne(String idOuReference, String colonne) {
        if (String.isBlank(colonne)) {
            throw new CertikoException('CERTIKO_SANS_DOSSIER');
        }
        majColonnes(idOuReference, new Map<String, Object>{ colonne => '' });
    }

    /**
     * Écrit plusieurs colonnes d'un dossier EN UN SEUL appel.
     *
     * Un seul appel, et pas un par colonne : l'API plafonne à une requête par
     * seconde (« x-ratelimit-limit: 1 »), deux PATCH rapprochés donnent un 429.
     * C'est ce qui permet d'annuler la visite et de libérer l'équipe d'un coup
     * quand le pré-visiteur replanifie.
     *
     * Même contrainte que viderColonne : l'appel doit partir HORS d'une
     * transaction ayant déjà écrit.
     */
    public static void majColonnes(String idOuReference, Map<String, Object> valeurs) {
        if (String.isBlank(idOuReference) || valeurs == null || valeurs.isEmpty()) {
            throw new CertikoException('CERTIKO_SANS_DOSSIER');
        }
        HttpRequest req = requete('PATCH',
            '/dossiers/' + EncodingUtil.urlEncode(idOuReference, 'UTF-8') + '/columns');
        req.setBody(JSON.serialize(new Map<String, Object>{ 'values' => valeurs }));
        appeler(req);
    }

    /* ════════════════════════════════════════════════════════════════════════
       CORPS DE LA REQUÊTE — piloté par Certiko_Champ__mdt
       ════════════════════════════════════════════════════════════════════════ */

    /** Lignes ACTIVES de la table de correspondance, dans l'ordre déclaré. */
    public static List<Certiko_Champ__mdt> correspondances() {
        return [
            SELECT Colonne_Certiko__c, Champ_Dossier__c, Valeur_Fixe__c, Type_Valeur__c, Ordre__c
            FROM Certiko_Champ__mdt
            WHERE Actif__c = true
            ORDER BY Ordre__c NULLS LAST, Colonne_Certiko__c
        ];
    }

    /**
     * Dossier relu avec EXACTEMENT les champs de la table de correspondance.
     * Un champ inconnu (table mal saisie) est ignoré : une faute de frappe ne
     * doit pas empêcher tout envoi.
     */
    private static Pro__c lireDossierSalesforce(Id dossierId) {
        // Le numéro d'envoi n'entre dans AUCUNE colonne Certiko : il sert à
        // construire la clé d'idempotence. Il est donc lu ici, et pas déclaré
        // dans la table de correspondance.
        Set<String> champs = new Set<String>{
            'Id', 'Name', 'PRO_Nom_Client__c', 'CERTIKO_Numero_Envoi__c' };
        for (Certiko_Champ__mdt c : correspondances()) {
            // Une valeur fixe ne lit rien sur le Dossier : inutile de l'interroger.
            if (String.isNotBlank(c.Valeur_Fixe__c)) {
                continue;
            }
            String chemin = chemin(c);
            if (cheminValide(chemin)) {
                champs.add(chemin);
            }
        }
        String soql = 'SELECT ' + String.join(new List<String>(champs), ', ')
            + ' FROM Pro__c WHERE Id = :dossierId LIMIT 1';
        return Database.query(soql);
    }

    /** Chemin déclaré dans la table, sans les espaces de saisie. */
    private static String chemin(Certiko_Champ__mdt c) {
        return c.Champ_Dossier__c == null ? '' : c.Champ_Dossier__c.trim();
    }

    /**
     * Le chemin existe-t-il vraiment sur le Dossier ?
     *
     * Vérifié maillon par maillon dans le schéma, pour que la ligne fautive
     * soit la seule écartée. Sans ce contrôle, une faute de frappe dans la
     * table ferait échouer la requête, donc TOUT l'envoi.
     *
     * @TestVisible : une ligne fautive ne peut pas être insérée en test (le DML
     * sur du Custom Metadata est asynchrone), le garde-fou se vérifie donc ici.
     */
    @TestVisible
    private static Boolean cheminValide(String chemin) {
        if (String.isBlank(chemin)) {
            return false;
        }
        List<String> morceaux = chemin.split('\\.');
        Schema.SObjectType type = Pro__c.SObjectType;
        for (Integer i = 0; i < morceaux.size() - 1; i++) {
            Schema.SObjectField lien = relation(type, morceaux[i]);
            if (lien == null) {
                return false;
            }
            List<Schema.SObjectType> cibles = lien.getDescribe().getReferenceTo();
            if (cibles.isEmpty()) {
                return false;
            }
            // Une relation polymorphe (Owner, What) n'a pas sa place ici : on
            // suit la première cible, qui est la seule pour un lookup normal.
            type = cibles[0];
        }
        return type.getDescribe().fields.getMap()
            .containsKey(morceaux[morceaux.size() - 1].toLowerCase());
    }

    /**
     * Champ de recherche derrière un nom de relation.
     *
     * Convention Salesforce : « Compte__r » est porté par « Compte__c », et
     * « Account » par « AccountId ». La déduire coûte deux recherches dans une
     * map, là où balayer les 400 champs du Dossier coûterait 400 describes.
     */
    private static Schema.SObjectField relation(Schema.SObjectType type, String nom) {
        Map<String, Schema.SObjectField> champs = type.getDescribe().fields.getMap();
        return nom.endsWithIgnoreCase('__r')
            ? champs.get(nom.removeEndIgnoreCase('__r').toLowerCase() + '__c')
            : champs.get(nom.toLowerCase() + 'id');
    }

    /**
     * Valeur au bout du chemin, ou null si un parent manque à l'appel.
     *
     * Un dossier sans pré-visiteur n'a pas d'équipe : mieux vaut ne rien
     * envoyer qu'une colonne vide.
     */
    private static Object valeurDe(SObject enr, String chemin) {
        List<String> morceaux = chemin.split('\\.');
        SObject courant = enr;
        for (Integer i = 0; i < morceaux.size() - 1 && courant != null; i++) {
            courant = courant.getSObject(morceaux[i]);
        }
        return courant == null ? null : courant.get(morceaux[morceaux.size() - 1]);
    }

    /**
     * Valeurs envoyées, par slug de colonne Certiko. Les valeurs vides sont omises.
     *
     * DEUX SOURCES : une « Valeur fixe » part telle quelle (statut du tableau,
     * poseur — identique pour tous les dossiers) ; sinon c'est un champ du
     * Dossier, ou d'un de ses parents, qui alimente la colonne. La valeur fixe
     * l'emporte, et se règle sans code, comme le reste de la table.
     */
    private static Map<String, Object> valeurs(Pro__c d) {
        Map<String, Object> sortie = new Map<String, Object>();
        for (Certiko_Champ__mdt c : correspondances()) {
            String colonne = c.Colonne_Certiko__c == null ? '' : c.Colonne_Certiko__c.trim();
            if (String.isBlank(colonne)) {
                continue;
            }
            Object brut;
            if (String.isNotBlank(c.Valeur_Fixe__c)) {
                brut = c.Valeur_Fixe__c.trim();
            } else {
                String chemin = chemin(c);
                if (!cheminValide(chemin)) {
                    continue;
                }
                brut = valeurDe(d, chemin);
            }
            Object valeur = convertir(brut, c.Type_Valeur__c);
            if (valeur != null) {
                sortie.put(colonne, valeur);
            }
        }
        return sortie;
    }

    /** Met la valeur Salesforce à la forme attendue par la colonne Certiko. */
    private static Object convertir(Object brut, String type) {
        if (type == 'booleen') {
            // Une case décochée est une information : elle part telle quelle.
            return brut == null ? false : brut;
        }
        if (brut == null) {
            return null;
        }
        if (type == 'nombre') {
            return brut;
        }
        if (type == 'date') {
            if (brut instanceof Date) {
                Date j = (Date) brut;
                return Datetime.newInstanceGmt(j, Time.newInstance(0, 0, 0, 0)).format('yyyy-MM-dd');
            }
            if (brut instanceof Datetime) {
                return ((Datetime) brut).formatGmt('yyyy-MM-dd');
            }
            return String.valueOf(brut);
        }
        if (type == 'date_heure') {
            // « 2026-09-22T13:28:00 » : Certiko attend l'heure LOCALE du
            // rendez-vous, sans fuseau. format() (et non formatGmt) applique
            // donc le fuseau de l'utilisateur du site — celui de l'invité du
            // portail, à garder sur l'Espagne.
            if (brut instanceof Datetime) {
                return ((Datetime) brut).format('yyyy-MM-dd\'T\'HH:mm:ss');
            }
            if (brut instanceof Date) {
                return ((Date) brut).year() + '-'
                    + String.valueOf(((Date) brut).month()).leftPad(2, '0') + '-'
                    + String.valueOf(((Date) brut).day()).leftPad(2, '0') + 'T00:00:00';
            }
            return String.valueOf(brut);
        }
        String texte = String.valueOf(brut).trim();
        if (String.isBlank(texte)) {
            return null;
        }
        if (type == 'adresse') {
            // Colonne de type « location » : Certiko attend un objet.
            return new Map<String, Object>{ 'address' => texte };
        }
        return texte;
    }

    /** Nom du client, sans le tiret final des noms importés (« ROCHER- »). */
    private static String nomClient(Pro__c d) {
        String nom = d.Name == null ? '' : d.Name.trim();
        return nom.removeEnd('-').trim();
    }

    /* ════════════════════════════════════════════════════════════════════════
       HTTP
       ════════════════════════════════════════════════════════════════════════ */

    private static HttpRequest requete(String methode, String chemin) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(reglage('CERTIKO_BASE_URL') + chemin);
        req.setMethod(methode);
        req.setTimeout(DELAI_MS);
        req.setHeader('X-API-Key', reglage('CERTIKO_API_KEY'));
        req.setHeader('Accept', 'application/json');
        if (methode != 'GET') {
            req.setHeader('Content-Type', 'application/json');
        }
        return req;
    }

    /**
     * Exécute l'appel et rend le corps désérialisé.
     *
     * Les erreurs sont traduites en CODES, jamais en texte brut de l'API : le
     * portail les affiche au pré-visiteur, dans sa langue.
     */
    private static Map<String, Object> appeler(HttpRequest req) {
        HttpResponse rep;
        try {
            rep = new Http().send(req);
        } catch (Exception e) {
            throw new CertikoException('CERTIKO_INJOIGNABLE');
        }
        Integer code = rep.getStatusCode();
        if (code == 429) {
            throw new CertikoException('CERTIKO_LIMITE_DEBIT');
        }
        Map<String, Object> corps;
        try {
            corps = (Map<String, Object>) JSON.deserializeUntyped(rep.getBody());
        } catch (Exception e) {
            corps = null;
        }
        if (code >= 200 && code < 300) {
            if (corps == null) {
                throw new CertikoException('CERTIKO_REPONSE_ILLISIBLE');
            }
            signalerColonnesRefusees(corps);
            return corps;
        }
        if (code == 401 || code == 403) {
            throw new CertikoException('CERTIKO_CLE_REFUSEE');
        }
        if (code == 404) {
            throw new CertikoException('CERTIKO_DOSSIER_INTROUVABLE');
        }
        // 422 (champ obligatoire manquant) et tout le reste : le détail de
        // Certiko est utile au pré-visiteur pour corriger sa fiche.
        throw new CertikoException('CERTIKO_REFUS:' + detail(corps, rep.getBody()));
    }

    /**
     * 200 NE VEUT PAS DIRE « TOUT EST PASSÉ ».
     *
     * Relevé le 2026-09-25 : un nom d'équipe que Certiko ne connaît pas rend un
     * 200 avec « updated: [] » et le détail dans « errors ». La colonne garde
     * son ancienne valeur, et rien ne le signale.
     *
     * On ne refuse pas l'appel pour autant — la visite doit pouvoir démarrer
     * même si l'équipe ne suit pas. Mais on laisse une trace : sans elle, une
     * équipe renommée chez Certiko se diagnostiquerait à l'aveugle.
     */
    private static void signalerColonnesRefusees(Map<String, Object> corps) {
        Object soucis = corps.get('errors');
        if (soucis instanceof List<Object> && !((List<Object>) soucis).isEmpty()) {
            System.debug(LoggingLevel.WARN,
                'Certiko a refuse une colonne : ' + JSON.serialize(soucis));
        }
    }

    /** Message lisible extrait de la réponse d'erreur, quelle que soit sa forme. */
    private static String detail(Map<String, Object> corps, String brut) {
        if (corps != null) {
            Object err = corps.get('error');
            if (err instanceof Map<String, Object>) {
                Object m = ((Map<String, Object>) err).get('message');
                if (m != null) return String.valueOf(m);
            }
            Object d = corps.get('detail');
            if (d != null) return JSON.serialize(d).abbreviate(200);
        }
        return brut == null ? '' : brut.abbreviate(200);
    }

    private static Resultat versResultat(Map<String, Object> corps) {
        Resultat r = new Resultat();
        r.id = texteDe(corps.get('id'));
        r.reference = texteDe(corps.get('reference'));
        Object statut = corps.get('status');
        if (statut instanceof Map<String, Object>) {
            Map<String, Object> s = (Map<String, Object>) statut;
            r.statutDossier = texteDe(s.get('name') != null ? s.get('name') : s.get('slug'));
        }
        Object valeurs = corps.get('values');
        if (valeurs instanceof Map<String, Object>) {
            r.statutVt = texteDe(((Map<String, Object>) valeurs).get('status_vt'));
        }
        // PAS DE REPLI sur le statut de workflow : depuis que Certiko expose
        // status_vt, y recopier « Nouveaux Clients » remplirait la liste de
        // sélection avec une valeur qui n'en fait pas partie.
        return r;
    }

    private static String texteDe(Object o) {
        return o == null ? null : String.valueOf(o);
    }

    /**
     * La valeur est-elle acceptable pour ce champ du Dossier ?
     *
     * Un champ de LISTE DE SÉLECTION n'admet que ses valeurs actives : Certiko
     * peut ouvrir un statut que nous ne connaissons pas encore, et l'écrire
     * laisserait le dossier dans un état dont nos règles ne savent rien. Les
     * valeurs sont lues DANS LE SCHÉMA : en ajouter une se fait en
     * configuration, sans toucher au code. Un champ texte accepte tout.
     */
    public static Boolean valeurAdmise(Schema.SObjectField champ, String valeur) {
        if (String.isBlank(valeur)) {
            return false;
        }
        Schema.DescribeFieldResult info = champ.getDescribe();
        Schema.DisplayType genre = info.getType();
        if (genre != Schema.DisplayType.PICKLIST && genre != Schema.DisplayType.MULTIPICKLIST) {
            return true;
        }
        for (Schema.PicklistEntry choix : info.getPicklistValues()) {
            if (choix.isActive() && choix.getValue() == valeur) {
                return true;
            }
        }
        return false;
    }

    /** Valeurs proposées par un champ, pour le dire à celui qui s'est trompé. */
    public static List<String> valeursAdmises(Schema.SObjectField champ) {
        List<String> sortie = new List<String>();
        for (Schema.PicklistEntry choix : champ.getDescribe().getPicklistValues()) {
            if (choix.isActive()) {
                sortie.add(choix.getValue());
            }
        }
        return sortie;
    }

    /**
     * Libellés de la liste de sélection, retenus le temps de la transaction :
     * getDossiers peut traiter mille dossiers, et redécrire le champ pour
     * chacun ne rendrait jamais rien de nouveau.
     */
    private static Map<String, Map<String, String>> libellesParChamp =
        new Map<String, Map<String, String>>();

    /**
     * Libellé lisible d'une valeur de liste de sélection (« en_cours » ->
     * « En cours »), ou null si la valeur n'en fait pas partie.
     *
     * Sert d'appui au portail : celui-ci traduit d'abord dans la langue du
     * pré-visiteur, et retombe sur ce libellé pour un statut ajouté en
     * configuration sans qu'on ait pensé au dictionnaire. Mieux vaut un
     * libellé français qu'une valeur d'API à l'écran.
     */
    public static String libelleDe(Schema.SObjectField champ, String valeur) {
        if (String.isBlank(valeur)) {
            return null;
        }
        Schema.DescribeFieldResult info = champ.getDescribe();
        String cle = String.valueOf(info.getSObjectType()) + '.' + info.getName();
        Map<String, String> libelles = libellesParChamp.get(cle);
        if (libelles == null) {
            libelles = new Map<String, String>();
            for (Schema.PicklistEntry choix : info.getPicklistValues()) {
                libelles.put(choix.getValue(), choix.getLabel());
            }
            libellesParChamp.put(cle, libelles);
        }
        return libelles.get(valeur);
    }

    /**
     * Valeur d un Custom Label.
     *
     * ⚠️ System.Label et non Label : un parametre nomme « label » masquerait le
     * mot-cle et la classe ne compilerait plus (« Variable does not exist »).
     * Les Custom Labels ne sont pas adressables dynamiquement : chaque reglage
     * est donc nomme explicitement.
     */
    private static String reglage(String cle) {
        String v;
        if (cle == 'CERTIKO_BASE_URL')        v = System.Label.CERTIKO_BASE_URL;
        else if (cle == 'CERTIKO_API_KEY')    v = System.Label.CERTIKO_API_KEY;
        else if (cle == 'CERTIKO_BOARD')      v = System.Label.CERTIKO_BOARD;
        else if (cle == 'CERTIKO_STATUT_CREATION') v = System.Label.CERTIKO_STATUT_CREATION;
        else if (cle == 'CERTIKO_URL_TERRAIN') v = System.Label.CERTIKO_URL_TERRAIN;
        if (String.isBlank(v)) {
            throw new CertikoException('CERTIKO_REGLAGE_MANQUANT');
        }
        return v.trim();
    }
}