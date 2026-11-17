#include "utility.h"

uint32_t align(uint32_t number, uint32_t alignTo)
{
    uint32_t rem;
    if (alignTo == 0)
        return number;

    rem = number % alignTo;
    return (rem > 0) ? (number + alignTo - rem) : number;
}
