---
title: "ScratchOS : first programs"
summary: "Uploading more and more sophisticated code."
series: [ScratchOS]
series_order: 2
categories: [ScratchOS]
tags: ["ScratchOS"]
#externalUrl: ""
showSummary: true
date: 2026-03-28
showTableOfContents : true
draft: true
---

## Introduction

In the previous article we finally obtained a ScratchOS firmware which allows us to upload code with 4 GPIOs and then run it.

In this chapter we'll upload our first sequences of instructions.

## Upload.

We have four pins available to send our code.

Making connections with cables is a pain so I repurposed some keyboard switches I had around and put my worse soldering skills to make this monstrosity.

The four top switches control the data pins, lsb on right and msb on left : if we don't press, the line is low and if we press, the line is high. 

On the bottom left is the capture switch, and on the bottom left, the execution pin.

## Assembly reference.

This chapter will show some assembly instructions. 

As per the rules of the game, I can't use a computer to convert test assembly to binary assembly.

I hence used the official Thumb1 doc from ARM to find the encodings, and [made a cheat sheet here](/art/doc_thumb_1).

I've been using this cheat sheet extensively while writing this chapter.

## Watch out for big endian.

The cheat sheet mentiones above shows the bits from msb/msB on the left to lsb/lsB on the right. 

Due to how our flasher works (incrementally copying memory), we need to transfer nibbles in big endian.

Ex : to upload a deadloop `b .` encoded by 0xe7fe, we need to transfer nibbles 0xe, 0xf, 0x7 and 0xe and press exec.

All algorithms will be presented in human readable format with offsets and encodings on the left, and will include the nibble stream to provide to the firmware to run them.

## Deadloop.

0 : e7fe : b .

stream : ef7e 

## Banch back to SRAM start.

We're located at end of SRAM and need to go back to 0x20000000.

That's bad since that's more than what our pc-relative branch lets us do. 

We'll have to hardcode the target PC in the code, then perform a PC-relative load (in r0) followed by a `BX r0`.

In this case, the target address is `0x20000001` since bx requires the bottom bit to be 1 for thumb mode.

Code :
0 : 4800 : ldr r0, [PC + 4]
2 : 4700 bx r0
Data :  
4 : 0x2000001

byte stream : 0084007410000002

## Turn led off and deadloop.

Led is already in out mode so _single_ write to make.

we can just write to all GPIOs since only LED is set to OUT.

ASM : 
mov r0, GPIO_OV
mov r1, (u32) -1
str r1, [r0]
b .

Now we need to make it doable in thumb with the least amount of instructions.

biggest challenge is not to do the stores, it's to intialize registers with addresses and values.

We are only able to provide code, and thumb instructions can only provide 8 bit immediates at best.

But we can make PC relative loads.

Our code will be composed of two sections :
- code section which will do the memory transfers based on data section.
- data section

register loads can be done with a Thumb shortcut : 
- we set SP at the start of data section.
- we use pop which can populate multiple registers at once.


code section :

add sp, PC, CODE_SIZE
pop {r0, r1}
str r1, [r0]
b .

data section
GPIO_OV
0xffffffff

the add sp, pc will be the hard one.
basically thumb register fields for registers are only 3 bits.
that makes our life complex since we can only operate on 'low' registers (r0 -> r7). sp and PC are both high registers.

We could rework our code for PC-relative load but in the future we want to be able to quickly load data from code so we need this trick to be generalist.

We want to do the following : 
mov r0, pc
add r0, #CODE_SIZE
mov sp, r0


High register operations ops syntax : 

0100 01oo SDss sddd 
4    4-7  .... ....

o : op : 00 = add, 01 = cmp, 10 = mov, 11 = bx.
S : high flag for source.
D : high flag for dest.
sss : source register
ddd : dest register

high register move syntax
0100 0110 SDss sddd
4    6    .... ....

special registers ;
sp = 13,  1 101
lr = 14,  1 110
pc = 15 , 1 111

mov r0, pc = mov 0000 1111
0100 0110 0100 0111
4    6    4    f

mov sp, r0 = mov 1101 0000
0010 0110 1010 1000
4    6    a    8

The addition is a bit more painfull at first glance since the native add-sub only allows a 3 bit operand (0-7) which will be limiting quickly.

Though since our source and dest registers are equal, we can use a dedicated instruction which supports a 8 bits immediate.

move/compare/add/subtract immediate syntax :

001o oddd iiii iiii
[23] .... .... ....

o : operation : 00 mov 01 cmp 10 add 11 sub
d : dest low reg.
i : offset.

addition syntax :

0011 0ddd iiii iiii
3    0-7  .... ....

which makes a ince lil 3 [reg] offset mnemonic.

in our case, add to 0 is 3 0 offset.

Now let's inline our sequence. Offset updated.

code section 
0 : mov r0, pc
2 : add r0, CODE_SIZE=12
4 : mov sp, r0
6 : pop {r0, r1}
8 : str r1, [r0]
10 : b .

data section
12 : GPIO_OV
14 : 0xffffffff

So that's it for our layout. We just need two more instructions : the pop and the store.

push pop syntax : 

1011 m01r llll llll
b    .... .... ....     

m : 0 store 1 load
r : 0 don't store LR / load PC, 1 store LR / load PC 
l : register mask. bit : 0 not pushed / popped, 1 pushed/popped.

push (regular) :
1011 1010 llll llll
b    a    .... ....

pop (regular)
1011 0010 llll llll
b    2    .... ....

pop {r0, r1}
1011 0010 0000 0011
b    2    0    3



load-store (immediate offset) syntax :

011s mooo oobb bddd

s : 0 word, 1 byte
l : 0 store, 1 load
o : base offset
b : base register
d : data register (source or dest).

word store with no offset : 
0110 0000 00bb bddd
6    0    0-3  ....

word load with no offset : 
0110 1000 00bb bddd
6    8    0-3  ....

str r1, [r0] :

0110 0000 0000 0001
6    0    0    1

generally, store any register at address of r0 :

0110 0000 0000 0ddd
6    0    0    Rd

generally, load any register at address of r0 :

0110 1000 0000 0ddd
6    8    0    Rd

Note that on the rpi2040 the SIO:GPIO_OUT is at 0xd0000000 + 0x10.

This gives us our final binary :

code section 
0  : 464f : mov r0, pc
2  : 3008 : add r0, CODE_SIZE - 4 = 8
4  : 46a8 : mov sp, r0
6  : b203 : pop {r0, r1}
8  : 6001 : str r1, [r0]
10 : e7fe : b .

data section
12 : d0000010
14 : ffffffff






####################################


Basic program to prove things work :
- configure GPIOs 0 to 8 for write.
- write turn them on.
- deadloop.

configuration of GPIOs for write : 
store base address of GPIOs in r0. 
store 5 in r1.

mov r0 GPIO_CTRL_START
mov r1 5
mov r2 8
str r1, [r0]
add r0, r0, r2
str r1, [r0]
add r0, r0, r2
str r1, [r0]
add r0, r0, r2
str r1, [r0]
add r0, r0, r2
str r1, [r0]
add r0, r0, r2
str r1, [r0]
add r0, r0, r2
str r1, [r0]
add r0, r0, r2
str r1, [r0]
mov r0, GPIO_OE
mov r1, (u32) -1
str r1, [r0]
mov r0, GPIO_OV
mov r1, (u32) -1
str r1, [r0]
b .


Code is just a big sequence of :
- load four 32 bits values from code : (dst, nbr, inc0, inc1) to r0, r1, r2 and r3.
- perform @nbr memory transfers from code to dst, incrementing dst of inc0 and  at the locations, incrementing of incr.


Let's rewrite the code 

