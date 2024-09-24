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
    

def blakelyMulMod(a, b, n):
    R = 0
    a_bin = bin(a)[2:][::-1]
    for i in range(len(a_bin)):
        bit = int(a_bin[(len(a_bin)-1)-i])  
        shift = R<<1
        mul = bit * b
        R = mul + shift                 ## Paralell B (split the bitshift and mul, and do both in paralell)
        if R>n:
            R = R - n
        if R>n:
            R = R - n
    return R

def serialBinaryExp(M, e, n):
    mask = 0b1
    C = 1
    P = M
    for i in range(0, len(bin(e)[2:])):
        if e & mask:
            C = blakelyMulMod(C, P, n)      ## Paralell A
        P = blakelyMulMod(P, P, n)          ## Paralell A
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
