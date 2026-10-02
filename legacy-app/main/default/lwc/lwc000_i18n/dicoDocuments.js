/**
 * dicoDocuments — modale « Documents » (c/lwc026_documents), ouverte depuis la
 * colonne Com du reporting.
 *
 * Ce dictionnaire ne porte QUE l'habillage de la modale. Les libellés des
 * sections de photos de la fiche RES060 (« Photo cadastrale »...) et surtout les
 * PRÉFIXES DE NOMMAGE des fichiers ne sont pas recopiés ici : le composant les
 * lit dans dicoNouveauRdv, pour que le nom stocké dans Salesforce soit
 * rigoureusement le même qu'à la création du RDV. Une copie dériverait.
 *
 * `fr` est la référence et doit rester exhaustive ; `es` peut être partiel.
 */
export const DICO_DOCUMENTS = {
    fr: {
        titre: 'Documents',
        typePiste: 'Piste',
        typeDossier: 'Dossier',

        // Liste
        listeTitre: 'Documents joints',
        aucunDocument: 'Aucun document pour le moment.',
        unDocument: '1 document',
        nDocuments: '{n} documents',
        ouvrir: 'Ouvrir le document',
        tropVolumineux: 'Ce fichier est trop volumineux pour être ouvert depuis le portail.',
        ongletBloque: 'Votre navigateur a bloqué l\'ouverture. Cliquez ici :',
        supprimer: 'Supprimer ce document',
        // Interpolé en JS : le nom du fichier est inséré au milieu de la phrase.
        confirmerSuppression: 'Supprimer définitivement « {nom} » ?',
        supprimerConfirmer: 'Supprimer',

        // Consultation seule (Dossier)
        lectureSeule: 'Les documents d\'un dossier sont en consultation seule.',

        // Accordéon d'ajout — fermé par défaut
        ajouterTitre: 'Ajouter des documents',
        ajouterSousTitre: 'Cliquez pour ouvrir la zone de dépôt',
        zoneGenerique: 'Documents',
        // Rappel affiché sous les zones de la fiche RES060 : le partenaire doit
        // savoir que ses fichiers seront renommés, sinon il ne les retrouve pas.
        nommageAutomatique: 'Les fichiers sont renommés automatiquement par type.',
        nommageOrigine: 'Les fichiers conservent leur nom d\'origine.',
        btnEnvoyer: 'Envoyer',
        btnEnvoiEnCours: 'Envoi en cours...',
        // Interpolés en JS (ordre des mots variable d'une langue à l'autre).
        envoiProgression: 'Envoi {n} / {total}...',
        succesEnvoi: '{n} document(s) ajouté(s).',
        succesSuppression: 'Document supprimé.',

        // Erreurs
        errChargement: 'Impossible de charger les documents.',
        errEnvoi: 'Erreur lors de l\'envoi des documents.',
        errSuppression: 'Erreur lors de la suppression du document.',
        errOuverture: 'Impossible d\'ouvrir ce document.',
        errAucunFichier: 'Sélectionnez au moins un fichier.',

        // Unités de taille
        uniteKo: 'Ko',
        uniteMo: 'Mo'
    },
    es: {
        titre: 'Documentos',
        typePiste: 'Contacto',
        typeDossier: 'Expediente',

        listeTitre: 'Documentos adjuntos',
        aucunDocument: 'Todavía no hay documentos.',
        unDocument: '1 documento',
        nDocuments: '{n} documentos',
        ouvrir: 'Abrir el documento',
        tropVolumineux: 'Este archivo es demasiado grande para abrirse desde el portal.',
        ongletBloque: 'Su navegador ha bloqueado la apertura. Haga clic aquí:',
        supprimer: 'Eliminar este documento',
        confirmerSuppression: '¿Eliminar definitivamente «{nom}»?',
        supprimerConfirmer: 'Eliminar',

        lectureSeule: 'Los documentos de un expediente son de solo consulta.',

        ajouterTitre: 'Añadir documentos',
        ajouterSousTitre: 'Haga clic para abrir la zona de carga',
        zoneGenerique: 'Documentos',
        nommageAutomatique: 'Los archivos se renombran automáticamente por tipo.',
        nommageOrigine: 'Los archivos conservan su nombre original.',
        btnEnvoyer: 'Subir',
        btnEnvoiEnCours: 'Subiendo...',
        envoiProgression: 'Subiendo {n} / {total}...',
        succesEnvoi: '{n} documento(s) añadido(s).',
        succesSuppression: 'Documento eliminado.',

        errChargement: 'No se han podido cargar los documentos.',
        errEnvoi: 'Error al subir los documentos.',
        errSuppression: 'Error al eliminar el documento.',
        errOuverture: 'No se ha podido abrir este documento.',
        errAucunFichier: 'Seleccione al menos un archivo.',

        uniteKo: 'KB',
        uniteMo: 'MB'
    }
};