---
title: "KASAN structure."
summary: "KASAN in details."
series: ["KASAN"]
series_order: 3
categories: ["KASAN"]
#externalUrl: ""
showSummary: true
date: 2023-09-27
showTableOfContents : true
draft: false
---

This chapter will describe the basic principles of operation of the KASAN. 

# Structure

The previous chapters laid the foundations on which we will build the kasan :
- we cannot use any transpiling-oriented method to wire our kasan due to potential code size increase.
- we have an MPU that can trigger a memory fault whenever a specific portion of memory is accessed.
- the handler of this memory fault can modify the interrupted code's stack context to modify the register values, and to alter its control flow.
- the memory fault handler gives us the location of the fault, so as the address of the instruction that generated the fault.

To implement our kasan, we will first use the MPU to disable access to the whole RAM region.

That will cause any access to any RAM to fault, and the memory management fault handler to be executed.

The memfault handler will save the part of the context that hasn't been saved by the HW somewhere in memory for the emulator (defined below) to retrieve it later.

The memfault handler will then read the PC of the instruction that caused the fault, read the instruction and decode it.

It will then check that the related instruction is a memory access. If it is not one, it will just execute the classic memory fault exception.

If it is a memory access, it will emulate the instruction and perform its checking in the meantime.

This is a complex task and will require a chapter of its own, and this will be the place where the memory checking is done. It involves :
- decoding the instruction.
- verifying that every access performed by the instruction is valid.
- updating the kasan memory metadata to reflect the new state caused by the memory access (ex : write to an uninitialized location causes the location to be treated as initialized in subsequent accesses to that location).
- emulating the instruction, by performing the underlying accesses : 
  - register reads will cause the emulator to read the context-saved values.
  - register writes will cause the emulator to write to the context-saved values.
  - memory reads will cause the emulator to actually perform the read now that the MPU is disabled.
  - memory writes will cause the emulator to actually perform the write 
- if the instruction emulation is successfull, modifying the PC that will be restored when the exception will return, so that the instruction after the one that just was emulated is executed at that time, and not the one that we emulated again.

When this is done, it will re-enable the KASAN MPU regions, reload the SW-saved context (possibly updated by the emulator since save), and return from exception.

Then, the processor will restore the HW saved context (possibly updated by the emulator since save), and give control back to the interrupted thread, but at the instruction after the one that just trapped and got emulated.

The following diagram summarizes the high level behavior or the kasan.

TODO : summarize initialization sequence.

TODO : summarize validation operation.

# Whitelisting the stacks.

In order for our MPU-based trap sytem to work, we need to add two other MPU regions, more prioritary than the RAM blacklist, to allow access to the user and exception stack (PSP, MSP). 

If we didn't do this, any code making a memory access in the RAM would cause an exception.

The processor, in the handling of this exception, would push the context to the stack in use at that moment (either Main or Process stack), which, if those regions were blacklisted by the MPU, would cause the memfault to be escalated in a hardfault.
This is not what we want, as it has different privileges, and less recoverability possibility.

This increses to 3 the number of MPU regions necessary to implement our kasan.

# Disabling MPU regions in the memfault handler.

The kasan memory access checker will run in the memfault hanler.

This checker will likely access variables not located in the stack.

This is a potential problem, as the MPU may still be active when this handler is executed.

Even if we had the option to disable the MPU in handler mode, this would not be what we would want, as that would prevent the kasan to check
accesses in handler mode, under which a large part of the kernel operates (syscall, scheduling, interrupts, etc...).

To handle this situation, we will need to reprogram the MPU when we enter and exit the MemFault handler.

On entry, we will disable the regions related to KASAN, and on exit, we will re-enable them.

# KASAN regular entry.

The next sections we will talk about how to manage the kasan memory attributes.

To do that, we will need the allocators to call into the kasan when they allocate or free memory.

In reality, there are some issues when trying to enter kasan in a function-like manner.

As described in the memory access trap section, the basic working principle of our kasan is to blacklist the whole RAM minus the stacks, and have any access to these regions.

The issue, is that the kasan is meant to check all accesses made by the kernel, interrupts included.

As such, when enering kasan 'The software way', we must prevent any interrupt to occur.

This can be done via disabling interrupts, and re-enabling them on exit. Though, we must be carefull here : interrupts may have been already disabled before entering kasan, so we must not re-enable them in this case.

Entering kasan 'The Software Way' requires us to be able to disable MPU regions, which requires us to have read / write access to registers of the system control space.

ARMV7M ARM for CortexM3 :
User access prevents:
- use of some instructions such as CPS to set FAULTMASK and PRIMASK
- access to most registers in System Control Space (SCS).

As such, if we plan to have memory management code that runs at User level (some secondary allocator), or if we plan to support user code that reports memory as read-only to debug something, we need to escalate to Privileged mode. 

We could have a dedicated syscall in the kernel to handle those cases. But then we would have to have two paths, for code that is already privilleged, and for code that is not.

There is a more clever way.

What we will do, is to have a dedicated entry function that receives a pointer to a function to execute, and its arguments.
This entry function will be located at a fixed address in the executable. This function will manually trigger a read at address 0 on purpose.
This will cause a memory management exception to be triggered, and will cause the execution of the generic kasan handler, which will setup the environment for kasan execution.
The generic kasan handler will then compare the fault PC to the location where the entry function causes the read at access 0.
If the values are equal, then it will treat the memory fault as a kasan entry, and will read the function and its arguments from the saved context, execute the function and return. I
If the values are not equal, then it will know that the memory fault was not made on purpose by the entry function, and will proceed with the regular kasan access checking.

Let's note that this techniques required address at address 0 to trigger a memory fault.

Unluckily for us, in microcontroler-land, address 0 is often accessible. In my board, this is the start of the TCM-D RAM region.

We have two choices : 
- access a known non-mapped address that we know will trigger a fault.
- use the MPU to blacklist the first 32B starting at address 0. This has the double benefit of causing the program to fault on any access to address 0 (nullptr), which is a typical symptom of a buggy code. If we don't do that, the buggy code will successfully access address 0 and continue until something else breaks.

