import math

F_CLK = 200 * 1e6

def CYC_BLAKELEY_MODULE(w):
    MAXCYCLES_ONE_A_BIT = 1
    return MAXCYCLES_ONE_A_BIT*w

def CYC_RSA_STAGE_MODULE(w):
    START = 2
    SMCP = 1
    END = 1
    return w*CYC_BLAKELEY_MODULE(w)+(START+SMCP+END)

def CYC_RSA_CORE_PIPELINED(w,stages):
    return CYC_RSA_STAGE_MODULE(w)/stages

def findTestEstimate():
    return f"{round(5000*(CYC_RSA_CORE_PIPELINED(256,4)/F_CLK)*1e3,2)} ms"

print(findTestEstimate())