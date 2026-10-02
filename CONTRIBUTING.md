# Travailler à deux sur ce projet

Deux développeurs (et leurs Claude) travaillent sur ce dépôt. Ces règles évitent d'écraser le travail de l'autre.

## 1. Avant de commencer

1. Récupérer la dernière version : `git pull --rebase origin main`.
2. Lire le contexte affiché au démarrage (dernières entrées du journal, branches en cours).
3. Vérifier qu'on ne reprend pas un sujet « en cours » chez l'autre développeur. En cas de doute, demander.

## 2. Une branche par sujet

- Jamais de travail direct sur `main` (sauf journal et documentation simple).
- Nom de branche : `auteur/sujet-court`, par exemple `micke/devis-lwc` ou `dev2/correction-trigger-compte`.
- Une fois le sujet terminé et vérifié : Pull Request vers `main`, relue si possible par l'autre.

## 3. Sauvegardes régulières

- Commit + push environ **tous les 10 messages** et à chaque étape terminée.
- Messages de commit en français : `ajout : …`, `correction : …`, `refonte : …`, `docs : …`.
- Toujours `git pull --rebase` juste avant un push.

## 4. Journal de bord

- Chaque session crée sa propre entrée dans `journal/AAAA/MM/` (voir `journal/README.md`).
- On ne modifie pas l'entrée de quelqu'un d'autre : on crée une nouvelle entrée qui y fait référence.
- Le statut passe à `terminé` quand le travail est fini, sinon il reste `en cours`.

## 5. En cas de conflit Git

Ne jamais forcer (`git push --force`) sur `main`. Résoudre le conflit en gardant les deux modifications
quand c'est possible ; en cas de doute, arrêter et demander à l'autre développeur.

## 6. Salesforce

- Ancien code : `legacy-app/`. Nouveau code : `force-app/`.
- Aucun déploiement en production sans accord écrit de Micke.
- Aucun identifiant ni mot de passe dans le dépôt.
