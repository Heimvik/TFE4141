import threading
import time
import csv
import queue

PIPELINE_STAGES = 8 #Set dependent of PPA in final implementation
KEY_LENGTH = 64 #Shuld be 256 in final implemntation

E = 8954    ## Encryption key
N = 25553    ## Modulus


messages = {}
stageDoingMessage = [0 for i in range(PIPELINE_STAGES+2)]

cases = queue.Queue()
caseMtx = threading.Lock()

'''
pipelinentermediates holds:
    [0] - Intermediate C after stage ID-1
    [1] - Intermediate P after stage ID-1
    [2] - Keeps the message ID
'''
pipelineIntermediates = [[queue.Queue() for _ in range(3)] for _ in range(PIPELINE_STAGES+2)]
intermediatesLoaded = [threading.Semaphore(0) for _ in range(PIPELINE_STAGES+2)]
intermediatesPopped = [threading.Semaphore(1) for _ in range(PIPELINE_STAGES+2)]
intermediateMtx = [threading.Lock() for _ in range(PIPELINE_STAGES+2)]

requestNewCase = threading.Semaphore(0)
grantNewCase = threading.Semaphore(0)

pipelineFinished = threading.Semaphore(0)


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

def splitE(number, keyLength, pipelineStages):
    binary_str = bin(number)[2:]
    total_length = keyLength  # total length of the binary string
    padded_binary_str = binary_str.zfill(total_length)
    chunk_size = total_length // pipelineStages
    chunks = [padded_binary_str[i:i + chunk_size] for i in range(0, total_length, chunk_size)]
    decimal_numbers = [int(chunk, 2) for chunk in chunks]
    return decimal_numbers[::-1]

def reportResults():
    print("\n--- Report Results ---\n")
    mismatch_found = False
    
    # Print the header
    print(f"{'Message ID':<15} {'Pipeline Result':<20} {'Expected Result':<20} {'Mismatch':<10}")
    print("-" * 65)  # Divider line

    for messageID, data in messages.items():
        M = data[0]  # Original message
        pipelineResult = data[1]  # Result from the pipeline
        
        # Compute the expected result using the built-in pow function
        expectedResult = pow(M, E, N)
        
        # Print the results in table format
        mismatch = "Yes" if pipelineResult != expectedResult else "No"
        print(f"{messageID:<15} {pipelineResult:<20} {expectedResult:<20} {mismatch:<10}")
        
        # Check if the results match
        if pipelineResult != expectedResult:
            print(f"Mismatch found for message ID {messageID}!")
            mismatch_found = True
    
    if not mismatch_found:
        print("\nAll results are correct!")
    else:
        print("\nThere were mismatches in the results.")


def reportProgress():
    print("\n--- Report Results ---\n")
    
    # Iterate through each stage and visualize the message IDs
    for stageID in range(PIPELINE_STAGES + 2):
        # Indent the stages progressively to create a "pipeline" shape
        indent = " " * (stageID * 4)  # Increase indentation with each stage
        
        # Check if there's a message ID in stageDoingMessage for the current stage
        message_id = stageDoingMessage[stageID]
        if message_id != 0:  # Assuming 0 means no message is being processed
            print(f"{indent}Stage {stageID}: Message ID {message_id}")
        else:
            print(f"{indent}Stage {stageID}: Empty")

    print("\n--- End of Pipeline Results ---\n")

def getQueueElement(q):
    if not q.empty():
        return q.queue[0]  # Access the first element
    else:
        return "Empty"  # Return 'Empty' if the queue is empty


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
    while(True):
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
        stageDoingMessage[stageID] = getQueueElement(pipelineIntermediates[stageID][2])
        intermediateMtx[stageID].release()

        ## Signal to next stage that data is ready
        intermediatesLoaded[stageID].release()

def blakeleyPipelineStage(eSlice,n,stageID):
    while(True):
        ## Wait for asynch signal from previous stage that data is ready
        intermediatesLoaded[stageID-1].acquire()
        
        ## Get values from pipelineIntermediates
        intermediateMtx[stageID-1].acquire()
        currentC = pipelineIntermediates[stageID-1][0].get(0)
        currentP = pipelineIntermediates[stageID-1][1].get(0)
        currentID = pipelineIntermediates[stageID-1][2].get()
        stageDoingMessage[stageID] = getQueueElement(pipelineIntermediates[stageID][2])
        intermediateMtx[stageID-1].release()

        ## Signal to previous stage it has popped, such that the previous stage can replace its values
        intermediatesPopped[stageID-1].release()

        ## Accumulate new values
        if KEY_LENGTH % PIPELINE_STAGES != 0:
            print(f"Error: KEY_LENGTH / PIPELINE_STAGES is not an integer")
            raise ValueError

        if len(bin(eSlice)[2:]) > (KEY_LENGTH/PIPELINE_STAGES):
            print(f"Error: eSlice is {eSlice} and not KEY_LENGTH/PIPELINE_STAGES")
            raise ValueError
        
        mask = 0b1
        for i in range(0, int(KEY_LENGTH/PIPELINE_STAGES)):
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

def blakeleyPipelineEnd(stageID):
    while(True):
        ## Wait for asynch signal from previous stage that data is ready
        intermediatesLoaded[stageID-1].acquire()

        ## Push values to pipelineIntermediates
        intermediateMtx[stageID-1].acquire()
        endC = pipelineIntermediates[stageID-1][0].get(0)
        endP = pipelineIntermediates[stageID-1][1].get(0)
        messageID = pipelineIntermediates[stageID-1][2].get(0)
        stageDoingMessage[stageID] = getQueueElement(pipelineIntermediates[stageID][2])
        intermediateMtx[stageID-1].release()

        messages[messageID].append(endC)    ## For final reults

        ## Signal to previous stage it has popped, such that the previous stage can put if it lies ahead in time
        intermediatesPopped[stageID-1].release()

        if(messageID == (cases.qsize()-1)):
            print("Last case out of the pipeline, signaled controller.")
            pipelineFinished.release()

def blakeleyPipelineController():
    while(True):
        requestNewCase.acquire()
        reportProgress()
        caseMtx.acquire()
        if cases.qsize() == 0:
            print("Finished, no more cases left. Generating report.")
            time.sleep(1)
            pipelineFinished.acquire()
            reportResults()
        caseMtx.release()
        grantNewCase.release()

def paralellBinartExp():

    ## Load all test cases that simulate the stream of M
    global cases
    cases = getCases("testCases.csv")

    eSlices = splitE(E, KEY_LENGTH, PIPELINE_STAGES)
    ## Start all threads and asynchromus communication (semaphores)
    threads = []
    threads.append(threading.Thread(target=blakeleyPipelineController))
    threads.append(threading.Thread(target=blakeleyPipelineStart, args=(0,)))
    for i in range(1,PIPELINE_STAGES+1):
        threads.append(threading.Thread(target=blakeleyPipelineStage, args=(eSlices[i-1],N,i)))
    threads.append(threading.Thread(target=blakeleyPipelineEnd, args=(PIPELINE_STAGES+1,)))

    for thread in threads:
        thread.start()

    for thread in threads:
        thread.join()

def main():
    paralellBinartExp()

if __name__ == "__main__":
    main()

