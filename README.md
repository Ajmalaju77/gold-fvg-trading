# Gold FVG Trading — 15m Fair Value Gap + 1m Confirmation

Gold (XAUUSD) trading strategy built on the Fair Value Gap model with a 1-minute confirmation.

## Strategy rules

- **Instrument:** Gold / XAUUSD, 15m chart
- **Fair Value Gap:** $2+ gap on the 15m chart
- **Retracement:** price trades back into the gap within 20 x 15m bars
- **Confirmation:** 1m candle closes above the previous 1m high (long) / below the previous 1m low (short)
- **Entry:** at that 1m close
- **Stop loss:** gap edge − $1
- **Take profit:** 1R by default (changeable to 1.5R / 2R)
- **Risk:** 1% per trade, one trade at a time

## Files

- `gold-fvg-1m-confirmation.pine` — TradingView Pine Script v5 indicator
- `Gold_FVG_1m_EA.mq5` — MetaTrader 5 Expert Advisor (same rules, 1% risk)

## How to use

**TradingView:** open Pine Editor, paste the `.pine` file, Add to chart on XAUUSD 15m.

**MT5 (laptop only — phone MT5 cannot run EAs):** copy `Gold_FVG_1m_EA.mq5` to MQL5 > Experts, compile in MetaEditor (F7), drag it onto an XAUUSD 15m chart, enable Algo Trading.

## Backtest (GC=F, Yahoo Finance)

FVG + 1m confirmation, TP 1R, 26 Oct – 23 Nov 2026: 99 trades, 55.6% win, +14.58R total, profit factor 1.35.

Pure FVG (15m only), TP 1R, 15 Sep – 23 Nov 2026: 222 trades, 51.4% win, +6.00R total.

Past backtest results do not predict future results. Run on a demo account first for 2–4 weeks before any live trading.

## Author

Ajmal K — SOC / Cybersecurity Analyst, Kerala, India
