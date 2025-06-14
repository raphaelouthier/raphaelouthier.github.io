---
title: "Trading bot : high level view"
summary: "Top level overview"
series: ["Trading bot"]
series_order: 1
categories: ["Trading bot"]
#externalUrl: ""
showSummary: true
date: 2025-06-13
showTableOfContents : true
draft: true
---

## The full picture.

For the record and to illustrate before diving in, here is a full diagram of the trading bot and the entities it interacts with.

{{< figure
	src="images/bot/bot_full.png"
	caption="Full diagram of the trading bot."
	alt="tb full"
	>}}

At first glance, we can identify three main groups : 
- core components : those compents constitute the trading bot itself, and are all part of the same executable. Hence, they are all programmed in pure C and are ideally self-contained, as in they do not incorporate third party code. 
- remote providers and remote brokers : the services that provide data used as decision base, and that receive and process orders. The protocol that they use to communicate depends on the company that provides those services, and we cannot expect much standardization.
- connector components : those components bridge the gap between the trading bot which is simple and self contained by design, and the complex protocols that either remote provider or remote brokers require to communicate. They will likely use libraries provided by the providers or brokers, and hence, we cannot infer anything in the language that they use. We only need to standardize the way they communicate with the trading bot. In practice, connector components will be running in their own processes, and will communicate with the trading bot via either unix sockets or named pipes, using a simple packet-based protocol.


In reality, since most data providers support rest-ful APIs, the trading bot executable uses urllib in the provider interface to avoid the need of a provider connector for performance reason. The broker connector will be present though, as interacting with remote brokers is complex and is usually done via libraries provided by the brokers themselves. Also in this case, performance does not really matter.

Let's now take a look at the fundamental concepts behind this rather convoluted design.

## Strategies

The term strategy will be used to describe the process of looking in past/present data for a set of conditions to be met, and of making a set of investment decisions based on that fact.

Some simple examples are :
- statistical correlation between an instrument's current value and another's past value :
  - stock A gained 5% between one day ago and now, we buy stock B. If stock B gains more than 5%, or looses more than 1%, we sell, 
- arbitrary rule based on local variations of a single instrument :
  - stock A lost 5% of its value, we buy A. If it regains more than 3 ppts or looses 2 more ppts, we sell.  

We want the strategies ran by the bot to be :
- dynamic : act based on different strategies, have the ability to add a new strategy without rewriting the whole bot.
- backtestable : the quality of a strategy is determined by reality. Before adding a new strategy, it should be backtested to verify if it would have been profitable even in the recent past.
- adjustable : strategies may become more or less profitable with time. When trading based on a given strategy, we must verify its profitability and be able to stop using it if it becomes non/not-enough profitable. 

Internally, a strategy is characterized by three things : 
- a target instrument that it will buy or sell.
- a detector, which reads historical data from the past and present and detects certain conditions (ex : an increase of more than X% in a given stock price). Upon detection, it makes a prediction on the future return on investment that buying the target instrument now will generate.
- trading parameters, which upon detection, describe the process of buying the target instrument, and monitoring its price evolution in order to detect when it should be sold.

Detectors can vary a lot and do characterize the implemented strategy.

Trade sequences are very similar accross different strategy : they invest a certain amount of money in the target instrument, and wait for certain conditions to be met to sell them.

Trading parameters describe in which modalities the trading bot will buy and sell.
Since buying and selling is a rather critical part of the trading bot, it is accomplished by a dedicated library, the trade sequence lib, which will be described in a dedicated chapter.


## Resources and portfolio

The trading bot manipulates different resources, tracked by a library called the portfolio.

The first one and most obvious one is money, which comes into different currencies. The wallet (sub-lib of the portfolio) tracks every money depot available to the trading bot.

Then, there are instruments, like stocks, options, which can be traded. One could argue that currencies can also be traded, a totally acceptable nuance, that I'll happily ignore as my implementation is not targetting currency trading. But that would be a valid point and I have not given enough thought on how/if it would change the portfolio design.

It is likely that the broker offers us ways to query our trading account's resources list. Although, I made the choice of not relying on the broker's info, as I wanted to support multiple bots using the same brokerage account. In this case, there would be no way for bot A and B to know which resources of the brokerage account are allocated to each other. 

## Consistency, fault tolerance, and on-disk portfolio storage

Since the previous section argued in favor of each bot having its own portfolio and resource management, 

I made the choice of relying heavily on file system import and export to save the state of the poftfolio, while also ensuring fault tolerance.

Since order passing (whose intricacies with the portfolio are described below) is relatively rare in a system with a response period of one minute, it is acceptable to completely export the portfolio to disc before and after updating (passing, completing, cancelling) any order. This way (and with the export of the remaining trading bot components at the same time), if the bot faults for some reason, the previously exported (and valid) state of the portfolio can be used when restarting the trading bot, and the resource accounting system is not in danger.

Order passing, and resources usage.

One of the fundamental goals of the trading bot is to pass (profitable) orders to the broker.

The order passing logic must respect the resources available in the bot's portfolio, understand : we must not invest more money than we have, and we must not sell more instruments than we own.

A simple strategy (which makes accounting a bit harder for a bot with pending orders) is to just un-count any resource used to pass an order from the portfolio. Then, two things can happen : 
- if the order is cancelled (either by the bot but ultimately by the broker which confirms the canellation) then resources are re-added to the portfolio.
- if the order is (partially or fully) executed, then some resources are consumed (money in case of buying a stock), some are re-added to the portfolio (part of the money if not all of it was invedted) and some new resources are added (the bought stocks).

A consequence of this is that order descriptors (what we want to buy/sell, how much of it we want to buy/sell, for what price, how much we ended up buying/selling) must be very accurately tracked by the trading bot, in collaboration with the broker : when an order is complete, we need to query the broker so that the portfolio has all the info it needs to maintain its bookkeeping.

Otherwise, the portfolio would inaccurately track its resources which could lead to catastrophic scenarios like : 
- a bot using more money that what it was authorized to handle, which is troublesome if multiple bots use the same underlying trading account.
- a bot selling more stocks that what it bought, which is also a problem in the scenario above.

## Allocation

TODO

## Local provider, remote providers, simultaneous access :

The term "provider" will be used all along this series to describe both : 
- remote provider : the entity that provides the historical data (ex : polygonio).
- provider, or local provider : the block of the trading bot that :
  - queries the remote providers for historical data.
  - stores the downloaded data locally on disk.
  - reads this data from disk when decisions need to be made based on it. 

Remote providers like polygonio offer different prices for different historical ranges :
- if you pay the low price, they will only allow you to access historical data between (now - 15 minutes) and (now - 3 years). If you want real time data, you'll have to pay a much higher price.
- other providers (like your actual broker) may give you access to the most recent data but may not go as far in the past 

It is thus important to support multiple remote providers. When the local provider will need to download data in a time range, it will select a source that can provide this time range and download the data from it.

The backtesting capability of the trading bot will affect the design of the local provider. Indeed, if we want to take advantage of the full processing powerr of our processor, we will likely start multiple backtesting sessions in parallel (in different processes) for multiple strategies.

Each one of these processes will have its own local provider, and the question is then : does each local provider have its own storage ? Formulated differently : can multiple instances of the local provider share the same disk storage, or do they have to re-download the data from the remote providers ?

As the reader can guess, mandating each backtesting session to re-download everything would be dramatic for perf. To give you numbers : 
- backtesting a single strategy involving AAPL and NVDA over a 3 months period takes roughly 3 seconds.
- downloading this amount of data from polgonio takes 15 seconds, or 5 times more.

Not sharing the storage just doesn't fly.

Hence, we must design the local provider in a semi-clever way so that :
- multiple local provider instances can be spawned;
- and they share the same disk storage.
- they collaborate on the update of this disk storage.
- they do this as efficiently as possible.

The actual implementation of the local provider is surprisingly simple in term of number of lines, but has a high conceptual/nb_of_lines ratio. Many design choices will impact the overall perf, and this, the local provider implementation will be covered in a dedicated article.








## Local broker, remote broker, simulation broker.

We will use the words local and remote to qualify brokers the same way we did to qualify providers.

A remote brokers is the entity that our bot must reach out to to pass orders.

The local broker is the part of the bot that allows :
- passing new orders.
- getting the status of our orders in flight.
- cancelling orders.

There are two types of local brokers.
 
The live broker is the local broker that is used active trading : it forwards the order management requests to a remote broker (ie : crafting requests to and reading responses from the remote broker's servers, possibly using a library provided by the said broker).

Note that the broker does not get the portfolio's composition from the remote broker. Indeed, multiple bots may trade using the same brokerage account, and the proper global synchronization of those shared account resources is out of the scope of this project. What is expected is that the resources allocated to all portfolios (manually on portfolio creation or gained after successfull trafes) of all bots that use the same brokerage account will not exceed the total resources of the said brokerage account. This way, bots do not have to compete to use those resources.

The simulation broker is the local broker that is used for backtesting. Its goal is to simulate the execution of the order passing requests, using historical data.
It uses the data provider to query the price of an intrument target of an order at the (past) order passing time and reports the order complete at that price (or acts in a more evolved way based on the stop and limit prices of the order).
It inherently assumes that the orders that are passed by the bot have no effect on the effective prices, which as of last time I checked my bank account, sounds like a reasonable assumption for a bot using it.










 
