; kernel stub

[BITS 64]
[GLOBAL kernel_start]

section .text
extern kernel_main

kernel_start:
    ; RDI already passes the bootinfo pointer from the bootloader
    ; i try to match SystemV x86_64 ABI convention
    call kernel_main
.halt:
    hlt
    jmp .halt