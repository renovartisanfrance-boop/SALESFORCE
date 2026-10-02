import { LightningElement, track } from 'lwc';

const BAREME = {
    'H1_CH_CL':    2500, 'H1_CH_GP':    4170,
    'H1_CHECS_CL': 3720, 'H1_CHECS_GP': 6045,
    'H2_CH_CL':    2000, 'H2_CH_GP':    3400,
    'H2_CHECS_CL': 3000, 'H2_CHECS_GP': 5000,
};
const TARIF_BAT163 = 25;
const COMMISSION_PAR_ZONE = { 'H1': 0.10, 'H2': 0.08 };
const COUTS_INSTALL = [
    [180,    6000,  8000],
    [300,   10000, 13000],
    [550,   20000, 24000],
    [700,   24000, 29000],
    [850,   30000, 36000],
    [2200,  48000, 48000],
];
const SURFACE_MIN = 100;
const SURFACE_MAX = 2200;
const SEUILS_BENEF = [
    [180,        4000],
    [300,        6000],
    [500,        7000],
    [800,        10000],
    [Infinity,  15000],
];
const SURFACE_MAX_CEF = 2200;
const SURFACE_MIN_ELIGIBLE = 80;
const NB_APPART_MIN_ELIGIBLE = 2;

const PRECO_TIERS = [
    { max: 270,        range: "Pour ≤ 270 m²",     config: "1 Pompe à chaleur Air/Eau" },
    { max: 500,        range: "Pour 271 — 500 m²", config: "2 Pompes à chaleur Air/Eau" },
    { max: 800,        range: "Pour 501 — 800 m²", config: "3 Pompes à chaleur Air/Eau",
      alt: "ou 1 chaudière gaz à condensation + 1 Pompe à chaleur Air/Eau" },
    { max: Infinity,   range: "Pour > 800 m²",     config: "1 chaudière gaz à condensation + N Pompes à chaleur Air/Eau" },
];

const fmtEuro = (n) => new Intl.NumberFormat('fr-FR', {
    style: 'currency', currency: 'EUR', maximumFractionDigits: 0
}).format(n);

export default class Lwc020SimulateurBatTh179 extends LightningElement {
    @track propriete = 'mono';
    @track zone = '';
    @track travaux = '';
    @track nb = null;
    @track surf = null;
    @track gp = 0;
    @track tert = null;
    @track activeInfoId = null;

    handleInfoToggle(event) {
        event.stopPropagation();
        const id = event.currentTarget.dataset.id;
        this.activeInfoId = (this.activeInfoId === id) ? null : id;
    }

    get isInfoPropriete() { return this.activeInfoId === 'propriete'; }
    get isInfoZone() { return this.activeInfoId === 'zone'; }
    get isInfoTravaux() { return this.activeInfoId === 'travaux'; }
    get isInfoSurf() { return this.activeInfoId === 'surf'; }
    get isInfoNb() { return this.activeInfoId === 'nb'; }
    get isInfoGp() { return this.activeInfoId === 'gp'; }
    get isInfoTert() { return this.activeInfoId === 'tert'; }

    get classInfoPropriete() { return this.isInfoPropriete ? 'info-toggle active' : 'info-toggle'; }
    get classInfoZone() { return this.isInfoZone ? 'info-toggle active' : 'info-toggle'; }
    get classInfoTravaux() { return this.isInfoTravaux ? 'info-toggle active' : 'info-toggle'; }
    get classInfoSurf() { return this.isInfoSurf ? 'info-toggle active' : 'info-toggle'; }
    get classInfoNb() { return this.isInfoNb ? 'info-toggle active' : 'info-toggle'; }
    get classInfoGp() { return this.isInfoGp ? 'info-toggle active' : 'info-toggle'; }
    get classInfoTert() { return this.isInfoTert ? 'info-toggle active' : 'info-toggle'; }

    pillClass(active, variant) {
        if (!active) return 'pill';
        return 'pill pill--active pill--' + variant;
    }

    get proprieteOptions() {
        return [
            { label: 'Monopropriété', value: 'mono', iconCopro: true, class: this.pillClass(this.propriete === 'mono', 'success') },
        ];
    }

    get zoneOptions() {
        return [
            { label: 'H1', value: 'H1', iconCold: true, class: this.pillClass(this.zone === 'H1', 'cold') },
            { label: 'H2', value: 'H2', iconWarm: true, class: this.pillClass(this.zone === 'H2', 'warm') },
        ];
    }

    get travauxOptions() {
        return [
            { label: 'Chauffage seul', value: 'CH', iconFire: true, class: this.pillClass(this.travaux === 'CH', 'fire') },
            { label: 'Chauffage + ECS', value: 'CHECS', iconFireWater: true, class: this.pillClass(this.travaux === 'CHECS', 'fire-water') },
        ];
    }

    // ━━━ Couleurs sémantiques dynamiques ━━━
    get proprieteIconClass() {
        return 'label-icon label-icon--success';
    }

    get zoneIconClass() {
        if (this.zone === 'H1') return 'label-icon label-icon--cold';
        if (this.zone === 'H2') return 'label-icon label-icon--warm';
        return 'label-icon';
    }

    get travauxIconClass() {
        return 'label-icon label-icon--fire';
    }

    get surfIconClass() {
        return 'label-icon label-icon--fire';
    }

    get nbIconClass() {
        return 'label-icon label-icon--purple';
    }

    get tertIconClass() {
        return 'label-icon label-icon--indigo';
    }

    // Niveau de précarité — palette thermique : vert → jaune → orange → rouge
    get gpHeatLevel() {
        const v = this.gp || 0;
        if (v < 20) return 'low';
        if (v < 45) return 'mid';
        if (v < 70) return 'high';
        return 'very-high';
    }

    get gpIconClass() {
        return 'label-icon label-icon--gp-' + this.gpHeatLevel;
    }

    get sliderClass() {
        return 'slider slider--gp-' + this.gpHeatLevel;
    }

    get sliderValueClass() {
        return 'slider-value slider-value--gp-' + this.gpHeatLevel;
    }

    handleProprieteClick(event) {
        this.propriete = event.currentTarget.dataset.value;
        this.activeInfoId = null;
    }

    handleZoneClick(event) {
        this.zone = event.currentTarget.dataset.value;
        this.activeInfoId = null;
    }

    handleTravauxClick(event) {
        this.travaux = event.currentTarget.dataset.value;
        this.activeInfoId = null;
    }

    handleNumberInput(event) {
        const key = event.currentTarget.dataset.key;
        const raw = event.target.value;
        if (raw === '' || raw === null) {
            this[key] = null;
        } else {
            const v = parseFloat(raw);
            this[key] = Number.isFinite(v) ? v : null;
        }
    }

    handleGpInput(event) {
        this.gp = parseInt(event.target.value, 10);
    }

    get gpDisplay() { return this.gp + ' %'; }

    get fieldsClass() {
        return this.propriete === 'copro' ? 'fields fields--disabled' : 'fields';
    }

    getCoutInstallation(surface, withECS) {
        if (!Number.isFinite(surface) || surface < SURFACE_MIN || surface > SURFACE_MAX) return null;
        for (const [maxSurf, sansECS, avecECS] of COUTS_INSTALL) {
            if (surface <= maxSurf) return withECS ? avecECS : sansECS;
        }
        return null;
    }

    getSeuilBeneficeNet(surface) {
        for (const [maxSurf, seuil] of SEUILS_BENEF) {
            if (surface <= maxSurf) return seuil;
        }
        return SEUILS_BENEF[SEUILS_BENEF.length - 1][1];
    }

    getPrecoTier(surface) {
        if (!Number.isFinite(surface) || surface <= 0) return null;
        return PRECO_TIERS.find(t => surface <= t.max) || null;
    }

    computePrime(s) {
        const nbGP = Math.round(s.nb * s.gp / 100);
        const nbCL = s.nb - nbGP;
        const primeCL = BAREME[`${s.zone}_${s.travaux}_CL`];
        const primeGP = BAREME[`${s.zone}_${s.travaux}_GP`];
        const prime179 = nbGP * primeGP + nbCL * primeCL;
        const prime163 = (Number.isFinite(s.tert) && s.tert > 0) ? s.tert * TARIF_BAT163 : 0;
        const primeTotale = prime179 + prime163;
        const tauxCommission = COMMISSION_PAR_ZONE[s.zone] || 0;
        const commission = primeTotale * tauxCommission;
        return { primeTotale, commission, prime179, prime163, nbGP, nbCL, tauxCommission };
    }

    get computedResult() {
        const s = {
            propriete: this.propriete,
            zone: this.zone,
            travaux: this.travaux,
            nb: this.nb,
            surf: this.surf,
            gp: this.gp,
            tert: this.tert,
        };

        if (!s.zone) {
            return { status: 'incomplet', message: "Sélectionnez la zone climatique." };
        }
        if (!s.travaux) {
            return { status: 'incomplet', message: "Sélectionnez le type de travaux." };
        }
        if (!Number.isFinite(s.surf) || s.surf <= 0) {
            return { status: 'incomplet', message: "Renseignez la surface chauffée." };
        }
        if (!Number.isFinite(s.nb) || s.nb < 1) {
            return { status: 'incomplet', message: "Renseignez le nombre d'appartements." };
        }
        if (s.surf < SURFACE_MIN_ELIGIBLE) {
            return { status: 'non_eligible_taille', raison: 'surface' };
        }
        if (s.nb < NB_APPART_MIN_ELIGIBLE) {
            return { status: 'non_eligible_taille', raison: 'appartements' };
        }
        if (s.surf > SURFACE_MAX_CEF) {
            return { status: 'hors_perimetre' };
        }
        const cout = this.getCoutInstallation(s.surf, s.travaux === 'CHECS');
        if (cout === null) {
            return { status: 'devis' };
        }
        const r = this.computePrime(s);
        const beneficeNet = r.primeTotale - cout - r.commission;
        const r0 = this.computePrime({ ...s, gp: 0 });
        const beneficeNet0 = r0.primeTotale - cout - r0.commission;
        const seuil = this.getSeuilBeneficeNet(s.surf);
        if (beneficeNet < seuil) {
            return { status: 'non_eligible' };
        }
        if (beneficeNet0 < seuil) {
            return {
                status: 'sous_condition',
                commission: r.commission,
                primeTotale: r.primeTotale,
                prime163: r.prime163,
                tauxCommission: r.tauxCommission,
            };
        }
        return {
            status: 'eligible',
            commission: r.commission,
            primeTotale: r.primeTotale,
            prime163: r.prime163,
            tauxCommission: r.tauxCommission,
        };
    }

    get isCopro() { return this.computedResult.status === 'copro'; }
    get isIncomplet() { return this.computedResult.status === 'incomplet'; }
    get isNonEligibleTaille() { return this.computedResult.status === 'non_eligible_taille'; }
    get isHorsPerimetre() { return this.computedResult.status === 'hors_perimetre'; }
    get isDevis() { return this.computedResult.status === 'devis'; }
    get isNonEligible() { return this.computedResult.status === 'non_eligible'; }
    get isEligible() {
        const s = this.computedResult.status;
        return s === 'eligible' || s === 'sous_condition';
    }
    get isSousCondition() { return this.computedResult.status === 'sous_condition'; }

    get incompletMessage() { return this.computedResult.message; }
    get raisonSurface() { return this.computedResult.raison === 'surface'; }
    get raisonAppart() { return this.computedResult.raison === 'appartements'; }

    get commissionStr() { return fmtEuro(this.computedResult.commission || 0); }
    get primeTotaleStr() { return fmtEuro(this.computedResult.primeTotale || 0); }
    get prime163Str() { return fmtEuro(this.computedResult.prime163 || 0); }
    get hasPrime163() { return (this.computedResult.prime163 || 0) > 0; }
    get tauxCommissionPct() { return Math.round((this.computedResult.tauxCommission || 0) * 100); }

    get showStep2() {
        return !!(this.propriete && this.zone && this.travaux);
    }

    get showPreco() {
        if (this.propriete === 'copro') return false;
        const tier = this.getPrecoTier(this.surf);
        if (!tier
            || this.surf < SURFACE_MIN_ELIGIBLE
            || this.surf > SURFACE_MAX_CEF
            || !Number.isFinite(this.nb)
            || this.nb < NB_APPART_MIN_ELIGIBLE) return false;
        return true;
    }
    get precoTier() { return this.getPrecoTier(this.surf); }
    get precoRange() { return this.precoTier ? this.precoTier.range : ''; }
    get precoConfig() { return this.precoTier ? this.precoTier.config : ''; }
    get precoAlt() { return this.precoTier ? this.precoTier.alt : null; }
    get hasPrecoAlt() { return !!(this.precoTier && this.precoTier.alt); }
}