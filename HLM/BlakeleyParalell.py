import threading
import time
import csv
import queue
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches

NUM_PIPELINE_STAGES = 16 #Set dependent of PPA in final implementation
KEY_LENGTH = 256 #Should be 256 in final implemntation

E = 8954    ## Encryption key
N = 25553    ## Modulus


messages = {}

pipelineLog = []
pipelineLogMtx = threading.Lock()

caseMtx = threading.Lock()

'''
pipelinentermediates holds:
    [0] - Intermediate C after stage ID-1
    [1] - Intermediate P after stage ID-1
    [2] - Keeps the message ID
'''
pipelineIntermediates = [[queue.Queue() for _ in range(3)] for _ in range(NUM_PIPELINE_STAGES+2)]
intermediatesLoaded = [threading.Semaphore(0) for _ in range(NUM_PIPELINE_STAGES+2)]
intermediatesPopped = [threading.Semaphore(1) for _ in range(NUM_PIPELINE_STAGES+2)]
intermediateMtx = [threading.Lock() for _ in range(NUM_PIPELINE_STAGES+2)]

requestNewCase = threading.Semaphore(0)
grantNewCase = threading.Semaphore(0)

pipelineFinished = threading.Semaphore(0)

## Note that all semaphore signals correspond to interstage/intercontroller commnication in HW


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
    print("\n--- Report results in hex ---\n")
    mismatch_found = False
    
    # Print the header
    print(f"{'Message ID':<15} {'Pipeline Result':<20} {'Expected Result':<20} {'Mismatch':<10}")
    print("-" * 65)  # Divider line

    for messageID, data in messages.items():
        M = data[0]  # Original message
        pipelineResult = data[1]  # Result from the pipeline
        
        expectedResult = pow(M, E, N)
        mismatch = "Yes" if pipelineResult != expectedResult else "No"
        print(f"{messageID:<15} {hex(pipelineResult):<20} {hex(expectedResult):<20} {mismatch:<10}")
        
        if pipelineResult != expectedResult:
            print(f"Mismatch found for message ID {messageID}!")
            mismatch_found = True
    
    if not mismatch_found:
        print("\nAll results are correct!")
    else:
        print("\nThere were mismatches in the results.")


def generateGanttChart():
    # Organize data from pipelineLog
    stages_by_message = {}
    for stageID, messageID, currentC, currentP, timestamp in pipelineLog:
        if messageID not in stages_by_message:
            stages_by_message[messageID] = []
        stages_by_message[messageID].append((stageID, timestamp))
    
    # Normalize timestamps
    start_time = min(entry[4] for entry in pipelineLog)
    for messageID in stages_by_message:
        stages_by_message[messageID] = [(stage, t - start_time) for stage, t in stages_by_message[messageID]]
    
    # Plot the Gantt chart
    fig, ax = plt.subplots(figsize=(10, len(stages_by_message) * 0.5))
    colors = plt.cm.tab20.colors  # Color palette

    for i, (messageID, stages) in enumerate(sorted(stages_by_message.items())):
        for stage, timestamp in stages:
            ax.barh(
                y=i, 
                width=0.9,  # Block size
                left=timestamp, 
                height=0.4, 
                color=colors[stage % len(colors)], 
                edgecolor="black",
                alpha=0.5,  # Partially transparent
                label=f"Stage {stage}" if stage == 0 else ""
            )

    # Add grid lines
    ax.grid(axis='x', linestyle='--', alpha=0.6)

    # Labeling
    ax.set_yticks(range(len(stages_by_message)))
    ax.set_yticklabels(sorted(stages_by_message.keys()))
    ax.set_xlabel("Time (normalized)")
    ax.set_ylabel("Message ID")
    ax.set_title("Pipeline Progression")

    # Ensure unique legend entries
    handles, labels = ax.get_legend_handles_labels()
    unique_labels = dict(zip(labels, handles))
    ax.legend(unique_labels.values(), unique_labels.keys(), loc="upper left", bbox_to_anchor=(1.05, 1), title="Stages")
    
    plt.tight_layout()
    plt.show()



def getQueueElement(q):
    if not q.empty():
        return q.queue[0]  # Access the first element
    else:
        return ""  # Return 'Empty' if the queue is empty


def blakeley_module(a, b, n):
    R = 0
    a_bin = bin(a)[2:][::-1]
    for i in range(len(a_bin)):
        bit = int(a_bin[(len(a_bin)-1)-i])  
        shift = R<<1                    
        mul = bit * b                   
        R = mul + shift                 
        if R>=n:
            R = R - n
        if R>=n:
            R = R - n
    return R


def axi_in(stageID):
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
        intermediateMtx[stageID].release()

        ## Signal to next stage that data is ready
        intermediatesLoaded[stageID].release()

def rsa_stage_module(eSlice,n,stageID):
    while(True):
        ## Wait for asynch signal from previous stage that data is ready
        intermediatesLoaded[stageID-1].acquire()
        
        ## Get values from pipelineIntermediates
        intermediateMtx[stageID-1].acquire()
        currentC = pipelineIntermediates[stageID-1][0].get(0)
        currentP = pipelineIntermediates[stageID-1][1].get(0)
        currentID = pipelineIntermediates[stageID-1][2].get()
        intermediateMtx[stageID-1].release()

        ## Signal to previous stage it has popped, such that the previous stage can replace its values
        intermediatesPopped[stageID-1].release()

        pipelineLogMtx.acquire()
        pipelineLog.append([stageID, currentID, currentC, currentP, time.time()])
        pipelineLogMtx.release()

        ## Accumulate new values
        if KEY_LENGTH % NUM_PIPELINE_STAGES != 0:
            print(f"Error: KEY_LENGTH / NUM_PIPELINE_STAGES is not an integer")
            raise ValueError

        if len(bin(eSlice)[2:]) > (KEY_LENGTH/NUM_PIPELINE_STAGES):
            print(f"Error: eSlice is {eSlice} and not KEY_LENGTH/NUM_PIPELINE_STAGES")
            raise ValueError
        
        mask = 0b1
        for i in range(0, int(KEY_LENGTH/NUM_PIPELINE_STAGES)):
            if eSlice & mask:
                currentC = blakeley_module(currentC, currentP, n)
            currentP = blakeley_module(currentP, currentP, n)
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

def axi_out(stageID):
    while(True):
        ## Wait for asynch signal from previous stage that data is ready
        intermediatesLoaded[stageID-1].acquire()

        ## Push values to pipelineIntermediates
        intermediateMtx[stageID-1].acquire()
        endC = pipelineIntermediates[stageID-1][0].get(0)
        endP = pipelineIntermediates[stageID-1][1].get(0)
        messageID = pipelineIntermediates[stageID-1][2].get(0)
        intermediateMtx[stageID-1].release()

        messages[messageID].append(endC)    ## For final reults

        ## Signal to previous stage it has popped, such that the previous stage can put if it lies ahead in time
        intermediatesPopped[stageID-1].release()

        if(messageID == (numCases-1)):
            print("Last case out of the pipeline, signaled controller.")
            pipelineFinished.release()

def rsa_core_control():
    while(True):
        requestNewCase.acquire()
        caseMtx.acquire()
        if cases.qsize() == 0:
            print("Finished, no more cases left. Awaiting signal from last pipeline stage.\n")
            pipelineFinished.acquire()
            print("Generating Gantt Chart...")
            generateGanttChart()
            print(f"Results of operation: C = M {hex(E)} mod {hex(N)} (E and N in hex)\n")
            reportResults()
            ## Timing test does not make sence in software, as the gains from the pipelining is only existent in HW
        caseMtx.release()
        grantNewCase.release()

def rsa_core():

    ## Load all test cases that simulate the stream of M
    global cases
    cases = getCases("testCases.csv")
    global numCases
    numCases = cases.qsize()

    eSlices = splitE(E, KEY_LENGTH, NUM_PIPELINE_STAGES)
    ## Start all threads and asynchromus communication (semaphores)
    threads = []
    threads.append(threading.Thread(target=rsa_core_control))
    threads.append(threading.Thread(target=axi_in, args=(0,)))
    for i in range(1,NUM_PIPELINE_STAGES+1):
        threads.append(threading.Thread(target=rsa_stage_module, args=(eSlices[i-1],N,i)))
    threads.append(threading.Thread(target=axi_out, args=(NUM_PIPELINE_STAGES+1,)))

    for thread in threads:
        thread.start()

    for thread in threads:
        thread.join()

def main():
    rsa_core()

if __name__ == "__main__":
    main()

