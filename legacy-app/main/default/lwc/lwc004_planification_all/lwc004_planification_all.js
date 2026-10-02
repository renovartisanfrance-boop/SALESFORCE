import { LightningElement , track , api , wire } from 'lwc';
import getConformeAutre from '@salesforce/apex/Planification_Controller.getConformeAutre';
import getplanification_metadata from '@salesforce/apex/Planification_Controller.getplanification_metadata';
import { refreshApex } from '@salesforce/apex';
import getDurations from '@salesforce/apex/Planification_Controller.getDurations';
import { getRecord } from 'lightning/uiRecordApi';
import makeZipCodeRequest from '@salesforce/apex/Planification_Controller.makeZipCodeRequest';



import USER_ID from '@salesforce/user/Id';

import PROFILE_NAME_FIELD from '@salesforce/schema/User.Profile.Name';

const FIELDS = [PROFILE_NAME_FIELD];

export default class Lwc004_planification_all extends LightningElement {


  get classDuration(){
    return this.showCaluclOnglet ? 'active_item_menu' : '';
  }
   get classDurationPro(){
    return this.showCaluclOngletPro ? 'active_item_menu' : '';
  }

    _confirme;
    _autre;
    @wire(getConformeAutre)
    wiredgetConformeAutre({ error, data })
    {
        if (data) {
            console.log(data);
            this._confirme = data.Conforme == undefined ? 0 :  data.Conforme ;
            this._autre = data.Autre == undefined ? 0 :  data.Autre ;
        }
        else if (error) {
            console.error(error);
        }
    }

    connectedCallback()
    {   
      const isInCommunity = this.isRunningInCommunity();
      if (isInCommunity) {
        this.is_community = true;
          console.log('The LWC is running in a community.');
      } else {
        this.is_community = false;
          console.log('The LWC is not running in a community.');
      }

    }


    isRunningInCommunity() {
      // Check the URL to determine if the LWC is running in a community
      const url = window.location.href;
      return url.includes('/s/planning');
  }

    activer_la_page = false;

    Id = USER_ID;
    @api  currentUserProfileName;
 
     is_admin = false;

     is_community = false;
 
     @wire(getRecord, { recordId: '$Id', fields: FIELDS })
     wiredUser({ error, data }) {
         if (data) {
             
             this.currentUserProfileName = data.fields.Profile.value.fields.Name.value;
             console.log(this.currentUserProfileName);
             console.log(this.currentUserProfileName);
             if( this.currentUserProfileName == 'Administrateur système')
                this.is_admin = true;
             else
             this.is_admin = false;

                if ( 
                  ['Administrateur système',
                  'PORTAIL INTERNE- Télépro',
                  'PORTAIL INTERNE- Responsable Telepro',
                  'PORTAIL INTERNE - Confirmateur',
                  'PORTAIL INTERNE - Gestion Planning',
                  'PORTAIL INTERNE- Closer',
                  'PORTAIL INTERNE- Closer LEDS'
                  ].includes(this.currentUserProfileName)
                )
                {
                          this.activer_la_page = true;
                }
               else
               {
                this.activer_la_page = false;
               }
 
         } else if (error) {
             console.error('Error fetching user profile name', error);
         }
     }
 


  


    index_1 = false;
    index_2 = true;
    handleClick_navigation(event)
    {
      var navigation_index =  event.currentTarget.dataset.id;
      if(navigation_index == '1')
      {
         this.index_1 = true;
      }
      else
      {
        this.index_1 = false;
      }
      if(navigation_index == '2')
      {
         this.index_2 = true;
      }
      else
      {
        this.index_2 = false;
      }
    }


    handleDataFromChild_parametrage(event) {
      const dataFromChild = event.detail;
      this.index_1 = dataFromChild.index_1;
      this.index_2 = !dataFromChild.index_1;
      this._planification_metadata_all =  dataFromChild._planification_metadata;
      this._planification_metadata = dataFromChild._planification_metadata.planifications;
      this._planification_metadata[0].active_item_menu = true;
     }

  refreshData() {
    refreshApex(this.wiredgetplanification_metadata);
  }
  _planification_metadata_all;
  _planification_metadata;
  _get_menu;
  @wire(getplanification_metadata)
  wiredgetplanification_metadata({ error, data })
  {
      if (data) {
          this._planification_metadata_all = data;
          console.log(this._planification_metadata_all);
          this._planification_metadata = data.planifications;
          this.menu_selected = this._planification_metadata[0].titre_menu; /* Abdessamad */
          // this.gerer_times(new Date((new Date).getFullYear(),(new Date).getMonth(),(new Date).getDate()));
          this.calculer_week_mounth(true , null);
      }
      else if (error) {
          console.error(error);
      }
  }
  @api index
  get first_index()
  {
     return this.index;
  }


  gerer_times(date)
  {
          var weekDates = this.getWeekDates(date);
          // var monthWeeks = this.getMonthWeeks(date);
          var monthWeeks = this.getWeekDates_v2(date);
      

          this._prettyjson_week = JSON.stringify(weekDates, undefined, 4)
          this._prettyjson_month = [];

          monthWeeks.forEach(element => {
            this._prettyjson_month.push( JSON.stringify(element, undefined, 4));
          });

          // console.log(this._prettyjson_month[0]);
  }


  get get_prettyjson_month()
  {
    return this._prettyjson_month;
  }


  get get_mounth_or_week()
  {
    return this.mounth_or_week == 1 ? true : false ;
  }





  menu_selected = "";
  _prettyjson_week;
  _prettyjson_month;
  go_to_planning(event)
  {
    var parent = event.target.parentElement.children;
     for(let i = 0 ; i < parent.length ; i++)
     {
        if(parent[i].classList.contains("active_item_menu") == true)
        {
          parent[i].classList.remove("active_item_menu");
        }
     }
      event.target.classList.add("active_item_menu");
      this.menu_selected = event.target.dataset.id;
       this.template.querySelector("c-lwc004_creneaux_all_planification").get_actuers_planification(this.menu_selected , null ,this._prettyjson_week);  

      var creneaux_all_planification = this.template.querySelectorAll("c-lwc004_creneaux_all_planification");   
      let index = 0 ;// this.get_prettyjson_month.length - 1 //0;
       creneaux_all_planification.forEach(element => {
          setTimeout(() => {
          element.get_actuers_planification(this.menu_selected , null,  this.get_prettyjson_month[index]);
          index++;
          } , 500);
      });

     // this.gerer_times();
  }

  go_to_calcul(event){
    let parent = this.template.querySelectorAll('.active_item_menu');
    parent.forEach(element => {
      element.classList.remove('active_item_menu');
    });
    const dataId = event.target.dataset.id;
    console.log('dataId ===> ' + dataId);
    if(dataId === 'Opportunité'){
      this.menu_selected = 'Calcul';
    } else if(dataId === 'Pro'){
      this.menu_selected = 'CalculPro';
    }
  }

  get showCaluclOnglet(){
    return this.menu_selected == 'Calcul';
  }

  get showCaluclOngletPro(){
    return this.menu_selected == 'CalculPro';
  }

  get showDivSearch(){
    return this.menu_selected != 'Calcul' && this.menu_selected != 'CalculPro';
  }


   getWeekDates_v2(date) {
    var days = ['dimanche', 'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi'];
    var weeks = [];
  
    var dayOfWeek = date.getDay();
    var diff = dayOfWeek - 1;
  
    var monday = new Date(date);
    monday.setDate(date.getDate() - diff);
  
    for (var j = 0; j < 4; j++) { // Boucle pour obtenir les 4 semaines
      var weekDates = [];
      for (var i = 0; i < 7; i++) { // Boucle pour obtenir les dates de chaque semaine
        var currentDate = new Date(monday);
        currentDate.setDate(monday.getDate() + i);
  
        if (currentDate.getDay() !== 0 /*&& currentDate.getDay() !== 6*/) {
          weekDates.push(currentDate.toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'numeric', year: 'numeric' }));
        }
      }
      weeks.push(weekDates); // Ajouter le tableau des dates de la semaine au tableau des semaines
      monday.setDate(monday.getDate() + 7); // Passer à la semaine suivante
    }
  
    return weeks;
  }
  


  getWeekDates(date) {
    var days = ['dimanche', 'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi'];
    var weekDates = [];
  

    var dayOfWeek = date.getDay();
  
    var diff = dayOfWeek - 1; 
  

    var monday = new Date(date);
    monday.setDate(date.getDate() - diff);

    // weekDates.push( this.menu_selected );

    for (var i = 0; i < 7; i++) {
      var currentDate = new Date(monday);
      currentDate.setDate(monday.getDate() + i);
      

      if (currentDate.getDay() !== 0 && currentDate.getDay() !== 6) {
        weekDates.push(currentDate.toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'numeric', year: 'numeric' }));
      }
    }
  
    return weekDates;
  }
  
  getMonthWeeks(date) {
    var year = date.getFullYear();
    var month = date.getMonth();
    var weeks = [];
    var currentDate = new Date(year, month, 1);
    var firstDay = currentDate.getDay();
    var daysInMonth = new Date(year, month + 1, 0).getDate();
    var currentWeek = [];
  
    for (var i = firstDay - 1; i >= 0; i--) {
      var previousDate = new Date(year, month, -i);
      if (previousDate.getDay() !== 0 && previousDate.getDay() !== 6) {
      currentWeek.push(previousDate.toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'numeric', year: 'numeric' }));

        if (previousDate.getDay() === 5) {
          weeks.push(currentWeek);
          currentWeek = [];
        }
     }

    }
    var dernierDate;
    for (var day = 1; day <= daysInMonth; day++) {
      var currentDate = new Date(year, month, day);
       dernierDate = currentDate;
      if (currentDate.getDay() !== 0 && currentDate.getDay() !== 6) {
        currentWeek.push(currentDate.toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'numeric', year: 'numeric' }));
  
        if (currentDate.getDay() === 5 || day === daysInMonth) {
          weeks.push(currentWeek);
          currentWeek = [];
        }
      }
    }

    if(weeks[weeks.length - 1].length < 5)
    { 
      for (var day = weeks[weeks.length - 1].length - 1; day < 5; day++) {
        dernierDate.setDate(dernierDate.getDate() + 1);
        if (currentDate.getDay() !== 0 && currentDate.getDay() !== 6) {          
          weeks[weeks.length - 1].push(dernierDate.toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'numeric', year: 'numeric' }));
        }
      }  
    }
  
    if (currentWeek.length > 0) {
      weeks.push(currentWeek);
    }
 
    return weeks;
  }

  converteDateStringToDate(dateString)
  {
      var dayMonthYear = dateString.split(" ")[1].split("/");
      var day = parseInt(dayMonthYear[0], 10);
      var month = parseInt(dayMonthYear[1], 10) - 1;
      var year = parseInt(dayMonthYear[2], 10);
      
      var date = new Date(year, month, day);
      return date
  }
  

  mounth_or_week = 1;
  _time_select(event)
  {
    this.mounth_or_week = event.target.value;
   // mounth_or_week = 1 week
   // mounth_or_week = 2 mounth

  }

  //Semaine 20-02-23/24-02-23
  date = new Date((new Date).getFullYear(),(new Date).getMonth(),(new Date).getDate());
  value_week_option;
  value_mounth_option;
  calculer_week_mounth(init , plus)
  {
    if(init == true)
    {
        this.gerer_times(this.date);
        var _prettyjson_week_first = this.converteDateStringToDate(JSON.parse(this._prettyjson_week)[0]);
        var _prettyjson_week_last  = this.converteDateStringToDate(JSON.parse(this._prettyjson_week)[JSON.parse(this._prettyjson_week).length-1]);
        this.value_week_option = "Semaine " + _prettyjson_week_first.getDate() + "-" +   (_prettyjson_week_first.getMonth()+1) + "/" + _prettyjson_week_last.getDate() + "-" +   (_prettyjson_week_last.getMonth() + 1);
        this.gerer_times(this.date);
        this.value_mounth_option = "Mois " + (_prettyjson_week_first.getMonth()+1) + "-" + _prettyjson_week_first.getFullYear();
    }
    else
    {
      if(this.mounth_or_week == 1)
      {
        let r = (plus == true ?  7 : -7);
        console.log(r)
        this.date.setDate(this.date.getDate() + r);
        this.gerer_times(this.date);
        var _prettyjson_week_first = this.converteDateStringToDate(JSON.parse(this._prettyjson_week)[0]);
        var _prettyjson_week_last  = this.converteDateStringToDate(JSON.parse(this._prettyjson_week)[JSON.parse(this._prettyjson_week).length-1]);
        this.value_week_option = "Semaine " + _prettyjson_week_first.getDate() + "-" +  (_prettyjson_week_first.getMonth()+1) + "/" + _prettyjson_week_last.getDate() + "-" + (_prettyjson_week_last.getMonth() + 1);
        this.value_mounth_option = "Mois " +(_prettyjson_week_first.getMonth()+1) + "-" + _prettyjson_week_first.getFullYear();
      }
      else
      {
        let r = (plus == true ?  1 : -1);
        console.log(r)
        this.date.setMonth(this.date.getMonth() + r);
        this.gerer_times(this.date);
        var _prettyjson_week_first = this.converteDateStringToDate(JSON.parse(this._prettyjson_week)[0]);
        var _prettyjson_week_last  = this.converteDateStringToDate(JSON.parse(this._prettyjson_week)[JSON.parse(this._prettyjson_week).length-1]);
        this.value_week_option = "Semaine " + _prettyjson_week_first.getDate() + "-" +  (_prettyjson_week_first.getMonth()+1) + "/" + _prettyjson_week_last.getDate() + "-" +  (_prettyjson_week_last.getMonth() + 1);
        this.value_mounth_option = "Mois " + (_prettyjson_week_first.getMonth()+1) + "-" + _prettyjson_week_first.getFullYear();
      }
    } 

  }


  calculer_moins(event)
  {
  this.template.querySelector('._search').value = '';
    this.calculer_week_mounth(false  , false).then(()=>{
      var creneaux_all_planification = this.template.querySelectorAll("c-lwc004_creneaux_all_planification");   
      let index = 0 ;// this.get_prettyjson_month.length - 1 //0;
       creneaux_all_planification.forEach(element => {
          setTimeout(() => {
          element.get_actuers_planification(this.menu_selected , null,  this.get_prettyjson_month[index]);
          index++;
          } , 500);
      });
  
    });

  }


  calculer_plus(event)
  {
    this.template.querySelector('._search').value = '';
    this.calculer_week_mounth(false , true).then(()=>{
      var creneaux_all_planification = this.template.querySelectorAll("c-lwc004_creneaux_all_planification");   
      let index = 0 ;// this.get_prettyjson_month.length - 1 //0;
       creneaux_all_planification.forEach(element => {
          setTimeout(() => {
          element.get_actuers_planification(this.menu_selected , null,  this.get_prettyjson_month[index]);
          index++;
          } , 500);
      });
  
    });
  }


  Calculer_les_trajets()
  {
    //  if(!this.isNumber(this.template.querySelector('._search').value))
    //  {
    //       alert('La valeur du code postal doit être un entier.')
    //  }
    //  else
    //  {

    makeZipCodeRequest({zipcode: this.template.querySelector('._search').value })
    .then(data => {
      var creneaux_all_planification = this.template.querySelectorAll("c-lwc004_creneaux_all_planification");   
      let index = 0 ;// this.get_prettyjson_month.length - 1 //0;
      console.log("data ======== > " + data);
      creneaux_all_planification.forEach(element => {
        //  setTimeout(() => {
          element.get_actuers_planification(this.menu_selected , data ,  this.get_prettyjson_month[index]);
          index++;
        //  } , 500);
      });
    }).catch(error => {
      console.log("error ======== > " , error);
    });
      

      // if(this.mounth_or_week == 2)
      // {
      //   let index = 0;
      //   const processElement = () => {
      //     const element = creneauxAllPlanification[index];
      //     if (element) {
      //       element.get_actuers_planification(this.menu_selected, this.template.querySelector('._search').value, this.get_prettyjson_month[index]);
      //       index++;
      //       if (index < creneauxAllPlanification.length) {
      //         setTimeout(processElement, 2000);
      //       }
      //     }
      //   };
      
      //   if (creneauxAllPlanification.length > 0) {
      //     setTimeout(processElement, 2000);
      //   }
      // }


   // }
  }



  isNumber(n){
    return typeof(n) != "boolean" && !isNaN(n);
  }

}