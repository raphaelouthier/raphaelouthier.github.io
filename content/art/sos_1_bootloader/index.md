---
title: "ScratchOS : Firmware"
summary: "Back to the nibble age."
series: [ScratchOS]
series_order: 1
categories: [ScratchOS]
tags: ["ScratchOS"]
#externalUrl: ""
showSummary: true
date: 2026-03-27
showTableOfContents : true
draft: false
---

## Rpi2040 : what we care about

### CPUs

The RPI2040 features two cortex M0+ CPUs, able to execute both thumb-1 and thumb-2 (truncated) ISA..

Thumb 1 instructions are 16 bits wide and that's perfect for us since it'll make a very dense binary.

Thumb 2 instructions are 32 bits wide and we'll try to avoid using them.

When we jump to an arbitrary location with bx <addr>, if the target is a thumb instruction, we must tell the CPU that it is so by adding one to the target address.


### Memory

The RPI2040 features :
- a RO (fixed at manufacturing) 16KiB ROM mapped at [0, 0x1000[;
- a RW 264KiB SRAM mapped at [0x20000000, 0x0x20042000[;
- a NA (for now) 16MiB Flash mappable at [0x10000000, 0x11000000[;

### Flash

Upon reset the flash is not mapped, and a subsystem in the chip must be configured to map it.

### GPIO

The RPI2040 has 29 available GPIOs.

GPIO 25 is used as an LED.

On reset, each pin is usable as input.

All GPIOs input values can be read at once by reading 0xd0000004.

All GPIOs modes (input, output) can be set at once by writing at 0xd0000024.

All GPIOs output states can be set high by writing 1s at 0xd0000014 and low by writing 1s at 0xd0000018.

To set a GPIO in output mode, we also need to set its AF to 5 (SIO). GPIO25's control register can be written at 0x400140cc to do so.

IO_BANK0 which sets the AF of each pin stays on RESET mode after reset. Reset needs to be deasserted (bit 5 of 0x4000c000) before using IO_BANK0. Reset status can be found at 0x4000c008.

### Boot sequence : stage 1

After reset, both CPUs start executing the stage 1 bootloader located at address 0, in the bootrom.

CPU 1 gets parked, and CPU 0 loads the stage 2 bootloader (256 bytes max) from Flash and copies it in SRAM at address 0x20041f00.

The stage 1 bootloader does not configure the flash mapping system.

Rather, it retrieves the 252 bytes of the stage 2 bootloader by running raw flash commands, and copies them at address 0x20041f00.

While doing so, it computes a 4 bytes checksum of the copied data and verifies that the last 4 bytes of the flash bootloader matches this section.

Then, it jumps to 0x20041f00 to execute the copied stage 2 bootloader.

The stage 2 bootloader will be our initial firmware.

### CRC = PITA

I have tried in vain to manually calculate the checksum myself and generate the final binary by hand with a dd-like command.

It was pointless and I lost more time that I wanted to this so I just went on and installed [uf2-util](https://crates.io/crates/uf2-util) which I found in [this article](https://sharpcoder.medium.com/baremetal-pico-venturing-beyond-the-bootloader-e70578c4048d) written by the author of the tool.

It saved me some sanity and I am grateful for this tool's existence.

## Firmware

### Goals

Our firmware's objective is to let us input arbitrary code and execute it.

Code input will be done via GPIO, and a LED will help us verify that it actually receives our data.

We need one pin for the led (GPIO25), one pin to report that data can be captured (GPIO0), one pin to report that data stage is done and the firmware should start executing the received code (GPIO1), and data pins.

Initially I'll have to provide data manually so I'd rather make it as least painful as possible.

I'll use spare keyboard switches that I have around to update GPIO values.

I'll need one finger to press the execute button but this needs to be done once at the end so ergonomy is not important.

What matters is efficiency in data input.

I'll need one finger to press the capture button everytime I want to input data.

That leaves 4 fingers available, which is cool since it means I can provide four bits at the time to the firmware.

This will require GPIO2, GPIO3, GPIO4 and GPIO5 to serve as our 4 data bits.

### Behavior

Upon startup, the firmware configures GPIOs and initializes the write (byte) pointer to the start of the copy region (SRAM_START + BOOTLOADER_SIZE) = 0x20000100.

Then it executes the capture loop (iteration numbers start at 0) :
- 0 : turn led off.
- 1 : whenever GPIO 0 is pressed long enough, move to step 1. Otherwise, stay in step 1.
- 2 : turn led on.
- 3 : read the 4 data GPIOs.
- 4 : whenever GPIO 0 is released long enough, move to step 5. Otherwise, stay in step 4.
- 5 : if we capture a byte start (even iteration number) store the nibble somewhere. Otherwise (odd iteration number) then write the stored nibble and the current nibble into memory at the write pointer, and increment the write pointer.
- 6 : if the exec button is pressed long enough, exit the loop. Otherwise, move to step 0.

When the loop exits, the firmware jumps to the start of the copy region.

### Code

Below is the code for the rpi2040 bootloader.

{{< collapsible-code path="content/art/sos_1_bootloader/boot.c" lang="asm" title="Our bootloader." >}}

### Linker script

We instruct the linker to link the bootloader in the SRAM section at address 0x20041f00 with the following linker script.

{{< collapsible-code path="content/art/sos_1_bootloader/boot.ld" lang="asm" title="Instructing the linker to place our code in SRAM." >}}

Note that we don't locate anything in flash since that's made on our behalf by the flasher and stage 1 bootloader. From our perspective, our code "is linked, lives and persists in SRAM".

### Build, test and upload

The following makefile builds the bootloader, then generates a binary file from it, then uses uf2-util to generate the final uf2 file which can be dragged and dropped after mounting the rp2040.

> Frankly after one day lost trying to work around the CRC I just noped out and decided that I'd just use the GUI and live on being ashamed of myself if it could give me a board which I could finally use.

{{< collapsible-code path="content/art/sos_1_bootloader/Makefile" lang="asm" title="How to build." >}}

## Next

Finally, it's done. We have a board flashed with a firmware which accepts raw data, copies it in RAM and executes it when it's done.

Satisfaction is present.

But it will be short lived, as now we need to figure out how the hell we can reliably transmit anything to that potential brick.



