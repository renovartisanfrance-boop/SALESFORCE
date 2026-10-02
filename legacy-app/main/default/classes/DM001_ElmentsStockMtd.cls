/**
 * @ Author: Abdessamad AZZOUZI (©S@M+)
 * @ Create Time: 2025-01-21 17:32:52
 * @ Modified by: Abdessamad AZZOUZI (©S@M+)
 * @ Modified time: 2025-01-21 17:33:10
 * @ Description:
 */


public with sharing class DM001_ElmentsStockMtd {
    public static List<StockPairs__mdt> getStockPairs() {
        return [SELECT Id, MasterLabel, Label__c, ElmentsStock__c FROM StockPairs__mdt];
    }
}