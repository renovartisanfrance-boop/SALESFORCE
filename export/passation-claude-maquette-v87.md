# Passation pour un autre Claude : maquette du portail, version 87

Date : 13/11/2026. Auteur de la session : micke (non développeur : répondre en français, simplement, conclusion d'abord).

## 1. Le sujet

Maquette cliquable du portail Renov Artisan France, en **un seul fichier** :

- `docs/maquettes/maquette-confirmateur.html` (≈ 350 Ko, HTML + CSS + JS, fins de ligne **CRLF**, lignes très longues).
- Données fictives, aucun serveur, aucune écriture dans Salesforce. Personne connectée simulée : `ME={nom:"Chauvet",profil:"Confirmateur"}`, heure simulée 05/11/2026.
- Lien publié (privé) : https://claude.ai/artifact/CXonvxji8VUbyuc14Jbtbt (version 87). Republier ce même fichier avec cette URL pour garder le lien.
- Journal de la session : `journal/2026/11/2026-11-12_08h10_micke_messagerie.md` (une puce datée par changement ; le tenir à jour).
- Zips remis à l'utilisateur : `export/maquette-confirmateur_2026-11-13_v87.zip`, `export/maquette-confirmateur_v87_avec-recapitulatif.zip` ; récapitulatif pour le développeur : `export/recapitulatif-maquette-v87.md`.

## 2. Règles à respecter (non négociables)

- **Rien sur GitHub sans oui explicite** de l'utilisateur (commit et push). Il ne l'a jamais donné dans cette session ; `docs/maquettes/` n'est pas suivi par git.
- **Aucune écriture ni déploiement sur l'org de production** sans oui explicite ; essais sur la sandbox `pcp1`. Tout ce travail est local, sur la maquette.
- **Aucun téléchargement** sans permission (ex. police d'icônes Tabler : demandée, jamais accordée ; les icônes `ti-*` sont donc invisibles sur claude.ai, les boutons importants sont dessinés en SVG ou en caractères).
- Jamais de mot de passe, jeton ou URL d'authentification dans le dépôt.
- Ne jamais modifier « RES060- Retour calculateur ».
- Depuis le 09/11/2026 : ne plus écrire de specs ni de guide intégrateur à chaque évolution d'écran (commentaires de code et journal suffisent), sauf demande explicite.
- Tout écran de Paramétrage reprend la présentation de « Visibilité Onglets » (personnes par profil en lignes, cases en colonnes).
- **Format téléphone obligatoire** : toute évolution doit rester utilisable à 375 px, sans retirer de fonction.
- Avant d'installer une skill, un plugin ou un serveur MCP : lire son contenu, donner un avis de risque, attendre un oui.

## 3. Méthode de travail qui fonctionne

- **Modifier** : petits changements avec l'outil Edit ; changements multiples avec un script Node à ancres uniques (`rep(ancre, remplacement)` qui échoue si l'ancre est absente ou en double), écrit dans le scratchpad puis lancé avec `node script.js <fichier>`. Écrire le script avec l'outil Write ou un heredoc `<<'EOF'` (les apostrophes cassent les `node -e`).
- **CRLF** : ne jamais utiliser `sed -i` sur le fichier (il supprime les CR). Après un Edit multi-lignes, vérifier que le nombre de `\r\n` égale le nombre de `\n` et renormaliser si besoin.
- **Contrôle du code** : extraire le contenu des balises `<script>` dans un fichier `.js` (en gardant les numéros de ligne), puis `node --check` et ESLint (`node_modules/eslint`, config plate avec les globales du navigateur). Objectif : **0 alerte**. Utiliser `window.matchMedia`, `window.MutationObserver`, etc. (sinon « is not defined »).
- **Tests** : navigateur intégré (`mcp__Claude_Browser__*`), `navigate` vers `file:///C:/Users/Mike/Projets/SALESFORCE/docs/maquettes/maquette-confirmateur.html?x=N` puis `javascript_tool`.
  - Le panneau ne recharge pas toujours la page si le fichier n'a pas changé : fermer l'onglet (`tabs_close`) puis renaviguer pour repartir d'un état neuf (repère : `MSGS.length === 11` et 12 onglets au départ).
  - Format téléphone : `resize_window` (preset `mobile` ou largeur/hauteur) **puis** `navigate` ; vérifier `innerWidth` dans le script, car un nouvel onglet perd l'émulation. Remettre `desktop` à la fin.
  - Les clics programmés n'envoient pas `blur` : pour valider une saisie, `g.focus()` puis `g.dispatchEvent(new Event('blur'))`. L'éditeur d'une case est `.gled` (ou la fenêtre `#glmp` pour les choix multiples et les liens).
  - Un test qui coche et décoche toutes les cases du Paramétrage laisse Chauvet sans onglet (cases de profil à trois états) : recharger avant les tests suivants.
- **Relecture indépendante** : un sous-agent en lecture seule, avec la liste des points déjà connus à ne pas re-signaler, a trouvé à chaque fois des défauts réels. Vérifier ses points dans le navigateur avant de corriger.

## 4. Architecture utile du fichier

- Navigation : `PTAB` (onglet), `PFI` (fiche), `EXTI` (type d'externe), `LSEL[o+fi]` (liste), `MSGL` (liste de la Messagerie). `prodDraw()` redessine toute la page Production ; `drawResp()` le Paramétrage ; `drawAlert()` le bandeau « à attribuer ».
- Données : `ONGLETS`, `FICHES`, `myTabs()`, `myFiches()`, `visLists(nom,o,fi)`, `tabRows(o,fi)`, `listRows(o,fi,L,all)`, `tabSpec(o,fi,L,all)` (colonnes et options par onglet).
- Tableau commun : `glTable(host,id,cols,rows,foot,o)` avec état `GLS[id]` (tri, filtres `qf`, brouillons `ed`, sélection). `glDrafts()` renvoie un **nombre**. Limites : `SELMAX=20`, `GLPAGE=50`. Options : `o.save`, `o.bulk=[{l,f}]`, `o.files`, `o.hist`. Le tableau se redessine seul : **ne jamais poser d'écouteur ligne par ligne** depuis l'extérieur, déléguer au `document`.
- Fenêtres : `openG(icône,couleur,titre,sous-titre,corps,pied)` / `closeG()` (`#ovg`), `#ov` (attribution), `toast(texte)`.
- Messagerie : `MSGS` (chaque demande a un `rec` {type, nom, fi, tel, st}), `msgNew(rec0)` (client verrouillé si `rec0`), `msgOpen` (panneau `#mpan`), `msgRecBox(nom,fi,all)` (encadré `.mrb` « Messagerie du client »), `recHist(rec)` (enveloppe d'une ligne), `msgRefresh()`, `MSG_LF` (filtres des 4 listes), `msgTodo()`, `msgUnreadN()`.
- Recherche : `#gsq`, `gsIndex()`, `gsDraw()`, `gsGo`, `gsOpen`, `gsHist` (panneau `#gsr`).
- Attribution : Confirmation = `PENDING` + `take(ids)` ; Leads et Data = `psAttr(o,fi)` / `psTake(o,fi,lignes)` (réserve `PSATT`, copie figée de `PENDING`).
- Garde « modifications non enregistrées » : écouteur en capture qui affiche `#navq` (Rester / Abandonner / Enregistrer).
- Échappement : `glEsc()` pour tout texte inséré en HTML.
- CSS responsive : un bloc `@media (max-width:960px)` « FORMAT TÉLÉPHONE » en fin de `<style>`, un bloc tablette 700–960 px (deux cartes côte à côte), un bloc ≤ 360 px. Les écouteurs JS du téléphone sont filtrés par `window.matchMedia("(max-width:960px)")`. `.dsq` (Messagerie + recherche + Récents + Actualiser) est en `display:contents` sur ordinateur et devient une barre collante en haut sur téléphone.

## 5. Ce qui a été fait dans cette session (versions 70 → 87)

- Messagerie : liste « Non lus » ; pastilles cliquables et « + New » dans l'onglet (rose et clignotant seulement s'il reste des demandes à traiter) ; demande toujours liée à un client (« Client concerné », 10 choix au plus affinés à la frappe) ; encadré « Messagerie du client » dans les fiches ; enveloppe des lignes → Messagerie du client + « Nouvelle demande sur ce client » ; pas d'enveloppe dans l'onglet Messagerie.
- Recherche unique sur la barre des onglets ; menu utilisateur avec déconnexion ; nom affiché en entier ; ligne « Filtres » seulement si un filtre est posé.
- « M'attribuer la sélection » dans les listes Attribution de Leads et Data (règle de l'utilisateur : quiconque voit la liste, et seulement dans ces listes).
- Compteurs des fiches et listes : rose dès 1, vert à 0.
- Format téléphone complet (cartes, rangées à glisser, saisie d'un appui, fenêtres plein écran, cibles de 40 à 44 px, bandeau « à attribuer » masqué), seuil porté de 820 à 960 px.
- Deux relectures complètes avec corrections (liens de la Messagerie perdus après tri, choix multiples au doigt, garde des brouillons, double conversion, échappements, débordements à 320 px et entre 821 et 927 px, etc.).

## 6. État des tests à la version 87

Sans erreur, ESLint 0 :

- Ordinateur : 207 listes (compteurs, tri), 475 filtres, 299 cases modifiables, 45 enveloppes, enregistrement, modification en masse, attribution ×3, Messagerie de bout en bout, recherche, Récents, Paramétrage (642 clics + 297 réglages de listes).
- Téléphone 375 et 320 px : 211 listes sans débordement, saisie au doigt, cases, attribution, enveloppe, recherche, conversation, Paramétrage, Contrôle.
- **Jamais essayé sur un vrai téléphone** (clavier, calendrier natif, glissement au doigt).

## 7. Points ouverts

Décisions de l'utilisateur (« laisse », « plus tard ») : ne pas y toucher sans nouvelle demande.

- Enregistrements retrouvés par nom + fiche (homonymes confondus) ; à remplacer par un identifiant unique, dans la maquette comme dans Salesforce.
- Data : un statut « Hors cible » sort la piste de toutes les listes (pas de liste « Hors cible »).
- Liste « À traiter » de la Messagerie : contient aussi les demandes envoyées, la pastille ne compte que les reçues.
- Historique des messages visible pour toute la société : décision métier ; à porter dans Salesforce comme une autorisation explicite, côté serveur.

Connus, non traités :

- `#navq` : « Enregistrer » quitte l'écran même si `o.save` refuse.
- Prévisite : `inf` et `pvr` insérés sans `glEsc`.
- `PSATT` sans lien avec `PENDING` entre onglets (mêmes noms d'exemple dans trois listes).
- Sous 960 px, une fenêtre d'ordinateur réduite passe en format téléphone.
- Une réponse simulée reçue pendant que la conversation est ouverte compte comme non lue.
- Sur téléphone, toucher une autre case pendant une saisie valide la première mais n'ouvre pas la seconde (second appui nécessaire, supposé).
- Accueil (reporting) à construire ; onglets de Paramétrage « Grilles tarifaires » et « Traitement rapide » en attente ; actualisation multi-utilisateurs non faite.

## 8. Autres sessions sur le même fichier

Une session parallèle a fait l'« allègement visuel » le 13/11 (tableau pleine largeur, `fitHeads`, notes intégrateur masquées, 6 tailles de texte). Deux sessions qui éditent ce fichier en même temps s'écrasent : relire l'état du fichier avant de modifier, et vérifier avec l'utilisateur qu'aucune autre session ne travaille dessus.
