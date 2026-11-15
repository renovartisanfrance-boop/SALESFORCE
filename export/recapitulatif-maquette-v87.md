# Maquette du portail Renov Artisan France, version 87

Date : 13/11/2026

Fichier joint : `maquette-confirmateur.html` (un seul fichier, à ouvrir dans Chrome). Les données sont fictives et rien n'est relié à Salesforce : la maquette sert de référence pour l'écran et le comportement attendus.

## Ce que contient la maquette

- Trois pages : Accueil (à construire), Production, Paramétrage.
- Production : onglets → fiches → listes de vue → tableau, avec tri, filtres par colonne, modification des cases, sélection de 20 lignes au maximum et modification d'un champ en masse.
- Messagerie interne entre collègues, toujours liée à un client (piste ou dossier).
- Recherche d'un client, Récents, Actualiser, menu utilisateur avec déconnexion.
- Format téléphone et tablette complet, sans fonction retirée.

## Ce qui a changé dans cette version

### 1. Messagerie

- Une demande est toujours liée à un client. Dans « Nouvelle demande », le champ « Client concerné » est obligatoire ; la recherche propose 10 choix au plus, affinés à chaque lettre, avec la fiche et l'état pour distinguer deux dossiers d'un même client.
- Quatre listes : À traiter, Non lus, En attente, Traité.
- Sur l'onglet Messagerie : pastilles « à traiter » et « non lus » cliquables (elles ouvrent leur liste) et pastille « + New » pour écrire sans quitter sa page. L'onglet est rose et clignote seulement s'il reste des demandes à traiter.
- Dans la fiche d'un client : encadré « Messagerie du client » avec tous les échanges depuis le premier.
- L'enveloppe en bout de ligne ouvre cette Messagerie du client, avec « Nouvelle demande sur ce client » (client verrouillé). Pas d'enveloppe dans l'onglet Messagerie lui-même.

### 2. Recherche d'un client

- Une seule recherche, sur la barre des onglets. Si le client est dans les listes de l'utilisateur : elle propose ces listes et y conduit. Sinon : seulement l'objet, la fiche et l'état, sans lien vers la fiche.
- Bouton « Messages (n) » sur chaque client trouvé : historique des échanges de toute la société sur ce client. C'est une décision métier ; dans Salesforce, il faudra une autorisation explicite, vérifiée côté serveur.

### 3. Attribution

- « M'attribuer la sélection » existe dans les listes « Attribution » de Leads, Data et Confirmation, et uniquement dans ces listes.
- Toute personne qui voit la liste peut s'attribuer des pistes ; la piste passe alors dans la première liste de travail.

### 4. Présentation

- Compteurs des fiches et des listes : rose dès 1 élément, vert à zéro.
- Bouton « Modifier un champ en masse ».
- Nom de l'utilisateur affiché en entier.
- Ligne « Filtres » visible seulement quand un filtre est posé.

### 5. Format téléphone et tablette (écran de 960 px de large ou moins)

- Recherche et Messagerie restent collées en haut de l'écran.
- Onglets, fiches et listes de vue en rangées à faire glisser.
- Une carte par ligne : nom du client, puis prochaine action, puis le reste ; titres de colonnes en rangée « Trier · filtrer ».
- Un seul appui ouvre la saisie d'une case ; fenêtres en plein écran ; boutons de 40 à 44 px.
- Le bandeau « à attribuer » n'est pas affiché sur téléphone.

## Contrôles effectués

Deux relectures complètes du code et tests rejoués dans le navigateur, sans erreur :

- sur ordinateur : 207 listes, 475 filtres, 299 cases modifiables, enregistrement, modification en masse, attribution, Messagerie, recherche, Paramétrage ;
- à la largeur d'un téléphone (375 et 320 px) : toutes les listes sans débordement.

Aucun essai n'a été fait sur un vrai téléphone.

## Points à traiter côté Salesforce

- **Identifiant unique** : la maquette retrouve un enregistrement par son nom et sa fiche. Il faut utiliser l'Id Salesforce partout (recherche, Messagerie, historiques), sinon deux homonymes se confondent.
- **Droits de lecture de la Messagerie** : à appliquer côté serveur.
- **Textes saisis** : ne jamais les insérer en HTML brut. Deux colonnes de Prévisite (infos dossier, pré-visiteur) ne sont pas encore protégées dans la maquette.
- **Avertissement « modifications non enregistrées »** : si l'enregistrement est refusé, la maquette quitte quand même l'écran. À corriger dans le composant.
- **Data** : un statut « Hors cible » fait sortir la piste de toutes les listes, faute de liste « Hors cible » dans cet onglet. À confirmer.
- **Messagerie** : la liste « À traiter » contient aussi les demandes envoyées, alors que la pastille ne compte que les demandes reçues.
- **Données d'exemple** : les listes Attribution de Leads, Data et Confirmation utilisent les mêmes noms, sans lien entre elles.
- **Fenêtre réduite** : en dessous de 960 px de large, une fenêtre d'ordinateur passe en format téléphone.
