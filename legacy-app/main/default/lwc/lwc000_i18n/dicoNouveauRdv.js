/**
 * dicoNouveauRdv — libellés de la page « Nouveau RDV » (lwc020_NouveauRdv).
 *
 * Les valeurs `fr` sont recopiées A L'IDENTIQUE des chaînes actuellement en dur
 * dans lwc020_NouveauRdv.html/.js : une campagne France doit afficher
 * STRICTEMENT le même texte qu'avant.
 *
 * Conventions de clés :
 *   …Ph     placeholder          …Aria   aria-label / title
 *   err…    validation / toast   btn…    libellé de bouton
 *   tp_…    libellé de typeProduit (la VALEUR reste française)
 *   pl_…    surcharge d'une valeur de picklist org (clé = valeur d'API)
 *
 * Piège : ne JAMAIS écrire « &nbsp; » ici — LWC échappe les liaisons texte et
 * l'entité s'afficherait littéralement. Utiliser   (espace insécable).
 * L'espace avant « ? » est une règle typographique française : l'espagnol colle
 * le point d'interrogation et ouvre par « ¿ ».
 */
export const DICO_NOUVEAU_RDV = {
    fr: {
        // États de chargement / campagne inactive
        chargementRegie: 'Chargement de la REGIE...',
        regieIntrouvable: 'REGIE Introuvable',
        regieDesactivee: 'REGIE Désactivée',
        regieDesactiveeMsg: "Cette REGIE est actuellement désactivée. Veuillez contacter le gestionnaire de REGIE pour l'activer.",

        // Bloc « produits disponibles »
        cahierDesCharges: 'Cahier Des Charges',
        demandezCdc: 'Demandez votre CDC',
        disponible: 'Disponible',
        nonDispo: 'Non dispo',
        afficherProduits: 'Afficher les produits',
        masquerProduits: 'Masquer les produits',

        // Sélection du produit
        titreCreerRdv: 'Créer un Nouveau RDV',
        typeRdv: 'Type du RDV:',
        choisirProduits: 'Choisir un ou plusieurs produits',

        // Identité
        nomSociete: 'Nom de la Societé',
        nomSocietePh: 'Ex: ABC SARL',
        nomClient: 'Nom Client',
        nomClientFilleul: 'Nom du filleul',
        nomClientPh: 'Ex: Dupont',
        prenom: 'Prénom',
        prenomFilleul: 'Prénom du filleul',
        prenomPh: 'Ex: Jean',
        email: 'Email',
        emailFilleul: 'Email du filleul',
        emailPh: 'jean@example.com',
        telephone: 'Téléphone',
        telephoneFilleul: 'Téléphone du filleul',
        // Volontairement identique en ES : la validation reste au format français
        // (/^0\d{9}$/, maxlength 10). Voir « Limites connues » du plan.
        telephonePh: '0612345678',

        // Adresse
        adresse: 'Adresse',
        adressePh: '123 Rue de la Paix, 75001 Paris',

        // --- Champs de la fiche RES060 (Espagne) ------------------------------
        // Clés df_<apiName> : elles REMPLACENT le libellé de l'org, qui est
        // technique (« RES- Shab », « RES- Anneé maison(ES) ») et fautif.
        sectionLogement: 'Le logement',
        df_RES_Zone_ES__c: 'Zone climatique',
        df_Parcelle_Cadastrale__c: 'Parcelle cadastrale',
        df_RES_Anne_maison__c: 'Année de construction',
        df_Surface_habitable__c: 'Surface habitable',
        df_Type_de_Chauffage__c: 'Type de chauffage',
        df_RES_Ann_e_Chaudi_re__c: 'Année de la chaudière',
        df_Suivi_Signature__c: 'Suivi Signature',
        // Placeholders
        df_RES_Anne_maison__cPh: 'Ex : 1985',
        df_RES_Ann_e_Chaudi_re__cPh: 'Ex : 2010',
        df_Surface_habitable__cPh: 'Ex : 120',
        df_Parcelle_Cadastrale__cPh: 'Ex : 9872023VH5797S0001WX',

        // --- Sections de photos (fiche RES060) --------------------------------
        photoCadastrale: 'Photo cadastrale',
        photoFacade: 'Photo de façade',
        photoChaudiere: 'Photo chaudière + plaque signalétique',
        // Pièce non photographique : le contrat de fourniture d'énergie du
        // client, le plus souvent un PDF. Elle passe par la même zone de dépôt.
        photoContratEnergie: "Contrat d'énergie",
        photoComplementaires: 'Photos complémentaires',
        // Préfixes de NOMMAGE des fichiers envoyés dans Salesforce. Identiques en
        // FR et en ES à dessein : le nom stocké ne doit pas dépendre de la langue
        // d'affichage, sinon deux partenaires produiraient des noms différents
        // pour le même type de document.
        prefixePhoto_cadastrale: 'Photo cadastrale',
        prefixePhoto_facade: 'Photo façade maison',
        prefixePhoto_chaudiere: 'Photo chaudière _ plaque signalétique',
        prefixePhoto_contratEnergie: "Contrat d'énergie",
        prefixePhoto_complementaires: 'Photo complémentaire',

        // Récapitulatif global des pièces jointes
        recapTitre: 'Documents joints',
        recapDocument: 'Document',
        recapType: 'Type',
        recapTaille: 'Taille',
        recapVide: 'Aucun document joint pour le moment.',
        uniteKo: 'Ko',
        uniteMo: 'Mo',

        // Date et créneau de rappel
        dateRappel: 'Date de Rappel Souhaitée',
        dateRappelFilleul: 'Date souhaitée pour le rappel du filleul',
        heureRappel: 'Heure de Disponibilité',
        heureRappelFilleul: 'Heure souhaitée pour le rappel du filleul',

        // Champs dynamiques
        detailsSupplementaires: 'Détails supplémentaires',

        // Informations d'appel (accès réduit)
        apporteurPresentation: 'De la part de qui devons-nous nous présenter ?',
        apporteurPresentationPh: 'Ex : de la part de votre voisin M. Dupont',
        clientPrevenu: 'Le client est-il déjà prévenu de notre appel ?',
        clientPrevenuAria: 'Le client est-il déjà prévenu de notre appel ?',
        clientRac: "Le client est-il informé qu'un reste à charge peut être applicable ?",
        clientRacAria: "Le client est-il informé qu'un reste à charge peut être applicable ?",

        // Commentaire
        commentaire: 'Commentaire',
        commentaireFilleul: 'Informations utiles pour notre conseiller',

        // Certification + soumission
        certification: "Je certifie avoir obtenu l'accord de ce contact pour transmettre ses coordonnées.",
        btnCreerRecommandation: 'Créer une recommandation',
        btnCreerRdv: 'Créer le RDV',
        btnCreationEnCours: 'Création en cours...',

        // Fichiers + succès
        fichiersSelectionnes: 'Fichiers sélectionnés',
        supprimerFichier: 'Supprimer le fichier',
        succesRdv: 'RDV créé avec succès!',

        // Messages de validation et toasts
        errNomSociete: 'Le nom la societé est requis',
        errNom: 'Le nom est requis',
        errPrenom: 'Le prénom est requis',
        errEmail: 'Un email valide est requis',
        errTelephone: 'Le numéro doit contenir 10 chiffres et commencer par 0',
        errAdresse: "L'adresse complète est requise",
        errDateRappel: 'La date de rappel souhaitée est requise',
        errHeureRappel: "L'heure de disponibilité est requise",
        errProduit: 'Veuillez sélectionner au moins un produit',
        errCommentaireLong: 'Le commentaire ne peut pas dépasser 255 caractères',
        errTailleFichiers: 'La taille totale des fichiers ({taille} Mo) dépasse la limite de {max} Mo. Supprimez un fichier avant de créer le RDV.',
        errChampRequis: 'Le champ "{champ}" est requis',
        errCertification: "Vous devez certifier avoir obtenu l'accord du contact pour transmettre ses coordonnées.",
        succesRdvToast: 'RDV créé avec succès !',
        errDoublonApporteur: "Malheureusement, votre dossier est déjà présent dans notre base de données sous le nom d'un apporteur d'affaires différent.",
        errCreationPiste: 'Erreur lors de la création de la piste',

        // Libellés de typeProduit — la VALEUR reste française (filtrage + payload Apex)
        tp_Residentiel: 'Residentiel',
        tp_Tertiaire: 'Tertiaire',
        tp_Agriculture: 'Agriculture'
    },
    es: {
        chargementRegie: 'Cargando la REGIE...',
        regieIntrouvable: 'REGIE no encontrada',
        regieDesactivee: 'REGIE desactivada',
        regieDesactiveeMsg: 'Esta REGIE está desactivada actualmente. Póngase en contacto con el gestor de la REGIE para activarla.',

        cahierDesCharges: 'Pliego de condiciones',
        demandezCdc: 'Solicite su pliego',
        disponible: 'Disponible',
        nonDispo: 'No disponible',
        afficherProduits: 'Mostrar los productos',
        masquerProduits: 'Ocultar los productos',

        titreCreerRdv: 'Crear una nueva cita',
        typeRdv: 'Tipo de cita:',
        choisirProduits: 'Elija uno o varios productos',

        nomSociete: 'Nombre de la empresa',
        nomSocietePh: 'Ej.: ABC S.L.',
        // En espagnol « Nombre » = prénom et « Apellidos » = nom de famille :
        // l'inversion est volontaire, ce n'est pas une erreur de correspondance.
        nomClient: 'Apellidos del cliente',
        nomClientFilleul: 'Apellidos del referido',
        nomClientPh: 'Ej.: García',
        prenom: 'Nombre',
        prenomFilleul: 'Nombre del referido',
        prenomPh: 'Ej.: Juan',
        email: 'Correo electrónico',
        emailFilleul: 'Correo electrónico del referido',
        emailPh: 'juan@ejemplo.com',
        telephone: 'Teléfono',
        telephoneFilleul: 'Teléfono del referido',
        telephonePh: '0612345678',

        adresse: 'Dirección',
        adressePh: 'Calle Mayor 1, 28013 Madrid',

        // --- Champs de la fiche RES060 ----------------------------------------
        // « Zona climática » : E1/D1/C1... sont les zones du Código Técnico de la
        //   Edificación (CTE) — les valeurs ne se traduisent pas.
        // « Referencia catastral » : on saisit l'identifiant de 20 caractères du
        //   Catastro, pas une parcelle — « parcela catastral » serait un contresens.
        // « Superficie útil » : terme légal espagnol de la surface habitable, par
        //   opposition à « superficie construida » (qui inclut murs et communs).
        sectionLogement: 'La vivienda',
        df_RES_Zone_ES__c: 'Zona climática (CTE)',
        df_Parcelle_Cadastrale__c: 'Referencia catastral',
        df_RES_Anne_maison__c: 'Año de construcción',
        df_Surface_habitable__c: 'Superficie útil (m²)',
        df_Type_de_Chauffage__c: 'Tipo de calefacción',
        df_RES_Ann_e_Chaudi_re__c: 'Año de la caldera',
        // « Suivi Signature » : qui pilote la signature du devis. La valeur choisie
        //   conditionne l'affichage de la date et du créneau de rappel.
        df_Suivi_Signature__c: 'Seguimiento de la firma',
        df_RES_Anne_maison__cPh: 'Ej.: 1985',
        df_RES_Ann_e_Chaudi_re__cPh: 'Ej.: 2010',
        df_Surface_habitable__cPh: 'Ej.: 120',
        df_Parcelle_Cadastrale__cPh: 'Ej.: 9872023VH5797S0001WX',

        // --- Sections de photos ------------------------------------------------
        photoCadastrale: 'Foto catastral',
        photoFacade: 'Foto de la fachada',
        photoChaudiere: 'Foto de la caldera + placa de características',
        photoContratEnergie: 'Contrato de energía',
        photoComplementaires: 'Fotos complementarias',

        recapTitre: 'Documentos adjuntos',
        recapDocument: 'Documento',
        recapType: 'Tipo',
        recapTaille: 'Tamaño',
        recapVide: 'Todavía no hay documentos adjuntos.',
        uniteKo: 'KB',
        uniteMo: 'MB',

        // --- Valeurs de Type_de_Chauffage__c (clé = valeur d'API, émoji compris) --
        // « Biomasa » plutôt que « Leña » : terme employé dans la classification
        // énergétique espagnole. « Bomba de calor aire-agua » = aerotermia.
        'pl_⛽Fioul': '⛽Gasóleo',
        'pl_♨️Gaz': '♨️Gas',
        'pl_🪵Bois': '🪵Biomasa',
        'pl_⚡PAC Air/Eau': '⚡Bomba de calor aire-agua',
        'pl_⚡Electricité': '⚡Electricidad',


        dateRappel: 'Fecha de llamada deseada',
        dateRappelFilleul: 'Fecha deseada para llamar al referido',
        heureRappel: 'Franja horaria disponible',
        heureRappelFilleul: 'Franja horaria deseada para llamar al referido',

        detailsSupplementaires: 'Datos adicionales',

        apporteurPresentation: '¿De parte de quién debemos presentarnos?',
        apporteurPresentationPh: 'Ej.: de parte de su vecino, el Sr. García',
        clientPrevenu: '¿El cliente ya está avisado de nuestra llamada?',
        clientPrevenuAria: '¿El cliente ya está avisado de nuestra llamada?',
        clientRac: '¿El cliente sabe que puede haber un coste a su cargo?',
        clientRacAria: '¿El cliente sabe que puede haber un coste a su cargo?',

        commentaire: 'Comentario',
        commentaireFilleul: 'Información útil para nuestro asesor',

        certification: 'Certifico que he obtenido el consentimiento de este contacto para facilitar sus datos.',
        btnCreerRecommandation: 'Crear una recomendación',
        btnCreerRdv: 'Crear la cita',
        btnCreationEnCours: 'Creando...',

        fichiersSelectionnes: 'Archivos seleccionados',
        supprimerFichier: 'Eliminar el archivo',
        succesRdv: '¡Cita creada correctamente!',

        errNomSociete: 'El nombre de la empresa es obligatorio',
        errNom: 'Los apellidos son obligatorios',
        errPrenom: 'El nombre es obligatorio',
        errEmail: 'Se requiere un correo electrónico válido',
        errTelephone: 'El número debe tener 10 dígitos y empezar por 0',
        errAdresse: 'La dirección completa es obligatoria',
        errDateRappel: 'La fecha de llamada deseada es obligatoria',
        errHeureRappel: 'La franja horaria disponible es obligatoria',
        errProduit: 'Seleccione al menos un producto',
        errCommentaireLong: 'El comentario no puede superar los 255 caracteres',
        errTailleFichiers: 'El tamaño total de los archivos ({taille} MB) supera el límite de {max} MB. Elimine un archivo antes de crear la cita.',
        errChampRequis: 'El campo «{champ}» es obligatorio',
        errCertification: 'Debe certificar que ha obtenido el consentimiento del contacto para facilitar sus datos.',
        succesRdvToast: '¡Cita creada correctamente!',
        errDoublonApporteur: 'Lamentablemente, su expediente ya figura en nuestra base de datos a nombre de otro prescriptor.',
        errCreationPiste: 'Error al crear el cliente potencial',

        tp_Residentiel: 'Residencial',
        tp_Tertiaire: 'Terciario',
        tp_Agriculture: 'Agricultura',

        // --- Surcharge des picklists de l'org ---------------------------------
        // getFieldsMetadata renvoie les libellés dans la langue de l'utilisateur
        // portail (français) : le toggle ne peut pas les changer. On surcharge
        // donc les seules valeurs réellement affichées, en clé = VALEUR D'API.
        // Attention : pour 2 créneaux la valeur diffère du libellé
        // (« MATIN (10H-15H) » porte le libellé « MATIN (10H-13H) »).
        'pl_LE PLUS VITE POSSIBLE': 'LO ANTES POSIBLE',
        'pl_MATIN (10H-15H)': 'MAÑANA (10H-13H)',
        'pl_SOIR (15H- 19H30)': 'TARDE (14H-19H30)',
        pl_Oui: 'Sí',
        pl_Non: 'No',
        // Les clés sont les VALEURS D'API, recopiées caractère pour caractère
        // (faute « gére » comprise). Seul l'affichage est traduit : la valeur
        // envoyée à Salesforce reste en français.
        'pl_Vous gérez la signature- On confirme une fois signé (Tx Conversion+++)':
            'Usted gestiona la firma — nosotros confirmamos una vez firmada (Tx Conversión+++)',
        'pl_On gére la signature + Confirmation (Tx Conversion+)':
            'Nosotros gestionamos la firma + confirmación (Tx Conversión+)'
    }
};