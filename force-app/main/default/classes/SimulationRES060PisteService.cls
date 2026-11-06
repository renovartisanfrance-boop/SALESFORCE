/**
 * Calculateur RES060 sur la Piste (Lead).
 * Appelé par LeadTriggerHandler avant insertion / modification : remplit
 * RES060- Indice, Zone, Statut et Province calculateur, sans DML ni requête.
 *
 * - Périmètre (réglages RES060_Parametre__mdt) : types de piste toujours calculés, et types
 *   calculés seulement avec une fiche RES060 (Type de dossier ou PREVISITE- Fiches Résidentiel).
 * - Recalcul uniquement à la création ou quand une info utilisée par le calculateur change.
 * - Une info manquante donne « Info manquante : … » et pas d'indice.
 */
public with sharing class SimulationRES060PisteService {
  public static final String INFO_MANQUANTE = 'Info manquante : ';
  public static final String NON_ELIGIBLE_PAC = 'Non éligible : déjà équipé d\'une pompe à chaleur';
  public static final String BONO_INCONNU = ' · bono non renseigné (calculé à Non)';

  /** Champs de la Piste lus par le calculateur : un changement relance le calcul. */
  private static final List<Schema.SObjectField> CHAMPS_SUIVIS = new List<Schema.SObjectField>{
    Lead.RecordTypeId,
    Lead.TypeDeDossier__c,
    Lead.PREVISITE_Fiche_Residentiel__c,
    Lead.PostalCode,
    Lead.Street,
    Lead.City,
    Lead.State,
    Lead.REGIE_Adresse_Client__c,
    Lead.Surface_habitable__c,
    Lead.RES_Anne_maison__c,
    Lead.Type_de_Chauffage__c,
    Lead.RES_Ann_e_Chaudi_re__c,
    Lead.RES_Bono_Social__c,
    Lead.RES060__c
  };
  private static final Pattern ANNEE = Pattern.compile(
    '(?<!\\d)((?:18|19|20)\\d{2})(?!\\d)'
  );

  private final SimulationRES060Selector selector;
  private SimulationRES060Service service;

  public SimulationRES060PisteService() {
    this(new SimulationRES060Selector());
  }

  @TestVisible
  private SimulationRES060PisteService(SimulationRES060Selector selector) {
    this.selector = selector;
  }

  /** Point d'entrée du trigger (before insert : anciennes = null). */
  public static void calculer(List<Lead> pistes, Map<Id, Lead> anciennes) {
    new SimulationRES060PisteService().traiter(pistes, anciennes);
  }

  public void traiter(List<Lead> pistes, Map<Id, Lead> anciennes) {
    List<Lead> aTraiter = new List<Lead>();
    for (Lead p : pistes) {
      Lead ancienne = anciennes == null ? null : anciennes.get(p.Id);
      if (ancienne == null || aChange(p, ancienne)) {
        aTraiter.add(p);
      }
    }
    if (aTraiter.isEmpty()) {
      return;
    }
    RES060_Parametre__mdt params = selector.getParametres();
    if (params == null) {
      return;
    }
    Set<String> toujours = liste(params.Pistes_Toujours__c);
    Set<String> avecFiche = liste(params.Pistes_Avec_Fiche__c);
    Set<String> fiches = liste(params.Fiches_RES060__c);
    Map<Id, Schema.RecordTypeInfo> types = Schema.SObjectType.Lead.getRecordTypeInfosById();

    for (Lead p : aTraiter) {
      Schema.RecordTypeInfo type = p.RecordTypeId == null
        ? null
        : types.get(p.RecordTypeId);
      String nomType = type == null ? null : type.getDeveloperName();
      Boolean dansPerimetre =
        toujours.contains(nomType) ||
        (avecFiche.contains(nomType) && aFicheRes060(p, fiches));
      if (dansPerimetre) {
        calculerPiste(p);
      } else if (p.RES060_Statut__c != null || p.RES060_Indice__c != null) {
        vider(p);
      }
    }
  }

  private void calculerPiste(Lead p) {
    if (service == null) {
      service = new SimulationRES060Service(selector);
    }
    vider(p);
    String province = service.trouverProvince(
      new List<String>{ p.PostalCode },
      new List<String>{ p.REGIE_Adresse_Client__c, p.Street, p.City, p.State }
    );
    p.RES060_Province__c = province;

    String typeChaudiere = typeChaudiere(p.Type_de_Chauffage__c);
    if (typeChaudiere == 'PAC') {
      p.RES060_Statut__c = NON_ELIGIBLE_PAC;
      return;
    }
    if (typeChaudiere == 'Bois') {
      p.RES060_Statut__c = SimulationRES060Service.STATUT_NON_ELIGIBLE;
      return;
    }

    Integer anneeMaison = annee(p.RES_Anne_maison__c);
    Integer anneeChaudiere = annee(p.RES_Ann_e_Chaudi_re__c);
    List<String> manque = new List<String>();
    if (province == null) {
      manque.add('province (code postal / adresse)');
    }
    if (p.Surface_habitable__c == null || p.Surface_habitable__c <= 0) {
      manque.add('surface');
    }
    if (anneeMaison == null) {
      manque.add('année de la maison');
    }
    if (typeChaudiere == null) {
      manque.add('type de chauffage');
    }
    if (
      anneeChaudiere == null &&
      (typeChaudiere == 'Gaz' ||
      typeChaudiere == 'Fioul')
    ) {
      manque.add('année de la chaudière');
    }
    if (!manque.isEmpty()) {
      p.RES060_Statut__c = (INFO_MANQUANTE + String.join(manque, ', '))
        .left(255);
      return;
    }

    Boolean bono = bonoSocial(p.RES_Bono_Social__c, p.RES060__c);
    Simulation_RES060__c s = new Simulation_RES060__c(
      Province__c = province,
      Surface__c = p.Surface_habitable__c,
      Annee_Maison__c = anneeMaison,
      Type_Chaudiere__c = typeChaudiere,
      Annee_Chaudiere__c = anneeChaudiere,
      Condensation__c = false,
      Bono_Social__c = bono == true
    );
    service.calculer(s);
    p.RES060_Indice__c = s.Indice__c;
    p.RES060_Zone__c = s.Zone__c;
    String statut = s.Statut__c == null ? '' : s.Statut__c;
    if (s.Indice__c != null && bono == null) {
      statut += BONO_INCONNU;
    }
    p.RES060_Statut__c = statut.left(255);
  }

  private static Boolean aChange(Lead p, Lead ancienne) {
    for (Schema.SObjectField f : CHAMPS_SUIVIS) {
      if (p.get(f) != ancienne.get(f)) {
        return true;
      }
    }
    return false;
  }

  private static Boolean aFicheRes060(Lead p, Set<String> fiches) {
    if (fiches.contains(p.PREVISITE_Fiche_Residentiel__c)) {
      return true;
    }
    if (p.TypeDeDossier__c != null) {
      for (String v : p.TypeDeDossier__c.split(';')) {
        if (fiches.contains(v.trim())) {
          return true;
        }
      }
    }
    return false;
  }

  private static void vider(Lead p) {
    p.RES060_Indice__c = null;
    p.RES060_Zone__c = null;
    p.RES060_Statut__c = null;
    p.RES060_Province__c = null;
  }

  private static Set<String> liste(String valeurs) {
    Set<String> result = new Set<String>();
    if (String.isNotBlank(valeurs)) {
      for (String v : valeurs.split(';')) {
        if (String.isNotBlank(v)) {
          result.add(v.trim());
        }
      }
    }
    return result;
  }

  /** Première année plausible (1800-2099) écrite dans le texte, sinon null. */
  @TestVisible
  private static Integer annee(String texte) {
    if (String.isBlank(texte)) {
      return null;
    }
    Matcher m = ANNEE.matcher(texte);
    return m.find() ? Integer.valueOf(m.group(1)) : null;
  }

  /** Valeur de « RES- Type de Chauffage » → valeur du calculateur (null si inconnue). */
  @TestVisible
  private static String typeChaudiere(String valeur) {
    String n = SimulationRES060Service.normaliser(valeur);
    if (String.isBlank(n)) {
      return null;
    }
    if (n.contains('pac') || n.contains('pompe')) {
      return 'PAC';
    }
    if (n.contains('fioul') || n.contains('gasoleo') || n.contains('fuel')) {
      return 'Fioul';
    }
    if (n.contains('gaz') || n.contains('gas')) {
      return 'Gaz';
    }
    if (n.contains('bois') || n.contains('pellet') || n.contains('lena')) {
      return 'Bois';
    }
    if (n.contains('electri')) {
      return 'Electrique';
    }
    if (n.contains('charbon') || n.contains('carbon')) {
      return 'Charbon';
    }
    return null;
  }

  /**
   * Bono social : « RES- Bono Social » d'abord, sinon la réponse du formulaire.
   * true = oui, false = non, null = non renseigné ou « je ne sais pas ».
   */
  @TestVisible
  private static Boolean bonoSocial(String confirme, String formulaire) {
    for (String v : new List<String>{ confirme, formulaire }) {
      String n = ' ' + SimulationRES060Service.normaliser(v) + ' ';
      if (String.isBlank(n) || n.contains(' sais ') || n.contains(' se ')) {
        continue;
      }
      if (n.contains(' oui ') || n.contains(' si ') || n.contains(' yes ')) {
        return true;
      }
      if (n.contains(' non ') || n.contains(' no ')) {
        return false;
      }
    }
    return null;
  }
}
