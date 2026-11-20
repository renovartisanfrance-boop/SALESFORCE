/**
 * Tests de la transformation des lignes de feuille en pistes : création avec régie et prix,
 * doublons de la même feuille, doublons internes (règle des 14 jours et des dossiers annulés),
 * faux numéros, écarts de prix, erreurs, lignes déjà remontées, contrôle de la configuration.
 */
@IsTest
private class RemonteeLeadServiceTest {
  private static final String SEP = RemonteeLeadFeuille.SEPARATEUR;
  private static final String NEUTRE =
    'DOUBLON' +
    SEP +
    'contact déjà connu depuis le ';

  private static Source_Lead__c source(String code) {
    return RemonteeLeadTestData.source(
      RemonteeLeadTestData.fournisseur(code),
      'classeur-' + code
    );
  }

  private static RemonteeLeadService.Resultat traiter(
    List<RemonteeLeadService.Travail> travaux
  ) {
    return new RemonteeLeadService()
      .traiter(travaux, RemonteeLeadTestData.reglage());
  }

  private static RemonteeLeadService.Travail ligne(
    Source_Lead__c src,
    Integer numero,
    String nom,
    String telephone,
    String email
  ) {
    return RemonteeLeadTestData.travail(
      src,
      numero,
      RemonteeLeadTestData.ligne(nom, telephone, email, 'Leon')
    );
  }

  private static String aujourdHui() {
    return DateTime.now().format('dd/MM/yyyy', 'Europe/Paris');
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
        Faux_Numero__c,
        Campagne_REGIE__c,
        Regie__c,
        Tarif_Lead__c,
        Prix_Achat__c,
        Prix_Revente__c,
        Statut_Prix__c,
        Paye_fournisseur__c,
        Facture_regie__c,
        Prix_Feuille__c,
        Ecart_Prix__c
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
        Telephone_Cle__c,
        Email__c,
        Nom__c,
        Ligne__c,
        Piste_existante__c,
        Piste_creee__c,
        Dossier_existant__c,
        Regie__c,
        Connu_autre_regie__c,
        Paye_fournisseur__c,
        Facture_regie__c,
        Prix_Achat__c,
        Tarif_Lead__c,
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
  static void ligneNormaleCreeUnePisteAvecSaRegieEtSesPrix() {
    Test.setMock(HttpCalloutMock.class, new RemonteeLeadGoogleMock());
    Fournisseur_Lead__c fournisseur = RemonteeLeadTestData.fournisseur('F001');
    Campaign regie = RemonteeLeadTestData.regie('Régie de test');
    Account compte = RemonteeLeadTestData.compteDeLaRegie(regie);
    Tarif_Lead__c tarif = RemonteeLeadTestData.tarifFixe(
      fournisseur,
      regie,
      5,
      10
    );
    Source_Lead__c src = RemonteeLeadTestData.source(
      fournisseur,
      'classeur-F001',
      regie
    );
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
    RemonteeLeadService.Resultat resultat = traiter(
      new List<RemonteeLeadService.Travail>{ travail }
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
    Assert.areEqual(
      regie.Id,
      p.Campagne_REGIE__c,
      'la régie de la feuille va dans « Campagne (REGIE) »'
    );
    Assert.isNull(p.Regie__c, '« LOOKUP-REGIE » n’est plus rempli');
    Assert.areEqual(tarif.Id, p.Tarif_Lead__c);
    Assert.areEqual(5, p.Prix_Achat__c);
    Assert.areEqual(10, p.Prix_Revente__c);
    Assert.areEqual(LeadPrixService.STATUT_DEFINITIF, p.Statut_Prix__c);
    Assert.isTrue(p.Paye_fournisseur__c);
    Assert.isTrue(p.Facture_regie__c);
    Assert.isFalse(
      p.Ecart_Prix__c,
      'pas de prix dans la feuille : pas d’écart'
    );

    String statut = resultat.statuts.get(src.Id).get(2);
    Assert.isTrue(statut.startsWith('OK' + SEP), statut);
    Assert.isTrue(statut.endsWith(SEP + p.Id), statut);
    Assert.isTrue(rejetsDe(src).isEmpty(), 'rien à historiser');
    Assert.isTrue(resultat.alertes.containsKey(src.Id));
    Assert.isNull(
      resultat.alertes.get(src.Id),
      'régie, compte et tarif en place : rien à signaler'
    );
    Assert.areEqual(compte.Id, resultat.comptesRegie.get(src.Id));
  }

  @IsTest
  static void sansRegieNiTarifLeLeadRemonteAvecUneAlerte() {
    Test.setMock(HttpCalloutMock.class, new RemonteeLeadGoogleMock());
    Fournisseur_Lead__c fournisseur = RemonteeLeadTestData.fournisseur('F001');
    Campaign regie = RemonteeLeadTestData.regie('Régie sans compte');
    Source_Lead__c sansRegie = RemonteeLeadTestData.source(
      fournisseur,
      'classeur-sans-regie'
    );
    Source_Lead__c sansTarif = RemonteeLeadTestData.source(
      fournisseur,
      'classeur-sans-tarif',
      regie
    );
    // Origine laissée vide sur la Source : LEADS par défaut.
    sansRegie.Origine_piste__c = null;

    Test.startTest();
    RemonteeLeadService.Resultat resultat = traiter(
      new List<RemonteeLeadService.Travail>{
        ligne(sansRegie, 2, 'Ana', '34666111222', 'ana@exemple.com'),
        ligne(sansTarif, 2, 'Luis', '34677111222', 'luis@exemple.com')
      }
    );
    Test.stopTest();

    Lead a = pistesDe(sansRegie)[0];
    Assert.areEqual(RemonteeLeadService.ORIGINE_PAR_DEFAUT, a.LeadSource);
    Assert.isNull(a.Campagne_REGIE__c);
    Assert.areEqual(LeadPrixService.STATUT_SANS_TARIF, a.Statut_Prix__c);
    Assert.isNull(a.Prix_Achat__c);
    Assert.isTrue(
      resultat.alertes.get(sansRegie.Id).startsWith('Aucune régie'),
      resultat.alertes.get(sansRegie.Id)
    );

    Lead b = pistesDe(sansTarif)[0];
    Assert.areEqual(regie.Id, b.Campagne_REGIE__c);
    Assert.areEqual(LeadPrixService.STATUT_SANS_TARIF, b.Statut_Prix__c);
    Assert.isNull(b.Tarif_Lead__c);
    String alerte = resultat.alertes.get(sansTarif.Id);
    Assert.isTrue(alerte.contains('Aucun compte ne pointe'), alerte);
    Assert.isTrue(alerte.contains('Aucun tarif actif'), alerte);
    Assert.isNull(resultat.comptesRegie.get(sansTarif.Id));
  }

  @IsTest
  static void villeTropLongueCoupeeAuLieuDEtreRefusee() {
    Test.setMock(HttpCalloutMock.class, new RemonteeLeadGoogleMock());
    Source_Lead__c src = source('F001');
    String adresse = 'santa cruz de retorta castro 1 guntin de pallares lugo';

    Test.startTest();
    RemonteeLeadService.Resultat resultat = traiter(
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
      }
    );
    Test.stopTest();

    List<Lead> pistes = pistesDe(src);
    Assert.areEqual(
      1,
      pistes.size(),
      'la piste est créée malgré la ville trop longue'
    );
    Assert.areEqual(adresse.left(40), pistes[0].City);
    Assert.isTrue(resultat.statuts.get(src.Id).get(2).startsWith('OK'));
  }

  // ------------------------------------------------------------ Doublons de la même feuille

  @IsTest
  static void memePersonneDeuxFoisDansLaMemeFeuille() {
    Test.setMock(HttpCalloutMock.class, new RemonteeLeadGoogleMock());
    Fournisseur_Lead__c fournisseur = RemonteeLeadTestData.fournisseur('F001');
    Campaign regie = RemonteeLeadTestData.regie('Régie de test');
    RemonteeLeadTestData.tarifFixe(fournisseur, regie, 5, 10);
    Source_Lead__c src = RemonteeLeadTestData.source(
      fournisseur,
      'classeur-F001',
      regie
    );
    // Un premier passage a créé la ligne 2.
    traiter(
      new List<RemonteeLeadService.Travail>{
        ligne(src, 2, 'Ana', '34666111222', 'ana@exemple.com')
      }
    );
    Lead premiere = pistesDe(src)[0];

    Test.startTest();
    RemonteeLeadService.Resultat resultat = traiter(
      new List<RemonteeLeadService.Travail>{
        ligne(src, 9, 'Ana encore', '0034 666111222', ''),
        ligne(src, 10, 'Luis', '677111222', 'luis@exemple.com'),
        ligne(src, 11, 'Luis bis', '34677111222', 'luis2@exemple.com')
      }
    );
    Test.stopTest();

    Assert.areEqual(
      2,
      pistesDe(src).size(),
      'Ana (ligne 2) et Luis (ligne 10)'
    );
    Assert.areEqual(
      'DOUBLON' + SEP + 'déjà envoyé le ' + aujourdHui() + ' (ligne 2)',
      resultat.statuts.get(src.Id).get(9),
      'déjà créée depuis cette feuille'
    );
    Assert.isTrue(resultat.statuts.get(src.Id).get(10).startsWith('OK'));
    Assert.areEqual(
      'DOUBLON' + SEP + 'déjà envoyé le ' + aujourdHui() + ' (ligne 10)',
      resultat.statuts.get(src.Id).get(11),
      'ligne plus haut dans le même paquet'
    );
    List<Rejet_Lead__c> rejets = rejetsDe(src);
    Assert.areEqual(2, rejets.size());
    for (Rejet_Lead__c rejet : rejets) {
      Assert.areEqual(
        RemonteeLeadService.MOTIF_DOUBLON_FEUILLE,
        rejet.Motif__c
      );
      Assert.isFalse(
        rejet.Paye_fournisseur__c,
        'envoyé deux fois par le même fournisseur : pas payé deux fois'
      );
      Assert.isFalse(rejet.Facture_regie__c);
      Assert.isNull(rejet.Prix_Achat__c);
      Assert.areEqual(regie.Id, rejet.Regie__c);
    }
    Assert.areEqual(premiere.Id, rejets[0].Piste_existante__c);
    Assert.areEqual('666111222', rejets[0].Telephone_Cle__c);
    Assert.areEqual('Ana encore', rejets[0].Nom__c);
    Assert.areEqual(src.Fournisseur__c, rejets[0].Fournisseur__c);
    Assert.isNotNull(rejets[0].Date_rejet__c);
  }

  // ------------------------------------------------------------ Doublons internes

  @IsTest
  static void contactActifAilleursBloqueSansRienReveler() {
    Test.setMock(HttpCalloutMock.class, new RemonteeLeadGoogleMock());
    Campaign autreRegie = RemonteeLeadTestData.regie('Régie Concurrente');
    Lead ancienne = RemonteeLeadTestData.pisteExistante(
      'Ancienne',
      '34666111222',
      null
    );
    update new Lead(Id = ancienne.Id, Campagne_REGIE__c = autreRegie.Id);
    Fournisseur_Lead__c fournisseur = RemonteeLeadTestData.fournisseur('F001');
    Campaign regie = RemonteeLeadTestData.regie('Régie de test');
    Tarif_Lead__c tarif = RemonteeLeadTestData.tarifFixe(
      fournisseur,
      regie,
      5,
      10
    );
    Source_Lead__c src = RemonteeLeadTestData.source(
      fournisseur,
      'classeur-F001',
      regie
    );

    Test.startTest();
    RemonteeLeadService.Resultat resultat = traiter(
      new List<RemonteeLeadService.Travail>{
        ligne(src, 5, 'Ana', '666 111 222', 'ana@exemple.com')
      }
    );
    Test.stopTest();

    Assert.isTrue(pistesDe(src).isEmpty(), 'pas de seconde piste');
    String statut = resultat.statuts.get(src.Id).get(5);
    Assert.areEqual(NEUTRE + aujourdHui() + ', non remonté', statut);
    Assert.isFalse(statut.contains('Concurrente'), 'jamais le nom de la régie');
    Assert.isFalse(statut.contains('F0'), 'jamais de code fournisseur');
    List<Rejet_Lead__c> rejets = rejetsDe(src);
    Assert.areEqual(1, rejets.size());
    Rejet_Lead__c rejet = rejets[0];
    Assert.areEqual(RemonteeLeadService.MOTIF_DOUBLON_INTERNE, rejet.Motif__c);
    Assert.areEqual(ancienne.Id, rejet.Piste_existante__c);
    Assert.isTrue(
      rejet.Connu_autre_regie__c,
      'le détail reste dans Salesforce'
    );
    Assert.isTrue(
      rejet.Paye_fournisseur__c,
      'un doublon interne est payé au fournisseur'
    );
    Assert.areEqual(5, rejet.Prix_Achat__c);
    Assert.areEqual(tarif.Id, rejet.Tarif_Lead__c);
    Assert.isFalse(rejet.Facture_regie__c, 'jamais facturé à la régie');
    Assert.areEqual('666 111 222', rejet.Telephone__c);
    Assert.areEqual(5, rejet.Ligne__c);
  }

  @IsTest
  static void contactSansActiviteDepuisDeuxSemainesNeBloquePlus() {
    Test.setMock(HttpCalloutMock.class, new RemonteeLeadGoogleMock());
    Lead ancienne = RemonteeLeadTestData.pisteExistante(
      'Ancienne',
      '34666111222',
      null
    );
    Source_Lead__c src = source('F001');
    // Vingt jours plus tard, la piste déjà présente n'a eu aucune activité.
    RemonteeLeadService.maintenantForce = DateTime.now().addDays(20);

    Test.startTest();
    RemonteeLeadService.Resultat resultat = traiter(
      new List<RemonteeLeadService.Travail>{
        ligne(src, 2, 'Ana', '666111222', 'ana@exemple.com')
      }
    );
    Test.stopTest();

    Assert.areEqual(1, pistesDe(src).size(), 'le lead entre normalement');
    Assert.isTrue(
      resultat.statuts.get(src.Id).get(2).startsWith('OK'),
      resultat.statuts.get(src.Id).get(2)
    );
    Assert.isTrue(rejetsDe(src).isEmpty());
    Assert.areEqual(
      2,
      [
        SELECT COUNT()
        FROM Lead
        WHERE Id = :ancienne.Id OR Source_Lead__c = :src.Id
      ]
    );
  }

  @IsTest
  static void derniereActiviteLaPlusRecenteDesTrois() {
    Lead creee = (Lead) JSON.deserialize(
      '{"attributes":{"type":"Lead"},"CreatedDate":"2026-01-10T10:00:00.000+0000"}',
      Lead.class
    );
    Lead modifiee = (Lead) JSON.deserialize(
      '{"attributes":{"type":"Lead"},"CreatedDate":"2026-01-10T10:00:00.000+0000",' +
      '"LastModifiedDate":"2026-02-03T08:00:00.000+0000"}',
      Lead.class
    );
    Lead appelee = (Lead) JSON.deserialize(
      '{"attributes":{"type":"Lead"},"CreatedDate":"2026-01-10T10:00:00.000+0000",' +
      '"LastModifiedDate":"2026-02-03T08:00:00.000+0000","LastActivityDate":"2026-03-15"}',
      Lead.class
    );

    Assert.areEqual(
      DateTime.newInstanceGmt(2026, 1, 10, 10, 0, 0),
      RemonteeLeadService.derniereActivite(creee)
    );
    Assert.areEqual(
      DateTime.newInstanceGmt(2026, 2, 3, 8, 0, 0),
      RemonteeLeadService.derniereActivite(modifiee)
    );
    Assert.areEqual(
      Date.newInstance(2026, 3, 15),
      RemonteeLeadService.derniereActivite(appelee).date(),
      'un appel ou une tâche compte comme une activité'
    );
  }

  @IsTest
  static void dossierVivantBloqueDossierAnnuleNon() {
    Test.setMock(HttpCalloutMock.class, new RemonteeLeadGoogleMock());
    Pro__c vivant = RemonteeLeadTestData.dossierExistant(
      'Dossier vivant',
      '34666111222',
      RemonteeLeadTestData.statutDossierVivant()
    );
    RemonteeLeadTestData.dossierExistant(
      'Dossier annulé',
      '34677111222',
      RemonteeLeadTestData.statutDossierAnnule()
    );
    Source_Lead__c src = source('F001');

    Test.startTest();
    RemonteeLeadService.Resultat resultat = traiter(
      new List<RemonteeLeadService.Travail>{
        ligne(src, 2, 'Ana', '666111222', 'ana@exemple.com'),
        ligne(src, 3, 'Luis', '677111222', 'luis@exemple.com')
      }
    );
    Test.stopTest();

    Assert.isNotNull(
      RemonteeLeadTestData.statutDossierAnnule(),
      'le statut « annulé » existe dans l’org'
    );
    String bloque = resultat.statuts.get(src.Id).get(2);
    Assert.isTrue(bloque.startsWith(NEUTRE), bloque);
    Assert.isTrue(
      resultat.statuts.get(src.Id).get(3).startsWith('OK'),
      'un dossier annulé ne bloque pas : ' + resultat.statuts.get(src.Id).get(3)
    );
    List<Lead> pistes = pistesDe(src);
    Assert.areEqual(1, pistes.size());
    Assert.areEqual('Luis', pistes[0].LastName);
    List<Rejet_Lead__c> rejets = rejetsDe(src);
    Assert.areEqual(1, rejets.size());
    Assert.areEqual(
      RemonteeLeadService.MOTIF_DOUBLON_INTERNE,
      rejets[0].Motif__c
    );
    Assert.areEqual(vivant.Id, rejets[0].Dossier_existant__c);
    Assert.isNull(rejets[0].Piste_existante__c);
    Assert.isTrue(rejets[0].Paye_fournisseur__c);
  }

  @IsTest
  static void deuxFeuillesEnvoientLaMemePersonne() {
    Test.setMock(HttpCalloutMock.class, new RemonteeLeadGoogleMock());
    Campaign regieA = RemonteeLeadTestData.regie('Régie A');
    Campaign regieB = RemonteeLeadTestData.regie('Régie B');
    Source_Lead__c premiere = RemonteeLeadTestData.source(
      RemonteeLeadTestData.fournisseur('F001'),
      'classeur-F001',
      regieA
    );
    Source_Lead__c seconde = RemonteeLeadTestData.source(
      RemonteeLeadTestData.fournisseur('F002'),
      'classeur-F002',
      regieB
    );
    RemonteeLeadReglage reglage = RemonteeLeadTestData.reglage();
    // Sans la recherche sur le numéro brut : la clé de comparaison doit suffire.
    reglage.rechercheTelephoneExacte = false;

    Test.startTest();
    // Même paquet : la première ligne garde la personne.
    RemonteeLeadService.Resultat memePaquet = new RemonteeLeadService()
      .traiter(
        new List<RemonteeLeadService.Travail>{
          ligne(premiere, 2, 'Ana', '34666111222', 'ana@exemple.com'),
          ligne(seconde, 2, 'Ana L.', '666111222', 'autre@exemple.com')
        },
        reglage
      );
    // Passage suivant : la seconde feuille renvoie la personne, puis une autre déjà prise.
    RemonteeLeadService.Resultat suivant = new RemonteeLeadService()
      .traiter(
        new List<RemonteeLeadService.Travail>{
          ligne(seconde, 7, 'Ana encore', '0034666111222', '')
        },
        reglage
      );
    Test.stopTest();

    Assert.areEqual(1, pistesDe(premiere).size(), 'une seule piste');
    Assert.isTrue(pistesDe(seconde).isEmpty());
    String chezLaSeconde = memePaquet.statuts.get(seconde.Id).get(2);
    Assert.areEqual(NEUTRE + aujourdHui() + ', non remonté', chezLaSeconde);
    Assert.isFalse(chezLaSeconde.contains('F001'), chezLaSeconde);
    Assert.areEqual(
      'DOUBLON' + SEP + 'déjà envoyé le ' + aujourdHui() + ' (ligne 2)',
      suivant.statuts.get(seconde.Id).get(7),
      'déjà rejetée dans cette feuille : c’est un doublon de la même feuille'
    );
    List<Rejet_Lead__c> rejets = rejetsDe(seconde);
    Assert.areEqual(2, rejets.size());
    Assert.areEqual(
      RemonteeLeadService.MOTIF_DOUBLON_INTERNE,
      rejets[0].Motif__c
    );
    Assert.isTrue(rejets[0].Paye_fournisseur__c, 'payé une fois');
    Assert.isTrue(rejets[0].Connu_autre_regie__c);
    Assert.areEqual(
      RemonteeLeadService.MOTIF_DOUBLON_FEUILLE,
      rejets[1].Motif__c
    );
    Assert.isFalse(rejets[1].Paye_fournisseur__c, 'pas payé une seconde fois');
  }

  // ------------------------------------------------------------ Faux numéros

  @IsTest
  static void fauxNumeroAvecEmailRemonteMaisNEstPasFacture() {
    Test.setMock(HttpCalloutMock.class, new RemonteeLeadGoogleMock());
    Campaign regie = RemonteeLeadTestData.regie('Régie de test');
    Fournisseur_Lead__c nonPaye = RemonteeLeadTestData.fournisseur('F001');
    Fournisseur_Lead__c paye = RemonteeLeadTestData.fournisseur('F002');
    RemonteeLeadTestData.tarifFixe(nonPaye, regie, 5, 10);
    Tarif_Lead__c tarifPaye = RemonteeLeadTestData.tarifFixe(
      paye,
      regie,
      6,
      12
    );
    update new Tarif_Lead__c(Id = tarifPaye.Id, Faux_numeros_payes__c = true);
    Source_Lead__c src = RemonteeLeadTestData.source(
      nonPaye,
      'classeur-F001',
      regie
    );
    Source_Lead__c srcPaye = RemonteeLeadTestData.source(
      paye,
      'classeur-F002',
      regie
    );

    Test.startTest();
    RemonteeLeadService.Resultat resultat = traiter(
      new List<RemonteeLeadService.Travail>{
        RemonteeLeadTestData.travail(
          src,
          2,
          RemonteeLeadTestData.ligne('Juan', '0', 'juan@exemple.com', 'Ourense')
        ),
        RemonteeLeadTestData.travail(
          srcPaye,
          2,
          RemonteeLeadTestData.ligne('Rosa', '0', 'rosa@exemple.com', 'Lugo')
        )
      }
    );
    Test.stopTest();

    List<Lead> pistes = pistesDe(src);
    Assert.areEqual(
      1,
      pistes.size(),
      'joignable par e-mail : la piste est créée'
    );
    Lead p = pistes[0];
    Assert.isTrue(p.Faux_Numero__c);
    Assert.isNull(p.Telephone_Cle__c);
    Assert.areEqual('0', p.Phone, 'numéro reçu gardé tel quel');
    Assert.areEqual(src.Id + '|2|juan@exemple.com', p.Ligne_Feuille__c);
    Assert.isFalse(p.Facture_regie__c, 'jamais facturé à la régie');
    Assert.isNull(p.Prix_Revente__c);
    Assert.isFalse(
      p.Paye_fournisseur__c,
      'ce tarif ne paie pas les faux numéros'
    );
    Assert.isNull(p.Prix_Achat__c);
    String statut = resultat.statuts.get(src.Id).get(2);
    Assert.isTrue(
      statut.startsWith('FAUX NUMÉRO' + SEP + 'e-mail seul' + SEP + 'créé le '),
      statut
    );
    Assert.isTrue(statut.endsWith(SEP + p.Id), statut);
    List<Rejet_Lead__c> rejets = rejetsDe(src);
    Assert.areEqual(
      1,
      rejets.size(),
      'faux numéro historisé pour le fournisseur'
    );
    Assert.areEqual(RemonteeLeadService.MOTIF_FAUX_NUMERO, rejets[0].Motif__c);
    Assert.areEqual(p.Id, rejets[0].Piste_creee__c);
    Assert.isNull(rejets[0].Piste_existante__c);
    Assert.isFalse(rejets[0].Paye_fournisseur__c);
    Assert.isTrue(
      rejets[0].Detail__c.startsWith('nombre de chiffres incorrect')
    );

    Lead q = pistesDe(srcPaye)[0];
    Assert.isTrue(
      q.Paye_fournisseur__c,
      'ce fournisseur est payé même pour un faux numéro'
    );
    Assert.areEqual(6, q.Prix_Achat__c);
    Assert.isFalse(q.Facture_regie__c, 'mais la régie ne le paie jamais');
    Assert.isNull(q.Prix_Revente__c);
  }

  @IsTest
  static void fauxNumeroSansEmailValableNEstPasRemonte() {
    Test.setMock(HttpCalloutMock.class, new RemonteeLeadGoogleMock());
    Source_Lead__c src = source('F001');

    Test.startTest();
    RemonteeLeadService.Resultat resultat = traiter(
      new List<RemonteeLeadService.Travail>{
        ligne(src, 2, 'Inconnu', '666666666', 'pas un mail'),
        ligne(src, 3, 'Vide', '', '')
      }
    );
    Test.stopTest();

    Assert.isTrue(pistesDe(src).isEmpty());
    Assert.areEqual(
      'FAUX NUMÉRO' +
        SEP +
        'numéro inventé' +
        SEP +
        'pas d’e-mail valable, non remonté',
      resultat.statuts.get(src.Id).get(2)
    );
    Assert.isTrue(
      resultat.statuts.get(src.Id).get(3).contains('numéro absent'),
      resultat.statuts.get(src.Id).get(3)
    );
    List<Rejet_Lead__c> rejets = rejetsDe(src);
    Assert.areEqual(2, rejets.size());
    Assert.areEqual(RemonteeLeadService.MOTIF_FAUX_NUMERO, rejets[0].Motif__c);
    Assert.isNull(rejets[0].Piste_existante__c);
    Assert.isNull(rejets[0].Piste_creee__c);
    Assert.isFalse(rejets[0].Paye_fournisseur__c, 'sans tarif : rien n’est dû');
    Assert.isFalse(rejets[0].Facture_regie__c);
    Assert.areEqual(
      'pas un mail',
      rejets[0].Email__c,
      'valeur reçue gardée pour contrôle'
    );
  }

  // ------------------------------------------------------------ Prix de la feuille

  @IsTest
  static void prixDeLaFeuilleDifferentDuTarifSignaleSansBloquer() {
    Test.setMock(HttpCalloutMock.class, new RemonteeLeadGoogleMock());
    Fournisseur_Lead__c fournisseur = RemonteeLeadTestData.fournisseur('F001');
    Campaign regie = RemonteeLeadTestData.regie('Régie de test');
    RemonteeLeadTestData.tarifFixe(fournisseur, regie, 5, 10);
    Source_Lead__c src = RemonteeLeadTestData.source(
      fournisseur,
      'classeur-F001',
      regie
    );

    Test.startTest();
    RemonteeLeadService.Resultat resultat = traiter(
      new List<RemonteeLeadService.Travail>{
        RemonteeLeadTestData.travail(
          src,
          2,
          RemonteeLeadTestData.ligneAvecPrix(
            'Ana',
            '34666111222',
            'ana@exemple.com',
            '7,50 €'
          )
        ),
        RemonteeLeadTestData.travail(
          src,
          3,
          RemonteeLeadTestData.ligneAvecPrix(
            'Luis',
            '34677111222',
            'luis@exemple.com',
            '5'
          )
        )
      }
    );
    Test.stopTest();

    List<Lead> pistes = pistesDe(src);
    Assert.areEqual(2, pistes.size(), 'l’écart de prix ne bloque pas le lead');
    Lead ecart = pistes[0];
    Assert.areEqual(7.5, ecart.Prix_Feuille__c);
    Assert.areEqual(5, ecart.Prix_Achat__c, 'le prix du tarif fait foi');
    Assert.isTrue(ecart.Ecart_Prix__c);
    String statut = resultat.statuts.get(src.Id).get(2);
    Assert.isTrue(statut.startsWith('OK' + SEP), statut);
    Assert.isTrue(
      statut.endsWith(SEP + 'ÉCART DE PRIX (feuille 7,5 € / tarif 5 €)'),
      statut
    );
    Assert.isTrue(RemonteeLeadFeuille.estTerminee(statut), 'ligne terminée');
    Assert.isFalse(pistes[1].Ecart_Prix__c, 'même prix : rien à signaler');
    Assert.areEqual(5, pistes[1].Prix_Feuille__c);
    Assert.isTrue(
      resultat.statuts.get(src.Id).get(3).endsWith(SEP + pistes[1].Id)
    );
  }

  @IsTest
  static void montantLuDansUneCellule() {
    Assert.areEqual(12, RemonteeLeadService.montant('12'));
    Assert.areEqual(12.5, RemonteeLeadService.montant(' 12,50 € '));
    Assert.areEqual(1200.5, RemonteeLeadService.montant('1 200.5'));
    Assert.isNull(RemonteeLeadService.montant(''));
    Assert.isNull(RemonteeLeadService.montant(null));
    Assert.isNull(RemonteeLeadService.montant('gratuit'));
    Assert.isNull(RemonteeLeadService.montant('1.2.3'), 'illisible : ignoré');
  }

  // ------------------------------------------------------------ Lignes déjà remontées, erreurs

  @IsTest
  static void ligneDejaRemonteeReconnueSansNouvellePiste() {
    Test.setMock(HttpCalloutMock.class, new RemonteeLeadGoogleMock());
    Source_Lead__c src = source('F001');
    List<String> cellules = RemonteeLeadTestData.ligne(
      'Ana',
      '34666111222',
      'ana@exemple.com',
      'Leon'
    );
    String premierStatut = traiter(
        new List<RemonteeLeadService.Travail>{
          RemonteeLeadTestData.travail(src, 2, cellules)
        }
      )
      .statuts.get(src.Id)
      .get(2);

    Test.startTest();
    // L'écriture du résultat dans la feuille a échoué : la même ligne revient, toujours vide.
    String secondStatut = traiter(
        new List<RemonteeLeadService.Travail>{
          RemonteeLeadTestData.travail(src, 2, cellules)
        }
      )
      .statuts.get(src.Id)
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
    RemonteeLeadService.Travail refuse = ligne(
      supprimee,
      2,
      'Refus',
      '34677111222',
      'refus@exemple.com'
    );
    RemonteeLeadService.Travail dernierEssai = ligne(
      supprimee,
      3,
      'Refus bis',
      '34688111222',
      'bis@exemple.com'
    );
    dernierEssai.ligne.tentatives = 2;
    // Une piste rattachée à une Source supprimée est refusée par Salesforce.
    delete new Source_Lead__c(Id = supprimee.Id);

    Test.startTest();
    RemonteeLeadService.Resultat resultat = new RemonteeLeadService()
      .traiter(
        new List<RemonteeLeadService.Travail>{
          refuse,
          ligne(bonne, 2, 'Ana', '34666111222', 'ana@exemple.com'),
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
    Assert.isTrue(resultat.statuts.get(bonne.Id).get(2).startsWith('OK'));
    String premiereErreur = resultat.statuts.get(supprimee.Id).get(2);
    Assert.isTrue(
      premiereErreur.startsWith('ERREUR' + SEP + 'tentative 1' + SEP),
      premiereErreur
    );
    Assert.isFalse(
      RemonteeLeadFeuille.estTerminee(premiereErreur),
      'sera retentée'
    );
    String derniereErreur = resultat.statuts.get(supprimee.Id).get(3);
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
    Assert.isTrue(traiter(new List<RemonteeLeadService.Travail>()).isEmpty());
    RemonteeLeadService.Resultat rien = traiter(null);
    Assert.isTrue(rien.isEmpty());
    Assert.isTrue(rien.alertes.isEmpty());
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

    // Une campagne qui n'est pas « Est REGIE » (celle d'un prévisiteur, par exemple).
    Campaign pasUneRegie = RemonteeLeadTestData.regie('Campagne ordinaire');
    Source_Lead__c mauvaiseRegie = src.clone(true, true);
    mauvaiseRegie.Regie__c = pasUneRegie.Id;
    mauvaiseRegie.Regie__r = new Campaign(
      Id = pasUneRegie.Id,
      EstREGIE__c = false
    );
    Assert.isTrue(
      new RemonteeLeadService()
        .erreurConfiguration(mauvaiseRegie)
        .contains('Est REGIE')
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
