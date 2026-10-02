import { LightningElement, api, wire } from 'lwc';
// import { getListRecordsByName } from 'lightning/uiRelatedListApi';
import { getListRecordsByName } from "lightning/uiListsApi";
import { getListInfoByName } from "lightning/uiListsApi";
import getDepartements from '@salesforce/apex/DepartementController.getDepartements';


// import getOpportunities from '@salesforce/apex/Lwc005CalculDurationController.getOpportunities';

const NOMINATIM_API_BASE_URL = 'https://nominatim.openstreetmap.org/search';
const OSRM_API_BASE_URL = 'http://router.project-osrm.org/route/v1/driving';
const FETCH_DELAY = 10; // 1 second delay between API calls
const DEFAULT_COORDINATES = '0,0';

export default class Lwc016CalculDurationDynamic extends LightningElement {
    @api objectApiName;
    @api fieldCordonnees = 'CoordonneesGPS__c';
    @api fieldCodePostal = 'CodePostal__c';
    @api listViewName;
    @api pageSize = 10;

    records = [];
    filteredRecords = [];
    paginatedRecords = [];
    columns = [];
    searchTerm = '';
    currentPage = 1;
    totalPages = 1;
    isLoading = false;
    error;
    listInfo;

    _fieldsToQuery;
    @api
    get fieldsToQuery() {
        return this._fieldsToQuery;
    }
    set fieldsToQuery(value) {
        this._fieldsToQuery = value;
    }

    @wire(getListInfoByName, {
        objectApiName: '$objectApiName',
        listViewApiName: '$listViewName'
    })
    wiredListInfo({ error, data }) {
        if (data) {
            // console.log('List Info Data:', JSON.stringify(data));
            this.listInfo = data;

            this.columns = data.displayColumns.map(col => ({
                label: col.label,
                fieldName: col.fieldApiName,
                // type: this.getFieldType(col.dataType)
                type: 'text',
                isRealField: true,
                hideFromTable: this.fieldCordonnees === col.fieldApiName // hide the coordinates field
            }));

            // insert first :
            this.columns.unshift({
                label: 'Durée',
                fieldName: 'duree',
                isSortable: true
            });
            this.fieldsToQuery = this.columns.filter(col => col.isRealField).map(col => this.objectApiName + '.' + col.fieldName);
            // console.log('fieldsToQuery:', JSON.stringify(this.fieldsToQuery));
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.listInfo = null;
            this.columns = [];
        }
    }

    @wire(getListRecordsByName, {
        objectApiName: '$objectApiName',
        listViewApiName: '$listViewName',
        fields: '$fieldsToQuery',
        pageSize: 2000
    })
    wiredRecords({ error, data }) {
        this.isLoading = true;
        if (data && this.fieldsToQuery?.length > 0) {
            // console.log('Records Data:', JSON.stringify(data));
            this.records = data.records.map(record => {
                let processedRecord = {
                    Id: record.id,
                    fields: []
                };

                this.columns.forEach(col => {
                    const fieldValue = this.getFieldValue(record.fields, col.fieldName);
                    processedRecord.fields.push({
                        hideFromTable: col.hideFromTable,
                        name: col.fieldName,
                        value: fieldValue,
                        // columnFieldName: col.fieldName,
                        columnLabel: col.label,
                        isMatch: false
                    });
                });

                // console.log('Processed Record:', JSON.stringify(processedRecord));

                return processedRecord;
            });

            // console.log('Processed Records:', JSON.stringify(this.records));

            this.filteredRecords = [...this.records];
            this.updatePagination();
            this.error = undefined;
            this.isLoading = false;
        } else if (error) {
            this.error = error;
            this.records = [];
            this.isLoading = false;
        }
    }

    departements = [];
    @wire(getDepartements, {

    })
    wiredDepartements({ error, data }) {
        if (data) {
            // console.log('Departements Data:', JSON.stringify(data));
            this.departements = data?.map(dept => ({
                label: dept.MasterLabel,
                value: dept.MasterLabel,
                voisins: dept.DepartementsVoisins__c?.split(",") || []
            })) || [];
            // console.log('Processed Departements:', JSON.stringify(this.departements));
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.departements = [];
        }
    }
    getFieldValue(fields, fieldName) {
        if(fieldName.endsWith('.Name')) {
            const relField = fieldName.split('.').slice(0, -1).join('.');
            if (fields[relField] && fields[relField].value) {
                return fields[relField].value?.fields?.Name?.value || fields[relField].value.displayValue || fields[relField].value;
            } else {
                console.log(`Related Field ${relField} not found in record fields. fields:`, JSON.stringify(fields));
                return '';
            }
        } else {
            return fields[fieldName] ? fields[fieldName].value : '';
        }
    }

    getFieldType(dataType) {
        const typeMap = {
            'String': 'text',
            'Currency': 'currency',
            'Date': 'date',
            'DateTime': 'date',
            'Percent': 'percent',
            'Phone': 'phone',
            'Email': 'email',
            'Url': 'url',
            'Boolean': 'boolean'
        };
        return typeMap[dataType] || 'text';
    }

    handleSearch(event) {
        this.searchTerm = event.target.value.toLowerCase();
        this.currentPage = 1;
        this.filterRecords();
    }

    filterRecords() {
        if (!this.searchTerm) {
            this.filteredRecords = [...this.records];
        } else {
            this.filteredRecords = this.records.filter(record => {
                return this.columns.some(col => {
                    // const value = record[col.fieldName];
                    const field = record.fields?.find(f => f.name === col.fieldName);
                    return field && field.value.toString().toLowerCase().includes(this.searchTerm);
                });
            });
        }
        this.updatePagination();
    }

    updatePagination() {
        this.totalPages = Math.ceil(this.filteredRecords.length / this.pageSize);
        this.paginateRecords();
    }

    paginateRecords() {
        const start = (this.currentPage - 1) * this.pageSize;
        const end = start + this.pageSize;
        // this.paginatedRecords = this.filteredRecords.slice(start, end);
        this.paginatedRecords = this.filteredRecords;
    }

    handlePrevious() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.paginateRecords();
        }
    }

    handleNext() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            this.paginateRecords();
        }
    }

    get isPreviousDisabled() {
        return this.currentPage === 1;
    }

    get isNextDisabled() {
        return this.currentPage === this.totalPages || this.totalPages === 0;
    }

    get showingFrom() {
        return this.filteredRecords.length === 0 ? 0 : (this.currentPage - 1) * this.pageSize + 1;
    }

    get showingTo() {
        const to = this.currentPage * this.pageSize;
        return to > this.filteredRecords.length ? this.filteredRecords.length : to;
    }

    get totalRecords() {
        return this.filteredRecords.length;
    }

    get hasRecords() {
        return this.paginatedRecords.length > 0;
    }

    codePostal = '';
    handlePostalCodeChange(event) {
        this.codePostal = event.target.value;
    }

    async CalculerDurationHandle() {
        try {
            console.log('Starting duration calculation for postal code:', this.codePostal);
            if(!this.codePostal || this.codePostal.length < 2) {
                this.errorMessage = 'Veuillez entrer un code postal valide.';
                console.warn('Invalid postal code entered:', this.codePostal);
                return;
            }
            this.errorMessage = '';
            await this.getLatLngCodePostal();
            if (this.canSearch) {
                this.isLoading = true;
                // reset old reselts:
                this.resetDurationsHandle();

                console.log('Starting duration calculations for records...');
                await this.calculDurations();
                this.isLoading = false;
                this.sortDescHandle();

            }
        } catch (error) {
            this.isLoading = false;
            console.error('Error in calculation:', JSON.stringify(error));
        }
    }

    resetDurationsHandle() {
        console.log('Resetting durations for all records...');
        this.paginatedRecords = this.paginatedRecords.map(record => {
            let fdDuration = record.fields.find(f => f.name === 'duree');
            // fdDuration.value = -1;
            // fdDuration.bdgClass = 'slds-badge slds-badge_inverse';
            fdDuration.bdgClass = '';
            fdDuration.value = '';
            record.durationInSec = null;
            return record;
        });
    }

    errorMessage = '';
    async getLatLngCodePostal() {
        try {
            const params = new URLSearchParams({
                q: this.codePostal,
                format: 'json',
                limit: '1',
                countrycodes: 'FR'
            });

            const response = await fetch(`${NOMINATIM_API_BASE_URL}?${params}`);
            const [data] = await response.json();
            // console.log('Nominatim response data:', JSON.stringify(data));

            if (data?.lat && data?.lon) {
                this.startLocation = { lat: data.lat, lon: data.lon };
                this.errorMessage = '';
                // console.log('Fetched location:', JSON.stringify(this.startLocation));
                this.canSearch = true;
            } else {
                this.errorMessage = 'Aucune localisation trouvée pour ce code postal.';
                console.warn('No location found for postal code:', this.codePostal);
                this.canSearch = false;
            }
        } catch (error) {
            this.canSearch = false;
            console.error('Error fetching location:', error);
        }
    }

    async calculDurations() {
        const depart = this.codePostal.substring(0, 2);
        const departement = this.departements.find(dept => dept.value === depart);
        if (departement) {
            console.log('Departement found:', JSON.stringify(departement));
        } else {
            // console.warn('No departement found for code:', depart);
        }

        console.log('Filtering records for duration calculation...');
        const validRecords = this.paginatedRecords.filter(opp => 
            // opp[this.fieldCordonnees] !== DEFAULT_COORDINATES 
            // && 
            (departement && departement.voisins.some(voisin => opp.fields?.find(f => f.name == this.fieldCodePostal)?.value?.startsWith(voisin)))) || [];
        if(validRecords.length === 0) {
            console.warn('No valid records found for duration calculation.');
            this.errorMessage = 'Aucun dossier valide trouvé pour le calcul de la durée.';
            return;
        } else {
            console.log('Valid records for duration calculation:', JSON.stringify(validRecords));
        }
        this.errorMessage = '';
        for (const record of validRecords) {
            console.log('Calculating duration for record Id:', record.Id);
            await this.processRecordsDuration(record);
            await this.delay(FETCH_DELAY);
        }
    }

    async processRecordsDuration(record) {
        try {
            console.log('Starts Processing record:', JSON.stringify(record));
            const [lat, lon] = record.fields.find(f => f.name === this.fieldCordonnees).value.split(',');
            const locTo = { lat, lon };
            console.log('Destination location:', JSON.stringify(locTo));

            const duration = await this.calculOneDuration(this.startLocation, locTo);
            record.fields.find(f => f.name === 'duree').value = duration;
            record = this.updateDurationDisplay(record);
            // update filteredRecords to trigger reactivity
            this.paginatedRecords = this.paginatedRecords.map(r => r.Id === record.Id ? record : r);
            console.log('Finished Processing record Id:', record.Id, 'Record ', JSON.stringify(record));
        } catch (error) {
            console.error('Error processing duration:', JSON.stringify(error));
            // record.Duration = -2;
            record.fields.find(f => f.name === 'duree').value = -2;
            this.updateDurationDisplay(record);
        }
    }

    async calculOneDuration(locFrom, locTo) {
        if (!this.isValidLocation(locFrom) || !this.isValidLocation(locTo)) {
            console.warn('Invalid locations for duration calculation:', JSON.stringify(locFrom), JSON.stringify(locTo));
            return -2;
        }

        try {
            console.log('Calculating duration from', JSON.stringify(locFrom), 'to', JSON.stringify(locTo));
            const url = `${OSRM_API_BASE_URL}/${locFrom.lon},${locFrom.lat};${locTo.lon},${locTo.lat}?overview=false`;
            const response = await fetch(url);
            const data = await response.json();
            console.log('OSRM response data:', JSON.stringify(data));
            return data.routes[0]?.duration ?? -2;
        } catch (error) {
            console.error('Error calculating duration:', error);
            return -2;
        }
    }

    isValidLocation(loc) {
        return loc?.lat && loc?.lon;
    }

    updateDurationDisplay(record) {
        let fdDuration = record.fields.find(f => f.name === 'duree');
        fdDuration.isFieldDuree = true;
        if (fdDuration.value >= 0) {
            record.durationInSec = fdDuration.value;
            fdDuration.value = this.convertSecToHeureMinutes(fdDuration.value);
            // fdDuration.durationInSec = fdDuration.value;
            fdDuration.bdgClass = 'slds-badge slds-theme_success';
        } else if (fdDuration.value === -1) {
            fdDuration.bdgClass = 'slds-badge slds-badge_inverse';
            fdDuration.value = "Non calculé";
        } else {
            fdDuration.bdgClass = 'slds-badge slds-theme_error';
            fdDuration.value = "Erreur";
        }
        return record;
    }

    convertSecToHeureMinutes(seconds) {
        if (seconds < 0) return "Erreur";
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        return `${hours}h${minutes}min`;
    }

    delay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

    sortOpportunities(ascending = true) {
        console.log('Records before sorting:', JSON.stringify(this.paginatedRecords));
        const sortedList = [...this.paginatedRecords].sort((a, b) => {
            return ascending ? (a.durationInSec || 0 ) - (b.durationInSec || 0) : (b.durationInSec || 0) - (a.durationInSec || 0);
        });
        // this.paginatedRecords = sortedList;
        //this.paginatedRecords = sortedList.map(r => r);
        // refresh paginatedRecords to lwc can trigger change:
        this.paginatedRecords = sortedList.map(r => r);
    }

    sortAscHandle() {
        this.sortOpportunities(true);
    }

    sortDescHandle() {
        this.sortOpportunities(false);
    }
}