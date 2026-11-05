org 0x7C00 ;BIOS always puts OS at 0x7C00. tells assembler where code will be located 
bits 16 ;tells assembler to emit 16-bit code

%define ENDL 0x0D, 0x0A

; FAT12 header
jmp short start
nop

bdb_oem: db 'MSWIN4.1' ;8 bytes
bdb_byt: dw 512 ;bytes per sector
bdb_sectors_per_cluster: db 1 ;sectors per cluster
bdb_reserved_sectors: dw 1 ;reserved sectors    
bdb_fat_count: db 2 ;number of FATs
bdb_dir_entries_count: dw 0E0h ;number of root directory entries
bdb_total_sectors: dw 2880 ;total sectors (2880 * 512 = 1.44 MB)
bdb_media_descriptor_type: db 0F0h ;media descriptor type (F0 = 3.5" floppy disk)
bdb_sectors_per_fat: dw 9 ;sectors per FAT
bdb_sectors_per_track: dw 18 ;sectors per track
bdb_heads: dw 2 ;number of heads
bdb_hidden_sectors: dd 0 ;number of hidden sectors
bdb_large_sector_count: dd 0 ;large sector count

; extended boot record
ebr_drive_number: db 0 ;drive number (0 = floppy, 80h = hard disk)
                  db 0 ;reserved
ebr_signature: db 29h ;extended boot signature
ebr_volume_id: dd 12h, 34h, 56h, 78h ;volume ID (serial number)
ebr_volume_label: db 'Silly Goose OS' ;volume label (11 bytes)
ebr_file_system_type: db 'FAT12   ' ;file system type (8 bytes)

;jump to main function
start:
    jmp main

;prints string to screen
puts:
    ;save si and ax registers for modification
    push si
    push ax

.loop:
    lodsb ;loads next character in al
    or al, al ;check if character is null
    jz .done ;if null, jump to done

    mov ah, 0x0e ;call bios interrupt
    mov bh, 0x00 ;set page number to 0
    int 0x10

    jmp .loop ;loops until null character is found

.done:
    ;returns ax and si registers to their original values
    pop ax
    pop si
    ret

main:
    ;setup data
    mov ax, 0
    mov ds, ax
    mov es, ax

    ;setup stack
    mov ss, ax
    mov sp, 0x7C00 ;set stack pointer to 0x7C00
    
    ;read something from floppy disk
    mov [ebr_drive_number], dl ;set drive number to floppy disk
    mov ax, 1 ;LBA=1
    mov cl, 1 ;read 1 sector
    mov bx, 0x7E00 ;buffer to read into
    call disk_read ;read sector from disk

    ;print message
    mov si, start_msg
    call puts

    cli ;disable interrupts
    hlt ;halt CPU

floppy_error:
    mov si, msg_read_failed
    call puts
    jmp wait_key_and_reboot

wait_key_and_reboot:
    mov ah, 0
    int 16h ;wait for key press

    mov ax, 0x0000
    int 0x19 ;reboot the system

.halt:
    cli ;disable interrupts
    hlt ;halt CPU

;convert LBA address to CHS address
lba_to_chs:
    push ax
    push dx

    xor dx, dx ;dx = 0
    div word[bdb_sectors_per_track] ;ax = LBA / Sectors per track, dx = LBA % Sectors per track

    inc dx ;dx = (LBA % SectorsPerTrack + 1) = sector
    mov cx, dx ;cx = sector

    xor dx, dx ;dx = 0
    div word[bdb_heads] ;ax = (LBA / SectorsPerTrack) / Heads = cylinder
                        ;dx = (LBA / SectorsPerTrack) % Heads = head
    mov dh, dl ;dh = head
    mov ch, al ;ch = cylinder (lower 8 bits)
    shl ah, 6
    or cl, ah ;put upper 2 bits of cylinder in CL

    pop ax
    mov dl, al ;restore DL
    pop ax
    ret

;reads a sector from disk into memory
disk_read:
    push ax ;save registers we will modify
    push bx
    push cx
    push dx
    push di

    push cx ;temporarily save CL (# of sectors to read)
    call lba_to_chs ;convert LBA to CHS
    pop ax ; AL = # of sectors to read
    
    mov ah, 02h
    mov di, 3 ;retry count

.retry:
    pusha ;save all registers
    stc ;set carry flag
    int 13h ;carry flag cleared = success, carry flag set = failure
    jnc .done ;if carry flag is clear, jump to done
    
    ;if read failed
    popa ;restore all registers
    call disk_reset

    dec di
    test di, di
    jnz .retry ;if retry count is not zero, retry

.fail:
    ; all attempts failed, print error message and halt
    jmp floppy_error

.done:
    popa ;restore all registers

    pop di
    pop dx
    pop cx
    pop bx
    pop ax ;restore registers modified
    ret

;reset disk controller
disk_reset:
    pusha
    mov ah, 0
    int 13h
    jc floppy_error
    popa
    ret

start_msg: db 'woagh :O', ENDL, 0 ;change this to change starting message
msg_read_failed: db 'Read from disk failed!', ENDL, 0

times 510-($-$$) db 0
dw 0AA55h