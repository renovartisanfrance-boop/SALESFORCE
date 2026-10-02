/**
 * @ Author: Abdessamad AZZOUZI (©S@M+)
 * @ Create Time: 2025-01-21 17:31:10
 * @ Modified by: Abdessamad AZZOUZI (©S@M+)
 * @ Modified time: 2025-01-21 17:35:34
 * @ Description:
 */


public with sharing class Lwc014_GestionStocksController {

    @AuraEnabled(cacheable=true)
    public static List<StockPairs__mdt> getStockPairs() {
        return SM01_ElmentsStockMdt.getStockPairs();
    }
}