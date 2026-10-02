/**
 * dicoFileUpload — zone de dépôt de fichiers (c/customFileUpload).
 *
 * Ce composant est PARTAGÉ : sans `langue` passée par le parent, il reste en
 * français, exactement comme aujourd'hui.
 *
 * Note de traduction : « téléchargement » désigne ici un envoi vers le serveur.
 * L'espagnol distingue « subir » (envoyer) de « descargar » (recevoir) — c'est
 * bien « subir » qu'il faut employer.
 */
export const DICO_FILE_UPLOAD = {
    fr: {
        dropPrimaire: 'Glissez-déposez vos documents ici',
        dropSecondaire: 'ou cliquez pour parcourir',
        formatsAcceptes: 'Formats acceptés:',
        fichiersSelectionnes: 'Fichiers sélectionnés',
        toutSupprimer: 'Tout supprimer',
        supprimerCeFichier: 'Supprimer ce fichier',
        tailleTotale: 'Taille totale:',
        choisirFichier: 'Choisir un fichier',

        // Variante compacte
        ajouter: 'Ajouter',
        unFichier: '1 fichier',
        nFichiers: '{n} fichiers',

        // Progression / succès — interpolés en JS car l'ordre des mots diffère
        // (l'espagnol ouvre par « ¡ » avant le nombre).
        telechargementEnCours: 'Téléchargement en cours...',
        telechargementPourcent: 'Téléchargement en cours... {pct}%',
        fichiersTelecharges: '{n} fichier(s) téléchargé(s) avec succès!',
        fichierTelecharge: 'Fichier téléchargé avec succès!',

        // Erreurs
        errFichierVolumineux: 'Le fichier "{nom}" est trop volumineux. Taille maximale: {max}',
        errTypeNonAutorise: 'Type de fichier non autorisé pour "{nom}". Formats acceptés: {formats}',
        errTailleTotale: 'La taille totale des fichiers dépasse la limite de {max}. Taille actuelle: {actuelle}',
        errLecture: 'Erreur lors de la lecture des fichiers',
        errSelectionFichier: 'Veuillez sélectionner un fichier',
        errSelectionAuMoinsUn: 'Veuillez sélectionner au moins un fichier',
        errTelechargementFichier: 'Erreur lors du téléchargement du fichier',
        errTelechargementFichiers: 'Erreur lors du téléchargement des fichiers',
        errEchecTelechargement: 'Échec du téléchargement de {n} fichier(s): {fichiers}'
    },
    es: {
        dropPrimaire: 'Arrastre y suelte sus documentos aquí',
        dropSecondaire: 'o haga clic para examinar',
        formatsAcceptes: 'Formatos admitidos:',
        fichiersSelectionnes: 'Archivos seleccionados',
        toutSupprimer: 'Eliminar todo',
        supprimerCeFichier: 'Eliminar este archivo',
        tailleTotale: 'Tamaño total:',
        choisirFichier: 'Elegir un archivo',

        ajouter: 'Añadir',
        unFichier: '1 archivo',
        nFichiers: '{n} archivos',

        telechargementEnCours: 'Subiendo...',
        telechargementPourcent: 'Subiendo... {pct}%',
        fichiersTelecharges: '¡{n} archivo(s) subido(s) correctamente!',
        fichierTelecharge: '¡Archivo subido correctamente!',

        errFichierVolumineux: 'El archivo «{nom}» es demasiado grande. Tamaño máximo: {max}',
        errTypeNonAutorise: 'Tipo de archivo no admitido para «{nom}». Formatos admitidos: {formats}',
        errTailleTotale: 'El tamaño total de los archivos supera el límite de {max}. Tamaño actual: {actuelle}',
        errLecture: 'Error al leer los archivos',
        errSelectionFichier: 'Seleccione un archivo',
        errSelectionAuMoinsUn: 'Seleccione al menos un archivo',
        errTelechargementFichier: 'Error al subir el archivo',
        errTelechargementFichiers: 'Error al subir los archivos',
        errEchecTelechargement: 'Error al subir {n} archivo(s): {fichiers}'
    }
};