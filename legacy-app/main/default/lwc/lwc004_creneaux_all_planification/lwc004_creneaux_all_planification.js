import { LightningElement , api , wire} from 'lwc';
import get_actuers_cible_planification from '@salesforce/apex/Planification_Controller.get_actuers_cible_planification';
import getDurations from '@salesforce/apex/Planification_Controller.getDurations';
import desactiver_thech from '@salesforce/apex/Planification_Controller.desactiver_thech';
//AIzaSyC9gozQDKQqd5n4_GSfdaWWLh254AGtd4c
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// import { getRecord } from 'lightning/uiRecordApi';
// import USER_ID from '@salesforce/user/Id';

// import PROFILE_NAME_FIELD from '@salesforce/schema/User.Profile.Name';

// const FIELDS = [PROFILE_NAME_FIELD];



export default class Lwc004_creneaux_all_planification extends LightningElement {
   @api prettyjson_month;
   @api prettyjson_week;
   @api mounth_or_week;
   @api planification_metadata_all;
   @api menu_selected;
   @api index_semaine;
   @api is_admin;
   @api is_community;


   daysOff = "";


   // Id = USER_ID;
   // @api  currentUserProfileName;

   //  is_admin = false;

   //  @wire(getRecord, { recordId: '$Id', fields: FIELDS })
   //  wiredUser({ error, data }) {
   //      if (data) {
   //          this.currentUserProfileName = data.fields.Profile.value.fields.Name.value;
   //          console.log(this.currentUserProfileName);
   //          console.log(this.currentUserProfileName);
   //          if( this.currentUserProfileName == 'Administrateur système')
   //             this.is_admin = true;
   //          else
   //          this.is_admin = false;

   //      } else if (error) {
   //          console.error('Error fetching user profile name', error);
   //      }
   //  }

   connectedCallback()
   {
      let time_wait = (this.index_semaine+1) * 1000;
      //console.log(time_wait);
      setTimeout(() => {
       
         this.get_actuers_planification(this.menu_selected , null ,this.prettyjson_week);
         console.log(' =====> ' + this.is_admin)

      } , time_wait );
   }



   get get_prettyjson_week()
   {
      if(this.prettyjson_week != undefined)
      {
         console.log("Check days : => ", this.prettyjson_week);
         var prettyjson_week = JSON.parse(this.prettyjson_week) 
         prettyjson_week.unshift(this.menu_selected + '/Semaine ' + (parseInt(this.index_semaine) + 1));
         return prettyjson_week;
      }
      else
        return undefined;
   }

   planning = []
   get get_get_actuers_planification()
   {
      if(this.planification_metadata_all != undefined)
      {
         this.planning = [];
         var planification_metadata_all = this.proxyToObj(this.planification_metadata_all);
         console.log(this.getplanning_menu_selected + "--" + planification_metadata_all.planifications[0].titre_menu);
         for(let i = 0 ; i < planification_metadata_all.planifications.length ; i++)
         {
            if(this.getplanning_menu_selected == planification_metadata_all.planifications[i].titre_menu)
            {
               get_actuers_planification({objet_acteur : planification_metadata_all.planifications[i].acteur.api_name_name , conditions_acteur : planification_metadata_all.planifications[i].acteur.condition_object_acteur , api_name_object_acteur : planification_metadata_all.planifications[i].acteur.api_name_object_acteur})
               .then(data => {
                  console.log(data);
                 // this.planning = data;

                  for(let r = 0 ; r < data.length ; r++)
                  {
                     this.planning.push({Id :  data[i].Id  , Name : data[i].Name , crenaux : planification_metadata_all.planifications[i].crenreaux });
                  }
                 

                
               })
               .catch(error => {
                  console.log(error);
               });
               break;
            }
         }
         //   console.log("----------------------");
           console.log(this.planning);
         return this.planning;
      }
      else
        return undefined;
   }


   get getplanning_menu_selected()
   {
      return this.menu_selected;
   }

   get get_mounth_or_week()
   {
      return this.mounth_or_week == 1 ? true : false;
   }


   get get_planning()
   {
      return this.planning;
   }

   
   get get_planning_bool()
   {
      return this.planning.length > 0 ? true : false;
   }

   proxyToObj(obj){
      return JSON.parse(JSON.stringify(obj));
   }
   
   search_key;
   spinner = false;
   planning = [];
   @api
    get_actuers_planification(menu_selected , search ,  prettyjson_week)
   {
      console.log("check if empty : ", prettyjson_week);
      var get_prettyjson_week = JSON.parse(prettyjson_week);

      get_prettyjson_week.unshift(menu_selected);

      if(this.planification_metadata_all != undefined)
      {
         this.spinner = true;
         this.planning = [];
         var planification_metadata_all = this.proxyToObj(this.planification_metadata_all);
         this.daysOff = planification_metadata_all?.daysOff ?? "";

         for(let i = 0 ; i < planification_metadata_all.planifications.length ; i++)
         {
            if(menu_selected == planification_metadata_all.planifications[i].titre_menu)
            {
             
               var dates_all = this.heure_string_to_heure(get_prettyjson_week[1] , get_prettyjson_week[get_prettyjson_week.length - 1]);


               // console.log('+_+_+_+_+_+_+_+ OP +_+_+_+_+_+_+_+_+_+');
               // console.log(planification_metadata_all.planifications[i].object_cible.api_champs_a_afficher_a_cote_date);
               // console.log(planification_metadata_all.planifications[i].object_cible.api_champs_a_afficher_a_cote_date);
               // console.log('+_+_+_+_+_+_+_+ OP +_+_+_+_+_+_+_+_+_+');
            
              get_actuers_cible_planification({
                  objet_acteur : planification_metadata_all.planifications[i].acteur.api_name_name , 
                  conditions_acteur : planification_metadata_all.planifications[i].acteur.condition_object_acteur , 
                  api_name_object_acteur : planification_metadata_all.planifications[i].acteur.api_name_object_acteur ,
                  couleur_api_name_acteur : planification_metadata_all.planifications[i].acteur.couleur_api_name_acteur,
                  api_name_relation_object_acteur_to_cible : planification_metadata_all.planifications[i].acteur.api_name_relation_object_acteur_to_cible,
                  date_cible : dates_all ,
                  api_name_date_planification : planification_metadata_all.planifications[i].object_cible.api_name_date_planification,
                  api_name_object_cible : planification_metadata_all.planifications[i].object_cible.api_name_object_cible,
                  api_champs_a_afficher :  planification_metadata_all.planifications[i].object_cible.api_champs_a_afficher,
                  condition_object_cible : planification_metadata_all.planifications[i].object_cible.condition_object_cible,
                  api_name_relation_object_cible_to_acteur : planification_metadata_all.planifications[i].object_cible.api_name_relation_object_cible_to_acteur,
                  cas_exception : planification_metadata_all.planifications[i].cas_exception,
                  api_champs_a_info_supl : planification_metadata_all.planifications[i].object_cible.api_champs_a_info_supl,
                  name_champs_a_info_supl : planification_metadata_all.planifications[i].object_cible.name_champs_a_info_supl,
                  api_champs_a_afficher_a_cote_date : planification_metadata_all.planifications[i].object_cible.api_champs_a_afficher_a_cote_date,
                  conges_champs_text_long_api_name : planification_metadata_all.planifications[i].acteur.conges_champs_text_long_api_name,
                  coodone_atitude_longitude : planification_metadata_all.planifications[i].object_cible.coodone_atitude_longitude,
                  api_name_badge : planification_metadata_all?.planifications[i]?.object_cible?.api_name_badge || "",
               })
               .then(data => {
                      console.log(data);
                          //console.log(search);
                          this.durations = [];
                        this.calcule_duree(data , planification_metadata_all.planifications[i] , search , get_prettyjson_week );
                        this.search_key = search;
                        if(search == undefined || search == '' || search == null)
                        {
                        var planning = [];
                        for(let r = 0 ; r < data.length ; r++)
                        {
                           var creneaux = [];
                           if(this.get_mounth_or_week == true)
                           {
                              for(let c = 1 ; c < get_prettyjson_week.length ; c++)
                              creneaux.push({ crenaux : planification_metadata_all.planifications[i].crenreaux , date : get_prettyjson_week[c] });
                           }

                         
                       
                           if(planification_metadata_all.planifications[i].acteur.couleur_api_name_acteur != null && planification_metadata_all.planifications[i].acteur.couleur_api_name_acteur != '')

                                 planning.push({Id :  data[r].Id  , 
                                 api_name_object_acteur : data[r][planification_metadata_all.planifications[i].acteur.api_name_object_acteur]  ,
                                 couleur_api_name_acteur :  "background:" + (data[r][planification_metadata_all.planifications[i].acteur.couleur_api_name_acteur] == undefined ? "#bababa" :  data[r][planification_metadata_all.planifications[i].acteur.couleur_api_name_acteur]) +";" , 
                                 crenaux_all : creneaux , 
                                 api_name_date_planification : planification_metadata_all.planifications[i].object_cible.api_name_date_planification,
                                 api_name_object_cible : planification_metadata_all.planifications[i].object_cible.api_name_object_cible,
                                 api_name_relation_object_cible_to_acteur : planification_metadata_all.planifications[i].object_cible.api_name_relation_object_cible_to_acteur,
                                 condition_object_cible : planification_metadata_all.planifications[i].object_cible.condition_object_cible,
                                 api_champs_a_afficher :  planification_metadata_all.planifications[i].object_cible.api_champs_a_afficher,
                                 condition_object_cible_couleur : planification_metadata_all.planifications[i].object_cible.condition_object_cible_couleur,
                                 list_event : data[r][planification_metadata_all.planifications[i].acteur.api_name_relation_object_acteur_to_cible] != null ? data[r][planification_metadata_all.planifications[i].acteur.api_name_relation_object_acteur_to_cible] : '',
                                 search : search,
                                 cas_exception : planification_metadata_all.planifications[i].cas_exception == "true" ? true : false,
                                 api_champs_a_info_supl : planification_metadata_all.planifications[i].object_cible.api_champs_a_info_supl,
                                 name_champs_a_info_supl : planification_metadata_all.planifications[i].object_cible.name_champs_a_info_supl,
                                 api_champs_a_afficher_a_cote_date : planification_metadata_all.planifications[i].object_cible.api_champs_a_afficher_a_cote_date,
                                 conges_champs_text_long_api_name : data[r][planification_metadata_all.planifications[i].acteur.conges_champs_text_long_api_name] != null ? data[r][planification_metadata_all.planifications[i].acteur.conges_champs_text_long_api_name] : '',
                                 coodone_atitude_longitude : planification_metadata_all.planifications[i].object_cible.coodone_atitude_longitude,
                                 api_name_badge : planification_metadata_all?.planifications[i]?.object_cible?.api_name_badge || "",
                              });
                           else {
                              planning.push({Id :  data[r].Id  ,
                                 api_name_object_acteur : data[r][planification_metadata_all.planifications[i].acteur.api_name_object_acteur]  ,  
                                 couleur_api_name_acteur : "background: #bababa ;" , 
                                 crenaux_all : creneaux , 
                                 api_name_date_planification : planification_metadata_all.planifications[i].object_cible.api_name_date_planification,
                                 api_name_object_cible : planification_metadata_all.planifications[i].object_cible.api_name_object_cible,
                                 api_name_relation_object_cible_to_acteur : planification_metadata_all.planifications[i].object_cible.api_name_relation_object_cible_to_acteur,
                                 condition_object_cible : planification_metadata_all.planifications[i].object_cible.condition_object_cible,
                                 api_champs_a_afficher :  planification_metadata_all.planifications[i].object_cible.api_champs_a_afficher,
                                 condition_object_cible_couleur : planification_metadata_all.planifications[i].object_cible.condition_object_cible_couleur,
                                 list_event : data[r][planification_metadata_all.planifications[i].acteur.api_name_relation_object_acteur_to_cible] != null ? data[r][planification_metadata_all.planifications[i].acteur.api_name_relation_object_acteur_to_cible] : '',
                                 search : search ,
                                 cas_exception : planification_metadata_all.planifications[i].cas_exception == "true" ? true : false,
                                 api_champs_a_info_supl : planification_metadata_all.planifications[i].object_cible.api_champs_a_info_supl,
                                 name_champs_a_info_supl : planification_metadata_all.planifications[i].object_cible.name_champs_a_info_supl,
                                 api_champs_a_afficher_a_cote_date : planification_metadata_all.planifications[i].object_cible.api_champs_a_afficher_a_cote_date,
                                 conges_champs_text_long_api_name : data[r][planification_metadata_all.planifications[i].acteur.conges_champs_text_long_api_name] != null ? data[r][planification_metadata_all.planifications[i].acteur.conges_champs_text_long_api_name] : '',
                                 coodone_atitude_longitude : planification_metadata_all.planifications[i].object_cible.coodone_atitude_longitude,
                                 api_name_badge : planification_metadata_all?.planifications[i]?.object_cible?.api_name_badge || ""

                              });
                        }

                        }
                        this.planning = planning;
                        this.spinner = false;
                        }
                 
                  

               })
               .catch(error => {
                  console.log(error);
               });
               break;
            }
         }
      }
   }



   async calcule_duree(data , planifications , search , get_prettyjson_week )
   {
      if(search != null && search != '')
      {
         let destinationPostalCodes = [];
         for(let r = 0 ; r < data.length ; r++)
         {  
               let list_event = data[r][planifications.acteur.api_name_relation_object_acteur_to_cible] != null ? data[r][planifications.acteur.api_name_relation_object_acteur_to_cible] : '';
               if(list_event != '')
                  {
                     
                     for(let j = 0 ; j < list_event.length ; j++)
                     {
                        //destinationPostalCodes.push(list_event[j][(planifications.object_cible.api_champs_a_afficher.split(','))[planifications.object_cible.api_champs_a_afficher.split(',').length-1].replace(/ /g, "")] /*+ ' France'*/);
                        destinationPostalCodes.push(list_event[j][planifications.object_cible.coodone_atitude_longitude.replace(/ /g, "")] /*+ ' France'*/);
                     }
                  }
         }


         

         // if(destinationPostalCodes.length > 0)
         // {
           // this.getDistances( search /*+ ' France' */, destinationPostalCodes , data , planifications  , search , get_prettyjson_week)

               this.getDistances( search /*+ ' France' */, destinationPostalCodes , data , planifications  , search , get_prettyjson_week)
               .then((durations) => {
                  //console.log('Durations:', durations);
               // return durations;
               })
               .catch((error) => {
                  console.error('Error:', error);
               });
        // }
      }
   }
    ss = 0;
    durations = [];
    index_api_key = 0;
    async getDistances(originPostalCode , destinationPostalCodes , data , planifications , search , get_prettyjson_week) {
      try {
         if(destinationPostalCodes.length > this.part_code_ppostaux)
         {
            var destinationPostalCodes_25 =  this.diviserListe(destinationPostalCodes);
            var duration_item = [];
            for(let i = 0 ; i < destinationPostalCodes_25.length ; i++)
            {
               console.table(destinationPostalCodes_25);
               duration_item.push(await getDurations({ originPostalCode, destinationPostalCodes : destinationPostalCodes_25[i] , index : this.index_api_key}));
               console.log('Durations:', this.durations);
               if(this.index_api_key < 3)
               {
                  this.index_api_key++; // 0 // 1 // 2 // 3 
               }
               else{
                  this.index_api_key=0;
               }
            }
            
            for(let r = 0 ; r < duration_item.length ; r++)
            {
               for(let j = 0 ; j < duration_item[r].length ; j++)
               {
                  this.durations.push(duration_item[r][j]);
               }
            }
         }
         else
         {
            console.table(destinationPostalCodes);

           this.durations = await getDurations({ originPostalCode, destinationPostalCodes ,  index : this.index_api_key });
           if(this.index_api_key < 3)
           {
              this.index_api_key++;
           }
           else{
              this.index_api_key=0;
           }
             console.log('Durations:', this.durations);
         }

         var planning = [];
         for(let r = 0 ; r < data.length ; r++)
         {
            var creneaux = [];
            if(this.get_mounth_or_week == true)
            {
               for(let c = 1 ; c < get_prettyjson_week.length ; c++)
               creneaux.push({ crenaux : planifications.crenreaux , date : get_prettyjson_week[c] });
            }

          
        
            if(planifications.acteur.couleur_api_name_acteur != null && planifications.acteur.couleur_api_name_acteur != '')

                  planning.push({Id :  data[r].Id  , 
                  api_name_object_acteur : data[r][planifications.acteur.api_name_object_acteur]  ,
                  couleur_api_name_acteur :  "background:" + (data[r][planifications.acteur.couleur_api_name_acteur] == undefined ? "#bababa" :  data[r][planifications.acteur.couleur_api_name_acteur]) +";" , 
                  crenaux_all : creneaux , 
                  api_name_date_planification : planifications.object_cible.api_name_date_planification,
                  api_name_object_cible : planifications.object_cible.api_name_object_cible,
                  api_name_relation_object_cible_to_acteur : planifications.object_cible.api_name_relation_object_cible_to_acteur,
                  condition_object_cible : planifications.object_cible.condition_object_cible,
                  api_champs_a_afficher :  planifications.object_cible.api_champs_a_afficher,
                  condition_object_cible_couleur : planifications.object_cible.condition_object_cible_couleur,
                  list_event : data[r][planifications.acteur.api_name_relation_object_acteur_to_cible] != null ? data[r][planifications.acteur.api_name_relation_object_acteur_to_cible] : '',
                  search : search,
                  cas_exception : planifications.cas_exception == "true" ? true : false,
                  api_champs_a_info_supl : planifications.object_cible.api_champs_a_info_supl,
                  name_champs_a_info_supl : planifications.object_cible.name_champs_a_info_supl,
                  api_champs_a_afficher_a_cote_date : planifications.object_cible.api_champs_a_afficher_a_cote_date,
                  conges_champs_text_long_api_name : data[r][planifications.acteur.conges_champs_text_long_api_name] != null ? data[r][planifications.acteur.conges_champs_text_long_api_name] : '',
                  coodone_atitude_longitude : planifications.object_cible.coodone_atitude_longitude,
                  api_name_badge : planifications.object_cible?.api_name_badge || "",
                  });
            else {
               planning.push({Id :  data[r].Id  ,
                  api_name_object_acteur : data[r][planifications.acteur.api_name_object_acteur]  ,  
                  couleur_api_name_acteur : "background: #bababa ;" , 
                  crenaux_all : creneaux , 
                  api_name_date_planification : planifications.object_cible.api_name_date_planification,
                  api_name_object_cible : planifications.object_cible.api_name_object_cible,
                  api_name_relation_object_cible_to_acteur : planifications.object_cible.api_name_relation_object_cible_to_acteur,
                  condition_object_cible : planifications.object_cible.condition_object_cible,
                  api_champs_a_afficher :  planifications.object_cible.api_champs_a_afficher,
                  condition_object_cible_couleur : planifications.object_cible.condition_object_cible_couleur,
                  list_event : data[r][planifications.acteur.api_name_relation_object_acteur_to_cible] != null ? data[r][planifications.acteur.api_name_relation_object_acteur_to_cible] : '',
                  search : search ,
                  cas_exception : planifications.cas_exception == "true" ? true : false,
                  api_champs_a_info_supl : planifications.object_cible.api_champs_a_info_supl,
                  name_champs_a_info_supl : planifications.object_cible.name_champs_a_info_supl,
                  api_champs_a_afficher_a_cote_date : planifications.object_cible.api_champs_a_afficher_a_cote_date,
                  conges_champs_text_long_api_name : data[r][planifications.acteur.conges_champs_text_long_api_name] != null ? data[r][planifications.acteur.conges_champs_text_long_api_name] : '',
                  coodone_atitude_longitude : planifications.object_cible.coodone_atitude_longitude,
                  api_name_badge : planifications.object_cible?.api_name_badge || "",
                  });
         }

         }
         this.planning = planning;
         this.spinner = false;
       
      } catch (error) {
          console.error('Error:', error);
      }
    }

      part_code_ppostaux = 55 ; // 24;
    diviserListe(liste) {
      const tailleGroupe = this.part_code_ppostaux;
      const result = [];
      const longueurListe = liste.length;
      let debut = 0;
    
      while (debut < longueurListe) {
        const fin = debut + tailleGroupe;
        const sousListe = liste.slice(debut, fin);
        result.push(sousListe);
        debut = fin;
      }
    
      return result;
    }




   heure_string_to_heure(dateString , dateString2)
   {
       var dateParts = dateString.split(" ");
       var day = parseInt(dateParts[1].split("/")[0]);
       var month = parseInt(dateParts[1].split("/")[1]) - 1; 
       var year = parseInt(dateParts[1].split("/")[2]);

       var dateParts2 = dateString2.split(" ");
       var day2 = parseInt(dateParts2[1].split("/")[0]);
       var month2 = parseInt(dateParts2[1].split("/")[1]) - 1; 
       var year2 = parseInt(dateParts2[1].split("/")[2]);

     
   
       var date = new Date();
       date.setDate(day);
       date.setMonth(month);
       date.setFullYear(year);
  


       var date2 = new Date();
       date2.setDate(day2);
       date2.setMonth(month2);
       date2.setFullYear(year2);



      var dates = [date , date2];

       return dates;
   }


   desactiver_thech(event)
   {
      
      var id = event.currentTarget.dataset.id ;
      let confirm_ = confirm("vous etes sur de le désactiver ?");
      if(confirm_)
      {
         // console.log("+!!++!+!!!++!");
         // console.log("+!!++!+!!!++!");
         // var planing = [];
         // for (let i = 0; i < this.planning.length; i++) {
         //    if (this.planning[i].Id == id) {
         //       planing =  this.planning.splice(i, 1);
         //       // Sortir de la boucle après la suppression de l'élément
         //    }
         //  }
         //  this.planning = planing;
         //  console.log("+!!++!+!!!++!");
         //  console.log(this.planning);
         //  console.log("+!!++!+!!!++!");

         desactiver_thech({Id : id})
         .then(data => {
            const evt = new ShowToastEvent({
               title: 'désactivation',
               message: data + ' (Après l\'actualisation de la page, elle disparaîtra !)',
               variant: 'success',
           });
           this.dispatchEvent(evt);
         
         })
      }
    
   }

   add_conges_var = false;
   _conges_acteur;
   add_conges(event)
   {
    
      this._conges_acteur = event.currentTarget.dataset.id;
      this.add_conges_var = true;
 

   }


   handleFermer(event)
   {
      this.add_conges_var = event.detail;
      this.get_actuers_planification(this.menu_selected ,  this.search_key != null ?  this.search_key :  null ,this.prettyjson_week);
   }



}