/**
 * lwc000_i18n — Module de traduction partagé (FR / ES) du site Campagnes.
 *
 * Règle métier : la langue est une fonction PURE de (valeur stockée, pays de la
 * campagne, accès réduit). Une campagne France est verrouillée en français quoi
 * qu'il y ait dans le localStorage — sans quoi un « renov_langue=es » laissé par
 * une session espagnole précédente afficherait une campagne française en espagnol
 * (cas réel : l'utilisateur ouvre un nouveau lien ?c__code= sans s'être
 * déconnecté, donc localStorage.clear() n'a pas tourné).
 *
 * Le même verrouillage s'applique aux campagnes en ACCÈS RÉDUIT (partenaires),
 * espagnoles comprises : elles n'offrent aucun sélecteur et affichent la langue
 * de leur pays, et elle seule. Voir choixLangueOffert().
 *
 * Les dictionnaires vivent dans des fichiers frères (dicoCommun.js, dicoEntete.js,
 * dicoNouveauRdv.js). Ils ne sont PAS importables depuis un autre composant :
 * seul ce fichier est l'API publique. Une page = un dictionnaire.
 *
 * Utilisation type dans un composant :
 *     import { FR, lireLangue, etiquettes } from 'c/lwc000_i18n';
 *     _langue = FR;
 *     @api get langue() { return this._langue; }
 *          set langue(v) { this._langue = v || FR; }
 *     get txt() { return etiquettes('nouveauRdv', this._langue); }
 *  puis dans le template : {txt.nomClient}, placeholder={txt.nomClientPh}
 */
import { DICO_COMMUN } from './dicoCommun';
import { DICO_ENTETE } from './dicoEntete';
import { DICO_NOUVEAU_RDV } from './dicoNouveauRdv';
import { DICO_FILE_UPLOAD } from './dicoFileUpload';
import { DICO_CAHIER_CHARGES } from './dicoCahierCharges';
import { DICO_FACTURATION } from './dicoFacturation';
import { DICO_GESTION_CAMPAGNES } from './dicoGestionCampagnes';
import { DICO_REPORTING } from './dicoReporting';
import { DICO_DEVIS } from './dicoDevis';
import { DICO_DOCUMENTS } from './dicoDocuments';

export const FR = 'fr';
export const ES = 'es';

/** Valeur de la picklist Pays__c déclenchant le bilinguisme. */
export const PAYS_ESPAGNE = 'Espagne';

/** Clé localStorage — même convention que renov_campaign_token / renov_footer_collapsed. */
export const CLE_LANGUE = 'renov_langue';

const LANGUES = [FR, ES];

// Ajouter ici tout nouveau dictionnaire de page.
const PAGES = {
    entete: DICO_ENTETE,
    nouveauRdv: DICO_NOUVEAU_RDV,
    fileUpload: DICO_FILE_UPLOAD,
    cahierCharges: DICO_CAHIER_CHARGES,
    facturation: DICO_FACTURATION,
    gestionCampagnes: DICO_GESTION_CAMPAGNES,
    reporting: DICO_REPORTING,
    devis: DICO_DEVIS,
    documents: DICO_DOCUMENTS
};

const _cache = new Map();

/* ------------------------------------------------------------------ *
 *  Résolution de la langue
 * ------------------------------------------------------------------ */

/**
 * Le PAYS admet-il les deux langues ? Espagne seule.
 *
 * ⚠️ Ne dit PAS si le sélecteur s'affiche — c'est `choixLangueOffert` qui en
 * décide. La distinction compte : le titre du site (« Espace CEE » / « Espacio
 * CAE ») dépend de ce drapeau-ci, du pays donc, et doit rester espagnol pour un
 * partenaire espagnol qui, lui, n'a aucun sélecteur.
 */
export function bilingue(pays) {
    return pays === PAYS_ESPAGNE;
}

/** Espagne => espagnol par défaut ; tout le reste => français. */
export function langueParDefaut(pays) {
    return bilingue(pays) ? ES : FR;
}

/**
 * Le CHOIX de la langue est-il offert à l'utilisateur ?
 *
 * Deux conditions cumulatives :
 *   - le pays est bilingue (Espagne) ;
 *   - la campagne n'est PAS en accès réduit.
 *
 * Les partenaires (AccesReduit__c) ne choisissent pas : ils voient le site dans
 * la langue de leur pays, et elle seule — espagnol pour une campagne Espagne,
 * français pour une campagne France. Leur parcours est court et prescrit ; un
 * sélecteur n'y a pas d'utilité et exposerait une version qui ne les concerne pas.
 */
export function choixLangueOffert(pays, accesReduit) {
    return bilingue(pays) && accesReduit !== true;
}

/** Toute valeur inconnue, vide ou nulle retombe sur `repli`. */
export function normaliserLangue(valeur, repli) {
    return LANGUES.includes(valeur) ? valeur : (repli || FR);
}

/**
 * Langue d'affichage effective.
 *
 * Sans choix offert (pays non bilingue, OU accès réduit), la langue est IMPOSÉE
 * par le pays et le stockage est ignoré — sans quoi un « renov_langue=fr » laissé
 * par une session de régie afficherait en français le portail d'un partenaire
 * espagnol (cas réel du même ordre que celui décrit en tête de fichier).
 *
 * `accesReduit` omis => comme avant : seul le pays décide de l'offre.
 */
export function lireLangue(pays, accesReduit) {
    if (!choixLangueOffert(pays, accesReduit)) return langueParDefaut(pays);
    let stocke = null;
    try {
        stocke = localStorage.getItem(CLE_LANGUE);
    } catch (e) {
        stocke = null; // localStorage indisponible (navigation privée)
    }
    return normaliserLangue(stocke, langueParDefaut(pays));
}

/**
 * Persiste le choix et RENVOIE la langue retenue — à affecter directement :
 *     this.langue = ecrireLangue(choix, this.campaign?.Pays__c, this.isAccesReduit);
 *
 * Quand aucun choix n'est offert, RIEN n'est persisté : écrire la langue imposée
 * d'un partenaire écraserait la préférence d'une future session où le choix, lui,
 * sera bien offert.
 */
export function ecrireLangue(langue, pays, accesReduit) {
    if (!choixLangueOffert(pays, accesReduit)) return langueParDefaut(pays);
    const lg = normaliserLangue(langue, langueParDefaut(pays));
    try {
        localStorage.setItem(CLE_LANGUE, lg);
    } catch (e) {
        // ignore (localStorage indisponible)
    }
    return lg;
}

/* ------------------------------------------------------------------ *
 *  Étiquettes
 * ------------------------------------------------------------------ */

/**
 * Objet PLAT de libellés résolus, prêt à binder dans un template.
 *
 * Chaîne de repli : FR commun -> FR page -> ES commun -> ES page.
 * Une clé absente du dictionnaire espagnol retombe donc STRUCTURELLEMENT sur le
 * français : il est impossible d'afficher « undefined » ou un nom de clé brut.
 *
 * Le résultat est mémoïsé : appeler ce getter à chaque rendu ne coûte qu'une
 * lecture de Map, et l'identité de l'objet reste stable.
 */
export function etiquettes(page, langue) {
    const lg = normaliserLangue(langue, FR);
    const cle = page + '|' + lg;
    if (_cache.has(cle)) return _cache.get(cle);

    const dico = PAGES[page] || {};
    const plat = {
        ...(DICO_COMMUN[FR] || {}),
        ...(dico[FR] || {}),
        ...(lg === FR ? {} : (DICO_COMMUN[lg] || {})),
        ...(lg === FR ? {} : (dico[lg] || {}))
    };
    // Pas de Object.freeze : un objet gelé interagit mal avec le membrane
    // réactif de LWC s'il atterrit un jour sur un champ @track.
    _cache.set(cle, plat);
    return plat;
}

/**
 * Substitution de paramètres nommés : « ({taille} Mo) » + {taille: '5,10'}.
 * Nommés et non positionnels, car l'ordre des mots diffère en espagnol.
 * Un paramètre manquant laisse « {taille} » visible — défaut évident et
 * greppable, jamais « undefined ».
 */
export function remplir(modele, params) {
    if (!modele) return '';
    if (!params) return String(modele);
    return String(modele).replace(/\{(\w+)\}/g, (brut, cle) =>
        Object.prototype.hasOwnProperty.call(params, cle) ? String(params[cle]) : brut
    );
}

/* ------------------------------------------------------------------ *
 *  Formats
 * ------------------------------------------------------------------ */

/** Locale pour Intl.* / toLocaleDateString. */
export function localeDe(langue) {
    return normaliserLangue(langue, FR) === ES ? 'es-ES' : 'fr-FR';
}

/** Séparateur décimal : « 4.20 » en français, « 4,20 » en espagnol. */
export function nombreDecimal(valeur, langue) {
    const txt = String(valeur === null || valeur === undefined ? '' : valeur);
    return normaliserLangue(langue, FR) === ES ? txt.replace('.', ',') : txt;
}

/* ------------------------------------------------------------------ *
 *  Catalogue produits
 * ------------------------------------------------------------------ */

/**
 * Traduit une fiche produit de PRODUCT_CATALOG.
 *
 * La fusion est GÉNÉRIQUE et volontairement non listée champ par champ : si on
 * ajoute demain un champ d'affichage aux fiches Espagne (description, sousTitre,
 * argumentaire...), il suffit de le déclarer dans `i18n.es` pour qu'il soit
 * traduit, sans toucher à ce module.
 *
 * Ne JAMAIS mettre dans `i18n` les champs qui servent de VALEURS
 * (codeProduit, typeEnregistrement, typeProduit, ordreAffichage) : ils pilotent
 * le filtrage côté LWC et la charge utile Apex de createLead.
 *
 * Renvoie la fiche d'origine telle quelle s'il n'y a rien à traduire — les
 * produits France ne sont donc jamais recopiés.
 */
export function traduireProduit(produit, langue) {
    const lg = normaliserLangue(langue, FR);
    const surcharge = produit && produit.i18n && produit.i18n[lg];
    return surcharge ? { ...produit, ...surcharge } : produit;
}

/** Idem sur une liste. */
export function traduireProduits(produits, langue) {
    return (produits || []).map(p => traduireProduit(p, langue));
}

/**
 * Libellé d'un typeProduit ('Residentiel' -> 'Residencial').
 * Seul le LIBELLÉ change : la valeur reste française côté filtrage et Apex.
 */
export function traduireTypeProduit(typeProduit, langue, page) {
    if (!typeProduit) return typeProduit;
    return etiquettes(page || 'nouveauRdv', langue)['tp_' + typeProduit] || typeProduit;
}

/**
 * Traduit les libellés d'une liste de colonnes (Facturation).
 *
 * La clé est le `key` de la colonne (col_numero, col_ttc...), jamais son
 * libellé : renommer une colonne côté français ne casse donc pas la traduction.
 * Les constantes COLONNES_* de c/lwc020_FacturationUtils restent de la pure
 * configuration, sans dépendance à l'i18n — c'est ce module qui vient poser la
 * traduction par-dessus, au rendu.
 *
 * Renvoie la liste d'origine si rien n'est à traduire (français) : aucune copie
 * inutile, et l'identité de l'objet reste stable pour les @api des enfants.
 */
export function traduireColonnes(colonnes, langue, page) {
    const lg = normaliserLangue(langue, FR);
    if (lg === FR) return colonnes || [];
    const t = etiquettes(page || 'facturation', lg);
    return (colonnes || []).map(c => {
        const libelle = t['col_' + c.key];
        return libelle ? { ...c, label: libelle } : c;
    });
}

/**
 * Libellé d'une valeur de picklist venant de l'org (getFieldsMetadata renvoie
 * toujours le français pour l'utilisateur portail). Clé = VALEUR D'API.
 * Retombe sur le libellé d'origine si aucune surcharge n'existe.
 */
export function traduirePicklist(valeur, libelle, langue, page) {
    if (!valeur) return libelle;
    return etiquettes(page || 'nouveauRdv', langue)['pl_' + valeur] || libelle;
}

/* ------------------------------------------------------------------ *
 *  Traduction par valeur francaise
 * ------------------------------------------------------------------ */

const _cacheInverse = new Map();

/**
 * Traduit un texte en partant de sa valeur FRANCAISE plutot que de sa cle.
 *
 * Utile quand les libelles vivent dans une structure de configuration qu'on ne
 * veut pas modifier — typiquement COLUMNS_CONFIG de lwc020_reporting_v2, un
 * tableau constant de ~15 colonnes ou chaque entree porte deja son `label`.
 * Plutot que d'y injecter une cle de dictionnaire, on retrouve la traduction en
 * indexant le dictionnaire a l'envers (valeur FR -> valeur ES).
 *
 * Deux libelles FR identiques donneraient la meme traduction : sans ambiguite
 * reelle, puisqu'ils diraient la meme chose.
 *
 * Renvoie le texte d'origine si aucune correspondance : jamais de vide.
 */
export function traduireValeurFr(texte, langue, page) {
    const lg = normaliserLangue(langue, FR);
    if (lg === FR || !texte) return texte;
    const cle = (page || '') + '|' + lg;
    let table = _cacheInverse.get(cle);
    if (!table) {
        table = {};
        const dico = PAGES[page] || {};
        const fr = { ...(DICO_COMMUN[FR] || {}), ...(dico[FR] || {}) };
        const tr = { ...(DICO_COMMUN[lg] || {}), ...(dico[lg] || {}) };
        Object.keys(fr).forEach(k => {
            if (typeof fr[k] === 'string' && tr[k]) table[fr[k]] = tr[k];
        });
        _cacheInverse.set(cle, table);
    }
    return table[texte] || texte;
}

/**
 * Applique traduireValeurFr sur le champ `label` d'une liste de configurations.
 */
export function traduireLabels(liste, langue, page) {
    const lg = normaliserLangue(langue, FR);
    if (lg === FR) return liste || [];
    return (liste || []).map(c => {
        const l = traduireValeurFr(c.label, lg, page);
        return l === c.label ? c : { ...c, label: l };
    });
}

/* ------------------------------------------------------------------ *
 *  Outil de recette (pas de production)
 * ------------------------------------------------------------------ */

/** Clés présentes en français et absentes en espagnol, pour une page donnée. */
export function clesManquantes(page) {
    const dico = PAGES[page] || {};
    const ref = { ...(DICO_COMMUN[FR] || {}), ...(dico[FR] || {}) };
    const trad = { ...(DICO_COMMUN[ES] || {}), ...(dico[ES] || {}) };
    return Object.keys(ref).filter(c => trad[c] === undefined);
}