--- 
title: "Assembly trick : set membership test." 
summary: "if ((a == c0) || (a == c1) || `...` || (a == cn))."
categories: ["C","Assembly",] 
#externalUrl: "" 
showSummary: true
date: 2025-08-03 
showTableOfContents : true
draft: true 
---

## C level

When working on [this project](), I took a look at how the compiler would digest this code : 

``` C

/*
 * Skip whitespaces.
 */
const char *ns_js_skp_whs(
    const char *pos
)
{
    char c;
    while ((c = *pos)) {
        if ((c == ' ') || (c == '\r') || (c == '\n') || (c == '\t')) pos++;
        else break;
    }
    return pos;
}
``` 

In this function, we want to skip every character in the set `{' ', '\r', '\n', '\t'}`.

{{< alert >}}
The reader may note that this function could be way shorter. We'll cover this in a moment.
{{< /alert >}}

## Assembly level.

Let's see what it looks like in `-o0` : 

``` assembly
(gdb) disassemble ns_js_skp_whs
Dump of assembler code for function ns_js_skp_whs:
   0x000000000045056c <+0>:     sub     sp, sp, #0x20
   0x0000000000450570 <+4>:     str     x0, [sp, #8]
   0x0000000000450574 <+8>:     b       0x4505b4 <ns_js_skp_whs+72>
   0x0000000000450578 <+12>:    ldrb    w0, [sp, #31]
   0x000000000045057c <+16>:    cmp     w0, #0x20
   0x0000000000450580 <+20>:    b.eq    0x4505a8 <ns_js_skp_whs+60>  // b.none
   0x0000000000450584 <+24>:    ldrb    w0, [sp, #31]
   0x0000000000450588 <+28>:    cmp     w0, #0xd
   0x000000000045058c <+32>:    b.eq    0x4505a8 <ns_js_skp_whs+60>  // b.none
   0x0000000000450590 <+36>:    ldrb    w0, [sp, #31]
   0x0000000000450594 <+40>:    cmp     w0, #0xa
   0x0000000000450598 <+44>:    b.eq    0x4505a8 <ns_js_skp_whs+60>  // b.none
   0x000000000045059c <+48>:    ldrb    w0, [sp, #31]
   0x00000000004505a0 <+52>:    cmp     w0, #0x9
   0x00000000004505a4 <+56>:    b.ne    0x4505cc <ns_js_skp_whs+96>  // b.any
   0x00000000004505a8 <+60>:    ldr     x0, [sp, #8]
   0x00000000004505ac <+64>:    add     x0, x0, #0x1
   0x00000000004505b0 <+68>:    str     x0, [sp, #8]
   0x00000000004505b4 <+72>:    ldr     x0, [sp, #8]
   0x00000000004505b8 <+76>:    ldrb    w0, [x0]
   0x00000000004505bc <+80>:    strb    w0, [sp, #31]
   0x00000000004505c0 <+84>:    ldrb    w0, [sp, #31]
   0x00000000004505c4 <+88>:    cmp     w0, #0x0
   0x00000000004505c8 <+92>:    b.ne    0x450578 <ns_js_skp_whs+12>  // b.any
   0x00000000004505cc <+96>:    ldr     x0, [sp, #8]
   0x00000000004505d0 <+100>:   add     sp, sp, #0x20
   0x00000000004505d4 <+104>:   ret
``` 

As you can see, the compiler basically does _each_ check sequentially, which makes sense since we told it to do so via `-o0`.

Now let's witness the magic of `-o3` :

```
(gdb) disassemble ns_js_skp_whs
Dump of assembler code for function ns_js_skp_whs:
   0x0000000000435320 <+0>:     ldrb    w1, [x0]
   0x0000000000435324 <+4>:     cbz     w1, 0x435348 <ns_js_skp_whs+40>
   0x0000000000435328 <+8>:     mov     x2, #0x2600                   // #9728
   0x000000000043532c <+12>:    movk    x2, #0x1, lsl #32
   0x0000000000435330 <+16>:    cmp     w1, #0x20
   0x0000000000435334 <+20>:    b.hi    0x435348 <ns_js_skp_whs+40>  // b.pmore
   0x0000000000435338 <+24>:    lsr     x1, x2, x1
   0x000000000043533c <+28>:    tbz     w1, #0, 0x435348 <ns_js_skp_whs+40>
   0x0000000000435340 <+32>:    ldrb    w1, [x0, #1]!
   0x0000000000435344 <+36>:    cbnz    w1, 0x435330 <ns_js_skp_whs+16>
   0x0000000000435348 <+40>:    ret
```

This looks nothing alike the previous version, and if you had given me just this assembly, I'd have hardly guessed that it was doing a set membership test.

## Assembly analysis

Let's see what's happening here :

### Foreword : ascii translation

Here are the numerical values of the character constants used by the C source file : 
- '\0' : 0
- '\t' : 9 
- '\n' : 10
- '\r' : 13
- ' '  : 32

> Use `man ascii` if you need to know this sort of info.

### Prologue + read.

As per the arm64 calling convention, the argument (`pos`) is in `x0`.

The prologue will load the first character into `w1`, and initialize `x2` with a clever constant that we'll elaborate on. 

```
   0x0000000000435320 <+0>:     ldrb    w1, [x0]
   0x0000000000435324 <+4>:     cbz     w1, 0x435348 <ns_js_skp_whs+40>
   0x0000000000435328 <+8>:     mov     x2, #0x2600                   // #9728
   0x000000000043532c <+12>:    movk    x2, #0x1, lsl #32
```
Notes :
`w1` will be written again when the next character will be loaded.
`x2` will always contain `0x100002600`. 


### Main comparison loop

The next lines contain the core of the comparison trick.

```
   0x0000000000435330 <+16>:    cmp     w1, #0x20
   0x0000000000435334 <+20>:    b.hi    0x435348 <ns_js_skp_whs+40>  // b.pmore
   0x0000000000435338 <+24>:    lsr     x1, x2, x1
   0x000000000043533c <+28>:    tbz     w1, #0, 0x435348 <ns_js_skp_whs+40>
   0x0000000000435340 <+32>:    ldrb    w1, [x0, #1]!
   0x0000000000435344 <+36>:    cbnz    w1, 0x435330 <ns_js_skp_whs+16>
```

The first two lines compares the current character to '0x20' (remember that it is the decimal value for `' '`) and jump to the return section if it is strictly superior to it.

The next two line shift our clever constant by the current character's numerical value and jump to the return section if `the resulting value has its first bit set`. We will come back to this in the next section.

Then, the last two instructions load the next character, updating `pos` in the process, and :
- jump back to the start of the comparison loop if the character is non-null.
- proceed to the return section if the character is null.

## What's going on ?

To understand what's going on, let's take a look at those two lines again :
``` 
   0x0000000000435338 <+24>:    lsr     x1, x2, x1
   0x000000000043533c <+28>:    tbz     w1, #0, 0x435348 <ns_js_skp_whs+40>
```

So there must be something going on with `x2`. Remember that its value throughout the function is `0x100002600`. 

Let's compute the following number :

`(1 << ' ') | (1 << '\r') | (1 << '\n') \ (1 << '\t')` 

<+12>:    movk    x2, #0x1, lsl #32  

## Improvement

Now let's simplify our C function.

As the reader might have guessed, we don't really need the null test, since the set membership test does it for us.

``` C
/*
 * Skip whitespaces.
 */
const char *ns_js_skp_whs(
    const char *pos
)
{
    char c;
    while (((c = *pos) == ' ') || (c == '\r') || (c == '\n') || (c == '\t')) pos++;
    return pos;
}
```

Resulting assembly :
```
(gdb) disassemble ns_js_skp_whs                                                     
Dump of assembler code for function ns_js_skp_whs:
   0x0000000000435320 <+0>:     mov     x2, #0x2600                     // #9728
   0x0000000000435324 <+4>:     movk    x2, #0x1, lsl #32
   0x0000000000435328 <+8>:     b       0x435330 <ns_js_skp_whs+16>
   0x000000000043532c <+12>:    add     x0, x0, #0x1
   0x0000000000435330 <+16>:    ldrb    w1, [x0]
   0x0000000000435334 <+20>:    cmp     w1, #0x20
   0x0000000000435338 <+24>:    b.hi    0x435344 <ns_js_skp_whs+36>  // b.pmore
   0x000000000043533c <+28>:    lsr     x1, x2, x1
   0x0000000000435340 <+32>:    tbnz    w1, #0, 0x43532c <ns_js_skp_whs+12>
   0x0000000000435344 <+36>:    ret
```

And now we see that the null comparison has disappeared.



