/**
 * Tests de l'analyse d'une feuille de leads : colonne de résultat, lignes à traiter,
 * point de reprise de la prochaine lecture.
 */
@IsTest
private class RemonteeLeadFeuilleTest {
  private static final List<String> TITRES = new List<String>{
    ' Nom ',
    'Num',
    'Mail',
    'Remonté'
  };

  private static List<String> ligne(String nom, String numero, String statut) {
    return statut == null
      ? new List<String>{ nom, numero, nom + '@exemple.com' }
      : new List<String>{ nom, numero, nom + '@exemple.com', statut };
  }

  @IsTest
  static void retientLesLignesSansResultatEtCellesEnErreur() {
    List<List<String>> lignes = new List<List<String>>{
      ligne('a', '600000001', 'OK – 20/11/2026 10:00 – 00Q000000000001'),
      ligne('b', '600000002', null),
      ligne(
        'c',
        '600000003',
        'DOUBLON – contact déjà connu depuis le 12/11/2026, non remonté'
      ),
      ligne('d', '600000004', 'ERREUR – tentative 2 – règle de validation'),
      ligne('e', '600000005', 'ERREUR DÉFINITIVE – règle de validation'),
      ligne('f', '600000006', 'FAUX NUMÉRO – numéro inventé'),
      ligne('g', '600000007', '')
    };

    RemonteeLeadFeuille.Lecture lecture = RemonteeLeadFeuille.analyser(
      TITRES,
      lignes,
      2,
      1,
      'remonté',
      10
    );

    Assert.areEqual(3, lecture.rangColonneStatut, 'colonne D');
    Assert.isFalse(lecture.colonneStatutACreer);
    Assert.areEqual(3, lecture.aTraiter.size(), 'b, d et g');
    Assert.areEqual(3, lecture.aTraiter[0].numero);
    Assert.areEqual(0, lecture.aTraiter[0].tentatives);
    Assert.areEqual(
      'b',
      lecture.aTraiter[0].valeurs.get('nom'),
      'titre normalisé'
    );
    Assert.areEqual('600000002', lecture.aTraiter[0].valeurs.get('num'));
    Assert.isFalse(
      lecture.aTraiter[0].valeurs.containsKey('remonté'),
      'la colonne de résultat n’est pas une donnée'
    );
    Assert.areEqual(5, lecture.aTraiter[1].numero);
    Assert.areEqual(2, lecture.aTraiter[1].tentatives);
    Assert.areEqual(8, lecture.aTraiter[2].numero);
    Assert.areEqual(
      3,
      lecture.premiereLigneNonTerminee,
      'reprise à la ligne de b'
    );
    Assert.isFalse(lecture.resteDesLignes);
  }

  @IsTest
  static void limiteALaCapaciteEtSignaleLeReste() {
    List<List<String>> lignes = new List<List<String>>();
    for (Integer i = 0; i < 5; i++) {
      lignes.add(ligne('n' + i, '60000000' + i, null));
    }

    RemonteeLeadFeuille.Lecture lecture = RemonteeLeadFeuille.analyser(
      TITRES,
      lignes,
      2,
      1,
      'Remonté',
      2
    );

    Assert.areEqual(2, lecture.aTraiter.size());
    Assert.isTrue(lecture.resteDesLignes);
    Assert.areEqual(2, lecture.premiereLigneNonTerminee);
  }

  @IsTest
  static void colonneDeResultatAbsenteCreeeApresLeDernierTitre() {
    RemonteeLeadFeuille.Lecture lecture = RemonteeLeadFeuille.analyser(
      new List<String>{ 'Nom', 'Num', 'Mail' },
      new List<List<String>>{ ligne('a', '600000001', null) },
      2,
      1,
      'Remonté',
      10
    );

    Assert.isTrue(lecture.colonneStatutACreer);
    Assert.areEqual(3, lecture.rangColonneStatut);
    Assert.areEqual(1, lecture.aTraiter.size());
  }

  @IsTest
  static void toutEstTermineLaRepriseSuitLaDerniereLigne() {
    List<List<String>> lignes = new List<List<String>>{
      ligne('a', '600000001', 'OK – 20/11/2026 10:00 – 00Q000000000001'),
      ligne('b', '600000002', 'OK – 20/11/2026 10:01 – 00Q000000000002')
    };

    RemonteeLeadFeuille.Lecture lecture = RemonteeLeadFeuille.analyser(
      TITRES,
      lignes,
      7,
      1,
      'Remonté',
      10
    );

    Assert.isTrue(lecture.aTraiter.isEmpty());
    Assert.areEqual(9, lecture.premiereLigneNonTerminee);
  }

  @IsTest
  static void ignoreLesTitresLesLignesVidesEtLesFeuillesVides() {
    List<List<String>> lignes = new List<List<String>>{
      TITRES,
      new List<String>(),
      new List<String>{ '', ' ', '' },
      ligne('a', '600000001', null)
    };

    RemonteeLeadFeuille.Lecture lecture = RemonteeLeadFeuille.analyser(
      TITRES,
      lignes,
      1,
      1,
      'Remonté',
      10
    );
    Assert.areEqual(1, lecture.aTraiter.size(), 'seule la vraie ligne compte');
    Assert.areEqual(4, lecture.aTraiter[0].numero);

    RemonteeLeadFeuille.Lecture vide = RemonteeLeadFeuille.analyser(
      TITRES,
      new List<List<String>>(),
      1,
      1,
      'Remonté',
      10
    );
    Assert.isTrue(vide.aTraiter.isEmpty());
    Assert.areEqual(2, vide.premiereLigneNonTerminee, 'juste sous les titres');
  }

  @IsTest
  static void resultatsTerminesOuNon() {
    Assert.isFalse(RemonteeLeadFeuille.estTerminee(null));
    Assert.isFalse(RemonteeLeadFeuille.estTerminee('  '));
    Assert.isFalse(RemonteeLeadFeuille.estTerminee('ERREUR – tentative 1 – x'));
    Assert.isTrue(RemonteeLeadFeuille.estTerminee('ERREUR DÉFINITIVE – x'));
    Assert.isTrue(
      RemonteeLeadFeuille.estTerminee('OK – 20/11/2026 10:00 – 00Q')
    );
    Assert.isTrue(
      RemonteeLeadFeuille.estTerminee(
        'doublon – déjà envoyé le 12/11/2026 (ligne 4)'
      )
    );
    Assert.isTrue(
      RemonteeLeadFeuille.estTerminee('traité à la main'),
      'un texte saisi par une personne vaut résultat'
    );

    Assert.areEqual(0, RemonteeLeadFeuille.tentatives(null));
    Assert.areEqual(1, RemonteeLeadFeuille.tentatives('ERREUR – x'));
    Assert.areEqual(
      4,
      RemonteeLeadFeuille.tentatives('ERREUR – tentative 4 – x')
    );
    Assert.areEqual('nom', RemonteeLeadFeuille.normaliser('  NOM '));
    Assert.areEqual('', RemonteeLeadFeuille.normaliser(null));
  }
}
