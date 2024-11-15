library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

library work;
use work.blakeley_utils.all;

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all; 
    
entity blakeley_module_datapath is
    generic (
        c_block_size : integer;
        log2_c_block_size : integer;
                
        -- Where the control fields ends, and datapath filed starts
        num_status_bits : integer := 32;
        datapath_offset : integer := 4;
        ainc_ierr_bit : integer := 0;
        mux_ctl_ierr_bit : integer := 1;
        
        --Length is log2_c_block_size
        ainc_debug_offset : integer := 2;
        
        mux_ctl_size : integer := 2; 
        mux_ctl_offset : integer := 10
        
    );
    port ( 
          --Defaults
          clk : in std_logic;
    
           --Data signals
           a : in std_logic_vector (c_block_size-1 downto 0);
           b : in std_logic_vector (c_block_size-1 downto 0);
           n : in std_logic_vector (c_block_size+1 downto 0); --NB: To avoid overflow
           r : out std_logic_vector (c_block_size-1 downto 0);
           
           --Control signals
           ainc_clk_en : in std_logic;
           ainc_rst : in std_logic;
           add_out_clk_en : in std_logic;
           add_out_rst : in std_logic;
           mux_ctl : in unsigned(1 downto 0);

           sum_out : out std_logic_vector(c_block_size+1 downto 0);   --NB: To avoid overflow
           ainc_out : out std_logic_vector(log2_c_block_size-1 downto 0)
           
           --Status signals
           --datapath_status : out std_logic_vector(num_status_bits-1 downto 0) := (others => '0')
    );
end blakeley_module_datapath;

architecture rtl of blakeley_module_datapath is
    signal ainc : unsigned(log2_c_block_size-1 downto 0);
    signal ainc_nxt : unsigned(log2_c_block_size-1 downto 0);
    
    signal r_out : unsigned (c_block_size-1 downto 0);

    signal dec_out : std_logic_vector (c_block_size-1 downto 0);
    signal mul_out : unsigned(c_block_size-1 downto 0);
    signal shift_out : unsigned(c_block_size+1 downto 0);       --NB: To avoid overflow
    
    signal add_out : unsigned(c_block_size+1 downto 0);       --NB: To avoid overflow
    signal add_out_nxt : unsigned(c_block_size+1 downto 0);   --NB: To avoid overflow
    
    signal sub0 : unsigned(c_block_size+1 downto 0);
    signal sub1 : unsigned(c_block_size+1 downto 0);
    signal sub2 : unsigned(c_block_size+1 downto 0);
begin
    -- Debug lines
    
    -- Datapath combinatorials
    ainc_nxt <= ainc + to_unsigned(1,log2_c_block_size);
    sum_out <= std_logic_vector(add_out);
    ainc_out <= std_logic_vector(ainc);
    
    --Select the whole b, only if we got a '1' bit in the current position in a, using ainc to iterate from MSB to LSB
    sel_a_comb : process (a,b,ainc) is
    begin
        if a((c_block_size-1)- to_integer(ainc)) = '1' then
            mul_out <= unsigned(b);
        else
            mul_out <= (others => '0');
        end if;
    end process sel_a_comb;
    
    --Multiply the current r by 2
    shift_out <= resize(r_out,shift_out'length) sll 1;
    
    --Do the addition of the current r and the result from the potential b
    add_out_nxt <= resize(mul_out,add_out_nxt'length) + shift_out;
    
    --As the addition are limited to 3(n-1), two subractions are needed at most
    sub0 <= add_out;
    sub1 <= add_out - unsigned(n);
    sub2 <= add_out - (unsigned(n) sll 1);
    
    --Select the correct subtraction, based of the result of add_out compared to the modulus n
    sel_sub_comb : process(mux_ctl, sub0, sub1, sub2) is
    begin
        --r_out <= sub0(c_block_size-1 downto 0);
        case(to_integer(mux_ctl)) is
            when 0 =>
                r_out <= sub0(c_block_size-1 downto 0);
            when 1 =>
                r_out <= sub1(c_block_size-1 downto 0);
            when 2 =>
                r_out <= sub2(c_block_size-1 downto 0);
            when others =>
        end case;
    end process sel_sub_comb;

    r <= std_logic_vector(r_out);
        
    -- Datapath sequentials
    datapath_seq : process(clk,ainc_rst,add_out_rst) is
    begin
        --Gated clocks
        if (clk'event and clk='1') then
            if ainc_clk_en = '1' then
                ainc <= ainc_nxt;
            end if;
            if add_out_clk_en = '1' then
                add_out <= add_out_nxt;
            end if;
        end if;
        
        -- Asynchronus reset
        if (ainc_rst = '1') then
            ainc <= to_unsigned(0,log2_c_block_size);
        end if;
        
        if (add_out_rst = '1') then
            add_out <= to_unsigned(0,C_BLOCK_SIZE+2);
        end if;
    end process datapath_seq;
end architecture rtl;
