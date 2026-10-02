/**
 * Moteur de formule du Catalogue Tarifaire — partagé par les composants lwc022.
 *
 * Une formule est une EXPRESSION texte (façon Salesforce / Excel) :
 *   - nombres : 40, 1500, 0.5
 *   - champs du dossier : {API_Name}  (ex. {MPR_SHAB__c})
 *   - opérateurs : + - * /  et parenthèses ( )
 *   - fonctions : MIN, MAX, ROUND, ABS, FLOOR, CEIL
 *   ex : MIN(2000, {MPR_SHAB__c} * 40) + 100
 *
 * Ce module fournit : extraction des champs, formatage lisible (libellés),
 * et validation stricte (tokenizer + parseur à descente récursive). La même
 * grammaire devra être ré-implémentée côté Apex pour le calcul réel.
 */

// Définition des fonctions supportées (arité + implémentation).
const FUNCTIONS = {
    MIN: { minArgs: 1, maxArgs: Infinity, apply: (a) => Math.min(...a) },
    MAX: { minArgs: 1, maxArgs: Infinity, apply: (a) => Math.max(...a) },
    ARRONDI: {
        minArgs: 1,
        maxArgs: 2,
        apply: (a) => {
            const decimals = a.length > 1 ? Math.trunc(a[1]) : 0;
            const factor = Math.pow(10, decimals);
            return Math.round(a[0] * factor) / factor;
        }
    },
    ABS: { minArgs: 1, maxArgs: 1, apply: (a) => Math.abs(a[0]) },
    PLANCHER: { minArgs: 1, maxArgs: 1, apply: (a) => Math.floor(a[0]) },
    PLAFOND: { minArgs: 1, maxArgs: 1, apply: (a) => Math.ceil(a[0]) }
};
const FUNCTION_NAMES = Object.keys(FUNCTIONS);

// Alias (anglais / Excel) tolérés en lecture -> nom canonique français.
const FUNCTION_ALIASES = { ROUND: 'ARRONDI', FLOOR: 'PLANCHER', CEIL: 'PLAFOND', CEILING: 'PLAFOND' };

// Catalogue des fonctions exposées dans l'UI (libellés en français).
export const AVAILABLE_FUNCTIONS = [
    { name: 'MIN', snippet: 'MIN(', help: 'Minimum : MIN(a, b, …)' },
    { name: 'MAX', snippet: 'MAX(', help: 'Maximum : MAX(a, b, …)' },
    { name: 'ARRONDI', snippet: 'ARRONDI(', help: 'Arrondi : ARRONDI(x, décimales)' },
    { name: 'ABS', snippet: 'ABS(', help: 'Valeur absolue : ABS(x)' },
    { name: 'PLANCHER', snippet: 'PLANCHER(', help: 'Arrondi inférieur : PLANCHER(x)' },
    { name: 'PLAFOND', snippet: 'PLAFOND(', help: 'Arrondi supérieur : PLAFOND(x)' }
];

// Boutons opérateurs / ponctuation exposés dans l'UI.
export const OPERATOR_INSERTS = [
    { key: 'plus', label: '+', snippet: ' + ' },
    { key: 'minus', label: '−', snippet: ' - ' },
    { key: 'times', label: '×', snippet: ' * ' },
    { key: 'div', label: '÷', snippet: ' / ' },
    { key: 'lpar', label: '(', snippet: '(' },
    { key: 'rpar', label: ')', snippet: ')' },
    { key: 'comma', label: ',', snippet: ', ' }
];

/** Liste des API names de champs référencés dans une expression. */
export function extractFields(expression) {
    if (!expression) return [];
    const set = new Set();
    const re = /\{([^}]+)\}/g;
    let m;
    while ((m = re.exec(expression)) !== null) {
        set.add(m[1].trim());
    }
    return [...set];
}

/** Rend une expression lisible : {API} -> libellé, * -> ×, / -> ÷. */
export function formatForDisplay(expression, labelByApi) {
    if (!expression) return '';
    return expression
        .replace(/\{([^}]+)\}/g, (whole, api) => {
            const key = api.trim();
            return (labelByApi && labelByApi[key]) || key;
        })
        .replace(/\*/g, ' × ')
        .replace(/\//g, ' ÷ ')
        .replace(/\s+/g, ' ')
        .trim();
}

// --- Tokenizer ---
function tokenize(expr) {
    const tokens = [];
    let i = 0;
    const n = expr.length;
    while (i < n) {
        const ch = expr[i];
        if (ch === ' ' || ch === '\t' || ch === '\n' || ch === '\r') {
            i++;
            continue;
        }
        if (ch === '{') {
            const end = expr.indexOf('}', i);
            if (end < 0) throw new Error('Référence de champ non fermée « { ».');
            const name = expr.substring(i + 1, end).trim();
            if (!name) throw new Error('Référence de champ vide « {} ».');
            tokens.push({ type: 'field', name });
            i = end + 1;
            continue;
        }
        if ((ch >= '0' && ch <= '9') || ch === '.') {
            let j = i;
            let dot = false;
            while (j < n && ((expr[j] >= '0' && expr[j] <= '9') || expr[j] === '.')) {
                if (expr[j] === '.') {
                    if (dot) throw new Error('Nombre invalide (deux points).');
                    dot = true;
                }
                j++;
            }
            tokens.push({ type: 'num', value: parseFloat(expr.substring(i, j)) });
            i = j;
            continue;
        }
        if (/[A-Za-z_]/.test(ch)) {
            let j = i;
            while (j < n && /[A-Za-z0-9_]/.test(expr[j])) j++;
            const raw = expr.substring(i, j);
            const name = raw.toUpperCase();
            const canonical = FUNCTION_ALIASES[name] || name;
            let k = j;
            while (k < n && expr[k] === ' ') k++;
            if (expr[k] !== '(') {
                throw new Error(
                    `« ${raw} » n'est pas reconnu. Utilisez « Insérer un champ » pour les champs du dossier.`
                );
            }
            if (!FUNCTION_NAMES.includes(canonical)) {
                throw new Error(`Fonction inconnue : ${raw}.`);
            }
            tokens.push({ type: 'func', name: canonical });
            i = j;
            continue;
        }
        if (ch === '+' || ch === '-' || ch === '*' || ch === '/') {
            tokens.push({ type: 'op', value: ch });
            i++;
            continue;
        }
        if (ch === '(') {
            tokens.push({ type: 'lparen' });
            i++;
            continue;
        }
        if (ch === ')') {
            tokens.push({ type: 'rparen' });
            i++;
            continue;
        }
        if (ch === ',') {
            tokens.push({ type: 'comma' });
            i++;
            continue;
        }
        throw new Error(`Caractère non autorisé : « ${ch} ».`);
    }
    return tokens;
}

// --- Parseur à descente récursive (valide ET évalue) ---
function makeParser(tokens, resolveField) {
    let pos = 0;
    const peek = () => tokens[pos];
    const next = () => tokens[pos++];

    function parseExpr() {
        let value = parseTerm();
        while (peek() && peek().type === 'op' && (peek().value === '+' || peek().value === '-')) {
            const op = next().value;
            const rhs = parseTerm();
            value = op === '+' ? value + rhs : value - rhs;
        }
        return value;
    }
    function parseTerm() {
        let value = parseFactor();
        while (peek() && peek().type === 'op' && (peek().value === '*' || peek().value === '/')) {
            const op = next().value;
            const rhs = parseFactor();
            if (op === '*') {
                value *= rhs;
            } else {
                if (rhs === 0) throw new Error('Division par zéro.');
                value /= rhs;
            }
        }
        return value;
    }
    function parseFactor() {
        const t = peek();
        if (t && t.type === 'op' && (t.value === '-' || t.value === '+')) {
            const op = next().value;
            const v = parseFactor();
            return op === '-' ? -v : v;
        }
        return parsePrimary();
    }
    function parsePrimary() {
        const t = next();
        if (!t) throw new Error('Expression incomplète.');
        if (t.type === 'num') return t.value;
        if (t.type === 'field') return resolveField(t.name);
        if (t.type === 'lparen') {
            const v = parseExpr();
            const closing = next();
            if (!closing || closing.type !== 'rparen') throw new Error('Parenthèse fermante « ) » manquante.');
            return v;
        }
        if (t.type === 'func') {
            const open = next();
            if (!open || open.type !== 'lparen') throw new Error(`« ${t.name} » doit être suivi de « ( ».`);
            const args = [];
            if (peek() && peek().type === 'rparen') {
                next();
            } else {
                args.push(parseExpr());
                while (peek() && peek().type === 'comma') {
                    next();
                    args.push(parseExpr());
                }
                const closing = next();
                if (!closing || closing.type !== 'rparen') throw new Error('Parenthèse fermante « ) » manquante.');
            }
            const def = FUNCTIONS[t.name];
            if (args.length < def.minArgs || args.length > def.maxArgs) {
                const expected =
                    def.maxArgs === Infinity
                        ? `${def.minArgs} argument(s) minimum`
                        : `${def.minArgs} à ${def.maxArgs} argument(s)`;
                throw new Error(`${t.name} attend ${expected}.`);
            }
            return def.apply(args);
        }
        throw new Error('Expression invalide.');
    }

    return { parseExpr, remaining: () => tokens.length - pos };
}

/**
 * Valide une expression. numericFieldApis = Set des API names de champs
 * numériques autorisés. Renvoie { valid, error }.
 */
export function validateFormula(expression, numericFieldApis) {
    const expr = (expression || '').trim();
    if (!expr) {
        return { valid: false, error: 'La formule est vide.' };
    }
    let tokens;
    try {
        tokens = tokenize(expr);
    } catch (e) {
        return { valid: false, error: e.message };
    }
    for (const t of tokens) {
        if (t.type === 'field' && numericFieldApis && !numericFieldApis.has(t.name)) {
            return { valid: false, error: `Champ inconnu ou non numérique : ${t.name}.` };
        }
    }
    try {
        const parser = makeParser(tokens, () => 1);
        parser.parseExpr();
        if (parser.remaining() !== 0) {
            return { valid: false, error: 'Expression mal formée (éléments en trop).' };
        }
        return { valid: true, error: null };
    } catch (e) {
        return { valid: false, error: e.message };
    }
}

/** Conversion des anciens formats vers une expression (rétro-compat). */
export function legacyTokensToExpression(tokens) {
    if (!Array.isArray(tokens)) return '';
    const opMap = { '+': ' + ', '-': ' - ', '*': ' * ', '/': ' / ' };
    return tokens
        .map((t, i) => {
            const operand = t.type === 'field' ? `{${t.field}}` : String(t.value == null ? '' : t.value);
            const op = i === 0 ? '' : opMap[t.op] || ' + ';
            return op + operand;
        })
        .join('')
        .trim();
}

export function legacyFactorFieldToExpression(factor, field) {
    if (field && factor != null) return `{${field}} * ${factor}`;
    if (field) return `{${field}}`;
    if (factor != null) return String(factor);
    return '';
}