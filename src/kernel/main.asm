org 0x0                 ;BIOS always puts OS at 0x7C00. tells assembler where code will be located 
bits 16                 ;tells assembler to emit 16-bit code

%define ENDL 0x0D, 0x0A

;jump to main function
start:
    mov si, start_msg
    call puts

.halt:
    cli
    hlt

;prints string to screen
puts:
    ;save registers for modification
    push si
    push ax
    push bx

.loop:
    lodsb           ;loads next character in al
    or al, al       ;check if character is null
    jz .done        ;if null, jump to done

    mov ah, 0x0e    ;call bios interrupt
    mov bh, 0x00    ;set page number to 0
    int 0x10

    jmp .loop       ;loops until null character is found

.done:
    ;returns ax and si registers to their original values
    pop bx
    pop ax
    pop si
    ret

start_msg: db 'woagh :O', ENDL, 0 ;change this to change starting message