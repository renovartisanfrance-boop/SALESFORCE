import { LightningElement, api } from 'lwc';
import { FR, etiquettes } from 'c/lwc000_i18n';
import { saisieFiltre, SEUIL_MOBILE } from 'c/lwc020_FacturationUtils';

const PAGE_SIZES = [25, 50, 100, 200];

/**
 * Table de factures — composant PRÉSENTATIONNEL partagé par les deux onglets.
 *
 * Il n'appelle aucun Apex : le parent charge les données, les normalise via
 * lwc020_FacturationUtils.normaliserFacture, et les lui passe.
 *
 * Il porte toute la mécanique d'affichage : fusion `rowspan` des factures
 * couvrant plusieurs dossiers, colonnes figées, filtres, tri et pagination.
 *
 * Il expose un emplacement nommé « kpi » entre les filtres et le tableau : les
 * tuiles de synthèse appartiennent au parent (chaque onglet a les siennes) mais
 * doivent s'afficher APRÈS les filtres, et suivre les totaux filtrés que seul ce
 * composant connaît — d'où l'événement `totaux`.
 */
export default class Lwc020_FacturationTable extends LightningElement {
    // Langue d'affichage, poussee par le parent (voir c/lwc000_i18n).
    _langue = FR;
    @api
    get langue() {
        return this._langue;
    }
    set langue(valeur) {
        this._langue = valeur || FR;
    }

    get txt() {
        return etiquettes('facturation', this._langue);
    }


    _rows = [];
    /**
     * Factures déjà normalisées (voir normaliserFacture).
     *
     * Le setter incrémente une version plutôt que de comparer les contenus : elle
     * sert de clé de cache au filtrage/tri, opération qui serait sinon relancée une
     * dizaine de fois par rendu (hasData, groupes, totalRecords, totauxCourants…).
     */
    @api
    get rows() {
        return this._rows;
    }
    set rows(value) {
        this._rows = value || [];
        this._versionRows++;
        // La table n'est plus démontée au rechargement, donc currentPage survit à
        // l'arrivée d'un nouveau jeu. Si celui-ci compte moins de pages, la page
        // courante pointe au-delà de la fin : la tranche est vide, mais totalRecords
        // reste positif — le tableau afficherait ses en-têtes sans une seule ligne,
        // sans jamais montrer l'état vide, sous une pagination du type « 126-100 sur
        // 100 ». Contrairement aux filtres et au tri, on ne revient PAS à la page 1 :
        // après un simple « Actualiser », l'utilisateur doit retrouver sa place.
        if (this.currentPage > this.totalPages) this.currentPage = this.totalPages;
    }
    /** Liste ORDONNÉE et unique des colonnes (voir COLONNES_EN_COURS / COLONNES_PAYEES). */
    @api colonnes = [];
    /** La liste a été plafonnée côté serveur (les totaux du compte restent exacts). */
    @api tronque = false;
    @api messageTroncature = '';
    // Repli seulement : le parent passe en general un message deja traduit.
    @api messageVide = null;
    /** Unité comptée dans la barre de pagination. */
    @api unite = null;

    filters = {};
    isFilterOpen = false;

    sortField = null;
    sortDir = 'asc';

    currentPage = 1;
    pageSizeValue = '25';

    _signatureTotaux = null;
    _versionRows = 0;
    _cacheCle = null;
    _cacheFiltrees = null;

    // ───────────────────────────────────────────── Point d'arrêt

    estMobile = false;
    _mql = null;
    _surChangementMobile = null;

    /**
     * Le réordonnancement des colonnes ne peut pas se faire en CSS : dans un
     * <table>, l'ordre visuel EST l'ordre du DOM, et passer les cellules en flex ou
     * en grid détruirait le rowspan. Le point d'arrêt est donc écouté en JavaScript.
     *
     * matchMedia plutôt qu'un écouteur `resize` : le navigateur ne notifie qu'au
     * FRANCHISSEMENT du seuil, pas à chaque pixel de redimensionnement.
     */
    connectedCallback() {
        if (typeof window === 'undefined' || !window.matchMedia) return;

        this._mql = window.matchMedia(`(max-width: ${SEUIL_MOBILE - 1}px)`);
        this.estMobile = this._mql.matches;
        this._surChangementMobile = (e) => {
            this.estMobile = e.matches;
        };
        // addListener est déprécié, mais c'est la seule API disponible sur
        // Safari < 14, encore présent sur des iPhone en service.
        if (this._mql.addEventListener) {
            this._mql.addEventListener('change', this._surChangementMobile);
        } else if (this._mql.addListener) {
            this._mql.addListener(this._surChangementMobile);
        }
    }

    disconnectedCallback() {
        if (!this._mql || !this._surChangementMobile) return;
        if (this._mql.removeEventListener) {
            this._mql.removeEventListener('change', this._surChangementMobile);
        } else if (this._mql.removeListener) {
            this._mql.removeListener(this._surChangementMobile);
        }
    }

    /**
     * Colonnes telles qu'elles doivent être RENDUES au point d'arrêt courant.
     *
     * Sur téléphone : le nom du dossier passe en tête et devient la seule colonne
     * figée ; les autres gardent leur ordre relatif et perdent leur figement. Les
     * deux colonnes dégelées reçoivent une largeur explicite, qu'elles tiraient
     * jusque-là des variables du bloc gelé.
     *
     * L'entrelacement facture / dossier survit au réordonnancement : la grille passe
     * de F,F,D,D,F,F,D,D à D,F,F,D,F,F,D,D, et les cellules de dossier des lignes
     * suivantes remplissent alors les cases libres 1, 4, 7 et 8 — les cases 2, 3, 5
     * et 6 étant occupées par la descente du rowspan.
     */
    get colonnesEffectives() {
        const cols = this.colonnes || [];
        if (!this.estMobile) return cols;

        // `ancreMobile` désigne explicitement la colonne à remonter — c'est le cas
        // des configurations qui ne figent RIEN sur desktop. À défaut, on prend la
        // 3ᵉ colonne figée (le nom du dossier dans les deux onglets), puis la 1ʳᵉ.
        const ancre = cols.find((col) => col.ancreMobile) ||
                      cols.find((col) => col.sticky === 3) ||
                      cols.find((col) => col.sticky === 1);
        if (!ancre) return cols;

        const LARGEURS_DEGELEES = { 1: 104, 2: 96, 3: 150 };
        const reste = cols
            .filter((col) => col !== ancre)
            .map((col) =>
                col.sticky
                    ? { ...col, sticky: 0, largeur: col.largeur || LARGEURS_DEGELEES[col.sticky] }
                    : col
            );

        return [{ ...ancre, sticky: 1 }, ...reste];
    }

    /** Classes du bloc figé, posées au RENDU et non à la normalisation : le rang de
     *  figement dépend du point d'arrêt, la normalisation n'a lieu qu'au chargement. */
    _classeSticky(col) {
        return col.sticky ? ` sticky-col sticky-col--${col.sticky}` : '';
    }

    // ───────────────────────────────────────────── Filtres

    /** Ordre d'AFFICHAGE des champs de filtre : celui des colonnes au point d'arrêt
     *  courant, pour que le filtre se trouve là où l'utilisateur voit la donnée. */
    get colonnesFiltrables() {
        return this.colonnesEffectives.filter((col) => col.filtre === true);
    }

    /** Aucune colonne filtrable : tout le bloc disparaît, accordéon compris — un
     *  en-tête « Filtres de recherche » qui n'ouvre sur rien serait pire que rien. */
    get afficheFiltres() {
        return this.colonnesFiltrables.length > 0;
    }

    /** Un champ de saisie par colonne filtrable, dans l'ordre d'affichage des
     *  colonnes — l'utilisateur retrouve le filtre là où il voit la donnée. */
    get filterFields() {
        return this.colonnesFiltrables.map((col) => ({
            key: col.key,
            label: col.label,
            value: this.filters[col.key] || '',
            placeholder: col.label
        }));
    }

    handleToggleFilter() {
        this.isFilterOpen = !this.isFilterOpen;
    }

    handleFilterChange(event) {
        this.filters = { ...this.filters, [event.target.dataset.key]: event.target.value };
        this.currentPage = 1;
    }

    handleClearFilters(event) {
        event.stopPropagation();
        this.filters = {};
        this.currentPage = 1;
    }

    /**
     * Filtres réellement DISCRIMINANTS, une fois la saisie normalisée.
     *
     * Une saisie peut être non vide et sans effet — taper « € » dans un filtre de
     * montant ne laisse aucun chiffre après normalisation. La compter comme active
     * afficherait « 1 filtre actif » sur un tableau intact, et déclencherait le
     * rappel du total du compte dans les tuiles sans qu'aucun total ne soit réduit.
     */
    get filtresEffectifs() {
        return (this.colonnes || [])
            .filter((col) => Boolean(this.filters[col.key]))
            .map((col) => ({ col, attendu: saisieFiltre(this.filters[col.key], col) }))
            .filter((f) => f.attendu !== '');
    }

    get activeFilterCount() {
        return this.filtresEffectifs.length;
    }

    get hasActiveFilters() {
        return this.activeFilterCount > 0;
    }

    get filterCountLabel() {
        const n = this.activeFilterCount;
        return `${n} filtre${n > 1 ? 's' : ''} actif${n > 1 ? 's' : ''}`;
    }

    get accordionIcon() {
        return this.isFilterOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }

    // ───────────────────────────────────────────── Filtrage / tri

    /**
     * Une facture est retenue si elle satisfait tous les filtres portant sur des
     * colonnes de FACTURE ET si au moins une de ses lignes satisfait tous les
     * filtres portant sur des colonnes de DOSSIER. Dans ce cas SEULES les lignes
     * correspondantes sont affichées : filtrer « Nom = DUPONT » doit montrer la
     * ligne DUPONT, pas toutes les lignes de sa facture. Le rowspan s'ajuste au
     * nombre de lignes conservées.
     */
    get facturesFiltrees() {
        // Une dizaine de getters dépendent de ce résultat (hasData, groupes,
        // totalRecords, totauxCourants…) : sans cache, chaque frappe au clavier
        // relancerait autant de filtrages et de tris sur l'intégralité du jeu.
        const cle = JSON.stringify(this.filters) +
                    `|${this.sortField}|${this.sortDir}|${this._versionRows}`;
        if (cle === this._cacheCle) return this._cacheFiltrees;

        const actifs = this.filtresEffectifs;

        const filtresFacture = actifs.filter((f) => f.col.scope === 'F');
        const filtresDossier = actifs.filter((f) => f.col.scope === 'D');

        const correspond = (valeurs, f) => (valeurs[f.col.key] || '').includes(f.attendu);

        let out = (this.rows || []).filter((r) =>
            filtresFacture.every((f) => correspond(r.filterValues, f))
        );

        if (filtresDossier.length > 0) {
            out = out
                .map((r) => {
                    const lignes = r.lignes.filter((l) =>
                        filtresDossier.every((f) => correspond(l.filterValues, f))
                    );
                    if (lignes.length === 0) return null;
                    // Les valeurs de tri des colonnes de DOSSIER sont réalignées sur la
                    // nouvelle tête de bloc : si le filtre a retiré la ligne d'origine,
                    // trier sur elle ordonnerait le tableau d'après une valeur que
                    // l'utilisateur ne voit plus.
                    return { ...r, lignes, sortValues: { ...r.sortValues, ...lignes[0].sortValues } };
                })
                .filter(Boolean);
        }

        if (this.sortField) {
            const dir = this.sortDir === 'asc' ? 1 : -1;
            out = [...out].sort((a, b) => {
                const va = a.sortValues[this.sortField];
                const vb = b.sortValues[this.sortField];
                const aVide = va === '' || va === null || va === undefined;
                const bVide = vb === '' || vb === null || vb === undefined;
                if (aVide && !bVide) return 1;     // vides toujours en dernier
                if (!aVide && bVide) return -1;
                if (va < vb) return -1 * dir;
                if (va > vb) return 1 * dir;
                return 0;
            });
        }

        this._cacheCle = cle;
        this._cacheFiltrees = out;
        return out;
    }

    /**
     * En-têtes : une seule boucle sur la liste ordonnée. La classe porte le rang
     * de colonne figée, jamais une position — voir classeCellule.
     */
    get entetes() {
        return this.colonnesEffectives.map((col) => {
            const actif = this.sortField === col.key;
            const classes = ['th-sortable'];
            if (col.scope === 'D') classes.push('th-dossier');
            if (col.sticky) classes.push('sticky-col', `sticky-col--${col.sticky}`);
            return {
                key: col.key,
                label: col.label,
                cssClass: classes.join(' '),
                // Les colonnes FIGÉES tirent leur largeur du CSS (--w1/--w2/--w3),
                // d'où dérivent aussi leurs décalages `left` — une largeur en ligne
                // ici l'emporterait sur la réduction prévue en dessous de 480px.
                style: col.sticky ? '' : `width:${col.largeur || 110}px`,
                icon: actif
                    ? this.sortDir === 'asc'
                        ? 'utility:arrowup'
                        : 'utility:arrowdown'
                    : 'utility:sort',
                iconClass: actif ? 'sort-icon sort-icon--active' : 'sort-icon'
            };
        });
    }

    /**
     * Largeur minimale du tableau : somme des colonnes non figées, à laquelle
     * s'ajoutent les trois largeurs figées telles que le CSS les définit au
     * point d'arrêt courant. Sans ce minimum, `table-layout: fixed` écraserait
     * les colonnes non figées au lieu de déclencher le défilement horizontal.
     */
    get styleTable() {
        const cols = this.colonnesEffectives;
        const somme = cols
            .filter((col) => !col.sticky)
            .reduce((t, col) => t + (col.largeur || 110), 0);
        // Les largeurs figées sont référencées par leur variable, jamais recopiées
        // en dur : elles changent au point d'arrêt, et le minimum doit suivre.
        const gelees = cols
            .filter((col) => col.sticky)
            .sort((a, b) => a.sticky - b.sticky)
            .map((col) => `var(--w${col.sticky}) + `)
            .join('');
        return `min-width: calc(${gelees}${somme}px)`;
    }

    handleSort(event) {
        const cle = event.currentTarget.dataset.sortkey;
        if (!cle) return;
        if (this.sortField === cle) {
            this.sortDir = this.sortDir === 'asc' ? 'desc' : 'asc';
        } else {
            this.sortField = cle;
            this.sortDir = 'asc';
        }
        this.currentPage = 1;
    }

    // ───────────────────────────────────────────── Pagination

    get pageSize() {
        return parseInt(this.pageSizeValue, 10) || 25;
    }

    get pageSizeOptions() {
        return PAGE_SIZES.map((n) => ({
            label: `${n} / page`,
            value: String(n),
            selected: String(n) === this.pageSizeValue
        }));
    }

    handlePageSizeChange(event) {
        event.stopPropagation();
        this.pageSizeValue = event.target.value;
        this.currentPage = 1;
    }

    handlePagePrev() {
        if (this.currentPage > 1) this.currentPage--;
    }

    handlePageNext() {
        if (this.currentPage < this.totalPages) this.currentPage++;
    }

    get totalRecords() {
        return this.facturesFiltrees.length;
    }
    get totalPages() {
        return Math.max(1, Math.ceil(this.totalRecords / this.pageSize));
    }
    get startRecord() {
        return this.totalRecords === 0 ? 0 : (this.currentPage - 1) * this.pageSize + 1;
    }
    get endRecord() {
        return Math.min(this.currentPage * this.pageSize, this.totalRecords);
    }
    get pageInfo() {
        return `${this.currentPage} / ${this.totalPages}`;
    }
    get isPrevDisabled() {
        return this.currentPage <= 1;
    }
    get isNextDisabled() {
        return this.currentPage >= this.totalPages;
    }

    // ───────────────────────────────────────────── Lignes du tableau

    /**
     * Regroupe les factures de la page courante en <tbody>, un par facture.
     *
     * Un tbody par groupe permet au survol de repeindre TOUT le bloc — cellules
     * fusionnées comprises — avec « tbody:hover td », sans JavaScript. Avec un
     * survol par <tr>, survoler la 3e ligne d'une facture laisserait les cellules
     * figées de gauche non surlignées, puisqu'elles appartiennent au premier <tr>.
     *
     * La pagination porte sur les FACTURES, pas sur les lignes : paginer les lignes
     * couperait une facture en deux entre deux pages et casserait le rowspan.
     *
     * Une facture sans aucune ligne produit malgré tout UNE ligne (cellules dossier
     * vides) — sinon elle disparaîtrait du tableau.
     */
    get groupes() {
        const debut = (this.currentPage - 1) * this.pageSize;
        const page = this.facturesFiltrees.slice(debut, debut + this.pageSize);
        const colonnes = this.colonnesEffectives;

        return page.map((r) => {
            const nb = Math.max(1, r.lignes.length);
            const rows = [];

            for (let i = 0; i < nb; i++) {
                const ligne = r.lignes[i];
                const cells = [];

                colonnes.forEach((col) => {
                    // Les classes du bloc figé sont ajoutées ICI et non à la
                    // normalisation : le rang de figement dépend du point d'arrêt.
                    const sticky = this._classeSticky(col);

                    if (col.scope === 'F') {
                        // Émises UNIQUEMENT sur la première ligne : sur les suivantes,
                        // ces colonnes sont déjà occupées par la descente du rowspan.
                        if (i !== 0) return;
                        const c = r.cellulesFacture[col.key];
                        if (c) cells.push({ ...c, cssClass: c.cssClass + sticky, rowspan: nb });
                    } else {
                        const c = ligne && ligne.parCle[col.key];
                        cells.push(
                            c
                                ? { ...c, cssClass: c.cssClass + sticky }
                                : {
                                      key: `${r.id}-l${i}-${col.key}`,
                                      value: '',
                                      cssClass: 'cell-text' + sticky,
                                      rowspan: 1
                                  }
                        );
                    }
                });

                rows.push({
                    key: `${r.id}#${i}`,
                    rowClass: i === 0 ? 'row-first' : 'row-suite',
                    cells
                });
            }

            let classe = 'groupe';
            if (r.aFacturer) classe += ' groupe-afacturer';
            if (r.ligneSupp) classe += ' groupe-supp';
            return { key: r.id, groupClass: classe, rows };
        });
    }

    get hasData() {
        return this.totalRecords > 0;
    }

    get showEmpty() {
        return this.totalRecords === 0;
    }

    get texteVide() {
        return (this.rows || []).length === 0
            ? (this.messageVide || this.txt.messageVide)
            : this.txt.aucuneLigneFiltre;
    }

    // ───────────────────────────────────────────── Totaux dynamiques

    /**
     * Totaux du jeu FILTRÉ (pas de la page courante : l'utilisateur attend le total
     * de ce qu'il a filtré, pas des 25 lignes qu'il a sous les yeux).
     *
     * Les deux origines sont comptées séparément : une ligne du catalogue porte un
     * montant HT et pas de facture, une facture porte son TTC.
     */
    get totauxCourants() {
        let nbFactures = 0;
        let sommeFactures = 0;
        let nbAFacturer = 0;
        let sommeAFacturer = 0;

        this.facturesFiltrees.forEach((r) => {
            if (r.aFacturer) {
                nbAFacturer++;
                sommeAFacturer += r.montant;
            } else {
                nbFactures++;
                sommeFactures += r.montant;
            }
        });

        // Les tuiles n'affichent le rappel du total du compte que lorsqu'un filtre
        // restreint réellement l'affichage : sans filtre, le grand chiffre EST déjà
        // le total, et le répéter en dessous n'apprendrait rien.
        return {
            nbFactures,
            sommeFactures,
            nbAFacturer,
            sommeAFacturer,
            filtreActif: this.activeFilterCount > 0
        };
    }

    /**
     * Publie les totaux après rendu, et seulement s'ils ont changé : un dispatch à
     * chaque rendu ferait remonter une valeur identique au parent, qui se re-rendrait
     * et redéclencherait un rendu ici — boucle infinie.
     *
     * `filtreActif` fait partie de la signature : poser un filtre qui laisse passer
     * toutes les lignes ne change aucun total, mais doit tout de même faire
     * apparaître le rappel dans les tuiles.
     */
    renderedCallback() {
        const t = this.totauxCourants;
        const signature = `${t.nbFactures}|${t.sommeFactures}|${t.nbAFacturer}` +
                          `|${t.sommeAFacturer}|${t.filtreActif}`;
        if (signature === this._signatureTotaux) return;
        this._signatureTotaux = signature;
        this.dispatchEvent(new CustomEvent('totaux', { detail: t }));
    }
}