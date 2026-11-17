#include "stdint.h"
#include "stdio.h"
#include "disk.h"
#include "fat.h"

void far* g_data = (void far*)0x00500200;

void _cdecl cstart_(uint16_t bootDrive)
{
    // All local variables MUST be declared at the very top of the function in C89
    DISK disk;
    FAT_File far* fd;
    FAT_DirectoryEntry entry;
    int i;
    int k;
    char buffer[100];
    uint32_t read;
    uint32_t j;

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
    fd = FAT_Open(&disk, "/");
    i = 0;
    while (FAT_ReadEntry(&disk, fd, &entry) && i++ < 5)
    {
        printf("  ");
        for (k = 0; k < 11; k++)
            putc(entry.Name[k]);
        printf("\r\n");
    }
    FAT_Close(fd);

    // read test.txt
    fd = FAT_Open(&disk, "mydir/test.txt");
    while ((read = FAT_Read(&disk, fd, sizeof(buffer), buffer)))
    {
        for (j = 0; j < read; j++)
        {
            if (buffer[j] == '\n')
                putc('\r');
            putc(buffer[j]);
        }
    }
    FAT_Close(fd);

end:
    for (;;);
}
