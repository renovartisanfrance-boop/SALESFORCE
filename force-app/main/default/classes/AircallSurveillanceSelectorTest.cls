@IsTest
private class AircallSurveillanceSelectorTest {
  @IsTest
  static void donneLaDerniereArrivee() {
    AircallSurveillanceSelector selector = new AircallSurveillanceSelector();
    Datetime sansFiche = selector.derniereArrivee();
    Aircall__c fiche = new Aircall__c(
      Objet__c = 'Missed Call from test on TEST',
      Telephone_Standard__c = '+33100000000',
      Nom_Standard__c = 'TEST'
    );
    insert fiche;
    Datetime quand = Datetime.newInstanceGmt(2026, 11, 18, 9, 0, 0);
    Test.setCreatedDate(fiche.Id, quand);

    Assert.isNull(sansFiche, 'Aucune fiche : pas de date');
    Assert.areEqual(quand, selector.derniereArrivee());
  }
}
