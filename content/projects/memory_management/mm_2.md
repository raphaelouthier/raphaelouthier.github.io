---
title: "Memory Manager : Part 2"
summary: "Secondary allocator"
series: ["Memory Management"]
series_order: 2
categories: ["Kernel", "Memory Management", "C", "Operating Systems"]
#externalUrl: ""
showSummary: true
date: 2021-09-21
showTableOfContents : true
draft: true
---

### Introduction

In the previous chapters, we defined the base characteristics of the system supervised 
by the memory manager, and we detailed the structure of such memory managers with a 
focus on the primary memory management.

In this chapter we aim to explore the secondary memory manager but, detailing secondary memory management
 will require a different approach, as it is less constrained by the characteristics of the system.
Since the primary memory manage is responsible for managing and supervising the 
allocation of primary memory it abstracts all the details of the system for the secondary memory manager and provides a high level page block allocation / free API.

The secondary memory management can be defined as:
> a set of techniques that, from page blocks provided by a primary memory manager, provide APIs to allocate or free memory blocks of smaller sizes.

These techniques are numerous, and this article does not intend to be exhaustive. \
Rather, I wish to share the ones I found to be the most useful in my different implementations, and provide, for each of them, an overview of their different objectives, trade-offs, and working principles.

{{< figure
src="images/memory_management/diskette.webp"
caption="Photo credit : Photo by pipp from FreeImages"
>}}

### Allocation types, the detailed version 

The secondary allocator is the allocator the end-user accesses to obtain and recycle its memory.

This allocator is, as a consequence, a critical block, as any additional allocation latency may heavily impact the user.

To design such an allocator efficiently, the **requirements** of the user in terms of speed and memory sizes best be known.

A first estimation we need to make is that of the allocation frequency per allocation size, as the user may require more blocks of certain size ranges, and less blocks of other size ranges.

The higher the frequency is, the more critical optimizing this case will be, and as such it should ideally :

- require the fastest allocation methods.
- not be concerned by internal superblock fragmentation issues, i.e. allocating a superblock and using very few blocks in it.

For block sizes which are less frequently used are thus less critical, we can :
- allow slower allocation methods.
- require methods to maximise the use of allocated superblocks to avoid fragmentation.

#### Real world experiment 

Let’s use an experiment to classify such ranges.

For this I turned to the allocator of my kernel and added functionality to report each allocation and its requested size.

Then I ran the kernel with some user programs: one of them was an instance of my home made VM doing its memory-consuming job of lexing, parsing, computing, compiling and executing.

I then stored the size of all resulting allocation requests in a spreadsheet.

Finally, I determined the amount of allocation of each size and compounded the results to the following graph :

<iframe width="600" height="371" seamless frameborder="0" scrolling="no" src="https://docs.google.com/spreadsheets/d/e/2PACX-1vSISxipUdgWH-1foxUlx5Z-rxbsQac0aapdLH96IJHcdLXxTU9gBu0BT_RUfVsTSxLV7WKDnsU63q7N/pubchart?oid=628429022&amp;format=interactive"></iframe>

Same data using a log scale on the Y axis : 

<iframe width="600" height="371" seamless frameborder="0" scrolling="no" src="https://docs.google.com/spreadsheets/d/e/2PACX-1vSISxipUdgWH-1foxUlx5Z-rxbsQac0aapdLH96IJHcdLXxTU9gBu0BT_RUfVsTSxLV7WKDnsU63q7N/pubchart?oid=742091593&amp;format=interactive"></iframe>

The difficulty to read it comes from the fact that a rare part of some of these allocations were large (max 2700B), and the vast majority concerns at most the range 0B -> 256B.

Redrawing the first graph on this range gives the most informative result :

<iframe width="600" height="371" seamless frameborder="0" scrolling="no" src="https://docs.google.com/spreadsheets/d/e/2PACX-1vSISxipUdgWH-1foxUlx5Z-rxbsQac0aapdLH96IJHcdLXxTU9gBu0BT_RUfVsTSxLV7WKDnsU63q7N/pubchart?oid=899902736&amp;format=interactive"></iframe>

As we can see, the most used range is the 1B->64B range, which corresponds to the small blocks allocation type that I evocated in the first chapter : results show that only 360 allocations over 9963 were strictly superior to 64 bytes, which makes less than 4 percents (3.61) of all allocations.

<iframe width="600" height="371" seamless frameborder="0" scrolling="no" src="https://docs.google.com/spreadsheets/d/e/2PACX-1vSISxipUdgWH-1foxUlx5Z-rxbsQac0aapdLH96IJHcdLXxTU9gBu0BT_RUfVsTSxLV7WKDnsU63q7N/pubchart?oid=119799290&amp;format=interactive"></iframe>

The small blocks type is, as a consequence, the allocation type on which I must focus my optimization efforts.

### Slab

{{< katex >}}

A Slab allocator receives superblocks (aka : page blocks), from the primary memory manager,
 and treats them as arrays of blocks of a constant size \\(N\\), that it frees and allocates to its 
users. 
<p style="text-align:center; font-weight: 600;">
It can only allocate blocks of this size.
</p>

Each superblock has a header that keeps track of the number of 
its blocks that are allocated or in the allocator’s cache, and of the non-allocated zone, 
i.e. the zone of the superblock that contains only non-allocated blocks.\
When the superblock is allocated, this zone occupies the whole superblock. \
When the superblock must allocate one block, the first block of the zone is allocated, and the zone is truncated with this block.

Each superblock also has a cache (i.e. linked list) that references all its free blocks that 
are not in the non-allocated zone or in the allocator’s cache.\
The allocator also has a cache (i.e linked list) that references free blocks of all superblocks that are not in their superblock’s cache or non-allocated zone.

--- 

The slab works the following way :

#### Allocation

- If a block is present in the allocator’s cache, remove it from the cache and use it.
- Otherwise, if a superblock has free blocks, either in its cache or in its non-allocated zone, use a block in this superblock (and increment this superblocks’ number of allocated blocks).
- Otherwise, allocate a new superblock and use a block in it

#### Free

- Push the block in the allocator’s cache.

#### Recycling

For each block in the allocator’s cache :
- Find the superblock the block is part of.
- Push the block in the superblock’s cache and decrement superblock’s number of allocated blocks.

#### Superblock collection

- Any superblock with no allocated blocks can be freed.

--- 

The slab is one of the simplest and most fundamental allocator as it is **freestanding**, all the metadata it uses can be stored in the superblocks or statically :

- the allocator struct can be statically allocated.
- superblock headers can be stored at the start of the superblock, the region to allocate blocks in occupying the remaining part.
- cache nodes can be stored in the block they reference, a singly linked list requiring only one pointer.

#### Trade-offs of the slab allocator

- Only allocates one size.
- No block header -> no extra memory consumption.
- Fastest possible allocation and free.
- Causes superblock internal fragmentation if only few allocation requests are made compared to the number of blocks in a superblock.
- Memory recycling is slow, as it requires reassigning each block to its originating superblock.
- Superblock free depends on memory recycling and so, is time-consuming and should not be done frequently.

{{< figure
src="images/memory_management/slab.webp"
caption="Visual representation of the internal structure of the slab.The diagram shows a system with two allocated superblocks, each one with its own non-allocated zone in yellow, and multiple allocated blocks in red, and multiple blocks in the allocator’s cache (in cyan), and multiple blocks in their slab’s cache. The rightmost superblock’s non allocated zone could be enlarged."
>}}

### Slabs

Now that the first and simplest brick of our secondary allocation library has been defined, the next easy step we can take is to use an array of them. In this array we will be allocating multiple slabs of consecutive sizes.

There are e two types of slab arrays we can define :

- **Size increment array** : slab at index i in the array allocates blocks of size: \\(base size + (i * size step)\\).
- **Order increment array** : slab at index i in the array allocates blocks of order: \\(base order + (i * order step)\\).

{{< figure
src="images/memory_management/size_vs_order.webp"
caption="Visual representation of the nuance between size and order increment."
>}}

With \\(base size\\) and \\(size step\\), or \\(base order\\) and \\(order step\\) being parameters of the resulting allocator.

When a request for memory is received by the slab array’s handler, in order to get the appropriately sized memory, 
this request must be forwarded to the appropriate slab. In order to meet the constraint on the size of the requested 
memory the slabs array only forwards allocation and free requests to the slab allocating blocks of the **smallest greater 
or equal size**. \
This imposes the additional constraint that **the size of the block must be provided** both at allocation and free time.

#### Trade-offs of the slabs array 

- Only allocates blocks of a size range.
- No block header -> no extra memory consumption.
- Size must be provided at allocation and free.
- Very fast allocation and free (time of the selection of the slab and the slab operation).
- Freestanding, if the amount of slabs of the array is known at compile-time.


