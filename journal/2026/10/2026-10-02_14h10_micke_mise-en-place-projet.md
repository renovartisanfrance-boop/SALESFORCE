---
date: 2026-10-02 14:10
auteur: micke
sujet: Mise en place du projet, de BMAD et du journal de bord
statut: terminé
branche: main
suite_de:
---

## Objectif

Préparer le dépôt GitHub pour travailler sur Salesforce avec Claude Code, à distance et à deux développeurs.

## Ce qui a été fait

- GitHub connecté à Claude Code (application Claude installée sur tous les dépôts).
- Structure SFDX : `force-app/` (nouveau code) et `legacy-app/` (ancien code de l'org, à importer).
- Outils qualité : ESLint (LWC), Prettier (Apex, XML), Jest (tests LWC).
- Installation automatique en session cloud (`scripts/setup-cloud.sh`) : dépendances npm, Salesforce CLI, BMAD en français.
- `CLAUDE.md` : règles d'architecture, de sécurité et de sauvegarde GitHub.
- Journal de bord (`journal/`) + affichage automatique du contexte au démarrage (`scripts/journal-context.sh`).
- Règles de travail à deux : une branche par sujet, Pull Request vers `main`.

## Fichiers touchés

- `CLAUDE.md`, `CONTRIBUTING.md`, `README.md`, `.claude/settings.json`
- `scripts/setup-cloud.sh`, `scripts/journal-context.sh`
- `journal/README.md`, `journal/_MODELE.md`
- `.github/pull_request_template.md`

## Décisions prises

- Interface en LWC et non React (React ne tourne pas nativement dans Salesforce).
- Méthode BMAD pour les nouvelles fonctionnalités.
- Journal : un fichier par session pour éviter les conflits entre les deux développeurs.
- Mise à jour GitHub environ tous les 10 messages (consigne de Micke).

## Problèmes / points d'attention

- BMAD n'a pas pu être installé dans cette session (téléchargement npm bloqué) : il s'installera au premier démarrage d'une session sur claude.ai/code. Penser à pousser le dossier `_bmad/` ensuite.
- L'ancien code n'est pas encore dans le dépôt.

## Prochaines étapes

- [ ] Ouvrir une session sur claude.ai/code pour déclencher l'installation de BMAD, puis pousser `_bmad/`.
- [ ] Importer l'ancien code (export de l'autre compte Claude) dans `legacy-app/`.
- [ ] Connecter l'org Salesforce (variable `SF_AUTH_URL` dans l'environnement cloud).
- [ ] Ajouter le second développeur au dépôt GitHub et compléter `journal/README.md` (tableau des auteurs).
