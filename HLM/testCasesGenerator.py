import csv
import random

def generate_test_cases(filename, num_testcases):
    # Open the file in write mode
    with open(filename, mode="w", newline="") as file:
        writer = csv.writer(file)
        
        # Write the header
        writer.writerow(["M", "ID"])
        
        # Write test cases
        for i in range(num_testcases):
            M = random.randint(100,200)  # Generate a random integer between 1 and 200
            writer.writerow([M, i])

# Define the number of test cases and the output file name
NUM_TESTCASES = 50
FILENAME = "testCases.csv"

# Generate the test cases
generate_test_cases(FILENAME, NUM_TESTCASES)

print(f"Generated {NUM_TESTCASES} test cases in '{FILENAME}'.")
