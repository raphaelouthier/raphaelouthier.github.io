---
title: "Memory Manager : Secondary allocators."
summary: "Secondary allocator"
series: ["Memory Management"]
series_order: 2
categories: ["Kernel", "Memory Management", "C", "Operating Systems"]
#externalUrl: ""
showSummary: true
date: 2021-09-21
showTableOfContents : true
---


### Introduction

In the previous chapters, we defined the base characteristics of the system supervised
by the memory manager, and we detailed the structure of such memory managers with a
focus on primary memory management.

In this chapter we aim to explore the secondary memory manager but, detailing secondary memory management
 will require a different approach, as it is less constrained by the characteristics of the system.
Since the primary memory manager is responsible for managing and supervising the
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
caption="Visual representation of the internal structure of the slab.The diagram shows a system with two allocated superblocks, each one with its own non-allocated zone in yellow, and multiple allocated blocks in red, and multiple blocks in the allocator’s cache (in cyan), and multiple blocks in their slab’s cache. The rightmost superblock’s non-allocated zone could be enlarged."
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

#### Heap

The secondary allocators described in the previous sections are very time-efficient, but suffer from the issue of superblock fragmentation that I have described before : once a superblock is allocated, it can only serve as a memory reserve for blocks of a fixed size. If I allocate a block of size 2 only once and never again, and free it in a long time, it will cause a whole superblock to be allocated for an used amount of 2 bytes, thus causing a loss of 4094 (if 4KiB pages), the superblock being dedicated to this size.

In ranges at which memory allocation is sparse, an allocation strategy that would allow a superblock to be used as a memory source for blocks of different sizes could be desirable.

This is the reason the Heap allocator exists.

*Note:* the name “heap” is ambiguous, as heap may be related to different concepts :

- A segment in the classic process user space layout, possibly used by the allocator implementing malloc/free.
- A referencing design pattern (see binary heap).
- This kind of allocator.

The naming similarity may come from the fact that implementations of the allocator I will describe may, in the past, have used a binary heap data structure to reference their free blocks, and the aforementioned segment as primary memory source.

A quick look at the GNU allocator will reveal that the use of a binary heap is deprecated, and modern allocators tend to rely on mmap more than on brk/sbrk (syscall that update the heap segment) to get their superblocks.

That being said, I will, more by convention, keep on using the name of Heap allocator.

The solution used in this allocator to address the problem of allocating blocks of different sizes in the same superblock consists of :

- track consecutive blocks of the same superblock in a linked list headed by the superblock. At the allocation of a superblock, a single free block occupying all its available space is allocated.
- track free blocks by size in the allocator. Multiple methods can be used, the ones deserving to be mentioned being the usage of a binary heap (may be unwise because metadata / time consuming), or of a cache in the form of a set of linked lists, each one referencing free blocks of a particular size. This method is used by the dl (Doug Lea) allocator, the allocator that the gnu memory allocator is based on.
- support split of a free block into two blocks of inferior sizes.
- support coalescing of two consecutive free blocks into a larger block.

In order for this to work, each block must at least have a header containing data to reference it in the list of blocks of its superblock. This form of referencing implicitly contains the size of the block, thus providing the interesting functionality to free a block without knowing its size : given a pointer to the start of a block, simply subtracting the header size to its provider the header pointer, which provides the block size.

> This is the reason why the free function from the C standard library doesn’t take the block size in argument.

Another piece of information that the header should contain is either the binary heap node or the linked list node that references the block in the allocator by size when it is free. Though, we can remark that this node will only be used when the node is free, thus, when the block’s memory is unused. A smart optimization is then to use the block’s memory to contain the node. It implies that the minimal allocation size of the allocator is greater or equal to the size of this referencing node.

The allocation algorithm works as follows :

- **Allocation** (size \\(N\\)) : search for a free block of size \\(M >= N\\) in the cache. If the remaining size
\\(M — N\\) can contain a block header and a memory block of the minimal size, split the block in two, one of size \\(N\\)
 and the other occupying the remaining part. Then return the first part of the split block if split, or the selected block otherwise.
- **Free** : retrieve the block header, and attempt to merge it with its successor and its predecessor if they exist and are free. Then, insert the resulting block in the allocator’s cache using its size.

The coalescing part (merge with neighbour) may be costly and so can be delayed, but may result in external fragmentation, as shown in the next diagram, leading to fragmentation.

---

{{< figure
src="images/memory_management/heap.webp"
caption="Visual representation : showing an allocation / free scenario of blocks of size N in a superblock of size 3 * N (with headers ignored for the sake of simplicity). Free areas are represented in green, allocated areas in grey. Numbers at the bottom represent the time line, referred to in the article as “steps”."
>}}

In steps **1 to 3**, all blocks are allocated.\
Then, in steps **4 to 6**, they are freed in a different order, with the middle block at last, and not coalesced,
keeping 3 free blocks in cache. \
Then, an allocation is done again at step **7**, which, depending on the caching mechanism, may provide the middle block.


Though the amount of memory is available, an attempt to allocate a block of size \\(2 * N\\) will fail, as no contiguous block of this size is available.

The same scenario with direct block coalescing is presented in steps **6’** and **7’**, and solves this issue.

---

#### Trade-offs of the heap allocator

- Supports all sizes that fit in a superblock.
- Supports block allocation and free.
- Block size is not required at block free.
- Block header -> extra memory consumption.
- Block header -> no alignment guarantees except for the fundamental order. Aligned allocation is possible but requires more metadata or allocation time.
- Allocation and free are slower than other methods due to block split and coalescing.

{{< figure
src="images/memory_management/heap_inner.webp"
caption="Visual representation of the internal structure of the heap."
>}}

### Stack

The complexity of the heap allocator comes from its requirement to support the per-block free operation. Due to this constraint, it must track blocks per superblock in order to coalesce them, and reference free blocks in order to reuse them.

For some use cases, the free per-block operation may not be necessary, only a global free or a free of all blocks allocated after a particular moment. This is the base idea of the stack allocator, a very simple and fast allocator. It will receive and track superblocks in allocation order, the last one being the one with available free memory, while all blocks afterwards are considered full. Each superblock tracks its non-allocated zone like slab superblocks, and allocates blocks at the start of their non-allocated zone.

The stack allocator’s algorithm is the following :

- **Allocation** (size \\(N\\)) : if the last superblock has enough free memory, allocate a block at the lowest possible location in it. Otherwise, tag the superblock used, allocate another and allocate in it.
- **Get-position** : return the insertion position of the last superblock.
- **Free** (position) : find the superblock the position belongs to, free all further superblocks, set the non-allocated zone of the superblock from the position to the superblock’s end, set the superblock as the last superblock.

#### Trade-offs of the stack allocator

- Supports all sizes that fit in a superblock.
- Block free not supported.
- Atypical allocation method.
- No block header -> no extra memory consumption.
- No block header -> aligned allocation can be easily achieved.
- Fast allocation.

### Secondary memory manager

Now that we overviewed this basic set of secondary allocators, let’s focus on the design principles of a secondary memory manager.

The allocators that we have described all have their trade-offs in terms of operations support, speed and overhead, and as detailed in part II of this article, secondary allocation can be split in different types :

- **small blocks** : \\([1B, cache line size ]\\) : frequent use (96% of allocations), many use of all many allocation sizes, must be fast, no superblock allocation issue due to the frequent usage of all sizes.
- **intermediate blocks** : \\(]cache line size, page size]\\) : infrequent use (4%), uses a few allocation sizes, can allow trading performance for avoiding superblock fragmentation.

For small blocks, the most efficient choice to make seems to be the use of a slab array with a small size step of for, based on our use case data, 8 bytes. The allocation will then well fit our program’s expected behavior, and as stated before, superblock fragmentation will not be a problem, as the huge amount of allocation will hugely reduce the probability of the rare use of a particular block size.

Though, if superblock fragmentation becomes a concern for the designer, given a different program behaviour, the size step of the slab array can be increased, reducing the total number of slabs and concentrating multiple allocation sizes on one slab. This will, though, increase the internal fragmentation of blocks. Again, this is a trade-off that depends on the target system’s behaviour.

For intermediate blocks, the strategy to employ is more dependent on usage constraints.

If the memory manager is the one of a kernel, that is, a system with a large amount of physical memory available, superblock fragmentation may not be an issue, and the designer may choose to use also a slab array for intermediate blocks. But this time with an order step to avoid an enormous and unnecessary amount of possible block sizes.

Intermediate block sizes will then be rounded up to the closest power of two, and a block of this size will be allocated by a slab. This provides fast allocation time, with low superblock fragmentation (only 5 orders to allocate in a system with cache line order 6 (64B) and page order 12 (4KiB)) but with high block internal fragmentation, due to the rounding to the higher power of 2.

Another advantage in this strategy is that in this configuration (block of size power of 2) the slab can be tuned at low costs to provide blocks aligned on their size, which guarantees that any intermediate block is aligned on its own size.

If the memory manager, on the other hand, is made for a system with a small amount of memory, or for a system with a small number of allocation (ex : process private memory allocator), this choice may not be the appropriate, as alignment guarantees may not be necessary, and intermediate blocks being allocated sparsely. In this situation, using a heap allocator for the intermediate block range may be a better solution, as it mutualists superblocks among all supported block sizes, and avoids internal block fragmentation, though causing a little memory overhead per block, neglectable for this size range.

### Page blocks tracking

One of the interesting features of the secondary memory manager we described in the previous section is to be composed only of sub-allocators that manage their superblocks by themselves.

Put differently, if required, all allocated memory can be freed at once, by simply freeing superblocks used by each sub-allocator.

A corner case, though, concerns the allocation of page blocks, that is delegated directly to the primary allocator. Tracking those allocated page blocks allows to also free them if necessary, extending the aforementioned feature to every allocation type, providing a fully functional and covering secondary allocator.

This causes a small memory overhead (at most one cache line per page size) neglectable compared to the size of a page (< 2%) , due to tracking metadata that must be allocated separately. But this can be allocated internally by the secondary memory manager, thus adding no structural complexity to the defined model.

### Conclusion

This chapter concludes this series on memory management.

After reading this, you should have acquired a solid understanding of the mechanisms involved in system memory management, that transparently occur when an end-user requests a memory allocation or free.

