org 0x7C00          ; BIOS always puts OS at 0x7C00. Tells assembler where code will be located 
bits 16             ; Tells assembler to emit 16-bit code

%define ENDL 0x0D, 0x0A

; FAT12 header
jmp short start
nop

bdb_oem:                db 'MSWIN4.1'   ; 8 bytes
bdb_bytes_per_sector:   dw 512          ; bytes per sector
bdb_sectors_per_cluster: db 1           ; sectors per cluster
bdb_reserved_sectors:   dw 1            ; reserved sectors    
bdb_fat_count:          db 2            ; number of FATs
bdb_dir_entries_count:  dw 0E0h         ; number of root directory entries
bdb_total_sectors:      dw 2880         ; total sectors (2880 * 512 = 1.44 MB)
bdb_media_descriptor_type: db 0F0h      ; media descriptor type (F0 = 3.5" floppy disk)
bdb_sectors_per_fat:    dw 9            ; sectors per FAT
bdb_sectors_per_track:  dw 18           ; sectors per track
bdb_heads:              dw 2            ; number of heads
bdb_hidden_sectors:     dd 0            ; number of hidden sectors
bdb_large_sector_count: dd 0            ; large sector count

; extended boot record
ebr_drive_number:       db 0            ; drive number (0 = floppy, 80h = hard disk)
                        db 0            ; reserved
ebr_signature:          db 29h          ; extended boot signature
ebr_volume_id:          dd 12h, 34h, 56h, 78h ; volume ID (serial number)
ebr_volume_label:       db 'Silly Goose OS' ; volume label (11 bytes)
ebr_file_system_type:   db 'FAT12   '   ; file system type (8 bytes)

; jump to main function
start:
    ; setup data segments
    mov ax, 0           ; can't set ds/es directly
    mov ds, ax
    mov es, ax
    
    ; setup stack
    mov ss, ax
    mov sp, 0x7C00      ; stack grows downwards from where we are loaded in memory

    ; some BIOSes might start us at 07C0:0000 instead of 0000:7C00, make sure we are in the expected location
    push es
    push word .after
    retf

.after:
    ; read something from floppy disk
    mov [ebr_drive_number], dl

    ; show loading message
    mov si, msg_loading
    call puts

    ; read drive parameters (sectors per track and head count)
    push es
    mov ah, 08h
    int 13h
    jc floppy_error
    pop es

    and cl, 0x3F                        ; remove top 2 bits
    xor ch, ch
    mov [bdb_sectors_per_track], cx     ; sector count

    inc dh
    mov [bdb_heads], dh                 ; head count

    ; compute LBA of root directory = reserved + fats * sectors_per_fat
    mov ax, [bdb_sectors_per_fat]
    mov bl, [bdb_fat_count]
    xor bh, bh
    mul bx                              ; ax = (fats * sectors_per_fat)
    add ax, [bdb_reserved_sectors]      ; ax = LBA of root directory
    push ax

    ; compute size of root directory = (32 * number_of_entries) / bytes_per_sector
    mov ax, [bdb_dir_entries_count]
    shl ax, 5                           ; ax *= 32
    xor dx, dx                          ; dx = 0
    div word [bdb_bytes_per_sector]     ; number of sectors we need to read

    test dx, dx                         ; if dx != 0, add 1
    jz .root_dir_after
    inc ax                              ; division remainder != 0, add 1

.root_dir_after:
    ; read root directory
    mov cl, al                          ; cl = number of sectors to read = size of root directory
    pop ax                              ; ax = LBA of root directory
    mov dl, [ebr_drive_number]          ; dl = drive number
    mov bx, buffer                      ; es:bx = buffer
    call disk_read

    ; search for kernel.bin
    xor bx, bx
    mov di, buffer

.search_kernel:
    mov si, file_stage2_bin
    mov cx, 11                          ; compare up to 11 characters
    push di
    repe cmpsb
    pop di
    je .found_kernel

    add di, 32
    inc bx
    cmp bx, [bdb_dir_entries_count]
    jl .search_kernel

    ; kernel not found
    jmp kernel_not_found_error

.found_kernel:
    ; di should have the address to the entry
    mov ax, [di + 26]                   ; first logical cluster field (offset 26)
    mov [stage2_cluster], ax

    ; load FAT from disk into memory
    mov ax, [bdb_reserved_sectors]
    mov bx, buffer
    mov cl, [bdb_sectors_per_fat]
    mov dl, [ebr_drive_number]
    call disk_read

    ; read kernel and process FAT chain
    mov bx, KERNEL_LOAD_SEGMENT
    mov es, bx
    mov bx, KERNEL_LOAD_OFFSET

.load_kernel_loop:
    ; Read next cluster
    mov ax, [stage2_cluster]
    
    add ax, 31                          ; first cluster = (kernel_cluster - 2) * sectors_per_cluster + start_sector
    mov cl, 1
    mov dl, [ebr_drive_number]
    call disk_read

    add bx, [bdb_bytes_per_sector]

    ; compute location of next cluster
    mov ax, [stage2_cluster]
    mov cx, 3
    mul cx
    mov cx, 2
    div cx                              ; ax = index of entry in FAT, dx = cluster mod 2

    mov si, buffer
    add si, ax
    mov ax, [ds:si]                     ; read entry from FAT table at index ax

    or dx, dx
    jz .even

.odd:
    shr ax, 4
    jmp .next_cluster_after

.even:
    and ax, 0x0FFF

.next_cluster_after:
    cmp ax, 0x0FF8                      ; end of chain
    jae .read_finish

    mov [stage2_cluster], ax
    jmp .load_kernel_loop

.read_finish:
    ; jump to our kernel
    mov dl, [ebr_drive_number]          ; boot device in dl

    mov ax, KERNEL_LOAD_SEGMENT         ; set segment registers
    mov ds, ax
    mov es, ax

    jmp KERNEL_LOAD_SEGMENT:KERNEL_LOAD_OFFSET

    jmp wait_key_and_reboot             ; should never happen

    cli                                 ; disable interrupts
    hlt

; prints string to screen
puts:
    push si
    push ax
    push bx

.loop:
    lodsb                               ; loads next character in al
    or al, al                           ; check if character is null
    jz .done                            ; if null, jump to done

    mov ah, 0x0e                        ; call bios interrupt
    mov bh, 0x00                        ; set page number to 0
    int 0x10

    jmp .loop                           ; loops until null character is found

.done:
    pop bx
    pop ax
    pop si
    ret

; ERROR HANDLERS
floppy_error:
    mov si, msg_read_failed
    call puts
    jmp wait_key_and_reboot

kernel_not_found_error:
    mov si, msg_kernel_not_found
    call puts
    jmp wait_key_and_reboot

wait_key_and_reboot:
    mov ah, 0
    int 16h                             ; wait for key press

    mov ax, 0x0000
    int 0x19                            ; reboot the system

.halt:
    cli                                 ; disable interrupts
    hlt                                 ; halt CPU

; DISK ROUTINES
; convert LBA address to CHS address
lba_to_chs:
    push ax
    push dx

    xor dx, dx                          ; dx = 0
    div word [bdb_sectors_per_track]    ; ax = LBA / Sectors per track, dx = LBA % Sectors per track

    inc dx                              ; dx = (LBA % SectorsPerTrack + 1) = sector
    mov cx, dx                          ; cx = sector

    xor dx, dx                          ; dx = 0
    div word [bdb_heads]                ; ax = (LBA / SectorsPerTrack) / Heads = cylinder
    mov dh, dl                          ; dh = head
    mov ch, al                          ; ch = cylinder (lower 8 bits)
    shl ah, 6
    or cl, ah                           ; put upper 2 bits of cylinder in CL

    pop ax
    mov dl, al                          ; restore DL
    pop ax
    ret

; reads a sector from disk into memory
disk_read:
    push ax                             ; save registers we will modify
    push bx
    push cx
    push dx
    push di

    push cx                             ; temporarily save CL (# of sectors to read)
    call lba_to_chs                     ; convert LBA to CHS
    pop ax                              ; AL = # of sectors to read
    
    mov ah, 02h
    mov di, 3                           ; retry count

.retry:
    pusha                               ; save all registers
    stc                                 ; set carry flag
    int 13h                             ; carry flag cleared = success, carry flag set = failure
    jnc .done                           ; if carry flag is clear, jump to done
    
    popa                                ; restore all registers
    call disk_reset

    dec di
    test di, di
    jnz .retry                          ; if retry count is not zero, retry

.fail:
    jmp floppy_error

.done:
    popa                                ; restore all registers
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; reset disk controller
disk_reset:
    pusha
    mov ah, 0
    stc
    int 13h
    jc floppy_error
    popa
    ret

msg_loading:            db 'HONK', ENDL, 0 
msg_read_failed:        db 'disk failed!', ENDL, 0
msg_kernel_not_found:   db 'no STAGE2!', ENDL, 0
file_kernel_bin:        db 'STAGE2  BIN'
kernel_cluster:         dw 0

KERNEL_LOAD_SEGMENT equ 0x2000
KERNEL_LOAD_OFFSET  equ 0x0000

times 510-($-$$) db 0
dw 0AA55h

buffer: