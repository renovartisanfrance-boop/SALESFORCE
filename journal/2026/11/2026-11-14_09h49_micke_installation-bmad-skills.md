---
date: 2026-11-14 09:49
auteur: micke
sujet: Installation de BMAD versionnée et question sur les skills populaires
statut: terminé
branche: claude/peaceful-lovelace-cry7js
suite_de: 2026-10-02_14h10_micke_mise-en-place-projet.md
---

## Objectif

Répondre à une question sur les skills les plus populaires, et versionner les fichiers
générés par l'installation automatique de BMAD au démarrage de la session cloud.

## Ce qui a été fait

- Réponse donnée sur les collections de skills les plus connues (sans chiffres vérifiés en ligne).
- Ajout au dépôt des fichiers créés par `scripts/setup-cloud.sh` : `_bmad/`, `.claude/skills/` (29 skills BMAD v6.12.4) et `package-lock.json`.

## Fichiers touchés

- `_bmad/`
- `.claude/skills/`
- `package-lock.json`

## Décisions prises

- Versionner `_bmad/` et les skills BMAD, comme prévu dans les prochaines étapes de l'entrée du 2026-10-02.

## Problèmes / points d'attention

- Ces fichiers ne sont pas encore sur `main` ni sur les branches `micke/*` : ils n'existent que sur cette branche tant qu'elle n'est pas fusionnée.
- Aucun code Salesforce modifié.

## Prochaines étapes

- [ ] Fusionner cette branche dans `main` (demande de fusion à créer si souhaité).
- [ ] Éventuellement : vérifier en ligne les skills spécialisées Salesforce avant d'en installer.
