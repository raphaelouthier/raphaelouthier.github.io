---
title: "Trading bot : introduction"
summary: "Presentation"
series: ["Trading bot"]
series_order: 0
categories: ["Trading bot"]
#externalUrl: ""
showSummary: true
date: 2025-06-10
showTableOfContents : true
draft: true
---

This series of articles describe the structure of a low frequency trading bot supporting dynamic, adjustable and backtestable investment strategies, a project that I have been working on and off for three years in the hope that some day, I could just start it in the morning and watch it print money while I drink coffee. Or contemplate it burn all my savings in 10 minutes.💸

This chapter covers some necessary precautions, states the objectives of the trading bot, its limitations, the impact of these on the implementation, and defines what strategies are.

For a more technical description of the trading bot, please refer to part 1 of this series.
 
## Disclaimers

### Open-source

I am legally bound by my company ({{< icon "apple" >}}) to not publish open source code in any form.

Though, I am legally free to write about my personal projects.

This series of articles sometimes contains code snippets but the entire project source code will remain private.

### Sponsoring

Accross this article, I mention a few company names like polygonio and interactive brokers.

I just happen to be their client.

I have not been offered anything (money or reduction or any form of advantage) to mention those names.

For what it's worth, none from those companies even knows that this website exists.

### Languages

I am a kernel developper, and as such, I am proficient in using C.

It is not by disregard for other languages : I started programming with python as a teenager, then studied java in classes, wrote quite a lot of C++ with embedded (Arduino) development for personal projects, and then moved to C after I decided to stop using third party code and to just reimplement everything on bare metal.

C++ could have been a valid choice to implement my trading bot, but I generally try to stick with C when possible, as it is closer to the machine and hence, offers you more control, resulting in more performance when needed.

### Third party libraries in C code

One of my general rules is to reimplement everything I use when possible and relevant. That is to make my code as portable as possible, and to have the best understanding of what it does. You can assume that the entirety of the trading core (see the diagram below) implementation (including the basic design patterns like trees, maps, lists, many functions of the standard library like formatted print and decode, etc...) is made from scratch, with a few exceptions that are worth mentioning : 
- **OS interface layer** : to be able to use kernel-managed resources, eg : files, sockets.
- **curl** : data providers like polygonio provide rest-ful APIs to query the actual data. This implies that you must either use libraries like curl or re-code them yourself, which was definitely out of **this** project's scope. It kinda did hurt, but I installed libcurl...
- **broker APIs** : brokers like interactive brokers saw the automatic trading trend coming and created dedicated libraries to allow you to procedurally do brokerage-related actions like creating and managing orders, getting your portfolio's composition, etc... Those libraries are rather complex and re-implementing them in pure C would be too risky (order passing is sensitive !) and useless. In the broker chapter I will discuss the way to have a pure C self-contained code interact properly with those brokerage systems.    

## Introduction
 
First, let's state the limits and objectives of this project.

I am not a trader, I am an outsider to the financal world. As such, I recognise that the investment strategies I can come up with would be naive and of poor quality compared to industry standards. I am a kernel engineer, and that explains that the goal I was writing the trading bot.

A kernel is essentially a shared resource manager.
It coordinates the shared access to resources like CPU execution time, memory, storage, devices like networking cards, etc...
The fundamental problem of a kernel is : how do we manage these resources, in order to offer the most performant result ? "Performant" here can mean a lot of things : fastest, most energy-efficient, most secure, most fault-tolerant.
Those factors are sometimes antagonist : more secure often implies less performant, and vice versa.
Before providing an implementation, one must carefully study what their use case is, deduce their performance metric, and then, design how resources should be handled by the kernel based on those axioms.     

If we think about it, investment strategies essentially do two things : consume historical data steamed by data providers, and produce trading decisions consumed by the broker.
It is the role of the trading bot to allow the strategies to do this in a performant manner.
Historical data is a shared computational resource, to which strategies must have a very fast access to. The performance metric here is the access speed.
Trading decisions are rarely made, and involve money and instruments, which must be managed with care. The performance metric here is the fault tolerance.

The same way a kernel aims to provide performant access to shared resources, my objective when writing this trading bot was to design a system which allows the easy implementation of complex strategies and that lets them access historical data and manage orders in a performant way.

But enough with the warnings, let's get started.

## Fundamental objectives.

First let's state the very basic objectives of our trading bot.

Base objectives :
- **observe** the variations of different instruments in real time.
- **trade** based on those variations in the least money-loosing way.

## Strategies

The term strategy is used to describe the process of looking in past/present data to identify when a set of conditions are met, and when this occurs, make  a set of investment decisions.

Some simple examples are :
- statistical correlation between an instrument's current value and another instrument's past value :
  - stock NVDA gained 5% between one day ago and now, we buy AMZN stock . If AMZN gains more than 5%, or looses more than 1%, we sell. 
- arbitrary rule based on local variations of a single instrument :
  - stock NVDA lost 5% of its value, we buy NVDA. If it regains more than 3 ppts or looses 2 more ppts, we sell.  

Those simple examples show that strategies can be designed as generic algorighms that receive parameters
which condition their behavior. The first example can be summarized as :  
{{< katex >}}
> "detect a price increase of stock 
\\(A\\) of at least \\(x\\)% between time \\('now-d'\\) and \\('now'\\), and when it is the case, buy stock \\(B\\). 
Then, if it looses more than \\(m\\), or takes more than \\(M\\)%, sell." 

with parameters :\
\\((x=5, d=one day, m=1, M=5, A=NVDA, B=AMZN)\\)

This implies that there is an infinite number of potential strategies, and that one of our goals is to find the best strategies to use. 

Luckily for us (and this is actually rare in my domain) the performance criterion here is very straighforward : return on investment, aka: how much did we make. 

But we still have to choose a finite number of strategies among an infinite set.
This requires us to explore the space of possible strategies, and backtest a few chosen ones. By backtesting, I mean simulating the behavior of those strategies in the recent past to determine what their return on investment would have been.

From what we covered until now, we can deduce a high level view of what the trading system looks like. 

## Fundamental components

{{< figure
	src="images/bot/bot_hgh_lvl.svg"
	caption="Full diagram of the trading bot."
	alt="tb full"
	>}}

### External entities

First, we have two types of external entities, on the bottom : 
- **data providers** : provide historical data that our bot bases its decisions on. There can be many.
- the **broker** : allows the bot to pass order creation and management requests in real time. There can only be one.

### Trading core

Then, going up, we see the trading core. It is composed of a single executable, coded in pure C, it consitutes the central piece of the trading bot : it is the one that supervises the execution of our strategies, and that allows them to access historical data and manage orders in the most simple and performant way.

The trading core supports two different execution modes : 
- **trading mode** : runs strategies in real-time using present data, and forwards their order management requests to the real broker, in order to generate actual profits.
- **simulation (backtesting) mode** : runs strategies using past data, and simulates the order management requests, in order to determine if those strategies would have been profitable in the past.

The strategies ran by the trading core in trading mode need to be configurable, hence, it uses eithe named pipes or unix sockets to receive configuration requests from the agent. 

### Database

Then, on the sides of the diagram, we have a database which contains two types of data : 
- mining data (see miner below) : base data used by the miner to search for strategies.
- agent config (see agent below) : describes the strategies that should currently be ran by the agent's real time trading core. Updated by the miner, and read by the agent.

### Agent

At the center of the diagram on the right, we see the agent, which has two responsibilities : 
- supervising the execution of the trading core (as a subprocess) configured in trading mode.
- periodically querying the agent config data of the database which is updated by the miner (see miner below) via SQL queries and updating the trading core's configuration to reflect this. 

Since it needs to access database data by perfroming SQL queries, it will be coded in python.

### Miner

In the center of the diagram, on the left, we see the miner, which has three roles :
- exploring the space of all possible strategies to find profitable ones.
- when it finds a profitable strategy, it adds these strategies to the agent config.
- it regularly backtests the strategies in the agent configs to verify that they are still profitable. If not, it removes them from the agent config.

Its job consists on selecting candidate strategies and starting backtesting sessions using subprocesses running the 
trading core in simulation mode to calculate their past return on investment. It has no real requirement for 
performance (as the computational work is done by the trading core), but it must efficiently explore 
the space of possible strategies, and avoid backtesting the same strategies twice. Thus : 
- it uses the database to store its backtesting state.
- it is coded in python to interact painlessly with the database.

### Controller 

Finally, at the top, we see the control system, which :
- oversees the execution of all the previously mentioned components (except the database which runs as a system service).
- allows admin controls to, eg: stop or start the agent, run custom backtesting sessions with admin-specified configs.

It is implemented in python and is accessible through a web browser (using flask).


## Limitations

### I am not a trading company

First, I am just an individual investor, running code from my computer (or a server) not directly connected to any exchange.


This has the following implications :
1. real time orderbook feed will not be available. We must use an aggregated data feed, which averages instrument prices over a base time slice. It could be any time duration, like a second, a minute, at day, etc... Though a smaller period would mean the need for more storage, it would give me the adentage of having more info on which to base a trading decision.
2. this data feed will come from a dedicated data provider like polygonio. That implies that we do not have that much choice in the data feed period. Most data providers provide data on a minute basis. This will be the base period that we will use to architect the system. 

For every minute, each instrument will have the following info :
- **mid** : minute index, identifier of the minute, i.e number of minutes between this minute and Jan 1st 1970 00:00:00. 
- **vol** : cumulated volume of all transactions for this instrument in this minute.
- **val** : average of transaction prices for this instrument at this minute, weighted by transaction volumes.


### Latency

The second limitation is that the bot will be running only on CPUs (no hardware acceleration like FPGAs), and given what we already stated, will only be able to trade based on a per-minute data feed, which will imply a gigantic reactivity time of one minute.

A consequence is that we cannot utilize and of the methodes more sofisticated market participants can get an aventage from like : 
- anything that requires reconstructing the orderbook. 
- anything that is remotely latency critical, as our trading bot will work on the granularity of the minute.

This low reactivity is a fundamental element in the trading bot design that this series of article focus on. 

### Consequences

From my work and other projects, I am very much aware that designing a real time microkernel for embedded systems differs from designing a consumer-facing kernel.

In the same manner, I understand that removing these two limitations would fundamentally modify the structure of the trading bot. 
I also realise, that the problems I faced when doing my design and implementation were noticeably different those that must be resolved in the professional trading world where serves on which the bots run are direcly co-located within the exchange and specialized hardware accelerators is available.
Never the less I believe that this project is a relevant introductory exercise to designing automatic trading systems.
