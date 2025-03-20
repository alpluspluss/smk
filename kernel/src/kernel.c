#include <boot.h>

#define VGA_WIDTH 80
#define VGA_HEIGHT 25
#define VGAMEMORY ((volatile unsigned short*) 0xB8000)
#define COLOR 0x0F

static int row = 0;
static int col = 0;

void clear(unsigned char color)
{
    unsigned short blank = (color << 8) | ' ';
    for (int i = 0; i < VGA_WIDTH * VGA_HEIGHT; ++i)
        VGAMEMORY[i] = blank;

    row = 0;
    col = 0;
}

void putchar(char c, unsigned char color)
{
    if (c == '\n') 
    {
        col = 0;
        row++;
        return;
    }
    
    VGAMEMORY[row * VGA_WIDTH + col] = (color << 8) | c;
    if (++col >= VGA_WIDTH) 
    {
        col = 0;
        row++;
    }
    
    if (row >= VGA_HEIGHT)
        row = 0; /* simple wraparound */
}

void print(const char* str, unsigned char color)
{
    for (int i = 0; str[i] != '\0'; i++)
        putchar(str[i], color);
}

void print_hex(uint64_t num, unsigned char color)
{
    const char* hex = "0123456789ABCDEF";
    char buffer[17];
    buffer[16] = '\0';
    
    int pos = 15;
    while (pos >= 0) 
    {
        buffer[pos] = hex[num & 0xF];
        num >>= 4;
        pos--;
        if (num == 0 && pos >= 0)
            break;
    }
    
    putchar('0', color);
    putchar('x', color);
    print(&buffer[pos + 1], color);
}

void print_dec(uint64_t num, unsigned char color)
{
    if (num == 0)
    {
        putchar('0', color);
        return;
    }
    
    char buffer[21];
    int pos = 20;
    buffer[pos] = '\0';
    
    while (num > 0) 
    {
        buffer[--pos] = '0' + (num % 10);
        num /= 10;
    }
    
    print(&buffer[pos], color);
}

void fb_verify_info(GraphicsInfo* gpinfo)
{
    if (!gpinfo)
    {
        print("Graphics info is NULL\n", COLOR);
        return;
    }
    
    print("Graphics info at: ", COLOR);
    print_hex((uint64_t)gpinfo, COLOR);
    print("\n", COLOR);
    
    print("Enabled: ", COLOR);
    print_dec(gpinfo->enabled, COLOR);
    print("\n", COLOR);
    
    /* only show details if graphics is reported as enabled */
    if (gpinfo->enabled)
    {
        print("Resolution: ", COLOR);
        print_dec(gpinfo->width, COLOR);
        print("x", COLOR);
        print_dec(gpinfo->height, COLOR);
        print("\n", COLOR);
        
        print("Bits per pixel: ", COLOR);
        print_dec(gpinfo->bpp, COLOR);
        print("\n", COLOR);
        
        print("Framebuffer address: ", COLOR);
        print_hex(gpinfo->framebuffer, COLOR);
        print("\n", COLOR);
        
        print("Pitch (bytes per line): ", COLOR);
        print_dec(gpinfo->pitch, COLOR);
        print("\n", COLOR);
        
        print("Color info:\n", COLOR);
        
        print("  Red: ", COLOR);
        print_dec(gpinfo->red_mask, COLOR);
        print(" bits at position ", COLOR);
        print_dec(gpinfo->red_position, COLOR);
        print("\n", COLOR);
        
        print("  Green: ", COLOR);
        print_dec(gpinfo->green_mask, COLOR);
        print(" bits at position ", COLOR);
        print_dec(gpinfo->green_position, COLOR);
        print("\n", COLOR);
        
        print("  Blue: ", COLOR);
        print_dec(gpinfo->blue_mask, COLOR);
        print(" bits at position ", COLOR);
        print_dec(gpinfo->blue_position, COLOR);
        print("\n", COLOR);
    }
}

void kernel_main(BootInfo* binfo, GraphicsInfo* gpinfo)
{
    if (!binfo)
        goto end;

    clear(0x0F);

    print("binfo at: ", COLOR);
    print_hex((uint64_t)binfo, COLOR);
    print("\n", COLOR);

    print("Memory map: ", COLOR);
    print_dec(binfo->memmap.entry_count, COLOR);
    print(" entries\n", COLOR);

    for (int i = 0; i < binfo->memmap.entry_count; ++i)
    {
        E820Entry* e = &binfo->memmap.entries[i];
        if (e->length == 0)
            continue;
        
        print_hex(e->base, COLOR);
        print(" - ", COLOR);

        print_hex(e->base + e->length - 1, COLOR);
        print(" | ", COLOR);

        /* check type */
        uint8_t type_color;
        const char* type_str;
        switch (e->type) 
        {
            case E820_TYPE_USABLE:
                type_color = 0x0A; /* green */
                type_str = "Usable";
                break;
            case E820_TYPE_RESERVED:
                type_color = 0x0C; /* red */
                type_str = "Reserved";
                break;
            case E820_TYPE_ACPI_RECLAIM:
                type_color = 0x0B; /* cyan */
                type_str = "ACPI Reclaim";
                break;
            case E820_TYPE_ACPI_NVS:
                type_color = 0x0B; /* cyan */
                type_str = "ACPI NVS";
                break;
            case E820_TYPE_BAD:
                type_color = 0x0C; /* red */
                type_str = "Bad Memory";
                break;
            default:
                type_color = 0x0F; /* white */
                type_str = "Unknown";
                break;
        }
        print(type_str, type_color);
        print("\n", 0x0F);
    }
    
    /* verify graphics info */
    print("\nVerifying graphics info...\n", COLOR);
    fb_verify_info(gpinfo);

    /* get kaslr offset */
    print("KASLR offset: ", COLOR);
    print_hex(binfo->memmap.kaslr_offset, COLOR);

end:
    while (1)
        asm volatile("hlt");
}