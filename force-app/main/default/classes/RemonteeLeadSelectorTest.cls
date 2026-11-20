/**
 * Tests des requêtes de la remontée des leads.
 */
@IsTest
private class RemonteeLeadSelectorTest {
  private static final RemonteeLeadSelector SELECTOR = new RemonteeLeadSelector();

  @IsTest
  static void sourcesActivesDUnFournisseurActifSeulement() {
    Fournisseur_Lead__c actif = RemonteeLeadTestData.fournisseur('F001');
    Fournisseur_Lead__c coupe = RemonteeLeadTestData.fournisseur('F002');
    Source_Lead__c lue = RemonteeLeadTestData.source(actif, 'classeur-a');
    Source_Lead__c eteinte = RemonteeLeadTestData.source(actif, 'classeur-b');
    Source_Lead__c fournisseurCoupe = RemonteeLeadTestData.source(
      coupe,
      'classeur-c'
    );
    update new Source_Lead__c(Id = eteinte.Id, Actif__c = false);
    update new Fournisseur_Lead__c(Id = coupe.Id, Actif__c = false);

    Test.startTest();
    List<Source_Lead__c> actives = SELECTOR.sourcesActives();
    Map<Id, Source_Lead__c> parId = SELECTOR.sourcesParId(
      new Set<Id>{ lue.Id, eteinte.Id, fournisseurCoupe.Id }
    );
    Test.stopTest();

    Assert.areEqual(
      1,
      actives.size(),
      'ni la source éteinte ni celle du fournisseur coupé'
    );
    Assert.areEqual(lue.Id, actives[0].Id);
    Assert.areEqual(3, parId.size());
    Assert.areEqual('F001', parId.get(lue.Id).Fournisseur__r.Code__c);
    Assert.areEqual('classeur-a', parId.get(lue.Id).Spreadsheet_Id__c);
    Assert.areEqual(RemonteeLeadTestData.ONGLET, parId.get(lue.Id).Onglet__c);
    Assert.isNotNull(parId.get(lue.Id).Mapping_JSON__c);
    Assert.isNull(parId.get(lue.Id).Regie__c, 'source créée sans régie');
  }

  @IsTest
  static void regieDeLaSourceEtSonCompte() {
    Test.setMock(HttpCalloutMock.class, new RemonteeLeadGoogleMock());
    Campaign regie = RemonteeLeadTestData.regie('Régie de test');
    Campaign sansCompte = RemonteeLeadTestData.regie('Régie sans compte');
    Account compte = RemonteeLeadTestData.compteDeLaRegie(regie);
    Source_Lead__c src = RemonteeLeadTestData.source(
      RemonteeLeadTestData.fournisseur('F001'),
      'classeur-a',
      regie
    );

    Test.startTest();
    List<Account> comptes = SELECTOR.comptesParRegie(
      new Set<Id>{ regie.Id, sansCompte.Id }
    );
    Test.stopTest();

    Assert.areEqual(regie.Id, src.Regie__c);
    Assert.isTrue(
      src.Regie__r.EstREGIE__c,
      'la Source est relue avec la nature de sa régie'
    );
    Assert.areEqual(1, comptes.size(), 'seul le compte relié à la régie');
    Assert.areEqual(compte.Id, comptes[0].Id);
    Assert.areEqual(regie.Id, comptes[0].Acces_REGIE__c);
  }

  @IsTest
  static void retrouveLesDossiersEtLesLignesDejaRejetees() {
    Test.setMock(HttpCalloutMock.class, new RemonteeLeadGoogleMock());
    Pro__c dossier = RemonteeLeadTestData.dossierExistant(
      'Dossier',
      '34666111222',
      RemonteeLeadTestData.statutDossierVivant()
    );
    update new Pro__c(Id = dossier.Id, Email__c = 'dossier@exemple.com');
    Source_Lead__c src = RemonteeLeadTestData.source(
      RemonteeLeadTestData.fournisseur('F001'),
      'classeur-a'
    );
    insert new List<Rejet_Lead__c>{
      new Rejet_Lead__c(
        Cle__c = src.Id + '|4|666111222',
        Source__c = src.Id,
        Fournisseur__c = src.Fournisseur__c,
        Motif__c = RemonteeLeadService.MOTIF_DOUBLON_INTERNE,
        Telephone_Cle__c = '666111222',
        Ligne__c = 4,
        Date_rejet__c = DateTime.now()
      ),
      new Rejet_Lead__c(
        Cle__c = src.Id + '|5|x',
        Source__c = src.Id,
        Fournisseur__c = src.Fournisseur__c,
        Motif__c = RemonteeLeadService.MOTIF_ERREUR,
        Telephone_Cle__c = '666111222',
        Ligne__c = 5,
        Date_rejet__c = DateTime.now()
      ),
      new Rejet_Lead__c(
        Cle__c = src.Id + '|6|mail@exemple.com',
        Source__c = src.Id,
        Fournisseur__c = src.Fournisseur__c,
        Motif__c = RemonteeLeadService.MOTIF_FAUX_NUMERO,
        Email__c = 'mail@exemple.com',
        Ligne__c = 6,
        Date_rejet__c = DateTime.now()
      )
    };
    Id opportuniteInconnue =
      Opportunity.SObjectType.getDescribe().getKeyPrefix() + '000000000001';

    Test.startTest();
    List<Pro__c> parNumero = SELECTOR.dossiersParTelephoneExact(
      new Set<String>{ '34666111222', '666111222' }
    );
    List<Pro__c> parEmail = SELECTOR.dossiersParEmail(
      new Set<String>{ 'dossier@exemple.com' }
    );
    List<Pro__c> parOpportunite = SELECTOR.dossiersParOpportunite(
      new Set<Id>{ opportuniteInconnue }
    );
    List<Pro__c> parGroupe = SELECTOR.dossiersParGroupeDoublon(
      new Set<String>{ '000000000' }
    );
    List<Rejet_Lead__c> rejets = SELECTOR.rejetsDejaNotes(
      new Set<Id>{ src.Id },
      new Set<String>{ '666111222' },
      new Set<String>{ 'mail@exemple.com' },
      new Set<String>{
        RemonteeLeadService.MOTIF_DOUBLON_INTERNE,
        RemonteeLeadService.MOTIF_DOUBLON_FEUILLE,
        RemonteeLeadService.MOTIF_FAUX_NUMERO
      }
    );
    Test.stopTest();

    Assert.areEqual(1, parNumero.size());
    Assert.areEqual(dossier.Id, parNumero[0].Id);
    Assert.areEqual(
      RemonteeLeadTestData.statutDossierVivant(),
      parNumero[0].PAC_STATUT_DOSSIER__c,
      'le statut du dossier est lu : c’est lui qui décide'
    );
    Assert.areEqual(1, parEmail.size());
    Assert.areEqual(dossier.Id, parEmail[0].Id);
    Assert.isTrue(parOpportunite.isEmpty(), 'opportunité sans dossier');
    Assert.isTrue(parGroupe.isEmpty(), 'aucun groupe pour ce numéro');
    Assert.areEqual(
      2,
      rejets.size(),
      'la ligne en erreur ne compte pas : elle sera retentée'
    );
    Assert.areEqual(4, rejets[0].Ligne__c, 'triées par numéro de ligne');
    Assert.areEqual(6, rejets[1].Ligne__c);
  }

  @IsTest
  static void retrouveLesPistesDejaPresentes() {
    Test.setMock(HttpCalloutMock.class, new RemonteeLeadGoogleMock());
    Lead ancienne = RemonteeLeadTestData.pisteExistante(
      'Ancienne',
      '34666111222',
      'ancienne@exemple.com'
    );
    Lead remontee = RemonteeLeadTestData.pisteExistante(
      'Remontee',
      '34677111222',
      'remontee@exemple.com'
    );
    update new Lead(
      Id = remontee.Id,
      Telephone_Cle__c = '677111222',
      Ligne_Feuille__c = 'source|2|677111222',
      Code_Fournisseur__c = 'F001'
    );

    Test.startTest();
    List<Lead> parLigne = SELECTOR.pistesParLigneFeuille(
      new Set<String>{ 'source|2|677111222', 'source|3|x' }
    );
    List<Lead> parCle = SELECTOR.pistesParCleTelephone(
      new Set<String>{ '677111222', '666111222' }
    );
    List<Lead> parNumero = SELECTOR.pistesParTelephoneExact(
      new Set<String>{ '34666111222', '666111222' }
    );
    List<Lead> parEmail = SELECTOR.pistesParEmail(
      new Set<String>{ 'ancienne@exemple.com' }
    );
    List<Lead> parGroupe = SELECTOR.pistesParGroupeDoublon(
      new Set<String>{ '000000000' }
    );
    Test.stopTest();

    Assert.areEqual(1, parLigne.size());
    Assert.areEqual(remontee.Id, parLigne[0].Id);
    Assert.areEqual('F001', parLigne[0].Code_Fournisseur__c);
    Assert.areEqual(1, parCle.size(), 'seule la piste qui porte la clé');
    Assert.areEqual(remontee.Id, parCle[0].Id);
    Assert.areEqual(
      1,
      parNumero.size(),
      'ancienne piste retrouvée sur son numéro brut'
    );
    Assert.areEqual(ancienne.Id, parNumero[0].Id);
    Assert.areEqual(1, parEmail.size());
    Assert.areEqual(ancienne.Id, parEmail[0].Id);
    Assert.isTrue(
      parGroupe.isEmpty(),
      'aucun groupe pour ce numéro, et aucune erreur'
    );
  }

  @IsTest
  static void ensemblesVidesSansRequete() {
    Set<String> rien = new Set<String>();

    Test.startTest();
    Integer avant = Limits.getQueries();
    Assert.isTrue(SELECTOR.pistesParLigneFeuille(rien).isEmpty());
    Assert.isTrue(SELECTOR.pistesParCleTelephone(rien).isEmpty());
    Assert.isTrue(SELECTOR.pistesParTelephoneExact(rien).isEmpty());
    Assert.isTrue(SELECTOR.pistesParEmail(rien).isEmpty());
    Assert.isTrue(SELECTOR.pistesParGroupeDoublon(rien).isEmpty());
    Assert.isTrue(SELECTOR.dossiersParGroupeDoublon(rien).isEmpty());
    Assert.isTrue(SELECTOR.dossiersParTelephoneExact(rien).isEmpty());
    Assert.isTrue(SELECTOR.dossiersParEmail(rien).isEmpty());
    Assert.isTrue(SELECTOR.dossiersParOpportunite(new Set<Id>()).isEmpty());
    Assert.isTrue(SELECTOR.comptesParRegie(new Set<Id>()).isEmpty());
    Assert.isTrue(
      SELECTOR.rejetsDejaNotes(new Set<Id>(), rien, rien, rien).isEmpty()
    );
    Integer apres = Limits.getQueries();
    Test.stopTest();

    Assert.areEqual(avant, apres, 'rien à chercher : aucune requête consommée');
  }

  @IsTest
  static void etatDeLaChaine() {
    Test.startTest();
    Integer enCours = SELECTOR.travauxEnCours(RemonteeLeadQueueable.NOM_CLASSE);
    Boolean planifiee = SELECTOR.tachePlanifieeExiste(
      'Tâche qui n’existe pas ' + Crypto.getRandomInteger()
    );
    Test.stopTest();

    Assert.areEqual(0, enCours, 'aucun traitement lancé dans ce test');
    Assert.isFalse(planifiee);
  }
}
