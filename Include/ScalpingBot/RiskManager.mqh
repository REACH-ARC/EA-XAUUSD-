//+------------------------------------------------------------------+
//|                                                 RiskManager.mqh |
//|                                    Copyright 2024, Scalping Bot |
//+------------------------------------------------------------------+
#property copyright "Scalping Bot"
#property link      ""
#property version   "1.00"

#include "Logger.mqh"

class CRiskManager
{
private:
   double            m_riskPercent;
   double            m_dailyLossLimitPercent;
   int               m_maxConcurrentTrades;
   double            m_maxLotSize;
   CLogger*          m_logger;
   string            m_symbol;
   ulong             m_magic;

   double            m_startOfDayBalance;

public:
                     CRiskManager();
                     ~CRiskManager();
                     
   void              Init(string symbol, ulong magic, double riskPercent, double dailyLossLimit, int maxConcurrent, double maxLotSize, CLogger* logger);
   
   double            CalculateLotSize(double sl_distance_points);
   bool              CanTrade();
   void              UpdateDailyBalance();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CRiskManager::CRiskManager() : m_startOfDayBalance(0)
{
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CRiskManager::~CRiskManager()
{
}

//+------------------------------------------------------------------+
//| Initialize                                                       |
//+------------------------------------------------------------------+
void CRiskManager::Init(string symbol, ulong magic, double riskPercent, double dailyLossLimit, int maxConcurrent, double maxLotSize, CLogger* logger)
{
   m_symbol = symbol;
   m_magic = magic;
   m_riskPercent = riskPercent;
   m_dailyLossLimitPercent = dailyLossLimit;
   m_maxConcurrentTrades = maxConcurrent;
   m_maxLotSize = maxLotSize;
   m_logger = logger;

   UpdateDailyBalance();
}

//+------------------------------------------------------------------+
//| Calculate dynamic lot size based on Stop Loss distance           |
//+------------------------------------------------------------------+
double CRiskManager::CalculateLotSize(double sl_distance_points)
{
   if(sl_distance_points <= 0) return 0.01;
   
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (m_riskPercent / 100.0);
   
   double tickSize = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
   
   // Formula: Lot = RiskAmount / (SL_Points * TickValue / TickSize)
   double lot = riskAmount / (sl_distance_points * tickValue);
   
   // Clamp to min/max/step allowed by broker
   double minLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
   
   lot = MathRound(lot / stepLot) * stepLot;
   
   // Check if we have enough margin for this lot size
   double marginPerLot = 0;
   if(OrderCalcMargin(ORDER_TYPE_BUY, m_symbol, 1.0, SymbolInfoDouble(m_symbol, SYMBOL_ASK), marginPerLot) && marginPerLot > 0)
   {
      double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      // Leave a small 5% buffer of free margin
      double affordableLot = (freeMargin * 0.95) / marginPerLot;
      affordableLot = MathFloor(affordableLot / stepLot) * stepLot;
      
      if(lot > affordableLot)
      {
         m_logger.Warn(StringFormat("Lot reduced from %.2f to %.2f due to margin constraints.", lot, affordableLot));
         lot = affordableLot;
      }
   }
   
   if(lot < minLot) lot = minLot;
   if(lot > maxLot) lot = maxLot;

   // Hard cap to protect small/cent accounts from oversized positions
   if(m_maxLotSize > 0 && lot > m_maxLotSize)
   {
      m_logger.Warn(StringFormat("Lot capped from %.2f to %.2f by MaxLotSize limit.", lot, m_maxLotSize));
      lot = m_maxLotSize;
   }

   return lot;
}

//+------------------------------------------------------------------+
//| Check if trading is allowed based on limits                      |
//+------------------------------------------------------------------+
bool CRiskManager::CanTrade()
{
   // 1. Check concurrent trades
   int activePositions = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetString(POSITION_SYMBOL) == m_symbol && PositionGetInteger(POSITION_MAGIC) == m_magic)
      {
         activePositions++;
      }
   }
   
   if(activePositions >= m_maxConcurrentTrades)
   {
      m_logger.Debug("Max concurrent trades reached.");
      return false;
   }
   
   // 2. Check Daily Drawdown
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double dailyLoss = m_startOfDayBalance - equity;
   double maxAllowedLoss = m_startOfDayBalance * (m_dailyLossLimitPercent / 100.0);
   
   if(dailyLoss > maxAllowedLoss && m_startOfDayBalance > 0)
   {
      m_logger.Warn(StringFormat("Daily loss limit reached! Allowed: %.2f, Current Loss: %.2f", maxAllowedLoss, dailyLoss));
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Update the starting balance for daily loss calculation           |
//+------------------------------------------------------------------+
void CRiskManager::UpdateDailyBalance()
{
   // Called once a day (e.g. at server hour 0)
   m_startOfDayBalance = AccountInfoDouble(ACCOUNT_BALANCE);
}
//+------------------------------------------------------------------+
