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
        A <= std_logic_vector(to_unsigned(13,c_block_size));
        B <= std_logic_vector(to_unsigned(7,c_block_size));
        N <= std_logic_vector(to_unsigned(17,c_block_size));
        wait for clk_period;
        ABVAL <= '1';
        wait until RVAL = '1';
        wait for clk_period;
        ABVAL <= '0'; --Should put blakeley module in idle
        
        wait;
    end process stimulus;
end architecture rtl;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

library work;
use work.blakeley_utils.all;

entity blakeley_module_datapath_tb is
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
    signal ainc_out : std_logic_vector(log2(c_block_size)-1 downto 0);

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

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;

library work;
use work.blakeley_utils.all;

entity blakeley_module_control_tb is
end blakeley_module_control_tb;

architecture sim of blakeley_module_control_tb is

    -- Parameters for the test
    constant C_BLOCK_SIZE : integer := 8; -- Set the block size as needed
    constant NUM_STATUS_BITS : integer := 32;
    constant NUM_DEBUG_BITS : integer := 32;
    
    -- Signals to connect to the DUT (Device Under Test)
    signal clk : std_logic := '0';
    signal rst : std_logic := '0';
    signal ainc_out : std_logic_vector(log2(C_BLOCK_SIZE)-1 downto 0) := (others => '0');
    signal sum_out : std_logic_vector(C_BLOCK_SIZE-1 downto 0) := (others => '0');
    signal n : std_logic_vector(C_BLOCK_SIZE-1 downto 0) := (others => '0'); -- Set as needed
    signal abval : std_logic := '0';
    
    signal rval : std_logic;
    signal ainc_clk_en : std_logic;
    signal ainc_rst : std_logic;
    signal add_out_clk_en : std_logic;
    signal add_out_rst : std_logic;
    signal r_out_clk_en : std_logic;
    signal r_out_rst : std_logic;
    signal mux_ctl : unsigned(1 downto 0);
    
    signal control_status : std_logic_vector(NUM_STATUS_BITS-1 downto 0);
    signal control_debug : std_logic_vector(NUM_DEBUG_BITS-1 downto 0);

begin

    -- Instantiate the DUT
    DUT: entity work.blakeley_module_control
        generic map (
            c_block_size => C_BLOCK_SIZE,
            num_status_bits => NUM_STATUS_BITS,
            num_debug_bits => NUM_DEBUG_BITS
        )
        port map (
            clk => clk,
            rst => rst,
            ainc_out => ainc_out,
            sum_out => sum_out,
            n => n,
            abval => abval,
            rval => rval,
            ainc_clk_en => ainc_clk_en,
            ainc_rst => ainc_rst,
            add_out_clk_en => add_out_clk_en,
            add_out_rst => add_out_rst,
            r_out_clk_en => r_out_clk_en,
            r_out_rst => r_out_rst,
            mux_ctl => mux_ctl,
            control_status => control_status,
            control_debug => control_debug
        );

    -- Clock generation
    clk_process : process
    begin
        while true loop
            clk <= '0';
            wait for 10 ns;
            clk <= '1';
            wait for 10 ns;
        end loop;
    end process;

    -- Test process
    stimulus_process : process
    begin
        -- Initialize
        n(2) <= '1';
        rst <= '1';
        wait for 20 ns; -- Reset period
        rst <= '0';
        wait for 20 ns;

        -- Test START state
        abval <= '1';  -- Trigger START
        wait for 20 ns;
        abval <= '0';  -- Release START trigger
        wait for 20 ns;

        -- Simulate RUN state
        for i in 0 to C_BLOCK_SIZE-1 loop
            ainc_out <= std_logic_vector(to_unsigned(i, log2(C_BLOCK_SIZE)));
            sum_out <= std_logic_vector(to_unsigned(i * 2, C_BLOCK_SIZE)); -- Change sum_out to affect mux_ctl
            wait for 20 ns;
        end loop;

        -- Trigger transition to FINISHED state
        wait for 20 ns;

        -- Check outputs in FINISHED state
        wait for 20 ns;

        -- Reset to IDLE
        wait for 20 ns;

        -- End simulation
        wait;
    end process;

end architecture sim;
