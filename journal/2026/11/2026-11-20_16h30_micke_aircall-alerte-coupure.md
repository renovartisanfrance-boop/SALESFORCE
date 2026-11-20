---
date: 2026-11-20 16:30
auteur: micke
sujet: Aircall : alerte quand plus aucun appel ne remonte, et connexions vers l'ancien Salesforce (cedf) désactivées
statut: terminé
branche: micke/aircall-dossier
suite_de: 2026-11-20_14h00_micke_aircall-rattachement-dossier.md
---

## Objectif

Ne plus revivre la coupure du 20/10 au 19/11 (30 jours sans remontée d'appels, vue par personne), et ne garder
qu'une seule connexion Aircall → Salesforce.

## Ce qui a été fait

- Alerte de coupure, installée en prod (accord de l'utilisateur, 8 tests OK, couverture 100 %) :
  - `AircallSurveillanceSchedulable` → `AircallSurveillanceService` → `AircallSurveillanceSelector` ;
  - tâche planifiée « Aircall - surveillance des remontées », chaque heure du lundi au vendredi ;
  - si aucune fiche `Aircall__c` n'est arrivée depuis 3 h, entre 12 h (9 h + 3 h) et 19 h heure de Paris : e-mail d'alerte ;
  - 2 e-mails par jour au maximum, espacés d'au moins 3 h ;
  - réglages (horaires, délai, destinataires, actif) et mémoire des envois dans le paramètre personnalisé
    `Aircall_Surveillance__c` (Configuration > Paramètres personnalisés > Aircall - Surveillance > Gérer) ;
  - e-mail d'essai envoyé au destinataire (envoi accepté par Salesforce).
- Connexions Aircall (tableau de bord Aircall, accord de l'utilisateur « couper cedf ») :
  - 4 connexions pointaient vers l'ancien Salesforce `cedf.my.salesforce.com` : PRODUCTION (55 numéros),
    Renov (Prod) (15), Renov 12-05 (63), STANDARD- NEW (4). Toutes **désactivées** (interrupteur « Activate app »),
    pas supprimées : réactivables d'un clic.
  - Reste active : « Salesforce V3 » (id 237257, 63 numéros) → org `business-saas-1575` (Renov Artisan).

## Fichiers touchés

- `force-app/main/default/objects/Aircall_Surveillance__c/` (paramètre personnalisé et ses 8 champs)
- `force-app/main/default/classes/AircallSurveillance*.cls` (service, selector, schedulable, tests)

## Décisions prises

- Désactiver plutôt que supprimer les connexions cedf : réversible.
- Pas d'alerte avant 12 h : le silence de la nuit ne doit pas déclencher de fausse alerte.
- Adresse du destinataire rangée dans le paramètre personnalisé, pas dans le dépôt.

## Problèmes / points d'attention

- Jour férié ou journée très calme : fausse alerte possible.
- Une fiche créée à la main (import) compte comme une arrivée et peut masquer une coupure pendant 3 h.
- Si la tâche planifiée est supprimée, la relancer avec la ligne indiquée en tête de `AircallSurveillanceSchedulable`.

## Prochaines étapes

- [ ] L'utilisateur confirme la réception de l'e-mail d'essai (regarder aussi les indésirables).
- [ ] Automatisation « À rappeler » (choix en attente : durée minimale d'une conversation, une liste ou une par ligne).
- [ ] Clôture automatique des appels décrochés ; doublons de pistes (mesure d'abord).
