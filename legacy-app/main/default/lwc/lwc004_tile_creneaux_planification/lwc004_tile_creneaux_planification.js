import { LightningElement , api } from 'lwc';
import get_planification_cible_tile from '@salesforce/apex/Planification_Controller.get_planification_cible_tile';
import lien_org_planification from '@salesforce/label/c.lien_org_planification';
import getDurationsDaily from '@salesforce/apex/Planification_Controller.getDurationsDaily';
import TIME_ZONE from '@salesforce/i18n/timeZone';

export default class Lwc004_tile_creneaux_planification extends LightningElement {

    daysWorking = [
        // Nath
        // { day : 1, dateDiff : 3},
        // { day : 2, dateDiff : 2},
        // { day : 3, dateDiff : 5},
        // { day : 4, dateDiff : 5},
        // { day : 5, dateDiff : 4},
        // { day : 6, dateDiff : 1},
        // { day : 0, dateDiff : 0},
        // Mickael
        { day : 1, dateDiff : 30},
        { day : 2, dateDiff : 30},
        { day : 3, dateDiff : 30},
        { day : 4, dateDiff : 30},
        { day : 5, dateDiff : 30},
        { day : 6, dateDiff : 30},
        { day : 0, dateDiff : 30},
    ]

    @api daysOff = "";

    get isDayOff() {
        let dateCr = this.date_crenaux;
        let dateEvent = this.list_event.length ? this.list_event[0]?.[this.api_name_date_planification] || null : null;
        console.log('dateEvent', dateEvent);
        console.log('date_crenaux_vraie  ', this.date_crenaux_vraie);
        return this.daysOff.split(',')?.map(e => e.trim())?.some(e => dateCr?.toLowerCase().includes(e));
    }

    get noEventExists(){
        let dateEvent = this.list_event.length ? this.list_event[0]?.[this.api_name_date_planification] || null : null;
        return dateEvent == null || dateEvent == undefined || dateEvent == '';
    }

    get isInWorkingIntervalle() {
        try{
            let strDateCr = this.date_crenaux?.split(" ")[1]; // mercredi [05/02/2025];
            let dateParts = strDateCr.split('/').map(e => +e);
            // console.log('dateParts', JSON.stringify(dateParts));
            let dateCr = new Date(dateParts[2], dateParts[1] - 1, dateParts[0], 8, 0, 0, 0);
            let today = new Date(new Date().setHours(8, 0, 0, 0));
            // let today = new Date(new Date(2025, 1, 11).setHours(8, 0, 0, 0));
            let day = today.getDay();

            // differnce in days
            let diff = Math.floor((dateCr - today) / (1000 * 60 * 60 * 24));
            // console.log('dateCr', dateCr);
            // console.log('diff', diff);
            // console.log('-----------------------');
            if(diff < 0) {
                return false;
            } else {
                // let day = dateCr.getDay();
                let workingDay = this.daysWorking.find(e => e.day == day);
                // console.log('diff', day);
                console.log('day', day, ' | dateParts', JSON.stringify(strDateCr.split('/').map(e => +e)), ' | workingDay.dateDiff', workingDay.dateDiff, ' | diff', diff);

                if(diff <= workingDay.dateDiff) {
                    return true;
                } else {
                    return false;
                }
            }
        } catch(e){
            console.error('Error in isInWorkingIntervalle', e);
            return false;
        }
    }

    get styleTile(){
        return (this.isDayOff || !this.isInWorkingIntervalle) && !this.event_remplis ? 'background:rgb(133, 133, 133);opacity: 0.52;' : '';
        return this.isDayOff || ( !this.isInWorkingIntervalle && this.noEventExists) ? 'background:rgb(133, 133, 133);opacity: 0.52;' : '';
        // return this.isDayOff || !this.isInWorkingIntervalle ? 'background:rgb(133, 133, 133);opacity: 0.52;' : '';
    }


    @api date_crenaux;
    @api badge;
    @api value_crenaux;
    @api option;
    @api acteur_id;
    @api api_name_date_planification;
    @api api_name_object_cible;
    @api api_name_relation_object_cible_to_acteur;
    @api condition_object_cible;
    @api api_champs_a_afficher;
    @api api_name_badge;
    @api condition_object_cible_couleur;
    @api list_event;
    @api search;
    @api crenaux_all;
    @api cas_exception;
    @api position_creneaux;
    @api duration_postaux;
    @api duration_postaux_deaily;
    @api api_champs_a_info_supl;
    @api name_champs_a_info_supl;
    @api api_champs_a_afficher_a_cote_date;
    @api conges_champs_text_long_api_name;
    date_crenaux_vraie;
    @api is_community;
    @api coodone_atitude_longitude;
    timezone = TIME_ZONE;

    event_exist = true;
    label = {
      lien_org_planification,
  };

    get get_global_option()
    {
        return this.option == "global" ? true : false ;
    }
    get get_option_option()
    {
        return this.option == "option" ? true : false ;
    }

    get get_value_a_afficher_info_supp()
    {
       return  this.name_champs_a_info_supl != null && this.name_champs_a_info_supl != '' ? true : false;
    }
    
    value_a_afficher_global = "00:00:00";
    //lien_org_planification
    value_a_afficher = '';
    value_a_afficher_info_supp = '';
    value_a_afficher_cote_date = '';
    lien_to_object_cible;
    event_remplis = false;
    value_a_afficher_before;
    value_a_afficher_after;


    date_crenaux_opt;

    get isBadge(){
        return this.badge != null && this.badge != '';
    }

    connectedCallback()
    {
      
        this.index_semaine++;
         setTimeout(() => {
            this.date_crenaux_opt =  this.date_crenaux.split(' ')[1];
            this.spinner = false;
            var dates;
              
               if(this.list_event !=  '')
                 {
                 
                    if(this.cas_exception == true)
                    {
                         var list_event_filter = this.list_event.filter(item => this.date_apex_to_js_date(item[this.api_name_date_planification]) == this.dateyime_to_date(this.date_crenaux));

                            // if( list_event_filter[this.position_creneaux][this.condition_object_cible_couleur[0].column_api_name]  == this.condition_object_cible_couleur[0].column_api_value)
                            // {
                            //     requestAnimationFrame(() => {
                            //         this.template.querySelector(".creneaux").style.background = this.condition_object_cible_couleur[0].couleur;
                            //         this.template.querySelector(".creneaux > a").style.color = "black";
                            //         // this.template.querySelector(".creneaux > a").style.color = "white";
                            //         // this.template.querySelector(".creneaux").style.color = "white";
                            //         });
                            // }
                            // else
                            // {
                            // requestAnimationFrame(() => {
                            //     this.template.querySelector(".creneaux").style.background = this.condition_object_cible_couleur[1].couleur;
                            //     this.template.querySelector(".creneaux > a").style.color = "black";
                            //     // this.template.querySelector(".creneaux > a").style.color = "white";
                            //     // this.template.querySelector(".creneaux").style.color = "white";
                            // });
                            // }
                             
                              for(let s = 0 ; s < this.condition_object_cible_couleur.length ; s++)
                                {  
                                  

                                    if( list_event_filter[this.position_creneaux][this.condition_object_cible_couleur[s].column_api_name]  == this.condition_object_cible_couleur[s].column_api_value   || (this.condition_object_cible_couleur[s].column_api_value == 'is_blank' && list_event_filter[this.position_creneaux][this.condition_object_cible_couleur[s].column_api_name] == undefined)) 
                                    {
                                          console.log('=--==--=-=-=-=-=-=-===-=-===-===-==-=');
                                            console.log( list_event_filter[this.position_creneaux][this.condition_object_cible_couleur[s].column_api_name] != null + '=='  + this.condition_object_cible_couleur[s].column_api_value);
                                            console.log('=--==--=-=-=-=-=-=-===-=-===-===-==-=');
                                        requestAnimationFrame(() => {
                                          
                                            if( this.condition_object_cible_couleur[s].couleur.split(';').length > 1)
                                            {
                                                  this.template.querySelector(".creneaux").style.background = this.condition_object_cible_couleur[s].couleur.split(';')[0];
                                                  this.template.querySelector(".creneaux > a").style.color = this.condition_object_cible_couleur[s].couleur.split(';')[1];
                                            }
                                            else
                                            {
                                                  this.template.querySelector(".creneaux").style.background = this.condition_object_cible_couleur[s].couleur;
                                                  this.template.querySelector(".creneaux > a").style.color = "black";

                                            }
                                            // this.template.querySelector(".creneaux > a").style.color = "white";
                                            // this.template.querySelector(".creneaux").style.color = "white";
                                            });
                                            break;
                                    }
                                }        

                            //this.lien_to_object_cible = this.label.lien_org_planification +  list_event_filter[this.position_creneaux].Id + '/view';
                          //   console.log( '+++++++++++++>>> ' + this.is_community  +'+++++++++' +  (window.location.href).split('/s/')[0] + '/s/detail/');
                           this.lien_to_object_cible =  this.is_community == false ? this.label.lien_org_planification +  list_event_filter[this.position_creneaux].Id + '/view' :  (window.location.href).split('/s/')[0] + '/s/detail/' + list_event_filter[this.position_creneaux].Id;

                            let tb = this.api_champs_a_afficher.split(',');
                            this.value_a_afficher = '';
                            for(let j = tb.length -1 ; j >= 0 ; j--)
                            {
                                if(!this.condition_object_cible_couleur.map((obj) => obj.column_api_name).includes(tb[j].replace(/\s/g,'')))
                                     this.value_a_afficher +=' ' +  list_event_filter[this.position_creneaux][tb[j].replace(/\s/g,'')];
                            }
                            // Badge Abdessamad
                            this.badge = list_event_filter[this.position_creneaux][this.api_name_badge];

                            // this.date_crenaux_vraie = (parseInt((list_event_filter[this.position_creneaux][this.api_name_date_planification]).split('T')[1].split('.')[0].split(':')[0]) + 2) + 'H' +(list_event_filter[this.position_creneaux][this.api_name_date_planification]).split('T')[1].split('.')[0].split(':')[1];

                            let tb_2 = this.api_champs_a_info_supl.split(',');
                            let tb_3 = this.name_champs_a_info_supl.split(',');
                            for(let j = tb_2.length -1 ; j >= 0 ; j--)
                            {
                                this.value_a_afficher_info_supp +=' -' + tb_3[j].replace(/\s/g,'') +': ' + (list_event_filter[this.position_creneaux][tb_2[j].replace(/\s/g,'')] == undefined ? 'vide' : list_event_filter[this.position_creneaux][tb_2[j].replace(/\s/g,'')]) + '<br/>';
                            }
                            requestAnimationFrame(() => {
                              this.template.querySelector(".value_a_afficher_info_supp").innerHTML =  this.value_a_afficher_info_supp;
                            });

                            this.event_remplis = true;
                        
                          
                    }
                    else
                    {
                        if(this.get_global_option == false)
                        {
                            dates =  this.heure_string_to_heure(this.date_crenaux , this.value_crenaux);

                                for(let i = 0 ; i < this.list_event.length ; i++)
                                {
                                
                                        if((this.date_apex_to_js(this.list_event[i][this.api_name_date_planification]) > dates[0]
                                        && this.date_apex_to_js(this.list_event[i][this.api_name_date_planification]) < dates[1])  
                                        || this.date_apex_to_js(this.list_event[i][this.api_name_date_planification]).toString() == dates[1] 
                                        || this.date_apex_to_js(this.list_event[i][this.api_name_date_planification]).toString() == dates[0])
                                        {
                                           


                                            for(let s = 0 ; s < this.condition_object_cible_couleur.length ; s++)
                                            {  
                                                // console.log('=--==--=-=-=-=-=-=-===-=-===-===-==-=');
                                                // console.log( this.list_event[i][this.condition_object_cible_couleur[s].column_api_name] + '=='  + this.condition_object_cible_couleur[s].column_api_value);
                                                // console.log('=--==--=-=-=-=-=-=-===-=-===-===-==-=');

                                                if( this.list_event[i][this.condition_object_cible_couleur[s].column_api_name]  == this.condition_object_cible_couleur[s].column_api_value   || (this.condition_object_cible_couleur[s].column_api_value == 'is_blank' && this.list_event[i][this.condition_object_cible_couleur[s].column_api_name] == undefined)) 
                                                {
                                                    requestAnimationFrame(() => {
                                                        this.template.querySelector(".creneaux").style.background = this.condition_object_cible_couleur[s].couleur;
                                                        this.template.querySelector(".creneaux > a").style.color = "black";
                                                        // this.template.querySelector(".creneaux > a").style.color = "white";
                                                        // this.template.querySelector(".creneaux").style.color = "white";
                                                        });
                                                }
                                            }            

                                            // const self = this.list_event;
                                            // this.condition_object_cible_couleur.forEach((element) => {
                                            //     console.log('=-=-=-=-=-=-=-=-=->>>>>');
                                            //     console.log(self);
                                            //     console.log('=-=-=-=-=-=-=-=-=->>>>>');
                                            //     if( self[i][element.column_api_name]  == element.column_api_value) 
                                            //     {
                                            //         requestAnimationFrame(() => {
                                            //             this.template.querySelector(".creneaux").style.background = element.couleur;
                                            //             this.template.querySelector(".creneaux > a").style.color = "white";
                                            //             this.template.querySelector(".creneaux").style.color = "white";
                                            //             });
                                            //     }

                                            // });


                                            // if( this.list_event[i][this.condition_object_cible_couleur[0].column_api_name]  == this.condition_object_cible_couleur[0].column_api_value)
                                            // {
                                            //     requestAnimationFrame(() => {
                                            //         this.template.querySelector(".creneaux").style.background = this.condition_object_cible_couleur[0].couleur;
                                            //         this.template.querySelector(".creneaux > a").style.color = "white";
                                            //         this.template.querySelector(".creneaux").style.color = "white";
                                            //         });
                                            // }
                                            // else
                                            // {
                                            // requestAnimationFrame(() => {
                                            //     this.template.querySelector(".creneaux").style.background = this.condition_object_cible_couleur[1].couleur;
                                            //     this.template.querySelector(".creneaux > a").style.color = "white";
                                            //     this.template.querySelector(".creneaux").style.color = "white";
                                            // });
                                            // }
                                         
                                            var dt_fin = new Date(new Date(this.list_event[i][this.api_name_date_planification]).toLocaleString("en-US", {timeZone: this.timezone}));
                                           this.date_crenaux_vraie = '(' + dt_fin.toString().split(' ')[4].split(':')[0] + 'H' + dt_fin.toString().split(' ')[4].split(':')[1] + ')';
                                            //this.date_crenaux_vraie = '('+(parseInt((this.list_event[i][this.api_name_date_planification]).split('T')[1].split('.')[0].split(':')[0])+2 ) + 'H' +(this.list_event[i][this.api_name_date_planification]).split('T')[1].split('.')[0].split(':')[1] + ')';
                                           // this.lien_to_object_cible = this.label.lien_org_planification + this.list_event[i].Id + '/view';
                                            this.lien_to_object_cible =  this.is_community == false ? this.label.lien_org_planification +  this.list_event[i].Id + '/view' :  (window.location.href).split('/s/')[0] + '/s/detail/' + this.list_event[i].Id;


                                           // console.log( '+++++++++++++>>> ' + this.is_community  +'+++++++++' +  (window.location.href).split('/s/')[0] + '/s/detail/');

                                            let tb = this.api_champs_a_afficher.split(',');
                                            this.value_a_afficher = '';
                                            for(let j = tb.length -1 ; j >= 0 ; j--)
                                            {
                                          
                                                if(!this.condition_object_cible_couleur.map((obj) => obj.column_api_name).includes(tb[j].replace(/\s/g,'')))
                                                   this.value_a_afficher +=' ' + this.list_event[i][tb[j].replace(/\s/g,'')];
                                            }
                                            // Badge Abdessamad
                                            this.badge = this.list_event[i][this.api_name_badge];
                                            let tb_2 = this.api_champs_a_info_supl.split(',');
                                            let tb_3 = this.name_champs_a_info_supl.split(',');

                                         

                                            if(tb_3.length > 0)
                                            {
                                                    for(let j = tb_2.length -1 ; j >= 0 ; j--)
                                                    {
                                                        this.value_a_afficher_info_supp +=' -' + tb_3[j].replace(/\s/g,'') +': ' + (this.list_event[i][tb_2[j].replace(/\s/g,'')] == undefined ? 'vide' : this.list_event[i][tb_2[j].replace(/\s/g,'')]) + '<br/>';
                                                    }
                                            }
                                          
                                            
                                          
                                            let tb_4 = this.api_champs_a_afficher_a_cote_date.split(',');
                           
                                            for(let j = tb_4.length -1 ; j >= 0 ; j--)
                                            {
                                                if(this.list_event[i][tb_4[j].replace(/\s/g,'')] != undefined)
                                                this.value_a_afficher_cote_date +=' ' + this.list_event[i][tb_4[j].replace(/\s/g,'')] + ' - ';
                                                else if(tb_4[j].replace(/\s/g,'').split('.').length > 1 && this.list_event[i][tb_4[j].replace(/\s/g,'').split('.')[0]] != undefined)
                                                {
                                                    this.value_a_afficher_cote_date += ' ' + (this.list_event[i][tb_4[j].replace(/\s/g,'').split('.')[0]])[tb_4[j].replace(/\s/g,'').split('.')[1]].replaceAll(/CONFIRMATEUR|AUDITEUR|TERRAINS|COMMERCIAL|TELEPRO|\-/g, "") + ' - ';
                                                }
                                                 

                                            }
                                            this.value_a_afficher_cote_date = this.value_a_afficher_cote_date.replace(/\-\s$/, '');
                                           
                                            requestAnimationFrame(() => {
                                              this.template.querySelector(".value_a_afficher_info_supp").innerHTML =  this.value_a_afficher_info_supp;
                                            });

                                            this.event_remplis = true;
                                            break;
                                        }
                                    
                                }   
                                         

                                if(this.event_remplis == false && this.search != null)
                                {
                                  
                                    if(  this.string_date_to_js_date_1(this.date_crenaux) >  new Date() )
                                    {

                                        var position_cruneaux = 0;
                                    

                                        var code_postal_before;
                                        var dates_cr_before;
                                        var code_postal_after;
                                        var dates_cr_after;

                                    


                                        for(let i = 0 ; i < this.crenaux_all.length ; i++)
                                        {
                                            if(this.crenaux_all[i].date == this.date_crenaux)
                                            {
                                                for(let j = 0 ; j < this.crenaux_all[i].crenaux.length ; j++)
                                                {
                                                    if(this.crenaux_all[i].crenaux[j].crenreaux == this.value_crenaux)
                                                    {
                                                    
                                                    
                                
                                                        position_cruneaux = j;
                                                        
                                                        if(position_cruneaux > 0 && position_cruneaux <  this.crenaux_all[i].crenaux.length -1)
                                                        {
                                                            dates_cr_before = this.heure_string_to_heure(this.date_crenaux , this.crenaux_all[i].crenaux[position_cruneaux-1].crenreaux );
                                                            dates_cr_after = this.heure_string_to_heure(this.date_crenaux , this.crenaux_all[i].crenaux[position_cruneaux+1].crenreaux );
                                                        
                                                        } 
                                                        else if(position_cruneaux ==  this.crenaux_all[i].crenaux.length -1 )
                                                        {
                                                            dates_cr_before = this.heure_string_to_heure(this.date_crenaux , this.crenaux_all[i].crenaux[position_cruneaux-1].crenreaux );
                                                        }
                                                        else if(position_cruneaux == 0)
                                                        {
                                                            dates_cr_after = this.heure_string_to_heure(this.date_crenaux , this.crenaux_all[i].crenaux[position_cruneaux+1].crenreaux );
                                                        }
                                                    
                                                        break;
                                                    }   
                                                }
                                            break;
                                            }
                                        }

                            
                                    
                                    

                                        for(let i = 0 ; i < this.list_event.length ; i++)
                                        {
                                            if(dates_cr_before != undefined)
                                            {
                                                
                                                if(this.date_apex_to_js(this.list_event[i][this.api_name_date_planification]) > dates_cr_before[0]
                                                && this.date_apex_to_js(this.list_event[i][this.api_name_date_planification]) < dates_cr_before[1]
                                                || this.date_apex_to_js(this.list_event[i][this.api_name_date_planification]).toString() == dates_cr_before[1] 
                                                || this.date_apex_to_js(this.list_event[i][this.api_name_date_planification]).toString() == dates_cr_before[0])
                                                {
                                                    let tb = this.api_champs_a_afficher.split(',');
                                                   // code_postal_before = this.list_event[i][tb[tb.length-1].replace(/\s/g,'')];
                                                     code_postal_before = this.list_event[i][this.coodone_atitude_longitude];
                                                }
                                            }
                                            if(dates_cr_after != undefined)
                                            {
                                                if(this.date_apex_to_js(this.list_event[i][this.api_name_date_planification]) >= dates_cr_after[0]
                                                && this.date_apex_to_js(this.list_event[i][this.api_name_date_planification]) <= dates_cr_after[1]
                                                || this.date_apex_to_js(this.list_event[i][this.api_name_date_planification]).toString() == dates_cr_after[1] 
                                                || this.date_apex_to_js(this.list_event[i][this.api_name_date_planification]).toString() == dates_cr_after[0])
                                                {
                                                    let tb = this.api_champs_a_afficher.split(',');
                                                   // code_postal_after = this.list_event[i][tb[tb.length-1].replace(/\s/g,'')];
                                                   code_postal_after =  this.list_event[i][this.coodone_atitude_longitude];
                                                }
                                            }
                                        }    

                                    
                                        //console.log( code_postal_before + ' // ' + code_postal_after + '//' + this.coodone_atitude_longitude);
                                            //console.log(this.search +" // "+ code_postal_before +" // "+ code_postal_after)
                                            if(code_postal_before != undefined)
                                            {
                                
                                                //    this.calculer_traget_before(this.search , code_postal_before);
                                                for(let i = 0 ; i < this.duration_postaux.length ; i++)
                                                {
                                                  // console.log( code_postal_before + "==" +  this.duration_postaux[i].postalcode);
                                                //if(code_postal_before == this.duration_postaux[i].postalcode.split(' ')[0])
                                                if(code_postal_before.replace(/ /g, "") == this.duration_postaux[i].origin )
                                                {
                                                    //this.value_a_afficher_before = this.duration_postaux[i].duration.replace('hour' , 'h').replace('mins' , 'm') + ' / ' + this.duration_postaux[i].distance ;
                                                    this.calcule_all_before(this.duration_postaux[i].duration.replace('hour' , 'h').replace('mins' , 'm') , this.duration_postaux[i].duration_value , this.duration_postaux[i].distance , position_cruneaux , code_postal_before ,code_postal_after );
                                                // console.log("===================>"+  this.value_a_afficher_before );
                                                    if((this.duration_postaux[i].duration_value/60) <= 35)
                                                    {
                                                        requestAnimationFrame(() => {
                                                            this.template.querySelector("._a_a_before").style.background = 'green';
                                                            this.template.querySelector("._a_a_before").style.color = 'white';
                                                        });
                                                    }
                                                    else if((this.duration_postaux[i].duration_value/60) > 35 && (this.duration_postaux[i].duration_value/60) <= 80)
                                                    {
                                                        requestAnimationFrame(() => {
                                                            this.template.querySelector("._a_a_before").style.background = '#fbb57b';
                                                            this.template.querySelector("._a_a_before").style.color = 'black';
                                                        });
                                                    }
                                                    else
                                                    {
                                                        this.before_is_red = true;
                                                        requestAnimationFrame(() => {
                                                            this.template.querySelector("._a_a_before").style.background = 'red';
                                                            this.template.querySelector("._a_a_before").style.color = 'white';
                                                        });
                                                    }
                                                    break;
                                                }
                                                    
                                                }   

                                            }

                                            if(code_postal_after != undefined)
                                            {
                        
                                            // this.calculer_traget_after(this.search , code_postal_after);
                                            for(let i = 0 ; i < this.duration_postaux.length ; i++)
                                            {
                                                //if(code_postal_after == this.duration_postaux[i].postalcode.split(' ')[0])
                                                if(code_postal_after.replace(/ /g, "") == this.duration_postaux[i].origin)
                                                {
                                                //this.value_a_afficher_after = this.duration_postaux[i].duration.replace('hour' , 'h').replace('mins' , 'm') + ' / ' + this.duration_postaux[i].distance ;
                                                this.calcule_all_after(this.duration_postaux[i].duration.replace('hour' , 'h').replace('mins' , 'm') , this.duration_postaux[i].duration_value , this.duration_postaux[i].distance , position_cruneaux , code_postal_before ,code_postal_after) ;

                                            // console.log("===================>"+  this.value_a_afficher_after  + ' ===> ' + (this.duration_postaux[i].duration_value/60));
                                                if((this.duration_postaux[i].duration_value/60) <= 35)
                                                {
                                                    requestAnimationFrame(() => {
                                                        this.template.querySelector("._a_a_after").style.background = 'green';
                                                        this.template.querySelector("._a_a_after").style.color = 'white';
                                                    });
                                                }
                                                else if((this.duration_postaux[i].duration_value/60) > 35 && (this.duration_postaux[i].duration_value/60) <= 80)
                                                {
                                                    requestAnimationFrame(() => {
                                                        this.template.querySelector("._a_a_after").style.background = '#fbb57b';
                                                        this.template.querySelector("._a_a_after").style.color = 'black';
                                                    });
                                                }
                                                else
                                                {
                                                    this.after_is_red = true;
                                                    requestAnimationFrame(() => {
                                                        this.template.querySelector("._a_a_after").style.background = 'red';
                                                        this.template.querySelector("._a_a_after").style.color = 'white';
                                                    });
                                                }
                                                break;
                                                }
                                                
                                              }   

                                            }


                                             if(code_postal_after != undefined && code_postal_before != undefined)
                                            {
                                                console.log('holaaaaaa');
                                                if(this.after_is_red == true  &&  this.before_is_red == true)
                                                {
                                                    console.log('holaaaaaa 22222');
                                                    requestAnimationFrame(() => {
                                                    // this.template.querySelector("._a_a_after").style.background = '#fff';
                                                    // this.template.querySelector("._a_a_after").style.color = '#fff';
                                                    // this.template.querySelector("._a_a_before").style.background = '#fff';
                                                    // this.template.querySelector("._a_a_before").style.color = '#fff';
                                                    this.template.querySelector("._a_a_after").style.opacity = '0.1';
                                                    this.template.querySelector("._a_a_after").style.opacity = '0.1';
                                                    this.template.querySelector("._a_a_before").style.opacity= '0.1';
                                                    this.template.querySelector("._a_a_before").style.opacity = '0.1';
                                                     });
                                                    // this.value_a_afficher_after = '';
                                                    // this.value_a_afficher_before = '';
                                                }
                                             }
                                             if(code_postal_after != undefined && code_postal_before == undefined)
                                             {
                                                
                                                if(this.after_is_red == true &&  this.before_is_red == false)
                                                {
                                                   
                                                    requestAnimationFrame(() => {
                                                    // this.template.querySelector("._a_a_after").style.background = '#fff';
                                                    // this.template.querySelector("._a_a_after").style.color = '#fff';
                                                    this.template.querySelector("._a_a_after").style.opacity = '0.1';
                                                    this.template.querySelector("._a_a_after").style.opacity = '0.1';
                                                     }); 
                                                   // this.value_a_afficher_after = '';
                                                }
                                            }
                                             if(code_postal_after == undefined && code_postal_before != undefined)
                                            {
                                               
                                                if(this.after_is_red == false &&  this.before_is_red == true)
                                                {
                                                   
                                                    requestAnimationFrame(() => {
                                                    // this.template.querySelector("._a_a_before").style.background = '#fff';
                                                    // this.template.querySelector("._a_a_before").style.color = '#fff';
                                                    this.template.querySelector("._a_a_before").style.opacity= '0.1';
                                                    this.template.querySelector("._a_a_before").style.opacity = '0.1';
                                                     }); 
                                                   // this.value_a_afficher_before = '';
                                                }
                                           }


                                         
                                          
                                            
                                        }
                                }
                        }
                        else if(this.get_global_option == true)
                        {
                          
                                var code_postal_all = [];
                                if(this.list_event !=  '')
                                {
                                    // this.list_event = this.triParSelection(this.list_event);
                                     //console.log(JSON.stringify(this.list_event));

                                    for(let i = 0 ; i < this.list_event.length ; i++)
                                    {                
                                        if(this.date_apex_to_js_date(this.list_event[i][this.api_name_date_planification])  ==  this.dateyime_to_date(this.date_crenaux))
                                        {
                                    
                                            let tb = this.api_champs_a_afficher.split(',');
                                            code_postal_all.push(this.list_event[i][tb[tb.length-1].replace(/\s/g,'')]  + ' France' );
                                        }
                                    }

                                    // console.log("R!P!P!!postaux!P!P!PP!!P!P!PP!");
                                    // console.log(code_postal_all);
                                    // console.log("R!P!P!!postaux!P!P!PP!!P!P!PP!");
 

                                    if(code_postal_all.length > 1)
                                    {
                                       
                                        var somme_duration = 0;
                                        var somme_duration_km = 0;
                                        this.getDistances_deaily( code_postal_all , code_postal_all)
                                        .then((durations_deaily) => {
                                            // console.log("R!P!P!!P!P!P!P!P!P!P!P!PP!!P!P!PP!");
                                            //     console.log(durations_deaily);
                                            // console.log("R!P!P!!P!P!P!P!P!P!P!P!PP!!P!P!PP!");


                                            for(let s = 0 ; s < code_postal_all.length-1 ; s++)
                                            {
                                                 for(let f = 0 ; f < durations_deaily.length ; f++)
                                                 {
                                                       if(durations_deaily[f].destination == code_postal_all[s] && durations_deaily[f].origin  == code_postal_all[s+1])
                                                       {
                                                        somme_duration += durations_deaily[f].duration_value;
                                                        somme_duration_km +=  parseInt(durations_deaily[f].distance.split(" ")[0]);
                                                        break;
                                                       }
                                                 }
                                            }

                                                var date = new Date(0);
                                                date.setSeconds(somme_duration); // specify value for SECONDS here
                                                this.somme_duration_string = date.toISOString().substring(11, 19);
                                                this.somme_duration_km_string = somme_duration_km + ' KM';
                                        })
                                        .catch((error) => {
                                           console.error('Error:', error);
                                        });
                                       
                                      
                                       
                                   }
                               }
                        }
                           
                    }

                }
                if(this.event_remplis == false && this.cas_exception == false)
                {
                    if(  this.string_date_to_js_date_1(this.date_crenaux) <  new Date() )
                    {
                        requestAnimationFrame(() => {
                            // Uncomment this line to set the background color of the crenaux to grey
                            this.template.querySelector(".creneaux").style.background = '#858585';
                            this.template.querySelector(".creneaux").style.opacity = "0.52";
                            
                            });
                    }
                    if(this.conges_champs_text_long_api_name != undefined && this.conges_champs_text_long_api_name != '')
                    {
                        // console.log("=========================>");
                        // console.log( this.date_crenaux.split(' ')[1]);
                        // console.log( this.conges_champs_text_long_api_name.split(',')[0]);
                        // // console.log(  this.string_to_date(this.date_crenaux.split(' ')[1])  +  " === " +  this.string_to_date(this.conges_champs_text_long_api_name.split(',')[0].split(' ')[1]));

                        // console.log( this.date_crenaux.split(' ')[1].toString() + ' /// ' + this.conges_champs_text_long_api_name.split(',')[0].split(' ')[1].toString());
                        // console.log("=========================>");
                        
                        for(let u = 0 ; u < this.conges_champs_text_long_api_name.split(',').length ; u++)
                        {
                            if(this.date_crenaux.split(' ')[1].replace(/ /g, "") ==  this.conges_champs_text_long_api_name.split(',')[u].split(' ')[1].replace(/ /g, "") )
                            {
                               // console.log( 'in' + '======>' + this.date_crenaux.split(' ')[1] + '///' + this.conges_champs_text_long_api_name.split(',')[0].split(' ')[1]);

                                requestAnimationFrame(() => {
                                    this.template.querySelector(".creneaux").style.background = '#858585';
                                    this.template.querySelector(".creneaux").style.opacity = "0.52";
                                    
                                    });
                            }
                        }
                    }

                }
        
              
         } , 2);
   }



   get_position_cruneaux()
   {
    for(let i = 0 ; i < this.crenaux_all.length ; i++)
    {
        if(this.crenaux_all[i].date == this.date_crenaux)
        {
            for(let j = 0 ; j < this.crenaux_all[i].crenaux.length ; j++)
            {
                if(this.crenaux_all[i].crenaux[j].crenreaux == this.value_crenaux)
                {
                    return j;
                    break;
                }   
            }
        break;
        }
    }


   }
   
   after_is_red = false;
   before_is_red = false;

   calcule_all_after(duration , duration_value , distance , position_cruneaux , code_postal_before , code_postal_after)  
   { 
             let not_sum = false;
            var code_postal_all = [];
            if(this.list_event !=  '')
            {
                

                for(let i = 0 ; i < this.list_event.length ; i++)
                {                
                    if(this.date_apex_to_js_date(this.list_event[i][this.api_name_date_planification])  ==  this.dateyime_to_date(this.date_crenaux))
                    {
                        let tb = this.api_champs_a_afficher.split(',');

                        //if(this.list_event[i][tb[tb.length-1].replace(/\s/g,'')] == code_postal_after )
                        if(this.list_event[i][this.coodone_atitude_longitude] == code_postal_after )
                        {
                           // if(!code_postal_all.includes(this.search  + ' France'))
                            if(!code_postal_all.includes(this.search))
                            {
                           // code_postal_all.push(this.search  + ' France');
                              code_postal_all.push(this.search);
                            }
                        }
                       
                       // code_postal_all.push(this.list_event[i][tb[tb.length-1].replace(/\s/g,'')]  + ' France' );
                       code_postal_all.push(this.list_event[i][this.coodone_atitude_longitude]);
                    
                    }
                }


             

                if(code_postal_all.length > 2)
                {
                
                    for(let i = 0 ; i < code_postal_all.length ; i++)
                    {    
                        if(code_postal_all[i].replace(/\s/g,'') == "49.516085,5.773984")
                        {
                        console.log('yes exist after===> ' + code_postal_all[i]);
                        }
                    } 
    
                    let ii = [];
                    var somme_duration = 0;
                    var somme_duration_km = 0;
    
                    for(let i = 0 ; i < code_postal_all.length ; i++)
                    {
                     
                        for(let j = 0 ; j < this.duration_postaux.length ; j++)
                        {
                            //"47.62081409115609,4.362717433"=="47.62081409115609,4.362717433"
                            // console.log("==============> ");
                            // console.log(JSON.stringify(this.duration_postaux[j].origin.toString())  + "==" + JSON.stringify(code_postal_all[i].replace(/\s/g,'')));
                            // console.log("==============> ");
                            const arr1 = this.duration_postaux[j].origin.replace(/\s/g,'').split(',').map(Number);
                            const arr2 = code_postal_all[i].replace(/\s/g,'').split(',').map(Number);

                            if(arr1.length === arr2.length && arr1.every((value, index) => value === arr2[index])) 
                            {
                                ii.push(j);
                                break;
                            }
                        }
                    }
                   
                    for(let i = 0 ; i < code_postal_all.length ; i++)
                    {    
                        if(code_postal_all[i].replace(/\s/g,'') == "49.516085,5.773984")
                        {
                            console.log('yes exist after ii ===> ' +ii);

                        }
                    } 
                   
                     for(let i = 0 ; i < ii.length ; i++)
                     {
                       if(i == 0)
                       {
                       
                        somme_duration +=  this.duration_postaux[ii[i]].duration_globale[ii[i]];
                        somme_duration_km += this.duration_postaux[ii[i]].distance_globale[ii[i]];

                       }
                      else
                      {
                        //'85.29km'
                        if(this.duration_postaux[ii[i]].duration_globale.length > ii[i-1])
                        {
                            somme_duration +=  this.duration_postaux[ii[i]].duration_globale[ii[i-1]];
                            somme_duration_km +=  this.duration_postaux[ii[i]].distance_globale[ii[i-1]];
                        }
                        else
                        {
                            this.value_a_afficher_after =  duration + ' / ' + distance;
                            not_sum = true;
                            // if((duration_value/60) <= 35)
                            // {
                            //     requestAnimationFrame(() => {
                            //         this.template.querySelector("._a_a_after").style.background = 'green';
                            //         this.template.querySelector("._a_a_after").style.color = 'white';
                            //     });
                            // }
                            // else if((duration_value/60) > 35 && (duration_value/60) <= 80)
                            // {
                            //     requestAnimationFrame(() => {
                            //         this.template.querySelector("._a_a_after").style.background = '#fbb57b';
                            //         this.template.querySelector("._a_a_after").style.color = 'black';
                            //     });
                            // }
                            // else
                            // {
                               
                            //     requestAnimationFrame(() => {
                            //         this.template.querySelector("._a_a_after").style.background = 'red';
                            //         this.template.querySelector("._a_a_after").style.color = 'white';
                            //     });
                            //     this.after_is_red = true;
                            //     if( this.before_is_red == true  && this.after_is_red == true)
                            //     {
                            //         console.log('holaaaaaa 22222');
                            //         requestAnimationFrame(() => {
                            //         this.template.querySelector("._a_a_after").style.background = '#818274';
                            //         this.template.querySelector("._a_a_after").style.color = '#fff';
                            //         this.template.querySelector("._a_a_before").style.background = '#818274';
                            //         this.template.querySelector("._a_a_before").style.color = '#fff';
                            //          });
                            //         // this.value_a_afficher_after = '';
                            //         // this.value_a_afficher_before = '';
                                
                            //     }
                            // }
                        }
                      }
                     
                     }

                    

                   if(!not_sum)
                   {
                    var date = new Date(0);
                    date.setSeconds(somme_duration); // specify value for SECONDS here
                    this.somme_duration_string = date.toISOString().substring(11, 19);
                    this.somme_duration_km_string = somme_duration_km.toFixed(2) + ' KM';
                    this.value_a_afficher_after = duration + ' / T ' + this.somme_duration_string + ' ' +  this.somme_duration_km_string ;
                   }
                
               }
               else
               {
                  this.value_a_afficher_after =  duration + ' / ' + distance;
               }

              
            
        }
   }



   calcule_all_before(duration , duration_value , distance , position_cruneaux, code_postal_before , code_postal_after)
   {
          let not_sum = false;
            var code_postal_all = [];
            if(this.list_event !=  '')
            {
               
               
                for(let i = 0 ; i < this.list_event.length ; i++)
                {                
                    if(this.date_apex_to_js_date(this.list_event[i][this.api_name_date_planification])  ==  this.dateyime_to_date(this.date_crenaux))
                    {
                       

                      
                        code_postal_all.push(this.list_event[i][this.coodone_atitude_longitude] );

                        if(this.list_event[i][this.coodone_atitude_longitude] == code_postal_before)
                        {
                            if(!code_postal_all.includes(this.search))
                            {
                                code_postal_all.push(this.search);
                            }
                        }
                      
                    }
                }

            


                if(code_postal_all.length > 2 && (code_postal_before == undefined || code_postal_after == undefined))
                {
               
                      
                // for(let i = 0 ; i < code_postal_all.length ; i++)
                // {    
                //     if(code_postal_all[i].replace(/\s/g,'') == "49.516085,5.773984")
                //     {
                //     console.log('yes exist before ===> ' + code_postal_all[i]);

                //     }
                // } 
                    let ii = [];
                    var somme_duration = 0;
                    var somme_duration_km = 0;
    
                    for(let i = 0 ; i < code_postal_all.length ; i++)
                    {
                        for(let j = 0 ; j < this.duration_postaux.length ; j++)
                        {
                            const arr1 = this.duration_postaux[j].origin.replace(/\s/g,'').split(',').map(Number);
                            const arr2 = code_postal_all[i].replace(/\s/g,'').split(',').map(Number);

                            if(arr1.length === arr2.length && arr1.every((value, index) => value === arr2[index])) 
                            {
                                ii.push(j);
                                break;
                            }
                        }
                    }

                    // console.log("==============> ");
                    //       console.log(ii);
                    // console.log("==============> ");
                  
                     for(let i = 0 ; i < ii.length ; i++)
                     {
                       if(i == 0)
                       {
                        somme_duration +=  this.duration_postaux[ii[i]].duration_globale[ii[i]];
                        somme_duration_km +=  this.duration_postaux[ii[i]].distance_globale[ii[i]];

                       }
                      else
                      {
                        if(this.duration_postaux[ii[i]].duration_globale.length > ii[i-1])
                        {
                            somme_duration +=  this.duration_postaux[ii[i]].duration_globale[ii[i-1]];
                            somme_duration_km +=  this.duration_postaux[ii[i]].distance_globale[ii[i-1]];
                        }
                        else
                        {
                            this.value_a_afficher_before =  duration + ' / ' + distance;
                            not_sum = true;
                            // if((duration_value/60) <= 35)
                            // {
                            //     requestAnimationFrame(() => {
                            //         this.template.querySelector("._a_a_before").style.background = 'green';
                            //         this.template.querySelector("._a_a_before").style.color = 'white';
                            //     });
                            // }
                            // else if((duration_value/60) > 35 && (duration_value/60) <= 80)
                            // {
                            //     requestAnimationFrame(() => {
                            //         this.template.querySelector("._a_a_before").style.background = '#fbb57b';
                            //         this.template.querySelector("._a_a_before").style.color = 'black';
                            //     });
                            // }
                            // else
                            // {
                                
                               
                            //     requestAnimationFrame(() => {
                            //         this.template.querySelector("._a_a_before").style.background = 'red';
                            //         this.template.querySelector("._a_a_before").style.color = 'white';
                            //     });
                            //     this.before_is_red = true;
                            //     if( this.before_is_red == true  && this.after_is_red == true)
                            //     {
                            //         console.log('holaaaaaa 22222');
                            //         requestAnimationFrame(() => {
                            //         this.template.querySelector("._a_a_after").style.background = '#818274';
                            //         this.template.querySelector("._a_a_after").style.color = '#fff';
                            //         this.template.querySelector("._a_a_before").style.background = '#818274';
                            //         this.template.querySelector("._a_a_before").style.color = '#fff';
                            //          });
                            //         // this.value_a_afficher_after = '';
                            //         // this.value_a_afficher_before = '';
                                
                            //     }
                            // }
                        }
                      }
                     
                     }
                     if(!not_sum)
                     {
                            var date = new Date(0);
                            date.setSeconds(somme_duration); // specify value for SECONDS here
                            this.somme_duration_string = date.toISOString().substring(11, 19);
                            this.somme_duration_km_string = somme_duration_km.toFixed(2) + ' KM';
                            this.value_a_afficher_before = duration + ' / T ' + this.somme_duration_string + ' ' +  this.somme_duration_km_string ;
                     }

                   
                
                
                
             }
             else
             {
                this.value_a_afficher_before = duration  + ' / ' + distance;
             }
        }
   }



   comparerParDate(a, b) {
    return this.date_apex_to_js(a[this.api_name_date_planification]) - this.date_apex_to_js(b[this.api_name_date_planification]);
  }


   triParSelection(tableau) {
    const n = tableau.length;
    
    for (let i = 0; i < n - 1; i++) {
      let minIndex = i;
      
      for (let j = i + 1; j < n; j++) {
        if (his.date_apex_to_js(tableau[j][this.api_name_date_planification]) < his.date_apex_to_js(tableau[minIndex][this.api_name_date_planification])) {
          minIndex = j;
        }
      }
      
      if (minIndex !== i) {
        const temp = tableau[i];
        tableau[i] = tableau[minIndex];
        tableau[minIndex] = temp;
      }
    }
    
    return tableau;
  }
  



  string_date_to_js_date_1(dateString)
  {

        // Define a map of French day names to English day names
        var frenchToEnglishDays = {
        'lundi': 'Monday',
        'mardi': 'Tuesday',
        'mercredi': 'Wednesday',
        'jeudi': 'Thursday',
        'vendredi': 'Friday',
        'samedi': 'Saturday',
        'dimanche': 'Sunday'
        };

        // Split the input string into words
        var words = dateString.split(' ');

        // Extract the French day name and date part
        var frenchDay = words[0];
        var datePart = words[1];

        // Replace the French day name with the English day name
        var englishDay = frenchToEnglishDays[frenchDay];

        // Parse the date string in the format 'MM/DD/YYYY'
        var parts = datePart.split('/');
        var month = parseInt(parts[1], 10) - 1; // Subtract 1 from the month since JavaScript months are zero-based
        var day = parseInt(parts[0], 10) + 1;
        var year = parseInt(parts[2], 10);

        // Create a JavaScript Date object
        var date = new Date(year, month, day);

        // Output the result
        //console.log(englishDay); // Outputs the English day name (e.g., "Monday")
        return date; 
  }


   somme_duration_string = "00h 00min" ;
   somme_duration_km_string =  "0km";
    spinner = true;




    string_to_date(dateString){
        var dateParts = dateString.split(" ");
        var day = parseInt(dateParts[1].split("/")[0]);
        var month = parseInt(dateParts[1].split("/")[1]) - 1; 
        var year = parseInt(dateParts[1].split("/")[2]);

        var date = new Date();
        date.setDate(day);
        date.setMonth(month);
        date.setFullYear(year);

        return date;
    }



    heure_string_to_heure(dateString , timeString){
        var dateParts = dateString.split(" ");
        var day = parseInt(dateParts[1].split("/")[0]);
        var month = parseInt(dateParts[1].split("/")[1]) - 1; 
        var year = parseInt(dateParts[1].split("/")[2]);

        var timeParts = timeString.toLowerCase().split("-");
        var timePart1 = timeParts[0].split("h");
        var timePart2 = timeParts[1].split("h");
        var hour1 = parseInt(timePart1[0]);
        var minut1 = parseInt(timePart1[1]);
        var hour2 = parseInt(timePart2[0]);
        var minut2 = parseInt(timePart2[1]);
    
        // var options = { timeZone: 'Europe/Paris' };



        var date = new Date();
        date.setDate(day);
        date.setMonth(month);
        date.setFullYear(year);
        date.setHours(parseInt(hour1)); //timeZone
        date.setMinutes(minut1);
        date.setSeconds(0);
        // date.toLocaleString('en-US', options);


        var date2 = new Date();
        date2.setDate(day);
        date2.setMonth(month);
        date2.setFullYear(year);
        date2.setHours(parseInt(hour2)); //timeZone
        date2.setMinutes(parseInt(minut2)-1);
        date2.setSeconds(0);
        // date2.toLocaleString('en-US', options);

        var dates = [date , date2];

        return dates;
    }


    // date_string_date()
    // {

    // }



     date_apex_to_js(dateString) {
        var date = new Date(new Date(dateString).toLocaleString("en-US", {timeZone: this.timezone}));
        return date;
      }




    dateyime_to_date(dateString){
        var dateParts = dateString.split(" ");
        var day = dateParts[1].split("/")[0];
        var month = dateParts[1].split("/")[1]; 
        var year = dateParts[1].split("/")[2];

        return (year+"-"+month+"-"+day);
    } 
      
       date_apex_to_js_date(dateString) {
        var dateParts = dateString.split("T");
        return dateParts[0];
      }

      toDate(str){
        var [ dd, MM, yyyy, hh, mm ] = str.split(/[. :]/g);
        return new Date(`${MM}/${dd}/${yyyy} ${hh}:${mm}`);
      }

     isNumber(n){
        return typeof(n) != "boolean" && !isNaN(n);
    }



    async calcule_duree_deaily(data , planifications)
    {
       if(destinationPostalCodes.length > 0)
       {
             this.getDistances_deaily( destinationPostalCodes , destinationPostalCodes)
             .then((durations_deaily) => {
                //console.log('Durations:', durations);
               // return durations;
             })
             .catch((error) => {
                console.error('Error:', error);
             });
       }
    }
 
 
     durations_deaily = [];
     async getDistances_deaily(originPostalCodes , destinationPostalCodes) {
       try {
           return await getDurationsDaily({ originPostalCodes, destinationPostalCodes });
             // console.log('Durations:', this.durations);
        
       } catch (error) {
           console.error('Error:', error);
       }
     }





    origin = "25310"; // code postal de départ
    destination = "25200"; // code postal d'arrivée
    lat_origin;
    lon_origin;
    calculer_traget_before(origin , destination) {
     
        // fetch("https://nominatim.openstreetmap.org/search?q=75001&format=json&limit=1")
        //     .then(response => response.text())
        //     .then(result => console.log(result))
        //     .catch(error => console.log('error', error));
             // Appel à l'API de géocodage OpenStreetMap pour obtenir les coordonnées géographiques des deux codes postaux
            const url_origin = "https://nominatim.openstreetmap.org/search?q="+origin+"&format=json&limit=1&countrycodes=FR";
            const url_destination = "https://nominatim.openstreetmap.org/search?q="+destination+"&format=json&limit=1&countrycodes=FR";

            //https://nominatim.openstreetmap.org/search?q=Paris&postalcode=75000&format=json&limit=1&countrycodes=FR

            // Appel à l'API de géocodage avec l'API de fetch
            fetch(url_origin)
            .then(response => response.json())
            .then(data => {
                //  console.log("+++++++++++++++>>>>");
                //          console.log(data);
                //  console.log("+++++++++++++++>>>>");
                 this.lat_origin = data[0]['lat'];
                 this.lon_origin = data[0]['lon'];
                return fetch(url_destination);
            })
            .then(response => response.json())
            .then(data => {
                // console.log("+++++++++++++++>>>>");
                //         console.log(data);
                // console.log("+++++++++++++++>>>>");
                const lat_destination = data[0]['lat'];
                const lon_destination = data[0]['lon'];
                // console.log("https://router.project-osrm.org/route/v1/driving/"+this.lon_origin+","+this.lat_origin+";"+lon_destination+","+lat_destination+"?overview=false");
                // Appel à l'API de calcul d'itinéraire d'OpenStreetMap pour obtenir la durée de voyage entre les deux codes postaux
                const url_route = "https://router.project-osrm.org/route/v1/driving/"+this.lon_origin+","+this.lat_origin+";"+lon_destination+","+lat_destination+"?overview=false";
               
                // Appel à l'API de calcul d'itinéraire avec l'API de fetch
                 return fetch(url_route);
            })
            .then(response => response.json())
            .then(data => {
                // console.log("+++++++++++++++>>>>");
                //         console.log(data);
                // console.log("+++++++++++++++>>>>");
                const duration = data['routes'][0]['duration'];

                var date = new Date(0);
                date.setSeconds(duration); // specify value for SECONDS here
                var timeString = date.toISOString().substring(11, 19);

                // console.log(duration);

                // console.log("La durée de voyage entre "+this.origin+" et "+this.destination+" est de "+timeString+" secondes.");
                this.value_a_afficher_before = timeString ;
                if((duration/60) <= 35)
                {
                    requestAnimationFrame(() => {
                        this.template.querySelector("._a_a_before").style.background = 'green';
                        this.template.querySelector("._a_a_before").style.color = 'white';
                    });
                }
                else if((duration/60) > 35 && (duration/60) <= 60)
                {
                    requestAnimationFrame(() => {
                        this.template.querySelector("._a_a_before").style.background = 'amber';
                        this.template.querySelector("._a_a_before").style.color = 'white';
                    });
                }
                else
                {
                    requestAnimationFrame(() => {
                        this.template.querySelector("._a_a_before").style.background = 'red';
                        this.template.querySelector("._a_a_before").style.color = 'white';
                    });
                }
               // return timeString;
            })
            .catch(error => console.error(error));
    }
    calculer_traget_after(origin , destination) {
     
        // fetch("https://nominatim.openstreetmap.org/search?q=75001&format=json&limit=1")
        //     .then(response => response.text())
        //     .then(result => console.log(result))
        //     .catch(error => console.log('error', error));
             // Appel à l'API de géocodage OpenStreetMap pour obtenir les coordonnées géographiques des deux codes postaux
            const url_origin = "https://nominatim.openstreetmap.org/search?q="+origin+"&format=json&limit=1&countrycodes=FR";
            const url_destination = "https://nominatim.openstreetmap.org/search?q="+destination+"&format=json&limit=1&countrycodes=FR";

            //https://nominatim.openstreetmap.org/search?q=Paris&postalcode=75000&format=json&limit=1&countrycodes=FR

            // Appel à l'API de géocodage avec l'API de fetch
            fetch(url_origin)
            .then(response => response.json())
            .then(data => {
                //  console.log("+++++++++++++++>>>>");
                //          console.log(data);
                //  console.log("+++++++++++++++>>>>");
                 this.lat_origin = data[0]['lat'];
                 this.lon_origin = data[0]['lon'];
                return fetch(url_destination);
            })
            .then(response => response.json())
            .then(data => {
                // console.log("+++++++++++++++>>>>");
                //         console.log(data);
                // console.log("+++++++++++++++>>>>");
                const lat_destination = data[0]['lat'];
                const lon_destination = data[0]['lon'];
                // console.log("https://router.project-osrm.org/route/v1/driving/"+this.lon_origin+","+this.lat_origin+";"+lon_destination+","+lat_destination+"?overview=false");
                // Appel à l'API de calcul d'itinéraire d'OpenStreetMap pour obtenir la durée de voyage entre les deux codes postaux
                const url_route = "https://router.project-osrm.org/route/v1/driving/"+this.lon_origin+","+this.lat_origin+";"+lon_destination+","+lat_destination+"?overview=false";
               
                // Appel à l'API de calcul d'itinéraire avec l'API de fetch
                 return fetch(url_route);
            })
            .then(response => response.json())
            .then(data => {
                // console.log("+++++++++++++++>>>>");
                //         console.log(data);
                // console.log("+++++++++++++++>>>>");
                const duration = data['routes'][0]['duration'];

                var date = new Date(0);
                date.setSeconds(duration); // specify value for SECONDS here
                var timeString = date.toISOString().substring(11, 19);
              

                // console.log("La durée de voyage entre "+this.origin+" et "+this.destination+" est de "+timeString+" secondes.");
                this.value_a_afficher_after = timeString;
                if((duration/60) <= 35)
                {
                    requestAnimationFrame(() => {
                        this.template.querySelector("._a_a_after").style.background = 'green';
                        this.template.querySelector("._a_a_after").style.color = 'white';
                    });
                }
                else if((duration/60) > 35 && (duration/60) <= 60)
                {
                    requestAnimationFrame(() => {
                        this.template.querySelector("._a_a_after").style.background = 'amber';
                        this.template.querySelector("._a_a_after").style.color = 'white';
                    });
                }
                else
                {
                    requestAnimationFrame(() => {
                        this.template.querySelector("._a_a_after").style.background = 'red';
                        this.template.querySelector("._a_a_after").style.color = 'white';
                    });
                }
            //    return timeString;
            })
            .catch(error => console.error(error));
    }





    // Function to fetch latitude and longitude for a postal code
     fetchCoordinates(postalCode) {
      const format = 'json'; // Response format
      
      // Construct the API URL
     // https://nominatim.openstreetmap.org/search?q="+destination+"&format=json&limit=1&countrycodes=FR
      const apiUrl = `https://nominatim.openstreetmap.org/search?q=${postalCode}&format=${format}&limit=1&countrycodes=FR`;
      
      // Make the API request
      return fetch(apiUrl)
        .then(response => response.json())
        .then(data => {
          if (data.length > 0) {
            const latitude = parseFloat(data[0].lat);
            const longitude = parseFloat(data[0].lon);
            return { postalCode, latitude, longitude };
          } else {
            return { postalCode, error: 'No coordinates found' };
          }
        })
        .catch(error => {
          return { postalCode, error: error.message };
        });
    }
    
    // Function to calculate the duration between two sets of coordinates
     calculateDuration(startLatitude, startLongitude, endLatitude, endLongitude) {
      const apiUrl = `https://router.project-osrm.org/route/v1/driving/${startLongitude},${startLatitude};${endLongitude},${endLatitude}`;
      
      // Make the API request
      return fetch(apiUrl)
        .then(response => response.json())
        .then(data => {
          if (data.code === 'Ok') {
            const duration = data.routes[0].duration;
            return duration;
          } else {
            throw new Error('Unable to calculate duration');
          }
        })
        .catch(error => {
          throw new Error(`Error calculating duration: ${error.message}`);
        });
    }
    
   
    

}