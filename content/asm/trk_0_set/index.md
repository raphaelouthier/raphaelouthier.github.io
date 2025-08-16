--- 
title: "Assembly trick : char set membership test." 
summary: "Tesing if a char is in a set of chars as fast as possible."
categories: ["C","Assembly",] 
#externalUrl: "" 
showSummary: true
date: 2025-08-03 
showTableOfContents : true
---



While I was working on [my json parser project](/prj/jsn/jsn_0_intro) I took a look at how the compiler had digested the following
whitespace skipping code : 


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
The diligent reader may note that this function could be much shorter. We'll cover this in a moment.
{{< /alert >}}

## Assembly level -o0

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

### ASCII translations

Here are the numerical values of the character constants used by the C source file :

| char | ASCII value |
|-----------|-------------|
| `\0`      | 0           |
| `\t`      | 9           |
| `\n`      | 10          |
| `\r`      | 13          |
| `' '`     | 32          |

> Use `man ascii` if you need to know this sort of info.

### Prologue + read

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

The first two lines compare the current character to `0x20` (remember that it is the decimal value for `' '`) 
and jump to the return section if it is strictly superior to it.

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

`(1 << ' ') | (1 << '\r') | (1 << '\n') | (1 << '\t')`

which translates to :

`(1 << 32) | (1 << 13) | (1 << 10) | (1 << 9)`

which gives :

`0x100000000 | 0x2000 | 0x400 | 0x200`

which gives us back our mysterious `x2` constant :

`0x100002600`.

Now as the reader may realize, shifting this number back by any of `{' ', '\r', '\n', '\t'}` will cause bit 0 to be set.

This is how, with a simple shift and test of bit 0, we can detect that a char is a member of a given set.

The applicability of this trick depends on :
- the register size. Here, we can only test among a set of constants with values of 63 or less.
- the behavior or LSR, as the dedicated section will cover.

## Better C generates better assembly

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
This behavior is different from the behavior of ARMV7's LSR which reads the entire byte. For this architecture, the compare + branch would not be needed.
Always know the version of the architecture that you're writing your assembly for, otherwise you may end up with surprises.
{{< /alert >}}

## Improvement : simple fixes

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

## Improvement : using smarter instructions

Let's change the high level algorithm : we'll update the range of supported constants to check to [0, 62] and be sure to have bit 63 set to 0.

We'll then use [this instruction](https://developer.arm.com/documentation/ddi0602/2025-06/Base-Instructions/UMIN--immediate---Unsigned-minimum--immediate--?lang=en) to assign a value to 63 to everything superior to 63, which will effectively exclude all those chars of the match set :

``` asm
prc`ns_js_skp_whs:
    0x4294c0 <+0>:  ldr    x2, 0x4294dc ; <+28>
    0x4294c4 <+4>:  ldrb   w1, [x0], #0x1
    0x4294c8 <+8>:  umin   w1, w1, #0x63
    0x4294cc <+12>: lsr    x1, x2, x1
    0x4294d0 <+16>: tbnz   w1, #0x0, 0x4294c4 ; <+4>
    0x4294d4 <+20>: sub    x0, x0, #0x1
    0x4294d8 <+24>: ret
    0x4294dc <+28>: udf    #0x2600
    0x4294e0 <+32>: udf    #0x1

```

When compiling, we see a strange compiling error :
```
Compiling arm64.S
arm64.S: Assembler messages:
arm64.S:15: Error: selected processor does not support `umin w1,w1,0x63'
make: *** [Makefile:755: build/lib/obj/_tgt_ns/arm64.S.o] Error 1
```

This is due to the target that I'm compiling my assembly file with :
```
   .arch armv8.5-a
```

As the AARCH64 doc says, this instruction is only available if `FEAT_CSSC` is available in the target architecture, and this feature is optional in ARMV8.5. Adding this feature to the supported assembly fixes the build error.

```
   .arch armv8.5-a+cssc
```

Though, we're not at the end of our troubles, as it appears that my computer (Apple M2 with Asahi) doesn't support this instruction :

``` asm
lldb build/prc/prc
(lldb) target create "build/prc/prc"
Current executable set to '/home/bt/bt/work/emb/build/prc/prc' (aarch64).
(lldb) run
Process 31568 launched: '/home/bt/bt/work/emb/build/prc/prc' (aarch64)
Process 31568 stopped
* thread #1, name = 'prc', stop reason = signal SIGILL: illegal opcode
    frame #0: 0x00000000004294c8 prc`ns_js_skp_whs + 8
(lldb) dis
prc`ns_js_skp_whs:
    0x4294c0 <+0>:  ldr    x2, 0x4294dc ; <+28>
    0x4294c4 <+4>:  ldrb   w1, [x0], #0x1
->  0x4294c8 <+8>:  umin   w1, w1, #0x63
    0x4294cc <+12>: lsr    x1, x2, x1
    0x4294d0 <+16>: tbnz   w1, #0x0, 0x4294c4 ; <+4>
    0x4294d4 <+20>: sub    x0, x0, #0x1
    0x4294d8 <+24>: ret
    0x4294dc <+28>: udf    #0x2600
    0x4294e0 <+32>: udf    #0x1
```

The instruction is not supported by my CPU hence it generated a sync exception reporting an undefined instruction when encountering it.

This version is thus not-applicable to my CPU but teaches us a great lesson in optimization :

{{< alert >}}
The architecture that your CPU runs on matters a lot as it affects the set of tricks at your disposal to grind perf.
{{< /alert >}}

## Doing it in C

OK so now we know this super clever trick used by the compiler.
We can now just use it in our C code to avoid relying on the compiler's cleverness.
We just have to carefully compute the masks, which can be easily achieved by two macros and some bitwise trickery :

``` C
/*
 * Skip whitespaces.
*/
_weak_ const char *ns_js_skp_whs(
    const char *pos
)
{

    /* Produce a bitmask for a char range. stt must be <= end. Undefined behavior otherwise. */
    #define RANGE(stt, end) ((((u64) 1 << ((end) + 1 - (stt))) - 1) << (stt))
    #define VALUE(c) RANGE(c, c)

    /* Compute the whitespace mask. */
    const u64 msk = VALUE(' ') | VALUE('\r') | RANGE('\t', '\n');

    /* Process naively. This line purposefully has a bug which the next section will cover. */                                                          
    char c;
    while ((msk >> (c = *pos)) & 0x1) pos++;

    /* Complete. */
    return pos;
}
```

Let's compile it in `-o0` just to prevent the compiler from being clever, and be horrified by the resulting assembly.

``` asm
(lldb) disassemble  -n ns_js_skp_whs
prc`ns_js_skp_whs:
0x4505f0 <+0>:  sub    sp, sp, #0x20
0x4505f4 <+4>:  str    x0, [sp, #0x8]
0x4505f8 <+8>:  mov    x0, #0x2600 ; =9728
0x4505fc <+12>: movk   x0, #0x1, lsl #32
0x450600 <+16>: str    x0, [sp, #0x18]
0x450604 <+20>: b      0x450614       ; <+36> at js.c:93:20
0x450608 <+24>: ldr    x0, [sp, #0x8]
0x45060c <+28>: add    x0, x0, #0x1
0x450610 <+32>: str    x0, [sp, #0x8]
0x450614 <+36>: ldr    x0, [sp, #0x8]
0x450618 <+40>: ldrb   w0, [x0]
0x45061c <+44>: strb   w0, [sp, #0x17]
0x450620 <+48>: ldrb   w0, [sp, #0x17]
0x450624 <+52>: ldr    x1, [sp, #0x18]
0x450628 <+56>: lsr    x0, x1, x0
0x45062c <+60>: and    x0, x0, #0x1
0x450630 <+64>: cmp    x0, #0x0
0x450634 <+68>: b.ne   0x450608       ; <+24> at js.c:93:39
0x450638 <+72>: ldr    x0, [sp, #0x8]
0x45063c <+76>: add    sp, sp, #0x20
0x450640 <+80>: ret
```

> I mean what the hell is that... Why is it even using any stack at all... That's where `-o0` gets you.

But between two retches we can still see that the compiler uses the same mask plus shift than earlier which is exactly what we want.

## C undefined behaviors and why we care

Looking at the assembly in the section above, the attentive reader may ask :
{{< alert >}}
We're using `LSR` right ? So how about the comparison with 64 ? Where is the check and jump that was previously used by the compiler itself ?
{{< /alert >}}

This is a legit question, as in its current state, given what we covered earlier, *this algorithm is not working*.

But confusingly enough, the compiler was actually right in its assembly generation.

To explain why, let's refer to [GNU's C documentation at section 3.8 on bit shifting](https://www.gnu.org/software/gnu-c-manual/gnu-c-manual.html#Bit-Shifting) :
> For both << and >>, if the second operand is greater than the bit-width of the first operand, or the second operand is negative, the behavior is undefined.

So basically our C program has a bug : it should manually check for the value of the char and only shift if it is less than (<) 64, otherwise, the result of the shift is undefined.

From the compiler's standpoint, words matter : undefined means 'whose behavior is not defined', understand 'whose behavior can legitimately produce any result'. Hence, the compiler does not have to ensure what result the operation has and could theoretically do everything it wants. Here, it simply used the aarch64 `LSR` instruction and stuck to its behavior. But for all intents and purposes, it could very well have generated an assembly sequence that :
- checks the char range and aborts if >= 64. or
- checks the char range and moves 0xdeadbeef in x0 instead of the shift result. or
- blows up your machine.

All those scenarios would all have been perfectly acceptable behaviors as per the C standard.

This teaches us one other optimization lesson :
{{< alert >}}
Beware of undefined behaviors. They may cause your optimization to work on a given platform/compiler, and not on others.
{{< /alert >}}

