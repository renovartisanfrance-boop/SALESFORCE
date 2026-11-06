/**
 * Contrat d'une règle de détection de doublons, exécutée par DoublonService.
 *
 * Une règle ne fait que décrire : quels objets elle couvre, dans quel champ chacun
 * range le lien vers son Groupe de doublons (Doublon_Groupe__c), et quelle clé
 * calculer pour un enregistrement. Toute la mécanique (groupes, verrous, comptage,
 * déclencheurs) est dans DoublonService.
 *
 * Ajouter une règle :
 *  1. une classe qui implémente cette interface (constructeur sans argument) ;
 *  2. sur chaque objet couvert, un lookup vers Doublon_Groupe__c + une formule d'affichage ;
 *  3. un enregistrement Doublon_Regle__mdt (DeveloperName = nom de la règle, Classe__c) ;
 *  4. sur un nouvel objet seulement : appeler DoublonService depuis son trigger.
 */
public interface DoublonRegle {

    /** Objets couverts par la règle et, pour chacun, son lookup vers Doublon_Groupe__c. */
    Map<SObjectType, SObjectField> champsLien();

    /**
     * Clé normalisée de l'enregistrement, ou null s'il n'entre pas dans la règle.
     * Ne doit faire aucune requête : appelée pour chaque enregistrement du lot.
     */
    String cle(SObject enregistrement);
}