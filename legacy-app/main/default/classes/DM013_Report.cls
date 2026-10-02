/**
 * @author Reda Mihradi
 */
public with sharing class DM013_Report {
    
/**
 * @author Reda Mihradi
 * @date Création 
 * @date Modification 
 *  @description  Permet de créer une map de developerName et Ids de report
 */
    public static Map<String,String> getMapDeveloperNameIdsByDevNames(List<String> listeDeveloperNames){
        List<Report>  reports  = [SELECT id,DeveloperName from Report where DeveloperName IN :listeDeveloperNames];
        Map<String,String> mapDeveloperNameIdsByDevNames = new Map<String,String>();
        for(Report report : reports){
            mapDeveloperNameIdsByDevNames.put(report.DeveloperName,report.id);
        }
        return mapDeveloperNameIdsByDevNames;
    }
}