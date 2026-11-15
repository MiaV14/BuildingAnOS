#pragma once

#include "stdint.h"

//DISK STRUCTURE
typedef struct {
    uint8_t id;
    uint16_t cylinders;
    uint16_t sectors;
    uint16_t heads;
} DISK;

//FUNCTIONS
//initialize disk given by the user
bool DISK_Initialize(DISK* disk, uint8_t driveNumber);
//read number of sectors requested 
bool DISK_ReadSectors(DISK* disk, uint32_t lba, uint8_t sectors, void* dataOut);