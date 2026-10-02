/**
 * @author Reda Mihradi
 * @date Création 
 * @date Modification 
 */
public with sharing class lWC003_DisplayReportChartController {
    /**
 * @author Reda Mihradi
 * @date Création 
 * @date Modification 
 *  @description  Permet de créer une map de developerName et Ids de report
 */
    @AuraEnabled
    public static Map<String,String> getMapDeveloperNameIdsByDevNames(List<String> listeDeveloperNames){
        return DM013_Report.getMapDeveloperNameIdsByDevNames(listeDeveloperNames);
    }
}