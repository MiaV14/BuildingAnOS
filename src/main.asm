org 0x7C00 ;BIOS always puts OS at 0x7C00. This tells assembler where code will be located 
bits 16 ;Tells assembler to emit 16-bit code

main:
    hlt ;Halt CPU until next interrupt

.halt:
    jmp .halt ;Infinite loop to halt the CPU

times 510-($-$$) db 0
dw 0AA55h