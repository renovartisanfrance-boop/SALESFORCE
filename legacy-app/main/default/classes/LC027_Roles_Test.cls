/**
 * Tests de LC027_Roles — configuration des rôles du portail Gestion Prévisites.
 *
 * Aucun DML : la classe n'est qu'une table. Ces tests figent les décisions qui,
 * modifiées par mégarde, ouvriraient ou fermeraient l'accès sans bruit.
 */
@isTest
private class LC027_Roles_Test {

    @isTest
    static void rolesDuPortail() {
        System.assert(LC027_Roles.estRolePortail('Pre-visiteur'));
        System.assert(LC027_Roles.estRolePortail('Installateur'));
        System.assert(!LC027_Roles.estRolePortail('Régie'), 'Une régie reste hors du portail.');
        System.assert(!LC027_Roles.estRolePortail(null));
        System.assert(!LC027_Roles.estRolePortail(''));
    }

    /** L'installateur reprend les champs du prévisiteur, sauf le nombre de prévisites. */
    @isTest
    static void memesChampsPourLesDeuxRoles() {
        Set<String> prev = LC027_Roles.champsModifiables(LC027_Roles.PREVISITEUR);
        Set<String> inst = LC027_Roles.champsModifiables(LC027_Roles.INSTALLATEUR);

        System.assert(prev.contains('Contrat_NIF__c'));
        System.assert(!prev.contains('StatutContrat__c'), 'Le statut ne se modifie jamais du portail.');
        System.assert(!prev.contains('Role__c'), 'Le rôle ne se modifie jamais du portail.');
        Set<String> prevSansNombre = new Set<String>(prev);
        prevSansNombre.remove('NombrePrevisites__c');
        System.assertEquals(prevSansNombre, inst);
    }

    @isTest
    static void roleInconnuSansChamp() {
        System.assert(LC027_Roles.champsModifiables('Régie').isEmpty());
        System.assert(LC027_Roles.champsModifiables(null).isEmpty());
    }

    /** L'ensemble renvoyé est une COPIE : le modifier n'altère pas la configuration. */
    @isTest
    static void champsRenvoyesEnCopie() {
        LC027_Roles.champsModifiables(LC027_Roles.PREVISITEUR).add('Role__c');
        System.assert(!LC027_Roles.champsModifiables(LC027_Roles.PREVISITEUR).contains('Role__c'));
    }

    @isTest
    static void contratParRole() {
        System.assertEquals('contrat_previsiteur', LC027_Roles.ressourceContrat(LC027_Roles.PREVISITEUR));
        System.assert(LC027_Roles.contratDisponible(LC027_Roles.PREVISITEUR));
        // Installateur : PAS de valeur supposée — son contrat est configurable.
        // On vérifie seulement la cohérence entre ressource et disponibilité.
        System.assertEquals(
            String.isNotBlank(LC027_Roles.ressourceContrat(LC027_Roles.INSTALLATEUR)),
            LC027_Roles.contratDisponible(LC027_Roles.INSTALLATEUR));
        System.assert(!LC027_Roles.contratDisponible(null));
    }

    /** Nombre de prévisites : prévisiteur ESPAGNOL uniquement. */
    @isTest
    static void champReserveALEspagne() {
        System.assert(LC027_Roles.champsModifiables(LC027_Roles.PREVISITEUR, 'Espagne')
            .contains('NombrePrevisites__c'));
        System.assert(!LC027_Roles.champsModifiables(LC027_Roles.PREVISITEUR, 'France')
            .contains('NombrePrevisites__c'));
        System.assert(!LC027_Roles.champsModifiables(LC027_Roles.PREVISITEUR, null)
            .contains('NombrePrevisites__c'));
        System.assert(!LC027_Roles.champsModifiables(LC027_Roles.INSTALLATEUR, 'Espagne')
            .contains('NombrePrevisites__c'), 'Champ propre au previsiteur.');
        // Les autres champs ne dependent pas du pays.
        System.assert(LC027_Roles.champsModifiables(LC027_Roles.PREVISITEUR, 'France')
            .contains('Contrat_NIF__c'));
    }

    @isTest
    static void prefixeDuCompte() {
        System.assertEquals('PREVISITEUR- ', LC027_Roles.prefixeCompte(LC027_Roles.PREVISITEUR));
        System.assertEquals('INSTALLATEUR- ', LC027_Roles.prefixeCompte(LC027_Roles.INSTALLATEUR));
        System.assertEquals('', LC027_Roles.prefixeCompte('Régie'));
    }
}