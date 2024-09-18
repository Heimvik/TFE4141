def blakelyMulMod(a, b, n):
    R = 0
    a_bin = bin(a)[2:][::-1]
    for i in range(len(a_bin)):
        bit = int(a_bin[(len(a_bin)-1)-i])  
        R = 2 * R + bit * b 
        if R>n:
            R = R - n
        if R>n:
            R = R - n
    return R

def binaryExp(M, e, n):
    mask = 0b1
    C = 1
    P = M
    for i in range(0, len(bin(e)[2:])):
        if e & mask: 
            C = blakelyMulMod(C, P, n) 
        P = blakelyMulMod(P, P, n) 
        mask = mask << 1 
    return C

def main():
    M = 22
    e = 54
    n = 123
    print("Result:",binaryExp(M,e,n))  
    print("Expected:",(pow(M,e,n)))

if __name__ == "__main__":
    main()
