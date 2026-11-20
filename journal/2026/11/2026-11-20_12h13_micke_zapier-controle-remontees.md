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

## Fichiers touchés

- `journal/2026/11/2026-11-20_12h13_micke_zapier-controle-remontees.md` (cette entrée)

## Décisions prises

- Aucun mot de passe confié à Claude : connexion par l'écran officiel Zapier.
- Lecture seule tant que l'utilisateur n'a pas dit oui : rien n'a été modifié dans Zapier ni dans Salesforce.

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

- [ ] Regarder les 93 exécutions retenues (quel Zap, quelles dates, pourquoi) avant toute relance ;
      une relance écrit dans Salesforce en production, donc accord de l'utilisateur obligatoire.
- [ ] Vérifier si les 20 lignes absentes font partie des 93 exécutions retenues ou d'erreurs Zapier,
      puis décider avec l'utilisateur de leur création dans Salesforce.
- [ ] Expliquer les ≈ 420 pistes en trop de la campagne `R1 26- KAF-Page3` (doublons).
- [ ] Demander si les 8 Zaps déjà éteints doivent aussi prendre le préfixe `inactif-`.
- [ ] Surveiller quelques jours qu'aucun lead attendu ne manque après l'extinction des 9 Zaps.
- [ ] Trouver, pour chaque Zap actif, la source (formulaire Facebook / site) et le champ Salesforce qui la repère.
- [ ] Premier rapprochement à la main sur les leads de la veille (source ↔ Pistes Salesforce).
- [ ] Programmer le contrôle chaque matin (tâche planifiée), manquants listés sans renvoi automatique.
