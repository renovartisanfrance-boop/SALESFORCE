import { LightningElement, wire } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';
import SheetJS from '@salesforce/resourceUrl/SheetJS';
import getImportableFields from '@salesforce/apex/LettreImportController.getImportableFields';
import isSystemAdmin from '@salesforce/apex/LettreImportController.isSystemAdmin';
import startImport from '@salesforce/apex/LettreImportController.startImport';

const PAGE_SIZE_OPTIONS = [
    { label: '20', value: '20' },
    { label: '50', value: '50' },
    { label: '100', value: '100' },
    { label: 'Tous', value: 'all' }
];

const TARGET_OBJECT = 'Lettre__c';
const IGNORE_FIELD_VALUE = '';

const APINAME_ToExclude = ['Id', 'OwnerId', 'CreatedDate', 'CreatedById', 'LastModifiedDate', 'LastModifiedById', 'SystemModstamp', 'Nom_d_import__c', "RES_Traitement_Appels__c"];

const DATE_FORMAT_OPTIONS = [
    { label: 'JJ/MM/AAAA  (31/12/2025)', value: 'DD/MM/YYYY' },
    { label: 'JJ-MM-AAAA  (31-12-2025)', value: 'DD-MM-YYYY' },
    { label: 'JJ.MM.AAAA  (31.12.2025)', value: 'DD.MM.YYYY' },
    { label: 'AAAA-MM-JJ  (2025-12-31)', value: 'YYYY-MM-DD' },
    { label: 'AAAA/MM/JJ  (2025/12/31)', value: 'YYYY/MM/DD' },
    { label: 'MM/JJ/AAAA  (12/31/2025)', value: 'MM/DD/YYYY' }
];

const DATETIME_FORMAT_OPTIONS = [
    { label: 'JJ/MM/AAAA HH:mm  (31/12/2025 14:30)', value: 'DD/MM/YYYY HH:mm' },
    { label: 'JJ/MM/AAAA HH:mm:ss', value: 'DD/MM/YYYY HH:mm:ss' },
    { label: 'AAAA-MM-JJ HH:mm:ss  (ISO)', value: 'YYYY-MM-DD HH:mm:ss' },
    { label: 'AAAA-MM-JJTHH:mm:ss  (ISO 8601)', value: 'YYYY-MM-DDTHH:mm:ss' },
    { label: 'MM/JJ/AAAA HH:mm:ss  (US)', value: 'MM/DD/YYYY HH:mm:ss' }
];

const FORMAT_DEFS = {
    'DD/MM/YYYY': { regex: /^(\d{1,2})\/(\d{1,2})\/(\d{4})$/, order: ['day', 'month', 'year'], ambiguous: true },
    'DD-MM-YYYY': { regex: /^(\d{1,2})-(\d{1,2})-(\d{4})$/, order: ['day', 'month', 'year'], ambiguous: false },
    'DD.MM.YYYY': { regex: /^(\d{1,2})\.(\d{1,2})\.(\d{4})$/, order: ['day', 'month', 'year'], ambiguous: false },
    'YYYY-MM-DD': { regex: /^(\d{4})-(\d{1,2})-(\d{1,2})$/, order: ['year', 'month', 'day'], ambiguous: false },
    'YYYY/MM/DD': { regex: /^(\d{4})\/(\d{1,2})\/(\d{1,2})$/, order: ['year', 'month', 'day'], ambiguous: false },
    'MM/DD/YYYY': { regex: /^(\d{1,2})\/(\d{1,2})\/(\d{4})$/, order: ['month', 'day', 'year'], ambiguous: true },
    'DD/MM/YYYY HH:mm': { regex: /^(\d{1,2})\/(\d{1,2})\/(\d{4})[ T](\d{1,2}):(\d{2})$/, order: ['day', 'month', 'year', 'hour', 'minute'], ambiguous: true },
    'DD/MM/YYYY HH:mm:ss': { regex: /^(\d{1,2})\/(\d{1,2})\/(\d{4})[ T](\d{1,2}):(\d{2}):(\d{2})$/, order: ['day', 'month', 'year', 'hour', 'minute', 'second'], ambiguous: true },
    'YYYY-MM-DD HH:mm:ss': { regex: /^(\d{4})-(\d{1,2})-(\d{1,2})[ ](\d{1,2}):(\d{2}):(\d{2})$/, order: ['year', 'month', 'day', 'hour', 'minute', 'second'], ambiguous: false },
    'YYYY-MM-DDTHH:mm:ss': { regex: /^(\d{4})-(\d{1,2})-(\d{1,2})T(\d{1,2}):(\d{2}):(\d{2})/, order: ['year', 'month', 'day', 'hour', 'minute', 'second'], ambiguous: false },
    'MM/DD/YYYY HH:mm:ss': { regex: /^(\d{1,2})\/(\d{1,2})\/(\d{4})[ T](\d{1,2}):(\d{2}):(\d{2})$/, order: ['month', 'day', 'year', 'hour', 'minute', 'second'], ambiguous: true }
};

const VALIDATIONS = {
    EMAIL_FORMAT: {
        label: 'Format email valide (@ et domaine)',
        regex: /^[^\s@]+@[^\s@]+\.[^\s@]+$/,
        appliesTo: ['EMAIL', 'STRING', 'TEXTAREA']
    },
    PHONE_FR: {
        label: 'Téléphone français (0X XX XX XX XX)',
        regex: /^0[1-9]([\s.\-]?\d{2}){4}$/,
        appliesTo: ['PHONE', 'STRING', 'TEXTAREA']
    },
    PHONE_FR_MOBILE: {
        label: 'Mobile français (06 ou 07)',
        regex: /^0[67]([\s.\-]?\d{2}){4}$/,
        appliesTo: ['PHONE', 'STRING', 'TEXTAREA']
    },
    PHONE_INTL_FR: {
        label: 'International France (+33...)',
        regex: /^\+33[\s.\-]?[1-9]([\s.\-]?\d{2}){4}$/,
        appliesTo: ['PHONE', 'STRING', 'TEXTAREA']
    },
    PHONE_FR_OR_INTL: {
        label: 'Téléphone FR (0X) ou international (+33)',
        regex: /^(0[1-9]([\s.\-]?\d{2}){4}|\+33[\s.\-]?[1-9]([\s.\-]?\d{2}){4})$/,
        appliesTo: ['PHONE', 'STRING', 'TEXTAREA']
    },
    URL_FORMAT: {
        label: 'URL (http:// ou https://)',
        regex: /^https?:\/\/[^\s]+$/i,
        appliesTo: ['URL', 'STRING', 'TEXTAREA']
    },
    POSITIVE_NUMBER: {
        label: 'Nombre positif',
        regex: /^\d+(\.\d+)?$/,
        appliesTo: ['INTEGER', 'DOUBLE', 'CURRENCY', 'PERCENT', 'STRING']
    },
    NOT_EMPTY: {
        label: 'Non vide',
        regex: /\S/,
        appliesTo: ['*']
    }
};

const SUGGESTED_VALIDATIONS_BY_TYPE = {
    EMAIL: ['EMAIL_FORMAT'],
    PHONE: ['PHONE_FR_OR_INTL'],
    URL: ['URL_FORMAT']
};

function parseDateValue(value, format) {
    const def = FORMAT_DEFS[format];
    if (!def) return null;
    const trimmed = String(value).trim();
    const m = trimmed.match(def.regex);
    if (!m) return null;
    const parts = {};
    def.order.forEach((key, i) => {
        parts[key] = parseInt(m[i + 1], 10);
    });
    if (parts.month < 1 || parts.month > 12) return null;
    if (parts.day < 1 || parts.day > 31) return null;
    if (parts.year < 1900 || parts.year > 2100) return null;
    if (parts.hour !== undefined && (parts.hour > 23 || parts.hour < 0)) return null;
    if (parts.minute !== undefined && (parts.minute > 59 || parts.minute < 0)) return null;
    if (parts.second !== undefined && (parts.second > 59 || parts.second < 0)) return null;
    let definitive = !def.ambiguous;
    if (def.ambiguous) {
        const firstKey = def.order[0];
        const secondKey = def.order[1];
        if (firstKey === 'day' && parts.day > 12) definitive = true;
        if (firstKey === 'month' && parts.day > 12) definitive = true;
        if (firstKey === 'day' && secondKey === 'month' && parts.month > 12) definitive = false;
    }
    return { ...parts, definitive };
}

export default class LettreImport extends LightningElement {
    importName = '';
    fileName = '';
    columns = [];
    allRows = [];
    errorMessage = '';
    fileLoaded = false;
    sheetJsReady = false;
    sheetJsLoading = false;

    searchTerm = '';
    pageSize = '20';
    currentPage = 1;

    pageSizeOptions = PAGE_SIZE_OPTIONS;

    rawFields = [];
    fieldOptionsError = '';
    columnMapping = {};
    columnFormats = {};
    columnValidations = {};
    isAdmin = false;
    importing = false;

    currentStep = 'configure';
    fieldSelections = {};
    configViewMode = 'list';

    @wire(isSystemAdmin)
    wiredAdmin({ data }) {
        if (data !== undefined) {
            this.isAdmin = !!data;
        }
    }

    @wire(getImportableFields, { objectApiName: TARGET_OBJECT })
    wiredFields({ data, error }) {
        if (data) {
            this.rawFields = data;
            this.fieldOptionsError = '';
            // DEBUG temporaire
            const ficheField = data.find((f) => f.apiName === 'Fiche__c');
            // eslint-disable-next-line no-console
            console.log('[lettreImport] Fiche__c reçu de l\'Apex :', JSON.parse(JSON.stringify(ficheField || {})));
            const picklistFields = data.filter(
                (f) => String(f.type).toUpperCase() === 'PICKLIST' || String(f.type).toUpperCase() === 'MULTIPICKLIST'
            );
            // eslint-disable-next-line no-console
            console.log('[lettreImport] Tous les picklists reçus :', JSON.parse(JSON.stringify(picklistFields)));
        } else if (error) {
            this.rawFields = [];
            this.fieldOptionsError =
                'Impossible de charger les champs Salesforce : ' +
                (error.body?.message || error.message || JSON.stringify(error));
        }
    }

    get fieldOptions() {
        const options = [{ label: '— Ignorer cette colonne —', value: IGNORE_FIELD_VALUE }];
        const excluded = new Set(APINAME_ToExclude.map((n) => n.toLowerCase()));
        const availableSet = this.availableForMappingSet;
        this.rawFields.forEach((field) => {
            if (excluded.has(field.apiName.toLowerCase())) return;
            if (availableSet && !availableSet.has(field.apiName)) return;
            const display = this.isAdmin ? `${field.label} (${field.apiName})` : field.label;
            options.push({ label: display, value: field.apiName });
        });
        return options;
    }

    get availableForMappingSet() {
        const set = new Set();
        Object.entries(this.fieldSelections).forEach(([apiName, s]) => {
            if (!s.selected) return;
            const v = s.defaultValue;
            const isEmpty =
                v === '' || v === null || v === undefined || (typeof v === 'string' && v.trim() === '');
            if (isEmpty) set.add(apiName);
        });
        return set;
    }

    get isConfigStep() {
        return this.currentStep === 'configure';
    }

    get isImportStep() {
        return this.currentStep === 'import';
    }

    get hasRawFields() {
        return this.rawFields && this.rawFields.length > 0;
    }

    get configurableFields() {
        const excluded = new Set(APINAME_ToExclude.map((n) => n.toLowerCase()));
        const PINNED_FIRST = 'Fiche__c';
        const ALWAYS_VISIBLE = new Set(['Name']);
        const filtered = this.rawFields.filter((f) => !excluded.has(f.apiName.toLowerCase()));
        const pinned = filtered.filter((f) => f.apiName === PINNED_FIRST);
        const rest = filtered
            .filter((f) => f.apiName !== PINNED_FIRST)
            .filter((f) => {
                if (ALWAYS_VISIBLE.has(f.apiName)) return true;
                const label = String(f.label || '').toUpperCase();
                return label.startsWith('VAR');
            });
        return [...pinned, ...rest]
            .map((f) => {
                const sel = this.fieldSelections[f.apiName] || { selected: false, defaultValue: '' };
                const t = String(f.type).toUpperCase();
                const isPicklist = t === 'PICKLIST';
                const isMultiPicklist = t === 'MULTIPICKLIST';
                const isDate = t === 'DATE';
                const isDateTime = t === 'DATETIME';
                const isBoolean = t === 'BOOLEAN';
                const isNumber =
                    t === 'INTEGER' || t === 'DOUBLE' || t === 'CURRENCY' || t === 'PERCENT';
                const isEmail = t === 'EMAIL';
                const isPhone = t === 'PHONE';
                const isUrl = t === 'URL';
                const isTextarea = t === 'TEXTAREA';
                const isReference = t === 'REFERENCE';

                let inputType = 'text';
                if (isEmail) inputType = 'email';
                else if (isPhone) inputType = 'tel';
                else if (isUrl) inputType = 'url';
                else if (isNumber) inputType = 'number';
                else if (isDate) inputType = 'date';
                else if (isDateTime) inputType = 'datetime-local';

                const picklistOptions = isPicklist
                    ? [
                        { label: '— Aucune —', value: '' },
                        ...(f.picklistValues || []).map((p) => {
                            if (typeof p === 'string') {
                                return { label: p, value: p };
                            }
                            const lbl = p && (p.label || p.value);
                            const val = p && p.value;
                            return { label: String(lbl == null ? '' : lbl), value: String(val == null ? '' : val) };
                        })
                    ]
                    : [];

                const displayLabel = this.isAdmin ? `${f.label} (${f.apiName})` : f.label;
                let helpText = '';
                if (isMultiPicklist) helpText = 'Plusieurs valeurs séparées par ;';
                else if (isReference) helpText = 'ID Salesforce (15 ou 18 caractères)';

                return {
                    key: f.apiName,
                    apiName: f.apiName,
                    label: displayLabel,
                    typeLabel: t,
                    selected: sel.selected,
                    defaultValue: sel.defaultValue,
                    inputType,
                    isPicklist,
                    isMultiPicklist,
                    isBoolean,
                    isTextarea,
                    isStandardInput:
                        !isPicklist && !isMultiPicklist && !isBoolean && !isTextarea,
                    picklistOptions,
                    helpText
                };
            });
    }

    get configContinueDisabled() {
        return !Object.values(this.fieldSelections).some((s) => s.selected);
    }

    get allConfigFieldsSelected() {
        const fields = this.configurableFields;
        if (fields.length === 0) return false;
        return fields.every((f) => f.selected);
    }

    get configFieldsCountText() {
        const fields = this.configurableFields;
        const total = fields.length;
        const selected = fields.filter((f) => f.selected).length;
        return `${selected} / ${total} champ(s) sélectionné(s)`;
    }


    get configListClass() {
        return this.configViewMode === 'grid' ? 'config-list grid-view' : 'config-list list-view';
    }

    get isListView() {
        return this.configViewMode === 'list';
    }

    get isGridView() {
        return this.configViewMode === 'grid';
    }

    get listVariant() {
        return this.configViewMode === 'list' ? 'brand' : 'neutral';
    }

    get gridVariant() {
        return this.configViewMode === 'grid' ? 'brand' : 'neutral';
    }

    handleViewList() {
        this.configViewMode = 'list';
    }

    handleViewGrid() {
        this.configViewMode = 'grid';
    }

    connectedCallback() {
        this.loadSheetJs();
    }

    loadSheetJs() {
        if (this.sheetJsReady || this.sheetJsLoading) {
            return Promise.resolve();
        }
        this.sheetJsLoading = true;
        return loadScript(this, SheetJS)
            .then(() => {
                this.sheetJsReady = true;
                this.sheetJsLoading = false;
            })
            .catch((error) => {
                this.sheetJsLoading = false;
                this.errorMessage = 'Impossible de charger la librairie Excel : ' + (error?.message || error);
            });
    }

    get hasPreview() {
        return this.columns.length > 0 && this.allRows.length > 0;
    }

    get cardHeaderClass() {
        return this.fileLoaded ? 'card-header compact' : 'card-header';
    }

    get mappedColumns() {
        const dupSet = this.duplicateFieldSet;
        const fieldByApiName = new Map();
        this.rawFields.forEach((f) => fieldByApiName.set(f.apiName, f));
        return this.columns.map((column, index) => {
            const selected = this.columnMapping[index] || IGNORE_FIELD_VALUE;
            const isDup = selected !== IGNORE_FIELD_VALUE && dupSet.has(selected);
            const field = selected ? fieldByApiName.get(selected) : null;
            const fieldType = field ? String(field.type).toUpperCase() : '';
            const isDate = fieldType === 'DATE';
            const isDateTime = fieldType === 'DATETIME';
            let formatOptions = [];
            if (isDate) {
                formatOptions = DATE_FORMAT_OPTIONS;
            } else if (isDateTime) {
                formatOptions = DATETIME_FORMAT_OPTIONS;
            }

            let validationOptions = [];
            const skipValidations =
                !field || isDate || isDateTime || fieldType === 'BOOLEAN' || fieldType === 'REFERENCE';
            if (!skipValidations) {
                validationOptions = Object.entries(VALIDATIONS)
                    .filter(([, v]) => v.appliesTo.includes('*') || v.appliesTo.includes(fieldType))
                    .map(([key, v]) => ({ label: v.label, value: key }));
            }
            const selectedValidations = this.columnValidations[index] || [];
            const validationSummary =
                selectedValidations.length === 0
                    ? '+ Validations'
                    : `Validations (${selectedValidations.length})`;

            return {
                key: `col-${index}`,
                index,
                label: column,
                selectedField: selected,
                needsFormat: isDate || isDateTime,
                formatOptions,
                selectedFormat: this.columnFormats[index] || (formatOptions[0] ? formatOptions[0].value : ''),
                hasValidationOptions: validationOptions.length > 0,
                validationOptions,
                selectedValidations,
                validationSummary,
                headerClass: isDup ? 'mapping-cell mapping-cell-error' : 'mapping-cell'
            };
        });
    }

    get duplicateFieldSet() {
        const counts = new Map();
        Object.values(this.columnMapping).forEach((apiName) => {
            if (apiName && apiName !== IGNORE_FIELD_VALUE) {
                counts.set(apiName, (counts.get(apiName) || 0) + 1);
            }
        });
        const dups = new Set();
        counts.forEach((count, apiName) => {
            if (count > 1) {
                dups.add(apiName);
            }
        });
        return dups;
    }

    get hasDuplicateMappings() {
        return this.duplicateFieldSet.size > 0;
    }

    get hasAnyMapping() {
        return Object.values(this.columnMapping).some((v) => v && v !== IGNORE_FIELD_VALUE);
    }

    get canImport() {
        return (
            this.fileLoaded &&
            this.hasAnyMapping &&
            !this.hasDuplicateMappings &&
            !this.importing
        );
    }

    get importDisabled() {
        return !this.canImport;
    }

    get duplicateMappingMessage() {
        const dupSet = this.duplicateFieldSet;
        if (dupSet.size === 0) {
            return '';
        }
        const fieldLabelByApiName = new Map();
        this.rawFields.forEach((f) => fieldLabelByApiName.set(f.apiName, f.label));
        const messages = [];
        dupSet.forEach((apiName) => {
            const columnsForField = [];
            Object.entries(this.columnMapping).forEach(([idx, value]) => {
                if (value === apiName) {
                    columnsForField.push(this.columns[parseInt(idx, 10)]);
                }
            });
            const fieldDisplay = this.isAdmin
                ? `${fieldLabelByApiName.get(apiName) || apiName} (${apiName})`
                : fieldLabelByApiName.get(apiName) || apiName;
            messages.push(`« ${fieldDisplay} » est mappé sur plusieurs colonnes : ${columnsForField.join(', ')}`);
        });
        return 'Conflit de mapping — ' + messages.join(' • ');
    }

    get filteredRows() {
        if (!this.searchTerm) {
            return this.allRows;
        }
        const term = this.searchTerm.toLowerCase();
        return this.allRows.filter((row) =>
            row.cells.some((cell) => String(cell.value).toLowerCase().includes(term))
        );
    }

    get totalPages() {
        if (this.isAllMode) {
            return 1;
        }
        const size = parseInt(this.pageSize, 10);
        return Math.max(1, Math.ceil(this.filteredRows.length / size));
    }

    get displayedRows() {
        const errorsMap = this.rowValidationErrors;
        let baseRows;
        if (this.isAllMode) {
            baseRows = this.filteredRows;
        } else {
            const size = parseInt(this.pageSize, 10);
            const start = (this.currentPage - 1) * size;
            baseRows = this.filteredRows.slice(start, start + size);
        }
        return baseRows.map((row) => {
            const error = errorsMap.get(row.id);
            const isValid = !error;
            return {
                ...row,
                isValid,
                rowClass: isValid ? '' : 'row-invalid',
                statusIcon: isValid ? 'utility:check' : 'utility:close',
                statusVariant: isValid ? 'success' : 'error',
                statusTitle: isValid ? 'Prêt pour import' : 'Validation échouée : ' + error
            };
        });
    }

    get rowValidationErrors() {
        const map = new Map();
        const fieldByApiName = new Map();
        this.rawFields.forEach((f) => fieldByApiName.set(f.apiName, f));

        // Pré-construit les Sets de valeurs/labels picklist (lowercase) pour comparaison rapide
        const picklistSetByApiName = new Map();
        fieldByApiName.forEach((f, api) => {
            if (Array.isArray(f.picklistValues) && f.picklistValues.length > 0) {
                const allowed = new Set();
                f.picklistValues.forEach((p) => {
                    if (typeof p === 'string') {
                        allowed.add(p.toLowerCase());
                        return;
                    }
                    if (p && p.value) allowed.add(String(p.value).toLowerCase());
                    if (p && p.label) allowed.add(String(p.label).toLowerCase());
                });
                picklistSetByApiName.set(api, allowed);
            }
        });

        const hasAnyPicklist = picklistSetByApiName.size > 0;
        const hasAnyUserValidation = Object.values(this.columnValidations).some(
            (arr) => Array.isArray(arr) && arr.length > 0
        );
        if (!hasAnyPicklist && !hasAnyUserValidation) {
            return map;
        }

        this.allRows.forEach((row) => {
            const errors = [];
            Object.entries(this.columnMapping).forEach(([colIdxStr, apiName]) => {
                if (!apiName || apiName === IGNORE_FIELD_VALUE) return;
                const colIdx = parseInt(colIdxStr, 10);
                const cell = row.cells[colIdx];
                const raw = cell ? cell.value : '';
                const trimmed = String(raw == null ? '' : raw).trim();
                if (trimmed === '') return;

                // Validation auto picklist / multipicklist
                const allowed = picklistSetByApiName.get(apiName);
                if (allowed) {
                    const field = fieldByApiName.get(apiName);
                    const fieldType = String(field.type).toUpperCase();
                    if (fieldType === 'MULTIPICKLIST') {
                        const vals = trimmed.split(';').map((v) => v.trim()).filter((v) => v !== '');
                        const invalid = vals.filter((v) => !allowed.has(v.toLowerCase()));
                        if (invalid.length > 0) {
                            errors.push(
                                `${this.columns[colIdx]} : valeur(s) hors liste : ${invalid.join(', ')}`
                            );
                            return;
                        }
                    } else if (!allowed.has(trimmed.toLowerCase())) {
                        errors.push(
                            `${this.columns[colIdx]} : « ${trimmed} » absent de la liste de sélection`
                        );
                        return;
                    }
                }

                // Validations cochées par l'utilisateur
                const vKeys = this.columnValidations[colIdx] || [];
                for (const vKey of vKeys) {
                    const v = VALIDATIONS[vKey];
                    if (!v) continue;
                    if (!v.regex.test(trimmed)) {
                        errors.push(`${this.columns[colIdx]} : ${v.label}`);
                        break;
                    }
                }
            });
            if (errors.length > 0) {
                map.set(row.id, errors.join(' • '));
            }
        });
        return map;
    }

    get validRowCount() {
        return this.allRows.length - this.rowValidationErrors.size;
    }

    get invalidRowCount() {
        return this.rowValidationErrors.size;
    }

    get hasInvalidRows() {
        return this.invalidRowCount > 0;
    }

    get isAllMode() {
        return this.pageSize === 'all';
    }

    get isFirstPage() {
        return this.currentPage <= 1;
    }

    get isLastPage() {
        return this.currentPage >= this.totalPages;
    }

    get hasNoResults() {
        return this.allRows.length > 0 && this.filteredRows.length === 0;
    }

    get rowSummary() {
        const total = this.allRows.length;
        const filtered = this.filteredRows.length;
        if (this.searchTerm && filtered !== total) {
            return `${filtered} / ${total} lignes`;
        }
        return `${total} lignes`;
    }

    handleNameChange(event) {
        this.importName = event.target.value;
    }

    handleFieldSelectChange(event) {
        const apiName = event.target.dataset.api;
        const checked = event.target.checked;
        const current = this.fieldSelections[apiName] || { selected: false, defaultValue: '' };
        this.fieldSelections = {
            ...this.fieldSelections,
            [apiName]: { ...current, selected: checked, defaultValue: checked ? current.defaultValue : '' }
        };
    }

    handleSelectAllConfigFields(event) {
        const checked = event.target.checked;
        const newSelections = { ...this.fieldSelections };
        this.configurableFields.forEach((f) => {
            const current = newSelections[f.apiName] || { selected: false, defaultValue: '' };
            newSelections[f.apiName] = {
                ...current,
                selected: checked,
                defaultValue: checked ? current.defaultValue : ''
            };
        });
        this.fieldSelections = newSelections;
    }

    handleDefaultValueChange(event) {
        const apiName = event.target.dataset.api;
        const value =
            event.detail && event.detail.value !== undefined ? event.detail.value : event.target.value;
        const current = this.fieldSelections[apiName] || { selected: true, defaultValue: '' };
        this.fieldSelections = {
            ...this.fieldSelections,
            [apiName]: { ...current, selected: true, defaultValue: value }
        };
    }

    handleDefaultBooleanChange(event) {
        const apiName = event.target.dataset.api;
        const value = !!event.target.checked;
        const current = this.fieldSelections[apiName] || { selected: true, defaultValue: false };
        this.fieldSelections = {
            ...this.fieldSelections,
            [apiName]: { ...current, selected: true, defaultValue: value }
        };
    }

    handleContinueToImport() {
        if (this.configContinueDisabled) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Aucun champ sélectionné',
                message: 'Coche au moins un champ pour pouvoir continuer.',
                variant: 'warning'
            }));
            return;
        }
        this.currentStep = 'import';
    }

    handleBackToConfigure() {
        this.currentStep = 'configure';
    }


    handleZoneClick(event) {
        if (event && event.target && event.target.tagName === 'INPUT') {
            return;
        }
        const input = this.template.querySelector('.hidden-file');
        if (input) {
            input.click();
        }
    }

    handleSearch(event) {
        this.searchTerm = event.target.value || '';
        this.currentPage = 1;
    }

    handlePageSizeChange(event) {
        this.pageSize = event.detail.value;
        this.currentPage = 1;
    }

    handlePrev() {
        if (this.currentPage > 1) {
            this.currentPage -= 1;
        }
    }

    handleNext() {
        if (this.currentPage < this.totalPages) {
            this.currentPage += 1;
        }
    }

    async handleDelete(event) {
        const id = event.currentTarget.dataset.id;
        const row = this.allRows.find((r) => r.id === id);
        if (!row) return;
        const preview = row.cells
            .map((c) => c.value)
            .filter((v) => v != null && String(v).trim() !== '')
            .slice(0, 3)
            .join(' · ');
        const confirmed = await LightningConfirm.open({
            message: preview
                ? `Supprimer cette ligne de l'aperçu ?\n\n${preview}`
                : 'Supprimer cette ligne de l\'aperçu ?',
            variant: 'header',
            label: 'Confirmation de suppression',
            theme: 'warning'
        });
        if (!confirmed) return;
        this.allRows = this.allRows.filter((r) => r.id !== id);
        const newTotal = this.totalPages;
        if (this.currentPage > newTotal) {
            this.currentPage = newTotal;
        }
    }

    handleChangeFile() {
        this.fileName = '';
        this.columns = [];
        this.allRows = [];
        this.columnMapping = {};
        this.columnFormats = {};
        this.columnValidations = {};
        this.fileLoaded = false;
        this.errorMessage = '';
        this.resetTableState();
    }

    handleMappingChange(event) {
        const index = parseInt(event.target.dataset.index, 10);
        const value = event.detail.value;
        this.columnMapping = { ...this.columnMapping, [index]: value };
        const newFormats = { ...this.columnFormats };
        delete newFormats[index];
        this.columnFormats = newFormats;
        this.applyDateFormatDetection(index, value);
        this.suggestValidations(index, value);
    }

    handleValidationChange(event) {
        const index = parseInt(event.target.dataset.index, 10);
        const value = event.detail.value || [];
        this.columnValidations = { ...this.columnValidations, [index]: [...value] };
    }

    suggestValidations(index, apiName) {
        const newValidations = { ...this.columnValidations };
        delete newValidations[index];
        if (apiName) {
            const field = this.rawFields.find((f) => f.apiName === apiName);
            if (field) {
                const fieldType = String(field.type).toUpperCase();
                const suggested = SUGGESTED_VALIDATIONS_BY_TYPE[fieldType];
                if (suggested && suggested.length > 0) {
                    newValidations[index] = [...suggested];
                }
            }
        }
        this.columnValidations = newValidations;
    }

    runValidations() {
        const errorsMap = this.rowValidationErrors;
        const invalidIndexes = new Set();
        const sampleErrors = [];
        const maxSamples = 5;
        this.allRows.forEach((row, rowIndex) => {
            if (errorsMap.has(row.id)) {
                invalidIndexes.add(rowIndex);
                if (sampleErrors.length < maxSamples) {
                    sampleErrors.push(`Ligne ${rowIndex + 2} — ${errorsMap.get(row.id)}`);
                }
            }
        });
        return { invalidCount: invalidIndexes.size, invalidIndexes, sampleErrors };
    }

    applyDateFormatDetection(index, apiName) {
        if (!apiName) return;
        const field = this.rawFields.find((f) => f.apiName === apiName);
        if (!field) return;
        const type = String(field.type).toUpperCase();
        if (type !== 'DATE' && type !== 'DATETIME') return;
        const detected = this.detectDateFormat(index, type);
        if (detected) {
            this.columnFormats = { ...this.columnFormats, [index]: detected };
        }
    }

    detectDateFormat(columnIndex, fieldType) {
        const samples = this.allRows
            .map((row) => row.cells[columnIndex] && row.cells[columnIndex].value)
            .filter((v) => v !== undefined && v !== null && String(v).trim() !== '')
            .slice(0, 30);
        if (samples.length === 0) {
            return null;
        }
        const candidates = fieldType === 'DATETIME' ? DATETIME_FORMAT_OPTIONS : DATE_FORMAT_OPTIONS;
        let best = { format: null, score: -1 };
        candidates.forEach((fmt) => {
            let valid = 0;
            let definitive = 0;
            samples.forEach((s) => {
                const r = parseDateValue(s, fmt.value);
                if (r) {
                    valid++;
                    if (r.definitive) definitive++;
                }
            });
            const score = valid + definitive * 1000;
            if (score > best.score && valid > 0) {
                best = { format: fmt.value, score };
            }
        });
        return best.format;
    }

    handleFormatChange(event) {
        const index = parseInt(event.target.dataset.index, 10);
        const value = event.detail.value;
        this.columnFormats = { ...this.columnFormats, [index]: value };
    }

    formatDateForSalesforce(value, format) {
        const parsed = parseDateValue(value, format);
        if (!parsed) {
            return null;
        }
        const yyyy = String(parsed.year).padStart(4, '0');
        const mm = String(parsed.month).padStart(2, '0');
        const dd = String(parsed.day).padStart(2, '0');
        if (parsed.hour !== undefined) {
            const hh = String(parsed.hour).padStart(2, '0');
            const mi = String(parsed.minute || 0).padStart(2, '0');
            const ss = String(parsed.second || 0).padStart(2, '0');
            return `${yyyy}-${mm}-${dd}T${hh}:${mi}:${ss}.000Z`;
        }
        return `${yyyy}-${mm}-${dd}`;
    }

    buildDefaultsRecord() {
        const fieldByApiName = new Map();
        this.rawFields.forEach((f) => fieldByApiName.set(f.apiName, f));
        const defaults = {};
        Object.entries(this.fieldSelections).forEach(([apiName, s]) => {
            if (!s.selected) return;
            const v = s.defaultValue;
            const isEmpty =
                v === '' || v === null || v === undefined || (typeof v === 'string' && v.trim() === '');
            if (isEmpty) return;
            const field = fieldByApiName.get(apiName);
            if (!field) return;
            const t = String(field.type).toUpperCase();
            if (t === 'BOOLEAN') {
                defaults[apiName] = !!v;
            } else if (t === 'INTEGER' || t === 'DOUBLE' || t === 'CURRENCY' || t === 'PERCENT') {
                const n = Number(v);
                if (!isNaN(n)) defaults[apiName] = n;
            } else if (t === 'DATE') {
                defaults[apiName] = String(v);
            } else if (t === 'DATETIME') {
                let s2 = String(v);
                if (s2.length === 16) s2 += ':00';
                if (!s2.endsWith('Z')) s2 = s2 + '.000Z';
                defaults[apiName] = s2;
            } else {
                defaults[apiName] = String(v);
            }
        });
        return defaults;
    }

    buildRecordsForImport(skipIndexes) {
        const fieldByApiName = new Map();
        this.rawFields.forEach((f) => fieldByApiName.set(f.apiName, f));
        const defaults = this.buildDefaultsRecord();

        return this.allRows.map((row, rowIdx) => {
            if (skipIndexes && skipIndexes.has(rowIdx)) return null;
            const record = { ...defaults };
            Object.entries(this.columnMapping).forEach(([idxStr, apiName]) => {
                if (!apiName || apiName === IGNORE_FIELD_VALUE) return;
                const idx = parseInt(idxStr, 10);
                const cell = row.cells[idx];
                const raw = cell ? cell.value : '';
                if (raw === '' || raw === null || raw === undefined) {
                    return;
                }
                const field = fieldByApiName.get(apiName);
                if (!field) return;
                const type = String(field.type).toUpperCase();
                if (type === 'DATE' || type === 'DATETIME') {
                    const fmt = this.columnFormats[idx];
                    const iso = this.formatDateForSalesforce(raw, fmt);
                    if (iso !== null) record[apiName] = iso;
                } else if (type === 'BOOLEAN') {
                    const v = String(raw).trim().toLowerCase();
                    record[apiName] = ['true', '1', 'oui', 'yes', 'vrai'].includes(v);
                } else if (
                    type === 'INTEGER' ||
                    type === 'DOUBLE' ||
                    type === 'CURRENCY' ||
                    type === 'PERCENT'
                ) {
                    const num = Number(String(raw).replace(',', '.').replace(/\s/g, ''));
                    if (!isNaN(num)) record[apiName] = num;
                } else {
                    record[apiName] = String(raw);
                }
            });
            if (this.importName) {
                record['Nom_d_import__c'] = this.importName;
            }
            return record;
        }).filter((rec) => rec && Object.keys(rec).length > 0);
    }

    async handleStartImport() {
        if (!this.canImport) return;

        const validation = this.runValidations();
        let message;
        let theme = 'info';
        if (validation.invalidCount === 0) {
            message = `Confirmer l'import de ${this.allRows.length} ligne(s) ? L'import s'exécutera en arrière-plan, vous recevrez une notification à la fin.`;
        } else {
            const remaining = this.allRows.length - validation.invalidCount;
            const sample = validation.sampleErrors.join('\n');
            message =
                `${validation.invalidCount} ligne(s) ne respectent pas les validations choisies et seront ignorées.\n\n` +
                `Exemples :\n${sample}\n\n` +
                `Confirmer l'import des ${remaining} ligne(s) restante(s) ?`;
            theme = 'warning';
        }

        const confirmed = await LightningConfirm.open({
            message,
            variant: 'header',
            label: "Démarrer l'importation",
            theme
        });
        if (!confirmed) return;

        this.importing = true;
        try {
            const records = this.buildRecordsForImport(validation.invalidIndexes);
            if (records.length === 0) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Aucune ligne valide',
                    message: 'Aucune ligne ne contient de données à importer après application du mapping.',
                    variant: 'warning'
                }));
                return;
            }
            await startImport({
                records,
                objectApiName: 'Lettre__c',
                importName: this.importName || this.fileName
            });
            this.dispatchEvent(new ShowToastEvent({
                title: 'Import lancé',
                message: `${records.length} ligne(s) en cours d'import. Vous recevrez une notification à la fin.`,
                variant: 'success',
                mode: 'sticky'
            }));
            this.handleChangeFile();
        } catch (e) {
            this.dispatchEvent(new ShowToastEvent({
                title: "Erreur lors du lancement de l'import",
                message: e?.body?.message || e?.message || JSON.stringify(e),
                variant: 'error',
                mode: 'sticky'
            }));
        } finally {
            this.importing = false;
        }
    }

    autoSuggestMapping() {
        if (!this.fieldOptions || this.fieldOptions.length <= 1) {
            return;
        }
        const fieldsByApiName = new Map();
        const fieldsByLabel = new Map();
        this.fieldOptions.forEach((option) => {
            if (option.value !== IGNORE_FIELD_VALUE) {
                fieldsByApiName.set(option.value.toLowerCase(), option.value);
                fieldsByLabel.set(option.label.toLowerCase(), option.value);
            }
        });
        const mapping = {};
        this.columns.forEach((columnLabel, index) => {
            const normalized = String(columnLabel).trim().toLowerCase();
            if (!normalized) {
                return;
            }
            if (fieldsByApiName.has(normalized)) {
                mapping[index] = fieldsByApiName.get(normalized);
                return;
            }
            const normalizedSnake = normalized.replace(/\s+/g, '_') + '__c';
            if (fieldsByApiName.has(normalizedSnake)) {
                mapping[index] = fieldsByApiName.get(normalizedSnake);
                return;
            }
            for (const [label, apiName] of fieldsByLabel.entries()) {
                if (label.startsWith(normalized + ' ') || label === normalized) {
                    mapping[index] = apiName;
                    return;
                }
            }
        });
        this.columnMapping = mapping;
        const newFormats = {};
        const newValidations = {};
        Object.entries(mapping).forEach(([idx, apiName]) => {
            const field = this.rawFields.find((f) => f.apiName === apiName);
            if (!field) return;
            const type = String(field.type).toUpperCase();
            if (type === 'DATE' || type === 'DATETIME') {
                const detected = this.detectDateFormat(parseInt(idx, 10), type);
                if (detected) newFormats[idx] = detected;
            }
            const suggested = SUGGESTED_VALIDATIONS_BY_TYPE[type];
            if (suggested && suggested.length > 0) {
                newValidations[idx] = [...suggested];
            }
        });
        this.columnFormats = newFormats;
        this.columnValidations = newValidations;
    }

    resetTableState() {
        this.searchTerm = '';
        this.pageSize = '20';
        this.currentPage = 1;
    }

    handleFileChange(event) {
        this.errorMessage = '';
        this.fileName = '';
        this.columns = [];
        this.allRows = [];
        this.columnMapping = {};
        this.columnFormats = {};
        this.columnValidations = {};
        this.fileLoaded = false;
        this.resetTableState();

        const file = event.target.files && event.target.files[0];
        if (!file) {
            return;
        }

        this.fileName = file.name;
        const extension = this.fileName.split('.').pop().toLowerCase();

        if (extension === 'xlsx' || extension === 'xls') {
            this.readExcel(file);
        } else {
            this.errorMessage = 'Format non pris en charge. Utilise un fichier .xlsx ou .xls.';
        }
    }

    readExcel(file) {
        const parse = () => {
            const reader = new FileReader();
            reader.onload = () => {
                try {
                    const data = new Uint8Array(reader.result);
                    const workbook = window.XLSX.read(data, { type: 'array' });
                    const firstSheetName = workbook.SheetNames[0];
                    if (!firstSheetName) {
                        this.errorMessage = 'Le fichier Excel ne contient aucune feuille.';
                        return;
                    }
                    const sheet = workbook.Sheets[firstSheetName];
                    const matrix = window.XLSX.utils.sheet_to_json(sheet, {
                        header: 1,
                        blankrows: false,
                        defval: ''
                    });
                    const preview = this.buildPreviewFromMatrix(matrix);
                    if (preview) {
                        this.columns = preview.columns;
                        this.allRows = preview.rows;
                        this.fileLoaded = true;
                        if (!this.importName) {
                            this.importName = this.fileName.replace(/\.[^.]+$/, '');
                        }
                        this.autoSuggestMapping();
                    } else {
                        this.errorMessage = 'Fichier Excel vide ou mal formé.';
                    }
                } catch (error) {
                    this.errorMessage = 'Erreur lors de la lecture Excel : ' + (error?.message || error);
                }
            };
            reader.onerror = () => {
                this.errorMessage = 'Impossible de lire le fichier Excel.';
            };
            reader.readAsArrayBuffer(file);
        };

        if (this.sheetJsReady) {
            parse();
        } else {
            this.loadSheetJs().then(() => {
                if (this.sheetJsReady) {
                    parse();
                }
            });
        }
    }

    buildPreviewFromMatrix(matrix) {
        if (!matrix || matrix.length === 0) {
            return null;
        }
        const headerRow = matrix[0] || [];
        const columns = headerRow.map((cell, index) =>
            cell !== undefined && cell !== null && String(cell).trim() !== ''
                ? String(cell).trim()
                : `Colonne ${index + 1}`
        );
        if (columns.length === 0) {
            return null;
        }
        const rows = matrix.slice(1).map((rowArray, rowIndex) => ({
            id: `row-${rowIndex}`,
            cells: columns.map((_, cellIndex) => ({
                key: `cell-${rowIndex}-${cellIndex}`,
                value:
                    rowArray[cellIndex] !== undefined && rowArray[cellIndex] !== null
                        ? String(rowArray[cellIndex])
                        : ''
            }))
        }));
        return { columns, rows };
    }
}