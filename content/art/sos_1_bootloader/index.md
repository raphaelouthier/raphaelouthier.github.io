---
title: "ScratchOS : Firmware."
summary: "Back to nibble age."
series: [ScratchOS]
series_order: 0
categories: [ScratchOS]
tags: ["ScratchOS"]
#externalUrl: ""
showSummary: true
date: 2026-03-20
showTableOfContents : true
draft: true
---

## Rpi2040 : what we care about.

### CPUs.

The RPI2040 features two cortex M0+ CPUs, able to execute the thumb ISA.

### Memory

The RPI2040 features :
- a RO (fixed at manifacturing) 16KiB ROM mapped at [0, 0x1000[;
- a RW 264KiB SRAM mapped at [0x20000000, 0x0x20042000[;
- a NA (for now) 16MiB Flash mappable at [0x10000000, 0x11000000[;

### Flash

Upon reset the flash is not mapped, and a subsystem in the chip must be configured to map it.

### GPIO

The RPI2040 has 29 available GPIOs.

GPIO 25 is used as LED.

On reset, each pin is usable as input.

All GPIOs input values can be read at once by reading TODO.

All GPIOs modes (input, output) can be set at once by setting TODO. 

To set a GPIO in output mode, we also need to set its AF to 5 (SIO).

IO_BANK0 which sets the AF of each pin stays on RESET mode after reset. Reset needs to be deasserted before using it.

### Boot sequence : stage 1.

After reset, both CPUs start executing the stage 1 bootloader located at address 0, in the bootrom.

CPU 1 gets parked, and CPU 0 loads the stage 2 bootloader (256 bytes max) from Flash and copies it in SRAM.

The stage 1 bootloader does not configure the flash mapping system.

Rather, it retrieves the stage 2 bootloader by running raw flash commands.

Then, it jumps to the start of SRAM to execute the copied stage 2 bootloader.

The stage 2 bootloader will be our initial firmware.

## Firmware.

### Goals

Our firmware's objective is to let us input arbitrary code and execute it.

Code input will be done via GPIO, and a LED will help us verify that it actually receives our data.

We need one pin for the led (GPIO25), one pin to report that data can be captured (GPIO0), one pin to report that data stage is done and the firmware should start executing the received code (GPIO1), and data pins.

Initially I'll have to provide data manually so I'd rather make it as least painfull as possible.

I'll use spare keyboard switches that I have around to update GPIO values.

I'll need one finger to press the execute button but this needs to be done once at the end so ergonomy is not important.

What matters is efficiency in data input.

I'll need one finger to press the capture button everytime I want to input data.

That leaves 4 fingers available, which is cool since it means I can provide four bits at the time to the firmware.

This will require GPIO2, GPIO3, GPIO4 and GPIO5 to serve as our 4 data bits.

### Behavior.

Upon startup, the firmware configures GPIOs and initialized the write (byte) pointer to the start of the copy region (SRAM_START + BOOTLOADER_SIZE) = 0x20000100.

Then it executes the capture loop (iteration numbers start at 0) :
- 0 : turn led off. 
- 1 : whenever GPIO 0 is pressed long enough, move to step 1. Otherwise, stay in step 1. 
- 2 : turn led on.
- 3 : read the 4 data GPIOs.
- 4 : whenever GPIO 0 is released long enough, move to step 5. Otherwise, stay in step 4.
- 5 : if we captured a byte start (even iteration number) store the nibble somewhere. Otherwise (odd iteration number) then write the stored nibble and the current nibble into memory at the write pointer, and increment the write pointer.
- 6 : if exec button is pressed long enough, exit the loop. Otherwise, move to step 0.

When the loop exits, the firmware jumps to the start of the copy region.

### Code.

### Build and upload.

