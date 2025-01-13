/*
This is a linker script, specifying the desired memory layout at runtime. We use this to make sure the addresses used in
the code (PCs, global variables) match up with what our processor provides.
 */

MEMORY
{
    START : ORIGIN = 0x00000000, LENGTH = 64
    CODE : ORIGIN = 0x00000040, LENGTH = 16K
    DATA : ORIGIN = 0x00005000, LENGTH = 8K
}

SECTIONS
{
    .start : { *(.start*) } > START
    .text : { *(.text*) } > CODE
    .rodata : { *(.rodata*) } > DATA
    .bss : { *(.bss*) } > DATA
    .data : { *(.data*) } > DATA
}
