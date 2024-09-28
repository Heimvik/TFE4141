
# Initialize t
t = 0

A = [1,0,0,1]
B = 10

k = 3

for i in range(len(A)-1,-1,-1):
    t = t + A[i] * B
    print(f"---After addition in iteration {i}: t = {t} (binary: {bin(t)})")    
    t = 2*t
    print(f"After multiplication in iteration {i}: t = {t} (binary: {bin(t)})")