# XAUUSD Scalping Bot (MQL5)

This is a native MetaTrader 5 Expert Advisor designed for scalping XAUUSD based on an EMA crossover and pullback strategy.

## Installation Instructions

1. Open MetaTrader 5.
2. Click on **File -> Open Data Folder**.
3. Copy the contents of the `Include` folder from this project into the `MQL5/Include/` directory of your MetaTrader data folder.
    * The path should look like: `MQL5/Include/ScalpingBot/` with the `.mqh` files inside.
4. Copy the contents of the `Experts` folder from this project into the `MQL5/Experts/` directory of your MetaTrader data folder.
    * The path should look like: `MQL5/Experts/ScalpingBot/ScalpingBot.mq5`.
5. Open MetaEditor (F4 in MetaTrader 5).
6. In the Navigator pane, find `Experts -> ScalpingBot -> ScalpingBot.mq5`.
7. Double click it to open, then click the **Compile** button at the top (or press F7).
8. Make sure there are no errors in the "Errors" tab at the bottom.

## Running the Bot

### Backtesting (Strategy Tester)
1. In MetaTrader 5, press `Ctrl + R` to open the Strategy Tester.
2. Select **Single** test.
3. Choose the Expert: `ScalpingBot\ScalpingBot.ex5`.
4. Symbol: `XAUUSD` (or your broker's equivalent, e.g., `XAUUSD.a`).
5. Timeframe: `M1` or `M5` is recommended for scalping.
6. Execution: Choose a delay (e.g., "Normal" or "Random") to simulate slippage.
7. Click the **Inputs** tab to adjust your risk and strategy parameters.
8. Click **Start**.

### Live / Demo Trading
1. In MetaTrader 5, make sure **Algo Trading** is enabled in the top toolbar.
2. In the Navigator pane (Ctrl + N), find `Expert Advisors -> ScalpingBot -> ScalpingBot`.
3. Drag and drop it onto your XAUUSD chart (M1 or M5).
4. A properties window will appear. Go to the "Common" tab and check "Allow Algo Trading".
5. Go to the "Inputs" tab to configure your risk per trade, stop loss, take profit, and trading hours.
6. Click OK. A green hat/icon should appear next to the EA name on the top right of the chart.

## Important Note
Always test the bot thoroughly on a Demo account before running it on a Live account. Market conditions, spread, and broker execution can heavily influence scalping strategies.
