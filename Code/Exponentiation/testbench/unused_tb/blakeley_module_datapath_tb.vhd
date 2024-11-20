library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

library work;
use work.blakeley_utils.all;

entity blakeley_module_datapath_tb is
    generic(
        log2_c_block_size : integer := 8
    );
end blakeley_module_datapath_tb;

architecture behavior of blakeley_module_datapath_tb is
    constant C_BLOCK_SIZE : integer := 256;
    constant CLK_PERIOD : time := 2 ns;

    signal a : std_logic_vector(C_BLOCK_SIZE-1 downto 0);
    signal b : std_logic_vector(C_BLOCK_SIZE-1 downto 0);
    signal n : std_logic_vector(C_BLOCK_SIZE-1 downto 0);
    signal r : std_logic_vector(C_BLOCK_SIZE-1 downto 0);
    
    signal clk : std_logic := '0';
    signal rst : std_logic := '0';
    
    signal ainc_clk_en : std_logic := '0';
    signal ainc_rst : std_logic := '0';
    signal add_out_clk_en : std_logic := '0';
    signal add_out_rst : std_logic := '0';
    signal r_out_clk_en : std_logic := '0';
    signal r_out_rst : std_logic := '0';
    signal mux_ctl : unsigned(1 downto 0);
    
    signal datapath_status : std_logic_vector(31 downto 0);
    signal datapath_debug : std_logic_vector(31 downto 0);
    signal sum_out : std_logic_vector(C_BLOCK_SIZE-1 downto 0);
    signal ainc_out : std_logic_vector(log2_c_block_size-1 downto 0);

begin

    DUT: entity work.blakeley_module_datapath
        generic map (
            c_block_size => C_BLOCK_SIZE
        )
        port map (
            a => a,
            b => b,
            n => n,
            r => r,
            clk => clk,
            ainc_clk_en => ainc_clk_en,
            ainc_rst => ainc_rst,
            add_out_clk_en => add_out_clk_en,
            add_out_rst => add_out_rst,
            r_out_clk_en => r_out_clk_en,
            r_out_rst => r_out_rst,
            datapath_status => datapath_status,
            datapath_debug => datapath_debug,
            sum_out => sum_out,
            mux_ctl => mux_ctl,
            ainc_out => ainc_out
        );

    clk_process: process
    begin
        while true loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
    end process clk_process;

    stimulus_process: process
    begin
        add_out_clk_en <= '1';
        mux_ctl <= to_unsigned(0,2);
        a <= (others => '0');
        b <= (others => '0');
        r_out_rst <= '0';
        ainc_rst <= '0';
        add_out_rst <= '0';
        wait for 2*CLK_PERIOD;
        r_out_rst <= '1';
        ainc_rst <= '1';
        add_out_rst <= '1';
        wait for CLK_PERIOD;
        r_out_rst <= '0';
        ainc_rst <= '0';
        add_out_rst <= '0';
        wait for 2*CLK_PERIOD;

        ainc_clk_en <= '1';

        for i in 0 to C_BLOCK_SIZE - 1 loop
            wait for CLK_PERIOD;
            assert (to_integer(unsigned(datapath_debug(0 downto 2))) = 0) 
            report "Ainc did not increment correctly!" severity error;
        end loop;
        
        ainc_clk_en <= '0';
        
        r_out_rst <= '1';
        ainc_rst <= '1';
        add_out_rst <= '1';
        wait for CLK_PERIOD;
        r_out_rst <= '0';
        ainc_rst <= '0';
        add_out_rst <= '0';
        wait for CLK_PERIOD;
        
        n <= (others =>'0');
        a <= (others =>'1');
        b <= (others =>'1');
        n(1) <= '1';
        r_out_clk_en <= '0';
        ainc_clk_en <= '1';
        wait for 10*CLK_PERIOD;
        r_out_clk_en <= '1';
        ainc_clk_en <= '0';
        mux_ctl <= to_unsigned(0,2);
        wait for 4*CLK_PERIOD;
        mux_ctl <= to_unsigned(1,2);
        wait for 4*CLK_PERIOD;
        mux_ctl <= to_unsigned(2,2);
        wait for 10*CLK_PERIOD;
        
        wait;
    end process stimulus_process;

end architecture behavior;
