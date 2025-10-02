--- 
title: "TurboJSON : Assembly-level optimization." 
summary: "Trying machine-specific approaches."
series: ["Json_optimization"]
series_order: 1
categories: ["Json optimization"]
tags: ["C","ARM64","Optimization"] 
#externalUrl: "" 
showSummary: true
date: 2025-09-05 
showTableOfContents : true 
---


## Introduction.

In the previous chapter we introduced a bunch of C-level tricks to optimize our parsing.

We now will dive at the assembly level to explore how we can increase performance even further.

Two warnings before we start.

First, the assembly world is cruel and cold. You may spend hours working on what you believe to be a clever optimization using fancy SIMD instructions and discover that they simply worsen your perf by a factor of 2. You'll actually see this in practice. This chapter will essentially be an enumeration of the different assembly variants of string and array skip, which occupy the most of our json parser. Do not expect any fun story here. It will be _just_ that, and watching my slow descent into insanity.

Working at the assembly level essentially means trying to find out how we can tune our assembly to be executed more efficiently by our processor, which is heavily dependent on its microarchitecture. A trick that works well on a given machine may actually not work / decrease the performance on another machine with the same architecture but a different microarchitecture.

As an example, let's imagine two hypothetical ARM64 machines, one with a very efficient branch predictor which accurately predicts at a 95% rate, and another with no branch predictor at all, or a very simple and stupid one.

The first machine will essentially always successfully speculate, which means that our job will be to increase the instructions bandwidth regardless of branches. The second machine's speculation capabilities will be doubtful, and our first job will be to reduce to a minimum the number of branches, using tricks like conditional arithmetics to reduce their number. This will lead to programs that look very different. You'll see an example of that and associated performance metrics on my machine.

## Calling assembly from C.

As stated before, this chapter will essentially be a summary of my autistic assembly-writing frenzy. I'll cover many versions of programs that do exactly the same thing (skipping strings and skipping arrays) but with different perf metrics.

It is important for our C code to be able into the selected assembly variant as easily as possible.

To do this, we'll use two things : the `weak` attribute and an assembly trampoline.

First, we'll prefix our two C functions `ns_js_fsk_str` and `ns_js_fsk_arr` by `__attribute__((weak))`, which will tell the compiler that the provided definition should only use as a backup in case no other function (generally, symbol) with the same name is provided at link time.

The last two words, `link time` do matter here. Indeed, since weak symbol resolution is done at link time, this `by design` prevents the compiler from inlining behind our back and reduces the scope of its optimizations.

Let's see that in action : here are the perf metrics for a run without the `weak` attribute :
```
 nkb &&  taskset -c 4  build/prc/prc -rdb /tmp/regs.json -C 10 -c 10
Compiling arm64.S
Packing lib_ns.o
Auto-packing build/prc/prc.o
Auto-linking build/prc/prc
stp 0 : 36.591.
stp 1 : 29.859.
stp 2 : 29.650.
stp 3 : 29.682.
stp 4 : 29.681.
stp 5 : 29.677.
stp 6 : 29.690.
stp 7 : 29.682.
stp 8 : 29.687.
stp 9 : 29.681.
stp 10 : 29.670.
stp 11 : 29.680.
stp 12 : 29.682.
stp 13 : 29.687.
stp 14 : 29.682.
stp 15 : 29.697.
stp 16 : 29.671.
stp 17 : 29.709.
stp 18 : 29.717.
stp 19 : 29.719.
Average : 29.691.
```

Now here are the perf metrics with the `weak` attribute.

```
nkb &&  taskset -c 4  build/prc/prc -rdb /tmp/regs.json -C 10 -c 10
Compiling arm64.S
Packing lib_ns.o
Auto-packing build/prc/prc.o
Auto-linking build/prc/prc
stp 0 : 39.208.
stp 1 : 31.896.
stp 2 : 31.672.
stp 3 : 31.717.
stp 4 : 31.703.
stp 5 : 31.713.
stp 6 : 31.726.
stp 7 : 31.761.
stp 8 : 31.725.
stp 9 : 31.725.
stp 10 : 31.708.
stp 11 : 31.718.
stp 12 : 31.717.
stp 13 : 31.723.
stp 14 : 31.699.
stp 15 : 31.711.
stp 16 : 31.712.
stp 17 : 31.715.
stp 18 : 31.725.
stp 19 : 31.765.
Average : 31.719.
```

So just by letting the C code call into our assembly functions, we already lost perf. We'll compensate for that later on.

{{< alert >}}
In the rest of the article I'll stop showing the perf iterations and just show the average, since there will be many of them.
{{< /alert >}}

On the assembly side we'll define trampoline functions named like our C functions, and which call the variant of our choice.

``` asm
   .align 4
   .global ns_js_fsk_str
   .type   ns_js_fsk_str, %function
s_js_fsk_str:
   b ns_js_fsk_str1
   .size   ns_js_fsk_str, .-ns_js_fsk_str

    .align 4
    .global ns_js_fsk_arr
    .type   ns_js_fsk_arr, %function
ns_js_fsk_arr:
    b ns_js_fsk_arr22
    .size   ns_js_fsk_arr, .-ns_js_fsk_arr
```

That sets us up for assembly programming.

## String skip.

Our json file is mostly composed of strings and skipping them quickly is important.

Our first optimization will be centered around `ns_js_fsk_str`.

### Compiler version.

``` asm
(lldb) dis -n ns_js_fsk_str
prc`ns_js_fsk_str:
0x45cd80 <+0>:  ldrb   w1, [x0], #0x1
0x45cd84 <+4>:  mov    w3, #0x5c ; =92
0x45cd88 <+8>:  mov    w2, w1
0x45cd8c <+12>: ldrb   w1, [x0], #0x1
0x45cd90 <+16>: cmp    w1, #0x22
0x45cd94 <+20>: ccmp   w2, w3, #0x4, eq
0x45cd98 <+24>: b.eq   0x45cd88       ; <+8> at js.c:605:3
0x45cd9c <+28>: ret
```

Clever as usual, it generates a minimal loop which reads incrementally, and remembers the last character.

As mentioned in the previous chapter, this algorithm is actually incorrect, as to parse an actual json string, we must keep track of the number of backslashes preceding a quote, and consider it a string end only if it is even.

### Variant 0 : using SIMD

SIMD&FP is mandatory in AARCH64 and is supported by my processor.

We'll use a [CMEQ](https://developer.arm.com/documentation/ddi0596/2021-09/SIMD-FP-Instructions/CMEQ--register---Compare-bitwise-Equal--vector--) to compare 8 characters at a time to `"`, and break at the first match. Then we'll count trailing 0s to determine the location of the first encountered quote, adjust the char pointer to this location. Finally, we'll count the number of `\`s preceding the quote and break if it is even.

{{< collapsible-code path="content/art/jsn_2_asm/str_0.h" lang="asm" title="Using CMEQ to compare 8 chars at a time." >}}

Multiple factors make this code efficient :
- counting the `/`s after we find the quote makes the loop lightweight.
- guarding the `/`s count behind a branch makes the branch predictor systematically skip this section, as backslashed quotes are very rare.

```
Average : 29.081.
```

This already compensated for the perf loss caused by the `weak` attribute.

For now this is the only variant for the str skip, though I may give a try to the multi-read trick shown in the array skip section.

## Array skip.

As shown by valgrind in the previous chapter, we spend most of our time in `ns_js_fsk_arr`. This makes it our main target for optimization.

All this section will cover this function, and the perf metrics shown will include the trick shown in the section about `ns_js_fsk_str`.

Our baseline will hence be :
```
Average : 29.081.
```

### C code

As a reminder, here is our base optimized C code :

``` C
s8 ns_js_fsk_arr_tbl [255] = {
   [']'] = -1,
   ['['] = 1
};

#define ITR(pos, v, cnt, qt, op, cl, tbl) \
        for (u8 i = 0; i < 8; pos++, i++, v >>= 8) { \
                u8 c = (u8) v; \
                cnt += tbl[c]; \
                if (!cnt) { \
                        return pos + 1; \
                } \
                if (c == qt) { \
                        pos = ns_js_fsk_str(pos); \
                        goto stt; \
                } \
        }

/*
 * Skip an array.
 */
_weak_ const char *ns_js_fsk_arr(
        const char *pos
)
{
        check(*pos == '[');
        pos++;
        u32 cnt = 1;
        while (1) {
                stt:;
                uint64_t v = *(uint64_t *) pos;
                uint64_t v1 = *(uint64_t *) (pos + 8);
                ITR(pos, v, cnt, '"', '[', ']', ns_js_fsk_arr_tbl);
                ITR(pos, v1, cnt, '"', '[', ']', ns_js_fsk_arr_tbl);
        }
}

```

We make two memory reads of 64 bits, then iterate over each byte.

Let's see what gcc does with that.

### Compiler version.

Here is the version generated by gcc :

{{< collapsible-code path="content/art/jsn_2_asm/arr_cpl.h" lang="asm" title="GCC output." >}}

Though it is kind of difficult to read, its working principle is kind of simple :

First, it initializes a couple of things, and enters the main loop.

Then it reads our two u64s with :

``` asm
0x45cde8 <+28>:  ldur   x2, [x1, #0x1]
0x45cdec <+32>:  ldur   x3, [x1, #0x9]
```

Then it processes each byte of the two registers with 16 sections like this :
``` asm
0x45ce08 <+60>:  ubfx   w5, w2, #8, #8
0x45ce0c <+64>:  add    x1, x0, #0x1
0x45ce10 <+68>:  ldrsb  w4, [x20, w5, sxtw]
0x45ce14 <+72>:  adds   w19, w19, w4
0x45ce18 <+76>:  b.eq   0x45cfd0       ; <+516> at js.c:666:1
0x45ce1c <+80>:  cmp    w5, #0x22
0x45ce20 <+84>:  b.eq   0x45cfe0       ; <+532> at js.c:663:3
```

Each of these will process one specific byte (selected via `ubfx`), and store the address of the current char in `x1`, so that the quote or end-of-array sections know where we are. Then the lookup table is accessed via `ldrsb`, the array nesting counter is computed with `adds`, and finally, both exit conditions are checked : if either a quote or an end of array is encountered in this section, the CPU jumps to the relevant section.

Performance notes :
- instead of the `store x0 + offset in x1` dance, we could just have incremented `x0`, but this would decrease perf, as it creates artificial register dependencies that prevent the CPU from reordering or executing in parallel. GCC knows that and avoids those.
- we are always writing in `x1` or `w5` or `w4`, but register renaming breaks those write-after-write artificial dependencies for us and allows their parallel execution.

If no quote or end-of-array is encountered, the next u64s are loaded via :

``` asm
0x45cfb8 <+492>: ldp    x2, x3, [x0]
```

and the byte-processing sequence is restarted.

This version is full of branches, but branch prediction being as perfect as it is, it does not matter. We'll take a look at variants of this algorithm and explain this in more details.

### Variant 0 : set membership test.

We'll use a variant of the char membership test described [here](/art/asm_trk_0_set). `"[]` are in a less-than-64-wide range in the ascii charset, so we can just initialize a mask in `x5` with their locations and use the `lsr` trick on the current char to quickly identify them.

If we see them, then we compare them manually. Otherwise we jump back.

{{< collapsible-code path="content/art/jsn_2_asm/arr_0_mbm.h" lang="asm" title="Using a set membership test to detect []\"." >}}

The perf numbers for this method are catastrophic :

```
Average : 44.022.
```

The reason why this is bad is because we don't let branch prediction enough branches to make accurate predictions. In the algorithm above, every section had its own branches and BP could just index them all. Here it just has one loop branch and three char branches to make a compound prediction for all of them.

On top of that, the loop is very short and all instructions have true data dependencies (RAW) which cause the CPU to execute them in order.

### Variant 1 : SIMD-based char membership test.

We'll try our luck with the SIMD world again.

Ideally we'd like to try to port the previous method with SIMD. Though we can't do this as variant 0's method as-is requires a 64 bits mask to do the set membership test.

We'll use the method described in [a dedicated article](/art/asm_trk_1_set) and use this expression as a detector :

```
({u8 shf = (((c - '"') ^ ((u8) 1 << 5)) - (u8) 25); !((shf <= 7) && ((0xa1 >> shf) & 1));})
```

It involves only 8 bit values which makes it perfectly suitable for SIMD.

{{< collapsible-code path="content/art/jsn_2_asm/arr_1_simd_mmb.h" lang="asm" title="A more complex but SIMD-compatible set membership test." >}}

On the perf side this solution is better than the previous one but that was not very hard. It's still pretty bad.

```
Average : 38.264.
```

### Variant 2 : CMEQ + EOR3.

The previous membership test is clever but it has too much true data dependencies which makes its execution necessarily sequential and degrades perf.

We can do a more stupid but better code which will just use `CMEQ` three times and gather the results. Each `CMEQ` will compare 8 chars with either `"`, `[` or `]`. We'll use the special `EOR3` instruction which does a three-way exclusive or. Since a char can only be equal to one of those, in our case, EOR is semantically equivalent to a `OR`.

{{< collapsible-code path="content/art/jsn_2_asm/arr_2_simd_cmeq.h" lang="asm" title="Replacing our set membership test by a dump three-way comparison." >}}

All the CMEQs are independent with the others, which allows them to be executed in parallel. The EOR3 depends on all of them and must wait for their completion to execute, but it is still better than our previous one.

Perf agrees :
```
Average : 34.119.
```

We're still pathetic compared to GCC, but we're progressing.

### Variant 3 : screw it let's just do like GCC.

Previous iterations have shown that my SIMD attempts were nice but GCC just lols at them if we compare perf numbers.

There's something the GCC solution does well : it reads once, and processes every byte, inlining each processing, leaving a lot of room for branch prediction to cause correct speculation.

We'll start by a simple re-implementation of what GCC does (without the weird loop tail and 16 bytes processing).

{{< collapsible-code path="content/art/jsn_2_asm/arr_3_gcc.h" lang="asm" title="The GCC way because apparently we're no match." >}}

Perf is nice, as expected :
```
Average : 29.399
```

We're already under what we started with so we're on a good track here. We'll just have to try and improve that a bit.

### Variant 4 : why speculate when you can just do it.

Explaining why the following trick improves performance requires a bit of theory.

Branch prediction is usually accurate but sometimes it's not.

In this case, the CPU has to flush its pipeline and start re-executing at the correct instruction.

Modern CPUs basically speculate at every branch, since we can't realistically wait for the result of a comparison (which can take more than 10 cycles) to just fetch the next instruction. That's the reason why branch prediction exists : located at the fetch stage, it predicts the value of the next PC from the current one.

This also implies that when the actual result of a comparison used in a conditional branch is effectively known, the CPU must retro-check that the branch target inferred by the branch predictor was accurate. If so, it just marks subsequent instructions as non-speculative. If not, it cancels their execution by flushing them out of the pipeline and reverting the CPU's structures to the state they were before the branch's effects started.

This flush is a very convoluted and expensive process, which consumes cycles and degrades the CPU's performance. Consider it a double edged sword : if you predict accurately, your perf goes through the roof. If you don't, your perf goes through the floor.

Let's take a look at our next variant.

{{< collapsible-code path="content/art/jsn_2_asm/arr_4_nobp.h" lang="asm" title="Moving `UBFX` and `LDRSB` out of the speculation window." >}}

The code is simple enough : we do exactly like the previous time, but we move the first four `UBFX` + `LDRSB` at the start of the loop.

```
Average : 29.360.
```

The difference is very small but it is consistent.

What we did is essentially to move those 8 instructions out of many reordering windows, into a code section with no branches.

This set of instructions is composed of two subgroups which only contain independent instructions, and hence, which can be dispatched in parallel, increasing the final throughput.

Here we're taking advantage of the fact that those instructions will statistically all be executed, by making them effectively executed all the time.

But as the next example shows, there's not much room for improvement here.

### Version 5 : messing up with branch-pred too much.

We'll try to apply the previous trick to the last 4 bytes of our uint64_t too and see what we get.

{{< collapsible-code path="content/art/jsn_2_asm/arr_5_missbp.h" lang="asm" title="Making things a bit too non-conditional." >}}

```
Average : 29.810.
```

Well that's bad.

What we can conclude here is that the instructions that we made non-conditional were actually correctly identified by the branch prediction-side as not being executed in reality.

By making them non-conditionally executed, we ended up increasing the instruction count of our program, which decreased the performance.

### Variant 6 : let's reduce the branch count and destroy our perf.

One could think that since branches cause speculation which takes time to undo if incorrect, performance could be increased by reducing the speculation requirements i.e removing branches in our program.

Here is a variant that reads 4 bytes at a time, then processes them without branches using conditional compares and selects.

{{< collapsible-code path="content/art/jsn_2_asm/arr_6_nob.h" lang="asm" title="What the hell am I doing with my Sunday..." >}}

Two comments :
- it is not working. I tried re-running it when writing this article and it did not pass my testbench successfully. There's something wrong with it but frankly I don't care, because
- it is dramatic for perf. From my notes at the time where it was working it literally multiplied the execution time by more than 5.

So let's discontinue this approach in the first trash can that we find and move along.

### Apparte : macroifying our byte-processing logic.

Most readers that are still here (Kudos) will probably be tired of seeing the same compulsive ubfx+ldrsb+adds+branch sequence.

So at this point in my development I grew a brain and made those macros to simplify the reading.

Here is the sequence for the record.

``` asm
.macro xtr_cmp1 xrg_src, xrg_dst, xrg_dat, xrg_tbl, wrg_ctr, xrg_tm0, wrg_tm0, wrg_tm1, bit_stt, val_qot, val_add, lbl_out, lbl_qot
        ubfx \xrg_tm0, \xrg_dat, #0 + \bit_stt, #8
        add \xrg_dst, \xrg_src, #\val_add
        ldrsb \wrg_tm1, [\xrg_tbl, \wrg_tm0, sxtw]
        adds \wrg_ctr, \wrg_ctr, \wrg_tm1
        b.eq \lbl_out;
        cmp \xrg_tm0, #\val_qot
        b.eq \lbl_qot;
.endm

.macro xtr_cmp2 xrg_src, xrg_dst, xrg_dat, xrg_tbl, wrg_ctr, xrg_tm0, wrg_tm0, wrg_tm1, val_qot, val_bas, lbl_out, lbl_qot
        xtr_cmp1 \xrg_src, \xrg_dst, \xrg_dat, \xrg_tbl, \wrg_ctr, \xrg_tm0, \wrg_tm0, \wrg_tm1, 0, \val_qot, \val_bas + 0, \lbl_out, \lbl_qot
        xtr_cmp1 \xrg_src, \xrg_dst, \xrg_dat, \xrg_tbl, \wrg_ctr, \xrg_tm0, \wrg_tm0, \wrg_tm1, 8, \val_qot, \val_bas + 1, \lbl_out, \lbl_qot
.endm

.macro xtr_cmp4 xrg_src, xrg_dst, xrg_dat, xrg_tbl, wrg_ctr, xrg_tm0, wrg_tm0, wrg_tm1, val_qot, val_bas, lbl_out, lbl_qot
        xtr_cmp1 \xrg_src, \xrg_dst, \xrg_dat, \xrg_tbl, \wrg_ctr, \xrg_tm0, \wrg_tm0, \wrg_tm1, 0, \val_qot, \val_bas + 0, \lbl_out, \lbl_qot
        xtr_cmp1 \xrg_src, \xrg_dst, \xrg_dat, \xrg_tbl, \wrg_ctr, \xrg_tm0, \wrg_tm0, \wrg_tm1, 8, \val_qot, \val_bas + 1, \lbl_out, \lbl_qot
        xtr_cmp1 \xrg_src, \xrg_dst, \xrg_dat, \xrg_tbl, \wrg_ctr, \xrg_tm0, \wrg_tm0, \wrg_tm1, 16, \val_qot, \val_bas + 2, \lbl_out, \lbl_qot
        xtr_cmp1 \xrg_src, \xrg_dst, \xrg_dat, \xrg_tbl, \wrg_ctr, \xrg_tm0, \wrg_tm0, \wrg_tm1, 24, \val_qot, \val_bas + 3, \lbl_out, \lbl_qot
.endm

.macro xtr_cmp8 xrg_src, xrg_dst, xrg_dat, xrg_tbl, wrg_ctr, xrg_tm0, wrg_tm0, wrg_tm1, val_qot, val_bas, lbl_out, lbl_qot
        xtr_cmp1 \xrg_src, \xrg_dst, \xrg_dat, \xrg_tbl, \wrg_ctr, \xrg_tm0, \wrg_tm0, \wrg_tm1, 0, \val_qot, \val_bas + 0, \lbl_out, \lbl_qot
        xtr_cmp1 \xrg_src, \xrg_dst, \xrg_dat, \xrg_tbl, \wrg_ctr, \xrg_tm0, \wrg_tm0, \wrg_tm1, 8, \val_qot, \val_bas + 1, \lbl_out, \lbl_qot
        xtr_cmp1 \xrg_src, \xrg_dst, \xrg_dat, \xrg_tbl, \wrg_ctr, \xrg_tm0, \wrg_tm0, \wrg_tm1, 16, \val_qot, \val_bas + 2, \lbl_out, \lbl_qot
        xtr_cmp1 \xrg_src, \xrg_dst, \xrg_dat, \xrg_tbl, \wrg_ctr, \xrg_tm0, \wrg_tm0, \wrg_tm1, 24, \val_qot, \val_bas + 3, \lbl_out, \lbl_qot
        xtr_cmp1 \xrg_src, \xrg_dst, \xrg_dat, \xrg_tbl, \wrg_ctr, \xrg_tm0, \wrg_tm0, \wrg_tm1, 32, \val_qot, \val_bas + 4, \lbl_out, \lbl_qot
        xtr_cmp1 \xrg_src, \xrg_dst, \xrg_dat, \xrg_tbl, \wrg_ctr, \xrg_tm0, \wrg_tm0, \wrg_tm1, 40, \val_qot, \val_bas + 5, \lbl_out, \lbl_qot
        xtr_cmp1 \xrg_src, \xrg_dst, \xrg_dat, \xrg_tbl, \wrg_ctr, \xrg_tm0, \wrg_tm0, \wrg_tm1, 48, \val_qot, \val_bas + 6, \lbl_out, \lbl_qot
        xtr_cmp1 \xrg_src, \xrg_dst, \xrg_dat, \xrg_tbl, \wrg_ctr, \xrg_tm0, \wrg_tm0, \wrg_tm1, 56, \val_qot, \val_bas + 7, \lbl_out, \lbl_qot
.endm
```

Now that we're done covering that complete mess, and that I gave you even less reasons for continuing your reading, let's proceed to a variant that will improve the perf for once.

### Variant 7 : skipping spaces.

A simple look at the non-simple JSON from ARM (yeah you might have forgotten but all of this is just because I wanted to parse this quickly...) shows that it's just full of spaces.

>One could say "Hey man why don't you just re-process your json" but WHO DOES THAT ? The rules are the rules and we're not gonna change them just because it would make sense, right ? If so, what's next ? Converting our json DB to a binary file and processing it entirely in what, 0.5ms, no fkng way, I'll waste as many watts as I can and stick with my stupid rules.

More seriously, there is a bit of obsession going on right here, I won't deny it, but I'm using this challenge as an exercise to improve perf with a stable input, as sometimes, you don't choose the data that your program has to ingest and finding optimization schemes basing on that data is a useful skill.

Our next step will hence be to read 16 bytes at a time, compare the first 8 with spaces (with a simple cmp) and if they are all spaces, move to the next set of 8 (with only one 8 bytes read required).

{{< collapsible-code path="content/art/jsn_2_asm/arr_7_byp.h" lang="asm" title="Fast forward if 8 chars are spaces." >}}

```
Average : 25.906.
```

We actually _did_ improve the performance with that one.

Let's do one last improvement so that I can finally move on with my life.

### Variant 8 : Bypass 16 bytes, use 4 bytes.

Our final variant will process chars in a combined way. First it will read 8 bytes at a time (16 initially to sorta-pre-fetch), and will skip spaces 8 bytes at a time. Then once it finds the first 8 byte word that contains no spaces, it will select the first half that contains a non-space character, and then process those resulting 4 bytes.

{{< collapsible-code path="content/art/jsn_2_asm/arr_8_22.h" lang="asm" title="Find the first non-space 4 bytes and process them. Then redo it." >}}

```
Average : 22.176.
```

Yay !

## Conclusion.

I must say that I'm proud of that result. It took a lot of sanity and time but so far that's the best time I've scored.

One possible improvement would be to implement the same compound-byte-processing trickery that we used in the string skip processing logic, but I need to move on to other projects and am happy with my current result.

