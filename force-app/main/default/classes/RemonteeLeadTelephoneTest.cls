/**
 * Tests des règles sur le téléphone et l'e-mail des leads reçus.
 */
@IsTest
private class RemonteeLeadTelephoneTest {
  @IsTest
  static void cleSurLesNeufDerniersChiffres() {
    Assert.areEqual('666831456', RemonteeLeadTelephone.cle('34666831456'));
    Assert.areEqual('666831456', RemonteeLeadTelephone.cle('+34 666 83 14 56'));
    Assert.areEqual('666831456', RemonteeLeadTelephone.cle('666831456'));
    Assert.areEqual('612345678', RemonteeLeadTelephone.cle('06 12 34 56 78'));
    Assert.areEqual(
      '12345',
      RemonteeLeadTelephone.cle('12345'),
      'numéro court gardé tel quel'
    );
    Assert.isNull(RemonteeLeadTelephone.cle(''), 'numéro vide');
    Assert.isNull(RemonteeLeadTelephone.cle(null), 'numéro absent');
    Assert.isNull(RemonteeLeadTelephone.cle('abc'), 'aucun chiffre');
  }

  @IsTest
  static void numerosEspagnolsEtFrancaisAcceptes() {
    for (
      String numero : new List<String>{
        '666831456',
        '34666831456',
        '+34 666 831 456',
        '0034666831456',
        '912345670',
        '0612345678',
        '33612345678',
        '+33 6 12 34 56 78',
        '+33 (0)6 12 34 56 78',
        '0033612345678'
      }
    ) {
      Assert.isTrue(RemonteeLeadTelephone.estValide(numero), numero);
      Assert.isNull(RemonteeLeadTelephone.motifInvalide(numero), numero);
    }
  }

  @IsTest
  static void fauxNumerosRefusesAvecLeurMotif() {
    Assert.areEqual('numéro absent', RemonteeLeadTelephone.motifInvalide(null));
    Assert.areEqual('numéro absent', RemonteeLeadTelephone.motifInvalide('  '));
    Assert.areEqual(
      'nombre de chiffres incorrect (1)',
      RemonteeLeadTelephone.motifInvalide('0')
    );
    Assert.areEqual(
      'nombre de chiffres incorrect (8)',
      RemonteeLeadTelephone.motifInvalide('66683145')
    );
    Assert.areEqual(
      'début de numéro ni espagnol ni français',
      RemonteeLeadTelephone.motifInvalide('13438291793'),
      'indicatif inconnu'
    );
    Assert.areEqual(
      'début de numéro ni espagnol ni français',
      RemonteeLeadTelephone.motifInvalide('512345678'),
      'un numéro espagnol ne commence pas par 5'
    );
    for (
      String invente : new List<String>{
        '666666666',
        '600000000',
        '34699999999',
        '123456789',
        '0123456789',
        '987654321'
      }
    ) {
      Assert.areEqual(
        'numéro inventé',
        RemonteeLeadTelephone.motifInvalide(invente),
        invente
      );
      Assert.isFalse(RemonteeLeadTelephone.estValide(invente), invente);
    }
  }

  @IsTest
  static void emailValable() {
    Assert.isTrue(RemonteeLeadTelephone.emailValide('jean.dupont@gmail.com'));
    Assert.isTrue(
      RemonteeLeadTelephone.emailValide(' Maria_Prieto+1@mail.co.es ')
    );
    Assert.isFalse(RemonteeLeadTelephone.emailValide(null));
    Assert.isFalse(RemonteeLeadTelephone.emailValide(''));
    Assert.isFalse(RemonteeLeadTelephone.emailValide('jean.dupont'));
    Assert.isFalse(RemonteeLeadTelephone.emailValide('jean@gmail'));
    Assert.isFalse(RemonteeLeadTelephone.emailValide('jean dupont@gmail.com'));
    Assert.isFalse(
      RemonteeLeadTelephone.emailValide('a'.repeat(80) + '@gmail.com'),
      'plus long que le champ e-mail de la piste'
    );
  }

  @IsTest
  static void variantesDuNumero() {
    Set<String> formes = RemonteeLeadTelephone.variantes('666831456');
    Assert.areEqual(8, formes.size());
    Assert.isTrue(formes.contains('666831456'));
    Assert.isTrue(formes.contains('34666831456'));
    Assert.isTrue(formes.contains('+34666831456'));
    Assert.isTrue(formes.contains('0666831456'));
    Assert.isTrue(formes.contains('0033666831456'));
    Assert.isTrue(RemonteeLeadTelephone.variantes(null).isEmpty());
  }
}
