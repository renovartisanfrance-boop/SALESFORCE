import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import LightningModal from 'lightning/modal';
// Importez votre composant modal existant
// import YourExistingModal from 'c/yourExistingModalComponent';

export default class Lwc015_RecapEtInfos extends NavigationMixin(LightningElement){
// export default class Lwc015_RecapEtInfos extends LightningElement {
    countdown = 60;
    intervalId;
    isVisible = true;
    
    connectedCallback() {
        // this.startCountdown();
    }
    
    startCountdown() {
        this.intervalId = setInterval(() => {
            this.countdown--;
            
            if (this.countdown <= 0) {
                this.countdown = 60;
            }
        }, 1000);
    }
    
    handleDismiss() {
        this.isVisible = false;
    }

    showModal = false;
       // Ouvrir le modal
    handleNewFolder() {
        console.log('Ouvrir le modal pour créer un nouveau dossier');
        this[NavigationMixin.Navigate]({
                type: 'standard__objectPage',
                attributes: {
                    objectApiName: 'Lead',
                    actionName: 'new'
                },
                state : {
                    count: '1',
                    nooverride: '1',
                    useRecordTypeCheck : '1',
                    // defaultFieldValues: inheritParentString,
                    // navigationLocation: 'RELATED_LIST'
                }
            });
        //this.showModal = true;
    }
    
    // Fermer le modal
    closeModal() {
        this.showModal = false;
    }
    
    // Sauvegarder et fermer
    handleSave() {
        // Logique de sauvegarde ici
        console.log('Dossier créé');
        this.showModal = false;
    }
    
    disconnectedCallback() {
        if (this.intervalId) {
            clearInterval(this.intervalId);
        }
    }
    
    get formattedTime() {
        const minutes = Math.floor(this.countdown / 60);
        const seconds = this.countdown % 60;
        return `${minutes}:${seconds.toString().padStart(2, '0')}`;
    }
    
    get progressPercentage() {
        return ((60 - this.countdown) / 60) * 100;
    }
    
    get progressStyle() {
        const circumference = 2 * Math.PI * 38;
        const offset = circumference - (this.progressPercentage / 100) * circumference;
        return `stroke-dashoffset: ${offset}`;
    }
    
    get isUrgent() {
        return this.countdown <= 10;
    }
    
    get notificationClass() {
        return this.isUrgent ? 'notification-card urgent' : 'notification-card';
    }
    
    get urgentIcon() {
        return this.isUrgent ? '🔥' : '⏰';
    }
}