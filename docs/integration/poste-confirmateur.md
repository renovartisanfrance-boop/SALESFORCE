# Poste confirmateur — guide de l'intégrateur Salesforce

> À lire avant de développer ou de déployer le poste confirmateur.
> Fonctionnel validé : `docs/analyse/04-poste-confirmateur.md`. Maquette : `docs/maquettes/maquette-confirmateur.html`.
> **Vues de travail** : **retiré** (ne pas développer). Les vues par profil restent des listes de vue Salesforce. **Onglets visibles par personne** : réglés **par l'intégrateur** (droits / menu du site), pas dans la page responsable.
> Noms d'API relevés **en lecture seule** dans l'org de production le **08/11/2026** (`sf sobject describe`).
> **Code couleur** : ✅ existe dans l'org · **🟨 Cx = À CONFIRMER** (par l'intégrateur, non bloquant) · **🟦 Ax = À CRÉER** · **🟥 Vx = À VÉRIFIER avant de déployer**.
> Chaque code renvoie à la liste d'actions ci-dessous : cochez-les au fur et à mesure.

---

## ★ VOS ACTIONS — à faire par l'intégrateur

### 🟨 À CONFIRMER par l'intégrateur (jaune) — vérifications rapides dans l'org, non bloquantes ; demander à Micke seulement en cas de doute

- [ ] **C1** — Champ qui porte la **fiche** de la piste : `TypeDeDossier__c` ? (autres candidats : `TYPE_DE_DOSSIER__c`, `DR_Type_dossier__c`, type d'enregistrement) → § 1, § 5
- [ ] **C2** — Champ **Provenance** affiché : `Apporteurs__c` ? (ou `CONFIRM_Provenance__c`, `NonREGIE_miniAppAff__c`, `Regie__c`) → § 1
- [ ] **C3** — Ordre de priorité de la **date et du créneau de rappel** : CONFIRM → REGIE → TELEPRO ? → § 1
- [ ] **C4** — Champ du **confirmateur attribué** : `Utilisateur__c` ou `Confirmateurs__c` ? → § 1
- [ ] **C5** — « Année de la maison » = `Ann_e_de_la_Chaudiere__c` (nom d'API trompeur) ? → § 2
- [ ] **C6** — AGRI : raison sociale et SIRET dans les mêmes champs `PRO_…` que le tertiaire ? → § 2
- [ ] **C7** — Statut de **signature du devis** d'une piste : `RES_Statut_Devis__c` ou `YS_Statut__c` ? → § 3
- [ ] **C8** — **Statut du dossier** : `PAC_STATUT_DOSSIER__c` ou le champ propre à chaque fiche ? → § 3
- [ ] **C9** — **Mécanisme qui crée le Dossier** (`Pro__c`) à la conversion (Flow ? Apex ?). Aucun lien direct Piste ↔ Dossier trouvé → § 2
- [ ] **C10** — **Vues de liste** exactes à brancher pour chaque fiche (Traitement, Rappels, Hors cible) → § 1
- [ ] **C11** — **Fichiers** : sont-ils attachés à la Piste, au Dossier ou aux deux ? À la conversion, les fichiers de la piste doivent-ils être liés au dossier créé ? → § 2

### 🟦 À CRÉER (bleu)

- [ ] **A1** — `User.Preferences_Ecran__c` : texte long (131 072), JSON des réglages du confirmateur → § 7
- [ ] **A2** — `Regle_Rappel__mdt` (ou objet de paramétrage modifiable par le responsable) : Fiche, Mode A/B, Délai, Provenance → § 7
- [ ] **A3** — `Champ_Obligatoire_Conversion__mdt` : Fiche, Objet, Champ API, Ordre → § 2
- [ ] **A4** — `Fiche_Confirmateur__mdt` : table des codes de fiche → § 5
- [ ] **A5** — Nouvelles règles de doublons dans `Doublon_Regle__mdt` + classes `DoublonRegle` : **téléphone toutes fiches** et **adresse** → § 4
- [ ] **A7** — `Lead.Consentement_Preuve__c` + `Lead.Consentement_Date__c` : preuve de la demande du client (règle à valider par Micke) → § 7
- [ ] **A8** — `Lead.CONFIRM_Premier_Appel__c` (date-heure) : premier changement de Traitement, pour l'indicateur « délai avant premier appel » → § 7
- [ ] **A9** — Vues de liste « **NRP 6x et +** », une par fiche → § 1
- [ ] **A10** — Champ **surface de serre** (AGRI) : aucun trouvé, à créer ou à identifier → § 2
- [ ] **A11** — **Menu du site** : garder le bandeau et le menu actuels (logo, Accueil, Pistes, Dossiers, Reporting Dossiers, Standard, Campagnes (REGIES), Plus, recherche, cloche, profil). Seuls ajouts : un élément **« Prévisite »** après « Dossiers », visible selon le réglage par confirmateur, et **« Page responsable »** dans « Plus », réservé aux responsables (audience du menu de navigation). Les LWC se placent **sous** le bandeau, dans les pages existantes.

- [ ] **A14** — **Filtre rapide dans les titres de colonnes** : uniquement dans le LWC (rien à créer dans Salesforce), appliqué sur les lignes déjà chargées. **Depuis le 09/11/2026, un seul composant LWC de liste (`listeDeVue`) sert à tous les écrans** : Pistes (Leads, Data, Confirmation) et Dossiers (Prévisite, Signature, Statut docs, Envoi en pose, Dépôt dossier). Mêmes fonctions partout : tri au clic sur le titre, filtre dans chaque titre (valeurs à cocher avec leur nombre, recherche au-delà de 8 valeurs, « contient… » pour le texte), barre des filtres actifs avec « Effacer les filtres », largeur des colonnes à la souris (double-clic = taille automatique), tri et largeurs gardés par liste dans `User.Preferences_Ecran__c` (A1). Le format est **identique à l'écran Confirmation** pour toutes les listes : case à cocher, modification en ligne (crayon, double-clic, ligne surlignée, barre Annuler / Enregistrer, enregistrement groupé en Apex avec `WITH USER_MODE`), icônes Fichiers et Historique, boutons Récents · SMS · Actualiser, Aide. Chaque écran ne fait que lui passer : la liste de vue (onglet → fiche → liste), ses colonnes et les colonnes modifiables. **Seuls les champs changent d'une liste à l'autre.**
- [ ] **A15** — **Listes de vue attribuées** (onglet « Listes de vue » de la page responsable), modifiables par la responsable (licence Partner Community, donc **pas une Custom Metadata**). Créer un objet de paramétrage `Config_Liste__c` : `Fiche__c` (code de la fiche), `Onglet__c` (liste : `Leads`, `Data`, `Confirmation`, `Prévisite`, `Signature`, `Statut docs`, `Envoi en pose`, `Dépôt dossier` ; **remplace `Profil__c`** depuis le 09/11/2026 : les listes sont rangées par onglet), `Liste__c` (nom ou Id de la vue de liste Salesforce), `Nom_Ecran__c` (nom affiché dans le poste), `Ordre__c` (nombre). Droits : création et modification pour la responsable, lecture pour les autres. **Pas de champ de réglage des filtres** (décision du 08/11/2026) : chacun filtre librement sur les colonnes de sa liste de vue.
      **Qui voit la liste** (09/11/2026 : **plus de création de liste dans le poste, ni de listes individuelles** ; les listes sont des listes de vue génériques gérées dans Salesforce, le poste ne fait que les afficher ; dans le pop-up d'une liste, **le nom et la liste de vue Salesforce sont en lecture seule** — `Nom_Ecran__c` et `Liste__c` de `Config_Liste__c` se règlent dans Salesforce, pas dans le poste). **Règle de hiérarchie (09/11/2026), la même dans tous les écrans : onglet → fiche → listes.** Une personne voit une liste si elle a **l'onglet** (A21) **et** si elle est cochée sur **la fiche** (A20), puis : listes communes de cet onglet sur cette fiche, sauf celles dont elle est retirée (en personne, ou via son profil). La barre des fiches de Pistes et Dossiers ne montre que les fiches de la personne. ~~`Liste_Individuelle__c`~~ : **objet abandonné le 09/11/2026**, ne pas le créer. **Personnes retirées d'une liste commune** : petit objet enfant **🟦** `Config_Liste_Exclusion__c` : `Config_Liste__c` (relation principal-détail), `Utilisateur__c` (recherche User, vide si retrait par profil) et **`Profil__c`** (liste de choix Télépro / Confirmateur / Secrétaire / Closer, vide si retrait d'une personne, 09/11/2026) ; un enregistrement par liste et par personne, ou par liste et par profil. « Retirer tous les profils » = un enregistrement par profil. La personne exclue (en nom, ou via son profil) ne voit pas cette liste commune, même si elle est cochée sur la fiche. Le code lit le profil de la personne depuis le champ de profil métier déjà utilisé pour A20 (🟨 à confirmer : `Profile.Name` ou champ dédié sur User).
      **Comment le code lit une liste individuelle** (**🟨** à confirmer avec l'intégrateur) : à la création, le LWC lit la liste de départ avec l'API `lightning/uiListsApi` (`getListInfoByName` : filtres et colonnes) et propose ses filtres ; pour chaque champ, **toutes les valeurs** viennent de la description de la liste de choix. **Champs modifiables = uniquement les colonnes de la liste de départ** (`displayColumns`). Les conditions de la liste sur des champs qui ne sont pas des colonnes (`filteredByInfo`) sont **reprises telles quelles, non modifiables**. L'Apex refuse tout autre champ. Ensuite l'Apex construit la requête lui-même (**SOQL dynamique** avec variables liées, champs limités à une liste autorisée, **`WITH USER_MODE`** pour respecter le partage) au lieu d'ouvrir la vue de liste. Une liste dont `Date_Fin__c` est dépassée n'est plus chargée (et un traitement de nuit peut la supprimer).
- [ ] **A16** — **Récemment ouverts** : la dernière ouverture vient de l'objet standard `RecentlyViewed` (`LastViewedDate`, **🟨** vérifier qu'il est alimenté pour les utilisateurs du site Experience). Pour le **nombre d'ouvertures et leurs heures**, créer un petit journal `Journal_Ouverture__c` (`Piste__c` lien Lead, `Utilisateur__c`, `Date_Ouverture__c`), écrit par le LWC à l'ouverture de la fiche et purgé après 30 jours. Les actions du jour viennent de `LeadHistory` (voir **🟥 V6**). **Tout est filtré sur l'utilisateur connecté** : `Journal_Ouverture__c.Utilisateur__c = UserInfo.getUserId()`, `LeadHistory.CreatedById = UserInfo.getUserId()`. Les SMS automatiques (créés par l'utilisateur système) ne sont affichés que s'ils suivent une action de cet utilisateur sur la même piste.
- [ ] **A17** — **Relances après NRP et priorités, par profil et par fiche** :
  - champ **`Lead.CONFIRM_Prochain_Appel__c`** (date-heure) pour les confirmateurs, et **`Lead.TELEPRO_Prochain_Appel__c`** (date-heure) pour les télépros ;
  - objet de paramétrage **`Regle_Relance__c`**, modifiable par la responsable (pas une Custom Metadata) : `Onglet__c` (**une seule règle par onglet, valable pour toutes les fiches** depuis le 09/11/2026 : `Leads`, `Data`, `Confirmation`, plus tard les onglets Dossiers ; `Fiche__c` et `Profil__c` ne sont plus utilisés pour les relances), `Champ_Traitement__c` (confirmateur : `CONFIRM_Traitement__c` ; télépro : **`RENO_Sous_Statut_Leads__c`**, « LEADS- Statut », confirmé par Micke), `Delais__c` (JSON NRP 1x→7x pour les confirmateurs, **1x→12x pour les télépros** : `30m`, `1h`, `2h`, `demi`, `lendemain`, `autre`), `Ordre_Priorite__c` (nouvelle, rappel, relance), **`Delai_Nouvelle__c`** (délai pour appeler une nouvelle piste : `15m`, `30m`, `1h`, `2h`, `demi`, `lendemain`) et **`Seuils_Retard__c`** (texte long JSON, **un seuil par valeur de statut**, en minutes, par exemple `{"▣ EN ATT DE TRAITEMENT":120,"🟨 NRP- 1x":60,"🟦 Rappel Nécessaire":30}`). Une piste est **en retard** quand l'heure prévue de son statut est dépassée de plus que le seuil de cette valeur. Heure prévue : nouvelle piste = date de création (ou d'attribution) + délai « nouvelle » ; NRP = prochain appel calculé (A17) ; rappel promis = date + début du créneau. Rien d'autre à créer : le code lit la valeur du statut et cherche sa ligne ; ce calcul sert au reporting « qui est en retard ». Les réglages de distribution (file d'attente, plafond…) restent **par fiche et par profil** : les garder dans un objet séparé ou dans des lignes `Fiche__c` distinctes. Le mode A/B et le délai « le plus vite possible » de **A2** peuvent y être regroupés : un seul objet ;
  - **calcul dans le déclencheur Apex de la Piste** (before update, quand le champ de traitement passe à un NRP et que la date ou le créneau ne sont pas modifiés en même temps), pour que **l'ancien et le nouvel onglet** en profitent. Plage de travail : 9h-19h30, fuseau Europe/Paris ;
  - tri du LWC : groupe de priorité (via **A13**), puis échéance ;
- [ ] **A18** — **Distribution automatique des pistes** (télépros et confirmateurs, par fiche ; code fourni par Claude, voir `04-poste-confirmateur.md` § « Distribution automatique ») :
  - **file d'attente = liste de vue « à attribuer » choisie par la responsable**, par fiche et par onglet (**Attribution Auto : seulement `Leads` et `Data`** depuis le 09/11/2026 ; l'attribution des confirmateurs n'est pas réglée dans cet onglet) (champ `Liste_Attribution__c` dans `Regle_Relance__c`, nom d'API de la liste de vue). Lecture côté Apex avec `ApexPages.StandardSetController` + `setFilterId(<Id de la liste de vue>)`, ce qui reprend exactement ses filtres. **🟥** Vérifier que chaque liste exclut les pistes déjà attribuées et reste sous 10 000 lignes ;
  - `User.Derniere_Activite__c` (date-heure), mis à jour par l'écran à chaque action : c'est la présence ; « absent » au-delà de 30 min ;
  - **nouvel utilisateur** : coché sur **aucune fiche** par défaut (aucune ligne créée dans le paramétrage fiche × personne) ; il ne reçoit rien tant que la responsable ne l'a pas attribué ;
  - **éligibilité d'un destinataire** = même profil + **a l'onglet de son métier** (Confirmation pour les confirmateurs, Leads ou Data pour les télépros) + cochée sur la fiche + présente + **même pays**. Créer `User.Pays__c` (liste FR / ES) et le pays de la fiche dans `Fiche_Confirmateur__mdt` (RES-060 = ES). Le contrôle du pays est fait **dans l'Apex de distribution** (verrou), pas seulement dans l'écran. Il complète **🟥 V3** (cloisonnement Espagne) ;
  - répartition équitable à la première action du jour, « donne-moi du travail » quand la liste est vide, rééquilibrage au traitement : **sans tâche planifiée** ;
  - **verrou** `SELECT … FOR UPDATE` sur les pistes déplacées, pour qu'une piste ne parte jamais à deux personnes ;
  - écriture dans le champ d'attribution existant (**🟨** télépro : `LOOKUP- Telepro`, utilisé par l'outil actuel de la responsable ; confirmateur : `Utilisateur__c`) ;
  - délai « fin » à la dernière étape (NRP 12x télépro, NRP 7x confirmateur) : plus de relance ni de distribution ;
  - **🟥** vérifier que changer le champ d'attribution donne bien l'accès en lecture et écriture à la nouvelle personne (règles de partage basées sur ce champ).
- [ ] **A19** — _(reporté : ira dans le reporting de l'activité, pas dans la page responsable)_ **Sécurité « licences désactivées »** (pistes et dossiers) : détection des utilisateurs **`User.IsActive = false`** (licence désactivée) qui ont encore des pistes ou des dossiers attribués. Les absences du jour ne sont **pas** concernées : la distribution automatique (A18) s'en charge.

  pour les champs d'attribution des Pistes (LOOKUP- Telepro, `Utilisateur__c`) et des Dossiers (`Confirmateurs__c` et champs secrétaire / closer, **🟨** à identifier). Calcul à l'ouverture de l'onglet Contrôle et chaque nuit (rapport du matin). Action unique **« Rebasculer dans la file automatique »** en Apex, en lot, avec verrou : on vide le champ d'attribution, et la piste ou le dossier repart dans la file ; une ligne d'historique par enregistrement. Pastille rouge sur la fiche **seulement** si un problème est détecté.

- [ ] **A12** — **Onglets bêta** : publier les nouveaux écrans dans des **onglets « bêta » à côté des onglets actuels** (qui restent en place), visibles par tous les profils concernés.
- [ ] **A13** — Table de correspondance **valeur de liste → groupe** (Custom Metadata `Groupe_Valeur__mdt` : NRP + nombre, Rappel, Hors cible, Conf OK, En attente). La logique du code s'appuie sur cette table, **jamais sur le texte des libellés**. L'affichage garde les libellés et émojis actuels.
- [ ] **A23** — **Mail auto** (onglet « Mail auto » de la page responsable, 09/11/2026, filtre par fiche) : nouvel objet **🟦** `Mail_Auto__c` : `Fiche__c` (code de la fiche, texte ou liste de choix comme A20), `Objet__c` (liste de choix : Piste / Dossier), `Evenement__c` (liste de choix des déclencheurs : `RDV_Confirme`, `Veille_RDV`, `Visite_Realisee`, `Devis_Sans_Reponse`, `Devis_Signe`, `Date_Pose`, `Docs_Incomplets`, `Dossier_Depose` ; 🟨 liste exacte à confirmer avec Micke et à relier aux champs de statut réels), `Modele_Email__c` (texte 255 : `DeveloperName` du modèle `EmailTemplate` ; les modèles sont créés dans Salesforce, pas dans le poste), `Delai__c` (liste de choix : Immediat / J-1_18h / J+1 / J+2 / J+3 / J+7), `Actif__c` (case). Un enregistrement par fiche et par événement. L'envoi lui-même : un flow ou Apex déclenché sur Lead / Dossier qui lit `Mail_Auto__c` pour la fiche et l'événement, vérifie l'adresse e-mail et le refus de communication (🟨 champ d'opt-out à confirmer : `HasOptedOutOfEmail` ou champ maison), envoie avec `Messaging.SingleEmailMessage` + le modèle, et trace une activité (`Task` ou `EmailMessage`) sur l'enregistrement. Les envois différés (J+1…) passent par un traitement planifié quotidien. Compteur « Envoyés (30 j) » = nombre de `EmailMessage` liés, par modèle, sur 30 jours.
- [ ] **A22** — **Contrôle du paramétrage** (dernier onglet de la page responsable, 09/11/2026) : aucun objet à créer. Une méthode Apex (ou le LWC) relit `Acces_Onglets__c`, `Equipe_Fiche__c`, `Config_Liste__c`, `Config_Liste_Exclusion__c`, `Mail_Auto__c` et `Fiche_Parametre__c`, et renvoie la liste des incohérences : personne sur une fiche sans onglet (rouge), onglet sans fiche (orange), onglet × fiche avec des personnes mais aucune liste commune (rouge), liste individuelle sans l'onglet ou la fiche (rouge), personne retirée de toutes les listes (orange), liste individuelle terminée, retrait inutile, fiche vide (information). Le nombre d'incohérences rouges s'affiche en pastille sur l'onglet. Pas de correction automatique : la responsable corrige elle-même.
- [ ] **A21** — **Accès aux sous-onglets de Pistes et de Dossiers** (onglet « Visibilité Onglets » de la page responsable, 09/11/2026) : objet **`Acces_Onglets__c`**, une ligne par utilisateur : `Utilisateur__c` (recherche User, unique), `Onglets_Pistes__c` (liste de sélection multiple : `Leads`, `Data`, `Confirmation`) et `Onglets_Dossiers__c` (liste de sélection multiple : `Prévisite`, `Signature`, `Statut docs`, `Envoi en pose`, `Dépôt dossier`). Un objet et non un champ sur User, car une responsable Partner Community ne peut pas modifier la fiche User des autres. Le LWC « Dossiers » n'affiche que les sous-onglets cochés. Droits : création / modification pour la responsable, lecture pour chacun sur sa ligne. Comme V11 : affichage seulement, la sécurité reste le partage Salesforce. Valeurs par défaut par profil (confirmées le 09/11/2026) : télépros `Leads` + `Data` ; confirmateurs `Confirmation` + `Signature` ; secrétaires `Prévisite` + `Statut docs` + `Dépôt dossier` ; closers `Envoi en pose`. **Un nouvel utilisateur n'a rien par défaut** (décision du 09/11/2026) : aucun onglet, aucune fiche, aucune liste ; la responsable règle tout dans Paramétrage, l'onglet Contrôle lui rappelle les nouveaux utilisateurs non paramétrés. Les valeurs par défaut ci-dessus servent de repère visuel (onglets habituels du profil en couleur, les autres grisés mais cochables). **🟦 Elles sont réglables par la responsable (09/11/2026, étoile « par défaut » sous chaque onglet de l'en-tête du profil)** : stocker la liste des onglets par défaut par profil dans `Fiche_Parametre__c` (un enregistrement par profil : `Profil__c`, `Onglets_Defaut__c` multi-sélection), et la lire à la création d'un utilisateur du portail pour pré-remplir `Acces_Onglets__c`, au lieu de coder les valeurs en dur.
- [ ] **A20** — **Équipes** (onglet « Équipes » de la page responsable, 08/11/2026) : objet personnalisé **`Equipe_Fiche__c`**, une ligne par case cochée : `Fiche__c` (code de la fiche, valeurs de `Fiche_Confirmateur__mdt`), `Utilisateur__c` (recherche User), `Profil__c` (liste : Télépro / Confirmateur / Secrétaire / Closer). Clé unique fiche + utilisateur + profil (règle de validation ou champ texte unique calculé par le code). **Ce n'est pas un groupe ni une règle de partage Salesforce** : c'est une simple table lue par notre code pour (1) la distribution (qui reçoit) et (2) l'affichage des listes communes (qui voit). Droits : création / suppression pour la responsable, lecture pour les autres profils du portail. **Fiches désactivées de l'affichage** : la responsable peut masquer une fiche où plus personne n'est coché. `Fiche_Confirmateur__mdt` n'étant pas modifiable par elle (Custom Metadata), stocker ce choix dans un petit objet **`Fiche_Parametre__c`** : `Fiche__c` (code, unique), `Desactivee__c` (case à cocher). Une fiche désactivée reste dans Salesforce ; elle est seulement cachée dans la page responsable.

### 🟥 À VÉRIFIER avant de déployer en production (rouge)

- [ ] **V10** — Le calcul du prochain appel (A17) ne doit pas entrer en conflit avec les **Flows SMS** existants déclenchés par les NRP : vérifier l'ordre d'exécution et l'absence de double mise à jour.
- [ ] **V11** — **Visibilité des listes = filtre de notre code, pas une sécurité.** Le poste n'affiche que les listes prévues pour la personne (Équipes + Listes communes, moins les retraits), mais l'accès réel aux pistes et dossiers reste décidé par le **partage Salesforce** (voir V2). Pour que le code puisse lire une liste de vue pour un utilisateur, **chaque liste de vue utilisée doit être partagée dans Salesforce avec tous les utilisateurs du portail concernés** (par exemple un groupe public « Portail - tous »), une fois pour toutes. Vérifier aussi que la licence Partner Community donne bien accès aux nouveaux objets (`Equipe_Fiche__c`, `Config_Liste__c`, `Config_Liste_Exclusion__c`, `Fiche_Parametre__c`, `Acces_Onglets__c`).
- [ ] **V0** — Avant d'ouvrir la bêta : tester en sandbox **toutes les actions qui enregistrent** (traitement, échéance, fiche client, conversion, fichiers). Les deux onglets modifient les mêmes données.

- [ ] **V1** — Droits du profil « PORTAIL INTERNE - Confirmateur » (lecture / écriture champ par champ) sur tous les champs de ce guide, et sur `User.Preferences_Ecran__c` pour sa propre fiche.
- [ ] **V2** — **Partage** : aujourd'hui ce profil lit et modifie **les 1 686 dossiers** via les règles de partage vers les groupes (« Résidentiel- Resp Confirmateurs »…). Cible : « ses dossiers uniquement ». À valider avec Micke.
- [ ] **V3** — Cloisonnement **Espagne** (RES-060) : les équipes ES ne voient pas les dossiers français, et inversement.
- [ ] **V4** — Retirer NRP 6x et 7x des filtres des vues « Traitement Conf ».
- [ ] **V5** — Flows existants : création du dossier, SMS automatiques (NRP 1x et 3x), et règles de validation `Previsite_2_tertiaire` et `Conversion_VerificationTERTIAIRE`.
- [ ] **V6** — **Suivi de l'historique** activé sur Traitement, Date et Créneau conf, Commentaire conf (20 champs maximum par objet).
- [ ] **V7** — Fuseau horaire Europe/Paris pour le calcul des échéances.
- [ ] **V8** — Affichage des **libellés** et non des noms d'API pour toutes les listes de choix (§ 6).
- [ ] **V9** — **Fichiers dans le site** : les utilisateurs partenaires voient-ils les fichiers ajoutés en interne ? (`ContentDocumentLink.Visibility` doit être `AllUsers`.) Peuvent-ils en ajouter (droits du profil, réglage du site, taille maximale) ?

---

## 0. Règles de déploiement

- Développer et tester dans la **sandbox** d'abord. **Aucun déploiement en production sans l'accord écrit de Micke.**
- Nouveau code dans `force-app/` : Trigger → Handler → Service → Selector, `with sharing`, `WITH USER_MODE`, code bulkifié, tests ≥ 85 %, Jest pour chaque LWC.
- Le poste confirmateur **fonctionne déjà** sur le site Experience « business saas » : cette version est une **refonte visuelle avec quelques fonctions en plus**. Elle réutilise les champs, vues de liste, Flows et règles existants. Ne rien casser de l'existant.

## 1. Onglet Pistes — colonnes (objet `Lead`, libellé « Piste »)

| Élément à l'écran                  | Champ (API)                                                                                                    | Libellé dans l'org                              | Type             | État                                 |
| ---------------------------------- | -------------------------------------------------------------------------------------------------------------- | ----------------------------------------------- | ---------------- | ------------------------------------ |
| Filtre « fiche »                   | `TypeDeDossier__c`                                                                                             | Type de dossier                                 | liste multiple   | **🟨 C1**                            |
| Créé le                            | `CreatedDate`                                                                                                  | Date de création                                | date/heure       | ✅                                   |
| Provenance (texte)                 | `Apporteurs__c`                                                                                                | DR- Apporteurs                                  | texte            | **🟨 C2**                            |
| Provenance Régie / Interne (icône) | `LeadSource`                                                                                                   | Origine de la piste                             | liste            | ✅ INTERNE, REGIES, LEADS, DATA-…    |
| Nom complet                        | `Name` (`FirstName`, `LastName`)                                                                               | Nom                                             | —                | ✅                                   |
| Téléphone                          | `Phone`                                                                                                        | Téléphone                                       | téléphone        | ✅ (`MobilePhone` = « Téléphone 2 ») |
| Doublon ✔ / ⚠                      | `Doublon_Telephone_Indicateur__c` + `Doublon_Telephone__c`                                                     | Doublon - Téléphone / Groupe téléphone          | formule / lien   | ✅ existe, **🟦 A5**                 |
| Échéance — date                    | `ENVOI_CONF_Date_de_Rappel__c`                                                                                 | CONFIRM- Date de Rappel                         | date             | ✅                                   |
| Échéance — créneau                 | `ENVOI_CONF_Cr_neau_de_Rappel__c`                                                                              | CONFIRM- Créneau de Rappel                      | liste            | ✅ (valeurs § 6)                     |
| Échéance si pas de date conf       | `REGIE_Date_de_Rappel__c`, `REGIE_Creneau_Rappel__c`, `TELEPRO_Date_de_Rappel__c`, `TELEPRO_Creneau_Rappel__c` | REGIE- / TELEPRO- …                             | date / liste     | **🟨 C3**                            |
| Traitement                         | `CONFIRM_Traitement__c`                                                                                        | CONFIRM- Traitement                             | liste            | ✅ 27 valeurs                        |
| Commentaire conf                   | `CONFIRM_Commentaire__c`                                                                                       | CONFIRM- Commentaire                            | texte long       | ✅                                   |
| Commentaire régie / télépro        | `REGIE_Commentaire_Regie__c` / `Telepro_Commentaire_pour_Confirmateur__c`                                      | REGIE- Commentaire Regie / TELEPRO- Commentaire | texte            | ✅                                   |
| Confirmateur attribué              | `Utilisateur__c`                                                                                               | LOOKUP- Confirmateur                            | lien Utilisateur | **🟨 C4**                            |
| Motif hors cible                   | `Motif_Hors_cible__c`                                                                                          | Motif Hors cible                                | liste            | ✅                                   |
| Historique                         | `LeadHistory`                                                                                                  | —                                               | —                | **🟥 V6**                            |

Listes de la fiche (sous-niveau) :

| Liste à l'écran | Règle                                                               | Vue de liste Salesforce                                        |
| --------------- | ------------------------------------------------------------------- | -------------------------------------------------------------- |
| Traitement conf | « ▣ EN ATT DE TRAITEMENT » ou NRP 1x à 5x                           | ex. « 2.1BAT Régies- Traitement Conf » — **🟨 C10**, **🟥 V4** |
| Rappels conf    | « 🟦 Rappel Nécessaire » (API `🟦 A Rappeler`) ou échéance dépassée | ex. « 2.2BAT Régies- Rappels Conf » — **🟨 C10**               |
| NRP 6x et +     | « 🟨 NRP- 6x » ou « 🟨 NRP- 7x + Mail/SMS »                         | **🟦 A9**                                                      |
| Hors cible      | toutes les valeurs « ⬛ HORS CIBLE… »                               | **🟨 C10**                                                     |

## 2. Fiche client — ouverte par un clic sur le nom (conversion) (objet `Lead`)

Champs communs : `FirstName`, `LastName`, `Phone`, `Email`, `Street`, `PostalCode`, `City` ✅ (adresse transmise par la régie : `REGIE_Adresse_Client__c`).

| Groupe  | À l'écran                               | Champ (API)                                                                                                              | Libellé                                    | État       |
| ------- | --------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------ | ---------- |
| RES     | Type de chauffage                       | `Type_de_Chauffage__c`                                                                                                   | RES- Type de Chauffage                     | ✅         |
| RES     | Surface habitable                       | `Surface_habitable__c`                                                                                                   | RES- Shab                                  | ✅         |
| RES     | Année de la maison                      | `Ann_e_de_la_Chaudiere__c`                                                                                               | RES- Année de la Maison                    | **🟨 C5**  |
| RES     | Catégorie de revenus                    | `Bareme_Ma_prim_renovv__c`                                                                                               | RES- Précarité                             | ✅         |
| RES     | Propriétaire occupant                   | `Situation_du_demandeur__c`                                                                                              | RES- Statut Occupation                     | ✅         |
| RES-060 | Bono social, année chaudière            | `RES_Bono_Social__c`, `RES_Ann_e_Chaudi_re__c`                                                                           | RES- Bono Social / RES- Année Chaudière    | ✅         |
| TER     | Raison sociale                          | `PRO_Nom_du_Signataire__c`                                                                                               | PRO- Raison Sociale (⚠ nom d'API trompeur) | ✅         |
| TER     | SIRET, code APE, siège                  | `PRO_Numero_de_Siret__c`, `PRO_Code_APE__c`, `PRO_Siege_Social_Adresse_numero_et_voie__c`                                | PRO- …                                     | ✅         |
| TER     | Nombre de logements / de précaires      | `PAC_Nb_Logements__c` / `PAC_179_Logements_Pr_carite__c`                                                                 | PAC 179- …                                 | ✅         |
| TER     | Signataire                              | `PRO_Pr_nom_du_Signataire__c`, `PRO_Fonction_du_Signataire__c`, `PRO_T_l_phone_Signataire__c`, `PRO_Email_Signataire__c` | PRO- … Signataire                          | ✅         |
| AGRI    | Raison sociale, SIRET                   | mêmes champs PRO                                                                                                         |                                            | **🟨 C6**  |
| AGRI    | Surface de serre                        | —                                                                                                                        | —                                          | **🟦 A10** |
| Toutes  | Liste des champs obligatoires par fiche | —                                                                                                                        | —                                          | **🟦 A3**  |

Fichiers et historique (volet de droite de la fenêtre, et bouton trombone de la ligne) :

| À l'écran                                                      | Source Salesforce                                                                                                                                                                 | État                    |
| -------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------- |
| Liste des fichiers (nom, date, taille, type, aperçu)           | `ContentDocumentLink` (`LinkedEntityId` = Id de la piste) → `ContentVersion` (`Title`, `FileExtension`, `ContentSize`, `CreatedDate`)                                             | ✅ standard, **🟨 C11** |
| Miniatures (photos et 1re page des PDF) sans ouvrir le fichier | rendu fourni par Salesforce : `/sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB240BY180&versionId=<ContentVersionId>` (préfixer avec le chemin du site Experience) | ✅ standard, **🟥 V9**  |
| Agrandir au clic, sans télécharger                             | rendu `THUMB720BY480` en grand, ou aperçu standard (`NavigationMixin`, page `filePreview`)                                                                                        | ✅ standard             |
| Ajouter des fichiers                                           | composant standard `lightning-file-upload` (`record-id` = Id de la piste)                                                                                                         | ✅ standard, **🟥 V9**  |
| Historique                                                     | `LeadHistory` (+ SMS automatiques si tracés)                                                                                                                                      | **🟥 V6**               |

Prévisite : `N_cessite_Pr_visite__c` (PREVISITE- Nécessité), `PREVISITE_Statut__c`, `PREVISITE_Nom_St__c` / `LOOKUP_Previsiteur__c`, `Date_de_Previsite__c`, `PREVISITE_Fiche_Residentiel__c` / `_Tertiaire__c` / `_Agri__c` ✅.

Conversion :

- `Status` passe à `Qualified` (« ✅Converti »).
- Le champ « Création Dossier » de la fiche passe à OUI (§ 5).
- Respecter `Previsite_2_tertiaire` et `Conversion_VerificationTERTIAIRE` (**🟥 V5**).
- Création du `Pro__c` : **🟨 C9**.

## 3. Fenêtre « Doublon possible » — statuts affichés

| Fiche en double | À l'écran                              | Champ (API)                                                                                                              | État      |
| --------------- | -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ | --------- |
| Piste           | Provenance (régie ou télépro)          | `Apporteurs__c` + `LeadSource` (même choix que **🟨 C2**)                                                                | ✅        |
| Piste           | Date de création                       | `CreatedDate`                                                                                                            | ✅        |
| Dossier         | Provenance                             | `DR_Provenance__c` (ADMIN- Apporteurs), `LeadSource__c`, `LOOKUP_Apporteur_d_affaires__c`                                | **🟨 C2** |
| Dossier         | Date de création de la piste d'origine | `Piste_Date_de_Cr_ation__c` (Piste- Date de Création), sinon `CreatedDate`                                               | ✅        |
| Piste           | Statut de la piste                     | `Status` (Annulée / ▣ Non Converti / ✅Converti)                                                                         | ✅        |
| Piste           | Traitement conf                        | `CONFIRM_Traitement__c`                                                                                                  | ✅        |
| Piste           | Motif d'annulation                     | `Motif_Hors_cible__c`                                                                                                    | ✅        |
| Piste           | Signature devis                        | `RES_Statut_Devis__c` / `YS_Statut__c`                                                                                   | **🟨 C7** |
| Dossier         | Fiche, téléphone, adresse              | `Fiche_CEE__c`, `Phone__c`, `Adresse__c`, `Client_Adresse_Chantier__c`                                                   | ✅        |
| Dossier         | Statut du dossier                      | `PAC_STATUT_DOSSIER__c` ou `PAC_TH171_Statut_Dossier__c`, `PAC_TH179_Statut_Dossier__c`, `RENO_TH174_Statut_Dossier__c`… | **🟨 C8** |
| Dossier         | Motif et date d'annulation             | `RDV_Motif_Annulation__c`, `RDV_Date_Dossier_Annul__c`                                                                   | ✅        |
| Dossier         | Signature devis                        | `Devis_Statut__c`, `DEVIS_Date_Signature__c`                                                                             | ✅        |
| Dossier         | Statut installation                    | `INSTALLATIONN_PAC__c`, `PAC_Date_d_Installation__c`                                                                     | ✅        |

## 4. Doublons — moteur existant à étendre (ne pas le refaire)

- Déjà en place : classe `DoublonService`, règles `Doublon_Regle__mdt`, groupes `Doublon_Groupe__c`, liens `Lead.Doublon_Telephone__c` / `Pro__c.Doublon_Telephone__c`, indicateur `Lead.Doublon_Telephone_Indicateur__c`.
- **Une seule règle active** : `TELEPHONE_RES060` (classe `DoublonRegle_TelephoneRes060`), limitée à RES-060.
- À ajouter : **🟦 A5** (téléphone toutes fiches, adresse). La fenêtre doublon est en **consultation seule** : seulement une croix pour fermer. Si elle a été ouverte depuis la fiche client, la fermeture ramène sur cette fiche.

## 5. Codes de fiche ↔ valeurs Salesforce (**🟨 C1**, à ranger dans **🟦 A4**)

| Code écran | `Lead.TypeDeDossier__c` (API ⇒ libellé)                        | Champ « Création Dossier »                       |
| ---------- | -------------------------------------------------------------- | ------------------------------------------------ |
| RES-171    | `RESIDENTIEL_REGIES_-_TH171` ⇒ 🟩BAR TH171- PAC Individuelle   | `PRO_DOSSIER_PAC_SEUL__c`                        |
| RES-174    | `RESIDENTIEL_REGIES_-_TH174` ⇒ 🟩BAR TH174- Rénovation Globale | `PRO_DOSSIER_RENO_GLOBALE__c`                    |
| RES-168    | `RESIDENTIEL_REGIES_-_TH168` ⇒ 🟩BAR TH168- Solaire            | `NEW_PRODUCT_8_RES168__c`                        |
| RES-060    | `RESIDENTIEL_REGIES_-_RES060` ⇒ 🟩BAR RES-060 PAC              | `NEW_PRODUCT_7_RES060__c`                        |
| TER-179    | `BAT_REGIES_-_TH179` ⇒ 🟩BAR TH179- PAC Collective             | `PRO_DOSSIER_SERRE_AGRICOLE__c` (⚠ nom trompeur) |
| TER-163    | `BAT_REGIES_-_TH163` ⇒ 🟩BAT TH163- PAC Tertiaire              | `NEW_PRODUCT_5__c`                               |
| AGRI-108   | `AGRI_REGIES_-_TH117` (⚠) ⇒ 🟩AGRI TH108- PAC Serres           | `NEW_PRODUCT_1__c`                               |
| AGRI-119   | `AGRI_REGIES_-_TH119` ⇒ 🟩AGRI TH119- VMC                      | `NEW_PRODUCT_2__c`                               |

Autres champs « Création Dossier » : `PRO_DOSSIER_DESTRAT__c` (TH142), `NEW_PRODUCT_4__c` (EQ108).

## 6. Pièges : nom d'API ≠ libellé (**🟥 V8**)

| Champ                             | Nom d'API                     | Libellé à afficher                    |
| --------------------------------- | ----------------------------- | ------------------------------------- |
| `CONFIRM_Traitement__c`           | 🟩Conf Ok- Att prévisite      | 🟫Conf Ok- Visite en attente          |
| `CONFIRM_Traitement__c`           | 🟦 A Rappeler                 | 🟦 Rappel Nécessaire                  |
| `CONFIRM_Traitement__c`           | ⬛ HORS CIBLE- Trop petit     | ⬛ HORS CIBLE- Surface Trop Petite    |
| `ENVOI_CONF_Cr_neau_de_Rappel__c` | MATIN (10H-15H)               | MATIN (10H-13H)                       |
| `ENVOI_CONF_Cr_neau_de_Rappel__c` | SOIR (15H- 19H30)             | SOIR (14H- 19H30)                     |
| `Status`                          | Unqualified / New / Qualified | Annulée / ▣ Non Converti / ✅Converti |
| `TypeDeDossier__c`                | AGRI_REGIES_-_TH117           | 🟩AGRI TH108- PAC Serres              |

Plages horaires des créneaux pour le calcul de l'échéance (**🟥 V7**) :

| Créneau (libellé)                   | Début                              | Fin                                     |
| ----------------------------------- | ---------------------------------- | --------------------------------------- |
| LE PLUS VITE POSSIBLE               | création (ou 9h le jour de rappel) | + délai de la fiche (15 min par défaut) |
| MATIN (10H-13H)                     | 10h00                              | 13h00                                   |
| SOIR (14H- 19H30)                   | 14h00                              | 19h30                                   |
| 10H-11H / 11H-12H / 12H-13H30       | 10h00 / 11h00 / 12h00              | 11h00 / 12h00 / 13h30                   |
| 15H30-17H / 17H-18H30 / 18H30-19H30 | 15h30 / 17h00 / 18h30              | 17h00 / 18h30 / 19h30                   |

## 7. Détail des éléments à créer

| Code    | Élément                                                    | Contenu                                                                                                                      |
| ------- | ---------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| **A1**  | `User.Preferences_Ecran__c`                                | JSON `{version, largeurs, tris}` (format dans `04-poste-confirmateur.md`)                                                    |
| **A2**  | `Regle_Rappel__mdt`                                        | Fiche, Mode (A = le plus vite possible, B = toute la journée 9h-19h30), Délai (min, 15 par défaut), Provenance (optionnelle) |
| **A3**  | `Champ_Obligatoire_Conversion__mdt`                        | Fiche, Objet, Champ API, Ordre                                                                                               |
| **A4**  | `Fiche_Confirmateur__mdt`                                  | Table du § 5 + groupe RES / TER / AGRI / ES                                                                                  |
| **A5**  | Règles de doublons                                         | Téléphone toutes fiches (pistes non converties + dossiers), adresse normalisée                                               |
| **A7**  | `Lead.Consentement_Preuve__c`, `Lead.Consentement_Date__c` | Texte, date-heure (consentement préalable obligatoire depuis le 11/08/2026)                                                  |
| **A8**  | `Lead.CONFIRM_Premier_Appel__c`                            | Date-heure                                                                                                                   |
| **A9**  | Vues de liste « NRP 6x et + »                              | Une par fiche                                                                                                                |
| **A10** | Surface de serre (AGRI)                                    | Nombre (m²)                                                                                                                  |

## 8. Charge estimée

Estimation pour **un développeur Salesforce confirmé**, à affiner après les vérifications C1 à C11 :

| Lot                           | Contenu                                                                                                                      | Jours                                                             |
| ----------------------------- | ---------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------- |
| Cadrage                       | Vérifications C1-C11 dans l'org, sandbox prête                                                                               | 1                                                                 |
| Modèle de données             | A1-A10, droits du profil, vues de liste                                                                                      | 3                                                                 |
| Apex                          | Lecture des vues, attribution, échéances, conversion, préférences, historique, extension des doublons + tests ≥ 85 %         | 7                                                                 |
| LWC Pistes                    | Liste, modification, tri, largeurs, bandeau, attribution, filtres de colonnes, Récents, doublons, fiche client et conversion | 12                                                                |
| LWC Prévisite                 | Onglet prévisite sur `Pro__c`                                                                                                | 3                                                                 |
| LWC Reporting                 | Reporting dossiers, version mobile                                                                                           | 3                                                                 |
| Page responsable              | Fiches × confirmateurs, vues, onglets, règles de rappel                                                                      | 6                                                                 |
| Tests Jest                    | Un test par composant                                                                                                        | 3                                                                 |
| Recette et mise en production | Recette sandbox avec Micke, corrections, partage (V2, V3), déploiement                                                       | 5                                                                 |
| **Total**                     |                                                                                                                              | **≈ 43 jours (≈ 9 semaines)** si tout est écrit par l'intégrateur |

- **Première version utile** (Pistes + attribution + doublons + fiche client et conversion) : environ **25 jours**.

### Scénario retenu par Micke : code livré prêt à déployer

1. L'intégrateur vérifie C1 à C11 dans l'org (rapide, non bloquant).
2. Le code (LWC, Apex, tests, métadonnées A1 à A10) est écrit dans `force-app/`, déployé et recetté dans la **sandbox pcp1**, puis validé par Micke à l'écran.
3. L'intégrateur fait la relecture, les vérifications **V1 à V9**, puis le déploiement en production avec l'accord de Micke.

Charge de l'intégrateur dans ce scénario : **1 jour**, ou 2 jours si un point de partage ou de droits (V1 à V3) doit être corrigé.
