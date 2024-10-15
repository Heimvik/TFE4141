library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

library work;
use work.blakeley_utils.all;

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all; 
    
entity blakeley_module is
    generic (
		c_block_size : integer := 256;
        num_upper_status_bits : integer := 32;
        num_lower_status_bits : integer := 16
	);
    port ( 
           clk : in std_logic;
           rst : in std_logic; 
            
           A : in std_logic_vector (c_block_size-1 downto 0);
           B : in std_logic_vector (c_block_size-1 downto 0);
           N : in std_logic_vector (c_block_size-1 downto 0);
           ABVAL : in std_logic;
           R : out std_logic_vector (c_block_size-1 downto 0);
           RVAL : out std_logic;
           
           -- Optimization possible on these
           blakeley_status : out std_logic_vector(num_upper_status_bits-1 downto 0)
    );
end blakeley_module;

architecture rtl of blakeley_module is
    signal ainc_clk_en : std_logic;
    signal ainc_rst : std_logic;  
    signal add_out_clk_en : std_logic;
    signal add_out_rst : std_logic;

    --Temporary solution while debugging (remove _internal when finished)
    signal sum_out_internal : std_logic_vector(c_block_size-1 downto 0);    
    signal ainc_out_internal : std_logic_vector(log2(c_block_size)-1 downto 0);
    
    signal mux_ctl_internal : unsigned(1 downto 0);
    
    signal control_status : std_logic_vector(num_lower_status_bits-1 downto 0);
    signal datapath_status : std_logic_vector(num_lower_status_bits-1 downto 0);
    
    
begin
    blakeley_status <= datapath_status & control_status;

    datapath: entity work.blakeley_module_datapath
        generic map(
            c_block_size => c_block_size,
            num_status_bits => num_lower_status_bits
        )
        port map(
            clk => clk,
            
            a => A,
            b => B,
            n => N,
            r => R,
            
            ainc_clk_en => ainc_clk_en,
            ainc_rst => ainc_rst,
            add_out_clk_en => add_out_clk_en,
            add_out_rst => add_out_rst,
            
            sum_out => sum_out_internal,
            ainc_out => ainc_out_internal,
            
            mux_ctl => mux_ctl_internal,
            
            datapath_status => datapath_status
        );
    control : entity work.blakeley_module_control
        generic map(
            c_block_size => c_block_size,
            num_status_bits => num_lower_status_bits
        )
        port map(
            clk => clk,
            rst => rst,
            
            n => N,
            abval => ABVAL,
            rval => RVAL,
            
            ainc_clk_en => ainc_clk_en,
            ainc_rst => ainc_rst,
            add_out_clk_en => add_out_clk_en,
            add_out_rst => add_out_rst,
            
            sum_out => sum_out_internal,
            ainc_out => ainc_out_internal,
 
            mux_ctl => mux_ctl_internal,

            control_status => control_status
        );
end rtl;