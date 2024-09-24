#include "BlakelySerial.h"
#include <stdio.h>

//Note: This is a little endian implementation

void toBinary(uint8_t* dst, uint32_t decNumber, uint16_t length) {
    for (int i = 0; i < length; i++) {
        dst[i] = 0;
    }
    for (int i = 0; i < length && i < length; i++) {
        dst[i] = decNumber % 2;
        decNumber = decNumber / 2;
    }
}

uint32_t toUint32(uint8_t* binaryArray, uint16_t length) {
    uint32_t result = 0;
    for (int i = length - 1; i >= 0; i--) {
        result = (result << 1) | (binaryArray[i] & 1);
    }
    return result;
}

long long getCurrentNs() {
    struct timespec ts;
    if (clock_gettime(CLOCK_REALTIME, &ts) == 0) {
        return (long long)ts.tv_sec * 1000000000LL + ts.tv_nsec;
    } else {
        return -1;
    }
}

void bwRShift(uint8_t* dst, uint8_t* src, uint16_t srcLength){
    uint8_t tmp[srcLength];
    memcpy(tmp,src,srcLength);
    for(uint16_t index = 0;index<srcLength-1;index++){
        tmp[index+1] = src[index];
    }
    tmp[0] = 0;
    memcpy(dst,tmp,srcLength);
}

void bwMul(uint8_t* dst, uint8_t a, uint8_t* b, uint16_t bLength){
    printf("A: %d\n",a);
    for(uint16_t i = 0;i<bLength;i++){
        printf("B[%d]=%d\n",i,b[i]);                //Done in paralell in HW
    }
    for(uint16_t i = 0;i<bLength;i++){
        dst[i] = a & b[i];
        printf("DST[%d]=%d\n",i,dst[i]);            //Done in paralell in HW
    }
    sleep(1);
}

void bwAdd(uint8_t* dst, uint8_t* a,uint16_t aLength, uint8_t* b, uint16_t bLength){
    uint32_t result = toUint32(a,aLength) + toUint32(b,bLength);
    toBinary(dst,result,aLength);
}

void bwSub(uint8_t* dst, uint8_t* a,uint16_t aLength, uint16_t n){
    uint32_t result = toUint32(a,aLength) - n;
    toBinary(dst,result,aLength);
}

uint32_t binaryExpSerial(uint8_t* M, uint16_t mLength, uint8_t* e, uint16_t eLength, uint16_t n, uint16_t nLength){

    uint8_t C[mLength];
    for (int i = 0; i < mLength; i++) {
        if(i == 0){
            C[i] = 1;
        } else {
            C[i] = 0;
        }
    }
    uint8_t P[mLength];  
    memcpy(P,M,mLength);

    uint8_t mask[eLength];
    mask[0] = 1;
    long startTime = getCurrentNs();

    for(uint16_t i = 0;i<eLength;i++){
        if(e[i] & mask[i]){
            blakeleyMulMod(C,C,P,mLength,n,nLength);  //Done in parallel
        }
        blakeleyMulMod(P,P,P,mLength,n,nLength);      //Done in parallel   (Not do at the last iteration)
        bwRShift(mask,mask,eLength);                  //Done in parallel   (Not do at the last iteration)
    }
    long endTime = getCurrentNs();
    printf("Time used serially: %ld ns\n",endTime-startTime);
    return toUint32(C,mLength);
}
/*
void blakeleyMulMod(uint8_t* R, uint8_t* a, uint8_t* b, uint16_t cpLength, uint16_t n,uint16_t nLength){
    printf("a: %d\n",toUint32(a,cpLength));
    printf("b: %d\n",toUint32(b,cpLength));
    toBinary(R,toUint32(a,cpLength)*toUint32(b,cpLength),cpLength);
}
*/

void printBinaryArray(uint8_t* binaryArray, uint16_t length) {
    for (uint16_t i = 0; i < length; i++) {
        printf("%u", binaryArray[i]);
    }
    printf("\t");
}


//Will save in a
void blakeleyMulMod(uint8_t* R, uint8_t* a, uint8_t* b, uint16_t cpLength, uint16_t n,uint16_t nLength){
    printf("\nA:\n");
    printBinaryArray(a,cpLength);
    printf("\nB:\n");
    printBinaryArray(b,cpLength);
    uint8_t currentResult[cpLength];
    for(uint16_t i = 0;i<nLength;i++){
        uint8_t shiftResult[cpLength];
        uint8_t mulResult[cpLength];
        printf("Init R: %d\n",toUint32(R,cpLength));
        bwRShift(shiftResult,R,cpLength);   
        bwMul(mulResult,a[(nLength-1)-i],b,cpLength);

        bwAdd(R,shiftResult,cpLength,mulResult,cpLength);
        printf("BWSHIFT\tBWMUL\tR\n");
        printBinaryArray(shiftResult,cpLength);
        printBinaryArray(mulResult,cpLength);
        printBinaryArray(R,cpLength);
        printf("\n");
        //printf("Final R: %d\nShiftResult: %d\nMulResult: %d\n",toUint32(R,cpLength),toUint32(shiftResult,cpLength),toUint32(mulResult,cpLength));
        /*
        if(toUint32(R,cpLength) >= n){
            bwSub(R,R,cpLength,n);
        }
        if(toUint32(R,cpLength) >= n){
            bwSub(R,R,cpLength,n);
        }
        */
    }
}


