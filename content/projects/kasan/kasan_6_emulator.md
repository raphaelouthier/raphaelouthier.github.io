---
title: "ARM Thumb Emulator."
summary: "Executing instruction the way it should not be done."
series: ["KASAN"]
series_order: 6
categories: ["KASAN"]
#externalUrl: ""
showSummary: true
date: 2023-11-15
showTableOfContents : true
draft: false
---

As stated in the previous sections, to verify our accesses, we will use the MPU to blacklist all the RAM minus the stacks, which will make any access to these instructions trap.

Then, the memory checker will use the context saved data to retrieve the PC of the instruction that caused the memory access, then decode it, then emulate it, checking the various accesses performed by the instruction in the meantime.

Our emulator will be composed of two base blocks : 
First, a set of instruction emulation functions that will, for each instructions that we support, emulate the instruction. That involves : 
  - read the content of the context-saved registers.
  - write the content of the context-saved registers.
  - read memory.
  - write memory.
  - perform KASAN check whenever a memory access is performed.

Second, a decoder, that will, given the binary encoding of an instruction, extract the instruction opcode, extract the relevant fields in the instruction, then call the C emulator function associated with that opcode.

# Decoder

The objective of the decoder will be to decide which instruction emulation function to call and with which argument, given the binary encoding of an instruction that caused a memory access.

This is where things get tricky.

Indeed, an ARMV7M CPU like the cortex M7 executes ARM-tumb assembly.
Sadly for us, the ARM Thumb assembly is NOT a fixed length instruction.

An ARM Thumb assembly instruction has one of two forms :
- 16 bits instructions.
- 32 bits instructions, composed of two 16 bits words. No field crosses the two 16 bits words.

This historically comes from the various additions to the THUMB instruction set, that forced the adoption of 32 bits instructions, as 16 bits were not enough to represent all required instructions, like VFP.

As we will see, writing a decoder is a real pain, but can be done really fast and automatically if we have the right tools. Though, decoding a variable-length instruction set is a REAL problem, and is much more complex than writing a fixed-length instruction set decoder.

Think about it : in order for our decoder to process the instruction, it must read the actual value of the instruction. But in the case of a variable-length instruction, how can it know the length to read ? It should read byte by byte only whenever needed, which will greatly complexify the code, compared to a fixed length instruction set, where it only has to read once and (in a couple of words) bisect depending on the values of certain bits.

Luckily, ARM makes our life easier by allowing us to detect if a word known to be the start of an instruction is the start of a 16 bits instruction or a 32 bits instruction :

https://developer.arm.com/documentation/ddi0403/d/Application-Level-Architecture/The-Thumb-Instruction-Set-Encoding/Thumb-instruction-set-encoding#:~:text=The%20Thumb%20instruction%20stream%20is,consecutive%20halfwords%20in%20that%20stream.

If bits [15:11] of the halfword being decoded take any of the following values, the halfword is the first halfword of a 32-bit instruction:
0b11101
0b11110
0b11111.

This will allow us to divide the tough problem of decoding the variable length THUMB ISA into two much simpler problems, being decoding either the fixed length THUMB32 ISA or the THUMB16 ISA.

The first task of our decoder will be to determine if the instruction that faulted is a 16 bits instruction or a 32 bits instruction.
Then, the decoder will call the relevant sub-decoder.

# Basic structure of a fixed-length instruction decoder

An instruction is composed of a fixed number of bits, each one having a particular meaning.

We can group these bits into three groups, for a given instruction : 
- opcode bits : those bits will determine the sequence operation performed by the instruction, aka in our case, the emulation function to call to execute this instruction.
- data bits : those bits will provide configs and arguments like register ids to the sequence of operations, aka in our case, arguments to our emulation functions.
- unused bits : bits whose value do not influence the behavior of a given instruction.


TODO PROVIDE AN EXAMPLE

The objective of our decoder will be, given a particular instruction represented by its binary encoding : 
- to read the opcode bits and to determine which 

An instruction is decoded in hardware by the CPU (by a block called, oh surpruse, the decoder), and as such, the structure of the instruction is made to allow a fast decoding.

In real life : 
- data bits representing the same entity (an immediate, a register ID) will almost always be contiguous. We will call that entity a field.
- opcode bits may or may not be contiguous.
- the location of the different fields and opcode parts of the various instructions are often similar accross instructions of the same category.

Let's take a look at the structure of the THUMB16 ISA encoding to illustrate that point

As you can see, we definitly can see a pattern here in the placement of the opcodes and registers.


There is one exception to the rules stated before, which will kind of complefify the generation of the decoer : there are cases where two different instructions will have the exact same opcode bits, but one should be executed if a field (ex : register ID) has a specific value, and the other should be executed otherwise.

Even if we can't thank ARM for this rather unpleasant corner case, let's thank them for not getting completely out of their minds and supporting the same situation but with a possible SET of values on each side rather than one value VS all others. That would have been a nightmare to manage. Thanks ARM.

All jokes aside, this will add a non-outrageous level of complexity to the decoder. 

Given what I have described until now, you should start to have an idea of the structure of our decoder. It will be composed of :
- a HUGE nested ifelse section (rather an ifelse tree)  where we will bisect on the value of one single bit at a time;
- in the leaf parts of the ifelse tree either : 
  - a jump to handle an UNDEFINED instruction (aka an instruction not supported by the decoder); or
  - a section to extract all data fields from the instruction encoding, and to call the related emulator function.

If you are intrested by writing such piece of code, be assured that I'm not, as it is a nightmare to read, to write and to debug : any incorrect bit index can radically change the behavior of the decoder and cause some undebuggable issue.

# ARM exploration tools

Luckily for US, ARM is in an even worse situation than us.

Indeed, we only have to generate a decoder for the memory instructions. They have to generate decoders for ALL instructions, both in HW and in their SW tools. Due to that, it is highly unlikely that they didn't come up with a solution to have those pieces of code easily generated.

When releasing the ARMV8, ARM also released what they call the ARM Exploration tools, aka HUGE xml/html files that describe the structure of instructions, and in particular, THEIR ENCODINGS.

The reader could think, "Yeah, but they only released it for ARMV8, right ?", which is true but kind of false in practice, as ARM ISAs are backwards compatible : the A32/T32 xml doc contains the encoding for the legacy ARM32 instruction, and all releases of the Thumb ISA.

This is ... PERFECT. I can't thank ARM enough for doing so, as it will prevent us from needing to manually read the spec and translate the text-based encoding into C code.

Thanks to that, it is easy to come up with a python script that will transform those XML files into an easily processable text representation like the following : 

TODO EXAMPLE + EXPLANATION.

This code is not open-source.

The spec has downsides though : 
- it doesn't really gives the encoding in a direct manner. Rather, it gives the indices and lengths of the various fields that compose an instruction.
- Bit values within fields are represented using multiple notations (0, 1, '', 'Z', 'N') and lack a bit of structure. When writing your parser, you will discover most of these corner cases the hard way.
- some instructions use values derived from MULTIPLE fields (ex : imm3:imm8). I searched a lot and I couldn't find any machine-readable information that would allow us to automatically generate code to do those combinations automatically. For now, the emulation functions will have to take care of that.

# Going crazy : generating our decoder automatically.

Using the instruction representation provided by the python script, it was easy and fun to write a small program that generates a C decoder using this representation. The program proceeds the following way : 
- it reads the description of each instruction to decode.
- then it generates a bisection tree by recursively dividing the instruction set in two based on the value of a particular bit know (either 0 or 1 but not x) for all bits.
- then, it generates the ifelse tree based on that, and the field extraction code based on each instruction description.

This code is again close-source, but if the reader needs to be convinced that what I describe is possible, they may find a procedurally generated decoder for a part of the AArch32 ISA (with minor changes), through [this link](https://github.com/Briztal/kr_public/blob/master/aarch32_dec.h)

This code is not public domain and you should not use it as it will not work as it : the minor changes that I just mentioned are actually me intentionally inverting the encoding of some frequently used instructions because I'm a nice person.

If you need the real decoder, reach out to me directly. 


