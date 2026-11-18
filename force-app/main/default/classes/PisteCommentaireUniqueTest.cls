/**
 * Tests du flux PISTE_CommentaireUnique : le commentaire télépro (interne) est recopié
 * dans le commentaire régie (externe), sans jamais écraser un commentaire d'apporteur externe.
 */
@IsTest
private class PisteCommentaireUniqueTest {
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

  private static Lead piste(String nom) {
    return new Lead(
      RecordTypeId = Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName()
        .get('RESIDENTIEL_LEADS')
        .getRecordTypeId(),
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
        Telepro_Commentaire_pour_Confirmateur__c,
        REGIE_Commentaire_Regie__c
      FROM Lead
      WHERE Id = :id
    ];
  }

  @IsTest
  static void creationAvecCommentaireTelepro() {
    Test.setMock(HttpCalloutMock.class, new BouchonCallout());
    Lead p = piste('Interne');
    p.Telepro_Commentaire_pour_Confirmateur__c = 'Rappeler après 18 h';

    Test.startTest();
    insert p;
    Test.stopTest();

    Lead lu = relire(p.Id);
    Assert.areEqual(
      'Rappeler après 18 h',
      lu.REGIE_Commentaire_Regie__c,
      'commentaire télépro recopié dans le commentaire régie'
    );
    Assert.areEqual(
      'Rappeler après 18 h',
      lu.Telepro_Commentaire_pour_Confirmateur__c,
      'commentaire télépro conservé'
    );
  }

  @IsTest
  static void modificationDuCommentaireTelepro() {
    Test.setMock(HttpCalloutMock.class, new BouchonCallout());
    Lead p = piste('Modif');
    p.Telepro_Commentaire_pour_Confirmateur__c = 'Premier commentaire';
    insert p;

    Test.startTest();
    update new Lead(
      Id = p.Id,
      Telepro_Commentaire_pour_Confirmateur__c = 'Commentaire corrigé'
    );
    Test.stopTest();

    Assert.areEqual(
      'Commentaire corrigé',
      relire(p.Id).REGIE_Commentaire_Regie__c,
      'le commentaire régie suit la modification du télépro'
    );
  }

  @IsTest
  static void commentaireExterneJamaisEcrase() {
    Test.setMock(HttpCalloutMock.class, new BouchonCallout());
    Lead p = piste('Externe');
    p.REGIE_Commentaire_Regie__c = 'Texte de l\'apporteur';
    insert p;

    Test.startTest();
    update new Lead(
      Id = p.Id,
      Telepro_Commentaire_pour_Confirmateur__c = 'Commentaire télépro'
    );
    Test.stopTest();

    Lead lu = relire(p.Id);
    Assert.areEqual(
      'Texte de l\'apporteur',
      lu.REGIE_Commentaire_Regie__c,
      'le commentaire de l\'apporteur externe est conservé'
    );
    Assert.areEqual(
      'Commentaire télépro',
      lu.Telepro_Commentaire_pour_Confirmateur__c,
      'le commentaire télépro est enregistré normalement'
    );
  }

  @IsTest
  static void sansCommentaireTeleproRienNeChange() {
    Test.setMock(HttpCalloutMock.class, new BouchonCallout());
    Lead p = piste('Vide');

    Test.startTest();
    insert p;
    Test.stopTest();

    Assert.isNull(relire(p.Id).REGIE_Commentaire_Regie__c, 'rien à recopier');
  }

  @IsTest
  static void deuxCentsPistes() {
    Test.setMock(HttpCalloutMock.class, new BouchonCallout());
    List<Lead> pistes = new List<Lead>();
    for (Integer i = 0; i < 200; i++) {
      Lead p = piste('Lot' + i);
      p.Telepro_Commentaire_pour_Confirmateur__c = 'Commentaire ' + i;
      pistes.add(p);
    }

    Test.startTest();
    insert pistes;
    Test.stopTest();

    Integer recopies = 0;
    for (Lead l : [
      SELECT
        Telepro_Commentaire_pour_Confirmateur__c,
        REGIE_Commentaire_Regie__c
      FROM Lead
      WHERE Id IN :pistes
    ]) {
      if (
        l.REGIE_Commentaire_Regie__c ==
        l.Telepro_Commentaire_pour_Confirmateur__c
      ) {
        recopies++;
      }
    }
    Assert.areEqual(200, recopies, 'les 200 pistes sont recopiées');
  }
}
