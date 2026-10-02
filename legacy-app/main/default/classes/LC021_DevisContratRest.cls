/**
 * LC021_DevisContratRest — sert le contrat de devis JOINT à une Piste ou un
 * Dossier, en flux PDF affichable.
 *
 * POURQUOI CE DÉTOUR — l'aperçu de la modale de devis est un <iframe>. Dans le
 * site Campagnes, la CSP n'admet pas `blob:` dans frame-src : le PDF coché
 * généré côté client s'ouvre très bien dans un onglet, mais pas dans l'aperçu.
 * Le composant joint donc d'abord le PDF coché au record
 * (LC021_DevisSignature.enregistrerContrat), puis l'iframe pointe ICI : une URL
 * même-origine (/services/apexrest/…) que la CSP accepte, et qui renvoie les
 * octets du fichier STOCKÉ avec `Content-Disposition: inline` — c'est cet
 * en-tête, que le servlet de fichiers standard ne garantit pas, qui fait
 * afficher le PDF au lieu de le télécharger.
 *
 * Appel depuis le site :
 *   GET /Campagnes/services/apexrest/devis/contrat?recordId=...&token=...
 *
 * Sécurité — mêmes verrous applicatifs que tout le workflow, délégués à
 * LC021_DevisSignature.lireContratStocke : token de campagne valide, record de
 * type supporté ET dans le périmètre du token. L'endpoint ne sert QUE le
 * document de contrat lié à ce record (titre fixe), jamais un fichier
 * arbitraire ; toute anomalie renvoie la même réponse 404, sans révéler si le
 * record existe.
 */
@RestResource(urlMapping='/devis/contrat')
global without sharing class LC021_DevisContratRest {

    @HttpGet
    global static void getContrat() {
        RestResponse res = RestContext.response;
        if (res == null) {
            res = new RestResponse();
            RestContext.response = res;
        }
        Map<String, String> params =
            (RestContext.request != null && RestContext.request.params != null)
                ? RestContext.request.params
                : new Map<String, String>();

        try {
            Blob pdf = LC021_DevisSignature.lireContratStocke(
                params.get('recordId'),
                params.get('token')
            );
            res.statusCode = 200;
            res.addHeader('Content-Type', 'application/pdf');
            res.addHeader('Content-Disposition',
                'inline; filename="' + LC021_DevisSignature.NOM_FICHIER_CONTRAT + '"');
            // Le fichier change à chaque nouvelle version : ne pas laisser un
            // aperçu périmé en cache navigateur.
            res.addHeader('Cache-Control', 'no-store');
            res.responseBody = pdf;
        } catch (Exception e) {
            // Réponse UNIQUE quelle que soit la cause (token invalide, record
            // hors périmètre, contrat absent) : ne rien apprendre à un appelant
            // qui sonde des Ids.
            res.statusCode = 404;
            res.addHeader('Content-Type', 'application/json; charset=UTF-8');
            res.responseBody = Blob.valueOf(JSON.serialize(
                new Map<String, String>{ 'error' => 'Document indisponible.' }
            ));
        }
    }
}