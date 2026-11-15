---
date: 2026-11-11 08:36
auteur: micke
sujet: Portail installateur ECONATURA : relecture et suppression du code inutile
statut: en cours
branche: micke/simulateur-res060
suite_de:
---

## Objectif

Relire la maquette du portail installateur ECONATURA (v71, publiée depuis un autre compte Claude),
retirer le code qui ne sert plus, puis la modifier ensemble.

## Ce qui a été fait

- Maquette récupérée depuis https://claude.ai/artifact/3Uq5Z1DDy7jkk79h14dxS4 et copiée dans le dépôt.
- Code inutile retiré : 3 444 → 2 837 lignes (−607), 202 Ko → 166 Ko.
  - 5 écrans qu'aucun bouton n'ouvrait plus : « Date de pose enregistrée + SMS », « Planifiées », « Chantier »
    (étapes Certiko), « Mes SAV » et « Fiche SAV » (anciennes versions, remplacées par le planning et « SAV à planifier »).
  - Le JavaScript qui allait avec : chStart, chEnd, savChange, copySms, sortS, rowS, renderS, fmodif, techLate,
    renameTeam, fillTeamSelect, la table TECH_TEAM, la liste `techlist`, 4 SAV d'exemple créés puis aussitôt effacés,
    champs de données jamais lus (`modif`, `team` en double, `name` des équipes), branches jamais atteintes.
  - 134 sélecteurs CSS sans élément correspondant (−13 Ko).
- Vérification : parcours automatique de 44 étapes dans Chrome (accueil, dépôt, équipes, techniciens, récap camion,
  à planifier, fixer la date sur 2 jours, SAV, planning, replanification, clôture avec doublon, vues liste, KPI,
  facturation) sur l'original et sur le fichier nettoyé : texte identique, captures identiques au pixel, 0 erreur.

- Republié sur ce compte : https://claude.ai/artifact/NJY6vow9xHFpDYXT16FxGs (c'est désormais l'adresse de travail).
- v73 — les installations ne sont plus « à planifier » mais **proposées** :
  - ECONATURA fixe 3 dates (3 jours distincts) ; l'installateur valide l'une d'elles ou rend le chantier.
  - Nom, téléphone et adresse du client masqués (liste, fiche, fenêtre de confirmation, recherche) jusqu'à la validation ;
    seuls la référence, la province, le trajet depuis le dépôt et le matériel sont visibles.
  - Pour chaque date, l'installateur choisit une de ses équipes libres ce jour-là (trajets dépôt / veille affichés).
  - Après validation : le chantier entre au planning et la fiche client s'ouvre avec les coordonnées.
  - Offre envoyée à plusieurs installateurs : le premier qui valide l'obtient ; un bouton « Démo » simule
    la disparition d'une ligne prise par un autre.
  - Retirés car devenus sans objet : compteur de tentatives d'appel sur les installations, historique du dossier,
    placement d'une installation dans le planning, pose sur 2 jours (J1/2, J2/2, « 2e jour déjà pris »).
  - Les SAV ne changent pas.
  - Vérifié dans Chrome : 22 contrôles automatiques (masquage, 3 dates, validation, rendre, démo, SAV, clôture), 0 erreur.

## Fichiers touchés

- `docs/maquettes/econatura/portail-installateur.html` (version nettoyée, à utiliser)
- `docs/maquettes/econatura/portail-installateur-v71-original.html` (copie de la v71 telle que publiée, pour comparaison)

## Décisions prises

- Aucune modification de comportement ni d'apparence dans cette passe : uniquement des suppressions.

## Problèmes / points d'attention

- La republication sur la même URL a été refusée : l'artifact appartient à un autre compte Claude et ce compte
  n'a pas le droit de le modifier. Il faut soit partager l'artifact en modification avec ce compte, soit republier
  le fichier depuis le compte d'origine.
- Défauts repérés, non corrigés (ce ne sont pas des suppressions) : le message « SAV créé » s'affiche dans le planning
  et non sur l'écran « SAV à planifier » où l'on se trouve ; la pagination de la facturation est décorative ;
  les 4 boutons « Copier » ont chacun leur copie du même code.
- Rien n'est poussé sur GitHub.

## Prochaines étapes

- [ ] Régler l'accès en modification à l'artifact (ou republier depuis l'autre compte).
- [ ] Modifier le portail avec l'utilisateur.
- [ ] Sauvegarder sur GitHub avec l'accord de l'utilisateur.
