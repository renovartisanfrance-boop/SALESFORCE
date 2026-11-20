---
date: 2026-11-20 12:45
auteur: micke
sujet: Aircall 163/179 : appels entrants restés sans retour depuis le 11/05, remontés pour rappel lundi
statut: terminé
branche: micke/commentaire-piste-unique
suite_de: 2026-11-19_17h00_micke_aircall-appels-manquants.md
---

## Objectif

Faire remonter dans la liste « APPELS ENTRANTS- 163/179 » les appels reçus sur le +33669778323 depuis le
11/05/2026 qui n'ont jamais eu de conversation avec quelqu'un de la société, pour que le confirmateur les
rappelle à partir du lundi 23/11. La liste ne doit plus montrer que ceux-là.

## Ce qui a été fait

- Export CSV de l'historique Aircall, toutes lignes, du 11/05 au 20/11 (3 fichiers, ~37 000 appels ;
  Aircall limite la période à ~3 mois par export).
- 87 numéros ont eu au moins un appel entrant non décroché sur le 163/179. Écartés : ceux qui ont eu une
  conversation (appel décroché, entrant ou sortant, toutes lignes) → reste 26.
  - 7 marqués « ⬛Hors cible » dans Salesforce : écartés (choix de l'utilisateur).
  - Gardés aussi 5 numéros qu'Olivier avait appelés début octobre (11 à 46 s, sans doute le répondeur) et qui
    ont rappelé quelques minutes après sans réponse, puis plus rien.
  - Écartés car vraie conversation : 2 numéros (1 min 52 avec Olivier le 25/08, 1 min 11 avec Julien Chauvet en septembre).
- **19 numéros** retenus : 4 avaient déjà une fiche créée le matin même (SA-55975, 55981, 55985, 55988),
  **15 fiches créées** (SA-55994 à SA-56008), commentaire « A RAPPELER - Appel manqué du … Jamais rappelé. Remonté le 20/11/2026. »
- Liste de vue `Aircall__c.Copie_de_STANDAR` (« APPELS ENTRANTS- 163/179 ») : ajout d'un 4e filtre
  « Date de création ≥ 20/11/2026 » (accord de l'utilisateur ; d'abord 19/11, puis passé au 20/11 à sa demande), déploiement de ce seul élément en prod.
  Résultat : 20 fiches visibles (les 19 + SA-55990 message vocal du 13/11).
- Aucune ancienne fiche modifiée : les 53 fiches plus anciennes (appels décrochés jamais clôturés dans
  Salesforce, NRP, anciens doublons des 19) restent telles quelles, simplement masquées par le filtre.

## Fichiers touchés

- Aucun fichier du dépôt (données et liste de vue prod uniquement). Exports et scripts dans le dossier temporaire de session.

## Décisions prises

- Nouvelle fiche datée du jour plutôt que modifier les anciennes : elles arrivent en haut de la liste, rien n'est perdu.
- Filtre par date sur la liste plutôt que changer le traitement de 53 fiches : réversible en retirant un filtre.

## Problèmes / points d'attention

- Pour revenir à l'ancienne liste : retirer le filtre 4 (Date de création) et remettre `1 AND 2 AND 3`.
- Les nouveaux appels qui arrivent continueront d'apparaître (date de création récente).
- Les 53 fiches masquées contiennent des appels décrochés en « En attente » et 6 fiches NRP anciennes : à clôturer un jour si besoin.
- Conversations passées depuis un portable perso ou avant le 11/05 : invisibles pour ce tri.

## Prochaines étapes

- [ ] Le confirmateur rappelle les 21 fiches à partir du lundi 23/11.
- [ ] Décider plus tard si on remet le filtre de date à zéro ou si on le décale.
