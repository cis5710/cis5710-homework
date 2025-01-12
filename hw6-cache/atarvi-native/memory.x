MEMORY
{
    RAM : ORIGIN = 0x00000000, LENGTH = 4K
}

SECTIONS
{
    .text : { *(.text*) } > RAM
    .rodata : { *(.rodata*) } > RAM
    .bss : { *(.bss*) } > RAM
    .data : { *(.data*) } > RAM
}
