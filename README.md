# Jink FS
A simple file system designed for little OSDev projects

## Definition
### General struct

a JinkFS disk is composed like this : 

```
[Bootloader] [File Table] [Block 1] [Block 2] [Block 3] ... [Block n]
```
`Bootloader` : 512 bytes long, contains the boot code and definitions of a JinkFS Disk. (Start at 0x7C00)

`File Table` : 2560 bytes long, contains each file entry (that are 20 bytes long each for a total of file of 128 files) (Start at 0x7e00)

`Block` : See below `Blocks` (Start at 0x8800)

### Bootloader

The bootloader must include a JinkFS signature and disk definition header at the beginning of the boot sector : 

```s
BITS 16
ORG 0x7C00

; JinkFS Signature
jmp start
db 0x4A

DiskLabel: db "JINKOS10"        ; Can be what you want
BytesPerBlock: dw 1024          ; Number of bytes in 1 block
Reserved: dw 0                  ; Reserved (for Jink OS)
FileTableOffset: dd 0x7E00      ; Offset of where the FileTabel start
BlockAreaOffset: dd 0x8800      ; Offset of where the block area start
TotalOfEntries: db 128          ; Max number of entries. (2560/20 = 128)

start:
    jmp $

times 510-($-$$) db 0
dw 0xAA55
```

### File Entry
```
[0..7]   : Name (8 bytes)
[8..10]  : Extension (3 bytes)
[11]     : Reserved (1 byte)
[12..15] : Offset of start (4 bytes)
[16..19] : Number of blocks (4 bytes)
```

### Blocks
JinkFS is made of 'blocks'

A file can occupy several consecutive blocks. Each block is 1024 bytes long.

And it's designed like this : 

```
[0]                  : 0xFF (Start)
[1 .. N*1024-2]      : Data
[N*1024-1]           : 0xFE (End)
```

## Visual Scheme

General struct : 
```
+----------------+----------------+---------+---------+---------+
|  Bootloader    |   File Table   | Block 1 | Block 2 | Block 3 | ...
+----------------+----------------+---------+---------+---------+
|   512 bytes    |   2560 bytes   | 1024 B  | 1024 B  | 1024 B  |

```

General struct with offsets :
```
        +---------------------+  <- 0x7C00
        |     Bootloader      |  (512 bytes)
        |  Code + definitions |
        +---------------------+  <- 0x7E00
        |     File Table      |  (2560 bytes)
        | 128 entries × 20 B  |
        +---------------------+  <- 0x8800
        |       Block 1       |  (1024 bytes)
        |  File data starts   |
        +---------------------+  <- 0x8C00
        |       Block 2       |  (1024 bytes)
        +---------------------+  <- 0x9000
        |       Block 3       |  (1024 bytes)
        +---------------------+
               ... etc ...

```
