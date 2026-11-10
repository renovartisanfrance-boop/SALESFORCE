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
- **Protection** (déployée, `0AfJv0000037kIvKAI`, 65 tests) : une erreur dans le calcul ne bloque jamais
  l'enregistrement d'une Piste (statut « Erreur de calcul : … », ou rien n'est écrit si l'erreur survient avant).
  Limite : les dépassements de limites Salesforce (CPU, requêtes) ne peuvent pas être interceptés.
- **Champ « Retour calculateur »** sur la Piste (formule, déployé `0AfJv0000037lQHKAY`) : indice ≥ seuil zone verte
  (3,5) → « A confirmer- A Envoyer en visite », sinon « A confirmer- Sans envoi visite », vide si pas d'indice.
- Feuilles 1 et 2 du Google Sheet « test calculateur » : colonne O = montants du calculateur version 3.
- **Dossiers RES060** : champ « RES060- Indice calculateur » (créé par l'utilisateur sur Pro__c) rempli sur 199 des
  200 dossiers BAR_RES060- PAC (calcul version 3). Essai à blanc avec annulation avant : aucun prix ni commission
  modifié par le flow GererPrix ; seuls les compteurs/drapeaux « dernière modification » repartent à zéro (accepté).
  1 échec : a09Jv00000RkFnlIAF (règle de validation visite) → indice attendu -0,5.
- **Bono social = « RES- Bono Social Final » uniquement** (décision utilisateur) pour les dossiers : 26 indices
  recalculés et mis à jour (vide ou « Je ne sais pas » = Non, 146 dossiers). Feuille 3 colonne C remplacée par
  les mêmes valeurs : 199/200 identiques au Salesforce (le 200e est le dossier bloqué par la règle de visite).
- **Règle 220 m²** (déployée `0AfJv0000037lmrKAA`, 67 tests) : surface > `Surface_Max_m2__c` (220) → indice 0, zone rouge,
  statut « Surface supérieure à 220 m² : indice mis à 0 ». Mis à jour : 83 Pistes (essai à blanc avant : aucun
  autre champ modifié, pas de SMS/rappel effacé), 12 Dossiers, 12 lignes de la feuille 3 (199/200 identiques).
- **DR- Provenance** (Piste, formule existante, déployée `0AfJv0000037m7pKAA`) : si télépro et régie (lookups) sont
  vides, renvoie « Nom REGIE » (NonREGIE_miniAppAff__c). 1 185 pistes concernées, plus aucune vide avec Nom REGIE.
- **Toutes les pistes RES060 calculées** (bulk, job 750Jv000019FQULIA4) : 6 282 pistes jamais calculées → 6 273 mises
  à jour (seules les 4 cases RES060 ; essai à blanc avant : seul « DR modifs » repart à zéro, accepté). 9 refus
  (règle « année 4 chiffres »), toutes en info manquante. 651 pistes RES060 ont un indice : 205 visite, 446 sans.
- Champ « RES060- Retour calculateur » modifié en prod par l'utilisateur (pastilles 🟩/🟫, libellé) : recopié dans
  le dépôt, ainsi que le champ Pro__c.RES060_Indice_calculateur__c créé par l'utilisateur.
- Feuilles 1 et 2 (lignes retriées par l'utilisateur, montants restés sur leur ligne) : colonne O alignée sur le
  calculateur Salesforce, règle 220 m² appliquée (75 lignes feuille 1, 4 lignes feuille 2).
- **Champ « RES060- Tranche indice »** (formule, Piste et Dossier, déployé `0AfJv0000037mNxKAI`) : < 2,5 / 2,5-3,4 /
  3,5-4,9 / 5-6,9 / 7 et plus. Contrôlé : 655 pistes et 200 dossiers, 0 erreur de tranche.
- **Indice sans bonification** (Piste, RES060_Indice_Sans_Bonification__c) : même calcul avec fC = 1 (réglage
  Facteur_fC_Sans_Bonification__c) et sans bono ×1,5. Installé (`0AfJv0000037wDdKAI`, 68 tests, sans toucher
  « RES060- Retour calculateur » à la demande de l'utilisateur). 6 937 pistes « Type de dossier RES060 » recalculées
  en mémoire (indices normaux identiques) ; 669 indices sans bonification écrits (bulk 750Jv000019Ku5CIAS, 0 échec).
  Sans bonification : 662 sous 2,5, 5 entre 2,5 et 3,4, 2 au-dessus de 3,5.
- « RES060- Retour calculateur » re-modifié en prod par l'utilisateur (✅ / 🟨) : resynchronisé, ainsi que le jeu
  d'autorisations. Toujours comparer prod et dépôt avant de déployer.
- **Dossiers RES060, indice sans bonification** (champ Pro__c.RES060_Indice_sans_bonification__c créé par
  l'utilisateur, recopié dans le dépôt) : 200/200 remplis (bulk 750Jv000019KtAlIAK, 0 échec). Indices normaux
  revérifiés : 200/200 identiques.
- **10/11 : passage au calculateur officiel RES060_FM** (fichier « Eligibilite PAC telepro RES060FM indice (2) »),
  qui remplace le calcul FC : D_CAL officiel × 1,3 (arrondi au dixième) + 11 kWh/m² d'eau chaude, rendement fixe
  0,70 (l'année de chaudière ne sert plus), fM 2, 160 €/MWh, bono « RES- Bono Social » ×1,5, mitoyenneté
  (champ utilisateur « RES060- Medianería » : isolée 1 / 1 côté 0,95 / 2 côtés 0,85 / vide 0,95), 1 PAC ≤ 210 m²
  (6 600 €), cascade 211-320 m² (13 000 €), au-delà indice 0 ; gaz et fioul seuls éligibles. Maison après 1997 :
  calculée mais signalée (« · maison après 1997 » dans le statut, « ⚠️Maison après 97 · » devant
  « RES060- Retour calculateur », à la demande de l'utilisateur). Indice sans bonification = même calcul sans ×1,5.
  Tout est réglable dans `RES060_Parametre__mdt` (8 nouveaux réglages). Écran du simulateur adapté (mitoyenneté).
  Déployé `0AfJv00000381urKAA` (32 composants, 71 tests, couverture 97-99 %).
- Tableau D_CAL × 1,3 contrôlé contre le fichier : 188/192 identiques, 4 écarts de 0,1 (le fichier part de valeurs
  officielles plus précises), effet sur l'indice ≤ 0,02.
- Recalcul des pistes RES060 (7 379 dans le périmètre, 828 changent) : 710 écrites (bulk 750Jv000019R6GYIA0),
  **118 refusées** : 109 par la règle LEAD_ENVOI_CONF2 (modifiée le 10/11 par l'utilisateur : « RES060- Medianería »
  obligatoire pour les pistes en « Conf Ok- Att prévisite », non rempli sur les anciennes), 9 par « année 4 chiffres ».
  Revérifié : seules ces 118 restent à l'ancien calcul. Dossiers RES060 : 198/200 changés, 200/200 conformes.

## Fichiers touchés

- `force-app/main/default/` (classes, triggers, objects, customMetadata, layouts, tabs, permissionsets)
- `docs/conception/simulateur-res060.md`
- `legacy-app/main/default/objects/Lead/fields/DR_Provenance__c.field-meta.xml`
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
- [x] Recalcul des pistes RES060 (fait avec la formule FM le 10/11).
- [ ] 118 pistes encore à l'ancien calcul (règles LEAD_ENVOI_CONF2 et « année 4 chiffres ») : attendre la décision
      de l'utilisateur (assouplir la règle ou remplir la mitoyenneté), puis relancer `calcFM.apex` + bulk.
- [ ] « RES060- Retour calculateur » reste au seuil 3,5 (réglage Seuil_Zone_Verte 3 500) alors que la fiche FM
      accepte à partir de 4 : à confirmer avec l'utilisateur.
