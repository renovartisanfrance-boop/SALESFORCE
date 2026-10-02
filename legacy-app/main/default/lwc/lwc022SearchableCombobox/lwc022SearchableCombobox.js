import { LightningElement, api } from 'lwc';

/**
 * Combobox avec recherche (type-ahead) — remplaçant filtrable de
 * lightning-combobox. Utile pour les listes longues (champs du dossier,
 * picklists). API proche de lightning-combobox :
 *   <c-lwc022-searchable-combobox label value options variant onchange>
 * Émet « change » avec { detail: { value } } et expose la propriété `value`,
 * pour rester compatible avec les handlers existants (event.target.value /
 * event.detail.value).
 *
 * resetonselect=true : agit comme un bouton d'action (se vide après sélection),
 * utilisé pour « Insérer un champ » dans l'éditeur de formule.
 *
 * keepopenonselect=true : la liste RESTE ouverte après une sélection, pour
 * enchaîner les ajouts sans re-cliquer (multi-valeurs : « + Ajouter une valeur »).
 */
export default class Lwc022SearchableCombobox extends LightningElement {
    @api label;
    @api placeholder = 'Sélectionner…';
    @api variant; // 'label-hidden' supporté
    @api disabled = false;
    @api required = false;
    @api resetonselect = false;
    @api keepopenonselect = false;

    @api
    get value() {
        return this._value;
    }
    set value(v) {
        this._value = v == null ? '' : v;
        if (!this._editing) {
            this._query = this.labelForValue(this._value);
        }
    }

    @api
    get options() {
        return this._options;
    }
    set options(v) {
        this._options = Array.isArray(v) ? v : [];
        if (!this._editing) {
            this._query = this.labelForValue(this._value);
        }
    }

    _value = '';
    _options = [];
    _query = '';
    _editing = false;
    open = false;
    _blurTimer;
    _refocus = false;

    disconnectedCallback() {
        if (this._blurTimer) {
            clearTimeout(this._blurTimer);
            this._blurTimer = undefined;
        }
    }

    // Après une sélection en mode « liste ouverte », on redonne le focus à l'input
    // pour que la frappe/le choix suivant enchaîne sans clic supplémentaire.
    renderedCallback() {
        if (!this._refocus) return;
        this._refocus = false;
        const input = this.template.querySelector('.pf-sc-input');
        if (input) input.focus();
    }

    get isLabelHidden() {
        return this.variant === 'label-hidden';
    }

    get showLabel() {
        return this.label && !this.isLabelHidden;
    }

    get displayValue() {
        return this._editing ? this._query : this.labelForValue(this._value);
    }

    // Classe de l'input : réserve la place de la croix d'effacement si visible.
    get inputClass() {
        return this.showClear ? 'pf-sc-input pf-sc-has-clear' : 'pf-sc-input';
    }

    // Croix d'effacement : visible quand une valeur est posée sur un champ
    // facultatif et éditable (pas sur les champs requis ni « bouton d'action »).
    get showClear() {
        return (
            !this.required &&
            !this.disabled &&
            !this.resetonselect &&
            this._value !== '' &&
            this._value !== null &&
            this._value !== undefined
        );
    }

    labelForValue(val) {
        if (val === '' || val === null || val === undefined) return '';
        const opt = this._options.find((o) => String(o.value) === String(val));
        return opt ? opt.label : val;
    }

    get filteredOptions() {
        const q = (this._query || '').toLowerCase().trim();
        const list =
            this._editing && q
                ? this._options.filter(
                      (o) =>
                          o.label.toLowerCase().includes(q) ||
                          String(o.value).toLowerCase().includes(q)
                  )
                : this._options;
        return list.map((o) => ({
            label: o.label,
            value: o.value,
            cls: o.value === this._value ? 'pf-sc-option pf-sc-option-selected' : 'pf-sc-option'
        }));
    }

    // État vide affiché dès que la liste ouverte n'a rien à proposer — y compris
    // sans recherche (multi-sélection : toutes les valeurs ont été ajoutées).
    get noResults() {
        return this.open && this.filteredOptions.length === 0;
    }

    get emptyMessage() {
        return this._query ? 'Aucun résultat' : 'Aucune option disponible';
    }

    get dropdownClass() {
        return this.open ? 'pf-sc-dropdown pf-sc-open' : 'pf-sc-dropdown';
    }

    handleFocus() {
        if (this.disabled) return;
        this._editing = true;
        this._query = '';
        this.open = true;
    }

    // Une option est choisie via mousedown + preventDefault : l'input GARDE le focus.
    // Un nouveau clic ne déclenche donc AUCUN événement `focus` — sans ce handler, il
    // faudrait sortir du champ puis y revenir pour rouvrir la liste.
    handleClick() {
        if (this.disabled || this.open) return;
        this._editing = true;
        this._query = '';
        this.open = true;
    }

    handleInput(event) {
        this._query = event.target.value;
        this._editing = true;
        this.open = true;
    }

    handleBlur() {
        // Délai pour laisser le mousedown sur une option s'exécuter avant la fermeture.
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._blurTimer = setTimeout(() => {
            this.open = false;
            this._editing = false;
            this._query = this.labelForValue(this._value);
        }, 150);
    }

    handleKeyDown(event) {
        if (event.key === 'Enter') {
            event.preventDefault();
            const first = this.filteredOptions[0];
            if (first) this.selectValue(first.value);
        } else if (event.key === 'Escape') {
            this.open = false;
            this._editing = false;
            this._query = this.labelForValue(this._value);
        } else if (
            (event.key === 'Backspace' || event.key === 'Delete') &&
            this.showClear &&
            !this._query
        ) {
            // Effacement au clavier : Retour arrière / Suppr sur une saisie vide
            // vide la sélection (équivalent clavier de la croix ×).
            event.preventDefault();
            this.clearSelection();
        }
    }

    handleOptionMouseDown(event) {
        event.preventDefault(); // empêche le blur de l'input avant la sélection
        this.selectValue(event.currentTarget.dataset.value);
    }

    // Croix d'effacement : remet la sélection à vide et notifie le parent.
    // mousedown + preventDefault pour agir avant le blur de l'input.
    handleClearMouseDown(event) {
        event.preventDefault();
        event.stopPropagation();
        this.clearSelection();
    }

    clearSelection() {
        if (this._blurTimer) {
            clearTimeout(this._blurTimer);
        }
        this.open = false;
        this._editing = false;
        this._value = '';
        this._query = '';
        this.dispatchEvent(new CustomEvent('change', { detail: { value: '' } }));
    }

    selectValue(val) {
        if (this._blurTimer) {
            clearTimeout(this._blurTimer);
            this._blurTimer = undefined;
        }
        if (this.resetonselect) {
            this._value = '';
            this._query = '';
        } else {
            this._value = val;
            this._query = this.labelForValue(val);
        }

        if (this.keepopenonselect) {
            // Multi-sélection : on garde la liste OUVERTE et on repart d'une recherche
            // vide, pour enchaîner les ajouts. Le parent retire la valeur choisie des
            // options -> la liste se rafraîchit avec les valeurs restantes.
            this._editing = true;
            this._query = '';
            this.open = true;
            this._refocus = true;
        } else {
            this.open = false;
            this._editing = false;
        }

        this.dispatchEvent(new CustomEvent('change', { detail: { value: val } }));
    }
}