/**
 * Requêtes du rattachement des fiches Aircall.
 * « without sharing » voulu : le rattachement tourne pour le compte du système (appel reçu d'Aircall)
 * et doit retrouver le client quel que soit l'utilisateur qui a déclenché l'enregistrement.
 */
public without sharing class AircallRattachementSelector {
  public List<Aircall__c> fichesParIds(Set<Id> ficheIds) {
    return [
      SELECT Id, Telephone_Client__c, Piste__c, Opportunite__c, Dossier__c
      FROM Aircall__c
      WHERE Id IN :ficheIds
    ];
  }

  public Database.QueryLocator fichesIncompletesDepuis(Datetime depuis) {
    return Database.getQueryLocator(
      [
        SELECT Id
        FROM Aircall__c
        WHERE
          CreatedDate >= :depuis
          AND Telephone_Client__c != NULL
          AND (Piste__c = NULL
          OR Opportunite__c = NULL
          OR Dossier__c = NULL)
      ]
    );
  }

  /**
   * Cherche pistes et dossiers par numéro, quel que soit le format saisi (recherche Salesforce
   * sur les champs téléphone). Seuls les numéros faits uniquement de chiffres sont recherchés.
   * Retour : [0] = pistes, [1] = dossiers.
   */
  public List<List<SObject>> clientsParNumeros(List<String> numeros) {
    List<String> termes = new List<String>();
    for (String numero : numeros) {
      if (numero != null && numero.isNumeric()) {
        termes.add(numero);
      }
    }
    if (termes.isEmpty()) {
      return new List<List<SObject>>{ new List<Lead>(), new List<Pro__c>() };
    }
    String recherche = String.join(termes, ' OR ');
    return [
      FIND :recherche
      IN PHONE FIELDS
      RETURNING
        Lead(
          Id,
          Phone,
          MobilePhone,
          IsConverted,
          ConvertedOpportunityId,
          CreatedDate
          ORDER BY CreatedDate DESC
          LIMIT 500
        ),
        Pro__c(
          Id,
          Phone__c,
          PRO_T_l_phone_Signataire__c,
          Opportunite__c,
          CreatedDate
          ORDER BY CreatedDate DESC
          LIMIT 500
        )
    ];
  }

  public List<Pro__c> dossiersParOpportunites(Set<Id> opportuniteIds) {
    if (opportuniteIds.isEmpty()) {
      return new List<Pro__c>();
    }
    return [
      SELECT Id, Opportunite__c, CreatedDate
      FROM Pro__c
      WHERE Opportunite__c IN :opportuniteIds
      ORDER BY CreatedDate DESC
    ];
  }
}
