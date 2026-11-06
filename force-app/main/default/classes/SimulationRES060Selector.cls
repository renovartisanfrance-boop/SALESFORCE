/**
 * Lit les réglages du simulateur RES060 (Custom Metadata).
 * Les Custom Metadata sont lus en mémoire : aucune requête SOQL consommée.
 */
public with sharing class SimulationRES060Selector {
  @TestVisible
  private static final String NOM_PARAMETRES = 'Defaut';

  /** Réglages fixes (SCOP, fC, prix par défaut, coûts, seuils). Null si l'enregistrement manque. */
  public RES060_Parametre__mdt getParametres() {
    return RES060_Parametre__mdt.getInstance(NOM_PARAMETRES);
  }

  /** Tableau D_CAL : une ligne par province. */
  public List<RES060_DCAL_Province__mdt> getDcalProvinces() {
    return RES060_DCAL_Province__mdt.getAll().values();
  }
}
