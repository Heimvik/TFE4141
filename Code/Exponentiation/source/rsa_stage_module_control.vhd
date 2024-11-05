library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;

entity rsa_stage_module_control is
    generic(
        c_block_size : integer;
        log2_c_block_size : integer;
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
        es : in std_logic_vector ((c_block_size/num_pipeline_stages)-1 downto 0);
        
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
    
    constant es_size : integer := c_block_size/num_pipeline_stages;

begin
    control_status(control_offset+ipi_bit downto control_offset+ili_bit) <= ipi & ili;
    control_status(control_offset+ipo_bit downto control_offset+ilo_bit) <= ipo_internal & ilo_internal;
    control_status(control_offset+p_bm_rval_bit downto control_offset+c_bm_rval_bit) <= p_bm_rval & c_bm_rval;
    control_status(control_offset+es_index_offset+log2_es_size-1 downto control_offset+es_index_offset) <= std_logic_vector(es_index);
    ilo <= ilo_internal;
    ipo <= ipo_internal;
    
    fsm_comb : process(stage_state,blakeley_module_state,ili,es,c_bm_rval,p_bm_rval,ipi,es_index) is
    begin
        case(stage_state) is
            when IDLE =>
                control_status(control_offset+s_state_offset+s_state_size-1 downto control_offset+s_state_offset) <= "000";
                --control_status(control_offset+bm_state_offset+bm_state_size-1 downto control_offset+bm_state_offset) <= "00";
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
                    c_reg_rst <= '1';
                    p_reg_rst <= '1';
                    stage_state_nxt <= SAVE_IN;
                else
                    c_reg_rst <= '0';
                    p_reg_rst <= '0';
                    stage_state_nxt <= IDLE;
                end if;
                
            when SAVE_IN =>
                control_status(control_offset+s_state_offset+s_state_size-1 downto control_offset+s_state_offset) <= "001";
                --control_status(control_offset+bm_state_offset+bm_state_size-1 downto control_offset+bm_state_offset) <= "00";
                ilo_internal <= '0';
                ipo_internal <= '0';
                
                c_mux_ctl <= '0';
                p_mux_ctl <= '0';
                
                c_bm_abval <= '0';
                p_bm_abval <= '0';
                
                --Watch the hold time here!
                c_reg_clk_en <= '1';
                p_reg_clk_en <= '1';
                
                c_reg_rst <= '0';
                p_reg_rst <= '0';
                
                blakeley_module_state_nxt <= RUN_CP;
                es_index_nxt <= es_index;
                stage_state_nxt <= ACK_SAVE_IN;
                
            when ACK_SAVE_IN =>
                control_status(control_offset+s_state_offset+s_state_size-1 downto control_offset+s_state_offset) <= "010";
                --control_status(control_offset+bm_state_offset+bm_state_size-1 downto control_offset+bm_state_offset) <= "00";
                --Ack for the values you popped off
                ilo_internal <= '0';
                ipo_internal <= '1';
                
                c_mux_ctl <= '1';
                p_mux_ctl <= '1';
                
                c_bm_abval <= '0';
                p_bm_abval <= '0';
                
                c_reg_clk_en <= '0';
                p_reg_clk_en <= '0';
                
                c_reg_rst <= '0';
                p_reg_rst <= '0';
                
                blakeley_module_state_nxt <= RUN_CP;
                es_index_nxt <= es_index;
                --To ensure that previous stage has returned to idle, such that coming around again before the previous stage won't pick up the same value
                if ili = '0' then
                    stage_state_nxt <= RUN_BM;
                else
                    stage_state_nxt <= ACK_SAVE_IN;
                end if;
            
            when RUN_BM =>
                control_status(control_offset+s_state_offset+s_state_size-1 downto control_offset+s_state_offset) <= "011";
                
                ilo_internal <= '0';
                ipo_internal <= '0';
                
                c_mux_ctl <= '1';
                p_mux_ctl <= '1';
                
                c_reg_rst <= '0';
                p_reg_rst <= '0';
                
                
                case(blakeley_module_state) is
                    when RUN_CP =>
                        control_status(control_offset+bm_state_offset+bm_state_size-1 downto control_offset+bm_state_offset) <= "00";
                        
                        c_bm_abval <= '1';                        
                        p_bm_abval <= '1';
                        stage_state_nxt <= RUN_BM;
                        
                        if c_bm_rval = '1' and p_bm_rval = '1' then
                            --NB: The hold time when entering CP_FINISHED might be to small for clocking in results!
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
                        
                    when FINISHED_CP =>
                        control_status(control_offset+bm_state_offset+bm_state_size-1 downto control_offset+bm_state_offset) <= "01";
          
                        c_reg_clk_en <= '0';
                        p_reg_clk_en <= '0';
                                        
                        c_bm_abval <= '0';
                        p_bm_abval <= '0';
                        
                        es_index_nxt <= es_index;
                        
                        if c_bm_rval = '0' and p_bm_rval = '0' then
                            blakeley_module_state_nxt <= RUN_CP;
                            if es_index = to_unsigned(0,log2_es_size) then
                                stage_state_nxt <= HOLD_OUT;
                            else
                                stage_state_nxt <= RUN_BM;
                            end if;
                        else
                            blakeley_module_state_nxt <= FINISHED_CP;
                            stage_state_nxt <= RUN_BM;
                        end if;
                end case;
            when HOLD_OUT =>
                control_status(control_offset+s_state_offset+s_state_size-1 downto control_offset+s_state_offset) <= "100";
                --control_status(control_offset+bm_state_offset+bm_state_size-1 downto control_offset+bm_state_offset) <= "00";
                ilo_internal <= '1';
                ipo_internal <= '0';
                
                c_mux_ctl <= '1';
                p_mux_ctl <= '1';
                
                c_bm_abval <= '0';
                p_bm_abval <= '0';
                
                c_reg_clk_en <= '0';
                p_reg_clk_en <= '0';
                
                c_reg_rst <= '0';
                p_reg_rst <= '0';
                
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
        if rst = '1' then
            stage_state <= IDLE;
            es_index <= to_unsigned(0,log2_es_size);
            rst_bms <= '1';
        else
            rst_bms <= '0';
        end if;
    end process fsm_seq;
end architecture rtl;
                