def splitE(number, key_length, pipeline_stages):
    binary_str = bin(number)[2:]
    
    total_length = key_length  # total length of the binary string
    padded_binary_str = binary_str.zfill(total_length)
    
    chunk_size = total_length // pipeline_stages
    
    chunks = [padded_binary_str[i:i + chunk_size] for i in range(0, total_length, chunk_size)]
    
    decimal_numbers = [int(chunk, 2) for chunk in chunks]
    
    return decimal_numbers[::-1]

# Example usage
number = 27343
KEY_LENGTH = 16  # Example key length
PIPELINE_STAGES = 4  # Example number of pipeline stages

result = convert_to_decimal_chunks(number, KEY_LENGTH, PIPELINE_STAGES)
print(bin(number),result)  # Output: List of decimal numbers from LSB to MSB
