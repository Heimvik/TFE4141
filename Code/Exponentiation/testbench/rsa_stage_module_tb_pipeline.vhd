library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;
use STD.textio.all;
use ieee.std_logic_textio.all;

use work.tb_utils.all;

entity rsa_stage_module_tb_extended is
    generic(
        c_block_size : integer := 256;
        log2_c_block_size : integer := 8;
        c_pipeline_stages : integer := 1;
        num_status_bits : integer := 32;
        CLK_PERIOD : time := 1 ns        
    );
end rsa_stage_module_tb_extended;

architecture rtl of rsa_stage_module_tb_extended is    
    signal clk : std_logic;
    signal rst : std_logic;
    
    --Control signals             
    signal ili : std_logic;
    signal ipi : std_logic;
    signal ipo : std_logic;
    signal ilo : std_logic;
    
    --Data signals
    signal dpo : std_logic_vector (c_block_size-1 downto 0);
    signal dco : std_logic_vector (c_block_size-1 downto 0);
    signal dpi : std_logic_vector (c_block_size-1 downto 0);
    signal dci : std_logic_vector (c_block_size-1 downto 0);
    
    --Status registers
    signal rsm_status : std_logic_vector(num_status_bits-1 downto 0);
    signal bm_status : std_logic_vector(num_status_bits-1 downto 0);
    
    --Init values
    signal n : std_logic_vector (c_block_size-1 downto 0);
    signal es : std_logic_vector ((c_block_size/c_pipeline_stages)-1 downto 0);
    
    --Test values    
    file inputfile : text open read_mode is "input_data.csv";
    
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

    -- Generate the pipeline stages
    gen_pipeline : for i in 1 to c_pipeline_stages generate

        first_stage : if i = 1 generate
            start_stage : entity work.rsa_stage_module
            generic map(
                c_block_size => c_block_size,
                log2_c_block_size => log2_c_block_size,
                c_pipeline_stages => c_pipeline_stages,
                num_status_bits => num_status_bits
            )
            port map(
                CLK => clk,
                RST => rst,
                ILI => ilo,
                IPI => ipo,
                IPO => ipi,
                ILO => ili,
                N => n,
                ES => es,
                DPI => dpo,
                DCI => dco,
                DPO => dpi,
                DCO => dci,
                rsm_status => rsm_status,
                bm_status => bm_status
            );
        end generate first_stage;

        middle_stage : if i /= 1 and i /= c_pipeline_stages generate
            generic_stage : entity work.rsa_stage_module
            generic map(
                c_block_size => c_block_size,
                log2_c_block_size => log2_c_block_size,
                c_pipeline_stages => c_pipeline_stages,
                num_status_bits => num_status_bits
            )
            port map(
                CLK => clk,
                RST => rst,
                ILI => ilo,
                IPI => ipo,
                IPO => ipi,
                ILO => ili,
                N => n,
                ES => es,
                DPI => dpo,
                DCI => dco,
                DPO => dpi,
                DCO => dci,
                rsm_status => rsm_status,
                bm_status => bm_status
            );
        end generate middle_stage;

        last_stage : if i = c_pipeline_stages generate
            end_stage : entity work.rsa_stage_module
            generic map(
                c_block_size => c_block_size,
                log2_c_block_size => log2_c_block_size,
                c_pipeline_stages => c_pipeline_stages,
                num_status_bits => num_status_bits
            )
            port map(
                CLK => clk,
                RST => rst,
                ILI => ilo,
                IPI => ipo,
                IPO => ipi,
                ILO => ili,
                N => n,
                ES => es,
                DPI => dpo,
                DCI => dco,
                DPO => dpi,
                DCO => dci,
                rsm_status => rsm_status,
                bm_status => bm_status
            );
        end generate last_stage;
    end generate gen_pipeline;
    
    stimuli : process is
        -- Has to be local variables, as they need to be updated inside the process (and not after termination)
        variable case_count : integer := 0;
        variable pass_count : integer := 0;
        variable fail_count : integer := 0;
        variable failed_cases : string(1 to 1000) := (others => ' ');
        variable failed_cases_tmp : string(1 to 1000);
        
        variable current_case_m, current_case_es, current_case_n, current_case_correct_c: std_logic_vector(c_block_size-1 downto 0);
        variable current_case_calculated_c : std_logic_vector(c_block_size-1 downto 0);
        
        file csv_file : text;
        variable current_line : line;
        
        variable comma : character;
    begin
        file_open(csv_file,"C:\Users\cmhei\OneDrive\Dokumenter\Semester 7\TFE4141 DDS1\Project\Utilities\testcases.csv",READ_MODE);
        while true loop
            readline(csv_file,current_line);
            read(current_line,current_case_m);
            read(current_line,comma);
            read(current_line,current_case_es);
            read(current_line,comma);
            read(current_line,current_case_n);
            read(current_line,comma);
            read(current_line,current_case_correct_c);

            if (vectors_equal(current_case_m,(others => '0')) 
                and vectors_equal(current_case_es,(others => '0')) 
                and vectors_equal(current_case_n,(others => '0')) 
                and vectors_equal(current_case_correct_c,(others => '0'))) then
                exit;  -- Exit if all cases are zero
            end if;
            
            case_count := case_count + 1; -- Increment case number
            
            es <= current_case_es;
            n <=  current_case_n;
            
            -- Signal inputs transmitted procedure
            ipo <= '0';
            ilo <= '0';
            
            --Transmit inputs
            dco <= std_logic_vector(to_unsigned(1, c_block_size));
            dpo <= current_case_m;
            
            --Signal inputs transmitted procedure
            ilo <= '1';
            wait until ipi = '1' and rising_edge(clk);
            ilo <= '0';
            
            --Wait for output ready signal
            wait until ili = '1' and rising_edge(clk);
            
            --Receive outputs
            current_case_calculated_c := dci;
            
            --Signal outputs received procedure
            ipo <= '1';
            wait until ili = '0' and rising_edge(clk);
            ipo <= '0';
    
            -- Compare the result with the expected solution
            if vectors_equal(current_case_calculated_c,current_case_correct_c) then
                pass_count := pass_count + 1;
                report "OK: Case " & integer'image(case_count) & " passed!"
                severity note;
            else
                fail_count := fail_count + 1;
                report "FAIL: Case " & integer'image(case_count) & " failed"
                severity note;
            end if;

        end loop;
        file_close(csv_file);

        --Final summary report
        report " " severity note;  -- Add a blank line before
        report "Test summary: " & integer'image(pass_count) & " cases passed, " & integer'image(fail_count) & " cases failed." severity note; 
        report " " severity note;  -- Add a blank line after
        
        -- Print all failed cases if there are any
        --if fail_count > 0 then
        --    report "Failed cases:" & LF & failed_cases severity error;
        --end if;
        
        wait;
    end process stimuli;
end rtl;
        
    
    

        
        