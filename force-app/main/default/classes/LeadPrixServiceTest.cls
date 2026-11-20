/**
 * Tests du calcul des prix d'un lead : mode d'achat, règle de revente, choix du tarif par couple
 * fournisseur + régie et par date, pose des prix sur une piste, refus des périodes qui se
 * recouvrent.
 */
@IsTest
private class LeadPrixServiceTest {
  private static Tarif_Lead__c tarif(
    String mode,
    Decimal achat,
    Decimal provisoire,
    String regle,
    Decimal revente,
    Decimal marge
  ) {
    return new Tarif_Lead__c(
      Mode_achat__c = mode,
      Prix_Achat__c = achat,
      Prix_Achat_Provisoire__c = provisoire,
      Regle_revente__c = regle,
      Prix_Revente__c = revente,
      Marge__c = marge
    );
  }

  private static Tarif_Lead__c periode(
    Id fournisseur,
    Id regie,
    Date debut,
    Date fin
  ) {
    return new Tarif_Lead__c(
      Fournisseur__c = fournisseur,
      Regie__c = regie,
      Date_debut__c = debut,
      Date_fin__c = fin,
      Actif__c = true,
      Mode_achat__c = LeadPrixService.MODE_FIXE,
      Prix_Achat__c = 5,
      Regle_revente__c = LeadPrixService.REVENTE_ACHAT
    );
  }

  // ------------------------------------------------------------ Calcul

  @IsTest
  static void acheterCinqEtRevendreDix() {
    LeadPrixService.Prix p = LeadPrixService.prixDuTarif(
      tarif(
        LeadPrixService.MODE_FIXE,
        5,
        null,
        LeadPrixService.REVENTE_FIXE,
        10,
        null
      )
    );

    Assert.areEqual(5, p.achat);
    Assert.areEqual(10, p.revente);
    Assert.areEqual(LeadPrixService.STATUT_DEFINITIF, p.statut);
    Assert.areEqual(LeadPrixService.MODE_FIXE, p.modeAchat);
    Assert.isFalse(p.fauxNumerosPayes);
  }

  @IsTest
  static void pourcentageDeCampagneDonneUnPrixProvisoire() {
    Tarif_Lead__c t = tarif(
      LeadPrixService.MODE_POURCENTAGE,
      99,
      4,
      LeadPrixService.REVENTE_MARGE_POURCENT,
      null,
      50
    );
    t.Faux_numeros_payes__c = true;

    LeadPrixService.Prix p = LeadPrixService.prixDuTarif(t);

    Assert.areEqual(
      4,
      p.achat,
      'le prix provisoire, pas le prix fixe resté dans la fiche'
    );
    Assert.areEqual(6, p.revente, 'achat + 50 %');
    Assert.areEqual(LeadPrixService.STATUT_PROVISOIRE, p.statut);
    Assert.isTrue(p.fauxNumerosPayes);
  }

  @IsTest
  static void sansTarifAucunPrix() {
    LeadPrixService.Prix p = LeadPrixService.prixDuTarif(null);

    Assert.isNull(p.tarifId);
    Assert.isNull(p.achat);
    Assert.isNull(p.revente);
    Assert.areEqual(LeadPrixService.STATUT_SANS_TARIF, p.statut);
    Assert.isFalse(p.fauxNumerosPayes);
    Assert.isNull(LeadPrixService.revente(null, 5));
  }

  @IsTest
  static void reventeSelonLaRegle() {
    Assert.areEqual(
      10,
      LeadPrixService.revente(
        tarif(null, null, null, LeadPrixService.REVENTE_FIXE, 10, null),
        5
      ),
      'prix fixe : indépendant de l’achat'
    );
    Assert.areEqual(
      5,
      LeadPrixService.revente(
        tarif(null, null, null, LeadPrixService.REVENTE_ACHAT, 10, null),
        5
      ),
      'revente au prix d’achat'
    );
    Assert.areEqual(
      6.13,
      LeadPrixService.revente(
        tarif(
          null,
          null,
          null,
          LeadPrixService.REVENTE_MARGE_POURCENT,
          null,
          22.5
        ),
        5
      ),
      'achat + 22,5 %, arrondi au centime'
    );
    Assert.areEqual(
      8,
      LeadPrixService.revente(
        tarif(null, null, null, LeadPrixService.REVENTE_MARGE_EUROS, null, 3),
        5
      ),
      'achat + 3 €'
    );
    Assert.isNull(
      LeadPrixService.revente(
        tarif(null, null, null, LeadPrixService.REVENTE_ACHAT, 10, null),
        null
      ),
      'achat inconnu : revente inconnue'
    );
    Assert.isNull(
      LeadPrixService.revente(
        tarif(null, null, null, 'Règle inconnue', 10, null),
        5
      )
    );
    Assert.isFalse(
      LeadPrixService.reventeDependDeLAchat(LeadPrixService.REVENTE_FIXE)
    );
    Assert.isTrue(
      LeadPrixService.reventeDependDeLAchat(LeadPrixService.REVENTE_ACHAT)
    );
    Assert.isTrue(
      LeadPrixService.reventeDependDeLAchat(
        LeadPrixService.REVENTE_MARGE_POURCENT
      )
    );
    Assert.isTrue(
      LeadPrixService.reventeDependDeLAchat(LeadPrixService.REVENTE_MARGE_EUROS)
    );
  }

  @IsTest
  static void poserLesPrixSelonCeQuiEstDu() {
    LeadPrixService.Prix p = LeadPrixService.prixDuTarif(
      tarif(
        LeadPrixService.MODE_FIXE,
        5,
        null,
        LeadPrixService.REVENTE_FIXE,
        10,
        null
      )
    );
    Lead normale = new Lead(LastName = 'Normale');
    Lead fauxNumero = new Lead(LastName = 'Faux numéro');

    LeadPrixService.poser(normale, p, true, true);
    LeadPrixService.poser(fauxNumero, p, false, false);

    Assert.areEqual(5, normale.Prix_Achat__c);
    Assert.areEqual(10, normale.Prix_Revente__c);
    Assert.isTrue(normale.Paye_fournisseur__c);
    Assert.isTrue(normale.Facture_regie__c);
    Assert.areEqual(LeadPrixService.STATUT_DEFINITIF, normale.Statut_Prix__c);
    Assert.isNull(fauxNumero.Prix_Achat__c, 'pas dû : pas de montant');
    Assert.isNull(fauxNumero.Prix_Revente__c, 'pas facturé : pas de montant');
    Assert.isFalse(fauxNumero.Paye_fournisseur__c);
    Assert.isFalse(fauxNumero.Facture_regie__c);
  }

  // ------------------------------------------------------------ Choix du tarif

  @IsTest
  static void tarifDuCoupleEtDuJour() {
    Fournisseur_Lead__c f1 = RemonteeLeadTestData.fournisseur('F001');
    Fournisseur_Lead__c f2 = RemonteeLeadTestData.fournisseur('F002');
    Campaign regieA = RemonteeLeadTestData.regie('Régie A');
    Campaign regieB = RemonteeLeadTestData.regie('Régie B');
    Date aujourdHui = Date.today();
    Tarif_Lead__c ancien = periode(
      f1.Id,
      regieA.Id,
      aujourdHui.addDays(-60),
      aujourdHui.addDays(-31)
    );
    ancien.Prix_Achat__c = 3;
    Tarif_Lead__c courant = periode(
      f1.Id,
      regieA.Id,
      aujourdHui.addDays(-30),
      null
    );
    courant.Prix_Achat__c = 5;
    // Le même fournisseur livre une autre régie à un autre prix.
    Tarif_Lead__c autreRegie = periode(
      f1.Id,
      regieB.Id,
      aujourdHui.addDays(-30),
      null
    );
    autreRegie.Prix_Achat__c = 8;
    insert new List<Tarif_Lead__c>{ ancien, courant, autreRegie };

    Test.startTest();
    LeadPrixService duJour = new LeadPrixService();
    duJour.charger(
      new Set<Id>{ f1.Id, f2.Id, null },
      new Set<Id>{ regieA.Id, regieB.Id },
      aujourdHui
    );
    LeadPrixService dAvant = new LeadPrixService();
    dAvant.charger(
      new Set<Id>{ f1.Id },
      new Set<Id>{ regieA.Id },
      aujourdHui.addDays(-45)
    );
    Test.stopTest();

    Assert.areEqual(5, duJour.prixDuCouple(f1.Id, regieA.Id).achat);
    Assert.areEqual(courant.Id, duJour.tarifDuCouple(f1.Id, regieA.Id).Id);
    Assert.areEqual(
      8,
      duJour.prixDuCouple(f1.Id, regieB.Id).achat,
      'un tarif par couple fournisseur + régie'
    );
    Assert.areEqual(
      LeadPrixService.STATUT_SANS_TARIF,
      duJour.prixDuCouple(f2.Id, regieA.Id).statut,
      'aucun tarif pour ce fournisseur'
    );
    Assert.isNull(duJour.tarifDuCouple(f1.Id, null));
    Assert.areEqual(
      3,
      dAvant.prixDuCouple(f1.Id, regieA.Id).achat,
      'le tarif valable à la date d’arrivée du lead'
    );
  }

  @IsTest
  static void tariferDesPistesCreeesAutrementQueParLaFeuille() {
    Test.setMock(HttpCalloutMock.class, new RemonteeLeadGoogleMock());
    Fournisseur_Lead__c fournisseur = RemonteeLeadTestData.fournisseur('F001');
    Campaign regie = RemonteeLeadTestData.regie('Régie de test');
    Tarif_Lead__c t = RemonteeLeadTestData.tarifFixe(fournisseur, regie, 5, 10);
    update new Tarif_Lead__c(Id = t.Id, Faux_numeros_payes__c = true);
    Source_Lead__c src = RemonteeLeadTestData.source(
      fournisseur,
      'classeur-saisie',
      regie
    );
    Lead normale = new Lead(
      LastName = 'Saisie par la régie',
      Source_Lead__c = src.Id,
      Campagne_REGIE__c = regie.Id
    );
    Lead regieDeLaSource = new Lead(
      LastName = 'Sans régie renseignée',
      Source_Lead__c = src.Id
    );
    Lead fauxNumero = new Lead(
      LastName = 'Faux numéro',
      Source_Lead__c = src.Id,
      Faux_Numero__c = true
    );
    Lead sansSource = new Lead(LastName = 'Sans source');

    Test.startTest();
    new LeadPrixService()
      .tarifer(
        new List<Lead>{ normale, regieDeLaSource, fauxNumero, sansSource },
        Date.today()
      );
    Test.stopTest();

    Assert.areEqual(5, normale.Prix_Achat__c);
    Assert.areEqual(10, normale.Prix_Revente__c);
    Assert.areEqual(t.Id, normale.Tarif_Lead__c);
    Assert.areEqual(
      5,
      regieDeLaSource.Prix_Achat__c,
      'à défaut, la régie de la Source'
    );
    Assert.isTrue(
      fauxNumero.Paye_fournisseur__c,
      'ce tarif paie les faux numéros'
    );
    Assert.areEqual(5, fauxNumero.Prix_Achat__c);
    Assert.isFalse(fauxNumero.Facture_regie__c, 'jamais facturé à la régie');
    Assert.isNull(fauxNumero.Prix_Revente__c);
    Assert.areEqual(
      LeadPrixService.STATUT_SANS_TARIF,
      sansSource.Statut_Prix__c
    );
    Assert.isNull(sansSource.Prix_Achat__c);
  }

  // ------------------------------------------------------------ Périodes qui se recouvrent

  @IsTest
  static void deuxPeriodesSeRecouvrentOuNon() {
    Date j = Date.newInstance(2026, 11, 1);
    Tarif_Lead__c novembre = periode(null, null, j, j.addDays(29));
    Tarif_Lead__c decembre = periode(null, null, j.addDays(30), null);
    Tarif_Lead__c miNovembre = periode(
      null,
      null,
      j.addDays(14),
      j.addDays(44)
    );
    Tarif_Lead__c sansFin = periode(null, null, j.addDays(-100), null);

    Assert.isFalse(LeadPrixService.seChevauchent(novembre, decembre));
    Assert.isFalse(LeadPrixService.seChevauchent(decembre, novembre));
    Assert.isTrue(LeadPrixService.seChevauchent(novembre, miNovembre));
    Assert.isTrue(LeadPrixService.seChevauchent(miNovembre, decembre));
    Assert.isTrue(
      LeadPrixService.seChevauchent(novembre, sansFin),
      'un tarif sans fin recouvre tout ce qui suit son début'
    );
    Assert.isTrue(
      LeadPrixService.seChevauchent(novembre, novembre.clone()),
      'même jour de début et de fin'
    );
  }

  @IsTest
  static void refusDansUnMemeLotSansToucherLesAutresCouples() {
    Fournisseur_Lead__c f = RemonteeLeadTestData.fournisseur('F001');
    Campaign regieA = RemonteeLeadTestData.regie('Régie A');
    Campaign regieB = RemonteeLeadTestData.regie('Régie B');
    Date j = Date.today();
    Tarif_Lead__c premier = periode(f.Id, regieA.Id, j, null);
    Tarif_Lead__c enDouble = periode(f.Id, regieA.Id, j.addDays(10), null);
    Tarif_Lead__c autreCouple = periode(f.Id, regieB.Id, j, null);
    Tarif_Lead__c inactif = periode(f.Id, regieA.Id, j, null);
    inactif.Actif__c = false;

    Test.startTest();
    new LeadPrixService()
      .refuserLesChevauchements(
        new List<Tarif_Lead__c>{ premier, enDouble, autreCouple, inactif }
      );
    Test.stopTest();

    Assert.isFalse(premier.hasErrors());
    Assert.isTrue(
      enDouble.hasErrors(),
      'même couple, périodes qui se recouvrent'
    );
    Assert.isTrue(
      enDouble.getErrors()[0].getMessage().contains('recouvre un autre tarif'),
      enDouble.getErrors()[0].getMessage()
    );
    Assert.isFalse(autreCouple.hasErrors(), 'une autre régie : un autre tarif');
    Assert.isFalse(inactif.hasErrors(), 'un tarif inactif ne gêne personne');
  }
}
