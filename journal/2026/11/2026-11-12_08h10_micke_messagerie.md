---
date: 2026-11-12 08:10
auteur: micke
sujet: Maquette confirmateur : onglet Messagerie (demandes entre collègues, lien piste ou dossier) et historique dans Contrôle
statut: terminé
branche: micke/catalogue-depots
suite_de: 2026-11-11_10h00_micke_onglet-stock.md
---

## Objectif

Ajouter une messagerie interne à la maquette : un onglet « Messagerie » pour tous les utilisateurs, avec deux
listes (En attente, Traité), pour s'envoyer des demandes entre acteurs, et une pastille rouge quand une
demande reçue n'est pas traitée.

## Ce qui a été fait

- Onglet **Messagerie** à droite de la barre d'onglets de Production, présent pour tout le monde
  (il ne dépend pas de Visibilité Onglets ; une personne sans aucun onglet le voit quand même).
- Deux listes : **En attente** et **Traité**. Chacun y voit les demandes qu'il a reçues ou envoyées
  (colonne Sens : Reçue / Envoyée). Colonnes : Quand, Sens, De, À, Demande, Pièces jointes, puis Action
  (bouton Traiter) ou Traité le + Réponse.
- Bouton **Nouveau** : choix du destinataire (personnes groupées par profil), message, pièces jointes.
- Ouverture d'une demande : message entier, pièces jointes ; le destinataire peut écrire une réponse et
  cliquer « Marquer comme traité » ; l'expéditeur voit « en attente de … ».
- **Pastille rouge** avec le nombre de demandes reçues non traitées : sur l'onglet Messagerie et sur
  « Production » dans le menu du haut (visible depuis Accueil et Paramétrage).
- Le bandeau « à attribuer » ne s'affiche pas sur la Messagerie.
- Vérifié dans le navigateur : envoi (avec contrôles destinataire et message), traitement, compteurs,
  pastille qui baisse, liste Traité, retour sur un autre onglet, aucune erreur.
- **Paramétrage › Messagerie** (nouvel onglet après Visibilité Listes de vue) : responsable direct de chaque personne
  avec organigramme, tableau « qui peut écrire à qui » par profil (Direction comprise), deux règles de hiérarchie
  (écrire à son responsable, écrire à son équipe). « Nouveau » ne propose que les personnes autorisées ;
  Contrôle signale les personnes isolées, injoignables ou sans responsable ; réglages tracés dans l’historique.
  Vérifié dans le navigateur : interdiction d’un profil, règle désactivée, boucle refusée, aucune erreur.
- Paramétrage › Messagerie **refait à la demande de l’utilisateur** sur le modèle de Visibilité Onglets : personnes par profil
  en lignes, profils destinataires en colonnes, case de profil, étoile « par défaut », clic sur le nom, « Comme… » ;
  responsable direct en dernière colonne. Organigramme et tableau profil × profil retirés. Vérifié dans le navigateur.
- **Décision finale** : aucune règle d’envoi (chacun écrit à qui il veut, direction comprise). L’onglet Paramétrage › Messagerie
  (deux versions essayées dans la matinée) est retiré, avec la hiérarchie et les alertes associées.
- Champ **Piste ou dossier concerné** (facultatif) dans une nouvelle demande : recherche par nom, un seul champ pour les deux ;
  colonne « Piste / dossier » cliquable dans les listes.
- **Contrôle › Historique Messagerie** : toutes les demandes de tous les utilisateurs, triées de la plus récente à la plus ancienne,
  filtres par personne et recherche dans le texte. Vérifié dans le navigateur, sans erreur.
- Quatre **statuts** de demande : Nouveau, En cours, En attente, Traité (le destinataire seul le change, depuis la liste ou la demande).
- **Pièces jointes** visibles et cliquables dans les listes ; ajout possible après coup depuis la demande ; colonne **Téléphone client**
  (piste ou dossier lié). Contrôle : Historique Messagerie placé juste après Retards en cours, compteur par statut.
  Vérifié dans le navigateur, sans erreur.
- Pièces jointes **rangées sur la piste ou le dossier lié** (visibles dans ses Fichiers) ; sans lien, elles restent sur la demande.
- Listes de la Messagerie alignées sur les autres onglets : boutons Récents et Actualiser, pied de tableau standard,
  plus de bouton dans les lignes ; plus de compteur sur « Traité ». Vérifié dans le navigateur, sans erreur.
- **Bouton Fichiers** (trombone + nombre) rendu visible sur toutes les listes, avec une vraie fenêtre d’ajout sur tous les onglets
  (avant : ajout réservé à Confirmation, icône seule invisible sur claude.ai). Messagerie : nombre de pièces jointes par ce même bouton,
  la colonne des noms est retirée. Vérifié sur Confirmation, Stock, Leads, Prévisite, Messagerie et Contrôle, sans erreur.
- **Bouton enveloppe** en bout de ligne de toutes les listes : nouvelle demande de la Messagerie déjà reliée au client de la ligne (colonne renommée « Actions »).
- **Récents** monté à côté de Messagerie : panneau des 50 dernières actions (ouvertures, modifications, fichiers, messages), filtres par type.
- **Messagerie** collée aux onglets, en couleur pleine ; rouge et animée avec « N à traiter » tant qu’il reste des demandes reçues.
- Messagerie : **trois listes** (À traiter, En attente, Traité), présentes dans Visibilité Listes de vue ; **Actualiser** monté à côté de Récents.
- Nouvelle demande : **service (= onglet) puis personne**, ou tout le service ; colonne Service dans les listes.
- Visibilité Listes de vue : **choix en haut** par objet (Pistes, Dossiers, SAV, Stock, Messagerie) puis par onglet.
- Visibilité Onglets : groupes Pistes, Dossiers, Stock, SAV ; hors défaut, seule la case est grisée, plus le nom (essai à valider).
- Visibilité Onglets et Fiche : plus de colonnes alternées (blanc = coché ou défaut, gris = non coché) ; **choix en haut** par profil ou par utilisateur.
- **Onglets Standard et Parrainages** ajoutés (Production, Visibilité Onglets, Visibilité Listes de vue) ; contenu proposé, à valider. Listes de vue : un seul filtre par onglet.
- Parrainages renommé **Externe** : filtre par type d’externe (sous-traitant, parrain, visiteur, Cofrac, régie, apporteur d’affaires) au lieu des fiches ; listes et colonnes proposées, à valider.
- Standard sans fiche (listes de vue seules) ; Externe sans Cofrac, ordre Apporteur, Régie, Visiteur, Sous-traitant, Parrain ; **correction** de l’en-tête de la fenêtre d’attribution et des fausses alertes de Contrôle.
- Nouvel onglet de Paramétrage **Visibilité Externe** : qui voit quels types d’externe, même présentation que Visibilité Onglets.
- Externe retiré de Visibilité Onglets : cocher un type dans Visibilité Externe ouvre l’onglet et le sous-onglet (un seul endroit de réglage).
- **Trois profils ajoutés** : Super admin (accès à tout, cases verrouillées), Responsable production, Responsable secrétariat ; affichés en premier partout. Onglets par défaut des responsables à valider.
- Envoi en pose retiré des défauts des responsables ; Externe : Régie et Apporteur d’affaires réservés au super admin (non cochables pour les autres).
- Visibilité Externe : colonnes selon le profil (Régie et Apporteur seulement pour le super admin ; télépros : Parrain seul).
- Type d’externe « Parrain » renommé « Parrainage » partout.
- **Filtres des listes** rendus visibles partout (entonnoir, tri et crayon dessinés dans la page, barre Filtres toujours affichée) : ils étaient invisibles sur claude.ai à cause de la police d’icônes bloquée.
- **Relecture et tests du Paramétrage** : toutes les cases cochables simulées dans le navigateur (Visibilité Onglets, Fiche, Externe, Listes de vue sur 296 listes, Attribution Auto, filtres des tableaux), avec vérification de l’effet dans Production. Un bug corrigé : la mention « aucun onglet » ne s’affichait pas quand on décochait les onglets un par un (la clé Externe restait cachée dans les onglets de la personne). Code inutile supprimé (variables jamais lues, ancien choix des destinataires par profil de la Messagerie, style `.dstb`) ; ESLint : 0 alerte.
- **Relecture et tests de Production** : les 207 listes visibles (12 onglets + Messagerie) rejouées dans le navigateur : compteurs, tri et filtre de chaque colonne, modification de chaque cellule (annuler / enregistrer), changement de statut (passage d’une liste à l’autre), boutons de ligne (fichiers, historique, enveloppe, nom), attribution, conversion en dossier, visionneuse, doublons, Messagerie, Récents, Actualiser. Corrigé : case « tout cocher » de la fenêtre d’attribution (restait décochée, impossible de tout décocher) et sélection vidée au changement de fiche ; statut Leads proposé en double (« Nouvelle » et « (vide) nouvelle piste ») ; fausse modification en refermant une liste sans rien choisir (ex. Pré-visiteur « À choisir ») ; Récents retrouve un enregistrement qui a changé de liste ; le rafraîchissement de chaque minute ne ferme plus un filtre ouvert et ne décoche plus les lignes ; boutons sans texte (croix des fenêtres, doublon, flèches) dessinés en caractères, visibles sans la police d’icônes. Code en double regroupé (ajout de fichiers, bouton Actualiser).
- Paramétrage : onglet **Grilles tarifaires** ajouté à côté de Relances & priorités, marqué « en attente de dev » (contenu à définir).
- Paramétrage : onglet **Traitement rapide** ajouté, « en attente de dev ».
- **Recherche globale** (case à côté de la cloche) : retrouve un client par nom, téléphone (chiffres seuls) ou adresse sur tous les objets (Piste, Dossier, SAV, Stock, Appel standard, Partenaire externe), dans ce que la personne a le droit de voir ; résultats groupés par objet, un clic ouvre la fiche. Dans Salesforce : SOSL avec les droits de l'utilisateur.
- **Actions groupées** dans toutes les listes : les cases de gauche sont gardées (tri, filtre) ; barre « N lignes cochées » avec « Modifier un champ » (même valeur sur toutes les lignes cochées, validée par Enregistrer) et, sur la liste Attribution de Confirmation, « M'attribuer la sélection ».
- Tailles de colonnes : déjà mémorisées par personne et par liste (localStorage `Preferences_Ecran__c`, futur champ utilisateur) — vérifié, rien à ajouter.
- Version « V2 » rendue par GPT analysée (réorganisation en 3 fichiers, recherche, pagination, avertissement, échappement) : rien de cassé, non reprise telle quelle. Reste à décider : actualisation multi-utilisateurs.
- Actions groupées : « Modifier un champ » seulement à partir de 2 lignes cochées ; **20 lignes cochées au maximum** dans toutes les listes et dans la fenêtre d'attribution (décision de l'utilisateur, 12/11/2026).
- **Messagerie en conversations** (cahier des charges de l'utilisateur, 12/11/2026), sans repartir de zéro :
  - chaque demande est un fil de messages (`m.msgs`), les anciennes demandes et leurs réponses de clôture y sont reprises ; répondre ne clôture plus ;
  - panneau latéral à droite (par-dessus la liste ou la fiche, sans les fermer) : en-tête, bulles, événements, fichiers par message, réponses rapides, Entrée = envoyer, vue agrandie ;
  - demandes à tout un service : « Je prends en charge » (un seul responsable, statut En cours, les autres en lecture seule) ; statut et clôture réservés au responsable ; « Réouvrir » avec motif obligatoire ;
  - deux pastilles distinctes : demandes à traiter (rouge) et conversations non lues (bleu) ; ligne en gras, colonnes Responsable / Dernier message / Dernier échange ;
  - recherche dans le client, l'identifiant, l'expéditeur et le contenu ;
  - encadré « Demandes internes » dans les fiches ; identifiant unique de l'enregistrement lié (`rec.id`) ;
  - la maquette n'a qu'un utilisateur : un bloc « Démonstration » du panneau simule la réponse ou la prise en charge d'un collègue (aucune vraie synchronisation).
  - Les 13 scénarios de validation joués dans le navigateur : tous passent ; reste du portail revérifié sur un échantillon (52 listes, 115 cases de Paramétrage).
- Messagerie : pastilles de critères rapides retirées (demande de l'utilisateur) ; la recherche reste.
- **Idées reprises de la version GPT**, dans notre fichier unique : échappement complet des textes (`glEsc` : `<`, `>`, `"`, `'`), plus aucun `onclick` écrit dans la page (clics gérés par le code), bandeau « Mode démonstration » avec heure simulée qui avance, pagination à 50 lignes (`GLPAGE`), avertissement avant de quitter un écran avec des modifications non enregistrées (fenêtre de la page : Rester / Abandonner / Enregistrer).
- **Relecture complète** : ESLint 0 alerte ; contrôle croisé page ↔ code (sélecteurs sans élément, identifiants absents, fonctions en double) ; code mort supprimé (`[data-files]`, `[data-mtr]`, `[data-qall]`, `.mqnote`) ; commentaires périmés de la Messagerie corrigés. Tests rejoués sur la version finale : Paramétrage 860 clics, Production 207 listes, Messagerie, attribution, conversion, recherche, actions groupées — aucune erreur.

## Fichiers touchés

- `docs/maquettes/maquette-confirmateur.html`
- `docs/analyse/04-poste-confirmateur.md`

## Décisions prises

- La Messagerie est un onglet de Production (même logique onglet → listes de vue), pas une page du menu du haut ;
  la pastille est répétée sur « Production » pour rester visible partout.
- Côté Salesforce : objet « Demande interne » à créer (De, À, Message, Statut, Réponse, Traité le) ;
  pièces jointes = Fichiers Salesforce.
- Tout écran de paramétrage reprend la présentation de Visibilité Onglets (lignes = personnes par profil, colonnes = ce qu’on règle).
- 13/11 : bouton de la barre de sélection renommé « Modifier un champ en masse ».
- 13/11 : décision de l'utilisateur : une demande est toujours liée à une piste ou à un dossier. Dans « Nouvelle demande », le champ est obligatoire ; la recherche porte sur les pistes et les dossiers (nom, téléphone, fiche) et chaque ligne affiche la fiche et l'état, pour distinguer deux dossiers d'un même client. Les 6 exemples de départ sans lien en ont reçu un.
- 13/11 : « Nouvelle demande » commence par la piste ou le dossier (étape 1, en haut), puis service et personne ; dans les résultats de recherche, la piste est en haut et ses dossiers dessous.
- 13/11 : recherche d'un client déplacée à côté de « Récents » (Production) ; la recherche du haut de l'écran et celle de la Messagerie sont supprimées. Résultat : si le client est dans des listes de vue de l'utilisateur, ces listes sont proposées (un clic y conduit, ligne surlignée) ; sinon seulement objet, fiche, étape et état, sans lien. Plus d'ouverture directe de la fiche depuis la recherche.
- 13/11 : recherche, suite : le nom d'un client accessible ouvre directement sa fiche ; pour un client hors des listes, bouton « Historique des messages (n) » : tous les échanges internes de la société sur ce client, en lecture seule (décision de l'utilisateur). Exemple de départ n° 8 rattaché à Marcel Couq pour le montrer.
- 13/11 : recherche, décision finale : bouton « Messages (n) » sur chaque client trouvé (dans ses listes ou non) ; la fenêtre montre l'historique de toute la société et propose « Nouvelle demande sur ce client » (demande déjà liée au client) pour transmettre à la personne concernée. Par cohérence, l'encadré « Messagerie du client » des fiches montre aussi les demandes de toute la société (lecture seule pour celles dont on ne fait pas partie).
- 13/11 : nouveau message : une pastille bleue « + New » dans l'onglet Messagerie, après les pastilles « à traiter » et « non lus » (pas de second bouton) ; l'onglet passe du rouge au rose ; les deux pastilles sont cliquables (« à traiter » → liste À traiter, « non lus » → liste contenant les non lus), visible sur tous les onglets de Production ; la fenêtre s'ouvre par-dessus la page en cours. L'ancien bouton « Nouveau » de l'onglet Messagerie est retiré.
- 13/11 : Messagerie : nouvelle liste de vue « Non lus » (après « À traiter ») : conversations avec un message non lu, quel que soit le statut ; la pastille « non lus » y conduit. Elle apparaît aussi dans Paramétrage › Visibilité Listes de vue.
- 13/11 : allègement visuel de Production (session parallèle, présentation seulement, aucune logique ni donnée touchée) : Messagerie, recherche, Récents et Actualiser sur la ligne des fiches (une ligne de moins) ; onglet Messagerie en ton neutre, pastilles de compteurs en gris, rouge réservé à l'urgence ; tableau sur toute la largeur et colonnes élargies tant qu'un texte est coupé (fitHeads) ; textes techniques masqués, visibles par le lien « Notes intégrateur » du bandeau de démonstration (classe `inote`) ; 6 tailles de texte (12 · 13 · 14 · 16 · 20 · 28 px). Captures dans `docs/maquettes/avant-apres/`. Lien claude.ai non republié depuis cette session (conflit de version avec la session principale).
- 13/11 : fiche d'un client, colonne de droite : l'encadré « Demandes internes » (dernier message seulement) devient « Messagerie du client », placé en haut, avec tous les échanges depuis le premier, demande par demande ; « Répondre » ouvre le panneau sans quitter la fiche, et l'encadré se met à jour après chaque message. Colonne élargie de 300 à 360 px.
- 13/11 : onglet Messagerie, décision de l'utilisateur après relecture du tableau avant/après : texte noir ; fond rose avec halo qui clignote uniquement quand il reste des demandes à traiter, fond blanc sinon. Le reste du tableau (recherche à 250, pastilles du menu, tableau pleine largeur, tailles de texte) était déjà en place.
- 13/11 : clic sur l'utilisateur (en haut à droite) : petit menu avec son nom, son profil et « Se déconnecter ». Dans la maquette, écran « Vous êtes déconnecté » avec « Se reconnecter » ; refusé s'il reste des modifications non enregistrées. Dans Salesforce : déconnexion standard.
- 13/11 : Messagerie, recherche, Récents et Actualiser remontés sur la barre des onglets (demande de l'utilisateur) : la session parallèle les avait descendus sur la ligne des fiches. La ligne des fiches ne contient plus que les fiches (absente sur Messagerie et Standard). À 1 720 px de large, la barre des onglets tient sur deux lignes.
- 13/11 : « Nouvelle demande » : le choix de la piste ou du dossier devient une liste déroulante (tous les clients dès l'ouverture, par ordre alphabétique, la piste avant ses dossiers ; elle se réduit à mesure qu'on écrit ; nombre de résultats en tête ; 200 lignes au plus). Avant : 10 résultats au maximum, seulement après avoir écrit.
- 13/11 : correction demandée par l'utilisateur : la liste ne s'affiche qu'en fonction des lettres tapées, 10 choix au plus, affinés à chaque lettre (plus de liste complète à l'ouverture) ; une ligne indique « 10 premiers choix sur n » quand il y en a davantage.
- 13/11 : deux points de l'audit visuel corrigés : nom de l'utilisateur affiché en entier dans l'en-tête, écrit comme dans le menu (« Chauvet · Confirmateur », tiré de la personne connectée) ; la ligne « Filtres : aucun… » ne s'affiche plus quand il n'y a aucun filtre (elle revient dès qu'un filtre est posé).
- 13/11 : **format téléphone** (demande de l'utilisateur : ergonomique, lisible, toutes les fonctions gardées ; priorité à la recherche et à la Messagerie, car on se connecte au téléphone pour une urgence ; 2 à 3 onglets par personne en général). Tout est dans un bloc de styles « FORMAT TÉLÉPHONE » (écran ≤ 820 px), l'affichage ordinateur ne change pas :
  - recherche d'un client + Récents + Actualiser, et Messagerie (pastilles, « + New ») dans une barre qui reste collée en haut de l'écran ;
  - onglets, fiches et listes de vue en rangées qu'on fait glisser du doigt (l'élément en cours est recentré) ;
  - listes en cartes (nom en tête, case à cocher en haut à droite, actions en bas) ; les titres de colonnes deviennent une rangée « Trier · filtrer » ; un seul appui ouvre la saisie d'une case modifiable (crayon) ;
  - fenêtres, fiche client et panneau de conversation en plein écran ; menu utilisateur (déconnexion) de nouveau visible ; boutons de 40 px au moins, champs à 16 px ;
  - Paramétrage : onglets à faire glisser, grands tableaux de cases qui défilent avec la colonne des noms fixe.
  - Vérifié à 375 px dans le navigateur : 211 listes sans débordement, recherche, fiche, Messagerie, nouvelle demande, filtres, Récents, sélection, Paramétrage (9 onglets), Accueil ; ordinateur revérifié. Non testé sur un vrai téléphone.
- 13/11 : format téléphone, suite : bandeau « à attribuer » retiré sur téléphone (demande de l'utilisateur) ; les rangées (onglets, fiches, listes de vue, « Trier · filtrer », onglets du Paramétrage) se glissent aussi à la souris, pour l'essai sur ordinateur en fenêtre étroite.
- 13/11 : **relecture complète avant déploiement** (demande de l'utilisateur) : relecture indépendante du code + tests rejoués dans le navigateur, ordinateur et téléphone. Corrigé :
  - Messagerie et Contrôle : les liens d'une ligne (ouvrir la demande, ouvrir la piste, « Je prends en charge ») ne répondaient plus après un tri, un filtre ou une case cochée → écoutés au niveau du document ;
  - téléphone : les champs à liste de choix (Aides visées, Closer, équipe…) se refermaient aussitôt ouverts ; cases à cocher et « Tout cocher » trop petits (zone agrandie) ; un seul crayon ; fenêtres de choix, de modification en masse et d'avertissement recadrées dans l'écran ; barre Enregistrer alignée ; débordement de Contrôle › Historique SMS ;
  - « Ouvrir la piste » depuis une conversation ouvrait la fiche derrière le panneau → le panneau se ferme ;
  - avertissement « modifications non enregistrées » : « Enregistrer » pouvait effacer en silence un brouillon d'une autre liste → il prévient et ne quitte pas ;
  - redessin au redimensionnement seulement si la largeur change et jamais pendant une saisie (clavier du téléphone) ;
  - une piste déjà convertie ne peut plus être convertie une seconde fois (via Récents) ;
  - textes saisis échappés (commentaire, date de passage, nom, téléphone de Prévisite ; fiche client) ; plus d'`onclick` écrit dans la page pour le téléphone ;
  - ouvrir un appel Standard par la recherche ne fait plus perdre la fiche en cours des autres onglets.
  - Tests : ordinateur, 207 listes (compteurs, tri), 351 filtres, 283 cases modifiables, enregistrement, modification en masse, attribution, Messagerie de bout en bout, recherche (60 clients), Récents, Paramétrage (640 clics) ; téléphone (375 px), 211 listes + Paramétrage + Contrôle sans débordement, saisie au doigt jusqu'à Enregistrer. ESLint 0, aucune erreur console.
  - Non corrigé, à décider : enregistrements retrouvés par leur nom (deux clients homonymes sur une même fiche se confondraient) ; en Data, un statut « Hors cible » fait sortir la piste de toutes les listes ; la liste « À traiter » de la Messagerie contient aussi les demandes envoyées (la pastille ne compte que les reçues). Non testé sur un vrai téléphone.
- 13/11 : suite à un audit externe transmis par l'utilisateur :
  - le format téléphone/tablette va maintenant jusqu'à **960 px** (au lieu de 820) : entre 821 et 927 px l'affichage ordinateur débordait (rangée d'onglets) ; sur ordinateur la rangée d'onglets passe à la ligne ; de 700 à 960 px, deux cartes côte à côte ;
  - à 320 px : menu du haut resserré (il poussait la page), barre Messagerie sans le mot « Messagerie » (enveloppe + pastilles) sous 360 px ;
  - cartes : sous le nom, la prochaine action sur toute la largeur (échéance / rappel, date de passage, de pose, d'intervention, de livraison, rappel prévu) ; pastilles de statut coupées entre deux mots seulement ; entonnoirs de filtre à 44 px ;
  - injection HTML corrigée dans l'encadré des doublons (`dupLine` : nom, fiche, statuts, motif échappés).
  - Vérifié sans débordement à 320, 375, 768, 900, 961 et 998 px (207 à 211 listes, Paramétrage, Contrôle).
  - Non traité, à décider : identifiant unique par enregistrement à la place de nom + fiche (problème n° 1 de l'audit) ; droits de lecture de la Messagerie appliqués côté serveur (n° 2 : l'historique « toute la société » est une décision de l'utilisateur du 13/11, à porter dans Salesforce comme une autorisation explicite).
- 13/11 : compteurs des fiches et des listes de vue : rose (comme la Messagerie) dès 1 élément, vert à zéro (demande de l'utilisateur).
- 13/11 : **« M'attribuer la sélection » dans les listes « Attribution » de Leads et Data** (il n'existait qu'en Confirmation). Règle donnée par l'utilisateur : toute personne qui a accès à la liste Attribution peut s'attribuer des pistes, et uniquement depuis ces listes. La piste prend la personne comme télépro, passe dans la première liste de travail de l'onglet et l'attribution est inscrite dans son historique. La liste Attribution de Data, vide jusque-là, reçoit des exemples.
- 13/11 : « Nouvelle demande » : le champ « 1. Piste ou dossier concerné » devient « 1. Client concerné » (case de recherche et message d'oubli alignés).
- 13/11 : l'enveloppe en bout de ligne des listes ouvre maintenant la « Messagerie du client » (tous les échanges internes sur ce client) avec le bouton « Nouvelle demande sur ce client », comme le bouton « Messages » de la recherche. Avant : elle ouvrait directement une nouvelle demande, sans montrer l'historique.
- 13/11 : nouvelle demande ouverte depuis un client (enveloppe d'une ligne, bouton « Messages » de la recherche) : le client est verrouillé, plus de croix pour le retirer (demande de l'utilisateur). Depuis « + New », le client reste à choisir et peut être changé.
- 13/11 : enveloppe retirée des lignes de la Messagerie (et de Contrôle › Historique Messagerie) : on y est déjà, elle ne servait à rien (remarque de l'utilisateur). Elle reste dans les listes des autres onglets.
- 13/11 : **seconde relecture complète** (relecture indépendante + tests rejoués). Aucun défaut bloquant. Corrigé :
  - téléphone : la fenêtre de réglage d'une liste de vue (Paramétrage) dépassait le bas de l'écran ; après un redessin (Enregistrer, Actualiser, minute suivante) l'onglet en cours sortait de la rangée ; ligne « Aucune ligne… » mal présentée ; place réservée à la case à cocher dans les cartes sans nom (Contrôle) ;
  - Récents ne laisse plus quitter une liste avec des modifications non enregistrées ;
  - l'attribution depuis Leads et Data est inscrite dans Récents, et le message cite une liste que la personne voit ;
  - redimensionnement pendant une saisie rattrapé ensuite ; l'encadré « Messagerie du client » garde sa position de défilement ; téléphone échappé dans « Nouvelle demande ».
  - Tests : ordinateur, 207 listes, 475 filtres, 299 cases modifiables, 45 enveloppes, enregistrement, masse, attribution ×3, Messagerie, recherche, Récents, Paramétrage (642 clics + 297 réglages de listes) ; téléphone 375 et 320 px, 211 listes, saisie, cases, attribution, enveloppe, recherche, Paramétrage. ESLint 0, aucune erreur console.
  - Laissé tel quel, à connaître : sous 960 px de large (fenêtre d'ordinateur réduite de moitié) l'affichage passe en format téléphone ; les listes Attribution de Leads, Data et Confirmation montrent les mêmes noms d'exemple sans lien entre elles ; « Enregistrer » dans l'avertissement quitte l'écran même si l'enregistrement est refusé (statut d'une demande dont on n'est pas responsable) ; reste des textes non échappés dans Prévisite (infos dossier, pré-visiteur).

## Problèmes / points d'attention

- Dans la maquette, on ne voit que la messagerie de la personne connectée (Chauvet) : une demande envoyée
  à un collègue apparaît dans « En attente » côté expéditeur, pas dans une autre session.
- Les pièces jointes ne sont que des noms de fichier (rien n'est envoyé).
- Icônes absentes sur claude.ai tant que la police d'icônes n'est pas intégrée (accord de téléchargement attendu).

## Prochaines étapes

- [ ] Valider le contenu : faut-il un titre de demande, une échéance ?
- [x] Sauvegarder sur GitHub (commit + push) : fait le 15/11/2026 à la demande de l'utilisateur (maquette version 87, journal, récapitulatifs).
- [ ] Essayer la maquette sur un vrai téléphone (iPhone et Android) avant le déploiement.
