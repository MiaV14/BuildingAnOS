#include "stdint.h"
#include "stdio.h"

void _cdecl cstart_(uint16_t bootDrive)
{
    puts("Silly Goose OS\r\n");

    //PRINTF TEST CASES
    /*printf("Formatted %% %c %s\r\n", 'a', "string");
    printf("Formatted %d %i %x %p %o %hd %hi %hhu %hhd\r\n", 1234, -5678, 0xdead, 0xbeef, 012345, (short)27, (short)-42, (unsigned char)20, (char)-10);
    printf("Formatted %ld %lx %lld %llx\r\n", -100000000l, 0xdeadbeeful, 10200300400ll, 0xdeadbeeffeebdaedull);*/

    puts("                                   ___\r\n");
    puts("                               ,-\"\"   `.\r\n");
    puts("                             ,'  _   e )`-._\r\n");
    puts("                            /  ,' `-._<.===-'\r\n");
    puts("                           /  /\r\n");
    puts("                          /  ;\r\n");
    puts("              _          /   ;\r\n");
    puts(" (`._    _.-\"\" \"\"--..__,'    |\r\n");
    puts(" <_  `-\"\"                    |\r\n");
    puts("<`-                          :\r\n");
    puts(" (__   <__.                  ;\r\n");
    puts("    `-.   '-.__.      _.'    /\r\n");
    puts("        `      `-.__,-'    _,'\r\n");
    puts("         `._    ,    /__,-'\r\n");
    puts("            \"\"._,__,'< <____\r\n");
    puts("                 | |  `----.`.\r\n");
    puts("                 | |        ` `.\r\n");
    puts("                 ; |___      `-``\r\n");
    puts("                 ` --<\r\n");

    for (;;);
}