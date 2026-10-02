# Entretien métier avec Micke

> BMAD — étape 1 (analyste). Questions posées bloc par bloc ; réponses de Micke et constats dans les données de production.
> Ce document est la référence fonctionnelle de la nouvelle version.

## Bloc 1 — Entrée des dossiers

### Canaux d'entrée (réponse de Micke)

| Canal | Fonctionnement |
|---|---|
| **Standard téléphonique** | Quelqu'un appelle le standard et transmet un dossier ; saisie manuelle. |
| **Télépro en ligne** | Le télépro crée le lead à la main pendant l'appel. |
| **Formulaires de pub** | Formulaires publicitaires envoyés automatiquement. |
| **Achat de leads** | Fournisseurs de leads. |
| **Site web / Campagnes** | Formulaires internet. |
| **Parrainage** | Objet Campagne : des **parrains** sont créés via une page internet et un portail, **signent leur contrat**, puis **insèrent des filleuls**. |
| **Régies** | Société externe avec son propre traitement, qui **insère un rendez-vous avec les prérequis, prêt à confirmer par le confirmateur** (elle remplace l'étape télépro). |

Données : 637 campagnes (type `Event`), 944 membres de campagne.

### Marchés (réponse de Micke)

**Résidentiel, Agricole, Tertiaire, Transport, Industrie** — tous conservés.
Aujourd'hui en types d'enregistrement : RESIDENTIEL, AGRI, BAT (tertiaire), TRA ; **Industrie n'existe pas encore**.

### Pays (réponse de Micke)

**France et Espagne**, même principe. En Espagne, les fiches sont celles du système espagnol (ex. `RES060` PAC).
Données : ~25 % des leads des 5 derniers mois ont rempli le formulaire espagnol (champ `RES060__c` « Bono social »).
Le pays n'est pas fiable dans les données (`Country` vide ou saisi librement : FRANCE, France, FR, España, Spain…).

### Fiches CEE réellement utilisées (dossiers `Pro__c` créés sur 5 mois : 349)

| Fiche | Dossiers | Marché |
|---|---|---|
| BAR-TH-171 — PAC individuelle | 243 | Résidentiel |
| AGRI-EQ-108 — Tubes | 38 | Agricole |
| BAR-TH-179 — PAC collective | 32 | Résidentiel collectif / tertiaire |
| BAR-TH-174 — Rénovation globale | 19 | Résidentiel |
| AGRI-TH-119 — VMC | 7 | Agricole |
| RES060 — PAC (Espagne) | 4 | Résidentiel ES |
| AGRI-TH-117 — Déshumidificateur | 3 | Agricole |
| BAR-TH-168 — Solaire | 2 | Résidentiel |
| TRA-SE-104 — Gonfleurs | 1 | Transport |

Statut CEE : En attente envoi → Déposé → Validation délégataire.

### Compléments (réponses de Micke)

- **Lead → dossier** : le dossier (`Pro__c`) est créé **après validation par le confirmateur**.
- **Espagne** : **équipes séparées**, qui ne doivent pas voir les dossiers français (et inversement) → cloisonnement par pays obligatoire.
- **Parrainage** : rémunération gérée par l'objet **Grille tarifaire** (qui gère tous les prix) ; pour l'instant **prix fixe** par filleul.
- **Formulaires de pub et achats de leads** : arrivent **automatiquement** dans Salesforce (outil à identifier).

### Constat (données)

`Pro__c` est **le vrai dossier client** (397 champs personnalisés), créé à partir du Lead.
Le Lead sert de fiche de prospection, puis le dossier vit sur `Pro__c`.

## Bloc 2 — Utilisateurs

### Télépro (11 utilisateurs, licence Partner)

| Sujet | Aujourd'hui | Nouvelle version |
|---|---|---|
| Attribution des leads | Le **responsable télépro distribue** les leads à la main | Idem (outil de distribution à prévoir pour le responsable) |
| Visibilité | — | **Ses leads + les dossiers issus de ses leads** (pour suivre ses résultats) |
| NRP | Compteur NRP 1x, 2x, 3x… puis le lead est **laissé de côté** | **Relances automatiques par SMS, e-mail et WhatsApp** (demande de Micke) |
| Téléphonie | **Aircall et Ringover** | À préciser (qui utilise quoi) |

### Confirmateur (5 utilisateurs, licence Partner)

| Sujet | Réponse de Micke |
|---|---|
| Ce qu'il vérifie | Une **liste de champs obligatoires qui bloquent la conversion** s'ils ne sont pas remplis : des **champs communs à toutes les fiches** + des **champs spécifiques à chaque fiche CEE**. |
| Réception — régies / externe | Une **vue filtrée** des leads venant des régies ou de l'externe, avec les informations nécessaires à la confirmation. |
| Réception — interne | Le télépro passe son statut Leads à **« Envoyé en confirmation »**. |
| Pré-visite | Si la fiche **nécessite une pré-visite**, le confirmateur le signale. Il la **planifie lui-même** s'il a la réponse du pré-visiteur en temps réel ; sinon il **convertit avec « passage demandé »**. Le résultat de la visite (effectuée ou autre) est ensuite géré **sur le dossier**. |
| Suite | Conversion de la piste (Lead) en dossier (`Pro__c`). |
| Visibilité | **Ses dossiers uniquement.** |

À retenir pour la nouvelle version : règles « champs obligatoires par fiche » paramétrables (Custom Metadata), sans code à modifier pour chaque nouvelle fiche.

### Secrétariat (licence Partner)

| Sujet | Réponse de Micke |
|---|---|
| Rôle | Gère la **pré-visite**, les **documents** et les **dépôts de dossiers** (aides). |
| Profils multiples | **Erreur historique** : un seul profil Secrétariat dans la nouvelle version. |
| Visibilité | **Tous les dossiers de son périmètre** (marché + pays). |

### Devis (réponse de Micke)

- Aujourd'hui : un **modèle PDF publiposté**, toujours le même, fait par le développeur ; « rien de réactif ».
- Nouvelle version : **devis automatisé par fiche CEE**, à partir d'un **modèle que l'on définira** ensemble (prix issus de la Grille tarifaire).

### Closer (licence Partner)

| Sujet | Réponse de Micke |
|---|---|
| Rôle | **Envoie en installation.** Intervient **après** : confirmation → pré-visite effectuée (si nécessaire) → documents récupérés. |
| SAV | Le **closer transmet aux sous-traitants**. Un accès Experience pour les sous-traitants (planning + SAV) était en cours de développement. |

Retrouvé dans le code : menu « Portail Sous-traitant » (Installation, SAV, Facturation), composants `lwc027_gestion_installations`,
`lwc027_facturation_installateur`, `lwc027_facturation_previsiteur` (modifiés en septembre 2026), 2 profils « Sous-traitant » sans connexion récente.

### Stock (réponse de Micke)

**À refondre entièrement** : un objet moderne, **dynamique**, simple, qui s'adapte sans développement **quand une nouvelle fiche est ajoutée**.

### Planning (réponse de Micke)

Ancien besoin (planification par distances entre codes postaux) : **à moderniser**.

### Apporteurs d'affaires et régies

| Sujet | Réponse de Micke |
|---|---|
| Apporteur | **Crée des régies**, **suit leurs dossiers** et **sa facturation**. Doit passer en utilisateur Experience. |
| Organisation actuelle | Ont un vrai compte utilisateur : **télépros, confirmateurs, secrétaires, apporteurs**. **Tout le reste est géré dans l'objet Campagne** (régies, pré-visiteurs, parrains). **Objectif : tout passer sur Experience.** |
| Rémunération régies / apporteurs | **Selon la grille tarifaire** (par régie / fiche). |
| Visibilité d'une régie | **Ses RDV + leur suite + sa facturation.** |

Constats (données) :
- 637 campagnes : **619 régies** (`EstREGIE__c`), **17 pré-visiteurs**, 1 « Régie » ; France 608, Espagne 29 ; 56 rattachées à une campagne parente (apporteur).
- **128 régies actives** (au moins un lead inséré sur 90 jours).
- Accès des régies / pré-visiteurs aujourd'hui : sites invités (Campagnes, Gestion Previsites) avec **jeton** (`CampaignToken__c`) et identifiants envoyés à une API externe — **pas de vrais comptes Salesforce**.
- ⚠️ Un champ `CERTIKO_Mot_De_Passe__c` stocke un mot de passe en clair sur la campagne (1 renseigné).

### Licences (constat)

| Licence | Achetées | Utilisées |
|---|---|---|
| Salesforce | 2 | 2 |
| **Partner Community** | **35** | **35 (toutes)** |
| Guest User | 25 | 5 |

⚠️ **Décision à prendre** : passer régies, pré-visiteurs et sous-traitants en vrais utilisateurs Experience demande des licences
supplémentaires (128 régies actives). Options à chiffrer : licences « Login » (facturées à la connexion), Customer Community Plus,
ou garder un accès invité sécurisé (jeton signé, durée limitée) pour les acteurs occasionnels.

### Comptabilité, pré-visiteurs, sous-traitants

| Sujet | Réponse de Micke |
|---|---|
| Comptabilité | **Selon l'échéance prévue dans la grille tarifaire**, une **demande de facturation** est envoyée au prestataire (confirmateur ou autre), qui **envoie sa facture**. |
| Pré-visiteurs (17) | **Sous-traitants externes.** |
| Sous-traitants installateurs | Portail avec **planning, SAV, facturation**. |
| Licences | Souhait de Micke : **tous en utilisateurs Experience sans licence**, comme ce qui existe avec l'objet Campagne. |

⚠️ Point à valider avec Salesforce avant de concevoir : un accès **avec identifiant et espace personnel durable** construit sur l'utilisateur invité
(sans licence) contourne le modèle de licences et pose des risques de sécurité (toutes les données passent par du code `without sharing`).
L'accès invité est fait pour des usages **ponctuels et sans compte** (formulaire, signature, compte rendu d'une visite par lien unique).
Architecture prévue pour supporter les deux : lien sécurisé à usage limité pour l'occasionnel, compte Experience pour l'usage régulier.
