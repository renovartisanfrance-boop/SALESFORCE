/**
 * Appels à Google Sheets au nom du compte de service (le « robot »).
 *
 * Authentification : OAuth 2 « JWT bearer ». La demande de jeton est signée par un certificat
 * conservé dans Salesforce (Configuration > Gestion des certificats et des clés) ; seule sa partie
 * publique est déclarée chez Google. Aucune clé secrète n'est donc stockée dans le code, le dépôt
 * ou un champ.
 *
 * Une instance garde son jeton le temps de la transaction : un seul appel de jeton par passage.
 * Les adresses Google sont publiques et fixes ; elles sont autorisées par les sites distants
 * Google_OAuth2 et Google_Sheets.
 */
public with sharing class GoogleSheetsClient {
  public class GoogleSheetsException extends Exception {
  }

  @TestVisible
  private static final String URL_JETON = 'https://oauth2.googleapis.com/token';
  @TestVisible
  private static final String URL_FEUILLES = 'https://sheets.googleapis.com/v4/spreadsheets/';
  private static final String PORTEE = 'https://www.googleapis.com/auth/spreadsheets';
  private static final String TYPE_ACCORD = 'urn:ietf:params:oauth:grant-type:jwt-bearer';
  private static final Integer DUREE_JETON_SECONDES = 3600;
  private static final Integer DELAI_MAX_MS = 60000;
  private static final String ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

  private final RemonteeLeadReglage reglage;
  private String jetonCourant;

  public GoogleSheetsClient(RemonteeLeadReglage reglage) {
    this.reglage = reglage;
  }

  // ------------------------------------------------------------ Jeton

  /** Jeton d'accès Google, demandé une seule fois par instance. */
  public String jeton() {
    if (jetonCourant != null) {
      return jetonCourant;
    }
    if (
      String.isBlank(reglage.emailCompteService) ||
      String.isBlank(reglage.nomCertificat)
    ) {
      throw new GoogleSheetsException(
        'Réglage incomplet : e-mail du compte de service ou nom du certificat manquant.'
      );
    }
    HttpRequest requete = new HttpRequest();
    requete.setEndpoint(URL_JETON);
    requete.setMethod('POST');
    requete.setTimeout(DELAI_MAX_MS);
    requete.setHeader('Content-Type', 'application/x-www-form-urlencoded');
    requete.setBody(
      'grant_type=' +
        EncodingUtil.urlEncode(TYPE_ACCORD, 'UTF-8') +
        '&assertion=' +
        assertion()
    );
    Map<String, Object> corps = envoyer(requete, 'demande de jeton');
    jetonCourant = (String) corps.get('access_token');
    if (String.isBlank(jetonCourant)) {
      throw new GoogleSheetsException('Google n’a renvoyé aucun jeton.');
    }
    return jetonCourant;
  }

  /** Demande signée : en-tête.contenu.signature, chaque partie en base64 « URL ». */
  @TestVisible
  private String assertion() {
    Long maintenant = DateTime.now().getTime() / 1000;
    Map<String, Object> contenu = new Map<String, Object>{
      'iss' => reglage.emailCompteService,
      'scope' => PORTEE,
      'aud' => URL_JETON,
      'iat' => maintenant,
      'exp' => maintenant + DUREE_JETON_SECONDES
    };
    String aSigner =
      base64Url(Blob.valueOf('{"alg":"RS256","typ":"JWT"}')) +
      '.' +
      base64Url(Blob.valueOf(JSON.serialize(contenu)));
    // En test, aucun certificat n'existe : la signature est remplacée par une valeur fixe.
    Blob signature = Test.isRunningTest()
      ? Blob.valueOf('signature-de-test')
      : Crypto.signWithCertificate(
          'RSA-SHA256',
          Blob.valueOf(aSigner),
          reglage.nomCertificat
        );
    return aSigner + '.' + base64Url(signature);
  }

  @TestVisible
  private static String base64Url(Blob donnees) {
    return EncodingUtil.base64Encode(donnees)
      .replace('+', '-')
      .replace('/', '_')
      .replace('=', '');
  }

  // ------------------------------------------------------------ Lecture

  /**
   * Lit plusieurs plages d'un classeur en un seul appel (values.batchGet).
   * Résultat dans l'ordre des plages demandées : plage → lignes → cellules (texte affiché).
   * Google n'envoie ni les lignes vides de fin ni les cellules vides de fin de ligne.
   */
  public List<List<List<String>>> lirePlages(
    String idClasseur,
    List<String> plages
  ) {
    String url =
      URL_FEUILLES +
      EncodingUtil.urlEncode(idClasseur, 'UTF-8') +
      '/values:batchGet?majorDimension=ROWS&valueRenderOption=FORMATTED_VALUE';
    for (String plage : plages) {
      url += '&ranges=' + EncodingUtil.urlEncode(plage, 'UTF-8');
    }
    HttpRequest requete = new HttpRequest();
    requete.setEndpoint(url);
    requete.setMethod('GET');
    requete.setTimeout(DELAI_MAX_MS);
    requete.setHeader('Authorization', 'Bearer ' + jeton());
    Map<String, Object> corps = envoyer(requete, 'lecture de la feuille');

    List<List<List<String>>> resultat = new List<List<List<String>>>();
    List<Object> blocs = (List<Object>) corps.get('valueRanges');
    for (Integer i = 0; i < plages.size(); i++) {
      List<List<String>> lignes = new List<List<String>>();
      Object bloc = blocs != null && i < blocs.size() ? blocs[i] : null;
      Object valeurs = bloc == null
        ? null
        : ((Map<String, Object>) bloc).get('values');
      if (valeurs != null) {
        for (Object ligne : (List<Object>) valeurs) {
          List<String> cellules = new List<String>();
          for (Object cellule : (List<Object>) ligne) {
            cellules.add(cellule == null ? '' : String.valueOf(cellule));
          }
          lignes.add(cellules);
        }
      }
      resultat.add(lignes);
    }
    return resultat;
  }

  // ------------------------------------------------------------ Écriture

  /** Écrit une valeur par cellule en un seul appel (values.batchUpdate). Clé : plage A1 complète. */
  public void ecrireCellules(String idClasseur, Map<String, String> valeurs) {
    if (valeurs == null || valeurs.isEmpty()) {
      return;
    }
    List<Object> donnees = new List<Object>();
    for (String plage : valeurs.keySet()) {
      donnees.add(
        new Map<String, Object>{
          'range' => plage,
          'values' => new List<Object>{ new List<Object>{ valeurs.get(plage) } }
        }
      );
    }
    HttpRequest requete = new HttpRequest();
    requete.setEndpoint(
      URL_FEUILLES +
        EncodingUtil.urlEncode(idClasseur, 'UTF-8') +
        '/values:batchUpdate'
    );
    requete.setMethod('POST');
    requete.setTimeout(DELAI_MAX_MS);
    requete.setHeader('Authorization', 'Bearer ' + jeton());
    requete.setHeader('Content-Type', 'application/json; charset=UTF-8');
    requete.setBody(
      JSON.serialize(
        new Map<String, Object>{
          'valueInputOption' => 'RAW',
          'data' => donnees
        }
      )
    );
    envoyer(requete, 'écriture dans la feuille');
  }

  // ------------------------------------------------------------ Outils

  /** Plage A1 complète : 'Nom de l''onglet'!A1:ZZ1. */
  public static String plage(String onglet, String zone) {
    return '\'' + onglet.replace('\'', '\'\'') + '\'!' + zone;
  }

  /** Lettre(s) d'une colonne à partir de son rang (0 = A, 25 = Z, 26 = AA). */
  public static String lettreColonne(Integer rang) {
    String lettres = '';
    Integer n = rang + 1;
    while (n > 0) {
      Integer reste = Math.mod(n - 1, 26);
      lettres = ALPHABET.mid(reste, 1) + lettres;
      n = (n - 1 - reste) / 26;
    }
    return lettres;
  }

  /** Rang d'une colonne à partir de ses lettres (A = 0, AA = 26). */
  public static Integer rangColonne(String lettres) {
    Integer n = 0;
    for (Integer i = 0; i < lettres.length(); i++) {
      n = n * 26 + ALPHABET.indexOf(lettres.mid(i, 1).toUpperCase()) + 1;
    }
    return n - 1;
  }

  private Map<String, Object> envoyer(HttpRequest requete, String action) {
    HttpResponse reponse = new Http().send(requete);
    String corps = reponse.getBody();
    if (reponse.getStatusCode() < 200 || reponse.getStatusCode() >= 300) {
      throw new GoogleSheetsException(
        'Refus de Google (' +
          reponse.getStatusCode() +
          ') pour la ' +
          action +
          ' : ' +
          messageErreur(corps)
      );
    }
    return String.isBlank(corps)
      ? new Map<String, Object>()
      : (Map<String, Object>) JSON.deserializeUntyped(corps);
  }

  /** Message lisible tiré de la réponse d'erreur de Google, sinon le début du corps. */
  private static String messageErreur(String corps) {
    if (String.isBlank(corps)) {
      return 'aucun détail';
    }
    try {
      Map<String, Object> contenu = (Map<String, Object>) JSON.deserializeUntyped(
        corps
      );
      Object erreur = contenu.get('error');
      if (erreur instanceof Map<String, Object>) {
        Object message = ((Map<String, Object>) erreur).get('message');
        if (message != null) {
          return String.valueOf(message).left(300);
        }
      }
      Object description = contenu.get('error_description');
      if (description != null) {
        return String.valueOf(description).left(300);
      }
    } catch (Exception e) {
      // Réponse qui n'est pas du JSON : on renvoie son début tel quel.
      System.debug(LoggingLevel.FINE, e.getMessage());
    }
    return corps.left(300);
  }
}
