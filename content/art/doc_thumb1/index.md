---
title: "Binary arm-thumb-1 cheat sheet"
summary: "Some useful instructions and their encoding."
categories: ["Documentation"]
tags: ["ARM"]
#externalUrl: ""
showSummary: true
date: 2026-03-28
showTableOfContents : true
draft: false
---

## Warning

This is a work in progress which I publish mostly for my own reference and there may be errors and typos.

Please refer to the source of truth if you want to use thumb-1 and pardon my english.

## Context

These days when I have time I'm playing ScratchOS and I'm currently at the nibble stage where I can only write code via GPIOs and have the firmware execute it.

To move forward I need to write a few simple programs to start taking over from here.

The challenge is that I can't use a computer to translate text assembly to hex assembly, and that requires me to get a better grip of the thumb assembly encoding.

This page is intended as a reference for future me or anyone playing masochist-mode-bringup.

## Source of truth

All the encodings listed here can be found in the [ARM Thumb 1 spec](/art/doc_thumb1/thumb1_manual.pdf).

## Instructions.

### PC-relative branch.

Branch syntax :

| 1110 | 0xxx | xxxx | xxxx |
|---|---|---|---|
| e | 0-7 | .... | .... |

branch behavior :
takes PC of instruction, adds 4, sign extends 2 * X to 32 bits, adds it, and sets PC to the result.

branch forward :
|1110 | 00xx | xxxx | xxxx |
|---|---|---|---|
|e | 0-3 | .... | .... |

branch backward :
| 1110 | 01xx | xxxx | xxxx |
|---|---|---|---|
| e | 4-7 | .... | .... |

deadloop : branch with offset of -4 -> X = -2 = (~0b10 + 1 = 0b111 1111 1101 + 1 = 0b111 1111 1110)

| 1110 | 0111 | 1111 | 1110 |
|---|---|---|---|
| e | 7 | f | e |


### PC-relative load :

Generic case :

| 0100 | 1ddd | oooo | oooo |
|---|---|---|---|
| 4 | 8-f | .... | .... |

Operands :
* `d` : dest register.
* `o` : offset

Behavior :
* take v = (PC of instruction + 4) & ~(3);
* take o and multiply it by 4.
* load at v + o, write result in dest reg.

Particular cases :

Load at N words after PC (N > 0) after PC into r0 :
| 0100 | 1000 | oooo | oooo |
|---|---|---|---|
| 4 | 8 | 0 | N - 1 |

Load four bytes after PC into r0 :
| 0100 | 1000 | 0000 | 0000 |
|---|---|---|---|
| 4 | 8 | 0 | 0 |

Load eight bytes after PC into r0 :
| 0100 | 1000 | 0000 | 0001 |
|---|---|---|---|
| 4 | 8 | 0 | 1 |

And so on.


### Operations on high registers.

Encoding :

| 0100 | 01oo | SDss | sddd |
|---|---|---|---|
|4 | 4-7 | .... | .... |

Operands :
 * `o` : op : 00 = add, 01 = cmp, 10 = mov, 11 = bx.
 * `S` : high flag for source.
 * `D` : high flag for dest.
 * `sss` : source register
 * `ddd` : dest register

high register move syntax
| 0100 | 0110 | SDss | sddd |
|---|---|---|---|
| 4 | 6 | .... | .... |

special registers ;
* `sp` = r13, `1 101`
* `lr` = r14, `1 110`
* `pc` = r15, `1 111`

mov r0, pc = mov 0000 1111 :

| 0100 | 0110 | 0100 | 0111 |
|---|---|---|---|
| 4 | 6 | 4 | f |

mov sp, r0 = mov 1101 0000 :

| 0010 | 0110 | 1010 | 1000 |
|---|---|---|---|
| 4 | 6 | a | 8 |

`bx <s>`

| 0100 | 0111 | 00ss | s000 |
|---|---|---|---|
|4 | 7 | 0-3 | [08] |

`bx r0`

| 0100 | 0111 | 0000 | 0000 |
|---|---|---|---|
|4 | 7 | 0 | 0 |


### Move/compare/add/subtract immediate syntax :

| 001o | oddd | iiii | iiii |
|---|---|---|---|
| [23] | .... | .... | .... |

Operands :
* `o` : operation : 00 mov 01 cmp 10 add 11 sub
* `d` : dest low reg.
* `i` : offset.

addition syntax :

| 0011 | 0ddd | iiii | iiii |
|---|---|---|---|
| 3 | 0-7 | .... | .... |

which makes a nice lil 3 [reg] offset mnemonic.

Add offset to r0 : 3 0 offset.

### push pop

| 1011 | m01r | llll | llll |
|---|---|---|---|
| b | .... | .... | .... |

Operands :
 * `m` : 0 store 1 load
 * `r` : 0 don't store LR / load PC, 1 store LR / load PC
 * `l` : register mask. bit : 0 not pushed / popped, 1 pushed/popped.

push (regular) :
| 1011 | 1010 | llll | llll |
|---|---|---|---|
| b | a | .... | .... |

pop (regular)
| 1011 | 0010 | llll | llll |
|---|---|---|---|
| b | 2 | .... | .... |

pop {r0, r1}
| 1011 | 0010 | 0000 | 0011 |
|---|---|---|---|
| b | 2 | 0 | 3 |

### load-store (immediate offset) syntax :

| 011s | mooo | oobb | bddd |
|---|---|---|---|
| [67] | .... | .... | .... |

Operands :
 * `s` : 0 word, 1 byte
 * `l` : 0 store, 1 load
 * `o` : base offset
 * `b` : base register
 * `d` : data register (source or dest).

word store with no offset :
| 0110 | 0000 | 00bb | bddd |
|---|---|---|---|
| 6 | 0 | 0-3 | .... |

word load with no offset :
| 0110 | 1000 | 00bb | bddd |
|---|---|---|---|
|6 | 8 | 0-3 | .... |

str r1, [r0] :

| 0110 | 0000 | 0000 | 0001 |
|---|---|---|---|
| 6 | 0 | 0 | 1 |

generally, store any register at address of r0 :

| 0110 | 0000 | 0000 | 0ddd |
|---|---|---|---|
| 6 | 0 | 0 | Rd |

generally, load any register at address contained in r0 :

| 0110 | 1000 | 0000 | 0ddd |
|---|---|---|---|
| 6 | 8 | 0 | Rd |


