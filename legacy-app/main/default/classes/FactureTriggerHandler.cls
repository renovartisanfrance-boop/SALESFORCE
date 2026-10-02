public class FactureTriggerHandler extends TriggerHandler {

    private List<Facture__c> newList;
    private Map<Id, Facture__c> oldMap;

    // Type de facture par défaut + valeurs API de la picklist restreinte
    // (⚠️ « Emise » sans accent ; « Reçue » == label).
    private static final String TYPE_FACTURE_RECUE = 'Reçue';
    private static final String TYPE_FACTURE_EMISE = 'Emise';

    public FactureTriggerHandler() {
        this.newList = (List<Facture__c>) Trigger.new;
        this.oldMap  = (Map<Id, Facture__c>) Trigger.oldMap;
    }

    protected override void beforeInsert() {
        appliquerTypeFactureParDefaut(newList);
        remplirCompteParDefaut(newList);
        verifierCoherenceMontant(newList);
    }

    /**
     * Remplissage automatique du compte « société » sur l'AUTRE champ lookup, selon le
     * sens de la facture :
     *  - facture ÉMISE  -> Destinataire_Compte__c (le Fournisseur est le compte courant) ;
     *  - facture REÇUE  -> Fournisseur_Compte__c   (le Destinataire est le compte courant).
     * Valeur = 1er Account avec ComptePrincipaleSociete__c = true ; laissé VIDE si aucun.
     * Posé uniquement si le champ cible est encore vide (n'écrase pas une valeur fournie).
     */
    private void remplirCompteParDefaut(List<Facture__c> factures) {
        Id comptePrincipal = comptePrincipalSociete();
        if (comptePrincipal == null) return; // aucun compte principal -> on laisse vide
        for (Facture__c f : factures) {
            if (f.TypeFacture__c == TYPE_FACTURE_EMISE) {
                if (f.Destinataire_Compte__c == null) f.Destinataire_Compte__c = comptePrincipal;
            } else if (f.TypeFacture__c == TYPE_FACTURE_RECUE) {
                if (f.Fournisseur_Compte__c == null) f.Fournisseur_Compte__c = comptePrincipal;
            }
        }
    }

    // 1er Account marqué « compte principal société » (ComptePrincipaleSociete__c = true),
    // ou null. Requête DYNAMIQUE + garde d'existence du champ : la classe se déploie même
    // si le champ n'est pas (encore) présent dans l'org.
    private static Id comptePrincipalSociete() {
        if (!Account.SObjectType.getDescribe().fields.getMap().containsKey('compteprincipalesociete__c')) {
            return null;
        }
        List<SObject> comptes = Database.query(
            'SELECT Id FROM Account WHERE ComptePrincipaleSociete__c = true LIMIT 1'
        );
        return comptes.isEmpty() ? null : (Id) comptes[0].get('Id');
    }

    /**
     * Type de facture par défaut « Reçue » posé sur TOUTE facture créée — quel que
     * soit le point de création (wizards, FacturesController.createFactureAvecLignes,
     * factures d'acompte LC023, flux, API) — tant que la valeur n'est pas déjà
     * renseignée. Le champ est rendu en lecture seule dans les formulaires ; les
     * factures émises seront traitées ultérieurement (elles poseront leur propre valeur).
     */
    private void appliquerTypeFactureParDefaut(List<Facture__c> factures) {
        for (Facture__c f : factures) {
            if (String.isBlank(f.TypeFacture__c)) {
                f.TypeFacture__c = TYPE_FACTURE_RECUE;
            }
        }
    }

    protected override void beforeUpdate() {
        bloquerChangementStatutSiLettrage();
        verifierCoherenceMontant(newList);
    }

    /**
     * Le statut d'une facture liée à un lettrage ne peut pas être modifié :
     * il faut d'abord détacher la facture du lettrage.
     */
    private void bloquerChangementStatutSiLettrage() {
        for (Facture__c f : newList) {
            Facture__c ancienne = oldMap.get(f.Id);
            if (ancienne == null) continue;
            if (f.Statut__c == ancienne.Statut__c) continue;   // statut inchangé
            if (ancienne.Lettrage__c == null) continue;        // non liée à un lettrage

            f.addError(
                'Impossible de modifier le statut de cette facture : elle est liée à '
                + 'un lettrage. Détachez-la du lettrage au préalable.'
            );
        }
    }

    /**
     * Lorsqu'une facture est au statut Validé, la somme des montants HT de ses
     * lignes doit être égale au montant HT de la facture + le total HT des
     * acomptes (avances) rattachés (Montant_TotalAcompte_Avance_HT__c) : le
     * montant d'une facture Classique ne contient pas les acomptes déjà
     * facturés au bénéficiaire.
     *
     * Les factures sans ligne associée ne sont pas concernées (ex. Avoir /
     * Acompte) — cohérent avec FacturesController.createFactureAvecLignes.
     */
    private void verifierCoherenceMontant(List<Facture__c> factures) {
        Set<Id> factureIds = new Set<Id>();
        for (Facture__c f : factures) {
            if (f.Statut__c == Constants.Facture_STATUT_VALIDE && f.Id != null) {
                factureIds.add(f.Id);
            }
        }
        if (factureIds.isEmpty()) return;

        Map<Id, Decimal> sommeParFacture = new Map<Id, Decimal>();
        for (LigneFacture__c ligne : [
            SELECT Facture__c, Montant_Total__c, Montant_HT__c
            FROM LigneFacture__c
            WHERE Facture__c IN :factureIds
        ]) {
            Decimal cumul = sommeParFacture.containsKey(ligne.Facture__c)
                ? sommeParFacture.get(ligne.Facture__c)
                : 0;
            if (ligne.Montant_HT__c != null) cumul += ligne.Montant_HT__c;
            sommeParFacture.put(ligne.Facture__c, cumul);
        }

        Id rtClassiqueId = Schema.SObjectType.Facture__c
            .getRecordTypeInfosByName().get('Classique').getRecordTypeId();

        for (Facture__c f : factures) {
            if (f.Statut__c != Constants.Facture_STATUT_VALIDE) continue;

            Boolean aDesLignes = sommeParFacture.containsKey(f.Id);
            Boolean estClassique = f.RecordTypeId == rtClassiqueId;

            // Sans ligne : exempté uniquement si le RecordType n'est pas Classique
            if (!aDesLignes && !estClassique) continue;

            Decimal sommeLignes = aDesLignes ? sommeParFacture.get(f.Id) : 0;
            Decimal montantFacture = (f.MontantHT__c == null ? 0 : f.MontantHT__c)
                + (f.Montant_TotalAcompte_Avance_HT__c == null ? 0 : f.Montant_TotalAcompte_Avance_HT__c);

            if (sommeLignes.setScale(2) != montantFacture.setScale(2)) {
                f.addError(
                    'Impossible de valider la facture : le total HT des lignes ('
                    + sommeLignes.setScale(2) + ' €) ne correspond pas au montant HT '
                    + 'de la facture + total des acomptes (' + montantFacture.setScale(2) + ' €).'
                );
            }
        }
    }
}