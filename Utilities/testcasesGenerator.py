import random
import csv

def generate_random_number(max_value):
    """Generate a random number between 1 and max_value."""
    return random.randint(1, max_value)

def to_binary_string(value, length=256):
    """Convert an integer value to a binary string of specified length."""
    return format(value, '0{}b'.format(length))

def generate_case(max_value):
    """Generate M, e, n values, where M < n, e < n, and return M, e, n, C as binary strings."""
    while True:
        n = generate_random_number(max_value)  # Generate n such that n is the modulus
        
        # Ensure n is greater than 1 to allow valid values for M and e
        if n <= 1:
            continue
            
        M = generate_random_number(n - 1)  # M must be less than n
        e = generate_random_number(n - 1)  # e must also be less than n
        
        # Compute C = M^e mod n using Python's built-in modular exponentiation
        C = pow(M, e, n)
        
        # Convert to binary strings of length 256
        binary_M = to_binary_string(M)
        binary_e = to_binary_string(e)
        binary_n = to_binary_string(n)
        binary_C = to_binary_string(C)

        return binary_M, binary_e, binary_n, binary_C

def generate_csv(file_name, num_cases, max_value):
    """Generate a CSV file with num_cases of random M, e, n, C cases."""
    with open(file_name, mode='w', newline='') as file:
        writer = csv.writer(file)
        
        for _ in range(num_cases):
            binary_M, binary_e, binary_n, binary_C = generate_case(max_value)
            writer.writerow([binary_M, binary_e, binary_n, binary_C, 'EOL'])
            print(f"Generated case - M: {hex(int(binary_M,2))}, e: {hex(int(binary_e,2))}, n: {hex(int(binary_n,2))}, C: {hex(int(binary_C,2))}")
        
        # Write the end of file indicator
        writer.writerow(['0' * 256, '0' * 256, '0' * 256, '0' * 256, 'EOL'])  # Ensure the end row has the same binary length

if __name__ == "__main__":
    NUM_CASES = 100  # Set your desired number of cases
    MAX_VAL = 1000  # Set maximum value for n
    file_name = "testcases.csv"
    generate_csv(file_name, NUM_CASES, MAX_VAL)
