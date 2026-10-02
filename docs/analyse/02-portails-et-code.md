# Portails Experience Cloud et code Apex — état des lieux

> BMAD — étape 1 (analyste). Mesuré le 2026-10-02 en production, en lecture seule.
> Métadonnées des sites rangées dans `legacy-app/main/default/` (experiences, digitalExperiences, networks, sites, navigationMenus, audience).

## Objectif cible (Micke)

**Deux accès Salesforce complets (administrateurs) ; tous les autres utilisateurs passent par les sites Experience.**
C'est déjà presque le cas : 38 utilisateurs Partner Community pour 2 administrateurs.

## 1. Les sites

| Site | Type | Public | Rôle |
|---|---|---|---|
| **business saas** | Aura (Customer/Partner) | Membres connectés, 20 profils | **Portail principal** de tous les métiers |
| **Gestion Previsites** | LWR | Invité (lien à jeton) | Pré-visiteurs / sous-traitants sans compte |
| **Campagnes** | LWR | Invité | Formulaires / campagnes des régies |
| yousign, Test | Site Force.com | Invité | Retour de signature Yousign ; test |

Auto-inscription désactivée partout (bien).

## 2. Le portail principal « business saas »

- 58 pages, 52 adresses, **41 variantes de pages** et **26 audiences** : une page d'accueil et des menus différents par profil.
- **14 menus**, un par métier :

| Métier | Menu |
|---|---|
| Télépro | Dossiers en cours |
| Responsable télépro | Pistes, Dossiers, Campagnes |
| Confirmateur | Pistes, Dossiers, Reporting dossiers, Standard, Campagnes (régies), Facturation |
| Confirmateur ES | Pistes, Dossiers, Campagnes |
| Secrétaire / Secrétariat / Secrétariat PRO | Opportunités, Dossiers (en cours), Standard (en attente) |
| Closer | Dossier, SAV, Stock, Planning, PRO |
| Closer LEDS | Pro, Planning |
| Apporteur d'affaires | Gestion régies, Cahier des charges, Facturation |
| Comptabilité | Comptes, Dossiers, Facturation, Opportunités, Stock |
| Sous-traitant | Installation, SAV, Facturation |
| Régie | (vide) |

- Pages clés et composants : fiche piste/dossier (`rdvFicheParent`, `proCeeFicheParent`), reporting (`lwc020_reporting_v2`),
  planning (`lwc004_planification_all`), facturation (`lwc020_Facturation`, `lwc025FactureApercu`, `lwc022PaiementFacturesMasse`),
  régies (`lwc020_GestionCampagnes`), cahier des charges (`lwc020_CahierCharges`).
- Accueils par marché (PAC, LEDS, DESTRAT, Réno globale, Serre agricole) protégés par un composant maison `securityCheck`.

### Problèmes

- **La sécurité repose sur l'affichage** (audiences, `securityCheck`, profils codés en dur dans le JavaScript), pas sur les droits d'accès aux données.
  Combiné aux classes `without sharing`, un utilisateur du portail peut potentiellement lire des données qui ne le concernent pas en appelant directement les méthodes Apex.
- 20 profils pour ~12 métiers, avec doublons (Secrétaire, Secrétaire 174, Secrétaire PAC, Secrétaire LEDS/DESTRAT…).
- Menus et pages dupliqués par variante de métier.

## 3. Le code Apex

| Mesure | Valeur |
|---|---|
| Classes | 149 (88 métier, 61 de test) |
| Lignes de code métier | ~37 900 |
| Classes métier `without sharing` | **51** / 88 (27 `with sharing`, 10 sans mention) |
| Services REST publics | 6 : CampagneController, LC021_DevisContratRest, LC027_CertikoRetour, OdooController, PrevisiteController, YS_WebhookRest |
| Triggers | 10 (8 avec handler ; `LeadTrigger` et `YS_WebhookTrigger` sans) |
| Couverture de tests | non mesurée récemment dans l'org (à relancer en sandbox) |

Classes « monstres » (une seule classe fait tout : requêtes, règles, écran) :
`Planification_Controller` (4 100 lignes, 55 méthodes exposées), `TaskTriggerHandler` (3 000), `LC020_GestionCampagnes` (2 100),
`CustomFileUploadController` (2 050), `LC023FacturationCompteController` (1 800), `LC021_DevisSignature` (1 500), `FieldSetController` (1 500).

## 4. Conséquences pour la nouvelle architecture

1. **Un seul portail partenaires**, des pages communes, et l'affichage adapté par **permission sets** plutôt que par 26 audiences.
2. **Sécurité par les données** : rôles de portail, groupes de partage et règles de partage ; Apex `with sharing` + `WITH USER_MODE`.
   Un télépro ne peut techniquement pas lire un dossier qui n'est pas le sien, quel que soit l'écran.
3. **Profils réduits** : 1 profil de portail de base + des permission sets par métier (Télépro, Confirmateur, Secrétariat, Closer, Apporteur, Régie, Comptabilité, Sous-traitant).
4. **Sites invités** (pré-visite, campagnes, Yousign) : accès par jeton signé et à durée limitée, aucune donnée exposée au-delà du dossier concerné.
5. **Apex en couches** (Service / Selector / Domain), petites classes testées, intégrations (Yousign, Aircall, Certiko, Odoo, Ionos) isolées derrière des Named Credentials.
