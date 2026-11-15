# Règles de validation (actives et inactives) — nouveau nom, explication et message proposés

Source : production, le 11/11/2026. **Appliqué en production le 11/11/2026** (noms, descriptions et messages ; 8 formules corrigées, voir fin du document). Les colonnes « Aujourd'hui » gardent l'ancienne version pour l'historique.

- Trois choses changeraient par règle : le **nom**, la **description** et le **message d'erreur**.
- Les formules, l'état actif / inactif et l'emplacement du message ne changent pas.
- Messages : une phrase qui dit ce qui bloque, puis « Merci de … » pour dire quoi faire.
- Les règles inactives sont incluses (marquées « inactive ») ; elles restent inactives.

## Format des noms

`OBJET_ÉTAPE_THÈME_SUJET`, en majuscules, 40 caractères maximum (limite Salesforce).

- **OBJET** : `PIS` pour les Pistes, `DOS` pour les Dossiers.
- **ÉTAPE** : un numéro qui suit le parcours. Salesforce classe les règles par ordre alphabétique, donc elles s'afficheront dans l'ordre du parcours.
- **THÈME** puis **SUJET** : ce que la règle contrôle, avec les codes de fiche (TH171, RES060…) tels qu'affichés à l'écran.

| Étape Pistes | Thème               |
| ------------ | ------------------- |
| PIS_10       | Création et accès   |
| PIS_20       | Télépro             |
| PIS_30       | Confirmateur        |
| PIS_40       | Prévisite           |
| PIS_50       | Conversion          |
| PIS_90       | Contrôles de saisie |

| Étape Dossiers | Thème                       |
| -------------- | --------------------------- |
| DOS_10         | Documents                   |
| DOS_20         | Prévisite et visite Certiko |
| DOS_30         | Audit et COFRAC             |
| DOS_40         | Devis                       |
| DOS_50         | MPR et reste à charge       |
| DOS_60         | Installation                |
| DOS_70         | Statut du dossier           |
| DOS_75         | CEE                         |
| DOS_80         | LEDS                        |
| DOS_90         | Contrôles de saisie         |

## Correspondance ancien nom → nouveau nom

### Pistes — 72 règles (59 actives, 13 inactives)

| Nouveau nom                             | Ancien nom                               | État     |
| --------------------------------------- | ---------------------------------------- | -------- |
| PIS_10_ACCES_PORTAIL_REGIES_BLOQUE      | Block_AutreQueProLeds2                   | active   |
| PIS_10_ACCES_REGIES_LEDS_UNIQUEMENT     | Block_AutreQueProLeds                    | active   |
| PIS_10_ACCES_REGIES_SANS_VELO_CARGO     | PORTAIL_REGIE                            | active   |
| PIS_10_CREATION_LOOKUP_A_SON_NOM        | Creation_piste_lookuo                    | active   |
| PIS_10_CREATION_TYPE_DOSSIER_COHERENT   | VR_Lead_TypeDeDossier_CoherenceRecordTyp | active   |
| PIS_20_TELEPRO_A_RETRAITER_LOOKUP       | LEAD_CHANGEMENT_STATUT                   | active   |
| PIS_20_TELEPRO_ENVOI_CONF_CHAMPS_BD     | BASE_ITE_ENVOYE_EN_CONF2                 | active   |
| PIS_20_TELEPRO_ENVOI_CONF_CONFIRM_BD    | BASE_ITE_ENVOYE_EN_CONF3                 | active   |
| PIS_20_TELEPRO_ENVOI_CONF_CONFIRM_LEADS | LEAD_ENVOI_CONF                          | active   |
| PIS_20_TELEPRO_ENVOI_CONF_LOOKUP_BD     | BASE_ITE_ENVOYE_EN_CONF                  | active   |
| PIS_20_TELEPRO_ENVOI_CONF_LOOKUP_LEADS  | LEAD_CHANGEMENT_STATUT3                  | active   |
| PIS_20_TELEPRO_HORS_CIBLE_LOOKUP        | LEAD_CHANGEMENT_STATUT2                  | active   |
| PIS_20_TELEPRO_QUESTIONS_CHAUFFAGE      | Si_interesser_panneau_pac_ou_ite         | inactive |
| PIS_20_TELEPRO_QUESTIONS_ITE            | Si_ite_oui_alors_remplir_les_champs      | active   |
| PIS_20_TELEPRO_QUESTIONS_PAC            | Si_interesser_par_pompe_a_chaleur        | inactive |
| PIS_20_TELEPRO_QUESTIONS_SOLAIRE        | Si_interesser_par_panneaux_solaires      | active   |
| PIS_20_TELEPRO_RAPPEL_CHAMPS_BD         | BASE_ITE_DATA                            | active   |
| PIS_20_TELEPRO_RAPPEL_CHAMPS_LEADS      | Champs_DATE_DE_RAPPEL                    | active   |
| PIS_20_TELEPRO_RAPPEL_LOOKUP            | BASE_ITE_RAPPEL                          | active   |
| PIS_20_TELEPRO_RAPPEL_SIGNATURE         | Champs_DATE_DE_RAPPEL2                   | active   |
| PIS_30_CONFIRM_DEVIS_GENERE_DATE        | CONF_DATE_GENERATION                     | active   |
| PIS_30_CONFIRM_DEVIS_SIGNE_VERROU       | BLOCAGE_Champs_Apres_SIgnature           | active   |
| PIS_30_CONFIRM_HORS_CIBLE_COMMENTAIRE   | CONFIRM_TRAITEMENT3                      | active   |
| PIS_30_CONFIRM_LOOKUPS_VERROUILLES      | LOOKUPS_DEJA_ATTRIBUES                   | active   |
| PIS_30_CONFIRM_RAPPEL_CHAMPS            | Champs_DATE_DE_RAPPEL3                   | active   |
| PIS_30_CONFIRM_RES060_SIGNATURE_CHAMPS  | LEAD_ENVOI_CONF2                         | active   |
| PIS_30_CONFIRM_RETOUR_EN_ATTENTE        | CONFIRM_TRAITEMENT2                      | active   |
| PIS_30_CONFIRM_TH179_SURFACES           | CALCUL_SHAB_163_179                      | active   |
| PIS_30_CONFIRM_VALEURS_RESERVEES        | CONFIRM_TRAITEMENT                       | active   |
| PIS_40_PREVISITE_AGRI_FICHE             | Previsite_Agri1                          | active   |
| PIS_40_PREVISITE_AGRI_STATUT            | Previsite_2_agri                         | active   |
| PIS_40_PREVISITE_PRISE_EN_CHARGE        | Previsite_Residentiel3                   | active   |
| PIS_40_PREVISITE_RESIDENTIEL_FICHE      | Previsite_Residentiel1                   | active   |
| PIS_40_PREVISITE_RESIDENTIEL_STATUT     | Previsite_1residentiel                   | active   |
| PIS_40_PREVISITE_TERTIAIRE_FICHE        | Previsite_Tertiaire1                     | active   |
| PIS_40_PREVISITE_TERTIAIRE_STATUT       | Previsite_2_tertiaire                    | active   |
| PIS_40_PREVISITE_TH171_TH174_DEMANDE    | Previsite_Residentiel2                   | inactive |
| PIS_50_CONVERSION_AGRI_FICHES           | Conversion_VerificationAGRI              | inactive |
| PIS_50_CONVERSION_ANCIEN_LEDS_REGIE     | Convertir_4                              | inactive |
| PIS_50_CONVERSION_ANCIEN_TH142_TH171    | Convertir_2                              | inactive |
| PIS_50_CONVERSION_ANCIEN_TH179          | Convertir_3                              | inactive |
| PIS_50_CONVERSION_ANCIEN_TYPE_V3        | Convertir_1                              | inactive |
| PIS_50_CONVERSION_CHAMPS_EQ108          | Conversion_REMPLISSAGE_TUBESEQ108        | active   |
| PIS_50_CONVERSION_CHAMPS_EQ110          | Conversion_REMPLISSAGE_DPAROEQ112        | active   |
| PIS_50_CONVERSION_CHAMPS_EQ127          | Conversion_REMPLISSAGE_LEDSEQ127         | active   |
| PIS_50_CONVERSION_CHAMPS_RES060         | Conversion_REMPLISSAGE_PAC060            | active   |
| PIS_50_CONVERSION_CHAMPS_RES168         | Conversion_REMPLISSAGE_168               | active   |
| PIS_50_CONVERSION_CHAMPS_TH108          | Conversion_REMPLISSAGE_DESHUTH117        | active   |
| PIS_50_CONVERSION_CHAMPS_TH119          | Conversion_REMPLISSAGE_VMCTH119          | active   |
| PIS_50_CONVERSION_CHAMPS_TH142          | Conversion_REMPLISSAGE_DESTRATTH142      | active   |
| PIS_50_CONVERSION_CHAMPS_TH163          | Conversion_REMPLISSAGE_PACTH163          | active   |
| PIS_50_CONVERSION_CHAMPS_TH171          | Conversion_REMPLISSAGE_PAC171            | active   |
| PIS_50_CONVERSION_CHAMPS_TH174          | Conversion_REMPLISSAGE_RENO_174          | active   |
| PIS_50_CONVERSION_CHAMPS_TH179          | Conversion_REMPLISSAGE_RENO_179          | active   |
| PIS_50_CONVERSION_CODE_POSTAL           | Code_Postal_Obligatoire_Pour_conversion  | active   |
| PIS_50_CONVERSION_NOM_CAMPAGNE          | REMPLIR_NOM_CAMPAGNE                     | inactive |
| PIS_50_CONVERSION_PAS_DE_MELANGE        | Conversion_VerificationMELANGE           | active   |
| PIS_50_CONVERSION_PAS_TELEPRO           | TELEPRO_NE_PEUVENT_PAS_CONVERTIR         | active   |
| PIS_50_CONVERSION_PROPRIETAIRE          | Owner_diffrent_de_logged_in_user         | active   |
| PIS_50_CONVERSION_PROPRIETAIRE_V3       | Convertir_au_nom_du_proprietaire         | active   |
| PIS_50_CONVERSION_RESIDENTIEL_FICHES    | Conversion_VerificationRESIDENTIEL       | inactive |
| PIS_50_CONVERSION_STATUT_RESERVE        | SECURITE_PROFIL                          | active   |
| PIS_50_CONVERSION_TERTIAIRE_UN_SEUL     | Conversion_VerificationTERTIAIRE         | active   |
| PIS_50_CONVERSION_TYPE_DOSSIER_V3       | Type_de_dossier_rempli_pour_convertir    | inactive |
| PIS_50_CONVERSION_UN_PRODUIT_MINI       | Conversion_REMPLISSAGE_unproduitminimum  | active   |
| PIS_90_CONTROLE_ANNEE_CHAUDIERE         | format_annee                             | active   |
| PIS_90_CONTROLE_ANNEE_MAISON            | format_annee2                            | active   |
| PIS_90_CONTROLE_ANTI_VIDE_BD            | BASEDONNEES_SOUS_STATUT_NULL             | active   |
| PIS_90_CONTROLE_ANTI_VIDE_LEADS         | LEAD_SOUS_STATUT_NULL                    | inactive |
| PIS_90_CONTROLE_ANTI_VIDE_LISTES        | TYPE_DE_DOSSIESTATUT_NULL                | active   |
| PIS_90_CONTROLE_ANTI_VIDE_REGIE         | REGIE_SOUS_STATUT_NULL                   | active   |
| PIS_90_CONTROLE_MONTANT_RAC             | MPR_RAC                                  | inactive |

### Dossiers — 73 règles (66 actives, 7 inactives)

| Nouveau nom                            | Ancien nom                             | État     |
| -------------------------------------- | -------------------------------------- | -------- |
| DOS_10_DOCS_CEE_COMPLET                | SECRETARIAT_DOC_COMPLET                | active   |
| DOS_10_DOCS_ES_COMPLET                 | docs_es_docs_complet                   | active   |
| DOS_10_DOCS_ES_INCOMPLET               | docs_es_docs_incomplet                 | active   |
| DOS_10_DOCS_ES_VALIDATION              | Docs_ESvalidation                      | active   |
| DOS_10_DOCS_MPR_COMPLET                | PAC_Docs1                              | active   |
| DOS_10_DOCS_RELANCE_UNE_PAR_FAMILLE    | Relance                                | active   |
| DOS_20_CERTIKO_STATUT_VT_DOCS          | Certiko_VT_Controle                    | active   |
| DOS_20_CERTIKO_STATUT_VT_RESERVE       | CERTIKO_STATUT_VT_RESERVE              | active   |
| DOS_20_CERTIKO_VT_VALIDEE_DOCS         | certikovisite_termine                  | active   |
| DOS_20_PREVISITE_A_REPLANIFIER         | PREVISITE5_OUI                         | active   |
| DOS_20_PREVISITE_ANNULE_PLANIFIE       | PREVISITE7_OUI                         | inactive |
| DOS_20_PREVISITE_DEMANDE               | PREVISITE3_OUI                         | active   |
| DOS_20_PREVISITE_EFFECTUE              | PREVISITE6_OUI                         | active   |
| DOS_20_PREVISITE_NON                   | PREVISITE1_NON                         | active   |
| DOS_20_PREVISITE_NOUVEAU_DOSSIER       | PREVISITE2_OUI                         | active   |
| DOS_20_PREVISITE_PLANIFIE              | PREVISITE4_OUI                         | active   |
| DOS_20_PREVISITE_PORTE_SANS_RETOUR     | PREVISITE_PORTE_PAS_DE_RETOUR          | active   |
| DOS_20_PREVISITE_PREVISITEUR_VERROU    | PREVISITEUR_VISITE_DEMARREE            | active   |
| DOS_20_PREVISITE_RETOUR_DOCS_VERROU    | DOCS_PREVISITE                         | inactive |
| DOS_20_PREVISITE_TH174_OBLIGATOIRE     | AUDIT_2                                | inactive |
| DOS_20_PREVISITE_TYPE_VT               | PREVISITE10                            | active   |
| DOS_30_AUDIT_APRES_PREVISITE           | AUDIT_1                                | active   |
| DOS_30_AUDIT_DEMANDE                   | AUDIT_OUI1                             | active   |
| DOS_30_AUDIT_MODIFS_DEMANDEES          | AUDIT_OUI2                             | active   |
| DOS_30_AUDIT_MPR_DEPOSEE               | PREVISITE9                             | active   |
| DOS_30_AUDIT_NON                       | AUDIT_NON                              | active   |
| DOS_30_AUDIT_VALIDE                    | AUDIT_OUI3                             | active   |
| DOS_30_COFRAC_ENVOI                    | AUDIT_OUI6                             | inactive |
| DOS_30_COFRAC_PLANIFIE                 | COFRAC174_1                            | active   |
| DOS_40_DEVIS_AGRI_DELEGATAIRE          | DEVIS_108_117_119                      | active   |
| DOS_40_DEVIS_FINAL_MONTANT_DELEGATAIRE | PAC_ATT_SIGNATURE_OU_SIGNE             | inactive |
| DOS_40_DEVIS_MONTANT_TTC_KIT           | PAC_Installation12                     | active   |
| DOS_40_DEVIS_TH163_TH179_DELEGATAIRE   | DEVIS_179_163                          | active   |
| DOS_40_DEVIS_TH171_TH174_DELEGATAIRE   | DEVIS_171_174                          | active   |
| DOS_40_DEVIS_TH174_APRES_TH171         | Si171_ouvert174en_attetne              | active   |
| DOS_40_DEVIS_TH174_CHAMPS              | DEVIS_174                              | active   |
| DOS_50_MPR_ANOMALIE_COMMENTAIRE        | PAC_Statut_Dossier_3                   | active   |
| DOS_50_MPR_DATE_MODIF                  | PAC_Installation6                      | active   |
| DOS_50_MPR_FULL_CEE                    | PAC_Installation14                     | active   |
| DOS_50_MPR_SOLDE_DOSSIER_INSTALLE      | PAC_Statut_Dossier_2                   | active   |
| DOS_50_MPR_SOLDE_INSTALL_CLOTUREE      | PAC_Installation11                     | active   |
| DOS_50_RAC_JAUNE_OBLIGATOIRE           | PAC_RAC_3                              | active   |
| DOS_50_RAC_MINIMUM_AVEC_KIT            | PAC_RAC_8                              | active   |
| DOS_50_RAC_MINIMUM_SANS_KIT            | PAC_RAC_2                              | active   |
| DOS_50_RAC_MODALITE_PAIEMENT           | PAC_Installation10                     | inactive |
| DOS_50_RAC_SELON_PRECARITE             | PAC_RAC_1                              | active   |
| DOS_60_INSTALL_CHAMPS_POSE             | PAC_Installation8                      | active   |
| DOS_60_INSTALL_CHANTIER_PREVALIDE      | PAC_Installation7                      | active   |
| DOS_60_INSTALL_DEPLACEMENT_SANS_RETOUR | INSTALLATION_DEPLACEMENT_PAS_DE_RETOUR | active   |
| DOS_60_INSTALL_ENVOI_EN_POSE           | Devis_171                              | active   |
| DOS_60_INSTALL_FIN_CHANTIER_SIGNEE     | PAC_Installation15                     | active   |
| DOS_60_INSTALL_MAIL_SOUS_TRAITANT      | PAC_Installation5                      | active   |
| DOS_60_INSTALL_MAIL_SOUS_TRAITANT_2    | date_installe_pac                      | active   |
| DOS_70_DOSSIER_ANNULATION_CHAMPS       | Statut_Dossier_2                       | active   |
| DOS_70_DOSSIER_ANNULATION_TH174        | VALIDATION_AnnulationFrere             | inactive |
| DOS_70_DOSSIER_ATTENTE_VS_CLOTURE      | Statut_Dossier_1                       | active   |
| DOS_70_DOSSIER_CLOTURE_SI_INSTALLE     | Statut_Dossier_4                       | active   |
| DOS_70_DOSSIER_INSTALLE_SI_CLOTURE     | Statut_Dossier_3                       | active   |
| DOS_70_DOSSIER_LOCATAIRE               | PAC_Statut_Dossier_1                   | active   |
| DOS_70_DOSSIER_PAS_DE_NON              | GLOBAL_METTRE_NON_APRES_CONVERSION     | active   |
| DOS_75_CEE_DATE_MODIF                  | CEE_MODIFS_STATUT                      | active   |
| DOS_75_CEE_STATUT_DOSSIER              | CEE_STATUT                             | active   |
| DOS_80_LEDS_AUDIT_VALIDE               | LEDS_FIN_DE_CHANTIER6                  | active   |
| DOS_80_LEDS_AUDITEUR                   | LEDS_FIN_DE_CHANTIER5                  | active   |
| DOS_80_LEDS_DEVIS_SIGNE                | DEVIS_Date_Signature                   | active   |
| DOS_80_LEDS_INSTALL_CHAMPS             | LEDS_INSTALLATION                      | active   |
| DOS_80_LEDS_INSTALL_CLOTUREE           | LEDS_INSTALLATION6                     | active   |
| DOS_80_LEDS_QTE_ET_MODE                | LEDS_FIN_DE_CHANTIER                   | active   |
| DOS_80_LEDS_QTE_FINALE                 | LEDS_FIN_DE_CHANTIER3                  | active   |
| DOS_80_LEDS_QTE_MINIMUM                | LEDS_Qte_INF                           | active   |
| DOS_80_LEDS_TYPE_COMME_PISTE           | LEDS_MEME_QUE_LA_PISTE                 | active   |
| DOS_90_CONTROLE_ANTI_VIDE_1            | CHAMPS_NUL                             | active   |
| DOS_90_CONTROLE_ANTI_VIDE_2            | CHAMPS_NUL2                            | active   |

## Pistes — détail

### Étape 10 — Création et accès

#### PIS_10_ACCES_PORTAIL_REGIES_BLOQUE

Ancien nom : `Block_AutreQueProLeds2`. Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                                        | Proposé                                                                                                                              |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| Nom                 | Block_AutreQueProLeds2                                                                                                             | PIS_10_ACCES_PORTAIL_REGIES_BLOQUE                                                                                                   |
| Description         | Si vous souhaitez travailler sur une autre fiche avec nous, Merci de contacter Mike par Whatsapp, Merci                            | Bloque tout enregistrement de piste par le profil PORTAIL INTERNE- REGIES : les régies doivent passer par le nouveau CRM.            |
| Message utilisateur | Si vous souhaitez travailler sur une autre fiche avec nous, Vous devez passer par le nouveau CRM, demandez nous un acces,<br>Merci | Ce portail n'est plus utilisé par les régies. Merci de passer par le nouveau CRM et de nous demander un accès si vous n'en avez pas. |

#### PIS_10_ACCES_REGIES_LEDS_UNIQUEMENT

Ancien nom : `Block_AutreQueProLeds`. Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                             | Proposé                                                                                                                                                                                                                                 |
| ------------------- | ------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | Block_AutreQueProLeds                                                                                   | PIS_10_ACCES_REGIES_LEDS_UNIQUEMENT                                                                                                                                                                                                     |
| Description         | Si vous souhaitez travailler sur une autre fiche avec nous, Merci de contacter Mike par Whatsapp, Merci | Liste d'une trentaine d'utilisateurs de régies externes (repérés par leur identifiant de connexion) : ils ne peuvent enregistrer que des pistes Régies LEDS (« Tech_typeEnregistrement » = RegiesLeds) ; toute autre fiche est bloquée. |
| Message utilisateur | Si vous souhaitez travailler sur une autre fiche avec nous, Merci de contacter Mike par Whatsapp, Merci | Votre accès est limité aux fiches Régies LEDS. Pour travailler sur un autre type de fiche avec nous, merci de contacter Mike par WhatsApp.                                                                                              |

#### PIS_10_ACCES_REGIES_SANS_VELO_CARGO

Ancien nom : `PORTAIL_REGIE`. Message affiché sous le champ « Type de Dossier v3 ».

|                     | Aujourd'hui                                             | Proposé                                                                                                    |
| ------------------- | ------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| Nom                 | PORTAIL_REGIE                                           | PIS_10_ACCES_REGIES_SANS_VELO_CARGO                                                                        |
| Description         | Ce produit n'est pas disponible pour les régies, Merci  | Le profil PORTAIL INTERNE- REGIES ne peut pas choisir « Type de Dossier v3 » = 🟩TRA-EQ-131- Vélos Cargos. |
| Message utilisateur | Ce produit n'est pas disponible pour les régies, Merci. | Le produit Vélos Cargos n'est pas disponible pour les régies. Merci de choisir un autre type de dossier.   |

#### PIS_10_CREATION_LOOKUP_A_SON_NOM

Ancien nom : `Creation_piste_lookuo`. Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                  | Proposé                                                                                                                                                                                                                                |
| ------------------- | -------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | Creation_piste_lookuo                                                                        | PIS_10_CREATION_LOOKUP_A_SON_NOM                                                                                                                                                                                                       |
| Description         | Pour creer une nouvelle piste, il faut que le lookup soit a ton nom.                         | Création d'une piste : un Confirmateur doit se mettre dans « LOOKUP- Confirmateur » et laisser « LOOKUP- Telepro » vide ; un Télépro (Data ou Leads) doit se mettre dans « LOOKUP- Telepro » et laisser « LOOKUP- Confirmateur » vide. |
| Message utilisateur | Pour creer une nouvelle piste, il faut que le lookup telepro ou confirmateur soit a ton nom. | Pour créer une piste, merci de vous mettre dans votre lookup (« LOOKUP- Telepro » ou « LOOKUP- Confirmateur ») et de laisser l'autre vide.                                                                                             |

#### PIS_10_CREATION_TYPE_DOSSIER_COHERENT

Ancien nom : `VR_Lead_TypeDeDossier_CoherenceRecordTyp`. Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                  | Proposé                                                                                                                                                                                       |
| ------------------- | -------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | VR_Lead_TypeDeDossier_CoherenceRecordTyp                                                     | PIS_10_CREATION_TYPE_DOSSIER_COHERENT                                                                                                                                                         |
| Description         | _(vide)_                                                                                     | Cohérence type d'enregistrement / « Type de dossier » : une piste AA- RESIDENTIEL, AA- BAT, AA- AGRI ou AA- IND ne peut pas contenir un type de dossier d'une autre famille (BAR, BAT, AGRI). |
| Message utilisateur | Le type de dossier sélectionné n'est pas compatible avec le type d'enregistrement de ce RDV. | Le « Type de dossier » choisi ne correspond pas au type de piste (résidentiel, tertiaire, agri ou industrie). Merci de choisir un type de dossier de la même famille.                         |

### Étape 20 — Télépro

#### PIS_20_TELEPRO_A_RETRAITER_LOOKUP

Ancien nom : `LEAD_CHANGEMENT_STATUT`. Message affiché sous le champ « LOOKUP- Telepro ».

|                     | Aujourd'hui                                                     | Proposé                                                                                                                                           |
| ------------------- | --------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | LEAD_CHANGEMENT_STATUT                                          | PIS_20_TELEPRO_A_RETRAITER_LOOKUP                                                                                                                 |
| Description         | Si changement de statut Lead alors mettre le Lookup à votre nom | Profil Télépro Leads : dès que « LEADS- Statut » est une valeur À RETRAITER (🟦A RAPPELER), « LOOKUP- Telepro » doit être l'utilisateur connecté. |
| Message utilisateur | Si changement de statut Lead alors mettre le Lookup à votre nom | Pour changer le statut de cette fiche, merci de vous mettre dans « LOOKUP- Telepro ».                                                             |

#### PIS_20_TELEPRO_ENVOI_CONF_CHAMPS_BD

Ancien nom : `BASE_ITE_ENVOYE_EN_CONF2`. Message affiché sous le champ « CONFIRM- Date de Rappel ».

|                     | Aujourd'hui                                                                                                         | Proposé                                                                                                                                                                                                      |
| ------------------- | ------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Nom                 | BASE_ITE_ENVOYE_EN_CONF2                                                                                            | PIS_20_TELEPRO_ENVOI_CONF_CHAMPS_BD                                                                                                                                                                          |
| Description         | Pour envoyer en confirmation, il faut que le commentaire de rappel soient rempli.                                   | 🟩ENVOYÉ EN CONF par un Télépro Data : sur BD.ITE, « TELEPRO- Commentaire » obligatoire ; sur BD.RENO, « CONFIRM- Date de Rappel », « CONFIRM- Créneau de Rappel » et « TELEPRO- Commentaire » obligatoires. |
| Message utilisateur | Pour envoyer en confirmation, il faut que la date, le creneau de rappel et le "Télépro- Commentaire" soient rempli. | Pour envoyer la fiche en confirmation, merci de renseigner la date et le créneau de rappel du confirmateur ainsi que votre commentaire (« TELEPRO- Commentaire »).                                           |

#### PIS_20_TELEPRO_ENVOI_CONF_CONFIRM_BD

Ancien nom : `BASE_ITE_ENVOYE_EN_CONF3`. Message affiché sous le champ « LOOKUP- Confirmateur ».

|                     | Aujourd'hui                                                   | Proposé                                                                                                                  |
| ------------------- | ------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| Nom                 | BASE_ITE_ENVOYE_EN_CONF3                                      | PIS_20_TELEPRO_ENVOI_CONF_CONFIRM_BD                                                                                     |
| Description         | _(vide)_                                                      | « BD.ITE- Sous Statut » ou « BD.RENO- Statut » = 🟩ENVOYÉ EN CONF (tous profils) : « LOOKUP- Confirmateur » obligatoire. |
| Message utilisateur | Merci de remplir le Lookup Confirmateur pour envoyer en Conf. | Pour envoyer la fiche en confirmation, merci de choisir le confirmateur dans « LOOKUP- Confirmateur ».                   |

#### PIS_20_TELEPRO_ENVOI_CONF_CONFIRM_LEADS

Ancien nom : `LEAD_ENVOI_CONF`. Message affiché sous le champ « LOOKUP- Confirmateur ».

|                     | Aujourd'hui                                           | Proposé                                                                                                                                   |
| ------------------- | ----------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | LEAD_ENVOI_CONF                                       | PIS_20_TELEPRO_ENVOI_CONF_CONFIRM_LEADS                                                                                                   |
| Description         | Si Envoi en Conf alors remplir le nom du Confirmateur | Profil Télépro Leads, « LEADS- Statut » = 🟩ENVOYÉ EN CONFF (valeur absente de la liste actuelle) : « LOOKUP- Confirmateur » obligatoire. |
| Message utilisateur | Si Envoi en Conf alors remplir le nom du Confirmateur | Pour envoyer la fiche en confirmation, merci de choisir le confirmateur dans « LOOKUP- Confirmateur ».                                    |

#### PIS_20_TELEPRO_ENVOI_CONF_LOOKUP_BD

Ancien nom : `BASE_ITE_ENVOYE_EN_CONF`. Message affiché sous le champ « LOOKUP- Telepro ».

|                     | Aujourd'hui                                                                                                                                    | Proposé                                                                                                                                                                                                                           |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | BASE_ITE_ENVOYE_EN_CONF                                                                                                                        | PIS_20_TELEPRO_ENVOI_CONF_LOOKUP_BD                                                                                                                                                                                               |
| Description         | Il faut que le Lookup soit égale au Télépro pour mettre envoyer en conf                                                                        | 🟩ENVOYÉ EN CONF par un télépro : « LOOKUP- Telepro » doit être l'utilisateur connecté (Télépro Data sur BD.ITE, Télépro Leads sur BD.RENO) ; pour Télépro Leads, « CONFIRM- Traitement » doit aussi être ▣ EN ATT DE TRAITEMENT. |
| Message utilisateur | Pour envoyer en confirmation, il faut que le Lookup du telepro soit rempli et que le champs CONFIRM- Traitement soit en ▣ EN ATT DE TRAITEMENT | Pour envoyer la fiche en confirmation, merci de vous mettre dans « LOOKUP- Telepro » et de laisser « CONFIRM- Traitement » sur ▣ EN ATT DE TRAITEMENT.                                                                            |

#### PIS_20_TELEPRO_ENVOI_CONF_LOOKUP_LEADS

Ancien nom : `LEAD_CHANGEMENT_STATUT3`. Message affiché sous le champ « LOOKUP- Telepro ».

|                     | Aujourd'hui                                                     | Proposé                                                                                                                                                                          |
| ------------------- | --------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | LEAD_CHANGEMENT_STATUT3                                         | PIS_20_TELEPRO_ENVOI_CONF_LOOKUP_LEADS                                                                                                                                           |
| Description         | Si changement de statut Lead alors mettre le Lookup à votre nom | Profil Télépro Leads : dès que « LEADS- Statut » contient ENVOYÉ EN CONF (aucune valeur de ce nom dans la liste actuelle), « LOOKUP- Telepro » doit être l'utilisateur connecté. |
| Message utilisateur | Si changement de statut Lead alors mettre le Lookup à votre nom | Pour envoyer la fiche en confirmation, merci de vous mettre dans « LOOKUP- Telepro ».                                                                                            |

#### PIS_20_TELEPRO_HORS_CIBLE_LOOKUP

Ancien nom : `LEAD_CHANGEMENT_STATUT2`. Message affiché sous le champ « LOOKUP- Telepro ».

|                     | Aujourd'hui                                                     | Proposé                                                                                                                              |
| ------------------- | --------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| Nom                 | LEAD_CHANGEMENT_STATUT2                                         | PIS_20_TELEPRO_HORS_CIBLE_LOOKUP                                                                                                     |
| Description         | Si changement de statut Lead alors mettre le Lookup à votre nom | Profil Télépro Leads : dès que « LEADS- Statut » est une valeur ⬛ HORS CIBLE, « LOOKUP- Telepro » doit être l'utilisateur connecté. |
| Message utilisateur | Si changement de statut Lead alors mettre le Lookup à votre nom | Pour mettre la fiche en ⬛ HORS CIBLE, merci de vous mettre dans « LOOKUP- Telepro ».                                                |

#### PIS_20_TELEPRO_QUESTIONS_CHAUFFAGE — règle inactive

Ancien nom : `Si_interesser_panneau_pac_ou_ite`. Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                                                        | Proposé                                                                                                                                                                                                          |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | Si_interesser_panneau_pac_ou_ite                                                                                                                   | PIS_20_TELEPRO_QUESTIONS_CHAUFFAGE                                                                                                                                                                               |
| Description         | _(vide)_                                                                                                                                           | « Interesser par Panneau solaire », « Interesser par Isolation Exterieur » ou « Intéresser par PAC/Ballon » = Oui : « Mode de chauffage principal » et « Avez vous deja bénéficier d'une étude ? » obligatoires. |
| Message utilisateur | Veuillez renseigner les champs <br>Mode de chauffage principal<br>Motivation du client pour les travaux<br>Avez vous deja bénéficier d'une étude ? | Le client est intéressé par un produit. Merci de remplir « Mode de chauffage principal » et « Avez vous deja bénéficier d'une étude ? ».                                                                         |

#### PIS_20_TELEPRO_QUESTIONS_ITE

Ancien nom : `Si_ite_oui_alors_remplir_les_champs`. Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                          | Proposé                                                                                                                                                                                                                             |
| ------------------- | ---------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | Si_ite_oui_alors_remplir_les_champs                                                                  | PIS_20_TELEPRO_QUESTIONS_ITE                                                                                                                                                                                                        |
| Description         | Veuillez remplir tous les champs requis lorsque le client est intéressé par l'isolation extérieure.​ | « Interesser par Isolation Exterieur » = Oui : Maison Mitoyenne, Pignon sur rue, Types des murs extérieurs, Espace pour l'echaffaudage, Maison en travaux, Maison Classé, Etat de la facade et Surface à isoler en m² obligatoires. |
| Message utilisateur | Veuillez remplir tous les champs requis lorsque le client est intéressé par l'isolation extérieure.​ | Le client est intéressé par l'isolation extérieure : merci de remplir les questions sur la maison (mitoyenneté, pignon sur rue, murs, échafaudage, travaux, maison classée, façade, surface à isoler).                              |

#### PIS_20_TELEPRO_QUESTIONS_PAC — règle inactive

Ancien nom : `Si_interesser_par_pompe_a_chaleur`. Message affiché en haut de la page.

|                     | Aujourd'hui                                                     | Proposé                                                                                                                         |
| ------------------- | --------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | Si_interesser_par_pompe_a_chaleur                               | PIS_20_TELEPRO_QUESTIONS_PAC                                                                                                    |
| Description         | _(vide)_                                                        | « Intéresser par PAC/Ballon » = Oui : « Emplacement de la chaudiere », « Pompe à Chaleur » et « PAC 179- ECS » obligatoires.    |
| Message utilisateur | Veuillez remplir les informations concernant la Pompe à Chaleur | Le client est intéressé par une PAC. Merci de remplir « Emplacement de la chaudiere », « Pompe à Chaleur » et « PAC 179- ECS ». |

#### PIS_20_TELEPRO_QUESTIONS_SOLAIRE

Ancien nom : `Si_interesser_par_panneaux_solaires`. Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                                                                                                                                           | Proposé                                                                                                                                                                                                                                |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | Si_interesser_par_panneaux_solaires                                                                                                                                                                                                   | PIS_20_TELEPRO_QUESTIONS_SOLAIRE                                                                                                                                                                                                       |
| Description         | _(vide)_                                                                                                                                                                                                                              | « Interesser par Panneau solaire » = Oui : Exposition de la toiture, velux, Chiens-Assis, Type de toiture, A déjà des panneaux ?, Superficie Libre, Ombrage, Eglise ou Monument proche et Installation en Panneau Proche obligatoires. |
| Message utilisateur | Veuillez remplir les Champs<br>Superficie Libre sur la toiture<br>Exposition de la toiture<br>Ombrage de la toiture<br>Avez vous des velux <br>Eglise Monument proche<br>Avez vous des Chiens-Assis<br>Installation en Panneau Proche | Le client est intéressé par des panneaux solaires : merci de remplir les questions sur la toiture (exposition, velux, chiens-assis, type, panneaux existants, superficie libre, ombrage, monument proche, panneaux proches).           |

#### PIS_20_TELEPRO_RAPPEL_CHAMPS_BD

Ancien nom : `BASE_ITE_DATA`. Message affiché en haut de la page.

|                     | Aujourd'hui                                                                       | Proposé                                                                                                                                                                                                      |
| ------------------- | --------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Nom                 | BASE_ITE_DATA                                                                     | PIS_20_TELEPRO_RAPPEL_CHAMPS_BD                                                                                                                                                                              |
| Description         | Merci de renseigner le Télépro la date de rappel et le commentaire.               | « BD.ITE- Sous Statut » ou « BD.RENO- Statut » = 🟦A RAPPELER : « TELEPRO- Date de Rappel », « TELEPRO- Creneau Rappel » et « TELEPRO- Commentaire » obligatoires.                                           |
| Message utilisateur | Merci de renseigner le Télépro la date, le creneau et et le commentaire de rappel | Pour mettre la fiche en 🟦A RAPPELER, merci de renseigner la date de rappel, le créneau de rappel et votre commentaire (« TELEPRO- Date de Rappel », « TELEPRO- Creneau Rappel », « TELEPRO- Commentaire »). |

#### PIS_20_TELEPRO_RAPPEL_CHAMPS_LEADS

Ancien nom : `Champs_DATE_DE_RAPPEL`. Message affiché sous le champ « TELEPRO- Date de Rappel ».

|                     | Aujourd'hui                                                               | Proposé                                                                                                                                                                                                      |
| ------------------- | ------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Nom                 | Champs_DATE_DE_RAPPEL                                                     | PIS_20_TELEPRO_RAPPEL_CHAMPS_LEADS                                                                                                                                                                           |
| Description         | Veuillez renseigner la Date et l'Heure de Rappel                          | Profil Télépro Leads, « LEADS- Statut » = 🟦A RAPPELER : « TELEPRO- Date de Rappel », « TELEPRO- Creneau Rappel » et « TELEPRO- Commentaire » obligatoires.                                                  |
| Message utilisateur | Veuillez renseigner la Date et l'Heure et mettre un commentaire de Rappel | Pour mettre la fiche en 🟦A RAPPELER, merci de renseigner la date de rappel, le créneau de rappel et votre commentaire (« TELEPRO- Date de Rappel », « TELEPRO- Creneau Rappel », « TELEPRO- Commentaire »). |

#### PIS_20_TELEPRO_RAPPEL_LOOKUP

Ancien nom : `BASE_ITE_RAPPEL`. Message affiché sous le champ « LOOKUP- Telepro ».

|                     | Aujourd'hui                                                        | Proposé                                                                                                                                                                    |
| ------------------- | ------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | BASE_ITE_RAPPEL                                                    | PIS_20_TELEPRO_RAPPEL_LOOKUP                                                                                                                                               |
| Description         | Il faut que le Lookup soit égale au Télépro pour mettre a rappeler | Profil Télépro Leads : pour mettre 🟦A RAPPELER (« BD.ITE- Sous Statut », « BD.RENO- Statut » ou « LEADS- Statut »), « LOOKUP- Telepro » doit être l'utilisateur connecté. |
| Message utilisateur | Il faut que le Lookup soit égale au Télépro pour mettre a rappeler | Pour mettre la fiche en 🟦A RAPPELER, merci de vous mettre dans « LOOKUP- Telepro ».                                                                                       |

#### PIS_20_TELEPRO_RAPPEL_SIGNATURE

Ancien nom : `Champs_DATE_DE_RAPPEL2`. Message affiché sous le champ « TELEPRO- Date de Rappel ».

|                     | Aujourd'hui                                                               | Proposé                                                                                                                                                                                                          |
| ------------------- | ------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | Champs_DATE_DE_RAPPEL2                                                    | PIS_20_TELEPRO_RAPPEL_SIGNATURE                                                                                                                                                                                  |
| Description         | Veuillez renseigner la Date et l'Heure de Rappel Pour la signature        | « LEADS- Statut » = 🟪A RAPPELER- POUR SIGNATURE !! (valeur absente de la liste actuelle) : « TELEPRO- Date de Rappel », « TELEPRO- Creneau Rappel » et « TELEPRO- Commentaire » obligatoires.                   |
| Message utilisateur | Veuillez renseigner la Date et l'Heure et mettre un commentaire de Rappel | Pour programmer un rappel pour signature, merci de renseigner la date de rappel, le créneau de rappel et votre commentaire (« TELEPRO- Date de Rappel », « TELEPRO- Creneau Rappel », « TELEPRO- Commentaire »). |

### Étape 30 — Confirmateur

#### PIS_30_CONFIRM_DEVIS_GENERE_DATE

Ancien nom : `CONF_DATE_GENERATION`. Message affiché sous le champ « CONFIRM- Géneration Devis ».

|                     | Aujourd'hui                                                                   | Proposé                                                                                                               |
| ------------------- | ----------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| Nom                 | CONF_DATE_GENERATION                                                          | PIS_30_CONFIRM_DEVIS_GENERE_DATE                                                                                      |
| Description         | Pour mettre en Devis Généré, merci de remplir la date de génération du devis. | « CONFIRM- Traitement » = 🟦DEVIS GÉNÉRÉ (valeur désactivée) : la date « CONFIRM- Géneration Devis » est obligatoire. |
| Message utilisateur | Pour mettre en Devis Généré, merci de remplir la date de génération du devis. | Pour mettre 🟦DEVIS GÉNÉRÉ, merci d'indiquer la date de génération du devis (« CONFIRM- Géneration Devis »).          |

#### PIS_30_CONFIRM_DEVIS_SIGNE_VERROU

Ancien nom : `BLOCAGE_Champs_Apres_SIgnature`. Message affiché en haut de la page.

|                     | Aujourd'hui                    | Proposé                                                                                                                                                                      |
| ------------------- | ------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | BLOCAGE_Champs_Apres_SIgnature | PIS_30_CONFIRM_DEVIS_SIGNE_VERROU                                                                                                                                            |
| Description         | _(vide)_                       | Une fois « RES- Statut Devis » = 🟩Signé, « DEVIS- Nombre de capteurs » et « DEVIS- Surface de toiture (m²) » ne peuvent plus être modifiés.                                 |
| Message utilisateur | Devis déjà signé.              | Le devis est déjà signé : le nombre de capteurs et la surface de toiture ne peuvent plus être modifiés. Merci de contacter le confirmateur si une correction est nécessaire. |

#### PIS_30_CONFIRM_HORS_CIBLE_COMMENTAIRE

Ancien nom : `CONFIRM_TRAITEMENT3`. Message affiché en haut de la page.

|                     | Aujourd'hui                                           | Proposé                                                                                                                                                             |
| ------------------- | ----------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | CONFIRM_TRAITEMENT3                                   | PIS_30_CONFIRM_HORS_CIBLE_COMMENTAIRE                                                                                                                               |
| Description         | Pour mettre en annulé, il faut mettre un commentaire. | Pistes AA- RESIDENTIEL- EXTERNE : « CONFIRM- Commentaire » obligatoire quand la valeur précédente de « CONFIRM- Traitement » était ⬛ HORS CIBLE- Voir commentaire. |
| Message utilisateur | Pour mettre en annulé, il faut mettre un commentaire. | La fiche est en ⬛ HORS CIBLE- Voir commentaire. Merci d'expliquer la raison dans « CONFIRM- Commentaire ».                                                         |

#### PIS_30_CONFIRM_LOOKUPS_VERROUILLES

Ancien nom : `LOOKUPS_DEJA_ATTRIBUES`. Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                                                                                                                            | Proposé                                                                                                                                                             |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | LOOKUPS_DEJA_ATTRIBUES                                                                                                                                                                                                 | PIS_30_CONFIRM_LOOKUPS_VERROUILLES                                                                                                                                  |
| Description         | Les profils PORTAIL ne peuvent pas changer un lookup Confirmateur, Telepro ou Previsiteur deja rempli : personne ne prend le dossier d'un autre. Seuls les administrateurs et le responsable telepro peuvent le faire. | _inchangée (déjà claire)_                                                                                                                                           |
| Message utilisateur | Ce dossier est déjà attribué : le confirmateur, le télépro et le prévisiteur ne peuvent être changés.                                                                                                                  | Ce dossier est déjà attribué : le confirmateur, le télépro et le prévisiteur ne peuvent plus être changés. Merci de vous adresser au responsable télépro si besoin. |

#### PIS_30_CONFIRM_RAPPEL_CHAMPS

Ancien nom : `Champs_DATE_DE_RAPPEL3`. Message affiché sous le champ « CONFIRM- Date de Rappel ».

|                     | Aujourd'hui                                                       | Proposé                                                                                                                                                                                                     |
| ------------------- | ----------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | Champs_DATE_DE_RAPPEL3                                            | PIS_30_CONFIRM_RAPPEL_CHAMPS                                                                                                                                                                                |
| Description         | Veuillez renseigner la Date et l'Heure de Rappel.                 | « CONFIRM- Traitement » = 🟦 Rappel Nécessaire : « CONFIRM- Date de Rappel », « CONFIRM- Créneau de Rappel » et « CONFIRM- Commentaire » obligatoires.                                                      |
| Message utilisateur | Veuillez renseigner la Date, l'Heure et le commentaire de Rappel. | Pour mettre 🟦 Rappel Nécessaire, merci de renseigner la date de rappel, le créneau de rappel et votre commentaire (« CONFIRM- Date de Rappel », « CONFIRM- Créneau de Rappel », « CONFIRM- Commentaire »). |

#### PIS_30_CONFIRM_RES060_SIGNATURE_CHAMPS

Ancien nom : `LEAD_ENVOI_CONF2`. Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                                                          | Proposé                                                                                                                                                                                                                                          |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Nom                 | LEAD_ENVOI_CONF2                                                                                                                                     | PIS_30_CONFIRM_RES060_SIGNATURE_CHAMPS                                                                                                                                                                                                           |
| Description         | Pour envoyer en confirmation, il faut que le commentaire de rappel soient rempli.                                                                    | RES060, « LEADS- Statut » 🟩Envoyé En Signature (Télépro Leads) ou « CONFIRM- Traitement » 🟫Conf Ok- Visite en attente : Adresse, lookup, PAC RES060 ✅- OUI, ✅Proprietaire Occupant et tous les champs RES du produit obligatoires.           |
| Message utilisateur | 1.Pour envoyer en signature,Il faut que tout les champs soient remplis<br>2.Pour mettre en confimation ok,Il faut que tout les champs soient remplis | Il manque des informations pour passer à l'étape suivante. Merci de remplir l'adresse, les lookups, RES060 sur ✅- OUI, ✅Proprietaire Occupant et les champs RES (années, chauffage, Shab, zone, medianería, parcelle, isolation, bono social). |

#### PIS_30_CONFIRM_RETOUR_EN_ATTENTE

Ancien nom : `CONFIRM_TRAITEMENT2`. Message affiché sous le champ « CONFIRM- Traitement ».

|                     | Aujourd'hui                                                                                                                                                       | Proposé                                                                                                                                                                                          |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Nom                 | CONFIRM_TRAITEMENT2                                                                                                                                               | PIS_30_CONFIRM_RETOUR_EN_ATTENTE                                                                                                                                                                 |
| Description         | Bloque les selections aux autres profils que le confirmateur                                                                                                      | Seul le profil Confirmateur peut remettre « CONFIRM- Traitement » sur ▣ EN ATT DE TRAITEMENT quand la valeur précédente était 🟦DEVIS GÉNÉRÉ, 🟩SIGNÉ (valeurs désactivées) ou un ⬛ HORS CIBLE. |
| Message utilisateur | Vous n'êtes pas autorisé à remettre ce statut si il y a eu un devis de généré,signé ou si le dossier a été annulé, merci de demander au confirmateur directement. | Un devis a été généré ou signé, ou la fiche est hors cible : elle ne peut pas revenir en ▣ EN ATT DE TRAITEMENT. Merci de demander au confirmateur.                                              |

#### PIS_30_CONFIRM_TH179_SURFACES

Ancien nom : `CALCUL_SHAB_163_179`. Message affiché sous le champ « BAT- Surf Total Batiment ».

|                     | Aujourd'hui                                                                      | Proposé                                                                                                                                                        |
| ------------------- | -------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | CALCUL_SHAB_163_179                                                              | PIS_30_CONFIRM_TH179_SURFACES                                                                                                                                  |
| Description         | Il faut que le cumul des surface soit coherente a la surface totale du batiment. | Dès qu'une surface est saisie, « PAC 179- Surf Chauffé PAC 163 » + « PAC 179- Surf Chauffé PAC 179 » doit être égal à « BAT- Surf Total Batiment ».            |
| Message utilisateur | Il faut que le cumul des surface soit coherente a la surface totale du batiment. | Les surfaces ne correspondent pas. Merci de vérifier que « PAC 179- Surf Chauffé PAC 163 » + « PAC 179- Surf Chauffé PAC 179 » = « BAT- Surf Total Batiment ». |

#### PIS_30_CONFIRM_VALEURS_RESERVEES

Ancien nom : `CONFIRM_TRAITEMENT`. Message affiché sous le champ « CONFIRM- Traitement ».

|                     | Aujourd'hui                                                         | Proposé                                                                                                                                                                           |
| ------------------- | ------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | CONFIRM_TRAITEMENT                                                  | PIS_30_CONFIRM_VALEURS_RESERVEES                                                                                                                                                  |
| Description         | Bloque les selections aux autres profils que le confirmateur        | « CONFIRM- Traitement » : les valeurs vide, 🟨 NRP- 1x à 4x et rappel sont réservées aux profils Confirmateur (y compris PRO LEDS et PRO LEDS/DESTRAT) et Administrateur système. |
| Message utilisateur | Le confirmateur uniquement est autorisé à utiliser cette séléction. | Ce choix de « CONFIRM- Traitement » (vide, 🟨 NRP ou rappel) est réservé au confirmateur. Merci de lui laisser la main sur ce champ.                                              |

### Étape 40 — Prévisite

#### PIS_40_PREVISITE_AGRI_FICHE

Ancien nom : `Previsite_Agri1`. Message affiché sous le champ « PREVISITE- Fiches Tertiaire ».

|                     | Aujourd'hui                                                                                                    | Proposé                                                                                                                                                        |
| ------------------- | -------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | Previsite_Agri1                                                                                                | PIS_40_PREVISITE_AGRI_FICHE                                                                                                                                    |
| Description         | Merci de mettre en previsite, une fiche ou il y a une demande de création de dossier.                          | « PREVISITE- Fiches Agri » (🟩AGRI TH108- PAC, TH119- VMC, EQ108- Tubes) : le champ « Création Dossier » du même produit doit être sur ✅- OUI.                |
| Message utilisateur | Si vous choisissez une fiche CEE en previsite il faut que la création dossier de cette fiche soit aussi en OUI | La fiche de prévisite choisie ne correspond à aucun produit demandé. Merci de mettre son champ « Création Dossier » sur ✅- OUI ou de choisir une autre fiche. |

#### PIS_40_PREVISITE_AGRI_STATUT

Ancien nom : `Previsite_2_agri`. Message affiché sous le champ « PREVISITE- Nécessité ».

|                     | Aujourd'hui                                                                                                                                                                                                                                                | Proposé                                                                                                                                                                                                                                             |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | Previsite_2_agri                                                                                                                                                                                                                                           | PIS_40_PREVISITE_AGRI_STATUT                                                                                                                                                                                                                        |
| Description         | Pour envoyer en previsite, Merci de mettre Passage demandé ou Passage Planifié.<br>Si le passage est demandé, la date doit être vide.<br>Si le passage est planifié, merci de renseigner une date.                                                         | Agri (AA- AGRI- INTERNE / EXTERNE). « PREVISITE- Nécessité » ❌- NON : ▣ Att Planification, sans Previsiteur, fiche ni date. ✅- OUI : 🟨Passage Demandé (fiche Agri, sans Previsiteur ni date) ou 🟧Passage Planifié (Previsiteur + fiche + date). |
| Message utilisateur | Pour envoyer en previsite, Merci de mettre Passage demandé ou Passage Planifié.<br>Si le passage est demandé, la fiche CEE rempli, la date vide et l'auditeur en nouveau dossier.<br>Si le passage est planifié, la fiche CEE, la date et auditeur rempli. | Prévisite incomplète. ✅- OUI : 🟨Passage Demandé avec la fiche Agri, sans pré-visiteur ni date ; 🟧Passage Planifié avec fiche, pré-visiteur et date. ❌- NON : merci de laisser les champs prévisite vides.                                       |

#### PIS_40_PREVISITE_PRISE_EN_CHARGE

Ancien nom : `Previsite_Residentiel3`. Message affiché sous le champ « PREVISITE- Nécessité ».

|                     | Aujourd'hui                                                                                                                                                                                                                                   | Proposé                                                                                                                                                                                                                                            |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | Previsite_Residentiel3                                                                                                                                                                                                                        | PIS_40_PREVISITE_PRISE_EN_CHARGE                                                                                                                                                                                                                   |
| Description         | Si 171 et 174 alors                                                                                                                                                                                                                           | RENO TH174 ✅- OUI : « PREVISITE- Nécessité » = ✅- OUI obligatoire (profil Confirmateur). TH171 : « PREVISITE- Prise en charge » 🟩A Notre charge interdite si « RES- Shab » < 90, ou si précarité autre que 🟦Bleu (sauf source cee-apporteurs). |
| Message utilisateur | 1.Si previsite pour un dossier de -90m, alors a la charge de l'apporteur,<br>2.Si previsite pour un dossier different de bleu alors a la charge de l'apporteur,<br>3.Si vous avez un dossier 174 alors il faut obligatoirement une prévisite. | Prévisite à revoir : un dossier TH174 doit avoir une prévisite. En TH171, elle est à la charge de l'apporteur si la Shab est sous 90 m² ou si la précarité n'est pas 🟦Bleu. Merci de corriger « PREVISITE- Prise en charge ».                     |

#### PIS_40_PREVISITE_RESIDENTIEL_FICHE

Ancien nom : `Previsite_Residentiel1`. Message affiché sous le champ « PREVISITE- Fiches Résidentiel ».

|                     | Aujourd'hui                                                                                                                                                                                                      | Proposé                                                                                                                                                                                                                                       |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | Previsite_Residentiel1                                                                                                                                                                                           | PIS_40_PREVISITE_RESIDENTIEL_FICHE                                                                                                                                                                                                            |
| Description         | Merci de mettre en previsite, une fiche ou il y a une demande de création de dossier.                                                                                                                            | « PREVISITE- Fiches Résidentiel » : le produit choisi (TH174, TH168, TH171, RES-060) doit avoir « Création Dossier » = ✅- OUI ; et si « PREVISITE- Nécessité » = ✅- OUI, la fiche doit être celle du produit demandé (171, 168 ou RES-060). |
| Message utilisateur | 1.Si vous choisissez une fiche CEE en previsite il faut que la création dossier de cette fiche soit aussi en OUI<br>2.Si 171 mettre visite 171<br>3.Si 168 mettre visite 168<br>4.Si RES060 mettre visite RES060 | La fiche de prévisite ne correspond pas au produit demandé. Merci de choisir la fiche du produit qui est sur ✅- OUI (TH171, TH168 ou RES-060).                                                                                               |

#### PIS_40_PREVISITE_RESIDENTIEL_STATUT

Ancien nom : `Previsite_1residentiel`. Message affiché sous le champ « PREVISITE- Nécessité ».

|                     | Aujourd'hui                                                                                                                                                                                                         | Proposé                                                                                                                                                                                                                                                 |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | Previsite_1residentiel                                                                                                                                                                                              | PIS_40_PREVISITE_RESIDENTIEL_STATUT                                                                                                                                                                                                                     |
| Description         | Pour envoyer en previsite, Merci de mettre Passage demandé ou Passage Planifié.<br>Si le passage est demandé, la date doit être vide.<br>Si le passage est planifié, merci de renseigner une date.                  | Résidentiel hors RES-060. « PREVISITE- Nécessité » ❌- NON : ▣ Att Planification, sans Previsiteur, fiche ni date. ✅- OUI : 🟨Passage Demandé (Previsiteur + fiche, sans date) ou 🟧Passage Planifié (+ date). TH171 : « PREVISITE- Prise en charge ». |
| Message utilisateur | Pour envoyer en previsite, Merci de mettre Passage demandé ou Passage Planifié.<br>Si le passage est demandé, la date doit être vide.<br>Si le passage est planifié, merci de renseigner une date et une fiche CEE. | Prévisite incomplète. ✅- OUI : 🟨Passage Demandé avec pré-visiteur et fiche, sans date ; 🟧Passage Planifié avec la date en plus (TH171 : prise en charge aussi). ❌- NON : merci de laisser les champs prévisite vides.                               |

#### PIS_40_PREVISITE_TERTIAIRE_FICHE

Ancien nom : `Previsite_Tertiaire1`. Message affiché sous le champ « PREVISITE- Fiches Tertiaire ».

|                     | Aujourd'hui                                                                                                    | Proposé                                                                                                                                                                                     |
| ------------------- | -------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | Previsite_Tertiaire1                                                                                           | PIS_40_PREVISITE_TERTIAIRE_FICHE                                                                                                                                                            |
| Description         | Merci de mettre en previsite, une fiche ou il y a une demande de création de dossier.                          | « PREVISITE- Fiches Tertiaire » (🟩BAT TH142- Déstratificateurs, BAT TH163- PAC Tertiaire, BAR TH179- PAC Collectif) : le champ « Création Dossier » du même produit doit être sur ✅- OUI. |
| Message utilisateur | Si vous choisissez une fiche CEE en previsite il faut que la création dossier de cette fiche soit aussi en OUI | La fiche de prévisite choisie ne correspond à aucun produit demandé. Merci de mettre son champ « Création Dossier » sur ✅- OUI ou de choisir une autre fiche.                              |

#### PIS_40_PREVISITE_TERTIAIRE_STATUT

Ancien nom : `Previsite_2_tertiaire`. Message affiché sous le champ « PREVISITE- Nécessité ».

|                     | Aujourd'hui                                                                                                                                                                                        | Proposé                                                                                                                                                                                                                                       |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | Previsite_2_tertiaire                                                                                                                                                                              | PIS_40_PREVISITE_TERTIAIRE_STATUT                                                                                                                                                                                                             |
| Description         | Pour envoyer en previsite, Merci de mettre Passage demandé ou Passage Planifié.<br>Si le passage est demandé, la date doit être vide.<br>Si le passage est planifié, merci de renseigner une date. | Tertiaire (AA- BAT- INTERNE / EXTERNE). « PREVISITE- Nécessité » ❌- NON : ▣ Att Planification, sans Previsiteur, fiche ni date. ✅- OUI : 🟨Passage Demandé (fiche Tertiaire, sans date) ou 🟧Passage Planifié (Previsiteur + fiche + date). |
| Message utilisateur | Pour envoyer en previsite, Merci de mettre Passage demandé ou Passage Planifié.<br>Si le passage est demandé, la date doit être vide.<br>Si le passage est planifié, merci de renseigner une date. | Prévisite incomplète. ✅- OUI : 🟨Passage Demandé avec la fiche Tertiaire, sans date ; 🟧Passage Planifié avec fiche, pré-visiteur et date. ❌- NON : merci de laisser les champs prévisite vides.                                            |

#### PIS_40_PREVISITE_TH171_TH174_DEMANDE — règle inactive

Ancien nom : `Previsite_Residentiel2`. Message affiché sous le champ « PREVISITE- Fiches Résidentiel ».

|                     | Aujourd'hui                                                                                        | Proposé                                                                                                                                                                               |
| ------------------- | -------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | Previsite_Residentiel2                                                                             | PIS_40_PREVISITE_TH171_TH174_DEMANDE                                                                                                                                                  |
| Description         | Si 171 et 174 alors                                                                                | PAC TH171 et RENO TH174 tous deux sur ✅- OUI : « PREVISITE- Statut » = 🟧Passage Planifié interdit (la prévisite se fait après la fin de la 171, donc 🟨Passage Demandé uniquement). |
| Message utilisateur | Si 171 et 174, la previsite se fait apres la fin de la 171- donc mettre uniquement passage demandé | Avec TH171 et TH174, la prévisite se fait après la fin de la 171. Merci de mettre « PREVISITE- Statut » sur 🟨Passage Demandé.                                                        |

### Étape 50 — Conversion

#### PIS_50_CONVERSION_AGRI_FICHES — règle inactive

Ancien nom : `Conversion_VerificationAGRI`. Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                 | Proposé                                                                                                                                                             |
| ------------------- | ----------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | Conversion_VerificationAGRI                                                                                 | PIS_50_CONVERSION_AGRI_FICHES                                                                                                                                       |
| Description         | _(vide)_                                                                                                    | AGRI : si l'un des champs « Création Dossier » PAC TH108, VMC TH119 ou TUBES EQ108 est rempli, les trois doivent l'être ; ils ne peuvent pas être tous sur ❌- NON. |
| Message utilisateur | AGRICULTURE<br>Vous avez au moins un champs de produit qui est vide,<br>Ou vous avez tout les champs en NON | Les trois fiches AGRICULTURE vont ensemble. Merci de remplir « Création Dossier » pour PAC TH108, VMC TH119 et TUBES EQ108, avec au moins un ✅- OUI.               |

#### PIS_50_CONVERSION_ANCIEN_LEDS_REGIE — règle inactive

Ancien nom : `Convertir_4`. Message affiché sous le champ « LEDS 127- Type Installation ».

|                     | Aujourd'hui                            | Proposé                                                                                                                                                                                |
| ------------------- | -------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | Convertir_4                            | PIS_50_CONVERSION_ANCIEN_LEDS_REGIE                                                                                                                                                    |
| Description         | En Regie, on ne fait pas la livraison. | Ancienne règle LEDS en régie : à la conversion d'une piste dont « LOOKUP-REGIE » est rempli, « LEDS 127- Type Installation » doit être ✅HORS AGRICULTURE (pas de livraison en régie). |
| Message utilisateur | En Regie, on ne fait pas la livraison. | Nous ne faisons pas de livraison en régie. Merci de mettre « LEDS 127- Type Installation » sur ✅HORS AGRICULTURE.                                                                     |

#### PIS_50_CONVERSION_ANCIEN_TH142_TH171 — règle inactive

Ancien nom : `Convertir_2`. Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                         | Proposé                                                                                                                                                                                                      |
| ------------------- | ------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Nom                 | Convertir_2                                                                                                         | PIS_50_CONVERSION_ANCIEN_TH142_TH171                                                                                                                                                                         |
| Description         | Veuillez remplir tout les champs si vous souhaitez Convertir.2                                                      | Ancienne règle de conversion DESTRAT TH142, PAC TH171 et RENO TH174 (✅- OUI ou ✅- Avec Prévisite🚗) : coordonnées, champs PRO, surface et chauffage obligatoires, « TYPE DE DOSSIER » = ▣ Nouveau Dossier. |
| Message utilisateur | Veuillez remplir tout les champs si vous souhaitez Convertir.256.<br>Mettre un Commentaire obligatoire pour le LEDS | Des informations manquent pour convertir. Merci de remplir les coordonnées, les champs PRO, la surface et le chauffage.                                                                                      |

#### PIS_50_CONVERSION_ANCIEN_TH179 — règle inactive

Ancien nom : `Convertir_3`. Message affiché en haut de la page.

|                     | Aujourd'hui                                                    | Proposé                                                                                                                                                                                                               |
| ------------------- | -------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | Convertir_3                                                    | PIS_50_CONVERSION_ANCIEN_TH179                                                                                                                                                                                        |
| Description         | Veuillez remplir tout les champs si vous souhaitez Convertir.3 | Ancienne règle de conversion PAC TH179 (✅- OUI ou ✅- Avec Prévisite🚗) : coordonnées, champs PRO, « BAT- Surf Total Batiment » et « BAT- Type de Chauffage » obligatoires, « TYPE DE DOSSIER » = ▣ Nouveau Dossier. |
| Message utilisateur | Veuillez remplir tout les champs si vous souhaitez Convertir.3 | Des informations manquent pour convertir. Merci de remplir les coordonnées, les champs PRO, « BAT- Surf Total Batiment » et « BAT- Type de Chauffage ».                                                               |

#### PIS_50_CONVERSION_ANCIEN_TYPE_V3 — règle inactive

Ancien nom : `Convertir_1`. Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                                                                             | Proposé                                                                                                                                                   |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | Convertir_1                                                                                                                                                             | PIS_50_CONVERSION_ANCIEN_TYPE_V3                                                                                                                          |
| Description         | Veuillez remplir les champs Commentaire telepro et Disponibilité, Commentaire pour Confirmateur et heure de rappel pour Confirmateur client si vous souhaitez Convertir | Ancienne règle basée sur « Type de Dossier v3 » (Vélos Cargos, 🟩RES- TH171- PAC, 🟨DATA, TH 174) : champs obligatoires pour passer la piste en Qualifié. |
| Message utilisateur | Veuillez remplir tout les champs si vous souhaitez Convertir.                                                                                                           | Des champs obligatoires pour ce type de dossier sont vides. Merci de les remplir avant de passer la piste en Qualifié.                                    |

#### PIS_50_CONVERSION_CHAMPS_EQ108

Ancien nom : `Conversion_REMPLISSAGE_TUBESEQ108`. Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                                        | Proposé                                                                                                                                                                                                                                                |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Nom                 | Conversion_REMPLISSAGE_TUBESEQ108                                                                                                  | PIS_50_CONVERSION_CHAMPS_EQ108                                                                                                                                                                                                                         |
| Description         | Veuillez remplir tout les champs si vous souhaitez Convertir.2                                                                     | Conversion TUBES EQ108 (✅- OUI) : Adresse, Email, Téléphone, PRO- Raison Sociale, Nom+Prenom / Fonction / Email / Téléphone Signataire, Siret, Code APE, Siege Social Adresse, « CONFIRM- Commentaire » et « AGRI- Infos Chantier 108 » obligatoires. |
| Message utilisateur | EQ108- Veuillez remplir tout les champs lié à votre produit si vous souhaitez Convertir.<br>+ Commentaire Confirmateur Obligatoire | Il manque des informations pour convertir ce dossier TUBES EQ108. Merci de remplir l'adresse, l'email, le téléphone, les champs PRO (raison sociale, signataire, Siret, code APE, siège), « AGRI- Infos Chantier 108 » et « CONFIRM- Commentaire ».    |

#### PIS_50_CONVERSION_CHAMPS_EQ110

Ancien nom : `Conversion_REMPLISSAGE_DPAROEQ112`. Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                                        | Proposé                                                                                                                                                                                                                                                  |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | Conversion_REMPLISSAGE_DPAROEQ112                                                                                                  | PIS_50_CONVERSION_CHAMPS_EQ110                                                                                                                                                                                                                           |
| Description         | Veuillez remplir tout les champs si vous souhaitez Convertir.2                                                                     | Conversion Séchage EQ110 (✅- OUI) : Adresse, Email, Téléphone, PRO- Raison Sociale, Nom+Prenom / Fonction / Email / Téléphone Signataire, Siret, Code APE, Siege Social Adresse, « AGRI- Infos Chantier 110 » et « CONFIRM- Commentaire » obligatoires. |
| Message utilisateur | EQ112- Veuillez remplir tout les champs lié à votre produit si vous souhaitez Convertir.<br>+ Commentaire Confirmateur Obligatoire | Il manque des informations pour convertir ce dossier Séchage EQ110. Merci de remplir l'adresse, l'email, le téléphone, les champs PRO (raison sociale, signataire, Siret, code APE, siège), « AGRI- Infos Chantier 110 » et « CONFIRM- Commentaire ».    |

#### PIS_50_CONVERSION_CHAMPS_EQ127

Ancien nom : `Conversion_REMPLISSAGE_LEDSEQ127`. Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                                       | Proposé                                                                                                                                                                                                                                         |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | Conversion_REMPLISSAGE_LEDSEQ127                                                                                                  | PIS_50_CONVERSION_CHAMPS_EQ127                                                                                                                                                                                                                  |
| Description         | Veuillez remplir tout les champs si vous souhaitez Convertir.2                                                                    | Conversion LEDS EQ127 (✅- OUI) : Adresse, Email, Téléphone, « CONFIRM- Commentaire », PRO- Raison Sociale, PRO- Numero de Siret, BAT- Surf Total Batiment, BAT- Type de Chauffage, LEDS 127- Validation Client et LEDS 127- Type Installation. |
| Message utilisateur | LEDS- Veuillez remplir tout les champs lié à votre produit si vous souhaitez Convertir.<br>+ Commentaire Confirmateur Obligatoire | Il manque des informations pour convertir ce dossier LEDS EQ127. Merci de remplir l'adresse, l'email, le téléphone, la raison sociale, le Siret, la surface et le chauffage du bâtiment, les deux champs LEDS 127 et « CONFIRM- Commentaire ».  |

#### PIS_50_CONVERSION_CHAMPS_RES060

Ancien nom : `Conversion_REMPLISSAGE_PAC060`. Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                                                                                                         | Proposé                                                                                                                                                                                                                                                           |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | Conversion_REMPLISSAGE_PAC060                                                                                                                                                                       | PIS_50_CONVERSION_CHAMPS_RES060                                                                                                                                                                                                                                   |
| Description         | Veuillez remplir tout les champs si vous souhaitez Convertir.2                                                                                                                                      | Conversion PAC RES060 (✅- OUI) : Adresse, Email, Téléphone, « CONFIRM- Commentaire », champs RES (années, Statut Occupation, Medianería, Kit Bizone), Shab de 50 à 230 m² ; PREVISITE- Nécessité = ✅- OUI ; bloqué si retour calculateur « Sans envoi visite ». |
| Message utilisateur | RES060- Veuillez remplir tout les champs lié à votre produit si vous souhaitez Convertir.<br>+ Commentaire Confirmateur Obligatoire.<br>+ La SHAB doit être 50 et 225m²<br>+ Pré-visite obligatoire | Il manque des informations pour convertir ce dossier RES060. Merci de remplir l'adresse, l'email, le téléphone, « CONFIRM- Commentaire » et les champs RES / RES060 (Shab de 50 à 230 m², prévisite sur ✅- OUI, calculateur sans « Sans envoi visite »).         |

#### PIS_50_CONVERSION_CHAMPS_RES168

Ancien nom : `Conversion_REMPLISSAGE_168`. Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                                                                                                                                                           | Proposé                                                                                                                                                                                                                                                       |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | Conversion_REMPLISSAGE_168                                                                                                                                                                                                                            | PIS_50_CONVERSION_CHAMPS_RES168                                                                                                                                                                                                                               |
| Description         | Veuillez remplir tout les champs si vous souhaitez Convertir.2                                                                                                                                                                                        | Conversion RES168 (✅- OUI) : Adresse, Email, Téléphone, « CONFIRM- Commentaire », RES- Précarité, Année de la Maison, Kit Bizone, Statut Occupation, Type de radiateur (hors ❌Fonte), Type parcours, Shab, toiture, capteurs. ✅CEE + MPR : maison +15 ans. |
| Message utilisateur | 1.TH168- Veuillez remplir tout les champs lié à votre produit si vous souhaitez Convertir.<br>2.Commentaire Confirmateur Obligatoire. + si 30% fonte alors MPR obligatoire<br>3.Si MPR alors maison obligatoirement +15ans<br>4.Prévisite obligatoire | Il manque des informations pour convertir ce dossier RES168. Merci de remplir l'adresse, l'email, le téléphone, « CONFIRM- Commentaire » et les champs RES et DEVIS du produit. Radiateurs ❌Fonte refusés ; parcours ✅CEE + MPR : maison de +15 ans.        |

#### PIS_50_CONVERSION_CHAMPS_TH108

Ancien nom : `Conversion_REMPLISSAGE_DESHUTH117`. Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                                        | Proposé                                                                                                                                                                                                                                              |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | Conversion_REMPLISSAGE_DESHUTH117                                                                                                  | PIS_50_CONVERSION_CHAMPS_TH108                                                                                                                                                                                                                       |
| Description         | Veuillez remplir tout les champs si vous souhaitez Convertir.2                                                                     | Conversion PAC TH108 (✅- OUI) : Adresse, Email, Téléphone, PRO- Raison Sociale, Nom+Prenom / Fonction / Email / Téléphone Signataire, Siret, Code APE, Siege Social Adresse, « CONFIRM- Commentaire » et « AGRI- Infos Chantier 108 » obligatoires. |
| Message utilisateur | TH108- Veuillez remplir tout les champs lié à votre produit si vous souhaitez Convertir.<br>+ Commentaire Confirmateur Obligatoire | Il manque des informations pour convertir ce dossier PAC TH108. Merci de remplir l'adresse, l'email, le téléphone, les champs PRO (raison sociale, signataire, Siret, code APE, siège), « AGRI- Infos Chantier 108 » et « CONFIRM- Commentaire ».    |

#### PIS_50_CONVERSION_CHAMPS_TH119

Ancien nom : `Conversion_REMPLISSAGE_VMCTH119`. Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                                        | Proposé                                                                                                                                                                                                                                              |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | Conversion_REMPLISSAGE_VMCTH119                                                                                                    | PIS_50_CONVERSION_CHAMPS_TH119                                                                                                                                                                                                                       |
| Description         | Veuillez remplir tout les champs si vous souhaitez Convertir.2                                                                     | Conversion VMC TH119 (✅- OUI) : Adresse, Email, Téléphone, PRO- Raison Sociale, Nom+Prenom / Fonction / Email / Téléphone Signataire, Siret, Code APE, Siege Social Adresse, « CONFIRM- Commentaire » et « AGRI- Infos Chantier 119 » obligatoires. |
| Message utilisateur | TH119- Veuillez remplir tout les champs lié à votre produit si vous souhaitez Convertir.<br>+ Commentaire Confirmateur Obligatoire | Il manque des informations pour convertir ce dossier VMC TH119. Merci de remplir l'adresse, l'email, le téléphone, les champs PRO (raison sociale, signataire, Siret, code APE, siège), « AGRI- Infos Chantier 119 » et « CONFIRM- Commentaire ».    |

#### PIS_50_CONVERSION_CHAMPS_TH142

Ancien nom : `Conversion_REMPLISSAGE_DESTRATTH142`. Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                                        | Proposé                                                                                                                                                                                                                                                      |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Nom                 | Conversion_REMPLISSAGE_DESTRATTH142                                                                                                | PIS_50_CONVERSION_CHAMPS_TH142                                                                                                                                                                                                                               |
| Description         | Veuillez remplir tout les champs si vous souhaitez Convertir                                                                       | Conversion DESTRAT TH142 (✅- OUI) : Adresse, Email, Téléphone, « CONFIRM- Commentaire », champs PRO (Raison Sociale, Signataire, Siret, APE, Siege Social), BAT- Surf Total Batiment, Type de Chauffage, Puissance Chauffage(KW) ; Hauteur Minimum = 🟩+5m. |
| Message utilisateur | TH142- Veuillez remplir tout les champs lié à votre produit si vous souhaitez Convertir.<br>+ Commentaire Confirmateur Obligatoire | Il manque des informations pour convertir ce dossier DESTRAT TH142. Merci de remplir l'adresse, l'email, le téléphone, les champs PRO et BAT, la puissance de chauffage et « CONFIRM- Commentaire ». La hauteur minimum doit être 🟩+5m.                     |

#### PIS_50_CONVERSION_CHAMPS_TH163

Ancien nom : `Conversion_REMPLISSAGE_PACTH163`. Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                                        | Proposé                                                                                                                                                                                                                                                       |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | Conversion_REMPLISSAGE_PACTH163                                                                                                    | PIS_50_CONVERSION_CHAMPS_TH163                                                                                                                                                                                                                                |
| Description         | Veuillez remplir tout les champs si vous souhaitez Convertir.2                                                                     | Conversion PAC TH163 (✅- OUI) : Adresse, Email, Téléphone, champs PRO (Raison Sociale, Signataire, Siret, Code APE, Siege Social), « CONFIRM- Commentaire », BAT- Surf Total Batiment, BAT- Type de Chauffage et « PAC 163- Surf Chauffé PAC » obligatoires. |
| Message utilisateur | TH163- Veuillez remplir tout les champs lié à votre produit si vous souhaitez Convertir.<br>+ Commentaire Confirmateur Obligatoire | Il manque des informations pour convertir ce dossier TH163. Merci de remplir l'adresse, l'email, le téléphone, les champs PRO et BAT, « PAC 163- Surf Chauffé PAC » et « CONFIRM- Commentaire ».                                                              |

#### PIS_50_CONVERSION_CHAMPS_TH171

Ancien nom : `Conversion_REMPLISSAGE_PAC171`. Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                                                                                      | Proposé                                                                                                                                                                                                                                     |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | Conversion_REMPLISSAGE_PAC171                                                                                                                                                    | PIS_50_CONVERSION_CHAMPS_TH171                                                                                                                                                                                                              |
| Description         | Veuillez remplir tout les champs si vous souhaitez Convertir.2                                                                                                                   | Conversion PAC TH171 (✅- OUI) : Adresse, Email, Téléphone, « CONFIRM- Commentaire », RES- Précarité, RES- Kit Bizone, RES- Statut Occupation, RES- Shab (70 m² minimum) obligatoires ; « RES- Année de la Maison » = 🟩Plus de 15 ans.     |
| Message utilisateur | TH171- Veuillez remplir tout les champs lié à votre produit si vous souhaitez Convertir.<br>+ Commentaire Confirmateur Obligatoire.<br>La SHAB ne doit pas etre inferieur a 70m² | Il manque des informations pour convertir ce dossier TH171. Merci de remplir l'adresse, l'email, le téléphone, « CONFIRM- Commentaire », la précarité, le kit bizone, le statut d'occupation et la Shab (70 m² minimum). Maison de +15 ans. |

#### PIS_50_CONVERSION_CHAMPS_TH174

Ancien nom : `Conversion_REMPLISSAGE_RENO_174`. Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                                   | Proposé                                                                                                                                                                                                                             |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | Conversion_REMPLISSAGE_RENO_174                                                                                               | PIS_50_CONVERSION_CHAMPS_TH174                                                                                                                                                                                                      |
| Description         | Veuillez remplir tout les champs si vous souhaitez Convertir.2                                                                | Conversion RENO TH174 (✅- OUI) : Adresse, Email, Téléphone, « CONFIRM- Commentaire », RES- Précarité, RES- Statut Occupation, « RENO 174- Travaux » et RES- Shab obligatoires ; « RES- Année de la Maison » = 🟩Plus de 15 ans.    |
| Message utilisateur | TH174- Veuillez remplir tout les champs lié à la TH174 si vous souhaitez Convertir.<br>+ Commentaire Confirmateur Obligatoire | Il manque des informations pour convertir ce dossier TH174. Merci de remplir l'adresse, l'email, le téléphone, « CONFIRM- Commentaire », la précarité, le statut d'occupation, « RENO 174- Travaux » et la Shab. Maison de +15 ans. |

#### PIS_50_CONVERSION_CHAMPS_TH179

Ancien nom : `Conversion_REMPLISSAGE_RENO_179`. Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                                                                                                                                                | Proposé                                                                                                                                                                                                                                                  |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | Conversion_REMPLISSAGE_RENO_179                                                                                                                                                                                                            | PIS_50_CONVERSION_CHAMPS_TH179                                                                                                                                                                                                                           |
| Description         | Veuillez remplir tout les champs si vous souhaitez Convertir.2                                                                                                                                                                             | Conversion PAC TH179 (✅- OUI) : Adresse, Email, Téléphone, champs PRO, « CONFIRM- Commentaire », BAT- Type de Chauffage, Surf Total Batiment et tous les champs PAC 179. Toujours : Surf Chauffé PAC 163 remplie si Presence 163 = ✅- OUI, vide sinon. |
| Message utilisateur | 1.TH179- Veuillez remplir tout les champs lié à la votre produit si vous souhaitez Convertir.<br>+ Commentaire Confirmateur Obligatoire.<br>2.Si Présence 163, remplir le champs de surface, si sans présence de 163 alors le laisser vide | Il manque des informations pour convertir ce dossier TH179. Merci de remplir l'adresse, l'email, le téléphone, les champs PRO, BAT et PAC 179 et « CONFIRM- Commentaire ». Surface PAC 163 : seulement si « Presence 163 » = ✅- OUI.                    |

#### PIS_50_CONVERSION_CODE_POSTAL

Ancien nom : `Code_Postal_Obligatoire_Pour_conversion`. Message affiché en haut de la page.

|                     | Aujourd'hui                                      | Proposé                                                                                                                  |
| ------------------- | ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------ |
| Nom                 | Code_Postal_Obligatoire_Pour_conversion          | PIS_50_CONVERSION_CODE_POSTAL                                                                                            |
| Description         | _(vide)_                                         | Conversion de la piste en dossier : le code postal de l'adresse doit être rempli et composé de 5 chiffres.               |
| Message utilisateur | Veuillez remplir le code postal avant conversion | Le code postal est manquant ou incorrect. Merci de saisir un code postal à 5 chiffres dans l'adresse avant de convertir. |

#### PIS_50_CONVERSION_NOM_CAMPAGNE — règle inactive

Ancien nom : `REMPLIR_NOM_CAMPAGNE`. Message affiché sous le champ « Nom de Campagne ».

|                     | Aujourd'hui                                           | Proposé                                                                                                                 |
| ------------------- | ----------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| Nom                 | REMPLIR_NOM_CAMPAGNE                                  | PIS_50_CONVERSION_NOM_CAMPAGNE                                                                                          |
| Description         | Merci de remplir le nom de la campagne pour convertir | Conversion : si « LOOKUP- Telepro » est rempli, « Nom de Campagne » est obligatoire.                                    |
| Message utilisateur | Merci de remplir le nom de la campagne pour convertir | La piste vient d'un télépro, la campagne est donc obligatoire. Merci de remplir « Nom de Campagne » avant de convertir. |

#### PIS_50_CONVERSION_PAS_DE_MELANGE

Ancien nom : `Conversion_VerificationMELANGE`. Message affiché en haut de la page.

|                     | Aujourd'hui                                             | Proposé                                                                                                                                                                                             |
| ------------------- | ------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | Conversion_VerificationMELANGE                          | PIS_50_CONVERSION_PAS_DE_MELANGE                                                                                                                                                                    |
| Description         | Vous ne pouvez pas mélanger PRO/RESIDENTIE/AGRICULTURE. | Interdit de mélanger les familles sur une piste : tertiaire (PAC TH163, PAC TH179, DESTRAT TH142), résidentiel (PAC TH171, RES168, PAC RES060, RENO TH174) et agriculture (PAC TH108, TUBES EQ108). |
| Message utilisateur | Vous ne pouvez pas mélanger PRO/RESIDENTIE/AGRICULTURE. | Une fiche ne peut contenir qu'une seule famille de produits (tertiaire, résidentiel ou agriculture). Merci de garder les champs « Création Dossier » d'une seule famille.                           |

#### PIS_50_CONVERSION_PAS_TELEPRO

Ancien nom : `TELEPRO_NE_PEUVENT_PAS_CONVERTIR`. Message affiché en haut de la page.

|                     | Aujourd'hui                               | Proposé                                                                                                        |
| ------------------- | ----------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| Nom                 | TELEPRO_NE_PEUVENT_PAS_CONVERTIR          | PIS_50_CONVERSION_PAS_TELEPRO                                                                                  |
| Description         | LE CONFIRMATEUR uniquement peut convertir | Les profils Télépro Data et Télépro Leads ne peuvent pas convertir une piste : seul le confirmateur convertit. |
| Message utilisateur | LE CONFIRMATEUR uniquement peut convertir | Seul le confirmateur peut convertir une piste. Merci de lui envoyer la fiche en confirmation.                  |

#### PIS_50_CONVERSION_PROPRIETAIRE

Ancien nom : `Owner_diffrent_de_logged_in_user`. Message affiché en haut de la page.

|                     | Aujourd'hui                                          | Proposé                                                                                                                                                                                                     |
| ------------------- | ---------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | Owner_diffrent_de_logged_in_user                     | PIS_50_CONVERSION_PROPRIETAIRE                                                                                                                                                                              |
| Description         | Veuillez modifier le propriétaire avant de convertir | Conversion hors 🟩BAR RES-060 PAC : l'utilisateur qui convertit doit être à la fois le propriétaire de la piste et la personne du « LOOKUP- Confirmateur ». Exception : le compte administrateur principal. |
| Message utilisateur | Veuillez modifier le propriétaire avant de convertir | Conversion impossible : vous devez être propriétaire de la piste et figurer dans « LOOKUP- Confirmateur ». Merci de modifier le propriétaire avant de convertir.                                            |

#### PIS_50_CONVERSION_PROPRIETAIRE_V3

Ancien nom : `Convertir_au_nom_du_proprietaire`. Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                             | Proposé                                                                                                                                                                    |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | Convertir_au_nom_du_proprietaire                                                                                        | PIS_50_CONVERSION_PROPRIETAIRE_V3                                                                                                                                          |
| Description         | Vous ne pouvez pas convertir l'enregistrement, veuillez vérifier que le "Telepro" est le propriétaire de la piste.      | « Type de Dossier v3 » = 🟩RES- TH171- PAC, 🟨DATA ou TH 174 : au passage en Qualifié, le propriétaire de la piste doit être la personne du « LOOKUP- Confirmateur ».      |
| Message utilisateur | Vous ne pouvez pas convertir l'enregistrement, veuillez vérifier que le "Confirmateur" est le propriétaire de la piste. | Conversion impossible : le propriétaire de la piste doit être le confirmateur indiqué dans « LOOKUP- Confirmateur ». Merci de modifier le propriétaire avant de convertir. |

#### PIS_50_CONVERSION_RESIDENTIEL_FICHES — règle inactive

Ancien nom : `Conversion_VerificationRESIDENTIEL`. Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                 | Proposé                                                                                                                                                           |
| ------------------- | ----------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | Conversion_VerificationRESIDENTIEL                                                                          | PIS_50_CONVERSION_RESIDENTIEL_FICHES                                                                                                                              |
| Description         | _(vide)_                                                                                                    | RÉSIDENTIEL : « PAC TH171- Création Dossier » et « PAC RES060- Création Dossier » doivent être remplis ensemble et ne peuvent pas être tous les deux sur ❌- NON. |
| Message utilisateur | RESIDENTIEL<br>Vous avez au moins un champs de produit qui est vide,<br>Ou vous avez tout les champs en NON | Les deux fiches RÉSIDENTIEL vont ensemble. Merci de remplir « PAC TH171- Création Dossier » et « PAC RES060- Création Dossier », avec au moins un ✅- OUI.        |

#### PIS_50_CONVERSION_STATUT_RESERVE

Ancien nom : `SECURITE_PROFIL`. Message affiché sous le champ « Status ».

|                     | Aujourd'hui                                  | Proposé                                                                                                                  |
| ------------------- | -------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| Nom                 | SECURITE_PROFIL                              | PIS_50_CONVERSION_STATUT_RESERVE                                                                                         |
| Description         | Vous ne pouvez pas modifier ce champs merci. | Le profil Confirmateur ne peut pas mettre lui-même le statut de la piste sur Qualifié ou Non qualifié (hors conversion). |
| Message utilisateur | Vous ne pouvez pas modifier ce champs merci. | Vous ne pouvez pas mettre vous-même la piste en Qualifié ou Non qualifié. Merci de passer par la conversion.             |

#### PIS_50_CONVERSION_TERTIAIRE_UN_SEUL

Ancien nom : `Conversion_VerificationTERTIAIRE`. Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                                                                             | Proposé                                                                                                                                                                                |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | Conversion_VerificationTERTIAIRE                                                                                                                                        | PIS_50_CONVERSION_TERTIAIRE_UN_SEUL                                                                                                                                                    |
| Description         | _(vide)_                                                                                                                                                                | TERTIAIRE : si l'un des champs « Création Dossier » PAC TH163, PAC TH179 ou DESTRAT TH142 est rempli, les trois doivent l'être ; pas tous sur ❌- NON ; un seul sur ✅- OUI par piste. |
| Message utilisateur | TERTIAIRE<br>1.Vous avez au moins un champs de produit qui est vide,<br>2.Ou vous avez tout les champs en NON<br>2. Vous pouvez avoir qu'un produit à la fois par fiche | Fiche tertiaire : merci de remplir les trois champs « Création Dossier » (PAC TH163, PAC TH179, DESTRAT TH142), avec un seul ✅- OUI par fiche.                                        |

#### PIS_50_CONVERSION_TYPE_DOSSIER_V3 — règle inactive

Ancien nom : `Type_de_dossier_rempli_pour_convertir`. Message affiché en haut de la page.

|                     | Aujourd'hui                                                   | Proposé                                                                                                            |
| ------------------- | ------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| Nom                 | Type_de_dossier_rempli_pour_convertir                         | PIS_50_CONVERSION_TYPE_DOSSIER_V3                                                                                  |
| Description         | Il est obligatoire d'avoir un type de dossier pour convertir. | « Type de Dossier v3 » obligatoire pour passer la piste en Qualifié.                                               |
| Message utilisateur | Il est obligatoire d'avoir un type de dossier pour convertir. | Le type de dossier n'est pas choisi. Merci de remplir « Type de Dossier v3 » avant de passer la piste en Qualifié. |

#### PIS_50_CONVERSION_UN_PRODUIT_MINI

Ancien nom : `Conversion_REMPLISSAGE_unproduitminimum`. Message affiché en haut de la page.

|                     | Aujourd'hui                                 | Proposé                                                                                                                 |
| ------------------- | ------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| Nom                 | Conversion_REMPLISSAGE_unproduitminimum     | PIS_50_CONVERSION_UN_PRODUIT_MINI                                                                                       |
| Description         | Il faut au moins un produit pour convertir  | Passage de la piste en Qualifié (conversion) : au moins un des 12 champs « … - Création Dossier » doit être rempli.     |
| Message utilisateur | Il faut au moins un produit pour convertir. | Aucun produit n'est sélectionné. Merci de mettre au moins un champ « Création Dossier » sur ✅- OUI avant de convertir. |

### Étape 90 — Contrôles de saisie

#### PIS_90_CONTROLE_ANNEE_CHAUDIERE

Ancien nom : `format_annee`. Message affiché sous le champ « RES- Année Chaudière ».

|                     | Aujourd'hui                                                 | Proposé                                                                                          |
| ------------------- | ----------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| Nom                 | format_annee                                                | PIS_90_CONTROLE_ANNEE_CHAUDIERE                                                                  |
| Description         | L'année doit être au format 4 chiffres (ex : 1980 ou 2000). | « RES- Année Chaudière » : si le champ est rempli, 4 chiffres entre 1700 et 2099.                |
| Message utilisateur | L'année doit être au format 4 chiffres (ex : 1980 ou 2000). | L'année de la chaudière n'est pas valide. Merci de la saisir sur 4 chiffres (ex : 1980 ou 2000). |

#### PIS_90_CONTROLE_ANNEE_MAISON

Ancien nom : `format_annee2`. Message affiché sous le champ « RES- Anneé maison(ES) ».

|                     | Aujourd'hui                                                 | Proposé                                                                                       |
| ------------------- | ----------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| Nom                 | format_annee2                                               | PIS_90_CONTROLE_ANNEE_MAISON                                                                  |
| Description         | L'année doit être au format 4 chiffres (ex : 1980 ou 2000). | « RES- Anneé maison(ES) » : si le champ est rempli, 4 chiffres entre 1700 et 2099.            |
| Message utilisateur | L'année doit être au format 4 chiffres (ex : 1980 ou 2000). | L'année de la maison n'est pas valide. Merci de la saisir sur 4 chiffres (ex : 1980 ou 2000). |

#### PIS_90_CONTROLE_ANTI_VIDE_BD

Ancien nom : `BASEDONNEES_SOUS_STATUT_NULL`. Message affiché en haut de la page.

|                     | Aujourd'hui                                  | Proposé                                                                                                                                 |
| ------------------- | -------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | BASEDONNEES_SOUS_STATUT_NULL                 | PIS_90_CONTROLE_ANTI_VIDE_BD                                                                                                            |
| Description         | Le statut de traitement ne peut pas etre nul | Anti-vidage : une fois remplis, « BD.ITE- Sous Statut », « BD.RENO- Statut » et « MPR*DOCS » ne peuvent plus être remis à vide.         |
| Message utilisateur | Le statut de traitement ne peut pas etre nul | Ce statut ne peut pas être remis à vide. Merci de choisir une valeur dans « BD.ITE- Sous Statut », « BD.RENO- Statut » ou « MPR*DOCS ». |

#### PIS_90_CONTROLE_ANTI_VIDE_LEADS — règle inactive

Ancien nom : `LEAD_SOUS_STATUT_NULL`. Message affiché sous le champ « LEADS- Statut ».

|                     | Aujourd'hui                             | Proposé                                                                                                         |
| ------------------- | --------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| Nom                 | LEAD_SOUS_STATUT_NULL                   | PIS_90_CONTROLE_ANTI_VIDE_LEADS                                                                                 |
| Description         | Le statut du LEAD ne peut pas etre nul  | Anti-vidage : « LEADS- Statut » ne peut pas être remis à vide une fois rempli, sauf par le profil Confirmateur. |
| Message utilisateur | Le statut du LEAD ne peut pas etre nul. | « LEADS- Statut » ne peut pas être remis à vide une fois rempli. Merci de choisir une valeur.                   |

#### PIS_90_CONTROLE_ANTI_VIDE_LISTES

Ancien nom : `TYPE_DE_DOSSIESTATUT_NULL`. Message affiché en haut de la page.

|                     | Aujourd'hui                                  | Proposé                                                                                                                                                                                                                       |
| ------------------- | -------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | TYPE_DE_DOSSIESTATUT_NULL                    | PIS_90_CONTROLE_ANTI_VIDE_LISTES                                                                                                                                                                                              |
| Description         | Le statut de traitement ne peut pas etre nul | Anti-vidage : Type de Dossier v3, VELO CARGO- TELEPRO, CONFIRM- Traitement, RES- Précarité, TYPE DE DOSSIER, RES- Kit Bizone, PREVISITE- Nécessité, PREVISITE- Statut et PREVISITE- Nom Sté ne peuvent pas être remis à vide. |
| Message utilisateur | Le statut de traitement ne peut pas etre nul | Ce champ ne peut pas être remis à vide une fois rempli. Merci de choisir une valeur.                                                                                                                                          |

#### PIS_90_CONTROLE_ANTI_VIDE_REGIE

Ancien nom : `REGIE_SOUS_STATUT_NULL`. Message affiché sous le champ « REGIE- Sous Statut ».

|                     | Aujourd'hui                                  | Proposé                                                                             |
| ------------------- | -------------------------------------------- | ----------------------------------------------------------------------------------- |
| Nom                 | REGIE_SOUS_STATUT_NULL                       | PIS_90_CONTROLE_ANTI_VIDE_REGIE                                                     |
| Description         | Le statut de traitement ne peut pas etre nul | Anti-vidage : « REGIE- Sous Statut » ne peut pas être remis à vide une fois rempli. |
| Message utilisateur | Le statut de traitement ne peut pas etre nul | « REGIE- Sous Statut » ne peut pas être remis à vide. Merci de choisir une valeur.  |

#### PIS_90_CONTROLE_MONTANT_RAC — règle inactive

Ancien nom : `MPR_RAC`. Message affiché sous le champ « MPR*Montant RAC ».

|                     | Aujourd'hui                                                     | Proposé                                                                                                           |
| ------------------- | --------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| Nom                 | MPR_RAC                                                         | PIS_90_CONTROLE_MONTANT_RAC                                                                                       |
| Description         | Si autre que bleu merci de remplir le montant du reste a charge | « RES- Précarité » = 🟨Jaune/Modeste, 🟪Violet/ Classique ou 🟥Rose/ Classique : « MPR*Montant RAC » obligatoire. |
| Message utilisateur | Si autre que bleu merci de remplir le montant du reste a charge | Pour ce niveau de précarité, le reste à charge est obligatoire. Merci de remplir « MPR*Montant RAC ».             |

## Dossiers — détail

### Étape 10 — Documents

#### DOS_10_DOCS_CEE_COMPLET

Ancien nom : `SECRETARIAT_DOC_COMPLET`. Message affiché sous le champ « DOCS- CEE ».

|                     | Aujourd'hui                                                                        | Proposé                                                                                                                             |
| ------------------- | ---------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | SECRETARIAT_DOC_COMPLET                                                            | DOS_10_DOCS_CEE_COMPLET                                                                                                             |
| Description         | Vous ne pouvez pas sélectionner le statut "Dossier Complet" avec d'autres valeurs. | « DOCS- CEE » : 🟩Dossier Complet ne peut pas être coché en même temps qu'un manquant (🟨Mq KBIS, 🟨Mq Sheets, 🟨Mq Geoportail).    |
| Message utilisateur | Vous ne pouvez pas sélectionner le statut "Dossier Complet" avec d'autres valeurs. | Le dossier ne peut pas être complet s'il manque un document. Merci de décocher 🟩Dossier Complet ou les documents manquants (🟨Mq). |

#### DOS_10_DOCS_ES_COMPLET

Ancien nom : `docs_es_docs_complet`. Message affiché sous le champ « DOCS ES- Statut ».

|                     | Aujourd'hui                                                                           | Proposé                                                                                                                               |
| ------------------- | ------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | docs_es_docs_complet                                                                  | DOS_10_DOCS_ES_COMPLET                                                                                                                |
| Description         | Vous ne pouvez pas sélectionner le statut Validé- Docs Complet avec d'autres valeurs. | « DOCS ES- Statut » : ✅Validé- Docs Complet ne peut pas être coché avec ☑️Validé- Docs Incomplet, ni avec un 🟨Mq ou une 🟨Anomalie. |
| Message utilisateur | Vous ne pouvez pas sélectionner le statut Validé- Docs Complet avec d'autres valeurs. | ✅Validé- Docs Complet ne peut pas être coché avec un autre choix. Merci de décocher les autres valeurs de « DOCS ES- Statut ».       |

#### DOS_10_DOCS_ES_INCOMPLET

Ancien nom : `docs_es_docs_incomplet`. Message affiché sous le champ « DOCS ES- Statut ».

|                     | Aujourd'hui                                                                                                             | Proposé                                                                                                                                                                                                |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Nom                 | docs_es_docs_incomplet                                                                                                  | DOS_10_DOCS_ES_INCOMPLET                                                                                                                                                                               |
| Description         | Si vous selectionnez "Validé- Docs Incomplet", il faut que vous sélectionnez aussi l'incomplet (photo, plaque ou autre) | « DOCS ES- Statut » : ☑️Validé- Docs Incomplet exige de cocher aussi au moins un manquant (🟨Mq Photos, 🟨Mq Photo plaque signalétique, 🟨Mq Facture(s), 🟨Mq IBI/justif propriété, 🟨Anomalie Autre). |
| Message utilisateur | Si vous selectionnez Validé- Docs Incomplet, il faut que vous sélectionnez aussi l'incomplet (photo, plaque ou autre)   | Vous avez choisi ☑️Validé- Docs Incomplet. Merci de cocher aussi ce qui manque (photos, plaque signalétique, factures, IBI/justif propriété ou autre anomalie).                                        |

#### DOS_10_DOCS_ES_VALIDATION

Ancien nom : `Docs_ESvalidation`. Message affiché sous le champ « DOCS ES- Att visiteur ».

|                     | Aujourd'hui                                                                                                                                 | Proposé                                                                                                                                                                             |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | Docs_ESvalidation                                                                                                                           | DOS_10_DOCS_ES_VALIDATION                                                                                                                                                           |
| Description         | Pour mettre Validé- Docs Complet ou Validé- Docs Incomplet, il faut avoir Validé secretariat                                                | « DOCS ES- Statut » = ✅Validé- Docs Complet ou ☑️Validé- Docs Incomplet : « DOCS ES- Att visiteur » doit être 🟩Validé secretariat et « RES- Bono Social Final » doit être rempli. |
| Message utilisateur | 1.Pour mettre Validé- Docs Complet ou Validé- Docs Incomplet, il faut avoir Validé secretariat<br>2. Il faut que le bono social soit rempli | Pour valider les documents, merci de passer « DOCS ES- Att visiteur » en 🟩Validé secretariat et de remplir « RES- Bono Social Final ».                                             |

#### DOS_10_DOCS_MPR_COMPLET

Ancien nom : `PAC_Docs1`. Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                                                                                                                                                   | Proposé                                                                                                                                                                                                            |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Nom                 | PAC_Docs1                                                                                                                                                                                                                                     | DOS_10_DOCS_MPR_COMPLET                                                                                                                                                                                            |
| Description         | Vous ne pouvez pas sélectionner le statut "Dossier Complet" avec d'autres valeurs.                                                                                                                                                            | « DOCS- Statut » = 🟩Dossier Complet : aucun 🟨Mq coché en même temps ; « CLIENT- Code postal » à 5 chiffres ; « RES- Zone » connue ; en TH171 : RES- Indivision, Statut Occupation, Precarité et Shab remplis.    |
| Message utilisateur | 1.Vous ne pouvez pas sélectionner le statut "Dossier Complet" avec d'autres valeurs.<br>2.En 171, Merci de remplir précarite, shab, statut d'occupation et indivision<br>3.Votre champs code postal doit etre rempli et composé de 5 chiffres | Le dossier ne peut pas être marqué complet. Merci de décocher les documents manquants (🟨Mq), de vérifier le code postal (5 chiffres) et, en TH171, de remplir précarité, Shab, statut d'occupation et indivision. |

#### DOS_10_DOCS_RELANCE_UNE_PAR_FAMILLE

Ancien nom : `Relance`. Message affiché sous le champ « DOCS- Relance ».

|                     | Aujourd'hui                                                                                      | Proposé                                                                                                                    |
| ------------------- | ------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | Relance                                                                                          | DOS_10_DOCS_RELANCE_UNE_PAR_FAMILLE                                                                                        |
| Description         | Relance un par famille                                                                           | « DOCS- Relance » : une seule valeur par famille (Appel1 à 4, Sms1 à 3, Whtsp1 à 3, Mail1 à 3) peut être cochée à la fois. |
| Message utilisateur | Vous pouvez choisir une relance par famille.<br>Uniquement 1 de chaque type appel/sms/whtsp/mail | Une seule relance par type à la fois. Merci de ne cocher qu'un Appel, un Sms, un Whtsp et un Mail au maximum.              |

### Étape 20 — Prévisite et visite Certiko

#### DOS_20_CERTIKO_STATUT_VT_DOCS

Ancien nom : `Certiko_VT_Controle`. Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                                                     | Proposé                                                                                                                                                                                                                                    |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Nom                 | Certiko_VT_Controle                                                                                                                             | DOS_20_CERTIKO_STATUT_VT_DOCS                                                                                                                                                                                                              |
| Description         | _(vide)_                                                                                                                                        | « CERTIKO- Statut VT » ▣ Visite en att démarrage, 🟫Visite Incomplete ou 🟦Visite Complete : « DOCS ES- Statut » et « DOCS ES- Att visiteur » vides. ❌Visite Terminée- Incomplet : un manquant coché et « DOCS ES- Att visiteur » rempli. |
| Message utilisateur | + Visite (▣,🟫,🟦) : Statuts documents doivent être vides .<br>+ Visite incomplète❌: précisez les docs manquants et renseignez l’att visiteur. | Documents incohérents avec la visite. Visite ▣, 🟫 ou 🟦 : merci de laisser « DOCS ES- Statut » et « DOCS ES- Att visiteur » vides. ❌Visite Terminée- Incomplet : merci de cocher les manquants et de remplir « DOCS ES- Att visiteur ».  |

#### DOS_20_CERTIKO_STATUT_VT_RESERVE

Ancien nom : `CERTIKO_STATUT_VT_RESERVE`. Message affiché sous le champ « CERTIKO- Statut VT ».

|                     | Aujourd'hui                                                                                                                                                                                                                      | Proposé                                                                                                                                                                                                                   |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | CERTIKO_STATUT_VT_RESERVE                                                                                                                                                                                                        | DOS_20_CERTIKO_STATUT_VT_RESERVE                                                                                                                                                                                          |
| Description         | Statut VT à la main : admin tout ; Secrétaire ES terminee/incomplet/termine_valide ; autres non. Libres : invité (webhook, portail) et remises à zéro (numéro d'envoi change : pré-visiteur, rendu, déplacement). Ids de profil. | _inchangée (déjà claire)_                                                                                                                                                                                                 |
| Message utilisateur | Statut VT : la secrétaire ES ne peut choisir que Visite Complete, Terminée- Incomplet ou Terminée- Validé ; les autres valeurs (démarrage, incomplète, annulée) sont réservées à Certiko et aux administrateurs.                 | Statut VT : vous pouvez choisir uniquement 🟦Visite Complete, ❌Visite Terminée- Incomplet ou 🟩Visite Terminée- Validé. Les autres valeurs sont gérées par Certiko et les administrateurs. Merci de votre compréhension. |

#### DOS_20_CERTIKO_VT_VALIDEE_DOCS

Ancien nom : `certikovisite_termine`. Message affiché sous le champ « DOCS ES- Statut ».

|                     | Aujourd'hui                                                                                                                           | Proposé                                                                                                                                        |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | certikovisite_termine                                                                                                                 | DOS_20_CERTIKO_VT_VALIDEE_DOCS                                                                                                                 |
| Description         | Pour mettre la visite en terminé validé, il faut la prévisite Le statut docs doit être Validé- Docs Complet ou Validé- Docs Incomplet | « CERTIKO- Statut VT » = 🟩Visite Terminée- Validé : « DOCS ES- Statut » doit contenir ✅Validé- Docs Complet ou ☑️Validé- Docs Incomplet.     |
| Message utilisateur | Il faut mettre la visite en terminé validé pour pouvoir mettre: Validé- Docs Complet ou Validé- Docs Incomplet.                       | Pour mettre la visite en 🟩Visite Terminée- Validé, merci de valider aussi les documents (✅Validé- Docs Complet ou ☑️Validé- Docs Incomplet). |

#### DOS_20_PREVISITE_A_REPLANIFIER

Ancien nom : `PREVISITE5_OUI`. Message affiché sous le champ « PREVISITE- Statut ».

|                     | Aujourd'hui                                                                                                    | Proposé                                                                                                                      |
| ------------------- | -------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | PREVISITE5_OUI                                                                                                 | DOS_20_PREVISITE_A_REPLANIFIER                                                                                               |
| Description         | Pour mettre à replanifier merci d'avoir la date de prévisite vide et le statut conf du rdv en nouveau dossier. | « PREVISITE- Statut » = 🟫Passage à Replanifier : « PREVISITE- Date Passage » et « PREVISITE- Conf J-1 » doivent être vides. |
| Message utilisateur | Pour mettre à replanifier merci d'avoir la date de prévisite vide et le statut conf du rdv en nouveau dossier. | Pour mettre 🟫Passage à Replanifier, merci de vider la date de passage et « PREVISITE- Conf J-1 ».                           |

#### DOS_20_PREVISITE_ANNULE_PLANIFIE — règle inactive

Ancien nom : `PREVISITE7_OUI`. Message affiché sous le champ « PREVISITE- Statut ».

|                     | Aujourd'hui                                                                                                                                                        | Proposé                                                                                                                                                                    |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | PREVISITE7_OUI                                                                                                                                                     | DOS_20_PREVISITE_ANNULE_PLANIFIE                                                                                                                                           |
| Description         | Pour mettre le passage en effectué merci d'avoir le nom la société de prévisite,la date d'envoi et la date de passage.                                             | « RDV- Statut Dossier » = ⚫DOSSIER- Annulé alors que « PREVISITE- Statut » = 🟧Passage Planifié : bloqué, il faut prévenir le pré-visiteur et remettre 🟨Passage Demandé. |
| Message utilisateur | Si vous mettez en annulé et que la prévisite est planifié, merci de prévenir le previsiteur pur qu'il annula previsite et de remettre la visite en passage demandé | Le dossier est annulé mais la prévisite est encore planifiée. Merci de prévenir le pré-visiteur, puis de remettre « PREVISITE- Statut » sur 🟨Passage Demandé.             |

#### DOS_20_PREVISITE_DEMANDE

Ancien nom : `PREVISITE3_OUI`. Message affiché sous le champ « PREVISITE- Statut ».

|                     | Aujourd'hui                                                                                                                          | Proposé                                                                                                                 |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------- |
| Nom                 | PREVISITE3_OUI                                                                                                                       | DOS_20_PREVISITE_DEMANDE                                                                                                |
| Description         | Pour mettre en previsite passage demandé, merci de remplir le nom de la société, la date d'envoi et d'avoir une date de passage vide | « PREVISITE- Statut » = 🟨Passage Demandé : « PREVISITE- Date Passage » doit être vide.                                 |
| Message utilisateur | Pour mettre en previsite passage demandé, merci de remplir le nom de la société, la date d'envoi et d'avoir une date de passage vide | Pour mettre 🟨Passage Demandé, merci de laisser la date de passage vide (elle se remplit une fois le passage planifié). |

#### DOS_20_PREVISITE_EFFECTUE

Ancien nom : `PREVISITE6_OUI`. Message affiché sous le champ « PREVISITE- Statut ».

|                     | Aujourd'hui                                                                                                                                                                                                                                          | Proposé                                                                                                                                                                                                                  |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Nom                 | PREVISITE6_OUI                                                                                                                                                                                                                                       | DOS_20_PREVISITE_EFFECTUE                                                                                                                                                                                                |
| Description         | Pour mettre le passage en effectué merci d'avoir le nom la société de prévisite,la date d'envoi et la date de passage.                                                                                                                               | « PREVISITE- Statut » = 🟩Passage Effectué : LOOKUP- Pré-visiteur et PREVISITE- Date Passage ; en TH171 / TH174, PREVISITE- Date d'Envoi et Type VT finale aussi, « AUDIT- Nécéssité » = ❌- NON en 171, ✅- OUI en 174. |
| Message utilisateur | 1.Pour mettre le passage en effectué, remplir nom previsiteure, date d'envoi, date de passage, type vt finale et de mettre si nécessité audit ou non<br>2.Si 171, Mettre Nécessité Audit en ''NON''<br>3.2.Si 174, Mettre Nécessité Audit en ''OUI'' | Pour mettre 🟩Passage Effectué, merci de remplir le pré-visiteur, la date d'envoi, la date de passage, le type de VT finale et la nécessité d'audit (❌- NON en TH171, ✅- OUI en TH174).                                |

#### DOS_20_PREVISITE_NON

Ancien nom : `PREVISITE1_NON`. Message affiché sous le champ « PREVISITE- Nécessité ».

|                     | Aujourd'hui                                                                                                                                             | Proposé                                                                                                                                                                          |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | PREVISITE1_NON                                                                                                                                          | DOS_20_PREVISITE_NON                                                                                                                                                             |
| Description         | On ne peut pas modifier les champs PREVISITE/AUDIT si il n'y en a pas.                                                                                  | « PREVISITE- Nécessité » = ❌- NON : « LOOKUP- Pré-visiteur » vide, « PREVISITE- Statut » = ▣ Nouveau Dossier, « PREVISITE- Date Passage » et « PREVISITE- Date d'Envoi » vides. |
| Message utilisateur | Si Previsite egale non, nom de societe en Nouveau dossier, Statut previsite en att planification, date de previsite et date d'envoi doivent etre vides. | La prévisite est sur ❌- NON. Merci de laisser le statut sur ▣ Nouveau Dossier et de vider le pré-visiteur, la date d'envoi et la date de passage.                               |

#### DOS_20_PREVISITE_NOUVEAU_DOSSIER

Ancien nom : `PREVISITE2_OUI`. Message affiché sous le champ « PREVISITE- Statut ».

|                     | Aujourd'hui                                                                                                                                                                           | Proposé                                                                                                                                              |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | PREVISITE2_OUI                                                                                                                                                                        | DOS_20_PREVISITE_NOUVEAU_DOSSIER                                                                                                                     |
| Description         | Merci d'enlever le nom de la société de prévisite, la date d'envoi et la date de passage de la société de prévisite si vous souhaitez que le statut previsite soit en Nouveau Dossier | « PREVISITE- Statut » = ▣ Nouveau Dossier : « LOOKUP- Pré-visiteur », « PREVISITE- Date d'Envoi » et « PREVISITE- Date Passage » doivent être vides. |
| Message utilisateur | Merci d'enlever le nom de la société de prévisite, la date d'envoi et la date de passage de la société de prévisite si vous souhaitez que le statut previsite soit en Nouveau Dossier | Pour remettre la prévisite en ▣ Nouveau Dossier, merci de vider le pré-visiteur, la date d'envoi et la date de passage.                              |

#### DOS_20_PREVISITE_PLANIFIE

Ancien nom : `PREVISITE4_OUI`. Message affiché sous le champ « PREVISITE- Statut ».

|                     | Aujourd'hui                                                                                                            | Proposé                                                                                                            |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| Nom                 | PREVISITE4_OUI                                                                                                         | DOS_20_PREVISITE_PLANIFIE                                                                                          |
| Description         | Pour mettre le passage en planifié merci d'avoir le nom la société de prévisite,la date d'envoi et la date de passage. | « PREVISITE- Statut » = 🟧Passage Planifié : « LOOKUP- Pré-visiteur » et « PREVISITE- Date Passage » obligatoires. |
| Message utilisateur | Pour mettre le passage en planifié merci d'avoir le nom la société de prévisite,la date d'envoi et la date de passage. | Pour mettre 🟧Passage Planifié, merci de choisir le pré-visiteur et d'indiquer la date de passage.                 |

#### DOS_20_PREVISITE_PORTE_SANS_RETOUR

Ancien nom : `PREVISITE_PORTE_PAS_DE_RETOUR`. Message affiché sous le champ « PREVISITE- Porte ».

|                     | Aujourd'hui                                                                                                                                                                                                                                            | Proposé                                                                                                                                                                                        |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | PREVISITE_PORTE_PAS_DE_RETOUR                                                                                                                                                                                                                          | DOS_20_PREVISITE_PORTE_SANS_RETOUR                                                                                                                                                             |
| Description         | Empêche tout retour en arrière sur « PREVISITE- Porte » : une fois Porte 1 atteinte on ne peut plus vider le champ, une fois Porte 2 atteinte on ne peut plus revenir à Porte 1 ni vider. La progression (vide -> Porte 1 -> Porte 2) reste autorisée. | _inchangée (déjà claire)_                                                                                                                                                                      |
| Message utilisateur | Retour en arrière interdit sur « PREVISITE- Porte » : une fois Porte 1 atteinte vous ne pouvez plus vider le champ, et une fois Porte 2 atteinte vous ne pouvez plus revenir à Porte 1 ni le vider.                                                    | Retour en arrière impossible sur « PREVISITE- Porte » : après Porte 1, le champ ne peut plus être vidé ; après Porte 2, il ne peut plus revenir à Porte 1. Merci de garder la valeur actuelle. |

#### DOS_20_PREVISITE_PREVISITEUR_VERROU

Ancien nom : `PREVISITEUR_VISITE_DEMARREE`. Message affiché sous le champ « LOOKUP- Pré-visiteur ».

|                     | Aujourd'hui                                                                                                                                                                                                                        | Proposé                                                                                                                           |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | PREVISITEUR_VISITE_DEMARREE                                                                                                                                                                                                        | DOS_20_PREVISITE_PREVISITEUR_VERROU                                                                                               |
| Description         | Pré-visiteur modifiable par tous seulement si le statut VT d'avant valait planifie ou vide ; au-delà, profil Administrateur système seul (repéré par Id). PRIORVALUE : la réattribution remet le statut à planifie avant la règle. | _inchangée (déjà claire)_                                                                                                         |
| Message utilisateur | Visite déjà démarrée chez Certiko : seul un administrateur peut changer ou enlever le pré-visiteur (permis seulement en « ▣ Visite en att démarrage »).                                                                            | La visite a déjà démarré chez Certiko : le pré-visiteur ne peut plus être changé. Merci de contacter un administrateur si besoin. |

#### DOS_20_PREVISITE_RETOUR_DOCS_VERROU — règle inactive

Ancien nom : `DOCS_PREVISITE`. Message affiché sous le champ « PREVISITE- Retour Docs ».

|                     | Aujourd'hui                                               | Proposé                                                                                                                                                          |
| ------------------- | --------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | DOCS_PREVISITE                                            | DOS_20_PREVISITE_RETOUR_DOCS_VERROU                                                                                                                              |
| Description         | Docs previsite modifiable que par la reponsable previsite | « PREVISITE- Retour Docs » modifiable uniquement par la responsable prévisite et le compte administrateur principal (repérés par leur identifiant de connexion). |
| Message utilisateur | Docs previsite modifiable que par la reponsable previsite | « PREVISITE- Retour Docs » est réservé à la responsable prévisite. Merci de lui demander la modification.                                                        |

#### DOS_20_PREVISITE_TH174_OBLIGATOIRE — règle inactive

Ancien nom : `AUDIT_2`. Message affiché sous le champ « PREVISITE- Nécessité ».

|                     | Aujourd'hui                                                             | Proposé                                                                                                                                      |
| ------------------- | ----------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | AUDIT_2                                                                 | DOS_20_PREVISITE_TH174_OBLIGATOIRE                                                                                                           |
| Description         | Si vous avez un dossier 174 alors il faut obligatoirement une previsite | Fiche 🟩BAR TH174- Réno Globale avec « RDV- Statut Dossier » = 🔵DOSSIER- Attente Installation : « PREVISITE- Nécessité » doit être ✅- OUI. |
| Message utilisateur | Si vous avez un dossier 174 alors il faut obligatoirement une previsite | Un dossier TH174 exige une prévisite avant l'installation. Merci de mettre « PREVISITE- Nécessité » sur ✅- OUI.                             |

#### DOS_20_PREVISITE_TYPE_VT

Ancien nom : `PREVISITE10`. Message affiché sous le champ « AUDIT- Statut ».

|                     | Aujourd'hui                                                                                                                                                                         | Proposé                                                                                                                                                                                                                        |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Nom                 | PREVISITE10                                                                                                                                                                         | DOS_20_PREVISITE_TYPE_VT                                                                                                                                                                                                       |
| Description         | Si 171 seule on ne peut pas envoyer en audit                                                                                                                                        | TH171 seule non installée : 🟨Audit- Demandé interdit. Dès « PREVISITE- Date d'Envoi » : « PREVISITE- Type VT » obligatoire, 🟩TH171 pour une 171 seule, 🟩TH174 pour 174 ou 171+174. Type VT = « PREVISITE- Type VT finale ». |
| Message utilisateur | 1.Si 171 seule on ne peut pas envoyer en audit.<br>2. Si 171 seule Type VT171<br>3. Si 174 seule Type VT174<br>4. Si 171+174 Type VT174<br>5. Type vt ne correspond pas a VT finale | Type de visite à revoir. Merci de choisir 🟩TH171 pour une 171 seule et 🟩TH174 pour une 174 ou 171+174, avec le même type en VT finale. Une 171 seule ne part pas en audit.                                                   |

### Étape 30 — Audit et COFRAC

#### DOS_30_AUDIT_APRES_PREVISITE

Ancien nom : `AUDIT_1`. Message affiché sous le champ « AUDIT- Nécéssité ».

|                     | Aujourd'hui                                                                                                  | Proposé                                                                                                                                                              |
| ------------------- | ------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | AUDIT_1                                                                                                      | DOS_30_AUDIT_APRES_PREVISITE                                                                                                                                         |
| Description         | Vous ne pouvez pas statuer la partie audit si la previsite n'est pas effectué ou bien sans previsite         | « AUDIT- Nécéssité » (✅- OUI ou ❌- NON) ne peut être renseigné que si « PREVISITE- Nécessité » = ❌- NON ou si « PREVISITE- Statut » = 🟩Passage Effectué.         |
| Message utilisateur | Vous ne pouvez pas statuer la partie audit si la previsite n'est pas effectué ou la previsite non nécessaire | L'audit ne peut être renseigné qu'après la prévisite. Merci d'attendre que la prévisite soit 🟩Passage Effectué (ou de mettre « PREVISITE- Nécessité » sur ❌- NON). |

#### DOS_30_AUDIT_DEMANDE

Ancien nom : `AUDIT_OUI1`. Message affiché sous le champ « AUDIT- Statut ».

|                     | Aujourd'hui                                                                                                 | Proposé                                                                                                                                   |
| ------------------- | ----------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | AUDIT_OUI1                                                                                                  | DOS_30_AUDIT_DEMANDE                                                                                                                      |
| Description         | Si l'auditeur est renseigné merci de mettre la date d'envoi                                                 | « AUDIT- Statut » = 🟨Audit- Demandé : « LOOKUP- Auditeur » et « AUDIT- Date d’Envoi » obligatoires.                                      |
| Message utilisateur | Si le statut audit est demandé, alors il faut que le nom de la société et la date d'envoi soient rensseigné | Pour mettre 🟨Audit- Demandé, merci de choisir l'auditeur (« LOOKUP- Auditeur ») et d'indiquer la date d'envoi (« AUDIT- Date d’Envoi »). |

#### DOS_30_AUDIT_MODIFS_DEMANDEES

Ancien nom : `AUDIT_OUI2`. Message affiché sous le champ « AUDIT- Statut ».

|                     | Aujourd'hui                                                                                                                 | Proposé                                                                                                                                  |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | AUDIT_OUI2                                                                                                                  | DOS_30_AUDIT_MODIFS_DEMANDEES                                                                                                            |
| Description         | Si le statut est en modif demandé, il faut que le nom de l'auditeur, la date d'envoi et la date de reception soient remplis | « AUDIT- Statut » = 🟧Audit- Modifs Demandées : « LOOKUP- Auditeur », « AUDIT- Date d’Envoi » et « AUDIT- Date Reception » obligatoires. |
| Message utilisateur | Si le dossier est en modifs demandé, il faut que le nom de l'auditeur la date d'envoi et date de réception soient rempli.   | Pour mettre 🟧Audit- Modifs Demandées, merci de renseigner l'auditeur, la date d'envoi et la date de réception de l'audit.               |

#### DOS_30_AUDIT_MPR_DEPOSEE

Ancien nom : `PREVISITE9`. Message affiché sous le champ « AUDIT- Statut ».

|                     | Aujourd'hui                                                      | Proposé                                                                                                                                     |
| ------------------- | ---------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | PREVISITE9                                                       | DOS_30_AUDIT_MPR_DEPOSEE                                                                                                                    |
| Description         | Si MPR non déposé on peut pas envoyer en audit                   | « AUDIT- Statut » = 🟨Audit- Demandé interdit tant que « DR- Prev1 » contient ❌ (MPR non déposée ou docs incomplets).                      |
| Message utilisateur | Si MPR non déposé Ou Docs incomplet on peut pas envoyer en audit | L'audit ne peut pas encore être demandé : la MPR n'est pas déposée ou les documents sont incomplets. Merci de compléter le dossier d'abord. |

#### DOS_30_AUDIT_NON

Ancien nom : `AUDIT_NON`. Message affiché sous le champ « PREVISITE- Nécessité ».

|                     | Aujourd'hui                                                                                                                                         | Proposé                                                                                                                                                                             |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | AUDIT_NON                                                                                                                                           | DOS_30_AUDIT_NON                                                                                                                                                                    |
| Description         | Si Audit egale non,, Statut previsite en att planification, nom de société en Nouveau dossier, date de previsite et date d'envoi doivent être vide. | « AUDIT- Nécéssité » = ❌- NON : « AUDIT- Statut » doit rester ▣ Nouveau Dossier, et « LOOKUP- Auditeur », « AUDIT- Date d’Envoi » et « AUDIT- Date Reception » doivent être vides. |
| Message utilisateur | Si Audit egale non,, Statut previsite en att planification, nom de société en Nouveau dossier, date de previsite et date d'envoi doivent être vide. | L'audit est sur ❌- NON. Merci de laisser « AUDIT- Statut » sur ▣ Nouveau Dossier et de vider l'auditeur, la date d'envoi et la date de réception.                                  |

#### DOS_30_AUDIT_VALIDE

Ancien nom : `AUDIT_OUI3`. Message affiché sous le champ « AUDIT- Statut ».

|                     | Aujourd'hui                                                                                                                 | Proposé                                                                                                                        |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| Nom                 | AUDIT_OUI3                                                                                                                  | DOS_30_AUDIT_VALIDE                                                                                                            |
| Description         | Si le statut est en modif demandé, il faut que le nom de l'auditeur, la date d'envoi et la date de reception soient remplis | « AUDIT- Statut » = 🟩Audit- Validé : « LOOKUP- Auditeur », « AUDIT- Date d’Envoi » et « AUDIT- Date Reception » obligatoires. |
| Message utilisateur | Si le statut audit est en validé alors il faut que le nom de l'auditeur la date d'envoi et date de réception soient rempli. | Pour mettre 🟩Audit- Validé, merci de renseigner l'auditeur, la date d'envoi et la date de réception de l'audit.               |

#### DOS_30_COFRAC_ENVOI — règle inactive

Ancien nom : `AUDIT_OUI6`. Message affiché sous le champ « COFRAC- Statut ».

|                     | Aujourd'hui                                                                                                                 | Proposé                                                                                                                                                           |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | AUDIT_OUI6                                                                                                                  | DOS_30_COFRAC_ENVOI                                                                                                                                               |
| Description         | Si le statut est en modif demandé, il faut que le nom de l'auditeur, la date d'envoi et la date de reception soient remplis | « COFRAC- Statut » renseigné : « AUDIT- Statut » doit être 🟩Audit- Validé, et « COFRAC- Nom Sté » et « COFRAC- Date de Passage » sont obligatoires.              |
| Message utilisateur | Merci de remplir le nom du Cofrac et la date de passage.<br>Il faut que l’audit soit validé pour envoyer en cofrac          | L'envoi au COFRAC demande un audit validé. Merci de passer « AUDIT- Statut » en 🟩Audit- Validé et de remplir « COFRAC- Nom Sté » et « COFRAC- Date de Passage ». |

#### DOS_30_COFRAC_PLANIFIE

Ancien nom : `COFRAC174_1`. Message affiché sous le champ « COFRAC- Statut ».

|                     | Aujourd'hui                                                                                   | Proposé                                                                                                                               |
| ------------------- | --------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | COFRAC174_1                                                                                   | DOS_30_COFRAC_PLANIFIE                                                                                                                |
| Description         | Pour envoyer au COFRAC il faut que les docs soient complet.                                   | « COFRAC- Statut » = 🟧Passage Planifié : « RES- Precarité » = 🟦BLEU et « DOCS- Statut » = 🟩Dossier Complet obligatoires.           |
| Message utilisateur | Pour envoyer au COFRAC en 174, il faut precarite Bleu et il faut que les docs soient complet. | Pour planifier le COFRAC, le client doit être 🟦BLEU et le dossier complet. Merci de vérifier « RES- Precarité » et « DOCS- Statut ». |

### Étape 40 — Devis

#### DOS_40_DEVIS_AGRI_DELEGATAIRE

Ancien nom : `DEVIS_108_117_119`. Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                                                                                                                                                                    | Proposé                                                                                                                                                                                                                            |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | DEVIS_108_117_119                                                                                                                                                                                                                                              | DOS_40_DEVIS_AGRI_DELEGATAIRE                                                                                                                                                                                                      |
| Description         | Il faut que le champ Devis TTC et que le Délégataire soit rempli.                                                                                                                                                                                              | « CEE- Statut » 🟩AAF Envoyé (AGRI EQ108, TH108, TH119, BAT TH163, BAR TH179) : « DEVIS- Montant TTC » rempli et non nul. « RDV- Statut Devis » 🟦En Att Signature ou 🟩Signé (fiches AGRI) : « LOOKUP- Delegataire » obligatoire. |
| Message utilisateur | 1.Si devis Att Signature, il faut le delégataire, date devis, documents, cotation soient complet.<br>2.Si devis Signé, il faut le delégataire, date devis, date signature,documents,cotation soient complet.<br>3.Si CEE payé, montant TTC doit etre renseigné | Il manque une information sur le devis. Devis 🟦En Att Signature ou 🟩Signé : merci de choisir le délégataire. CEE 🟩AAF Envoyé : merci d'indiquer « DEVIS- Montant TTC ».                                                         |

#### DOS_40_DEVIS_FINAL_MONTANT_DELEGATAIRE — règle inactive

Ancien nom : `PAC_ATT_SIGNATURE_OU_SIGNE`. Message affiché sous le champ « DEVIS- Montant TTC ».

|                     | Aujourd'hui                                                                                                                                                    | Proposé                                                                                                                                                         |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | PAC_ATT_SIGNATURE_OU_SIGNE                                                                                                                                     | DOS_40_DEVIS_FINAL_MONTANT_DELEGATAIRE                                                                                                                          |
| Description         | Pour mettre le devis en signé, Merci de mettre le statut "PAC- STATUT DOSSIER " en "Dossier signé" ainsi que de renseigner la personne et la date de Signature | « LEDS- Devis Final » = 🟦En Attente Signature ou 🟩Signé : « DEVIS- Montant TTC » rempli et différent de 0, et « CEE- Délegataire » choisi (pas ▣ En attente). |
| Message utilisateur | Pour mettre le devis en attente de signature ou signé il faut que le champ DEVIS- Montant TTC et le delegataire soit rempli                                    | Le devis final ne peut pas être en attente de signature ou signé sans montant ni délégataire. Merci de remplir « DEVIS- Montant TTC » et « CEE- Délegataire ».  |

#### DOS_40_DEVIS_MONTANT_TTC_KIT

Ancien nom : `PAC_Installation12`. Message affiché sous le champ « DEVIS- Montant TTC ».

|                     | Aujourd'hui                                                                                           | Proposé                                                                                                                                                            |
| ------------------- | ----------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Nom                 | PAC_Installation12                                                                                    | DOS_40_DEVIS_MONTANT_TTC_KIT                                                                                                                                       |
| Description         | Votre montant total n'a pas pris en charge le kit bizone ou est incorrect, merci de le mettre à jour. | « DEVIS- Montant TTC » (s'il est rempli) : 10 000 à 10 600 € si « INSTALLATION- Kit Bi-Zone » = Non nécessaire ou KIT 1 ZONE ; 10 600 à 13 000 € avec KIT BI-ZONE. |
| Message utilisateur | Votre montant total n'a pas pris en charge le kit bizone ou est incorrect, merci de le mettre à jour. | Le montant TTC ne correspond pas au kit choisi. Merci de le corriger : 10 000 à 10 600 € sans kit bizone (ou avec KIT 1 ZONE), 10 600 à 13 000 € avec KIT BI-ZONE. |

#### DOS_40_DEVIS_TH163_TH179_DELEGATAIRE

Ancien nom : `DEVIS_179_163`. Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                                                                 | Proposé                                                                                                                |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| Nom                 | DEVIS_179_163                                                                                                                                               | DOS_40_DEVIS_TH163_TH179_DELEGATAIRE                                                                                   |
| Description         | Il faut que le champ Devis TTC et que le Délégataire soit rempli.                                                                                           | BAT TH163 et BAR TH179 : « RDV- Statut Devis » = 🟦En Att Signature ou 🟩Signé => « LOOKUP- Delegataire » obligatoire. |
| Message utilisateur | 1.Si devis Att Signature, il faut le delégataire, date devis, documents.<br>2.Si devis Signé, il faut le delégataire, date devis, date signature,documents. | Devis 🟦En Att Signature ou 🟩Signé : merci de choisir le délégataire (« LOOKUP- Delegataire »).                       |

#### DOS_40_DEVIS_TH171_TH174_DELEGATAIRE

Ancien nom : `DEVIS_171_174`. Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                        | Proposé                                                                                                                                                                                            |
| ------------------- | ------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | DEVIS_171_174                                                                                                      | DOS_40_DEVIS_TH171_TH174_DELEGATAIRE                                                                                                                                                               |
| Description         | Il faut que le champ Devis TTC et que le Délégataire soit rempli.                                                  | TH171 et TH174 : « CEE- Statut » = 🟩AAF Envoyé => « DEVIS- Montant TTC » rempli et différent de 0 ; « RDV- Statut Devis » = 🟦En Att Signature ou 🟩Signé => « LOOKUP- Delegataire » obligatoire. |
| Message utilisateur | Si devis Généré ou Signé, il faut le delagataire soit rempli<br>Si CEE payé, il faut le montant TTC soit renseigné | Il manque une information sur le devis. Devis 🟦En Att Signature ou 🟩Signé : merci de choisir le délégataire. CEE 🟩AAF Envoyé : merci d'indiquer « DEVIS- Montant TTC ».                         |

#### DOS_40_DEVIS_TH174_APRES_TH171

Ancien nom : `Si171_ouvert174en_attetne`. Message affiché en haut de la page.

|                     | Aujourd'hui                                                                    | Proposé                                                                                                                                                                                         |
| ------------------- | ------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | Si171_ouvert174en_attetne                                                      | DOS_40_DEVIS_TH174_APRES_TH171                                                                                                                                                                  |
| Description         | Vous avez une fiche 171 en court merci de la cloturer avant de passer a la 174 | Fiche TH174 : les profils Responsable Telepro et Closer ne peuvent pas changer « RDV- Statut Devis » tant que « DR-Infos fiche1 » contient ⚠️PACRes (fiche TH171 en cours pour le même client). |
| Message utilisateur | Vous avez une fiche 171 en cours merci de la cloturer avant de passer a la 174 | Une fiche TH171 est encore en cours pour ce client. Merci de la clôturer avant de faire avancer le devis TH174.                                                                                 |

#### DOS_40_DEVIS_TH174_CHAMPS

Ancien nom : `DEVIS_174`. Message affiché sous le champ « RDV- Statut Devis ».

|                     | Aujourd'hui                                                                                                                                                                                                                                          | Proposé                                                                                                                                                                                                                        |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Nom                 | DEVIS_174                                                                                                                                                                                                                                            | DOS_40_DEVIS_TH174_CHAMPS                                                                                                                                                                                                      |
| Description         | Pour mettre le devis en attente de sigature, merci de remplir, la date de devis,la shab,la precarité,la cotation.                                                                                                                                    | TH174 (« DR-Infos fiche2 » = 1), devis sorti de ▣ Génération Devis : 🟩Dossier Complet, 🟦BLEU, LOOKUP- Delegataire, DEVIS- Généré le, RES- Shab, DEVIS- Cotation, RENO 174- Travaux Finaux. Toujours : un seul ballon thermo. |
| Message utilisateur | Pour remplir shab,travaux finaux cotation , il faut le cofrac soit satisfaisant.<br>Pour faire devis, il faut préca bleu,travaux finaux, delegataire, date devis, Shab, Precarité, Cotation, docs.<br>Un type de ballon uniquement ds travaux finaux | Il manque des éléments pour faire avancer le devis TH174. Merci de vérifier : docs 🟩Dossier Complet, précarité 🟦BLEU, délégataire, date du devis, Shab, cotation et travaux finaux (un seul ballon thermo).                  |

### Étape 50 — MPR et reste à charge

#### DOS_50_MPR_ANOMALIE_COMMENTAIRE

Ancien nom : `PAC_Statut_Dossier_3`. Message affiché sous le champ « DOCS- Com Secrétaire ».

|                     | Aujourd'hui                                                         | Proposé                                                                                    |
| ------------------- | ------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| Nom                 | PAC_Statut_Dossier_3                                                | DOS_50_MPR_ANOMALIE_COMMENTAIRE                                                            |
| Description         | Merci de mettre le bon statut de dossier pour mettre ce statut MPR. | « MPR- Statut » = 🟨Anomalie- Voir Commentaire : « DOCS- Com Secrétaire » obligatoire.     |
| Message utilisateur | Merci de remplir un commentaire d'anomalie MPR                      | Le statut MPR est en anomalie. Merci d'expliquer l'anomalie dans « DOCS- Com Secrétaire ». |

#### DOS_50_MPR_DATE_MODIF

Ancien nom : `PAC_Installation6`. Message affiché sous le champ « MPR- Modifs ».

|                     | Aujourd'hui                                                               | Proposé                                                                                                                           |
| ------------------- | ------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | PAC_Installation6                                                         | DOS_50_MPR_DATE_MODIF                                                                                                             |
| Description         | Si le statut MPR est changé, il faut mettre à jour la date de modifs MPR. | Tout changement de « MPR- Statut » doit s'accompagner, dans le même enregistrement, de la mise à jour de la date « MPR- Modifs ». |
| Message utilisateur | Si le statut MPR est changé, il faut mettre à jour la date de modifs MPR. | Vous avez changé « MPR- Statut ». Merci de mettre aussi à jour la date « MPR- Modifs ».                                           |

#### DOS_50_MPR_FULL_CEE

Ancien nom : `PAC_Installation14`. Message affiché sous le champ « MPR- Statut ».

|                     | Aujourd'hui                                                                                                                                  | Proposé                                                                                                                                                  |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | PAC_Installation14                                                                                                                           | DOS_50_MPR_FULL_CEE                                                                                                                                      |
| Description         | Pour mettre en statut déposé, Merci de remplir les champs manquants                                                                          | TH171, « MPR- Statut » = ❌Full CEE : « RES- Indivision » et « RES- Statut Occupation » renseignés, « RES- Precarité » = 🟥ROSE et « RES- Shab » rempli. |
| Message utilisateur | Pour mettre en statut full CEE, il faut, que le statut d'occupation, l'indivision, la précarité en Rose et la surface habitable soit rempli. | Pour passer en ❌Full CEE, le client doit être 🟥ROSE. Merci de remplir aussi la Shab, le statut d'occupation et l'indivision.                           |

#### DOS_50_MPR_SOLDE_DOSSIER_INSTALLE

Ancien nom : `PAC_Statut_Dossier_2`. Message affiché sous le champ « MPR- Statut ».

|                     | Aujourd'hui                                                         | Proposé                                                                                                                                            |
| ------------------- | ------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | PAC_Statut_Dossier_2                                                | DOS_50_MPR_SOLDE_DOSSIER_INSTALLE                                                                                                                  |
| Description         | Merci de mettre le bon statut de dossier pour mettre ce statut MPR. | TH171 : « MPR- Statut » = 🟫Solde Demandé, 🟩Payé- Reçu Bénéficiaire ou 🟩Payé- Virement Reçu exige « RDV- Statut Dossier » = 🟢DOSSIER- Installé. |
| Message utilisateur | Merci de mettre le bon statut de dossier pour mettre ce statut MPR. | Ce statut MPR n'est possible qu'une fois le dossier installé. Merci de passer d'abord « RDV- Statut Dossier » en 🟢DOSSIER- Installé.              |

#### DOS_50_MPR_SOLDE_INSTALL_CLOTUREE

Ancien nom : `PAC_Installation11`. Message affiché sous le champ « MPR- Statut ».

|                     | Aujourd'hui                                                   | Proposé                                                                                                                                                 |
| ------------------- | ------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | PAC_Installation11                                            | DOS_50_MPR_SOLDE_INSTALL_CLOTUREE                                                                                                                       |
| Description         | Pour Envoyer en pose il faut que le statut MPR soit cohérent. | TH171 : « MPR- Statut » = 🟫Solde Demandé, 🟩Payé- Reçu Bénéficiaire ou 🟩Payé- Virement Reçu exige « INSTALLATION- Statut » = 🟩Installation Cloturée. |
| Message utilisateur | Pour Envoyer en pose il faut que le statut MPR soit cohérent. | Ce statut MPR n'est possible qu'après l'installation. Merci de passer d'abord « INSTALLATION- Statut » en 🟩Installation Cloturée.                      |

#### DOS_50_RAC_JAUNE_OBLIGATOIRE

Ancien nom : `PAC_RAC_3`. Message affiché sous le champ « DEVIS- Modalité Paiement ».

|                     | Aujourd'hui                                                                                                                                                                             | Proposé                                                                                                                                                                 |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | PAC_RAC_3                                                                                                                                                                               | DOS_50_RAC_JAUNE_OBLIGATOIRE                                                                                                                                            |
| Description         | Remplir les modalité paiement, le modele de la PAC, Ballon, Kit bizone, Compteur, le Sous traitant et la date d'installation pour passer au statut suivant                              | TH171, 🟨JAUNE avec « RES- Shab » < 90 ou « RES- Zone » = 🟧H2, « MPR- Statut » 🟪Déposé ou plus : « DEVIS- Montant RAC » et « DEVIS- Modalité Paiement » obligatoires. |
| Message utilisateur | 1.Si Le client est Jaune inferieur a 90m², merci de remplir les modalité de paiement et le RAC.<br>2.Si Le client est Jaune en H2, merci de remplir les modalité de paiement et le RAC. | Client 🟨JAUNE de moins de 90 m² ou en zone 🟧H2 : merci de renseigner le montant du reste à charge et la modalité de paiement.                                         |

#### DOS_50_RAC_MINIMUM_AVEC_KIT

Ancien nom : `PAC_RAC_8`. Message affiché sous le champ « DEVIS- Montant RAC ».

|                     | Aujourd'hui                                                                                                                                                                               | Proposé                                                                                                                                                                                                                        |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Nom                 | PAC_RAC_8                                                                                                                                                                                 | DOS_50_RAC_MINIMUM_AVEC_KIT                                                                                                                                                                                                    |
| Description         | Merci de mettre un RAC Coherent                                                                                                                                                           | « DEVIS- Montant RAC » minimum avec KIT BI-ZONE ou KIT 1 ZONE (dossiers créés depuis le 27/04/2026) : 🟨JAUNE 4 500 € (Shab 70-89, ou 90 et plus en 🟧H2) ; 🟪VIOLET 7 500 € (70-89) ou 6 500 € (90 et plus) ; 🟥ROSE 9 000 €. |
| Message utilisateur | Merci de mettre un RAC coherent.<br><br>JAUNE (H1/ +90m²: 0€ - le reste des cas:3000€)<br>VIOLET (H1/H2: -90m²: 6000€ // +90m²: 4500€)<br>ROSE (H1/H2: 7500€)<br><br>Si kit Bizone +1500€ | Le reste à charge est trop bas avec un kit. Minimums : 🟨JAUNE 4 500 € (0 € en H1 à partir de 90 m²), 🟪VIOLET 7 500 € sous 90 m² et 6 500 € au-delà, 🟥ROSE 9 000 €. Merci de corriger le montant.                            |

#### DOS_50_RAC_MINIMUM_SANS_KIT

Ancien nom : `PAC_RAC_2`. Message affiché sous le champ « DEVIS- Montant RAC ».

|                     | Aujourd'hui                                                                                                                                                                               | Proposé                                                                                                                                                                                                                 |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | PAC_RAC_2                                                                                                                                                                                 | DOS_50_RAC_MINIMUM_SANS_KIT                                                                                                                                                                                             |
| Description         | Merci de mettre un RAC Coherent                                                                                                                                                           | « DEVIS- Montant RAC » minimum sans kit bizone (dossiers créés depuis le 27/04/2026) : 🟨JAUNE 3 000 € (Shab 70-89, ou 90 et plus en 🟧H2) ; 🟪VIOLET 6 000 € (70-89) ou 4 500 € (90 et plus) ; 🟥ROSE 7 500 €.         |
| Message utilisateur | Merci de mettre un RAC coherent.<br><br>JAUNE (H1/ +90m²: 0€ - le reste des cas:3000€)<br>VIOLET (H1/H2: -90m²: 6000€ // +90m²: 4500€)<br>ROSE (H1/H2: 7500€)<br><br>Si kit Bizone +1500€ | Le reste à charge est trop bas. Minimums : 🟨JAUNE 3 000 € (0 € en H1 à partir de 90 m²), 🟪VIOLET 6 000 € sous 90 m² et 4 500 € au-delà, 🟥ROSE 7 500 €. Avec un kit bizone : + 1 500 €. Merci de corriger le montant. |

#### DOS_50_RAC_MODALITE_PAIEMENT — règle inactive

Ancien nom : `PAC_Installation10`. Message affiché sous le champ « DEVIS- Modalité Paiement ».

|                     | Aujourd'hui                                                                                  | Proposé                                                                                                                                                                                                    |
| ------------------- | -------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | PAC_Installation10                                                                           | DOS_50_RAC_MODALITE_PAIEMENT                                                                                                                                                                               |
| Description         | Les modalités de paiement ne sont pas renseigné ou pas cohérent avec la précarité du client. | « DEVIS- Modalité Paiement » selon « RES- Precarité » : 🟦BLEU => 🟩Sans RAC- 0€ obligatoire ; 🟨JAUNE, 🟪VIOLET, 🟥ROSE => 🟩Sans RAC- 0€ interdit. (Valeur 🟩Sans RAC- 0€ absente de la liste actuelle.) |
| Message utilisateur | Les modalités de paiement ne sont pas cohérent avec la précarité du client.                  | La modalité de paiement ne correspond pas à la précarité du client. Merci d'adapter « DEVIS- Modalité Paiement » à « RES- Precarité ».                                                                     |

#### DOS_50_RAC_SELON_PRECARITE

Ancien nom : `PAC_RAC_1`. Message affiché sous le champ « DEVIS- Modalité Paiement ».

|                     | Aujourd'hui                                                                                                                                                                        | Proposé                                                                                                                                                                                                    |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | PAC_RAC_1                                                                                                                                                                          | DOS_50_RAC_SELON_PRECARITE                                                                                                                                                                                 |
| Description         | Remplir les modalité paiement, le modele de la PAC, Ballon, Kit bizone, Compteur, le Sous traitant et la date d'installation pour passer au statut suivant                         | TH171, « MPR- Statut » 🟪Déposé ou plus : 🟪VIOLET => « DEVIS- Montant RAC » et « DEVIS- Modalité Paiement » obligatoires ; 🟥ROSE en ❌Full CEE => idem ; 🟦BLEU => ces deux champs doivent rester vides. |
| Message utilisateur | Si Le client est Bleue, merci de laisser vide les modalité paiement et le montant RAC.<br> Si Le client est Violet/Rose, Merci de Remplir les modalité paiement et le montant RAC. | Le reste à charge ne correspond pas à la précarité. Client 🟦BLEU : merci de laisser vides le montant RAC et la modalité de paiement. Client 🟪VIOLET ou 🟥ROSE : merci de les remplir.                    |

### Étape 60 — Installation

#### DOS_60_INSTALL_CHAMPS_POSE

Ancien nom : `PAC_Installation8`. Message affiché sous le champ « INSTALLATION- Statut ».

|                     | Aujourd'hui                                                                                                                                                                                                                                                | Proposé                                                                                                                                                                                                                                    |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Nom                 | PAC_Installation8                                                                                                                                                                                                                                          | DOS_60_INSTALL_CHAMPS_POSE                                                                                                                                                                                                                 |
| Description         | Merci de remplir le modele de la PAC, Ballon, Kit bizone, le lookup Straitant et la date d'installation pour passer au statut suivant                                                                                                                      | « INSTALLATION- Statut » 🟨, 🟧 ou 🟩. TH171 : Date Réel, 🟩Dossier Complet, Modele PAC, Modele Ballon, Kit Bi-Zone, Compteur, Nom SS Traitant, Mail et Infos SStraitant. TH174 : détail de chaque travail final coché (m², type, modèle). |
| Message utilisateur | Docs doivent etre complet.<br>171- Date d'installation, PAC,Ballon, Kit bizone,Compteur,Sous traitant, Mail et commentaire pr ss traitant.<br>174- Date d'installation, Infos lié au produits installé, Sous traitant, Mail et commentaire pr ss traitant. | Il manque des informations pour planifier ou clôturer l'installation. TH171 : docs complets et champs INSTALLATION (date, PAC, ballon, kit, compteur, sous-traitant, mail, infos). TH174 : merci de détailler chaque travail final coché.  |

#### DOS_60_INSTALL_CHANTIER_PREVALIDE

Ancien nom : `PAC_Installation7`. Message affiché sous le champ « INSTALLATION- Statut ».

|                     | Aujourd'hui                                                                                                  | Proposé                                                                                                                                            |
| ------------------- | ------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | PAC_Installation7                                                                                            | DOS_60_INSTALL_CHANTIER_PREVALIDE                                                                                                                  |
| Description         | Merci de remplir le modèle de la PAC, Ballon, Kit bizone, pour passer au statut suivant.                     | TH171, « INSTALLATION- Statut » = 🟪Chantier PréValidé : INSTALLATION- Modele PAC, Modele Ballon, Compteur Electrique et Kit Bi-Zone obligatoires. |
| Message utilisateur | Merci de remplir le modèle de la PAC, Ballon, Kit bizone, Compteur électrique pour passer au statut suivant. | Pour mettre 🟪Chantier PréValidé, merci de renseigner le modèle de PAC, le modèle de ballon, le compteur électrique et le kit bizone.              |

#### DOS_60_INSTALL_DEPLACEMENT_SANS_RETOUR

Ancien nom : `INSTALLATION_DEPLACEMENT_PAS_DE_RETOUR`. Message affiché sous le champ « INSTALLATION- Deplacement ».

|                     | Aujourd'hui                                                                                                                                                                                                                                    | Proposé                                                                                                                                                                                                                   |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | INSTALLATION_DEPLACEMENT_PAS_DE_RETOUR                                                                                                                                                                                                         | DOS_60_INSTALL_DEPLACEMENT_SANS_RETOUR                                                                                                                                                                                    |
| Description         | Anti-retour sur « INSTALLATION- Deplacement » : une fois Déplacement 1 atteint, interdit de vider ; une fois Déplacement 2 atteint, interdit de revenir à 1 ou de vider. Progression vide -> 1 -> 2 autorisée.                                 | _inchangée (déjà claire)_                                                                                                                                                                                                 |
| Message utilisateur | Retour en arrière interdit sur « INSTALLATION- Deplacement » : une fois Frais Déplacement 1 atteint vous ne pouvez plus vider le champ, et une fois Frais Déplacement 2 atteint vous ne pouvez plus revenir à Frais Déplacement 1 ni le vider. | Retour en arrière impossible sur « INSTALLATION- Deplacement » : après Frais Déplacement 1, le champ ne peut plus être vidé ; après Frais Déplacement 2, il ne peut plus revenir à 1. Merci de garder la valeur actuelle. |

#### DOS_60_INSTALL_ENVOI_EN_POSE

Ancien nom : `Devis_171`. Message affiché sous le champ « INSTALLATION- Statut ».

|                     | Aujourd'hui                                                                                                                                                                                                           | Proposé                                                                                                                                                                                                                         |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | Devis_171                                                                                                                                                                                                             | DOS_60_INSTALL_ENVOI_EN_POSE                                                                                                                                                                                                    |
| Description         | Voir Zone/ Shab ou Précarité pour envoie en pose                                                                                                                                                                      | Blocage de 🟨Date Planifiée (« INSTALLATION- Statut »). TH171 : RAC avec devis non signé ; 🟨JAUNE/🟪VIOLET (RAC ≤ 6 999 €) ou « RES- Shab » < 90 sans MPR accordée ; Shab < 70. Toutes fiches : « RES- Zone » 🟥H3 ou INCONNU. |
| Message utilisateur | Vous ne pouvez pas envoyer en pose si:<br>1.Devis non signé quand il y a du RAC <br>2.Jaune/violet sans accord MPR<br>3.Dossier -90m² sans accord MPR<br>4.Votre code postal est en H3<br>5.La Shab est moins de 70m² | Envoi en pose impossible pour le moment. Merci de vérifier : devis signé s'il y a un reste à charge, accord MPR pour un client 🟨JAUNE / 🟪VIOLET ou sous 90 m², Shab d'au moins 70 m², zone connue et hors 🟥H3.               |

#### DOS_60_INSTALL_FIN_CHANTIER_SIGNEE

Ancien nom : `PAC_Installation15`. Message affiché sous le champ « INSTALLATION- Statut ».

|                     | Aujourd'hui                                                                 | Proposé                                                                                                                                                    |
| ------------------- | --------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | PAC_Installation15                                                          | DOS_60_INSTALL_FIN_CHANTIER_SIGNEE                                                                                                                         |
| Description         | Pour mettre en signé il faut que le statut de l'installation soit cohérent. | TH171 et TH174 : « INSTALLATION- Fin Chantier » = 🟩Signé interdit si « INSTALLATION- Statut » est encore ▣ Attente Planification ou 🟪Chantier PréValidé. |
| Message utilisateur | Pour mettre en signé il faut que le statut de l'installation soit cohérent. | La fin de chantier ne peut pas être signée avant l'installation. Merci de faire avancer d'abord « INSTALLATION- Statut ».                                  |

#### DOS_60_INSTALL_MAIL_SOUS_TRAITANT

Ancien nom : `PAC_Installation5`. Message affiché sous le champ « INSTALLATION- Mail Sous Traitant ».

|                     | Aujourd'hui                                                                                                                                                                                              | Proposé                                                                                                                                                                                          |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Nom                 | PAC_Installation5                                                                                                                                                                                        | DOS_60_INSTALL_MAIL_SOUS_TRAITANT                                                                                                                                                                |
| Description         | Le champ "Email du sous-traitant" ne peut pas être renseigné tant que la date d’installation, le lookupp ss traitant, le kit bizone, le modele de la pac et le commentaire installateur n’est pas saisi. | « INSTALLATION- Mail Sous Traitant » ne peut être rempli que si INSTALLATION- Date Réel, Nom SS Traitant, Compteur Electrique, Modele PAC, Kit Bi-Zone et Infos SStraitant sont saisis.          |
| Message utilisateur | Le champ "Email du sous-traitant" ne peut pas être renseigné tant que la date d’installation, le lookupp ss traitant, le kit bizone, le modele de la pac et le commentaire installateur n’est pas saisi. | Le mail au sous-traitant ne peut pas partir sans les infos de pose. Merci de remplir la date, le sous-traitant, le compteur, le modèle de PAC, le kit bizone et les infos pour le sous-traitant. |

#### DOS_60_INSTALL_MAIL_SOUS_TRAITANT_2

Ancien nom : `date_installe_pac`. Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                                                                                                              | Proposé                                                                                                                                                                                                           |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | date_installe_pac                                                                                                                                                                                        | DOS_60_INSTALL_MAIL_SOUS_TRAITANT_2                                                                                                                                                                               |
| Description         | Le champ "Email du sous-traitant" ne peut pas être renseigné tant que la date d’installation de la PAC n’est pas saisie.                                                                                 | Doublon de PAC_Installation5, sans le compteur : « INSTALLATION- Mail Sous Traitant » interdit tant que INSTALLATION- Date Réel, Nom SS Traitant, Modele PAC, Kit Bi-Zone et Infos SStraitant ne sont pas saisis. |
| Message utilisateur | Le champ "Email du sous-traitant" ne peut pas être renseigné tant que la date d’installation, le lookupp ss traitant, le kit bizone, le modele de la pac et le commentaire installateur n’est pas saisi. | Le mail au sous-traitant ne peut pas partir sans les infos de pose. Merci de remplir la date, le sous-traitant, le modèle de PAC, le kit bizone et les infos pour le sous-traitant.                               |

### Étape 70 — Statut du dossier

#### DOS_70_DOSSIER_ANNULATION_CHAMPS

Ancien nom : `Statut_Dossier_2`. Message affiché en haut de la page.

|                     | Aujourd'hui                                                        | Proposé                                                                                                                                                                  |
| ------------------- | ------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Nom                 | Statut_Dossier_2                                                   | DOS_70_DOSSIER_ANNULATION_CHAMPS                                                                                                                                         |
| Description         | Merci de remplir le motif, le commentaire et la date d'Annulation. | « RDV- Statut Dossier » = ⚫DOSSIER- Annulé (toutes fiches CEE) : « RDV- Motif Annulation », « RDV- Date d'Annulation » et « RDV- Commentaire Annulation » obligatoires. |
| Message utilisateur | Merci de remplir le motif, le commentaire et la date d'Annulation. | Pour annuler le dossier, merci d'indiquer le motif, la date et un commentaire d'annulation.                                                                              |

#### DOS_70_DOSSIER_ANNULATION_TH174 — règle inactive

Ancien nom : `VALIDATION_AnnulationFrere`. Message affiché sous le champ « RENO TH174- Annulation ».

|                     | Aujourd'hui                                                               | Proposé                                                                                                                                                                                            |
| ------------------- | ------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | VALIDATION_AnnulationFrere                                                | DOS_70_DOSSIER_ANNULATION_TH174                                                                                                                                                                    |
| Description         | _(vide)_                                                                  | Fiche TH171 ⚫DOSSIER- Annulé avec RENO TH174 demandée (✅- OUI) et « RENO TH174- Statut Dossier » = 🔵DOSSIER- Attente Installation : « RENO TH174- Annulation » (✅- OUI / ❌- NON) obligatoire. |
| Message utilisateur | Merci de répondre à la question d’annulation en sélectionnant OUI ou NON. | La PAC TH171 est annulée alors qu'une RENO TH174 est en attente. Merci d'indiquer dans « RENO TH174- Annulation » si elle est aussi annulée (✅- OUI ou ❌- NON).                                  |

#### DOS_70_DOSSIER_ATTENTE_VS_CLOTURE

Ancien nom : `Statut_Dossier_1`. Message affiché en haut de la page.

|                     | Aujourd'hui                                                        | Proposé                                                                                                                                                       |
| ------------------- | ------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | Statut_Dossier_1                                                   | DOS_70_DOSSIER_ATTENTE_VS_CLOTURE                                                                                                                             |
| Description         | Merci d'avoir le statut installation en cohérence avec le dossier. | Toutes fiches CEE hors LEDS : « RDV- Statut Dossier » = 🔵DOSSIER- Attente Installation incompatible avec « INSTALLATION- Statut » = 🟩Installation Cloturée. |
| Message utilisateur | Merci d'avoir le statut installation en cohérence avec le dossier. | L'installation est clôturée mais le dossier est encore en attente d'installation. Merci de passer « RDV- Statut Dossier » en 🟢DOSSIER- Installé.             |

#### DOS_70_DOSSIER_CLOTURE_SI_INSTALLE

Ancien nom : `Statut_Dossier_4`. Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                     | Proposé                                                                                                                                                       |
| ------------------- | ----------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | Statut_Dossier_4                                                                                | DOS_70_DOSSIER_CLOTURE_SI_INSTALLE                                                                                                                            |
| Description         | Pour mettre le statut en Dossier Installé, il faut que le statut installation soit en installé. | Toutes fiches CEE hors LEDS : « RDV- Statut Dossier » = 🟢DOSSIER- Installé => « INSTALLATION- Statut » doit être 🟩Installation Cloturée.                    |
| Message utilisateur | Pour mettre le statut en Dossier Installé, il faut que le statut installation soit en installé. | Le dossier ne peut pas être installé tant que l'installation n'est pas clôturée. Merci de passer d'abord « INSTALLATION- Statut » en 🟩Installation Cloturée. |

#### DOS_70_DOSSIER_INSTALLE_SI_CLOTURE

Ancien nom : `Statut_Dossier_3`. Message affiché sous le champ « INSTALLATION- Statut ».

|                     | Aujourd'hui                                                                                         | Proposé                                                                                                                                    |
| ------------------- | --------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| Nom                 | Statut_Dossier_3                                                                                    | DOS_70_DOSSIER_INSTALLE_SI_CLOTURE                                                                                                         |
| Description         | Pour mettre le statut en Dossier Installé, il faut que le statut installation PAC soit en installé. | Toutes fiches CEE hors LEDS : « INSTALLATION- Statut » = 🟩Installation Cloturée => « RDV- Statut Dossier » doit être 🟢DOSSIER- Installé. |
| Message utilisateur | Pour mettre le statut en Dossier Installé, il faut que le statut installation soit en installé.     | L'installation est clôturée. Merci de passer aussi « RDV- Statut Dossier » en 🟢DOSSIER- Installé.                                         |

#### DOS_70_DOSSIER_LOCATAIRE

Ancien nom : `PAC_Statut_Dossier_1`. Message affiché sous le champ « RDV- Statut Dossier ».

|                     | Aujourd'hui                                                    | Proposé                                                                                                                                               |
| ------------------- | -------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | PAC_Statut_Dossier_1                                           | DOS_70_DOSSIER_LOCATAIRE                                                                                                                              |
| Description         | Si le client est locataire, alors le dossier est pas éligible. | TH171 : si « RES- Statut Occupation » = ⚠️Locataire, « RDV- Statut Dossier » ne peut pas être 🔵DOSSIER- Attente Installation (dossier non éligible). |
| Message utilisateur | Si le client est locataire, alors le dossier est pas éligible. | Le client est locataire : le dossier n'est pas éligible. Merci de ne pas le passer en 🔵DOSSIER- Attente Installation.                                |

#### DOS_70_DOSSIER_PAS_DE_NON

Ancien nom : `GLOBAL_METTRE_NON_APRES_CONVERSION`. Message affiché en haut de la page.

|                     | Aujourd'hui                                                                    | Proposé                                                                                                                                                                                                                                 |
| ------------------- | ------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | GLOBAL_METTRE_NON_APRES_CONVERSION                                             | DOS_70_DOSSIER_PAS_DE_NON                                                                                                                                                                                                               |
| Description         | Merci de mettre directement en annulé le dossier si il n'est plus d'actualité. | Après la création du dossier, on ne repasse pas un champ « Création Dossier » sur ❌- NON (LEDS EQ127, DESTRAT TH142, PAC TH171, RENO TH174, PAC TH179) : il faut annuler le dossier. La formule ne teste que le ❌- NON de LEDS EQ127. |
| Message utilisateur | Merci de mettre directement en annulé le dossier si il n'est plus d'actualité. | Un produit ne se remet pas sur ❌- NON après la création du dossier. Si le dossier n'est plus d'actualité, merci de le passer en annulé.                                                                                                |

### Étape 75 — CEE

#### DOS_75_CEE_DATE_MODIF

Ancien nom : `CEE_MODIFS_STATUT`. Message affiché en haut de la page.

|                     | Aujourd'hui                                                               | Proposé                                                                                                                           |
| ------------------- | ------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | CEE_MODIFS_STATUT                                                         | DOS_75_CEE_DATE_MODIF                                                                                                             |
| Description         | Si le statut CEE est changé, il faut mettre à jour la date de modifs CEE. | Tout changement de « CEE- Statut » doit s'accompagner, dans le même enregistrement, de la mise à jour de la date « CEE- Modifs ». |
| Message utilisateur | Si le statut CEE est changé, il faut mettre à jour la date de modifs CEE. | Vous avez changé « CEE- Statut ». Merci de mettre aussi à jour la date « CEE- Modifs ».                                           |

#### DOS_75_CEE_STATUT_DOSSIER

Ancien nom : `CEE_STATUT`. Message affiché sous le champ « CEE- Statut ».

|                     | Aujourd'hui                                                         | Proposé                                                                                                                                                                                                                           |
| ------------------- | ------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | CEE_STATUT                                                          | DOS_75_CEE_STATUT_DOSSIER                                                                                                                                                                                                         |
| Description         | Merci de mettre le bon statut de dossier pour mettre ce statut CEE. | TH171, « CEE- Statut » / « RDV- Statut Dossier ». ▣ En Attente Incitation : Attente Installation, Installé ou Annulé. 🟪Déposé et suivants : 🟢DOSSIER- Installé. 🟩AAF Envoyé : « CEE- N° AAF » et « CEE- Prix Cumacs » remplis. |
| Message utilisateur | Merci de mettre le bon statut de dossier pour mettre ce statut CEE. | Le statut CEE ne correspond pas à l'avancement du dossier : à partir de 🟪Déposé, le dossier doit être 🟢DOSSIER- Installé. Pour 🟩AAF Envoyé, merci de remplir aussi « CEE- N° AAF » et « CEE- Prix Cumacs ».                    |

### Étape 80 — LEDS

#### DOS_80_LEDS_AUDIT_VALIDE

Ancien nom : `LEDS_FIN_DE_CHANTIER6`. Message affiché sous le champ « LEDS- Statut Audit ».

|                     | Aujourd'hui                                                                      | Proposé                                                                                                                                                                  |
| ------------------- | -------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Nom                 | LEDS_FIN_DE_CHANTIER6                                                            | DOS_80_LEDS_AUDIT_VALIDE                                                                                                                                                 |
| Description         | Pour changer le statut de signature merci de mettre le statut d'audit en validé. | « LEDS- Statut Audit » doit être 🟩Validé pour faire avancer « LEDS- Devis Final » (hors ▣ Génération Devis) ou « LEDS- Fin Chantier » (hors ▣ Génération Fin Chantier). |
| Message utilisateur | Pour changer le statut de signature merci de mettre le statut d'audit en validé. | Pour faire avancer le devis final ou la fin de chantier, l'audit LEDS doit être 🟩Validé. Merci de valider l'audit d'abord.                                              |

#### DOS_80_LEDS_AUDITEUR

Ancien nom : `LEDS_FIN_DE_CHANTIER5`. Message affiché sous le champ « LEDS- Auditeur ».

|                     | Aujourd'hui                                        | Proposé                                                                                                        |
| ------------------- | -------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| Nom                 | LEDS_FIN_DE_CHANTIER5                              | DOS_80_LEDS_AUDITEUR                                                                                           |
| Description         | Merci de mettre le nom de l'auditeur pour valider. | « LEDS- Auditeur » doit être choisi (pas ▣ En Attente) dès que « LEDS- Statut Audit » n'est plus ▣ En Attente. |
| Message utilisateur | Merci de mettre le nom de l'auditeur pour valider. | Merci de choisir l'auditeur LEDS avant de changer le statut d'audit.                                           |

#### DOS_80_LEDS_DEVIS_SIGNE

Ancien nom : `DEVIS_Date_Signature`. Message affiché sous le champ « LEDS EQ127- Statut Dossier ».

|                     | Aujourd'hui                                                                                                                                                                                                      | Proposé                                                                                                                                                                                                                                                      |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Nom                 | DEVIS_Date_Signature                                                                                                                                                                                             | DOS_80_LEDS_DEVIS_SIGNE                                                                                                                                                                                                                                      |
| Description         | Pour mettre le devis en signé, Merci de mettre le statut "PAC- STATUT DOSSIER " en "Dossier signé", d'avoir les docs complet, le délégataire,le montant de devis, la personne et la date de Signature renseigné. | LEDS EQ127 (« LEDS- Devis Final » 🟩Signé) : dossier sorti de 🔵Attente Installation, CLIENT- Code postal, Adresse Chantier, « DOCS- CEE » 🟩Dossier Complet, LOOKUP- Delegataire, DEVIS- Montant HT, hauteurs et LEDS- Qté Prévue. Idem prévu pour DESTRAT. |
| Message utilisateur | Pour mettre le devis en signé, Merci de mettre le statut "PAC- STATUT DOSSIER " en "Dossier signé", d'avoir les docs complet, le délégataire,le montant de devis renseigné.                                      | Il manque des informations pour passer le devis en signé. Merci de remplir les docs CEE (🟩Dossier Complet), le délégataire, le montant HT, le code postal et l'adresse du chantier, et de faire avancer le statut du dossier.                               |

#### DOS_80_LEDS_INSTALL_CHAMPS

Ancien nom : `LEDS_INSTALLATION`. Message affiché sous le champ « LEDS EQ127- Statut Installation ».

|                     | Aujourd'hui                                                                                                                                                                                                                                | Proposé                                                                                                                                                                                                                                                   |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | LEDS_INSTALLATION                                                                                                                                                                                                                          | DOS_80_LEDS_INSTALL_CHAMPS                                                                                                                                                                                                                                |
| Description         | Merci de remplir le Lookup sous traitant et la date de planification.                                                                                                                                                                      | « LEDS EQ127- Statut Installation » 🟨Date Planifiée, 🟧Non Finalisée ou 🟩Cloturée : LEDS- Type d'Installation Final, Nom SS Traitant, RDV- Equipe d'Install, Hauteur MAX Sous Faitage, Date d'installation ; « LEDS- Qté Final » en plus si 🟩Cloturée. |
| Message utilisateur | Si envoi en pose, <br>Mettre le champs Leds-Validation Client en Envoi en pose,<br>Le Type d'installation Final. <br>Le Lokkup SSTraitant,<br>La Date installe, <br>LaHauteur Max Sous Faitage<br>Si installe <br>Rajouter QTE Leds finale | Il manque des informations sur l'installation LEDS. Merci de remplir le type d'installation final, le sous-traitant, l'équipe d'installation, la hauteur max sous faîtage et la date (+ la quantité finale si clôturée).                                  |

#### DOS_80_LEDS_INSTALL_CLOTUREE

Ancien nom : `LEDS_INSTALLATION6`. Message affiché sous le champ « LEDS EQ127- Statut Installation ».

|                     | Aujourd'hui                                                                    | Proposé                                                                                                   |
| ------------------- | ------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------- |
| Nom                 | LEDS_INSTALLATION6                                                             | DOS_80_LEDS_INSTALL_CLOTUREE                                                                              |
| Description         | Si le nombre de Leds finale est rempli, il faut que le statut soit en cloturé. | Si « LEDS- Qté Final » est rempli, « LEDS EQ127- Statut Installation » doit être 🟩Installation Cloturée. |
| Message utilisateur | Si le nombre de Leds finale est rempli, il faut que le statut soit en cloturé. | La quantité finale de LEDS est remplie : merci de passer l'installation en 🟩Installation Cloturée.       |

#### DOS_80_LEDS_QTE_ET_MODE

Ancien nom : `LEDS_FIN_DE_CHANTIER`. Message affiché sous le champ « LEDS- Qté Final ».

|                     | Aujourd'hui                                                                                                                                                                                                     | Proposé                                                                                                                                                   |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | LEDS_FIN_DE_CHANTIER                                                                                                                                                                                            | DOS_80_LEDS_QTE_ET_MODE                                                                                                                                   |
| Description         | Si la quantité de LEDS finale est renseigné il faut aussi renseigner le mode d'installation.<br>Et Inversement.                                                                                                 | « LEDS- Qté Final » et « LEDS- Mode d'installation » vont ensemble : si la quantité est remplie, le mode ne peut pas rester ▣ En Attente, et inversement. |
| Message utilisateur | Si la quantité de LEDS finale est vide alors le Mode d'installation doit l'etre aussi.<br>Si la quantité de LEDS finale est renseigné alots il faut aussi renseigner le mode d'installation.<br>Et Inversement. | La quantité finale et le mode d'installation LEDS vont ensemble. Merci de remplir les deux, ou de laisser la quantité vide et le mode sur ▣ En Attente.   |

#### DOS_80_LEDS_QTE_FINALE

Ancien nom : `LEDS_FIN_DE_CHANTIER3`. Message affiché sous le champ « LEDS- Qté Final ».

|                     | Aujourd'hui                                                                                                                                                                                                          | Proposé                                                                                                                                                 |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | LEDS_FIN_DE_CHANTIER3                                                                                                                                                                                                | DOS_80_LEDS_QTE_FINALE                                                                                                                                  |
| Description         | Pour Mettre en attente de signature il faut que la quantité de LEDS finale soit rempli.                                                                                                                              | « LEDS- Qté Final » obligatoire dès que « LEDS- Devis Final » quitte ▣ Génération Devis ou que « LEDS- Fin Chantier » quitte ▣ Génération Fin Chantier. |
| Message utilisateur | Pour Mettre En attente de signature le devis final il faut que la quantité de LEDS finale soit rempli.<br>Pour Mettre En attente de signature la fin de chantier il faut que la quantité de LEDS finale soit rempli. | Pour faire avancer le devis final ou la fin de chantier, merci d'indiquer la quantité finale de LEDS (« LEDS- Qté Final »).                             |

#### DOS_80_LEDS_QTE_MINIMUM

Ancien nom : `LEDS_Qte_INF`. Message affiché en haut de la page.

|                     | Aujourd'hui                                                                          | Proposé                                                                                                                                  |
| ------------------- | ------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | LEDS_Qte_INF                                                                         | DOS_80_LEDS_QTE_MINIMUM                                                                                                                  |
| Description         | Le nombre de Leds doit etre au minimum de 40 pour l'agriculture et 20 pour le reste. | LEDS (dossier non annulé) : « LEDS- Qté Prévue » au minimum 20 si « LEDS- Type Installation » = ☑️AGRICULTURE, 12 si ✅HORS AGRICULTURE. |
| Message utilisateur | Le nombre de Leds doit etre au minimum de 50 pour l'agriculture et 20 pour le reste. | Quantité de LEDS insuffisante. Merci d'indiquer au moins 20 LEDS en agriculture et 12 hors agriculture.                                  |

#### DOS_80_LEDS_TYPE_COMME_PISTE

Ancien nom : `LEDS_MEME_QUE_LA_PISTE`. Message affiché sous le champ « LEDS- Type d'Installation Final ».

|                     | Aujourd'hui                                                   | Proposé                                                                                                                       |
| ------------------- | ------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | LEDS_MEME_QUE_LA_PISTE                                        | DOS_80_LEDS_TYPE_COMME_PISTE                                                                                                  |
| Description         | Il faut que le type d'installation soit le meme que la piste. | « LEDS- Type d'Installation Final » (hors ▣ En Attente) doit être identique à « LEDS- Type Installation » repris de la piste. |
| Message utilisateur | Il faut que le type d'installation soit le meme que la piste. | Le type d'installation final doit être le même que sur la piste. Merci de corriger « LEDS- Type d'Installation Final ».       |

### Étape 90 — Contrôles de saisie

#### DOS_90_CONTROLE_ANTI_VIDE_1

Ancien nom : `CHAMPS_NUL`. Message affiché en haut de la page.

|                     | Aujourd'hui                            | Proposé                                                                                                                                                                                                                           |
| ------------------- | -------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | CHAMPS_NUL                             | DOS_90_CONTROLE_ANTI_VIDE_1                                                                                                                                                                                                       |
| Description         | LE CHAMPS NE PEUT PAS REPASSER EN NULL | Anti-vidage (liste 1) : 27 listes de statut (devis, RDV- Statut Dossier, PREVISITE, LEDS, INSTALLATION, AUDIT, MPR, CEE, CERTIKO…) ne peuvent pas être remises à vide. Exception : « CERTIKO- Statut VT » lors d'un nouvel envoi. |
| Message utilisateur | LE CHAMPS NE PEUT PAS REPASSER EN NULL | Ce statut est déjà renseigné et ne peut pas être remis à vide. Merci de choisir une valeur.                                                                                                                                       |

#### DOS_90_CONTROLE_ANTI_VIDE_2

Ancien nom : `CHAMPS_NUL2`. Message affiché en haut de la page.

|                     | Aujourd'hui                            | Proposé                                                                                                                                                                                                                          |
| ------------------- | -------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nom                 | CHAMPS_NUL2                            | DOS_90_CONTROLE_ANTI_VIDE_2                                                                                                                                                                                                      |
| Description         | LE CHAMPS NE PEUT PAS REPASSER EN NULL | Anti-vidage (liste 2) : 13 listes (RES- Precarité, RES- Indivision, INSTALLATION- Fin Chantier, champs ITE, MPR- Precarité.Piste, PREVISITE- Conf J-1, AUDIT- Nom Sté, PREVISITE- Nécessité) ne peuvent pas être remises à vide. |
| Message utilisateur | LE CHAMPS NE PEUT PAS REPASSER EN NULL | Ce statut est déjà renseigné et ne peut pas être remis à vide. Merci de choisir une valeur.                                                                                                                                      |

## Formules corrigées le 11/11/2026 (accord de l'utilisateur)

Seule la formule de ces 8 règles a changé. Aucun dossier existant n'est bloqué par ces corrections (vérifié avant).

| Règle                                          | Avant                                               | Après                                                                                             |
| ---------------------------------------------- | --------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| DOS_30_AUDIT_DEMANDE                           | 🟨Audit- Demandé                                    | 🟨Demandé                                                                                         |
| DOS_60_INSTALL_ENVOI_EN_POSE                   | 🟦En Attente Signature                              | 🟦En Att Signature                                                                                |
| DOS_40_DEVIS_MONTANT_TTC_KIT                   | non                                                 | Non                                                                                               |
| DOS_70_DOSSIER_ANNULATION_CHAMPS (partie LEDS) | ⚫DOSSIER Annulé                                    | ⚫DOSSIER- Annulé                                                                                 |
| PIS_30_CONFIRM_VALEURS_RESERVEES               | 🟦 A RAPPELER                                       | 🟦 A Rappeler                                                                                     |
| PIS_50_CONVERSION_CHAMPS_RES168                | ✅Fonte + Acier (Max 30% Fontes et MPR obligatoire) | Fonte + Acier (Max 30% Fontes)                                                                    |
| PIS_20_TELEPRO_HORS_CIBLE_LOOKUP               | contient « HORS CIBLE »                             | contient « HORS CIBLE » sans tenir compte des majuscules (prend « hORS CIBLE - Plusieurs devis ») |
| PIS_50_CONVERSION_CHAMPS_RES060                | Shab max 225 m²                                     | Shab max 230 m² (description et message alignés)                                                  |

## Points à vérifier (non corrigés)

Les lignes ci-dessous gardent les anciens noms ; celles corrigées plus haut sont réglées. Corrigé le 11/11/2026 : voir tableau ci-dessus.

### Valeurs citées dans une formule mais introuvables dans la liste du champ

La règle compare le champ à un texte qui ne correspond à aucune valeur actuelle : cette partie de la règle ne se déclenche probablement jamais. À confirmer par un essai.

| Objet    | Règle                                    | Champ                     | Texte dans la formule                               | Valeur réelle la plus proche                                          |
| -------- | ---------------------------------------- | ------------------------- | --------------------------------------------------- | --------------------------------------------------------------------- |
| Pistes   | BASE_ITE_ENVOYE_EN_CONF, _CONF2, _CONF3  | BD.ITE- Sous Statut       | 🟩ENVOYÉ EN CONF                                    | ENVOYÉ EN CONF (sans le carré vert dans la valeur technique)          |
| Pistes   | BASE_ITE_ENVOYE_EN_CONF, LEAD_ENVOI_CONF | LEADS- Statut             | 🟩ENVOYÉ EN CONFF                                   | aucune                                                                |
| Pistes   | LEAD_CHANGEMENT_STATUT3                  | LEADS- Statut             | contient « ENVOYÉ EN CONF »                         | aucune                                                                |
| Pistes   | Champs_DATE_DE_RAPPEL2                   | LEADS- Statut             | 🟪A RAPPELER- POUR SIGNATURE !!                     | aucune                                                                |
| Pistes   | CONFIRM_TRAITEMENT                       | CONFIRM- Traitement       | 🟦 A RAPPELER (majuscules)                          | 🟦 A Rappeler (libellé : 🟦 Rappel Nécessaire)                        |
| Pistes   | Conversion_REMPLISSAGE_168               | RES- Type de radiateur    | ✅Fonte + Acier (Max 30% Fontes et MPR obligatoire) | Fonte + Acier (Max 30% Fontes) : la formule cite le libellé           |
| Pistes   | LEAD_CHANGEMENT_STATUT2                  | LEADS- Statut             | contient « HORS CIBLE »                             | la valeur « hORS CIBLE - Plusieurs devis » commence par une minuscule |
| Dossiers | AUDIT_OUI1                               | AUDIT- Statut             | 🟨Audit- Demandé                                    | 🟨Demandé : la formule cite le libellé                                |
| Dossiers | Devis_171                                | RDV- Statut Devis         | 🟦En Attente Signature                              | 🟦En Att Signature                                                    |
| Dossiers | PAC_Installation10 (inactive)            | DEVIS- Modalité Paiement  | 🟩Sans RAC- 0€                                      | aucune                                                                |
| Dossiers | PAC_Installation12                       | INSTALLATION- Kit Bi-Zone | non (minuscule)                                     | Non (libellé : Non nécessaire)                                        |
| Dossiers | Statut_Dossier_2                         | RDV- Statut Dossier       | ⚫DOSSIER Annulé (branche LEDS)                     | ⚫DOSSIER- Annulé                                                     |
| Dossiers | Statut_Dossier_4                         | Type- Fiche CEE           | BBAR_TH174- Réno Glob                               | BAR_TH174- Réno Glob                                                  |

### Valeurs désactivées encore citées

- Pistes, « CONFIRM- Traitement » : 🟦DEVIS GÉNÉRÉ et 🟩SIGNÉ (règles CONFIRM_TRAITEMENT2 et CONF_DATE_GENERATION).
- Pistes, « PREVISITE- Fiches Résidentiel » : 🟩BAR TH174- Réno Globale (Previsite_Residentiel1).
- Pistes, « Type de dossier » : 🟩BAT TH142- Déstratificateurs (VR_Lead_TypeDeDossier_CoherenceRecordTyp).
- Dossiers, « Type- Fiche CEE » : 🟩AGRI EQ112- DParois (Statut_Dossier_1 à 4).

### Écarts entre le message actuel et la formule

Le message proposé suit la formule. Dites-moi si c'est la formule qui est fausse.

- Dossiers, LEDS_Qte_INF : le message annonce 50 LEDS minimum en agriculture et 20 ailleurs ; la formule contrôle 20 et 12.
- Dossiers, PAC_RAC_8 : avec kit, 🟪VIOLET à partir de 90 m² est contrôlé à 6 500 €, alors que « 4 500 € + 1 500 € » ferait 6 000 €.
- Pistes, Conversion_REMPLISSAGE_PAC060 : « RES- Shab » bloquée au-delà de 225 m², alors que le calculateur RES060 va jusqu'à 230 m².
- Pistes, CONFIRM_TRAITEMENT3 : la règle regarde l'ancienne valeur de « CONFIRM- Traitement », pas la nouvelle.
- Pistes, BASE_ITE_ENVOYE_EN_CONF : parenthèses mal fermées, le bloc « LEADS- Statut » est imbriqué dans le bloc BD.RENO.
- Dossiers, GLOBAL_METTRE_NON_APRES_CONVERSION : toutes les branches testent « LEDS EQ127- Création Dossier ».
- Dossiers, DEVIS_Date_Signature : la branche DESTRAT vise un type d'enregistrement « PRO_DESTRAT » absent de la liste, et teste « LEDS- Validation Client » sur la valeur technique 🟩Signé, dont le libellé est 🟦En Attente Date.

### Libellés qui peuvent prêter à confusion

- Pistes : deux champs portent le même libellé « AGRI- Infos Chantier 108 » (l'un sert à PAC TH108, l'autre à TUBES EQ108).
- Pistes : le champ technique « Ann_e_de_la_Chaudiere » s'appelle « RES- Année de la Maison » à l'écran ; les explications suivent le libellé.
- Pistes : le libellé du statut standard de la piste (Qualifié / Non qualifié) n'a pas pu être lu ; à corriger s'il est affiché autrement.
