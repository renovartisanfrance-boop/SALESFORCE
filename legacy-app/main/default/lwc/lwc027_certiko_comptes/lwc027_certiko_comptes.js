import { LightningElement, track } from 'lwc';
import getTableau from '@salesforce/apex/LC027_CertikoAdmin.getTableau';
import creerEquipe from '@salesforce/apex/LC027_CertikoAdmin.creerEquipe';
import majEquipe from '@salesforce/apex/LC027_CertikoAdmin.majEquipe';
import creerCompte from '@salesforce/apex/LC027_CertikoAdmin.creerCompte';
import majCompte from '@salesforce/apex/LC027_CertikoAdmin.majCompte';
import ouvrirCompte from '@salesforce/apex/LC027_CertikoAdmin.ouvrirCompte';

/**
 * lwc027_certiko_comptes — tableau de bord Certiko, pour les administrateurs.
 *
 * ÉCRAN INTERNE, en FRANÇAIS uniquement : il ne s'adresse pas aux
 * pré-visiteurs espagnols mais à l'équipe qui les administre. Il ne passe donc
 * pas par c/lwc027_i18n — y ajouter un dictionnaire d'une seule langue le
 * ferait paraître traduisible alors qu'il ne l'est pas.
 *
 * DISPOSITION, dans l'ordre de ce qu'on vient y chercher :
 *   • INDICATEURS — à ouvrir / actifs / jamais connectés ; cliquables, ils
 *     servent de filtres rapides.
 *   • ÉCARTS — bandeau repliable : contrats signés SANS compte Certiko, et
 *     comptes dont l'ÉQUIPE chez Certiko n'est plus celle enregistrée chez
 *     nous (leurs dossiers partiraient à la mauvaise équipe, sans erreur).
 *     C'est la seule chose que la console Certiko ne peut pas montrer, et la
 *     raison d'être de cet écran.
 *   • COMPTES — la liste de travail : réinitialiser un mot de passe, déplacer,
 *     désactiver un départ.
 *   • MODALES — « Gestion équipes » (liste + création) et « Nouveau compte » :
 *     des actions ponctuelles, qui n'ont pas à occuper l'écran en permanence.
 *
 * ⚠️ AUCUNE SUPPRESSION chez Certiko : un compte se DÉSACTIVE. Les inactifs
 * s'affichent à la demande, pour qu'un départ reste visible.
 */

/** Mot de passe posé à la création, identique à celui du service Apex. */
const MOT_DE_PASSE_INITIAL = '0123456789';

/** Durée d'affichage d'un message de succès, en ms. Les erreurs restent. */
const DUREE_SUCCES = 6000;

/** Filtre rapide « Jamais connectés » (indicateur cliquable). */
const FILTRE_JAMAIS = 'jamais';

const COMPTE_VIDE = { email: '', prenom: '', nom: '', equipe: '', telephone: '' };

/** Messages des codes que le serveur renvoie tels quels. */
const ERREURS = {
    CERTIKO_INJOIGNABLE: "Certiko n'a pas répondu. Réessayez.",
    CERTIKO_CLE_REFUSEE: 'Clé API refusée par Certiko. Vérifiez le label CERTIKO_API_KEY_COMPTES.',
    CERTIKO_REGLAGE_MANQUANT: 'Un réglage Certiko manque (label CERTIKO_BASE_URL ou CERTIKO_API_KEY_COMPTES).',
    CERTIKO_LIMITE_DEBIT: 'Trop de demandes envoyées à Certiko. Patientez quelques secondes.',
    CERTIKO_INTROUVABLE: 'Introuvable chez Certiko.',
    CERTIKO_EQUIPE_EXISTE: 'Une équipe active porte déjà ce nom.',
    CERTIKO_EMAIL_PRIS: 'Cet email est déjà utilisé par un compte Certiko.',
    CERTIKO_REPONSE_ILLISIBLE: 'Réponse de Certiko illisible.',
    CERTIKO_EQUIPE_SANS_NOM: "Le nom de l'équipe est obligatoire.",
    CERTIKO_COMPTE_INCOMPLET: 'Email, mot de passe et équipe sont obligatoires.',
    CERTIKO_RIEN_A_CHANGER: 'Aucune modification demandée.',
    CAMPAGNE_INTROUVABLE: 'Campagne introuvable.',
    PAS_UN_PREVISITEUR: "Cette campagne n'est pas un pré-visiteur.",
    EMAIL_MANQUANT: "La campagne n'a pas d'email."
};

export default class Lwc027CertikoComptes extends LightningElement {
    @track chargement = true;
    @track message = null;
    @track typeMessage = 'info';
    @track enCours = false;
    @track inclureInactifs = false;

    @track poseur = null;
    @track equipes = [];
    @track membres = [];
    @track previsiteurs = [];

    /* Saisies */
    @track nouvelleEquipe = '';
    @track nouveauCompte = { ...COMPTE_VIDE };
    /** Équipe ouverte dans la liste des comptes ; vide = tous. */
    @track filtreEquipe = '';
    @track recherche = '';
    /** Filtre rapide posé par un indicateur ; vide = aucun. */
    @track filtreConnexion = '';

    /* Affichage */
    @track aOuvrirDeplie = false;
    @track modaleEquipes = false;
    @track modaleCompte = false;
    @track formEquipeOuvert = false;

    _minuteurMessage;
    /** Élément à focaliser au prochain rendu (Échap ne marche que focalisé). */
    _focaliser = null;

    connectedCallback() {
        this.charger();
    }

    disconnectedCallback() {
        clearTimeout(this._minuteurMessage);
    }

    renderedCallback() {
        if (!this._focaliser) return;
        const cible = this.template.querySelector(this._focaliser);
        if (cible) {
            cible.focus();
            this._focaliser = null;
        }
    }

    /* ══════════════════════ Chargement ══════════════════════ */

    async charger() {
        this.chargement = true;
        try {
            const t = await getTableau({ inclureInactifs: this.inclureInactifs });
            this.poseur = t.poseur;
            this.equipes = t.equipes || [];
            this.membres = t.membres || [];
            this.previsiteurs = t.previsiteurs || [];
            this.message = null;
        } catch (e) {
            this.afficher(this.messageDe(e), 'error');
        } finally {
            this.chargement = false;
        }
    }

    handleRafraichir() {
        this.charger();
    }

    handleInclureInactifs(event) {
        this.inclureInactifs = event.target.checked;
        this.charger();
    }

    /* ══════════════════════ En-tête ══════════════════════ */

    get titrePoseur() {
        return this.poseur ? this.poseur.nom : '—';
    }

    get resumeCle() {
        if (!this.poseur) return 'Clé non vérifiée';
        return `Clé valide · ${this.equipes.length} équipes · ${this.membres.length} comptes`;
    }

    get classeMessage() {
        return 'message message-' + this.typeMessage;
    }

    /** Dans une modale, le message s'affiche DEDANS : le fond le masquerait. */
    get afficherMessagePage() {
        return !!this.message && !this.modaleEquipes && !this.modaleCompte;
    }

    handleFermerMessage() {
        this.message = null;
    }

    /* ══════════════════════ Indicateurs ══════════════════════ */

    get nbAOuvrir() {
        return this.aOuvrir.length;
    }

    get nbActifs() {
        return this.membres.filter((m) => m.actif).length;
    }

    get nbJamaisConnectes() {
        return this.membres.filter((m) => m.actif && !m.derniereConnexion).length;
    }

    get nbEquipesActives() {
        return this.equipes.filter((e) => e.active).length;
    }

    get classeTuileAOuvrir() {
        let c = 'tuile';
        if (this.nbAOuvrir) c += ' tuile-alerte';
        if (this.aOuvrirDeplie) c += ' tuile-active';
        return c;
    }

    get classeTuileActifs() {
        return 'tuile' + (!this.filtreConnexion ? ' tuile-active' : '');
    }

    get classeTuileJamais() {
        let c = 'tuile';
        if (this.nbJamaisConnectes) c += ' tuile-attention';
        if (this.filtreConnexion === FILTRE_JAMAIS) c += ' tuile-active';
        return c;
    }

    handleFiltreTous() {
        this.filtreConnexion = '';
    }

    handleFiltreJamais() {
        this.filtreConnexion = this.filtreConnexion === FILTRE_JAMAIS ? '' : FILTRE_JAMAIS;
    }

    /* ══════════════════════ 1. À ouvrir ══════════════════════ */

    /**
     * Les DEUX écarts entre les deux systèmes, dans une seule liste parce
     * qu'un seul bouton les répare :
     *   • contrat signé sans compte vérifié chez Certiko ;
     *   • compte dont l'équipe chez Certiko n'est plus celle enregistrée chez
     *     nous — ses dossiers partiraient à la mauvaise équipe, en silence.
     */
    get aOuvrir() {
        return this.previsiteurs
            .filter((p) => !p.compteVerifie || p.equipeDesynchronisee)
            .map((p) => ({
                ...p,
                classeLigne: p.erreur ? 'ligne ligne-erreur' : 'ligne',
                motif: p.compteVerifie
                    ? "Équipe désynchronisée — ses dossiers partiraient à la mauvaise équipe"
                    : null,
                // Le geste est le même — relire Certiko et réécrire la
                // campagne — mais le dire « ouvrir un compte » alors qu'il
                // existe déjà ferait hésiter avant de cliquer.
                libelleBouton: p.compteVerifie ? 'Resynchroniser' : 'Ouvrir le compte'
            }));
    }

    get nbEquipesDesynchronisees() {
        return this.previsiteurs.filter((p) => p.equipeDesynchronisee).length;
    }

    get aDesComptesAOuvrir() {
        return this.aOuvrir.length > 0;
    }

    get resumeAOuvrir() {
        const sansCompte = this.previsiteurs.filter((p) => !p.compteVerifie).length;
        const desync = this.nbEquipesDesynchronisees;
        if (!sansCompte && !desync) return 'Tous les contrats signés ont leur compte Certiko.';
        const morceaux = [];
        if (sansCompte) {
            morceaux.push(
                sansCompte === 1 ? '1 pré-visiteur sans compte' : `${sansCompte} pré-visiteurs sans compte`
            );
        }
        if (desync) {
            morceaux.push(
                desync === 1 ? '1 équipe désynchronisée' : `${desync} équipes désynchronisées`
            );
        }
        return morceaux.join(', ');
    }

    get chevronAOuvrir() {
        return this.aOuvrirDeplie ? 'Masquer ▴' : 'Voir la liste ▾';
    }

    get aOuvrirDeplieTexte() {
        return this.aOuvrirDeplie ? 'true' : 'false';
    }

    handleBasculerAOuvrir() {
        if (!this.nbAOuvrir) return;
        this.aOuvrirDeplie = !this.aOuvrirDeplie;
    }

    async handleOuvrirCompte(event) {
        const campagneId = event.currentTarget.dataset.id;
        await this.executer(async () => {
            const p = await ouvrirCompte({ campagneId });
            this.afficher(`${p.nom} — compte ${p.certikoLogin}, équipe ${p.certikoEquipe}`, 'success');
            await this.charger();
        });
    }

    /* ══════════════════════ 2. Équipes ══════════════════════ */

    get equipesVue() {
        return this.equipes.map((e) => ({
            ...e,
            classePastille: e.active ? 'pastille pastille-ok' : 'pastille pastille-off',
            etat: e.active ? 'Active' : 'Désactivée',
            libelleBascule: e.active ? 'Désactiver' : 'Réactiver',
            classeBascule: e.active ? 'btn btn-ghost btn-sm btn-danger' : 'btn btn-ghost btn-sm',
            membresTexte: e.membres === 1 ? '1 membre' : `${e.membres || 0} membres`
        }));
    }

    get resumeEquipes() {
        const n = this.nbEquipesActives;
        return n === 1 ? '1 équipe active' : `${n} équipes actives`;
    }

    handleOuvrirEquipes() {
        this.message = null;
        this.formEquipeOuvert = false;
        this.modaleEquipes = true;
        this._focaliser = '.modale';
    }

    handleOuvrirFormEquipe() {
        this.nouvelleEquipe = '';
        this.formEquipeOuvert = true;
        this._focaliser = '.champ-equipe';
    }

    handleAnnulerEquipe() {
        this.nouvelleEquipe = '';
        this.formEquipeOuvert = false;
    }

    /** Entrée valide la création, sans passer par la souris. */
    handleToucheEquipe(event) {
        if (event.key === 'Enter' && !this.creerEquipeDesactive) {
            event.preventDefault();
            this.handleCreerEquipe();
        }
    }

    /** Depuis la modale : « 2 membres » ouvre la liste filtrée sur l'équipe. */
    handleVoirMembres(event) {
        this.filtreEquipe = event.currentTarget.dataset.nom;
        this.filtreConnexion = '';
        this.recherche = '';
        this.handleFermerModales();
    }

    handleNouvelleEquipe(event) {
        this.nouvelleEquipe = event.target.value;
    }

    get creerEquipeDesactive() {
        return !this.nouvelleEquipe || !this.nouvelleEquipe.trim() || this.enCours;
    }

    async handleCreerEquipe() {
        const nom = (this.nouvelleEquipe || '').trim();
        await this.executer(async () => {
            const e = await creerEquipe({ nom });
            this.nouvelleEquipe = '';
            this.formEquipeOuvert = false;
            this.afficher(`Équipe « ${e.nom} » prête.`, 'success');
            await this.charger();
        });
    }

    async handleBasculerEquipe(event) {
        const cle = event.currentTarget.dataset.id;
        const active = event.currentTarget.dataset.active === 'true';
        await this.executer(async () => {
            await majEquipe({ cle, nouveauNom: null, active: !active });
            this.afficher(active ? 'Équipe désactivée.' : 'Équipe réactivée.', 'success');
            await this.charger();
        });
    }

    /* ══════════════════════ 3. Comptes ══════════════════════ */

    get equipesOptions() {
        return this.equipes
            .filter((e) => e.active)
            .map((e) => ({ cle: e.nom, libelle: e.nom }));
    }

    /** Liste du formulaire « Nouveau compte », avec l'équipe déjà choisie. */
    get equipesOptionsCompte() {
        return this.equipesOptions.map((o) => ({
            ...o,
            choisi: o.cle === this.nouveauCompte.equipe ? true : null
        }));
    }

    get optionsFiltre() {
        return [{ cle: '', libelle: 'Toutes les équipes' }].concat(
            this.equipes.map((e) => ({ cle: e.nom, libelle: e.nom }))
        ).map((o) => ({ ...o, choisi: o.cle === this.filtreEquipe ? true : null }));
    }

    /** Nom d'équipe par identifiant : l'API ne rend que l'id sur un compte. */
    get equipeParId() {
        const table = {};
        this.equipes.forEach((e) => { table[e.id] = e.nom; });
        return table;
    }

    get membresVue() {
        const noms = this.equipeParId;
        const q = (this.recherche || '').toLowerCase().trim();
        return this.membres
            .filter((m) => {
                if (this.filtreEquipe && noms[m.equipeId] !== this.filtreEquipe) return false;
                if (this.filtreConnexion === FILTRE_JAMAIS && (!m.actif || m.derniereConnexion)) return false;
                if (!q) return true;
                return `${m.email || ''} ${m.prenom || ''} ${m.nom || ''}`.toLowerCase().indexOf(q) >= 0;
            })
            .map((m) => ({
                ...m,
                equipeNom: noms[m.equipeId] || '—',
                nomComplet: `${m.prenom || ''} ${m.nom || ''}`.trim() || '—',
                initiales: this.initialesDe(m),
                classeLigne: m.actif ? '' : 'ligne-inactive',
                classeBascule: m.actif ? 'btn btn-ghost btn-sm btn-danger' : 'btn btn-ghost btn-sm',
                classePastille: m.actif ? 'pastille pastille-ok' : 'pastille pastille-off',
                etat: m.actif ? 'Actif' : 'Désactivé',
                libelleBascule: m.actif ? 'Désactiver' : 'Réactiver',
                connexion: m.derniereConnexion
                    ? new Date(m.derniereConnexion).toLocaleString('fr-FR',
                        { day: '2-digit', month: '2-digit', year: '2-digit',
                          hour: '2-digit', minute: '2-digit' })
                    : 'Jamais connecté',
                // Jamais connecté : c'est la cause n°1 d'un « je ne vois pas le
                // formulaire » — la première connexion est obligatoire.
                classeConnexion: m.derniereConnexion ? 'dim' : 'dim alerte'
            }));
    }

    get aDesMembres() {
        return this.membresVue.length > 0;
    }

    get aDesFiltres() {
        return !!(this.recherche || this.filtreEquipe || this.filtreConnexion);
    }

    get resumeListe() {
        const n = this.membresVue.length;
        const total = this.membres.length;
        const txt = n === 1 ? '1 compte' : `${n} comptes`;
        return n === total ? txt : `${txt} sur ${total}`;
    }

    get titreMotDePasse() {
        return `Remettre le mot de passe à ${MOT_DE_PASSE_INITIAL}`;
    }

    handleEffacerFiltres() {
        this.recherche = '';
        this.filtreEquipe = '';
        this.filtreConnexion = '';
    }

    /** « Test Test » -> « TT » ; à défaut de nom, les initiales de l'email. */
    initialesDe(m) {
        const src = `${m.prenom || ''} ${m.nom || ''}`.trim() || m.email || '?';
        return src.split(/[\s@.]+/).filter((x) => x).slice(0, 2)
            .map((x) => x.charAt(0).toUpperCase()).join('');
    }

    handleFiltreEquipe(event) {
        this.filtreEquipe = event.target.value;
    }

    handleRecherche(event) {
        this.recherche = event.target.value;
    }

    handleOuvrirNouveauCompte() {
        this.message = null;
        // L'équipe filtrée est le choix le plus probable : on la pré-remplit.
        const equipe = this.equipesOptions.some((o) => o.cle === this.filtreEquipe) ? this.filtreEquipe : '';
        this.nouveauCompte = { ...COMPTE_VIDE, equipe };
        this.modaleCompte = true;
        this._focaliser = '.champ-email';
    }

    handleSaisieCompte(event) {
        const champ = event.target.dataset.champ;
        this.nouveauCompte = { ...this.nouveauCompte, [champ]: event.target.value };
    }

    get creerCompteDesactive() {
        const c = this.nouveauCompte;
        return !c.email || !c.email.trim() || !c.equipe || this.enCours;
    }

    get motDePasseInitial() {
        return MOT_DE_PASSE_INITIAL;
    }

    async handleCreerCompte() {
        const c = this.nouveauCompte;
        await this.executer(async () => {
            const m = await creerCompte({
                email: c.email.trim(),
                motDePasse: MOT_DE_PASSE_INITIAL,
                prenom: c.prenom,
                nom: c.nom,
                equipe: c.equipe,
                telephone: c.telephone
            });
            this.nouveauCompte = { ...COMPTE_VIDE };
            this.modaleCompte = false;
            this.afficher(`Compte créé : ${m.email}`, 'success');
            await this.charger();
        });
    }

    async handleBasculerCompte(event) {
        const cle = event.currentTarget.dataset.id;
        const actif = event.currentTarget.dataset.actif === 'true';
        await this.executer(async () => {
            await majCompte({ cle, motDePasse: null, equipe: null, actif: !actif });
            this.afficher(actif ? 'Compte désactivé.' : 'Compte réactivé.', 'success');
            await this.charger();
        });
    }

    async handleReinitialiser(event) {
        const cle = event.currentTarget.dataset.id;
        await this.executer(async () => {
            await majCompte({ cle, motDePasse: MOT_DE_PASSE_INITIAL, equipe: null, actif: null });
            this.afficher(`Mot de passe remis à « ${MOT_DE_PASSE_INITIAL} » pour ${cle}.`, 'success');
        });
    }

    async handleDeplacer(event) {
        const cle = event.currentTarget.dataset.id;
        const equipe = event.target.value;
        if (!equipe) return;
        await this.executer(async () => {
            await majCompte({ cle, motDePasse: null, equipe, actif: null });
            this.afficher(`${cle} déplacé vers « ${equipe} ».`, 'success');
            await this.charger();
        });
    }

    /* ══════════════════════ Modales ══════════════════════ */

    handleFermerModales() {
        this.modaleEquipes = false;
        this.modaleCompte = false;
        this.formEquipeOuvert = false;
    }

    handleToucheModale(event) {
        if (event.key !== 'Escape') return;
        event.stopPropagation();
        // Échap referme d'abord le formulaire d'équipe, puis la modale.
        if (this.formEquipeOuvert) this.handleAnnulerEquipe();
        else this.handleFermerModales();
    }

    /* ══════════════════════ Outils ══════════════════════ */

    async executer(action) {
        this.enCours = true;
        this.message = null;
        try {
            await action();
        } catch (e) {
            this.afficher(this.messageDe(e), 'error');
        } finally {
            this.enCours = false;
        }
    }

    afficher(message, type) {
        this.message = message;
        this.typeMessage = type || 'info';
        clearTimeout(this._minuteurMessage);
        if (type === 'success') {
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            this._minuteurMessage = setTimeout(() => {
                if (this.message === message) this.message = null;
            }, DUREE_SUCCES);
        }
    }

    /** Code serveur -> phrase. « CERTIKO_REFUS:… » porte le détail de Certiko. */
    messageDe(erreur) {
        const brut = (erreur && erreur.body && erreur.body.message)
            || (erreur && erreur.message) || '';
        if (brut.indexOf('CERTIKO_REFUS:') === 0) {
            return `Certiko a refusé : ${brut.slice('CERTIKO_REFUS:'.length)}`;
        }
        return ERREURS[brut] || brut || 'Une erreur est survenue.';
    }
}