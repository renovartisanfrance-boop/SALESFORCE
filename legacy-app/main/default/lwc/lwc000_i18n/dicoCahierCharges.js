/**
 * dicoCahierCharges — page « Cahier de charges » (lwc020_CahierCharges).
 *
 * Périmètre volontairement réduit : tout le bloc commercial « Recommandez un
 * client » (barème de revenus, Île-de-France, montants en €, PAC Air/Eau et
 * Air/Air) dépend de th171Product, or TH171 est un produit pays: ["France"]
 * que filtrerProduitsParPays écarte pour l'Espagne. Ce bloc est donc
 * inatteignable en espagnol : le traduire n'aurait aucun sens, ses barèmes
 * étant des dispositifs réglementaires français (MaPrimeRénov').
 *
 * Note métier : « Cahier des charges » -> « Pliego de condiciones », terme
 * formel espagnol du document qui fixe les exigences techniques d'une
 * opération. « Fiche » -> « Ficha », qui est aussi le mot employé dans le
 * système CAE espagnol (fichas estandarizadas).
 */
export const DICO_CAHIER_CHARGES = {
    fr: {
        chargementProduits: 'Chargement des produits...',
        // Bandeau « accès réduit » : rappelle au partenaire où retrouver son
        // lien de connexion. Affiché aux partenaires des DEUX pays.
        reconnexionTexte: 'Votre lien de connexion personnel se trouve dans votre e-mail. Pensez à vérifier vos courriers indésirables.',
        produitsDisponibles: 'Produits disponibles',

        // Actions sur une fiche produit
        voirCdcTitre: 'Voir le Cahier Des Charges',
        voirCdc: 'Voir Cahier Des Charges',
        voirCatalogueTitre: 'Voir le catalogue produit',
        voirCatalogue: 'Voir Catalogue',
        demandezCdc: 'Demandez votre CDC',

        // Simulateurs (produits France : inatteignable en espagnol, traduit par
        // cohérence si un produit espagnol en reçoit un un jour)
        simulateurTitre: "Lancer le simulateur d'éligibilité et de commission",
        simulateur: 'Simulateur Éligibilité/Commission',
        fermerSimulateur: 'Fermer le simulateur',

        // Repli / affichage
        masquer: 'Masquer',
        afficherProduits: 'Afficher les produits',
        masquerProduits: 'Masquer les produits'
    },
    es: {
        chargementProduits: 'Cargando los productos...',
        reconnexionTexte: 'Su enlace de acceso personal está en su correo electrónico. No olvide revisar la carpeta de correo no deseado.',
        produitsDisponibles: 'Productos disponibles',

        voirCdcTitre: 'Ver el pliego de condiciones',
        voirCdc: 'Ver el pliego',
        voirCatalogueTitre: 'Ver el catálogo de productos',
        voirCatalogue: 'Ver catálogo',
        demandezCdc: 'Solicite su pliego',

        simulateurTitre: 'Abrir el simulador de elegibilidad y comisión',
        simulateur: 'Simulador de elegibilidad/comisión',
        fermerSimulateur: 'Cerrar el simulador',

        masquer: 'Ocultar',
        afficherProduits: 'Mostrar los productos',
        masquerProduits: 'Ocultar los productos'
    }
};