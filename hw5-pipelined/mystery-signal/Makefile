mystery.bin: mystery.c
	riscv64-unknown-elf-gcc -Wall -Os -march=rv32im -mabi=ilp32 -fno-tree-loop-distribute-patterns -nostdlib -nodefaultlibs -T memory.ld -o $@ mystery.c

asm:
	riscv64-unknown-elf-objdump -d mystery.bin

nm:
	riscv64-unknown-elf-nm mystery.bin

elf:
	riscv64-unknown-elf-readelf -e mystery.bin
