import { LightningElement } from 'lwc';
import bannerPage from '@salesforce/resourceUrl/bannerPage';

export default class Lwc001_banner extends LightningElement {
    bannerPage = bannerPage;

    get backgroundStyle() {
        return `background-image:url(${bannerPage})`;
    }
}