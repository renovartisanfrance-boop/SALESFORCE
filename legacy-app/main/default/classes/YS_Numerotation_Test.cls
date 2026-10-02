/**
 * Tests de YS_Numerotation.
 *
 * ⚠️ CE QUE CES TESTS NE PEUVENT PAS COUVRIR : la concurrence. Deux
 * transactions simultanées ne sont pas simulables en Apex, donc le `FOR UPDATE`
 * — la raison d'être de cette classe — n'est vérifiable qu'en recette, deux
 * navigateurs côte à côte. Ce qui est testé ici, c'est l'arithmétique et les
 * refus explicites.
 */
@isTest
private class YS_Numerotation_Test {

    private static YS_Compteur__c compteur(Decimal depart, Decimal pas, String prefixe) {
        YS_Compteur__c c = new YS_Compteur__c(
            Name = 'Devis CAE',
            Cle__c = YS_Numerotation.CLE_DEVIS,
            Prochain__c = depart,
            Pas__c = pas,
            Prefixe__c = prefixe
        );
        insert c;
        return c;
    }

    private static Decimal prochain() {
        return [SELECT Prochain__c FROM YS_Compteur__c LIMIT 1].Prochain__c;
    }

    /* ── Arithmétique ───────────────────────────────────────────────────── */

    @isTest
    static void deuxAppelsDonnentDeuxNumerosConsecutifs() {
        compteur(1001, 1, null);

        Test.startTest();
        String un = YS_Numerotation.suivant(YS_Numerotation.CLE_DEVIS);
        String deux = YS_Numerotation.suivant(YS_Numerotation.CLE_DEVIS);
        Test.stopTest();

        System.assertEquals('1001', un);
        System.assertEquals('1002', deux);
        System.assertEquals(1003, prochain(), 'Le compteur doit pointer sur le suivant.');
    }

    /** Le pas est le seul reglage que Salesforce ne sait pas offrir nativement. */
    @isTest
    static void lePasEstRespecte() {
        compteur(1001, 10, null);

        Test.startTest();
        String un = YS_Numerotation.suivant(YS_Numerotation.CLE_DEVIS);
        String deux = YS_Numerotation.suivant(YS_Numerotation.CLE_DEVIS);
        Test.stopTest();

        System.assertEquals('1001', un);
        System.assertEquals('1011', deux);
    }

    @isTest
    static void lePrefixeEstColleDevant() {
        compteur(1001, 1, 'FA-');

        Test.startTest();
        String numero = YS_Numerotation.suivant(YS_Numerotation.CLE_DEVIS);
        Test.stopTest();

        System.assertEquals('FA-1001', numero);
    }

    /** Un numéro distribué n'est jamais repris, même si rien ne l'a consommé. */
    @isTest
    static void unNumeroDistribueNestJamaisRepris() {
        compteur(1001, 1, null);

        Test.startTest();
        Set<String> vus = new Set<String>();
        for (Integer i = 0; i < 25; i++) {
            vus.add(YS_Numerotation.suivant(YS_Numerotation.CLE_DEVIS));
        }
        Test.stopTest();

        System.assertEquals(25, vus.size(), 'Vingt-cinq appels, vingt-cinq numéros distincts.');
    }

    /* ── Refus explicites ───────────────────────────────────────────────── */

    /**
     * Une séquence absente doit NOMMER la clé manquante. Un compteur muet qui
     * inventerait un numéro serait bien pire qu'une erreur.
     */
    @isTest
    static void cleInconnueNommeLaCleManquante() {
        String message = null;

        Test.startTest();
        try {
            YS_Numerotation.suivant('SEQUENCE_ABSENTE');
        } catch (YS_Numerotation.NumerotationException e) {
            message = e.getMessage();
        }
        Test.stopTest();

        System.assertNotEquals(null, message, 'Une exception était attendue.');
        System.assert(message.contains('SEQUENCE_ABSENTE'),
            'Le message doit nommer la clé introuvable : ' + message);
    }

    /** Un pas nul redistribuerait indéfiniment le même numéro. */
    @isTest
    static void unPasNulEstRefuse() {
        compteur(1001, 0, null);
        Boolean refuse = false;

        Test.startTest();
        try {
            YS_Numerotation.suivant(YS_Numerotation.CLE_DEVIS);
        } catch (YS_Numerotation.NumerotationException e) {
            refuse = true;
        }
        Test.stopTest();

        System.assert(refuse, 'Un pas nul doit être refusé, pas appliqué.');
        System.assertEquals(1001, prochain(), 'Le compteur ne doit pas avoir bougé.');
    }

    @isTest
    static void cleVideEstRefusee() {
        Boolean refuse = false;

        Test.startTest();
        try {
            YS_Numerotation.suivant('');
        } catch (YS_Numerotation.NumerotationException e) {
            refuse = true;
        }
        Test.stopTest();

        System.assert(refuse);
    }

    @isTest
    static void suivantNumeriqueRenvoieUnNombre() {
        compteur(1001, 1, 'FA-');

        Test.startTest();
        Decimal numero = YS_Numerotation.suivantNumerique(YS_Numerotation.CLE_DEVIS);
        Test.stopTest();

        System.assertEquals(1001, numero, 'Le préfixe ne doit pas entrer dans la valeur numérique.');
    }
}