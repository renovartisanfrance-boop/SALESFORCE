/**
 * LC027_CertikoComptes — équipes et comptes des pré-visiteurs chez Certiko.
 *
 * TROISIÈME CLASSE CERTIKO, et ce n'est pas un découpage de confort :
 *   • LC027_Certiko       — les DOSSIERS (clé CERTIKO_API_KEY) ;
 *   • LC027_CertikoRetour — le webhook entrant ;
 *   • celle-ci            — les ÉQUIPES et les COMPTES, avec une clé À PART
 *     (CERTIKO_API_KEY_COMPTES). Deux clés, deux périmètres : celle des
 *     dossiers ne crée pas d'utilisateur, et inversement. Les mélanger ferait
 *     qu'une fuite de l'une donnerait les deux pouvoirs.
 *
 * POURQUOI UNE ÉQUIPE PAR PRÉ-VISITEUR — Certiko affecte les dossiers à une
 * équipe, pas à une personne. Sans équipe propre, tous les pré-visiteurs
 * verraient les mêmes dossiers. D'où « Equipo <nom> », créée juste avant le
 * compte.
 *
 * CE QUI SE PASSE QUAND ÇA EXISTE DÉJÀ — l'API répond 409 avec un code
 * (`equipe_exists`, `email_taken`), et les deux ne se traitent pas pareil :
 *   • `email_taken` : c'est LA MÊME PERSONNE. On retrouve son compte plutôt
 *     que d'échouer — une re-signature ne doit pas afficher une erreur ;
 *   • `equipe_exists` : c'est peut-être un HOMONYME. On crée alors l'équipe
 *     sous un nom suffixé, sauf si celle qui bloque est vide — auquel cas
 *     elle est sans doute la nôtre, restée d'une tentative avortée.
 * Voir creerEquipe et creerCompte.
 *
 * ⚠️ AUCUNE SUPPRESSION dans cette API : un compte se DÉSACTIVE
 * (`is_active: false`), il ne s'efface pas. Une équipe aussi.
 */
public without sharing class LC027_CertikoComptes {

    public class CertikoComptesException extends Exception {}

    private static final Integer DELAI_MS = 60000;
    /** Langue des comptes créés : les pré-visiteurs sont espagnols. */
    private static final String LANGUE = 'es';
    /**
     * Palette des équipes — un hasard BORNÉ.
     *
     * Tirer une couleur au hasard sur les seize millions possibles donnerait
     * un jaune pâle illisible une fois sur dix. Celles-ci se distinguent les
     * unes des autres et se lisent toutes sur le fond clair de leur console.
     */
    private static final List<String> COULEURS = new List<String>{
        '#3B82F6', '#10B981', '#F59E0B', '#8B5CF6',
        '#EF4444', '#14B8A6', '#EC4899', '#6366F1'
    };

    /**
     * Nombre de noms essayés avant d'abandonner.
     *
     * Petit, et pour une raison : l'API plafonne à une requête par seconde,
     * et chaque essai en coûte deux. Deux pré-visiteurs homonymes arrivent ;
     * cinq, jamais — et si cela arrivait, mieux vaut une erreur lisible
     * qu'une rafale de 429.
     */
    private static final Integer ESSAIS_NOM = 5;

    /* ════════════════════════════════════════════════════════════════════════
       CE QUE L'API REND
       ════════════════════════════════════════════════════════════════════════ */

    public class Equipe {
        @AuraEnabled public String id;
        @AuraEnabled public String nom;
        @AuraEnabled public String couleur;
        @AuraEnabled public Boolean active;
        @AuraEnabled public Integer membres;
    }

    public class Membre {
        @AuraEnabled public String id;
        @AuraEnabled public String email;
        @AuraEnabled public String prenom;
        @AuraEnabled public String nom;
        @AuraEnabled public String telephone;
        @AuraEnabled public String role;
        @AuraEnabled public String langue;
        @AuraEnabled public String equipeId;
        @AuraEnabled public Boolean actif;
        @AuraEnabled public Datetime derniereConnexion;
        @AuraEnabled public Datetime creeLe;
    }

    /** Titulaire de la clé — sert à vérifier qu'elle répond. */
    public class Poseur {
        @AuraEnabled public String id;
        @AuraEnabled public String nom;
        @AuraEnabled public Integer equipes;
    }

    /* ════════════════════════════════════════════════════════════════════════
       ÉQUIPES
       ════════════════════════════════════════════════════════════════════════ */

    public static Poseur poseur() {
        Map<String, Object> corps = appeler(requete('GET', '/poseur'));
        Poseur p = new Poseur();
        p.id = texte(corps, 'id');
        p.nom = texte(corps, 'name');
        p.equipes = entier(corps, 'equipes_count');
        return p;
    }

    public static List<Equipe> equipes(Boolean inclureInactives) {
        String chemin = '/equipes' + (inclureInactives == true ? '?include_inactive=true' : '');
        List<Equipe> sortie = new List<Equipe>();
        for (Object o : liste(appeler(requete('GET', chemin)))) {
            sortie.add(versEquipe((Map<String, Object>) o));
        }
        return sortie;
    }

    /**
     * Crée l'équipe du pré-visiteur, quitte à changer son nom.
     *
     * DEUX PRÉ-VISITEURS PEUVENT PORTER LE MÊME NOM. Leurs équipes
     * s'appelleraient alors « Equipo Jose Martinez » toutes les deux, et
     * l'API refuse le doublon (409 « equipe_exists »). Glisser le second dans
     * l'équipe du premier serait le pire des règlements : Certiko affecte les
     * dossiers à une ÉQUIPE, le nouveau venu verrait donc les visites de son
     * homonyme. On ajoute donc un suffixe et on réessaie.
     *
     * SAUF SI L'ÉQUIPE EST VIDE — auquel cas elle est très probablement la
     * nôtre : une ouverture de compte qui échoue après la création de
     * l'équipe en laisse une sans personne dedans. La réutiliser évite d'en
     * semer une nouvelle à chaque tentative.
     *
     * @return l'équipe obtenue. SON NOM PEUT DIFFÉRER de celui demandé : c'est
     *         `Equipe.nom` qu'il faut donner à creerCompte, pas le nom voulu.
     */
    public static Equipe creerEquipe(String nom) {
        if (String.isBlank(nom)) {
            throw new CertikoComptesException('CERTIKO_EQUIPE_SANS_NOM');
        }
        String souhaite = nom.trim();
        CertikoComptesException dernier;
        for (Integer essai = 1; essai <= ESSAIS_NOM; essai++) {
            String candidat = essai == 1 ? souhaite : souhaite + ' (' + essai + ')';
            HttpRequest req = requete('POST', '/equipes');
            req.setBody(JSON.serialize(new Map<String, Object>{
                'name' => candidat, 'color' => couleurAuHasard()
            }));
            try {
                return versEquipe(appeler(req));
            } catch (CertikoComptesException e) {
                if (e.getMessage() != 'CERTIKO_EQUIPE_EXISTE') {
                    throw e;
                }
                dernier = e;
                Equipe libre = equipeReutilisable(candidat);
                if (libre != null) {
                    return libre;
                }
                // Le nom est pris par une équipe qui a des membres : elle sert
                // à quelqu'un. On en essaie un autre.
            }
        }
        throw dernier;
    }

    /**
     * L'équipe qui porte ce nom est-elle libre ?
     *
     * VIDE = réutilisable. Un membre dedans = celle de quelqu'un d'autre, on
     * n'y touche pas. Une équipe inactive et vide est réactivée plutôt que
     * doublée : l'API refuserait de toute façon d'en créer une seconde du
     * même nom.
     *
     * Les inactives sont incluses dans LA MÊME lecture : deux appels pour la
     * même question coûteraient un 429 sur une API limitée à une requête par
     * seconde.
     */
    private static Equipe equipeReutilisable(String nom) {
        for (Equipe e : equipes(true)) {
            if (e.nom == null || !e.nom.equalsIgnoreCase(nom)) {
                continue;
            }
            if (e.membres != null && e.membres > 0) {
                return null;
            }
            return e.active == true ? e : majEquipe(e.id, null, true);
        }
        return null;
    }

    @TestVisible
    private static String couleurAuHasard() {
        return COULEURS[(Integer) (Math.random() * COULEURS.size())];
    }

    /** Renomme, recolore ou (dés)active une équipe. Les nulls sont ignorés. */
    public static Equipe majEquipe(String cle, String nouveauNom, Boolean active) {
        Map<String, Object> corps = new Map<String, Object>();
        if (String.isNotBlank(nouveauNom)) corps.put('name', nouveauNom.trim());
        if (active != null) corps.put('is_active', active);
        if (corps.isEmpty()) {
            throw new CertikoComptesException('CERTIKO_RIEN_A_CHANGER');
        }
        HttpRequest req = requete('PATCH', '/equipes/' + encoder(cle));
        req.setBody(JSON.serialize(corps));
        return versEquipe(appeler(req));
    }

    public static Equipe equipeParNom(String nom) {
        return equipeParNom(nom, false);
    }

    public static Equipe equipeParNom(String nom, Boolean inclureInactives) {
        for (Equipe e : equipes(inclureInactives)) {
            if (e.nom != null && e.nom.equalsIgnoreCase(nom)) {
                return e;
            }
        }
        return null;
    }

    /* ════════════════════════════════════════════════════════════════════════
       COMPTES
       ════════════════════════════════════════════════════════════════════════ */

    public static List<Membre> membres(String equipe, Boolean inclureInactifs) {
        List<String> params = new List<String>();
        if (String.isNotBlank(equipe)) params.add('equipe=' + encoder(equipe));
        if (inclureInactifs == true) params.add('include_inactive=true');
        String chemin = '/users' + (params.isEmpty() ? '' : '?' + String.join(params, '&'));
        List<Membre> sortie = new List<Membre>();
        for (Object o : liste(appeler(requete('GET', chemin)))) {
            sortie.add(versMembre((Map<String, Object>) o));
        }
        return sortie;
    }

    public static Membre membreParEmail(String email, Boolean inclureInactifs) {
        for (Membre m : membres(null, inclureInactifs)) {
            if (m.email != null && m.email.equalsIgnoreCase(email)) {
                return m;
            }
        }
        return null;
    }

    /**
     * Crée le compte, ou RETROUVE celui qui porte déjà cet email.
     *
     * Le 409 « email_taken » arrive dès qu'un contrat est signé deux fois, ou
     * qu'un pré-visiteur revient. On rend alors le compte existant : le portail
     * doit afficher un accès, pas un message d'erreur.
     */
    public static Membre creerCompte(String email, String motDePasse, String prenom,
            String nom, String equipe, String telephone) {
        if (String.isBlank(email) || String.isBlank(motDePasse) || String.isBlank(equipe)) {
            throw new CertikoComptesException('CERTIKO_COMPTE_INCOMPLET');
        }
        Map<String, Object> corps = new Map<String, Object>{
            'email' => email.trim(),
            'password' => motDePasse,
            // L'API exige un prénom ET un nom : un pré-visiteur inscrit sous
            // un seul mot ne doit pas faire échouer la création.
            'first_name' => String.isBlank(prenom) ? nom : prenom,
            'last_name' => String.isBlank(nom) ? prenom : nom,
            'equipe' => equipe.trim(),
            'language' => LANGUE
        };
        if (String.isNotBlank(telephone)) {
            corps.put('phone', telephone.trim());
        }
        HttpRequest req = requete('POST', '/users');
        req.setBody(JSON.serialize(corps));
        try {
            return versMembre(appeler(req));
        } catch (CertikoComptesException e) {
            if (e.getMessage() != 'CERTIKO_EMAIL_PRIS') {
                throw e;
            }
            Membre existant = membreParEmail(email.trim(), true);
            if (existant == null) {
                throw e;
            }
            return existant;
        }
    }

    /**
     * Change ce qui est fourni, ignore le reste.
     * @param actif null pour ne pas y toucher.
     */
    public static Membre majCompte(String cle, String motDePasse, String equipe, Boolean actif) {
        Map<String, Object> corps = new Map<String, Object>();
        if (String.isNotBlank(motDePasse)) corps.put('password', motDePasse);
        if (String.isNotBlank(equipe)) corps.put('equipe', equipe.trim());
        if (actif != null) corps.put('is_active', actif);
        if (corps.isEmpty()) {
            throw new CertikoComptesException('CERTIKO_RIEN_A_CHANGER');
        }
        HttpRequest req = requete('PATCH', '/users/' + encoder(cle));
        req.setBody(JSON.serialize(corps));
        return versMembre(appeler(req));
    }

    /* ════════════════════════════════════════════════════════════════════════
       LECTURE DES RÉPONSES
       ════════════════════════════════════════════════════════════════════════ */

    private static Equipe versEquipe(Map<String, Object> o) {
        Equipe e = new Equipe();
        e.id = texte(o, 'id');
        e.nom = texte(o, 'name');
        e.couleur = texte(o, 'color');
        e.active = booleen(o, 'is_active');
        e.membres = entier(o, 'members_count');
        return e;
    }

    private static Membre versMembre(Map<String, Object> o) {
        Membre m = new Membre();
        m.id = texte(o, 'id');
        m.email = texte(o, 'email');
        m.prenom = texte(o, 'first_name');
        m.nom = texte(o, 'last_name');
        m.telephone = texte(o, 'phone');
        m.role = texte(o, 'role');
        m.langue = texte(o, 'language');
        m.equipeId = texte(o, 'equipe_id');
        m.actif = booleen(o, 'is_active');
        m.derniereConnexion = versDatetime(texte(o, 'last_login'));
        m.creeLe = versDatetime(texte(o, 'created_at'));
        return m;
    }

    private static List<Object> liste(Map<String, Object> corps) {
        Object items = corps.get('items');
        return (items instanceof List<Object>) ? (List<Object>) items : new List<Object>();
    }

    private static String texte(Map<String, Object> o, String cle) {
        Object v = o == null ? null : o.get(cle);
        return v == null ? null : String.valueOf(v);
    }

    private static Boolean booleen(Map<String, Object> o, String cle) {
        Object v = o == null ? null : o.get(cle);
        return v instanceof Boolean ? (Boolean) v : null;
    }

    private static Integer entier(Map<String, Object> o, String cle) {
        Object v = o == null ? null : o.get(cle);
        return v instanceof Integer ? (Integer) v
            : (v instanceof Decimal ? ((Decimal) v).intValue() : null);
    }

    /** « 2026-09-25T11:36:33.249076 » — sans fuseau, donc lu comme de l'UTC. */
    private static Datetime versDatetime(String brut) {
        if (String.isBlank(brut)) return null;
        String iso = brut.substringBefore('.');
        if (!iso.endsWith('Z')) iso += 'Z';
        try {
            return (Datetime) JSON.deserialize('"' + iso + '"', Datetime.class);
        } catch (Exception e) {
            return null;
        }
    }

    /* ════════════════════════════════════════════════════════════════════════
       HTTP
       ════════════════════════════════════════════════════════════════════════ */

    private static HttpRequest requete(String methode, String chemin) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(reglage('CERTIKO_BASE_URL') + chemin);
        req.setMethod(methode);
        req.setTimeout(DELAI_MS);
        // ⚠️ La clé des COMPTES, pas celle des dossiers.
        req.setHeader('X-API-Key', reglage('CERTIKO_API_KEY_COMPTES'));
        req.setHeader('Accept', 'application/json');
        if (methode != 'GET') {
            req.setHeader('Content-Type', 'application/json');
        }
        return req;
    }

    /**
     * Exécute l'appel et rend le corps.
     *
     * Les refus deviennent des CODES : le composant d'administration les
     * traduit, et creerEquipe / creerCompte s'appuient dessus pour distinguer
     * « existe déjà » d'un vrai échec.
     */
    private static Map<String, Object> appeler(HttpRequest req) {
        HttpResponse rep;
        try {
            rep = new Http().send(req);
        } catch (Exception e) {
            throw new CertikoComptesException('CERTIKO_INJOIGNABLE');
        }
        Integer code = rep.getStatusCode();
        Map<String, Object> corps;
        try {
            corps = (Map<String, Object>) JSON.deserializeUntyped(rep.getBody());
        } catch (Exception e) {
            corps = null;
        }
        if (code >= 200 && code < 300) {
            if (corps == null) {
                throw new CertikoComptesException('CERTIKO_REPONSE_ILLISIBLE');
            }
            return corps;
        }
        if (code == 429) throw new CertikoComptesException('CERTIKO_LIMITE_DEBIT');
        if (code == 401 || code == 403) throw new CertikoComptesException('CERTIKO_CLE_REFUSEE');
        if (code == 404) throw new CertikoComptesException('CERTIKO_INTROUVABLE');
        if (code == 409) {
            String detail = codeDErreur(corps);
            if (detail == 'equipe_exists') throw new CertikoComptesException('CERTIKO_EQUIPE_EXISTE');
            if (detail == 'email_taken') throw new CertikoComptesException('CERTIKO_EMAIL_PRIS');
        }
        throw new CertikoComptesException('CERTIKO_REFUS:' + message(corps, rep.getBody()));
    }

    /** « error.code » de l'API, seul repère stable d'un refus. */
    private static String codeDErreur(Map<String, Object> corps) {
        Object err = corps == null ? null : corps.get('error');
        if (err instanceof Map<String, Object>) {
            Object c = ((Map<String, Object>) err).get('code');
            return c == null ? null : String.valueOf(c);
        }
        return null;
    }

    private static String message(Map<String, Object> corps, String brut) {
        Object err = corps == null ? null : corps.get('error');
        if (err instanceof Map<String, Object>) {
            Object m = ((Map<String, Object>) err).get('message');
            if (m != null) return String.valueOf(m);
        }
        return brut == null ? '' : brut.abbreviate(200);
    }

    private static String encoder(String valeur) {
        return EncodingUtil.urlEncode(valeur == null ? '' : valeur.trim(), 'UTF-8');
    }

    /**
     * Valeur d'un Custom Label.
     *
     * ⚠️ System.Label et non Label : un paramètre nommé « label » masquerait le
     * mot-clé. Les labels ne sont pas adressables dynamiquement, chaque réglage
     * est donc nommé explicitement.
     */
    private static String reglage(String cle) {
        String v;
        if (cle == 'CERTIKO_BASE_URL') v = System.Label.CERTIKO_BASE_URL;
        else if (cle == 'CERTIKO_API_KEY_COMPTES') v = System.Label.CERTIKO_API_KEY_COMPTES;
        if (String.isBlank(v)) {
            throw new CertikoComptesException('CERTIKO_REGLAGE_MANQUANT');
        }
        return v.trim();
    }
}