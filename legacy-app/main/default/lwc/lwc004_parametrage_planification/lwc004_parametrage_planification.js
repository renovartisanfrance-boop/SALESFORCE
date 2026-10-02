import { LightningElement , track , api , wire } from 'lwc';
import getplanification_metadata from '@salesforce/apex/Planification_Controller.getplanification_metadata';
import addplanification_metadata from '@salesforce/apex/Planification_Controller.addplanification_metadata';
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { refreshApex } from '@salesforce/apex';

export default class Lwc004_parametrage_planification extends LightningElement {
   
   
    @api sendDataToParent() {
        const data = false;
        const event = new CustomEvent('senddata', { detail:
            { index_1 : data , _planification_metadata : JSON.parse(this._prettyjson)}
         });
        this.dispatchEvent(event);
    }

    @api _planification_metadata;
    _prettyjsonp;
    connectedCallback()
    {
        this._prettyjson = JSON.stringify(this._planification_metadata, undefined, 4);
    }

    json_input_change(event)
    {
        this._prettyjson = event.target.value;
    }
    
    spinner = false;
    handelclick_enregitrer_metadata()
    {
        this.spinner = true;
        addplanification_metadata({ Parametrage_planification_all_value : JSON.parse(this._prettyjson)}
        ).then(data => {
           
            const event = new ShowToastEvent({
                title: 'Succès',
                message: "Paramétrage bien enregistré",
                variant: 'success'
                });
                this.dispatchEvent(event);  
                this._prettyjson = JSON.stringify(data, undefined, 4);
                this.spinner = false;

        }).catch(error => {
            console.log(error);
            this.spinner = false;
        });

      
    }


       //    const milliseconds = 38700000;

        //     const seconds = Math.floor(milliseconds / 1000);
        //     const minutes = Math.floor(seconds / 60);
        //     const hours = Math.floor(minutes / 60);

        //     const formattedTime = '${hours % 24}:${minutes % 60}:${seconds % 60}';
        //     console.log(hours + '/' + minutes);


        
    // _prettyjson;
    // _planification_metadata;
    // @wire(getplanification_metadata)
    // wiredgetplanification_metadata({ error, data })
    // {
    //    // alert("hi");
    //     if (data) {
    //         console.log(data);
    //         this._planification_metadata = data;
    //         this._prettyjson = JSON.stringify(this._planification_metadata, undefined, 4);
    //     }
    //     else if (error) {
    //         console.error(error);
    //     }
    // }



}