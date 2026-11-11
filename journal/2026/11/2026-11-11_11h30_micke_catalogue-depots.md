---
date: 2026-11-11 11:30
auteur: micke
sujet: Création des objets Catalogue de produits et Dépôts en production
statut: terminé
branche: micke/catalogue-depots
suite_de: 2026-11-11_10h00_micke_onglet-stock.md
---

## Objectif

Créer dans Salesforce deux objets isolés : le catalogue de produits (fenêtre « Nouveau produit »
de la maquette) et les dépôts logistiques (fenêtre « Nouveau dépôt »), avec des champs proposés
largement ; l'utilisateur supprimera ceux qui ne servent pas.

## Ce qui a été fait

- Objet `Produit_Catalogue__c` (« Catalogue de produits ») : 30 champs (référence, famille, marque,
  modèle, unité, fournisseur habituel, prix achat/vente, TVA, marge calculée, seuil d'alerte,
  suivi n° de série, puissance, ETAS, COP, classe énergétique, fluide, fiches CEE, garantie…).
- Objet `Depot__c` (« Dépôts ») : 20 champs (type, logisticien, adresse, départements desservis,
  géolocalisation, responsable, téléphone, e-mail, horaires livraison/retrait, accès, coût, contrat…).
- Mises en page, onglets, vue de liste « Tous », jeu d'autorisations `Catalogue_et_Depots`.
- Contrôle à blanc puis **déploiement en production avec l'accord explicite de l'utilisateur**
  (59 éléments, uniquement des créations). Jeu d'autorisations attribué à renov.artisan.france.

## Fichiers touchés

- `force-app/main/default/objects/Produit_Catalogue__c/`, `force-app/main/default/objects/Depot__c/`
- `force-app/main/default/layouts/Produit_Catalogue__c-Produit.layout-meta.xml`, `Depot__c-Depot.layout-meta.xml`
- `force-app/main/default/tabs/Produit_Catalogue__c.tab-meta.xml`, `Depot__c.tab-meta.xml`
- `force-app/main/default/permissionsets/Catalogue_et_Depots.permissionset-meta.xml`

## Décisions prises

- « Fournisseur habituel » et « Logisticien » = recherche vers Compte (les intervenants sont des Comptes ;
  aucune valeur « Fournisseur » dans Type Intervenant, on n'a pas modifié ce champ existant).
- Objets isolés : aucun champ ajouté sur un objet existant (`STOCK__c`, `CatalogueTarifaire__c` intacts).
- Sandbox pcp1 non utilisée : session expirée, et l'utilisateur a demandé la prod directement.

## Problèmes / points d'attention

- Le stock _dans_ un dépôt demande un 3ᵉ objet de liaison (Dépôt × Produit × quantité), pas encore créé.
- Pour supprimer un champ en prod : Configuration > Gestionnaire d'objets > objet > Champs. Retirer aussi
  le fichier correspondant dans `force-app/` pour garder le dépôt aligné.

## Prochaines étapes

- [ ] L'utilisateur fait le tri des champs.
- [ ] Décider de l'objet « Stock par dépôt » (quantité disponible, réservée, seuil).
- [x] Sauvegarder sur GitHub (commit + push).

## Complément

- Objet renommé « Catalogue articles » (enregistrement = « Article ») : Salesforce a déjà un onglet
  standard « Catalogue de produits » (SalesforceProductCatalog), d'où deux onglets du même nom.
  Nom technique inchangé : `Produit_Catalogue__c`. Déployé en prod avec l'accord de l'utilisateur.
