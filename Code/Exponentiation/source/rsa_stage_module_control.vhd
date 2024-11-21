library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;

entity rsa_stage_module_control is
    generic(
        c_block_size : integer;
        log2_c_block_size : integer;
        e_block_size : integer;
        es_size : integer;
        log2_es_size : integer;
        
        num_pipeline_stages : integer;
        num_status_bits : integer;
        
        control_offset : integer := 0;
        
        ili_bit : integer := 0;
        ipi_bit : integer := 1;
        ilo_bit : integer := 2;
        ipo_bit : integer := 3;
        c_bm_rval_bit : integer := 4;
        p_bm_rval_bit : integer := 5;
        
        s_state_size : integer := 3;
        s_state_offset : integer := 6;
        
        bm_state_size : integer := 2;
        bm_state_offset : integer := 9;
        
        es_index_offset : integer := 11
        
    );
    port(
        --Defaults
        clk : in std_logic;
        rst : in std_logic;

        --Data signals
        es : in std_logic_vector (es_size-1 downto 0);
        
        --Control signals
        ili : in std_logic;
        ipi : in std_logic;
        ilo : out std_logic;
        ipo : out std_logic;
        
        c_mux_ctl : out std_logic;
        p_mux_ctl : out std_logic;
        
        c_reg_clk_en : out std_logic;
        c_reg_rst : out std_logic;
        p_reg_clk_en : out std_logic; 
        p_reg_rst : out std_logic;
        
        c_bm_abval : out std_logic;
        c_bm_rval : in std_logic;
        p_bm_abval : out std_logic;
        p_bm_rval : in std_logic;

        
        rst_bms : out std_logic;
        
        --Status signals 
        control_status : out std_logic_vector(num_status_bits-1 downto 0) := (others=>'0')
    );
end rsa_stage_module_control;

architecture rtl of rsa_stage_module_control is
    type s_state is (IDLE,SAVE_IN,ACK_SAVE_IN,RUN_BM,HOLD_OUT);
    type bm_state is (RUN_CP,FINISHED_CP);
    
    signal stage_state : s_state := IDLE;
    signal stage_state_nxt : s_state := IDLE;
    signal blakeley_module_state : bm_state := RUN_CP;
    signal blakeley_module_state_nxt : bm_state := RUN_CP;
    
    signal ilo_internal : std_logic;
    signal ipo_internal : std_logic;
    
    signal es_index : unsigned(log2_es_size-1 downto 0) := to_unsigned(0,log2_es_size);
    signal es_index_nxt : unsigned(log2_es_size-1 downto 0) := to_unsigned(0,log2_es_size);

begin
    ilo <= ilo_internal;
    ipo <= ipo_internal;
    
    fsm_comb : process(stage_state,blakeley_module_state,ili,es,c_bm_rval,p_bm_rval,ipi,es_index) is
    begin
        --Assign contro status in all cases to hider inferred latches
        control_status <= (others => '0');
        control_status(control_offset+ipi_bit downto control_offset+ili_bit) <= ipi & ili;
        control_status(control_offset+ipo_bit downto control_offset+ilo_bit) <= ipo_internal & ilo_internal;
        control_status(control_offset+p_bm_rval_bit downto control_offset+c_bm_rval_bit) <= p_bm_rval & c_bm_rval;
        control_status(control_offset+es_index_offset+log2_es_size-1 downto control_offset+es_index_offset) <= std_logic_vector(es_index);
        
        c_reg_rst <= '0';
        p_reg_rst <= '0';
        
        case(stage_state) is
            
            --PURPOSE OF STATE:
            --Wait for c and p values from the previouss stage (being either the previous stage in the pipeline or axi_in)
            --Set up the datapath such that MUX4 and MUX5 (see michroarchitecture) is set to take inputs from the previous stage
            --Set blakeley module in idle and dont reset
            when IDLE =>
                control_status(control_offset+s_state_offset+s_state_size-1 downto control_offset+s_state_offset) <= "000";
                ilo_internal <= '0';
                ipo_internal <= '0';
                
                c_mux_ctl <= '0';
                p_mux_ctl <= '0';
                
                c_bm_abval <= '0';
                p_bm_abval <= '0';
                
                c_reg_clk_en <= '0';
                p_reg_clk_en <= '0';
                
                blakeley_module_state_nxt <= RUN_CP;
                es_index_nxt <= es_index;
                
                if ili = '1' then
                    stage_state_nxt <= SAVE_IN;
                else
                    stage_state_nxt <= IDLE;
                end if;
            
            --PURPOSE OF STATE:
            --We have now received our c and p from the previous stage, and we know by the assertion of ili
            --These values should now be clocked in to their respective registers by enabling the gated clocks
            when SAVE_IN =>
                control_status(control_offset+s_state_offset+s_state_size-1 downto control_offset+s_state_offset) <= "001";
                ilo_internal <= '0';
                ipo_internal <= '0';
                
                c_mux_ctl <= '0';
                p_mux_ctl <= '0';
                
                c_bm_abval <= '0';
                p_bm_abval <= '0';
                
                c_reg_clk_en <= '1';
                p_reg_clk_en <= '1';
                
                blakeley_module_state_nxt <= RUN_CP;
                es_index_nxt <= es_index;
                stage_state_nxt <= ACK_SAVE_IN;
            
            --PURPOSE OF STATE:
            --Acknowledge to the previous stage that you popped off its values by asserting ipo 
            --We have to only proceed if the previous stage has returned to idle, such that coming around again before the previous stage won't pick up the same value this is done by checking for ili='0'
            --As we now have received results from the previous stage, we switch both MUX4 and MUX5 to only take internal inputs
            when ACK_SAVE_IN =>
                control_status(control_offset+s_state_offset+s_state_size-1 downto control_offset+s_state_offset) <= "010";
                ilo_internal <= '0';
                ipo_internal <= '1';
                
                c_mux_ctl <= '1';
                p_mux_ctl <= '1';
                
                c_bm_abval <= '0';
                p_bm_abval <= '0';
                
                c_reg_clk_en <= '0';
                p_reg_clk_en <= '0';
                
                blakeley_module_state_nxt <= RUN_CP;
                es_index_nxt <= es_index;
                --To ensure that previous stage has returned to idle, such that coming around again before the previous stage won't pick up the same value
                if ili = '0' then
                    stage_state_nxt <= RUN_BM;
                else
                    stage_state_nxt <= ACK_SAVE_IN;
                end if;
            
            --PURPOSE OF STATE:
            --Run both c and p blakeley modules
            --Keep both MUXes to mux in inernals singals only
            when RUN_BM =>
                control_status(control_offset+s_state_offset+s_state_size-1 downto control_offset+s_state_offset) <= "011";
                
                ilo_internal <= '0';
                ipo_internal <= '0';
                
                c_mux_ctl <= '1';
                p_mux_ctl <= '1';
                
                case(blakeley_module_state) is
                    
                    --PURPOSE OF STATE:
                    --Initiatiate the blakeley_module by asserting _abval when the operands are ready
                    --Upon a valid output (_rval = '1') clock in:
                    --Current c should be clocked in if the current bit in the encryption key slice es is 1
                    --Current p should always be clocked in
                    when RUN_CP =>
                        control_status(control_offset+bm_state_offset+bm_state_size-1 downto control_offset+bm_state_offset) <= "00";
                        
                        c_bm_abval <= '1';                        
                        p_bm_abval <= '1';
                        stage_state_nxt <= RUN_BM;
                        
                        if c_bm_rval = '1' and p_bm_rval = '1' then
                            c_reg_clk_en <= std_logic(es(to_integer(es_index)));
                            p_reg_clk_en <= '1';
                            es_index_nxt <= es_index + 1; --Intended to overflow upon reaching max to save LUT
                            blakeley_module_state_nxt <= FINISHED_CP;
                        else
                            c_reg_clk_en <= '0';
                            p_reg_clk_en <= '0';
                            es_index_nxt <= es_index;
                            blakeley_module_state_nxt <= RUN_CP;
                        end if;
                       
                    --PURPOSE OF STATE:
                    --Acknowledge to the blakeley_module that you have clocked in its values by negating the _abval
                    --Wait for the blakeley_module to respond with a negation of _rval in order to proceed
                    --Check if the current es_index is max of what it is supposed to be within out encryption key slice es, if it is, we are done and needs to hold out the result to the next stage
                    when FINISHED_CP =>
                        control_status(control_offset+bm_state_offset+bm_state_size-1 downto control_offset+bm_state_offset) <= "01";
          
                        c_reg_clk_en <= '0';
                        p_reg_clk_en <= '0';
                                        
                        c_bm_abval <= '0';
                        p_bm_abval <= '0';
                        
                        es_index_nxt <= es_index;
                        
                        if c_bm_rval = '0' and p_bm_rval = '0' then
                            blakeley_module_state_nxt <= RUN_CP;
                            if es_index = to_unsigned(es_size,log2_es_size) then
                                es_index_nxt <= to_unsigned(0,log2_es_size);
                                stage_state_nxt <= HOLD_OUT;
                            else
                                es_index_nxt <= es_index;
                                stage_state_nxt <= RUN_BM;
                            end if;
                        else
                            blakeley_module_state_nxt <= FINISHED_CP;
                            stage_state_nxt <= RUN_BM;
                        end if;
                end case;
            
            --PURPOSE OF STATE:
            --Hold the current value out to the next stage and wait for it to pop it off (that is, wait until we get ipi = '1') 
            --If we notice that the next tage have taken over our values, provceed to idle where we can pick up the values from the previous stage
            when HOLD_OUT =>
                control_status(control_offset+s_state_offset+s_state_size-1 downto control_offset+s_state_offset) <= "100";
                
                ilo_internal <= '1';
                ipo_internal <= '0';
                
                c_mux_ctl <= '1';
                p_mux_ctl <= '1';
                
                c_bm_abval <= '0';
                p_bm_abval <= '0';
                
                c_reg_clk_en <= '0';
                p_reg_clk_en <= '0';
                
                blakeley_module_state_nxt <= RUN_CP;
                es_index_nxt <= es_index;
                if ipi = '1' then
                    stage_state_nxt <= IDLE;
                else
                    stage_state_nxt <= HOLD_OUT;
                end if;
        end case;
    end process fsm_comb;
    
    fsm_seq : process(clk,rst) is
    begin
        if(clk'event and clk = '1') then
            stage_state <= stage_state_nxt;
            blakeley_module_state <= blakeley_module_state_nxt;
            es_index <= es_index_nxt;
        end if;
        
        --Asynchronus reset
        if rst = '1' then
            stage_state <= IDLE;
            es_index <= to_unsigned(0,log2_es_size);
            rst_bms <= '1';
        else
            rst_bms <= '0';
        end if;
    end process fsm_seq;
end architecture rtl;
                