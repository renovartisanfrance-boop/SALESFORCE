/**
 * Tests du calculateur RES060 sur la Piste (via LeadTrigger / LeadTriggerHandler).
 * Valeurs attendues recalculées avec la formule RES060_FM (D_CAL × 1,3 + 11, η 0,70, fM 2, 160 €/MWh,
 * mitoyenneté non renseignée = −5 %), à partir des réglages de l'org.
 */
@IsTest
private class SimulationRES060PisteServiceTest {
  /** Les Flows des Pistes font des appels sortants (géocodage, SMS). */
  private class BouchonCallout implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest requete) {
      HttpResponse reponse = new HttpResponse();
      reponse.setStatusCode(200);
      reponse.setHeader('Content-Type', 'application/json');
      String endpoint = requete.getEndpoint();
      reponse.setBody(
        endpoint != null && endpoint.contains('nominatim')
          ? '[]'
          : '{"success":true}'
      );
      return reponse;
    }
  }

  private static Id typePiste(String nom) {
    return Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName()
      .get(nom)
      .getRecordTypeId();
  }

  /** Piste interne RES060 complète : Asturias trouvée dans l'adresse (pas de code postal saisi). */
  private static Lead pisteAsturias(String nom) {
    return new Lead(
      RecordTypeId = typePiste('RESIDENTIEL_LEADS'),
      TypeDeDossier__c = Constants.FICHE_PISTE_060,
      LastName = nom,
      Company = 'Foyer ' + nom,
      Street = 'LG TEJERO 18[A] 33875 TINEO [ASTURIAS]',
      Surface_habitable__c = 128,
      RES_Anne_maison__c = '1890',
      Type_de_Chauffage__c = '⛽Fioul',
      RES_Ann_e_Chaudi_re__c = '1980',
      RES_Bono_Social__c = '❌Non'
    );
  }

  private static Lead relire(Id id) {
    return [
      SELECT
        RES060_Indice__c,
        RES060_Zone__c,
        RES060_Statut__c,
        RES060_Province__c,
        RES060_Indice_Sans_Bonification__c,
        RES060_Retour_Calculateur__c
      FROM Lead
      WHERE Id = :id
    ];
  }

  @IsTest
  static void calculALaCreationAvecProvinceDansLAdresse() {
    Test.setMock(HttpCalloutMock.class, new BouchonCallout());
    Lead p = pisteAsturias('Bueno');

    Test.startTest();
    insert p;
    Test.stopTest();

    Lead lu = relire(p.Id);
    Assert.areEqual('Asturias', lu.RES060_Province__c, 'province trouvée');
    Assert.areEqual(5.0, lu.RES060_Indice__c, 'indice');
    Assert.areEqual(
      -0.8,
      lu.RES060_Indice_Sans_Bonification__c,
      'indice sans bonification (fM 1, sans ×1,5)'
    );
    Assert.areEqual(
      SimulationRES060Service.ZONE_VERTE,
      lu.RES060_Zone__c,
      'zone'
    );
    Assert.areEqual(
      SimulationRES060Service.STATUT_ELIGIBLE,
      lu.RES060_Statut__c,
      'statut'
    );
  }

  @IsTest
  static void recalculQuandUneInfoChangeSeulement() {
    Test.setMock(HttpCalloutMock.class, new BouchonCallout());
    Lead p = pisteAsturias('Recalcul');
    insert p;

    Test.startTest();
    // Changement sans rapport avec le calculateur : le résultat n'est pas recalculé.
    update new Lead(
      Id = p.Id,
      RES060_Statut__c = 'repère',
      FirstName = 'Prénom'
    );
    Lead apresAutre = relire(p.Id);
    // Le bono passe à oui : recalcul.
    update new Lead(
      Id = p.Id,
      RES_Bono_Social__c = '✅Oui',
      PostalCode = '24393',
      RES_Anne_maison__c = '1996',
      Surface_habitable__c = 157,
      RES_Ann_e_Chaudi_re__c = '1996'
    );
    Test.stopTest();

    Lead apresBono = relire(p.Id);
    Assert.areEqual(
      'repère',
      apresAutre.RES060_Statut__c,
      'pas de recalcul sans changement d\'info'
    );
    Assert.areEqual(
      'León',
      apresBono.RES060_Province__c,
      'le code postal saisi est prioritaire'
    );
    Assert.areEqual(10.5, apresBono.RES060_Indice__c, 'indice recalculé');
    Assert.areEqual(
      SimulationRES060Service.ZONE_VERTE,
      apresBono.RES060_Zone__c,
      'zone verte'
    );
  }

  @IsTest
  static void infoManquante() {
    Test.setMock(HttpCalloutMock.class, new BouchonCallout());
    Lead p = pisteAsturias('Manque');
    p.Street = null;
    p.RES_Anne_maison__c = null;
    p.Surface_habitable__c = null;

    insert p;

    Lead lu = relire(p.Id);
    Assert.isNull(lu.RES060_Indice__c, 'pas d\'indice');
    Assert.isNull(lu.RES060_Zone__c, 'pas de zone');
    Assert.areEqual(
      SimulationRES060PisteService.INFO_MANQUANTE +
      'province (code postal / adresse), surface, année de la maison',
      lu.RES060_Statut__c,
      'liste de ce qui manque'
    );
  }

  @IsTest
  static void perimetre() {
    Test.setMock(HttpCalloutMock.class, new BouchonCallout());
    Lead interneSansFiche = pisteAsturias('Interne1');
    interneSansFiche.TypeDeDossier__c = null;
    Lead interneFichePrevisite = pisteAsturias('Interne2');
    interneFichePrevisite.TypeDeDossier__c = null;
    interneFichePrevisite.PREVISITE_Fiche_Residentiel__c = '🟩RES-060 PAC';
    Lead interneAutreFiche = pisteAsturias('Interne3');
    interneAutreFiche.TypeDeDossier__c = null;
    interneAutreFiche.PREVISITE_Fiche_Residentiel__c = '🟩BAR TH171- PAC Individuelle';
    Lead externeSansFiche = pisteAsturias('Externe1');
    externeSansFiche.RecordTypeId = typePiste('RESIDENTIEL_REGIES');
    externeSansFiche.TypeDeDossier__c = null;
    Lead externeAvecFiche = pisteAsturias('Externe2');
    externeAvecFiche.RecordTypeId = typePiste('RESIDENTIEL_REGIES');

    Test.startTest();
    insert new List<Lead>{
      interneSansFiche,
      externeSansFiche,
      externeAvecFiche
    };
    // La fiche prévisite est soumise à des règles de validation : calcul testé sans enregistrer.
    new SimulationRES060PisteService()
      .traiter(
        new List<Lead>{ interneFichePrevisite, interneAutreFiche },
        null
      );
    Test.stopTest();

    Assert.isNull(
      relire(interneSansFiche.Id).RES060_Statut__c,
      'interne sans fiche RES060 : pas de calcul'
    );
    Assert.areEqual(
      5.0,
      interneFichePrevisite.RES060_Indice__c,
      'fiche prévisite RES-060 : calcul'
    );
    Assert.isNull(
      interneAutreFiche.RES060_Statut__c,
      'autre fiche : pas de calcul'
    );
    Assert.isNull(
      relire(externeSansFiche.Id).RES060_Statut__c,
      'externe sans fiche : pas de calcul'
    );
    Assert.areEqual(
      5.0,
      relire(externeAvecFiche.Id).RES060_Indice__c,
      'externe avec fiche RES060 : calcul'
    );
  }

  @IsTest
  static void ficheRetireeVideLesCases() {
    Test.setMock(HttpCalloutMock.class, new BouchonCallout());
    Lead p = pisteAsturias('Retrait');
    insert p;

    Test.startTest();
    update new Lead(Id = p.Id, TypeDeDossier__c = null);
    Test.stopTest();

    Lead lu = relire(p.Id);
    Assert.isNull(lu.RES060_Indice__c, 'indice effacé');
    Assert.isNull(lu.RES060_Statut__c, 'statut effacé');
  }

  @IsTest
  static void pacDejaInstalleeEtBonoInconnu() {
    Test.setMock(HttpCalloutMock.class, new BouchonCallout());
    Lead pac = pisteAsturias('Pac');
    pac.Type_de_Chauffage__c = '⚡PAC Air/Eau';
    Lead bono = pisteAsturias('Bono');
    bono.RES_Bono_Social__c = 'Je ne sais pas';
    bono.RES060__c = 'No lo sé';

    insert new List<Lead>{ pac, bono };

    Assert.areEqual(
      SimulationRES060PisteService.NON_ELIGIBLE_PAC,
      relire(pac.Id).RES060_Statut__c,
      'PAC'
    );
    Lead lu = relire(bono.Id);
    Assert.areEqual(5.0, lu.RES060_Indice__c, 'bono inconnu calculé à Non');
    Assert.isTrue(
      lu.RES060_Statut__c.endsWith(SimulationRES060PisteService.BONO_INCONNU),
      'avertissement bono'
    );
  }

  @IsTest
  static void calculEnMasse() {
    Test.setMock(HttpCalloutMock.class, new BouchonCallout());
    List<Lead> lot = new List<Lead>();
    for (Integer i = 0; i < 200; i++) {
      lot.add(pisteAsturias('Masse' + i));
    }

    Test.startTest();
    insert lot;
    Test.stopTest();

    for (Lead l : [SELECT RES060_Indice__c FROM Lead WHERE Id IN :lot]) {
      Assert.areEqual(5.0, l.RES060_Indice__c, 'chaque piste est calculée');
    }
  }

  @IsTest
  static void lectureDesValeurs() {
    Assert.areEqual(
      1985,
      SimulationRES060PisteService.annee(' 1985 '),
      'année simple'
    );
    Assert.areEqual(
      1998,
      SimulationRES060PisteService.annee('Antes de 1998'),
      'année dans une phrase'
    );
    Assert.isNull(
      SimulationRES060PisteService.annee('No lo sé'),
      'pas d\'année'
    );
    Assert.isNull(SimulationRES060PisteService.annee(null), 'vide');

    Assert.areEqual(
      'Fioul',
      SimulationRES060PisteService.typeChaudiere('⛽Fioul'),
      'fioul'
    );
    Assert.areEqual(
      'Gaz',
      SimulationRES060PisteService.typeChaudiere('♨️Gaz'),
      'gaz'
    );
    Assert.areEqual(
      'Bois',
      SimulationRES060PisteService.typeChaudiere('🪵Bois'),
      'bois'
    );
    Assert.areEqual(
      'Electrique',
      SimulationRES060PisteService.typeChaudiere('⚡Electricité'),
      'électrique'
    );
    Assert.areEqual(
      'PAC',
      SimulationRES060PisteService.typeChaudiere('⚡PAC Air/Eau'),
      'pac'
    );
    Assert.areEqual(
      'Charbon',
      SimulationRES060PisteService.typeChaudiere('Carbón'),
      'charbon'
    );
    Assert.isNull(
      SimulationRES060PisteService.typeChaudiere('Autre'),
      'inconnu'
    );

    Assert.areEqual(
      true,
      SimulationRES060PisteService.bonoSocial('✅Oui', null),
      'oui confirmé'
    );
    Assert.areEqual(
      false,
      SimulationRES060PisteService.bonoSocial('❌Non', 'Sí'),
      'le confirmé prime'
    );
    Assert.areEqual(
      true,
      SimulationRES060PisteService.bonoSocial(null, 'Sí'),
      'formulaire oui'
    );
    Assert.areEqual(
      false,
      SimulationRES060PisteService.bonoSocial(null, 'no'),
      'formulaire non'
    );
    Assert.isNull(
      SimulationRES060PisteService.bonoSocial(null, 'no_lo_sé'),
      'ne sait pas'
    );
    Assert.isNull(SimulationRES060PisteService.bonoSocial(null, null), 'vide');
  }

  @IsTest
  static void rechercheDeProvince() {
    SimulationRES060Service s = new SimulationRES060Service();

    Assert.areEqual(
      'Navarra',
      s.trouverProvince(new List<String>{ 'CP 31580' }, null),
      'code postal avec texte'
    );
    Assert.areEqual(
      'Albacete',
      s.trouverProvince(new List<String>{ '2500' }, null),
      'zéro de tête perdu'
    );
    Assert.areEqual(
      'León',
      s.trouverProvince(
        new List<String>{ null },
        new List<String>{
          'AV VILLAFRANCA 107 24300 BEMBIBRE (BEMBIBRE) (LEÓN)'
        }
      ),
      'code postal dans l\'adresse'
    );
    Assert.areEqual(
      'Navarra',
      s.trouverProvince(
        null,
        new List<String>{ 'CL SAN ANDRES / SAN ANDRES KALEA, 16  Navarra' }
      ),
      'nom de province seul'
    );
    Assert.areEqual(
      'Bizkaia',
      s.trouverProvince(
        null,
        new List<String>{ 'Calle Mayor 3, Getxo, Vizcaya' }
      ),
      'autre nom de la province'
    );
    Assert.isNull(
      s.trouverProvince(null, new List<String>{ 'Rue inconnue' }),
      'introuvable'
    );
  }

  @IsTest
  static void erreurPendantLeCalculNeBloquePasLaPiste() {
    Test.setMock(HttpCalloutMock.class, new BouchonCallout());
    SimulationRES060PisteService.simulerErreurPiste = true;
    Lead p = pisteAsturias('Erreur');

    Test.startTest();
    Database.SaveResult r = Database.insert(p, false);
    Test.stopTest();

    Assert.isTrue(r.isSuccess(), 'la piste est enregistrée malgré l\'erreur');
    Lead lu = relire(p.Id);
    Assert.isTrue(
      lu.RES060_Statut__c.startsWith(
        SimulationRES060PisteService.ERREUR_CALCUL
      ),
      'statut erreur de calcul'
    );
    Assert.isNull(lu.RES060_Indice__c, 'pas d\'indice');
  }

  @IsTest
  static void erreurAvantLeCalculNeBloquePasLaPiste() {
    Test.setMock(HttpCalloutMock.class, new BouchonCallout());
    SimulationRES060PisteService.simulerErreurGlobale = true;
    Lead p = pisteAsturias('ErreurGlobale');

    Test.startTest();
    Database.SaveResult r = Database.insert(p, false);
    Test.stopTest();

    Assert.isTrue(r.isSuccess(), 'la piste est enregistrée malgré l\'erreur');
    Assert.isNull(relire(p.Id).RES060_Statut__c, 'rien n\'est écrit');
  }

  @IsTest
  static void pisteAuDelaDe230M2() {
    Test.setMock(HttpCalloutMock.class, new BouchonCallout());
    Lead p = pisteAsturias('Grande');
    p.Surface_habitable__c = 231;

    insert p;

    Lead lu = relire(p.Id);
    Assert.isTrue(lu.RES060_Indice__c != 0, 'indice calculé');
    Assert.isTrue(
      lu.RES060_Statut__c.contains('plus de 230 m²'),
      lu.RES060_Statut__c
    );
    Assert.areEqual(
      '🟨A confirmer- Sans envoi visite',
      lu.RES060_Retour_Calculateur__c,
      'plus de 230 m² : sans envoi visite'
    );
  }

  @IsTest
  static void mitoyenneteEtMaisonApres97() {
    Test.setMock(HttpCalloutMock.class, new BouchonCallout());
    Lead p = pisteAsturias('Mitoyenne');
    p.RES_Anne_maison__c = '1990';
    p.RES060_Mitoyenn__c = SimulationRES060Service.MITOYENNETE_AUCUNE;
    Lead recente = pisteAsturias('Recente');
    recente.RES_Anne_maison__c = '2005';
    insert new List<Lead>{ p, recente };
    Decimal isolee = relire(p.Id).RES060_Indice__c;

    Test.startTest();
    update new Lead(
      Id = p.Id,
      RES060_Mitoyenn__c = SimulationRES060Service.MITOYENNETE_2_COTES
    );
    Test.stopTest();

    Assert.areEqual(0.3, isolee, 'maison isolée');
    Assert.areEqual(
      -0.7,
      relire(p.Id).RES060_Indice__c,
      'recalcul quand la mitoyenneté change (−15 %)'
    );
    Lead lu = relire(recente.Id);
    Assert.isNotNull(lu.RES060_Indice__c, 'maison 2005 : indice calculé');
    Assert.isTrue(lu.RES060_Indice__c < 3, 'indice faible');
    Assert.areEqual(
      '❌Dossier non rentable',
      lu.RES060_Retour_Calculateur__c,
      'indice sous 3 : non rentable'
    );
    Assert.isTrue(
      lu.RES060_Statut__c.contains('maison après 1997'),
      lu.RES060_Statut__c
    );
  }
}
