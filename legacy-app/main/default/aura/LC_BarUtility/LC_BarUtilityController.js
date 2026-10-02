({
    openForm : function (cmp, event, helper) {
        //alert("You clicked: " + event.getSource().get("v.label"));
        //document.getElementById("myForm").style.display = "block";
        //document.querySelector('.AirCall-bloc').style.display = "block"; 
        document.querySelector('.AirCall-bloc').classList.add("AirCallBlock");
        document.querySelector('.AirCall-bloc').classList.remove("AirCallRemove");
    },

    closeForm : function (cmp, event, helper) {
        //alert("You clicked: " + event.getSource().get("v.label"));
        //document.getElementById("myForm").style.display = "block";
        //document.querySelector('.AirCall-bloc').style.display = "none";
        document.querySelector('.AirCall-bloc').classList.remove("AirCallBlock");
        document.querySelector('.AirCall-bloc').classList.add("AirCallRemove"); 
    }

});