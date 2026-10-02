/**
 * dicoEntete — en-tête du site, bloc d'erreur plein écran, barre « retour »
 * et pied de page contact. Consommé par lwc020_CampagneContainer.
 *
 * Les valeurs `fr` sont recopiées A L'IDENTIQUE des chaînes actuellement en dur
 * dans lwc020_CampagneContainer.html/.js : c'est ce qui garantit qu'une campagne
 * France n'affiche STRICTEMENT aucun changement.
 *
 * Note métier : « CEE » (Certificats d'Économies d'Énergie) devient « CAE »
 * (Certificados de Ahorro Energético), le dispositif espagnol équivalent,
 * en vigueur depuis 2023 — et non une traduction littérale du sigle français.
 */
export const DICO_ENTETE = {
    fr: {
        // Marque + navigation
        // NB : le titre du site (« Espace CEE » / « Espace CAE ») n'est PAS ici.
        // Il dépend du pays de la campagne et non de la langue d'affichage —
        // voir TITRE_SITE_* dans lwc020_CampagneContainer.js.
        logoAlt: 'Logo Renov',
        menuAria: 'Menu',
        creerAcces: 'Créer Accès Utilisateurs',
        nouveauRdv: 'Nouveau RDV',
        reporting: 'Reporting',
        cahierCharges: 'Cahier de Charges',
        facturation: 'Facturation',
        // Libellé du même onglet pour les partenaires (accès réduit) : ils n'y
        // facturent pas, ils suivent leurs dossiers au regard de leur contrat.
        // Même formulation que dicoFacturation.titrePartenaire.
        facturationContrat: 'Facturation/Contrat',
        deconnexion: 'Se déconnecter',

        // Sélecteur de langue (visible uniquement pour les campagnes Espagne)
        choixLangueAria: 'Choix de la langue',
        langueFrTitre: 'Afficher le site en français',
        langueEsTitre: 'Afficher le site en espagnol',

        // Barre de retour (accès réduit)
        retourProduits: 'Retour aux produits',

        // Bloc d'erreur plein écran
        lienInvalide: 'Lien invalide',
        pageNonTrouvee: 'Page non trouvée',
        pasAcces: "Vous n'avez pas accès à cette page. Vérifiez votre lien ou contactez le support de RENOV.",
        conseilLien: "Conseil: Vérifiez que l'URL de votre lien est correcte ou contactez le support de RENOV.",

        // Pied de page contact (accès réduit)
        besoinAide: "Besoin d'aide ?",
        contactTel: 'Contactez notre équipe par téléphone.',
        appeler: 'Appeler'
    },
    es: {
        logoAlt: 'Logo Renov',
        menuAria: 'Menú',
        creerAcces: 'Crear accesos de usuario',
        nouveauRdv: 'Nueva cita',
        reporting: 'Informes',
        cahierCharges: 'Pliego de condiciones',
        facturation: 'Facturación',
        facturationContrat: 'Facturación/Contrato',
        deconnexion: 'Cerrar sesión',

        choixLangueAria: 'Selección de idioma',
        langueFrTitre: 'Ver el sitio en francés',
        langueEsTitre: 'Ver el sitio en español',

        retourProduits: 'Volver a los productos',

        lienInvalide: 'Enlace no válido',
        pageNonTrouvee: 'Página no encontrada',
        pasAcces: 'No tiene acceso a esta página. Compruebe su enlace o póngase en contacto con el soporte de RENOV.',
        conseilLien: 'Consejo: compruebe que la URL de su enlace es correcta o póngase en contacto con el soporte de RENOV.',

        besoinAide: '¿Necesita ayuda?',
        contactTel: 'Póngase en contacto con nuestro equipo por teléfono.',
        appeler: 'Llamar'
    }
};