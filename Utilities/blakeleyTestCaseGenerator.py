import random
import csv

#Simple test case generator for the Blakeley module

def generate_random_number(min_value, max_value):
    # Generate a random number between min_value and max_value
    return random.randint(min_value, max_value)

def to_binary_string(value, length=256):
    # Convert value to binary string with fixed length
    return format(value, '0{}b'.format(length))

def generate_case(max_value):
    # Genereate random A, B, N values
    while True:
        A = generate_random_number(1, max_value)
        B = generate_random_number(1, max_value)
        N = generate_random_number(max(A, B) + 1, max_value)  
        
        # Compute expected R as (A * B) mod N
        expected_R = (A * B) % N
        # Convert to bin 
        binary_A = to_binary_string(A)
        binary_B = to_binary_string(B)
        binary_N = to_binary_string(N)
        binary_expected_R = to_binary_string(expected_R)

        return binary_A, binary_B, binary_N, binary_expected_R

def generate_csv(file_name, num_cases, max_value):
    #Generate a CSV file with num_cases of random A, B, N and expected_R cases.
    with open(file_name, mode='w', newline='') as file:
        writer = csv.writer(file)
        
        for i in range(num_cases):
            binary_A, binary_B, binary_N, binary_expected_R = generate_case(max_value)
            writer.writerow([binary_A, binary_B, binary_N, binary_expected_R, 'EOL'])
            print(f"Generated case {i + 1} - A: {hex(int(binary_A, 2))}, B: {hex(int(binary_B, 2))}, N: {hex(int(binary_N, 2))}, expected_R: {hex(int(binary_expected_R, 2))}")
        
        # Write the end-of-file indicator
        writer.writerow(['0' * 256, '0' * 256, '0' * 256, '0' * 256, 'EOL'])

if __name__ == "__main__":
    NUM_CASES = 100  # Set the desired number of test cases
    MAX_VAL = (2 ** 256) - 1  # Set maximum value for A, B, N
    csv_file_name = "blakeleymoduletestcases.csv"

    generate_csv(csv_file_name, NUM_CASES, MAX_VAL)
