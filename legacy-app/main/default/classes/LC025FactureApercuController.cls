/**
 * Contrôleur du composant d'aperçu de facture (lwc025FactureApercu), affiché sur la
 * page d'enregistrement Facture__c (Lightning Experience ET Experience Cloud).
 *
 * Renvoie, en lecture seule, les informations clés permettant de distinguer une
 * facture ÉMISE d'une facture REÇUE :
 *  - le Record Type,
 *  - le type de facture (Reçue / Émise — valeur API « Emise » sans accent côté picklist),
 *  - la contrepartie : le CLIENT (Destinataire) pour une reçue, le FOURNISSEUR pour une émise,
 *  - les montants HT et TTC.
 *
 * « with sharing » : respecte l'accès de l'utilisateur (important en communauté).
 */
public with sharing class LC025FactureApercuController {

    // Valeur API de la picklist TypeFacture__c pour une facture émise (restreinte ;
    // « Emise » sans accent — le libellé affiché est « Émise »).
    private static final String TYPE_EMISE = 'Emise';

    public class Apercu {
        @AuraEnabled public String recordTypeName;
        @AuraEnabled public String typeFacture;        // libellé affiché : « Émise » / « Reçue »
        @AuraEnabled public Boolean isEmise;
        @AuraEnabled public String contrepartieLabel;  // « Fournisseur » (émise) / « Client » (reçue)
        @AuraEnabled public String contrepartieNom;
        @AuraEnabled public Decimal montantHT;
        @AuraEnabled public Decimal montantTTC;
    }

    @AuraEnabled(cacheable=true)
    public static Apercu getApercu(Id factureId) {
        if (factureId == null) {
            throw new AuraHandledException('Facture requise');
        }
        List<Facture__c> factures = [
            SELECT RecordType.Name, TypeFacture__c,
                   Destinataire_Compte__r.Name, Fournisseur_Compte__r.Name,
                   MontantHT__c, Montant_Total__c
            FROM Facture__c
            WHERE Id = :factureId
            WITH USER_MODE
            LIMIT 1
        ];
        if (factures.isEmpty()) {
            throw new AuraHandledException('Facture introuvable ou inaccessible.');
        }
        Facture__c f = factures[0];

        Apercu a = new Apercu();
        a.recordTypeName = (f.RecordType != null) ? f.RecordType.Name : null;
        a.isEmise = (f.TypeFacture__c == TYPE_EMISE);
        a.typeFacture = a.isEmise ? 'Émise' : 'Reçue';
        if (a.isEmise) {
            a.contrepartieLabel = 'Fournisseur';
            a.contrepartieNom = (f.Fournisseur_Compte__r != null) ? f.Fournisseur_Compte__r.Name : null;
        } else {
            a.contrepartieLabel = 'Client';
            a.contrepartieNom = (f.Destinataire_Compte__r != null) ? f.Destinataire_Compte__r.Name : null;
        }
        a.montantHT = f.MontantHT__c;
        a.montantTTC = f.Montant_Total__c;
        return a;
    }
}