---
date: 2026-11-20 09:00
auteur: micke
sujet: Dossier : champ « DR- Date Conv » transformé en vraie date (tri correct)
statut: terminé
branche: micke/commentaire-piste-unique
suite_de:
---

## Objectif

Les listes de vues des dossiers (`Pro__c`) triées sur « DR- Date Conv » étaient dans le désordre
(13/10 juste avant 13/11).

## Ce qui a été fait

- Cause : `DR_Date_Conv__c` était une formule **Texte** « JJ/MM » → tri alphabétique, jour d'abord, sans année.
- Vérification des dépendances (prod) : utilisé uniquement dans 20 mises en page, aucune formule, flux ni Apex.
- Modification en prod (accord explicite de l'utilisateur), déploiement de ce seul champ :
  formule `DATEVALUE(CreatedDate)`, type de retour **Date**. Libellé inchangé.
- Contrôle : tri croissant correct (08/10, 09/10, …).

## Fichiers touchés

- Aucun fichier du dépôt (champ non présent dans `legacy-app/`). Copie de l'ancienne définition
  gardée dans le dossier temporaire de session.

## Décisions prises

- Vraie date plutôt que texte : tri juste partout et l'année apparaît (affichage « 13/10/2026 »).

## Problèmes / points d'attention

- Ancienne formule, pour revenir en arrière si besoin :
  `RIGHT("0" & TEXT(DAY(DATEVALUE(CreatedDate))), 2) & "/" & RIGHT("0" & TEXT(MONTH(DATEVALUE(CreatedDate))), 2)` (type Texte).

## Prochaines étapes

- [ ] L'utilisateur vérifie l'affichage dans ses listes de vues.
