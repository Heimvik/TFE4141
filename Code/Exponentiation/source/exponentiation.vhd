library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

entity rsa_core_pipeline is
    generic (
		-- Users to add parameters here
		c_block_size          : integer;
		log2_c_block_size     : integer;
		num_pipeline_stages     : integer;
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
        E : in std_logic_vector (c_block_size-1 downto 0);
        
        --Data signals
        DPO : out std_logic_vector (c_block_size-1 downto 0);
        DCO : out std_logic_vector (c_block_size-1 downto 0);
        DPI : in std_logic_vector (c_block_size-1 downto 0);
        DCI : in std_logic_vector (c_block_size-1 downto 0);
        
        --Status registers
        rsm_status : out std_logic_vector(num_status_bits-1 downto 0)
    );
end rsa_core_pipeline;

architecture rtl of rsa_core_pipeline is
    --Intermediate signals in the pipeline
    --First index i gives intermediates between stage i and i+1
    signal ilx_internals : std_logic_vector(num_pipeline_stages downto 0);
    signal ipx_internals : std_logic_vector(num_pipeline_stages downto 0);

    -- Signals for DPO, DCO, etc.
    type data_internals is array (num_pipeline_stages+1 downto 0) of std_logic_vector(c_block_size-1 downto 0);
    signal dcx_internals : data_internals;
    signal dpx_internals : data_internals;
    
    type status_internals is array (num_pipeline_stages downto 1) of std_logic_vector(num_status_bits-1 downto 0);
    signal rsm_status_internals : status_internals;
    
    constant es_size : integer := c_block_size/num_pipeline_stages;

begin

    gen_status : process(rsm_status_internals)
    begin
        for i in 1 to num_pipeline_stages loop
            rsm_status(i-1) <= rsm_status_internals(i)(7);
        end loop;
    end process gen_status;

    ilx_internals(0) <= ILI; 
    IPO <= ipx_internals(0);
    
    dcx_internals(0) <= DCI;
    dpx_internals(0) <= DPI;

    gen_pipeline : for i in 1 to num_pipeline_stages generate
        stage : entity work.rsa_stage_module
        generic map(
            c_block_size => c_block_size,
            log2_c_block_size => log2_c_block_size,
            num_pipeline_stages => num_pipeline_stages,
            num_status_bits => num_status_bits
        )
        port map(
            CLK => CLK,
            RST => RST,
            ILI => ilx_internals(i-1),
            IPO => ipx_internals(i-1),
            ILO => ilx_internals(i),
            IPI => ipx_internals(i),
            
            N => n,
            ES => e((es_size*i)-1 downto (es_size*(i-1))),
            DCI => dcx_internals(i-1),
            DPI => dpx_internals(i-1),
            DCO => dcx_internals(i),
            DPO => dpx_internals(i),
            rsm_status => rsm_status_internals(i)
        );
    end generate gen_pipeline;
    
    ipx_internals(num_pipeline_stages) <= IPI;
    ILO <= ilx_internals(num_pipeline_stages);

    DCO <= dcx_internals(num_pipeline_stages);
    DPO <= dcx_internals(num_pipeline_stages);
end rtl;