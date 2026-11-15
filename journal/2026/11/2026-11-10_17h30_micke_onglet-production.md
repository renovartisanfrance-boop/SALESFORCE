---
date: 2026-11-10 17:30
auteur: micke
sujet: Maquette confirmateur : un seul onglet Production, tableau commun partout
statut: terminé
branche: micke/simulateur-res060
suite_de: 2026-11-06_09h57_micke_simulateur-res060.md
---

## Objectif

Regrouper Pistes et Dossiers de la maquette en un seul onglet « Production », puisque la visibilité
(onglets → fiches → listes de vue) se règle entièrement dans Paramétrage, et simplifier le code :
un seul tableau, un seul jeu de filtres, de tri et de saisie pour toute l'interface.

## Ce qui a été fait

- Menu réduit à Accueil · Production · Paramétrage. Production affiche les 8 onglets autorisés à la personne
  (Leads, Data, Confirmation | Prévisite, Signature, Statut docs, Envoi en pose, Dépôt dossier), ses fiches, puis les listes de vue.
- L'écran Confirmation utilise maintenant le tableau commun (glTable), avec ses règles métier branchées :
  tri par priorité puis échéance, saisie date + créneau, enregistrement avec historique, SMS automatique (NRP 1x et 3x),
  prochain appel calculé, icône doublon, fiche client / conversion, fichiers et historique.
- Le tableau commun accepte des colonnes sur mesure (texte de filtre, clé de tri, saisie, affichage d'une valeur modifiée)
  et des réglages par liste (tri de départ, enregistrement, fenêtres fichiers / historique).
- Code retiré : ancien tableau Confirmation et ses filtres, écrans Pistes / Dossiers / Prévisite séparés,
  réglage caché « Échéances » (règle A/B), mémorisation des tris, variables orphelines. 1 404 → 1 271 lignes.
- Bouton Actualiser relié ; les autres boutons vérifiés un par un dans le navigateur, sans erreur de console.
- Analyse mise à jour (`docs/analyse/04-poste-confirmateur.md`, paragraphe « Un seul onglet Production »).

## Fichiers touchés

- `docs/maquettes/maquette-confirmateur.html`
- `docs/analyse/04-poste-confirmateur.md`

## Décisions prises

- Un seul onglet Production : la coupure Pistes / Dossiers ne décidait plus de rien, le Paramétrage fait tout.
- Les groupes « Pistes » et « Dossiers » restent dans Paramétrage comme noms des objets Salesforce (séparateur dans Production).
- Échéances (règle A/B par fiche) supprimé : une date sans créneau vaut « dès 9 h, sous le délai nouvelle piste ».
- Pastille d'une fiche = total de ce que la personne verra sur l'onglet choisi (règle unique, même pour Hors cible).

## Problèmes / points d'attention

- Le bouton SMS reste un bouton de présentation (choix du modèle à faire dans la vraie version).
- Les données Leads, Data et Dossiers sont fictives ; seules Confirmation et Prévisite ont des données reliées (conversion → Prévisite).
- Rien n'est poussé sur GitHub : `docs/` et le journal sont encore non suivis (`??`), en attente de l'accord de l'utilisateur.

## Prochaines étapes

- [ ] Sauvegarder sur GitHub (commit + push) avec l'accord de l'utilisateur.
- [ ] Reporting (Accueil), puis Espagne (RES-060) et les sujets mis de côté.
- [ ] Passer aux vrais LWC / Apex dans la sandbox pcp1.
