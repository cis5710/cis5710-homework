/*
This is a linker script, specifying the desired memory layout at runtime. We use this to make sure the addresses used in
the code (PCs, global variables) match up with what our processor provides.
 */

MEMORY
{
    START : ORIGIN = 0x00000000, LENGTH = 512
    CODE :  ORIGIN = 0x00000200, LENGTH = 256
    DATA :  ORIGIN = 0x00000300, LENGTH = 128
}

SECTIONS
{
    .start : { *(.start*) } > START
    .text : { *(.text*) } > CODE
    .rodata : { *(.rodata*) } > DATA
    .srodata : { *(.srodata*) } > DATA
    .bss : { *(.bss*) } > DATA
    .data : { *(.data*) } > DATA
    .sdata : { *(.sdata*) } > DATA
}
