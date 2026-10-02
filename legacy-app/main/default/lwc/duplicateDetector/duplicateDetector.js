import { LightningElement, api, track } from 'lwc';
import findDuplicates from '@salesforce/apex/DuplicateDetectorController.findDuplicates';

/**
 * Composant générique de détection de doublons Salesforce.
 *
 * Utilisation :
 *   <c-duplicate-detector
 *     object-api-name="Contact"
 *     fields-config={fieldsConfig}
 *     logic-operator="1 AND (2 OR 3)"
 *     record-id={recordId}
 *     max-results="5"
 *     onduplicatesfound={handleDuplicates}
 *     onnoduplicates={handleNoDuplicates}>
 *   </c-duplicate-detector>
 *
 * La méthode publique checkDuplicates(fieldValues) doit être appelée depuis le parent
 * avec un objet clé=fieldApiName, valeur=valeur saisie.
 * Ex : this.template.querySelector('c-duplicate-detector').checkDuplicates({ Name: 'Dupont', Email__c: 'test@test.com' });
 */

// Opérateurs SOQL supportés
const OPERATOR_MAP = {
    EQUALS:         (field, value) => `${field} = '${escapeSoql(value)}'`,
    NOT_EQUALS:     (field, value) => `${field} != '${escapeSoql(value)}'`,
    LIKE_START:     (field, value) => `${field} LIKE '${escapeSoql(value)}%'`,
    LIKE_CONTAINS:  (field, value) => `${field} LIKE '%${escapeSoql(value)}%'`,
    LIKE_END:       (field, value) => `${field} LIKE '%${escapeSoql(value)}'`,
    EQUALS_LITERAL: (field, value) => `${field} = ${escapeSoql(value)}`
};

/**
 * Échappe les caractères dangereux dans les valeurs de chaînes SOQL
 * pour éviter les injections SOQL.
 * @param {string} value
 * @returns {string}
 */
function escapeSoql(value) {
    if (typeof value !== 'string') return String(value);
    // Échappe les apostrophes et antislashs (caractères dangereux en SOQL)
    return value.replace(/\\/g, '\\\\').replace(/'/g, "\\'");
}

export default class DuplicateDetector extends LightningElement {

    // ─── Propriétés publiques (@api) ──────────────────────────────────────────

    /* Permet de masquer le composant après utilisation, si besoin*/
    @api hideResult = false; 

    
    /** API name de l'objet Salesforce à interroger (ex: 'Contact') */
    @api objectApiName;

    /**
     * Configuration des champs à utiliser pour la détection.
     * Tableau d'objets : [{ fieldApiName, label, operator }]
     */
    @api fieldsConfig = [];

    /**
     * Logique entre les conditions :
     *  - 'AND' : tous les champs
     *  - 'OR'  : au moins un champ
     *  - expression custom ex: '1 AND (2 OR 3)' (index 1-based sur fieldsConfig)
     */
    @api logicOperator = 'AND';

    /** ID de l'enregistrement courant à exclure des résultats (mode édition) */
    @api recordId;

    /** Nombre maximum de doublons à retourner */
    @api maxResults = 10;

    /**
     * Champs à inclure dans le SELECT et à afficher dans le tableau de résultats.
     * Chaîne CSV, ex: "Name,Company,Phone,Email"
     * Si absent, les colonnes sont déduites de fieldsConfig.
     */
    @api fieldsToQuery;

    // ─── État interne ─────────────────────────────────────────────────────────

    @track duplicates = [];
    @track isLoading = false;
    @track errorMessage = '';
    @track searchDone = false;   // true après au moins une recherche

    // ─── Getters pour le template ─────────────────────────────────────────────

    /** Indique s'il y a des doublons à afficher */
    get hasDuplicates() {
        return this.duplicates.length > 0;
    }

    /** Affiche le message "aucun doublon" seulement après une recherche sans résultat */
    get showNoDuplicateMessage() {
        return this.searchDone && !this.hasDuplicates && !this.isLoading && !this.errorMessage;
    }

    /** Libellé du nombre de doublons trouvés */
    get duplicateCountLabel() {
        const count = this.duplicates.length;
        return count === 1
            ? '1 doublon potentiel détecté.'
            : `${count} doublons potentiels détectés.`;
    }

    /**
     * Colonnes du tableau (hors Name, toujours en 1ère colonne).
     * Priorité : fieldsToQuery (CSV) > fieldsConfig.
     * Quand fieldsToQuery est fourni, le label affiché est le nom du champ.
     */
    get tableColumns() {
        if (this.fieldsToQuery) {
            return this.fieldsToQuery
                .split(',')
                .map(f => f.trim())
                .filter(f => f && f !== 'Name')
                .map(f => ({ fieldApiName: f, label: f }));
        }
        if (!this.fieldsConfig) return [];
        return this.fieldsConfig.filter(f => f.fieldApiName !== 'Name');
    }

    /**
     * Doublons enrichis pour le template : chaque enregistrement contient
     * un tableau `columns` avec { key, label, value } pour éviter l'accès
     * calculé {record[col.fieldApiName]} interdit dans les templates LWC < v66.
     */
    get duplicatesWithColumns() {
        const cols = this.tableColumns;
        return this.duplicates.map(record => ({
            ...record,
            columns: cols.map(col => ({
                key: col.fieldApiName,
                label: col.label,
                value: record[col.fieldApiName]
            }))
        }));
    }

    // ─── Méthode publique ─────────────────────────────────────────────────────

    /**
     * Point d'entrée principal — appelé depuis le composant parent.
     * @param {Object} fieldValues - clé: fieldApiName, valeur: valeur saisie
     *   Ex : { Name: 'Dupont', Email__c: 'test@test.com' }
     */
    @api
    checkDuplicates(fieldValues) {
        // Réinitialisation
        this.duplicates = [];
        this.errorMessage = '';
        this.searchDone = false;

        // Construction de la clause WHERE à partir des valeurs fournies
        const whereClause = this._buildWhereClause(fieldValues);

        // Si aucune condition n'est construite (toutes les valeurs sont vides),
        // on n'effectue pas la requête
        if (!whereClause) {
            this.errorMessage = 'Veuillez renseigner au moins un champ pour la détection.';
            return;
        }

        this._callApex(whereClause);
    }

    // ─── Méthodes privées ─────────────────────────────────────────────────────

    /**
     * Construit la clause WHERE SOQL à partir des valeurs fournies et de la logicOperator.
     * @param {Object} fieldValues
     * @returns {string|null} clause WHERE sans le mot-clé WHERE, ou null si vide
     */
    _buildWhereClause(fieldValues) {
        if (!this.fieldsConfig || !fieldValues) return null;

        // Tableau des conditions indexées (null si valeur vide)
        const conditions = this.fieldsConfig.map(fieldConfig => {
            const value = fieldValues[fieldConfig.fieldApiName];

            // On ignore les champs sans valeur
            if (value === null || value === undefined || String(value).trim() === '') {
                return null;
            }

            const operatorFn = OPERATOR_MAP[fieldConfig.operator] || OPERATOR_MAP.EQUALS;
            return operatorFn(fieldConfig.fieldApiName, String(value).trim());
        });

        return this._applyLogic(conditions);
    }

    /**
     * Applique la logique (AND / OR / expression custom) sur le tableau de conditions.
     * Les conditions nulles (champs vides) sont ignorées.
     * @param {Array<string|null>} conditions
     * @returns {string|null}
     */
    _applyLogic(conditions) {
        const logic = (this.logicOperator || 'AND').trim().toUpperCase();

        if (logic === 'AND' || logic === 'OR') {
            // Logique simple : on filtre les nulls et on joint
            const active = conditions.filter(Boolean);
            if (active.length === 0) return null;
            return active.join(` ${logic} `);
        }

        // Logique custom : ex "1 AND (2 OR 3)"
        // On remplace chaque index (1-based) par la condition correspondante
        // ou on retire le terme s'il est vide
        return this._parseCustomLogic(logic, conditions);
    }

    /**
     * Interprète une expression de logique custom de type "1 AND (2 OR 3)".
     * Remplace les indices (1-based) par les conditions SOQL correspondantes.
     * Gère les valeurs vides en retirant proprement le terme et l'opérateur associé.
     * @param {string} expression
     * @param {Array<string|null>} conditions
     * @returns {string|null}
     */
    _parseCustomLogic(expression, conditions) {
        // Remplace chaque nombre par la condition (index 1-based → 0-based)
        // On utilise un marqueur temporaire pour les conditions nulles
        const NULL_MARKER = '__NULL__';

        let result = expression.replace(/\b(\d+)\b/g, (match, num) => {
            const idx = parseInt(num, 10) - 1;
            if (idx < 0 || idx >= conditions.length || !conditions[idx]) {
                return NULL_MARKER;
            }
            return `(${conditions[idx]})`;
        });

        // Nettoyage : suppression des termes NULL et opérateurs orphelins
        // Ex: "(__NULL__) AND (cond2)" → "(cond2)"
        // On répète le nettoyage jusqu'à stabilisation (cas imbriqués)
        let previous;
        do {
            previous = result;
            // Supprime "(NULL_MARKER) AND/OR ..." ou "... AND/OR (NULL_MARKER)"
            result = result
                .replace(new RegExp(`\\(${NULL_MARKER}\\)\\s*(AND|OR)\\s*`, 'gi'), '')
                .replace(new RegExp(`\\s*(AND|OR)\\s*\\(${NULL_MARKER}\\)`, 'gi'), '')
                .replace(new RegExp(NULL_MARKER, 'g'), '');

            // Supprime les parenthèses vides
            result = result.replace(/\(\s*\)/g, '').trim();
        } while (result !== previous);

        // Supprime les AND/OR en début/fin de chaîne restants
        result = result.replace(/^\s*(AND|OR)\s*/i, '').replace(/\s*(AND|OR)\s*$/i, '').trim();

        return result.length > 0 ? result : null;
    }

    /**
     * Appelle le contrôleur Apex pour récupérer les doublons.
     * @param {string} whereClause
     */
    _callApex(whereClause) {
        this.isLoading = true;

        findDuplicates({
            objectApiName: this.objectApiName,
            soqlWhereClause: whereClause,
            recordId: this.recordId || null,
            maxResults: parseInt(this.maxResults, 10) || 10,
            fieldsToQuery: this.fieldsToQuery || null
        })
        .then(res => {
            this.searchDone = true;
            const { records } = res;
            // console.log(`[DuplicateDetector] ${JSON.stringify(records)}`);
            // Enrichissement des enregistrements avec une URL relative vers la fiche
            this.duplicates = records.map(rec => ({
                ...rec,
                recordUrl: `/${rec.Id}`
            }));

            if (this.duplicates.length > 0) {
                // Événement : doublons trouvés
                this.dispatchEvent(new CustomEvent('duplicatesfound', {
                    detail: { duplicates: this.duplicates, picklistMeta: res.picklistMeta }
                }));
            } else {
                // Événement : aucun doublon
                this.dispatchEvent(new CustomEvent('noduplicates'));
            }
        })
        .catch(error => {
            this.searchDone = true;
            this.errorMessage = error?.body?.message || 'Une erreur est survenue lors de la détection des doublons.';
            console.error('[DuplicateDetector] Erreur Apex :', error);
        })
        .finally(() => {
            this.isLoading = false;
        });
    }
}