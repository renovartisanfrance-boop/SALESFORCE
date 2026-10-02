/**
 * dicoDevis — modale « Signer devis » (c/lwc021_devis_signature).
 *
 * ATTENTION — comme pour dicoReporting, ne JAMAIS mettre ici les VALEURS de
 * picklist du statut de devis (« ▣ Génération Devis », « 🟩Signé »…). Elles
 * servent à des comparaisons côté Apex ; les traduire casserait le workflow.
 * Seul le libellé d'ÉTAPE (Récapitulatif / Document / Signature) est traduit.
 *
 * Notes métier :
 *  - le document `cae_colab_contrat` est une « hoja de pedido » espagnole : le
 *    vocabulaire ES retenu suit celui du document (« Potencia », « Firmar »).
 *  - « Puissance » -> « Potencia » (et non « Poder »), terme technique du RITE.
 */
export const DICO_DEVIS = {
    fr: {
        // Modale
        titreModale: 'Devis',
        fermer: 'Fermer',
        chargement: 'Chargement du devis...',

        // Onglets
        ongletRecap: 'Récapitulatif',
        ongletDocument: 'Document',
        ongletSignature: 'Signature',

        // Récapitulatif
        recapIntro: 'Vérifiez les informations avant de générer le devis.',
        enregistrer: 'Enregistrer',
        enregistrementEnCours: 'Enregistrement...',
        enregistre: 'Modifications enregistrées.',
        aucuneModification: 'Aucune modification à enregistrer.',
        annulerModifs: 'Annuler les modifications',
        suivant: 'Suivant',
        precedent: 'Précédent',
        // {0} = la liste des champs vides, separee par des virgules.
        champsObligatoires: 'Renseignez tous les champs avant de continuer : {0}.',

        // Puissance
        puissance: 'Puissance',
        puissanceRetenue: 'Puissance retenue',
        surfaceAbsente: 'Surface habitable non renseignée : la puissance ne peut pas être déterminée.',
        // Le document joint au dossier ne correspond plus à l'écran — voir
        // contratEnvoyeConforme. C'est ce fichier-là qui partirait à la signature.
        signatureDocumentObsolete: 'Le devis est en cours de mise à jour. Patientez avant de le soumettre à la signature.',
        // Fiche a plusieurs versions de devis : tant qu'aucune n'est choisie,
        // il n'y a pas de document a produire.
        devisVersionAChoisir: 'Choisissez le type de devis pour produire le document.',
        // Fiche a calculs (TH168) : la surface ne tombe dans aucune tranche.
        // {0} = la donnee en cause (« Surface de toiture », « Surface habitable »).
        calculHorsCible: '{0} hors des tranches du devis : le dimensionnement est impossible.',
        calculChampAbsent: '{0} non renseignée : le dimensionnement est impossible.',
        // Sous un champ pre-rempli par une regle de la fiche (nombre de capteurs).
        valeurRecommandeeAide: 'Valeur recommandée d\'après la surface saisie — vous pouvez en choisir une autre.',
        // {0} = la valeur recommandee, quand l'utilisateur en a choisi une autre.
        valeurRecommandeeAutre: 'Valeur recommandée : {0}.',
        surfaceTropPetite: 'Surface inférieure à 80 m² : hors cible.',
        surfaceTropGrande: 'Surface supérieure à 210 m² : hors cible.',
        horsCible: 'Hors cible',

        // Document
        documentIntro: 'Document contractuel associé au devis.',
        ouvrirNouvelOnglet: 'Ouvrir dans un nouvel onglet',
        pdfIndisponible: "Le document n'a pas pu être chargé.",
        casePuissance: 'Case à cocher dans la section Description :',
        caseCochee: 'Case cochée dans le document, section Description :',
        pdfEnCours: 'Préparation du document...',
        // Étapes de production du devis — nommées une par une : l'opération
        // dure quelques secondes et un spinner muet passe pour un blocage.
        pdfEtapeLibs: "Chargement de l'éditeur de document...",
        pdfEtapeModele: 'Récupération du modèle de contrat...',
        pdfEtapeGeneration: 'Génération de votre devis...',
        pdfEtapeEnregistrement: 'Enregistrement au dossier...',
        pdfEtapeAffichage: 'Affichage du document...',
        pdfPatienter: 'Merci de patienter quelques instants.',
        // Aperçu canvas désactivé : le document s'ouvre dans un onglet.
        documentPret: 'Votre devis est prêt.',
        ouvrirDocument: 'Ouvrir le devis',
        ouvrirDocumentAide: "Le document s'ouvre dans un nouvel onglet.",
        documentSignePret: 'Votre devis signé est disponible.',
        ouvrirDocumentSigne: 'Ouvrir le devis signé',
        pdfNonCoche: "La case n'a pas pu être cochée automatiquement : le document s'affiche non coché.",
        caseCocheeJointe: 'Case cochée — devis joint au dossier :',
        fichierJointErreur: "Le devis n'a pas pu être joint au dossier.",

        // Signature — envoi à Yousign.
        // {0} est remplacé par le composant : ne pas retirer le marqueur.
        signaturePrete: 'Le devis est prêt à être signé.',
        signerDevis: 'Envoyer en signature',
        signatureBloqueeHorsCible: 'Signature impossible : la surface est hors cible.',
        signatureEmailLabel: 'Email du signataire',
        signatureDestinataire: 'Signataire',
        signatureEnvoiEnCours: 'Envoi en cours…',
        signatureEnvoyee: 'Devis envoyé à {0} pour signature.',
        signatureErreurEnvoi: "L'envoi à la signature a échoué.",
        signatureEmailManquant: "Renseignez l'adresse email du signataire.",
        signatureDejaEnvoyee: 'Une demande de signature a été envoyée le {0}.',
        signatureAttenteAide: "Le client reçoit un lien par email. Le devis passera automatiquement à « signé » dès qu'il aura signé.",
        // Écran de choix proposé quand une demande est déjà partie.
        emailModifier: 'Modifier',
        relanceModifierInfos: 'Modifier les informations du devis',
        relanceModifierEmail: "Modifier l'email du signataire",
        // {0} = le nombre de relances actuel, {1} = celui qui suivra.
        relanceFleche: 'Relance {0} → {1}',
        relanceEnregistrerEtEnvoyer: 'Enregistrer et envoyer la relance',
        // {0} = le rang de la relance a venir : « 1re », « 2e »...
        relanceEnvoyer: 'Envoyer la {0} relance',

        // Devis signé : le récapitulatif disparaît, seul le document reste.
        devisSigneInfo: 'Ce devis est signé. Le document ci-dessous fait foi ; ses informations ne sont plus modifiables.',
        devisSigneIntrouvable: 'Le devis signé est introuvable dans le dossier.',
        devisSigneLe: 'Signé le {0}',

        // Statuts
        enAttenteSignature: 'Ce devis est en attente de signature.',
        dejaSigne: 'Ce devis est déjà signé.',
        etapeNonDisponible: 'Cette étape sera disponible dans une prochaine version.',
        statutInconnu: 'Statut de devis non reconnu.',

        // Erreurs
        erreurChargement: 'Impossible de charger le devis.',
        erreurEnregistrement: "Impossible d'enregistrer les modifications.",
        tokenManquant: 'Session expirée : veuillez vous reconnecter au portail.'
    },

    es: {
        titreModale: 'Presupuesto',
        fermer: 'Cerrar',
        chargement: 'Cargando el presupuesto...',

        ongletRecap: 'Resumen',
        ongletDocument: 'Documento',
        ongletSignature: 'Firma',

        recapIntro: 'Compruebe los datos antes de generar el presupuesto.',
        enregistrer: 'Guardar',
        enregistrementEnCours: 'Guardando...',
        enregistre: 'Cambios guardados.',
        aucuneModification: 'No hay cambios que guardar.',
        annulerModifs: 'Descartar los cambios',
        suivant: 'Siguiente',
        precedent: 'Anterior',
        champsObligatoires: 'Complete todos los campos antes de continuar: {0}.',

        puissance: 'Potencia',
        puissanceRetenue: 'Potencia seleccionada',
        surfaceAbsente: 'Superficie habitable sin cumplimentar: no se puede determinar la potencia.',
        signatureDocumentObsolete: 'El presupuesto se está actualizando. Espere antes de enviarlo a firma.',
        devisVersionAChoisir: 'Elija el tipo de presupuesto para generar el documento.',
        calculHorsCible: '{0} fuera de los tramos del presupuesto: no se puede dimensionar.',
        calculChampAbsent: '{0} sin cumplimentar: no se puede dimensionar.',
        valeurRecommandeeAide: 'Valor recomendado según la superficie indicada: puede elegir otro.',
        valeurRecommandeeAutre: 'Valor recomendado: {0}.',
        surfaceTropPetite: 'Superficie inferior a 80 m²: fuera de objetivo.',
        surfaceTropGrande: 'Superficie superior a 210 m²: fuera de objetivo.',
        horsCible: 'Fuera de objetivo',

        documentIntro: 'Documento contractual asociado al presupuesto.',
        ouvrirNouvelOnglet: 'Abrir en una pestaña nueva',
        pdfIndisponible: 'No se ha podido cargar el documento.',
        casePuissance: 'Casilla que marcar en la sección Descripción:',
        caseCochee: 'Casilla marcada en el documento, sección Descripción:',
        pdfEnCours: 'Preparando el documento...',
        pdfEtapeLibs: 'Cargando el editor de documentos...',
        pdfEtapeModele: 'Recuperando la plantilla del contrato...',
        pdfEtapeGeneration: 'Generando su presupuesto...',
        pdfEtapeEnregistrement: 'Guardando en el expediente...',
        pdfEtapeAffichage: 'Mostrando el documento...',
        pdfPatienter: 'Espere unos instantes, por favor.',
        documentPret: 'Su presupuesto está listo.',
        ouvrirDocument: 'Abrir el presupuesto',
        ouvrirDocumentAide: 'El documento se abre en una pestaña nueva.',
        documentSignePret: 'Su presupuesto firmado está disponible.',
        ouvrirDocumentSigne: 'Abrir el presupuesto firmado',
        pdfNonCoche: 'No se ha podido marcar la casilla automáticamente: el documento se muestra sin marcar.',
        caseCocheeJointe: 'Casilla marcada — presupuesto adjuntado al expediente:',
        fichierJointErreur: 'No se ha podido adjuntar el presupuesto al expediente.',

        signaturePrete: 'El presupuesto está listo para firmarse.',
        signerDevis: 'Enviar para firma',
        signatureBloqueeHorsCible: 'No se puede firmar: la superficie está fuera de objetivo.',
        signatureEmailLabel: 'Email del firmante',
        signatureDestinataire: 'Firmante',
        signatureEnvoiEnCours: 'Enviando…',
        signatureEnvoyee: 'Presupuesto enviado a {0} para su firma.',
        signatureErreurEnvoi: 'No se ha podido enviar el presupuesto para firma.',
        signatureEmailManquant: 'Introduzca el email del firmante.',
        signatureDejaEnvoyee: 'Se envió una solicitud de firma el {0}.',
        signatureAttenteAide: 'El cliente recibe un enlace por email. El presupuesto pasará automáticamente a « firmado » en cuanto firme.',
        emailModifier: 'Modificar',
        relanceModifierInfos: 'Modificar los datos del presupuesto',
        relanceModifierEmail: 'Modificar el email del firmante',
        relanceFleche: 'Recordatorio {0} → {1}',
        relanceEnregistrerEtEnvoyer: 'Guardar y enviar el recordatorio',
        relanceEnvoyer: 'Enviar el {0} recordatorio',

        devisSigneInfo: 'Este presupuesto está firmado. El documento siguiente es el que da fe; sus datos ya no se pueden modificar.',
        devisSigneIntrouvable: 'No se encuentra el presupuesto firmado en el expediente.',
        devisSigneLe: 'Firmado el {0}',

        enAttenteSignature: 'Este presupuesto está pendiente de firma.',
        dejaSigne: 'Este presupuesto ya está firmado.',
        etapeNonDisponible: 'Esta etapa estará disponible en una próxima versión.',
        statutInconnu: 'Estado de presupuesto no reconocido.',

        erreurChargement: 'No se ha podido cargar el presupuesto.',
        erreurEnregistrement: 'No se han podido guardar los cambios.',
        tokenManquant: 'Sesión caducada: vuelva a conectarse al portal.'
    }
};