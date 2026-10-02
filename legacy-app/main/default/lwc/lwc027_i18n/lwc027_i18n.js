/**
 * lwc027_i18n — traduction du portail Gestion Prévisites (ES par défaut, FR en option).
 *
 * Même mécanique que c/lwc000_i18n — dictionnaires par écran, `etiquettes()`
 * mémoïsée, langue persistée dans localStorage — mais avec DEUX différences qui
 * justifient un module séparé plutôt qu'un ajout au module partagé :
 *
 *   1. LA RÈGLE DE LANGUE N'EST PAS LA MÊME. Dans Campagnes, elle se déduit de
 *      Campaign.Pays__c et d'AccesReduit__c : français par défaut, espagnol pour
 *      l'Espagne, et aucun sélecteur pour les partenaires. Ici, l'ESPAGNOL est
 *      la langue par défaut sans condition, et la bascule est TOUJOURS offerte —
 *      le portail ne s'adresse qu'à des techniciens espagnols, le français n'est
 *      qu'un confort. Passer un faux `pays` à lireLangue() pour obtenir ce
 *      comportement aurait marché, mais par effet de bord.
 *
 *   2. LA CLÉ DE STOCKAGE EST DISTINCTE. c/lwc000_i18n écrit sous
 *      « renov_langue ». Les deux portails partagent le même domaine
 *      my.site.com : une clé commune ferait basculer la langue de Campagnes en
 *      changeant celle de Prévisites, et inversement. Même raisonnement que
 *      pour la clé du token dans lwc027_previsite_container.
 *
 * La signature du contrat, elle, N'EST PAS concernée : elle reste en espagnol
 * quelle que soit la langue d'affichage — voir contratConfig.CONTRAT_SIGNATURE.
 */

import { DICO_ENTETE } from './dicoEntete';
import { DICO_CONTRAT } from './dicoContrat';
import { DICO_PREVISITE } from './dicoPrevisite';
import { DICO_FACTURATION } from './dicoFacturation';
import { DICO_INSTALLATIONS } from './dicoInstallations';
import { DICO_FACTURATION_INSTALLATEUR } from './dicoFacturationInstallateur';

export const ES = 'es';
export const FR = 'fr';

/** Espagnol par défaut, sans condition : le portail est espagnol. */
export const LANGUE_DEFAUT = ES;

/** Distincte de « renov_langue » (Campagnes) — voir l'en-tête. */
export const CLE_LANGUE = 'renov_previsite_langue';

const ECRANS = {
    entete: DICO_ENTETE,
    contrat: DICO_CONTRAT,
    previsite: DICO_PREVISITE,
    facturation: DICO_FACTURATION,
    // Rôle Installateur : écrans distincts, mêmes clés que leurs pendants
    // prévisiteur (composants copiés).
    installations: DICO_INSTALLATIONS,
    facturationInstallateur: DICO_FACTURATION_INSTALLATEUR
};

const _cache = new Map();

/** Ramène n'importe quelle valeur à 'es' ou 'fr'. */
export function normaliserLangue(valeur) {
    const v = String(valeur || '').trim().toLowerCase();
    return v === FR ? FR : ES;
}

/**
 * Langue à appliquer au chargement : le choix mémorisé, sinon l'espagnol.
 * localStorage peut lever (navigation privée stricte) : jamais bloquant.
 */
export function lireLangue() {
    try {
        const stocke = localStorage.getItem(CLE_LANGUE);
        return stocke ? normaliserLangue(stocke) : LANGUE_DEFAUT;
    } catch (e) {
        return LANGUE_DEFAUT;
    }
}

/**
 * Persiste le choix et RENVOIE la langue retenue — à affecter directement :
 *     this.langue = ecrireLangue(choix);
 */
export function ecrireLangue(langue) {
    const lg = normaliserLangue(langue);
    try {
        localStorage.setItem(CLE_LANGUE, lg);
    } catch (e) {
        // Stockage indisponible : la langue tient pour la session en cours.
    }
    return lg;
}

/** L'autre langue que celle passée — utilisé par le bouton de bascule. */
export function autreLangue(langue) {
    return normaliserLangue(langue) === ES ? FR : ES;
}

/**
 * Étiquettes d'un écran, mémoïsées.
 *
 * L'espagnol sert de SOCLE et le français vient par-dessus : une clé oubliée en
 * français affiche l'espagnol, pas « undefined ». C'est l'inverse de
 * c/lwc000_i18n, où le français est le socle — cohérent avec la langue de
 * référence de chaque portail.
 *
 * Pas d'Object.freeze : un objet gelé interagit mal avec le membrane réactif de
 * LWC s'il atterrit sur un champ @track.
 */
export function etiquettes(ecran, langue) {
    const lg = normaliserLangue(langue);
    const cle = ecran + '|' + lg;
    if (_cache.has(cle)) return _cache.get(cle);

    const dico = ECRANS[ecran] || {};
    const plat = {
        ...(dico[ES] || {}),
        ...(lg === ES ? {} : (dico[lg] || {}))
    };
    _cache.set(cle, plat);
    return plat;
}