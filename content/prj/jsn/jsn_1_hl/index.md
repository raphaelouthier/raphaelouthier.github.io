--- 
title: "TurboJSON : C-level optimization." 
summary: "Removing unnecessary processing steps."
series: ["Json_optimization"]
series_order: 1
categories: ["C","ARM64","Optimization"] 
#externalUrl: "" 
showSummary: true
date: 2025-08-02 
showTableOfContents : true 
---

{{< figure src="images/jsn_1_head.png" >}}

## Introduction

This chapter will cover the modifications of the structure processing algorithm that decrease the JSON parsing time of around 40%.

It will cover all optimizations that can be implemented at the C level, while the next chapter will focus on how we can improve it even more by using tricks reserved for the assembly world.

Let's start by remembering a few facts.

First, the JSON format is not structured in memory (you can't just skip to the next entity by applying a (compile-time or runtime) constant byte offset : you must process the entire file char by char.

Second, our base reference time for processing the entire file with no special trick is around `50ms`. Let's see how much we can reduce that.

There are many possible ways to rework the JSON parsing algorithm, but not all will :
- always be functional.
- always notably increase the performance.

## Profiling

In order for us to efficiently optimize, we first need execution metrics to see where most of the processing time is spent. Then, we can make design decisions based on that.

There are multiple ways to profile an executable :
- sampling (statistical profiling) : the program is periodically stopped and the current backtrace is captured. This will show the most frequent call sites and their callers. `gprof` does this, among other things.
- tracing (exact profiling) : the CPU itself (via dedicated HW) generates a trace that can later be retrieved to reconstruct a program's exact execution sequence. Dedicated HW is needed (ex : ARM64's ETM).
- simulation : the program is run by a simulator which records the calls and provides semi-exact cycle time data. Valgrind's callgrind tool works like this.

I prefer to use callgrind for simplicity, and kcachegrind to visualize the execution ratios.

One downside of valgrind is that it works by changing your program's assembly to add instrumentation around various operations and hence. The only thing that valgrind doesn't change is your program's execution (unless it depends on timing-related factors, in which case you have other problems), but other metrics will be more or less reliable. In particular :
- execution time takes a 10x to 100x hit. You read correctly.
- the assembly will be less performant because of the instrumentation.

But it still does a good job at telling you where your program loses most of its time.

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

The <cycle 8> node is the way kcachegrind tells us that our program actually recursed, which is logical as since the JSON structure is recursive, object or array parsing is not terminal and will likely recurse.

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

## Detour : malformed JSONs

An unsaid guarantee that the parser currently provides is to correctly detect and handle malformed JSONs.

Just for the experiment, let's remove a comma at 50% of our huge JSON file, in a section where we do not intend on extracting information :

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

This is due to the fact stated in the previous section : since skipping a value causes a full parsing of this value, let it be object, string or array, then any syntax error in this value is detected and can cause the parsing to fail.

Maybe we can alleviate this restriction a bit to increase perf.

In our case, we always parse the same JSON file, so we can just check its correctness once, and then rely on the fact that we will not update it.

In a production environment, it may or may not be safe to assume the correctness of real-time data. It will depend.

## 20% gain by skipping the right way.

Our container skippers are pretty complex for what they intend to do : they are calling sub-skippers for every entity that containers are composed of. By doing so, they strictly respect the JSON format. But who actually cares, since they discard the result.

Knowing that fact, we can do better. Instead of diligently parsing the entire structure, we just iterate over all characters and count brackets.

We start at the character the first (opening) bracket of the container, and iterate over all characters while maintaining a bracket counter :
- if we detect an opening bracket (either `[` or `{` depending on the container type) we increment the bracket counter.
- if we detect a closing bracket, we decrement the bracket counter, and stop if it reaches 0.
- if we detect a string, we'll skip the string. This is required to avoid counting brackets inside strings.

In the meantime, we can also simplify our string parsing algorithm by stopping at the first quote which is not preceded by a backslash.

We can also improve our number skipper. A quick look at the ascii table will show that all characters that a number can be composed of (`[0-9eE.+-]`) are in the character decimal interval `['+', '+' + 64]` which allows us to apply the fast set membership test trick that I covered [in this article](/asm/trk_0_set).

{{< collapsible-code path="content/prj/jsn/jsn_1_hl/fst_skp.h" lang="c" title="Faster JSON entity skippers." >}}

Let's check how much perf we gained :

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

## 25% gain by gathering memory reads.

One of the bottlenecks of modern systems is memory access.

Here we are doing something stupid, which is to read character by character.

This will effectively translate into single char requests from our CPU to its memory system. This can be improved with a bit of trickery.

Instead of reading character by character, we will read `uint64_t by uint64_t` and process each of the 8 read bytes one after the other.

The best performance result that I had so far was by doing two consecutive `uint64_t` reads and processing each of the resulting 16 bytes one after the other.

{{< collapsible-code path="content/prj/jsn/jsn_1_hl/u64_mem.h" lang="c" title="Reading 16 characters at a time." >}}

{{< alert >}}
The attentive reader will note that this code intrinsically generates unaligned accesses.

Unaligned accesses make the CPU designers' life hard. They are unhappy about that. They probably also know where you live.

Unaligned accesses are bad. Don't do unaligned accesses.

Unless they give you a 25% perf increase. In which case it’s just fine...
{{< /alert >}}

Let's see how much we gained.

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

That's another 10ms gain, 25% better than trick 1, 40% better than the original recursive version, among which 20pp are due to this added trick.

## Conclusion

With those improvements we almost divided our execution time by 2.

As the next chapter will show, we can shrink it even more but to do this, we need to move to the assembly level, to apply tricks that the compiler is too clumsy to handle correctly.

