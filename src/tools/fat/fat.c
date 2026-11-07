#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <stdbool.h>

// structure for boot sector
#pragma pack(push, 1)
typedef struct {
    uint8_t BootJumpInstruction[3];
    uint8_t OemIdentifier[8];
    uint16_t BytesPerSector;
    uint8_t SectorsPerCluster;
    uint16_t ReservedSectors;
    uint8_t FatCount;
    uint16_t DirEntryCount;
    uint16_t TotalSectors;
    uint8_t MediaDescriptorType;
    uint16_t SectorsPerFat;
    uint16_t SectorsPerTrack;
    uint16_t Heads;
    uint32_t HiddenSectors;
    uint32_t LargeSectorCount;

    //extended boot record
    uint8_t DriveNumber;
    uint8_t _Reserved;
    uint8_t Signature;
    uint32_t VolumeId;         // serial number, value doesn't matter
    uint8_t VolumeLabel[11];   // 11 bytes, padded with spaces
    uint8_t SystemId[8];

} BootSector;
#pragma pack(pop)       // do not add padding bytes

// structure for directory entry
#pragma pack(push, 1)
typedef struct {
    uint8_t Name[11];
    uint8_t Attributes;
    uint8_t _Reserved;
    uint8_t CreatedTimeTenths;
    uint16_t CreatedTime;
    uint16_t CreatedDate;
    uint16_t AccessedDate;
    uint16_t FirstClusterHigh;
    uint16_t ModifiedTime;
    uint16_t ModifiedDate;
    uint16_t FirstClusterLow;
    uint32_t Size;
} DirectoryEntry;       
#pragma pack(pop)   // do not add padding bytes

// GLOBAL VARIABLES
BootSector global_BootSector;
uint8_t* global_Fat = NULL;
DirectoryEntry* global_RootDirectory = NULL;
uint32_t global_RootDirectoryEnd;

// READ BOOT SECTOR
// reads boot sector from disk and stores state in a global variable
bool readBootSector(FILE* disk){
    //returns boolean value of success
    //points to boot sector global variable
    return fread(&global_BootSector, sizeof(global_BootSector), 1, disk) > 0;
}

// READ SECTORS
// Parameters: file handle, sector number/lba, number of sectors to read, pointer to store the data
bool readSectors(FILE* disk, uint32_t lba, uint32_t count, void* bufferOut){
    bool ok = true;
    // before read: seek to the right position in the file
    // right position: sector number x sector size read from boot sector
    ok = ok && (fseek(disk, lba * global_BootSector.BytesPerSector, SEEK_SET) == 0);

    // read number of sectors from that position
    ok = ok && (fread(bufferOut, global_BootSector.BytesPerSector, count, disk) == count);
    return ok;
}

// READ FAT
// reads file allocation table into memory
// fat region begins right after reserved region
// reserved region's size can be found in the reserved sectors field from the boot sector
bool readFat(FILE* disk){
    global_Fat = (uint8_t*) malloc(global_BootSector.SectorsPerFat * global_BootSector.BytesPerSector);
    return readSectors(disk, global_BootSector.ReservedSectors, global_BootSector.SectorsPerFat, global_Fat);
}

// READ ROOT DIRECTORY
//
bool readRootDirectory(FILE* disk){
    // calculate beginning position
    uint32_t lba = global_BootSector.ReservedSectors + global_BootSector.SectorsPerFat * global_BootSector.FatCount;
    // number of sectors to read
    uint32_t size = sizeof(DirectoryEntry) * global_BootSector.DirEntryCount;
    uint32_t sectors = (size / global_BootSector.BytesPerSector);
    
    if (size % global_BootSector.BytesPerSector > 0){
        sectors++;
    }

    global_RootDirectoryEnd = lba + sectors;
    global_RootDirectory = (DirectoryEntry*) malloc(sectors * global_BootSector.BytesPerSector);
    return readSectors(disk, lba, sectors, global_RootDirectory);
}

DirectoryEntry* findFile(const char* name){
    for (uint32_t i = 0; i < global_BootSector.DirEntryCount; i++){
        if (memcmp(name, global_RootDirectory[i].Name, 11) == 0){
            return &global_RootDirectory[i];
        }
    }

    return NULL;
}

// READ FILE
// pass file as directory entry from findFile function
bool readFile(DirectoryEntry* fileEntry, FILE* disk, uint8_t* outputBuffer){
    bool ok = true;
    uint16_t currentCluster = fileEntry->FirstClusterLow;

    do {
        uint32_t lba = global_RootDirectoryEnd + (currentCluster - 2) * global_BootSector.SectorsPerCluster;
        ok = ok && readSectors(disk, lba, global_BootSector.SectorsPerCluster, outputBuffer);
        outputBuffer += global_BootSector.SectorsPerCluster * global_BootSector.BytesPerSector;

        uint32_t fatIndex = currentCluster * 3 / 2;
        if (currentCluster % 2 == 0){
            currentCluster = (*(uint16_t*)(global_Fat + fatIndex)) && 0x0FFF;
        }
        else{
            currentCluster = (*(uint16_t*)(global_Fat + fatIndex)) >> 4;
        }

    } while (ok && currentCluster < 0x0FF8);

    return ok;
}

// MAIN FUNCTION
// two command line arguments
int main( int argc, char** argv){

    // check if user entered correct number of parameters and prints syntax otherwise
    if (argc < 3){
        // defense disk image and file name we want to read
        printf("Syntax: %s <disk image> <file name>\n", argv[0]);
        return -1;
    }

    // read boot sector
    FILE* disk = fopen(argv[1], "rb");
    if (!disk){
        fprintf(stderr, "Cannot open disk image %s!\n", argv[1]);
        return -1;
    }

    // call function to handle any potential errors
    if (!readBootSector(disk)){
        fprintf(stderr, "Could not read boot sector!\n");
        return -2;
    }

    if (!readFat(disk)){
        fprintf(stderr, "Could not read FAT!\n");
        free(global_Fat);
        return -3;
    }

    if (!readRootDirectory(disk)){
        fprintf(stderr, "Could not read FAT!\n");
        free(global_Fat);
        free(global_RootDirectory);
        return -4;
    }

    DirectoryEntry* fileEntry = findFile(argv[2]);
    if (!fileEntry){
        fprintf(stderr, "Could not find file %s!\n", argv[2]);
        free(global_Fat);
        free(global_RootDirectory);
        return -5;
    }

    uint8_t* buffer = (uint8_t*) malloc(fileEntry->Size + global_BootSector.BytesPerSector);
    if (!readFile(fileEntry, disk, buffer)) {
        fprintf(stderr, "Could not read file %s!\n", argv[2]);
        free(global_Fat);
        free(global_RootDirectory);
        free(buffer);
        return -5;
    }

    for (size_t i = 0; i < fileEntry->Size; i++){
        if (isprint(buffer[i])) fputc(buffer[i], stdout);
        else printf("<%02x>", buffer[i]);
    }

    printf("\n");

    free(buffer);
    free(global_Fat);
    free(global_RootDirectory);
    return 0;
}