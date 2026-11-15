---
date: 2026-11-11 09:44
auteur: micke
sujet: Explications des règles de validation Pistes et Dossiers (propositions)
statut: en cours
branche: micke/simulateur-res060
suite_de:
---

## Objectif

Réécrire le champ « Description » des règles de validation des Pistes (Lead) et des Dossiers (Pro__c)
pour qu'elles soient bien documentées. Ne toucher ni aux formules, ni aux messages d'erreur.

## Ce qui a été fait

- Lecture seule de la production : 72 règles sur Lead, 73 sur Pro__c.
- 140 nouvelles explications proposées (255 caractères max), 5 laissées telles quelles car déjà claires.
- Demande de l'utilisateur : changer aussi le **message d'erreur** affiché à l'utilisateur, et écrire
  avec les **libellés à l'écran** (champs et valeurs), pas les noms techniques. Tableau refait en ce sens :
  140 descriptions + 140 messages.
- Liste des valeurs citées dans les formules mais absentes des listes (fin du document).
- **Validé par l'utilisateur (11/11)** : propositions des 20 règles inactives (13 Pistes, 7 Dossiers).
  Pas encore appliquées en production.
- Document à part pour la relecture des 125 règles actives : `docs/regles-validation/explications-regles-actives.md`.
- Demande de l'utilisateur : renommer aussi les règles actives, au format `OBJET_ÉTAPE_THÈME_SUJET`
  (`PIS_`/`DOS_` + numéro d'étape du parcours), pour qu'elles s'affichent dans l'ordre du parcours.
  Correspondance ancien → nouveau nom dans le document (sert d'historique après renommage).
- Demande de l'utilisateur : messages plus clairs et polis, sans en faire trop. Les 125 messages des règles
  actives sont réécrits : une phrase sur ce qui bloque, puis « Merci de … » (modèle donné :
  « Merci d'avoir le statut installation en cohérence avec le dossier. »).
- Demande de l'utilisateur : même traitement pour les 20 règles inactives (nouveau nom + message poli ;
  descriptions déjà validées gardées). Elles restent inactives.
  Document unique pour les 145 règles : `docs/regles-validation/explications-toutes-regles.md`
  (il remplace le document des seules règles actives).
- **Appliqué en production le 11/11/2026, avec accord de l'utilisateur (« applique »)** :
  - sauvegarde des 145 règles avant modification, et vérification qu'elles n'avaient pas changé depuis le matin ;
  - renommage des 145 règles par la Metadata API `renameMetadata` (même identifiant, testé d'abord sur MPR_RAC) ;
    l'API Tooling ne permet pas de renommer ;
  - descriptions et messages : déploiement validé à blanc (818 tests OK), puis appliqué (0AfJv00000385ATKAY) ;
  - contrôle après relecture de la prod : formules, état actif/inactif et champ d'affichage identiques ;
    descriptions et messages conformes au document (145/145).
- **Formules corrigées en production le 11/11/2026, à la demande de l'utilisateur (8 règles, rien d'autre)** :
  DOS_30_AUDIT_DEMANDE (🟨Demandé), DOS_60_INSTALL_ENVOI_EN_POSE (🟦En Att Signature), DOS_40_DEVIS_MONTANT_TTC_KIT
  (Non), DOS_70_DOSSIER_ANNULATION_CHAMPS partie LEDS (⚫DOSSIER- Annulé), PIS_30_CONFIRM_VALEURS_RESERVEES
  (🟦 A Rappeler), PIS_50_CONVERSION_CHAMPS_RES168 (Fonte + Acier (Max 30% Fontes)), PIS_20_TELEPRO_HORS_CIBLE_LOOKUP
  (UPPER pour prendre « hORS CIBLE »), PIS_50_CONVERSION_CHAMPS_RES060 (Shab max 230 m², description et message alignés).
  Avant : aucun dossier existant bloqué par ces corrections (comptage en lecture seule). Validation à blanc 855 tests OK,
  déploiement 0AfJv00000385lZKAQ. Après : seules ces 8 règles ont changé, conformes au paquet.
  Les autres anomalies restent non corrigées, sur décision de l'utilisateur.

## Fichiers touchés

- `docs/regles-validation/explications-proposees.md` (premier tableau avant / après)
- `docs/regles-validation/explications-toutes-regles.md` (version à valider : nom, description, message)

## Décisions prises

- On change la Description et le Message d'erreur ; jamais la formule ni l'état actif.
- Quand le message actuel contredit la formule, le message proposé suit la formule (ex. LEDS_Qte_INF : 20 / 12).

## Problèmes / points d'attention

- Anomalies vues dans les formules, non corrigées (hors demande) :
  - `Pro__c.Statut_Dossier_4` : « BBAR_TH174 » (faute de frappe), la branche TH174 ne se déclenche jamais.
  - `Pro__c.GLOBAL_METTRE_NON_APRES_CONVERSION` : toutes les branches testent le champ LEDS.
  - `Pro__c.LEDS_Qte_INF` : le message dit 50 / 20, la formule contrôle 20 / 12.
  - `Lead.Conversion_REMPLISSAGE_PAC060` : SHAB limitée à 225 m² alors que le calculateur va jusqu'à 230 m².
  - `Lead.BASE_ITE_ENVOYE_EN_CONF` : parenthèses mal fermées, le bloc « Leads » est imbriqué dans le bloc BD PAC.
  - `Lead.CONFIRM_TRAITEMENT3` : teste l'ancienne valeur (PRIORVALUE) au lieu de la nouvelle.

## Prochaines étapes

- [x] Relecture et validation du tableau par l'utilisateur.
- [x] Mise à jour en production des noms, descriptions et messages (145 règles) et contrôle avant / après.
- [x] Décider si on corrige les anomalies : 8 corrigées, le reste laissé tel quel (décision utilisateur).
- [ ] Sauvegarder sur GitHub (commit + push) avec l'accord de l'utilisateur.
