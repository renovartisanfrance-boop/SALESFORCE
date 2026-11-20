/**
 * Transforme des lignes de feuilles Google en pistes, selon la configuration de leur Source.
 *
 * Pour chaque ligne, dans l'ordre :
 *  1. ni téléphone valable ni e-mail valable → « FAUX NUMÉRO », pas de piste ;
 *  2. ligne déjà remontée (clé Ligne_Feuille__c) → « OK » avec la piste d'origine, sans rien créer ;
 *  3. personne déjà envoyée dans la MÊME feuille (piste créée depuis cette Source, ligne déjà
 *     rejetée, ou ligne plus haut dans le même paquet) → « DOUBLON – déjà envoyé le … (ligne N) »,
 *     toujours, quel que soit le délai. Ni payé au fournisseur, ni facturé à la régie ;
 *  4. personne déjà connue AILLEURS (« doublon interne ») :
 *       - piste non convertie qui a eu une activité depuis moins de N jours (réglage, 14 par défaut ;
 *         activité = le plus récent entre création, dernière tâche ou appel, dernière modification) ;
 *       - ou dossier dont « RDV- Statut Dossier » n'est pas le statut « annulé » du réglage ;
 *     → « DOUBLON – contact déjà connu depuis le …, non remonté » : ni fournisseur, ni régie, ni nom
 *     dans la feuille. Payé au fournisseur, non facturé à la régie ;
 *  5. sinon la piste est créée, avec sa régie (« Campagne (REGIE) »), sa source, son code
 *     fournisseur et ses prix (LeadPrixService). Téléphone inutilisable mais e-mail valable : créée
 *     quand même, cochée « Faux numéro », jamais facturée à la régie.
 * Une piste refusée par Salesforce (règle de validation…) n'empêche pas les autres : sa ligne
 * reçoit « ERREUR » et sera retentée, jusqu'au nombre de tentatives du réglage.
 * Doublons, faux numéros et erreurs sont historisés dans Rejet_Lead__c, avec ce qui est dû au
 * fournisseur.
 *
 * Aucun appel sortant ici : la lecture et l'écriture des feuilles sont faites par
 * RemonteeLeadQueueable, avant et après cette classe.
 *
 * Écritures en mode système : ce traitement tourne sans utilisateur à l'écran, pour le compte de
 * l'entreprise, et doit remplir ses champs techniques quel que soit le profil de celui qui a
 * lancé la chaîne.
 */
public with sharing class RemonteeLeadService {
  public static final String MOTIF_DOUBLON_FEUILLE = 'Doublon même feuille';
  public static final String MOTIF_DOUBLON_INTERNE = 'Doublon interne';
  public static final String MOTIF_FAUX_NUMERO = 'Faux numéro';
  public static final String MOTIF_ERREUR = 'Erreur';
  public static final String ORIGINE_PAR_DEFAUT = 'LEADS';
  public static final String COLONNE_PRIX_PAR_DEFAUT = 'Prix';
  public static final String ECART_DE_PRIX = 'ÉCART DE PRIX';
  private static final String FORMAT_DATE = 'dd/MM/yyyy';
  private static final String FORMAT_DATE_HEURE = 'dd/MM/yyyy HH:mm';
  private static final String FUSEAU = 'Europe/Paris';
  private static final String SEP = RemonteeLeadFeuille.SEPARATEUR;
  private static final Set<String> VALEURS_VRAIES = new Set<String>{
    'true',
    '1',
    'oui',
    'si',
    'sí',
    'yes',
    'x'
  };

  /** En test seulement : date et heure « actuelles », pour vérifier la règle des 14 jours. */
  @TestVisible
  private static DateTime maintenantForce;

  /** Une ligne à traiter et la Source dont elle vient. */
  public class Travail {
    public Source_Lead__c source;
    public RemonteeLeadFeuille.Ligne ligne;
    public Travail(Source_Lead__c source, RemonteeLeadFeuille.Ligne ligne) {
      this.source = source;
      this.ligne = ligne;
    }
  }

  /** Ce que le traitement d'un paquet rend à la chaîne. */
  public class Resultat {
    /** Pour chaque Source, le résultat à écrire dans la feuille par numéro de ligne. */
    public Map<Id, Map<Integer, String>> statuts = new Map<Id, Map<Integer, String>>();
    /** Pour chaque Source du paquet, ce qui est à corriger (null = rien à signaler). */
    public Map<Id, String> alertes = new Map<Id, String>();
    /** Pour chaque Source du paquet, le compte de sa régie quand il est unique. */
    public Map<Id, Id> comptesRegie = new Map<Id, Id>();

    public Boolean isEmpty() {
      return statuts.isEmpty();
    }
  }

  /** Ce qu'on sait d'une ligne pendant son traitement. */
  private class Demande {
    Travail travail;
    String code;
    String nom;
    String telephone;
    String email;
    String motifTelephone;
    String cleTelephone;
    Boolean emailValable;
    /** Clé de la personne : téléphone valable, sinon e-mail valable, sinon null. */
    String identite;
    String cleLigne;
    Decimal prixFeuille;
    LeadPrixService.Prix prix;
    Lead piste;
  }

  /** Personne déjà connue qui fait refuser une ligne. */
  private class Connu {
    DateTime depuis;
    Integer ligne;
    Id idPiste;
    Id idDossier;
    Boolean autreRegie = false;
  }

  /** Tout ce qui est déjà connu des personnes d'un paquet, rangé par clé de personne. */
  private class Connaissances {
    Map<String, List<Lead>> pistes = new Map<String, List<Lead>>();
    Map<String, List<Pro__c>> dossiers = new Map<String, List<Pro__c>>();
    /** Première ligne déjà rejetée par « Source|personne ». */
    Map<String, Rejet_Lead__c> rejets = new Map<String, Rejet_Lead__c>();
  }

  @TestVisible
  private RemonteeLeadSelector selector = new RemonteeLeadSelector();
  @TestVisible
  private LeadPrixService prixService = new LeadPrixService();
  private Map<String, Schema.DescribeFieldResult> descriptions = new Map<String, Schema.DescribeFieldResult>();
  private Map<Id, Map<String, String>> correspondances = new Map<Id, Map<String, String>>();

  // ------------------------------------------------------------ Contrôle de la configuration

  /** Raison pour laquelle une Source ne peut pas être lue, ou null si sa configuration est correcte. */
  public String erreurConfiguration(Source_Lead__c source) {
    if (
      String.isBlank(source.Spreadsheet_Id__c) ||
      String.isBlank(source.Onglet__c)
    ) {
      return 'Identifiant du classeur ou onglet manquant.';
    }
    if (String.isBlank(source.Fournisseur__r?.Code__c)) {
      return 'Le fournisseur n’a pas de code.';
    }
    if (source.Regie__c != null && source.Regie__r?.EstREGIE__c != true) {
      return 'La régie choisie n’est pas une campagne « Est REGIE ».';
    }
    if (
      String.isNotBlank(source.Record_Type_Developer_Name__c) &&
      typeEnregistrement(source.Record_Type_Developer_Name__c) == null
    ) {
      return 'Type d’enregistrement de piste inconnu : ' +
        source.Record_Type_Developer_Name__c;
    }
    Map<String, String> correspondance;
    try {
      correspondance = lireCorrespondance(source);
    } catch (Exception e) {
      return 'Correspondance des colonnes illisible (JSON attendu) : ' +
        e.getMessage();
    }
    if (correspondance.isEmpty()) {
      return 'Correspondance des colonnes vide.';
    }
    Set<String> cibles = new Set<String>();
    for (String champ : correspondance.values()) {
      Schema.DescribeFieldResult description = decrire(champ);
      if (description == null) {
        return 'Champ de piste inconnu dans la correspondance : ' + champ;
      }
      if (!description.isCreateable() || !typeGere(description)) {
        return 'Champ de piste non alimentable : ' + champ;
      }
      cibles.add(champ.toLowerCase());
    }
    if (!cibles.contains('phone') && !cibles.contains('email')) {
      return 'La correspondance doit alimenter le téléphone (Phone) ou l’e-mail (Email).';
    }
    return null;
  }

  // ------------------------------------------------------------ Traitement d'un paquet

  /** Traite un paquet de lignes (toutes sources confondues). */
  public Resultat traiter(List<Travail> travaux, RemonteeLeadReglage reglage) {
    Resultat resultat = new Resultat();
    if (travaux == null || travaux.isEmpty()) {
      return resultat;
    }

    List<Demande> demandes = new List<Demande>();
    Map<Id, Source_Lead__c> sources = new Map<Id, Source_Lead__c>();
    Set<String> clesLigne = new Set<String>();
    Set<String> clesTelephone = new Set<String>();
    Set<String> emails = new Set<String>();
    Set<Id> fournisseurs = new Set<Id>();
    Set<Id> regies = new Set<Id>();
    for (Travail travail : travaux) {
      Demande d = preparer(travail);
      demandes.add(d);
      sources.put(travail.source.Id, travail.source);
      fournisseurs.add(travail.source.Fournisseur__c);
      if (travail.source.Regie__c != null) {
        regies.add(travail.source.Regie__c);
      }
      clesLigne.add(d.cleLigne);
      if (d.cleTelephone != null) {
        clesTelephone.add(d.cleTelephone);
      } else if (d.emailValable) {
        emails.add(d.identite);
      }
    }

    DateTime instant = maintenant();
    prixService.charger(fournisseurs, regies, jourDeParis(instant));
    for (Demande d : demandes) {
      d.prix = prixService.prixDuCouple(
        d.travail.source.Fournisseur__c,
        d.travail.source.Regie__c
      );
    }
    controlerLesSources(sources, regies, resultat, instant);

    Map<String, Lead> dejaRemontees = new Map<String, Lead>();
    for (Lead piste : selector.pistesParLigneFeuille(clesLigne)) {
      dejaRemontees.put(piste.Ligne_Feuille__c.toLowerCase(), piste);
    }
    Connaissances connues = chercher(
      clesTelephone,
      emails,
      sources.keySet(),
      reglage
    );

    DateTime seuil = instant.addDays(-reglage.delaiDoublonJours);
    String horodatage = instant.format(FORMAT_DATE_HEURE, FUSEAU);
    /** Première ligne du paquet par « Source|personne » (pour le doublon de la même feuille). */
    Map<String, Integer> vuesParFeuille = new Map<String, Integer>();
    /** Ligne du paquet qui crée la piste de chaque personne (pour le doublon entre feuilles). */
    Map<String, Demande> creeesDansLePaquet = new Map<String, Demande>();
    List<Demande> creations = new List<Demande>();
    List<Rejet_Lead__c> rejets = new List<Rejet_Lead__c>();

    for (Demande d : demandes) {
      if (d.identite == null) {
        String detail =
          d.motifTelephone +
          SEP +
          'pas d’e-mail valable, non remonté';
        noter(
          resultat,
          d,
          RemonteeLeadFeuille.STATUT_FAUX_NUMERO + SEP + detail
        );
        rejets.add(
          rejet(d, MOTIF_FAUX_NUMERO, null, detail, d.prix.fauxNumerosPayes)
        );
        continue;
      }
      Lead deja = dejaRemontees.get(d.cleLigne.toLowerCase());
      if (deja != null) {
        noter(resultat, d, statutOk(deja.CreatedDate, deja.Id));
        continue;
      }

      String cleFeuille = d.travail.source.Id + '|' + d.identite;
      Connu memeFeuille = dejaDansLaFeuille(
        d,
        connues,
        vuesParFeuille.get(cleFeuille),
        instant
      );
      if (!vuesParFeuille.containsKey(cleFeuille)) {
        vuesParFeuille.put(cleFeuille, d.travail.ligne.numero);
      }
      if (memeFeuille != null) {
        String detail =
          'déjà envoyé le ' +
          memeFeuille.depuis.format(FORMAT_DATE, FUSEAU) +
          (memeFeuille.ligne == null
            ? ''
            : ' (ligne ' + memeFeuille.ligne + ')');
        noter(resultat, d, RemonteeLeadFeuille.STATUT_DOUBLON + SEP + detail);
        rejets.add(rejet(d, MOTIF_DOUBLON_FEUILLE, memeFeuille, detail, false));
        continue;
      }

      Connu ailleurs = dejaConnuAilleurs(
        d,
        connues,
        creeesDansLePaquet.get(d.identite),
        seuil,
        reglage,
        instant
      );
      if (ailleurs != null) {
        // Message neutre : ni fournisseur, ni régie, ni nom. Le détail reste dans Salesforce.
        String detail =
          'contact déjà connu depuis le ' +
          ailleurs.depuis.format(FORMAT_DATE, FUSEAU) +
          ', non remonté';
        noter(resultat, d, RemonteeLeadFeuille.STATUT_DOUBLON + SEP + detail);
        rejets.add(rejet(d, MOTIF_DOUBLON_INTERNE, ailleurs, detail, true));
        continue;
      }

      creeesDansLePaquet.put(d.identite, d);
      d.piste = construire(d);
      creations.add(d);
    }

    creer(creations, resultat, rejets, reglage, horodatage);

    if (!rejets.isEmpty()) {
      // Clé unique par ligne : un rejet retraité est mis à jour, pas dupliqué.
      Database.upsert(
        rejets,
        Rejet_Lead__c.Cle__c,
        false,
        AccessLevel.SYSTEM_MODE
      );
    }
    return resultat;
  }

  /** Crée les pistes sans tout annuler si l'une est refusée, et note le résultat de chacune. */
  private void creer(
    List<Demande> creations,
    Resultat resultat,
    List<Rejet_Lead__c> rejets,
    RemonteeLeadReglage reglage,
    String horodatage
  ) {
    if (creations.isEmpty()) {
      return;
    }
    List<Lead> pistes = new List<Lead>();
    for (Demande d : creations) {
      pistes.add(d.piste);
    }
    List<Database.SaveResult> resultats = Database.insert(
      pistes,
      false,
      AccessLevel.SYSTEM_MODE
    );
    for (Integer i = 0; i < resultats.size(); i++) {
      Demande d = creations[i];
      if (resultats[i].isSuccess()) {
        Id idPiste = resultats[i].getId();
        String ecart = d.piste.Ecart_Prix__c == true
          ? SEP +
            ECART_DE_PRIX +
            ' (feuille ' +
            euros(d.prixFeuille) +
            ' / tarif ' +
            euros(d.prix.achat) +
            ')'
          : '';
        if (d.cleTelephone == null) {
          String detail = 'e-mail seul' + SEP + 'créé le ' + horodatage;
          noter(
            resultat,
            d,
            RemonteeLeadFeuille.STATUT_FAUX_NUMERO +
              SEP +
              detail +
              SEP +
              idPiste +
              ecart
          );
          Rejet_Lead__c fauxNumero = rejet(
            d,
            MOTIF_FAUX_NUMERO,
            null,
            d.motifTelephone +
              SEP +
              'piste créée, joignable par e-mail seulement',
            d.prix.fauxNumerosPayes
          );
          fauxNumero.Piste_creee__c = idPiste;
          rejets.add(fauxNumero);
        } else {
          noter(
            resultat,
            d,
            RemonteeLeadFeuille.STATUT_OK +
              SEP +
              horodatage +
              SEP +
              idPiste +
              ecart
          );
        }
        continue;
      }
      String message = messageErreur(resultats[i]);
      Integer tentative = d.travail.ligne.tentatives + 1;
      Boolean definitive = tentative >= reglage.tentativesMax;
      noter(
        resultat,
        d,
        definitive
          ? RemonteeLeadFeuille.STATUT_ERREUR_DEFINITIVE + SEP + message
          : RemonteeLeadFeuille.STATUT_ERREUR +
            SEP +
            'tentative ' +
            tentative +
            SEP +
            message
      );
      rejets.add(rejet(d, MOTIF_ERREUR, null, message, false));
    }
  }

  // ------------------------------------------------------------ Sources : régie, compte, tarif

  /**
   * Note sur chaque Source du paquet ce qui est à corriger sans arrêter la remontée : pas de régie,
   * compte de la régie introuvable ou en plusieurs exemplaires, pas de tarif. Les leads remontent
   * quand même.
   */
  private void controlerLesSources(
    Map<Id, Source_Lead__c> sources,
    Set<Id> regies,
    Resultat resultat,
    DateTime instant
  ) {
    Map<Id, List<Account>> comptesParRegie = new Map<Id, List<Account>>();
    for (Account compte : selector.comptesParRegie(regies)) {
      if (!comptesParRegie.containsKey(compte.Acces_REGIE__c)) {
        comptesParRegie.put(compte.Acces_REGIE__c, new List<Account>());
      }
      comptesParRegie.get(compte.Acces_REGIE__c).add(compte);
    }
    for (Source_Lead__c source : sources.values()) {
      List<String> messages = new List<String>();
      if (source.Regie__c == null) {
        messages.add(
          'Aucune régie sur cette Source : les leads remontent sans régie et sans prix.'
        );
      } else {
        List<Account> comptes = comptesParRegie.get(source.Regie__c);
        Integer nombre = comptes == null ? 0 : comptes.size();
        if (nombre == 1) {
          resultat.comptesRegie.put(source.Id, comptes[0].Id);
        } else if (nombre == 0) {
          messages.add(
            'Aucun compte ne pointe vers cette régie par « Accès REGIE » : le relevé des leads n’a pas de destinataire.'
          );
        } else {
          messages.add(
            nombre +
            ' comptes pointent vers cette régie par « Accès REGIE » : il en faut un seul pour le relevé des leads.'
          );
        }
        if (
          prixService.tarifDuCouple(source.Fournisseur__c, source.Regie__c) ==
          null
        ) {
          messages.add(
            'Aucun tarif actif pour ce fournisseur et cette régie au ' +
              instant.format(FORMAT_DATE, FUSEAU) +
              ' : les leads remontent « Sans tarif ».'
          );
        }
      }
      resultat.alertes.put(
        source.Id,
        messages.isEmpty() ? null : String.join(messages, ' ').left(2000)
      );
    }
  }

  // ------------------------------------------------------------ Recherche des personnes connues

  /**
   * Rassemble, en un nombre fixe de requêtes, les pistes, dossiers et lignes déjà rejetées qui
   * concernent les personnes du paquet.
   * Le téléphone est cherché de trois façons complémentaires : la clé de comparaison posée par
   * la remontée, les groupes du système de doublons existant, et le numéro brut des anciens
   * enregistrements (que le réglage permet de couper).
   */
  private Connaissances chercher(
    Set<String> clesTelephone,
    Set<String> emails,
    Set<Id> idsSources,
    RemonteeLeadReglage reglage
  ) {
    Connaissances connues = new Connaissances();
    Set<String> numerosBruts = new Set<String>();
    if (reglage.rechercheTelephoneExacte) {
      for (String cle : clesTelephone) {
        numerosBruts.addAll(RemonteeLeadTelephone.variantes(cle));
      }
    }

    // ---- Pistes ----
    Map<Id, Lead> pistes = new Map<Id, Lead>();
    pistes.putAll(selector.pistesParCleTelephone(clesTelephone));
    pistes.putAll(selector.pistesParGroupeDoublon(clesTelephone));
    pistes.putAll(selector.pistesParTelephoneExact(numerosBruts));
    pistes.putAll(selector.pistesParEmail(emails));
    /** Personnes rattachées à chaque opportunité issue d'une piste convertie. */
    Map<Id, Set<String>> personnesParOpportunite = new Map<Id, Set<String>>();
    for (Lead piste : pistes.values()) {
      Set<String> personnes = new Set<String>();
      for (
        String cle : new Set<String>{
          piste.Telephone_Cle__c,
          RemonteeLeadTelephone.cle(piste.Phone),
          RemonteeLeadTelephone.cle(piste.MobilePhone)
        }
      ) {
        if (cle != null && clesTelephone.contains(cle)) {
          personnes.add(cle);
        }
      }
      if (piste.Email != null && emails.contains(piste.Email.toLowerCase())) {
        personnes.add(piste.Email.toLowerCase());
      }
      for (String personne : personnes) {
        if (!connues.pistes.containsKey(personne)) {
          connues.pistes.put(personne, new List<Lead>());
        }
        connues.pistes.get(personne).add(piste);
      }
      if (piste.IsConverted && piste.ConvertedOpportunityId != null) {
        if (
          !personnesParOpportunite.containsKey(piste.ConvertedOpportunityId)
        ) {
          personnesParOpportunite.put(
            piste.ConvertedOpportunityId,
            new Set<String>()
          );
        }
        personnesParOpportunite.get(piste.ConvertedOpportunityId)
          .addAll(personnes);
      }
    }

    // ---- Dossiers ----
    Map<Id, Pro__c> dossiers = new Map<Id, Pro__c>();
    dossiers.putAll(selector.dossiersParGroupeDoublon(clesTelephone));
    dossiers.putAll(selector.dossiersParTelephoneExact(numerosBruts));
    dossiers.putAll(selector.dossiersParEmail(emails));
    dossiers.putAll(
      selector.dossiersParOpportunite(personnesParOpportunite.keySet())
    );
    for (Pro__c dossier : dossiers.values()) {
      Set<String> personnes = new Set<String>();
      String cle = RemonteeLeadTelephone.cle(dossier.Phone__c);
      if (cle != null && clesTelephone.contains(cle)) {
        personnes.add(cle);
      }
      if (
        dossier.Email__c != null &&
        emails.contains(dossier.Email__c.toLowerCase())
      ) {
        personnes.add(dossier.Email__c.toLowerCase());
      }
      if (personnesParOpportunite.containsKey(dossier.Opportunite__c)) {
        personnes.addAll(personnesParOpportunite.get(dossier.Opportunite__c));
      }
      for (String personne : personnes) {
        if (!connues.dossiers.containsKey(personne)) {
          connues.dossiers.put(personne, new List<Pro__c>());
        }
        connues.dossiers.get(personne).add(dossier);
      }
    }

    // ---- Lignes déjà rejetées des mêmes feuilles ----
    for (
      Rejet_Lead__c note : selector.rejetsDejaNotes(
        idsSources,
        clesTelephone,
        emails,
        new Set<String>{
          MOTIF_DOUBLON_FEUILLE,
          MOTIF_DOUBLON_INTERNE,
          MOTIF_FAUX_NUMERO
        }
      )
    ) {
      String personne = note.Telephone_Cle__c != null
        ? note.Telephone_Cle__c
        : (note.Email__c == null ? null : note.Email__c.toLowerCase());
      String cle = note.Source__c + '|' + personne;
      // La requête est triée par numéro de ligne : la première trouvée est la plus haute.
      if (personne != null && !connues.rejets.containsKey(cle)) {
        connues.rejets.put(cle, note);
      }
    }
    return connues;
  }

  /** La personne a-t-elle déjà été envoyée dans la même feuille ? */
  private Connu dejaDansLaFeuille(
    Demande d,
    Connaissances connues,
    Integer ligneDuPaquet,
    DateTime instant
  ) {
    Id idSource = d.travail.source.Id;
    Lead plusAncienne;
    if (connues.pistes.containsKey(d.identite)) {
      for (Lead piste : connues.pistes.get(d.identite)) {
        if (
          piste.Source_Lead__c == idSource &&
          (plusAncienne == null ||
          piste.CreatedDate < plusAncienne.CreatedDate)
        ) {
          plusAncienne = piste;
        }
      }
    }
    Connu connu = new Connu();
    if (plusAncienne != null) {
      connu.depuis = plusAncienne.CreatedDate;
      connu.ligne = numeroDeLigne(plusAncienne.Ligne_Feuille__c);
      connu.idPiste = plusAncienne.Id;
      return connu;
    }
    Rejet_Lead__c note = connues.rejets.get(idSource + '|' + d.identite);
    if (note != null && note.Ligne__c != d.travail.ligne.numero) {
      connu.depuis = note.Date_rejet__c == null ? instant : note.Date_rejet__c;
      connu.ligne = note.Ligne__c == null ? null : note.Ligne__c.intValue();
      return connu;
    }
    if (ligneDuPaquet != null) {
      connu.depuis = instant;
      connu.ligne = ligneDuPaquet;
      return connu;
    }
    return null;
  }

  /** La personne est-elle déjà connue ailleurs, d'une façon qui bloque le nouveau lead ? */
  private Connu dejaConnuAilleurs(
    Demande d,
    Connaissances connues,
    Demande creeeDansLePaquet,
    DateTime seuil,
    RemonteeLeadReglage reglage,
    DateTime instant
  ) {
    Id regie = d.travail.source.Regie__c;
    Lead piste;
    if (connues.pistes.containsKey(d.identite)) {
      for (Lead candidate : connues.pistes.get(d.identite)) {
        // Une piste convertie ne compte plus : c'est son dossier qui décide.
        if (
          !candidate.IsConverted &&
          derniereActivite(candidate) >= seuil &&
          (piste == null ||
          candidate.CreatedDate < piste.CreatedDate)
        ) {
          piste = candidate;
        }
      }
    }
    Connu connu = new Connu();
    if (piste != null) {
      connu.depuis = piste.CreatedDate;
      connu.idPiste = piste.Id;
      connu.autreRegie = estUneAutreRegie(piste.Campagne_REGIE__c, regie);
      return connu;
    }
    Pro__c dossier;
    if (connues.dossiers.containsKey(d.identite)) {
      for (Pro__c candidat : connues.dossiers.get(d.identite)) {
        Boolean annule =
          String.isNotBlank(reglage.statutDossierAnnule) &&
          candidat.PAC_STATUT_DOSSIER__c == reglage.statutDossierAnnule;
        if (
          !annule &&
          (dossier == null ||
          candidat.CreatedDate < dossier.CreatedDate)
        ) {
          dossier = candidat;
        }
      }
    }
    if (dossier != null) {
      connu.depuis = dossier.CreatedDate;
      connu.idDossier = dossier.Id;
      connu.autreRegie = estUneAutreRegie(dossier.Campagne_REGIE__c, regie);
      return connu;
    }
    if (creeeDansLePaquet != null) {
      // Deux feuilles envoient la même personne dans le même paquet : la première ligne la garde.
      connu.depuis = instant;
      connu.autreRegie = estUneAutreRegie(
        creeeDansLePaquet.travail.source.Regie__c,
        regie
      );
      return connu;
    }
    return null;
  }

  /** Dernière activité d'une piste : création, dernière tâche ou appel, dernière modification. */
  @TestVisible
  private static DateTime derniereActivite(Lead piste) {
    DateTime activite = piste.CreatedDate;
    if (
      piste.LastModifiedDate != null &&
      (activite == null ||
      piste.LastModifiedDate > activite)
    ) {
      activite = piste.LastModifiedDate;
    }
    if (piste.LastActivityDate != null) {
      DateTime finDeJournee = DateTime.newInstance(
        piste.LastActivityDate,
        Time.newInstance(23, 59, 59, 0)
      );
      if (activite == null || finDeJournee > activite) {
        activite = finDeJournee;
      }
    }
    return activite;
  }

  private static Boolean estUneAutreRegie(Id regieConnue, Id regieDeLaLigne) {
    return regieConnue != null && regieConnue != regieDeLaLigne;
  }

  /** Numéro de ligne rangé dans une clé « Source|ligne|personne », ou null. */
  private static Integer numeroDeLigne(String cleLigne) {
    if (String.isBlank(cleLigne)) {
      return null;
    }
    List<String> morceaux = cleLigne.split('\\|');
    return morceaux.size() > 1 && morceaux[1].isNumeric()
      ? Integer.valueOf(morceaux[1])
      : null;
  }

  // ------------------------------------------------------------ Préparation d'une ligne

  private Demande preparer(Travail travail) {
    Source_Lead__c source = travail.source;
    Map<String, String> correspondance = lireCorrespondance(source);
    Demande d = new Demande();
    d.travail = travail;
    d.code = source.Fournisseur__r?.Code__c;
    d.nom = valeurDuChamp(travail, correspondance, 'lastname');
    d.telephone = valeurDuChamp(travail, correspondance, 'phone');
    if (String.isBlank(d.telephone)) {
      d.telephone = valeurDuChamp(travail, correspondance, 'mobilephone');
    }
    d.email = valeurDuChamp(travail, correspondance, 'email');
    d.motifTelephone = RemonteeLeadTelephone.motifInvalide(d.telephone);
    d.cleTelephone = d.motifTelephone == null
      ? RemonteeLeadTelephone.cle(d.telephone)
      : null;
    d.emailValable = RemonteeLeadTelephone.emailValide(d.email);
    d.identite = d.cleTelephone != null
      ? d.cleTelephone
      : (d.emailValable ? d.email.trim().toLowerCase() : null);
    d.cleLigne = (source.Id +
      '|' +
      travail.ligne.numero +
      '|' +
      (d.identite == null ? 'x' : d.identite))
      .left(255);
    d.prixFeuille = montant(
      travail.ligne.valeurs.get(
        RemonteeLeadFeuille.normaliser(
          String.isBlank(source.Colonne_Prix__c)
            ? COLONNE_PRIX_PAR_DEFAUT
            : source.Colonne_Prix__c
        )
      )
    );
    return d;
  }

  /** Valeur de la colonne qui alimente ce champ de piste (nom de champ en minuscules). */
  private static String valeurDuChamp(
    Travail travail,
    Map<String, String> correspondance,
    String champ
  ) {
    for (String titre : correspondance.keySet()) {
      if (correspondance.get(titre).toLowerCase() == champ) {
        return travail.ligne.valeurs.get(titre);
      }
    }
    return null;
  }

  /** Correspondance « titre de colonne normalisé → champ de piste » d'une Source. */
  private Map<String, String> lireCorrespondance(Source_Lead__c source) {
    if (correspondances.containsKey(source.Id)) {
      return correspondances.get(source.Id);
    }
    Map<String, String> resultat = new Map<String, String>();
    if (String.isNotBlank(source.Mapping_JSON__c)) {
      Map<String, Object> brut = (Map<String, Object>) JSON.deserializeUntyped(
        source.Mapping_JSON__c
      );
      for (String titre : brut.keySet()) {
        Object champ = brut.get(titre);
        if (champ != null && String.isNotBlank(String.valueOf(champ))) {
          resultat.put(
            RemonteeLeadFeuille.normaliser(titre),
            String.valueOf(champ).trim()
          );
        }
      }
    }
    correspondances.put(source.Id, resultat);
    return resultat;
  }

  /** Montant écrit dans une cellule (« 12 », « 12,50 € »…), ou null s'il est vide ou illisible. */
  @TestVisible
  private static Decimal montant(String cellule) {
    if (String.isBlank(cellule)) {
      return null;
    }
    String chiffres = cellule.replaceAll('[^0-9,.\\-]', '').replace(',', '.');
    try {
      return String.isBlank(chiffres) ? null : Decimal.valueOf(chiffres);
    } catch (Exception e) {
      // Cellule non numérique : pas de comparaison de prix pour cette ligne.
      System.debug(LoggingLevel.FINE, 'Prix illisible : ' + cellule);
      return null;
    }
  }

  // ------------------------------------------------------------ Construction de la piste

  private Lead construire(Demande d) {
    Source_Lead__c source = d.travail.source;
    Map<String, String> correspondance = lireCorrespondance(source);
    Lead piste = new Lead();
    for (String titre : correspondance.keySet()) {
      String valeur = d.travail.ligne.valeurs.get(titre);
      String champ = correspondance.get(titre);
      if (String.isBlank(valeur)) {
        continue;
      }
      // Un e-mail mal formé ferait refuser toute la piste : il n'est pas recopié.
      if (champ.toLowerCase() == 'email' && !d.emailValable) {
        continue;
      }
      affecter(piste, champ, valeur);
    }
    if (String.isBlank(piste.LastName)) {
      piste.LastName = d.emailValable ? d.email.trim().left(80) : '(sans nom)';
    }
    if (String.isNotBlank(source.Record_Type_Developer_Name__c)) {
      piste.RecordTypeId = typeEnregistrement(
        source.Record_Type_Developer_Name__c
      );
    }
    piste.LeadSource = String.isBlank(source.Origine_piste__c)
      ? ORIGINE_PAR_DEFAUT
      : source.Origine_piste__c;
    if (String.isNotBlank(source.Statut_piste__c)) {
      piste.Status = source.Statut_piste__c;
    }
    if (String.isNotBlank(source.Campagne__c)) {
      piste.Origine_de_la_demande__c = source.Campagne__c;
    }
    if (String.isNotBlank(source.Type_de_dossier__c)) {
      piste.TypeDeDossier__c = source.Type_de_dossier__c;
    }
    // La régie est une campagne « Est REGIE » : elle va dans « Campagne (REGIE) », qui suit la
    // piste jusqu'à l'opportunité et au dossier. « LOOKUP-REGIE » n'est pas touché.
    if (source.Regie__c != null) {
      piste.Campagne_REGIE__c = source.Regie__c;
    }
    piste.Source_Lead__c = source.Id;
    piste.Code_Fournisseur__c = d.code;
    piste.Ligne_Feuille__c = d.cleLigne;
    piste.Telephone_Cle__c = d.cleTelephone;
    Boolean fauxNumero = d.cleTelephone == null;
    piste.Faux_Numero__c = fauxNumero;
    // Un faux numéro n'est jamais facturé à la régie ; il n'est payé au fournisseur que si son
    // tarif le prévoit.
    LeadPrixService.poser(
      piste,
      d.prix,
      fauxNumero ? d.prix.fauxNumerosPayes : true,
      !fauxNumero
    );
    piste.Prix_Feuille__c = d.prixFeuille;
    // L'écart ne se juge que contre un prix fixe : un prix provisoire n'est qu'une estimation.
    piste.Ecart_Prix__c =
      d.prixFeuille != null &&
      d.prix.modeAchat == LeadPrixService.MODE_FIXE &&
      d.prix.achat != null &&
      d.prixFeuille != d.prix.achat;
    return piste;
  }

  /** Pose une valeur de la feuille dans un champ, convertie et coupée à la longueur du champ. */
  private void affecter(Lead piste, String champ, String valeur) {
    Schema.DescribeFieldResult description = decrire(champ);
    if (description == null) {
      return;
    }
    String texte = valeur.trim();
    Schema.SoapType nature = description.getSoapType();
    if (nature == Schema.SoapType.BOOLEAN) {
      piste.put(champ, VALEURS_VRAIES.contains(texte.toLowerCase()));
    } else if (
      nature == Schema.SoapType.DOUBLE ||
      nature == Schema.SoapType.INTEGER
    ) {
      try {
        Decimal nombre = Decimal.valueOf(
          texte.replace(' ', '').replace(',', '.')
        );
        if (nature == Schema.SoapType.INTEGER) {
          piste.put(champ, nombre.intValue());
        } else {
          piste.put(champ, nombre);
        }
      } catch (Exception e) {
        // Valeur non numérique : le champ reste vide plutôt que de faire refuser la piste.
        System.debug(LoggingLevel.FINE, champ + ' : ' + e.getMessage());
      }
    } else {
      Integer longueur = description.getLength();
      piste.put(champ, longueur > 0 ? texte.left(longueur) : texte);
    }
  }

  private static Boolean typeGere(Schema.DescribeFieldResult description) {
    Schema.SoapType nature = description.getSoapType();
    return nature == Schema.SoapType.STRING ||
      nature == Schema.SoapType.BOOLEAN ||
      nature == Schema.SoapType.DOUBLE ||
      nature == Schema.SoapType.INTEGER;
  }

  private Schema.DescribeFieldResult decrire(String champ) {
    String cle = champ == null ? '' : champ.trim().toLowerCase();
    if (!descriptions.containsKey(cle)) {
      Schema.SObjectField f = Schema.SObjectType.Lead.fields.getMap().get(cle);
      descriptions.put(cle, f == null ? null : f.getDescribe());
    }
    return descriptions.get(cle);
  }

  private static Id typeEnregistrement(String nomTechnique) {
    Schema.RecordTypeInfo info = Schema.SObjectType.Lead.getRecordTypeInfosByDeveloperName()
      .get(nomTechnique);
    return info == null ? null : info.getRecordTypeId();
  }

  // ------------------------------------------------------------ Résultats et historique

  private static void noter(Resultat resultat, Demande d, String statut) {
    Id idSource = d.travail.source.Id;
    if (!resultat.statuts.containsKey(idSource)) {
      resultat.statuts.put(idSource, new Map<Integer, String>());
    }
    resultat.statuts.get(idSource).put(d.travail.ligne.numero, statut);
  }

  private static String statutOk(DateTime creation, Id idPiste) {
    return RemonteeLeadFeuille.STATUT_OK +
      SEP +
      creation.format(FORMAT_DATE_HEURE, FUSEAU) +
      SEP +
      idPiste;
  }

  /**
   * Ligne d'historique. Une ligne rejetée n'est jamais facturée à la régie ; elle est due au
   * fournisseur pour un doublon interne, et pour un faux numéro si son tarif le prévoit.
   */
  private static Rejet_Lead__c rejet(
    Demande d,
    String motif,
    Connu connu,
    String detail,
    Boolean payeFournisseur
  ) {
    Source_Lead__c source = d.travail.source;
    Boolean paye = payeFournisseur == true;
    return new Rejet_Lead__c(
      Cle__c = d.cleLigne,
      Source__c = source.Id,
      Fournisseur__c = source.Fournisseur__c,
      Regie__c = source.Regie__c,
      Motif__c = motif,
      Telephone__c = d.telephone?.left(40),
      Telephone_Cle__c = d.cleTelephone,
      Email__c = d.email?.left(255),
      Nom__c = d.nom?.left(255),
      Ligne__c = d.travail.ligne.numero,
      Piste_existante__c = connu?.idPiste,
      Dossier_existant__c = connu?.idDossier,
      Connu_autre_regie__c = connu != null && connu.autreRegie,
      Paye_fournisseur__c = paye,
      Facture_regie__c = false,
      Prix_Achat__c = paye ? d.prix.achat : null,
      Statut_Prix__c = paye ? d.prix.statut : null,
      Tarif_Lead__c = d.prix.tarifId,
      Detail__c = detail?.left(2000),
      Date_rejet__c = maintenant()
    );
  }

  /** Message d'erreur Salesforce sur une ligne, court et sans retour à la ligne. */
  private static String messageErreur(Database.SaveResult resultat) {
    List<String> messages = new List<String>();
    for (Database.Error erreur : resultat.getErrors()) {
      messages.add(erreur.getMessage());
    }
    return String.join(messages, ' / ').replaceAll('\\s+', ' ').left(200);
  }

  // ------------------------------------------------------------ Outils

  private static DateTime maintenant() {
    return maintenantForce == null ? DateTime.now() : maintenantForce;
  }

  /** Jour d'arrivée du lead, à l'heure de Paris : c'est lui qui choisit le tarif. */
  private static Date jourDeParis(DateTime instant) {
    return Date.valueOf(instant.format('yyyy-MM-dd', FUSEAU));
  }

  private static String euros(Decimal valeur) {
    if (valeur == null) {
      return '?';
    }
    return valeur.setScale(2, RoundingMode.HALF_UP)
        .stripTrailingZeros()
        .toPlainString()
        .replace('.', ',') + ' €';
  }
}
