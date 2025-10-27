BITS 16
ORG 0x7C00

; Copyright (C) 2025 Téo JAUFFRET. All rights reserved.
; JinkFS Assembly Implementation 16bit (with french comments)
;
; Status : beta2

jmp start                       ; Jump au start (fais office de Signature[0] et Signature[1]
db 0x4A                         ; Signature[2] obligatoire

DiskLabel: db "JINKBOOT"        ; Nom du disque (8 caractères max)
BytesPerBlock: dw 1024          ; Combien d'octet par block
Reserved: dw 0                  ; Reservé pour Jink OS
FileTableOffset: dd 0x7E00      ; Offset ou la FET commence
BlockAreaOffset: dd 0x8800      ; Offset ou la zone des blocks commence. (Inutilisé ici)
TotalOfEntries: db 128          ; Nombre max d'entrée dans la FET

start:
    cli                         ; Désactive les interruptions.
    xor ax, ax                  ; Initialisation de la pile.
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7BFF
    sti                         ; On réactive les interruptions.

    mov [BOOT_DISK], dl         ; On copie dans BOOT_DISK l'identifiant du disque. (Si dl > 0x80 alors HDD sinon Floppy)

    mov ah, 0x2                 ; Mode Lecture
    mov al, 5                   ; 5 secteurs de 512 octet (car la FET mesure 2560 octets, donc 2560/512=5)
    mov ch, 0           
    mov dh, 0
    mov cl, 2                   ; 2 ème secteur.
    mov bx, [FileTableOffset]
    mov dl, [BOOT_DISK]
    int 0x13                    ; Interruption disque.
    jc DiskError                ; Jump si erreur.

    mov si, [FileTableOffset]   ; Met dans SI l'adresse de FileTableOffset
    mov cl, [TotalOfEntries]    ; Met dans CI le Max d'Entries
    xor ch, ch                  ; Reset CH

CheckNextEntry:
    mov al, [si]                ; Met dans AL, le premier caractère de SI
    cmp al, 0                   ; Compare AL avec 0
    je NotFound                 ; Si cmp est juste, alors on jump a NotFoundd

    push si                     ; On met SI dans la pile
    mov di, KernelName          ; On met dans DI l'adresse de KernelName
    mov bp, 8                   ; On met dans BP la valeur 8 (taille total du nom)

CompareName:    
    mov al, [si]                ; On met dans AL la première lettre de SI
    cmp al, [di]                ; On compare cette lettre avec la première lettre de DI (KernelName)
    jne NextEntry               ; Si c'est pas égal alors on jump a NextEntry
    inc si                      ; Si c'est égal on incrémente SI
    inc di                      ; On incrémente DI
    dec bp                      ; On decrémente BP
    jnz CompareName             ; On jump si c'est pas égal a 0

    mov di, KernelExt           ; Si le nom est bon alors on met dans DI l'adresse de KernelExt
    mov bp, 3                   ; On met dans BP la valeur 3 (taille total de l'extension de fichier)

CompareExt:
    mov al, [si]                ; On met dans AL la lettre de SI (première lettre de l'extension)
    cmp al, [di]                ; On compare AL avec la première lettre de l'extension (ici DI)
    jne NextEntry               ; Si c'est pas égal alors on jump a NextEntry
    inc si                      ; Si c'est égal on incrémente SI
    inc di                      ; On incrémente DI
    dec bp                      ; On decrémente BP
    jnz CompareExt              ; On jump si c'est pas égal a 0

    pop si                      ; On enlève SI de la pile
    add si, 12                  ; On pointe a SI le début de l'offset
    mov ax, [si]                ; On met dans AX l'offset bas
    mov dx, [si+2]              ; On met dans DX l'offset haut.
    mov [KernelOffsetLow], ax   ; On les stock dans des variables.
    mov [KernelOffsetHigh], dx

    add si, 4                   ; On ajoute 4 a SI pour pointer sur le début de la taille
    mov bx, [si]                ; On met dans BX la taille bas
    mov cx, [si+2]              ; On met dans CX la taille haute
    mov [KernelSizeLow], bx     ; On les stock dans des variables
    mov [KernelSizeHigh], cx

    jmp LoadKernel              ; On jump a LoadKernel

NextEntry:
    pop si                      ; On enlève SI de la pile
    add si, 20                  ; On ajoute 20 a SI (Pour pointer sur la prochaine entrée)
    loop CheckNextEntry         ; On retourne a CheckNextEntry

NotFound:
    jmp DiskError               ; Le fichier n'a pas été trouvé, on jump alors a DiskError

DiskError:
    jmp $                       ; Boucle infini -> Signe d'Erreur.

LoadKernel:
    mov si, MsgFound            ; On met dans SI l'adresse du message MsgFound

Print:  
    lodsb                       ; lodsb -> AL <- [DS:SI] puis SI <- SI +- 1 selon DF
    cmp al, 0                   ; On compare AL avec 0
    je .done                    ; On jump si AL == 0

    mov ah, 0xe                 ; On met le mode Teletype Output de l'INT 10h
    mov bh, 0                   ; On écrit sur la page vidéo 0
    int 0x10                    ; On produit l'interruption 0x10

    jmp Print                   ; On jump tant que AL != 0
.done:
    xor ax, ax                  ; On reset tout les registres
    xor bx, bx
    xor cx, cx
    xor dx, dx
    xor si, si 
    xor di, di 

    mov ax, [KernelOffsetLow]   ; On met dans AX l'offset de KernelOffsetLow
    sub ax, 0x7C00              ; On enleve 0x7C00 de l'offset
    
    mov bx, 512                 ; On met dans BX le dénominateur (512 car 1 secteur vaut 512)
    div bx                      ; On fais AX/BX
    mov [NumSectors], ax        ; On stock le secteur de départ dans NumSectors

    xor ax, ax                  ; On resets les registres recemment utilisé
    xor bx, bx 
    xor dx, dx

    mov ax, [KernelSizeLow]     ; On met dans AX, la valeur de [KernelSizeLow]
    shl ax, 1                   ; On la multiplie par 2 (car 512 = 1 secteur, 1024 = 2 secteur)

    mov ah, 0x2                 ; On utilise le mode lecture de l'INT 13H
    mov al, al                  ; Inutile ici mais sécurité
    mov ch, 0
    mov dh, 0
    mov cl, [NumSectors]        ; On met dans CL, le nombre de secteurs a partir du quel il faut lire. ((Offset - 0x7C00) / 512)
    mov bx, 0x1000              ; On stock le kernel en 0x1000
    mov dl, [BOOT_DISK]         ; On lit sur le disque de BOOT.
    int 0x13                    ; On execute l'interruption
    jc DiskError                ; Si erreur on jump a DiskError

    jmp 0x0000:0x1000           ; Sinon on boot sur le kernel
    jmp $                       ; Ne dois jamais se produire

MsgFound db "KERNEL.BIN Found!", 0x0D, 0x0A, 0
KernelName db "KERNEL  ", 0
KernelExt db "BIN", 0
KernelOffsetLow dw 0
KernelOffsetHigh dw 0
KernelSizeLow dw 0
KernelSizeHigh dw 0

BOOT_DISK equ 0x800

NumSectors db 0

times 510-($-$$) db 0           ; Remplit le reste du fichiers (jusqu'a 510 octet) avec des 0x00
dw 0xAA55                       ; Signature du bootloader
