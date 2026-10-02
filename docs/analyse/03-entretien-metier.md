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
