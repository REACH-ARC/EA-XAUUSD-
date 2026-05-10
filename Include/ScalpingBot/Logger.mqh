//+------------------------------------------------------------------+
//|                                                       Logger.mqh |
//|                                    Copyright 2024, Scalping Bot |
//+------------------------------------------------------------------+
#property copyright "Scalping Bot"
#property link      ""
#property version   "1.00"

enum LOG_LEVEL {
   LOG_INFO,
   LOG_WARN,
   LOG_ERROR,
   LOG_DEBUG
};

class CLogger
{
private:
   LOG_LEVEL m_minLevel;
   string    LevelToString(LOG_LEVEL level);

public:
                     CLogger();
                     ~CLogger();
                     
   void              SetLevel(LOG_LEVEL level) { m_minLevel = level; }
   
   void              Info(string message);
   void              Warn(string message);
   void              Error(string message);
   void              Debug(string message);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CLogger::CLogger() : m_minLevel(LOG_INFO)
{
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CLogger::~CLogger()
{
}

//+------------------------------------------------------------------+
//| Convert level enum to string                                     |
//+------------------------------------------------------------------+
string CLogger::LevelToString(LOG_LEVEL level)
{
   switch(level)
   {
      case LOG_INFO: return "[INFO]";
      case LOG_WARN: return "[WARN]";
      case LOG_ERROR: return "[ERROR]";
      case LOG_DEBUG: return "[DEBUG]";
      default: return "[UNKNOWN]";
   }
}

//+------------------------------------------------------------------+
//| Log Info                                                         |
//+------------------------------------------------------------------+
void CLogger::Info(string message)
{
   if(m_minLevel >= LOG_INFO)
      PrintFormat("%s %s", LevelToString(LOG_INFO), message);
}

//+------------------------------------------------------------------+
//| Log Warning                                                      |
//+------------------------------------------------------------------+
void CLogger::Warn(string message)
{
   if(m_minLevel >= LOG_INFO) // Warnings always printed if info is enabled
      PrintFormat("%s %s", LevelToString(LOG_WARN), message);
}

//+------------------------------------------------------------------+
//| Log Error                                                        |
//+------------------------------------------------------------------+
void CLogger::Error(string message)
{
   PrintFormat("%s %s", LevelToString(LOG_ERROR), message); // Errors always printed
}

//+------------------------------------------------------------------+
//| Log Debug                                                        |
//+------------------------------------------------------------------+
void CLogger::Debug(string message)
{
   if(m_minLevel == LOG_DEBUG)
      PrintFormat("%s %s", LevelToString(LOG_DEBUG), message);
}
//+------------------------------------------------------------------+
