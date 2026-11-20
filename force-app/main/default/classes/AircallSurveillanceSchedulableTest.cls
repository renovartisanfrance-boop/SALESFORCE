@IsTest
private class AircallSurveillanceSchedulableTest {
  @IsTest
  static void seProgrammeEtSexecute() {
    Test.startTest();
    Id tache = System.schedule(
      'Test surveillance Aircall',
      '0 0 * ? * MON-FRI',
      new AircallSurveillanceSchedulable()
    );
    new AircallSurveillanceSchedulable().execute(null);
    Test.stopTest();

    Assert.areEqual(
      1,
      [SELECT COUNT() FROM CronTrigger WHERE Id = :tache],
      'La vérification doit être programmée'
    );
  }
}
