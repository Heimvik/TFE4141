import csv
import threading
import time

E = 457     ## Encryption key
N = 2553    ## Modulus

clockSem = threading.Semaphore(0)

def clock():
    while True:
        time.sleep(0.0001)  # 10 kHz clock cycle (100 microseconds)
        clockSem.release()  # Trigger the next step in the algorithm

def start_clock():
    clock_thread = threading.Thread(target=clock)
    clock_thread.daemon = True  # Ensure it exits when the main program exits
    clock_thread.start()


def getCases(filename):
    with open(filename, mode='r') as file:
        reader = csv.DictReader(file)
        cases = []
        
        for case in reader:
            M = int(case['M'])
            cases.append([M])
        
        return cases
    

statusRegister = [0,0,0,0,0,0]
debugRegister = [0,0,0,0,0,0]
performanceRegister = [0,0,0,0,0,0]

def blakelyMulMod(a, b, n):
    R = 0
    a_bin = bin(a)[2:][::-1]
    for i in range(len(a_bin)):
        bit = int(a_bin[(len(a_bin)-1)-i])  
        debugRegister[1] = bit
        shift = R<<1
        debugRegister[2] = shift 
        mul = bit * b
        debugRegister[3] = mul
        R = mul + shift                 ## Paralell B (split the bitshift and mul, and do both in paralell)
        statusRegister[2] = 1
        if R>n:
            statusRegister[3] = 1     
            R = R - n
        if R>n:
            statusRegister[4] = 1
            R = R - n
        statusRegister[2] = 0
        statusRegister[3] = 0
        statusRegister[4] = 0
    return R

def serialBinaryExp(M, e, n):
    mask = 0b1
    C = 1
    P = M

    for i in range(0, len(bin(e)[2:])):
        debugRegister[0] = i
        if e & mask:
            statusRegister[0] = 1
            C = blakelyMulMod(C, P, n)      ## Paralell A
        statusRegister[1] = 1
        P = blakelyMulMod(P, P, n)          ## Paralell A
        statusRegister[0] = 0
        statusRegister[1] = 0
        mask = mask << 1 
    return C

def main():
    testCases = getCases("testCases.csv")
    currentCase = 0
    while(currentCase != len(testCases)-1):
        M = testCases[currentCase][0]
        print("Result:",serialBinaryExp(M,E,N))
        print("Expected:",(pow(M,E,N)))
        currentCase +=1

if __name__ == "__main__":
    main()

##WORKS, but:
# 1. Add the stream of bytes integrated into the start of the pipeline, read in when empty space in pipeline
# 2. Add status register, performance coutners and debug registers
# 3. Add multithreading to and asynchronus pipeline to signify the workings of it
