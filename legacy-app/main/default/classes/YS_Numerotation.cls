/**
 * YS_Numerotation — distribution de numéros uniques et incrémentaux.
 *
 * VOLONTAIREMENT IGNORANTE DU DEVIS. Elle distribue des numéros pour n'importe
 * quelle séquence identifiée par une clé ; le devis n'en est que le premier
 * usage. Un besoin futur — facture, bon d'intervention — ajoute une ligne dans
 * YS_Compteur__c, pas un mécanisme de plus.
 *
 * ══ POURQUOI UN VERROU, ET PAS UN NUMÉRO AUTOMATIQUE ═══════════════════════
 *
 * Un Numéro automatique Salesforce garantit l'unicité, mais posé sur Lead ET
 * sur Pro__c il produirait DEUX séquences indépendantes : un devis de Piste
 * finirait par porter le même numéro qu'un devis de Dossier. Il ne sait pas non
 * plus appliquer un pas différent de 1, que le métier veut pouvoir régler.
 *
 * D'où un compteur applicatif — et donc l'obligation de gérer la concurrence
 * nous-mêmes :
 *
 *     SELECT ... FROM YS_Compteur__c WHERE Cle__c = :cle LIMIT 1 FOR UPDATE
 *
 * `FOR UPDATE` verrouille la ligne jusqu'à la fin de la transaction. Deux
 * générations simultanées sont sérialisées : la seconde attend, puis lit la
 * valeur déjà incrémentée. SANS CE VERROU, deux portails ouverts au même
 * instant recevraient le même numéro — précisément ce qu'il faut interdire.
 *
 * C'est aussi la raison pour laquelle un Custom Setting a été écarté : mis en
 * cache par la plateforme, il n'accepte pas FOR UPDATE.
 *
 * ══ CE QUE LA CLASSE NE FAIT PAS ═══════════════════════════════════════════
 *
 * Elle ne comble jamais un trou. Un numéro distribué n'est pas repris, même si
 * l'enregistrement qui le portait est supprimé : le compteur ne va que dans un
 * sens. C'est l'exigence métier, et c'est aussi ce qui rend le mécanisme sûr.
 *
 * `without sharing` : appelée depuis le portail Campagnes, qui tourne sous le
 * Guest User du site — voir l'en-tête de LC021_DevisSignature.
 */
public without sharing class YS_Numerotation {

    /** Séquence du numéro de devis, imprimée sur la « hoja de pedido ». */
    public static final String CLE_DEVIS = 'DEVIS';

    public class NumerotationException extends Exception {}

    /**
     * Numéro suivant de la séquence, préfixe compris.
     *
     * @param cle identifiant de la séquence (YS_Compteur__c.Cle__c).
     * @return par exemple « 1001 », ou « FA-1001 » si un préfixe est configuré.
     */
    public static String suivant(String cle) {
        YS_Compteur__c compteur = verrouiller(cle);

        Decimal numero = compteur.Prochain__c;
        compteur.Prochain__c = numero + compteur.Pas__c;
        update compteur;

        String prefixe = String.isBlank(compteur.Prefixe__c) ? '' : compteur.Prefixe__c;
        return prefixe + String.valueOf(numero.setScale(0));
    }

    /** Même chose, sans le préfixe, pour un appelant qui veut calculer dessus. */
    public static Decimal suivantNumerique(String cle) {
        YS_Compteur__c compteur = verrouiller(cle);

        Decimal numero = compteur.Prochain__c;
        compteur.Prochain__c = numero + compteur.Pas__c;
        update compteur;

        return numero;
    }

    /**
     * Lit la ligne de séquence EN LA VERROUILLANT.
     *
     * Les contrôles ci-dessous ne sont pas du zèle : un pas nul redistribuerait
     * indéfiniment le même numéro, et une ligne absente laisserait le code
     * inventer une valeur. Mieux vaut une erreur nommant la cause qu'un doublon
     * découvert des mois plus tard sur un document contractuel.
     */
    private static YS_Compteur__c verrouiller(String cle) {
        if (String.isBlank(cle)) {
            throw new NumerotationException('Clé de séquence non fournie.');
        }

        List<YS_Compteur__c> lignes = [
            SELECT Id, Cle__c, Prochain__c, Pas__c, Prefixe__c
            FROM YS_Compteur__c
            WHERE Cle__c = :cle
            LIMIT 1
            FOR UPDATE
        ];

        if (lignes.isEmpty()) {
            throw new NumerotationException(
                'Aucune séquence de numérotation pour la clé « ' + cle + ' ». '
                + 'Créer un enregistrement « Compteur de numerotation » portant cette clé.');
        }

        YS_Compteur__c compteur = lignes[0];
        if (compteur.Prochain__c == null) {
            throw new NumerotationException(
                'La séquence « ' + cle + ' » n\'a pas de prochain numéro.');
        }
        if (compteur.Pas__c == null || compteur.Pas__c <= 0) {
            throw new NumerotationException(
                'Le pas de la séquence « ' + cle + ' » doit être supérieur à zéro.');
        }
        return compteur;
    }
}