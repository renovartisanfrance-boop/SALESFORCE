/**
 * Tests de la lecture des réglages de la remontée des leads.
 */
@IsTest
private class RemonteeLeadReglageTest {
  /** Un enregistrement de Custom Metadata ne se crée pas en test : il est bâti en mémoire. */
  private static Remontee_Lead_Reglage__mdt enregistrement(String texte) {
    return (Remontee_Lead_Reglage__mdt) JSON.deserialize(
      texte,
      Remontee_Lead_Reglage__mdt.class
    );
  }

  @IsTest
  static void sansEnregistrementToutEstCoupeEtPrudent() {
    RemonteeLeadReglage reglage = RemonteeLeadReglage.depuis(null);

    Assert.isFalse(reglage.actif, 'rien ne tourne sans réglage');
    Assert.areEqual(20, reglage.taillePaquet);
    Assert.areEqual(3, reglage.intervalleMinutes);
    Assert.areEqual(5, reglage.tentativesMax);
    Assert.isNull(reglage.nomCertificat);
  }

  @IsTest
  static void reprendLesValeursSaisies() {
    Remontee_Lead_Reglage__mdt saisi = enregistrement(
      '{"Actif__c":true,"Taille_paquet__c":50,"Intervalle_minutes__c":5,' +
        '"Tentatives_max__c":3,"Nom_certificat__c":"Mon_Certificat",' +
        '"Email_compte_service__c":"robot@exemple.iam.gserviceaccount.com",' +
        '"Recherche_telephone_exacte__c":false}'
    );

    RemonteeLeadReglage reglage = RemonteeLeadReglage.depuis(saisi);

    Assert.isTrue(reglage.actif);
    Assert.areEqual(50, reglage.taillePaquet);
    Assert.areEqual(5, reglage.intervalleMinutes);
    Assert.areEqual(3, reglage.tentativesMax);
    Assert.areEqual('Mon_Certificat', reglage.nomCertificat);
    Assert.areEqual(
      'robot@exemple.iam.gserviceaccount.com',
      reglage.emailCompteService
    );
    Assert.isFalse(reglage.rechercheTelephoneExacte);
  }

  @IsTest
  static void rameneLesValeursHorsBornes() {
    Remontee_Lead_Reglage__mdt saisi = enregistrement(
      '{"Actif__c":true,"Taille_paquet__c":5000,"Intervalle_minutes__c":60,' +
      '"Tentatives_max__c":0}'
    );

    RemonteeLeadReglage reglage = RemonteeLeadReglage.depuis(saisi);

    Assert.areEqual(
      200,
      reglage.taillePaquet,
      'limite Salesforce par opération'
    );
    Assert.areEqual(
      10,
      reglage.intervalleMinutes,
      'pause maximale d’un traitement différé'
    );
    Assert.areEqual(
      5,
      reglage.tentativesMax,
      'zéro n’a pas de sens : valeur par défaut'
    );
    Assert.areEqual(7, RemonteeLeadReglage.borner(null, 7, 10));
    Assert.areEqual(7, RemonteeLeadReglage.borner(-2, 7, 10));
    Assert.areEqual(4, RemonteeLeadReglage.borner(4.9, 7, 10));
  }

  @IsTest
  static void lireRendLeReglageImposeOuCeluiDeLOrg() {
    RemonteeLeadReglage org = RemonteeLeadReglage.lire();
    Assert.isNotNull(org, 'jamais null, même sans enregistrement');
    Assert.isTrue(org.taillePaquet >= 1 && org.taillePaquet <= 200);

    RemonteeLeadReglage impose = RemonteeLeadTestData.reglage();
    Assert.areEqual(impose, RemonteeLeadReglage.lire());
    Assert.isTrue(RemonteeLeadReglage.lire().actif);
  }
}
