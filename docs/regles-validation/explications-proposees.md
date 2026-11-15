# Règles de validation — explications et messages proposés

Source : production, lecture seule, le 11/11/2026. **Rien n'a été modifié dans Salesforce.**

- Deux champs seraient changés par règle : la **Description** (visible des administrateurs) et le **Message d'erreur** (affiché à l'utilisateur).
- Les formules, l'état actif / inactif et l'emplacement du message ne changent pas.
- Les champs et les valeurs sont écrits avec leur **libellé à l'écran**, pas leur nom technique.
- Limite Salesforce : 255 caractères par texte.

## Pistes — 72 règles

### 1. BASEDONNEES_SOUS_STATUT_NULL

Message affiché en haut de la page.

|                     | Aujourd'hui                                  | Proposé                                                                                                                                 |
| ------------------- | -------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Le statut de traitement ne peut pas etre nul | Anti-vidage : une fois remplis, « BD.ITE- Sous Statut », « BD.RENO- Statut » et « MPR*DOCS » ne peuvent plus être remis à vide.         |
| Message utilisateur | Le statut de traitement ne peut pas etre nul | Ce champ ne peut pas être remis à vide : merci de choisir une valeur pour « BD.ITE- Sous Statut », « BD.RENO- Statut » ou « MPR*DOCS ». |

### 2. BASE_ITE_DATA

Message affiché en haut de la page.

|                     | Aujourd'hui                                                                       | Proposé                                                                                                                                                            |
| ------------------- | --------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Description         | Merci de renseigner le Télépro la date de rappel et le commentaire.               | « BD.ITE- Sous Statut » ou « BD.RENO- Statut » = 🟦A RAPPELER : « TELEPRO- Date de Rappel », « TELEPRO- Creneau Rappel » et « TELEPRO- Commentaire » obligatoires. |
| Message utilisateur | Merci de renseigner le Télépro la date, le creneau et et le commentaire de rappel | Pour mettre 🟦A RAPPELER, merci de remplir « TELEPRO- Date de Rappel », « TELEPRO- Creneau Rappel » et « TELEPRO- Commentaire ».                                   |

### 3. BASE_ITE_ENVOYE_EN_CONF

Message affiché sous le champ « LOOKUP- Telepro ».

|                     | Aujourd'hui                                                                                                                                    | Proposé                                                                                                                                                                                                                           |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Il faut que le Lookup soit égale au Télépro pour mettre envoyer en conf                                                                        | 🟩ENVOYÉ EN CONF par un télépro : « LOOKUP- Telepro » doit être l'utilisateur connecté (Télépro Data sur BD.ITE, Télépro Leads sur BD.RENO) ; pour Télépro Leads, « CONFIRM- Traitement » doit aussi être ▣ EN ATT DE TRAITEMENT. |
| Message utilisateur | Pour envoyer en confirmation, il faut que le Lookup du telepro soit rempli et que le champs CONFIRM- Traitement soit en ▣ EN ATT DE TRAITEMENT | Pour mettre 🟩ENVOYÉ EN CONF, « LOOKUP- Telepro » doit être à votre nom et « CONFIRM- Traitement » doit être sur ▣ EN ATT DE TRAITEMENT.                                                                                          |

### 4. BASE_ITE_ENVOYE_EN_CONF2

Message affiché sous le champ « CONFIRM- Date de Rappel ».

|                     | Aujourd'hui                                                                                                         | Proposé                                                                                                                                                                                                      |
| ------------------- | ------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Description         | Pour envoyer en confirmation, il faut que le commentaire de rappel soient rempli.                                   | 🟩ENVOYÉ EN CONF par un Télépro Data : sur BD.ITE, « TELEPRO- Commentaire » obligatoire ; sur BD.RENO, « CONFIRM- Date de Rappel », « CONFIRM- Créneau de Rappel » et « TELEPRO- Commentaire » obligatoires. |
| Message utilisateur | Pour envoyer en confirmation, il faut que la date, le creneau de rappel et le "Télépro- Commentaire" soient rempli. | Pour mettre 🟩ENVOYÉ EN CONF, merci de remplir « CONFIRM- Date de Rappel », « CONFIRM- Créneau de Rappel » et « TELEPRO- Commentaire ».                                                                      |

### 5. BASE_ITE_ENVOYE_EN_CONF3

Message affiché sous le champ « LOOKUP- Confirmateur ».

|                     | Aujourd'hui                                                   | Proposé                                                                                                                  |
| ------------------- | ------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| Description         | _(vide)_                                                      | « BD.ITE- Sous Statut » ou « BD.RENO- Statut » = 🟩ENVOYÉ EN CONF (tous profils) : « LOOKUP- Confirmateur » obligatoire. |
| Message utilisateur | Merci de remplir le Lookup Confirmateur pour envoyer en Conf. | Pour mettre 🟩ENVOYÉ EN CONF, merci de remplir « LOOKUP- Confirmateur ».                                                 |

### 6. BASE_ITE_RAPPEL

Message affiché sous le champ « LOOKUP- Telepro ».

|                     | Aujourd'hui                                                        | Proposé                                                                                                                                                                    |
| ------------------- | ------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Il faut que le Lookup soit égale au Télépro pour mettre a rappeler | Profil Télépro Leads : pour mettre 🟦A RAPPELER (« BD.ITE- Sous Statut », « BD.RENO- Statut » ou « LEADS- Statut »), « LOOKUP- Telepro » doit être l'utilisateur connecté. |
| Message utilisateur | Il faut que le Lookup soit égale au Télépro pour mettre a rappeler | Pour mettre 🟦A RAPPELER, « LOOKUP- Telepro » doit être à votre nom.                                                                                                       |

### 7. BLOCAGE_Champs_Apres_SIgnature

Message affiché en haut de la page.

|                     | Aujourd'hui       | Proposé                                                                                                                                      |
| ------------------- | ----------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | _(vide)_          | Une fois « RES- Statut Devis » = 🟩Signé, « DEVIS- Nombre de capteurs » et « DEVIS- Surface de toiture (m²) » ne peuvent plus être modifiés. |
| Message utilisateur | Devis déjà signé. | Devis déjà signé : « DEVIS- Nombre de capteurs » et « DEVIS- Surface de toiture (m²) » ne peuvent plus être modifiés.                        |

### 8. Block_AutreQueProLeds

Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                             | Proposé                                                                                                                                                                                                                                 |
| ------------------- | ------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Si vous souhaitez travailler sur une autre fiche avec nous, Merci de contacter Mike par Whatsapp, Merci | Liste d'une trentaine d'utilisateurs de régies externes (repérés par leur identifiant de connexion) : ils ne peuvent enregistrer que des pistes Régies LEDS (« Tech_typeEnregistrement » = RegiesLeds) ; toute autre fiche est bloquée. |
| Message utilisateur | Si vous souhaitez travailler sur une autre fiche avec nous, Merci de contacter Mike par Whatsapp, Merci | Votre accès est limité aux fiches Régies LEDS. Pour travailler sur un autre type de fiche avec nous, merci de contacter Mike par WhatsApp.                                                                                              |

### 9. Block_AutreQueProLeds2

Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                                        | Proposé                                                                                                                   |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| Description         | Si vous souhaitez travailler sur une autre fiche avec nous, Merci de contacter Mike par Whatsapp, Merci                            | Bloque tout enregistrement de piste par le profil PORTAIL INTERNE- REGIES : les régies doivent passer par le nouveau CRM. |
| Message utilisateur | Si vous souhaitez travailler sur une autre fiche avec nous, Vous devez passer par le nouveau CRM, demandez nous un acces,<br>Merci | Ce portail n'est plus utilisé par les régies : merci de passer par le nouveau CRM (demandez-nous un accès).               |

### 10. CALCUL_SHAB_163_179

Message affiché sous le champ « BAT- Surf Total Batiment ».

|                     | Aujourd'hui                                                                      | Proposé                                                                                                                                             |
| ------------------- | -------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Il faut que le cumul des surface soit coherente a la surface totale du batiment. | Dès qu'une surface est saisie, « PAC 179- Surf Chauffé PAC 163 » + « PAC 179- Surf Chauffé PAC 179 » doit être égal à « BAT- Surf Total Batiment ». |
| Message utilisateur | Il faut que le cumul des surface soit coherente a la surface totale du batiment. | Surfaces incohérentes : « PAC 179- Surf Chauffé PAC 163 » + « PAC 179- Surf Chauffé PAC 179 » doit être égal à « BAT- Surf Total Batiment ».        |

### 11. CONFIRM_TRAITEMENT

Message affiché sous le champ « CONFIRM- Traitement ».

|                     | Aujourd'hui                                                         | Proposé                                                                                                                                                                           |
| ------------------- | ------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Bloque les selections aux autres profils que le confirmateur        | « CONFIRM- Traitement » : les valeurs vide, 🟨 NRP- 1x à 4x et rappel sont réservées aux profils Confirmateur (y compris PRO LEDS et PRO LEDS/DESTRAT) et Administrateur système. |
| Message utilisateur | Le confirmateur uniquement est autorisé à utiliser cette séléction. | Seul le confirmateur peut choisir cette valeur de « CONFIRM- Traitement » (vide, 🟨 NRP ou rappel).                                                                               |

### 12. CONFIRM_TRAITEMENT2

Message affiché sous le champ « CONFIRM- Traitement ».

|                     | Aujourd'hui                                                                                                                                                       | Proposé                                                                                                                                                                                          |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Description         | Bloque les selections aux autres profils que le confirmateur                                                                                                      | Seul le profil Confirmateur peut remettre « CONFIRM- Traitement » sur ▣ EN ATT DE TRAITEMENT quand la valeur précédente était 🟦DEVIS GÉNÉRÉ, 🟩SIGNÉ (valeurs désactivées) ou un ⬛ HORS CIBLE. |
| Message utilisateur | Vous n'êtes pas autorisé à remettre ce statut si il y a eu un devis de généré,signé ou si le dossier a été annulé, merci de demander au confirmateur directement. | Vous ne pouvez pas remettre ▣ EN ATT DE TRAITEMENT après un devis généré, un devis signé ou un hors cible : merci de demander au confirmateur.                                                   |

### 13. CONFIRM_TRAITEMENT3

Message affiché en haut de la page.

|                     | Aujourd'hui                                           | Proposé                                                                                                                                                             |
| ------------------- | ----------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Pour mettre en annulé, il faut mettre un commentaire. | Pistes AA- RESIDENTIEL- EXTERNE : « CONFIRM- Commentaire » obligatoire quand la valeur précédente de « CONFIRM- Traitement » était ⬛ HORS CIBLE- Voir commentaire. |
| Message utilisateur | Pour mettre en annulé, il faut mettre un commentaire. | ⬛ HORS CIBLE- Voir commentaire : merci de remplir « CONFIRM- Commentaire ».                                                                                        |

### 14. CONF_DATE_GENERATION

Message affiché sous le champ « CONFIRM- Géneration Devis ».

|                     | Aujourd'hui                                                                   | Proposé                                                                                                               |
| ------------------- | ----------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| Description         | Pour mettre en Devis Généré, merci de remplir la date de génération du devis. | « CONFIRM- Traitement » = 🟦DEVIS GÉNÉRÉ (valeur désactivée) : la date « CONFIRM- Géneration Devis » est obligatoire. |
| Message utilisateur | Pour mettre en Devis Généré, merci de remplir la date de génération du devis. | Pour mettre 🟦DEVIS GÉNÉRÉ, merci de remplir la date « CONFIRM- Géneration Devis ».                                   |

### 15. Champs_DATE_DE_RAPPEL

Message affiché sous le champ « TELEPRO- Date de Rappel ».

|                     | Aujourd'hui                                                               | Proposé                                                                                                                                                     |
| ------------------- | ------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Veuillez renseigner la Date et l'Heure de Rappel                          | Profil Télépro Leads, « LEADS- Statut » = 🟦A RAPPELER : « TELEPRO- Date de Rappel », « TELEPRO- Creneau Rappel » et « TELEPRO- Commentaire » obligatoires. |
| Message utilisateur | Veuillez renseigner la Date et l'Heure et mettre un commentaire de Rappel | Pour mettre 🟦A RAPPELER, merci de remplir « TELEPRO- Date de Rappel », « TELEPRO- Creneau Rappel » et « TELEPRO- Commentaire ».                            |

### 16. Champs_DATE_DE_RAPPEL2

Message affiché sous le champ « TELEPRO- Date de Rappel ».

|                     | Aujourd'hui                                                               | Proposé                                                                                                                                                                                        |
| ------------------- | ------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Veuillez renseigner la Date et l'Heure de Rappel Pour la signature        | « LEADS- Statut » = 🟪A RAPPELER- POUR SIGNATURE !! (valeur absente de la liste actuelle) : « TELEPRO- Date de Rappel », « TELEPRO- Creneau Rappel » et « TELEPRO- Commentaire » obligatoires. |
| Message utilisateur | Veuillez renseigner la Date et l'Heure et mettre un commentaire de Rappel | Rappel pour signature : merci de remplir « TELEPRO- Date de Rappel », « TELEPRO- Creneau Rappel » et « TELEPRO- Commentaire ».                                                                 |

### 17. Champs_DATE_DE_RAPPEL3

Message affiché sous le champ « CONFIRM- Date de Rappel ».

|                     | Aujourd'hui                                                       | Proposé                                                                                                                                                |
| ------------------- | ----------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Description         | Veuillez renseigner la Date et l'Heure de Rappel.                 | « CONFIRM- Traitement » = 🟦 Rappel Nécessaire : « CONFIRM- Date de Rappel », « CONFIRM- Créneau de Rappel » et « CONFIRM- Commentaire » obligatoires. |
| Message utilisateur | Veuillez renseigner la Date, l'Heure et le commentaire de Rappel. | Pour mettre 🟦 Rappel Nécessaire, merci de remplir « CONFIRM- Date de Rappel », « CONFIRM- Créneau de Rappel » et « CONFIRM- Commentaire ».            |

### 18. Code_Postal_Obligatoire_Pour_conversion

Message affiché en haut de la page.

|                     | Aujourd'hui                                      | Proposé                                                                                                    |
| ------------------- | ------------------------------------------------ | ---------------------------------------------------------------------------------------------------------- |
| Description         | _(vide)_                                         | Conversion de la piste en dossier : le code postal de l'adresse doit être rempli et composé de 5 chiffres. |
| Message utilisateur | Veuillez remplir le code postal avant conversion | Avant de convertir, merci de saisir un code postal à 5 chiffres dans l'adresse.                            |

### 19. Conversion_REMPLISSAGE_168

Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                                                                                                                                                           | Proposé                                                                                                                                                                                                                                                       |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Veuillez remplir tout les champs si vous souhaitez Convertir.2                                                                                                                                                                                        | Conversion RES168 (✅- OUI) : Adresse, Email, Téléphone, « CONFIRM- Commentaire », RES- Précarité, Année de la Maison, Kit Bizone, Statut Occupation, Type de radiateur (hors ❌Fonte), Type parcours, Shab, toiture, capteurs. ✅CEE + MPR : maison +15 ans. |
| Message utilisateur | 1.TH168- Veuillez remplir tout les champs lié à votre produit si vous souhaitez Convertir.<br>2.Commentaire Confirmateur Obligatoire. + si 30% fonte alors MPR obligatoire<br>3.Si MPR alors maison obligatoirement +15ans<br>4.Prévisite obligatoire | RES168, pour convertir : Adresse, Email, Téléphone, « CONFIRM- Commentaire » et tous les champs RES et DEVIS du produit. « RES- Type de radiateur » ❌Fonte refusé. Parcours ✅CEE + MPR : maison de plus de 15 ans obligatoire.                              |

### 20. Conversion_REMPLISSAGE_DESHUTH117

Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                                        | Proposé                                                                                                                                                                                                                                              |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Veuillez remplir tout les champs si vous souhaitez Convertir.2                                                                     | Conversion PAC TH108 (✅- OUI) : Adresse, Email, Téléphone, PRO- Raison Sociale, Nom+Prenom / Fonction / Email / Téléphone Signataire, Siret, Code APE, Siege Social Adresse, « CONFIRM- Commentaire » et « AGRI- Infos Chantier 108 » obligatoires. |
| Message utilisateur | TH108- Veuillez remplir tout les champs lié à votre produit si vous souhaitez Convertir.<br>+ Commentaire Confirmateur Obligatoire | PAC TH108, pour convertir : Adresse, Email, Téléphone, tous les champs PRO (Raison Sociale, Signataire, Siret, Code APE, Siege Social), « AGRI- Infos Chantier 108 » et « CONFIRM- Commentaire ».                                                    |

### 21. Conversion_REMPLISSAGE_DESTRATTH142

Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                                        | Proposé                                                                                                                                                                                                                                                      |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Description         | Veuillez remplir tout les champs si vous souhaitez Convertir                                                                       | Conversion DESTRAT TH142 (✅- OUI) : Adresse, Email, Téléphone, « CONFIRM- Commentaire », champs PRO (Raison Sociale, Signataire, Siret, APE, Siege Social), BAT- Surf Total Batiment, Type de Chauffage, Puissance Chauffage(KW) ; Hauteur Minimum = 🟩+5m. |
| Message utilisateur | TH142- Veuillez remplir tout les champs lié à votre produit si vous souhaitez Convertir.<br>+ Commentaire Confirmateur Obligatoire | DESTRAT TH142, pour convertir : Adresse, Email, Téléphone, champs PRO, « BAT- Surf Total Batiment », « BAT- Type de Chauffage », « DESTRAT 142- Puissance Chauffage(KW) », « CONFIRM- Commentaire ». « DESTRAT 142- Hauteur Minimum » : 🟩+5m.               |

### 22. Conversion_REMPLISSAGE_DPAROEQ112

Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                                        | Proposé                                                                                                                                                                                                                                                  |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Veuillez remplir tout les champs si vous souhaitez Convertir.2                                                                     | Conversion Séchage EQ110 (✅- OUI) : Adresse, Email, Téléphone, PRO- Raison Sociale, Nom+Prenom / Fonction / Email / Téléphone Signataire, Siret, Code APE, Siege Social Adresse, « AGRI- Infos Chantier 110 » et « CONFIRM- Commentaire » obligatoires. |
| Message utilisateur | EQ112- Veuillez remplir tout les champs lié à votre produit si vous souhaitez Convertir.<br>+ Commentaire Confirmateur Obligatoire | Séchage EQ110, pour convertir : Adresse, Email, Téléphone, tous les champs PRO (Raison Sociale, Signataire, Siret, Code APE, Siege Social), « AGRI- Infos Chantier 110 » et « CONFIRM- Commentaire ».                                                    |

### 23. Conversion_REMPLISSAGE_LEDSEQ127

Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                                       | Proposé                                                                                                                                                                                                                                         |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Veuillez remplir tout les champs si vous souhaitez Convertir.2                                                                    | Conversion LEDS EQ127 (✅- OUI) : Adresse, Email, Téléphone, « CONFIRM- Commentaire », PRO- Raison Sociale, PRO- Numero de Siret, BAT- Surf Total Batiment, BAT- Type de Chauffage, LEDS 127- Validation Client et LEDS 127- Type Installation. |
| Message utilisateur | LEDS- Veuillez remplir tout les champs lié à votre produit si vous souhaitez Convertir.<br>+ Commentaire Confirmateur Obligatoire | LEDS EQ127, pour convertir : Adresse, Email, Téléphone, « PRO- Raison Sociale », « PRO- Numero de Siret », « BAT- Surf Total Batiment », « BAT- Type de Chauffage », les deux champs LEDS 127 et « CONFIRM- Commentaire ».                      |

### 24. Conversion_REMPLISSAGE_PAC060

Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                                                                                                         | Proposé                                                                                                                                                                                                                                                           |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Veuillez remplir tout les champs si vous souhaitez Convertir.2                                                                                                                                      | Conversion PAC RES060 (✅- OUI) : Adresse, Email, Téléphone, « CONFIRM- Commentaire », champs RES (années, Statut Occupation, Medianería, Kit Bizone), Shab de 50 à 225 m² ; PREVISITE- Nécessité = ✅- OUI ; bloqué si retour calculateur « Sans envoi visite ». |
| Message utilisateur | RES060- Veuillez remplir tout les champs lié à votre produit si vous souhaitez Convertir.<br>+ Commentaire Confirmateur Obligatoire.<br>+ La SHAB doit être 50 et 225m²<br>+ Pré-visite obligatoire | RES060, pour convertir : Adresse, Email, Téléphone, « CONFIRM- Commentaire » et tous les champs RES / RES060. « RES- Shab » entre 50 et 225 m². « PREVISITE- Nécessité » sur ✅- OUI. Bloqué si le retour calculateur indique « Sans envoi visite ».              |

### 25. Conversion_REMPLISSAGE_PAC171

Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                                                                                      | Proposé                                                                                                                                                                                                                                 |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Veuillez remplir tout les champs si vous souhaitez Convertir.2                                                                                                                   | Conversion PAC TH171 (✅- OUI) : Adresse, Email, Téléphone, « CONFIRM- Commentaire », RES- Précarité, RES- Kit Bizone, RES- Statut Occupation, RES- Shab (70 m² minimum) obligatoires ; « RES- Année de la Maison » = 🟩Plus de 15 ans. |
| Message utilisateur | TH171- Veuillez remplir tout les champs lié à votre produit si vous souhaitez Convertir.<br>+ Commentaire Confirmateur Obligatoire.<br>La SHAB ne doit pas etre inferieur a 70m² | TH171, pour convertir : Adresse, Email, Téléphone, « CONFIRM- Commentaire », « RES- Précarité », « RES- Kit Bizone », « RES- Statut Occupation » et « RES- Shab » (70 m² minimum). « RES- Année de la Maison » : 🟩Plus de 15 ans.      |

### 26. Conversion_REMPLISSAGE_PACTH163

Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                                        | Proposé                                                                                                                                                                                                                                                       |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Veuillez remplir tout les champs si vous souhaitez Convertir.2                                                                     | Conversion PAC TH163 (✅- OUI) : Adresse, Email, Téléphone, champs PRO (Raison Sociale, Signataire, Siret, Code APE, Siege Social), « CONFIRM- Commentaire », BAT- Surf Total Batiment, BAT- Type de Chauffage et « PAC 163- Surf Chauffé PAC » obligatoires. |
| Message utilisateur | TH163- Veuillez remplir tout les champs lié à votre produit si vous souhaitez Convertir.<br>+ Commentaire Confirmateur Obligatoire | TH163, pour convertir : Adresse, Email, Téléphone, tous les champs PRO, « BAT- Surf Total Batiment », « BAT- Type de Chauffage », « PAC 163- Surf Chauffé PAC » et « CONFIRM- Commentaire ».                                                                  |

### 27. Conversion_REMPLISSAGE_RENO_174

Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                                   | Proposé                                                                                                                                                                                                                          |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Veuillez remplir tout les champs si vous souhaitez Convertir.2                                                                | Conversion RENO TH174 (✅- OUI) : Adresse, Email, Téléphone, « CONFIRM- Commentaire », RES- Précarité, RES- Statut Occupation, « RENO 174- Travaux » et RES- Shab obligatoires ; « RES- Année de la Maison » = 🟩Plus de 15 ans. |
| Message utilisateur | TH174- Veuillez remplir tout les champs lié à la TH174 si vous souhaitez Convertir.<br>+ Commentaire Confirmateur Obligatoire | TH174, pour convertir : Adresse, Email, Téléphone, « CONFIRM- Commentaire », « RES- Précarité », « RES- Statut Occupation », « RENO 174- Travaux » et « RES- Shab ». « RES- Année de la Maison » : 🟩Plus de 15 ans.             |

### 28. Conversion_REMPLISSAGE_RENO_179

Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                                                                                                                                                | Proposé                                                                                                                                                                                                                                                  |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Veuillez remplir tout les champs si vous souhaitez Convertir.2                                                                                                                                                                             | Conversion PAC TH179 (✅- OUI) : Adresse, Email, Téléphone, champs PRO, « CONFIRM- Commentaire », BAT- Type de Chauffage, Surf Total Batiment et tous les champs PAC 179. Toujours : Surf Chauffé PAC 163 remplie si Presence 163 = ✅- OUI, vide sinon. |
| Message utilisateur | 1.TH179- Veuillez remplir tout les champs lié à la votre produit si vous souhaitez Convertir.<br>+ Commentaire Confirmateur Obligatoire.<br>2.Si Présence 163, remplir le champs de surface, si sans présence de 163 alors le laisser vide | TH179, pour convertir : Adresse, Email, Téléphone, champs PRO, BAT et PAC 179, « CONFIRM- Commentaire ». « PAC 179- Surf Chauffé PAC 163 » : à remplir si « PAC 179- Presence 163 » = ✅- OUI, à laisser vide sinon.                                     |

### 29. Conversion_REMPLISSAGE_TUBESEQ108

Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                                        | Proposé                                                                                                                                                                                                                                                |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Description         | Veuillez remplir tout les champs si vous souhaitez Convertir.2                                                                     | Conversion TUBES EQ108 (✅- OUI) : Adresse, Email, Téléphone, PRO- Raison Sociale, Nom+Prenom / Fonction / Email / Téléphone Signataire, Siret, Code APE, Siege Social Adresse, « CONFIRM- Commentaire » et « AGRI- Infos Chantier 108 » obligatoires. |
| Message utilisateur | EQ108- Veuillez remplir tout les champs lié à votre produit si vous souhaitez Convertir.<br>+ Commentaire Confirmateur Obligatoire | TUBES EQ108, pour convertir : Adresse, Email, Téléphone, tous les champs PRO (Raison Sociale, Signataire, Siret, Code APE, Siege Social), « AGRI- Infos Chantier 108 » et « CONFIRM- Commentaire ».                                                    |

### 30. Conversion_REMPLISSAGE_VMCTH119

Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                                        | Proposé                                                                                                                                                                                                                                              |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Veuillez remplir tout les champs si vous souhaitez Convertir.2                                                                     | Conversion VMC TH119 (✅- OUI) : Adresse, Email, Téléphone, PRO- Raison Sociale, Nom+Prenom / Fonction / Email / Téléphone Signataire, Siret, Code APE, Siege Social Adresse, « CONFIRM- Commentaire » et « AGRI- Infos Chantier 119 » obligatoires. |
| Message utilisateur | TH119- Veuillez remplir tout les champs lié à votre produit si vous souhaitez Convertir.<br>+ Commentaire Confirmateur Obligatoire | VMC TH119, pour convertir : Adresse, Email, Téléphone, tous les champs PRO (Raison Sociale, Signataire, Siret, Code APE, Siege Social), « AGRI- Infos Chantier 119 » et « CONFIRM- Commentaire ».                                                    |

### 31. Conversion_REMPLISSAGE_unproduitminimum

Message affiché en haut de la page.

|                     | Aujourd'hui                                 | Proposé                                                                                                             |
| ------------------- | ------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| Description         | Il faut au moins un produit pour convertir  | Passage de la piste en Qualifié (conversion) : au moins un des 12 champs « … - Création Dossier » doit être rempli. |
| Message utilisateur | Il faut au moins un produit pour convertir. | Il faut au moins un produit pour convertir : merci de remplir un champ « Création Dossier ».                        |

### 32. Conversion_VerificationAGRI — règle inactive

Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                 | Proposé                                                                                                                                                             |
| ------------------- | ----------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | _(vide)_                                                                                                    | AGRI : si l'un des champs « Création Dossier » PAC TH108, VMC TH119 ou TUBES EQ108 est rempli, les trois doivent l'être ; ils ne peuvent pas être tous sur ❌- NON. |
| Message utilisateur | AGRICULTURE<br>Vous avez au moins un champs de produit qui est vide,<br>Ou vous avez tout les champs en NON | AGRICULTURE : merci de remplir les trois champs « Création Dossier » (PAC TH108, VMC TH119, TUBES EQ108), avec au moins un ✅- OUI.                                 |

### 33. Conversion_VerificationMELANGE

Message affiché en haut de la page.

|                     | Aujourd'hui                                             | Proposé                                                                                                                                                                                             |
| ------------------- | ------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Vous ne pouvez pas mélanger PRO/RESIDENTIE/AGRICULTURE. | Interdit de mélanger les familles sur une piste : tertiaire (PAC TH163, PAC TH179, DESTRAT TH142), résidentiel (PAC TH171, RES168, PAC RES060, RENO TH174) et agriculture (PAC TH108, TUBES EQ108). |
| Message utilisateur | Vous ne pouvez pas mélanger PRO/RESIDENTIE/AGRICULTURE. | Vous ne pouvez pas mélanger tertiaire, résidentiel et agriculture sur une même fiche : gardez les champs « Création Dossier » d'une seule famille.                                                  |

### 34. Conversion_VerificationRESIDENTIEL — règle inactive

Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                 | Proposé                                                                                                                                                           |
| ------------------- | ----------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | _(vide)_                                                                                                    | RÉSIDENTIEL : « PAC TH171- Création Dossier » et « PAC RES060- Création Dossier » doivent être remplis ensemble et ne peuvent pas être tous les deux sur ❌- NON. |
| Message utilisateur | RESIDENTIEL<br>Vous avez au moins un champs de produit qui est vide,<br>Ou vous avez tout les champs en NON | RÉSIDENTIEL : merci de remplir « PAC TH171- Création Dossier » et « PAC RES060- Création Dossier », avec au moins un ✅- OUI.                                     |

### 35. Conversion_VerificationTERTIAIRE

Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                                                                             | Proposé                                                                                                                                                                                |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | _(vide)_                                                                                                                                                                | TERTIAIRE : si l'un des champs « Création Dossier » PAC TH163, PAC TH179 ou DESTRAT TH142 est rempli, les trois doivent l'être ; pas tous sur ❌- NON ; un seul sur ✅- OUI par piste. |
| Message utilisateur | TERTIAIRE<br>1.Vous avez au moins un champs de produit qui est vide,<br>2.Ou vous avez tout les champs en NON<br>2. Vous pouvez avoir qu'un produit à la fois par fiche | TERTIAIRE : merci de remplir les trois champs « Création Dossier » (PAC TH163, PAC TH179, DESTRAT TH142), avec un seul ✅- OUI par fiche.                                              |

### 36. Convertir_1 — règle inactive

Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                                                                             | Proposé                                                                                                                                                   |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Veuillez remplir les champs Commentaire telepro et Disponibilité, Commentaire pour Confirmateur et heure de rappel pour Confirmateur client si vous souhaitez Convertir | Ancienne règle basée sur « Type de Dossier v3 » (Vélos Cargos, 🟩RES- TH171- PAC, 🟨DATA, TH 174) : champs obligatoires pour passer la piste en Qualifié. |
| Message utilisateur | Veuillez remplir tout les champs si vous souhaitez Convertir.                                                                                                           | Merci de remplir tous les champs liés à votre type de dossier avant de convertir.                                                                         |

### 37. Convertir_2 — règle inactive

Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                         | Proposé                                                                                                                                                                                                      |
| ------------------- | ------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Description         | Veuillez remplir tout les champs si vous souhaitez Convertir.2                                                      | Ancienne règle de conversion DESTRAT TH142, PAC TH171 et RENO TH174 (✅- OUI ou ✅- Avec Prévisite🚗) : coordonnées, champs PRO, surface et chauffage obligatoires, « TYPE DE DOSSIER » = ▣ Nouveau Dossier. |
| Message utilisateur | Veuillez remplir tout les champs si vous souhaitez Convertir.256.<br>Mettre un Commentaire obligatoire pour le LEDS | Merci de remplir tous les champs liés à votre produit avant de convertir (coordonnées, champs PRO, surface, chauffage).                                                                                      |

### 38. Convertir_3 — règle inactive

Message affiché en haut de la page.

|                     | Aujourd'hui                                                    | Proposé                                                                                                                                                                                                               |
| ------------------- | -------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Veuillez remplir tout les champs si vous souhaitez Convertir.3 | Ancienne règle de conversion PAC TH179 (✅- OUI ou ✅- Avec Prévisite🚗) : coordonnées, champs PRO, « BAT- Surf Total Batiment » et « BAT- Type de Chauffage » obligatoires, « TYPE DE DOSSIER » = ▣ Nouveau Dossier. |
| Message utilisateur | Veuillez remplir tout les champs si vous souhaitez Convertir.3 | Merci de remplir tous les champs liés à votre produit avant de convertir (coordonnées, champs PRO, surface, chauffage).                                                                                               |

### 39. Convertir_4 — règle inactive

Message affiché sous le champ « LEDS 127- Type Installation ».

|                     | Aujourd'hui                            | Proposé                                                                                                                                                                                |
| ------------------- | -------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | En Regie, on ne fait pas la livraison. | Ancienne règle LEDS en régie : à la conversion d'une piste dont « LOOKUP-REGIE » est rempli, « LEDS 127- Type Installation » doit être ✅HORS AGRICULTURE (pas de livraison en régie). |
| Message utilisateur | En Regie, on ne fait pas la livraison. | En régie, nous ne faisons pas la livraison : « LEDS 127- Type Installation » doit être ✅HORS AGRICULTURE.                                                                             |

### 40. Convertir_au_nom_du_proprietaire

Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                             | Proposé                                                                                                                                                               |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Vous ne pouvez pas convertir l'enregistrement, veuillez vérifier que le "Telepro" est le propriétaire de la piste.      | « Type de Dossier v3 » = 🟩RES- TH171- PAC, 🟨DATA ou TH 174 : au passage en Qualifié, le propriétaire de la piste doit être la personne du « LOOKUP- Confirmateur ». |
| Message utilisateur | Vous ne pouvez pas convertir l'enregistrement, veuillez vérifier que le "Confirmateur" est le propriétaire de la piste. | Conversion impossible : le propriétaire de la piste doit être le confirmateur indiqué dans « LOOKUP- Confirmateur ».                                                  |

### 41. Creation_piste_lookuo

Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                  | Proposé                                                                                                                                                                                                                                |
| ------------------- | -------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Pour creer une nouvelle piste, il faut que le lookup soit a ton nom.                         | Création d'une piste : un Confirmateur doit se mettre dans « LOOKUP- Confirmateur » et laisser « LOOKUP- Telepro » vide ; un Télépro (Data ou Leads) doit se mettre dans « LOOKUP- Telepro » et laisser « LOOKUP- Confirmateur » vide. |
| Message utilisateur | Pour creer une nouvelle piste, il faut que le lookup telepro ou confirmateur soit a ton nom. | Pour créer une piste, mettez-vous dans votre lookup (« LOOKUP- Telepro » ou « LOOKUP- Confirmateur ») et laissez l'autre vide.                                                                                                         |

### 42. LEAD_CHANGEMENT_STATUT

Message affiché sous le champ « LOOKUP- Telepro ».

|                     | Aujourd'hui                                                     | Proposé                                                                                                                                           |
| ------------------- | --------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Si changement de statut Lead alors mettre le Lookup à votre nom | Profil Télépro Leads : dès que « LEADS- Statut » est une valeur À RETRAITER (🟦A RAPPELER), « LOOKUP- Telepro » doit être l'utilisateur connecté. |
| Message utilisateur | Si changement de statut Lead alors mettre le Lookup à votre nom | Pour mettre ce « LEADS- Statut », « LOOKUP- Telepro » doit être à votre nom.                                                                      |

### 43. LEAD_CHANGEMENT_STATUT2

Message affiché sous le champ « LOOKUP- Telepro ».

|                     | Aujourd'hui                                                     | Proposé                                                                                                                              |
| ------------------- | --------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| Description         | Si changement de statut Lead alors mettre le Lookup à votre nom | Profil Télépro Leads : dès que « LEADS- Statut » est une valeur ⬛ HORS CIBLE, « LOOKUP- Telepro » doit être l'utilisateur connecté. |
| Message utilisateur | Si changement de statut Lead alors mettre le Lookup à votre nom | Pour mettre un ⬛ HORS CIBLE, « LOOKUP- Telepro » doit être à votre nom.                                                             |

### 44. LEAD_CHANGEMENT_STATUT3

Message affiché sous le champ « LOOKUP- Telepro ».

|                     | Aujourd'hui                                                     | Proposé                                                                                                                                                                          |
| ------------------- | --------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Si changement de statut Lead alors mettre le Lookup à votre nom | Profil Télépro Leads : dès que « LEADS- Statut » contient ENVOYÉ EN CONF (aucune valeur de ce nom dans la liste actuelle), « LOOKUP- Telepro » doit être l'utilisateur connecté. |
| Message utilisateur | Si changement de statut Lead alors mettre le Lookup à votre nom | Pour envoyer en conf, « LOOKUP- Telepro » doit être à votre nom.                                                                                                                 |

### 45. LEAD_ENVOI_CONF

Message affiché sous le champ « LOOKUP- Confirmateur ».

|                     | Aujourd'hui                                           | Proposé                                                                                                                                   |
| ------------------- | ----------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Si Envoi en Conf alors remplir le nom du Confirmateur | Profil Télépro Leads, « LEADS- Statut » = 🟩ENVOYÉ EN CONFF (valeur absente de la liste actuelle) : « LOOKUP- Confirmateur » obligatoire. |
| Message utilisateur | Si Envoi en Conf alors remplir le nom du Confirmateur | Pour envoyer en conf, merci de remplir « LOOKUP- Confirmateur ».                                                                          |

### 46. LEAD_ENVOI_CONF2

Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                                                          | Proposé                                                                                                                                                                                                                                 |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Pour envoyer en confirmation, il faut que le commentaire de rappel soient rempli.                                                                    | RES060, « LEADS- Statut » 🟩Envoyé En Signature (Télépro Leads) ou « CONFIRM- Traitement » 🟫Conf Ok- Visite en attente : Adresse, lookup, PAC RES060 ✅- OUI, ✅Proprietaire Occupant et tous les champs RES du produit obligatoires.  |
| Message utilisateur | 1.Pour envoyer en signature,Il faut que tout les champs soient remplis<br>2.Pour mettre en confimation ok,Il faut que tout les champs soient remplis | 🟩Envoyé En Signature ou 🟫Conf Ok- Visite en attente : Adresse, lookup, « PAC RES060- Création Dossier » ✅- OUI, ✅Proprietaire Occupant et champs RES (années, chauffage, Shab, zone, medianería, parcelle, isolation, bono social). |

### 47. LEAD_SOUS_STATUT_NULL — règle inactive

Message affiché sous le champ « LEADS- Statut ».

|                     | Aujourd'hui                             | Proposé                                                                                                         |
| ------------------- | --------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| Description         | Le statut du LEAD ne peut pas etre nul  | Anti-vidage : « LEADS- Statut » ne peut pas être remis à vide une fois rempli, sauf par le profil Confirmateur. |
| Message utilisateur | Le statut du LEAD ne peut pas etre nul. | « LEADS- Statut » ne peut pas être remis à vide : merci de choisir une valeur.                                  |

### 48. LOOKUPS_DEJA_ATTRIBUES

Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                                                                                                                            | Proposé                   |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------- |
| Description         | Les profils PORTAIL ne peuvent pas changer un lookup Confirmateur, Telepro ou Previsiteur deja rempli : personne ne prend le dossier d'un autre. Seuls les administrateurs et le responsable telepro peuvent le faire. | _inchangée (déjà claire)_ |
| Message utilisateur | Ce dossier est déjà attribué : le confirmateur, le télépro et le prévisiteur ne peuvent être changés.                                                                                                                  | _inchangé (déjà clair)_   |

### 49. MPR_RAC — règle inactive

Message affiché sous le champ « MPR*Montant RAC ».

|                     | Aujourd'hui                                                     | Proposé                                                                                                           |
| ------------------- | --------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| Description         | Si autre que bleu merci de remplir le montant du reste a charge | « RES- Précarité » = 🟨Jaune/Modeste, 🟪Violet/ Classique ou 🟥Rose/ Classique : « MPR*Montant RAC » obligatoire. |
| Message utilisateur | Si autre que bleu merci de remplir le montant du reste a charge | Précarité autre que 🟦Bleu/ Tres Modeste : merci de remplir « MPR*Montant RAC ».                                  |

### 50. Owner_diffrent_de_logged_in_user

Message affiché en haut de la page.

|                     | Aujourd'hui                                          | Proposé                                                                                                                                                                                                     |
| ------------------- | ---------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Veuillez modifier le propriétaire avant de convertir | Conversion hors 🟩BAR RES-060 PAC : l'utilisateur qui convertit doit être à la fois le propriétaire de la piste et la personne du « LOOKUP- Confirmateur ». Exception : le compte administrateur principal. |
| Message utilisateur | Veuillez modifier le propriétaire avant de convertir | Conversion impossible : vous devez être le propriétaire de la piste et figurer dans « LOOKUP- Confirmateur ». Merci de modifier le propriétaire avant de convertir.                                         |

### 51. PORTAIL_REGIE

Message affiché sous le champ « Type de Dossier v3 ».

|                     | Aujourd'hui                                             | Proposé                                                                                                    |
| ------------------- | ------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| Description         | Ce produit n'est pas disponible pour les régies, Merci  | Le profil PORTAIL INTERNE- REGIES ne peut pas choisir « Type de Dossier v3 » = 🟩TRA-EQ-131- Vélos Cargos. |
| Message utilisateur | Ce produit n'est pas disponible pour les régies, Merci. | Le produit Vélos Cargos n'est pas disponible pour les régies.                                              |

### 52. Previsite_1residentiel

Message affiché sous le champ « PREVISITE- Nécessité ».

|                     | Aujourd'hui                                                                                                                                                                                                         | Proposé                                                                                                                                                                                                                                                 |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Pour envoyer en previsite, Merci de mettre Passage demandé ou Passage Planifié.<br>Si le passage est demandé, la date doit être vide.<br>Si le passage est planifié, merci de renseigner une date.                  | Résidentiel hors RES-060. « PREVISITE- Nécessité » ❌- NON : ▣ Att Planification, sans Previsiteur, fiche ni date. ✅- OUI : 🟨Passage Demandé (Previsiteur + fiche, sans date) ou 🟧Passage Planifié (+ date). TH171 : « PREVISITE- Prise en charge ». |
| Message utilisateur | Pour envoyer en previsite, Merci de mettre Passage demandé ou Passage Planifié.<br>Si le passage est demandé, la date doit être vide.<br>Si le passage est planifié, merci de renseigner une date et une fiche CEE. | Prévisite ✅- OUI : 🟨Passage Demandé (« LOOKUP- Previsiteur » + « PREVISITE- Fiches Résidentiel », sans date) ou 🟧Passage Planifié (+ « PREVISITE- Date »). TH171 : « PREVISITE- Prise en charge ». ❌- NON : tout laisser vide.                      |

### 53. Previsite_2_agri

Message affiché sous le champ « PREVISITE- Nécessité ».

|                     | Aujourd'hui                                                                                                                                                                                                                                                | Proposé                                                                                                                                                                                                                                             |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Pour envoyer en previsite, Merci de mettre Passage demandé ou Passage Planifié.<br>Si le passage est demandé, la date doit être vide.<br>Si le passage est planifié, merci de renseigner une date.                                                         | Agri (AA- AGRI- INTERNE / EXTERNE). « PREVISITE- Nécessité » ❌- NON : ▣ Att Planification, sans Previsiteur, fiche ni date. ✅- OUI : 🟨Passage Demandé (fiche Agri, sans Previsiteur ni date) ou 🟧Passage Planifié (Previsiteur + fiche + date). |
| Message utilisateur | Pour envoyer en previsite, Merci de mettre Passage demandé ou Passage Planifié.<br>Si le passage est demandé, la fiche CEE rempli, la date vide et l'auditeur en nouveau dossier.<br>Si le passage est planifié, la fiche CEE, la date et auditeur rempli. | Prévisite ✅- OUI : 🟨Passage Demandé (« PREVISITE- Fiches Agri », sans « LOOKUP- Previsiteur » ni date) ou 🟧Passage Planifié (fiche, « LOOKUP- Previsiteur » et « PREVISITE- Date »). ❌- NON : tout laisser vide.                                |

### 54. Previsite_2_tertiaire

Message affiché sous le champ « PREVISITE- Nécessité ».

|                     | Aujourd'hui                                                                                                                                                                                        | Proposé                                                                                                                                                                                                                                       |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Pour envoyer en previsite, Merci de mettre Passage demandé ou Passage Planifié.<br>Si le passage est demandé, la date doit être vide.<br>Si le passage est planifié, merci de renseigner une date. | Tertiaire (AA- BAT- INTERNE / EXTERNE). « PREVISITE- Nécessité » ❌- NON : ▣ Att Planification, sans Previsiteur, fiche ni date. ✅- OUI : 🟨Passage Demandé (fiche Tertiaire, sans date) ou 🟧Passage Planifié (Previsiteur + fiche + date). |
| Message utilisateur | Pour envoyer en previsite, Merci de mettre Passage demandé ou Passage Planifié.<br>Si le passage est demandé, la date doit être vide.<br>Si le passage est planifié, merci de renseigner une date. | Prévisite ✅- OUI : 🟨Passage Demandé (« PREVISITE- Fiches Tertiaire », sans date) ou 🟧Passage Planifié (fiche, « LOOKUP- Previsiteur » et « PREVISITE- Date »). ❌- NON : tout laisser vide.                                                |

### 55. Previsite_Agri1

Message affiché sous le champ « PREVISITE- Fiches Tertiaire ».

|                     | Aujourd'hui                                                                                                    | Proposé                                                                                                                                         |
| ------------------- | -------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Merci de mettre en previsite, une fiche ou il y a une demande de création de dossier.                          | « PREVISITE- Fiches Agri » (🟩AGRI TH108- PAC, TH119- VMC, EQ108- Tubes) : le champ « Création Dossier » du même produit doit être sur ✅- OUI. |
| Message utilisateur | Si vous choisissez une fiche CEE en previsite il faut que la création dossier de cette fiche soit aussi en OUI | La fiche choisie dans « PREVISITE- Fiches Agri » doit avoir son champ « Création Dossier » sur ✅- OUI.                                         |

### 56. Previsite_Residentiel1

Message affiché sous le champ « PREVISITE- Fiches Résidentiel ».

|                     | Aujourd'hui                                                                                                                                                                                                      | Proposé                                                                                                                                                                                                                                       |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Merci de mettre en previsite, une fiche ou il y a une demande de création de dossier.                                                                                                                            | « PREVISITE- Fiches Résidentiel » : le produit choisi (TH174, TH168, TH171, RES-060) doit avoir « Création Dossier » = ✅- OUI ; et si « PREVISITE- Nécessité » = ✅- OUI, la fiche doit être celle du produit demandé (171, 168 ou RES-060). |
| Message utilisateur | 1.Si vous choisissez une fiche CEE en previsite il faut que la création dossier de cette fiche soit aussi en OUI<br>2.Si 171 mettre visite 171<br>3.Si 168 mettre visite 168<br>4.Si RES060 mettre visite RES060 | 1. La fiche choisie dans « PREVISITE- Fiches Résidentiel » doit avoir son champ « Création Dossier » sur ✅- OUI. 2. Produit TH171 : fiche TH171. Produit RES168 : fiche TH168. Produit RES060 : fiche RES-060.                               |

### 57. Previsite_Residentiel2 — règle inactive

Message affiché sous le champ « PREVISITE- Fiches Résidentiel ».

|                     | Aujourd'hui                                                                                        | Proposé                                                                                                                                                                               |
| ------------------- | -------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Si 171 et 174 alors                                                                                | PAC TH171 et RENO TH174 tous deux sur ✅- OUI : « PREVISITE- Statut » = 🟧Passage Planifié interdit (la prévisite se fait après la fin de la 171, donc 🟨Passage Demandé uniquement). |
| Message utilisateur | Si 171 et 174, la previsite se fait apres la fin de la 171- donc mettre uniquement passage demandé | TH171 + TH174 : la prévisite se fait après la fin de la 171, merci de mettre uniquement 🟨Passage Demandé.                                                                            |

### 58. Previsite_Residentiel3

Message affiché sous le champ « PREVISITE- Nécessité ».

|                     | Aujourd'hui                                                                                                                                                                                                                                   | Proposé                                                                                                                                                                                                                                            |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Si 171 et 174 alors                                                                                                                                                                                                                           | RENO TH174 ✅- OUI : « PREVISITE- Nécessité » = ✅- OUI obligatoire (profil Confirmateur). TH171 : « PREVISITE- Prise en charge » 🟩A Notre charge interdite si « RES- Shab » < 90, ou si précarité autre que 🟦Bleu (sauf source cee-apporteurs). |
| Message utilisateur | 1.Si previsite pour un dossier de -90m, alors a la charge de l'apporteur,<br>2.Si previsite pour un dossier different de bleu alors a la charge de l'apporteur,<br>3.Si vous avez un dossier 174 alors il faut obligatoirement une prévisite. | 1. Dossier TH174 : prévisite obligatoire. 2. TH171 de moins de 90 m² : prévisite à la charge de l'apporteur. 3. TH171 avec une précarité autre que 🟦Bleu : prévisite à la charge de l'apporteur.                                                  |

### 59. Previsite_Tertiaire1

Message affiché sous le champ « PREVISITE- Fiches Tertiaire ».

|                     | Aujourd'hui                                                                                                    | Proposé                                                                                                                                                                                     |
| ------------------- | -------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Merci de mettre en previsite, une fiche ou il y a une demande de création de dossier.                          | « PREVISITE- Fiches Tertiaire » (🟩BAT TH142- Déstratificateurs, BAT TH163- PAC Tertiaire, BAR TH179- PAC Collectif) : le champ « Création Dossier » du même produit doit être sur ✅- OUI. |
| Message utilisateur | Si vous choisissez une fiche CEE en previsite il faut que la création dossier de cette fiche soit aussi en OUI | La fiche choisie dans « PREVISITE- Fiches Tertiaire » doit avoir son champ « Création Dossier » sur ✅- OUI.                                                                                |

### 60. REGIE_SOUS_STATUT_NULL

Message affiché sous le champ « REGIE- Sous Statut ».

|                     | Aujourd'hui                                  | Proposé                                                                             |
| ------------------- | -------------------------------------------- | ----------------------------------------------------------------------------------- |
| Description         | Le statut de traitement ne peut pas etre nul | Anti-vidage : « REGIE- Sous Statut » ne peut pas être remis à vide une fois rempli. |
| Message utilisateur | Le statut de traitement ne peut pas etre nul | « REGIE- Sous Statut » ne peut pas être remis à vide : merci de choisir une valeur. |

### 61. REMPLIR_NOM_CAMPAGNE — règle inactive

Message affiché sous le champ « Nom de Campagne ».

|                     | Aujourd'hui                                           | Proposé                                                                              |
| ------------------- | ----------------------------------------------------- | ------------------------------------------------------------------------------------ |
| Description         | Merci de remplir le nom de la campagne pour convertir | Conversion : si « LOOKUP- Telepro » est rempli, « Nom de Campagne » est obligatoire. |
| Message utilisateur | Merci de remplir le nom de la campagne pour convertir | Merci de remplir « Nom de Campagne » avant de convertir.                             |

### 62. SECURITE_PROFIL

Message affiché sous le champ « Status ».

|                     | Aujourd'hui                                  | Proposé                                                                                                                  |
| ------------------- | -------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| Description         | Vous ne pouvez pas modifier ce champs merci. | Le profil Confirmateur ne peut pas mettre lui-même le statut de la piste sur Qualifié ou Non qualifié (hors conversion). |
| Message utilisateur | Vous ne pouvez pas modifier ce champs merci. | Vous ne pouvez pas mettre vous-même ce statut de piste (Qualifié / Non qualifié).                                        |

### 63. Si_interesser_panneau_pac_ou_ite — règle inactive

Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                                                        | Proposé                                                                                                                                                                                                          |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | _(vide)_                                                                                                                                           | « Interesser par Panneau solaire », « Interesser par Isolation Exterieur » ou « Intéresser par PAC/Ballon » = Oui : « Mode de chauffage principal » et « Avez vous deja bénéficier d'une étude ? » obligatoires. |
| Message utilisateur | Veuillez renseigner les champs <br>Mode de chauffage principal<br>Motivation du client pour les travaux<br>Avez vous deja bénéficier d'une étude ? | Merci de remplir « Mode de chauffage principal » et « Avez vous deja bénéficier d'une étude ? ».                                                                                                                 |

### 64. Si_interesser_par_panneaux_solaires

Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                                                                                                                                           | Proposé                                                                                                                                                                                                                                |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | _(vide)_                                                                                                                                                                                                                              | « Interesser par Panneau solaire » = Oui : Exposition de la toiture, velux, Chiens-Assis, Type de toiture, A déjà des panneaux ?, Superficie Libre, Ombrage, Eglise ou Monument proche et Installation en Panneau Proche obligatoires. |
| Message utilisateur | Veuillez remplir les Champs<br>Superficie Libre sur la toiture<br>Exposition de la toiture<br>Ombrage de la toiture<br>Avez vous des velux <br>Eglise Monument proche<br>Avez vous des Chiens-Assis<br>Installation en Panneau Proche | Panneaux solaires : merci de remplir exposition de la toiture, velux, chiens-assis, type de toiture, « A déjà des panneaux ? », superficie libre, ombrage, église ou monument proche et installation en panneau proche.                |

### 65. Si_interesser_par_pompe_a_chaleur — règle inactive

Message affiché en haut de la page.

|                     | Aujourd'hui                                                     | Proposé                                                                                                                      |
| ------------------- | --------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| Description         | _(vide)_                                                        | « Intéresser par PAC/Ballon » = Oui : « Emplacement de la chaudiere », « Pompe à Chaleur » et « PAC 179- ECS » obligatoires. |
| Message utilisateur | Veuillez remplir les informations concernant la Pompe à Chaleur | PAC : merci de remplir « Emplacement de la chaudiere », « Pompe à Chaleur » et « PAC 179- ECS ».                             |

### 66. Si_ite_oui_alors_remplir_les_champs

Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                          | Proposé                                                                                                                                                                                                                             |
| ------------------- | ---------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Veuillez remplir tous les champs requis lorsque le client est intéressé par l'isolation extérieure.​ | « Interesser par Isolation Exterieur » = Oui : Maison Mitoyenne, Pignon sur rue, Types des murs extérieurs, Espace pour l'echaffaudage, Maison en travaux, Maison Classé, Etat de la facade et Surface à isoler en m² obligatoires. |
| Message utilisateur | Veuillez remplir tous les champs requis lorsque le client est intéressé par l'isolation extérieure.​ | Isolation extérieure : merci de remplir Maison Mitoyenne, Pignon sur rue, Types des murs extérieurs, Espace pour l'echaffaudage, Maison en travaux, Maison Classé, Etat de la facade et Surface à isoler en m².                     |

### 67. TELEPRO_NE_PEUVENT_PAS_CONVERTIR

Message affiché en haut de la page.

|                     | Aujourd'hui                               | Proposé                                                                                                        |
| ------------------- | ----------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| Description         | LE CONFIRMATEUR uniquement peut convertir | Les profils Télépro Data et Télépro Leads ne peuvent pas convertir une piste : seul le confirmateur convertit. |
| Message utilisateur | LE CONFIRMATEUR uniquement peut convertir | Seul le confirmateur peut convertir une piste.                                                                 |

### 68. TYPE_DE_DOSSIESTATUT_NULL

Message affiché en haut de la page.

|                     | Aujourd'hui                                  | Proposé                                                                                                                                                                                                                       |
| ------------------- | -------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Le statut de traitement ne peut pas etre nul | Anti-vidage : Type de Dossier v3, VELO CARGO- TELEPRO, CONFIRM- Traitement, RES- Précarité, TYPE DE DOSSIER, RES- Kit Bizone, PREVISITE- Nécessité, PREVISITE- Statut et PREVISITE- Nom Sté ne peuvent pas être remis à vide. |
| Message utilisateur | Le statut de traitement ne peut pas etre nul | Ce champ ne peut pas être remis à vide une fois rempli : merci de choisir une valeur.                                                                                                                                         |

### 69. Type_de_dossier_rempli_pour_convertir — règle inactive

Message affiché en haut de la page.

|                     | Aujourd'hui                                                   | Proposé                                                              |
| ------------------- | ------------------------------------------------------------- | -------------------------------------------------------------------- |
| Description         | Il est obligatoire d'avoir un type de dossier pour convertir. | « Type de Dossier v3 » obligatoire pour passer la piste en Qualifié. |
| Message utilisateur | Il est obligatoire d'avoir un type de dossier pour convertir. | Merci de remplir « Type de Dossier v3 » avant de convertir.          |

### 70. VR_Lead_TypeDeDossier_CoherenceRecordTyp

Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                  | Proposé                                                                                                                                                                                       |
| ------------------- | -------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | _(vide)_                                                                                     | Cohérence type d'enregistrement / « Type de dossier » : une piste AA- RESIDENTIEL, AA- BAT, AA- AGRI ou AA- IND ne peut pas contenir un type de dossier d'une autre famille (BAR, BAT, AGRI). |
| Message utilisateur | Le type de dossier sélectionné n'est pas compatible avec le type d'enregistrement de ce RDV. | Le « Type de dossier » choisi n'est pas compatible avec le type d'enregistrement de cette piste (résidentiel, tertiaire, agri ou industrie).                                                  |

### 71. format_annee

Message affiché sous le champ « RES- Année Chaudière ».

|                     | Aujourd'hui                                                 | Proposé                                                                                  |
| ------------------- | ----------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| Description         | L'année doit être au format 4 chiffres (ex : 1980 ou 2000). | « RES- Année Chaudière » : si le champ est rempli, 4 chiffres entre 1700 et 2099.        |
| Message utilisateur | L'année doit être au format 4 chiffres (ex : 1980 ou 2000). | « RES- Année Chaudière » : merci de saisir une année sur 4 chiffres (ex : 1980 ou 2000). |

### 72. format_annee2

Message affiché sous le champ « RES- Anneé maison(ES) ».

|                     | Aujourd'hui                                                 | Proposé                                                                                   |
| ------------------- | ----------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| Description         | L'année doit être au format 4 chiffres (ex : 1980 ou 2000). | « RES- Anneé maison(ES) » : si le champ est rempli, 4 chiffres entre 1700 et 2099.        |
| Message utilisateur | L'année doit être au format 4 chiffres (ex : 1980 ou 2000). | « RES- Anneé maison(ES) » : merci de saisir une année sur 4 chiffres (ex : 1980 ou 2000). |

## Dossiers — 73 règles

### 1. AUDIT_1

Message affiché sous le champ « AUDIT- Nécéssité ».

|                     | Aujourd'hui                                                                                                  | Proposé                                                                                                                                                      |
| ------------------- | ------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Description         | Vous ne pouvez pas statuer la partie audit si la previsite n'est pas effectué ou bien sans previsite         | « AUDIT- Nécéssité » (✅- OUI ou ❌- NON) ne peut être renseigné que si « PREVISITE- Nécessité » = ❌- NON ou si « PREVISITE- Statut » = 🟩Passage Effectué. |
| Message utilisateur | Vous ne pouvez pas statuer la partie audit si la previsite n'est pas effectué ou la previsite non nécessaire | Vous ne pouvez pas renseigner « AUDIT- Nécéssité » tant que la prévisite n'est pas 🟩Passage Effectué (ou « PREVISITE- Nécessité » sur ❌- NON).             |

### 2. AUDIT_2 — règle inactive

Message affiché sous le champ « PREVISITE- Nécessité ».

|                     | Aujourd'hui                                                             | Proposé                                                                                                                                      |
| ------------------- | ----------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Si vous avez un dossier 174 alors il faut obligatoirement une previsite | Fiche 🟩BAR TH174- Réno Globale avec « RDV- Statut Dossier » = 🔵DOSSIER- Attente Installation : « PREVISITE- Nécessité » doit être ✅- OUI. |
| Message utilisateur | Si vous avez un dossier 174 alors il faut obligatoirement une previsite | Un dossier TH174 exige une prévisite : merci de mettre « PREVISITE- Nécessité » sur ✅- OUI.                                                 |

### 3. AUDIT_NON

Message affiché sous le champ « PREVISITE- Nécessité ».

|                     | Aujourd'hui                                                                                                                                         | Proposé                                                                                                                                                                             |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Si Audit egale non,, Statut previsite en att planification, nom de société en Nouveau dossier, date de previsite et date d'envoi doivent être vide. | « AUDIT- Nécéssité » = ❌- NON : « AUDIT- Statut » doit rester ▣ Nouveau Dossier, et « LOOKUP- Auditeur », « AUDIT- Date d’Envoi » et « AUDIT- Date Reception » doivent être vides. |
| Message utilisateur | Si Audit egale non,, Statut previsite en att planification, nom de société en Nouveau dossier, date de previsite et date d'envoi doivent être vide. | Audit sur ❌- NON : laissez « AUDIT- Statut » sur ▣ Nouveau Dossier et videz « LOOKUP- Auditeur », « AUDIT- Date d’Envoi » et « AUDIT- Date Reception ».                            |

### 4. AUDIT_OUI1

Message affiché sous le champ « AUDIT- Statut ».

|                     | Aujourd'hui                                                                                                 | Proposé                                                                                              |
| ------------------- | ----------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| Description         | Si l'auditeur est renseigné merci de mettre la date d'envoi                                                 | « AUDIT- Statut » = 🟨Audit- Demandé : « LOOKUP- Auditeur » et « AUDIT- Date d’Envoi » obligatoires. |
| Message utilisateur | Si le statut audit est demandé, alors il faut que le nom de la société et la date d'envoi soient rensseigné | Pour mettre 🟨Audit- Demandé, merci de remplir « LOOKUP- Auditeur » et « AUDIT- Date d’Envoi ».      |

### 5. AUDIT_OUI2

Message affiché sous le champ « AUDIT- Statut ».

|                     | Aujourd'hui                                                                                                                 | Proposé                                                                                                                                  |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Si le statut est en modif demandé, il faut que le nom de l'auditeur, la date d'envoi et la date de reception soient remplis | « AUDIT- Statut » = 🟧Audit- Modifs Demandées : « LOOKUP- Auditeur », « AUDIT- Date d’Envoi » et « AUDIT- Date Reception » obligatoires. |
| Message utilisateur | Si le dossier est en modifs demandé, il faut que le nom de l'auditeur la date d'envoi et date de réception soient rempli.   | Pour mettre 🟧Audit- Modifs Demandées, merci de remplir « LOOKUP- Auditeur », « AUDIT- Date d’Envoi » et « AUDIT- Date Reception ».      |

### 6. AUDIT_OUI3

Message affiché sous le champ « AUDIT- Statut ».

|                     | Aujourd'hui                                                                                                                 | Proposé                                                                                                                        |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| Description         | Si le statut est en modif demandé, il faut que le nom de l'auditeur, la date d'envoi et la date de reception soient remplis | « AUDIT- Statut » = 🟩Audit- Validé : « LOOKUP- Auditeur », « AUDIT- Date d’Envoi » et « AUDIT- Date Reception » obligatoires. |
| Message utilisateur | Si le statut audit est en validé alors il faut que le nom de l'auditeur la date d'envoi et date de réception soient rempli. | Pour mettre 🟩Audit- Validé, merci de remplir « LOOKUP- Auditeur », « AUDIT- Date d’Envoi » et « AUDIT- Date Reception ».      |

### 7. AUDIT_OUI6 — règle inactive

Message affiché sous le champ « COFRAC- Statut ».

|                     | Aujourd'hui                                                                                                                 | Proposé                                                                                                                                              |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Si le statut est en modif demandé, il faut que le nom de l'auditeur, la date d'envoi et la date de reception soient remplis | « COFRAC- Statut » renseigné : « AUDIT- Statut » doit être 🟩Audit- Validé, et « COFRAC- Nom Sté » et « COFRAC- Date de Passage » sont obligatoires. |
| Message utilisateur | Merci de remplir le nom du Cofrac et la date de passage.<br>Il faut que l’audit soit validé pour envoyer en cofrac          | Pour envoyer au COFRAC, « AUDIT- Statut » doit être 🟩Audit- Validé, et « COFRAC- Nom Sté » et « COFRAC- Date de Passage » doivent être remplis.     |

### 8. CEE_MODIFS_STATUT

Message affiché en haut de la page.

|                     | Aujourd'hui                                                               | Proposé                                                                                                                           |
| ------------------- | ------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Si le statut CEE est changé, il faut mettre à jour la date de modifs CEE. | Tout changement de « CEE- Statut » doit s'accompagner, dans le même enregistrement, de la mise à jour de la date « CEE- Modifs ». |
| Message utilisateur | Si le statut CEE est changé, il faut mettre à jour la date de modifs CEE. | Vous avez changé « CEE- Statut » : merci de mettre à jour la date « CEE- Modifs ».                                                |

### 9. CEE_STATUT

Message affiché sous le champ « CEE- Statut ».

|                     | Aujourd'hui                                                         | Proposé                                                                                                                                                                                                                           |
| ------------------- | ------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Merci de mettre le bon statut de dossier pour mettre ce statut CEE. | TH171, « CEE- Statut » / « RDV- Statut Dossier ». ▣ En Attente Incitation : Attente Installation, Installé ou Annulé. 🟪Déposé et suivants : 🟢DOSSIER- Installé. 🟩AAF Envoyé : « CEE- N° AAF » et « CEE- Prix Cumacs » remplis. |
| Message utilisateur | Merci de mettre le bon statut de dossier pour mettre ce statut CEE. | « CEE- Statut » incohérent avec « RDV- Statut Dossier » : à partir de 🟪Déposé, le dossier doit être 🟢DOSSIER- Installé. Pour 🟩AAF Envoyé, merci de remplir « CEE- N° AAF » et « CEE- Prix Cumacs ».                            |

### 10. CERTIKO_STATUT_VT_RESERVE

Message affiché sous le champ « CERTIKO- Statut VT ».

|                     | Aujourd'hui                                                                                                                                                                                                                      | Proposé                   |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------- |
| Description         | Statut VT à la main : admin tout ; Secrétaire ES terminee/incomplet/termine_valide ; autres non. Libres : invité (webhook, portail) et remises à zéro (numéro d'envoi change : pré-visiteur, rendu, déplacement). Ids de profil. | _inchangée (déjà claire)_ |
| Message utilisateur | Statut VT : la secrétaire ES ne peut choisir que Visite Complete, Terminée- Incomplet ou Terminée- Validé ; les autres valeurs (démarrage, incomplète, annulée) sont réservées à Certiko et aux administrateurs.                 | _inchangé (déjà clair)_   |

### 11. CHAMPS_NUL

Message affiché en haut de la page.

|                     | Aujourd'hui                            | Proposé                                                                                                                                                                                                                           |
| ------------------- | -------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | LE CHAMPS NE PEUT PAS REPASSER EN NULL | Anti-vidage (liste 1) : 27 listes de statut (devis, RDV- Statut Dossier, PREVISITE, LEDS, INSTALLATION, AUDIT, MPR, CEE, CERTIKO…) ne peuvent pas être remises à vide. Exception : « CERTIKO- Statut VT » lors d'un nouvel envoi. |
| Message utilisateur | LE CHAMPS NE PEUT PAS REPASSER EN NULL | Un champ de statut déjà rempli ne peut pas être remis à vide : merci de choisir une valeur.                                                                                                                                       |

### 12. CHAMPS_NUL2

Message affiché en haut de la page.

|                     | Aujourd'hui                            | Proposé                                                                                                                                                                                                                          |
| ------------------- | -------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | LE CHAMPS NE PEUT PAS REPASSER EN NULL | Anti-vidage (liste 2) : 13 listes (RES- Precarité, RES- Indivision, INSTALLATION- Fin Chantier, champs ITE, MPR- Precarité.Piste, PREVISITE- Conf J-1, AUDIT- Nom Sté, PREVISITE- Nécessité) ne peuvent pas être remises à vide. |
| Message utilisateur | LE CHAMPS NE PEUT PAS REPASSER EN NULL | Un champ de statut déjà rempli ne peut pas être remis à vide : merci de choisir une valeur.                                                                                                                                      |

### 13. COFRAC174_1

Message affiché sous le champ « COFRAC- Statut ».

|                     | Aujourd'hui                                                                                   | Proposé                                                                                                                           |
| ------------------- | --------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Pour envoyer au COFRAC il faut que les docs soient complet.                                   | « COFRAC- Statut » = 🟧Passage Planifié : « RES- Precarité » = 🟦BLEU et « DOCS- Statut » = 🟩Dossier Complet obligatoires.       |
| Message utilisateur | Pour envoyer au COFRAC en 174, il faut precarite Bleu et il faut que les docs soient complet. | Pour mettre le COFRAC en 🟧Passage Planifié, « RES- Precarité » doit être 🟦BLEU et « DOCS- Statut » doit être 🟩Dossier Complet. |

### 14. Certiko_VT_Controle

Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                                                     | Proposé                                                                                                                                                                                                                                    |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Description         | _(vide)_                                                                                                                                        | « CERTIKO- Statut VT » ▣ Visite en att démarrage, 🟫Visite Incomplete ou 🟦Visite Complete : « DOCS ES- Statut » et « DOCS ES- Att visiteur » vides. ❌Visite Terminée- Incomplet : un manquant coché et « DOCS ES- Att visiteur » rempli. |
| Message utilisateur | + Visite (▣,🟫,🟦) : Statuts documents doivent être vides .<br>+ Visite incomplète❌: précisez les docs manquants et renseignez l’att visiteur. | Visite ▣, 🟫 ou 🟦 : « DOCS ES- Statut » et « DOCS ES- Att visiteur » doivent être vides. ❌Visite Terminée- Incomplet : cochez les manquants dans « DOCS ES- Statut » et remplissez « DOCS ES- Att visiteur ».                            |

### 15. DEVIS_108_117_119

Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                                                                                                                                                                    | Proposé                                                                                                                                                                                                                            |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Il faut que le champ Devis TTC et que le Délégataire soit rempli.                                                                                                                                                                                              | « CEE- Statut » 🟩AAF Envoyé (AGRI EQ108, TH108, TH119, BAT TH163, BAR TH179) : « DEVIS- Montant TTC » rempli et non nul. « RDV- Statut Devis » 🟦En Att Signature ou 🟩Signé (fiches AGRI) : « LOOKUP- Delegataire » obligatoire. |
| Message utilisateur | 1.Si devis Att Signature, il faut le delégataire, date devis, documents, cotation soient complet.<br>2.Si devis Signé, il faut le delégataire, date devis, date signature,documents,cotation soient complet.<br>3.Si CEE payé, montant TTC doit etre renseigné | Devis 🟦En Att Signature ou 🟩Signé : merci de remplir « LOOKUP- Delegataire ». CEE 🟩AAF Envoyé : merci de remplir « DEVIS- Montant TTC ».                                                                                        |

### 16. DEVIS_171_174

Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                        | Proposé                                                                                                                                                                                            |
| ------------------- | ------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Il faut que le champ Devis TTC et que le Délégataire soit rempli.                                                  | TH171 et TH174 : « CEE- Statut » = 🟩AAF Envoyé => « DEVIS- Montant TTC » rempli et différent de 0 ; « RDV- Statut Devis » = 🟦En Att Signature ou 🟩Signé => « LOOKUP- Delegataire » obligatoire. |
| Message utilisateur | Si devis Généré ou Signé, il faut le delagataire soit rempli<br>Si CEE payé, il faut le montant TTC soit renseigné | Devis 🟦En Att Signature ou 🟩Signé : merci de remplir « LOOKUP- Delegataire ». CEE 🟩AAF Envoyé : merci de remplir « DEVIS- Montant TTC ».                                                        |

### 17. DEVIS_174

Message affiché sous le champ « RDV- Statut Devis ».

|                     | Aujourd'hui                                                                                                                                                                                                                                          | Proposé                                                                                                                                                                                                                               |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Pour mettre le devis en attente de sigature, merci de remplir, la date de devis,la shab,la precarité,la cotation.                                                                                                                                    | TH174 (« DR-Infos fiche2 » = 1), devis sorti de ▣ Génération Devis : 🟩Dossier Complet, 🟦BLEU, LOOKUP- Delegataire, DEVIS- Généré le, RES- Shab, DEVIS- Cotation, RENO 174- Travaux Finaux. Toujours : un seul ballon thermo.        |
| Message utilisateur | Pour remplir shab,travaux finaux cotation , il faut le cofrac soit satisfaisant.<br>Pour faire devis, il faut préca bleu,travaux finaux, delegataire, date devis, Shab, Precarité, Cotation, docs.<br>Un type de ballon uniquement ds travaux finaux | TH174, pour avancer le devis : « DOCS- Statut » 🟩Dossier Complet, « RES- Precarité » 🟦BLEU, « LOOKUP- Delegataire », « DEVIS- Généré le », « RES- Shab », « DEVIS- Cotation », « RENO 174- Travaux Finaux ». Un seul ballon thermo. |

### 18. DEVIS_179_163

Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                                                                 | Proposé                                                                                                                |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| Description         | Il faut que le champ Devis TTC et que le Délégataire soit rempli.                                                                                           | BAT TH163 et BAR TH179 : « RDV- Statut Devis » = 🟦En Att Signature ou 🟩Signé => « LOOKUP- Delegataire » obligatoire. |
| Message utilisateur | 1.Si devis Att Signature, il faut le delégataire, date devis, documents.<br>2.Si devis Signé, il faut le delégataire, date devis, date signature,documents. | Devis 🟦En Att Signature ou 🟩Signé : merci de remplir « LOOKUP- Delegataire ».                                        |

### 19. DEVIS_Date_Signature

Message affiché sous le champ « LEDS EQ127- Statut Dossier ».

|                     | Aujourd'hui                                                                                                                                                                                                      | Proposé                                                                                                                                                                                                                                                      |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Description         | Pour mettre le devis en signé, Merci de mettre le statut "PAC- STATUT DOSSIER " en "Dossier signé", d'avoir les docs complet, le délégataire,le montant de devis, la personne et la date de Signature renseigné. | LEDS EQ127 (« LEDS- Devis Final » 🟩Signé) : dossier sorti de 🔵Attente Installation, CLIENT- Code postal, Adresse Chantier, « DOCS- CEE » 🟩Dossier Complet, LOOKUP- Delegataire, DEVIS- Montant HT, hauteurs et LEDS- Qté Prévue. Idem prévu pour DESTRAT. |
| Message utilisateur | Pour mettre le devis en signé, Merci de mettre le statut "PAC- STATUT DOSSIER " en "Dossier signé", d'avoir les docs complet, le délégataire,le montant de devis renseigné.                                      | Devis signé : « LEDS EQ127- Statut Dossier » ne doit plus être 🔵DOSSIER- Attente Installation ; il faut « DOCS- CEE » 🟩Dossier Complet, « LOOKUP- Delegataire », « DEVIS- Montant HT », le code postal et l'adresse du chantier.                           |

### 20. DOCS_PREVISITE — règle inactive

Message affiché sous le champ « PREVISITE- Retour Docs ».

|                     | Aujourd'hui                                               | Proposé                                                                                                                                                          |
| ------------------- | --------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Docs previsite modifiable que par la reponsable previsite | « PREVISITE- Retour Docs » modifiable uniquement par la responsable prévisite et le compte administrateur principal (repérés par leur identifiant de connexion). |
| Message utilisateur | Docs previsite modifiable que par la reponsable previsite | « PREVISITE- Retour Docs » ne peut être modifié que par la responsable prévisite.                                                                                |

### 21. Devis_171

Message affiché sous le champ « INSTALLATION- Statut ».

|                     | Aujourd'hui                                                                                                                                                                                                           | Proposé                                                                                                                                                                                                                         |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Voir Zone/ Shab ou Précarité pour envoie en pose                                                                                                                                                                      | Blocage de 🟨Date Planifiée (« INSTALLATION- Statut »). TH171 : RAC avec devis non signé ; 🟨JAUNE/🟪VIOLET (RAC ≤ 6 999 €) ou « RES- Shab » < 90 sans MPR accordée ; Shab < 70. Toutes fiches : « RES- Zone » 🟥H3 ou INCONNU. |
| Message utilisateur | Vous ne pouvez pas envoyer en pose si:<br>1.Devis non signé quand il y a du RAC <br>2.Jaune/violet sans accord MPR<br>3.Dossier -90m² sans accord MPR<br>4.Votre code postal est en H3<br>5.La Shab est moins de 70m² | Envoi en pose impossible si : devis non signé avec un RAC ; 🟨JAUNE / 🟪VIOLET sans accord MPR ; « RES- Shab » < 90 m² sans accord MPR ; « RES- Shab » < 70 m² ; « RES- Zone » en 🟥H3 ou inconnue.                             |

### 22. Docs_ESvalidation

Message affiché sous le champ « DOCS ES- Att visiteur ».

|                     | Aujourd'hui                                                                                                                                 | Proposé                                                                                                                                                                             |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Pour mettre Validé- Docs Complet ou Validé- Docs Incomplet, il faut avoir Validé secretariat                                                | « DOCS ES- Statut » = ✅Validé- Docs Complet ou ☑️Validé- Docs Incomplet : « DOCS ES- Att visiteur » doit être 🟩Validé secretariat et « RES- Bono Social Final » doit être rempli. |
| Message utilisateur | 1.Pour mettre Validé- Docs Complet ou Validé- Docs Incomplet, il faut avoir Validé secretariat<br>2. Il faut que le bono social soit rempli | Pour valider les docs (complet ou incomplet), « DOCS ES- Att visiteur » doit être 🟩Validé secretariat et « RES- Bono Social Final » doit être rempli.                              |

### 23. GLOBAL_METTRE_NON_APRES_CONVERSION

Message affiché en haut de la page.

|                     | Aujourd'hui                                                                    | Proposé                                                                                                                                                                                                                                 |
| ------------------- | ------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Merci de mettre directement en annulé le dossier si il n'est plus d'actualité. | Après la création du dossier, on ne repasse pas un champ « Création Dossier » sur ❌- NON (LEDS EQ127, DESTRAT TH142, PAC TH171, RENO TH174, PAC TH179) : il faut annuler le dossier. La formule ne teste que le ❌- NON de LEDS EQ127. |
| Message utilisateur | Merci de mettre directement en annulé le dossier si il n'est plus d'actualité. | Un produit ne se remet pas sur ❌- NON après la création du dossier : si le dossier n'est plus d'actualité, merci de le passer en annulé.                                                                                               |

### 24. INSTALLATION_DEPLACEMENT_PAS_DE_RETOUR

Message affiché sous le champ « INSTALLATION- Deplacement ».

|                     | Aujourd'hui                                                                                                                                                                                                                                    | Proposé                   |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------- |
| Description         | Anti-retour sur « INSTALLATION- Deplacement » : une fois Déplacement 1 atteint, interdit de vider ; une fois Déplacement 2 atteint, interdit de revenir à 1 ou de vider. Progression vide -> 1 -> 2 autorisée.                                 | _inchangée (déjà claire)_ |
| Message utilisateur | Retour en arrière interdit sur « INSTALLATION- Deplacement » : une fois Frais Déplacement 1 atteint vous ne pouvez plus vider le champ, et une fois Frais Déplacement 2 atteint vous ne pouvez plus revenir à Frais Déplacement 1 ni le vider. | _inchangé (déjà clair)_   |

### 25. LEDS_FIN_DE_CHANTIER

Message affiché sous le champ « LEDS- Qté Final ».

|                     | Aujourd'hui                                                                                                                                                                                                     | Proposé                                                                                                                                                   |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Si la quantité de LEDS finale est renseigné il faut aussi renseigner le mode d'installation.<br>Et Inversement.                                                                                                 | « LEDS- Qté Final » et « LEDS- Mode d'installation » vont ensemble : si la quantité est remplie, le mode ne peut pas rester ▣ En Attente, et inversement. |
| Message utilisateur | Si la quantité de LEDS finale est vide alors le Mode d'installation doit l'etre aussi.<br>Si la quantité de LEDS finale est renseigné alots il faut aussi renseigner le mode d'installation.<br>Et Inversement. | « LEDS- Qté Final » et « LEDS- Mode d'installation » se remplissent ensemble : les deux renseignés, ou quantité vide et mode sur ▣ En Attente.            |

### 26. LEDS_FIN_DE_CHANTIER3

Message affiché sous le champ « LEDS- Qté Final ».

|                     | Aujourd'hui                                                                                                                                                                                                          | Proposé                                                                                                                                                 |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Pour Mettre en attente de signature il faut que la quantité de LEDS finale soit rempli.                                                                                                                              | « LEDS- Qté Final » obligatoire dès que « LEDS- Devis Final » quitte ▣ Génération Devis ou que « LEDS- Fin Chantier » quitte ▣ Génération Fin Chantier. |
| Message utilisateur | Pour Mettre En attente de signature le devis final il faut que la quantité de LEDS finale soit rempli.<br>Pour Mettre En attente de signature la fin de chantier il faut que la quantité de LEDS finale soit rempli. | Pour faire avancer « LEDS- Devis Final » ou « LEDS- Fin Chantier », merci de remplir « LEDS- Qté Final ».                                               |

### 27. LEDS_FIN_DE_CHANTIER5

Message affiché sous le champ « LEDS- Auditeur ».

|                     | Aujourd'hui                                        | Proposé                                                                                                        |
| ------------------- | -------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| Description         | Merci de mettre le nom de l'auditeur pour valider. | « LEDS- Auditeur » doit être choisi (pas ▣ En Attente) dès que « LEDS- Statut Audit » n'est plus ▣ En Attente. |
| Message utilisateur | Merci de mettre le nom de l'auditeur pour valider. | Merci de choisir « LEDS- Auditeur » avant de changer « LEDS- Statut Audit ».                                   |

### 28. LEDS_FIN_DE_CHANTIER6

Message affiché sous le champ « LEDS- Statut Audit ».

|                     | Aujourd'hui                                                                      | Proposé                                                                                                                                                                  |
| ------------------- | -------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Description         | Pour changer le statut de signature merci de mettre le statut d'audit en validé. | « LEDS- Statut Audit » doit être 🟩Validé pour faire avancer « LEDS- Devis Final » (hors ▣ Génération Devis) ou « LEDS- Fin Chantier » (hors ▣ Génération Fin Chantier). |
| Message utilisateur | Pour changer le statut de signature merci de mettre le statut d'audit en validé. | Pour faire avancer « LEDS- Devis Final » ou « LEDS- Fin Chantier », « LEDS- Statut Audit » doit être 🟩Validé.                                                           |

### 29. LEDS_INSTALLATION

Message affiché sous le champ « LEDS EQ127- Statut Installation ».

|                     | Aujourd'hui                                                                                                                                                                                                                                | Proposé                                                                                                                                                                                                                                                   |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Merci de remplir le Lookup sous traitant et la date de planification.                                                                                                                                                                      | « LEDS EQ127- Statut Installation » 🟨Date Planifiée, 🟧Non Finalisée ou 🟩Cloturée : LEDS- Type d'Installation Final, Nom SS Traitant, RDV- Equipe d'Install, Hauteur MAX Sous Faitage, Date d'installation ; « LEDS- Qté Final » en plus si 🟩Cloturée. |
| Message utilisateur | Si envoi en pose, <br>Mettre le champs Leds-Validation Client en Envoi en pose,<br>Le Type d'installation Final. <br>Le Lokkup SSTraitant,<br>La Date installe, <br>LaHauteur Max Sous Faitage<br>Si installe <br>Rajouter QTE Leds finale | Installation LEDS : merci de remplir « LEDS- Type d'Installation Final », « LEDS- Nom SS Traitant », « RDV- Equipe d'Install », « LEDS- Hauteur MAX Sous Faitage », « LEDS- Date d'installation » (+ « LEDS- Qté Final » si clôturée).                    |

### 30. LEDS_INSTALLATION6

Message affiché sous le champ « LEDS EQ127- Statut Installation ».

|                     | Aujourd'hui                                                                    | Proposé                                                                                                   |
| ------------------- | ------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------- |
| Description         | Si le nombre de Leds finale est rempli, il faut que le statut soit en cloturé. | Si « LEDS- Qté Final » est rempli, « LEDS EQ127- Statut Installation » doit être 🟩Installation Cloturée. |
| Message utilisateur | Si le nombre de Leds finale est rempli, il faut que le statut soit en cloturé. | « LEDS- Qté Final » est rempli : « LEDS EQ127- Statut Installation » doit être 🟩Installation Cloturée.   |

### 31. LEDS_MEME_QUE_LA_PISTE

Message affiché sous le champ « LEDS- Type d'Installation Final ».

|                     | Aujourd'hui                                                   | Proposé                                                                                                                       |
| ------------------- | ------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| Description         | Il faut que le type d'installation soit le meme que la piste. | « LEDS- Type d'Installation Final » (hors ▣ En Attente) doit être identique à « LEDS- Type Installation » repris de la piste. |
| Message utilisateur | Il faut que le type d'installation soit le meme que la piste. | « LEDS- Type d'Installation Final » doit être identique à « LEDS- Type Installation » (valeur de la piste).                   |

### 32. LEDS_Qte_INF

Message affiché en haut de la page.

|                     | Aujourd'hui                                                                          | Proposé                                                                                                                                  |
| ------------------- | ------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Le nombre de Leds doit etre au minimum de 40 pour l'agriculture et 20 pour le reste. | LEDS (dossier non annulé) : « LEDS- Qté Prévue » au minimum 20 si « LEDS- Type Installation » = ☑️AGRICULTURE, 12 si ✅HORS AGRICULTURE. |
| Message utilisateur | Le nombre de Leds doit etre au minimum de 50 pour l'agriculture et 20 pour le reste. | « LEDS- Qté Prévue » insuffisante : minimum 20 LEDS en agriculture et 12 hors agriculture.                                               |

### 33. PAC_ATT_SIGNATURE_OU_SIGNE — règle inactive

Message affiché sous le champ « DEVIS- Montant TTC ».

|                     | Aujourd'hui                                                                                                                                                    | Proposé                                                                                                                                                         |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Pour mettre le devis en signé, Merci de mettre le statut "PAC- STATUT DOSSIER " en "Dossier signé" ainsi que de renseigner la personne et la date de Signature | « LEDS- Devis Final » = 🟦En Attente Signature ou 🟩Signé : « DEVIS- Montant TTC » rempli et différent de 0, et « CEE- Délegataire » choisi (pas ▣ En attente). |
| Message utilisateur | Pour mettre le devis en attente de signature ou signé il faut que le champ DEVIS- Montant TTC et le delegataire soit rempli                                    | Pour mettre le devis final en attente de signature ou signé, merci de remplir « DEVIS- Montant TTC » et « CEE- Délegataire ».                                   |

### 34. PAC_Docs1

Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                                                                                                                                                   | Proposé                                                                                                                                                                                                         |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Vous ne pouvez pas sélectionner le statut "Dossier Complet" avec d'autres valeurs.                                                                                                                                                            | « DOCS- Statut » = 🟩Dossier Complet : aucun 🟨Mq coché en même temps ; « CLIENT- Code postal » à 5 chiffres ; « RES- Zone » connue ; en TH171 : RES- Indivision, Statut Occupation, Precarité et Shab remplis. |
| Message utilisateur | 1.Vous ne pouvez pas sélectionner le statut "Dossier Complet" avec d'autres valeurs.<br>2.En 171, Merci de remplir précarite, shab, statut d'occupation et indivision<br>3.Votre champs code postal doit etre rempli et composé de 5 chiffres | 🟩Dossier Complet : ne cochez aucun 🟨Mq en même temps ; « CLIENT- Code postal » à 5 chiffres ; en TH171, remplir « RES- Precarité », « RES- Shab », « RES- Statut Occupation » et « RES- Indivision ».         |

### 35. PAC_Installation10 — règle inactive

Message affiché sous le champ « DEVIS- Modalité Paiement ».

|                     | Aujourd'hui                                                                                  | Proposé                                                                                                                                                                                                    |
| ------------------- | -------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Les modalités de paiement ne sont pas renseigné ou pas cohérent avec la précarité du client. | « DEVIS- Modalité Paiement » selon « RES- Precarité » : 🟦BLEU => 🟩Sans RAC- 0€ obligatoire ; 🟨JAUNE, 🟪VIOLET, 🟥ROSE => 🟩Sans RAC- 0€ interdit. (Valeur 🟩Sans RAC- 0€ absente de la liste actuelle.) |
| Message utilisateur | Les modalités de paiement ne sont pas cohérent avec la précarité du client.                  | « DEVIS- Modalité Paiement » n'est pas cohérente avec « RES- Precarité » du client.                                                                                                                        |

### 36. PAC_Installation11

Message affiché sous le champ « MPR- Statut ».

|                     | Aujourd'hui                                                   | Proposé                                                                                                                                                 |
| ------------------- | ------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Pour Envoyer en pose il faut que le statut MPR soit cohérent. | TH171 : « MPR- Statut » = 🟫Solde Demandé, 🟩Payé- Reçu Bénéficiaire ou 🟩Payé- Virement Reçu exige « INSTALLATION- Statut » = 🟩Installation Cloturée. |
| Message utilisateur | Pour Envoyer en pose il faut que le statut MPR soit cohérent. | Ce « MPR- Statut » n'est possible que si « INSTALLATION- Statut » est 🟩Installation Cloturée.                                                          |

### 37. PAC_Installation12

Message affiché sous le champ « DEVIS- Montant TTC ».

|                     | Aujourd'hui                                                                                           | Proposé                                                                                                                                                            |
| ------------------- | ----------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Description         | Votre montant total n'a pas pris en charge le kit bizone ou est incorrect, merci de le mettre à jour. | « DEVIS- Montant TTC » (s'il est rempli) : 10 000 à 10 600 € si « INSTALLATION- Kit Bi-Zone » = Non nécessaire ou KIT 1 ZONE ; 10 600 à 13 000 € avec KIT BI-ZONE. |
| Message utilisateur | Votre montant total n'a pas pris en charge le kit bizone ou est incorrect, merci de le mettre à jour. | « DEVIS- Montant TTC » incorrect : 10 000 à 10 600 € sans kit bizone (ou KIT 1 ZONE), 10 600 à 13 000 € avec KIT BI-ZONE. Merci de le mettre à jour.               |

### 38. PAC_Installation14

Message affiché sous le champ « MPR- Statut ».

|                     | Aujourd'hui                                                                                                                                  | Proposé                                                                                                                                                  |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Pour mettre en statut déposé, Merci de remplir les champs manquants                                                                          | TH171, « MPR- Statut » = ❌Full CEE : « RES- Indivision » et « RES- Statut Occupation » renseignés, « RES- Precarité » = 🟥ROSE et « RES- Shab » rempli. |
| Message utilisateur | Pour mettre en statut full CEE, il faut, que le statut d'occupation, l'indivision, la précarité en Rose et la surface habitable soit rempli. | Pour mettre ❌Full CEE : « RES- Precarité » doit être 🟥ROSE, et « RES- Shab », « RES- Statut Occupation » et « RES- Indivision » doivent être remplis.  |

### 39. PAC_Installation15

Message affiché sous le champ « INSTALLATION- Statut ».

|                     | Aujourd'hui                                                                 | Proposé                                                                                                                                                    |
| ------------------- | --------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Pour mettre en signé il faut que le statut de l'installation soit cohérent. | TH171 et TH174 : « INSTALLATION- Fin Chantier » = 🟩Signé interdit si « INSTALLATION- Statut » est encore ▣ Attente Planification ou 🟪Chantier PréValidé. |
| Message utilisateur | Pour mettre en signé il faut que le statut de l'installation soit cohérent. | « INSTALLATION- Fin Chantier » 🟩Signé impossible tant que « INSTALLATION- Statut » est ▣ Attente Planification ou 🟪Chantier PréValidé.                   |

### 40. PAC_Installation5

Message affiché sous le champ « INSTALLATION- Mail Sous Traitant ».

|                     | Aujourd'hui                                                                                                                                                                                              | Proposé                                                                                                                                                                                        |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Le champ "Email du sous-traitant" ne peut pas être renseigné tant que la date d’installation, le lookupp ss traitant, le kit bizone, le modele de la pac et le commentaire installateur n’est pas saisi. | « INSTALLATION- Mail Sous Traitant » ne peut être rempli que si INSTALLATION- Date Réel, Nom SS Traitant, Compteur Electrique, Modele PAC, Kit Bi-Zone et Infos SStraitant sont saisis.        |
| Message utilisateur | Le champ "Email du sous-traitant" ne peut pas être renseigné tant que la date d’installation, le lookupp ss traitant, le kit bizone, le modele de la pac et le commentaire installateur n’est pas saisi. | Avant de remplir « INSTALLATION- Mail Sous Traitant », merci de saisir les champs INSTALLATION : Date Réel, Nom SS Traitant, Compteur Electrique, Modele PAC, Kit Bi-Zone et Infos SStraitant. |

### 41. PAC_Installation6

Message affiché sous le champ « MPR- Modifs ».

|                     | Aujourd'hui                                                               | Proposé                                                                                                                           |
| ------------------- | ------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Si le statut MPR est changé, il faut mettre à jour la date de modifs MPR. | Tout changement de « MPR- Statut » doit s'accompagner, dans le même enregistrement, de la mise à jour de la date « MPR- Modifs ». |
| Message utilisateur | Si le statut MPR est changé, il faut mettre à jour la date de modifs MPR. | Vous avez changé « MPR- Statut » : merci de mettre à jour la date « MPR- Modifs ».                                                |

### 42. PAC_Installation7

Message affiché sous le champ « INSTALLATION- Statut ».

|                     | Aujourd'hui                                                                                                  | Proposé                                                                                                                                            |
| ------------------- | ------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Merci de remplir le modèle de la PAC, Ballon, Kit bizone, pour passer au statut suivant.                     | TH171, « INSTALLATION- Statut » = 🟪Chantier PréValidé : INSTALLATION- Modele PAC, Modele Ballon, Compteur Electrique et Kit Bi-Zone obligatoires. |
| Message utilisateur | Merci de remplir le modèle de la PAC, Ballon, Kit bizone, Compteur électrique pour passer au statut suivant. | Pour mettre 🟪Chantier PréValidé, merci de remplir les champs INSTALLATION : Modele PAC, Modele Ballon, Compteur Electrique et Kit Bi-Zone.        |

### 43. PAC_Installation8

Message affiché sous le champ « INSTALLATION- Statut ».

|                     | Aujourd'hui                                                                                                                                                                                                                                                | Proposé                                                                                                                                                                                                                                    |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Description         | Merci de remplir le modele de la PAC, Ballon, Kit bizone, le lookup Straitant et la date d'installation pour passer au statut suivant                                                                                                                      | « INSTALLATION- Statut » 🟨, 🟧 ou 🟩. TH171 : Date Réel, 🟩Dossier Complet, Modele PAC, Modele Ballon, Kit Bi-Zone, Compteur, Nom SS Traitant, Mail et Infos SStraitant. TH174 : détail de chaque travail final coché (m², type, modèle). |
| Message utilisateur | Docs doivent etre complet.<br>171- Date d'installation, PAC,Ballon, Kit bizone,Compteur,Sous traitant, Mail et commentaire pr ss traitant.<br>174- Date d'installation, Infos lié au produits installé, Sous traitant, Mail et commentaire pr ss traitant. | TH171 : « DOCS- Statut » 🟩Dossier Complet + champs INSTALLATION (Date Réel, Modele PAC, Modele Ballon, Kit Bi-Zone, Compteur, Nom SS Traitant, Mail, Infos SStraitant). TH174 : détail (m², type, modèle) de chaque travail final coché.  |

### 44. PAC_RAC_1

Message affiché sous le champ « DEVIS- Modalité Paiement ».

|                     | Aujourd'hui                                                                                                                                                                        | Proposé                                                                                                                                                                                                    |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Remplir les modalité paiement, le modele de la PAC, Ballon, Kit bizone, Compteur, le Sous traitant et la date d'installation pour passer au statut suivant                         | TH171, « MPR- Statut » 🟪Déposé ou plus : 🟪VIOLET => « DEVIS- Montant RAC » et « DEVIS- Modalité Paiement » obligatoires ; 🟥ROSE en ❌Full CEE => idem ; 🟦BLEU => ces deux champs doivent rester vides. |
| Message utilisateur | Si Le client est Bleue, merci de laisser vide les modalité paiement et le montant RAC.<br> Si Le client est Violet/Rose, Merci de Remplir les modalité paiement et le montant RAC. | Client 🟦BLEU : laissez vides « DEVIS- Montant RAC » et « DEVIS- Modalité Paiement ». Client 🟪VIOLET ou 🟥ROSE : merci de remplir ces deux champs.                                                        |

### 45. PAC_RAC_2

Message affiché sous le champ « DEVIS- Montant RAC ».

|                     | Aujourd'hui                                                                                                                                                                               | Proposé                                                                                                                                                                                                         |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Merci de mettre un RAC Coherent                                                                                                                                                           | « DEVIS- Montant RAC » minimum sans kit bizone (dossiers créés depuis le 27/04/2026) : 🟨JAUNE 3 000 € (Shab 70-89, ou 90 et plus en 🟧H2) ; 🟪VIOLET 6 000 € (70-89) ou 4 500 € (90 et plus) ; 🟥ROSE 7 500 €. |
| Message utilisateur | Merci de mettre un RAC coherent.<br><br>JAUNE (H1/ +90m²: 0€ - le reste des cas:3000€)<br>VIOLET (H1/H2: -90m²: 6000€ // +90m²: 4500€)<br>ROSE (H1/H2: 7500€)<br><br>Si kit Bizone +1500€ | « DEVIS- Montant RAC » trop bas. 🟨JAUNE : 3 000 € (0 € en H1 à partir de 90 m²). 🟪VIOLET : 6 000 € sous 90 m², 4 500 € à partir de 90 m². 🟥ROSE : 7 500 €. Avec un kit bizone : + 1 500 €.                   |

### 46. PAC_RAC_3

Message affiché sous le champ « DEVIS- Modalité Paiement ».

|                     | Aujourd'hui                                                                                                                                                                             | Proposé                                                                                                                                                                 |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Remplir les modalité paiement, le modele de la PAC, Ballon, Kit bizone, Compteur, le Sous traitant et la date d'installation pour passer au statut suivant                              | TH171, 🟨JAUNE avec « RES- Shab » < 90 ou « RES- Zone » = 🟧H2, « MPR- Statut » 🟪Déposé ou plus : « DEVIS- Montant RAC » et « DEVIS- Modalité Paiement » obligatoires. |
| Message utilisateur | 1.Si Le client est Jaune inferieur a 90m², merci de remplir les modalité de paiement et le RAC.<br>2.Si Le client est Jaune en H2, merci de remplir les modalité de paiement et le RAC. | Client 🟨JAUNE de moins de 90 m² ou en zone 🟧H2 : merci de remplir « DEVIS- Montant RAC » et « DEVIS- Modalité Paiement ».                                             |

### 47. PAC_RAC_8

Message affiché sous le champ « DEVIS- Montant RAC ».

|                     | Aujourd'hui                                                                                                                                                                               | Proposé                                                                                                                                                                                                                        |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Description         | Merci de mettre un RAC Coherent                                                                                                                                                           | « DEVIS- Montant RAC » minimum avec KIT BI-ZONE ou KIT 1 ZONE (dossiers créés depuis le 27/04/2026) : 🟨JAUNE 4 500 € (Shab 70-89, ou 90 et plus en 🟧H2) ; 🟪VIOLET 7 500 € (70-89) ou 6 500 € (90 et plus) ; 🟥ROSE 9 000 €. |
| Message utilisateur | Merci de mettre un RAC coherent.<br><br>JAUNE (H1/ +90m²: 0€ - le reste des cas:3000€)<br>VIOLET (H1/H2: -90m²: 6000€ // +90m²: 4500€)<br>ROSE (H1/H2: 7500€)<br><br>Si kit Bizone +1500€ | « DEVIS- Montant RAC » trop bas avec un kit. 🟨JAUNE : 4 500 € (0 € en H1 à partir de 90 m²). 🟪VIOLET : 7 500 € sous 90 m², 6 500 € à partir de 90 m². 🟥ROSE : 9 000 €.                                                      |

### 48. PAC_Statut_Dossier_1

Message affiché sous le champ « RDV- Statut Dossier ».

|                     | Aujourd'hui                                                    | Proposé                                                                                                                                               |
| ------------------- | -------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Si le client est locataire, alors le dossier est pas éligible. | TH171 : si « RES- Statut Occupation » = ⚠️Locataire, « RDV- Statut Dossier » ne peut pas être 🔵DOSSIER- Attente Installation (dossier non éligible). |
| Message utilisateur | Si le client est locataire, alors le dossier est pas éligible. | Client ⚠️Locataire : le dossier n'est pas éligible et ne peut pas passer en 🔵DOSSIER- Attente Installation.                                          |

### 49. PAC_Statut_Dossier_2

Message affiché sous le champ « MPR- Statut ».

|                     | Aujourd'hui                                                         | Proposé                                                                                                                                            |
| ------------------- | ------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Merci de mettre le bon statut de dossier pour mettre ce statut MPR. | TH171 : « MPR- Statut » = 🟫Solde Demandé, 🟩Payé- Reçu Bénéficiaire ou 🟩Payé- Virement Reçu exige « RDV- Statut Dossier » = 🟢DOSSIER- Installé. |
| Message utilisateur | Merci de mettre le bon statut de dossier pour mettre ce statut MPR. | Ce « MPR- Statut » n'est possible que si « RDV- Statut Dossier » est 🟢DOSSIER- Installé.                                                          |

### 50. PAC_Statut_Dossier_3

Message affiché sous le champ « DOCS- Com Secrétaire ».

|                     | Aujourd'hui                                                         | Proposé                                                                                        |
| ------------------- | ------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| Description         | Merci de mettre le bon statut de dossier pour mettre ce statut MPR. | « MPR- Statut » = 🟨Anomalie- Voir Commentaire : « DOCS- Com Secrétaire » obligatoire.         |
| Message utilisateur | Merci de remplir un commentaire d'anomalie MPR                      | 🟨Anomalie- Voir Commentaire : merci d'expliquer l'anomalie MPR dans « DOCS- Com Secrétaire ». |

### 51. PREVISITE10

Message affiché sous le champ « AUDIT- Statut ».

|                     | Aujourd'hui                                                                                                                                                                         | Proposé                                                                                                                                                                                                                        |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Description         | Si 171 seule on ne peut pas envoyer en audit                                                                                                                                        | TH171 seule non installée : 🟨Audit- Demandé interdit. Dès « PREVISITE- Date d'Envoi » : « PREVISITE- Type VT » obligatoire, 🟩TH171 pour une 171 seule, 🟩TH174 pour 174 ou 171+174. Type VT = « PREVISITE- Type VT finale ». |
| Message utilisateur | 1.Si 171 seule on ne peut pas envoyer en audit.<br>2. Si 171 seule Type VT171<br>3. Si 174 seule Type VT174<br>4. Si 171+174 Type VT174<br>5. Type vt ne correspond pas a VT finale | 1. TH171 seule : pas d'audit. 2. « PREVISITE- Type VT » obligatoire : 🟩TH171 pour une 171 seule, 🟩TH174 pour une 174 ou 171+174. 3. « PREVISITE- Type VT » et « PREVISITE- Type VT finale » doivent être identiques.         |

### 52. PREVISITE1_NON

Message affiché sous le champ « PREVISITE- Nécessité ».

|                     | Aujourd'hui                                                                                                                                             | Proposé                                                                                                                                                                          |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | On ne peut pas modifier les champs PREVISITE/AUDIT si il n'y en a pas.                                                                                  | « PREVISITE- Nécessité » = ❌- NON : « LOOKUP- Pré-visiteur » vide, « PREVISITE- Statut » = ▣ Nouveau Dossier, « PREVISITE- Date Passage » et « PREVISITE- Date d'Envoi » vides. |
| Message utilisateur | Si Previsite egale non, nom de societe en Nouveau dossier, Statut previsite en att planification, date de previsite et date d'envoi doivent etre vides. | Prévisite sur ❌- NON : laissez « PREVISITE- Statut » sur ▣ Nouveau Dossier et videz « LOOKUP- Pré-visiteur », « PREVISITE- Date d'Envoi » et « PREVISITE- Date Passage ».       |

### 53. PREVISITE2_OUI

Message affiché sous le champ « PREVISITE- Statut ».

|                     | Aujourd'hui                                                                                                                                                                           | Proposé                                                                                                                                              |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Merci d'enlever le nom de la société de prévisite, la date d'envoi et la date de passage de la société de prévisite si vous souhaitez que le statut previsite soit en Nouveau Dossier | « PREVISITE- Statut » = ▣ Nouveau Dossier : « LOOKUP- Pré-visiteur », « PREVISITE- Date d'Envoi » et « PREVISITE- Date Passage » doivent être vides. |
| Message utilisateur | Merci d'enlever le nom de la société de prévisite, la date d'envoi et la date de passage de la société de prévisite si vous souhaitez que le statut previsite soit en Nouveau Dossier | Pour remettre ▣ Nouveau Dossier, merci de vider « LOOKUP- Pré-visiteur », « PREVISITE- Date d'Envoi » et « PREVISITE- Date Passage ».                |

### 54. PREVISITE3_OUI

Message affiché sous le champ « PREVISITE- Statut ».

|                     | Aujourd'hui                                                                                                                          | Proposé                                                                                 |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------- |
| Description         | Pour mettre en previsite passage demandé, merci de remplir le nom de la société, la date d'envoi et d'avoir une date de passage vide | « PREVISITE- Statut » = 🟨Passage Demandé : « PREVISITE- Date Passage » doit être vide. |
| Message utilisateur | Pour mettre en previsite passage demandé, merci de remplir le nom de la société, la date d'envoi et d'avoir une date de passage vide | Pour mettre 🟨Passage Demandé, « PREVISITE- Date Passage » doit être vide.              |

### 55. PREVISITE4_OUI

Message affiché sous le champ « PREVISITE- Statut ».

|                     | Aujourd'hui                                                                                                            | Proposé                                                                                                            |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| Description         | Pour mettre le passage en planifié merci d'avoir le nom la société de prévisite,la date d'envoi et la date de passage. | « PREVISITE- Statut » = 🟧Passage Planifié : « LOOKUP- Pré-visiteur » et « PREVISITE- Date Passage » obligatoires. |
| Message utilisateur | Pour mettre le passage en planifié merci d'avoir le nom la société de prévisite,la date d'envoi et la date de passage. | Pour mettre 🟧Passage Planifié, merci de remplir « LOOKUP- Pré-visiteur » et « PREVISITE- Date Passage ».          |

### 56. PREVISITE5_OUI

Message affiché sous le champ « PREVISITE- Statut ».

|                     | Aujourd'hui                                                                                                    | Proposé                                                                                                                      |
| ------------------- | -------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| Description         | Pour mettre à replanifier merci d'avoir la date de prévisite vide et le statut conf du rdv en nouveau dossier. | « PREVISITE- Statut » = 🟫Passage à Replanifier : « PREVISITE- Date Passage » et « PREVISITE- Conf J-1 » doivent être vides. |
| Message utilisateur | Pour mettre à replanifier merci d'avoir la date de prévisite vide et le statut conf du rdv en nouveau dossier. | Pour mettre 🟫Passage à Replanifier, merci de vider « PREVISITE- Date Passage » et « PREVISITE- Conf J-1 ».                  |

### 57. PREVISITE6_OUI

Message affiché sous le champ « PREVISITE- Statut ».

|                     | Aujourd'hui                                                                                                                                                                                                                                          | Proposé                                                                                                                                                                                                                  |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Description         | Pour mettre le passage en effectué merci d'avoir le nom la société de prévisite,la date d'envoi et la date de passage.                                                                                                                               | « PREVISITE- Statut » = 🟩Passage Effectué : LOOKUP- Pré-visiteur et PREVISITE- Date Passage ; en TH171 / TH174, PREVISITE- Date d'Envoi et Type VT finale aussi, « AUDIT- Nécéssité » = ❌- NON en 171, ✅- OUI en 174. |
| Message utilisateur | 1.Pour mettre le passage en effectué, remplir nom previsiteure, date d'envoi, date de passage, type vt finale et de mettre si nécessité audit ou non<br>2.Si 171, Mettre Nécessité Audit en ''NON''<br>3.2.Si 174, Mettre Nécessité Audit en ''OUI'' | 🟩Passage Effectué : remplir « LOOKUP- Pré-visiteur », « PREVISITE- Date d'Envoi », « PREVISITE- Date Passage », « PREVISITE- Type VT finale » et « AUDIT- Nécéssité » (❌- NON en TH171, ✅- OUI en TH174).             |

### 58. PREVISITE7_OUI — règle inactive

Message affiché sous le champ « PREVISITE- Statut ».

|                     | Aujourd'hui                                                                                                                                                        | Proposé                                                                                                                                                                    |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Pour mettre le passage en effectué merci d'avoir le nom la société de prévisite,la date d'envoi et la date de passage.                                             | « RDV- Statut Dossier » = ⚫DOSSIER- Annulé alors que « PREVISITE- Statut » = 🟧Passage Planifié : bloqué, il faut prévenir le pré-visiteur et remettre 🟨Passage Demandé. |
| Message utilisateur | Si vous mettez en annulé et que la prévisite est planifié, merci de prévenir le previsiteur pur qu'il annula previsite et de remettre la visite en passage demandé | Dossier annulé avec une prévisite planifiée : merci de prévenir le pré-visiteur pour qu'il annule, puis de remettre « PREVISITE- Statut » sur 🟨Passage Demandé.           |

### 59. PREVISITE9

Message affiché sous le champ « AUDIT- Statut ».

|                     | Aujourd'hui                                                      | Proposé                                                                                                                |
| ------------------- | ---------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| Description         | Si MPR non déposé on peut pas envoyer en audit                   | « AUDIT- Statut » = 🟨Audit- Demandé interdit tant que « DR- Prev1 » contient ❌ (MPR non déposée ou docs incomplets). |
| Message utilisateur | Si MPR non déposé Ou Docs incomplet on peut pas envoyer en audit | Envoi en audit impossible : la MPR n'est pas déposée ou les docs sont incomplets (voir « DR- Prev1 »).                 |

### 60. PREVISITEUR_VISITE_DEMARREE

Message affiché sous le champ « LOOKUP- Pré-visiteur ».

|                     | Aujourd'hui                                                                                                                                                                                                                        | Proposé                   |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------- |
| Description         | Pré-visiteur modifiable par tous seulement si le statut VT d'avant valait planifie ou vide ; au-delà, profil Administrateur système seul (repéré par Id). PRIORVALUE : la réattribution remet le statut à planifie avant la règle. | _inchangée (déjà claire)_ |
| Message utilisateur | Visite déjà démarrée chez Certiko : seul un administrateur peut changer ou enlever le pré-visiteur (permis seulement en « ▣ Visite en att démarrage »).                                                                            | _inchangé (déjà clair)_   |

### 61. PREVISITE_PORTE_PAS_DE_RETOUR

Message affiché sous le champ « PREVISITE- Porte ».

|                     | Aujourd'hui                                                                                                                                                                                                                                            | Proposé                   |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------- |
| Description         | Empêche tout retour en arrière sur « PREVISITE- Porte » : une fois Porte 1 atteinte on ne peut plus vider le champ, une fois Porte 2 atteinte on ne peut plus revenir à Porte 1 ni vider. La progression (vide -> Porte 1 -> Porte 2) reste autorisée. | _inchangée (déjà claire)_ |
| Message utilisateur | Retour en arrière interdit sur « PREVISITE- Porte » : une fois Porte 1 atteinte vous ne pouvez plus vider le champ, et une fois Porte 2 atteinte vous ne pouvez plus revenir à Porte 1 ni le vider.                                                    | _inchangé (déjà clair)_   |

### 62. Relance

Message affiché sous le champ « DOCS- Relance ».

|                     | Aujourd'hui                                                                                      | Proposé                                                                                                                    |
| ------------------- | ------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------- |
| Description         | Relance un par famille                                                                           | « DOCS- Relance » : une seule valeur par famille (Appel1 à 4, Sms1 à 3, Whtsp1 à 3, Mail1 à 3) peut être cochée à la fois. |
| Message utilisateur | Vous pouvez choisir une relance par famille.<br>Uniquement 1 de chaque type appel/sms/whtsp/mail | « DOCS- Relance » : une seule relance par famille à la fois (un Appel, un Sms, un Whtsp, un Mail).                         |

### 63. SECRETARIAT_DOC_COMPLET

Message affiché sous le champ « DOCS- CEE ».

|                     | Aujourd'hui                                                                        | Proposé                                                                                                                          |
| ------------------- | ---------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Vous ne pouvez pas sélectionner le statut "Dossier Complet" avec d'autres valeurs. | « DOCS- CEE » : 🟩Dossier Complet ne peut pas être coché en même temps qu'un manquant (🟨Mq KBIS, 🟨Mq Sheets, 🟨Mq Geoportail). |
| Message utilisateur | Vous ne pouvez pas sélectionner le statut "Dossier Complet" avec d'autres valeurs. | « DOCS- CEE » : 🟩Dossier Complet ne peut pas être coché avec un document manquant (🟨Mq).                                       |

### 64. Si171_ouvert174en_attetne

Message affiché en haut de la page.

|                     | Aujourd'hui                                                                    | Proposé                                                                                                                                                                                         |
| ------------------- | ------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Vous avez une fiche 171 en court merci de la cloturer avant de passer a la 174 | Fiche TH174 : les profils Responsable Telepro et Closer ne peuvent pas changer « RDV- Statut Devis » tant que « DR-Infos fiche1 » contient ⚠️PACRes (fiche TH171 en cours pour le même client). |
| Message utilisateur | Vous avez une fiche 171 en cours merci de la cloturer avant de passer a la 174 | Une fiche TH171 est encore en cours pour ce client : merci de la clôturer avant de faire avancer le devis TH174.                                                                                |

### 65. Statut_Dossier_1

Message affiché en haut de la page.

|                     | Aujourd'hui                                                        | Proposé                                                                                                                                                                                  |
| ------------------- | ------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Merci d'avoir le statut installation en cohérence avec le dossier. | Toutes fiches CEE hors LEDS : « RDV- Statut Dossier » = 🔵DOSSIER- Attente Installation incompatible avec « INSTALLATION- Statut » = 🟩Installation Cloturée.                            |
| Message utilisateur | Merci d'avoir le statut installation en cohérence avec le dossier. | Incohérence : dossier en 🔵DOSSIER- Attente Installation alors que « INSTALLATION- Statut » est 🟩Installation Cloturée. Merci de passer « RDV- Statut Dossier » en 🟢DOSSIER- Installé. |

### 66. Statut_Dossier_2

Message affiché en haut de la page.

|                     | Aujourd'hui                                                        | Proposé                                                                                                                                                                  |
| ------------------- | ------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Description         | Merci de remplir le motif, le commentaire et la date d'Annulation. | « RDV- Statut Dossier » = ⚫DOSSIER- Annulé (toutes fiches CEE) : « RDV- Motif Annulation », « RDV- Date d'Annulation » et « RDV- Commentaire Annulation » obligatoires. |
| Message utilisateur | Merci de remplir le motif, le commentaire et la date d'Annulation. | Pour annuler le dossier, merci de remplir « RDV- Motif Annulation », « RDV- Date d'Annulation » et « RDV- Commentaire Annulation ».                                      |

### 67. Statut_Dossier_3

Message affiché sous le champ « INSTALLATION- Statut ».

|                     | Aujourd'hui                                                                                         | Proposé                                                                                                                                    |
| ------------------- | --------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| Description         | Pour mettre le statut en Dossier Installé, il faut que le statut installation PAC soit en installé. | Toutes fiches CEE hors LEDS : « INSTALLATION- Statut » = 🟩Installation Cloturée => « RDV- Statut Dossier » doit être 🟢DOSSIER- Installé. |
| Message utilisateur | Pour mettre le statut en Dossier Installé, il faut que le statut installation soit en installé.     | Installation clôturée : merci de passer « RDV- Statut Dossier » en 🟢DOSSIER- Installé.                                                    |

### 68. Statut_Dossier_4

Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                     | Proposé                                                                                                                                    |
| ------------------- | ----------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| Description         | Pour mettre le statut en Dossier Installé, il faut que le statut installation soit en installé. | Toutes fiches CEE hors LEDS : « RDV- Statut Dossier » = 🟢DOSSIER- Installé => « INSTALLATION- Statut » doit être 🟩Installation Cloturée. |
| Message utilisateur | Pour mettre le statut en Dossier Installé, il faut que le statut installation soit en installé. | Pour mettre 🟢DOSSIER- Installé, « INSTALLATION- Statut » doit être 🟩Installation Cloturée.                                               |

### 69. VALIDATION_AnnulationFrere — règle inactive

Message affiché sous le champ « RENO TH174- Annulation ».

|                     | Aujourd'hui                                                               | Proposé                                                                                                                                                                                            |
| ------------------- | ------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | _(vide)_                                                                  | Fiche TH171 ⚫DOSSIER- Annulé avec RENO TH174 demandée (✅- OUI) et « RENO TH174- Statut Dossier » = 🔵DOSSIER- Attente Installation : « RENO TH174- Annulation » (✅- OUI / ❌- NON) obligatoire. |
| Message utilisateur | Merci de répondre à la question d’annulation en sélectionnant OUI ou NON. | Merci de répondre à « RENO TH174- Annulation » par ✅- OUI ou ❌- NON.                                                                                                                             |

### 70. certikovisite_termine

Message affiché sous le champ « DOCS ES- Statut ».

|                     | Aujourd'hui                                                                                                                           | Proposé                                                                                                                                    |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| Description         | Pour mettre la visite en terminé validé, il faut la prévisite Le statut docs doit être Validé- Docs Complet ou Validé- Docs Incomplet | « CERTIKO- Statut VT » = 🟩Visite Terminée- Validé : « DOCS ES- Statut » doit contenir ✅Validé- Docs Complet ou ☑️Validé- Docs Incomplet. |
| Message utilisateur | Il faut mettre la visite en terminé validé pour pouvoir mettre: Validé- Docs Complet ou Validé- Docs Incomplet.                       | 🟩Visite Terminée- Validé : « DOCS ES- Statut » doit être ✅Validé- Docs Complet ou ☑️Validé- Docs Incomplet.                              |

### 71. date_installe_pac

Message affiché en haut de la page.

|                     | Aujourd'hui                                                                                                                                                                                              | Proposé                                                                                                                                                                                                           |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Le champ "Email du sous-traitant" ne peut pas être renseigné tant que la date d’installation de la PAC n’est pas saisie.                                                                                 | Doublon de PAC_Installation5, sans le compteur : « INSTALLATION- Mail Sous Traitant » interdit tant que INSTALLATION- Date Réel, Nom SS Traitant, Modele PAC, Kit Bi-Zone et Infos SStraitant ne sont pas saisis. |
| Message utilisateur | Le champ "Email du sous-traitant" ne peut pas être renseigné tant que la date d’installation, le lookupp ss traitant, le kit bizone, le modele de la pac et le commentaire installateur n’est pas saisi. | Avant de remplir « INSTALLATION- Mail Sous Traitant », merci de saisir les champs INSTALLATION : Date Réel, Nom SS Traitant, Modele PAC, Kit Bi-Zone et Infos SStraitant.                                         |

### 72. docs_es_docs_complet

Message affiché sous le champ « DOCS ES- Statut ».

|                     | Aujourd'hui                                                                           | Proposé                                                                                                                               |
| ------------------- | ------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| Description         | Vous ne pouvez pas sélectionner le statut Validé- Docs Complet avec d'autres valeurs. | « DOCS ES- Statut » : ✅Validé- Docs Complet ne peut pas être coché avec ☑️Validé- Docs Incomplet, ni avec un 🟨Mq ou une 🟨Anomalie. |
| Message utilisateur | Vous ne pouvez pas sélectionner le statut Validé- Docs Complet avec d'autres valeurs. | ✅Validé- Docs Complet ne peut pas être coché avec d'autres valeurs de « DOCS ES- Statut ».                                           |

### 73. docs_es_docs_incomplet

Message affiché sous le champ « DOCS ES- Statut ».

|                     | Aujourd'hui                                                                                                             | Proposé                                                                                                                                                                                                |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Description         | Si vous selectionnez "Validé- Docs Incomplet", il faut que vous sélectionnez aussi l'incomplet (photo, plaque ou autre) | « DOCS ES- Statut » : ☑️Validé- Docs Incomplet exige de cocher aussi au moins un manquant (🟨Mq Photos, 🟨Mq Photo plaque signalétique, 🟨Mq Facture(s), 🟨Mq IBI/justif propriété, 🟨Anomalie Autre). |
| Message utilisateur | Si vous selectionnez Validé- Docs Incomplet, il faut que vous sélectionnez aussi l'incomplet (photo, plaque ou autre)   | ☑️Validé- Docs Incomplet : merci de cocher aussi ce qui manque (photos, plaque signalétique, factures, IBI/justif propriété ou autre anomalie).                                                        |

## Points à vérifier (rien n'a été corrigé)

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
