# État des lieux de la production — Renov Artisan

> BMAD — étape 1 (analyste). Mesuré le 2026-10-02 directement en production, en lecture seule.
> Sources : utilisateurs actifs, volumes par objet, champs réellement remplis, statuts, code modifié récemment.

## 1. Qui utilise Salesforce

| Licence | Profil | Actifs | Connectés 30 j |
|---|---|---|---|
| Salesforce | Administrateur système | 2 | 2 |
| Partner Community | Télépro Leads | 11 | 11 |
| Partner Community | Responsable Télépro | 1 | 1 |
| Partner Community | Confirmateur | 5 | 4 |
| Partner Community | Secrétaire / Secrétaire PAC | 4 | 3 |
| Partner Community | Closer / Closer LEDS | 2 | 2 |
| Partner Community | Apporteur d'affaires (+ interne) | 8 | 3 |
| Partner Community | Régies | 1 | 1 |
| Partner Community | Comptabilité | 1 | 1 |
| Partner Community | Sous-traitant (portail externe) | 2 | 0 |

Sites Experience Cloud en ligne : **business saas** (portail principal), **Gestion Previsites**, **Campagnes**.
Utilisateurs invités (sites publics) : Yousign, Campagnes, Gestion Previsites, business saas.

## 2. Ce qui vit vraiment (volumes)

| Objet | Total | Créés 30 j | Rôle constaté |
|---|---|---|---|
| Lead | 220 596 | 2 127 | **Cœur de tout le processus**, du premier contact à la signature |
| Task | 66 186 | 3 235 | Appels (alimentés par Aircall) |
| Aircall__c | 53 923 | 3 235 | Journal des appels |
| Account / Contact | 3 588 / 2 832 | 253 / 53 | Comptes partenaires et clients |
| Opportunity | 2 569 | 37 | **Quasi inutilisée** : 100 % en « Qualification » |
| Pro__c | 1 489 | 41 | Fiches professionnelles (CEE / tertiaire) |
| Case | 1 428 | 123 | Demandes |
| YS_Evenement__c | 385 | 381 | Événements Yousign (signature) |
| Facture__c / LigneFacture__c | 133 / 335 | 37 / 62 | Facturation (récente, active) |
| STOCK__c | 664 | 2 | Stock |
| Installation__c, SAV__c, Comptabilite__c, Facturation2__c, Tache__c, Formulaires__c, AccesTelepro__c, Lettrage__c | 0–1 | 0 | **Abandonnés** |

Aucun Event : les rendez-vous ne sont pas dans l'agenda Salesforce.

## 3. Le parcours actuel (reconstitué depuis les statuts du Lead)

Tout se passe sur le **Lead**, avec un champ « sous-statut » par équipe :

1. **Entrée** — `LeadSource` : LEADS (campagnes web, ~85 %), REGIES (apporteurs, ~15 %), INTERNE.
   Types : Résidentiel (~99 %), Bâtiment, Agricole, Transport — chacun en interne / externe.
2. **Télépro** — `RENO_Sous_Statut_Leads__c` : NRP 1x…12x, À retraiter / rappel programmé, Hors cible (motifs).
3. **Base / relance** — `BD_PAC_Sous_Statut__c`, `ITE_Sous_Statut__c` : NRP, À rappeler, **Envoyé en conf**.
4. **Confirmateur** — `CONFIRM_Traitement__c` : NRP + mail/SMS, Hors cible (faisabilité, revenus, trop petit…).
5. **Pré-visite** — `N_cessite_Pr_visite__c`, `PREVISITE_Statut__c` : passage demandé → planifié (prévisiteurs par code postal, sous-traitants).
6. **Devis & signature** — `RES_Statut_Devis__c` : génération → en attente de signature → signé (Yousign).
7. **Dossier d'aides** — `MPR_Docs__c` (MaPrimeRénov'), Certiko (CEE).
8. **Installation / facturation** — composants `lwc027_gestion_installations`, facturation installateur / prévisiteur / partenaires, catalogue tarifaire.

Régies : `REGIE_Sous_Statut__c` (peu utilisé).

## 4. Ce qui est en chantier (code modifié ces 4 derniers mois)

- **Pré-visites** : `lwc027_*`, `PrevisiteController`, `PrevisiteurCpController`, `previsiteurParCp` (modifiés jusqu'au 02/10).
- **Certiko** (CEE) : `LC027_Certiko*`.
- **Devis / contrat / signature Yousign** : `LC021_DevisSignature`, `lwc021_devis_signature`, `YS_*`.
- **Facturation** : `lwc020_Facturation*`, `lwc022*`, `lwc023/024/025*`, `creerFactureWizard`, `FactureTriggerHandler`.
- **Campagnes & reporting** : `lwc020_GestionCampagnes`, `lwc020_reporting_v2`, `rdvFicheStandard`.
- **Documents** : `lwc026_documents`.

## 5. Problèmes constatés

- **Lead surchargé** : 305 champs personnalisés, dont **175 jamais remplis** sur 90 jours ; seuls ~50 sont réellement utilisés.
- **Tout le cycle de vie sur le Lead** : pas de conversion en client / dossier ; 220 000 leads mélangent prospects et clients signés.
- **Statuts parallèles** par équipe, avec des valeurs par défaut qui rendent les compteurs trompeurs (213 000 leads « EN ATT DE TRAITEMENT »).
- **Libellés avec emojis et fautes** dans les valeurs de listes (`EN ATT DE TRAITEMENTTT`) : difficile à automatiser et à rapporter.
- **Objets abandonnés** (Installation, SAV, Comptabilité, Facturation2…) et Opportunity inutilisée.
- **Sécurité** : nombreuses classes `without sharing`, profils codés en dur dans le JavaScript, clés API en clair (voir journal du 02/10).
- **Tests et architecture** : pas de couche Service / Selector homogène, logique dans les contrôleurs LWC.

## 6. Questions ouvertes pour Micke

- Le parcours en 8 étapes ci-dessus est-il juste ? Qu'est-ce qui manque ?
- Que veut dire « fonctionnel mais non opérationnel » pour les pré-visites, Certiko, la facturation ?
- Les closers interviennent à quelle étape ?
- Bâtiment / Agricole / Transport : à garder dans la nouvelle version ?
- Outils à conserver : Aircall ou Ringover ? Odoo ? Ionos ? Certiko ? Yousign ?
