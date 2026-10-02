/**
 * Libellés de lwc027_carte, propres au composant pour qu'il reste autonome
 * (aucune dépendance au dictionnaire du portail). Espagnol par défaut.
 */
const LIBELLES = {
    es: {
        chargement: 'Cargando el mapa…',
        erreurCarte: 'No se ha podido cargar el mapa.',
        localisation: 'Localizando direcciones: {n}/{total}',
        nonLocalises: 'Direcciones no encontradas en el mapa:',
        maPosition: 'Mi posición',
        positionInactive: 'Activa la localización de tu dispositivo para calcular el itinerario.',
        positionRefusee: 'Localización no disponible: itinerario desactivado.',
        boutonItineraire: 'Itinerario',
        boutonGps: 'Abrir en Google Maps',
        calcul: 'Calculando el itinerario…',
        itineraireKo: 'No se ha podido calcular el itinerario.',
        itineraireVers: 'Itinerario hacia {titre}',
        effacer: 'Borrar',
        recentrer: 'Ver todo',
        min: 'min',
        h: 'h'
    },
    fr: {
        chargement: 'Chargement de la carte…',
        erreurCarte: "La carte n'a pas pu être chargée.",
        localisation: 'Localisation des adresses : {n}/{total}',
        nonLocalises: 'Adresses introuvables sur la carte :',
        maPosition: 'Ma position',
        positionInactive: "Activez la localisation de votre appareil pour calculer l'itinéraire.",
        positionRefusee: 'Localisation indisponible : itinéraire désactivé.',
        boutonItineraire: 'Itinéraire',
        boutonGps: 'Ouvrir dans Google Maps',
        calcul: "Calcul de l'itinéraire…",
        itineraireKo: "L'itinéraire n'a pas pu être calculé.",
        itineraireVers: 'Itinéraire vers {titre}',
        effacer: 'Effacer',
        recentrer: 'Tout afficher',
        min: 'min',
        h: 'h'
    }
};

export function libelles(langue) {
    return { ...LIBELLES.es, ...(langue === 'fr' ? LIBELLES.fr : {}) };
}