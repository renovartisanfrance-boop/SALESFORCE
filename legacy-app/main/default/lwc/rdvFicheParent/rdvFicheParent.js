import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

const NAME_LEAD_FIELD  = 'Lead.Name';
const PHONE_LEAD_FIELD = 'Lead.Phone';

export default class RdvFicheParent extends LightningElement {

    @api isCommunityUser;
    @api recordId;
    @api largeur; // ex: "8/12", "1/2", "100%" — appliqué à partir de 768px

    @track _leadDuplicateCards = [];
    @track _proDuplicateCards  = [];
    _showMoreOpen = false;
    _duplicateCheckDone = false;

    get wrapperStyle() {
        if (!this.largeur) return '';
        if (this.largeur.includes('/')) {
            const [num, den] = this.largeur.split('/').map(Number);
            if (!den) return '';
            return `--comp-width: ${(num / den * 100).toFixed(4)}%;`;
        }
        return `--comp-width: ${this.largeur};`;
    }

    @wire(getRecord, { recordId: '$recordId', fields: [NAME_LEAD_FIELD, PHONE_LEAD_FIELD] })
    record;

    get dossierName() {
        return getFieldValue(this.record.data, NAME_LEAD_FIELD) || 'Dossier';
    }

    get phone() {
        return getFieldValue(this.record.data, PHONE_LEAD_FIELD) || null;
    }

    // ─── Duplicate detector configs ───────────────────────────────────────────

    get duplicateFieldsConfig() {
        return [
            { fieldApiName: 'Phone', label: 'Téléphone', operator: 'EQUALS' },
            { fieldApiName: 'IsConverted', label: 'Converti', operator: 'EQUALS_LITERAL' }
        ];
    }

    get proDuplicateFieldsConfig() {
        return [
            { fieldApiName: 'Phone__c', label: 'Téléphone', operator: 'EQUALS' }
        ];
    }

    // Combined array used by all display getters
    get duplicateCards() {
        return [...this._leadDuplicateCards, ...this._proDuplicateCards];
    }

    // ─── Display getters ──────────────────────────────────────────────────────

    get hasDuplicateCards() {
        return this.duplicateCards.length > 0;
    }

    get duplicateCardsCountLabel() {
        const n = this.duplicateCards.length;
        return n === 1 ? '1 doublon potentiel détecté' : `${n} doublons potentiels détectés`;
    }

    get visibleCards() {
        return this.duplicateCards.slice(0, 3);
    }

    get extraCards() {
        return this.duplicateCards.slice(3);
    }

    get hasExtraCards() {
        return this.duplicateCards.length > 3;
    }

    get extraCardsCount() {
        return this.duplicateCards.length - 3;
    }

    get extraCardsLabel() {
        const n = this.extraCardsCount;
        return this._showMoreOpen
            ? 'Masquer'
            : (n === 1 ? 'Voir 1 doublon supplémentaire' : `Voir ${n} doublons supplémentaires`);
    }

    get showMoreOpen() {
        return this._showMoreOpen;
    }

    get accordionIconName() {
        return this._showMoreOpen ? 'utility:chevronup' : 'utility:chevrondown';
    }

    handleToggleExtra() {
        this._showMoreOpen = !this._showMoreOpen;
    }

    // ─── Lifecycle ────────────────────────────────────────────────────────────

    renderedCallback() {
        if (this.phone && !this._duplicateCheckDone) {
            this._duplicateCheckDone = true;
            const leadDetector = this.template.querySelector('c-duplicate-detector[data-source="lead"]');
            const proDetector  = this.template.querySelector('c-duplicate-detector[data-source="pro"]');
            if (leadDetector) {
                leadDetector.checkDuplicates({ Phone: this.phone, IsConverted: false });
            }
            if (proDetector) {
                proDetector.checkDuplicates({ Phone__c: this.phone });
            }
        }
    }

    // ─── Event handlers ───────────────────────────────────────────────────────

    handleDuplicatesFound(event) {
        const { duplicates, picklistMeta = {} } = event.detail;
        this._leadDuplicateCards = duplicates.map(rec => ({
            id:               rec.Id,
            recordUrl:        rec.recordUrl,
            name:             rec.Name || '-',
            source:           'Lead',
            sourceBadge:      'Piste',
            sourceBadgeClass: 'dup-card-badge--lead',
            row1Label:        'Type',
            row1Value:        this._resolveMultiPicklist(rec.TypeDeDossier__c, picklistMeta.TypeDeDossier__c),
            row2Label:        'RDV - Traitement',
            row2Value:        this._resolvePicklist(rec.CONFIRM_Traitement__c, picklistMeta.CONFIRM_Traitement__c),
            showRow3:         false,
            row3Label:        null,
            row3Value:        null,
            showRow4:         !!rec.CONFIRM_Commentaire__c,
            row4Label:        'RDV - Commentaire',
            row4Value:        rec.CONFIRM_Commentaire__c || '-'
        }));
        console.log(`[rdvFicheParent] ${this._leadDuplicateCards.length} doublon(s) Lead pour tél. ${this.phone}`);
    }

    handleNoDuplicates() {
        this._leadDuplicateCards = [];
        console.log(`[rdvFicheParent] Aucun doublon Lead pour le tél. ${this.phone}`);
    }

    handleProDuplicatesFound(event) {
        const { duplicates, picklistMeta = {} } = event.detail;
        this._proDuplicateCards = duplicates.map(rec => {
            const showStatutInstal = rec.INSTALLATIONN_PAC__c !== '▣ Attente Planification'
                && rec.PAC_STATUT_DOSSIER__c !== '⚫DOSSIER- Annulé';
            const showCommentaire = rec.PAC_STATUT_DOSSIER__c === '⚫DOSSIER- Annulé';
            return {
                id:               rec.Id,
                recordUrl:        rec.recordUrl,
                name:             rec.Name || '-',
                source:           'Pro__c',
                sourceBadge:      'Dossier',
                sourceBadgeClass: 'dup-card-badge--pro',
                row1Label:        'Type',
                row1Value:        this._resolvePicklist(rec.Fiche_CEE__c, picklistMeta.Fiche_CEE__c),
                row2Label:        'RDV - Statut Dossier',
                row2Value:        this._resolvePicklist(rec.PAC_STATUT_DOSSIER__c, picklistMeta.PAC_STATUT_DOSSIER__c),
                showRow3:         showStatutInstal,
                row3Label:        'RDV - Statut Installation',
                row3Value:        this._resolvePicklist(rec.INSTALLATIONN_PAC__c, picklistMeta.INSTALLATIONN_PAC__c),
                showRow4:         showCommentaire,
                row4Label:        'RDV - Commentaire Annulation',
                row4Value:        rec.RDV_Commentaire_Annulation__c || '-'
            };
        });
        console.log(`[rdvFicheParent] ${this._proDuplicateCards.length} doublon(s) Pro__c pour tél. ${this.phone}`);
    }

    handleProNoDuplicates() {
        this._proDuplicateCards = [];
        console.log(`[rdvFicheParent] Aucun doublon Pro__c pour le tél. ${this.phone}`);
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────

    _resolvePicklist(value, meta) {
        if (!value) return '-';
        return (meta && meta[value]) ? meta[value] : value;
    }

    _resolveMultiPicklist(value, meta) {
        if (!value) return '-';
        if (!meta) return value;
        return value.split(';').map(v => meta[v.trim()] || v.trim()).join(' · ');
    }
}