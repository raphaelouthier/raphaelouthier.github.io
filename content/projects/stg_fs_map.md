---
title: "Disk access, MMU, mmap, a simple overview."
summary: "Explaining what happens when one mmap-s the content of a file."
categories: ["Operating systems"]
#externalUrl: ""
showSummary: true
date: 2025-06-16
showTableOfContents : true
---

## Context

While writing an article about a component of my trading bot, I needed to explain what mapping a file's content in memory actually means, and cover the various performance issues that arise when doing so.

Since this explanation ended up taking more lines than what I originally had in mind and it seemed relevant to other topics, I decided to break this up into a dedicated article.

The original article can be found here :

{{< article link="/projects/bot/bot_2_prv/" >}}

## Introduction

In this article, I will provide an exploration into the banal act of
mapping a file's content to memory. Behind this simple act lies a trove of
hidden complexities that have a very concrete impact on code performance.

Once again, deepening our understanding of how this works also unlocks a new
set of design considerations leading to potential optimization techniques. \
And giving such an overview of this topic is exactly the aim of this article.


{{< alert "circle-info"  >}}
Acronyms used in this article :
- **PA**  will be used as an acronym for "Physical Address", aka the addresses used in actual memory transactions on the bus (see below).
- **VA** will be used as an acronym for "Virtual Address", aka the addresses used by code running in CPUs.

The translation between the two and its impact will be covered in the next section.
{{< /alert >}}

## Storage device management

First, let's cover how the kernel manages storage devices (disks).

**Some facts first.**

Processors are distributed systems with many components, among them :
- multiple **CPUs**, which all need to access DRAM.
- multiple **peripherals** (Ethernet interface, USB interface, PCIE interface) that (in broad terms) are meant to be programmed by CPUs and that in some cases must access DRAM.
- multiple **DRAM** slots.

In order to make this different components interact with each others in an unified way, we introduce another component, the **interconnect**, abusively called "memory bus" in all this chapter.
It's role is to connect them all.
In particular :
- it defines the notion of physical address.
- connected clients can be masters (can initiate transactions), slaves (can process transactions) or both.
- it allows its masters to initiate implementation-defined transactions which target a given physical address. It is a functional simplification to consider that memory reads and writes are particular cases of such transactions.
- it allows CPUs to configure and control peripherals by initiating transactions at PA ranges that peripherals are programmed to respond to.
- it allows CPUs and peripherals to read or write to DRAM by initiating transactions at PA ranges that DRAM controllers are programmed to respond to.

Storage devices like your average SATA or SSD drive :
- are meant to be pluggable and hence have their dedicated connectors and HW communication protocols.
- are not meant to interface with processor interconnects directly. One cannot just make an access at a given PA and expect a storage device to just process this access.
- cannot be accessed at a random granularity (byte, cache line, etc...). The same way the cache system cannot perform accesses at a granule inferior to the cache line, storage devices perform reads and writes at a minimal granularity, the sector size, which is a HW characteristic.
- consequence : accessing the data contained in a storage device (ex : a SATA disk) is made via a dedicated peripheral connected to the interconnect, providing a HW interface to talk to your disk, and requiring a kernel driver to control with this peripheral.

**A high level view.**

Here is a more complex but still extremely simplified view of how we can make code running in CPUs access (DRAM copy of) data located in a disk.

{{< figure
        src="images/bot/prv_fs_dsk.svg"
        caption="Interacting with a hard drive."
        alt="prv fs dsk"
        >}}

Participants :
- IC (interconnect) : allowing all its clients to communicate with each other.
- CPU : executes user code. Interconnect master only for this example's purpose.
- DRAM : the actual memory of your system. Interconnect slave, processes transactions by converting them to actual DRAM read and writes.
- Disk : a storage device that is controlled via an implementation-defined protocol only handled by the storage interface. Not directly connected to the interconnect.
- Storage interface : interfaces the interconnect and the disks. Must be programmed by an external entity to do so. Interconnect slave : processes memory transactions targeting its address range as configuration requests, which allows external entities to control its behavior, for example to power up the disk, initiate a sector read or write (etc...). Interconnect master : forwards disk data to DRAM via write interconnect transactions.

Now, let's describe the different sequences involved to allow CPUs to read data at two different locations on the disk. We will here suppose that CPUs can read at arbitrary PAs, and the next section will complexify this model.

**Step A : storage interface setup.**

The kernel running on CPU 0 does the following things :
- it allocates two buffers of DRAM using its primary memory allocator, in a zone that allows the storage interface to perform memory transactions (DMA16 or more likely DMA32).
- it sends control transactions to the storage interface via the memory bus, to instruct it to perform two disk reads and to store the resulting data at the PAs of the buffers that it allocated.

**Step B : disk reads.**

The storage interface understands the instructions sent by the CPU and starts the disk read sequences. The disk will respond with two consecutive data streams, that the storage interface will then transmit to DRAM using memory bus transactions (DMA).

Once the reads are done, the storage interface notifies the kernel of their completion by sending an IRQ targeting one of the CPUs.

**Step C : CPU access.**

Now that DRAM buffers have been initialized with a copy of the data at the required disk locations, CPU can read those buffers by simply performing memory reads at PAs within buffers A and B (provided that they have invalidated their caches for the memory ranges of A and B).

Now, an immediate consequence of what we covered here is that CPUs _cannot_ modify the data on disk themselves. All they can do is to modify the DRAM copy.

If updates need to be propagated to disk, the kernel will need to initiate another transaction (a disk write this time), instructing the storage interface to read from DRAM and write data to disk.

From userspace, this is typically initiated via fsync or msync.

## MMU, virtual address space

In the previous section, we assumed that the different CPUs in the system could write to arbitrary PAs.

The reality is more nuanced, as PA access is critical :
- first, allowing any userspace process to access any PA basically allows it to read any other process's data. Just for security reasons, we can't let that happen.
- then, we saw in the previous sections that some PAs correspond to HW configuration ranges, and if mis-used, can cause HW faults which often just make the system immediately panic. For practicality, we also cannot let that happen.
- finally, most programs are not meant to deal with PA itself. Physical memory management is a critical task of the kernel, and physical pages are usually allocated in a non-contiguous manner, on a page-per-page basis. Programs often need to access large contiguous memory regions (like their whole 4MiB wide executable), and hence, have needs that are incompatible with how physical memory is intrinsically managed by the kernel.

For all those reasons and others, code running on CPUs (whether it be kernel code or userspace code) does not operate with physical addresses directly.

Rather, it operates using virtual addresses, which translate (or not) into physical addresses using an in-memory structure that SW can configure but whose format is dictated by the HW, called a page table. Every CPU in the system is equipped with a Memory Management Unit or MMU, which translates any VA used by the CPU to the corresponding PA.

This article will not dive into the format of the pagetable, but here are a few facts worth mentioning :
- VA->PA translation is done at the aligned page granule. Virtual memory is divided into pages of usually 4, 16 or 64 KiBs and each virtual page can map to at most one physical page. When I say map to, understand 'set by the pagetable content to be translated to'
- multiple virtual pages can map to the same physical page.
- the pagetable contains the translation data and also attributes like translation permissions (can data be read, written, executed, and by who ?) and cacheability.
- the pagetable is dynamically writeable, but usually by privileged software (kernel) only.

Now let's add some details on how the CPUs will need to map memory to perform the various transactions described in the previous section :
- to program the storage interface, CPUs will need to map the PA region corresponding to the peripheral's control range into a range in their virtual address space (in reality, into the kernel's virtual address space which all CPUs use in kernel mode), and perform memory accessed from this virtual range. The mapping will be RWnE (read/write/non-execute) and non-cacheable, as we want the control transaction not to be affected by the CPU's cache system.
- to read from and write to DRAM, CPUs will again need to map the PA regions corresponding to the buffer A and B into the kernel's virtual address space and perform their accesses from this virtual range. The mappings will be cacheable, but a few precautions will need to be taken to ensure that reads see the data written by the storage interface, and that reads by the storage interface (during disk writes) see the writes made by the CPU :
  - before reading data written by the storage interface, CPUs will need to invalidate the ranges for buffers A and B, so that when they read at those addresses, data is re-fetched from memory.
  - before instructing the storage interface to write to disk, CPUs will need to flush the ranges for buffers A and B, so that the writes made by CPUs are propagated to memory and observed by the storage interface.

To illustrate, here would be how the translation summary would look like for _just_ our example. Here we assume that we have 4KiB (0x1000b) pages, a 3 bytes virtual address space (0x1000000 bytes of addressable VA), a 2 bytes physical address space (0x10000 bytes of addressable PA), among which :
- the 7 first pages are mapped, and the remaining part of the PA space is not mapped.
- the storage interface responds to transactions targeting the first page of PA.
- the DRAM controller responds to transactions targeting the 4 next pages of PA.
- another peripheral, the UART, responds to transactions targeting the next (and last) page of PA.

{{< figure
        src="images/bot/prv_va_pa_trs.svg"
        caption="Translations in our example."
        alt="prv sync"
        >}}

As one can expect :
- one VA page maps the control range of the storage interface, and is used by CPUs to configure it to initiate disk transactions.
- two VA pages map buffers A and B (let's assume that they are page-sized) who are located in DRAM, so that cpus can read and write the DRAM copy of the disk data. Note that both buffers have non-contiguous PA and VA locations.
- No one maps the UART.

> The attentive reader may ask : how are CPUs executing any code ?
Indeed, code resides in memory somewhere in PA and hence, needs a dedicated VA mapping for CPUs to read it.
In an effort to keep this diagram simple, I did not add this info, but in reality, there should be DRAM pages allocated to contain code, and a contiguous VA region that maps those PA pages.

An important notion to remember is that if two CPUs run two user programs that want to access the same region of disk data, the CPUs may map exactly the same physical pages (buffers) allocated by the kernel under the hood. Or they may map different copies transparently made by the kernel. The next section will cover the modalities of this system.

## MMAP

So far, we know that :
- the kernel handles storage operations (disk reads and writes) transparently on behalf of users, by allocating buffers and initiating disk read and write to / from those buffers via one of its drivers that interacts with the storage interface.
- Upon completion of disk read requests, userland code can access those buffers by instructing the kernel to map those buffers in the user's virtual address space.

This section will elaborate on the second part.

There are two ways for user code to access disk data :
- file operations like read, write, readat, writeat, et al. Those operations involve invoking the kernel and do not scale well in practice.
- mapping the buffers managed by the kernel to contain disk data in userland and let user code read and write freely.

We will focus on the second method, and in particular, in the way users can configure the mapping made by the kernel.

The main system call to map a file into userspace is mmap. It involves the following steps :
- user code makes an open call to open the proper disk file and acquire its (shared) ownership.
- user code calls mmap with chosen parameters so that the buffers managed by the kernel are mapped into its virtual address space.

Note that the kernel does not necessarily need to read the entire disk file and populate all the DRAM buffers to contain all the file's data.
Rather, it can choose to defer the disk reads to when the user code needs it : it will allocate a VA region of the size of the file in the user's virtual address space, and let the VA pages unmapped. When the user code will access those VAs, the HW will generate a translation fault, which will be handled by the kernel. The kernel will then put the user code to sleep, perform the disk read, and upon completion, resume the user process execution at the instruction that originally faulted.

Mmap takes the following parameters :
- permissions : condition the way user code can access the mapped data :
  - readability : if readable, the user can perform memory reads on the mapped VA region; if not, it cannot.
  - writeability : if writeable, the user can perform memory writes on the mapped VA region; if not, it cannot.
  - executability : if executable, the user can branch to the mapped VA region and execute its content; if not, it cannot.
- shareability : condition if the running process sees disk writes from other programs and vice versa.
  - private : the process sees its local copy of the file. It behaves exactly as if the kernel had read the whole file at map time and the user process was mapping this copy. In practice this is more nuanced than this, as copying (potentially GiB-wide) files results in a huge memory consumption. The kernel likely implements Copy-on-Write (CoW) mechanisms to reduce the memory cost. Writes to this private copy will not be (natively) propagateable to disk.
  - shareable: the process uses the kernel shared buffers and no private copy is used. Updates to those buffers will :
    - be visible to any other process mapping the same buffers (i.e mapping the same portion of the same file) at some point.
    - be propagated to disk when msync is called.

> It is typically considered a security vulnerability to leave a VA range WE (write + execute) as it allows an attacker with write capabilities to escalate into arbitrary execution capabilities.

> This article will not elaborate too much on how CoW works, but here is a simple (and probably suboptimal) way it can be achieved : when a process maps a file in private and this file is mapped by other processes, the kernel first disallows any writes to this file's shared buffers, then maps those in the process's virtual address space.
Any write to those buffers (by anyone) will generate a translation fault which the kernel will handle by effectively duplicating the buffers, and map the copy in the virtual address space of the process that required private access.
Other processes keep the shared buffers mapped.
Once that's done, buffer writes are allowed again for both shared and private buffers.   

## Performance considerations

The two biggest performance factors to consider when mapping a file are :
- do we need to write to the file ? If not, then we can map as readable and simplify the kernel's life, as it is guaranteed that we never modify the mapped buffers, which reduces its CoW implementation.
- do we need to work on our local copy of the file, or is it acceptable to :
  - observe updates made to the file by other entities.
  - have our own updates observed by other entities that map this file as shareable.

If we choose to access the file in shareable, we have to deal with the following performance issues :
- If someone else maps the same portion of the same file in private, we could see a perf hit when writes are performed for the first time on a page, due to the kernel's CoW implementation.
- If us and a remote entity access (read or write) the same locations, then the CPU's cache system needs to synchronize those accesses, leading to real-time perf hits. Any multiprocessing system where entities map the same underlying physical pages must be designed in a way that minimizes the simultaneous access to those pages, or be prepared to pay a big performance cost otherwise.

If we choose to access the file in private, we have to deal with the following performance issue :
- If someone else maps the file either in private or in shareable, then the same buffers may be mapped (via the kernel's CoW system) and we may experience random perf hits when us or another processes mapping the file writes to a CoW buffer.

