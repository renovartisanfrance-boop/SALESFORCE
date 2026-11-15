# Vues de travail — architecture pour l'intégrateur Salesforce

> **Statut (08/11/2026) : RETIRÉ, ne pas développer.** Conservé pour mémoire. Les vues par profil sont stables. Elles restent des **listes de vue Salesforce** créées par l'intégrateur et attribuées par la responsable. Le besoin courant (filtrer un peu plus) est couvert par le **filtre rapide dans les titres de colonnes** du poste de travail. Ne développer ce module que si Micke le redemande.

> Objectif : la **responsable** (licence **Partner Community**) crée elle-même, depuis le portail, les vues de travail de chaque profil : **télépros, confirmateurs, secrétaires, closer, comptabilité**. L'intégrateur n'intervient que pour une **nouvelle fiche** ou un **nouveau champ**.
> Maquette : `docs/maquettes/maquette-confirmateur.html` → menu « Plus » → « Page responsable » → carte **« Vues de travail »**.
> Guide du poste confirmateur : `docs/integration/poste-confirmateur.md` (même code couleur).
> **Code couleur** : ✅ existe · **🟨 Cx = À CONFIRMER** (par l'intégrateur) · **🟦 Ax = À CRÉER** · **🟥 Vx = À VÉRIFIER avant de déployer**.

---

## ★ VOS ACTIONS — à faire par l'intégrateur

### 🟨 À CONFIRMER par l'intégrateur (jaune)

- [ ] **VT-C1** — Le module existant « par fiche et par profil » (présentation des pages) : peut-on **réutiliser son paramétrage** (fiches × profils) pour attribuer les vues, plutôt que d'en créer un second ?
- [ ] **VT-C2** — Une licence **Partner Community** peut-elle créer des listes de vue Salesforce **partagées** ? (Normalement non : c'est ce qui justifie cette solution.) À constater en sandbox.
- [ ] **VT-C3** — Quota d'objets personnalisés accessibles aux licences Partner Community dans l'org : la solution n'ajoute **qu'un seul objet** (`Vue_Travail__c`).
- [ ] **VT-C4** — Profils réels à proposer : Télépro, Confirmateur, Secrétaire, Closer, Comptabilité, et responsables (liste exacte des profils du site).

### 🟦 À CRÉER (bleu)

- [ ] **VT-A1** — Custom Metadata **`Champ_Autorise__mdt`** : le **catalogue des champs** que la responsable peut filtrer ou afficher (§ 2).
- [ ] **VT-A2** — Objet **`Vue_Travail__c`** : une vue = un enregistrement (§ 3).
- [ ] **VT-A3** — Classe Apex **`VueTravailService`** + **`VueTravailSelector`** : lecture des vues attribuées à l'utilisateur, construction **sécurisée** de la requête (§ 4), tests ≥ 85 %.
- [ ] **VT-A4** — LWC **`vueTravailEditeur`** (page responsable) : création et modification d'une vue, aperçu en direct.
- [ ] **VT-A5** — LWC **`posteTravail`** générique : le même écran de travail pour tous les profils (liste, tri, largeurs, modification directe, échéance, doublons, fichiers, « Compléter » selon l'objet). Le poste confirmateur en est une configuration.
- [ ] **VT-A6** — Jeu de permissions **« Responsable - Vues de travail »** (créer, modifier, supprimer `Vue_Travail__c`) et **« Lecture - Vues de travail »** pour les autres profils.

### 🟥 À VÉRIFIER avant de déployer (rouge)

- [ ] **VT-V1** — **Sécurité de la requête** : aucun texte saisi n'est concaténé dans le SOQL. Seuls les champs du catalogue sont acceptés, les valeurs passent en variables liées, et la requête s'exécute en `AccessLevel.USER_MODE` (§ 4).
- [ ] **VT-V2** — Une vue **ne montre jamais plus** que ce que l'utilisateur voit déjà : partage et droits par champ respectés (test avec un vrai utilisateur partenaire de chaque profil).
- [ ] **VT-V3** — Les utilisateurs non responsables **ne peuvent ni créer ni modifier** une vue (droits CRUD + contrôle Apex).
- [ ] **VT-V4** — Performances : pagination (200 lignes par page), filtres sélectifs, limites de requêtes respectées sur les fiches volumineuses.
- [ ] **VT-V5** — Cloisonnement **Espagne** : une vue RES-060 n'est attribuable qu'aux équipes ES.

---

## 1. Fonctionnement voulu

| Qui                                  | Fait quoi                                                                                                                 | Où                          |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------- | --------------------------- |
| **Intégrateur** (accès complet)      | Ajoute une fiche (valeur de liste + ligne `Fiche_Confirmateur__mdt`) ou un champ au catalogue (`Champ_Autorise__mdt`)     | Configuration Salesforce    |
| **Responsable** (Partner Community)  | Crée une vue : objet (Pistes ou Dossiers), fiches, filtres, colonnes, tri, et l'attribue à des profils ou à des personnes | Page responsable du portail |
| **Utilisateurs** (Partner Community) | Voient les vues qui leur sont attribuées, sous la fiche choisie, et travaillent dedans                                    | Leur écran de travail       |

- Une vue attribuée à un profil apparaît dans la ligne des listes, sous la fiche, avec une icône violette ▤.
- Les **listes de vue Salesforce existantes** restent branchables pendant la transition.

## 2. Catalogue des champs autorisés — `Champ_Autorise__mdt` (**🟦 VT-A1**)

| Champ du type                                      | Contenu                                       |
| -------------------------------------------------- | --------------------------------------------- |
| `Objet__c`                                         | `Lead` ou `Pro__c`                            |
| `Champ_API__c`                                     | Nom d'API exact (ex. `CONFIRM_Traitement__c`) |
| `Libelle__c`                                       | Libellé affiché à la responsable              |
| `Type_Filtre__c`                                   | `liste`, `texte`, `date`, `echeance`, `aucun` |
| `Filtrable__c` / `Affichable__c` / `Modifiable__c` | Cases à cocher                                |
| `Ordre__c`                                         | Ordre dans les menus                          |

Contenu de départ (repris de la maquette, noms d'API vérifiés dans l'org le 08/11/2026) :

| Objet  | Libellé                     | Champ API                                                          | Type                |
| ------ | --------------------------- | ------------------------------------------------------------------ | ------------------- |
| Lead   | Créé le                     | `CreatedDate`                                                      | date                |
| Lead   | Provenance                  | `Apporteurs__c` (**🟨** voir C2 du guide confirmateur)             | texte               |
| Lead   | Origine (régie / interne)   | `LeadSource`                                                       | liste               |
| Lead   | Nom complet / Téléphone     | `Name` / `Phone`                                                   | texte               |
| Lead   | Doublon                     | `Doublon_Telephone_Indicateur__c`                                  | aucun (affichage)   |
| Lead   | Échéance                    | `ENVOI_CONF_Date_de_Rappel__c` + `ENVOI_CONF_Cr_neau_de_Rappel__c` | échéance (calculée) |
| Lead   | Créneau                     | `ENVOI_CONF_Cr_neau_de_Rappel__c`                                  | liste               |
| Lead   | Traitement                  | `CONFIRM_Traitement__c`                                            | liste, modifiable   |
| Lead   | Commentaire conf            | `CONFIRM_Commentaire__c`                                           | texte, modifiable   |
| Lead   | Commentaire régie / télépro | `REGIE_Commentaire_Regie__c`                                       | texte               |
| Pro__c | Apporteur                   | `DR_Provenance__c`                                                 | texte               |
| Pro__c | Client / Téléphone          | `Name` / `Phone__c`                                                | texte               |
| Pro__c | Infos dossier               | `DR_PROconvers__c`                                                 | texte               |
| Pro__c | Statut prévisite            | `Pr_visite_Statut__c`                                              | liste, modifiable   |
| Pro__c | Pré-visiteur                | `Pr_visite_Nom_St__c`                                              | liste, modifiable   |
| Pro__c | Date d'envoi / de passage   | `Audit_Envoi_en_Visite__c` / `PREVISITE_Date__c`                   | date                |
| Pro__c | Commentaire                 | `Pr_visite_Commentaire__c`                                         | texte, modifiable   |

Pour les secrétaires, le closer et la comptabilité, ajouter au catalogue les champs `Pro__c` qu'ils utilisent : statuts devis, installation, CEE, MPR, documents… Les noms d'API sont dans `poste-confirmateur.md` § 3.

## 3. Objet `Vue_Travail__c` (**🟦 VT-A2**) — un seul objet

| Champ             | Type                 | Contenu                                                                |
| ----------------- | -------------------- | ---------------------------------------------------------------------- |
| `Name`            | Texte                | Nom de la vue                                                          |
| `Objet__c`        | Liste                | `Lead` / `Pro__c`                                                      |
| `Fiches__c`       | Liste multiple       | Codes de fiche (vide = toutes)                                         |
| `Definition__c`   | Texte long (131 072) | JSON : filtres, colonnes, tri (format ci-dessous)                      |
| `Profils__c`      | Liste multiple       | Télépro, Confirmateur, Secrétaire, Closer, Comptabilité (**🟨 VT-C4**) |
| `Utilisateurs__c` | Texte long           | Id des personnes attribuées, séparés par `;`                           |
| `Active__c`       | Case à cocher        | Vue visible ou non                                                     |
| `Ordre__c`        | Nombre               | Position dans la ligne des listes                                      |

```json
{
  "version": 1,
  "filtres": [
    {
      "champ": "CONFIRM_Traitement__c",
      "operateur": "in",
      "valeurs": ["🟨 NRP- 3x", "🟨 NRP- 4x", "🟨 NRP- 5x"]
    }
  ],
  "colonnes": [
    "CreatedDate",
    "Apporteurs__c",
    "Name",
    "Phone",
    "Doublon_Telephone_Indicateur__c",
    "ENVOI_CONF_Date_de_Rappel__c",
    "CONFIRM_Traitement__c",
    "CONFIRM_Commentaire__c"
  ],
  "tri": { "champ": "ENVOI_CONF_Date_de_Rappel__c", "sens": "asc" }
}
```

Opérateurs : `in` (est l'un de), `nin` (n'est pas), `has` (contient), `empty`, `full`, `today`, `d7`, `month`, `older` ; pour l'échéance : `retard`, `maintenant`, `heure`, `avenir`. Toutes les conditions sont combinées par **ET**.

## 4. Construction sécurisée de la requête (**🟦 VT-A3**, **🟥 VT-V1**)

1. Charger la vue. Ne garder que les champs **présents dans `Champ_Autorise__mdt`** pour cet objet ; ignorer tout le reste.
2. Pour chaque filtre, produire une condition **avec variable liée** : `CONFIRM_Traitement__c IN :valeurs0`, `Name LIKE :texte1`…
3. Exécuter avec `Database.queryWithBinds(soql, binds, AccessLevel.USER_MODE)` : partage et droits par champ de l'utilisateur appliqués.
4. **Échéance** : filtrer en SOQL sur la date de rappel (≤ aujourd'hui, = aujourd'hui…), puis calculer l'état exact (retard, maintenant, dans l'heure, à venir) en Apex ou en LWC, avec les créneaux et `Regle_Rappel__mdt`.
5. Pagination de 200 lignes, tri sur un champ du catalogue uniquement.
6. Lecture des vues attribuées : sélecteur dédié, limité aux vues `Active__c` dont `Profils__c` contient le profil de l'utilisateur ou dont `Utilisateurs__c` contient son Id.

## 5. Nouvelle fiche : procédure

1. **Intégrateur** : ajouter la valeur dans `TypeDeDossier__c` (et les champs « Création Dossier », fiches prévisite si besoin), une ligne `Fiche_Confirmateur__mdt`, et les éventuels nouveaux champs dans `Champ_Autorise__mdt`.
2. **Responsable** : créer les vues de travail de la fiche et les attribuer aux profils. Aucun déploiement de code.

## 6. Charge estimée

| Cas                                                                                                           | Charge de l'intégrateur                                                                           |
| ------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| Code écrit et testé en sandbox par Claude avec Micke, l'intégrateur relit, vérifie (VT-V1 à VT-V5) et déploie | **½ journée**, en plus de la journée du poste confirmateur                                        |
| Tout écrit par l'intégrateur                                                                                  | environ **8 à 10 jours** (objet, catalogue, Apex sécurisé et tests, éditeur LWC, écran générique) |
