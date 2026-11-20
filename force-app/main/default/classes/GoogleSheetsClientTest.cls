/**
 * Tests des appels à Google Sheets (jeton, lecture, écriture) avec un faux Google.
 */
@IsTest
private class GoogleSheetsClientTest {
  private static final String ID = RemonteeLeadTestData.ID_CLASSEUR;

  private static RemonteeLeadGoogleMock google() {
    RemonteeLeadGoogleMock mock = new RemonteeLeadGoogleMock();
    mock.feuilles.put(
      ID,
      new List<List<String>>{
        new List<String>{ 'Nom', 'Num', 'Remonté' },
        new List<String>{ 'Ana', '666111222' },
        new List<String>{ 'Luis', '677111222', 'OK' }
      }
    );
    Test.setMock(HttpCalloutMock.class, mock);
    return mock;
  }

  @IsTest
  static void jetonDemandeUneSeuleFoisAvecUneDemandeSignee() {
    RemonteeLeadGoogleMock mock = google();
    GoogleSheetsClient client = new GoogleSheetsClient(
      RemonteeLeadTestData.reglage()
    );

    Test.startTest();
    String premier = client.jeton();
    String second = client.jeton();
    Test.stopTest();

    Assert.areEqual('jeton-de-test', premier);
    Assert.areEqual(premier, second);
    Assert.areEqual(1, mock.appelsJeton, 'un seul appel de jeton par instance');
    Assert.isTrue(
      mock.dernierCorpsJeton.startsWith(
        'grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion='
      ),
      mock.dernierCorpsJeton
    );
    List<String> parties = mock.dernierCorpsJeton.substringAfter('assertion=')
      .split('\\.');
    Assert.areEqual(3, parties.size(), 'en-tête, contenu, signature');
    Map<String, Object> contenu = (Map<String, Object>) JSON.deserializeUntyped(
      EncodingUtil.base64Decode(
          parties[1].replace('-', '+').replace('_', '/') +
          '='.repeat(Math.mod(4 - Math.mod(parties[1].length(), 4), 4))
        )
        .toString()
    );
    Assert.areEqual(
      'robot@exemple.iam.gserviceaccount.com',
      contenu.get('iss')
    );
    Assert.areEqual('https://oauth2.googleapis.com/token', contenu.get('aud'));
    Assert.areEqual(
      'https://www.googleapis.com/auth/spreadsheets',
      contenu.get('scope')
    );
    Assert.areEqual(
      3600,
      Long.valueOf(String.valueOf(contenu.get('exp'))) -
      Long.valueOf(String.valueOf(contenu.get('iat'))),
      'jeton demandé pour une heure'
    );
  }

  @IsTest
  static void jetonRefuseOuReglageIncomplet() {
    RemonteeLeadGoogleMock mock = google();
    mock.jetonRefuse = true;
    RemonteeLeadReglage reglage = RemonteeLeadTestData.reglage();

    Test.startTest();
    try {
      new GoogleSheetsClient(reglage).jeton();
      Assert.fail('un refus de Google doit remonter');
    } catch (GoogleSheetsClient.GoogleSheetsException e) {
      Assert.isTrue(e.getMessage().contains('400'), e.getMessage());
      Assert.isTrue(
        e.getMessage().contains('Invalid JWT Signature'),
        e.getMessage()
      );
    }
    reglage.nomCertificat = null;
    try {
      new GoogleSheetsClient(reglage).jeton();
      Assert.fail('sans certificat, aucun appel ne doit partir');
    } catch (GoogleSheetsClient.GoogleSheetsException e) {
      Assert.isTrue(
        e.getMessage().contains('Réglage incomplet'),
        e.getMessage()
      );
    }
    Test.stopTest();

    Assert.areEqual(1, mock.appelsJeton, 'le second cas n’appelle pas Google');
  }

  @IsTest
  static void lectureDePlusieursPlagesEnUnAppel() {
    RemonteeLeadGoogleMock mock = google();
    GoogleSheetsClient client = new GoogleSheetsClient(
      RemonteeLeadTestData.reglage()
    );

    Test.startTest();
    List<List<List<String>>> lu = client.lirePlages(
      ID,
      new List<String>{
        GoogleSheetsClient.plage('Leads PAC', 'A1:ZZ1'),
        GoogleSheetsClient.plage('Leads PAC', 'A2:ZZ')
      }
    );
    Test.stopTest();

    Assert.areEqual(1, mock.appelsLecture);
    Assert.areEqual('Bearer jeton-de-test', mock.dernierJetonPresente);
    Assert.areEqual(2, lu.size(), 'une réponse par plage, dans l’ordre');
    Assert.areEqual(1, lu[0].size());
    Assert.areEqual('Remonté', lu[0][0][2]);
    Assert.areEqual(2, lu[1].size());
    Assert.areEqual('Ana', lu[1][0][0]);
    Assert.areEqual(2, lu[1][0].size(), 'cellule vide de fin de ligne absente');
    Assert.areEqual('OK', lu[1][1][2]);
  }

  @IsTest
  static void lectureRefuseeAvecLeMessageDeGoogle() {
    RemonteeLeadGoogleMock mock = google();
    GoogleSheetsClient client = new GoogleSheetsClient(
      RemonteeLeadTestData.reglage()
    );

    Test.startTest();
    try {
      // La feuille n'a que 3 lignes : Google refuse une plage qui commence à la ligne 9.
      client.lirePlages(
        ID,
        new List<String>{ GoogleSheetsClient.plage('Leads PAC', 'A9:ZZ') }
      );
      Assert.fail('la lecture hors grille doit échouer');
    } catch (GoogleSheetsClient.GoogleSheetsException e) {
      Assert.isTrue(
        e.getMessage().contains('exceeds grid limits'),
        e.getMessage()
      );
    }
    mock.lectureRefusee = true;
    try {
      client.lirePlages(
        ID,
        new List<String>{ GoogleSheetsClient.plage('Leads PAC', 'A1:ZZ1') }
      );
      Assert.fail('un refus d’accès doit remonter');
    } catch (GoogleSheetsClient.GoogleSheetsException e) {
      Assert.isTrue(e.getMessage().contains('403'), e.getMessage());
      Assert.isTrue(
        e.getMessage().contains('does not have permission'),
        e.getMessage()
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void ecritureDeCellules() {
    RemonteeLeadGoogleMock mock = google();
    GoogleSheetsClient client = new GoogleSheetsClient(
      RemonteeLeadTestData.reglage()
    );

    Test.startTest();
    client.ecrireCellules(ID, new Map<String, String>());
    client.ecrireCellules(
      ID,
      new Map<String, String>{
        GoogleSheetsClient.plage('Leads PAC', 'C2') => 'OK – 20/11/2026 10:00',
        GoogleSheetsClient.plage('Leads PAC', 'C4') => 'DOUBLON – déjà envoyé'
      }
    );
    mock.ecritureRefusee = true;
    try {
      client.ecrireCellules(
        ID,
        new Map<String, String>{
          GoogleSheetsClient.plage('Leads PAC', 'C3') => 'x'
        }
      );
      Assert.fail('une feuille en lecture seule doit faire échouer l’écriture');
    } catch (GoogleSheetsClient.GoogleSheetsException e) {
      Assert.isTrue(e.getMessage().contains('écriture'), e.getMessage());
    }
    Test.stopTest();

    Assert.areEqual(2, mock.appelsEcriture, 'rien à écrire = aucun appel');
    Assert.areEqual('OK – 20/11/2026 10:00', mock.cellule(ID, 2, 2));
    Assert.areEqual(
      'DOUBLON – déjà envoyé',
      mock.cellule(ID, 4, 2),
      'ligne ajoutée'
    );
    Assert.areEqual(
      'OK',
      mock.cellule(ID, 3, 2),
      'écriture refusée : inchangé'
    );
  }

  @IsTest
  static void plagesEtColonnes() {
    Assert.areEqual(
      '\'Leads PAC\'!A1:ZZ1',
      GoogleSheetsClient.plage('Leads PAC', 'A1:ZZ1')
    );
    Assert.areEqual(
      '\'Feuille d\'\'essai\'!B2',
      GoogleSheetsClient.plage('Feuille d\'essai', 'B2'),
      'apostrophe doublée'
    );
    Assert.areEqual('A', GoogleSheetsClient.lettreColonne(0));
    Assert.areEqual('Z', GoogleSheetsClient.lettreColonne(25));
    Assert.areEqual('AA', GoogleSheetsClient.lettreColonne(26));
    Assert.areEqual('AZ', GoogleSheetsClient.lettreColonne(51));
    Assert.areEqual('ZZ', GoogleSheetsClient.lettreColonne(701));
    for (Integer rang : new List<Integer>{ 0, 14, 25, 26, 51, 700, 701 }) {
      Assert.areEqual(
        rang,
        GoogleSheetsClient.rangColonne(GoogleSheetsClient.lettreColonne(rang))
      );
    }
    Assert.areEqual(
      'YQ',
      GoogleSheetsClient.base64Url(Blob.valueOf('a')),
      'sans remplissage'
    );
    Assert.areEqual(
      'Pz8-',
      GoogleSheetsClient.base64Url(Blob.valueOf('??>')),
      '+ devient -'
    );
    Assert.areEqual(
      'Pz8_',
      GoogleSheetsClient.base64Url(Blob.valueOf('???')),
      '/ devient _'
    );
  }
}
