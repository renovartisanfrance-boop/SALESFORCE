/**
 * Règle TELEPHONE_RES060 : même téléphone entre pistes RES060 non converties
 * (Lead.Phone) et Dossiers RES060 (Pro__c.Phone__c).
 *
 * Une piste convertie sort de la règle : c'est son Dossier qui compte.
 * Clé = chiffres seuls, puis les 9 derniers (« +34 666 66 66 66 », « 34666666666 »
 * et « 666666666 » donnent la même clé). Un numéro plus court est comparé tel quel.
 */
public class DoublonRegle_TelephoneRes060 implements DoublonRegle {

    @TestVisible
    private static final String FICHE_DOSSIER_060 = 'BAR_RES060- PAC';
    private static final Integer LONGUEUR_CLE = 9;

    public Map<SObjectType, SObjectField> champsLien() {
        return new Map<SObjectType, SObjectField>{
            Lead.SObjectType   => Lead.Doublon_Telephone__c,
            Pro__c.SObjectType => Pro__c.Doublon_Telephone__c
        };
    }

    public String cle(SObject enregistrement) {
        if (enregistrement instanceof Lead) {
            Lead piste = (Lead) enregistrement;
            if (piste.IsConverted || !estPisteRes060(piste)) return null;
            return normaliser(piste.Phone);
        }
        if (enregistrement instanceof Pro__c) {
            Pro__c dossier = (Pro__c) enregistrement;
            if (dossier.Fiche_CEE__c != FICHE_DOSSIER_060) return null;
            return normaliser(dossier.Phone__c);
        }
        return null;
    }

    private static Boolean estPisteRes060(Lead piste) {
        return piste.TypeDeDossier__c != null
            && piste.TypeDeDossier__c.split(';').contains(Constants.FICHE_PISTE_060);
    }

    @TestVisible
    private static String normaliser(String telephone) {
        if (String.isBlank(telephone)) return null;
        String chiffres = telephone.replaceAll('[^0-9]', '');
        if (chiffres.length() == 0) return null;
        return chiffres.length() > LONGUEUR_CLE ? chiffres.right(LONGUEUR_CLE) : chiffres;
    }
}