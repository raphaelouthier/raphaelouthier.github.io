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

This series of articles will describe the structure of a low frequency trading bot supporting dynamic, adjustable and backtestable investment strategies, a project that I have been working on for two years in the hope that some day, I could just start it in the morning and watch it printing money while I drink coffee. Or contemplate it burn all my savings in 10 minutes.

This chapter will cover the necessary precautions, state the objectives of the trading bot, its limitations, the impact of these on the implementation.

For a technical description of the trading bot, please refer to part 1 of this series.
 
## Disclaimers

### Open-source

I am legally bound by my company ({{< icon "apple" >}}) to not publish open source code in any form.

Though, I am legally free to write about my personal projects.

This series of articles will sometimes post code snippets but the entire project source code will remain private.

### Sponsoring

Accross this article, I mention a few company names like polygonio or interactive brokers.

I just happen to be their client.

I have not been offered anything (money or reduction or any form of advantage) to mention those names.

For what it's worth, none from those companies even knows that this website exists.

### Languages

I am a kernel developper, and as such, I am proficient in using C.

It is not by disregard for other languages : I started programming with python as a teenager, then studied java in classes, wrote quite a lot of C++ with embedded (Arduino) development and then moved to C after I decided to stop using third party code and to just reimplement everything on bare metal.

C++ could have been a valid choice to implement my trading bot, but I generally try to stick with C when possible, as it is closer to the machine and hence, offers you more control, resulting in more perf if needed.

### Third party libraries

One of my general rules is to reimplement everything I use when possible and relevant. That is to make my code as portable as possible, and to have the best understanding of what my code does. You can assume that the entirety of the trading bot implementation (including the basic design patterns like trees, maps, lists, many functions of the standard library like formatted print and decode, etc...) is made from scratch, with a few exceptions that are worth mentioning : 
- **OS interface layer** : to be able to use kernel-managed resources, eg : files, sockets
- **curl** : data providers like polygonio provide rest-ful APIs to query the actual data. This implies that you must either use libraries like curl or re-code them yourself, which was definitely out of this project's scope. It kinda did hurt, but I installed libcurl...
- **broker APIs** : brokers like interactive brokers saw the automatic trading trend coming and created dedicated libraries to allow you to procedurally do brokerage-related actions like create and manage orders, get your portfolio composition, etc... Those libraries are rather complex and recoding them in pure C would be too risky (order passing is sensitive !) and useless. The broker chapter will discuss the way to have a pure C self-contained code interact properly with those brokerage systems.    

## Introduction
 
First, let's state the limits of this project. I am not a trader, I am a kernel engineer. As a relative outsider to the finance world, I know that the investment strategies that I could think of and implement would be of poor quality compared to the industry standards.
 
Though, coming from the kernel world, I know that even if writing processes and apps can be relatively easy, writing a kernel, i.e a system that manages those processes, and the shared resources that they may (simultaneously or not) access, is a very different problem, and forces you to see things in a way that writing user space applications would not have.

Hence, my objective in this implementation was less to implement powerful investment strategies, and more to design the infrastructure that would allow the easy implementation and efficient executions of those investment strategies. 

But enough with the warnings, let's get started.

## Banalities

First let's state the very basic objectives of our trading bot.

Base objectives :
- observe the variations of different instruments in real time.
- trade based on those variations in the least money-loosing way.

## Limitations


### I am not a trading company

First, I am just an individual investor, running code from my computer (or from a server) not directly connected to any exchange.
That has the following implications :
- 1 : real time orderbook feed will not be available. We must hence use an aggregated data feed, which averages instrument prices over a base time slice. It could be any time, like a second, a minute, at day, etc... A smaller period will mean more storage but more info to make a trading decision.
- 2 : data feed will come from a dedicated data provider like polygonio. That implies that we do not have that much choice in the data feed period. Most data providers provide data on a minute basis. This will be the base period that we will use to architect the system. 

For every minute, every instrument will have the following info :
- mid : minute index, identifier of the minute, i.e number of minutes between this minute and Jan 1st 1970 00:00:00. 
- vol : cumulated volume of transactions for this instrument at this minute.
- val : average of transaction prices for this instrument at this minute, weighted by transaction volumes.


### Latency

The second limitation is that the bot will be running only on CPUs (no hardware acceleration like FPGA), and given what we already stated, will only be able to trade based on a per-minute data feed, which will imply a gigantic reactivity time of one minute.

A consequence is that we cannot use exploits that for example hyper-frequency trading could take advantage of, like : 
- anything that requires reconstructing the orderbook. 
- anything that is remotely latency critical, as our trading bot will respond by the minute at least.

This low reactivity is a fundamental element in the trading bot design that this series of article focus on. 

### Consequences

From my work and other projects, I very much know that designing a real time microkernel for embedded systems differs from designing a consumer-facing kernel.

The same waym, I understand that removing these two limitations would fundamentally modify the structure of the trading bot and hence, that the problems that I faced when doing my design and implementation were noticeably different than the ones that must be resolved in the professional trading world where devices are connected to the marketplace servers and specialized hardware (FPGAs) is available.

But I believe that this project is a relevant introductory exercise to automatic trading nevertheless.
