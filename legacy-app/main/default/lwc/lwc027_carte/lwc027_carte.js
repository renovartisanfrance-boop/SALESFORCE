import { LightningElement, api, track } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import LEAFLET from '@salesforce/resourceUrl/leaflet';
import {
    FOND_CARTE,
    VUE_DEFAUT,
    ZOOM_AJUSTEMENT_MAX,
    COULEURS,
    GEOCODAGE_DELAI_MS,
    geocoder,
    itineraire,
    lienNavigation
} from './carteConfig';
import { libelles } from './carteLibelles';

/**
 * lwc027_carte — carte Leaflet AUTONOME et générique.
 *
 * Le composant ne connaît ni Salesforce ni les dossiers : il reçoit des points,
 * les place (en localisant l'adresse quand les coordonnées manquent), affiche la
 * position de l'utilisateur si elle est autorisée, et trace l'itinéraire vers le
 * point choisi. Fournisseurs (tuiles, géocodage, itinéraire) : carteConfig.js.
 *
 * ENTRÉES
 *   points  [{ id, titre, adresse, sousTitre?, lat?, lng?, couleur? }]
 *           couleur = clé de COULEURS (defaut, alerte, attente, info, gris).
 *   langue  'es' (défaut) | 'fr'
 *   actionLibelle  libellé d'un bouton supplémentaire dans la bulle d'un
 *                  point ; son clic émet `action`. Vide = pas de bouton.
 *   hauteur        hauteur CSS de la carte (défaut 480px).
 *
 * ÉVÉNEMENTS
 *   selection  { id }  un point a été ouvert
 *   action     { id }  le bouton `actionLibelle` a été cliqué
 *
 * ÉVOLUTIONS PRÉVUES — ajouter une entrée plutôt que modifier l'existant :
 * nouveaux types de points (couleur), nouveaux boutons de bulle, autre
 * fournisseur dans carteConfig.js.
 */

/** Coordonnées déjà trouvées, partagées entre les ouvertures de la carte. */
const CACHE_GEOCODAGE = new Map();
const CLE_STOCKAGE = 'lwc027_carte_geocodage';

function lireCacheSession() {
    try {
        const brut = sessionStorage.getItem(CLE_STOCKAGE);
        if (brut) {
            Object.entries(JSON.parse(brut)).forEach(([k, v]) => CACHE_GEOCODAGE.set(k, v));
        }
    } catch (e) {
        // Stockage indisponible : le cache reste en mémoire seulement.
    }
}

function ecrireCacheSession() {
    try {
        sessionStorage.setItem(CLE_STOCKAGE, JSON.stringify(Object.fromEntries(CACHE_GEOCODAGE)));
    } catch (e) {
        // idem
    }
}

const attendre = (ms) => new Promise((ok) => {
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    setTimeout(ok, ms);
});

const coordValides = (p) => p && Number.isFinite(Number(p.lat)) && Number.isFinite(Number(p.lng))
    && p.lat !== null && p.lng !== null && p.lat !== '' && p.lng !== '';

export default class Lwc027Carte extends LightningElement {
    @api langue;
    @api actionLibelle;
    @api hauteur = '480px';

    @track chargement = true;
    @track erreur = false;
    @track progression = null;
    @track nonLocalises = [];
    @track messagePosition = null;
    @track trajet = null;
    @track calculEnCours = false;
    @track messageTrajet = null;

    _points = [];
    carte = null;
    L = null;
    coucheReperes = null;
    coucheTrajet = null;
    repereMoi = null;
    maPosition = null;
    lancement = 0;
    initialise = false;
    positionsParId = new Map();

    @api
    get points() {
        return this._points;
    }
    set points(valeur) {
        this._points = Array.isArray(valeur) ? valeur : [];
        if (this.carte) {
            this.placerPoints();
        }
    }

    get txt() {
        return libelles(this.langue);
    }

    get styleCarte() {
        return `height: ${this.hauteur || '480px'};`;
    }

    get aDesNonLocalises() {
        return this.nonLocalises.length > 0;
    }

    /* ══════════════════════ Cycle de vie ══════════════════════ */

    renderedCallback() {
        if (this.initialise) return;
        this.initialise = true;
        this.demarrer();
    }

    disconnectedCallback() {
        this.lancement++;
        if (this.carte) {
            this.carte.remove();
            this.carte = null;
        }
    }

    async demarrer() {
        try {
            await loadScript(this, LEAFLET);
            // eslint-disable-next-line no-undef
            this.L = window.L;
            lireCacheSession();
            this.creerCarte();
            this.chargement = false;
            // Points d abord : la demande de position peut attendre la reponse
            // de l utilisateur, la carte ne doit pas rester vide en attendant.
            this.placerPoints();
            this.localiserUtilisateur();
        } catch (e) {
            console.error('Carte Leaflet indisponible :', e);
            this.chargement = false;
            this.erreur = true;
        }
    }

    creerCarte() {
        const L = this.L;
        const conteneur = this.template.querySelector('.carte');
        this.carte = L.map(conteneur, { zoomControl: true, attributionControl: true })
            .setView([VUE_DEFAUT.lat, VUE_DEFAUT.lng], VUE_DEFAUT.zoom);
        L.tileLayer(FOND_CARTE.url, {
            maxZoom: FOND_CARTE.zoomMax,
            attribution: FOND_CARTE.attribution
        }).addTo(this.carte);
        this.coucheTrajet = L.layerGroup().addTo(this.carte);
        this.coucheReperes = L.layerGroup().addTo(this.carte);
        // Le conteneur peut avoir été mesuré avant son affichage définitif.
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => this.carte && this.carte.invalidateSize(), 200);
    }

    /* ══════════════════════ Position de l'utilisateur ══════════════════════ */

    localiserUtilisateur() {
        if (!navigator.geolocation) {
            this.messagePosition = this.txt.positionRefusee;
            return;
        }
        navigator.geolocation.getCurrentPosition(
            (pos) => {
                this.maPosition = { lat: pos.coords.latitude, lng: pos.coords.longitude };
                this.messagePosition = null;
                try {
                    this.afficherMaPosition();
                    this.ajuster();
                } catch (e) {
                    // Affichage de la position impossible : la carte reste utilisable.
                    console.error('Position non affichee :', e);
                }
            },
            () => {
                this.maPosition = null;
                this.messagePosition = this.txt.positionRefusee;
            },
            { enableHighAccuracy: true, timeout: 10000, maximumAge: 60000 }
        );
    }

    afficherMaPosition() {
        if (!this.carte || !this.maPosition) return;
        const L = this.L;
        if (this.repereMoi) this.repereMoi.remove();
        this.repereMoi = L.circleMarker([this.maPosition.lat, this.maPosition.lng], {
            radius: 9, color: '#fff', weight: 3, fillColor: COULEURS.moi, fillOpacity: 1
        }).addTo(this.carte).bindTooltip(this.txt.maPosition, { direction: 'top' });
    }

    /* ══════════════════════ Points ══════════════════════ */

    /**
     * Place les points. Un nouvel appel (liste changée) ANNULE le précédent :
     * sans ce jeton, une localisation lente ajouterait des repères d'une
     * ancienne liste.
     */
    async placerPoints() {
        const jeton = ++this.lancement;
        this.coucheReperes.clearLayers();
        this.effacerTrajet();
        this.positionsParId = new Map();
        this.nonLocalises = [];

        const aChercher = [];
        this._points.forEach((p) => {
            if (coordValides(p)) {
                this.ajouterRepere(p, { lat: Number(p.lat), lng: Number(p.lng) });
            } else if (p.adresse && CACHE_GEOCODAGE.has(p.adresse)) {
                const c = CACHE_GEOCODAGE.get(p.adresse);
                if (c) this.ajouterRepere(p, c);
                else this.nonLocalises = [...this.nonLocalises, p];
            } else {
                aChercher.push(p);
            }
        });
        this.ajuster();

        for (let i = 0; i < aChercher.length; i++) {
            if (jeton !== this.lancement) return;
            this.progression = this.txt.localisation
                .replace('{n}', i + 1).replace('{total}', aChercher.length);
            const p = aChercher[i];
            let c = null;
            try {
                // eslint-disable-next-line no-await-in-loop
                c = await geocoder(p.adresse);
            } catch (e) {
                c = null;
            }
            if (jeton !== this.lancement) return;
            if (p.adresse) {
                CACHE_GEOCODAGE.set(p.adresse, c);
            }
            if (c) {
                this.ajouterRepere(p, c);
                this.ajuster();
            } else {
                this.nonLocalises = [...this.nonLocalises, p];
            }
            if (i < aChercher.length - 1) {
                // eslint-disable-next-line no-await-in-loop
                await attendre(GEOCODAGE_DELAI_MS);
            }
        }
        if (jeton === this.lancement) {
            this.progression = null;
            ecrireCacheSession();
        }
    }

    ajouterRepere(point, coord) {
        const L = this.L;
        const couleur = COULEURS[point.couleur] || COULEURS.defaut;
        const icone = L.divIcon({
            className: 'repere',
            html: `<span class="repere-epingle" style="background:${couleur}"></span>`,
            iconSize: [26, 26],
            iconAnchor: [13, 26],
            popupAnchor: [0, -24],
            tooltipAnchor: [0, -22]
        });
        const repere = L.marker([coord.lat, coord.lng], { icon: icone, title: point.titre || '' });
        // Nom du dossier affiché en permanence sur le repère.
        repere.bindTooltip(point.titre || '', {
            permanent: true, direction: 'top', className: 'repere-nom', opacity: 1
        });
        repere.bindPopup(() => this.contenuBulle(point, coord), { minWidth: 200 });
        repere.on('popupopen', () => {
            this.dispatchEvent(new CustomEvent('selection', { detail: { id: point.id } }));
        });
        repere.addTo(this.coucheReperes);
        this.positionsParId.set(point.id, coord);
    }

    /** Bulle construite en DOM (textContent) : aucune donnée injectée en HTML. */
    contenuBulle(point, coord) {
        const L = this.L;
        const bloc = L.DomUtil.create('div', 'bulle');
        const titre = L.DomUtil.create('div', 'bulle-titre', bloc);
        titre.textContent = point.titre || '';
        if (point.sousTitre) {
            L.DomUtil.create('div', 'bulle-sous', bloc).textContent = point.sousTitre;
        }
        if (point.adresse) {
            L.DomUtil.create('div', 'bulle-adresse', bloc).textContent = point.adresse;
        }

        const actions = L.DomUtil.create('div', 'bulle-actions', bloc);
        const btnTrajet = L.DomUtil.create('button', 'bulle-btn bulle-btn-principal', actions);
        btnTrajet.type = 'button';
        btnTrajet.textContent = this.txt.boutonItineraire;
        if (!this.maPosition) {
            btnTrajet.disabled = true;
            btnTrajet.title = this.txt.positionInactive;
        }
        L.DomEvent.on(btnTrajet, 'click', (ev) => {
            L.DomEvent.stop(ev);
            this.tracerTrajet(point, coord);
        });

        const lien = L.DomUtil.create('a', 'bulle-btn', actions);
        lien.href = lienNavigation(this.maPosition, coord);
        lien.target = '_blank';
        lien.rel = 'noopener noreferrer';
        lien.textContent = this.txt.boutonGps;

        if (this.actionLibelle) {
            const btnAction = L.DomUtil.create('button', 'bulle-btn', actions);
            btnAction.type = 'button';
            btnAction.textContent = this.actionLibelle;
            L.DomEvent.on(btnAction, 'click', (ev) => {
                L.DomEvent.stop(ev);
                this.dispatchEvent(new CustomEvent('action', { detail: { id: point.id } }));
            });
        }
        if (!this.maPosition) {
            L.DomUtil.create('div', 'bulle-note', bloc).textContent = this.txt.positionInactive;
        }
        L.DomEvent.disableClickPropagation(bloc);
        return bloc;
    }

    /** Cadre la carte sur tous les repères (et ma position si connue). */
    ajuster() {
        if (!this.carte) return;
        const coords = [...this.positionsParId.values()].map((c) => [c.lat, c.lng]);
        if (this.maPosition) coords.push([this.maPosition.lat, this.maPosition.lng]);
        if (!coords.length) return;
        if (coords.length === 1) {
            this.carte.setView(coords[0], ZOOM_AJUSTEMENT_MAX);
            return;
        }
        this.carte.fitBounds(this.L.latLngBounds(coords), { padding: [40, 40], maxZoom: ZOOM_AJUSTEMENT_MAX });
    }

    handleRecentrer() {
        this.ajuster();
    }

    /* ══════════════════════ Itinéraire ══════════════════════ */

    async tracerTrajet(point, coord) {
        if (!this.maPosition) {
            this.messageTrajet = this.txt.positionInactive;
            return;
        }
        this.carte.closePopup();
        this.effacerTrajet();
        this.calculEnCours = true;
        this.messageTrajet = this.txt.calcul;
        try {
            const res = await itineraire(this.maPosition, coord);
            if (!res) throw new Error('aucun itineraire');
            const ligne = this.L.polyline(res.coordonnees, { color: COULEURS.moi, weight: 5, opacity: 0.85 })
                .addTo(this.coucheTrajet);
            this.carte.fitBounds(ligne.getBounds(), { padding: [40, 40] });
            this.trajet = {
                titre: this.txt.itineraireVers.replace('{titre}', point.titre || ''),
                distance: `${(res.distanceM / 1000).toFixed(1)} km`,
                duree: this.formatDuree(res.dureeS),
                lien: lienNavigation(this.maPosition, coord)
            };
            this.messageTrajet = null;
        } catch (e) {
            console.error('Itineraire indisponible :', e);
            this.messageTrajet = this.txt.itineraireKo;
        } finally {
            this.calculEnCours = false;
        }
    }

    effacerTrajet() {
        if (this.coucheTrajet) this.coucheTrajet.clearLayers();
        this.trajet = null;
        this.messageTrajet = null;
    }

    handleEffacerTrajet() {
        this.effacerTrajet();
        this.ajuster();
    }

    formatDuree(secondes) {
        const min = Math.round(secondes / 60);
        if (min < 60) return `${min} ${this.txt.min}`;
        return `${Math.floor(min / 60)} ${this.txt.h} ${String(min % 60).padStart(2, '0')}`;
    }
}