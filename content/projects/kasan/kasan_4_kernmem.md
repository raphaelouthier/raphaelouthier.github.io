---
title: "Kernel memory management."
summary: "How the kernel manages primary memory."
series: ["KASAN"]
series_order: 4
categories: ["KASAN"]
#externalUrl: ""
showSummary: true
date: 2023-09-27
showTableOfContents : true
draft: true
---

Before elaborating on how the memory checker will actually check memory accesses, we need to elaborate on how memory is managed by the kernel in a microcontroller, or more generally, in a systen without an MMU.

# Memory region

The term region here refers to a memory region and not an MPU region.

A memory region is a portion of the address space :
- at which memory is mapped.
- around which memort is not mapped.

In particular, if an address range R is a memory region : 
- all bytes in this range are accessible and are mapped to memory.
- the two bytes before and after R are not mapped to memory.

A microcontroller has multiple memory regions. For example, the STM32H750 has the following memory regions available :
TODO

# Regions manager

One of the most fundamental job of the kernel is to manage memory, that is, to allow itself and its users to allocate and free memory.

The precise architecture, and the reason that guide the architecture of such a memory management system will not be discussed here, as it requires a dedicated chapter. I may or may not write about that in the future. Rather, I will focus on the high level blocks and features, with few justifications.

Managing memory is not easy, particularly when dealing with small memory blocks, as it often requires metadata.

Various allocation techniques exist and each have their tradeoff.

The memory management's fundamental block is the regions manager. It has to : 
- manage memory regions, as in tracking the allocation state of every byte of every region.
- allow dynamic allocation of blocks of arbitrary sizes.
- allow dynamic free of allocated blocks.

# Page

To do that in a manner that is not too catastrophic for the perf, the regions manager will define arbitrarily the notion of page, as a block of size 2 ^ PAGE_ORDER, aligned on its size, with PAGE_ORDER the order of a page.

The region allocator will then manage memory on a per-page basis : rather than keeping track of the allocation status of each and every byte in the system, it will keep track of the status of every page in the system, and make allocations on a per-page basis.

The order of the page is arbitrary, but the reader can have the following orders in mind : 
- modern systems : size = 64KiB, order = 16. (or higher).
- older systems (and windows lol) size = 4KiB,order = 12.
- embedded systems : size = 1KiB, order = 10. (or lower).

The order of a page may be dictated by the hardware, in a system with an MMU, as it must match the translation granule of the said MMU.

Here, we do not have that constraint. The page order will be selected by the kernel developper depending on the use case, using the following criteria : 
- a larger memory order will mean less pages in the system, which will mean more fragmentation in the allocators that will use those pages, but less metadata per page, so more a potentially better use of the memory. May be better for specialized applications where large blocks are required.
- a smaller memory order will mean more pages in the system, while will mean less fragmentation in the allocators that will use those pages, but more metadata per page, so a potentially underuse of the memory. May be better for generic applications that allocate a lot of blocks of different sizes in a non-predictible manner.

The way to allocate and free pages is implementation-defined and depends on the use case : 
- if allocation of blocks of contiguous pages is required, a buddy allocator can be used. This method only supports allocating block of 2 ^ k pages which proves to be enough in practice.
- if the system only needs pages and not particularly blocks of pages, a simple linked list can be used.

# Region per-page metadata

To manage the state of the pages, the regions manager will need per-page metadata.

These per-page metadata are a net cost, as in they can't be repurposed when the page is free, or allocated.

The regions manager is the fundamental block of the memory allocator. Other allocators are built on top of it. A consequence to that is that it cannot rely on dynamic memory allocation to allocate its metadata.

Think about it : when the system boots, all allocators are empty. During bootstrap, when the regions manager will register its first memory region, how could it allocate metadata, since calling some form of malloc would ultimately cause its own page allocation functions to be called, yielding a failure, since no memory is yet registered. This is a classical memory chicken and egg problem.

The regions manager solves this problem by carving out a block of static (non-reusable, not provided by another allocator) per-page metadata in the actual memory block that will contain the pages.
In other words, it will use some of the (theoretical) pages to contain the metadata of the remaining pages. The pages containing metadata will obviously not be available for allocation.

For the regions manager, a page will be either : 
- not accessible : the page hasn't been allocated to any user of the regions manager and shoud _never_ be accessed by anyone.
- accessible : the page has been allocated to a secondary allocator, who may access it, and provide access to portions of it to users.

# Secondary allocators.

As described in the previous section, the regions manager's job is to manage memory regions.

It can only allocate memory on a per-page basis, and cannot allocate smaller blocks.

Though, it is kind of rare for a user software to need an actual page of memory. A rough estimation is that most allocations require around 1 to 4 cache lines of memory (64B -> 256B) which is way smaller than a page, even in a microcontroller environment.

The secondary allocators handle this use case.

Their behavior is simple : they act as an interface between the user and the regions manager, by allocating large blocks of memory (blocks of 2 ^ k pages), and by dividing them into smaller blocks in an implementation-defined manner, and by then allocating these blocks to the user.

There are many secondary allocators, that each have their own axions and tradeoffs. We can mention : 
- slab : supports both allocation and free of blocks of a fixed size. Works by dividing a page into block of the same size. Block state is either stored in a bitmap, or directly in the data of the free blocks, to form a linked list of free blocks.
- slab array : supports both allocation and free of blocks of a set of sizes. Uses multiple slabs, one for each supported size.
- stack : supports allocation of blocks of arbitrary size and mass-free only.
- heap : supports allocation and feee of blocks of arbitrary size, allocating blocks of different sizes in the same pages. Inefficient.

Any memory block that the allocators manage is provided by the regions manager. As such, such block is always accessible.

From the allocator's perspective, a block of memory is :
- free : the block is not accessible by any user. It can be used by the allocator to store metadata.
- allocated : the block is accessible to all users. It should never be accessed by the allocator.

# Summary

The following diagram summarizes the architecture of the memory system.

TODO.
