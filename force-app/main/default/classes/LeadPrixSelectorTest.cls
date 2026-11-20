/**
 * Tests des requêtes des prix des leads : tarifs, sources d'un couple, clôtures, et comptages des
 * pistes et des lignes rejetées d'un mois.
 */
@IsTest
private class LeadPrixSelectorTest {
  private static final LeadPrixSelector SELECTOR = new LeadPrixSelector();

  private static Decimal nombre(List<AggregateResult> lignes, String colonne) {
    Decimal total = 0;
    for (AggregateResult ligne : lignes) {
      Object valeur = ligne.get(colonne);
      total += valeur == null ? 0 : Decimal.valueOf(String.valueOf(valeur));
    }
    return total;
  }

  @IsTest
  static void tarifsDUnCoupleSelonLaDate() {
    Fournisseur_Lead__c f = RemonteeLeadTestData.fournisseur('F001');
    Campaign regie = RemonteeLeadTestData.regie('Régie de test');
    Tarif_Lead__c tarif = RemonteeLeadTestData.tarifFixe(f, regie, 5, 10);
    Set<Id> fournisseurs = new Set<Id>{ f.Id };
    Set<Id> regies = new Set<Id>{ regie.Id };

    Test.startTest();
    List<Tarif_Lead__c> duJour = SELECTOR.tarifsApplicables(
      fournisseurs,
      regies,
      Date.today()
    );
    List<Tarif_Lead__c> avantLeDebut = SELECTOR.tarifsApplicables(
      fournisseurs,
      regies,
      Date.today().addYears(-2)
    );
    List<Tarif_Lead__c> actifs = SELECTOR.tarifsActifs(
      fournisseurs,
      regies,
      new Set<Id>()
    );
    List<Tarif_Lead__c> saufLuiMeme = SELECTOR.tarifsActifs(
      fournisseurs,
      regies,
      new Set<Id>{ tarif.Id }
    );
    Test.stopTest();

    Assert.areEqual(1, duJour.size());
    Assert.areEqual(tarif.Id, duJour[0].Id);
    Assert.areEqual(5, duJour[0].Prix_Achat__c);
    Assert.areEqual(LeadPrixService.REVENTE_FIXE, duJour[0].Regle_revente__c);
    Assert.isTrue(
      avantLeDebut.isEmpty(),
      'le tarif ne s’appliquait pas encore'
    );
    Assert.areEqual(1, actifs.size());
    Assert.isTrue(saufLuiMeme.isEmpty());
    Assert.isTrue(
      SELECTOR.tarifsApplicables(new Set<Id>(), regies, Date.today()).isEmpty()
    );
    Assert.isTrue(
      SELECTOR.tarifsActifs(fournisseurs, new Set<Id>(), new Set<Id>())
        .isEmpty()
    );
  }

  @IsTest
  static void sourcesClosturesEtComptagesDUnMois() {
    Test.setMock(HttpCalloutMock.class, new RemonteeLeadGoogleMock());
    RemonteeLeadTestData.Mois mois = RemonteeLeadTestData.moisDeLeads(true);
    Source_Lead__c sansRegie = RemonteeLeadTestData.source(
      mois.fournisseur,
      'classeur-sans-regie'
    );
    Id idCloture = new LeadClotureService().ouvrirMois(Date.today())[0].Id;
    LeadClotureService.Periode periode = new LeadClotureService.Periode(
      Date.today()
    );
    Set<Id> sources = new Set<Id>{ mois.source.Id };
    String cle = LeadClotureService.cle(
      mois.fournisseur.Id,
      mois.regie.Id,
      Date.today().toStartOfMonth()
    );

    Test.startTest();
    Map<Id, Source_Lead__c> parId = SELECTOR.sourcesParId(
      new Set<Id>{ mois.source.Id, sansRegie.Id }
    );
    List<Source_Lead__c> avecRegie = SELECTOR.sourcesAvecRegie();
    List<Source_Lead__c> duCouple = SELECTOR.sourcesDesCouples(
      new Set<Id>{ mois.fournisseur.Id },
      new Set<Id>{ mois.regie.Id }
    );
    List<Cloture_Lead__c> clotures = SELECTOR.cloturesParId(
      new Set<Id>{ idCloture }
    );
    List<Cloture_Lead__c> parCle = SELECTOR.cloturesParCle(
      new Set<String>{ cle, 'clé inconnue' }
    );
    Map<Id, Decimal> montants = SELECTOR.montantsReventeParRegie(
      new Set<Id>{ mois.regie.Id }
    );
    List<AggregateResult> payees = SELECTOR.pistesPayees(
      sources,
      periode.debut,
      periode.fin
    );
    List<AggregateResult> aRepartir = SELECTOR.pistesARepartir(
      sources,
      periode.debut,
      periode.fin,
      LeadPrixService.STATUT_PROVISOIRE
    );
    List<AggregateResult> facturees = SELECTOR.pistesFacturees(
      sources,
      periode.debut,
      periode.fin
    );
    List<AggregateResult> rejetsPayes = SELECTOR.rejetsPayes(
      sources,
      periode.debut,
      periode.fin
    );
    List<Rejet_Lead__c> rejetsARepartir = SELECTOR.rejetsARepartir(
      sources,
      periode.debut,
      periode.fin,
      LeadPrixService.STATUT_PROVISOIRE
    );
    Integer aCorriger = 0;
    Database.QueryLocatorIterator curseur = SELECTOR.pistesARepartirUneParUne(
        sources,
        periode.debut,
        periode.fin,
        LeadPrixService.STATUT_PROVISOIRE
      )
      .iterator();
    while (curseur.hasNext()) {
      Lead piste = (Lead) curseur.next();
      Assert.areEqual(
        LeadPrixService.REVENTE_MARGE_POURCENT,
        piste.Tarif_Lead__r.Regle_revente__c,
        'la règle de revente est lue avec la piste'
      );
      aCorriger++;
    }
    List<AggregateResult> moisPrecedent = SELECTOR.pistesPayees(
      sources,
      periode.debut.addMonths(-1),
      periode.debut
    );
    Test.stopTest();

    Assert.areEqual(2, parId.size());
    Assert.areEqual(mois.regie.Id, parId.get(mois.source.Id).Regie__c);
    Assert.areEqual(
      mois.fournisseur.Id,
      parId.get(mois.source.Id).Fournisseur__c
    );
    Assert.areEqual(
      1,
      avecRegie.size(),
      'la Source sans régie n’a pas de relevé'
    );
    Assert.areEqual(mois.source.Id, avecRegie[0].Id);
    Assert.areEqual(1, duCouple.size());
    Assert.areEqual(mois.compte.Id, duCouple[0].Compte_Regie__c);
    Assert.areEqual(1, clotures.size());
    Assert.areEqual(cle, clotures[0].Cle__c);
    Assert.areEqual(1, parCle.size());
    Assert.areEqual(LeadClotureService.STATUT_OUVERTE, parCle[0].Statut__c);
    Assert.areEqual(12, montants.get(mois.regie.Id), '2 × 6 € provisoires');
    Assert.areEqual(2, nombre(payees, 'nombre'), 'Ana et Luis');
    Assert.areEqual(8, nombre(payees, 'montant'), '2 × 4 € provisoires');
    Assert.areEqual(mois.source.Id, (Id) payees[0].get('feuille'));
    Assert.areEqual(2, nombre(aRepartir, 'nombre'));
    Assert.areEqual(2, nombre(facturees, 'nombre'), 'pas le faux numéro');
    Assert.areEqual(12, nombre(facturees, 'montant'));
    Assert.areEqual(1, nombre(rejetsPayes, 'nombre'), 'le doublon interne');
    Assert.areEqual(4, nombre(rejetsPayes, 'montant'));
    Assert.areEqual(1, rejetsARepartir.size());
    Assert.areEqual(2, aCorriger);
    Assert.isTrue(moisPrecedent.isEmpty(), 'rien le mois d’avant');
    Assert.isTrue(SELECTOR.sourcesParId(new Set<Id>()).isEmpty());
    Assert.isTrue(SELECTOR.cloturesParId(new Set<Id>()).isEmpty());
    Assert.isTrue(SELECTOR.cloturesParCle(new Set<String>()).isEmpty());
    Assert.isTrue(SELECTOR.montantsReventeParRegie(new Set<Id>()).isEmpty());
    Assert.isTrue(
      SELECTOR.sourcesDesCouples(new Set<Id>(), new Set<Id>()).isEmpty()
    );
  }
}
