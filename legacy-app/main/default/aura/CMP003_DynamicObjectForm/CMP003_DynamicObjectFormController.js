({
    myAction : function(component, event, helper) {

    },
    handleClose : function(component, event, helper) {
        // Handle the click event
        console.log('Button clicked in CMP003_DynamicObjectForm');
        $A.get("e.force:closeQuickAction").fire();
        // You can add more logic here if needed
    }
})