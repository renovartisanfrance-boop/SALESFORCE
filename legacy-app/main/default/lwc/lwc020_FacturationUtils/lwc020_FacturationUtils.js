/**
 * Module de service partagé par les onglets de facturation du portail.
 *
 * Regroupe ce qui doit rester IDENTIQUE entre « En cours » et « Payées » :
 * la configuration des colonnes, la construction des métadonnées envoyées à l'Apex,
 * et la normalisation d'une facture en ligne affichable.
 *
 * Même motif que lwc022FormulaUtils : module JS pur, sans template, non exposé.
 */

// Clé localStorage du token de campagne — IDENTIQUE à lwc020_reporting_v2.
// Ne pas la changer sans changer l'autre : c'est le même token qui circule.
export const TOKEN_STORAGE_KEY = 'renov_campaign_token';

/** Affiché à la place d'une valeur vide, dans toutes les colonnes. */
export const VIDE = '—';

/** N° de facture d'un dossier dont la facture n'est pas encore émise. */
export const REPLI_NUMERO = '🕛Att. facture';

/** Date de paiement prévue inconnue (pas de facture, ou facture sans échéance). */
export const REPLI_PREVU = '🕛En Att';

/**
 * Point d'arrêt « téléphone », en pixels.
 *
 * ⚠️ Doit rester IDENTIQUE au `@media (max-width: …)` de lwc020_FacturationTable.css.
 * En dessous, la table ne fige plus que le nom du dossier et le remonte en première
 * colonne : un bloc de trois colonnes gelées mangerait la quasi-totalité d'un écran
 * de téléphone et il ne resterait rien à faire défiler. Le réordonnancement des
 * colonnes ne peut pas se faire en CSS sur un <table>, il passe donc par le JS —
 * d'où cette valeur partagée entre les deux fichiers.
 */
export const SEUIL_MOBILE = 640;

/* ═══════════════════════════════════════════════════════════════════════════
   CONFIGURATION DES COLONNES

   C'est le SEUL endroit à modifier pour ajouter / retirer / réordonner une
   colonne. L'ordre du tableau EST l'ordre d'affichage, l'ordre des en-têtes et
   l'ordre des champs de filtre — il n'y a plus qu'une seule liste à tenir.

   `scope`    : 'F' = champ de la FACTURE, fusionné en rowspan sur toutes ses
                lignes de dossier. 'D' = champ de la LIGNE, rendu à chaque ligne.
                Les deux familles peuvent s'entrelacer librement (F,F,D,D,F,F,D,D
                ci-dessous) : les cellules sont émises dans l'ordre de cette liste
                et l'algorithme de placement des tableaux HTML fait le reste.
   `field`    : nom d'API, envoyé à l'Apex qui construit la SOQL. Plusieurs séparés
                par une virgule = « premier non vide gagne ». Chemin pointé accepté
                sur un niveau de relation (ex. 'Dossier__r.Name').
   `type`     : 'text' (défaut) | 'date' | 'currency' | 'prevu'
   `sticky`   : 1 | 2 | 3 — rang de la colonne dans le bloc figé à gauche. Les
                colonnes figées doivent être les PREMIÈRES de la liste et se
                suivre, sinon les décalages `left` du CSS ne correspondent plus.
                Leur LARGEUR est fixée dans le CSS (--w1/--w2/--w3) et non ici :
                le décalage `left` de la suivante en dérive, les deux ne peuvent
                pas diverger.
   `largeur`  : largeur en pixels, pour les colonnes NON figées uniquement (le
                tableau est en table-layout: fixed).
   `filtre`   : true = un champ de filtre dédié lui est généré.
   `repli`    : texte affiché quand la valeur est vide (sinon VIDE).
   ═══════════════════════════════════════════════════════════════════════════ */

/**
 * Onglet « En cours » — table UNIQUE mêlant deux origines :
 *   • les dossiers dont l'échéance est atteinte et la facture pas encore créée
 *     (catalogue tarifaire, via getLignesAFacturer) ;
 *   • les factures créées mais non réglées (Brouillon comme Validé).
 *
 * Les colonnes de facture sont donc vides sur les premiers, d'où les replis :
 * « Att. réception facture » et « 🕛En Att ».
 */
export const COLONNES_EN_COURS = [
    { key: 'numero',  label: 'N° Facture',     scope: 'F', field: 'N_Facture_Externe__c,Name', sticky: 1, filtre: true, repli: REPLI_NUMERO },
    { key: 'prevu',   label: 'Paiement prévu', scope: 'F', field: 'DateEcheance__c',      type: 'prevu',    sticky: 2, filtre: true },
    { key: 'dossier', label: 'Nom',            scope: 'D', field: 'Dossier__r.Name',                        sticky: 3, filtre: true },
    { key: 'montant', label: 'Montant HT',     scope: 'D', field: 'Montant_HT__c',        type: 'currency', largeur: 96 },
    { key: 'ttc',     label: 'Total TTC',      scope: 'F', field: 'Montant_Total__c',     type: 'currency', largeur: 100, filtre: true },
    { key: 'date',    label: 'Date facture',   scope: 'F', field: 'DateFacture__c',       type: 'date',     largeur: 94,  filtre: true },
    { key: 'ech',     label: 'Échéance',       scope: 'D', field: 'Echeance_Declenchante__c',               largeur: 136 },
    { key: 'fiche',   label: 'Fiche',          scope: 'D', field: 'Dossier__r.Fiche_CEE__c',                largeur: 170, filtre: true }
];

/**
 * Onglet « Payées ».
 *
 * Même grille que « En cours », à deux colonnes près : « Paiement prévu » cède la
 * place à « Payé le » (la date réelle, plus l'estimation), et tout est renseigné
 * puisqu'il n'y a ici que de vraies factures.
 */
export const COLONNES_PAYEES = [
    { key: 'numero',  label: 'N° Facture',   scope: 'F', field: 'N_Facture_Externe__c,Name', sticky: 1, filtre: true },
    { key: 'paye',    label: 'Payé le',      scope: 'F', field: 'Date_Paiement__c',   type: 'date',     sticky: 2, filtre: true },
    { key: 'dossier', label: 'Nom',          scope: 'D', field: 'Dossier__r.Name',                      sticky: 3, filtre: true },
    { key: 'montant', label: 'Montant HT',   scope: 'D', field: 'Montant_HT__c',      type: 'currency', largeur: 96 },
    { key: 'ttc',     label: 'Total TTC',    scope: 'F', field: 'Montant_Total__c',   type: 'currency', largeur: 100, filtre: true },
    { key: 'date',    label: 'Date facture', scope: 'F', field: 'DateFacture__c',     type: 'date',     largeur: 94,  filtre: true },
    { key: 'ech',     label: 'Échéance',     scope: 'D', field: 'Echeance_Declenchante__c',             largeur: 136 },
    { key: 'fiche',   label: 'Fiche',        scope: 'D', field: 'Dossier__r.Fiche_CEE__c',              largeur: 170, filtre: true }
];

/** Statut de paiement affiché en badge dans la vue partenaire. */
export const STATUT_PAYEE = 'Payée';
export const STATUT_IMPAYEE = 'En attente de paiement';

/**
 * Vue PARTENAIRE (campagnes en accès réduit).
 *
 * Un seul tableau, sans onglet ni filtre, qui réunit ce que les deux onglets
 * séparent : dossiers prêts à facturer, factures impayées et factures réglées.
 * La colonne « Paiement » est ce qui les distingue — « Pas payée » couvre à la
 * fois le pas-encore-facturé et le facturé-pas-encore-réglé, « Payée » ne couvre
 * que le réglé.
 *
 * Aucune colonne n'est déclarée `filtre`, ce qui fait disparaître tout le bloc de
 * filtres — accordéon compris.
 */
export const COLONNES_PARTENAIRE = [
    { key: 'install', label: 'Date installation', scope: 'D', field: 'Dossier__r.PAC_Date_d_Installation__c', type: 'date', largeur: 122 },
    { key: 'dossier', label: 'Nom',               scope: 'D', field: 'Dossier__r.Name', gras: true, ancreMobile: true, largeur: 190 },
    { key: 'statut',  label: 'Paiement',          scope: 'F', computed: 'statutPaiement', type: 'badge', largeur: 112 },
    { key: 'montant', label: 'Montant HT',        scope: 'D', field: 'Montant_HT__c', type: 'currency', largeur: 106 },
    { key: 'ttc',     label: 'Total TTC',         scope: 'F', field: 'Montant_Total__c', type: 'currency', largeur: 112 }
];

export const EURO = new Intl.NumberFormat('fr-FR', {
    style: 'currency',
    currency: 'EUR',
    minimumFractionDigits: 2,
    maximumFractionDigits: 2
});

/** Token de campagne, lu défensivement (localStorage peut lever en navigation privée). */
export function lireToken() {
    try {
        return localStorage.getItem(TOKEN_STORAGE_KEY);
    } catch (e) {
        return null;
    }
}

/**
 * Aplatit les colonnes d'un périmètre ('F' ou 'D') en liste de noms d'API pour
 * l'Apex. Les doublons sont éliminés ; l'Apex ajoute de son côté les champs qu'il
 * lui faut (Id, Statut__c, Montant_Total__c, DateEcheance__c, Facture__c).
 */
export function champsDe(colonnes, scope) {
    const set = new Set();
    (colonnes || []).forEach((col) => {
        if (col.scope !== scope) return;
        if (!col.field || col.field === '-') return;
        col.field.split(',').forEach((f) => {
            const clean = f.trim();
            if (clean) set.add(clean);
        });
    });
    return [...set].join(',');
}

export function construireMetadata(colonnes, campaignCode, recordId) {
    return {
        champsFacture: champsDe(colonnes, 'F'),
        champsLigne: champsDe(colonnes, 'D'),
        campaignCode: campaignCode || '',
        compteIdContexte: recordId || ''
    };
}

/** « premier non vide gagne » sur un spec multi-champs. */
export function val(champs, spec) {
    if (!spec || spec === '-') return null;
    const noms = spec.split(',');
    for (let i = 0; i < noms.length; i++) {
        const v = champs[noms[i].trim()];
        if (v !== null && v !== undefined && v !== '') return v;
    }
    return null;
}

/** 'YYYY-MM-DD' -> 'DD/MM/YYYY', sans passer par new Date() qui décalerait
 *  d'un jour selon le fuseau du navigateur. */
function formaterDate(valeur) {
    const s = String(valeur);
    const m = s.match(/^(\d{4})-(\d{2})-(\d{2})/);
    return m ? `${m[3]}/${m[2]}/${m[1]}` : s;
}

export function formater(valeur, col) {
    const type = col && col.type;
    const vide = (col && col.repli) || VIDE;
    const estVide = valeur === null || valeur === undefined || valeur === '';

    // « Paiement prévu » : la date d'échéance de la facture, ou l'attente explicite
    // quand la facture n'existe pas encore (ligne du catalogue) ou n'en porte pas.
    // Ne diffère du type 'date' que par ce repli.
    if (type === 'prevu') {
        return estVide ? REPLI_PREVU : formaterDate(valeur);
    }
    if (estVide) return vide;
    if (type === 'currency') {
        const n = Number(valeur);
        return isNaN(n) ? vide : EURO.format(n);
    }
    if (type === 'date') return formaterDate(valeur);
    return String(valeur);
}

export function valeurTri(valeur, col) {
    const type = col && col.type;
    if (valeur === null || valeur === undefined || valeur === '') return '';
    if (type === 'currency') {
        const n = Number(valeur);
        return isNaN(n) ? 0 : n;
    }
    // 'YYYY-MM-DD' se trie en lexicographique — 'prevu' est une date, lui aussi.
    if (type === 'date' || type === 'prevu') return String(valeur);
    return String(valeur).toLowerCase();
}

/**
 * Valeur sur laquelle porte un filtre saisi au clavier.
 *
 * Pour un montant, on compare les CHIFFRES SEULS : « 1 440,00 € » contient une
 * espace insécable et un séparateur décimal virgule, donc un « contient » naïf ne
 * trouverait rien en tapant « 1440 ».
 */
export function valeurFiltre(affiche, col) {
    const s = String(affiche || '');
    return col && col.type === 'currency' ? s.replace(/\D/g, '') : s.toLowerCase();
}

/** Normalise la saisie de l'utilisateur de la même façon que valeurFiltre. */
export function saisieFiltre(saisie, col) {
    const s = String(saisie || '');
    return col && col.type === 'currency' ? s.replace(/\D/g, '') : s.toLowerCase();
}

/**
 * Classe de la cellule, hors mise en page.
 *
 * Les classes de colonne FIGÉE ne sont volontairement PAS posées ici : le rang de
 * figement dépend de la largeur d'écran (sur mobile, seul le nom du dossier reste
 * figé, et il passe en tête), or la normalisation a lieu une fois au chargement.
 * C'est donc la table qui les ajoute au moment du rendu, où elle connaît le point
 * d'arrêt courant.
 */
function classeCellule(col) {
    if (col.type === 'badge') return 'cell-badge';
    const base = col.type === 'currency' ? 'cell-amount' : 'cell-text';
    return col.gras ? base + ' cell-fort' : base;
}

/**
 * Construit une cellule affichable à partir d'une valeur brute.
 * `rowspan` vaut le nombre de lignes de la facture pour une cellule de facture,
 * 1 pour une cellule de dossier.
 */
function cellule(idRow, col, brut, rowspan) {
    const estBadge = col.type === 'badge';
    return {
        key: `${idRow}-${col.key}`,
        value: formater(brut, col),
        cssClass: classeCellule(col),
        rowspan,
        // Le badge est rendu dans un vrai <span> par le template : la couleur de la
        // pastille se décide donc ici, à partir de la valeur brute.
        estBadge,
        badgeClass: estBadge
            ? 'badge-pill badge-pill--' + (brut === STATUT_PAYEE ? 'paye' : 'impaye')
            : ''
    };
}

/**
 * Transforme une facture renvoyée par l'Apex en objet prêt à afficher.
 *
 * Le résultat porte, pour chaque ligne de dossier, la liste ORDONNÉE des cellules
 * à émettre dans le <tr> : sur la première ligne, toutes les colonnes ; sur les
 * suivantes, uniquement les colonnes de dossier — les cellules de facture y sont
 * déjà présentes par la descente du rowspan.
 */
export function normaliserFacture(f, colonnes) {
    const champs = f.champs || {};
    const lignesSrc = f.lignes && f.lignes.length ? f.lignes : [null];
    const nb = lignesSrc.length;

    const sortValues = {};
    const filterValues = {};

    // ── Cellules de facture : calculées une fois, étirées sur toutes les lignes.
    const cellulesFacture = [];
    colonnes.forEach((col) => {
        if (col.scope !== 'F') return;
        // Une colonne « computed » se lit à la RACINE de la facture : sa valeur ne
        // vient pas de la SOQL, donc aucun nom d'API ne transite pour elle.
        const brut = col.computed ? f[col.computed] : val(champs, col.field);
        const c = cellule(f.id, col, brut, nb);
        cellulesFacture.push({ col, cell: c });
        sortValues[col.key] = valeurTri(brut, col);
        filterValues[col.key] = valeurFiltre(c.value, col);
    });

    // ── Cellules de dossier : une série par ligne.
    const lignes = lignesSrc.map((l, i) => {
        const parCle = {};
        const lf = {};
        const ls = {};
        colonnes.forEach((col) => {
            if (col.scope !== 'D') return;
            const brut = l ? val(l, col.field) : null;
            const c = cellule(`${f.id}-l${i}`, col, brut, 1);
            parCle[col.key] = c;
            lf[col.key] = valeurFiltre(c.value, col);
            ls[col.key] = valeurTri(brut, col);
            // Le tri sur une colonne de dossier porte sur la PREMIÈRE ligne de la
            // facture : c'est la seule valeur définie pour un groupe qui en compte
            // plusieurs, et celle que l'utilisateur voit en tête du bloc.
            if (i === 0) sortValues[col.key] = ls[col.key];
        });
        // La valeur de tri est CONSERVÉE par ligne, et pas seulement agrégée sur la
        // première : un filtre de dossier peut retirer la ligne d'index 0, auquel cas
        // le tri doit repartir de la nouvelle tête de bloc — sinon il ordonne sur une
        // valeur qui n'est plus affichée nulle part.
        return { parCle, filterValues: lf, sortValues: ls };
    });

    const cellulesParCle = {};
    cellulesFacture.forEach((x) => {
        cellulesParCle[x.col.key] = x.cell;
    });

    return {
        id: f.id,
        aFacturer: f.aFacturer === true,
        // Montant retenu pour les totaux dynamiques des tuiles.
        montant: Number(f.montantTotal) || 0,
        ligneSupp: f.isSupplementaire === true,
        cellulesFacture: cellulesParCle,
        sortValues,
        filterValues,
        lignes
    };
}

/**
 * Emballe une ligne du catalogue prête à être facturée dans la MÊME forme qu'une
 * facture, pour qu'une table unique puisse afficher les deux origines.
 *
 * Elle n'a évidemment aucun champ de facture : les colonnes correspondantes
 * tomberont sur leurs replis (« Att. réception facture », « 🕛En Att », « — »).
 */
export function ligneAFacturerEnFacture(l, index) {
    return {
        id: `af-${l.key || index}`,
        aFacturer: true,
        isSupplementaire: l.isSupplementaire === true,
        montantTotal: l.montant,
        champs: {},
        // Les clés reprennent EXACTEMENT les `field` des configs de colonnes : c'est
        // ce qui permet à une même colonne de lire indifféremment une ligne de
        // facture renvoyée par la SOQL ou une ligne de catalogue fabriquée ici.
        lignes: [
            {
                'Dossier__r.Name': l.dossierName,
                'Dossier__r.Fiche_CEE__c': l.ficheCee,
                'Dossier__r.PAC_Date_d_Installation__c': l.dateInstallation,
                'Echeance_Declenchante__c': l.echeance,
                'Montant_HT__c': l.montant
            }
        ]
    };
}

/** Message d'erreur lisible à partir d'une erreur Apex. */
export function messageErreur(err) {
    if (!err) return 'Erreur inconnue.';
    if (err.body && err.body.message) return err.body.message;
    if (Array.isArray(err.body)) return err.body.map((e) => e.message).join(', ');
    return err.message || 'Erreur inconnue.';
}