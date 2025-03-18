KERNEL_OFFSET_HIGH = 0xFFFFFFFF80000000;
KERNEL_OFFSET_LOW = 0x10000;

ENTRY(kernel_start)

SECTIONS
{
    . = KERNEL_OFFSET_HIGH + KERNEL_OFFSET_LOW;

    .text ALIGN(4K) : AT(ADDR(.text) - KERNEL_OFFSET_HIGH)
    {
        *(.text*)
    }

    .rodata ALIGN(4K) : AT(ADDR(.rodata) - KERNEL_OFFSET_HIGH)
    {
        *(.rodata*)
    }

    .data ALIGN(4K) : AT(ADDR(.data) - KERNEL_OFFSET_HIGH)
    {
        *(.data*)
    }

    .bss ALIGN(4K) : AT(ADDR(.bss) - KERNEL_OFFSET_HIGH)
    {
        *(COMMON)
        *(.bss*)
    }

    /DISCARD/ :
    {
        *(.eh_frame)
        *(.comment)
        *(.note*)
    }
}