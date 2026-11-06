/**
 * Tests de LeadReferenceCadastrale (via LeadTrigger / LeadTriggerHandler).
 *
 * Références valides utilisées (lettres de contrôle exactes) :
 *  9872023VH5797S0001WX (exemple officiel du Catastro), 2749704YJ0624N0001DI,
 *  9872023VH5797S0002EM, 9872023VH5797S0003RQ, 1234567AB1234C0001OS.
 */
@isTest
private class LeadReferenceCadastrale_Test {

    private static final String FICHE_RES060 = 'RESIDENTIEL_REGIES_-_RES060';

    /** Les triggers et Flows des Pistes font des appels sortants (géocodage, SMS). */
    private class BouchonCallout implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest requete) {
            HttpResponse reponse = new HttpResponse();
            reponse.setStatusCode(200);
            reponse.setHeader('Content-Type', 'application/json');
            String endpoint = requete.getEndpoint();
            reponse.setBody(endpoint != null && endpoint.contains('nominatim') ? '[]' : '{"success":true}');
            return reponse;
        }
    }

    private static Lead piste(String nom, String reference, Boolean ficheRes060) {
        // VR_Lead_TypeDeDossier_CoherenceRecordTyp : une piste RES060 doit être d'un type résidentiel.
        return new Lead(
            RecordTypeId = Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName()
                .get('RESIDENTIEL_REGIES').getRecordTypeId(),
            LastName = nom,
            Company = 'Foyer ' + nom,
            TypeDeDossier__c = ficheRes060 ? FICHE_RES060 : null,
            Parcelle_Cadastrale__c = reference
        );
    }

    private static String erreurInsertion(Lead l) {
        try {
            insert l;
        } catch (DmlException e) {
            return e.getMessage();
        }
        return null;
    }

    private static String erreurMiseAJour(Lead l) {
        try {
            update l;
        } catch (DmlException e) {
            return e.getMessage();
        }
        return null;
    }

    // ------------------------------------------------------------ Format

    @isTest
    static void lettresDeControle() {
        Assert.areEqual('WX', LeadReferenceCadastrale.lettresControle('9872023VH5797S0001WX'));
        Assert.areEqual('DI', LeadReferenceCadastrale.lettresControle('2749704YJ0624N0001DI'));
        Assert.isNull(LeadReferenceCadastrale.erreurFormat('9872023VH5797S0001WX'));
        Assert.areEqual(LeadReferenceCadastrale.MSG_CONTROLE, LeadReferenceCadastrale.erreurFormat('9872023VH5797S0001WA'));
        Assert.areEqual(LeadReferenceCadastrale.MSG_FORMAT, LeadReferenceCadastrale.erreurFormat('9872023VH5797S'));
        Assert.areEqual(LeadReferenceCadastrale.MSG_FORMAT, LeadReferenceCadastrale.erreurFormat('9872023VH5797S0001WXZ'));
        Assert.areEqual(LeadReferenceCadastrale.MSG_FORMAT, LeadReferenceCadastrale.erreurFormat('9872023VH5797SABCDWX'));
        Assert.areEqual('9872023VH5797S0001WX', LeadReferenceCadastrale.normaliser(' 9872023 vh5797s-0001.wx '));
    }

    @isTest
    static void referenceValideNormalisee() {
        Test.setMock(HttpCalloutMock.class, new BouchonCallout());
        Lead l = piste('Valide', '9872023 vh5797s 0001 wx', true);

        Test.startTest();
        insert l;
        Test.stopTest();

        Assert.areEqual('9872023VH5797S0001WX',
            [SELECT Parcelle_Cadastrale__c FROM Lead WHERE Id = :l.Id].Parcelle_Cadastrale__c);
    }

    @isTest
    static void formatInvalideBloque() {
        Test.setMock(HttpCalloutMock.class, new BouchonCallout());

        Test.startTest();
        String erreurLongueur = erreurInsertion(piste('Courte', '9872023VH5797S', true));
        String erreurControle = erreurInsertion(piste('Controle', '9872023VH5797S0001AA', true));
        Test.stopTest();

        Assert.isTrue(erreurLongueur.contains('20 caractères attendus'), erreurLongueur);
        Assert.isTrue(erreurControle.contains('les 2 dernières lettres ne correspondent pas'), erreurControle);
    }

    @isTest
    static void horsRes060NonControle() {
        Test.setMock(HttpCalloutMock.class, new BouchonCallout());

        Test.startTest();
        insert piste('Autre fiche', 'n importe quoi', false);
        insert piste('Autre fiche bis', 'n importe quoi', false);
        Test.stopTest();

        Assert.areEqual(2, [SELECT COUNT() FROM Lead WHERE Parcelle_Cadastrale__c = 'n importe quoi']);
    }

    // ------------------------------------------------------------ Doublons

    @isTest
    static void doublonSaisieUtilisateurCiteLaPiste() {
        Test.setMock(HttpCalloutMock.class, new BouchonCallout());
        LeadReferenceCadastrale.saisieAutomatiqueForcee = false;
        insert piste('Existante', '9872023VH5797S0001WX', true);

        Test.startTest();
        String erreur = erreurInsertion(piste('Nouvelle', '9872023VH5797S0001WX', true));
        Test.stopTest();

        Assert.isTrue(erreur.contains('Référence cadastrale déjà utilisée : Piste « Existante »'), erreur);
        Assert.isTrue(erreur.contains('non convertie'), erreur);
        Assert.isTrue(erreur.contains('Referencia catastral ya utilizada: Lead « Existante »'), erreur);
    }

    @isTest
    static void doublonSaisieAutomatiqueSansDetail() {
        Test.setMock(HttpCalloutMock.class, new BouchonCallout());
        insert piste('Existante', '9872023VH5797S0001WX', true);
        LeadReferenceCadastrale.saisieAutomatiqueForcee = true;

        Test.startTest();
        String erreur = erreurInsertion(piste('Nouvelle', '9872023VH5797S0001WX', true));
        Test.stopTest();

        Assert.isTrue(erreur.contains(LeadReferenceCadastrale.MSG_DOUBLON_ANONYME), erreur);
        Assert.isFalse(erreur.contains('Existante'), erreur);
    }

    @isTest
    static void doublonAncienneValeurMalFormee() {
        Test.setMock(HttpCalloutMock.class, new BouchonCallout());
        LeadReferenceCadastrale.saisieAutomatiqueForcee = false;
        // Valeur historique saisie avec espaces et en minuscules, jamais contrôlée.
        insert piste('Historique', '9872023 vh5797s 0002 em', false);

        Test.startTest();
        String erreur = erreurInsertion(piste('Nouvelle', '9872023VH5797S0002EM', true));
        Test.stopTest();

        Assert.isTrue(erreur.contains('Piste « Historique »'), erreur);
    }

    @isTest
    static void memeParcelleAutreLogementAccepte() {
        Test.setMock(HttpCalloutMock.class, new BouchonCallout());
        insert piste('Logement 1', '9872023VH5797S0001WX', true);

        Test.startTest();
        insert piste('Logement 3', '9872023VH5797S0003RQ', true);
        Test.stopTest();

        Assert.areEqual(2, [SELECT COUNT() FROM Lead WHERE Parcelle_Cadastrale__c LIKE '9872023VH5797S%']);
    }

    @isTest
    static void doublonDansLeMemeLot() {
        Test.setMock(HttpCalloutMock.class, new BouchonCallout());

        Test.startTest();
        List<Database.SaveResult> resultats = Database.insert(new List<Lead>{
            piste('Lot 1', '1234567AB1234C0001OS', true),
            piste('Lot 2', '1234567AB1234C0001OS', true)
        }, false);
        Test.stopTest();

        Assert.isTrue(resultats[0].isSuccess());
        Assert.isFalse(resultats[1].isSuccess());
        Assert.areEqual(LeadReferenceCadastrale.MSG_DOUBLON_ANONYME, resultats[1].getErrors()[0].getMessage());
    }

    @isTest
    static void miseAJourVersUnDoublonBloquee() {
        Test.setMock(HttpCalloutMock.class, new BouchonCallout());
        LeadReferenceCadastrale.saisieAutomatiqueForcee = false;
        insert piste('Existante', '9872023VH5797S0001WX', true);
        Lead l = piste('A corriger', '2749704YJ0624N0001DI', true);
        insert l;

        Test.startTest();
        l.Parcelle_Cadastrale__c = '9872023VH5797S0001WX';
        String erreur = erreurMiseAJour(l);
        Test.stopTest();

        Assert.isTrue(erreur.contains('Piste « Existante »'), erreur);
    }

    @isTest
    static void doublonHistoriqueNonBloquePourUneAutreModification() {
        Test.setMock(HttpCalloutMock.class, new BouchonCallout());
        // Deux pistes déjà en base avec la même référence (la seconde hors RES060,
        // donc jamais contrôlée) : modifier un autre champ de la première ne bloque pas.
        Lead a = piste('Historique A', '9872023VH5797S0001WX', true);
        insert a;
        Lead b = piste('Historique B', '9872023VH5797S0001WX', false);
        insert b;

        Test.startTest();
        a.Company = 'Foyer modifié';
        update a;
        Test.stopTest();

        Assert.areEqual('Foyer modifié', [SELECT Company FROM Lead WHERE Id = :a.Id].Company);
    }

    /**
     * Piste convertie : le Dossier est retrouvé par Dossiers.Opportunite__c. La vraie
     * conversion n'est pas rejouée ici (une cinquantaine de règles de validation de
     * conversion sur Piste) : on crée directement l'opportunité et ses Dossiers.
     */
    @isTest
    static void dossierRetrouveParOpportunite() {
        Test.setMock(HttpCalloutMock.class, new BouchonCallout());
        Opportunity opportunite = new Opportunity(Name = 'Opportunite cadastre', StageName = 'Prospecting', CloseDate = Date.today());
        insert opportunite;
        List<Pro__c> existants = [SELECT Id FROM Pro__c WHERE Opportunite__c = :opportunite.Id];
        if (existants.isEmpty()) {
            insert new Pro__c(Name = 'DOSSIER CADASTRE', Opportunite__c = opportunite.Id);
        }

        Test.startTest();
        Map<Id, Pro__c> resultat = LeadReferenceCadastrale.dossiersParOpportunite(new Set<Id>{ opportunite.Id });
        Map<Id, Pro__c> vide = LeadReferenceCadastrale.dossiersParOpportunite(new Set<Id>());
        Test.stopTest();

        Assert.isTrue(resultat.containsKey(opportunite.Id));
        Assert.isTrue(vide.isEmpty());
    }

    @isTest
    static void messageDossier() {
        Lead autre = (Lead) JSON.deserialize(
            '{"attributes":{"type":"Lead"},"Name":"Cliente","IsConverted":true,'
            + '"CreatedDate":"2026-10-01T10:00:00.000+0000","Owner":{"attributes":{"type":"User"},"Name":"ALAN"}}',
            Lead.class);
        Pro__c dossier = new Pro__c(Name = 'DOSSIER CLIENTE');

        String message = LeadReferenceCadastrale.messageDoublon(autre, dossier);

        Assert.isTrue(message.startsWith('Référence cadastrale déjà utilisée : Dossier « DOSSIER CLIENTE » (piste convertie, télépro ALAN, créée le '), message);
        Assert.isTrue(message.contains('Expediente « DOSSIER CLIENTE » (lead convertido, teleoperador ALAN'), message);
        Assert.isTrue(LeadReferenceCadastrale.messageDoublon(autre, null).contains('Piste « Cliente » (convertie, télépro ALAN'));
    }
}