/**
 * dicoReporting — onglet Reporting (lwc020_reporting_v2).
 *
 * ATTENTION — ne JAMAIS ajouter ici les valeurs de statut manipulées par le
 * composant ('🟩Passage Effectué', '▣ Nouveau Dossier', 'MPR: Déposé'...).
 * Ce sont des VALEURS de picklist Salesforce servant à des comparaisons dans le
 * code : les traduire casserait le filtrage et les couleurs de badge. Elles
 * représentent l'essentiel des chaînes françaises du fichier, d'où l'écart entre
 * le volume apparent et le périmètre réel de traduction.
 *
 * Notes métier :
 *  - « App. Affaire » (apporteur d'affaires) -> « Prescriptor ».
 *  - « Fiche CEE » -> « Ficha CAE » : le dispositif espagnol équivalent.
 *  - « Dossier » -> « Expediente », terme administratif standard.
 */
export const DICO_REPORTING = {
    fr: {
        // Barre d'outils
        filtresRecherche: 'Filtres de recherche',
        reinitialiser: 'Réinitialiser',
        actualiser: 'Actualiser',
        rechercherPh: 'Rechercher...',
        masquer: 'Masquer',
        tous: 'Tous',

        // États
        chargementDonnees: 'Chargement des données...',
        aucunResultat: 'Aucun résultat',
        aucuneDonnee: 'Aucune donnée à afficher.',
        aucuneDonneeAide: "Après avoir ajouté votre première recommandation, vous pourrez suivre ici l'avancement de vos dossiers.",
        avertissementMobile: 'Cette présentation est optimisée pour ordinateur ou tablette. Pour une meilleure expérience, veuillez utiliser un écran plus large.',

        // Pagination
        precedent: '‹ Préc.',
        suivant: 'Suiv. ›',

        // En-têtes longs (filtres)
        colDateCreation: 'Date de création',
        colDateModif: 'Date dernière modification',
        colNomClientSociete: 'Nom client- Societe',
        colTelephone: 'Téléphone',
        colInfosConfirmation: 'Infos Confirmation',
        colTypeClient: 'Type Client',
        colTypeFiche: 'Type Fiche CEE',
        colStatutConfirmation: 'Statut Confirmation',
        colStatutAdmin: 'Statut Admin',
        colStatutInstallation: 'Statut Installation',
        colInfosDossier: 'Informations Dossier',
        colStatutPaiement: 'Statut Paiement',
        // Colonnes réservées au Responsable Télépro.
        colNomTelepro: 'Nom Télépro',
        colConfirmateur: 'Confirmateur',
        colNote: 'Note',

        // En-têtes courts (tableau)
        thCreation: 'Création',
        thLastModif: 'Last modif.',
        thAppAffaire: 'App. Affaire',
        thNomClient: 'Nom client',
        thNom: 'Nom',
        thStatutConf: 'Statut Conf.',
        thStatutInstall: 'Statut Install.',
        thInfosDossier: 'Infos Dossier',
        thCom: 'Com',

        // Colonne « Docs » : pastille qui ouvre c/lwc026_documents.
        thDocs: 'Docs',
        docTitre: 'Documents joints — cliquer pour ouvrir',

        // Colonne « Statut Devis » — Espagne uniquement. Chaque état est un
        // bouton vers c/lwc021_devis_signature, qui s'aiguille sur le statut.
        colStatutDevis: 'Statut Devis',
        devisGenerer: '+ Générer devis',
        devisGenererTitre: 'Cliquer pour générer le devis',
        devisAttSignature: 'Att. signature',
        devisAttSignatureTitre: 'En attente de signature — cliquer pour modifier le devis',
        devisRelancerTitre: 'Relancer la signature',
        // Pastille d'action : « + relance », puis « Relance - 2 ».
        devisRelanceAjouter: '+ relance',
        devisRelance: 'Relance',
        devisSigne: 'Signé',
        devisSigneTitre: 'Cliquer pour afficher le devis signé',

        // Libellés du FILTRE « Statut Devis ». Volontairement distincts des
        // pastilles ci-dessus : « + Générer devis » est une invite à cliquer,
        // qui n'a aucun sens dans une liste de valeurs à cocher.
        devisFiltreGenerer: 'À générer',
        devisFiltreAttente: 'En attente de signature',
        devisFiltreSigne: 'Signé'
    },
    es: {
        filtresRecherche: 'Filtros de búsqueda',
        reinitialiser: 'Restablecer',
        actualiser: 'Actualizar',
        rechercherPh: 'Buscar...',
        masquer: 'Ocultar',
        tous: 'Todos',

        chargementDonnees: 'Cargando los datos...',
        aucunResultat: 'Sin resultados',
        aucuneDonnee: 'No hay datos que mostrar.',
        aucuneDonneeAide: 'Tras añadir su primera recomendación, podrá seguir aquí el avance de sus expedientes.',
        avertissementMobile: 'Esta vista está optimizada para ordenador o tableta. Para una mejor experiencia, utilice una pantalla más ancha.',

        precedent: '‹ Ant.',
        suivant: 'Sig. ›',

        colDateCreation: 'Fecha de creación',
        colDateModif: 'Última modificación',
        colNomClientSociete: 'Nombre del cliente / empresa',
        colTelephone: 'Teléfono',
        colInfosConfirmation: 'Información de confirmación',
        colTypeClient: 'Tipo de cliente',
        colTypeFiche: 'Tipo de ficha CAE',
        colStatutConfirmation: 'Estado de confirmación',
        colStatutAdmin: 'Estado administrativo',
        colStatutInstallation: 'Estado de instalación',
        colInfosDossier: 'Información del expediente',
        colStatutPaiement: 'Estado de pago',
        colNomTelepro: 'Teleoperador',
        colConfirmateur: 'Confirmador',
        colNote: 'Nota',

        thCreation: 'Creación',
        thLastModif: 'Últ. modif.',
        thAppAffaire: 'Prescriptor',
        thNomClient: 'Nombre del cliente',
        thNom: 'Nombre',
        thStatutConf: 'Est. confirm.',
        thStatutInstall: 'Est. instal.',
        thInfosDossier: 'Info expediente',
        thCom: 'Com',

        thDocs: 'Docs',
        docTitre: 'Documentos adjuntos — haga clic para abrir',

        colStatutDevis: 'Estado presupuesto',
        devisGenerer: '+ Generar presupuesto',
        devisGenererTitre: 'Haga clic para generar el presupuesto',
        devisAttSignature: 'Pdte. firma',
        devisAttSignatureTitre: 'Pendiente de firma — haga clic para modificar el presupuesto',
        devisRelancerTitre: 'Reenviar la solicitud de firma',
        devisRelanceAjouter: '+ recordatorio',
        devisRelance: 'Recordatorio',
        devisSigne: 'Firmado',
        devisSigneTitre: 'Haga clic para ver el presupuesto firmado',

        devisFiltreGenerer: 'Por generar',
        devisFiltreAttente: 'Pendiente de firma',
        devisFiltreSigne: 'Firmado'
    }
};