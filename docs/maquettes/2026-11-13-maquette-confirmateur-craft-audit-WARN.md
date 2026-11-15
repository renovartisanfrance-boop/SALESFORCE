# Audit visuel — maquette confirmateur (13/11/2026)

Skill utilisée : `experience-design-validate`. **Portée : qualité visuelle uniquement.** Ce bilan ne valide ni l'accessibilité, ni le bon fonctionnement, ni les performances, ni une mise en production.

```text
scope: visual-craft-only
verdict: WARN
evidence_mode: DYNAMIC_VISUAL
evidence_inventory:
  - Production › Confirmation › TER-179, liste Attribution, 1440x900 (capture entière)
  - Production › Messagerie, liste À traiter, 1440x900 (capture partielle, moitié gauche)
  - Menu utilisateur ouvert (zoom en haut à droite), 1440x900
  - Écran « Vous êtes déconnecté », 1440x900
  - Barre des onglets + ligne des outils (zoom), 1440x900
  - Actions jouées : ouverture du menu, déconnexion, reconnexion, passage Confirmation ↔ Messagerie
evidence_limitations:
  - Une seule largeur d'écran (1440 px) ; rien sur 1920 px ni sur petit écran
  - Clignotement de l'onglet Messagerie non observé (images fixes)
  - Accueil, Paramétrage, fiche client, panneau de conversation, fenêtres : non regardés
  - Icônes : visibles ici en local ; leur absence sur claude.ai n'est pas évaluée

first_impressions:
  - Propre et calme : un tableau lisible, peu de couleurs, le bleu réservé à ce qui est sélectionné.
  - Beaucoup d'étages avant le tableau : alerte, onglets, outils, fiches, listes, filtres (6 bandes).
  - L'onglet Messagerie rose attire l'œil en premier, avant la liste à traiter.

coverage_relevance_ledger:
  - {item: Useful, relevance: APPLICABLE, coverage: SCORED, evidence_mode: DYNAMIC_VISUAL, evidence: écran Confirmation, reason: contenu visible suffisant}
  - {item: Usable, relevance: APPLICABLE, coverage: SCORED, evidence_mode: DYNAMIC_VISUAL, evidence: barre des onglets et outils, reason: hiérarchie visible}
  - {item: Reliable, relevance: APPLICABLE, coverage: SCORED, evidence_mode: DYNAMIC_VISUAL, evidence: menu, déconnexion, changement d'onglet, reason: états joués directement ; limité à ces trois parcours}
  - {item: Coherent, relevance: APPLICABLE, coverage: SCORED, evidence_mode: DYNAMIC_VISUAL, evidence: 4 écrans, reason: plusieurs écrans comparables}
  - {item: Well-Crafted, relevance: APPLICABLE, coverage: SCORED, evidence_mode: DYNAMIC_VISUAL, evidence: toutes les captures, reason: détails visibles}
  - {item: navigation, relevance: APPLICABLE, coverage: SCORED, evidence_mode: DYNAMIC_VISUAL, evidence: onglets, fiches, listes, reason: visible}
  - {item: data (tableaux), relevance: APPLICABLE, coverage: SCORED, evidence_mode: DYNAMIC_VISUAL, evidence: deux listes, reason: visible}
  - {item: responsive, relevance: APPLICABLE, coverage: INSUFFICIENT_EVIDENCE, evidence_mode: DYNAMIC_VISUAL, evidence: aucune, reason: une seule largeur capturée}
  - {item: performance, relevance: APPLICABLE, coverage: INSUFFICIENT_EVIDENCE, evidence_mode: DYNAMIC_VISUAL, evidence: aucune, reason: maquette locale, rien de mesurable}
  - {item: ai, relevance: N/A, coverage: N/A, evidence_mode: DYNAMIC_VISUAL, evidence: aucune, reason: pas d'IA à l'écran}

dimensions:
  - name: Useful
    score: 7
    evidence: chaque bande sert (alerte, onglets, fiches, listes, tableau) ; seule la ligne d'aide « Filtres : aucun · cliquez l'entonnoir… » occupe une ligne entière en permanence
    gap_to_next_level: faire disparaître l'aide des filtres une fois connue, ou la réduire à une icône
  - name: Usable
    score: 6
    evidence: à 1440 px la barre des onglets ne tient pas ; Messagerie tombe seule à gauche sur une deuxième ligne, la recherche et les deux boutons à l'extrême droite ; le chemin principal (choisir une liste, traiter) reste clair
    gap_to_next_level: une barre d'onglets qui tient sur une ligne, ou une deuxième ligne assumée et alignée
  - name: Reliable
    score: 7
    evidence: menu utilisateur lisible (nom, profil, action en rouge) ; écran déconnecté sans ambiguïté avec un seul bouton ; onglet sélectionné toujours identifiable
    gap_to_next_level: l'écran déconnecté pourrait dire ce qu'il advient du travail en cours
  - name: Coherent
    score: 7
    evidence: mêmes pastilles, mêmes boutons, mêmes rayons partout ; écarts : « + New » en anglais dans une interface en français, nom en capitales dans l'en-tête et en minuscules dans le menu, un rose qui n'existe nulle part ailleurs
    gap_to_next_level: un seul libellé de langue et une seule écriture du nom
  - name: Well-Crafted
    score: 6
    evidence: nom d'utilisateur coupé (« CONFIRMATEUR- CHA… ») alors qu'il reste de la place ; dates coupées (« 05/11/202… ») dans la première colonne ; deuxième ligne d'outils née d'un retour à la ligne, pas d'un choix
    gap_to_next_level: plus aucun texte coupé dans l'en-tête ni dans la colonne des dates

findings:
  - severity: major
    primary_dimension: Usable
    related_dimensions: [Well-Crafted]
    location: Production, barre des onglets, 1440 px
    problem: les 12 onglets remplissent la ligne ; Messagerie passe dessous, seule à gauche, et la recherche, Récents et Actualiser partent à droite.
    why_it_weakens_craft: une ligne qui se casse toute seule donne l'impression d'un rangement subi ; l'œil cherche pourquoi Messagerie n'est pas avec les autres onglets.
    what_better_looks_like: soit tout sur une ligne, soit une ligne d'outils voulue, alignée et identique sur tous les écrans.
    fix: assumer la deuxième ligne comme « ligne d'outils » (Messagerie à gauche, recherche et boutons à droite) et l'afficher ainsi à toutes les largeurs ; ou raccourcir les onglets (icône seule pour les moins utilisés).
  - severity: minor
    primary_dimension: Well-Crafted
    related_dimensions: [Coherent]
    location: en-tête, en haut à droite
    problem: le nom est coupé (« CONFIRMATEUR- CHA… ») et écrit en capitales avec un tiret collé, alors que le menu affiche « Chauvet / Confirmateur ».
    why_it_weakens_craft: un nom coupé dans un en-tête presque vide paraît inachevé ; deux écritures du même nom à 20 px d'écart se remarquent.
    what_better_looks_like: « Chauvet » en clair, le profil en plus petit dessous ou à côté, jamais coupé.
    fix: afficher le nom en entier, même écriture que dans le menu.
  - severity: minor
    primary_dimension: Well-Crafted
    related_dimensions: []
    location: listes, colonne « Créé le »
    problem: la date est coupée (« 05/11/202… ») alors que d'autres colonnes ont de la place.
    why_it_weakens_craft: une date coupée ne se lit pas ; c'est la première colonne, donc la première chose vue sur chaque ligne.
    what_better_looks_like: date entière, ou date courte « 05/11 » comme dans « Rappel souhaité ».
    fix: donner à la colonne la largeur d'une date complète ou passer au format court.
  - severity: minor
    primary_dimension: Coherent
    related_dimensions: []
    location: onglet Messagerie
    problem: « + New » est le seul mot anglais de l'écran.
    why_it_weakens_craft: une langue qui change dans un seul bouton casse la voix du produit.
    what_better_looks_like: « + Nouveau » ou « + Message ».
    fix: choix de l'utilisateur à confirmer ; garder « + New » si c'est voulu.
  - severity: polish
    primary_dimension: Useful
    related_dimensions: []
    location: au-dessus des tableaux
    problem: la ligne « Filtres : aucun · cliquez l'entonnoir… » reste affichée même sans filtre.
    why_it_weakens_craft: une aide permanente prend la place d'une ligne de données sur un écran déjà très étagé.
    what_better_looks_like: la ligne n'apparaît que lorsqu'un filtre est actif.
    fix: masquer la ligne tant qu'aucun filtre n'est posé (l'entonnoir des colonnes suffit).

cross_cutting_patterns:
  - Textes coupés (nom d'utilisateur, dates) alors que la place existe.
  - Empilement de bandes au-dessus du tableau : chaque ajout récent a ajouté de la hauteur.

recommendations:
  - Décider la forme de la barre des onglets (une ligne ou deux lignes voulues).
  - Afficher le nom d'utilisateur en entier, même écriture que dans le menu.
  - Ne plus couper la date de la première colonne.
  - Trancher « + New » ou « + Nouveau ».
  - N'afficher la ligne des filtres que lorsqu'un filtre est actif.

fix_prompt: |
  But : que l'écran de Production paraisse rangé volontairement, sans texte coupé.
  1. Barre des onglets (Production) : en faire deux lignes voulues — onglets en haut, puis une ligne d'outils avec Messagerie à gauche et recherche, Récents, Actualiser à droite — identiques à toutes les largeurs.
  2. En-tête : nom d'utilisateur entier, même écriture que dans son menu.
  3. Listes : date de la première colonne lisible en entier.
  4. Onglet Messagerie : un libellé français pour le nouveau message, si l'utilisateur le confirme.
  5. Listes : ligne des filtres visible seulement quand un filtre est actif.
  Garder : la sobriété des couleurs, les pastilles de compteurs, le menu utilisateur, l'écran déconnecté.
  Vérifier sur de nouvelles captures à 1440 et 1920 px ; dimensions attendues en hausse : Usable, Well-Crafted, Coherent.
```
