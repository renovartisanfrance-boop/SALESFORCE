---
date: 2026-11-20 12:13
auteur: micke
sujet: Zapier connecté à Claude, premier état des Zaps (contrôle des remontées de leads)
statut: en cours
branche: micke/commentaire-piste-unique
suite_de:
---

## Objectif

Mettre en place un contrôle automatique : vérifier chaque matin que les leads de la veille
sont bien arrivés dans Salesforce, et lister ceux qui ne sont pas passés.
Première étape : connecter Zapier et voir quels Zaps servent encore.

## Ce qui a été fait

- Connecteur Zapier (officiel, `mcp.zapier.com`) connecté par l'utilisateur sur son compte Claude.
- Applis visibles côté Zapier : Formidable Forms, Google Sheets, Gmail, Facebook Conversions,
  Facebook Lead Ads, Salesforce (5 connexions Salesforce, à trier).
- Appli « Zapier Manager » activée en **lecture seule** (les 3 actions d'écriture
  — allumer/éteindre un Zap, inviter un membre, valider une demande — ont été retirées).
- Liste des 11 Zaps : tous allumés.
- Consommation de tâches par Zap sur la période de facturation en cours (16/11 → 16/12) :
  - `ES- PAC 1EU- Ryan- page 3` (379625571) : 1 608 tâches
  - `ES- PAC 1EU-Yossef` (379353253) : 226 tâches
  - les 9 autres : aucune tâche facturable depuis le 16/11.

- **Sur demande de l'utilisateur (20/11, 12h17)** : les 9 Zaps sans tâche depuis le 16/11 ont été **éteints**
  dans Zapier. Restent allumés : `ES- PAC 1EU- Ryan- page 3` et `ES- PAC 1EU-Yossef`.
  Zaps éteints (numéro Zapier entre parenthèses, pour les rallumer si besoin) :
  - `(Copy) ES- PAC 1EU- Ryan- page 3` (385868859)
  - `ES- PAC 1EU- Ryan- page 2` (379516328)
  - `ES- PAC 1EU- Ryan` (379489962)
  - `Y1- PAC 1EU2` (330817998)
  - `Formulaire Meta Ads / Salesforce` (265602934)
  - `ma-prime-eco-renovation-globale / Salesforce` (265598247)
  - `mon-isolation-par-exterieur.fr : CF7 / Salesforce` (263858853)
  - `mon-isolation-par-exterieur.fr : FF / Salesforce` (263848402)
  - `mon-isolation-par-exterieur.fr : Quform / Salesforce` (263838015)
- Le droit d'allumer/éteindre un Zap a été retiré de nouveau après l'opération.
- **Renommage en `inactif-…` : fait** pour les 9 Zaps éteints, par le site zapier.com dans le Chrome de
  l'utilisateur (le connecteur Zapier n'a aucune action pour renommer). Vérifié sur la liste Zapier.
- Colonne « Last run » de Zapier (vue après coup) : 8 des 9 Zaps éteints affichent « None in 60 days » ;
  `(Copy) ES- PAC 1EU- Ryan- page 3` a tourné une fois le **05/11/2026** (jour où il a été allumé).
- 8 autres Zaps étaient **déjà éteints** avant cette session et n'ont pas été renommés :
  `(Copy) Y1- PAC 1EU2`, `Y1- AGRI 117`, `Y1- 179`, `AGRI 119 Y1`, `M1- LEDS 1E`, `Y1- LEDS 1E`,
  `Leads Manuels : Sheets / Salesforce`, `Meta Conversion Leads`.
- **Zapier affiche « 93 held Zap runs », retenus jusqu'au 19/12/2026** : 93 exécutions en attente,
  donc probablement des leads pas arrivés dans Salesforce. Rien n'a été relancé.

- **Contrôle des 2 Zaps actifs (20/11, lecture seule)** : chaque ligne des feuilles Google comparée aux
  Pistes Salesforce créées depuis le 01/09 (par téléphone, 9 derniers chiffres, ou e-mail).
  - `ES- PAC 1EU- Ryan- page 3` : classeur « PAC RAYAN ESPAGNE », feuille `EXCLUSION`, colonne déclencheur
    « Date d'ajout » → Piste avec Campagne (`Origine_de_la_demande__c`) = `R1 26- KAF-Page3`.
    7 538 lignes (10/09 → 20/11) : 7 526 trouvées, **12 absentes** (toutes entre le 02/11 et le 19/11).
  - `ES- PAC 1EU-Yossef` : classeur « Leads Ecotanura PAC Espagne », feuille `Leads PAC`, colonne déclencheur
    « Nom » → Campagne = `Y1 26- FB 1`. 3 025 lignes : 3 016 trouvées, **8 absentes** (22/09 → 14/11)
    - 1 ligne de test.
  - Les 20 absentes ont été recherchées dans toutes les Pistes et tous les Contacts (y compris supprimés) : introuvables.
  - Écart non expliqué : Salesforce compte 7 956 pistes `R1 26- KAF-Page3` pour 7 538 lignes de feuille
    (≈ 420 de plus) ; la feuille contient 309 lignes en double. Doublons créés par le déclencheur
    « New or Updated row » ? À vérifier.

- **Cause des 93 exécutions retenues (lu dans l'historique Zapier)** : statut « On hold – Disconnected app ».
  La connexion Salesforce de Zapier (`renov.artisan.france@gmail.com`, créée le 8 sept.) a été coupée
  du **20/10 vers 16h18 au 21/10 vers 11h42**. Répartition : Ryan page 3 ≈ 39, Yossef ≈ 50.
  - Ces leads **sont déjà dans Salesforce** : les lignes des feuilles datées de cette fenêtre (60 + 58)
    ont presque toutes une piste créée le 21/10 entre 11h et 14h (heure de Paris), après la reconnexion.
    Une seule ligne de la fenêtre est absente.
  - **Ne pas relancer les 93** : cela créerait des doublons.
  - Même jour que le début de la coupure Aircall (20/10) : cause commune probable côté Salesforce
    (hypothèse, non vérifiée).
- **Cause trouvée pour une partie des 20 leads absents** : 16 exécutions « Errored » sur les 2 Zaps depuis
  septembre. Les 9 ouvertes ont toutes la même erreur Salesforce : `Ville : valeur de données trop élevée
(max length=40)` — le client a tapé son adresse complète dans le champ ville.
  10 des 20 absents correspondent à une de ces erreurs (9 Ryan page 3, 1 Yossef).
  Les 10 autres (3 Ryan page 3, 7 Yossef) n'ont pas d'erreur visible : cause non trouvée.

- **Écriture en production, sur accord explicite de l'utilisateur (20/11, vers 13h07)** : les 20 pistes
  absentes ont été créées dans Salesforce avec exactement les mêmes champs que ceux remplis par leur Zap
  (type d'enregistrement « AA- RESIDENTIEL- INTERNE », Origine `LEADS`, Statut `New`, Type de dossier
  `RESIDENTIEL_REGIES_-_RES060`, Campagne `R1 26- KAF-Page3` ou `Y1 26- FB 1`, champs « Formulaire » et
  « ADMIN- Heure de création » repris tels quels de la feuille). 12 pour Ryan page 3, 8 pour Yossef.
  - Seul écart avec la feuille : la **ville coupée à 40 caractères** pour 10 d'entre elles.
  - Résultat : 20 créées, 0 refus. Elles sont arrivées dans la file « ATTRIBUTION RDV REGIES/LEADS »,
    comme celles créées par les Zaps.
  - Les 10 lignes sans erreur Zapier connue ont été acceptées sans problème par Salesforce : le Zap ne les
    avait donc probablement jamais envoyées (ligne non détectée par Zapier). Cause exacte non trouvée.

## Fichiers touchés

- `journal/2026/11/2026-11-20_12h13_micke_zapier-controle-remontees.md` (cette entrée)

## Décisions prises

- Aucun mot de passe confié à Claude : connexion par l'écran officiel Zapier.
- Lecture seule tant que l'utilisateur n'a pas dit oui : rien n'a été modifié dans Zapier ni dans Salesforce.

- **Projet « remontée des leads sans Zapier » — phase d'exploration, rien de construit (décisions de
  l'utilisateur, 20/11)** :
  - Une feuille Google par fournisseur ; une feuille = une régie fixe ; fournisseur interne ou externe.
  - Jusqu'à 50 feuilles × 50–70 leads/jour : Salesforce lit les feuilles toutes les 3 minutes
    (pas un script par feuille) et écrit le résultat dans une colonne « Remonté ».
  - Doublon : comparé à toutes les pistes, le premier fournisseur garde le lead ; pas de nouvelle piste,
    message dans la feuille avec le **code fournisseur** (jamais le nom), historique gardé dans Salesforce.
  - Faux numéro (mauvais nombre de chiffres, préfixe ni espagnol ni français, numéro inventé) : noté et
    historisé ; **si l'e-mail est valable, le lead remonte quand même**.
  - Prix : prix de référence dans Salesforce par fournisseur et période, comparé à la colonne prix du
    fournisseur ; un écart est signalé mais ne bloque pas le lead.
  - Deux modes de tarif d'achat : prix fixe par lead, ou pourcentage de campagne (le fournisseur paie la
    publicité et refacture budget + 10 à 13 %) avec coût par lead calculé à la clôture.
  - Chaque lead porte **deux prix** : prix d'acquisition et prix de revente à la régie, avec possibilité
    de reprendre le même prix.
  - Achat : le fournisseur est payé sur **tous** les leads qu'il envoie ; un doublon avec un autre
    fournisseur ne lui est pas imputable (il reste à la charge de l'entreprise).
  - Revente : prix fixé par l'utilisateur pour ses régies internes, distinct du prix d'achat.
  - Suivi : compte rendu de Claude toutes les heures dans une discussion dédiée.

## Problèmes / points d'attention

- Zapier ne donne pas la date de dernière exécution d'un Zap par le connecteur. La mesure utilisée
  est le nombre de tâches facturables depuis le **16/11** (début de période), pas depuis le 1er novembre.
  Un Zap qui se déclenche mais s'arrête sur un filtre compte 0 tâche.
- L'historique complet (`zapier.com/app/history`) demande une connexion de l'utilisateur dans le navigateur.
- 1 608 tâches en 4 jours sur un seul Zap : vérifier le plafond du forfait Zapier
  (un plafond atteint met les leads en attente).
- Dans Salesforce, les leads créés par Zapier le sont sous le compte administrateur
  (renov.artisan.france@gmail.com) : impossible de les distinguer par créateur. Il faudra un champ
  qui identifie le Zap ou le formulaire d'origine pour faire le rapprochement.

## Prochaines étapes

- [x] Créer les 20 pistes absentes dans Salesforce (fait le 20/11, ville coupée à 40 caractères).
- [ ] Avec accord : corriger les 2 Zaps pour couper la ville à 40 caractères (sinon l'erreur reviendra).
- [ ] Chercher la cause des 10 absents sans erreur visible (recherche par nom dans l'historique Zapier).
- [ ] Vérifier les 7 exécutions en erreur non ouvertes (15/10, 19/10, 25/10, 28/09 ×2, 06/11, 05/11).
- [ ] Ne pas relancer les 93 exécutions retenues (doublons) ; les laisser expirer le 19/12 ou les écarter.
- [ ] Expliquer les ≈ 420 pistes en trop de la campagne `R1 26- KAF-Page3` (doublons).
- [ ] Demander si les 8 Zaps déjà éteints doivent aussi prendre le préfixe `inactif-`.
- [ ] Surveiller quelques jours qu'aucun lead attendu ne manque après l'extinction des 9 Zaps.
- [ ] Trouver, pour chaque Zap actif, la source (formulaire Facebook / site) et le champ Salesforce qui la repère.
- [ ] Premier rapprochement à la main sur les leads de la veille (source ↔ Pistes Salesforce).
- [ ] Programmer le contrôle chaque matin (tâche planifiée), manquants listés sans renvoi automatique.
