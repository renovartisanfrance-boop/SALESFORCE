import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getObjectFields from '@salesforce/apex/LC022CatalogueTarifaireController.getObjectFields';
import getCatalogueLigne from '@salesforce/apex/LC022CatalogueTarifaireController.getCatalogueLigne';
import saveCatalogueLigne from '@salesforce/apex/LC022CatalogueTarifaireController.saveCatalogueLigne';
import verifierChevauchement from '@salesforce/apex/LC022CatalogueTarifaireController.verifierChevauchement';
import getAccountsByIds from '@salesforce/apex/LC022CatalogueTarifaireController.getAccountsByIds';
import getRecordTypeIds from '@salesforce/apex/LC022CatalogueTarifaireController.getRecordTypeIds';
import { getPicklistValuesByRecordType } from 'lightning/uiObjectInfoApi';
import {
    AVAILABLE_FUNCTIONS,
    OPERATOR_INSERTS,
    extractFields,
    formatForDisplay,
    validateFormula,
    legacyTokensToExpression,
    legacyFactorFieldToExpression
} from 'c/lwc022FormulaUtils';
import { detectRuleConflicts } from 'c/lwc022RuleConflicts';

const DOSSIER_OBJECT = 'Pro__c';
const CATALOGUE_OBJECT = 'CatalogueTarifaire__c';

// Champs fixes de la ligne de catalogue (écran 1). Ordre d'affichage (un champ
// par ligne) : Fiche + période de validité, puis Statut, Rôle. Les intervenants
// (multi-comptes) sont gérés à part via un sélecteur dédié (champ Intervenants__c).
const CATALOGUE_FIELDS = [
    'FicheCEE__c',
    'DateDebutValidite__c',
    'DateFinValidite__c',
    'Statut__c',
    'Montants_modifiables__c',
    'RoleIntervenant__c',
    // Sens du paiement (Émis/Reçu) : affiché et obligatoire pour le Standard seul.
    'Paiement__c',
    // Masquées de l'étape 1 (échéances par règle), gardées pour leurs options.
    'EcheancePaiement1__c',
    'EcheancePaiement2__c',
    // Échéance des lignes « Supplémentaire » (picklist dépendante du rôle), rendue
    // à part (options filtrées par rôle via la dépendance), gardée ici pour son label.
    'echeanceSupp__c'
];

// Record Types du catalogue (DeveloperName) + libellés.
const RECORD_TYPE_OPTIONS = [
    { label: 'Standard', value: 'Standard' },
    { label: 'Supplémentaire', value: 'Supplementaire' },
    { label: 'Acompte', value: 'Acompte' }
];
const RT_STANDARD = 'Standard';
const RT_SUPPLEMENTAIRE = 'Supplementaire';
// Acompte : comme Supplémentaire (montant unique, pas de Montant 2) mais SANS
// échéance du tout et avec Fiche CEE FACULTATIVE.
const RT_ACOMPTE = 'Acompte';
const ECHEANCE_SUPP_FIELD = 'echeanceSupp__c';
const ROLE_FIELD = 'RoleIntervenant__c';
// Sens du paiement (picklist Émis/Reçu) : propre au Standard, obligatoire, défaut « Émis ».
const PAIEMENT_FIELD = 'Paiement__c';
const PAIEMENT_DEFAULT = 'Emis';

// Ordre des étapes du wizard (navigation par le path cliquable).
const STEP_ORDER = ['infos', 'variables', 'regles'];

// Champs affichés en demi-largeur (deux côte à côte sur la même ligne) à l'étape 1.
const HALF_ROW_FIELDS = ['Statut__c', 'Montants_modifiables__c'];

// Séparateur des IDs de comptes concaténés dans CatalogueTarifaire__c.Intervenants__c.
const INTERVENANT_SEP = ';';

// Champs obligatoires : tous sauf Intervenant (facultatif) et les 2 échéances.
const REQUIRED_FIELDS = [
    'FicheCEE__c',
    'RoleIntervenant__c',
    'Statut__c',
    'DateDebutValidite__c',
    'DateFinValidite__c'
];

// Échéances de paiement : masquées de l'étape 1, désormais choisies PAR RÈGLE
// (écran 3), appariées au montant — échéance 1 ↔ Montant Base 1, échéance 2 ↔
// Montant Base 2. On garde leur describe (via CATALOGUE_FIELDS) uniquement pour
// récupérer leurs valeurs de picklist (identiques pour 1 et 2).
const ECHEANCE_FIELDS = ['EcheancePaiement1__c', 'EcheancePaiement2__c'];

const COMPARISON_OPTIONS = [
    { label: 'Valeur exacte', value: 'exact' },
    { label: 'Intervalle', value: 'interval' }
];

// Opérateurs disponibles PAR CELLULE pour une condition de type picklist :
//  - exact : égal à une valeur unique ;
//  - in    : « une parmi » plusieurs valeurs (OU) ;
//  - notIn : « différent de » plusieurs valeurs (exclusion).
// (Le moteur — LC022/LC023/LC024 ruleMatches — lit ce `comparison` par cellule.)
const PICKLIST_OPERATOR_OPTIONS = [
    { label: 'Égal à', value: 'exact' },
    { label: 'Une parmi', value: 'in' },
    { label: 'Différent de', value: 'notIn' }
];
const MULTI_OPERATORS = ['in', 'notIn'];

const MONTANT_MODE_OPTIONS = [
    { label: 'Montant fixe', value: 'fixed' },
    { label: 'Formule', value: 'formula' }
];

const BOOLEAN_OPTIONS = [
    { label: 'Vrai', value: 'true' },
    { label: 'Faux', value: 'false' }
];

/**
 * Onglet 2 : assistant de création / modification d'une ligne de catalogue.
 *  Étape 1 « Informations » : champs fixes du catalogue.
 *  Étape 2 « Variables »    : sélection des variables de décision du dossier
 *                             + mode de comparaison (exact / intervalle).
 *  Étape 3 « Règles »       : pour chaque combinaison de valeurs, montants 1 et 2
 *                             (fixe ou formule = facteur × champ du dossier).
 * Le tout est sérialisé en JSON dans ParametresFiche__c (le calcul des montants
 * se fera ailleurs, depuis le dossier).
 */
export default class Lwc022CatalogueForm extends LightningElement {
    @api recordId; // édition d'une ligne existante
    @api cloneId; // duplication : pré-remplit depuis cette ligne, mais crée une NOUVELLE ligne

    currentStep = 'infos';
    loading = false;

    catalogueFields = [];
    dossierFields = [];
    dossierFieldMap = {};

    fixedValues = {};
    selectedVariables = [];
    rules = [];
    collapsedMap = {}; // id de règle -> repliée (récap au lieu des inputs)
    intervenants = []; // comptes sélectionnés : [{ id, name }] -> Intervenants__c concaténé

    recordType = ''; // Record Type DeveloperName : Standard | Supplementaire
    supplementaireRtId; // id du RT Supplémentaire (pour la picklist dépendante)
    echeanceSuppPicklist; // valeurs dépendantes de echeanceSupp__c (par rôle)

    searchTerm = '';
    _ruleSeq = 0;

    // Picklist dépendante echeanceSupp__c (contrôlée par RoleIntervenant__c), lue
    // sur le Record Type Supplémentaire : fournit controllerValues + validFor.
    @wire(getPicklistValuesByRecordType, { objectApiName: CATALOGUE_OBJECT, recordTypeId: '$supplementaireRtId' })
    wiredCataloguePicklists({ data }) {
        this.echeanceSuppPicklist = data && data.picklistFieldValues
            ? data.picklistFieldValues[ECHEANCE_SUPP_FIELD]
            : undefined;
    }

    // ----------------------------------------------------------------- lifecycle

    async connectedCallback() {
        this.loading = true;
        try {
            const [catFields, dosFields, rtIds] = await Promise.all([
                getObjectFields({ objectApiName: CATALOGUE_OBJECT, fieldApiNames: CATALOGUE_FIELDS }),
                getObjectFields({ objectApiName: DOSSIER_OBJECT, fieldApiNames: [] }),
                getRecordTypeIds({ objectApiName: CATALOGUE_OBJECT })
            ]);
            this.supplementaireRtId = (rtIds && rtIds[RT_SUPPLEMENTAIRE]) || null;
            // Conserver l'ordre déclaré pour les champs fixes du catalogue.
            const catByApi = {};
            catFields.forEach((f) => {
                catByApi[f.apiName] = f;
            });
            this.catalogueFields = CATALOGUE_FIELDS.map((api) => catByApi[api]).filter(Boolean);

            this.dossierFields = dosFields;
            this.dossierFieldMap = {};
            dosFields.forEach((f) => {
                this.dossierFieldMap[f.apiName] = f;
            });

            if (this.recordId) {
                await this.loadFrom(this.recordId);
            } else if (this.cloneId) {
                // Duplication : on charge la ligne source mais recordId reste null -> création.
                await this.loadFrom(this.cloneId);
            } else {
                // Création : statut par défaut « Active » (aligné sur le défaut du champ).
                this.fixedValues = { Statut__c: 'Active' };
            }
        } catch (e) {
            this.toast('Erreur', this.reduceError(e), 'error');
        } finally {
            this.loading = false;
        }
    }

    async loadFrom(recordId) {
        const record = await getCatalogueLigne({ recordId });
        // Record Type de la ligne source (édition ou duplication).
        if (record.RecordType && record.RecordType.DeveloperName) {
            this.recordType = record.RecordType.DeveloperName;
        }
        const values = {};
        CATALOGUE_FIELDS.forEach((api) => {
            if (record[api] !== undefined && record[api] !== null) {
                values[api] = record[api];
            }
        });
        this.fixedValues = values;

        // Intervenants (multi-comptes) : depuis le champ Intervenants__c (IDs concaténés).
        const ids = this.parseIntervenantIds(record.Intervenants__c);
        this.intervenants = ids.map((id) => ({ id, name: id }));
        this.syncIntervenants();
        if (ids.length) {
            this.resolveIntervenantNames(ids);
        }

        if (record.ParametresFiche__c) {
            try {
                const parsed = JSON.parse(record.ParametresFiche__c);
                this.selectedVariables = Array.isArray(parsed.decisionVariables)
                    ? parsed.decisionVariables.map((v) => ({
                          field: v.field,
                          label: v.label || this.labelFor(v.field),
                          type: v.type || (this.dossierFieldMap[v.field] || {}).dataType || 'text',
                          comparison: v.comparison || 'exact'
                      }))
                    : [];
                // Repli migration : une ancienne ligne dont les montants n'ont pas
                // d'échéance dans le JSON reprend l'échéance du champ fixe correspondant
                // (1↔EcheancePaiement1__c, 2↔EcheancePaiement2__c). La réédition n'exige
                // donc aucune ressaisie et le save complète la migration vers le JSON.
                this.rules = Array.isArray(parsed.rules)
                    ? parsed.rules.map((r) => ({
                          id: 'r' + this._ruleSeq++,
                          commentaire: r.commentaire || '',
                          conditions: r.conditions || {},
                          montant1: this.normalizeMontant(r.montant1, record.EcheancePaiement1__c),
                          montant2: this.normalizeMontant(r.montant2, record.EcheancePaiement2__c),
                          designation: r.designation || '' // gabarit de désignation Acompte
                      }))
                    : [];
                // Vue d'ensemble : règles existantes repliées par défaut.
                const collapsed = {};
                this.rules.forEach((r) => {
                    collapsed[r.id] = true;
                });
                this.collapsedMap = collapsed;
            } catch (e) {
                this.toast('Avertissement', 'Les paramètres existants sont illisibles et ont été ignorés.', 'warning');
            }
        }
    }

    // ----------------------------------------------------------------- steps

    get steps() {
        return [
            { label: 'Informations', value: 'infos' },
            { label: 'Variables de décision', value: 'variables' },
            { label: 'Règles & montants', value: 'regles' }
        ];
    }

    get isStepInfos() {
        return this.currentStep === 'infos';
    }
    get isStepVariables() {
        return this.currentStep === 'variables';
    }
    get isStepRegles() {
        return this.currentStep === 'regles';
    }

    async handleNext() {
        await this.advanceOneStep();
    }

    // Avance d'une étape en appliquant les vérifications de l'étape COURANTE (mêmes
    // règles que « Suivant »). Renvoie true si l'avancée a eu lieu, false si une
    // vérification a échoué (le toast a alors déjà été affiché).
    async advanceOneStep() {
        if (this.currentStep === 'infos') {
            if (!this.rtSelected) {
                this.toast('Type requis', 'Choisissez d\'abord le type d\'enregistrement.', 'warning');
                return false;
            }
            if (!this.validateRenderedInputs()) {
                return false;
            }
            const infos = this.validateInfos();
            if (!infos.ok) {
                this.toast('Champs requis', infos.message, 'warning');
                return false;
            }
            if (this.isSupplementaire && !this.fixedValues[ECHEANCE_SUPP_FIELD]) {
                this.toast('Échéance requise', 'Sélectionnez l\'échéance (« ' + this.echeanceSuppLabel + ' »).', 'warning');
                return false;
            }
            // Blocage du chevauchement : on ne passe pas à l'écran suivant si une
            // ligne ACTIVE couvre déjà la même clé sur une période qui se recoupe.
            // Ce contrôle est la règle STANDARD (Fiche + rôle + intervenant). Le
            // Supplémentaire et l'Acompte n'ont AUCUN contrôle de chevauchement.
            if (!this.isLigneUnique) {
                const conflit = await this.checkChevauchement();
                if (conflit) {
                    this.toast(
                        'Chevauchement',
                        'Une ligne de catalogue active (' +
                            conflit +
                            ') couvre déjà la même Fiche CEE, le même rôle et le même intervenant ' +
                            'sur une période qui se recoupe. Ajustez les dates ou le statut.',
                        'error'
                    );
                    return false;
                }
            }
            this.currentStep = 'variables';
            return true;
        } else if (this.currentStep === 'variables') {
            this.currentStep = 'regles';
            return true;
        }
        return false;
    }

    // Clic sur une étape du path : même rôle que « Suivant ». En AVANT, on applique
    // les mêmes vérifications que « Suivant » étape par étape (pas de saut sans
    // valider) ; sur l'étape courante ou en ARRIÈRE, navigation libre (comme « Retour »).
    async handleStepClick(event) {
        const target = event.currentTarget.dataset.step;
        if (!target) return;
        await this.goToStep(target);
    }

    async goToStep(target) {
        const ti = STEP_ORDER.indexOf(target);
        if (ti < 0) return;
        if (ti <= STEP_ORDER.indexOf(this.currentStep)) {
            // Étape courante ou en arrière : autorisé sans validation.
            this.currentStep = target;
            return;
        }
        // En avant : on avance d'une étape à la fois en validant chacune ; on
        // s'arrête dès qu'une vérification échoue (l'utilisateur reste sur l'étape).
        while (STEP_ORDER.indexOf(this.currentStep) < ti) {
            // eslint-disable-next-line no-await-in-loop
            const ok = await this.advanceOneStep();
            if (!ok) return;
        }
    }

    // Renvoie le N° de la ligne en conflit (chevauchement), ou null. En cas d'échec
    // de la vérification, on n'empêche pas l'avancée : le trigger reste le garde-fou.
    async checkChevauchement() {
        this.loading = true;
        try {
            return await verifierChevauchement({
                recordId: this.recordId || null,
                fields: this.fixedValues
            });
        } catch (e) {
            return null;
        } finally {
            this.loading = false;
        }
    }


    handleBack() {
        if (this.currentStep === 'regles') {
            this.currentStep = 'variables';
        } else if (this.currentStep === 'variables') {
            this.currentStep = 'infos';
        }
    }

    // Valide les champs requis de l'étape actuellement rendue (seule l'étape
    // active est dans le DOM grâce aux lwc:if).
    validateRenderedInputs() {
        const inputs = [
            ...this.template.querySelectorAll('.pf-card lightning-input, .pf-card lightning-combobox')
        ];
        return inputs.reduce((valid, el) => {
            const ok = typeof el.reportValidity === 'function' ? el.reportValidity() : true;
            return valid && ok;
        }, true);
    }

    // Champs obligatoires selon le type : pour l'Acompte la Fiche CEE est
    // FACULTATIVE (Standard et Supplémentaire l'exigent).
    get requiredFields() {
        const base = this.isAcompte ? REQUIRED_FIELDS.filter((f) => f !== 'FicheCEE__c') : REQUIRED_FIELDS;
        // Le sens du paiement (Émis/Reçu) est obligatoire pour le Standard uniquement.
        return this.isStandard ? [...base, PAIEMENT_FIELD] : base;
    }

    // Valide l'étape 1 : champs obligatoires (les échéances sont désormais
    // choisies par règle à l'écran 3, voir findMissingEcheance()).
    validateInfos() {
        const labelByApi = {};
        this.catalogueFields.forEach((f) => {
            labelByApi[f.apiName] = f.label;
        });
        const missing = this.requiredFields.filter((api) => !this.fixedValues[api]);
        if (missing.length) {
            return {
                ok: false,
                message: 'Champs obligatoires manquants : ' + missing.map((a) => labelByApi[a] || a).join(', ') + '.'
            };
        }
        return { ok: true };
    }

    // ----------------------------------------------------- step 1 : champs fixes

    get catalogueInputs() {
        // Les échéances ne sont plus saisies ici : elles sont choisies par règle
        // (écran 3), appariées au montant. On les exclut donc de l'étape 1.
        return this.catalogueFields
            // Le paiement (Émis/Reçu) est rendu à part, juste après le type (hors grille).
            .filter(
                (f) =>
                    !ECHEANCE_FIELDS.includes(f.apiName) &&
                    f.apiName !== ECHEANCE_SUPP_FIELD &&
                    f.apiName !== PAIEMENT_FIELD
            )
            .map((f) => {
                const value = this.fixedValues[f.apiName];
                let options = (f.picklistValues || []).map((p) => ({ label: p.label, value: p.value }));
                // Supplémentaire : ne proposer que les rôles ayant au moins une
                // échéance supplémentaire valide (dépendance echeanceSupp__c).
                if (this.isSupplementaire && f.apiName === ROLE_FIELD) {
                    const allowed = this.rolesWithEcheanceSupp;
                    if (allowed) {
                        options = options.filter((o) => allowed.has(o.value));
                    }
                }
                return {
                    apiName: f.apiName,
                    label: f.label,
                    cssClass: HALF_ROW_FIELDS.includes(f.apiName) ? 'pf-field pf-field-half' : 'pf-field',
                    required: this.requiredFields.includes(f.apiName),
                    isPicklist: f.dataType === 'picklist',
                    isNumber: f.dataType === 'number',
                    isDate: f.dataType === 'date',
                    isDatetime: f.dataType === 'datetime',
                    isLookup: f.dataType === 'reference',
                    isCheckbox: f.dataType === 'boolean',
                    isText: f.dataType === 'text',
                    referenceTo: f.referenceTo,
                    options,
                    value: value === undefined || value === null ? '' : String(value),
                    checked: value === true || value === 'true',
                    lookupValue: value === undefined || value === null || value === '' ? null : String(value)
                };
            });
    }

    // Options d'échéance de paiement pour le montant `num` (1 ou 2). Les deux
    // picklists ont les mêmes valeurs ; on lit celle du champ correspondant.
    echeanceOptionsForNum(num) {
        const api = String(num) === '2' ? 'EcheancePaiement2__c' : 'EcheancePaiement1__c';
        const f = this.catalogueFields.find((c) => c.apiName === api);
        return ((f && f.picklistValues) || []).map((p) => ({ label: p.label, value: p.value }));
    }

    handleFixedChange(event) {
        const api = event.target.dataset.field;
        this.fixedValues = { ...this.fixedValues, [api]: this.readVal(event) };
    }

    // --------------------------------------- Record Type & échéance supplémentaire

    get recordTypeOptions() {
        return RECORD_TYPE_OPTIONS;
    }
    get rtSelected() {
        return !!this.recordType;
    }
    // Type figé en édition (recordId) ; modifiable en création/duplication.
    get rtLocked() {
        return !!this.recordId;
    }
    // Mode édition (ligne existante) : autorise « Enregistrer » depuis les 3 écrans.
    get isEditMode() {
        return !!this.recordId;
    }
    get isStandard() {
        return this.recordType === RT_STANDARD;
    }
    get isSupplementaire() {
        return this.recordType === RT_SUPPLEMENTAIRE;
    }
    get isAcompte() {
        return this.recordType === RT_ACOMPTE;
    }
    // « Ligne à montant unique » : Supplémentaire OU Acompte (un seul montant, pas
    // de Montant 2, pas d'échéance par règle). Distinct de isSupplementaire, qui
    // reste réservé à l'échéance ligne (echeanceSupp__c) — absente de l'Acompte.
    get isLigneUnique() {
        return this.isSupplementaire || this.isAcompte;
    }

    // Paiement (Émis/Reçu) : rendu à part, juste après le type d'enregistrement
    // (Standard uniquement). Options issues du describe ; valeur dans fixedValues.
    get paiementField() {
        return this.catalogueFields.find((f) => f.apiName === PAIEMENT_FIELD);
    }
    get paiementLabel() {
        const f = this.paiementField;
        return f ? f.label : 'Paiement';
    }
    get paiementValue() {
        const v = this.fixedValues[PAIEMENT_FIELD];
        return v === undefined || v === null ? '' : String(v);
    }
    get paiementOptions() {
        const f = this.paiementField;
        return ((f && f.picklistValues) || []).map((p) => ({ label: p.label, value: p.value }));
    }

    handleRecordTypeChange(event) {
        this.recordType = this.readVal(event) || '';
        // Paiement (Émis/Reçu) : propre au Standard. À la sélection du Standard on
        // pré-remplit « Émis » (modifiable) ; pour les autres types on vide la valeur.
        const paiement = this.isStandard ? this.fixedValues[PAIEMENT_FIELD] || PAIEMENT_DEFAULT : '';
        this.fixedValues = { ...this.fixedValues, [PAIEMENT_FIELD]: paiement };
        if (!this.isSupplementaire) {
            // Type Standard : on vide l'échéance ligne (propre aux Supplémentaire).
            this.fixedValues = { ...this.fixedValues, [ECHEANCE_SUPP_FIELD]: '' };
            return;
        }
        // Supplémentaire : si le rôle déjà choisi n'a pas d'échéance supplémentaire,
        // il n'est plus proposé -> on le vide (avec son échéance) pour éviter une
        // sélection invalide restée affichée.
        const allowed = this.rolesWithEcheanceSupp;
        const role = this.fixedValues[ROLE_FIELD];
        if (allowed && role && !allowed.has(role)) {
            this.fixedValues = { ...this.fixedValues, [ROLE_FIELD]: '', [ECHEANCE_SUPP_FIELD]: '' };
        }
    }

    get echeanceSuppField() {
        return this.catalogueFields.find((f) => f.apiName === ECHEANCE_SUPP_FIELD);
    }
    get echeanceSuppLabel() {
        const f = this.echeanceSuppField;
        return f ? f.label : 'Échéance';
    }
    get echeanceSuppValue() {
        const v = this.fixedValues[ECHEANCE_SUPP_FIELD];
        return v === undefined || v === null ? '' : String(v);
    }
    // Rôles (RoleIntervenant__c) ayant au moins une échéance supplémentaire valide
    // : valeur contrôlante référencée par le validFor d'au moins une valeur dépendante.
    // null tant que la picklist dépendante n'est pas chargée (on ne filtre pas alors).
    get rolesWithEcheanceSupp() {
        const pl = this.echeanceSuppPicklist;
        if (!pl || !pl.controllerValues || !Array.isArray(pl.values)) return null;
        const set = new Set();
        Object.keys(pl.controllerValues).forEach((role) => {
            const idx = pl.controllerValues[role];
            const hasEch = pl.values.some(
                (v) => Array.isArray(v.validFor) && v.validFor.includes(idx)
            );
            if (hasEch) set.add(role);
        });
        return set;
    }

    // Options dépendantes du rôle sélectionné (validFor de la picklist dépendante).
    get echeanceSuppOptions() {
        const pl = this.echeanceSuppPicklist;
        const role = this.fixedValues.RoleIntervenant__c;
        if (!pl || !role) return [];
        const idx = pl.controllerValues ? pl.controllerValues[role] : undefined;
        if (idx === undefined || idx === null) return [];
        return (pl.values || [])
            .filter((v) => Array.isArray(v.validFor) && v.validFor.includes(idx))
            .map((v) => ({ label: v.label, value: v.value }));
    }

    // Lookup (lightning-record-picker) : la valeur est l'Id du compte sélectionné.
    handleLookupChange(event) {
        const api = event.target.dataset.field;
        const recordId = (event.detail && event.detail.recordId) || null;
        this.fixedValues = { ...this.fixedValues, [api]: recordId };
    }

    // ------------------------------------ step 1 : intervenants (multi-comptes)

    get intervenantPills() {
        return this.intervenants;
    }
    get hasIntervenants() {
        return this.intervenants.length > 0;
    }

    // Ajout d'un compte via le record-picker, puis vidage du picker pour le suivant.
    handleAddIntervenant(event) {
        const id = (event.detail && event.detail.recordId) || null;
        const picker = event.target;
        if (!id) {
            return; // événement de vidage (clearSelection) : rien à faire
        }
        if (picker && typeof picker.clearSelection === 'function') {
            picker.clearSelection();
        }
        if (this.intervenants.some((x) => x.id === id)) {
            return; // compte déjà présent
        }
        this.intervenants = [...this.intervenants, { id, name: id }];
        this.syncIntervenants();
        this.resolveIntervenantNames([id]);
    }

    handleRemoveIntervenant(event) {
        const id = event.currentTarget.dataset.id;
        this.intervenants = this.intervenants.filter((x) => x.id !== id);
        this.syncIntervenants();
    }

    // Reflète la sélection dans fixedValues.Intervenants__c (IDs concaténés).
    syncIntervenants() {
        const ids = this.intervenants.map((x) => x.id);
        this.fixedValues = { ...this.fixedValues, Intervenants__c: ids.join(INTERVENANT_SEP) };
    }

    parseIntervenantIds(raw) {
        if (!raw) return [];
        const seen = new Set();
        const out = [];
        String(raw)
            .split(INTERVENANT_SEP)
            .forEach((s) => {
                const id = s.trim();
                if (id && !seen.has(id)) {
                    seen.add(id);
                    out.push(id);
                }
            });
        return out;
    }

    // Résout les libellés (Name) des comptes pour l'affichage des pills.
    async resolveIntervenantNames(ids) {
        try {
            const accounts = await getAccountsByIds({ accountIds: ids });
            const byId = {};
            (accounts || []).forEach((a) => {
                byId[a.Id] = a.Name;
            });
            this.intervenants = this.intervenants.map((x) => ({ id: x.id, name: byId[x.id] || x.name }));
        } catch (e) {
            // Échec de résolution : on garde l'Id comme libellé (non bloquant).
        }
    }

    // ----------------------------------------------- step 2 : variables de décision

    handleSearch(event) {
        this.searchTerm = (event.target.value || '').toLowerCase();
    }

    get filteredDossierFields() {
        const term = this.searchTerm;
        const selectedSet = new Set(this.selectedVariables.map((v) => v.field));
        return this.dossierFields
            .filter((f) => {
                if (!term) return true;
                return (
                    f.label.toLowerCase().includes(term) ||
                    f.apiName.toLowerCase().includes(term)
                );
            })
            .slice(0, 200)
            .map((f) => ({
                apiName: f.apiName,
                label: f.label,
                dataType: f.dataType,
                selected: selectedSet.has(f.apiName)
            }));
    }

    get selectedVariablesView() {
        return this.selectedVariables.map((v) => ({
            field: v.field,
            label: v.label,
            type: v.type,
            comparison: v.comparison,
            showComparison: v.type === 'number' || v.type === 'date' || v.type === 'datetime',
            comparisonOptions: COMPARISON_OPTIONS,
            typeLabel: this.typeLabel(v.type)
        }));
    }

    get hasSelectedVariables() {
        return this.selectedVariables.length > 0;
    }

    handleToggleVariable(event) {
        const api = event.target.dataset.field;
        const checked = event.target.checked;
        if (checked) {
            const desc = this.dossierFieldMap[api];
            if (!desc) return;
            this.selectedVariables = [
                ...this.selectedVariables,
                { field: api, label: desc.label, type: desc.dataType, comparison: 'exact' }
            ];
        } else {
            this.selectedVariables = this.selectedVariables.filter((v) => v.field !== api);
            // Nettoyer les conditions correspondantes dans les règles.
            this.rules = this.rules.map((r) => {
                const conditions = { ...r.conditions };
                delete conditions[api];
                return { ...r, conditions };
            });
        }
    }

    handleComparisonChange(event) {
        const api = event.target.dataset.field;
        const value = this.readVal(event);
        this.selectedVariables = this.selectedVariables.map((v) =>
            v.field === api ? { ...v, comparison: value } : v
        );
    }

    handleRemoveVariable(event) {
        const api = event.currentTarget.dataset.field;
        this.selectedVariables = this.selectedVariables.filter((v) => v.field !== api);
        this.rules = this.rules.map((r) => {
            const conditions = { ...r.conditions };
            delete conditions[api];
            return { ...r, conditions };
        });
    }

    // ----------------------------------------------------- step 3 : règles

    get ruleColumns() {
        return this.selectedVariables.map((v) => ({ key: v.field, label: v.label }));
    }

    get numericDossierOptions() {
        return this.dossierFields
            .filter((f) => f.dataType === 'number')
            .map((f) => ({ label: f.label, value: f.apiName }));
    }

    // Ensemble des API names de champs numériques (autorisés dans les formules).
    get numericFieldApiSet() {
        return new Set(this.dossierFields.filter((f) => f.dataType === 'number').map((f) => f.apiName));
    }

    // API name -> libellé (pour l'aperçu lisible des formules).
    get dossierLabelByApi() {
        const map = {};
        this.dossierFields.forEach((f) => {
            map[f.apiName] = f.label;
        });
        return map;
    }

    get operatorChips() {
        return OPERATOR_INSERTS;
    }

    get functionChips() {
        return AVAILABLE_FUNCTIONS.map((f) => ({ key: f.name, label: f.name, snippet: f.snippet, title: f.help }));
    }

    // Valeur figée à vide pour que le combobox « Insérer un champ » agisse comme
    // un bouton d'action (se réinitialise après chaque sélection).
    get blankValue() {
        return '';
    }

    // Booléen pour activer resetonselect sur le sélecteur de champ de la formule.
    get resetTrue() {
        return true;
    }

    // Conflits entre règles (détection front, « première règle qui matche gagne »).
    get ruleConflicts() {
        return detectRuleConflicts(this.rules, this.selectedVariables);
    }
    // Bandeau récapitulatif affiché en haut de l'écran « Règles ».
    get ruleConflictBanner() {
        const conflicts = this.ruleConflicts;
        const nums = [];
        let danger = false;
        conflicts.forEach((c, i) => {
            if (c.hasConflict) {
                nums.push(i + 1);
                if (c.level === 'danger') danger = true;
            }
        });
        if (!nums.length) return null;
        return {
            danger,
            class: danger ? 'pf-rule-conflict-banner pf-conflict-danger' : 'pf-rule-conflict-banner pf-conflict-warning',
            text:
                (danger ? 'Conflit entre règles' : 'Chevauchement entre règles') +
                ' — vérifiez la cohérence des règles ' +
                nums.join(', ') +
                ' avant d’enregistrer.'
        };
    }

    get ruleViews() {
        const total = this.rules.length;
        const conflicts = this.ruleConflicts;
        return this.rules.map((rule, index) => {
            const collapsed = !!this.collapsedMap[rule.id];
            const conflict = conflicts[index] || { hasConflict: false, level: null, message: '' };
            return {
                id: rule.id,
                index: index + 1,
                isFirst: index === 0,
                isLast: index === total - 1,
                collapsed,
                collapseIcon: collapsed ? 'utility:chevronright' : 'utility:chevrondown',
                commentaire: rule.commentaire || '',
                summary: this.buildSummary(rule),
                cells: this.selectedVariables.map((v) => this.buildCell(v, rule)),
                montants: this.isLigneUnique
                    ? [{ ...this.buildMontant(rule, 1), label: 'Montant' }]
                    : [
                          { ...this.buildMontant(rule, 1), label: 'Montant Base 1' },
                          { ...this.buildMontant(rule, 2), label: 'Montant Base 2' }
                      ],
                designation: rule.designation || '',
                designationPreview: this.formatDesignationPreview(rule.designation || ''),
                hasConflict: conflict.hasConflict,
                conflictMessage: conflict.message,
                conflictBadgeClass:
                    conflict.level === 'danger'
                        ? 'pf-rule-conflict pf-conflict-danger'
                        : 'pf-rule-conflict pf-conflict-warning',
                conflictLabel: conflict.level === 'danger' ? 'Conflit' : 'Chevauchement',
                rowClass: conflict.hasConflict ? 'pf-rule pf-rule-flagged' : 'pf-rule'
            };
        });
    }

    // Options du sélecteur « Insérer un champ » de la désignation Acompte : tous les
    // champs du dossier, préfixés « dossier. » (la valeur portera le placeholder).
    get designationDossierOptions() {
        return this.dossierFields.map((f) => ({ label: f.label, value: 'dossier.' + f.apiName }));
    }
    // … et les champs (fixes) du catalogue tarifaire, préfixés « catalogue. ».
    get designationCatalogueOptions() {
        return this.catalogueFields.map((f) => ({ label: f.label, value: 'catalogue.' + f.apiName }));
    }

    // Aperçu lisible du gabarit : {dossier.X}/{catalogue.X} -> «Libellé». La valeur
    // réelle est résolue côté serveur à la création de la facture d'acompte.
    formatDesignationPreview(tpl) {
        if (!tpl) return '';
        return tpl.replace(/\{(dossier|catalogue)\.([^}]+)\}/g, (whole, src, api) => {
            const key = api.trim();
            const label =
                src === 'dossier'
                    ? (this.dossierFieldMap[key] || {}).label
                    : (this.catalogueFields.find((c) => c.apiName === key) || {}).label;
            return '«' + (label || key) + '»';
        });
    }

    // Récap lecture seule d'une règle (affiché quand elle est repliée).
    buildSummary(rule) {
        const conditions = this.selectedVariables.map((v) => ({
            key: v.field,
            text: v.label + ' ' + this.conditionText(v, (rule.conditions && rule.conditions[v.field]) || {})
        }));
        return {
            hasConditions: conditions.length > 0,
            conditions,
            montant1Text: this.montantText(rule.montant1),
            montant2Text: this.montantText(rule.montant2),
            showMontant2: !this.isLigneUnique,
            hasComment: !!(rule.commentaire && rule.commentaire.trim())
        };
    }

    conditionText(variable, cond) {
        if (variable.comparison === 'interval') {
            const fmt = (x) => (x === undefined || x === null || x === '' ? '…' : x);
            return '∈ [' + fmt(cond.min) + ' – ' + fmt(cond.max) + ']';
        }
        // Multi-valeurs picklist : « ∈ {…} » (une parmi) / « ∉ {…} » (différent de).
        if (cond && MULTI_OPERATORS.includes(cond.comparison) && Array.isArray(cond.values)) {
            const desc = this.dossierFieldMap[variable.field] || {};
            const labels = cond.values.map((val) => {
                const opt = (desc.picklistValues || []).find((p) => String(p.value) === String(val));
                return opt ? opt.label : val;
            });
            const joined = labels.length ? labels.join(', ') : '—';
            return (cond.comparison === 'in' ? '∈ {' : '∉ {') + joined + '}';
        }
        let val = cond.value;
        if (variable.type === 'picklist') {
            const desc = this.dossierFieldMap[variable.field] || {};
            const opt = (desc.picklistValues || []).find((p) => String(p.value) === String(val));
            if (opt) val = opt.label;
        } else if (variable.type === 'boolean') {
            val = val === 'true' || val === true ? 'Vrai' : 'Faux';
        }
        return '= ' + (val === undefined || val === null || val === '' ? '—' : val);
    }

    montantText(m) {
        if (!m) return '—';
        let base;
        if (m.mode === 'formula') {
            const expr = (m.expression || '').trim();
            base = expr ? formatForDisplay(expr, this.dossierLabelByApi) : '—';
        } else {
            const v = m.value;
            base = v === undefined || v === null || v === '' ? '—' : v + ' €';
        }
        // Échéance appariée affichée dans le récap replié.
        return m.echeance ? base + ' → ' + m.echeance : base;
    }

    get hasRules() {
        return this.rules.length > 0;
    }

    buildCell(variable, rule) {
        const cond = (rule.conditions && rule.conditions[variable.field]) || {};
        const desc = this.dossierFieldMap[variable.field] || {};
        const type = variable.type;
        const interval = variable.comparison === 'interval';
        const isPicklist = type === 'picklist';
        const options = (desc.picklistValues || []).map((p) => ({ label: p.label, value: p.value }));

        // Opérateur PAR CELLULE (picklist uniquement) : exact | in | notIn (défaut exact).
        const operator = isPicklist && MULTI_OPERATORS.includes(cond.comparison) ? cond.comparison : 'exact';
        const isMulti = isPicklist && operator !== 'exact';
        // Valeurs multiples -> pills {value, label}. Le picker d'ajout ne propose que
        // les valeurs pas encore choisies.
        const chosen = isMulti && Array.isArray(cond.values) ? cond.values.map((x) => String(x)) : [];
        const labelByValue = {};
        options.forEach((o) => {
            labelByValue[String(o.value)] = o.label;
        });
        const selectedPills = chosen.map((val) => ({
            key: rule.id + ':' + variable.field + ':' + val,
            value: val,
            label: labelByValue[val] || val
        }));
        const chosenSet = new Set(chosen);
        const remainingOptions = options.filter((o) => !chosenSet.has(String(o.value)));

        return {
            key: rule.id + ':' + variable.field,
            ruleId: rule.id,
            field: variable.field,
            label: variable.label,
            isPicklist,
            isPicklistExact: isPicklist && !isMulti,
            isPicklistMulti: isMulti,
            operator,
            operatorOptions: PICKLIST_OPERATOR_OPTIONS,
            isBoolean: type === 'boolean',
            isExactText: (type === 'text' || type === 'reference') && !interval,
            isExactNumber: type === 'number' && !interval,
            isIntervalNumber: type === 'number' && interval,
            isExactDate: type === 'date' && !interval,
            isIntervalDate: type === 'date' && interval,
            isExactDatetime: type === 'datetime' && !interval,
            isIntervalDatetime: type === 'datetime' && interval,
            options,
            remainingOptions,
            selectedPills,
            hasSelectedPills: selectedPills.length > 0,
            booleanOptions: BOOLEAN_OPTIONS,
            value: cond.value === undefined || cond.value === null ? '' : String(cond.value),
            min: cond.min === undefined || cond.min === null ? '' : String(cond.min),
            max: cond.max === undefined || cond.max === null ? '' : String(cond.max)
        };
    }

    buildMontant(rule, num) {
        const m = rule['montant' + num] || { mode: 'fixed' };
        const mode = m.mode || 'fixed';
        const expression = m.expression || '';
        const hasExpression = expression.trim().length > 0;
        const validation = hasExpression
            ? validateFormula(expression, this.numericFieldApiSet)
            : { valid: false, error: null };
        return {
            num: String(num),
            mode,
            isFixed: mode === 'fixed',
            isFormula: mode === 'formula',
            value: m.value === undefined || m.value === null ? '' : String(m.value),
            modeOptions: MONTANT_MODE_OPTIONS,
            expression,
            hasExpression,
            expressionValid: validation.valid,
            expressionError: validation.error,
            expressionPreview: hasExpression ? formatForDisplay(expression, this.dossierLabelByApi) : '',
            fieldOptions: this.numericDossierOptions,
            echeance: m.echeance === undefined || m.echeance === null ? '' : String(m.echeance),
            echeanceOptions: this.echeanceOptionsForNum(num),
            // Échéance par règle uniquement pour Standard. Supplémentaire = échéance
            // ligne (echeanceSupp__c) ; Acompte = aucune échéance.
            showEcheance: !this.isLigneUnique
        };
    }

    handleAddRule() {
        this.rules = [
            ...this.rules,
            {
                id: 'r' + this._ruleSeq++,
                commentaire: '',
                conditions: {},
                montant1: { mode: 'fixed' },
                montant2: { mode: 'fixed' },
                designation: '' // gabarit de désignation (RT Acompte uniquement)
            }
        ];
    }

    handleRemoveRule(event) {
        const id = event.currentTarget.dataset.id;
        this.rules = this.rules.filter((r) => r.id !== id);
    }

    handleRuleComment(event) {
        const ruleId = event.target.dataset.id;
        const val = event.target.value;
        this.updateRule(ruleId, (r) => {
            r.commentaire = val;
        });
    }

    // Réordonnancement (↑ / ↓) pour la lisibilité.
    handleMoveRule(event) {
        const id = event.currentTarget.dataset.id;
        const dir = event.currentTarget.dataset.dir; // up | down
        const idx = this.rules.findIndex((r) => r.id === id);
        if (idx < 0) return;
        const target = dir === 'up' ? idx - 1 : idx + 1;
        if (target < 0 || target >= this.rules.length) return;
        const next = [...this.rules];
        [next[idx], next[target]] = [next[target], next[idx]];
        this.rules = next;
    }

    handleToggleCollapse(event) {
        const id = event.currentTarget.dataset.id;
        this.collapsedMap = { ...this.collapsedMap, [id]: !this.collapsedMap[id] };
    }

    // Duplique une règle (copie conditions + montants + note) juste en dessous,
    // dépliée pour être ajustée sans tout re-saisir.
    handleDuplicateRule(event) {
        const id = event.currentTarget.dataset.id;
        const idx = this.rules.findIndex((r) => r.id === id);
        if (idx < 0) return;
        const copy = JSON.parse(JSON.stringify(this.rules[idx]));
        copy.id = 'r' + this._ruleSeq++;
        const next = [...this.rules];
        next.splice(idx + 1, 0, copy);
        this.rules = next;
        // La copie n'est pas dans collapsedMap -> affichée dépliée pour édition.
    }

    handleConditionChange(event) {
        const ruleId = event.target.dataset.rule;
        const field = event.target.dataset.field;
        const part = event.target.dataset.part; // value | min | max
        const val = this.readVal(event);
        const variable = this.selectedVariables.find((v) => v.field === field);
        this.updateRule(ruleId, (r) => {
            const conditions = { ...r.conditions };
            const current = { ...(conditions[field] || {}) };
            current.comparison = variable ? variable.comparison : 'exact';
            current[part] = val;
            conditions[field] = current;
            r.conditions = conditions;
        });
    }

    // Changement d'opérateur d'une cellule picklist (exact | in | notIn). On convertit
    // la saisie en cours pour ne rien perdre : exact -> multi amorce la liste avec la
    // valeur exacte ; multi -> exact reprend la 1re valeur choisie.
    handleConditionOperator(event) {
        const ruleId = event.target.dataset.rule;
        const field = event.target.dataset.field;
        const op = this.readVal(event);
        this.updateRule(ruleId, (r) => {
            const conditions = { ...r.conditions };
            const current = { ...(conditions[field] || {}) };
            if (op === 'exact') {
                const first =
                    Array.isArray(current.values) && current.values.length
                        ? current.values[0]
                        : current.value;
                conditions[field] = {
                    comparison: 'exact',
                    value: first === undefined || first === null ? '' : first
                };
            } else {
                let values = Array.isArray(current.values) ? current.values.slice() : [];
                if (!values.length && current.value !== undefined && current.value !== null && current.value !== '') {
                    values = [current.value];
                }
                conditions[field] = { comparison: op, values };
            }
            r.conditions = conditions;
        });
    }

    // Ajout d'une valeur à une condition multi (in/notIn) via le picker de recherche.
    handleAddConditionValue(event) {
        const ruleId = event.target.dataset.rule;
        const field = event.target.dataset.field;
        const val = (event.detail && event.detail.value) || event.target.value;
        if (!val) return;
        this.updateRule(ruleId, (r) => {
            const conditions = { ...r.conditions };
            const current = { ...(conditions[field] || {}) };
            const comparison = current.comparison === 'notIn' ? 'notIn' : 'in';
            const values = Array.isArray(current.values) ? current.values.slice() : [];
            if (!values.map((x) => String(x)).includes(String(val))) {
                values.push(val);
            }
            conditions[field] = { comparison, values };
            r.conditions = conditions;
        });
    }

    handleRemoveConditionValue(event) {
        const ruleId = event.currentTarget.dataset.rule;
        const field = event.currentTarget.dataset.field;
        const val = event.currentTarget.dataset.value;
        this.updateRule(ruleId, (r) => {
            const conditions = { ...r.conditions };
            const current = { ...(conditions[field] || {}) };
            const comparison = current.comparison === 'notIn' ? 'notIn' : 'in';
            const values = (Array.isArray(current.values) ? current.values : []).filter(
                (x) => String(x) !== String(val)
            );
            conditions[field] = { comparison, values };
            r.conditions = conditions;
        });
    }

    handleMontantMode(event) {
        const ruleId = event.target.dataset.rule;
        const num = event.target.dataset.montant;
        const mode = this.readVal(event);
        this.updateRule(ruleId, (r) => {
            const existing = r['montant' + num] || {};
            // L'échéance choisie est appariée au montant : on la conserve quand on
            // bascule entre montant fixe et formule.
            const echeance = existing.echeance || '';
            if (mode === 'formula') {
                const expression = typeof existing.expression === 'string' ? existing.expression : '';
                r['montant' + num] = { mode: 'formula', expression, echeance };
            } else {
                r['montant' + num] = { mode: 'fixed', value: '', echeance };
            }
        });
    }

    // Échéance de paiement appariée au montant (1 ↔ Montant Base 1, 2 ↔ Base 2).
    handleMontantEcheance(event) {
        const ruleId = event.target.dataset.rule;
        const num = event.target.dataset.montant;
        const val = this.readVal(event);
        this.updateRule(ruleId, (r) => {
            const m = { ...(r['montant' + num] || { mode: 'fixed' }) };
            m.echeance = val;
            r['montant' + num] = m;
        });
    }

    // Montant fixe : saisie de la valeur unique.
    handleMontantPart(event) {
        const ruleId = event.target.dataset.rule;
        const num = event.target.dataset.montant;
        const part = event.target.dataset.part; // value
        const val = this.readVal(event);
        this.updateRule(ruleId, (r) => {
            const m = { ...(r['montant' + num] || { mode: 'fixed' }) };
            m[part] = val;
            r['montant' + num] = m;
        });
    }

    // --- Éditeur de formule (expression texte type Salesforce/Excel) ---

    handleExpressionChange(event) {
        const ruleId = event.target.dataset.rule;
        const num = event.target.dataset.montant;
        const val = this.readVal(event);
        this.updateRule(ruleId, (r) => {
            const m = r['montant' + num] || { mode: 'formula' };
            m.expression = val;
            r['montant' + num] = m;
        });
    }

    // Combobox « Insérer un champ » : ajoute {API} à la formule.
    handleInsertField(event) {
        const ruleId = event.target.dataset.rule;
        const num = event.target.dataset.montant;
        const api = (event.detail && event.detail.value) || event.target.value;
        if (api) {
            this.appendToExpression(ruleId, num, `{${api}}`);
        }
    }

    // Puces fonctions / opérateurs / parenthèses.
    handleInsertSnippet(event) {
        const ruleId = event.currentTarget.dataset.rule;
        const num = event.currentTarget.dataset.montant;
        const snippet = event.currentTarget.dataset.snippet;
        this.appendToExpression(ruleId, num, snippet);
    }

    handleClearFormula(event) {
        const ruleId = event.currentTarget.dataset.rule;
        const num = event.currentTarget.dataset.montant;
        this.updateRule(ruleId, (r) => {
            const m = r['montant' + num] || { mode: 'formula' };
            m.expression = '';
            r['montant' + num] = m;
        });
    }

    appendToExpression(ruleId, num, snippet) {
        this.updateRule(ruleId, (r) => {
            const m = r['montant' + num] || { mode: 'formula', expression: '' };
            m.expression = (m.expression || '') + snippet;
            r['montant' + num] = m;
        });
    }

    // --- Désignation Acompte (gabarit texte : littéral + {dossier.X}/{catalogue.X}) ---

    handleDesignationChange(event) {
        const ruleId = event.target.dataset.rule;
        const val = this.readVal(event);
        this.updateRule(ruleId, (r) => {
            r.designation = val;
        });
    }

    // Un seul handler pour les 2 sélecteurs : la valeur porte déjà le préfixe
    // (dossier.X / catalogue.X) ; on l'insère sous forme de placeholder {…}.
    handleInsertDesignationField(event) {
        const ruleId = event.target.dataset.rule;
        const token = (event.detail && event.detail.value) || event.target.value;
        if (token) {
            this.appendToDesignation(ruleId, `{${token}}`);
        }
    }

    handleClearDesignation(event) {
        const ruleId = event.currentTarget.dataset.rule;
        this.updateRule(ruleId, (r) => {
            r.designation = '';
        });
    }

    appendToDesignation(ruleId, snippet) {
        this.updateRule(ruleId, (r) => {
            r.designation = (r.designation || '') + snippet;
        });
    }

    updateRule(ruleId, mutator) {
        this.rules = this.rules.map((r) => {
            if (r.id !== ruleId) return r;
            const copy = JSON.parse(JSON.stringify(r));
            mutator(copy);
            return copy;
        });
    }

    // ----------------------------------------------------- sauvegarde

    get saveLabel() {
        if (this.recordId) return 'Enregistrer les modifications';
        if (this.cloneId) return 'Créer la copie';
        return 'Créer la ligne';
    }

    // Bloque la sauvegarde en cas de conflit BLOQUANT entre règles : niveau « danger »
    // = doublon (conditions identiques) ou règle inaccessible (déjà couverte par une
    // règle antérieure). Le simple chevauchement (warning) reste permis, le moteur le
    // tranchant par l'ordre (première règle qui matche gagne). Renvoie un message ou null.
    findBlockingRuleConflict() {
        const nums = [];
        this.ruleConflicts.forEach((c, i) => {
            if (c.hasConflict && c.level === 'danger') nums.push(i + 1);
        });
        if (!nums.length) return null;
        return (
            'Des règles sont en conflit (doublon ou règle inaccessible) : ' +
            nums.join(', ') +
            '. Corrigez ou supprimez les règles en conflit avant d’enregistrer.'
        );
    }

    async handleSave() {
        // Commit d'une éventuelle saisie en cours : les champs (commentaire, formule,
        // montant fixe…) ne valident leur valeur qu'au blur. On force le blur du champ
        // actif puis on laisse l'événement se propager avant de sérialiser.
        const active = this.template.activeElement;
        if (active && typeof active.blur === 'function') {
            active.blur();
            await Promise.resolve();
        }

        const infos = this.validateInfos();
        if (!infos.ok) {
            this.toast('Champs requis', infos.message, 'warning');
            this.currentStep = 'infos';
            return;
        }
        if (!this.hasRules) {
            this.toast('Aucune règle', 'Ajoutez au moins une règle de tarification.', 'warning');
            return;
        }
        const formulaError = this.findInvalidFormula();
        if (formulaError) {
            this.toast('Formule invalide', formulaError, 'warning');
            this.currentStep = 'regles';
            return;
        }
        const echeanceError = this.findMissingEcheance();
        if (echeanceError) {
            this.toast('Échéance requise', echeanceError, 'warning');
            this.currentStep = 'regles';
            return;
        }
        const conflictError = this.findBlockingRuleConflict();
        if (conflictError) {
            this.toast('Conflit entre règles', conflictError, 'error');
            this.currentStep = 'regles';
            return;
        }

        const parametres = this.buildParametres();
        this.loading = true;
        try {
            // TRANSITION : l'échéance « vérité » est désormais PAR RÈGLE dans
            // parametres (montant1/montant2.echeance). Les champs fixes
            // EcheancePaiement1__c/2__c restent envoyés tels quels (présents dans
            // fixedValues en édition d'une ancienne ligne) tant que la facturation
            // V2 les lit encore — à retirer du payload lors de la migration V2.
            const savedId = await saveCatalogueLigne({
                recordId: this.recordId || null,
                fields: this.fixedValues,
                parametresFiche: JSON.stringify(parametres),
                recordTypeDevName: this.recordType || null
            });
            this.toast('Enregistré', 'La ligne de catalogue a été enregistrée.', 'success');
            this.dispatchEvent(new CustomEvent('saved', { detail: { recordId: savedId } }));
        } catch (e) {
            this.toast('Erreur', this.reduceError(e), 'error');
        } finally {
            this.loading = false;
        }
    }

    buildParametres() {
        const toNumber = (x) => (x === '' || x === null || x === undefined ? null : Number(x));
        const rules = this.rules.map((r) => {
            const conditions = {};
            this.selectedVariables.forEach((v) => {
                const c = (r.conditions && r.conditions[v.field]) || {};
                if (v.comparison === 'interval') {
                    conditions[v.field] = {
                        comparison: 'interval',
                        min: v.type === 'number' ? toNumber(c.min) : c.min || null,
                        max: v.type === 'number' ? toNumber(c.max) : c.max || null
                    };
                } else if (v.type === 'picklist' && MULTI_OPERATORS.includes(c.comparison)) {
                    // « Une parmi » (in) / « Différent de » (notIn) : liste de valeurs.
                    const values = (Array.isArray(c.values) ? c.values : []).filter(
                        (x) => x !== null && x !== undefined && x !== ''
                    );
                    // Liste vide -> aucune contrainte (équivalent d'une valeur exacte vidée).
                    conditions[v.field] = values.length
                        ? { comparison: c.comparison, values }
                        : { comparison: 'exact', value: null };
                } else {
                    let exactValue;
                    if (v.type === 'number') {
                        exactValue = toNumber(c.value);
                    } else if (v.type === 'boolean') {
                        // Les comboboxes booléens renvoient les chaînes 'true'/'false' :
                        // on sérialise un vrai booléen (défaut false si non renseigné).
                        exactValue = c.value === 'true' || c.value === true;
                    } else {
                        // Valeur vidée (croix d'effacement) ou absente -> aucune contrainte
                        // (null), pour ne pas créer une règle « = vide » qui ne matche aucun
                        // dossier et reste indiscernable d'une condition jamais renseignée.
                        exactValue =
                            c.value === undefined || c.value === null || c.value === ''
                                ? null
                                : c.value;
                    }
                    conditions[v.field] = { comparison: 'exact', value: exactValue };
                }
            });
            return {
                id: r.id,
                commentaire: (r.commentaire || '').trim() || null,
                conditions,
                montant1: this.cleanMontant(r.montant1),
                // Supplémentaire / Acompte : un seul montant (montant2 ignoré).
                montant2: this.isLigneUnique ? null : this.cleanMontant(r.montant2),
                // Désignation (gabarit texte) : RT Acompte uniquement, sinon absente.
                designation: this.isAcompte ? ((r.designation || '').trim() || null) : null
            };
        });
        return {
            version: 1,
            decisionVariables: this.selectedVariables.map((v) => ({
                field: v.field,
                label: v.label,
                type: v.type,
                comparison: v.comparison
            })),
            rules
        };
    }

    // Renvoie le 1er message d'erreur de formule rencontré, sinon null.
    findInvalidFormula() {
        for (let i = 0; i < this.rules.length; i++) {
            const r = this.rules[i];
            for (const num of [1, 2]) {
                const m = r['montant' + num];
                if (!m || m.mode !== 'formula') continue;
                const v = validateFormula(m.expression, this.numericFieldApiSet);
                if (!v.valid) {
                    return `Règle ${i + 1}, Montant ${num} : ${v.error}`;
                }
            }
        }
        return null;
    }

    // Un montant renseigné (fixe ou formule) doit avoir son échéance : sans elle,
    // il ne serait jamais déclenché en facturation. Renvoie le 1er manque, sinon null.
    findMissingEcheance() {
        // Acompte : AUCUNE échéance (ni ligne, ni par règle) -> jamais bloquant.
        if (this.isAcompte) {
            return null;
        }
        if (this.isSupplementaire) {
            // Échéance au niveau LIGNE (echeanceSupp__c), pas par règle.
            if (!this.fixedValues[ECHEANCE_SUPP_FIELD]) {
                return 'Sélectionnez l\'échéance (« ' + this.echeanceSuppLabel + ' ») à l\'étape Informations.';
            }
            return null;
        }
        for (let i = 0; i < this.rules.length; i++) {
            const r = this.rules[i];
            for (const num of [1, 2]) {
                const m = r['montant' + num] || {};
                const hasValue =
                    m.mode === 'formula'
                        ? !!(m.expression && m.expression.trim())
                        : !(m.value === '' || m.value === null || m.value === undefined);
                if (hasValue && !(m.echeance && String(m.echeance).trim())) {
                    return `Règle ${i + 1}, Montant Base ${num} : sélectionnez l'échéance de paiement associée.`;
                }
            }
        }
        return null;
    }

    cleanMontant(m) {
        const source = m || { mode: 'fixed' };
        // Échéance de paiement appariée à ce montant (null si non choisie).
        const echeance = source.echeance ? source.echeance : null;
        if (source.mode === 'formula') {
            const expression = (source.expression || '').trim();
            return { mode: 'formula', expression, fields: extractFields(expression), echeance };
        }
        return {
            mode: 'fixed',
            value: source.value === '' || source.value == null ? null : Number(source.value),
            echeance
        };
    }

    // Normalise un montant lu depuis le JSON. Tolère les anciens formats
    // (tableau de tokens, ou {factor, field}) en les convertissant en expression.
    normalizeMontant(m, echeanceRepli) {
        const fallback = echeanceRepli == null ? '' : echeanceRepli;
        if (!m || typeof m !== 'object') {
            return { mode: 'fixed', value: '', echeance: fallback };
        }
        // Échéance du JSON prioritaire ; à défaut, repli sur le champ fixe.
        const echeance = m.echeance == null || m.echeance === '' ? fallback : m.echeance;
        if (m.mode === 'formula') {
            if (typeof m.expression === 'string') {
                return { mode: 'formula', expression: m.expression, echeance };
            }
            if (Array.isArray(m.tokens)) {
                return { mode: 'formula', expression: legacyTokensToExpression(m.tokens), echeance };
            }
            return { mode: 'formula', expression: legacyFactorFieldToExpression(m.factor, m.field), echeance };
        }
        return { mode: 'fixed', value: m.value == null ? '' : m.value, echeance };
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('cancelform'));
    }

    // ----------------------------------------------------- helpers

    readVal(event) {
        const t = event.target;
        if (t.type === 'checkbox' || t.type === 'toggle') {
            return t.checked;
        }
        return t.value;
    }

    labelFor(apiName) {
        const d = this.dossierFieldMap[apiName];
        return d ? d.label : apiName;
    }

    typeLabel(type) {
        switch (type) {
            case 'picklist':
                return 'Liste';
            case 'number':
                return 'Numérique';
            case 'date':
                return 'Date';
            case 'datetime':
                return 'Date/heure';
            case 'boolean':
                return 'Booléen';
            default:
                return 'Texte';
        }
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    reduceError(error) {
        if (!error) return 'Erreur inconnue';
        if (Array.isArray(error.body)) {
            return error.body.map((e) => e.message).join(', ');
        }
        if (error.body && error.body.message) {
            return error.body.message;
        }
        return error.message || 'Erreur inconnue';
    }
}