@IsTest
private class AircallSurveillanceServiceTest {
  // Mercredi 18/11/2026, 14 h à Paris.
  private static final Datetime MERCREDI_14H = Datetime.newInstanceGmt(
    2026,
    11,
    18,
    13,
    0,
    0
  );

  private static void reglages(String destinataires) {
    insert new Aircall_Surveillance__c(
      SetupOwnerId = UserInfo.getOrganizationId(),
      Actif__c = true,
      Heure_Debut__c = 9,
      Heure_Fin__c = 19,
      Delai_Heures__c = 3,
      Alertes_Max_Par_Jour__c = 2,
      Destinataires__c = destinataires
    );
  }

  private static void ficheArrivee(Datetime quand) {
    Aircall__c fiche = new Aircall__c(
      Objet__c = 'Missed Call from test on TEST',
      Telephone_Standard__c = '+33100000000',
      Nom_Standard__c = 'TEST'
    );
    insert fiche;
    Test.setCreatedDate(fiche.Id, quand);
  }

  @IsTest
  static void alerteQuandPlusRienNarrive() {
    reglages('alerte@example.com, autre@example.com');
    ficheArrivee(MERCREDI_14H.addHours(-5));

    Test.startTest();
    Boolean envoyee = new AircallSurveillanceService().verifier(MERCREDI_14H);
    Integer emails = Limits.getEmailInvocations();
    Test.stopTest();

    Assert.isTrue(envoyee, 'Une alerte doit partir après 5 h de silence');
    Assert.areEqual(1, emails, 'Un e-mail doit être envoyé');
    Aircall_Surveillance__c etat = Aircall_Surveillance__c.getOrgDefaults();
    Assert.areEqual(1, etat.Alertes_Du_Jour__c, 'Une alerte comptée');
    Assert.areEqual(MERCREDI_14H, etat.Derniere_Alerte__c);
  }

  @IsTest
  static void pasDalerteSiUnAppelEstRecent() {
    reglages('alerte@example.com');
    ficheArrivee(MERCREDI_14H.addHours(-1));

    Boolean envoyee = new AircallSurveillanceService().verifier(MERCREDI_14H);

    Assert.isFalse(envoyee, 'Un appel il y a 1 h : pas d\'alerte');
  }

  @IsTest
  static void pasDalerteLeWeekEndNiTropTot() {
    reglages('alerte@example.com');
    ficheArrivee(MERCREDI_14H.addDays(-2));
    AircallSurveillanceService service = new AircallSurveillanceService();

    Boolean samedi = service.verifier(MERCREDI_14H.addDays(3));
    Boolean mercrediDixHeures = service.verifier(MERCREDI_14H.addHours(-4));
    Boolean mercrediVingtDeuxHeures = service.verifier(
      MERCREDI_14H.addHours(8)
    );

    Assert.isFalse(samedi, 'Pas d\'alerte le samedi');
    Assert.isFalse(mercrediDixHeures, 'Pas d\'alerte avant 12 h');
    Assert.isFalse(mercrediVingtDeuxHeures, 'Pas d\'alerte après la fermeture');
  }

  @IsTest
  static void deuxAlertesParJourAuMaximum() {
    reglages('alerte@example.com');
    ficheArrivee(MERCREDI_14H.addDays(-2));
    AircallSurveillanceService service = new AircallSurveillanceService();

    Boolean premiere = service.verifier(MERCREDI_14H.addHours(-2));
    Boolean tropTot = service.verifier(MERCREDI_14H.addHours(-1));
    Boolean deuxieme = service.verifier(MERCREDI_14H.addHours(1));
    Boolean troisieme = service.verifier(MERCREDI_14H.addHours(4));
    Boolean lendemain = service.verifier(MERCREDI_14H.addDays(1));

    Assert.isTrue(premiere, 'Première alerte à 12 h');
    Assert.isFalse(tropTot, 'Pas de relance une heure après');
    Assert.isTrue(deuxieme, 'Relance 3 h après la première');
    Assert.isFalse(troisieme, 'Pas plus de deux alertes par jour');
    Assert.isTrue(lendemain, 'Le compteur repart le lendemain');
  }

  @IsTest
  static void rienSansReglagesNiDestinataire() {
    AircallSurveillanceService service = new AircallSurveillanceService();
    Boolean sansReglages = service.verifier(MERCREDI_14H);
    reglages(null);
    Boolean sansDestinataire = service.verifier(MERCREDI_14H);

    Assert.isFalse(sansReglages, 'Sans réglages, pas d\'alerte');
    Assert.isFalse(sansDestinataire, 'Sans destinataire, pas d\'alerte');
  }

  @IsTest
  static void alerteAussiSansAucuneFiche() {
    reglages('alerte@example.com');

    Boolean envoyee = new AircallSurveillanceService().verifier(MERCREDI_14H);

    Assert.isTrue(envoyee, 'Aucune fiche du tout : alerte');
  }
}
