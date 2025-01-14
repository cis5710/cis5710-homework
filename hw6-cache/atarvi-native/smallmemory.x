/*
This is a linker script, specifying the desired memory layout at runtime. We use this to make sure the addresses used in
the code (PCs, global variables) match up with what our processor provides.
 */

MEMORY
{
    START : ORIGIN = 0x00000000, LENGTH = 16
    CODE : ORIGIN = 0x00000010, LENGTH = 6000
    DATA : ORIGIN = 0x0001800, LENGTH = 2048
    /* put stack at 0x1A00 */
}

SECTIONS
{
    .start : { *(.start*) } > START
    .text : { *(.text*) } > CODE
    .rodata : { *(.rodata*) } > DATA
    .bss : { *(.bss*) } > DATA
    .data : { *(.data*) } > DATA
}
