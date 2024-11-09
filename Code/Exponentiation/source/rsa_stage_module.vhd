library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity rsa_stage_module is
    generic (
		-- Users to add parameters here
		c_block_size          : integer;
		log2_c_block_size     : integer;
		
		num_pipeline_stages     : integer;
        log2_es_size          : integer;
		
		num_status_bits       : integer
	);
    port (
        CLK : in std_logic;
        RST : in std_logic;
        
        --Control signals             
        ILI : in std_logic;
        IPI : in std_logic;
        IPO : out std_logic;
        ILO : out std_logic;
        N : in std_logic_vector (c_block_size-1 downto 0);
        ES : in std_logic_vector ((c_block_size/num_pipeline_stages)-1 downto 0);
        
        --Data signals
        DPO : out std_logic_vector (c_block_size-1 downto 0);
        DCO : out std_logic_vector (c_block_size-1 downto 0);
        DPI : in std_logic_vector (c_block_size-1 downto 0);
        DCI : in std_logic_vector (c_block_size-1 downto 0);
        
        --Status register
        rsm_status : out std_logic_vector(num_status_bits-1 downto 0)
    );
end rsa_stage_module;


architecture rtl of rsa_stage_module is
    --Internal singnals
    --Extended by one bit to enable no overflow when doing sll 1 in blakeley module
    signal n_extended : std_logic_vector(c_block_size+1 downto 0);
    
    signal c_mux_ctl : std_logic;
    signal p_mux_ctl : std_logic;
    
    signal c_reg_clk_en : std_logic;
    signal c_reg_rst : std_logic;
    signal p_reg_clk_en : std_logic; 
    signal p_reg_rst : std_logic;
    
    signal c_bm_abval : std_logic;
    signal c_bm_rval : std_logic;
    signal p_bm_abval : std_logic;
    signal p_bm_rval : std_logic;
    
    signal rst_bms : std_logic;
    
    signal control_status : std_logic_vector(num_status_bits-1 downto 0);

begin
    n_extended <= "00" & N;
    rsm_status <= control_status;
    
    datapath: entity work.rsa_stage_module_datapath
        generic map(
            c_block_size => c_block_size,
            num_status_bits => num_status_bits
        )
        port map(
            clk => CLK,
            
            n => n_extended,
            dco => DCO,
            dpo => DPO,
            dci => DCI,
            dpi => DPI,
            
            c_mux_ctl => c_mux_ctl,
            p_mux_ctl => p_mux_ctl,
            
            c_reg_clk_en => c_reg_clk_en,
            c_reg_rst => c_reg_rst,
            p_reg_clk_en => p_reg_clk_en,
            p_reg_rst => p_reg_rst,
            
            c_bm_abval => c_bm_abval,
            c_bm_rval => c_bm_rval,
            p_bm_abval => p_bm_abval,
            p_bm_rval => p_bm_rval,
            
            rst_bms => rst_bms
        );

    control: entity work.rsa_stage_module_control
        generic map(
            c_block_size => c_block_size,
            log2_c_block_size => log2_c_block_size,
            num_pipeline_stages => num_pipeline_stages,
            log2_es_size => log2_es_size,
            num_status_bits => num_status_bits
        )
        port map(
            clk => CLK,
            rst => RST,
            
            es => ES,
            ili => ILI,
            ipi => IPI,
            ilo => ILO,
            ipo => IPO,
            
            c_mux_ctl => c_mux_ctl,
            p_mux_ctl => p_mux_ctl,
            
            c_reg_clk_en => c_reg_clk_en,
            c_reg_rst => c_reg_rst,
            p_reg_clk_en => p_reg_clk_en,
            p_reg_rst => p_reg_rst,
            
            c_bm_abval => c_bm_abval,
            c_bm_rval => c_bm_rval,
            p_bm_abval => p_bm_abval,
            p_bm_rval => p_bm_rval,
            
            rst_bms => rst_bms,
            control_status => control_status
        );
end rtl;
















