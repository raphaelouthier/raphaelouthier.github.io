---
title: "Trading bot : data provider"
summary: "Data provider"
series: ["Trading bot"]
series_order: 2
categories: ["Trading bot"]
#externalUrl: ""
showSummary: true
date: 2025-06-13
showTableOfContents : true
draft: true
---

This chapter will describe the design choices of the data provision system.

## Participants

## Consumer needs

## Remote provider

## Constraints

## File system and buffer mapping in userspace. 

TODO intro to file system buffer management.

TODO intro to MMU. 

TODO intro to mmap.

## Design

{{< figure
	src="images/bot/bot_prv_syn.svg"
	caption="Data provider synchronization example."
	alt="prv sync"
	>}}

## Storage file layout

```
  Offset        Description    Data
┌────────────┬──────────────┬───────────────────────────┐
│            │              │                           │
│            │              │  Marketplace              │
│  0         │  Descriptor  │  Symbol                   │
│            │              │  Total number of minutes  │
│            │              │                           │
├────────────┼──────────────┼───────────────────────────┤
│            │              │  Sync data access lock    │
│ PG_SIZ     │  Sync data   │  Write flag               │
│            │              │  *Fill counter            │
├────────────┼──────────────┼───────────────────────────┤
│            │              │                           │
│            │              │  Raw array of values      │
│ 2 * PG_SIZ │  Values      │  in mid order             │
│            │              │  (f64)                    │
│            │              │                           │
├────────────┼──────────────┼───────────────────────────┤
│            │              │                           │
│ 2 * PG_SIZ │              │  Raw array of volumes     │
│ + VA_SIZ   │  Volumes     │  in mid order             │
│            │              │  (f64)                    │
│            │              │                           │
├────────────┼──────────────┼───────────────────────────┤
│            │              │                           │
│ 2 * PG_SIZ │              │  Raw array of indices     │
│ + VA_SIZ   │  Prev ids    │  in mid order             │
│ + VO_SIZ   │              │  (f64)                    │
│            │              │                           │
├────────────┼──────────────┼───────────────────────────┤
│            │              │                           │
│ 2 * PG_SIZ │              │                           │
│ + VA_SIZ   │   End        │  N/A                      │
│ + VO_SIZ   │              │                           │
│ + PR_SIZ   │              │                           │
│            │              │                           │
└────────────┴──────────────┴───────────────────────────┘
```

First, let's remind that each section (except END...) will be mmap-ed by the trading bot's local provider in order to read and write data. Hence, each section needs to be placed at an offset which allows its mapping. 

As stated above, the MMU only allows us to map entire pages, which means that our section must reside at an offset which is a multiple of a page.

Since our trading bot may run on multiple system, we must only ensure that our file layout is compatible with the systems that we want to run on, by choosing a very large page size. 64KiB is enough for modern system.

TODO ELABORATE ON THE MAX NUMBER OF MINUTES PER YEAR AND LEAP YEARS.

TODO ELABORATE ON OTHER PARAMETERS.

## Going further ; mapping, readability, shareability.

## going further : prv array
