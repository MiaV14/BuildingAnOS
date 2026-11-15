#include "stdint.h"
#include "stdio.h"
#include "disk.h"
#include "fat.h"

void* g_data = (void*)0x00500200;

void _cdecl cstart_(uint16_t bootDrive)
{
    DISK disk;
    if (!DISK_Initialize(&disk, bootDrive))
    {
        printf("Disk init error\r\n");
        goto end;
    }

    DISK_ReadSectors(&disk, 19, 1, g_data);

    if (!FAT_Initialize(&disk))
    {
        printf("FAT init error\r\n");
        goto end;
    }

     // browse files in root
    FAT_File* fd = FAT_Open(&disk, "/");
    FAT_DirectoryEntry entry;
    int i = 0;
    while (FAT_ReadEntry(&disk, fd, &entry) && i++ < 5)
    {
        printf("  ");
        for (int i = 0; i < 11; i++)
            putc(entry.Name[i], stdout);
        printf("\r\n");
    }
    FAT_Close(fd);

    // read test.txt
    char buffer[100];
    uint32_t read;
    fd = FAT_Open(&disk, "mydir/test.txt");
    while ((read = FAT_Read(&disk, fd, sizeof(buffer), buffer)))
    {
        for (uint32_t i = 0; i < read; i++)
        {
            if (buffer[i] == '\n')
                putc('\r', stdout);
            putc(buffer[i], stdout);
        }
    }
    FAT_Close(fd);

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

    end:
        for (;;);
}