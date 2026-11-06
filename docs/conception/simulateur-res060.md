# Simulateur RES060FC dans Salesforce — fiche de conception

Date : 2026-11-06 · Auteur : micke · Source : `Simulateur_Prime_RES060FC (3).html` (dernière version)

## Besoin

Reproduire dans Salesforce le simulateur de marge « RES060FC » (pompe à chaleur, maison individuelle) :
on saisit les infos du logement, Salesforce calcule tout seul la prime, le bénéfice, l'indice et la zone.

Étape 1 (cette fiche) : un **objet isolé** « Simulation RES060 », relié à rien.
Étape 2 (plus tard) : le « connecteur » qui remplit une simulation à partir d'une Piste et renvoie l'indice
dans une case de la Piste.

## Ce que l'utilisateur saisit

| Champ                            | Remarque                                                                       |
| -------------------------------- | ------------------------------------------------------------------------------ |
| Province                         | liste des 50 provinces du simulateur                                           |
| Code postal                      | facultatif ; si la province est vide, elle est déduite des 2 premiers chiffres |
| Surface habitable (m²)           | obligatoire pour calculer                                                      |
| Année de la maison               | vide = ≤1940 (comme le simulateur)                                             |
| Type de chaudière                | Gaz, Gasóleo (fioul), Charbon, Électrique, Bois / pellets (non éligible)       |
| Année de la chaudière            | vide = 2000 (comme le simulateur)                                              |
| Condensation                     | case à cocher                                                                  |
| Bono social severo               | case à cocher (× 1,5)                                                          |
| **Prix de valorisation (€/MWh)** | le prix auquel l'énergie économisée est payée ; vide = 155 (valeur par défaut) |

## Ce que Salesforce calcule (cases en lecture seule)

D_CAL, rendement η, AES (MWh/an), prime, coût du pack, bénéfice, indice, zone, statut.

## Formule (identique au simulateur version 3)

- AES (kWh/an) = D_CAL[province][tranche d'année de la maison] × S × (1/η − 1/SCOP)
- Prime (€) = AES × fC × (1,5 si bono) × prix (€/MWh) ÷ 1000
- Coût pack = 6 600 € (S ≤ 220 m²) ou 12 500 € (cascade 2 PAC, S > 220 m²)
- Bénéfice = Prime − coût pack ; Indice = bénéfice ÷ 1000 (1 décimale)
- Zone verte (prioritaire) si bénéfice ≥ 3 500 €, sinon zone rouge (à traiter en janvier)
- Rendement η : gaz < 1979 → 0,55 ; ≤ 1997 → 0,65 ; après → 0,73 ; condensation 0,83 (< 1998) / 0,85.
  Fioul < 1985 → 0,65 ; ≤ 1997 → 0,70 ; après → 0,79 ; condensation 0,83. Charbon 0,55. Électrique 1,00.
  Bois : non éligible.
- Las Palmas et Santa Cruz de Tenerife : pas de D_CAL publié → « Donnée manquante ».

## Réglages modifiables sans code (Custom Metadata)

- `RES060_Parametre__mdt` (enregistrement `Defaut`) : SCOP 4, fC 2, prix par défaut 155 €/MWh,
  coûts du pack 6 600 / 12 500 €, seuil cascade 220 m², seuil zone verte 3 500 €, bono × 1,5.
- `RES060_DCAL_Province__mdt` : une ligne par province (préfixe du code postal + 7 valeurs D_CAL).

## Architecture

`SimulationRES060Trigger` (avant insertion / modification, sans logique)
→ `SimulationRES060TriggerHandler` → `SimulationRES060Service` (le calcul)
→ `SimulationRES060Selector` (lecture des réglages). Aucune requête dans une boucle.

Accès : jeu d'autorisations « Simulateur RES060 » (objet, champs, onglet).

## Isolement

Seuls des éléments **nouveaux** sont créés. Aucun objet, champ, flow ou trigger existant n'est modifié.
Le déploiement en production ne lance que les tests de ce simulateur.
