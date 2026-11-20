---
date: 2026-11-20 14:41
auteur: micke
sujet: Remontée des leads depuis Google Sheets sans Zapier — code du pilote (non déployé)
statut: en cours
branche: micke/remontee-leads-sheets
suite_de: journal/2026/11/2026-11-20_12h13_micke_zapier-controle-remontees.md
---

## Objectif

Écrire le code du pilote : Salesforce lit lui-même les feuilles Google des fournisseurs de leads
toutes les 3 minutes, crée les pistes et écrit le résultat de chaque ligne dans une colonne
« Remonté » de la feuille. Les prix (achat / revente) ne font pas partie de ce pilote.

## Ce qui a été fait

- Branche `micke/remontee-leads-sheets`, partie de `micke/commentaire-piste-unique`.
  **Rien n'est déployé**, ni en production ni en org de test.
- Objets neufs : `Fournisseur_Lead__c` (code neutre, interne/externe), `Source_Lead__c` (une par
  feuille : classeur, onglet, régie, campagne, correspondance des colonnes en JSON, suivi),
  `Rejet_Lead__c` (historique des doublons, faux numéros, erreurs).
- Réglage général `Remontee_Lead_Reglage__mdt` (enregistrement « Défaut », livré **inactif**) :
  interrupteur, taille de paquet (20), pause (3 min), nom du certificat, e-mail du robot Google,
  recherche des doublons sur le téléphone brut, nombre de tentatives (5).
- 5 champs ajoutés sur la Piste : `Source_Lead__c`, `Code_Fournisseur__c`, `Ligne_Feuille__c`
  (clé unique : une ligne de feuille ne crée jamais deux pistes), `Faux_Numero__c`,
  `Telephone_Cle__c` (9 derniers chiffres, indexé).
- Classes Apex : `GoogleSheetsClient` (jeton signé par certificat, lecture, écriture),
  `RemonteeLeadFeuille` (analyse d'une feuille), `RemonteeLeadTelephone` (règles téléphone/e-mail),
  `RemonteeLeadSelector`, `RemonteeLeadService` (création des pistes, doublons, rejets),
  `RemonteeLeadQueueable` (la chaîne), `RemonteeLeadGardien` (relance horaire), `RemonteeLeadReglage`.
- Une classe de test par classe (7), plus un faux Google (`RemonteeLeadGoogleMock`) et des données
  de test communes (`RemonteeLeadTestData`).
- Jeu d'autorisations `Remontee_Leads`, 3 onglets, 2 sites distants Google.
- Liste de déploiement : `manifest/remontee-leads.xml`.

### Résultats écrits dans la feuille

| Cas                         | Texte                                                                                |
| --------------------------- | ------------------------------------------------------------------------------------ |
| Piste créée                 | `OK – 20/11/2026 14:02 – <Id de la piste>`                                           |
| Doublon                     | `DOUBLON – déjà reçu le 12/11/2026 par F012` (ou `hors fournisseurs`)                |
| Faux numéro, e-mail valable | `FAUX NUMÉRO – e-mail seul – créé le … – <Id>` (piste créée, cochée « Faux numéro ») |
| Faux numéro, pas d'e-mail   | `FAUX NUMÉRO – <raison> – pas d’e-mail valable, non remonté`                         |
| Refus de Salesforce         | `ERREUR – tentative 2 – <raison>` puis `ERREUR DÉFINITIVE – <raison>`                |

## Fichiers touchés

- `force-app/main/default/classes/RemonteeLead*.cls`, `GoogleSheetsClient*.cls`
- `force-app/main/default/objects/{Fournisseur_Lead__c,Source_Lead__c,Rejet_Lead__c,Remontee_Lead_Reglage__mdt}/`
- `force-app/main/default/objects/Lead/fields/` (5 champs ajoutés)
- `force-app/main/default/customMetadata/Remontee_Lead_Reglage.Defaut.md-meta.xml`
- `force-app/main/default/remoteSiteSettings/`, `tabs/`, `permissionsets/Remontee_Leads.permissionset-meta.xml`
- `manifest/remontee-leads.xml`

## Décisions prises

- Salesforce lit les feuilles (pas un script par feuille) : un seul endroit à surveiller, aucun appel API consommé.
- Aucune clé secrète : la demande de jeton Google est signée par un certificat gardé dans Salesforce.
- Le résultat d'un paquet est écrit dans la feuille au début de l'opération suivante (Salesforce
  interdit un appel sortant après une écriture). Si cette écriture échoue, la ligne est relue et
  reconnue par sa clé, sans nouvelle piste.
- Au plus « taille de paquet » pistes créées par opération (20), pour ménager les 12 flux et le
  déclencheur existants ; au plus 40 feuilles lues par opération (limite de 100 appels sortants).
- Doublons : la recherche existante (`DoublonService`, groupes `Doublon_Groupe__c`, règle
  `TELEPHONE_RES060`) n'est pas modifiée ; la remontée la consulte en lecture, en plus de sa
  propre clé `Telephone_Cle__c` et du numéro brut des anciennes pistes.
- Écritures en mode système (traitement automatique, sans utilisateur à l'écran).

## Problèmes / points d'attention

- **Les tests Apex n'ont jamais été exécutés** : aucune org de test n'est connectée (pcp1 expirée).
  Le code est seulement vérifié par le formateur (syntaxe). Des erreurs de compilation ou de test
  restent possibles au premier déploiement.
- Les tests créent des pistes : ils traversent les 59 règles de validation et les 12 flux de la
  production. Un automatisme existant peut faire échouer un test sans que le pilote soit en cause.
- `Telephone_Cle__c` n'est rempli que sur les pistes créées par la remontée. Pour les 230 000
  pistes existantes, les doublons sont cherchés sur le numéro tel qu'il est enregistré
  (`34XXXXXXXXX`, `0XXXXXXXXX`…) : requête non indexée, tolérée hors déclencheur mais qui
  ralentira avec le volume. À terme : remplir la clé sur l'existant (traitement de reprise, à
  faire avec précaution car chaque piste modifiée déclenche les automatismes), puis décocher
  « Recherche de doublons sur le téléphone brut ».
- La régie de la Source est recopiée dans `Lead.Regie__c`. Des automatismes existants réagissent à
  ce champ (`PISTE_SharePiste`, `FL_Piste`, règle `PIS_10_CREATION_LOOKUP_A_SON_NOM`) : non testé.
  Pour le premier essai, laisser la régie vide sur la Source.
- Non vérifié auprès de Google : la forme exacte acceptée pour la signature (le code construit le
  JWT lui-même et le signe avec `Crypto.signWithCertificate`) et l'écriture dans une colonne
  au-delà de la grille de la feuille. Vérifié sur une vraie feuille : une lecture dont la fin
  dépasse la grille est acceptée, une lecture qui commence après la dernière ligne est refusée.
- La colonne « Remonté » doit exister dans la grille de la feuille (26 colonnes par défaut) et la
  feuille doit être partagée **en modification** avec le compte de service.
- Si des lignes sont supprimées dans une feuille, vider « Première ligne à traiter » sur la Source
  pour forcer une relecture complète.

## Corrections demandées par l'utilisateur le 20/11 (à faire, pas encore codées)

- **La régie est une Campagne « Est REGIE »** (`Campaign.EstREGIE__c`), avec un compte relié par
  `Account.Acces_REGIE__c`. La Source pointe vers une Campagne, plus vers un utilisateur ; la piste remplit
  `Lead.Campagne_REGIE__c` et plus `Lead.Regie__c`.
- Vérifié en production (lecture seule, 20/11) : aucun des 12 flux actifs de la piste, ni `LeadTrigger`,
  `LeadTriggerHandler`, `DoublonService`, ni aucune règle de validation ou de partage de la piste ne cite
  `Campagne_REGIE__c`. La conversion le recopie vers `Opportunity.Campagne_REGIE__c`. **Correction (20/11)** : le Dossier `Pro__c` a bien
  `Campagne_REGIE__c` (« Campagne (REGIE) ») et `CampagneRegie_PRINCIPALE__c` (« Campagne Principale (REGIE
  PRINCIPALE) ») ; une première lecture tronquée avait fait croire le contraire.
  Les 138 comptes dont « Accès REGIE » pointe vers une campagne non cochée « Est REGIE » sont 137 comptes
  `PREVISITEUR- …` et 1 compte `INSTALLATEUR- test`, créés depuis le 15/09/2026 : le champ « Accès REGIE » sert
  aussi à l'accès des prévisiteurs. Les 945 campagnes « Est REGIE » ont chacune exactement un compte.
  Chiffres : 945 campagnes « Est REGIE », 1 083 comptes avec « Accès REGIE », 1 275 pistes et 413 opportunités
  avec « Campagne (REGIE) ».
- **Un seul cas : la régie internalisée** (plus de « interne / externe »). Les 945 régies actuelles ne changent pas.
  Sur la campagne : case « Régie internalisée », nombre d'utilisateurs actifs, montant des leads.
- **Prix** : prix d'achat et prix de revente sur chaque lead ; tarif par couple fournisseur + régie ; tarifs et
  clôture dans des objets à part ; Catalogue tarifaire intouché ; écrans de réglage comme « Visibilité Onglets ».
- **Doublons** : message neutre dans la feuille quand le contact est connu d'une autre régie.
- **Préparer sans construire** : accès par régie (plus tard, par la sandbox), saisie de leads par la régie,
  reporting de la régie. Chaque piste doit garder régie, source, prix de revente et télépro.

## Suite du cadrage (20/11, toujours rien de codé)

- Télépro et régie suivent déjà de la piste à l'opportunité (réglage de conversion : `ConfirmateurLookup__c` →
  `LOOKUP_Telepro__c`, `Campagne_REGIE__c` → `Campagne_REGIE__c`) puis au dossier (constaté sur 486 dossiers
  de 60 jours, aucun cas perdu ; mécanisme opportunité → dossier non lu, l'utilisateur fera lui-même les liens).
- Champs neufs à porter jusqu'au dossier : Source de leads et code fournisseur (texte, lisible par des
  utilisateurs qui n'ont pas accès aux objets de réglage). Prix sur le dossier : en discussion.
- Visibilité actuelle (lu en production) : piste en « public lecture/écriture/transfert » pour les internes,
  **privée pour les externes** ; presque tous les utilisateurs actifs sont des partenaires (portail) ;
  la règle `PORTAIL_TELEPRO` partage toutes les pistes au groupe « PORTAIL INTERNE Télépros » ; le flux
  `PISTE_SharePiste` crée déjà des partages piste par piste. 15 règles de partage à critères sur la piste (max 50).
- Verrou entre régies retenu sur le principe : un groupe par régie internalisée, télépros hors du groupe général,
  partage de chaque piste avec le groupe de sa régie, automatisé. À faire **après** le pilote, par la sandbox.
  La première régie internalisée démarrera après ce chantier ; il n'y en a qu'une pour l'instant ; un traitement
  de reprise partagera ses pistes existantes.
- Décidé : **les prix ne sont pas copiés sur le dossier** (on s'en tient au coût d'acquisition par dossier,
  calculé par la Source). La régie internalisée actuelle (une seule) sera regardée plus tard.
- Édition Enterprise : 500 champs personnalisés par objet ; piste 322, opportunité 389, dossier 406.

## Lecture complète des automatismes de production (20/11, lecture seule : 66 flux, 26 déclencheurs, 486 classes)

- **Campagne** : aucun flux ; un seul déclencheur `CampaignTrigger` (after update) qui ne réagit qu'au passage de
  `StatutContrat__c` à « Signé » pour un rôle du portail. Écrire des compteurs sur une campagne ne déclenche rien.
- **Opportunité → Dossier** : le dossier est créé par le flux `Opportunite_FL_AfterCreateUpdate` (c'est là qu'il
  faudra ajouter Source et code fournisseur). **Campagne Principale** est calculée seule par
  `PRO_FT_BeforeCreateUpdate` : campagne parente de « Campagne (REGIE) », sinon la campagne elle-même.
- **`FL_Piste`** : à la création, propriétaire = file `ATTRIBUTION_RDV_REGIES` (7 membres) quand le créateur est
  administrateur ; `LeadSource = REGIES` et `Regie__c = utilisateur` seulement pour le profil « PORTAIL INTERNE- REGIES ».
- **`Archiver_les_pistes_Regies_Interne_Leades`** (planifié) : les pistes non converties de plus de 5 mois passent
  de LEADS/REGIES/INTERNE à DATA-LEADS/DATA-REGIES/DATA-INTERNE.
- **Visibilité réelle des pistes** (correction) : le groupe de la règle `PORTAIL_TELEPRO` est **vide**. Les télépros
  Espagne voient les pistes par la règle `TELEPRO_ES` (pays = Espagne → groupe « Résidentiel ES Télépros », 20 membres).
  Aucune règle ne donne les opportunités ni les dossiers aux télépros Espagne.
- **Licences** : Partner Community 35, dont 34 utilisées (13 télépros leads, 7 confirmateurs…). Un utilisateur
  partenaire = un compte à lui. Aucune licence Salesforce complète libre (2/2).
- Points à trancher listés à l'utilisateur le 20/11 (licences, visibilité par vos propres télépros, file d'attribution,
  origine LEADS/REGIES, périmètre des doublons, mode pourcentage, lead facturable, facturation).

## Décisions de cadrage du 20/11 (soir), rien de codé

- Rattachement télépro ↔ régie : objet à part « Télépro de régie » (pas de champ sur Utilisateur).
- Licences : l'utilisateur garde un stock de licences Partner Community ; la création d'un télépro prend une
  licence libre, alerte quand le stock est bas. Création d'accès automatisée, validée par l'utilisateur.
- Visibilité : les télépros maison ne doivent plus voir les pistes d'une régie internalisée, **sans rien perdre
  de ce qu'ils voient aujourd'hui** → case « Régie internalisée » sur la piste + condition ajoutée aux règles
  `TELEPRO_ES` et `TELEPRO_LEADS_DATA` (modification de l'existant, par la sandbox).
- File d'attribution : au choix de Claude → une file par régie internalisée, réattribution par le programme
  juste après la création ; `FL_Piste` non modifié (`PISTE_LOOKUP_PROPRIETAIRE` ne change le propriétaire que si
  « LOOKUP- Confirmateur » change).
- Origine des pistes : `LEADS`, réglable par feuille.
- Doublon : une piste existante ne bloque que si elle a eu une activité depuis moins de 2 semaines ; un dossier
  bloque sauf si « RDV- Statut Dossier » (`Pro__c.PAC_STATUT_DOSSIER__c`) = « ⚫DOSSIER- Annulé ».
  Définition de « activité » à confirmer (`REP_DerniereModif__c` ne suit que 4 champs du confirmateur).
- Message : `DOUBLON – contact déjà connu depuis le JJ/MM/AAAA, non remonté`.
- Prix : fixe **ou** pourcentage de campagne, l'un des deux par tarif.
- Facturable : doublon sur la même feuille = non payé au fournisseur ; doublon interne (déjà connu ailleurs) =
  payé au fournisseur, non facturé à la régie ; faux numéro (même remonté grâce à l'e-mail) = non facturé.
- Précisions finales : « activité » d'une piste = le plus récent entre création, dernier appel ou tâche, dernière
  modification ; confirmateurs et secrétaires continuent de voir les pistes des régies internalisées (seuls les
  télépros maison sont fermés) ; faux numéro jamais facturé à la régie, **payé ou non au fournisseur selon le
  fournisseur** (réglage sur le tarif) ; doublon interne payé au fournisseur et non remonté, perte assumée.
- Pas de facture pour l'instant, seulement le relevé. Accès actuels aux opportunités et dossiers : inchangés.

## Prochaines étapes

- [ ] Créer dans Salesforce un certificat auto-signé nommé `Google_Sheets_Leads`
      (Configuration > Gestion des certificats et des clés), télécharger sa partie publique.
- [ ] Importer cette partie publique dans le compte de service Google
      `salesforce-leads-robot@salesforce-leads-515313.iam.gserviceaccount.com` (Clés > Importer une clé existante).
- [ ] Comparer la production et le dépôt, puis déployer **uniquement** `manifest/remontee-leads.xml`
      avec `RunSpecifiedTests` (GoogleSheetsClientTest, RemonteeLeadFeuilleTest, RemonteeLeadGardienTest,
      RemonteeLeadQueueableTest, RemonteeLeadReglageTest, RemonteeLeadSelectorTest,
      RemonteeLeadServiceTest, RemonteeLeadTelephoneTest) — **après accord explicite de l'utilisateur**.
- [ ] Attribuer le jeu d'autorisations « Remontée des leads » à l'administrateur.
- [ ] Créer un Fournisseur (code `TEST`) et une Source de test pointant sur la feuille de test,
      campagne de test, régie vide, « Actif » coché.
- [ ] Passer le réglage « Défaut » sur Actif, puis lancer une fois `RemonteeLeadGardien.planifier();`
      (Exécuter du code anonyme).
- [ ] Vérifier la ligne de test : piste créée, colonne « Remonté » remplie ; supprimer la piste de test.
- [ ] Étape suivante du projet : tarifs d'achat / revente et prix figés sur la piste.
