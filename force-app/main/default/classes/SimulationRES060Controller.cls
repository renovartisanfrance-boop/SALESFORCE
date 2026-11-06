/**
 * Point d'entrée du composant visuel « simulateurRes060 ».
 * Calcule une simulation en mémoire (sans l'enregistrer) avec le même service que le trigger :
 * l'écran et l'enregistrement donnent donc toujours le même résultat.
 */
public with sharing class SimulationRES060Controller {
  @AuraEnabled
  public static Simulation_RES060__c simuler(Simulation_RES060__c simulation) {
    if (!Schema.SObjectType.Simulation_RES060__c.isAccessible()) {
      throw new AuraHandledException('Accès au simulateur RES060 refusé.');
    }
    Simulation_RES060__c s = simulation == null
      ? new Simulation_RES060__c()
      : simulation;
    new SimulationRES060Service().calculer(s);
    return s;
  }
}
