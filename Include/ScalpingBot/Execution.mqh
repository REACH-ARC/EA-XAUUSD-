//+------------------------------------------------------------------+
//|                                                    Execution.mqh |
//|                                    Copyright 2024, Scalping Bot |
//+------------------------------------------------------------------+
#property copyright "Scalping Bot"
#property link      ""
#property version   "1.00"

#include <Trade\Trade.mqh>
#include "Logger.mqh"

class CExecution
{
private:
   CTrade            m_trade;
   CLogger*          m_logger;
   string            m_symbol;
   ulong             m_magic;
   int               m_maxRetries;

public:
                     CExecution();
                     ~CExecution();

   void              Init(string symbol, ulong magic, ENUM_ORDER_TYPE_FILLING filling, CLogger* logger);
   
   bool              OpenBuy(double volume, double sl_distance, double tp_distance, string comment="");
   bool              OpenSell(double volume, double sl_distance, double tp_distance, string comment="");
   void              CloseAllPositions();
   void              ManagePositions(double trailing_distance);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CExecution::CExecution() : m_maxRetries(3)
{
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CExecution::~CExecution()
{
}

//+------------------------------------------------------------------+
//| Initialize                                                       |
//+------------------------------------------------------------------+
void CExecution::Init(string symbol, ulong magic, ENUM_ORDER_TYPE_FILLING filling, CLogger* logger)
{
   m_symbol = symbol;
   m_magic = magic;
   m_logger = logger;

   m_trade.SetExpertMagicNumber(m_magic);
   m_trade.SetDeviationInPoints(5);
   m_trade.SetTypeFilling(filling);
   m_trade.LogLevel(LOG_LEVEL_ERRORS);
}

//+------------------------------------------------------------------+
//| Open Buy Position                                                |
//+------------------------------------------------------------------+
bool CExecution::OpenBuy(double volume, double sl_distance, double tp_distance, string comment="")
{
   for(int i = 0; i < m_maxRetries; i++)
   {
      double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      double sl_price = (sl_distance > 0) ? (ask - sl_distance) : 0;
      double tp_price = (tp_distance > 0) ? (ask + tp_distance) : 0;
      
      if(m_trade.Buy(volume, m_symbol, ask, sl_price, tp_price, comment))
      {
         m_logger.Info(StringFormat("Buy Opened: Vol=%.2f, Price=%.5f, SL=%.5f, TP=%.5f", volume, ask, sl_price, tp_price));
         return true;
      }
      else
      {
         m_logger.Warn(StringFormat("Buy failed (Attempt %d). Error: %d", i+1, m_trade.ResultRetcode()));
         Sleep(100);
      }
   }
   
   m_logger.Error(StringFormat("Buy failed after %d retries.", m_maxRetries));
   return false;
}

//+------------------------------------------------------------------+
//| Open Sell Position                                               |
//+------------------------------------------------------------------+
bool CExecution::OpenSell(double volume, double sl_distance, double tp_distance, string comment="")
{
   for(int i = 0; i < m_maxRetries; i++)
   {
      double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double sl_price = (sl_distance > 0) ? (bid + sl_distance) : 0;
      double tp_price = (tp_distance > 0) ? (bid - tp_distance) : 0;
      
      if(m_trade.Sell(volume, m_symbol, bid, sl_price, tp_price, comment))
      {
         m_logger.Info(StringFormat("Sell Opened: Vol=%.2f, Price=%.5f, SL=%.5f, TP=%.5f", volume, bid, sl_price, tp_price));
         return true;
      }
      else
      {
         m_logger.Warn(StringFormat("Sell failed (Attempt %d). Error: %d", i+1, m_trade.ResultRetcode()));
         Sleep(100);
      }
   }
   
   m_logger.Error(StringFormat("Sell failed after %d retries.", m_maxRetries));
   return false;
}

//+------------------------------------------------------------------+
//| Close All Positions                                              |
//+------------------------------------------------------------------+
void CExecution::CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetString(POSITION_SYMBOL) == m_symbol && PositionGetInteger(POSITION_MAGIC) == m_magic)
      {
         if(m_trade.PositionClose(ticket))
         {
            m_logger.Info(StringFormat("Position %I64u closed.", ticket));
         }
         else
         {
            m_logger.Error(StringFormat("Failed to close position %I64u. Error: %d", ticket, m_trade.ResultRetcode()));
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Manage Positions (Trailing Stop)                                 |
//+------------------------------------------------------------------+
void CExecution::ManagePositions(double trailing_distance)
{
   if(trailing_distance <= 0) return;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetString(POSITION_SYMBOL) == m_symbol && PositionGetInteger(POSITION_MAGIC) == m_magic)
      {
         long type = PositionGetInteger(POSITION_TYPE);
         double current_sl = PositionGetDouble(POSITION_SL);
         double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
         
         if(type == POSITION_TYPE_BUY)
         {
            double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
            if(bid - open_price > trailing_distance) // In profit by more than trailing distance
            {
               double new_sl = bid - trailing_distance;
               if(new_sl > current_sl + (SymbolInfoDouble(m_symbol, SYMBOL_POINT) * 10)) // Move SL up only
               {
                  if(!m_trade.PositionModify(ticket, new_sl, PositionGetDouble(POSITION_TP)))
                  {
                     m_logger.Warn(StringFormat("Failed to modify Buy SL for ticket %I64u", ticket));
                  }
               }
            }
         }
         else if(type == POSITION_TYPE_SELL)
         {
            double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
            if(open_price - ask > trailing_distance) // In profit by more than trailing distance
            {
               double new_sl = ask + trailing_distance;
               if(new_sl < current_sl - (SymbolInfoDouble(m_symbol, SYMBOL_POINT) * 10) || current_sl == 0) // Move SL down only
               {
                  if(!m_trade.PositionModify(ticket, new_sl, PositionGetDouble(POSITION_TP)))
                  {
                     m_logger.Warn(StringFormat("Failed to modify Sell SL for ticket %I64u", ticket));
                  }
               }
            }
         }
      }
   }
}
//+------------------------------------------------------------------+