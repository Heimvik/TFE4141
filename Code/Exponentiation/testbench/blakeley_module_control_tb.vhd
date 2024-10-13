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
