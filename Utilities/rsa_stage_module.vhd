library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

entity rsa_stage_module_datapath is
    generic(
        c_block_size : integer := 256;
        c_pipeline_stages : integer;
        num_status_bits : integer := 32
    );
    port(
        --Defaults
        clk : in std_logic;

        --Data signals
        n : in std_logic_vector (c_block_size-1 downto 0);
        es : in std_logic_vector ((c_block_size/c_pipeline_stages)-1 downto 0);
        dco : out std_logic_vector (c_block_size-1 downto 0);
        dpo : out std_logic_vector (c_block_size-1 downto 0);
        dci : in std_logic_vector (c_block_size-1 downto 0);
        dpi : in std_logic_vector (c_block_size-1 downto 0);
        
        --Control signals
        c_mux_ctl : in std_logic;
        p_mux_ctl : in std_logic;
        
        c_reg_clk_en : in std_logic;
        c_reg_rst : in std_logic;
        p_reg_clk_en : in std_logic; 
        p_reg_rst : in std_logic;
        
        c_bm_abcal : in std_logic;
        c_bm_rval : out std_logic;
        P_bm_abval : in std_logic;
        p_bm_rval : out std_logic;

        
        rst_bms : in std_logic;
        
        --Status signals 
        c_bm_status : out std_logic_vector(num_status_bits-1 downto 0)
        p_bm_status : out std_logic_vector(num_status_bits-1 downto 0);
    )
end rsa_stage_module_datapath;

architecture rtl of rsa_stage_module_datapath is
    signal c : std_logic_vector(c_block_size-1 downto 0);
    signal c_nxt : std_logic_vector(c_block_size-1 downto 0);
    
    signal p : std_logic_vector(c_block_size-1 downto 0);
    signal p_nxt : std_logic_vector(c_block_size-1 downto 0);
    
    signal c_mux_out : std_logic_vector(c_block_size-1 downto 0);
    signal p_mux_out : std_logic_vector(c_block_size-1 downto 0);
    
    signal c_bm_out : std_logic_vector(c_block_size-1 downto 0);
    signal p_bm_out : std_logic_vector(c_block_size-1 downto 0);
   
begin 
    
    
    c_bm : entity work.blakeley_module(rtl)
        generic map(
           c_block_size => c_block_size
        );
        port map(
            clk => clk,
            rst => rst_bms,
            
            A => c,
            B => p,
            N => n,
            ABVAL => c_bm_abval,
            R => c_bm_out,
            RVAL => c_bm_rval,
end architecture rtl;       
