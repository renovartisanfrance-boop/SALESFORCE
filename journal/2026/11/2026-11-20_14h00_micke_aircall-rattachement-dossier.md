---
date: 2026-11-20 14:00
auteur: micke
sujet: Aircall : rattachement automatique des appels à la piste, l'opportunité et le dossier (par numéro)
statut: en cours
branche: micke/aircall-dossier
suite_de: 2026-11-20_12h45_micke_aircall-rappels-163-179.md
---

## Objectif

Les fiches Aircall (`Aircall__c`) sont rarement reliées à la piste ou au dossier du client. But : les relier
automatiquement à partir du numéro de l'appelant, sans dépendre de ce qu'Aircall reconnaît.

## Ce qui a été fait

- Diagnostic (prod, lecture) sur les 5 413 fiches créées depuis le 01/09/2026 :
  35 % reliées à une piste, 3 % à une opportunité, 0 % à un dossier (champ inexistant).
  25 % non reliées alors qu'une piste a le même numéro ; 30 % viennent d'un numéro qui a un dossier.
- Causes : le flux `TASK_AFTER_CreateUpdate` recopie seulement le WhoId / WhatId posé par Aircall sur la tâche
  (contacts et requêtes ignorés, et il **revide** Piste / Opportunité à chaque mise à jour de la tâche) ;
  numéros des pistes saisis dans une dizaine de formats ; doublons de pistes ; et les cases Piste / Opportunité
  n'étaient même pas affichées sur les mises en page Aircall.
- En prod (accord de l'utilisateur) :
  - champ `Aircall__c.Dossier__c` (référence vers Dossier) + jeu d'autorisations `Aircall_Dossier` (attribué à Mickael seulement pour l'instant) ;
  - 3 mises en page Aircall (Appel entrant, Autres, Lettres) : nouvelle section « Client (piste, opportunité, dossier) ».
    Copie des mises en page d'avant gardée dans le dossier temporaire de session ;
  - liste de vue « APPELS- Par dossier » (remplace la liste d'essai, supprimée) ;
  - essai manuel : les 7 fiches d'un client test reliées à sa piste, son opportunité et son dossier.
  - champ formule `Aircall__c.Client__c` (demande de l'utilisateur : un seul champ à regarder) : lien cliquable vers le dossier
    s'il existe (📁), sinon vers la piste (👤). La section des 3 mises en page Aircall n'affiche plus que « Client » ;
    la liste « APPELS- Par dossier » aussi. Piste / Opportunité / Dossier restent remplis en coulisses.
  - Aucune mise en page Dossier touchée (demande de l'utilisateur).
- Automatisation écrite dans `force-app` (pas encore installée en prod) :
  - `AircallTrigger` → `AircallTriggerHandler` → `AircallRattachementQueueable` → `AircallRattachementService` → `AircallRattachementSelector` ;
  - recherche Salesforce (SOSL) sur les champs téléphone : retrouve le client quel que soit le format, sans champ
    supplémentaire ni modification des 230 000 pistes (les champs téléphone ne sont pas indexés, un SOQL serait refusé) ;
  - ne remplit que les cases vides ; piste convertie en priorité sinon la plus récente ; dossier le plus récent ;
    dossier de l'opportunité déjà reliée en priorité ;
  - se relance quand le flux existant revide Piste / Opportunité (le flux existant n'est pas modifié) ;
  - `AircallRattachementBatch` pour rattraper les fiches déjà créées.
- Vérification à blanc sur la prod (`deploy validate`, rien d'installé) : 16 tests OK, couverture ~95 %.

## Fichiers touchés

- `force-app/main/default/objects/Aircall__c/fields/Dossier__c.field-meta.xml` et `Client__c.field-meta.xml`
- `force-app/main/default/objects/Aircall__c/listViews/Appels_Par_Dossier.listView-meta.xml`
- `force-app/main/default/permissionsets/Aircall_Dossier.permissionset-meta.xml`
- `force-app/main/default/triggers/AircallTrigger.trigger`
- `force-app/main/default/classes/Aircall*.cls` (handler, service, selector, queueable, batch, tests, `AircallTestSupport`)

## Décisions prises

- Recherche SOSL plutôt qu'un champ « téléphone normalisé » : rien à écrire sur les pistes et dossiers existants.
- Traitement en arrière-plan (Queueable) : la création de l'appel n'est jamais ralentie ni bloquée.
- Flux existants laissés tels quels.

## Problèmes / points d'attention

- Sandbox pcp1 déconnectée (jeton expiré) : tests faits par vérification à blanc sur la prod.
- La création d'un dossier déclenche un appel HTTP externe (automatisme existant, réponse JSON en liste) :
  simulé dans les tests par `AircallTestSupport`.
- Le rattrapage modifiera la « date de dernière modification » des anciennes fiches.
- Le champ Dossier n'est visible que des utilisateurs qui ont le jeu d'autorisations `Aircall_Dossier`.

## Prochaines étapes

- [ ] Accord de l'utilisateur pour installer l'automatisation en prod.
- [ ] Attribuer `Aircall_Dossier` aux utilisateurs concernés.
- [ ] Vérifier sur un vrai appel, puis lancer le rattrapage (depuis le 01/09 ou plus loin).
