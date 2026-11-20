/**
 * Chaîne de remontée des leads : lit les feuilles Google des Sources actives, crée les pistes
 * (RemonteeLeadService) et écrit le résultat de chaque ligne dans la feuille.
 *
 * Une opération fait toujours, dans cet ordre :
 *   1. les appels à Google : jeton, écriture des résultats de l'opération précédente, lectures ;
 *   2. puis seulement les écritures Salesforce (pistes, rejets, suivi des Sources).
 * Salesforce interdit un appel sortant après une écriture dans la même opération : c'est pourquoi
 * le résultat d'un paquet n'est écrit dans la feuille qu'au début de l'opération suivante.
 *
 * Enchaînement :
 *   - tant qu'il reste des résultats à écrire ou des feuilles à lire, l'opération suivante part
 *     tout de suite ;
 *   - une fois le tour des feuilles terminé, la suivante part après la pause du réglage
 *     (3 minutes par défaut) et recommence un tour complet.
 * RemonteeLeadGardien relance la chaîne si elle s'est arrêtée (erreur de limite, maintenance…).
 *
 * Garde-fous :
 *   - au plus « taille de paquet » lignes par opération, toutes feuilles confondues : les
 *     automatismes des pistes ne voient jamais plus de pistes à la fois ;
 *   - au plus 40 feuilles lues par opération : 1 jeton + 40 écritures + 40 lectures restent sous
 *     la limite de 100 appels sortants ;
 *   - une feuille en erreur (lecture, écriture, configuration) est notée sur sa Source et laissée
 *     de côté jusqu'au tour suivant, sans bloquer les autres.
 * Une Source dont les leads remontent mais où quelque chose manque (tarif, compte de la régie)
 * reçoit une « Alerte », distincte de la « Dernière erreur » qui, elle, signale un arrêt.
 *
 * Rien n'est perdu si l'écriture dans la feuille échoue : la ligne reste sans résultat, elle est
 * relue au tour suivant et reconnue grâce à sa clé (Lead.Ligne_Feuille__c), sans nouvelle piste.
 */
public with sharing class RemonteeLeadQueueable implements Queueable, Database.AllowsCallouts {
  public static final String NOM_CLASSE = 'RemonteeLeadQueueable';
  @TestVisible
  private static final Integer MAX_SOURCES_PAR_OPERATION = 40;

  /** En test, l'opération suivante n'est pas lancée : elle est gardée ici pour être vérifiée. */
  @TestVisible
  private static RemonteeLeadQueueable suivante;
  @TestVisible
  private static Integer pauseSuivante;

  // ---- État transmis d'une opération à la suivante ----
  /** Sources du tour en cours, dans l'ordre ; null = commencer un nouveau tour. */
  @TestVisible
  private List<Id> idsSources;
  /** Rang, dans idsSources, de la prochaine Source à lire. */
  @TestVisible
  private Integer curseur = 0;
  /** Résultats à écrire dans les feuilles : Source → plage A1 → texte. */
  @TestVisible
  private Map<Id, Map<String, String>> ecrituresEnAttente = new Map<Id, Map<String, String>>();
  /** Sources mises de côté jusqu'à la fin du tour. */
  @TestVisible
  private Set<Id> sourcesEnEchec = new Set<Id>();

  // ------------------------------------------------------------ Démarrage

  /** Lance la chaîne si l'interrupteur général est sur « actif » et qu'elle ne tourne pas déjà. */
  public static Boolean demarrerSiArretee() {
    if (!RemonteeLeadReglage.lire().actif) {
      return false;
    }
    if (new RemonteeLeadSelector().travauxEnCours(NOM_CLASSE) > 0) {
      return false;
    }
    System.enqueueJob(new RemonteeLeadQueueable());
    return true;
  }

  // ------------------------------------------------------------ Une opération

  public void execute(QueueableContext contexte) {
    RemonteeLeadReglage reglage = RemonteeLeadReglage.lire();
    if (!reglage.actif) {
      // Interrupteur coupé : la chaîne s'arrête d'elle-même.
      return;
    }
    Boolean resteDuTravail = false;
    try {
      resteDuTravail = traiter(reglage);
    } catch (Exception e) {
      // Erreur inattendue : le tour est abandonné, un nouveau tour repartira après la pause.
      System.debug(
        LoggingLevel.ERROR,
        NOM_CLASSE + ' : ' + e.getMessage() + '\n' + e.getStackTraceString()
      );
      idsSources = null;
    }
    enchainer(resteDuTravail, reglage);
  }

  /** @return vrai s'il reste des résultats à écrire ou des feuilles à lire dans ce tour. */
  private Boolean traiter(RemonteeLeadReglage reglage) {
    RemonteeLeadSelector selector = new RemonteeLeadSelector();
    RemonteeLeadService service = new RemonteeLeadService();

    if (idsSources == null) {
      idsSources = new List<Id>();
      for (Source_Lead__c source : selector.sourcesActives()) {
        idsSources.add(source.Id);
      }
      curseur = 0;
      sourcesEnEchec = new Set<Id>();
    }
    if (idsSources.isEmpty() && ecrituresEnAttente.isEmpty()) {
      return false;
    }

    Set<Id> concernees = new Set<Id>(ecrituresEnAttente.keySet());
    for (
      Integer i = curseur;
      i < idsSources.size() &&
      i < curseur + MAX_SOURCES_PAR_OPERATION;
      i++
    ) {
      concernees.add(idsSources[i]);
    }
    Map<Id, Source_Lead__c> sources = selector.sourcesParId(concernees);
    Map<Id, Source_Lead__c> suivi = new Map<Id, Source_Lead__c>();
    GoogleSheetsClient client = new GoogleSheetsClient(reglage);

    // ---- 1. Appels à Google (aucune écriture Salesforce avant la fin de cette partie) ----
    try {
      client.jeton();
    } catch (Exception e) {
      for (Id idSource : sources.keySet()) {
        suivre(suivi, idSource)
          .Derniere_erreur__c = ('Connexion à Google impossible : ' +
          e.getMessage())
          .left(2000);
      }
      enregistrer(suivi);
      idsSources = null;
      return false;
    }

    ecrireResultats(client, sources, suivi);
    List<RemonteeLeadService.Travail> travaux = new List<RemonteeLeadService.Travail>();
    Map<Id, Integer> rangsColonneStatut = new Map<Id, Integer>();
    lireFeuilles(
      client,
      service,
      sources,
      suivi,
      travaux,
      rangsColonneStatut,
      reglage
    );

    // ---- 2. Écritures Salesforce ----
    RemonteeLeadService.Resultat resultat = service.traiter(travaux, reglage);
    Map<Id, Map<Integer, String>> statuts = resultat.statuts;
    // Ce qui est à corriger sur une Source sans arrêter sa remontée (pas de tarif, compte de la
    // régie introuvable…) et le compte de sa régie, pour le relevé des leads.
    for (Id idSource : resultat.alertes.keySet()) {
      Source_Lead__c ligneSuivi = suivre(suivi, idSource);
      ligneSuivi.Alerte__c = resultat.alertes.get(idSource);
      ligneSuivi.Compte_Regie__c = resultat.comptesRegie.get(idSource);
    }
    for (Id idSource : statuts.keySet()) {
      Source_Lead__c source = sources.get(idSource);
      String colonne = GoogleSheetsClient.lettreColonne(
        rangsColonneStatut.get(idSource)
      );
      for (Integer numero : statuts.get(idSource).keySet()) {
        prevoirEcriture(
          source,
          colonne + numero,
          statuts.get(idSource).get(numero)
        );
      }
    }
    enregistrer(suivi);

    return curseur < idsSources.size() || !ecrituresEnAttente.isEmpty();
  }

  /** Écrit dans les feuilles les résultats calculés par l'opération précédente. */
  private void ecrireResultats(
    GoogleSheetsClient client,
    Map<Id, Source_Lead__c> sources,
    Map<Id, Source_Lead__c> suivi
  ) {
    Map<Id, Map<String, String>> aEcrire = ecrituresEnAttente;
    ecrituresEnAttente = new Map<Id, Map<String, String>>();
    for (Id idSource : aEcrire.keySet()) {
      Source_Lead__c source = sources.get(idSource);
      if (source == null) {
        continue;
      }
      try {
        client.ecrireCellules(source.Spreadsheet_Id__c, aEcrire.get(idSource));
        suivre(suivi, idSource).Derniere_erreur__c = null;
      } catch (Exception e) {
        // Les lignes restent sans résultat : elles seront relues et reconnues au tour suivant.
        sourcesEnEchec.add(idSource);
        suivre(suivi, idSource)
          .Derniere_erreur__c = ('Écriture du résultat impossible (la feuille est-elle partagée en modification avec le compte de service ?) : ' +
          e.getMessage())
          .left(2000);
      }
    }
  }

  /** Lit les feuilles à partir du curseur, jusqu'à remplir le paquet ou atteindre le plafond. */
  private void lireFeuilles(
    GoogleSheetsClient client,
    RemonteeLeadService service,
    Map<Id, Source_Lead__c> sources,
    Map<Id, Source_Lead__c> suivi,
    List<RemonteeLeadService.Travail> travaux,
    Map<Id, Integer> rangsColonneStatut,
    RemonteeLeadReglage reglage
  ) {
    Integer capacite = reglage.taillePaquet;
    // Seules les Sources chargées pour cette opération (voir traiter) peuvent être lues.
    Integer fin = Math.min(
      idsSources.size(),
      curseur + MAX_SOURCES_PAR_OPERATION
    );
    while (curseur < fin && capacite > 0) {
      Id idSource = idsSources[curseur];
      Source_Lead__c source = sources.get(idSource);
      if (source == null || sourcesEnEchec.contains(idSource)) {
        curseur++;
        continue;
      }
      String erreur = service.erreurConfiguration(source);
      if (erreur != null) {
        suivre(suivi, idSource).Derniere_erreur__c = erreur.left(2000);
        curseur++;
        continue;
      }
      try {
        RemonteeLeadFeuille.Lecture lecture = lire(client, source, capacite);
        Source_Lead__c ligneSuivi = suivre(suivi, idSource);
        ligneSuivi.Dernier_passage__c = DateTime.now();
        ligneSuivi.Premiere_ligne_a_traiter__c = lecture.premiereLigneNonTerminee;
        if (lecture.aTraiter.isEmpty() && !lecture.colonneStatutACreer) {
          // Feuille lue et rien à faire : tout va bien pour cette Source.
          ligneSuivi.Derniere_erreur__c = null;
        }
        rangsColonneStatut.put(idSource, lecture.rangColonneStatut);
        if (lecture.colonneStatutACreer) {
          prevoirEcriture(
            source,
            GoogleSheetsClient.lettreColonne(lecture.rangColonneStatut) +
            ligneTitres(source),
            titreColonneStatut(source)
          );
        }
        for (RemonteeLeadFeuille.Ligne ligne : lecture.aTraiter) {
          travaux.add(new RemonteeLeadService.Travail(source, ligne));
        }
        capacite -= lecture.aTraiter.size();
        if (lecture.resteDesLignes) {
          // Paquet plein : on reste sur cette feuille pour l'opération suivante.
          break;
        }
        curseur++;
      } catch (Exception e) {
        sourcesEnEchec.add(idSource);
        Source_Lead__c ligneSuivi = suivre(suivi, idSource);
        ligneSuivi.Derniere_erreur__c = ('Lecture de la feuille impossible : ' +
          e.getMessage())
          .left(2000);
        // La feuille a pu être réorganisée : la prochaine lecture repartira du début.
        ligneSuivi.Premiere_ligne_a_traiter__c = null;
        curseur++;
      }
    }
  }

  /**
   * Lit la ligne des titres et les lignes à partir de la dernière ligne terminée.
   * On repart d'une ligne déjà lue (qui existe donc dans la feuille) : Google refuse une plage
   * qui commence après la dernière ligne de la grille.
   */
  private RemonteeLeadFeuille.Lecture lire(
    GoogleSheetsClient client,
    Source_Lead__c source,
    Integer capacite
  ) {
    Integer titres = ligneTitres(source);
    Integer premiere = source.Premiere_ligne_a_traiter__c == null
      ? titres + 1
      : source.Premiere_ligne_a_traiter__c.intValue();
    Integer debut = Math.max(premiere - 1, titres);
    List<List<List<String>>> lu = client.lirePlages(
      source.Spreadsheet_Id__c,
      new List<String>{
        GoogleSheetsClient.plage(
          source.Onglet__c,
          'A' + titres + ':ZZ' + titres
        ),
        GoogleSheetsClient.plage(source.Onglet__c, 'A' + debut + ':ZZ')
      }
    );
    return RemonteeLeadFeuille.analyser(
      lu[0].isEmpty() ? new List<String>() : lu[0][0],
      lu[1],
      debut,
      titres,
      titreColonneStatut(source),
      capacite
    );
  }

  // ------------------------------------------------------------ Enchaînement

  private void enchainer(Boolean resteDuTravail, RemonteeLeadReglage reglage) {
    RemonteeLeadQueueable prochaine = new RemonteeLeadQueueable();
    prochaine.ecrituresEnAttente = ecrituresEnAttente;
    if (resteDuTravail) {
      prochaine.idsSources = idsSources;
      prochaine.curseur = curseur;
      prochaine.sourcesEnEchec = sourcesEnEchec;
    }
    Integer pause = resteDuTravail ? 0 : reglage.intervalleMinutes;
    if (Test.isRunningTest()) {
      // Un test ne peut pas enchaîner des traitements : il rejoue lui-même l'opération suivante.
      suivante = prochaine;
      pauseSuivante = pause;
      return;
    }
    if (pause > 0) {
      System.enqueueJob(prochaine, pause);
    } else {
      System.enqueueJob(prochaine);
    }
  }

  // ------------------------------------------------------------ Outils

  private void prevoirEcriture(
    Source_Lead__c source,
    String cellule,
    String texte
  ) {
    if (!ecrituresEnAttente.containsKey(source.Id)) {
      ecrituresEnAttente.put(source.Id, new Map<String, String>());
    }
    ecrituresEnAttente.get(source.Id)
      .put(GoogleSheetsClient.plage(source.Onglet__c, cellule), texte);
  }

  private static Source_Lead__c suivre(
    Map<Id, Source_Lead__c> suivi,
    Id idSource
  ) {
    if (!suivi.containsKey(idSource)) {
      suivi.put(idSource, new Source_Lead__c(Id = idSource));
    }
    return suivi.get(idSource);
  }

  /** Met à jour le suivi des Sources ; un échec sur l'une ne bloque pas les autres. */
  private static void enregistrer(Map<Id, Source_Lead__c> suivi) {
    if (!suivi.isEmpty()) {
      Database.update(suivi.values(), false, AccessLevel.SYSTEM_MODE);
    }
  }

  private static Integer ligneTitres(Source_Lead__c source) {
    return source.Ligne_entete__c == null ||
      source.Ligne_entete__c < 1
      ? 1
      : source.Ligne_entete__c.intValue();
  }

  private static String titreColonneStatut(Source_Lead__c source) {
    return String.isBlank(source.Colonne_Remonte__c)
      ? 'Remonté'
      : source.Colonne_Remonte__c;
  }
}
