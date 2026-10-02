/**
 * YS_TestMock — bouchon HTTP partagé par les tests Yousign.
 *
 * POURQUOI UN BOUCHON UNIQUE ET ROUTEUR — Salesforce n'accepte qu'un seul
 * Test.setMock par test, or les triggers Lead et Pro__c de cette org émettent
 * eux-mêmes des appels sortants (géocodage, SMS, synchronisation). Un bouchon
 * qui ne répondrait qu'à Yousign ferait échouer la simple insertion d'une Piste.
 * Celui-ci répond donc à tout, en aiguillant sur l'URL appelée.
 *
 * Il conserve aussi les requêtes reçues : c'est le seul moyen de vérifier que le
 * corps multipart envoyé à Yousign est bien formé.
 */
@isTest
public class YS_TestMock implements HttpCalloutMock {

    /** Toutes les requêtes vues, dans l'ordre — pour les assertions. */
    public List<HttpRequest> requetes = new List<HttpRequest>();

    /** Identifiants renvoyés par le faux Yousign. */
    public String demandeId  = 'sr_test_0001';
    public String documentId = 'doc_test_0001';

    /** Statut renvoyé par GET /signature_requests/{id}. */
    public String statut = 'ongoing';

    /** Si renseigné, TOUS les appels Yousign échouent avec ce code. */
    public Integer codeErreur = null;
    /** Corps renvoye avec codeErreur — pour verifier ce que l'ecran en fait. */
    public String corpsErreur = '{"detail":"Refus simulé par le test."}';

    /** Corps du PDF signé renvoyé par le téléchargement. */
    public Blob pdfSigne = Blob.valueOf('%PDF-1.4 signe');

    public HttpResponse respond(HttpRequest requete) {
        String url = requete.getEndpoint();

        // ── Appels sortants des triggers de l'org, hors sujet ici ────────────
        if (url == null || !url.contains('yousign')) {
            HttpResponse autre = new HttpResponse();
            autre.setStatusCode(200);
            autre.setHeader('Content-Type', 'application/json');
            // Le géocodage des Dossiers désérialise en LISTE, les autres en objet.
            autre.setBody(url != null && url.contains('nominatim') ? '[]' : '{"success":true}');
            return autre;
        }

        requetes.add(requete);

        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');

        if (codeErreur != null) {
            res.setStatusCode(codeErreur);
            res.setBody(corpsErreur);
            return res;
        }

        if (url.endsWith('/documents/download')) {
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/pdf');
            res.setBodyAsBlob(pdfSigne);
            return res;
        }
        if (url.endsWith('/activate')) {
            res.setStatusCode(200);
            res.setBody('{"id":"' + demandeId + '","status":"ongoing"}');
            return res;
        }
        if (url.endsWith('/documents')) {
            res.setStatusCode(201);
            res.setBody('{"id":"' + documentId + '"}');
            return res;
        }
        if (url.endsWith('/signers')) {
            res.setStatusCode(201);
            res.setBody('{"id":"signer_test_0001"}');
            return res;
        }
        if (url.endsWith('/signature_requests')) {
            res.setStatusCode(201);
            res.setBody('{"id":"' + demandeId + '","status":"draft"}');
            return res;
        }
        // GET /signature_requests/{id}
        res.setStatusCode(200);
        res.setBody('{"id":"' + demandeId + '","status":"' + statut + '"}');
        return res;
    }

    /** Première requête dont l'URL se termine par ce suffixe, ou null. */
    public HttpRequest requetePour(String suffixe) {
        for (HttpRequest r : requetes) {
            if (r.getEndpoint() != null && r.getEndpoint().endsWith(suffixe)) return r;
        }
        return null;
    }
}