org 0x7C00 ;BIOS always puts OS at 0x7C00. tells assembler where code will be located 
bits 16 ;tells assembler to emit 16-bit code

%define ENDL 0x0D, 0x0A

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
    
    ;print message
    mov si, start_msg
    call puts

    hlt ;halt CPU until next interrupt

.halt:
    jmp .halt ;infinite loop to halt the CPU

start_msg: db 'woagh :O', ENDL, 0 ;change this to change starting message

times 510-($-$$) db 0
dw 0AA55h