import { LightningElement , api , wire} from 'lwc';
import {getRecord , updateRecord } from 'lightning/uiRecordApi';
import Conges_planification from "@salesforce/schema/Camion__c.CongesPlanification__c";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

const fieldsFormatted = ['Camion__c.CongesPlanification__c'];

export default class Lwc004_conges_planification extends LightningElement {


    @api get_prettyjson_week;
    @api id_acteur;
    @api menu_selected;
    Conges_planification_value = [];
    connectedCallback()
    {
        console.log( this.menu_selected );
        console.log( '++++++>>>>>>>>>>>>>>>' );
       console.log(this.get_prettyjson_week);
       console.log( '++++++>>>>>>>>>>>>>>>' );



    }

    @wire(getRecord, { recordId: '$id_acteur', fields: fieldsFormatted })
    wireconges({data, error}) {
        if(data) {
            if(data.fields.CongesPlanification__c.value != null)
            {
                this.Conges_planification_value = data.fields.CongesPlanification__c.value.split(',');
                console.log(this.Conges_planification_value);
                var checkboxes = this.template.querySelectorAll('input[name="time_selected"]');
                var checkedValues = [];
                var Conges_planification_value_value =  this.Conges_planification_value;
              
                checkboxes.forEach(function(checkbox) { 
                  for(let i = 0 ; i <  Conges_planification_value_value.length ; i++)
                  {
                    if(Conges_planification_value_value[i] == checkbox.value)
                    {
                        checkbox.checked = true;
                        break;
                    }
                  }
                //  checkedValues.push(checkbox.value);
                });
            }
        }
        else
        {
            console.log(error);
        }
    }

    // get_record()
    // {
    //     getRecord({recordId:  this.id_acteur , fields: fieldsFormatted})
    //     .then((data) => {
    //      this.Conges_planification_value = data;
    //      console.log(his.Conges_planification_value);
    //     }).catch((error) => {
    //      console.log(error);
    //     });
    // }


    get get_prettyjson_week_get()
    {
        return  this.get_prettyjson_week;
    }

    handleFermer(event) {
        this.dispatchEvent(new CustomEvent('fermer', {
          detail: false
        }));
      }


      updateConges()
      {
      
        const fields = {};
        fields.Id = this.id_acteur;
        fields[Conges_planification.fieldApiName] = this.Conges_planification_value.toString();
        const recordInput = { fields };
        updateRecord(recordInput)
                .then(() => {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: "Success",
                            message: "Absence bien enregistrée",
                            variant: "success"
                        })
                    );
                    this.handleFermer();
                })
                .catch((error) => {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: "Error absence enregistrée",
                            message: error.body.message,
                            variant: "error"
                        })
                    );
                });
       // this.handleFermer();
      }

      proxyToObj(obj){
        return JSON.parse(JSON.stringify(obj));
     }



     checkedValues_fin;


     onchange_checked(event)
     {
        if(this.Conges_planification_value.length > 0)
        {
            for(let i = 0 ; i <  this.Conges_planification_value.length ; i++)
            {
            if(this.Conges_planification_value[i] == event.currentTarget.value && event.currentTarget.checked == false)
            {
                this.Conges_planification_value = this.Conges_planification_value.filter(item => item !=  event.currentTarget.value)
                break;
            }
            else if(event.currentTarget.checked == true)
            {
                this.Conges_planification_value.push(event.currentTarget.value);
                break;
            }
            }
        }
        else
        {
            if(event.currentTarget.checked == true)
            {
                this.Conges_planification_value.push(event.currentTarget.value);
            }
        }
      
     }

     
     getCheckedValues() {
        var checkboxes = this.template.querySelectorAll('input[name="time_selected"]:checked');
        var checkedValues = [];
      
        checkboxes.forEach(function(checkbox) {
          checkedValues.push(checkbox.value);
        });
      
        if (checkedValues.length > 0) {
            return checkedValues;
          console.log("Checked values:", checkedValues);
        } else {
            return 0;
          console.log("No checkboxes are checked.");
        }
      }
   
}