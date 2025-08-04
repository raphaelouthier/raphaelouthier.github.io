--- 
title: "Assembly trick : char set membership test." 
summary: "Tesing if a char is in a set of chars as fast as possible."
categories: ["C","Assembly",] 
#externalUrl: "" 
showSummary: true
date: 2025-08-03 
showTableOfContents : true
---

## C level

When working on [this project](/prj/jsn/jsn_0_intro), I took a look at how the compiler would digest this code :

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

``` asm
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

```asm
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

This looks nothing like the previous version, and if you had given me just this assembly, I'd have hardly guessed that it was doing a set membership test.

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

```asm
   0x0000000000435320 <+0>:     ldrb    w1, [x0]
   0x0000000000435324 <+4>:     cbz     w1, 0x435348 <ns_js_skp_whs+40>
   0x0000000000435328 <+8>:     mov     x2, #0x2600                   // #9728
   0x000000000043532c <+12>:    movk    x2, #0x1, lsl #32
```
Notes :
`w1` will be written again when the next character is loaded.
`x2` will always contain `0x100002600`.


### Main comparison loop

The next lines contain the core of the comparison trick.

```asm
   0x0000000000435330 <+16>:    cmp     w1, #0x20
   0x0000000000435334 <+20>:    b.hi    0x435348 <ns_js_skp_whs+40>  // b.pmore
   0x0000000000435338 <+24>:    lsr     x1, x2, x1
   0x000000000043533c <+28>:    tbz     w1, #0, 0x435348 <ns_js_skp_whs+40>
   0x0000000000435340 <+32>:    ldrb    w1, [x0, #1]!
   0x0000000000435344 <+36>:    cbnz    w1, 0x435330 <ns_js_skp_whs+16>
```

The first two lines compare the current character to '0x20' (remember that it is the decimal value for `' '`) and jump to the return section if it is strictly superior to it.

The next two lines shift our clever constant by the current character's numerical value and jump to the return section if `the resulting value has its first bit set`. We will come back to this in the next section.

Then, the last two instructions load the next character, updating `pos` in the process, and :
- jump back to the start of the comparison loop if the character is non-null.
- proceed to the return section if the character is null.

## What's going on ?

To understand what's going on, let's take a look at those two lines again :
```asm
   0x0000000000435338 <+24>:    lsr     x1, x2, x1
   0x000000000043533c <+28>:    tbz     w1, #0, 0x435348 <ns_js_skp_whs+40>
```

So there must be something going on with `x2`. Remember that its value throughout the function is `0x100002600`.

Let's compute the following number :

`(1 << ' ') | (1 << '\r') | (1 << '\n') \ (1 << '\t')`

<+12>:    movk    x2, #0x1, lsl #32

## Better C generates better assembly.

Let's simplify our C function.

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
```asm
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

## LSR weirdness

One could wonder why those two lines are required, as we are later comparing against a bitmask.

```asm
   0x0000000000435334 <+20>:    cmp     w1, #0x20
   0x0000000000435338 <+24>:    b.hi    0x435344 <ns_js_skp_whs+36>  // b.pmore
```

This is due to a weirdness in the behavior of LSR.

Quoting the [aarch64 spec](https://developer.arm.com/documentation/ddi0602/2022-12/Base-Instructions/LSRV--Logical-Shift-Right-Variable-?lang=en) :

```
LSRV <Xd>, <Xn>, <Xm>
...
Xm : Is the 64-bit name of the second general-purpose source register holding a shift amount from 0 to 63 in its bottom 6 bits, encoded in the "Rm" field.
```

This causes the following shifts behave exactly the same :

```asm
    # shift by 0
    mov x1, #0x00
    # or shift by 64
    mov x1, #0x40
    # will produce the original value if used as a shift operand.
    lsr x0, x0, x1
```

This essentially means that this LSR trick only works with shifts < 0x40, which mandates a compare + branch to compare. Here the compiler was smart enough to detect the range of our set and just added an upper bound comparison.

{{< alert >}}
This behavior is different from the behavior of ARMV7's LSR which read the entire byte. For this architecture, the compare + branch would not be needed.
Always know the version of the architecture that you're writing your assembly for, otherwise you may end up with surprises.
{{< /alert >}}

## Improving it.

Some improvements can still be made to this function :
- 1 : it loads the constant with two instructions.
- 2 : it branches at the start of the function, to skip the initial add. This is dumb as it causes a branch + the extra x0 add will be executed at each iteration.
- 3 : the main loop has two branches : we first check that the current char is < 0x20, and then we test if it is in the target set.

We can update the code the following way : 
- we'll hardcode the constant after the code and do a PC-relative load. This may or may not be a good idea as a load may take time, but the PC-local cache line is probably in cache. 
- we will always add 1 to x0 during the ldrb to make the loop more compact, and we will decrement x0 before `ret`. This is OK since we only return once but may execute the loop multiple times.

The third point will be more interesting to update : 
- first, let's note that the bitmask trick works for constants up to 63, due to :
  - the register mask size.
  - the behavior of LSR in aarch64.
- thus, we can replace the `is <= 0x20` check by a `is < 0x40` check in the code without any change of behavior.
- this is equivalent to checking that bits 6 and 7 of our character are 0.
- so now we can rephrase our check : `test that bits 6 and 7 of the character are 0, and that the bitmask shifted by the character value has bit 0 set.`
- with a CSEL (conditional select) we can rework our assembly to do the following : 
  - if bits 6 or 7 of `x1` are set, then store 0 in `x1`. 
  - otherwise store the shifted mask in `x1`
  - then, test bit 0 of `x1` and branch back if it is set.

Here is the resulting assembly :

```asm
(lldb) dis
prc`ns_js_skp_whs:
->  0x4294c0 <+0>:  ldr    x2, 0x4294e0 ; <+32>
    0x4294c4 <+4>:  ldrb   w1, [x0], #0x1
    0x4294c8 <+8>:  tst    w1, #0xc0
    0x4294cc <+12>: lsr    x1, x2, x1
    0x4294d0 <+16>: csel   x1, x1, xzr, eq
    0x4294d4 <+20>: tbnz   w1, #0x0, 0x4294c4 ; <+4>
    0x4294d8 <+24>: sub    x0, x0, #0x1
    0x4294dc <+28>: ret
    0x4294e0 <+32>: udf    #0x2600
    0x4294e4 <+36>: udf    #0x1
```

> I had to switch to LLDB as GDB was choking on my hand-written assembly function : it was hanging at program start.

