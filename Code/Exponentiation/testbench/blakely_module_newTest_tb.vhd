library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;
use STD.textio.all;
use ieee.std_logic_textio.all;

library work;
use work.blakeley_utils.all;

entity blakely_module_newtest_tb is
    generic (
        c_block_size : integer := 256;
        num_status_bits : integer := 32
    );
    port (
        trigger : in  std_logic;  -- FSM start signal
        finished: out std_logic   -- FSM completion signal
    );
end blakely_module_newtest_tb;

architecture rtl of blakely_module_newtest_tb is
    signal A : std_logic_vector(c_block_size-1 downto 0);
    signal B : std_logic_vector(c_block_size-1 downto 0);
    signal N : std_logic_vector(c_block_size+1 downto 0);
    signal ABVAL : std_logic; 
    signal R : std_logic_vector(c_block_size-1 downto 0);
    signal RVAL : std_logic;
    signal clk : std_logic := '0'; -- Internal clock
    signal rst : std_logic := '0'; -- Internal reset

    type state_t is (IDLE, TESTING);
    signal state, next_state : state_t := IDLE;
    
    signal blakeley_status : std_logic_vector(num_status_bits-1 downto 0);
    
    constant clk_period : time := 2 ns;


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
    DUT: entity work.blakeley_module 
        generic map(
            c_block_size => c_block_size
            --TODO: Check if I need this
            -- log2_c_block_size => log2_c_block_size
            -- num_upper_status_bits => num_status_bits
            -- num_lower_status_bits => num_status_bits
        )
        port map(
            clk => clk,
            rst => rst,
            
            A => A,
            B => B,
            N => N,
            ABVAL => ABVAL,
            R => R,
            RVAL => RVAL
            
            --blakeley_status => blakeley_status
        );
    
    clk_gen: process
    begin
        while true loop
            clk <= '0';
            wait for clk_period / 2;
            clk <= '1';
            wait for clk_period / 2;
        end loop;
   end process clk_gen;

    -- FSM Process for state transitions
    fsm_process: process(clk, rst)
    begin
        if rst = '1' then
            state <= IDLE;
        elsif rising_edge(clk) then
            state <= next_state;
        end if;
    end process fsm_process;

    -- Process to determine next state
    next_state_logic: process(state, trigger)
    begin
        case state is
            when IDLE =>
                if trigger = '1' then
                    next_state <= TESTING;
                else
                    next_state <= IDLE;
                end if;
            
            when TESTING =>
                if trigger = '0' then
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
    begin
        -- Apply reset
        rst <= '1';
        wait for 10 * clk_period;
        rst <= '0';
        
        -- Wait in IDLE state until trigger is set
        wait until state = TESTING;
        
        -- Open CSV file for reading
        file_open(csv_file, "C:\Users\Andreas\Desktop\alphaterst2\TFE4141_Design_of_digital_systems\bmtc.csv", READ_MODE);
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
            A <= current_case_A;
            B <= current_case_B;
            N <= "00" & current_case_N; -- Add padding if needed
            expected_R := current_case_expected_R;

            -- Report assigned values for verification
            report "Assigned A: " & to_string(A) severity note;
            report "Assigned B: " & to_string(B) severity note;
            report "Assigned N: " & to_string(N) severity note;
            report "Assigned expected_R: " & to_string(expected_R) severity note;
            
            -- Start the operation
            wait for clk_period;
            ABVAL <= '1';
            wait until RVAL = '1';
            wait for clk_period;
            if(R = expected_R) then
                pass_count := pass_count + 1;
                report("Test case " & integer'image(test_case_index) & " passed") severity note;
            else
                fail_count := fail_count + 1;
                report("Test case " & integer'image(test_case_index) & " failed") severity error;
            end if;
            test_case_index := test_case_index + 1;
            wait for clk_period;
            ABVAL <= '0';
        end loop;
        file_close(csv_file);
        report "Test completed. " & integer'image(pass_count) & " cases passed, " & integer'image(fail_count) & " cases failed." severity note;
        finished <= '1';
    wait;
    end process stimulus;
end architecture rtl;