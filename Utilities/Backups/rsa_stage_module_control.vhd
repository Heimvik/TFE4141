library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;

entity rsa_stage_module_control is
    generic(
        c_block_size : integer := 256;
        c_pipeline_stages : integer;
        num_status_bits : integer := 32
    );
    port(
        --Defaults
        clk : in std_logic;
        rst : in std_logic;

        --Data signals
        es : in std_logic_vector ((c_block_size/c_pipeline_stages)-1 downto 0);
        
        --Control signals
        ili : in std_logic;
        ipi : in std_logic;
        ipo : out std_logic;
        ilo : out std_logic;
        
        c_mux_ctl : out std_logic;
        p_mux_ctl : out std_logic;
        
        c_reg_clk_en : out std_logic;
        c_reg_rst : out std_logic;
        p_reg_clk_en : out std_logic; 
        p_reg_rst : out std_logic;
        
        c_bm_abval : out std_logic;
        c_bm_rval : in std_logic;
        P_bm_abval : out std_logic;
        p_bm_rval : in std_logic;

        
        rst_bms : out std_logic;
        
        --Status signals 
        ctl_status : out std_logic_vector(num_status_bits-1 downto 0)
    );
end rsa_stage_module_control;

architecture rsa of rsa_stage_module_control is
    type s_state is (IDLE,SAVE_IN,ACK_IN,RUN_BM,HOLD_OUT);
    type bm_state is (CURRENT_INIT,CURRENT_FINISHED);
    
    signal stage_state : s_state := IDLE;
    signal stage_state_nxt : s_state;
    signal blakeley_module_state : bm_state := CURRENT_INIT;
    signal blakeley_module_state_nxt : bm_state;

begin
    fsm_comb : process(stage_state) is --Fill sens list
    
    begin
        case(stage_state) is
            when IDLE =>
                --Do idle stuff
            when SAVE_IN =>
                --Enable clock in intermediates
            when ACK_SAVE_IN =>
                --Ack for the values you popped off
            when RUN_BM =>
                case(blakeley_module_state) is
                    when CURRENT_INIT =>
                        --If statement on current ES index
                        
                        --Assert ABVAL
                        --Wait for RVAL assertion for CURRENT_FINISED
                    when CURRENT_FINISHED =>
                        --Clock result in
                        
                        --Negate ABVAL
                        --Wait for RVAL negation
                        
                        --Not last ES index for new current and CURRENT_INIT
                        --Last ES index for HOLD_OUT
                    when others=>
            when HOLD_OUT =>
                --Assert ILO
                --Wait for IPI assertion for IDLE
            when others =>
    end process fsm_comb;
    
    fsm_seq : process(clk) is
    begin
        if(clk'event and clk = '1') then
            stage_state <= stage_state_nxt;
            bm_state <= bm_state_nxt;
        end if
    end process fsm_seq;
end architecture rsa_stage_module_control;
                
                
                
                
                
                