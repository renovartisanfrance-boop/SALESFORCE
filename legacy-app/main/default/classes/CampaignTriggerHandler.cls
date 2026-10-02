/**
 * CampaignTriggerHandler — logique declenchee par CampaignTrigger.
 *
 * Etend TriggerHandler, comme CatalogueTarifaireTriggerHandler et
 * FactureTriggerHandler : le trigger se contente de `new ...().run()`.
 *
 * SEUL TRAITEMENT AUJOURD'HUI — prevenir le pre-visiteur que son contrat est
 * signe, avec son lien de connexion. Tout ajout ulterieur sur Campagne passe
 * par ici : c'est le premier trigger de cet objet dans l'org, et le laisser
 * mono-usage inviterait le suivant a en creer un second.
 */
public class CampaignTriggerHandler extends TriggerHandler {

    private List<Campaign> newList;
    private Map<Id, Campaign> oldMap;

    public CampaignTriggerHandler() {
        this.newList = (List<Campaign>) Trigger.new;
        this.oldMap  = (Map<Id, Campaign>) Trigger.oldMap;
    }

    protected override void afterUpdate() {
        notifierContratsSignes();
        ouvrirComptesCertiko();
    }

    /**
     * Ouvre le compte Certiko des PRÉ-VISITEURS dont le contrat vient d'être
     * signé.
     *
     * Même détection que notifierContratsSignes — passage À « Signe », comparé
     * à l'ancienne valeur — mais réservée au rôle PRÉ-VISITEUR : c'est lui qui
     * remplit le relevé de visite technique. Un installateur signé n'a rien à
     * faire chez Certiko.
     *
     * L'ouverture part en FILE D'ATTENTE : elle appelle Certiko, et Salesforce
     * refuse un appel sortant après une écriture dans la même transaction.
     *
     * Isolée dans un try/catch pour la même raison que l'envoi du mail : la
     * signature est déjà enregistrée quand ce code s'exécute. Un contrat signé
     * perdu parce qu'un compte n'a pas pu être créé serait le pire des défauts.
     */
    private void ouvrirComptesCertiko() {
        Set<Id> aOuvrir = new Set<Id>();

        for (Campaign c : newList) {
            Campaign avant = oldMap.get(c.Id);
            Boolean vientDEtreSigne =
                c.StatutContrat__c == LC027_GestionContrat.STATUT_SIGNE
                && (avant == null || avant.StatutContrat__c != LC027_GestionContrat.STATUT_SIGNE);

            if (vientDEtreSigne && c.Role__c == LC027_Roles.PREVISITEUR) {
                aOuvrir.add(c.Id);
            }
        }

        if (aOuvrir.isEmpty()) {
            return;
        }

        try {
            LC027_CertikoCompteService.ouvrirComptes(aOuvrir);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                'CampaignTriggerHandler : compte Certiko non ouvert — ' + e.getMessage());
        }
    }

    /**
     * Detecte les contrats qui VIENNENT d'etre signes et previent leur titulaire.
     *
     * DEUX CONDITIONS, toutes deux necessaires :
     *   • StatutContrat__c passe A « Signe » — on compare a l'ancienne valeur,
     *     sans quoi toute mise a jour ulterieure d'une campagne deja signee
     *     renverrait le mail (le webhook Yousign, le batch de reconciliation et
     *     l'ecran d'administration touchent tous ces enregistrements) ;
     *   • Role__c est un role du PORTAIL (Pre-visiteur ou Installateur, voir
     *     LC027_Roles) — une regie signee, s'il en existe un jour, ne doit pas
     *     recevoir un mail qui la renvoie vers le portail Previsites.
     *
     * L'envoi est ISOLE dans un try/catch : la signature est deja enregistree
     * quand ce code s'execute. Laisser une exception remonter annulerait la
     * transaction, donc la signature elle-meme — un contrat signe perdu parce
     * que l'accuse de reception n'est pas parti serait le pire des defauts.
     */
    private void notifierContratsSignes() {
        Set<Id> aNotifier = new Set<Id>();

        for (Campaign c : newList) {
            Campaign avant = oldMap.get(c.Id);
            Boolean vientDEtreSigne =
                c.StatutContrat__c == LC027_GestionContrat.STATUT_SIGNE
                && (avant == null || avant.StatutContrat__c != LC027_GestionContrat.STATUT_SIGNE);

            if (vientDEtreSigne && LC027_Roles.estRolePortail(c.Role__c)) {
                aNotifier.add(c.Id);
            }
        }

        if (aNotifier.isEmpty()) {
            return;
        }

        try {
            LC027_EmailServicePrevisite.envoyerConfirmationsSignature(aNotifier);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                'CampaignTriggerHandler : confirmation de signature non envoyee — ' + e.getMessage());
        }
    }
}