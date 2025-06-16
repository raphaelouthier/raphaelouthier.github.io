--- 
title: "Joys of porting a kernel to WebAssembly, Part 2" 
summary: "WebAssembly, or why the toolchain matters."
tags: ["C","wasm","Emscripten", "Kernel","Web Development", "Webassembly","gnu",] 
#externalUrl: "" 
showSummary: true
date: 2021-10-08 
showTableOfContents : true 
draft: false 
---

In the previous part, I introduced the base components of what I consider to be
a minimalistic kernel, and spent some time defining static modules, and why
their correct initialization raises some issues.

In this chapter, I will be going into more details on WebAssembly and describe
the issues I faced when porting my kernel to this environment.

# WebAssembly C Toolchain

Though the work of porting a whole codebase to a browser environment may seem
like a hellish amount of work, the Emscripten toolchain greatly eases the
workload, by providing a C environment resembling (relatively speaking…) to the
posix environment.

The C compiler used for emscripten is LLVM (abstracted by the emcc program),
which helps keep the C developer in a world he is familiar with.

But the pleasure of enjoying compatibility stops here, due to the fact that
WebAssembly chose to reimplement its own object format, instead of using a
familiar standard for its executable format like ELF (Executable and Linkable
Format).

Now, I am not claiming the authority to judge whether this was a bad idea, nor
question their objectives, and I am certain that they had their reasons for
making such a choice. I could, for example, imagine them desiring to get rid of
the executable side of the ELF format (program headers etc…) to avoid wasteful
memory consumption.

In the end, the resulting format shares many similar features with the linkable
side of the ELF format. But as we will observe in the next sections, they also
chose not to support some of the ELF formats useful features that a C developer
may be expecting.

# WebAssembly Object format

A quick look at the official documentation shows that the WebAssembly object
format (the official documentation uses the term “module” but I will rather use
the term “object” to avoid any ambiguity with the concept of module defined in
the previous chapter) is similar to what a C developer expects of a linkable
format, namely: the definition of sections referring to binary data. Each
section having a attributes that define the format and content of this binary
data :

> “ The binary encoding of modules is organized into sections. Most sections
> correspond to one component of a module record, except that function
> definitions are split into two sections, separating their type declarations
> in the function section from their bodies in the code section.”

source : https://webassembly.github.io/spec/core/binary/modules.html

The format defines standard section types, similarly to the ELF format, and
assigns a particular meaning to them, such as code, data, import, etc…

They even provide support for ,what they referred to as custom sections, which
may lead one to think that the feature evocated in the previous chapter
(defining a custom section where a variable should be placed) may be
supportable.

But all our hopes crumble, after observing that the compilation of the
following code doesn’t result in the definition of any custom section :

```C
#include <stdio.h>

__attribute__((section(“.xxx”))) const char *str = “MYSTRING”;

int main() {printf(str);} 
```

Rather, the ‘str’ variable will be placed in the data section, meaning that the
`__attribute__((section(“xxx”)))` is basically ignored :

```C 
wasm-objdump -x main.wasm

main.wasm: file format wasm 0x1

Section Details:

Type[22]: …

Import[3]: …

Function[51]: …

Table[1]: …

Memory[1]: …

Global[3]: …

Export[13]: …

Elem[1]: …

Code[51]: …

Data[3]:

- segment[0] memory=0 size=565 — init i32=1024

- 0000400: 4d59 5354 5249 4e47 0000 0000 3806 0000 MYSTRING….8…

- 0000410: 2d2b 2020 2030 5830 7800 286e 756c 6c29 -+ 0X0x.(null) 
```

For reference, the same file compiled with clang (C frontend for llvm) produces
the expected result of placing the `MYSTRING` data in the custom `xxx` section.
From this we can deduce that there isn’t any issue with the code itself but
rather that the problem lies in the lack of support for this kind of operation
in the emscripten toolchain.

This lack of support is in itself, not an issue for standard-C-compliant
libraries. As the notion of sections resides outside of the C standard’s
jurisdiction, and the `__attribute__` keyword is an extension that just so
happens to be supported by both gcc and clang. But, for any type of software
that relies on the use of sections, WebAssembly will be incompatible.

Though I may seem critical in my conclusion, I perfectly understand the reasons
for this lack of support and their validity.

Indeed the support for programmer-defined custom sections presupposes the
existence of a more complex tool for defining the behaviour of the linker when
merging multiple files containing custom sections.

In order to fill this need, standard toolchains rely on the provision by the
programmer of linker scripts (.ld files), that define these behaviours.

Supporting linker script represents a hellish workload, as such I perfectly
understand why WebAssembly designers chose not to invest time on it, after all
the usage of programmer-defined custom sections is actually very infrequent.

More details on the gnu linker scripts syntax : [Command
Language](https://ftp.gnu.org/old-gnu/Manuals/ld-2.9.1/html_chapter/ld_3.html?source=post_page-----5f0124e71080--------------------------------)

# Conclusion

This article served two purposes.

First, introducing the requirements that may lead a developer to implementing
or using a kernel, and describing the base software blocks that compose a
minimalistic kernel.

Then, showing that the concept of heterogeneous environments (bare-metal,
OS-hosted, Web-browser-hosted) is not simply a concept but a reality, that
implies an heterogeneity of toolchains, which force the developer aiming for
portability to strictly rely on common toolchain capabilities, and that the
lack of support for a toolchain feature may directly prevent particular
programs to be ported to the considered environment.

In my example, the lack of support for user-defined per-variable custom
sections forced me to rewrite parts of my kernel that depended on this
functionality.
