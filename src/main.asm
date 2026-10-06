org 0x7C00 ;BIOS always puts OS at 0x7C00. This tells assembler where code will be located 
bits 16 ;Tells assembler to emit 16-bit code

%define ENDL 0x0D, 0x0A

start:
    jmp main ;jump to main function

puts:
    ;Save si and ax registers for modification
    push si
    push ax

.loop:
    lodsb ;Loads next character in al
    or al, al ;Check if character is null
    jz .done 

    mov ah, 0x0e ;Call bios interrupt
    mov bh, 0x00 ;Set page number to 0
    int 0x10

    jmp .loop ;loops until null character is found

.done:
    ;Returns ai and ax registers to their original values
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
    mov sp, 0x7C00 ;Set stack pointer to 0x7C00 and stack grows downward from where it is loaded
    
    ;print message
    mov si, start_msg
    call puts

    hlt ;Halt CPU until next interrupt

.halt:
    jmp .halt ;Infinite loop to halt the CPU

start_msg: db 'woagh :O', ENDL, 0

times 510-($-$$) db 0
dw 0AA55h