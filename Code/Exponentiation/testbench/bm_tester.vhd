library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;
use STD.textio.all;
use ieee.std_logic_textio.all;

library work;
use work.blakeley_utils.all;

entity bm_tester is
    generic (
        c_block_size : integer := 256
    );
    port (
        bm_tester_start : in  std_logic;
        bm_tester_finished: out std_logic;
        
        clk : in std_logic; 
        rst_tester : in std_logic;
        rst_dut : out std_logic;
        
        a : out std_logic_vector(c_block_size-1 downto 0);
        b : out std_logic_vector(c_block_size-1 downto 0);
        abval : out std_logic;
        
        r : in std_logic_vector(c_block_size-1 downto 0);
        rval : in std_logic;
        
        nx1 : out std_logic_vector (c_block_size+1 downto 0);
        nx2 : out std_logic_vector (c_block_size+1 downto 0)    
    );
end bm_tester;

architecture rtl of bm_tester is
    type state_t is (IDLE, TESTING);
    signal state, next_state : state_t := IDLE;
    
    --File handling
    file csv_file : text;
    constant num_testcases : integer := 5;
     -- Conversion function for std_logic_vector to string
    function to_string(vector: std_logic_vector) return string is
        variable result: string(1 to vector'length);
    begin
        for i in vector'range loop
            if vector(i) = '1' then
                result(i - vector'low + 1) := '1';
            else
                result(i - vector'low + 1) := '0';
            end if;
        end loop;
        return result;
    end function;
begin    
    -- FSM Process for state transitions
    fsm_process: process(clk, rst_tester)
    begin
        if rst_tester = '1' then
            state <= IDLE;
        elsif rising_edge(clk) then
            state <= next_state;
        end if;
    end process fsm_process;

    -- Process to determine next state
    next_state_logic: process(state, bm_tester_start)
    begin
        case state is
            when IDLE =>
                if bm_tester_start = '1' then
                    next_state <= TESTING;
                else
                    next_state <= IDLE;
                end if;
            
            when TESTING =>
                if bm_tester_start = '0' then
                    next_state <= IDLE;
                else
                    next_state <= TESTING;
                end if;
        end case;
    end process next_state_logic;

    stimulus: process
        variable current_line : line;
        variable current_case_A, current_case_B, current_case_N, current_case_expected_R : std_logic_vector(c_block_size-1 downto 0);
        variable pass_count, fail_count : integer := 0;
        variable test_case_index : integer := 0;
        variable comma : character := ',';
        variable expected_R : std_logic_vector(c_block_size-1 downto 0);
        
        variable nx1_internal : std_logic_vector(c_block_size+1 downto 0);
    begin
        -- Apply reset
        rst_dut <= '1';
        wait for 10 ns;
        rst_dut <= '0';
        
        -- Wait in IDLE state until trigger is set
        --wait until state = TESTING;
        
        -- Open CSV file for reading
        
        file_open(csv_file, "C:\Users\cmhei\OneDrive\Dokumenter\Semester_7\TFE4141_DDS1\Project\Utilities\tb_utilities\bm_testcase_gen\bm_cases.csv", READ_MODE);
        if not endfile(csv_file) then
            report "File opened successfully." severity note;
        else
            report "Failed to open file or file is empty." severity error;
        end if;

        while not endfile(csv_file) loop
            readline(csv_file, current_line);
             -- Read sections from the line and skip commas
            read(current_line, current_case_A);
            read(current_line, comma); -- Read the comma separator
            read(current_line, current_case_B);
            read(current_line, comma); -- Read the next comma separator
            read(current_line, current_case_N);
            read(current_line, comma); -- Read the next comma separator
            read(current_line, current_case_expected_R);
            read(current_line, comma); -- Read the next comma separator
            -- Assign to testbench signals
            a <= current_case_A;
            b <= current_case_B;
            nx1_internal := "00" & current_case_n;
            nx1 <= nx1_internal;
            nx2 <= std_logic_vector(unsigned(nx1_internal) sll 1);
            expected_R := current_case_expected_R;

            -- Report assigned values for verification
            --report "Assigned A: " & to_string(A) severity note;
            --report "Assigned B: " & to_string(B) severity note;
            --report "Assigned N: " & to_string(N) severity note;
            --report "Assigned expected_R: " & to_string(expected_R) severity note;
            
            -- Start the operation
            abval <= '1';
            wait until RVAL = '1';
            if(r = expected_R) then
                pass_count := pass_count + 1;
                report("Test case " & integer'image(test_case_index) & " passed") severity note;
            else
                fail_count := fail_count + 1;
                report("Test case " & integer'image(test_case_index) & " failed") severity error;
            end if;
            test_case_index := test_case_index + 1;
            ABVAL <= '0';
        end loop;
        file_close(csv_file);
        report "Test completed. " & integer'image(pass_count) & " cases passed, " & integer'image(fail_count) & " cases failed." severity note;
        bm_tester_finished <= '1';
    wait;
    end process stimulus;
end architecture rtl;