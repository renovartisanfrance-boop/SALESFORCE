# Projet Salesforce — Renov Artisan France

Langue : répondre en français, simplement (l'utilisateur n'est pas développeur).

## Structure

- `force-app/` : **nouveau code**, écrit avec une architecture propre. C'est le répertoire par défaut.
- `legacy-app/` : **ancien code** récupéré de l'org existante. On le lit, on le corrige si nécessaire,
  mais on ne l'étend pas : toute nouvelle fonctionnalité va dans `force-app/`.
- `config/project-scratch-def.json` : définition d'org de test (scratch org).
- `scripts/setup-cloud.sh` : installe Node, Salesforce CLI (`sf`) et BMAD au démarrage d'une session cloud.
- `_bmad/` : méthode BMAD (installée automatiquement au premier démarrage cloud).

## Méthode de travail : BMAD

Suivre la méthode BMAD pour toute fonctionnalité non triviale :
analyse → PRD (product manager) → architecture → stories → développement → revue/QA.
Les documents produits par BMAD vont dans le dossier de sortie BMAD et sont versionnés.

## Règles d'architecture Salesforce

- Interface : **Lightning Web Components (LWC)**, pas React (React ne tourne pas nativement dans Salesforce).
- Apex en couches : `Trigger` (une seule par objet, sans logique) → `TriggerHandler` → `Service` → `Selector` (requêtes SOQL).
- Aucun SOQL/DML dans une boucle ; code « bulkifié » (200 enregistrements minimum).
- `with sharing` par défaut ; vérifier les droits (`WITH USER_MODE` ou `Security.stripInaccessible`).
- Pas d'ID ni d'identifiants codés en dur : utiliser Custom Metadata / Custom Settings / Named Credentials.
- Chaque classe Apex a sa classe de test (`*Test.cls`), couverture ≥ 85 %, avec assertions réelles.
- Chaque composant LWC a un test Jest dans `__tests__/`.
- Avant de livrer : `npm run lint`, `npm run prettier:verify`, `npm test`.

## Sécurité

- Jamais de mot de passe, jeton ou URL d'authentification Salesforce dans le dépôt.
  La connexion à l'org passe par la variable d'environnement `SF_AUTH_URL` de l'environnement cloud.
- Aucun déploiement en production sans accord explicite de l'utilisateur.

## Sauvegarde sur GitHub (consigne de l'utilisateur)

Mettre à jour GitHub régulièrement : faire un commit + push **environ tous les 10 messages**,
et aussi dès qu'un travail cohérent est terminé. Messages de commit en français, clairs.
