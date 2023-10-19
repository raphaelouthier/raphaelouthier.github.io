---
title: "Memory checking."
summary: "General memory checking considerations."
series: ["KASAN"]
series_order: 1
categories: ["KASAN"]
#externalUrl: ""
showSummary: true
date: 2023-09-27
showTableOfContents : true
draft: false
---

This article will give a theoretical base on memory checking.

A memory checker is a system that checks a subset of the memory operation made by a program.

# Terminology : 

Memory operations : Direct memory accesses and allocation/free operations.
Memory access : read or write to a memory location.
Memory location : location in CPU memory accessible by address.

-> A register is not a memory location.
-> Accessing a register is not a memory access.

Here the 'subset' can include all memory operation  or an actual subset. We will elaborate more on that in a few moments.

Disclaimer : I have no prior experience with the internals of existing memory checkers like valgrind. The rough explanation that I'm giving here may be partially / completely false. It just reflects my high level understanding. This should have no impact on the validiti of the further sections.

Checking a memory operation means intercepting that memory operation before it occurs in 'some way', then verifying that the said memory operation is legitimate, then if so, allowing the operation to complete.

Legitimate memory operation : an operation that philosophically makes sense, given the paradigms of the program.
Examples :
- read to an initialized local variable.
- write to a writeable local variable.
- read to a memory region allocated by the program, not freed since allocation.

Illegitimate memory operation : an operation that philosophically doesn't make sense, given the paradigms of the program.
Examples : 
- double free.
- read of uninitialized memory.
- use by the user after free.
- double allocation (by the allocator).
- use by the allocator after the allocation.
- write to non-writeable memory.
- write to a memory location that philosophically doesn't belong to the part of the program that does the access (mem corruption ?)

The strategy to check a memory operation depends on the type of the operation.

For allocation/free operations, there are usually fixed entrypoints for those operations (C : malloc/free et.al. ). The memory checker just has to override these entrypoints so that its own implementations of (ex) malloc or free are called. Then it has the opportunity to verify the validity of operations, and call (potentially) call the real malloc / free if they are legit (or just manage memory itself, it doesn't matter).

Memory accesses are trickier to check.
Those accesses are not made using a function code, they are made using actual assembly operations, and there is no easy way to just 'override' those instructions.

# Checking memory accesses : transpiling and why we cannot.

A potential strategy is to transpile the program : the memory checker will disassemble the assembly code and replace all memory access operations with assembly stubs to instead call the memory checker's entrypoints, or just do the checking in place.
In all cases : 
- this is a very tricky operation, as for example, the jump addresses / offsets have to be carefully updated.
- this has a significant impact on :
	- the code size, as a single memory access assembly operation is converted to a sequence of assembly operations.
	- the code performance, as every access will have to be checked.

This strategy could theoretically work for a microcontroller code, but we have to consider the impact on code size very seriously.

Computers have a large virtual address space and kernel-powered swapping capabilities that allows enlarging the size of the executable way beyond what we could ever need. Taking a 10x hit on the executable size won't affect the possibility of executing the code.

Microcontrollers are not in this situation.

Microcontrollers have flash that range from a few kilobytes to a few megabytes.

In my case, my code was already taking 63% of the chip's flash (128KiB large).

Even taking a 2x hit wasn't acceptable in my case, and the transpiling method only gives a worst case guarantee of Nx (N being the number of instructions required to emulate a single memory access instruction, N >= 2). 

This strategy was not applicable in our case.

To implement a KASAN on such device, we need to have a solution that is taking advantage of the processor hardware.

# Subset and limitations.

In the introduction I mentioned that the memory checker was checking a subset of the memory operations.

Ideally, we would like our memory checker to check all memory operations.

Though, depending on the implementation of the memory checker, some operations will be more difficult to handle than others.

A trivial example is memory access operations vs allocation / free operations. It is very easy for a debugger to hook up to memory allocation primitives like malloc and free and to verify the validity of those operations, since those (with their `realloc*` counterparts) support the entire lifecycle memory (you're not supposed to free a block not acquired via free and freeing a block means that you shouldn't free it again). 

Though, as we said earlier, checking actual memory accesses is non-trivial as involves directly working with the assembly, either directly as described in the transpiling section, or indirectly, as it will be described later for our implementation.

Another example showing the variation in complexity between check operation arises when we think of local variables vs allocated variables.

Let's assume in this example that regisers and compiler optimization do not exist and that when we access any type of variable, a memory access instruction is generated by the compiler.

When compiling this fuction : 

```
void f(void) {
	volatile uint64_t i = 0;
}
```

the comiler will detect that a local variable (@i) is used, and needs a location.
It will place this variable in the execution stack allocated to @f, and will generate :
- a function prologue to reserve space on the stack.
- a memory access to store 0 at the location of @i in the stack.
- a function epilogue to restore the stack to the state where it was before the execution of the prologue.

This hardly requires subtracting 8 to the stack pointer, storing 0 at the new top of stack and adding 8 to the stack pointer.

Now, let's note that the actual address of i (that &i evaluates to) is a stack address, and will become invalid as soon as the function returns.
After that, it will potentially be allocated to another stack variable, or never used again, depending on the executed code.

Due to this, if we want to check accesses to local variables (to detect a read from an uninitialized location), we also need to modify the function prologue and epilogue to report stack adjustments to the memory checker.

Now, when compiling this function : 

```C
void f(void) {
	uint64_t *ptr = malloc(8);
	*ptr = 0;
	free(ptr);
}
```

the compiler will still allocate space on the stack for a local variable, but this time this local variable will be a pointer that will contain the address of the memory block to write 0 to.

In this case, it will be a lot easier for the memory checker to verify accesses to `*ptr` (not `ptr`), since this memory block has a clearly defined life cycle : its life starts after allocation by @malloc, after which it can be considered uninitilized, and ends before free by @free.

The conclusion to this point is that it is more difficult to check accesses to local variables than it is to check accesses to dynamically allocated variables.

Luckily for us, the compilers nowadays feature decent function-local analysers that will warn against such usages at compile time.
Added to that, the main bugs that we statistically encounter in real life are due to dynamically allocated memory.
Checking local variable is a nice to have feature, but not a must have feature. 

