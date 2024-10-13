library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

library work;
use work.blakeley_utils.all;

entity blakeley_module_tb is
    generic (
		c_block_size : integer := 256;
        num_status_bits : integer := 32
    );
end blakeley_module_tb;

architecture rtl of blakeley_module_tb is
    signal A : std_logic_vector (c_block_size-1 downto 0);
    signal B : std_logic_vector (c_block_size-1 downto 0);
    signal N : std_logic_vector (c_block_size-1 downto 0);
    signal ABVAL : std_logic;
    signal R : std_logic_vector (c_block_size-1 downto 0);
    signal RVAL : std_logic;
           
    signal clk : std_logic;
    signal rst : std_logic;
    
    signal sum_out : std_logic_vector(c_block_size-1 downto 0);    
    signal ainc_out : std_logic_vector(log2(c_block_size)-1 downto 0);
    signal mux_ctl : unsigned(1 downto 0);
    
    signal blakeley_status : std_logic_vector(num_status_bits-1 downto 0);
    
    constant clk_period : time := 2 ns;


begin
    DUT: entity work.blakeley_module
        generic map(
            c_block_size => c_block_size
        )
        port map(
            clk => clk,
            rst => rst,
            
            A => A,
            B => B,
            N => N,
            ABVAL => ABVAL,
            R => R,
            RVAL => RVAL,
            
            sum_out => sum_out,
            ainc_out => ainc_out,
            mux_ctl => mux_ctl,
            
            blakeley_status => blakeley_status
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
    
    stimulus: process
    begin
        wait for clk_period;
        A <= std_logic_vector(to_unsigned(12422,c_block_size));
        B <= std_logic_vector(to_unsigned(12311,c_block_size));
        N <= std_logic_vector(to_unsigned(99999,c_block_size));
        wait for clk_period;
        ABVAL <= '1';
        wait until RVAL = '1';
        wait for clk_period;
        ABVAL <= '0'; --Should put blakeley module in idle
        
        wait;
    end process stimulus;
end architecture rtl;