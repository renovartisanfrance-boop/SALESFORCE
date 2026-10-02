import { LightningElement, api } from 'lwc';
import rechercherAdresse from '@salesforce/apex/AdresseGouvController.rechercherAdresse';

/**
 * Autocomplétion d'adresse française (Base Adresse Nationale, api-adresse.data.gouv.fr)
 * via le proxy Apex AdresseGouvController.
 *
 * L'utilisateur tape, choisit une suggestion, et le composant émet « select » avec
 * l'adresse déjà découpée :
 *   { id, label, street, postalCode, city, country, latitude, longitude, typeAdresse }
 * Le parent est responsable d'écrire ces valeurs dans ses champs.
 *
 * Le mécanisme d'ouverture/fermeture de la liste (blur différé + mousedown avec
 * preventDefault) reprend celui de lwc022SearchableCombobox, qui est éprouvé.
 *
 * TROIS PRÉSENTATIONS sont proposées via l'attribut `variante`, le temps de choisir :
 *   'aligne'  — libellé à gauche / saisie à droite, comme un champ normal du formulaire
 *   'bandeau' — barre pleine largeur à fond bleu pâle, distincte des champs de données
 *   'loupe'   — bouton discret qui ouvre la recherche en surimpression
 * Une fois la variante retenue, supprimer les deux autres blocs du .html, leur getter
 * ci-dessous et les règles CSS correspondantes.
 */

const DEBOUNCE_MS = 300; // délai de frappe avant appel Apex (cf. ionosUsersAdmin)
const MIN_CHARS = 3; // minimum imposé par l'API BAN
const BLUR_MS = 150; // délai de fermeture (cf. lwc022SearchableCombobox)

export default class AdresseAutocomplete extends LightningElement {
    @api label = 'Rechercher une adresse';
    @api placeholder = 'Ex : 8 boulevard du Port, Amiens';
    @api disabled = false;
    @api variante = 'bandeau'; // 'aligne' | 'bandeau' | 'loupe'

    query = '';
    suggestions = [];
    open = false;
    isLoading = false;
    errorMessage = '';
    popoverOuvert = false; // variante « loupe » uniquement

    _debounceTimer;
    _blurTimer;
    _seq = 0; // garde anti-réponse obsolète
    _activeIndex = -1;
    _focusApresRendu = false;

    disconnectedCallback() {
        window.clearTimeout(this._debounceTimer);
        window.clearTimeout(this._blurTimer);
    }

    // Variante « loupe » : la surimpression vient d'être ouverte → on donne le focus
    // à la saisie pour que l'utilisateur puisse taper sans clic supplémentaire.
    renderedCallback() {
        if (!this._focusApresRendu) return;
        this._focusApresRendu = false;
        const input = this.template.querySelector('.aa-input');
        if (input) input.focus();
    }

    get isAligne() {
        return this.variante === 'aligne';
    }

    get isBandeau() {
        return this.variante === 'bandeau';
    }

    get options() {
        return this.suggestions.map((suggestion, index) => ({
            // L'id BAN peut manquer sur certains types : on le complète par l'index.
            key: (suggestion.id || 'x') + '#' + index,
            index: String(index),
            label: suggestion.label,
            sub: [suggestion.postalCode, suggestion.city].filter(Boolean).join(' '),
            cls: index === this._activeIndex ? 'aa-option aa-option--active' : 'aa-option'
        }));
    }

    get dropdownClass() {
        return this.open ? 'aa-dropdown aa-open' : 'aa-dropdown';
    }

    get showNoResults() {
        return (
            this.open &&
            !this.isLoading &&
            this.suggestions.length === 0 &&
            this.query.trim().length >= MIN_CHARS
        );
    }

    handleInput(event) {
        this.query = event.target.value;
        this.errorMessage = '';
        window.clearTimeout(this._debounceTimer);

        if (this.query.trim().length < MIN_CHARS) {
            // On invalide les appels en vol : leurs résultats ne doivent plus s'afficher.
            this._seq++;
            this.suggestions = [];
            this.open = false;
            this.isLoading = false;
            return;
        }

        this.open = true;
        this.isLoading = true;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._debounceTimer = window.setTimeout(() => this.search(), DEBOUNCE_MS);
    }

    search() {
        const seq = ++this._seq;
        rechercherAdresse({ query: this.query.trim() })
            .then((resultats) => {
                if (seq !== this._seq) return; // réponse obsolète → ignorée
                this.suggestions = resultats || [];
                this._activeIndex = -1;
                this.open = true;
                this.isLoading = false;
            })
            .catch((error) => {
                if (seq !== this._seq) return;
                this.suggestions = [];
                this.isLoading = false;
                this.errorMessage =
                    error?.body?.message || 'Recherche d\'adresse momentanément indisponible.';
                console.error('[adresseAutocomplete] échec de la recherche', error);
            });
    }

    handleFocus() {
        if (this.disabled) return;
        if (this.suggestions.length) this.open = true;
    }

    handleBlur() {
        // Délai pour laisser le mousedown sur une option s'exécuter avant la fermeture.
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._blurTimer = window.setTimeout(() => {
            this.open = false;
            this._activeIndex = -1;
            // Variante « loupe » : quitter la saisie referme aussi la surimpression.
            this.popoverOuvert = false;
        }, BLUR_MS);
    }

    // Variante « loupe » : ouvre/ferme la recherche en surimpression.
    handleTriggerClick() {
        this.popoverOuvert = !this.popoverOuvert;
        if (this.popoverOuvert) {
            this._focusApresRendu = true;
        } else {
            this.reinitialiser();
        }
    }

    reinitialiser() {
        window.clearTimeout(this._debounceTimer);
        window.clearTimeout(this._blurTimer);
        this._seq++;
        this.query = '';
        this.suggestions = [];
        this.open = false;
        this.isLoading = false;
        this.errorMessage = '';
        this._activeIndex = -1;
    }

    // Sélection via mousedown + preventDefault : l'input GARDE le focus, ce qui évite
    // que le blur ne referme la liste avant que le clic n'ait été traité.
    handleOptionMouseDown(event) {
        event.preventDefault();
        this.select(Number(event.currentTarget.dataset.index));
    }

    handleKeyDown(event) {
        if (event.key === 'ArrowDown') {
            event.preventDefault();
            this._activeIndex = Math.min(this._activeIndex + 1, this.suggestions.length - 1);
        } else if (event.key === 'ArrowUp') {
            event.preventDefault();
            this._activeIndex = Math.max(this._activeIndex - 1, 0);
        } else if (event.key === 'Enter') {
            // Le composant vit dans un lightning-record-edit-form : sans ces deux
            // appels, Entrée enregistrerait la fiche au lieu de choisir l'adresse.
            event.preventDefault();
            event.stopPropagation();
            const index = this._activeIndex >= 0 ? this._activeIndex : 0;
            if (this.suggestions[index]) this.select(index);
        } else if (event.key === 'Escape') {
            this.open = false;
            this._activeIndex = -1;
        }
    }

    select(index) {
        const suggestion = this.suggestions[index];
        if (!suggestion) return;

        window.clearTimeout(this._blurTimer);
        window.clearTimeout(this._debounceTimer);
        this._seq++; // aucune réponse en vol ne doit rouvrir la liste

        this.query = suggestion.label;
        this.open = false;
        this.isLoading = false;
        this._activeIndex = -1;
        this.popoverOuvert = false; // variante « loupe » : on referme après le choix

        this.dispatchEvent(
            new CustomEvent('select', {
                detail: {
                    id: suggestion.id,
                    label: suggestion.label,
                    street: suggestion.street,
                    postalCode: suggestion.postalCode,
                    city: suggestion.city,
                    country: suggestion.country,
                    latitude: suggestion.latitude,
                    longitude: suggestion.longitude,
                    typeAdresse: suggestion.typeAdresse
                }
            })
        );
    }
}