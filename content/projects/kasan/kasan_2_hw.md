---
title: "Hardware."
summary: "What our KASAN will run on."
series: ["KASAN"]
series_order: 2
categories: ["KASAN"]
#externalUrl: ""
showSummary: true
date: 2023-09-27
showTableOfContents : true
draft: false
---

This article will give technical details on the hardware capabilities used to implement our KASAN.

I'd like to point out that the KASAN implementation is not specific to this chip.
The only features needed for the KASAN to theoretically work are : 
- an exception handling mechanism.
- an MPU.

# The chip

TODO PICTURE.

Let's introduce the development board on which I built the KASAN.

The devboard that my dear wife made for me has :
- STM32H750 processor; featuring 
- a CortexM7 CPU implementing the ARMV7M architecture;
- a Memory Protection Unit (MPU) conforming to the ARMV7M architecture.
- a Floating Point Unit.
- 128KiB of Flash;
- TODO Around 512KiB of RAM.

The MPU is the main component on which our KASAN implementation will be based. It is a needed feature.

# Execution privilleges

A procesor implementing the ARMV7M architecture has two levels of privileges : 
- unprivilleged mode : code running in this privilege level has limited access to the processor system registers.
- privilleged mode : code running in this privilege level has unlimited access to all processor features.

In particular, the CPU starts in privileged mode at reset. Then, it is up to the firmware (kernel) to run threads in unprivileged mode.

Code running in unprivileged mode can do a system call to execute a system handler. This handler will execute in privileged mode. The actual function that will be executed can't be programmed by unprivileged software.

# Stacks

A processor implementing the ARMV7M architecture supports two different stacks :
- the Main Stack, used in handler mode. Stack pointer : MSP
- the Process Stack (should have been called Thread Stack), used in thread mode. Stack pointer : PSP.

The MSP / PSP are aliased to SP. Accessing SP actually accesses the stack pointer active in the current mode (thread or stack).

# Exceptions

A processor implementing the ARMV7M architecture supports the notion of exception : code running at a given time can be temporarily stopped, for another piece of code (a handler) to be executed instead.
When the handler is done (understand : when the handler function returns), the stopped code resumes its execution transparenly.
This mechanism is purely hardware, and serves among other things, to handle system calls and interrupts. 
The piece of code that is executed is called a handler;  when the processor handles an exception, it is said to be in handler mode.
When it doesn't, it is said to be thead mode.
Thread mode can be privileged or not.
Handler mode is always privileged.

An exception has an ID, which is used to determine : 
- if this exception is enabled (i.e. if the handler is allowed to be called at all when the exception is triggered).
- the priority of this exception (i.e if the handler is allowed to be called given the currently excecuted exception, if any).
- the handler to be executed..

The ARMV7M architecture supports at most 512 exceptions.

The ARMV7M architecture defines the 16 first exception IDs as system exception

TODO TABLE.

The (at most) 496 remaining exceptions are interrupts.

When an exception A is triggered, the processor determines the priority of A, so as the priority of B, the exception currently handled by the processor, if any.
If A is enabled and is more prioritary than B (or if the processor is not currently executing any exception), the current execution context is saved in the local stack (either Main Stack or Process Stack) by the hardware, and the handler of A executed.
When the handler of A is complete (when it returns), the processor detects it, and restores the execution context saved on exception entry. Then, the execution of B (or thread code) continues transparently.

# Context.

The ARMV7M context is composed of 
- general purpose registers : 
	- R0 -> R3 : Caller-saved.
	- R4 -> R11 : Callee-saved.
	- R12 : Caller saved, scratch register.
	- R13 : Caller saved, Stack pointer, alias : SP.
	- R14 : Caller saved, Link register, alias LR.
	- R15 : Caller saved, Program counter, alias PC.
- Floating point registers (When FPU is implemented and active) : 
	- S0 -> S15 : Caller saved.
	- S16 -> S31 : Callee saved.
- Status registers : 
	xPSR : composite of all status registers, see the ARMV7M ARM for more details.

# Context saving and exception. 

Saving the execution context means atomically storing a subset of the context registers to the currently used stack (Main / Process).
Restoring the execution context means atomically loading a subset of the context registers from the stack, and as such, updating the state of the processor.
(The loaded subsets and the stored subsets are the same).

In the ARMV7M architecture, This subset of saved/restored registers is composed of all the caller-saved registers and of the program status registers.
This makes the exception entry / return procedures follow the standard ARMV7M calling conventions, and allows us to implement exception handlers using C code only when required (not here lol).

TODO context for both WITH FPU and WITHOUT FPU.

Note : if after a context save, if the stored value of a register is modified, the modified value will be loaded in the register during context restore. This will be the base trick on top of which we will build our emulator.

# MPU

The ARMV7M features an optional MPU, always implemented in the CortexM7.

The MPU for Memory Protection Unit, allows the kernel to define up to 8 or 16 (depending on the implementation) MPU regions, and to define
access permissions for these MPU regions.

These MPU regions must be :
- of a size that is a power of 2 and that is greater or equal than 32 bytes.
- aligned on their size (start address is a multiple on the size).

I will not elaborate a lot on the various access permissions since that would require a chapter of its own. What is important to us is that the MPU allows us to : 
- blacklist a memory block, i.e. prevent the CPU to access this memory block while the MPU is active.
- whitelist a memory block, i.e. allow the CPU to access this memory block while the MPU is active.

The MPU regions are indexed from 0 to N (N = nb_mpu_regions - 1), and have a fixed priority : when determining the access permissions for a byte at address X, if multiple MPU regions (let's say A and B) cover X, then the MPU region with the highest index will be selected to decide which permissions use to access X.

That allows us, for example, to blacklist a large memory block using a MPU region with low priority, and to whitelist smaller portions of this memory block using MPU regions with a higher priority : when an access to one of the smaller blocks will be made, both the whitelist and the blacklist MPU regions will be considered, but since the whitelist MPU region has a higher priority, it will be selected and access will be allowed. This will be the base trick on top of which we will build the memory access trap system. 

