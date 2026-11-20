---
date: 2026-11-20 11:45
auteur: micke
sujet: Champs RAC (reste à charge) créés sur Opportunité et Dossier en production
statut: terminé
branche: micke/champs-rac
suite_de:
---

## Objectif

Créer en production, sur l'Opportunité et sur le Dossier (`Pro__c`), les trois champs « RAC »
qui existaient seulement sur la Piste, avec exactement les mêmes libellés, noms, types et valeurs.

## Ce qui a été fait

- Vérifié que les 3 champs existent sur la Piste (`Lead`) et pas encore sur `Opportunity` ni `Pro__c`.
- Récupéré leur définition depuis la prod et recopiée telle quelle :
  - « RAC- Gestion client » — `Suivi_Signature__c` — liste de sélection restreinte, 2 valeurs
    (« Je gère la signature client (Tx Conversion+++) », « Notre confirmateur gère la signature client »).
  - « RAC- Montant » — `RAC_Reste_charge__c` — Numéro(18, 0).
  - « RAC- Reste à charge client » — `Reste_charge_client__c` — liste de sélection restreinte, 4 valeurs
    (Non / Oui / Je ne sais pas… régie / Je ne sais pas… confirmateur).
  - Même ordre des valeurs, aucune valeur par défaut (comme sur la Piste).
- Essai à blanc OK, puis déploiement en prod (test `SimulationRES060SelectorTest` : 1/1 réussi).
- Droits d'accès recopiés depuis la Piste (mêmes profils, même lecture / modification) :
  262 droits créés. Vérification : Dossier = mêmes 45-46 profils que la Piste ; Opportunité = 4 de moins.
- Vérifié par describe : les 6 champs existent avec les bons libellés et les bonnes valeurs.

## Fichiers touchés

- `force-app/main/default/objects/Opportunity/fields/` : 3 fichiers (`Suivi_Signature__c`, `RAC_Reste_charge__c`, `Reste_charge_client__c`)
- `force-app/main/default/objects/Pro__c/fields/` : les 3 mêmes

## Décisions prises

- Copie fidèle de la Piste, y compris « RAC- Gestion client » en **lecture seule pour tous les profils**
  (c'est déjà le cas sur la Piste) : à changer si on veut pouvoir le modifier sur l'Opportunité / le Dossier.

## Problèmes / points d'attention

- 4 profils techniques (Identity User, Anypoint Integration, Minimum Access - API Only Integrations,
  Salesforce API Only System Integrations) n'ont pas eu le droit sur l'Opportunité : leur licence n'y donne pas accès. Normal.
- Les champs ne sont sur **aucune mise en page** pour l'instant.
- Le mappage de conversion Piste → Opportunité n'est pas réglé : les valeurs de la Piste ne remontent pas encore.

## Prochaines étapes

- [ ] Ajouter les champs aux mises en page Opportunité et Dossier (à faire par l'utilisateur ou à demander).
- [ ] Si on veut que les valeurs remontent à la conversion : mapper les 3 champs Piste → Opportunité
      (Configuration > Piste > Champs > Mapper les champs de piste).
- [ ] Décider si « RAC- Gestion client » doit être modifiable sur l'Opportunité / le Dossier.
