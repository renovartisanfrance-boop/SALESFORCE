@isTest
private class PrevisiteurCpControllerTest {

    /** Pro__c.PREVISITE_Statut__c : sans « OUI », PREVISITE1_NON interdit tout prévisiteur. */
    private static final String PREVISITE_NECESSAIRE = 'OUI';

    @TestSetup
    static void donnees() {
        // Les triggers de Compte, Piste et Dossier font des appels sortants.
        LC027_TestFactory.bouchonnerCallouts();
        insert new List<Province__c>{
            new Province__c(Code__c = '01', Name = 'Álava', Alias__c = 'Araba;Araba/Álava', Adjacentes__c = '26'),
            new Province__c(Code__c = '24', Name = 'León', Coordonnees__Latitude__s = 42.6, Coordonnees__Longitude__s = -5.57),
            new Province__c(Code__c = '26', Name = 'La Rioja', Alias__c = 'Rioja (La)', Adjacentes__c = '01'),
            new Province__c(Code__c = '28', Name = 'Madrid', Coordonnees__Latitude__s = 40.42, Coordonnees__Longitude__s = -3.7)
        };
        insert new List<Campaign>{
            new Campaign(Name = 'Prev Signé', IsActive = true, Role__c = LC027_Roles.PREVISITEUR,
                         StatutContrat__c = LC027_GestionContrat.STATUT_SIGNE,
                         Telephone__c = '+34 600 11 22 33', Email__c = 'prev.signe@test.invalid',
                         Contrat_Provinces__c = 'Araba/Álava;Madrid;Rioja (La)'),
            new Campaign(Name = 'Prev En attente', IsActive = true, Role__c = LC027_Roles.PREVISITEUR,
                         Contrat_Provinces__c = 'León'),
            new Campaign(Name = 'Une Régie', IsActive = true, Role__c = 'Régie',
                         Contrat_Provinces__c = 'Madrid')
        };
        Map<String, Id> campagnes = new Map<String, Id>();
        for (Campaign c : [SELECT Id, Name FROM Campaign]) campagnes.put(c.Name, c.Id);
        insert new List<Account>{
            compte('PREVISITEUR- Signé', campagnes.get('Prev Signé')),
            compte('PREVISITEUR- Attente', campagnes.get('Prev En attente')),
            compte('Compte Régie', campagnes.get('Une Régie'))
        };
    }

    /** Compte construit comme le portail : RecordType « Client » (comptes personnels activés). */
    private static Account compte(String nom, Id campagneId) {
        Account a = new Account(Name = nom, Type_Intervenant__c = LC027_Roles.PREVISITEUR, Acces_REGIE__c = campagneId);
        for (RecordType rt : [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'Client' LIMIT 1]) {
            a.RecordTypeId = rt.Id;
        }
        return a;
    }

    private static Id compteId(String nom) {
        return [SELECT Id FROM Account WHERE Name = :nom].Id;
    }

    private static User utilisateur(Boolean admin) {
        Profile p = [
            SELECT Id FROM Profile
            WHERE PermissionsModifyAllData = :admin AND UserLicense.Name = 'Salesforce'
            LIMIT 1
        ];
        String cle = admin ? 'adm' : 'std';
        User u = new User(
            ProfileId = p.Id, LastName = 'Test ' + cle, Alias = 'pcp' + cle,
            Email = 'pcp.' + cle + '@test.invalid',
            Username = 'pcp.' + cle + '.' + System.now().getTime() + '@test.invalid',
            TimeZoneSidKey = 'Europe/Paris', LocaleSidKey = 'fr_FR',
            EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'fr',
            TelephoneRingover__c = '0600000000'  // obligatoire sur User dans cette org
        );
        insert u;
        return u;
    }

    private static PrevisiteurCpController.ProvinceDTO province(String code, String nom, List<String> adj) {
        PrevisiteurCpController.ProvinceDTO p = new PrevisiteurCpController.ProvinceDTO();
        p.code = code; p.nom = nom; p.adjacentes = adj;
        return p;
    }

    @isTest static void retourneLesPrevisiteursSignesSeulement() {
        PrevisiteurCpController.DonneesDTO d = PrevisiteurCpController.getDonnees();
        System.assertEquals(4, d.provinces.size());

        Map<String, PrevisiteurCpController.PrevisiteurDTO> parNom = new Map<String, PrevisiteurCpController.PrevisiteurDTO>();
        for (PrevisiteurCpController.PrevisiteurDTO p : d.previsiteurs) parNom.put(p.nom, p);
        System.assert(!parNom.containsKey('Une Régie'), 'une Régie n\'est pas un prévisiteur');

        PrevisiteurCpController.PrevisiteurDTO signe = parNom.get('Prev Signé');
        System.assertEquals(compteId('PREVISITEUR- Signé'), signe.compteId);
        System.assertEquals(new List<String>{ '01', '28', '26' }, signe.zones);
        System.assertEquals(true, signe.actif);
        System.assertEquals('prev.signe@test.invalid', signe.mail);
        System.assert(!JSON.serialize(signe).contains('600 11 22 33'), 'téléphone non transmis');

        System.assert(!parNom.containsKey('Prev En attente'), 'contrat non signé : non proposé');
    }

    @isTest static void splitZonesLitLesProvinces() {
        System.assertEquals(new List<String>{ '01', '24' }, PrevisiteurCpController.splitZones('ARABA; leon'));
        System.assertEquals(new List<String>{ '26' }, PrevisiteurCpController.splitZones('Rioja (La)'));
        System.assertEquals(new List<String>{ '28', '34', '47' }, PrevisiteurCpController.splitZones('28;34;47'));
        System.assertEquals(0, PrevisiteurCpController.splitZones('Province inconnue').size());
        System.assertEquals(0, PrevisiteurCpController.splitZones(null).size());
    }

    @isTest static void adminRemplaceLaTable() {
        User adm = utilisateur(true);
        List<PrevisiteurCpController.ProvinceDTO> liste = new List<PrevisiteurCpController.ProvinceDTO>();
        Province__c madrid = [SELECT Id FROM Province__c WHERE Code__c = '28'];
        PrevisiteurCpController.ProvinceDTO m = province('28', 'Madrid capital', new List<String>{ '45' });
        m.id = madrid.Id;
        m.alias = 'Comunidad de Madrid';
        liste.add(m);
        liste.add(province('45', 'Toledo', new List<String>{ '28' }));

        PrevisiteurCpController.DonneesDTO d;
        System.runAs(adm) {
            Test.startTest();
            System.assert(PrevisiteurCpController.estAdmin());
            d = PrevisiteurCpController.enregistrerProvinces(JSON.serialize(liste));
            Test.stopTest();
        }
        System.assertEquals(2, d.provinces.size(), 'les provinces absentes sont supprimées');
        Province__c apres = [SELECT Name, Adjacentes__c, Alias__c FROM Province__c WHERE Id = :madrid.Id];
        System.assertEquals('Madrid capital', apres.Name);
        System.assertEquals('45', apres.Adjacentes__c);
        System.assertEquals(new List<String>{ '28' }, PrevisiteurCpController.splitZones('comunidad de madrid'));
    }

    @isTest static void nonAdminRefuse() {
        User std = utilisateur(false);
        System.runAs(std) {
            System.assert(!PrevisiteurCpController.estAdmin());
            try {
                PrevisiteurCpController.enregistrerProvinces('[]');
                System.assert(false, 'un non-admin ne doit pas pouvoir enregistrer');
            } catch (AuraHandledException e) {
                System.assert(true);
            }
        }
        System.assertEquals(4, [SELECT COUNT() FROM Province__c], 'rien n\'a été supprimé');
    }

    @isTest static void saisieInvalideRefusee() {
        List<String> erreurs = PrevisiteurCpController.valider(new List<PrevisiteurCpController.ProvinceDTO>{
            province('2', 'Code court', null),
            province('28', '', new List<String>{ '99', '28' }),
            province('28', 'Doublon', null)
        });
        System.assertEquals(5, erreurs.size(), String.join(erreurs, ' | '));
    }

    @isTest static void adminErreursRemontees() {
        User adm = utilisateur(true);
        System.runAs(adm) {
            Integer refus = 0;
            for (String json : new List<String>{ 'pas du json', '[{"code":"2","nom":""}]' }) {
                try {
                    PrevisiteurCpController.enregistrerProvinces(json);
                } catch (AuraHandledException e) {
                    refus++;
                }
            }
            System.assertEquals(2, refus);
        }
        System.assertEquals(4, [SELECT COUNT() FROM Province__c], 'rien n\'a été modifié');
    }

    @isTest static void dossierPrerempliEtAttribue() {
        LC027_TestFactory.bouchonnerCallouts();
        Pro__c p = new Pro__c(
            Name = 'Dossier test', PREVISITE_Statut__c = PREVISITE_NECESSAIRE,
            LOOKUP_Pre_visiteur__c = compteId('PREVISITEUR- Attente'),
            Pr_visite_Statut__c = '🟨Passage Demandé',
            Client_Adresse_Chantier__c = 'Calle Mayor 14,,28001,MADRID',
            CodePostal__c = '28001', Phone__c = '612345678'
        );
        insert p;

        PrevisiteurCpController.ContexteDTO c = PrevisiteurCpController.getContexte(p.Id);
        System.assertEquals('28001', c.codePostal);
        System.assertEquals(compteId('PREVISITEUR- Attente'), c.compteActuelId);

        Test.startTest();
        c = PrevisiteurCpController.attribuer(p.Id, compteId('PREVISITEUR- Signé'));
        Test.stopTest();
        System.assertEquals(compteId('PREVISITEUR- Signé'), c.compteActuelId);
        System.assertEquals('28001', [SELECT CodePostal__c FROM Pro__c WHERE Id = :p.Id].CodePostal__c,
            'le code postal de la fiche n\'est jamais modifié');
    }

    @isTest static void pistePreremplie() {
        LC027_TestFactory.bouchonnerCallouts();
        Lead l = new Lead(FirstName = 'Ana', LastName = 'Lopez', Company = 'Foyer Lopez', PostalCode = '24001');
        insert l;
        Test.startTest();
        PrevisiteurCpController.ContexteDTO c = PrevisiteurCpController.getContexte(l.Id);
        Test.stopTest();
        System.assertEquals('24001', c.codePostal);
        System.assertEquals(null, c.compteActuelId);
    }

    @isTest static void attributionRefusee() {
        LC027_TestFactory.bouchonnerCallouts();
        Lead l = new Lead(FirstName = 'Ana', LastName = 'Lopez', Company = 'Foyer Lopez', PostalCode = '24001');
        insert l;
        Integer refus = 0;
        // compte qui n'est pas celui d'un prévisiteur ; puis fiche qui n'est ni Piste ni Dossier
        try { PrevisiteurCpController.attribuer(l.Id, compteId('Compte Régie')); } catch (AuraHandledException e) { refus++; }
        Id campagne = [SELECT Id FROM Campaign LIMIT 1].Id;
        try { PrevisiteurCpController.getContexte(campagne); } catch (AuraHandledException e) { refus++; }
        System.assertEquals(2, refus);
        System.assertEquals(null, [SELECT LOOKUP_Previsiteur__c FROM Lead WHERE Id = :l.Id].LOOKUP_Previsiteur__c);
    }
}