ledrop.bin: ledrop.c
	riscv64-unknown-elf-gcc -Wall -Os -march=rv32im -mabi=ilp32 -nostdlib -nodefaultlibs -T memory.ld -o $@ ledrop.c

asm:
	riscv64-unknown-elf-objdump -d ledrop.bin

nm:
	riscv64-unknown-elf-nm ledrop.bin

elf:
	riscv64-unknown-elf-readelf -e ledrop.bin
