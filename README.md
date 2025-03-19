# smk: A small bootloader

smk is a minimal x86 BIOS bootloader & templated kernel that implements multi-stage boot process with "just enough" 
features to run an ELF-compiled kernel. smk is developed as a free time killer for educational purpose during 
the spring break of my high school.

The Assembly code is written with readability in mind with fairly good amount of comments covered in many sections. 
Readers should be able to learn how the boot process of a AMD64 CPU works.

> [!NOTE]
> This project is kind of a [remastered version](https://github.com/alpluspluss/bootloader-x86_64) of my small and old 
> bootloader.

## Status

smk supports all mandatory features to boot a CPU as well as some nice-to-have features as additionals:

### Essentials

- [X] Mode transitions (16-bit -> 32-bit -> 64-bit)
- [X] A20 line
- [X] Disk loading
- [X] Memory map detection with E820 BIOS subroutine
- [X] Paging setup
- [X] Kernel loading and jumping
- [X] SystemV AMD64 ABI for passing boot info to the kernel

### Optionals

- [X] Kernel virtual memory mapping
- [X] Stack pointer placements
- [x] 64-bit GDT
- [X] Some nice error messages

smk does not and will not support advanced features such as:

- KALSR
- CPU vendor and features detection
- VESA framebuffer
- FAT filesystem to load the kernel
- Boot log
- Image display
- and so on...

simply because it would take too much time to develop and add extra complexity that is contradict with the goal and 
design principle of this project.

> [!NOTE]
> UEFI booting is not supported not because of it being an optional feature but because of the environment I 
> am developing in.

## Building

### Requirements

Before building smk, there are several required components:

- GNU Make
- GNU binutils
- GCC cross compiler
- NASM
- QEMU

### Commands

To start building, type:

```shell
make
```

to build every component.

```shell
make run
```

to compile and start QEMU.

```shell
make clean
```

to clean the build and:

```shell
make rerun
```

to clean, build, and run the project in a single step.

## License

This project is licensed under the [MIT license](LICENSE).