/**
 * devisConfig — TOUTE la configuration métier du workflow de devis.
 *
 * C'est le SEUL fichier à ouvrir pour :
 *   • ajouter / retirer / réordonner un champ du récapitulatif,
 *   • changer les tranches surface -> puissance,
 *   • brancher un nouveau statut de devis.
 *
 * Module JS pur, sans template : il n'est pas exposé et ne peut pas être posé
 * dans Experience Builder — même motif que lwc020_FacturationUtils.
 *
 * ⚠️ SÉCURITÉ — la liste de champs ci-dessous ne fait qu'AFFICHER. L'autorisation
 *    réelle vit dans LC021_DevisSignature (CONFIG_LEAD / CONFIG_PRO). Déclarer un
 *    champ ici sans l'ajouter à la liste blanche Apex ne l'ouvre pas : il sera
 *    simplement absent de la réponse. Les deux doivent être tenus ensemble.
 */

import { champsRecapDeclares } from 'c/lwc000_utils';

/* ═══════════════════════════════════════════════════════════════════════════
   STATUTS DE DEVIS

   Les valeurs de picklist réelles diffèrent entre Lead (RES_Statut_Devis__c :
   « 🟦En Att Signature ») et Pro__c (devisfinal__c : « 🟦En Attente Signature »).
   L'Apex les normalise en CODES ; c'est sur ces codes que le composant décide,
   jamais sur le texte affiché.
   ═══════════════════════════════════════════════════════════════════════════ */

export const STATUT_GENERATION        = 'GENERATION';
export const STATUT_ATTENTE_SIGNATURE = 'ATTENTE_SIGNATURE';
export const STATUT_SIGNE             = 'SIGNE';
export const STATUT_INCONNU           = 'INCONNU';

/* ═══════════════════════════════════════════════════════════════════════════
   RÉCAPITULATIF — champs affichés

   `field`    : nom d'API RÉEL (vérifié sur l'org, cf. en-tête de LC021).
   `label`    : libellé affiché. Absent => le libellé Salesforce du champ.
   `editable` : true = saisissable puis enregistrable. N'a d'effet que si le
                champ est aussi dans la liste blanche d'écriture de l'Apex.
   `type`     : type du <input> natif. Absent => déduit du DisplayType.
   `pleineLargeur` : le champ occupe les deux colonnes de la grille.
   ═══════════════════════════════════════════════════════════════════════════ */

/**
 * Piste (Lead). Surface habitable = Surface_habitable__c (« RES- Shab »).
 *
 * `Street` porte l'adresse ENTIÈRE sur la Piste : ni code postal ni ville ne
 * sont repris à part, le devis n'a qu'une ligne « Dirección ».
 */
export const CHAMPS_RECAP_LEAD = [
    { field: 'LastName',             label: 'Nom',               editable: true },
    { field: 'FirstName',            label: 'Prénom',            editable: true },
    { field: 'Phone',                label: 'Téléphone',         editable: true, type: 'tel' },
    { field: 'Email',                label: 'Email',             editable: true, type: 'email' },
    // « REGIE- Adresse Client » plutot que Street : c'est le champ que la
    // regie renseigne reellement, et celui qui doit figurer sur le devis.
    { field: 'REGIE_Adresse_Client__c', label: 'Adresse',        editable: true, pleineLargeur: true },
    { field: 'Surface_habitable__c', label: 'Surface habitable', editable: true, type: 'number' }
];

/**
 * Dossier (Pro__c).
 *
 * Écarts d'API par rapport à la Piste — ce ne sont PAS les mêmes noms :
 *   • surface habitable « RES- Shab »  -> MPR_SHAB__c  (et non Surface_habitable__c,
 *     qui n'existe pas sur Pro__c ; Surface_habitablee__c porte, lui, le libellé
 *     « MPR*SHAB.Piste » et n'est donc pas le champ RES) ;
 *   • le nom du client est en un seul champ (PRO_Pr_nom_du_Signataire__c) ;
 *   • l'adresse de chantier est une zone de texte long, qui porte l'adresse
 *     entière — comme `Street` côté Piste.
 *
 * `Name` (nom du dossier) n'est PAS repris : il figure déjà dans le titre de la
 * modale, l'afficher deux fois n'apprendrait rien.
 */
export const CHAMPS_RECAP_PRO = [
    { field: 'PRO_Pr_nom_du_Signataire__c', label: 'Nom + Prénom',      editable: true },
    { field: 'Phone__c',                    label: 'Téléphone',         editable: true, type: 'tel' },
    { field: 'Email__c',                    label: 'Email',             editable: true, type: 'email' },
    { field: 'Client_Adresse_Chantier__c',  label: 'Adresse',           editable: true, pleineLargeur: true },
    { field: 'MPR_SHAB__c',                 label: 'Surface habitable', editable: true, type: 'number' }
];

/** Champ « surface habitable », par objet. */
export const CHAMP_SURFACE = { Lead: 'Surface_habitable__c', 'Pro__c': 'MPR_SHAB__c' };

/**
 * Récapitulatif applicable à un objet donné.
 *
 * @param {String}  objectType     'Lead' ou 'Pro__c'
 * @param {Object}  [options]
 * @param {Boolean} options.avecSurface  false retire la surface habitable.
 *        Elle n'est demandée que si la fiche s'en sert — cases de puissance
 *        du RES060, ou calcul déclaré sur elle (TH168). Ailleurs, la demander
 *        ferait saisir une donnée que rien ne lit, et qui plus est OBLIGATOIRE
 *        puisque tous les champs du récapitulatif le sont.
 * @param {Array}   options.supplementaires  champs propres à la fiche, ajoutés
 *        à la suite — voir champsRecapFiche() de c/lwc000_utils.
 */
export function champsRecap(objectType, options) {
    const opt = options || {};
    const base = objectType === 'Pro__c' ? CHAMPS_RECAP_PRO : CHAMPS_RECAP_LEAD;
    const surface = CHAMP_SURFACE[objectType];

    const retenus = (opt.avecSurface === false
        ? base.filter((c) => c.field !== surface)
        : base).slice();

    // Un champ de fiche se place a la suite, dans l'ordre ou la fiche le
    // declare, ou AVANT un champ nomme par `avant` — pour le poser a gauche
    // d'un champ commun, sur sa rangee, plutot qu'en fin de formulaire.
    (opt.supplementaires || []).forEach((c) => {
        const i = c && c.avant ? retenus.findIndex((r) => r.field === c.avant) : -1;
        if (i === -1) retenus.push(c);
        else retenus.splice(i, 0, c);
    });
    return retenus;
}

/**
 * Champs qui identifient le SIGNATAIRE, par objet.
 *
 * Distincts de CHAMPS_CLIENT_PDF, qui fusionne téléphone et email sur une seule
 * ligne pour l'impression : Yousign, lui, exige un email isolé et un nom séparé
 * du prénom.
 *
 * Sur le Dossier, `PRO_Email_Signataire__c` sert de repli à `Email__c` — les deux
 * existent, et le mail du signataire n'est pas toujours celui du dossier.
 */
export const CHAMPS_SIGNATAIRE = {
    Lead: {
        prenom: 'FirstName',
        nom: 'LastName',
        email: ['Email']
    },
    'Pro__c': {
        // Un seul champ « CLIENT- Nom+Prénom du Signataire » : c'est l'Apex qui
        // le coupe au premier espace, le composant n'affiche que le tout.
        nomComplet: 'PRO_Pr_nom_du_Signataire__c',
        email: ['Email__c', 'PRO_Email_Signataire__c']
    }
};

/** Noms d'API à demander à l'Apex pour un objet donné. */
export function champsDemandes(objectType) {
    const champs = champsRecap(objectType).map((c) => c.field);

    // Le récapitulatif ne montre pas tous les champs dont l'onglet Signature a
    // besoin : sans cet ajout, `PRO_Email_Signataire__c` ne remonterait jamais,
    // bien qu'autorisé côté Apex.
    const conf = CHAMPS_SIGNATAIRE[objectType] || {};
    const complements = [].concat(conf.email || [], conf.nomComplet || [], conf.prenom || [], conf.nom || []);
    for (const api of complements) {
        if (api && !champs.includes(api)) champs.push(api);
    }

    // Suivi Yousign : lecture seule, mais l'onglet Signature doit savoir si une
    // demande est déjà partie et quand.
    for (const api of CHAMPS_SUIVI_YOUSIGN) {
        if (!champs.includes(api)) champs.push(api);
    }

    // Fiche produit : elle désigne les réglages de signature (langue,
    // expéditeur, emplacements) dans c/lwc000_utils.
    const fiche = CHAMP_FICHE[objectType];
    if (fiche && !champs.includes(fiche)) champs.push(fiche);

    // Champs propres aux fiches — celui qui choisit la version du devis, par
    // exemple. Demandés pour TOUTES les fiches, faute de savoir laquelle
    // s'applique avant d'avoir lu l'enregistrement ; l'Apex écarte ceux que sa
    // liste blanche n'autorise pas pour cet objet.
    for (const api of champsRecapDeclares()) {
        if (!champs.includes(api)) champs.push(api);
    }

    return champs;
}

/**
 * Champ portant la fiche produit, par objet.
 *
 * ⚠️ LES DEUX FORMES DIFFÈRENT. La Piste porte le codeProduit exact
 * (« RESIDENTIEL_REGIES_-_RES060 ») ; le Dossier porte un libellé
 * (« BAR_TH171- PAC Indiv »). `reglagesSignature()` de c/lwc000_utils
 * reconnaît les deux, c'est sa raison d'être — ne pas tenter de les
 * normaliser ici.
 */
export const CHAMP_FICHE = {
    Lead: 'TypeDeDossier__c',
    'Pro__c': 'Fiche_CEE__c'
};

/** Champs de suivi Yousign, communs aux deux objets. */
export const CHAMPS_SUIVI_YOUSIGN = [
    'YS_Demande_Id__c',
    'YS_Statut__c',
    'YS_Date_Envoi__c',
    'YS_Date_Signature__c',
    'YS_Nb_Relances__c',
    'YS_Contrat_Doc_Id__c',
    'YS_Contrat_Empreinte__c',
    'YS_Numero_Devis__c'
];

/* ═══════════════════════════════════════════════════════════════════════════
   SURFACE HABITABLE -> PUISSANCE

   Bornes semi-ouvertes [min, max[ pour éviter toute ambiguïté aux frontières,
   sauf la dernière tranche qui INCLUT 210 (« 140 à 210 m² -> 16 KW », puis
   « > 210 m² -> hors cible »).

   Contrôles :  95 -> 12 KW · 125 -> 14 KW · 170 -> 16 KW · 210 -> 16 KW
               211 -> hors cible · 250 -> hors cible · 60 -> hors cible
   ═══════════════════════════════════════════════════════════════════════════ */

export const HORS_CIBLE = 'HORS_CIBLE';

export const TRANCHES_PUISSANCE = [
    { min: 80,  max: 110, maxInclus: false, puissance: 12, libelle: '12 KW' },
    { min: 110, max: 140, maxInclus: false, puissance: 14, libelle: '14 KW' },
    { min: 140, max: 1000, maxInclus: true,  puissance: 16, libelle: '16 KW' }
];

/** Toutes les puissances possibles, dans l'ordre du document. */
export const PUISSANCES = TRANCHES_PUISSANCE.map((t) => t.puissance);

/**
 * Puissance déterminée par la surface.
 *
 * @returns {{puissance:number|null, libelle:string, horsCible:boolean, raison:string|null}}
 *          `raison` vaut 'INFERIEURE' / 'SUPERIEURE' / 'ABSENTE' quand on est hors
 *          cible, pour que le message affiché puisse être précis.
 */
export function puissancePourSurface(surface) {
    const s = Number(surface);
    if (surface === null || surface === undefined || surface === '' || isNaN(s)) {
        return { puissance: null, libelle: '—', horsCible: true, raison: 'ABSENTE' };
    }
    for (const t of TRANCHES_PUISSANCE) {
        const dansBorneHaute = t.maxInclus ? s <= t.max : s < t.max;
        if (s >= t.min && dansBorneHaute) {
            return { puissance: t.puissance, libelle: t.libelle, horsCible: false, raison: null };
        }
    }
    const bornMin = TRANCHES_PUISSANCE[0].min;
    return {
        puissance: null,
        libelle: 'Hors cible',
        horsCible: true,
        raison: s < bornMin ? 'INFERIEURE' : 'SUPERIEURE'
    };
}

/* ════════════════════════════════════════════════════════════════════════════
   DOCUMENT PDF — cochage réel de la puissance

   `cae_colab_contrat` est un PDF PLAT de 3 pages : les trois cases
   « ☐ 12 kW ☐ 14 kW ☐ 16 kW » de la section DESCRIPCIÓN sont du texte imprimé,
   PAS des cases de formulaire AcroForm. Il n'existe donc aucun champ à cocher :
   la coche doit être DESSINÉE dans le fichier, ce que fait `appliquerPuissanceSurPdf`
   via pdf-lib (Static Resource `pdfLib`). Le PDF affiché dans la modale, celui
   ouvert dans un nouvel onglet et celui qui partira en signature sont un seul et
   même fichier, déjà coché.

   COORDONNÉES — relevées sur le fichier réel, page 1 (595 × 842 pt), en repère
   PLACEIT (origine en HAUT à gauche), comme pour Yousign : ce sont les chiffres
   qu'on lit directement dans l'outil, sans conversion mentale. Le passage au
   repère de pdf-lib (origine en BAS à gauche) est fait au dessin par
   versReperePdf(). Les points de la coche sont eux aussi exprimés « y vers le
   bas » depuis le coin haut-gauche de la case.
   ════════════════════════════════════════════════════════════════════════════ */

export const PDF_RESOURCE_NAME = 'cae_colab_contrat';

/* ───────────────────────────────────────────────────────────────────────────
   ZONE « CLIENTE » de la page 1

   ⚠️ DEUX REPÈRES COHABITENT DANS CE FICHIER — c'est LE piège.

     • PlaceIt (et Yousign) comptent depuis le coin HAUT-gauche de la page ;
     • pdf-lib, qui dessine réellement, compte depuis le coin BAS-gauche.

   Toutes les constantes ci-dessous sont exprimées en repère PLACEIT : ce sont
   les chiffres qu'on relève à l'écran, et qu'on peut donc vérifier sans calcul
   mental. La conversion a lieu une seule fois, au dessin, dans versReperePdf().
   Ne JAMAIS mélanger les deux : une valeur reportée sans conversion place le
   texte à l'exact symétrique vertical, souvent hors du cadre.

   Le cadre est décrit comme une BOÎTE (x, y, largeur, hauteur) et non par une
   liste de points : les quatre lignes s'en déduisent par l'interligne. Un
   gabarit qui bouge ne demande alors que de recoller les quatre nombres relevés
   dans PlaceIt, au lieu de repositionner chaque ligne à la main.

   NIF/NIE n'est pas rempli : aucun champ de l'org ne porte cette donnée.
   ─────────────────────────────────────────────────────────────────────────── */

export const PDF_ZONE_CLIENT = {
    page: 0,

    /** Cadre CLIENTE relevé dans PlaceIt — origine en HAUT à gauche. */
    boite: { x: 301, y: 151, largeur: 243, hauteur: 62 },

    /** Retrait du texte à l'intérieur du cadre. `haut` vise la première ligne de base. */
    marge: { gauche: 6, haut: 11 },

    /** Écart entre deux lignes de base. 4 lignes → 11 + 3 × 12,5 = 48,5 pt dans 62. */
    interligne: 12.5,

    taille: 8,
    /** En dessous, on tronque plutôt que de réduire encore : illisible. */
    tailleMin: 6,

    /**
     * Ordre d'impression, tel que demandé par le métier :
     *   1. nom et prénom
     *   2. adresse
     *   3. téléphone
     *   4. email
     * Les clés renvoient à celles produites par le getter `donneesClient` du
     * composant. Ajouter une ligne ici suppose de l'y produire aussi.
     */
    lignes: ['nom', 'adresse', 'telephone', 'email']
};

/**
 * Convertit une ordonnée PlaceIt (origine en HAUT à gauche) vers le repère de
 * pdf-lib (origine en BAS à gauche).
 *
 * La hauteur est lue sur la page elle-même plutôt qu'écrite en dur : le jour où
 * le gabarit passera en A4 paysage ou en Letter, rien ne bougera ici.
 */
export function versReperePdf(page, yPlaceIt) {
    return page.getHeight() - yPlaceIt;
}

/**
 * Champs qui alimentent la zone CLIENTE, par objet.
 * Plusieurs noms d'API = valeurs concaténées par une espace.
 */
export const CHAMPS_CLIENT_PDF = {
    Lead: {
        nom: ['FirstName', 'LastName'],
        // Pas d'equivalent sur Pro__c : le Dossier garde Client_Adresse_Chantier__c.
        adresse: ['REGIE_Adresse_Client__c'],
        telephone: ['Phone'],
        email: ['Email']
    },
    'Pro__c': {
        nom: ['PRO_Pr_nom_du_Signataire__c'],
        adresse: ['Client_Adresse_Chantier__c'],
        telephone: ['Phone__c'],
        email: ['Email__c']
    }
};

/* ───────────────────────────────────────────────────────────────────────────
   NUMÉRO DE DEVIS

   Le gabarit imprime déjà « HP-2026- » en tête des pages 1 et 2 ; on ne dessine
   que les chiffres qui suivent. Repère PLACEIT (origine en HAUT à gauche) comme
   toutes les coordonnées de ce fichier — conversion au tracé par versReperePdf().

   Ces coordonnées vivent ICI et non dans un Custom Label, contrairement à celles
   de la signature Yousign : tout ce que pdf-lib dessine est groupé dans ce
   fichier, et les disperser rendrait le réglage plus difficile à relire. Les
   changer demande donc un déploiement.

   Relevé PlaceIt, identique sur les deux pages :
       page 1 et 2 — x 516, y 64, cadre de 43 × 14.

   ⚠️ PlaceIt donne le HAUT du cadre ; `drawText` attend la LIGNE DE BASE. Les
   deux ne se confondent pas : reporter 64 tel quel poserait le texte au-dessus
   du cadre, à cheval sur le titre. On descend donc d'environ une hauteur de
   capitale — d'où `ligneDeBase` calculé plutôt qu'écrit en dur, pour que
   changer `taille` reste sans surprise.
   ─────────────────────────────────────────────────────────────────────────── */

export const PDF_NUMERO_DEVIS = {
    /** Le gabarit imprime « HP-2026- » en gras d'environ cette taille. */
    taille: 10,

    /** Cadre relevé dans PlaceIt : origine en HAUT à gauche. */
    emplacements: [
        // `page` est l'index pdf-lib : 0 = première page (PlaceIt compte à partir de 1).
        { page: 0, x: 516, y: 63, hauteur: 14 },
        { page: 1, x: 516, y: 63, hauteur: 14 }
    ]
};

/**
 * Ligne de base d'un texte centré verticalement dans un cadre PlaceIt.
 *
 * Approximation volontairement simple : la hauteur de capitale d'Helvetica vaut
 * environ 0,72 em. Le résultat reste en repère PlaceIt — la conversion vers
 * pdf-lib se fait après, comme partout ailleurs.
 */
export function ligneDeBase(emplacement, taille) {
    const hauteur = emplacement.hauteur || taille;
    return emplacement.y + (hauteur + taille * 0.72) / 2;
}

/** Page portant les cases (0 = première page). */
export const PDF_PAGE_CASES = 0;

/**
 * Coin HAUT-GAUCHE de chaque case a cocher.
 *
 * REPERE PLACEIT (origine en HAUT a gauche), comme les coordonnees Yousign et
 * comme on lit la page. La conversion vers le repere de pdf-lib (origine en BAS
 * a gauche) se fait au dessin, via versReperePdf() : une seule regle, un seul
 * endroit, et des valeurs qu'on peut relire directement dans PlaceIt.
 */
export const PDF_CASES_PUISSANCE = {
    12: { x: 84,  y: 317 },
    14: { x: 122, y: 317 },
    16: { x: 160, y: 317 }
};

/**
 * Hauteur de la bande « [ ] 12 kW [ ] 14 kW [ ] 16 kW », relevee dans PlaceIt :
 * x 84, y 317, largeur 84, hauteur 7. Les trois cases se partagent cette bande,
 * espacees de 38 points.
 *
 * Le trace de la coche est exprime en fraction de cette hauteur plutot qu'en
 * points absolus : ajuster la bande suffit alors a replacer la coche, sans
 * avoir a recalculer trois paires de coordonnees a la main.
 */
export const PDF_HAUTEUR_CASE = 7;

/**
 * Tracé de la coche, relatif au coin haut-gauche de la case, y vers le BAS.
 * Trois points = deux segments : la descente courte puis la remontée longue.
 *
 * VOLONTAIREMENT PLUS GRANDE QUE LA CASE IMPRIMÉE. Le carré du document ne fait
 * que 4,1 × 4,2 pt : une coche stricement contenue dedans, en trait fin, passait
 * inaperçue à l'impression comme à l'écran — or c'est elle qui porte la
 * puissance retenue, l'information la plus engageante du devis. La remontée
 * dépasse donc légèrement en haut à droite, comme une coche tracée à la main.
 *
 * Pour l'agrandir ou la réduire encore, jouer sur ces trois points ET sur
 * l'épaisseur : les deux se voient autant l'un que l'autre.
 */
export const PDF_TRACE_COCHE = [
    { dx: 0.9, dy: 3.4 },
    { dx: 2.3, dy: 5.4 },
    { dx: 5.4, dy: 1.0 }
];

/** Épaisseur du trait, en points. Doublée : 0,55 pt ne se voyait pas. */
export const PDF_EPAISSEUR_COCHE = 1.1;

/** Encre de la coche (0–1 par composante) — bleu nuit, lisible à l'impression. */
export const PDF_COULEUR_COCHE = { r: 0.09, g: 0.13, b: 0.35 };

/* ═══════════════════════════════════════════════════════════════════════════
   CALCULS DÉCLARÉS PAR LA FICHE

   Un gabarit imprime des valeurs qui ne sont dans aucun champ : un nombre de
   capteurs déduit d'une surface, un modèle de pompe déduit d'une puissance…
   Les RÈGLES vivent dans le catalogue (c/lwc000_utils, `signature.calculs`),
   à côté du gabarit qu'elles servent ; ici ne vit que l'ÉVALUATION, générique.

   Deux formes de règle :
     • tranches — { champ, tranches: [{ min, max | maxExclu, valeur }] } : la
       valeur de la première tranche contenant le champ. `min` et `max` sont
       INCLUS ; `maxExclu` ne l'est pas — c'est lui qu'il faut pour des tranches
       jointives (18 à 24, 24 à 33…), sans quoi une surface de 23,5 tomberait
       dans le trou entre « jusqu'à 23 » et « à partir de 24 ».
       `choix` (facultatif) nomme un champ dont la valeur, si elle est
       renseignée, PRIME sur la tranche : c'est ce que l'utilisateur a retenu.
     • table    — { selon, table: { cle: valeur } } : la valeur associée au
       résultat d'un autre calcul.

   Un calcul sans résultat est HORS CIBLE : la surface ne tombe dans aucune
   tranche. Le document ne se fabrique pas — un devis avec un blanc à la place
   du modèle ne vaut rien, et en produire un ferait croire qu'il est complet.
   ─────────────────────────────────────────────────────────────────────────── */

/**
 * Évalue les calculs d'une fiche à partir des valeurs de l'enregistrement.
 *
 * @param {Object} calculs   `signature.calculs` de la fiche, ou null.
 * @param {Object} valeurs   valeurs par nom d'API, brouillon compris.
 * @returns {{ valeurs: Object, recommandations: Object, horsCible: Array<string> }}
 *          `valeurs` : le résultat retenu (choix de l'utilisateur ou tranche) ;
 *          `recommandations` : ce que la tranche seule aurait donné — ce qu'on
 *          propose par défaut dans la liste, avant que l'utilisateur ne tranche ;
 *          `horsCible` : les calculs restés sans résultat.
 */
export function evaluerCalculs(calculs, valeurs) {
    const resultat = { valeurs: {}, recommandations: {}, horsCible: [] };
    if (!calculs) return resultat;
    const lues = valeurs || {};

    const nombre = (v) => {
        if (v === null || v === undefined || String(v).trim() === '') return null;
        const n = Number(String(v).replace(',', '.'));
        return Number.isFinite(n) ? n : null;
    };
    const parTranche = (regle) => {
        const n = nombre(lues[regle.champ]);
        if (n === null) return null;
        const t = (regle.tranches || []).find((tr) =>
            (tr.min === null || tr.min === undefined || n >= tr.min)
            && (tr.max === null || tr.max === undefined || n <= tr.max)
            && (tr.maxExclu === null || tr.maxExclu === undefined || n < tr.maxExclu));
        return t ? t.valeur : null;
    };

    // Deux passes : les tranches d'abord, les tables ensuite — une table ne
    // peut dépendre que d'un calcul déjà résolu.
    const noms = Object.keys(calculs);
    noms.filter((n) => calculs[n].tranches).forEach((n) => {
        const regle = calculs[n];
        const recommande = parTranche(regle);
        resultat.recommandations[n] = recommande;
        const choisi = regle.choix ? lues[regle.choix] : null;
        const retenu = (choisi !== null && choisi !== undefined && String(choisi).trim() !== '')
            ? String(choisi).trim()
            : recommande;
        resultat.valeurs[n] = retenu;
        if (retenu === null || retenu === undefined) resultat.horsCible.push(n);
    });
    noms.filter((n) => calculs[n].table).forEach((n) => {
        const regle = calculs[n];
        const cle = resultat.valeurs[regle.selon];
        const v = (cle === null || cle === undefined) ? null : regle.table[String(cle)];
        resultat.valeurs[n] = v === undefined ? null : v;
        resultat.recommandations[n] = resultat.valeurs[n];
        if (resultat.valeurs[n] === null) resultat.horsCible.push(n);
    });
    return resultat;
}

/**
 * Mise en page de REPLI — celle du gabarit historique (RES060).
 *
 * Chaque devis d'une fiche declare desormais la sienne dans c/lwc000_utils :
 * un gabarit n'a pas les memes cadres qu'un autre, et ces valeurs sont donc de
 * la donnee de fiche, pas une constante du composant. Ce repli ne sert qu'a un
 * devis qui n'en declarerait aucune — l'ecran continue alors de fonctionner
 * comme avant plutot que de rendre un document vierge.
 *
 * `casesPuissance` est FACULTATIF : seul un gabarit qui imprime la bande
 * « 12 / 14 / 16 kW » en a besoin. Une fiche sans cases produit quand meme son
 * document — cadre client et numero — au lieu de ne rien produire.
 */
export const MISE_EN_PAGE_DEFAUT = {
    zoneClient: PDF_ZONE_CLIENT,
    numeroDevis: PDF_NUMERO_DEVIS,
    casesPuissance: { page: PDF_PAGE_CASES, cases: PDF_CASES_PUISSANCE }
};

/**
 * Décode le base64 renvoyé par LC021_DevisSignature.getContratBase64 en octets.
 *
 * Le PDF n'est PAS téléchargé par fetch() : dans le site Campagnes, Lightning
 * Web Security refuse tout fetch vers l'URL du Static Resource (« Cannot request
 * disallowed endpoint …/resource/… », constaté en sandbox). Les octets passent
 * donc par un appel Apex — canal autorisé — et arrivent ici en base64.
 */
export function octetsVersBase64(octets) {
    let binaire = '';
    const BLOC = 0x8000; // String.fromCharCode plafonne sur le nombre d'arguments
    for (let i = 0; i < octets.length; i += BLOC) {
        binaire += String.fromCharCode.apply(null, octets.subarray(i, i + BLOC));
    }
    return btoa(binaire);
}

export function base64VersOctets(base64) {
    if (!base64) throw new Error('document vide reçu du serveur');
    const binaire = atob(base64);
    const octets = new Uint8Array(binaire.length);
    for (let i = 0; i < binaire.length; i++) {
        octets[i] = binaire.charCodeAt(i);
    }
    return octets;
}

/**
 * Réduit la taille de police jusqu'à ce que le texte tienne, puis tronque.
 * Renvoie null si rien à écrire.
 */
function ajusterTexte(texte, police, largeurMax, taille, tailleMin) {
    let t = String(texte == null ? '' : texte).trim();
    if (!t) return null;

    let taillePolice = taille;
    while (taillePolice > tailleMin && police.widthOfTextAtSize(t, taillePolice) > largeurMax) {
        taillePolice -= 0.5;
    }
    // Toujours trop long à la taille plancher : on coupe plutôt que de déborder
    // du cadre sur la colonne voisine.
    while (t.length > 1 && police.widthOfTextAtSize(t, taillePolice) > largeurMax) {
        t = t.slice(0, -1);
    }
    return { texte: t, taille: taillePolice };
}

/**
 * Reporte les coordonnées du client dans le cadre « CLIENTE » de la page 1.
 *
 * Silencieux si `client` est absent : le document reste alors celui d'avant,
 * avec ses lignes vierges — un devis sans nom vaut mieux qu'une exception qui
 * priverait l'utilisateur de tout aperçu.
 */
async function ecrireZoneClient(pdf, pages, pdfLib, client, zone) {
    if (!client || !zone) return;

    const z = zone;
    // La page est celle du CADRE, pas celle des cases : les deux coincident sur
    // le gabarit historique, rien ne dit qu'elles coincideront sur le suivant.
    const page = pages[z.page || 0];
    if (!page) return;
    const police = await pdf.embedFont(pdfLib.StandardFonts.Helvetica);
    const encre = pdfLib.rgb(0.09, 0.13, 0.35);

    const x = z.boite.x + z.marge.gauche;
    // Marge symétrique à droite : le texte ne touche jamais le filet du cadre.
    const largeurMax = z.boite.largeur - 2 * z.marge.gauche;

    z.lignes.forEach((cle, rang) => {
        const valeur = client[cle];
        // Une donnée absente laisse sa ligne vide plutôt que de décaler les
        // suivantes : le cadre imprimé garde ainsi sa mise en page.
        if (!valeur || !String(valeur).trim()) return;

        const ajuste = ajusterTexte(String(valeur).trim(), police, largeurMax,
                                    z.taille, z.tailleMin);
        if (!ajuste) return;

        const yPlaceIt = z.boite.y + z.marge.haut + rang * z.interligne;
        page.drawText(ajuste.texte, {
            x,
            y: versReperePdf(page, yPlaceIt),
            size: ajuste.taille,
            font: police,
            color: encre
        });
    });
}

/**
 * Recouvre des zones du gabarit d'un rectangle plein (`pdf.masques`).
 *
 * Sert à EFFACER ce que le gabarit imprime et qu'on ne veut plus voir — les
 * soulignements « ____ » sous les valeurs, par exemple. Le gabarit est un PDF
 * aplati : on ne peut pas y supprimer un trait, seulement le recouvrir d'un
 * rectangle à la couleur exacte du fond.
 *
 * Chaque masque : { page, x, y, largeur, hauteur, couleur } — repère PlaceIt
 * (origine en haut à gauche), `couleur` en '#rrggbb' (blanc à défaut).
 *
 * ⚠️ À appeler AVANT ecrireTextes : pdf-lib empile dans l'ordre des appels, et
 * un masque posé après recouvrirait la valeur qu'il est censé dégager.
 */
function poserMasques(pages, pdfLib, masques) {
    if (!Array.isArray(masques)) return;
    masques.forEach((m) => {
        const page = pages[m.page || 0];
        if (!page) return;
        const c = /^#?([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/i.exec(m.couleur || '#ffffff');
        page.drawRectangle({
            x: m.x,
            // Le rectangle se décrit par son coin BAS-gauche en repère pdf-lib.
            y: versReperePdf(page, m.y + m.hauteur),
            width: m.largeur,
            height: m.hauteur,
            color: pdfLib.rgb(parseInt(c[1], 16) / 255, parseInt(c[2], 16) / 255, parseInt(c[3], 16) / 255),
            borderWidth: 0
        });
    });
}

/**
 * Pose sur le document les textes déclarés par la fiche (`pdf.textes`).
 *
 * Chaque entrée dit QUOI, par une seule des clés :
 *   • champ   — un champ de l'enregistrement ; une chaîne, ou { Lead, 'Pro__c' }
 *               quand le nom diffère selon l'objet ;
 *   • calcul  — un résultat de evaluerCalculs() ;
 *   • source  — 'numeroDevis' | 'recordId' | 'dateDuJour' ;
 *   • texte   — une constante, imprimée telle quelle.
 *
 * OÙ — `page` (index pdf-lib, 0 = première page), `x`, et la position verticale
 * sous l'une de ces deux formes, en repère PlaceIt (origine en haut à gauche) :
 *   • base        — la LIGNE DE BASE elle-même. C'est la forme à préférer pour
 *                   une valeur voisine d'un libellé : on reporte la ligne de
 *                   base du libellé, et les deux textes sont alignés au point
 *                   près, quelle que soit la taille ;
 *   • y + hauteur — un cadre relevé dans PlaceIt, où le texte est centré.
 *
 * COMMENT — `taille`, `gras`, `couleur` ('#rrggbb'), avec pour défaut ceux de
 * `pdf.styleTextes` ; `aligne: 'droite'` fait de `x` le bord DROIT du texte
 * (une valeur collée à son unité : « 12 kW », « 10 capteurs ») ; `largeur`
 * active le retour à la ligne, sur `lignesMax` lignes espacées de `interligne`.
 *
 * Une valeur absente laisse son emplacement vide plutôt que d'écrire « null » :
 * un blanc se voit et se corrige, un « undefined » imprimé passe pour du texte.
 */
async function ecrireTextes(pdf, pages, pdfLib, textes, contexte, style) {
    if (!Array.isArray(textes) || textes.length === 0 || !contexte) return;

    const normale = await pdf.embedFont(pdfLib.StandardFonts.Helvetica);
    const grasse = await pdf.embedFont(pdfLib.StandardFonts.HelveticaBold);
    const defaut = style || {};
    // Encre historique — le bleu nuit des gabarits RES060 — si rien n'est dit.
    const encre = (hex) => {
        const m = /^#?([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/i.exec(hex || '');
        return m
            ? pdfLib.rgb(parseInt(m[1], 16) / 255, parseInt(m[2], 16) / 255, parseInt(m[3], 16) / 255)
            : pdfLib.rgb(0.09, 0.13, 0.35);
    };

    textes.forEach((t) => {
        const page = pages[t.page || 0];
        if (!page) return;
        const valeur = valeurDuTexte(t, contexte);
        if (valeur === null || valeur === undefined || String(valeur).trim() === '') return;

        const taille = t.taille || defaut.taille || 9;
        const gras = t.gras !== undefined ? t.gras : defaut.gras === true;
        const police = gras ? grasse : normale;
        const couleur = encre(t.couleur || defaut.couleur);
        const base = (t.base !== undefined && t.base !== null) ? t.base : ligneDeBase(t, taille);

        const lignes = t.largeur
            ? couperEnLignes(String(valeur), police, taille, t.largeur, t.lignesMax || 1)
            : [String(valeur).trim()];

        lignes.forEach((ligne, rang) => {
            const x = t.aligne === 'droite'
                ? t.x - police.widthOfTextAtSize(ligne, taille)
                : t.x;
            page.drawText(ligne, {
                x,
                y: versReperePdf(page, base + rang * (t.interligne || taille * 1.35)),
                size: taille,
                font: police,
                color: couleur
            });
        });
    });
}

/**
 * Coupe un texte en lignes tenant dans `largeur`, mot par mot.
 *
 * Les retours à la ligne saisis sont respectés. Au-delà de `lignesMax`, la
 * dernière ligne est tronquée et terminée par « … » : une adresse qui déborde
 * du cadre passerait sur le bloc voisin, et une coupe visible vaut mieux
 * qu'un chevauchement illisible.
 */
export function couperEnLignes(texte, police, taille, largeur, lignesMax) {
    const mesure = (t) => police.widthOfTextAtSize(t, taille);
    const lignes = [];
    String(texte).split(/\r?\n/).forEach((paragraphe) => {
        let courante = '';
        paragraphe.split(/\s+/).filter(Boolean).forEach((mot) => {
            const essai = courante ? courante + ' ' + mot : mot;
            if (!courante || mesure(essai) <= largeur) {
                courante = essai;
            } else {
                lignes.push(courante);
                courante = mot;
            }
        });
        if (courante) lignes.push(courante);
    });
    if (lignes.length <= lignesMax) return lignes;

    const gardees = lignes.slice(0, lignesMax);
    let derniere = gardees[lignesMax - 1] + ' ' + lignes.slice(lignesMax).join(' ');
    while (derniere.length > 1 && mesure(derniere + '…') > largeur) {
        derniere = derniere.slice(0, -1);
    }
    gardees[lignesMax - 1] = derniere.trim() + '…';
    return gardees;
}

/** Résout la valeur d'une entrée de `pdf.textes` — voir ecrireTextes(). */
export function valeurDuTexte(t, contexte) {
    if (!t || !contexte) return null;
    if (t.texte !== undefined) return t.texte;
    if (t.source) return contexte[t.source];
    if (t.calcul) return (contexte.calculs || {})[t.calcul];
    if (t.champ) {
        const api = typeof t.champ === 'string' ? t.champ : t.champ[contexte.objectType];
        return api ? (contexte.champs || {})[api] : null;
    }
    return null;
}

/**
 * Imprime le numéro du devis sur les pages qui l'attendent.
 *
 * Silencieux si le numéro est absent : un document sans numéro vaut mieux qu'un
 * aperçu impossible à ouvrir. Silencieux aussi si une page manque — le gabarit
 * peut changer de pagination sans que cette fonction ait à le savoir.
 */
async function ecrireNumeroDevis(pdf, pages, pdfLib, numero, conf) {
    // `conf` absent : le gabarit n'imprime pas de numero. Ce n'est pas une
    // anomalie — toutes les fiches n'en portent pas.
    if (!conf || !numero || !String(numero).trim()) return;
    const police = await pdf.embedFont(pdfLib.StandardFonts.HelveticaBold);
    const encre = pdfLib.rgb(0.09, 0.13, 0.35);
    const texte = String(numero).trim();

    conf.emplacements.forEach((emplacement) => {
        const page = pages[emplacement.page];
        if (!page) return;
        page.drawText(texte, {
            x: emplacement.x,
            y: versReperePdf(page, ligneDeBase(emplacement, conf.taille)),
            size: conf.taille,
            font: police,
            color: encre
        });
    });
}

/**
 * Produit un PDF dont la case de la puissance retenue est cochée.
 *
 * @param {Uint8Array} octets      Le contrat brut — voir base64VersOctets().
 * @param {number|null} puissance  12, 14, 16 — ou null (hors cible / surface absente).
 * @param {object} pdfLib          Le global `PDFLib`, chargé par le composant.
 * @returns {Promise<{url:string|null, coche:boolean, base64:string|null, octets:Uint8Array|null}>}
 *          `base64` : le fichier coché, prêt à être JOINT au record par
 *          LC021_DevisSignature.enregistrerContrat. `octets` : le même contenu
 *          brut, rendu sur canvas par pdf.js — trois formes d'un seul fichier.
 *
 * Hors cible (`puissance` nulle) : renvoie `url: null` avec `coche: false` —
 * comportement normal, il n'y a aucune case à cocher, l'appelant affiche la
 * ressource statique brute.
 *
 * Tout AUTRE empêchement lève une exception portant l'étape fautive. C'est
 * volontaire : sur un document contractuel, un PDF non coché ne doit jamais
 * passer pour un PDF coché. C'est l'appelant qui décide d'afficher le document
 * nu accompagné de l'avertissement.
 */
export async function appliquerPuissanceSurPdf(octets, puissance, pdfLib, client,
                                               numeroDevis, miseEnPage, contexte) {
    const plan = miseEnPage || MISE_EN_PAGE_DEFAUT;
    const cases = plan.casesPuissance;
    const cible = cases ? (cases.cases || {})[puissance] : null;

    // Deux situations bien distinctes, longtemps confondues :
    //   • le gabarit PORTE des cases mais aucune puissance n'est retenue —
    //     hors cible, il n'y a rien a produire, comportement historique ;
    //   • le gabarit N'EN PORTE PAS (fiche solaire, par exemple) — il faut
    //     produire le document quand meme, avec son cadre client et son
    //     numero. Le premier code retournait ici et ne generait jamais rien.
    if (cases && !cible) return { url: null, coche: false, base64: null, octets: null };

    if (!octets || !octets.length) {
        throw new Error('octets du contrat manquants');
    }
    // Un échec silencieux rendrait le PDF non coché indiscernable d'un PDF
    // coché : précisément ce qu'il ne faut pas sur un document contractuel.
    if (!pdfLib || !pdfLib.PDFDocument) {
        throw new Error('pdf-lib indisponible (window.PDFLib absent après loadScript)');
    }

    const pdf = await pdfLib.PDFDocument.load(octets);
    const pages = pdf.getPages();

    if (cible) {
        const indexPage = cases.page || 0;
        const page = pages[indexPage];
        if (!page) {
            throw new Error('page ' + indexPage + ' absente du document');
        }

        const couleur = pdfLib.rgb(PDF_COULEUR_COCHE.r, PDF_COULEUR_COCHE.g, PDF_COULEUR_COCHE.b);
        // Bouts et jointures arrondis : un trait à angle vif laisse une pointe qui
        // déborde du carré imprimé à ce niveau de zoom.
        const bout = pdfLib.LineCapStyle ? pdfLib.LineCapStyle.Round : undefined;

        // La case est reperee en PlaceIt (y vers le bas), le trace aussi : une
        // seule conversion suffit, ici, au moment de dessiner.
        const hautCase = versReperePdf(page, cible.y);
        const points = PDF_TRACE_COCHE.map((p) => ({
            x: cible.x + p.dx,
            y: hautCase - p.dy
        }));

        for (let i = 0; i < points.length - 1; i++) {
            page.drawLine({
                start: points[i],
                end: points[i + 1],
                thickness: PDF_EPAISSEUR_COCHE,
                color: couleur,
                lineCap: bout
            });
        }
    }

    poserMasques(pages, pdfLib, plan.masques);
    await ecrireZoneClient(pdf, pages, pdfLib, client, plan.zoneClient);
    await ecrireNumeroDevis(pdf, pages, pdfLib, numeroDevis, plan.numeroDevis);
    await ecrireTextes(pdf, pages, pdfLib, plan.textes, contexte, plan.styleTextes);

    const resultat = await pdf.save();

    let url;
    try {
        const blob = new Blob([resultat], { type: 'application/pdf' });
        url = URL.createObjectURL(blob);
    } catch (e) {
        throw new Error('création du blob impossible : ' + (e.message || e));
    }
    return { url, coche: true, base64: octetsVersBase64(resultat), octets: resultat };
}