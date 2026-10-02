/**
 * @ Author: Abdessamad AZZOUZI (©S@M+)
 * @ Create Time: 2025-01-21 17:33:33
 * @ Modified by: Abdessamad AZZOUZI (©S@M+)
 * @ Modified time: 2025-01-21 17:33:54
 * @ Description:
 */


public with sharing class SM01_ElmentsStockMdt {
    public static List<StockPairs__mdt> getStockPairs() {
        return DM001_ElmentsStockMtd.getStockPairs();
    }
}