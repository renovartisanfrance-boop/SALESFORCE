# Journal de bord

Historique de tout le travail fait sur le projet, par les humains et par leurs Claude.
Deux développeurs travaillent en parallèle : ce journal est la mémoire commune.

## Principe : un fichier par session (zéro conflit)

On n'écrit **jamais** dans un fichier partagé commun. Chaque session crée **son propre fichier** :

```
journal/AAAA/MM/AAAA-MM-JJ_HHhMM_auteur_sujet-court.md
```

Exemple : `journal/2026/10/2026-10-02_14h10_micke_mise-en-place-journal.md`

Deux personnes peuvent donc écrire en même temps sans jamais se gêner sur GitHub.

## Quand écrire

- **Début de session** : lire les dernières entrées (elles s'affichent automatiquement au démarrage
  d'une session Claude Code grâce à `scripts/journal-context.sh`).
- **Pendant** : mettre à jour son entrée et pousser sur GitHub environ tous les 10 messages.
- **Fin de session** : compléter l'entrée (statut, prochaines étapes) et pousser.

Une session = un fichier. Si on reprend le même travail plus tard, on crée une **nouvelle** entrée
qui renvoie à la précédente (champ « Suite de »).

## Modèle

Copier `journal/_MODELE.md`. Les champs en haut (entre `---`) servent au résumé automatique :
ne pas les supprimer.

## Auteurs

| Identifiant | Personne | Rôle |
|---|---|---|
| `micke` | Micke | Propriétaire du projet |
| `dev2` | (à compléter) | Développeur |
