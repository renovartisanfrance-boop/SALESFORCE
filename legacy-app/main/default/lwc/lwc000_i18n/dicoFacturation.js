/**
 * dicoFacturation — onglet Facturation et ses sous-composants
 * (lwc020_Facturation, ...EnCours, ...Payees, ...Table).
 *
 * Les clés col_<key> surchargent les libellés de colonnes définis dans
 * c/lwc020_FacturationUtils (COLONNES_EN_COURS / COLONNES_PAYEES /
 * COLONNES_PARTENAIRE). La clé est le `key` de la colonne, pas son libellé :
 * un renommage côté FR ne casse donc pas la traduction.
 *
 * Notes métier :
 *  - « Montant HT » -> « Importe sin IVA » (et non « base imponible », plus
 *    comptable que lisible pour un partenaire).
 *  - « Total TTC » -> « Total con IVA ».
 *  - « Échéance » -> « Vencimiento », terme standard de facturation.
 *  - « À payer » -> « Pendiente de pago » : côté partenaire c'est une somme
 *    qu'il va RECEVOIR, « por pagar » laisserait croire qu'il doit payer.
 */
export const DICO_FACTURATION = {
    fr: {
        titreFacturation: 'Facturation',
        ongletEnCours: 'En cours',
        ongletPayees: 'Payées',

        titreEnCours: 'Paiements en cours',
        titrePayees: 'Factures payées',
        sousTitrePayees: 'Historique des règlements reçus',
        chargementEnCours: 'Chargement de vos paiements en cours...',
        chargementPayees: 'Chargement de vos factures payées...',

        actualiser: 'Actualiser',
        filtresRecherche: 'Filtres de recherche',

        pretAFacturer: 'Prêt à facturer',
        aPayer: 'À payer',
        paye: 'Payé',

        // Replis affichés quand la valeur est vide
        repliNumero: '🕛Att. facture',
        repliPrevu: '🕛En Att',

        // Libellés de colonnes (clé = `key` de la colonne)
        col_numero: 'N° Facture',
        col_prevu: 'Paiement prévu',
        col_dossier: 'Nom',
        col_montant: 'Montant HT',
        col_ttc: 'Total TTC',
        col_date: 'Date facture',
        col_ech: 'Échéance',
        col_fiche: 'Fiche',
        col_paye: 'Payé le',
        col_install: 'Date installation',
        col_statut: 'Paiement',

        // Vue partenaire (accès réduit)
        titrePartenaire: 'Facturation / Contrat',
        sousTitrePartenaire: 'Vos dossiers et leur état de paiement',
        chargementPartenaire: 'Chargement de vos dossiers...',
        titreInfoPremier: 'Pour votre premier paiement',
        titreInfoSuivants: 'Pour vos prochains paiements',
        infoIntro: 'Merci de nous transmettre par e-mail à',
        pieceDemande: 'Votre demande de paiement, en précisant votre nom de parrain et le nom de votre filleul ;',
        pieceContrat: 'Votre contrat de parrainage rempli et signé (',
        pieceContratLien: 'à télécharger ici',
        // Ponctuation fermante de la mention « contrat » : le français insère une
        // espace avant le point-virgule, l'espagnol non — d'où une clé et non un
        // littéral partagé.
        pieceContratApres: ') ;',
        pieceRib: 'Votre RIB.',
        pieceRibChangement: "Merci de nous alerter s'il y a eu un changement de RIB depuis le dernier règlement.",
        infoSuite: 'Dès réception de ces documents, votre dossier pourra être traité.',
        // Le délai est coupé en trois : sa valeur est mise en gras dans le
        // template, elle ne peut donc pas vivre au milieu d'une phrase entière.
        infoDelaiAvant: 'Le paiement de votre prime sera effectué dans un délai de',
        infoDelaiValeur: '10 jours',
        infoDelaiApres: "suivant l'installation de votre filleul.",

        // États vides et tableau
        messageVide: 'Aucune facture à afficher.',
        // Le partenaire raisonne en dossiers, pas en factures.
        messageVidePartenaire: 'Aucun dossier à afficher pour le moment.',
        aucuneLigneFiltre: 'Aucune ligne ne correspond aux filtres sélectionnés.',
        uniteFacture: 'facture(s)',
        uniteLigne: 'ligne(s)',
        actualisation: 'Actualisation...',

        // Chargements partiels et troncatures
        srcLignes: 'les dossiers pas encore facturés',
        srcImpayees: 'les factures non réglées',
        srcPayees: 'les factures déjà réglées',
        errPartielle: 'Impossible de charger {sources}. Le tableau ci-dessous est donc incomplet.',
        troncRecentes: 'Seules les factures les plus récentes sont affichées.',
        troncLignesFacture: 'Volume de lignes très important : les dernières factures de la liste peuvent apparaître sans leur dossier.',
        troncLignesCompte: 'Volume important de lignes sur ce compte : certains dossiers déjà facturés peuvent apparaître ici à tort. Rapprochez-vous du service facturation.',
        errCalculPrets: "Les dossiers prêts à être facturés n'ont pas pu être calculés. Seules les factures déjà créées sont affichées.",
        errChargementFactures: "Vos factures n'ont pas pu être chargées. Seuls les dossiers prêts à être facturés sont affichés.",
        totauxCompte: 'Les totaux « du compte » ci-dessus portent sur l\'intégralité du compte.',
        totalCompte: 'Le total « du compte » ci-dessus porte sur l\'intégralité du compte.',
        // Joint les sources en échec : « A et B ». L'espagnol emploie « y ».
        joignantEt: ' et '
    },
    es: {
        titreFacturation: 'Facturación',
        ongletEnCours: 'En curso',
        ongletPayees: 'Pagadas',

        titreEnCours: 'Pagos en curso',
        titrePayees: 'Facturas pagadas',
        sousTitrePayees: 'Historial de cobros recibidos',
        chargementEnCours: 'Cargando sus pagos en curso...',
        chargementPayees: 'Cargando sus facturas pagadas...',

        actualiser: 'Actualizar',
        filtresRecherche: 'Filtros de búsqueda',

        pretAFacturer: 'Listo para facturar',
        aPayer: 'Pendiente de pago',
        paye: 'Pagado',

        repliNumero: '🕛Pdte. factura',
        repliPrevu: '🕛Pendiente',

        col_numero: 'N.º de factura',
        col_prevu: 'Pago previsto',
        col_dossier: 'Nombre',
        col_montant: 'Importe sin IVA',
        col_ttc: 'Total con IVA',
        col_date: 'Fecha de factura',
        col_ech: 'Vencimiento',
        col_fiche: 'Ficha',
        col_paye: 'Pagada el',
        col_install: 'Fecha de instalación',
        col_statut: 'Pago',

        titrePartenaire: 'Facturación / Contrato',
        sousTitrePartenaire: 'Sus expedientes y su estado de pago',
        chargementPartenaire: 'Cargando sus expedientes...',
        titreInfoPremier: 'Para su primer cobro',
        titreInfoSuivants: 'Para sus próximos cobros',
        infoIntro: 'Le rogamos que nos envíe por correo electrónico a',
        pieceDemande: 'Su solicitud de cobro, indicando su nombre de prescriptor y el nombre de su referido;',
        pieceContrat: 'Su contrato de prescripción cumplimentado y firmado (',
        pieceContratLien: 'descargar aquí',
        pieceContratApres: ');',
        // « RIB » est un document propre à la France : côté espagnol on demande
        // les coordonnées bancaires, identifiées par l'IBAN.
        pieceRib: 'Sus datos bancarios (IBAN).',
        pieceRibChangement: 'Le rogamos que nos avise si sus datos bancarios han cambiado desde el último pago.',
        infoSuite: 'Una vez recibidos estos documentos, su expediente podrá tramitarse.',
        infoDelaiAvant: 'El pago de su prima se realizará en un plazo de',
        infoDelaiValeur: '10 días',
        infoDelaiApres: 'tras la instalación de su referido.',

        messageVide: 'No hay facturas que mostrar.',
        messageVidePartenaire: 'No hay expedientes que mostrar por el momento.',
        aucuneLigneFiltre: 'Ninguna línea coincide con los filtros seleccionados.',
        uniteFacture: 'factura(s)',
        uniteLigne: 'línea(s)',
        actualisation: 'Actualizando...',

        srcLignes: 'los expedientes aún no facturados',
        srcImpayees: 'las facturas pendientes de cobro',
        srcPayees: 'las facturas ya cobradas',
        errPartielle: 'No se han podido cargar {sources}. La tabla siguiente está incompleta.',
        troncRecentes: 'Solo se muestran las facturas más recientes.',
        troncLignesFacture: 'Volumen de líneas muy elevado: las últimas facturas de la lista pueden aparecer sin su expediente.',
        troncLignesCompte: 'Volumen elevado de líneas en esta cuenta: algunos expedientes ya facturados pueden aparecer aquí por error. Póngase en contacto con el servicio de facturación.',
        errCalculPrets: 'No se han podido calcular los expedientes listos para facturar. Solo se muestran las facturas ya creadas.',
        errChargementFactures: 'No se han podido cargar sus facturas. Solo se muestran los expedientes listos para facturar.',
        totauxCompte: 'Los totales «de la cuenta» indicados arriba abarcan la totalidad de la cuenta.',
        totalCompte: 'El total «de la cuenta» indicado arriba abarca la totalidad de la cuenta.',
        joignantEt: ' y '
    }
};