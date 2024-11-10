library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;
use STD.textio.all;
use ieee.std_logic_textio.all;

use work.tb_utils.all;

entity rsm_tester is
    generic(
        c_block_size : integer;
        log2_c_block_size : integer;
        
        num_pipeline_stages : integer;
        log2_es_size : integer 
    );
    
    port(
        rsm_tester_start : in std_logic;
        rsm_tester_finished : out std_logic;
        
        clk : in std_logic;
        rst_tester : in std_logic;
        rst_dut : out std_logic;
        
        --Control signals             
        ili : in std_logic;
        ipi : in std_logic;
        ipo : out std_logic := '0';
        ilo : out std_logic := '0';
        
        --Data signals
        dpo : out std_logic_vector (c_block_size-1 downto 0);
        dci : in std_logic_vector (c_block_size-1 downto 0);

        n : out std_logic_vector (c_block_size-1 downto 0);
        e : out std_logic_vector (c_block_size-1 downto 0)
    );        
end rsm_tester;

architecture rtl of rsm_tester is        
    type ai_state is (WAIT_FOR_START,GET_FROM_AXI,HOLD_FOR_PIPELINE,FINISHED_IN,PULSE_RST); --Finished are only here in tb
    type ao_state is (WAIT_FOR_PIPELINE,GIVE_TO_AXI,FINISHED_OUT); --Finished are only here in tb
    signal axi_in_state : ai_state := GET_FROM_AXI;
    signal axi_in_state_nxt : ai_state := GET_FROM_AXI;
    signal axi_out_state : ao_state := WAIT_FOR_PIPELINE;
    signal axi_out_state_nxt : ao_state := WAIT_FOR_PIPELINE;
        
    --For tb purposes only
    constant num_testcases : integer := 100;
    type c_array is array(num_testcases downto 1) of std_logic_vector(c_block_size-1 downto 0);
    signal correct_c : c_array;
    shared variable cases_in_count : integer := 1;
    shared variable cases_out_count : integer := 1;
    shared variable cases_out_count_prev : integer := 0;
    

    function count_ones(vec : std_logic_vector) return integer is
        variable count : integer := 0;
    begin
        for i in vec'RANGE loop
            if vec(i) = '1' then
                count := count + 1;
            end if;
        end loop;
        return count;
    end function;
    
begin    
    simulate_axi_regio : process is
        variable current_case_e, current_case_n: std_logic_vector(c_block_size-1 downto 0);
    
        file csv_file : text;
        variable current_line : line;
        
        variable comma : character;
    begin
        file_open(csv_file,"C:\Users\Andreas\Desktop\alpha_test\forsok5\TFE4141_Design_of_digital_systems\Utilities\key.csv",READ_MODE);
        readline(csv_file,current_line);
        read(current_line,current_case_e);
        read(current_line,comma);
        read(current_line,current_case_n);
        file_close(csv_file);
        
        e <= current_case_e;
        n <= current_case_n;
        wait;
    end process simulate_axi_regio;
    
    simulate_axi_in : process(ipi,axi_in_state,rsm_tester_start) is
        variable current_case_m, current_case_correct_c: std_logic_vector(c_block_size-1 downto 0);
        variable cases_in_count_prev : integer := 0;
        variable file_opened : boolean := false;
        file csv_file : text;
        variable current_line : line;
        variable comma : character;
        
        variable rst_at_case : std_logic_vector(num_testcases downto 1) := (others => '0');

    begin
        case axi_in_state is
            when WAIT_FOR_START =>
                if(rsm_tester_start = '1') then
                    
                    axi_in_state_nxt <= GET_FROM_AXI;
                else
                    axi_in_state_nxt <= WAIT_FOR_START;
                end if;
            when GET_FROM_AXI =>
                ilo <= '0';
                rst_dut <= '0';
                
                if not file_opened then
                    file_open(csv_file,"C:\Users\Andreas\Desktop\alpha_test\forsok5\TFE4141_Design_of_digital_systems\Utilities\messages.csv",READ_MODE);
                    file_opened := true;
                end if;
                
                if cases_in_count /= cases_in_count_prev then
                    readline(csv_file,current_line);--Have to reset current_line in order to read from the top again!!!!!!!!!!!!!!! TODO!
                    read(current_line,current_case_m);
                    read(current_line,comma);
                    read(current_line,current_case_correct_c);
                    cases_in_count_prev := cases_in_count;
                end if;
                
                if (vectors_equal(current_case_m,(others => '0')) 
                    and vectors_equal(current_case_correct_c,(others => '0'))) then
                    axi_in_state_nxt <= FINISHED_IN;
                end if;
                
                dpo <= current_case_m;
                correct_c(cases_in_count) <= current_case_correct_c;
                
                if ipi = '0' then
                    axi_in_state_nxt <= HOLD_FOR_PIPELINE;
                end if;
            
            when HOLD_FOR_PIPELINE =>
                ilo <= '1';
                if(ipi = '1') then
                    cases_in_count := cases_in_count + 1;
                    axi_in_state_nxt <= GET_FROM_AXI;
                end if;
                
            when FINISHED_IN =>
                file_close(csv_file);
                report "All messages sent in"
                severity note;
                file_opened := false;
            when others =>
        end case;
    end process simulate_axi_in;
    
    simulate_axi_out : process(ili,axi_out_state) is
        variable pass_count : integer := 0;
        variable fail_count : integer := 0;
        
    begin
        rsm_tester_finished <= '0';
        case(axi_out_state) is
            when WAIT_FOR_PIPELINE =>
                ipo <= '0';
                if ili = '1' then
                    axi_out_state_nxt <= GIVE_TO_AXI;
                else
                    axi_out_state_nxt <= WAIT_FOR_PIPELINE;
                end if;
            
            when GIVE_TO_AXI =>
                --DCI ready and can be sent to axi for as ling as ipo = '0'
                if cases_out_count /= cases_out_count_prev then
                    if vectors_equal(dci,correct_c(cases_out_count)) then
                        pass_count := pass_count + 1;
                        report "OK: Case " & integer'image(cases_out_count) & " passed!"
                        severity note;
                    else
                        fail_count := fail_count + 1;
                        report "FAIL: Case " & integer'image(cases_out_count) & " failed"
                        severity note;
                    end if;
                    cases_out_count_prev := cases_out_count;
                end if;
          
                ipo <= '1';
                if ili = '0' then
                    cases_out_count := cases_out_count + 1;
                    axi_out_state_nxt <= WAIT_FOR_PIPELINE;                
                end if;
                
                if cases_out_count = cases_in_count and axi_in_state = FINISHED_IN then
                    axi_out_state_nxt <= FINISHED_OUT;
                end if;     
            
            when FINISHED_OUT =>
                report " " severity note;  -- Add a blank line before
                report "All messages received out" severity note;  -- Add a blank line before
                report " " severity note;  -- Add a blank line before
                report "Test summary: " & integer'image(pass_count) & " cases passed, " & integer'image(fail_count) & " cases failed." severity note; 
                report " " severity note;  -- Add a blank line after
                rsm_tester_finished <= '1';
                
            when others =>
        end case;
    end process simulate_axi_out;
    
    fsm_seq : process(clk) is
    begin
        if (clk'event and clk='1') then
            axi_in_state <= axi_in_state_nxt;
            axi_out_state <= axi_out_state_nxt;
        end if;
        if(rst_tester = '1') then
            axi_in_state <= WAIT_FOR_START;
            axi_out_state <= WAIT_FOR_PIPELINE;

            cases_in_count := 1;
            cases_out_count := 1;
            cases_out_count_prev := 0; 
        end if;
    end process fsm_seq;
end rtl;