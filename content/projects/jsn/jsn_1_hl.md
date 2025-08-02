--- 
title: "TurboJSON : High level optimization." 
summary: "Removing unnecessary processing steps."
series: ["Json optimization"]
series_order: 1
categories: ["C","ARM64","Optimization"] 
#externalUrl: "" 
showSummary: true
date: 2025-08-02 
showTableOfContents : true 
draft: true 
---

{{< figure src="images/jsn_1_head.png" >}}

## Introduction

This chapter will cover the modifications of the structure processing algorithm that increase the json parsing performance.  

It will not cover tricks to optimize _existing_ _steps_ (like using an assembly trick to do the same thing but faster). For this kind of details, please refer to the next chapter.

Let's first remind two facts.

First, the json format is not structured in memory (you can't just skip to the next entity by applying a (compile-time or runtime) constant byte offset : you must process the entire file char by char.

Second, our base reference time for processing the entire file with no special trick is around `50ms`. Let's see by how much we can divide that.

There are many possible ways to rework the json parsing algorithm, but not all will :
- always be functional.
- always notably increase the performance.

## Profiling

In order for us to efficiently optimize, we first need execution metrics to see where most of the processing time is spent. Then, we can make design decisions based on that.

There are multiple ways to profile an executable :
- sampling (statistical profiling) : the program is periodically stopped and the current backtrace is captured. This will show the most frequent call sites and their callers. `gprof` does this, among other things. 
- tracing (exact profiling) : the CPU itself (via dedicated HW) generates a trace that can later be retrieved to reconstruct a program's exact execution sequence. Dedicated HW is needed (ex : ARM64's ETM).
- simulation : the program is ran by a simulator which records the calls and provides semi-exact cycle time data. Valgrind's callgrind tool works like this.

I prefer to use callgrind for simplicity, and kcachegrind to visualize the execution ratios.

One downside of valgrind is that it works by changing your program's assembly to add instrumentation around various operations and hence. The only thing that it doesn't change is your program's execution (unless it depends on timing-related factors), but other metrics will more or less reliable. In particular : 
- execution time takes a 10x to 100x hit.
- the assembly will be less performant because of the instrumentation.

But it still does a good job at telling you where your program spends most of its time.

Let's run it and check what it does.

```
$ valgrind --dump-instr=yes --tool=callgrind build/prc/prc
==26755== Callgrind, a call-graph generating cache profiler
==26755== Copyright (C) 2002-2017, and GNU GPL'd, by Josef Weidendorfer et al.
==26755== Using Valgrind-3.24.0 and LibVEX; rerun with -h for copyright info
==26755== Command: build/prc/prc
==26755==
==26755== For interactive control, run 'callgrind_control -h'.
Available rdb commands :
  lst : list registers.
  reg : show info about a register.
  dec : decode the value of a register.
  lyt : generate a C register layout struct.
==26755==
==26755== Events    : Ir
==26755== Collected : 649845413
==26755==
==26755== I   refs:      649,845,413
$ kcachegrind callgrind.out.26755
```

> My command line tool loads the database during early startup so the command that we run is not important. Here it just displayed the list of available commands.

Let's take a look at the callee map :

{{< figure src="images/jsn_1_cgd_0.png" >}}

And Here is a simplified call graph :

{{< figure src="images/jsn_1_cgd_1.png" >}}

The <cycle 8> node is the way kcachegrind tells us that our program actually recursed, which is logical as since the json structure is recursive, object or array parsing is not terminal and will likely recurse.

## Preliminary analysis

The first thing that we can see is that we spend _ALL_ our time processing characters.

Second, we spend a lot of time parsing :
- objects : that makes sense as the register DB is composed mostly of them.
- characters : which is the internal function to skip a string, which makes sense as those are both used as key and value. 

So let's take a step back here.

To parse the JSON, we need to iterate over all substructures. There's no avoiding it, but it doesn't mean that we cannot skip a bunch of things.

The parsing method implemented here will _carefully_ parse all substructures, recognize them, to potentially extract info from them.

In our case, we do not care about the majority of objects that we are parsing. Those that we care about are inherently explored due to how the object / array iterators work, but others are skipped with the following function : 

``` C
/*
 * Skip a value.
 */
const char *ns_js_skp_val(
	const char *start
);
```

This function is called whenever we do _not _care_ about the result of the parsing.

So maybe we can rework it so that it is not _as_ _careful_ in its parsing as if we cared about the information that it skips.

## Detour : malformed jsons

An unsaid guarantee that the parser currently provides is to correctly detect and handle malformed jsons.

Just for the experiment, let's remove a comma at 50% of our huge json file, in a section where we do not intend on extracting information :

```
 "access": {                
   "_type": "AST.Function", 
   "arguments": [],         
   "name": "Undefined"   <--- missing comma   
   "parameters": []         
 },                         
```

Let's feed it to the parser and how it reacts :

```
$ build/prc/prc lst
[../kr/std/ns/src/lib/js.c:463] expected a '}' at object end : '"parameters": []
   '.
```

So the parser actually detected the malformation.

This is due to the fact stated in the previous section : since skipping a value causes a full parsing of this value, let it be object, string or array, then any syntax error in this value is be detected and is cause the parsing to fail.

Maybe we can alleviate this restriction a bit to increase perf.

In our case, we always parse the same json file, so we can just check its correctness once, and then rely on the fact that we will not update it.

In a production environment, it may or may not be safe to assume the correctness of real-time data. It will depend. 

## Skipping arrays and objects the smart way : bracket counting.

As a matter of fact, 












