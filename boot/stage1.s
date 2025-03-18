[BITS 16] ; we start from 16-bit real mode
[ORG 0x7C00] ; the origin address where BIOS loads the bootloader

start:
    ; stack segment init
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    mov [boot_drive], dl ; save boot drive number; BIOS provides this in DL reg at startup

    ; load stage 2 from disk with 0x13h interrupt routine
    mov ax, 0x0203 ; AH: 02 read sectors subroutine, AL: 03 = 3 sectors per read
    mov cx, 0x0002 ; start at cylinder 0 from sector 2
    xor dh, dh ; head 0
    mov bx, 0x7E00 ; ES:BX = dest addr 0:0x7E00
    mov dl, [boot_drive]
    int 0x13 ; call the service
    jc disk_error ; carry flag set = error

    mov si, success_msg
    call print_string

    db 0xEA ; far jump machine opcode
    dw 0x0000, 0x07E0 ; to 0x07E0:0x0000 -> phys addr 0x7E00

disk_error:
    mov si, error_msg ; load err msg
    call print_string ; display
    mov al, ah
    call print_hex ; error code in hexadecimal
    cli ;  turn the interrupt off
.halt:
    hlt ; halt the CPU instruction until the next interrupt which should never happen
    jmp short .halt ; just in case an NMI happens

print_string:
    pushf
    cld
.loop:
    lodsb ; load byte from 
    test al, al ; check for null terminator; if zero then we done
    jz .done
    mov ah, 0x0E ; the teletype output function
    int 0x10 ; BIOS video service
    jmp short .loop
.done:
    popf
    ret

print_hex:
    push ax ; save stack frame
    mov dl, al ; save
    shr al, 4 ; get high nibble`
    call print_nibble
    mov al, dl ; restore al
    and al, 0x0F ; low nibble only
    call print_nibble
    pop ax ; restore the stack frame
    ret

print_nibble:
    and al, 0x0F ; ensure low nibble only from the print_hex callsite; 
                    ; note: this should get optimized away if the assembler is doing its job correctly
    add al, '0' ; conv to ascii
    cmp al, '9' ; no more than '9' 
    jbe .print ; 0-9 is good to print
    add al, 7 ; otherwise add 7 more to get to 'A' - 'F'
.print:
    mov ah, 0x0E ; teletype
    int 0x10 ; BIOS video service
    ret ; go back to caller

boot_drive:    db 0
success_msg:   db "OK", 0
error_msg:     db "ERR:", 0


times 510-($-$$) db 0 ; pad with zeros until 510 bytes
dw 0xAA55 ; 2 bytes boot signature; required by BIOS