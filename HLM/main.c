#include "BlakelySerial.h"
#include <stdio.h>
#include <math.h>

#define N 5
#define N_LENGTH 16

#define M 2
#define M_LENGTH N_LENGTH+2

#define E 5
#define E_LENGTH 8



void testBinaryExp(){
    uint8_t e[E_LENGTH];
    toBinary(e,E,E_LENGTH);

    uint8_t m[M_LENGTH];
    toBinary(m,M,M_LENGTH);

    uint32_t result = binaryExpSerial(m,(uint16_t)M_LENGTH,e,(uint16_t)E_LENGTH,(uint16_t)N,(uint16_t)N_LENGTH);
    uint32_t expected = (uint32_t)pow(M,toUint32(e,E_LENGTH));
    
    printf("Expected: %i\tResult: %d\n",expected,result);
}


int main(){
    testBinaryExp();
}