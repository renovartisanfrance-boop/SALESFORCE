/**
 * Tests de la chaîne de remontée, de bout en bout avec un faux Google : lecture des feuilles,
 * création des pistes, résultats à écrire, enchaînement des opérations et cas d'échec.
 *
 * Un test ne peut exécuter qu'une opération (Salesforce interdit un appel sortant après une
 * écriture dans le même test) : l'opération suivante est vérifiée par son état, ou rejouée dans
 * un autre test à partir d'un état préparé.
 */
@IsTest
private class RemonteeLeadQueueableTest {
  private static final String ID = RemonteeLeadTestData.ID_CLASSEUR;
  private static final Integer RANG = RemonteeLeadTestData.RANG_REMONTE;
  private static final String COLONNE = 'O';

  private static RemonteeLeadGoogleMock google(List<List<String>> lignes) {
    RemonteeLeadGoogleMock mock = new RemonteeLeadGoogleMock();
    mock.feuilles.put(ID, RemonteeLeadTestData.feuille(lignes));
    Test.setMock(HttpCalloutMock.class, mock);
    return mock;
  }

  private static Source_Lead__c source() {
    return RemonteeLeadTestData.source(
      RemonteeLeadTestData.fournisseur('F001'),
      ID
    );
  }

  private static String cellule(Integer ligne) {
    return GoogleSheetsClient.plage(
      RemonteeLeadTestData.ONGLET,
      COLONNE + ligne
    );
  }

  private static Source_Lead__c suivi(Id idSource) {
    return [
      SELECT Dernier_passage__c, Derniere_erreur__c, Premiere_ligne_a_traiter__c
      FROM Source_Lead__c
      WHERE Id = :idSource
    ];
  }

  // ------------------------------------------------------------ Passage normal

  @IsTest
  static void premiereOperationLitCreeEtPrepareLesResultats() {
    RemonteeLeadTestData.reglage();
    Lead ancienne = RemonteeLeadTestData.pisteExistante(
      'Ancienne',
      '34677111222',
      null
    );
    Source_Lead__c src = source();
    RemonteeLeadGoogleMock mock = google(
      new List<List<String>>{
        RemonteeLeadTestData.ligne(
          'Ana',
          '34666111222',
          'ana@exemple.com',
          'Leon'
        ),
        RemonteeLeadTestData.ligne(
          'Luis',
          '677 111 222',
          'luis@exemple.com',
          'Lugo'
        ),
        RemonteeLeadTestData.ligne('Faux', '123456789', '', 'Soria')
      }
    );

    Test.startTest();
    new RemonteeLeadQueueable().execute(null);
    Test.stopTest();

    Assert.areEqual(1, mock.appelsJeton);
    Assert.areEqual(1, mock.appelsLecture, 'titres et lignes en un seul appel');
    Assert.areEqual(
      0,
      mock.appelsEcriture,
      'les résultats partent à l’opération suivante'
    );
    List<Lead> pistes = [
      SELECT Id, LastName, Code_Fournisseur__c
      FROM Lead
      WHERE Source_Lead__c = :src.Id
    ];
    Assert.areEqual(
      1,
      pistes.size(),
      'Ana seulement : Luis est un doublon, Faux un faux numéro'
    );
    Assert.areEqual('Ana', pistes[0].LastName);
    Assert.areEqual('F001', pistes[0].Code_Fournisseur__c);
    Assert.areEqual(
      2,
      [SELECT COUNT() FROM Rejet_Lead__c WHERE Source__c = :src.Id]
    );
    Assert.areEqual(
      ancienne.Id,
      [
        SELECT Piste_existante__c
        FROM Rejet_Lead__c
        WHERE Source__c = :src.Id AND Ligne__c = 3
      ]
      .Piste_existante__c
    );

    RemonteeLeadQueueable suite = RemonteeLeadQueueable.suivante;
    Assert.isNotNull(suite, 'la chaîne continue');
    Assert.areEqual(
      0,
      RemonteeLeadQueueable.pauseSuivante,
      'résultats à écrire : sans attendre'
    );
    Map<String, String> aEcrire = suite.ecrituresEnAttente.get(src.Id);
    Assert.areEqual(3, aEcrire.size(), 'un résultat par ligne');
    Assert.isTrue(
      aEcrire.get(cellule(2)).startsWith('OK'),
      aEcrire.get(cellule(2))
    );
    Assert.isTrue(
      aEcrire.get(cellule(2)).endsWith(pistes[0].Id),
      aEcrire.get(cellule(2))
    );
    Assert.isTrue(
      aEcrire.get(cellule(3)).startsWith('DOUBLON'),
      aEcrire.get(cellule(3))
    );
    Assert.isTrue(
      aEcrire.get(cellule(4)).startsWith('FAUX NUMÉRO'),
      aEcrire.get(cellule(4))
    );
    Assert.areEqual(
      1,
      suite.curseur,
      'feuille entièrement lue : le tour est fini'
    );
    Assert.areEqual(1, suite.idsSources.size());

    Source_Lead__c etat = suivi(src.Id);
    Assert.isNotNull(etat.Dernier_passage__c);
    Assert.isNull(etat.Derniere_erreur__c);
    Assert.areEqual(
      2,
      etat.Premiere_ligne_a_traiter__c,
      'tant que les résultats ne sont pas écrits'
    );
  }

  @IsTest
  static void operationSuivanteEcritLesResultatsPuisFaitUnePause() {
    RemonteeLeadReglage reglage = RemonteeLeadTestData.reglage();
    Source_Lead__c src = source();
    RemonteeLeadGoogleMock mock = google(
      new List<List<String>>{
        RemonteeLeadTestData.ligne(
          'Ana',
          '34666111222',
          'ana@exemple.com',
          'Leon'
        ),
        RemonteeLeadTestData.ligne(
          'Luis',
          '34677111222',
          'luis@exemple.com',
          'Lugo'
        )
      }
    );
    RemonteeLeadQueueable operation = new RemonteeLeadQueueable();
    operation.idsSources = new List<Id>{ src.Id };
    operation.curseur = 0;
    operation.ecrituresEnAttente.put(
      src.Id,
      new Map<String, String>{
        cellule(2) => 'OK – 20/11/2026 10:00 – 00Q000000000001AAA',
        cellule(3) => 'DOUBLON – déjà reçu le 12/11/2026 par F002'
      }
    );

    Test.startTest();
    operation.execute(null);
    Test.stopTest();

    Assert.areEqual(
      1,
      mock.appelsEcriture,
      'les deux résultats en un seul appel'
    );
    Assert.areEqual(
      'OK – 20/11/2026 10:00 – 00Q000000000001AAA',
      mock.cellule(ID, 2, RANG)
    );
    Assert.areEqual(
      'DOUBLON – déjà reçu le 12/11/2026 par F002',
      mock.cellule(ID, 3, RANG)
    );
    Assert.areEqual(
      1,
      mock.appelsLecture,
      'la feuille est relue après l’écriture'
    );
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM Lead WHERE Source_Lead__c = :src.Id],
      'lignes terminées : rien à créer'
    );
    RemonteeLeadQueueable suite = RemonteeLeadQueueable.suivante;
    Assert.isNotNull(suite);
    Assert.areEqual(
      reglage.intervalleMinutes,
      RemonteeLeadQueueable.pauseSuivante,
      'tour terminé : pause avant le prochain'
    );
    Assert.isNull(
      suite.idsSources,
      'le prochain tour relira la liste des sources'
    );
    Assert.isTrue(suite.ecrituresEnAttente.isEmpty());
    Source_Lead__c etat = suivi(src.Id);
    Assert.areEqual(
      4,
      etat.Premiere_ligne_a_traiter__c,
      'reprise après la dernière ligne'
    );
    Assert.isNull(etat.Derniere_erreur__c);
  }

  @IsTest
  static void paquetPleinLaChaineResteSurLaFeuille() {
    RemonteeLeadReglage reglage = RemonteeLeadTestData.reglage();
    reglage.taillePaquet = 2;
    Source_Lead__c src = source();
    List<List<String>> lignes = new List<List<String>>();
    for (Integer i = 1; i <= 5; i++) {
      lignes.add(
        RemonteeLeadTestData.ligne(
          'Lead ' + i,
          '3466611122' + i,
          'lead' + i + '@exemple.com',
          'Leon'
        )
      );
    }
    google(lignes);

    Test.startTest();
    new RemonteeLeadQueueable().execute(null);
    Test.stopTest();

    Assert.areEqual(
      2,
      [SELECT COUNT() FROM Lead WHERE Source_Lead__c = :src.Id],
      'jamais plus de pistes que la taille de paquet par opération'
    );
    RemonteeLeadQueueable suite = RemonteeLeadQueueable.suivante;
    Assert.areEqual(0, RemonteeLeadQueueable.pauseSuivante);
    Assert.areEqual(0, suite.curseur, 'la feuille n’est pas finie');
    Assert.areEqual(2, suite.ecrituresEnAttente.get(src.Id).size());
  }

  @IsTest
  static void colonneDeResultatAbsenteSonTitreEstAjoute() {
    RemonteeLeadTestData.reglage();
    Source_Lead__c src = source();
    RemonteeLeadGoogleMock mock = new RemonteeLeadGoogleMock();
    mock.feuilles.put(
      ID,
      new List<List<String>>{
        new List<String>{ 'Nom', 'Num', 'Mail' },
        new List<String>{ 'Ana', '34666111222', 'ana@exemple.com' }
      }
    );
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    new RemonteeLeadQueueable().execute(null);
    Test.stopTest();

    Map<String, String> aEcrire = RemonteeLeadQueueable.suivante.ecrituresEnAttente.get(
      src.Id
    );
    Assert.areEqual(
      'Remonté',
      aEcrire.get(GoogleSheetsClient.plage(RemonteeLeadTestData.ONGLET, 'D1')),
      'titre créé juste après la dernière colonne'
    );
    Assert.isTrue(
      aEcrire.get(GoogleSheetsClient.plage(RemonteeLeadTestData.ONGLET, 'D2'))
        .startsWith('OK')
    );
  }

  // ------------------------------------------------------------ Interrupteur et démarrage

  @IsTest
  static void interrupteurCoupeRienNeTourne() {
    RemonteeLeadReglage reglage = RemonteeLeadTestData.reglage();
    reglage.actif = false;
    Source_Lead__c src = source();
    RemonteeLeadGoogleMock mock = google(
      new List<List<String>>{
        RemonteeLeadTestData.ligne(
          'Ana',
          '34666111222',
          'ana@exemple.com',
          'Leon'
        )
      }
    );

    Test.startTest();
    new RemonteeLeadQueueable().execute(null);
    Boolean demarree = RemonteeLeadQueueable.demarrerSiArretee();
    Test.stopTest();

    Assert.areEqual(
      0,
      mock.appelsJeton + mock.appelsLecture + mock.appelsEcriture
    );
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM Lead WHERE Source_Lead__c = :src.Id]
    );
    Assert.isNull(
      RemonteeLeadQueueable.suivante,
      'la chaîne s’arrête d’elle-même'
    );
    Assert.isFalse(demarree);
  }

  @IsTest
  static void demarrageEtToursSansSource() {
    RemonteeLeadReglage reglage = RemonteeLeadTestData.reglage();
    RemonteeLeadGoogleMock mock = new RemonteeLeadGoogleMock();
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    Boolean demarree = RemonteeLeadQueueable.demarrerSiArretee();
    Test.stopTest();

    Assert.isTrue(demarree, 'interrupteur actif et aucune chaîne en cours');
    Assert.areEqual(
      0,
      mock.appelsJeton,
      'aucune source : Google n’est pas appelé'
    );
    Assert.isNotNull(RemonteeLeadQueueable.suivante, 'la chaîne reste en vie');
    Assert.areEqual(
      reglage.intervalleMinutes,
      RemonteeLeadQueueable.pauseSuivante
    );
  }

  // ------------------------------------------------------------ Cas d'échec

  @IsTest
  static void connexionGoogleImpossibleNoteeSurLaSource() {
    RemonteeLeadReglage reglage = RemonteeLeadTestData.reglage();
    Source_Lead__c src = source();
    RemonteeLeadGoogleMock mock = google(
      new List<List<String>>{
        RemonteeLeadTestData.ligne(
          'Ana',
          '34666111222',
          'ana@exemple.com',
          'Leon'
        )
      }
    );
    mock.jetonRefuse = true;

    Test.startTest();
    new RemonteeLeadQueueable().execute(null);
    Test.stopTest();

    Assert.areEqual(0, mock.appelsLecture);
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM Lead WHERE Source_Lead__c = :src.Id]
    );
    Assert.isTrue(
      suivi(src.Id)
        .Derniere_erreur__c.startsWith('Connexion à Google impossible'),
      suivi(src.Id).Derniere_erreur__c
    );
    Assert.areEqual(
      reglage.intervalleMinutes,
      RemonteeLeadQueueable.pauseSuivante,
      'nouvel essai au prochain tour'
    );
  }

  @IsTest
  static void lectureImpossibleNoteeEtLaSourceEstMiseDeCote() {
    RemonteeLeadTestData.reglage();
    Source_Lead__c src = source();
    update new Source_Lead__c(Id = src.Id, Premiere_ligne_a_traiter__c = 40);
    RemonteeLeadGoogleMock mock = google(new List<List<String>>());
    mock.lectureRefusee = true;

    Test.startTest();
    new RemonteeLeadQueueable().execute(null);
    Test.stopTest();

    Source_Lead__c etat = suivi(src.Id);
    Assert.isTrue(
      etat.Derniere_erreur__c.startsWith('Lecture de la feuille impossible'),
      etat.Derniere_erreur__c
    );
    Assert.isTrue(
      etat.Derniere_erreur__c.contains('403'),
      etat.Derniere_erreur__c
    );
    Assert.isNull(
      etat.Premiere_ligne_a_traiter__c,
      'la prochaine lecture repartira du début'
    );
    Assert.isNull(RemonteeLeadQueueable.suivante.idsSources, 'tour terminé');
  }

  @IsTest
  static void ecritureImpossibleNoteeSansPerdreLesLignes() {
    RemonteeLeadTestData.reglage();
    Source_Lead__c src = source();
    RemonteeLeadGoogleMock mock = google(
      new List<List<String>>{
        RemonteeLeadTestData.ligne(
          'Ana',
          '34666111222',
          'ana@exemple.com',
          'Leon'
        )
      }
    );
    mock.ecritureRefusee = true;
    RemonteeLeadQueueable operation = new RemonteeLeadQueueable();
    operation.idsSources = new List<Id>{ src.Id };
    operation.ecrituresEnAttente.put(
      src.Id,
      new Map<String, String>{ cellule(2) => 'OK – 20/11/2026 10:00 – 00Q' }
    );

    Test.startTest();
    operation.execute(null);
    Test.stopTest();

    Assert.areEqual(1, mock.appelsEcriture);
    Assert.areEqual(
      0,
      mock.appelsLecture,
      'source mise de côté jusqu’au tour suivant'
    );
    Assert.isNull(
      mock.cellule(ID, 2, RANG),
      'la ligne reste sans résultat : elle sera relue'
    );
    Assert.isTrue(
      suivi(src.Id)
        .Derniere_erreur__c.startsWith('Écriture du résultat impossible'),
      suivi(src.Id).Derniere_erreur__c
    );
    Assert.isTrue(RemonteeLeadQueueable.suivante.ecrituresEnAttente.isEmpty());
  }

  @IsTest
  static void configurationInvalideNoteeSansAppelerGoogleSheets() {
    RemonteeLeadTestData.reglage();
    Source_Lead__c src = source();
    update new Source_Lead__c(Id = src.Id, Mapping_JSON__c = 'pas du json');
    RemonteeLeadGoogleMock mock = google(
      new List<List<String>>{
        RemonteeLeadTestData.ligne(
          'Ana',
          '34666111222',
          'ana@exemple.com',
          'Leon'
        )
      }
    );

    Test.startTest();
    new RemonteeLeadQueueable().execute(null);
    Test.stopTest();

    Assert.areEqual(0, mock.appelsLecture);
    Assert.isTrue(
      suivi(src.Id).Derniere_erreur__c.contains('illisible'),
      suivi(src.Id).Derniere_erreur__c
    );
  }
}
