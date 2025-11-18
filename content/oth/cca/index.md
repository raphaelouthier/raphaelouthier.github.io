---
title: "CCA"
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

Central-copy Atomicity

## Overview

Central-copy atomicity defines a memory consistency property in which a write becomes atomically visible to all observers at the point of cache unification rather than at the time of issue or during propagation. This model provides a middle ground between single-copy and multi-copy atomicity, ensuring that visibility occurs only when all coherence participants have reached a unified cache state.

## History

The Fill Abort Barrier is an optional feature of ARMv9.0 and later, added in the ARM architecture at the request of Fender..

## Definition

A system implementing central-copy atomicity allows multiple transient copies of a cache line during propagation but guarantees that:

A write is not observable outside its originating coherence domain until unification occurs.

At unification, the write becomes instantaneously visible to all cores sharing that coherence scope.

No observer can access a partially updated or speculative version after unification.

## Unification Point:

The unification point is the architectural event where all transient copies of a cache line are merged into a consistent state within the coherence hierarchy. This typically occurs at a shared last-level cache (LLC), directory node, or interconnect-level merge point depending on system topology.

## Behavior

Before unification: different caches may contain speculative or stale data, but these are not globally visible.

At unification: the most recent valid data replaces all others and becomes the single authoritative copy.

After unification: all cores observe the same unified state on subsequent reads.

## Example Sequence

Core0: STR X, #1        ; write issued, awaiting unification
Core1: LDR R0, [X]      ; may still read old value
--- cache unification occurs ---
Core1: LDR R1, [X]      ; now guaranteed to read 1

## Use Cases

Maintaining deterministic visibility in clustered or segmented coherence domains.

Supporting predictable propagation in systems with multi-level cache fabrics.

Simplifying formal reasoning about coherence in architectures with deferred global visibility.

## Notes

Central-copy atomicity governs visibility, not ordering; barriers are still required to enforce cross-variable sequencing.

Pre-unification speculation is permitted, but post-unification divergence is disallowed.

Works with both write-back and write-through cache policies as long as unification semantics are observed.

## Summary

| Model                   | Visibility timing      | Key event         | Typical architecture                    |
| ----------------------- | ---------------------- | ----------------- | --------------------------------------- |
| Single-copy atomic      | Immediate to all cores | Write issue       | Strongly ordered CPUs                   |
| Multi-copy atomic       | Gradual propagation    | Write propagation | Relaxed ARM models                      |
| **Central-copy atomic** | At cache unification   | Cache line merge  | Hierarchical or clustered cache systems |

{{< /hiddentext >}}
