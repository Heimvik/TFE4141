library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;
use STD.textio.all;
use ieee.std_logic_textio.all;

use work.tb_utils.all;

entity rsa_pipeline_tb is
    generic(
        c_block_size : integer := 256;
        log2_c_block_size : integer := 8;
        
        num_pipeline_stages : integer := 16;
        log2_es_size : integer := 4;   --Has to be log2(c_block_size/num_pipeline_stages)
        
        num_status_bits : integer := 32;
        CLK_PERIOD : time := 1 ns        
    );
end rsa_pipeline_tb;

architecture rtl of rsa_pipeline_tb is    
    signal clk : std_logic;
    signal rst : std_logic;
    
    --Control signals             
    signal ili : std_logic;
    signal ipi : std_logic;
    signal ipo : std_logic := '0';
    signal ilo : std_logic := '0';
    
    --Data signals
    signal dpo : std_logic_vector (c_block_size-1 downto 0);
    signal dco : std_logic_vector (c_block_size-1 downto 0);
    signal dpi : std_logic_vector (c_block_size-1 downto 0);
    signal dci : std_logic_vector (c_block_size-1 downto 0);
    
    --Status registers
    signal rsm_status : std_logic_vector(num_status_bits-1 downto 0);
    
    --Init values
    signal n : std_logic_vector (c_block_size-1 downto 0);
    signal e : std_logic_vector (c_block_size-1 downto 0);
    
    type ai_state is (GET_FROM_AXI,HOLD_FOR_PIPELINE,FINISHED_IN,PULSE_RST); --Finished are only here in tb
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
    
    shared variable rst_at_case : std_logic_vector(num_testcases downto 1) := (others => '0');

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
    clk_gen : process is
    begin
        while true loop
            clk <= '1';
            wait for CLK_PERIOD/2; 
            clk <= '0';
            wait for CLK_PERIOD/2;
        end loop;
    end process clk_gen;

    
    DUT : entity work.rsa_core_pipeline
    generic map(
        c_block_size => c_block_size,
        log2_c_block_size => log2_c_block_size,
        num_pipeline_stages => num_pipeline_stages,
        log2_es_size => log2_es_size,
        num_status_bits => num_status_bits
    )
    port map(
        CLK => clk,
        RST_N => not rst,
        
        --Input control signals to the blakeley stage module are outputs from the tb
        ILI => ilo,
        IPI => ipo,
        
        --Output control signals from the blakeley stage module are inputs to the tb
        IPO => ipi,
        ILO => ili,
        
        N => n,
        E => e,
        
        DPI => dpo,
        DCI => dco,
        DPO => dpi,
        DCO => dci,
        
        rsm_status => rsm_status
    );
    
    axi_regio : process is
        variable current_case_e, current_case_n: std_logic_vector(c_block_size-1 downto 0);
    
        file csv_file : text;
        variable current_line : line;
        
        variable comma : character;
    begin
        file_open(csv_file,"C:\Users\cmhei\OneDrive\Dokumenter\Semester_7\TFE4141_DDS1\Project\Utilities\key.csv",READ_MODE);
        readline(csv_file,current_line);
        read(current_line,current_case_e);
        read(current_line,comma);
        read(current_line,current_case_n);
        file_close(csv_file);
        
        e <= current_case_e;
        n <= current_case_n;
        wait;
    end process axi_regio;
    
    axi_in : process(ipi,axi_in_state) is
        variable current_case_m, current_case_correct_c: std_logic_vector(c_block_size-1 downto 0);
        variable cases_in_count_prev : integer := 0;
        variable file_opened : boolean := false;
        file csv_file : text;
        variable current_line : line;
        variable comma : character;
    begin
        case axi_in_state is
            when GET_FROM_AXI =>
                ilo <= '0';
                rst <= '0';
                
                if not file_opened then
                    file_open(csv_file,"C:\Users\cmhei\OneDrive\Dokumenter\Semester_7\TFE4141_DDS1\Project\Utilities\messages.csv",READ_MODE);
                    file_opened := true;
                end if;
                if cases_in_count /= cases_in_count_prev then
                    readline(csv_file,current_line);
                    read(current_line,current_case_m);
                    read(current_line,comma);
                    read(current_line,current_case_correct_c);
                    cases_in_count_prev := cases_in_count;
                end if;
                
                if (vectors_equal(current_case_m,(others => '0')) 
                    and vectors_equal(current_case_correct_c,(others => '0'))) then
                    axi_in_state_nxt <= FINISHED_IN;
                end if;
                
                dco <= std_logic_vector(to_unsigned(1, c_block_size));
                dpo <= current_case_m;
                correct_c(cases_in_count) <= current_case_correct_c;
                
                if ipi = '0' then
                    axi_in_state_nxt <= HOLD_FOR_PIPELINE;
                end if;
            
            when HOLD_FOR_PIPELINE =>
            
                ilo <= '1';
                if(cases_in_count = 25 and rst_at_case(cases_in_count) = '0') then
                    axi_in_state_nxt <= PULSE_RST;
                end if;
                if(ipi = '1') then
                    cases_in_count := cases_in_count + 1;
                    axi_in_state_nxt <= GET_FROM_AXI;
                end if;
            when FINISHED_IN =>
                file_close(csv_file);
                report "AXI_IN finished!"
                severity note;
                
            when PULSE_RST =>
                rst <= '1';
                --The rst causes a flush of the pipeline, effectively discarding all that lies in it
                cases_out_count := cases_out_count + num_pipeline_stages;
                cases_out_count_prev := cases_out_count_prev + num_pipeline_stages;
                rst_at_case(cases_in_count) := '1';
                report "RST"
                severity note;
                axi_in_state_nxt <= GET_FROM_AXI;        
                
        end case;
    end process axi_in;
    
    axi_out : process(ili,axi_out_state) is
        variable pass_count : integer := 0;
        variable fail_count : integer := 0;
        
    begin
        case(axi_out_state) is
            when WAIT_FOR_PIPELINE =>
                ipo <= '0';
                if ili = '1' then
                    axi_out_state_nxt <= GIVE_TO_AXI;
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
                
                if cases_out_count = cases_in_count then
                    axi_out_state_nxt <= FINISHED_OUT;
                end if;
    
                ipo <= '1';
                if ili = '0' then
                    cases_out_count := cases_out_count + 1;
                    axi_out_state_nxt <= WAIT_FOR_PIPELINE;                
                end if;
                
            when FINISHED_OUT =>
                report " " severity note;  -- Add a blank line before
                report "Test summary: " & integer'image(pass_count) & " cases passed, " & integer'image(fail_count) & " cases failed." severity note; 
                report " " severity note;  -- Add a blank line after
                
            when others =>
        end case;
    end process axi_out;
    
    fsm_seq : process(clk) is
    begin
        if (clk'event and clk='1') then
            axi_in_state <= axi_in_state_nxt;
            axi_out_state <= axi_out_state_nxt;
        end if;
    end process fsm_seq;
end rtl;
        
    
    

        
        