import {
    LightningElement,
    wire
} from 'lwc';
import {
    ShowToastEvent
} from 'lightning/platformShowToastEvent';
import {
    createRecord
} from 'lightning/uiRecordApi';
import LightningConfirm from "lightning/confirm";
import {
    NavigationMixin
} from 'lightning/navigation';
import getStockPairs from '@salesforce/apex/Lwc014_GestionStocksController.getStockPairs';
import {
    getPicklistValuesByRecordType
} from "lightning/uiObjectInfoApi";

// import USER_PROFILE_NAME from '@salesforce/schema/User.Profile.Name';
import STOCKS_OBJECT from '@salesforce/schema/STOCK__c';

const NULL_ID_RECORDTYPE = '012000000000000AAA';

const OPT_MARCHANDISES = [{
        label: 'Pompe à chaleur',
        value: 'PAC'
    },
    {
        label: 'ITE',
        value: 'ITE'
    },
    {
        label: 'VMC',
        value: 'VMC'
    },
    {
        label: 'FENETRE',
        value: 'FENETRE'
    },
    {
        label: 'ISO INTERIEUR',
        value: 'ISO INTERIEUR'
    }
]

export default class Lwc014_AjouterNStocks extends NavigationMixin(LightningElement) {


    fournisseursVals = [];
    fournisseursModesRetVals = [];
    fournisseursLivraisonChez = [];
    fournisseursARecupPar = [];

    @wire(getPicklistValuesByRecordType, {
        objectApiName: STOCKS_OBJECT,
        recordTypeId: NULL_ID_RECORDTYPE,
    })
    getPicklists({
        error,
        data
    }) {
        console.log('getPicklists fired');
        console.log('STOCKS_OBJECT', JSON.stringify(STOCKS_OBJECT));
        if (data) {
            console.log('Data', JSON.stringify(data));
            this.fournisseursVals = data.picklistFieldValues.FOURNISSEUR__c?.values;
            this.fournisseursModesRetVals = data.picklistFieldValues.fournisseur_mode_de_retrait__c?.values;
            this.fournisseursLivraisonChez = data.picklistFieldValues.LIVRAISON_CHEZ__c?.values;
            this.fournisseursARecupPar = data.picklistFieldValues.A_Recuperer_Par__c?.values;
        } else if (error) {
            console.error('Error', error);
        }
    }

    optionsMarchandises = OPT_MARCHANDISES;

    formData = {
        recordsToAddCount: 0,
    };

    lines = [];

    initLines(params) {
        this.lines = [];
        this.addLine({
            ...params
        })
    }

    addLine({
        label,
        elements
    }) {
        let id = 'id-' + Math.floor(Math.random() * 99999) + Date.now();
        this.lines.push({
            // generate random between 1 and 99999 id concat with date
            id: id,
            recordsToAddCount: 1,
            recordsToAddCountName: 'records-to-add-count-' + id,
            label: label,
            elements: elements,
            marchandise: 'PAC',
        });
        this.lines = [...this.lines];
    }

    cbMarchandiseChangeHandler(event) {
        const val = event.target.value;
        const field = event.target.dataset.field;

        console.log('Val', val);
        console.log('field', field);
        const dataId = event.target.dataset.id;
        const line = this.lines.find(line => line.id === dataId);
        if (line) {
            line[field] = val;
            if (field == 'fournisseurModes') {
                if (val == 'Livraison') {
                    line.showLivraion = true;
                    line.showRetrait = false;
                } else if (val == 'Retrait sur place') {
                    line.showLivraion = false;
                    line.showRetrait = true;
                }
            }
            this.lines = [...this.lines];
        }
    }

    cbChangeHandler(event) {
        const val = event.target.value;
        const dataId = event.target.dataset.id;
        const line = this.lines.find(line => line.id === dataId);
        if (line) {
            line.elements = val?.replaceAll('\r','')?.split('\n') || [];
            console.log('values :', line.elements);
            this.lines = [...this.lines];
        }
    }

    nbrChangeHandler(event) {
        const val = event.target.value;
        const dataId = event.target.dataset.id;
        const line = this.lines.find(line => line.id === dataId);
        if (line) {
            line.recordsToAddCount = val;
            this.lines = [...this.lines];
        }
    }

    changeHandler(event) {
        const {
            name,
            value,
            checked,
            type
        } = event.target;
        const isCheckbox = type === 'checkbox' || type === 'checkbox-button' || type === 'toggle';
        this.formData = {
            ...this.formData,
            [name]: isCheckbox ? checked : value
        };
    }

    stockPairs = [];
    optionsStocks = [];
    @wire(getStockPairs)
    getStockPairs({
        error,
        data
    }) {
        if (data) {
            console.log('getStockPairs fired');
            console.log('Stock Pairs', JSON.stringify(data));
            this.optionsStocks = data?.map(stock => ({
                label: stock.Label__c,
                value: stock.ElmentsStock__c
            }));
            if (this.optionsStocks?.length > 0) {
                const el1 = this.optionsStocks[0];
                // this.initLines({label: el1.label, elements: el1.value?.split(';') || []});
                this.initLines({
                    label: el1.label,
                    elements: []
                });
            }
        } else if (error) {
            console.error('Error', error);
        }
    }

    addLineHandler(event) {
        this.addLine({});
    }

    deleteHandle(event) {
        const dataId = event.target.dataset.id;
        console.log('Delete', dataId);

        this.lines = this.lines.filter(line => line.id !== dataId);
        if (this.lines.length === 0) {
            this.addLine({});
        }
    }

    // stocksToAdd = [];
    async submitHandler(event) {
        // create array of stocks to add based on the number of stocks to add
        event.preventDefault();
        this.stocksToAdd = Array.from({
            length: 3
        }).map(e => ({}));

        if (!this.formData.recordsToAddCount || this.formData.recordsToAddCount <= 0) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Erreur',
                message: 'Veuillez saisir un nombre positif de stocks à ajouter',
                variant: 'error',
            }));
            return;
        }

        const stocksToAdd = Array.from({
            length: this.formData.recordsToAddCount
        }).map(e => ({}));

        const result = await LightningConfirm.open({
            message: "Voulez-vous vraiment ajouter ces stocks ?",
            variant: "default", // headerless
            label: "Confirmation",
        });

        if (!result) {
            return;
        }
        // console.log("Form Data", JSON.stringify(this.formData));
        const promises = stocksToAdd.map(record => {
            const fields = {};
            const objRecord = {
                apiName: 'STOCK__c',
                fields
            };
            return createRecord(objRecord);
        });

        // Traiter toutes les promesses
        Promise.all(promises)
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Succès',
                        message: 'Tous les enregistrements ont été créés avec succès.',
                        variant: 'success',
                    })
                );
                this[NavigationMixin.Navigate]({
                    type: 'standard__objectPage',
                    attributes: {
                        objectApiName: 'STOCK__c',
                        actionName: 'home',
                    },
                });
                // this.records = [{ Name: '', Description__c: '' }];
            })
            .catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Erreur',
                        message: `Erreur lors de la création : ${error.body.message}`,
                        variant: 'error',
                    })
                );
            });
    }

    // stocksToAdd = [];
    async submitHandlerV2(event) {
        // create array of stocks to add based on the number of stocks to add
        event.preventDefault();


        if (this.lines.some(e => !e.recordsToAddCount || e.recordsToAddCount <= 0)) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Erreur',
                message: 'Veuillez saisir un nombre positif de stocks à ajouter',
                variant: 'error',
            }));
            return;
        }

        if (this.lines.some(e => !e.marchandise || e.marchandise === '')) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Erreur',
                message: 'Veuillez choisir une marchandise',
                variant: 'error',
            }));
            return;
        }

        if (this.lines.some(e => !e.fournisseurModes || e.fournisseurModes === '')) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Erreur',
                message: 'Veuillez choisir une marchandise',
                variant: 'error',
            }));
            return;
        }

        this.lines.forEach(e => {
            e.onAdd = false;
            e.done = false;
            e.failed = false;
        });
        this.lines = [...this.lines];
        let copyLines = JSON.parse(JSON.stringify(this.lines));

        try {
            for (let line of copyLines) {
                // 
                let originalElements = this.lines.find(e => e.id === line.id);
                originalElements.onAdd = true;
                this.lines = [...this.lines];

                const nbrGrp = Array.from({
                    length: line.recordsToAddCount
                }).map(e => ({}));
                for (let grp of nbrGrp) {
                    try {
                        // add groupe: 
                        let stocks = line.elements?.map(e => {
                            let ss = {
                                POMPE_A_CHALEUR__c: e,
                                Marchandise__c: line.marchandise,
                                FOURNISSEUR__c: line.fournisseur,
                                fournisseur_mode_de_retrait__c: line.fournisseurModes,
                                // LIVRAISON_CHEZ__c: line.livraisonChez,
                                // DATE_DE_LIVRAISON__c: line.dateLivraison,
                                // A_Recuperer_Par__c: line.aRecupererPar,
                                // Date_demander_pour_Retrait__c: line.dateDemandeRetrait,
                            };
                            if(line?.showLivraion){
                                ss = {
                                    ...ss,
                                    LIVRAISON_CHEZ__c: line.livraisonChez,
                                    DATE_DE_LIVRAISON__c: line.dateLivraison,
                                }
                            } else if(line?.showRetrait){
                                ss = {
                                    ...ss,
                                    A_Recuperer_Par__c: line.aRecupererPar,
                                    Date_demander_pour_Retrait__c: line.dateDemandeRetrait,
                                }
                            }
                            return ss;
                        });

                        console.log('Stocks', JSON.stringify(stocks));

                        //
                        const promises = stocks.map(record => {
                            const fields = record;
                            const objRecord = {
                                apiName: 'STOCK__c',
                                fields
                            };
                            return createRecord(objRecord);
                        });

                        console.log('Start sendibng records');
                        await Promise.all(promises);
                        originalElements.onAdd = false;
                        originalElements.done = true;
                        this.lines = [...this.lines];

                    } catch (error) {
                        console.error('Error', error);
                        originalElements.onAdd = false;
                        originalElements.failed = true;
                        this.lines = [...this.lines];
                        throw error;
                    }
                }
            }
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Succès',
                    message: 'Tous les enregistrements ont été créés avec succès.',
                    variant: 'success',
                })
            );

            // this[NavigationMixin.Navigate]({
            //     type: 'standard__objectPage',
            //     attributes: {
            //         objectApiName: 'STOCK__c',
            //         actionName: 'home',
            //     },
            // });
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Erreur',
                    message: `Erreur lors de la création : ${error.body.message}`,
                    variant: 'error',
                })
            );
        }
    }

    // confirm:
    async handleCancel() {
        await LightningAlert.open({
            message: 'this is the alert message',
            theme: 'error',
            label: 'Error!',
            variant: 'header',
        });
    }

}