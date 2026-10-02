/**
 * lwc000_utils — Module utilitaire partagé.
 *
 * PRODUCT_CATALOG : source unique du catalogue produits.
 * Utilisé par lwc020_NouveauRdv et lwc020_CahierCharges.
 * => Toute modification du catalogue se fait UNIQUEMENT ici.
 */

// CDC Master (avec prix — Rang 1, profil PORTAIL INTERNE)
import cdc_171_Master from '@salesforce/resourceUrl/CDC_171MasterRegie';
import cdc_174_Master from '@salesforce/resourceUrl/CDC_174MasterRegie';
import cdc_163_Master from '@salesforce/resourceUrl/CDC_163MasterRegie';
import cdc_179_Master from '@salesforce/resourceUrl/CDC_179MasterRegie';
import cdc_117_Master from '@salesforce/resourceUrl/CDC_117MasterRegie';
import cdc_119_Master from '@salesforce/resourceUrl/CDC_119MasterRegie';
import cdc_108_Master from '@salesforce/resourceUrl/CDC_108MasterRegie';
import cdc_168_Master from '@salesforce/resourceUrl/CDC_168MasterRegie';

// CDC Mini (sans prix — Rang 2)
import cdc_171_Mini from '@salesforce/resourceUrl/CDC_171MiniRegie';
import cdc_174_Mini from '@salesforce/resourceUrl/CDC_174MiniRegie';
import cdc_163_Mini from '@salesforce/resourceUrl/CDC_163MiniRegie';
import cdc_179_Mini from '@salesforce/resourceUrl/CDC_179MiniRegie';
import cdc_117_Mini from '@salesforce/resourceUrl/CDC_117MiniRegie';
import cdc_119_Mini from '@salesforce/resourceUrl/CDC_119MiniRegie';
import cdc_108_Mini from '@salesforce/resourceUrl/CDC_108MiniRegie';
import cdc_168_Mini from '@salesforce/resourceUrl/CDC_168MiniRegie';

// Gabarits contractuels envoyes a la signature — UN PAR DEVIS.
// ⚠️ L'import doit rester STATIQUE : `@salesforce/resourceUrl/<nom>` est resolu
// a la compilation, un nom calcule a l'execution ne fonctionnerait pas. C'est
// pourquoi chaque gabarit s'importe ici, comme les cahiers des charges, et se
// designe ensuite par variable dans la fiche.
import contrat_RES060 from '@salesforce/resourceUrl/cae_colab_contrat';
import contrat_TH168 from '@salesforce/resourceUrl/DEVIS_TH168';
import contrat_TH110_v1 from '@salesforce/resourceUrl/DEVIS_TH110_v1';
import contrat_TH110_v2 from '@salesforce/resourceUrl/DEVIS_TH110_v2';
import contrat_SE104 from '@salesforce/resourceUrl/DEVIS_SE104';

// CDC Partenaire (accès réduit — utilisateurs partenaires cee-apporteurs)
import cdc_171_Partenaire from '@salesforce/resourceUrl/CDC_171PartenaireRegie';

// RES060 (Espagne) — le cahier des charges existe en DEUX langues, servies selon
// la langue d'affichage du site (bouton FR/ES), pas selon le pays de la campagne.
// La bascule passe par le bloc i18n.es de la fiche, fusionné par traduireProduit().
//
// Master (rang 1) et Mini (rang 2) pointent aujourd'hui sur le MÊME document dans
// chaque langue : la distinction avec/sans prix n'existe pas encore pour cette
// fiche. Le jour où elle existera, il suffira de remplacer le fichier de la
// ressource concernée, sans toucher au code.
import cdc_RES060_Master from '@salesforce/resourceUrl/CDC_RES060MasterRegie';
import cdc_RES060_Mini from '@salesforce/resourceUrl/CDC_RES060MiniRegie';
import cdc_RES060_Master_ES from '@salesforce/resourceUrl/CDC_RES060MasterRegieES';
import cdc_RES060_Mini_ES from '@salesforce/resourceUrl/CDC_RES060MiniRegieES';
// Catalogue : document UNIQUE, identique dans les deux langues — donc absent de
// i18n.es, volontairement.
import cat_RES060 from '@salesforce/resourceUrl/CDC_RES060_Catalogue';

// Catalogues — un seul lien par produit (peu importe le rang)
import cat_163 from '@salesforce/resourceUrl/CDC_163_Catalogue';
import cat_179 from '@salesforce/resourceUrl/CDC_179_Catalogue';
import cat_117 from '@salesforce/resourceUrl/CDC_117_Catalogue';
import cat_119 from '@salesforce/resourceUrl/CDC_119_Catalogue';
import cat_108 from '@salesforce/resourceUrl/CDC_108_Catalogue';

// Types d'enregistrement (RecordType)
export const RT_RES = 'RESIDENTIEL_REGIES';
export const RT_PRO = 'PRO_REGIES';
export const RT_AGRI = 'AA_AGRI_EXTERNE';
export const RT_TRA = 'TRA_Externe';

/**
 * Catalogue produits — source unique de vérité.
 * La disponibilité réelle est recalculée à l'exécution
 * (Campaign.ProduitsDisponibles__c) dans chaque composant.
 */
export const PRODUCT_CATALOG = {
    title: 'Produits disponibles',
    subtitle: '',
    produits: [
        {
            titre: 'Residentiel :',
            typeEnregistrement: RT_RES,
            typeProduit: 'Residentiel',
            nomProduit: 'TH171- Pompe à Chaleur Air/Eau',
            codeProduit: 'RESIDENTIEL_REGIES_-_TH171',
            couleurProduit: '#624FDE',
            disponible: true,
            description: '',
            cdcExiste: true,
            cdcMaster: cdc_171_Master,
            cdcMini: cdc_171_Mini,
            cdcPartenaire: cdc_171_Partenaire,
            ordreAffichage: 1,
            champsDisponibles: [],
            pays: ["France"]
        },
        {
            titre: 'Residentiel :',
            typeEnregistrement: RT_RES,
            typeProduit: 'Residentiel',
            nomProduit: 'TH174- Rénovation Globale',
            codeProduit: 'RESIDENTIEL_REGIES_-_TH174',
            couleurProduit: '#624FDE',
            disponible: false,
            description: '',
            cdcExiste: true,
            cdcMaster: cdc_174_Master,
            cdcMini: cdc_174_Mini,
            ordreAffichage: 2,
            champsDisponibles: [],
            pays: ["France"]
        },
        {
            titre: 'Residentiel :',
            typeEnregistrement: RT_RES,
            typeProduit: 'Residentiel',
            nomProduit: 'TH168- Solaire',
            codeProduit: 'RESIDENTIEL_REGIES_-_TH168',
            couleurProduit: '#624FDE',
            disponible: true,
            description: '',
            cdcExiste: true,
            cdcMaster: cdc_168_Master,
            cdcMini: cdc_168_Mini,
            ordreAffichage: 3,
            champsDisponibles: [],
            pays: ["France"],
            // -- Signature electronique ----------------------------------
            // Gabarit GREENWAY « Système solaire combiné + PAC », 3 pages.
            // Ce gabarit n'a ni cadre client ni bande de puissance : TOUT ce
            // qui s'imprime est declare dans `pdf.textes`, et les valeurs qui
            // ne sont dans aucun champ (capteurs, modele de PAC...) viennent
            // des regles de `calculs`. Voir devisConfig.evaluerCalculs().
            signature: {
                statut: true,
                lanceur: [],
                compteur: 'DEVIS-TH',
                // Client francais : l'email de signature part en francais, la
                // ou la 060 impose l'espagnol. C'est tout l'objet du reglage
                // par fiche.
                langue: 'fr',
                // Le gabarit est celui de GREENWAY : c'est ce nom que le client
                // doit lire dans l'email de signature, pas celui de la regie.
                expediteur: 'GREENWAY',

                // Champs de l'enregistrement qui DECIDENT du document. Ils sont
                // affiches sur le Recapitulatif, modifiables comme le nom ou
                // l'adresse, meme quand rien d'autre ne les y appelle : une
                // fiche sans cases de puissance perdrait sinon la surface.
                champsDecision: ['Surface_habitable__c'],

                // Champs propres a la fiche sur le Recapitulatif.
                //   Surface habitable | Surface de toiture
                //   Nombre de capteurs
                // Ils s'ajoutent A LA SUITE du formulaire, DANS L'ORDRE DE CETTE
                // LISTE. La surface habitable etant le dernier champ commun, la
                // toiture vient se ranger a sa droite, sur la meme rangee.
                // (`avant: '<champ>'` insererait un champ DEVANT un autre.)
                champsRecap: [
                    {
                        field: 'Surface_Toiture__c',
                        label: 'Surface de toiture (m²)',
                        editable: true,
                        type: 'number'
                    },
                    {
                        field: 'Nombre_Capteurs__c',
                        label: 'Nombre de capteurs',
                        editable: true,
                        type: 'picklist',
                        // Sur toute la largeur : la liste est seule sur sa
                        // rangee, et le message d'aide dessous a besoin de place.
                        pleineLargeur: true,
                        options: ['10', '12', '16', '20'],
                        // Valeur PROPOSEE par defaut : le resultat du calcul
                        // `capteurs`, selectionne dans la liste tant que
                        // l'utilisateur n'a rien choisi. Il peut le remplacer.
                        recommande: 'capteurs'
                    }
                ],

                // Regles de calcul. DEUX SURFACES, DEUX ROLES : la toiture
                // dimensionne le solaire, la surface habitable dimensionne la
                // pompe a chaleur. `maxExclu` rend les tranches jointives —
                // une surface de 23,5 m2 ne tombe dans aucun trou.
                // `libelle` nomme la donnee dans le message « hors tranches ».
                calculs: {
                    capteurs: {
                        champ: 'Surface_Toiture__c',
                        libelle: 'Surface de toiture',
                        choix: 'Nombre_Capteurs__c',
                        tranches: [
                            { min: 18, maxExclu: 24, valeur: '10' },
                            { min: 24, maxExclu: 33, valeur: '12' },
                            { min: 33, maxExclu: 41, valeur: '16' },
                            { min: 41, valeur: '20' }
                        ]
                    },
                    // Surface hors-tout installee, en m2, selon le nombre de
                    // capteurs RETENU (choix de l'utilisateur compris).
                    surfaceHorsTout: {
                        selon: 'capteurs',
                        table: { '10': '20,2', '12': '24,7', '16': '33', '20': '41,2' }
                    },
                    // Puissance de la PAC selon la surface habitable. Les bornes
                    // donnees se chevauchaient (101, 220) : elles sont tranchees
                    // ici, 101 -> 10 kW et 220 -> 16 kW.
                    puissancePac: {
                        champ: 'Surface_habitable__c',
                        libelle: 'Surface habitable',
                        tranches: [
                            { min: 60,  maxExclu: 102, valeur: '10' },
                            { min: 102, maxExclu: 131, valeur: '12' },
                            { min: 131, maxExclu: 161, valeur: '14' },
                            { min: 161, maxExclu: 221, valeur: '16' },
                            { min: 221, max: 300, valeur: '2x 14' }
                        ]
                    },
                    modelePac: {
                        selon: 'puissancePac',
                        table: {
                            '10': '80MT',
                            '12': '120 MT',
                            '14': '120 MT',
                            '16': '150 MT',
                            '2x 14': '2x 120 MT'
                        }
                    }
                },

                devis: [
                    {
                        cle: 'standard',
                        contratUrl: contrat_TH168,
                        contratRessource: 'DEVIS_TH168',
                        // Cadre pointille « Signature, date, cachet... » de la
                        // page 2, releve sur le gabarit : x 43-308, y 558-612.
                        // Mention au-dessus, signature en dessous.
                        //
                        // ⚠️ YOUSIGN EXIGE 37 pt DE HAUT AU MINIMUM pour un champ
                        // de signature (« fields[0].height : should be greater
                        // than or equal to 37 »). A 34, la demande etait refusee
                        // avec un simple « invalid params ». Les deux champs se
                        // partagent les 54 pt du cadre : 14 pour la mention,
                        // 37 pour la signature. Geometrie VALIDEE contre l'API.
                        champSignature: '2|47|575|256|37',
                        champMention: '2|47|560|256|14',
                        pdf: {
                            // Les valeurs s'impriment comme les donnees fixes du
                            // gabarit (« Chauffage et eau chaude sanitaire ») :
                            // gras, noir #222222, 9 pt. Le gabarit est compose en
                            // Liberation Sans, jumelle metrique d'Arial ; la
                            // police posee est Helvetica-Bold, l'equivalent
                            // standard du format PDF — memes largeurs, meme dessin.
                            styleTextes: { gras: true, couleur: '#222222', taille: 9 },

                            // Un PDF aplati ne se corrige pas : ce qu'on ne veut
                            // plus voir du gabarit, on le RECOUVRE d'un rectangle a
                            // la couleur exacte du fond, AVANT d'ecrire les valeurs.
                            //
                            // ⚠️ UN MASQUE COUVRE TOUTE LA CASE DE LA VALEUR, jamais
                            // le seul trait. Des masques de 1,5 pt, ajustes au
                            // soulignement, passaient au rendu fin mais laissaient
                            // le trait de « Modele » visible dans la visionneuse du
                            // navigateur : elle cale les rectangles pleins sur la
                            // grille des pixels, et un cache aussi mince que le
                            // trait peut tomber une rangee a cote. Une case entiere
                            // (12,5 pt de haut, 3 pt sous le trait) ne depend plus
                            // du zoom. Elle s'arrete entre le « : » du libelle et
                            // l'unite, et entre les rangees voisines.
                            //
                            // Si le gabarit est refait, re-mesurer ; s'il est livre
                            // SANS ces elements, retirer les masques devenus inutiles.
                            masques: [
                                // ── Page 1, entete (fond blanc) ──────────────
                                // Libelle « Zone : » : la zone ne figure plus au devis.
                                { page: 0, x: 304.6, y: 151.0, largeur: 31.0, hauteur: 13.6, couleur: '#ffffff' },
                                // Ancien libelle « Type de logement : », reimprime
                                // deux rangees plus haut, a la place de la zone.
                                { page: 0, x: 304.6, y: 182.0, largeur: 82.4, hauteur: 13.6, couleur: '#ffffff' },
                                // ── Soulignements des valeurs (fond #f3f8f4) ─
                                // Page 1 : nombre de capteurs, surface hors-tout.
                                { page: 0, x: 128.9, y: 248.2, largeur: 35.1, hauteur: 12.5, couleur: '#f3f8f4' },
                                { page: 0, x: 413.7, y: 248.2, largeur: 32.5, hauteur: 12.5, couleur: '#f3f8f4' },
                                // Page 2 : puissance, modele, surface chauffee.
                                { page: 1, x: 170.8, y: 78.2,  largeur: 32.5, hauteur: 12.5, couleur: '#f3f8f4' },
                                { page: 1, x: 338.7, y: 63.5,  largeur: 85.3, hauteur: 12.5, couleur: '#f3f8f4' },
                                { page: 1, x: 377.0, y: 78.2,  largeur: 32.5, hauteur: 12.5, couleur: '#f3f8f4' }
                            ],

                            // `base` = LIGNE DE BASE du libelle voisin, relevee
                            // dans le gabarit (repere PlaceIt, origine en haut a
                            // gauche) : valeur et libelle sont alignes au point
                            // pres. `page` est l'index pdf-lib (0 = page 1).
                            textes: [
                                // ── Page 1, colonne de gauche ────────────────
                                { source: 'numeroDevis', page: 0, x: 93, base: 96.9, taille: 14 },
                                // Numero client : champ a numerotation automatique
                                // de la Piste (« CL-01001 »), plus son identifiant
                                // technique.
                                { champ: { Lead: 'Numero_Client__c', 'Pro__c': null }, page: 0, x: 103, base: 114.6 },
                                { source: 'dateDuJour', page: 0, x: 100.5, base: 130.1 },
                                // Adresse des travaux : UN champ, celui que le
                                // Recapitulatif fait saisir — une correction a
                                // l'ecran se retrouve donc dans le document.
                                // Retour a la ligne automatique, trois lignes au
                                // plus sous le libelle. Largeur 200 pt : l'adresse
                                // s'arrete a x 234, bien avant la colonne de droite
                                // (x 306,6), au lieu de venir la frôler. Au-dela de
                                // trois lignes, la derniere se termine par « … ».
                                {
                                    champ: { Lead: 'REGIE_Adresse_Client__c', 'Pro__c': 'Client_Adresse_Chantier__c' },
                                    page: 0, x: 34, base: 161.0,
                                    largeur: 200, lignesMax: 3, interligne: 15.45
                                },
                                // ── Page 1, colonne de droite ────────────────
                                // Nom et prenom partent du MEME x que les libelles
                                // « Tél : » et « Type de logement : », sur les rangees
                                // de « Numéro Client » et « Date de devis ».
                                { champ: { Lead: 'LastName',  'Pro__c': 'PRO_Pr_nom_du_Signataire__c' }, page: 0, x: 306.6, base: 114.6 },
                                { champ: { Lead: 'FirstName', 'Pro__c': null },                          page: 0, x: 306.6, base: 130.1 },
                                { champ: { Lead: 'Phone',     'Pro__c': 'Phone__c' },                    page: 0, x: 330.6, base: 145.5 },
                                // Type de logement, sous « Tél : », a la place de la
                                // zone — qui ne figure plus au devis (libelle masque
                                // plus haut). Le libelle d'origine, deux rangees plus
                                // bas, est masque lui aussi et REIMPRIME ici : en
                                // maigre, comme les autres libelles du gabarit, suivi
                                // de sa valeur en gras.
                                { texte: 'Type de logement :', page: 0, x: 306.6, base: 161.0, gras: false },
                                { texte: 'Maison Individuelle', page: 0, x: 389.7, base: 161.0 },
                                // ── Page 1, systeme solaire ──────────────────
                                { calcul: 'capteurs',        page: 0, x: 134.6, base: 257.7 },
                                // Collee a son unite : « 24,7 m² ».
                                { calcul: 'surfaceHorsTout', page: 0, x: 444, base: 257.7, aligne: 'droite' },
                                // Quantites des lignes « Capteur solaire » et « Kit
                                // de fixation » — le kit est dimensionne au nombre
                                // de capteurs. Collees au mot « capteurs ».
                                { calcul: 'capteurs',        page: 0, x: 398.5, base: 379.9, aligne: 'droite' },
                                { calcul: 'capteurs',        page: 0, x: 398.5, base: 621.1, aligne: 'droite' },
                                // ── Page 2, pompe a chaleur ──────────────────
                                { calcul: 'puissancePac',    page: 1, x: 201.5, base: 87.7, aligne: 'droite' },
                                { calcul: 'modelePac',       page: 1, x: 343.9, base: 73.0 },
                                { champ: 'Surface_habitable__c', page: 1, x: 407.5, base: 87.7, aligne: 'droite' },
                                // Le modele, a la suite du titre de la ligne et sur
                                // SA ligne de base : le soulignement qui obligeait a
                                // le remonter a disparu du gabarit.
                                { calcul: 'modelePac',       page: 1, x: 333, base: 182.9 }
                            ]
                        }
                    }
                ]
            }
        },
        {
            titre: 'Residentiel :',
            typeEnregistrement: RT_RES,          // 'RESIDENTIEL_REGIES' — la "Cte RT"
            typeProduit: 'Residentiel',
            nomProduit: 'RES060- Pompe à Chaleur',
            codeProduit: 'RESIDENTIEL_REGIES_-_RES060',
            couleurProduit: '#624FDE',
            disponible: true,
            description: '',
            cdcExiste: true,
            cdcMaster: cdc_RES060_Master,        // rang 1 (avec prix)
            cdcMini: cdc_RES060_Mini,            // rang 2 (sans prix)
            catalogueExiste: true,
            catalogue: cat_RES060,
            ordreAffichage: 10,                  // 10 pour ne rien renuméroter
            champsDisponibles: [],
            // Champs propres a la fiche, tous OBLIGATOIRES, rendus a un emplacement
            // precis du formulaire Nouveau RDV — a la difference de champsDisponibles,
            // qui alimente le bloc generique « Details supplementaires ». Seule
            // l'implantation dans le formulaire les distingue.
            //   groupe 'adresse'   -> juste sous l'adresse
            //   groupe 'logement'  -> section dediee, apres l'adresse
            //   groupe 'signature' -> juste avant le bloc date/creneau de rappel,
            //                         dont il CONDITIONNE l'affichage (voir
            //                         afficherRappel dans lwc020_NouveauRdv)
            // Les libelles FR/ES viennent des cles df_<apiName> de c/lwc000_i18n :
            // les libelles de l'org (« RES- Shab »...) ne sont jamais affiches.
            champsFiche: [
                { apiName: 'RES_Zone_ES__c', groupe: 'adresse' },
                { apiName: 'Parcelle_Cadastrale__c', groupe: 'adresse' },
                // `entiers` / `decimales` bornent la SAISIE des champs numeriques
                // (voir handleLimiteChiffres dans lwc020_NouveauRdv) : maxlength est
                // sans effet sur un <input type="number">, il faut tronquer a la frappe.
                { apiName: 'RES_Anne_maison__c', groupe: 'logement', entiers: 4 },
                { apiName: 'Surface_habitable__c', groupe: 'logement', entiers: 3, decimales: 2 },
                { apiName: 'Type_de_Chauffage__c', groupe: 'logement' },
                { apiName: 'RES_Ann_e_Chaudi_re__c', groupe: 'logement', entiers: 4 },
                { apiName: 'Suivi_Signature__c', groupe: 'signature' }
            ],
            // Sections de photos, chacune multi-fichiers. Les fichiers sont
            // renommes « <prefixe> 1, 2... n » avant envoi. Le prefixe vient de
            // prefixePhoto_<cle> dans c/lwc000_i18n, volontairement IDENTIQUE en
            // FR et en ES : le nom stocke dans Salesforce doit rester stable quelle
            // que soit la langue d'affichage choisie par le partenaire.
            // Toutes ne sont pas des photos : 'contratEnergie' recoit le contrat
            // d'energie du client, generalement un PDF. La mecanique de zone, de
            // nommage et de numerotation est la meme, seule la compression ne
            // s'applique pas (c/customFileUpload ne compresse que les images).
            photosFiche: ['cadastrale', 'facade', 'chaudiere', 'contratEnergie', 'complementaires'],
            pays: ["Espagne"],
            // ── Signature electronique ───────────────────────────────────
            // Ces reglages VARIENT d'une fiche a l'autre : ils n'ont donc plus
            // leur place dans des Custom Labels, qui sont uniques pour toute
            // l'org. Une deuxieme fiche signable y aurait ecrase la premiere.
            // Les labels YOUSIGN_* subsistent comme REPLI, pour une fiche qui
            // ne declarerait rien ici.
            signature: {
                // L'INTERRUPTEUR de la fonctionnalite pour cette fiche.
                // false, ou bloc `signature` absent : la colonne « Statut
                // Devis » disparait du reporting et le devis ne se gere pas.
                // C'est ce drapeau, et non le pays, qui decide desormais :
                // la signature n'existe aujourd'hui qu'en Espagne parce que
                // seule une fiche espagnole la declare, pas parce que le code
                // regarde le pays.
                statut: true,
                // Ce qui DECLENCHE une demande de signature. Vide pour
                // l'instant : la 060 s'envoie a la main depuis la modale.
                // La forme est une liste des maintenant, comme `devis` — la
                // logique reste a definir.
                lanceur: [],
                // Sequence de numerotation utilisee pour le numero de devis :
                // la valeur de Cle__c sur l'enregistrement YS_Compteur__c.
                //
                // AU NIVEAU DE LA FICHE et non du devis : les devis d'une meme
                // fiche appartiennent au meme dossier commercial et doivent se
                // suivre dans une seule serie. Deux fiches, en revanche, peuvent
                // vouloir des series distinctes — d'ou le reglage ici plutot
                // qu'une constante Apex unique.
                //
                // ⚠️ La LIGNE doit exister dans l'org : elle ne se deploie pas
                // (une donnee n'est pas une metadonnee). Absente, la reservation
                // echoue en nommant la cle manquante, plutot que d'inventer un
                // numero.
                compteur: 'DEVIS',
                // Langue de la PLATEFORME de signature — email envoye au
                // client, page de signature, mention manuscrite. Sans rapport
                // avec la langue du portail : un utilisateur francais qui
                // prepare un devis pour un client espagnol doit lui adresser
                // un document en espagnol.
                langue: 'es',
                // Nom d'expediteur affiche au client. Pose demande par demande,
                // jamais dans le compte Yousign : celui-ci est partage avec
                // d'autres integrations, qui gardent leur propre nom.
                expediteur: 'ECONATURA',
                // UN devis = UN gabarit de document, donc UN jeu de
                // coordonnees. La 060 n'en a qu'un aujourd'hui, mais la forme
                // est une LISTE des maintenant : d'autres fiches en auront
                // plusieurs selon les choix de l'utilisateur, et transformer
                // un objet en liste plus tard obligerait a reprendre tous les
                // appelants.
                // Format « page|x|y|largeur|hauteur », repere PlaceIt
                // (origine en haut a gauche), identique a celui des labels.
                devis: [
                    {
                        cle: 'standard',
                        // Le gabarit appartient au DEVIS, pas a la fiche : une
                        // fiche a plusieurs devis aura plusieurs documents, et
                        // chacun ses emplacements de signature.
                        //
                        // DEUX formes du meme gabarit, et les deux servent :
                        //   contratUrl       — URL, pour l'AFFICHAGE cote navigateur ;
                        //   contratRessource — nom, pour la LECTURE cote Apex,
                        //                      qui interroge StaticResource.
                        contratUrl: contrat_RES060,
                        contratRessource: 'cae_colab_contrat',
                        champSignature: '1|140|700|249|40',
                        champMention: '1|140|665|251|30',
                        // Ce que le navigateur IMPRIME sur le gabarit avant
                        // envoi - a ne pas confondre avec les champs ci-dessus,
                        // qui sont des zones interactives posees par Yousign.
                        // Repere PlaceIt (origine en haut a gauche) ; `page`
                        // est l'index pdf-lib, donc 0 pour la premiere page.
                        pdf: {
                            zoneClient: {
                                page: 0,
                                boite: { x: 301, y: 151, largeur: 243, hauteur: 62 },
                                marge: { gauche: 6, haut: 11 },
                                interligne: 12.5,
                                taille: 8,
                                tailleMin: 6,
                                lignes: ['nom', 'adresse', 'telephone', 'email']
                            },
                            // Le gabarit imprime deja « HP-2026- » : seul le
                            // numero se pose, sur les deux premieres pages.
                            numeroDevis: {
                                taille: 10,
                                emplacements: [
                                    { page: 0, x: 516, y: 63, hauteur: 14 },
                                    { page: 1, x: 516, y: 63, hauteur: 14 }
                                ]
                            },
                            // Bande « 12 / 14 / 16 kW ». Propre a ce gabarit :
                            // une fiche qui n'en porte pas omet simplement la cle.
                            casesPuissance: {
                                page: 0,
                                cases: {
                                    12: { x: 84, y: 317 },
                                    14: { x: 122, y: 317 },
                                    16: { x: 160, y: 317 }
                                }
                            }
                        }
                    }
                ]
            },
            // Traduction de la fiche — fusionnee generiquement par traduireProduit()
            // de c/lwc000_i18n. Tout nouveau champ AFFICHE ajoute a cette fiche doit
            // etre repris ici, sinon il restera en francais.
            // N'y mettre AUCUN champ servant de valeur (codeProduit, typeEnregistrement,
            // typeProduit, ordreAffichage) : ils pilotent le filtrage et le payload Apex.
            i18n: {
                es: {
                    nomProduit: 'RES060- Bomba de Calor',
                    titre: 'Residencial:',
                    // Cahier des charges en espagnol. Ce sont des URL d'affichage,
                    // pas des valeurs de filtrage : leur place est bien ici.
                    // `catalogue` n'y figure PAS — le même document sert aux deux
                    // langues, et le surcharger inutilement créerait un second
                    // fichier à maintenir en parallèle du premier.
                    cdcMaster: cdc_RES060_Master_ES,
                    cdcMini: cdc_RES060_Mini_ES
                }
            }
        },
        {
            titre: 'Tertiaire :',
            typeEnregistrement: RT_PRO,
            typeProduit: 'Tertiaire',
            nomProduit: 'TH142- Déstratificateurs',
            codeProduit: 'BAT_REGIES_-_TH142',
            couleurProduit: '#a600c7',
            disponible: false,
            description: '',
            cdcExiste: false,
            ordreAffichage: 3,
            champsDisponibles: [],
            pays: ["France"]
        },
        {
            titre: 'Tertiaire :',
            typeEnregistrement: RT_PRO,
            typeProduit: 'Tertiaire',
            nomProduit: 'TH163- PAC Collective Tertiaire',
            codeProduit: 'BAT_REGIES_-_TH163',
            couleurProduit: '#a600c7',
            disponible: false,
            description: '',
            cdcExiste: true,
            cdcMaster: cdc_163_Master,
            cdcMini: cdc_163_Mini,
            catalogueExiste: true,
            catalogue: cat_163,
            simulateurExiste: true,
            ordreAffichage: 4,
            champsDisponibles: [],
            pays: ["France"]
        },
        {
            titre: 'Tertiaire :',
            typeEnregistrement: RT_PRO,
            typeProduit: 'Tertiaire',
            nomProduit: 'TH179- PAC Collective Residentiel',
            codeProduit: 'BAT_REGIES_-_TH179',
            couleurProduit: '#a600c7',
            disponible: true,
            description: '',
            cdcExiste: true,
            cdcMaster: cdc_179_Master,
            cdcMini: cdc_179_Mini,
            catalogueExiste: true,
            catalogue: cat_179,
            simulateurExiste: true,
            ordreAffichage: 5,
            champsDisponibles: [],
            pays: ["France"]
        },
        {
            titre: 'Tertiaire :',
            typeEnregistrement: RT_PRO,
            typeProduit: 'Tertiaire',
            nomProduit: 'EQ127- LEDS',
            codeProduit: 'BAT_REGIES_-_EQ127',
            couleurProduit: '#a600c7',
            disponible: false,
            description: '',
            cdcExiste: false,
            ordreAffichage: 6,
            champsDisponibles: [],
            pays: ["France"]
        },
        {
            titre: 'Agriculture :',
            typeEnregistrement: RT_AGRI,
            typeProduit: 'Agriculture',
            nomProduit: 'TH117- Déshumidificateurs',
            codeProduit: 'AGRI_REGIES_-_TH117',
            couleurProduit: '#F0B13B',
            disponible: false,
            description: '',
            cdcExiste: true,
            cdcMaster: cdc_117_Master,
            cdcMini: cdc_117_Mini,
            catalogueExiste: true,
            catalogue: cat_117,
            ordreAffichage: 7,
            champsDisponibles: [],
            pays: ["France"]
        },
        {
            titre: 'Agriculture :',
            typeEnregistrement: RT_AGRI,
            typeProduit: 'Agriculture',
            nomProduit: 'TH119- VMC',
            codeProduit: 'AGRI_REGIES_-_TH119',
            couleurProduit: '#F0B13B',
            disponible: false,
            description: '',
            cdcExiste: true,
            cdcMaster: cdc_119_Master,
            cdcMini: cdc_119_Mini,
            catalogueExiste: true,
            catalogue: cat_119,
            ordreAffichage: 8,
            champsDisponibles: [],
            pays: ["France"]
        },
        {
            titre: 'Agriculture :',
            typeEnregistrement: RT_AGRI,
            typeProduit: 'Agriculture',
            nomProduit: 'EQ108- TUBES',
            codeProduit: 'AGRI_REGIES_-_EQ108',
            couleurProduit: '#F0B13B',
            disponible: false,
            description: '',
            cdcExiste: true,
            cdcMaster: cdc_108_Master,
            cdcMini: cdc_108_Mini,
            catalogueExiste: true,
            catalogue: cat_108,
            ordreAffichage: 9,
            champsDisponibles: [],
            pays: ["France"]
        },
        {
            titre: 'Agriculture :',
            typeEnregistrement: RT_AGRI,
            typeProduit: 'Agriculture',
            // ⚠️ NOM ET CODE NE CONCORDENT PAS, et c'est voulu : la picklist
            // TypeDeDossier__c porte toujours la valeur historique
            // « AGRI_REGIES_-_EQ112 », dont l'etiquette a ete rebasculee sur le
            // 110. C'est le CODE qui fait foi pour reconnaitre la fiche, jamais
            // le libelle — voir ficheSignable().
            nomProduit: 'EQ110- Séchage Solaire',
            codeProduit: 'AGRI_REGIES_-_EQ112',
            // Ce que le REPORTING affiche, quand le code technique ne dit pas
            // ce qu'on veut lire. Ici le code historique donnerait « EQ112 »,
            // alors que la fiche joue le role du 110 depuis que son etiquette a
            // ete rebasculee. A defaut de cet attribut, la colonne retombe sur
            // l'extraction du codeProduit — le comportement d'avant, inchange
            // pour toutes les autres fiches.
            codeProduitReporting: 'TH110',
            codeProduitReporting: 'EQ110',
            couleurProduit: '#F0B13B',
            disponible: false,
            description: '',
            cdcExiste: false,
            ordreAffichage: 9,
            champsDisponibles: [],
            pays: ["France"],
            // -- Signature electronique ----------------------------------
            // PREMIERE FICHE A DEUX VERSIONS de devis. Le document differe
            // selon que le client a deja ete informe du reste a charge : ce
            // n'est pas une variante de mise en page, ce sont deux contrats.
            signature: {
                statut: false,
                compteur: 'DEVIS-TH',
                langue: 'fr',
                expediteur: 'RENOV ARTISAN',
                lanceur: [],
                // Champs a saisir sur l'onglet RECAPITULATIF, en plus de ceux
                // communs a tous les devis. Celui-ci n'est pas descriptif :
                // c'est LUI qui designe le document contractuel.
                //
                // Sur le Recapitulatif et non l'onglet Signature : tous les
                // champs y sont obligatoires, le choix est donc fait AVANT que
                // le document ne se fabrique. Pose plus loin, il aurait laisse
                // l'utilisateur arriver devant un ecran sans document.
                champsRecap: [
                    {
                        field: 'Type_Devis__c',
                        label: 'Type de devis',
                        editable: true,
                        type: 'picklist',
                        pleineLargeur: true,
                        options: [
                            '100% pris en charge- Grand précaire',
                            '3500€ RAC- Classique'
                        ]
                    }
                ],
                devis: [
                    {
                        cle: 'v1',
                        // Ce qui DESIGNE cette version. Toutes les conditions
                        // doivent etre satisfaites ; le premier devis dont
                        // c'est le cas l'emporte.
                        //
                        // Aucun devis ne correspondant, il n'y en a PAS — pas de
                        // repli sur le premier de la liste. Les deux versions
                        // engagent le client differemment, et l'ecart ne se
                        // verrait qu'apres signature.
                        conditions: [
                            { champ: 'Type_Devis__c', valeur: '100% pris en charge- Grand précaire' }
                        ],
                        contratUrl: contrat_TH110_v1,
                        contratRessource: 'DEVIS_TH110_v1',
                        // Signature, mention et numero : identiques au TH168,
                        // meme maquette d'en-tete et de pied de page.
                        champSignature: '1|55|745|501|52',
                        champMention: '1|57|710|498|33',
                        pdf: {
                            // Cadre client A GAUCHE sur cette version.
                            // Releve PlaceIt : x 55, y 138, largeur 258, hauteur 101.
                            zoneClient: {
                                page: 0,
                                boite: { x: 55, y: 138, largeur: 258, hauteur: 101 },
                                marge: { gauche: 6, haut: 11 },
                                interligne: 14,
                                taille: 9,
                                tailleMin: 6,
                                lignes: ['nom', 'adresse', 'telephone', 'email']
                            },
                            numeroDevis: {
                                taille: 10,
                                emplacements: [
                                    { page: 0, x: 447, y: 50, hauteur: 21 }
                                ]
                            }
                        }
                    },
                    {
                        cle: 'v2',
                        conditions: [
                            { champ: 'Type_Devis__c', valeur: '3500€ RAC- Classique' }
                        ],
                        contratUrl: contrat_TH110_v2,
                        contratRessource: 'DEVIS_TH110_v2',
                        champSignature: '1|55|745|501|52',
                        champMention: '1|57|710|498|33',
                        pdf: {
                            // Cadre client A DROITE et plus bas sur cette
                            // version. Releve PlaceIt : x 286, y 200,
                            // largeur 252, hauteur 101.
                            zoneClient: {
                                page: 0,
                                boite: { x: 286, y: 200, largeur: 252, hauteur: 101 },
                                marge: { gauche: 6, haut: 11 },
                                interligne: 14,
                                taille: 9,
                                tailleMin: 6,
                                lignes: ['nom', 'adresse', 'telephone', 'email']
                            },
                            numeroDevis: {
                                taille: 10,
                                emplacements: [
                                    { page: 0, x: 447, y: 50, hauteur: 21 }
                                ]
                            }
                        }
                    }
                ]
            }
        },
        {
            titre: 'Transport :',
            typeEnregistrement: RT_TRA,
            typeProduit: 'Transport',
            nomProduit: 'SE104- Gonfleurs',
            codeProduit: 'TRANSPORT_REGIES_-_SE104',
            couleurProduit: '#e4353d',
            disponible: false,
            description: '',
            cdcExiste: false,
            cdcMaster: cdc_171_Master,
            cdcMini: cdc_171_Mini,
            cdcPartenaire: cdc_171_Partenaire,
            ordreAffichage: 12,
            champsDisponibles: [],
            pays: ["France"],
            // -- Signature electronique ----------------------------------
            // Un seul devis, donc pas de `conditions` ni de champ de choix :
            // reglagesSignature() sert directement le devis declare.
            signature: {
                statut: false,
                lanceur: [],
                compteur: 'DEVIS-TH',
                langue: 'fr',
                expediteur: 'RENOV ARTISAN',
                devis: [
                    {
                        cle: 'standard',
                        contratUrl: contrat_SE104,
                        contratRessource: 'DEVIS_SE104',
                        // MEMES EMPLACEMENTS QUE LE TH168 : les deux gabarits
                        // partagent la meme maquette. Les valeurs sont recopiees
                        // plutot que partagees par une constante — un gabarit
                        // peut evoluer sans l'autre, et une constante commune
                        // ferait bouger les deux le jour ou l'un change.
                        champSignature: '1|55|745|501|52',
                        champMention: '1|57|710|498|33',
                        pdf: {
                            zoneClient: {
                                page: 0,
                                boite: { x: 274, y: 168, largeur: 264, hauteur: 101 },
                                marge: { gauche: 6, haut: 11 },
                                interligne: 14,
                                taille: 9,
                                tailleMin: 6,
                                lignes: ['nom', 'adresse', 'telephone', 'email']
                            },
                            numeroDevis: {
                                taille: 10,
                                emplacements: [
                                    { page: 0, x: 447, y: 50, hauteur: 21 }
                                ]
                            }
                            // casesPuissance : absent, comme pour le TH168.
                        }
                    }
                ]
            }
        },
    ]
};

/**
 * Filtre le catalogue produits par pays.
 *
 * Le pays vient de Pays__c (picklist France / Espagne), porté par
 * l'Utilisateur (User.Pays__c) ou par la Campagne (Campaign.Pays__c)
 * selon le mode d'accès du composant appelant.
 *
 * - pays vide/null      => aucun filtre (comportement historique conservé,
 *                          le temps que Pays__c soit renseigné en masse)
 * - produit sans `pays` => tous pays, toujours visible
 *
 * @param {Array}  produits liste de produits issue de PRODUCT_CATALOG
 * @param {String} pays     'France' | 'Espagne' | null
 * @returns {Array} les produits du pays demandé
 */
export function filtrerProduitsParPays(produits, pays) {
    if (!pays) return produits || [];
    return (produits || []).filter(
        p => !Array.isArray(p.pays) || p.pays.length === 0 || p.pays.includes(pays)
    );
}
/**
 * codeReporting() — libelle a afficher dans la colonne « Type Fiche CEE ».
 *
 * Rend `codeProduitReporting` s'il est renseigne sur la fiche, `null` sinon —
 * auquel cas l'appelant garde sa logique d'extraction habituelle.
 *
 * Cherche parmi TOUTES les fiches, signables ou non : la colonne concerne tout
 * le catalogue, pas seulement les produits qui partent a la signature.
 *
 * Reconnaissance en deux temps, comme ficheSignable() : egalite stricte sur le
 * codeProduit, puis presence du suffixe (« EQ112 ») dans la reference. La Piste
 * porte le code exact, le Dossier un libelle.
 *
 * @param {String} reference codeProduit, ou libelle de fiche
 * @returns {String|null}
 */
export function codeReporting(reference) {
    if (!reference) return null;

    const toutes = Object.keys(PRODUCT_CATALOG)
        .reduce((acc, cle) => acc.concat(PRODUCT_CATALOG[cle] || []), [])
        .filter(f => f.codeProduitReporting);

    const ref = String(reference).trim().toUpperCase();
    const fiche = toutes.find(f => String(f.codeProduit).toUpperCase() === ref)
        || toutes.find(f => {
            const suffixe = String(f.codeProduit).split('_-_').pop();
            return suffixe && ref.includes(suffixe.toUpperCase());
        });

    return fiche ? fiche.codeProduitReporting : null;
}

/**
 * signatureActivee() — la fiche gere-t-elle la signature electronique ?
 *
 * C'est ce que consulte le reporting pour decider d'afficher la colonne
 * « Statut Devis » et ses actions. Une fiche sans bloc `signature`, ou dont le
 * `statut` n'est pas vrai, ne propose rien.
 *
 * @param {String} reference codeProduit, ou libelle de fiche
 * @returns {Boolean}
 */
export function signatureActivee(reference) {
    return ficheSignable(reference) !== null;
}

/**
 * La fiche ACTIVE correspondant a une reference, ou null.
 *
 * POURQUOI UNE RECONNAISSANCE EN DEUX TEMPS : la reference n'a pas la meme
 * forme selon l'objet.
 *   • Piste  — `TypeDeDossier__c` porte le codeProduit exact
 *              (« RESIDENTIEL_REGIES_-_RES060 ») ;
 *   • Dossier — `Fiche_CEE__c` porte un LIBELLE (« BAR_TH171- PAC Indiv »).
 * D'ou l'egalite stricte sur le codeProduit, puis, a defaut, la presence du
 * suffixe de code (« RES060 ») dans la reference. Le suffixe est le seul
 * fragment stable entre les deux formes.
 */
function ficheSignable(reference) {
    if (!reference) return null;

    const toutes = Object.keys(PRODUCT_CATALOG)
        .reduce((acc, cle) => acc.concat(PRODUCT_CATALOG[cle] || []), []);
    const actives = toutes.filter(f => f.signature && f.signature.statut === true);

    const ref = String(reference).toUpperCase();
    return actives.find(f => String(f.codeProduit).toUpperCase() === ref)
        || actives.find(f => {
            // « RESIDENTIEL_REGIES_-_RES060 » -> « RES060 »
            const suffixe = String(f.codeProduit).split('_-_').pop();
            return suffixe && ref.includes(suffixe.toUpperCase());
        })
        || null;
}

/**
 * cleDevisSelonConditions() — quelle version de devis pour cet enregistrement ?
 *
 * Une fiche peut porter PLUSIEURS devis, et un champ de l'enregistrement
 * tranche : le 110 a deux contrats selon que le client a deja ete informe du
 * reste a charge. Chaque devis porte ses propres `conditions`, la ou les
 * consulter est le plus naturel — a cote du gabarit et des emplacements
 * qu'elles commandent.
 *
 * TOUTES les conditions d'un devis doivent etre satisfaites ; le PREMIER devis
 * dont c'est le cas l'emporte.
 *
 * Aucun devis ne correspondant, on rend `null` — jamais le premier de la liste.
 * Servir une version au hasard serait le pire des comportements : les deux
 * engagent le client differemment, et l'ecart ne se verrait qu'apres signature.
 *
 * Un devis SANS conditions n'est jamais choisi ici : c'est le cas des fiches a
 * un seul devis, que reglagesSignature() sert directement.
 *
 * @param {String} reference codeProduit, ou libelle de fiche
 * @param {Object} valeurs   valeurs de l'enregistrement, par nom d'API
 * @returns {String|null} cle du devis
 */
export function cleDevisSelonConditions(reference, valeurs) {
    const fiche = ficheSignable(reference);
    if (!fiche) return null;

    const devis = fiche.signature.devis;
    if (!Array.isArray(devis)) return null;

    const lues = valeurs || {};
    const lu = (champ) => String(lues[champ] == null ? '' : lues[champ]).trim();

    const retenu = devis.find(d =>
        d && Array.isArray(d.conditions) && d.conditions.length > 0
        && d.conditions.every(c => c && c.champ && lu(c.champ) === String(c.valeur).trim()));

    return retenu ? retenu.cle : null;
}

/**
 * devisSousConditions() — la fiche propose-t-elle plusieurs versions de devis,
 * departagees par des conditions ?
 *
 * C'est CE critere, et non la presence de champs sur le Recapitulatif, qui
 * dit s'il y a un choix de version a faire. Le TH168 declare un champ (le
 * nombre de capteurs) mais un seul devis : rien a choisir. Le 110 en declare
 * deux sous conditions : tant qu'aucune n'est satisfaite, pas de document.
 *
 * @returns {Boolean}
 */
export function devisSousConditions(reference) {
    const fiche = ficheSignable(reference);
    if (!fiche) return false;
    return (fiche.signature.devis || []).some(d =>
        d && Array.isArray(d.conditions) && d.conditions.length > 0);
}

/**
 * champsRecapFiche() — champs propres a la fiche, saisis sur le Recapitulatif.
 *
 * Ils sont declares avec la meme forme que ceux de devisConfig (field, label,
 * editable, type, options...) pour que l'ecran n'ait pas a distinguer leur
 * origine.
 *
 * @returns {Array} toujours un tableau, vide a defaut
 */
export function champsRecapFiche(reference) {
    const fiche = ficheSignable(reference);
    const champs = fiche && fiche.signature.champsRecap;
    return Array.isArray(champs) ? champs : [];
}

/**
 * champsRecapDeclares() — noms d'API de TOUS les champs de fiche.
 *
 * POURQUOI L'UNION plutot que ceux de la fiche courante : au premier
 * chargement, le composant ne SAIT PAS encore de quelle fiche il s'agit — la
 * reponse est dans un champ qu'il faut justement demander. On demande donc tous
 * les champs susceptibles de servir, et l'Apex ne rend que ceux que sa liste
 * blanche autorise pour l'objet concerne. Un champ demande en trop ne coute
 * rien ; un champ manquant empeche de choisir la version du devis.
 *
 * @returns {Array<String>} sans doublon
 */
export function champsRecapDeclares() {
    const noms = new Set();
    Object.keys(PRODUCT_CATALOG)
        .reduce((acc, cle) => acc.concat(PRODUCT_CATALOG[cle] || []), [])
        .forEach((f) => {
            const sig = f.signature;
            if (!sig) return;
            (Array.isArray(sig.champsRecap) ? sig.champsRecap : [])
                .forEach(c => c && c.field && noms.add(c.field));
            (Array.isArray(sig.champsDecision) ? sig.champsDecision : [])
                .forEach(c => c && noms.add(c));
            // Les champs IMPRIMES et ceux qui alimentent un calcul : sans eux
            // le document sortirait avec des blancs, sans erreur.
            (sig.devis || []).forEach((d) => {
                const textes = d && d.pdf && d.pdf.textes;
                (Array.isArray(textes) ? textes : []).forEach((t) => {
                    if (!t || !t.champ) return;
                    if (typeof t.champ === 'string') noms.add(t.champ);
                    else Object.keys(t.champ).forEach(k => t.champ[k] && noms.add(t.champ[k]));
                });
            });
            Object.keys(sig.calculs || {}).forEach((n) => {
                const r = sig.calculs[n];
                if (r.champ) noms.add(r.champ);
                if (r.choix) noms.add(r.choix);
            });
        });
    return [...noms];
}

/**
 * reglagesSignature() — les parametres Yousign d'une fiche.
 *
 * Rend null si la fiche n'existe pas, ne declare pas de signature, ou l'a
 * DESACTIVEE (statut != true) — voir ficheSignable().
 *
 * @param {String} reference  codeProduit, ou libelle de fiche
 * @param {String} [cleDevis] devis vise ; le premier declare si omis
 * @returns {Object|null} { langue, expediteur, champSignature, champMention,
 *                        contratUrl, contratRessource, compteur }, ou null si la fiche
 *                        ne declare pas de signature — auquel cas l'Apex
 *                        retombe sur les Custom Labels et le gabarit par defaut.
 */
export function reglagesSignature(reference, cleDevis) {
    const fiche = ficheSignable(reference);
    if (!fiche) return null;

    const devis = Array.isArray(fiche.signature.devis) ? fiche.signature.devis : [];
    // Cle inconnue : on ne devine PAS en retombant sur le premier devis. Un
    // document contractuel signe au mauvais endroit ne se rattrape pas, et un
    // repli silencieux ferait passer l'erreur inapercue.
    const gabarit = cleDevis
        ? devis.find(d => d.cle === cleDevis)
        : devis[0];

    if (!gabarit) return null;

    return {
        langue: fiche.signature.langue || null,
        expediteur: fiche.signature.expediteur || null,
        champSignature: gabarit.champSignature || null,
        champMention: gabarit.champMention || null,
        contratUrl: gabarit.contratUrl || null,
        contratRessource: gabarit.contratRessource || null,
        compteur: fiche.signature.compteur || null,
        pdf: gabarit.pdf || null,
        calculs: fiche.signature.calculs || null,
        champsDecision: Array.isArray(fiche.signature.champsDecision)
            ? fiche.signature.champsDecision : []
    };
}

/**
 * estModeGenerateur() — vrai quand la page tourne dans le Générateur
 * d'expérience (Experience Builder) ou dans un aperçu de site, en prod comme
 * en sandbox.
 *
 * POURQUOI : sans token de campagne, le portail redirige vers l'app externe
 * (label GESTION_RDV_EXTERNE_API_ENDPOINT). Dans le Générateur, cette
 * redirection remplace l'iframe d'aperçu par la page de connexion « CEE
 * Apporteurs » et masque toute l'interface de travail. Les redirections
 * automatiques doivent donc être désactivées dans ce contexte.
 *
 * DÉTECTION : uniquement sur les URLs (frame courante, origines parentes,
 * referrer). On n'utilise volontairement PAS le simple test « je suis dans une
 * iframe » : le site publié peut légitimement être embarqué ailleurs, et la
 * redirection d'authentification doit continuer d'y fonctionner.
 *
 * @returns {Boolean} true dans le Générateur / l'aperçu, false sur le site publié
 */
export function estModeGenerateur() {
    const urls = [];
    try { urls.push(window.location.href); } catch (e) { /* ignore */ }
    try {
        const origines = window.location.ancestorOrigins;
        if (origines) {
            for (let i = 0; i < origines.length; i++) urls.push(origines[i]);
        }
    } catch (e) { /* ignore */ }
    try { if (document.referrer) urls.push(document.referrer); } catch (e) { /* ignore */ }

    return /builder\.salesforce-experience\.com|live-preview\.salesforce-experience\.com|\/sfsites\/picasso|sitepreview/i
        .test(urls.join(' '));
}