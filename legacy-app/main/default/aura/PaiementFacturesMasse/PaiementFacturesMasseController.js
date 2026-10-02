({
    // À chaque navigation vers la page, le LWC est démonté puis remonté :
    // il repart d'un état vierge et recharge ses données depuis le serveur
    // (les méthodes Apex ne sont pas cacheables), donc aucune liste obsolète.
    handlePageReferenceChange: function (component) {
        component.set("v.actif", false);
        window.setTimeout($A.getCallback(function () {
            if (component.isValid()) {
                component.set("v.actif", true);
            }
        }), 0);
    }
})