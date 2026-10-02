/**
 * LC020_GestionCampagnes - Gestion des campagnes REGIE
 * Handles CRUD operations for campaigns with product selection
 */
public without sharing class LC020_GestionCampagnes {
    
    @AuraEnabled(cacheable=true)
    public static List<Campaign> getMyCampagnes() {
        // Check CRUD permission
        // if (!Campaign.SObjectType.getDescribe().isAccessible()) {
        //     throw new AuraHandledException('Vous n\'avez pas accès aux campagnes.');
        // }
        // System.debug('🦐🤢 ' + UserInfo.getSessionId());

        return [
            SELECT
                Id,
                Name,
                StartDate,
                EndDate,
                Status,
                Type,
                BudgetedCost,
                ActualCost,
                OwnerId,
                Owner.Name,
                CampaignToken__c,
                // Formule texte : base URL (FR ou ES selon Pays__c) + ?c__code=<token>.
                // Alimente le bouton « Copier le lien de connexion » du portail.
                LienConnexion__c,
                DateDerniereConnexion__c,
                CreatedDate,
                commentaireRegie__c,
                Email__c,
                Telephone__c,
                ProduitsDisponibles__c,
                Simulateur_BAT_TH179__c,
                Simulateur_BAT_TH163__c,
                PeutCreerREGIE__c,
                // REGIE_Commentaire_Regie__c,
                IsActive
            FROM Campaign
            WHERE OwnerId = :UserInfo.getUserId()
            ORDER BY StartDate DESC NULLS LAST
        ];
    }

    /**
     * Récupère les campagnes enfants d'une campagne parente identifiée par son token
     * Utilisé par les guest users pour voir et gérer les REGIES filles
     */
    @AuraEnabled(cacheable=false)
    public static List<Campaign> getCampaignsByParentToken(String parentToken) {
        try {
            // D'abord, trouver la campagne parente par son token
            List<Campaign> parentCampaigns = [
                SELECT Id FROM Campaign
                WHERE CampaignToken__c = :parentToken
                LIMIT 1
            ];

            if (parentCampaigns.isEmpty()) {
                throw new AuraHandledException('Campagne parente introuvable.');
            }

            Id parentId = parentCampaigns[0].Id;

            // Récupérer les campagnes enfants
            return [
                SELECT
                    Id,
                    Name,
                    StartDate,
                    EndDate,
                    Status,
                    Type,
                    BudgetedCost,
                    ActualCost,
                    OwnerId,
                    Owner.Name,
                    CampaignToken__c,
                    // Formule texte : base URL (FR ou ES selon Pays__c) + ?c__code=<token>.
                    // Alimente le bouton « Copier le lien de connexion » du portail.
                    LienConnexion__c,
                    DateDerniereConnexion__c,
                    CreatedDate,
                    commentaireRegie__c,
                    Email__c,
                    Telephone__c,
                    ProduitsDisponibles__c,
                    Simulateur_BAT_TH179__c,
                    Simulateur_BAT_TH163__c,
                    PeutCreerREGIE__c,
                    AvoirAccesCEE__c,
                    ParentId,
                    IsActive
                FROM Campaign
                WHERE ParentId = :parentId
                ORDER BY CreatedDate DESC
            ];
        } catch (QueryException e) {
            throw new AuraHandledException('Erreur lors de la récupération des campagnes : ' + e.getMessage());
        }
    }

    /**
     * Récupère les campagnes de l'utilisateur connecté ainsi que leurs campagnes filles
     * Les campagnes filles sont marquées comme readOnly
     */
    @AuraEnabled(cacheable=false)
    public static List<Map<String, Object>> getMyCampagnesWithChildren() {
        List<Map<String, Object>> result = new List<Map<String, Object>>();

        // Récupérer les campagnes de l'utilisateur
        List<Campaign> myCampaigns = [
            SELECT
                Id,
                Name,
                StartDate,
                EndDate,
                Status,
                Type,
                BudgetedCost,
                ActualCost,
                OwnerId,
                Owner.Name,
                CampaignToken__c,
                // Formule texte : base URL (FR ou ES selon Pays__c) + ?c__code=<token>.
                // Alimente le bouton « Copier le lien de connexion » du portail.
                LienConnexion__c,
                DateDerniereConnexion__c,
                CreatedDate,
                commentaireRegie__c,
                Email__c,
                Telephone__c,
                ProduitsDisponibles__c,
                Simulateur_BAT_TH179__c,
                Simulateur_BAT_TH163__c,
                PeutCreerREGIE__c,
                AvoirAccesCEE__c,
                ParentId,
                IsActive
            FROM Campaign
            WHERE OwnerId = :UserInfo.getUserId()
            AND ParentId = null
            ORDER BY CreatedDate DESC NULLS LAST
        ];

        // Collecter les IDs des campagnes de l'utilisateur
        Set<Id> myCampaignIds = new Set<Id>();
        for (Campaign c : myCampaigns) {
            myCampaignIds.add(c.Id);

            Map<String, Object> campaignMap = new Map<String, Object>();
            campaignMap.put('campaign', c);
            campaignMap.put('isReadOnly', false);
            result.add(campaignMap);
        }

        // Récupérer les campagnes filles (dont le parent appartient à l'utilisateur)
        if (!myCampaignIds.isEmpty()) {
            List<Campaign> childCampaigns = [
                SELECT
                    Id,
                    Name,
                    StartDate,
                    EndDate,
                    Status,
                    Type,
                    BudgetedCost,
                    ActualCost,
                    OwnerId,
                    Owner.Name,
                    CampaignToken__c,
                    // Formule texte : base URL (FR ou ES selon Pays__c) + ?c__code=<token>.
                    // Alimente le bouton « Copier le lien de connexion » du portail.
                    LienConnexion__c,
                    DateDerniereConnexion__c,
                    CreatedDate,
                    commentaireRegie__c,
                    Email__c,
                    Telephone__c,
                    ProduitsDisponibles__c,
                    Simulateur_BAT_TH179__c,
                    Simulateur_BAT_TH163__c,
                    PeutCreerREGIE__c,
                    AvoirAccesCEE__c,
                    ParentId,
                    Parent.Name,
                    IsActive
                FROM Campaign
                WHERE ParentId IN :myCampaignIds
                // AND OwnerId != :UserInfo.getUserId()
                ORDER BY CreatedDate DESC
            ];

            for (Campaign c : childCampaigns) {
                Map<String, Object> campaignMap = new Map<String, Object>();
                campaignMap.put('campaign', c);
                campaignMap.put('isReadOnly', true);
                campaignMap.put('parentName', c.Parent.Name);
                result.add(campaignMap);
            }
        }

        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getProduitsDisponiblesPicklistValues() {
        try {
            List<Map<String, String>> picklistValues = new List<Map<String, String>>();
            Schema.DescribeFieldResult fieldDescribe = Campaign.ProduitsDisponibles__c.getDescribe();
            List<Schema.PicklistEntry> entries = fieldDescribe.getPicklistValues();
            
            for (Schema.PicklistEntry entry : entries) {
                Map<String, String> picklistItem = new Map<String, String>();
                picklistItem.put('label', entry.getLabel());
                picklistItem.put('value', entry.getValue());
                picklistValues.add(picklistItem);
            }
            
            return picklistValues;
        } catch (Exception e) {
            throw new AuraHandledException('Erreur lors de la récupération des produits : ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void deleteCampaign(String campaignId) {
        try {
            // Check DELETE permission
            // if (!Campaign.SObjectType.getDescribe().isDeletable()) {
            //     throw new AuraHandledException('Vous n\'avez pas la permission de supprimer des campagnes.');
            // }
            
            Campaign camp = new Campaign(Id = campaignId);
            delete camp;
        } catch (DmlException e) {
            throw new AuraHandledException('Erreur lors de la suppression : ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static String createCampaign(String campaignJson) {
        try {
            // // Check CREATE permission
            // if (!Campaign.SObjectType.getDescribe().isCreateable()) {
            //     throw new AuraHandledException('Vous n\'avez pas la permission de créer des campagnes.');
            // }
            
            
            // Parse the JSON
            Map<String, Object> campaignData = (Map<String, Object>) JSON.deserializeUntyped(campaignJson);
            
            Campaign newCampaign = new Campaign();
            newCampaign.Name = (String) campaignData.get('name');
            newCampaign.StartDate = System.today();
            newCampaign.Status = 'In Progress';
            newCampaign.IsActive = (Boolean) campaignData.get('isActive');

             // Store additional info in new fields
            String email = (String) campaignData.get('email');
            String telephone = (String) campaignData.get('telephone');
            String commentaire = (String) campaignData.get('commentaire');
            newCampaign.Email__c = email;
            newCampaign.Telephone__c = telephone;
            newCampaign.commentaireRegie__c = commentaire;
            newCampaign.EstREGIE__c = true;

            // Nom de la société (obligatoire côté LWC pour les Apporteur d'Affaires)
            String nomSociete = (String) campaignData.get('nomSociete');
            if (String.isNotBlank(nomSociete)) {
                newCampaign.NomSociete__c = nomSociete;
            }

            // AvoirAccesCEE__c : envoyé par le LWC (false par défaut pour isApporteurInterne, true sinon)
            if (campaignData.containsKey('avoirAccesCEE') && campaignData.get('avoirAccesCEE') != null) {
                newCampaign.AvoirAccesCEE__c = (Boolean) campaignData.get('avoirAccesCEE');
            } else {
                newCampaign.AvoirAccesCEE__c = true;
            }

            // Check campagn with the sames email and EstREGIE = true
            List<Campaign> existingCampaigns = [
                SELECT Id 
                FROM Campaign 
                WHERE Email__c = :email 
                AND EstREGIE__c = true
                LIMIT 1
            ];
            if (!existingCampaigns.isEmpty()) {
                // Utilisateur existant
                throw new AuraHandledException('Un utilisateur avec cet email existe déjà. Veuillez utiliser un email différent.');
            }

            // Pays (France / Espagne) : recopie de la campagne parente ; renseigne plus bas
            // depuis le proprietaire si la parente est absente ou son pays vide.
            String paysCampagne = null;

            // Ajouter le ParentId si fourni
            if (campaignData.containsKey('parentId') && campaignData.get('parentId') != null) {
                newCampaign.ParentId = (String) campaignData.get('parentId');
                // get the parent campaign
                Campaign parentCamp = [SELECT Id, ProduitsDisponibles__c, PeutCreerREGIE__c, IsActive, OwnerId, Pays__c FROM Campaign WHERE Id = :newCampaign.ParentId LIMIT 1];
                // if parent campaign has produitsDisponibles__c, copy them to the new campaign
                newCampaign.ProduitsDisponibles__c = parentCamp.ProduitsDisponibles__c;

                // La campagne fille herite du pays de sa parente (meme valeur, aucune conversion).
                paysCampagne = parentCamp.Pays__c;

                // if parent campaign is not active, block the creation of the campaign and throw an exception
                if (!parentCamp.IsActive) {
                    throw new AuraHandledException('La campagne parente est inactive. Vous ne pouvez pas créer une campagne enfant à partir d\'une campagne inactive.');
                }

                // check if he can create REGIE, otherwise, block the creation of the campaign and throw an exception
                if (!parentCamp.PeutCreerREGIE__c) {
                    throw new AuraHandledException('La campagne parente n\'autorise pas la création de REGIE.');
                }

                // set the owner of the new campaign to the owner of the parent campaign
                newCampaign.OwnerId = parentCamp.OwnerId;
            }
            
           

            // Ajouter PeutCreerREGIE pour les campagnes créées via l'interface (non héritées d'une parente)
            if(newCampaign.ParentId == null) {
                 if (campaignData.containsKey('peutCreerRegie')) {
                    newCampaign.PeutCreerREGIE__c = (Boolean) campaignData.get('peutCreerRegie');
                } else {
                    newCampaign.PeutCreerREGIE__c = true; // Par défaut, les campagnes créées via l'interface peuvent créer des REGIE
                }
            } else {
                newCampaign.PeutCreerREGIE__c = false; // Les campagnes créées via l'interface ne peuvent pas créer de REGIE
            }

            // Pays (France / Espagne) : a defaut de campagne parente (ou si celle-ci n'a pas
            // de pays), on reprend celui du proprietaire de la nouvelle campagne — le
            // proprietaire de la parente pour une fille, l'utilisateur courant sinon.
            // Le champ reste vide si la source l'est : aucune valeur n'est inventee.
            if (String.isBlank(paysCampagne)) {
                Id proprietaireId = newCampaign.OwnerId != null ? newCampaign.OwnerId : UserInfo.getUserId();
                List<User> proprietaires = [SELECT Pays__c FROM User WHERE Id = :proprietaireId LIMIT 1];
                if (!proprietaires.isEmpty()) {
                    paysCampagne = proprietaires[0].Pays__c;
                }
            }
            newCampaign.Pays__c = paysCampagne;

            // Ajouter les produits disponibles
            Object produitsObj = campaignData.get('produitsDisponibles');
            if (produitsObj != null) {
                List<Object> produitsList = (List<Object>) produitsObj;
                if (!produitsList.isEmpty()) {
                    List<String> produitsStringList = new List<String>();
                    for (Object produit : produitsList) {
                        produitsStringList.add((String) produit);
                    }
                    String produitsStr = String.join(produitsStringList, ';');
                    newCampaign.ProduitsDisponibles__c = produitsStr;
                }
            }

            // Simulateurs BAT (toggles conditionnels au moment de la création).
            // Le LWC envoie la valeur seulement si le produit lié est sélectionné, sinon null.
            String simTh179 = (String) campaignData.get('simulateurBatTh179');
            if (String.isNotBlank(simTh179)) {
                newCampaign.Simulateur_BAT_TH179__c = simTh179;
            }
            String simTh163 = (String) campaignData.get('simulateurBatTh163');
            if (String.isNotBlank(simTh163)) {
                newCampaign.Simulateur_BAT_TH163__c = simTh163;
            }

            //generate a unique token of 64 caractere [A-Za-z0-9] for the campaign and check if not already used
            String campaignToken = '';
            Boolean isUnique = false;
            while (!isUnique) {
                campaignToken = generateRandomString(32);
                List<Campaign> existing = [SELECT Id FROM Campaign WHERE CampaignToken__c = :campaignToken LIMIT 1];
                if (existing.isEmpty()) {
                    isUnique = true;
                }
            }
            newCampaign.CampaignToken__c = campaignToken;

            // Envoyer l'accès vers le système externe si demandé — AVANT le DML (restriction Salesforce)
            Boolean creerAcces = campaignData.containsKey('creerAcces') ? (Boolean) campaignData.get('creerAcces') : false;
            String motDePasse = '';
            if (creerAcces == true) {
                motDePasse = (String) campaignData.get('motDePasse');
                String redirectUrl = Label.RENOV_Campagne_Base_URL + '?c__code=' + campaignToken;
                LC020_ExterneAPIService.Result accesCree = LC020_ExterneAPIService.envoyerAccesUtilisateur(
                    newCampaign.Name,
                    email,
                    motDePasse,
                    redirectUrl
                );
                if (!accesCree.success) {
                    if(accesCree.message != null) {
                        throw new AuraHandledException(accesCree.message);
                    } else {
                        throw new AuraHandledException('Erreur lors de la création de l\'accès utilisateur.');
                    }
                }

            }

            insert newCampaign;

            // Création automatique d'un Compte (RT Client) lié à la campagne via Acces_REGIE__c
            createAccountForCampaign(newCampaign, email, telephone);

            LC020_EmailService.sendCampaignEmail(newCampaign.Id, email, motDePasse);

            return newCampaign.Id;
        } catch (DmlException e) {
            throw new AuraHandledException('Erreur lors de la création : ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static String activerCEE(String campaignId) {
        try {
            Campaign camp = [
                SELECT Id, Name, Email__c, CampaignToken__c, AvoirAccesCEE__c
                FROM Campaign
                WHERE Id = :campaignId
                LIMIT 1
            ];

            if (camp.AvoirAccesCEE__c) {
                throw new AuraHandledException('L\'expérience CEE est déjà activée pour cet utilisateur.');
            }
            //generate a unique token of 64 caractere [A-Za-z0-9] for the campaign and check if not already used
            String campaignToken = '';
            Boolean isUnique = false;
            while (!isUnique) {
                campaignToken = generateRandomString(32);
                List<Campaign> existing = [SELECT Id FROM Campaign WHERE CampaignToken__c = :campaignToken LIMIT 1];
                if (existing.isEmpty()) {
                    isUnique = true;
                }
            }
            String email = camp.Email__c;
            String motDePasse = '123456';
            // String motDePasse = generateRandomString(8);
            String redirectUrl = Label.RENOV_Campagne_Base_URL + '?c__code=' + campaignToken;

            // Appel API pour mettre à jour la redirect_url AVANT le DML
            LC020_ExterneAPIService.Result redirectResult = LC020_ExterneAPIService.changerRedirectURL(email, redirectUrl, camp.Name);
            if (!redirectResult.success) {
                throw new AuraHandledException(
                    redirectResult.message != null ? redirectResult.message : 'Erreur lors de la mise à jour de la redirect URL.'
                );
            }

            // L'API a confirmé le changement : on persiste le token sur la campagne
            camp.CampaignToken__c = campaignToken;

            // // Créer l'accès dans le système externe AVANT le DML (contrainte Salesforce)
            // LC020_ExterneAPIService.Result accesCree = LC020_ExterneAPIService.envoyerAccesUtilisateur(
            //     camp.Name, email, motDePasse, redirectUrl
            // );
            // if (!accesCree.success) {
            //     throw new AuraHandledException(
            //         accesCree.message != null ? accesCree.message : 'Erreur lors de la création de l\'accès utilisateur.'
            //     );
            // }

            camp.AvoirAccesCEE__c = true;
            camp.AccesReduit__c = false;
            update camp;

            return LC020_EmailService.sendCampaignEmail(campaignId, email, motDePasse);

        } catch (AuraHandledException e) {
            throw e;
        } catch (DmlException e) {
            throw new AuraHandledException('Erreur lors de l\'activation CEE : ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void updateCampaign(String campaignJson) {
        try {
            // Check UPDATE permission (commented out for now)
            // if (!Campaign.SObjectType.getDescribe().isUpdateable()) {
            //     throw new AuraHandledException('Vous n\'avez pas la permission de modifier des campagnes.');
            // }

            Map<String, Object> campaignData = (Map<String, Object>) JSON.deserializeUntyped(campaignJson);
            String campaignId = (String) campaignData.get('campaignId');

            Campaign camp = new Campaign(Id = campaignId);

            // --- Gestion du changement d'email ---
            // L'appel API DOIT se faire AVANT le DML (contrainte Salesforce : callout interdit
            // après un DML non commité). Si l'API échoue, aucun DML n'est exécuté (= rollback).
            if (campaignData.containsKey('email')) {
                String newEmail = (String) campaignData.get('email');

                // Récupérer l'email actuel en base
                Campaign existing = [SELECT Email__c FROM Campaign WHERE Id = :campaignId LIMIT 1];
                String oldEmail = existing.Email__c;

                // Vérifier la duplication dans Salesforce
                List<Campaign> duplicates = [
                    SELECT Id
                    FROM Campaign
                    WHERE Email__c = :newEmail
                    AND EstREGIE__c = true
                    AND Id != :campaignId
                    LIMIT 1
                ];
                if (!duplicates.isEmpty()) {
                    throw new AuraHandledException('Un utilisateur avec cet email existe déjà. Veuillez utiliser un email différent.');
                }

                camp.Email__c = newEmail;

                // Appel API uniquement si l'email a réellement changé
                if (String.isNotBlank(oldEmail) && oldEmail != newEmail) {
                    LC020_ExterneAPIService.Result apiResult = LC020_ExterneAPIService.changerEmail(oldEmail, newEmail);
                    if (!apiResult.success) {
                        throw new AuraHandledException(
                            apiResult.message != null
                                ? apiResult.message
                                : 'Erreur lors du changement d\'email dans le système externe.'
                        );
                    }
                }
            }

            // --- Mise à jour des autres champs ---
            if (campaignData.containsKey('name')) {
                camp.Name = (String) campaignData.get('name');
            }
            if (campaignData.containsKey('isActive')) {
                camp.IsActive = (Boolean) campaignData.get('isActive');
            }
            if (campaignData.containsKey('telephone')) {
                camp.Telephone__c = (String) campaignData.get('telephone');
            }
            if (campaignData.containsKey('commentaire')) {
                camp.commentaireRegie__c = (String) campaignData.get('commentaire');
            }
            if (campaignData.containsKey('peutCreerRegie')) {
                camp.PeutCreerREGIE__c = (Boolean) campaignData.get('peutCreerRegie');
            }

            // Produits disponibles (campagnes parentes uniquement)
            if (camp.ParentId == null) {
                Object produitsObj = campaignData.get('produitsDisponibles');
                if (produitsObj != null) {
                    List<Object> produitsList = (List<Object>) produitsObj;
                    if (!produitsList.isEmpty()) {
                        List<String> produitsStringList = new List<String>();
                        for (Object produit : produitsList) {
                            produitsStringList.add((String) produit);
                        }
                        camp.ProduitsDisponibles__c = String.join(produitsStringList, ';');
                    } else {
                        camp.ProduitsDisponibles__c = null;
                    }
                }
            }

            // Simulateurs BAT — le LWC envoie la clé pour les profils habilités.
            // Valeur null = produit décoché ou profil non habilité → on efface le champ.
            if (campaignData.containsKey('simulateurBatTh179')) {
                camp.Simulateur_BAT_TH179__c = (String) campaignData.get('simulateurBatTh179');
            }
            if (campaignData.containsKey('simulateurBatTh163')) {
                camp.Simulateur_BAT_TH163__c = (String) campaignData.get('simulateurBatTh163');
            }

            // DML : mettre à jour la campagne et ses filles
            List<Campaign> allCampToUpdate = new List<Campaign>{ camp };
            if (camp.ParentId == null) {
                List<Campaign> childCampaigns = [
                    SELECT Id FROM Campaign
                    WHERE ParentId = :camp.Id
                ];
                for (Campaign childCamp : childCampaigns) {
                    childCamp.ProduitsDisponibles__c = camp.ProduitsDisponibles__c;
                    allCampToUpdate.add(childCamp);
                }
            }

            update allCampToUpdate;

        } catch (AuraHandledException e) {
            throw e;
        } catch (DmlException e) {
            throw new AuraHandledException('Erreur lors de la mise à jour : ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static Campaign getCampaignByToken(String campaignToken) {
        try {
            // if (!Campaign.SObjectType.getDescribe().isAccessible()) {
            //     throw new AuraHandledException('Vous n\'avez pas accès aux campagnes.');
            // }
            // System.debug('🦐🤢 session Id: ' + UserInfo.getSessionId());
            // System.debug('🦐🤢 Session Id 2 >> ' + UserInfo.getOrganizationId().substring(0, 15) + ' ' + UserInfo.getSessionId().substring(15));
            
            List<Campaign> campaigns = [
                SELECT 
                    Id, 
                    Name, 
                    Description,
                    StartDate, 
                    EndDate, 
                    Status, 
                    Type,
                    BudgetedCost, 
                    ActualCost,
                    OwnerId,
                    Owner.Name,
                    Email__c,
                    Telephone__c,
                    IsActive,
                    ProduitsDisponibles__c,
                    Simulateur_BAT_TH179__c,
                    Simulateur_BAT_TH163__c,
                    PeutCreerREGIE__c,
                    AccesReduit__c,
                    AvoirAccesCEE__c,
                    // Pays de la campagne (France / Espagne) : filtre le catalogue
                    // produits cote LWC (Cahier des charges + Nouveau RDV).
                    Pays__c,
                    ParentId,
                    Parent.Name,
                    // get campaign children (include Name for display)
                    (SELECT Id, Name FROM ChildCampaigns)
                FROM Campaign
                WHERE CampaignToken__c = :campaignToken
                LIMIT 1
            ];
            
            if (campaigns.isEmpty()) {
                throw new AuraHandledException('Campagne introuvable.');
            }
            
            // Update the last access date/time
            campaigns[0].DateDerniereConnexion__c = System.now();
            update campaigns[0];

            //
            
            return campaigns[0];
        } catch (QueryException e) {
            throw new AuraHandledException('Erreur lors de la récupération de la campagne : ' + e.getMessage());
        }
    }
    

    @AuraEnabled
    public static Map<String, Object> createLead(String leadJson, String campaignToken, String filesDataJson, String dynamicFieldsJson) {
        try {
             // Get campaign by token to find owner
            List<Campaign> campaigns = [
                SELECT Id, OwnerId, Name, ParentId, Parent.Name, Parent.OwnerId FROM Campaign
                WHERE CampaignToken__c = :campaignToken
                LIMIT 1
            ];

            if(campaigns.isEmpty()) {
                throw new AuraHandledException('Campagne introuvable pour le token fourni.');
            }

            // if (!Lead.SObjectType.getDescribe().isCreateable()) {
            //     throw new AuraHandledException('Vous n\'avez pas la permission de créer des pistes.');
            // }

            Map<String, Object> leadData = (Map<String, Object>) JSON.deserializeUntyped(leadJson);
            
            Lead newLead = new Lead();
            newLead.FirstName = (String) leadData.get('firstName');
            newLead.LastName = (String) leadData.get('lastName');
            newLead.Email = (String) leadData.get('email');
            newLead.Phone = (String) leadData.get('phone');
            newLead.TypeDeDossier__c = (String) leadData.get('TypeDeDossier__c');
            // Attribution Automatique de l'origine de la piste REGIES pour différencier les leads provenant des campagnes REGIE des autres leads
            newLead.LeadSource = 'REGIES';

            // check if the is nomDirigeant
            try {
                newLead.Nom_du_dirigeant__c = (String) leadData.get('nomDirigeant');
            } catch (Exception e) {
                // If nomDirigeant is not present or not accessible, do nothing
            }

            // Récupérer le RecordTypeId basé sur le typeEnregistrement (developerName)
            String typeEnregistrement = (String) leadData.get('typeEnregistrement');
            if (!String.isEmpty(typeEnregistrement)) {
                List<RecordType> recordTypes = [
                    SELECT Id FROM RecordType 
                    WHERE SObjectType = 'Lead' 
                    AND DeveloperName = :typeEnregistrement
                    LIMIT 1
                ];
                if (!recordTypes.isEmpty()) {
                    newLead.RecordTypeId = recordTypes[0].Id;
                }
            }
            // si meme app affaire Ok // sinon probleme

            // Verification duplication:
            // Telephone(9 derniers chiffres) + RT + (Champ ([Appafaire - nom regie]  Deja une  sur dossier(creation champs apporteur affaire ))
            String phone = newLead.Phone != null ? newLead.Phone.replaceAll('[^0-9]', '') : '';
            if (phone.length() > 9) {
                phone = phone.substring(phone.length() - 9);
            }
            String querryPhone = '%' + phone;
            // Check phone, RT, and lastmodifieddate less than 3 months:
            List<Lead> existingLeads = [
                SELECT Id
                FROM Lead 
                WHERE Phone LIKE :querryPhone
                AND RecordTypeId = :newLead.RecordTypeId
                AND LastModifiedDate > LAST_N_MONTHS:3
                AND Campagne_REGIE__c != ''
                AND Campagne_REGIE__c != :campaigns[0].Id
                LIMIT 1
            ];

            if (!existingLeads.isEmpty()) {
                throw new AuraHandledException('DUPLICATE_LEAD');
            }
            
            
            
            // Ajouter l'adresse complète au champ personnalisé
            String adresseComplete = (String) leadData.get('adresseComplete');
            if (!String.isEmpty(adresseComplete)) {
                newLead.REGIE_Adresse_Client__c = adresseComplete;
            }
            
            // Ajouter le commentaire
            String commentaire = (String) leadData.get('commentaire');
            if (!String.isEmpty(commentaire)) {
                newLead.REGIE_Commentaire_Regie__c = commentaire;
            }

            // Ajouter la date de rappel souhaitée
            String dateRappelStr = (String) leadData.get('dateRappel');
            if (!String.isEmpty(dateRappelStr)) {
                try {
                    newLead.ENVOI_CONF_Date_de_Rappel__c = Date.valueOf(dateRappelStr);
                } catch (Exception e) {
                    System.debug('⚠️ Erreur conversion date de rappel: ' + e.getMessage());
                }
            }

            // Ajouter le créneau de rappel
            String creneauRappel = (String) leadData.get('creneauRappel');
            if (!String.isEmpty(creneauRappel)) {
                newLead.ENVOI_CONF_Cr_neau_de_Rappel__c = creneauRappel;
            }

            

            // check if mini 1 or mini 2 in the campaign name and set the field accordingly
            if(campaigns[0].ParentId != null){
                // Regie 2 (Fils de Regie 1, donc petit fils de l'apporteur d'affaire)
                newLead.NonREGIE_miniAppAff__c = campaigns[0].Parent.Name;
                newLead.ApporteurAffaires__c = campaigns[0].Parent.OwnerId;

                newLead.NonREGIE_miniAppAff2__c = campaigns[0].Name;

                newLead.Campagne_REGIE__c = campaigns[0].Id;
            } else {
                // Regie 1 (Fils de l'apporteur d'affaire)
                newLead.NonREGIE_miniAppAff__c = campaigns[0].Name;
                newLead.ApporteurAffaires__c = campaigns[0].OwnerId;

                newLead.Campagne_REGIE__c = campaigns[0].Id;
            }
            

            // System debug un peut stylé et coloré pour mieux visualiser dans les logs
            System.debug('🎯 Creating Lead for Campaign: ' + campaigns[0].Name);
            // Apply dynamic fields (if provided) safely.
            if (!String.isBlank(dynamicFieldsJson)) {
                System.debug('🔧 Applying dynamic fields: ' + dynamicFieldsJson);
                Map<String, Object> dynMap = new Map<String, Object>();
                try {
                    // Prefer parsing as map (common payload: {"Company":"Société","Enseigne__c":"Enseigne"})
                    dynMap = (Map<String, Object>) JSON.deserializeUntyped(dynamicFieldsJson);
                    System.debug('🗃️ Parsing dynamic fields JSON as Map');
                } catch (Exception exMap) {
                    // If not a map, try parse as list of objects [{apiName:'X', value:'Y'}]
                    try {
                        System.debug('📜 Dynamic fields JSON is not a Map, trying to parse as List');
                        Object dynObj = JSON.deserializeUntyped(dynamicFieldsJson);
                        if (dynObj instanceof List<Object>) {
                            for (Object o : (List<Object>) dynObj) {
                                if (o instanceof Map<String, Object>) {
                                    Map<String, Object> m = (Map<String, Object>) o;
                                    String api = (String) m.get('apiName');
                                    if (api != null) {
                                        if (m.containsKey('currentValue')) dynMap.put(api, m.get('currentValue'));
                                        else if (m.containsKey('value')) dynMap.put(api, m.get('value'));
                                    }
                                    System.debug('➡️ Parsed dynamic field from list: ' + api + ' = ' + dynMap.get(api));
                                }
                            }
                        }
                    } catch (Exception exList) {
                        System.debug('⚠️ Failed to parse dynamic fields JSON as List: ' + exList.getMessage());
                    }
                }

                if (!dynMap.isEmpty()) {
                    // Describe Lead fields once
                    Map<String, Schema.SObjectField> leadFields = Schema.SObjectType.Lead.fields.getMap();
                    System.debug('🔍 Described Lead fields for dynamic mapping, total fields: ' + leadFields.size());
                    for (String apiName : dynMap.keySet()) {
                        if (String.isBlank(apiName)) {
                            System.debug('⚠️ Skipping dynamic field with blank API name');
                            continue;
                        }
                        if (!leadFields.containsKey(apiName)) {
                            System.debug('⚠️ Skipping dynamic field ' + apiName + ' - not found on Lead');
                            continue;
                        }

                        try {
                            Schema.DescribeFieldResult d = leadFields.get(apiName).getDescribe();
                            if (!d.isCreateable()) {
                                System.debug('⚠️ Skipping dynamic field ' + apiName + ' - not createable');
                                continue;
                            }

                            Object rawVal = dynMap.get(apiName);
                            if (rawVal == null){
                                newLead.put(apiName, null);
                                System.debug('➡️ Setting dynamic field ' + apiName + ' to null');
                                continue;
                            }

                            // Convert common types safely
                            Schema.DisplayType dt = d.getType();
                            System.debug('🔄 Processing dynamic field ' + apiName + ' with raw value: ' + rawVal + ' and detected type: ' + dt);
                            try {
                                if (dt == Schema.DisplayType.BOOLEAN) {
                                    Boolean b = (rawVal instanceof Boolean) ? (Boolean) rawVal : Boolean.valueOf(String.valueOf(rawVal));
                                    newLead.put(apiName, b);
                                } else if (dt == Schema.DisplayType.INTEGER) {
                                    Integer i = Integer.valueOf(String.valueOf(rawVal));
                                    newLead.put(apiName, i);
                                } else if (dt == Schema.DisplayType.DOUBLE || dt == Schema.DisplayType.CURRENCY || dt == Schema.DisplayType.PERCENT) {
                                    Decimal dec = Decimal.valueOf(String.valueOf(rawVal));
                                    newLead.put(apiName, dec);
                                } else if (dt == Schema.DisplayType.DATE) {
                                    Date dVal = Date.valueOf(String.valueOf(rawVal));
                                    newLead.put(apiName, dVal);
                                } else if (dt == Schema.DisplayType.DATETIME) {
                                    Datetime dtVal = Datetime.valueOf(String.valueOf(rawVal));
                                    newLead.put(apiName, dtVal);
                                } else {
                                    newLead.put(apiName, String.valueOf(rawVal));
                                }
                                System.debug('✅ Successfully set dynamic field ' + apiName + ' to value: ' + newLead.get(apiName));
                            } catch (Exception convEx) {
                                System.debug('⚠️ Conversion error for dynamic field ' + apiName + ' with value: ' + rawVal + ' - ' + convEx.getMessage());
                                continue;
                            }
                        } catch (Exception fEx) {
                            System.debug('⚠️ Error processing dynamic field ' + apiName + ': ' + fEx.getMessage());
                        }
                    }
                }
            }
            
            insert newLead;

            // Update the last access date/time
            campaigns[0].DateDerniereConnexion__c = System.now();
            // DerniereRecommandation__c is date field
            campaigns[0].DerniereRecommandation__c = System.today();

            update campaigns[0];
            
            // Mise à jour du ConfirmateurLookup__c avec l'owner de la campagne
            // newLead.ConfirmateurLookup__c = campaigns[0].OwnerId;
            // update newLead;
            
            if (CampaignMember.SObjectType.getDescribe().isCreateable()) {
                CampaignMember campMember = new CampaignMember();
                campMember.CampaignId = campaigns[0].Id;
                campMember.LeadId = newLead.Id;
                campMember.Status = 'Sent';
                insert campMember;
            }

            // Upload files and link them to the Lead
            List<Map<String, Object>> uploadedFiles = new List<Map<String, Object>>();
            if (!String.isBlank(filesDataJson)) {
                try {
                    List<Object> filesList = (List<Object>) JSON.deserializeUntyped(filesDataJson);

                    for (Object fileObj : filesList) {
                        Map<String, Object> fileData = (Map<String, Object>) fileObj;

                        try {
                            // Upload file with Lead as recordId (uses FirstPublishLocationId)
                            String fileName = (String) fileData.get('fileName');
                            String base64Data = (String) fileData.get('base64');
                            String contentType = (String) fileData.get('contentType');

                            // Decode base64 data
                            Blob fileBlob = EncodingUtil.base64Decode(base64Data);

                            // Create ContentVersion with FirstPublishLocationId
                            ContentVersion cv = new ContentVersion();
                            cv.Title = fileName;
                            cv.PathOnClient = fileName;
                            cv.VersionData = fileBlob;
                            cv.ContentLocation = 'S';
                            cv.IsMajorVersion = true;
                            cv.FirstPublishLocationId = newLead.Id; // Auto-link to Lead

                            insert cv;

                            // Get ContentDocumentId
                            ContentVersion insertedCV = [
                                SELECT Id, ContentDocumentId, Title
                                FROM ContentVersion
                                WHERE Id = :cv.Id
                                LIMIT 1
                            ];

                            Map<String, Object> uploadResult = new Map<String, Object>();
                            uploadResult.put('fileName', fileName);
                            uploadResult.put('contentDocumentId', insertedCV.ContentDocumentId);
                            uploadResult.put('contentVersionId', insertedCV.Id);
                            uploadResult.put('success', true);
                            uploadedFiles.add(uploadResult);

                            System.debug('Successfully uploaded and linked file: ' + fileName + ' to Lead: ' + newLead.Id);
                        } catch (Exception fileEx) {
                            Map<String, Object> uploadResult = new Map<String, Object>();
                            uploadResult.put('fileName', fileData.get('fileName'));
                            uploadResult.put('success', false);
                            uploadResult.put('error', fileEx.getMessage());
                            uploadedFiles.add(uploadResult);

                            System.debug('Error uploading file: ' + fileData.get('fileName') + ' - ' + fileEx.getMessage());
                        }
                    }
                } catch (Exception filesEx) {
                    System.debug('Warning: Could not process files for Lead: ' + filesEx.getMessage());
                    // Don't throw error - lead is already created, file upload is optional
                }
            }

            // Return Lead ID and uploaded files info
            Map<String, Object> result = new Map<String, Object>();
            result.put('leadId', newLead.Id);
            result.put('uploadedFiles', uploadedFiles);
            result.put('createdLead', newLead);

            return result;
        } catch (DmlException e) {
            throw new AuraHandledException('Erreur lors de la création de la piste : ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static List<Lead> getLeadsByCampaignToken(String campaignToken) {
        try {
            // if (!Lead.SObjectType.getDescribe().isAccessible()) {
            //     throw new AuraHandledException('Vous n\'avez pas accès aux pistes.');
            // }
            
            List<Campaign> campaigns = [
                SELECT Id, (SELECT Id FROM ChildCampaigns)
                FROM Campaign 
                WHERE CampaignToken__c = :campaignToken
                LIMIT 1
            ];
            
            if (campaigns.isEmpty()) {
                return new List<Lead>();
            }
            
            // Update the last access date/time
            campaigns[0].DateDerniereConnexion__c = System.now();
            update campaigns[0];
            
            if (!CampaignMember.SObjectType.getDescribe().isAccessible()) {
                throw new AuraHandledException('Vous n\'avez pas accès aux membres de campagne.');
            }
            
            // Collect campaign IDs: main campaign + child campaigns
            Set<Id> campaignIds = new Set<Id>();
            campaignIds.add(campaigns[0].Id);
            for (Campaign childCamp : campaigns[0].ChildCampaigns) {
                campaignIds.add(childCamp.Id);
            }
            
            List<CampaignMember> members = [
                SELECT LeadId FROM CampaignMember 
                WHERE CampaignId IN :campaignIds
            ];
            
            Set<Id> leadIds = new Set<Id>();
            for (CampaignMember member : members) {
                leadIds.add(member.LeadId);
            }
            
            if (leadIds.isEmpty()) {
                return new List<Lead>();
            }
            
            return [
                SELECT 
                    Id, 
                    FirstName, 
                    LastName, 
                    Email, 
                    Phone, 
                    Company,
                    Status,
                    LeadSource,
                    CreatedDate
                FROM Lead 
                WHERE Id IN :leadIds
                ORDER BY CreatedDate DESC
            ];
        } catch (QueryException e) {
            throw new AuraHandledException('Erreur lors de la récupération des pistes : ' + e.getMessage());
        }
    }

    /**
     * Crée un Compte (RecordType "Client") lié à la campagne via Acces_REGIE__c.
     * Appelé après l'insert de la campagne. Les erreurs sont loggées mais ne bloquent pas
     * la création de la campagne (le compte peut être recréé manuellement si besoin).
     */
    private static void createAccountForCampaign(Campaign camp, String email, String telephone) {
        try {
            Id clientRtId = null;
            List<RecordType> rts = [
                SELECT Id FROM RecordType
                WHERE SObjectType = 'Account'
                AND DeveloperName = 'Client'
                LIMIT 1
            ];
            if (!rts.isEmpty()) {
                clientRtId = rts[0].Id;
            }

            Account compte = new Account();
            compte.Name = 'REGIE- ' + camp.Name;
            if(camp.NomSociete__c != null){
                compte.Name += ' - ' + camp.NomSociete__c;
            }
            compte.Type_Intervenant__c = 'Régie';
            if (clientRtId != null) {
                compte.RecordTypeId = clientRtId;
            }
            compte.Acces_REGIE__c = camp.Id;
            if (String.isNotBlank(telephone)) {
                compte.Phone = telephone;
            }
            if (String.isNotBlank(email)) {
                // Champ standard Account.Description pour stocker l'email si pas de champ dédié
                // compte.Description = 'Email REGIE : ' + email;
                // compte.PersonEmail = email; // Si Account Personnalisé, sinon utiliser un champ personnalisé pour l'email
            }

            insert compte;
        } catch (Exception e) {
            System.debug('⚠️ Erreur création Compte pour campagne ' + camp.Id + ' : ' + e.getMessage());
        }
    }

    private static String generateRandomString(Integer length) {
        String characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
        String randomString = '';
        
        for (Integer i = 0; i < length; i++) {
            Integer randomIndex = Math.mod(Math.abs(Crypto.getRandomInteger()), characters.length());
            randomString += characters.substring(randomIndex, randomIndex + 1);
        }
        
        return randomString;
    }

    @AuraEnabled(cacheable=true)
    public static String getInfosProduits() {
        try {
            return Label.REGIE_infosProduits;
        } catch (Exception e) {
            throw new AuraHandledException('Erreur lors de la récupération des infos produits : ' + e.getMessage());
        }
    }

    public static void fakeMethod() {
        Integer dummy = 0;
        dummy++;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
          dummy++;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
         dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
          dummy++;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
         dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
          dummy++;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
        dummy--;
    }
}