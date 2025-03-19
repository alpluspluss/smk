#pragma once

#include <stdint.h>

#define E820_TYPE_USABLE           1
#define E820_TYPE_RESERVED         2
#define E820_TYPE_ACPI_RECLAIM     3
#define E820_TYPE_ACPI_NVS         4
#define E820_TYPE_BAD              5

typedef struct
{
    uint64_t base; /* base addr */
    uint64_t length; /* region length */
    uint32_t type; /* regoin type */
    uint32_t acpi; /* ACPI extended attributes */
} __attribute__((packed)) E820Entry;

typedef struct
{
    uint16_t entry_count;
    E820Entry entries[];
} __attribute__((packed)) MemmapInfo;

typedef struct
{
    MemmapInfo memmap; /* our memmap info */
    /* TODO: add more or smth idk */
} __attribute__((packed)) BootInfo;