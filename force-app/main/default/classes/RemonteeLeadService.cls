/**
 * Transforme des lignes de feuilles Google en pistes, selon la configuration de leur Source.
 *
 * Pour chaque ligne, dans l'ordre :
 *  1. ni téléphone valable ni e-mail valable → « FAUX NUMÉRO », pas de piste ;
 *  2. ligne déjà remontée (clé Ligne_Feuille__c) → « OK » avec la piste d'origine, sans rien créer ;
 *  3. même personne déjà présente dans les pistes, ou plus haut dans le même paquet → « DOUBLON » ;
 *  4. sinon la piste est créée. Téléphone inutilisable mais e-mail valable : créée quand même,
 *     cochée « Faux numéro ».
 * Une piste refusée par Salesforce (règle de validation…) n'empêche pas les autres : sa ligne
 * reçoit « ERREUR » et sera retentée, jusqu'au nombre de tentatives du réglage.
 * Doublons, faux numéros et erreurs sont historisés dans Rejet_Lead__c.
 *
 * Aucun appel sortant ici : la lecture et l'écriture des feuilles sont faites par
 * RemonteeLeadQueueable, avant et après cette classe.
 *
 * Écritures en mode système : ce traitement tourne sans utilisateur à l'écran, pour le compte de
 * l'entreprise, et doit remplir ses champs techniques quel que soit le profil de celui qui a
 * lancé la chaîne.
 */
public with sharing class RemonteeLeadService {
  public static final String MOTIF_DOUBLON_AUTRE = 'Doublon autre fournisseur';
  public static final String MOTIF_DOUBLON_MEME = 'Doublon même fournisseur';
  public static final String MOTIF_FAUX_NUMERO = 'Faux numéro';
  public static final String MOTIF_ERREUR = 'Erreur';
  private static final String HORS_FOURNISSEURS = 'hors fournisseurs';
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

  /** Une ligne à traiter et la Source dont elle vient. */
  public class Travail {
    public Source_Lead__c source;
    public RemonteeLeadFeuille.Ligne ligne;
    public Travail(Source_Lead__c source, RemonteeLeadFeuille.Ligne ligne) {
      this.source = source;
      this.ligne = ligne;
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
    Lead piste;
  }

  @TestVisible
  private RemonteeLeadSelector selector = new RemonteeLeadSelector();
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

  /**
   * Traite un paquet de lignes (toutes sources confondues).
   * @return pour chaque Source, le résultat à écrire par numéro de ligne.
   */
  public Map<Id, Map<Integer, String>> traiter(
    List<Travail> travaux,
    RemonteeLeadReglage reglage
  ) {
    Map<Id, Map<Integer, String>> statuts = new Map<Id, Map<Integer, String>>();
    if (travaux == null || travaux.isEmpty()) {
      return statuts;
    }

    List<Demande> demandes = new List<Demande>();
    Set<String> clesLigne = new Set<String>();
    Set<String> clesTelephone = new Set<String>();
    Set<String> emails = new Set<String>();
    for (Travail travail : travaux) {
      Demande d = preparer(travail);
      demandes.add(d);
      clesLigne.add(d.cleLigne);
      if (d.cleTelephone != null) {
        clesTelephone.add(d.cleTelephone);
      } else if (d.emailValable) {
        emails.add(d.identite);
      }
    }

    Map<String, Lead> dejaRemontees = new Map<String, Lead>();
    for (Lead piste : selector.pistesParLigneFeuille(clesLigne)) {
      dejaRemontees.put(piste.Ligne_Feuille__c.toLowerCase(), piste);
    }
    Map<String, Lead> presentes = pistesPresentes(
      clesTelephone,
      emails,
      reglage
    );

    String maintenant = DateTime.now().format(FORMAT_DATE_HEURE, FUSEAU);
    Map<String, String> vuesDansLePaquet = new Map<String, String>();
    List<Demande> creations = new List<Demande>();
    List<Rejet_Lead__c> rejets = new List<Rejet_Lead__c>();

    for (Demande d : demandes) {
      if (d.identite == null) {
        String detail =
          d.motifTelephone +
          SEP +
          'pas d’e-mail valable, non remonté';
        noter(
          statuts,
          d,
          RemonteeLeadFeuille.STATUT_FAUX_NUMERO + SEP + detail
        );
        rejets.add(rejet(d, MOTIF_FAUX_NUMERO, null, detail));
        continue;
      }
      Lead deja = dejaRemontees.get(d.cleLigne.toLowerCase());
      if (deja != null) {
        noter(statuts, d, statutOk(deja.CreatedDate, deja.Id));
        continue;
      }
      Lead presente = presentes.get(d.identite);
      if (presente != null) {
        String premier = String.isBlank(presente.Code_Fournisseur__c)
          ? HORS_FOURNISSEURS
          : 'par ' + presente.Code_Fournisseur__c;
        String detail =
          'déjà reçu le ' +
          presente.CreatedDate.format(FORMAT_DATE, FUSEAU) +
          ' ' +
          premier;
        noter(statuts, d, RemonteeLeadFeuille.STATUT_DOUBLON + SEP + detail);
        rejets.add(
          rejet(
            d,
            presente.Code_Fournisseur__c == d.code
              ? MOTIF_DOUBLON_MEME
              : MOTIF_DOUBLON_AUTRE,
            presente.Id,
            detail
          )
        );
        continue;
      }
      if (vuesDansLePaquet.containsKey(d.identite)) {
        String premierCode = vuesDansLePaquet.get(d.identite);
        String detail =
          'déjà reçu le ' +
          DateTime.now().format(FORMAT_DATE, FUSEAU) +
          ' par ' +
          premierCode;
        noter(statuts, d, RemonteeLeadFeuille.STATUT_DOUBLON + SEP + detail);
        rejets.add(
          rejet(
            d,
            premierCode == d.code ? MOTIF_DOUBLON_MEME : MOTIF_DOUBLON_AUTRE,
            null,
            detail
          )
        );
        continue;
      }
      vuesDansLePaquet.put(d.identite, d.code);
      d.piste = construire(d);
      creations.add(d);
    }

    creer(creations, statuts, rejets, reglage, maintenant);

    if (!rejets.isEmpty()) {
      // Clé unique par ligne : un rejet retraité est mis à jour, pas dupliqué.
      Database.upsert(
        rejets,
        Rejet_Lead__c.Cle__c,
        false,
        AccessLevel.SYSTEM_MODE
      );
    }
    return statuts;
  }

  /** Crée les pistes sans tout annuler si l'une est refusée, et note le résultat de chacune. */
  private void creer(
    List<Demande> creations,
    Map<Id, Map<Integer, String>> statuts,
    List<Rejet_Lead__c> rejets,
    RemonteeLeadReglage reglage,
    String maintenant
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
        if (d.cleTelephone == null) {
          String detail = 'e-mail seul' + SEP + 'créé le ' + maintenant;
          noter(
            statuts,
            d,
            RemonteeLeadFeuille.STATUT_FAUX_NUMERO +
              SEP +
              detail +
              SEP +
              idPiste
          );
          rejets.add(
            rejet(
              d,
              MOTIF_FAUX_NUMERO,
              idPiste,
              d.motifTelephone +
                SEP +
                'piste créée, joignable par e-mail seulement'
            )
          );
        } else {
          noter(
            statuts,
            d,
            RemonteeLeadFeuille.STATUT_OK + SEP + maintenant + SEP + idPiste
          );
        }
        continue;
      }
      String message = messageErreur(resultats[i]);
      Integer tentative = d.travail.ligne.tentatives + 1;
      Boolean definitive = tentative >= reglage.tentativesMax;
      noter(
        statuts,
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
      rejets.add(rejet(d, MOTIF_ERREUR, null, message));
    }
  }

  // ------------------------------------------------------------ Recherche des doublons

  /**
   * Piste la plus ancienne déjà présente pour chaque personne (clé de téléphone ou e-mail).
   * Le téléphone est cherché de trois façons complémentaires : la clé de comparaison posée par
   * la remontée, les groupes du système de doublons existant, et le numéro brut des anciennes pistes.
   */
  private Map<String, Lead> pistesPresentes(
    Set<String> clesTelephone,
    Set<String> emails,
    RemonteeLeadReglage reglage
  ) {
    Map<String, Lead> presentes = new Map<String, Lead>();
    if (!clesTelephone.isEmpty()) {
      List<Lead> trouvees = new List<Lead>();
      trouvees.addAll(selector.pistesParCleTelephone(clesTelephone));
      trouvees.addAll(selector.pistesParGroupeDoublon(clesTelephone));
      if (reglage.rechercheTelephoneExacte) {
        Set<String> numeros = new Set<String>();
        for (String cle : clesTelephone) {
          numeros.addAll(RemonteeLeadTelephone.variantes(cle));
        }
        trouvees.addAll(selector.pistesParTelephoneExact(numeros));
      }
      for (Lead piste : trouvees) {
        for (
          String cle : new Set<String>{
            piste.Telephone_Cle__c,
            RemonteeLeadTelephone.cle(piste.Phone),
            RemonteeLeadTelephone.cle(piste.MobilePhone)
          }
        ) {
          if (cle != null && clesTelephone.contains(cle)) {
            garderLaPlusAncienne(presentes, cle, piste);
          }
        }
      }
    }
    for (Lead piste : selector.pistesParEmail(emails)) {
      if (piste.Email != null) {
        garderLaPlusAncienne(presentes, piste.Email.toLowerCase(), piste);
      }
    }
    return presentes;
  }

  private static void garderLaPlusAncienne(
    Map<String, Lead> presentes,
    String cle,
    Lead piste
  ) {
    Lead actuelle = presentes.get(cle);
    if (actuelle == null || piste.CreatedDate < actuelle.CreatedDate) {
      presentes.put(cle, piste);
    }
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
    if (String.isNotBlank(source.Origine_piste__c)) {
      piste.LeadSource = source.Origine_piste__c;
    }
    if (String.isNotBlank(source.Statut_piste__c)) {
      piste.Status = source.Statut_piste__c;
    }
    if (String.isNotBlank(source.Campagne__c)) {
      piste.Origine_de_la_demande__c = source.Campagne__c;
    }
    if (String.isNotBlank(source.Type_de_dossier__c)) {
      piste.TypeDeDossier__c = source.Type_de_dossier__c;
    }
    if (source.Regie__c != null) {
      piste.Regie__c = source.Regie__c;
    }
    piste.Source_Lead__c = source.Id;
    piste.Code_Fournisseur__c = d.code;
    piste.Ligne_Feuille__c = d.cleLigne;
    piste.Telephone_Cle__c = d.cleTelephone;
    piste.Faux_Numero__c = d.cleTelephone == null;
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

  private static void noter(
    Map<Id, Map<Integer, String>> statuts,
    Demande d,
    String statut
  ) {
    Id idSource = d.travail.source.Id;
    if (!statuts.containsKey(idSource)) {
      statuts.put(idSource, new Map<Integer, String>());
    }
    statuts.get(idSource).put(d.travail.ligne.numero, statut);
  }

  private static String statutOk(DateTime creation, Id idPiste) {
    return RemonteeLeadFeuille.STATUT_OK +
      SEP +
      creation.format(FORMAT_DATE_HEURE, FUSEAU) +
      SEP +
      idPiste;
  }

  private static Rejet_Lead__c rejet(
    Demande d,
    String motif,
    Id idPiste,
    String detail
  ) {
    return new Rejet_Lead__c(
      Cle__c = d.cleLigne,
      Source__c = d.travail.source.Id,
      Fournisseur__c = d.travail.source.Fournisseur__c,
      Motif__c = motif,
      Telephone__c = d.telephone?.left(40),
      Email__c = d.email?.left(255),
      Nom__c = d.nom?.left(255),
      Ligne__c = d.travail.ligne.numero,
      Piste_existante__c = idPiste,
      Detail__c = detail?.left(2000),
      Date_rejet__c = DateTime.now()
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
}
