
---
title: "Trading bot : trade sequence."
summary: "How the trading bot trades."
series: ["Trading bot"]
series_order: 3
categories: ["Trading bot"]
#externalUrl: ""
showSummary: true
date: 2025-07-19
showTableOfContents : true
---
s chapter elaborates on how the algorithm that passes orders given the prediction made by a strategy.

It will also serve as an opportunity to show the backtesting in action.

The implemented algorithm specializes in trading securities in a simple way, it buys a security, then attempts to sell it at a higher price.

While this appears simple, there are subtleties to understand and precautions to take when doing such a simple task.

Trading more complex instruments, or trading securities using different techniques would undoubtedly involve more complex trade sequences, but the constraints and objectives of this simple model would still apply.

## Abstract objectives

The trade sequence is the code block that given :
- an instrument;
- a prediction on the future price of this instrument made by a strategy;
- a given amount of money in the instrument's trading currency, determined by the allocator;
creates and manages orders to extract a profit from the prediction.

Its order management algorithm must be precise and bug-free, as it must avoid at all costs :
- using more money than allowed by the allocator which would put the portfolio in money deficit.
- selling more units of the target instruments than the amount that it has previously bought which would put the portfolio in asset deficit.
- loosing track of orders, which would make resources vanish from the portfolio.

The last part has a subtlety implied by my design choices.

A look at the trading bot's high level diagram will show that the trade sequence is the bot's only entity that manages orders.

An implication of this is that if we aim at deleting a trade sequence, we must ensure that all its orders are eiter complete or cancelled.

The trading bot is regularly exported to allow fail safety, and stopping it does not cause a trade sequence deletion. It just means that when restarting the bot again, the trade sequence will be resumed, accounting for the same orders as before stopping teh bot.

## Trade scenarios

The base algorithm of the trade sequence will be divided into three phases :
- buying : buy a certain number of units of the target instrument;
- monitoring : wait for the target price to be reached;
- selling : sell the bought units;

This is very simple in theory, but there are subtleties that add to it.

Buying constraints :
- buying can take time, and we do not want to buy if the price is already too high. Remember that we are low latency after all.
- buying can take time and we do not want to buy after a certain time past the prediction. The prediction may be incorrect after all.
- the prediction implies a future price increase, but if the price goes down, we may want to consider it unreliable and not buy.
- the buy order may not be completely executed, and we may end up with less units than expected.

Monitoring constraints :
- the prediction may be incorrect and the target price could not be reached in time. We must not wait indefinitely and just sell after some time.
- the prediction may be incorrect and the price may decrease after buying. We must set a stop loss price and sell if it is reached.

Selling is a critical part of the trade sequence as it is necessary for the trade sequence to be deletable. Hence, it should be as flexible as possible, and in practice, has no constraints. We just buy as many units as we have, with a market sell order.

## FSM

With the constraints listed so far, we can come up with a simple algorithm which behaves like an FSM.

It receives the following parameters :
- `mny` : the amount of money to invest.
- `prc_buy` : the maximal buy price.
- `prc_tgt` : the target sell price.
- `prc_stp` : the minimal stop price.
- `buy_tim` : the maximal time allowed to buy.
- `mon_tim` : the maximal time allowed to monitor.

Its states are :
- BUY : a single buy order for `mny` has been issued and we are waiting for its completion.
  - If the order completes without cancellation, move to MON.
  - If the current price becomes lower than `prc_stp`, or if `buy_tim` is ellapsed, cancel it and move to SEL, as the buy order may have been partially executed.
- MON : the buy order has been executed and we are monitoring the current price.
  - If the price goes above `prc_tgt`, move to SEL (or to `TRG` if implemented, see the Improvements section below).
  - If the price goes below `prc_stp`, or if `mon_tim` is ellapsed, move to SEL.
- SEL : the buy order has been executed, and the sell market order has been issued.
  - If the sell order has been partially executed, re-issue one covering the remaining units.
  - If the sell order has been completely executed, move to DON.
- DON : all orders have been completed, ready for deletion.

## Improvements

This section covers potential improvements to the trade sequence to increase profits or predictability.

Note that even those mechanisms may seem interesting per-se, they may not provide any benefit _without_ _a_ _valid_ _prediction_.

They provide a benefit only because (shoudl I say : `if`) the prediction itself has valid information. They do not provide information per-se. They `could` simply allow us to get closer to the predicted return by handling more corner cases in the market's behavior.

Their use and characteristics should be subject to backtesting, as they may be profitable or not based on the market conditions.

### 1 : Sell only when the price decreases

That will allow us to take advantage of a rising market.

The strategy's predictor only makes a prediction on the return between `now` and `now` + `some time`. It says nothing about what happens next, and if the price keeps going up, there is no reason for us to sell early.

To implement this, we need to establish a price drop percentage after which we sell.

### 2 : divide the buy stage in multiple steps

If the target instrument is volatile, it may be a good idea to not buy all units at the same time. In average this will not matter as we will have multiple trade sequences, which should average the volatility with time, but by handling this at the buy stage, we avoid propagating the volatility to the trade sequences performances, and be more predictable which matters to us.

### 3 : add a TRG step between MON and SEL

If the target price has been reached, we try selling using a limit sell order for some time. If we could not sell all after this time, we enter the SEL stage and sell everything with a market order.

It allows us to only be affected by the positive side of volatility : if price temporarily goes down, we will not sell. If it goes up, we will sell at a better price.

The counterpart of this is that if the prices goes down in a non-temporary manner, we will sell too late and at a potentially lesser price.


## Visual logs

For my testing I generated a lot of simulations to both test the bot's correctness and its ability to correctly (or not) take advantage of a prediction.

From the bot's logs, some nice graphs can be generated, to visually ensure that the bot's trade sequence does the right thing.

The python script that I wrote to generate the visual reports can be found [here](https://github.com/Briztal/kr_public/blob/master/bot_rep.py) and uses the `rep` package proviced [here](https://github.com/Briztal/kr_public/blob/master/rep/) :
- [cmd](https://github.com/Briztal/kr_public/blob/master/rep/cmd.py) : parsing utilities.
- [rep](https://github.com/Briztal/kr_public/blob/master/rep/rep.py) : reprot python structures.
- [prs](https://github.com/Briztal/kr_public/blob/master/rep/prs.py) : log parsing.
- [plt](https://github.com/Briztal/kr_public/blob/master/rep/plt.py) : plotting core.

Given a backtesting log produced by the trading bot, it will generate :
- one summary picture of the bot's top level behavior.
- for each trade sequence, a summary picture of the decisions of the trade sequence.

The examples found in this section are accompanied by archives containing :
- the backtesting logs.
- the visual reports generated from the backtesting logs.

In order to re-generate those visual reports from the logs, run :
```
bot_rep.py prs <log> <tmp> && bot_rep.py exp <tmp> <report_path> -r -s
```
with :
- `log` : the log file.
- `tmp` : the path for the temporary parsed log blob (used by the tool internally).
- `rep` : the path to generate visual reports at. If you provide `/tmp/pict` it will generate `/tmp/pict_main.svg` for the toplevel view and `/tmp/pict_seq_<N>.svg` for each sequence.

### Self backtesting : aapl_aapl_1d

A good way to test that the bot works is to have it backtest a symbol against a future version of itself : predicting the behavior of AAPL in one day knowing AAPL in one day is very reliable. If our bot mispredicts anything here, then it has a bug.

The backtesting report showed here was generated backtesting a single strategy predicting AAPL's next day behavior based on AAPL's next day values, from Jan 1st 2024 to March 1st 2024.

First, let's take a look at the high level report.

{{< figure
    src="images/bot/aapl_aapl_1d_main.svg"
    caption="Self backtesting top level."
    alt="self bkt top"
>}}

All graphs have the time as abscissa and various data in ordinate.

The first graph on top shows the two curves that the predictor operates on. We see two versions of the same curve, translated of a day, which aligns with what we expect.

The second graph in the middle shows :
- bottom curve : the number of AAPL stocks that the bot owns with time.
- top curve : the amount of money ($) owned by the bot not involved in orders.

The third graph on the bottom plots the two curves again, and adds a horizontal line covering the duration of each trade sequence. The line is green if the trade sequence was successfull (target price reached) or red if it was failed (target price not reached).
The ordinate of the trade sequence lines has no particular meaning apart from indicating the sequence creation order.
In this case, all sequences were successful.

Now, let's take a look at what trade sequence 25 did as an example.

{{< figure
    src="images/bot/aapl_aapl_1d_seq_25.svg"
    caption="Self backtesting trade sequence example."
    alt="self bkt seq"
>}}

In abscissa, compacted in a totally unreadable way thanks to mathplotlib (<3) we have the time base expressed in `mid`.
Just above the time axis, there is a colored timeline where :
- the grey part represents the time before the trade sequence's creation. Our trading bot being relatively causal, all data used by the predictor should be in this area.
- the green part represents the time window where buying is allowed.
- the blue part represents the time window where monitoring is allowed.
- the red part represents the time window where monitoring is not allowed anymore and assets should be sold. It occupies all the time range after the monitoring range.

In ordinate, we have the prices, and the two curves that are drawn are :
- on the left, the curve used by the strategy to make its prediction, here it is AAPL+1d.
- on the right, the curve used by the trade sequence to pass and monitor orders, here it is AAPL.

Again, we can see that the two curves are identical modulus a translation.

The two red dots connected by a line are the two prices used by the strategy's predictor to make its prediction. The bot's behavior being correct, they coincide with the predictor's curve. If there was a bug in the predictor (read at the wrong time), they would differ.

The two blue dots represent :
- on the left : the price at which we bought our assets.
- on the right : the price at which we sold our assets.

Again, since the bot's behavior is correct, those dots belong to the curve used by the trade sequence.

There are also a set of indicator lines.

The horizontal lines represent :
- bottom black line : price at sequence construction.
- middle blue line : limit price for buying.
- top green line : target price for selling.

The vertical lines represent :
- left green line : buy time.
- right blue line : sell time.


### No correlation : predict NVDA based on AAPL

{{< figure

    src="images/bot/aapl_nvda_main.svg"
    caption="Backtesting a strategy correlating non-correlated curves."
    alt="non cor top"
>}}

What we see here is interesting : we ended up with a positive return on investment because the target instrument (NVDA) had a price increase in the backtesting period (it doubled in value).

We can hence see that even with faulty info, we can end up with a positive return just because our target was steadily increasing.

As we can see, regardless of when AAPL gained in value, the resulting trading sequence (trading NVDA) was able to consistently meet its target price, because NVDA was coincidentally increasing in price.

Let's see a case where it is not that simple : the inverse prediction.

### When it goes _bang_ : predict AAPL based on NVDA

{{< figure

    src="images/bot/nvda_aapl_main.svg"
    caption="Backtesting a strategy correlating non-correlated curves, predicting one that did not steadily gain value."
    alt="non cor top"
>}}

This time we see something totally different : AAPL did not steadily gain in price during the backtesting time, so the sudden price increases in NVDA had no particular reason to be related to sudden AAPL price increases.

All trade sequences except a couple of lucky one were unsuccessfull, and We even ended up loosing some money.

## Conclusion.

This article finishes my series on the trading bot.

As I had stated in the introduction, the objective of this series was to describe the structure of my implementation, elaborate on the design choices, and show a couple of interesting problems, which I hope to have achieved.

As those last sections described, printing money is not easy, and the real value of the trading bot is its ability to make the best use of reliable predictions.

Establishing those predictions is a complete separate topic, on which I did not spend time yet and which I will probably not do so soon, as I am currently moving on to other projects.

I hope you had a pleasant reading.

This chapter elaborates on how the algorithm that passes orders given the prediction made by a strategy.

It will also serve as an opportunity to show the backtesting feature in action.

The implemented algorithm specializes in trading securities in a simple way, it buys a security, then attempts to sell it at a higher price.

While this appears simple, there are subtleties to understand and precautions to take when doing such a simple task.

Trading more complex instruments, or trading securities using different techniques would undoubtedly involve more complex trade sequences, but the constraints and objectives of this simple model would still apply.

## Abstract objectives

The trade sequence is the code block that given :
- an instrument;
- a prediction on the future price of this instrument made by a strategy;
- a given amount of money in the instrument's trading currency, determined by the allocator;
creates and manages orders to extract a profit from the prediction.

Its order management algorithm must be precise and bug-free, as it must avoid at all costs :
- using more money than allowed by the allocator which would put the portfolio in a money deficit.
- selling more units of the target instruments than the amount that it has previously bought which would put the portfolio in an asset deficit.
- losing track of orders, which would make resources vanish from the portfolio.

The last part has a subtlety implied by my design choices.

A look at the trading bot's high level diagram will show that the trade sequence is the bot's only entity that manages orders.

An implication of this is that if we aim at deleting a trade sequence, we must ensure that all its orders are either complete or cancelled.

The trading bot is regularly exported to allow fail safety, and stopping it does not cause a trade sequence deletion. It just means that when restarting the bot again, the trade sequence will be resumed, accounting for the same orders as before stopping the bot.

## Trade scenarios

The base algorithm of the trade sequence will be divided into three phases :
- buying : buy a certain number of units of the target instrument;
- monitoring : wait for the target price to be reached;
- selling : sell the bought units;

This is very simple in theory, but there are subtleties that add to it.

Buying constraints :
- Buying can take time, and we do not want to buy if the price is already too high. Remember that we are low latency after all.
- buying can take time and we do not want to buy after a certain time past the prediction. The prediction may be incorrect after all.
- the prediction implies a future price increase, but if the price goes down, we may want to consider it unreliable and not buy.
- the buy order may not be completely executed, and we may end up with less units than expected.

Monitoring constraints :
- the prediction may be incorrect and the target price could not be reached in time. We must not wait indefinitely and just sell after some time.
- the prediction may be incorrect and the price may decrease after buying. We must set a stop loss price and sell if it is reached.

Selling is a critical part of the trade sequence as it is necessary for the trade sequence to be deletable. Hence, it should be as flexible as possible, and in practice, has no constraints. We just buy as many units as we have, with a market sell order.

## FSM

With the constraints listed so far, we can come up with a simple algorithm which behaves like an FSM.

It receives the following parameters :
- `mny` : the amount of money to invest.
- `prc_buy` : the maximal buy price.
- `prc_tgt` : the target sell price.
- `prc_stp` : the minimal stop price.
- `buy_tim` : the maximum time allowed to buy.
- `mon_tim` : the maximum time allowed to monitor.

Its states are :
- BUY : a single buy order for `mny` has been issued and we are waiting for its completion.
  - If the order completes without cancellation, move to MON.
  - If the current price becomes lower than `prc_stp`, or if `buy_tim` has elapsed, cancel it and move to SEL, as the buy order may have been partially executed.
- MON : the buy order has been executed and we are monitoring the current price.
  - If the price goes above `prc_tgt`, move to SEL (or to `TRG` if implemented, see the Improvements section below).
  - If the price goes below `prc_stp`, or if `mon_tim` has elapsed, move to SEL.
- SEL : the buy order has been executed, and the sell market order has been issued.
  - If the sell order has been partially executed, re-issue one covering the remaining units.
  - If the sell order has been completely executed, move to DON.
- DON : all orders have been completed, ready for deletion.

## Improvements

This section covers potential improvements to the trade sequence to increase profits or predictability.

Note that even those mechanisms may seem interesting per-se, they may not provide any benefit _without_ _a_ _valid_ _prediction_.

They provide a benefit only because (should I say : `if`) the prediction itself has valid information. They do not provide information per-se. They `could` simply allow us to get closer to the predicted return by handling more corner cases in the market's behavior.

Their use and characteristics should be subject to backtesting, as they may be profitable or not based on the market conditions.

### 1 : Sell only when the price decreases

That will allow us to take advantage of a rising market.

The strategy's predictor only makes a prediction on the return between `now` and `now` + `some time`. It says nothing about what happens next, and if the price keeps going up, there is no reason for us to sell early.

To implement this, we need to establish a price drop percentage after which we sell.

### 2 : divide the buy stage in multiple steps

If the target instrument is volatile, it may be a good idea to not buy all units at the same time. On average this will not matter as we will have multiple trade sequences, which should average the volatility with time, but by handling this at the buy stage, we avoid propagating the volatility to the trade sequences performances, and be more predictable which matters to us.

### 3 : add a TRG step between MON and SEL

If the target price has been reached, we try selling using a limit sell order for some time. If we could not sell all after this time, we enter the SEL stage and sell everything with a market order.

It allows us to only be affected by the positive side of volatility : if price temporarily goes down, we will not sell. If it goes up, we will sell at a better price.

The counterpart of this is that if the prices go down in a non-temporary manner, we will sell too late and at a potentially lesser price.


## Visual logs

For my testing I generated a lot of simulations to both test the bot's correctness and its ability to correctly (or not) take advantage of a prediction.

From the bot's logs, some nice graphs can be generated, to visually ensure that the bot's trade sequence does the right thing.

The python script that I wrote to generate the visual reports can be found [here](https://github.com/Briztal/kr_public/blob/master/bot_rep.py) and uses the `rep` package proviced [here](https://github.com/Briztal/kr_public/blob/master/rep/) :
- [cmd](https://github.com/Briztal/kr_public/blob/master/rep/cmd.py) : parsing utilities.
- [rep](https://github.com/Briztal/kr_public/blob/master/rep/rep.py) : report python structures.
- [prs](https://github.com/Briztal/kr_public/blob/master/rep/prs.py) : log parsing.
- [plt](https://github.com/Briztal/kr_public/blob/master/rep/plt.py) : plotting core.

Given a backtesting log produced by the trading bot, it will generate :
- one summary picture of the bot's top level behavior.
- for each trade sequence, a summary picture of the decisions of the trade sequence.

The examples found in this section are accompanied by archives containing :
- the backtesting logs.
- the visual reports generated from the backtesting logs.

In order to re-generate those visual reports from the logs, run :
```
bot_rep.py prs <log> <tmp> && bot_rep.py exp <tmp> <report_path> -r -s
```
with :
- `log` : the log file.
- `tmp` : the path for the temporary parsed log blob (used by the tool internally).
- `rep` : the path to generate visual reports at. If you provide `/tmp/pict` it will generate `/tmp/pict_main.svg` for the toplevel view and `/tmp/pict_seq_<N>.svg` for each sequence.

### Self backtesting : aapl_aapl_1d

A good way to test that the bot works is to have it backtest a symbol against a future version of itself : predicting the behavior of AAPL in one day knowing AAPL in one day is very reliable. If our bot mispredicts anything here, then it has a bug.

The backtesting report shown here was generated by backtesting a single strategy predicting AAPL's next day behavior based on AAPL's next day values, from Jan 1st 2024 to March 1st 2024.

First, let's take a look at the high level report.

{{< figure
    src="images/bot/aapl_aapl_1d_main.svg"
    caption="Self backtesting top level."
    alt="self bkt top"
>}}

All graphs have the time as abscissa and various data in ordinate.

The first graph on top shows the two curves that the predictor operates on. We see two versions of the same curve, translated of a day, which aligns with what we expect.

The second graph in the middle shows :
- bottom curve : the number of AAPL stocks that the bot owns with time.
- top curve : the amount of money ($) owned by the bot not involved in orders.

The third graph on the bottom plots the two curves again, and adds a horizontal line covering the duration of each trade sequence. The line is green if the trade sequence was successful (target price reached) or red if it was failed (target price not reached).
The ordinate of the trade sequence lines has no particular meaning apart from indicating the sequence creation order.
In this case, all sequences were successful.

Now, let's take a look at what trade sequence 25 did as an example.

{{< figure
    src="images/bot/aapl_aapl_1d_seq_25.svg"
    caption="Self backtesting trade sequence example."
    alt="self bkt seq"
>}}

In abscissa, compacted in a totally unreadable way thanks to matplotlib (<3) we have the time base expressed in `mid`.
Just above the time axis, there is a colored timeline where :
- the grey part represents the time before the trade sequence's creation. Our trading bot being relatively causal, all data used by the predictor should be in this area.
- the green part represents the time window where buying is allowed.
- the blue part represents the time window where monitoring is allowed.
- the red part represents the time window where monitoring is not allowed anymore and assets should be sold. It occupies all the time range after the monitoring range.

In ordinate, we have the prices, and the two curves that are drawn are :
- on the left, the curve used by the strategy to make its prediction, here it is AAPL+1d.
- on the right, the curve used by the trade sequence to pass and monitor orders, here it is AAPL.

Again, we can see that the two curves are identical modulus translation.

The two red dots connected by a line are the two prices used by the strategy's predictor to make its prediction. The bot's behavior being correct, they coincide with the predictor's curve. If there was a bug in the predictor (read at the wrong time), they would differ.

The two blue dots represent :
- on the left : the price at which we bought our assets.
- on the right : the price at which we sold our assets.

Again, since the bot's behavior is correct, those dots belong to the curve used by the trade sequence.

There are also a set of indicator lines.

The horizontal lines represent :
- bottom black line : price at sequence construction.
- middle blue line : limit price for buying.
- top green line : target price for selling.

The vertical lines represent :
- left green line : buy time.
- right blue line : sell time.


### No correlation : predict NVDA based on AAPL

{{< figure

    src="images/bot/aapl_nvda_main.svg"
    caption="Backtesting a strategy correlating non-correlated curves."
    alt="non cor top"
>}}

What we see here is interesting : we ended up with a positive return on investment because the target instrument (NVDA) had a price increase in the backtesting period (it doubled in value).

We can hence see that even with faulty info, we can end up with a positive return just because our target was steadily increasing.

As we can see, regardless of when AAPL gained in value, the resulting trading sequence (trading NVDA) was able to consistently meet its target price, because NVDA was coincidentally increasing in price.

Let's see a case where it is not that simple : the inverse prediction.

### When it goes _bang_ : predict AAPL based on NVDA

{{< figure

    src="images/bot/nvda_aapl_main.svg"
    caption="Backtesting a strategy correlating non-correlated curves, predicting one that did not steadily gain value."
    alt="non cor top"
>}}

This time we see something totally different : AAPL did not steadily gain in price during the backtesting time, so the sudden price increases in NVDA had no particular reason to be related to sudden AAPL price increases.

All trade sequences except a couple of lucky ones were unsuccessful, and we even ended up losing money.

## Conclusion.

This article finishes my series on the trading bot.

As I had stated in the introduction, the objective of this series was to describe the structure of my implementation, elaborate on the design choices, and show a couple of interesting problems, which I hope to have achieved.

As those last sections described, printing money is not easy, and the real value of the trading bot is its ability to make the best use of reliable predictions.

Establishing those predictions is a completely separate topic, on which I did not spend time yet and which I will probably not do so soon, as I am currently moving on to other projects.

I hope you had a pleasant reading.

