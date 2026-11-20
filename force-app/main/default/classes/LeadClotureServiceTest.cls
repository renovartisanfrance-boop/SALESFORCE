/**
 * Tests de la clôture mensuelle des leads : ouverture d'un mois, totaux (leads payés, doublons
 * internes payés, faux numéros non facturés), clôture à prix fixe, clôture au pourcentage de
 * campagne avec répartition du coût réel, et action appelable depuis un flux.
 */
@IsTest
private class LeadClotureServiceTest {
  private static Cloture_Lead__c relire(Id idCloture) {
    return [
      SELECT
        Statut__c,
        Periode__c,
        Fournisseur__c,
        Regie__c,
        Compte_Regie__c,
        Nombre_payes__c,
        Nombre_a_repartir__c,
        Nombre_factures__c,
        Montant_achat__c,
        Montant_revente__c,
        Cout_unitaire__c,
        Date_cloture__c,
        Alerte__c
      FROM Cloture_Lead__c
      WHERE Id = :idCloture
    ];
  }

  private static LeadClotureService.Demande demande(
    String action,
    Date mois,
    Id idCloture
  ) {
    LeadClotureService.Demande d = new LeadClotureService.Demande();
    d.action = action;
    d.mois = mois;
    d.clotureId = idCloture;
    return d;
  }

  private static LeadClotureService.Reponse appeler(
    String action,
    Date mois,
    Id idCloture
  ) {
    return LeadClotureService.executer(
      new List<LeadClotureService.Demande>{ demande(action, mois, idCloture) }
    )[0];
  }

  // ------------------------------------------------------------ Prix fixe

  @IsTest
  static void moisAPrixFixeOuvertPuisCloture() {
    Test.setMock(HttpCalloutMock.class, new RemonteeLeadGoogleMock());
    RemonteeLeadTestData.Mois mois = RemonteeLeadTestData.moisDeLeads(false);

    Test.startTest();
    LeadClotureService service = new LeadClotureService();
    List<Cloture_Lead__c> ouvertes = service.ouvrirMois(Date.today());
    Cloture_Lead__c ouverte = relire(ouvertes[0].Id);
    String message = service.cloturer(ouvertes[0].Id);
    List<Cloture_Lead__c> rouvertes = service.ouvrirMois(Date.today());
    Test.stopTest();

    Assert.areEqual(1, ouvertes.size(), 'un couple fournisseur + régie');
    Assert.areEqual(LeadClotureService.STATUT_OUVERTE, ouverte.Statut__c);
    Assert.areEqual(Date.today().toStartOfMonth(), ouverte.Periode__c);
    Assert.areEqual(mois.fournisseur.Id, ouverte.Fournisseur__c);
    Assert.areEqual(mois.regie.Id, ouverte.Regie__c);
    Assert.areEqual(mois.compte.Id, ouverte.Compte_Regie__c);
    Assert.areEqual(
      3,
      ouverte.Nombre_payes__c,
      'deux leads et le doublon interne ; pas le faux numéro'
    );
    Assert.areEqual(15, ouverte.Montant_achat__c, '3 × 5 €');
    Assert.areEqual(
      2,
      ouverte.Nombre_factures__c,
      'ni le doublon ni le faux numéro ne sont facturés à la régie'
    );
    Assert.areEqual(20, ouverte.Montant_revente__c, '2 × 10 €');
    Assert.areEqual(
      0,
      ouverte.Nombre_a_repartir__c,
      'prix fixes : rien à répartir'
    );

    Assert.areEqual('Clôture figée.', message);
    Cloture_Lead__c figee = relire(ouvertes[0].Id);
    Assert.areEqual(LeadClotureService.STATUT_CLOTUREE, figee.Statut__c);
    Assert.isNotNull(figee.Date_cloture__c);
    Assert.areEqual(15, figee.Montant_achat__c);
    Assert.areEqual(
      20,
      [SELECT Montant_leads__c FROM Campaign WHERE Id = :mois.regie.Id]
      .Montant_leads__c,
      'montant des leads reporté sur la fiche de la régie'
    );
    Assert.isTrue(
      rouvertes.isEmpty(),
      'une clôture figée n’est pas recalculée'
    );
  }

  @IsTest
  static void clotureDejaFigeeNiRecalculeeNiRecloturee() {
    Test.setMock(HttpCalloutMock.class, new RemonteeLeadGoogleMock());
    RemonteeLeadTestData.moisDeLeads(false);
    LeadClotureService service = new LeadClotureService();
    Id idCloture = service.ouvrirMois(Date.today())[0].Id;
    service.calculer(new Set<Id>{ idCloture });
    service.cloturer(idCloture);

    Test.startTest();
    String erreurCalcul;
    String erreurCloture;
    try {
      service.calculer(new Set<Id>{ idCloture });
    } catch (LeadClotureService.ClotureException e) {
      erreurCalcul = e.getMessage();
    }
    try {
      service.cloturer(idCloture);
    } catch (LeadClotureService.ClotureException e) {
      erreurCloture = e.getMessage();
    }
    Test.stopTest();

    Assert.isTrue(
      erreurCalcul != null && erreurCalcul.contains('déjà clôturée'),
      erreurCalcul
    );
    Assert.isTrue(
      erreurCloture != null && erreurCloture.contains('déjà clôturée'),
      erreurCloture
    );
  }

  // ------------------------------------------------------------ Pourcentage de campagne

  @IsTest
  static void coutReelRepartiSurTousLesLeadsPayes() {
    Test.setMock(HttpCalloutMock.class, new RemonteeLeadGoogleMock());
    RemonteeLeadTestData.Mois mois = RemonteeLeadTestData.moisDeLeads(true);
    LeadClotureService service = new LeadClotureService();
    Id idCloture = service.ouvrirMois(Date.today())[0].Id;
    Cloture_Lead__c ouverte = relire(idCloture);
    // Budget 25 € + 20 % de commission = 30 € pour 3 leads payés : 10 € par lead.
    update new Cloture_Lead__c(Id = idCloture, Budget__c = 25, Taux__c = 20);

    Test.startTest();
    String message = service.cloturer(idCloture);
    Cloture_Lead__c enCours = relire(idCloture);
    Test.stopTest();

    Assert.areEqual(3, ouverte.Nombre_payes__c);
    Assert.areEqual(
      3,
      ouverte.Nombre_a_repartir__c,
      'deux pistes et le doublon interne attendent le coût réel'
    );
    Assert.areEqual(12, ouverte.Montant_achat__c, '3 × 4 € provisoires');
    Assert.areEqual(12, ouverte.Montant_revente__c, '2 × (4 € + 50 %)');
    Assert.isTrue(message.startsWith('Répartition du coût lancée'), message);
    Assert.areEqual(LeadClotureService.STATUT_EN_COURS, enCours.Statut__c);
    Assert.areEqual(10, enCours.Cout_unitaire__c);
    Assert.isNotNull(LeadClotureService.dernierLot);

    List<Lead> pistes = [
      SELECT LastName, Prix_Achat__c, Prix_Revente__c, Statut_Prix__c
      FROM Lead
      WHERE Source_Lead__c = :mois.source.Id AND Paye_fournisseur__c = TRUE
      ORDER BY LastName
    ];
    Assert.areEqual(2, pistes.size());
    for (Lead piste : pistes) {
      Assert.areEqual(10, piste.Prix_Achat__c, piste.LastName);
      Assert.areEqual(
        15,
        piste.Prix_Revente__c,
        'la revente suit l’achat : 10 € + 50 %'
      );
      Assert.areEqual(LeadPrixService.STATUT_DEFINITIF, piste.Statut_Prix__c);
    }
    Assert.areEqual(
      10,
      [
        SELECT Prix_Achat__c
        FROM Rejet_Lead__c
        WHERE
          Source__c = :mois.source.Id
          AND Motif__c = :RemonteeLeadService.MOTIF_DOUBLON_INTERNE
      ]
      .Prix_Achat__c,
      'le doublon interne est payé au même coût réel'
    );
    Cloture_Lead__c figee = relire(idCloture);
    Assert.areEqual(LeadClotureService.STATUT_CLOTUREE, figee.Statut__c);
    Assert.areEqual(0, figee.Nombre_a_repartir__c);
    Assert.areEqual(30, figee.Montant_achat__c, 'le total de la facture');
    Assert.areEqual(30, figee.Montant_revente__c, '2 × 15 €');
    Assert.isNull(figee.Alerte__c);
    Assert.areEqual(
      30,
      [SELECT Montant_leads__c FROM Campaign WHERE Id = :mois.regie.Id]
      .Montant_leads__c
    );
  }

  @IsTest
  static void sansFactureNiBudgetLaClotureEstRefusee() {
    Test.setMock(HttpCalloutMock.class, new RemonteeLeadGoogleMock());
    RemonteeLeadTestData.moisDeLeads(true);
    LeadClotureService service = new LeadClotureService();
    Id idCloture = service.ouvrirMois(Date.today())[0].Id;

    Test.startTest();
    LeadClotureService.Reponse reponse = appeler(
      LeadClotureService.ACTION_CLOTURER,
      null,
      idCloture
    );
    // Des pistes sont restées au prix provisoire : la clôture ne se termine pas.
    service.terminer(idCloture);
    Test.stopTest();

    Assert.isFalse(reponse.reussi);
    Assert.isTrue(reponse.message.contains('prix provisoire'), reponse.message);
    Cloture_Lead__c restee = relire(idCloture);
    Assert.areEqual(LeadClotureService.STATUT_EN_COURS, restee.Statut__c);
    Assert.isTrue(
      restee.Alerte__c.contains('restés au prix provisoire'),
      restee.Alerte__c
    );
    Assert.isNull(restee.Date_cloture__c);
  }

  // ------------------------------------------------------------ Action appelable

  @IsTest
  static void actionAppelableDepuisUnFlux() {
    Test.setMock(HttpCalloutMock.class, new RemonteeLeadGoogleMock());
    RemonteeLeadTestData.moisDeLeads(false);

    Test.startTest();
    LeadClotureService.Reponse ouverture = appeler(
      LeadClotureService.ACTION_OUVRIR,
      Date.today(),
      null
    );
    Id idCloture = [SELECT Id FROM Cloture_Lead__c LIMIT 1].Id;
    List<LeadClotureService.Reponse> calculs = LeadClotureService.executer(
      new List<LeadClotureService.Demande>{
        demande(LeadClotureService.ACTION_CALCULER, null, idCloture),
        demande(LeadClotureService.ACTION_CALCULER, null, idCloture)
      }
    );
    LeadClotureService.Reponse sansMois = appeler(
      LeadClotureService.ACTION_OUVRIR,
      null,
      null
    );
    LeadClotureService.Reponse sansCloture = appeler(
      LeadClotureService.ACTION_CALCULER,
      null,
      null
    );
    LeadClotureService.Reponse inconnue = appeler('Supprimer', null, idCloture);
    LeadClotureService.Reponse cloture = appeler(
      LeadClotureService.ACTION_CLOTURER,
      null,
      idCloture
    );
    Test.stopTest();

    Assert.isTrue(ouverture.reussi, ouverture.message);
    Assert.isTrue(ouverture.message.startsWith('1 clôture'), ouverture.message);
    Assert.isTrue(calculs[0].reussi, calculs[0].message);
    Assert.isFalse(calculs[1].reussi, 'une seule demande par appel');
    Assert.isTrue(
      calculs[1].message.contains('Une seule demande'),
      calculs[1].message
    );
    Assert.isFalse(sansMois.reussi);
    Assert.isTrue(sansMois.message.contains('jour du mois'), sansMois.message);
    Assert.isFalse(sansCloture.reussi);
    Assert.isTrue(
      sansCloture.message.contains('clôture concernée'),
      sansCloture.message
    );
    Assert.isFalse(inconnue.reussi);
    Assert.isTrue(
      inconnue.message.contains('Action inconnue'),
      inconnue.message
    );
    Assert.isTrue(cloture.reussi, cloture.message);
    Assert.areEqual(
      LeadClotureService.STATUT_CLOTUREE,
      relire(idCloture).Statut__c
    );
  }

  @IsTest
  static void moisSansLeadNeCreeAucuneCloture() {
    Test.setMock(HttpCalloutMock.class, new RemonteeLeadGoogleMock());
    RemonteeLeadTestData.moisDeLeads(false);

    Test.startTest();
    List<Cloture_Lead__c> anciennes = new LeadClotureService()
      .ouvrirMois(Date.today().addMonths(-6));
    Test.stopTest();

    Assert.isTrue(anciennes.isEmpty(), 'aucun lead ce mois-là');
    Assert.areEqual(0, [SELECT COUNT() FROM Cloture_Lead__c]);
    Assert.isTrue(
      LeadClotureService.cle(
          UserInfo.getUserId(),
          UserInfo.getUserId(),
          Date.newInstance(2026, 11, 20)
        )
        .endsWith('|2026-11'),
      'une clé par couple et par mois'
    );
  }
}
