---
date: 2026-11-20 14:00
auteur: micke
sujet: Aircall : diagnostic du rattachement des appels (piste / dossier) et essai sur un dossier
statut: en cours
branche: micke/aircall-dossier
suite_de: 2026-11-20_12h45_micke_aircall-rappels-163-179.md
---

## Objectif

Comprendre pourquoi les fiches Aircall (`Aircall__c`) sont rarement reliées à la piste ou au dossier du client,
et montrer sur un seul dossier en prod ce que donnerait un rattachement par numéro de téléphone.

## Ce qui a été fait

- Diagnostic (prod, lecture) sur les 5 413 fiches créées depuis le 01/09/2026 :
  35 % reliées à une piste, 3 % à une opportunité, 0 % à un dossier (champ inexistant).
  25 % non reliées alors qu'une piste a le même numéro ; 30 % viennent d'un numéro qui a un dossier.
- Cause : le flux `TASK_AFTER_CreateUpdate` recopie seulement le WhoId / WhatId posé par Aircall sur la tâche :
  - WhoId Contact (client converti, 1 360 tâches) ignoré : le flux ne gère que `00Q` (piste) ;
  - WhatId Requête (`Case`, 3 170 tâches, dont 1 636 sur la requête fourre-tout « [NE-TOUCHE-PAS-CETTE-REQUETE] ») ignoré ;
  - numéros des pistes saisis dans plusieurs formats (33…, +33…, 0…, 6…) → Aircall ne reconnaît pas toujours le client ;
  - nombreux doublons de pistes sur un même numéro.
- Essai en prod (accord de l'utilisateur, uniquement des éléments **nouveaux**) :
  - champ `Aircall__c.Dossier__c` (référence vers Dossier, liste associée « Appels Aircall ») ;
  - jeu d'autorisations `Aircall_Dossier` (lecture/modification du champ), attribué à Mickael uniquement ;
  - liste de vue « ESSAI- Appels reliés à un dossier » (visible de tous, à supprimer après l'essai) ;
  - les 7 fiches d'un client test (dossier `a09Jv00000SMBeDIAX`) reliées à sa piste, son opportunité et son dossier.

## Fichiers touchés

- `force-app/main/default/objects/Aircall__c/fields/Dossier__c.field-meta.xml`
- `force-app/main/default/objects/Aircall__c/listViews/Essai_Rattachement_Dossier.listView-meta.xml`
- `force-app/main/default/permissionsets/Aircall_Dossier.permissionset-meta.xml`

## Décisions prises

- Essai sur un seul client avant d'écrire l'automatisation, à la demande de l'utilisateur.
- Aucune mise en page existante modifiée sans accord : le champ n'apparaît pas encore sur les fiches.

## Problèmes / points d'attention

- Pour voir le champ sur la fiche Aircall et la liste « Appels Aircall » sur le dossier, il faut modifier
  des mises en page existantes (3 Aircall, 22 Dossier) : en attente de l'accord de l'utilisateur.

## Prochaines étapes

- [ ] Accord de l'utilisateur pour ajouter le champ / la liste associée aux mises en page.
- [ ] Si l'essai convient : automatisation (rattachement par numéro normalisé à la création de l'appel) + rattrapage des fiches.
