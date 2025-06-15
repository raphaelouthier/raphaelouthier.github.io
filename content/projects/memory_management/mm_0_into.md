---
title: "Memory Managers : Introduction"
summary: "General considerations on memory and memory managers."
series: ["Memory Management"]
series_order: 0
categories: ["Kernel, Memory Management"]
#externalUrl: ""
showSummary: true
date: 2021-09-17
showTableOfContents : true
draft: true
---

In all articles of this series, sizes of different types of memory blocks will be an important topic.\
To differentiate sizes more clearly, the concept of order of magnitude, or order, will be used as an equivalent qualifier, both concepts being linked by : 

{{< katex >}}
$$
size = 2^{order}
$$
An increment of order multiplying the size by 2.


### Introduction

Memory, although one of the most important resources of any running program, is perhaps, also, one of the least understood.

In most modern languages, an effort is made to take memory management out of the programmer’s hands in an effort of safety and transparency.

Even in low level languages such as C or Rust, memory management, though being accessible to the programmer, is confined to the use of malloc/free-ish primitives, which serve as an abstraction of the host’s memory manager (ex : glibc). \
The memory manager itself is meant to be invisible to the user, which may explain why so many developers are so unfamiliar with memory management techniques, costs, trade-offs, and efficiency.

In this article, I intend to take the radically opposite direction, by providing a simplified overview of different memory management techniques, their objectives and trade-offs, and explore how these different techniques are combined to form a simple kernel-level memory management system.

In this first chapter I will start by defining the basics needed to better understand memory manager design. 

Much of the theory and the designs that I will be describing in this article are a collections the things I have learned by exploring the sources of different kernels, linux on top of the list, reading papers and testing implementations of my own.

I hope this articles will be useful to developers looking for a high level understanding of the concepts behind this truely fascinating domain that is memory management.

I wish you a pleasant read.

### The memory bottleneck

As software developers we, on average, tend to view memory as an uniform resource, with a constant and negligible access time.

To illustrate let me recall an experiment I once did when tutoring a group of programmers:

I presented them with a simplified CPU that would execute 3 types of operations:
- **memory access** (read / write).
- **ALU operations** (int / float sum / diff / div).
- **branch operations** (conditional (or not) jumps.

I then asked the room which type of operations could have the longest execution time.  Nearly all of them chose calculations.

This is what school teaches us, as well as what modern languages give us the impression of.
However, this is also utterly false.

Memory is the major bottleneck of modern computer micro architectures, and has been so since CPU cycle time and memory access time diverged, back in the 90s.

### Cache

In an effort to mitigate this memory access bottleneck, modern CPU hardware designs have introduced a transparent multi-level cache system.

Cache levels store and exchange contiguous memory blocks called cache lines.\
Cache lines have a constant size and are aligned on this size. \
The cache line is the smallest granule a cache can request memory on, and as a result, is the granule at which all operations are executed from the point of view of the external memory.

Consequencently, assuming the memory region isn't already cached : 
- any user memory **read** will eventually cause at least one read of the **whole cache line** from memory to the cache system.
- any user memory **write** will eventually cause at least one write of the **whole cache line** to memory from the cache system.
- any user operation **requiring exclusivity** on a memory segment (ex : atomic operation) will be handled by the cache system. The memory subsytem containing the L1 cache of the core executing this instruction will require the exclusivity on the **whole cache line**.

Additional details :
- [Reducing Memory Access Times with Caches | Red Hat Developer ](https://developers.redhat.com/blog/2016/03/01/reducing-memory-access-times-with-caches?source=post_page-----4f2acc9d5e28---------------------------------------#)
- [How L1 and L2 CPU Caches Work, and Why They're an Essential Part of Modern Chips | ExtremeTech ](https://www.extremetech.com/extreme/188776-how-l1-and-l2-cpu-caches-work-and-why-theyre-an-essential-part-of-modern-chips?source=post_page-----4f2acc9d5e28---------------------------------------)

### Page and Frame

Modern systems are equipped with an MMU (Memory Management Unit) that provides, among others uses, memory access protection and virtualization capabilities.

In such systems, two different address spaces are to consider :

- **virtual address space** : the address space accessed by programs (processes or kernel). Appart from the very early stages of boot nearly all code is using virtual address space.
- **physical address space** : the address space in which hardware devices are accessible at determined addresses, this includes DRAM, peripherals like UART, USB, ETHERNET, Bus interfaces like PCIE, etc…

The relation between virtual and physical address relies on two concepts :
- the partition of both virtual and physical address spaces in blocks of constant sizes called pages (typical smallest size of 4KiB), aligned on their size.
- the definition by software of a set of translation rules, that associate at most one physical page to each virtual page, called a Page-Table. The MMU is used when it needs to translate a virtual address into a physical address. In paractice, to speed up these translations, local copies of previous translation results can be stored locally in the CPU within TLBs.

The **page order** \\((log2(page size))\\) is a hardware constant, and cannot be changed.

Though, the operating system may require, for its own reasons, to work on a larger base block.

It will then define another block called a **Frame**, that will contain a power of 2 number of pages.
In practice, a frame is simply a block of pages abstracted by the OS.

Though this mechanism may be interesting, it will not be detailed in this article. I will, for the sake of simplicity, consider in the following part of the article that pages and frames as the same entities.

Additional details :
- [Paging and Segmentation | Enterprise Storage Forum](https://www.enterprisestorageforum.com/hardware/paging-and-segmentation/?source=post_page-----4f2acc9d5e28---------------------------------------)
- [The Translation Lookaside Buffer (TLB) | Arm Developer](https://developer.arm.com/documentation/den0013/d/The-Memory-Management-Unit/The-Translation-Lookaside-Buffer)

### Access Time

To estimate the time of a memory access, it is necessary to estimate the access time for all cache levels. And to estimate the average access time in a program, it is necessary to know the size of all cache levels and have some notions of each of the cache’s replacement policies, to be able to guess at which level the access might hit.

As such, this estimation is highly unreliable, a better estimation can be made by profiling the execution of the code or by using tools like cachegrind that simulate a cache hierarchy. Though still not exact, these can help the developer in making its software design choice and help evaluate the chosen development paradigms.

To illustrate how wide the differences in memory access times are between cache levels, let me provide indicative values for their access time in CPU cycles and typical size. These numbers are not meant to be taken literally, but rather, serve to show orders of magnitude.

<div style="text-align: center;">
Registers : ~ 256B, ~1 cycle.

L1 cache : ~ 64KiB, ~ 4 cycles.

L2 cache : ~ 512KiB, ~ 20 cycles.

L3 cache : ~ 4MiB, ~ 100 cycles.

RAM : ~ 8GiB, ~ 200 cycles.
</div>

The following thread provides a more detailed comparison to a real CPU benchmark :
- [Approximate cost to access various caches and main memory | Stack Overflow](https://stackoverflow.com/questions/4087280/approximate-cost-to-access-various-caches-and-main-memory?source=post_page-----4f2acc9d5e28---------------------------------------)

With this in mind, in order to make a program as efficient as possible, the two fundamental rules will be :
- To reduce as much as possible the amount of memory accesses.
- If possible, increase spatial and temporal locality, i.e. to generate accesses at memory locations close to previous ones and not long after their use.

### System constraints : NUMA

NUMA (Non Uniform Memory Access) is a qualifier for a system where the physical memory access latency for a same address depends on the core the access originates from.

For example, in such systems, there may be multiple primary memory banks, located at different places in the motherboard, and multiple cores, also located at different places.

To simplify the management of these systems, we can conceptually group memory banks and cores in sets that we will call node (linuxian terminology), the node of a core and the node of a memory bank being the only factors taken into account when considering the latency of the core/bank access.

In all this series, we will place ourselves (and our allocators) in a NUMA system.\
ie: a system with :

- One or more cores, i.e. processing elements, cpus…
- One or more blocks of primary memory, i.e. primary memory that is provided as-it in the system (eg : DRAM), mapped in kernel address space and accessible by all cores of the system, but with a latency that may depend on the core (see *node* below).
- One or more nodes.

In this system, the first objectives of our memory manager is to :

- Reference primary memory blocks of each node.
- Provide a primary memory allocation / free interface to each core.
- Ensure that memory allocated to a CPU is as close as possible to this CPU.

Additional details on NUMA :

- [What is NUMA ? | The Linux Kernel documentation](https://www.kernel.org/doc/html/v5.0/vm/numa.html?source=post\_page-----4f2acc9d5e28---------------------------------------)
- [Non-uniform memory access | Wikipedia](https://en.wikipedia.org/wiki/Non-uniform_memory_access?source=post_page-----4f2acc9d5e28---------------------------------------)
- [Understanding NUMA Architecture | LinuxHint](https://linuxhint.com/understanding_numa_architecture/?source=post_page-----4f2acc9d5e28---------------------------------------)

### Fundamental orders

Now that all these bases are laid, there are some fundamental orders that must be understood and kept in mind when talking about memory management :

- Byte : order 0, constant.
- Pointer : order ~ 2 or 3 (= 4B or 8B), depends on the size of the virtual address space.
- Cache line : order ~ 8 (= 64B), depends on the cache management system.
- Page : order ~ 12 (= 4KiB), depends on the granularity of the page-table.
- Primary memory block : order ~20 to 30 or more (1MiB -> 1GiB or more). 

{{< figure
src="images/memory_management/page_order.webp"
alt="really cool diagram that I made"
caption="Visual representation of the fundamental orders of memory sizes"
>}}

### Allocation types

Now that orders are defined, we can also consider some fundamental allocation types, which will help us classify allocators, and each's objectives:

- **small blocks (< cache_line_size)** : frequent allocation, used for a huge part of object allocations (average size of malloced structures = 60 bytes), must be fast, small blocks must respect the fundamental alignment.
- **intermediate blocks ( < page_size)** : least frequent allocation, used for larger structs, may not be fast. Intermediate blocks must respect the fundamental alignment.
- **page ( = page_size)** : very frequent use by the kernel to populate page-tables, usage by secondary allocators as super blocks, must be very fast. Pages must be aligned on the page order.
- **page blocks** : contiguous page blocks, used by secondary allocators, less frequent. Page blocks must be aligned on the page order.

### 🐔 & 🥚 problem 

Primary memory management is a difficult problem, because it cannot require the use of any other allocator, as it is **THE** first allocator, the one managing primary memory, which is provided as-it.

Moreover, it cannot use the memory it manages to store allocation metadata, simply because one of its jobs is to allocate pages that must be aligned on a page size.

Storing for example 64 bytes of metadata between each page would cause a memory loss of 4096–64 bytes of data which defeats the purpose.

{{< figure
src="images/memory_management/cache_line.webp"
caption="To scale, illustration for the unused memory problem when storing metadata on one cache line."
>}}

A good approach to design such memory manager is to observe the following :

- Solving the page block allocation problem solves the page allocation problem.
- If the page block allocation problem is solved, then the resulting allocator can be used to provide page blocks (superblocks) to other allocators that will handle the allocation of small and intermediate blocks. Those will receive superblocks and use them to allocate blocks of inferior size.

We then define two categories of memory allocators :

- **Primary allocators** : manage primary memory blocks, allocate page blocks in it.
- **Secondary allocators** : manage superblocks provided by primary allocators, allocate smaller blocks in it.

The anatomy of a primary allocator, (the buddy), and of several secondary allocators will be detailed in further chapters.

### Crossing accesses

I stated before that the base granule for memory operations is the cache line.

Now, let’s examine the following C code, and let’s imagine that compiler optimisations and registers do not exist :

```C
int main() {  
  /* Part 1. */
  char i = 5;
  long int j = 5;  
  /* Part 2. */
  char t[16] __attribute__((aligned(8)));
  *(long int *) (t + 1) = 5;}
```

Let’s focus on part 1 of this code: the compiler will have to generate two memory writes (no optimisations) for your two of variables, storing data to the stack.

One of those memory writes will concern a char (1 byte), and the second will concern a long (size depends on the architecture, let’s say 8 bytes). The compiler is not crazy, and will not generate 8 consecutive 1-byte write instructions, rather, it will generate one 8-bytes write instruction.

Let’s now observe part 2: we defined a char array of 16 bytes on the stack, whose first element’s address is aligned on 8 bytes (\_\_attribute\_\_(…)), and in practice, will be located at, for example address 56. This will cause the compiler to generate a 8-bytes access starting with a one byte offset, in our case, from the address range 57 to 65.

For the record, it is explicitly mentioned in all the C language standards that this type of pointer casts has an **undefined behaviour**.

Now if we suppose that the cache line size of our system is 64 Bytes, we just generated a memory write that spans across two cache lines : the first part from 57 to 63 (on cache line ranging from addresses 0–63), the second from 63 to 64 (on cache line ranging from addresses 64–127), this type of access being infamously known as an unaligned access.

Unaligned accesses may carry a severe penalty and are generally something to avoid generating, as it may lead to undefined behaviours. The example we described was fairly simple, and the answer “ yeah I don’t care generate two accesses instead of one ”, could fly between programmers, but not make the CPU designers happy.

But if an access can cross cache lines, it can also cross a page boundary and can concern two virtual pages that can be mapped to two different physical pages with different access privileges and cacheability (another attribute held by the page table).

So what to do now ?

Worse, the access could cross a mapped boundary, and concern one virtual page effectively mapped to a physical page, and another that is not mapped to any page.

What to do now ? Generate half the access, and not the other ? Generate none ?

Worse, the access could be an atomic instruction that requires the exclusivity on one cache line, which is a hell of a heavy work for a CPU. Now to support it, it has to require the exclusivity on two cache lines and split the access. Congratulations, you have successfully turned the unhappy CPU designers into your sworn enemies.

Some architectures like the old ARM processors (ARMV4T) did not support unaligned accesses, others tolerated it but trapped them (generated a fault when occurring), or profiled them so they could be reported to the respectful developer. The safest certainty we have is that they should be avoided if at all possible. As a matter of fact, the C compiler never generates any unaligned access, unless using implementation-defined behaviour (as we did in my example).

I personally had the unpleasant experience of observing that some implementations of the C standard library actually generated such accesses (particularly in functions like memcpy or memset, by uncarefully extending the copy / write size), but patches seem to be in the works for those.

Additional reading :



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
- **curl** : data providers like polygonio provide rest-ful APIs to query the actual data. This implies that you must either use libraries like curl or re-code them yourself, which was definitely out of **this** project's scope. It kinda did hurt, but I installed libcurl...
- **broker APIs** : brokers like interactive brokers saw the automatic trading trend coming and created dedicated libraries to allow you to procedurally do brokerage-related actions like create and manage orders, get your portfolio composition, etc... Those libraries are rather complex and recoding them in pure C would be too risky (order passing is sensitive !) and useless. In the broker chapter I will discuss the way to have a pure C self-contained code interact properly with those brokerage systems.    

## Introduction
 
First, let's state the limits of this project. I am not a trader, I am a kernel engineer. I am an outsider to the financal world, as such I recognise that the investment strategies I can come up with would be naive and of poor quality compared to industry standards.

I know that writing processes and apps can be relatively easy. But coming from the kernel world, I am also have a keely aware of how complex handling shared ressources properly, let they be access simulanously or not, along with the costs intrensic to the chosen solutions. Since the kernel absctracts these away from user space processes, it is easy to miss them when working from a purely a user space perspective. 

Hence, my objective with this implementation was less so to implement a powerful investment strategies, and so more to design the infrastructure that would allow me to easily implementat and efficienty execute these investment strategies. 

But enough with the warnings, let's get started.

## Banalities

First let's state the very basic objectives of our trading bot.

Base objectives :
- **observe** the variations of different instruments in real time.
- **trade** based on those variations in the least money-loosing way.

## Limitations


### I am not a trading company

First, I am just an individual investor, running code from my computer (or a server) not directly connected to any exchange.


That has the following implications :
- 1 : real time orderbook feed will not be available. We must use an aggregated data feed, which averages instrument prices over a base time slice. It could be any time duration, like a second, a minute, at day, etc... Though a smaller period would mean the need for more storage, it would give me the adentage of having more info on which to base a trading decision.
- 2 : this data feed will come from a dedicated data provider like polygonio. That implies that we do not have that much choice in the data feed period. Most data providers provide data on a minute basis. This will be the base period that we will use to architect the system. 

For every minute, each instrument will have the following info :
- **mid** : minute index, identifier of the minute, i.e number of minutes between this minute and Jan 1st 1970 00:00:00. 
- **vol** : cumulated volume of all transactions for this instrument in this minute.
- **val** : average of transaction prices for this instrument at this minute, weighted by transaction volumes.


### Latency

The second limitation is that the bot will be running only on CPUs (no hardware acceleration like FPGA), and given what we already stated, will only be able to trade based on a per-minute data feed, which will imply a gigantic reactivity time of one minute.

A consequence is that we cannot utilize and of the methodes more sofisticated market participants can get an aventage from like : 
- anything that requires reconstructing the orderbook. 
- anything that is remotely latency critical, as our trading bot will work on the granularity of the minute.

This low reactivity is a fundamental element in the trading bot design that this series of article focus on. 

### Consequences

From my work and other projects, I am very much aware that designing a real time microkernel for embedded systems differs from designing a consumer-facing kernel.

In the same manner, I understand that removing these two limitations would fundamentally modify the structure of the trading bot. 
I also realise, that the problems I faced when doing my design and implementation were noticeably different those that must be resolved in the professional trading world where serves on which the bots run are direcly co-located within the exchange and specialized hardware accelerators is available.
Never the less I believe that this project is a relevant introductory exercise to designing automatic trading systems.
