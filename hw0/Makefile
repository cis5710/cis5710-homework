
help:
	@echo available commands: '`make build`', '`make start`' and '`make run`'

build:
	riscv64-unknown-elf-as -march=rv32im -mabi=ilp32 uppercase.S -o uppercase.o
	riscv64-unknown-elf-ld -A rv32 --oformat elf32-littleriscv -Tdata=0x2000 uppercase.o -o uppercase.bin
	riscv64-unknown-elf-objdump -d uppercase.bin > uppercase.disasm.s

start:
	spike -p1 -m0:0x1000,0x1000:0x1000,0x2000:0x1000,0x10000:0x1000 --isa=rv32im -d uppercase.bin

run:
	echo "str 0 2000\n rs 1000\n str 0 2000\n quit" | spike -p1 -m0:0x1000,0x1000:0x1000,0x2000:0x1000,0x10000:0x1000 --isa=rv32im -d --debug-cmd=/dev/stdin uppercase.bin
