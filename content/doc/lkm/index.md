---
title: "Adding your custom libraries to a Linux Kernel Module."
summary: "Ever dreamed of delegating all your build flow to KBuild ? Me neither."
categories: ["Kernel", "Linux", "C"]
#externalUrl: ""
showSummary: true
date: 2025-09-01
showTableOfContents : true
draft: false
---

## Context

These days I'm working on a project involving FPGAs and PCIe which lead me to become more familiar with linux kernel modules.

I must say that so far I'm really enjoying the experience, as the linux kernel is way more pleasant to work with than my usual XNU.

Though, while doing my first Linux Kernel Module (LKM) trials and errors, I had to solve a problem which may be of broader interest.

I spent a lot of time during the previous decade writing my own kernel. While doing this, I wrote a lot of cross-platform libraries that I find quite useful and that would nicely fit in the module that I'm developing.

Most of my projects are cross-platform, and to support them, I wrote my own (makefile-based) build system, which among other things, makes sure to select the correct platform-dependent files, toolchain, build options and debug scripts for the platform that I'm targeting.

The upside of this is that it is very simple for me to port my existing codebase to a new completely different target.

The downside of this is that it kind of collides with what the Linux kernel expects when it builds your modules for you.

This article shows the different steps required when one wants to build a linux kernel module that includes third party code without adapting their build system to what linux expects.

## Your simplest module.

Here are the steps to build the simplest module that you can think of.

Module source :
``` C
#include <linux/module.h>
#include <linux/kernel.h>

static int __init ini(void) {return 0;}

static void __exit dei(void) {}

module_init(ini);
module_exit(dei);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Me");
MODULE_DESCRIPTION("The bare minimum.");
```

Makefile :
``` Makefile
obj-m := kmod.o
kmod-objs := main.o

all:
        $(MAKE) -C /lib/modules/$(shell uname -r)/build M=$(shell pwd) modules

clean:
        $(MAKE) -C /lib/modules/$(shell uname -r)/build M=$(shell pwd) clean
```

You'll invoke your makefile with `make all` which at the same time :
- build generate kmod.ko
- will build a lot of shit into your local directory. We'll see how to make this manageable later.

Let's see it in action :

```
bt@fedora:/tmp/kmod$ ll
total 32
drwxr-xr-x.  2 bt   bt     80 Sep  1 14:46 ./
drwxrwxrwt. 32 root root 1140 Sep  1 14:46 ../
-rw-r--r--.  1 bt   bt    249 Sep  1 14:45 main.c
-rw-r--r--.  1 bt   bt    192 Sep  1 14:45 Makefile
bt@fedora:/tmp/kmod$ make all
make -C /lib/modules/6.15.10-402.asahi.fc41.aarch64+16k/build M=/tmp/kmod modules
make[1]: Entering directory '/usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k'
make[2]: Entering directory '/tmp/kmod'
  CC [M]  main.o
  LD [M]  kmod.o
  MODPOST Module.symvers
  CC [M]  kmod.mod.o
  CC [M]  .module-common.o
  LD [M]  kmod.ko
  BTF [M] kmod.ko
Skipping BTF generation for kmod.ko due to unavailability of vmlinux
make[2]: Leaving directory '/tmp/kmod'
make[1]: Leaving directory '/usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k'
bt@fedora:/tmp/kmod$ ll
total 768
drwxr-xr-x.  2 bt   bt      420 Sep  1 14:46 ./
drwxrwxrwt. 32 root root   1140 Sep  1 14:46 ../
-rw-r--r--.  1 bt   bt   168600 Sep  1 14:46 kmod.ko
-rw-r--r--.  1 bt   bt      232 Sep  1 14:46 .kmod.ko.cmd
-rw-r--r--.  1 bt   bt        9 Sep  1 14:46 kmod.mod
-rw-r--r--.  1 bt   bt      373 Sep  1 14:46 kmod.mod.c
-rw-r--r--.  1 bt   bt       92 Sep  1 14:46 .kmod.mod.cmd
-rw-r--r--.  1 bt   bt   145448 Sep  1 14:46 kmod.mod.o
-rw-r--r--.  1 bt   bt    70278 Sep  1 14:46 .kmod.mod.o.cmd
-rw-r--r--.  1 bt   bt    13888 Sep  1 14:46 kmod.o
-rw-r--r--.  1 bt   bt      117 Sep  1 14:46 .kmod.o.cmd
-rw-r--r--.  1 bt   bt      249 Sep  1 14:45 main.c
-rw-r--r--.  1 bt   bt    13888 Sep  1 14:46 main.o
-rw-r--r--.  1 bt   bt    70106 Sep  1 14:46 .main.o.cmd
-rw-r--r--.  1 bt   bt      192 Sep  1 14:45 Makefile
-rw-r--r--.  1 bt   bt    12560 Sep  1 14:46 .module-common.o
-rw-r--r--.  1 bt   bt    71000 Sep  1 14:46 ..module-common.o.cmd
-rw-r--r--.  1 bt   bt        7 Sep  1 14:46 modules.order
-rw-r--r--.  1 bt   bt       64 Sep  1 14:46 .modules.order.cmd
-rw-r--r--.  1 bt   bt        0 Sep  1 14:46 Module.symvers
-rw-r--r--.  1 bt   bt      221 Sep  1 14:46 .Module.symvers.cmd
```

What a mess... But you get the idea.

## Providing pre-built objects.

The main problem with the previous approach (apart that it blows up our current working directory but apparently who cares) is that it expects _source_ _files_ to be provided. If you want to build your own stuff yourself, this method is a no-go.

The attentive reader will have noticed two things.

First, the object files to be included in the module are listed in this section of the makefile :
``` Makefile
obj-m := kmod.o <= module object.
kmod-objs := main.o <= objects to build the module from
```
Here no source file is actually provided, only object files.

In our case, since main.o does not exist, but main.c does, KBuild will be smart enough to understand that we want him to build main.o from main.c using gcc. It will use a default build rule and do so.

This allows us to get smart and list another object file `aux.o` that we built ourselves. This object file can define its own symbols, which main.c can use.

Our updated makefile :
``` Makefile
obj-m := kmod.o
kmod-objs := main.o aux.o

all:
        $(MAKE) -C /lib/modules/$(shell uname -r)/build M=$(shell pwd) modules

clean:
        $(MAKE) -C /lib/modules/$(shell uname -r)/build M=$(shell pwd) clean
```

Our updated main.c :
``` C
#include <linux/module.h>
#include <linux/kernel.h>

int ext_fnc(int a);

static int __init ini(void) {
        printk(KERN_INFO "ini : %d.\n", ext_fnc(2));
        return 0;
}

static void __exit dei(void) {}

module_init(ini);
module_exit(dei);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Me");
MODULE_DESCRIPTION("With a third party object.");
```

Our new aux_src.c
``` C
int ext_fnc(int a) {return 2 * a;}
```

Let's build it.
First, I'll try building it without having aux.o generated, which will fail, since aux.o is generated from aux_src.c, and the difference in name prevents KBuild from using its default build rules.
Then I'll build aux.o with gcc, which will allow me to successfully re-build the module :

```
bt@fedora:/tmp/kmod$ ll
total 48
drwxr-xr-x.  2 bt   bt    100 Sep  1 14:59 ./
drwxrwxrwt. 32 root root 1140 Sep  1 14:59 ../
-rw-r--r--.  1 bt   bt     35 Sep  1 14:55 aux_src.c
-rw-r--r--.  1 bt   bt    320 Sep  1 14:57 main.c
-rw-r--r--.  1 bt   bt    198 Sep  1 14:56 Makefile
bt@fedora:/tmp/kmod$ make all
make -C /lib/modules/6.15.10-402.asahi.fc41.aarch64+16k/build M=/tmp/kmod modules
make[1]: Entering directory '/usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k'
make[2]: Entering directory '/tmp/kmod'
  CC [M]  main.o
make[4]: *** No rule to make target 'aux.o', needed by 'kmod.o'.  Stop.
make[3]: *** [/usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k/Makefile:2043: .] Error 2
make[2]: *** [/usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k/Makefile:260: __sub-make] Error 2
make[2]: Leaving directory '/tmp/kmod'
make[1]: *** [Makefile:260: __sub-make] Error 2
make[1]: Leaving directory '/usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k'
make: *** [Makefile:5: all] Error 2
bt@fedora:/tmp/kmod$ gcc -o aux.o -c aux_src.c
bt@fedora:/tmp/kmod$ make all
make -C /lib/modules/6.15.10-402.asahi.fc41.aarch64+16k/build M=/tmp/kmod modules
make[1]: Entering directory '/usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k'
make[2]: Entering directory '/tmp/kmod'
  LD [M]  kmod.o
  MODPOST Module.symvers
  CC [M]  kmod.mod.o
  CC [M]  .module-common.o
  LD [M]  kmod.ko
  BTF [M] kmod.ko
Skipping BTF generation for kmod.ko due to unavailability of vmlinux
make[2]: Leaving directory '/tmp/kmod'
make[1]: Leaving directory '/usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k'
bt@fedora:/tmp/kmod$ sudo insmod kmod.ko; sudo dmesg | tail
[sudo] password for bt:
[ 8724.706297] macsmc-power macsmc-power: Port 1 state change (charge port: 1)
[ 8724.706326] macsmc-power macsmc-power: Unknown charger event 0x71130004
[ 8724.710842] macsmc-power macsmc-power: Charging: 1
[ 8724.759403] macsmc-rtkit 23e400000.smc: RTKit: syslog message: aceElec.cpp:711:      Elec: Elec Cause 0x8000
[ 8725.086489] macsmc-rtkit 23e400000.smc: RTKit: syslog message: aceElec.cpp:711:      Elec: Elec Cause 0x20
[ 8731.223230] macsmc-rtkit 23e400000.smc: RTKit: syslog message: aceElec.cpp:711:      Elec: Elec Cause 0x1000
[ 9482.337632] evm: overlay not supported
[11846.920912] kmod: loading out-of-tree module taints kernel.
[11846.920917] kmod: module verification failed: signature and/or required key missing - tainting kernel
[11846.921526] ini : 4.
```

So that's good.

This trick basically allows us to include _any_ third party library, as long as it is compatible (same compiler, same ISA, and probably other nuances that you don't care about as long as you build your sources yourself).

But in my case, I still had work to do.

## Using the kernel API in our external sources.

In my case I needed to access the linux kernel API from within aux.o.

Let's try it and check what happens :

Updated aux_src.o
``` C
#include <linux/kernel.h>

int ext_fnc(int a) {
        printk(KERN_INFO "I am not from around here.\n");
        return 2 * a;
}
```

Let's build it !
```
bt@fedora:/tmp/kmod$ gcc -o aux.o -c aux_src.c
aux_src.c: In function ‘ext_fnc’:
aux_src.c:5:9: error: implicit declaration of function ‘printk’ [-Wimplicit-function-declaration]
    5 |         printk(KERN_INFO "I am free !\n");
      |         ^~~~~~
aux_src.c:5:16: error: ‘KERN_INFO’ undeclared (first use in this function)
    5 |         printk(KERN_INFO "I am free !\n");
      |                ^~~~~~~~~
aux_src.c:5:16: note: each undeclared identifier is reported only once for each function it appears in
aux_src.c:5:25: error: expected ‘)’ before string constant
    5 |         printk(KERN_INFO "I am free !\n");
      |               ~         ^~~~~~~~~~~~~~~~
      |                         )
```

So that's bad. And if you think it's all going to be a matter of including printk, then let's try it :
```
bt@fedora:/tmp/kmod$ gcc -o aux.o -c aux_src.c
aux_src.c:2:10: fatal error: linux/printk.h: No such file or directory
    2 | #include <linux/printk.h>
      |          ^~~~~~~~~~~~~~~~
compilation terminated.
```
So `one does not simply`.

The problem here is that we are naively using `gcc` to compile for _userspace_, hence, we do not have all the options that KBuild uses to build our `main.c`. KBuild still uses gcc though, but with some carefully chosen parameters, among which there are some include paths that give us access to our precious kernel API.

The solution here is rather simple : we need to find out which gcc parameters KBuild uses and add them to our own command.

We can do this by making KBuild show the verbose output when it builds main.o.

Updated Makefile :
``` Makefile
obj-m := kmod.o
kmod-objs := main.o aux.o

all:
    $(MAKE) -C /lib/modules/$(shell uname -r)/build M=$(shell pwd) V=1 modules

clean:
    $(MAKE) -C /lib/modules/$(shell uname -r)/build M=$(shell pwd) clean
```
(Note the `V=1` in the modules invocation.)

Let's build it :
```
bt@fedora:/tmp/kmod$ touch main.c && make all
make -C /lib/modules/6.15.10-402.asahi.fc41.aarch64+16k/build M=/tmp/kmod V=1 modules
make[1]: Entering directory '/usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k'
make  -C /tmp/kmod \
-f /usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k/Makefile modules
make[2]: Entering directory '/tmp/kmod'
make --no-print-directory -C /tmp/kmod \
-f /usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k/Makefile modules
make -f /usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k/scripts/Makefile.build obj=. need-builtin=1 need-modorder=1
# CC [M]  main.o
  gcc -Wp,-MMD,./.main.o.d -nostdinc -I/usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k/arch/arm64/include -I/usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k/arch/arm64/include/generated -I/usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k/include -I/usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k/include -I/usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k/arch/arm64/include/uapi -I/usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k/arch/arm64/include/generated/uapi -I/usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k/include/uapi -I/usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k/include/generated/uapi -include /usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k/include/linux/compiler-version.h -include /usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k/include/linux/kconfig.h -include /usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k/include/linux/compiler_types.h -D__KERNEL__ -mlittle-endian -DCC_USING_PATCHABLE_FUNCTION_ENTRY -DKASAN_SHADOW_SCALE_SHIFT= -std=gnu11 -fshort-wchar -funsigned-char -fno-common -fno-PIE -fno-strict-aliasing -mgeneral-regs-only -DCONFIG_CC_HAS_K_CONSTRAINT=1 -Wno-psabi -mabi=lp64 -fno-asynchronous-unwind-tables -fno-unwind-tables -mbranch-protection=pac-ret -Wa,-march=armv8.5-a -DARM64_ASM_ARCH='"armv8.5-a"' -DKASAN_SHADOW_SCALE_SHIFT= -fno-delete-null-pointer-checks -O2 -fno-allow-store-data-races -fstack-protector-strong -fno-omit-frame-pointer -fno-optimize-sibling-calls -ftrivial-auto-var-init=zero -fno-stack-clash-protection -fpatchable-function-entry=4,2 -fno-inline-functions-called-once -fmin-function-alignment=8 -fstrict-flex-arrays=3 -fno-strict-overflow -fno-stack-check -fconserve-stack -fno-builtin-wcslen -Wall -Wextra -Wundef -Werror=implicit-function-declaration -Werror=implicit-int -Werror=return-type -Werror=strict-prototypes -Wno-format-security -Wno-trigraphs -Wno-frame-address -Wno-address-of-packed-member -Wmissing-declarations -Wmissing-prototypes -Wframe-larger-than=2048 -Wno-main -Wno-dangling-pointer -Wvla -Wno-pointer-sign -Wcast-function-type -Wno-array-bounds -Wno-stringop-overflow -Wno-alloc-size-larger-than -Wimplicit-fallthrough=5 -Werror=date-time -Werror=incompatible-pointer-types -Werror=designated-init -Wenum-conversion -Wunused -Wno-unused-but-set-variable -Wno-unused-const-variable -Wno-packed-not-aligned -Wno-format-overflow -Wno-format-truncation -Wno-stringop-truncation -Wno-override-init -Wno-missing-field-initializers -Wno-type-limits -Wno-shift-negative-value -Wno-maybe-uninitialized -Wno-sign-compare -Wno-unused-parameter -g -mstack-protector-guard=sysreg -mstack-protector-guard-reg=sp_el0 -mstack-protector-guard-offset=2328  -fsanitize=bounds-strict -fsanitize=shift    -DMODULE  -DKBUILD_BASENAME='"main"' -DKBUILD_MODNAME='"kmod"' -D__KBUILD_MODNAME=kmod_kmod -c -o main.o main.c
make[4]: *** No rule to make target 'aux.o', needed by 'kmod.o'.  Stop.
make[3]: *** [/usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k/Makefile:2043: .] Error 2
make[2]: *** [/usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k/Makefile:260: __sub-make] Error 2
make[2]: Leaving directory '/tmp/kmod'
make[1]: *** [Makefile:260: __sub-make] Error 2
make[1]: Leaving directory '/usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k'
make: *** [Makefile:5: all] Error 2
```

So we have it :
```
 -nostdinc -I/usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k/arch/arm64/include -I/usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k/arch/arm64/include/generated -I/usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k/include -I/usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k/include -I/usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k/arch/arm64/include/uapi -I/usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k/arch/arm64/include/generated/uapi -I/usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k/include/uapi -I/usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k/include/generated/uapi -include /usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k/include/linux/compiler-version.h -include /usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k/include/linux/kconfig.h -include /usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k/include/linux/compiler_types.h -D__KERNEL__ -mlittle-endian -DCC_USING_PATCHABLE_FUNCTION_ENTRY -DKASAN_SHADOW_SCALE_SHIFT= -std=gnu11 -fshort-wchar -funsigned-char -fno-common -fno-PIE -fno-strict-aliasing -mgeneral-regs-only -DCONFIG_CC_HAS_K_CONSTRAINT=1 -Wno-psabi -mabi=lp64 -fno-asynchronous-unwind-tables -fno-unwind-tables -mbranch-protection=pac-ret -Wa,-march=armv8.5-a -DARM64_ASM_ARCH='"armv8.5-a"' -DKASAN_SHADOW_SCALE_SHIFT= -fno-delete-null-pointer-checks -O2 -fno-allow-store-data-races -fstack-protector-strong -fno-omit-frame-pointer -fno-optimize-sibling-calls -ftrivial-auto-var-init=zero -fno-stack-clash-protection -fpatchable-function-entry=4,2 -fno-inline-functions-called-once -fmin-function-alignment=8 -fstrict-flex-arrays=3 -fno-strict-overflow -fno-stack-check -fconserve-stack -fno-builtin-wcslen -Wall -Wextra -Wundef -Werror=implicit-function-declaration -Werror=implicit-int -Werror=return-type -Werror=strict-prototypes -Wno-format-security -Wno-trigraphs -Wno-frame-address -Wno-address-of-packed-member -Wmissing-declarations -Wmissing-prototypes -Wframe-larger-than=2048 -Wno-main -Wno-dangling-pointer -Wvla -Wno-pointer-sign -Wcast-function-type -Wno-array-bounds -Wno-stringop-overflow -Wno-alloc-size-larger-than -Wimplicit-fallthrough=5 -Werror=date-time -Werror=incompatible-pointer-types -Werror=designated-init -Wenum-conversion -Wunused -Wno-unused-but-set-variable -Wno-unused-const-variable -Wno-packed-not-aligned -Wno-format-overflow -Wno-format-truncation -Wno-stringop-truncation -Wno-override-init -Wno-missing-field-initializers -Wno-type-limits -Wno-shift-negative-value -Wno-maybe-uninitialized -Wno-sign-compare -Wno-unused-parameter -g -mstack-protector-guard=sysreg -mstack-protector-guard-reg=sp_el0 -mstack-protector-guard-offset=2328  -fsanitize=bounds-strict -fsanitize=shift
```

Happy ?!

In our case, we especially care about this segment :
```
-I/usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k/arch/arm64/include -I/usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k/arch/arm64/include/generated -I/usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k/include -I/usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k/include -I/usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k/arch/arm64/include/uapi -I/usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k/arch/arm64/include/generated/uapi -I/usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k/include/uapi -I/usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k/include/generated/uapi -include /usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k/include/linux/compiler-version.h -include /usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k/include/linux/kconfig.h -include /usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k/include/linux/compiler_types.h
```
as :
- the `-I` directives will add a given path to the path searched by the preprocessor when resolving the `#include` directives, hence providing access to the correct `<linux/kernel.h>` and giving us access to our precious kernel API.
- the `-include` directives cause a particular header to be included before the compilation even begins. It's as if it injected a `#include [path]` on top of your source file.

The rest consists of compilation flags, warning enablements and disablements `WHICH YOU SHOULD NOT TOUCH` otherwise it will blow up your terminal with endless build warnings or simply fail to build.

Now that we have this, we can actually build aux.o properly using this simple and concise command :

```
bt@fedora:/tmp/kmod$ ll
total 80
drwxr-xr-x.  2 bt   bt     140 Sep  1 15:22 ./
drwxrwxrwt. 32 root root  1140 Sep  1 15:21 ../
-rw-r--r--.  1 bt   bt     116 Sep  1 15:22 aux_src.c
-rw-r--r--.  1 bt   bt     320 Sep  1 15:15 main.c
-rw-r--r--.  1 bt   bt     198 Sep  1 15:21 Makefile
bt@fedora:/tmp/kmod$ gcc -Wp,-MMD,./.main.o.d -nostdinc -I/usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k/arch/arm64/include -I/usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k/arch/arm64/include/generated -I/usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k/include -I/usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k/include -I/usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k/arch/arm64/include/uapi -I/usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k/arch/arm64/include/generated/uapi -I/usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k/include/uapi -I/usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k/include/generated/uapi -include /usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k/include/linux/compiler-version.h -include /usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k/include/linux/kconfig.h -include /usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k/include/linux/compiler_types.h -D__KERNEL__ -mlittle-endian -DCC_USING_PATCHABLE_FUNCTION_ENTRY -DKASAN_SHADOW_SCALE_SHIFT= -std=gnu11 -fshort-wchar -funsigned-char -fno-common -fno-PIE -fno-strict-aliasing -mgeneral-regs-only -DCONFIG_CC_HAS_K_CONSTRAINT=1 -Wno-psabi -mabi=lp64 -fno-asynchronous-unwind-tables -fno-unwind-tables -mbranch-protection=pac-ret -Wa,-march=armv8.5-a -DARM64_ASM_ARCH='"armv8.5-a"' -DKASAN_SHADOW_SCALE_SHIFT= -fno-delete-null-pointer-checks -O2 -fno-allow-store-data-races -fstack-protector-strong -fno-omit-frame-pointer -fno-optimize-sibling-calls -ftrivial-auto-var-init=zero -fno-stack-clash-protection -fpatchable-function-entry=4,2 -fno-inline-functions-called-once -fmin-function-alignment=8 -fstrict-flex-arrays=3 -fno-strict-overflow -fno-stack-check -fconserve-stack -fno-builtin-wcslen -Wall -Wextra -Wundef -Werror=implicit-function-declaration -Werror=implicit-int -Werror=return-type -Werror=strict-prototypes -Wno-format-security -Wno-trigraphs -Wno-frame-address -Wno-address-of-packed-member -Wmissing-declarations -Wmissing-prototypes -Wframe-larger-than=2048 -Wno-main -Wno-dangling-pointer -Wvla -Wno-pointer-sign -Wcast-function-type -Wno-array-bounds -Wno-stringop-overflow -Wno-alloc-size-larger-than -Wimplicit-fallthrough=5 -Werror=date-time -Werror=incompatible-pointer-types -Werror=designated-init -Wenum-conversion -Wunused -Wno-unused-but-set-variable -Wno-unused-const-variable -Wno-packed-not-aligned -Wno-format-overflow -Wno-format-truncation -Wno-stringop-truncation -Wno-override-init -Wno-missing-field-initializers -Wno-type-limits -Wno-shift-negative-value -Wno-maybe-uninitialized -Wno-sign-compare -Wno-unused-parameter -g -mstack-protector-guard=sysreg -mstack-protector-guard-reg=sp_el0 -mstack-protector-guard-offset=2328  -fsanitize=bounds-strict -fsanitize=shift -o aux.o -c aux_src.c
aux_src.c:3:5: warning: no previous prototype for ‘ext_fnc’ [-Wmissing-prototypes]
    3 | int ext_fnc(int a) {
      |     ^~~~~~~
bt@fedora:/tmp/kmod$ make all
make -C /lib/modules/6.15.10-402.asahi.fc41.aarch64+16k/build M=/tmp/kmod modules
make[1]: Entering directory '/usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k'
make[2]: Entering directory '/tmp/kmod'
  CC [M]  main.o
  LD [M]  kmod.o
  MODPOST Module.symvers
  CC [M]  kmod.mod.o
  CC [M]  .module-common.o
  LD [M]  kmod.ko
  BTF [M] kmod.ko
Skipping BTF generation for kmod.ko due to unavailability of vmlinux
make[2]: Leaving directory '/tmp/kmod'
make[1]: Leaving directory '/usr/src/kernels/6.15.10-402.asahi.fc41.aarch64+16k'
bt@fedora:/tmp/kmod$ sudo insmod kmod.ko; sudo dmesg | tail
[ 8725.086489] macsmc-rtkit 23e400000.smc: RTKit: syslog message: aceElec.cpp:711:  Elec: Elec Cause 0x20
[ 8731.223230] macsmc-rtkit 23e400000.smc: RTKit: syslog message: aceElec.cpp:711:  Elec: Elec Cause 0x1000
[ 9482.337632] evm: overlay not supported
[11846.920912] kmod: loading out-of-tree module taints kernel.
[11846.920917] kmod: module verification failed: signature and/or required key missing - tainting kernel
[11846.921526] ini : 4.
[13250.275691] I am not from around here.
[13250.275697] ini : 4.
```

So all jokes aside, even if one can think that this list of flags is absurdly long :
- this is the required list of flags used by KBuild and any missing entry could cause an incompatibility. So we must use them anyway.
- the process to actually get those flags is pretty straightforward and will be the subject of the next section.

All those tricks cumulated allow us to effectively abstracting us from KBuild by :
- compiling all our sources our own way, provided that we now have the correct build flags to do it. Our sources will be able to access all kernel APIs normally accessible to modules.
- merging all our own object files into a single object file with `ld -r ...`.
- providing this single object file containing all our code to KBuild alongside our `main.c`
- calling symbols defined by our object file from within our main.c.

Goal fulfilled !.

Now let's make things a bit easier.

## Automatically extracting the proper flags for your build system.

Let's be frank, no one wants to manually go through the pain of :
- creating a test makefile.
- creating a test module init.
- invoking KBuild in verbose mode.
- manually copy-pasting the right flags and referencing that in a third party build system.

So the following script does it for you :
``` python
#! /bin/python3

########
# Deps #
########

import os
import subprocess

################
# Toy makefile #
################

mkf = """
obj-m := stp.o
stp-objs := main.o

KDIR := /lib/modules/$(shell uname -r)/build
PWD  := $(shell pwd)

all:
        $(MAKE) -C $(KDIR) V=1 M=$(PWD) modules

clean:
        $(MAKE) -C $(KDIR) M=$(PWD) clean
"""

########
# Main #
########

# Reset.
os.system("rm -rf /tmp/kmod_stp")
os.system("mkdir /tmp/kmod_stp")

# Generate the makefile.
os.system(f"echo '{mkf}' > /tmp/kmod_stp/Makefile")

# Generate a (faulty) module main.
os.system(f"echo '' > /tmp/kmod_stp/main.c")

# Call linux module build, let it compile main.c and fail, but capture the flags.
output = subprocess.getoutput("make -C /tmp/kmod_stp all")

# Isolate the gcc command.
lins = output.split("\n")
cmd = None
for lin in lins:
        lin = lin.strip();
        if lin.startswith("gcc"):
                cmd = lin
                break
if cmd == None:
        print("gcc command not found.")
        exit(1)

# Isolate the interesting part.
cmd = cmd.split("-DMODULE")[0]
cmd = cmd.split("main.o.d")[1]

# Replace system version with a call to uname. Only works within a makefile.
nam = subprocess.getoutput("uname -r")
cmd = cmd.replace(nam, "$(shell uname -r)")

# Add a default include of <linux/kernel.h>. Not delicate but easier to work with.
cmd += "-include /usr/src/kernels/$(shell uname -r)/include/linux/kernel.h"

# Reference the build flags in my build system.
os.system(f"echo '.bprf.tgt.cc += {cmd}' > ../tch/linux.kernel.mk")
```

One can ignore the last two lines as they are specific to 1 my own needs and 2 my build system but the remaining part should suit your needs.

## Making KBuild go play in its own room.

In the first section we saw that KBuild is a bit messy and generates a ton of stuff that we don't care about.

We certainly need to have them as they may contain valuable data to debug linkage issues with our module, but we'd like to have them generated not in the middle of the room...

I'm sad to say that I didn't find a nice way to _just_ instruct kbuild to throw up in a specific directory. Rather, it seems programmed to generate its stuff in the _same_ directory that the Makefile is placed in.

So if we want it to generate its stuff in our build directory (`./build`) then the most (and only) straightforward way to do this is to just move the Makefile in the build directory.

In my build system I can't really do this as my Makefile actually creates the build directory, so I went one step uglier and had my Makefile generate `another makefile` in the build directory which only takes care of calling KBuild with the proper paths, and recurse into it by running `make -C build all`.

FTR here's the generate one-liner makefile, don't mind my own `-DKMOD_XXX` which are specific to my system :
```
cat build/Makefile
all:;make -C /lib/modules/6.15.10-402.asahi.fc41.aarch64+16k/build CFLAGS_prc/kmod.o="-DKMOD_NAM=\"TMP\" -DKMOD_ATH=\"BT\" -DKMOD_DSC=\"temp module\" -DKMOD_LCS=\"GPL\" -DKMOD_INI=\"prc_lkm_main\" " M=/home/bt/bt/work/prj/lkm/build obj-m=mod.o mod-objs="prc/kmod.o prc/prc.o" modules
```

I can't say I'm proud of that one, but at least it refrains KBuild's insanity.

