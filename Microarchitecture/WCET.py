import math

F_CLK = 150 * 10**6

def CYC_BLAKELEY_MODULE(w):
    MAXCYCLES_ONE_A_BIT = 9
    MINCYCLES_ONE_A_BIT = 6
    return MINCYCLES_ONE_A_BIT*w

def CYC_RSA_STAGE_MODULE(w):
    START = 2
    SMCP = 1
    END = 1
    return w*CYC_BLAKELEY_MODULE(w)+(START+SMCP+END)

def findRsaMs(cycles):
    return (cycles/F_CLK)*10**3

print(findRsaMs(CYC_RSA_STAGE_MODULE(256)))