import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import getDonnees from '@salesforce/apex/PrevisiteurCpController.getDonnees';
import enregistrerProvinces from '@salesforce/apex/PrevisiteurCpController.enregistrerProvinces';
import getContexte from '@salesforce/apex/PrevisiteurCpController.getContexte';
import attribuerApex from '@salesforce/apex/PrevisiteurCpController.attribuer';

/* ======================================================================
   PROVINCES : lues dans l'objet « Province » (Province__c), modifiables
   par un administrateur via la modale « Gérer les provinces ».
   Indexées ici par code : n = nom, c = [lat, lon] du chef-lieu (ou null),
   a = codes des provinces limitrophes (= « zones adjacentes »).
   ====================================================================== */
function indexer(provinces) {
    const prov = {};
    (provinces || []).forEach(p => {
        prov[p.code] = {
            n: p.nom,
            c: p.lat != null && p.lon != null ? [Number(p.lat), Number(p.lon)] : null,
            a: p.adjacentes || []
        };
    });
    return prov;
}

const msg = e => (e && e.body && e.body.message) || (e && e.message) || 'erreur inconnue';
let cleLigne = 0;

function km(a, b) {
    const R = 6371, dLa = (b[0] - a[0]) * Math.PI / 180, dLo = (b[1] - a[1]) * Math.PI / 180;
    const x = Math.sin(dLa / 2) ** 2 + Math.cos(a[0] * Math.PI / 180) * Math.cos(b[0] * Math.PI / 180) * Math.sin(dLo / 2) ** 2;
    return Math.round(2 * R * Math.atan2(Math.sqrt(x), Math.sqrt(1 - x)));
}

export default class PrevisiteurParCp extends LightningElement {
    /* ---------- mode FICHE : action rapide sur Piste (Lead) ou Dossiers (Pro__c) ----------
       Le code postal est prérempli depuis la fiche ; le modifier ici ne réécrit JAMAIS la fiche.
       Seul le bouton « Attribuer » écrit, et uniquement le lookup prévisiteur. */
    _recordId;
    @api objectApiName;
    @api
    get recordId() { return this._recordId; }
    set recordId(v) {
        const change = v && v !== this._recordId;
        this._recordId = v;
        if (change) this.chargerContexte();
    }
    contexte;                   // { codePostal, compteActuelId, compteActuelNom }
    attributionEnCours = false;

    @track cp = '';
    @track previsiteurs = [];   // [{ id, nom, mail, zones:['34','47'], actif, dispo }]
    provinces = [];             // ProvinceDTO reçus d'Apex
    prov = {};                  // les mêmes, indexés par code
    estAdmin = false;
    loading = true;
    error;
    copied = null;

    /* modale d'administration des provinces */
    modaleOuverte = false;
    @track lignes = [];         // copie éditable de provinces
    filtre = '';
    enregistrement = false;
    erreurModale;

    connectedCallback() { this.charger(); }

    /* Fenêtre de l'action rapide élargie : sa largeur est fixée par Salesforce, hors de
       portée du CSS du composant. La règle ne vise QUE la fenêtre qui contient ce composant
       (:has) et disparaît avec lui. */
    renderedCallback() {
        if (this.styleInjecte || !this.modeFiche) return;
        const hote = this.template.querySelector('.style-hote');
        if (!hote) return;
        const style = document.createElement('style');
        style.textContent =
            '.slds-modal__container:has(c-previsiteur-par-cp), .modal-container:has(c-previsiteur-par-cp)' +
            '{ width: 92% !important; max-width: 1400px !important; }' +
            '.slds-modal__content:has(c-previsiteur-par-cp), .modal-body:has(c-previsiteur-par-cp)' +
            '{ max-height: 85vh !important; height: auto !important; }';
        hote.appendChild(style);
        this.styleInjecte = true;
    }

    charger() {
        this.loading = true;
        return getDonnees()
            .then(d => this.appliquer(d))
            .catch(e => { this.error = 'Impossible de charger les prévisiteurs : ' + msg(e); })
            .finally(() => { this.loading = false; });
    }
    appliquer(d) {
        this.error = undefined;
        this.provinces = d.provinces || [];
        this.prov = indexer(this.provinces);
        this.previsiteurs = d.previsiteurs || [];
        this.estAdmin = d.estAdmin === true;
    }
    get modeFiche() { return !!this._recordId; }
    get afficherAdmin() { return this.estAdmin && !this.modeFiche; }
    get cpFiche() { return this.contexte && this.contexte.codePostal ? String(this.contexte.codePostal).replace(/\D/g, '').slice(0, 5) : ''; }
    get cpDifferent() { return this.modeFiche && !!this.cpFiche && this.cp !== this.cpFiche; }
    get previsiteurActuel() { return this.contexte && this.contexte.compteActuelNom ? this.contexte.compteActuelNom : 'aucun'; }

    chargerContexte() {
        return getContexte({ recordId: this._recordId })
            .then(c => {
                this.contexte = c;
                if (!this.cp) this.cp = this.cpFiche;
            })
            .catch(e => { this.error = 'Impossible de lire la fiche : ' + msg(e); });
    }
    reprendreCpFiche() { this.cp = this.cpFiche; }

    attribuer(e) {
        const { compte, nom } = e.currentTarget.dataset;
        this.attributionEnCours = true;
        attribuerApex({ recordId: this._recordId, compteId: compte })
            .then(c => {
                this.contexte = c;
                this.dispatchEvent(new ShowToastEvent({ title: 'Prévisiteur attribué', message: nom, variant: 'success' }));
                notifyRecordUpdateAvailable([{ recordId: this._recordId }]);
                // Action rapide (Lightning) : ferme la fenêtre. Bouton du portail : le parent écoute « fermer ».
                this.dispatchEvent(new CloseActionScreenEvent());
                this.dispatchEvent(new CustomEvent('fermer'));
            })
            .catch(err => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Attribution impossible', message: msg(err), variant: 'error', mode: 'sticky' }));
            })
            .finally(() => { this.attributionEnCours = false; });
    }

    get aucuneProvince() { return !this.loading && !this.error && this.provinces.length === 0; }

    /* ---------- saisie ---------- */
    handleCp(e) { this.cp = (e.target.value || '').replace(/\D/g, '').slice(0, 5); }
    clear() { this.cp = ''; const i = this.template.querySelector('.cp-input'); if (i) i.value = ''; }

    get provinceCode() { return this.cp.length >= 2 ? this.cp.slice(0, 2) : null; }
    get province() { return this.provinceCode && this.prov[this.provinceCode] ? this.prov[this.provinceCode] : null; }
    get adjacents() { return this.province ? this.province.a.map(c => ({ code: c, n: this.prov[c] ? this.prov[c].n : c })) : []; }
    get hasAdjacents() { return this.adjacents.length > 0; }
    get hint() {
        if (this.cp.length >= 2 && !this.province) return 'Code postal inconnu : les deux premiers chiffres (' + this.provinceCode + ') ne correspondent à aucune province.';
        return 'Entrez les 2 premiers chiffres pour identifier la province.';
    }
    get hintClass() { return this.cp.length >= 2 && !this.province ? 'hint err' : 'hint'; }
    get showResults() { return !!this.province && !this.loading; }

    /* ---------- calcul ---------- */
    distTo(code, zones) {
        let best = null;
        const origine = this.prov[code].c;
        if (!origine) return null;
        (zones || []).forEach(z => { if (!this.prov[z] || !this.prov[z].c) return; const d = km(origine, this.prov[z].c); if (best === null || d < best) best = d; });
        return best;
    }
    estActuel(p) { return !!(this.contexte && p.compteId && this.contexte.compteActuelId === p.compteId); }
    decorate(p, code) {
        const d = this.distTo(code, p.zones);
        const adj = this.prov[code].a;
        return {
            ...p,
            key: p.id || p.nom,
            zonesView: (p.zones || []).map(z => ({ code: z, n: this.prov[z] ? this.prov[z].n : z, cls: 'zone' + (z === code ? ' hit' : (adj.includes(z) ? ' adj' : '')) })),
            dist: d,
            distTxt: d === null ? '—' : (d < 15 ? 'sur place' : '≈ ' + d + ' km'),
            distClass: 'dist ' + (d === null ? '' : (d < 60 ? 'tg' : (d <= 150 ? 'to' : 'tf'))),
            initiales: (p.nom || '?').split(/\s+/).filter(m => m).slice(0, 2).map(m => m[0].toUpperCase()).join(''),
            estActuel: this.estActuel(p),
            sansCompte: !p.compteId,
            carteClass: 'ligne' + (this.estActuel(p) ? ' actuelle' : '') + (p.actif ? '' : ' inactive'),
            attribuerVariant: this.estActuel(p) ? 'neutral' : 'brand',
            statut: p.actif ? 'Actif' : 'Inactif',
            pillClass: p.actif ? 'pill ok' : 'pill grey',
            attribuerLabel: this.estActuel(p) ? 'Attribué' : 'Attribuer',
            attribuerDisabled: !p.compteId || this.attributionEnCours || this.estActuel(p),
            attribuerTitre: p.compteId ? 'Attribuer ' + p.nom + ' à cette fiche' : 'Aucun compte « PREVISITEUR- » rattaché à cette campagne',
            copyLabel: this.copied === p.nom ? '✓ Copié' : 'Copier',
            copyClass: this.copied === p.nom ? 'copy ok' : 'copy'
        };
    }
    sortRows(a, b) { return (b.actif - a.actif) || ((a.dist ?? 9999) - (b.dist ?? 9999)) || a.nom.localeCompare(b.nom); }
    get inZone() {
        if (!this.province) return [];
        const code = this.provinceCode;
        return this.previsiteurs.filter(p => (p.zones || []).includes(code)).map(p => this.decorate(p, code)).sort(this.sortRows);
    }
    get adjacent() {
        if (!this.province) return [];
        const code = this.provinceCode, adj = this.province.a;
        return this.previsiteurs
            .filter(p => !(p.zones || []).includes(code) && (p.zones || []).some(z => adj.includes(z)))
            .map(p => this.decorate(p, code)).sort(this.sortRows);
    }

    /* ---------- copier le nom ---------- */
    copyName(e) {
        const name = e.currentTarget.dataset.name;
        const done = () => { this.copied = name; this.previsiteurs = [...this.previsiteurs]; setTimeout(() => { this.copied = null; this.previsiteurs = [...this.previsiteurs]; }, 1400); };
        if (navigator.clipboard && navigator.clipboard.writeText) { navigator.clipboard.writeText(name).then(done).catch(() => this.fallbackCopy(name, done)); }
        else this.fallbackCopy(name, done);
    }
    fallbackCopy(text, done) {
        const ta = document.createElement('textarea'); ta.value = text; ta.style.position = 'fixed'; ta.style.opacity = '0';
        document.body.appendChild(ta); ta.select();
        try { document.execCommand('copy'); } catch (err) { /* ignore */ }
        document.body.removeChild(ta); done();
    }

    /* ---------- administration des provinces (modale, admins seulement) ---------- */
    ouvrirModale() {
        this.lignes = this.provinces.map(p => ({
            key: 'l' + (++cleLigne), id: p.id, code: p.code, nom: p.nom,
            lat: p.lat, lon: p.lon, adjacentes: (p.adjacentes || []).join(';'), alias: p.alias || ''
        }));
        this.filtre = '';
        this.erreurModale = undefined;
        this.modaleOuverte = true;
    }
    fermerModale() { if (!this.enregistrement) this.modaleOuverte = false; }
    handleFiltre(e) { this.filtre = (e.target.value || '').trim().toLowerCase(); }
    get lignesVisibles() {
        const f = this.filtre;
        if (!f) return this.lignes;
        return this.lignes.filter(l => !l.id || (l.code || '').includes(f) || (l.nom || '').toLowerCase().includes(f) || (l.alias || '').toLowerCase().includes(f));
    }
    get nbLignes() { return this.lignes.length; }
    handleCellule(e) {
        const { key, champ } = e.target.dataset;
        const ligne = this.lignes.find(l => l.key === key);
        if (ligne) ligne[champ] = e.target.value;
    }
    ajouterLigne() {
        this.lignes = [{ key: 'l' + (++cleLigne), id: null, code: '', nom: '', lat: null, lon: null, adjacentes: '', alias: '' }, ...this.lignes];
    }
    supprimerLigne(e) {
        const key = e.currentTarget.dataset.key;
        this.lignes = this.lignes.filter(l => l.key !== key);
    }
    enregistrer() {
        const nombre = v => (v === '' || v === null || v === undefined ? null : Number(String(v).replace(',', '.')));
        const payload = this.lignes.map(l => ({
            id: l.id || null,
            code: (l.code || '').trim(),
            nom: (l.nom || '').trim(),
            lat: nombre(l.lat),
            lon: nombre(l.lon),
            adjacentes: (l.adjacentes || '').split(/[;,\s]+/).map(c => c.trim()).filter(c => c),
            alias: l.alias || null
        }));
        const invalide = payload.find(p => (p.lat !== null && isNaN(p.lat)) || (p.lon !== null && isNaN(p.lon)));
        if (invalide) { this.erreurModale = 'Province ' + (invalide.code || '(sans code)') + ' : latitude / longitude non numérique.'; return; }

        this.enregistrement = true;
        this.erreurModale = undefined;
        enregistrerProvinces({ provincesJson: JSON.stringify(payload) })
            .then(d => { this.appliquer(d); this.modaleOuverte = false; })
            .catch(e => { this.erreurModale = msg(e); })
            .finally(() => { this.enregistrement = false; });
    }
}