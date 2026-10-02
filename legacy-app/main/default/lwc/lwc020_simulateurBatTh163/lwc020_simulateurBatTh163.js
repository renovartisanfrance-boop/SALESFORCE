import { LightningElement, track } from 'lwc';

const CONFIG = {
    PRIX_M2:          { Bureaux: 31.68, Autres: 18.48 },
    RATIO_M2_PAR_KW:  { Bureaux: 15,    Autres: 20    },
    SURFACE_MIN_M2:   { Bureaux: 2000,  Autres: 3500  },
    PAC_KW:           30,
    CASCADE_MAX:      6,
    COMMISSION_RATE:  { H1: 0.10, H2: 0.08 },
    OVERMAX_DECOTE:   0.20,
};

const fmtNum = (n) => new Intl.NumberFormat('fr-FR', { maximumFractionDigits: 0 }).format(n);
const fmtKw  = (n) => new Intl.NumberFormat('fr-FR', { maximumFractionDigits: 0 }).format(Math.round(n));

export default class Lwc020SimulateurBatTh163 extends LightningElement {
    @track secteur = '';
    @track zone = '';
    @track surface = null;
    @track activeInfoId = null;

    handleInfoToggle(event) {
        event.stopPropagation();
        const id = event.currentTarget.dataset.id;
        this.activeInfoId = (this.activeInfoId === id) ? null : id;
    }

    get isInfoSecteur() { return this.activeInfoId === 'secteur'; }
    get isInfoSurface() { return this.activeInfoId === 'surface'; }
    get isInfoZone() { return this.activeInfoId === 'zone'; }

    get classInfoSecteur() { return this.isInfoSecteur ? 'info-toggle active' : 'info-toggle'; }
    get classInfoSurface() { return this.isInfoSurface ? 'info-toggle active' : 'info-toggle'; }
    get classInfoZone() { return this.isInfoZone ? 'info-toggle active' : 'info-toggle'; }

    // ━━━ Couleurs sémantiques dynamiques ━━━
    get secteurIconClass() {
        if (this.secteur === 'Bureaux') return 'label-icon label-icon--medical';
        if (this.secteur === 'Autres') return 'label-icon label-icon--indigo';
        return 'label-icon';
    }

    get surfaceIconClass() {
        return 'label-icon label-icon--fire';
    }

    get zoneIconClass() {
        if (this.zone === 'H1') return 'label-icon label-icon--cold';
        if (this.zone === 'H2') return 'label-icon label-icon--warm';
        return 'label-icon';
    }

    pillClass(active, variant) {
        if (!active) return 'pill';
        return 'pill pill--active pill--' + variant;
    }

    get secteurOptions() {
        return [
            { label: 'Bureaux / Santé', value: 'Bureaux', iconMedical: true, class: this.pillClass(this.secteur === 'Bureaux', 'medical') },
            { label: 'Autres', value: 'Autres', iconStore: true, class: this.pillClass(this.secteur === 'Autres', 'indigo') },
        ];
    }

    get zoneOptions() {
        return [
            { label: 'H1', value: 'H1', iconCold: true, class: this.pillClass(this.zone === 'H1', 'cold') },
            { label: 'H2', value: 'H2', iconWarm: true, class: this.pillClass(this.zone === 'H2', 'warm') },
        ];
    }

    handleSecteurClick(event) {
        this.secteur = event.currentTarget.dataset.value;
    }

    handleZoneClick(event) {
        this.zone = event.currentTarget.dataset.value;
    }

    handleSurfaceChange(event) {
        const v = parseFloat(event.target.value);
        this.surface = isNaN(v) ? null : v;
    }

    get state() {
        const secteur = this.secteur;
        const zone = this.zone;
        const surface = this.surface;

        if (!secteur || !zone) {
            return { kind: 'empty' };
        }

        if (!surface || isNaN(surface) || surface <= 0) {
            return { kind: 'empty' };
        }

        const minSurface = CONFIG.SURFACE_MIN_M2[secteur];
        if (surface < minSurface) {
            return { kind: 'tooSmall', secteur, minSurface };
        }

        const ratio = CONFIG.RATIO_M2_PAR_KW[secteur];
        const need = surface / ratio;
        const N = Math.ceil((need * 0.4) / CONFIG.PAC_KW);

        if (N > CONFIG.CASCADE_MAX) {
            const maxSurface = (CONFIG.CASCADE_MAX * CONFIG.PAC_KW * ratio) / 0.4;
            const cappedN = CONFIG.CASCADE_MAX;
            const cappedPacKw = cappedN * CONFIG.PAC_KW;
            const actualNeed = surface / ratio;
            const boilerKw = Math.max(0, actualNeed - cappedPacKw);
            const prime = CONFIG.PRIX_M2[secteur] * surface;
            const rate = CONFIG.COMMISSION_RATE[zone];
            const commission = prime * rate * (1 - CONFIG.OVERMAX_DECOTE);
            return {
                kind: 'overMax',
                inputSurface: surface,
                maxSurface: Math.floor(maxSurface),
                N: cappedN,
                pacKw: cappedPacKw,
                boilerKw,
                commission,
            };
        }

        const pacKw = N * CONFIG.PAC_KW;
        const boilerKw = Math.max(0, need - pacKw);
        const prime = CONFIG.PRIX_M2[secteur] * surface;
        const rate = CONFIG.COMMISSION_RATE[zone];
        const commission = prime * rate;

        return { kind: 'ok', N, pacKw, boilerKw, commission };
    }

    get isEmpty() { return this.state.kind === 'empty'; }
    get isTooSmall() { return this.state.kind === 'tooSmall'; }
    get isOverMax() { return this.state.kind === 'overMax'; }
    get isOk() { return this.state.kind === 'ok'; }

    get commissionStr() { return fmtNum(this.state.commission || 0); }
    get maxSurfaceStr() { return fmtNum(this.state.maxSurface || 0); }
    get minSurfaceStr() { return fmtNum(this.state.minSurface || 0); }
    get tooSmallSecteur() { return this.state.secteur; }
    get nbPac() { return this.state.N; }
    get pacWord() { return (this.state.N || 0) > 1 ? 'pompes à chaleur' : 'pompe à chaleur'; }
    get pacUnitKw() { return CONFIG.PAC_KW; }
    get pacKwStr() { return fmtKw(this.state.pacKw || 0); }
    get boilerKwStr() { return fmtKw(this.state.boilerKw || 0); }
}