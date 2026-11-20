/**
 * Règles sur le téléphone et l'e-mail d'un lead reçu d'un fournisseur.
 *
 * - Clé de comparaison : chiffres seuls, puis les 9 derniers. C'est la même clé que la règle de
 *   doublons existante (DoublonRegle_TelephoneRes060) : « +34 666 66 66 66 », « 34666666666 »
 *   et « 666666666 » sont le même numéro.
 * - Faux numéro : mauvais nombre de chiffres, début ni espagnol ni français, ou numéro inventé.
 *
 * Aucune requête, aucun DML : classe de calcul pur.
 */
public with sharing class RemonteeLeadTelephone {
  private static final Integer LONGUEUR_CLE = 9;
  private static final Set<String> SUITES_INVENTEES = new Set<String>{
    '123456789',
    '987654321',
    '012345678',
    '234567890',
    '098765432'
  };
  private static final Pattern MOTIF_EMAIL = Pattern.compile(
    '^[A-Za-z0-9._%+\\-]+@[A-Za-z0-9\\-]+(\\.[A-Za-z0-9\\-]+)*\\.[A-Za-z]{2,}$'
  );

  /** Chiffres seuls ; chaîne vide si rien d'exploitable. */
  public static String chiffres(String brut) {
    return String.isBlank(brut) ? '' : brut.replaceAll('[^0-9]', '');
  }

  /** Clé de comparaison (9 derniers chiffres), ou null si le numéro est vide. */
  public static String cle(String brut) {
    String c = chiffres(brut);
    if (c.length() == 0) {
      return null;
    }
    return c.length() > LONGUEUR_CLE ? c.right(LONGUEUR_CLE) : c;
  }

  public static Boolean estValide(String brut) {
    return motifInvalide(brut) == null;
  }

  /** Raison pour laquelle le numéro est un faux numéro, ou null s'il est acceptable. */
  public static String motifInvalide(String brut) {
    String c = chiffres(brut);
    if (c.length() == 0) {
      return 'numéro absent';
    }
    if (c.startsWith('00')) {
      c = c.substring(2);
    }
    // Un numéro inventé est signalé comme tel, même si sa forme n'est ni espagnole ni française.
    if (c.length() >= 9 && c.length() <= 12 && estInvente(c.right(9))) {
      return 'numéro inventé';
    }
    String national = numeroNational(c);
    if (national == null) {
      return c.length() < 9 ||
        c.length() > 12
        ? 'nombre de chiffres incorrect (' + c.length() + ')'
        : 'début de numéro ni espagnol ni français';
    }
    return null;
  }

  /** Les 9 chiffres nationaux d'un numéro espagnol ou français, ou null si la forme ne convient pas. */
  private static String numeroNational(String c) {
    Integer longueur = c.length();
    // Espagne : 9 chiffres commençant par 6, 7, 8 ou 9, avec ou sans indicatif 34.
    if (longueur == 9 && '6789'.contains(c.left(1))) {
      return c;
    }
    if (longueur == 11 && c.startsWith('34') && '6789'.contains(c.mid(2, 1))) {
      return c.substring(2);
    }
    // France : 0X XX XX XX XX, 33 X XX XX XX XX ou 33 0X XX XX XX XX.
    if (longueur == 10 && c.startsWith('0') && c.mid(1, 1) != '0') {
      return c.substring(1);
    }
    if (longueur == 11 && c.startsWith('33') && c.mid(2, 1) != '0') {
      return c.substring(2);
    }
    if (longueur == 12 && c.startsWith('330') && c.mid(3, 1) != '0') {
      return c.substring(3);
    }
    return null;
  }

  /** Tous les chiffres identiques (au premier près) ou suite évidente. */
  private static Boolean estInvente(String national) {
    if (SUITES_INVENTEES.contains(national)) {
      return true;
    }
    String reste = national.substring(1);
    return reste.replace(reste.left(1), '').length() == 0;
  }

  public static Boolean emailValide(String email) {
    return String.isNotBlank(email) &&
      email.trim().length() <= 80 &&
      MOTIF_EMAIL.matcher(email.trim()).matches();
  }

  /**
   * Formes sous lesquelles un même numéro est habituellement enregistré.
   * Sert à retrouver les anciennes pistes qui n'ont pas encore de clé de comparaison.
   */
  public static Set<String> variantes(String cle) {
    Set<String> formes = new Set<String>();
    if (String.isBlank(cle)) {
      return formes;
    }
    for (
      String prefixe : new List<String>{
        '',
        '0',
        '34',
        '+34',
        '0034',
        '33',
        '+33',
        '0033'
      }
    ) {
      formes.add(prefixe + cle);
    }
    return formes;
  }
}
