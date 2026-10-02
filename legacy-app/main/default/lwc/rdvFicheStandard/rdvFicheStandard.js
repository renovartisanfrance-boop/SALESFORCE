import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import userId from '@salesforce/user/Id';

const USER_PROFILE_FIELD = 'User.Profile.Name';
const USER_PROFILE_VIRTUEL_FIELD = 'User.Tech_ProfilVirtuel__c';
const USER_PAYS_FIELD = 'User.Pays__c';
// const PROFIL_VIRTUEL_FIELD = 'Lead.ProfilVirtuel__c';

// Champs utilisés dans les conditions → doivent être listés ici pour être chargés par getRecord
// Ajoutez ici chaque champ dont vous avez besoin dans une condition
//! TODO
const CONDITION_FIELDS = [
    // creation:
    "Lead.PRO_DOSSIER_PAC_SEUL__c", // 171
    "Lead.PRO_DOSSIER_RENO_GLOBALE__c", // 174
    "Lead.NEW_PRODUCT_7_RES060__c", // 060
    "Lead.NEW_PRODUCT_8_RES168__c", // 168
    "Lead.NEW_PRODUCT_9_TRA104__c", // 104
    "Lead.NEW_PRODUCT_4__c", // 108
    "Lead.NEW_PRODUCT_3__c", // 112
    "Lead.NEW_PRODUCT_1__c", // 117
    "Lead.NEW_PRODUCT_2__c", // 119
    "Lead.PRO_DOSSIER_DESTRAT__c", // 142
    "Lead.NEW_PRODUCT_5__c", // 163
    "Lead.PRO_DOSSIER_SERRE_AGRICOLE__c", // 179
    "Lead.PAC__c",
    "Lead.PAC_179_Surface_163__c",
    // End creation

    'Lead.Name',
    'Lead.REGIE_Commentaire_Regie__c',
    'Lead.Apporteurs__c',
    'Lead.ConfirmateurLookup__c',
    'Lead.Telepro_Commentaire_pour_Confirmateur__c',
    'Lead.BD_PAC_Sous_Statut__c',
    'Lead.RENO_Sous_Statut_Leads__c',
    'Lead.REGIE_Adresse_Client__c',
    'Lead.N_cessite_Pr_visite__c',
    'Lead.PREVISITE_Statut__c',
    'Lead.Origine_de_la_demande__c',
    'Lead.CONFIRM_Commentaire__c',
    'Lead.TypeDeDossier__c',
    'Lead.DR_Infos_Lead__c',

    'Lead.Date_de_Previsite__c',
    'Lead.LOOKUP_Previsiteur__c',
    'Lead.Pr_visite_Prise_en_charge__c',
    'Lead.PREVISITE_Fiche_Agri__c',
    'Lead.PREVISITE_Fiche_Tertiaire__c',
    'Lead.PREVISITE_Fiche_Residentiel__c',

];

const PROFIL_SECRETAIRE = 'PORTAIL INTERNE- Secretaire';
const PROFIL_CONFIRMATEUR = 'PORTAIL INTERNE - Confirmateur';
const PROFIL_RESPO_TELEPRO = 'PORTAIL INTERNE- Responsable Telepro';
const PROFIL_CLOSER = 'PORTAIL INTERNE- Closer';
const PROFIL_ADMIN = 'Administrateur système';
const PROFIL_TP_LEADS = 'PORTAIL INTERNE- Télépro Leads';
const PROFIL_TP_DATA = 'PORTAIL INTERNE- Télépro Data';

const PROFILS_TELEPRO = [PROFIL_TP_LEADS, PROFIL_TP_DATA];
const PROFILS_Autres = [PROFIL_SECRETAIRE, PROFIL_CLOSER];

// ['▣ Attente Planification', '🟪Chantier PréValidé'].includes(f.INSTALLATIONN_PAC__c?.value)
// ['🟨Date Planifiée'].includes(f.INSTALLATIONN_PAC__c?.value)
// ['🟧Installation Non Finalisée', '🟩Installation Cloturée'].includes(f.INSTALLATIONN_PAC__c?.value)



export default class RdvFicheStandard extends LightningElement {
    @api recordId;
    @api isCommunityUser = false; // transmis par rdvFicheParent : true en community
    _editingSections = {}; // map { [nomSection]: true } des sections en cours d'édition
    isSaving = false;
    _editValues = {}; // valeurs modifiées en cours d'édition (pour réévaluer les conditions en temps réel)
    simulatedProfile = PROFIL_SECRETAIRE; // admin uniquement — profil simulé via la liste "Voir en tant que" (vide = fallback Tech_ProfilVirtuel__c)

    @wire(getRecord, { recordId: userId, optionalFields: [USER_PROFILE_FIELD, USER_PROFILE_VIRTUEL_FIELD, USER_PAYS_FIELD, USER_PAYS_FIELD] })
    currentUser;

    get isEditing() {
        return Object.keys(this._editingSections).length > 0;
    }

    // Libellé affiché dans la barre sticky
    get editingLabel() {
        const keys = Object.keys(this._editingSections);
        if (keys.length === 1) return keys[0];
        return 'Modification globale';
    }

    // True si au moins une section visible est éditable (pour afficher le bouton global)
    get hasEditableSections() {
        return this.sections.some(s => s.canEdit);
    }

    get currentFiche(){
        // console.log('Accès à currentFiche, preRecord =', JSON.stringify(this.preRecordData));
        // return this.preRecordData?.fields?.Fiche_CEE__c?.value || null;
        return 'STANDARD';
    }

    proRecord;
    preRecordData;
    //! TODO
    @wire(getRecord, { recordId: '$recordId', optionalFields: [ /*PROFIL_VIRTUEL_FIELD,*/ ...CONDITION_FIELDS] })
    wiredProRecord(value) {
        this.proRecord = value;
        const { error, data } = value;
        if (data) {
            this.preRecordData = data;
            console.log('Record data:', JSON.stringify(this.proRecord));
        } else if (error) {
            console.error('Error loading record:', error);
        }
    }

    get currentProfile() {
        // console.log('Accès à currentProfile, currentUser =', JSON.stringify(this.currentUser));
        return getFieldValue(this.currentUser?.data, USER_PROFILE_FIELD);
    }

    get currentPays() {
        console.log('Accès à currentPays, currentUser =', getFieldValue(this.currentUser?.data, USER_PAYS_FIELD));
        return getFieldValue(this.currentUser?.data, USER_PAYS_FIELD);
    }

    get isAdmin() {
        const p = this.currentProfile;
        return p === 'Administrateur système' || p === 'System Administrator';
    }

    // Bloc admin "Voir en tant que" : interne uniquement, jamais en community
    get showImpersonate() {
        return this.isAdmin && !this.isCommunityUser;
    }

    // Profil effectif : admin → profil simulé via la liste "Voir en tant que",
    // fallback sur Tech_ProfilVirtuel__c de l'utilisateur (null si vide → tout afficher).
    // Non-admin → profil réel.
    get effectiveProfile() {
        if (this.isAdmin) {
            return this.simulatedProfile
                || getFieldValue(this.currentUser?.data, USER_PROFILE_VIRTUEL_FIELD)
                || null;
        }
        return this.currentProfile;
    }

    get simulateProfileOptions() {
        return [
            // { label: 'Tout afficher',       value: '' },
            { label: 'Secrétaire',          value: PROFIL_SECRETAIRE },
            { label: 'Confirmateur',        value: PROFIL_CONFIRMATEUR },
            { label: 'Closer',              value: PROFIL_CLOSER },
            { label: 'Responsable Télépro', value: PROFIL_RESPO_TELEPRO },
            { label: 'Télépro Leads',       value: PROFIL_TP_LEADS },
            { label: 'Télépro Data',        value: PROFIL_TP_DATA },
        ];
    }

    handleSimulateProfile(event) {
        this.simulatedProfile = event.detail.value || '';
    }

    get ficheTitre() {
        const current = parametresFiches.fiches.find(fiche => fiche.nom === this.currentFiche) || null;
        return current ? current.displayName || current.nom : null;
    }

    get ficheName() {
        const current = parametresFiches.fiches.find(fiche => fiche.nom === this.currentFiche) || null;
        return current ? current.nom : null;
    }

    get sections() {
        const profile = this.effectiveProfile;
        const base = this.proRecord?.data?.fields;
        // Données pas encore chargées → attendre (évite les faux-négatifs sur les conditions)
        if (!base) return [];
        // En édition : fusionner avec les valeurs saisies en cours pour réévaluer les conditions
        const f = Object.keys(this._editingSections).length > 0 ? { ...base, ...this._editValues } : base;
        const current = parametresFiches.fiches.find(fiche => fiche.nom === this.currentFiche) || null;
        if (!current) return [];
        return current.sections
            // TODO : continue logic sections visibility based on conditions
            .filter(section => !section.condition || section.condition(f, profile, base, this.currentUser?.data))
            .map(section => {
                const sectionIsEditing = !!this._editingSections[section.nom];
                const sectionCanEdit   = !section.canEdit || section.canEdit(f, profile, base, this.currentUser?.data);
                return {
                    nom: section.nom,
                    isEditing:       sectionIsEditing,
                    canEdit:         sectionCanEdit,
                    showEditButton:  sectionCanEdit && !sectionIsEditing,
                    sectionClass: sectionIsEditing ? 'fb-section fb-section--editing' : 'fb-section',
                    gridClass:    sectionIsEditing ? 'fb-grid fb-grid--edit' : 'fb-grid',
                    champs: section.champs
                        .filter(champ => {
                            const profilOk = (this.isAdmin && !profile) || champ.profils?.includes(profile);
                            const conditionOk = !champ.condition || champ.condition(f, profile, base, this.currentUser?.data);
                            return profilOk && conditionOk;
                        })
                        .reduce((acc, champ) => {
                            const item = {
                                apiName:          champ.apiName,
                                isField:          true,
                                readOnly:         champ.readOnly || false,
                                showInput:        sectionIsEditing && !(champ.readOnly || false),
                                cellClass:        champ.fw ? 'fb-field fb-field--fw'         : 'fb-field',
                                editCellClass:    champ.fw ? 'fb-edit-cell fb-edit-cell--fw' : 'fb-edit-cell',
                                currentCellClass: sectionIsEditing
                                    ? (champ.fw ? 'fb-edit-cell fb-edit-cell--fw' : 'fb-edit-cell')
                                    : (champ.fw ? 'fb-field fb-field--fw'         : 'fb-field'),
                            };
                            const brKey = champ.apiName + '__br';
                            const sbKey = champ.apiName + '__sb';
                            const mkBreak = (key) => ({ apiName: key, isField: false, cellClass: 'fb-break',       editCellClass: 'fb-break',       currentCellClass: 'fb-break' });
                            const mkSpace = (key) => ({ apiName: key, isField: false, cellClass: 'fb-space-break', editCellClass: 'fb-space-break', currentCellClass: 'fb-space-break' });
                            const hasAfter  = champ.spaceBreakAfter;
                            const hasBefore = champ.spaceBreakBefore;

                            if (champ.fw) {
                                // Flush pending spaceBreakAfter from an incomplete col-1 row
                                if (acc.col === 1 && acc.pendingSpaceBreakAfter) {
                                    acc.items.push(mkSpace(sbKey + '_pre'));
                                    acc.pendingSpaceBreakAfter = false;
                                }
                                if (hasBefore) acc.items.push(mkSpace(sbKey + '_bef'));
                                acc.items.push(item);
                                if (champ.ligneBreak) acc.items.push(mkBreak(brKey));
                                if (hasAfter)  acc.items.push(mkSpace(sbKey));
                                acc.col = 0;
                            } else if (acc.col === 0) {
                                // Left column
                                if (hasBefore) acc.items.push(mkSpace(sbKey + '_bef'));
                                acc.items.push(item);
                                if (champ.ligneBreak) {
                                    acc.items.push(mkBreak(brKey));
                                    if (hasAfter) acc.items.push(mkSpace(sbKey));
                                    acc.col = 0;
                                } else {
                                    if (hasAfter) acc.pendingSpaceBreakAfter = true;
                                    acc.col = 1;
                                }
                            } else {
                                // Right column
                                if (hasBefore) acc.items.push(mkSpace(sbKey + '_bef'));
                                acc.items.push(item);
                                if (champ.ligneBreak) acc.items.push(mkBreak(brKey));
                                if (acc.pendingSpaceBreakAfter || hasAfter) acc.items.push(mkSpace(sbKey));
                                acc.pendingSpaceBreakAfter = false;
                                acc.col = 0;
                            }
                            return acc;
                        }, { items: [], col: 0, pendingSpaceBreakAfter: false }).items
                };
            })
            .filter(section => section.champs.length > 0);
    }

    handleFieldChange(event) {
        const fieldName = event.target.fieldName;
        const value = event.detail.value;
        // Créer un nouvel objet pour forcer la réactivité LWC
        this._editValues = { ...this._editValues, [fieldName]: { value } };
    }

    handleEditSection(event) {
        const nom = event.currentTarget.dataset.section;
        this._editingSections = { ...this._editingSections, [nom]: true };
    }

    handleEditAll() {
        this._editValues = {};
        const all = {};
        this.sections.forEach(s => { if (s.canEdit) all[s.nom] = true; });
        this._editingSections = all;
    }

    handleCancel() {
        this._editValues = {};
        this._editingSections = {};
    }

    // Bouton Enregistrer → déclenche le submit du formulaire
    handleSaveClick() {
        this.isSaving = true;
        this.template.querySelector('lightning-record-edit-form').submit();
    }

    // Prévient le submit natif si déclenché depuis l'intérieur du form (ex: Enter)
    handleFormSubmit(event) {
        event.preventDefault();
        this.isSaving = true;
        this.template.querySelector('lightning-record-edit-form').submit(event.detail.fields);
    }

    handleSuccess() {
        this.isSaving = false;
        this._editingSections = {};
        this._editValues = {};
        this.dispatchEvent(new ShowToastEvent({
            title: 'Enregistré',
            message: 'Les modifications ont été sauvegardées avec succès.',
            variant: 'success'
        }));
    }

    handleError(event) {
        this.isSaving = false;
        const msg = event.detail?.message || 'Une erreur est survenue lors de la sauvegarde.';
        this.dispatchEvent(new ShowToastEvent({
            title: 'Erreur',
            message: msg,
            variant: 'error',
            mode: 'sticky'
        }));
    }
}

const bat_142 = "BAT_REGIES_-_TH142";
const bat_163 = "BAT_REGIES_-_TH163";
const bat_179 = "BAT_REGIES_-_TH179";

const res_171 = "RESIDENTIEL_REGIES_-_TH171";
const res_060 = "RESIDENTIEL_REGIES_-_RES060";
const res_168 = "RESIDENTIEL_REGIES_-_TH168";

const tra_104 = "TRANSPORT_REGIES_-_SE104";

const fiches_res_171_174_060_168 = ["RESIDENTIEL_REGIES_-_TH171", "RESIDENTIEL_REGIES_-_TH174", "RESIDENTIEL_REGIES_-_RES060", "RESIDENTIEL_REGIES_-_TH168"]
const fiches_agri_117_119_108 = ["AGRI_REGIES_-_TH117", "AGRI_REGIES_-_TH119", "AGRI_REGIES_-_EQ108"]
const fiches_bat_142_163_179 = [bat_142, bat_163, bat_179]
const fiches_tra_104 = [tra_104]

const parametresFiches = {
    fiches: [
        // 171
        {
            nom: "STANDARD",
            displayName: "RDV- STANDARD",
            sections: [
                {
                    nom: "Informations RDV",
                    condition: (f,p) => [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_Autres].includes(p),
                    // canEdit: (f,p) => [PROFIL_RESPO_TELEPRO].includes(p),
                    champs:[
                        { apiName: "DR_Type_dossier__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_Autres], fw: true},
                        { apiName: "Apporteurs__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_Autres], fw: true, condition: (f,p) => f.Apporteurs__c?.value },
                        { apiName: "ConfirmateurLookup__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_Autres], fw: true, condition: (f,p) => f.ConfirmateurLookup__c?.value},
                        { apiName: "RENO_Sous_Statut_Leads__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_Autres], fw: true, condition: (f,p) => f.RENO_Sous_Statut_Leads__c?.value === "🟩ENVOYÉ EN CONFF"},
                        { apiName: "BD_PAC_Sous_Statut__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO], fw: true, condition: (f,p) => f.BD_PAC_Sous_Statut__c?.value === "🟩ENVOYÉ EN CONF"},
                        { apiName: "REGIE_Commentaire_Regie__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_Autres], fw: true, condition: (f,p) => f.REGIE_Commentaire_Regie__c?.value},
                        { apiName: "Telepro_Commentaire_pour_Confirmateur__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_Autres], fw: true, spaceBreakAfter: true, condition: (f,p) => f.Telepro_Commentaire_pour_Confirmateur__c?.value},

                        { apiName: "Name", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_Autres], fw: true},
                        { apiName: "Phone", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_Autres], fw: true},
                        { apiName: "Email", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_Autres], fw: true},
                        { apiName: "REGIE_Adresse_Client__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_Autres], fw: true, condition: (f,p) => f.REGIE_Adresse_Client__c?.value},
                        { apiName: "Address", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_Autres], fw: true, spaceBreakAfter: true},

                        { apiName: "PRO_Nom_du_Signataire__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_Autres], fw: true, condition: (f,p) => !f.TypeDeDossier__c?.value?.split(';').some(fch => fiches_res_171_174_060_168.includes(fch))},
                        { apiName: "PRO_Siege_Social_Adresse_numero_et_voie__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_Autres], fw: true, condition: (f,p) => !f.TypeDeDossier__c?.value?.split(';').some(fch => fiches_res_171_174_060_168.includes(fch))},
                        { apiName: "PRO_Numero_de_Siret__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_Autres], fw: true, condition: (f,p) => !f.TypeDeDossier__c?.value?.split(';').some(fch => fiches_res_171_174_060_168.includes(fch))},
                        { apiName: "PRO_Code_APE__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_Autres], fw: true, condition: (f,p) => !f.TypeDeDossier__c?.value?.split(';').some(fch => fiches_res_171_174_060_168.includes(fch))},
                        { apiName: "PRO_Pr_nom_du_Signataire__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_Autres], fw: true, condition: (f,p) => !f.TypeDeDossier__c?.value?.split(';').some(fch => fiches_res_171_174_060_168.includes(fch))},
                        { apiName: "PRO_Fonction_du_Signataire__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_Autres], fw: true, condition: (f,p) => !f.TypeDeDossier__c?.value?.split(';').some(fch => fiches_res_171_174_060_168.includes(fch))},
                        { apiName: "PRO_T_l_phone_Signataire__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_Autres], fw: true, condition: (f,p) => !f.TypeDeDossier__c?.value?.split(';').some(fch => fiches_res_171_174_060_168.includes(fch))},
                        { apiName: "PRO_Email_Signataire__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_Autres], fw: true, spaceBreakAfter: true, condition: (f,p) => !f.TypeDeDossier__c?.value?.split(';').some(fch => fiches_res_171_174_060_168.includes(fch))},

                        { apiName: "Utilisateur__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_Autres], fw: true},
                        { apiName: "CONFIRM_Traitement__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_Autres], fw: true},
                        { apiName: "ENVOI_CONF_Date_de_Rappel__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_Autres], fw: true},
                        { apiName: "ENVOI_CONF_Cr_neau_de_Rappel__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_Autres], fw: true},
                        { apiName: "CONFIRM_Commentaire__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_Autres], fw: true, spaceBreakAfter: true},
                    ]
                },
                {
                    nom: "Informations PREVISITE",
                    condition: (f,p) => [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_Autres].includes(p) && ![tra_104].some(fch => f.TypeDeDossier__c?.value?.split(';').includes(fch)),
                    champs:[
                        { apiName: "N_cessite_Pr_visite__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_Autres], fw: true},
                        { apiName: "PREVISITE_Statut__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_Autres], fw: true,
                            condition: (f,p, b) => f.N_cessite_Pr_visite__c?.value === "OUI" || (b.PREVISITE_Statut__c?.value && b.PREVISITE_Statut__c?.value !== "▣ Att Planification") || (f.PREVISITE_Statut__c?.value && f.PREVISITE_Statut__c?.value !== "▣ Att Planification")},

                        { apiName: "PREVISITE_Fiche_Residentiel__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_Autres], fw: true,
                            condition: (f,p, b) => (f.TypeDeDossier__c?.value?.split(';').some(fch => fiches_res_171_174_060_168.includes(fch))) && (f.N_cessite_Pr_visite__c?.value === "OUI" || b.PREVISITE_Fiche_Residentiel__c?.value || f.PREVISITE_Fiche_Residentiel__c?.value)},

                        { apiName: "PREVISITE_Fiche_Tertiaire__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_Autres], fw: true, 
                            condition: (f,p, b) => (f.TypeDeDossier__c?.value?.split(';').some(fch => fiches_bat_142_163_179.includes(fch))) && (f.N_cessite_Pr_visite__c?.value === "OUI" || b.PREVISITE_Fiche_Tertiaire__c?.value || f.PREVISITE_Fiche_Tertiaire__c?.value)},

                        { apiName: "PREVISITE_Fiche_Agri__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_Autres], fw: true,
                            condition: (f,p, b) => (f.TypeDeDossier__c?.value?.split(';').some(fch => fiches_agri_117_119_108.includes(fch))) && (f.N_cessite_Pr_visite__c?.value === "OUI" || b.PREVISITE_Fiche_Agri__c?.value || f.PREVISITE_Fiche_Agri__c?.value)},

                        { apiName: "Pr_visite_Prise_en_charge__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_Autres], fw: true,
                            condition: (f,p, b) => f.TypeDeDossier__c?.value?.split(';').includes(res_171) && (f.N_cessite_Pr_visite__c?.value === "OUI"  || ( b.Pr_visite_Prise_en_charge__c?.value) || ( f.Pr_visite_Prise_en_charge__c?.value))},

                        { apiName: "LOOKUP_Previsiteur__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_Autres], fw: true,
                            condition: (f,p, b) => f.N_cessite_Pr_visite__c?.value === "OUI"  || ( b.LOOKUP_Previsiteur__c?.value) || ( f.LOOKUP_Previsiteur__c?.value)},

                        { apiName: "Date_de_Previsite__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_Autres], fw: true,
                            condition: (f,p, b) => (f.N_cessite_Pr_visite__c?.value === "OUI" && ['🟧Passage Planifié'].includes(f.PREVISITE_Statut__c?.value)) || b.Date_de_Previsite__c?.value || f.Date_de_Previsite__c?.value,
                        },
                    ]
                },
                {
                    nom: "Informations RDV",
                    condition: (f,p) => [...PROFILS_TELEPRO].includes(p),
                    champs:[
                        { apiName: "DR_Type_dossier__c", profils: [...PROFILS_TELEPRO], fw: true, spaceBreakAfter: true},
                        { apiName: "DR_Infos_Lead__c", profils: [...PROFILS_TELEPRO], fw: true, condition: (f,p) => f.DR_Infos_Lead__c?.value},
                        { apiName: "Name", profils: [...PROFILS_TELEPRO], fw: true},
                        { apiName: "Phone", profils: [...PROFILS_TELEPRO], fw: true},
                        { apiName: "Email", profils: [...PROFILS_TELEPRO], fw: true},
                        { apiName: "Address", profils: [...PROFILS_TELEPRO], fw: true, spaceBreakAfter: true},
                        { apiName: "ConfirmateurLookup__c", profils: [...PROFILS_TELEPRO], fw: true},
                        { apiName: "RENO_Sous_Statut_Leads__c", profils: [...PROFILS_TELEPRO], fw: true, condition: (f,p) => f.Origine_de_la_demande__c?.value, fw: true, spaceBreakAfter: true},
                        // { apiName: "BD_PAC_Sous_Statut__c", profils: [...PROFILS_TELEPRO], fw: true, spaceBreakAfter: true},
                        { apiName: "TELEPRO_Date_de_Rappel__c", profils: [...PROFILS_TELEPRO], fw: true, condition: (f,p) => f.RENO_Sous_Statut_Leads__c?.value == "À RETRAITER- Rappel programmé" || f.BD_PAC_Sous_Statut__c?.value == "🟦A RAPPELER"},
                        { apiName: "TELEPRO_Creneau_Rappel__c", profils: [...PROFILS_TELEPRO], fw: true, condition: (f,p) => f.RENO_Sous_Statut_Leads__c?.value == "À RETRAITER- Rappel programmé" || f.BD_PAC_Sous_Statut__c?.value == "🟦A RAPPELER"},
                        { apiName: "Telepro_Commentaire_pour_Confirmateur__c", profils: [...PROFILS_TELEPRO], fw: true, spaceBreakAfter: true},

                        { apiName: "Utilisateur__c", profils: [...PROFILS_TELEPRO], fw: true, condition: (f,p) => f.RENO_Sous_Statut_Leads__c?.value == "🟩ENVOYÉ EN CONFF" || f.BD_PAC_Sous_Statut__c?.value == "🟩ENVOYÉ EN CONF"},
                        { apiName: "CONFIRM_Traitement__c", profils: [...PROFILS_TELEPRO], fw: true, condition: (f,p) => f.RENO_Sous_Statut_Leads__c?.value == "🟩ENVOYÉ EN CONFF" || f.BD_PAC_Sous_Statut__c?.value == "🟩ENVOYÉ EN CONF"},
                        { apiName: "ENVOI_CONF_Date_de_Rappel__c", profils: [...PROFILS_TELEPRO], fw: true, condition: (f,p) => f.RENO_Sous_Statut_Leads__c?.value == "🟩ENVOYÉ EN CONFF" || f.BD_PAC_Sous_Statut__c?.value == "🟩ENVOYÉ EN CONF"},
                        { apiName: "ENVOI_CONF_Cr_neau_de_Rappel__c", profils: [...PROFILS_TELEPRO], fw: true, condition: (f,p) => f.RENO_Sous_Statut_Leads__c?.value == "🟩ENVOYÉ EN CONFF" || f.BD_PAC_Sous_Statut__c?.value == "🟩ENVOYÉ EN CONF"},
                        { apiName: "CONFIRM_Commentaire__c", profils: [...PROFILS_TELEPRO], fw: true, condition: (f,p) => f.CONFIRM_Commentaire__c?.value},

                        // { apiName: "PRO_DOSSIER_PAC_SEUL__c", profils: [...PROFILS_TELEPRO], fw: true, spaceBreakBefore: true, condition: (f,p) => f.RENO_Sous_Statut_Leads__c?.value == "🟩ENVOYÉ EN CONFF" || f.BD_PAC_Sous_Statut__c?.value == "🟩ENVOYÉ EN CONF"},
                        // { apiName: "PRO_DOSSIER_RENO_GLOBALE__c", profils: [...PROFILS_TELEPRO], fw: true, condition: (f,p) => f.RENO_Sous_Statut_Leads__c?.value == "🟩ENVOYÉ EN CONFF" || f.BD_PAC_Sous_Statut__c?.value == "🟩ENVOYÉ EN CONF"},
                    ]
                },
                {
                    // Res
                    nom: "Informations Dossier",
                    condition: (f,p) => [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO].includes(p) && (f.TypeDeDossier__c?.value?.split(';').some(fch => fiches_res_171_174_060_168.includes(fch))),
                    champs:[
                        // getFieldValue(this.currentUser?.data, USER_PAYS_FIELD)
                        // { apiName: "PRO_DOSSIER_PAC_SEUL__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO], fw: true, condition: (f,p, b, u) => getFieldValue(u, USER_PAYS_FIELD) === 'France'},
                        { apiName: "PRO_DOSSIER_PAC_SEUL__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO], fw: true, condition: (f,p, b, u) => f.TypeDeDossier__c?.value?.split(';').includes(res_171) },
                        // { apiName: "PRO_DOSSIER_RENO_GLOBALE__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO], fw: true},
                        // { apiName: "NEW_PRODUCT_7_RES060__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO], fw: true, condition: (f,p, b, u) => getFieldValue(u, USER_PAYS_FIELD) === 'Espagne'},
                        { apiName: "NEW_PRODUCT_7_RES060__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO], fw: true, condition: (f,p, b, u) => f.TypeDeDossier__c?.value?.split(';').includes(res_060) },
                        // { apiName: "RES_Statut_Devis__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO], fw: true, condition: (f,p, b, u) => f.TypeDeDossier__c?.value?.split(';').includes(res_060, res_168) },
                        { apiName: "NEW_PRODUCT_8_RES168__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO], fw: true, condition: (f,p, b, u) => f.TypeDeDossier__c?.value?.split(';').includes(res_168) },
                        { apiName: "RES_Statut_Devis__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO], fw: true, condition: (f,p, b, u) => f.TypeDeDossier__c?.value?.split(';').some( ff => [res_060, res_168].includes(ff)) },
                        { apiName: "DR_Cotation_06__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO], fw: true, condition: (f,p, b, u) => f.TypeDeDossier__c?.value?.split(';').some( ff => [res_060].includes(ff)) },

                        { apiName: "Situation_du_demandeur__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO], fw: true, spaceBreakBefore: true, condition: (f,p) => f.PRO_DOSSIER_PAC_SEUL__c?.value === "SansPrevisite" || f.NEW_PRODUCT_7_RES060__c?.value === "SansPrevisite" || f.NEW_PRODUCT_8_RES168__c?.value === "SansPrevisite"},
                        { apiName: "Ann_e_de_la_Chaudiere__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO], fw: true, condition: (f,p) => f.PRO_DOSSIER_PAC_SEUL__c?.value === "SansPrevisite" || f.NEW_PRODUCT_8_RES168__c?.value === "SansPrevisite" },
                        { apiName: "RES_Anne_maison__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO], fw: true, condition: (f,p) => f.TypeDeDossier__c?.value?.split(';').includes(res_060) && f.NEW_PRODUCT_7_RES060__c?.value === "SansPrevisite"},
                        { apiName: "Type_de_Chauffage__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO], fw: true, condition: (f,p) => f.PRO_DOSSIER_PAC_SEUL__c?.value === "SansPrevisite" || f.NEW_PRODUCT_7_RES060__c?.value === "SansPrevisite"},
                        { apiName: "RES_Ann_e_Chaudi_re__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO], fw: true, condition: (f,p) => f.TypeDeDossier__c?.value?.split(';').includes(res_060) && f.NEW_PRODUCT_7_RES060__c?.value === "SansPrevisite"},
                        { apiName: "RES_Zone_ES__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO], fw: true, condition: (f,p) => f.TypeDeDossier__c?.value?.split(';').includes(res_060) && f.NEW_PRODUCT_7_RES060__c?.value === "SansPrevisite"},
                        { apiName: "RES_Bono_Social__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO], fw: true, condition: (f,p) => f.TypeDeDossier__c?.value?.split(';').includes(res_060) && f.NEW_PRODUCT_7_RES060__c?.value === "SansPrevisite"},
                        { apiName: "RES_Isolation_Existante__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO], fw: true, condition: (f,p) => f.TypeDeDossier__c?.value?.split(';').includes(res_060) && f.NEW_PRODUCT_7_RES060__c?.value === "SansPrevisite"},
                        { apiName: "Parcelle_Cadastrale__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO], spaceBreakAfter: true, fw: true, condition: (f,p) => f.TypeDeDossier__c?.value?.split(';').includes(res_060) && f.NEW_PRODUCT_7_RES060__c?.value === "SansPrevisite"},
                        

                        
                        { apiName: "Type_parcours__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.NEW_PRODUCT_8_RES168__c?.value === "SansPrevisite"},
                        { apiName: "Bareme_Ma_prim_renovv__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO], fw: true, condition: (f,p) => f.PRO_DOSSIER_PAC_SEUL__c?.value === "SansPrevisite" || f.NEW_PRODUCT_8_RES168__c?.value === "SansPrevisite"},
                        { apiName: "CEE_Num_Fiscal__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO], fw: true, spaceBreakAfter: true, condition: (f,p) => f.PRO_DOSSIER_PAC_SEUL__c?.value === "SansPrevisite"},
                        { apiName: "Surface_habitable__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO], fw: true, condition: (f,p) => f.PRO_DOSSIER_PAC_SEUL__c?.value === "SansPrevisite" || f.NEW_PRODUCT_7_RES060__c?.value === "SansPrevisite" || f.NEW_PRODUCT_8_RES168__c?.value === "SansPrevisite"},
                        { apiName: "Surface_Toiture__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.NEW_PRODUCT_8_RES168__c?.value === "SansPrevisite"},
                        { apiName: "Nombre_Capteurs__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.NEW_PRODUCT_8_RES168__c?.value === "SansPrevisite"},
                        { apiName: "Type_de_radiateur__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR], fw: true, spaceBreakBefore: true, condition: (f,p) => f.NEW_PRODUCT_8_RES168__c?.value === "SansPrevisite"},
                        { apiName: "PAC_Kit_Bizone__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO], fw: true, condition: (f,p) => f.PRO_DOSSIER_PAC_SEUL__c?.value === "SansPrevisite" || f.NEW_PRODUCT_7_RES060__c?.value === "SansPrevisite" || f.NEW_PRODUCT_8_RES168__c?.value === "SansPrevisite"},
                        { apiName: "RES_Date_Fictif__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO], fw: true, condition: (f,p) => (f.PRO_DOSSIER_PAC_SEUL__c?.value === "SansPrevisite" || f.NEW_PRODUCT_7_RES060__c?.value === "SansPrevisite") && !f.TypeDeDossier__c?.value?.split(';').includes(res_060)},
                        // { apiName: "RENO_174_Travaux__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO], fw: true, condition: (f,p) => f.PRO_DOSSIER_RENO_GLOBALE__c?.value === "SansPrevisite"},
                        
                        // 168 : 
                        // { apiName: "Ann_e_de_la_Chaudiere__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR], fw: true, spaceBreakBefore: true, condition: (f,p) => f.TypeDeDossier__c?.value?.split(';').includes(res_168) && f.NEW_PRODUCT_8_RES168__c?.value === "SansPrevisite"},
                        // { apiName: "Situation_du_demandeur__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.TypeDeDossier__c?.value?.split(';').includes(res_168) && f.NEW_PRODUCT_8_RES168__c?.value === "SansPrevisite"},
                        // { apiName: "Bareme_Ma_prim_renovv__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.TypeDeDossier__c?.value?.split(';').includes(res_168) && f.NEW_PRODUCT_8_RES168__c?.value === "SansPrevisite"},
                        // { apiName: "PAC_Kit_Bizone__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.TypeDeDossier__c?.value?.split(';').includes(res_168) && f.NEW_PRODUCT_8_RES168__c?.value === "SansPrevisite"},
                        // { apiName: "Surface_habitable__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.TypeDeDossier__c?.value?.split(';').includes(res_168) && f.NEW_PRODUCT_8_RES168__c?.value === "SansPrevisite"},
                ]
                },
                {
                    // BAT
                    nom: "Informations Dossier",
                    condition: (f,p) => [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO].includes(p) && (f.TypeDeDossier__c?.value?.split(';').some(fch => fiches_bat_142_163_179.includes(fch))),
                    champs:[
                        { apiName: "PRO_DOSSIER_DESTRAT__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO], fw: true},
                        { apiName: "NEW_PRODUCT_5__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO], fw: true},
                        { apiName: "PRO_DOSSIER_SERRE_AGRICOLE__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO], fw: true},

                        { apiName: "PRO_Type_de_Chauffage__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO], fw: true, spaceBreakBefore: true, condition: (f,p) => [f.PRO_DOSSIER_DESTRAT__c?.value, f.NEW_PRODUCT_5__c?.value, f.PRO_DOSSIER_SERRE_AGRICOLE__c?.value].includes("SansPrevisite")},
                        { apiName: "PRO_Surface_Total_Locaux__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO], fw: true, condition: (f,p) => [f.PRO_DOSSIER_DESTRAT__c?.value, f.NEW_PRODUCT_5__c?.value, f.PRO_DOSSIER_SERRE_AGRICOLE__c?.value].includes("SansPrevisite")},

                        // 142
                        { apiName: "DESTRAT_142_Puissance_Chauffage_KW__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO],fw: true, spaceBreakBefore: true, condition: (f,p) => f.PRO_DOSSIER_DESTRAT__c?.value === "SansPrevisite"},
                        { apiName: "DESTRAT_142_Hauteur_Minimum__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO], fw: true, condition: (f,p) => f.PRO_DOSSIER_DESTRAT__c?.value === "SansPrevisite"},

                        // 163:
                        { apiName: "PAC_163_Surf_Chauff_PAC__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO], fw: true, spaceBreakBefore: true, condition: (f,p) => f.NEW_PRODUCT_5__c?.value === "SansPrevisite"},
                        
                        // 179:
                        { apiName: "PAC__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO], fw: true, spaceBreakBefore: true, condition: (f,p) => f.PRO_DOSSIER_SERRE_AGRICOLE__c?.value === "SansPrevisite"},
                        { apiName: "PAC_179_Surface_163__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO], fw: true, condition: (f,p) => f.PRO_DOSSIER_SERRE_AGRICOLE__c?.value === "SansPrevisite" && (f.PAC__c?.value === "✅- OUI" || (f.PAC_179_Surface_163__c?.value != null && f.PAC_179_Surface_163__c?.value !== ""))},
                        { apiName: "PRO_Surf_Chauff_par_PAC__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO], fw: true, condition: (f,p) => f.PRO_DOSSIER_SERRE_AGRICOLE__c?.value === "SansPrevisite"},
                        { apiName: "PAC_Nb_Logements__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO], fw: true, condition: (f,p) => f.PRO_DOSSIER_SERRE_AGRICOLE__c?.value === "SansPrevisite"},
                        { apiName: "PAC_179_Logements_Pr_carite__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO], fw: true, spaceBreakAfter: true, condition: (f,p) => f.PRO_DOSSIER_SERRE_AGRICOLE__c?.value === "SansPrevisite"},
                       
                        { apiName: "PAC_179_Type_PAC__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO], fw: true, condition: (f,p) => f.PRO_DOSSIER_SERRE_AGRICOLE__c?.value === "SansPrevisite"},
                        { apiName: "Ballon_d_eau_Chaude__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO], fw: true, condition: (f,p) => f.PRO_DOSSIER_SERRE_AGRICOLE__c?.value === "SansPrevisite"},
                        { apiName: "Compteur_Electrique__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO], fw: true, condition: (f,p) => f.PRO_DOSSIER_SERRE_AGRICOLE__c?.value === "SansPrevisite"},
                    ]
                },
                {
                    // AGRI
                    nom: "Informations Dossier",
                    condition: (f,p) => [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO].includes(p) && (f.TypeDeDossier__c?.value?.split(';').some(fch => fiches_agri_117_119_108.includes(fch))),
                    champs:[
                        { apiName: "NEW_PRODUCT_4__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO], fw: true},
                        // { apiName: "NEW_PRODUCT_3__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO], fw: true},
                        { apiName: "NEW_PRODUCT_1__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO], fw: true},
                        { apiName: "NEW_PRODUCT_2__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO], fw: true, spaceBreakAfter: true,},

                        { apiName: "AGRI_Infos_Chantier_108__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO], fw: true, condition: (f,p) => f.NEW_PRODUCT_4__c?.value === "SansPrevisite"},
                        // { apiName: "AGRI_Infos_Chantier_112__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO], fw: true, condition: (f,p) => f.NEW_PRODUCT_3__c?.value === "SansPrevisite"},
                        { apiName: "AGRI117_Infos_Chantier__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO], fw: true, condition: (f,p) => f.NEW_PRODUCT_1__c?.value === "SansPrevisite"},
                        { apiName: "AGRI_Infos_Chantier_119__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO], fw: true, condition: (f,p) => f.NEW_PRODUCT_2__c?.value === "SansPrevisite"},
                        // { apiName: "PRO_Surface_Total_Locaux__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO], fw: true, spaceBreakBefore: true, condition: (f,p) => [f.PRO_DOSSIER_DESTRAT__c?.value, f.NEW_PRODUCT_5__c?.value, f.PRO_DOSSIER_SERRE_AGRICOLE__c?.value].includes("SansPrevisite")},
                        // { apiName: "PRO_Type_de_Chauffage__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO], fw: true, condition: (f,p) => [f.PRO_DOSSIER_DESTRAT__c?.value, f.NEW_PRODUCT_5__c?.value, f.PRO_DOSSIER_SERRE_AGRICOLE__c?.value].includes("SansPrevisite")},

                        // // 142
                        // { apiName: "DESTRAT_142_Puissance_Chauffage_KW__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO],fw: true, condition: (f,p) => f.PRO_DOSSIER_DESTRAT__c?.value === "SansPrevisite"},
                        // { apiName: "DESTRAT_142_Hauteur_Minimum__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO], fw: true, condition: (f,p) => f.PRO_DOSSIER_DESTRAT__c?.value === "SansPrevisite"},

                        // // 163:
                        // { apiName: "PAC_163_Surf_Chauff_PAC__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO], fw: true, spaceBreakBefore: true, condition: (f,p) => f.NEW_PRODUCT_5__c?.value === "SansPrevisite"},
                        
                        // // 179:
                        // { apiName: "PRO_Surf_Chauff_par_PAC__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO], fw: true, condition: (f,p) => f.PRO_DOSSIER_SERRE_AGRICOLE__c?.value === "SansPrevisite"},
                        // { apiName: "PAC_Nb_Logements__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO], fw: true, condition: (f,p) => f.PRO_DOSSIER_SERRE_AGRICOLE__c?.value === "SansPrevisite"},
                        // { apiName: "PAC_179_Logements_Pr_carite__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO], fw: true, condition: (f,p) => f.PRO_DOSSIER_SERRE_AGRICOLE__c?.value === "SansPrevisite"},
                    ]
                },

                {
                    // TRA
                    nom: "Informations Dossier",
                    condition: (f,p) => [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO].includes(p) && (f.TypeDeDossier__c?.value?.split(';').some(fch => fiches_tra_104.includes(fch))),
                    champs:[
                        { apiName: "NEW_PRODUCT_9_TRA104__c", profils: [PROFIL_ADMIN, PROFIL_CONFIRMATEUR, PROFIL_RESPO_TELEPRO, ...PROFILS_TELEPRO], fw: true},

                    ]
                },
            ]
    },
]
};