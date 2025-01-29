/*
This is a linker script, specifying the desired memory layout at runtime. We use this to make sure the addresses used in
the code (PCs, global variables) match up with what our processor provides.
 */

MEMORY
{
    START : ORIGIN = 0x00000000, LENGTH = 32
    CODE : ORIGIN = 0x00000040, LENGTH = 500
    DATA : ORIGIN = 0x00005000, LENGTH = 300
}

SECTIONS
{
    .start : { *(.start*) } > START
    .text : { *(.text*) } > CODE
    .rodata : { *(.rodata*) } > DATA
    .bss : { *(.bss*) } > DATA
    .data : { *(.data*) } > DATA
}
