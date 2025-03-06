uart.bin: uart.c
	riscv64-unknown-elf-gcc -Wall -Os -march=rv32im -mabi=ilp32 -nostdlib -nodefaultlibs -T memory.ld -o $@ uart.c

asm:
	riscv64-unknown-elf-objdump -d uart.bin

nm:
	riscv64-unknown-elf-nm uart.bin

elf:
	riscv64-unknown-elf-readelf -e uart.bin
