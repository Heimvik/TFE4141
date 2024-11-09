#pragma once
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <sys/time.h>
#include <unistd.h>

#include <pthread.h>
#include <semaphore.h>


//First: the straight forward implementation of C = M^e mod N, without any improvements
long long getCurrentNs();

void toBinary(uint8_t* dst, uint32_t decNumber, uint16_t length);

uint32_t toUint32(uint8_t* binaryArray, uint16_t length);

void blakeleyMulMod(uint8_t* R, uint8_t* a, uint8_t* b, uint16_t cpLength, uint16_t n,uint16_t nLength);

uint32_t binaryExpSerial(uint8_t* M, uint16_t mLength, uint8_t* e, uint16_t eLength, uint16_t n, uint16_t nLength);
