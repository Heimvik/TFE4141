library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

library work;
use work.blakeley_utils.all;

entity blakeley_module_control is
    generic (
        c_block_size : integer;
        log2_c_block_size : integer;
        
        num_status_bits : integer := 32;      
        
        -- Where the control fields ends, and datapath filed starts
        control_offset : integer := 0;
        ainc_clk_en_bit : integer := 0;
        add_out_clk_en_bit : integer := 1
    );
    port (
           --Defaults            
           clk : in std_logic;
           rst : in std_logic;

           n : in std_logic_vector (c_block_size+1 downto 0);
           abval : in std_logic;
           rval : out std_logic;
           
           ainc_clk_en : out std_logic;
           ainc_rst : out std_logic;
           add_out_clk_en : out std_logic;
           add_out_rst : out std_logic;
           mux_ctl : out unsigned(1 downto 0);
           
           ainc_out : in std_logic_vector(log2_c_block_size-1 downto 0);
           sum_out : in std_logic_vector(c_block_size+1 downto 0) --NB: To avoid overflow (MAY have to be one more bit?)
    );
end blakeley_module_control;

architecture rtl of blakeley_module_control is
    type c_state is (IDLE,START,RUN,FINISHED);
    signal control_state : c_state := IDLE; 
    signal control_state_nxt : c_state;
begin    
    fsm_comb : process(control_state,abval,ainc_out,sum_out,n) is
        variable ainc_limit : unsigned(log2_c_block_size-1 downto 0);
    begin
        ainc_limit := (others => '1');
        case (control_state) is
            
            --PURPOSE OF STATE:
            --Wait for a abval negation and oparands a and b to be applied
            --Until then, set up the datapath such that we can start clocking of ainc and add_out immediately
            --Keep rval negated  
            when IDLE =>
                rval <= '0';
                
                ainc_rst <= '1';
                add_out_rst <= '1';
                
                ainc_clk_en <= '0';
                add_out_clk_en <= '0';
                
                mux_ctl <= to_unsigned(0,2);
                
                if abval = '1' then
                    control_state_nxt <= RUN;
                else
                    control_state_nxt <= IDLE;
                end if;
            
            --PURPOSE OF STATE:
            --We have now gotten operands, and need to run the blakeley algorithm for 256 consectutive cycles, this is done by
            --1) Continuously incrementing ainc, potentially adding b to the current r between each rising edge
            --2) Continously clocking in new result in the ainc and add_out registers
            --3) Give the control signals to control MUX1 (see michroarchitecture) based off the value of the bit in a
            when RUN =>
                rval <= '0';
                
                ainc_rst <= '0';
                add_out_rst <= '0';
                
                ainc_clk_en <= '1';
                add_out_clk_en <= '1';
                
                if (unsigned(sum_out) < unsigned(n)) then
                    mux_ctl <= to_unsigned(0, 2);
                elsif (unsigned(sum_out) >= unsigned(n) and unsigned(sum_out) < (unsigned(n) sll 1)) then
                    mux_ctl <= to_unsigned(1, 2);
                else
                    mux_ctl <= to_unsigned(2, 2);
                end if;
                
                if unsigned(ainc_out) = ainc_limit then
                    ainc_clk_en <= '0';
                    control_state_nxt <= FINISHED;
                else
                    ainc_clk_en <= '1';
                    control_state_nxt <= RUN;
                end if;
            
            --PURPOSE OF STATE:
            --Interact with the above stage and signal that we are finished, asserting rval 
            --Hold the mux in the same position, in order to guarantee a stable result for the above level
            --Enter only idle and reset the registers only if the above level has acknowledged reveived values (negated abval)
            when FINISHED =>
                rval <= '1';
                
                ainc_rst <= '0';
                add_out_rst <= '0';
                
                add_out_clk_en <= '0';
                ainc_clk_en <= '0';
                
                if (unsigned(sum_out) < unsigned(n)) then
                    mux_ctl <= to_unsigned(0, 2);
                elsif (unsigned(sum_out) >= unsigned(n) and unsigned(sum_out) < (unsigned(n) sll 1)) then
                    mux_ctl <= to_unsigned(1, 2);
                else
                    mux_ctl <= to_unsigned(2, 2);
                end if;

                if(abval = '0') then
                    control_state_nxt <= IDLE;
                else
                    control_state_nxt <= FINISHED;
                end if;
            when others =>
                rval <= '0';
                
                ainc_rst <= '0';
                add_out_rst <= '0';
                
                add_out_clk_en <= '0';
                ainc_clk_en <= '0';
                
                mux_ctl <= to_unsigned(0, 2);
                control_state_nxt <= IDLE;
         end case;     
      end process fsm_comb;
      
      fsm_seq : process(clk,rst) is
      begin
        if(clk'event and clk = '1') then
            control_state <= control_state_nxt;
        end if;
        
        --Asynchronus reset
        if rst = '1' then
            control_state <= IDLE;
        end if;
      end process fsm_seq;
end architecture rtl;
                    
                
                    