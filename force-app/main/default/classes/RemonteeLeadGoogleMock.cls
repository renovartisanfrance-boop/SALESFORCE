/**
 * Faux Google pour les tests de la remontée des leads : jeton, lecture (values.batchGet) et
 * écriture (values.batchUpdate) sur des feuilles gardées en mémoire.
 *
 * Il se comporte comme Google sur les points dont dépend le code : les écritures modifient la
 * feuille en mémoire, et une lecture qui commence après la dernière ligne est refusée (400).
 * Il répond aussi aux appels sortants des Flows de pistes (géocodage, SMS) pour ne pas les bloquer.
 */
@IsTest
public class RemonteeLeadGoogleMock implements HttpCalloutMock {
  /** Identifiant du classeur → lignes de la feuille (la première est la ligne 1). */
  public Map<String, List<List<String>>> feuilles = new Map<String, List<List<String>>>();
  public Boolean jetonRefuse = false;
  public Boolean lectureRefusee = false;
  public Boolean ecritureRefusee = false;
  public Integer appelsJeton = 0;
  public Integer appelsLecture = 0;
  public Integer appelsEcriture = 0;
  public String dernierCorpsJeton;
  public String dernierJetonPresente;

  private static final Pattern ZONE_LECTURE = Pattern.compile(
    '^A(\\d+):ZZ(\\d*)$'
  );
  private static final Pattern CELLULE = Pattern.compile('^([A-Z]+)(\\d+)$');

  public HttpResponse respond(HttpRequest requete) {
    String url = requete.getEndpoint();
    if (url.startsWith(GoogleSheetsClient.URL_JETON)) {
      appelsJeton++;
      dernierCorpsJeton = requete.getBody();
      return jetonRefuse
        ? reponse(
            400,
            '{"error":"invalid_grant","error_description":"Invalid JWT Signature."}'
          )
        : reponse(
            200,
            '{"access_token":"jeton-de-test","expires_in":3599,"token_type":"Bearer"}'
          );
    }
    if (url.startsWith(GoogleSheetsClient.URL_FEUILLES)) {
      dernierJetonPresente = requete.getHeader('Authorization');
      String idClasseur = url.substringBetween(
        GoogleSheetsClient.URL_FEUILLES,
        '/values'
      );
      if (url.contains('values:batchGet')) {
        appelsLecture++;
        return lectureRefusee
          ? reponse(
              403,
              '{"error":{"code":403,"message":"The caller does not have permission","status":"PERMISSION_DENIED"}}'
            )
          : lire(idClasseur, url);
      }
      appelsEcriture++;
      return ecritureRefusee
        ? reponse(
            403,
            '{"error":{"code":403,"message":"The caller does not have permission","status":"PERMISSION_DENIED"}}'
          )
        : ecrire(idClasseur, requete.getBody());
    }
    // Appels sortants des automatismes de pistes (géocodage, SMS…).
    return reponse(200, url.contains('nominatim') ? '[]' : '{"success":true}');
  }

  /** Texte d'une cellule de la feuille en mémoire (ligne à partir de 1, rang de colonne à partir de 0). */
  public String cellule(String idClasseur, Integer ligne, Integer rangColonne) {
    List<List<String>> lignes = feuilles.get(idClasseur);
    if (lignes == null || ligne > lignes.size()) {
      return null;
    }
    List<String> cellules = lignes[ligne - 1];
    return rangColonne < cellules.size() ? cellules[rangColonne] : null;
  }

  private HttpResponse lire(String idClasseur, String url) {
    List<List<String>> lignes = feuilles.get(idClasseur);
    if (lignes == null) {
      return reponse(
        404,
        '{"error":{"code":404,"message":"Requested entity was not found."}}'
      );
    }
    List<Object> blocs = new List<Object>();
    for (String parametre : url.substringAfter('?').split('&')) {
      if (!parametre.startsWith('ranges=')) {
        continue;
      }
      String plage = EncodingUtil.urlDecode(
        parametre.substringAfter('ranges='),
        'UTF-8'
      );
      Matcher m = ZONE_LECTURE.matcher(plage.substringAfterLast('!'));
      if (!m.matches()) {
        return reponse(
          400,
          '{"error":{"code":400,"message":"Unable to parse range: ' +
            plage.escapeJava() +
            '"}}'
        );
      }
      Integer debut = Integer.valueOf(m.group(1));
      Integer fin = String.isBlank(m.group(2))
        ? lignes.size()
        : Math.min(Integer.valueOf(m.group(2)), lignes.size());
      if (debut > lignes.size()) {
        return reponse(
          400,
          '{"error":{"code":400,"message":"Range exceeds grid limits. Max rows: ' +
            lignes.size() +
            ', max columns: 26"}}'
        );
      }
      List<Object> valeurs = new List<Object>();
      for (Integer i = debut; i <= fin; i++) {
        valeurs.add(lignes[i - 1]);
      }
      Map<String, Object> bloc = new Map<String, Object>{
        'range' => plage,
        'majorDimension' => 'ROWS'
      };
      if (!valeurs.isEmpty()) {
        bloc.put('values', valeurs);
      }
      blocs.add(bloc);
    }
    return reponse(
      200,
      JSON.serialize(
        new Map<String, Object>{
          'spreadsheetId' => idClasseur,
          'valueRanges' => blocs
        }
      )
    );
  }

  private HttpResponse ecrire(String idClasseur, String corps) {
    List<List<String>> lignes = feuilles.get(idClasseur);
    if (lignes == null) {
      lignes = new List<List<String>>();
      feuilles.put(idClasseur, lignes);
    }
    Map<String, Object> contenu = (Map<String, Object>) JSON.deserializeUntyped(
      corps
    );
    List<Object> donnees = (List<Object>) contenu.get('data');
    for (Object element : donnees) {
      Map<String, Object> ecriture = (Map<String, Object>) element;
      String plage = (String) ecriture.get('range');
      Matcher m = CELLULE.matcher(plage.substringAfterLast('!'));
      if (!m.matches()) {
        return reponse(
          400,
          '{"error":{"code":400,"message":"Unable to parse range"}}'
        );
      }
      Integer rang = GoogleSheetsClient.rangColonne(m.group(1));
      Integer ligne = Integer.valueOf(m.group(2));
      while (lignes.size() < ligne) {
        lignes.add(new List<String>());
      }
      List<String> cellules = lignes[ligne - 1];
      while (cellules.size() <= rang) {
        cellules.add('');
      }
      List<Object> valeurs = (List<Object>) ecriture.get('values');
      cellules[rang] = String.valueOf(((List<Object>) valeurs[0])[0]);
    }
    return reponse(
      200,
      '{"spreadsheetId":"' +
        idClasseur +
        '","totalUpdatedCells":' +
        donnees.size() +
        '}'
    );
  }

  private static HttpResponse reponse(Integer code, String corps) {
    HttpResponse r = new HttpResponse();
    r.setStatusCode(code);
    r.setHeader('Content-Type', 'application/json');
    r.setBody(corps);
    return r;
  }
}
