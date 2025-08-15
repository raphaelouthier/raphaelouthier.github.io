--- 
title: "TurboJSON : High level optimization." 
summary: "Removing unnecessary processing steps."
series: ["Json_optimization"]
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

TODO Convert notes to actual readable article material.


``` C
/*****************
 * Fast skip API *
 *****************/

/*
 * Skip a string.
 */
const char *ns_js_fsk_str(
        const char *pos
)
{
        char c = *(pos++);
        check(c == '"');
        char p = c;
        while (1) {
                c = *(pos++);
                if ((c == '"') && (p != '\\'))
                        return pos;
                p = c;
        }
}

/*
 * Skip a number.
 */
const char *ns_js_fsk_nb(
        const char *pos
)
{
        return NS_STR_SKP64(pos, '+', (RNG, '0', '9'), (VAL, 'e'), (VAL, 'E'), (VAL, '.'), (VAL, '+'), (VAL, '-'));
}

/*
 * Skip an array.
 */
const char *ns_js_fsk_arr(
        const char *pos
)
{
        char c = *(pos++);
        check(c == '[');
        u32 cnt = 1;
        while (1) {
                while (((c = *(pos++)) != '[') && (c != ']') && (c != '"'));
                if (c == '"') {
                        pos = ns_js_fsk_str(pos - 1);
                } else if (c == '[') {
                        cnt += 1;
                } else {
                        if (!(cnt -= 1)) {
                                return pos;
                        }
                }
        }
}

/*
 * Skip an object.
 */
const char *ns_js_fsk_obj(
        const char *pos
)
{
        char c = *(pos++);
        check(c == '{');
        u32 cnt = 1;
        while (1) {
                while (((c = *(pos++)) != '{') && (c != '}') && (c != '"'));
                if (c == '"') {
                        pos = ns_js_skp_str(pos - 1);
                } else if (c == '{') {
                        cnt += 1;
                } else if (c == '}') {
                        if (!(cnt -= 1)) {
                                return pos;
                        }
                }
        }
}

/*
 * Skip a value.
 */
const char *ns_js_fsk_val(
        const char *pos
)
{
        const char c = *pos;
        if (c == '{') return ns_js_fsk_obj(pos);
        else if (c == '[') return ns_js_fsk_arr(pos);
        else if (c == '"') return ns_js_fsk_str(pos);
        else if (c == 't') return ns_js_fsk_true(pos);
        else if (c == 'f') return ns_js_fsk_false(pos);
        else if (c == 'n') return ns_js_fsk_null(pos);
        else return ns_js_fsk_nb(pos);
}
```


TODO SKIP algorithm.

```
$ nkb && build/prc/prc -rdb /tmp/regs.json -c 10
stp 0 : 62.251.
stp 1 : 41.016.
stp 2 : 40.413.
stp 3 : 40.051.
stp 4 : 41.333.
stp 5 : 42.412.
stp 6 : 41.331.
stp 7 : 41.820.
stp 8 : 41.574.
stp 9 : 41.314.
Average : 43.351.
```

This trick just gave us a 20% perf gain.

## Trick 2 : Larger read width.

```C

/*
 * Skip an array.
 */
const char *ns_js_fsk_arr(
        const char *pos
)
{
        char c = *(pos++);
        check(c == '[');
        u32 cnt = 1;
        while (1) {
                stt:;
                uint64_t v = *(uint64_t *) pos;
                uint64_t v1 = *(uint64_t *) (pos + 8);
                for (u8 i = 0; i < 2; i++) {
                        for (u8 i = 0; i < 8; pos++, i++, v >>= 8) {
                                c = (uint8_t) v;
                                if ((c != '[') && (c != ']') && (c != '"')) continue;
                                if (c == '"') {
                                        pos = ns_js_fsk_str(pos);
                                        goto stt;
                                } else if (c == '[') {
                                        cnt += 1;
                                } else if (c == ']') {
                                        if (!(cnt -= 1)) {
                                                return pos + 1;
                                        }
                                }
                        }
                        v = v1;
                }
        }
}

/*
 * Skip an object.
 */
const char *ns_js_fsk_obj(
        const char *pos
)
{
        char c = *(pos++);
        check(c == '{');
        u32 cnt = 1;
        while (1) {
                stt:;
                uint64_t v = *(uint64_t *) pos;
                uint64_t v1 = *(uint64_t *) (pos + 8);
                for (u8 i = 0; i < 2; i++) {
                        for (u8 i = 0; i < 8; pos++, i++, v >>= 8) {
                                c = (uint8_t) v;
                                if ((c != '{') && (c != '}') && (c != '"')) continue;
                                if (c == '"') {
                                        pos = ns_js_fsk_str(pos);
                                        goto stt;
                                } else if (c == '{') {
                                        cnt += 1;
                                } else if (c == '}') {
                                        if (!(cnt -= 1)) {
                                                return pos + 1;
                                        }
                                }
                        }
                        v = v1;
                }
        }
}
```


```
$ nkb && build/prc/prc -rdb /tmp/regs.json -c 10
stp 0 : 59.529.
stp 1 : 34.611.
stp 2 : 30.723.
stp 3 : 30.411.
stp 4 : 29.897.
stp 5 : 31.522.
stp 6 : 30.488.
stp 7 : 30.425.
stp 8 : 30.707.
stp 9 : 30.250.
Average : 33.856.
```

Here's another 10ms gain, 25% better than trick 1, 40% better than the original recursive version, among which 20pp are due to this added trick.


## Detour : a lower boundary for our execution time.

So I must be honest, I wasn't expecting GCC to :
- be that good at optimizing what I considered poor code, and
- give me the middle finger on what I considered a more optimized version.  

But metrics don't lie so I'll have to find better tricks.

But first, since shrinking this execution time does not sound like an easy task, let's try to reason about the actual target. 

TODO : MAP_POPULATE
TODO : TELL THAT MAPPINGS ARE PRIVATE
TODO : TELL ABOUT THROTTLING

### Profiling methodology.

The first thing we do is to map our big JSon file. We hence need to estimate the minimal time it takes.

Then, accross all our parsing, we are effectively reading the file entirely. This also will need to be accounted for since we cannot avoid it.

The following graphs were generated in one single profiling session where

To get execution time estimations for these operations, I ran 500 times the following scenario :
- Read-only map.
- Read-write map.
- Read-only map with populate.
- Read-write map populate.
- Read-only map and full read.
- Read-write map and full read.
- Read-only map with populate and full read.
- Read-write map populate and full read.

And then generated the grapgs presented in the next two sections.

It is possible that those steps interact with each other, which could explain some perf subtleties that we will cover.

### Profiling mmap.

The first thing our program does is to map our json file in memory.

Let's use the same method used in chapter 1 to determine how long just mapping the whole file with different attributes takes.

We'll do 500 iterations 

<iframe width="600" height="371" seamless frameborder="0" scrolling="no" src="https://docs.google.com/spreadsheets/d/e/2PACX-1vTz3oNv5A1TIxLR1au_-eqklkcNY5_M9mkacmsvPtAAmdNPfYzijByJhu_jwjZuvb4Lbm4Mu5ig6TAe/pubchart?oid=1803207841&amp;format=interactive"></iframe>


<iframe width="600" height="371" seamless frameborder="0" scrolling="no" src="https://docs.google.com/spreadsheets/d/e/2PACX-1vTz3oNv5A1TIxLR1au_-eqklkcNY5_M9mkacmsvPtAAmdNPfYzijByJhu_jwjZuvb4Lbm4Mu5ig6TAe/pubchart?oid=711579004&amp;format=interactive"></iframe>


<iframe width="600" height="371" seamless frameborder="0" scrolling="no" src="https://docs.google.com/spreadsheets/d/e/2PACX-1vTz3oNv5A1TIxLR1au_-eqklkcNY5_M9mkacmsvPtAAmdNPfYzijByJhu_jwjZuvb4Lbm4Mu5ig6TAe/pubchart?oid=2009877744&amp;format=interactive"></iframe>


<iframe width="600" height="371" seamless frameborder="0" scrolling="no" src="https://docs.google.com/spreadsheets/d/e/2PACX-1vTz3oNv5A1TIxLR1au_-eqklkcNY5_M9mkacmsvPtAAmdNPfYzijByJhu_jwjZuvb4Lbm4Mu5ig6TAe/pubchart?oid=1064451209&amp;format=interactive"></iframe>

## Detour 1 : profiling mmap + complete read.










