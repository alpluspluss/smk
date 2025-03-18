ARCH ?= x86_64
AS = nasm
CC = $(ARCH)-elf-gcc
LD = $(ARCH)-elf-ld
OBJCOPY = $(ARCH)-elf-objcopy
QEMU = qemu-system-$(ARCH)

NASMFLAGS = -f elf64
NASMFLAGS_BIN = -f bin
INC_DIRS = -I./kernel/include -I./include

CFLAGS = -ffreestanding -nostdlib -mno-red-zone -Wall -Wextra -O3 -mcmodel=kernel $(INC_DIRS)
LDFLAGS = -T linker.ld -nostdlib

BUILD_DIR = build
BOOT_DIR = boot
KERNEL_SRC_DIR = kernel/src

BOOT_STAGE1 = $(BOOT_DIR)/stage1.s
BOOT_STAGE2 = $(BOOT_DIR)/stage2.s
KERNEL_ENTRY = $(KERNEL_SRC_DIR)/entry.s
KERNEL_C = $(KERNEL_SRC_DIR)/kernel.c

BOOT_STAGE1_BIN = $(BUILD_DIR)/stage1.bin
BOOT_STAGE2_BIN = $(BUILD_DIR)/stage2.bin
KERNEL_ENTRY_OBJ = $(BUILD_DIR)/entry.o
KERNEL_C_OBJ = $(BUILD_DIR)/kernel.o
KERNEL_ELF = $(BUILD_DIR)/kernel-$(ARCH).elf
KERNEL_BIN = $(BUILD_DIR)/kernel-$(ARCH).bin
OS_IMG = $(BUILD_DIR)/smk-$(ARCH).img

all: compiledb $(OS_IMG)

compiledb: | $(BUILD_DIR)
	@which compiledb > /dev/null 2>&1 || (echo "compiledb is not installed. Please install it using pip install compiledb" && exit 1)
	@echo "Generating compile_commands.json in $(BUILD_DIR)..."
	@make -Bnwk $(KERNEL_C_OBJ) | compiledb -o $(BUILD_DIR)/compile_commands.json

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BOOT_STAGE1_BIN): $(BOOT_STAGE1) | $(BUILD_DIR)
	$(AS) $(NASMFLAGS_BIN) $< -o $@

$(BOOT_STAGE2_BIN): $(BOOT_STAGE2) | $(BUILD_DIR)
	$(AS) $(NASMFLAGS_BIN) $< -o $@

$(KERNEL_ENTRY_OBJ): $(KERNEL_ENTRY) | $(BUILD_DIR)
	$(AS) $(NASMFLAGS) $< -o $@

$(KERNEL_C_OBJ): $(KERNEL_C) | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(KERNEL_ELF): $(KERNEL_ENTRY_OBJ) $(KERNEL_C_OBJ) | $(BUILD_DIR)
	$(LD) $(LDFLAGS) -o $@ $^

$(KERNEL_BIN): $(KERNEL_ELF) | $(BUILD_DIR)
	$(OBJCOPY) -O binary $< $@

$(OS_IMG): $(BOOT_STAGE1_BIN) $(BOOT_STAGE2_BIN) $(KERNEL_BIN)
	dd if=/dev/zero of=$(OS_IMG) bs=512 count=2880
	dd if=$(BOOT_STAGE1_BIN) of=$(OS_IMG) bs=512 seek=0 conv=notrunc
	dd if=$(BOOT_STAGE2_BIN) of=$(OS_IMG) bs=512 seek=1 conv=notrunc
	dd if=$(KERNEL_BIN) of=$(OS_IMG) bs=512 seek=4 conv=notrunc

clean:
	rm -rf $(BUILD_DIR)/*.o $(BUILD_DIR)/*.bin $(BUILD_DIR)/*.img $(KERNEL_ELF)
	rm -f $(BUILD_DIR)/compile_commands.json

run: $(OS_IMG)
	$(QEMU) -drive file=$(OS_IMG),format=raw -serial stdio # -S -gdb tcp::1234

rerun: clean all run

.PHONY: all clean run rerun compiledb