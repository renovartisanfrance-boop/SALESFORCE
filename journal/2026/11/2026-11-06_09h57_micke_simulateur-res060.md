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

- **Écran visuel** (composant LWC `simulateurRes060`, même style que le HTML) : calcul en direct pendant la saisie
  (Apex `SimulationRES060Controller`, sans enregistrer), gros indice vert/rouge, détail du calcul, bouton Enregistrer.
  Page « Simulateur RES060 » + onglet, et page d'une simulation enregistrée. Déployé en prod (`0AfJv0000037hg1KAA`,
  18 tests Apex + 6 tests Jest).

- **Lien Piste → calculateur** (déployé en prod, `0AfJv0000037joHKAQ`, 63 tests dont DoublonService_Test,
  LeadReferenceCadastrale_Test, TriggerHandlerTest) : 4 nouvelles cases sur la Piste (RES060- Indice / Zone /
  Statut / Province calculateur), remplies par `SimulationRES060PisteService`, appelé par `LeadTriggerHandler`
  (1 ligne ajoutée en before insert et before update). Seules ces 4 cases sont écrites ; aucune DML en plus.
- Périmètre : pistes RES060 seulement (internes ou externes, fiche dans Type de dossier ou PREVISITE- Fiches
  Résidentiel) : 6 484 pistes, dont 678 avec les infos. Recalcul seulement quand une info du calculateur change.
- Province cherchée dans le code postal (même « CP 31580 » ou sans le 0), puis dans l'adresse régie, la rue, la
  ville et la région (code postal ou nom de province, noms en Custom Metadata). Info manquante = pas d'indice.
- Code des Pistes resynchronisé depuis la prod dans `legacy-app/` (modifié en prod le 19/10, absent du dépôt).

## Fichiers touchés

- `force-app/main/default/` (classes, triggers, objects, customMetadata, layouts, tabs, permissionsets)
- `docs/conception/simulateur-res060.md`
- `legacy-app/main/default/classes/LeadTriggerHandler.cls` (+ classes Doublon / Cadastre resynchronisées)

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

- [x] Écran vérifié et validé par l'utilisateur (« Ça me va »).
- [ ] Faire valider le simulateur par l'utilisateur sur quelques cas réels.
- [x] Connecteur Piste : fait et déployé.
- [ ] Ajouter les 4 cases RES060 sur la page de la Piste et donner l'accès en lecture aux télépros / confirmateurs
      (pour l'instant seul renov.artisan.france les voit, via le jeu d'autorisations « Simulateur RES060 »).
- [ ] Option : recalculer d'un coup les 678 pistes RES060 déjà remplies (vérifier avant les flows SMS/email).
