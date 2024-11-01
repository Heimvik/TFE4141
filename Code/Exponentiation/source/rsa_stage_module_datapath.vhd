library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

entity rsa_stage_module_datapath is
    generic(
        c_block_size : integer := 256;
        num_status_bits : integer := 32;
        
        datapath_offset : integer := 19;
        c_mux_ctl_bit : integer := 0;
        p_mux_ctl_bit : integer := 1;
        c_bm_abval_bit : integer := 2;
        p_bm_abval_bit : integer := 3;
        c_reg_clk_en_bit : integer := 4;
        p_reg_clk_en_bit : integer := 5;
        c_reg_rst_bit : integer := 6;
        p_reg_rst_bit : integer := 7;
        reg_valid_bit : integer := 8
    );
    port(
        --Defaults
        clk : in std_logic;

        --Data signals
        n : in std_logic_vector (c_block_size+1 downto 0); --NB: To avoid overflow
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
        
        c_bm_abval : in std_logic;
        c_bm_rval : out std_logic;
        p_bm_abval : in std_logic;
        p_bm_rval : out std_logic;

        
        rst_bms : in std_logic
        
        --Status signals 
        --bm_status : out std_logic_vector(num_status_bits-1 downto 0);
        --datapath_status : out std_logic_vector(num_status_bits-1 downto 0) := (others=>'0')
    );
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
    
    signal c_bm_status : std_logic_vector(num_status_bits-1 downto 0);
    signal p_bm_status : std_logic_vector(num_status_bits-1 downto 0);
   
begin
    --datapath_status(datapath_offset+p_mux_ctl_bit downto datapath_offset+c_mux_ctl_bit)         <= p_mux_ctl & c_mux_ctl;
    --datapath_status(datapath_offset+p_bm_abval_bit downto datapath_offset+c_bm_abval_bit)       <= p_bm_abval & c_bm_abval;
    --datapath_status(datapath_offset+p_reg_clk_en_bit downto datapath_offset+c_reg_clk_en_bit)   <= p_reg_clk_en & c_reg_clk_en;
    --datapath_status(datapath_offset+p_reg_rst_bit downto datapath_offset+c_reg_rst_bit)         <= p_reg_rst & c_reg_rst;
    --bm_status <= std_logic_vector(unsigned(c_bm_status) sll 16) or p_bm_status;
    
    sel_c_comb : process(c_mux_ctl,dci,c_bm_out) is
    begin
        if c_mux_ctl = '0' then
            c_nxt <= dci;
        else
            c_nxt <= c_bm_out;
        end if;
    end process sel_c_comb;
            
    
    c_bm : entity work.blakeley_module(rtl)
        generic map(
           c_block_size => c_block_size
        )
        port map(
            clk => clk,
            rst => rst_bms,
            
            A => p,
            B => c,
            N => n,
            ABVAL => c_bm_abval,
            R => c_bm_out,
            RVAL => c_bm_rval
            
            --blakeley_status => c_bm_status
        );
        
    dco <= c;
        
    sel_p_comb : process(p_mux_ctl,dpi,p_bm_out) is
    begin
        --datapath_status(datapath_offset + p_mux_ctl_bit) <= p_mux_ctl;
        if p_mux_ctl = '0' then
            p_nxt <= dpi;
        else
            p_nxt <= p_bm_out;
        end if;
    end process sel_p_comb;
    
    p_bm : entity work.blakeley_module(rtl)
        generic map(
           c_block_size => c_block_size
        )
        port map(
            clk => clk,
            rst => rst_bms,
            
            A => p,
            B => p,
            N => n,
            ABVAL => p_bm_abval,
            R => p_bm_out,
            RVAL => p_bm_rval
            
            --blakeley_status => p_bm_status
        );
        
    dpo <= p;

    datapath_seq : process(clk,c_reg_rst) is
    begin
        --Gated clocks
        if(clk'event and clk = '1') then
            if c_reg_clk_en = '1' then
                c <= c_nxt;
            end if;
            if p_reg_clk_en = '1' then
                p <= p_nxt;
            end if;
        end if;
        
        --Asynchronus reset
        if c_reg_rst = '1' then
            c <= (others => '0');
        end if;
        if c_reg_rst = '1' then
            p <= (others => '0');
        end if;        
    end process datapath_seq;
end architecture rtl;       
