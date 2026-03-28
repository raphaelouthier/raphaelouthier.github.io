remote := 192.168.0.120:3333

.PHONY: build run

build :
	mkdir -p build
	arm-none-eabi-gcc -c boot.c -Wall -Wextra -mcpu=cortex-m0plus -mthumb -Os -ffreestanding -g -nostdlib -o build/boot.o
	arm-none-eabi-ld build/boot.o -T boot.ld -o build/boot.elf
	arm-none-eabi-objcopy -O binary build/boot.elf build/boot.bin
	readelf -S build/boot.elf | grep .stage2
	dd if=/dev/zero bs=1 count=2 of=build/app.bin
	uf2-util --bootrom build/boot.bin --progdata build/app.bin --output build/boot.uf2

run :
	readelf -S build/boot.elf | grep .stage2
	gdb build/boot.elf -ex 'target remote $(remote)' -ex 'load' -ex 'set $$pc = 0x20041f00' -ex 'continue'

