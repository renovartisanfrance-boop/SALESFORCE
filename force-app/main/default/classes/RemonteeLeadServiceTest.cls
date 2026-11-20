/**
 * Tests de la transformation des lignes de feuille en pistes : création, doublons, faux numéros,
 * erreurs, lignes déjà remontées, et contrôle de la configuration d'une Source.
 */
@IsTest
private class RemonteeLeadServiceTest {
  private static final String SEP = RemonteeLeadFeuille.SEPARATEUR;

  private static Source_Lead__c source(String code) {
    return RemonteeLeadTestData.source(
      RemonteeLeadTestData.fournisseur(code),
      'classeur-' + code
    );
  }

  private static List<Lead> pistesDe(Source_Lead__c source) {
    return [
      SELECT
        Id,
        LastName,
        Phone,
        Email,
        City,
        RecordType.DeveloperName,
        LeadSource,
        Status,
        Origine_de_la_demande__c,
        TypeDeDossier__c,
        CP_Formulaire__c,
        Heure_de_cr_ation__c,
        Mode_de_chauffage_Formulaire__c,
        Source_Lead__c,
        Code_Fournisseur__c,
        Ligne_Feuille__c,
        Telephone_Cle__c,
        Faux_Numero__c
      FROM Lead
      WHERE Source_Lead__c = :source.Id
      ORDER BY Ligne_Feuille__c
    ];
  }

  private static List<Rejet_Lead__c> rejetsDe(Source_Lead__c source) {
    return [
      SELECT
        Motif__c,
        Telephone__c,
        Email__c,
        Nom__c,
        Ligne__c,
        Piste_existante__c,
        Detail__c,
        Fournisseur__c,
        Date_rejet__c
      FROM Rejet_Lead__c
      WHERE Source__c = :source.Id
      ORDER BY Ligne__c
    ];
  }

  // ------------------------------------------------------------ Création

  @IsTest
  static void ligneNormaleCreeUnePisteCommeUnZap() {
    Test.setMock(HttpCalloutMock.class, new RemonteeLeadGoogleMock());
    Source_Lead__c src = source('F001');
    RemonteeLeadService.Travail travail = RemonteeLeadTestData.travail(
      src,
      2,
      RemonteeLeadTestData.ligne(
        'Ana Lopez',
        '+34 666 111 222',
        'ana.lopez@exemple.com',
        'Asturias'
      )
    );

    Test.startTest();
    Map<Id, Map<Integer, String>> statuts = new RemonteeLeadService()
      .traiter(
        new List<RemonteeLeadService.Travail>{ travail },
        RemonteeLeadTestData.reglage()
      );
    Test.stopTest();

    List<Lead> pistes = pistesDe(src);
    Assert.areEqual(1, pistes.size());
    Lead p = pistes[0];
    Assert.areEqual('Ana Lopez', p.LastName, 'nom complet dans le nom');
    Assert.areEqual('ana.lopez@exemple.com', p.Email);
    Assert.areEqual('Asturias', p.City);
    Assert.areEqual(
      RemonteeLeadTestData.TYPE_ENREGISTREMENT,
      p.RecordType.DeveloperName
    );
    Assert.areEqual('LEADS', p.LeadSource);
    Assert.areEqual(
      'TEST REMONTEE',
      p.Origine_de_la_demande__c,
      'campagne de la source'
    );
    Assert.areEqual('RESIDENTIEL_REGIES_-_RES060', p.TypeDeDossier__c);
    Assert.areEqual('24730', p.CP_Formulaire__c);
    Assert.areEqual('20/11/2026 10:00:00', p.Heure_de_cr_ation__c);
    Assert.areEqual('caldera_de_gas', p.Mode_de_chauffage_Formulaire__c);
    Assert.areEqual('F001', p.Code_Fournisseur__c);
    Assert.areEqual(
      '666111222',
      p.Telephone_Cle__c,
      'clé de comparaison posée'
    );
    Assert.areEqual(src.Id + '|2|666111222', p.Ligne_Feuille__c);
    Assert.isFalse(p.Faux_Numero__c);

    String statut = statuts.get(src.Id).get(2);
    Assert.isTrue(statut.startsWith('OK' + SEP), statut);
    Assert.isTrue(statut.endsWith(SEP + p.Id), statut);
    Assert.isTrue(rejetsDe(src).isEmpty(), 'rien à historiser');
  }

  @IsTest
  static void villeTropLongueCoupeeAuLieuDEtreRefusee() {
    Test.setMock(HttpCalloutMock.class, new RemonteeLeadGoogleMock());
    Source_Lead__c src = source('F001');
    String adresse = 'santa cruz de retorta castro 1 guntin de pallares lugo';

    Test.startTest();
    Map<Id, Map<Integer, String>> statuts = new RemonteeLeadService()
      .traiter(
        new List<RemonteeLeadService.Travail>{
          RemonteeLeadTestData.travail(
            src,
            2,
            RemonteeLeadTestData.ligne(
              'Daniel',
              '34647113687',
              'daniel@exemple.com',
              adresse
            )
          )
        },
        RemonteeLeadTestData.reglage()
      );
    Test.stopTest();

    List<Lead> pistes = pistesDe(src);
    Assert.areEqual(
      1,
      pistes.size(),
      'la piste est créée malgré la ville trop longue'
    );
    Assert.areEqual(adresse.left(40), pistes[0].City);
    Assert.isTrue(statuts.get(src.Id).get(2).startsWith('OK'));
  }

  // ------------------------------------------------------------ Doublons

  @IsTest
  static void doublonDUneAnciennePisteHorsFournisseurs() {
    Test.setMock(HttpCalloutMock.class, new RemonteeLeadGoogleMock());
    Lead ancienne = RemonteeLeadTestData.pisteExistante(
      'Ancienne',
      '34666111222',
      null
    );
    Source_Lead__c src = source('F001');

    Test.startTest();
    Map<Id, Map<Integer, String>> statuts = new RemonteeLeadService()
      .traiter(
        new List<RemonteeLeadService.Travail>{
          RemonteeLeadTestData.travail(
            src,
            5,
            RemonteeLeadTestData.ligne(
              'Ana',
              '666 111 222',
              'ana@exemple.com',
              'Leon'
            )
          )
        },
        RemonteeLeadTestData.reglage()
      );
    Test.stopTest();

    Assert.isTrue(pistesDe(src).isEmpty(), 'pas de seconde piste');
    String statut = statuts.get(src.Id).get(5);
    Assert.isTrue(statut.startsWith('DOUBLON' + SEP + 'déjà reçu le '), statut);
    Assert.isTrue(statut.endsWith('hors fournisseurs'), statut);
    List<Rejet_Lead__c> rejets = rejetsDe(src);
    Assert.areEqual(1, rejets.size());
    Assert.areEqual(
      RemonteeLeadService.MOTIF_DOUBLON_AUTRE,
      rejets[0].Motif__c
    );
    Assert.areEqual(ancienne.Id, rejets[0].Piste_existante__c);
    Assert.areEqual('666 111 222', rejets[0].Telephone__c);
    Assert.areEqual('Ana', rejets[0].Nom__c);
    Assert.areEqual(5, rejets[0].Ligne__c);
    Assert.areEqual(src.Fournisseur__c, rejets[0].Fournisseur__c);
    Assert.isNotNull(rejets[0].Date_rejet__c);
  }

  @IsTest
  static void lePremierFournisseurGardeLeLead() {
    Test.setMock(HttpCalloutMock.class, new RemonteeLeadGoogleMock());
    Source_Lead__c premier = source('F001');
    Source_Lead__c second = source('F002');
    RemonteeLeadReglage reglage = RemonteeLeadTestData.reglage();
    // Sans la recherche sur le numéro brut : la clé de comparaison doit suffire.
    reglage.rechercheTelephoneExacte = false;
    RemonteeLeadService service = new RemonteeLeadService();
    service.traiter(
      new List<RemonteeLeadService.Travail>{
        RemonteeLeadTestData.travail(
          premier,
          2,
          RemonteeLeadTestData.ligne(
            'Ana',
            '34666111222',
            'ana@exemple.com',
            'Leon'
          )
        )
      },
      reglage
    );

    Test.startTest();
    Map<Id, Map<Integer, String>> statuts = new RemonteeLeadService()
      .traiter(
        new List<RemonteeLeadService.Travail>{
          RemonteeLeadTestData.travail(
            second,
            2,
            RemonteeLeadTestData.ligne(
              'Ana L.',
              '666111222',
              'autre@exemple.com',
              'Leon'
            )
          ),
          RemonteeLeadTestData.travail(
            premier,
            9,
            RemonteeLeadTestData.ligne('Ana', '0034 666111222', '', 'Leon')
          )
        },
        reglage
      );
    Test.stopTest();

    Assert.areEqual(
      1,
      pistesDe(premier).size(),
      'une seule piste, chez le premier'
    );
    Assert.isTrue(pistesDe(second).isEmpty());
    String chezLeSecond = statuts.get(second.Id).get(2);
    Assert.isTrue(chezLeSecond.startsWith('DOUBLON'), chezLeSecond);
    Assert.isTrue(
      chezLeSecond.endsWith('par F001'),
      'le code du premier fournisseur, jamais son nom : ' + chezLeSecond
    );
    Assert.isFalse(chezLeSecond.contains('Fournisseur F001'), chezLeSecond);
    Assert.areEqual(
      RemonteeLeadService.MOTIF_DOUBLON_AUTRE,
      rejetsDe(second)[0].Motif__c
    );
    Assert.areEqual(
      RemonteeLeadService.MOTIF_DOUBLON_MEME,
      rejetsDe(premier)[0].Motif__c,
      'renvoyé par le même fournisseur'
    );
  }

  @IsTest
  static void doublonDansLeMemePaquetEtParEmail() {
    Test.setMock(HttpCalloutMock.class, new RemonteeLeadGoogleMock());
    RemonteeLeadTestData.pisteExistante(
      'Connue par mail',
      null,
      'connue@exemple.com'
    );
    Source_Lead__c src = source('F001');

    Test.startTest();
    Map<Id, Map<Integer, String>> statuts = new RemonteeLeadService()
      .traiter(
        new List<RemonteeLeadService.Travail>{
          RemonteeLeadTestData.travail(
            src,
            2,
            RemonteeLeadTestData.ligne(
              'Luis',
              '677111222',
              'luis@exemple.com',
              'Leon'
            )
          ),
          RemonteeLeadTestData.travail(
            src,
            3,
            RemonteeLeadTestData.ligne(
              'Luis bis',
              '34677111222',
              'luis2@exemple.com',
              'Leon'
            )
          ),
          RemonteeLeadTestData.travail(
            src,
            4,
            RemonteeLeadTestData.ligne(
              'Sans numéro',
              '',
              'CONNUE@exemple.com',
              'Leon'
            )
          )
        },
        RemonteeLeadTestData.reglage()
      );
    Test.stopTest();

    Assert.areEqual(
      1,
      pistesDe(src).size(),
      'seule la première ligne crée une piste'
    );
    Assert.isTrue(statuts.get(src.Id).get(2).startsWith('OK'));
    Assert.isTrue(
      statuts.get(src.Id).get(3).startsWith('DOUBLON') &&
      statuts.get(src.Id).get(3).endsWith('par F001'),
      statuts.get(src.Id).get(3)
    );
    Assert.isTrue(
      statuts.get(src.Id).get(4).startsWith('DOUBLON'),
      'sans téléphone valable, la comparaison se fait sur l’e-mail : ' +
      statuts.get(src.Id).get(4)
    );
    List<Rejet_Lead__c> rejets = rejetsDe(src);
    Assert.areEqual(2, rejets.size());
    Assert.areEqual(RemonteeLeadService.MOTIF_DOUBLON_MEME, rejets[0].Motif__c);
    Assert.areEqual(
      RemonteeLeadService.MOTIF_DOUBLON_AUTRE,
      rejets[1].Motif__c
    );
  }

  // ------------------------------------------------------------ Faux numéros

  @IsTest
  static void fauxNumeroAvecEmailValableRemonteQuandMeme() {
    Test.setMock(HttpCalloutMock.class, new RemonteeLeadGoogleMock());
    Source_Lead__c src = source('F001');

    Test.startTest();
    Map<Id, Map<Integer, String>> statuts = new RemonteeLeadService()
      .traiter(
        new List<RemonteeLeadService.Travail>{
          RemonteeLeadTestData.travail(
            src,
            2,
            RemonteeLeadTestData.ligne(
              'Juan',
              '0',
              'juan@exemple.com',
              'Ourense'
            )
          )
        },
        RemonteeLeadTestData.reglage()
      );
    Test.stopTest();

    List<Lead> pistes = pistesDe(src);
    Assert.areEqual(
      1,
      pistes.size(),
      'joignable par e-mail : la piste est créée'
    );
    Assert.isTrue(pistes[0].Faux_Numero__c);
    Assert.isNull(pistes[0].Telephone_Cle__c);
    Assert.areEqual('0', pistes[0].Phone, 'numéro reçu gardé tel quel');
    Assert.areEqual(src.Id + '|2|juan@exemple.com', pistes[0].Ligne_Feuille__c);
    String statut = statuts.get(src.Id).get(2);
    Assert.isTrue(
      statut.startsWith('FAUX NUMÉRO' + SEP + 'e-mail seul' + SEP + 'créé le '),
      statut
    );
    Assert.isTrue(statut.endsWith(SEP + pistes[0].Id), statut);
    List<Rejet_Lead__c> rejets = rejetsDe(src);
    Assert.areEqual(
      1,
      rejets.size(),
      'faux numéro historisé pour le fournisseur'
    );
    Assert.areEqual(RemonteeLeadService.MOTIF_FAUX_NUMERO, rejets[0].Motif__c);
    Assert.areEqual(pistes[0].Id, rejets[0].Piste_existante__c);
    Assert.isTrue(
      rejets[0].Detail__c.startsWith('nombre de chiffres incorrect')
    );
  }

  @IsTest
  static void fauxNumeroSansEmailValableNEstPasRemonte() {
    Test.setMock(HttpCalloutMock.class, new RemonteeLeadGoogleMock());
    Source_Lead__c src = source('F001');

    Test.startTest();
    Map<Id, Map<Integer, String>> statuts = new RemonteeLeadService()
      .traiter(
        new List<RemonteeLeadService.Travail>{
          RemonteeLeadTestData.travail(
            src,
            2,
            RemonteeLeadTestData.ligne(
              'Inconnu',
              '666666666',
              'pas un mail',
              'Leon'
            )
          ),
          RemonteeLeadTestData.travail(
            src,
            3,
            RemonteeLeadTestData.ligne('Vide', '', '', 'Leon')
          )
        },
        RemonteeLeadTestData.reglage()
      );
    Test.stopTest();

    Assert.isTrue(pistesDe(src).isEmpty());
    Assert.areEqual(
      'FAUX NUMÉRO' +
        SEP +
        'numéro inventé' +
        SEP +
        'pas d’e-mail valable, non remonté',
      statuts.get(src.Id).get(2)
    );
    Assert.isTrue(
      statuts.get(src.Id).get(3).contains('numéro absent'),
      statuts.get(src.Id).get(3)
    );
    List<Rejet_Lead__c> rejets = rejetsDe(src);
    Assert.areEqual(2, rejets.size());
    Assert.areEqual(RemonteeLeadService.MOTIF_FAUX_NUMERO, rejets[0].Motif__c);
    Assert.isNull(rejets[0].Piste_existante__c);
    Assert.areEqual(
      'pas un mail',
      rejets[0].Email__c,
      'valeur reçue gardée pour contrôle'
    );
  }

  // ------------------------------------------------------------ Lignes déjà remontées, erreurs

  @IsTest
  static void ligneDejaRemonteeReconnueSansNouvellePiste() {
    Test.setMock(HttpCalloutMock.class, new RemonteeLeadGoogleMock());
    Source_Lead__c src = source('F001');
    RemonteeLeadReglage reglage = RemonteeLeadTestData.reglage();
    List<String> cellules = RemonteeLeadTestData.ligne(
      'Ana',
      '34666111222',
      'ana@exemple.com',
      'Leon'
    );
    String premierStatut = new RemonteeLeadService()
      .traiter(
        new List<RemonteeLeadService.Travail>{
          RemonteeLeadTestData.travail(src, 2, cellules)
        },
        reglage
      )
      .get(src.Id)
      .get(2);

    Test.startTest();
    // L'écriture du résultat dans la feuille a échoué : la même ligne revient, toujours vide.
    String secondStatut = new RemonteeLeadService()
      .traiter(
        new List<RemonteeLeadService.Travail>{
          RemonteeLeadTestData.travail(src, 2, cellules)
        },
        reglage
      )
      .get(src.Id)
      .get(2);
    Test.stopTest();

    List<Lead> pistes = pistesDe(src);
    Assert.areEqual(1, pistes.size(), 'jamais deux pistes pour la même ligne');
    Assert.isTrue(premierStatut.startsWith('OK'), premierStatut);
    Assert.isTrue(
      secondStatut.startsWith('OK'),
      'reconnue, pas déclarée doublon : ' + secondStatut
    );
    Assert.isTrue(secondStatut.endsWith(SEP + pistes[0].Id), secondStatut);
    Assert.isTrue(rejetsDe(src).isEmpty());
  }

  @IsTest
  static void pisteRefuseeNoteeEnErreurSansBloquerLesAutres() {
    Test.setMock(HttpCalloutMock.class, new RemonteeLeadGoogleMock());
    Source_Lead__c bonne = source('F001');
    Source_Lead__c supprimee = source('F002');
    RemonteeLeadReglage reglage = RemonteeLeadTestData.reglage();
    reglage.tentativesMax = 3;
    RemonteeLeadService.Travail refuse = RemonteeLeadTestData.travail(
      supprimee,
      2,
      RemonteeLeadTestData.ligne(
        'Refus',
        '34677111222',
        'refus@exemple.com',
        'Leon'
      )
    );
    RemonteeLeadService.Travail dernierEssai = RemonteeLeadTestData.travail(
      supprimee,
      3,
      RemonteeLeadTestData.ligne(
        'Refus bis',
        '34688111222',
        'bis@exemple.com',
        'Leon'
      )
    );
    dernierEssai.ligne.tentatives = 2;
    // Une piste rattachée à une Source supprimée est refusée par Salesforce.
    delete new Source_Lead__c(Id = supprimee.Id);

    Test.startTest();
    Map<Id, Map<Integer, String>> statuts = new RemonteeLeadService()
      .traiter(
        new List<RemonteeLeadService.Travail>{
          refuse,
          RemonteeLeadTestData.travail(
            bonne,
            2,
            RemonteeLeadTestData.ligne(
              'Ana',
              '34666111222',
              'ana@exemple.com',
              'Leon'
            )
          ),
          dernierEssai
        },
        reglage
      );
    Test.stopTest();

    Assert.areEqual(
      1,
      pistesDe(bonne).size(),
      'la bonne ligne passe quand même'
    );
    Assert.isTrue(statuts.get(bonne.Id).get(2).startsWith('OK'));
    String premiereErreur = statuts.get(supprimee.Id).get(2);
    Assert.isTrue(
      premiereErreur.startsWith('ERREUR' + SEP + 'tentative 1' + SEP),
      premiereErreur
    );
    Assert.isFalse(
      RemonteeLeadFeuille.estTerminee(premiereErreur),
      'sera retentée'
    );
    String derniereErreur = statuts.get(supprimee.Id).get(3);
    Assert.isTrue(
      derniereErreur.startsWith('ERREUR DÉFINITIVE' + SEP),
      derniereErreur
    );
    Assert.isTrue(
      RemonteeLeadFeuille.estTerminee(derniereErreur),
      'plus retentée'
    );
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM Lead WHERE LastName LIKE 'Refus%'],
      'aucune piste pour les lignes refusées'
    );
  }

  @IsTest
  static void paquetVide() {
    Assert.isTrue(
      new RemonteeLeadService()
        .traiter(
          new List<RemonteeLeadService.Travail>(),
          RemonteeLeadTestData.reglage()
        )
        .isEmpty()
    );
    Assert.isTrue(
      new RemonteeLeadService()
        .traiter(null, RemonteeLeadTestData.reglage())
        .isEmpty()
    );
  }

  // ------------------------------------------------------------ Configuration d'une Source

  @IsTest
  static void configurationCorrecteOuErreurLisible() {
    Source_Lead__c src = source('F001');
    RemonteeLeadService service = new RemonteeLeadService();
    Assert.isNull(
      service.erreurConfiguration(src),
      'configuration de référence'
    );

    Source_Lead__c sansOnglet = src.clone(true, true);
    sansOnglet.Onglet__c = null;
    Assert.isTrue(
      new RemonteeLeadService()
        .erreurConfiguration(sansOnglet)
        .contains('onglet manquant')
    );

    Source_Lead__c typeInconnu = src.clone(true, true);
    typeInconnu.Record_Type_Developer_Name__c = 'TYPE_QUI_N_EXISTE_PAS';
    Assert.isTrue(
      new RemonteeLeadService()
        .erreurConfiguration(typeInconnu)
        .contains('Type d’enregistrement de piste inconnu')
    );

    Map<String, String> casInvalides = new Map<String, String>{
      'pas du json' => 'illisible',
      '{}' => 'vide',
      '{"Nom":"Champ_Qui_N_Existe_Pas__c","Num":"Phone"}' => 'inconnu',
      '{"Nom":"LastName","Num":"Phone","X":"OwnerId"}' => 'non alimentable',
      '{"Nom":"LastName","Province":"City"}' => 'téléphone (Phone) ou l’e-mail'
    };
    for (String correspondance : casInvalides.keySet()) {
      Source_Lead__c invalide = src.clone(true, true);
      invalide.Mapping_JSON__c = correspondance;
      String erreur = new RemonteeLeadService().erreurConfiguration(invalide);
      Assert.isNotNull(erreur, correspondance);
      Assert.isTrue(
        erreur.contains(casInvalides.get(correspondance)),
        correspondance + ' → ' + erreur
      );
    }
  }
}
