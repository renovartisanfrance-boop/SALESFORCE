import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import userId from '@salesforce/user/Id';

const USER_PROFILE_FIELD = 'User.Profile.Name';
const PROFIL_VIRTUEL_FIELD = 'Pro__c.ProfilVirtuel__c';

// Champs utilisés dans les conditions → doivent être listés ici pour être chargés par getRecord
// Ajoutez ici chaque champ dont vous avez besoin dans une condition
const CONDITION_FIELDS = [
    'Pro__c.Fiche_CEE__c',     // ex: afficher PREVISITE seulement si statut = Attente Installation

    'Pro__c.POMPE_A_CHALEUR__c',           // ex: afficher PAC_Kit_Bi_Zone__c seulement si PAC = Oui
         // ex: afficher PAC_Fin_Chantier__c seulement si statut = Terminé
    'Pro__c.MPR_Docs__c',                  // ex: afficher MPR_Relance_Docs__c seulement si docs non reçus
    'Pro__c.Audit_Envoi_en_Visite__c',     // ex: afficher section PREVISITE seulement si envoyé en visite
    'Pro__c.Name',
    'Pro__c.DESTRAT142_Commentaire_Interne__c',
    "Pro__c.PREVISITE_Statut__c",
    "Pro__c.AUDIT_N_c_ssit__c",
    "Pro__c.MPR_Pose_Fictif__c",
    "Pro__c.PAC_Date_d_Installation__c",
    "Pro__c.POMPE_A_CHALEUR__c",
    "Pro__c.PAC_Modele_Ballon__c",
    "Pro__c.PAC_Kit_Bi_Zone__c",
    "Pro__c.Compteur_Electrique__c",
    "Pro__c.INSTALLATIONN_PAC__c",
    "Pro__c.CodePostal__c",
    "Pro__c.MPR_PRECARITE__c",
    "Pro__c.RENO_174_Travaux_Finaux__c",
    "Pro__c.Pr_visite_Statut__c",
    "Pro__c.PRO_Nom_du_Signataire__c",

    // Creation :
    "Pro__c.PRO_DOSSIER_RENO_GLOBALE__c",

    "Pro__c.RENO_174_Date_d_Installation__c",

    // 171
    "Pro__c.PAC_STATUT_DOSSIER__c",

    // 174
    "Pro__c.RENO_TH174_Statut_Dossier__c",

    // 179
    "Pro__c.PAC_TH179_Statut_Dossier__c",

    // 127
    "Pro__c.PRO_Statut_Dossier__c",

    // 142
    "Pro__c.PRO_DOSSIER_DESTRAT__c",

    // 163
    "Pro__c.PAC_TH163_Cr_ation_Dossier__c",

    // 117
    "Pro__c.DESHU_TH117_Cr_ation_Dossier__c",

    // 108
    "Pro__c.TUBES_EQ108_Cr_ation_Dossier__c",

    // 112
    "Pro__c.DPARO_EQ112_Cr_ation_Dossier__c",

    // Champs textarea plain affichés via lightning-formatted-rich-text (toHtmlValue)
    // doivent être chargés par getRecord, sinon proRecord.data.fields[...] est undefined
    "Pro__c.DR_PROconvers__c",
    "Pro__c.DR_Infos_Piste_R_sidentiel__c",
    "Pro__c.DR_Infos_Piste_AGRI__c",
];

const PROFIL_SECRETAIRE = 'PORTAIL INTERNE- Secretaire';
const PROFIL_COMPTA = 'PORTAIL INTERNE- Comptabilité';
const PROFIL_CONFIRMATEUR = 'PORTAIL INTERNE - Confirmateur';
const PROFIL_CLOSER = 'PORTAIL INTERNE- Closer';

// ['▣ Attente Planification', '🟪Chantier PréValidé'].includes(f.INSTALLATIONN_PAC__c?.value)
// ['🟨Date Planifiée'].includes(f.INSTALLATIONN_PAC__c?.value)
// ['🟧Installation Non Finalisée', '🟩Installation Cloturée'].includes(f.INSTALLATIONN_PAC__c?.value)



export default class ProCeeFicheBar extends LightningElement {
    @api recordId;
    _editingSections = {}; // map { [nomSection]: true } des sections en cours d'édition
    isSaving = false;
    _editValues = {}; // valeurs modifiées en cours d'édition (pour réévaluer les conditions en temps réel)
    simulatedProfile = PROFIL_SECRETAIRE; // admin uniquement — profil simulé via la liste "Voir en tant que"

    @wire(getRecord, { recordId: userId, fields: [USER_PROFILE_FIELD] })
    currentUser;

    get isEditing() {
        return Object.keys(this._editingSections).length > 0;
    }

    get editingLabel() {
        const keys = Object.keys(this._editingSections);
        if (keys.length === 1) return keys[0];
        return 'Modification globale';
    }

    get hasEditableSections() {
        return this.sections.some(s => s.canEdit);
    }

    get currentFiche(){
        console.log('Accès à currentFiche, preRecord =', JSON.stringify(this.preRecordData));
        return this.preRecordData?.fields?.Fiche_CEE__c?.value || null;
    }

    proRecord;
    preRecordData;
    @wire(getRecord, { recordId: '$recordId', optionalFields: [ PROFIL_VIRTUEL_FIELD, ...CONDITION_FIELDS] })
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
        return getFieldValue(this.currentUser?.data, USER_PROFILE_FIELD);
    }

    get isAdmin() {
        const p = this.currentProfile;
        return p === 'Administrateur système' || p === 'System Administrator';
    }

    // Profil effectif : admin → profil simulé via la liste "Voir en tant que" (vide = tout afficher).
    // Fallback sur ProfilVirtuel__c du Pro__c si rien n'est sélectionné dans la liste.
    // Non-admin → profil réel.
    get effectiveProfile() {
        if (this.isAdmin) {
            return this.simulatedProfile
                || getFieldValue(this.proRecord?.data, PROFIL_VIRTUEL_FIELD)
                || null;
        }
        return this.currentProfile;
    }

    get simulateProfileOptions() {
        return [
            { label: 'Secrétaire',    value: PROFIL_SECRETAIRE },
            { label: 'Closer',        value: PROFIL_CLOSER },
            { label: 'Confirmateur',  value: PROFIL_CONFIRMATEUR },
            { label: 'Comptabilité',  value: PROFIL_COMPTA },
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
        // Fiche en lecture seule pour ce profil → verrouille toute la fiche
        // (aucun bouton Modifier, tous les champs en sortie). Définie au niveau fiche : readOnly: (p) => [...].includes(p)
        const ficheReadOnly = typeof current.readOnly === 'function' && current.readOnly(profile);
        return current.sections
            // TODO : continue logic sections visibility based on conditions
            .filter(section => !section.condition || section.condition(f, profile, base))
            .map(section => {
                const sectionIsEditing = !!this._editingSections[section.nom];
                const sectionCanEdit   = !ficheReadOnly && (!section.canEdit || section.canEdit(f, profile, base));
                return {
                nom: section.nom,
                isEditing:      sectionIsEditing,
                canEdit:        sectionCanEdit,
                showEditButton: sectionCanEdit && !sectionIsEditing,
                sectionClass:   sectionIsEditing ? 'fb-section fb-section--editing' : 'fb-section',
                gridClass:      sectionIsEditing ? 'fb-grid fb-grid--edit' : 'fb-grid',
                champs: section.champs
                    .filter(champ => {
                        const profilOk = (this.isAdmin && !profile) || champ.profils?.includes(profile);
                        const conditionOk = !champ.condition || champ.condition(f, profile, base);
                        return profilOk && conditionOk;
                    })
                    .reduce((acc, champ) => {
                        const champReadOnly = ficheReadOnly || champ.readOnly || false;
                        const item = {
                            apiName:          champ.apiName,
                            isField:          true,
                            readOnly:         champReadOnly,
                            showInput:        sectionIsEditing && !champReadOnly,
                            plainToHtml:      champ.plainToHtml || false,
                            htmlValue:        champ.plainToHtml ? this.toHtmlValue(champ.apiName) : '',
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

    // Convertit la valeur brute d'un champ textarea plain en HTML pour lightning-formatted-rich-text.
    // Gère à la fois les "\n" littéraux (formules SUBSTITUTE) et les vrais newlines.
    toHtmlValue(apiName) {
        console.log(`Conversion en HTML du champ ${apiName}`);
        const raw = this.proRecord?.data?.fields?.[apiName]?.value;
        if (raw == null) return '';
        return String(raw)
            .replace(/\\n/g, '<br/>')
            .replace(/\r?\n/g, '<br/>')
            // Maintenant pour les |
            .replaceAll("|", '<br/>');
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

const RENO174_Combles = ["🔧COMBLES"];
const RENO174_SS = ["🔧SOUS SOL"];
const RENO174_VMC = ["🔧VMC"];
const RENO174_BT = ["🔧BALLON THERMO 180L- COP 3,8", "🔧BALLON THERMO 280L- COP 3,83", "🔧BALLON THERMO SPLITE 180L- COP 3"];
const RENO174_Murs = ["🔧MURS INTERIEURS 30%"];
const RENO174_Air = ["🔧AIR AIR"];
const RENO174_VT = ["🔧VANNES THERMOSTATIQUE"];


const parametresFiches = {
    fiches: [
    // 171
    {
        nom: "BAR_TH171- PAC Indiv",
        displayName: "🟩BAR TH171- PAC Individuelle",
        //readOnly: (p) => [PROFIL_COMPTA].includes(p),
            sections: [
            {
                nom: "Informations Client",
                champs:[
                    { apiName: "Name", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    { apiName: "PRO_Nom_du_Signataire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f, p, b) => f?.INSTALLATIONN_PAC__c?.value != "▣ Attente Planification" && b.PRO_Nom_du_Signataire__c?.value},
                    { apiName: "Phone__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    { apiName: "Email__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    { apiName: "Client_Adresse_Chantier__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    { apiName: "CodePostal__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f, p, base) => !base?.CodePostal__c?.value },

                    { apiName: "Tech_ExtraireFichierDepuisOpportunite__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, spaceBreakBefore: true},
                    { apiName: "Facturer_Client__c", profils: [PROFIL_COMPTA], fw: true},
                    { apiName: "DR_Infos_Piste_R_sidentiel__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, plainToHtml: true},
                    // { apiName: "Res_Type_de_Chauffage__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    // { apiName: "CEE_Num_Fiscal__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    // { apiName: "RENO_174_Travaux__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PRO_DOSSIER_RENO_GLOBALE__c?.value == 'SansPrevisite'},
                    // { apiName: "DR_Provenance__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    // { apiName: "Confirmateur_Commentaire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                ]
            },
            {
                nom: "PREVISITE",
                condition: (f,p, b) => b.PREVISITE_Statut__c?.value != 'NON' && !(['🟢DOSSIER- Installé', '⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && f.PREVISITE_Statut__c?.value == 'NON' && f.AUDIT_N_c_ssit__c?.value == 'NON'),
            //   condition: (f,p) => ['🔵DOSSIER- Attente Installation'].includes(f.PAC_STATUT_DOSSIER__c?.value) || (['🟢DOSSIER- Installé', '⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && (f.PREVISITE_Statut__c?.value == 'OUI' || f.AUDIT_N_c_ssit__c?.value == 'OUI')),
                champs:[
                { apiName: "PREVISITE_Statut__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                { apiName: "Pr_visite_Statut__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI'},
                { apiName: "PREVISITE_Type_VT__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI'},
                { apiName: "PREVISITE_Type_VT_finale__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI'},
                { apiName: "LOOKUP_Pre_visiteur__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI'},
                { apiName: "Audit_Envoi_en_Visite__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI'&& f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                { apiName: "PREVISITE_Date__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                //{ apiName: "Audit_Statut_CQ__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                // { apiName: "DOCS_Previsite__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA], fw: true, condition: (f,p) => f.Pr_visite_Statut__c?.value == '🟩Passage Effectué' },
                { apiName: "Pr_visite_Commentaire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},

                { apiName: "AUDIT_N_c_ssit__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, spaceBreakBefore: true},
                { apiName: "RENO_Statut_Audit__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI'},
                { apiName: "LOOKUP_Auditeur__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI'},
                { apiName: "AUDIT_D__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                { apiName: "Audit_Date_Reception__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                { apiName: "AUDIT_Commentaire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                ]
            },
            {
                nom: "Details PAC Individuelle",
                // Exemple : section visible seulement si Audit_Envoi_en_Visite__c est coché
                condition: (f,p) => {/*console.log('Vérification condition pré-visite, Name =', f?.Name?.value); */ return p && [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR].includes(p) },
                champs:[
                { apiName: "PAC_STATUT_DOSSIER__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                { apiName: "RDV_Date_d_Annulation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PAC_STATUT_DOSSIER__c?.value == '⚫DOSSIER- Annulé' },
                { apiName: "RDV_Motif_Annulation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PAC_STATUT_DOSSIER__c?.value == '⚫DOSSIER- Annulé'},
                { apiName: "RDV_Commentaire_Annulation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PAC_STATUT_DOSSIER__c?.value == '⚫DOSSIER- Annulé'},
                //! Annulation du 174
                // { apiName: "Annulation_174__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PAC_STATUT_DOSSIER__c?.value == '⚫DOSSIER- Annulé' && f.RENO_TH174_Statut_Dossier__c?.value == '🔵DOSSIER- Attente Installation'},
                //! Annulation du 174
                { apiName: "Devis_Statut__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value)},
                { apiName: "INSTALLATIONN_PAC__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CLOSER], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && (['▣ Attente Planification'].includes(f.INSTALLATIONN_PAC__c?.value)))},
                { apiName: "MPR_Pose_Fictif__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => ['▣ Attente Planification', '🟪Chantier PréValidé', '🟨Date Planifiée'].includes(f.INSTALLATIONN_PAC__c?.value)},
                { apiName: "PAC_Date_d_Installation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !((['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && !f.PAC_Date_d_Installation__c?.value) || (['🔵DOSSIER- Attente Installation'].includes(f.PAC_STATUT_DOSSIER__c?.value) && ['▣ Attente Planification', '🟪Chantier PréValidé'].includes(f.INSTALLATIONN_PAC__c?.value)))},
                { apiName: "LOOKUP_Sous_Traitant_PAC__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) || (['🔵DOSSIER- Attente Installation'].includes(f.PAC_STATUT_DOSSIER__c?.value) && ['▣ Attente Planification', '🟪Chantier PréValidé'].includes(f.INSTALLATIONN_PAC__c?.value)))},
                { apiName: "PAC_Fin_Chantier__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) || (['🔵DOSSIER- Attente Installation'].includes(f.PAC_STATUT_DOSSIER__c?.value) && ['▣ Attente Planification', '🟪Chantier PréValidé'].includes(f.INSTALLATIONN_PAC__c?.value)) || ['🟨Date Planifiée'].includes(f.INSTALLATIONN_PAC__c?.value))},
                //{ apiName: "PAC_SS_Traitant_Final__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) || (['🔵DOSSIER- Attente Installation'].includes(f.PAC_STATUT_DOSSIER__c?.value) && ['▣ Attente Planification', '🟪Chantier PréValidé'].includes(f.INSTALLATIONN_PAC__c?.value)) || ['🟨Date Planifiée'].includes(f.INSTALLATIONN_PAC__c?.value))},
                
                //{ apiName: "MPR_Secretaire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CONFIRMATEUR], fw: true, spaceBreakBefore: true,},
                { apiName: "DR_Zone__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CONFIRMATEUR], fw: true, spaceBreakBefore: true},
                { apiName: "MPR_PRECARITE__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CONFIRMATEUR], fw: true},
                { apiName: "MPR_SHAB__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                { apiName: "Statut_d_occupation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !['🟢DOSSIER- Installé'].includes(f.PAC_STATUT_DOSSIER__c?.value)},
                { apiName: "MPR_Indivision__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !['🟢DOSSIER- Installé'].includes(f.PAC_STATUT_DOSSIER__c?.value)},
                { apiName: "MPR_Docs__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !((['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && !f.MPR_Docs__c?.value) || (['🟢DOSSIER- Installé'].includes(f.PAC_STATUT_DOSSIER__c?.value))) },
                
                { apiName: "DR_Recap_Client__c", profils: [PROFIL_CLOSER], fw: true, spaceBreakBefore: true},
                { apiName: "CEE_Commentaire_Secr_taire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) || (['🟢DOSSIER- Installé'].includes(f.PAC_STATUT_DOSSIER__c?.value)))},
                

                { apiName: "LOOKUP_Delegataire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value), spaceBreakBefore: true},
                { apiName: "PAC_Statut_CEE__c",  profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value)},
                { apiName: "PAC_Modif_Statut_CEE__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA], fw: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value)},
                { apiName: "PAC_Statut_MPR__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                { apiName: "PAC_Modifs_MPR__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CONFIRMATEUR], fw: true},
                
                // { apiName: "MPR_Relance_Dossier__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) || (['🟢DOSSIER- Installé'].includes(f.PAC_STATUT_DOSSIER__c?.value)) || ['🟨Date Planifiée'].includes(f.INSTALLATIONN_PAC__c?.value) || ['🟧Installation Non Finalisée', '🟩Installation Cloturée'].includes(f.INSTALLATIONN_PAC__c?.value))},
                // { apiName: "PAC_Date_Relance_MPR__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) || (['🟢DOSSIER- Installé'].includes(f.PAC_STATUT_DOSSIER__c?.value)) || ['🟨Date Planifiée'].includes(f.INSTALLATIONN_PAC__c?.value) || ['🟧Installation Non Finalisée', '🟩Installation Cloturée'].includes(f.INSTALLATIONN_PAC__c?.value))},
                // { apiName: "MPR_Relance_Docs__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) || (['🟢DOSSIER- Installé'].includes(f.PAC_STATUT_DOSSIER__c?.value)) || ['🟨Date Planifiée'].includes(f.INSTALLATIONN_PAC__c?.value) || ['🟧Installation Non Finalisée', '🟩Installation Cloturée'].includes(f.INSTALLATIONN_PAC__c?.value)) },
                
                // { apiName: "DR_Recap_Client__c", profils: [PROFIL_CLOSER], fw: true},
                // { apiName: "DR_Recap_Docs__c", profils: [PROFIL_CLOSER], fw: true, spaceBreakAfter: true},

               
                { apiName: "POMPE_A_CHALEUR__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, spaceBreakBefore: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && !f.POMPE_A_CHALEUR__c?.value) },
                { apiName: "PAC_Modele_Ballon__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && !f.PAC_Modele_Ballon__c?.value) },
                { apiName: "PAC_Kit_Bi_Zone__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && !f.PAC_Kit_Bi_Zone__c?.value) },
                { apiName: "Compteur_Electrique__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && !f.Compteur_Electrique__c?.value) },
                
                { apiName: "PAC_171_Commentaire_Interne__c", profils: [PROFIL_CLOSER], fw: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value)},
                { apiName: "Installe_Commentaire_pour_Installateur__c", profils: [PROFIL_CLOSER], fw: true, condition: (f,p) => ['🟧Installation Non Finalisée', '🟨Date Planifiée', '🟩Installation Cloturée'].includes(f.INSTALLATIONN_PAC__c?.value) },
                { apiName: "PAC_Email_Sous_Traitant__c", profils: [ PROFIL_CLOSER], fw: true, condition: (f,p) =>  ['🟧Installation Non Finalisée', '🟨Date Planifiée', '🟩Installation Cloturée'].includes(f.INSTALLATIONN_PAC__c?.value) },
                { apiName: "Pac_Photo_Installation__c", profils: [PROFIL_CLOSER], fw: true, condition: (f,p) => ['🟧Installation Non Finalisée', '🟨Date Planifiée', '🟩Installation Cloturée'].includes(f.INSTALLATIONN_PAC__c?.value)},

                { apiName: "DEVIS_Modalit_Paiement__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], spaceBreakBefore: true, fw: true, condition: (f,p, b) => !['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && b.MPR_PRECARITE__c?.value != '🟦BLEU' },
                // { apiName: "DEVIS_Montant_TTC__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value)},
                { apiName: "Montant_RAC_c__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p, b) => !['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && b.MPR_PRECARITE__c?.value != '🟦BLEU'},

                ]
            }
        ]
    },
    // 174
    {
            nom: "BAR_TH174- Réno Glob",
            displayName: "🟩BAR TH174- Réno Globale",
            //readOnly: (p) => [PROFIL_COMPTA].includes(p),
            sections: [ 
                {
                    nom: "Informations Client",
                    champs:[
                        { apiName: "Name", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        { apiName: "PRO_Nom_du_Signataire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f, p, b) => f?.INSTALLATIONN_PAC__c?.value != "▣ Attente Planification" && b.PRO_Nom_du_Signataire__c?.value},
                        { apiName: "Phone__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        { apiName: "Email__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        { apiName: "Client_Adresse_Chantier__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        { apiName: "CodePostal__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f, p, base) => !base?.CodePostal__c?.value },

                        { apiName: "Tech_ExtraireFichierDepuisOpportunite__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, spaceBreakBefore: true},
                        { apiName: "Facturer_Client__c", profils: [PROFIL_COMPTA], fw: true},
                        { apiName: "DR_Infos_Piste_R_sidentiel__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, plainToHtml: true},
                        // { apiName: "Res_Type_de_Chauffage__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        // { apiName: "CEE_Num_Fiscal__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        // { apiName: "RENO_174_Travaux__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        // { apiName: "DR_Provenance__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        // { apiName: "Confirmateur_Commentaire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    ]
                },
                {
                  nom: "PREVISITE / AUDIT",
                  condition: (f,p) => !(['🟢DOSSIER- Installé', '⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && f.PREVISITE_Statut__c?.value == 'NON' && f.AUDIT_N_c_ssit__c?.value == 'NON'),
                  champs:[
                    { apiName: "PREVISITE_Statut__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    { apiName: "LOOKUP_Pre_visiteur__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI'},
                    { apiName: "Pr_visite_Statut__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI'},
                    { apiName: "Audit_Envoi_en_Visite__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation" && !['🟨Date Planifiée', '🟧Installation Non Finalisée'].includes(f.INSTALLATIONN_PAC__c?.value)},
                    { apiName: "PREVISITE_Date__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation" && !['🟨Date Planifiée', '🟧Installation Non Finalisée'].includes(f.INSTALLATIONN_PAC__c?.value)},
                    //{ apiName: "Audit_Statut_CQ__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation" && !['🟨Date Planifiée', '🟧Installation Non Finalisée'].includes(f.INSTALLATIONN_PAC__c?.value)},
                    // { apiName: "DOCS_Previsite__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA], fw: true, condition: (f,p) => f.Pr_visite_Statut__c?.value == '🟩Passage Effectué' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation" && !['🟨Date Planifiée', '🟧Installation Non Finalisée'].includes(f.INSTALLATIONN_PAC__c?.value) },
                    { apiName: "Pr_visite_Commentaire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation" && !['🟨Date Planifiée', '🟧Installation Non Finalisée'].includes(f.INSTALLATIONN_PAC__c?.value)},

                    { apiName: "AUDIT_N_c_ssit__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, spaceBreakBefore: true},
                    { apiName: "LOOKUP_Auditeur__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI'},
                    { apiName: "RENO_Statut_Audit__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI'},
                    { apiName: "AUDIT_D__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation" && !['🟨Date Planifiée', '🟧Installation Non Finalisée'].includes(f.INSTALLATIONN_PAC__c?.value)},
                    { apiName: "Audit_Date_Reception__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation" && !['🟨Date Planifiée', '🟧Installation Non Finalisée'].includes(f.INSTALLATIONN_PAC__c?.value)},
                    { apiName: "AUDIT_Commentaire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation" && !['🟨Date Planifiée', '🟧Installation Non Finalisée'].includes(f.INSTALLATIONN_PAC__c?.value)},

                    //! COFRAC STANDBY
                    // { apiName: "COFRAC__c",  profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, spaceBreakBefore: true,},
                    // { apiName: "COFRAC_Nom_St__c",  profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    // { apiName: "COFRAC_Date_de_Passage__c",  profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                  ]
                },
                {
                  nom: "RESIDENTIEL TH174- Réno Globale",
                  champs:[
                    { apiName: "PAC_STATUT_DOSSIER__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    { apiName: "RDV_Date_d_Annulation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PAC_STATUT_DOSSIER__c?.value == '⚫DOSSIER- Annulé' },
                    { apiName: "RDV_Motif_Annulation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PAC_STATUT_DOSSIER__c?.value == '⚫DOSSIER- Annulé'},
                    { apiName: "RDV_Commentaire_Annulation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PAC_STATUT_DOSSIER__c?.value == '⚫DOSSIER- Annulé'},
                    { apiName: "Devis_Statut__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    { apiName: "INSTALLATIONN_PAC__c",profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && (['▣ Attente Planification'].includes(f.INSTALLATIONN_PAC__c?.value)))},
                    { apiName: "PAC_Date_d_Installation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !((['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && !f.PAC_Date_d_Installation__c?.value) || (['🔵DOSSIER- Attente Installation'].includes(f.PAC_STATUT_DOSSIER__c?.value) && ['▣ Attente Planification', '🟪Chantier PréValidé'].includes(f.INSTALLATIONN_PAC__c?.value)))},
                    { apiName: "LOOKUP_Sous_Traitant_PAC__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) || (['🔵DOSSIER- Attente Installation'].includes(f.PAC_STATUT_DOSSIER__c?.value) && ['▣ Attente Planification', '🟪Chantier PréValidé'].includes(f.INSTALLATIONN_PAC__c?.value)))},
                    { apiName: "PAC_Fin_Chantier__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) || (['🔵DOSSIER- Attente Installation'].includes(f.PAC_STATUT_DOSSIER__c?.value) && ['▣ Attente Planification', '🟪Chantier PréValidé'].includes(f.INSTALLATIONN_PAC__c?.value)) || ['🟨Date Planifiée'].includes(f.INSTALLATIONN_PAC__c?.value))},
                    //{ apiName: "PAC_SS_Traitant_Final__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) || (['🔵DOSSIER- Attente Installation'].includes(f.PAC_STATUT_DOSSIER__c?.value) && ['▣ Attente Planification', '🟪Chantier PréValidé'].includes(f.INSTALLATIONN_PAC__c?.value)) || ['🟨Date Planifiée'].includes(f.INSTALLATIONN_PAC__c?.value))},
                    
                    //{ apiName: "MPR_Secretaire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, spaceBreakBefore: true,},
                    { apiName: "DR_Zone__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CONFIRMATEUR], fw: true, spaceBreakBefore: true},
                    { apiName: "MPR_PRECARITE__c",  profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CONFIRMATEUR], fw: true},
                    { apiName: "MPR_SHAB__c",  profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CONFIRMATEUR], fw: true},
                    { apiName: "TH174_Cotation__c",  profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA], fw: true},
                    { apiName: "RENO_174_Travaux_Finaux__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA], fw: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value)},
                    { apiName: "MPR_Docs__c",  profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA], fw: true,},
                    
                    { apiName: "RES_recap174__c", profils: [PROFIL_CLOSER], fw: true, spaceBreakBefore: true},
                    { apiName: "CEE_Commentaire_Secr_taire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], spaceBreakAfter: true, fw: true},
                    
                    { apiName: "LOOKUP_Delegataire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true,  condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value)},
                    { apiName: "PAC_Statut_CEE__c",  profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value)},
                    { apiName: "PAC_Modif_Statut_CEE__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA], fw: true, spaceBreakAfter: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value)},
                    // { apiName: "PAC_171_Commentaire_Interne__c", profils: [PROFIL_CLOSER], fw: true, spaceBreakAfter: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value)},
                    
                    { apiName: "ISO_M_COMBLE__c",  profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => [...RENO174_Combles].some(v => f.RENO_174_Travaux_Finaux__c?.value?.includes(v)), _spaceBreakBefore: true,},
                    { apiName: "ISO_D_signation_Comble__c",  profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => [...RENO174_Combles].some(v => f.RENO_174_Travaux_Finaux__c?.value?.includes(v))},
                    { apiName: "ISO_M_COMBLE_2__c",  profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => [...RENO174_Combles].some(v => f.RENO_174_Travaux_Finaux__c?.value?.includes(v))},
                    { apiName: "ISO_D_signation_Comble_2__c",  profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => [...RENO174_Combles].some(v => f.RENO_174_Travaux_Finaux__c?.value?.includes(v))},

                    { apiName: "ISO_M_Sous_Sol__c",  profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => [...RENO174_SS].some(v => f.RENO_174_Travaux_Finaux__c?.value?.includes(v)), _spaceBreakBefore: true},
                    { apiName: "ISO_D_signation_Sous_Sol__c",  profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => [...RENO174_SS].some(v => f.RENO_174_Travaux_Finaux__c?.value?.includes(v))},
                    { apiName: "ISO_M_Sous_Sol_2__c",  profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => [...RENO174_SS].some(v => f.RENO_174_Travaux_Finaux__c?.value?.includes(v))},
                    { apiName: "ISO_D_signation_Sous_Sol_2__c",  profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => [...RENO174_SS].some(v => f.RENO_174_Travaux_Finaux__c?.value?.includes(v))},  

                    { apiName: "MURS_M__c",  profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => [...RENO174_Murs].some(v => f.RENO_174_Travaux_Finaux__c?.value?.includes(v)), _spaceBreakBefore: true},
                    { apiName: "POMPE_A_CHALEUR__c",  profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => [...RENO174_Air].some(v => f.RENO_174_Travaux_Finaux__c?.value?.includes(v)), _spaceBreakBefore: true},
                    { apiName: "PAC_Modele_Ballon__c",  profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => [...RENO174_BT].some(v => f.RENO_174_Travaux_Finaux__c?.value?.includes(v))},
                    { apiName: "VMC_Mod_le__c",  profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => [...RENO174_VMC].some(v => f.RENO_174_Travaux_Finaux__c?.value?.includes(v))},
                    { apiName: "THERMOSTAT_Mod_le__c",  profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => [...RENO174_VT].some(v => f.RENO_174_Travaux_Finaux__c?.value?.includes(v))},

                    // { apiName: "Installe_Commentaire_pour_Installateur__c", profils: [PROFIL_CLOSER], fw: true, condition: (f,p) => ['🟧Installation Non Finalisée', '🟨Date Planifiée', '🟩Installation Cloturée'].includes(f.INSTALLATIONN_PAC__c?.value) },
                    // { apiName: "PAC_Email_Sous_Traitant__c", profils: [ PROFIL_CLOSER], fw: true, condition: (f,p) =>  ['🟧Installation Non Finalisée', '🟨Date Planifiée', '🟩Installation Cloturée'].includes(f.INSTALLATIONN_PAC__c?.value) },
                    // { apiName: "Pac_Photo_Installation__c", profils: [PROFIL_CLOSER], fw: true, condition: (f,p) => ['🟧Installation Non Finalisée', '🟨Date Planifiée', '🟩Installation Cloturée'].includes(f.INSTALLATIONN_PAC__c?.value)},
                    { apiName: "PAC_171_Commentaire_Interne__c", profils: [PROFIL_CLOSER], fw: true, spaceBreakBefore: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value)},
                    { apiName: "Installe_Commentaire_pour_Installateur__c", profils: [PROFIL_CLOSER], fw: true, condition: (f,p) => ['🟧Installation Non Finalisée', '🟨Date Planifiée', '🟩Installation Cloturée'].includes(f.INSTALLATIONN_PAC__c?.value) },
                    { apiName: "PAC_Email_Sous_Traitant__c", profils: [ PROFIL_CLOSER], fw: true, condition: (f,p) =>  ['🟧Installation Non Finalisée', '🟨Date Planifiée', '🟩Installation Cloturée'].includes(f.INSTALLATIONN_PAC__c?.value) },
                    { apiName: "Pac_Photo_Installation__c", profils: [PROFIL_CLOSER], fw: true, condition: (f,p) => ['🟧Installation Non Finalisée', '🟨Date Planifiée', '🟩Installation Cloturée'].includes(f.INSTALLATIONN_PAC__c?.value)},

                   
                    // { apiName: "DEVIS_Modalit_Paiement__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, spaceBreakBefore: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && f.MPR_PRECARITE__c?.value != '🟦BLEU'},
                    // // { apiName: "LEDS_Date_Devis__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value)},
                    // // { apiName: "DEVIS_Montant_TTC__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value)},
                    // { apiName: "Montant_RAC_c__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && f.MPR_PRECARITE__c?.value != '🟦BLEU'},

                ]
            }
        ]
    },
    // BAT 179
    {
            nom: "BAR_TH179- PAC Collec",
            displayName: "🟩BAR TH179- PAC Collectif",
            //readOnly: (p) => [PROFIL_COMPTA].includes(p),
            sections: [
                {
                    nom: "Informations Client",
                    champs:[
                        { apiName: "Name", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        { apiName: "PRO_Nom_du_Signataire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        { apiName: "Phone__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        { apiName: "Email__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        { apiName: "Client_Adresse_Chantier__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, spaceBreakAfter: true},
                        { apiName: "CodePostal__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f, p, base) => !base?.CodePostal__c?.value },

                        { apiName: "Tech_ExtraireFichierDepuisOpportunite__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        { apiName: "Facturer_Client__c", profils: [PROFIL_COMPTA], fw: true},
                        { apiName: "DR_PROconvers__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, plainToHtml: true},
                        // { apiName: "Res_Type_de_Chauffage__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        // { apiName: "CEE_Num_Fiscal__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        // { apiName: "DR_Provenance__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        // { apiName: "Confirmateur_Commentaire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    ]
                },
                {
                  nom: "PREVISITE",
                  condition: (f,p) => !(['🟢DOSSIER- Installé', '⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && f.PREVISITE_Statut__c?.value == 'NON' && f.AUDIT_N_c_ssit__c?.value == 'NON'),
                  champs:[
                    { apiName: "PREVISITE_Statut__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    { apiName: "Pr_visite_Statut__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI'},
                    { apiName: "LOOKUP_Pre_visiteur__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI'},
                    { apiName: "Audit_Envoi_en_Visite__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI'&& f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                    { apiName: "PREVISITE_Date__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                    //{ apiName: "Audit_Statut_CQ__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                    // { apiName: "DOCS_Previsite__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA], fw: true, condition: (f,p) => f.Pr_visite_Statut__c?.value == '🟩Passage Effectué'},
                    { apiName: "Pr_visite_Commentaire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},

                    { apiName: "AUDIT_N_c_ssit__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, spaceBreakBefore: true},
                    { apiName: "RENO_Statut_Audit__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI'},
                    { apiName: "LOOKUP_Auditeur__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI'},
                    //{ apiName: "RENO_174_Travaux__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI'},
                    { apiName: "AUDIT_D__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                    { apiName: "Audit_Date_Reception__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                    { apiName: "AUDIT_Commentaire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                  ]
                },
                {
                  nom: "RESIDENTIEL TH179- PAC Collectif",
                  champs:[
                    { apiName: "PAC_STATUT_DOSSIER__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    { apiName: "RDV_Date_d_Annulation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PAC_STATUT_DOSSIER__c?.value == '⚫DOSSIER- Annulé' },
                    { apiName: "RDV_Motif_Annulation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PAC_STATUT_DOSSIER__c?.value == '⚫DOSSIER- Annulé'},
                    { apiName: "RDV_Commentaire_Annulation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PAC_STATUT_DOSSIER__c?.value == '⚫DOSSIER- Annulé'},
                    { apiName: "Devis_Statut__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    { apiName: "INSTALLATIONN_PAC__c",profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && (['▣ Attente Planification'].includes(f.INSTALLATIONN_PAC__c?.value)))},
                    { apiName: "PAC_Date_d_Installation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !((['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && !f.PAC_Date_d_Installation__c?.value))},
                     { apiName: "LOOKUP_Sous_Traitant_PAC__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) || (['🔵DOSSIER- Attente Installation'].includes(f.PAC_STATUT_DOSSIER__c?.value) && ['▣ Attente Planification', '🟪Chantier PréValidé'].includes(f.INSTALLATIONN_PAC__c?.value)))},
                            
                    { apiName: "LEDS_Date_Devis__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], spaceBreakBefore: true, fw: true},
                    { apiName: "DEVIS_Date_Signature__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    { apiName: "TH174_Cotation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    { apiName: "DOCS_Rsx_Chaleur__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    { apiName: "MPR_Docs__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !((['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && !f.MPR_Docs__c?.value) || (['🟢DOSSIER- Installé'].includes(f.PAC_STATUT_DOSSIER__c?.value))) },
                    { apiName: "Confirmateur_Commentaire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    // { apiName: "DR_Recap_Client__c", profils: [PROFIL_CLOSER], fw: true, spaceBreakBefore: true},
                    { apiName: "CEE_Commentaire_Secr_taire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) || (['🟢DOSSIER- Installé'].includes(f.PAC_STATUT_DOSSIER__c?.value)))},
                            

                    { apiName: "LOOKUP_Delegataire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value), spaceBreakBefore: true},
                    { apiName: "PAC_Statut_CEE__c",  profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value)},
                    { apiName: "PAC_Modif_Statut_CEE__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA], fw: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value)},
                        
                    { apiName: "POMPE_A_CHALEUR__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, spaceBreakBefore: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && !f.POMPE_A_CHALEUR__c?.value) },
                    { apiName: "PAC_Modele_Ballon__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && !f.PAC_Modele_Ballon__c?.value) },
                    { apiName: "PAC_Kit_Bi_Zone__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && !f.PAC_Kit_Bi_Zone__c?.value) },
                    { apiName: "Compteur_Electrique__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && !f.Compteur_Electrique__c?.value) },
                        
                    { apiName: "PAC_171_Commentaire_Interne__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && !f.Compteur_Electrique__c?.value)},
                    { apiName: "Installe_Commentaire_pour_Installateur__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => ['🟧Installation Non Finalisée', '🟨Date Planifiée', '🟩Installation Cloturée'].includes(f.INSTALLATIONN_PAC__c?.value) },
                    { apiName: "PAC_Email_Sous_Traitant__c", profils: [ PROFIL_SECRETAIRE, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) =>  ['🟧Installation Non Finalisée', '🟨Date Planifiée', '🟩Installation Cloturée'].includes(f.INSTALLATIONN_PAC__c?.value) },
                    { apiName: "Pac_Photo_Installation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => ['🟧Installation Non Finalisée', '🟨Date Planifiée', '🟩Installation Cloturée'].includes(f.INSTALLATIONN_PAC__c?.value)},

                ]
            }
        ]
    },
    // 060
    {
        nom: "BAR_RES060- PAC",
        displayName: "🟩RES-060 PAC",
        //readOnly: (p) => [PROFIL_COMPTA].includes(p),
            sections: [
            {
                nom: "Informations Client",
                champs:[
                    { apiName: "Name", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    { apiName: "PRO_Nom_du_Signataire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f, p, b) => f?.INSTALLATIONN_PAC__c?.value != "▣ Attente Planification" && b.PRO_Nom_du_Signataire__c?.value},
                    { apiName: "Phone__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    { apiName: "Email__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    { apiName: "Client_Adresse_Chantier__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    { apiName: "CodePostal__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f, p, base) => !base?.CodePostal__c?.value },

                    { apiName: "Tech_ExtraireFichierDepuisOpportunite__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, spaceBreakBefore: true},
                    { apiName: "Facturer_Client__c", profils: [PROFIL_COMPTA], fw: true},
                    { apiName: "DR_Infos_Piste_R_sidentiel__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, plainToHtml: true},
                    // { apiName: "Res_Type_de_Chauffage__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    // { apiName: "CEE_Num_Fiscal__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    // { apiName: "RENO_174_Travaux__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PRO_DOSSIER_RENO_GLOBALE__c?.value == 'SansPrevisite'},
                    // { apiName: "DR_Provenance__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    // { apiName: "Confirmateur_Commentaire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                ]
            },
            {
                nom: "PREVISITE",
                condition: (f,p, b) => b.PREVISITE_Statut__c?.value != 'NON' && !(['🟢DOSSIER- Installé', '⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && f.PREVISITE_Statut__c?.value == 'NON' && f.AUDIT_N_c_ssit__c?.value == 'NON'),
            //   condition: (f,p) => ['🔵DOSSIER- Attente Installation'].includes(f.PAC_STATUT_DOSSIER__c?.value) || (['🟢DOSSIER- Installé', '⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && (f.PREVISITE_Statut__c?.value == 'OUI' || f.AUDIT_N_c_ssit__c?.value == 'OUI')),
                champs:[
                { apiName: "PREVISITE_Statut__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                { apiName: "Pr_visite_Statut__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI'},
                { apiName: "PREVISITE_Type_VT__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI'},
                // { apiName: "PREVISITE_Type_VT_finale__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI'},
                { apiName: "LOOKUP_Pre_visiteur__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI'},
                { apiName: "Audit_Envoi_en_Visite__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI'&& f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                { apiName: "PREVISITE_Date__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                //{ apiName: "Audit_Statut_CQ__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                // { apiName: "DOCS_Previsite__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA], fw: true, condition: (f,p) => f.Pr_visite_Statut__c?.value == '🟩Passage Effectué' },
                { apiName: "Pr_visite_Commentaire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},

                // { apiName: "AUDIT_N_c_ssit__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, spaceBreakBefore: true},
                // { apiName: "RENO_Statut_Audit__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI'},
                // { apiName: "LOOKUP_Auditeur__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI'},
                // { apiName: "AUDIT_D__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                // { apiName: "Audit_Date_Reception__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                // { apiName: "AUDIT_Commentaire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                ]
            },
            {
                nom: "Details PAC Individuelle",
                // Exemple : section visible seulement si Audit_Envoi_en_Visite__c est coché
                condition: (f,p) => {/*console.log('Vérification condition pré-visite, Name =', f?.Name?.value); */ return p && [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR].includes(p) },
                champs:[
                { apiName: "PAC_STATUT_DOSSIER__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                { apiName: "RDV_Date_d_Annulation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PAC_STATUT_DOSSIER__c?.value == '⚫DOSSIER- Annulé' },
                { apiName: "RDV_Motif_Annulation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PAC_STATUT_DOSSIER__c?.value == '⚫DOSSIER- Annulé'},
                { apiName: "RDV_Commentaire_Annulation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PAC_STATUT_DOSSIER__c?.value == '⚫DOSSIER- Annulé'},
                //! Annulation du 174
                // { apiName: "Annulation_174__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PAC_STATUT_DOSSIER__c?.value == '⚫DOSSIER- Annulé' && f.RENO_TH174_Statut_Dossier__c?.value == '🔵DOSSIER- Attente Installation'},
                //! Annulation du 174
                { apiName: "Devis_Statut__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value)},
                { apiName: "INSTALLATIONN_PAC__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CLOSER], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && (['▣ Attente Planification'].includes(f.INSTALLATIONN_PAC__c?.value)))},
                { apiName: "MPR_Pose_Fictif__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => ['▣ Attente Planification', '🟪Chantier PréValidé', '🟨Date Planifiée'].includes(f.INSTALLATIONN_PAC__c?.value)},
                { apiName: "PAC_Date_d_Installation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !((['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && !f.PAC_Date_d_Installation__c?.value) || (['🔵DOSSIER- Attente Installation'].includes(f.PAC_STATUT_DOSSIER__c?.value) && ['▣ Attente Planification', '🟪Chantier PréValidé'].includes(f.INSTALLATIONN_PAC__c?.value)))},
                { apiName: "LOOKUP_Sous_Traitant_PAC__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) || (['🔵DOSSIER- Attente Installation'].includes(f.PAC_STATUT_DOSSIER__c?.value) && ['▣ Attente Planification', '🟪Chantier PréValidé'].includes(f.INSTALLATIONN_PAC__c?.value)))},
                { apiName: "PAC_Fin_Chantier__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) || (['🔵DOSSIER- Attente Installation'].includes(f.PAC_STATUT_DOSSIER__c?.value) && ['▣ Attente Planification', '🟪Chantier PréValidé'].includes(f.INSTALLATIONN_PAC__c?.value)) || ['🟨Date Planifiée'].includes(f.INSTALLATIONN_PAC__c?.value))},
                //{ apiName: "PAC_SS_Traitant_Final__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) || (['🔵DOSSIER- Attente Installation'].includes(f.PAC_STATUT_DOSSIER__c?.value) && ['▣ Attente Planification', '🟪Chantier PréValidé'].includes(f.INSTALLATIONN_PAC__c?.value)) || ['🟨Date Planifiée'].includes(f.INSTALLATIONN_PAC__c?.value))},
                
                //{ apiName: "MPR_Secretaire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CONFIRMATEUR], fw: true, spaceBreakBefore: true,},
                { apiName: "DR_Zone__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CONFIRMATEUR], fw: true, spaceBreakBefore: true},
                { apiName: "DR_Cotation_06__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                { apiName: "RES_Bono_Social__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CONFIRMATEUR], fw: true},
                { apiName: "MPR_SHAB__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                { apiName: "Statut_d_occupation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !['🟢DOSSIER- Installé'].includes(f.PAC_STATUT_DOSSIER__c?.value)},
                // { apiName: "MPR_Indivision__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !['🟢DOSSIER- Installé'].includes(f.PAC_STATUT_DOSSIER__c?.value)},
                { apiName: "MPR_Docs__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !((['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && !f.MPR_Docs__c?.value) || (['🟢DOSSIER- Installé'].includes(f.PAC_STATUT_DOSSIER__c?.value))) },
                
                // { apiName: "DR_Recap_Client__c", profils: [PROFIL_CLOSER], fw: true, },
                { apiName: "CEE_Commentaire_Secr_taire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, spaceBreakBefore: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) || (['🟢DOSSIER- Installé'].includes(f.PAC_STATUT_DOSSIER__c?.value)))},
                

                { apiName: "LOOKUP_Delegataire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value), spaceBreakBefore: true},
                { apiName: "PAC_Statut_CEE__c",  profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value)},
                { apiName: "PAC_Modif_Statut_CEE__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA], fw: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value)},
                // { apiName: "PAC_Statut_MPR__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                // { apiName: "PAC_Modifs_MPR__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CONFIRMATEUR], fw: true},
                
                // { apiName: "MPR_Relance_Dossier__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) || (['🟢DOSSIER- Installé'].includes(f.PAC_STATUT_DOSSIER__c?.value)) || ['🟨Date Planifiée'].includes(f.INSTALLATIONN_PAC__c?.value) || ['🟧Installation Non Finalisée', '🟩Installation Cloturée'].includes(f.INSTALLATIONN_PAC__c?.value))},
                // { apiName: "PAC_Date_Relance_MPR__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) || (['🟢DOSSIER- Installé'].includes(f.PAC_STATUT_DOSSIER__c?.value)) || ['🟨Date Planifiée'].includes(f.INSTALLATIONN_PAC__c?.value) || ['🟧Installation Non Finalisée', '🟩Installation Cloturée'].includes(f.INSTALLATIONN_PAC__c?.value))},
                // { apiName: "MPR_Relance_Docs__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) || (['🟢DOSSIER- Installé'].includes(f.PAC_STATUT_DOSSIER__c?.value)) || ['🟨Date Planifiée'].includes(f.INSTALLATIONN_PAC__c?.value) || ['🟧Installation Non Finalisée', '🟩Installation Cloturée'].includes(f.INSTALLATIONN_PAC__c?.value)) },
                
                // { apiName: "DR_Recap_Client__c", profils: [PROFIL_CLOSER], fw: true},
                // { apiName: "DR_Recap_Docs__c", profils: [PROFIL_CLOSER], fw: true, spaceBreakAfter: true},

               
                { apiName: "POMPE_A_CHALEUR__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, spaceBreakBefore: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && !f.POMPE_A_CHALEUR__c?.value) },
                { apiName: "PAC_Modele_Ballon__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && !f.PAC_Modele_Ballon__c?.value) },
                { apiName: "PAC_Kit_Bi_Zone__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && !f.PAC_Kit_Bi_Zone__c?.value) },
                { apiName: "Compteur_Electrique__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && !f.Compteur_Electrique__c?.value) },
                
                { apiName: "PAC_171_Commentaire_Interne__c", profils: [PROFIL_CLOSER], fw: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value)},
                { apiName: "Installe_Commentaire_pour_Installateur__c", profils: [PROFIL_CLOSER], fw: true, condition: (f,p) => ['🟧Installation Non Finalisée', '🟨Date Planifiée', '🟩Installation Cloturée'].includes(f.INSTALLATIONN_PAC__c?.value) },
                { apiName: "PAC_Email_Sous_Traitant__c", profils: [ PROFIL_CLOSER], fw: true, condition: (f,p) =>  ['🟧Installation Non Finalisée', '🟨Date Planifiée', '🟩Installation Cloturée'].includes(f.INSTALLATIONN_PAC__c?.value) },
                { apiName: "Pac_Photo_Installation__c", profils: [PROFIL_CLOSER], fw: true, condition: (f,p) => ['🟧Installation Non Finalisée', '🟨Date Planifiée', '🟩Installation Cloturée'].includes(f.INSTALLATIONN_PAC__c?.value)},

                { apiName: "DEVIS_Modalit_Paiement__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], spaceBreakBefore: true, fw: true, condition: (f,p, b) => !['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && b.MPR_PRECARITE__c?.value != '🟦BLEU' },
                // { apiName: "DEVIS_Montant_TTC__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value)},
                { apiName: "Montant_RAC_c__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p, b) => !['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && b.MPR_PRECARITE__c?.value != '🟦BLEU'},

                ]
            }
        ]
    },
    // BAT 127
    {
            nom: "BAT_EQ127- LEDS",
            displayName: "🟩BAT EQ127- LEDS",
            //readOnly: (p) => [PROFIL_COMPTA].includes(p),
            sections: [
                {
                    nom: "Informations Client",
                    champs:[
                        { apiName: "Name", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        { apiName: "PRO_Nom_du_Signataire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        { apiName: "Phone__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        { apiName: "Email__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        { apiName: "Client_Adresse_Chantier__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, spaceBreakAfter: true},
                        { apiName: "CodePostal__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f, p, base) => !base?.CodePostal__c?.value },

                        { apiName: "Tech_ExtraireFichierDepuisOpportunite__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        { apiName: "Facturer_Client__c", profils: [PROFIL_COMPTA], fw: true},
                        { apiName: "DR_PROconvers__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, plainToHtml: true},
                        // { apiName: "Res_Type_de_Chauffage__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        // { apiName: "CEE_Num_Fiscal__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        // { apiName: "DR_Provenance__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        // { apiName: "Confirmateur_Commentaire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    ]
                },
                {
                  nom: "PREVISITE",
                  condition: (f,p) => !(['🟢DOSSIER- Installé', '⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && f.PREVISITE_Statut__c?.value == 'NON' && f.AUDIT_N_c_ssit__c?.value == 'NON'),
                  champs:[
                    { apiName: "PREVISITE_Statut__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    { apiName: "Pr_visite_Statut__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI'},
                    { apiName: "LOOKUP_Pre_visiteur__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI'},
                    { apiName: "Audit_Envoi_en_Visite__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI'&& f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                    { apiName: "PREVISITE_Date__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                    //{ apiName: "Audit_Statut_CQ__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                    // { apiName: "DOCS_Previsite__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA], fw: true, condition: (f,p) => f.Pr_visite_Statut__c?.value == '🟩Passage Effectué'},
                    { apiName: "Pr_visite_Commentaire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},

                    { apiName: "AUDIT_N_c_ssit__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, spaceBreakBefore: true},
                    { apiName: "RENO_Statut_Audit__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI'},
                    { apiName: "LOOKUP_Auditeur__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI'},
                    //{ apiName: "RENO_174_Travaux__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI'},
                    { apiName: "AUDIT_D__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                    { apiName: "Audit_Date_Reception__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                    { apiName: "AUDIT_Commentaire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                  ]
                },
                {
                  nom: "TERTIAIRE TH127- LEDS",
                  champs:[
                    { apiName: "PAC_STATUT_DOSSIER__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    { apiName: "RDV_Date_d_Annulation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PAC_STATUT_DOSSIER__c?.value == '⚫DOSSIER- Annulé' },
                    { apiName: "RDV_Motif_Annulation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PAC_STATUT_DOSSIER__c?.value == '⚫DOSSIER- Annulé'},
                    { apiName: "RDV_Commentaire_Annulation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PAC_STATUT_DOSSIER__c?.value == '⚫DOSSIER- Annulé'},
                    { apiName: "Devis_Statut__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    { apiName: "INSTALLATIONN_PAC__c",profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && (['▣ Attente Planification'].includes(f.INSTALLATIONN_PAC__c?.value)))},
                    { apiName: "PAC_Date_d_Installation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !((['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && !f.PAC_Date_d_Installation__c?.value))},
                    { apiName: "LOOKUP_Sous_Traitant_PAC__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) || (['🔵DOSSIER- Attente Installation'].includes(f.PAC_STATUT_DOSSIER__c?.value) && ['▣ Attente Planification', '🟪Chantier PréValidé'].includes(f.INSTALLATIONN_PAC__c?.value)))},
                    //{ apiName: "PAC_SS_Traitant_Final__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) || (['🔵DOSSIER- Attente Installation'].includes(f.PAC_STATUT_DOSSIER__c?.value) && ['▣ Attente Planification', '🟪Chantier PréValidé'].includes(f.INSTALLATIONN_PAC__c?.value)) || ['🟨Date Planifiée'].includes(f.INSTALLATIONN_PAC__c?.value))},
                    
                    //{ apiName: "MPR_Secretaire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, spaceBreakBefore: true,},
                    // { apiName: "RENO_174_Travaux_Finaux__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.PRO_Statut_Dossier__c?.value)},
                    
                    // { apiName: "PAC_Statut_CEE__c",  profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, spaceBreakBefore: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.PRO_Statut_Dossier__c?.value)},
                    // { apiName: "LOOKUP_Delegataire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.PRO_Statut_Dossier__c?.value)},
                ]
            }
        ]
    },
    // BAT 142
    {
            nom: "BAT_TH142- Déstrat",
            displayName: "🟩BAT TH142- Déstratificateurs",
            //readOnly: (p) => [PROFIL_COMPTA].includes(p),
            sections: [
                {
                    nom: "Informations Client",
                    champs:[
                        { apiName: "Name", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        { apiName: "PRO_Nom_du_Signataire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        { apiName: "Phone__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        { apiName: "Email__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        { apiName: "Client_Adresse_Chantier__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, spaceBreakAfter: true},
                        { apiName: "CodePostal__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f, p, base) => !base?.CodePostal__c?.value },

                        { apiName: "Tech_ExtraireFichierDepuisOpportunite__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        { apiName: "Facturer_Client__c", profils: [PROFIL_COMPTA], fw: true},
                        { apiName: "DR_PROconvers__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, plainToHtml: true},
                        // { apiName: "Res_Type_de_Chauffage__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        // { apiName: "CEE_Num_Fiscal__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        // { apiName: "DR_Provenance__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        // { apiName: "Confirmateur_Commentaire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    ]
                },
                {
                  nom: "PREVISITE",
                  condition: (f,p) => !(['🟢DOSSIER- Installé', '⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && f.PREVISITE_Statut__c?.value == 'NON' && f.AUDIT_N_c_ssit__c?.value == 'NON'),
                  champs:[
                    { apiName: "PREVISITE_Statut__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    { apiName: "Pr_visite_Statut__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI'},
                    { apiName: "LOOKUP_Pre_visiteur__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI'},
                    { apiName: "Audit_Envoi_en_Visite__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI'&& f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                    { apiName: "PREVISITE_Date__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                    //{ apiName: "Audit_Statut_CQ__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                    // { apiName: "DOCS_Previsite__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA], fw: true, condition: (f,p) => f.Pr_visite_Statut__c?.value == '🟩Passage Effectué'},
                { apiName: "Pr_visite_Commentaire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},

                    { apiName: "AUDIT_N_c_ssit__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, spaceBreakBefore: true},
                    { apiName: "RENO_Statut_Audit__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI'},
                    { apiName: "LOOKUP_Auditeur__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI'},
                    //{ apiName: "RENO_174_Travaux__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI'},
                    { apiName: "AUDIT_D__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                    { apiName: "Audit_Date_Reception__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                    { apiName: "AUDIT_Commentaire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                  ]
                },
                {
                  nom: "TERTIAIRE TH142- Déstrat",
                  champs:[
                    { apiName: "PAC_STATUT_DOSSIER__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    { apiName: "RDV_Date_d_Annulation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PAC_STATUT_DOSSIER__c?.value == '⚫DOSSIER- Annulé' },
                    { apiName: "RDV_Motif_Annulation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PAC_STATUT_DOSSIER__c?.value == '⚫DOSSIER- Annulé'},
                    { apiName: "RDV_Commentaire_Annulation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PAC_STATUT_DOSSIER__c?.value == '⚫DOSSIER- Annulé'},
                    { apiName: "Devis_Statut__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    { apiName: "INSTALLATIONN_PAC__c",profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && (['▣ Attente Planification'].includes(f.INSTALLATIONN_PAC__c?.value)))},
                    { apiName: "PAC_Date_d_Installation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !((['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && !f.PAC_Date_d_Installation__c?.value))},
                    { apiName: "LOOKUP_Sous_Traitant_PAC__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) || (['🔵DOSSIER- Attente Installation'].includes(f.PAC_STATUT_DOSSIER__c?.value) && ['▣ Attente Planification', '🟪Chantier PréValidé'].includes(f.INSTALLATIONN_PAC__c?.value)))},
                    //{ apiName: "PAC_SS_Traitant_Final__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) || (['🔵DOSSIER- Attente Installation'].includes(f.PAC_STATUT_DOSSIER__c?.value) && ['▣ Attente Planification', '🟪Chantier PréValidé'].includes(f.INSTALLATIONN_PAC__c?.value)) || ['🟨Date Planifiée'].includes(f.INSTALLATIONN_PAC__c?.value))},
                    
                    //{ apiName: "MPR_Secretaire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, spaceBreakBefore: true,},
                    // { apiName: "RENO_174_Travaux_Finaux__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.PRO_DOSSIER_DESTRAT__c?.value)},
                    
                    // { apiName: "PAC_Statut_CEE__c",  profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, spaceBreakBefore: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.PRO_DOSSIER_DESTRAT__c?.value)},
                    // { apiName: "LOOKUP_Delegataire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.PRO_DOSSIER_DESTRAT__c?.value)},
                ]
            }
        ]
    },
    // BAT 163
    {
            nom: "BAT_TH163- PAC Tertiaire",
            displayName: "🟩BAT TH163- PAC Tertiaire",
            //readOnly: (p) => [PROFIL_COMPTA].includes(p),
            sections: [
                {
                    nom: "Informations Client",
                    champs:[
                        { apiName: "Name", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        { apiName: "PRO_Nom_du_Signataire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        { apiName: "Phone__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        { apiName: "Email__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        { apiName: "Client_Adresse_Chantier__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, spaceBreakAfter: true},
                        { apiName: "CodePostal__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f, p, base) => !base?.CodePostal__c?.value },

                        { apiName: "Tech_ExtraireFichierDepuisOpportunite__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        { apiName: "Facturer_Client__c", profils: [PROFIL_COMPTA], fw: true},
                        { apiName: "DR_PROconvers__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, plainToHtml: true},
                        // { apiName: "Res_Type_de_Chauffage__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        // { apiName: "CEE_Num_Fiscal__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        // { apiName: "DR_Provenance__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        // { apiName: "Confirmateur_Commentaire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    ]
                },
                {
                  nom: "PREVISITE",
                  condition: (f,p) => !(['🟢DOSSIER- Installé', '⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && f.PREVISITE_Statut__c?.value == 'NON' && f.AUDIT_N_c_ssit__c?.value == 'NON'),
                  champs:[
                    { apiName: "PREVISITE_Statut__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    { apiName: "Pr_visite_Statut__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI'},
                    { apiName: "LOOKUP_Pre_visiteur__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI'},
                    { apiName: "Audit_Envoi_en_Visite__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI'&& f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                    { apiName: "PREVISITE_Date__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                    //{ apiName: "Audit_Statut_CQ__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                    // { apiName: "DOCS_Previsite__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA], fw: true, condition: (f,p) => f.Pr_visite_Statut__c?.value == '🟩Passage Effectué'},
                { apiName: "Pr_visite_Commentaire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},

                    { apiName: "AUDIT_N_c_ssit__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, spaceBreakBefore: true},
                    { apiName: "RENO_Statut_Audit__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI'},
                    { apiName: "LOOKUP_Auditeur__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI'},
                    // { apiName: "RENO_174_Travaux__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI'},
                    { apiName: "AUDIT_D__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                    { apiName: "Audit_Date_Reception__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                    { apiName: "AUDIT_Commentaire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                  ]
                },
                {
                  nom: "TERTIAIRE TH163- PAC",
                  champs:[
                    { apiName: "PAC_STATUT_DOSSIER__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    { apiName: "RDV_Date_d_Annulation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PAC_STATUT_DOSSIER__c?.value == '⚫DOSSIER- Annulé' },
                    { apiName: "RDV_Motif_Annulation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PAC_STATUT_DOSSIER__c?.value == '⚫DOSSIER- Annulé'},
                    { apiName: "RDV_Commentaire_Annulation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PAC_STATUT_DOSSIER__c?.value == '⚫DOSSIER- Annulé'},
                    { apiName: "Devis_Statut__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    { apiName: "INSTALLATIONN_PAC__c",profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && (['▣ Attente Planification'].includes(f.INSTALLATIONN_PAC__c?.value)))},
                    { apiName: "PAC_Date_d_Installation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !((['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && !f.PAC_Date_d_Installation__c?.value))},
                     { apiName: "LOOKUP_Sous_Traitant_PAC__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) || (['🔵DOSSIER- Attente Installation'].includes(f.PAC_STATUT_DOSSIER__c?.value) && ['▣ Attente Planification', '🟪Chantier PréValidé'].includes(f.INSTALLATIONN_PAC__c?.value)))},
                         
                    { apiName: "LEDS_Date_Devis__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, spaceBreakBefore: true,},
                    { apiName: "DEVIS_Date_Signature__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    { apiName: "TH174_Cotation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    { apiName: "MPR_Docs__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !((['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && !f.MPR_Docs__c?.value) || (['🟢DOSSIER- Installé'].includes(f.PAC_STATUT_DOSSIER__c?.value))) },
                    { apiName: "Confirmateur_Commentaire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    // { apiName: "DR_Recap_Client__c", profils: [PROFIL_CLOSER], fw: true, spaceBreakBefore: true},
                    { apiName: "CEE_Commentaire_Secr_taire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) || (['🟢DOSSIER- Installé'].includes(f.PAC_STATUT_DOSSIER__c?.value)))},
                            

                    { apiName: "LOOKUP_Delegataire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value), spaceBreakBefore: true},
                    { apiName: "PAC_Statut_CEE__c",  profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value)},
                    { apiName: "PAC_Modif_Statut_CEE__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA], fw: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value)},
                    
                    { apiName: "POMPE_A_CHALEUR__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, spaceBreakBefore: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && !f.POMPE_A_CHALEUR__c?.value) },
                    { apiName: "PAC_Modele_Ballon__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && !f.PAC_Modele_Ballon__c?.value) },
                    { apiName: "PAC_Kit_Bi_Zone__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && !f.PAC_Kit_Bi_Zone__c?.value) },
                    { apiName: "Compteur_Electrique__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR],fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && !f.Compteur_Electrique__c?.value) },
                        
                    { apiName: "PAC_171_Commentaire_Interne__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && !f.Compteur_Electrique__c?.value)},
                    { apiName: "Installe_Commentaire_pour_Installateur__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => ['🟧Installation Non Finalisée', '🟨Date Planifiée', '🟩Installation Cloturée'].includes(f.INSTALLATIONN_PAC__c?.value) },
                    { apiName: "PAC_Email_Sous_Traitant__c", profils: [ PROFIL_SECRETAIRE, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) =>  ['🟧Installation Non Finalisée', '🟨Date Planifiée', '🟩Installation Cloturée'].includes(f.INSTALLATIONN_PAC__c?.value) },
                    { apiName: "Pac_Photo_Installation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => ['🟧Installation Non Finalisée', '🟨Date Planifiée', '🟩Installation Cloturée'].includes(f.INSTALLATIONN_PAC__c?.value)},

                ]
            }
        ]
    },

    // 168
    {
        nom: "BAR_TH168- Solaire",
        displayName: "🟩BAR TH168- Solaire",
        //readOnly: (p) => [PROFIL_COMPTA].includes(p),
        sections: [
        {
            nom: "Informations Client",
            champs:[
                { apiName: "Name", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                { apiName: "PRO_Nom_du_Signataire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f, p, b) => f?.INSTALLATIONN_PAC__c?.value != "▣ Attente Planification" && b.PRO_Nom_du_Signataire__c?.value},
                { apiName: "Phone__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                { apiName: "Email__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                { apiName: "Client_Adresse_Chantier__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                { apiName: "CodePostal__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f, p, base) => !base?.CodePostal__c?.value },

                { apiName: "Tech_ExtraireFichierDepuisOpportunite__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, spaceBreakBefore: true},
                { apiName: "Facturer_Client__c", profils: [PROFIL_COMPTA], fw: true},
                { apiName: "DR_Infos_Piste_R_sidentiel__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, plainToHtml: true},
                // { apiName: "Res_Type_de_Chauffage__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                // { apiName: "CEE_Num_Fiscal__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                // { apiName: "RENO_174_Travaux__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PRO_DOSSIER_RENO_GLOBALE__c?.value == 'SansPrevisite'},
                // { apiName: "DR_Provenance__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                // { apiName: "Confirmateur_Commentaire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
            ]
        },
        {
            nom: "PREVISITE",
            condition: (f,p, b) => b.PREVISITE_Statut__c?.value != 'NON' && !(['🟢DOSSIER- Installé', '⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && f.PREVISITE_Statut__c?.value == 'NON' && f.AUDIT_N_c_ssit__c?.value == 'NON'),
        //   condition: (f,p) => ['🔵DOSSIER- Attente Installation'].includes(f.PAC_STATUT_DOSSIER__c?.value) || (['🟢DOSSIER- Installé', '⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && (f.PREVISITE_Statut__c?.value == 'OUI' || f.AUDIT_N_c_ssit__c?.value == 'OUI')),
            champs:[
            { apiName: "PREVISITE_Statut__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
            { apiName: "Pr_visite_Statut__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI'},
            { apiName: "PREVISITE_Type_VT__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI'},
            { apiName: "PREVISITE_Type_VT_finale__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI'},
            { apiName: "LOOKUP_Pre_visiteur__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI'},
            { apiName: "Audit_Envoi_en_Visite__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI'&& f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
            { apiName: "PREVISITE_Date__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
            //{ apiName: "Audit_Statut_CQ__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
            // { apiName: "DOCS_Previsite__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA], fw: true, condition: (f,p) => f.Pr_visite_Statut__c?.value == '🟩Passage Effectué' },
            { apiName: "Pr_visite_Commentaire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},

            // { apiName: "AUDIT_N_c_ssit__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, spaceBreakBefore: true},
            // { apiName: "RENO_Statut_Audit__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI'},
            // { apiName: "LOOKUP_Auditeur__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI'},
            // { apiName: "AUDIT_D__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
            // { apiName: "Audit_Date_Reception__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
            // { apiName: "AUDIT_Commentaire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
            ]
        },
        {
            nom: "Details PAC Individuelle",
            // Exemple : section visible seulement si Audit_Envoi_en_Visite__c est coché
            condition: (f,p) => {/*console.log('Vérification condition pré-visite, Name =', f?.Name?.value); */ return p && [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR].includes(p) },
            champs:[
            { apiName: "PAC_STATUT_DOSSIER__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
            { apiName: "RDV_Date_d_Annulation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PAC_STATUT_DOSSIER__c?.value == '⚫DOSSIER- Annulé' },
            { apiName: "RDV_Motif_Annulation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PAC_STATUT_DOSSIER__c?.value == '⚫DOSSIER- Annulé'},
            { apiName: "RDV_Commentaire_Annulation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PAC_STATUT_DOSSIER__c?.value == '⚫DOSSIER- Annulé'},
            //! Annulation du 174
            // { apiName: "Annulation_174__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PAC_STATUT_DOSSIER__c?.value == '⚫DOSSIER- Annulé' && f.RENO_TH174_Statut_Dossier__c?.value == '🔵DOSSIER- Attente Installation'},
            //! Annulation du 174
            { apiName: "Devis_Statut__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value)},
            { apiName: "INSTALLATIONN_PAC__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CLOSER], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && (['▣ Attente Planification'].includes(f.INSTALLATIONN_PAC__c?.value)))},
            { apiName: "MPR_Pose_Fictif__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => ['▣ Attente Planification', '🟪Chantier PréValidé', '🟨Date Planifiée'].includes(f.INSTALLATIONN_PAC__c?.value)},
            { apiName: "PAC_Date_d_Installation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !((['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && !f.PAC_Date_d_Installation__c?.value) || (['🔵DOSSIER- Attente Installation'].includes(f.PAC_STATUT_DOSSIER__c?.value) && ['▣ Attente Planification', '🟪Chantier PréValidé'].includes(f.INSTALLATIONN_PAC__c?.value)))},
            { apiName: "LOOKUP_Sous_Traitant_PAC__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) || (['🔵DOSSIER- Attente Installation'].includes(f.PAC_STATUT_DOSSIER__c?.value) && ['▣ Attente Planification', '🟪Chantier PréValidé'].includes(f.INSTALLATIONN_PAC__c?.value)))},
            { apiName: "PAC_Fin_Chantier__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) || (['🔵DOSSIER- Attente Installation'].includes(f.PAC_STATUT_DOSSIER__c?.value) && ['▣ Attente Planification', '🟪Chantier PréValidé'].includes(f.INSTALLATIONN_PAC__c?.value)) || ['🟨Date Planifiée'].includes(f.INSTALLATIONN_PAC__c?.value))},
            //{ apiName: "PAC_SS_Traitant_Final__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) || (['🔵DOSSIER- Attente Installation'].includes(f.PAC_STATUT_DOSSIER__c?.value) && ['▣ Attente Planification', '🟪Chantier PréValidé'].includes(f.INSTALLATIONN_PAC__c?.value)) || ['🟨Date Planifiée'].includes(f.INSTALLATIONN_PAC__c?.value))},
            
            //{ apiName: "MPR_Secretaire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CONFIRMATEUR], fw: true, spaceBreakBefore: true,},
            { apiName: "DR_Zone__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CONFIRMATEUR], fw: true, spaceBreakBefore: true},
            { apiName: "MPR_PRECARITE__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CONFIRMATEUR], fw: true},
            { apiName: "MPR_SHAB__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
            { apiName: "Statut_d_occupation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !['🟢DOSSIER- Installé'].includes(f.PAC_STATUT_DOSSIER__c?.value)},
            { apiName: "MPR_Indivision__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !['🟢DOSSIER- Installé'].includes(f.PAC_STATUT_DOSSIER__c?.value)},
            { apiName: "MPR_Docs__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !((['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && !f.MPR_Docs__c?.value) || (['🟢DOSSIER- Installé'].includes(f.PAC_STATUT_DOSSIER__c?.value))) },
            
            { apiName: "DR_Recap_Client__c", profils: [PROFIL_CLOSER], fw: true, spaceBreakBefore: true},
            { apiName: "CEE_Commentaire_Secr_taire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) || (['🟢DOSSIER- Installé'].includes(f.PAC_STATUT_DOSSIER__c?.value)))},
            

            { apiName: "LOOKUP_Delegataire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value), spaceBreakBefore: true},
            { apiName: "PAC_Statut_CEE__c",  profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value)},
            { apiName: "PAC_Modif_Statut_CEE__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA], fw: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value)},
            { apiName: "PAC_Statut_MPR__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
            { apiName: "PAC_Modifs_MPR__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CONFIRMATEUR], fw: true},
            
            // { apiName: "MPR_Relance_Dossier__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) || (['🟢DOSSIER- Installé'].includes(f.PAC_STATUT_DOSSIER__c?.value)) || ['🟨Date Planifiée'].includes(f.INSTALLATIONN_PAC__c?.value) || ['🟧Installation Non Finalisée', '🟩Installation Cloturée'].includes(f.INSTALLATIONN_PAC__c?.value))},
            // { apiName: "PAC_Date_Relance_MPR__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) || (['🟢DOSSIER- Installé'].includes(f.PAC_STATUT_DOSSIER__c?.value)) || ['🟨Date Planifiée'].includes(f.INSTALLATIONN_PAC__c?.value) || ['🟧Installation Non Finalisée', '🟩Installation Cloturée'].includes(f.INSTALLATIONN_PAC__c?.value))},
            // { apiName: "MPR_Relance_Docs__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) || (['🟢DOSSIER- Installé'].includes(f.PAC_STATUT_DOSSIER__c?.value)) || ['🟨Date Planifiée'].includes(f.INSTALLATIONN_PAC__c?.value) || ['🟧Installation Non Finalisée', '🟩Installation Cloturée'].includes(f.INSTALLATIONN_PAC__c?.value)) },
            
            // { apiName: "DR_Recap_Client__c", profils: [PROFIL_CLOSER], fw: true},
            // { apiName: "DR_Recap_Docs__c", profils: [PROFIL_CLOSER], fw: true, spaceBreakAfter: true},

            
            { apiName: "POMPE_A_CHALEUR__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, spaceBreakBefore: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && !f.POMPE_A_CHALEUR__c?.value) },
            { apiName: "PAC_Modele_Ballon__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && !f.PAC_Modele_Ballon__c?.value) },
            { apiName: "PAC_Kit_Bi_Zone__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && !f.PAC_Kit_Bi_Zone__c?.value) },
            { apiName: "Compteur_Electrique__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && !f.Compteur_Electrique__c?.value) },
            
            { apiName: "PAC_171_Commentaire_Interne__c", profils: [PROFIL_CLOSER], fw: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value)},
            { apiName: "Installe_Commentaire_pour_Installateur__c", profils: [PROFIL_CLOSER], fw: true, condition: (f,p) => ['🟧Installation Non Finalisée', '🟨Date Planifiée', '🟩Installation Cloturée'].includes(f.INSTALLATIONN_PAC__c?.value) },
            { apiName: "PAC_Email_Sous_Traitant__c", profils: [ PROFIL_CLOSER], fw: true, condition: (f,p) =>  ['🟧Installation Non Finalisée', '🟨Date Planifiée', '🟩Installation Cloturée'].includes(f.INSTALLATIONN_PAC__c?.value) },
            { apiName: "Pac_Photo_Installation__c", profils: [PROFIL_CLOSER], fw: true, condition: (f,p) => ['🟧Installation Non Finalisée', '🟨Date Planifiée', '🟩Installation Cloturée'].includes(f.INSTALLATIONN_PAC__c?.value)},

            { apiName: "DEVIS_Modalit_Paiement__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], spaceBreakBefore: true, fw: true, condition: (f,p, b) => !['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && b.MPR_PRECARITE__c?.value != '🟦BLEU' },
            // { apiName: "DEVIS_Montant_TTC__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value)},
            { apiName: "Montant_RAC_c__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p, b) => !['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && b.MPR_PRECARITE__c?.value != '🟦BLEU'},

            ]
            }
        ]
    },

    // AGRI 117
    {
            nom: "AGRI_TH117- DESHU",
            displayName: "🟩AGRI TH117- Déshumidificateurs",
            //readOnly: (p) => [PROFIL_COMPTA].includes(p),
            sections: [
                {
                    nom: "Informations Client",
                    champs:[
                        { apiName: "Name", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        { apiName: "PRO_Nom_du_Signataire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        { apiName: "Phone__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        { apiName: "Email__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        { apiName: "Client_Adresse_Chantier__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, spaceBreakAfter: true},
                        { apiName: "CodePostal__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f, p, base) => !base?.CodePostal__c?.value },

                        { apiName: "Tech_ExtraireFichierDepuisOpportunite__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        { apiName: "Facturer_Client__c", profils: [PROFIL_COMPTA], fw: true},
                        { apiName: "DR_Infos_Piste_AGRI__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, plainToHtml: true},
                        // { apiName: "Res_Type_de_Chauffage__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        // { apiName: "CEE_Num_Fiscal__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        // { apiName: "DR_Provenance__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        // { apiName: "Confirmateur_Commentaire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    ]
                },
                {
                  nom: "PREVISITE",
                  condition: (f,p) => !(['🟢DOSSIER- Installé', '⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && f.PREVISITE_Statut__c?.value == 'NON' && f.AUDIT_N_c_ssit__c?.value == 'NON'),
                  champs:[
                    { apiName: "PREVISITE_Statut__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    { apiName: "Pr_visite_Statut__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI'},
                    { apiName: "LOOKUP_Pre_visiteur__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI'},
                    { apiName: "Audit_Envoi_en_Visite__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI'&& f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                    { apiName: "PREVISITE_Date__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                    //{ apiName: "Audit_Statut_CQ__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                    // { apiName: "DOCS_Previsite__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA], fw: true, condition: (f,p) => f.Pr_visite_Statut__c?.value == '🟩Passage Effectué'},
                { apiName: "Pr_visite_Commentaire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},

                    { apiName: "AUDIT_N_c_ssit__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, spaceBreakBefore: true},
                    { apiName: "RENO_Statut_Audit__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI'},
                    { apiName: "LOOKUP_Auditeur__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI'},
                    // { apiName: "RENO_174_Travaux__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI'},
                    { apiName: "AUDIT_D__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                    { apiName: "Audit_Date_Reception__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                    { apiName: "AUDIT_Commentaire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                  ]
                },
                {
                  nom: "AGRICULTURE TH117- Déshumidificateurs",
                  champs:[
                    { apiName: "PAC_STATUT_DOSSIER__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    { apiName: "RDV_Date_d_Annulation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PAC_STATUT_DOSSIER__c?.value == '⚫DOSSIER- Annulé' },
                    { apiName: "RDV_Motif_Annulation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PAC_STATUT_DOSSIER__c?.value == '⚫DOSSIER- Annulé'},
                    { apiName: "RDV_Commentaire_Annulation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PAC_STATUT_DOSSIER__c?.value == '⚫DOSSIER- Annulé'},
                    { apiName: "Devis_Statut__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    { apiName: "INSTALLATIONN_PAC__c",profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && (['▣ Attente Planification'].includes(f.INSTALLATIONN_PAC__c?.value)))},
                    { apiName: "PAC_Date_d_Installation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !((['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && !f.PAC_Date_d_Installation__c?.value))},
                    { apiName: "LOOKUP_Sous_Traitant_PAC__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) || (['🔵DOSSIER- Attente Installation'].includes(f.PAC_STATUT_DOSSIER__c?.value) && ['▣ Attente Planification', '🟪Chantier PréValidé'].includes(f.INSTALLATIONN_PAC__c?.value)))},
                            
                    { apiName: "MPR_Docs__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CONFIRMATEUR], fw: true, spaceBreakBefore: true, condition: (f,p) => !((['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && !f.MPR_Docs__c?.value) || (['🟢DOSSIER- Installé'].includes(f.PAC_STATUT_DOSSIER__c?.value))) },
                    { apiName: "Confirmateur_Commentaire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    // { apiName: "DR_Recap_Client__c", profils: [PROFIL_CLOSER], fw: true, spaceBreakBefore: true},
                    { apiName: "CEE_Commentaire_Secr_taire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) || (['🟢DOSSIER- Installé'].includes(f.PAC_STATUT_DOSSIER__c?.value)))},
                            

                    { apiName: "LOOKUP_Delegataire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value), spaceBreakBefore: true},
                    { apiName: "PAC_Statut_CEE__c",  profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value)},
                    { apiName: "PAC_Modif_Statut_CEE__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA], fw: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value)},
                        
                    { apiName: "Compteur_Electrique__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], spaceBreakBefore: true, fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && !f.Compteur_Electrique__c?.value) },
                        
                    { apiName: "PAC_171_Commentaire_Interne__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && !f.Compteur_Electrique__c?.value)},
                    { apiName: "Installe_Commentaire_pour_Installateur__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => ['🟧Installation Non Finalisée', '🟨Date Planifiée', '🟩Installation Cloturée'].includes(f.INSTALLATIONN_PAC__c?.value) },
                    { apiName: "PAC_Email_Sous_Traitant__c", profils: [ PROFIL_SECRETAIRE, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) =>  ['🟧Installation Non Finalisée', '🟨Date Planifiée', '🟩Installation Cloturée'].includes(f.INSTALLATIONN_PAC__c?.value) },
                    { apiName: "Pac_Photo_Installation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => ['🟧Installation Non Finalisée', '🟨Date Planifiée', '🟩Installation Cloturée'].includes(f.INSTALLATIONN_PAC__c?.value)},

                    //{ apiName: "PAC_SS_Traitant_Final__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) || (['🔵DOSSIER- Attente Installation'].includes(f.PAC_STATUT_DOSSIER__c?.value) && ['▣ Attente Planification', '🟪Chantier PréValidé'].includes(f.INSTALLATIONN_PAC__c?.value)) || ['🟨Date Planifiée'].includes(f.INSTALLATIONN_PAC__c?.value))},
                    
                    //{ apiName: "MPR_Secretaire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, spaceBreakBefore: true,}
                    // { apiName: "RENO_174_Travaux_Finaux__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.DESHU_TH117_Cr_ation_Dossier__c?.value)},
                    
                    // { apiName: "PAC_Statut_CEE__c",  profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, spaceBreakBefore: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.DESHU_TH117_Cr_ation_Dossier__c?.value)},
                    // { apiName: "LOOKUP_Delegataire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.DESHU_TH117_Cr_ation_Dossier__c?.value)},
                ]
            }
        ]
    },
    // AGRI 108
    {
            nom: "AGRI_EQ108- TUBES",
            displayName: "🟩AGRI EQ108- Tubes",
            //readOnly: (p) => [PROFIL_COMPTA].includes(p),
            sections: [
                {
                    nom: "Informations Client",
                    champs:[
                        { apiName: "Name", profils: [PROFIL_SECRETAIRE, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        { apiName: "Name", profils: [PROFIL_COMPTA], fw: true, readOnly: true},
                        { apiName: "PRO_Nom_du_Signataire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        { apiName: "Phone__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        { apiName: "Email__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        { apiName: "Client_Adresse_Chantier__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, spaceBreakAfter: true},
                        { apiName: "CodePostal__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f, p, base) => !base?.CodePostal__c?.value },

                        { apiName: "Tech_ExtraireFichierDepuisOpportunite__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        { apiName: "Facturer_Client__c", profils: [PROFIL_COMPTA], fw: true},
                        { apiName: "DR_Infos_Piste_AGRI__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, plainToHtml: true},
                        // { apiName: "Res_Type_de_Chauffage__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        // { apiName: "CEE_Num_Fiscal__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        // { apiName: "DR_Provenance__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        // { apiName: "Confirmateur_Commentaire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    ]
                },
                {
                  nom: "PREVISITE",
                  condition: (f,p) => !(['🟢DOSSIER- Installé', '⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && f.PREVISITE_Statut__c?.value == 'NON' && f.AUDIT_N_c_ssit__c?.value == 'NON'),
                  champs:[
                    { apiName: "PREVISITE_Statut__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    { apiName: "Pr_visite_Statut__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI'},
                    { apiName: "LOOKUP_Pre_visiteur__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI'},
                    { apiName: "Audit_Envoi_en_Visite__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI'&& f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                    { apiName: "PREVISITE_Date__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                    //{ apiName: "Audit_Statut_CQ__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                    // { apiName: "DOCS_Previsite__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA], fw: true, condition: (f,p) => f.Pr_visite_Statut__c?.value == '🟩Passage Effectué'},
                { apiName: "Pr_visite_Commentaire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},

                    { apiName: "AUDIT_N_c_ssit__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, spaceBreakBefore: true},
                    { apiName: "RENO_Statut_Audit__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI'},
                    { apiName: "LOOKUP_Auditeur__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI'},
                    // { apiName: "RENO_174_Travaux__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI'},
                    { apiName: "AUDIT_D__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                    { apiName: "Audit_Date_Reception__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                    { apiName: "AUDIT_Commentaire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                  ]
                },
                {
                  nom: "AGRICULTURE EQ108- Tubes",
                  champs:[
                    { apiName: "PAC_STATUT_DOSSIER__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    { apiName: "RDV_Date_d_Annulation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PAC_STATUT_DOSSIER__c?.value == '⚫DOSSIER- Annulé' },
                    { apiName: "RDV_Motif_Annulation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PAC_STATUT_DOSSIER__c?.value == '⚫DOSSIER- Annulé'},
                    { apiName: "RDV_Commentaire_Annulation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PAC_STATUT_DOSSIER__c?.value == '⚫DOSSIER- Annulé'},
                    { apiName: "Devis_Statut__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    { apiName: "INSTALLATIONN_PAC__c",profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && (['▣ Attente Planification'].includes(f.INSTALLATIONN_PAC__c?.value)))},
                    { apiName: "PAC_Date_d_Installation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !((['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && !f.PAC_Date_d_Installation__c?.value))},
                    { apiName: "LOOKUP_Sous_Traitant_PAC__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) || (['🔵DOSSIER- Attente Installation'].includes(f.PAC_STATUT_DOSSIER__c?.value) && ['▣ Attente Planification', '🟪Chantier PréValidé'].includes(f.INSTALLATIONN_PAC__c?.value)))},
                    { apiName: "LOOKUP_Sous_Traitant_PAC__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) || (['🔵DOSSIER- Attente Installation'].includes(f.PAC_STATUT_DOSSIER__c?.value) && ['▣ Attente Planification', '🟪Chantier PréValidé'].includes(f.INSTALLATIONN_PAC__c?.value)))},
                    
                    { apiName: "MPR_Docs__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CONFIRMATEUR], fw: true, spaceBreakBefore: true, condition: (f,p) => !((['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && !f.MPR_Docs__c?.value) || (['🟢DOSSIER- Installé'].includes(f.PAC_STATUT_DOSSIER__c?.value))) },
                    { apiName: "Confirmateur_Commentaire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    // { apiName: "DR_Recap_Client__c", profils: [PROFIL_CLOSER], fw: true, spaceBreakBefore: true},
                    { apiName: "CEE_Commentaire_Secr_taire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) || (['🟢DOSSIER- Installé'].includes(f.PAC_STATUT_DOSSIER__c?.value)))},
                            

                    { apiName: "LOOKUP_Delegataire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value), spaceBreakBefore: true},
                    { apiName: "PAC_Statut_CEE__c",  profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value)},
                    { apiName: "PAC_Modif_Statut_CEE__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA], fw: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value)},
                        
                    { apiName: "Compteur_Electrique__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], spaceBreakBefore: true, fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && !f.Compteur_Electrique__c?.value) },
                
                /**! TODO */ { apiName: "PAC_171_Commentaire_Interne__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && !f.Compteur_Electrique__c?.value)},
                /**! TODO */ { apiName: "Installe_Commentaire_pour_Installateur__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => ['🟧Installation Non Finalisée', '🟨Date Planifiée', '🟩Installation Cloturée'].includes(f.INSTALLATIONN_PAC__c?.value) },
                /**! TODO */ { apiName: "PAC_Email_Sous_Traitant__c", profils: [ PROFIL_SECRETAIRE, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) =>  ['🟧Installation Non Finalisée', '🟨Date Planifiée', '🟩Installation Cloturée'].includes(f.INSTALLATIONN_PAC__c?.value) },
                /**! TODO */ { apiName: "Pac_Photo_Installation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => ['🟧Installation Non Finalisée', '🟨Date Planifiée', '🟩Installation Cloturée'].includes(f.INSTALLATIONN_PAC__c?.value)},
                ]
            }
        ]
    },
    // AGRI 112
    {
            nom: "AGRI_EQ112- DPAROIS",
            displayName: "🟩AGRI EQ112- DParois",
            //readOnly: (p) => [PROFIL_COMPTA].includes(p),
            sections: [
                {
                    nom: "Informations Client",
                    champs:[
                        { apiName: "Name", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        { apiName: "PRO_Nom_du_Signataire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        { apiName: "Phone__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        { apiName: "Email__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        { apiName: "Client_Adresse_Chantier__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, spaceBreakAfter: true},
                        { apiName: "CodePostal__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f, p, base) => !base?.CodePostal__c?.value },

                        { apiName: "Tech_ExtraireFichierDepuisOpportunite__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        { apiName: "Facturer_Client__c", profils: [PROFIL_COMPTA], fw: true},
                        { apiName: "DR_Infos_Piste_AGRI__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, plainToHtml: true},
                        // { apiName: "Res_Type_de_Chauffage__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        // { apiName: "CEE_Num_Fiscal__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        // { apiName: "DR_Provenance__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        // { apiName: "Confirmateur_Commentaire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    ]
                },
                {
                  nom: "PREVISITE",
                  condition: (f,p) => !(['🟢DOSSIER- Installé', '⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && f.PREVISITE_Statut__c?.value == 'NON' && f.AUDIT_N_c_ssit__c?.value == 'NON'),
                  champs:[
                    { apiName: "PREVISITE_Statut__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    { apiName: "Pr_visite_Statut__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI'},
                    { apiName: "LOOKUP_Pre_visiteur__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI'},
                    { apiName: "Audit_Envoi_en_Visite__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI'&& f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                    { apiName: "PREVISITE_Date__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                    //{ apiName: "Audit_Statut_CQ__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                    // { apiName: "DOCS_Previsite__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA], fw: true, condition: (f,p) => f.Pr_visite_Statut__c?.value == '🟩Passage Effectué'},
                    { apiName: "Pr_visite_Commentaire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},

                    { apiName: "AUDIT_N_c_ssit__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, spaceBreakBefore: true},
                    { apiName: "RENO_Statut_Audit__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI'},
                    { apiName: "LOOKUP_Auditeur__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI'},
                    // { apiName: "RENO_174_Travaux__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI'},
                    { apiName: "AUDIT_D__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                    { apiName: "Audit_Date_Reception__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                    { apiName: "AUDIT_Commentaire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                  ]
                },
                {
                  nom: "AGRICULTURE EQ112- DParois",
                  champs:[
                    { apiName: "PAC_STATUT_DOSSIER__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    { apiName: "RDV_Date_d_Annulation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PAC_STATUT_DOSSIER__c?.value == '⚫DOSSIER- Annulé' },
                    { apiName: "RDV_Motif_Annulation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PAC_STATUT_DOSSIER__c?.value == '⚫DOSSIER- Annulé'},
                    { apiName: "RDV_Commentaire_Annulation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PAC_STATUT_DOSSIER__c?.value == '⚫DOSSIER- Annulé'},
                    { apiName: "Devis_Statut__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    { apiName: "INSTALLATIONN_PAC__c",profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && (['▣ Attente Planification'].includes(f.INSTALLATIONN_PAC__c?.value)))},
                    { apiName: "PAC_Date_d_Installation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !((['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && !f.PAC_Date_d_Installation__c?.value))},
                    { apiName: "LOOKUP_Sous_Traitant_PAC__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) || (['🔵DOSSIER- Attente Installation'].includes(f.PAC_STATUT_DOSSIER__c?.value) && ['▣ Attente Planification', '🟪Chantier PréValidé'].includes(f.INSTALLATIONN_PAC__c?.value)))},
                    //{ apiName: "PAC_SS_Traitant_Final__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) || (['🔵DOSSIER- Attente Installation'].includes(f.PAC_STATUT_DOSSIER__c?.value) && ['▣ Attente Planification', '🟪Chantier PréValidé'].includes(f.INSTALLATIONN_PAC__c?.value)) || ['🟨Date Planifiée'].includes(f.INSTALLATIONN_PAC__c?.value))},
                    
                    //{ apiName: "MPR_Secretaire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, spaceBreakBefore: true,},
                    // { apiName: "RENO_174_Travaux_Finaux__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.DPARO_EQ112_Cr_ation_Dossier__c?.value)},
                    
                    // { apiName: "PAC_Statut_CEE__c",  profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, spaceBreakBefore: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.DPARO_EQ112_Cr_ation_Dossier__c?.value)},
                    // { apiName: "LOOKUP_Delegataire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.DPARO_EQ112_Cr_ation_Dossier__c?.value)},
                ]
            }
        ]
    },
    // 119
    {
            nom: "AGRI_TH119- VMC",
            displayName: "🟩AGRI TH119- VMC",
            //readOnly: (p) => [PROFIL_COMPTA].includes(p),
            sections: [
                {
                    nom: "Informations Client",
                    champs:[
                        { apiName: "Name", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        { apiName: "PRO_Nom_du_Signataire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        { apiName: "Phone__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        { apiName: "Email__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        { apiName: "Client_Adresse_Chantier__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, spaceBreakAfter: true},
                        { apiName: "CodePostal__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f, p, base) => !base?.CodePostal__c?.value },

                        { apiName: "Tech_ExtraireFichierDepuisOpportunite__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        { apiName: "Facturer_Client__c", profils: [PROFIL_COMPTA], fw: true},
                        { apiName: "DR_Infos_Piste_AGRI__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, plainToHtml: true},
                        // { apiName: "Res_Type_de_Chauffage__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        // { apiName: "CEE_Num_Fiscal__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        // { apiName: "DR_Provenance__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                        // { apiName: "Confirmateur_Commentaire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    ]
                },
                {
                  nom: "PREVISITE",
                  condition: (f,p) => !(['🟢DOSSIER- Installé', '⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && f.PREVISITE_Statut__c?.value == 'NON' && f.AUDIT_N_c_ssit__c?.value == 'NON'),
                  champs:[
                    { apiName: "PREVISITE_Statut__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    { apiName: "Pr_visite_Statut__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI'},
                    { apiName: "LOOKUP_Pre_visiteur__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI'},
                    { apiName: "Audit_Envoi_en_Visite__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI'&& f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                    { apiName: "PREVISITE_Date__c",  profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                    //{ apiName: "Audit_Statut_CQ__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                    // { apiName: "DOCS_Previsite__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA], fw: true, condition: (f,p) => f.Pr_visite_Statut__c?.value == '🟩Passage Effectué'},
                    { apiName: "Pr_visite_Commentaire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PREVISITE_Statut__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},

                    { apiName: "AUDIT_N_c_ssit__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, spaceBreakBefore: true},
                    { apiName: "RENO_Statut_Audit__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI'},
                    { apiName: "LOOKUP_Auditeur__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI'},
                    //{ apiName: "RENO_174_Travaux__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI'},
                    { apiName: "AUDIT_D__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                    { apiName: "Audit_Date_Reception__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                    { apiName: "AUDIT_Commentaire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.AUDIT_N_c_ssit__c?.value == 'OUI' && f.PAC_STATUT_DOSSIER__c?.value == "🔵DOSSIER- Attente Installation"},
                  ]
                },
                {
                  nom: "AGRICULTURE TH119- VMC",
                  champs:[
                    { apiName: "PAC_STATUT_DOSSIER__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    { apiName: "RDV_Date_d_Annulation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PAC_STATUT_DOSSIER__c?.value == '⚫DOSSIER- Annulé' },
                    { apiName: "RDV_Motif_Annulation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PAC_STATUT_DOSSIER__c?.value == '⚫DOSSIER- Annulé'},
                    { apiName: "RDV_Commentaire_Annulation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => f.PAC_STATUT_DOSSIER__c?.value == '⚫DOSSIER- Annulé'},
                    { apiName: "Devis_Statut__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
                    { apiName: "INSTALLATIONN_PAC__c",profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && (['▣ Attente Planification'].includes(f.INSTALLATIONN_PAC__c?.value)))},
                    { apiName: "PAC_Date_d_Installation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !((['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && !f.PAC_Date_d_Installation__c?.value))},
                    { apiName: "LOOKUP_Sous_Traitant_PAC__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) || (['🔵DOSSIER- Attente Installation'].includes(f.PAC_STATUT_DOSSIER__c?.value) && ['▣ Attente Planification', '🟪Chantier PréValidé'].includes(f.INSTALLATIONN_PAC__c?.value)))},
                    { apiName: "LOOKUP_Sous_Traitant_PAC__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) || (['🔵DOSSIER- Attente Installation'].includes(f.PAC_STATUT_DOSSIER__c?.value) && ['▣ Attente Planification', '🟪Chantier PréValidé'].includes(f.INSTALLATIONN_PAC__c?.value)))},
                    
                    { apiName: "MPR_Docs__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CONFIRMATEUR], fw: true, spaceBreakBefore: true, condition: (f,p) => !((['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && !f.MPR_Docs__c?.value) || (['🟢DOSSIER- Installé'].includes(f.PAC_STATUT_DOSSIER__c?.value))) },
                    { apiName: "Confirmateur_Commentaire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true},
               //   { apiName: "DR_Recap_Client__c", profils: [PROFIL_CLOSER], fw: true, spaceBreakBefore: true},
                    { apiName: "CEE_Commentaire_Secr_taire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) || (['🟢DOSSIER- Installé'].includes(f.PAC_STATUT_DOSSIER__c?.value)))},
                    

                    { apiName: "LOOKUP_Delegataire__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value), spaceBreakBefore: true},
                    { apiName: "PAC_Statut_CEE__c",  profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value)},
                    { apiName: "PAC_Modif_Statut_CEE__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA], fw: true, condition: (f,p) => !['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value)},
                
                    { apiName: "Compteur_Electrique__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], spaceBreakBefore: true, fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && !f.Compteur_Electrique__c?.value) },
                
                /**! TODO */ { apiName: "PAC_171_Commentaire_Interne__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => !(['⚫DOSSIER- Annulé'].includes(f.PAC_STATUT_DOSSIER__c?.value) && !f.Compteur_Electrique__c?.value)},
                /**! TODO */ { apiName: "Installe_Commentaire_pour_Installateur__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => ['🟧Installation Non Finalisée', '🟨Date Planifiée', '🟩Installation Cloturée'].includes(f.INSTALLATIONN_PAC__c?.value) },
                /**! TODO */ { apiName: "PAC_Email_Sous_Traitant__c", profils: [ PROFIL_SECRETAIRE, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) =>  ['🟧Installation Non Finalisée', '🟨Date Planifiée', '🟩Installation Cloturée'].includes(f.INSTALLATIONN_PAC__c?.value) },
                /**! TODO */ { apiName: "Pac_Photo_Installation__c", profils: [PROFIL_SECRETAIRE, PROFIL_COMPTA, PROFIL_CLOSER, PROFIL_CONFIRMATEUR], fw: true, condition: (f,p) => ['🟧Installation Non Finalisée', '🟨Date Planifiée', '🟩Installation Cloturée'].includes(f.INSTALLATIONN_PAC__c?.value)},
                ]
            }
        ]
    },
]
};