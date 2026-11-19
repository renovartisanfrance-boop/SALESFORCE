---
date: 2026-11-19 17:00
auteur: micke
sujet: Aircall : coupure de la remontée des appels (20/10 → 19/11) et récupération de la ligne PARTENAIRES EXTERNE
statut: terminé
branche: micke/commentaire-piste-unique
suite_de:
---

## Objectif

Comprendre pourquoi la liste de vues « PARTENAIRES- 0.Demandes à traiter » (objet `Aircall__c`)
s'arrête au 20 octobre, et récupérer les appels manquants de la ligne +33 6 52 55 47 04.

## Ce qui a été fait

- Constat (prod, lecture) : plus aucune fiche `Aircall__c` ni tâche d'appel créée entre le
  20/10/2026 15h50 (heure de Paris) et le 19/11/2026 au matin, **toutes lignes confondues**.
  La remontée a repris le 19/11 avec la nouvelle connexion Aircall « Salesforce V3 »
  (id 237257, org `business-saas-1575`, 63 numéros).
- Chaîne de création vérifiée : Aircall crée une tâche → flux `TASK_AFTER_CreateUpdate` crée la fiche
  `Aircall__c` (statut par défaut « ▣ En Attente de Traitement »). Le flux `AIRCALL_FT_AfterCreateUpdate`
  n'agit que si « 🟩Piste crée » ou une Lettre est renseignée → rien ne se déclenche à l'import.
- Ligne « PARTENAIRES EXTERNE » (+33652554704) : 23 messages vocaux relevés dans Aircall
  (Conversation center) entre le 20/10 17h33 et le 18/11 10h55, absents de Salesforce.
- Import en prod (accord explicite de l'utilisateur) de 23 fiches `Aircall__c` : SA-55889 à SA-55911.
  - Objet au format Aircall (`Voicemail from … on PARTENAIRES EXTERNE`) → Statut calculé identique.
  - Traitement « ▣ En Attente de Traitement », lien du message vocal du jour de l'appel.
  - Date réelle de l'appel dans « LETTRE- Commentaire Traitement ».
  - Piste liée quand le numéro correspondait à une piste (10 numéros sur 17).
- Aucune tâche (Task) recréée, aucune modification dans Aircall.
- Ensuite, à la demande de l'utilisateur : suppression (corbeille) des fiches dont le correspondant a eu
  une conversation plus tard (appel entrant ou sortant, toutes lignes, d'après l'historique Aircall) =
  messages déjà traités. 10 fiches supprimées : SA-55889, 55891, 55893, 55896, 55898, 55905, 55906,
  55907, 55908, 55911. Restent 13 fiches à traiter.
- SA-55889 restaurée ensuite à la demande de l'utilisateur (appel sortant de 45 s seulement, peut-être
  le répondeur). Total : 9 supprimées, 14 fiches à traiter.

## Fichiers touchés

- Aucun fichier du dépôt (données prod uniquement). Script d'import dans le dossier temporaire de session.

## Décisions prises

- Date de création = aujourd'hui (demande de l'utilisateur), date d'origine indiquée dans le commentaire.
- Doublons de pistes (Galardon ×3, Kremer ×2) : rattaché à la plus ancienne (`00QbR00000LoTM4UAN`, `00QbR00000LocyxUAB`).

## Problèmes / points d'attention

- Les autres lignes ont aussi perdu leurs appels du 20/10 au 19/11 : non récupérés.
- Plusieurs numéros sont branchés sur plusieurs connexions Aircall (PRODUCTION → org `cedf`, Renov 12-05, Salesforce V3)
  → risque d'appels envoyés dans deux Salesforce.
- Seuls les messages vocaux apparaissaient pour cette ligne dans Aircall sur la période.

## Prochaines étapes

- [ ] Décider si on récupère aussi les appels manquants des autres lignes.
- [ ] Faire le tri des connexions Aircall en double.
