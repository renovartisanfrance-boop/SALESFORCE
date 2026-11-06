---
date: 2026-11-06 09:57
auteur: micke
sujet: Simulateur de marge RES060FC dans Salesforce (objet isolé)
statut: en cours
branche: micke/simulateur-res060
suite_de:
---

## Objectif

Recréer dans Salesforce le simulateur HTML « RES060FC » (version 3), dans un objet isolé qui n'impacte rien,
avec un prix de valorisation (€/MWh) modifiable. Le lien avec la Piste viendra plus tard.

## Ce qui a été fait

- Fiche de conception : `docs/conception/simulateur-res060.md`.
- Nouvel objet « Simulation RES060 » (`Simulation_RES060__c`) : 9 champs de saisie, 9 champs de résultat,
  mise en page, onglet, vue de liste, jeu d'autorisations « Simulateur RES060 ».
- Réglages en Custom Metadata : `RES060_Parametre__mdt` (SCOP, fC, prix par défaut 155, coûts pack,
  seuils) et `RES060_DCAL_Province__mdt` (50 provinces, tableau D_CAL repris du simulateur).
- Calcul Apex : trigger → handler → service → selector ; 16 tests, couverture 98 %.
- **Déployé en production** avec l'accord de l'utilisateur (déploiement `0AfJv0000037hWLKAY`,
  tests limités aux 3 classes de test du simulateur). Jeu d'autorisations attribué à renov.artisan.france.
- Essai en prod : SIM-00001 (Madrid, 120 m², 1970, gaz 1990) → indice 1,2, zone rouge, identique au HTML.

## Fichiers touchés

- `force-app/main/default/` (classes, triggers, objects, customMetadata, layouts, tabs, permissionsets)
- `docs/conception/simulateur-res060.md`

## Décisions prises

- Version 3 du simulateur : 155 €/MWh, 2 zones seulement (verte si bénéfice ≥ 3 500 €, sinon rouge).
- Prix vide sur une simulation = prix par défaut des réglages (écrit dans la case pour qu'on le voie).
- Province vide = déduite des 2 premiers chiffres du code postal (prépare le connecteur Piste).
- Objet isolé : aucun objet, champ, flow ou trigger existant n'est modifié.

## Problèmes / points d'attention

- Les feuilles Google « test calculateur » (feuilles 1 et 3) ont été calculées avec l'ancienne version
  (160 €/MWh, 3 zones) : à recalculer si besoin.
- Les autres utilisateurs n'ont pas encore accès : leur attribuer le jeu d'autorisations « Simulateur RES060 ».

## Prochaines étapes

- [ ] Faire valider le simulateur par l'utilisateur sur quelques cas réels.
- [ ] Connecteur Piste (Lead) : remplir une simulation depuis Code postal, RES- Shab, RES- Type de Chauffage,
      RES- Année de la Maison (liste : vérifier si année ou tranche), RES- Année Chaudière, RES- Bono Social,
      puis renvoyer l'indice dans une nouvelle case de la Piste.
