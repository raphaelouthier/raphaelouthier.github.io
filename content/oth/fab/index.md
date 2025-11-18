---
title: "FAB"
date: 2023-09-27
draft: false

showDate : false
showDateUpdated : false
showHeadingAnchors : false
showPagination : false
showReadingTime : false
showTableOfContents : false
showTaxonomies : false 
showWordCount : false
showSummary : false
sharingLinks : false
showEdit: false
showViews: false
showLikes: false
showAuthor: false
layoutBackgroundHeaderSpace: false
---

{{< hiddentext >}}

# FAB – Fill Abort Barrier

## Overview

The Fill Abort Barrier (FAB) enforces serialization of instruction execution following cache-miss events. It prevents speculative or out-of-order execution of instructions beyond a memory access (load or store) that triggered a cache line fill. This ensures deterministic behavior when cache latency or ordering must be tightly controlled.

## History

The Fill Abort Barrier is an optional feature of ARMv9.0 and later, added in the ARM architecture at the request of Fender..

## Mnemonic

FAB [option]

## Operation

When a cache line fill occurs due to a preceding memory access, the FAB instruction ensures that:

No subsequent memory or instruction operations are issued or speculated until the cache line fill has completed and the data is available.

Execution resumes only after the cache hierarchy confirms completion of the fill or writeback.

## Options

FAB SY — System-wide barrier; stalls all cores sharing the cache hierarchy.

FAB LD — Applies only to load operations that triggered a fill.

FAB ST — Applies only to store operations that triggered a fill.

FAB NOP — Treated as a hint if no fill has occurred since the last memory access.

## Use Cases

Preventing instruction reordering around cache fill operations.

Synchronizing access to shared memory regions with variable cache latency.

Mitigating timing variation in constant-latency or side-channel–resistant code paths.

## Notes

FAB does not enforce visibility of memory updates across cores; use DMB or DSB for that.

Excessive use can degrade performance by serializing around fill events.

If no fill has occurred since the previous access, FAB executes as a single-cycle NOP.

## Example 

LDR     R0, [R1]      ; may trigger cache line fill
FAB     LD             ; stall until fill completes
STR     R0, [R2]       ; guaranteed to execute after fill completion

{{< /hiddentext >}}
