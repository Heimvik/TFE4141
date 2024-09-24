import threading
import time
import csv
import queue

PIPELINE_STAGES = 8 #Set dependent of PPA in final implementation
KEY_LENGTH = 64 #Shuld be 256 in final implemntation

E = 8954    ## Encryption key
N = 25553    ## Modulus


messages = {}
 
cases = queue.Queue()
caseMtx = threading.Lock()

'''
pipelinentermediates holds:
    [0] - Intermediate C after stage ID-1
    [1] - Intermediate P after stage ID-1
    [2] - Keeps the message ID
'''
pipelineIntermediates = [[queue.Queue() for _ in range(3)] for _ in range(PIPELINE_STAGES)]
intermediatesLoaded = [threading.Semaphore(0) for _ in range(PIPELINE_STAGES)]
intermediatesPopped = [threading.Semaphore(1) for _ in range(PIPELINE_STAGES)]
intermediateMtx = [threading.Lock() for _ in range(PIPELINE_STAGES)]

requestNewCase = threading.Semaphore(0)
grantNewCase = threading.Semaphore(0)

def getCases(filename):
    with open(filename, mode='r') as file:
        reader = csv.DictReader(file)
        casesQueue = queue.Queue()  # Initialize the queue
        
        for case in reader:
            M = int(case['M'])
            messageID = int(case['ID'])
            casesQueue.put([M, messageID])

            messages[messageID] = [M]   ## For final reults        
    return casesQueue

def blakelyMulMod(a, b, n):
    R = 0
    a_bin = bin(a)[2:][::-1]
    for i in range(len(a_bin)):
        bit = int(a_bin[(len(a_bin)-1)-i])  
        shift = R<<1                    ## Parelell B
        mul = bit * b                   ## Paralell B
        R = mul + shift                 
        if R>n:
            R = R - n
        if R>n:
            R = R - n
    return R


def blakeleyPipelineStart(stageID):
    stageActive = True
    while(stageActive):
        ## Request the pipeline controller a new case
        requestNewCase.release()
        grantNewCase.acquire()

        ## Get the next case
        caseMtx.acquire()
        nextCase = cases.get()
        caseMtx.release()

        ## Wait for asynch signal from next stage that it has popped off the previous values in time
        intermediatesPopped[stageID].acquire()

        ## Push values to pipelineIntermediates
        intermediateMtx[stageID].acquire()
        pipelineIntermediates[stageID][0].put(1)
        pipelineIntermediates[stageID][1].put(nextCase[0])
        pipelineIntermediates[stageID][2].put(nextCase[1])
        intermediateMtx[stageID].release()

        ## Signal to next stage that data is ready
        intermediatesLoaded[stageID].release()

        if stageFinished(pipelineIntermediates[stageID]):
            stageActive = False

def blakeleyPipelineStage(eSlice,n,stageID):
    stageActive = True
    while(stageActive):
        ## Wait for asynch signal from previous stage that data is ready
        intermediatesLoaded[stageID-1].acquire()

        ## Pop values from pipelineIntermediates
        intermediateMtx[stageID-1].acquire()
        currentC = pipelineIntermediates[stageID-1][0].pop(0)
        currentP = pipelineIntermediates[stageID-1][1].pop(0)
        currentID = pipelineIntermediates[stageID-1][2].pop()
        intermediateMtx[stageID-1].release()

        ## Signal to previous stage it has popped, such that the previous stage can replace its values
        intermediatesPopped[stageID-1].release()

        ## Accumulate new values
        if eSlice != (KEY_LENGTH/PIPELINE_STAGES):
            print(f"Error: eSlice is {eSlice} and not KEY_LENGTH/PIPELINE_STAGES")
            raise ValueError
        
        mask = 0b1
        for i in range(0, KEY_LENGTH/PIPELINE_STAGES):
            if eSlice & mask:
                currentC = blakelyMulMod(currentC, currentP, n)
            currentP = blakelyMulMod(currentP, currentP, n)
            mask = mask << 1

        ## Wait for asynch signal from next stage that it has popped off the previous values in time
        intermediatesPopped[stageID].acquire()

        ## Push values to pipelineIntermediates
        intermediateMtx[stageID].acquire()
        pipelineIntermediates[stageID][0].put(currentC)
        pipelineIntermediates[stageID][1].put(currentP)
        pipelineIntermediates[stageID][2].put(currentID)
        intermediateMtx[stageID].release()

        ## Signal to next stage that data is ready
        intermediatesLoaded[stageID].release()

        if stageFinished(pipelineIntermediates[stageID]):
            stageActive = False

def blakeleyPipelineEnd(stageID):
    stageActive = True
    while(stageActive):
        ## Wait for asynch signal from previous stage that data is ready
        intermediatesLoaded[stageID-1].acquire()

        ## Push values to pipelineIntermediates
        intermediateMtx[stageID-1].acquire()
        endC = pipelineIntermediates[stageID-1][0].pop(0)
        endP = pipelineIntermediates[stageID-1][1].pop(0)
        messageID = pipelineIntermediates[stageID-1][2].pop(0)
        intermediateMtx[stageID-1].release()

        messages[messageID].append(endC)    ## For final reults

        ## Signal to previous stage it has popped, such that the previous stage can put if it lies ahead in time
        intermediatesPopped[stageID-1].release()

        if stageFinished(pipelineIntermediates[stageID]):
            stageActive = False

def blakeleyPipelineController():
    controllerActive = True
    while(controllerActive):
        ## Wait for request from start stage
        requestNewCase.acquire()
        
        caseMtx.acquire()
        if cases.empty():
            ## Grant access to request, but insert nop if done
            cases.put([0,0,0,0])
            controllerActive = False
        caseMtx.release()
        grantNewCase.release()

def stageFinished(intermediates):
    return all(x == 0 for x in intermediates)

def splitE(number, keyLength, pipelineStages):
    binary_str = bin(number)[2:]
    
    total_length = keyLength  # total length of the binary string
    padded_binary_str = binary_str.zfill(total_length)
    
    chunk_size = total_length // pipelineStages
    
    chunks = [padded_binary_str[i:i + chunk_size] for i in range(0, total_length, chunk_size)]
    
    decimal_numbers = [int(chunk, 2) for chunk in chunks]
    
    return decimal_numbers[::-1]

def paralellBinartExp():

    ## Load all test cases that simulate the stream of M
    global cases
    cases = getCases("testCases.csv")

    eSlices = splitE(E, KEY_LENGTH, PIPELINE_STAGES)
    ## Start all threads and asynchromus communication (semaphores)
    threads = []
    threads.append(threading.Thread(target=blakeleyPipelineController))
    threads.append(threading.Thread(target=blakeleyPipelineStart, args=(0,)))
    for i in range(0,PIPELINE_STAGES):
        threads.append(threading.Thread(target=blakeleyPipelineStage, args=(eSlices[i],N,i+1)))
    threads.append(threading.Thread(target=blakeleyPipelineEnd, args=(PIPELINE_STAGES+1,)))
    
    for thread in threads:
        thread.start()  # Start all threads
        thread.join()   # Wait for all threads to finish
    
    ## Print final results
    for key in messages.keys():
        print(f"Message ID: {key} - C: {messages[key][1]}\t Expected: {messages}")

def main():
    paralellBinartExp()

if __name__ == "__main__":
    main()

