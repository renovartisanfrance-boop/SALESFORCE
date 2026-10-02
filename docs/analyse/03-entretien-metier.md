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

### Constat important

`Pro__c` est **le vrai dossier client** (397 champs personnalisés), créé à partir du Lead.
Le Lead sert de fiche de prospection, puis le dossier vit sur `Pro__c`.
