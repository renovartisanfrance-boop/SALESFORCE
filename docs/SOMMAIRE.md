# Sommaire des documents — Renov Artisan France

Tous les documents du projet, rangés par thème. Cliquer sur un nom pour l'ouvrir.
Les fichiers `.html` s'ouvrent dans un navigateur ; les `.pdf` sont les versions à imprimer ou à envoyer.

_Mis à jour le 13/11/2026._

---

## 1. Analyse de l'existant

| Document                                                                   | De quoi il parle                                              |
| -------------------------------------------------------------------------- | ------------------------------------------------------------- |
| [État des lieux de la production](analyse/01-etat-des-lieux-production.md) | Ce qui existe aujourd'hui dans l'org Salesforce de production |
| [Portails et code Apex](analyse/02-portails-et-code.md)                    | Les portails Experience Cloud et l'ancien code                |
| [Entretien métier](analyse/03-entretien-metier.md)                         | Le fonctionnement de l'entreprise expliqué par Micke          |
| [Poste confirmateur — décisions](analyse/04-poste-confirmateur.md)         | Les choix validés sur la maquette du confirmateur             |

## 2. Conception

| Document                                               | De quoi il parle                                           |
| ------------------------------------------------------ | ---------------------------------------------------------- |
| [Simulateur RES060FC](conception/simulateur-res060.md) | Fiche de conception du simulateur de marge dans Salesforce |

## 3. Calculateurs

| Document                                                                                      | De quoi il parle                                                                     |
| --------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| [Éligibilité PAC télépro (RES060_FM)](calculateurs/eligibilite-pac-telepro-res060fm.html)     | Le calculateur utilisé par les télépros                                              |
| [Paramètres de Micke (après calculateur)](calculateurs/parametres-micke-apres-calculateur.md) | Coûts du pack (6 600 / 7 500 / 13 000 €) — usage personnel, hors calculateur télépro |

## 4. Maquettes (écrans)

| Document                                                                                              | De quoi il parle                                                                                                                                                                                                                                                               |
| ----------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| [Maquette poste confirmateur](maquettes/maquette-confirmateur.html)                                   | La maquette complète du poste confirmateur (tous les onglets)                                                                                                                                                                                                                  |
| [Audit visuel de la maquette (13/11)](maquettes/2026-11-13-maquette-confirmateur-craft-audit-WARN.md) | Points à améliorer relevés sur la maquette                                                                                                                                                                                                                                     |
| [Pistes — maquette portail](maquettes/pistes.html)                                                    | Écran des pistes                                                                                                                                                                                                                                                               |
| [Portail installateur ECONATURA](maquettes/econatura/portail-installateur.html)                       | Version nettoyée du portail installateur                                                                                                                                                                                                                                       |
| [Portail installateur — original v71](maquettes/econatura/portail-installateur-v71-original.html)     | Version d'origine, gardée pour comparaison                                                                                                                                                                                                                                     |
| Avant / après (images)                                                                                | [Liste attribution avant](maquettes/avant-apres/1-liste-attribution-AVANT.jpg) · [après](maquettes/avant-apres/2-liste-attribution-APRES.jpg) · [Fiche client avant](maquettes/avant-apres/3-fiche-client-AVANT.jpg) · [après](maquettes/avant-apres/4-fiche-client-APRES.jpg) |

## 5. Guides pour l'intégrateur Salesforce

> Ces guides ne sont plus mis à jour depuis le 09/11/2026 (la maquette et le code font foi).

| Document                                                                                                                   | De quoi il parle                                          |
| -------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------- |
| [Poste confirmateur — guide intégrateur](integration/poste-confirmateur.html) ([texte](integration/poste-confirmateur.md)) | Ce que l'intégrateur doit construire pour le confirmateur |
| [Vues de travail — architecture](integration/vues-de-travail.html) ([texte](integration/vues-de-travail.md))               | L'organisation des listes de vue                          |

## 6. Règles de validation

| Document                                                                                    | De quoi il parle                                                |
| ------------------------------------------------------------------------------------------- | --------------------------------------------------------------- |
| [Explications et messages proposés](regles-validation/explications-proposees.md)            | Les règles Pistes et Dossiers, expliquées simplement            |
| [Toutes les règles (actives et inactives)](regles-validation/explications-toutes-regles.md) | Liste complète avec nouveau nom, explication et message proposé |

## 7. Contrats Espagne (RES060_FM)

Dossier : `docs/contrats/espagne/`. Ce sommaire est tenu à jour par la conversation « Docs complet » : chaque conversation « Docs- … » du groupe ESPAGNE lui signale ses nouvelles versions. Seule la dernière version de chaque document est listée.

Chaque document existe en espagnol (version officielle, celle qu'on fait signer) et en traduction française (de courtoisie, sans valeur contractuelle).

| Document                                                                                                                                                                   | Espagnol                                                                                                                                                                         | Français                                                                                                                                                                                                 |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Contrat de sous-traitance installateur (v1.7, 12/11/2026) : contrat unique, il n'y a pas de contrat prévisiteur séparé                                                     | [HTML](contrats/espagne/installateur/Contrato_Subcontratacion_Instalador_ES.html) · [PDF](contrats/espagne/installateur/Contrato_Subcontratacion_Instalador_ES_v1.7.pdf)         | [HTML](contrats/espagne/installateur/Contrat_Sous-traitance_Installateur_FR_traduction.html) · [PDF](contrats/espagne/installateur/Contrat_Sous-traitance_Installateur_FR_v1.7_traduction.pdf)           |
| Offre de maintenance (v2.1) : le client accepte ou refuse la maintenance proposée par l'installateur (350 € TTC par an maximum) ; remplace l'ancien contrat de maintenance | [HTML](contrats/espagne/mantenimiento/Oferta_Mantenimiento_ES.html) · [PDF](contrats/espagne/mantenimiento/Oferta_Mantenimiento_ES_v2.1.pdf)                                     | [HTML](contrats/espagne/mantenimiento/Offre_Maintenance_FR_traduction.html) · [PDF](contrats/espagne/mantenimiento/Offre_Maintenance_FR_v2.1_traduction.pdf)                                             |
| Avertissement zones D et E, logement F ou G (v1.0) — obligatoire, fiche RES060_FM ap. 3 point 13 ; à faire signer au client avant les travaux                              | [HTML](contrats/espagne/advertencia-zonas-DE/Advertencia_Zonas_DE_RES060FM_ES.html) · [PDF](contrats/espagne/advertencia-zonas-DE/Advertencia_Zonas_DE_RES060FM_ES_v1.0.pdf)     | [HTML](contrats/espagne/advertencia-zonas-DE/Avertissement_Zones_DE_RES060FM_FR_traduction.html) · [PDF](contrats/espagne/advertencia-zonas-DE/Avertissement_Zones_DE_RES060FM_FR_v1.0_traduction.pdf)   |
| Résumé des économies et consentement (v1.0)                                                                                                                                | [HTML](contrats/espagne/consentimiento-ahorro/Consentimiento_Ahorro_RES060FM_ES.html) · [PDF](contrats/espagne/consentimiento-ahorro/Consentimiento_Ahorro_RES060FM_ES_v1.0.pdf) | [HTML](contrats/espagne/consentimiento-ahorro/Consentement_Economies_RES060FM_FR_traduction.html) · [PDF](contrats/espagne/consentimiento-ahorro/Consentement_Economies_RES060FM_FR_v1.0_traduction.pdf) |
| Consentement — version bilingue espagnol + français (v1.0), référence pour l'équipe ; c'est la version espagnole seule qu'on fait signer et qu'on verse au dossier CAE     | [HTML](contrats/espagne/consentimiento-ahorro/Consentimiento_RES060FM_ES+FR.html) · [PDF](contrats/espagne/consentimiento-ahorro/Consentimiento_RES060FM_ES+FR_v1.0.pdf)         | (même document)                                                                                                                                                                                          |
| Annexe A — aides publiques (v1.0)                                                                                                                                          | [HTML](contrats/espagne/anexo-A-ayudas/Anexo_A_Ayudas_Publicas_RES060FM_ES.html) · [PDF](contrats/espagne/anexo-A-ayudas/Anexo_A_Ayudas_Publicas_RES060FM_ES_v1.0.pdf)           | [HTML](contrats/espagne/anexo-A-ayudas/Annexe_A_Aides_Publiques_RES060FM_FR_traduction.html) · [PDF](contrats/espagne/anexo-A-ayudas/Annexe_A_Aides_Publiques_RES060FM_FR_v1.0_traduction.pdf)           |

## 8. Marketing

| Document                                                                | De quoi il parle                                                                                                                                                                                                                                                            |
| ----------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [Visuel bono social](../marketing/pub-meta-bono-social/visuel-duo.html) | Modèle de la pub Meta « bono social »                                                                                                                                                                                                                                       |
| Images de la pub                                                        | [Carré 1080×1080](../marketing/pub-meta-bono-social/pub-bono-social-carre-1080x1080.png) · [Fil 1080×1350](../marketing/pub-meta-bono-social/pub-bono-social-feed-1080x1350.png) · [Story 1080×1920](../marketing/pub-meta-bono-social/pub-bono-social-story-1080x1920.png) |
| Factures d'exemple (anonymisées)                                        | [Facture 42 €](../marketing/pub-meta-bono-social/facture-bono-42-anonyme.png) · [Facture 57 €](../marketing/pub-meta-bono-social/facture-bono-57-anonyme.png)                                                                                                               |

## 9. Exports (archives à envoyer)

| Document                                                                             | De quoi il parle                            |
| ------------------------------------------------------------------------------------ | ------------------------------------------- |
| [Maquette confirmateur — 13/11/2026](../export/maquette-confirmateur_2026-11-13.zip) | Dernière version de la maquette, en archive |
| [Maquette confirmateur — 12/11/2026](../export/maquette-confirmateur_2026-11-12.zip) | Version précédente                          |

## Autres repères

- [Journal de bord](../journal/) — ce qui a été fait à chaque session
- [Règles de travail à deux](../CONTRIBUTING.md)
- [Présentation du projet](../README.md)
