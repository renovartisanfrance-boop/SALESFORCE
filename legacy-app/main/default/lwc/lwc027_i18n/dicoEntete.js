/**
 * Libellés de l'en-tête et des écrans d'état du conteneur.
 * Une entrée par langue ; l'espagnol fait foi, le français est la traduction.
 */
export const DICO_ENTETE = {
    es: {
        titreSite: 'Espacio Previsitador',
        deconnexion: 'Cerrar sesión',
        navPrevisites: 'Mis previsitas',
        navInstallations: 'Mis instalaciones',
        navFacturation: 'Mi facturación',
        navBloquee: 'Disponible una vez firmado el contrato',
        verification: 'Verificando tu acceso…',

        // Écrans d'erreur d'accès — mêmes clés que les statuts renvoyés par
        // LC027_GestionPrevisites, pour que le composant les indexe directement.
        TOKEN_MANQUANT_titre: 'Sesión caducada',
        TOKEN_MANQUANT_message: 'Tu enlace de acceso ya no está en memoria en este dispositivo. Vuelve a abrir el enlace de conexión que recibiste.',
        INTROUVABLE_titre: 'Campaña no encontrada',
        INTROUVABLE_message: 'Ninguna campaña corresponde a este enlace de acceso. Comprueba el enlace recibido o contacta con administración.',
        ROLE_INVALIDE_titre: 'Acceso no autorizado',
        ROLE_INVALIDE_message: 'Este enlace no da acceso al espacio de previsitador. Contacta con administración para conocer tu situación.',
        DESACTIVE_titre: 'Cuenta desactivada',
        DESACTIVE_message: 'Tu cuenta está desactivada. Contacta con administración para conocer tu situación.',
        TECHNIQUE_titre: 'Servicio no disponible',
        TECHNIQUE_message: 'No se ha podido verificar tu acceso. Inténtalo de nuevo; si el problema persiste, contacta con administración.',
        GENERATEUR_titre: 'Vista previa del Generador',
        GENERATEUR_message: 'No hay token en esta vista previa: el control de acceso está desactivado aquí. El componente funcionará con normalidad en el sitio publicado (enlace con ?c__code=...).'
    },
    fr: {
        titreSite: 'Espace Prévisiteur',
        deconnexion: 'Se déconnecter',
        navPrevisites: 'Mes prévisites',
        navInstallations: 'Mes installations',
        navFacturation: 'Ma facturation',
        navBloquee: 'Disponible une fois le contrat signé',
        verification: 'Vérification de votre accès…',

        TOKEN_MANQUANT_titre: 'Session expirée',
        TOKEN_MANQUANT_message: "Votre lien d'accès n'est plus en mémoire sur cet appareil. Rouvrez le lien de connexion qui vous a été transmis.",
        INTROUVABLE_titre: 'Campagne introuvable',
        INTROUVABLE_message: "Aucune campagne ne correspond à ce lien d'accès. Vérifiez le lien reçu ou rapprochez-vous de l'administration.",
        ROLE_INVALIDE_titre: 'Accès non autorisé',
        ROLE_INVALIDE_message: "Ce lien ne donne pas accès à l'espace Prévisites. Rapprochez-vous de l'administration pour connaître votre statut.",
        DESACTIVE_titre: 'Compte désactivé',
        DESACTIVE_message: "Votre compte est désactivé. Veuillez contacter l'administration pour connaître votre statut.",
        TECHNIQUE_titre: 'Service indisponible',
        TECHNIQUE_message: "Impossible de vérifier votre accès. Réessayez ; si le problème persiste, contactez l'administration.",
        GENERATEUR_titre: 'Aperçu Générateur',
        GENERATEUR_message: "Aucun token dans cet aperçu : le contrôle d'accès est neutralisé ici. Le composant fonctionnera normalement sur le site publié (lien avec ?c__code=...)."
    }
};