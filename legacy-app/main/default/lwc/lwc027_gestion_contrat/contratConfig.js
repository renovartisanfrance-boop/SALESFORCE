/**
 * contratConfig — TOUTE la configuration du contrat de prévisiteur.
 *
 * C'est le SEUL fichier à ouvrir pour :
 *   • ajouter / retirer / réordonner un champ du formulaire,
 *   • corriger une coordonnée de dessin sur le PDF,
 *   • déplacer une zone de signature,
 *   • brancher un nouveau statut de contrat.
 *
 * Module JS pur, sans template : il n'est pas exposé et ne peut pas être posé
 * dans Experience Builder — même motif que devisConfig dans lwc021_devis_signature.
 *
 * OÙ VIVENT LES RÉGLAGES — même partage que pour le devis :
 *
 *   • Les COORDONNÉES DE DESSIN servent dans le navigateur : c'est pdf-lib qui
 *     écrit les valeurs sur le PDF.
 *
 *   • Les RÉGLAGES YOUSIGN (langue, expéditeur, position du champ de signature)
 *     sont déclarés ici et TRANSMIS à l'Apex, qui les applique via
 *     YS_YousignService.appliquerReglages(). La forme de l'objet rendu par
 *     reglagesContrat() est celle de lwc000_utils.reglagesSignature(), pour que
 *     l'Apex le consomme sans distinguer son origine.
 *
 *     ⚠️ CE FICHIER EST LA SEULE SOURCE — il n'y a PAS de repli sur les Custom
 *     Labels. LC027_GestionContrat REFUSE l'envoi si un réglage manque, au lieu
 *     de retomber sur YOUSIGN_CHAMP_SIGNATURE. Ce label vaut « 1|140|700|249|40 »
 *     (page 1) et n'est PLUS utilisé par personne : le devis passe désormais la
 *     position de chaque fiche par reglagesSignature(). C'est donc une valeur
 *     morte, que plus aucun flux ne tient à jour — y retomber ferait signer le
 *     contrat au milieu de sa première page. Un envoi refusé se corrige, un
 *     contrat mal signé non.
 *
 *     Seuls YOUSIGN_API_ENDPOINT et YOUSIGN_API_TOKEN (et le secret du webhook)
 *     restent des labels : coordonnées de service communes à toutes les
 *     intégrations, elles n'ont pas leur place dans une config par document.
 *
 * POURQUOI ICI ET NON DANS lwc000_utils — les réglages de signature des devis y
 * vivent parce qu'ils dépendent de la FICHE PRODUIT (PRODUCT_CATALOG), et qu'une
 * même fiche peut porter plusieurs gabarits selon des conditions. Le contrat de
 * prévisiteur ne dépend d'aucun produit : un seul document, un seul gabarit, lié
 * à la Campagne. L'ajouter au catalogue produits l'aurait rendu dépendant d'une
 * arborescence qui ne le concerne pas.
 */

/* ═══════════════════════════════════════════════════════════════════════════
   STATUTS DE CONTRAT — Campaign.StatutContrat__c

   Picklist RESTREINTE : ces trois chaînes sont les valeurs d'API réelles, pas
   les libellés affichés (« En cours de génération », « Signé »). Le composant
   décide sur ces valeurs, jamais sur le texte traduit.

   VIDE est un quatrième état légitime : une campagne de rôle Régie n'a pas de
   contrat. Le conteneur ne doit alors rien afficher de contractuel.
   ═══════════════════════════════════════════════════════════════════════════ */

export const STATUT_GENERATION        = 'En cours de generation';
export const STATUT_ATTENTE_SIGNATURE = 'Attente signature';
export const STATUT_SIGNE             = 'Signe';

/** Le contrat verrouille le portail tant qu'il n'est pas signé. */
export function contratBloquant(statut) {
    return statut === STATUT_GENERATION || statut === STATUT_ATTENTE_SIGNATURE;
}

/* ═══════════════════════════════════════════════════════════════════════════
   FORMULAIRE — les 9 informations du contrat

   `champ`    : nom d'API RÉEL sur Campaign (vérifié sur l'org).
   `label`    : libellé espagnol, tel qu'imprimé dans le contrat.
   `type`     : type d'input HTML, 'picklist' ou 'badges' (multipicklist).
   `requis`   : bloque l'envoi en signature si vide.
   `pleineLargeur` : le champ occupe les deux colonnes de la grille.
   `pays`     : (facultatif) valeurs de Campaign.Pays__c pour lesquelles le champ
                s'affiche. Absent = tous les pays. Miroir serveur :
                LC027_Roles.PAYS_PAR_CHAMP.

   NOM et EMAIL/TÉLÉPHONE ne sont PAS des champs dédiés :
   `Name` porte déjà « nom prénom » (posé par PrevisiteController à l'inscription),
   `Email__c` et `Telephone__c` existaient déjà sur Campaign. Créer des doublons
   aurait fait diverger les deux jeux de valeurs dès la première correction.
   ═══════════════════════════════════════════════════════════════════════════ */

/* ═══════════════════════════════════════════════════════════════════════════
   RÔLES — valeurs EXACTES de Campaign.Role__c
   ═══════════════════════════════════════════════════════════════════════════ */

export const ROLE_PREVISITEUR  = 'Pre-visiteur';
export const ROLE_INSTALLATEUR = 'Installateur';

/**
 * CATALOGUE de toutes les définitions de champ du formulaire.
 *
 * Il ne dit PAS qui voit quoi : c'est CHAMPS_PAR_ROLE, plus bas, qui compose le
 * formulaire de chaque rôle en piochant ici par nom d'API. Un champ se décrit
 * donc une seule fois, même s'il sert à plusieurs rôles.
 */
export const DEFINITIONS_CHAMPS = [
    { champ: 'Name',                  label: 'Nombre y apellidos o denominación', type: 'text',  requis: true },
    { champ: 'Contrat_Profession__c', label: 'Profesión o actividad',             type: 'text',  requis: true },
    { champ: 'Contrat_Situation__c',  label: 'Situación',                         type: 'picklist', requis: true,
      options: [
          { valeur: 'Autonomo',    label: 'Autónomo' },
          { valeur: 'Sociedad SL', label: 'Sociedad S.L.' }
      ] },
    { champ: 'Contrat_NIF__c',        label: 'NIF (DNI / NIE)',                   type: 'text',  requis: true },
    { champ: 'Contrat_Adresse__c',    label: 'Domicilio fiscal',                  type: 'text',  requis: true, pleineLargeur: true },
    { champ: 'Contrat_CodePostal__c', label: 'Código postal',                     type: 'text',  requis: true },
    { champ: 'Contrat_Ville__c',      label: 'Localidad',                         type: 'text',  requis: true },
    { champ: 'Telephone__c',          label: 'Teléfono',                          type: 'tel',   requis: true },
    { champ: 'Email__c',              label: 'Correo electrónico',                type: 'email', requis: true },
    /**
     * Nombre de prévisites par semaine — prévisiteurs ESPAGNOLS uniquement.
     * Valeurs d'API en français (picklist restreinte), libellés espagnols.
     */
    { champ: 'NombrePrevisites__c', label: '¿Cuántas previsitas puedes hacer a la semana?',
      type: 'picklist', requis: true, pays: ['Espagne'],
      options: [
          { valeur: '1 à 5',      label: '1 a 5' },
          { valeur: '6 à 10',     label: '6 a 10' },
          { valeur: '11 à 20',    label: '11 a 20' },
          { valeur: 'Plus de 20', label: 'Más de 20' }
      ] },
    /**
     * Provinces — BADGES sélectionnables (multipicklist Contrat_Provinces__c).
     *
     * 27 valeurs, dont plusieurs à cocher : une liste déroulante multiple
     * imposerait un Ctrl+clic impraticable au doigt, et 27 cases prendraient un
     * écran entier. Les badges compacts se lisent d'un coup d'œil et se
     * sélectionnent d'un tap.
     *
     * ⚠️ Les VALEURS doivent être exactement celles de la picklist (accents,
     * « / », parenthèses compris) : c'est une liste restreinte. L'ordre ici est
     * celui de la picklist — alphabétique espagnol — et donc celui du stockage.
     */
    { champ: 'Contrat_Provinces__c', label: 'Provincias', type: 'badges', requis: true,
      pleineLargeur: true,
      options: [
          'Albacete', 'Araba/Álava', 'Asturias', 'Ávila', 'Burgos', 'Ciudad Real',
          'Cuenca', 'Gipuzkoa', 'Girona', 'Guadalajara', 'Huesca', 'León', 'Lleida',
          'Lugo', 'Madrid', 'Navarra', 'Ourense', 'Palencia', 'Rioja (La)',
          'Salamanca', 'Segovia', 'Soria', 'Teruel', 'Toledo', 'Valladolid',
          'Zamora', 'Zaragoza'
      ].map((p) => ({ valeur: p, label: p })) }
];

/**
 * ═══ CHAMPS PAR RÔLE — LA table à modifier ═══════════════════════════════════
 *
 * Pour AJOUTER un champ à un rôle : son nom d'API dans la liste du rôle (et sa
 * définition dans DEFINITIONS_CHAMPS s'il est nouveau). Pour le RETIRER : on
 * l'enlève de la liste. L'ORDRE de la liste est l'ordre d'affichage.
 *
 * ⚠️ MIROIR SERVEUR — LC027_Roles.CHAMPS_PAR_ROLE porte la même table pour le
 * DROIT D'ÉCRITURE. Un champ ajouté ici mais pas là-bas s'affichera, et son
 * enregistrement sera ignoré sans erreur. Les deux se modifient ensemble.
 *
 * L'installateur reprend pour l'instant exactement les champs du prévisiteur.
 * Les listes sont déjà séparées : le jour où elles divergent, modifier l'une ne
 * touche pas l'autre.
 */
export const CHAMPS_PAR_ROLE = {
    [ROLE_PREVISITEUR]: [
        'Name',
        'Contrat_Profession__c',
        'Contrat_Situation__c',
        'Contrat_NIF__c',
        'Contrat_Adresse__c',
        'Contrat_CodePostal__c',
        'Contrat_Ville__c',
        'Telephone__c',
        'Email__c',
        'NombrePrevisites__c',
        'Contrat_Provinces__c'
    ],
    [ROLE_INSTALLATEUR]: [
        'Name',
        'Contrat_Profession__c',
        'Contrat_Situation__c',
        'Contrat_NIF__c',
        'Contrat_Adresse__c',
        'Contrat_CodePostal__c',
        'Contrat_Ville__c',
        'Telephone__c',
        'Email__c',
        'Contrat_Provinces__c'
    ]
};

/**
 * Définitions ordonnées des champs du formulaire de ce rôle.
 *
 * Un rôle inconnu rend un formulaire VIDE plutôt que celui d'un autre rôle :
 * afficher les champs du prévisiteur à un rôle non prévu ferait croire qu'ils
 * sont enregistrables, alors que la liste blanche serveur les refuserait.
 * Un nom d'API sans définition est ignoré, pour qu'une faute de frappe dans la
 * table ne casse pas tout l'écran.
 */
export function champsFormulaire(role, pays) {
    const ids = CHAMPS_PAR_ROLE[role] || [];
    return ids
        .map((id) => DEFINITIONS_CHAMPS.find((d) => d.champ === id))
        .filter(Boolean)
        // Champ réservé à certains pays : masqué ailleurs (voir clé `pays`).
        .filter((d) => !d.pays || d.pays.includes(pays));
}

/** Séparateur des multipicklists Salesforce. */
export const SEPARATEUR_MULTI = ';';

/** Noms d'API du formulaire de ce rôle — dérivés de la table, jamais recopiés. */
export function champsDemandes(role, pays) {
    return champsFormulaire(role, pays).map((c) => c.champ);
}

/**
 * Récapitulatif LISIBLE des informations saisies, pour ce rôle.
 *
 * Seule construction du récap : la relecture avant envoi (lwc027_gestion_contrat)
 * et l'accueil verrouillé (lwc027_gestion_previsite / _installations) l'appellent
 * toutes deux, pour qu'un intervenant relise EXACTEMENT les mêmes libellés et
 * valeurs aux deux endroits.
 *
 * @param role      Campaign.Role__c
 * @param donnees   valeurs par nom d'API (EtatContrat.donnees)
 * @param txtContrat étiquettes de l'écran « contrat » (clés champ_<API>) ; le
 *                  libellé espagnol de la configuration sert de repli.
 * @param pays      Campaign.Pays__c — masque les champs réservés à un autre pays.
 * @returns [{ champ, label, valeur }] — les champs VIDES sont omis.
 */
export function lignesRecap(role, donnees, txtContrat, pays) {
    const d = donnees || {};
    const txt = txtContrat || {};
    return champsFormulaire(role, pays)
        .map((c) => {
            const brut = d[c.champ];
            let valeur = brut ? String(brut) : '';
            if (valeur && c.type === 'picklist') {
                // Le LIBELLÉ, pas la valeur d'API : « Autónomo », pas « Autonomo ».
                valeur = (c.options || []).find((o) => o.valeur === valeur)?.label || valeur;
            } else if (valeur && c.type === 'badges') {
                // Multipicklist relue en liste : « Burgos, Madrid ».
                valeur = valeur.split(SEPARATEUR_MULTI).filter((v) => v).join(', ');
            }
            return { champ: c.champ, label: txt['champ_' + c.champ] || c.label, valeur };
        })
        .filter((l) => l.valeur);
}

/* ═══════════════════════════════════════════════════════════════════════════
   PDF — géométrie du contrat

   Static Resource `contrat_previsiteur` : contrat V2.0, 9 pages A4 (595,92 ×
   842,88 pt),
   PDF PLAT généré par Chrome (Skia/PDF), **sans aucun champ AcroForm** — même
   nature que `cae_colab_contrat` du devis. Les valeurs ne peuvent donc pas être
   « remplies » : elles sont DESSINÉES aux coordonnées ci-dessous.

   Repère : celui de pdf-lib, origine en BAS À GAUCHE, unité = point PDF.
   Les valeurs viennent des flux du PDF réel (positions de texte relevées après
   application de la matrice de transformation), pas d'une mesure à l'œil.
   ═══════════════════════════════════════════════════════════════════════════ */

export const PDF_RESOURCE_NAME = 'contrat_previsiteur';

export const PDF_LARGEUR = 595.92;
export const PDF_HAUTEUR = 842.88;

/** Page portant le bloc d'identification du technicien (index 0 = page 1). */
export const PDF_PAGE_IDENTITE = 0;

/**
 * Colonne des valeurs. Relevée sur le bloc ECONATURA de la page 1, qui a
 * exactement la même structure libellé / valeur que le bloc du technicien juste
 * en dessous — c'est ce qui garantit l'alignement visuel des deux blocs.
 */
export const PDF_X_VALEUR = 196.6;

/**
 * Ordonnée de chaque valeur, à la ligne de base de son libellé.
 *
 * Le décalage de 0,8 pt sous le libellé reproduit celui observé entre libellé et
 * valeur dans le bloc ECONATURA (592,4 contre 591,6).
 *
 * PIÈGE : le contrat n'a qu'UNE ligne « Código postal y localidad ». Code postal
 * et localité y sont donc écrits ensemble (voir valeurLigne), alors qu'ils sont
 * saisis séparément dans le formulaire.
 */
/*
 * Les ZONES ne figurent pas ici : le contrat imprimé n'a pas de ligne pour
 * elles. Le champ sert à l'affectation des prévisites, pas à l'engagement
 * contractuel — l'ajouter au PDF supposerait une nouvelle version du document.
 */
export const PDF_LIGNES = {
    Name:                  452.8,
    Contrat_Profession__c: 422.8,
    Contrat_Situation__c:  404.8,
    Contrat_NIF__c:        386.1,
    Contrat_Adresse__c:    368.1,
    CP_VILLE:              350.1,
    Telephone__c:          332.1,
    Email__c:              314.1
};

export const PDF_TAILLE_POLICE = 9;
export const PDF_COULEUR_TEXTE = { r: 0.09, g: 0.13, b: 0.35 };

/**
 * Valeur à imprimer sur une ligne du PDF. Centralise les deux cas particuliers :
 * la ligne fusionnée code postal + localité, et la picklist Situación dont on
 * imprime le LIBELLÉ espagnol (« Autónomo »), pas la valeur d'API (« Autonomo »).
 */
export function valeurLigne(cle, donnees) {
    if (cle === 'CP_VILLE') {
        return [donnees.Contrat_CodePostal__c, donnees.Contrat_Ville__c]
            .filter(Boolean).join(' ');
    }
    if (cle === 'Contrat_Situation__c') {
        const def = DEFINITIONS_CHAMPS.find((c) => c.champ === 'Contrat_Situation__c');
        const opt = def?.options?.find((o) => o.valeur === donnees.Contrat_Situation__c);
        return opt ? opt.label : (donnees.Contrat_Situation__c || '');
    }
    return donnees[cle] || '';
}

/* ═══════════════════════════════════════════════════════════════════════════
   ZONES DE SIGNATURE — repère seulement, la vérité est côté Apex

   Le contrat porte DEUX blocs « Leído y conforme – Firma » :
   l'un page 6 (fin du contrat), l'autre page 10 (Anexo 5 — accord de
   sous-traitance, que la clause 11.2 dit signé « simultáneamente con el presente
   contrato, del que forma parte integrante y sin el cual el contrato no producirá
   efectos »). Ne signer que la page 6 laisse donc l'annexe non signée.

   Format attendu par le label : « page|x|y|largeur|hauteur », page en base 1 et
   origine en HAUT à gauche (convention Yousign), à l'inverse du repère pdf-lib
   utilisé plus haut. D'où versReperePdf() ci-dessous pour passer de l'un à l'autre.
   ═══════════════════════════════════════════════════════════════════════════ */

/**
 * Réglages de signature du contrat.
 *
 * MÊME FORME que le bloc `signature` d'une fiche dans lwc000_utils
 * (PRODUCT_CATALOG[...].signature) : `langue`, `expediteur`, puis un gabarit
 * portant `contratRessource`, `champSignature`, `champMention`. C'est ce qui
 * permet à reglagesContrat() de rendre le même objet que reglagesSignature() et
 * à YS_YousignService.appliquerReglages() de le consommer tel quel.
 *
 * `langue: 'es'` — le contrat et son signataire sont espagnols. Comme pour les
 * devis, la langue est celle du SIGNATAIRE, pas celle du portail : un opérateur
 * qui basculerait son écran en français ne doit pas envoyer un email français à
 * un technicien espagnol.
 *
 * `expediteur: 'ECONATURA'` — le contrat est conclu avec ECONATURA Energía
 * Renovable S.L., pas avec RENOV ARTISAN. Le compte Yousign étant PARTAGÉ entre
 * projets, ce nom doit être posé par requête et jamais dans le compte lui-même.
 *
 * `champMention: null` — le contrat imprime déjà « Leído y conforme – Firma » à
 * côté de la zone de signature. Ajouter une mention Yousign superposerait deux
 * fois la même formule.
 */
export const CONTRAT_SIGNATURE = Object.freeze({
    statut: true,
    langue: 'es',
    expediteur: 'ECONATURA',
    contratRessource: PDF_RESOURCE_NAME,

    /**
     * Zone de signature et zone de mention, repère Yousign :
     * « page|x|y|largeur|hauteur », page en base 1 et origine en HAUT à gauche —
     * l'inverse du repère pdf-lib utilisé pour le dessin plus haut. D'où
     * versReperePdf().
     *
     * PAGE 9 (contrat V2.0, 9 pages). Le bloc de signature y occupe la colonne
     * DROITE, sous l'intitulé « EL TÉCNICO » :
     *   • « EL TÉCNICO »               X=320,8  Y=277,4 (repère PDF)
     *   • TRAIT de signature           X=321,0 → 553,5  Y=199,4 (épaisseur 0,70)
     *   • « El Técnico · Encargado… »  X=320,8  Y=186,6
     *
     * ⚠️ LE TRAIT EST LA CONTRAINTE BASSE, et il ne se voit pas dans le texte
     * extrait : c'est un rectangle plein, relevé dans les opérateurs graphiques
     * du PDF. Un premier réglage l'ignorait et les deux signatures le
     * chevauchaient — elles semblaient « mal alignées » alors qu'elles
     * débordaient simplement sous la ligne.
     *
     * Bande réellement disponible : Y 200,1 (haut du trait) à 277,4 (intitulé),
     * soit 77 pt. Elle est partagée ainsi, du bas vers le haut :
     *   signature  PDF Y 204,9 → 244,9   (4,8 pt au-dessus du trait)
     *   mention    PDF Y 248,9 → 270,9   (6,5 pt sous l'intitulé)
     * L'ordre mention-au-dessus / signature-en-dessous est celui d'un paraphe.
     */
    champMention:   '9|321|572|233|22',
    champSignature: '9|321|598|233|40'
});

/*
 * TEXTE DE LA MENTION — il ne se règle PAS ici.
 *
 * YS_YousignService choisit lui-même entre les étiquettes YOUSIGN_MENTION_ES et
 * YOUSIGN_MENTION_FR selon la langue du SIGNATAIRE, et Yousign y remplace
 * « %date% » à la signature. L'étiquette espagnole vaut déjà exactement ce
 * qu'il faut : « Conforme y aceptado %date% ».
 *
 * Ce fichier ne fournit donc que la POSITION (champMention ci-dessus). Y
 * recopier le texte aurait créé un réglage mort, jamais lu, que quelqu'un
 * aurait fini par modifier en croyant agir sur le document.
 *
 * En API v3 la mention est un CHAMP À PART ENTIÈRE, pas une propriété du champ
 * de signature (elle l'était en v2) : d'où deux positions distinctes.
 * « DESACTIVE » dans YOUSIGN_CHAMP_MENTION supprime la mention sans toucher au code.
 */

/* ═══════════════════════════════════════════════════════════════════════════
   SIGNATURE ECONATURA — apposée AVANT l'envoi, pas demandée à Yousign

   Yousign ne sait pas « pré-signer » un document au nom de l'émetteur : une
   demande de signature s'adresse à des SIGNATAIRES, qui doivent tous agir.
   Ajouter ECONATURA comme second signataire obligerait un administrateur à
   signer chaque contrat à la main — l'inverse d'une signature par défaut.

   La signature d'ECONATURA est donc DESSINÉE sur le PDF par pdf-lib, dans la
   colonne gauche de la page 9, juste avant l'envoi. Le technicien reçoit ainsi
   un document déjà paraphé par la société et n'a plus qu'à signer sa colonne.

   ⚠️ PORTÉE JURIDIQUE — c'est un fac-similé, pas une signature électronique :
   il n'a pas la valeur probante de la signature Yousign du technicien. C'est
   l'usage courant pour la partie émettrice d'un contrat d'adhésion, mais la
   décision appartient au métier.

   La ressource est FACULTATIVE : absente, rien n'est apposé et l'envoi se
   poursuit. Le contrat part alors sans paraphe côté ECONATURA plutôt que
   d'échouer — un envoi bloqué serait un défaut plus grave qu'un paraphe absent.
   ═══════════════════════════════════════════════════════════════════════════ */

export const SIGNATURE_ECONATURA = Object.freeze({
    /** Static Resource JPEG (fond blanc, se fond dans la page). */
    ressource: 'signature_econatura',
    /**
     * Index de page pdf-lib : 8 = page 9, la DERNIÈRE du contrat V2.0.
     * À réviser si le contrat change de pagination — c'est la seule valeur de
     * ce fichier qui dépend du nombre total de pages.
     */
    page: 8,
    /**
     * Colonne GAUCHE (« POR ECONATURA », X=42,7), dans la bande libre entre
     * l'intitulé (Y=277,4) et la ligne de noms (Y=186,6). Repère pdf-lib,
     * origine en bas à gauche.
     *
     * ⚠️ MÊME CONTRAINTE QUE LA COLONNE DROITE : un trait de signature court de
     * X=42,7 à X=275,2 à Y=199,4. L'image doit rester AU-DESSUS. Un premier
     * réglage la posait à y=198, elle chevauchait donc la ligne.
     * Elle occupe désormais Y 205 → 265, soit 4,9 pt au-dessus du trait.
     *
     * La bande ne fait que ~77 pt de haut, et l'image 656 x 382 px a un rapport
     * de 1,72 : c'est donc la HAUTEUR qui contraint, pas la largeur (60 pt de
     * haut donnent ~103 pt de large). Le dessin utilise scaleToFit, qui préserve
     * le rapport — fixer les deux dimensions aurait déformé le trait.
     */
    x: 60,
    y: 205,
    largeurMax: 190,
    hauteurMax: 60
});

/**
 * Réglages à transmettre à l'Apex, dans la forme attendue par
 * YS_YousignService.appliquerReglages(). Les clés absentes retombent sur les
 * Custom Labels YOUSIGN_* — c'est le repli, pas l'inverse.
 */
export function reglagesContrat() {
    return {
        langue: CONTRAT_SIGNATURE.langue,
        expediteur: CONTRAT_SIGNATURE.expediteur,
        champSignature: CONTRAT_SIGNATURE.champSignature,
        champMention: CONTRAT_SIGNATURE.champMention
    };
}

/** Repère Yousign (haut-gauche, page base 1) -> repère pdf-lib (bas-gauche, page base 0). */
export function versReperePdf(page, yYousign) {
    return { page: page - 1, y: PDF_HAUTEUR - yYousign };
}

/* ═══════════════════════════════════════════════════════════════════════════
   CHARGEMENT DU PDF — contraintes du site LWR

   Ne JAMAIS revenir à un fetch() direct de la Static Resource : dans un site
   Experience Cloud LWR, Lightning Web Security bloque tout fetch vers
   /webruntime/org-asset/... (« Cannot request disallowed endpoint »). loadScript
   passe, fetch non. Les octets du contrat sont donc livrés en base64 par l'Apex.

   Même contrainte pour l'aperçu : toutes les voies iframe sont fermées sur ce
   type de site (blob: refusé par frame-src, Apex REST non routé, Content-
   Disposition: attachment sur les URL de fichiers). L'aperçu se fait par rendu
   pdf.js sur un <canvas>, worker chargé sur le thread principal.
   ═══════════════════════════════════════════════════════════════════════════ */

export const RESSOURCES_PDF = Object.freeze({
    pdfLib:      'pdfLib',
    pdfJs:       'pdfJs',
    pdfJsWorker: 'pdfJsWorker'
});

export function base64VersOctets(base64) {
    const binaire = atob(base64);
    const octets = new Uint8Array(binaire.length);
    for (let i = 0; i < binaire.length; i++) {
        octets[i] = binaire.charCodeAt(i);
    }
    return octets;
}

export function octetsVersBase64(octets) {
    let binaire = '';
    const tranche = 0x8000; // par blocs : String.fromCharCode sature au-delà
    for (let i = 0; i < octets.length; i += tranche) {
        binaire += String.fromCharCode.apply(null, octets.subarray(i, i + tranche));
    }
    return btoa(binaire);
}