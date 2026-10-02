/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 04-11-2024
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
// public with sharing class VF_DisplayReportsChartController {


//     public String accountId {get;set;}
//     public String developerNameReport1 {get;set;}
//     public String developerNameReport2 {get;set;}
//     public String developerNameReport3 {get;set;}
//     public String developerNameReport4 {get;set;}
//     public String developerNameReport5 {get;set;}
//     public String developerNameReport6 {get;set;}
//     public String idReport1 {get;set;}
//     public String idReport2 {get;set;}
//     public String idReport3 {get;set;}
//     public String idReport4 {get;set;}
//     public String idReport5 {get;set;}
//     public String idReport6 {get;set;}
//     public String[] developerNameReports {get;set;}
//     public Integer counts {get;set;}
//     public String column {get;set;}
//     public String accountName {get;set;}

//     public String url1 {get;set;}
//     public String url2 {get;set;}
//     public String url3 {get;set;}
//     public String url4 {get;set;}
//     public String url5 {get;set;}
//     public String url6 {get;set;}
    
//     public Map<String, String> mapDevNameInfos {get;set;}

//     public VF_DisplayReportsChartController() { 
//         String[] developerNameReportsTemp = new String[]{};
//         Map<String, String> mapDevNameInfosTemp = new Map<String,String>();
//         Integer countsTemp = 0;
//         accountId = System.currentPageReference().getParameters().get('accountId') != null ? System.currentPageReference().getParameters().get('accountId') : null;
//         developerNameReport1 = System.currentPageReference().getParameters().get('developerNameReport1') != null ? System.currentPageReference().getParameters().get('developerNameReport1') : null;
//         developerNameReport2 = System.currentPageReference().getParameters().get('developerNameReport2') != null ? System.currentPageReference().getParameters().get('developerNameReport2') : null;
//         developerNameReport3 = System.currentPageReference().getParameters().get('developerNameReport3') != null ? System.currentPageReference().getParameters().get('developerNameReport3') : null;
//         developerNameReport4 = System.currentPageReference().getParameters().get('developerNameReport4') != null ? System.currentPageReference().getParameters().get('developerNameReport4') : null;
//         developerNameReport5 = System.currentPageReference().getParameters().get('developerNameReport5') != null ? System.currentPageReference().getParameters().get('developerNameReport5') : null;
//         developerNameReport6 = System.currentPageReference().getParameters().get('developerNameReport6') != null ? System.currentPageReference().getParameters().get('developerNameReport6') : null;
//         idReport1 = System.currentPageReference().getParameters().get('idReport1') != 'undefined' ? System.currentPageReference().getParameters().get('idReport1') : 'null'; 
//         idReport2 = System.currentPageReference().getParameters().get('idReport2') != 'undefined' ? System.currentPageReference().getParameters().get('idReport2') : 'null';
//         idReport3 = System.currentPageReference().getParameters().get('idReport3') != 'undefined' ? System.currentPageReference().getParameters().get('idReport3') : 'null';
//         idReport4 = System.currentPageReference().getParameters().get('idReport4') != 'undefined' ? System.currentPageReference().getParameters().get('idReport4') : 'null';
//         idReport5 = System.currentPageReference().getParameters().get('idReport5') != 'undefined' ? System.currentPageReference().getParameters().get('idReport5') : 'null';
//         idReport6 = System.currentPageReference().getParameters().get('idReport6') != 'undefined' ? System.currentPageReference().getParameters().get('idReport6') : 'null';

//         accountName = System.currentPageReference().getParameters().get('accountName');
//         column = System.currentPageReference().getParameters().get('column');
        
//         url1 ='/lightning/r/Report/'+idReport1+'/view?reportFilters=[{"column": "'+column+'","operator": "equals","value": "'+accountName+'"}]';
//         url2 ='/lightning/r/Report/'+idReport2+'/view?reportFilters=[{"column": "'+column+'","operator": "equals","value": "'+accountName+'"}]';
//         url3 ='/lightning/r/Report/'+idReport3+'/view?reportFilters=[{"column": "'+column+'","operator": "equals","value": "'+accountName+'"}]';
//         url4 ='/lightning/r/Report/'+idReport4+'/view?reportFilters=[{"column": "'+column+'","operator": "equals","value": "'+accountName+'"}]';
//         url5 ='/lightning/r/Report/'+idReport5+'/view?reportFilters=[{"column": "'+column+'","operator": "equals","value": "'+accountName+'"}]';
//         url6 ='/lightning/r/Report/'+idReport6+'/view?reportFilters=[{"column": "'+column+'","operator": "equals","value": "'+accountName+'"}]';

//         mapDevNameInfosTemp.put(developerNameReport1, url1);
//         mapDevNameInfosTemp.put(developerNameReport2, url2);
//         mapDevNameInfosTemp.put(developerNameReport3, url3);
//         mapDevNameInfosTemp.put(developerNameReport4, url4);
//         mapDevNameInfosTemp.put(developerNameReport5, url5);
//         mapDevNameInfosTemp.put(developerNameReport6, url6);

//         mapDevNameInfos = mapDevNameInfosTemp;

        

//         if (developerNameReport1 != 'null' ) {
//             developerNameReportsTemp.add(developerNameReport1);  
//             countsTemp++;
//         }
//         if (developerNameReport2 != 'null' ) {
//             developerNameReportsTemp.add(developerNameReport2);
//             countsTemp++;  
//         }
//         if (developerNameReport3 != 'null' ) {
//             developerNameReportsTemp.add(developerNameReport3); 
//             countsTemp++; 
//         }
//         if (developerNameReport4 != 'null' ) {
//             developerNameReportsTemp.add(developerNameReport4);
//             countsTemp++;  
//         }
//         if (developerNameReport5 != 'null' ) {
//             developerNameReportsTemp.add(developerNameReport5); 
//             countsTemp++; 
//         }
//         if (developerNameReport6 != 'null' ) {
//             developerNameReportsTemp.add(developerNameReport6);  
//             countsTemp++;
//         }
//         developerNameReports = developerNameReportsTemp;
//         counts = countsTemp;

        
//     }



// }
/**
 * @author Reda Mihradi
 * @date Création 
 * @date Modification 
 * @description  Controller pour la page VF_DisplayReportsChart
 */
public with sharing class VF_DisplayReportsChartController {

    public String accountId {get;set;}
    public String[] developerNameReports {get;set;}
    public Integer counts {get;set;}
    public String column {get;set;}
    public String accountName {get;set;}
    public Map<String, String> mapDevNameInfos {get;set;}

    public VF_DisplayReportsChartController() {
        accountId = System.currentPageReference().getParameters().get('accountId');
        accountName = System.currentPageReference().getParameters().get('accountName');
        column = System.currentPageReference().getParameters().get('column');

        mapDevNameInfos = new Map<String, String>();
        developerNameReports = new List<String>();
        counts = 0;
        System.debug('accountId: ' + accountId);
        System.debug('accountName: ' + accountName);
        System.debug('column: ' + column);
        initializeReportInfo('developerNameReport1', 'idReport1');
        initializeReportInfo('developerNameReport2', 'idReport2');
        initializeReportInfo('developerNameReport3', 'idReport3');
        initializeReportInfo('developerNameReport4', 'idReport4');
        initializeReportInfo('developerNameReport5', 'idReport5');
        initializeReportInfo('developerNameReport6', 'idReport6');
    }

    private void initializeReportInfo(String devNameParam, String idParam) {
        String developerName = System.currentPageReference().getParameters().get(devNameParam);
        String reportId = System.currentPageReference().getParameters().get(idParam);

        if (developerName != 'null' && reportId != 'undefined') {
            String url = '/lightning/r/Report/' + reportId + '/view?reportFilters=[{"column":"' + column + '","operator":"equals","value":"' + accountName + '"}]';
            mapDevNameInfos.put(developerName, url);
            developerNameReports.add(developerName);
            counts++;
        }
    }
}