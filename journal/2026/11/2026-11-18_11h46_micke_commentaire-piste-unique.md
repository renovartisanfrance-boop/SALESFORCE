---
date: 2026-11-18 11:46
auteur: micke
sujet: Piste : un seul commentaire à la conversion (flux PISTE_CommentaireUnique) + nettoyage versions du flux Opportunité
statut: terminé
branche: micke/commentaire-piste-unique
suite_de:
---

## Objectif

Une piste vient soit de l'interne, soit d'un apporteur externe. Le commentaire télépro (interne,
`Telepro_Commentaire_pour_Confirmateur__c`, 255 car.) doit basculer dans le commentaire régie (externe,
`REGIE_Commentaire_Regie__c`, 15 000 car.) pour ne faire remonter qu'un seul champ à la conversion.

## Ce qui a été fait

- **Flux Opportunite_FL_AfterCreateUpdate** : versions inactives 92 et 93 supprimées en prod (accord utilisateur).
  Elles étaient bloquées par 13 interviews de flux en échec (création du Dossier refusée par des règles de
  validation, 10/11 au 18/11, CHAUVET et NICOLETTE) : interviews supprimées d'abord. Reste la version 94 active.
- **Nouveau flux `PISTE_CommentaireUnique`** (avant enregistrement, création et modification de Piste) :
  si le commentaire télépro est rempli, il est recopié dans le commentaire régie quand celui-ci est vide, ou
  quand il contient encore l'ancien commentaire télépro (le télépro l'a modifié). Un commentaire d'apporteur
  externe n'est jamais écrasé. Le commentaire télépro est conservé.
- Prod déployée en 3 temps (la prod installe les flux inactifs : `enableFlowDeployAsActiveEnabled` = false) :
  flux installé, activé (version 1), puis classe de test `PisteCommentaireUniqueTest` déployée : 5 tests OK
  (création, modification, externe protégé, sans commentaire, lot de 200), flux couvert à 100 %.
- **Rattrapage** : 12 308 pistes non converties (commentaire télépro rempli, régie vide) → 12 286 recopiées,
  22 bloquées par des règles de validation (voir ci-dessous). Contrôle après coup : 22 restantes, rien d'autre.
  Avant le rattrapage, vérifié que les flux SMS / e-mail des Pistes ne partent que sur changement de statut
  précis : aucun message envoyé.

## Fichiers touchés

- `force-app/main/default/flows/PISTE_CommentaireUnique.flow-meta.xml`
- `force-app/main/default/classes/PisteCommentaireUniqueTest.cls` (+ meta)

## Décisions prises

- Flux séparé plutôt qu'ajout dans PISTE_AvantCreation (flux de l'utilisateur, modifié à la main en prod).
- Commentaire télépro gardé ; le champ régie suit ses modifications (choix utilisateur).
- Pistes converties non rattrapées (non modifiables).

## Problèmes / points d'attention

- 22 pistes non recopiées, bloquées par une règle de validation : 10 « Prévisite incomplète », 1 « fiche
  prévisite ≠ produit », 5 « année chaudière pas sur 4 chiffres », 4 « année maison pas sur 4 chiffres »,
  3 « A RAPPELER sans date / créneau ». Elles se recopieront seules dès qu'elles seront corrigées et
  enregistrées (le flux recopie tant que le champ régie est vide).
- Le champ régie reçoit désormais aussi les commentaires internes : penser à mettre à jour le mapping de
  conversion si ce n'est pas déjà ce champ qui remonte.

## Prochaines étapes

- [ ] L'utilisateur vérifie le mapping de conversion (un seul champ : commentaire régie).
