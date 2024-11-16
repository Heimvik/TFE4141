import random
import csv

def generate_random_number(min_value,max_value):
    """Generate a random number between 1 and max_value."""
    return random.randint(min_value, max_value)

def to_binary_string(value, length=256):
    """Convert an integer value to a binary string of specified length."""
    return format(value, '0{}b'.format(length))

def generate_key(min_value,max_value):
    n = generate_random_number(min_value,max_value)
    e = generate_random_number(min_value,n-1)
    binary_e = to_binary_string(e)
    binary_n = to_binary_string(n)
    return binary_e, binary_n

def generate_message(min_value,max_value):
    M = generate_random_number(min_value,max_value)
    binary_M = to_binary_string(M)
    return binary_M

def generate_case(max_value,n):
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
'''
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
'''

def generate_binary_string(max_value,min_value):
    """Generate a random binary string with a maximum decimal value of max_value."""
    value = random.randint(min_value, max_value)
    return bin(value)[2:].zfill(256)

def generate_csv_pairs(file_name, num_cases, max_value_upper, max_value_lower):
    """Generate a CSV file with num_cases of random M, e, n, C cases."""
    with open(file_name, mode='w', newline='') as file:
        writer = csv.writer(file)
        
        for i in range(1,num_cases):
            while True:
                min_M = 2**253
                min_e = 2**253
                if i <=12:
                    max_M = max_value_upper - 1
                    min_M = max_value_lower + 1
                    max_e = max_value_upper - 1
                    min_e = max_value_lower + 1
                    max_n = max_value_upper
                elif i>=12 and i<24:
                    max_M = max_value_lower
                    max_e = max_value_lower
                    max_n = max_value_upper
                elif i>=24 and i<36:
                    max_M = max_value_upper - 1
                    min_M = max_value_lower + 1
                    max_e = max_value_lower
                    max_n = max_value_upper
                elif i>=36 and i<48:
                    max_M = max_value_lower
                    max_e = max_value_upper - 1
                    min_e = max_value_lower + 1
                    max_n = max_value_upper
                else:
                    max_M = max_value_lower - 1
                    max_e = max_value_lower - 1
                    max_n = max_value_lower

                binary_M = generate_binary_string(max_M,min_M)
                binary_e = generate_binary_string(max_e,min_e)
                binary_n = generate_binary_string(max_n,2**253)
                if(int(binary_M, 2) < int(binary_n, 2) and int(binary_e, 2) < int(binary_n, 2)):
                    break
            binary_C = to_binary_string(pow(int(binary_M, 2), int(binary_e, 2), int(binary_n, 2)))
            print(f"Lengths: {len(binary_M)}, {len(binary_e)}, {len(binary_n)}, {len(binary_C)}")
            writer.writerow([binary_M, binary_e, binary_n, binary_C, 'EOL'])
            print(f"Generated case {i} - M: {hex(int(binary_M, 2))}, e: {hex(int(binary_e, 2))}, n: {hex(int(binary_n, 2))}, C: {hex(int(binary_C, 2))}")

        # Write the end of file indicator
        writer.writerow(['0' * 256, '0' * 256, '0' * 256, '0' * 256, 'EOL'])  # Ensure the end row has the same binary length

def generate_csv(m_file, k_file, num_cases,min_value, max_value):
    """Generate a CSV file with num_cases of random M, e, n, C cases."""
    binary_e, binary_n = 0,0
    
    with open(k_file, mode='w', newline='') as key_file:
        writerK = csv.writer(key_file)
        binary_e, binary_n = generate_key(min_value,max_value)
        writerK.writerow([binary_e, binary_n, 'EOL'])
        print(f"\nGenerated key - e: {hex(int(binary_e,2))} (length: {len(binary_e)}), n: {hex(int(binary_n,2))} (length: {len(binary_e)})\n")

    with open(m_file, mode='w', newline='') as message_file:
        writerM = csv.writer(message_file)
        for i in range(0,2):
            for _ in range(num_cases):
                binary_M = generate_message(min_value,int(binary_n, 2)-1)
                binary_C = to_binary_string(pow(int(binary_M, 2), int(binary_e, 2), int(binary_n, 2)))
                writerM.writerow([binary_M, binary_C, 'EOL'])
                print(f"Generated message - M: {hex(int(binary_M,2))}, (length: {len(binary_M)}), C: {hex(int(binary_C,2))}, (length: {len(binary_C)})")
            
            # Write the end of file indicator
            writerM.writerow(['0' * 256, '0' * 256, '0' * 256, '0' * 256, 'EOL'])  # Ensure the end row has the same binary length

if __name__ == "__main__":
    NUM_CASES = 19  # Set your desired number of cases
    MAX_VAL_UPPER = int((2**256)-1)  # Set maximum value for n
    MIN_VAL = int(2**255)
    msg_file_name = "messages.csv"
    key_file_name = "key.csv"
    generate_csv(msg_file_name, key_file_name, NUM_CASES, MIN_VAL, MAX_VAL_UPPER)
    #generate_csv_pairs(file_name, NUM_CASES, MAX_VAL_UPPER, MAX_VAL_LOWER)