/**
 * carteConfig — TOUTE la configuration de lwc027_carte.
 *
 * Le composant ne connaît aucun service en dur : fond de carte, géocodage et
 * itinéraire sont décrits ici. Changer de fournisseur (MapTiler, Google,
 * OpenRouteService…) se fait dans CE fichier, en respectant la forme des
 * fonctions `geocoder` et `itineraire` — le composant n'en voit que le résultat.
 *
 * ⚠️ CSP DU SITE — chaque domaine appelé doit être déclaré en site de confiance
 * (Configuration > Sites de confiance CSP) :
 *   • tuiles     : https://tile.openstreetmap.org  (img-src)
 *   • géocodage  : https://nominatim.openstreetmap.org (connect-src)
 *   • itinéraire : https://router.project-osrm.org  (connect-src)
 * Un domaine absent n'affiche AUCUNE erreur visible : les tuiles restent grises
 * ou les appels échouent en silence dans la console.
 */

/** Fond de carte (tuiles raster). */
export const FOND_CARTE = {
    url: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    attribution: '&copy; OpenStreetMap',
    zoomMax: 19
};

/** Vue initiale tant qu'aucun point n'est placé (Espagne). */
export const VUE_DEFAUT = { lat: 40.2, lng: -3.7, zoom: 6 };

/** Zoom maximal quand la carte s'ajuste aux points (évite un zoom rue sur 1 point). */
export const ZOOM_AJUSTEMENT_MAX = 14;

/** Couleurs des marqueurs, par clé passée dans `point.couleur`. */
export const COULEURS = {
    defaut: '#2E9E5B',
    alerte: '#DC2626',
    attente: '#D97706',
    info: '#1D4ED8',
    gris: '#64748B',
    moi: '#2563EB'
};

/* ═══════════════════════════ Géocodage ═══════════════════════════ */

/**
 * Nominatim impose 1 requête par seconde maximum (règle d'usage du service).
 * Les adresses déjà trouvées sont gardées en mémoire de session : rouvrir la
 * carte ne relance pas les recherches.
 */
export const GEOCODAGE_DELAI_MS = 1100;

/**
 * Adresse texte -> { lat, lng } ou null.
 * Si l'adresse complète ne donne rien, une seconde recherche est tentée sur
 * « code postal + ville » (les adresses importées sont souvent approximatives).
 */
export async function geocoder(adresse) {
    const texte = String(adresse || '').trim();
    if (!texte) return null;
    const trouve = await rechercheNominatim(texte);
    if (trouve) return trouve;
    const repli = repliCodePostalVille(texte);
    return repli && repli !== texte ? rechercheNominatim(repli) : null;
}

async function rechercheNominatim(q) {
    const params = new URLSearchParams({ q, format: 'json', limit: '1' });
    const rep = await fetch(`https://nominatim.openstreetmap.org/search?${params.toString()}`, {
        headers: { Accept: 'application/json' }
    });
    if (!rep.ok) return null;
    const data = await rep.json();
    if (!Array.isArray(data) || !data.length) return null;
    return { lat: Number(data[0].lat), lng: Number(data[0].lon) };
}

/** « 39 RUE X, 48000, MENDE » -> « 48000 MENDE ». */
function repliCodePostalVille(texte) {
    const m = texte.match(/(\d{5})\s*,?\s*([^,\d][^,]*)$/);
    return m ? `${m[1]} ${m[2].trim()}` : null;
}

/* ═══════════════════════════ Itinéraire ═══════════════════════════ */

/**
 * Itinéraire routier entre deux points.
 * @returns { coordonnees: [[lat,lng]...], distanceM, dureeS } ou null.
 */
export async function itineraire(depart, arrivee) {
    const url = 'https://router.project-osrm.org/route/v1/driving/'
        + `${depart.lng},${depart.lat};${arrivee.lng},${arrivee.lat}`
        + '?overview=full&geometries=geojson';
    const rep = await fetch(url);
    if (!rep.ok) return null;
    const data = await rep.json();
    const route = data && data.routes && data.routes[0];
    if (!route) return null;
    return {
        // GeoJSON = [lng, lat] ; Leaflet attend [lat, lng].
        coordonnees: route.geometry.coordinates.map(([lng, lat]) => [lat, lng]),
        distanceM: route.distance,
        dureeS: route.duration
    };
}

/** Lien de navigation externe (application GPS du téléphone). */
export function lienNavigation(depart, arrivee) {
    const dest = `${arrivee.lat},${arrivee.lng}`;
    const orig = depart ? `&origin=${depart.lat},${depart.lng}` : '';
    return `https://www.google.com/maps/dir/?api=1&destination=${dest}${orig}&travelmode=driving`;
}