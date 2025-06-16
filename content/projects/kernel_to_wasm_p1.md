--- 
title: "Joys of porting a kernel to WebAssembly, Part 1" 
summary: "In-process kernels, WebAssembly and their difficulties to cohabitate."
tags: ["C","wasm","Emscripten", "Kernel","Web Development", "Webassembly","gnu",] 
#externalUrl: "" 
showSummary: true
date: 2021-10-07 
showTableOfContents : true 
draft: false 
---

# The back story

For as long as I can remember, understanding how kernels were designed and
written was something that has interested me.

In the beginning, a newcomer to the world of programming, I saw them as
mysterious, incredibly complex and barely comprehensible software blocks,
handling equally mysterious tasks in the execution of a program.

A few years later, after having perfected my skills as a programmer, I dived
into the concept with a new perspective, and discovered the real issues that
required the use of kernels and the possible implementations choices that solved
these problems.

Afterwards, I did what every normal programmer would do in my situation and
spent more than the next half decade implementing my own one.

Last year, I discovered WebAssembly, an Intermediate Representation allowing the
deployment of C software in a web-browser. In order to make this port possible I
had to update a part of my code base to support WebAssembly, and it was within
that context that I set upon myself the challenge of :
> porting the kernel to the wasm environment.
WebAssembly and its related toolchain, Emscripten, have done a very respectable
work in providing support for C99 with gnu extensions (ex : constructs like
({statements})), allowing regular C libraries to be ported without any issue.

Yet, I encountered my fair share of interesting issues when porting my kernel to
this environment. After all, kernel’s are quite far from the simple
standard-compliant C code, and as such forced me to push to the boundaries of
the emscripten wasm toolchain and get familiar with it’s nooks and crannies.

This article’s aim is to describe these difficulties in more detail and hopes
to, in the process, give you glimpses of how kernel’s on one hand and the
emscripten toolchain, on the other, work under the hood.

I will start this article by briefly introducing Webassembly, and I will then
tell you more about the main needs that pushed me to implement my own kernel,
and in doing so, I will give a short description of its main blocks. Following
this, I will provide a more detailed look at the Emscripten toolchain, to expose
a corner case that forced me to reimplement a part of the kernel’s init
procedure to support WebAssembly.

# Web-browsers and Javascript

Historically designed to render statically defined text-based pages,
web-browsers have drastically evolved to the point we know, being nowadays
having more in common with actual Operating Systems than simple page renderers.

Web-browsers getting more and more complex and varying in their implementations,
and web-designers desiring to avoid as much as possible taking the execution
browser brand (firefox, chrome, …) into account during development, it was
central to provide a stable common API. Javascript rapidly took this place, the
Javascript VM now being one of the central components of a web-browser.

Javascript being an interpreted complex language, its execution performances
rapidly showed their limits, even with JIT features enabled. In a world where
Moore’s law applies, this may not seem like a real issue, as the assumption that
the next generation of computer will provide enough performance increase to
compensate for this slowness. Though, in our years where this law clearly
started to present its validity limits, this issue had to be addressed.

# WebAssembly

Webassembly is a relatively new (2017) trending IR (Intermediate Representation)
code format designed to be loaded and interpreted, translated or JITed in, among
others, web-browsers.

{{< figure
src="https://upload.wikimedia.org/wikipedia/commons/1/1f/WebAssembly_Logo.svg"
alt="Wasm logo" caption="Wasm logo"
    >}}

An intermediate representation is, as the name states, a manner to represent a
program that doesn’t aim to be directly executed, but rather :

- to serve as storage or exchange format.

- to be interpreted efficiently by a wide range of program processors
  (compilers, VMs etc…), to be either translated into other formats (ex : actual
assembly) or directly executed.

WebAssembly is, as a consequence, not a programming language (though the textual
version may be used this way), but rather an object format that compilers may
use to store the result of their compilation, and that a virtual machine may use
as executable source.

This allows a possible wide range of programming languages to be compiled into
it, for example C or Rust for the most widely known.

Though its reputation may be tainted due to its strong use by web hackers to
inject (among others) crypto-mining payloads in client side, webassembly remains
a good option for porting C libraries in the Web world.

# Kernels, or the need for environment abstraction layers

As any software engineer I aim to write _“good”_ code.  Naturally, pretty fast,
the problem of defining what _“good code”_ is arises.  After all, given a choice
between multiple possible implementations, it would be best to have some
criterion.

Though I recognize that these criterion are not universal, in my implementations
at least I now consider 4 performance indicators that I have listed them below
in decreasing importance :

- **portability** : the code must be compatible with the widest scope of
  environments.

- **functionalities** : the code must offer an answer to the most general
  problem.

- **memory consumption** : the code must use the smallest amount of memory,
  considering the previous rules.

- **execution time** : the code must run as fast as possible, considering the
  previous rules.

I wish to once more remind the reader that these criterion are completely
subjective, and are only the reflection of my experience and my objectives.

It is certain that real-time software engineers would have radically different
guidelines, and would, for example, place execution time invariability, or
avoidance of linked lists traversals inside critical sections, on top of their
list.

But let us go back to my criterion.

Generally, I tend to place code reusability across use-cases and environments
among every other requirement.

When I say environment, I mean the platforms (x8664, x8632, arm32, aarch64),
host OS (freestanding, linux, windows, mbedOS) and toolchain (gcc, llvm).

This means that the code I write must be as independent as possible of the host
API its executable version will access.

Having this constraint implies defining standard custom APIs for the most basic
host requirements of a program :

- **host memory access** : ex for stdlib : `malloc`, `free`.

- **host memory mapping** : ex for linux : `mmap`, `mprotect`, `munmap`.

- **host file access** : ex : printf, for linux : `open`, `close`, `read`,
  `write`, `seek`.

- **host directory access** : ex for linux : `readdir`, `closedir`, `seekdir`.

- **threading : ex for linux** : `pthread` environment.

# The need for freestanding implementation

To achieve the aforementioned code reusability objective, in a classic hosted
environment defining a simple function indirections (static inline functions or
macro aliases in a shared header) will do the job.

That being said, as an embedded software engineer, my primary environment
targets are freestanding (without OS, bare-metal) systems, not hosted ones,
which complicates the problem.

Though, it is still possible to use frameworks for those freestanding systems,
that would provide some semblance of a standard environment. The Arduino
framework, being one example, offers a default standard for low-performance
embedded systems. In this case the previous simple solution would still be
viable.

But, after a more thorough examination and more experience with these frameworks
I have started to have several objections regarding their use :

- **code quality** : a simple look in an Arduino framework implementation is
  enough to leave one, at best doubtful, at worst frightened by the code quality
and the apparent absence of debugging efforts.

- **code performance** : for example, the quality of the memory management
  system may be weak, which could lead to memory allocation poor performances,
which could impact the whole program.

- **missing features** : platforms like the teensy35 (a platform nevertheless
  close to my heart as it was my entry point into embedded systems and my
hardware of choice for a few years) is based on a cortex-m4f based on the ARMV7M
architecture. As such, it features all of the architectural components required
to implement a context-switch based mono-core threading API. Yet, the Arduino
framework is primarily made to provide an uniform API for extremely low-power
cores like AVR8 chips. As such it doesn’t provide a satisfying threading API,
and so, if an implementation is required, it must be implemented manually.

- **language constraints** : the Arduino framework is written in C++, which
  doesn’t ease the development of pure-C applications.

As a consequence, for freestanding systems, it becomes a necessity to have an
available working implementation of the basic code blocks to support at least :

- memory allocation.

- memory mapping (if any).

- file access.

- threading.

And those blocks happen to be the minimal blocks needed for a kernel.

#The need for code compatibility between freestanding and hosted environments

Hosted and freestanding environments are different in many ways, but, most
probably the most painful difference between the two for any programmer is the
difference in debugging capabilities.

On the one hand, debugging on a hosted environment (ex : linux process) is very
easy and fast. Tools like <mark>valgrind</mark> are extremely versatile, easy to use and can
allow the developer to have an exhaustive list of all invalid accesses, memory
leaks, uninitialized accesses, without requiring any additional instrumentation.
Program faults are handled by the host and faults’ side-effects are reduced, as
the host will close any used file, resource, etc…

On the other hand debugging on a freestanding environment is much more of a
headache and may require a particularly expensive instrumentation (the most
well-known toolkit being the Segger’s J-Link) to set up a gdb server, in the
best case.

An invaluable tool like valgrind being a simulation-based debug tool, it only
supports its host’s instruction set, and as such can’t be adapted to this
environment. As such our debugging capabilities are greatly reduced.

Memory leaks will be harder to detect, uninitialized accessed will be
untraceable.

Program faults may be fatal, if not handled properly, as they may put the
program in an unsafe state. Worst, if the related program is a controller for
physical objects, may lead to erratic behaviours with repercussions in the
physical world, which may be inconvenient if not harmful.

As a consequence, we have two complementary environments, one that depends on a
safe and verified code but can’t provide ways to verify it, and another that
provides such ways, but for which the consequences of not having a dependable
and verified code are much lower.

As such we can make up for the shortcoming of the freestanding environment by
making the code as much platform-independent as possible. This allows for a
rigorous stress-testing and debugging of shared code via standardised, powerful
and robust tools in the hosted environment, and safe deployment of this verified
code on freestanding platforms.

# A simple user space kernel

Though the definition of what is and what is not a kernel may be a subject of
debate, I believe the best definition to start with is the following :

> a kernel manages shared resources in a system.

Those resources may be :

- cores.

- Tasks (and threads and processes).

- Executables, the kernel executable at first, then possible dynamic libraries
  and modules.

- Memory.

- Peripherals.

- Files.

More generally, a kernel aims to manage any shared resources accessible by
multiple programs in a system. The role of the kernel is to supervise the access
to those resources, by providing a consistent API to use them.

Contrary to what is most common for a kernel, my kernel will run in user-space.

Normally kernels do not do this and isolate its threads from itself via the
virtualisation / protection mechanisms offered by MMUs or MPUs. My kernel
doesn’t include this feature as protection mechanisms from the MMUs and MPUs may
be absent on the targeted systems. This can occur when the kernel is run in the
process space on a hosted system (no MMU, may be emulated via linux-KVM if
relevant but that’s another story), or on a cortex-m4f (implementation-defined
MPU capabilities but no MMU).

That aside, the kernel implements most of the features that you would expect to
encounter :

- **BSP** : environment dependent code, provides a standardised API to interact
  with cores, host memory managers, host file manager, etc…
- **Memory manager** : responsible for managing primary memory and to provide
  secondary memory APIs to cores. See my detailed article on this topic.
- **Scheduler** : decentralised system responsible for scheduling tasks on each
  core, and to coordinate the transfer of tasks between cores depending on each
core’s load. Introduces the concept of process, i.e. threads accessing the same
set of resources.
- **Loader** : provides static module initialization capabilities and dynamic
  modules / libraries loading / unloading capabilities.
- **File system** : tracks resources processes can use, manages their access.
- **Resource tracker** : tracks resources used by each process, and frees them
  automatically when the process terminates.

# Modules

The previous section introduced a particular block of the kernel, the loader,
that was in the centre of one of the issues I encountered, the Loader.

It is not my intention to go into details regarding the internals of the loader,
as this would be long enough for an entire article. Yet, as having a clear
comprehension of the concept of modules is essential for understanding the
following sections, we will introduce it.

We can divide the software that will be executed at runtime in two categories :

- **kernel** : contains all blocks previously mentioned, i.e. blocks required to
  manage resources, and to run user code. Kernel code must be linked statically
to form the kernel executable.
- **modules** : code that is not strictly required in the kernel executable, and
  so, that can be **dynamically loaded**.

For example, the file system is a component of the kernel, but the code to
support a particular type of file manager (ext2, ext4, ntfs) can be provided in
a module.

Now that this nuance is introduced, we next need to introduce the concept of
static modules and introduce their use case.

On certain platforms, the RAM memory sections are not executable, this implies
that Writable memory can’t be executed, and so, such dynamic loading is
impossible, as dynamically loading a module means writing it to memory from an
external source, and modifying it (ex : applying relocations) such that it can
access kernel symbols (functions and variables).

In these platforms, dynamic loading will be impossible, and all required modules
should be linked statically to the kernel executable.

On other environments, like WebAssembly, the executable format is atypical, and
dynamic loading may be difficult. Even if a loader implementation for such a
format may be possible, it will require a lot more development effort than what
I was willing to invest. In such a situation statically linked modules there
again seem like a valid option, even if only as a temporary solution.

Another benefit of linking modules statically to the kernel executable is time,
dynamic loading being a complex problem with complex and time-consuming
solutions. Doing the linking work at compile time avoids the need to do it at
each execution.

A module being an implementation-defined executable aiming to have a
user-defined impact on the kernel (for example, to start processes or to provide
support for file system types), it must comprise a function accomplishing the
aforementioned tasks, the module initialization function, that the loader can
find and execute .

This execution will be done at different times, depending on the module type :

- For **static modules**, all init functions of static modules must be retrieved
  at once and executed sequentially, possibly in a particular order.
- For **dynamic modules**, the init function must be executed as soon as the
  module is loaded in the kernel.

Again, what will be of interest here will be the case of static modules.

At a high level the build procedure of static modules in our kernel works as the
following :

- Source files of the same module are compiled independently.
- Source files of the same module are merged to form a single relocatable
  executable, the module executable.
- Module executables are modified, by possibly forcing symbols locality to
  prevent multiple symbols definitions.
- Module executables are merged to form a single relocatable executable, the
  static modules executable.

During this process multiple static modules executables will be generated, each
one having its own initialization function. Later, they will be merged into a
single relocatable executable, and the position of these functions in the
resulting executable may not be known.

Not knowing the position in the executable of each module’s initialization
function will be an issue as, at runtime, the kernel will have to execute each
one of these functions, but the kernel being independent of modules, it has no
knowledge a priori of the location of these functions.

There are two strategies one can use to help overcome this hurdle.

The first, and most common solution involved using the concept of sections,
supported by the elf format. Practically this involves defining for each module
a static function pointer that contains the location of the module’s
initialization function, and placing this variable in a custom section of the
efl. We shall be calling this custom elf section the `.modinit`.

Later in the build process, during the merging of multiple static modules
executables, the linker (ld) will merge the content of sections with the same
name (default behaviour, but can be configured with the use of a linker script),
in our case this means merging into one section the multiple static modules
`.modinit` content. This will cause all our pointers to be located in the same
output section, which in the resulting executable, will cause them to be located
contiguously in memory.

A wisely crafted linker script provided to the linker will define two global
variables, `.modinit_start` and `.modinit_end`, used to help the kernel locate
the start and end of this section, which will allow the kernel to retrieve
addresses of all modules initialization functions needed to execute them.

This aforementioned process is the one that regular executable processes use to
trigger the

initialization and de-initialization of static variables whose expressions need
to be computed at run time.

For more details : [ELF: From The Programmer's
Perspective](http://ftp.math.utah.edu/u/ma/hohn/linux/misc/elf/elf.html)

The second solution, which is in my humble opinion much less elegant and relies
on knowing at compile-time the full list of static modules that need to be
compiled and linked, consists in providing a unique name to each initialization
function (derived from the module name, modules names must be unique), and to
assign a global visibility to this function, then to define a single function
calling each initialization function by name. The kernel then only needs to
execute this function to initialize all modules.

Though being un-clever, this procedure can be done automatically using a bash
script.

In my pre-WebAssembly implementation, I used the first solution. This was only
possible because I had easy access to the standard elf format as I was
developing for the linux environment. But, as we will now observe, WebAssembly’s
constraints on the elf format forced me to review my choice and opt for the
second solution.

In-process kernels, WebAssembly and their difficulties to cohabitate.

The second solution, which is in my humble opinion much less elegant and relies
on knowing at compile-time the full list of static modules that need to be
compiled and linked, consists in providing a unique name to each initialization
function (derived from the module name, modules names must be unique), and to
assign a global visibility to this function, then to define a single function
calling each initialization function by name. The kernel then only needs to
execute this function to initialize all modules.

Though being un-clever, this procedure can be done automatically using a bash
script.

In my pre-WebAssembly implementation, I used the first solution. This was only
possible because I had easy access to the standard elf format as I was
developing for the linux environment. But, as we will now observe, WebAssembly’s
constraints on the elf format forced me to review my choice and opt for the
second solution.

In-process kernels, WebAssembly and their difficulties to cohabitate.

