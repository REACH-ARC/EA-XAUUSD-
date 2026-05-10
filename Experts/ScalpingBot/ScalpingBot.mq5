//+------------------------------------------------------------------+
//|                                                  ScalpingBot.mq5 |
//|                                    Copyright 2024, Scalping Bot |
//|                                             https://example.com |
//+------------------------------------------------------------------+
#property copyright "Scalping Bot"
#property link      "https://example.com"
#property version   "1.00"

#include <ScalpingBot\Logger.mqh>
#include <ScalpingBot\Execution.mqh>
#include <ScalpingBot\RiskManager.mqh>
#include <ScalpingBot\Strategy.mqh>

//--- Input Parameters
input group "=== Strategy Parameters ==="
input int      InpEmaFast           = 20;       // Fast EMA Period
input int      InpEmaSlow           = 50;       // Slow EMA Period
input ENUM_TIMEFRAMES InpHtfTimeframe = PERIOD_M15; // Higher Timeframe (HTF)
input int      InpHtfEmaPeriod      = 200;      // HTF Trend EMA Period
input int      InpRsiPeriod         = 14;       // RSI Period
input int      InpMaxSpreadPoints   = 500;      // Max Spread (Points)
input int      InpStartHour         = 8;        // Trading Start Hour (Broker Time)
input int      InpEndHour           = 18;       // Trading End Hour (Broker Time)

input group "=== Risk Management ==="
input double   InpRiskPercent       = 1.0;      // Risk per Trade (%)
input double   InpDailyLossLimit    = 3.0;      // Daily Loss Limit (%)
input int      InpMaxConcurrent     = 1;        // Max Concurrent Trades
input double   InpMaxLotSize        = 0.10;     // Max Lot Size (0=unlimited, 0.01 for cent)
input bool     InpUseATR            = true;     // Use ATR for SL/TP?
input int      InpAtrPeriod         = 14;       // ATR Period
input double   InpAtrSlMultiplier   = 2.0;      // ATR Stop Loss Multiplier
input double   InpAtrTpMultiplier   = 4.0;      // ATR Take Profit Multiplier
input int      InpStopLossPips      = 30;       // Static SL Pips (if ATR false)
input int      InpTakeProfitPips    = 80;       // Static TP Pips (if ATR false)
input bool     InpUseTrailingStop   = true;     // Use Trailing Stop?
input int      InpTrailingStopPips  = 15;       // Trailing Stop Distance (Pips)

input group "=== Broker / Account Settings ==="
input ENUM_ORDER_TYPE_FILLING InpOrderFilling = ORDER_FILLING_RETURN; // Order Filling Mode

input group "=== System Settings ==="
input ulong    InpMagicNumber       = 1337;     // Magic Number
input LOG_LEVEL InpLogLevel    = LOG_INFO; // Log Level (0:Info, 3:Debug)

//--- Global Component Instances
CLogger      g_logger;
CExecution   g_execution;
CRiskManager g_riskManager;
CStrategy    g_strategy;

//--- State variables
datetime     g_lastCandleTime;
double       g_pointSize;
double       g_slPoints;
double       g_tpPoints;
double       g_trailingStopPoints;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Init Logger
   g_logger.SetLevel((LOG_LEVEL)InpLogLevel);
   g_logger.Info("Initializing Scalping Bot...");
   
   // Init Points conversion (1 pip = 10 points usually, but depends on broker)
   g_pointSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // If it's a 5-digit broker, 1 pip = 10 points
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double pipMultiplier = (digits == 3 || digits == 5) ? 10.0 : 1.0;
   
   g_slPoints = InpStopLossPips * pipMultiplier * g_pointSize;
   g_tpPoints = InpTakeProfitPips * pipMultiplier * g_pointSize;
   g_trailingStopPoints = InpTrailingStopPips * pipMultiplier * g_pointSize;
   
   // Init Execution
   g_execution.Init(_Symbol, InpMagicNumber, InpOrderFilling, &g_logger);

   // Init RiskManager
   g_riskManager.Init(_Symbol, InpMagicNumber, InpRiskPercent, InpDailyLossLimit, InpMaxConcurrent, InpMaxLotSize, &g_logger);
   
   // Init Strategy
   if(!g_strategy.Init(_Symbol, Period(), InpEmaFast, InpEmaSlow, InpMaxSpreadPoints, InpStartHour, InpEndHour, 
                       InpHtfTimeframe, InpHtfEmaPeriod, InpRsiPeriod, InpUseATR, InpAtrPeriod, InpAtrSlMultiplier, InpAtrTpMultiplier,
                       &g_logger))
   {
      g_logger.Error("Strategy initialization failed.");
      return(INIT_FAILED);
   }
   
   g_lastCandleTime = 0;
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   g_strategy.Deinit();
   g_logger.Info("Scalping Bot deinitialized.");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check Daily Balance update (at start of a new day)
   static int lastDay = -1;
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day != lastDay)
   {
      g_riskManager.UpdateDailyBalance();
      lastDay = dt.day;
      g_logger.Info("New trading day. Daily balance updated.");
   }
   
   // Check and manage Trailing Stops on every tick
   if(InpUseTrailingStop)
   {
      g_execution.ManagePositions(g_trailingStopPoints);
   }
   
   // Check if we have a new candle closed
   datetime currentCandleTime = iTime(_Symbol, Period(), 0);
   if(currentCandleTime == g_lastCandleTime)
   {
      // Still on the same candle, wait for close to evaluate entry
      return; 
   }
   
   // New candle detected
   g_lastCandleTime = currentCandleTime;
   
   // 1. Check Market Conditions
   if(!g_strategy.CheckMarketConditions())
   {
      return;
   }
   
   // 2. Check Risk Limits (Daily Loss, Concurrent trades)
   if(!g_riskManager.CanTrade())
   {
      return;
   }
   
   // 3. Evaluate Entry Logic
   double dynamicSL = 0;
   double dynamicTP = 0;
   SIGNAL_TYPE signal = g_strategy.EvaluateEntry(dynamicSL, dynamicTP, g_slPoints, g_tpPoints);
   
   // 4. Execute Trade
   if(signal == SIGNAL_BUY)
   {
      double lot = g_riskManager.CalculateLotSize(dynamicSL / g_pointSize);
      
      g_logger.Info(StringFormat("Buy Signal Detected. Attempting execution... SL Distance: %.5f", dynamicSL));
      g_execution.OpenBuy(lot, dynamicSL, dynamicTP, "Scalp Buy");
   }
   else if(signal == SIGNAL_SELL)
   {
      double lot = g_riskManager.CalculateLotSize(dynamicSL / g_pointSize);
      
      g_logger.Info(StringFormat("Sell Signal Detected. Attempting execution... SL Distance: %.5f", dynamicSL));
      g_execution.OpenSell(lot, dynamicSL, dynamicTP, "Scalp Sell");
   }
}
//+------------------------------------------------------------------+
