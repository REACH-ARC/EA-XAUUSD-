//+------------------------------------------------------------------+
//|                                                    Strategy.mqh |
//|                                    Copyright 2024, Scalping Bot |
//+------------------------------------------------------------------+
#property copyright "Scalping Bot"
#property link      ""
#property version   "1.00"

#include "Logger.mqh"

enum SIGNAL_TYPE {
   SIGNAL_NONE,
   SIGNAL_BUY,
   SIGNAL_SELL
};

class CStrategy
{
private:
   int               m_emaFastPeriod;
   int               m_emaSlowPeriod;
   int               m_maxSpreadPoints;
   int               m_startHour;
   int               m_endHour;
   
   ENUM_TIMEFRAMES   m_htfTimeframe;
   int               m_htfEmaPeriod;
   int               m_rsiPeriod;
   int               m_atrPeriod;
   bool              m_useAtr;
   double            m_atrSlMultiplier;
   double            m_atrTpMultiplier;
   
   int               m_emaFastHandle;
   int               m_emaSlowHandle;
   int               m_htfEmaHandle;
   int               m_rsiHandle;
   int               m_atrHandle;
   
   double            m_emaFastBuffer[];
   double            m_emaSlowBuffer[];
   double            m_htfEmaBuffer[];
   double            m_rsiBuffer[];
   double            m_atrBuffer[];
   
   CLogger*          m_logger;
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;

public:
                     CStrategy();
                     ~CStrategy();
                     
   bool              Init(string symbol, ENUM_TIMEFRAMES tf, int emaFast, int emaSlow, int maxSpread, int startH, int endH, 
                          ENUM_TIMEFRAMES htf_tf, int htf_ema, int rsi_period, bool use_atr, int atr_period, double atr_sl_mult, double atr_tp_mult,
                          CLogger* logger);
   void              Deinit();
   
   bool              CheckMarketConditions();
   SIGNAL_TYPE       EvaluateEntry(double &out_sl_distance, double &out_tp_distance, double default_sl, double default_tp);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CStrategy::CStrategy() : m_emaFastHandle(INVALID_HANDLE), m_emaSlowHandle(INVALID_HANDLE),
                         m_htfEmaHandle(INVALID_HANDLE), m_rsiHandle(INVALID_HANDLE), m_atrHandle(INVALID_HANDLE)
{
   ArraySetAsSeries(m_emaFastBuffer, true);
   ArraySetAsSeries(m_emaSlowBuffer, true);
   ArraySetAsSeries(m_htfEmaBuffer, true);
   ArraySetAsSeries(m_rsiBuffer, true);
   ArraySetAsSeries(m_atrBuffer, true);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CStrategy::~CStrategy()
{
   Deinit();
}

//+------------------------------------------------------------------+
//| Initialize handles                                               |
//+------------------------------------------------------------------+
bool CStrategy::Init(string symbol, ENUM_TIMEFRAMES tf, int emaFast, int emaSlow, int maxSpread, int startH, int endH, 
                     ENUM_TIMEFRAMES htf_tf, int htf_ema, int rsi_period, bool use_atr, int atr_period, double atr_sl_mult, double atr_tp_mult,
                     CLogger* logger)
{
   m_symbol = symbol;
   m_timeframe = tf;
   m_emaFastPeriod = emaFast;
   m_emaSlowPeriod = emaSlow;
   m_maxSpreadPoints = maxSpread;
   m_startHour = startH;
   m_endHour = endH;
   
   m_htfTimeframe = htf_tf;
   m_htfEmaPeriod = htf_ema;
   m_rsiPeriod = rsi_period;
   m_useAtr = use_atr;
   m_atrPeriod = atr_period;
   m_atrSlMultiplier = atr_sl_mult;
   m_atrTpMultiplier = atr_tp_mult;
   
   m_logger = logger;
   
   m_emaFastHandle = iMA(m_symbol, m_timeframe, m_emaFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
   m_emaSlowHandle = iMA(m_symbol, m_timeframe, m_emaSlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
   
   m_htfEmaHandle = iMA(m_symbol, m_htfTimeframe, m_htfEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   m_rsiHandle = iRSI(m_symbol, m_timeframe, m_rsiPeriod, PRICE_CLOSE);
   
   if(m_useAtr)
      m_atrHandle = iATR(m_symbol, m_timeframe, m_atrPeriod);
   
   if(m_emaFastHandle == INVALID_HANDLE || m_emaSlowHandle == INVALID_HANDLE || 
      m_htfEmaHandle == INVALID_HANDLE || m_rsiHandle == INVALID_HANDLE || 
      (m_useAtr && m_atrHandle == INVALID_HANDLE))
   {
      m_logger.Error("Failed to create indicator handles.");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Deinitialize                                                     |
//+------------------------------------------------------------------+
void CStrategy::Deinit()
{
   if(m_emaFastHandle != INVALID_HANDLE) IndicatorRelease(m_emaFastHandle);
   if(m_emaSlowHandle != INVALID_HANDLE) IndicatorRelease(m_emaSlowHandle);
   if(m_htfEmaHandle != INVALID_HANDLE) IndicatorRelease(m_htfEmaHandle);
   if(m_rsiHandle != INVALID_HANDLE) IndicatorRelease(m_rsiHandle);
   if(m_atrHandle != INVALID_HANDLE) IndicatorRelease(m_atrHandle);
}

//+------------------------------------------------------------------+
//| Filter out bad conditions (spread, time)                         |
//+------------------------------------------------------------------+
bool CStrategy::CheckMarketConditions()
{
   // Spread filter
   long spread = SymbolInfoInteger(m_symbol, SYMBOL_SPREAD);
   if(spread > m_maxSpreadPoints)
   {
      m_logger.Info(StringFormat("Spread too high: %d (max: %d)", spread, m_maxSpreadPoints));
      return false;
   }

   // Session filter
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.hour < m_startHour || dt.hour >= m_endHour)
   {
      m_logger.Info(StringFormat("Outside session: broker hour=%d (session: %d-%d)", dt.hour, m_startHour, m_endHour));
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Core trading logic (Pullback to EMA)                             |
//+------------------------------------------------------------------+
SIGNAL_TYPE CStrategy::EvaluateEntry(double &out_sl_distance, double &out_tp_distance, double default_sl, double default_tp)
{
   // Initialize outputs to defaults
   out_sl_distance = default_sl;
   out_tp_distance = default_tp;

   if(CopyBuffer(m_emaFastHandle, 0, 1, 3, m_emaFastBuffer) <= 0 ||
      CopyBuffer(m_emaSlowHandle, 0, 1, 3, m_emaSlowBuffer) <= 0 ||
      CopyBuffer(m_rsiHandle, 0, 1, 3, m_rsiBuffer) <= 0 ||
      CopyBuffer(m_htfEmaHandle, 0, 1, 3, m_htfEmaBuffer) <= 0)
   {
      return SIGNAL_NONE;
   }
   
   if(m_useAtr && CopyBuffer(m_atrHandle, 0, 1, 3, m_atrBuffer) <= 0)
   {
      return SIGNAL_NONE;
   }
   
   double close1 = iClose(m_symbol, m_timeframe, 1);
   double open1 = iOpen(m_symbol, m_timeframe, 1);
   double low1 = iLow(m_symbol, m_timeframe, 1);
   double high1 = iHigh(m_symbol, m_timeframe, 1);
   
   double emaFast1 = m_emaFastBuffer[0];
   double emaSlow1 = m_emaSlowBuffer[0];
   double rsi1 = m_rsiBuffer[0];
   
   // MT5 handles HTF indicator synchronization automatically, index 0 matches current time reasonably
   double htfEma1 = m_htfEmaBuffer[0]; 
   
   // Check Buy conditions
   // HTF Filter: Price must be above HTF EMA
   // RSI Filter: RSI cooled off (between 30 and 60)
   if(close1 > htfEma1 && rsi1 > 30 && rsi1 < 60)
   {
      if(emaFast1 > emaSlow1 && low1 <= emaFast1 && close1 > open1)
      {
         if(m_useAtr)
         {
            out_sl_distance = m_atrBuffer[0] * m_atrSlMultiplier;
            out_tp_distance = m_atrBuffer[0] * m_atrTpMultiplier;
         }
         return SIGNAL_BUY;
      }
   }
   
   // Check Sell conditions
   // HTF Filter: Price must be below HTF EMA
   // RSI Filter: RSI rallied (between 40 and 70)
   if(close1 < htfEma1 && rsi1 > 40 && rsi1 < 70)
   {
      if(emaFast1 < emaSlow1 && high1 >= emaFast1 && close1 < open1)
      {
         if(m_useAtr)
         {
            out_sl_distance = m_atrBuffer[0] * m_atrSlMultiplier;
            out_tp_distance = m_atrBuffer[0] * m_atrTpMultiplier;
         }
         return SIGNAL_SELL;
      }
   }
   
   return SIGNAL_NONE;
}
//+------------------------------------------------------------------+
