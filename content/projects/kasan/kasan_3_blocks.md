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

## Structure

### Base

The previous chapters laid the foundations on which we will build the KASAN :
- we cannot use any transpiling-oriented method to wire our KASAN to the executable due to potential code size increase.
- we have an `MPU` that can trigger a MemManage fault whenever a specific portion of memory is accessed.
- the handler of this MemManage fault can modify execution context (registers) of the program that caused the memory access, and update its execution flow.
- the MemManage fault handler gives us the location of the fault, so as the address of the instruction that generated the fault.

### Memory checker execution flow 

To implement our KASAN, we will first use the `MPU` to disable access to the whole RAM region.

That will make any access to any RAM to cause a MemManage fault, causing an exception and the execution of the related handler.

The MemManage fault handler will save the part of the context that hasn't been saved by the HW somewhere in memory for the emulator (defined below) to read or write it later.

The MemManage fault handler will then read the PC of the instruction that caused the fault, read the instruction and decode it.

It will then check that the related instruction is a memory access. If it is not one, it will just execute the classic MemManage fault exception.

If it is a memory access, it will emulate the instruction and perform its checking in the meantime.

This will be the place where the memory checking is done.
It involves :
- decoding the instruction.
- verifying that every access performed by the instruction is valid.
- updating the KASAN memory metadata to reflect the new state caused by the memory access (ex : write to an uninitialized location causes the location to be treated as initialized in subsequent accesses to that location).
- emulating the instruction, by performing the underlying accesses : 
  - register reads will cause the emulator to read the context-saved values.
  - register writes will cause the emulator to write the context-saved values.
  - memory reads will cause the emulator to actually perform the read now that the `MPU` is disabled.
  - memory writes will cause the emulator to actually perform the write now that the `MPU` is disabled.
- if the instruction emulation is successful, modifying the PC that will be restored when the exception will return, so that the instruction after the one that just was emulated is executed at that time, and not the one that we emulated again.

The implementation of such an emulator will have a dedicated chapter.

When this is done, it will re-enable the KASAN `MPU` regions, reload the SW-saved context (possibly updated by the emulator since it was saved), and return from exception.

Then, the processor will restore the HW saved context (possibly updated by the emulator since it was saved), and give control back to the interrupted thread, but at the instruction after the one that just trapped and got emulated.

### Summary

The following diagram summarizes the high level behavior or the KASAN.

TODO : summarize initialization sequence.

TODO : summarize validation operation.

## Design notes 

### Whitelisting the stacks

In order for our `MPU`-based trap system to work, we need to add two other `MPU` regions, with a greater priority than the RAM blacklist region, to allow access to the user and exception stack (PSP, MSP). 

If we didn't do this, any code making a memory access in the RAM would cause an exception.

The processor, in the handling of this exception, would push the context to the stack in use at that moment (either Main or Process stack), which, if those regions were blacklisted by the `MPU`, would cause the MemManage fault to be escalated in a hardfault.
This is not what we want, as it has different privileges, and less recoverability.

This increases to 3 the number of `MPU` regions necessary to implement our KASAN.

### Disabling MPU regions in the MemManage fault handler

The KASAN memory access checker will run in the MemManage fault handler.

This checker will likely access variables not located in the stack.

This is a potential problem, as the `MPU` may still be active when this handler is executed.

Even if we had the option to have the `MPU` automatically disabled in handler mode, this is to coarse to suit our needs, as that would prevent the KASAN to check
accesses made in handler mode, under which a large part of the kernel operates (syscall, scheduling, interrupts, etc...).

To handle this situation, we will need to reprogram the `MPU` when we enter and exit the MemManage fault handler.

On entry, we will disable the regions related to KASAN, and on exit, we will re-enable them.

### KASAN regular entry

The next chapters we will talk about how to manage the KASAN memory attributes, and in particular, how those memory attributes are updated when an allocator allocates or frees a memory block. The allocators will need to call a KASAN entrypoint to verify that the attribute change is valid, and to perform it.

In reality, there are some issues when trying to enter KASAN in a function-like manner.

As described in the memory access trap section, the basic working principle of our KASAN is to blacklist the whole RAM minus the stacks, such as any access to this region causes a MemManage fault and causes the KASAN memory access checker to be executed.

The issue, is that the KASAN is meant to check all accesses made by the kernel, interrupts included.

As such, when entering KASAN `The software way`, we must prevent any interrupt to occur.

This can be done by disabling interrupts, and re-enabling them on exit. Though, we must be careful here : interrupts may have been already disabled before entering KASAN, so we must not re-enable them in this case.

Entering KASAN 'The Software Way' also requires us to be able to disable `MPU` regions. To do this, we need to have read / write access to registers of the `System Control Space`, which requires us to run in `Privileged mode`.

ARMV7M ARM for CortexM3 :
```
User access prevents:
- use of some instructions such as CPS to set FAULTMASK and PRIMASK
- access to most registers in System Control Space (SCS).
```

As such, if we plan to have memory management code that runs on `Unprivileged mode` (ex : secondary allocator), or if we plan to support user code that reports memory as read-only to debug something, we need to escalate to Privileged mode. 

We could have a dedicated syscall in the kernel to handle those cases. But then we would have to have two paths, for code that is already privileged, and for code that is not.

### A single KASAN entrypoint

There is a more clever way.

Unluckily for us, in microcontroller-land, address 0 is often accessible. In my board, this is the start of the TCM-D RAM region.

We will use another `MPU` region to prevent any access at address 0.

Then, we will define a dedicated `software_kasan_entry` function, implemented in assembly, that receives a pointer to a function to execute, and its arguments.

This entry function will be located at a fixed address in the executable. This function will manually trigger a read at address 0 on purpose.

This will cause a memory management exception to be triggered, and will cause the execution of the generic KASAN handler, which will setup the environment for KASAN execution.

The generic KASAN handler will then compare the fault PC to the location where the entry function causes the read at access 0.

If the values are equal, then it will treat the MemManage fault as a KASAN entry, and will read the function and its arguments from the saved context, execute the function and return.

If the values are not equal, then it will know that the MemManage fault was not made on purpose by the entry function, and will proceed with the regular KASAN access checking.

The related assembly code is : 


```C
# Enter kasan.
# Receives 4 args at most :
# - hdl : function to call, receives at most 4 args.
# - arg0 : first arg to pass to hdl.
# - arg1 : second arg to pass to hdl.
# - arg2 : third arg to pass to hdl.
# - arg3 : fourth arg to pass to hdl.
    .align  4
    .global kr0_tgt_ksn_enter
    .type   kr0_tgt_ksn_enter, %function

kr0_tgt_ksn_enter:

    # Store arg3 in r4 for the handler to have an easier job.
    sub sp, #8
    str r4, [sp, #0]
    str lr, [sp, #4]
    ldr r4, [sp, #8]

    # Store 0 in r12.
    mov r12, #0

    # Trigger a read at address 0.
    # The fault handler will detect that it came from this PC and forward
    # the call to the kasan handler.
    enter_pc:
    str r12, [r12]

    # Complete.
    ldr r4, [sp, #0]
    ldr lr, [sp, #4]
    add sp, #8
    bx lr
    .size   kr0_tgt_ksn_enter, .-kr0_tgt_ksn_enter
    .global armv7m_kasan_enter_pc
    .set armv7m_kasan_enter_pc, enter_pc

```

This assembly code defines a global variable whose address is equal to the address of the instruction that causes the access at PA 0.

The related KASAN C handler (called by the assembly MemManage fault handler after it saved the software context and disabled the KASAN MPU regions) will then compare the fault PC against this value and act accordingly.

Kasan handler C code :  

```C

/*
 * Kasan entrypoint.
 * Called by armv7m_kasan_handler defined in armv7m.S.
 * @fault_pc is the location where the address of the instruction that
 * faulted is stored (@hw_ctx + 0x18).
 * @hw_ctx is the start of the hw-pushed context.
 * @sw_ctx is the start of the sw-pushed context.
 */
void armv7m_kasan_entry(
	u32 *fault_pc,
	u32 *hw_ctx,
	u32 *sw_ctx
)
{
	check(hw_ctx, sw_ctx);
	check((void *) fault_pc == psum(hw_ctx, 0x18));

	/* Only handle memfaults with a valid MMFAR.
	 * All other faults go to kernel. */
	SCS_SHCSR SHCSR;
	SHCSR.bits = *(volatile u32 *) SCS_SHCSR__ADDR;
	if ((!SHCSR.MEMFAULTACT) || (SHCSR.BUSFAULTACT) || (SHCSR.USGFAULTACT))
		_flt_forward();
	SCS_CFSR CFSR;
	CFSR.bits = *(volatile u32 *) SCS_CFSR__ADDR;
	if (!CFSR.MMARVALID)
		_flt_forward();

	/* Read the MMFAR. */	
	const u32 mmfar = *(volatile u32 *) SCS_MMFAR__ADDR;  

	/* If the fault PC is equal to @armv7m_kasan_enter_pc, this is a kasan
	 * entry call. */
	if (*fault_pc == (((u32) &armv7m_kasan_enter_pc) & ~(u32) 1)) {

		/* MMFAR should be 0. */
		assert(mmfar == 0, "MMFAR expected 0 on kasan entry.\n");

		/* Fetch the handler and its arguments. */
		void (*hdl)(uaddr, uaddr, uaddr, uaddr) =
			(void (*)(uaddr, uaddr, uaddr, uaddr)) hw_ctx[0];
		uaddr arg0 = hw_ctx[1];
		uaddr arg1 = hw_ctx[2];
		uaddr arg2 = hw_ctx[3];
		uaddr arg3 = sw_ctx[0];

		/* Call the handler. */
		(*hdl)(arg0, arg1, arg2, arg3);

		/* Clear the fault. */
		*(volatile u32 *) SCS_CFSR__ADDR = 0xffffffff;

		/* Recover from the fault. */
		*fault_pc += 4;
		return;

	}

	/* Otherwise, we must check the operation in progress. */

	/* Determine the fault address. */
	const u32 pc = *(volatile u32 *) fault_pc;

	/* Determine if we are in allocator or user context. */
	const u8 from_all = !!all_ctr;

	/* Decode the instruction, execute it and return the
	 * PC of the next instruction.
	 * If an error occurs, do not return. */
	const ksn_emu emu = {
		.emu = {&ksn_emut},
		.hw_ctx = hw_ctx,
		.sw_ctx = sw_ctx,
		.flt_addr = mmfar,
		.from_all = from_all, 
		.chk_flt = 1,
		.is_ici = 0
	}; 
	const u32 new_pc = _process_pc(pc, &emu);
	check(pc < new_pc);
	assert(!emu.chk_flt, "no memory access made by the emulator.\n");
	const u32 diff = new_pc - pc;
	check((diff == 2) || (diff == 4));

	/* Clear the fault. */
	*(volatile u32 *) SCS_CFSR__ADDR = 0xffffffff;
	
	/* Update the PC and resume execution. */
	*fault_pc = new_pc;

}

```

