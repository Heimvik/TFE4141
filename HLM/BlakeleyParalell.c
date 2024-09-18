#pragma once
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <sys/time.h>

#include <pthread.h>
#include <semaphore.h>


uint16_t binaryExpParalell(uint16_t M, uint16_t mLength, uint8_t* e, uint16_t eLength, uint16_t n){
    uint16_t C = 1;
    uint16_t P = M;
    uint8_t* mask = (uint8_t*)malloc(sizeof(uint8_t)*eLength);
    mask[0] = 1;
    long startTime = getCurrentTimeInNanoseconds();

    //Spawn 4 threads: 3 doing work
    //Run eachof the tasks below for each thread
    //This is just psuedocode, but synchronization is expected to work
    

}

semaphore = 0;

void CPtask(){
    int localC;
    int localP;
    while(CPiteraterator<eLength){
        mutex_lock(&mutex);
            localP = P;
            localC = C;
            arrived++;
            if(arrived == 3){
                sem_post(&ts1);
                sem_wait(&ts2);
            }
        mutex_unlock(&mutex);

        sem_wait(&ts1);
        if(e[i] && mask[i]){
            sem_post(&ts1);
            C = blakeleyMulMod(localC,localP,n);
            CPiteraterator++;
        } else {
            sem_post(&ts1);
        }

        mutex_lock(&mutex);
            arrived--;
            if(arrived == 0){
                sem_post(&ts2);
                sem_wait(&ts1);
            }
        mutex_unlock(&mutex);

        sem_wait(&ts2);
        sem_post(&ts2);
    }
}
void PPtask(){
    int localP;
    while(PPiterator<elength-1){
        mutex_lock(&mutex);
            localP = P;
            arrived++;
            if(arrived == 3){
                sem_post(&ts1);
                sem_wait(&ts2);
            }
        mutex_unlock(&mutex);

        sem_wait(&ts1);
        sem_post(&ts1);
        P = blakeleyMulMod(localP,localP,n);
        PPiterator++;

        mutex_lock(&mutex);
            arrived--;
            if(arrived == 0){
                sem_post(&ts2);
                sem_wait(&ts1);
            }
        mutex_unlock(&mutex);

        sem_wait(&ts2);
        sem_post(&ts2);
    }
}

void SLtask(){
    while(SLiteraterator<eLength-1){
        mutex_lock(&mutex);
            arrived++;
            if(arrived == 3){
                sem_post(&ts1);
                sem_wait(&ts2);
            }
        mutex_unlock(&mutex);

        sem_wait(&ts1);
        sem_post(&ts1);
        shiftLeft(mask,SLiteraterator);
        SLiteraterator++;

        mutex_lock(&mutex);
            arrived--;
            if(arrived == 0){
                sem_post(&ts2);
                sem_wait(&ts1);
            }
        mutex_unlock(&mutex);

        sem_wait(&ts2);
        sem_post(&ts2);
    }
}
