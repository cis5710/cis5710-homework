/*
This is a linker script, specifying the desired memory layout at runtime. We use this to make sure the addresses used in
the code (PCs, global variables) match up with what our processor provides.
 */

MEMORY
{
    CODE : ORIGIN = 0x00000000, LENGTH = 16K
    DATA : ORIGIN = 0x00004000, LENGTH = 8K
}

SECTIONS
{
    .text : { *(.text*) } > CODE
    .rodata : { *(.rodata*) } > DATA
    .bss : { *(.bss*) } > DATA
    .data : { *(.data*) } > DATA
}
