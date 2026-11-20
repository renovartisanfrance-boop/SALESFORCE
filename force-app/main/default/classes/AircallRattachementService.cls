/**
 * Rattache les fiches Aircall à leur client à partir du numéro de l'appelant :
 * piste, opportunité et dossier. Ne remplit que les cases vides, n'écrase rien.
 * Règles : piste convertie en priorité, sinon la plus récente ; dossier le plus récent.
 */
public with sharing class AircallRattachementService {
  private static final Integer NUMEROS_PAR_RECHERCHE = 20;
  private final AircallRattachementSelector selector;

  public AircallRattachementService() {
    this.selector = new AircallRattachementSelector();
  }

  /** Numéro ramené à ses 9 derniers chiffres (06…, +33 6…, 336… donnent le même résultat). */
  public static String normaliser(String telephone) {
    if (String.isBlank(telephone)) {
      return null;
    }
    String chiffres = telephone.replaceAll('[^0-9]', '');
    return chiffres.length() < 9 ? null : chiffres.right(9);
  }

  public void rattacher(Set<Id> ficheIds) {
    Map<Id, String> numeroParFiche = new Map<Id, String>();
    List<Aircall__c> fiches = new List<Aircall__c>();
    for (Aircall__c fiche : selector.fichesParIds(ficheIds)) {
      String numero = normaliser(fiche.Telephone_Client__c);
      Boolean incomplete =
        fiche.Piste__c == null ||
        fiche.Opportunite__c == null ||
        fiche.Dossier__c == null;
      if (numero != null && incomplete) {
        numeroParFiche.put(fiche.Id, numero);
        fiches.add(fiche);
      }
    }
    if (fiches.isEmpty()) {
      return;
    }

    Map<String, Lead> pisteParNumero = new Map<String, Lead>();
    Map<String, Pro__c> dossierParNumero = new Map<String, Pro__c>();
    chercherClients(
      new Set<String>(numeroParFiche.values()),
      pisteParNumero,
      dossierParNumero
    );
    Map<Id, Pro__c> dossierParOpportunite = dossiersDesOpportunites(
      fiches,
      pisteParNumero.values()
    );

    List<Aircall__c> aMettreAJour = new List<Aircall__c>();
    for (Aircall__c fiche : fiches) {
      String numero = numeroParFiche.get(fiche.Id);
      Aircall__c modifiee = completer(
        fiche,
        pisteParNumero.get(numero),
        dossierParNumero.get(numero),
        dossierParOpportunite
      );
      if (modifiee != null) {
        aMettreAJour.add(modifiee);
      }
    }
    enregistrer(aMettreAJour);
  }

  private void chercherClients(
    Set<String> numeros,
    Map<String, Lead> pisteParNumero,
    Map<String, Pro__c> dossierParNumero
  ) {
    List<String> lot = new List<String>();
    List<String> tous = new List<String>(numeros);
    for (Integer i = 0; i < tous.size(); i++) {
      lot.add(tous[i]);
      if (lot.size() < NUMEROS_PAR_RECHERCHE && i < tous.size() - 1) {
        continue;
      }
      List<List<SObject>> resultats = selector.clientsParNumeros(lot);
      lot = new List<String>();
      for (Lead piste : (List<Lead>) resultats[0]) {
        List<String> telephones = new List<String>{
          piste.Phone,
          piste.MobilePhone
        };
        for (String numero : numerosDe(telephones, numeros)) {
          if (meilleurePiste(piste, pisteParNumero.get(numero))) {
            pisteParNumero.put(numero, piste);
          }
        }
      }
      for (Pro__c dossier : (List<Pro__c>) resultats[1]) {
        List<String> telephones = new List<String>{
          dossier.Phone__c,
          dossier.PRO_T_l_phone_Signataire__c
        };
        for (String numero : numerosDe(telephones, numeros)) {
          Pro__c actuel = dossierParNumero.get(numero);
          if (actuel == null || dossier.CreatedDate > actuel.CreatedDate) {
            dossierParNumero.put(numero, dossier);
          }
        }
      }
    }
  }

  /** Numéros recherchés que portent réellement ces champs téléphone (contrôle exact). */
  private static Set<String> numerosDe(
    List<String> telephones,
    Set<String> recherches
  ) {
    Set<String> trouves = new Set<String>();
    for (String telephone : telephones) {
      String numero = normaliser(telephone);
      if (numero != null && recherches.contains(numero)) {
        trouves.add(numero);
      }
    }
    return trouves;
  }

  @TestVisible
  private static Boolean meilleurePiste(Lead candidate, Lead actuelle) {
    if (actuelle == null) {
      return true;
    }
    if (candidate.IsConverted != actuelle.IsConverted) {
      return candidate.IsConverted;
    }
    return candidate.CreatedDate > actuelle.CreatedDate;
  }

  private Map<Id, Pro__c> dossiersDesOpportunites(
    List<Aircall__c> fiches,
    List<Lead> pistes
  ) {
    Set<Id> opportuniteIds = new Set<Id>();
    for (Aircall__c fiche : fiches) {
      if (fiche.Opportunite__c != null) {
        opportuniteIds.add(fiche.Opportunite__c);
      }
    }
    for (Lead piste : pistes) {
      if (piste.ConvertedOpportunityId != null) {
        opportuniteIds.add(piste.ConvertedOpportunityId);
      }
    }
    Map<Id, Pro__c> dossierParOpportunite = new Map<Id, Pro__c>();
    for (Pro__c dossier : selector.dossiersParOpportunites(opportuniteIds)) {
      if (!dossierParOpportunite.containsKey(dossier.Opportunite__c)) {
        dossierParOpportunite.put(dossier.Opportunite__c, dossier);
      }
    }
    return dossierParOpportunite;
  }

  /** Renvoie la fiche avec ses cases vides remplies, ou null s'il n'y a rien à changer. */
  private static Aircall__c completer(
    Aircall__c fiche,
    Lead piste,
    Pro__c dossierDuNumero,
    Map<Id, Pro__c> dossierParOpportunite
  ) {
    Id pisteId = fiche.Piste__c;
    Id opportuniteId = fiche.Opportunite__c;
    Id dossierId = fiche.Dossier__c;

    if (pisteId == null && piste != null) {
      pisteId = piste.Id;
    }
    if (dossierId == null) {
      Pro__c dossier = opportuniteId != null
        ? dossierParOpportunite.get(opportuniteId)
        : null;
      if (dossier == null) {
        dossier = dossierDuNumero;
      }
      if (dossier == null && piste != null) {
        dossier = dossierParOpportunite.get(piste.ConvertedOpportunityId);
      }
      if (dossier != null) {
        dossierId = dossier.Id;
        if (opportuniteId == null) {
          opportuniteId = dossier.Opportunite__c;
        }
      }
    }
    if (opportuniteId == null && piste != null) {
      opportuniteId = piste.ConvertedOpportunityId;
    }

    if (
      pisteId == fiche.Piste__c &&
      opportuniteId == fiche.Opportunite__c &&
      dossierId == fiche.Dossier__c
    ) {
      return null;
    }
    return new Aircall__c(
      Id = fiche.Id,
      Piste__c = pisteId,
      Opportunite__c = opportuniteId,
      Dossier__c = dossierId
    );
  }

  private static void enregistrer(List<Aircall__c> fiches) {
    if (fiches.isEmpty()) {
      return;
    }
    AircallTriggerHandler.enPause = true;
    try {
      // Mode système voulu (automatisme) ; une fiche bloquée par une règle n'empêche pas les autres.
      for (Database.SaveResult resultat : Database.update(fiches, false)) {
        if (!resultat.isSuccess()) {
          System.debug(
            LoggingLevel.WARN,
            'Rattachement Aircall impossible : ' + resultat.getErrors()
          );
        }
      }
    } finally {
      AircallTriggerHandler.enPause = false;
    }
  }
}
