#include <boot.h>

void kernel_main()
{
    while (1)
        asm volatile("hlt");
}