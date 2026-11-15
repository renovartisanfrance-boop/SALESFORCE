---
date: 2026-11-11 10:00
auteur: micke
sujet: Maquette confirmateur : onglets Stock et SAV ; Contrôle = erreurs, mails auto, SMS auto, alertes, retards, relances ; attribution en listes de vue
statut: terminé
branche: micke/simulateur-res060
suite_de: 2026-11-10_17h30_micke_onglet-production.md
---

## Objectif

Ajouter un onglet « Stock » à l'écran Production de la maquette, avec exactement la même logique que les
autres onglets : Visibilité Onglets → Visibilité Fiche → Visibilité Listes de vue, tableau commun.

## Ce qui a été fait

- Onglet **Stock** (icône colis) ajouté après Dépôt dossier, avant SAV (déplacé en fin de journée ; d’abord après Envoi en pose), dans le groupe Dossiers.
- Quatre listes de vue : À commander, Commandé · en attente, Reçu en dépôt, Sorti pour la pose.
- Colonnes : Signé le, Client, Ville, Équipement, Référence article, Quantité, Fournisseur, Commandé le,
  Livraison prévue, Reçu le, Dépôt, Statut stock, Commentaire (types Salesforce déclarés : texte, nombre,
  relation, dates, listes de choix).
- Par défaut pour les closers (avec Envoi en pose) ; la personne connectée le voit pour la démonstration.
- Vérifié dans le navigateur : les 20 listes (5 fiches × 4 listes) s'affichent sans erreur ; l'onglet apparaît
  dans Visibilité Onglets (9 colonnes, sans débordement) et dans Visibilité Listes de vue ; décocher Stock
  pour la personne le retire bien de Production.
- Analyse mise à jour (`docs/analyse/04-poste-confirmateur.md`, paragraphe « Onglet Stock »).

- **Contrôle › Erreurs des utilisateurs** : troisième vue de Contrôle, tableau commun des refus d’enregistrement
  (quand, utilisateur, profil, fiche, enregistrement, onglet, origine, règle ou flux, message vu, commentaire responsable ;
  le statut de suivi a été retiré à la demande de l’utilisateur) avec 12 exemples fictifs ; résumé en tête (à voir, règle la plus fréquente, personne la plus bloquée).
  Côté Salesforce : objet « Journal des erreurs », écrit par le portail (règles de validation, message préfixé d’un code
  [RV-xx]) ou par le flux lui-même (chemin d’erreur). Vérifié dans le navigateur, sans erreur.

- Contrôle réordonné : Historique des modifications (par défaut), Erreurs des utilisateurs, Alertes d’incohérence ;
  les alertes passent en tableau (Niveau, Alerte), comme l’historique.

- Onglet **Mail auto** retiré du Paramétrage (modèle / délai / activation par fiche : à gérer dans Salesforce) ;
  remplacé par deux registres dans Contrôle : **Mails auto** et **SMS auto** (quand, client, modèle, événement,
  déclenché par, résultat, texte du SMS), avec données fictives. Un SMS auto déclenché depuis Confirmation (NRP 1x / 3x)
  s’ajoute en direct au registre. Ordre final des vues de Contrôle : Historique des modifications, Historique Mails auto, Historique SMS auto,
  Historique Erreurs, Alertes d’incohérence ; colonnes des trois historiques dans l’ordre Quand, Fiche, Déclenché par / Utilisateur, Client, puis le reste.

- Onglet **SAV** ajouté après Dépôt dossier (groupe Dossiers), même logique : listes Nouvelles demandes, Intervention planifiée,
  En attente de pièce, Clôturées ; colonnes motif, priorité, garantie, technicien, date d’intervention… ; par défaut pour les secrétaires.

- Onglet **Attribution manuelle** retiré du Paramétrage. À la place, une liste **« Attribution »** en tête de chaque onglet Pistes
  (Leads, Data, Confirmation) pour chaque fiche, réglée dans Visibilité Listes de vue comme les autres ; elle alimente le bandeau
  « à attribuer » (une personne retirée de la liste n’a plus le bandeau) et affiche les pistes en attente dans Production.
  Contrôle signale une fiche sans liste « Attribution » ou dont tout le profil en est retiré. Paramétrage : six onglets.
  Vérifié dans le navigateur (listes, comptes, bandeau, retrait, Contrôle), sans erreur.

- Trait noir après la liste « Attribution » (Production et Visibilité Listes de vue).

- **Relances & priorités** retiré du Paramétrage (cinq onglets) et déplacé à la fin de Contrôle, scindé en deux vues :
  **Retards en cours** (toutes les pistes en retard, tous utilisateurs : personne, onglet, fiche, client, statut, durée, liste ;
  résumé en tête et pastille par personne ; calcul en direct) et **Relances & priorités** (configuration par onglet existante).
  Contrôle s’ouvre maintenant sur Alertes d’incohérence. Vérifié dans le navigateur : 58 retards fictifs listés, réglage d’un délai
  depuis Contrôle tracé dans l’historique, aucune erreur.

- Correction : **Relances & priorités** revient en onglet du Paramétrage ; **Attribution Auto** et Relances & priorités passent
  à la fin, en orange « en attente de dev ». **Retards en cours** reste dans Contrôle, juste après Alertes d’incohérence,
  avec deux lectures : les plus en retard, ou par utilisateur (liste déroulante ou clic sur la pastille d’une personne).
  Le bandeau « à attribuer » n’apparaît plus sur les onglets Dossiers de Production. Vérifié dans le navigateur, sans erreur.

- Stock déplacé après Dépôt dossier partout ; dans Retards en cours, filtre par onglet en haut (Tous, Leads, Data,
  Confirmation, avec les comptes), combinable avec les deux lectures.

- Stock et SAV : titres rattachés à leurs objets Salesforce (« Stock- Matériel », « SAV- Demandes », objet indiqué sous
  chaque tableau de Production) ; Retards en cours sans Téléphone ni Étape.

- Bouton SMS manuel retiré de Production ; bouton d’actualisation libellé « Actualiser » (icône seule invisible sur claude.ai).

- **Page client commune** : le nom est cliquable sur toutes les listes et ouvre une page (infos client, champs de la liste,
  historique, fichiers, objet Salesforce) ; avant, seul Confirmation avait une page, les autres un simple message.
  Vérifié sur toutes les listes de tous les onglets (164 listes ouvertes sans erreur).

- Bouton « Simuler : nouvelle fiche créée dans Salesforce » retiré du Paramétrage.

- **Relecture complète du code** : statut modifié = changement de liste sur tous les onglets (bug d’affichage Prévisite corrigé),
  SMS auto Leads / Data et e-mail de conversion inscrits dans Contrôle, page client et Récents reliés à tous les onglets,
  sommaire d’intégration en tête du script, définitions uniques (objOf, attrSf). Test de non-régression identique avant / après
  (160 combinaisons personne × onglet × fiche), 164 listes ouvertes sans erreur.

## Fichiers touchés

- `docs/maquettes/maquette-confirmateur.html` (1 271 → 1 431 lignes)
- `docs/analyse/04-poste-confirmateur.md`

## Décisions prises

- Modèle, délai et activation des mails auto par fiche : réglés dans Salesforce seul (décision du 11/11/2026),
  plus de panneau dans Paramétrage.

- Une ligne de Stock = le matériel d'un dossier client (même objet Dossier que les autres onglets du groupe),
  pas un inventaire par article. À confirmer avec l'utilisateur.

## Problèmes / points d'attention

- Données fictives ; listes et colonnes à confirmer à l'étape Dossiers.
- Toujours rien de poussé sur GitHub (docs/ et journal non suivis), en attente de l'accord de l'utilisateur.

## Prochaines étapes

- [ ] Réécrire les messages des règles de validation de l’org avec un code [RV-xx] et une phrase claire (autre conversation).

- [ ] Confirmer le contenu de Stock (par dossier ou inventaire par article).
- [ ] Sauvegarder sur GitHub (commit + push) avec l'accord de l'utilisateur.
- [ ] Reporting (Accueil), puis Espagne (RES-060) et les sujets mis de côté.
