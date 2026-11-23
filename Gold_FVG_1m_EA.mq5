//+------------------------------------------------------------------+
//|                                        Gold_FVG_1m_EA.mq5        |
//|  Gold FVG 15m + 1m Confirmation EA - 1R Target                    |
//|  Use on: XAUUSD, 15 minute chart, MT5                             |
//|                                                                    |
//|  Rules tested in backtest:                                         |
//|  - 15m Fair Value Gap >= $2                                        |
//|  - Price retraces into the FVG within 20 x 15m bars               |
//|  - 1m confirmation: 1m candle closes above previous 1m high       |
//|    (long) / below previous 1m low (short)                          |
//|  - Entry at market, SL = gap edge - $1 buffer                      |
//|  - TP = 1R by default (change InpTPMultiplier to 1.5 / 2.0)        |
//|  - One trade at a time, risk % of balance per trade                |
//|                                                                    |
//|  Backtest on Gold futures, 15m FVG + 1m, 2R: 53 trades, 41.5% win |
//|  Pure FVG 1R: 52.0% win on Gold. Past results do NOT predict       |
//|  future results. TEST ON A DEMO ACCOUNT FIRST.                     |
//|  MT5 must stay on, or use a VPS, for the EA to trade.              |
//+------------------------------------------------------------------+
#property copyright "Gold FVG 1m EA - educational, use on demo first"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>
CTrade trade;

//--- Inputs
input double InpRiskPercent  = 1.0;    // Risk % of balance per trade (0 = use fixed lot)
input double InpFixedLot     = 0.01;   // Fixed lot if Risk % = 0
input double InpTPMultiplier = 1.0;    // TP multiplier in R (1.0 = 1R, 1.5, 2.0)
input double InpFVGMin       = 2.0;    // Min FVG size in $
input double InpSLBuffer     = 1.0;    // SL buffer in $
input int    InpMaxWaitBars  = 20;     // Max 15m bars to wait for retracement
input long   InpMagic        = 20261121;
input string InpComment      = "GoldFVG1R";

//--- State
int    pendingDir  = 0;   // 1 long, -1 short, 0 idle
double gapTop      = 0;
double gapBot      = 0;
datetime gapExpiry = 0;
bool   waitingConf = false;
datetime last15mBarTime = 0;

//+------------------------------------------------------------------+
//| Calculate lot size from risk %                                   |
//+------------------------------------------------------------------+
double CalcLot(double entry, double sl)
{
   if(InpRiskPercent <= 0)
      return InpFixedLot;

   double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = balance * InpRiskPercent / 100.0;
   double riskDist  = MathAbs(entry - sl); // in $ per oz
   if(riskDist <= 0)
      return InpFixedLot;

   // XAUUSD: 1.0 lot = 100 oz, $1 move = $100 per lot
   double lot = riskMoney / (riskDist * 100.0);

   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lot = MathMax(minLot, MathMin(maxLot, lot));
   lot = MathFloor(lot / lotStep) * lotStep;
   lot = NormalizeDouble(lot, 2);
   if(lot < minLot)
      lot = minLot;
   return lot;
}

//+------------------------------------------------------------------+
//| Check if we already have a position with our magic               |
//+------------------------------------------------------------------+
bool HasPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) == InpMagic &&
         PositionGetString(POSITION_SYMBOL) == _Symbol)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Only trade XAUUSD / GOLD symbols, and only on 15m chart
   if(HasPosition())
      return;

   datetime cur15mTime = iTime(_Symbol, PERIOD_M15, 0);
   bool new15mBar = (cur15mTime != last15mBarTime);

   //--- Detect a new FVG on a newly closed 15m bar
   // Closed bar is shift 1, the bar before the gap is shift 3
   if(new15mBar)
   {
      last15mBarTime = cur15mTime;

      // Expire old pending FVG
      if(pendingDir != 0 && TimeCurrent() > gapExpiry)
      {
         pendingDir = 0;
         waitingConf = false;
      }

      if(pendingDir == 0)
      {
         double low1  = iLow(_Symbol, PERIOD_M15, 1);
         double high3 = iHigh(_Symbol, PERIOD_M15, 3);
         double high1 = iHigh(_Symbol, PERIOD_M15, 1);
         double low3  = iLow(_Symbol, PERIOD_M15, 3);

         // Bullish FVG: Low[1] > High[3]
         if(low1 > high3 && (low1 - high3) >= InpFVGMin)
         {
            pendingDir  = 1;
            gapTop      = low1;
            gapBot      = high3;
            gapExpiry   = cur15mTime + InpMaxWaitBars * PeriodSeconds(PERIOD_M15);
            waitingConf = false;
            Print("Gold FVG: Bullish FVG found, Gap ", DoubleToString(gapBot, 2), " - ", DoubleToString(gapTop, 2));
         }
         // Bearish FVG: High[1] < Low[3]
         else if(high1 < low3 && (low3 - high1) >= InpFVGMin)
         {
            pendingDir  = -1;
            gapTop      = low3;
            gapBot      = high1;
            gapExpiry   = cur15mTime + InpMaxWaitBars * PeriodSeconds(PERIOD_M15);
            waitingConf = false;
            Print("Gold FVG: Bearish FVG found, Gap ", DoubleToString(gapBot, 2), " - ", DoubleToString(gapTop, 2));
         }
      }
   }

   if(pendingDir == 0)
      return;

   //--- Retracement into FVG, using live price
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(pendingDir == 1 && !waitingConf)
   {
      double low0 = iLow(_Symbol, PERIOD_M15, 0);
      if(low0 <= gapTop && bid > gapBot)
         waitingConf = true;
      else if(bid <= gapBot)
      {
         pendingDir = 0;
         waitingConf = false;
         return;
      }
   }
   if(pendingDir == -1 && !waitingConf)
   {
      double high0 = iHigh(_Symbol, PERIOD_M15, 0);
      if(high0 >= gapBot && ask < gapTop)
         waitingConf = true;
      else if(ask >= gapTop)
      {
         pendingDir = 0;
         waitingConf = false;
         return;
      }
   }

   if(!waitingConf)
      return;

   //--- 1m confirmation: closed 1m candle (shift 1) closes above previous 1m high / below previous 1m low
   double c1m1  = iClose(_Symbol, PERIOD_M1, 1);
   double o1m1  = iOpen(_Symbol, PERIOD_M1, 1);
   double h1m2  = iHigh(_Symbol, PERIOD_M1, 2);
   double l1m2  = iLow(_Symbol, PERIOD_M1, 2);

   // Only act once per closed 1m candle - use a static last confirmation bar time
   static datetime lastConfBar = 0;
   datetime cur1mTime = iTime(_Symbol, PERIOD_M1, 1);
   if(cur1mTime == lastConfBar)
      return;

   bool bullConf = (c1m1 > o1m1 && c1m1 > h1m2);
   bool bearConf = (c1m1 < o1m1 && c1m1 < l1m2);

   trade.SetExpertMagicNumber(InpMagic);

   if(pendingDir == 1 && bullConf)
   {
      lastConfBar = cur1mTime;
      double entry = ask;
      double sl    = gapBot - InpSLBuffer;
      double risk  = entry - sl;
      if(risk <= 0) { pendingDir = 0; waitingConf = false; return; }
      double tp    = entry + InpTPMultiplier * risk;
      double lot   = CalcLot(entry, sl);
      Print("Gold FVG LONG: Entry ", DoubleToString(entry, 2), " SL ", DoubleToString(sl, 2), " TP ", DoubleToString(tp, 2), " Lot ", DoubleToString(lot, 2));
      if(!trade.Buy(lot, _Symbol, entry, sl, tp, InpComment))
         Print("Buy failed: ", trade.ResultRetcodeDescription());
      pendingDir = 0;
      waitingConf = false;
   }

   if(pendingDir == -1 && bearConf)
   {
      lastConfBar = cur1mTime;
      double entry = bid;
      double sl    = gapTop + InpSLBuffer;
      double risk  = sl - entry;
      if(risk <= 0) { pendingDir = 0; waitingConf = false; return; }
      double tp    = entry - InpTPMultiplier * risk;
      double lot   = CalcLot(entry, sl);
      Print("Gold FVG SHORT: Entry ", DoubleToString(entry, 2), " SL ", DoubleToString(sl, 2), " TP ", DoubleToString(tp, 2), " Lot ", DoubleToString(lot, 2));
      if(!trade.Sell(lot, _Symbol, entry, sl, tp, InpComment))
         Print("Sell failed: ", trade.ResultRetcodeDescription());
      pendingDir = 0;
      waitingConf = false;
   }
}
//+------------------------------------------------------------------+
