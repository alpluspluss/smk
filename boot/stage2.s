[BITS 16]
[ORG 0x7E00]

KERNEL_HIGH equ 0xFFFFFFFF80000000 ; kernel virtual address in higher half
KERNEL_SEG equ 0x1000 ; segment where kernel is loaded in real mode
KERNEL_OFF equ 0x0000 ; offset of the kernel where it is loaded
KERNEL_LOW equ (KERNEL_SEG << 4) + KERNEL_OFF ; physical address computation
VGA_MEM equ 0xB8000 ; VGA text mode buffer address
MEMMAP_BUFFER equ 0x8000 ; the address to store memory map
MEMMAP_ENTRIES equ 0x7E00 ; store number of entries at this address

; BootInfo structure definitions
BOOT_INFO equ 0x9000 ; base address for bootinfo structure
MEMMAP_INFO_OFFSET equ 0 ; memory map info offset in bootinfo

start:
    ; stack segment init
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x9000

    mov si, msg_stage2 ; show we reached stage2 of the boot
    call print_rm

    ; init BootInfo structure (clear it)
    mov di, BOOT_INFO
    mov cx, 512 ; clear 1KB / 2 per word
    xor ax, ax
    rep stosw ; clear the memory by repeating store word and set zero

    ; IMPORTANT note: this is ORDER-SENSITIVE
    call enable_a20 ; enable A20 line for >1MB memory access
    call detect_mm ; detect memory map
    call load_kernel ; load the kernel from the disk using DL (drive num)
    call enter_pm ; enter protected mode (32-bit)

; detect memory map using E820 BIOS call
detect_mm:
    pusha ; save all 16-bit registers

    ; setup the buffer
    mov di, BOOT_INFO + MEMMAP_INFO_OFFSET + 2 ; skip the first 2 bytes (entry count)
    xor bx, bx ; clear bx to start with the first entry
    xor bp, bp ; bp counts the entries

    ; get the response from E820 subroutine call
    mov edx, 0x534D4150 ; "SMAP" signature for E820
    mov ax, 0xE820 ; E820 BIOS service
    mov [es:di + 20], word 1 ; use word-sized ext flags
    mov cx, 24 ; ask for 24 bytes; standard E820 entry size
    int 0x15 ; call the BIOS
    jc .error ; carry flag set = function not supported
    
    ; validation
    cmp eax, 0x534D4150 ; EAX should have "SMAP" signature
    jne .error ; if not, error occurred
    
    test bx, bx ; is BX zero? (no more entries)
    jz .done ; if so then memory detection done
    
    jmp .start_loop ; skip first entry check and continue

.next_entry:
    mov ax, 0xE820 ; E820 function
    mov [es:di + 20], word 1 ; use word instead of dword
    mov cx, 24 ; 24 bytes again
    int 0x15 ; call BIOS
    jc .done ; carry = end of list
    
.start_loop:
    jcxz .skip_entry ; skip 0-length entries
    
    ; entry is valid -> move to next position
    add di, 24 ; move buffer pointer
    inc bp ; count += 1
    
.skip_entry:
    test bx, bx ; BX = 0 means list is complete
    jnz .next_entry ; if not, get next entry
    
.done:
    ; store count at the beginning of the memory map info
    mov [BOOT_INFO + MEMMAP_INFO_OFFSET], bp
    
    mov si, msg_mem_ok
    call print_rm

    mov ax, bp
    call print_num
    mov si, newline
    call print_rm

    popa  ; restore all 16-bit registers
    ret

.error:
    mov si, msg_mem_err
    call print_rm

    popa
    ret

; print a number in AX
print_num:
    push ax
    push bx
    push cx
    push dx
    
    mov bx, 10          ; divisor
    xor cx, cx          ; count digits
    
.div_loop:
    xor dx, dx          ; clear high word of dividend
    div bx              ; divide by 10
    push dx             ; push remainder (digit)
    inc cx              ; increment digit count
    test ax, ax         ; check if quotient is zero
    jnz .div_loop       ; continue if not
    
.print_loop:
    pop dx              ; get digit
    add dl, '0'         ; convert to ASCII
    mov ah, 0x0E        ; BIOS teletype function
    mov al, dl          ; character to print
    int 0x10            ; call BIOS
    loop .print_loop    ; loop until all digits are printed
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; real mode print; this is the same thing from stage1.s so i will not be commenting this
print_rm:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp print_rm
.done:
    ret

load_kernel:
    mov ax, 0x0240 ; read 64 sectors (32KB) at a time
    xor ch, ch ; cylinder 0
    mov cl, 5 ; from section 5 after 1 & 2; boot1 is at 1 and boot2 is at 3
    xor dh, dh
    push KERNEL_SEG ; set ES to kernel segment
    pop es
    mov bx, KERNEL_OFF ; ES:BX = dest addr
    int 0x13
    jc disk_error ; carry flag = error
    ret

; small note: there are many ways to activate A20 
; but this is the simplest way to achieve
enable_a20:
    push ax
    in al, 0x92 ; read system control port
    or al, 2 ; set bit 1 to enable the A20 line
    out 0x92, al ; write back to port
    pop ax ; restore the stack frame
    ret

; switch to 32-bit protected mode
enter_pm:
    cli ; disable interrupts
    lgdt [gdt32_desc] ; load GDT descriptor
    mov eax, cr0 ; get cr0
    or eax, 1 ; set protection enable (PE) bit
    mov cr0, eax ; enable to enter protected mode
    jmp 0x08:pm_entry ; then make a  far jmp to flush the CPU pipeline

; refer to stage1.s
disk_error:
    mov si, msg_disk_err
    call print_rm
    cli
    hlt


[BITS 32]
pm_entry:
    ; init segments with 32-bit data segment selector
    mov ax, 0x10 ; 0x10 is the data segment selector
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x200000 ; set stack pointer to 2MB

    ; "hey, we reached protected mode!"
    mov esi, msg_pm
    call print_pm

    call setup_paging ; setup cpu paging for long mode

    lgdt [gdt64_desc] ; load the 64-bit GDT
    call enter_lm ; then enable long mode

    jmp 0x08:lm_entry

; refer to the old printer; this one just uses 32-bit registers instead of 16
print_pm:
    push eax
    push ebx
    mov ebx, VGA_MEM
.loop:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0F
    mov [ebx], ax
    add ebx, 2
    jmp .loop
.done:
    pop ebx
    pop eax
    ret

; 4 level paging
setup_paging:
    ; clear the page tables 
    mov edi, 0x1000 ; the tables will start at 0x1000
    xor eax, eax ; clear the memory
    mov ecx, 5 * 4096 / 4 ; 5 tables * 4KB / 4 B per dword
    rep stosd ; repeat store double world to fill with zeros

    ; identity mapping for the first 2MB
    ; 0x00002003 means points to the next page table
    ; READABLE (bit 0) | WRITABLE (bit 1) | PRESENT in memory (bit 2)
    ; also goes similarly for other mappings
    mov dword [0x1000], 0x00002003 ; [PDPT] | READ | WRITE | PRESENT 
    mov dword [0x2000], 0x00003003 ; [PDT] | READ | WRITE | PRESENT 
    mov dword [0x3000], 0x00000083 ; 2MB page; | READ | WRITE | PRESENT 

    ; our paging structure for high half virtual kernel mapping
    ; KERNEL_HIGH >> 39 to get the top-level page table index
    ; & 0x1FF to ensure that only 9 bits OR 512 entries are used
    ; mul by 8 to get the correct offset
    mov dword [0x1000 + 8 * ((KERNEL_HIGH >> 39) & 0x1FF)], 0x00004003
    mov dword [0x4000 + 8 * ((KERNEL_HIGH >> 30) & 0x1FF)], 0x00005003
    mov dword [0x5000 + 8 * ((KERNEL_HIGH >> 21) & 0x1FF)], 0x00000083

    ; load cr3 with the address of PML4T
    mov edi, 0x1000
    mov cr3, edi
    ret

enter_lm:
    mov ecx, 0xC0000080 ; EFER MSR
    rdmsr ; read current value 
    or eax, 1 << 8 ; set LME (similar to the protected mode boot)
    wrmsr ; write back

    ; Enable Physical Address Extension (PAE) and Page Global Enable (PGE)
    ; PAE allows 36-bit physical addresses and is required for long mode
    ; PGE allows caching of global page mappings across context switches
    mov eax, 10100000b ; set PAE and PGE bits
    mov cr4, eax ; update our cr4

    mov eax, cr0 ; get current cr0
    or eax, 1 << 31 ; set paging bit
    mov cr0, eax ; enable paging
    ret

[BITS 64]
lm_entry:
    ; init seg 64-bit dss
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    mov rsp, 0x90000 + KERNEL_HIGH ; set stack pointer to high address

    ; yay we reached the long mode
    mov rsi, msg_lm
    call print_lm

    ; pass BootInfo pointer to kernel in RDI (first parameter)
    ; this is required because we need to follow the convention to correctly pass the boot information
    ; to the kernel
    mov rdi, KERNEL_HIGH + BOOT_INFO

    mov rax, KERNEL_HIGH + KERNEL_LOW ; jump to kernel at its virtual high address
    jmp rax

print_lm:
    push rax
    push rbx
    mov rbx, VGA_MEM
.loop:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0F
    mov [rbx], ax
    add rbx, 2
    jmp .loop
.done:
    pop rbx
    pop rax
    ret

msg_stage2:    db 'Stage 2 loaded', 13, 10, 0
msg_disk_err:  db 'Disk error', 13, 10, 0
msg_mem_err:   db 'Memory map detection failed', 13, 10, 0
msg_mem_ok:    db 'Memory map detected, entries: ', 0
newline:       db 13, 10, 0
msg_lm:        db 'In long mode', 0
msg_pm:        db 'In protected mode', 0


; gpt structures
; aligning the data to 16 bytes is required
align 16
gdt32:
    dq 0 ; null descriptor
    dq 0x00CF9A000000FFFF ; code: 32-bit, 4K granularity, ring 0
    dq 0x00CF92000000FFFF ; data: 32-bit, 4K granularity, ring 0
gdt32_end:

gdt32_desc:
    dw gdt32_end - gdt32 - 1 ; size minus 1
    dd gdt32 ; base addr

; and similiarly for 64-bit GDT
align 16
gdt64:
    dq 0 ; null
    dq 0x00AF9A000000FFFF ; code: 64-bit, 4K granularity, ring 0
    dq 0x00AF92000000FFFF ; data: 64-bit, 4K granularity, ring 0
gdt64_end:

gdt64_desc:
    dw gdt64_end - gdt64 - 1
    dq gdt64