({
    doInit: function (component, event, helper) {
        var rtId = null;
        var pageRef = component.get("v.pageReference");
        if (pageRef && pageRef.state && pageRef.state.recordTypeId) {
            rtId = pageRef.state.recordTypeId;
        }
        if (!rtId) {
            try {
                var url = window.location.href;
                var m = url.match(/recordTypeId=([0-9a-zA-Z]{15,18})/);
                if (m) rtId = m[1];
            } catch (e) {}
        }
        if (rtId && rtId !== component.get("v.recordTypeId")) {
            component.set("v.recordTypeId", rtId);
        }
    }
})