/**
 * Aide pour les tests Aircall : la création d'un dossier déclenche un appel vers un service externe
 * (automatisme existant) ; on le simule pour que les tests puissent créer des dossiers.
 */
@IsTest
public class AircallTestSupport implements HttpCalloutMock {
  public static void simulerAppelsExternes() {
    Test.setMock(HttpCalloutMock.class, new AircallTestSupport());
  }

  public HttpResponse respond(HttpRequest requete) {
    HttpResponse reponse = new HttpResponse();
    reponse.setStatusCode(200);
    reponse.setBody('[]');
    return reponse;
  }
}
