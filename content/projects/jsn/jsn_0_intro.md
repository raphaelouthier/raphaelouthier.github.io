--- 
title: "TurboJSON : JSON basics." 
summary: "Bases on JSON and how to parse it semi-efficiently."
series: ["Json optimization"]
series_order: 0
categories: ["C","ARM64","Optimization"] 
#externalUrl: "" 
showSummary: true
date: 2025-07-30 
showTableOfContents : true 
draft: false 
---

{{< figure src="images/jsn_0_head.png" >}}


## Context

While working on this project (TODO LINK) involving ARM64 register programming I quickly felt the need to have a small command line tool that would give me some info on a given register, to avoid constantly looking in the ARM64 spec.

Luckily for me, ARM folks did a great job (this time) and they nowadays release "machine-readable" descriptors of their ISA, in the form of gigantic JSON files describing among other things every register available.

> A while ago I had to implement an ARM32 emulator for my uKasan, but at that time I only had found the XML human-readable version which was a real pain to parse.
This JSON spec is MUCH better and I can't thank ARM folks enough for it.

But simplicity never lasts long : when I can, I prefer re-coding my libraries myself and avoid relying on third party code, as well as programming in C.

Back then for uKasan, after looking for 2 long minutes at the  immediately defaulted to python after looking at the [XML's EBNF](https://www.liquid-technologies.com/Reference/Glossary/XML_EBNF1.1.html) I quickly decided to doubly hold my nose and to :
- rely on a third party XML parsing library.
- use python.

which kinda hurt, let's be honest.

But JSON is a whole simpler kind of beast. A glance a the [JSON EBNF](https://gist.github.com/springcomp/e72d09e3a8f06e8d711751c3d1ee160e) will show you how simple it is compared to XML.

I have already implemented a couple of JSON parsers for past use cases, but those were small JSON files, and I cared more about the functionality itself than about its performance.

This time, it is different : the ARM64 Register descriptor is 82MB wide, so the parsing time is non-neglectible.

My wish was to have my little command line database load as quickly as possible, and the more it progressed, the more it looked like it could deserve its own article.

First, we will start by some general considerations on the JSON format and its parsing.
Then, we'll discuss some algorithmic optimizations that can increase the performance.
Then, we'll go a level below and try to optimize some steps of the parsing algorithm at the assembly level to increase the performance even more.

## The JSON format

Anyone interested in the exact JSON syntax spec should definitely go checkout [this dedicated website](https://www.JSON.org/JSON-en.html). It is great, and very clearly defines all the basic JSON data structures, so clearly that I was just tempted to post screenshots of it in this article. But I refrained.

Long story very short, the JSON file defines the basic value structure which can be any of :
- null : equivalent to void or none. Indicates the value of the XML format these days.
- boolean : false or true.
- number : decimal positive or negative integer or float.
- string : sequence of chars delimited by double quotes, backslashed characters have special meanings.
- array : sequence of values separated by commas and delimited by brackets.
- object : sequence of `key (string) : value` separated by commas and delimited by brackets.

Note that the beauty of the JSON is that the array and object structures contain values and hence make this format recursive. That will matter when we'll discuss parsing.

The json spec essentially defines the low level features of our parser. It will need to recognize every entity supported by the spec and parse it correctly.

## Skipping, and why it matters

A parser is a piece of code able to extract and process data structured in a given format.

A counter-intuitive fact is that in practice, a (linear) parser is essentially a skip engine : at any given time, it knows :
- the position in the parsed file where it is at;
- what entity is at the current position.
- how to skip the current entity, aka move to the following.

Let's see this with an example.

> In all this section, we will ignore whitespaces to keep the explanation simple.

Let's suppose that our parser is at the start of an object, and that it wants to extract some information contained in this object.
The parser needs to skip the object start. The json format defines '{' as a single-character array start, so the parser can simply move to the next character.
The parser is now at a string start. As per the json format, the current char should be '"'. After checking this fact, the parser can move to the next character.
The parser is now in a string body. The json format defines that the string will end with a '"' not preceded by a '/'. It can move to the next character until it detects it. If the string should be stored somewhere, it can copy it directly.
The parser is now at a string end '"'. It can move to the next character.
The parser is now at a key-value separator. After checking that the current character is ':', it can move to the next character.
The parser is now at a value start. It can now call the generic value parser which will :
- detect the value's first character; and
- call the relevant substructure parser based on it; and
- return the location at which parsing should resume (i.e : the location of the first character after the value.
The parser is now at either :
- an array end '}', in which case the parsing is done and the parser returns the location of the character after the '}'; or
- a key:value separator ',', in which case the parser reiterates the key-value parsing routine.

So far, you can see that our parser is just a character skip engine with benefits : sometimes it may copy those characters or process them (for integer parsing), but what really matters is that it knows how to skip the current entity, in order to move to the next.

But you should also realize that skipping an entity is non-trivial.
In order for our object to be fully parsed (skipped), we will have needed to skip _ every single entity that composed it _.

This fact alone gives us the first golden rule of json parsing :

{{< alert >}}
DO NOT PARSE THE SAME VALUE TWICE.
{{< /alert >}}

We previously saw that the json spec itself defines almost entirely the low level aspect of our parser. But there is one question that is still pending : how are we going to use those low level features ? How are we going to parse our json's components ?

So before elaborating on the implications of the first rule, we need to define the high level features of our parser.

## Parsing a data exchange format

A JSON file is essentially a data container. But are we always interested in all the information that it contains ?

In our case, the answer is no. The ARM64 json spec describes _everything_ about the registers and instruction, but there are many things that we are not interested in (like "Accessors" ?!).

The job of our parser will be to extract _targetted_ information.

For example, in our case, the ARM64 register spec is a gigantic array of register descriptors, where each register descriptor has a lot more info that we care about.

> In the following section, [.] means "all entries of the array", and ["xxx"] means the value of the current object indexed by "xxx".

``` C
What we care, and the way to access it in the json is :
- root : array : register descriptor.
  - [.] : object : register descriptor.
    - ["name"] : str : register name.
    - ["purpose"] : str : register purpose (null 99% of the time).
    - ["title"] : str : register title (null 99% of the time).
    - ["fieldets"] : array : layouts for this register (bad naming).
      - [.] : object : layout descriptor.
        - ["width"] : int : layout size in bits.
        - ["values"] : array : bitfield descriptor (any suggestion for a more confusing name ?).
          - [.] : object : bitfield descriptor.
            - ["name"] : str : bitfield name.
            - ["rangeset"] : array : of bit range descriptors.
                - [.] : object : bitfield descriptor.
                  - ["start"] : int : bitfield start.
                  - ["width"] : int : bitfield size.
```

Our parser's high level features hence sound pretty simple :
- iterate over every element of an array and parse each element with a dedicated function.
- iterate over _a_ _certain_ _set_ of object elements indexed by specific keys and parse them with a dedicated function.

Our previously established golden rule will have a consequence on the second feature : since we must avoid parsing anything twice, we can't afford to lookup an object once for each key that we are looking for. We will need to parse the object once and extract all elements in the order in which they appear.

## Sample headers, macros and parsing code

Here are the declarations of both the low level and high level parts of the parser :

{{< collapsible-code path="content/projects/jsn/prs_api.h" lang="c" title="Spec of the JSON parser." >}}

A few notes :
- the `Skip API` section defines the low level part of the parser. As we covered previously, it is mostly composed of functions that receive a pointer to the start of a particular entity, and that return the location of the next character after this entity.
- the `Array parsing` and `Object parsing` sections define functions that allow a granular parsing of those containers, substructure by substructure.
- the `Iteration` sections define macros that expand into for statements which use the container parsing utilities defined by the section above, they allow iterating over all elements of a container in a very compact way.
- the `NS_JS_XTR` macro is the toplevel primitive to use to parse an object. In one single object processing sequence, it allows the simple extraction of a specified set of `key:value`. Since the types of the results of the parsing of those values depends on what we are parsing, it cannot be implemented as a function. Rather, it is a macro that expands into the dedicated object parsing sequence. It also automatically defines the variables that contain the result of the parsing.
- If one takes a closer look at the `NS_JS_XTR` macro, they will notice that it internally uses macros prefixed by `NS_PRP` that it does not define. Those are part of my preprocessor tricks lib, which is out of the scope of this topic, but in particular :
  - `NS_PRP_CAL(name, separator, ...)` expands into a call to `name` with every value passed in `__VA_ARGS__`.
  - `NS_PRP_CDT_EMP(cdt) (code)` will expand to `code` if `cdt` is empty and to nothing if `cdt` is not empty.
  - `NS_PRP_CDT_EMP(cdt) (code)` will expand to nothing if `cdt` is empty and to `code` if `cdt` is not empty.

Now let's take a look at the code to extract (and simply print) the data that we need from the register spec.

{{< collapsible-code path="content/projects/jsn/reg_xtr_m0.c" lang="c" title="ARM64 register spec extraction code using the JSON parser." >}}

A few notes :
- this relies heavily on my own standard library (all the ns_ prefixed stuff). In particular :
- printing is made via `info`, format specifiers may look weird (`%U` for 64 bits integers). That's normal, since I use my own format decoder I took the liberty to reassign a few specifiers to cover up the stdlib's madness. In particular, `%u` and `%U` are unsigned ints, `%i` and `%I` are for signed ints, `%f` is for float, and `%d` is for double (in practice both are the same, given how the C handles float promotion in variadic args).
- since we just print, parsers do not return anything. If we want to not _just_ print, we can allocate structures on the fly with `malloc`, initialize them with the parsed data and return them. As long as the parser signatures are changed to reflect this, and that the parent callers do not lose track of them, no problem.

Actually, let's do it.

Here is the code that parses the arm register db and that stores it in a tree-like data structure.

{{< collapsible-code path="content/projects/jsn/reg_xtr_m1.c" lang="c" title="ARM64 register spec extraction code using the JSON parser." >}}

Notes :
- while writing this code I renamed a few things, so the reader will notice changes in the parser names. No functional change is implemented.
- allocation is performed using `ns_alloc__` which performs variable def, allocation and size computation at once for less C code.
- the code uses some functions of my own (non-)standard library, namely, my linked list lib (`ns_dls`) and my map (`ns_map`) lib, so as their dedicated iterators.

## Base performance metrics

First, to have a vague idea of what is considered an acceptable decoding time, let's have the ARM64 register file decoded by another library.

Here I chose python for simplicity.

``` python
import json
json.load(open('/home/bt/Downloads/armdb/Registers.json'))
```

Let's run it and check how much time it takes.

```
$ time python3 /tmp/test.py
real    0m0.403s
user    0m0.326s
sys     0m0.055s
```

Here, let's remember that we're asking python to :
- decode the whole file, which our case study code has to also do, because of what we covered earlier.
- construct a python object tree to contain _all_ _the_ _information_ contained in the JSON file.

Hence, we're here asking python to do things that we are not doing on our side, so the python execution time must be considered just as a point of reference, and not as a relevant performance metric.

Just out of curiosity, I took a shot at doing the same thing (decoding the whole file and generating a C-like containerized version) with a library (`ct`) that I wrote a few years ago. This library is not optimized (it likely does some parsing multiple times) and its perf most certainly sucks but you'll see that the execution time (which is worse than python) stays in the same order of magnitude.

``` C

/*
 * rdb main.
 */
u32 prc_rdb_main(
        u32 argc,
        char **argv
)
{

        /* Open and map the reg db. */
        ns_res stg_res;
        ns_stg *stg = nsk_stg_opn(&stg_res, "/home/bt/Downloads/armdb/Registers.json");
        assert(stg);
        char *jsn = ns_stg_map(stg, 0, 0, ns_stg_siz(stg), NS_STG_ATT_RED | NS_STG_ATT_WRT);
        assert(jsn);

        /* Parse the whole file and generate a tree-like representation. */
        ct_val *v = ct_js_parse_value((const char **) &jsn);

        /* Yeah I know I didn't delete @v, it's just for show, who cares... (valgrind does...) */

        return 0;

}
```

Then let's run it :

```
$ time build/prc/prc

real    0m0.591s
user    0m0.573s
sys     0m0.017s
```

> The reader may wonder as I did why the python side spends so much system time compared to mine. As you can see in the C code, I'm mmap-ing the whole JSON file in RAM for simplicity, which also has the benefit of not relying on `fread` constantly. It's possible that the python side does rely on constant `fread`s which could explain this. Bad job on my side for doing worse than this if that's so.

I'm taking around 50% more time to do it because my library is bad, but again, it's just to give you a rough estimate of how much time it takes on my machine to decode that large file.

Well, actually it may not be just because my lib is bad. I checked my build command and here it was : 
```
gcc -Ibuild/prc/inc -Ibuild/lib/inc -MMD -O0 -DDEBUG -Wall -Wextra -Wconversion -Wshadow -Wundef -fno-common -Wall -Wno-unused-parameter -Wno-type-limits -g -o build/prc/obj/rdb/rdb.c.o -c prc/rdb.c
```

{{< alert >}}
I was building for debug with optimizations disabled ...
{{< /alert >}}

Fixing the brain and the build mode gives a better result.

```
 time build/prc/prc
real    0m0.189s
user    0m0.174s
sys     0m0.014s
```

So I'm running quicker than python but again, both times are in close order of magniture. 


Now, let's run the code that I showed you at the end of the previous section, which actually extracts register info and does something with it.

This JSON decoder is _relatively_ performant, in the sense that it does not do anything stupid like parse the same content multiple times (which my previous example certainly did). It also does not create a full in-memory representation of all the data in the JSON file.

Here I'm having it decode the values of a register's bitfield given the register name and a value for it.

```
$ time build/prc/prc dec -n PMUSERENR -v 10
PMUSERENR : 32
- [0]     : EN : 0x0
- [1]     : SW : 0x1
- [2]     : CR : 0x0
- [3]     : ER : 0x1

real    0m0.054s
user    0m0.050s
sys     0m0.004s
```

This duration is statistically relevant (run it multiple times and you'll get a reasonably close time), and reliably reflects the JSON parsing time : just to be sure, I purposefully removed all the data allocation and deallocation, and it was statistically the same : all the execution time is spent in parsing the JSON.

Hence, this time will be our base performance metric for the next chapters.

Let's see how much we can shrink it !


## Conclusion

This article should have stated the base notions required to understand what JSON is, how it is parsed, and the potential difficulties and perf problems that arise when doing so.

The next part will show some high level algorithmic tricks to make this process more efficient.

## Bonus : why I made this command line tool

With that json database, a simple command line tool can do a lot of things for you. Here are the features that matter to me as a machine-level programmer :

```
$ build/prc/prc -h
Available rdb commands :
  lst : list registers.
  reg : show info about a register.
  dec : decode the value of a register.
  lyt : generate a C register layout struct.
```

List registers starting with a prefix.

```
$ build/prc/prc lst -n PMU
PMU
PMUACR_EL1
PMUSERENR
PMUSERENR_EL0
```

Generate a C struct to directly manipulate bitfields in an easy way. Let's see it in action with the ARM CPSR.

```
$ build/prc/prc lyt -n CPSR
typedef union {
        uint32_t bits;
        struct {
                uint32_t M : 4;
                uint32_t __res0 : 2;
                uint32_t F : 1;
                uint32_t I : 1;
                uint32_t A : 1;
                uint32_t E : 1;
                uint32_t __res1 : 6;
                uint32_t GE : 4;
                uint32_t __res2 : 7;
                uint32_t Q : 1;
                uint32_t V : 1;
                uint32_t C : 1;
                uint32_t Z : 1;
                uint32_t N : 1;
        };
} CPSR_t;

```

(`dec` just does what `reg` does with the added decoding and I already covered `dec` in the previous section.)

