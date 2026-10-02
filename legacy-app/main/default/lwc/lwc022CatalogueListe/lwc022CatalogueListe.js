import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';
import getCatalogueLignes from '@salesforce/apex/LC022CatalogueTarifaireController.getCatalogueLignes';
import getCatalogueLigne from '@salesforce/apex/LC022CatalogueTarifaireController.getCatalogueLigne';
import deleteCatalogueLigne from '@salesforce/apex/LC022CatalogueTarifaireController.deleteCatalogueLigne';
import getObjectFields from '@salesforce/apex/LC022CatalogueTarifaireController.getObjectFields';
import getAccountsByIds from '@salesforce/apex/LC022CatalogueTarifaireController.getAccountsByIds';
import {
    formatForDisplay,
    legacyTokensToExpression,
    legacyFactorFieldToExpression
} from 'c/lwc022FormulaUtils';

// Champs picklist dont on affiche le LIBELLÉ (et non la valeur/API stockée).
const LABEL_FIELDS = ['FicheCEE__c', 'RoleIntervenant__c', 'Statut__c', 'Paiement__c'];

// Classe de badge par valeur de statut.
const STATUT_BADGE = {
    Active: 'pf-badge pf-badge-success',
    Inactive: 'pf-badge pf-badge-danger',
    Archivée: 'pf-badge pf-badge-muted'
};

/**
 * Onglet 1 : liste des lignes de catalogue existantes.
 * Affiche pour chaque ligne ses champs fixes et le NOMBRE de règles (compté côté
 * serveur) ; le JSON ParametresFiche__c n'est PAS chargé au premier rendu.
 * Chaque ligne est DÉPLIABLE (accordéon) : le récap des règles (SI / ALORS,
 * comme au formulaire) est chargé À LA DEMANDE au premier dépliage via
 * getCatalogueLigne, puis mis en cache pour la durée de vie du composant.
 * Émet « new » (créer) et « edit » (modifier une ligne) vers le parent.
 *
 * Chargement impératif (et non @wire cacheable) : le composant est remonté à
 * chaque entrée d'onglet par le parent, ce qui garantit des données fraîches
 * après une création / modification réalisée dans l'onglet du formulaire.
 */
// Clé localStorage pour mémoriser les filtres entre deux actualisations
// (préférence par navigateur / utilisateur).
const FILTERS_STORAGE_KEY = 'lwc022CatalogueListe.filters';

export default class Lwc022CatalogueListe extends LightningElement {
    allRows = [];
    error;
    loading = false;
    labelMaps = {};
    pickOptions = {};
    // Dépliage des lignes (accordéon) : ids dépliés + détails chargés à la demande
    // ({ [id]: { status: 'loading'|'error'|'ready', ... } }).
    expandedIds = {};
    detailsById = {};
    // Describe du dossier (labels de champs + libellés picklist), chargé UNE fois
    // au premier dépliage (jamais au chargement initial du composant).
    dossierDescribePromise = null;
    // Statut filtré sur « Active » par défaut (les lignes inactives/archivées
    // restent accessibles via le filtre ou « Réinitialiser »). Paiement filtré sur
    // « Émis » par défaut (le sens Reçu sera traité plus tard).
    filters = { recordType: 'Standard', fiche: '', role: '', intervenant: '', statut: 'Active', paiement: 'Emis' };

    connectedCallback() {
        this.restoreFilters();
        this.loadData();
    }

    // Restaure les filtres mémorisés (localStorage) PAR-DESSUS les valeurs par défaut :
    // les clés absentes du stockage gardent leur défaut.
    restoreFilters() {
        try {
            const raw = window.localStorage.getItem(FILTERS_STORAGE_KEY);
            if (raw) {
                const saved = JSON.parse(raw);
                if (saved && typeof saved === 'object') {
                    this.filters = { ...this.filters, ...saved };
                }
            }
        } catch (e) {
            // localStorage indisponible ou JSON illisible : on garde les filtres par défaut.
        }
    }

    // Mémorise les filtres courants pour les réappliquer après une actualisation.
    persistFilters() {
        try {
            window.localStorage.setItem(FILTERS_STORAGE_KEY, JSON.stringify(this.filters));
        } catch (e) {
            // localStorage indisponible / quota dépassé : sans effet (non bloquant).
        }
    }

    async loadData() {
        this.loading = true;
        // Repli des accordéons + purge des détails : les données rechargées peuvent
        // avoir changé (suppression, actualisation).
        this.expandedIds = {};
        this.detailsById = {};
        try {
            const [data, descriptors] = await Promise.all([
                getCatalogueLignes(),
                getObjectFields({ objectApiName: 'CatalogueTarifaire__c', fieldApiNames: LABEL_FIELDS })
            ]);
            this.labelMaps = this.buildLabelMaps(descriptors);
            this.pickOptions = this.buildPickOptions(descriptors);
            const records = (data || []).map((dto) => dto || {});
            // Résout les noms des comptes (Intervenants__c = IDs concaténés).
            const accountNames = await this.resolveAccountNames(
                this.collectAccountIds(records.map((dto) => dto.ligne || {}))
            );
            this.allRows = records.map((dto) => this.decorate(dto, accountNames));
            this.error = undefined;
        } catch (e) {
            this.error = this.reduceError(e);
        } finally {
            this.loading = false;
        }
    }

    // Construit { apiName: { valeurStockée: libellé } } pour les champs picklist.
    buildLabelMaps(descriptors) {
        const maps = {};
        (descriptors || []).forEach((d) => {
            if (d.picklistValues && d.picklistValues.length) {
                const m = {};
                d.picklistValues.forEach((p) => {
                    m[p.value] = p.label;
                });
                maps[d.apiName] = m;
            }
        });
        return maps;
    }

    // Construit { apiName: [{label, value}] } pour alimenter les filtres.
    buildPickOptions(descriptors) {
        const out = {};
        (descriptors || []).forEach((d) => {
            if (d.picklistValues && d.picklistValues.length) {
                out[d.apiName] = d.picklistValues.map((p) => ({ label: p.label, value: p.value }));
            }
        });
        return out;
    }

    // Renvoie le libellé de la valeur stockée (ou la valeur brute si non trouvée).
    pickLabel(field, value) {
        if (!value) return '—';
        const map = this.labelMaps[field];
        return (map && map[value]) || value;
    }

    decorate(dto, accountNames) {
        // Le compte de règles est calculé côté serveur : le JSON ParametresFiche__c
        // n'est plus expédié à la liste (chargé à la demande au dépliage).
        const record = dto.ligne || {};
        const nbRegles = dto.nbRegles || 0;
        const names = accountNames || {};
        const pills = this.parseIntervenantIds(record.Intervenants__c).map((id) => ({
            id,
            name: names[id] || id
        }));
        return {
            id: record.Id,
            name: record.Name,
            fiche: this.pickLabel('FicheCEE__c', record.FicheCEE__c),
            role: this.pickLabel('RoleIntervenant__c', record.RoleIntervenant__c),
            statut: this.pickLabel('Statut__c', record.Statut__c),
            statutBadgeClass: STATUT_BADGE[record.Statut__c] || 'pf-badge pf-badge-muted',
            intervenants: pills,
            intervenantsLabel: pills.length ? pills.map((p) => p.name).join(', ') : '—',
            ficheValue: record.FicheCEE__c || '',
            roleValue: record.RoleIntervenant__c || '',
            statutValue: record.Statut__c || '',
            paiementValue: record.Paiement__c || '',
            recordTypeDev: record.RecordType ? record.RecordType.DeveloperName : '',
            debut: record.DateDebutValidite__c,
            fin: record.DateFinValidite__c,
            nbRegles,
            montantsModifiablesLabel: record.Montants_modifiables__c === true ? 'Oui' : 'Non',
            montantsModifiablesBadgeClass:
                record.Montants_modifiables__c === true ? 'pf-badge pf-badge-success' : 'pf-badge pf-badge-muted'
        };
    }

    // IDs de comptes distincts présents dans toutes les lignes (champ Intervenants__c).
    collectAccountIds(records) {
        const set = new Set();
        records.forEach((r) => {
            this.parseIntervenantIds(r.Intervenants__c).forEach((id) => set.add(id));
        });
        return [...set];
    }

    async resolveAccountNames(ids) {
        if (!ids.length) return {};
        try {
            const accounts = await getAccountsByIds({ accountIds: ids });
            const map = {};
            (accounts || []).forEach((a) => {
                map[a.Id] = a.Name;
            });
            return map;
        } catch (e) {
            return {};
        }
    }

    parseIntervenantIds(raw) {
        if (!raw) return [];
        const seen = new Set();
        const out = [];
        String(raw)
            .split(';')
            .forEach((s) => {
                const id = s.trim();
                if (id && !seen.has(id)) {
                    seen.add(id);
                    out.push(id);
                }
            });
        return out;
    }

    // Lignes filtrées (par valeur stockée) + état de dépliage (accordéon).
    get rows() {
        const f = this.filters;
        return this.allRows
            .filter(
                (r) =>
                    (!f.recordType || r.recordTypeDev === f.recordType) &&
                    (!f.fiche || r.ficheValue === f.fiche) &&
                    (!f.role || r.roleValue === f.role) &&
                    (!f.intervenant || r.intervenants.some((p) => p.id === f.intervenant)) &&
                    (!f.statut || r.statutValue === f.statut) &&
                    // Le paiement (Émis/Reçu) n'existe que sur le Standard : le filtre ne
                    // contraint donc que les lignes Standard ; les autres types passent.
                    (!f.paiement || r.recordTypeDev !== 'Standard' || r.paiementValue === f.paiement)
            )
            .map((r) => {
                const expanded = !!this.expandedIds[r.id];
                const detail = this.detailsById[r.id] || { status: 'loading' };
                return {
                    ...r,
                    expanded,
                    detailKey: r.id + '-detail',
                    detailIcon: expanded ? 'utility:chevrondown' : 'utility:chevronright',
                    detailLoading: detail.status === 'loading',
                    detailError: detail.status === 'error' ? detail.error : null,
                    detailReady: detail.status === 'ready',
                    detailRegles: detail.regles || [],
                    detailHasRegles: (detail.regles || []).length > 0,
                    detailEcheanceSupp: detail.echeanceSupp || null,
                    detailParseError: !!detail.parseError,
                    // « Aucune règle » : seulement si le JSON est lisible mais vide
                    // (sinon c'est l'avertissement d'illisibilité qui s'affiche).
                    detailShowEmpty: !(detail.regles || []).length && !detail.parseError
                };
            });
    }

    get hasRows() {
        return this.rows.length > 0;
    }

    get hasAnyRows() {
        return this.allRows.length > 0;
    }

    get isFiltered() {
        const f = this.filters;
        return !!(f.fiche || f.role || f.intervenant || f.statut);
    }

    // Options des filtres (préfixées d'un « Tous »).
    optionsFor(field) {
        return [{ label: 'Tous', value: '' }, ...(this.pickOptions[field] || [])];
    }
    get recordTypeOptions() {
        return [
            { label: 'Tous', value: '' },
            { label: 'Standard', value: 'Standard' },
            { label: 'Supplémentaire', value: 'Supplementaire' },
            { label: 'Acompte', value: 'Acompte' }
        ];
    }
    get ficheOptions() {
        return this.optionsFor('FicheCEE__c');
    }
    get roleOptions() {
        return this.optionsFor('RoleIntervenant__c');
    }
    get statutOptions() {
        return this.optionsFor('Statut__c');
    }
    get paiementOptions() {
        return this.optionsFor('Paiement__c');
    }

    // Comptes RÉELLEMENT présents dans les lignes (distincts), triés par nom.
    get intervenantOptions() {
        const byId = new Map();
        this.allRows.forEach((r) => {
            r.intervenants.forEach((p) => {
                byId.set(p.id, p.name);
            });
        });
        const opts = [...byId.entries()]
            .map(([value, label]) => ({ label, value }))
            .sort((a, b) => a.label.localeCompare(b.label));
        return [{ label: 'Tous', value: '' }, ...opts];
    }

    handleFilterChange(event) {
        const key = event.target.dataset.filter; // fiche | role | intervenant | statut
        this.filters = { ...this.filters, [key]: event.detail.value };
        this.persistFilters();
    }

    handleResetFilters() {
        // On conserve le type Standard et le paiement Émis par défaut (filtres « cadre »
        // qui ne déclenchent pas le bouton Réinitialiser).
        this.filters = { recordType: 'Standard', fiche: '', role: '', intervenant: '', statut: '', paiement: 'Emis' };
        this.persistFilters();
    }

    handleNew() {
        this.dispatchEvent(new CustomEvent('new'));
    }

    handleEdit(event) {
        const recordId = event.currentTarget.dataset.id;
        this.dispatchEvent(new CustomEvent('edit', { detail: { recordId } }));
    }

    handleClone(event) {
        const recordId = event.currentTarget.dataset.id;
        this.dispatchEvent(new CustomEvent('clone', { detail: { recordId } }));
    }

    // ------------------------- Dépliage (récap des règles, chargé à la demande)

    handleToggleDetail(event) {
        const id = event.currentTarget.dataset.id;
        if (this.expandedIds[id]) {
            // Repli : on garde le détail en cache pour un réaffichage instantané.
            const next = { ...this.expandedIds };
            delete next[id];
            this.expandedIds = next;
            return;
        }
        this.expandedIds = { ...this.expandedIds, [id]: true };
        // (Re)charge si jamais chargé OU si le dernier essai a échoué (erreur
        // transitoire réseau/session) : sinon la ligne resterait figée sur l'erreur.
        const cached = this.detailsById[id];
        if (!cached || cached.status === 'error') {
            this.loadDetail(id);
        }
    }

    async loadDetail(id) {
        this.setDetail(id, { status: 'loading' });
        try {
            // Describe du dossier (labels) + JSON de la ligne, chargés en parallèle.
            const [describe, record] = await Promise.all([
                this.ensureDossierDescribe(),
                getCatalogueLigne({ recordId: id })
            ]);
            this.setDetail(id, { status: 'ready', ...this.buildDetail(record, describe) });
        } catch (e) {
            this.setDetail(id, { status: 'error', error: this.reduceError(e) });
        }
    }

    setDetail(id, value) {
        this.detailsById = { ...this.detailsById, [id]: value };
    }

    // Labels des champs du dossier (formules) + libellés picklist (conditions),
    // chargés une seule fois au premier dépliage. En cas d'échec, on affiche les
    // API names bruts plutôt que de bloquer le récap.
    ensureDossierDescribe() {
        if (!this.dossierDescribePromise) {
            this.dossierDescribePromise = getObjectFields({ objectApiName: 'Pro__c', fieldApiNames: null })
                .then((fields) => {
                    const labelByApi = {};
                    const typeByApi = {};
                    const picklistByField = {};
                    (fields || []).forEach((d) => {
                        labelByApi[d.apiName] = d.label;
                        typeByApi[d.apiName] = d.dataType;
                        if (d.picklistValues && d.picklistValues.length) {
                            const m = {};
                            d.picklistValues.forEach((p) => {
                                m[String(p.value)] = p.label;
                            });
                            picklistByField[d.apiName] = m;
                        }
                    });
                    return { labelByApi, typeByApi, picklistByField };
                })
                .catch(() => ({ labelByApi: {}, typeByApi: {}, picklistByField: {} }));
        }
        return this.dossierDescribePromise;
    }

    // Récap des règles d'une ligne (même lecture SI / ALORS que le formulaire),
    // construit depuis le JSON sérialisé ParametresFiche__c.
    buildDetail(record, describe) {
        const rt = record.RecordType ? record.RecordType.DeveloperName : '';
        // Supplémentaire / Acompte : montant unique (pas de Montant 2).
        const ligneUnique = rt === 'Supplementaire' || rt === 'Acompte';
        // L'échéance déclenchante Supplémentaire est un champ de la LIGNE, indépendant
        // du JSON : à conserver même quand ce dernier est illisible.
        const echeanceSupp = rt === 'Supplementaire' ? record.echeanceSupp__c || null : null;
        let parsed = null;
        if (record.ParametresFiche__c) {
            try {
                parsed = JSON.parse(record.ParametresFiche__c);
            } catch (e) {
                // JSON corrompu : on signale (≠ silencieux) mais on garde l'échéance ligne.
                return { regles: [], echeanceSupp, parseError: true };
            }
        }
        const vars = parsed && Array.isArray(parsed.decisionVariables) ? parsed.decisionVariables : [];
        const rules = parsed && Array.isArray(parsed.rules) ? parsed.rules : [];
        const regles = rules.map((r, i) => ({
            key: r.id || 'r' + i,
            index: i + 1,
            hasConditions: vars.length > 0,
            conditions: vars.map((v) => {
                // Repli pour les anciens JSON sans label/type (comme le formulaire) :
                // sinon on afficherait « undefined = <valeur brute> ».
                const label = v.label || (describe.labelByApi || {})[v.field] || v.field;
                const type = v.type || (describe.typeByApi || {})[v.field] || 'text';
                const resolved = { ...v, label, type };
                return {
                    key: v.field,
                    text: label + ' ' + this.detailConditionText(resolved, (r.conditions && r.conditions[v.field]) || {}, describe)
                };
            }),
            montant1Text: this.detailMontantText(r.montant1, ligneUnique ? null : record.EcheancePaiement1__c, describe),
            montant2Text: this.detailMontantText(r.montant2, record.EcheancePaiement2__c, describe),
            showMontant2: !ligneUnique,
            commentaire: r.commentaire || '',
            hasComment: !!(r.commentaire && String(r.commentaire).trim())
        }));
        return { regles, echeanceSupp, parseError: false };
    }

    // Texte d'une condition sérialisée (mêmes conventions que le formulaire).
    detailConditionText(variable, cond, describe) {
        if (variable.comparison === 'interval') {
            const fmt = (x) => (x === undefined || x === null || x === '' ? '…' : x);
            return '∈ [' + fmt(cond.min) + ' – ' + fmt(cond.max) + ']';
        }
        let val = cond.value;
        if (variable.type === 'picklist') {
            const m = (describe.picklistByField || {})[variable.field] || {};
            if (m[String(val)]) val = m[String(val)];
        } else if (variable.type === 'boolean') {
            val = val === true || val === 'true' ? 'Vrai' : 'Faux';
        }
        return '= ' + (val === undefined || val === null || val === '' ? '—' : val);
    }

    // Texte d'un montant sérialisé (fixe ou formule ; tolère les anciens formats
    // tokens / factor+field). L'échéance du JSON prime, repli sur le champ fixe
    // (anciennes lignes Standard).
    detailMontantText(m, echeanceRepli, describe) {
        // Montant absent : on affiche quand même l'échéance de repli (champ fixe),
        // comme le formulaire (« — → <échéance> ») pour les anciennes lignes Standard.
        if (!m || typeof m !== 'object') {
            return echeanceRepli ? '— → ' + echeanceRepli : '—';
        }
        let base;
        if (m.mode === 'formula') {
            let expr = typeof m.expression === 'string' ? m.expression : null;
            if (expr === null && Array.isArray(m.tokens)) expr = legacyTokensToExpression(m.tokens);
            if (expr === null) expr = legacyFactorFieldToExpression(m.factor, m.field);
            expr = (expr || '').trim();
            base = expr ? formatForDisplay(expr, describe.labelByApi || {}) : '—';
        } else {
            base = m.value === undefined || m.value === null || m.value === '' ? '—' : m.value + ' €';
        }
        const echeance = m.echeance || echeanceRepli;
        return echeance ? base + ' → ' + echeance : base;
    }

    async handleDelete(event) {
        const recordId = event.currentTarget.dataset.id;
        const confirmed = await LightningConfirm.open({
            message: 'Supprimer définitivement cette ligne de catalogue ?',
            label: 'Confirmation de suppression',
            theme: 'warning'
        });
        if (!confirmed) {
            return;
        }
        this.loading = true;
        try {
            await deleteCatalogueLigne({ recordId });
            this.toast('Ligne supprimée', 'La ligne de catalogue a été supprimée.', 'success');
            await this.loadData();
        } catch (e) {
            this.toast('Erreur', this.reduceError(e), 'error');
        } finally {
            this.loading = false;
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