/**
 * Détection des conflits entre règles d'une MÊME ligne de catalogue (decision
 * table évaluée en « première règle qui matche gagne », cf. LC022FacturationCatalogueController).
 *
 * Inspiré de la vérification temps réel des decision tables (DMN « FIRST hit
 * policy », Red Hat/Drools guided decision tables, Sparx EA). On détecte, en
 * fonction des variables de décision sélectionnées, trois anomalies :
 *   - doublon (redundancy)        : deux règles aux conditions identiques ;
 *   - règle inaccessible (subsumption) : une règle ANTÉRIEURE plus générale couvre
 *     entièrement une règle suivante -> cette dernière ne se déclenche jamais ;
 *   - chevauchement partiel (overlap)  : deux règles peuvent s'appliquer au même
 *     dossier (régions qui se recoupent) sans que l'une couvre l'autre.
 *
 * On NE signale PAS le motif « règle spécifique puis règle plus générale »
 * (i ⊂ j avec i avant j) : c'est le motif volontaire « cas particulier d'abord,
 * fourre-tout ensuite », parfaitement valide sous first-match.
 *
 * La détection est PILOTÉE par les variables de décision : sans variable
 * sélectionnée, il n'y a pas de conditions à comparer -> aucun conflit signalé.
 *
 * Cohérence avec le moteur : les dates ET datetimes sont comparées à la JOURNÉE,
 * car la facturation tronque à la date (LC022FacturationCatalogueController.toDate).
 *
 * Détection PUREMENT front (aide à la saisie) : aucune contrainte backend.
 *
 * @param {Array} rules     this.rules : [{ id, conditions: { field: {comparison, value|min|max} } }]
 * @param {Array} variables this.selectedVariables : [{ field, label, type, comparison }]
 * @returns {Array} indexé comme `rules` : [{ hasConflict, level: 'danger'|'warning'|null, message }]
 */
export function detectRuleConflicts(rules, variables) {
    const list = Array.isArray(rules) ? rules : [];
    const vars = Array.isArray(variables) ? variables : [];
    if (!vars.length) {
        return list.map(() => ({ hasConflict: false, level: null, message: '' }));
    }

    const acc = list.map(() => ({ dup: [], shadowedBy: [], shadows: [], overlap: [] }));

    for (let i = 0; i < list.length; i++) {
        for (let j = i + 1; j < list.length; j++) {
            const res = classifyPair(list[i], list[j], vars);
            if (!res) continue;
            if (res.kind === 'duplicate') {
                acc[i].dup.push(String(j + 1));
                acc[j].dup.push(String(i + 1));
            } else if (res.kind === 'shadowed') {
                // i (antérieure) couvre j -> j inaccessible.
                acc[j].shadowedBy.push(partner(i + 1, res.fields));
                acc[i].shadows.push(String(j + 1));
            } else if (res.kind === 'overlap') {
                acc[i].overlap.push(partner(j + 1, res.fields));
                acc[j].overlap.push(partner(i + 1, res.fields));
            }
        }
    }

    return acc.map((x) => buildMessage(x));
}

// « 3 » ou « 3 (Surface, Zone) » selon les variables différenciantes.
function partner(n, fields) {
    return fields && fields.length ? n + ' (' + fields.join(', ') + ')' : String(n);
}

function buildMessage(x) {
    const parts = [];
    let level = null;
    if (x.dup.length) {
        level = 'danger';
        parts.push('Doublon de la règle ' + x.dup.join(', '));
    }
    if (x.shadowedBy.length) {
        level = 'danger';
        parts.push('Inaccessible : déjà couverte par la règle ' + x.shadowedBy.join(', '));
    }
    if (x.shadows.length) {
        level = level || 'warning';
        parts.push('Rend inaccessible la règle ' + x.shadows.join(', '));
    }
    if (x.overlap.length) {
        level = level || 'warning';
        parts.push('Chevauche la règle ' + x.overlap.join(', '));
    }
    return { hasConflict: !!level, level, message: parts.join(' · ') };
}

// Classe une paire (a = règle antérieure, b = règle suivante) :
// { kind: 'duplicate'|'shadowed'|'overlap', fields: [libellés différenciants] } ou null.
function classifyPair(a, b, vars) {
    let intersectAll = true;
    let aSubsumesB = true;
    let bSubsumesA = true;
    const differing = [];
    for (let k = 0; k < vars.length; k++) {
        const v = vars[k];
        const ca = condOf(a, v.field);
        const cb = condOf(b, v.field);
        const inter = intersects(v, ca, cb);
        const ab = subsumes(v, ca, cb);
        const ba = subsumes(v, cb, ca);
        if (!inter) intersectAll = false;
        if (!ab) aSubsumesB = false;
        if (!ba) bSubsumesA = false;
        // Variable « différenciante » : régions qui se recoupent sans être identiques.
        if (inter && !(ab && ba)) differing.push(v.label || v.field);
    }
    if (!intersectAll) return null;
    if (aSubsumesB && bSubsumesA) return { kind: 'duplicate', fields: [] };
    if (aSubsumesB) return { kind: 'shadowed', fields: differing };
    if (bSubsumesA) return null; // b (après) plus générale : motif « spécifique puis fourre-tout »
    return { kind: 'overlap', fields: differing };
}

function condOf(rule, field) {
    return (rule && rule.conditions && rule.conditions[field]) || null;
}

const isBlank = (x) => x === undefined || x === null || x === '';

function exactUnconstrained(c) {
    return !c || isBlank(c.value);
}
function intervalUnconstrained(c) {
    return !c || (isBlank(c.min) && isBlank(c.max));
}

// a ⊇ b : la région de la condition a contient celle de b, pour la variable v.
function subsumes(v, a, b) {
    if (v.type === 'picklist') {
        return regionSubsumes(picklistRegion(a), picklistRegion(b));
    }
    if (v.comparison === 'interval') {
        if (intervalUnconstrained(a)) return true;
        if (intervalUnconstrained(b)) return false;
        const lowOk = isBlank(a.min) || (!isBlank(b.min) && cmp(v.type, a.min, b.min) <= 0);
        const highOk = isBlank(a.max) || (!isBlank(b.max) && cmp(v.type, a.max, b.max) >= 0);
        return lowOk && highOk;
    }
    if (exactUnconstrained(a)) return true;
    if (exactUnconstrained(b)) return false;
    return scalarEqual(v.type, a.value, b.value);
}

// a ∩ b ≠ ∅ : les régions se recoupent, pour la variable v.
function intersects(v, a, b) {
    if (v.type === 'picklist') {
        return regionIntersects(picklistRegion(a), picklistRegion(b));
    }
    if (v.comparison === 'interval') {
        if (intervalUnconstrained(a) || intervalUnconstrained(b)) return true;
        const c1 = isBlank(a.min) || isBlank(b.max) || cmp(v.type, a.min, b.max) <= 0;
        const c2 = isBlank(b.min) || isBlank(a.max) || cmp(v.type, b.min, a.max) <= 0;
        return c1 && c2;
    }
    if (exactUnconstrained(a) || exactUnconstrained(b)) return true;
    return scalarEqual(v.type, a.value, b.value);
}

// Comparaison de deux scalaires selon le type. Renvoie <0 / 0 / >0, ou NaN si
// indéterminé (valeur en cours de saisie non parseable -> on n'alerte pas).
function cmp(type, a, b) {
    if (type === 'number') {
        const na = Number(a);
        const nb = Number(b);
        if (Number.isNaN(na) || Number.isNaN(nb)) return NaN;
        return na - nb;
    }
    if (type === 'date' || type === 'datetime') {
        // Granularité JOUR, comme le moteur (toDate tronque, même pour datetime).
        const ta = Date.parse(dayPart(a));
        const tb = Date.parse(dayPart(b));
        if (Number.isNaN(ta) || Number.isNaN(tb)) return NaN;
        return ta - tb;
    }
    const sa = String(a);
    const sb = String(b);
    if (sa < sb) return -1;
    return sa > sb ? 1 : 0;
}

// Partie date « yyyy-MM-dd » d'une valeur date/datetime saisie.
function dayPart(s) {
    const str = String(s);
    return str.length > 10 ? str.slice(0, 10) : str;
}

function scalarEqual(type, a, b) {
    const c = cmp(type, a, b);
    return !Number.isNaN(c) && c === 0;
}

// ------------------------- picklist : opérateurs ensemblistes (=, in, notIn) ----------
// Représente une condition picklist comme une région :
//   { neg:false, set:null }  -> univers (aucune contrainte : matche tout)
//   { neg:false, set:S }     -> valeurs positives (exact = singleton, in = S)
//   { neg:true,  set:S }     -> complément (notIn : tout SAUF S)
function picklistRegion(c) {
    if (!c) return { neg: false, set: null };
    if (c.comparison === 'in' || c.comparison === 'notIn') {
        const vals = Array.isArray(c.values) ? c.values.map(String).filter((x) => x !== '') : [];
        if (!vals.length) return { neg: false, set: null }; // liste vide = aucune contrainte
        return { neg: c.comparison === 'notIn', set: new Set(vals) };
    }
    if (isBlank(c.value)) return { neg: false, set: null };
    return { neg: false, set: new Set([String(c.value)]) };
}

function isSubset(x, y) {
    for (const e of x) {
        if (!y.has(e)) return false;
    }
    return true;
}
function disjoint(x, y) {
    for (const e of x) {
        if (y.has(e)) return false;
    }
    return true;
}

// A ⊇ B (A contient B). Les cas nécessitant l'univers complet des valeurs
// (P ⊇ N) sont traités de façon CONSERVATRICE (false) pour ne jamais signaler
// à tort un doublon/inaccessibilité (niveau bloquant « danger »).
function regionSubsumes(A, B) {
    const aUniv = A.set === null && !A.neg;
    const bUniv = B.set === null && !B.neg;
    if (aUniv) return true; // l'univers contient tout
    if (bUniv) return false; // seul l'univers contient l'univers (déjà traité)
    if (!A.neg && !B.neg) return isSubset(B.set, A.set); // P(A) ⊇ P(B) : B ⊆ A
    if (A.neg && !B.neg) return disjoint(A.set, B.set); // N(A) ⊇ P(B) : A ∩ B = ∅
    if (A.neg && B.neg) return isSubset(A.set, B.set); // N(A) ⊇ N(B) : A ⊆ B
    return false; // P(A) ⊇ N(B) : nécessite l'univers -> conservateur
}

// A ∩ B ≠ ∅. Le cas N ∩ N (nécessite l'univers) est traité de façon
// CONSERVATRICE (true) : au pire un simple avertissement « chevauchement ».
function regionIntersects(A, B) {
    const aUniv = A.set === null && !A.neg;
    const bUniv = B.set === null && !B.neg;
    if (aUniv || bUniv) return true;
    if (!A.neg && !B.neg) return !disjoint(A.set, B.set); // P ∩ P : A ∩ B ≠ ∅
    if (A.neg && !B.neg) return !isSubset(B.set, A.set); // N(A) ∩ P(B) : B ⊄ A
    if (!A.neg && B.neg) return !isSubset(A.set, B.set); // P(A) ∩ N(B) : A ⊄ B
    return true; // N ∩ N : conservateur
}