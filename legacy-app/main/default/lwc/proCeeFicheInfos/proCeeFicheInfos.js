import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { getRecord } from 'lightning/uiRecordApi';
import { getRelatedListRecords } from 'lightning/uiRelatedListApi';

// Étape 1 : vérification des champs picklist sur le Pro courant
const PRO_FIELDS = [
    'Pro__c.Opportunite__c',
    'Pro__c.Fiche_CEE__c',

    'Pro__c.PRO_DOSSIER_DESTRAT__c',
    'Pro__c.PRO_DOSSIER_LEDS__c',
    'Pro__c.PRO_DOSSIER_PAC_SEUL__c',
    'Pro__c.PRO_DOSSIER_RENO_GLOBALE__c',
    'Pro__c.PRO_DOSSIER_SERRE_AGRICOLE__c',
    'Pro__c.NEW_PRODUCT_1__c',
    'Pro__c.NEW_PRODUCT_2__c',
    'Pro__c.NEW_PRODUCT_3__c',
    'Pro__c.NEW_PRODUCT_4__c',
    'Pro__c.NEW_PRODUCT_5__c',
];
const NON_DOSSIER  = 'NON';
const NON_PRODUCT  = '❌- NON';
const DOSSIER_KEYS = ['PRO_DOSSIER_DESTRAT__c', 'PRO_DOSSIER_LEDS__c', 'PRO_DOSSIER_PAC_SEUL__c', 'PRO_DOSSIER_RENO_GLOBALE__c', 'PRO_DOSSIER_SERRE_AGRICOLE__c'];
const PRODUCT_KEYS = ['NEW_PRODUCT_1__c', 'NEW_PRODUCT_2__c', 'NEW_PRODUCT_3__c', 'NEW_PRODUCT_4__c', 'NEW_PRODUCT_5__c'];

// Étape 2 : dossiers frères via la liste liée sur l'Opportunité
const DOSSIER_FIELDS = [
    'Pro__c.Id',
    'Pro__c.Fiche_CEE__c',
    'Pro__c.PRO_DOSSIER_PAC_SEUL__c',
    'Pro__c.PRO_DOSSIER_RENO_GLOBALE__c',
    'Pro__c.PAC_STATUT_DOSSIER__c',
    'Pro__c.RENO_TH174_Statut_Dossier__c',
    // fields referenced in fieldsToShowFiches.fieldsToShow
    'Pro__c.INSTALLATIONN_PAC__c',
    'Pro__c.PAC_Date_d_Installation__c',
    'Pro__c.RDV_Date_d_Annulation__c',
    'Pro__c.RDV_Commentaire_Annulation__c',
];

// Mapping Fiche_CEE__c → champ statut correspondant
const FICHE_TO_STATUT = {
    'BAR_TH171- PAC Indiv':     'INSTALLATIONN_PAC__c',
    'BAR_TH174- Réno Glob':     'RENO_TH174_Statut_Dossier__c',
    // 'BAT_TH142- Déstrat':       'INSTALLATION_Destrat__c',
    // 'BAT_EQ127- LEDS':          'INSTALLATION_Leds__c',
    // 'BAR_TH179- PAC Collec':    'INSTALLATION_Serre_Agricole__c',
    // 'AGRI_TH117- DESHU':        'DESHU_TH117_Statut_Dossier__c',
    // 'AGRI_TH119- VMC':          'VMC_TH119_Statut_Installation__c',
    // 'AGRI_EQ112- DPAROIS':      'DPARO_EQ112_Statut_Installation__c',
    // 'AGRI_EQ108- TUBES':        'TUBES_EQ108_Statut_Installation__c',
    // 'BAT_TH163- PAC Tertiaire': 'PAC_TH163_Statut_Installation__c',
};

const fichesToCheck = [
    {
        fiche: 'BAR_TH174- Réno Glob',
        fieldsDemanesAnnulation: ["PAC_171_Annulation__c"],
        checkIn: [
            {
                // fiche:
                field: 'Fiche_CEE__c',
                values: ['BAR_TH171- PAC Indiv'],
            },
            {
                // statut dossier 171
                field: 'PAC_STATUT_DOSSIER__c',
                values: ['🔵DOSSIER- Attente Installation'],
            },
            {
                // creation 171
                field: 'PRO_DOSSIER_PAC_SEUL__c',
                values: ['SansPrevisite'],
            }
        ]
    }, {
        fiche: 'BAR_TH171- PAC Indiv',
        fieldsDemanesAnnulation: ["Annulation_174__c"],
        checkIn: [
            {
                // fiche:
                field: 'Fiche_CEE__c',
                values: ['BAR_TH174- Réno Glob'],
            },
            {
                // statut dossier 174
                field: 'RENO_TH174_Statut_Dossier__c',
                values: ['🔵DOSSIER- Attente Installation'],
            },
            {
                // creation 174
                field: 'PRO_DOSSIER_RENO_GLOBALE__c',
                values: ['SansPrevisite'],
            }
        ]
    }
]


const fieldsToShowByFiche = [
    {
        condition : [
            { field: 'PAC_STATUT_DOSSIER__c', values : ['🔵DOSSIER- Attente Installation'], }
        ],
        sharedFieldsToShow: [
            { label: "Statut Dossier", fieldApiName: 'PAC_STATUT_DOSSIER__c', },
            { label: "Statut Installation", fieldApiName: 'INSTALLATIONN_PAC__c', },
            { label: "Date d'Installation", fieldApiName: 'PAC_Date_d_Installation__c', hideIfEmpty: true },
        ],
        // fiches:[
        //     {
        //         nom: 'BAR_TH174- Réno Glob',
        //         fieldsToShow: 
        //         [
        //             // { label: "Statut Installation", fieldApiName: 'INSTALLATIONN_PAC__c', },
        //             // { label: "Date d'Installation", fieldApiName: 'PAC_Date_d_Installation__c', }
        //         ]
        //     },
        //     {
        //         nom: 'BAR_TH174- Réno Glob',
        //         fieldsToShow: 
        //         [
        //             // { label: "Statut Installation", fieldApiName: 'INSTALLATIONN_PAC__c', },
        //             // { label: "Date d'Installation", fieldApiName: 'PAC_Date_d_Installation__c', }
        //         ]
        //     }
        // ]
    },
    {
        condition : [
            { field: 'PAC_STATUT_DOSSIER__c', values : ['🟢DOSSIER- Installé'], }
        ],
        sharedFieldsToShow: [
            { label: "Statut Dossier", fieldApiName: 'PAC_STATUT_DOSSIER__c', },
            { label: "Date d'Installation", fieldApiName: 'PAC_Date_d_Installation__c', }
        ],
        // fiches:[
        //     {
        //         nom: 'BAR_TH174- Réno Glob',
        //         fieldsToShow: 
        //         [
        //             // { label: "Statut Installation", fieldApiName: 'INSTALLATIONN_PAC__c', },
        //             // { label: "Date d'Installation", fieldApiName: 'PAC_Date_d_Installation__c', }
        //         ]
        //     },
        //     {
        //         nom: 'BAR_TH174- Réno Glob',
        //         fieldsToShow: 
        //         [
        //             // { label: "Statut Installation", fieldApiName: 'INSTALLATIONN_PAC__c', },
        //             // { label: "Date d'Installation", fieldApiName: 'PAC_Date_d_Installation__c', }
        //         ]
        //     }
        // ]
    },
    {
        condition : [
            { field: 'PAC_STATUT_DOSSIER__c', values : ['⚫DOSSIER- Annulé'], }
        ],
        sharedFieldsToShow: [
            { label: "Statut Dossier", fieldApiName: 'PAC_STATUT_DOSSIER__c', },
            { label: "Date d'Annulation",  fieldApiName: 'RDV_Date_d_Annulation__c', },
            { label: "Commentaire Annulation", fieldApiName: 'RDV_Commentaire_Annulation__c', }
        ],
        // fiches:[
        //     {
        //         nom: 'BAR_TH174- Réno Glob',
        //         fieldsToShow: 
        //         [
        //             // { label: "Statut Installation", fieldApiName: 'INSTALLATIONN_PAC__c', },
        //             // { label: "Date d'Installation", fieldApiName: 'PAC_Date_d_Installation__c', }
        //         ]
        //     },
        //     {
        //         nom: 'BAR_TH174- Réno Glob',
        //         fieldsToShow: 
        //         [
        //             // { label: "Statut Installation", fieldApiName: 'INSTALLATIONN_PAC__c', },
        //             // { label: "Date d'Installation", fieldApiName: 'PAC_Date_d_Installation__c', }
        //         ]
        //     }
        // ]
    }
]


export default class ProCeeFicheInfos extends NavigationMixin(LightningElement) {
    @api recordId;
    @api ficheType;

    _proRecord;
    _opportuniteId;
    get opportuniteId() {
        return this._opportuniteId;
    }
    set opportuniteId(value) {
        this._opportuniteId = value;
    }

    currentDossierFiche = { value: '', displayValue: '' };
    @wire(getRecord, { recordId: '$recordId', optionalFields: PRO_FIELDS })
    wiredPro({ data, error }) {
        if (data) {
            console.log('Pro record data:', JSON.stringify(data));
            this._proRecord = data;
            this.currentDossierFiche = {
                value: data.fields.Fiche_CEE__c?.value ?? '',
                displayValue: data.fields.Fiche_CEE__c?.displayValue ?? '',
            };
            console.log('Current dossier fiche:', this.currentDossierFiche);
            this.opportuniteId = data.fields.Opportunite__c?.value;
        } else if (error) {
            console.error('proCeeFicheInfos wiredPro:', error);
        }
    }

    // ── Étape 1 ──────────────────────────────────────────────
    get _actifCount() {
        if (!this._proRecord) return 0;
        const f = this._proRecord.fields;
        let count = 0;
        DOSSIER_KEYS.forEach(k => { if (f[k]?.value && f[k].value !== NON_DOSSIER) count++; });
        PRODUCT_KEYS.forEach(k => { if (f[k]?.value && f[k].value !== NON_PRODUCT) count++; });
        return count;
    }

    get hasMultipleActifs() {
        return this._actifCount >= 2;
    }

    get messageErreur() {
        // TODO : remplacer XXXX par le message souhaité
        return `Nombre de dossiers ouverts en total : ${this._actifCount}`;
    }


    // ── Étape 2 ──────────────────────────────────────────────
    wiredDossiers;
    @wire(getRelatedListRecords, {
        parentRecordId: '$opportuniteId',
        relatedListId: 'Pro__r',
        optionalFields: DOSSIER_FIELDS,
    })
    getWiredDossiers( { data, error }) {
        // console.log('getWiredDossiers data:', JSON.stringify(data));
        // console.log('getWiredDossiers error:', JSON.stringify(error));
        console.log('getWiredDossiers opportuniteId:', this.opportuniteId);
        if (data) {
            console.log('ok getWiredDossiers data:', JSON.stringify(data));
            this.wiredDossiers = data;
        } else if (error) {
            console.error('error getWiredDossiers:', error);
        }
    }

    // get dossiers() {
    //     if (!this.wiredDossiers?.data) return [];
    //     return this.wiredDossiers.data.records.map(r => {
    //         const fiche = r.fields.Fiche_CEE__c?.value ?? '—';
    //         const statutField = FICHE_TO_STATUT[fiche];
    //         const statut = statutField ? (r.fields[statutField]?.value ?? '—') : '—';
    //         return { id: r.fields.Id.value, fiche, statut };
    //     });
    // }

    // get hasDossiers() {
    //     return this.dossiers.length >= 2;
    // }

    // ── Étape 3 ──────────────────────────────────────────────
    get _siblingRecords() {
        if (!this.wiredDossiers?.records) return [];
        // Compare sur 15 premiers chars (case-sensitive) pour neutraliser un éventuel mismatch 15/18.
        // Utilise r.id (toujours peuplé) plutôt que r.fields.Id.value (peut être undefined avec optionalFields).
        const currentId15 = this.recordId?.substring(0, 15);
        if (!currentId15) return this.wiredDossiers.records;
        return this.wiredDossiers.records.filter(r => {
            const rid = r.id || r.fields?.Id?.value;
            return rid && rid.substring(0, 15) !== currentId15;
        });
    }

    get _ficheRule() {
        return fichesToCheck.find(f => f.fiche === this.currentDossierFiche.value);
    }

    get hasFicheMatch() {
        return false; // TODO : réactiver après debug
        const rule = this._ficheRule;
        console.log('Current rule:', JSON.stringify(rule));
        if (!rule) return false;
        console.log('Sibling records to check:', JSON.stringify(this._siblingRecords));
        return this._siblingRecords.some(r =>
            rule.checkIn.every(condition =>
            {
                const fieldValue = r.fields[condition.field]?.value;
                console.log(`Checking sibling record ${r.fields.Id.value} - field ${condition.field}:`, fieldValue);
                return condition.values.includes(fieldValue);
            }
            )
        );
    }

    // get the fieldsDemanesAnnulation of the current fiche rule, or an empty array if no rule matches
    get fieldsDemanesAnnulation() {
        const rule = this._ficheRule;
        return this.hasFicheMatch ? rule.fieldsDemanesAnnulation : [];
    }

    get messageFicheMatch() {
        return `Un dossier frère est en cours d'installation a été détecté pour la fiche ${this.currentDossierFiche.displayValue || this.currentDossierFiche.value}.`;
    }

    // ── Récap autres dossiers (collapse) ─────────────────────
    isOtherDossiersOpen = true;

    toggleOtherDossiers() {
        this.isOtherDossiersOpen = !this.isOtherDossiersOpen;
    }

    get otherDossiersIcon() {
        return this.isOtherDossiersOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get hasSiblingDossiers() {
        console.log('Checking sibling dossiers, count:', this._siblingRecords.length);
        return this._siblingRecords.length > 0;
    }

    get siblingDossiersSummary() {
        return this._siblingRecords.map(r => {
            const fiche = r.fields.Fiche_CEE__c?.value ?? '';
            const ficheDisplay = r.fields.Fiche_CEE__c?.displayValue ?? fiche;

            let displayFields = [];
            for (const entry of fieldsToShowByFiche) {
                const conditionMet = entry.condition.every(c => {
                    const fieldValue = r.fields[c.field]?.value;
                    return c.values.includes(fieldValue);
                });
                if (conditionMet) {
                    displayFields = entry.sharedFieldsToShow.reduce((acc, f) => {
                        const value = r.fields[f.fieldApiName]?.value ?? null;
                        if (f.hideIfEmpty && !value) return acc;
                        acc.push({ label: f.label, value: value ?? '—' });
                        return acc;
                    }, []);
                    break;
                }
            }

            return {
                id: r.fields.Id?.value,
                fiche: ficheDisplay || fiche || '—',
                fields: displayFields,
            };
        });
    }

    navigateToDossier(event) {
        const recordId = event.currentTarget.dataset.id;
        this[NavigationMixin.GenerateUrl]({
            type: 'standard__recordPage',
            attributes: { recordId, actionName: 'view' },
        }).then(url => window.open(url, '_blank'));
    }
}