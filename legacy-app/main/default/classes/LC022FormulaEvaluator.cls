/**
 * Évaluateur de formules du Catalogue Tarifaire (côté Apex).
 *
 * Ré-implémente la grammaire du module LWC `lwc022FormulaUtils` afin de
 * CALCULER réellement les montants au moment de la facturation V2.
 *
 * Une formule est une expression texte (façon Salesforce / Excel) :
 *   - nombres : 40, 1500, 0.5
 *   - champs du dossier : {API_Name}  (ex. {MPR_SHAB__c})
 *   - opérateurs : + - * /  et parenthèses ( )
 *   - fonctions : MIN, MAX, ARRONDI, ABS, PLANCHER, PLAFOND
 *     (alias anglais tolérés : ROUND, FLOOR, CEIL, CEILING)
 *   ex : MIN(2000, {MPR_SHAB__c} * 40) + 100
 *
 * Les valeurs de champs sont fournies dans une Map<String, Decimal> (clé =
 * API name, sans accolades). Un champ absent ou null vaut 0.
 *
 * Ne PAS modifier la grammaire sans répercuter dans lwc022FormulaUtils.js.
 */
public without sharing class LC022FormulaEvaluator {

    /** Exception levée pour toute formule invalide ou non calculable. */
    public class FormulaException extends Exception {}

    // Caractères de classification (évite les opérateurs < > non supportés sur String).
    private static final String DIGITS = '0123456789';
    private static final String ALPHA = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_';
    private static final String ALNUM = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_0123456789';

    // Fonctions reconnues : nom canonique -> {minArgs, maxArgs}. -1 = illimité.
    private static final Map<String, Integer[]> FUNC_ARITY = new Map<String, Integer[]>{
        'MIN' => new Integer[]{ 1, -1 },
        'MAX' => new Integer[]{ 1, -1 },
        'ARRONDI' => new Integer[]{ 1, 2 },
        'ABS' => new Integer[]{ 1, 1 },
        'PLANCHER' => new Integer[]{ 1, 1 },
        'PLAFOND' => new Integer[]{ 1, 1 }
    };

    // Alias anglais / Excel tolérés en lecture -> nom canonique français.
    private static final Map<String, String> FUNC_ALIASES = new Map<String, String>{
        'ROUND' => 'ARRONDI',
        'FLOOR' => 'PLANCHER',
        'CEIL' => 'PLAFOND',
        'CEILING' => 'PLAFOND'
    };

    /**
     * Calcule la valeur numérique d'une expression. `fields` = valeurs des
     * champs référencés (clé = API name). Lève FormulaException si invalide.
     */
    public static Decimal evaluate(String expression, Map<String, Decimal> fields) {
        if (String.isBlank(expression)) {
            throw new FormulaException('La formule est vide.');
        }
        List<Token> tokens = tokenize(expression);
        Parser p = new Parser(tokens, fields == null ? new Map<String, Decimal>() : fields);
        Decimal value = p.parseExpr();
        if (p.remaining() != 0) {
            throw new FormulaException('Expression mal formée (éléments en trop).');
        }
        return value;
    }

    // ------------------------------------------------------------------ Tokens

    private enum TokType { NUM, FIELDREF, FUNC, OP, LPAREN, RPAREN, COMMA }

    private class Token {
        TokType type;
        Decimal num;
        String text; // nom de champ, nom de fonction, ou opérateur
        Token(TokType t) { this.type = t; }
    }

    private static Boolean isDigit(String c) { return DIGITS.contains(c); }
    private static Boolean isAlpha(String c) { return ALPHA.contains(c); }
    private static Boolean isAlphaNum(String c) { return ALNUM.contains(c); }
    private static Boolean isSpace(String c) {
        return c == ' ' || c == '\t' || c == '\n' || c == '\r';
    }

    private static List<Token> tokenize(String expr) {
        List<Token> tokens = new List<Token>();
        Integer i = 0;
        Integer n = expr.length();
        while (i < n) {
            String ch = expr.substring(i, i + 1);

            if (isSpace(ch)) { i++; continue; }

            // Référence de champ {API_Name}
            if (ch == '{') {
                Integer endIdx = expr.indexOf('}', i);
                if (endIdx < 0) throw new FormulaException('Référence de champ non fermée « { ».');
                String name = expr.substring(i + 1, endIdx).trim();
                if (String.isBlank(name)) throw new FormulaException('Référence de champ vide « {} ».');
                Token t = new Token(TokType.FIELDREF);
                t.text = name;
                tokens.add(t);
                i = endIdx + 1;
                continue;
            }

            // Nombre
            if (isDigit(ch) || ch == '.') {
                Integer j = i;
                Boolean dot = false;
                while (j < n) {
                    String cj = expr.substring(j, j + 1);
                    if (cj == '.') {
                        if (dot) throw new FormulaException('Nombre invalide (deux points).');
                        dot = true;
                    } else if (!isDigit(cj)) {
                        break;
                    }
                    j++;
                }
                Token t = new Token(TokType.NUM);
                t.num = Decimal.valueOf(expr.substring(i, j));
                tokens.add(t);
                i = j;
                continue;
            }

            // Identifiant -> fonction (doit être suivi de « ( »)
            if (isAlpha(ch)) {
                Integer j = i;
                while (j < n && isAlphaNum(expr.substring(j, j + 1))) j++;
                String raw = expr.substring(i, j);
                String nameUpper = raw.toUpperCase();
                String canonical = FUNC_ALIASES.containsKey(nameUpper) ? FUNC_ALIASES.get(nameUpper) : nameUpper;
                Integer k = j;
                while (k < n && expr.substring(k, k + 1) == ' ') k++;
                if (k >= n || expr.substring(k, k + 1) != '(') {
                    throw new FormulaException(
                        '« ' + raw + ' » n\'est pas reconnu. Utilisez les champs sous la forme {API_Name}.'
                    );
                }
                if (!FUNC_ARITY.containsKey(canonical)) {
                    throw new FormulaException('Fonction inconnue : ' + raw + '.');
                }
                Token t = new Token(TokType.FUNC);
                t.text = canonical;
                tokens.add(t);
                i = j;
                continue;
            }

            // Opérateurs / ponctuation
            if (ch == '+' || ch == '-' || ch == '*' || ch == '/') {
                Token t = new Token(TokType.OP);
                t.text = ch;
                tokens.add(t);
                i++;
                continue;
            }
            if (ch == '(') { tokens.add(new Token(TokType.LPAREN)); i++; continue; }
            if (ch == ')') { tokens.add(new Token(TokType.RPAREN)); i++; continue; }
            if (ch == ',') { tokens.add(new Token(TokType.COMMA)); i++; continue; }

            throw new FormulaException('Caractère non autorisé : « ' + ch + ' ».');
        }
        return tokens;
    }

    // ------------------------------------------------- Parseur descente récursive

    private class Parser {
        List<Token> toks;
        Integer pos = 0;
        Map<String, Decimal> fields;

        Parser(List<Token> toks, Map<String, Decimal> fields) {
            this.toks = toks;
            this.fields = fields;
        }

        Token peek() { return pos < toks.size() ? toks[pos] : null; }
        Token next() { return pos < toks.size() ? toks[pos++] : null; }
        Integer remaining() { return toks.size() - pos; }

        Decimal parseExpr() {
            Decimal value = parseTerm();
            Token t = peek();
            while (t != null && t.type == TokType.OP && (t.text == '+' || t.text == '-')) {
                String op = next().text;
                Decimal rhs = parseTerm();
                value = (op == '+') ? value + rhs : value - rhs;
                t = peek();
            }
            return value;
        }

        Decimal parseTerm() {
            Decimal value = parseFactor();
            Token t = peek();
            while (t != null && t.type == TokType.OP && (t.text == '*' || t.text == '/')) {
                String op = next().text;
                Decimal rhs = parseFactor();
                if (op == '*') {
                    value = value * rhs;
                } else {
                    if (rhs == 0) throw new FormulaException('Division par zéro.');
                    value = value.divide(rhs, 10, System.RoundingMode.HALF_UP);
                }
                t = peek();
            }
            return value;
        }

        Decimal parseFactor() {
            Token t = peek();
            if (t != null && t.type == TokType.OP && (t.text == '-' || t.text == '+')) {
                String op = next().text;
                Decimal v = parseFactor();
                return (op == '-') ? -v : v;
            }
            return parsePrimary();
        }

        Decimal parsePrimary() {
            Token t = next();
            if (t == null) throw new FormulaException('Expression incomplète.');
            if (t.type == TokType.NUM) return t.num;
            if (t.type == TokType.FIELDREF) {
                Decimal v = fields.get(t.text);
                return v == null ? 0 : v;
            }
            if (t.type == TokType.LPAREN) {
                Decimal v = parseExpr();
                Token closing = next();
                if (closing == null || closing.type != TokType.RPAREN) {
                    throw new FormulaException('Parenthèse fermante « ) » manquante.');
                }
                return v;
            }
            if (t.type == TokType.FUNC) {
                Token open = next();
                if (open == null || open.type != TokType.LPAREN) {
                    throw new FormulaException('« ' + t.text + ' » doit être suivi de « ( ».');
                }
                List<Decimal> args = new List<Decimal>();
                if (peek() != null && peek().type == TokType.RPAREN) {
                    next();
                } else {
                    args.add(parseExpr());
                    while (peek() != null && peek().type == TokType.COMMA) {
                        next();
                        args.add(parseExpr());
                    }
                    Token closing = next();
                    if (closing == null || closing.type != TokType.RPAREN) {
                        throw new FormulaException('Parenthèse fermante « ) » manquante.');
                    }
                }
                Integer[] arity = FUNC_ARITY.get(t.text);
                Integer minA = arity[0];
                Integer maxA = arity[1];
                if (args.size() < minA || (maxA != -1 && args.size() > maxA)) {
                    String expected = (maxA == -1)
                        ? (minA + ' argument(s) minimum')
                        : (minA + ' à ' + maxA + ' argument(s)');
                    throw new FormulaException(t.text + ' attend ' + expected + '.');
                }
                return applyFunction(t.text, args);
            }
            throw new FormulaException('Expression invalide.');
        }
    }

    // ----------------------------------------------------------- Fonctions

    private static Decimal applyFunction(String name, List<Decimal> a) {
        if (name == 'MIN') {
            Decimal m = a[0];
            for (Decimal x : a) if (x < m) m = x;
            return m;
        }
        if (name == 'MAX') {
            Decimal m = a[0];
            for (Decimal x : a) if (x > m) m = x;
            return m;
        }
        if (name == 'ABS') {
            return a[0].abs();
        }
        if (name == 'PLANCHER') {
            return a[0].setScale(0, System.RoundingMode.FLOOR);
        }
        if (name == 'PLAFOND') {
            return a[0].setScale(0, System.RoundingMode.CEILING);
        }
        if (name == 'ARRONDI') {
            Integer decimals = (a.size() > 1) ? a[1].intValue() : 0;
            if (decimals >= 0) {
                return a[0].setScale(decimals, System.RoundingMode.HALF_UP);
            }
            // Décimales négatives : arrondi aux dizaines/centaines…
            Decimal factor = Decimal.valueOf(Math.pow(10, decimals * -1).longValue());
            return a[0].divide(factor, 0, System.RoundingMode.HALF_UP) * factor;
        }
        throw new FormulaException('Fonction inconnue : ' + name + '.');
    }
}