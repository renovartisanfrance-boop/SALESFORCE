/**
 * Contrôles de la « RES- Parcelle Cadastrale » (Lead.Parcelle_Cadastrale__c) sur les
 * pistes RES060 (Type de dossier contenant RESIDENTIEL_REGIES_-_RES060).
 *
 * Appelé par LeadTriggerHandler (before insert / before update), uniquement quand la
 * référence est saisie ou modifiée, ou quand la piste devient RES060 : les pistes
 * existantes ne sont pas bloquées pour d'autres modifications.
 *
 *  1. Format : référence catastrale espagnole complète, 20 caractères
 *     (7 + 7 parcelle, 4 chiffres logement, 2 lettres de contrôle), lettres de contrôle
 *     recalculées selon l'algorithme du Catastro.
 *  2. Doublon : aucune autre piste (convertie ou non, perdue comprise) ne doit porter
 *     la même référence. Saisie par un utilisateur : le message cite la piste ou le
 *     Dossier existant. Piste reçue automatiquement (API, import, traitement de fond) :
 *     message sans détail.
 *
 * La référence est enregistrée normalisée (majuscules, sans espace ni séparateur).
 * Les anciennes valeurs mal formées sont comparées après la même normalisation.
 *
 * without sharing : le doublon doit être trouvé même sur une piste d'un autre télépro.
 */
public without sharing class LeadReferenceCadastrale {

    private static final Integer LONGUEUR = 20;
    private static final List<Integer> POIDS = new List<Integer>{ 13, 15, 12, 5, 4, 17, 9, 21, 3, 7, 1 };
    private static final String LETTRES_CONTROLE = 'MQWERTYUIOPASDFGHJKLBZX';
    private static final Pattern FORMAT = Pattern.compile('^[0-9A-Z]{14}[0-9]{4}[A-Z]{2}$');

    @TestVisible
    private static final String MSG_FORMAT =
        'Référence cadastrale invalide : 20 caractères attendus, sans espace (ex. 9872023VH5797S0001WX).'
        + ' / Referencia catastral no válida: se esperan 20 caracteres, sin espacios (ej. 9872023VH5797S0001WX).';
    @TestVisible
    private static final String MSG_CONTROLE =
        'Référence cadastrale invalide : les 2 dernières lettres ne correspondent pas au reste de la référence, vérifiez la saisie.'
        + ' / Referencia catastral no válida: las 2 últimas letras no corresponden al resto de la referencia, revise la entrada.';
    @TestVisible
    private static final String MSG_DOUBLON_ANONYME =
        'Référence cadastrale déjà utilisée sur une autre piste ou un autre dossier.'
        + ' / Referencia catastral ya utilizada en otro registro.';
    @TestVisible
    private static final String MSG_DOUBLON_PREFIXE_FR = 'Référence cadastrale déjà utilisée : ';
    @TestVisible
    private static final String MSG_DOUBLON_PREFIXE_ES = ' / Referencia catastral ya utilizada: ';

    /** Contextes où personne ne lit le message : on n'y cite pas l'autre enregistrement. */
    private static final Set<Quiddity> CONTEXTES_AUTOMATIQUES = new Set<Quiddity>{
        Quiddity.REST, Quiddity.SOAP, Quiddity.BULK_API,
        Quiddity.BATCH_APEX, Quiddity.BATCH_ACS, Quiddity.BATCH_CHUNK_PARALLEL, Quiddity.BATCH_CHUNK_SERIAL,
        Quiddity.FUTURE, Quiddity.QUEUEABLE, Quiddity.SCHEDULED, Quiddity.TRANSACTION_FINALIZER_QUEUEABLE
    };

    /** Forçage du contexte pour les tests (null = contexte réel). */
    @TestVisible
    private static Boolean saisieAutomatiqueForcee;

    public static void controler(List<Lead> pistes, Map<Id, Lead> anciennes) {
        // 1) Pistes à contrôler, normalisation et format.
        Map<String, Lead> parReference = new Map<String, Lead>();
        for (Lead piste : pistes) {
            if (!aControler(piste, anciennes == null ? null : anciennes.get(piste.Id))) continue;

            String reference = normaliser(piste.Parcelle_Cadastrale__c);
            piste.Parcelle_Cadastrale__c = reference;

            String erreur = erreurFormat(reference);
            if (erreur != null) {
                piste.Parcelle_Cadastrale__c.addError(erreur);
                continue;
            }
            // Deux pistes du même lot avec la même référence : la seconde est bloquée.
            if (parReference.containsKey(reference)) {
                piste.Parcelle_Cadastrale__c.addError(MSG_DOUBLON_ANONYME);
                continue;
            }
            parReference.put(reference, piste);
        }
        if (parReference.isEmpty()) return;

        // 2) Pistes existantes candidates. Le filtre sur les 7 premiers caractères
        //    attrape aussi les anciennes valeurs saisies avec espaces ou séparateurs ;
        //    la comparaison exacte se fait après normalisation.
        List<String> motifs = new List<String>();
        Set<Id> idsDuLot = new Set<Id>();
        for (String reference : parReference.keySet()) motifs.add(reference.left(7) + '%');
        for (Lead piste : pistes) if (piste.Id != null) idsDuLot.add(piste.Id);

        Map<String, Lead> existantes = new Map<String, Lead>();
        for (Lead autre : [
            SELECT Id, Name, Parcelle_Cadastrale__c, IsConverted, ConvertedOpportunityId,
                   CreatedDate, ConfirmateurLookup__r.Name, Owner.Name
            FROM Lead
            WHERE Parcelle_Cadastrale__c LIKE :motifs AND Id NOT IN :idsDuLot
            ORDER BY CreatedDate
        ]) {
            String reference = normaliser(autre.Parcelle_Cadastrale__c);
            if (parReference.containsKey(reference) && !existantes.containsKey(reference)) {
                existantes.put(reference, autre);
            }
        }
        if (existantes.isEmpty()) return;

        // 3) Dossier des pistes converties (Dossiers.Opportunite__c = opportunité convertie).
        Map<Id, Pro__c> dossierParOpportunite = new Map<Id, Pro__c>();
        if (!estSaisieAutomatique()) {
            Set<Id> opportunites = new Set<Id>();
            for (Lead autre : existantes.values()) {
                if (autre.ConvertedOpportunityId != null) opportunites.add(autre.ConvertedOpportunityId);
            }
            dossierParOpportunite = dossiersParOpportunite(opportunites);
        }

        // 4) Blocage.
        for (String reference : existantes.keySet()) {
            Lead autre = existantes.get(reference);
            String message = estSaisieAutomatique()
                ? MSG_DOUBLON_ANONYME
                : messageDoublon(autre, dossierParOpportunite.get(autre.ConvertedOpportunityId));
            parReference.get(reference).Parcelle_Cadastrale__c.addError(message);
        }
    }

    /** Premier Dossier créé pour chaque opportunité. */
    @TestVisible
    private static Map<Id, Pro__c> dossiersParOpportunite(Set<Id> opportunites) {
        Map<Id, Pro__c> resultat = new Map<Id, Pro__c>();
        if (opportunites.isEmpty()) return resultat;
        for (Pro__c dossier : [
            SELECT Id, Name, Opportunite__c FROM Pro__c
            WHERE Opportunite__c IN :opportunites ORDER BY CreatedDate
        ]) {
            if (!resultat.containsKey(dossier.Opportunite__c)) resultat.put(dossier.Opportunite__c, dossier);
        }
        return resultat;
    }

    /** Majuscules, sans espace, point, tiret ni barre. */
    @TestVisible
    private static String normaliser(String valeur) {
        if (valeur == null) return null;
        return valeur.toUpperCase().replaceAll('[\\s.\\-/_]', '');
    }

    /** null si la référence est valide, sinon le message d'erreur. */
    @TestVisible
    private static String erreurFormat(String reference) {
        if (reference == null || reference.length() != LONGUEUR || !FORMAT.matcher(reference).matches()) {
            return MSG_FORMAT;
        }
        return reference.right(2) == lettresControle(reference) ? null : MSG_CONTROLE;
    }

    /**
     * Lettres de contrôle du Catastro : la 1re porte sur les caractères 1-7 et 15-18,
     * la 2de sur les caractères 8-14 et 15-18 ; somme pondérée modulo 23.
     * Valeur d'une lettre : A = 1 … N = 14, Ñ = 15, O = 16 … Z = 27.
     */
    @TestVisible
    private static String lettresControle(String reference) {
        String logement = reference.substring(14, 18);
        String resultat = '';
        for (String bloc : new List<String>{ reference.substring(0, 7) + logement, reference.substring(7, 14) + logement }) {
            Integer somme = 0;
            for (Integer i = 0; i < bloc.length(); i++) {
                somme += POIDS[i] * valeurCaractere(bloc.substring(i, i + 1));
            }
            Integer rang = Math.mod(somme, 23);
            resultat += LETTRES_CONTROLE.substring(rang, rang + 1);
        }
        return resultat;
    }

    private static Integer valeurCaractere(String c) {
        if (c.isNumeric()) return Integer.valueOf(c);
        if (c == 'Ñ') return 15;
        Integer code = c.charAt(0);
        return code > 78 ? code - 63 : code - 64; // au-delà de N, Ñ occupe le rang 15
    }

    private static Boolean aControler(Lead piste, Lead ancienne) {
        if (String.isBlank(piste.Parcelle_Cadastrale__c) || !estRes060(piste)) return false;
        if (ancienne == null) return true;
        return piste.Parcelle_Cadastrale__c != ancienne.Parcelle_Cadastrale__c || !estRes060(ancienne);
    }

    private static Boolean estRes060(Lead piste) {
        return piste.TypeDeDossier__c != null
            && piste.TypeDeDossier__c.split(';').contains(Constants.FICHE_PISTE_060);
    }

    private static Boolean estSaisieAutomatique() {
        if (saisieAutomatiqueForcee != null) return saisieAutomatiqueForcee;
        return CONTEXTES_AUTOMATIQUES.contains(Request.getCurrent().getQuiddity());
    }

    @TestVisible
    private static String messageDoublon(Lead autre, Pro__c dossier) {
        String telepro = autre.ConfirmateurLookup__r != null ? autre.ConfirmateurLookup__r.Name : autre.Owner.Name;
        String creeLe = autre.CreatedDate.format('dd/MM/yyyy');
        String fr;
        String es;
        if (dossier != null) {
            fr = 'Dossier « ' + dossier.Name + ' » (piste convertie, télépro ' + telepro + ', créée le ' + creeLe + ')';
            es = 'Expediente « ' + dossier.Name + ' » (lead convertido, teleoperador ' + telepro + ', creado el ' + creeLe + ')';
        } else {
            String etatFr = autre.IsConverted ? 'convertie' : 'non convertie';
            String etatEs = autre.IsConverted ? 'convertido' : 'no convertido';
            fr = 'Piste « ' + autre.Name + ' » (' + etatFr + ', télépro ' + telepro + ', créée le ' + creeLe + ')';
            es = 'Lead « ' + autre.Name + ' » (' + etatEs + ', teleoperador ' + telepro + ', creado el ' + creeLe + ')';
        }
        return MSG_DOUBLON_PREFIXE_FR + fr + MSG_DOUBLON_PREFIXE_ES + es;
    }
}