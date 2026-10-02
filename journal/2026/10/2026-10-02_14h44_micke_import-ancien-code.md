---
date: 2026-10-02 14:44
auteur: micke
sujet: Poste local Windows + import de l'ancien code depuis l'org
statut: en cours
branche: micke/import-ancien-code
suite_de: 2026-10-02_14h10_micke_mise-en-place-projet.md
---

## Objectif

Travailler depuis l'ordinateur de Micke (application Claude, onglet Code) et importer l'ancien code de l'org dans `legacy-app/`.

## Ce qui a été fait

- Poste Windows de Micke : Git et GitHub CLI installés, connexion GitHub (compte `renovartisanfrance-boop`).
- Dépôt cloné dans `C:\Users\Mike\Projets\SALESFORCE` (hors OneDrive, pour éviter les conflits de synchronisation).
- Org Salesforce déjà connectée sur ce poste : **Renov Artisan**, Enterprise Edition, **production** (pas une sandbox).
- Ancien code récupéré depuis l'org (lecture seule, rien n'a été déployé) dans `legacy-app/main/default/` :
  - 149 classes Apex, 10 triggers
  - 77 composants LWC, 11 composants Aura
  - 24 pages Visualforce, 4 composants Visualforce
- **Sandbox `modern` demandée** (type Developer, alias CLI `modern`, job `0GRJv0000001zPdOAI`), dédiée à la modernisation.
  Suivi / connexion une fois prête : `sf org resume sandbox --job-id 0GRJv0000001zPdOAI -o renov.artisan.france@gmail.com`.
  Sandboxes déjà présentes, non touchées : dev4, dev5, dev6 (Developer), PCP1 (Partial Copy, la seule licence).
- Contrôle des secrets avant envoi sur GitHub : des clés étaient écrites en clair dans le code.
  Elles ont été remplacées par `SECRET_RETIRE_DU_DEPOT_VOIR_ORG` **dans la copie du dépôt uniquement** (l'org n'est pas modifiée).

## Fichiers touchés

- `legacy-app/main/default/**` (745 fichiers, import initial)
- `journal/2026/10/2026-10-02_14h44_micke_import-ancien-code.md`

## Décisions prises

- Import limité au code (Apex, triggers, LWC, Aura, Visualforce). Objets, champs, flows, profils : import séparé plus tard.
- **Objectif validé par Micke** : refaire l'application avec une architecture neuve et propre, en repartant de zéro
  et en suivant le parcours métier depuis le début (« le démarrage »). Construction dans la sandbox `modern`,
  puis bascule de l'ancienne version vers la nouvelle. L'ancien code (`legacy-app/`) sert de référence fonctionnelle.
- Secrets retirés de la copie versionnée : un dépôt Git garde tout l'historique, une clé poussée une fois y reste pour toujours.

## Problèmes / points d'attention

- **Ne pas déployer `legacy-app/` tel quel** : les 3 classes ci-dessous contiennent le marqueur à la place des vraies clés et casseraient les appels en production.
  - `classes/Planification_Controller.cls` : 4 clés OpenRouteService, 1 clé zipcodestack, 1 clé distancematrix (en commentaire).
  - `classes/IonosUsersService.cls` : clé API Ionos.
  - `classes/LC020_ExterneAPIService.cls` : mot de passe par défaut donné aux utilisateurs externes.
- Ces clés sont en clair dans l'org depuis longtemps : à **changer chez chaque fournisseur** puis à ranger dans des Named Credentials ou Custom Metadata (règle `CLAUDE.md`).
- Code récupéré au format API de l'org (67.0) alors que `sourceApiVersion` du projet est 66.0 : sans effet pour la lecture.

## Prochaines étapes

- [ ] Fusionner la Pull Request #1 (`micke/import-ancien-code` → `main`).
- [ ] Vérifier que la sandbox `modern` est prête et la connecter (commande ci-dessus).
- [ ] BMAD étape 1 (analyste) : décrire le parcours métier complet, du premier contact client jusqu'au SAV.
- [ ] Déplacer les clés de `Planification_Controller` et `IonosUsersService` vers des Named Credentials (nouveau code dans `force-app/`), puis changer les clés chez les fournisseurs.
- [ ] Importer les métadonnées (objets, champs, flows, permission sets) dans `legacy-app/`.
- [ ] Faire un état des lieux de l'ancien code (BMAD, rôle analyste) avant toute nouvelle fonctionnalité.
- [ ] Installer BMAD et pousser `_bmad/`.
- [ ] Ajouter le second développeur au dépôt et au tableau des auteurs (`journal/README.md`).
