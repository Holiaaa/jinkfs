BITS 16
ORG 0x7C00

jmp start
db 0x4A

; Copyright (C) 2025 Téo JAUFFRET. All rights reserved.
; JinkFS Assembly Implementation 16bit
;
; Status : Beta

DiskLabel: db "JINKBOOT"
BytesPerBlock: dw 1024
Reserved: dw 0
FileTableOffset: dd 0x7E00
BlockAreaOffset: dd 0x8800
TotalOfEntries: db 128

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7BFF
    sti

    mov [BOOT_DISK], dl

    mov ah, 0x2
    mov al, 1
    mov ch, 0
    mov dh, 0
    mov cl, 2
    mov bx, [FileTableOffset]
    mov dl, [BOOT_DISK]
    int 0x13
    jc DiskError

    mov si, [FileTableOffset]
    mov cl, [TotalOfEntries]
    xor ch, ch

CheckNextEntry:
    mov al, [si]
    cmp al, 0
    je NotFound

    push si
    mov di, KernelName
    mov bp, 8

CompareName:    
    mov al, [si]
    cmp al, [di]
    jne NextEntry
    inc si
    inc di
    dec bp
    jnz CompareName

    pop si
    jmp LoadKernel

NextEntry:
    pop si
    add si, 20
    loop CheckNextEntry

NotFound:
    jmp DiskError

DiskError:
    jmp $

LoadKernel:
    mov si, MsgFound

Print:
    lodsb
    cmp al, 0
    je .done

    mov ah, 0xe
    mov bh, 0
    int 0x10

    jmp Print
.done:
    jmp $

MsgFound db "Found!", 0
KernelName db "KERNEL  ", 0
KernelExt db "BIN", 0
BOOT_DISK equ 0x800
times 510-($-$$) db 0
dw 0xAA55

db "KERNEL  "
db "BIN"
db 0
dd 0x00008800
dd 1

times 2560 - 20 db 0
