import { LightningElement, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';
import getImportNames from '@salesforce/apex/LettreImportController.getImportNames';
import getImportableFields from '@salesforce/apex/LettreImportController.getImportableFields';
import getLettresByImportName from '@salesforce/apex/LettreImportController.getLettresByImportName';
import startMassUpdate from '@salesforce/apex/LettreImportController.startMassUpdate';

const EXCLUDED_FROM_EDIT = new Set([
    'Id', 'Name', 'OwnerId', 'CreatedDate', 'CreatedById',
    'LastModifiedDate', 'LastModifiedById', 'SystemModstamp', 'Nom_d_import__c'
]);

const PAGE_SIZE_OPTIONS = [
    { label: '25', value: '25' },
    { label: '50', value: '50' },
    { label: '100', value: '100' },
    { label: 'Tous', value: 'all' }
];

export default class LettreModification extends LightningElement {
    importSummaries = [];
    selectedImport = '';

    rawFields = [];
    selectedFields = [];

    lettres = [];
    loading = false;
    updating = false;
    errorMessage = '';

    tablePageSize = '50';
    tableCurrentPage = 1;
    pageSizeOptions = PAGE_SIZE_OPTIONS;
    addFieldValue = '';
    columnsExpanded = true;

    @wire(getImportNames)
    wiredImportNames({ data }) {
        if (data) this.importSummaries = data;
    }

    @wire(getImportableFields, { objectApiName: 'Lettre__c' })
    wiredFields({ data }) {
        if (data) this.rawFields = data;
    }

    get importNameOptions() {
        return (this.importSummaries || []).map((s) => ({
            label: `${s.importName} (${s.count})`,
            value: s.importName
        }));
    }

    get fieldOptions() {
        return (this.rawFields || [])
            .filter((f) => !EXCLUDED_FROM_EDIT.has(f.apiName))
            .map((f) => ({ label: f.label, value: f.apiName }));
    }

    get fieldCheckboxes() {
        const selected = new Set(this.selectedFields);
        return this.fieldOptions.map((f) => ({
            value: f.value,
            label: f.label,
            selected: selected.has(f.value)
        }));
    }

    get allFieldsSelected() {
        return (
            this.fieldOptions.length > 0 &&
            this.selectedFields.length === this.fieldOptions.length
        );
    }

    get selectedCountText() {
        return `${this.selectedFields.length} / ${this.fieldOptions.length} colonne(s) sélectionnée(s)`;
    }

    get columnsToggleIcon() {
        return this.columnsExpanded ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get columnsToggleLabel() {
        return this.columnsExpanded ? 'Masquer' : 'Afficher';
    }

    handleToggleColumns() {
        this.columnsExpanded = !this.columnsExpanded;
    }

    get canSelectFields() {
        return !!this.selectedImport;
    }

    get canLoad() {
        return this.selectedImport && this.selectedFields.length > 0 && !this.loading;
    }

    get loadDisabled() {
        return !this.canLoad;
    }

    get submitDisabled() {
        return !this.hasLettres || this.updating;
    }

    get hasLettres() {
        return this.lettres.length > 0;
    }

    get columnsForDisplay() {
        return this.selectedFields.map((apiName) => {
            const field = this.rawFields.find((f) => f.apiName === apiName);
            const type = field ? String(field.type).toUpperCase() : 'STRING';
            return this.buildColumnMeta(apiName, field, type);
        });
    }

    buildColumnMeta(apiName, field, type) {
        const isPicklist = type === 'PICKLIST';
        const isMultiPicklist = type === 'MULTIPICKLIST';
        const isBoolean = type === 'BOOLEAN';
        const isDate = type === 'DATE';
        const isDateTime = type === 'DATETIME';
        const isNumber = type === 'INTEGER' || type === 'DOUBLE' || type === 'CURRENCY' || type === 'PERCENT';
        let inputType = 'text';
        if (type === 'EMAIL') inputType = 'email';
        else if (type === 'PHONE') inputType = 'tel';
        else if (type === 'URL') inputType = 'url';
        else if (isNumber) inputType = 'number';
        else if (isDate) inputType = 'date';
        else if (isDateTime) inputType = 'datetime-local';
        const picklistOptions = isPicklist
            ? [{ label: '— Aucune —', value: '' }, ...(field?.picklistValues || []).map((p) => {
                if (typeof p === 'string') return { label: p, value: p };
                return { label: p.label || p.value, value: p.value };
            })]
            : [];
        return {
            apiName,
            label: field ? field.label : apiName,
            inputType,
            isPicklist,
            isMultiPicklist,
            isBoolean,
            isStandardInput: !isPicklist && !isBoolean,
            picklistOptions
        };
    }

    get isAllPagesMode() {
        return this.tablePageSize === 'all';
    }

    get totalTablePages() {
        if (this.isAllPagesMode) return 1;
        const size = parseInt(this.tablePageSize, 10);
        return Math.max(1, Math.ceil(this.lettres.length / size));
    }

    get isFirstTablePage() {
        return this.tableCurrentPage <= 1;
    }

    get isLastTablePage() {
        return this.tableCurrentPage >= this.totalTablePages;
    }

    get paginatedLettres() {
        if (this.isAllPagesMode) return this.lettres;
        const size = parseInt(this.tablePageSize, 10);
        const start = (this.tableCurrentPage - 1) * size;
        return this.lettres.slice(start, start + size);
    }

    get displayRows() {
        const cols = this.columnsForDisplay;
        return this.paginatedLettres.map((l) => ({
            Id: l.Id,
            Name: l.Name,
            cells: cols.map((col) => ({
                key: `${l.Id}-${col.apiName}`,
                field: col.apiName,
                label: col.label,
                value: this.normalizeForInput(l[col.apiName], col.inputType, col.isBoolean),
                inputType: col.inputType,
                isPicklist: col.isPicklist,
                isBoolean: col.isBoolean,
                isStandardInput: col.isStandardInput,
                picklistOptions: col.picklistOptions
            }))
        }));
    }

    get pageSummary() {
        return `${this.lettres.length} lettre(s) chargée(s)`;
    }

    normalizeForInput(value, inputType, isBoolean) {
        if (value == null) return isBoolean ? false : '';
        if (isBoolean) return !!value;
        if (inputType === 'date' && typeof value === 'string' && value.length >= 10) {
            return value.substring(0, 10);
        }
        if (inputType === 'datetime-local' && typeof value === 'string' && value.length >= 16) {
            return value.substring(0, 16);
        }
        return value;
    }

    handleImportChange(event) {
        this.selectedImport = event.detail.value;
        this.selectedFields = [];
        this.lettres = [];
    }

    handleFieldsChange(event) {
        this.selectedFields = event.detail.value || [];
        this.lettres = [];
    }

    handleFieldCheckChange(event) {
        const v = event.target.dataset.value;
        const checked = event.target.checked;
        if (checked) {
            if (!this.selectedFields.includes(v)) {
                this.selectedFields = [...this.selectedFields, v];
            }
        } else {
            this.selectedFields = this.selectedFields.filter((f) => f !== v);
        }
        this.lettres = [];
    }

    handleSelectAllFields(event) {
        if (event.target.checked) {
            this.selectedFields = this.fieldOptions.map((f) => f.value);
        } else {
            this.selectedFields = [];
        }
        this.lettres = [];
    }

    handleTablePageSizeChange(event) {
        this.tablePageSize = event.detail.value;
        this.tableCurrentPage = 1;
    }

    handleTablePrev() {
        if (this.tableCurrentPage > 1) this.tableCurrentPage -= 1;
    }

    handleTableNext() {
        if (this.tableCurrentPage < this.totalTablePages) this.tableCurrentPage += 1;
    }

    async handleLoad() {
        if (!this.canLoad) return;
        this.loading = true;
        this.errorMessage = '';
        this.tableCurrentPage = 1;
        try {
            const data = await getLettresByImportName({
                importName: this.selectedImport,
                fieldApiNames: this.selectedFields
            });
            this.lettres = (data || []).map((l) => ({ ...l }));
            if (this.lettres.length === 0) {
                this.errorMessage = 'Aucune lettre trouvée pour cet import.';
            } else {
                this.columnsExpanded = false;
            }
        } catch (e) {
            this.errorMessage =
                'Erreur de chargement : ' + (e?.body?.message || e?.message || JSON.stringify(e));
        } finally {
            this.loading = false;
        }
    }

    handleBulkChange(event) {
        const field = event.target.dataset.field;
        const isBoolean = event.target.type === 'checkbox';
        const value = isBoolean
            ? event.target.checked
            : (event.detail && event.detail.value !== undefined ? event.detail.value : event.target.value);
        this.lettres = this.lettres.map((l) => ({ ...l, [field]: value }));
    }

    handleCellChange(event) {
        const id = event.target.dataset.id;
        const field = event.target.dataset.field;
        const isBoolean = event.target.type === 'checkbox';
        const value = isBoolean
            ? event.target.checked
            : (event.detail && event.detail.value !== undefined ? event.detail.value : event.target.value);
        this.lettres = this.lettres.map((l) =>
            l.Id === id ? { ...l, [field]: value } : l
        );
    }

    async handleSubmit() {
        if (!this.hasLettres || this.updating) return;
        const confirmed = await LightningConfirm.open({
            message: `Confirmer la modification de ${this.lettres.length} lettre(s) ?`,
            variant: 'header',
            label: 'Modification en masse',
            theme: 'info'
        });
        if (!confirmed) return;

        this.updating = true;
        try {
            const records = this.lettres.map((l) => {
                const rec = { Id: l.Id };
                this.selectedFields.forEach((f) => {
                    rec[f] = l[f] == null ? null : l[f];
                });
                return rec;
            });
            await startMassUpdate({ records });
            this.dispatchEvent(new ShowToastEvent({
                title: 'Modification lancée',
                message: `${records.length} lettre(s) en cours de mise à jour. Vous recevrez une notification à la fin.`,
                variant: 'success',
                mode: 'sticky'
            }));
            this.lettres = [];
            this.selectedFields = [];
            this.selectedImport = '';
        } catch (e) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Erreur',
                message: e?.body?.message || e?.message || JSON.stringify(e),
                variant: 'error',
                mode: 'sticky'
            }));
        } finally {
            this.updating = false;
        }
    }
}