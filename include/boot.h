#pragma once

#ifndef BOOT_H
#define BOOT_H

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

typedef struct X
{
    uint16_t entry_count;
    E820Entry entries[64];
    uint64_t kaslr_offset;
} __attribute__((packed)) MemmapInfo;

typedef struct
{
    MemmapInfo memmap; /* our memmap info */
} __attribute__((packed)) BootInfo;

typedef struct
{
    uint16_t enabled;        /* graphics enabled flag (1=enabled, 0=disabled) */
    uint16_t width;          /* screen width in pixels */
    uint16_t height;         /* screen height in pixels */
    uint8_t bpp;             /* bits per pixel */
    uint32_t framebuffer;    /* physical address of the linear framebuffer */
    uint16_t pitch;          /* bytes per scanline */
    uint8_t red_mask;        /* size of red mask in bits */
    uint8_t red_position;    /* bit position of red mask */
    uint8_t green_mask;      /* size of green mask in bits */
    uint8_t green_position;  /* bit position of green mask */
    uint8_t blue_mask;       /* size of blue mask in bits */
    uint8_t blue_position;   /* bit position of blue mask */
} __attribute__((packed)) GraphicsInfo;

#endif